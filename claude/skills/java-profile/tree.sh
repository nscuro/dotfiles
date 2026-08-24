#!/bin/sh
# Attribute async-profiler `collapsed` output down the stack, not at the leaf.
#   tree.sh FILE [N]       top N frames by *inclusive* total -- self plus everything below
#   tree.sh FILE FRAME     direct children of FRAME, biggest first -- where its total went
# FRAME is matched as a literal substring, so a bare method name usually suffices.
# Counter unit is whatever the profile used: samples, or bytes if `total` was set.
set -eu

pre='
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    n = split(substr($0, 1, i - 1), f, ";") }
'

case "${2-25}" in
  *[!0-9]*)
    awk "$pre"'
      { for (i = 1; i <= n; i++)
          if (index(f[i], key)) { kid[i < n ? f[i + 1] : "(self)"] += c; tot += c; break } }
      END { if (!tot) { print "tree.sh: no stack contains " key > "/dev/stderr"; exit 1 }
        for (k in kid) printf "%6.2f%%  %12d  %s\n", 100 * kid[k] / tot, kid[k], k }' \
      key="$2" "$1" | sort -rn ;;
  *)
    awk "$pre"'
      { delete seen
        for (i = 1; i <= n; i++) if (!(f[i] in seen)) { seen[f[i]]; incl[f[i]] += c }
        tot += c }
      END { for (k in incl) printf "%6.2f%%  %12d  %s\n", 100 * incl[k] / tot, incl[k], k }' \
      "$1" | sort -rn | head -"${2:-25}" ;;
esac
