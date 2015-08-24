#!/bin/bash

source tw-lib.sh

progName="tw-extract-and-update-official-plugin-list.sh"

pluginOfficialListWikiId="inmysocks"
pluginOfficialListListingTiddler="twCard_Listing_-_Plugins"
pluginOfficialListTag="Plugin twCard"
pluginOfficialListTemplateTiddler="Plugin_Info_Template"

#pluginTargetMissingTitleOrAddressTitle="\$:/SourcePluginsFieldError"
#pluginTargetMissingTitleOrAddressFile="\$__SourcePluginsFieldError.tid"
#pluginTargetMissingTitleOrAddressTags="TWCSCore"



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

#targetTiddlerFile="$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"
#writeCreatedTodayField   >"$targetTiddlerFile"
#echo "title: $pluginTargetMissingTitleOrAddressTitle" >>"$targetTiddlerFile"
#echo "tags: $pluginTargetMissingTitleOrAddressTags"  >>"$targetTiddlerFile"
#echo "type: text/vnd.tiddlywiki"   >>"$targetTiddlerFile"
#echo  >>"$targetTiddlerFile"

jedsWikiList=$(mktemp)
echo "DEBUG: temp Jed's wiki list = $jedsWikiList" 1>&2

# PART 1: extracting relevant tiddlers from Jed's wiki and generating corresponding "plugin tidders"

#cp "$sourceWiki/$pluginOfficialListListingTiddler.tid" "$targetWiki/tiddlers/$pluginTargetListingTiddler.tid"
for tiddlerFile in $sourceWiki/*.tid; do 
    firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    hasPluginTag=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^tags:.*\[\[$pluginOfficialListTag\]\]")
    if [ ! -z "$hasPluginTag" ] ; then
	category=$(extractField "category" "$tiddlerFile" "$firstBlankLineNo")
	if [ -z "$category" ] ||  [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListListingTiddler.tid" ] || [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListTemplateTiddler.tid" ]; then
#	    cp "$tiddlerFile" "$targetWiki/tiddlers/"
	    echo "DEBUG: ignoring $tiddlerFile (not a plugin twCard tiddler)" 1>&2
	else
	    #	    echo "DEBUG: processing $tiddlerFile" 1>&2
	    targetTiddler="$targetWiki/tiddlers/$(basename "$tiddlerFile")"
	    tags=$(extractField "tags" "$tiddlerFile" $firstBlankLineNo)
	    printTiddlerFields "$tiddlerFile" "tags" $firstBlankLineNo >"$targetTiddler"
	    echo "$tags CommunityPlugins" >>"$targetTiddler"
	    pluginTitle=$(extractField "plugin_tiddler" "$tiddlerFile" $firstBlankLineNo)
	    
	    if [ -z "$pluginTitle" ] || [ ${pluginTitle:0:3} != "\$:/" ]; then
		echo "twcs-error: invalid/missing value for field 'plugin_tiddler'" >>"$targetTiddler"
		#		echo "DEBUG: missing field, excluding $tiddlerFile" 1>&2
		#		sourceTiddlerTitle=$(extractField "title" "$tiddlerFile" $firstBlankLineNo)
		#		echo "* [[$sourceTiddlerTitle]]" >>"$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"
	    else
		echo "$pluginTitle" # written to "$jedsWikiList" file
		pluginAddress=$(extractField "wiki" "$tiddlerFile" $firstBlankLineNo | removeTrailingSlash)
		if [ -z "$pluginAddress" ]; then
		    echo "twcs-error: error 1: missing value for field 'wiki'" >>"$targetTiddler"
		    echo  >>"$targetTiddler"
		    echo  "{{||$:/CommunityPluginError}}" >>"$targetTiddler"
		else
		    line=$(grep "^$pluginAddress\s$pluginTitle\s" "$pluginListFile")
		    if [ -z "$line" ]; then # no full match found...
			matchLines=$(grep "\s$pluginTitle\s" "$pluginListFile" | wc -l)
			if [ $matchLines -eq 0 ]; then # no partial match found
			    echo "twcs-error: error 2: no match found on plugin title (unknown wiki?)" >>"$targetTiddler"
			else
			    echo "twcs-error: error 3: found only partial match (plugin title ok), check wiki address" >>"$targetTiddler"
			fi
			echo  >>"$targetTiddler"
			echo  "{{||$:/CommunityPluginError}}" >>"$targetTiddler"
		    else
			wikiId=$(echo "$line" | cut -f 3)
			#			originalTiddlerFile=$(echo "$line" | cut -f 4)
			outputTiddlerFile=$(echo "$line" | cut -f 5)
			firstBlankLineNo=$(echo "$line" | cut -f 6)
			echo "twcs-wiki-id: $wikiId" >>"$targetTiddler"
			echo "twcs-tiddler-title-as-text: $(extractField source-tiddler-title-as-text "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddler"
			echo "twcs-tiddler-title-as-link: $(extractField source-tiddler-title-as-link "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddler"
			echo "twcs-description: $(extractField description "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddler"
			echo "twcs-author: $(extractField author "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddler"
			echo "twcs-version: $(extractField version "$outputTiddlerFile" "$firstBlankLineNo")" >>"$targetTiddler"
			echo >> "$targetTiddler"
			echo '{{||$:/CommunityPluginTemplate}}' >> "$targetTiddler"
		    fi
		fi
	    fi
	fi
    fi
done | sort >"$jedsWikiList"

extractedPluginsList=$(mktemp)
cut -f 2 "$pluginListFile" | sort -u >"$extractedPluginsList"
comm -13 "$jedsWikiList" "$extractedPluginsList" | while read plugin; do
    echo "DEBUG found unmatched extracted plugin: '$plugin'" 1>&2
    title="Unknown plugin '$plugin'"
    pluginAsFile=$(echo "$title" | tr '$:/' '___')
    targetTiddler="$targetWiki/tiddlers/$pluginAsFile"
    echo "title: $title" >"$targetTiddler"
    writeCreatedTodayField >>"$targetTiddler"
    echo "category: unknown" >>"$targetTiddler"
    echo "plugin_tiddler: $plugin" >>"$targetTiddler"
    echo "tags: [[$pluginOfficialListTag]] CommunityPlugins"  >>"$targetTiddler"
    echo "twcs-error: error 4: found unknown plugin" >>"$targetTiddler"
    echo >>"$targetTiddler"
    echo '{{||$:/CommunityPluginTemplate}}' >> "$targetTiddler"

done
echo "DEBUG: leaving tmp files; jed's=$jedsWikiList, extracted=$extractedPluginsList " 1>&2
exit 0
rm -f "$extractedPluginsList"  "$jedsWikiList"

