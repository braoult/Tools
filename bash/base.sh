#!/usr/bin/env bash
#
# base.sh - convert decimal numbers from/to base 2, 8, 10 and 16.
#
# (C) Bruno Raoult ("br"), 2024
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
#

CMDNAME=${0##*/}                                  # script name

usage() {
    printf "usage: %s [OPTIONS] [NUMBER]...\n" "$CMDNAME"
    printf  "Use '%s -h' for more help\n" "$CMDNAME"
}

help() {
    cat << _EOF
usage: $CMDNAME [OPTIONS] [NUMBER]...
  -f, --from=BASE      input base, see BASE below. Default is "g"
  -t, --to=BASE        output base, see BASE below. Default is "a"
  -b, -o, -d, -x       equivalent to -t2, -t8, -t10, -t16"
  -g, --group=[SEP]    group output (see OUTPUT below)
  -p, --padding        0-pad output on block boundary (implies -g)
  -n, --noprefix       remove base prefixes in output
  -h, --help           this help

$CMDNAME output the NUMBERS arguments in different bases. If no NUMBER is
given, standard input will be used.

BASE
  2, b, B              binary
  8, o, O, 0           octal
  10, d, D             decimal
  16, h, H, 0x         hexadecimal
  a, g                 all/any: Default, guess format for '-f', output all
                       bases for '-t'

INPUT NUMBER
  If input base is not specified, some prefixes are supported.
  'b' or '2/' for binary, '0', 'o' or '8/' for octal, '0x', 'x' or
  '16/' for hexadecimal, and 'd' or '10/' for decimal.
  If no prefix, decimal is assumed.

OUTPUT
  By default, the input number is shown converted in the 4 supported
  bases (16, 10, 8, 2, in this order), separated by one tab character.
  Without '-n' option, all output numbers but decimal will be prefixed:
  '2#' for binary, '0' for octal, '0x' for hexadecimal, making them
  usable for input in some otilities such as bash(1).]
  With '-g' option, number digits will be grouped by 3 (octal,
  decimal), 4 (hexadecimal), or 8 (binary). If no SEP character is given,
  the separator will be ',' (comma) for decimal, space otherwise.
  This option may be useless for default output, with multiple numbers
  on one line.
  The '-p' option add 0 padding up to the base grouping boundary.

EXAMPLES
  Converting number in hexadecimal, decimal, octal, and binary, with or without
  prefixes. Here, '\t' separator is shown as space:
  $ $CMDNAME 0
  0x0 0 0 2#0

  $ $CMDNAME -n 2/100
  4 4 4 100

  $ $CMDNAME 123456
  0x1e240 123456 0361100 2#11110001001000000

  $ $CMDNAME -n 0x1e240
  1e240	123456	361100	11110001001000000

  Binary output, no prefix, grouped output:
  $ $CMDNAME -bng 0x1e240
  1 11100010 01000000

  Input base indication, left padding binary output, no prefix:
  $ $CMDNAME -nbp -f8 361100
  00000001 11100010 01000000

  Set group separator. Note that the separator *must* immediately follow the '-g'
  option, without spaces:
  $ $CMDNAME -nxg: 123456
  1:e240

  Long options, with separator and padding:
  $ $CMDNAME --to=16 --noprefix --padding --group=: 12345
  0001:e240
_EOF
}

# some default values  (blocks separator padchar)
# Attention: For output base 10, obase is 1
declare -i ibase=0 obase=0 padding=0 prefix=1 ogroup=0

declare -rA _bases=(
    [2]=2 [b]=2 [B]=2
    [8]=8 [o]=8 [O]=8 [0]=8
    [10]=10 [d]=10 [D]=10
    [16]=16 [h]=16 [H]=16 [0x]=16
    [a]=-1 [g]=-1
)
declare -A _pad=(
    [2]=" " [8]=" " [10]="," [16]=" "
)
declare -rA _ogroup=(
    [2]=8 [8]=3 [10]=3 [16]=4
)
declare -rA _oprefix=(
    [2]="2#" [8]="0" [10]="" [16]="0x"
)

