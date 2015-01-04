#!/bin/bash

progName="tw-community-search.sh"
outputFilename=${progName%.sh}.html
inputWikiBasis="tw-aggregator-basis"
removeWorkDir=1
skipHarvest=0
workDir=
indexableWikiAddressListTiddler="$:/indexableWikiAddressList"

function usage {
    echo "Usage: $progName [options] [wiki basis path]"
    echo
    echo "  [wiki basis path] is the path to the community search wiki skeleton." 
    echo "  This wiki contains a tiddler '$indexableWikiAddressListTiddler'"
    echo "  which is rendered in order to obtain the list of wikis addresses;"
    echo "  then these wikis are harvested (downloaded and converted to node.js);"
    echo "  Then the script extracts the non-system tiddlers and copies them as"
    echo "  system tiddlers in the output wiki (with various checks/adaptations)."
    echo "  The 'wiki basis' is is expected by default in the current directory"
    echo "  under the name '$inputWikiBasis'"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -o <standalone html output filename>. Default: $outputFilename."
    echo "  -k keep working dir (for debugging purpose mostly)"
    echo "  -d <working dir> use this path as working directory instead of"
    echo "     creating a temporary dir. -k is implied."
    echo "  -s skip harvest part (to be used with -d)"
    echo    
}





while getopts 'ho:kd:s' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"o" ) outputFilename="$OPTARG";;
	"k" ) removeWorkDir=0;;
	"s" ) skipHarvest=1;;
	"d" ) workDir="$OPTARG";;
        "?" )
            echo "Error, unknow option." 1>&2
            usage 1>&2
	    exit 1
    esac
done
shift $(($OPTIND - 1)) # skip options already processed above
if [ $# -ne 0 ] && [ $# -ne 1 ]; then
    echo "Error: 0 or 1 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
if [ $# -eq 1 ]; then
    inputWikiBasis="$1"
fi

if [ -z "$workDir" ]; then
    workDir=$(mktemp -d)
else
    removeWorkDir=0
fi
exitCode=0
if [ $skipHarvest -ne 1 ]; then
    wikiListFile="$workDir/wikis.list"
    tw-extract-list-of-indexable-wikis.sh "$inputWikiBasis" "$indexableWikiAddressListTiddler" >"$wikiListFile"
    tw-harvest.sh "$wikiListFile" "$workDir"
    exitCode="$?"
fi

if [ $exitCode -eq 0 ]; then
    echo "Preparing output wiki..."
    if [ -d "$workDir/output-wiki" ]; then
	rm -rf "$workDir/output-wiki"
    fi
    tiddlywiki "$workDir/output-wiki" --init server >/dev/null
    mkdir "$workDir"/output-wiki/tiddlers
    cp "$inputWikiBasis"/tiddlers/* "$workDir"/output-wiki/tiddlers

    tw-convert-regular-tiddlers.sh "$workDir" "$workDir/output-wiki"
    tw-generate-presentation-tiddlers.sh  "$workDir" "$workDir/output-wiki"


    total=$(ls "$workDir"/output-wiki/tiddlers/*.tid | wc -l)
    echo "Converting the output wiki to standalone html"
    tiddlywiki "$workDir/output-wiki" --rendertiddler "$:/plugins/tiddlywiki/tiddlyweb/save/offline" "output.html" text/plain
    mv "$workDir/output-wiki/output/output.html" "$outputFilename"
    if [ $removeWorkDir -ne 0 ]; then
	rm -rf "$workDir"
    fi
    echo "Done. $total tiddlers harvested, result in $outputFilename"
fi
