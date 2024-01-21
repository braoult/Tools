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
  -f, --from=BASE      input base. Default is "g"
  -t, --to=BASE        output base. Default is "a"
  -2, -8, -d, -x       equivalent to -t2, -t8, -t10, -t16"
  -g, --group=[SEP]    group output (see OUTPUT below)
  -0, --padding        Not implemented. 0-pad output on block boundary (implies -g)
  -n, --noprefix       Remove base prefixes in output
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
  By default, output is the input number converted in the 4 supported
  bases (16, 10, 8, 2, in this order, separated by one tab character.
  Without '-n' option, all output numbers but decimal will be prefixed:
  '2#' for binary, '0' for octal, '0x' for hexadecimal, making them
  usable for input in some otilities such as bash(1).]
  With '-g' option, number digits will be grouped by 3 (octal,
  decimal), or 4 (binary, hexadecimal)\n. If no SEP character is given,
  the separator will be ',' (comma) for decimal, space otherwise.
  This option may be useless if default output, with multiple numbers
  on one line.
  The '-0' option will left pad with '0' (zeros) to a group boundary.

EXAMPLES
  $ $CMDNAME 123456
  2#11110001001000000 0361100 123456 0x1e240
  $ $CMDNAME -n 123456
  11110001001000000 361100 123456 1e240
  $ $CMDNAME -ng2 012345
  1 0100 1110 0101
  $ $CMDNAME -n2 012345
  1 0100 1110 0101
_EOF
}

# some default values  (blocks separator padchar)
declare -i ibase=0 obase=0 padding=0 noprefix=0 ogroup=0

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
    [2]=4 [8]=3 [10]=3 [16]=4
)
declare -rA _oprefix=(
    [2]="2#" [8]="0" [10]="" [16]="0x"
)

zero_pad() {
    local base="$1" str="$2"
    local str="$1"
    local -i n=${_ogroup[$base]}

    #printf "str=$str #=${#str}" >&2
    while (( ${#str} < $2 )); do
        str="0$str"
    done
    printf "%s" "$str"
}

split() {
    local base="$1" str="$2"
    local res="$str" sep=${_pad[$base]}
    local -i n=${_ogroup[$base]}

    if (( ogroup )); then
        res=""
        while (( ${#str} )); do
            if (( ${#str} < n )); then
                str=$(zero_pad "$str" $n)
            fi
            res="${str: -$n}${res:+$sep$res}"
            str="${str:0:-$n}"
        done
    fi
    printf "%s" "$res"
}

bin() {
    local n bits=""
    for (( n = $1 ; n > 0 ; n >>= 1 )); do
        bits=$((n&1))$bits
    done
    printf "%s\n" "${bits-0}"
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
    local sopts="f:t:28dxg::pnh"
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
            "-2") obase=2 ;;
            "-8") obase=8 ;;
            "-d") obase=10 ;;
            "-x") obase=16 ;;
            "-g"|"--group")
                ogroup=1
                if [[ -n "$2" ]]; then
                    for i in 2 8 10 16; do _pad["$i"]="$2"; done
                fi
                shift
                ;;
            "-p"|"--padding") padding=1 ;;
            "-n"|"--noprefix") noprefix=1 ;;
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

# shellcheck disable=SC2317
addprefix() {
    local base="$1" number="$2"
    local prefix=""
    (( noprefix )) || prefix="${_oprefix[$base]}"
    printf "%s%s" "$prefix" "$number"
}

stripprefix() {
    local number="$1"
    number=${number#0x}
    number=${number#[bodx0]}
    number=${number#0}
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
