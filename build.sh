#!/bin/bash
# Clone (or refresh) the Polyphase Engine repository the agent will work on.
#
# On a coding-agent container, the clone needs to be writable since the
# agent will commit + push feature branches. GITHUB_TOKEN, if set, has
# already been wired into git's credential helper by entrypoint.sh via
# `gh auth setup-git`, so HTTPS clone/push to github.com just works.
set -e

if [ -z "$POLYPHASE_REPO" ]; then
  echo "POLYPHASE_REPO not set"
  exit 1
fi

if [ ! -d "/data/openclaw/.openclaw/workspace/Polyphase/.git" ]; then
  echo "Cloning Polyphase Engine from $POLYPHASE_REPO..."
  rm -rf "/data/openclaw/.openclaw/workspace/Polyphase"
  git clone "$POLYPHASE_REPO" "/data/openclaw/.openclaw/workspace/Polyphase" --recursive
else
  echo "Polyphase Engine repo already exists, pulling latest..."
  cd "/data/openclaw/.openclaw/workspace/Polyphase"
  git pull --ff-only || echo "  (pull skipped; agent may be on a feature branch)"
  git submodule update --init --recursive
fi

# Ensure the base branch we'll PR against is fetched.
cd "/data/openclaw/.openclaw/workspace/Polyphase"
base_branch="${GITHUB_BASE_BRANCH:-main}"
git fetch origin "$base_branch" || true
