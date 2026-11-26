#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t3450-history.sh
# (https://github.com/git/git/blob/v2.56.1/t/t3450-history.sh). GPL-2.0, see LICENSE.

test_description='tests for git-history command'

. ./test-lib.sh

test_expect_success 'does nothing without any arguments' '
	test_must_fail git history 2>err &&
	test_grep "need a subcommand" err
'

test_expect_success 'raises an error with unknown argument' '
	test_must_fail git history garbage 2>err &&
	test_grep "unknown subcommand: .garbage." err
'

test_done
