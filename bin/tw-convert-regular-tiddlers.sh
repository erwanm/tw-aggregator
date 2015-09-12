#!/bin/bash

source tw-lib.sh

progName="tw-convert-regular-tiddlers.sh"
whitelistSpecialTiddler="$:/CommunitySearchIndexableTiddlers"
whitelistSpecialTiddlerFilename=$(echo "$whitelistSpecialTiddler" | sed 's/^$:\//$__/')
newsSpecialTiddler="$:/CommunityNewsTiddlers"
newsSpecialTiddlerFilename=$(echo "$newsSpecialTiddler" | sed 's/^$:\//$__/')
tagsListFile="/dev/null"

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
    echo "  -t <tags list file> prints all regular tags found to this file" 
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


while getopts 'ht:' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"t" ) tagsListFile="$OPTARG";;
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
	echo -n "Processing wiki '$name': " 1>&2
	tiddlersList=$(mktemp)
	echo -n "listing; " 1>&2
	if [ -f "$wikiDir/tiddlers/$whitelistSpecialTiddlerFilename.tid" ]; then
	    tw-print-from-rendered-tiddler.sh "$wikiDir" "$whitelistSpecialTiddler" | while read title; do
		printTiddlerFileFromTitle "$wikiDir" "$title"
	    done > "$tiddlersList"
	else
	    ls "$wikiDir"/tiddlers/*.tid | while read f; do 
		if [ -f "$f" ]; then # this is to avoid problems later with special characters in filenames; should be made more robust
		    echo "$f"
		else
		    echo "Bug: file '$f' listed by 'ls' but not found in wiki '$name'" 1>&2
		fi
	    done >"$tiddlersList"
	fi
	echo -n "converting; " 1>&2
	cat "$tiddlersList" | while read tiddlerFile; do
	    firstBlankLineNo=$(getFirstBlankLineNo "$tiddlerFile")
	    tiddlerType=$(getTiddlerType "$tiddlerFile" "$firstBlankLineNo")
	    if [ "$tiddlerType" == "text" ] && ! isSystemTiddlerFile "$tiddlerFile"; then # ignore plugins/themes and system tiddlers
		cloneAsTWCSTiddler "$tiddlerFile" "$targetWiki/tiddlers" "$firstBlankLineNo" "$name" 1 "" "$tagsListFile" >/dev/null
		followUrlTiddler "$tiddlerFile" $firstBlankLineNo "$name" "$targetWiki"
	    fi
	done
	rm -f "$tiddlersList"
	echo "checking for news. " 1>&2
	if [ -f "$wikiDir/tiddlers/$newsSpecialTiddlerFilename.tid" ]; then
	    tw-print-from-rendered-tiddler.sh "$wikiDir" "$newsSpecialTiddler" | while read title; do
#		echo "DEBUG: found news tiddler: '$title' " 1>&2
		printTiddlerFileFromTitle "$wikiDir" "$title"
	    done | while read sourceTiddlerFile; do
#		echo "DEBUG reading news tiddler file '$sourceTiddlerFile'" 1>&2
		# TODO: not checking if special tiddler (plugin etc.); such a case would be very strange but still possible.
		firstBlankLineNo=$(getFirstBlankLineNo "$sourceTiddlerFile")
		# overwriting existing system tiddler only to add the CommunityNews tag 
		# (still, better than checking if every tiddler is in the news list)
		cloneAsTWCSTiddler "$sourceTiddlerFile" "$targetWiki/tiddlers" "$firstBlankLineNo" "$name" 1 "" "" "CommunityNews" >/dev/null
	    done
#	else
#	    echo "DEBUG: no news special tiddler '$wikiDir/tiddlers/$newsSpecialTiddlerFilename.tid' found" 1>&2
	fi
    else
	echo "Warning: no directory '$wikiDir', wiki '$name' ignored." 1>&2
    fi
done
