#!/bin/bash

progName="tw-update-presentation-tiddler.sh"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  Reads a list of wiki ids on STDIN; for each id, updates its"
    echo "  corresponding presentation tiddler in <target wiki dir> based"
    echo "  on the info in <collected wikis dir>."
    echo
    echo "  The additional info is TW version and the so-called "
    echo "  'presentation', which is actually the wiki subtitle."
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
    if [ ! -d "$wikiDir" ] || [ ! -e "$tiddler" ]; then
	echo "Warning: no dir '$wikiDir' found or no file '$tiddler' found, the two must exist. Ignoring wiki '$name' in $progName" 1>&2
    else
	newContent=$(mktemp)
	firstBlankNo=$(cat "$tiddler" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
	head -n $(( $firstBlankLineNo - 2 )) "$tiddler" > "$newContent"
	echo -n "wiki-tw-version: " >> "$newContent"
	cat "$wikiDir.version" >> "$newContent"
	if [ -e "$wikiDir.presentation" ]; then
	    tail -n +$firstBlankNo  "$wikiDir.presentation" >> "$newContent"
	fi
	echo -e "\n\n{{||\$:/CommunityWikiPresentationTemplate}}"  >> "$newContent"
	cat "$newContent" >"$targetWiki/tiddlers/$name.tid"
	rm -f "$newContent"
    fi
done

