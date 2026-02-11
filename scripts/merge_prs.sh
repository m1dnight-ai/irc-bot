#!/usr/bin/env bash
#
# merge_prs.sh — Merge all approved open PRs, update local main, and restart the server.
# Handles conflicts automatically by rebasing PR branches on main before merging.
#
# Usage:  ./scripts/merge_prs.sh
#
set -euo pipefail

MIXE="$HOME/.local/bin/mixe"
PROJECT_DIR="$HOME/irc-bot"
REPO="m1dnight-ai/irc-bot"
DEFAULT_BRANCH="main"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

cd "$PROJECT_DIR"

# ── Ensure clean worktree and get on main ────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  log "Uncommitted changes detected. Committing..."
  git add -A
  git commit -m "chore: auto-commit before merge_prs" || true
fi

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  log "On branch ${CURRENT_BRANCH}, switching to ${DEFAULT_BRANCH}..."
  git checkout "$DEFAULT_BRANCH"
fi

# Push any unpushed local main commits
git pull --rebase origin "$DEFAULT_BRANCH"
git push origin "$DEFAULT_BRANCH" 2>/dev/null || true

# ── Find approved PRs ───────────────────────────────────────────────
log "Checking for approved PRs..."

APPROVED=$(gh pr list --repo "$REPO" --state open \
  --json number,title,headRefName,reviews \
  --jq '[.[] | select(.reviews | map(select(.state == "APPROVED")) | length > 0)]')

COUNT=$(echo "$APPROVED" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  log "No approved PRs to merge."
  exit 0
fi

log "Found ${COUNT} approved PR(s)."

# ── Merge each PR (rebase if conflicting) ────────────────────────────
echo "$APPROVED" | jq -c '.[]' | while IFS= read -r row; do
  PR_NUM=$(echo "$row" | jq -r '.number')
  PR_TITLE=$(echo "$row" | jq -r '.title')
  PR_BRANCH=$(echo "$row" | jq -r '.headRefName')

  log "Processing PR #${PR_NUM}: ${PR_TITLE} (branch: ${PR_BRANCH})..."

  # Check if mergeable
  MERGEABLE=$(gh pr view "$PR_NUM" --repo "$REPO" --json mergeable --jq '.mergeable')

  if [[ "$MERGEABLE" == "CONFLICTING" ]]; then
    log "PR #${PR_NUM} has conflicts. Rebasing on ${DEFAULT_BRANCH}..."

    git fetch origin "$PR_BRANCH"
    git checkout -B "$PR_BRANCH" "origin/${PR_BRANCH}"

    if git rebase "$DEFAULT_BRANCH"; then
      git push --force-with-lease origin "$PR_BRANCH"
      log "Rebased and pushed ${PR_BRANCH}."

      # Wait for GitHub to recompute mergeability
      sleep 5
    else
      log "WARNING: Rebase failed for PR #${PR_NUM}. Aborting rebase and skipping."
      git rebase --abort
      git checkout "$DEFAULT_BRANCH"
      continue
    fi

    git checkout "$DEFAULT_BRANCH"
  fi

  # Merge the PR
  log "Merging PR #${PR_NUM}..."
  if gh pr merge "$PR_NUM" --repo "$REPO" --merge --delete-branch; then
    log "PR #${PR_NUM} merged."
    # Update local main with the merge
    git pull origin "$DEFAULT_BRANCH"
  else
    log "WARNING: Failed to merge PR #${PR_NUM}. Skipping."
  fi
done

# ── Update local and rebuild ─────────────────────────────────────────
log "Updating local ${DEFAULT_BRANCH}..."
git checkout "$DEFAULT_BRANCH" 2>/dev/null || true
git pull origin "$DEFAULT_BRANCH"

log "Rebuilding..."
"$MIXE" mix deps.get
"$MIXE" mix compile

log "Restarting Phoenix server..."
PIDS=$(pgrep -f "phx.server" 2>/dev/null || true)
if [[ -n "$PIDS" ]]; then
  kill $PIDS 2>/dev/null || true
  sleep 2
  kill -9 $PIDS 2>/dev/null || true
fi

PORT=80 nohup "$MIXE" mix phx.server > /tmp/irc_bot_phx.log 2>&1 &
log "Phoenix server restarted (PID: $!)."

log "Done!"
