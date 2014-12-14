#!/bin/bash

# requires a properly configured git repo bith local and remote (e.g. github)
# the basic repo with the wiki must already exist in the repo

# must be run from the project dir

wiki="tw-aggregator"

# just in case, but things will go wrong if merging is needed
git pull
# run the aggregator
bin/tw-aggregator.sh tw-sites-list.txt
# add/delete any new tiddler
git add -u "$wiki"/tiddlers/*/tiddlers/
# commit and push
git commit -a -m "automatic update"
git push

