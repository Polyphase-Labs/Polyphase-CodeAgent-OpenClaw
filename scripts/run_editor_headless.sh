#!/bin/bash
# Run the freshly-built Linux Editor in headless mode against a test
# project. The engine supports `-headless` which gates rendering and audio
# initialisation; combined with the controller REST server on
# http://localhost:7890 this is the agent's hook for scripted post-build
# verification (e.g. "did my new node type instantiate without crashing?").
#
# Wraps in xvfb-run as a belt-and-suspenders fallback for any platform code
# that still pokes at DISPLAY during init.
#
# Usage:
#   run_editor_headless.sh <project-path>
#
# Exits 0 when the editor exits cleanly. Stream stdout/stderr to caller.
set -euo pipefail

if [ -z "${POLYPHASE_DIR:-}" ]; then
  echo "POLYPHASE_DIR is not set" >&2
  exit 1
fi

project_path="${1:-}"
if [ -z "$project_path" ]; then
  echo "usage: $0 <path-to-.octp-or-project-dir>" >&2
  exit 2
fi

cd "$POLYPHASE_DIR"

elf="Standalone/Build/Linux/PolyphaseEditor.elf"
if [ ! -x "$elf" ]; then
  echo "Editor binary not built: $elf" >&2
  echo "Run verify_compile_linux.sh first." >&2
  exit 3
fi

exec xvfb-run -a "$elf" -headless -project "$project_path" "${@:2}"
