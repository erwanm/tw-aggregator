#!/bin/bash

source tw-lib.sh

progName="tw-harvest.sh"


function usage {
    echo "Usage: $progName [options] <dest dir> <wiki address> [wiki id]"
    echo
    echo "  Downloads the (standalone html) wiki at <wiki address> and converts"
    echo "  it to a node.js wiki named <wiki id> located in <dest dir>."
    echo
    echo "  If <wiki id> is not supplied, the name is extracted from the "
    echo "  address, which is assumed to have the following form:"
    echo "  http://<id>.tiddlyspot.com or http://mysite.com/<id>.html"
    echo
    echo "  If <wiki address> doesn't start with 'http', it is interpreted as"
    echo "  a local file."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}



#
# returns a (quite) user-friendly name without '/' characters from a wiki address.
# typically returns 'mywiki' for 'http://mywiki.tiddlyspot.com'; otherwise the part after the last '/'
#
function extractIdFromAddress {
    address="$1"
    if [ "${address:0:4}" == "http" ]; then # url
	name=$(echo "$address" | sed 's/\/$//' | sed 's/^http.*:\/\///' | sed 's/.tiddlyspot.com$//')
	echo "${name##*/}"
    else # local file
	echo $(basename "$address")
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
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "Error: 2 or 3 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
destDir="$1"
address="$2"
name="$3"

if [ ! -d "$destDir" ]; then
    echo "Error: directory $destDir does not exist." 1>&2
    exit 1
fi
if [ -z "$name" ]; then
    name=$(extractIdFromAddress "$address")
fi


exitCode=0
if [ "${address:0:4}" == "http" ]; then
    wget -P "$destDir" -q "$address" # download the wiki
    if [ $? -ne 0 ]; then
	echo "Warning: an error occured when trying to fetch wiki at '$address'" 1>&2
	exit 1
    fi
    if [ ! -f "$destDir"/index.html ]; then # if file not named index.html, rename it
	mv "$destDir/${address##*/}" "$destDir"/index.html
    fi
else   # otherwise, assuming it's a local standalone html file 
    if [ -f "$address" ]; then
	cp "$address" "$destDir"/index.html
    else
	echo "Warning: no local wiki found at '$address'" 1>&2
	exit 1
    fi
fi
pushd "$destDir"  >/dev/null
tiddlywiki "$name" --init server >/dev/null # create temporary node.js wiki 
tiddlywiki "$name" --load index.html >/dev/null # convert standalone to tid files
# extract wiki version
grep "<meta name=\"tiddlywiki-version\"" index.html | sed 's/ /\n/g' | grep "^content=" | cut -d '"' -f 2 >"$name.version"
rm -f index.html
popd >/dev/null
