#!/usr/bin/env bash
#
# sms-free.sh - send SMS to Free Mobile.
#
# (C) Bruno Raoult ("br"), 2022
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
#       sms-free.sh - Send SMS to Free Mobile account.
#
# SYNOPSIS
#       sms-free.sh [OPTIONS] [-k KEYFILE] USER [MESSAGE]
#       sms-free.sh [OPTIONS] [-l LOGIN:PASSWORD] [MESSAGE]
#
# DESCRIPTION
#       Send a SMS to a Free Mobile (french mobile operator). This script will
#       only work for phones numbers for which you have the "SMS key" (see FREE
#       MOBILE SMS SETUP below). Therefore yourself, close relatives, and other
#       people who trust you).
#       MESSAGE is the text to be sent. If missing, it will be read from standard
#       input.
#
# OPTIONS
#       -d, --dry-run
#          Will not send the SMS.
#
#       -h, --help
#          Display usage and exit.
#
#       -l, --login=ACCOUNT:SMSKEY
#          Do not use a KEYFILE, and provide directly the Free Mobile ACCOUNT
#          and SMSKEY.
#
#       -k, --keyfile=KEYFILE
#          Use KEYFILE instead of default ~/data/private/free-sms-keys.txt.
#
#       -m, --man
#          Print a man-like help and exit.
#
#       -v, --verbose
#          Print messages on what is being done.
#
# FREE MOBILE SMS SETUP
#       You should first connect on https://mobile.free.fr/account/, and
#       activate the option "Mes options / Notifications par SMS". You will be
#       given a key.
#
# KEY FILE SYNTAX
#       The key file contains lines of the form:
#            id:login:password
#       id
#          A mnemonic for the user (firstname, etc...), it should be unique.
#       login
#          A valid Free Mobile account number (usually 8 digits).
#       key
#          The SMS key associated with the Free Mobile login (usually a 14
#          alphanumeric string).
#
#       Example:
#       bruno:01234567:abcdeABCDE1234
#       bodiccea:76543210:xyztXYZT123456
#
# AUTHOR
#       Bruno Raoult.
#%MAN_END%
#
# PERSONAL NOTES/TODO
#       In example above, "%20" can be replaced by "+"
#          See: https://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1
#       utf8 characters look supported (tested on French accentuated characters,
#          Japanese kana and kanji, and Chinese)
#
# FREE MOBILE DOCUMENTATION
#
#        L'envoi du SMS se fait en appelant le lien suivant :
#
#        https://smsapi.free-mobile.fr/sendmsg
#        avec les paramètres suivants :
#
#            user : votre login
#            pass : votre clé d'identification générée automatiquement par notre
#                   service
#            msg  : le contenu du SMS encodé sous forme d'url (Percent-encoding)
#
#        Exemple : Envoyer le message "Hello World !" sur votre mobile :
#
#        https://smsapi.free-mobile.fr/sendmsg?user=12345678&pass=abcABC12345678&msg=Hello%20World%20!
#
#        Vous pouvez également, si vous le préférez, envoyer les paramètres en POST.
#        Dans ce cas, le contenu du message n'a pas besoin d'être encodé.
#        Le code de retour HTTP indique le succès ou non de l'opération :
#
#            200 : Le SMS a été envoyé sur votre mobile.
#            400 : Un des paramètres obligatoires est manquant.
#            402 : Trop de SMS ont été envoyés en trop peu de temps.
#            403 : Le service n'est pas activé sur l'espace abonné, ou login / clé
#                  incorrect.
#            500 : Erreur côté serveur. Veuillez réessayer ultérieurement.

#set -x
script="$0"                                       # full path to script
cmdname=${0##*/}                                  # script name
export LC_CTYPE="C.UTF-8"                         # to handle non ascii chars

declare sms_keyfile=~/data/private/free-sms-keys.txt
declare sms_verbose=""
declare sms_credentials=""
declare sms_dryrun=""
declare sms_message=""
declare sms_url="https://smsapi.free-mobile.fr/sendmsg"
declare -A sms_status=(
    [-]="Unknown error"
    [200]="OK"
    [400]="Missing parameter"
    [402]="Too many SMS sent in short time"
    [403]="Service non activated or incorrect credentials"
    [500]="Server error"
)

usage() {
    printf "usage: %s [-hmv] [-k KEYFILE] USER [MESSAGE]\n" "$cmdname"
    printf "       %s [-hmv] [-l LOGIN:PASSWORD] [MESSAGE]\n" "$cmdname"
    printf  "Use '%s --man' for more help\n" "$cmdname"
    return 0
}

man() {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!s/^#[ ]\{0,1\}//p}' "$script" | more
}

# log() - log messages on stderr
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
    [[ -z $sms_verbose ]] && return 0
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
    [[ $prefix != "" ]] && printf "%s " "$prefix" >&2
    [[ $timestr != "" ]] && printf "%s" "$timestr" >&2
    # shellcheck disable=SC2059
    printf "$@" >&2
    [[ $newline = y ]] && printf "\n" >&2
    return 0
}

