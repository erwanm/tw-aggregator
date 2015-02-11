#!/bin/bash

progName="tw-extract-and-update-official-plugin-list.sh"
pluginOfficialListWikiId="inmysocks"
pluginOfficialListListingTiddler="twCard Listing - Plugins"
pluginOfficialListTag="Plugin twCard"
pluginTargetListingTiddler="CommunityPlugins"
pluginOfficialListTemplateTiddler="Plugin Info Template"
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


function writeTags {
    local name="$1"
    local tags="$2"

    echo -n "tags: $name"
    set -- $tags
#    echo "DEBUG TAGS='$tags'" 1>&2
    local regex="^\\\$:/"
    while [ ! -z "$1" ]; do
	tag="$1"
	if [ "${tag:0:2}" == "[[" ]; then
	    while [ ${tag:(-2)} != "]]" ]; do
		shift
		tag="$tag $1"
	    done
#	    echo "DEBUG: found possible multiword tag='$tag'" 1>&2
	    if [[ ! ${tag:2} =~ $regex ]]; then # keep it if not a system tag, otherwise ignore it
		echo -n " $tag"
	    fi
	else
#	    if [  "${tag:0:2}" == '$(' ] || [  "${tag:(-2)}" == ')$' ]; then
#		echo "DEBUG found varialbe in tags: '$tag'" 1>&2
#	    fi
	    if [[ ! $tag =~ $regex ]] && [  "${tag:0:2}" != '$(' ] && [  "${tag:(-2)}" != ')$' ]; then # keep it if not a system tag, otherwise ignore it # added bug fix #8: ignore also if variable
		echo -n " $tag"
	    fi
	fi
	shift
    done
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
cp "$sourceWiki/$pluginOfficialListListingTiddler.tid" "$targetWiki/tiddlers/$pluginTargetListingTiddler.tid"
for tiddlerFile in $sourceWiki/*.tid; do 
    firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
    hasPluginTag=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^tags:.*\[\[$pluginOfficialListTag\]\]")
    if [ ! -z "$hasPluginTag" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListListingTiddler.tid" ] && [ "$tiddlerFile" != "$sourceWiki/$pluginOfficialListTemplateTiddler.tid" ]; then
	hasCategoryField=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^category:")
	if [ ! -z "$hasCategoryField" ]; then
#	    echo "DEBUG: $tiddlerFile" 1>&2
	    pluginTitle=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^plugin_tiddler: " | sed 's/^plugin_tiddler: //')
	    pluginLine=$(grep "\s$pluginTitle\s" "$pluginListFile")

TODO:	    match on two conditions: same wiki address + same plugin title

	    pluginWiki=$(echo "$pluginLine" | cut -f 2)
	    pluginFile=$(echo "$pluginLine" | cut -f 2)
	    
	fi
    fi
done
