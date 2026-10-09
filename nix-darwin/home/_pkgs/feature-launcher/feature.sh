usage() {
  cat <<'EOF'
feature - open a ticket's worktree and start its feature lead there

Usage:
  feature <branch> <brief>

Creates <branch> off the default branch with `wt switch --create`, which runs
the repo's worktrunk hooks (seeding included), opens a herdr tab in the new
worktree, and starts `claude --agent feature-lead "<brief>"` in it. Never
starts the app. Refuses when the branch already has a worktree.

Blocks until the worktree is ready: when the repo uses direnv, it waits for
the setup hooks to write .envrc, then loads the environment once, which can
take several minutes. Run it in the background from an agent.

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

primary="$(git worktree list --porcelain | awk 'NR == 1 && /^worktree / { print $2 }')"
if [ -e "$primary/.envrc" ]; then
  echo "waiting for the worktree's setup hooks to write .envrc"
  for _ in $(seq 1 120); do
    [ -e "$path/.envrc" ] && break
    sleep 1
  done
  [ -e "$path/.envrc" ] || die "no .envrc in $path after 2 minutes; check wt config state logs"
  echo "loading the dev environment once, which can take several minutes"
  direnv allow "$path"
  (cd "$path" && direnv exec . true)
fi

pane="$(herdr tab create --cwd "$path" --label "$name" --no-focus | jq -r '.result.root_pane.pane_id')"
[ -n "$pane" ] && [ "$pane" != null ] || die "could not open a herdr tab in $path"

herdr agent start "$name" --kind claude --pane "$pane" --timeout 300000 -- --agent feature-lead "$brief" >/dev/null

echo "worktree: $path"
echo "pane:     $pane"