# echorun() - logs and run (maybe) a command.
# $1: reference of variable which will get the output of command
# $2..$n: command to log and run
echorun() {
    local -n _out="$1"
    shift
    log "%s" "$*"
    [[ -z $sms_dryrun ]] && _out=$("$@")
    return $?
}

# get_credentials() - get credentials from keyfile
# $1: reference of variable which will contain credentials
# $2: keyfile
# $3: user to find
#
# @return: 0 on success
# @return: 1 on file not present or not readable
# @return: 2 if user not found
get_credentials() {
    local -n _cred=$1
    local _keyfile="$2" _user="$3" _name=""
    local -a _keys
    local -i _n

    log "get_credentials: ref=%s user=%s keyfile=%s" "$!_cred" "$_user" "$_keyfile"
    if [[ ! -r "$_keyfile" ]]; then
        printf "%s: cannot read keyfile %s\n" "$cmdname" "$_keyfile"
        return 2
    fi
    readarray -t _keys < "$_keyfile"
    log "keyfile contains %d lines" "${#_keys[@]}"
    for ((_n = 0; _n < ${#_keys[@]}; ++_n)); do
        IFS=: read -r _name _cred <<< "${_keys[$_n]}"
        log -n "key %d: name:[%s] creds:[%s]..." "$_n" "$_name" "$_cred"
        if [[ $_name = "$_user" ]]; then
            log "match"
            return 0
        else
            log "skipping."
        fi
    done
    return 2
}

parse_opts() {
    # short and long options
    local sopts="dhk:l:mv"
    local lopts="dry-run,help,keyfile:,login:,man,verbose"

    if ! tmp=$(getopt -o "$sopts" -l "$lopts" -n "$cmdname" -- "$@"); then
        log "Use '%s --help' or '%s --man' for help." "$cmdname" "$cmdname"
        exit 1
    fi

    eval set -- "$tmp"

    while true; do
        case "$1" in
            '-d'|'--dry-run')
                sms_dryrun=y
                ;;
            '-h'|'--help')
                usage
                exit 0
                ;;
            '-k'|'--keyfile')
                sms_keyfile="$2"
                shift
                ;;
            '-l'|'--login')
                sms_credentials="$2"
                log "sms_creds=%s" "$sms_credentials"
                shift
                ;;
            '-m'|'--man')
                man
                exit 0
                ;;
            '-v'|'--verbose')
                sms_verbose=y
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

    # parse remaining arguments
    case "$#" in
        0)
            # no user, no message: we need sms_credentials
            if [[ -z $sms_credentials ]]; then
                printf "%s: Missing credentials.\n" "$cmdname"
                exit 1
            fi
            ;;
        1|2)
            # get credentials from KEYFILE
            if [[ -z $sms_credentials ]]; then
                get_credentials sms_credentials "$sms_keyfile" "$1" || exit 1
                shift
            else
                # cannot have user and sms_credentials
                (( $# == 2 )) && usage && exit 1
            fi
            if [[ $# == 1 ]]; then
                sms_message="$1"
            else
                readarray sms_message
                printf -v sms_message "%s" "${sms_message[@]}"
                sms_message=${sms_message%$'\n'}          # remove trailing '\n'
            fi
            ;;
        *)
            usage
            ;;
    esac

    log "keyfile=%s" "$sms_keyfile"
    log "credentials=%s" "$sms_credentials"
    log "message=[%s]" "$sms_message"
}

# send-sms() - send SMS (GET method)
send_sms() {
    local _login=${sms_credentials%:*} _pass=${sms_credentials#*:} _res=""

    log "send_sms(): login=%s pass=%s" "$_login" "$_pass"
    echorun _res curl --silent --get --write-out '%{http_code}' \
            --data "user=$_login" \
            --data "pass=$_pass" \
            --data-urlencode "msg=$sms_message" \
            "$sms_url"
    [[ -n $sms_dryrun ]] && _res=200
    log "send_sms(): curl status=%s (%s)" "$_res" \
        "${sms_status[$_res]:-${sms_status[-]}}"
    if [[ $_res != 200 ]]; then
        printf "%s: %s\n" "$cmdname" "${sms_status[$_res]:-${sms_status[-]}}"
    fi
}

parse_opts "$@"
send_sms
exit 0


# Indent style for emacs
# Local Variables:
# sh-basic-offset: 4
# sh-indentation: 4
# indent-tabs-mode: nil
# comment-column: 32
# End:
