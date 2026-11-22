#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t5405-send-pack-rewind.sh
# (https://github.com/git/git/blob/v2.56.1/t/t5405-send-pack-rewind.sh). GPL-2.0, see LICENSE.

test_description='forced push to replace commit we do not have'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '

	>file1 && git add file1 && test_tick &&
	git commit -m Initial &&
	git config receive.denyCurrentBranch warn &&

	mkdir another && (
		cd another &&
		git init &&
		git fetch --update-head-ok .. main:main
	) &&

	>file2 && git add file2 && test_tick &&
	git commit -m Second

'

test_expect_success 'non forced push should die not segfault' '

	(
		cd another &&
		test_must_fail git push .. main:main
	)

'

test_expect_success 'forced push should succeed' '

	(
		cd another &&
		git push .. +main:main
	)

'

test_done
