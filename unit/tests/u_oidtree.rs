// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-oidtree.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-oidtree.c).
// GPL-2.0, see LICENSE.
//
// git's oidtree is the in-memory index of loose object names used for
// abbreviated-id lookup. rgit answers the same questions from its loose store
// directly, so the cases run against `rgit_odb`:
// - `oidtree_insert` of a list: placeholder files in a loose store
//   (see common/mod.rs);
// - `oidtree_contains`: `ObjectDatabase::contains`;
// - `oidtree_each(prefix)`: `ObjectDatabase::resolve_prefix`, whose result
//   lists the matches in ascending order like the oidtree walk. The query is
//   padded to a full id like upstream's `cl_parse_any_oid` and then cut to
//   the query's length (`Prefix::new`), as `oidtree_each` gets `strlen(query)`.
// Deviation: `insert_overwrites_data` is not ported. It checks the per-id
// payload pointer an oidtree node carries; rgit's prefix lookup keeps no
// payload per id (ids only).
// Every case runs with SHA-1 and SHA-256.

mod common;

use common::{LooseIds, hash_kinds, parse_any_oid};
use rgit_hash::{HashKind, ObjectId, Prefix};
use rgit_odb::{LooseOptions, ObjectDatabase, PrefixMatch};

/// Upstream `FILL_TREE` on a fresh tree.
fn fill_tree(kind: HashKind, hexes: &[&str]) -> (LooseIds, ObjectDatabase) {
    let ids: Vec<ObjectId> = hexes.iter().map(|h| parse_any_oid(kind, h)).collect();
    let dir = LooseIds::new(&ids);
    let db = ObjectDatabase::open(dir.path(), kind, LooseOptions::default());
    (dir, db)
}

fn check_contains(db: &ObjectDatabase, hex: &str, expected: bool) {
    let oid = parse_any_oid(db.hash_kind(), hex);
    assert_eq!(
        db.contains(&oid),
        expected,
        "{} contains {hex}",
        db.hash_kind()
    );
}

/// Upstream `check_each`: the ids starting with `query`, in order.
fn check_each(db: &ObjectDatabase, query: &str, expected: &[&str]) {
    let kind = db.hash_kind();
    let oid = parse_any_oid(kind, query);
    let prefix = Prefix::new(oid, query.len()).expect("valid prefix length");
    let found = match db.resolve_prefix(&prefix).expect("prefix lookup") {
        PrefixMatch::None => Vec::new(),
        PrefixMatch::Unique(oid) => vec![oid],
        PrefixMatch::Ambiguous(ids) => ids,
    };
    let found: Vec<String> = found.iter().map(ObjectId::to_hex).collect();
    let expected: Vec<String> = expected
        .iter()
        .map(|h| parse_any_oid(kind, h).to_hex())
        .collect();
    assert_eq!(found, expected, "{kind}: query '{query}'");
}

#[test]
fn contains() {
    for kind in hash_kinds() {
        let (_dir, db) = fill_tree(
            kind,
            &["444", "1", "2", "3", "4", "5", "a", "b", "c", "d", "e"],
        );
        check_contains(&db, "44", false);
        check_contains(&db, "441", false);
        check_contains(&db, "440", false);
        check_contains(&db, "444", true);
        check_contains(&db, "4440", true);
        check_contains(&db, "4444", false);
    }
}

#[test]
fn each() {
    for kind in hash_kinds() {
        let (_dir, db) = fill_tree(
            kind,
            &["f", "9", "8", "123", "321", "320", "a", "b", "c", "d", "e"],
        );
        check_each(&db, "12300", &["123"]);
        check_each(&db, "3211", &[]); // should not reach callback
        check_each(&db, "3210", &["321"]);
        check_each(&db, "32100", &["321"]);
        check_each(&db, "32", &["320", "321"]);
    }
}
