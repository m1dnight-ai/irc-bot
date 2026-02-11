#!/usr/bin/env bash
#
# work_issue.sh — Pick the oldest unassigned GitHub issue, implement it with
# Claude Code, run tests, push a branch, create a PR, and restart the dev server.
#
# Usage:  ./scripts/work_issue.sh
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth login)
#   - claude CLI at ~/.local/bin/claude
#   - mise-managed Elixir via ~/.local/bin/mixe
#
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────
CLAUDE="$HOME/.local/bin/claude"
MIXE="$HOME/.local/bin/mixe"
PROJECT_DIR="$HOME/irc-bot"
REPO="m1dnight-ai/irc-bot"
DEFAULT_BRANCH="main"
MAX_BUDGET="5.00"

# ── Logging ──────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────
command -v gh  >/dev/null 2>&1 || die "gh CLI not found. Install: sudo apt install gh"
command -v jq  >/dev/null 2>&1 || die "jq not found. Install: sudo apt install jq"
[[ -x "$CLAUDE" ]]            || die "claude CLI not found at $CLAUDE"
[[ -x "$MIXE" ]]              || die "mixe wrapper not found at $MIXE"
[[ -d "$PROJECT_DIR/.git" ]]  || die "$PROJECT_DIR is not a git repository"

gh auth status >/dev/null 2>&1 || die "gh not authenticated. Run: gh auth login"

cd "$PROJECT_DIR"

# ── Ensure clean worktree and switch to main ─────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  log "Uncommitted changes detected. Committing on current branch..."
  git add -A
  git commit -m "chore: auto-commit uncommitted changes before work_issue run" || true
fi

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  log "On branch ${CURRENT_BRANCH}, switching to ${DEFAULT_BRANCH}..."
  git checkout "$DEFAULT_BRANCH"
fi

git pull origin "$DEFAULT_BRANCH"

# ── Step 1: Find oldest open unassigned issue without a PR ───────────
log "Searching for oldest open unassigned issue..."

# Get issue numbers that already have an open PR (body contains "Closes #N")
ISSUES_WITH_PRS=$(gh pr list --repo "$REPO" --state open --json body \
  --jq '[.[].body | capture("#(?<num>[0-9]+)") | .num] | unique | .[]')

ISSUES_JSON=$(gh issue list \
  --repo "$REPO" \
  --state open \
  --assignee "" \
  --json number,title,body,labels \
  --limit 100 \
  --jq 'sort_by(.number)')

ISSUE_JSON=""
ISSUE_NUMBER=""

ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq 'length')
for (( i=0; i<ISSUE_COUNT; i++ )); do
  num=$(echo "$ISSUES_JSON" | jq -r ".[$i].number")
  if ! echo "$ISSUES_WITH_PRS" | grep -qx "$num"; then
    ISSUE_JSON=$(echo "$ISSUES_JSON" | jq -c ".[$i]")
    ISSUE_NUMBER="$num"
    break
  fi
done

if [[ -z "$ISSUE_NUMBER" ]]; then
  log "No open unassigned issues without PRs found. Nothing to do."
  exit 0
fi

ISSUE_TITLE=$(echo "$ISSUE_JSON"  | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON"   | jq -r '.body // ""')
ISSUE_LABELS=$(echo "$ISSUE_JSON" | jq -r '(.labels // []) | map(.name) | join(", ")')

log "Found issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}"

# ── Step 2: Assign issue to current user ─────────────────────────────
GH_USER=$(gh api user --jq '.login')
log "Assigning issue #${ISSUE_NUMBER} to ${GH_USER}..."
gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-assignee "$GH_USER"

# ── Step 3: Announce plan and mark in-progress ────────────────────────
log "Generating implementation plan for issue #${ISSUE_NUMBER}..."

PLAN=$("$CLAUDE" -p --max-budget-usd 0.50 \
  "Given this GitHub issue for an Elixir/Phoenix IRC bot project, write a brief plan (3-5 bullet points) of what you will implement. Be specific about files and modules. Do not use markdown headers, just bullet points.

Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}

${ISSUE_BODY}")

log "Posting plan comment on issue #${ISSUE_NUMBER}..."
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<COMMENT_EOF
I will take care of this!

Here's my plan:
${PLAN}
COMMENT_EOF
)"

log "Adding 'in progress' label to issue #${ISSUE_NUMBER}..."
gh label create "in progress" --repo "$REPO" --color "ededed" --description "Work is underway" 2>/dev/null || true
gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-label "in progress"

