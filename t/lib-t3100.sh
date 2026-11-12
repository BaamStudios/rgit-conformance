#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-t3100.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-t3100.sh). GPL-2.0, see LICENSE.

setup_basic_ls_tree_data () {
	mkdir dir &&
	test_commit dir/sub-file &&
	test_commit top-file &&
	git clone . submodule &&
	git submodule add ./submodule &&
	git commit -m"add submodule"
}
