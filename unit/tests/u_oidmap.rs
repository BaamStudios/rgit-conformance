// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-oidmap.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-oidmap.c).
// GPL-2.0, see LICENSE.
//
// Same cases and expected values as upstream. rgit keys its maps by
// `rgit_hash::ObjectId` in std's `HashMap` instead of a custom oidmap, so the
// cases check that `ObjectId`'s `Hash`/`Eq` make it a working map key:
// `oidmap_put` is `insert` (returns the replaced entry), `oidmap_get` is
// `get`, `oidmap_remove` is `remove`, iteration and size as upstream.
// The two clear cases check ownership instead of a free callback: with the
// callback the map owns the entries and clearing drops them (counted by a
// `Drop` hook); without it the map holds shared handles and clearing leaves
// the entry alive.
// Every case runs with SHA-1 and SHA-256.

mod common;

use std::cell::Cell;
use std::collections::HashMap;
use std::rc::Rc;

use common::{hash_kinds, parse_any_oid};
use rgit_hash::{HashKind, ObjectId};

const KEY_VAL: [(&str, &str); 3] = [("11", "one"), ("22", "two"), ("33", "three")];

/// Upstream `test_oidmap__initialize`.
fn initialize(kind: HashKind) -> HashMap<ObjectId, String> {
    let mut map = HashMap::new();
    for (key, val) in KEY_VAL {
        assert!(
            map.insert(parse_any_oid(kind, key), val.to_string())
                .is_none()
        );
    }
    map
}

#[test]
fn replace() {
    for kind in hash_kinds() {
        let mut map = initialize(kind);
        let prev = map.insert(parse_any_oid(kind, "11"), "un".to_string());
        assert_eq!(prev.as_deref(), Some("one"));
        let prev = map.insert(parse_any_oid(kind, "22"), "deux".to_string());
        assert_eq!(prev.as_deref(), Some("two"));
    }
}

#[test]
fn get() {
    for kind in hash_kinds() {
        let map = initialize(kind);
        assert_eq!(
            map.get(&parse_any_oid(kind, "22")).map(String::as_str),
            Some("two")
        );
        assert_eq!(map.get(&parse_any_oid(kind, "44")), None);
        assert_eq!(
            map.get(&parse_any_oid(kind, "11")).map(String::as_str),
            Some("one")
        );
    }
}

#[test]
fn remove() {
    for kind in hash_kinds() {
        let mut map = initialize(kind);
        let oid = parse_any_oid(kind, "11");
        assert_eq!(map.remove(&oid).as_deref(), Some("one"));
        assert_eq!(map.get(&oid), None);

        let oid = parse_any_oid(kind, "22");
        assert_eq!(map.remove(&oid).as_deref(), Some("two"));
        assert_eq!(map.get(&oid), None);

        assert_eq!(map.remove(&parse_any_oid(kind, "44")), None);
    }
}

#[test]
fn iterate() {
    for kind in hash_kinds() {
        let map = initialize(kind);
        let mut seen = [false; KEY_VAL.len()];
        let mut count = 0;
        for (oid, name) in &map {
            let i = KEY_VAL
                .iter()
                .position(|(key, _)| parse_any_oid(kind, key) == *oid)
                .unwrap_or_else(|| panic!("Unexpected entry: name = {name}, oid = {oid}"));
            assert!(!seen[i], "Unexpected entry: name = {name}, oid = {oid}");
            seen[i] = true;
            count += 1;
        }
        assert_eq!(count, KEY_VAL.len());
        assert_eq!(map.len(), KEY_VAL.len());
    }
}

/// An entry that counts how often it is freed.
struct Entry<'a> {
    #[allow(dead_code)]
    name: &'static str,
    freed: &'a Cell<usize>,
}

impl Drop for Entry<'_> {
    fn drop(&mut self) {
        self.freed.set(self.freed.get() + 1);
    }
}

#[test]
fn clear_without_free_callback() {
    for kind in hash_kinds() {
        let freed = Cell::new(0);
        let entry = Rc::new(Entry {
            name: "one",
            freed: &freed,
        });
        let mut local_map = HashMap::new();
        assert!(
            local_map
                .insert(parse_any_oid(kind, "11"), Rc::clone(&entry))
                .is_none()
        );
        local_map.clear();
        assert_eq!(freed.get(), 0);
        drop(entry);
    }
}

#[test]
fn clear_with_free_callback() {
    for kind in hash_kinds() {
        let freed = Cell::new(0);
        let mut local_map = HashMap::new();
        assert!(
            local_map
                .insert(
                    parse_any_oid(kind, "11"),
                    Entry {
                        name: "one",
                        freed: &freed,
                    },
                )
                .is_none()
        );
        local_map.clear();
        assert_eq!(freed.get(), 1);
    }
}
