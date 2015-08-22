#!/bin/bash

source tw-lib.sh

progName="tw-extract-and-update-official-plugin-list.sh"

pluginOfficialListWikiId="inmysocks"
pluginOfficialListListingTiddler="twCard_Listing_-_Plugins"
pluginOfficialListTag="Plugin twCard"
pluginOfficialListTemplateTiddler="Plugin_Info_Template"

pluginTargetMissingTitleOrAddressTitle="\$:/SourcePluginsFieldError"
pluginTargetMissingTitleOrAddressFile="\$__SourcePluginsFieldError.tid"
pluginTargetMissingTitleOrAddressTags="TWCSCore"

pluginOkTag="CommunityPlugins"



function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir> <plugin list file>"
    echo
    echo TODO
    echo "  <plugin list file> is a text file containing all the plugin tiddlers found in all the"
    echo "  extracted wikis. It contains lines like this:"
    echo "  <wiki address>  <wiki id> <tiddler file> <plugin title> <end header col no>"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}

function writePluginInfo {
    local wikiId="$1"
    local pluginTiddlerFile="$2"
    local firstBlankLineNo="$3"
    local targetTiddlerFile="$4"

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
collectedWikisDir="$1"
targetWiki="$2"
pluginListFile="$3"

sourceWiki="$collectedWikisDir/$pluginOfficialListWikiId/tiddlers/"
if [ ! -f "$sourceWiki/$pluginOfficialListListingTiddler.tid" ]; then
    echo "Error: no listing tiddler in the plugin source wiki: cannot open '$sourceWiki/$pluginOfficialListListingTiddler.tid'" 1>&2
    exit 3
fi

targetTiddlerFile="$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"
writeCreatedTodayField   >"$targetTiddlerFile"
echo "title: $pluginTargetMissingTitleOrAddressTitle" >>"$targetTiddlerFile"
echo "tags: $pluginTargetMissingTitleOrAddressTags"  >>"$targetTiddlerFile"
echo "type: text/vnd.tiddlywiki"   >>"$targetTiddlerFile"
echo  >>"$targetTiddlerFile"

# PART 1: extracting relevant tiddlers from Jed's wiki and generating corresponding "plugin tidders"

#cp "$sourceWiki/$pluginOfficialListListingTiddler.tid" "$targetWiki/tiddlers/$pluginTargetListingTiddler.tid"
for tiddlerFile in $sourceWiki/*.tid; do 
    firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    hasPluginTag=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^tags:.*\[\[$pluginOfficialListTag\]\]")
    if [ ! -z "$hasPluginTag" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListListingTiddler.tid" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListTemplateTiddler.tid" ]; then
	category=$(extractField "category" "$tiddlerFile" "$firstBlankLineNo")
	if [ ! -z "$category" ]; then
#	    echo "DEBUG: processing $tiddlerFile" 1>&2
	    pluginTitle=$(extractField "plugin_tiddler" "$tiddlerFile" $firstBlankLineNo)
	    pluginAddress=$(extractField "wiki" "$tiddlerFile" $firstBlankLineNo)
	    if [ -z "$pluginTitle" ] || [ -z "$pluginAddress" ] || [ ${pluginTitle:0:3} != "\$:/" ]; then
#		echo "DEBUG: missing field, excluding $tiddlerFile" 1>&2
		sourceTiddlerTitle=$(extractField "title" "$tiddlerFile" $firstBlankLineNo)
		echo "* [[$sourceTiddlerTitle]]" >>"$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"
	    else
		pluginName=$(extractField "name" "$tiddlerFile" $firstBlankLineNo)
		pluginDescr=$(extractField "short_description" "$tiddlerFile" $firstBlankLineNo)
		targetTiddlerTitle=${pluginTitle:3}
		targetTiddlerFile="$targetWiki/tiddlers/$(echo "$targetTiddlerTitle" | tr '/' '_').tid"
		if [ -f "$targetTiddlerFile" ]; then
		    echo "Warning: file $targetTiddlerFile already exists! overwriting it..." 1>&2
		fi
		writeCreatedTodayField   >"$targetTiddlerFile"
		echo "title: $targetTiddlerTitle" >>"$targetTiddlerFile"
		echo "source-wiki-address: $pluginAddress" >>"$targetTiddlerFile"
		echo "canonical-name: $pluginTitle" >>"$targetTiddlerFile"
		echo "name: $pluginName" >>"$targetTiddlerFile"
		echo "short-description: $pluginDescr" >>"$targetTiddlerFile"
		echo "category: $category" >>"$targetTiddlerFile"
		echo "type: text/vnd.tiddlywiki" >>"$targetTiddlerFile"
	    fi
	else
	    echo "Warning: no category plugin, ignoring tiddler file '$tiddlerFile'"
	fi
    fi
done

# PART 2: try to match the plugins actually found in the scrapped wikis against the source plugin tiddlers from Jed's list
# principle:
# If the plugin tiddler file exists and the plugin source wiki is the same, then it's a
#  match, tag tiddler with CommunityPlugins; otherwise ignore.
# As a result, there are XX cases for unmatched plugins:
#  - in Jed's list but not found in theextracted wikis -> the wiki is not in my list
#    or there's a different address. In this case a non-system tiddler named after the
#    plugin exists but does not have the CommunityWikis tag.
#  - in extracted wikis but not in Jed's list -> it's an imported plugin or there's a
#    different address. In this case there is a system tiddler with field extracted-plugin
#    but no matching wiki.

cat  "$pluginListFile" | while read line; do
    wikiAddress=$(echo "$line" | cut -f 1)
    canonicalName=$(echo "$line" | cut -f 2)
    wikiId=$(echo "$line" | cut -f 3)
    originalTiddlerFile=$(echo "$line" | cut -f 4)
    outputTiddlerFile=$(echo "$line" | cut -f 5)
    firstBlankLineNo=$(echo "$line" | cut -f 6)
    targetTiddlerTitle=${canonicalName:3}
    targetTiddlerFile="$targetWiki/tiddlers/$(echo "$targetTiddlerTitle" | tr '/' '_').tid"
#    echo "DEBUG: looking for $canonicalName, wiki=$wikiAddress, wikiId=$wikiId, originalTiddlerFile=$originalTiddlerFile, outputTiddlerFile=$outputTiddlerFile, targetTiddlerFile=$targetTiddlerFile" 1>&2
    if [ -f "$targetTiddlerFile" ]; then # target plugin tiddler exists from Jed's list
	sourcePluginAddress=$(extractField "source-wiki-address" "$targetTiddlerFile" 100)
	if [ "$sourcePluginAddress" == "$wikiAddress" ]; then # MATCH FOUND
#	    echo "DEBUG MATCH FOUND" 1>&2
	    echo "plugin-description: $(extractField description "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddlerFile"
	    echo "plugin-author: $(extractField author "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddlerFile"
	    echo "plugin-version: $(extractField version "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddlerFile"
	    echo "source-wiki-id: $wikiId" >>"$targetTiddlerFile"
	    echo "source-tiddler-title-as-text: $(extractField source-tiddler-title-as-text "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddlerFile"
	    echo "source-tiddler-title-as-link: $(extractField source-tiddler-title-as-link "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddlerFile"
	    echo "tags: [[$wikiId]] $pluginOkTag" >> "$targetTiddlerFile"
	    echo >> "$targetTiddlerFile"
	    echo '{{||$:/CommunityPluginTemplate}}' >> "$targetTiddlerFile"
#	else
#	    echo "DEBUG file exists but different wiki address" 1>&2
	fi
    fi
done

