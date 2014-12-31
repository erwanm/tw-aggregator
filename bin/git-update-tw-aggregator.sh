#!/bin/bash

# requires a properly configured git repo bith local and remote (e.g. github)
# the basic repo with the wiki must already exist in the repo

# must be run from the project dir


# just in case, but things will go wrong if merging is needed
git pull
# run the aggregator
tw-community-search.sh tw-sites-list.txt
git commit -m "automatic update" tw-community-search.html
git push

