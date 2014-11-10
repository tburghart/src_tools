#!/bin/ksh
#
#   Copyright (c) 2014 T. R. Burghart
#
#   Permission to use, copy, modify, and/or distribute this software for any
#   purpose with or without fee is hereby granted, provided that the above
#   copyright notice and this permission notice appear in all copies.
#
#   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# Install as a git 'clean' filter
#
# Because this file uses regex to process the Revision line, it can
# safely be processed by itself.
#
# Author:     Ted Burghart
# Version:    0.0.2
# Revision:   2   2014-11-10T17:24:15Z
#

#
# WTF is running this thing?
#
if  true
then
    typeset  -r TraceFile="/tmp/update-rev.$(date -u '+%s').$$"
    printf 'Pid: %u = ' $$ >> "$TraceFile"
    echo "$0" "$@" >> "$TraceFile"
    echo . >> "$TraceFile"
    ps -ef >> "$TraceFile"
    echo . >> "$TraceFile"
fi

[[ $# -gt 0 ]] || exit 0

#typeset  -r TraceOpt='set +x'
unset TraceOpt
$TraceOpt

#
# temporary shorthand for building filters
#
S='[[:space:]]'
N='[^[:space:]]'
D='[[:digit:]]'
Y="$D{4}"
R="$D+"
T="$Y-$D{2}-$D{2}T$D{2}:$D{2}:$D{2}Z"

#
# head -10 <filename> | sed -En "$DelimFilt" ==> <comment-delimiter>
#
typeset  -r DelimFilt="s/^$S*($N+)$S+[Cc]opyright($S+|$S.*$S)$Y[[:space:],-].*\$/\\1/p"

#
# Each locates 5 fields:
#   \1  line before <revision-number>
#   \2  <revision-number>
#   \3  characters between <revision-number> and <revision-time>
#   \4  <revision-time>
#   \5  line following <revision-time>
#
# "$ErlRevFilt" consumes the entire line
# "$TxtRevFilt" consumes the line following the <comment-delimiter>
#
typeset  -r TxtRevFilt="($S+Revision:$S+)($R)($S+)($T)($S.*)?\$"
typeset  -r ErlRevFilt="^($S*-revision\\($S*\\[$S*\")($R)(\",$S*\")($T)(\"$S*\\]$S*\\)$S*\\.$S*)\$"

#
# clear the shorthand variables
#
unset S N D Y R T

typeset  -r LockFile="/tmp/${0##*/}.lock"
typeset  -r TempFile="$(mktemp -t gitpc)"
trap "rm -f $LockFile $TempFile" EXIT

#
# make sure we're not executing in parallel - running against the same
# file in more than one instance would be a Bad Thing!
#
lockfile "$LockFile"

typeset  -r DateTime="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

#
# handle_comment <comment-delimiter> <file-path>
#
#   <comment-delimiter> is a fragment inserted directly into an extended regex
#
handle_comment()
{
    $TraceOpt
    typeset delim fpath filt rev revdt
    delim="$1"
    fpath="$2"
    filt="^([[:space:]]*$delim)$TxtRevFilt"
    rev="$(sed -En "s/$filt/\\3/p" "$fpath")"
    if [[ -n "$rev" ]]
    then
        typeset  -i rev
        let 'rev += 1'
        revdt="$(printf '%-3u %s' "$rev" "$DateTime")"
        cp "$fpath" "$TempFile"
        sed -E "s/$filt/\\1\\2$revdt\\6/" "$TempFile" > "$fpath"
        return $?
    fi
    return 0
}

handle_hash_comment()
{
    $TraceOpt
    typeset delim fpath
    fpath="$1"
    #
    # get the comment delimiter pattern from the Revision line
    #
    delim="$(sed -En "s/^[[:space:]]*(#+)$TxtRevFilt/\1/p" "$fpath")"
    if [[ -n "$delim" ]]
    then
        handle_comment "$delim" "$fpath"
        return $?
    fi
    return 0
}

handle_erl_comment()
{
    $TraceOpt
    typeset delim fpath
    fpath="$1"
    #
    # get the comment delimiter pattern from the Revision line
    #
    delim="$(sed -En "s/^[[:space:]]*(%+)$TxtRevFilt/\1/p" "$fpath")"
    if [[ -n "$delim" ]]
    then
        handle_comment "$delim" "$fpath"
        return $?
    fi
    return 0
}

handle_erl_module()
{
    $TraceOpt
    typeset fpath rev
    fpath="$1"
    rev="$(sed -En "s/$ErlRevFilt/\\2/p" "$fpath")"
    if [[ -n "$rev" ]]
    then
        typeset  -i rev
        let 'rev += 1'
        cp "$fpath" "$TempFile"
        sed -E "s/$ErlRevFilt/\\1$rev\\3$DateTime\\5/" "$TempFile" > "$fpath"
        return $?
    fi
}

handle_c_comment()
{
    $TraceOpt
    typeset delim fpath
    fpath="$1"
}

handle_cpp_comment()
{
    $TraceOpt
    typeset delim fpath
    fpath="$1"
}

handle_text_file()
{
    $TraceOpt
    typeset delim fpath
    fpath="$1"
    #
    # figure out the comment delimiter from the header copyright line
    #
    delim="$(head -10 "$fpath" | sed -En "$DelimFilt")"
    if [[ -n "$delim" ]]
    then
        handle_comment "$delim" "$fpath"
        return $?
    fi
    return 0
}

handle_file_type()
{
    $TraceOpt
    typeset fpath ftype fext
    fpath="$1"
    ftype="$2"

    case "$ftype" in
        *\ shell\ script\ text\ executable | \
        *\ sh\ script\ text\ executable | \
        *\ [a-z]sh\ script\ text\ executable | \
        *\ [a-z][a-z]sh\ script\ text\ executable | \
        *\ /bin/sh\ script\ text\ executable | \
        *\ /bin/[a-z]sh\ script\ text\ executable | \
        *\ /bin/[a-z][a-z]sh\ script\ text\ executable )
            handle_hash_comment "$fpath"
            return $?
            ;;
    esac

    typeset -l  fname="${fpath##*/}"

    case "$fname" in
        *.sh | .git* | makefile )
            handle_hash_comment "$fpath"
            return $?
            ;;
        *.erl )
            handle_erl_module "$fpath"
            return $?
            ;;
        *.hrl | *.app.scr | rebar.config )
            handle_erl_comment "$fpath"
            return $?
            ;;
    esac

    case "$ftype" in
        ascii\ text | ascii\ *\ text )
            handle_text_file "$fpath"
            return $?
            ;;
    esac

    return 0
}

for fp in "$@"
do
    typeset -l  ftype="$(file -b "$fp")"
    handle_file_type "$fp" "$ftype"
done
