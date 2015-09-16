#!/bin/bash

source tw-lib.sh

progName="tw-generate-community-news-static.sh"

function usage {
    echo "Usage: $progName [options] <community-search node.js wiki dir> <output dir>"
    echo
    echo  TODO
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -o <output wiki dir> default: '$outputWikiDir'"
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
inputTWCSWiki="$1"
outputDir="$2"

if [ -d "$outputDir" ]; then
    rm -rf "$outputDir"
fi
echo "$progName: rendering static CommunityNews"
tiddlywiki "$inputTWCSWiki" --rendertiddlers 'CommunityNews' '$:/core/templates/static.tiddler.html' static-news text/plain >/dev/null
tiddlywiki "$inputTWCSWiki" --rendertiddler '$:/core/templates/static.template.css' static-news/static.css text/plain >/dev/null
mv "$inputTWCSWiki"/output/static-news "$outputDir"
echo "$progName: done."
