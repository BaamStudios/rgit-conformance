#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t4025-hunk-header.sh
# (https://github.com/git/git/blob/v2.56.1/t/t4025-hunk-header.sh). GPL-2.0, see LICENSE.

test_description='diff hunk header truncation'

. ./test-lib.sh

N='日本語'
N1='日'
N2='日本'
NS="$N$N$N$N$N$N$N$N$N$N$N$N$N"

test_expect_success setup '

	(
		echo "A $NS" &&
		printf "  %s\n" B C D E F G H I J K &&
		echo "L  $NS" &&
		printf "  %s\n" M N O P Q R S T U V
	) >file &&
	git add file &&

	sed -e "/^  [EP]/s/$/ modified/" <file >file+ &&
	mv file+ file

'

test_expect_success 'hunk header truncation with an overly long line' '

	git diff | sed -n -e "s/^.*@@//p" >actual &&
	(
		echo " A $N$N$N$N$N$N$N$N$N2" &&
		echo " L  $N$N$N$N$N$N$N$N$N1"
	) >expected &&
	test_cmp expected actual

'

test_done
