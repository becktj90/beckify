#!/usr/bin/env bash
# List remote branches that are behind main, or that carry commits main does not have.
# Usage: scripts/branch-drift.sh [--markdown] [--days N]
#   --days N   Only flag an unmerged branch once its last commit is N days old (default 3).
# A branch that is behind main needs main merged in. A branch that is ahead and old needs a squash merge
# or deleting. Branches whose merge into main would change nothing (squash-merged ones) are skipped.
set -euo pipefail

format=text
days=3
while [ $# -gt 0 ]; do
  case "$1" in
    --markdown) format=markdown ;;
    --days) days="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

base="origin/main"
git rev-parse --verify --quiet "$base" >/dev/null || { echo "no $base; run git fetch origin main" >&2; exit 2; }

now=$(date +%s)
rows=()
while IFS= read -r ref; do
  name="${ref#origin/}"
  [ "$name" = "main" ] && continue
  [ "$name" = "HEAD" ] && continue
  behind=$(git rev-list --count "$ref..$base")
  ahead=$(git rev-list --count "$base..$ref")
  # A squash-merged branch still looks "ahead". Merging it into main would change nothing, so it is done.
  # merge-tree compares what the merge would produce against main's own tree, which survives later commits on main.
  if [ "$ahead" -gt 0 ]; then
    merged_tree=$(git merge-tree --write-tree "$base" "$ref" 2>/dev/null || true)
    if [ -n "$merged_tree" ] && [ "$merged_tree" = "$(git rev-parse "$base^{tree}")" ]; then continue; fi
  fi
  [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ] && continue
  stamp=$(git log -1 --format=%ct "$ref")
  age=$(( (now - stamp) / 86400 ))
  last=$(git log -1 --format=%cs "$ref")
  state=""
  if [ "$ahead" -gt 0 ] && [ "$age" -ge "$days" ]; then state="unmerged ${age}d"; fi
  if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then state="${state:+$state, }behind main by $behind"; fi
  if [ "$ahead" -eq 0 ] && [ "$behind" -gt 0 ]; then state="fully merged, delete"; fi
  [ -z "$state" ] && continue
  rows+=("$name|$ahead|$behind|$last|$state")
done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)

if [ "$format" = markdown ]; then
  echo "Branches that are behind \`main\` or have sat unmerged. Squash-merge them, merge \`main\` in, or delete them."
  echo
  if [ "${#rows[@]}" -eq 0 ]; then echo "None."; exit 0; fi
  echo "| Branch | Ahead | Behind | Last commit | Needs |"
  echo "| --- | --- | --- | --- | --- |"
  for row in "${rows[@]}"; do
    IFS='|' read -r name ahead behind last state <<<"$row"
    echo "| \`$name\` | $ahead | $behind | $last | $state |"
  done
else
  if [ "${#rows[@]}" -eq 0 ]; then echo "No stale branches."; exit 0; fi
  printf '%-52s %6s %7s  %-10s  %s\n' BRANCH AHEAD BEHIND LAST NEEDS
  for row in "${rows[@]}"; do
    IFS='|' read -r name ahead behind last state <<<"$row"
    printf '%-52s %6s %7s  %-10s  %s\n' "$name" "$ahead" "$behind" "$last" "$state"
  done
fi
