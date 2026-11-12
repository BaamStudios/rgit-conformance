// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-dir.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-dir.c).
// GPL-2.0, see LICENSE.
//
// Partly ported:
// - `common_prefix_skips_excluded_pathspec_items` runs against
//   `rgit_pathspec::Pathspec::common_prefix`. Upstream fills the pathspec
//   items by hand; here the same three items are parsed from their command
//   line form (`:(exclude)` magic for the first one).
// - `within_depth` (the `--max-depth` limit of the directory walk) is not
//   ported yet: rgit has no counterpart until the directory walk lands
//   (rgit #37).

use rgit_pathspec::{ParseOptions, Pathspec};

#[test]
fn common_prefix_skips_excluded_pathspec_items() {
    let pathspec = Pathspec::parse(
        [":(exclude)unrelated/path", "foo/bar", "foo/baz"],
        &ParseOptions::default(),
    )
    .expect("valid pathspec");
    assert_eq!(pathspec.len(), 3);
    assert!(pathspec.items()[0].is_exclude());
    assert_eq!(pathspec.items()[0].nowildcard_len(), 14);
    assert_eq!(pathspec.items()[1].nowildcard_len(), 7);
    assert_eq!(pathspec.items()[2].nowildcard_len(), 7);
    assert_eq!(pathspec.common_prefix(), b"foo/");
}
