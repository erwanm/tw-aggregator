tw-aggregator
=============

The project implements the scraping of a list of TiddlyWiki wikis, from which a "community search engine" is generated. It is actually a static wiki containing all the content, which can then be searched using TW search function and points to the original wikis instead of the local tiddlers.

Other applications of TW scraping might be considered in the future.

The generated wiki can be accessed directly at:
http://erwanm.github.io/tw-community-search/

Setup
-----

The offline process is done by a few Bash scripts located in the bin/ directory.
It should work from any Linux environment. The directory bin/ should be added to the $PATH environment variable.

See more details in the documentation provided in the wiki.
