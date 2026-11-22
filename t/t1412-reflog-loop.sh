#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1412-reflog-loop.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1412-reflog-loop.sh). GPL-2.0, see LICENSE.

test_description='reflog walk shows repeated commits again'

. ./test-lib.sh

test_expect_success 'setup commits' '
	test_commit one file content &&
	test_commit --append two file content
'

test_expect_success 'setup reflog with alternating commits' '
	git checkout -b topic &&
	git reset one &&
	git reset two &&
	git reset one &&
	git reset two
'

test_expect_success 'reflog shows all entries' '
	cat >expect <<-\EOF &&
		topic@{0} reset: moving to two
		topic@{1} reset: moving to one
		topic@{2} reset: moving to two
		topic@{3} reset: moving to one
		topic@{4} branch: Created from HEAD
	EOF
	git log -g --format="%gd %gs" topic >actual &&
	test_cmp expect actual
'

test_done
