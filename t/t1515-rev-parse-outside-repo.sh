#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1515-rev-parse-outside-repo.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1515-rev-parse-outside-repo.sh). GPL-2.0, see LICENSE.

test_description='check that certain rev-parse options work outside repo'

. ./test-lib.sh

test_expect_success 'set up non-repo directory' '
	GIT_CEILING_DIRECTORIES=$(pwd) &&
	export GIT_CEILING_DIRECTORIES &&
	mkdir non-repo &&
	cd non-repo &&
	# confirm that git does not find a repo
	test_must_fail git rev-parse --git-dir
'

# Rather than directly test the output of sq-quote directly,
# make sure the shell can read back a tricky case, since
# that's what we really care about anyway.
tricky="really tricky with \\ and \" and '"
dump_args () {
	for i in "$@"; do
		echo "arg: $i"
	done
}
test_expect_success 'rev-parse --sq-quote' '
	dump_args "$tricky" easy >expect &&
	eval "dump_args $(git rev-parse --sq-quote "$tricky" easy)" >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --local-env-vars' '
	git rev-parse --local-env-vars >actual &&
	# we do not want to depend on the complete list here,
	# so just look for something plausible
	test_grep ^GIT_DIR actual
'

test_expect_success 'rev-parse --resolve-git-dir' '
	git init --separate-git-dir repo dir &&
	test_must_fail git rev-parse --resolve-git-dir . &&
	echo "$(pwd)/repo" >expect &&
	git rev-parse --resolve-git-dir dir/.git >actual &&
	test_cmp expect actual
'

test_done
