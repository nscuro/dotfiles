#!/bin/sh
# Aggregate async-profiler `collapsed` output by leaf (self) frame.
#   hot.sh FILE [N]           top N self frames (default 25)
#   hot.sh BEFORE AFTER [N]   delta between two profiles, biggest change first
# Counter unit is whatever the profile used: samples, or bytes if `total` was set.
# HOT_DEPTH=2 aggregates one frame below the leaf (the caller) -- needed for `alloc`
# profiles, where the leaf frame is the allocated *type*, not the allocation site.
set -eu

agg='
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    n = split(substr($0, 1, i - 1), f, ";")
    d = ENVIRON["HOT_DEPTH"] + 0; if (d < 1) d = 1
    j = n - d + 1; if (j < 1) j = 1
    self[FILENAME "\t" f[j]] += c; tot[FILENAME] += c }
'

case "$([ -f "${2-}" ] && echo diff || echo top)" in
  top)
    awk "$agg"'END { for (k in self) { split(k, p, "\t")
      printf "%6.2f%%  %12d  %s\n", 100 * self[k] / tot[p[1]], self[k], p[2] } }' "$1" \
      | sort -rn | head -"${2:-25}" ;;
  diff)
    awk "$agg"'END {
      for (k in self) { split(k, p, "\t"); if (p[1] == a) A[p[2]] = self[k]; else B[p[2]] = self[k] }
      for (k in A) K[k]; for (k in B) K[k]
      for (k in K) { d = B[k] - A[k]; if (d == 0) continue
        printf "%d\t%+12d  %12d -> %-12d  %s\n", (d < 0 ? -d : d), d, A[k], B[k], k } }' \
      a="$1" "$1" "$2" | sort -rn | cut -f2- | head -"${3:-25}" ;;
esac
