#!/bin/sh
# Split async-profiler `collapsed` output by thread.
#   threads.sh FILE          per-thread totals, biggest first
#   threads.sh FILE NAME     that thread's stacks, thread prefix stripped, to stdout
# Needs a profile converted with `-t` (jfrconv), so every line starts with `[<name> tid=<n>];`.
# NAME is matched as a literal substring of the prefix -- use `main`, not the tid, which
# changes every run. Counter unit is whatever the profile used: samples, or bytes with `total`.
set -eu

check='
  NR == 1 && substr($0, 1, 1) != "[" {
    print "threads.sh: no thread prefix -- reconvert with jfrconv -t" > "/dev/stderr"; exit 1 }
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    j = index($0, ";"); if (!j) next }
'

case "${2-}" in
  "")
    awk "$check"'{ s[substr($0, 1, j - 1)] += c }
      END { for (t in s) printf "%12d  %s\n", s[t], t }' "$1" | sort -rn ;;
  *)
    awk -v key="$2" "$check"'
      index(substr($0, 1, j - 1), key) { print substr($0, j + 1) }' "$1" ;;
esac
