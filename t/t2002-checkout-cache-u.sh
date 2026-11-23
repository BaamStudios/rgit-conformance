#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t2002-checkout-cache-u.sh
# (https://github.com/git/git/blob/v2.56.1/t/t2002-checkout-cache-u.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='git checkout-index -u test.

With -u flag, git checkout-index internally runs the equivalent of
git update-index --refresh on the checked out entry.'

. ./test-lib.sh

test_expect_success \
'preparation' '
echo frotz >path0 &&
git update-index --add path0 &&
t=$(git write-tree)'

test_expect_success \
'without -u, git checkout-index smudges stat information.' '
rm -f path0 &&
git read-tree $t &&
git checkout-index -f -a &&
test_must_fail git diff-files --exit-code'

test_expect_success \
'with -u, git checkout-index picks up stat information from new files.' '
rm -f path0 &&
git read-tree $t &&
git checkout-index -u -f -a &&
git diff-files --exit-code'

test_done
