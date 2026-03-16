<p align="center">
  <img src="./.github/assets/logo.png" alt="ClawKiller logo" width="220" />
</p>

<h1 align="center">ClawKiller</h1>

<p align="center">Cross-platform OpenClaw uninstaller for Windows, macOS, Linux, and WSL.</p>

<p align="center">
  <a href="./README.md">简体中文</a> |
  <a href="./README.en.md">English</a>
</p>

## Overview

**ClawKiller** is a cross-platform uninstaller for **OpenClaw**, built to remove the following as thoroughly as possible:

- OpenClaw application files
- CLI binaries and related leftovers
- services, scheduled tasks, LaunchAgents, and systemd user services
- state directories and config files
- workspace data
- exact-match package-manager installation records

It is useful when you want to fully uninstall OpenClaw, troubleshoot leftovers, or do a clean reset before reinstalling.

## Features

- Supports **Windows native / WSL / macOS / Linux**
- Scope-based cleanup: `service` / `state` / `workspace` / `app` / `cli`
- Full cleanup by default when no scope is specified
- **Dry-run** support to preview actions before execution
- **Backup** support before removal, with fallback copy-based backup if the official backup command fails
- Best-effort cleanup for common package-manager records
- Clear uninstall report after execution
- Honors custom environment paths:
  - `OPENCLAW_STATE_DIR`
  - `OPENCLAW_CONFIG_PATH`
  - `OPENCLAW_HOME`

## Repository Layout

```text
.
├── .github
│   └── assets
│       ├── donate-alipay.jpg
│       ├── donate-wechat.png
│       └── logo.png
├── README.md
├── README.en.md
├── uninstall-linux.sh
├── uninstall-macos.sh
├── uninstall-unix-common.sh
└── uninstall-windows.ps1
```

> `uninstall-linux.sh` and `uninstall-macos.sh` depend on `uninstall-unix-common.sh`, so keep them in the same directory.

## Quick Start

### Windows

Run directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

Preview actions first:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -DryRun
```

Run a full cleanup with auto-confirm:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -All -Yes
```

Create a backup before removal:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -All -Backup -Yes
```

Only clean state and workspace data:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -State -Workspace -Yes
```

Only clean OpenClaw inside WSL:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -Mode wsl -Distro Ubuntu -All -Yes
```

### Linux

Grant execute permissions first:

```bash
chmod +x uninstall-linux.sh uninstall-unix-common.sh
```

Run directly:

```bash
./uninstall-linux.sh
```

Preview mode:

```bash
./uninstall-linux.sh --dry-run
```

Run a full cleanup with auto-confirm:

```bash
./uninstall-linux.sh --all --yes
```

Create a backup before removal:

```bash
./uninstall-linux.sh --all --backup --yes
```

### macOS

Grant execute permissions first:

```bash
chmod +x uninstall-macos.sh uninstall-unix-common.sh
```

Run directly:

```bash
./uninstall-macos.sh
```

Preview mode:

```bash
./uninstall-macos.sh --dry-run
```

Run a full cleanup with auto-confirm:

```bash
./uninstall-macos.sh --all --yes
```

Create a backup before removal:

```bash
./uninstall-macos.sh --all --backup --yes
```

## Flags

### Shared cleanup scopes

- `service`: services, scheduled tasks, LaunchAgents, systemd user services
- `state`: state directories, config directories, config files
- `workspace`: workspace directories
- `app`: application files
- `cli`: CLI binaries and related command leftovers

### Windows flags

```text
-All
-Service
-State
-Workspace
-App
-Cli
-Backup
-DryRun
-Yes
-Profiles current|all
-Mode auto|native|wsl
-Distro <WSL distro name>
```

Notes:

- `-Mode auto`: default mode, handles native Windows and detected WSL distros
- `-Mode native`: only handles native Windows
- `-Mode wsl`: only handles WSL
- `-Distro`: targets a specific WSL distro, such as `Ubuntu`
- `-Profiles current|all`: `current` currently falls back to `all` in the standalone script

### Linux / macOS flags

```text
--all
--service
--state
--workspace
--app
--cli
--backup
--dry-run
--yes
--profiles current|all
--help
```

Notes:

- If no scope flag is provided, a full cleanup runs by default
- `--profiles current|all`: `current` currently falls back to `all` in the standalone script

## Backup Behavior

- With `-Backup` or `--backup`, the script first tries `openclaw backup create --json`
- If the official backup command is unavailable or fails, it falls back to a local copy-based backup
- Windows native fallback backups go to `%USERPROFILE%\\ClawKiller-Backup\\windows-native-<timestamp>`
- Linux / macOS fallback backups go to `$HOME/ClawKiller-Backup/<platform>-<timestamp>`

## What Gets Removed

ClawKiller performs **best-effort** cleanup for OpenClaw-owned files and installation records, including:

- application directories
- CLI commands and npm global leftovers
- state directories and config files
- workspace directories
- service-related files
- selected package-manager records

The scripts detect the local environment and skip missing targets instead of failing the entire run.

## Package Manager Cleanup

### Windows

- winget
- Chocolatey
- Scoop
- npm

### Linux / macOS / WSL

- npm
- Homebrew
- apt
- dnf
- yum
- pacman
- zypper
- snap
- flatpak

### macOS extras

- `pkgutil` receipts
- `launchctl` / `LaunchAgents` leftovers

> Package-manager cleanup only runs when the corresponding command and installation record are detected.

## Notes

- This is a destructive operation. Use `-DryRun` or `--dry-run` first when possible.
- Use `-Backup` or `--backup` before removal if your data matters.
- Some system-level cleanup steps may require administrator or root privileges.
- The project mainly targets **OpenClaw-owned paths** and **exact-match package records**.
- Third-party wrappers, renamed directories, and non-standard install paths are not guaranteed to be fully covered.

## Support the Author

If this project is useful to you, you can support ongoing maintenance through either of these payment methods:

| WeChat Pay | Alipay |
| --- | --- |
| <img src="./.github/assets/donate-wechat.png" alt="WeChat Pay QR code" width="280" /> | <img src="./.github/assets/donate-alipay.jpg" alt="Alipay QR code" width="280" /> |

## License

This project is released under the MIT License. See [LICENSE](./LICENSE).
