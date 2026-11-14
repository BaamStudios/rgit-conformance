#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t0022-crlf-rename.sh
# (https://github.com/git/git/blob/v2.56.1/t/t0022-crlf-rename.sh). GPL-2.0, see LICENSE.

test_description='ignore CR in CRLF sequence while computing similarity'

. ./test-lib.sh

test_expect_success setup '

	cat "$TEST_DIRECTORY"/t0022-crlf-rename.sh >sample &&
	git add sample &&

	test_tick &&
	git commit -m Initial &&

	append_cr <"$TEST_DIRECTORY"/t0022-crlf-rename.sh >elpmas &&
	git add elpmas &&
	rm -f sample &&

	test_tick &&
	git commit -a -m Second

'

test_expect_success 'diff -M' '

	git diff-tree -M -r --name-status HEAD^ HEAD >tmp &&
	sed -e "s/R[0-9]*/RNUM/" tmp >actual &&
	echo "RNUM	sample	elpmas" >expect &&
	test_cmp expect actual

'

test_done
