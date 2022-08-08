#!/usr/bin/env bash
#
# gen-passwd.sh - a simple password generator.
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
#       gen-passwwd.sh - a simple password generator.
#
# SYNOPSIS
#       gen-passwd.sh [OPTIONS] TYPE [LENGTH]
#
# DESCRIPTION
#       Generate a random TYPE password with length LENGTH.
#       Available types are :
#       dice
#          A list of digits in range [1-6]. Default length is 5. The purpose of
#          this is only to help choosing a word in a diceware word list.
#       mac
#          A "xx-xx-xx-xx-xx-xx" type address, where 'x' are hexadecimal digits
#          (ranges 0-9 and a-h).
#          Length is the number of "bytes" (groups od 2 hehexademal digits), and
#          defaults to 6. The default ":" delimiter can be changed with "-s"
#          option.
#          This is the default option.
#       pincode
#          A numeric password. default LENGTH is 4, with no separator.
#       passphrase
#          Generate words from a diceware-like dictionary. Length is the number
#          of words ans defaults to 6.
#
# OPTIONS
#       -c, --copy
#          Copy password to clipboard.
#
#       -C, --capitalize
#          For 'passphrase' and 'mac' type only.
#          Passphrase: Capitalize words (first letter of each word). Recommended
#          if separator is set to null-string (--separator=0).
#          Mac: use capital hexadecimal digits.
#
#       -d, --dictionary=file
#          Use file as wordlist file. Default is
#
#       -g, --gui
#          Will use a GUI (yad based) to propose the password. This GUI
#          simply displays the password, allows to copy it to clipboard,
#          and to re-generate a new password.
#
#       -h, --help
#          Display usage and exit.
#
#       -m, --man
#          Print a man-like help and exit.
#
#       -s, --separator=CHAR
#          CHAR is used as separator when TYPE allows it. Use "0" to remove
#          separators.
#
#       -v, --verbose
#          Print messages on what is being done.
#
# EXAMPLES
#       TODO
#
# TODO
#       Add different languages wordlists.
#
# AUTHOR
#       Bruno Raoult.
#
# SEE ALSO
#       Pages on Diceware/words lists :
#       EFF: https://www.eff.org/dice
#       diceware: https://theworld.com/~reinhold/diceware.html
#
#
#%MAN_END%

