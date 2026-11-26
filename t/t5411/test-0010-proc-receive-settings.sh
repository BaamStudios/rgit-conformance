# rgit-conformance: copied unchanged from git v2.56.1, path t/t5411/test-0010-proc-receive-settings.sh
# (https://github.com/git/git/blob/v2.56.1/t/t5411/test-0010-proc-receive-settings.sh). GPL-2.0, see LICENSE.
test_expect_success "add two receive.procReceiveRefs settings" '
	(
		cd "$upstream" &&
		git config --add receive.procReceiveRefs refs/for &&
		git config --add receive.procReceiveRefs refs/review/
	)
'
