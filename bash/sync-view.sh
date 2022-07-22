#!/usr/bin/env bash
#
# sync-view.sh - view file versions in a sync.sh backup directory.
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
#       sync-view.sh - list file versions from rsync.sh backups.
#
# SYNOPSIS
#       sync-view.sh [OPTIONS] TARGET
#
# DESCRIPTION
#       List TARGET versions from a sync.sh backup directory.
#
# OPTIONS
#       -1, --unique
#          Skip duplicate files. This option do not apply if TARGET is a
#          directory.
#
#       -a, --absolute-target
#          Do not try to resolve TARGET path.. By default, the script will try to
#          guess TARGET absolute path. This is not possible if current system is
#          different from the the one from which the backup was made, or if some
#          path component are missing or were changed.
#          If this option is used, TARGET must be an absolute path as it was on
#          backuped machine.
#
#       -b, --backupdir=DIR
#          DIR is the local mount point where the backups can be found. It can
#          be a network mount, or the destination directory if the backup was
#          local.
#
#       -c, --config
#          A sync.sh configuration file where the script could find variables
#          SOURCEDIR (option '-r') and BACKUPDIR (option '-b').
#
#       -d, --destdir
#          Directory which will hold links to actual files. It will be created
#          if non-existant. If this option is missing, a temporary directory will
#          be created in /tmp.
#
#       -h, --help
#          Display short help and exit.
#
#       -m, --man
#          Display a "man-like" description and exit.
#
#       -r, --root=DIR
#          DIR is the path of the backup source. If '-c' option is used, the
#          variable SOURCEDIR will be used. By default '/'.
#
#       -v, --verbose
#          Print messages on what is being done.
#
#       -x, --exclude=REGEX
#          Filenames matching REGEX (with relative path to backup directory,
#          as specified with '-b' option) will be excluded. This option can be
#          useful
#
# EXAMPLES
#       The next command will list all .bashrc versions for current user, from
#       backups in /mnt/backup. yearly and monthly-03 to monthly-09 are
#       excluded. Source directory (-r) of backups are taken from sync.sh
#       configuration file named s.conf. A temporary directory will be created
#       in /mnt to handle links to actual files.
#       $ sync-view.sh -c s.conf -b /mnt/backup -x "^(yearly|monthly-0[3-9]).*$" ~/.bashrc
#
#       Links to user's .bashrc backups will be put in /tmp/test. Files are in
#       /mnt/backup, which contains backups of /export directory. The /tmp/test
#       directory will be created if necessary.
#       $ sync-view.sh -r /export -b /mnt/backup -d /tmp/test ~/.bashrc
#
# AUTHOR
#       Bruno Raoult.
#
#%MAN_END%

# internal variables, cannot (and *should not*) be changed unless you
# understand exactly what you do.
SCRIPT="$0"                                       # full path to script
CMDNAME=${0##*/}                                  # script name
HOSTNAME="$(hostname)"

ROOTDIR="/"                                       # root of backup source
BACKUPDIR=""                                      # the local view of backup dirs
TARGETDIR=""                                      # temp dir to hold links

TARGET=""                                         # the file/dir to find
RESOLVETARGET=y                                   # resolve TARGET
UNIQUE=""                                         # omit duplicate files
EXCLUDE=""                                        # regex for files to exclude
VERBOSE=""                                        # -v option
declare -A INODES                                 # inodes table (for -1 option)

# error management
set -o errexit
#set -o xtrace

usage() {
    printf "usage: %s [-b BACKUPDIR][-c CONF][-d DSTDIR][-r ROOTDIR][-x EXCLUDE][-1ahmv] file\n" "$CMDNAME"
    return 0
}

man() {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!s/^#[ ]\{0,1\}//p}' "$SCRIPT" | more
}

# log function
# parameters:
# -l, -s: long, or short prefix (default: none). Last one is used.
# -t: timestamp
# -n: no newline
# This function accepts either a string, either a format string followed
# by arguments :
#   log -s "%s" "foo"
#   log -s "foo"
log() {
    local timestr="" prefix="" newline=y todo OPTIND
    [[ -z $VERBOSE ]] && return 0
    while getopts lsnt todo; do
        case $todo in
            l) prefix=$(printf "*%.s" {1..30})
               ;;
            s) prefix=$(printf "*%.s" {1..5})
               ;;
            n) newline=n
               ;;
            t) timestr=$(date "+%F %T%z ")
               ;;
            *)
               ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ $prefix != "" ]] && printf "%s " "$prefix"
    [[ $timestr != "" ]] && printf "%s" "$timestr"
    # shellcheck disable=SC2059
    printf "$@"
    [[ $newline = y ]] && printf "\n"
    return 0
}

