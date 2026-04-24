#!/bin/sh
# Railway-only entrypoint: bootstrap the Claude Code OAuth credentials from
# CLAUDE_CREDENTIALS_JSON (so claude_local agents can use the operator's
# Anthropic Max subscription without an interactive OAuth flow inside the
# container), then exec the normal CMD.
#
# This is idempotent: if the credentials file already exists on the persistent
# volume, we don't overwrite it (so any token-refresh updates Claude Code wrote
# back to disk are preserved).

set -eu

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

exec "$@"
