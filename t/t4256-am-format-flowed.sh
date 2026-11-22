#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4256-am-format-flowed.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4256-am-format-flowed.sh). GPL-2.0, see LICENSE.

test_description='test format=flowed support of git am'

. ./test-lib.sh

test_expect_success 'setup' '
	cp "$TEST_DIRECTORY/t4256/1/mailinfo.c.orig" mailinfo.c &&
	git add mailinfo.c &&
	git commit -m initial
'

test_expect_success 'am with format=flowed' '
	git am <"$TEST_DIRECTORY/t4256/1/patch" 2>stderr &&
	test_grep "warning: Patch sent with format=flowed" stderr &&
	test_cmp "$TEST_DIRECTORY/t4256/1/mailinfo.c" mailinfo.c
'

test_done
