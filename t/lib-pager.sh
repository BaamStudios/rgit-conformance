# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-pager.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-pager.sh). GPL-2.0, see LICENSE.
# Helpers for tests of git's choice of pager.

test_expect_success 'determine default pager' '
	test_might_fail git config --unset core.pager &&
	less=$(
		sane_unset PAGER GIT_PAGER &&
		git var GIT_PAGER
	) &&
	test -n "$less"
'

if expr "$less" : '[a-z][a-z]*$' >/dev/null
then
	test_set_prereq SIMPLEPAGER
fi
