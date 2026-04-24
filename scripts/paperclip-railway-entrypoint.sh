#!/bin/sh
# Railway-only entrypoint: bootstrap the Claude Code OAuth credentials from
# CLAUDE_CREDENTIALS_JSON (so claude_local agents can use the operator's
# Anthropic Max subscription without an interactive OAuth flow inside the
# container) AND clone the Remoteand-org workspace repos on first boot, then
# exec the normal CMD.
#
# Both bootstraps are idempotent — they only run if the target doesn't exist
# on the persistent volume.

set -eu

# --- 1. Claude Code OAuth credentials ------------------------------------
CRED_DIR="${HOME:-/paperclip}/.claude"
CRED_FILE="$CRED_DIR/.credentials.json"

if [ -n "${CLAUDE_CREDENTIALS_JSON:-}" ] && [ ! -s "$CRED_FILE" ]; then
  mkdir -p "$CRED_DIR"
  printf '%s' "$CLAUDE_CREDENTIALS_JSON" > "$CRED_FILE"
  chmod 600 "$CRED_FILE"
  echo "[entrypoint] wrote $CRED_FILE ($(wc -c < $CRED_FILE) bytes) from CLAUDE_CREDENTIALS_JSON env"
elif [ -s "$CRED_FILE" ]; then
  echo "[entrypoint] $CRED_FILE already exists ($(wc -c < $CRED_FILE) bytes) — leaving it alone"
fi

# --- 2. Workspace repos (clone on first boot) ----------------------------
WORKSPACES_DIR="/paperclip/workspaces"

if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "[entrypoint] bootstrapping git config + ensuring Remoteand-org repos under $WORKSPACES_DIR"
  mkdir -p "$WORKSPACES_DIR"

  # Default agent identity for commits — overridden per-repo below where needed.
  git config --global user.email "tech@remoteand.com"
  git config --global user.name "Remote& Agents"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global advice.detachedHead false

  # Per-repo idempotent clone: checks for .git (not just the dir) so Paperclip-created
  # empty cwd stubs don't block the clone.
  for repo in remote-and remoteand-website remoteand-fundraising-kit remoteand-context paperclip; do
    if [ ! -d "$WORKSPACES_DIR/$repo/.git" ]; then
      echo "[entrypoint] cloning Remoteand-org/$repo"
      rm -rf "$WORKSPACES_DIR/$repo" 2>/dev/null || true
      git clone --quiet \
        "https://x-access-token:${GITHUB_TOKEN}@github.com/Remoteand-org/${repo}.git" \
        "$WORKSPACES_DIR/$repo" || echo "[entrypoint] WARN: clone failed for $repo (continuing)"
    fi
  done

  # Website repo's Vercel team requires a specific git committer email.
  if [ -d "$WORKSPACES_DIR/remoteand-website" ]; then
    git -C "$WORKSPACES_DIR/remoteand-website" config user.email "mahmoudd.khaled95@gmail.com"
    git -C "$WORKSPACES_DIR/remoteand-website" config user.name "Mahmoud Khaled"
  fi

  echo "[entrypoint] workspaces ready:"
  ls -la "$WORKSPACES_DIR" | sed 's/^/[entrypoint]   /'
fi

exec "$@"
