#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1461-refs-list.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1461-refs-list.sh). GPL-2.0, see LICENSE.

test_description='git refs list tests'

. ./test-lib.sh

git_for_each_ref='git refs list'
. "$TEST_DIRECTORY"/for-each-ref-tests.sh
