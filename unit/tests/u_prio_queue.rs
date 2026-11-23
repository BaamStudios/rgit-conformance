// SPDX-License-Identifier: GPL-2.0-only
//
// rgit-conformance: ported from git v2.56.1, path t/unit-tests/u-prio-queue.c
// (https://github.com/git/git/blob/v2.56.1/t/unit-tests/u-prio-queue.c).
// GPL-2.0, see LICENSE.
//
// Same cases and expected values as upstream, run against
// `rgit_revwalk::PrioQueue`. Upstream switches the queue to LIFO mode by
// clearing its compare function (`STACK`); every case does that first, on
// the empty queue, so the port starts with `PrioQueue::lifo()` instead.
// `REPLACE` is `PrioQueue::replace` (get, then put).

use rgit_revwalk::PrioQueue;

const MISSING: i32 = -1;
const DUMP: i32 = -2;
const STACK: i32 = -3;
const GET: i32 = -4;
const REVERSE: i32 = -5;
const REPLACE: i32 = -6;

fn show(v: Option<i32>) -> i32 {
    v.unwrap_or(MISSING)
}

fn test_prio_queue(input: &[i32], result: &[i32]) {
    let mut pq = if input.first() == Some(&STACK) {
        PrioQueue::lifo()
    } else {
        PrioQueue::new(|a: &i32, b: &i32| a.cmp(b))
    };
    let mut got = Vec::new();
    let mut i = 0;
    while i < input.len() {
        match input[i] {
            GET => {
                let peek = pq.peek().copied();
                let get = pq.get();
                assert_eq!(peek, get);
                got.push(show(get));
            }
            DUMP => {
                while let Some(peek) = pq.peek().copied() {
                    let get = pq.get();
                    assert_eq!(Some(peek), get);
                    got.push(show(get));
                }
            }
            STACK => assert_eq!(i, 0, "STACK only on the empty queue"),
            REVERSE => pq.reverse(),
            REPLACE => {
                assert!(i + 1 < input.len() && input[i + 1] >= 0);
                i += 1;
                got.push(show(pq.replace(input[i])));
            }
            v => pq.put(v),
        }
        i += 1;
    }
    assert_eq!(got, result);
}

#[test]
fn basic() {
    test_prio_queue(
        &[2, 6, 3, 10, 9, 5, 7, 4, 5, 8, 1, DUMP],
        &[1, 2, 3, 4, 5, 5, 6, 7, 8, 9, 10],
    );
}

#[test]
fn mixed() {
    test_prio_queue(&[6, 2, 4, GET, 5, 3, GET, GET, 1, DUMP], &[2, 3, 4, 1, 5, 6]);
}

#[test]
fn empty() {
    test_prio_queue(
        &[1, 2, GET, GET, GET, 1, 2, GET, GET, GET],
        &[1, 2, MISSING, 1, 2, MISSING],
    );
}

#[test]
fn replace() {
    test_prio_queue(
        &[REPLACE, 6, 2, 4, REPLACE, 5, 7, GET, REPLACE, 1, DUMP],
        &[MISSING, 2, 4, 5, 1, 6, 7],
    );
}

#[test]
fn stack() {
    test_prio_queue(&[STACK, 8, 1, 5, 4, 6, 2, 3, DUMP], &[3, 2, 6, 4, 5, 1, 8]);
}

#[test]
fn reverse_stack() {
    test_prio_queue(&[STACK, 1, 2, 3, 4, 5, 6, REVERSE, DUMP], &[1, 2, 3, 4, 5, 6]);
}

#[test]
fn replace_stack() {
    test_prio_queue(
        &[STACK, 8, 1, 5, REPLACE, 4, 6, 2, 3, DUMP],
        &[5, 3, 2, 6, 4, 1, 8],
    );
}
