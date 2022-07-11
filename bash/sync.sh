#!/usr/bin/env bash
#
# sync.sh - a backup utility using ssh/rsync facilities.
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
#       sync.sh - a backup utility using ssh/rsync facilities.
#
# SYNOPSIS
#       sync.sh [OPTIONS] CONFIG
#
# DESCRIPTION
#       Perform a backup to a local or remote destination, keeping different
#       versions (daily, weekly, monthly, yearly). All options can be set in
#       CONFIG file, which is mandatory.
#       The synchronization is make with rsync(1), and only files changed or
#       modified are actually copied; files which are identical with previous
#       backup are hard-linked to previous one.
#
# OPTIONS
#       -a PERIOD
#          Indicate which backup(s) should be done. PERIOD is a string composed
#          of one or more of 'y', 'm', 'w', and 'd', indicating respectively
#          yearly, monthly, weekly and daily backups.
#          Multiple -a may appear. For example, if we wish to perform a daily,
#          monthly, and yearly backup, we can use syntax like :
#              -a m -a y -a d
#              -adm -ay
#              -a ymd
#          If this option is not used, and none of the equivalent variables
#          (YEARLY, MONTHY, WEEKLY, DAILY) is set to "y" in configuration
#          file, the script will determine itself what should be done,
#          depending on the current day or date: daily backup every day,
#          weekly every sunday, monthly every first day of month, and yearly
#          every Jan 1st.
#       -D
#          By default, this script re-routes all outputs (stdout and stderr)
#          to a temporary file after basic initialization (mainly options
#          checks and configuration file evaluation), so that we can format
#          the output before displaying or mailing it.
#          This option disables this redirection. It is useful (together with
#          bash's -x option) when some errors are difficult to track.
#       -f
#          Filter some rsync output, such as hard and soft links, dirs, etc.
#       -l
#          Keep log file (usually /tmp/sync-log-PID).
#       -m
#          Display a "man-like" description and exit.
#       -n
#          Do not send mail report (which is the default if MAILTO environment
#          is set). Practically, this option only unsets MAILTO.
#       -r
#          Resume an interrupted transfer (rsync --partial option). It should
#          be safe to use this option, as it has no effect in usual case.
#       -u
#          Use numeric IDs (UID and GID) instead of usernames/groupnames. This
#          could be preferable in case of backup, to avoid any issue when
#          getting back the file (for instance via a mount).
#       -v
#          Add sub-tasks information, with timestamps. This option is currently
#          not implemented.
#       -z
#          Enable rsync compression. Should be used when the transport is more
#          expensive than CPU (typically slow connections).
#       -Z
#          By default, if gzip utility is available, the email log attachment
#          is compressed. This option will prevent any compression.
#
# GENERAL
#       You should avoid modifying variables in this script.
#       Instead, use the configuration file, whenever possible.
#
#       All options can be set in configuration file (which will always have
#       the "last word"). Please check the "getopts" section in the code below.
#
#       By default, the output is displayed (or mailed) when the script exits.
#       The -D option allows to get real-time output.
#
# PREREQUISITES
#       The following must be installed, configured, and within your PATH :
#       ssh
#          Ensure your ssh setup is correct: You must be able to ssh the target
#          machine without password.
#       sendmail/postfix (or any MTA providing the sendmail command)
#          Your MTA must be properly configured to send emails. For example
#          you should receive an email with the following command :
#             echo "Subject: sendmail test" | sendmail -v youremail@example.com
#
#       Additionnaly, you will also need the "base64" and "gzip" utilities.
#
#       NOTE: If you run this script via cron(8), please remember that PATH is
#       different. For example, on some systems, cron's default PATH is
#       "/usr/bin:/bin". Should sendmail binary be in /usr/sbin on your system,
#       you will have to change PATH in your crontab.
#
# CONFIGURATION FILE
#       TODO: Write documentation. See example (sync-conf-example.sh).
#
# AUTHOR
#       Bruno Raoult.
#
#%MAN_END%
#
# BUGS
#       Many.
#       This was written for a "terastation" NAS server, which is a kind of
#       light Linux running busybox and an old version of rsync. Therefore,
#       some useful rsync options were not used (such as server logs, etc).
#       This script has been tested on Linux/MacOS clients, with bash versions
#       3.X and 4.X. Associative arrays cannot be used in bash < V4. Therefore
#       the code is not as efficient as it could be.
#
# TODO
#       - allow a reverse backup (from remote to local). Would be useful for
#         non-rooted Android devices (rooted ones could probably run the script
#         by themselves - to be confirmed.
#       - add more logs options (maybe with a mask?)
#       - replace y/n values with empty/not-empty. A step to avoid config file
#       - set default compress value on local/non-local. Step to avoid config
#         file
#       - manage more errors (instead of relying on traps)
#       - the deletion of oldest backup directories takes ages. This could be
#         avoided (for example we could move them to a temp dir and remove it
#         in background).
#       - configuration file could be avoided by adding a few options, such
#         as source and destination directories, and maybe also an rsync
#         exclude pattern (or more generally some more options to rsync).
#       - rewrite exit_handler which is really ugly.
#       - instead of filtering output, it could be better to create the
#         destination from the previous backup, and perform a usual backup
#         on this new directory. This should be easy, but my guess is that
#         it could be slower (1 first pass on server is added before the
#         normal backup).
#       - replace bash's getopts for a better options parsing tool, such as
#         GNU's getopt(1) could be an option, but not available everywhere
#         (for example on MacOS). Likely impossible to keep this script portable.
#

