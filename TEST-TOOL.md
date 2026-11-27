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
| `pkt-line` | `unpack-sideband` (`--[no-]reader-use-sideband`, `--[no-]chomp-newline`), `send-split-sideband`, `receive-sideband` | `rgit-test-tool pkt-line` (rgit #310, on rgit-protocol's side-band code), via `sub/pkt-line` | `pack`, `pack-raw-stdin`, `unpack` (class B on purpose); everything when no `rgit-test-tool` is found | rgit `crates/rgit-test-tool/tests/pkt_line.rs` |
| `serve-v2` | `--stateless-rpc`, `--advertise-capabilities` | `GIT_PROTOCOL=version=2 git upload-pack [--stateless-rpc] [--advertise-refs] <git dir>` (rgit #68), via `sub/serve-v2`; rgit in strict mode, the reference git in fallback mode (`upload-pack` is not in `implemented.txt`: t5701 compares `agent=` with `git version`) | other options | `t5701-git-serve.sh`, `t5703-upload-pack-ref-in-want.sh` in strict mode |
| `bundle-uri` | `parse-key-values`, `parse-config` | `rgit-test-tool bundle-uri` (rgit #172, on rgit-bundle's bundle lists), via `sub/bundle-uri` | `ls-remote` (asks the server; rgit's server side of `bundle-uri` is a follow-up); everything when no `rgit-test-tool` is found | `t5750-bundle-uri-parse.sh` |
| `sha1`, `sha256`, `sha1-is-sha1dc`, `parse-options`, `parse-options-flags`, `parse-subcommand`, `config`, `wildmatch`, `progress` | all | `rgit-test-tool <subcommand>` (rgit `crates/rgit-test-tool`, rgit #192), via `sub/rgit-test-tool.sh` | everything when no `rgit-test-tool` is found | `test-tool/check-rgit-test-tool.sh` |
| `bloom` | `get_murmur3`, `get_murmur3_seven_highbit`, `generate_filter`, `get_filter_for_commit` | `rgit-test-tool bloom` (rgit #22, on rgit-commitgraph's filter code), via `sub/rgit-test-tool.sh` | everything when no `rgit-test-tool` is found | `t0095-bloom.sh` |
| `trace2` | all verbs (`001return` ... `400ancestry`) | `rgit-test-tool trace2` on rgit-trace (rgit #695), via `sub/rgit-test-tool.sh` | everything when no `rgit-test-tool` is found | rgit `crates/rgit-test-tool/tests/trace2.rs` |

`t0210`-`t0213` put `$GIT_BUILD_DIR/t/helper` in front of `PATH` themselves
(for nested `test-tool` calls). So that they reach this dispatcher, `run` sets
`GIT_BUILD_DIR` in the rgit passes to an overlay of the reference build
(`results/<variant>/build-overlay/`) whose `t/helper/test-tool` is this
dispatcher, with `REF_TEST_TOOL` pointing at the real one (rgit #706). Strict
pass on 2026-11-27: t0210 13/14, t0211 12/17, t0212 11/11, t0213 1/5; the rest
needs rgit work (clone with `url.*.insteadOf` on a URL with a password, git
aliases as `git_alias` child processes, `remote-http` / `http-fetch`
def_params). In the fallback pass `git version` goes to the reference, so `run`
switches the substitute off there (`RGIT_TEST_TOOL_DISABLE=trace2`).

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
   `t5701-git-serve.sh`, more in `t5703-upload-pack-ref-in-want.sh`). Done:
   `sub/serve-v2` runs `git upload-pack` of the git under test with
   `GIT_PROTOCOL=version=2` (rgit #68).
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
| `bitmap list-commits` | 20 | 5 | - | - | B |  | reads bitmaps |
| `bitmap write` | 8 | 2 | - | - | B |  | reads bitmaps |
| `bitmap dump-pseudo-merge-commits` | 3 | 1 | - | - | B |  | reads bitmaps |
| `bitmap dump-pseudo-merges` | 3 | 1 | - | - | B |  | reads bitmaps |
| `bitmap dump-hashes` | 2 | 1 | - | - | B |  | reads bitmaps |
| `bitmap dump-pseudo-merge-objects` | 1 | 1 | - | - | B |  | reads bitmaps |
| `bitmap list-commits-with-offset` | 1 | 1 | - | - | B |  | reads bitmaps |
| `bloom` | 11 | 1 | - | - | C | #22 | changed-path Bloom filters (t0095) |
| `bundle-uri parse-config` | 8 | 1 | - | - | C |  | bundle-uri parsing |
| `bundle-uri parse-key-values` | 6 | 1 | - | - | C |  | bundle-uri parsing |
| `bundle-uri ls-remote` | 0 | 0 | lib-bundle-uri-protocol.sh | - | C |  | bundle-uri parsing |
| `cache-entry` | 2 | 1 | - | - | C |  | cache entry allocation limits of the index API (t1600) |
| `chmtime` | 192 | 40 | - | M2 | A |  | file mtimes |
| `config read_early_config` | 8 | 2 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config configset_get_value` | 6 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get` | 5 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config` | 3 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config configset_get_value_multi` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get_string` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config get_value` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `config iterate` | 1 | 1 | - | M1 | C | #28 | config reader API (t1305, t1308, t1309) |
| `crontab` | 5 | 1 | - | - | A |  | fake crontab |
| `date getnanos` | 18 | 1 | - | - | C | #74 | date parsing/formatting (t0006) |
| `date show:<format>` | 4 | 2 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date timestamp` | 4 | 2 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date approxidate` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date human` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date parse` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `date relative` | 1 | 1 | - | M1 | C | #74 | date parsing/formatting (t0006) |
| `delta` | 9 | 1 | - | M1 | C | #17 | delta application (t5303) |
| `dump-cache-tree` | 3 | 2 | - | M2 | B |  | reads the index cache-tree extension |
| `dump-fsmonitor` | 5 | 1 | - | - | B |  | reads the fsmonitor extension |
| `dump-reftable` | 8 | 1 | - | - | B |  | reads reftable files |
| `dump-split-index` | 26 | 2 | - | M2 | B |  | reads split index |
| `dump-untracked-cache` | 38 | 2 | - | M2 | B |  | reads the untracked-cache extension |
| `env-helper` | 14 | 2 | lib-git-daemon.sh, lib-httpd.sh | M1, M2 | A |  | reads an environment variable as bool/ulong |
| `find-pack` | 27 | 1 | - | - | B |  | finds the pack that holds an object |
| `fsmonitor-client` | 9 | 1 | - | - | B |  | queries the fsmonitor daemon of the git under test over its IPC socket (t7527) |
| `genrandom` | 71 | 31 | - | M1, M2 | A |  | deterministic pseudo-random bytes |
| `genzeros` | 19 | 11 | - | M1, M2 | A |  | zero bytes |
| `getcwd` | 1 | 1 | - | M1 | A |  | prints the working directory |
| `hexdump` | 5 | 2 | lib-unicode-nfc-nfd.sh | - | A |  | hex dump of stdin |
| `mktemp` | 2 | 1 | - | - | C |  | git's mktemp wrapper and its error messages (t0070); library internals, likely excluded for rgit |
| `name-hash` | 1 | 1 | - | - | C |  | pack name hashes, versions 1 and 2 (t5310) |
| `online-cpus` | 3 | 1 | - | - | A |  | expected value: number of CPUs that hook.jobs=-1 resolves to (t1800) |
| `pack-deltas` | 1 | 1 | - | M2 | B |  | writes a crafted pack (fixture) that rgit must read |
| `pack-mtimes` | 28 | 2 | - | - | B |  | reads .mtimes |
| `parse-options` | 61 | 1 | - | M1 | C | #73 | option parser (t0040) |
| `parse-options-flags` | 7 | 1 | - | M1 | C | #73 | option parser flags (t0040) |
| `parse-pathspec-file` | 8 | 1 | - | M2 | C | #106 | --pathspec-from-file parsing (t0067) |
| `parse-subcommand` | 22 | 1 | - | M1 | C | #73 | subcommand parser (t0040) |
| `partial-clone` | 1 | 1 | - | - | C |  | object lookup with lazy fetch in a repository other than the main one (t0410) |
| `path-utils file-size` | 35 | 11 | - | M1, M2 | A |  | file size |
| `path-utils real_path` | 27 | 6 | - | M1, M2 | A |  | expected path for comparisons |
| `path-utils normalize_path_copy` | 6 | 2 | - | M2 | A |  | expected path for comparisons (t0007); t0060 itself would be C |
| `path-utils readlink` | 5 | 2 | - | M1 | A |  | symlink target |
| `path-utils absolute_path` | 4 | 2 | - | M1 | A |  | expected path for comparisons |
| `path-utils prefix_path` | 4 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils print_path` | 3 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils basename` | 1 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils dirname` | 1 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils is_dotgitattributes` | 1 | 1 | - | - | C |  | .gitattributes name variants, NTFS and HFS+ (t0060) |
| `path-utils is_dotgitignore` | 1 | 1 | - | - | C |  | .gitignore name variants, NTFS and HFS+ (t0060) |
| `path-utils is_dotgitmodules` | 1 | 1 | - | - | C |  | .gitmodules name variants, NTFS and HFS+ (t0060) |
| `path-utils is_dotmailmap` | 1 | 1 | - | - | C |  | .mailmap name variants, NTFS and HFS+ (t0060) |
| `path-utils is_valid_path` | 1 | 1 | - | - | C |  | path validation (t0060) |
| `path-utils longest_ancestor_length` | 1 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils relative_path` | 1 | 1 | - | - | C |  | path functions (t0060) |
| `path-utils strip_path_suffix` | 1 | 1 | - | - | C |  | path functions (t0060) |
| `pcre2-config` | 1 | 1 | - | - | A |  | prerequisite probe of the PCRE2 library (t7812) |
| `pkt-line pack` | 56 | 8 | - | M1, M2 | B |  | encodes request input; the git under test decodes it |
| `pkt-line unpack` | 30 | 6 | - | M2 | B |  | decodes the output of the git under test |
| `pkt-line send-split-sideband` | 5 | 1 | - | - | C | #60 | sideband actions (send-split-sideband, receive-sideband, unpack-sideband) |
| `pkt-line unpack-sideband` | 5 | 2 | - | - | C | #60 | sideband actions (send-split-sideband, receive-sideband, unpack-sideband) |
| `pkt-line pack-raw-stdin` | 3 | 3 | - | - | B |  | encodes request input; the git under test decodes it |
| `pkt-line receive-sideband` | 3 | 1 | - | - | C | #60 | sideband actions (send-split-sideband, receive-sideband, unpack-sideband) |
| `progress` | 16 | 1 | - | - | C |  | progress display |
| `reach` | 1 | 1 | - | M2 | C | #50 | reachability queries (t6600) |
| `read-cache` | 1 | 1 | - | - | B |  | reads the index |
| `read-graph` | 9 | 2 | lib-commit-graph.sh | - | B |  | reads commit-graph |
| `read-midx` | 33 | 6 | lib-bitmap.sh, lib-midx.sh | - | B |  | reads multi-pack-index |
| `ref-store delete-refs` | 33 | 6 | - | M1, M2 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store for-each-reflog-ent` | 30 | 8 | - | M1, M2 | C | #30 | reflog reader |
| `ref-store update-ref` | 25 | 9 | - | M1, M2 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store create-symref` | 16 | 5 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store reflog-exists` | 9 | 3 | - | M1, M2 | C | #30 | reflog reader |
| `ref-store for-each-reflog` | 6 | 4 | - | M1 | C | #30 | reflog reader |
| `ref-store delete-reflog` | 5 | 3 | - | M1, M2 | C | #30 | reflog writer |
| `ref-store for-each-ref` | 4 | 2 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store create-reflog` | 3 | 3 | - | M1, M2 | C | #30 | reflog writer |
| `ref-store for-each-reflog-ent-reverse` | 2 | 2 | - | M1 | C | #30 | reflog reader |
| `ref-store resolve-ref` | 2 | 2 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store delete-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store rename-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `ref-store verify-ref` | 1 | 1 | - | M1 | C | #29 | ref backend API (t1405, t1430, t0600, t1400, t3800); reflog actions #30 |
| `regex` | 5 | 4 | - | - | A |  | prerequisite probe of the platform regex/locale (t4210, t7810, t7812); `--bug` in t0070 checks the reference build's regex compat |
| `repository` | 4 | 1 | - | - | C |  | repository API: commit and tree lookup through the commit-graph (t5318) |
| `revision-walking` | 2 | 2 | - | - | C |  | revision walk API: run-twice (t0062), line-log-peek (t4211) |
| `rot13-filter` | 19 | 3 | - | - | A |  | clean/smudge filter process |
| `scrap-cache-tree` | 4 | 1 | - | M2 | B |  | rewrites the index without cache-tree; rgit must read the result |
| `serve-v2` | 45 | 3 | - | M1, M2 | C | #68 | protocol v2 server (t5701, t5702, t5703); substitute runs `git upload-pack` of the git under test |
| `sha1` | 1 | 1 | - | M1 | C | #11 | collision-detecting SHA-1 (t0013) |
| `sha1-is-sha1dc` | 1 | 1 | - | M1 | C | #11 | prerequisite: SHA-1 is collision detecting |
| `sha1/sha256 (via $algo)` | 0 | 0 | lib-loose.sh, lib-pack.sh | - | A |  | hash of stdin, used by lib-loose.sh/lib-pack.sh to craft objects |
| `sigchain` | 3 | 2 | - | M1 | C | #98 | signal handler chain (t0005); library internals, likely excluded for rgit |
| `submodule is-active` | 17 | 1 | - | - | C |  | submodule activity rules (t7413) |
| `submodule config-list` | 6 | 1 | - | - | C |  | .gitmodules config reader (t7411) |
| `submodule config-writeable` | 4 | 1 | - | - | C |  | whether .gitmodules may be written (t7411) |
| `submodule config-set` | 3 | 1 | - | - | C |  | .gitmodules config writer (t7411) |
| `submodule check-name` | 1 | 1 | - | - | C |  | submodule name validation (t7450) |
| `submodule check-url` | 1 | 1 | - | - | C |  | submodule URL validation (t7450) |
| `submodule config-unset` | 1 | 1 | - | - | C |  | .gitmodules config writer (t7411) |
| `submodule resolve-relative-url` | 1 | 1 | - | - | C |  | submodule API |
| `submodule-config` | 8 | 1 | - | - | C |  | .gitmodules parsing |
| `submodule-nested-repo-config` | 2 | 1 | - | - | C |  | .gitmodules parsing of a nested repository (t7411) |
| `subprocess` | 1 | 1 | - | M1 | C | #26 | repository setup before running a command (t1501) |
| `synthesize` | 1 | 1 | - | - | B |  | writes a synthetic >4GB pack (fixture) that rgit must index and clone (t5608) |
| `trace2 001return` | 13 | 3 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 004child` | 5 | 3 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 003error` | 4 | 3 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 400ancestry` | 4 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 002exit` | 2 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 006data` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 007bug` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 008bug` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 009bug_BUG` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 010bug_BUG` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 100timer` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 101timer` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 200counter` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 201counter` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 300redact_start` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 301redact_child_start` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 302redact_exec` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `trace2 303redact_def_param` | 1 | 1 | - | - | C | #695 | trace2 API (t0210, t0211, t0212, t0213) |
| `truncate` | 4 | 2 | - | M2 | A |  | truncates a file |
| `userdiff` | 3 | 1 | - | - | C |  | userdiff drivers |
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
| t0003-attributes.sh | imported | - |
| t0004-unwritable.sh | M1 #98, M2 #123 | - |
| t0005-signals.sh | M1 #98 | `genrandom` 1, `sigchain` 2 |
| t0006-date.sh | M1 #6, M1 #74 | `date approxidate` 1, `date human` 1, `date parse` 1, `date relative` 1, `date show:<format>` 1 |
| t0007-git-var.sh | M2 #122 | `path-utils normalize_path_copy` 4 |
| t0008-ignores.sh | M2 #37 | - |
| t0009-git-dir-validation.sh | M1 #26 | - |
| t0010-racy-git.sh | M2 #36 | - |
| t0012-help.sh | M1 #73 | - |
| t0013-sha1dc.sh | M1 #6, M1 #11 | `sha1` 1, `sha1-is-sha1dc` 1 |
| t0014-alias.sh | imported | - |
| t0018-advice.sh | M2 #178 | `advise` 3 |
| t0020-crlf.sh | imported | - |
| t0021-conversion.sh | imported | `genrandom` 2, `path-utils file-size` 16, `rot13-filter` 17 |
| t0022-crlf-rename.sh | imported | - |
| t0023-crlf-am.sh | imported | - |
| t0024-crlf-archive.sh | imported | - |
| t0025-crlf-renormalize.sh | imported | - |
| t0026-eol-config.sh | imported | - |
| t0027-auto-crlf.sh | imported | - |
| t0028-working-tree-encoding.sh | imported | - |
| t0030-stripspace.sh | imported | - |
| t0031-lockfile-pid.sh | M1 #98 | - |
| t0033-safe-directory.sh | M1 #26 | - |
| t0034-root-safe-directory.sh | M1 #26 | - |
| t0035-safe-bare-repository.sh | M1 #26 | - |
| t0040-parse-options.sh | M1 #6, M1 #73 | `parse-options` 61, `parse-options-flags` 7, `parse-subcommand` 22 |
| t0050-filesystem.sh | imported | - |
| t0055-beyond-symlinks.sh | M2 #39 | - |
| t0056-git-C.sh | M1 #73 | - |
| t0060-path-utils.sh | imported | `path-utils absolute_path` 2, `path-utils basename` 1, `path-utils dirname` 1, `path-utils is_dotgitattributes` 1, `path-utils is_dotgitignore` 1, `path-utils is_dotgitmodules` 1, `path-utils is_dotmailmap` 1, `path-utils is_valid_path` 1, `path-utils longest_ancestor_length` 1, `path-utils normalize_path_copy` 2, `path-utils prefix_path` 4, `path-utils print_path` 3, `path-utils real_path` 15, `path-utils relative_path` 1, `path-utils strip_path_suffix` 1, `submodule resolve-relative-url` 1 |
| t0062-revision-walking.sh | imported | `revision-walking` 1 |
| t0067-parse_pathspec_file.sh | M2 #106 | `parse-pathspec-file` 8 |
| t0068-for-each-repo.sh | imported | - |
| t0070-fundamental.sh | imported | `mktemp` 2, `pkt-line receive-sideband` 3, `pkt-line send-split-sideband` 5, `pkt-line unpack-sideband` 4, `regex` 1 |
| t0090-cache-tree.sh | M2 #79, M2 #123 | `dump-cache-tree` 2, `dump-split-index` 2, `scrap-cache-tree` 4 |
| t0091-bugreport.sh | imported | - |
| t0092-diagnose.sh | imported | - |
| t0095-bloom.sh | imported | `bloom` 11 |
| t0100-previous.sh | M2 #30 | - |
| t0101-at-syntax.sh | imported | - |
| t0210-trace2-normal.sh | imported | `trace2 001return` 5, `trace2 002exit` 2, `trace2 003error` 1, `trace2 007bug` 1, `trace2 008bug` 1, `trace2 009bug_BUG` 1, `trace2 010bug_BUG` 1 |
| t0211-trace2-perf.sh | imported | `trace2 001return` 5, `trace2 003error` 1, `trace2 004child` 3, `trace2 100timer` 1, `trace2 101timer` 1, `trace2 200counter` 1, `trace2 201counter` 1 |
| t0212-trace2-event.sh | imported | `trace2 001return` 3, `trace2 003error` 2, `trace2 004child` 1, `trace2 006data` 1, `trace2 300redact_start` 1, `trace2 301redact_child_start` 1, `trace2 302redact_exec` 1, `trace2 303redact_def_param` 1 |
| t0213-trace2-ancestry.sh | imported | `trace2 004child` 1, `trace2 400ancestry` 4 |
| t0300-credentials.sh | M2 #161 | - |
| t0301-credential-cache.sh | imported | - |
| t0302-credential-store.sh | imported | - |
| t0303-credential-external.sh | M2 #161 | - |
| t0410-partial-clone.sh | imported | `partial-clone` 1 |
| t0411-clone-from-partial.sh | imported | - |
| t0450-txt-doc-vs-help.sh | M1 #73 | - |
| t0500-progress-display.sh | imported | `progress` 16 |
| t0600-reffiles-backend.sh | M1 #29 | `path-utils readlink` 2, `ref-store create-symref` 1, `ref-store for-each-reflog` 2 |
| t0601-reffiles-pack-refs.sh | imported | - |
| t0602-reffiles-fsck.sh | imported | - |
| t0610-reftable-basics.sh | imported | `ref-store create-reflog` 1, `ref-store delete-reflog` 1, `ref-store delete-refs` 1, `ref-store for-each-ref` 2, `ref-store for-each-reflog-ent-reverse` 1, `ref-store reflog-exists` 5, `ref-store update-ref` 4, `truncate` 1 |
| t0611-reftable-httpd.sh | imported | - |
| t0613-reftable-write-options.sh | imported | `dump-reftable` 8, `genzeros` 1 |
| t0614-reftable-fsck.sh | imported | - |
| t1000-read-tree-m-3way.sh | imported | - |
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
| t1011-read-tree-sparse-checkout.sh | imported | - |
| t1012-read-tree-df.sh | M2 #107 | - |
| t1013-read-tree-submodule.sh | imported | - |
| t1014-read-tree-confusing.sh | M2 #107 | - |
| t1015-read-index-unmerged.sh | imported | - |
| t1017-cat-file-remote-object-info.sh | M1 #15 | - |
| t1050-large.sh | imported | `genrandom` 3, `path-utils file-size` 1 |
| t1051-large-conversion.sh | imported | `genzeros` 2, `path-utils file-size` 3 |
| t1060-object-corruption.sh | M1 #14 | - |
| t1090-sparse-checkout-scope.sh | imported | - |
| t1091-sparse-checkout-builtin.sh | imported | - |
| t1092-sparse-checkout-compatibility.sh | imported | - |
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
| t1350-config-hooks-path.sh | imported | - |
| t1400-update-ref.sh | M1 #29, M2 #30 | `ref-store delete-reflog` 3, `ref-store delete-refs` 2, `ref-store for-each-reflog-ent` 18 |
| t1401-symbolic-ref.sh | M1 #29 | - |
| t1402-check-ref-format.sh | M1 #29 | - |
| t1403-show-ref.sh | M1 #29 | - |
| t1404-update-ref-errors.sh | M1 #29 | - |
| t1405-main-ref-store.sh | M1 #29 | `ref-store create-reflog` 1, `ref-store create-symref` 1, `ref-store delete-ref` 1, `ref-store delete-reflog` 1, `ref-store delete-refs` 1, `ref-store for-each-ref` 2, `ref-store for-each-reflog` 1, `ref-store for-each-reflog-ent` 1, `ref-store for-each-reflog-ent-reverse` 1, `ref-store reflog-exists` 1, `ref-store rename-ref` 1, `ref-store resolve-ref` 1, `ref-store update-ref` 1, `ref-store verify-ref` 1 |
| t1408-packed-refs.sh | M1 #29 | - |
| t1409-avoid-packing-refs.sh | imported | - |
| t1410-reflog.sh | M2 #30 | `ref-store create-reflog` 1, `ref-store for-each-reflog-ent` 4, `ref-store reflog-exists` 3, `ref-store update-ref` 1 |
| t1411-reflog-show.sh | M2 #30 | - |
| t1412-reflog-loop.sh | imported | - |
| t1413-reflog-detach.sh | M2 #30 | - |
| t1414-reflog-walk.sh | imported | - |
| t1415-worktree-refs.sh | imported | - |
| t1416-ref-transaction-hooks.sh | imported | - |
| t1417-reflog-updateref.sh | imported | - |
| t1418-reflog-exists.sh | M2 #30 | - |
| t1420-lost-found.sh | imported | - |
| t1421-reflog-write.sh | imported | `ref-store for-each-reflog-ent` 1 |
| t1422-show-ref-exists.sh | M1 #29 | - |
| t1423-ref-backend.sh | imported | - |
| t1430-bad-ref-name.sh | M1 #29 | `ref-store create-symref` 12, `ref-store delete-refs` 26, `ref-store update-ref` 12 |
| t1450-fsck.sh | imported | `genrandom` 6, `genzeros` 1, `ref-store create-symref` 1, `ref-store update-ref` 2 |
| t1451-fsck-buffer.sh | imported | - |
| t1460-refs-migrate.sh | imported | `ref-store for-each-reflog` 1, `ref-store for-each-reflog-ent` 1, `ref-store update-ref` 1 |
| t1461-refs-list.sh | imported | - |
| t1462-refs-exists.sh | imported | - |
| t1463-refs-optimize.sh | imported | - |
| t1464-refs-delete.sh | imported | `ref-store for-each-reflog-ent` 1 |
| t1465-refs-update.sh | imported | - |
| t1466-refs-create.sh | imported | - |
| t1467-refs-rename.sh | imported | - |
| t1500-rev-parse.sh | M1 #32 | - |
| t1501-work-tree.sh | M1 #26 | `path-utils real_path` 4, `subprocess` 1 |
| t1502-rev-parse-parseopt.sh | imported | - |
| t1503-rev-parse-verify.sh | M1 #32 | - |
| t1504-ceiling-dirs.sh | M1 #26 | - |
| t1505-rev-parse-last.sh | imported | - |
| t1506-rev-parse-diagnosis.sh | M1 #32 | - |
| t1507-rev-parse-upstream.sh | imported | - |
| t1508-at-combinations.sh | imported | - |
| t1509-root-work-tree.sh | M1 #26 | - |
| t1510-repo-setup.sh | M1 #26, M1 #177 | - |
| t1511-rev-parse-caret.sh | M1 #32 | - |
| t1512-rev-parse-disambiguation.sh | imported | - |
| t1513-rev-parse-prefix.sh | M1 #32 | - |
| t1514-rev-parse-push.sh | imported | - |
| t1515-rev-parse-outside-repo.sh | M1 #26 | - |
| t1517-outside-repo.sh | M1 #26 | - |
| t1600-index.sh | imported | `cache-entry` 2, `genzeros` 2, `hexdump` 4 |
| t1601-index-bogus.sh | M2 #79 | - |
| t1700-split-index.sh | imported | `chmtime` 7, `dump-cache-tree` 1, `dump-split-index` 24 |
| t1701-racy-split-index.sh | imported | `chmtime` 1 |
| t1800-hook.sh | imported | `online-cpus` 3 |
| t1900-repo-info.sh | imported | `path-utils real_path` 2 |
| t1901-repo-structure.sh | imported | - |
| t2000-conflict-when-checking-files-out.sh | M2 #107 | - |
| t2002-checkout-cache-u.sh | M2 #107 | - |
| t2003-checkout-cache-mkdir.sh | M2 #107 | - |
| t2004-checkout-cache-temp.sh | M2 #107 | - |
| t2005-checkout-index-symlinks.sh | M2 #107 | - |
| t2006-checkout-index-basic.sh | M2 #107 | - |
| t2007-checkout-symlink.sh | imported | - |
| t2008-checkout-subdir.sh | imported | - |
| t2009-checkout-statinfo.sh | imported | - |
| t2010-checkout-ambiguous.sh | M2 #42 | - |
| t2011-checkout-invalid-head.sh | M2 #42 | - |
| t2012-checkout-last.sh | M2 #42 | - |
| t2013-checkout-submodule.sh | imported | - |
| t2014-checkout-switch.sh | M2 #42 | - |
| t2015-checkout-unborn.sh | M2 #42 | - |
| t2016-checkout-patch.sh | imported | - |
| t2017-checkout-orphan.sh | M2 #42 | - |
| t2018-checkout-branch.sh | M2 #42 | - |
| t2019-checkout-ambiguous-ref.sh | M2 #42 | - |
| t2020-checkout-detach.sh | M2 #42 | - |
| t2021-checkout-overwrite.sh | M2 #42 | - |
| t2022-checkout-paths.sh | imported | `chmtime` 2 |
| t2023-checkout-m.sh | imported | - |
| t2024-checkout-dwim.sh | M2 #42 | - |
| t2025-checkout-no-overlay.sh | imported | - |
| t2026-checkout-pathspec-file.sh | imported | - |
| t2027-checkout-track.sh | M2 #42 | - |
| t2030-unresolve-info.sh | imported | - |
| t2060-switch.sh | M2 #42 | - |
| t2070-restore.sh | imported | - |
| t2071-restore-patch.sh | imported | - |
| t2072-restore-pathspec-file.sh | imported | - |
| t2080-parallel-checkout-basics.sh | imported | `rot13-filter` 1 |
| t2081-parallel-checkout-collisions.sh | imported | - |
| t2082-parallel-checkout-attributes.sh | imported | `rot13-filter` 1 |
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
| t2206-add-submodule-ignored.sh | imported | - |
| t2400-worktree-add.sh | imported | - |
| t2401-worktree-prune.sh | imported | - |
| t2402-worktree-list.sh | imported | `ref-store create-symref` 1 |
| t2403-worktree-move.sh | imported | - |
| t2404-worktree-config.sh | imported | - |
| t2405-worktree-submodule.sh | imported | - |
| t2406-worktree-repair.sh | imported | - |
| t2407-worktree-heads.sh | imported | - |
| t2500-untracked-overwriting.sh | M2 #42 | - |
| t3000-ls-files-others.sh | M2 #37 | - |
| t3001-ls-files-others-exclude.sh | M2 #37 | - |
| t3002-ls-files-dashpath.sh | M2 #39 | - |
| t3003-ls-files-exclude.sh | M2 #37 | - |
| t3004-ls-files-basic.sh | M2 #39 | - |
| t3005-ls-files-relative.sh | M2 #39 | - |
| t3006-ls-files-long.sh | M2 #39 | - |
| t3007-ls-files-recurse-submodules.sh | imported | - |
| t3009-ls-files-others-nonsubmodule.sh | M2 #37 | - |
| t3010-ls-files-killed-modified.sh | M2 #39 | - |
| t3011-common-prefixes-and-directory-traversal.sh | M2 #37 | - |
| t3012-ls-files-dedup.sh | M2 #39 | - |
| t3013-ls-files-format.sh | M2 #39 | - |
| t3020-ls-files-error-unmatch.sh | M2 #39 | - |
| t3040-subprojects-basic.sh | imported | - |
| t3060-ls-files-with-tree.sh | M2 #39 | - |
| t3070-wildmatch.sh | M2 #106 | `wildmatch` 3 |
| t3100-ls-tree-restrict.sh | M1 #88 | - |
| t3101-ls-tree-dirname.sh | M1 #88 | - |
| t3102-ls-tree-wildcards.sh | M1 #88 | - |
| t3103-ls-tree-misc.sh | M1 #88 | - |
| t3104-ls-tree-format.sh | M1 #88 | - |
| t3105-ls-tree-output.sh | M1 #88 | - |
| t3200-branch.sh | M2 #48 | - |
| t3201-branch-contains.sh | imported | - |
| t3202-show-branch.sh | imported | - |
| t3203-branch-output.sh | imported | - |
| t3204-branch-name-interpretation.sh | M2 #48 | - |
| t3205-branch-color.sh | imported | - |
| t3206-range-diff.sh | imported | - |
| t3207-branch-submodule.sh | imported | - |
| t3211-peel-ref.sh | M1 #29 | - |
| t3301-notes.sh | imported | - |
| t3303-notes-subtrees.sh | imported | - |
| t3304-notes-mixed.sh | imported | - |
| t3305-notes-fanout.sh | imported | - |
| t3306-notes-prune.sh | imported | `chmtime` 1 |
| t3307-notes-man.sh | imported | - |
| t3308-notes-merge.sh | imported | - |
| t3309-notes-merge-auto-resolve.sh | imported | - |
| t3310-notes-merge-manual-resolve.sh | imported | - |
| t3311-notes-merge-fanout.sh | imported | - |
| t3320-notes-merge-worktrees.sh | imported | - |
| t3321-notes-stripspace.sh | imported | - |
| t3400-rebase.sh | imported | - |
| t3401-rebase-and-am-rename.sh | imported | - |
| t3402-rebase-merge.sh | imported | - |
| t3403-rebase-skip.sh | imported | - |
| t3404-rebase-interactive.sh | imported | `chmtime` 2 |
| t3405-rebase-malformed.sh | imported | - |
| t3406-rebase-message.sh | imported | - |
| t3407-rebase-abort.sh | imported | - |
| t3408-rebase-multi-line.sh | imported | - |
| t3409-rebase-environ.sh | imported | - |
| t3412-rebase-root.sh | imported | - |
| t3413-rebase-hook.sh | imported | - |
| t3415-rebase-autosquash.sh | imported | - |
| t3416-rebase-onto-threedots.sh | imported | - |
| t3417-rebase-whitespace-fix.sh | imported | - |
| t3418-rebase-continue.sh | imported | `chmtime` 2 |
| t3419-rebase-patch-id.sh | imported | - |
| t3420-rebase-autostash.sh | imported | - |
| t3421-rebase-topology-linear.sh | imported | - |
| t3422-rebase-incompatible-options.sh | imported | - |
| t3423-rebase-reword.sh | imported | - |
| t3424-rebase-empty.sh | imported | - |
| t3425-rebase-topology-merges.sh | imported | - |
| t3426-rebase-submodule.sh | imported | - |
| t3427-rebase-subtree.sh | imported | - |
| t3428-rebase-signoff.sh | imported | - |
| t3429-rebase-edit-todo.sh | imported | - |
| t3430-rebase-merges.sh | imported | - |
| t3431-rebase-fork-point.sh | imported | - |
| t3432-rebase-fast-forward.sh | imported | - |
| t3433-rebase-across-mode-change.sh | imported | - |
| t3434-rebase-i18n.sh | imported | - |
| t3436-rebase-more-options.sh | imported | - |
| t3437-rebase-fixup-options.sh | imported | - |
| t3438-rebase-broken-files.sh | imported | - |
| t3440-rebase-trailer.sh | imported | - |
| t3450-history.sh | imported | - |
| t3451-history-reword.sh | imported | - |
| t3452-history-split.sh | imported | - |
| t3453-history-fixup.sh | imported | - |
| t3454-history-drop.sh | imported | - |
| t3500-cherry.sh | imported | - |
| t3501-revert-cherry-pick.sh | imported | `chmtime` 1 |
| t3502-cherry-pick-merge.sh | imported | - |
| t3503-cherry-pick-root.sh | imported | - |
| t3504-cherry-pick-rerere.sh | imported | - |
| t3505-cherry-pick-empty.sh | imported | - |
| t3506-cherry-pick-ff.sh | imported | - |
| t3507-cherry-pick-conflict.sh | imported | - |
| t3508-cherry-pick-many-commits.sh | imported | - |
| t3509-cherry-pick-merge-df.sh | imported | - |
| t3510-cherry-pick-sequence.sh | imported | `chmtime` 2 |
| t3511-cherry-pick-x.sh | imported | - |
| t3512-cherry-pick-submodule.sh | imported | - |
| t3513-revert-submodule.sh | imported | - |
| t3514-cherry-pick-revert-gpg.sh | imported | - |
| t3600-rm.sh | M2 #41 | `chmtime` 1 |
| t3601-rm-pathspec-file.sh | M2 #41 | - |
| t3602-rm-sparse-checkout.sh | imported | - |
| t3650-replay-basics.sh | imported | - |
| t3700-add.sh | M2 #41 | `chmtime` 1 |
| t3701-add-interactive.sh | imported | - |
| t3702-add-edit.sh | imported | - |
| t3703-add-magic-pathspec.sh | M2 #106 | - |
| t3704-add-pathspec-file.sh | M2 #106 | - |
| t3705-add-sparse-checkout.sh | imported | `chmtime` 1 |
| t3800-mktag.sh | M1 #15 | `ref-store delete-refs` 2, `ref-store update-ref` 2 |
| t3900-i18n-commit.sh | imported | - |
| t3901-i18n-patch.sh | imported | - |
| t3902-quoted.sh | M2 #39 | - |
| t3903-stash.sh | imported | `chmtime` 2, `path-utils readlink` 3 |
| t3904-stash-patch.sh | imported | - |
| t3905-stash-include-untracked.sh | imported | - |
| t3906-stash-submodule.sh | imported | - |
| t3907-stash-show-config.sh | imported | - |
| t3908-stash-in-worktree.sh | imported | - |
| t3909-stash-pathspec-file.sh | imported | - |
| t3910-mac-os-precompose.sh | imported | - |
| t4000-diff-format.sh | M2 #144 | - |
| t4001-diff-rename.sh | imported | - |
| t4002-diff-basic.sh | M2 #144 | - |
| t4003-diff-rename-1.sh | imported | - |
| t4004-diff-rename-symlink.sh | imported | - |
| t4005-diff-rename-2.sh | imported | - |
| t4006-diff-mode.sh | M2 #82 | - |
| t4007-rename-3.sh | imported | - |
| t4008-diff-break-rewrite.sh | imported | - |
| t4009-diff-rename-4.sh | imported | - |
| t4010-diff-pathspec.sh | M2 #144 | - |
| t4011-diff-symlink.sh | M2 #82 | `chmtime` 1 |
| t4012-diff-binary.sh | M2 #82 | - |
| t4013-diff-various.sh | M2 #82 | `chmtime` 1 |
| t4014-format-patch.sh | imported | - |
| t4015-diff-whitespace.sh | imported | - |
| t4016-diff-quote.sh | M2 #82 | - |
| t4017-diff-retval.sh | M2 #144 | - |
| t4018-diff-funcname.sh | imported | `userdiff` 3 |
| t4019-diff-wserror.sh | imported | - |
| t4020-diff-external.sh | imported | - |
| t4021-format-patch-numbered.sh | imported | - |
| t4022-diff-rewrite.sh | imported | - |
| t4023-diff-rename-typechange.sh | imported | - |
| t4024-diff-optimize-common.sh | M2 #82 | - |
| t4025-hunk-header.sh | M2 #82 | - |
| t4026-color.sh | imported | - |
| t4027-diff-submodule.sh | imported | - |
| t4028-format-patch-mime-headers.sh | imported | - |
| t4029-diff-trailing-space.sh | imported | - |
| t4030-diff-textconv.sh | imported | - |
| t4031-diff-rewrite-binary.sh | imported | `hexdump` 1 |
| t4032-diff-inter-hunk-context.sh | imported | - |
| t4033-diff-patience.sh | imported | - |
| t4034-diff-words.sh | imported | - |
| t4035-diff-quiet.sh | M2 #144 | `chmtime` 1 |
| t4036-format-patch-signer-mime.sh | imported | - |
| t4037-diff-r-t-dirs.sh | M2 #144 | - |
| t4038-diff-combined.sh | imported | - |
| t4039-diff-assume-unchanged.sh | M2 #144 | - |
| t4040-whitespace-status.sh | imported | - |
| t4041-diff-submodule-option.sh | imported | - |
| t4042-diff-textconv-caching.sh | imported | - |
| t4043-diff-rename-binary.sh | imported | - |
| t4044-diff-index-unique-abbrev.sh | M2 #144 | - |
| t4045-diff-relative.sh | imported | - |
| t4046-diff-unmerged.sh | M2 #144 | - |
| t4047-diff-dirstat.sh | imported | - |
| t4048-diff-combined-binary.sh | imported | - |
| t4049-diff-stat-count.sh | imported | - |
| t4050-diff-histogram.sh | imported | - |
| t4051-diff-function-context.sh | imported | - |
| t4052-stat-output.sh | imported | - |
| t4053-diff-no-index.sh | imported | - |
| t4054-diff-bogus-tree.sh | M2 #144 | - |
| t4055-diff-context.sh | imported | - |
| t4056-diff-order.sh | imported | - |
| t4057-diff-combined-paths.sh | imported | - |
| t4058-diff-duplicates.sh | imported | - |
| t4059-diff-submodule-not-initialized.sh | imported | - |
| t4060-diff-submodule-option-diff-format.sh | imported | - |
| t4061-diff-indent.sh | M2 #82 | - |
| t4062-diff-pickaxe.sh | imported | - |
| t4063-diff-blobs.sh | M2 #144 | - |
| t4064-diff-oidfind.sh | imported | - |
| t4065-diff-anchored.sh | imported | - |
| t4066-diff-emit-delay.sh | imported | - |
| t4067-diff-partial-clone.sh | imported | - |
| t4068-diff-symmetric-merge-base.sh | M2 #144 | - |
| t4069-remerge-diff.sh | imported | - |
| t4070-diff-pairs.sh | imported | - |
| t4071-diff-minimal.sh | imported | - |
| t4072-diff-max-depth.sh | imported | - |
| t4073-diff-stat-name-width.sh | imported | - |
| t4074-diff-shifted-matched-group.sh | M2 #82 | - |
| t4100-apply-stat.sh | imported | - |
| t4101-apply-nonl.sh | imported | - |
| t4102-apply-rename.sh | imported | - |
| t4103-apply-binary.sh | imported | `genrandom` 1 |
| t4104-apply-boundary.sh | imported | - |
| t4105-apply-fuzz.sh | imported | - |
| t4106-apply-stdin.sh | imported | - |
| t4107-apply-ignore-whitespace.sh | imported | - |
| t4108-apply-threeway.sh | imported | - |
| t4109-apply-multifrag.sh | imported | - |
| t4110-apply-scan.sh | imported | - |
| t4111-apply-subdir.sh | imported | - |
| t4112-apply-renames.sh | imported | - |
| t4113-apply-ending.sh | imported | - |
| t4114-apply-typechange.sh | imported | - |
| t4115-apply-symlink.sh | imported | - |
| t4116-apply-reverse.sh | imported | - |
| t4117-apply-reject.sh | imported | - |
| t4118-apply-empty-context.sh | imported | - |
| t4119-apply-config.sh | imported | - |
| t4120-apply-popt.sh | imported | - |
| t4121-apply-diffs.sh | imported | - |
| t4122-apply-symlink-inside.sh | imported | - |
| t4123-apply-shrink.sh | imported | - |
| t4124-apply-ws-rule.sh | imported | - |
| t4125-apply-ws-fuzz.sh | imported | - |
| t4126-apply-empty.sh | imported | - |
| t4127-apply-same-fn.sh | imported | - |
| t4128-apply-root.sh | imported | - |
| t4129-apply-samemode.sh | imported | - |
| t4130-apply-criss-cross-rename.sh | imported | - |
| t4131-apply-fake-ancestor.sh | imported | - |
| t4132-apply-removal.sh | imported | - |
| t4133-apply-filenames.sh | imported | - |
| t4135-apply-weird-filenames.sh | imported | - |
| t4136-apply-check.sh | imported | - |
| t4137-apply-submodule.sh | imported | - |
| t4138-apply-ws-expansion.sh | imported | - |
| t4139-apply-escape.sh | imported | - |
| t4140-apply-ita.sh | imported | - |
| t4141-apply-too-large.sh | imported | `genrandom` 2, `genzeros` 2 |
| t4150-am.sh | imported | - |
| t4151-am-abort.sh | imported | `chmtime` 2 |
| t4152-am-subjects.sh | imported | - |
| t4153-am-resume-override-opts.sh | imported | - |
| t4200-rerere.sh | imported | `chmtime` 11 |
| t4201-shortlog.sh | imported | - |
| t4202-log.sh | M1 #78 | - |
| t4203-mailmap.sh | imported | - |
| t4204-patch-id.sh | imported | - |
| t4205-log-pretty-formats.sh | imported | `genzeros` 1 |
| t4206-log-follow-harder-copies.sh | imported | - |
| t4207-log-decoration-colors.sh | imported | - |
| t4208-log-magic-pathspec.sh | imported | - |
| t4209-log-pickaxe.sh | imported | - |
| t4210-log-i18n.sh | imported | `regex` 1 |
| t4211-line-log.sh | imported | `revision-walking` 1 |
| t4214-log-graph-octopus.sh | imported | - |
| t4215-log-skewed-merges.sh | imported | - |
| t4216-log-bloom.sh | imported | `read-graph` 4 |
| t4217-log-limit.sh | imported | - |
| t4218-log-graph-indentation.sh | imported | - |
| t4219-log-follow-merge.sh | imported | - |
| t4252-am-options.sh | imported | - |
| t4253-am-keep-cr-dos.sh | imported | - |
| t4254-am-corrupt.sh | imported | - |
| t4255-am-submodule.sh | imported | - |
| t4256-am-format-flowed.sh | imported | - |
| t4257-am-interactive.sh | imported | - |
| t4258-am-quoted-cr.sh | imported | - |
| t4300-merge-tree.sh | imported | - |
| t4301-merge-tree-write-tree.sh | imported | - |
| t5000-tar-tree.sh | imported | `chmtime` 1, `genrandom` 1 |
| t5001-archive-attr.sh | imported | - |
| t5002-archive-attr-pattern.sh | imported | - |
| t5003-archive-zip.sh | imported | `genrandom` 1 |
| t5004-archive-corner-cases.sh | imported | - |
| t5100-mailinfo.sh | imported | - |
| t5150-request-pull.sh | imported | - |
| t5200-update-server-info.sh | imported | `chmtime` 7 |
| t5300-pack-object.sh | M1 #17, M2 #18, M2 #80 | `genrandom` 2, `genzeros` 3, `path-utils file-size` 2 |
| t5301-sliding-window.sh | imported | `genrandom` 1 |
| t5302-pack-index.sh | M1 #17, M2 #18 | `genrandom` 7, `path-utils file-size` 1 |
| t5303-pack-corruption-resilience.sh | M1 #17 | `delta` 9, `genrandom` 5 |
| t5304-prune.sh | imported | `chmtime` 12 |
| t5305-include-tag.sh | imported | - |
| t5306-pack-nobase.sh | M2 #18 | - |
| t5307-pack-missing-commit.sh | imported | - |
| t5308-pack-detect-duplicates.sh | M2 #18 | - |
| t5309-pack-delta-cycles.sh | M2 #18 | `pack-deltas` 1 |
| t5310-pack-bitmaps.sh | imported | `bitmap list-commits` 6, `bitmap list-commits-with-offset` 1, `bitmap write` 2, `genrandom` 3, `name-hash` 1 |
| t5311-pack-bitmaps-shallow.sh | imported | - |
| t5312-prune-corruption.sh | imported | `ref-store delete-refs` 1, `ref-store update-ref` 1 |
| t5313-pack-bounds-checks.sh | M1 #17 | `genrandom` 2 |
| t5314-pack-cycle-detection.sh | imported | `genrandom` 1 |
| t5315-pack-objects-compression.sh | imported | `path-utils file-size` 1 |
| t5316-pack-delta-depth.sh | imported | `genrandom` 1 |
| t5317-pack-objects-filter-objects.sh | imported | - |
| t5318-commit-graph.sh | imported | `genzeros` 1, `repository` 4 |
| t5319-multi-pack-index.sh | imported | `bitmap list-commits` 3, `chmtime` 7, `genrandom` 8, `path-utils file-size` 4, `read-midx` 17 |
| t5320-delta-islands.sh | imported | `genrandom` 1 |
| t5321-pack-large-objects.sh | imported | - |
| t5322-pack-objects-sparse.sh | imported | - |
| t5323-pack-redundant.sh | imported | - |
| t5324-split-commit-graph.sh | imported | `chmtime` 2, `read-graph` 5 |
| t5325-reverse-index.sh | imported | - |
| t5326-multi-pack-bitmaps.sh | imported | `bitmap dump-hashes` 2, `bitmap list-commits` 7 |
| t5327-multi-pack-bitmaps-rev.sh | imported | - |
| t5328-commit-graph-64bit-time.sh | imported | - |
| t5329-pack-objects-cruft.sh | imported | `chmtime` 23, `genrandom` 2, `pack-mtimes` 14 |
| t5331-pack-objects-stdin.sh | imported | - |
| t5332-multi-pack-reuse.sh | imported | - |
| t5333-pseudo-merge-bitmaps.sh | imported | `bitmap dump-pseudo-merge-commits` 3, `bitmap dump-pseudo-merge-objects` 1, `bitmap dump-pseudo-merges` 3, `bitmap list-commits` 2, `bitmap write` 6 |
| t5334-incremental-multi-pack-index.sh | imported | `read-midx` 1 |
| t5335-compact-multi-pack-index.sh | imported | `read-midx` 7 |
| t5351-unpack-large-objects.sh | imported | `genrandom` 2 |
| t5400-send-pack.sh | imported | `chmtime` 1 |
| t5401-update-hooks.sh | imported | - |
| t5403-post-checkout-hook.sh | imported | - |
| t5404-tracking-branches.sh | M2 #65 | - |
| t5405-send-pack-rewind.sh | imported | - |
| t5406-remote-rejects.sh | M2 #65 | - |
| t5408-send-pack-stdin.sh | imported | - |
| t5409-colorize-remote-messages.sh | imported | - |
| t5410-receive-pack.sh | imported | `pkt-line unpack` 1 |
| t5411-proc-receive-hook.sh | M2 #60 | - |
| t5500-fetch-pack.sh | M2 #62 | `pkt-line pack` 1 |
| t5501-fetch-push-alternates.sh | imported | - |
| t5502-quickfetch.sh | M2 #62 | - |
| t5503-tagfollow.sh | M2 #62 | - |
| t5504-fetch-receive-strict.sh | imported | - |
| t5505-remote.sh | imported | `ref-store for-each-reflog` 2, `ref-store for-each-reflog-ent` 2 |
| t5506-remote-groups.sh | imported | - |
| t5507-remote-environment.sh | M2 #160 | - |
| t5509-fetch-push-namespaces.sh | imported | - |
| t5510-fetch.sh | M2 #62, M2 #66 | - |
| t5511-refspec.sh | M2 #159 | - |
| t5512-ls-remote.sh | M2 #63 | `pkt-line pack` 2 |
| t5513-fetch-track.sh | M2 #62 | - |
| t5514-fetch-multiple.sh | imported | - |
| t5515-fetch-merge-logic.sh | M2 #62 | - |
| t5516-fetch-push.sh | M2 #65, M2 #66 | `chmtime` 1 |
| t5517-push-mirror.sh | imported | - |
| t5518-fetch-exit-status.sh | M2 #62 | - |
| t5519-push-alternates.sh | imported | - |
| t5520-pull.sh | imported | - |
| t5521-pull-options.sh | imported | - |
| t5522-pull-symlink.sh | imported | - |
| t5523-push-upstream.sh | M2 #65 | - |
| t5524-pull-msg.sh | imported | - |
| t5525-fetch-tagopt.sh | M2 #62 | - |
| t5526-fetch-submodules.sh | imported | - |
| t5527-fetch-odd-refs.sh | M2 #62 | - |
| t5528-push-default.sh | M2 #65 | - |
| t5529-push-errors.sh | M2 #65 | - |
| t5530-upload-pack-error.sh | imported | `pkt-line pack` 5, `pkt-line unpack` 2 |
| t5531-deep-submodule-push.sh | imported | - |
| t5532-fetch-proxy.sh | imported | - |
| t5533-push-cas.sh | imported | - |
| t5534-push-signed.sh | imported | - |
| t5535-fetch-push-symref.sh | M2 #62 | - |
| t5536-fetch-conflicts.sh | M2 #62 | - |
| t5537-fetch-shallow.sh | imported | - |
| t5538-push-shallow.sh | imported | - |
| t5539-fetch-http-shallow.sh | imported | - |
| t5541-http-push-smart.sh | M2 #65, M2 #66, M2 #87, M2 #162 | - |
| t5542-push-http-shallow.sh | imported | - |
| t5543-atomic-push.sh | imported | - |
| t5544-pack-objects-hook.sh | imported | - |
| t5545-push-options.sh | imported | - |
| t5546-receive-limits.sh | imported | `genrandom` 1 |
| t5547-push-quarantine.sh | imported | `genrandom` 1 |
| t5548-push-porcelain.sh | imported | - |
| t5549-fetch-push-http.sh | M2 #162 | - |
| t5551-http-fetch-smart.sh | M2 #66, M2 #87, M2 #162 | - |
| t5552-skipping-fetch-negotiator.sh | imported | - |
| t5553-set-upstream.sh | imported | - |
| t5554-noop-fetch-negotiator.sh | imported | - |
| t5555-http-smart-common.sh | M2 #162 | `pkt-line unpack` 10 |
| t5557-http-get.sh | imported | - |
| t5558-clone-bundle-uri.sh | imported | - |
| t5559-http-fetch-smart-http2.sh | imported | - |
| t5560-http-backend-noserver.sh | imported | - |
| t5561-http-backend.sh | imported | - |
| t5562-http-backend-content-length.sh | imported | `pkt-line pack` 3, `pkt-line pack-raw-stdin` 1 |
| t5563-simple-http-auth.sh | M2 #162 | - |
| t5564-http-proxy.sh | imported | - |
| t5565-push-multiple.sh | imported | - |
| t5566-push-group.sh | imported | - |
| t5570-git-daemon.sh | imported | `pkt-line pack-raw-stdin` 1, `pkt-line unpack` 1 |
| t5571-pre-push-hook.sh | imported | - |
| t5572-pull-submodule.sh | imported | - |
| t5574-fetch-output.sh | M2 #62 | `path-utils real_path` 4 |
| t5580-unc-paths.sh | imported | - |
| t5581-http-curl-verbose.sh | M2 #162 | - |
| t5582-fetch-negative-refspec.sh | M2 #62 | - |
| t5583-push-branches.sh | M2 #65 | - |
| t5584-http-429-retry.sh | imported | `date getnanos` 18, `date show:<format>` 3, `date timestamp` 3 |
| t5600-clone-fail-cleanup.sh | M2 #64 | - |
| t5601-clone.sh | M2 #64, M2 #66, M2 #87, M2 #159, M2 #160 | - |
| t5602-clone-remote-exec.sh | M2 #160 | - |
| t5603-clone-dirname.sh | M2 #64, M2 #159 | - |
| t5604-clone-reference.sh | imported | - |
| t5605-clone-local.sh | imported | - |
| t5606-clone-options.sh | imported | - |
| t5607-clone-bundle.sh | imported | - |
| t5608-clone-2gb.sh | imported | `env-helper` 1, `synthesize` 1 |
| t5609-clone-branch.sh | M2 #64 | - |
| t5610-clone-detached.sh | M2 #64 | - |
| t5611-clone-config.sh | M2 #64 | - |
| t5612-clone-refspec.sh | M2 #64 | - |
| t5613-info-alternate.sh | imported | - |
| t5614-clone-submodules-shallow.sh | imported | - |
| t5615-alternate-env.sh | imported | - |
| t5616-partial-clone.sh | imported | - |
| t5617-clone-submodules-remote.sh | imported | - |
| t5618-alternate-refs.sh | imported | - |
| t5619-clone-local-ambiguous-transport.sh | imported | - |
| t5620-backfill.sh | imported | - |
| t5621-clone-revision.sh | imported | - |
| t5700-protocol-v1.sh | imported | - |
| t5701-git-serve.sh | M2 #60 | `path-utils file-size` 2, `pkt-line pack` 25, `pkt-line unpack` 15, `serve-v2` 29 |
| t5702-protocol-v2.sh | M1 #177, M2 #60, M2 #66, M2 #81, M2 #160, M2 #162 | `pkt-line pack` 5, `serve-v2` 2 |
| t5703-upload-pack-ref-in-want.sh | imported | `pkt-line pack` 11, `pkt-line unpack` 1, `pkt-line unpack-sideband` 1, `serve-v2` 14 |
| t5704-protocol-violations.sh | imported | `pkt-line pack` 4, `pkt-line pack-raw-stdin` 1 |
| t5705-session-id-in-capabilities.sh | imported | - |
| t5710-promisor-remote-capability.sh | imported | `genrandom` 2 |
| t5730-protocol-v2-bundle-uri-file.sh | imported | - |
| t5731-protocol-v2-bundle-uri-git.sh | imported | - |
| t5732-protocol-v2-bundle-uri-http.sh | imported | - |
| t5750-bundle-uri-parse.sh | imported | `bundle-uri parse-config` 8, `bundle-uri parse-key-values` 6 |
| t5801-remote-helpers.sh | imported | - |
| t5802-connect-helper.sh | imported | - |
| t5810-proto-disable-local.sh | imported | - |
| t5811-proto-disable-git.sh | imported | - |
| t5812-proto-disable-http.sh | imported | - |
| t5813-proto-disable-ssh.sh | imported | - |
| t5814-proto-disable-ext.sh | imported | - |
| t5815-submodule-protos.sh | imported | - |
| t6000-rev-list-misc.sh | M1 #78 | - |
| t6001-rev-list-graft.sh | imported | - |
| t6002-rev-list-bisect.sh | imported | - |
| t6003-rev-list-topo-order.sh | imported | - |
| t6004-rev-list-path-optim.sh | imported | - |
| t6005-rev-list-count.sh | M1 #78 | - |
| t6006-rev-list-format.sh | imported | - |
| t6007-rev-list-cherry-pick-file.sh | imported | - |
| t6009-rev-list-parent.sh | M1 #78 | - |
| t6010-merge-base.sh | M2 #50 | - |
| t6011-rev-list-with-bad-commit.sh | imported | - |
| t6012-rev-list-simplify.sh | imported | - |
| t6013-rev-list-reverse-parents.sh | imported | - |
| t6014-rev-list-all.sh | M1 #78 | - |
| t6016-rev-list-graph-simplify-history.sh | imported | - |
| t6017-rev-list-stdin.sh | imported | - |
| t6018-rev-list-glob.sh | imported | - |
| t6019-rev-list-ancestry-path.sh | imported | - |
| t6020-bundle-misc.sh | imported | - |
| t6021-rev-list-exclude-hidden.sh | imported | - |
| t6022-rev-list-missing.sh | imported | - |
| t6030-bisect-porcelain.sh | imported | - |
| t6040-tracking-info.sh | M2 #40, M2 #48 | - |
| t6041-bisect-submodule.sh | imported | - |
| t6050-replace.sh | imported | - |
| t6060-merge-index.sh | imported | - |
| t6099-merge-base-side-exhaustion.sh | M2 #50 | - |
| t6100-rev-list-in-order.sh | imported | - |
| t6101-rev-parse-parents.sh | M1 #32 | - |
| t6102-rev-list-unexpected-objects.sh | imported | - |
| t6111-rev-list-treesame.sh | imported | - |
| t6112-rev-list-filters-objects.sh | imported | - |
| t6113-rev-list-bitmap-filters.sh | imported | - |
| t6114-keep-packs.sh | imported | - |
| t6115-rev-list-du.sh | imported | - |
| t6120-describe.sh | imported | `chmtime` 2 |
| t6130-pathspec-noglob.sh | M2 #106 | - |
| t6131-pathspec-icase.sh | M2 #106 | - |
| t6132-pathspec-exclude.sh | M2 #106 | - |
| t6133-pathspec-rev-dwim.sh | imported | - |
| t6134-pathspec-in-submodule.sh | imported | - |
| t6135-pathspec-with-attrs.sh | imported | - |
| t6136-pathspec-in-bare.sh | M2 #106 | - |
| t6137-pathspec-wildcards-literal.sh | M2 #106 | - |
| t6200-fmt-merge-msg.sh | imported | - |
| t6300-for-each-ref.sh | imported | - |
| t6301-for-each-ref-errors.sh | imported | `ref-store update-ref` 1 |
| t6302-for-each-ref-filter.sh | imported | - |
| t6400-merge-df.sh | imported | - |
| t6401-merge-criss-cross.sh | imported | - |
| t6402-merge-rename.sh | imported | `chmtime` 14 |
| t6403-merge-file.sh | imported | - |
| t6404-recursive-merge.sh | imported | - |
| t6405-merge-symlinks.sh | imported | - |
| t6406-merge-attr.sh | imported | - |
| t6407-merge-binary.sh | imported | - |
| t6408-merge-up-to-date.sh | imported | - |
| t6409-merge-subtree.sh | imported | - |
| t6411-merge-filemode.sh | imported | - |
| t6412-merge-large-rename.sh | imported | - |
| t6413-merge-crlf.sh | imported | - |
| t6414-merge-rename-nocruft.sh | imported | - |
| t6415-merge-dir-to-symlink.sh | imported | - |
| t6416-recursive-corner-cases.sh | imported | - |
| t6417-merge-ours-theirs.sh | imported | - |
| t6418-merge-text-auto.sh | imported | - |
| t6419-merge-ignorecase.sh | imported | - |
| t6422-merge-rename-corner-cases.sh | imported | - |
| t6423-merge-rename-directories.sh | imported | - |
| t6424-merge-unrelated-index-changes.sh | imported | `chmtime` 1 |
| t6425-merge-rename-delete.sh | imported | - |
| t6426-merge-skip-unneeded-updates.sh | imported | `chmtime` 14 |
| t6427-diff3-conflict-markers.sh | imported | - |
| t6428-merge-conflicts-sparse.sh | imported | - |
| t6429-merge-sequence-rename-caching.sh | imported | - |
| t6430-merge-recursive.sh | imported | - |
| t6432-merge-recursive-space-options.sh | imported | - |
| t6433-merge-toplevel.sh | imported | - |
| t6434-merge-recursive-rename-options.sh | imported | - |
| t6435-merge-sparse.sh | imported | - |
| t6436-merge-overwrite.sh | imported | - |
| t6437-submodule-merge.sh | imported | - |
| t6438-submodule-directory-file-conflicts.sh | imported | - |
| t6439-merge-co-error-msgs.sh | imported | - |
| t6500-gc.sh | imported | `chmtime` 1, `path-utils file-size` 1 |
| t6501-freshen-objects.sh | imported | `chmtime` 2 |
| t6600-test-reach.sh | M2 #50 | `reach` 1 |
| t7001-mv.sh | M2 #41 | - |
| t7002-mv-sparse-checkout.sh | imported | - |
| t7004-tag.sh | imported | `ref-store for-each-reflog-ent` 2 |
| t7005-editor.sh | M2 #122 | - |
| t7006-pager.sh | imported | `genzeros` 1, `sigchain` 1 |
| t7007-show.sh | imported | - |
| t7011-skip-worktree-reading.sh | imported | - |
| t7012-skip-worktree-writing.sh | imported | - |
| t7030-verify-tag.sh | imported | - |
| t7031-verify-tag-signed-ssh.sh | imported | - |
| t7060-wtstatus.sh | M2 #40 | - |
| t7061-wtstatus-ignore.sh | M2 #37, M2 #40 | - |
| t7062-wtstatus-ignorecase.sh | imported | - |
| t7063-status-untracked-cache.sh | M2 #40 | `chmtime` 7, `dump-untracked-cache` 36 |
| t7064-wtstatus-pv2.sh | M2 #40 | - |
| t7101-reset-empty-subdirs.sh | M2 #49 | - |
| t7102-reset.sh | M2 #49 | - |
| t7103-reset-bare.sh | M2 #49 | - |
| t7104-reset-hard.sh | M2 #49 | - |
| t7105-reset-patch.sh | imported | - |
| t7106-reset-unborn-branch.sh | M2 #49 | - |
| t7107-reset-pathspec-file.sh | M2 #49 | - |
| t7110-reset-merge.sh | M2 #49 | - |
| t7111-reset-table.sh | M2 #49 | - |
| t7112-reset-submodule.sh | imported | - |
| t7113-post-index-change-hook.sh | imported | `chmtime` 5 |
| t7201-co.sh | M2 #42 | - |
| t7300-clean.sh | imported | - |
| t7301-clean-interactive.sh | imported | - |
| t7400-submodule-basic.sh | imported | - |
| t7401-submodule-summary.sh | imported | - |
| t7402-submodule-rebase.sh | imported | - |
| t7403-submodule-sync.sh | imported | - |
| t7406-submodule-update.sh | imported | - |
| t7407-submodule-foreach.sh | imported | - |
| t7408-submodule-reference.sh | imported | - |
| t7409-submodule-detached-work-tree.sh | imported | - |
| t7411-submodule-config.sh | imported | `submodule config-list` 6, `submodule config-set` 3, `submodule config-unset` 1, `submodule config-writeable` 4, `submodule-config` 8, `submodule-nested-repo-config` 2 |
| t7412-submodule-absorbgitdirs.sh | imported | - |
| t7413-submodule-is-active.sh | imported | `submodule is-active` 17 |
| t7414-submodule-mistakes.sh | imported | - |
| t7416-submodule-dash-url.sh | imported | - |
| t7417-submodule-path-url.sh | imported | - |
| t7419-submodule-set-branch.sh | imported | - |
| t7420-submodule-set-url.sh | imported | - |
| t7421-submodule-summary-add.sh | imported | - |
| t7422-submodule-output.sh | imported | - |
| t7423-submodule-symlinks.sh | imported | - |
| t7424-submodule-mixed-ref-formats.sh | imported | - |
| t7426-submodule-get-default-remote.sh | imported | - |
| t7450-bad-git-dotfiles.sh | imported | `submodule check-name` 1, `submodule check-url` 1 |
| t7500-commit-template-squash-signoff.sh | imported | - |
| t7501-commit-basic-functionality.sh | M2 #45 | - |
| t7502-commit-porcelain.sh | M2 #45 | - |
| t7503-pre-commit-and-pre-merge-commit-hooks.sh | imported | - |
| t7504-commit-msg-hook.sh | imported | - |
| t7505-prepare-commit-msg-hook.sh | imported | - |
| t7506-status-submodule.sh | imported | - |
| t7507-commit-verbose.sh | imported | - |
| t7508-status.sh | M2 #40 | `chmtime` 7, `truncate` 3 |
| t7509-commit-authorship.sh | M2 #45 | - |
| t7510-signed-commit.sh | imported | - |
| t7511-status-index.sh | M2 #40 | - |
| t7512-status-help.sh | M2 #40 | - |
| t7513-interpret-trailers.sh | imported | - |
| t7514-commit-patch.sh | imported | - |
| t7515-status-symlinks.sh | M2 #36 | - |
| t7516-commit-races.sh | M2 #45 | - |
| t7517-per-repo-email.sh | M2 #122 | - |
| t7518-ident-corner-cases.sh | M2 #122 | - |
| t7519-status-fsmonitor.sh | imported | `chmtime` 6, `dump-fsmonitor` 5, `dump-untracked-cache` 2, `read-cache` 1 |
| t7520-ignored-hook-warning.sh | imported | - |
| t7521-ignored-mode.sh | M2 #40 | - |
| t7524-commit-summary.sh | M2 #45 | - |
| t7525-status-rename.sh | imported | - |
| t7526-commit-pathspec-file.sh | imported | - |
| t7527-builtin-fsmonitor.sh | imported | `fsmonitor-client` 9 |
| t7528-signed-commit-ssh.sh | imported | - |
| t7600-merge.sh | imported | - |
| t7601-merge-pull-config.sh | imported | - |
| t7602-merge-octopus-many.sh | imported | - |
| t7603-merge-reduce-heads.sh | imported | - |
| t7604-merge-custom-message.sh | imported | - |
| t7605-merge-resolve.sh | imported | - |
| t7606-merge-custom.sh | imported | - |
| t7607-merge-state.sh | imported | - |
| t7608-merge-messages.sh | imported | - |
| t7609-mergetool--lib.sh | imported | - |
| t7610-mergetool.sh | imported | - |
| t7611-merge-abort.sh | imported | - |
| t7612-merge-verify-signatures.sh | imported | - |
| t7614-merge-signoff.sh | imported | - |
| t7615-diff-algo-with-mergy-operations.sh | imported | - |
| t7700-repack.sh | imported | `bitmap list-commits` 2, `find-pack` 27, `genrandom` 3 |
| t7701-repack-unpack-unreachable.sh | imported | `chmtime` 6 |
| t7702-repack-cyclic-alternate.sh | imported | - |
| t7703-repack-geometric.sh | imported | `chmtime` 6, `genrandom` 2, `path-utils real_path` 1, `read-midx` 2 |
| t7704-repack-cruft.sh | imported | `chmtime` 16, `genrandom` 1, `pack-mtimes` 14, `read-midx` 4 |
| t7705-repack-incremental-midx.sh | imported | `genrandom` 2, `read-midx` 2 |
| t7706-repack-drop-filtered.sh | imported | `genrandom` 3 |
| t7800-difftool.sh | imported | - |
| t7810-grep.sh | imported | `regex` 1 |
| t7811-grep-open.sh | imported | - |
| t7812-grep-icase-non-ascii.sh | imported | `pcre2-config` 1, `regex` 2 |
| t7813-grep-icase-iso.sh | imported | - |
| t7814-grep-recurse-submodules.sh | imported | - |
| t7815-grep-binary.sh | imported | - |
| t7816-grep-binary-pattern.sh | imported | - |
| t7817-grep-sparse-checkout.sh | imported | - |
| t7900-maintenance.sh | imported | `chmtime` 4, `crontab` 5, `genrandom` 2 |
| t7999-subtree.sh | imported | - |
| t8001-annotate.sh | imported | - |
| t8002-blame.sh | imported | - |
| t8003-blame-corner-cases.sh | imported | - |
| t8004-blame-with-conflicts.sh | imported | - |
| t8005-blame-i18n.sh | imported | - |
| t8006-blame-textconv.sh | imported | - |
| t8007-cat-file-textconv.sh | M1 #15 | - |
| t8008-blame-formats.sh | imported | - |
| t8009-blame-vs-topicbranches.sh | imported | - |
| t8010-cat-file-filters.sh | M1 #15 | - |
| t8011-blame-split-file.sh | imported | - |
| t8012-blame-colors.sh | imported | - |
| t8013-blame-ignore-revs.sh | imported | - |
| t8014-blame-ignore-fuzzy.sh | imported | - |
| t8015-blame-diff-algorithm.sh | imported | - |
| t8020-last-modified.sh | imported | - |
| t9001-send-email.sh | imported | - |
| t9002-column.sh | imported | - |
| t9003-help-autocorrect.sh | imported | - |
| t9300-fast-import.sh | imported | `genrandom` 1, `ref-store resolve-ref` 1 |
| t9301-fast-import-notes.sh | imported | - |
| t9302-fast-import-unpack-limit.sh | imported | - |
| t9303-fast-import-compression.sh | imported | `path-utils file-size` 2 |
| t9304-fast-import-marks.sh | imported | - |
| t9305-fast-import-signatures.sh | imported | - |
| t9306-fast-import-signed-tags.sh | imported | - |
| t9350-fast-export.sh | imported | - |
| t9351-fast-export-anonymize.sh | imported | - |
| t9850-shell.sh | imported | `genzeros` 1 |
| t9904-url-parse.sh | imported | - |

### Sourced libraries

| Library | Used by | Subcommands (calls) |
|---|---:|---|
| lib-bitmap.sh | 6 | `read-midx` 1 |
| lib-bundle-uri-protocol.sh | 3 | `bundle-uri ls-remote` 4 |
| lib-commit-graph.sh | 2 | `read-graph` 1 |
| lib-git-daemon.sh | 8 | `env-helper` 1 |
| lib-httpd.sh | 33 | `env-helper` 1 |
| lib-loose.sh | 3 | `sha1/sha256 (via $algo)` 1, `zlib` 1 |
| lib-midx.sh | 8 | `read-midx` 2 |
| lib-pack.sh | 4 | `sha1/sha256 (via $algo)` 1 |
| lib-unicode-nfc-nfd.sh | 1 | `hexdump` 4 |

### Framework

Always loaded, so these run in every script.

- `test-lib.sh`: `date is64bit` 1, `date time_t-is64bit` 1, `path-utils file-size` 1
- `test-lib-functions.sh`: `chmtime` 2, `env-helper` 1, `hexdump` 1, `path-utils file-size` 1, `path-utils readlink` 1, `pkt-line pack` 1, `pkt-line pack-raw-stdin` 1, `pkt-line unpack` 1
<!-- END GENERATED INVENTORY -->
