#!/bin/bash
# Compile-only verification on the Linux Editor build. This is the minimum
# bar before opening a PR: the engine + editor must link cleanly on Linux.
#
# Runs the same first-stage steps the engine's verify-build.yml runs:
#   1. submodules init/update
#   2. compile Vulkan shaders (Engine/Shaders/GLSL/compile.sh)
#   3. prebuild libgit2 (Tools/prebuild_libgit2.sh)
#   4. generate embedded asset stubs (Tools/generate_embedded_stubs.py)
#   5. make -C Standalone -f Makefile_Linux_Editor
#   6. build libLua.a (separate, used by native-addon shipping path)
#
# Exit codes:
#   0  build succeeded
#   1  any step failed (stderr has the error from the failing tool)
#
# Stream the full output to stdout so the calling agent can read errors and
# self-correct. Use -j$(nproc) for fan-out.
set -euo pipefail

if [ -z "${POLYPHASE_DIR:-}" ]; then
  echo "POLYPHASE_DIR is not set" >&2
  exit 1
fi

cd "$POLYPHASE_DIR"

# Mark the workspace safe for git operations (we're running as root in the container)
git config --global --add safe.directory '*'

echo "==> submodule init/update"
git submodule update --init --recursive

echo "==> shader compile (Vulkan glslc)"
(
  cd Engine/Shaders/GLSL
  chmod +x compile.sh
  ./compile.sh
)

echo "==> prebuild libgit2"
bash Tools/prebuild_libgit2.sh

echo "==> generate embedded asset stubs"
python3 Tools/generate_embedded_stubs.py

echo "==> build Linux Editor"
make -C Standalone -f Makefile_Linux_Editor -j"$(nproc)"

echo "==> build libLua.a (for native addon shipping)"
make -C External/Lua a -j"$(nproc)"
mkdir -p External/Lua/Build/Linux/x64/ReleaseEditor
cp External/Lua/liblua.a External/Lua/Build/Linux/x64/ReleaseEditor/libLua.a
test -f External/Lua/Build/Linux/x64/ReleaseEditor/libLua.a
make -C External/Lua clean
test -f External/Lua/Build/Linux/x64/ReleaseEditor/libLua.a

echo "==> verifying editor binary loads"
elf="Standalone/Build/Linux/PolyphaseEditor.elf"
test -f "$elf"
chmod +x "$elf"
if ! "$elf" -h >/dev/null 2>err.txt; then
  if grep -q 'GLIBC' err.txt; then
    echo "FATAL: editor binary needs newer glibc than container provides." >&2
    cat err.txt >&2
    exit 1
  fi
fi
rm -f err.txt

echo "==> Linux Editor compile + smoke check OK"
