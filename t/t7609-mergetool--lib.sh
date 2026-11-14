#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t7609-mergetool--lib.sh
# (https://github.com/git/git/blob/v2.56.1/t/t7609-mergetool--lib.sh). GPL-2.0, see LICENSE.

test_description='git mergetool

Testing basic merge tools options'

. ./test-lib.sh

test_expect_success 'mergetool --tool=vimdiff creates the expected layout' '
	. "$GIT_SOURCE_DIR"/mergetools/vimdiff &&
	run_unit_tests
'

test_done
