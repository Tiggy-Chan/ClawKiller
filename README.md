<p align="center">
  <img src="./.github/assets/logo.png" alt="ClawKiller logo" width="220" />
</p>

<h1 align="center">ClawKiller</h1>

<p align="center">跨平台 OpenClaw 卸载脚本，支持 Windows / macOS / Linux / WSL。</p>

<p align="center">
  <a href="./README.md">简体中文</a> |
  <a href="./README.en.md">English</a>
</p>

## 简介

**ClawKiller** 是一组面向 **OpenClaw** 的跨平台卸载脚本，用于尽可能完整地清理：

- OpenClaw 应用文件
- CLI 命令行工具及相关残留
- 服务、计划任务、LaunchAgents、systemd user service 等残留
- 状态目录与配置文件
- 工作区数据
- 精确匹配的包管理器安装记录

适用于彻底卸载 OpenClaw、排查残留问题、以及重装前做一次干净清理。

## 特性

- 支持 **Windows 原生 / WSL / macOS / Linux**
- 支持按范围清理：`service` / `state` / `workspace` / `app` / `cli`
- 不传范围参数时，默认执行完整清理
- 支持 **dry-run**，先预览再执行
- 支持 **backup**，卸载前优先调用官方备份，失败后回退为本地复制备份
- 自动尝试清理常见包管理器中的 OpenClaw 安装记录
- 输出清晰的卸载报告，便于确认执行结果
- 支持读取自定义环境变量路径：
  - `OPENCLAW_STATE_DIR`
  - `OPENCLAW_CONFIG_PATH`
  - `OPENCLAW_HOME`

## 与 `openclaw uninstall` 的区别

`openclaw uninstall` 更适合常规卸载。根据 OpenClaw CLI 的帮助信息，它主要卸载 gateway service 和本地数据，但会保留 `openclaw` CLI 本身。

`ClawKiller` 更适合彻底清理和排查残留问题。它可以按范围清理 `service`、`state`、`workspace`、`app`、`cli`，并尝试移除包管理器中的安装记录。

- 想保留 `openclaw` 命令，只清理运行环境：优先用 `openclaw uninstall`，或使用 ClawKiller 的非 `cli` 范围
- 想连 CLI、本体、包管理器记录和跨平台残留一起清掉：使用 ClawKiller
- 想清理 WSL 或单独控制 Windows/macOS/Linux 上的范围：使用 ClawKiller

## 仓库结构

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

> `uninstall-linux.sh` 和 `uninstall-macos.sh` 依赖 `uninstall-unix-common.sh`，请保持它们位于同一目录。

## 快速开始

### Windows

直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

先预览将要执行的操作：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -DryRun
```

完整清理并自动确认：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -All -Yes
```

卸载前先备份：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -All -Backup -Yes
```

仅清理状态和工作区：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -State -Workspace -Yes
```

仅移除服务、状态和工作区，但保留 `openclaw` CLI：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -Service -State -Workspace -Yes
```

仅处理 WSL 中的 OpenClaw：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 -Mode wsl -Distro Ubuntu -All -Yes
```

### Linux

从 Git 克隆后通常可直接运行；如果你的环境没有保留脚本执行权限，再执行：

```bash
chmod +x uninstall-linux.sh uninstall-unix-common.sh
```

直接运行：

```bash
./uninstall-linux.sh
```

预览模式：

```bash
./uninstall-linux.sh --dry-run
```

完整清理并自动确认：

```bash
./uninstall-linux.sh --all --yes
```

卸载前备份：

```bash
./uninstall-linux.sh --all --backup --yes
```

仅移除服务、状态和工作区，但保留 `openclaw` CLI：

```bash
./uninstall-linux.sh --service --state --workspace --yes
```

### macOS

从 Git 克隆后通常可直接运行；如果你的环境没有保留脚本执行权限，再执行：

```bash
chmod +x uninstall-macos.sh uninstall-unix-common.sh
```

直接运行：

```bash
./uninstall-macos.sh
```

预览模式：

```bash
./uninstall-macos.sh --dry-run
```

完整清理并自动确认：

```bash
./uninstall-macos.sh --all --yes
```

卸载前备份：

```bash
./uninstall-macos.sh --all --backup --yes
```

仅移除服务、状态和工作区，但保留 `openclaw` CLI：

```bash
./uninstall-macos.sh --service --state --workspace --yes
```

## 参数说明

### 通用清理范围

- `service`：服务、计划任务、LaunchAgents、systemd user service 等
- `state`：状态目录、配置目录、配置文件
- `workspace`：工作区目录
- `app`：应用本体文件
- `cli`：CLI 可执行文件及相关命令残留

> 不传范围参数时默认执行完整清理，这会包含 `app` 和 `cli`，因此可能移除 `openclaw` 命令本身。

### Windows 参数

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
-Distro <WSL发行版名称>
```

说明：

- `-Mode auto`：默认模式，同时处理原生 Windows 和可检测到的 WSL
- `-Mode native`：只处理原生 Windows
- `-Mode wsl`：只处理 WSL
- `-Distro`：指定某个 WSL 发行版，例如 `Ubuntu`
- `-Profiles current|all`：当前 standalone 脚本中，`current` 会回退为 `all`

### Linux / macOS 参数

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

说明：

- 不带任何范围参数时，默认执行完整清理
- `--profiles current|all`：当前 standalone 脚本中，`current` 会回退为 `all`

## 备份行为

- 开启 `-Backup` 或 `--backup` 后，脚本会优先尝试调用 `openclaw backup create --json`
- 如果官方备份不可用或执行失败，会回退为本地复制备份
- Windows 原生回退备份默认写入 `%USERPROFILE%\\ClawKiller-Backup\\windows-native-<timestamp>`
- Linux / macOS 回退备份默认写入 `$HOME/ClawKiller-Backup/<platform>-<timestamp>`

## 会尝试清理什么

ClawKiller 会以 **best-effort** 的方式清理 OpenClaw 的自有文件与安装记录，例如：

- 应用目录
- CLI 命令与 npm 全局路径残留
- 状态目录与配置文件
- 工作区目录
- 服务相关文件
- 部分包管理器中的安装记录

脚本会自动检测环境并跳过不存在的项，不会因为某个组件未安装就中断整个流程。

## 包管理器清理

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

### macOS 额外处理

- `pkgutil` receipts
- `launchctl` / `LaunchAgents` 相关残留

> 所有包管理器相关操作都会先检测对应命令和安装记录，存在才执行，不存在则跳过。

## 注意事项

- 这是删除型操作，建议先使用 `-DryRun` 或 `--dry-run`
- 重要数据建议先使用 `-Backup` 或 `--backup`
- 某些系统级安装记录、服务或目录，可能需要管理员 / root 权限
- 本项目主要清理 **OpenClaw 自有文件** 与 **精确匹配的安装记录**
- 对于第三方脚本、手动改名目录、非标准安装路径，不保证 100% 覆盖

## 支持作者

如果这个项目帮到了你，可以通过下面两种方式支持作者继续维护：

| 微信支付 | 支付宝 |
| --- | --- |
| <img src="./.github/assets/donate-wechat.png" alt="微信支付收款码" width="280" /> | <img src="./.github/assets/donate-alipay.jpg" alt="支付宝收款码" width="280" /> |

## License

本项目基于 MIT License 发布，详见 [LICENSE](./LICENSE)。
