# syntax=docker/dockerfile:1.6
FROM node:22-slim

ENV OPENCLAW_HOME=/data/openclaw \
    WORKSPACE=/workspace \
    POLYPHASE_DIR=/data/openclaw/.openclaw/workspace/Polyphase \
    POLYPHASE_PATH=/data/openclaw/.openclaw/workspace/Polyphase

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally via npm
RUN npm install -g openclaw

WORKDIR ${WORKSPACE}

# Copy OpenClaw config (staged for runtime copy since /data/openclaw is a volume)
COPY openclaw/openclaw.json /root/.openclaw/openclaw.json
COPY openclaw/openclaw.json /tmp/openclaw.json
COPY openclaw/workspace/skills/ /tmp/skills/
COPY openclaw/workspace/memory/ /tmp/memory/

EXPOSE 3000

COPY entrypoint.sh /entrypoint.sh
COPY build.sh /workspace/build.sh
RUN chmod +x /entrypoint.sh /workspace/build.sh

ENTRYPOINT ["/entrypoint.sh"]
