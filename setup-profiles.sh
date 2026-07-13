#!/usr/bin/env bash
set -euo pipefail

# Registers the multi-agent Sentry fixer prompts on the m0-controller and
# m0-worker profiles, and sets DEV_MODE on the controller profile.
#
# Usage: ./setup-profiles.sh [--prod]     (default: DEV_MODE=true)

cd "$(dirname "$0")"

dev_mode="true"
[[ "${1:-}" == "--prod" ]] && dev_mode="false"

# --- Prerequisites ----------------------------------------------------
echo "==> Checking profile integrations..."
machine0 integrations check m0-controller
machine0 integrations check m0-worker

# --- Compose the controller prompt -------------------------------------
# prompts/process-sentry.md embeds the worker SOP at registration time so
# prompts/fix-sentry-issue.md stays the single source of truth.
composed=$(mktemp /tmp/process-sentry-composed-XXXXXX.md)
trap 'rm -f "$composed"' EXIT

awk '/^\{\{WORKER_SOP\}\}$/ { while ((getline line < "prompts/fix-sentry-issue.md") > 0) print line; next } { print }' \
  prompts/process-sentry.md > "$composed"

if grep -q '{{WORKER_SOP}}' "$composed"; then
  echo "Error: {{WORKER_SOP}} marker was not substituted" >&2
  exit 1
fi

# --- Register prompts ---------------------------------------------------
register() { # register <profile> <name> <file> <description>
  local profile="$1" name="$2" file="$3" description="$4"
  if machine0 prompts new "$profile" "$name" --body @"$file" --description "$description" 2>/dev/null; then
    echo "==> Created prompt '$name' on '$profile'"
  else
    machine0 prompts update "$profile" "$name" --body @"$file" --description "$description"
    echo "==> Updated prompt '$name' on '$profile'"
  fi
}

register m0-controller process-sentry "$composed" \
  "Fan out the top-3 Sentry issues to disposable Codex worker VMs"
register m0-worker fix-sentry-issue prompts/fix-sentry-issue.md \
  "SOP template: clone fdmtl/machine0, branch, fix one Sentry issue, open a PR"

# --- Vars ---------------------------------------------------------------
machine0 vars set m0-controller DEV_MODE="$dev_mode"

echo "==> Done. DEV_MODE=$dev_mode (flipping it later requires recreating the controller VM)"