SCRIPT="$0"                                       # full path to script
CMDNAME=${0##*/}                                  # script name
SHELLVERSION=$(( BASH_VERSINFO[0] * 10 + BASH_VERSINFO[1] ))

# default type, length, separator
declare pw_type="mac"
declare pw_length=6
declare pw_sep=":"
declare pw_cap=""
declare pw_dict=""
declare pw_copy=""
declare pw_gui=""
declare pw_verbose=""
declare -A pw_commands=()
declare -a pw_command=()

usage() {
    printf "usage: %s [-s CHAR][-d DICT][-Ccgmv] [TYPE] [LENGTH]\n" "$CMDNAME"
    return 0
}

man() {
    sed -n '/^#%MAN_BEGIN%/,/^#%MAN_END%$/{//!s/^#[ ]\{0,1\}//p}' "$SCRIPT" | more
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
    [[ -z $pw_verbose ]] && return 0
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

# srandom() - use RANDOM to simulate SRANDOM
# $1: Reference of variable to hold result
#
# Note: RANDOM is 15 bits, SRANDOM is 15 bits.
#
# @return: 0, $1 will contain the 32 bits random number
srandom() {
    local -n _ret=$1

    (( _ret = RANDOM << 17 | RANDOM << 2 | RANDOM & 3 ))
}

# rnd() - get a random number integer
# $1: An integer, the modulo value
#
# @return: 0, output a string with the random integer on stdout.
#
# This function uses SRANDOM for bash >= 5.1 and srandom() function
# above for lower versions.
rnd() {
    local mod=$1 ret

    if (( SHELLVERSION >= 51 )); then
        # shellcheck disable=SC2153
        (( ret = SRANDOM ))
    else
        srandom ret
    fi
    printf "%d" "$(( ret % mod ))"
}

# rnd_hex() - get a random 2-digits hex number
#
# @return: 0, output a string with the random integer on stdout.
rnd_hex() {
    printf "%02x" "$(rnd 256)"
}

# rnd_dice() - get a 6 faces 1-6 random number
#
# @return: 0, output a string {1..6}
rnd_dice() {
    printf "%d" "$(( $(rnd 6) + 1 ))"
}

# rnd_digit() - get a digit random number
#
# @return: 0, output a string {0..9}
rnd_digit() {
    printf "%d" "$(( $(rnd 10) ))"
}

# rnd_word() - get a word from file
# $1: The dice rolls
# $2: The word list file ()
#
# @return: 0, output a string {0..9}
rnd_word() {
    local roll="$1" file="$2" word=""

    word=$(sed -n "s/^${roll}[[:blank:]]\+//p" "$file")
    printf "%s" "$word"
}

# rnd_charset() - get a random string from a charset
# $1: A string with characters to choose from
# $2: An integer
#
# @return: 0, output a random string from charset $1, with length $2.
rnd_charset() {
    local charset="$1" ret=""
    local -i len=$2 _i

    for ((_i=0; _i<len; ++_i)); do
        ret+=${charset:$(rnd ${#charset}):1}
    done

    printf "%s" "$ret"
}

# pwd_dice() - get a random dice style string
# $1: Integer, the number dice runs
# $2: Separator
#
# @return: 0, output dice rolls
pwd_dice() {
    local -i i n="${1:-6}"
    local sep="" _sep="${2}"
    local str="" _str=""

    for ((i = 0; i < n; ++i)); do
        printf -v _str  "%s%s" "$sep" "$(rnd_dice)"
        str+="$_str"
        sep="$_sep"
    done
    printf "%s" "$str"
    return 0
}
pw_commands["dice"]=pwd_dice

# pwd_mac() - get a random MAC-address style string
# $1: Integer, the number of hex values
# $2: Separator
# $3: Capitalize
#
# @return: 0, output a random MAC-address style string.
pwd_pincode() {
    local -i i n="${1:-6}"
    local sep="" _sep="${2}" _cap="$3"
    local str="" _str=""

    for ((i = 0; i < n; ++i)); do
        printf -v _str  "%s%s" "$sep" "$(rnd_digit)"
        str+="$_str"
        sep="$_sep"
    done
    [[ -n $_cap ]] && str=${str^^}
    printf "%s" "$str"
    return 0
}
pw_commands["pincode"]=pwd_pincode

# pwd_mac() - get a random MAC-address style string
# $1: Integer, the number of hex values (default: 6)
# $2: Separator (default: "-")
# $3: Capitalize (default: "")
#
# @return: 0, output a random MAC-address style string.
pwd_mac() {
    local -i i n="$1"
    local sep="" _sep="${2}" _cap="$3"
    local str="" _str=""

    for ((i = 0; i < n; ++i)); do
        str+="$sep$(rnd_hex)"
        sep="$_sep"
    done
    [[ -n $_cap ]] && str=${str^^}
    printf "%s" "$str"
    return 0
}
pw_commands["mac"]=pwd_mac

# pwd_passphrase() - get a list of words from a diceware-style file
# $1: Integer, the number of words
# $2: Separator
# $3: Capitalize
# $4: diceware file
#
# @return: 0, output a random MAC-address style string.
pwd_passphrase() {
    local -i i n="$1" _digits=0
    local sep="" _sep="${2}" _cap="$3" _file="$4"
    local str="" _str="" _key="" _dummy=""

    # get the number of digits from 1st file line
    read -r _key _dummy < "$_file"
    _digits=${#_key}
    log "passphrase setup: key 1=%s digits=%d" "$_key" "$_digits"

    for ((i = 0; i < n; ++i)); do
        _key=$(pwd_dice "$_digits" "")
        _str=$(rnd_word "$_key" "$_file")
        [[ -n $_cap ]] && _str=${_str^}
        log "passphrase: key=%s str=%s" "$_key" "$_str"
        str+="$sep$_str"
        sep="$_sep"
    done
    printf "%s" "$str"
    return 0
}
pw_commands["passphrase"]=pwd_passphrase

# print command() - print a pwd_command parameters
# $1: reference of pwd_command array
#
# @return: 0
print_command() {
    local -n arr="$1"
    local -a label=("function" "length" "sep" "cap" "dict")
    local -i i
    for i in "${!arr[@]}"; do
        log -s "%s=[%s]" "${label[$i]}" "${arr[$i]}"
    done
    return 0
}

# gui_passwd() - GUI for passwords
# $1: reference pwd_command array
#
# @return: 0
gui_passwd() {
    local -a _command=("$@")
    local passwd="" res=0

    while
        passwd=$("${_command[@]}")
        yad --title="Password Generator" --text-align=center --text="$passwd" \
            --borders=20 --button=gtk-copy:0 --button=gtk-refresh:1 \
            --button=gtk-ok:252 --window-icon=dialog-password
        res=$?
        log "res=%d\n" "$res"
        if ((res == 0)); then
            log "%s" "$passwd" | xsel -bi
        fi
        ((res == 1))
    do true;  done
    return $res
}

parse_opts() {
    # short and long options
    local sopts="cCd:ghms:v"
    local lopts="copy,capitalize,dictionary:,gui,help,man,separator:,verbose"
    # set by options
    local tmp="" tmp_length="" tmp_sep="" tmp_cap="" tmp_dict=""

    if ! tmp=$(getopt -o "$sopts" -l "$lopts" -n "$CMD" -- "$@"); then
        log "Use '$CMD --help' or '$CMD --man' for help."
        exit 1
    fi

    eval set -- "$tmp"

    while true; do
        case "$1" in
            '-c'|'--copy')
                pw_copy=y
                ;;
            '-C'|'--capitalize')
                tmp_cap=y
                ;;
            '-d'|'--dictionary')
                tmp_dict="$2"
                shift
                ;;
            '-g'|'--gui')
                pw_gui="$2"
                ;;
            '-h'|'--help')
                usage
                exit 0
                ;;
            '-m'|'--man')
                man
                exit 0
                ;;
            '-s'|'--separator')
                tmp_sep="$2"
                shift
                ;;
            '-v'|'--verbose')
                pw_verbose=y
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

    # parse arguments
    if (($# > 0)); then                               # type
        type=$1
        case "$type" in
            dice)
                pw_type="dice"
                tmp_length=5
                [[ -z $tmp_sep ]] && tmp_sep=" "
                ;;
            mac)
                pw_type="mac"
                tmp_length=6
                [[ -z $tmp_sep ]] && tmp_sep=":"
                ;;
            pincode)
                pw_type="pincode"
                tmp_length=4
                [[ -z $tmp_sep ]] && tmp_sep="0"
                ;;
            passphrase)
                pw_type="passphrase"
                tmp_length=6
                [[ -z $tmp_dict ]] && tmp_dict="eff_large_wordlist.txt"
                [[ -z $tmp_sep ]] && tmp_sep=" "
                [[ -z $tmp_cap ]] && tmp_cap=""
                ;;
            *)
                printf "%s: Unknown '%s' password type.\n" "$CMDNAME" "$type"
                usage
                exit 1
        esac
        shift
    fi
    if (($# > 0)); then                               # length
        if ! [[ $1 =~ ^[0-9]+$ ]]; then
            printf "%s: Bad '%s' length.\n" "$CMDNAME" "$1"
            usage
            exit 1
        fi
        tmp_length="$1"
        shift
    fi
    [[ -n $tmp_length ]] && pw_length=$tmp_length
    if ! (( pw_length )); then
        printf "%s: Bad '%d' length.\n" "$CMDNAME" "$tmp_length"
        usage
        exit 1
    fi
    [[ -n $tmp_sep   ]] && pw_sep=$tmp_sep
    [[ $pw_sep = "0" ]] && pw_sep=""
    [[ -n $tmp_cap   ]] && pw_cap=$tmp_cap
    [[ -n $tmp_dict  ]] && pw_dict=$tmp_dict
}

parse_opts "$@"

pw_command=("${pw_commands[$pw_type]}" "$pw_length" "$pw_sep" "$pw_cap" "$pw_dict")

#printf "command=%d %s\n" "${#pw_command[@]}" "+${pw_command[*]}+"
print_command pw_command

if [[ -z $pw_gui ]]; then
    passwd=$("${pw_command[@]}")
    if [[ -n $pw_copy ]]; then
        printf "%s" "$passwd" | xsel -bi
    fi
    printf "%s\n" "$passwd"
else
    gui_passwd "${pw_command[@]}"
fi

exit 0

gui_passwd() {
    local passwd="" res=0

    while
        passwd=$(rnd_mac "$@")
        yad --title="Password Generator" --text-align=center --text="$passwd" \
            --borders=20 --button=gtk-copy:0 --button=gtk-refresh:1 --button=gtk-ok:252 \
            --window-icon=dialog-password
        res=$?
        printf "res=%d\n" "$res" >& 2
        if ((res == 0)); then
            printf "%s" "$passwd" | xsel -bi
        fi
        ((res == 1))
    do true;  done
    return $res
}

for i in {0..10}; do
    rnd_charset "abcde"
done
echo
exit 0
gui_passwd "$@"

exit 0
