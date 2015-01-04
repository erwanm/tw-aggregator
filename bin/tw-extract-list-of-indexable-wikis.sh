#!/bin/bash

progName="tw-extract-list-of-indexable-wikis.sh"

function usage {
    echo "Usage: $progName [options] <wiki basis path> <indexable wikis tiddler>"
    echo
    echo "  <wiki basis path> contains a tiddler <indexable wikis tiddler>"
    echo "  which is rendered in order to obtain the list of wikis addresses."
    echo "  The addresses are extracted are printed to STDOUT."
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
wikiBasisPath="$1"
targetTiddler="$2"


htmlList=$(mktemp)
tiddlywiki "$wikiBasisPath" --output $(dirname "$htmlList") --rendertiddler "$targetTiddler" $(basename "$htmlList")
cat "$htmlList" | grep -v ">" | grep -v "<" | grep -v "^\s*$" | sed 's/^\s*//g'
rm -f $htmlList

