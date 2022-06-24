#!/usr/bin/env bash
#
# dup-live-disk.sh - duplicate (possibly live) system partitions
#
# (C) Bruno Raoult ("br"), 2007-2022
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
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
#       if SRC is omitted, the running system disk (where root partition
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
#       -a, --autofs=DIR
#          Use DIR as autofs "LABEL-based" automount. See AUTOFS below. Default
#          is /mnt.
#
#       -c, --copy=ACTION
#          ACTION can be 'yes' (all eligible partitions will be copied), 'no'
#          (no partition will be copied), or 'ask'. Default is 'Ask'.
#          See ACTIONS below.
#
#       -d, --dry-run
#          Dry-run: nothing will be really be written to disk. This option
#          0verrides any of '--yes', '--copy', '--fstab', '--grub', and
#          '--mariadb' options.
#
#       -f, --fstab=ACTION
#          ACTION ('yes', 'no', or 'ask') defines whether fstab should be
#          adjusted on destination root partition. Default is 'ask'.
#          /etc/fstab/LABEL must exist on source root partition. LABEL is the
#          partition LABEL of destination root disk.
#          See ACTIONS below.
#
#       -g, --grub=ACTION
#          ACTION ('yes', 'no', 'ask') defines if grub should be installed on
#          destination disk). Default is 'ask'.
#          Warning: Only works if root partition contains all necessary files
#          for grub: /boot, /usr, etc...
#          See ACTIONS below.
#
#       -h, --help
#          Display short help and exit.
#
#       -m, --man
#          Display a "man-like" description and exit.
#
#       -M, --mariadb=ACTION
#          ACTION may be 'yes', 'no', or 'ask', which indicates whether mysql
#          or mariadb should be stopped before effective partition copies, and
#          restarted after.
#          See ACTIONS below.
#
#       -n, --no
#          Will answer 'no' to any question asked to user.
#
#       -r, --root=PARTNUM
#          Mandatory if SRC is provided, forbidden otherwise.
#          PARTNUM is root partition number on SRC disk.
#
#       -y, --yes
#          Will answer 'yes' to any question asked to user.
#
# ACTIONS
#       Before writing anything, of if something unexpected happens, the
#       program may ask to proceed. User may answer 'yes', 'no', or 'quit'.
#       Options --yes, and --no will default respectively to 'yes' and 'no',
#       default is to ask.
#       Options '--copy', '--fstab', and '--grub' (which can take the values
#       'yes', 'no', and 'ask') can override the specific action for copying
#       partitions, adjusting destination fstab file, and
#       installing grub on destination disk.
#
# EXAMPLES
#       Copy sda to sdb, root partition is partition 1 (sda1/sdb1) on both
#       disks. The user will be asked for any action (partition copy, grub,
#       etc...)
#       $ sudo dup-live-disk.sh --root 1 sda sdb
#
#       Copy live disk (all partitions of current / partition disk) to sdb.
#       The user will be asked for any action (partition copy, grub, etc...)
#       $ sudo dup-live-disk.sh sdb
#
#       Copy live disk (all partitions of current / partition disk) to sdb.
#       All valid partitions will be copied, and grub installed on sdb.
#       $ sudo dup-live-disk.sh --yes sdb
#
#       Do not copy partitions, only install grub on sdb.
#       $ sudo ./dup-live-disk.sh --copy=no --grub=yes sdb
#       or
#       $ sudo ./dup-live-disk.sh --no --grub=yes sdb
#
# AUTOFS
#       This script relies on autofs to mount partitions according to partitions
#       LABELS. See autofs(5) and auto.master(5) for more details.
#       For example, the following will mount partitions withs LABELS 'root1',
#       'root2' in /mnt/hd/root1 and /mnt/hd/root2, simply when we try to access
#       the directories (for example with 'ls /mnt/hd/root1') :
#
#       # in file /etc/auto.master
#       /mnt/hd   /etc/auto.hd              --timeout 60 --ghost
#
#       # in file /etc/auto.hd
#       *         -fstype=auto,defaults     :LABEL=&
#
#       This script uses /mnt as default autofs directory. In fact, /mnt contains
#       symbolic links to different disk labels :
#
#       $ ls -l /mnt/root?
#       lrwxrwxrwx 1 root root 8 Oct 10  2020 /mnt/root1 -> hd/root1/
#       lrwxrwxrwx 1 root root 8 May 25  2018 /mnt/root2 -> hd/root2/
#
#       It means that accessing /mnt/root1 will automagically mount /mnt/hd/root1.
#       With the maps above, and without the /mnt symlinks, it is possible to
#       use '--autofs=/mnt/hd' to directly use the automounter map.
#
# BUGS
#       * Cannot generate grub with a separate /boot partition.
#       * This script will not work for all situations, I strongly suggest you
#         don't use it if you don't *fully* understand it.
#       * Extended attributes are not preserved (easy fix, but I cannot test)
#
# TODO
#       * Log levels
#%MAN_END%

