#!/bin/bash

progName="tw-community-search.sh"
outputFilename=${progName%.sh}.html
inputWikiBasis="tw-aggregator-basis"
removeWorkDir=1
skipHarvest=0
workDir=

function usage {
    echo "Usage: $progName [options] <list file>"
    echo
    echo "  First harvests the collection of wikis provided in <list file>, which"
    echo "  contains lines of the form:"
    echo "  <wiki address> [ <wiki short name> [<presentation tiddler title>] ]"
    echo "  Then extracts the non-system tiddlers and copies them as system"
    echo "  tiddlers in the output wiki (with various checks and adaptations)."
    echo "  The 'empty' wiki core (which contains the basic tiddlers, e.g. the"
    echo "  search form and specific code) must exist: it is expected by default"
    echo "  in the current directory under the name '$inputWikiBasis'"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -b <wiki basis path>. Default: $inputWikiBasis."
    echo "  -o <standalone html output filename>. Default: $outputFilename."
    echo "  -k keep working dir (for debugging purpose mostly)"
    echo "  -d <working dir> use this path as working directory instead of"
    echo "     creating a temporary dir. -k is implied."
    echo "  -s skip harvest part (to be used with -d)"
    echo    
}





while getopts 'hb:o:kd:s' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"b" ) inputWikiBasis="$OPTARG";;
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
if [ $# -ne 1 ]; then
    echo "Error: 1 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
wikiListFile="$1"

if [ -z "$workDir" ]; then
    workDir=$(mktemp -d)
else
    removeWorkDir=0
fi
if [ $skipHarvest -ne 1 ]; then
    tw-harvest.sh "$wikiListFile" "$workDir"
fi
echo "Preparing output wiki..."
if [ -d "$workDir/output-wiki" ]; then
    rm -rf "$workDir/output-wiki"
fi
tiddlywiki "$workDir/output-wiki" --init server >/dev/null
mkdir "$workDir"/output-wiki/tiddlers
cp "$inputWikiBasis"/tiddlers/* "$workDir"/output-wiki/tiddlers

tw-convert-regular-tiddlers.sh "$workDir" "$workDir/output-wiki"



total=$(ls "$workDir"/output-wiki/tiddlers/*.tid | wc -l)
echo "Converting the output wiki to standalone html"
tiddlywiki "$workDir/output-wiki" --rendertiddler "$:/plugins/tiddlywiki/tiddlyweb/save/offline" "output.html" text/plain
mv "$workDir/output-wiki/output/output.html" "$outputFilename"
if [ $removeWorkDir -ne 0 ]; then
    rm -rf "$workDir"
fi
echo "Done. $total tiddlers harvested, result in $outputFilename"