zero_pad() {
    local n="$1" str="$2"

    printf "%0.*d%s" $(( n - ${#str} % n))  0 "$str"
}

split() {
    local base="$1" str="$2"
    local res="$str" sep=${_pad[$base]}
    local -i n=${_ogroup[$base]}

    (( padding )) && str=$(zero_pad "${_ogroup[$base]}" "$str")
    if (( ogroup )); then
        res=""
        while (( ${#str} )); do
            if (( ${#str} <= n )); then           # finished
                res="${str}${res:+$sep$res}"
                break
            fi
            res="${str: -n}${res:+$sep$res}"
            str="${str:0:-n}"
        done
    fi
    printf "%s" "$res"
}

bin() {
    local n bits=""
    for (( n = $1 ; n > 0 ; n >>= 1 )); do
        bits=$((n&1))$bits
    done
    printf "%s\n" "${bits:-0}"
}

hex() {
    printf "%lx" "$1"
}

dec() {
    printf "%lu" "$1"
}

oct() {
    printf "%lo" "$1"
}

declare -a args=()

parse_opts() {
    # short and long options
    local sopts="f:t:bodxg::pnh"
    local lopts="from:,to:,group::,padding,noprefix,help"
    # set by options
    local tmp=""

    if ! tmp=$(getopt -o "$sopts" -l "$lopts" -n "$CMDNAME" -- "$@"); then
        usage
        exit 1
    fi
    eval set -- "$tmp"

    while true; do
        case "$1" in
            "-f"|"--from")
                ibase=${_bases[$2]}
                if (( ! ibase )); then
                    usage
                    exit 1
                fi
                shift
                ;;
            "-t"|"--to")
                obase=${_bases[$2]}
                if (( ! obase )); then
                    usage
                    exit 1
                fi
                shift
                ;;
            "-b") obase=2 ;;
            "-o") obase=8 ;;
            "-d") obase=1 ;;
            "-x") obase=16 ;;
            "-g"|"--group")
                ogroup=1
                if [[ -n "$2" ]]; then
                    for i in 2 8 10 16; do _pad["$i"]="$2"; done
                fi
                shift
                ;;
            "-p"|"--padding") ogroup=1; padding=1 ;;
            "-n"|"--noprefix") prefix=0 ;;
            "-h"|"--help") help ; exit 0 ;;
            "--") shift; break ;;
            *) usage; echo "Internal error [$1]!" >&2; exit 1 ;;
        esac
        shift
    done
    # parse remaining arguments
    if (($# > 0)); then                               # type
        args=("$@")
    fi
}

addprefix() {
    local base="$1" number="$2" _prefix=""
    if (( prefix )); then
        if [[ $base != 8 || $number != "0" ]]; then
            _prefix="${_oprefix[$base]}"
        fi
    fi
    printf "%s%s" "$_prefix" "$number"
}

stripprefix() {
    local number="$1"
    number=${number#0x}
    number=${number#[bodx]}
    number=${number#*/}
    printf "%s" "$number"
}

guessbase() {
    local input="$1"
    local -i base=0
    if [[ $input =~ ^b || $input =~ ^2/ ]]; then
        base=2
    elif [[ $input =~ ^0x || $input =~ ^x || $input =~ ^16/ ]]; then
        base=16
    elif [[ $input =~ ^0 || $input =~ ^o || $input =~ ^8/ ]]; then
        base=8
    elif [[ $input =~ ^d || $input =~ ^10/ ]]; then
        base=10
    fi
    return $(( base ? base : 10 ))
}

doit() {
    local number="$2" multi="" val inum
    local -i base=$1 decval _obase=$obase
    if (( base <= 0 )); then
        guessbase "$number"
        base=$?
    fi

    inum=$(stripprefix "$number")
    (( decval = "$base#$inum" ))                  # input value in decimal

    # mask for desired output: 1=decimal, others are same as base
    if (( ! _obase )); then
        (( _obase = 1|2|8|16 ))
        multi=$'\t'
    fi

    if (( _obase & 16 )); then
        val=$(addprefix 16 "$(split 16 "$(hex $decval)")")
        printf "%s%s" "$val" "$multi"
    fi
    if (( _obase & 1 )); then
        val=$(addprefix 10 "$(split 10 "$(dec $decval)")")
        printf "%s%s" "$val" "$multi"
    fi
    if (( _obase & 8 )); then
        val=$(addprefix 8 "$(split 8 "$(oct $decval)")")
        printf "%s%s" "$val" "$multi"
    fi
    if (( _obase & 2 )); then
        val=$(addprefix 2 "$(split 2 "$(bin $decval)")")
        printf "%s%s" "$val" "$multi"
    fi
    printf "\n"
}

parse_opts "$@"

if ! (( ${#args[@]} )); then
    while read -ra line; do
        for input in "${line[@]}"; do
            doit "ibase" "$input"
        done
    done
else
    for input in "${args[@]}"; do
        doit "$ibase" "$input"
    done
fi
exit 0
