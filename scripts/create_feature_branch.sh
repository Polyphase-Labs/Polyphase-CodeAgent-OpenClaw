#!/bin/bash
# Create a new feature branch under development/features/<scope>/<slug>-<short-id>.
# <short-id> is a random 6-hex suffix so concurrent agent sessions never collide
# on the same scope+slug pair. Prints the chosen branch name on stdout so the
# caller can capture it.
#
# Usage:
#   create_feature_branch.sh <scope> <slug>
#
# Example:
#   create_feature_branch.sh scripting lua-coroutine-helpers
#   → development/features/scripting/lua-coroutine-helpers-a1b2c3
set -euo pipefail

if [ -z "${POLYPHASE_DIR:-}" ]; then
  echo "POLYPHASE_DIR is not set" >&2
  exit 1
fi

scope="${1:-}"
slug="${2:-}"
if [ -z "$scope" ] || [ -z "$slug" ]; then
  echo "usage: $0 <scope> <slug>" >&2
  exit 2
fi

# Sanitise: lowercase, kebab-case-safe characters only.
sanitise() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/--+/-/g; s/^-+|-+$//g'
}
scope=$(sanitise "$scope")
slug=$(sanitise "$slug")

if [ -z "$scope" ] || [ -z "$slug" ]; then
  echo "scope/slug sanitised to empty; pick something with letters/digits" >&2
  exit 3
fi

short_id=$(head -c 12 /dev/urandom | xxd -p | cut -c1-6)
branch="development/features/${scope}/${slug}-${short_id}"

cd "$POLYPHASE_DIR"

# Make sure we're starting from a clean, up-to-date base.
base_branch="${GITHUB_BASE_BRANCH:-main}"
git fetch origin "$base_branch" >&2
git checkout "$base_branch" >&2
git pull --ff-only origin "$base_branch" >&2

# If the (astronomically unlikely) branch already exists locally or remotely,
# regenerate with a fresh suffix until we find a free name.
while git show-ref --verify --quiet "refs/heads/$branch" \
   || git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; do
  short_id=$(head -c 12 /dev/urandom | xxd -p | cut -c1-6)
  branch="development/features/${scope}/${slug}-${short_id}"
done

git checkout -b "$branch" >&2

# stdout = branch name only, for easy capture by the agent.
echo "$branch"
