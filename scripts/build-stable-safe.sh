#!/usr/bin/env bash
set -euo pipefail

if [[ "${ALLOW_STABLE_BUILD:-0}" == "1" ]]; then
	echo "[build:stable:safe] ALLOW_STABLE_BUILD=1 set; running stable build."
	exec bun run build:stable
fi

if [[ -n "${CODEX_HOME:-}" || -n "${CODEX_SANDBOX:-}" || "${CI_SANDBOX:-0}" == "1" || "${SANDBOXED_DEV_TOOL:-0}" == "1" ]]; then
	echo "[build:stable:safe] sandboxed environment detected; skipping 'bun run build:stable'."
	echo "[build:stable:safe] use local Terminal/iTerm or set ALLOW_STABLE_BUILD=1 to force."
	exit 0
fi

echo "[build:stable:safe] unsandboxed environment detected; running stable build."
exec bun run build:stable
