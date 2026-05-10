#!/bin/bash
# Cross-compile the engine for a console target. Wraps the per-platform
# Standalone makefile. Intended for use AFTER verify_compile_linux.sh has
# already produced the Linux editor (some platforms reuse Linux artifacts
# during a packaging pass, though pure engine compile doesn't strictly need
# them).
#
# Usage:
#   verify_build_console.sh <target>
#   target ∈ { wii | gcn | 3ds | linux-game }
#
# Exit 0 on success; non-zero with the failing tool's output on stderr.
set -euo pipefail

if [ -z "${POLYPHASE_DIR:-}" ]; then
  echo "POLYPHASE_DIR is not set" >&2
  exit 1
fi

target="${1:-}"
case "$target" in
  wii)         makefile="Makefile_Wii" ;;
  gcn)         makefile="Makefile_GCN" ;;
  3ds)         makefile="Makefile_3DS" ;;
  linux-game)  makefile="Makefile_Linux_Game" ;;
  *)
    echo "usage: $0 {wii|gcn|3ds|linux-game}" >&2
    exit 2
    ;;
esac

cd "$POLYPHASE_DIR"
git config --global --add safe.directory '*'

echo "==> $target: submodule init/update (devkit env)"
git submodule update --init --recursive

# devkitPPC / devkitARM expectations: DEVKITPRO + DEVKITPPC / DEVKITARM must be
# set. The polyphase-bare image exports these via /etc/profile.d/devkit-env.sh,
# but bash -c doesn't auto-source profile, so re-source here.
if [ -f /etc/profile.d/devkit-env.sh ]; then
  # shellcheck disable=SC1091
  . /etc/profile.d/devkit-env.sh
fi
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITPPC="${DEVKITPPC:-$DEVKITPRO/devkitPPC}"
export DEVKITARM="${DEVKITARM:-$DEVKITPRO/devkitARM}"

echo "==> $target: building engine"
make -C Standalone -f "$makefile" -j"$(nproc)"

echo "==> $target: build OK"
