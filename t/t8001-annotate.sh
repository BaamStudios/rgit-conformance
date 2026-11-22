#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t8001-annotate.sh
# (https://github.com/git/git/blob/v2.56.1/t/t8001-annotate.sh). GPL-2.0, see LICENSE.

test_description='git annotate'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

if ! test_have_prereq PERL_TEST_HELPERS
then
	skip_all='skipping annotate tests; Perl not available'
	test_done
fi

PROG='git annotate'
. "$TEST_DIRECTORY"/annotate-tests.sh

test_expect_success 'annotate old revision' '
	git annotate file main >actual &&
	awk "{ print \$3; }" <actual >authors &&
	test 2 = $(grep A <authors | wc -l) &&
	test 2 = $(grep B <authors | wc -l)
'

test_done
