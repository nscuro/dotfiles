#!/bin/sh
# Attribute async-profiler `collapsed` output down the stack, not at the leaf.
#   tree.sh FILE [N]       top N frames by *inclusive* total -- self plus everything below
#   tree.sh FILE FRAME     direct children of FRAME, biggest first -- where its total went
# FRAME matches a whole frame or its trailing `.method`, so a bare method name usually
# suffices and `processBom` will not silently match `processBomAsync`. Falls back to
# substring matching, with a warning on stderr, only when nothing matches that way.
# One method can appear as several consecutive frames in one stack, `Foo.bar_[i]` above
# `Foo.bar_[j]`, when the JIT inlined it into itself. Both views collapse those to one
# method, so a hot method does not report itself as its own child, or occupy two rows.
# TREE_PKG=org.foo restricts the inclusive view to frames containing that string.
# Percentages stay relative to the whole profile, so the filtered rows still add up
# against it. Without the filter the inclusive top is launcher, reflection and framework
# wrappers by construction, since every one of them encloses everything below.
# Counter unit is whatever the profile used: samples, or bytes if `total` was set.
set -eu

die() { echo "tree.sh: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: tree.sh FILE [N] | tree.sh FILE FRAME"
[ -r "$1" ] && [ ! -d "$1" ] || die "cannot read $1"

pre='
  function bare(s) { sub(/_\[[0-9A-Za-z]\]$/, "", s); return s }
  # First frame below i that is a different method than the one at i.
  function childOf(i,   g, j) {
    g = bare(f[i]); j = i + 1
    while (j <= n && bare(f[j]) == g) j++
    if (j > n) return "(self)"
    if (!(bare(f[j]) in label)) label[bare(f[j])] = f[j]
    return bare(f[j]) }
  { i = match($0, / [0-9]+$/); if (!i) next
    c = substr($0, i + 1) + 0
    n = split(substr($0, 1, i - 1), f, ";") }
'

case "${2-25}" in
  *[!0-9]*)
    out=$(awk "$pre"'
      { for (i = 1; i <= n; i++) {
          g = bare(f[i])
          if (g == key || (length(g) > length(key) &&
              substr(g, length(g) - length(key)) == "." key)) {
            xk[childOf(i)] += c; xt += c; break } }
        for (i = 1; i <= n; i++)
          if (index(f[i], key)) { sk[childOf(i)] += c; st += c; break } }
      END {
        if (xt) { for (k in xk)
          printf "%6.2f%%  %12d  %s\n", 100 * xk[k] / xt, xk[k], (k in label ? label[k] : k); exit }
        if (st) {
          printf "tree.sh: no frame named %s, fell back to substring match\n", key > "/dev/stderr"
          for (k in sk)
            printf "%6.2f%%  %12d  %s\n", 100 * sk[k] / st, sk[k], (k in label ? label[k] : k) } }' \
      key="$2" "$1")
    [ -n "$out" ] || die "no stack contains $2"
    printf '%s\n' "$out" | sort -rn ;;
  *)
    out=$(awk "$pre"'
      { delete seen
        for (i = 1; i <= n; i++) {
          g = bare(f[i]); if (g in seen) continue
          seen[g]; incl[g] += c; if (!(g in label)) label[g] = f[i] }
        tot += c }
      END { for (k in incl) { if (pkg != "" && !index(k, pkg)) continue
        printf "%6.2f%%  %12d  %s\n", 100 * incl[k] / tot, incl[k], label[k] } }' \
      pkg="${TREE_PKG-}" "$1")
    [ -n "$out" ] || die "no samples in $1${TREE_PKG:+ under $TREE_PKG}"
    printf '%s\n' "$out" | sort -rn | head -"${2:-25}" ;;
esac
