#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t3908-stash-in-worktree.sh
# (https://github.com/git/git/blob/v2.56.1/t/t3908-stash-in-worktree.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2019 Johannes E Schindelin
#

test_description='Test git stash in a worktree'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial &&
	git worktree add wt &&
	test_commit -C wt in-worktree
'

test_expect_success 'apply in subdirectory' '
	mkdir wt/subdir &&
	(
		cd wt/subdir &&
		echo modified >../initial.t &&
		git stash &&
		git stash apply >out
	) &&
	test_grep "\.\.\/initial\.t" wt/subdir/out
'

test_done
