#!/bin/bash

id="tw-community-search"
wikiBasis="tw-aggregator-basis"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <indexed wikis file>" 1>&2
    echo "  where <indexed wikis file> is a text file describing one wiki by line:" 1>&2
    echo " <wiki address> [ <wiki short name> [<presentation tiddler title>] ]" 1>&2
    echo 1>&2
    echo "  the skeleton wiki '$wikiBasis' must already exist." 1>&2
    exit 1
fi
listFile="$1"
pushd $(dirname "$listFile")  >/dev/null # convert to absolute filename
listFile="$(pwd)/$(basename "$listFile")"
popd >/dev/null


#
# returns a (quite) user-friendly name without '/' characters from a wiki address.
# typically returns 'mywiki' works for 'http://mywiki.tiddlyspot.com'; otherwise the part after the last '/'
#
function extractIdFromAddress {
    address="$1"
    name=$(echo "$address" | sed 's/\/$//' | sed 's/^http.*:\/\///' | sed 's/.tiddlyspot.com$//') # extract a reasonably short name (without '/')
    echo "${name##*/}"
}


#
# arguments of the form "field: value"
#
function writeTiddlerHeader {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
    while [ $# -gt 0 ]; do
	echo "$1"
	shift
    done
    echo
}




# echoes the name of the temp tiddler after being cleaned up/converted if "normal tiddler",
# empty string if the tiddler is discarded (plugin/theme tiddler)
#
function processTiddler {
    file="$1"
    name="$2"
    address="$3"

    dest=$(mktemp)
    # find the position of the end of fields declarations / beginning of text
    firstBlankNo=$(cat "$file" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    pluginField=$(head -n $(( $firstBlankNo - 1 )) "$file" | grep "^plugin-type:" | wc -l)
    if [ $pluginField -gt 0 ]; then # discard plugins/themes
	rm -f "$dest"
	echo ""
    else
	oldTitle=$(head -n $(( $firstBlankNo - 1 )) "$file" | grep "^title:" | sed 's/^title: //g')
	newTitle="\$:/$name/$oldTitle" # convert title to system tiddler with wiki id prefix
	echo "title: $newTitle" >$dest
	head -n $(( $firstBlankNo - 1 )) "$file" | grep -v "^title:" | grep -v "^tags:" >>"$dest" # copy fields except title and tags
	oldtags=$(head -n $(( $firstBlankNo - 1 )) "$file" | grep "^tags:" | sed 's/^tags: //g')
	newtags=""
	regex="^\\\$:/"
	for tag in $oldtags; do # very dirty, doesn't deal with [[multi words tags]], should be unlikely in system tags 
	    #	echo " '$tag' =~ '$regex' ??" 1>&2
	    if [[ ! $tag =~ $regex ]]; then # keep it if not a system tag, otherwise ignore it
		newtags="$newtags $tag"
	    fi
	done
	if [ ! -z "$newtags" ]; then
	    echo "tags:$newtags $name" >>"$dest"
	fi
	tiddler=$(basename "${file%.tid}")
	echo "source-wiki-id: $name" >>"$dest" # store custom fields in order to recompute the original address
	echo "source-tiddler-title: $tiddler" >>"$dest" 
	tail -n +$firstBlankNo "$file" >>"$dest"
	echo "$dest"
    fi
}



nbSites=$(cat "$listFile" | wc -l)
echo "Input list read from file $listFile; $nbSites sites"

workDir=$(mktemp -d)
echo "creating target wiki"
tiddlywiki "$workDir/$id" --init server >/dev/null
mkdir "$workDir/$id"/tiddlers
cp "$wikiBasis"/tiddlers/* "$workDir/$id"/tiddlers
pushd "$workDir" >/dev/null


total=0
## iterate the referenced wikis to add their content to the target wiki
##
for siteNo in $(seq 1 $nbSites); do
    set -- $(head -n $siteNo "$listFile" | tail -n 1)
    address="$1"
    shift
    name="$1"
    shift
    presentationTiddler="$@"
    if [ -z "$name" ]; then
	name=$(extractIdFromAddress "$address")
    fi
    echo "processing '$name': fetching '$address'"
    wget "$address" 2>/dev/null # download the wiki
    if [ ! -f index.html ]; then # if file not named index.html, rename it
	mv ${address##*/} index.html
    fi
    if [ $? -ne 0 ] || [ ! -f index.html ]; then # if error, ignore this wiki
	echo "Warning: something wrong when fetching '$address'" 1>&2
    else
	echo "processing '$name': creating wiki"
	tiddlywiki "$name" --init server >/dev/null # create temporary node.js wiki 
	echo "processing '$name': loading tiddlers from standalone html"
	tiddlywiki "$name" --load index.html >/dev/null # convert standalone to tid files
	rm -f index.html "$name"/tiddlers/\$__*.tid # remove all system tiddlers (they could introduce incompatibilities)
	nbThis=$(ls "$name"/tiddlers/*.tid | wc -l)
	total=$(( $total + $nbThis ))
	echo "processing '$name': extracted $nbThis tiddlers"
	echo "processing '$name': removing system tags and adding source field" # system tags can cause incompatibilities as well
	# the lines below also discard any file which isn't *.tid, btw
	for f in "$name"/tiddlers/*.tid; do
	    resFile=$(processTiddler "$f" "$name" "$address")
	    if [ ! -z "$resFile" ]; then # no output means that the file should be ignored (special tiddlers, e.g. plugin)
		basef=$(basename "$f")
		# rename as system tag and prefixed with the wiki id (so that tiddlers from different wikis with the same title don't cause overwritting, for instance GettingStarted)
		mv "$resFile" "$id"/tiddlers/"\$__${name}_$basef"
	    fi
	done

	echo "processing '$name': creating presentation tiddler"
	writeTiddlerHeader "title: $name" "tags: community-wiki" "wiki-address: $address" "type: text/vnd.tiddlywiki" >"$id/tiddlers/$name.tid"
	if [ ! -z "$presentationTiddler" ]; then
	    file="$name/tiddlers/$presentationTiddler.tid"
	    if [ -f "$file" ]; then
		firstBlankNo=$(cat "$file" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
		tail -n +$firstBlankNo "$file" >> "$id/tiddlers/$name.tid"
	    else
		echo "Warning: presentation tiddler '$file' (title '$presentationTiddler') does not exist" 1>&2
	    fi
	    
	fi
	echo -e "\n\n{{||\$:/CommunityWikiPresentationTemplate}}"  >> "$id/tiddlers/$name.tid"

	rm -rf "$name"
    fi
done
echo "Converting the big fat wiki back to standalone html"
tiddlywiki "$id" --rendertiddler $:/plugins/tiddlywiki/tiddlyweb/save/offline "$id".html text/plain
popd >/dev/null
mv "$workDir/$id/output/$id.html" .
rm -rf "$workDir"
echo "Done. result in $id.html ($total tiddlers)"

