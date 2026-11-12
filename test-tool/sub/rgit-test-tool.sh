#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Substitute for the test-tool subcommands that rgit's own helper binary
# `rgit-test-tool` answers (rgit issue #192, crate crates/rgit-test-tool).
# The files sub/<subcommand> are symbolic links to this script; the
# subcommand is the name it was called by.
#
# rgit-test-tool is found as
#   1. $RGIT_TEST_TOOL,
#   2. rgit-test-tool next to $RGIT (when RGIT names a path),
#   3. rgit-test-tool on PATH.
# Without one the call goes to the reference test-tool (or fails with 127
# under RGIT_TEST_TOOL_STRICT=1), like the other substitutes.

sub=${0##*/}

find_rgit_test_tool () {
	if test -n "$RGIT_TEST_TOOL"
	then
		echo "$RGIT_TEST_TOOL"
		return
	fi
	case ${RGIT:-} in
	*/*)
		if test -x "${RGIT%/*}/rgit-test-tool"
		then
			echo "${RGIT%/*}/rgit-test-tool"
			return
		fi
		;;
	esac
	command -v rgit-test-tool
}

tool=$(find_rgit_test_tool)
if test -n "$tool" && test -x "$tool"
then
	exec "$tool" "$sub" "$@"
fi

if test "$RGIT_TEST_TOOL_STRICT" = 1
then
	echo "test-tool (rgit): rgit-test-tool not found for $sub; set RGIT_TEST_TOOL" >&2
	exit 127
fi
if test -n "$RGIT_TEST_TOOL_FORWARD_LOG"
then
	echo "$sub ${1:-}" >>"$RGIT_TEST_TOOL_FORWARD_LOG"
fi
exec "${REF_TEST_TOOL:?REF_TEST_TOOL not set}" "$sub" "$@"
