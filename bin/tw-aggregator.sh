



#
# arguments of the form "field: value"
#
function writeTiddlerHeader {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
    while [ $# -gt 0 ]; do
	echo "$1"
	shift
    done
    echo
}









total=0
## iterate the referenced wikis to add their content to the target wiki
##
for siteNo in $(seq 1 $nbSites); do


	echo "processing '$name': creating presentation tiddler"
	writeTiddlerHeader "title: $name" "tags: community-wiki" "wiki-address: $address" "type: text/vnd.tiddlywiki" >"$id/tiddlers/$name.tid"
	if [ ! -z "$presentationTiddler" ]; then
	    file="$name/tiddlers/$presentationTiddler.tid"
	    if [ -f "$file" ]; then
		firstBlankNo=$(cat "$file" | grep -n "^$" | head -n 1 | cut -f 1 -d ":")
		tail -n +$firstBlankNo "$file" >> "$id/tiddlers/$name.tid"
	    else
		echo "Warning: presentation tiddler '$file' (title '$presentationTiddler') does not exist" 1>&2
	    fi
	    
	fi
	echo -e "\n\n{{||\$:/CommunityWikiPresentationTemplate}}"  >> "$id/tiddlers/$name.tid"

	rm -rf "$name"
    fi
done
