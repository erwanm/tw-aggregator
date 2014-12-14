#!/bin/bash

id="tw-aggregator"
paramTiddler="TWAggregatorSources"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <list file>" 1>&2
    echo "  where <list file> is a text with one wiki webpage on each line" 1>&2
    echo "  the empty wiki '$id' must exist in the current directory."
    exit 1
fi
listFile="$1"
pushd $(dirname "$listFile")  >/dev/null # convert to absolute filename
listFile="$(pwd)/$(basename "$listFile")"
popd >/dev/null

function extractIdFromAddress {
    address="$1"
    name=$(echo "$address" | sed 's/\/$//' | sed 's/^http.*:\/\///' | sed 's/.tiddlyspot.com$//') # extract a reasonably short name (without '/')
    echo "${name##*/}"
}

function processTiddler {
    file="$1"
    name="$2"
    address="$3"

    dest=$(mktemp)
    firstBlankNo=$(cat "$file" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    oldTitle=$(head -n $(( $firstBlankNo - 1 )) "$file" | grep "^title:" | sed 's/^title: //g')
    newTitle="\$:/$name/$oldTitle"
    echo "title: $newTitle" >$dest
    head -n $(( $firstBlankNo - 1 )) "$file" | grep -v "^title:" | grep -v "^tags:" >>"$dest"
    oldtags=$(head -n $(( $firstBlankNo - 1 )) "$file" | grep "^tags:" | sed 's/^tags: //g')
    newtags=""
    regex="^\\\$:/"
    for tag in $oldtags; do # very dirty, doesn't deal with [[multi words tags]]
#	echo " '$tag' =~ '$regex' ??" 1>&2
	if [[ ! $tag =~ $regex ]]; then
	    newtags="$newtags $tag"
#	    echo NO-MATCH 1>&2
#	else
#	    echo MATCH 1>&2
	fi
    done
    if [ ! -z "$newtags" ]; then
	echo "tags:$newtags" >>"$dest"
    fi
    tiddler=$(basename "${file%.tid}")
#    tiddler=$(echo "$tiddler" | sed 's/ /%20/g')
    echo "source-wiki-id: $name" >>"$dest"
    echo "source-tiddler-title: $tiddler" >>"$dest"
    tail -n +$firstBlankNo "$file" >>"$dest"
    echo "$dest"
}



nbSites=$(cat "$listFile" | wc -l)
echo "Input list read from file $listFile; $nbSites sites"
# cleaning previous sub-wikis (not done in the loop in case one has been deleted from the list)
for d in "$id"/tiddlers/*; do
    if [ -d "$d" ]; then 
	rm -rf "$d"
    fi
done

theDate=$(date +"%Y%m%d%H%M%S")
echo -e "created: ${theDate}000\ntitle: $paramTiddler" > "$id/tiddlers/$paramTiddler.tid"
cat "$listFile" | while read address; do
    name=$(extractIdFromAddress "$address")
    echo "$name: $address"
done >> "$id/tiddlers/$paramTiddler.tid"
echo >> "$id/tiddlers/$paramTiddler.tid"
cat "$listFile" | while read l; do echo "* $l"; done >> "$id/tiddlers/$paramTiddler.tid"

total=0
for siteNo in $(seq 1 $nbSites); do
    address=$(head -n $siteNo "$listFile" | tail -n 1)
    name=$(extractIdFromAddress "$address")
    echo "processing '$name': fetching '$address'"
    wget "$address" 2>/dev/null # fetch the wiki
    if [ ! -f index.html ]; then
	mv ${address##*/} index.html
    fi
    if [ $? -ne 0 ] || [ ! -f index.html ]; then
	echo "Warning: something wrong when fetching '$address'" 1>&2
    else
	echo "processing '$name': creating wiki"
	tiddlywiki "$name" --init server >/dev/null # create temporary node.js wiki 
	echo "processing '$name': loading tiddlers from standalone html"
	tiddlywiki "$name" --load index.html >/dev/null # convert standalone to tid files
	rm -f index.html "$name"/tiddlers/\$__*.tid # $:/core.tid seems to cause problems when present
	nbThis=$(ls "$name"/tiddlers/*.tid | wc -l)
	total=$(( $total + $nbThis ))
	echo "processing '$name': extracted $nbThis tiddlers"
	echo "processing '$name': removing system tags and adding source field"
	# the lines below also removes any file which isn't *.tid, btw
	mkdir "$name"/tiddlers2
	for f in "$name"/tiddlers/*.tid; do
	    resFile=$(processTiddler "$f" "$name" "$address")
	    basef=$(basename "$f")
	    mv "$resFile" "$name"/tiddlers2/"\$__${name}_$basef"
	done
	rm -rf "$name"/tiddlers/
	mv "$name"/tiddlers2 "$name"/tiddlers
	mv "$name" "$id"/tiddlers
    fi
done
echo "Converting the big fat wiki back to standalone html"
tiddlywiki "$id" --rendertiddler $:/core/save/all "$id".html text/plain
echo "Done. result in $id/output/$id.html ($total tiddlers)"

