#!/bin/bash

# requires a properly configured git repo bith local and remote (e.g. github)
# the basic repo with the wiki must already exist in the repo

# must be run from the project dir

wiki="tw-aggregator"

# run the aggregator
bin/tw-aggregator.sh tw-sites-list.txt
# add any new tiddler
git add "$wiki"/tiddlers/*/tiddlers/*.tid
# commit and push
git commit -m "automatic update"
git push