# command line
SCRIPT="$0"
CMD="${0##*/}"
export LC_ALL=C

# valid filesystems
# shellcheck disable=2034
VALIDFS=(ext3 ext4 btrfs vfat reiserfs xfs zfs)

man() {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!s/^#[ ]\{0,1\}//p}' "$SCRIPT" | more
}

usage() {
    cat <<_EOF
Usage: $CMD [OPTIONS] [SRC] DST
Duplicate SRC (or live system) disk partitions to DST disk partitions.

Options:
      -a, --autofs=DIR     autofs 'LABEL-based' directory. Default is '/mnt'.
      -c, --copy=ACTION    do partitions copies (ACTION='yes', 'no', 'ask).
                           Default is 'ask'
      -d, --dry-run        dry-run: nothing will be written to disk
      -f, --fstab=ACTION   adjust fstab on destination disk ('yes', 'no',
                           'ask'). Default is 'ask'
      -g, --grub=ACTION    install grub on destination disk ('yes', 'no',
                           'ask'). Default is 'ask'
      -h, --help           this help
      -m, --man            display a "man-like" page and exit
      -M, --mariadb=ACTION stop and restart mysql/mariadb server before and
                           after copies ('yes', 'no', 'ask'). Default is 'ask'
      -n, --no             Will answer 'no' to any question
      -r, --root=PARTNUM   root partition number on SRC device
                           mandatory if and only if SRC is provided
      -y, --yes            Will answer 'yes' to any question

SRC and DST have strong constraints on partitions schemes and naming.
Type '$CMD --man' for more details
_EOF
    return 0
}

# log function
# parameters:
# -l, -s: long, or short prefix (default: none). Last one is used.
# -t: timestamp
# -n: no newline
log() {
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

# prints out and run (maybe) a command.
echorun_maybe() {
    if [[ "$DRYRUN" == 'yes' ]]; then
        log "dry-run: %s" "$*"
    else
        log "%s" "$*"
        "$@"
    fi
}

yesno() {
    local reason answer

    # shellcheck disable=SC2059
    printf -v reason "*** $1 [y/n/q] ? " "${@:2}"

    while true; do
        if [[ $YESNO =~ ^(yes|no)$ ]]; then
            answer="$YESNO"
            # shellcheck disable=SC2059
            printf "$reason%s\n" "$answer"
        else
            read -p "$reason" -r answer
        fi
        case "${answer,,}" in
            y|yes) return 0
                   ;;
            n|no) return 1
                  ;;
            q|quit) printf "Aborting...\n"
                    exit 1
        esac
    done
}

# mariadb start/stop
mariadb_maybe_stop() {
    [[ $MARIADBSTOPPED == yes ]] && return 0
    if systemctl is-active --quiet mysql; then
        if [[ $MARIADB == ask ]]; then
            if yesno "Stop MariaDB/MySQL"; then
               MARIADB=yes
            else
               MARIADB=no
            fi
        fi
        if [[ $MARIADB == no ]]; then
            log "Warning: MariaDB/MySQL is running, database corruption possible on DEST disk."
            return 0
        fi
        echorun_maybe systemctl stop mariadb
        # bug if script stops here
        MARIADBSTOPPED=yes
    else
        log "MariaDB/MySQL is inactive."
    fi
}

mariadb_maybe_start() {
    if [[ $MARIADB == yes && $MARIADBSTOPPED == yes ]]; then
        #log -n "restarting mariadb/mysql... "
        echorun_maybe systemctl start mariadb
        MARIADBSTOPPED=no
        #log "done."
    fi
}

error_handler() {
    local ERROR=$2
    log "FATAL: Error line $1, exit code $2. Aborting."
    exit "$ERROR"
}
trap 'error_handler $LINENO $?' ERR SIGHUP SIGINT SIGTERM

