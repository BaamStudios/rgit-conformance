#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t5732-protocol-v2-bundle-uri-http.sh
# (https://github.com/git/git/blob/v2.56.1/t/t5732-protocol-v2-bundle-uri-http.sh). GPL-2.0, see LICENSE.

test_description="Test bundle-uri with protocol v2 and 'http://' transport"

TEST_NO_CREATE_REPO=1

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Test protocol v2 with 'http://' transport
#
BUNDLE_URI_PROTOCOL=http
. "$TEST_DIRECTORY"/lib-bundle-uri-protocol.sh

test_done
