# rgit-conformance: copied unchanged from git v2.56.1, path t/lib-sudo.sh
# (https://github.com/git/git/blob/v2.56.1/t/lib-sudo.sh). GPL-2.0, see LICENSE.
# Helpers for running git commands under sudo.

# Runs a scriplet passed through stdin under sudo.
run_with_sudo () {
	local ret
	local RUN="$TEST_DIRECTORY/$$.sh"
	write_script "$RUN" "$TEST_SHELL_PATH"
	# avoid calling "$RUN" directly so sudo doesn't get a chance to
	# override the shell, add additional restrictions or even reject
	# running the script because its security policy deem it unsafe
	sudo "$TEST_SHELL_PATH" -c "\"$RUN\""
	ret=$?
	rm -f "$RUN"
	return $ret
}
