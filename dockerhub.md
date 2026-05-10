# Polyphase Code Agent Claw

An autonomous coding agent for the [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine), built on [OpenClaw](https://docs.openclaw.ai). Takes a feature request in English and produces a reviewable pull request on GitHub: plans the change, creates a unique feature branch, writes the code, compiles the Linux Editor (and optionally Wii / GameCube / 3DS / Linux Game), and opens the PR.

## Quick Start

```bash
docker run -d \
  --name polyphase_codeagent \
  -e POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine \
  -e GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  -e GITHUB_BASE_BRANCH=main \
  -e OPENCLAW_HOME=/data/openclaw \
  -p 3348:3000 \
  -v openclaw_polyphase_codeagent_state:/data/openclaw \
  --tty --interactive \
  polyphaselabs/polyphase-codeagent-claw:latest
```

Then onboard (first time only):

```bash
docker exec -it polyphase_codeagent openclaw onboard
docker restart polyphase_codeagent
```

Open the Control UI at **http://localhost:3348** and enter the auth token (default: `polyphase`).

## What's Inside

- **`polyphaselabs/polyphase-bare:latest` base** — debian:bookworm-slim + GCC 12 + Vulkan SDK + glslc + devkitPro (devkitPPC, devkitARM) + libogc2 + 3ds-dev + wii-dev + gamecube-tools-git + curl-impersonate. Identical to what the engine's CI uses.
- **Node 22 + OpenClaw** — the agent runtime.
- **GitHub CLI (`gh`)** — auto-wires git credentials from `GITHUB_TOKEN` on container start; used by `gh pr create`.
- **xvfb** + `git-lfs` — headless editor runs and LFS-tracked engine assets.
- **5 bundled skills**:
  - `polyphase-feature-agent` — the orchestrator (plan → branch → code → build → PR).
  - `polyphase` — engine developer playbook.
  - `polyphase-addon` — native C++ addon authoring.
  - `polyphase-controller` — drive the running editor over its REST controller server.
  - `polyphase-widget` — UI widget generation.
- **Helper scripts** at `/workspace/scripts/` for branch creation, multi-platform verification, headless editor runs, and PR opening.
- On first boot, automatically clones the Polyphase Engine repo into the container workspace and configures git/gh with the provided token.
- Persistent volume keeps credentials, session history, and the cloned repo across restarts.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_TOKEN` | Yes (for push/PR) | PAT for the target repo. The container still starts without it for read-only work, but `open_pr.sh` will refuse to push. |
| `POLYPHASE_REPO` | No | Repo URL the agent clones. Defaults to the public engine. |
| `GITHUB_BASE_BRANCH` | No | Base branch PRs target. Default: `main`. |
| `GIT_AUTHOR_NAME` | No | Commit author name. Default: `Polyphase Code Agent`. |
| `GIT_AUTHOR_EMAIL` | No | Commit author email. Default: `codeagent@polyphase.local`. |
| `OPENCLAW_HOME` | No | OpenClaw data directory (default: `/data/openclaw`). |
| `SYNC_MODE` | No | Set to `true` to overwrite config/skills/memory from the image on every boot. |
| `ALLOWED_ORIGINS` | No | Comma-separated CORS origins for the Control UI. |
| `GATEWAY_TOKEN` | No | Override the Control UI auth token. |

## Ports

| Container Port | Description |
|----------------|-------------|
| `3000` | OpenClaw Gateway + Control UI |

Map to any host port you like (e.g. `-p 3348:3000`).

## Volumes

| Path | Description |
|------|-------------|
| `/data/openclaw` | Persistent storage for credentials, config, cloned repo, and session data. |

## How the agent works

1. **Plan** — reads `.llm/Spec.md` and subsystem docs, identifies which files to touch, writes a plan.
2. **Branch** — runs `/workspace/scripts/create_feature_branch.sh <scope> <slug>` to create `development/features/<scope>/<slug>-<6hex>` (unique suffix prevents collisions across concurrent sessions).
3. **Code** — writes the implementation, following Polyphase's RTTI/factory/serialization conventions.
4. **Compile** — runs `/workspace/scripts/verify_compile_linux.sh` at minimum. For features that touch core/rendering/scripting, runs `verify_build_all.sh` to cover Wii / GCN / 3DS / Linux Game too.
5. **(Optional) Headless smoke** — `run_editor_headless.sh <project>` launches the editor under `xvfb-run` with `-headless` and pokes the REST controller server.
6. **PR** — `open_pr.sh "<title>" /tmp/pr-body.md` commits, pushes, and runs `gh pr create` against the base branch.

The agent pauses at each checkpoint for your sign-off via the Control UI unless you explicitly tell it to run autonomously.

## Setting up `GITHUB_TOKEN`

A fine-grained PAT is recommended — scoped to the target repo only, with these permissions:

- **Contents**: Read and write
- **Pull requests**: Read and write
- **Metadata**: Read-only (auto)

Classic PATs work too — use `repo` scope.

Put it in `.env`:

```ini
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Verify after the container starts:

```bash
docker exec polyphase_codeagent gh auth status
```

## Onboarding

The first time you run the container, register your LLM provider credentials:

```bash
docker exec -it polyphase_codeagent openclaw onboard
```

Pick OpenAI or Anthropic, paste your API key. Stored in the persistent volume — only needed once.

## Use cases

- **"Implement an HTTP backend for the Dolphin platform"** — agent plans, branches under `development/features/network/dolphin-http-<hash>`, codes against `libogc` sockets + mbedTLS, verifies Linux Editor + Wii build, opens PR.
- **"Add a Voxel3D node with run-length-encoded serialization"** — agent identifies `Engine/Source/Engine/Nodes/3D/` plus the `.vcxproj` filter add, writes the type, version-gates the serialized field, verifies all platforms.
- **"Refactor the script reload path to be Lua-only on Ctrl+R"** — agent finds the three Ctrl+R handler call sites, strips the native-reload calls, verifies the editor still links and runs headless, opens PR.
- **"Create a new HTTP/JSON addon under Packages"** — agent uses `polyphase-addon` skill to scaffold `package.json`, `Source/MyAddon.cpp`, the build config, and the editor-UI hook registration.

## Docker Compose

```yaml
services:
  polyphase_codeagent:
    image: polyphaselabs/polyphase-codeagent-claw:latest
    environment:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      POLYPHASE_REPO: https://github.com/Polyphase-Labs/Polyphase-Engine
      GITHUB_BASE_BRANCH: main
      OPENCLAW_HOME: /data/openclaw
      # SYNC_MODE: "true"
      # ALLOWED_ORIGINS: "http://localhost:3348,https://myhost.example.com"
      # GATEWAY_TOKEN: "my-secret-token"
    ports:
      - "3348:3000"
    volumes:
      - openclaw_polyphase_codeagent_state:/data/openclaw
    tty: true
    stdin_open: true

volumes:
  openclaw_polyphase_codeagent_state:
```

## Security notes

- The gateway binds `0.0.0.0` inside the container and is exposed on port 3348 on your host by default. Don't expose this beyond `localhost` without changing the auth token to something strong (`GATEWAY_TOKEN`) and re-enabling device pairing (`dangerouslyDisableDeviceAuth: false` in `openclaw.json`).
- `GITHUB_TOKEN` lives in the container's environment and is wired into git/gh credentials. The persistent volume contains the configured git credentials too; treat the volume as sensitive.
- The agent has shell access inside the container and can run arbitrary commands against the cloned repo. Operate it on a sandbox host or VM if you're not comfortable with that.

## Links

- [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine)
- [Source & Dockerfile](https://github.com/Polyphase-Labs/Polyphase-CodeAgent-OpenClaw)
- [OpenClaw documentation](https://docs.openclaw.ai)
