# Slim Railway Dockerfile for Paperclip — uses the published npm CLI (paperclipai)
# instead of building the monorepo from source. This avoids:
#   - upstream master TS errors on packages/server
#   - stale-SHA failures in the gh CLI keyring install
#   - the VOLUME directive (Railway-banned)
#
# Strategy: install paperclipai globally + agent CLIs needed by adapters,
# then `paperclipai run` will start the embedded server using env-vars provided
# by Railway (DATABASE_URL, BETTER_AUTH_SECRET, PAPERCLIP_PUBLIC_URL, etc.).

FROM node:22-slim

# Tools needed by claude-local / codex-local adapters at runtime
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git ripgrep python3 jq openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Install paperclipai CLI + agent CLIs globally
RUN npm install -g \
      paperclipai@2026.416.0 \
      @anthropic-ai/claude-code \
      @openai/codex \
      opencode-ai

# Defaults — Railway env-vars override these
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3100 \
    SERVE_UI=true \
    PAPERCLIP_HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    PAPERCLIP_DEPLOYMENT_MODE=authenticated \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=public

WORKDIR /paperclip
EXPOSE 3100

# `run` does first-boot bootstrap (onboard + doctor) using env vars then starts the server
CMD ["paperclipai", "run", "--bind", "loopback", "--data-dir", "/paperclip"]
