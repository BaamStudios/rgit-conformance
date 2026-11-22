#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t7414-submodule-mistakes.sh
# (https://github.com/git/git/blob/v2.56.1/t/t7414-submodule-mistakes.sh). GPL-2.0, see LICENSE.

test_description='handling of common mistakes people may make with submodules'

. ./test-lib.sh

test_expect_success 'create embedded repository' '
	git init embed &&
	test_commit -C embed one
'

test_expect_success 'git-add on embedded repository warns' '
	test_when_finished "git rm --cached -f embed" &&
	git add embed 2>stderr &&
	test_grep warning stderr
'

test_expect_success '--no-warn-embedded-repo suppresses warning' '
	test_when_finished "git rm --cached -f embed" &&
	git add --no-warn-embedded-repo embed 2>stderr &&
	test_grep ! warning stderr
'

test_expect_success 'no warning when updating entry' '
	test_when_finished "git rm --cached -f embed" &&
	git add embed &&
	git -C embed commit --allow-empty -m two &&
	git add embed 2>stderr &&
	test_grep ! warning stderr
'

test_expect_success 'submodule add does not warn' '
	test_when_finished "git rm -rf submodule .gitmodules" &&
	git -c protocol.file.allow=always \
		submodule add ./embed submodule 2>stderr &&
	test_grep ! warning stderr
'

test_done
