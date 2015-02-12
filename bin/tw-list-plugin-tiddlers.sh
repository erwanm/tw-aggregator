#!/bin/bash

progName="tw-list-plugins-tiddlers.sh"

function usage {
    echo "Usage: $progName [options] <collected wikis dir>"  #<target wiki dir>
    echo
    echo "  Reads a list of lines <wiki address>|<wiki id> from STDIN; each"
    echo "  <wiki id> corresponds to a directory "
    echo "  <collected wikis dir>/<wiki id> (previously collected with"
    echo "  tw-harvest.sh), containing the tiddlers."
    echo 
    echo "  Every plugin tiddler found is printed to STDOUT with:"
    echo "  <wiki address> <plugin title> <wiki id> <tiddler file> <end header col no>"
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

function obsoleteTiddlerCreation {
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
		echo "type: text/vnd.tiddlywiki"  >>"$dest"
		echo  >>"$dest"
		echo "{{||\$:/CommunityPluginTemplate}}" >>"$dest"
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
if [ $# -ne 1 ]; then
    echo "Error: 1 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
collectedWikisDir="$1"
#targetWiki="$2"

while read line; do
    address=$(echo "$line" | cut -d "|" -f 1)
    name=$(echo "$line" | cut -d "|" -f 2)
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
		pluginTitle=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^title: " | sed 's/^title: //')
		echo -e "$address\t$pluginTitle\t$name\t$tiddlerFile\t$firstBlankLineNo"
	    fi
	done
	rm -f "$tiddlersList"
    else
	echo "Warning: no directory '$wikiDir', wiki '$name' ignored." 1>&2
    fi
done
