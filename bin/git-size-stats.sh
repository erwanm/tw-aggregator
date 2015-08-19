#!/bin/bash

file="tw-community-search.html"

git rev-list master | while read rev; do
    date=$(git show -s --format=%ci $rev | cut -d " " -f 1)
    size=$(git ls-tree -r $rev -l "$file" | cut -d " " -f 4 | sed "s/$file//g")
    if [ ! -z "$size" ]; then
	echo -e "$rev\t$date\t$size"
    fi
done
echo "info: pipe the output with sort -u +1 -2 for daily size." 1>&2

