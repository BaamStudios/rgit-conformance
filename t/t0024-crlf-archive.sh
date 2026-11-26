#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t0024-crlf-archive.sh
# (https://github.com/git/git/blob/v2.56.1/t/t0024-crlf-archive.sh). GPL-2.0, see LICENSE.

test_description='respect crlf in git archive'

. ./test-lib.sh

test_expect_success setup '

	git config core.autocrlf true &&

	printf "CRLF line ending\r\nAnd another\r\n" >sample &&
	git add sample &&

	test_tick &&
	git commit -m Initial

'

test_expect_success 'tar archive' '

	git archive --format=tar HEAD >test.tar &&
	mkdir untarred &&
	"$TAR" xf test.tar -C untarred &&

	test_cmp sample untarred/sample

'

test_expect_success UNZIP 'zip archive' '

	git archive --format=zip HEAD >test.zip &&

	mkdir unzipped &&
	(
		cd unzipped &&
		"$GIT_UNZIP" ../test.zip
	) &&

	test_cmp sample unzipped/sample

'

test_done
