// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-hash.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-hash.c).
// GPL-2.0, see LICENSE.
//
// Same cases and expected values as upstream; the clar harness is replaced by
// Rust tests, git_hash_{init,update,final} by rgit_hash::Hasher.

use rgit_hash::{HashKind, Hasher};

/// Upstream `check_hash_data`: hash `data` with every algorithm and compare
/// the hex digest. `expected` is in upstream order: SHA-1, SHA-256.
fn check_hash_data(data: &[u8], expected: [&str; 2]) {
    for (kind, expected) in [HashKind::Sha1, HashKind::Sha256].into_iter().zip(expected) {
        let mut ctx = Hasher::new(kind);
        ctx.update(data);
        let hash = ctx.finalize().expect("no SHA-1 collision in these inputs");
        assert_eq!(hash.to_hex(), expected, "{kind} of {} bytes", data.len());
    }
}

/// Upstream `TEST_HASH_STR`: a NUL terminated string.
fn test_hash_str(data: &str, sha1: &str, sha256: &str) {
    check_hash_data(data.as_bytes(), [sha1, sha256]);
}

/// Upstream `TEST_HASH_LITERAL`: a literal that may contain NUL characters.
fn test_hash_literal(literal: &[u8], sha1: &str, sha256: &str) {
    check_hash_data(literal, [sha1, sha256]);
}

#[test]
fn empty_string() {
    test_hash_str(
        "",
        "da39a3ee5e6b4b0d3255bfef95601890afd80709",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    );
}

#[test]
fn single_character() {
    test_hash_str(
        "a",
        "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8",
        "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",
    );
}

#[test]
fn multi_character() {
    test_hash_str(
        "abc",
        "a9993e364706816aba3e25717850c26c9cd0d89d",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
}

#[test]
fn message_digest() {
    test_hash_str(
        "message digest",
        "c12252ceda8be8994d5fa0290a47231c1d16aae3",
        "f7846f55cf23e14eebeab5b4e1550cad5b509e3348fbc4efa3a1413d393cb650",
    );
}

#[test]
fn alphabet() {
    test_hash_str(
        "abcdefghijklmnopqrstuvwxyz",
        "32d10c7b8cf96570ca04ce37f2a19d84240d3a89",
        "71c480df93d6ae2f1efad1447c66c9525e316218cf51fc8d9ed832f2daf18b73",
    );
}

#[test]
fn aaaaaaaaaa_100000() {
    test_hash_str(
        &"aaaaaaaaaa".repeat(100000),
        "34aa973cd4c4daa4f61eeb2bdbad27316534016f",
        "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
    );
}

#[test]
fn alphabet_100000() {
    test_hash_str(
        &"abcdefghijklmnopqrstuvwxyz".repeat(100000),
        "e7da7c55b3484fdf52aebec9cbe7b85a98f02fd4",
        "e406ba321ca712ad35a698bf0af8d61fc4dc40eca6bdcea4697962724ccbde35",
    );
}

#[test]
fn zero_blob_literal() {
    test_hash_literal(
        b"blob 0\0",
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813",
    );
}

#[test]
fn three_blob_literal() {
    test_hash_literal(
        b"blob 3\0abc",
        "f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f",
        "c1cf6e465077930e88dc5136641d402f72a229ddd996f627d60e9639eaba35a6",
    );
}

#[test]
fn zero_tree_literal() {
    test_hash_literal(
        b"tree 0\0",
        "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
        "6ef19b41225c5369f1c104d45d8d85efa9b057b53b14b4b9b939dd74decc5321",
    );
}
