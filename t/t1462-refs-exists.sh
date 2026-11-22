#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1462-refs-exists.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1462-refs-exists.sh). GPL-2.0, see LICENSE.

test_description='refs exists'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

git_show_ref_exists='git refs exists'
. "$TEST_DIRECTORY"/show-ref-exists-tests.sh
