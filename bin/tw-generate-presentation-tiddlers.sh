#!/bin/bash

progName="tw-generate-presentation-tiddlers.sh"
specificTag="community-wiki"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  For every wiki in <collected wikis dir> a 'presentation tiddler'"
    echo "  (named after the wiki id) is generated in <target wiki dir>,"
    echo "  which contains the following fields:"
    echo "    * wiki-address"
    echo "    * wiki-tw-version"
    echo "  and is tagged '$specificTag'"
    echo "Options:"
    echo "  -h this help message"
    echo    
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

for wikiDir in "$collectedWikisDir"/*; do
    if [ -d "$wikiDir" ]; then
	if [ "$(basename "$targetWiki")" != "$(basename "$wikiDir")" ]; then # skip target wiki
	    name=$(basename "$wikiDir")
	    writeTiddlerHeader "title: $name" "tags: $specificTag" "wiki-address: $(cat "$wikiDir.address")" "wiki-tw-version: $(cat "$wikiDir.version")" "type: text/vnd.tiddlywiki" >"$targetWiki/tiddlers/$name.tid"
	    if [ -e "$wikiDir.presentation" ]; then
		firstBlankNo=$(cat "$wikiDir.presentation" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
		tail -n +$firstBlankNo  "$wikiDir.presentation" >> "$targetWiki/tiddlers/$name.tid"
	    fi
	    echo -e "\n\n{{||\$:/CommunityWikiPresentationTemplate}}"  >> "$targetWiki/tiddlers/$name.tid"
	fi
    fi
done
