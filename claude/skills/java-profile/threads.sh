#!/bin/sh
# Split async-profiler `collapsed` output by thread.
#   threads.sh FILE          per-thread-name totals, biggest first
#   threads.sh FILE NAME     that thread's stacks, thread prefix stripped, to stdout
# Needs a profile converted with `-t` (jfrconv), so every line starts with `[<name> tid=<n>];`.
# Totals roll up by name: `GC Thread#0..8` becomes one row, as do the compiler threads,
# since the tid and the pool index change every run and a per-tid list hides a pool that
# outweighs the workload. NAME is matched as a literal substring of the *unrolled* prefix.
# Counter unit is whatever the profile used: samples, or bytes with `total`.
set -eu

die() { echo "threads.sh: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: threads.sh FILE [NAME]"
[ -r "$1" ] && [ ! -d "$1" ] || die "cannot read $1"

check='
  NR == 1 && substr($0, 1, 1) != "[" {
    print "threads.sh: no thread prefix -- reconvert with jfrconv -t" > "/dev/stderr"; exit 1 }
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    j = index($0, ";"); if (!j) next }
'

case "${2-}" in
  "")
    out=$(awk "$check"'
      { t = substr($0, 1, j - 1)
        sub(/ *tid=[0-9]+/, "", t); sub(/#?[0-9]+\]$/, "]", t)
        if (t == "[]") t = "[unnamed]"
        s[t] += c; tot += c }
      END { for (t in s) printf "%6.2f%%  %12d  %s\n", 100 * s[t] / tot, s[t], t }' "$1")
    [ -n "$out" ] || die "no samples in $1"
    printf '%s\n' "$out" | sort -rn ;;
  *)
    # Accept the rolled-up label the totals view prints, `[main]`, as well as `main`.
    key=${2#[}; key=${key%]}
    awk -v key="$key" "$check"'
      index(substr($0, 1, j - 1), key) { print substr($0, j + 1); n++ }
      END { if (!n) { print "threads.sh: no thread matches " key > "/dev/stderr"; exit 1 } }' "$1" ;;
esac
