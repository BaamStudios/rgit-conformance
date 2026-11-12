# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-cat-file.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-cat-file.sh). GPL-2.0, see LICENSE.
# Library of git-cat-file related test functions.

# Print a string without a trailing newline.
echo_without_newline () {
	printf '%s' "$*"
}

# Print a string without newlines and replace them with a NUL character (\0).
echo_without_newline_nul () {
	echo_without_newline "$@" | tr '\n' '\0'
}

# Calculate the length of a string.
strlen () {
	echo_without_newline "$1" | wc -c | sed -e 's/^ *//'
}
