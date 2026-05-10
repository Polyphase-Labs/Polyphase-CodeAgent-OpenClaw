#!/bin/bash
# Run the full non-Windows verification matrix. Use this before opening a PR
# when the feature touches code that ships to all platforms (engine core,
# rendering abstraction, scripting). For features scoped to a single platform
# or pure-editor work, verify_compile_linux.sh alone is enough.
#
# Order matters: Linux Editor first (it produces shaders + libgit2 + asset
# stubs that nothing else needs but it's the canonical "does it compile at
# all" check). Then console targets in increasing build-time order.
#
# Aborts at the first failure; the calling agent should read the output, fix,
# and re-run.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)

echo "=============================================="
echo " 1/5  Linux Editor"
echo "=============================================="
"$script_dir/verify_compile_linux.sh"

echo "=============================================="
echo " 2/5  Linux Standalone Game"
echo "=============================================="
"$script_dir/verify_build_console.sh" linux-game

echo "=============================================="
echo " 3/5  Wii"
echo "=============================================="
"$script_dir/verify_build_console.sh" wii

echo "=============================================="
echo " 4/5  GameCube"
echo "=============================================="
"$script_dir/verify_build_console.sh" gcn

echo "=============================================="
echo " 5/5  3DS"
echo "=============================================="
"$script_dir/verify_build_console.sh" 3ds

echo
echo "All non-Windows targets built successfully."
