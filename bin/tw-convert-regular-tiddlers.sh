#!/bin/bash

progName="tw-convert-regular-tiddlers.sh"
whitelistSpecialTiddler="$:/CommunitySearchIndexableTiddlers"
whitelistSpecialTiddlerFilename=$(echo "$whitelistSpecialTiddler" | sed 's/^$:\//$__/')

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  The following steps are applied to every regular tiddler:"
    echo "  * convert to system tiddler"
    echo "  * rename as \$:/<wiki-name>/<title>"
    echo "  * remove any system tag"
    echo "  * add field 'source-wiki-id' with value <wiki-name>"
    echo "  * add field 'source-wiki-title' with value <title>"
    echo "  Plugin/theme tiddlers are ignored, as well as tiddler with type"
    echo "  application/javascript."
    echo
    echo "  Additionally, if a tiddler contains a field 'follow' with value"
    echo "  'YES' and a field 'url', then the url is printed to STDOUT as:"
    echo "  <original wiki name> <url new wiki>"
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




#
#
#
function followUrlTiddler  {
    local tiddlerFile="$1"
    local firstBlankLineNo="$2"
    local sourceWikiName="$3"
    local tiddlerDir="$4"

    follow=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^follow:" | sed 's/^follow: //g')
    if [ "${follow,,}" == "yes" ]; then
	url=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^url:" | sed 's/^url: //g')
	title=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^title:" | sed 's/^title: //g')
	if [ ! -z "$url" ] && [ ! -f "$tiddlerDir/$title.tid" ] ; then # second condition to ensure the wiki hasn't been already extracted
	    echo "$sourceWikiName $url $title"
	fi
    fi
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
collectedWikisDir="$1"
targetWiki="$2"

regex="^\\\$__"
for wikiDir in "$collectedWikisDir"/*; do
    if [ -d "$wikiDir" ]; then
	if [ "$(basename "$targetWiki")" != "$(basename "$wikiDir")" ]; then # skip target wiki
	    name=$(basename "$wikiDir")
	    if [ -f "$wikiDir/tiddlers/$whitelistSpecialTiddlerFilename.tid" ]; then
		tw-print-from-rendered-tiddler.sh "$wikiDir" "$whitelistSpecialTiddler" > TODOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO

TODO

	    else
	    fi
	    for tiddlerFile in "$wikiDir"/tiddlers/*.tid; do
		firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
		basef=$(basename "$tiddlerFile")
		isPluginThemeOrJavascript "$tiddlerFile" "$firstBlankLineNo"
		if [ $? -eq 0 ] && [[ ! $basef =~ $regex ]]; then # ignore plugins/themes and system tiddlers
#		    echo "debug regular '$basef'" 1>&2
		    dest="$targetWiki/tiddlers/\$__${name}_$basef"
		    oldTitle=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^title:" | sed 's/^title: //g')
		    newTitle="\$:/$name/$oldTitle" # convert title to system tiddler with wiki id prefix
		    echo "title: $newTitle" >"$dest"
		    head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep -v "^title:" | grep -v "^tags:" >>"$dest" # copy fields except title and tags
		    oldTags=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^tags:" | sed 's/^tags: //g')
		    writeTags "$name" "$oldTags" >>"$dest"
		    echo "source-wiki-id: $name" >>"$dest" # store custom fields in order to recompute the original address
		    # url-encode the title, in case it contains characters like # (see github bug #24)
		    # also keep the non-encoded title (named source-tiddler-title-as-text), to display it in a user-friendly readable text
		    # without the prefix '$:/<wiki name>/' (maybe possible to user remove-suffix instead ?? regexp ?)
		    echo "source-tiddler-title-as-text: $oldTitle" >>"$dest"   
		    echo -n "source-tiddler-title-as-link: " >>"$dest"
		    rawurlencode "$oldTitle" >>"$dest"  # new version with url-encoding
		    tail -n +$firstBlankLineNo "$tiddlerFile" >>"$dest"
		    followUrlTiddler "$tiddlerFile" $firstBlankLineNo "$name" "$targetWiki/tiddlers"
		fi
	    done
	fi
    fi
done
