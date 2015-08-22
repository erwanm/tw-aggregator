#!/bin/bash

source tw-lib.sh

progName="tw-convert-regular-tiddlers.sh"
whitelistSpecialTiddler="$:/CommunitySearchIndexableTiddlers"
whitelistSpecialTiddlerFilename=$(echo "$whitelistSpecialTiddler" | sed 's/^$:\//$__/')

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  Reads a list of wiki ids from STDIN; each <wiki id> corresponds to"
    echo "  a directory <collected wikis dir>/<wiki id> (previously collected"
    echo "  with tw-harvest.sh), containing the tiddlers."
    echo "  The following steps are applied to every regular tiddler:"
    echo "  * convert to system tiddler"
    echo "  * rename as \$:/<wiki-name>/<title>"
    echo "  * remove any system tag"
    echo "  * add field 'source-wiki-id' with value <wiki-name>"
    echo "  * add field 'source-wiki-title' with value <title>"
    echo "  Plugin/theme tiddlers are ignored, as well as tiddler with type"
    echo "  application/javascript."
    echo
    echo "  - if a tiddler contains a field 'follow' with value 'YES' and a"
    echo "    field 'url', then the url is printed to STDOUT as:"
    echo "    <original wiki name> <url new wiki>"
    echo "  - if the wiki contains a tiddler '$whitelistSpecialTiddler', then"
    echo "    only the tiddlers listed in this tiddler are processed."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}

#
#
#
function followUrlTiddler  {
    local tiddlerFile="$1"
    local firstBlankLineNo="$2"
    local sourceWikiName="$3"
    local outputWikiDir="$4"

    follow=$(extractField "follow" "$tiddlerFile" "$firstBlankLineNo")
    if [ "${follow,,}" == "yes" ]; then
	url=$(extractField "url" "$tiddlerFile" "$firstBlankLineNo")
	title=$(extractField "title" "$tiddlerFile" "$firstBlankLineNo")
	if [ ! -z "$url" ] && [ ! -f "$outputWikiDir/tiddlers/$title.tid" ] ; then # second condition to ensure the wiki hasn't been already extracted
	    echo "$sourceWikiName|$url|$title"
	fi
    fi
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

regex="^\\\$__"
while read name; do
    wikiDir="$collectedWikisDir/$name"
    if [ -d "$wikiDir" ]; then
	echo "Processing wiki '$name'" 1>&2
	tiddlersList=$(mktemp)
	if [ -f "$wikiDir/tiddlers/$whitelistSpecialTiddlerFilename.tid" ]; then
	    tw-print-from-rendered-tiddler.sh "$wikiDir" "$whitelistSpecialTiddler" | while read title; do
		if [ -f "$wikiDir/tiddlers/$title.tid" ]; then
		    echo "$wikiDir/tiddlers/$title.tid"
		else 
		    f=$(grep "^title: $title$" "$wikiDir"/tiddlers/*.tid | cut -d ":" -f 1) # assuming only one possibility!
		    if [ -z "$f" ]; then
			echo "Warning: whitelist: no tiddler titled '$title' found in wiki '$name'" 1>&2
		    else
			echo "$f"
		    fi
		fi
	    done > "$tiddlersList"
	else
	    ls "$wikiDir"/tiddlers/*.tid | while read f; do 
		if [ -f "$f" ]; then # this is to avoid problems later with special characters in filenames; should be made more robust
		    echo "$f"
		else
		    echo "Warning: no file '$f' found in wiki '$name'" 1>&2
		fi
	    done >"$tiddlersList"
	fi
	cat "$tiddlersList" | while read tiddlerFile; do
	    firstBlankLineNo=$(getFirstBlankLineNo "$tiddlerFile")
	    tiddlerType=$(getTiddlerType "$tiddlerFile" "$firstBlankLineNo")
	    if [ "$tiddlerType" == "text" ] && ! isSystemTiddlerFile "$tiddlerFile"; then # ignore plugins/themes and system tiddlers
		cloneAsTWCSTiddler "$tiddlerFile" "$targetWiki/tiddlers" "$firstBlankLineNo" "$name" 1 >/dev/null
		followUrlTiddler "$tiddlerFile" $firstBlankLineNo "$name" "$targetWiki"
	    fi
	done
	rm -f "$tiddlersList"
    else
	echo "Warning: no directory '$wikiDir', wiki '$name' ignored." 1>&2
    fi
done
