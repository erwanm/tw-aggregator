#!/bin/bash

source tw-lib.sh

progName="tw-generate-community-news-static.sh"
outputWikiDir="./tw-community-news"

function usage {
    echo "Usage: $progName [options] <community-search node.js wiki dir>"
    echo
    echo  TODO
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -o <output wiki dir> default: '$outputWikiDir'"
    echo    
}


function copyAllTiddlersTagged {
    local sourceWikiDir="$1"
    local destWikiDir="$2"
    local tag="$3"

    grep "^tags:.*$tag" "$sourceWikiDir"/tiddlers/*.tid | cut -d ":" -f 1 | while read f; do
	cp "$f" "$destWikiDir"/tiddlers
    done
}



while getopts 'ho:' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"o" ) outputWikiDir="$OPTARG";;
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
inputTWCSWiki="$1"

echo "$progName: initializing new wiki '$outputWikiDir'"
tiddlywiki "$outputWikiDir" --init server >/dev/null
mkdir "$outputWikiDir"/tiddlers
echo "$progName: copying news tiddlers (and a few others) to '$outputWikiDir/tiddlers'"
for f in CommunityNews.tid '$__WikiLinkAndContentTemplate.tid' '$__TWCSMacros.tid' '$__core_ui_ListItemTemplate.tid'; do
    cp "$inputTWCSWiki/tiddlers/$f" "$outputWikiDir"/tiddlers
done
copyAllTiddlersTagged "$inputTWCSWiki" "$outputWikiDir" "CommunityNews"
copyAllTiddlersTagged "$inputTWCSWiki" "$outputWikiDir" "CommunityAuthors"
copyAllTiddlersTagged "$inputTWCSWiki" "$outputWikiDir" "CommunityWikis"

writeSimpleTiddler '$:/SiteTitle' "TW Community News" >"$outputWikiDir"/tiddlers/'$__SiteTitle.tid'
writeSimpleTiddler '$:/SiteSubtitle' "Daily updates from the TW community!" >"$outputWikiDir"/tiddlers/'$__SiteSubtitle.tid'
writeSimpleTiddler '$:/DefaultTiddlers' "CommunityNews" >"$outputWikiDir"/tiddlers/'$__DefaultTiddlers.tid'

echo "$progName: converting to static"
tiddlywiki "$outputWikiDir" --rendertiddlers '[!is[system]]' '$:/core/templates/static.tiddler.html' static text/plain >/dev/null
tiddlywiki "$outputWikiDir" --rendertiddler '$:/core/templates/static.template.html' static.html text/plain >/dev/null
tiddlywiki "$outputWikiDir" --rendertiddler '$:/core/templates/static.template.css' static/static.css text/plain >/dev/null
echo "$progName: done."
