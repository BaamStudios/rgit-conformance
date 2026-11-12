# unit — ported C unit tests

Rust ports of git's C unit tests (`git/t/unit-tests/u-*.c`, git v2.56.1) that
check behaviour of formats and algorithms rgit implements. They run against
rgit's library crates, which are pulled from
[rgit `main`](https://github.com/BaamStudios/rgit) as git dependencies. This
crate is GPL-2.0 like the tests it is derived from, is never published and is
never part of rgit (rgit issue #8, ADR 0001).

```sh
cd unit
cargo test                 # uses the rgit main commit in the local Cargo.lock
cargo update && cargo test # pick up the latest rgit main
```

`Cargo.lock` is not committed: the tests always follow rgit `main`.

## Porting rules

- One file per upstream file: `t/unit-tests/u-foo-bar.c` becomes
  `tests/u_foo_bar.rs`, one `#[test]` per upstream `test_<suite>__<case>`
  function with the same case name.
- Each file starts with `SPDX-License-Identifier: GPL-2.0-only` and a header
  naming the upstream path and git version.
- Same cases and expected values as upstream. The clar harness and C helpers
  (strbuf, test-lib) are replaced by plain Rust; note other deviations in the
  file header.
- A file is ported when the rgit type it tests is on rgit `main`; until then it
  stays in the "pending" table with the rgit issue that brings the type.
- Implementation work on rgit may read these ports, but never git's C/Rust
  implementation (rgit CLEANROOM.md).

## Status

### Ported

| Upstream file | Port | rgit crate | Issue |
|---|---|---|---|
| `u-hash.c` | `tests/u_hash.rs` | `rgit-hash` (`Hasher`, `HashKind`) | #11, #12 |
| `u-oid-array.c` | `tests/u_oid_array.rs` | `rgit-odb` (`ObjectDatabase::all_objects` over several loose stores), `rgit-hash` (`ObjectId` order, `Prefix::cmp_oid` search) | #8 |
| `u-oidmap.c` | `tests/u_oidmap.rs` | `rgit-hash` (`ObjectId` as `HashMap` key) | #8 |
| `u-oidtree.c` | `tests/u_oidtree.rs` | `rgit-odb` (`ObjectDatabase::contains`, `resolve_prefix`); `insert_overwrites_data` not ported: rgit keeps no payload per id | #8, #32 |
| `u-urlmatch-normalization.c` | `tests/u_urlmatch_normalization.rs` | `rgit-config` (`urlmatch::Url::parse`), `rgit-remote` (`url::parse_connect_url`); `length` not ported (rgit builds no normalized string); 45 checks rgit does not pass yet are listed in `KNOWN_GAPS` and skipped | #8, #159 |
| `u-dir.c` (part) | `tests/u_dir.rs` | `rgit-pathspec` (`Pathspec::common_prefix`); `within_depth` pending, see below | #8, #106 |

### Pending: ported once the rgit type exists

| Upstream file | What it tests | Needs | Issue |
|---|---|---|---|
| `u-prio-queue.c` | priority queue order, LIFO mode, replace | commit queue of the revision walk (not on rgit main yet; `BinaryHeap` uses in rgit-pack/-protocol are private) | #46 |
| `u-utf8-width.c` | display width of CJK text, ANSI escapes, alignment | UTF-8 width helpers (not on rgit main yet) | #75 |
| `u-trailer.c` | trailer parsing | `interpret-trailers` | #129 |
| `u-list-objects-filter-options.c` | `--filter=` spec parsing | partial clone filters | #24 |
| `u-dir.c` (`within_depth`) | path depth limit of the directory walk | directory walk (`--max-depth`) | #37 |
| `u-reftable-basics.c` | reftable helpers (binary search, prefix compression, varints) | reftable | #31 |
| `u-reftable-block.c` | reftable blocks: write, read, seek | reftable | #31 |
| `u-reftable-merged.c` | merged tables | reftable | #31 |
| `u-reftable-pq.c` | merge priority queue | reftable | #31 |
| `u-reftable-readwrite.c` | table read/write round trips | reftable | #31 |
| `u-reftable-record.c` | record encoding (ref, log, obj, index) | reftable | #31 |
| `u-reftable-stack.c` | `tables.list` stack, auto-compaction | reftable | #31 |
| `u-reftable-table.c` | table reader, iterators | reftable | #31 |
| `u-reftable-tree.c` | reftable's binary tree | reftable | #31 |

### Not ported

C containers and helpers without an rgit counterpart; Rust's standard library
covers them.

| Upstream file | Reason |
|---|---|
| `u-strbuf.c` | C string buffer (`String`/`Vec<u8>`) |
| `u-strvec.c` | C string vector (`Vec<String>`) |
| `u-string-list.c` | C string list |
| `u-mem-pool.c` | C memory pool allocator |
| `u-hashmap.c` | C hash map (`HashMap`) |
| `u-strcmp-offset.c` | C string compare helper |
| `u-ctype.c` | git's own `ctype` table (`u8::is_ascii_*`) |
| `u-example-decorate.c` | C object decoration example |
| `u-odb-inmemory.c` | git's in-memory object database internals |

Single cases not ported (the rest of the file is): `u-oidtree.c`
`insert_overwrites_data` (per-id payload of git's oidtree; rgit's prefix lookup
stores ids only), `u-urlmatch-normalization.c` `length` (length of git's
normalized URL string; rgit keeps the normalized URL as parts).

Ports run every case with SHA-1 and SHA-256; `GIT_TEST_DEFAULT_HASH` limits
them to one, as upstream. `tests/common/mod.rs` is the port of `lib-oid.c`.

Support files (`unit-test.[ch]`, `test-lib.[ch]`, `lib-oid.[ch]`,
`lib-reftable.[ch]`, `clar/`, `generate-clar-*.sh`) are the C harness and are
not ported; the helpers a port needs are rewritten in the port.
