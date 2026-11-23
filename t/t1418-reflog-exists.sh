#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1418-reflog-exists.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1418-reflog-exists.sh). GPL-2.0, see LICENSE.

test_description='Test reflog display routines'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit A
'

test_expect_success 'usage' '
	test_expect_code 129 git reflog exists &&
	git reflog exists -h
'

test_expect_success 'usage: unknown option' '
	test_expect_code 129 git reflog exists --unknown-option
'

test_expect_success 'reflog exists works' '
	git reflog exists refs/heads/main &&
	test_must_fail git reflog exists refs/heads/nonexistent
'

test_expect_success 'reflog exists works with a "--" delimiter' '
	git reflog exists -- refs/heads/main &&
	test_must_fail git reflog exists -- refs/heads/nonexistent
'

test_expect_success 'reflog exists works with a "--end-of-options" delimiter' '
	git reflog exists --end-of-options refs/heads/main &&
	test_must_fail git reflog exists --end-of-options refs/heads/nonexistent
'

test_done
