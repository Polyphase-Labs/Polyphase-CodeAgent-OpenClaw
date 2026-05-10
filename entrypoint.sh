#!/bin/bash
set -e

# ----- GitHub auth setup -----
# Coding agents need to clone, push, and open PRs. Wire git + gh CLI from
# the GITHUB_TOKEN env var (a fine-grained or classic PAT with repo scope).
# Without a token we still start (the user may want a read-only session),
# but the open_pr.sh helper will refuse to push.
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "Configuring git + gh from GITHUB_TOKEN"
  git config --global user.name  "${GIT_AUTHOR_NAME:-Polyphase Code Agent}"
  git config --global user.email "${GIT_AUTHOR_EMAIL:-codeagent@polyphase.local}"
  git config --global init.defaultBranch main
  git config --global --add safe.directory '*'
  # gh stores the token and registers itself as git's credential helper for
  # github.com — handles both HTTPS clone/push and `gh pr create`.
  echo "$GITHUB_TOKEN" | gh auth login --hostname github.com --git-protocol https --with-token
  gh auth setup-git
else
  echo "WARNING: GITHUB_TOKEN is not set. The agent can still read the repo," \
       "but clone of private repos, push, and PR creation will fail." >&2
fi

# Clone (or pull) the target repo into the workspace.
bash "./build.sh"

cd "$POLYPHASE_DIR"

# Ensure directories exist
mkdir -p /data/openclaw/.openclaw/workspace/memory
mkdir -p /data/openclaw/.openclaw/workspace/skills
mkdir -p /root/.openclaw/skills
mkdir -p /root/.openclaw/memory

# First run: copy everything from the image
if [ ! -f /data/openclaw/.openclaw/flag.json ]; then
  echo "First run detected, copying config and skills"
  cp /tmp/openclaw.json /data/openclaw/.openclaw/openclaw.json
  cp /tmp/openclaw.json /root/.openclaw/openclaw.json
  cp -r /tmp/skills/* /data/openclaw/.openclaw/workspace/skills/
  cp -r /tmp/memory/* /data/openclaw/.openclaw/workspace/memory/
  cp -r /tmp/skills/* /root/.openclaw/skills/
  cp -r /tmp/memory/* /root/.openclaw/memory/
  touch /data/openclaw/.openclaw/flag.json
fi

# Sync mode: only overwrite skills and memory, merge config (preserves runtime changes like discord tokens, onboarding creds)
if [ "$SYNC_MODE" = "true" ]; then
  echo "Sync mode: updating skills and memory from image"
  cp -r /tmp/skills/* /data/openclaw/.openclaw/workspace/skills/
  cp -r /tmp/memory/* /data/openclaw/.openclaw/workspace/memory/
  cp -r /tmp/skills/* /root/.openclaw/skills/
  cp -r /tmp/memory/* /root/.openclaw/memory/

  # Merge image config into existing config (image values win, but existing keys not in image are preserved)
  for cfg in /data/openclaw/.openclaw/openclaw.json /root/.openclaw/openclaw.json; do
    if [ -f "$cfg" ]; then
      node -e "
        const fs = require('fs');
        const deepMerge = (target, source) => {
          for (const key of Object.keys(source)) {
            if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])
                && target[key] && typeof target[key] === 'object' && !Array.isArray(target[key])) {
              deepMerge(target[key], source[key]);
            } else {
              target[key] = source[key];
            }
          }
          return target;
        };
        const existing = JSON.parse(fs.readFileSync('$cfg', 'utf8'));
        const image = JSON.parse(fs.readFileSync('/tmp/openclaw.json', 'utf8'));
        const merged = deepMerge(existing, image);
        fs.writeFileSync('$cfg', JSON.stringify(merged, null, 2) + '\n');
      "
    fi
  done
  echo "Sync mode: merged config from image (preserving runtime changes)"
fi

# Runtime patches — these only touch specific fields, preserving everything else
for cfg in /data/openclaw/.openclaw/openclaw.json /root/.openclaw/openclaw.json; do
  if [ -f "$cfg" ]; then
    node -e "
      const fs = require('fs');
      const cfg = JSON.parse(fs.readFileSync('$cfg', 'utf8'));
      cfg.gateway = cfg.gateway || {};
      cfg.gateway.controlUi = cfg.gateway.controlUi || {};
      cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
      cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
      fs.writeFileSync('$cfg', JSON.stringify(cfg, null, 2) + '\n');
    "
  fi
done

# Patch allowedOrigins at runtime if ALLOWED_ORIGINS is set
# Accepts a comma-separated list, e.g. ALLOWED_ORIGINS="http://localhost:3348,https://myhost.example.com"
if [ -n "$ALLOWED_ORIGINS" ]; then
  ORIGINS_JSON=$(echo "$ALLOWED_ORIGINS" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
  for cfg in /data/openclaw/.openclaw/openclaw.json /root/.openclaw/openclaw.json; do
    if [ -f "$cfg" ]; then
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('$cfg', 'utf8'));
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.controlUi = cfg.gateway.controlUi || {};
        cfg.gateway.controlUi.allowedOrigins = $ORIGINS_JSON;
        fs.writeFileSync('$cfg', JSON.stringify(cfg, null, 2) + '\n');
      "
    fi
  done
  echo "Patched allowedOrigins: $ALLOWED_ORIGINS"
fi

# Patch gateway auth token at runtime if GATEWAY_TOKEN is set
if [ -n "$GATEWAY_TOKEN" ]; then
  for cfg in /data/openclaw/.openclaw/openclaw.json /root/.openclaw/openclaw.json; do
    if [ -f "$cfg" ]; then
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('$cfg', 'utf8'));
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.auth = cfg.gateway.auth || {};
        cfg.gateway.auth.token = '$GATEWAY_TOKEN';
        fs.writeFileSync('$cfg', JSON.stringify(cfg, null, 2) + '\n');
      "
    fi
  done
  echo "Patched gateway auth token from GATEWAY_TOKEN env"
fi

# Fix permissions
chmod 700 /data/openclaw/.openclaw

exec openclaw gateway run --bind lan --port 3000
