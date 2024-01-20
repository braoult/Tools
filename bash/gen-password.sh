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
#          Length is the number of "bytes" (groups of 2 hexadecimal digits), and
#          defaults to 6. The default ":" delimiter can be changed with "-s"
#          option.
#          This is the default option.
#       passphrase
#          Generate words from a diceware-like dictionary. Length is the number
#          of words ans defaults to 6.
#       pincode
#          A numeric password. default LENGTH is 4, with no separator.
#       string
#          Password will be a string taken from different character ranges.
#          By default, alphabetic characters and digits. See -x option for
#          different character sets.
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
#       -d, --dictionary=FILE
#          Use FILE as wordlist file. Default is en-5.
#          FILE will be searched in these directories : root, current directory,
#          and /usr/local/share/br-tools/gen-password directory.
#
#       -g, --gui
#          Will use a GUI (yad based) to propose the password. This GUI
#          simply displays the password, allows to copy it to clipboard,
#          and to re-generate a new password.
#
#       -h, --help
#          Display usage and exit.
#
#       -l, --list-dictionaries
#          Display the list of available dictionaries, with names suitable for
#          the "-d" option.
#
#       -m, --man
#          Print a man-like help and exit.
#
#       -n, --no-similar-chars
#          For "string" type only, this option removes similar characters which
#          could be difficult to differenciate: 0-O, 1-l, 8-B, [], ø-Ø, ~--, ...
#
#       -s, --separator=CHAR
#          CHAR is used as separator when TYPE allows it. Use "0" to remove
#          separators.
#
#       -v, --verbose
#          Print messages on what is being done.
#
#       -x, --extended=RANGE
#          Specify the ranges of string type. Default is "a:1:a1", as lower case
#          alphabetic characters (a-z) and digits (0-9), with at least one letter
#          and one digit. RANGE  is a string composed of:
#          a: lower case alphabetic characters (a-z)
#          A: upper case alphabetic characters (A-Z)
#          e: extra European characters (e.g. À, É, é, Ï, ï, Ø, ø...)
#          1: digits (0-9)
#          x: extended characters set 1: #$%&@^`~.,:;{[()]}
#          y: extended characters set 2: "'\/|_-<>*+!?=
#          k: japanese hiragana: あいうえおかき...
#          When a RANGED character is followed by a ':' exactly one character of
#          this range will appear in generated password: If we want two or more
#          digits, the syntax would be '-x1:1:1'.
#
# TODO
#       Add different languages wordlists.
#       Replace hiragana with half-width katakana ?
#       Add usage examples
#
# AUTHOR
#       Bruno Raoult.
#
# SEE ALSO
#       Pages on Diceware/words lists :
#       EFF: https://www.eff.org/dice
#       diceware: https://theworld.com/~reinhold/diceware.html
#
#%MAN_END%

