// SPDX-License-Identifier: GPL-2.0-only
//! Port of git v2.56.1 `t/unit-tests/u-trailer.c` (GPL-2.0) to
//! `rgit-trailer`.
//!
//! Upstream walks the trailer block with `trailer_iterator`, which ignores
//! a `---` divider; here `rgit_trailer::parse` runs with `divider: false`
//! and the default configuration. Each item of the block is checked as
//! (raw line, key, value): trailer lines give their key and value, other
//! lines of the block the whole line as key and an empty value. rgit keeps
//! no raw text for trailer lines, so their raw form is only checked for
//! the lines that are not trailers.

use rgit_trailer::{Config, Line, ParseOptions, parse};

/// (raw, key, val) as in upstream's `struct contents`.
type Contents<'a> = &'a [(&'a str, &'a str, &'a str)];

fn t_trailer_iterator(msg: &str, expected: Contents<'_>) {
    let conf = Config::default();
    let opts = ParseOptions {
        divider: false,
        ..ParseOptions::default()
    };
    let info = parse(msg.as_bytes(), &conf, &opts);
    let lines = if info.found { &info.lines[..] } else { &[][..] };
    assert_eq!(lines.len(), expected.len(), "{msg:?}: {lines:?}");
    for (line, (raw, key, val)) in lines.iter().zip(expected) {
        match line {
            Line::Trailer(t) => {
                assert_eq!(t.token, key.as_bytes(), "{msg:?}");
                assert_eq!(t.value, val.as_bytes(), "{msg:?}");
            }
            Line::Other(text) => {
                assert_eq!(format!("{text}\n"), *raw, "{msg:?}");
                assert_eq!(text, key.as_bytes(), "{msg:?}");
                assert_eq!(*val, "", "{msg:?}");
            }
        }
    }
}

const FIXES_ACKED_REVIEWED: Contents<'static> = &[
    ("Fixes: x\n", "Fixes", "x"),
    ("Acked-by: x\n", "Acked-by", "x"),
    ("Reviewed-by: x\n", "Reviewed-by", "x"),
];

#[test]
fn empty_input() {
    t_trailer_iterator("", &[]);
}

#[test]
fn no_newline_start() {
    t_trailer_iterator("Fixes: x\nAcked-by: x\nReviewed-by: x\n", &[]);
}

#[test]
fn newline_start() {
    t_trailer_iterator("\nFixes: x\nAcked-by: x\nReviewed-by: x\n", FIXES_ACKED_REVIEWED);
}

#[test]
fn no_body_text() {
    t_trailer_iterator(
        "subject: foo bar\n\nFixes: x\nAcked-by: x\nReviewed-by: x\n",
        FIXES_ACKED_REVIEWED,
    );
}

#[test]
fn body_text_no_divider() {
    t_trailer_iterator(
        "my subject\n\nmy body which is long\nand contains some special\n\
         chars like : = ? !\nhello\n\n\
         Fixes: x\nAcked-by: x\nReviewed-by: x\nSigned-off-by: x\n",
        &[
            ("Fixes: x\n", "Fixes", "x"),
            ("Acked-by: x\n", "Acked-by", "x"),
            ("Reviewed-by: x\n", "Reviewed-by", "x"),
            ("Signed-off-by: x\n", "Signed-off-by", "x"),
        ],
    );
}

#[test]
fn body_no_divider_2nd_block() {
    // The last trailer block takes precedence over the first one.
    t_trailer_iterator(
        "my subject\n\nmy body which is long\nand contains some special\n\
         chars like : = ? !\nhello\n\n\
         Fixes: x\nAcked-by: x\nReviewed-by: x\nSigned-off-by: x\n\n\
         Helped-by: x\nSigned-off-by: x\n",
        &[
            ("Helped-by: x\n", "Helped-by", "x"),
            ("Signed-off-by: x\n", "Signed-off-by", "x"),
        ],
    );
}

#[test]
fn body_and_divider() {
    // The trailer still counts because the iterator ignores the divider.
    t_trailer_iterator(
        "my subject\n\nmy body which is long\nand contains some special\n\
         chars like : = ? !\nhello\n\n---\n\nSigned-off-by: x\n",
        &[("Signed-off-by: x\n", "Signed-off-by", "x")],
    );
}

#[test]
fn non_trailer_in_block() {
    // At least 25% trailers and a Git-generated one: a trailer block, and
    // every line of it is an item.
    t_trailer_iterator(
        "subject: foo bar\n\n\
         not a trailer line\nnot a trailer line\nnot a trailer line\n\
         Signed-off-by: x\n",
        &[
            ("not a trailer line\n", "not a trailer line", ""),
            ("not a trailer line\n", "not a trailer line", ""),
            ("not a trailer line\n", "not a trailer line", ""),
            ("Signed-off-by: x\n", "Signed-off-by", "x"),
        ],
    );
}

#[test]
fn too_many_non_trailers() {
    // Only 20% trailers: below the 25% threshold.
    t_trailer_iterator(
        "subject: foo bar\n\n\
         not a trailer line\nnot a trailer line\nnot a trailer line\n\
         not a trailer line\nSigned-off-by: x\n",
        &[],
    );
}

#[test]
fn one_non_trailer_no_git_trailers() {
    // 90% trailers, but the threshold only applies with a Git-generated
    // trailer.
    t_trailer_iterator(
        "subject: foo bar\n\n\
         Reviewed-by: x\nReviewed-by: x\nReviewed-by: x\n\
         Helped-by: x\nHelped-by: x\nHelped-by: x\n\
         Acked-by: x\nAcked-by: x\nAcked-by: x\n\
         not a trailer line\n",
        &[],
    );
}

#[test]
#[allow(non_snake_case)]
fn URL() {
    // URLs are not trailers.
    t_trailer_iterator("Subject: foo bar\n\nhttps://www.example.org\n", &[]);
}

#[test]
#[allow(non_snake_case)]
fn not_a_URL_space_after_separator() {
    t_trailer_iterator(
        "Subject: foo bar\n\nhttps: //www.example.org\n",
        &[("https: //www.example.org\n", "https", "//www.example.org")],
    );
}

#[test]
#[allow(non_snake_case)]
fn not_a_URL_space_before_separator() {
    t_trailer_iterator(
        "Subject: foo bar\n\nhttps ://www.example.org\n",
        &[("https ://www.example.org\n", "https", "//www.example.org")],
    );
}
