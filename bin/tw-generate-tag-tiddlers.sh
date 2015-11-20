#!/bin/bash

source tw-lib.sh

progName="tw-generate-tag-tiddlers.sh"

# wikis whose tiddlers might be found as duplicates elsewhere
potentialDuplicateSourceWikis="tiddlywiki.com"
# list of target wikis to check for duplicates
# either one of the two versions below can be used, but not at the same time
#checkForDuplicatesWikis="cpashow" # wikis to check
checkForDuplicatesWikis="!$potentialDuplicateSourceWikis" # wikis NOT to check
duplicateChecksumFile="source-tiddlers.md5"

function usage {
    echo "Usage: $progName [options] <tags list file> <work dir> <output wiki dir>"
    echo
    echo "  Generates a CommunityTag tiddler for every tag in <tags list file>," 
    echo "  except if a tiddler with that name already exists."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}


#reads STDIN and prints to STDOUT 
# STDIN must have been sorted first.
#
#
function countIdentical {
    local prev=""
    while read l; do
#	echo "DEBUG: read '$l'; prev='$prev'" 1>&2
	if [ "$l" == "$prev" ]; then
	    nb=$(( $nb + 1 ))
	else
	    if [ ! -z "$prev" ]; then
		echo -e "$prev\t$nb"
	    fi
	    prev="$l"
	    nb=1
	fi
    done
    echo -e "$prev\t$nb"
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
    echo "Error: 3 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
tagsListFile="$1"
workDir="$2"
outputWiki="$3"


countFile="$workDir/community-tags-counts.list"
cat "$tagsListFile" | sort | countIdentical >"$countFile"
cat "$countFile" | while read l; do
    tag=$(echo "$l" | cut -f 1)
    nb=$(echo "$l" | cut -f 2)
    f=$(echo "CommunityTag: $tag" | tr ':/ ' '___')
    tiddlerFile="$outputWiki/tiddlers/$f.tid"
    if [ -f "$tiddlerFile" ]; then 
	echo "Warning: tiddler file '$tiddlerFile' already exists, no community tag tiddler written." 1>&2
    else
	echo "title: CommunityTag: $tag" >"$tiddlerFile"
	echo "tags: CommunityTags" >>"$tiddlerFile"
	echo "community-tag: $tag" >>"$tiddlerFile"
	echo "community-tag-count: $nb" >>"$tiddlerFile"
	echo  >>"$tiddlerFile"
	echo "{{||\$:/CommunityTagTemplate}}" >>"$tiddlerFile"
    fi
done



