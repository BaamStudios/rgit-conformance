#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t2009-checkout-statinfo.sh
# (https://github.com/git/git/blob/v2.56.1/t/t2009-checkout-statinfo.sh). GPL-2.0, see LICENSE.

test_description='checkout should leave clean stat info'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '

	echo hello >world &&
	git update-index --add world &&
	git commit -m initial &&
	git branch side &&
	echo goodbye >world &&
	git update-index --add world &&
	git commit -m second

'

test_expect_success 'branch switching' '

	git reset --hard &&
	test "$(git diff-files --raw)" = "" &&

	git checkout main &&
	test "$(git diff-files --raw)" = "" &&

	git checkout side &&
	test "$(git diff-files --raw)" = "" &&

	git checkout main &&
	test "$(git diff-files --raw)" = ""

'

test_expect_success 'path checkout' '

	git reset --hard &&
	test "$(git diff-files --raw)" = "" &&

	git checkout main world &&
	test "$(git diff-files --raw)" = "" &&

	git checkout side world &&
	test "$(git diff-files --raw)" = "" &&

	git checkout main world &&
	test "$(git diff-files --raw)" = ""

'

test_done

