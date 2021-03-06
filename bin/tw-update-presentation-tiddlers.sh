#!/bin/bash

source tw-lib.sh

progName="tw-update-presentation-tiddler.sh"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  Reads a list of wiki ids on STDIN; for each id, updates its"
    echo "  corresponding presentation tiddler in <target wiki dir> based"
    echo "  on the info in <collected wikis dir>."
    echo
    echo "  The additional info is:"
    echo "    - TW version for this wiki"
    echo "    - the so called 'presentation', which is actually the wiki subtitle."
    echo "    - the date of latest modification"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}


while getopts 'h' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
        "?" )
            echo "Error, unknow option." 1>&2
            usage 1>&2
	    exit 1
    esac
done
shift $(($OPTIND - 1)) # skip options already processed above
if [ $# -ne 2 ]; then
    echo "Error: 2 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
collectedWikisDir="$1"
targetWiki="$2"

while read name; do
    wikiDir="$collectedWikisDir/$name"
    tiddler="$targetWiki/tiddlers/$name.tid"
    if [ ! -e "$tiddler" ]; then # not sure what is the correct version, changed a couple of times so I left both
	name2=$(echo "$name" | tr " " "_")
	tiddler="$targetWiki/tiddlers/$name2.tid"
	if [ ! -e "$tiddler" ]; then
	    echo "Bug: no file '$tiddler' found. Ignoring wiki '$name' in $progName" 1>&2
	    tiddler=""
	fi
    fi
    if [ ! -z "$tiddler" ]; then
	newContent=$(mktemp)
	firstBlankLineNo=$(getFirstBlankLineNo "$tiddler")
	head -n $(( $firstBlankLineNo - 1 )) "$tiddler" > "$newContent"
	if [ -d "$wikiDir" ]; then # wikis not found are not processed.
	    echo -n "wiki-tw-version: " >> "$newContent" 
	    cat "$wikiDir.version" >> "$newContent"
	    latestModif=$(grep "modified: " "$wikiDir"/tiddlers/*tid | cut -f 3 -d ":" | sed 's/^ //g' | grep "^[0-9]*$" | sort | tail -n 1)
	    nbRegularTiddlers=$(ls "$wikiDir"/tiddlers | grep -v "^\$__" | grep "\.tid$" | wc -l)
	    echo "wiki-latest-modification: $latestModif" >> "$newContent"
	    echo "wiki-nb-tiddlers: $nbRegularTiddlers" >> "$newContent"
	    if [ -e "$wikiDir.presentation" ]; then
		firstBlankLineNo2=$(getFirstBlankLineNo "$wikiDir.presentation")
		tail -n +$firstBlankLineNo2  "$wikiDir.presentation" >> "$newContent"
	    fi
	fi
	echo -e "\n\n{{||\$:/CommunityWikiPresentationTemplate}}"  >> "$newContent"
	cat "$newContent" >"$targetWiki/tiddlers/$name.tid"
	rm -f "$newContent"
    fi
done

