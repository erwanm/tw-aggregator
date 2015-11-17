
#
# EM Aug 15
# library of functions for manipulating tiddlers as text files
#

#
# returns the absolute path of a file or directory
#
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


# args: 
# STDIN = 
# $1 = <searched item>
# $2 = <list of items separatated by space (default)>
# $3 = [separator] if the separator is different from space
#
# returns 0 if true, 1 otherwise.
#
function memberList {
    item="$1"
    list="$2"
    sep="$3"
    if [ ! -z "$sep" ]; then
	list=$(echo "$list" | sed "s/$sep/ /g")
    fi
#    echo "memberList: searching '$item' in '$list'" 1>&2
    set -- $list
    while [ ! -z "$1" ]; do
#	echo "memberList: '$item' == '$1' ?" 1>&2
	if [ "$item" == "$1" ]; then
#	echo "memberList: '$item' found, returning 0" 1>&2
	    return 0
	fi
	shift
    done
#    echo "memberList: end of list, returning 1" 1>&2
    return 1
}



#
# Returns the line number of the first blank line (i.e. end of header, beginning of content)
#
function getFirstBlankLineNo {
    local tiddlerFile="$1"
    cat "$tiddlerFile" | grep -n "^$" | head -n 1 | cut -f 1 -d ":"
}


