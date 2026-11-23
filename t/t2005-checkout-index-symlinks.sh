#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t2005-checkout-index-symlinks.sh
# (https://github.com/git/git/blob/v2.56.1/t/t2005-checkout-index-symlinks.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2007 Johannes Sixt
#

test_description='git checkout-index on filesystem w/o symlinks test.

This tests that git checkout-index creates a symbolic link as a plain
file if core.symlinks is false.'

. ./test-lib.sh

test_expect_success \
'preparation' '
git config core.symlinks false &&
l=$(printf file | git hash-object -t blob -w --stdin) &&
echo "120000 $l	symlink" | git update-index --index-info'

test_expect_success \
'the checked-out symlink must be a file' '
git checkout-index symlink &&
test -f symlink'

test_expect_success 'the file must be the blob we added during the setup' '
	echo "$l" >expect &&
	git hash-object -t blob symlink >actual &&
	test_cmp expect actual
'

test_done
