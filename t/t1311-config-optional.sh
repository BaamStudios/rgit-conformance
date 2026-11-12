#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1311-config-optional.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1311-config-optional.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2025 Google LLC
#

test_description=':(optional) paths'

. ./test-lib.sh

test_expect_success 'var=:(optional)path-exists' '
	test_config a.path ":(optional)path-exists" &&
	>path-exists &&
	echo path-exists >expect &&

	git config get --path a.path >actual &&
	test_cmp expect actual
'

test_expect_success 'missing optional value is ignored' '
	test_config a.path ":(optional)no-such-path" &&
	# Using --show-scope ensures we skip writing not only the value
	# but also any meta-information about the ignored key.
	test_must_fail git config get --show-scope --path a.path >actual &&
	test_line_count = 0 actual
'

test_expect_success 'missing optional value is ignored in multi-value config' '
	test_when_finished "git config unset --all a.path" &&
	git config set --append a.path ":(optional)path-exists" &&
	git config set --append a.path ":(optional)no-such-path" &&
	>path-exists &&
	echo path-exists >expect &&

	git config --get --path a.path >actual &&
	test_cmp expect actual
'

test_done
