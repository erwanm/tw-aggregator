#!/bin/bash

source tw-lib.sh

progName="tw-list-plugins-tiddlers.sh"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  Reads a list of lines <wiki address>|<wiki id> from STDIN; each"
    echo "  <wiki id> corresponds to a directory "
    echo "  <collected wikis dir>/<wiki id> (previously collected with"
    echo "  tw-harvest.sh), containing the tiddlers."
    echo 
    echo "  Every plugin tiddler found is printed to STDOUT with:"
    echo "  <wiki address> <plugin title> <wiki id> <original tiddler file> <target tiddler file> <end header col no>"
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
    echo "Error: 1 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
collectedWikisDir="$1"
targetWiki="$2"

while read line; do
    address=$(echo "$line" | cut -d "|" -f 1 | removeTrailingSlash)
    name=$(echo "$line" | cut -d "|" -f 2)
    wikiDir="$collectedWikisDir/$name"
    if [ -d "$wikiDir" ]; then
	echo "Processing wiki '$name'" 1>&2
	tiddlersList=$(mktemp)
	ls "$wikiDir"/tiddlers/*.tid | while read f; do
	    if [ -f "$f" ]; then
		echo "$f"
	    else
		echo "Warning: cannot open file '$f' in wiki '$name'" 1>&2
	    fi
	done >"$tiddlersList"
	cat "$tiddlersList" | while read tiddlerFile; do
	    firstBlankLineNo=$(getFirstBlankLineNo "$tiddlerFile")
	    basef=$(basename "$tiddlerFile")
	    tiddlerType=$(getTiddlerType "$tiddlerFile"  "$firstBlankLineNo")
	    if [ "$tiddlerType" == "plugin" ]; then
		# 1. create tiddler in the same way as regular tiddlers
		targetTiddler=$(cloneAsTWCSTiddler "$tiddlerFile" "$targetWiki/tiddlers" "$firstBlankLineNo" "$name" 0 "plugin-type type")
		echo "extracted-plugin: true" >>"$targetTiddler"
		echo >>"$targetTiddler"
		echo "{{||CommunityExtractedPlugin}}" >>"$targetTiddler"
		# 2. add to list
		pluginTitle=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^title: " | sed 's/^title: //')
		targetFirstBlankLineNo=$(getFirstBlankLineNo "$targetTiddler")
		echo -e "$address\t$pluginTitle\t$name\t$tiddlerFile\t$targetTiddler\t$targetFirstBlankLineNo"
	    fi
	done
	rm -f "$tiddlersList"
    else
	echo "Warning: no directory '$wikiDir', wiki '$name' ignored." 1>&2
    fi
done
