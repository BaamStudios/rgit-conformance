#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t5518-fetch-exit-status.sh
# (https://github.com/git/git/blob/v2.56.1/t/t5518-fetch-exit-status.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2008 Dmitry V. Levin
#

test_description='fetch exit status test'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '

	>file &&
	git add file &&
	git commit -m initial &&

	git checkout -b side &&
	echo side >file &&
	git commit -a -m side &&

	git checkout main &&
	echo next >file &&
	git commit -a -m next
'

test_expect_success 'non-fast-forward fetch' '

	test_must_fail git fetch . main:side

'

test_expect_success 'forced update' '

	git fetch . +main:side

'

test_done
