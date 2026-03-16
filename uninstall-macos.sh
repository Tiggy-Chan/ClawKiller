#!/usr/bin/env bash
# ClawKiller standalone uninstaller for OpenClaw
# Author: Tiggy Chan

CLAWKILLER_HOME_DIR="${HOME:-${USERPROFILE:-}}"
if [ -z "$CLAWKILLER_HOME_DIR" ]; then
  CLAWKILLER_HOME_DIR="$(cd ~ 2>/dev/null && pwd || printf '.')"
fi

declare -r CLAWKILLER_PLATFORM="macos"
declare -r CLAWKILLER_DEFAULT_CONFIG_PATH="$CLAWKILLER_HOME_DIR/Library/Application Support/OpenClaw/config.json"

declare -a CLAWKILLER_APP_TARGETS=(
  "/Applications/OpenClaw.app"
)

declare -a CLAWKILLER_PACKAGE_NAMES=(
  "openclaw"
  "openclaw-cli"
  "openclaw-gateway"
)

declare -a CLAWKILLER_BREW_FORMULAE=(
  "openclaw"
)

declare -a CLAWKILLER_BREW_CASKS=(
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

declare -a CLAWKILLER_PKGUTIL_RECEIPTS=(
  "ai.openclaw.gateway"
  "ai.openclaw.openclaw"
  "bot.molt.gateway"
  "bot.molt.openclaw"
  "com.openclaw.gateway"
  "com.openclaw.openclaw"
)

declare -a CLAWKILLER_LAUNCH_LABELS=(
  "ai.openclaw.gateway"
  "bot.molt.gateway"
  "com.openclaw.gateway"
)

declare -a CLAWKILLER_LAUNCH_PLIST_PATTERNS=(
  "$CLAWKILLER_HOME_DIR/Library/LaunchAgents/ai.openclaw*.plist"
  "$CLAWKILLER_HOME_DIR/Library/LaunchAgents/bot.molt*.plist"
  "$CLAWKILLER_HOME_DIR/Library/LaunchAgents/com.openclaw*.plist"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared ClawKiller behavior for Unix-like standalone uninstallers by Tiggy Chan.
source "$SCRIPT_DIR/uninstall-unix-common.sh"

clawkiller_main "$@"