exit_handler() {
    local mnt

    # log "exit handler (at line $1)"
    mariadb_maybe_start
    if [[ -n "$DSTMNT" ]] && mountpoint -q "$DSTMNT"; then
        for mnt in "$DSTMNT"/{dev,proc,sys}; do
            if mountpoint -q "$mnt"; then
                # https://unix.stackexchange.com/questions/693346
                if ! echorun_maybe umount "$mnt"; then
                    echorun_maybe umount --lazy "$mnt"
                fi
            fi
        done
    fi
}
trap 'exit_handler $LINENO' EXIT

# check_block_device - check a file system device
# $1: device description
# $2: more ('w' for writable)
# $3: device
check_block_device() {
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

# check that /etc/fstab.DESTLABEL exists in SRC disk.
check_fstab() {
    local etc="${AUTOFS_DIR}/$SRCROOTLABEL/etc"
    local fstab="fstab.$DSTROOTLABEL"
    #if [[ "$FSTAB" != no ]]; then
    if [[ ! -f "$etc/$fstab" ]]; then
        FSTAB=no
        log "Warning: No target fstab (%s) on SRC disk" "$etc/$fstab"
    else
        log "Info: Found target fstab (%s) in SRC root partition (%s)." "$fstab" "$etc"
    fi
    return 0
}

fix_fstab() {
    local fstab="${AUTOFS_DIR}/$DSTROOTLABEL/etc/fstab"

    #[[ ! -f "$fstab" ]] && log "Warning: DST fstab will be wrong !" && FSTAB=no
    if [[ "$FSTAB" == ask ]]; then
        yesno "Link %s to %s" "$fstab.$DSTROOTLABEL" "$fstab" && FSTAB=yes || FSTAB=no
    fi
    if [[ "$FSTAB" == no ]]; then
        log "Warning: DST fstab will be *wrong*, boot is compromised"
    else
        echorun_maybe ln -f "$fstab.$DSTROOTLABEL" "$fstab"
    fi
    return 0
}

# check if $1 is in array $2 ($2 is by reference)
in_array() {
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
SRCROOTPARTNUM=""
AUTOFS_DIR=/mnt

DRYRUN=no                                         # dry-run
FSTAB=ask                                         # adjust fstab
GRUB=ask                                          # install grub
COPY=ask                                          # do FS copies
MARIADB=ask                                       # stop/start mysql/mariadb
MARIADBSTOPPED=no                                 # mysql stopped ?
YESNO=                                            # default answer
ROOTCOPIED=no                                     # was root partition copied ?

# short and long options
SOPTS="a:c:df:g:hmM:nr:y"
LOPTS="autofs:,copy:,dry-run,fstab:,grub:,help,man,mariadb:,no,root:,yes"

if ! TMP=$(getopt -o "$SOPTS" -l "$LOPTS" -n "$CMD" -- "$@"); then
    log "Use '$CMD --help' or '$CMD --man' for help."
    exit 1
fi

eval set -- "$TMP"
unset TMP

while true; do
    case "$1" in
        '-a'|'--autofs')
            AUTOFS_DIR="$2"
            shift
            ;;
        '-c'|'--copy')
            case "${2,,}" in
                "no") COPY=no;;
                "yes") COPY=yes;;
                "ask") COPY=ask;;
                *) log "invalid '$2' --copy flag"
                   usage
                   exit 1
            esac
            shift
            ;;
        '-d'|'--dry-run')
            DRYRUN=yes
            ;;
        '-f'|'--fstab')
            case "${2,,}" in
                "no") FSTAB=no;;
                "yes") FSTAB=yes;;
                "ask") FSTAB=ask;;
                *) log "invalid '$2' --fstab flag"
                   usage
                   exit 1
            esac
            shift
            ;;
        '-g'|'--grub')
            case "${2,,}" in
                "no") GRUB=no;;
                "yes") GRUB=yes;;
                "ask") GRUB=ask;;
                *) log "invalid '$2' --grub flag"
                   usage
                   exit 1
            esac
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
        '-n'|'--no')
            YESNO=no
            ;;
        '-M'|'--mariadb')
            case "${2,,}" in
                "no") MARIADB=no;;
                "yes") MARIADB=yes;;
                "ask") MARIADB=ask;;
                *) log "invalid '$2' --mariadb flag"
                   usage
                   exit 1
            esac
            shift
            ;;
        '-r'|'--root')
            SRCROOTPARTNUM="$2"
            if ! [[ "$SRCROOTPARTNUM" =~ ^[[:digit:]]+$ ]]; then
                log "$CMD: $SRCROOTPARTNUM must be a partition number."
                exit 1
            fi
            shift
            ;;
        '--')
            shift
            break
            ;;
        '-y'|'--yes')
            YESNO=yes
            ;;
        *)
            usage
            log 'Internal error!'
            exit 1
            ;;
    esac
    shift
