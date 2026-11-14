#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4050-diff-histogram.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4050-diff-histogram.sh). GPL-2.0, see LICENSE.

test_description='histogram diff algorithm'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff-alternative.sh

test_diff_frobnitz "histogram"

test_diff_unique "histogram"

test_done
