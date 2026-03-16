#!/usr/bin/env bash
# ClawKiller standalone uninstaller for OpenClaw
# Author: Tiggy Chan

set -u
set -o pipefail

: "${CLAWKILLER_PLATFORM:?CLAWKILLER_PLATFORM must be set before sourcing uninstall-unix-common.sh}"
: "${CLAWKILLER_DEFAULT_CONFIG_PATH:?CLAWKILLER_DEFAULT_CONFIG_PATH must be set before sourcing uninstall-unix-common.sh}"

CLAWKILLER_HOME_DIR="${CLAWKILLER_HOME_DIR:-${HOME:-${USERPROFILE:-}}}"
if [ -z "$CLAWKILLER_HOME_DIR" ]; then
  CLAWKILLER_HOME_DIR="$(cd ~ 2>/dev/null && pwd || printf '.')"
fi

declare -r CLAWKILLER_NAME="ClawKiller"
declare -r CLAWKILLER_AUTHOR="Tiggy Chan"

if ! declare -p CLAWKILLER_APP_TARGETS >/dev/null 2>&1; then
  declare -a CLAWKILLER_APP_TARGETS=()
fi

if ! declare -p CLAWKILLER_PACKAGE_NAMES >/dev/null 2>&1; then
  declare -a CLAWKILLER_PACKAGE_NAMES=(openclaw openclaw-cli openclaw-gateway)
fi

if ! declare -p CLAWKILLER_BREW_FORMULAE >/dev/null 2>&1; then
  declare -a CLAWKILLER_BREW_FORMULAE=(openclaw)
fi

if ! declare -p CLAWKILLER_BREW_CASKS >/dev/null 2>&1; then
  declare -a CLAWKILLER_BREW_CASKS=()
fi

if ! declare -p CLAWKILLER_NPM_PACKAGES >/dev/null 2>&1; then
  declare -a CLAWKILLER_NPM_PACKAGES=(openclaw)
fi

if ! declare -p CLAWKILLER_FLATPAK_IDS >/dev/null 2>&1; then
  declare -a CLAWKILLER_FLATPAK_IDS=(ai.openclaw.OpenClaw com.openclaw.OpenClaw bot.molt.OpenClaw openclaw)
fi

if ! declare -p CLAWKILLER_PKGUTIL_RECEIPTS >/dev/null 2>&1; then
  declare -a CLAWKILLER_PKGUTIL_RECEIPTS=()
fi

if ! declare -p CLAWKILLER_LAUNCH_LABELS >/dev/null 2>&1; then
  declare -a CLAWKILLER_LAUNCH_LABELS=()
fi

if ! declare -p CLAWKILLER_LAUNCH_PLIST_PATTERNS >/dev/null 2>&1; then
  declare -a CLAWKILLER_LAUNCH_PLIST_PATTERNS=()
fi

SERVICE=0
STATE=0
WORKSPACE=0
APP=0
CLI=0
BACKUP=0
DRY_RUN=0
YES=0
PROFILES="all"
declare -a CLAWKILLER_REPORT_ACTIONS=()
declare -a CLAWKILLER_REPORT_SKIPS=()
declare -a CLAWKILLER_REPORT_WARNINGS=()

clawkiller_log() {
  printf '[clawkiller/%s] %s\n' "$CLAWKILLER_PLATFORM" "$1"
}

clawkiller_record_action() {
  CLAWKILLER_REPORT_ACTIONS+=("$1")
}

clawkiller_record_skip() {
  CLAWKILLER_REPORT_SKIPS+=("$1")
}

clawkiller_record_warning() {
  CLAWKILLER_REPORT_WARNINGS+=("$1")
}

clawkiller_warn() {
  clawkiller_record_warning "$1"
  printf '[clawkiller/%s] warning: %s\n' "$CLAWKILLER_PLATFORM" "$1" >&2
}

