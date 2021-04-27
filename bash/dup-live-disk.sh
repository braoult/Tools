#!/bin/bash
#
# dup-live-disk.sh - duplicate (possibly live) system partitions
#
# (C) Bruno Raoult ("br"), 2007-2021
# Licensed under the Mozilla Public License (MPL) version 2.0.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the Mozilla Public License along with this
# program.  If not, see <https://www.mozilla.org/en-US/MPL>
#
# SPDX-License-Identifier: MPL-2.0 <https://spdx.org/licenses/MPL-2.0.html>
#
#%MAN_BEGIN%
# NAME
#       dup-live-disk.sh - duplicate (possibly live) system partitions
#
# SYNOPSIS
#       dup-live-disk.sh [OPTIONS] [SRC] DST
#
# DESCRIPTION
#       Duplicate SRC disk partitions to same structured DST disk ones.
#       if SRC is omitted, tue running system disk (where root partition resides) will
#       be used.
#       Both SRC and DST *must* have same partition base LABELs - as 'LABEL' field for
#       lsblk(1) and blkid(1), with an ending character (unique per disk) to
#       differentiate them.
#       For example, if partitions base labels are 'root', 'export', and 'swap',
#       SRC disk the ending character '1' and DST disk the character '2', SRC
#       partitions must be 'root1', 'export1, and 'swap1', and DST partitions must be
#       'root2', 'export2, and 'swap2'.
#
# OPTIONS
#       -d, -n, --dry-run, --no
#          Dry-run: nothing will be written to disk.
#
#       -h, --help
#          Display short help and exit.
#
#       -m, --man
#          Display a "man-like" description and exit.
#
#       -r, --root=PARTNUM
#          Mandatory if SRC is provided, forbidden otherwise.
#          PARTNUM is root partition number on SRC disk.
#
#       -y, --yes
#          Do not ask for actions confirmation. Default is to display next
#          action and ask user to [y] do it, [q] quit, [s] skip.
#
# EXAMPLES
#       Copy sda to sdb, root partition is partition (sda1/sdb1)
#       $ sudo dup-live-disk.sh --root 1 sda sdb
#
#       Copy live system (where / is mounted) to sdb
#       $ sudo dup-live-disk.sh sdb
#
# BUGS
#       Cannot generate grub with a separate /boot partition.
#       This script will not work for all situations, I strongly suggest you
#       don't use it if you don't *fully* understand it.
#
# TODO
#       Write about autofs.
#%MAN_END%

# command line
SCRIPT="${0}"
CMD="${0##*/}"

# valid filesystems
# shellcheck disable=2034
VALIDFS=(ext3 ext4 btrfs vfat reiserfs)

function man {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!p}'  "$SCRIPT" | sed -E 's/^# ?//'
}

function usage {
    cat <<_EOF
Usage: $CMD [OPTIONS] [SRC] DST
Duplicate SRC (or live system) disk partitions to DST disk partitions.

Options:
      -d, -n, --dry-run, --no  dry-run: nothing will be written to disk
      -h, --help               this help
      -m, --man                display a "man-like" page and exit
      -r, --root=PARTNUM       root partition number on SRC device
                               mandatory if and only if SRC is provided
      -y, --yes                DANGER ! perform all actions without user
                               confirmation

SRC and DST have strong constraints on partitions schemes and naming.
Type '$CMD --man" for more details"
_EOF
    exit 0
}

# log function
# parameters:
# -l, -s: long, or short prefix (default: none). Last one is used.
# -t: timestamp
# -n: no newline
function log {
    local timestr="" prefix="" opt=y newline=y
    while [[ $opt = y ]]; do
        case $1 in
            -l) prefix=$(printf "*%.s" {1..30});;
            -s) prefix=$(printf "*%.s" {1..5});;
            -n) newline=n;;
            -t) timestr=$(date "+%F %T%z - ");;
            *) opt=n;;
        esac
        [[ $opt = y ]] && shift
    done
    [[ $prefix != "" ]] && printf "%s " "$prefix"
    printf "%s" "$timestr"
    printf "$@"
    [[ $newline = y ]] && printf "\n"
    return 0
}

# prints out and run a command.
function echorun {
    log "%s" "$@"
    "$@"
    return $?
}

