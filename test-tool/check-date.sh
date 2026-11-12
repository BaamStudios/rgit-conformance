#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Differential test of the `date` substitute: every `test-tool date parse`,
# `approxidate` and `timestamp` call that t0006-date.sh and t1300-config.sh
# make is run through the reference test-tool and through sub/date, and
# stdout, stderr and exit code must be equal.
#
#   test-tool/check-date.sh REF_TEST_TOOL GIT [T_DIR]
#
# GIT is the git the substitute talks to. With the reference git it checks the
# substitute itself; with rgit it checks rgit's date parser.
# T_DIR holds t0006-date.sh (default: t/ of this repository, then $UPSTREAM_T).
set -u
ref=$1
git=$2
here=$(cd "$(dirname "$0")" && pwd)
tdir=${3:-}
if test -z "$tdir"
then
	if test -f "$here/../t/t0006-date.sh"
	then
		tdir=$here/../t
	else
		tdir=${UPSTREAM_T:?pass T_DIR or set UPSTREAM_T}
	fi
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/check-date.XXXXXX")
trap 'rm -rf "$work"' EXIT

now0=1251660000
cases=$work/cases
: >"$cases"

# Record "TZ<TAB>NOW<TAB>action<TAB>date" for the case helpers of t0006.
check_parse () {
	printf '%s\t%s\tparse\t%s\n' "${3:-UTC}" "$now0" "$1" >>"$cases"
}
check_approxidate () {
	now=$now0
	if test "${3:-}" != failure && test -n "${3:-}"
	then
		set -- "$1" "$2" $3
		case $4 in
		hours) unit=3600 ;;
		days) unit=86400 ;;
		esac
		now=$((now0 + $3 * unit))
	fi
	printf 'UTC\t%s\tapproxidate\t%s\n' "$now" "$1" >>"$cases"
	printf 'UTC\t%s\ttimestamp\t%s\n' "$now" "$1" >>"$cases"
}
eval "$(grep -E '^(check_parse|check_approxidate) [^(]' "$tdir/t0006-date.sh")"

# t1300 asks for several relative dates in one call.
printf 'UTC\t%s\ttimestamp\t%s\n' "$now0" "never" >>"$cases"
printf 'UTC\t%s\ttimestamp\t%s\n' "$now0" "now" >>"$cases"

fail=0 total=0
mkdir "$work/bin"
ln -s "$here/test-tool" "$work/bin/test-tool"
while IFS='	' read -r tz now action d
do
	total=$((total + 1))
	TZ=$tz GIT_TEST_DATE_NOW=$now "$ref" date "$action" "$d" \
		>"$work/r.out" 2>"$work/r.err"
	r=$?
	TZ=$tz GIT_TEST_DATE_NOW=$now REF_TEST_TOOL=$ref RGIT=$git \
		RGIT_TEST_TOOL_STRICT=1 "$work/bin/test-tool" date "$action" "$d" \
		>"$work/s.out" 2>"$work/s.err"
	s=$?
	if test $r != $s || ! cmp -s "$work/r.out" "$work/s.out" ||
		! cmp -s "$work/r.err" "$work/s.err"
	then
		fail=$((fail + 1))
		echo "DIFF TZ=$tz NOW=$now date $action '$d'"
		echo "  reference ($r): $(cat "$work/r.out" "$work/r.err")"
		echo "  substitute ($s): $(cat "$work/s.out" "$work/s.err")"
	fi
done <"$cases"

# Several dates in one call, as t1300 does.
TZ=UTC GIT_TEST_DATE_NOW=$now0 "$ref" date timestamp never now '3.days.ago' >"$work/r.out" 2>&1
TZ=UTC GIT_TEST_DATE_NOW=$now0 REF_TEST_TOOL=$ref RGIT=$git "$work/bin/test-tool" date timestamp \
	never now '3.days.ago' >"$work/s.out" 2>&1
total=$((total + 1))
if ! cmp -s "$work/r.out" "$work/s.out"
then
	fail=$((fail + 1))
	echo "DIFF date timestamp with several dates"
fi

echo "date substitute: $((total - fail))/$total cases equal"
test $fail = 0