SCRIPT="$0"                                       # full path to script
CMDNAME=${0##*/}                                  # script name
SHELLVERSION=$(( BASH_VERSINFO[0] * 10 + BASH_VERSINFO[1] ))

export LC_CTYPE="C.UTF-8"                         # to handle non ascii chars

# character sets
declare -A pw_charsets=(
    [a]="abcdefghijklmnopqrstuvwxyz"
    [A]="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    [1]="0123456789"
    [e]="âêîôûáéíóúàèìòùäëïöüãõñçøÂÊÎÔÛÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÃÕÑÇØ¡¿"
    [x]='#$%&@^`~.,:;{[()]}'
    [y]=\''"\/|_-<>*+!?='
    [k]="あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん"
)

# default type, length, separator
declare pw_type="mac"
declare pw_length=6
declare pw_sep=":"
declare pw_cap=""
declare pw_dict=""
declare pw_copy=""
declare pw_gui=""
declare pw_verbose=""
declare pw_no_similar=""
declare pw_charset="a:A:1:aA1"

declare -A pw_commands=()
declare -a pw_command=()

usage() {
    printf "usage: %s [-s CHAR][-d DICT][-x CHARSET][-Ccgmv] [TYPE] [LENGTH]\n" "$CMDNAME"
    printf  "Use '%s --man' for more help\n" "$CMDNAME"
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

# check_dict() - check for dictionary file
# $1: the dictionary filename (variable reference).
#
# @return: 0 on success, $1 will contain full path to dictionary.
# @return: 1 if not found
# @return: 2 if format is wrong
check_dict() {
    local -n dict="$1"
    local tmp_dir tmp_dict tmp_key tmp_dummy

    if [[ -n "$dict" ]]; then
        for tmp_dir in / ./ /usr/local/share/br-tools/gen-password/; do
            tmp_dict="$tmp_dir$dict.txt"
            log -n "checking for %s dictionary... " "$tmp_dict"
            if [[ -f "$tmp_dict" ]]; then
                log -n "found, "
                # shellcheck disable=SC2034
                read -r tmp_key tmp_dummy < "$tmp_dict"
                if ! [[ $tmp_key =~ ^[1-6]+$ ]]; then
                    log "wrong format [%s]" "$tmp_key"
                    return 2
                fi
                log "key length=%d" "${#tmp_key}"
                dict="$tmp_dict"
                return 0
            else
                log "not found."
            fi
        done
        printf "cannot find '%s' dictionary file\n" "$dict"
        exit 1
    fi
    return 0
}

# list_dict() - list available dictionaries.
#
# @return: 0 on success
# @return: 1 on error
list_dict() {
    local datadir="/usr/local/share/br-tools/gen-password" file fn fn2 key dummy
    local -a output
    local -i res=1 cur=0 i

    if [[ -d "$datadir" ]]; then
        printf -v output[0] "#\tlen\tName"
        for file in "$datadir"/*.txt; do
            fn=${file##*/}
            fn=${fn%.txt}
            # shellcheck disable=SC2034
            fn2="$fn"
            if check_dict fn2; then
                (( cur++ ))
                # shellcheck disable=SC2034
                read -r key dummy < "$file"
                printf -v output[cur-1] "%d\t%d\t%s" "$cur" "${#key}" "$fn"
            fi
        done
        if ((cur > 0)); then
            printf "#\tlen\tName\n"
            for (( i = 0; i < cur; ++i )); do
                printf "%s\n" "${output[i]}"
            done
            return 0
        fi
    fi
    printf "No dictionaries found.\n"
    return 1
}

# sanitize() - sanitize string for HTML characters
# $1: string to cleanup
#
# @return: 0, $1 will contain the sanitized string
sanitize() {
    local str="$1"

    str=${str//&/&amp;}
    str=${str//</&lt;}
    str=${str//>/&gt;}
    str=${str//'"'/&quot;}
    log "sanitized string: '%s' -> '%s'" "$1" "$str"
    printf -- "%str" "$str"
}

# srandom() - use RANDOM to simulate SRANDOM
# $1: Reference of variable to hold result
#
# Note: RANDOM is 15 bits, SRANDOM is 32 bits.
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

# shuffle() - shuffle  a string
# $1: The string to shuffle
#
# The string is shuffled using the Fisher–Yates shuffle method :
# https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle
#
# @return: 0,  output the shuffled string to stdout.
shuffle() {
    local _str="$1"
    local _res=""
    local -i _i _len=${#_str} _cur=0

    for (( _i = _len ; _i > 0; --_i )); do
        _cur=$(rnd "$_i")
        _res+=${_str:$_cur:1}
        _str="${_str:0:_cur}${_str:_cur+1}"
    done
    printf "%s" "$_res"
    return  0
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
# $2: An integer, the length of returned string
#
# @return: 0, output a random string from charset $1, with length $2.
rnd_charset() {
    local charset="$1" ret=""
    local -i len=$2 _i

    #log "rnd_charset: %d from  '%s'" "$len" "$charset"
    for ((_i=0; _i<len; ++_i)); do
        ret+=${charset:$(rnd ${#charset}):1}
    done

    #log "rnd_charset: return '%s'" "$ret"
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

# pwd_string() - generate a string from a charset
# $1: Integer, the string length
# $5: The charset definition (e.g. "a:1:")
#
# @return: 0, output a random string from $5 charset.
pwd_string() {
    local -i i n="$1"
    local _charset="${5}" _allchars=""
    local str="" _c="" _char=""

    log "string setup: len=%d charset=[%s]" "$n" "$_charset"
    # finds out mandatory characters and build final charset
    log -n "mandatory chars:"
    for (( i = 0; i < ${#_charset}; ++i )); do
        _c="${_charset:i:1}"
        if [[ ${_charset:i+1:1} == ":" ]]; then
            _char=$(rnd_charset "${pw_charsets[$_c]}" 1)
            log -n " [%s]" "$_char"
            str+="$_char"
            (( i++ ))
        else
            _allchars+=${pw_charsets[$_c]}
        fi
    done
    log ""
    if (( ${#str} < n && ${#_allchars} == 0 )); then
        printf "Fatal: No charset to choose from ! Please check  '-x' option."
        exit 1
    fi

    log -n "generating %d remaining chars:" "$((n-${#str}))"
    for ((i = ${#str}; i < n; ++i)); do
        _char=$(rnd_charset "$_allchars" 1)
        log -n " [%s]" "$_char"
        str+="$_char"
    done
    log ""
    log "string before shuffle : %s" "$str"
    str="$(shuffle "$str")"
    log "string after shuffle : %s" "$str"
    # cut string if too long (may happen if too many mandatory chars)
    (( ${#str} > n)) && log  "truncating '%s' to '%s'" "$str" "${str:0:n}"
    printf "%s" "${str:0:n}"
    return 0
}
pw_commands["string"]=pwd_string

# print command() - print a pwd_command parameters
# $1: reference of pwd_command array
#
# @return: 0
print_command() {
    local -n arr="$1"
    local -a label=("function" "length" "sep" "cap" "dict" "charset")
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
    local passwd="" res=0 sane=""

    while
        passwd=$("${_command[@]}")
        sane=$(sanitize "$passwd")
        yad --title="Password Generator" --text-align=center --text="$sane" \
            --borders=20 --button=gtk-copy:0 --button=gtk-refresh:1 \
            --button=gtk-ok:252 --window-icon=dialog-password
        res=$?
        log "res=%d\n" "$res"
        if (( res == 0 )); then
            printf "%s" "$passwd" | xsel -bi
        fi
        ((res != 252))
    do true;  done
    return $res
}

parse_opts() {
    # short and long options
    local sopts="cCd:ghlmns:vx:"
    local lopts="copy,capitalize,dictionary:,gui,help,list-dictionaries,man,no-similar-chars,separator:,verbose,extended:"
    # set by options
    local tmp="" tmp_length="" tmp_sep="" tmp_cap="" tmp_dict="" tmp_dir=""
    local tmp_charset=""
    local c2="" c3=""
    local  -i  i

    if ! tmp=$(getopt -o "$sopts" -l "$lopts" -n "$CMDNAME" -- "$@"); then
        log "Use '$CMD --help' or 'zob $CMDNAME --man' for help."
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
                if ! type -P "yad" > /dev/null; then
                    printf "%s: Please install 'yad' package tu use 'g' option.\n" \
                           "$CMDNAME"
                fi
                pw_gui="y"
                ;;
            '-h'|'--help')
                usage
                exit 0
                ;;
            '-l'|'--list-dictionaries')
                list_dict
                exit 0
                ;;
            '-m'|'--man')
                man
                exit 0
                ;;
            '-n'|'no-similar-chars')
                pw_no_similar=y
                ;;
            '-s'|'--separator')
                tmp_sep="$2"
                shift
                ;;
            '-v'|'--verbose')
                pw_verbose=y
                ;;
            '-x'|'--extended')
                for (( i = 0; i < ${#2}; ++i)); do
                    c2="${2:i:1}"
                    case "$c2" in
                        a|A|1|x|y|k|e)
                            tmp_charset+="$c2"
                            c3="${2:i+1:1}"
                            if [[ "$c3" == ":" ]]; then
                                tmp_charset+=":"
                                (( i++ ))
                            fi
                            ;;

                        *) printf "unknown character set '%s\n" "${2:$i:1}"
                           usage
                           exit 1
                    esac
                done
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

    # parse remaining arguments
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
                [[ -z $tmp_dict ]] && tmp_dict="en-5"
                [[ -z $tmp_sep ]] && tmp_sep=" "
                [[ -z $tmp_cap ]] && tmp_cap=""
                ;;
            string)
                pw_type="string"
                tmp_length=10
                if [[ -n $pw_no_similar ]]; then
                    pw_charsets[A]="ABCDEFGHIJKLMNPQRSTUVWXYZ"
                    pw_charsets[a]="abcdefghijkmnopqrstuvwxyz"
                    pw_charsets[1]="23456789"
                    pw_charsets[e]="âêîôûáéíóúàèìòùñçÂÊÎÔÛÁÉÍÓÚÀÈÌÒÙÇ¡¿"
                    pw_charsets[x]='#$%&@^`.,:;{()}'
                    pw_charsets[y]='\/|_<>*+!?='
                fi
                if [[ -n $tmp_charset ]]; then
                    pw_charset="$tmp_charset"
                fi
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

    # look for dictionary file
    check_dict pw_dict || exit 1
}

parse_opts "$@"

pw_command=("${pw_commands[$pw_type]}" "$pw_length" "$pw_sep" "$pw_cap" "$pw_dict"
           "$pw_charset")

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
