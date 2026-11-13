# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-httpd/error-smart-http.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-httpd/error-smart-http.sh). GPL-2.0, see LICENSE.
echo "Content-Type: application/x-git-upload-pack-advertisement"
echo
printf "%s" "0019ERR server-side error"
