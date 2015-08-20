#!/bin/bash

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

function isPluginThemeOrJavascript {
    local tiddlerFile="$1"
    local maxLineNo="$2"
    pluginField=$(head -n $(( $maxLineNo - 1 )) "$tiddlerFile" | grep "^plugin-type:" | wc -l)
    if [ $pluginField -gt 0 ]; then
	return 1
    else
	typeField=$(head -n $(( $maxLineNo - 1 )) "$tiddlerFile" | grep "^type:")
	if [ ! -z "$typeField" ]; then
	    isJavascript=$(echo "$typeField" | grep "application/javascript")
	    if [ ! -z "$isJavascript" ]; then
		return 1
	    fi
	fi
	return 0
    fi
}




#
# from http://stackoverflow.com/questions/296536/urlencode-from-a-bash-script
#
rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
#  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}




#
# arguments of the form "field: value"
# CAUTION: no 'echo' (blank line) written at the end of the header!
function writeTiddlerHeader {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
    while [ $# -gt 0 ]; do
	echo "$1"
	shift
    done
}


function extractField {
    local fieldName="$1"
    local tiddlerFile="$2"
    local firstBlankLineNo="$3"
    head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^$fieldName: " | sed "s/^$fieldName: //"
}


function writePluginInfo {
    local wikiId="$1"
    local pluginTiddlerFile="$2"
    local firstBlankLineNo="$3"
    local targetFile="$4"

    echo "wiki-id: $wikiId" >>"$targetFile"
    echo "plugin-description: $(extractField description "$pluginTiddlerFile" "$firstBlankLineNo")" >>"$targetFile"
    echo "plugin-author: $(extractField author "$pluginTiddlerFile" "$firstBlankLineNo")" >>"$targetFile"
    echo "plugin-version: $(extractField version "$pluginTiddlerFile" "$firstBlankLineNo")" >>"$targetFile"
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

writeTiddlerHeader "title: $pluginTargetMissingTitleOrAddressTitle" "tags: $pluginTargetMissingTitleOrAddressTags" "type: text/vnd.tiddlywiki"  >"$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"
echo >>"$targetWiki/tiddlers/$pluginTargetMissingTitleOrAddressFile"

# PART 1: extracting relevant tiddlers from Jed's wiki and generating corresponding "plugin tidders"

#cp "$sourceWiki/$pluginOfficialListListingTiddler.tid" "$targetWiki/tiddlers/$pluginTargetListingTiddler.tid"
for tiddlerFile in $sourceWiki/*.tid; do 
    firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    hasPluginTag=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^tags:.*\[\[$pluginOfficialListTag\]\]")
    if [ ! -z "$hasPluginTag" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListListingTiddler.tid" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListTemplateTiddler.tid" ]; then
	hasCategoryField=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^category:")
	if [ ! -z "$hasCategoryField" ]; then
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
		writeTiddlerHeader "title: $targetTiddlerTitle" "source-wiki-address: $pluginAddress" "canonical-name: $pluginTitle" "name: $pluginName" "short-description: $pluginDescr" "type: text/vnd.tiddlywiki"  >"$targetTiddlerFile"
	    fi
	else
	    echo "Warning: no category plugin, ignoring tiddler file '$tiddlerFile'"
	fi
    fi
done

# PART 2: try to match the plugins actually found in the scrapped wikis against the source plugin tiddlers from Jed's wiki
# principle:
#  (1) if the plugin tiddler file exists and the plugin source wiki is the same, then it's a match: tag tiddler with CommunityPlugins
#  (2) if the file exists but not with the same wiki, then the extracted plugin is imported, we ignore it
#  (3) if the file doesn't exist, then there's an error somewhere which has to be manually fixed: in this case the target tiddler is created but incomplete, and not tagged with CommunityPlugins
#  (4) another incomplete case is a plugin for which there is an entry in Jed's list but nothing with the same canonical name in the extracted wikis: this is either an error or because the wiki is not in my list; has to be fixed manually, and here again the tiddler exists but does not get the CommunityPlugins tag.

cat  "$pluginListFile" | while read line; do
    wikiAddress=$(echo "$line" | cut -f 1)
    canonicalName=$(echo "$line" | cut -f 2)
    wikiId=$(echo "$line" | cut -f 3)
    tiddlerFile=$(echo "$line" | cut -f 4)
    firstBlankLineNo=$(echo "$line" | cut -f 5)
    targetTiddlerTitle=${canonicalName:3}
    targetTiddlerFile="$targetWiki/tiddlers/$(echo "$targetTiddlerTitle" | tr '/' '_').tid"
    echo "DEBUG: looking for $canonicalName, wiki=$wikiAddress, wikiId=$wikiId, tiddlerFile=$tiddlerFile, targetTiddlerFile=$targetTiddlerFile" 1>&2
    if [ -f "$targetTiddlerFile" ]; then # target plugin tiddler exists from Jed's list
	echo "DEBUG file exists..." 1>&2
	sourcePluginAddress=$(extractField "sourceWikiAddress" "$targetTiddlerFile" 100)
	if [ "$sourcePluginAddress" == "$wikiAddress" ]; then # MATCH FOUND
	    echo "DEBUG MATCH FOUND" 1>&2
	    writePluginInfo "$wikiId" "$tiddlerFile" "$firstBlankLineNo" "$targetTiddlerFile"
	    echo "tags: [[$wikiId]] $pluginOkTag" >> "$targetTiddlerFile"
	    echo >> "$targetTiddlerFile"
	fi
	# Remark: if no match is found, normally it means that the plugin is not from this wiki (imported plugin), so we simply ignore it.
    else # no match on plugin title
	echo "DEBUG no file." 1>&2
	writePluginInfo "$wikiId" "$tiddlerFile" "$firstBlankLineNo" "$targetTiddlerFile"
	    echo "tags: [[$wikiId]]" >> "$targetTiddlerFile"
	    echo >> "$targetTiddlerFile"
    fi

    
done

