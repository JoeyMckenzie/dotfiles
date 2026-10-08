usage() {
  cat <<'EOF'
feature - open a ticket's worktree and start its product manager there

Usage:
  feature <branch> <brief>

Creates <branch> off the default branch with `wt switch --create`, which runs
the repo's worktrunk hooks (seeding included), opens a herdr tab in the new
worktree, and starts `claude --agent product-manager "<brief>"` in it. Never
starts the app. Refuses when the branch already has a worktree.

Run it inside herdr, from any checkout of the repo.
EOF
}

die() {
  echo "feature: $*" >&2
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi
[ $# -eq 2 ] || { usage >&2; exit 1; }

branch="$1"
brief="$2"

[ -n "$brief" ] || die "the brief is empty"
[ "${HERDR_ENV:-}" = 1 ] || die "not running inside herdr"

if git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
  die "$branch already has a worktree"
fi

wt switch --create "$branch" --no-cd

path="$(wt list --format=json | jq -r --arg b "$branch" '.items[] | select(.branch == $b) | .worktree.path')"
[ -n "$path" ] && [ -d "$path" ] || die "could not find the worktree for $branch"
name="$(basename "$path")"

pane="$(herdr tab create --cwd "$path" --label "$name" --no-focus | jq -r '.result.root_pane.pane_id')"
[ -n "$pane" ] && [ "$pane" != null ] || die "could not open a herdr tab in $path"

herdr agent start "$name" --kind claude --pane "$pane" -- --agent product-manager "$brief" >/dev/null

echo "worktree: $path"
echo "pane:     $pane"