#
# Extracts the value of a given field (if it exists, returns empty string otherwise)
# firstBlankLineNo is optional (faster if provided)
#
function extractField {
    local fieldName="$1"
    local tiddlerFile="$2"
    local firstBlankLineNo="$3"

    if [ -z "$firstBlankLineNo" ]; then
	firstBlankLineNo=$(getFirstBlankLineNo "$tiddlerFile")
    fi
    val=$(head -n $(( $firstBlankLineNo - 1 )) "$tiddlerFile" | grep "^$fieldName: " | tail -n 1)
    echo ${val#$fieldName: }
}


#
#
# 1) Returns the value of the field 'plugin-type' if it exists (it should be either 'plugin', 'theme', or 'language');
# 2) If there is no 'plugin-type' field, returns the first part of the value of the field 'type': 'text', 'application', or 'image';
# 3) If there is no 'type' field, returns the default type 'text'.
#
# (See http://tiddlywiki.com/#PluginMechanism and  http://tiddlywiki.com/#ContentType)
#
# firstBlankLineNo is optional (faster if provided)
#
# Remark: "regular tiddlers" are of type 'text', but they can be system/shadow tiddlers as well.
#
function getTiddlerType {
    local tiddlerFile="$1"
    local firstBlankLineNo="$2"

    pluginField=$(extractField "plugin-type" "$tiddlerFile" "$firstBlankLineNo")
    if [ ! -z "$pluginField" ]; then
	echo "$pluginField"
    else
	typeField=$(extractField "type" "$tiddlerFile" "$firstBlankLineNo")
	if [ ! -z "$typeField" ]; then
	    echo ${typeField%%/*}
	else
	    echo "text"
	fi
    fi
}


#
# Returns true if the tiddler file name corresponds to a system tiddler, i.e. starts with '$__'.
# Can be used in 'if' statement: "if [!] isSystemTiddlerFile <file>; then ..."
#
function isSystemTiddlerFile {
    local tiddlerFile=$(basename "$1")
#    echo "DEBUG: '$tiddlerFile'" 1>&2
    if [ "${tiddlerFile:0:3}" == '$__' ]; then
	return 0
    else
	return 1
    fi
}


#
# Writes "created: <current date>" to STDOUT
#
function writeCreatedTodayField {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
}


#
# Writes a 'tags' field to STDOUT with content <tags> and each tag in <filteredTags> which
# is not a system tag (starting with $:/) or a variable (between '$( )$').
# Additionally every tag in <filteredTags> which passes the filter is appended to <tagsListFile>
#
# <tags> and <filteredTags> are optional (i.e. you can use or the other, or both).
#
function writeTagsIfNotSystem {
    local tagsListFile="$1"
    local tags="$2"
    local filteredTags="$3"

    echo -n "tags: $tags"
    set -- $filteredTags
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
		echo "${tag:2}" | sed 's/\]\]//' >>"$tagsListFile"
	    fi
	else
#	    if [  "${tag:0:2}" == '$(' ] || [  "${tag:(-2)}" == ')$' ]; then
#		echo "DEBUG found varialbe in tags: '$tag'" 1>&2
#	    fi
	    if [[ ! $tag =~ $regex ]] && [  "${tag:0:2}" != '$(' ] && [  "${tag:(-2)}" != ')$' ]; then # keep it if not a system tag, otherwise ignore it # added bug fix #8: ignore also if variable
		echo -n " $tag"
		echo "$tag" >>"$tagsListFile"
	    fi
	fi
	shift
    done
    echo
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
# prints a tiddler fields to STDOUT, with possible exceptions.
# remark: if title is not excluded, it is copied as well (in this case the target tiddler 
#         filename should be identical to the source tiddler)
#
# firstBlankLineNo is optional
#
function printTiddlerFields {
    local sourceTiddlerFile="$1"
    local excludeFields="$2"
    local firstBlankLineNo="$3"

    if [ -z "$firstBlankLineNo" ]; then
	firstBlankLineNo=$(getFirstBlankLineNo "$sourceTiddlerFile")
    fi
    command=" cat "
    for field in $excludeFields; do
	command="$command | grep -v '^$field: ' "
    done
    head -n $(( $firstBlankLineNo - 1 )) "$sourceTiddlerFile" | eval "$command"
}


#
# Generates a "TWCS tiddler" from a source tiddler, i.e. a system tiddler:
#   - with <wikiId> as prefix as its title
#   - with all the source fields, except for 'title' and 'tags':
#     - 'title' is modified (see above)
#     - 'tags' are copied except system tags and variables, and the wikiId is added as tag.
#   -  with additional fields:
#     - source-wiki-id
#     - source-tiddler-title-as-text (user-friendly version)
#     - source-tiddler-title-as-link (link version, with special characters converted)
#
# Prints the name of the target tiddler to STDOUT.
#
# The text content is copied only if <copyTextContent> is set to 1. If it's not, no blank
# line is printed so that fields can be added later.
#
# <excludeFields> is optional; if defined, the list of fields it contains are not copied.
# <tagsListFile> is optional; if defined, regular tags are appended to this file.
#
function cloneAsTWCSTiddler {
    local sourceTiddlerFile="$1"
    local targetTiddlerDir="$2"
    local firstBlankLineNo="$3"
    local wikiId="$4"
    local copyTextContent="$5"
    local excludeFields="$6"
    local tagsListFile="$7"
    local additionalTags="$8"

    if [ -z "$tagsListFile" ]; then
	tagsListFile="/dev/null"
    fi
    basef=$(basename "$sourceTiddlerFile")
    targetTiddler="$targetTiddlerDir/\$__${wikiId}_$basef"
    oldTitle=$(extractField "title" "$sourceTiddlerFile" "$firstBlankLineNo")
    newTitle="\$:/$wikiId/$oldTitle" # convert title to system tiddler with wiki id prefix
    echo "title: $newTitle" >"$targetTiddler"
    printTiddlerFields "$sourceTiddlerFile" "title tags $excludeFields" "$firstBlankLineNo" >>"$targetTiddler"
    oldTags=$(extractField "tags" "$sourceTiddlerFile" "$firstBlankLineNo")
    writeTagsIfNotSystem "$tagsListFile" "[[$wikiId]] $additionalTags" "$oldTags" >>"$targetTiddler"
    echo "source-wiki-id: $wikiId" >>"$targetTiddler" # store custom fields in order to recompute the original address
    # url-encode the title, in case it contains characters like # (see github bug #24)
    # also keep the non-encoded title (named source-tiddler-title-as-text), to display it in a user-friendly readable text
    # without the prefix '$:/<wiki name>/' (maybe possible to user remove-suffix instead ?? regexp ?)
    echo "source-tiddler-title-as-text: $oldTitle" >>"$targetTiddler"   
    echo -n "source-tiddler-title-as-link: " >>"$targetTiddler"
    rawurlencode "$oldTitle" >>"$targetTiddler"  # new version with url-encoding
    if [ "$copyTextContent" == "1" ]; then
	tail -n +$firstBlankLineNo "$sourceTiddlerFile" >>"$targetTiddler"
    fi
    echo "$targetTiddler"
}


#
# as the name sugests. reads from STDIN, writes to STDOUT
#
function removeTrailingSlash {
    while read x; do echo "${x%/}"; done
}


#
# prints the filename corresponding to the tiddler <title> in <wikiDir>/tiddlers
#
# TODO check special chars replaced with '_' before using grep
#
function printTiddlerFileFromTitle {
    local wikiDir="$1"
    local title="$2"

    if [ -f "$wikiDir/tiddlers/$title.tid" ]; then
	echo "$wikiDir/tiddlers/$title.tid"
    else 
	f=$(grep "^title: $title$" "$wikiDir"/tiddlers/*.tid | cut -d ":" -f 1) # assuming only one possibility!
	if [ -z "$f" ]; then
	    echo "Warning: no tiddler titled '$title' found in wiki '$name'" 1>&2
	else
	    echo "$f"
	fi
    fi
}


function writeSimpleTiddler {
    local title="$1"
    local text="$2"

    writeCreatedTodayField
    echo "title: $title"
    echo
    echo "$text"
}

