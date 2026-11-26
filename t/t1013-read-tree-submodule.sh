#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t1013-read-tree-submodule.sh
# (https://github.com/git/git/blob/v2.56.1/t/t1013-read-tree-submodule.sh). GPL-2.0, see LICENSE.

test_description='read-tree can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS=1

test_submodule_switch_recursing_with_args "read-tree -u -m"

test_submodule_forced_switch_recursing_with_args "read-tree -u --reset"

test_submodule_switch "read-tree -u -m"

test_submodule_forced_switch "read-tree -u --reset"

test_done
