#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4110-apply-scan.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4110-apply-scan.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2005 Junio C Hamano
# Copyright (c) 2005 Robert Fitzsimons
#

test_description='git apply test for patches which require scanning forwards and backwards.

'

. ./test-lib.sh

test_expect_success 'git apply scan' '
	git apply \
		"$TEST_DIRECTORY/t4110/patch1.patch" \
		"$TEST_DIRECTORY/t4110/patch2.patch" \
		"$TEST_DIRECTORY/t4110/patch3.patch" \
		"$TEST_DIRECTORY/t4110/patch4.patch" \
		"$TEST_DIRECTORY/t4110/patch5.patch" &&
	test_cmp new.txt "$TEST_DIRECTORY/t4110/expect"
'

test_done
