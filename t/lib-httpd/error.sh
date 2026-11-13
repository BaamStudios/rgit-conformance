#!/bin/sh
# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-httpd/error.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-httpd/error.sh). GPL-2.0, see LICENSE.

printf "Status: 500 Intentional Breakage\n"

printf "Content-Type: "
charset=iso-8859-1
case "$PATH_INFO" in
*html*)
	printf "text/html"
	;;
*text*)
	printf "text/plain"
	;;
*charset*)
	printf "text/plain; charset=utf-8"
	charset=utf-8
	;;
*utf16*)
	printf "text/plain; charset=utf-16"
	charset=utf-16
	;;
*odd-spacing*)
	printf "text/plain; foo=bar ;charset=utf-16; other=nonsense"
	charset=utf-16
	;;
esac
printf "\n"

printf "\n"
printf "this is the error message\n" |
iconv -f us-ascii -t $charset
