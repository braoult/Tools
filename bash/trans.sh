#!/bin/bash
#
# trans.sh - Translate words using linguee.com.
#
# (C) Bruno Raoult ("br"), 2021
# Licensed under the Mozilla Public License (MPL) version 2.0.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the Mozilla Public License along with this
# program.  If not, see <https://www.mozilla.org/en-US/MPL>
#
# SPDX-License-Identifier: MPL-2.0 <https://spdx.org/licenses/MPL-2.0.html>
#
# Options: See usage function in code below.

CMD=${0##*/}
SRC=""
DST=""
KEEPTMP=false
FILTER="cat"

# languages names.
declare -A lang=(
    [bg]="bulgarian"  [cs]="czech"      [da]="danish"
    [de]="german"     [el]="greek"      [en]="english"
    [es]="spanish"    [et]="estonian"   [fi]="finnish"
    [fr]="french"     [hu]="hungarian"  [it]="italian"
    [ja]="japanese"   [lt]="lithuanian" [lv]="latvian"
    [mt]="maltese"    [nl]="dutch"      [pl]="polish"
    [pt]="portuguese" [ro]="romanian"   [ru]="russian"
    [sk]="slovak"     [sl]="slovene"    [sv]="swedish"
    [zh]="chinese"
)

# languages which can only translate to/from english
declare -A englishonly=(
    [ja]="japanese"   [ru]="russian"    [zh]="chinese"
)

usage () {
    printf "Usage: %s [OPT] word\n" "$CMD"
    printf "Translate a word between languages.\n\n"
    printf "Options:\n"
    printf "  -1       Display only first line.\n"
    printf "  -f LANG  Translate from language LANG (default: fr).\n"
    printf "  -k       Keep temporary file (and displays its name).\n"
    printf "  -l       List accepted languages.\n"
    printf "  -t LANG  Translate to language LANG (default: en).\n"
    printf "  -h,-?    This help.\n"
    printf "\n"
    printf "If only one of -f or -t options is used, the other language will default to 'en'.\n"
    printf "If none is specified, default will be '-f fr -t en'.\n"

    exit 1
}
list_languages() {
    local k e
    for k in "${!lang[@]}"; do
        e=""
        [[ -v englishonly[$k] ]] && e=" (English only)"
        printf "%s: %s %s\n" "$k" "${lang[$k]}" "$e"
    done
}
while getopts "1f:t:klh?" opt; do
    case "$opt" in
        1) FILTER="head -1"
           ;;
        f) SRC="$OPTARG"
           if [[ ! -v lang[$SRC] ]]; then
               printf "%s: unknown source language.\n" "$SRC"
               exit 1
           fi
           ;;
        k) KEEPTMP=true
           ;;
        l) list_languages
           exit 0
           ;;
        t) DST="$OPTARG"
           if [[ ! -v lang[$DST] ]]; then
               printf "%s: unknown target language.\n" "$SRC"
               exit 1
           fi
           ;;
        *) usage
           ;;
    esac
done
if [[ -z "$SRC" && -z "$DST" ]]; then
    SRC=fr
    DST=en
elif [[ -z "$SRC" ]]; then
    SRC="en"
elif [[ -z "$DST" ]]; then
    DST="en"
fi
if [[ "$SRC" = "$DST" ]]; then
    printf "%s: cannot translate to itself.\n" "$SRC"
    exit 1
fi

if [[ -v englishonly[$SRC] && $DST != en ]]; then
    printf "%s: setting target language to english.\n" "$SRC"
    DST=en
fi
if [[ -v englishonly[$DST] && $SRC != en ]]; then
    printf "%s: can only translate from english.\n" "$DST"
    exit 1
fi

shift $((OPTIND - 1))
(( $# != 1 )) && usage

word=$1

tmpfile=$(mktemp --tmpdir= trans-XXXXX)

curl -Gis "https://www.linguee.com/${lang[$SRC]}-${lang[$DST]}/search" \
     --data-urlencode "qe=${word}" \
     --data-urlencode "source=${lang[$SRC]}" |
    dos2unix > "$tmpfile"

# not sure what these options are for
#--data-urlencode "cw=788" \
#--data-urlencode "ch=1055" \
# --data-urlencode "as=shownOnStart" \
# -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:82.0) Gecko/20100101 Firefox/82.0' \
# -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
# -H 'Accept: */*' | \

encoding=$(sed -n '/charset=/{s/^.*charset="\(.*\)".*$/\1/p; q}' "$tmpfile")

sed '1,/^$/d' "$tmpfile" |
    iconv -f "$encoding" -t "utf-8" |
    hxunent |
    hxprune -c wordtype |
    hxprune -c main_wordtype |
    hxprune -c suggest_row |
    hxprune -c sep |
    hxprune -c placeholder |
    # select text
    hxselect -s "\n" -l en -i -c div.main_item, div.translation_item |
    # left trim blanks
    sed -e 's/^ *//' |
    # remove double blank lines only
    sed -e 'N;/^\n$/d;P;D' |
    # merge consecutive non blank lines
    sed -e '/./{:a;N;s-\n\(.\)-, \1-;ta}' |
    # merge lines separated by a blank line, \t as separator
    sed -e 'N;N;s/\n\n/\t/;P;D' |
    ${FILTER} |
    # column display
    column -t -s$'\t'

#printf "%s\n%s\n" "$tmpfile" "$encoding"
if [[ $KEEPTMP = true ]]; then
    printf "\nWarning: Retained temp file: %s\n" "$tmpfile"
else
    rm "$tmpfile"
fi

exit 0
