# Polyphase Engine Coding Agent — OpenClaw Docker Deployment

An autonomous coding agent for the [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine), built on [OpenClaw](https://docs.openclaw.ai).

Give it a feature request in English. It plans the change, creates a uniquely-named branch under `development/features/<scope>/<slug>-<6hex>`, writes the code, compiles the Linux Editor (and optionally every non-Windows target: Linux Game, Wii, GameCube, 3DS), and finally opens a pull request against the upstream repo on GitHub.

The container ships with the full engine build environment baked in — `devkitPPC`, `devkitARM`, `libogc2`, `wii-dev`, `3ds-dev`, `gamecube-tools-git`, the Vulkan SDK, `glslc`, GCC 12, Node 22, and the GitHub CLI — so it can verify changes on every shipped platform except Windows without leaving the container.

## What it does

1. **Plan** — reads `.llm/Spec.md` and the relevant subsystem docs in the engine, identifies which files to touch, writes a plan you can review.
2. **Branch** — creates a unique branch named `development/features/<scope>/<slug>-<6hex>` based on the configured base branch (`main` by default).
3. **Code** — writes the implementation following Polyphase's RTTI/factory/serialization conventions. Pulls in `polyphase`, `polyphase-addon`, `polyphase-controller`, and `polyphase-widget` skills as needed.
4. **Compile** — minimum bar: Linux Editor builds cleanly (`make -C Standalone -f Makefile_Linux_Editor`). Optionally builds Linux Game, Wii, GameCube, and 3DS.
5. **(Optional) Headless smoke test** — launches the editor under `xvfb-run` with `-headless` and pokes its REST controller server.
6. **PR** — pushes the branch and opens a pull request against `$GITHUB_BASE_BRANCH` with an auto-generated body summarising the change and verification results.

You stay in the loop at every checkpoint via the OpenClaw Control UI — it asks for plan sign-off before coding and won't push until you say so (unless you explicitly tell it to run autonomously).

## What's inside

| Component | Purpose |
|-----------|---------|
| `polyphaselabs/polyphase-bare:latest` base image | All engine build toolchains (Linux + console cross-compilers). |
| Node 22 + OpenClaw | Agent runtime. |
| GitHub CLI (`gh`) | PR creation, git credential setup. |
| `xvfb` | Headless editor runs that touch GL/Vulkan init. |
| `git-lfs` | LFS-tracked assets in the engine repo. |
| **5 bundled skills** | `polyphase-feature-agent` (orchestrator) + `polyphase`, `polyphase-addon`, `polyphase-controller`, `polyphase-widget`. |
| `/workspace/scripts/` | Helper shell scripts: create branch, verify compile, full build matrix, headless run, open PR. |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- A GitHub personal access token with write access to the target repo (see [Setting up GitHub auth](#setting-up-github-auth) below)
- An [OpenAI API key](https://platform.openai.com/api-keys) (default model is `gpt-5.1-codex`; Anthropic also supported via the onboarding wizard)

## Quick Start

### 1. Create a `.env` file

```ini
# GitHub PAT with Contents: read+write and Pull requests: read+write on the target repo
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional overrides:
POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine
GITHUB_BASE_BRANCH=main
GIT_AUTHOR_NAME=Polyphase Code Agent
GIT_AUTHOR_EMAIL=codeagent@polyphase.local
```

### 2. Build and start the container

```bash
docker compose up --build -d
```

First build is slow (it pulls `polyphase-bare`, which is several GB of toolchains). Subsequent rebuilds use the Docker layer cache and finish in seconds unless you touched the Dockerfile or skills.

### 3. Run onboarding (first time only)

```bash
docker compose exec polyphase_codeagent openclaw onboard
```

The wizard asks for:
- Acceptance of terms
- Model provider (OpenAI or Anthropic)
- API key

The credential lives in the persistent Docker volume so you only do this once. Restart after onboarding:

```bash
docker compose restart
```

### 4. Open the Control UI

```
http://localhost:3348
```

Enter the gateway token when prompted (default: `polyphase`; override with `GATEWAY_TOKEN`).

### 5. Ask Polly to build a feature

```
Implement an HTTP backend for the Dolphin platform — use libogc sockets with mbedTLS for HTTPS. Verify Linux Editor + Wii.
```

The agent will:
1. Read the relevant docs (`Engine/Source/Network/`, `.llm/` docs).
2. Show you a plan.
3. After your "go ahead", create `development/features/network/dolphin-http-<hash>` and write the code.
4. Run `verify_compile_linux.sh`, fix any compile errors, then `verify_build_console.sh wii`.
5. Push the branch and open a PR against `main`. The PR URL is the final message.

## Setting up GitHub auth

The agent needs a token that can:
- **Clone** the repo (if private — public repos don't need a token for clone but do for push)
- **Push** the feature branch
- **Open a pull request** via the `gh` CLI

### Fine-grained PAT (recommended)

1. Go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. **Repository access**: only the target repo (e.g. `Polyphase-Labs/Polyphase-Engine`).
3. **Permissions** → **Repository permissions**:
   - **Contents**: Read and write
   - **Pull requests**: Read and write
   - **Metadata**: Read-only (auto)
4. Copy the token, put it in `.env` as `GITHUB_TOKEN=...`, then `docker compose up -d` (or `restart`) so the entrypoint picks it up.

### Classic PAT (legacy)

If your org doesn't allow fine-grained tokens yet, use a classic PAT with the `repo` scope (full repo access). Same `GITHUB_TOKEN=...` placement.

### Verifying auth inside the container

```bash
docker compose exec polyphase_codeagent gh auth status
```

Should report `Logged in to github.com as <user>` with `Token scopes` showing the right permissions.

## Authentication (Control UI)

The OpenClaw Gateway uses token-based auth for the Control UI. Default token: `polyphase` (set in `openclaw/openclaw.json` under `gateway.auth.token`; override with the `GATEWAY_TOKEN` env var without rebuilding).

Device pairing is disabled (`dangerouslyDisableDeviceAuth: true`) for convenience. See `dockerhub.md` for the security hardening checklist if you intend to expose this beyond `localhost`.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_TOKEN` | Yes (for push/PR) | PAT for the target repo. The container can still start without it but won't be able to push or PR. |
| `POLYPHASE_REPO` | No | Repo URL to clone (default: `https://github.com/Polyphase-Labs/Polyphase-Engine`). |
| `GITHUB_BASE_BRANCH` | No | Base branch PRs target (default: `main`). |
| `GIT_AUTHOR_NAME` | No | Author name on commits (default: `Polyphase Code Agent`). |
| `GIT_AUTHOR_EMAIL` | No | Author email on commits (default: `codeagent@polyphase.local`). |
| `SYNC_MODE` | No | `"true"` to overwrite config/skills/memory from the image on every boot. Default: only on first run. |
| `ALLOWED_ORIGINS` | No | Comma-separated CORS origins for the Control UI. |
| `GATEWAY_TOKEN` | No | Override the Control UI auth token at runtime. |

## Helper scripts

The agent calls these via shell. You can also call them by hand if you `docker compose exec polyphase_codeagent bash`:

| Script | Purpose |
|--------|---------|
| `/workspace/scripts/create_feature_branch.sh <scope> <slug>` | Create unique branch under `development/features/`. |
| `/workspace/scripts/verify_compile_linux.sh` | Build Linux Editor (shaders + libgit2 + asset stubs + engine + editor + libLua), smoke-check the resulting ELF. Required minimum. |
| `/workspace/scripts/verify_build_console.sh {wii\|gcn\|3ds\|linux-game}` | Build one extra target via its `Standalone/Makefile_<target>`. |
| `/workspace/scripts/verify_build_all.sh` | Full matrix: Linux Editor → Linux Game → Wii → GCN → 3DS. |
| `/workspace/scripts/run_editor_headless.sh <project>` | Run editor under `xvfb-run` with `-headless`, optionally driven via the controller REST server. |
| `/workspace/scripts/open_pr.sh "<title>" <body-file>` | Commit pending changes, push branch, `gh pr create`. |

## Project structure

```
.
├── Dockerfile                  # polyphase-bare base + Node 22 + gh + xvfb
├── docker-compose.yml          # Service + env var wiring + persistent volume
├── entrypoint.sh               # gh auth setup-git + clone + start gateway
├── build.sh                    # Clone/pull helper invoked by entrypoint
├── scripts/                    # Helper shell scripts the agent calls
│   ├── create_feature_branch.sh
│   ├── verify_compile_linux.sh
│   ├── verify_build_console.sh
│   ├── verify_build_all.sh
│   ├── run_editor_headless.sh
│   └── open_pr.sh
├── openclaw/
│   ├── openclaw.json           # OpenClaw gateway + agent configuration
│   └── workspace/
│       ├── skills/
│       │   ├── polyphase-feature-agent/   # Orchestrator (plan→branch→code→build→PR)
│       │   ├── polyphase/                  # Engine developer playbook
│       │   ├── polyphase-addon/            # Native C++ addon authoring
│       │   ├── polyphase-controller/       # Editor REST controller scripting
│       │   └── polyphase-widget/           # UI widget generation
│       └── memory/             # Polly identity + seeded memory
├── .github/workflows/release.yml   # Tag → Docker Hub + GitHub Release
└── README.md
```

## Sync mode

By default, the bundled config/skills/memory are only copied into the persistent volume on **first boot**. Edits made inside the container (onboarding creds, Polly's accumulated session memory, gateway token tweaks) are preserved across `docker compose restart`/`up`.

When you're iterating on the skills or `openclaw.json` and want every rebuild to push the latest versions:

```yaml
# docker-compose.yml
environment:
  SYNC_MODE: "true"
```

This overwrites `skills/` and `memory/` from the image and deep-merges the image's `openclaw.json` into the existing one (image values win, but onboarding-set fields like `auth.profiles` are preserved).

## Resetting

Persistent state lives in the `openclaw_polyphase_codeagent_state` volume. To wipe it (re-run onboarding from scratch, re-clone the engine):

```bash
docker compose down -v
```

## Troubleshooting

### "GITHUB_TOKEN is not set" warning at startup
You can still start the container without a token (read-only mode), but the agent can't push or open PRs. Add `GITHUB_TOKEN=...` to `.env` and `docker compose restart`.

### `gh pr create` fails with "must be on a branch"
The feature branch wasn't created. Re-run `create_feature_branch.sh <scope> <slug>` first.

### Build fails on first run after `docker compose up`
The very first compile in a fresh container will be slow (no build cache). Look at the actual error in `verify_compile_linux.sh` output rather than re-running blindly. If it's an environment problem (`DEVKITPRO` unset, `glslc` not in PATH), file an issue — the `polyphase-bare` base image should have everything pre-wired.

### Headless editor exits immediately
The engine's `-headless` mode requires both the flag **and** a `-project <path>` argument. Without a project, it falls back to interactive mode and exits when no window opens. Pass a valid project path.

### Onboarding credentials lost
If you removed the Docker volume:

```bash
docker compose exec polyphase_codeagent openclaw onboard
docker compose restart
```

## Release workflow

A tag matching `v*` pushed to the GitHub mirror of this repo triggers `.github/workflows/release.yml`, which:
1. Builds a multi-arch (linux/amd64 + linux/arm64) Docker image.
2. Pushes it to Docker Hub as `polyphaselabs/polyphase-codeagent-claw` (override via the `DOCKERHUB_IMAGE` repo variable).
3. Creates a GitHub Release with auto-generated notes since the previous tag.

Required repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`. See the workflow file header for setup details.

## Links

- [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine)
- [OpenClaw documentation](https://docs.openclaw.ai)
- [polyphase-bare Docker image](https://hub.docker.com/r/polyphaselabs/polyphase-bare) (build environment base)
