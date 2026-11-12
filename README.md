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
| `unit/` | Rust ports of git's C unit tests (`git/t/unit-tests/`) |
| `run` | Test runner (planned, rgit issue #5) |
| `STATUS.md` | Generated: which upstream scripts are ported and how many cases pass against rgit |

## How it works

1. Every script runs against the **reference git** (pinned version, currently
   v2.56.1). Cases that fail there are not valid checks and are excluded.
2. The same scripts run against **rgit**, installed as `git` via
   `GIT_TEST_INSTALLED`.
3. Modes: `fallback` forwards subcommands rgit does not implement yet to the
   reference git (used for rgit milestones M1–M2, forwarded commands are
   reported); `strict` runs everything through rgit.

rgit pins the expected version of this suite in its `conformance.lock` file.

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
