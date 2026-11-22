#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t0601-reffiles-pack-refs.sh
# (https://github.com/git/git/blob/v2.56.1/t/t0601-reffiles-pack-refs.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2005 Amos Waterland
# Copyright (c) 2006 Christian Couder
#

test_description='git pack-refs should not change the branch semantic

This test runs git pack-refs and git show-ref and checks that the branch
semantic is still the same.
'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME
GIT_TEST_DEFAULT_REF_FORMAT=files
export GIT_TEST_DEFAULT_REF_FORMAT

. ./test-lib.sh

. "$TEST_DIRECTORY"/pack-refs-tests.sh

test_done
