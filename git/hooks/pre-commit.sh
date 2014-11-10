#!/bin/ksh
#
# don't allow files with whitespace errors to be committed
#
if git rev-parse --verify HEAD >/dev/null 2>&1
then
    exec git diff-index --check --cached HEAD --
else
    # Initial commit: diff against an empty tree object
    exec git diff-index --check --cached 4b825dc642cb6eb9a060e54bf8d69288fbee4904 --
fi
