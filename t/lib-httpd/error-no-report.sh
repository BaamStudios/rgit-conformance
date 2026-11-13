# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-httpd/error-no-report.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-httpd/error-no-report.sh). GPL-2.0, see LICENSE.
echo "Content-Type: application/x-git-receive-pack-result"
echo
printf '0013\001000eunpack ok\n'
printf '0015\002skipping report\n'
printf '0009\0010000'
printf '0000'
