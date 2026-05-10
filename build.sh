#!/bin/bash
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
  git pull && git submodule update --init --recursive
fi
