// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-utf8-width.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-utf8-width.c).
// GPL-2.0, see LICENSE.
//
// Same cases and expected values as upstream, run against
// `rgit_messages::width`: `utf8_strnwidth(s, len, skip_ansi)` is
// `display_width(&s[..len])` with `skip_ansi` and `display_width_raw`
// without, `utf8_strwidth` is `display_width_raw`, `strbuf_utf8_align` is
// `align` (`ALIGN_LEFT`/`ALIGN_MIDDLE`/`ALIGN_RIGHT` are `Align::*`).

use rgit_messages::width::{Align, align, display_width, display_width_raw};

fn strnwidth(s: &str, len: usize, skip_ansi: bool) -> usize {
    let s = &s[..len];
    if skip_ansi {
        display_width(s)
    } else {
        display_width_raw(s)
    }
}

fn strwidth(s: &str) -> usize {
    display_width_raw(s)
}

#[test]
fn strnwidth_chinese() {
    assert_eq!(5, strnwidth("Hello", 5, false));
    assert_eq!(5, strnwidth("Hello", 5, true));
    assert_eq!(4, strnwidth("你好", 6, false));
    assert_eq!(6, strnwidth("Hi你好", 8, false));
    assert_eq!(10, strnwidth("你好世界！", 15, false));
    assert_eq!(2, strnwidth("中", 3, false));
    assert_eq!(0, strnwidth("", 0, false));
    let s = "你好世界";
    assert_eq!(2, strnwidth(s, 3, false));
    assert_eq!(4, strnwidth(s, 6, false));
}

#[test]
fn strwidth_chinese() {
    assert_eq!(5, strwidth("Hello"));
    assert_eq!(4, strwidth("你好"));
    assert_eq!(10, strwidth("你好世界！"));
    assert_eq!(9, strwidth("Hello世界"));
    assert_eq!(7, strwidth("Hi世界!"));
}

#[test]
fn strnwidth_japanese_korean() {
    assert_eq!(10, strnwidth("こんにちは", 15, false));
    assert_eq!(10, strnwidth("안녕하세요", 15, false));
}

#[test]
fn strnwidth_cjk_with_ansi() {
    let s = "\x1b[1m你好\x1b[0m";
    assert_eq!(4, strnwidth(s, s.len(), true));
    let s = "Hello\x1b[32m世界\x1b[0m!";
    assert_eq!(10, strnwidth(s, s.len(), true));
}

#[test]
fn strbuf_utf8_align() {
    assert_eq!("你好      ", align("你好", 10, Align::Left));
    assert_eq!("    世界", align("世界", 8, Align::Right));
    assert_eq!("    中    ", align("中", 10, Align::Middle));
    assert_eq!(" 中  ", align("中", 5, Align::Middle));
    assert_eq!("你好", align("你好", 2, Align::Left));
}
