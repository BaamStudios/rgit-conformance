#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4101-apply-nonl.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4101-apply-nonl.sh). GPL-2.0, see LICENSE.
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='git apply should handle files with incomplete lines.

'

. ./test-lib.sh

# setup

(echo a; echo b) >frotz.0
(echo a; echo b; echo c) >frotz.1
(echo a; echo b | tr -d '\012') >frotz.2
(echo a; echo c; echo b | tr -d '\012') >frotz.3

for i in 0 1 2 3
do
  for j in 0 1 2 3
  do
    test $i -eq $j && continue
    cat frotz.$i >frotz
    test_expect_success "apply diff between $i and $j" '
	git apply <"$TEST_DIRECTORY"/t4101/diff.$i-$j &&
	test_cmp frotz.$j frotz
    '
  done
done

test_done
