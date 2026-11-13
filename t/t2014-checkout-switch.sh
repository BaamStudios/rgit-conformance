#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t2014-checkout-switch.sh
# (https://github.com/git/git/blob/v2.56.1/t/t2014-checkout-switch.sh). GPL-2.0, see LICENSE.

test_description='Peter MacMillan'

. ./test-lib.sh

test_expect_success setup '
	echo Hello >file &&
	git add file &&
	test_tick &&
	git commit -m V1 &&
	echo Hello world >file &&
	git add file &&
	git checkout -b other
'

test_expect_success 'check all changes are staged' '
	git diff --exit-code
'

test_expect_success 'second commit' '
	git commit -m V2
'

test_expect_success 'check' '
	git diff --cached --exit-code
'

test_done
