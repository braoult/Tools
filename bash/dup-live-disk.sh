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
#       if SRC is omitted, tue running system disk (where root partition
#       resides) will be used.
#       Both SRC and DST *must* have same partition base LABELs - as 'LABEL'
#       field for lsblk(1) and blkid(1), with an ending character (unique per
#       disk) to differentiate them.
#       For example, if partitions base labels are 'root', 'export', and 'swap',
#       SRC disk the ending character '1' and DST disk the character '2', SRC
#       partitions must be 'root1', 'export1, and 'swap1', and DST partitions
#       must be 'root2', 'export2, and 'swap2'.
#
# OPTIONS
#       -d, -n, --dry-run, --no
#          Dry-run: nothing will be written to disk.
#
#       -g, --grub
#          Install grub on destination disk.
#          Warning: Only works if root partition contains all necessary for
#          grub: /boot, /usr, etc...
#
#       -h, --help
#          Display short help and exit.
#
#       -m, --man
#          Display a "man-like" description and exit.
#
#       --mariadb
#          Stop mysql/mariadb before effective copies, restart after.
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
#       Write about autofs configuration.
#       Log levels
#       Separate dry-run and copies/mysql/grub
#%MAN_END%

# command line
SCRIPT="$0"
CMD="${0##*/}"

# valid filesystems
# shellcheck disable=2034
VALIDFS=(ext3 ext4 btrfs vfat reiserfs xfs zfs)

function man {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!p}'  "$SCRIPT" | sed -E 's/^# ?//'
}

function usage {
    cat <<_EOF
Usage: $CMD [OPTIONS] [SRC] DST
Duplicate SRC (or live system) disk partitions to DST disk partitions.

Options:
      -d, -n, --dry-run, --no  dry-run: nothing will be written to disk
      -g, --grub               install grub on destination disk
      -h, --help               this help
      -m, --man                display a "man-like" page and exit
      --mariadb                stop and restart mysql/mariadb server before and
                               after copies
      -r, --root=PARTNUM       root partition number on SRC device
                               mandatory if and only if SRC is provided
      -y, --yes                DANGER ! perform all actions without user
                               confirmation

SRC and DST have strong constraints on partitions schemes and naming.
Type '$CMD --man" for more details"
_EOF
    exit 0
}

# mariadb start/stop
function mariadb_maybe_stop {
    if [[ $MARIADB == yes ]] && systemctl is-active --quiet mysql; then
        log -n "stopping mariadb/mysql... "
        systemctl stop mariadb
        # bug if script stops here
        MARIADBSTOPPED=yes
        log "done."
    fi
}
function mariadb_maybe_start {
    if [[ $MARIADB == yes && $MARIADBSTOPPED == yes ]]; then
        log -n "restarting mariadb/mysql... "
        systemctl start mariadb
        MARIADBSTOPPED=no
        log "done."
    fi
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
    # shellcheck disable=SC2059
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

function exit_handler {
    log "exit handler (at line $1)"
    mariadb_maybe_start
    if [[ -v DSTMNT ]]; then
        umount "$DSTMNT/dev"
        umount "$DSTMNT/proc"
        umount "$DSTMNT/sys"
    fi

}
trap 'exit_handler $LINENO' EXIT

function check_block_device {
    local devtype="$1"
    local mode="$2"
    local dev="$3"

    if [[ ! -b "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not a block device."
        exit 1
    fi
    if [[ ! -r "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not readable."
        exit 1
    fi
    if [[ $mode = "w" && ! -w "$dev" ]]; then
        log "$CMD: $devtype '$dev' is not writable."
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

# get y/n/q user input
function yesno {
    local input
    while true; do
        printf "%s " "$1"
        read -r input
        case "$input" in
            y|Y)
                return 0
                ;;
            q|Q)
                log "aborting..."
                exit 0
                ;;
            n|N)
                return 1
                ;;
            *)
                printf "invalid answer. "
        esac
    done
}

# source and destination devices, root partition
SRC=""
DST=""
SRCROOT=""
ROOTPARTNUM=""
DOIT=manual
MARIADB=no
MARIADBSTOPPED=no
GRUBINSTALL=no

# short and long options
SOPTS="dnghmr:y"
LOPTS="dry-run,no,grub,help,man,mariadb,root:,yes"

if ! TMP=$(getopt -o "$SOPTS" -l "$LOPTS" -n "$CMD" -- "$@"); then
    log "Use '$CMD --help' or '$CMD --man' for help."
    exit 1
fi

eval set -- "$TMP"
unset TMP

while true; do
    case "$1" in
        '-d'|'-n'|'--dry-run'|'--no')
            DOIT=no
            shift
            continue
            ;;
        '-g'|'--grub')
            GRUBINSTALL=yes
            shift
            ;;
        '-h'|'--help')
            usage
            exit 0
            ;;
        '-m'|'--man')
            man
            exit 0
            ;;
        '--mariadb')
            MARIADB=yes
            shift
            ;;
        '-r'|'--root')
            ROOTPARTNUM="$2"
            if ! [[ "$ROOTPARTNUM" =~ ^[[:digit:]]+$ ]]; then
                log "$CMD: $ROOTPARTNUM must be a partition number."
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
            log 'Internal error!'
            exit 1
            ;;
    esac
done


case "$#" in
    1)
        if [[ -n "$ROOTPARTNUM" ]]; then
            log "$CMD: cannot have --root option for live system."
            log "Use '$CMD --help' or '$CMD --man' for help."
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
            log "$CMD: missing --root option for non live system."
            log "Use '$CMD --help' or '$CMD --man' for help."
            exit 1
        fi
        SRC="/dev/$1"
        SRCROOT="$SRC$ROOTPARTNUM"
        DST="/dev/$2"
        ;;
    *)
        usage
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

for ((i=0; i<${#LABELS[@]}; ++i)); do
    log -n "%s %s " "${SRCDEVS[$i]}" "${DSTDEVS[$i]}"
    log -n "%s %s " "${SRCLABELS[$i]}" "${DSTLABELS[$i]}"
    log -n "%s %s "  "${SRCFS[$i]}" "${DSTFS[$i]}"
    log -n "%s %s "  "${SRCDOIT[$i]}" "${DSTDOIT[$i]}"
    [[ "$DSTROOTLABEL" == "${DSTLABELS[$i]}" ]] && log "*"
    echo
done | column -N DEV1,DEV2,LABEL1,LABEL2,FS1,FS2,SDOIT,DDOIT,ROOT -t -o " | "

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
            yesno "proceed ? [y/n/q]" && skip=n
            ;;
    esac
    if [[ "$skip" == n ]]; then
        # shellcheck disable=SC2086
        mariadb_maybe_stop
        echorun rsync "$FILTER" ${RSYNCOPTS} "$SRCPART" "$DSTPART"
    fi
    log ""
done

# grub install
# mount virtual devices
if [[ $GRUBINSTALL == yes ]]; then
    log "installing grub on $DST..."
    DSTMNT="/mnt/$DSTROOTLABEL"
    mount -o bind /sys  "$DSTMNT/sys"
    mount -o bind /proc "$DSTMNT/proc"
    mount -o bind /dev  "$DSTMNT/dev"

    chroot "$DSTMNT" update-grub
    chroot "$DSTMNT" grub-install "$DST"

fi

exit 0
