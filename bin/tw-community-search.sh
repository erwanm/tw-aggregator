#!/bin/bash

source tw-lib.sh

progName="tw-community-search.sh"
outputFilename=${progName%.sh}.html
inputWikiBasis="skeleton"
removeWorkDir=1
skipHarvest=0
workDir=
indexableWikiAddressListTiddler="$:/IndexableWikiAddressList"
anyWikiAddressListTiddler="$:/AnyWikiAddressList"
testWikiAddressListTiddler="$:/TestWikiAddressList"

# wikis whose tiddlers might be found as duplicates elsewhere
potentialDuplicateSourceWikis="tiddlywiki.com"
# list of target wikis to check for duplicates
# either one of the two versions below can be used, but not at the same time
#checkForDuplicatesWikis="cpashow" # wikis to check
checkForDuplicatesWikis="!$potentialDuplicateSourceWikis" # wikis NOT to check
duplicateChecksumFile="source-tiddlers.md5"
tagsFilename="community-tags.list"

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
    echo "  -t use test list of wikis instead of full list (= debug mode)"
    echo    
}




function findWikiAuthor {
    local tiddlersPath="$1"
    local wikiName="$2"
    grep "^author: " "$tiddlersPath/$wikiName.tid" | sed 's/^author: //'
}


while getopts 'ho:kd:st' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"o" ) outputFilename="$OPTARG";;
	"k" ) removeWorkDir=0;;
	"s" ) skipHarvest=1;;
	"d" ) workDir="$OPTARG";;
	"t" ) indexableWikiAddressListTiddler="$testWikiAddressListTiddler"
	      anyWikiAddressListTiddler="$testWikiAddressListTiddler";;
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
    if [ $skipHarvest -ne 1 ]; then
	if [ -d "$workDir" ]; then
	    echo "Warning: removing any previous content in '$workDir'" 1>&2
	    rm -rf "$workDir"/*
	else
	    mkdir "$workDir"
	fi
    else
	if [ ! -d "$workDir" ]; then
	    echo "Error: '$workDir' does not exist but option '-s' supplied" 1>&2
	    exit 2
	fi
    fi
    removeWorkDir=0
fi

indexableWikiListFile="$workDir/indexable-wikis.list"
anyWikiListFile="$workDir/all-wikis.list"
tw-print-from-rendered-tiddler.sh "$inputWikiBasis" "$indexableWikiAddressListTiddler" >"$indexableWikiListFile"
tw-print-from-rendered-tiddler.sh "$inputWikiBasis" "$anyWikiAddressListTiddler" >"$anyWikiListFile"

visitedUrlsFile="$workDir/visited-urls.list"
rm -f "$visitedUrlsFile"
exitCode=0
if [ $skipHarvest -ne 1 ]; then
    tw-harvest-list.sh "$anyWikiListFile" "$workDir" "$visitedUrlsFile"
    exitCode="$?"
else # simulate harvested wiki in order to keep visited-urls list up to date
    cat "$anyWikiListFile" | cut -f 1 -d "|" | grep "^http" | sed 's:/$::' >>"$visitedUrlsFile"
fi

rm -f "$workDir/$duplicateChecksumFile"
for wikiSource in $potentialDuplicateSourceWikis; do
    if [ -d "$workDir/$wikiSource" ]; then
	echo "Computing checksum for wiki $wikiSource..."
	md5sum "$workDir/$wikiSource/tiddlers"/* | cut -f 1 -d " " >>"$workDir/$duplicateChecksumFile"
    else
	echo "Warning: no directory found for source wiki '$wikiSource' (duplicate detection, source step)" 1>&2
    fi
done

if [ $exitCode -eq 0 ]; then
    echo "Preparing output wiki..."
    if [ -d "$workDir/output-wiki" ]; then
	rm -rf "$workDir/output-wiki"
    fi
    tiddlywiki "$workDir/output-wiki" --init server >/dev/null
    mkdir "$workDir"/output-wiki/tiddlers
    cp "$inputWikiBasis"/tiddlers/* "$workDir"/output-wiki/tiddlers

    tagsListFile="$workDir/$tagsFilename"
    rm -f "$tagsListFile"
    # remark: the loop is for "follow url" option; this option is available only for indexable wikis (not other wikis, taken into account only for plugins)
    while [ -s  "$indexableWikiListFile" ] && [ $exitCode -eq 0 ] ; do # loop for sub-wikis (field 'follow')
	subwikiListFile="$workDir/subwikis.list"
	cat "$indexableWikiListFile" | cut -d "|" -f 2 | tw-convert-regular-tiddlers.sh -d "$workDir/$duplicateChecksumFile:$checkForDuplicatesWikis" -t "$tagsListFile" "$workDir" "$workDir/output-wiki" "$subwikiListFile" "$visitedUrlsFile"
	cat "$indexableWikiListFile" | cut -d "|" -f 2 | tw-update-presentation-tiddlers.sh  "$workDir" "$workDir/output-wiki"
	nbSubWikis=$(cat "$subwikiListFile" | wc -l)
	echo " $nbSubWikis sub-wikis to follow."
	cut -f 2,3 -d "|" "$subwikiListFile" >> "$anyWikiListFile" # add to the list of all wikis for plugin extraction
	if [ $nbSubWikis -gt 0 ]; then
	    cat "$subwikiListFile" | while read line; do
		sourceWiki=$(echo "$line" | cut -d "|" -f 1)
		address=$(echo "$line" | cut -d "|" -f 2)
		title=$(echo "$line" | cut -d "|" -f 3)
		author=$(findWikiAuthor "$workDir/output-wiki/tiddlers" "$sourceWiki")
		echo "  Generating new community wiki tiddler: '$title' by '$author' at '$address'"
		tiddlerFile="$workDir/output-wiki/tiddlers/$title.tid"
		# stopped writing creation date to avoid spurious changes in git commit when the wiki tiddler existed before
		#writeCreatedTodayField >"$tiddlerFile"
		echo "title: $title" >"$tiddlerFile"
		echo "tags: CommunityWikis" >>"$tiddlerFile"
		echo "type: text/vnd.tiddlywiki" >>"$tiddlerFile"
		echo "wiki-address: $address" >>"$tiddlerFile"
		echo "author: $author" >>"$tiddlerFile"
		echo  >>"$tiddlerFile"
		echo "{{||\$:/CommunityWikiAuthorTemplate}}" >>"$workDir/output-wiki/tiddlers/$title.tid"
	    done
	    cut -d "|" -f 2,3 "$subwikiListFile" > "$indexableWikiListFile"
	    if [ $skipHarvest -ne 1 ]; then
		tw-harvest-list.sh "$indexableWikiListFile" "$workDir" "$visitedUrlsFile"
		exitCode="$?"
	    else # simulate harvested wiki in order to keep visited-urls list up to date
		cat "$indexableWikiListFile" | cut -f 1 -d "|" | grep "^http" | sed 's:/$::' >>"$visitedUrlsFile"
	    fi
	else 
	    rm -f "$indexableWikiListFile"
	fi
    done

    echo "Generating tags tiddlers"
    tw-generate-tag-tiddlers.sh  "$tagsListFile" "$workDir" "$workDir/output-wiki"

    # special tiddler to record the date of the last update
    tiddlerFile="$workDir/output-wiki/tiddlers/LastUpdate.tid"
    writeCreatedTodayField >"$tiddlerFile"
    echo "title: LastUpdate" >>"$tiddlerFile"
    echo "tags: TWCSCore"  >>"$tiddlerFile"

    echo "Generating the plugins directory, part 1: searching extracted plugins"
    pluginTiddlersList="$workDir/plugin-tiddlers.list"
    cat "$anyWikiListFile" | tw-list-plugin-tiddlers.sh "$workDir" "$workDir/output-wiki" > "$pluginTiddlersList" 
    echo "Generating the plugins directory, part 2: extracting curated list of plugins for matching"
    tw-extract-and-update-official-plugin-list.sh "$workDir" "$workDir/output-wiki" "$pluginTiddlersList"


    total=$(ls "$workDir"/output-wiki/tiddlers | wc -l)
    echo "Converting the output wiki to standalone html"
    tiddlywiki "$workDir/output-wiki" --rendertiddler "$:/plugins/tiddlywiki/tiddlyweb/save/offline" "output.html" text/plain >/dev/null
    mv "$workDir/output-wiki/output/output.html" "$outputFilename"
    if [ $removeWorkDir -ne 0 ]; then
	rm -rf "$workDir"
    fi
    echo "Done. $total tiddlers in result wiki '$outputFilename'"
fi
