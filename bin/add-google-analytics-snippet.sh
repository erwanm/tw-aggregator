#!/bin/bash

progName="add-google-analytics-snippet.sh"

function usage {
    echo "Usage: $progName [options] <GoogleAnalytics Tracking ID> <input html> <output html>"
    echo
    echo "  Adds the GoogleAnalytics snippet to <input html file> and returns"
    echo "  the result in <output html>"
    echo
    echo "Options:"
    echo "  -h this help message"
    echo    
}


function writeGoogleSnippet {
    local id="$1"

    echo "<script>"
    echo "  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){"
    echo "  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),"
    echo "  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)"
    echo "  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');"
    echo "  ga('create', '$id', 'auto');"
    echo "  ga('send', 'pageview');"
    echo
    echo "</script>"
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
trackingId="$1"
inputFile="$2"
outputFile="$3"


lineNo=$(grep -n "</head>\s*$" "$inputFile" | cut -f 1 -d ":")
if [ -z "$lineNo" ]; then
    echo "Error: pattern '</head>\s*$' not found in file '$inputFile'" 1>&2
    exit 5
fi
head -n $(( $lineNo - 1 )) "$inputFile" > "$outputFile"
writeGoogleSnippet "$trackingId" >> "$outputFile"
tail -n +$lineNo  "$inputFile" >> "$outputFile"

