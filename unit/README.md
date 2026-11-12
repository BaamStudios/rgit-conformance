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

### Pending: ported once the rgit type exists

| Upstream file | What it tests | Needs | Issue |
|---|---|---|---|
| `u-oid-array.c` | sorted object-id list: enumerate unique, lookup incl. duplicates | object-id set/array type | #8 (after #13/#14) |
| `u-oidmap.c` | map keyed by object id: get, replace, remove, iterate, clear | object-id map type | #8 (after #13/#14) |
| `u-oidtree.c` | object-id prefix lookup (contains, each, overwrite) | abbreviated-id lookup | #32 |
| `u-prio-queue.c` | priority queue order, LIFO mode, replace | commit queue of the revision walk | #46 |
| `u-utf8-width.c` | display width of CJK text, ANSI escapes, alignment | UTF-8 width helpers | #75 |
| `u-urlmatch-normalization.c` | URL normalisation for `http.<url>.*` matching | URL handling | #159 |
| `u-trailer.c` | trailer parsing | `interpret-trailers` | #129 |
| `u-list-objects-filter-options.c` | `--filter=` spec parsing | partial clone filters | #24 |
| `u-dir.c` | path depth limit, common prefix of pathspecs with excludes | directory walk, pathspecs | #37 (pathspecs: #106) |
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

Support files (`unit-test.[ch]`, `test-lib.[ch]`, `lib-oid.[ch]`,
`lib-reftable.[ch]`, `clar/`, `generate-clar-*.sh`) are the C harness and are
not ported; the helpers a port needs are rewritten in the port.