done

# check if current user is root
if (( EUID != 0 )); then
    log "This script must be run as root... Aborting."
    exit 1
fi

case "$#" in
    1)
        if [[ -n "$SRCROOTPARTNUM" ]]; then
            log "$CMD: cannot have --root option for live system."
            log "Use '$CMD --help' or '$CMD --man' for help."
            exit 1
        fi
        # guess root partition disk name
        SRCROOT=$(findmnt -no SOURCE -M /)
        SRCROOTPARTNUM=${SRCROOT: -1}
        SRC="/dev/"$(lsblk -no pkname "$SRCROOT")
        DST="/dev/$1"
        ;;
    2)
        if [[ -z "$SRCROOTPARTNUM" ]]; then
            log "$CMD: missing --root option for non live system."
            log "Use '$CMD --help' or '$CMD --man' for help."
            exit 1
        fi
        SRC="/dev/$1"
        SRCROOT="$SRC$SRCROOTPARTNUM"
        DST="/dev/$2"
        ;;
    0)
        log "Missing destination disk."
        usage
        exit 1
        ;;
    *)
        usage
        exit 1
esac

# check SRC and DST are different, find out their characteristics
if [[ "$SRC" = "$DST" ]]; then
    log "Fatal: destination and source disk are identical (%s)" "$SRC"
    log "Use '%s --help' or '%s --man' for help." "$CMD" "$CMD"
    exit 1
fi
check_block_device "source disk" r "$SRC"
check_block_device "destination disk" w "$DST"
check_block_device "source root partition" r "$SRCROOT"

SRCROOTLABEL=$(lsblk -no label "$SRCROOT")
# strip out last character
ROOTLABEL=${SRCROOTLABEL%%?}

# find out all partitions labels on SRC disk...
# shellcheck disable=SC2207
declare -a SRCLABELS=($(lsblk -lno  LABEL "$SRC"))
# shellcheck disable=SC2206
declare -a LABELS=(${SRCLABELS[@]%?})

