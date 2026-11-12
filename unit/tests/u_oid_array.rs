// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-oid-array.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-oid-array.c).
// GPL-2.0, see LICENSE.
//
// Same cases and expected values as upstream. rgit has no `oid_array`; the
// behaviour it stands for maps onto rgit as follows:
// - enumerate unique (`oid_array_for_each_unique`): the sorted, de-duplicated
//   id listing of `rgit_odb::ObjectDatabase::all_objects`. The input ids are
//   placeholder files in loose stores; duplicates are the same ids in further
//   stores, since one directory cannot hold a file twice.
// - lookup (`oid_array_lookup`): binary search of a sorted `Vec<ObjectId>`
//   (rgit's `Ord`) with `rgit_hash::Prefix::cmp_oid`, the comparison rgit
//   offers for searching sorted id lists. The result is mapped to upstream's
//   convention: the index if found, otherwise `-1 - insertion point`.
// Every case runs with SHA-1 and SHA-256 (see common/mod.rs).

mod common;

use std::sync::Arc;

use common::{LooseIds, hash_kinds, parse_any_oid};
use rgit_hash::{HashKind, ObjectId, Prefix};
use rgit_odb::{LooseOptions, LooseStore, ObjectDatabase};

fn fill_array(kind: HashKind, hexes: &[&str]) -> Vec<ObjectId> {
    let array: Vec<ObjectId> = hexes.iter().map(|h| parse_any_oid(kind, h)).collect();
    assert_eq!(array.len(), hexes.len());
    array
}

/// Upstream `t_enumeration`.
fn t_enumeration(input: &[&str], expect: &[&str]) {
    for kind in hash_kinds() {
        let input = fill_array(kind, input);
        let expect = fill_array(kind, expect);

        // Each run of distinct ids goes into its own loose store.
        let mut stores: Vec<Vec<ObjectId>> = Vec::new();
        for oid in input {
            match stores.iter_mut().find(|s| !s.contains(&oid)) {
                Some(s) => s.push(oid),
                None => stores.push(vec![oid]),
            }
        }
        let dirs: Vec<LooseIds> = stores.iter().map(|s| LooseIds::new(s)).collect();
        let mut db = ObjectDatabase::open(dirs[0].path(), kind, LooseOptions::default());
        for dir in &dirs[1..] {
            db.push_store(Arc::new(LooseStore::new(
                dir.path(),
                kind,
                LooseOptions::default(),
            )));
        }

        let actual: Vec<ObjectId> = db.all_objects().expect("listing").into_iter().collect();
        assert_eq!(actual.len(), expect.len(), "{kind}");
        for (a, e) in actual.iter().zip(&expect) {
            assert_eq!(a, e, "{kind}");
        }
    }
}

/// Upstream `oid_array_lookup` on rgit: sort, then binary search.
fn oid_array_lookup(array: &mut [ObjectId], query: &ObjectId) -> i64 {
    array.sort();
    let prefix = Prefix::from(*query);
    match array.binary_search_by(|id| prefix.cmp_oid(id).reverse()) {
        Ok(i) => i as i64,
        Err(i) => -1 - i as i64,
    }
}

/// Upstream `t_lookup`.
fn t_lookup(input: &[&str], query: &str, lower_bound: i64, upper_bound: i64) {
    for kind in hash_kinds() {
        let oid_query = parse_any_oid(kind, query);
        let mut array = fill_array(kind, input);
        let ret = oid_array_lookup(&mut array, &oid_query);
        assert!(ret <= upper_bound, "{kind}: {ret} > {upper_bound}");
        assert!(ret >= lower_bound, "{kind}: {ret} < {lower_bound}");
    }
}

const ARR_INPUT: &[&str] = &["88", "44", "aa", "55"];
const ARR_INPUT_DUP: &[&str] = &[
    "88", "44", "aa", "55", "88", "44", "aa", "55", "88", "44", "aa", "55",
];
const RES_SORTED: &[&str] = &["44", "55", "88", "aa"];

#[test]
fn enumerate_unique() {
    t_enumeration(ARR_INPUT, RES_SORTED);
}

#[test]
fn enumerate_duplicate() {
    t_enumeration(ARR_INPUT_DUP, RES_SORTED);
}

#[test]
fn lookup() {
    t_lookup(ARR_INPUT, "55", 1, 1);
}

#[test]
fn lookup_non_existent() {
    t_lookup(ARR_INPUT, "33", i64::MIN, -1);
}

#[test]
fn lookup_duplicates() {
    t_lookup(ARR_INPUT_DUP, "55", 3, 5);
}

#[test]
fn lookup_non_existent_dup() {
    t_lookup(ARR_INPUT_DUP, "66", i64::MIN, -1);
}

#[test]
fn lookup_almost_dup() {
    for kind in hash_kinds() {
        let nearly_55 = if kind == HashKind::Sha1 {
            "5500000000000000000000000000000000000001"
        } else {
            "5500000000000000000000000000000000000000000000000000000000000001"
        };
        let oid_query = parse_any_oid(kind, "55");
        let mut array = fill_array(kind, &["55", nearly_55]);
        assert_eq!(oid_array_lookup(&mut array, &oid_query), 0, "{kind}");
    }
}

#[test]
fn lookup_single_dup() {
    t_lookup(&["55", "55"], "55", 0, 1);
}
