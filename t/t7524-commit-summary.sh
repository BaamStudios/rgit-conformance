#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t7524-commit-summary.sh
# (https://github.com/git/git/blob/v2.56.1/t/t7524-commit-summary.sh). GPL-2.0, see LICENSE.

test_description='git commit summary'

. ./test-lib.sh

test_expect_success 'setup' '
	test_seq 101 200 >file &&
	git add file &&
	git commit -m initial &&
	git tag initial
'

test_expect_success 'commit summary ignores rewrites' '
	git reset --hard initial &&
	test_seq 200 300 >file &&

	git diff --stat >diffstat &&
	git diff --stat --break-rewrites >diffstatrewrite &&

	# make sure this scenario is a detectable rewrite
	! test_cmp_bin diffstat diffstatrewrite &&

	git add file &&
	git commit -m second >actual &&

	grep "1 file" <actual >actual.total &&
	grep "1 file" <diffstat >diffstat.total &&
	test_cmp diffstat.total actual.total
'

test_done