# ... and corresponding partition device and fstype
declare -a SRCDEVS SRCFS SRC_VALID_FS
for ((i=0; i<${#SRCLABELS[@]}; ++i)); do
    TMP="${SRCLABELS[$i]}"
    #log "TMP=%s" "$TMP"
    TMPDEV=$(findfs LABEL="$TMP")
    TMPFS=$(lsblk -no fstype "$TMPDEV")
    log "found LABEL=$TMP DEV=$TMPDEV FSTYPE=$TMPFS"
    SRCDEVS[$i]="$TMPDEV"
    SRCFS[$i]="$TMPFS"
    SRC_VALID_FS[$i]=n
    in_array "$TMPFS" VALIDFS && SRC_VALID_FS[$i]=y
    unset TMP TMPDEV TMPFS
done

# find out DST root partition
# shellcheck disable=SC2207
declare -a TMP_DSTLABELS=($(lsblk -lno  LABEL "$DST"))

for maybe_root in "${TMP_DSTLABELS[@]}"; do
    log "rootlabel=%s maybe=%s" "$ROOTLABEL" "$maybe_root"
    if [[ $maybe_root =~ ^${ROOTLABEL}.$ ]]; then
        log "Found destination root label: $maybe_root"
        DSTROOTLABEL=$maybe_root
        DSTCHAR=${DSTROOTLABEL: -1}
        DSTROOT=$(findfs LABEL="$DSTROOTLABEL")
        check_block_device "destination root partition" w "$DSTROOT"
        break
    fi
done

declare -a DSTLABELS DSTDEVS DSTFS DST_VALID_FS
# Do the same for corresponding DST partitions labels, device, and fstype
for ((i=0; i<${#LABELS[@]}; ++i)); do
    TMP="${LABELS[$i]}$DSTCHAR"
    log -n "Looking for [%s] label : " "$TMP"
    if ! TMPDEV=$(findfs LABEL="$TMP"); then
        log "not found."
        exit 1
    fi
    TMPDISK=${TMPDEV%?}
    log -n "DEV=%s DISK=%s " "$TMPDEV" "$TMPDISK"
    if [[ "$TMPDISK" != "$DST" ]]; then
        log "wrong disk (%s != %s)" "$TMPDISK" "$DST"
        exit 1
    fi
    TMPFS=$(lsblk -no fstype "$TMPDEV")
    log "FSTYPE=%s" "$TMPFS"
    DSTLABELS[$i]="$TMP"
    DSTDEVS[$i]="$TMPDEV"
    DSTFS[$i]="$TMPFS"
    DST_VALID_FS[$i]=n
    in_array "$TMPFS" VALIDFS && DST_VALID_FS[$i]=y
    unset TMP TMPDEV TMPFS
done

{
    printf "DEV1 DEV2 LABEL1 LABEL2 FS1 FS2 SVALID\? DVALID\? ROOT\n"
    for ((i=0; i<${#LABELS[@]}; ++i)); do
        log -n "%s %s " "${SRCDEVS[$i]}" "${DSTDEVS[$i]}"
        log -n "%s %s " "${SRCLABELS[$i]}" "${DSTLABELS[$i]}"
        log -n "%s %s "  "${SRCFS[$i]}" "${DSTFS[$i]}"
        log -n "%s %s "  "${SRC_VALID_FS[$i]}" "${DST_VALID_FS[$i]}"
        [[ "$DSTROOTLABEL" == "${DSTLABELS[$i]}" ]] && log "*"
        echo
    done
} | column -t

check_fstab || exit 1

FILTER=--filter="dir-merge .rsync-disk-copy"
declare -a RSYNCOPTS=(-axH "$FILTER" --delete --delete-excluded)
# copy loop
for ((i=0; i<${#LABELS[@]}; ++i)); do
    if [[ "${SRC_VALID_FS[$i]}" != y ]] || [[ "${DST_VALID_FS[$i]}" != y ]]; then
        log "skipping label %s" "${LABELS[$i]}"
        continue
    fi
    SRCPART="$AUTOFS_DIR/${SRCLABELS[$i]}/"
    DSTPART="$AUTOFS_DIR/${DSTLABELS[$i]}"

    #log -n "%s -> %s : " "$SRCPART" "$DSTPART"
    #log "\t%s %s %s %s %s" rsync "${RSYNCOPTS}" "$FILTER" "$SRCPART" "$DSTPART"
    copy="$COPY"
    if [[ "$COPY" == 'ask' ]]; then
        yesno "Copy $SRCPART to $DSTPART" && copy=yes || copy=no
    fi
    if [[ "$copy" == yes ]]; then
        mariadb_maybe_stop
        status=0
        # shellcheck disable=SC2086
        echorun_maybe rsync "${RSYNCOPTS[@]}" "$SRCPART" "$DSTPART" || status=$?
        if (( status != 24 && status != 0 )); then
            log -s "rsync error %d" "$status"
            exit 1
        fi

        if [[ "$DSTROOTLABEL" == "${DSTLABELS[$i]}" ]]; then
            ROOTCOPIED=yes
            fix_fstab
        fi
    fi
    #log ""
done
mariadb_maybe_start

# grub install
if [[ $GRUB == ask ]]; then
    if ! yesno "install grub on %s (root label: %s)" "$DST" "$DSTROOTLABEL"; then
        GRUB=no
    fi
fi
if [[ $GRUB == no ]]; then
    if [[ $ROOTCOPIED == yes ]]; then
        log "Warning: root filesystem changed, and skipping grub install on %s, boot will probably fail." "$DST"
    else
        log "Warning: Skipping grub install on %s." "$DST"
    fi
else
    log "installing grub on $DST..."

    DSTMNT="$AUTOFS_DIR/$DSTROOTLABEL"
    # mount virtual devices
    echorun_maybe mount -o bind /sys  "$DSTMNT/sys"
    echorun_maybe mount -o bind /proc "$DSTMNT/proc"
    echorun_maybe mount -o bind /dev  "$DSTMNT/dev"

    echorun_maybe chroot "$DSTMNT" update-grub
    echorun_maybe chroot "$DSTMNT" grub-install "$DST"
fi

exit 0