filetype() {
    local file="$1" type="unknown"
    if [[ ! -e "$file" ]]; then
        type="missing"
    elif [[ -f "$file" ]]; then
        type="file"
    elif [[ -d "$file" ]]; then
        type="directory"
    elif [[ -h "$file" ]]; then
        type="symlink"
    elif [[ -p "$file" ]]; then
        type="fifo"
    elif [[ -b "$file" || -c "$file" ]]; then
        type="device"
    fi
    printf "%s" "$type"
    return 0
}

# command-line parsing / configuration file read.
parse_opts() {
    # short and long options
    local sopts="1ab:c:d:hmr:vx:"
    local lopts="absolute-target,unique,backupdir:,config:,destdir:,help,man,root:,verbose,exclude:"
    local tmp tmp_destdir="" tmp_destdir="" tmp_rootdir="" config

    if ! tmp=$(getopt -o "$sopts" -l "$lopts" -n "$CMD" -- "$@"); then
        log "Use '$CMD --help' or '$CMD --man' for help."
        exit 1
    fi

    eval set -- "$tmp"

    while true; do
        case "$1" in
            -1|--unique)
                UNIQUE=yes
                ;;
            '-a'|'--absolute-target')
                RESOLVETARGET=""
                ;;
            '-b'|'--backupdir')
                tmp_backupdir="$2"
                shift
                ;;
            '-c'|'--config')
                config="$2"
                if [[ ! -r "$config" ]]; then
                    printf "%s: Cannot open %s file. Exiting.\n" "$CMDNAME" "$config"
                    exit 9
                fi
                # shellcheck source=sync-conf-example.sh
                source "$config"
                [[ -n "$SOURCEDIR" ]] && ROOTDIR="$SOURCEDIR"
                shift
                ;;
            '-d'|'--destdir')
                tmp_destdir="$2"
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
            '-r'|'--rootdir')
                tmp_rootdir="$2"
                shift
                ;;
            '-v'|'--verbose')
                VERBOSE=yes
                ;;
            '-x'|'--exclude')
                EXCLUDE="$2"
                shift
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
        shift
    done

    # Now check remaining arguments (configuration file and searched file).
    # The configuration file contains the variable SOURCEDIR, which will allow
    # to find the relative path of TARGET in backup tree.
    # it may also contain BACKUPDIR variable, which the local root of backup
    # tree.
    if (( $# != 1 )); then
        usage
        exit 1
    fi
    TARGET="$1"
    [[ -z $RESOLVETARGET ]] || TARGET="$(realpath -L "$1")"

    [[ -n "$tmp_backupdir" ]] && BACKUPDIR="$tmp_backupdir"
    [[ -n "$tmp_destdir" ]] && TARGETDIR="$tmp_destdir"
    [[ -n "$tmp_rootdir" ]] && ROOTDIR="$tmp_rootdir"
    return 0
}

check_paths() {
    local tmp

    [[ -z "$BACKUPDIR" ]] && printf "%s: backup directory is not set.\n" "$CMDNAME" && \
        ! usage
    [[ -z "$ROOTDIR" ]] && printf "%s: source directory is not set.\n" "$CMDNAME" && \
        ! usage
    if [[ -n "$TARGETDIR" ]]; then
        if [[ ! -e $TARGETDIR ]]; then
            log "Creating destination directory %s." "$TARGETDIR"
            mkdir "$TARGETDIR"
        fi
    else
        tmp="$(basename "$TARGET")"
        TARGETDIR="$(mktemp -d /tmp/"$tmp"-XXXXXXXX)"
        log "%s target directory created." "$TARGETDIR"
    fi
    for var in ROOTDIR BACKUPDIR TARGETDIR; do
        [[ $var = ROOTDIR && -z $RESOLVETARGET ]] && continue
        if [[ ! -d "${!var}" ]]; then
            printf "%s is not a directory.\n" "$var"
            exit 1
        fi
    done
    if ! pushd "$TARGETDIR" > /dev/null; then
        printf "cannot change to directory %s.\n" "$TARGETDIR"
        exit 1
    fi
    # remove existing files
    if [[ -n "$(ls -A .)" ]]; then
        log "Cleaning existing directory %s." "$TARGETDIR"
        for target in *; do
            rm "$target"
        done
    fi
    log "ROOTDIR=[%s]" "$ROOTDIR"
    log "BACKUPDIR=[%s]" "$BACKUPDIR"
    log "TARGETDIR=[%s]" "$TARGETDIR"
    log "TARGET=[%s]" "$TARGET"
    return 0
}

parse_opts "$@"
check_paths

# add missing directories
declare -a DIRS
DIRS=("$BACKUPDIR"/{dai,week,month,year}ly-[0-9][0-9])
log "DIRS=%s" "${DIRS[*]}"

for file in "${DIRS[@]}"; do
    # src is file/dir in backup tree
    _tmp=${TARGET#"$ROOTDIR"}
    [[ $_tmp =~ ^/.*$ ]] || _tmp="/$_tmp"
    src="$file$_tmp"
    #printf "src=%s\n" "$src"
    if [[ ! -e $src ]]; then
        log "Skipping non-existing %s" "$src"
        continue
    fi
    #ls -li "$src"

    # last modification time in seconds since epoch
    inode=$(stat --dereference --printf="%i" "$src")
    date=$(stat --printf="%Y" "$src")
    date_backup=$(stat --dereference --printf="%Y" "$file")
    # target is daily-01, etc...
    #target=$(date --date="@$date" "+%Y-%m-%d %H:%M")" - ${file#"$BACKUPDIR/"}"
    target="${file#"$BACKUPDIR/"}"

    #printf "target=[%s] src=[%s]\n" "$target" "$src"
    if [[ -n $EXCLUDE && $target =~ $EXCLUDE ]]; then
        log "Skipping %s\n" "$file"
        continue
    fi
    if [[ -z $UNIQUE || ! -v INODES[$inode] ]]; then
        log "Adding %s inode %s (%s)" "$file" "$inode" "$target"
        ln -fs "$src" "$TARGETDIR/$target"
    else
        log "Skipping duplicate inode %s (%s)" "$inode" "$target"
    fi
    INODES[$inode]=${INODES[$inode]:-$date}
    INODES[backup-$inode]=${INODES[backup-$inode]:-$date_backup}
done

if [[ -n "$(ls -A .)" ]]; then
    printf "type|modified|inode|size|perms|backup|backup date|path\n"
    # for file in {dai,week,month,year}ly-[0-9][0-9]; do
    for symlink in *; do
        file=$(readlink "$symlink")
        #printf "file=<%s> link=<%s>\n" "$file" "$symlink" >&2
        inode=$(stat --printf="%i" "$file")
        type=$(filetype "$file")
        #links=$(stat --printf="%h" "$file")
        date=$(date --date="@${INODES[$inode]}" "+%Y-%m-%d %H:%M")
        backup_date=$(date --date="@${INODES[backup-$inode]}" "+%Y-%m-%d %H:%M")
        size=$(stat --printf="%s" "$file")
        perms=$(stat --printf="%A" "$file")
        printf "%s|" "$type"
        printf "%s|" "$date"
        #printf "%s|" "$links"
        printf "%s|" "$inode"
        printf "%s|" "$size"
        printf "%s|" "$perms"
        printf "%s|" "$symlink"
        printf "%s|" "$backup_date"
        printf "%s\n" "$file"
        # ls -lrt "$TARGETDIR"
    done | sort -r
fi | column -t -s\|

printf "temporary files directory is: %s\n" "$PWD"
exit 0
