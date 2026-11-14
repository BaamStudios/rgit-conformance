#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4071-diff-minimal.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4071-diff-minimal.sh). GPL-2.0, see LICENSE.

test_description='minimal diff algorithm'

. ./test-lib.sh

test_expect_success 'minimal diff should not mark changes between changed lines' '
	test_write_lines x x x x >pre &&
	test_write_lines x x x A B C D x E F G >post &&
	test_expect_code 1 git diff --no-index --minimal pre post >diff &&
	test_grep ! ^[+-]x diff 
'

test_done