# ── Step 4: Create feature branch ───────────────────────────────────
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-50
}

SLUG=$(slugify "$ISSUE_TITLE")
BRANCH="issue-${ISSUE_NUMBER}-${SLUG}"

log "Creating branch: ${BRANCH}"

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  log "Branch ${BRANCH} already exists locally. Deleting it..."
  git branch -D "$BRANCH"
fi

git checkout -b "$BRANCH"

# ── Step 5: Invoke Claude Code ───────────────────────────────────────
log "Invoking Claude Code to implement issue #${ISSUE_NUMBER}..."

read -r -d '' PROMPT <<PROMPT_EOF || true
You are working on the IRC bot project (Elixir/Phoenix).

## GitHub Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}

${ISSUE_BODY}

## Labels
${ISSUE_LABELS}

## Your task

1. Read the existing codebase to understand the architecture (AGENTS.md, the plugin system, tests, etc.).
2. Implement the changes required by this issue. Follow all conventions in AGENTS.md.
3. All mix commands must be run through: $HOME/.local/bin/mixe mix <command>
   For example: $HOME/.local/bin/mixe mix test
   Do NOT use bare "mix" -- it will use the wrong Elixir version.
4. Write or update tests for your changes.
5. Run the full test suite with: $HOME/.local/bin/mixe mix test
   Fix any failures before proceeding.
6. Run: $HOME/.local/bin/mixe mix format
   Fix any formatting issues.
7. Commit your changes with a descriptive commit message referencing issue #${ISSUE_NUMBER}.
   Use conventional commit style, e.g.: "feat: add XYZ plugin (closes #${ISSUE_NUMBER})"
8. Do NOT push or create PRs -- the calling script handles that.

Important constraints:
- This is an Elixir/Phoenix 1.8 project using SQLite (ecto_sqlite3).
- The plugin system uses IrcBot.Plugin behaviour + IrcBot.Plugin.Registry.
- ExIRC is used for IRC connectivity.
- Mox is used for test mocking.
- Never use bare "mix" commands. Always use $HOME/.local/bin/mixe mix <command>.
PROMPT_EOF

"$CLAUDE" -p \
  --permission-mode bypassPermissions \
  --max-budget-usd "$MAX_BUDGET" \
  "$PROMPT"

# ── Step 6: Verify tests pass ───────────────────────────────────────
log "Running test suite to verify implementation..."
"$MIXE" mix test || die "Tests failed after implementation. Branch ${BRANCH} needs manual fixes."

# ── Step 7: Push branch and create PR ───────────────────────────────
log "Pushing branch ${BRANCH} to origin..."
git push -u --force-with-lease origin "$BRANCH"

log "Creating pull request..."
PR_URL=$(gh pr create \
  --repo "$REPO" \
  --base "$DEFAULT_BRANCH" \
  --head "$BRANCH" \
  --title "Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}" \
  --body "$(cat <<PR_EOF
## Issue

Closes #${ISSUE_NUMBER}

## Summary

Automated implementation of: **${ISSUE_TITLE}**

${ISSUE_BODY}

---

> This PR was generated by \`scripts/work_issue.sh\` using Claude Code.
> Please review carefully before merging.
PR_EOF
)")

log "Pull request created: ${PR_URL}"

# Assign the PR to the same user
PR_NUMBER=$(basename "$PR_URL")
log "Assigning PR #${PR_NUMBER} to ${GH_USER}..."
gh pr edit "$PR_NUMBER" --repo "$REPO" --add-assignee "$GH_USER"

# ── Step 8: Restart dev server ──────────────────────────────────────
log "Restarting dev server..."

PIDS=$(pgrep -f "phx.server" 2>/dev/null || true)
if [[ -n "$PIDS" ]]; then
  log "Stopping existing phx.server (PIDs: ${PIDS})..."
  kill $PIDS 2>/dev/null || true
  sleep 2
  kill -9 $PIDS 2>/dev/null || true
fi

log "Starting phx.server in background..."
PORT=80 nohup "$MIXE" mix phx.server > /tmp/irc_bot_phx.log 2>&1 &
log "phx.server started (PID: $!, log: /tmp/irc_bot_phx.log)"

# ── Done ─────────────────────────────────────────────────────────────
log "Done! Issue #${ISSUE_NUMBER} implemented."
log "PR: ${PR_URL}"
log "Branch: ${BRANCH}"
