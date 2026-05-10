# Polyphase Engine Dev Agent — OpenClaw Docker Deployment

A self-contained Docker deployment of an [OpenClaw](https://docs.openclaw.ai) agent specialised for [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine) development. On startup it clones the Polyphase Engine repository into the container workspace, loads the four `polyphase*` skills, and exposes the OpenClaw Gateway + Control UI over HTTP.

## What It Does

The agent ships with four skills covering the full surface of Polyphase Engine development:

| Skill | Purpose |
|-------|---------|
| **polyphase** | Senior engine-developer skill — RTTI/factory patterns, serialization, naming conventions, every subsystem (rendering, scripting, node graphs, editor, asset pipeline, plugins). Reads `.llm/Spec.md` and subsystem docs as its map. |
| **polyphase-addon** | Build and ship full-fledged native C++ addons under `<Project>/Packages/<reverse-dns-id>/` — hot-reloaded by the editor, statically linked into shipped builds. Covers `package.json`, lifecycle, editor-UI hooks, per-platform libraries. |
| **polyphase-controller** | Drive the running editor over its REST controller server — create scenes, spawn nodes, set transforms and properties, attach Lua scripts, fill in script-exposed fields, start/stop play-in-editor. |
| **polyphase-widget** | Generate new UI widgets following the established Widget + Lua-binding pattern. |

The skills read the `.llm/` documentation files and source headers directly from the cloned repo inside the container, so answers are grounded in the actual codebase rather than guesses.

### Use Cases

- **Code generation** — Scaffold new Node types, Asset types, GraphNodes, Lua bindings, native addons, editor panels, or widgets following Polyphase's exact conventions (RTTI macros, factory registration, serialization patterns).
- **Scene authoring at runtime** — "Spawn a cube at origin, attach the player script, and start play-in-editor" — handled via the `polyphase-controller` skill talking to the editor's REST server.
- **Architecture Q&A** — Query subsystem design, class hierarchies, or how specific engine features are implemented.
- **Debugging assistance** — Describe a bug; the agent will trace call chains, read relevant source files, and suggest fixes.
- **Code review** — Paste code and it will check for missing `FORCE_LINK_CALL` registration, incorrect naming, missing `#if EDITOR` guards, asset version gating, and other common pitfalls.
- **Onboarding** — New developers can ask the agent to explain any part of the engine, from the rendering pipeline to the plugin API.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- An [OpenAI API key](https://platform.openai.com/api-keys) (the agent uses `gpt-5.1-codex` by default; Anthropic also supported)

## Quick Start

### 1. (Optional) Create a `.env` file

The compose file defaults `POLYPHASE_REPO` to `https://github.com/Polyphase-Labs/Polyphase-Engine`, so you can skip this step unless you want to point at a fork or private mirror.

```bash
echo "POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine" > .env
```

### 2. Build and start the container

```bash
docker compose up --build -d
```

### 3. Run onboarding (first time only)

The agent needs your OpenAI or Anthropic API key stored in its credential store. Shell into the running container and run the onboard wizard:

```bash
docker compose exec polyphase_claw openclaw onboard
```

This walks you through:
- Accepting the terms
- Selecting your model provider (choose **OpenAI** or **Anthropic**)
- Entering your **API key**

The key is saved inside the persistent Docker volume, so you only need to do this once. The container will retain it across restarts.

### 4. Restart the gateway

After onboarding, restart the container so the gateway picks up the new credentials:

```bash
docker compose restart
```

### 5. Open the Control UI

Navigate to:

```
http://localhost:3348
```

You should see the OpenClaw Control UI. Enter the gateway auth token when prompted (see [Authentication](#authentication) below).

## Authentication

The gateway uses **token-based auth**. When you open the Control UI, you'll be asked for a token.

### Default token

The default token is set in `openclaw/openclaw.json` under `gateway.auth.token`:

```json
"auth": {
  "mode": "token",
  "token": "polyphase"
}
```

Enter `polyphase` (or whatever you've changed it to) in the Control UI token prompt.

### Changing the token

Edit `openclaw/openclaw.json` and change `gateway.auth.token` to any string you want, then rebuild:

```bash
docker compose up --build -d
```

### Device pairing

Device pairing is **disabled** in this deployment (`dangerouslyDisableDeviceAuth: true`) for convenience. This means any browser that has the token can connect without an additional approval step.

If you want to re-enable pairing for tighter security, set `dangerouslyDisableDeviceAuth` to `false` in `openclaw/openclaw.json`. New browsers will then require approval:

```bash
docker compose exec polyphase_claw openclaw devices list
docker compose exec polyphase_claw openclaw devices approve <requestId>
```

### Allowed origins

The Control UI enforces CORS via `allowedOrigins`. By default it only allows `http://localhost:3348`. To allow additional origins (e.g., accessing from a remote host), set the `ALLOWED_ORIGINS` environment variable as a comma-separated list:

```yaml
# docker-compose.yml
environment:
  ALLOWED_ORIGINS: "http://localhost:3348,https://myhost.example.com"
```

Or with plain Docker:

```bash
docker run -d \
  -e ALLOWED_ORIGINS="http://localhost:3348,https://myhost.example.com" \
  ...
```

The entrypoint patches the config JSON at runtime, so you don't need to rebuild.

### Gateway token via environment

You can override the auth token at runtime without editing `openclaw.json`:

```yaml
# docker-compose.yml
environment:
  GATEWAY_TOKEN: "my-secret-token"
```

Or with plain Docker:

```bash
docker run -d \
  -e GATEWAY_TOKEN="my-secret-token" \
  ...
```

### Security notes

- The gateway binds to `0.0.0.0` inside the container (`bind: "lan"`) so Docker can route traffic to it. It is only exposed on port `3348` on your host.
- Do **not** expose port `3348` to the public internet without changing the token to something strong and re-enabling device auth.
- The `allowedOrigins` in the config restricts Control UI access to `http://localhost:3348`. Use `ALLOWED_ORIGINS` to add more origins.

## Running Without Docker Compose

If you prefer plain `docker` commands instead of Compose:

### 1. Build the image

```bash
docker build -t polyphase-claw .
```

### 2. Create a volume for persistent data

```bash
docker volume create openclaw_polyphase_state
```

### 3. Run the container

```bash
docker run -d \
  --name polyphase_claw \
  -e POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine \
  -e OPENCLAW_HOME=/data/openclaw \
  -p 3348:3000 \
  -v openclaw_polyphase_state:/data/openclaw \
  --tty --interactive \
  polyphase-claw
```

### 4. Run onboarding (first time only)

```bash
docker exec -it polyphase_claw openclaw onboard
```

Then restart the container:

```bash
docker restart polyphase_claw
```

### 5. Open the Control UI

Navigate to `http://localhost:3348` and enter the auth token (default: `polyphase`).

### Useful commands

```bash
# View logs
docker logs -f polyphase_claw

# Shell into the container
docker exec -it polyphase_claw bash

# List skills
docker exec polyphase_claw openclaw skills list

# Stop and remove
docker stop polyphase_claw && docker rm polyphase_claw

# Fully reset (remove persistent data)
docker volume rm openclaw_polyphase_state
```

## Project Structure

```
.
├── Dockerfile                  # Node 22 base, installs OpenClaw via npm
├── docker-compose.yml          # Service definition, port mapping, volume
├── entrypoint.sh               # Clones Polyphase repo, copies config, starts gateway
├── build.sh                    # Clone/pull helper invoked by entrypoint
├── openclaw/
│   ├── openclaw.json           # OpenClaw gateway + agent configuration
│   └── workspace/
│       ├── skills/
│       │   ├── polyphase/             # General engine-dev skill
│       │   ├── polyphase-addon/       # Native C++ addon authoring
│       │   ├── polyphase-controller/  # Editor REST controller scripting
│       │   └── polyphase-widget/      # UI widget generation
│       └── memory/             # Agent identity + seeded memory files
└── README.md
```

## Configuration

### Changing the model

Edit `openclaw/openclaw.json` and update `agents.defaults.model.primary` and the agent's `model` field in `agents.list`:

```json
"model": {
  "primary": "openai/gpt-5.1-codex"
}
```

### Changing the port

The gateway listens on port `3000` inside the container, mapped to `3348` on the host. To change the host port, edit `docker-compose.yml`:

```yaml
ports:
  - "YOUR_PORT:3000"
```

Then update `gateway.controlUi.allowedOrigins` in `openclaw/openclaw.json` to match.

### Sync mode

By default, the config, skills, and memory files are only copied into the volume on the **first boot** (tracked by a `flag.json` marker). This means changes you make inside the container (via onboarding, editing config, etc.) are preserved across restarts.

If you want the container to **always overwrite** the volume config/skills/memory with what's baked into the image, set `SYNC_MODE=true`:

```yaml
# docker-compose.yml
environment:
  SYNC_MODE: "true"
```

Or with plain Docker:

```bash
docker run -d \
  -e SYNC_MODE=true \
  ...
```

This is useful during development when you're iterating on `openclaw.json`, skills, or memory files and want every rebuild to push the latest changes into the running volume.

### Persistent data

The Docker volume `openclaw_polyphase_state` persists:
- The cloned Polyphase Engine repository
- OpenClaw credentials (from onboarding)
- Session history and memory
- Config and skills (after first boot, unless `SYNC_MODE=true`)

To fully reset, remove the volume:

```bash
docker compose down -v
```

## Troubleshooting

### "Gateway token missing"
Enter the auth token in the Control UI prompt. Default: `polyphase`.

### "Pairing required"
If you re-enabled device auth, approve the device from inside the container (see [Device pairing](#device-pairing)).

### Skill not showing up
All four `polyphase*` skills should appear in the agent's skill list. Verify with:

```bash
docker compose exec polyphase_claw openclaw skills list
```

If anything is missing, check that the SKILL.md files were copied correctly:

```bash
docker compose exec polyphase_claw ls /data/openclaw/.openclaw/workspace/skills/
```

You should see `polyphase/`, `polyphase-addon/`, `polyphase-controller/`, and `polyphase-widget/` — each containing a `SKILL.md`.

### Skills out of date after a Polyphase Engine update
The skills are baked into the Docker image from the engine repo's `.claude/skills/` at build time. To refresh them, copy the latest skill folders into `openclaw/workspace/skills/` and rebuild:

```bash
docker compose up --build -d
```

If you want the rebuild to also push the updated skills into the live volume, set `SYNC_MODE=true` for the next boot.

### Onboarding credentials lost
If you removed the Docker volume, re-run onboarding:

```bash
docker compose exec polyphase_claw openclaw onboard
docker compose restart
```
