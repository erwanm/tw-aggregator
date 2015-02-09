#!/bin/bash

progName="tw-extract-plugins-info.sh"

function usage {
    echo "Usage: $progName [options] <collected wikis dir> <target wiki dir>"
    echo
    echo "  Reads a list of wiki ids from STDIN; each <wiki id> corresponds to"
    echo "  a directory <collected wikis dir>/<wiki id> (previously collected"
    echo "  with tw-harvest.sh), containing the tiddlers."
    echo 
    echo "  For every plugin tiddlers found, a tiddler is created."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}

function isPlugin {
    local tiddlerFile="$1"
    local maxLineNo="$2"
    pluginField=$(head -n $(( $maxLineNo - 1 )) "$tiddlerFile" | grep "^plugin-type: plugin" | wc -l)
    if [ $pluginField -gt 0 ]; then
	return 1
    else
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

while read name; do
    wikiDir="$collectedWikisDir/$name"
    if [ -d "$wikiDir" ]; then
	echo "Processing wiki '$name'" 1>&2
	tiddlersList=$(mktemp)
	ls "$wikiDir"/tiddlers/*.tid | while read f; do
	    if [ -f "$f" ]; then
		echo "$f"
	    else
		echo "Warning: cannot open file '$f' in wiki '$name'" 1>&2
	    fi
	done >"$tiddlersList"
	cat "$tiddlersList" | while read tiddlerFile; do
	    firstBlankLineNo=$(cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
	    basef=$(basename "$tiddlerFile")
	    isPlugin "$tiddlerFile" "$firstBlankLineNo"
	    if [ $? -eq 1 ]; then
		dest="$targetWiki/tiddlers/\$__${name}_$basef"
		oldTitle=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^title:" | sed 's/^title: //g')
		newTitle="\$:/$name/$oldTitle" # convert title to system tiddler with wiki id prefix
		echo "title: $newTitle" >"$dest"
		head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep -v "^title:" | grep -v "^tags:" | grep -v "plugin-type:" >>"$dest" # copy fields except title and tags (normally there are no tags in a plugin tiddler)
		echo "source-wiki-id: $name" >>"$dest" # store custom fields in order to recompute the original address
		echo "source-tiddler-title-as-text: $oldTitle" >>"$dest"   
		echo -n "source-tiddler-title-as-link: " >>"$dest"
		rawurlencode "$oldTitle" >>"$dest"  # new version with url-encoding
		echo "tags: $name CommunityPlugins" >>"$dest"
		echo "type: text/vnd.tiddlywiki"
		echo  >>"$dest"
		echo "{{||\$:/CommunityPluginTemplate}}" >>"$dest"
	    fi
	done
	rm -f "$tiddlersList"
    else
	echo "Warning: no directory '$wikiDir', wiki '$name' ignored." 1>&2
    fi
done
