# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-httpd/incomplete-length-upload-pack-v2-http.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-httpd/incomplete-length-upload-pack-v2-http.sh). GPL-2.0, see LICENSE.
printf "Content-Type: text/%s\n" "application/x-git-upload-pack-result"
echo
printf "%s" "00"
