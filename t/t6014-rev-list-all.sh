#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t6014-rev-list-all.sh
# (https://github.com/git/git/blob/v2.56.1/t/t6014-rev-list-all.sh). GPL-2.0, see LICENSE.

test_description='--all includes detached HEADs'

. ./test-lib.sh


commit () {
	test_tick &&
	echo $1 > foo &&
	git add foo &&
	git commit -m "$1"
}

test_expect_success 'setup' '

	commit one &&
	commit two &&
	git checkout HEAD^ &&
	commit detached

'

test_expect_success 'rev-list --all lists detached HEAD' '

	test 3 = $(git rev-list --all | wc -l)

'

test_expect_success 'repack does not lose detached HEAD' '

	git gc &&
	git prune --expire=now &&
	git show HEAD

'

test_expect_success 'rev-list --graph --no-walk is forbidden' '
	test_must_fail git rev-list --graph --no-walk HEAD
'

test_done