function error_handler {
    local ERROR=$2
    log "FATAL: Error line $1, exit code $2. Aborting."
    exit "$ERROR"
}
trap 'error_handler $LINENO $?' ERR SIGHUP SIGINT SIGTERM

function check_block_device {
    local devtype="$1"
    local mode="$2"
    local dev="$3"

    if [[ ! -b "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not a block device." >&2
        exit 1
    fi
    if [[ ! -r "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not readable." >&2
        exit 1
    fi
    if [[ $mode = "w" && ! -w "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not writable." >&2
        exit 1
    fi
    return 0
}

# check if $1 is in array $2 ($2 is by reference)
function in_array {
    local elt=$1 i
    local -n arr=$2
    for ((i=0; i<${#arr[@]}; ++i)); do
        [[ ${arr[$i]} == "$elt" ]] && return 0
    done
    return 1
}

# source and destination devices, root partition
SRC=""
DST=""
SRCROOT=""
ROOTPARTNUM=""
DOIT=manual

# short and long options
SOPTS="dnhmr:y"
LOPTS="dry-run,no,help,man,root:,yes"

if ! TMP=$(getopt -o "$SOPTS" -l "$LOPTS" -n "$CMD" -- "$@"); then
    log "Use '$CMD --help' or '$CMD --man' for help."
    exit 1
fi
# if (( $? > 1 )); then
#   echo 'Terminating...' >&2
#   exit 1
# fi

eval set -- "$TMP"
unset TMP

while true; do
    case "$1" in
        '-d'|'-n'|'--dry-run'|'--no')
            DOIT=no
            shift
            continue
            ;;
        '-h'|'--help')
            usage
            exit 0
            ;;
        '-m'|'--man')
            man
            exit 0
            ;;
        '-r'|'--root')
            ROOTPARTNUM="$2"
            if ! [[ "$ROOTPARTNUM" =~ ^[[:digit:]]+$ ]]; then
                log "$CMD: $ROOTPARTNUM must be a partition number." >&2
                exit 1
            fi
            shift 2
            continue
            ;;
        '-y'|'--yes')
            DOIT=yes
            shift
            continue
            ;;
        '--')
            shift
            break
            ;;
        *)
            usage
            log 'Internal error!' >&2
            exit 1
            ;;
    esac
done


case "$#" in
    1)
        if [[ -n "$ROOTPARTNUM" ]]; then
            log "$CMD: cannot have --root option for live system." >&2
            log "Use '$CMD --help' or '$CMD --man' for help." >&2
            exit 1
        fi
        # guess root partition disk name
        SRCROOT=$(findmnt -no SOURCE -M /)
        ROOTPARTNUM=${SRCROOT: -1}
        SRC="/dev/"$(lsblk -no pkname "$SRCROOT")
        DST="/dev/$1"
        ;;
    2)
        if [[ -z "$ROOTPARTNUM" ]]; then
            log "$CMD: missing --root option for non live system." >&2
            log "Use '$CMD --help' or '$CMD --man' for help." >&2
            exit 1
        fi
        SRC="/dev/$1"
        SRCROOT="$SRC$ROOTPARTNUM"
        DST="/dev/$2"
        ;;
    *)
        usage >&2
        exit 1
esac

# check SRC and DST are different, find out their characteristics
if [[ "$SRC" = "$DST" ]]; then
    log "%s: Fatal: destination disk (%s) cannot be source.\n" "$CMD" "$SRC"
    log "Use '%s --help' or '%s --man' for help." "$CMD" "$CMD"
    exit 1
fi
check_block_device "source disk" r "$SRC"
check_block_device "destination disk" w "$DST"
check_block_device "source root partition" r "$SRCROOT"

SRCROOTLABEL=$(lsblk -no label "$SRCROOT")
SRCCHAR=${SRCROOTLABEL: -1}
ROOTLABEL=${SRCROOTLABEL:0:-1}
# find out all partitions labels on SRC disk...
# shellcheck disable=SC2207
declare -a SRCLABELS=($(lsblk -lno  LABEL "$SRC"))
# shellcheck disable=SC2206
declare -a LABELS=(${SRCLABELS[@]%?})

