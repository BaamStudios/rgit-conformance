#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t7702-repack-cyclic-alternate.sh
# (https://github.com/git/git/blob/v2.56.1/t/t7702-repack-cyclic-alternate.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2014 Ephrim Khong
#

test_description='repack involving cyclic alternate'

. ./test-lib.sh

test_expect_success setup '
	GIT_OBJECT_DIRECTORY=.git//../.git/objects &&
	export GIT_OBJECT_DIRECTORY &&
	touch a &&
	git add a &&
	git commit -m 1 &&
	git repack -adl &&
	echo "$(pwd)"/.git/objects/../objects >.git/objects/info/alternates
'

test_expect_success 're-packing repository with itself as alternate' '
	git repack -adl &&
	git fsck
'

test_done
