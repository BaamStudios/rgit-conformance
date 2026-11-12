# rgit-conformance

The conformance test suite for [rgit](https://github.com/BaamStudios/rgit), an
unofficial clean-room reimplementation of git in Rust. It contains tests
**ported from git's own test suite** and runs them against the reference git and
against rgit to prove that rgit behaves exactly like git.

> [!IMPORTANT]
> This repository is **GPL-2.0**, because its contents are derived from git's
> GPL-2.0 test suite. It is a separate work: it only runs the `rgit` binary and is
> never compiled into or linked with rgit, which is MIT licensed. Neither project
> is affiliated with or endorsed by the Git project or Software Freedom
> Conservancy.

## Directory layout

| Path | Contents |
|---|---|
| `t/` | Shell tests copied from `git/t/` (same names, e.g. `t1006-cat-file.sh`) plus `test-lib.sh`, `test-lib-functions.sh` and needed `lib-*.sh` |
| `unit/` | Rust ports of git's C unit tests (`git/t/unit-tests/`), run against rgit's crates; see [unit/README.md](unit/README.md) |
| `run` | Test runner: builds the reference git, runs the scripts, writes `STATUS.md`, checks the baseline |
| `import` | Copies files from git's `t/` into `t/` with the required header |
| `REFERENCE_VERSION` | The git version the scripts were copied from and that is built as reference (`v2.56.1`) |
| `implemented.txt` | Subcommands that fallback mode sends to rgit |
| `exclude.txt` | Optional: cases excluded on purpose (`<script> <case numbers> # reason`) |
| `baseline.txt` | Generated: cases that pass against rgit; a listed case that fails is a regression |
| `STATUS.md` | Generated: per-script and per-case results of all passes |
| `selftest/` | Self-test of the regression gate |
| `results/` | Raw results of the last run (not committed) |
| `test-tool/`, `TEST-TOOL.md` | `test-tool` dispatcher and rgit-backed substitutes, inventory of the subcommands the scripts use (rgit issue #6) |

## How it works

1. Every script runs against the **reference git** (pinned version, currently
   v2.56.1). Cases that fail there are not valid checks and are excluded.
2. The same scripts run against **rgit**, installed as `git` via
   `GIT_TEST_INSTALLED`.
3. Modes: `fallback` forwards subcommands rgit does not implement yet to the
   reference git (used for rgit milestones M1–M2, forwarded commands are
   reported); `strict` runs everything through rgit.

rgit pins the expected version of this suite in its `conformance.lock` file.

## Running

```sh
./run --reference-only t0000            # reference pass only
./run --rgit ../rgit/target/debug/rgit  # reference + fallback pass, all scripts
./run --mode both --rgit … --check      # + strict pass, fail on regressions
```

The first run clones git `REFERENCE_VERSION` into
`~/.cache/rgit-conformance/git-v2.56.1` (`RGIT_CONFORMANCE_CACHE` changes the
cache directory, `RGIT_REFERENCE_SOURCE` the clone source, e.g. a local
checkout) and builds it with `make`, including `t/helper/test-tool`. The runner
only runs the build; nobody needs to read git's sources.

Per script and pass, `run`

- runs the script from `t/` with `GIT_BUILD_DIR` pointing at the reference build
  (so `test-tool`, templates and `GIT-BUILD-OPTIONS` come from there);
- for the rgit passes sets `GIT_TEST_INSTALLED` to a generated directory under
  `results/<variant>/install-<mode>/` that contains `git` and the dashed programs
  `git-upload-pack`, `git-receive-pack`, `git-upload-archive`;
- parses the TAP output into `results/<variant>/<pass>/<script>.tsv`
  (`case number, status, forwarded subcommands, description`; status is `pass`,
  `fail`, `skip`, `todo` for a known breakage or `fixed` when it vanished) and a
  `.meta` file with the script state (`complete`, `complete_failed`,
  `skip_all`, `bail`, `error`). Raw TAP, stderr and trash directories stay in
  `results/` for debugging; rerun a single script by hand with `-v -i -x`.

A case is a **valid check** only if it passes against the reference git. Cases
that fail there, and all cases of a script that does not complete there, are
reported as invalid and shown as `excluded` in the rgit columns.

`STATUS.md` is generated from everything in `results/` and contains no
timestamps or rgit version, so two runs over the same state produce the same file.

### Modes

- **fallback**: `git` is a wrapper. It determines the subcommand (skipping
  global options like `-C`, `-c`, `--git-dir`; an option-only call such as
  `git --exec-path` uses the option as its name; a dashed program uses its name
  without `git-`). If the subcommand is listed in `implemented.txt` it runs
  rgit, otherwise the reference git. Every forwarded call is written into the
  script's TAP stream as `# rgit-forwarded: <subcommand>`; the parser assigns it
  to the next test case, so `STATUS.md` lists per case what was forwarded
  (calls from code outside a test block are counted for the following case).
  Calls that the reference git makes internally are not seen by the wrapper.
- **strict**: `git` is rgit. As long as rgit does not answer `--exec-path`
  (rgit #73) a shim answers it with the install directory.

With only `--version` in `implemented.txt`, fallback mode is pure reference
behaviour and every valid case must pass; this is the sanity check of the
wrapper. `version` itself can only be listed once rgit supports
`git version --build-options` (test-lib reads `default-hash:` from it).

### Baseline and regressions

`./run --update-baseline` writes `baseline.txt` (`<mode> <script> <ranges>`)
from the current results. `./run --check` exits 1 if a case listed there no
longer passes and prints `REGRESSION:` lines; new passes are only reported.
`./run --check-status` exits 1 if the committed `STATUS.md` differs from the one
the current results produce. `selftest/gate.sh` shows the gate turning red when
a subcommand routed to a broken rgit makes passing cases fail. With both
`--check` and `--update-baseline` the check runs against the previous baseline
before it is rewritten.

rgit's CI fails only on regressions; it does not touch `STATUS.md` or
`baseline.txt`. The nightly `refresh` workflow in this repository builds rgit
`main`, runs `./run --mode both --check --update-baseline` and opens (or
updates) the pull request "Refresh STATUS/baseline" when either file changed.
Regressions it finds are listed in that pull request; the baseline is only
lowered when the pull request is merged.

### Variants

`--hash sha256` sets `GIT_TEST_DEFAULT_HASH`, `--ref-format reftable` sets
`GIT_TEST_DEFAULT_REF_FORMAT`. Results, status and baseline of a variant are
kept apart (`results/sha256/`, `STATUS.sha256.md`, `baseline.sha256.txt`).

## Importing a script

1. Check out git at the version in `REFERENCE_VERSION` (rgit's
   `scripts/fetch-upstream.sh` does that).
2. `./import <checkout> t1234-foo.sh` and the same for every `lib-*.sh` or data
   file it sources (look for `. "$TEST_DIRECTORY"/…` and other files the script
   reads from `$TEST_DIRECTORY`).
3. `./run --mode both --rgit <rgit> t1234` — the reference pass must complete;
   failing cases are reported as invalid.
4. If a case cannot be a valid check (for example it depends on the build
   environment), add it to `exclude.txt` with a reason: `t1234-foo.sh 7 12 # why`.
   Excluded cases are skipped in all passes via `GIT_SKIP_TESTS`.
5. Run `./run --mode both --rgit <rgit> --update-baseline` for the full suite
   and commit the script, `STATUS.md` and `baseline.txt`.

## Porting rules

- Keep upstream names and numbers. Every ported file starts with a header naming
  the upstream file and git version.
- Change upstream scripts only where unavoidable and mark changes with `# rgit:`.
- Implementation work on rgit may read these tests, but never git's C/Rust
  implementation (see rgit's
  [CLEANROOM.md](https://github.com/BaamStudios/rgit/blob/main/CLEANROOM.md)).

Work items are tracked in the rgit repository:
<https://github.com/BaamStudios/rgit/issues>.

## License

GPL-2.0, see [LICENSE](LICENSE).
