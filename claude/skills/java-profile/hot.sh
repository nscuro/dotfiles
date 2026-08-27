#!/bin/sh
# Aggregate async-profiler `collapsed` output by leaf (self) frame.
#   hot.sh FILE [N]           top N self frames (default 25)
#   hot.sh BEFORE AFTER [N]   delta between two profiles, biggest *share* change first
# Deltas are share of each profile's own total, so two runs of different length still
# compare. The raw counters are shown beside them, and both totals go to stderr.
# Counter unit is whatever the profile used: samples, or bytes if `total` was set.
# HOT_DEPTH=2 aggregates one frame below the leaf (the caller) -- needed for `alloc`
# profiles, where the leaf frame is the allocated *type*, not the allocation site.
set -eu

die() { echo "hot.sh: $*" >&2; exit 1; }
readable() { [ -r "$1" ] && [ ! -d "$1" ] || die "cannot read $1"; }

agg='
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    n = split(substr($0, 1, i - 1), f, ";")
    d = ENVIRON["HOT_DEPTH"] + 0; if (d < 1) d = 1
    j = n - d + 1; if (j < 1) j = 1
    self[FILENAME "\t" f[j]] += c; tot[FILENAME] += c }
'

[ $# -ge 1 ] || die "usage: hot.sh FILE [N] | hot.sh BEFORE AFTER [N]"
readable "$1"

case "${2-}" in
  *[!0-9]*)
    readable "$2"
    out=$(awk "$agg"'END {
      for (k in self) { split(k, p, "\t"); if (p[1] == a) A[p[2]] = self[k]; else B[p[2]] = self[k] }
      printf "hot.sh: %s = %d, %s = %d -- deltas are share of each total\n",
        a, tot[a], b, tot[b] > "/dev/stderr"
      for (k in A) K[k]; for (k in B) K[k]
      for (k in K) {
        pa = tot[a] ? 100 * A[k] / tot[a] : 0; pb = tot[b] ? 100 * B[k] / tot[b] : 0
        d = pb - pa; if (d > -0.005 && d < 0.005) continue
        printf "%f\t%+7.2f%%  %6.2f%% -> %-7s %12d -> %-12d  %s\n",
          (d < 0 ? -d : d), d, pa, sprintf("%.2f%%", pb), A[k], B[k], k } }' \
      a="$1" b="$2" "$1" "$2")
    [ -n "$out" ] || die "no frame changed by more than 0.01% of its profile"
    printf '%s\n' "$out" | sort -rn | cut -f2- | head -"${3:-25}" ;;
  *)
    out=$(awk "$agg"'END { for (k in self) { split(k, p, "\t")
      printf "%6.2f%%  %12d  %s\n", 100 * self[k] / tot[p[1]], self[k], p[2] } }' "$1")
    [ -n "$out" ] || die "no samples in $1 -- not a collapsed profile?"
    printf '%s\n' "$out" | sort -rn | head -"${2:-25}" ;;
esac
