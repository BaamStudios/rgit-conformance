// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/lib-oid.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/lib-oid.c).
// GPL-2.0, see LICENSE.
//
// Upstream picks one hash algorithm from GIT_TEST_DEFAULT_HASH. The ports run
// every case with both SHA-1 and SHA-256 instead; `hash_kinds` keeps the
// variable as a filter (unset: both).

#![allow(dead_code)]

use rgit_hash::{HashKind, ObjectId};

/// The hash kinds a test runs with: both, or the one GIT_TEST_DEFAULT_HASH
/// names (upstream `cl_setup_hash_algo`).
pub fn hash_kinds() -> Vec<HashKind> {
    match std::env::var("GIT_TEST_DEFAULT_HASH") {
        Ok(name) => vec![HashKind::from_name(&name).expect("valid GIT_TEST_DEFAULT_HASH")],
        Err(_) => vec![HashKind::Sha1, HashKind::Sha256],
    }
}

/// Upstream `cl_parse_any_oid`: pad `hex` with `0` to a full id of `kind`.
pub fn parse_any_oid(kind: HashKind, hex: &str) -> ObjectId {
    assert!(hex.len() <= kind.hex_len(), "{hex} longer than a {kind} id");
    let padded = format!("{hex:0<width$}", width = kind.hex_len());
    ObjectId::from_hex(kind, padded.as_bytes()).expect("valid hex")
}

/// A directory of loose-object placeholder files: `<dir>/<xx>/<rest>` for
/// each id. rgit's loose store finds ids by file name alone (existence and
/// prefix listing), so the files can stay empty. This stands in for the
/// in-memory containers (oid-array, oidtree) the C tests fill.
pub struct LooseIds {
    pub dir: tempfile::TempDir,
}

impl LooseIds {
    pub fn new(ids: &[ObjectId]) -> LooseIds {
        let dir = tempfile::tempdir().expect("temporary directory");
        for oid in ids {
            let hex = oid.to_hex();
            let fan = dir.path().join(&hex[..2]);
            std::fs::create_dir_all(&fan).expect("fan-out directory");
            std::fs::write(fan.join(&hex[2..]), b"").expect("placeholder file");
        }
        LooseIds { dir }
    }

    pub fn path(&self) -> &std::path::Path {
        self.dir.path()
    }
}
