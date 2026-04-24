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

COPY scripts/paperclip-railway-entrypoint.sh /usr/local/bin/paperclip-railway-entrypoint.sh
RUN chmod +x /usr/local/bin/paperclip-railway-entrypoint.sh

WORKDIR /paperclip
EXPOSE 3100

# Entrypoint bootstraps Claude Code OAuth creds from CLAUDE_CREDENTIALS_JSON
# (so all 4 claude_local agents use the operator's Max sub on first boot)
# then execs the CMD.
ENTRYPOINT ["paperclip-railway-entrypoint.sh"]

# `onboard --yes` writes config (idempotent — no-op if already configured) AND starts
# the server. --bind lan binds to 0.0.0.0 so Railway's HTTP proxy can reach the
# container; deployment mode (authenticated/public) and PAPERCLIP_PUBLIC_URL come
# from Railway env vars and override at runtime.
CMD ["paperclipai", "onboard", "--yes", "--bind", "lan", "--data-dir", "/paperclip"]
