#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t3409-rebase-environ.sh
# (https://github.com/git/git/blob/v2.56.1/t/t3409-rebase-environ.sh). GPL-2.0, see LICENSE.

test_description='git rebase interactive environment'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit one &&
	test_commit two &&
	test_commit three
'

test_expect_success 'rebase --exec does not muck with GIT_DIR' '
	git rebase --exec "printf %s \$GIT_DIR >environ" HEAD~1 &&
	test_must_be_empty environ
'

test_expect_success 'rebase --exec does not muck with GIT_WORK_TREE' '
	git rebase --exec "printf %s \$GIT_WORK_TREE >environ" HEAD~1 &&
	test_must_be_empty environ
'

test_done
