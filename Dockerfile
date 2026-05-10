# syntax=docker/dockerfile:1.6
#
# Base on the same all-in-one build environment the engine's CI uses
# (polyphase-bare). That image already ships:
#   - debian:bookworm-slim (glibc 2.36, gcc 12)
#   - g++ / make / python3
#   - Vulkan SDK + glslc (Linux Editor shader compile step)
#   - devkitPro pacman + devkitPPC + devkitARM
#   - libogc2 + libogc2-libdvm + 3ds-dev + wii-dev + gamecube-tools-git
#   - curl-impersonate
#
# We add Node 22 (for OpenClaw), GitHub CLI (for PR creation), git LFS,
# and xvfb (for running the editor headlessly when needed) on top.
FROM polyphaselabs/polyphase-bare:latest

ENV OPENCLAW_HOME=/data/openclaw \
    WORKSPACE=/workspace \
    POLYPHASE_DIR=/data/openclaw/.openclaw/workspace/Polyphase \
    POLYPHASE_PATH=/data/openclaw/.openclaw/workspace/Polyphase \
    GH_PROMPT_DISABLED=1 \
    DEBIAN_FRONTEND=noninteractive

# Node 22 (nodesource) + GitHub CLI (cli.github.com) + xvfb for headless editor runs.
# gh is needed for `gh pr create`; xvfb is a fallback for any GL/Vulkan init
# that touches an X display before falling into headless mode.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg jq xvfb git-lfs; \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    git lfs install --system; \
    rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally via npm
RUN npm install -g openclaw

WORKDIR ${WORKSPACE}

# Stage OpenClaw config + skills + memory for the entrypoint to copy into
# /data/openclaw on first boot.
COPY openclaw/openclaw.json /root/.openclaw/openclaw.json
COPY openclaw/openclaw.json /tmp/openclaw.json
COPY openclaw/workspace/skills/ /tmp/skills/
COPY openclaw/workspace/memory/ /tmp/memory/

# Helper scripts the feature-agent skill calls during plan → branch → build → PR.
COPY scripts/ /workspace/scripts/
RUN chmod +x /workspace/scripts/*.sh

EXPOSE 3000

COPY entrypoint.sh /entrypoint.sh
COPY build.sh /workspace/build.sh
RUN chmod +x /entrypoint.sh /workspace/build.sh

ENTRYPOINT ["/entrypoint.sh"]
