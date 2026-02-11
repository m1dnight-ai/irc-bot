#!/usr/bin/env bash
#
# merge_prs.sh — Merge all approved open PRs, update local main, and restart the server.
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

log "Checking for approved PRs..."

APPROVED=$(gh pr list --repo "$REPO" --state open \
  --json number,title,reviews \
  --jq '[.[] | select(.reviews | map(select(.state == "APPROVED")) | length > 0)]')

COUNT=$(echo "$APPROVED" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  log "No approved PRs to merge."
  exit 0
fi

log "Found ${COUNT} approved PR(s)."

echo "$APPROVED" | jq -c '.[]' | while IFS= read -r row; do
  PR_NUM=$(echo "$row" | jq -r '.number')
  PR_TITLE=$(echo "$row" | jq -r '.title')
  log "Merging PR #${PR_NUM}: ${PR_TITLE}..."
  if gh pr merge "$PR_NUM" --repo "$REPO" --merge --delete-branch; then
    log "PR #${PR_NUM} merged."
  else
    log "WARNING: Failed to merge PR #${PR_NUM}. Skipping."
  fi
done

log "Updating local ${DEFAULT_BRANCH}..."

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "chore: auto-commit before merge_prs" || true
fi

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  git checkout "$DEFAULT_BRANCH"
fi

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