###############################################################################
#########################  options default values
###############################################################################
# These ones can be set by command-line and in configuration file.
# priority is given to configuration file.
YEARLY=n                        # (-ay) yearly backup (y/n)
MONTHLY=n                       # (-am) monthly backup (y/n)
WEEKLY=n                        # (-aw) weekly backup (y/n)
DAILY=n                         # (-ad) daily backup (y/n)
FILTERLNK=n                     # (-f) rsync logs filter: links, dirs... (y/n)
RESUME=n                        # (-r) resume backup (y/n)
COMPRESS=""                     # (-z) rsync compression
NUMID=""                        # (-u) use numeric IDs
#VERBOSE=0                       # TODO: (-v) logs level (0/1)
DEBUG=n                         # (-D) debug: no I/O redirect (y/n)
MAILTO=${MAILTO:-""}            # (-n) mail recipient. -n sets it to ""
ZIPMAIL="gzip"                  # (-Z) zip mail attachment
KEEPLOGFILE=n                   # (-l) keep log file

# options only settable in config  file.
NYEARS=3                        # keep # years (int)
NMONTHS=12                      # keep # months (int)
NWEEKS=6                        # keep # weeks (int)
NDAYS=10                        # keep # days (int)
declare -a RSYNCOPTS=()         # other rsync options
SOURCEDIR=""                    # source dir
SERVER=""                       # backup server
DESTDIR=""                      # destination dir
MODIFYWINDOW=1                  # accuracy for mod time comparison

# these 2 functions can be overwritten in data file, to run specific actions
# just before and after the actual sync
beforesync() {
    log "calling default beforesync..."
}
aftersync() {
    log "calling default aftersync..."
}

