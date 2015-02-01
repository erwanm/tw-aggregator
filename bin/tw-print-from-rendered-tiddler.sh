#!/bin/bash

progName="tw-print-from-rendered-tiddler.sh"

function usage {
    echo "Usage: $progName [options] <wiki basis path> <tiddler>"
    echo
    echo "  <wiki basis path> contains a tiddler <tiddler>"
    echo "  which is rendered, and its content is printed to STDOUT"
    echo "  (after being cleaned from html tags)."
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
#echo $htmlList
tiddlywiki "$wikiBasisPath" --output $(dirname "$htmlList") --rendertiddler "$targetTiddler" $(basename "$htmlList")
cat "$htmlList" | sed 's/<[^>]*>/\n/g' | grep -v "^\s*$" | sed 's/^\s*//g' | sed 's/&amp;/\&/g' # dirty...
rm -f $htmlList

