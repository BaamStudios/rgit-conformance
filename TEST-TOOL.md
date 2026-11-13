# test-tool in rgit runs

Upstream scripts call `test-tool`, git's C test helper. In the reference pass
the scripts use the reference build's `test-tool` as they are. In the rgit pass
some subcommands would only test the reference build's own library code, so
they get substitutes that ask rgit for the answer (rgit issue #6, ADR 0001).

Substitutes are written from **observed behaviour only**: the usage text of the
reference `test-tool <cmd> -h`, its output for the inputs the scripts use, and
the scripts themselves. git's `t/helper/*.c` is implementation code and is never
read (rgit `CLEANROOM.md`).

## Classes

| Class | Meaning | In the rgit pass |
|---|---|---|
| A | Neutral utility (`chmtime`, `genrandom`, `path-utils file-size`, ...) | reference binary |
| B | Reads or writes repository or wire data (`dump-untracked-cache`, `read-midx`, `pkt-line pack`, ...). git's own reader must accept what rgit wrote, so this is a compatibility check in itself | reference binary, on purpose |
| C | Calls the library code that the script is testing (`date`, `parse-options`, `ref-store`, `config`, ...). From the reference build it says nothing about rgit | substitute in `test-tool/sub/`, otherwise reference binary and reported as forwarded |

`test-tool/classes.tsv` holds the class and owner issue per subcommand. A key
can name an action (`path-utils file-size`, `ref-store for-each-reflog-ent`);
the most specific key wins. Deviations from the lists in rgit issue #6:

- `path-utils` is split: `file-size`, `readlink`, `real_path`,
  `absolute_path` and `normalize_path_copy` only compute expected values in the
  M1/M2 scripts (class A). `t0060-path-utils.sh`, which tests the path functions
  themselves, is not in M1/M2 and would need class C.
- `pkt-line pack`, `pack-raw-stdin` and `unpack` encode requests for and decode
  answers from the git under test (class B, a wire compatibility check). The
  sideband actions remain class C (#60).
- `scrap-cache-tree` and `pack-deltas` write data that rgit then reads (class B).

## How the rgit pass uses it

```
<rgit install dir>/
  git        -> rgit (or the fallback wrapper of #5)
  test-tool  -> rgit-conformance/test-tool/test-tool
```

With `GIT_TEST_INSTALLED`, `test-lib.sh` puts the install directory in front of
the reference build's `t/helper`, so the dispatcher `test-tool/test-tool` runs
first. It handles `-C <dir>`, runs `test-tool/sub/<subcommand>` when a
substitute exists and otherwise execs the reference binary (the next
`test-tool` on `PATH`, or `$REF_TEST_TOOL`).

| Variable | Effect |
|---|---|
| `REF_TEST_TOOL` | reference `test-tool`; default: next one on `PATH` |
| `RGIT` | git the substitutes call; default `git` on `PATH`, i.e. the git under test |
| `RGIT_TEST_TOOL_STRICT=1` | a substitute fails (exit 127) instead of forwarding an action it does not implement |
| `RGIT_TEST_TOOL_FORWARD_LOG` | file that receives `<subcommand> <action>` for every forwarded call |
| `RGIT_TEST_TOOL_DISABLE` | space separated substitutes to switch off |
| `RGIT_TEST_TOOL` | the `rgit-test-tool` binary; default: `rgit-test-tool` next to `$RGIT`, then on `PATH` |

## Substitutes

| Subcommand | Actions done | Through | Forwarded | Checked by |
|---|---|---|---|---|
| `date` | `parse`, `approxidate`, `timestamp`; `show:<format>`, `relative`, `human`, `is64bit`, `time_t-is64bit`, `getnanos` | `GIT_AUTHOR_DATE=<d> git var GIT_AUTHOR_IDENT`; `git rev-parse --since=<d>` in a scratch repository; the formatting actions and `getnanos` through `rgit-test-tool date` (rgit #192) | the `rgit-test-tool` actions when no `rgit-test-tool` is found | `test-tool/check-date.sh`, `test-tool/check-rgit-test-tool.sh` |
| `ref-store` | `create-symref`, `delete-refs`, `rename-ref`, `for-each-ref`, `resolve-ref`, `verify-ref`, `for-each-reflog`, `for-each-reflog-ent`, `for-each-reflog-ent-reverse`, `reflog-exists`, `create-reflog`, `delete-reflog`, `update-ref`, `delete-ref` on the stores `main`, `worktree:main`, `worktree:<id>` | `rgit-test-tool ref-store` (rgit #192 on rgit-refs #29 and its reflogs #30), via `sub/ref-store` | the other functions; everything when no `rgit-test-tool` is found | `test-tool/check-rgit-test-tool.sh` |
| `sha1`, `sha256`, `sha1-is-sha1dc`, `parse-options`, `parse-options-flags`, `parse-subcommand`, `config`, `wildmatch` | all | `rgit-test-tool <subcommand>` (rgit `crates/rgit-test-tool`, rgit #192), via `sub/rgit-test-tool.sh` | everything when no `rgit-test-tool` is found | `test-tool/check-rgit-test-tool.sh` |

`check-date.sh REF_TEST_TOOL GIT` runs every `parse`, `approxidate` and
`timestamp` case of `t0006-date.sh` (with its `TZ` and `GIT_TEST_DATE_NOW`
offsets) plus the multi-date call of `t1300-config.sh` through the reference
`test-tool` and through the substitute, and compares stdout, stderr and exit
code. With the reference git v2.56.1 as `GIT`: 146/146 equal. With rgit as `GIT`
it becomes the acceptance check for rgit's date parser (#74). `t0006-date.sh`
and `t1300-config.sh` pass unchanged with the dispatcher installed.

The substitute only uses commands that are in M1 anyway: `var` (#122 for the
command, #74 for the parser), `rev-parse --since` (#32) and repository
discovery with `--git-dir` (#26).

`sub/sha1`, `sub/parse-options`, ... are symbolic links to
`sub/rgit-test-tool.sh`, which execs `rgit-test-tool <subcommand> "$@"`.
`rgit-test-tool` is rgit's MIT helper binary built from rgit's crates
(`cargo build -p rgit-test-tool`); its behaviour comes only from the
reference binary's `-h` output and its answers, and its own tests compare it
with the reference `test-tool` call by call.

`check-rgit-test-tool.sh REF_BUILD RGIT_TEST_TOOL [SCRIPT...]` runs
`t0006-date.sh`, `t0013-sha1dc.sh`, `t0040-parse-options.sh`,
`t1305-config-include.sh`, `t1308-config-set.sh`, `t1309-early-config.sh`,
`t3070-wildmatch.sh`, `t1405-main-ref-store.sh` and
`t0600-reffiles-backend.sh` from the reference build with the reference git
but the dispatcher as `test-tool`, with `RGIT_TEST_TOOL_STRICT=1`. All nine
pass as with the reference test-tool (t1309 keeps its two known breakages).

`sub/ref-store` sends the functions listed above to `rgit-test-tool
ref-store` and forwards the rest, so scripts that use `ref-store` only as a
fixture tool (t1400, t1430, t3800) keep working with functions rgit-test-tool
does not have.

## Plan for the class C subcommands of M1

Ranked by call sites in M1 scripts (see the inventory below). A call site in a
helper function can run many times: t0006 has 6 `date` call sites and about 150
`date` invocations.

Where no public git command gives the same answer, the substitute needs an
entry point in rgit. Proposal: a small binary `rgit-test-tool` in the rgit
repository (MIT, built from rgit's crates, behaviour defined only by the
reference `test-tool`'s observed output), installed next to `rgit`;
`test-tool/sub/<name>` then execs `rgit-test-tool <name> "$@"` and keeps
forwarding unimplemented actions. Every substitute gets a differential check
like `check-date.sh` that replays the scripts' invocations against both
binaries.

1. **`parse-options`, `parse-subcommand`, `parse-options-flags`** (90 call
   sites, all in `t0040-parse-options.sh`, owner #73). No public equivalent:
   the helper defines its own option table (see `test-tool parse-options -h`)
   and prints the parsed values. Needs `rgit-test-tool parse-options*` on top
   of rgit's option parser, with the option table and the usage text taken
   from `-h` and the value dump format taken from t0040's expected output.
   Differential check: every t0040 invocation, stdout, stderr, exit code.
2. **`ref-store`** (about 95 call sites in M1, owners #29, reflog actions #30).
   Two different uses:
   - `t1430-bad-ref-name.sh`, `t1400-update-ref.sh`, `t3800-mktag.sh` use it
     as a fixture tool: create refs and symrefs with invalid names that `git
     update-ref` refuses, delete them again, and dump reflog entries. With the
     files backend the reference binary works on repositories rgit created and
     reads what rgit wrote, so it can stay (role B) as long as rgit writes
     standard files-backend data.
   - `t1405-main-ref-store.sh` and `t0600-reffiles-backend.sh` test the ref
     store API itself (`resolve-ref`, `verify-ref`, `rename-ref`,
     `for-each-ref`, worktree stores). Needs `rgit-test-tool ref-store <store>
     <action>` on top of rgit-refs. Output formats come from the reference
     binary's answers on the same repositories.
   - Under `GIT_TEST_DEFAULT_REF_FORMAT=reftable` (#31) the fixture role also
     needs the rgit helper unless rgit's reftable output is byte-compatible.
3. **`delta`** (9 call sites, `t5303-pack-corruption-resilience.sh`, owner #17).
   Only `-p <base> <delta> <out>` (apply) is used; no git command applies a
   raw delta, so `rgit-test-tool delta -p` on rgit-pack's delta decoder. The
   scripts check exit codes; the failure message is `fatal: delta operation
   failed (returned NULL)` with exit 128 (observed).
4. **`config`** (28 call sites in `t1305`, `t1308`, `t1309`, owner #28). The
   config API actions (`get`, `get_value`, `get_string`,
   `configset_get_value[_multi]`, `iterate`, `read_early_config`) have their
   own exit codes (1 missing key, 2 unreadable file, 128 fatal) and output
   formats, which `git config` does not reproduce. Needs
   `rgit-test-tool config` on top of rgit-config.
5. **`date show:<format>`, `relative`, `human`** (owner #74). Could be built
   from public commands (`git hash-object -t commit -w` plus
   `git log --date=<format> --format=%ad`), but that ties t0006 to `log`
   formatting that M1 does not have (#78 only covers the default and
   `--oneline` formats). Proposal: `rgit-test-tool date`.
6. **`sha1`, `sha1-is-sha1dc`** (t0013, owner #11; `sha256` for #12).
   `sha1` hashes stdin and prints the hex id; on the SHAttered PDF it fails
   with `fatal: SHA-1 appears to be part of a collision attack: <hex>`, exit
   128 (observed). `git hash-object` hashes with an object header, so it is
   not a replacement. Needs `rgit-test-tool sha1|sha256|sha1-is-sha1dc`.
7. **`subprocess`** (1 call site, `t1501-work-tree.sh`, owner #26). Sets up the
   repository (with `--setup-work-tree` also the work tree) and then runs `git
   <args>` as a child process; t1501 checks that a relative `GIT_WORK_TREE`
   still works in the child. Needs `rgit-test-tool subprocess` using rgit's
   setup code.
8. **`serve-v2`** (2 call sites in `t5702-protocol-v2.sh`, 29 in
   `t5701-git-serve.sh`). The protocol v2 server is rgit M5; until then the
   reference binary serves the client tests.
9. **`sigchain`** (`t0005-signals.sh`, owner #98) tests git's signal handler
   chain, a C library detail without an rgit equivalent. Proposal: exclude
   these cases for rgit (open question for a maintainer).

## Maintenance

```
test-tool/scripts-from-issues.sh UPSTREAM_T > test-tool/scripts.tsv  # needs gh
test-tool/inventory.py --write --upstream UPSTREAM_T                  # regenerate below
test-tool/inventory.py --check [--upstream UPSTREAM_T]               # CI
```

`--check` fails when a scanned script uses a subcommand that has no class in
`test-tool/classes.tsv`, and, with `--upstream`, when the section below is out
of date. Without `--upstream` it checks only the imported scripts in `t/`.
`test-tool/known-subcommands.txt` is the subcommand list of the reference
binary (`test-tool` without arguments); the scanner ignores words after
`test-tool` that are not in it (prose in comments and strings).

<!-- BEGIN GENERATED INVENTORY -->
<!-- Generated by test-tool/inventory.py --write. Do not edit by hand. -->

## Inventory

Scripts scanned: the upstream scripts named in open rgit M1/M2 issues
(`test-tool/scripts.tsv`) plus the imported scripts in `t/`. Counts are
call sites in the script text (a helper function called in a loop counts
once), including calls through the wrapper functions of
`test-lib-functions.sh` (`packetize`, `test_file_size`, ...) and through
variables such as `RUN="test-tool ref-store main"`. Calls inside sourced
`lib-*.sh` files are listed separately. Class and owner come from
`test-tool/classes.tsv`.

### By subcommand

| Subcommand | Calls | Scripts | Also in | Milestones | Class | Owner | Note |
|---|---:|---:|---|---|---|---|---|
| `advise` | 3 | 1 | - | M2 | C | #178 | advice output (t0018) |
| `chmtime` | 28 | 9 | - | M2 | A |  | file mtimes |
| `config read_early_config` | 8 | 2 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config configset_get_value` | 6 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get` | 5 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config` | 3 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config configset_get_value_multi` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get_string` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get_value` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config iterate` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `date approxidate` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date human` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date parse` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date relative` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date show:<format>` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date timestamp` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `delta` | 9 | 1 | - | M1 | C | #17 | delta application (t5303) |
| `dump-cache-tree` | 2 | 1 | - | M2 | B |  | reads the index cache-tree extension |
| `dump-split-index` | 2 | 1 | - | M2 | B |  | reads split index |
| `dump-untracked-cache` | 36 | 1 | - | M2 | B |  | reads the untracked-cache extension |
| `env-helper` | 13 | 1 | lib-git-daemon.sh, lib-httpd.sh | M1, M2 | A |  | reads an environment variable as bool/ulong |
| `genrandom` | 18 | 6 | - | M1, M2 | A |  | deterministic pseudo-random bytes |
| `genzeros` | 7 | 2 | - | M1, M2 | A |  | zero bytes |
| `getcwd` | 1 | 1 | - | M1 | A |  | prints the working directory |
| `pack-deltas` | 1 | 1 | - | M2 | B |  | writes a crafted pack (fixture) that rgit must read |
| `parse-options` | 61 | 1 | - | M1 | C | #73 | option parser (t0040) |
| `parse-options-flags` | 7 | 1 | - | M1 | C | #73 | option parser flags (t0040) |
| `parse-pathspec-file` | 8 | 1 | - | M2 | C | #106 | --pathspec-from-file parsing (t0067) |
| `parse-subcommand` | 22 | 1 | - | M1 | C | #73 | subcommand parser (t0040) |
| `path-utils real_path` | 9 | 3 | - | M1, M2 | A |  | expected path for comparisons |
| `path-utils file-size` | 7 | 4 | - | M1, M2 | A |  | file size |
| `path-utils normalize_path_copy` | 4 | 1 | - | M2 | A |  | expected path for comparisons (t0007); t0060 itself would be C |
| `path-utils absolute_path` | 2 | 1 | - | M1 | A |  | expected path for comparisons |
| `path-utils readlink` | 2 | 1 | - | M1 | A |  | symlink target |
| `pkt-line pack` | 33 | 4 | - | M1, M2 | B |  | encodes request input; the git under test decodes it |
| `pkt-line unpack` | 26 | 3 | - | M2 | B |  | decodes the output of the git under test |
| `pkt-line pack-raw-stdin` | 1 | 1 | - | - | B |  | encodes request input; the git under test decodes it |
| `reach` | 1 | 1 | - | M2 | C | #50 | reachability queries (t6600) |
| `ref-store delete-refs` | 31 | 4 | - | M1, M2 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store for-each-reflog-ent` | 23 | 3 | - | M1, M2 | C | #30 | reflog reader |
| `ref-store update-ref` | 16 | 4 | - | M1, M2 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store create-symref` | 14 | 3 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store delete-reflog` | 4 | 2 | - | M1, M2 | C | #30 | reflog writer |
| `ref-store reflog-exists` | 4 | 2 | - | M1, M2 | C | #30 | reflog reader |
| `ref-store for-each-reflog` | 3 | 2 | - | M1 | C | #30 | reflog reader |
| `ref-store create-reflog` | 2 | 2 | - | M1, M2 | C | #30 | reflog writer |
| `ref-store for-each-ref` | 2 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store delete-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store for-each-reflog-ent-reverse` | 1 | 1 | - | M1 | C | #30 | reflog reader |
| `ref-store rename-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store resolve-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store verify-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `scrap-cache-tree` | 4 | 1 | - | M2 | B |  | rewrites the index without cache-tree; rgit must read the result |
| `serve-v2` | 31 | 2 | - | M1, M2 | C | M5 | protocol v2 server (t5701, t5702); server side is not part of M1/M2 |
| `sha1` | 1 | 1 | - | M1 | C | #11 | collision-detecting SHA-1 (t0013) |
| `sha1-is-sha1dc` | 1 | 1 | - | M1 | C | #11 | prerequisite: SHA-1 is collision detecting |
| `sha1/sha256 (via $algo)` | 0 | 0 | lib-loose.sh, lib-pack.sh | - | A |  | hash of stdin, used by lib-loose.sh/lib-pack.sh to craft objects |
| `sigchain` | 2 | 1 | - | M1 | C | #98 | signal handler chain (t0005); library internals, likely excluded for rgit |
| `subprocess` | 1 | 1 | - | M1 | C | #26 | repository setup before running a command (t1501) |
| `truncate` | 3 | 1 | - | M2 | A |  | truncates a file |
| `wildmatch` | 3 | 1 | - | M2 | C | #106 | wildmatch (t3070) |
| `zlib` | 0 | 0 | lib-loose.sh | - | A |  | deflate/inflate stdin, used to craft loose objects |

### Class C call sites per milestone

- **M1**: `parse-options` 61, `ref-store delete-refs` 31, `parse-subcommand` 22, `ref-store for-each-reflog-ent` 19, `ref-store update-ref` 15, `ref-store create-symref` 14, `delta` 9, `config read_early_config` 8, `parse-options-flags` 7, `config configset_get_value` 6, `config get` 5, `ref-store delete-reflog` 4, `config` 3, `ref-store for-each-reflog` 3, `ref-store for-each-ref` 2, `serve-v2` 2, `sigchain` 2, `config configset_get_value_multi` 1, `config get_string` 1, `config get_value` 1, `config iterate` 1, `date approxidate` 1, `date human` 1, `date parse` 1, `date relative` 1, `date show:<format>` 1, `date timestamp` 1, `ref-store create-reflog` 1, `ref-store delete-ref` 1, `ref-store for-each-reflog-ent-reverse` 1, `ref-store reflog-exists` 1, `ref-store rename-ref` 1, `ref-store resolve-ref` 1, `ref-store verify-ref` 1, `sha1` 1, `sha1-is-sha1dc` 1, `subprocess` 1
- **M2**: `serve-v2` 31, `ref-store for-each-reflog-ent` 22, `parse-pathspec-file` 8, `advise` 3, `ref-store delete-reflog` 3, `ref-store reflog-exists` 3, `wildmatch` 3, `ref-store delete-refs` 2, `reach` 1, `ref-store create-reflog` 1, `ref-store update-ref` 1

### By script

| Script | Issues | Subcommands (calls) |
|---|---|---|
| t0000-basic.sh | M1 #5, M2 #123 | `env-helper` 13 |
| t0001-init.sh | M1 #27 | `getcwd` 1, `path-utils absolute_path` 2 |
| t0002-gitfile.sh | M1 #26 | - |
| t0004-unwritable.sh | M1 #98, M2 #123 | - |
| t0005-signals.sh | M1 #98 | `genrandom` 1, `sigchain` 2 |
| t0006-date.sh | M1 #6, M1 #74 | `date approxidate` 1, `date human` 1, `date parse` 1, `date relative` 1, `date show:<format>` 1 |
| t0007-git-var.sh | M2 #122 | `path-utils normalize_path_copy` 4 |
| t0008-ignores.sh | M2 #37 | - |
| t0009-git-dir-validation.sh | M1 #26 | - |
| t0010-racy-git.sh | M2 #36 | - |
| t0012-help.sh | M1 #73 | - |
| t0013-sha1dc.sh | M1 #6, M1 #11 | `sha1` 1, `sha1-is-sha1dc` 1 |
| t0018-advice.sh | M2 #178 | `advise` 3 |
| t0031-lockfile-pid.sh | M1 #98 | - |
| t0033-safe-directory.sh | M1 #26 | - |
| t0034-root-safe-directory.sh | M1 #26 | - |
| t0035-safe-bare-repository.sh | M1 #26 | - |
| t0040-parse-options.sh | M1 #6, M1 #73 | `parse-options` 61, `parse-options-flags` 7, `parse-subcommand` 22 |
| t0055-beyond-symlinks.sh | M2 #39 | - |
| t0056-git-C.sh | M1 #73 | - |
| t0067-parse_pathspec_file.sh | M2 #106 | `parse-pathspec-file` 8 |
| t0090-cache-tree.sh | M2 #79, M2 #123 | `dump-cache-tree` 2, `dump-split-index` 2, `scrap-cache-tree` 4 |
| t0100-previous.sh | M2 #30 | - |
| t0300-credentials.sh | M2 #161 | - |
| t0302-credential-store.sh | imported | - |
| t0303-credential-external.sh | M2 #161 | - |
| t0450-txt-doc-vs-help.sh | M1 #73 | - |
| t0600-reffiles-backend.sh | M1 #29 | `path-utils readlink` 2, `ref-store create-symref` 1, `ref-store for-each-reflog` 2 |
| t1001-read-tree-m-2way.sh | M2 #107 | - |
| t1002-read-tree-m-u-2way.sh | M2 #107 | - |
| t1003-read-tree-prefix.sh | M2 #107 | - |
| t1004-read-tree-m-u-wf.sh | M2 #107 | - |
| t1005-read-tree-reset.sh | M2 #107 | - |
| t1006-cat-file.sh | M1 #5, M1 #14, M1 #15 | `genrandom` 1, `path-utils file-size` 2 |
| t1007-hash-object.sh | M1 #14, M1 #15 | `genzeros` 4 |
| t1008-read-tree-overlay.sh | M2 #107 | - |
| t1009-read-tree-new-index.sh | M2 #107 | - |
| t1010-mktree.sh | M1 #15 | - |
| t1012-read-tree-df.sh | M2 #107 | - |
| t1014-read-tree-confusing.sh | M2 #107 | - |
| t1017-cat-file-remote-object-info.sh | M1 #15 | - |
| t1060-object-corruption.sh | M1 #14 | - |
| t1100-commit-tree-options.sh | M2 #123 | - |
| t1300-config.sh | M1 #28, M1 #99 | `date timestamp` 1, `path-utils real_path` 1 |
| t1301-shared-repo.sh | M1 #27 | - |
| t1302-repo-version.sh | M1 #33 | - |
| t1303-wacky-config.sh | M1 #28, M1 #99 | - |
| t1305-config-include.sh | M1 #28 | `config read_early_config` 2 |
| t1306-xdg-files.sh | M1 #28 | - |
| t1307-config-blob.sh | M1 #28 | - |
| t1308-config-set.sh | M1 #28 | `config` 3, `config configset_get_value` 6, `config configset_get_value_multi` 1, `config get` 5, `config get_string` 1, `config get_value` 1, `config iterate` 1 |
| t1309-early-config.sh | M1 #28 | `config read_early_config` 6 |
| t1310-config-default.sh | M1 #28 | - |
| t1311-config-optional.sh | M1 #28 | - |
| t1400-update-ref.sh | M1 #29, M2 #30 | `ref-store delete-reflog` 3, `ref-store delete-refs` 2, `ref-store for-each-reflog-ent` 18 |
| t1401-symbolic-ref.sh | M1 #29 | - |
| t1402-check-ref-format.sh | M1 #29 | - |
| t1403-show-ref.sh | M1 #29 | - |
| t1404-update-ref-errors.sh | M1 #29 | - |
| t1405-main-ref-store.sh | M1 #29 | `ref-store create-reflog` 1, `ref-store create-symref` 1, `ref-store delete-ref` 1, `ref-store delete-reflog` 1, `ref-store delete-refs` 1, `ref-store for-each-ref` 2, `ref-store for-each-reflog` 1, `ref-store for-each-reflog-ent` 1, `ref-store for-each-reflog-ent-reverse` 1, `ref-store reflog-exists` 1, `ref-store rename-ref` 1, `ref-store resolve-ref` 1, `ref-store update-ref` 1, `ref-store verify-ref` 1 |
| t1408-packed-refs.sh | M1 #29 | - |
| t1410-reflog.sh | M2 #30 | `ref-store create-reflog` 1, `ref-store for-each-reflog-ent` 4, `ref-store reflog-exists` 3, `ref-store update-ref` 1 |
| t1411-reflog-show.sh | M2 #30 | - |
| t1413-reflog-detach.sh | M2 #30 | - |
| t1418-reflog-exists.sh | M2 #30 | - |
| t1422-show-ref-exists.sh | M1 #29 | - |
| t1430-bad-ref-name.sh | M1 #29 | `ref-store create-symref` 12, `ref-store delete-refs` 26, `ref-store update-ref` 12 |
| t1500-rev-parse.sh | M1 #32 | - |
| t1501-work-tree.sh | M1 #26 | `path-utils real_path` 4, `subprocess` 1 |
| t1503-rev-parse-verify.sh | M1 #32 | - |
| t1504-ceiling-dirs.sh | M1 #26 | - |
| t1506-rev-parse-diagnosis.sh | M1 #32 | - |
| t1507-rev-parse-upstream.sh | imported | - |
| t1509-root-work-tree.sh | M1 #26 | - |
| t1510-repo-setup.sh | M1 #26, M1 #177 | - |
| t1511-rev-parse-caret.sh | M1 #32 | - |
| t1512-rev-parse-disambiguation.sh | imported | - |
| t1513-rev-parse-prefix.sh | M1 #32 | - |
| t1515-rev-parse-outside-repo.sh | M1 #26 | - |
| t1517-outside-repo.sh | M1 #26 | - |
| t1601-index-bogus.sh | M2 #79 | - |
| t2000-conflict-when-checking-files-out.sh | M2 #107 | - |
| t2002-checkout-cache-u.sh | M2 #107 | - |
| t2003-checkout-cache-mkdir.sh | M2 #107 | - |
| t2004-checkout-cache-temp.sh | M2 #107 | - |
| t2005-checkout-index-symlinks.sh | M2 #107 | - |
| t2006-checkout-index-basic.sh | M2 #107 | - |
| t2010-checkout-ambiguous.sh | M2 #42 | - |
| t2011-checkout-invalid-head.sh | M2 #42 | - |
| t2012-checkout-last.sh | M2 #42 | - |
| t2014-checkout-switch.sh | M2 #42 | - |
| t2015-checkout-unborn.sh | M2 #42 | - |
| t2017-checkout-orphan.sh | M2 #42 | - |
| t2018-checkout-branch.sh | M2 #42 | - |
| t2019-checkout-ambiguous-ref.sh | M2 #42 | - |
| t2020-checkout-detach.sh | M2 #42 | - |
| t2021-checkout-overwrite.sh | M2 #42 | - |
| t2024-checkout-dwim.sh | M2 #42 | - |
| t2027-checkout-track.sh | M2 #42 | - |
| t2060-switch.sh | M2 #42 | - |
| t2100-update-cache-badpath.sh | M2 #39 | - |
| t2101-update-index-reupdate.sh | M2 #39 | - |
| t2102-update-index-symlinks.sh | M2 #39 | - |
| t2103-update-index-ignore-missing.sh | M2 #39 | - |
| t2104-update-index-skip-worktree.sh | M2 #39 | - |
| t2106-update-index-assume-unchanged.sh | M2 #36 | - |
| t2107-update-index-basic.sh | M2 #39 | - |
| t2108-update-index-refresh-racy.sh | M2 #36 | `chmtime` 8 |
| t2200-add-update.sh | M2 #41 | - |
| t2201-add-update-typechange.sh | M2 #41 | - |
| t2202-add-addremove.sh | M2 #41 | - |
| t2203-add-intent.sh | M2 #41 | - |
| t2204-add-ignored.sh | M2 #41 | - |
| t2500-untracked-overwriting.sh | M2 #42 | - |
| t3000-ls-files-others.sh | M2 #37 | - |
| t3001-ls-files-others-exclude.sh | M2 #37 | - |
| t3002-ls-files-dashpath.sh | M2 #39 | - |
| t3003-ls-files-exclude.sh | M2 #37 | - |
| t3004-ls-files-basic.sh | M2 #39 | - |
| t3005-ls-files-relative.sh | M2 #39 | - |
| t3006-ls-files-long.sh | M2 #39 | - |
| t3009-ls-files-others-nonsubmodule.sh | M2 #37 | - |
| t3010-ls-files-killed-modified.sh | M2 #39 | - |
| t3011-common-prefixes-and-directory-traversal.sh | M2 #37 | - |
| t3012-ls-files-dedup.sh | M2 #39 | - |
| t3013-ls-files-format.sh | M2 #39 | - |
| t3020-ls-files-error-unmatch.sh | M2 #39 | - |
| t3060-ls-files-with-tree.sh | M2 #39 | - |
| t3070-wildmatch.sh | M2 #106 | `wildmatch` 3 |
| t3100-ls-tree-restrict.sh | M1 #88 | - |
| t3101-ls-tree-dirname.sh | M1 #88 | - |
| t3102-ls-tree-wildcards.sh | M1 #88 | - |
| t3103-ls-tree-misc.sh | M1 #88 | - |
| t3104-ls-tree-format.sh | M1 #88 | - |
| t3105-ls-tree-output.sh | M1 #88 | - |
| t3200-branch.sh | M2 #48 | - |
| t3204-branch-name-interpretation.sh | M2 #48 | - |
| t3211-peel-ref.sh | M1 #29 | - |
| t3600-rm.sh | M2 #41 | `chmtime` 1 |
| t3601-rm-pathspec-file.sh | M2 #41 | - |
| t3700-add.sh | M2 #41 | `chmtime` 1 |
| t3703-add-magic-pathspec.sh | M2 #106 | - |
| t3704-add-pathspec-file.sh | M2 #106 | - |
| t3800-mktag.sh | M1 #15 | `ref-store delete-refs` 2, `ref-store update-ref` 2 |
| t3902-quoted.sh | M2 #39 | - |
| t4000-diff-format.sh | M2 #144 | - |
| t4002-diff-basic.sh | M2 #144 | - |
| t4006-diff-mode.sh | M2 #82 | - |
| t4010-diff-pathspec.sh | M2 #144 | - |
| t4011-diff-symlink.sh | M2 #82 | `chmtime` 1 |
| t4012-diff-binary.sh | M2 #82 | - |
| t4013-diff-various.sh | M2 #82 | `chmtime` 1 |
| t4016-diff-quote.sh | M2 #82 | - |
| t4017-diff-retval.sh | M2 #144 | - |
| t4024-diff-optimize-common.sh | M2 #82 | - |
| t4025-hunk-header.sh | M2 #82 | - |
| t4035-diff-quiet.sh | M2 #144 | `chmtime` 1 |
| t4037-diff-r-t-dirs.sh | M2 #144 | - |
| t4039-diff-assume-unchanged.sh | M2 #144 | - |
| t4044-diff-index-unique-abbrev.sh | M2 #144 | - |
| t4046-diff-unmerged.sh | M2 #144 | - |
| t4054-diff-bogus-tree.sh | M2 #144 | - |
| t4061-diff-indent.sh | M2 #82 | - |
| t4063-diff-blobs.sh | M2 #144 | - |
| t4068-diff-symmetric-merge-base.sh | M2 #144 | - |
| t4074-diff-shifted-matched-group.sh | M2 #82 | - |
| t4202-log.sh | M1 #78 | - |
| t5300-pack-object.sh | M1 #17, M2 #18, M2 #80 | `genrandom` 2, `genzeros` 3, `path-utils file-size` 2 |
| t5302-pack-index.sh | M1 #17, M2 #18 | `genrandom` 7, `path-utils file-size` 1 |
| t5303-pack-corruption-resilience.sh | M1 #17 | `delta` 9, `genrandom` 5 |
| t5306-pack-nobase.sh | M2 #18 | - |
| t5308-pack-detect-duplicates.sh | M2 #18 | - |
| t5309-pack-delta-cycles.sh | M2 #18 | `pack-deltas` 1 |
| t5313-pack-bounds-checks.sh | M1 #17 | `genrandom` 2 |
| t5404-tracking-branches.sh | M2 #65 | - |
| t5406-remote-rejects.sh | M2 #65 | - |
| t5411-proc-receive-hook.sh | M2 #60 | - |
| t5500-fetch-pack.sh | M2 #62 | `pkt-line pack` 1 |
| t5502-quickfetch.sh | M2 #62 | - |
| t5503-tagfollow.sh | M2 #62 | - |
| t5507-remote-environment.sh | M2 #160 | - |
| t5510-fetch.sh | M2 #62, M2 #66 | - |
| t5511-refspec.sh | M2 #159 | - |
| t5512-ls-remote.sh | M2 #63 | `pkt-line pack` 2 |
| t5513-fetch-track.sh | M2 #62 | - |
| t5515-fetch-merge-logic.sh | M2 #62 | - |
| t5516-fetch-push.sh | M2 #65, M2 #66 | `chmtime` 1 |
| t5518-fetch-exit-status.sh | M2 #62 | - |
| t5523-push-upstream.sh | M2 #65 | - |
| t5525-fetch-tagopt.sh | M2 #62 | - |
| t5527-fetch-odd-refs.sh | M2 #62 | - |
| t5528-push-default.sh | M2 #65 | - |
| t5529-push-errors.sh | M2 #65 | - |
| t5535-fetch-push-symref.sh | M2 #62 | - |
| t5536-fetch-conflicts.sh | M2 #62 | - |
| t5541-http-push-smart.sh | M2 #65, M2 #66, M2 #87, M2 #162 | - |
| t5549-fetch-push-http.sh | M2 #162 | - |
| t5551-http-fetch-smart.sh | M2 #66, M2 #87, M2 #162 | - |
| t5555-http-smart-common.sh | M2 #162 | `pkt-line unpack` 10 |
| t5563-simple-http-auth.sh | M2 #162 | - |
| t5570-git-daemon.sh | imported | `pkt-line pack-raw-stdin` 1, `pkt-line unpack` 1 |
| t5574-fetch-output.sh | M2 #62 | `path-utils real_path` 4 |
| t5581-http-curl-verbose.sh | M2 #162 | - |
| t5582-fetch-negative-refspec.sh | M2 #62 | - |
| t5583-push-branches.sh | M2 #65 | - |
| t5600-clone-fail-cleanup.sh | M2 #64 | - |
| t5601-clone.sh | M2 #64, M2 #66, M2 #87, M2 #159, M2 #160 | - |
| t5602-clone-remote-exec.sh | M2 #160 | - |
| t5603-clone-dirname.sh | M2 #64, M2 #159 | - |
| t5609-clone-branch.sh | M2 #64 | - |
| t5610-clone-detached.sh | M2 #64 | - |
| t5611-clone-config.sh | M2 #64 | - |
| t5612-clone-refspec.sh | M2 #64 | - |
| t5701-git-serve.sh | M2 #60 | `path-utils file-size` 2, `pkt-line pack` 25, `pkt-line unpack` 15, `serve-v2` 29 |
| t5702-protocol-v2.sh | M1 #177, M2 #60, M2 #66, M2 #81, M2 #160, M2 #162 | `pkt-line pack` 5, `serve-v2` 2 |
| t6000-rev-list-misc.sh | M1 #78 | - |
| t6005-rev-list-count.sh | M1 #78 | - |
| t6009-rev-list-parent.sh | M1 #78 | - |
| t6010-merge-base.sh | M2 #50 | - |
| t6014-rev-list-all.sh | M1 #78 | - |
| t6040-tracking-info.sh | M2 #40, M2 #48 | - |
| t6099-merge-base-side-exhaustion.sh | M2 #50 | - |
| t6101-rev-parse-parents.sh | M1 #32 | - |
| t6130-pathspec-noglob.sh | M2 #106 | - |
| t6131-pathspec-icase.sh | M2 #106 | - |
| t6132-pathspec-exclude.sh | M2 #106 | - |
| t6136-pathspec-in-bare.sh | M2 #106 | - |
| t6137-pathspec-wildcards-literal.sh | M2 #106 | - |
| t6600-test-reach.sh | M2 #50 | `reach` 1 |
| t7001-mv.sh | M2 #41 | - |
| t7005-editor.sh | M2 #122 | - |
| t7060-wtstatus.sh | M2 #40 | - |
| t7061-wtstatus-ignore.sh | M2 #37, M2 #40 | - |
| t7063-status-untracked-cache.sh | M2 #40 | `chmtime` 7, `dump-untracked-cache` 36 |
| t7064-wtstatus-pv2.sh | M2 #40 | - |
| t7101-reset-empty-subdirs.sh | M2 #49 | - |
| t7102-reset.sh | M2 #49 | - |
| t7103-reset-bare.sh | M2 #49 | - |
| t7104-reset-hard.sh | M2 #49 | - |
| t7106-reset-unborn-branch.sh | M2 #49 | - |
| t7107-reset-pathspec-file.sh | M2 #49 | - |
| t7110-reset-merge.sh | M2 #49 | - |
| t7111-reset-table.sh | M2 #49 | - |
| t7201-co.sh | M2 #42 | - |
| t7501-commit-basic-functionality.sh | M2 #45 | - |
| t7502-commit-porcelain.sh | M2 #45 | - |
| t7508-status.sh | M2 #40 | `chmtime` 7, `truncate` 3 |
| t7509-commit-authorship.sh | M2 #45 | - |
| t7511-status-index.sh | M2 #40 | - |
| t7512-status-help.sh | M2 #40 | - |
| t7515-status-symlinks.sh | M2 #36 | - |
| t7516-commit-races.sh | M2 #45 | - |
| t7517-per-repo-email.sh | M2 #122 | - |
| t7518-ident-corner-cases.sh | M2 #122 | - |
| t7521-ignored-mode.sh | M2 #40 | - |
| t7524-commit-summary.sh | M2 #45 | - |
| t8007-cat-file-textconv.sh | M1 #15 | - |
| t8010-cat-file-filters.sh | M1 #15 | - |

### Sourced libraries

| Library | Used by | Subcommands (calls) |
|---|---:|---|
| lib-git-daemon.sh | 3 | `env-helper` 1 |
| lib-httpd.sh | 11 | `env-helper` 1 |
| lib-loose.sh | 2 | `sha1/sha256 (via $algo)` 1, `zlib` 1 |
| lib-pack.sh | 2 | `sha1/sha256 (via $algo)` 1 |

### Framework

Always loaded, so these run in every script.

- `test-lib.sh`: `date is64bit` 1, `date time_t-is64bit` 1, `path-utils file-size` 1
- `test-lib-functions.sh`: `chmtime` 2, `env-helper` 1, `hexdump` 1, `path-utils file-size` 1, `path-utils readlink` 1, `pkt-line pack` 1, `pkt-line pack-raw-stdin` 1, `pkt-line unpack` 1
<!-- END GENERATED INVENTORY -->
