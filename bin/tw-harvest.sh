#!/bin/bash

progName="tw-scrap.sh"


function usage {
    echo "Usage: $progName [options] <list file> <dest dir>"
    echo
    echo "  Downloads the collection of wikis provided in <list file>, which"
    echo "  contains lines of the form:"
    echo "  <wiki address> [ <wiki short name> [<presentation tiddler title>] ]"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}


function absolutePath {
    target="$1"
    if [ -d "$target" ]; then
	pushd "$target" >/dev/null
    else
	pushd $(dirname "$target") >/dev/null
    fi
    path=$(pwd)
    if [ ! -d "$target" ]; then
	path="$path/$(basename "$target")"
    fi
    echo "$path"
    popd  >/dev/null
}

#
# returns a (quite) user-friendly name without '/' characters from a wiki address.
# typically returns 'mywiki' for 'http://mywiki.tiddlyspot.com'; otherwise the part after the last '/'
#
function extractIdFromAddress {
    address="$1"
    name=$(echo "$address" | sed 's/\/$//' | sed 's/^http.*:\/\///' | sed 's/.tiddlyspot.com$//')
    echo "${name##*/}"
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
wikiListFile="$1"
destDir="$2"

if [ ! -d "$destDir" ]; then
    echo "Error: directory $destDir does not exist." 1>&2
    exit 1
fi
if [ ! -e "$wikiListFile" ]; then
    echo "Error: file $wikiListFile does not exist." 1>&2
    exit 1
fi

wikiListFile=$(absolutePath "$wikiListFile")

pushd "$destDir"  >/dev/null
nbLines=$(cat "$wikiListFile" | wc -l)
nbSites=$(cat "$wikiListFile" | grep -v "^#" | wc -l)
echo "Reading $nbSites wikis..."
wikiNo=1
for lineNo in $(seq 1 $nbLines); do
    set -- $(head -n $lineNo "$wikiListFile" | tail -n 1)
    if [ "${1:0:1}" != "#" ]; then
	address=$(echo "$1" | sed 's/%20/ /g')
	shift
	name="$1"
	shift
	presentationTiddler="$@"
	if [ -z "$name" ]; then
	    name=$(extractIdFromAddress "$address")
	fi
	echo "$address" > "$name.address"
	echo "wiki $wikiNo/$nbSites: '$name'; fetching '$address'"
	wget -q "$address" # download the wiki
	if [ ! -f index.html ]; then # if file not named index.html, rename it
	    mv ${address##*/} index.html
	fi
	if [ $? -ne 0 ] || [ ! -f index.html ]; then # if error, ignore this wiki
	    echo "Warning: something wrong when fetching '$address'" 1>&2
	else
	    tiddlywiki "$name" --init server >/dev/null # create temporary node.js wiki 
	    tiddlywiki "$name" --load index.html >/dev/null # convert standalone to tid files
	    # extract wiki version
	    grep "<meta name=\"tiddlywiki-version\"" index.html | sed 's/ /\n/g' | grep "^content=" | cut -d '"' -f 2 >"$name.version"
	    rm -f index.html
	    if [ -z "$presentationTiddler" ]; then
		targetTiddler="$name/tiddlers/\$__SiteSubtitle.tid"
	    else
		if [ -e "$name/tiddlers/$presentationTiddler.tid" ]; then
		    targetTiddler="$name/tiddlers/$presentationTiddler.tid"
		else
		    echo "Warning: presentation tiddler '$presentationTiddler' does not exist in '$name'" 1>&2
		    targetTiddler="$name/tiddlers/\$__SiteSubtitle.tid"
		fi
	    fi
	    if [ -e "$targetTiddler" ]; then
		ln -s "$targetTiddler" "$name.presentation"
	    else
		echo "Warning: no site subtitle in '$name' (no presentation tiddler)" 1>&2
	    fi
	fi
	wikiNo=$(( $wikiNo + 1 ))
    fi
done
popd >/dev/null
