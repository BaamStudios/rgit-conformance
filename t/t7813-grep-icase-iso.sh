#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/t7813-grep-icase-iso.sh
# (https://github.com/git/git/blob/v2.56.1/t/t7813-grep-icase-iso.sh). GPL-2.0, see LICENSE.

test_description='grep icase on non-English locales'

. ./lib-gettext.sh

test_expect_success GETTEXT_ISO_LOCALE 'setup' '
	printf "TILRAUN: Halló Heimur!" >file &&
	git add file &&
	LC_ALL="$is_IS_iso_locale" &&
	export LC_ALL
'

test_expect_success GETTEXT_ISO_LOCALE,PCRE 'grep pcre string' '
	git grep --perl-regexp -i "TILRAUN: H.lló Heimur!" &&
	git grep --perl-regexp -i "TILRAUN: H.LLÓ HEIMUR!"
'

test_done