#log "SRCLABELS=${#SRCLABELS[@]} - ${SRCLABELS[*]}"
#log "LABELS=${#LABELS[@]} - ${LABELS[*]}"


declare -a SRCDEVS SRCFS SRCDOIT
# ... and corresponding partition device and fstype
for ((i=0; i<${#LABELS[@]}; ++i)); do
    TMP="${LABELS[$i]}$SRCCHAR"
    TMP="${SRCLABELS[$i]}"
    TMPDEV=$(findfs LABEL="$TMP")
    TMPFS=$(lsblk -no fstype "$TMPDEV")
    log "found LABEL=$TMP DEV=$TMPDEV FSTYPE=$TMPFS"
    SRCDEVS[$i]="$TMPDEV"
    SRCFS[$i]="$TMPFS"
    SRCDOIT[$i]=n
    in_array "$TMPFS" VALIDFS && SRCDOIT[$i]=y
    unset TMP TMPDEV TMPFS
done


DSTROOT="$DST$ROOTPARTNUM"
check_block_device "destination root partition" w "$DSTROOT"
DSTROOTLABEL=$(lsblk -no label "$DSTROOT")
DSTCHAR=${DSTROOTLABEL: -1}

# check DSTROOTLABEL is compatible with ROOTLABEL
if [[ "$DSTROOTLABEL" != "$ROOTLABEL$DSTCHAR" ]]; then
    log "%s: Fatal: %s != %s%s." "$CMD" "$DSTROOTLABEL" "$ROOTLABEL" "$DSTCHAR"
    exit 1
fi

# log "SRC=%s DST=%s" "$SRC" "$DST"
# log "SRCROOT=%s DSTROOT=%s" "$SRCROOT" "$DSTROOT"
# log "ROOTLABEL=$ROOTLABEL"
# log "SRCROOTLABEL=%s DSTROOTLABEL=%s" "$SRCROOTLABEL" "$DSTROOTLABEL"
# log "SRCCHAR=%s DSTCHAR=%s" "$SRCCHAR" "$DSTCHAR"
# log "DOIT=%s\n" "$DOIT"

declare -a DSTLABELS DSTDEVS DSTFS DSTDOIT
# Do the same for correponding DST partitions labels, device, and fstype
for ((i=0; i<${#LABELS[@]}; ++i)); do
    TMP="${LABELS[$i]}$DSTCHAR"
    log -n "Looking for [%s] label... " "$TMP"
    if ! TMPDEV=$(findfs LABEL="$TMP"); then
        log "not found."
        exit 1
    fi
    TMPDISK=${TMPDEV%?}
    log -n "DEV=%s... DISK=%s..." "$TMPDEV" "$TMPDISK"
    if [[ "$TMPDISK" != "$DST" ]]; then
        log "wrong disk (%s != %s)" "$TMPDISK" "$DST"
        exit 1
    fi
    TMPFS=$(lsblk -no fstype "$TMPDEV")
    log "FSTYPE=%s" "$TMPFS"
    DSTLABELS[$i]="$TMP"
    DSTDEVS[$i]="$TMPDEV"
    DSTFS[$i]="$TMPFS"
    DSTDOIT[$i]=n
    in_array "$TMPFS" VALIDFS && DSTDOIT[$i]=y
    unset TMP TMPDEV TMPFS
done
echo ZOB "${SRCDEVS[0]}" "${DSTDEVS[0]}"
for ((i=0; i<${#LABELS[@]}; ++i)); do
    log -n "%s %s " "${SRCDEVS[$i]}" "${DSTDEVS[$i]}"
    log -n "%s %s " "${SRCLABELS[$i]}" "${DSTLABELS[$i]}"
    log -n "%s %s "  "${SRCFS[$i]}" "${DSTFS[$i]}"
    log "%s %s"  "${SRCDOIT[$i]}" "${DSTDOIT[$i]}"
    echo
done | column -N DEV1,DEV2,LABEL1,LABEL2,FS1,FS2,SDOIT,DDOIT -t -o " | "

RSYNCOPTS="-axH --delete --delete-excluded"
FILTER=--filter="dir-merge .rsync-disk-copy"
# copy loop
for ((i=0; i<${#LABELS[@]}; ++i)); do
    if [[ "${SRCDOIT[$i]}" != y ]] || [[ "${DSTDOIT[$i]}" != y ]]; then
        log "skipping label %s" "${LABELS[$i]}"
        continue
    fi
    SRCPART=/mnt/${SRCLABELS[$i]}/
    DSTPART=/mnt/${DSTLABELS[$i]}

    log -n "%s -> %s : " "$SRCPART" "$DSTPART"
    #log "\t%s %s %s %s %s" rsync "${RSYNCOPTS}" "$FILTER" "$SRCPART" "$DSTPART"
    skip=y
    case "$DOIT" in
        yes)
            skip=n
            ;;
        no)
            log "skipping (dry run)."
            ;;
        manual)
            log -n "proceed ? [y/N/q] "
            read -r key
            case "$key" in
                y|Y)
                    log "copying..."
                    skip=n
                    ;;
                q|Q)
                    log "aborting..."
                    exit 0
                    ;;
                n|N|*)
                    log "skipping..."
                    ;;
            esac
    esac
    if [[ "$skip" == n ]]; then
        # shellcheck disable=SC2086
        echorun rsync "$FILTER" ${RSYNCOPTS} "$SRCPART" "$DSTPART"
    fi
    log ""
done


exit 0
# array of partitions to copy
TO_COPY=(root export EFI)

# An alternative to SRCNUM, DSTNUM, and TO_COPY variables would be to have
# an array containing src and destination partitions:
#   (partsrc1 partdst1 partsrc2 partdst2 etc...)
# example:
# TO_COPY=(root2 root1 export2 export1)
# declare -i i
# for ((i=0; i<${#TO_COPY[@]}; i+=2)); do
#     SRC=${#TO_COPY[$i]}
#     DST=${#TO_COPY[$i + 1]}
# etc...

# where we will configure/install grub: mount point, device
GRUB_ROOT=/mnt/root${DSTNUM}
GRUB_DEV=/dev/$(lsblk -no pkname /dev/disk/by-label/root${DSTNUM})

# we will use ".rsync-disk-copy" files to exclude files/dirs

# stop what could be problematic (databases, etc...)
systemctl stop mysql

# partitions copy
for part in ${TO_COPY[@]}; do
    SRCPART=/mnt/${part}${SRCNUM}/
    DSTPART=/mnt/${part}${DSTNUM}

    echo copy from $SRCPART to $DSTPART
    echo -n "press a key to continue..."
    read -r key
    echo rsync ${RSYNCOPTS} "$FILTER" "$SRCPART" "$DSTPART"
    rsync ${RSYNCOPTS} "$FILTER" "$SRCPART" "$DSTPART"
done

# grub install
# mount virtual devices
mount -o bind  /sys    ${GRUB_ROOT}/sys
mount -o bind  /proc   ${GRUB_ROOT}/proc
mount -o bind  /dev    ${GRUB_ROOT}/dev

chroot ${GRUB_ROOT} update-grub
chroot ${GRUB_ROOT} grub-install ${GRUB_DEV}

# restart stopped process (db, etc...)
systemctl start mysql

exit 0
###############declare -a DSTLABELS_CHECK=(${SRCLABELS[@]/%?/$DSTCHAR})

# find corresponding LABELS on DEST disk
# declare -a LABELS=(${SRCLABELS[@]/%?/})
# for ((i=0; i<${#SRCLABELS[@]}; ++i)); do
#     TMP="${LABELS[$i]}$DSTCHAR"
#     echo -n "looking for partition 'LABEL=$TMP'... "
#     if ! DSTFS=$(findfs LABEL="$TMP"); then
#         echo "not found."
#         exit 1
#     fi
#     echo "$DSTFS"
#     DSTLABELS[$i]="$TMP"

# done

# #DSTLABELS=($(lsblk -lno  LABEL "$DST"))
# # check all partitions types
# for ((i=0; i<${#SRCLABELS[@]}; ++1)); do
#     check_block_device "source ${LABELS[$i]} partition" r "${SRCLABELS[$i]}"
#     #check_block_device "destination ${LABELS[$i]} partition" w "${DSTLABELS[$i]}"

# done

# echo "DSTLABELS=${#DSTLABELS[@]} - ${DSTLABELS[*]}"


exit 0
