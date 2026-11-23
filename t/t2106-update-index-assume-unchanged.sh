#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t2106-update-index-assume-unchanged.sh
# (https://github.com/git/git/blob/v2.56.1/t/t2106-update-index-assume-unchanged.sh). GPL-2.0, see LICENSE.

test_description='git update-index --assume-unchanged test.
'

. ./test-lib.sh

test_expect_success 'setup' '
	: >file &&
	git add file &&
	git commit -m initial &&
	git branch other &&
	echo upstream >file &&
	git add file &&
	git commit -m upstream
'

test_expect_success 'do not switch branches with dirty file' '
	git reset --hard &&
	git checkout other &&
	echo dirt >file &&
	git update-index --assume-unchanged file &&
	test_must_fail git checkout - 2>err &&
	test_grep overwritten err
'

test_done
