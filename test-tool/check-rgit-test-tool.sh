#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Runs the upstream scripts that use the subcommands answered by
# rgit-test-tool (rgit issue #192) with the reference git, but with the
# dispatcher installed as `test-tool`, so every call of those subcommands
# goes to rgit-test-tool. The scripts must pass as they do with the
# reference test-tool.
#
#   test-tool/check-rgit-test-tool.sh REF_BUILD RGIT_TEST_TOOL [SCRIPT...]
#
# REF_BUILD is a built git tree (git and t/helper/test-tool), for example
# ~/.cache/rgit-conformance/git-v2.56.1-norust from ./run. Default scripts: the M1
# scripts that call sha1, sha1-is-sha1dc, parse-options*, parse-subcommand,
# config, date show/relative/human, wildmatch and ref-store. In t0006 the date parse actions go
# through sub/date to the reference git, so that script checks the
# formatting side only.
set -u
ref=$(cd "${1:?REF_BUILD}" && pwd)
tool=${2:?RGIT_TEST_TOOL}
shift 2
here=$(cd "$(dirname "$0")" && pwd)
case $tool in
/*) ;;
*) tool=$(pwd)/$tool ;;
esac
test -x "$tool" || { echo "not executable: $tool" >&2; exit 2; }
test $# -gt 0 || set -- t0006-date.sh t0013-sha1dc.sh t0040-parse-options.sh \
	t1305-config-include.sh t1308-config-set.sh t1309-early-config.sh \
	t3070-wildmatch.sh t1405-main-ref-store.sh t0600-reffiles-backend.sh

work=$(mktemp -d "${TMPDIR:-/tmp}/check-rgit-test-tool.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/install" "$work/trash"
ln -s "$ref/git" "$work/install/git"
ln -s "$here/test-tool" "$work/install/test-tool"

fail=0
for s in "$@"
do
	if (
		cd "$ref/t" &&
		GIT_TEST_INSTALLED=$work/install GIT_EXEC_PATH=$ref \
		REF_TEST_TOOL=$ref/t/helper/test-tool RGIT_TEST_TOOL=$tool \
		RGIT_TEST_TOOL_STRICT=1 RGIT_TEST_TOOL_FORWARD_LOG=$work/forwarded \
			sh "./$s" --root="$work/trash" >"$work/out" 2>&1
	)
	then
		echo "ok: $s ($(grep -c '^ok ' "$work/out") passed)"
	else
		fail=1
		echo "FAIL: $s"
		grep -E '^(not ok|# failed)' "$work/out" | sed 's/^/  /'
	fi
done
if test -s "$work/forwarded"
then
	echo "forwarded to the reference test-tool:"
	sort "$work/forwarded" | uniq -c | sed 's/^/  /'
fi
exit $fail
