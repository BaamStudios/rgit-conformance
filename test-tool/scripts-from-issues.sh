#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Print the upstream test scripts named in the open M1 and M2 issues of
# BaamStudios/rgit as "milestone<TAB>issue<TAB>script", sorted.
# A bare number such as "t1006" is resolved against the upstream t/ directory.
#
# Usage: test-tool/scripts-from-issues.sh [UPSTREAM_T] > test-tool/scripts.tsv
# Needs: gh (authenticated), jq.
set -eu
T=${1:-${UPSTREAM_T:-../rgit/upstream/git/t}}
test -d "$T" || { echo "upstream t/ directory not found: $T" >&2; exit 1; }

printf '# milestone\tissue\tscript\n'
printf '# Upstream scripts named in open M1/M2 issues of BaamStudios/rgit.\n'
printf '# Regenerate: test-tool/scripts-from-issues.sh > test-tool/scripts.tsv\n'
for m in "M1 – Read a repository" "M2 – Minimal client (MVP)"; do
	tag=${m%% *}
	gh issue list -R BaamStudios/rgit --milestone "$m" --state open --limit 500 \
		--json number,body |
	jq -r --arg t "$tag" '.[] | . as $i
		| ($i.body | [scan("t[0-9]{4}")] | unique[]) as $s
		| "\($t)\t\($i.number)\t\($s)"'
done | sort -u | while IFS='	' read -r m n p; do
	for f in "$T/$p"-*.sh; do
		test -f "$f" && printf '%s\t%s\t%s\n' "$m" "$n" "${f##*/}"
	done
done | sort -u
