#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Self-test of the regression gate (rgit #9): routes `init` to a fake rgit that
# always fails and expects `./run --check` to report regressions against the
# committed baseline. Also checks that the unchanged setup passes the gate.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/fake-rgit" <<'EOS'
#!/bin/sh
echo "fake-rgit: not implemented" >&2
exit 1
EOS
chmod +x "$tmp/fake-rgit"
printf -- '--version\n' >"$tmp/implemented-ok.txt"
printf -- '--version\ninit\n' >"$tmp/implemented-broken.txt"

script=${1:-t0000-basic.sh}

echo "gate self-test 1: unchanged setup must pass"
"$ROOT/run" --mode fallback --rgit "$ROOT/selftest/version-only-rgit" \
	--implemented "$tmp/implemented-ok.txt" --out "$tmp/ok" --no-status --check "$script"

echo "gate self-test 2: breaking 'init' must fail the gate"
if "$ROOT/run" --mode fallback --rgit "$tmp/fake-rgit" \
	--implemented "$tmp/implemented-broken.txt" \
	--out "$tmp/broken" --no-status --check "$script" 2>"$tmp/err"
then
	cat "$tmp/err" >&2
	echo "FAIL: the gate did not catch the regression" >&2
	exit 1
fi
grep -q '^REGRESSION: ' "$tmp/err" || { cat "$tmp/err" >&2; echo "FAIL: no REGRESSION line" >&2; exit 1; }
echo "ok: $(grep -c '^REGRESSION: ' "$tmp/err") regressions reported, gate is red"
