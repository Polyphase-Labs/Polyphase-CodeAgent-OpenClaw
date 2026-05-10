# Polyphase Dev Claw

An AI-powered development agent for the [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine), built on [OpenClaw](https://docs.openclaw.ai). Ships with four `polyphase*` skills — deep knowledge of every Polyphase subsystem, naming convention, and development pattern — ready to assist with code generation, native addon authoring, runtime scene control, widget creation, architecture questions, debugging, and code review.

## Quick Start

```bash
docker run -d \
  --name polyphase_claw \
  -e POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine \
  -e OPENCLAW_HOME=/data/openclaw \
  -p 3348:3000 \
  -v openclaw_polyphase_state:/data/openclaw \
  --tty --interactive \
  polyphaselabs/polyphase-dev-claw:latest
```

Then run onboarding to set up your API key (first time only):

```bash
docker exec -it polyphase_claw openclaw onboard
docker restart polyphase_claw
```

Open the Control UI at **http://localhost:3348** and enter the auth token (default: `polyphase`).

## What's Inside

- **Node 22** runtime with OpenClaw installed via npm
- Four bundled skills:
  - **polyphase** — Engine developer playbook (RTTI, factories, serialization, every subsystem).
  - **polyphase-addon** — Native C++ addon authoring (manifests, lifecycle, editor UI hooks, hot-reload).
  - **polyphase-controller** — Drive the running editor over its REST controller server.
  - **polyphase-widget** — Generate new UI widgets following the established pattern.
- On first boot, automatically clones the Polyphase Engine repository into the container workspace
- **Agent memory** files baked into the image for pre-seeded identity / context
- Persistent volume keeps credentials, session history, and the cloned repo across restarts
- **Sync mode** (`SYNC_MODE=true`) to force-refresh config, skills, and memory from the image on every boot

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POLYPHASE_REPO` | No | Git URL for the Polyphase Engine repository. Defaults to `https://github.com/Polyphase-Labs/Polyphase-Engine` if unset. |
| `OPENCLAW_HOME` | No | OpenClaw data directory (default: `/data/openclaw`) |
| `SYNC_MODE` | No | Set to `true` to overwrite config/skills/memory from the image on every boot. Default: only copies on first run. |
| `ALLOWED_ORIGINS` | No | Comma-separated list of allowed origins for the Control UI (e.g., `http://localhost:3348,https://myhost.example.com`). Patches the config at runtime. |
| `GATEWAY_TOKEN` | No | Override the gateway auth token at runtime without editing `openclaw.json`. |

## Ports

| Container Port | Description |
|----------------|-------------|
| `3000` | OpenClaw Gateway + Control UI |

Map it to any host port you like (e.g., `-p 3348:3000`).

## Volumes

| Path | Description |
|------|-------------|
| `/data/openclaw` | Persistent storage for credentials, config, cloned repo, and session data |

## Authentication

The gateway requires a token to connect. Default token: `polyphase`.

You can override the token and allowed origins via environment variables — no rebuild needed:

```bash
docker run -d \
  --name polyphase_claw \
  -e POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine \
  -e OPENCLAW_HOME=/data/openclaw \
  -e GATEWAY_TOKEN=my-secret-token \
  -e ALLOWED_ORIGINS="http://localhost:3348,https://myhost.example.com" \
  -p 3348:3000 \
  -v openclaw_polyphase_state:/data/openclaw \
  --tty --interactive \
  polyphaselabs/polyphase-dev-claw:latest
```

The entrypoint patches the config JSON at runtime with the values from `GATEWAY_TOKEN` and `ALLOWED_ORIGINS`.

## Onboarding

The first time you run the container, you need to register your LLM provider credentials:

```bash
docker exec -it polyphase_claw openclaw onboard
```

The wizard will ask you to:
1. Accept the terms
2. Choose a model provider (OpenAI or Anthropic)
3. Enter your API key

Credentials are stored in the persistent volume — you only need to do this once unless you remove the volume.

## Use Cases

- **Scaffold engine types** — "Create a new ParticleEmitter3D node with velocity, lifetime, and emission rate properties."
- **Author a native addon** — "Create an addon called 'com.acme.video' that registers a VideoPlayer3D node and an editor menu under Tools > Video."
- **Drive the running editor** — "Spawn a directional light, three Box3D nodes in a triangle around origin, attach the player script to the first one, then play the scene."
- **Generate a widget** — "Make a Slider widget that drives a float value and emits an OnValueChanged signal."
- **Architecture deep-dives** — "Explain how the NodeGraph processor evaluates pins and links."
- **Debug assistance** — "My custom asset isn't appearing at runtime, what could be wrong?"
- **Code review** — "Check this Node implementation for missing registration, guards, or serialization version gating."
- **Onboard new developers** — "Walk me through the rendering pipeline from Vulkan init to frame submission."

## Sync Mode

By default, config, skills, and memory are only copied into the volume on first boot. To always overwrite from the image (useful when iterating on skills or config):

```bash
docker run -d \
  -e SYNC_MODE=true \
  -e POLYPHASE_REPO=https://github.com/Polyphase-Labs/Polyphase-Engine \
  -e OPENCLAW_HOME=/data/openclaw \
  -p 3348:3000 \
  -v openclaw_polyphase_state:/data/openclaw \
  --tty --interactive \
  polyphaselabs/polyphase-dev-claw:latest
```

## Docker Compose

```yaml
services:
  polyphase_claw:
    image: polyphaselabs/polyphase-dev-claw:latest
    environment:
      POLYPHASE_REPO: https://github.com/Polyphase-Labs/Polyphase-Engine
      OPENCLAW_HOME: /data/openclaw
      # SYNC_MODE: "true"       # Uncomment to overwrite config/skills/memory on every boot
      # ALLOWED_ORIGINS: "http://localhost:3348,https://myhost.example.com"
      # GATEWAY_TOKEN: "my-secret-token"
    ports:
      - "3348:3000"
    volumes:
      - openclaw_polyphase_state:/data/openclaw
    tty: true
    stdin_open: true

volumes:
  openclaw_polyphase_state:
```

## Links

- [Polyphase Engine](https://github.com/Polyphase-Labs/Polyphase-Engine)
- [Source & Dockerfile](https://github.com/Polyphase-Labs/Polyphase-Dev-Claw)