clawkiller_print_banner() {
  cat <<EOF

==============================================
   ______ _                 _  ___ _ _ _
  / ____| |               | |/ (_) | | |
 | |    | | __ ___      __| ' / _| | | | ___ _ __
 | |    | |/ _\` \ \ /\ / /|  < | | | | |/ _ \ '__|
 | |____| | (_| |\ V  V / | . \| | | | |  __/ |
  \_____|_|\__,_| \_/\_/  |_|\_\_|_|_|_|\___|_|

  $CLAWKILLER_NAME | OpenClaw Standalone Uninstaller
  Author: $CLAWKILLER_AUTHOR
==============================================

EOF
}

clawkiller_get_scope_text() {
  local scope_text=""

  [ "$SERVICE" -eq 1 ] && scope_text="${scope_text}service "
  [ "$STATE" -eq 1 ] && scope_text="${scope_text}state "
  [ "$WORKSPACE" -eq 1 ] && scope_text="${scope_text}workspace "
  [ "$APP" -eq 1 ] && scope_text="${scope_text}app "
  [ "$CLI" -eq 1 ] && scope_text="${scope_text}cli "

  scope_text="${scope_text% }"
  if [ -z "$scope_text" ]; then
    scope_text="none"
  fi

  printf '%s' "$scope_text"
}

clawkiller_print_report_section() {
  local title="$1"
  local array_name="$2"
  local count=0
  local index=0
  local item=""

  eval "count=\${#$array_name[@]}"
  [ "$count" -gt 0 ] || return 0

  clawkiller_log "$title ($count):"
  while [ "$index" -lt "$count" ]; do
    eval "item=\${$array_name[$index]}"
    clawkiller_log "  - $item"
    index=$((index + 1))
  done
}

clawkiller_print_report() {
  local action_title="actions"
  local action_count skip_count warning_count

  [ "$DRY_RUN" -eq 1 ] && action_title="planned actions"

  action_count="${#CLAWKILLER_REPORT_ACTIONS[@]}"
  skip_count="${#CLAWKILLER_REPORT_SKIPS[@]}"
  warning_count="${#CLAWKILLER_REPORT_WARNINGS[@]}"

  clawkiller_log "uninstall report: mode=$([ "$DRY_RUN" -eq 1 ] && printf 'dry-run' || printf 'execute'), scopes=$(clawkiller_get_scope_text), actions=$action_count, skipped=$skip_count, warnings=$warning_count"
  clawkiller_print_report_section "$action_title" CLAWKILLER_REPORT_ACTIONS
  clawkiller_print_report_section "skipped" CLAWKILLER_REPORT_SKIPS
  clawkiller_print_report_section "warnings" CLAWKILLER_REPORT_WARNINGS
}

clawkiller_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

clawkiller_format_cmd() {
  local rendered=""
  local arg
  for arg in "$@"; do
    if [ -n "$rendered" ]; then
      rendered="$rendered "
    fi
    rendered="$rendered$(printf '%q' "$arg")"
  done
  printf '%s' "$rendered"
}

clawkiller_run_cmd() {
  local rendered
  rendered="$(clawkiller_format_cmd "$@")"
  if [ "$DRY_RUN" -eq 1 ]; then
    clawkiller_log "[dry-run] $rendered"
    return 0
  fi
  "$@"
}

clawkiller_run_quiet_cmd() {
  local rendered
  rendered="$(clawkiller_format_cmd "$@")"
  if [ "$DRY_RUN" -eq 1 ]; then
    clawkiller_log "[dry-run] $rendered"
    return 0
  fi
  "$@" >/dev/null 2>&1
}

clawkiller_can_use_sudo() {
  clawkiller_has_cmd sudo && sudo -n true >/dev/null 2>&1
}

clawkiller_run_root_cmd() {
  local rendered
  rendered="$(clawkiller_format_cmd "$@")"

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$(id -u)" -eq 0 ]; then
      clawkiller_log "[dry-run] $rendered"
    else
      clawkiller_log "[dry-run] sudo $rendered"
    fi
    return 0
  fi

  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return $?
  fi

  if clawkiller_can_use_sudo; then
    sudo "$@"
    return $?
  fi

  clawkiller_warn "skip command that requires root: $rendered"
  return 0
}

clawkiller_run_root_quiet_cmd() {
  local rendered
  rendered="$(clawkiller_format_cmd "$@")"

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$(id -u)" -eq 0 ]; then
      clawkiller_log "[dry-run] $rendered"
    else
      clawkiller_log "[dry-run] sudo $rendered"
    fi
    return 0
  fi

  if [ "$(id -u)" -eq 0 ]; then
    "$@" >/dev/null 2>&1
    return $?
  fi

  if clawkiller_can_use_sudo; then
    sudo "$@" >/dev/null 2>&1
    return $?
  fi

  clawkiller_warn "skip command that requires root: $rendered"
  return 0
}

clawkiller_confirm() {
  if [ "$DRY_RUN" -eq 1 ] || [ "$YES" -eq 1 ]; then
    return 0
  fi

  local scope_text
  scope_text="$(clawkiller_get_scope_text)"

  printf '[clawkiller/%s] confirm purge for scopes: %s [y/N] ' "$CLAWKILLER_PLATFORM" "$scope_text" >&2
  local reply=""
  read -r reply || return 1
  case "$reply" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      clawkiller_log "cancelled."
      return 1
      ;;
  esac
}

clawkiller_emit_optimized_paths() {
  local candidate normalized existing skip i
  local -a selected=()

  for candidate in "$@"; do
    if [ -z "${candidate:-}" ]; then
      continue
    fi

    normalized="${candidate%/}"
    if [ -z "$normalized" ]; then
      normalized="/"
    fi

    skip=0
    for i in "${!selected[@]}"; do
      existing="${selected[$i]}"

      if [ "$normalized" = "$existing" ]; then
        skip=1
        break
      fi

      case "$normalized/" in
        "$existing"/*)
          if [ "$normalized" != "$existing" ]; then
            skip=1
            break
          fi
          ;;
      esac

      case "$existing/" in
        "$normalized"/*)
          if [ "$normalized" != "$existing" ]; then
            selected[$i]="$normalized"
            skip=1
            break
          fi
          ;;
      esac
    done

    [ "$skip" -eq 1 ] || selected+=("$normalized")
  done

  printf '%s\n' "${selected[@]}"
}

clawkiller_remove_path() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    return 0
  fi

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    clawkiller_log "skip missing: $target"
    clawkiller_record_skip "missing path $target"
    return 0
  fi

  local parent
  parent="$(dirname "$target")"
  if [ -w "$target" ] || [ -w "$parent" ]; then
    clawkiller_log "remove $target"
    clawkiller_record_action "remove $target"
    clawkiller_run_cmd rm -rf -- "$target" || clawkiller_warn "failed to remove $target"
  else
    clawkiller_log "remove $target"
    clawkiller_record_action "remove $target"
    clawkiller_run_root_cmd rm -rf -- "$target" || clawkiller_warn "failed to remove $target"
  fi
}

clawkiller_fallback_backup() {
  local backup_root="$CLAWKILLER_HOME_DIR/ClawKiller-Backup/$CLAWKILLER_PLATFORM-$(date +%Y%m%d-%H%M%S)"
  clawkiller_log "create fallback backup at $backup_root"
  clawkiller_record_action "create fallback backup at $backup_root"

  if [ "$DRY_RUN" -eq 1 ]; then
    clawkiller_log "[dry-run] mkdir -p $(printf '%q' "$backup_root")"
    return 0
  fi

  mkdir -p "$backup_root"
  [ -d "$STATE_DIR" ] && cp -R "$STATE_DIR" "$backup_root/"
  if [ -d "$CONFIG_DIR" ]; then
    cp -R "$CONFIG_DIR" "$backup_root/"
  elif [ -f "$CONFIG_PATH" ]; then
    cp "$CONFIG_PATH" "$backup_root/"
  fi
  [ -d "$WORKSPACE_DIR" ] && cp -R "$WORKSPACE_DIR" "$backup_root/"
}

clawkiller_run_backup() {
  if [ "$BACKUP" -eq 0 ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    clawkiller_log "[dry-run] backup OpenClaw data"
    clawkiller_record_action "backup OpenClaw data"
    return 0
  fi

  if [ -n "$CLI_PATH" ]; then
    clawkiller_log "run official backup via OpenClaw CLI"
    if ! "$CLI_PATH" backup create --json; then
      clawkiller_warn "official backup failed, switching to fallback copy"
      clawkiller_fallback_backup
    else
      clawkiller_record_action "run official OpenClaw backup via CLI"
    fi
  else
    clawkiller_fallback_backup
  fi
}

clawkiller_cleanup_npm_records() {
  clawkiller_has_cmd npm || return 0

  local pkg
  for pkg in "${CLAWKILLER_NPM_PACKAGES[@]}"; do
    if npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove npm global package record $pkg"
      clawkiller_record_action "remove npm global package record $pkg"
      clawkiller_run_quiet_cmd npm uninstall -g "$pkg" || clawkiller_warn "npm uninstall failed for $pkg"
    fi
  done
}

clawkiller_cleanup_brew_records() {
  clawkiller_has_cmd brew || return 0

  local token
  for token in "${CLAWKILLER_BREW_FORMULAE[@]}"; do
    if brew list --formula "$token" >/dev/null 2>&1; then
      clawkiller_log "remove Homebrew formula record $token"
      clawkiller_record_action "remove Homebrew formula record $token"
      clawkiller_run_quiet_cmd brew uninstall --formula "$token" || clawkiller_warn "brew uninstall failed for formula $token"
    fi
  done

  for token in "${CLAWKILLER_BREW_CASKS[@]}"; do
    if brew list --cask "$token" >/dev/null 2>&1; then
      clawkiller_log "remove Homebrew cask record $token"
      clawkiller_record_action "remove Homebrew cask record $token"
      clawkiller_run_quiet_cmd brew uninstall --cask "$token" || clawkiller_warn "brew uninstall failed for cask $token"
    fi
  done
}

clawkiller_cleanup_apt_records() {
  clawkiller_has_cmd dpkg-query || return 0
  clawkiller_has_cmd apt-get || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx 'installed'; then
      clawkiller_log "purge apt package record $pkg"
      clawkiller_record_action "purge apt package record $pkg"
      clawkiller_run_root_quiet_cmd env DEBIAN_FRONTEND=noninteractive apt-get -y purge "$pkg" || clawkiller_warn "apt purge failed for $pkg"
    fi
  done
}

clawkiller_cleanup_dnf_records() {
  clawkiller_has_cmd rpm || return 0
  clawkiller_has_cmd dnf || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove dnf package record $pkg"
      clawkiller_record_action "remove dnf package record $pkg"
      clawkiller_run_root_quiet_cmd dnf -y remove "$pkg" || clawkiller_warn "dnf remove failed for $pkg"
    fi
  done
}

clawkiller_cleanup_yum_records() {
  clawkiller_has_cmd rpm || return 0
  clawkiller_has_cmd yum || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove yum package record $pkg"
      clawkiller_record_action "remove yum package record $pkg"
      clawkiller_run_root_quiet_cmd yum -y remove "$pkg" || clawkiller_warn "yum remove failed for $pkg"
    fi
  done
}

clawkiller_cleanup_pacman_records() {
  clawkiller_has_cmd pacman || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove pacman package record $pkg"
      clawkiller_record_action "remove pacman package record $pkg"
      clawkiller_run_root_quiet_cmd pacman -Rn --noconfirm "$pkg" || clawkiller_warn "pacman remove failed for $pkg"
    fi
  done
}

clawkiller_cleanup_zypper_records() {
  clawkiller_has_cmd rpm || return 0
  clawkiller_has_cmd zypper || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove zypper package record $pkg"
      clawkiller_record_action "remove zypper package record $pkg"
      clawkiller_run_root_quiet_cmd zypper --non-interactive rm "$pkg" || clawkiller_warn "zypper remove failed for $pkg"
    fi
  done
}

clawkiller_cleanup_snap_records() {
  clawkiller_has_cmd snap || return 0

  local pkg
  for pkg in "${CLAWKILLER_PACKAGE_NAMES[@]}"; do
    if snap list "$pkg" >/dev/null 2>&1; then
      clawkiller_log "remove snap package record $pkg"
      clawkiller_record_action "remove snap package record $pkg"
      clawkiller_run_root_quiet_cmd snap remove --purge "$pkg" || clawkiller_warn "snap remove failed for $pkg"
    fi
  done
}

clawkiller_cleanup_flatpak_records() {
  clawkiller_has_cmd flatpak || return 0

  local app_id
  for app_id in "${CLAWKILLER_FLATPAK_IDS[@]}"; do
    if flatpak info --user --app "$app_id" >/dev/null 2>&1; then
      clawkiller_log "remove user flatpak record $app_id"
      clawkiller_record_action "remove user flatpak record $app_id"
      clawkiller_run_quiet_cmd flatpak uninstall --user --noninteractive -y --delete-data --app "$app_id" || clawkiller_warn "flatpak uninstall failed for user app $app_id"
    fi
    if flatpak info --system --app "$app_id" >/dev/null 2>&1; then
      clawkiller_log "remove system flatpak record $app_id"
      clawkiller_record_action "remove system flatpak record $app_id"
      clawkiller_run_root_quiet_cmd flatpak uninstall --system --noninteractive -y --delete-data --app "$app_id" || clawkiller_warn "flatpak uninstall failed for system app $app_id"
    fi
  done
}

clawkiller_cleanup_pkgutil_receipts() {
  clawkiller_has_cmd pkgutil || return 0

  local receipt
  for receipt in "${CLAWKILLER_PKGUTIL_RECEIPTS[@]}"; do
    if pkgutil --pkgs | grep -Fx "$receipt" >/dev/null 2>&1; then
      clawkiller_log "forget pkgutil receipt $receipt"
      clawkiller_record_action "forget pkgutil receipt $receipt"
      clawkiller_run_root_quiet_cmd pkgutil --forget "$receipt" || clawkiller_warn "pkgutil --forget failed for $receipt"
    fi
  done
}

clawkiller_cleanup_package_manager_records() {
  if [ "$APP" -eq 0 ] && [ "$CLI" -eq 0 ] && [ "$SERVICE" -eq 0 ]; then
    return 0
  fi

  clawkiller_cleanup_npm_records
  clawkiller_cleanup_brew_records
  clawkiller_cleanup_apt_records
  clawkiller_cleanup_dnf_records
  clawkiller_cleanup_yum_records
  clawkiller_cleanup_pacman_records
  clawkiller_cleanup_zypper_records
  clawkiller_cleanup_snap_records
  clawkiller_cleanup_flatpak_records

  if [ "$CLAWKILLER_PLATFORM" = "macos" ]; then
    clawkiller_cleanup_pkgutil_receipts
  fi
}

clawkiller_collect_cli_targets() {
  local -a targets=()
  local cli_dir cli_prefix npm_prefix

  if [ -n "$CLI_PATH" ]; then
    targets+=("$CLI_PATH")
    cli_dir="$(dirname "$CLI_PATH")"
    targets+=(
      "$cli_dir/openclaw"
      "$cli_dir/openclaw.cmd"
      "$cli_dir/openclaw.ps1"
      "$cli_dir/openclaw.bat"
      "$cli_dir/openclaw.exe"
    )

    cli_prefix="$(dirname "$cli_dir")"
    targets+=("$cli_prefix/lib/node_modules/openclaw")
  fi

  if clawkiller_has_cmd npm; then
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ]; then
      targets+=(
        "$npm_prefix/bin/openclaw"
        "$npm_prefix/lib/node_modules/openclaw"
      )
    fi
  fi

  if [ "${#targets[@]}" -gt 0 ]; then
    clawkiller_emit_optimized_paths "${targets[@]}"
  fi
}

clawkiller_remove_cli_targets() {
  local rendered_targets target
  rendered_targets="$(clawkiller_collect_cli_targets)"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    clawkiller_remove_path "$target"
  done <<EOF
$rendered_targets
EOF
}

clawkiller_cleanup_service_linux() {
  if [ "$SERVICE" -eq 0 ]; then
    return 0
  fi

  if clawkiller_has_cmd systemctl && systemctl --user cat openclaw-gateway.service >/dev/null 2>&1; then
    clawkiller_record_action "stop systemd user service openclaw-gateway.service"
    clawkiller_run_quiet_cmd systemctl --user stop openclaw-gateway.service || true
    clawkiller_record_action "disable systemd user service openclaw-gateway.service"
    clawkiller_run_quiet_cmd systemctl --user disable openclaw-gateway.service || true
  fi

  local unit
  for unit in "$CLAWKILLER_HOME_DIR"/.config/systemd/user/openclaw-gateway*.service; do
    [ -e "$unit" ] && clawkiller_remove_path "$unit"
  done

  if clawkiller_has_cmd systemctl; then
    clawkiller_record_action "reload systemd user daemon"
    clawkiller_run_quiet_cmd systemctl --user daemon-reload || true
  fi
}

clawkiller_cleanup_service_macos() {
  if [ "$SERVICE" -eq 0 ]; then
    return 0
  fi

  local label pattern plist
  for label in "${CLAWKILLER_LAUNCH_LABELS[@]}"; do
    clawkiller_record_action "remove launchctl label $label"
    clawkiller_run_quiet_cmd launchctl remove "$label" || true
  done

  shopt -s nullglob
  for pattern in "${CLAWKILLER_LAUNCH_PLIST_PATTERNS[@]}"; do
    for plist in $pattern; do
      clawkiller_remove_path "$plist"
    done
  done
  shopt -u nullglob
}

clawkiller_cleanup_service() {
  case "$CLAWKILLER_PLATFORM" in
    linux)
      clawkiller_cleanup_service_linux
      ;;
    macos)
      clawkiller_cleanup_service_macos
      ;;
  esac
}

clawkiller_remove_manual_targets() {
  local -a targets=()
  local target

  if [ "$STATE" -eq 1 ]; then
    targets+=("$STATE_DIR" "$CONFIG_DIR" "$CONFIG_PATH")
  fi
  if [ "$WORKSPACE" -eq 1 ]; then
    targets+=("$WORKSPACE_DIR")
  fi
  if [ "$APP" -eq 1 ]; then
    targets+=("${CLAWKILLER_APP_TARGETS[@]}")
  fi

  local rendered_targets
  if [ "${#targets[@]}" -gt 0 ]; then
    rendered_targets="$(clawkiller_emit_optimized_paths "${targets[@]}")"
  else
    rendered_targets=""
  fi

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    clawkiller_remove_path "$target"
  done <<EOF
$rendered_targets
EOF

  if [ "$CLI" -eq 1 ]; then
    clawkiller_remove_cli_targets
  fi
}

clawkiller_show_help() {
  clawkiller_print_banner
  cat <<EOF
Usage: $(basename "$0") [options]
  --all --service --state --workspace --app --cli
  --backup --dry-run --yes --profiles current|all

ClawKiller removes OpenClaw-owned artifacts and exact-match package-manager records.
EOF
}

clawkiller_parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --all)
        SERVICE=1
        STATE=1
        WORKSPACE=1
        APP=1
        CLI=1
        ;;
      --service) SERVICE=1 ;;
      --state) STATE=1 ;;
      --workspace) WORKSPACE=1 ;;
      --app) APP=1 ;;
      --cli) CLI=1 ;;
      --backup) BACKUP=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --yes) YES=1 ;;
      --profiles)
        shift
        PROFILES="${1:-all}"
        ;;
      --help|-h)
        clawkiller_show_help
        exit 0
        ;;
      *)
        clawkiller_warn "unknown argument: $1"
        exit 1
        ;;
    esac
    shift
  done
}

clawkiller_main() {
  clawkiller_parse_args "$@"
  clawkiller_print_banner

  if [ "$SERVICE" -eq 0 ] && [ "$STATE" -eq 0 ] && [ "$WORKSPACE" -eq 0 ] && [ "$APP" -eq 0 ] && [ "$CLI" -eq 0 ]; then
    SERVICE=1
    STATE=1
    WORKSPACE=1
    APP=1
    CLI=1
  fi

  if [ "$PROFILES" = "current" ]; then
    clawkiller_warn "profiles=current is not implemented by this standalone script. Falling back to all."
    PROFILES="all"
  fi

  STATE_DIR="${OPENCLAW_STATE_DIR:-$CLAWKILLER_HOME_DIR/.openclaw}"
  CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$CLAWKILLER_DEFAULT_CONFIG_PATH}"
  CONFIG_DIR="$(dirname "$CONFIG_PATH")"
  WORKSPACE_ROOT="${OPENCLAW_HOME:-$CLAWKILLER_HOME_DIR/.openclaw}"
  WORKSPACE_DIR="$WORKSPACE_ROOT/workspace"
  CLI_PATH="$(command -v openclaw 2>/dev/null || true)"

  clawkiller_log "profile mode: $PROFILES"

  clawkiller_confirm || exit 1
  clawkiller_run_backup
  clawkiller_cleanup_package_manager_records
  clawkiller_cleanup_service
  clawkiller_remove_manual_targets
  clawkiller_log "completed."
  clawkiller_print_report
}
