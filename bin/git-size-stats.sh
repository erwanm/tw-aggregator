#!/bin/bash

file="tw-community-search.html"

git rev-list master | while read rev; do
    date=$(git show -s --format=%ci $rev | cut -d " " -f 1)
    size=$(git ls-tree -r $rev -l "$file" | cut -d " " -f 4 | sed "s/$file//g")
    if [ ! -z "$size" ]; then
	echo -e "$date\t$size"
    fi
done | sort -u +0 -1