# internal variables, cannot (and *should not*) be changed unless you
# understand exactly what you do.
# Some variables were moved into the code (example: in the log() function),
# for practical reasons, the absence of associative arrays being one of them.
SCRIPT="$0"                     # full path to script
CMDNAME=${0##*/}                # script name
PID=$$                          # current pricess PID
LOCKED=n                        # indicates if we created lock file.
STARTTIME=$(date +%s)           # time since epoch in seconds
HOSTNAME="$(hostname)"
declare -A ERROR_STR=(          # error strings
    [0]="ok"
    [1]="error"
    [2]="missing command"
    [3]="source directory error"
    [4]="could not create lock file"
    [5]="could not rotate backup directories"
    [6]="partial backup detected"
    [7]="rsync error"
    [8]="invalid command line"
    [9]="missing configuration file"
    [10]="missing destination directory"
    [11]="cannot acquire lock"
    [12]="cannot determine PID of locked directory"
    [13]="error in rotation"
    [14]="could not set modification time on target"
    [15]="error on non-daily tree copy"
)

###############################################################################
#########################  helper functions
###############################################################################
man() {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!s/^#[ ]\{0,1\}//p}' "$SCRIPT" | more
}

usage() {
    printf "usage: %s [-a PERIOD][-DflmnruvzZ] config-file\n" "$CMDNAME"
    exit 8
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
            *) ;;
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

# prints out and run a command. Used mainly for rsync debug.
echorun () {
    log "%s" "$*"
    "$@"
    return $?
}

# lock system
lock_lock() {
    local opid pidfile="$LOCKDIR/pid"
    #log -n "Setting lock: "
    log "Acquire lock (%s), pid=%d" "$LOCKDIR" "$PID"
    if [[ -d "$LOCKDIR" ]]; then
        if [[ -r "$pidfile" ]]; then
            read -r opid < "$pidfile"
            if ps -p "$opid" &> /dev/null; then
                log "PID %d (in %s) still active. Exiting." "$opid" "$pidfile"
                exit 11
            fi
            log "Stale lock file found (pid=%d), forcing unlock... " "$opid"
            lock_unlock -f
            log "Re-Acquire lock (%s), pid=%d" "$LOCKDIR" "$PID"
        else
            log "lockdir exists with unknown PID"
            exit 12
        fi
    fi
    if ! mkdir "$LOCKDIR"; then
        log "Cannot create lock file. Exiting."
        exit 4
    fi
    printf "%d\n" "$PID" >> "$pidfile"
    LOCKED=y
    return 0
}

lock_unlock() {
    local force=n
    [[ $# == 1 && $1 == -f ]] && force=y
    if [[ "$force" = y || "$LOCKED" = y ]]; then
        if [[ "$force" = y ]]; then
            log "Forced lock release (%s)" "$LOCKDIR"
        else
            log "Release lock (%s)" "$LOCKDIR"
        fi
        rm -vrf "$LOCKDIR"
    else
        log "Nothing to unlock (%s)" "$LOCKDIR"
    fi
    return 0
}

# Error handler.After these basic initializations, errors will be managed by the
# following handler. It is better to do this before the redirections below.
error_handler() {
    local line="$1" err="$2"
    printf "FATAL: Error line %s, exit code %s. Aborting.\n" "$line" "$err"
    exit "$err"
}

exit_handler() {
    local -i status="$?"
    local error="${ERROR_STR[$status]}"
    local subject="$CMDNAME: $SOURCEDIR on $HOSTNAME"
    # we dont need lock file anymore (another backup could start from now).
    lock_unlock

    if (( status == 0 )); then
        subject="$subject (Success)"
    else
        subject="$subject (Failure: $error)"
    fi

    log -l -t "Ending backup."

    if [[ $DEBUG = n ]]; then
        # restore stdout (not necessary), set temp file as stdin, close fd 3.
        # remove temp file (as still opened by stdin, will still be readable).
        exec 1<&3 3>&- 0<"$TMPFILE"
        [[ $KEEPLOGFILE = n ]] && rm -f "$TMPFILE"
    else
        exec 0<<<""             # force empty input for the following
    fi

    SECS=$(( $(date +%s) - STARTTIME ))

    # Warning: no logs allowed here (before next braces), as stdout will not
    # be handled/filtered.
    {
        # we write these logs here so that they are on top if no DEBUG.
        printf "%s: Exit code: %d (%s) " "$CMDNAME" "$status" \
               "${ERROR_STR[$status]}"

        printf "in %d seconds (%d:%02d:%02d)\n" \
               $((SECS)) $((SECS/3600)) $((SECS%3600/60)) $((SECS%60))

        [[ $KEEPLOGFILE = y ]] && printf "log file kept at: %s\n" "$TMPFILE"
        printf "\n"
        if [[ -n $FILTERLNK ]]; then
            grep -vE "^(hf|cd|cL)[ \+]"
        else
            cat
        fi
    } |
    {
        if [[ -n $MAILTO ]]; then
            {
                MIMESTR="FEDCBA_0987654321"

                # email header
                printf "To: %s\n" "$MAILTO"
                #printf "From: %s" "$MAILTO"
                printf "Subject: %s\n" "$subject"
                printf "MIME-Version: 1.0\n"
                printf 'Content-Type: multipart/mixed; boundary="%s"\n' "$MIMESTR"
                printf "\n"

                # We write a short information in email's body
                printf "\n--%s\n" "$MIMESTR"
                printf 'Content-Type: text/plain; charset=UTF-8\n'
                printf '\n'

                # send first lines in message body (until the mark line or EOF)
                has_mark_line=0
                while read -r line; do
                    if [[ $line =~ ^\*+\ Mark$ ]]; then
                        has_mark_line=1
                        break
                    fi
                    printf "%s\n" "$line"
                done

                # we prepare attachment only if a mark line was found
                if ((  has_mark_line == 1 )); then
                    printf "\n--%s\n" "$MIMESTR"
                    if [[ "$ZIPMAIL" == cat ]]; then
                        printf 'Content-Type: text/plain; charset=UTF-8\n'
                        printf 'Content-Disposition: attachment; filename="sync-log.txt"\n'
                    else
                        printf "Content-Type: application/gzip\n"
                        printf 'Content-Disposition: attachment; filename="sync-log.txt.gz"\n'
                    fi
                    printf "Content-Transfer-Encoding: base64\n"
                    printf '\n'
                    $ZIPMAIL | base64
                fi
                printf "\n--%s--\n" "$MIMESTR"
            } | sendmail -it
        else
            grep -vE "^\*+\ Mark$"
        fi
    }
}

###############################################################################
#########################  Options/Environment setup
###############################################################################
# command-line parsing / configuration file read.
parse_opts() {
    OPTIND=0
    shopt -s extglob                # to parse "-a" option
    while getopts a:DflmnruvzZ todo; do
        case "$todo" in
            a)
                # we use US (Unit Separator, 0x1F, control-_) as separator
                # next line will add US before each char (including 1st one)
                IFS=$'\x1F' read -ra periods <<< "${OPTARG//?()/$'\x1F'}"
                # we skip 1st (empty) ellement of array
                for period in "${periods[@]:1}"; do
                    case "$period" in
                        d) DAILY=y;;
                        w) WEEKLY=y;;
                        m) MONTHLY=y;;
                        y) YEARLY=y;;
                        *) printf '%s: unknown period "%s"\n' "$CMDNAME" "$period"
                           usage
                    esac
                done
                ;;
            f)
                FILTERLNK=y
                ;;
            r)
                RESUME=y
                ;;
            l)
                KEEPLOGFILE=y
                ;;
            m)
                man
                exit 0
                ;;
            n)
                MAILTO=""
                ;;
            z)
                COMPRESS=-y     # rsync compression. Depends on net/CPU perfs
                ;;
            u)
                NUMID="--numeric-ids"
                ;;
            D)
                DEBUG=y
                ;;
            Z)
                ZIPMAIL="cat"
                ;;
            *)
                usage
                ;;
        esac
    done
    # Now check remaining argument (configuration file), which should be unique,
    # and read the file.
    shift $((OPTIND - 1))
    (( $# != 1 )) && usage
    CONFIG="$1"

    if [[ ! -r "$CONFIG" ]]; then
        printf "%s: Cannot open $CONFIG file. Exiting.\n" "$CMDNAME"
        exit 9
    fi
    # shellcheck source=sync-conf-example.sh
    source "$CONFIG"

    LOCKDIR="/tmp/$CMDNAME-$HOSTNAME-${CONFIG##*/}.lock"
}

parse_opts "$@"

# we set backups to be done if none has been set yet (i.e. none is "y").
# Note: we use the form +%-d to avoid zero padding :
# for bash, starting with 0 => octal => 08 is invalid
adjust_targets() {
    if ! [[ "$DAILY$WEEKLY$MONTHLY$YEARLY" =~ .*y.* ]]; then
        (( $(date +%u) == 7 )) && WEEKLY=y
        (( $(date +%-d) == 1 )) && MONTHLY=y
        (( $(date +%-d) == 1 && $(date +%-m) == 1 )) && YEARLY=y
        DAILY=y
    fi
}

adjust_targets

# After these basic initializations, errors will be managed by the
# following handler. It is better to do this before the redirections below.
trap 'error_handler $LINENO $?' ERR SIGHUP SIGINT SIGTERM
trap 'exit_handler' EXIT

# activate exit on error
# set -o errexit errtrace nounset pipefail

# standard descriptors redirection.
# if not DEBUG, save stdout as fd 3, and redirect stdout to temp file.
# in case of DEBUG, we could close stdin, but there could be side effects,
# such as ^C handling, etc... So we keep the keyboard available.
if [[ $DEBUG = n ]]; then
    TMPFILE=$(mktemp /tmp/sync-XXXXXXXX.log)
    exec 3<&1 >"$TMPFILE"     # no more output on screen from now.
fi
exec 2>&1

# prepare list of backups, such as "daily 7 weekly 4", etc...
# the order is important.
TODO=()
[[ $DAILY   = y ]] && (( NDAYS   > 0 )) && TODO+=(daily   "$NDAYS")
[[ $WEEKLY  = y ]] && (( NWEEKS  > 0 )) && TODO+=(weekly  "$NWEEKS")
[[ $MONTHLY = y ]] && (( NMONTHS > 0 )) && TODO+=(monthly "$NMONTHS")
[[ $YEARLY  = y ]] && (( NYEARS  > 0 )) && TODO+=(yearly  "$NYEARS")

log -l -t "Starting %s" "$CMDNAME"
log "Bash version: %s.%s.%s" \
    "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"
log "Hostname: %s" "$HOSTNAME"
log "Operating System: %s on %s" "$(uname -sr)" "$(uname -m)"
log "Config : %s\n" "$CONFIG"
log "Src dir: %s" "$SOURCEDIR"
log "Dst dir: %s" "$SERVER:$DESTDIR"
log "Actions: %s" "${TODO[*]}"
if (( ${#RSYNCOPTS[@]} )); then
    log -n "Rsync additional options (%d): " "${#RSYNCOPTS[@]}"
    for opt in "${RSYNCOPTS[@]}"; do
        log -n '\"%s\" ' "$opt"
    done
    log ""
else
    log "Rsync additional options : None."
fi

log -n "Mail recipient: "
# shellcheck disable=SC2015
[[ -n "$MAILTO" ]] && log "$MAILTO" || log "<unset>"
# shellcheck disable=SC2015
log -n "Compression: " && [[ $ZIPMAIL = gzip ]] && log "gzip" || log "none"

# check availability of necessary commands
declare -a cmdavail=()
declare error=0
log -n "Checking for commands : "
for cmd in rsync base64 sendmail gzip; do
    log -n "%s..." "$cmd"
    if type -P "$cmd" > /dev/null; then
        log -n "ok "
    else
        (( error++ ))
        log -n "NOK "
        case "$cmd" in
            gzip)
                log -n "(compression disabled) "
                ZIPMAIL="cat"
                (( error-- ))   # Not an error
               ;;
            sendmail)
                MAILTO=""       # to get some output in cron
                ;;
        esac
        cmdavail+=("$cmd")
    fi
done
log ""
(( ${#cmdavail[@]} )) && log -s "Please install the following programs: %s." \
                             "${cmdavail[*]}"
(( error > 0 )) && exit 2
unset cmdavail
unset error

# all logs from this point will be in email attachment
log -s "Mark"                   # to separate email body

log -l -t "Starting backup"
# create lock file
lock_lock


# select handling depending on local or networked target (ssh or not).
if [[ $SERVER = local ]]; then  # local backup
    DOIT=""
    DEST="$DESTDIR"
else                            # remote backup
    DOIT="ssh $SERVER"
    DEST="$SERVER:$DESTDIR"
fi

# commands and specific variables.
EXIST="$DOIT test -e"
MOVE="$DOIT mv"
REMOVE="$DOIT rm -rf"
COPYHARD="$DOIT rsync -ar"
TOUCH="$DOIT touch"

# rotate files. arguments are a string and a number. For instance $1=weekly,
# $2=3.
# we first build a list from $2 to zero, with 2 padded digits: 03 02 01 00
# then we remove $1-03, and move $1-02 to $1-03, $1-01 to $1-02, etc...
rotate-files() {
    # shellcheck disable=SC2207
    local -a files=( $(seq -f "$DESTDIR/$1-%02g" "$2" -1 0) )
    log -s -t -n "deleting %s... " "${files[0]##*/}"
    if ! $REMOVE "${files[0]}"; then
        # this should never happen.
        # But I saw this event in case of a file system corruption. Better
        # is to stop immediately instead of accepting strange side effects.
        if $EXIST "${files[0]}" ; then
            log -s "Could not remove %s. This SHOULD NOT happen." "${files[0]}"
            exit 5
        fi
    fi
    log "done."

    log -s -t -n "rotating " "$1"
    while (( ${#files[@]} > 1 )); do
        if $EXIST "${files[1]}" ; then
            log -n "%s... " "${files[1]##*/}"
            if ! $MOVE "${files[1]}" "${files[0]}"; then
                log "error"
                exit 13
            fi

        fi
        unset "files[0]"        # shift and pack array
        files=( "${files[@]}" )
    done
    log "done."
    return 0
}

if [[ ! -d "$SOURCEDIR" ]]; then
    log -s "Invalid source directory (%s)." "$SOURCEDIR"
    exit 3
fi
if ! cd "$SOURCEDIR"; then
    log -s "Cannot cd to %s." "$SOURCEDIR"
    exit 3
fi
if ! $EXIST "$DESTDIR"; then
    log -s 'destination directory (%s) missing.' "$DESTDIR"
    exit 10
fi

# main loop.
while [[ ${TODO[0]} != "" ]]; do
    # these variables to make the script easier to read.
    todo="${TODO[0]}"           # daily, weekly, etc...
    keep="${TODO[1]}"           # # of versions to keep for $todo set
    todop="$DESTDIR/$todo"      # prefix for backup (e.g. "destdir/daily")
    tdest="$todop-00"           # target full path (e.g. "destdir/daily-00")
    ldest="$DESTDIR/daily-01"   # link-dest dir (always daily-01)

    log -l -t "%s backup..." "$todo"

    # check if target (XX-00) directory exists. If yes, we must have the
    # resume option to go on.
    if $EXIST "$tdest"; then
        if [[ $RESUME = n ]]; then
            log -s '%s already exists, and no "resume" option.' "$tdest"
            exit 6
        fi
        log -s "Warning: Resuming %s partial backup." "$todo"
    fi

    # daily backup.
    # as we already checked the existence of the -00 file, we can keep
    # the --partial option safely.
    if [[ $todo = daily ]]; then
        beforesync              # script to run before the sync
        log -s -t "rsync copy..."
        # Do the sync. Run in a subshell to avoid the error handling, as
        # we want to ignore "acceptable" errors, such as:
        #   - "vanished file" (exit code 24).
        #   - others?
        status=0
        echorun rsync \
            -aHixv \
            "${RSYNCOPTS[@]}" \
            $COMPRESS \
            $NUMID \
            --delete \
            --delete-during \
            --delete-excluded \
            --modify-window=$MODIFYWINDOW \
            --partial \
            --link-dest="$ldest" \
            . \
            "$DEST/daily-00" || status=$?
        # error 24 is "vanished source file", and should be ignored.
        if (( status != 24 && status != 0)); then
            log -s "rsync error %d" "$status"
            exit 7
        fi
        if ! $TOUCH "$tdest"; then
            log -s "cannot change %s modification time (error %d)" \
                "$DEST/daily-00" "$status"
            exit 14
        fi
        aftersync               # script to run after the sync
    else                        # non-daily case
        if $EXIST "$ldest"; then
            # if ((status == 0 )); then
            log -s -t "%s update..." "$tdest"
            if ! $COPYHARD --link-dest="$ldest" "$ldest/" "$tdest"; then
                log -s "copyhard error %d" "$status"
                exit 15
            fi
        else
            log "No %s directory. Skipping %s backup." "$ldest" "$todo"
        fi
    fi
    rotate-files "$todo" "$keep"

    # shift and pack TODO array
    unset 'TODO[0]' 'TODO[1]'
    TODO=( "${TODO[@]}" )
done

exit 0

# Indent style for emacs
# Local Variables:
# sh-basic-offset: 4
# sh-indentation: 4
# indent-tabs-mode: nil
# comment-column: 32
# End:
