#!/usr/bin/env bash
# ClawKiller standalone uninstaller for OpenClaw
# Author: Tiggy Chan

CLAWKILLER_HOME_DIR="${HOME:-${USERPROFILE:-}}"
if [ -z "$CLAWKILLER_HOME_DIR" ]; then
  CLAWKILLER_HOME_DIR="$(cd ~ 2>/dev/null && pwd || printf '.')"
fi

declare -r CLAWKILLER_PLATFORM="linux"
declare -r CLAWKILLER_DEFAULT_CONFIG_PATH="$CLAWKILLER_HOME_DIR/.config/openclaw/config.json"

declare -a CLAWKILLER_APP_TARGETS=(
  "$CLAWKILLER_HOME_DIR/.local/share/OpenClaw"
  "/opt/OpenClaw"
)

declare -a CLAWKILLER_PACKAGE_NAMES=(
  "openclaw"
  "openclaw-cli"
  "openclaw-gateway"
)

declare -a CLAWKILLER_BREW_FORMULAE=(
  "openclaw"
)

declare -a CLAWKILLER_NPM_PACKAGES=(
  "openclaw"
)

declare -a CLAWKILLER_FLATPAK_IDS=(
  "ai.openclaw.OpenClaw"
  "com.openclaw.OpenClaw"
  "bot.molt.OpenClaw"
  "openclaw"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared ClawKiller behavior for Unix-like standalone uninstallers by Tiggy Chan.
source "$SCRIPT_DIR/uninstall-unix-common.sh"

clawkiller_main "$@"
