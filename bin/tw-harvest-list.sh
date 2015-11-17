#!/bin/bash

progName="tw-harvest.sh"

source tw-lib.sh

function usage {
    echo "Usage: $progName [options] <list file> <dest dir> <visited urls file>"
    echo
    echo "  Downloads the collection of wikis provided in <list file>, which"
    echo "  contains lines of the form:"
    echo "  <wiki address>[|<wiki short name>[|<presentation tiddler title>]]"
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
if [ $# -ne 3 ]; then
    echo "Error: 2 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
wikiListFile="$1"
destDir="$2"
visitedUrlsFile="$3"

if [ ! -d "$destDir" ]; then
    echo "Error: directory $destDir does not exist." 1>&2
    exit 1
fi
if [ ! -e "$wikiListFile" ]; then
    echo "Error: file $wikiListFile does not exist." 1>&2
    exit 1
fi

nbLines=$(cat "$wikiListFile" | wc -l)
nbSites=$(cat "$wikiListFile" | grep -v "^#" | wc -l)
echo "Reading $nbSites wikis..."
wikiNo=1
for lineNo in $(seq 1 $nbLines); do
    row=$(head -n $lineNo "$wikiListFile" | tail -n 1)
    address=$(echo "$row" | cut -f 1 -d "|" | sed 's:/$::')
    name=$(echo "$row" | cut -f 2 -d "|")
    presentationTiddler=$(echo "$row" | cut -f 3 -d "|")
#    echo "DEBUG: $address" 1>&2
    echo "wiki $wikiNo/$nbSites: '$name'; fetching '$address'"
    echo "$address" >>"$visitedUrlsFile"
    if [ -z "$name" ]; then
	tw-harvest-wiki.sh "$destDir" "$address"
	exitCode=$?
    else
	tw-harvest-wiki.sh "$destDir" "$address" "$name"
	exitCode=$?
    fi
    if [ $exitCode -eq 0 ]; then
	if [ -z "$presentationTiddler" ]; then
	    targetTiddler="$destDir/$name/tiddlers/\$__CommunitySearchWikiPresentation.tid"
	    if [ ! -e "$targetTiddler" ]; then
		targetTiddler="$destDir/$name/tiddlers/\$__SiteSubtitle.tid"
	    fi
	else # should never be used now, as far as I remember
	    if [ -e "$destDir/$name/tiddlers/$presentationTiddler.tid" ]; then
		targetTiddler="$destDir/$name/tiddlers/$presentationTiddler.tid"
	    else
		echo "Warning: presentation tiddler '$presentationTiddler' does not exist in '$name'" 1>&2
		targetTiddler="$destDir/$name/tiddlers/\$__SiteSubtitle.tid"
	    fi
	fi
	if [ -e "$targetTiddler" ]; then
	    cp "$targetTiddler" "$destDir/$name.presentation"
	else
	    echo "Warning: no presentation tiddler in '$name'" 1>&2
	fi
    else
	echo "Warning: something went wrong: 'tw-harvest-wiki.sh \"$destDir\" \"$address\"' returned exit code $exitCode" 1>&2
    fi
    wikiNo=$(( $wikiNo + 1 ))
done
