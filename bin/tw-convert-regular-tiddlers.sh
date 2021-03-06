#!/bin/bash

source tw-lib.sh

progName="tw-convert-regular-tiddlers.sh"
whitelistSpecialTiddler="$:/CommunitySearchIndexableTiddlers"
whitelistSpecialTiddlerFilename=$(echo "$whitelistSpecialTiddler" | sed 's/^$:\//$__/')
newsSpecialTiddler="$:/CommunityNewsTiddlers"
newsSpecialTiddlerFilename=$(echo "$newsSpecialTiddler" | sed 's/^$:\//$__/')
tagsListFile="/dev/null"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir> <follow wikis file> <visited urls file>"
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
    echo "    field 'url', then the url is printed to <follow wikis file> as"
    echo "    <original wiki name> <url new wiki>"
    echo "  - if the wiki contains a tiddler '$whitelistSpecialTiddler', then"
    echo "    only the tiddlers listed in this tiddler are processed."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -t <tags list file> prints all regular tags found to this file" 
    echo "  -d <checksum filename:list of wikis to apply it to>"
    echo "     for every wiki specified in the second part of the argument,"
    echo "     the tiddlers will be checksumed and the checksum will be"
    echo "     compared with the ones in the ref file (first arg): if this a"
    echo "     match, the tiddler is ignored (duplicate)."
    echo "     if the list of wikis starts with '!', then the process is applied"
    echo "     to all wikis except the ones specified in the list."
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
    local visitedUrlsFile="$5"
    local targetUrlsFile="$6"

    follow=$(extractField "follow" "$tiddlerFile" "$firstBlankLineNo")
    if [ "${follow,,}" == "yes" ]; then
	url=$(extractField "url" "$tiddlerFile" "$firstBlankLineNo" | sed 's/#.*$//' | sed 's:/$::')
	title=$(extractField "title" "$tiddlerFile" "$firstBlankLineNo")
#	echo "DEBUG: title=$title; url=$url" 1>&2
	# conditions: url must not have been already visited and must not be already planned for visit
	if [ ! -z "$url" ] && ! grep "$url" "$visitedUrlsFile" >/dev/null && ! cat "$targetUrlsFile" | cut -d "|" -f 2 | grep "^$url$" >/dev/null; then
	    if [ -f "$outputWikiDir/tiddlers/$title.tid" ]; then
		echo "Warning: there is already a wiki tiddler for '$title' in the target wiki, ignoring (address: '$url')" 1>&2
	    else
#		echo "DEBUG: ADDING" 1>&2
		echo "$sourceWikiName|$url|$title" >>"$targetUrlsFile"
	    fi
	fi
    fi
}


while getopts 'ht:d:' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"t" ) tagsListFile="$OPTARG";;
	"d" ) checksumFile=${OPTARG%:*}
	      wikisToCheckForDuplicate=${OPTARG#*:}
	      duplicateCheckWikisInList=1
	      if [ "${wikisToCheckForDuplicate:0:1}" == "!" ]; then
		  wikisToCheckForDuplicate="${wikisToCheckForDuplicate:1}"
		  duplicateCheckWikisInList=0
	      fi;;
#	      echo "DEBUG: wikisToCheckForDuplicate=$wikisToCheckForDuplicate"
#	      echo "DEBUG: duplicateCheckWikisInList=$duplicateCheckWikisInList" ;;
        "?" )
            echo "Error, unknow option." 1>&2
            usage 1>&2
	    exit 1
    esac
done
shift $(($OPTIND - 1)) # skip options already processed above
if [ $# -ne 4 ]; then
    echo "Error: 4 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
collectedWikisDir="$1"
targetWiki="$2"
followWikisFile="$3"
visitedUrlsFile="$4"

rm -f "$followWikisFile"
touch "$followWikisFile"
regex="^\\\$__"
while read name; do
    checkDup=""
    if [ ! -z "$wikisToCheckForDuplicate" ]; then
#	echo "DEBUG: duplicate detection active"
	inList=0
	for wiki in $wikisToCheckForDuplicate; do
	    if [ "$wiki" == "$name" ]; then
		inList=1
	    fi
	done
	if [ "$duplicateCheckWikisInList" == "$inList" ]; then
	    checkDup=1
	fi
#	echo "DEBUG: wiki $name: inList=$inList; checkDup='$checkDup'"
    fi
    wikiDir="$collectedWikisDir/$name"
    if [ -d "$wikiDir" ]; then
	echo -n "Processing wiki '$name': "
	nbDup=0
	tiddlersList=$(mktemp)
	echo -n "listing; "
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
	echo -n "converting; "
	duplicateTiddlersFile=$(mktemp)
	cat "$tiddlersList" | while read tiddlerFile; do
	    ignoreTiddler=0
	    if [ ! -z "$checkDup" ] && [ -s "$checksumFile" ]; then
		checksum=$(md5sum "$tiddlerFile" | cut -d " " -f 1)
		if grep "$checksum" "$checksumFile" >/dev/null; then
		    ignoreTiddler=1
		    echo "$tiddlerFile" >> "$duplicateTiddlersFile"
		fi
#		echo "DEBUG: dup-ignore-tiddler=$ignoreTiddler; nbDup=$nbDup"
	    fi
	    if [ $ignoreTiddler -ne 1 ]; then
		firstBlankLineNo=$(getFirstBlankLineNo "$tiddlerFile")
		tiddlerType=$(getTiddlerType "$tiddlerFile" "$firstBlankLineNo")
		if [ "$tiddlerType" == "text" ] && ! isSystemTiddlerFile "$tiddlerFile"; then # ignore plugins/themes and system tiddlers
		    cloneAsTWCSTiddler "$tiddlerFile" "$targetWiki/tiddlers" "$firstBlankLineNo" "$name" 1 "" "$tagsListFile" >/dev/null
		    followUrlTiddler "$tiddlerFile" $firstBlankLineNo "$name" "$targetWiki" "$visitedUrlsFile" "$followWikisFile"
		fi
	    fi
	done
	rm -f "$tiddlersList"
	echo "checking for news. "
	nbDup=$(cat "$duplicateTiddlersFile" | wc -l)
	rm -f "$duplicateTiddlersFile"
	if [ $nbDup -gt 0 ]; then
	    echo "INFO: wiki $name: $nbDup duplicate tiddlers removed"
	fi
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
