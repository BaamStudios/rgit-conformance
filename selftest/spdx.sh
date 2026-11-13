#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Self-test of ./check-spdx (rgit #241): the current tree passes; a new
# rgit-owned script without header, a file with an MIT identifier and an
# unmarked file under t/ each make it fail.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
mkdir -p "$HOME"

echo "spdx self-test 1: the current tree passes"
"$ROOT/check-spdx" "$ROOT"

fresh () {
	rm -rf "$tmp/repo"
	mkdir "$tmp/repo"
	(cd "$ROOT" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$tmp/repo"
	git -C "$tmp/repo" init -q
	git -C "$tmp/repo" add -A
}

expect_fail () {
	git -C "$tmp/repo" add -A
	if "$ROOT/check-spdx" "$tmp/repo" 2>"$tmp/err"
	then
		echo "spdx self-test: check passed but should fail ($1)" >&2
		exit 1
	fi
	grep -q "$2" "$tmp/err" || {
		echo "spdx self-test: expected '$2' in:" >&2
		cat "$tmp/err" >&2
		exit 1
	}
	echo "  failed as expected: $1"
}

echo "spdx self-test 2: rgit-owned script without header"
fresh
printf '#!/bin/sh\necho hi\n' >"$tmp/repo/test-tool/sub/new-sub"
expect_fail "script without header" "test-tool/sub/new-sub: needs"

echo "spdx self-test 3: MIT identifier"
fresh
printf '// SPDX-License-Identifier: %s\n' "M""IT" >"$tmp/repo/unit/src/mit.rs"
expect_fail "MIT header" "unit/src/mit.rs: MIT SPDX identifier"

echo "spdx self-test 4: file under t/ that is neither imported nor GPL-marked"
fresh
printf '#!/bin/sh\ntrue\n' >"$tmp/repo/t/t9999-own.sh"
expect_fail "unmarked t/ file" "t/t9999-own.sh: neither imported"

echo "spdx self-test passed"
