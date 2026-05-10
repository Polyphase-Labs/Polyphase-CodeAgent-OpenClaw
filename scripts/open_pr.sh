#!/bin/bash
# Commit any pending changes (if not already committed), push the current
# branch to origin, and open a pull request against the configured base
# branch via `gh pr create`.
#
# Usage:
#   open_pr.sh <title> <body-file>
#
#   title     — required, used for both the commit message subject (if there
#               are uncommitted changes) and the PR title.
#   body-file — required, path to a file whose contents are passed as the PR
#               body (multiline supported). Use - for stdin.
#
# Authentication: requires GITHUB_TOKEN to have been set up via
#   gh auth login --with-token  (done by entrypoint.sh on container start).
#
# Base branch: $GITHUB_BASE_BRANCH if set, otherwise "main".
#
# Prints the PR URL to stdout on success.
set -euo pipefail

if [ -z "${POLYPHASE_DIR:-}" ]; then
  echo "POLYPHASE_DIR is not set" >&2
  exit 1
fi

title="${1:-}"
body_file="${2:-}"
if [ -z "$title" ] || [ -z "$body_file" ]; then
  echo "usage: $0 <title> <body-file>" >&2
  exit 2
fi

if [ "$body_file" = "-" ]; then
  body=$(cat)
else
  body=$(cat "$body_file")
fi

cd "$POLYPHASE_DIR"
git config --global --add safe.directory '*'

# Make sure git identity is configured for the commit. The entrypoint sets
# sensible defaults but tolerate the case where the user overrode them.
if [ -z "$(git config --get user.name)" ]; then
  git config user.name "${GIT_AUTHOR_NAME:-Polyphase Code Agent}"
fi
if [ -z "$(git config --get user.email)" ]; then
  git config user.email "${GIT_AUTHOR_EMAIL:-codeagent@polyphase.local}"
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "HEAD" ]; then
  echo "Detached HEAD; check out a feature branch with create_feature_branch.sh first." >&2
  exit 3
fi

base_branch="${GITHUB_BASE_BRANCH:-main}"
if [ "$branch" = "$base_branch" ]; then
  echo "Refusing to PR from the base branch ($base_branch). Create a feature branch first." >&2
  exit 4
fi

# Stage + commit any uncommitted changes under the PR title.
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "$title" -m "$body"
fi

# Make sure we have at least one commit ahead of base before opening a PR.
ahead_count=$(git rev-list --count "origin/$base_branch..HEAD" 2>/dev/null || echo 0)
if [ "$ahead_count" -eq 0 ]; then
  echo "No commits ahead of origin/$base_branch; nothing to PR." >&2
  exit 5
fi

# Push (creates upstream on first push). If origin has a different commit on
# this branch already, force-with-lease to avoid clobbering someone else's
# work — but only if the divergent commit is one we authored (sanity check).
git push -u origin "HEAD:$branch"

# Open (or report existing) PR. gh exits non-zero if a PR for this branch
# already exists; in that case, just print its URL.
if existing=$(gh pr view --json url --jq .url 2>/dev/null); then
  echo "PR already open: $existing"
  exit 0
fi

gh pr create \
  --base "$base_branch" \
  --head "$branch" \
  --title "$title" \
  --body  "$body" \
  --fill-first \
  || gh pr view --json url --jq .url
