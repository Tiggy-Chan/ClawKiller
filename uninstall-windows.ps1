# ClawKiller standalone uninstaller for OpenClaw
# Author: Tiggy Chan
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [switch]$All,
    [switch]$Service,
    [switch]$State,
    [switch]$Workspace,
    [switch]$App,
    [switch]$Cli,
    [switch]$Backup,
    [switch]$DryRun,
    [switch]$Yes,
    [ValidateSet("current", "all")]
    [string]$Profiles = "all",
    [ValidateSet("auto", "native", "wsl")]
    [string]$Mode = "auto",
    [string]$Distro
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$script:CommandRuntime = $PSCmdlet
$script:YesToAll = $false
$script:NoToAll = $false
$script:LogPrefix = "[clawkiller/windows]"
$script:ToolName = "ClawKiller"
$script:Author = "Tiggy Chan"
$script:WingetNames = @("OpenClaw", "openclaw")
$script:ChocolateyPackages = @("openclaw", "openclaw.install", "openclaw.portable")
$script:ScoopPackages = @("openclaw", "openclaw-cli", "openclaw-gateway")
$script:NpmPackages = @("openclaw")
$script:ReportActions = New-Object 'System.Collections.Generic.List[string]'
$script:ReportSkips = New-Object 'System.Collections.Generic.List[string]'
$script:ReportWarnings = New-Object 'System.Collections.Generic.List[string]'

function Write-Info {
    param([string]$Message)
    Write-Host "$($script:LogPrefix) $Message"
}

function Write-Banner {
    $banner = @(
        ""
        "=============================================="
        "   ______ _                 _  ___ _ _ _"
        "  / ____| |               | |/ (_) | | |"
        " | |    | | __ ___      __| ' / _| | | | ___ _ __"
        " | |    | |/ _` \ \ /\ / /|  < | | | | |/ _ \ '__|"
        " | |____| | (_| |\ V  V / | . \| | | | |  __/ |"
        "  \_____|_|\__,_| \_/\_/  |_|\_\_|_|_|_|\___|_|"
        ""
        "  $($script:ToolName) | OpenClaw Standalone Uninstaller"
        "  Author: $($script:Author)"
        "=============================================="
        ""
    )

    foreach ($line in $banner) {
        Write-Host $line
    }
}

function Add-ReportAction {
    param([string]$Message)

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:ReportActions.Add($Message) | Out-Null
    }
}

function Add-ReportSkip {
    param([string]$Message)

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:ReportSkips.Add($Message) | Out-Null
    }
}

function Add-ReportWarning {
    param([string]$Message)

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:ReportWarnings.Add($Message) | Out-Null
    }
}

function Write-WarnLine {
    param([string]$Message)

    Add-ReportWarning -Message $Message
    Write-Warning "$($script:LogPrefix) $Message"
}

function Write-SkipLine {
    param([string]$Message)

    Add-ReportSkip -Message $Message
    Write-Info $Message
}

function Get-RequestedScopeText {
    $requestedScopes = New-Object System.Collections.Generic.List[string]
    if ($Service) { $requestedScopes.Add("service") | Out-Null }
    if ($State) { $requestedScopes.Add("state") | Out-Null }
    if ($Workspace) { $requestedScopes.Add("workspace") | Out-Null }
    if ($App) { $requestedScopes.Add("app") | Out-Null }
    if ($Cli) { $requestedScopes.Add("cli") | Out-Null }

    if ($requestedScopes.Count -eq 0) {
        return "none"
    }

    return ($requestedScopes -join ", ")
}

function Write-ReportSection {
    param(
        [string]$Title,
        [System.Collections.Generic.List[string]]$Entries
    )

    if ($Entries.Count -eq 0) {
        return
    }

    Write-Info "$Title ($($Entries.Count)):"
    foreach ($entry in $Entries) {
        Write-Info "  - $entry"
    }
}

function Write-UninstallReport {
    $actionTitle = if ($DryRun) { "planned actions" } else { "actions" }
    $executionMode = if ($DryRun) { "dry-run" } else { "execute" }
    $scopeText = Get-RequestedScopeText

    Write-Info "uninstall report: mode=$Mode, execution=$executionMode, scopes=$scopeText, actions=$($script:ReportActions.Count), skipped=$($script:ReportSkips.Count), warnings=$($script:ReportWarnings.Count)"
    Write-ReportSection -Title $actionTitle -Entries $script:ReportActions
    Write-ReportSection -Title "skipped" -Entries $script:ReportSkips
    Write-ReportSection -Title "warnings" -Entries $script:ReportWarnings
}

function Get-UniqueStrings {
    param([string[]]$Values)

    $seen = @{}
    foreach ($value in $Values) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        $trimmed = $value.Trim()
        $key = $trimmed.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $trimmed
        }
    }
}

function Get-NormalizedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        $fullPath = $Path.Trim()
    }

    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if (-not [string]::IsNullOrWhiteSpace($root) -and $fullPath.Length -gt $root.Length) {
        return $fullPath.TrimEnd('\')
    }

    return $fullPath
}

function Get-OptimizedPaths {
    param([string[]]$Paths)

    $candidates = foreach ($path in $Paths) {
        $normalized = Get-NormalizedPath -Path $path
        if ($normalized) {
            [pscustomobject]@{
                Original = $path
                Normalized = $normalized
            }
        }
    }

    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in ($candidates | Sort-Object @{ Expression = { $_.Normalized.Length } }, @{ Expression = { $_.Normalized } })) {
        $skip = $false

        foreach ($existing in $selected) {
            if ($candidate.Normalized.Equals($existing.Normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
                $skip = $true
                break
            }

            if (
                $candidate.Normalized.Length -gt $existing.Normalized.Length -and
                $candidate.Normalized.StartsWith($existing.Normalized + "\", [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                $skip = $true
                break
            }
        }

        if (-not $skip) {
            $selected.Add($candidate) | Out-Null
        }
    }

    return @($selected | ForEach-Object { $_.Original })
}

function Confirm-UninstallIntent {
    if ($DryRun -or $Yes -or $WhatIfPreference) {
        return $true
    }
    $scopeText = Get-RequestedScopeText

    return $script:CommandRuntime.ShouldContinue(
        "Proceed with ClawKiller purge on mode '$Mode' for scopes: $scopeText ?",
        "Confirm ClawKiller uninstall",
        ([ref]$script:YesToAll),
        ([ref]$script:NoToAll)
    )
}

function Invoke-Step {
    param(
        [string]$Description,
        [scriptblock]$Script,
        [string]$Target = $Description,
        [string]$Action = "Execute"
    )

    if ($DryRun) {
        Write-Info "[dry-run] $Description"
        Add-ReportAction -Message $Description
        return $true
    }

    if (-not $script:CommandRuntime.ShouldProcess($Target, $Action)) {
        return $false
    }

    Write-Info $Description
    & $Script
    Add-ReportAction -Message $Description
    return $true
}

function Remove-Target {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        Write-SkipLine "skip missing: $Path"
        return
    }

    Invoke-Step "remove $Path" -Target $Path -Action "Remove path" {
        $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($isReparsePoint -or -not $item.PSIsContainer) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
        else {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
    } | Out-Null
}

function Remove-ScheduledTaskIfExists {
    param([string]$TaskName)

    $escapedTaskName = '"' + $TaskName.Replace('"', '\"') + '"'
    & cmd.exe /c "schtasks /Query /TN $escapedTaskName >nul 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-SkipLine "skip missing scheduled task $TaskName"
        return
    }

    Invoke-Step "delete scheduled task $TaskName" -Target $TaskName -Action "Delete scheduled task" {
        & cmd.exe /c "schtasks /Delete /TN $escapedTaskName /F >nul 2>&1"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete scheduled task $TaskName"
        }
    } | Out-Null
}

function Get-NpmCommand {
    Get-Command npm -ErrorAction SilentlyContinue
}

function Get-NpmGlobalPrefixes {
    $prefixes = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $prefixes.Add((Join-Path $env:APPDATA "npm")) | Out-Null
    }

    $npmCommand = Get-NpmCommand
    if ($npmCommand) {
        try {
            $npmPrefix = & $npmCommand.Source prefix -g 2>$null
            if ($LASTEXITCODE -eq 0) {
                foreach ($entry in @($npmPrefix)) {
                    if (-not [string]::IsNullOrWhiteSpace($entry)) {
                        $prefixes.Add($entry) | Out-Null
                    }
                }
            }
        }
        catch {
            Write-WarnLine "Unable to query npm global prefix. Falling back to the standard AppData path."
        }
    }

    return @(Get-UniqueStrings -Values $prefixes)
}

function Get-NativeCliTargets {
    param([string]$PrimaryCliPath)

    $targets = New-Object System.Collections.Generic.List[string]
    $sourcePaths = New-Object System.Collections.Generic.List[string]

    foreach ($command in @(Get-Command openclaw -All -ErrorAction SilentlyContinue)) {
        if ($command.Source) {
            $sourcePaths.Add($command.Source) | Out-Null
        }
    }

    if ($PrimaryCliPath) {
        $sourcePaths.Add($PrimaryCliPath) | Out-Null
    }

    foreach ($prefix in Get-NpmGlobalPrefixes) {
        foreach ($name in @(
            "openclaw",
            "openclaw.cmd",
            "openclaw.ps1",
            "openclaw.exe",
            "openclaw.bat",
            "node_modules\openclaw",
            "node_modules\.bin\openclaw",
            "node_modules\.bin\openclaw.cmd",
            "node_modules\.bin\openclaw.ps1"
        )) {
            $targets.Add((Join-Path $prefix $name)) | Out-Null
        }
    }

    foreach ($sourcePath in (Get-UniqueStrings -Values $sourcePaths)) {
        $targets.Add($sourcePath) | Out-Null

        $sourceDir = Split-Path -Parent $sourcePath
        if ([string]::IsNullOrWhiteSpace($sourceDir)) {
            continue
        }

        foreach ($name in @(
            "openclaw",
            "openclaw.cmd",
            "openclaw.ps1",
            "openclaw.exe",
            "openclaw.bat",
            "node_modules\openclaw",
            "node_modules\.bin\openclaw",
            "node_modules\.bin\openclaw.cmd",
            "node_modules\.bin\openclaw.ps1"
        )) {
            $targets.Add((Join-Path $sourceDir $name)) | Out-Null
        }
    }

    $optimizedTargets = Get-OptimizedPaths -Paths (Get-UniqueStrings -Values $targets)
    return @($optimizedTargets | Where-Object { Get-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue })
}

function Get-NativePaths {
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $appData = [Environment]::GetFolderPath("ApplicationData")
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    $command = Get-Command openclaw -ErrorAction SilentlyContinue
    $stateDir = if ($env:OPENCLAW_STATE_DIR) { $env:OPENCLAW_STATE_DIR } else { Join-Path $userProfile ".openclaw" }
    $configPath = if ($env:OPENCLAW_CONFIG_PATH) { $env:OPENCLAW_CONFIG_PATH } else { Join-Path $appData "OpenClaw\config.json" }
    $configRoot = Split-Path -Parent $configPath
    $workspaceRoot = if ($env:OPENCLAW_HOME) { $env:OPENCLAW_HOME } else { $stateDir }
    $workspaceDir = Join-Path $workspaceRoot "workspace"
    $appDir = Join-Path $localAppData "Programs\OpenClaw"
    $appPath = Join-Path $appDir "OpenClaw.exe"
    $gatewayScript = Join-Path $stateDir "gateway.cmd"
    $cliPath = if ($command) { $command.Source } else { $null }

    [pscustomobject]@{
        StateDir = $stateDir
        ConfigPath = $configPath
        ConfigRoot = $configRoot
        WorkspaceDir = $workspaceDir
        AppDir = $appDir
        AppPath = $appPath
        GatewayScript = $gatewayScript
        CliPath = $cliPath
        CliTargets = Get-NativeCliTargets -PrimaryCliPath $cliPath
    }
}

function Invoke-FallbackBackup {
    param([pscustomobject]$Paths)

    $backupRoot = Join-Path ([Environment]::GetFolderPath("UserProfile")) ("ClawKiller-Backup\windows-native-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Invoke-Step "create clawkiller fallback backup at $backupRoot" -Target $backupRoot -Action "Create backup" {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        if (Test-Path -LiteralPath $Paths.StateDir) { Copy-Item -LiteralPath $Paths.StateDir -Destination $backupRoot -Recurse -Force }
        if (Test-Path -LiteralPath $Paths.ConfigRoot) { Copy-Item -LiteralPath $Paths.ConfigRoot -Destination $backupRoot -Recurse -Force }
        elseif (Test-Path -LiteralPath $Paths.ConfigPath) { Copy-Item -LiteralPath $Paths.ConfigPath -Destination $backupRoot -Force }
        if (Test-Path -LiteralPath $Paths.WorkspaceDir) { Copy-Item -LiteralPath $Paths.WorkspaceDir -Destination $backupRoot -Recurse -Force }
    } | Out-Null
}

function Backup-Native {
    param([pscustomobject]$Paths)

    if ($DryRun) {
        Write-Info "[dry-run] backup OpenClaw data"
        Add-ReportAction -Message "backup OpenClaw data"
        return
    }

    if ($Paths.CliPath) {
        Write-Info "run official backup via OpenClaw CLI"
        & $Paths.CliPath backup create --json
        if ($LASTEXITCODE -ne 0) {
            Write-WarnLine "Official backup failed, switching to fallback copy."
            Invoke-FallbackBackup -Paths $Paths
        }
        else {
            Add-ReportAction -Message "run official OpenClaw backup via CLI"
        }
    }
    else {
        Invoke-FallbackBackup -Paths $Paths
    }
}

function Test-NpmPackageInstalled {
    param([string]$PackageName)

    $npmCommand = Get-NpmCommand
    if (-not $npmCommand) {
        return $false
    }

    & $npmCommand.Source ls -g --depth=0 $PackageName *> $null
    return $LASTEXITCODE -eq 0
}

function Remove-NpmPackageRecords {
    $npmCommand = Get-NpmCommand
    if (-not $npmCommand) {
        return
    }

    foreach ($packageName in $script:NpmPackages) {
        if (-not (Test-NpmPackageInstalled -PackageName $packageName)) {
            continue
        }

        Invoke-Step "remove npm global package record $packageName" -Target $packageName -Action "Remove npm package" {
            & $npmCommand.Source uninstall -g $packageName *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "npm uninstall failed for $packageName"
            }
        } | Out-Null
    }
}

function Test-ChocoPackageInstalled {
    param([string]$PackageName)

    $chocoCommand = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCommand) {
        return $false
    }

    $output = & $chocoCommand.Source list --local-only --exact $PackageName --limit-output 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return @($output | Where-Object { $_ -match "^(?i)$([regex]::Escape($PackageName))\|" }).Count -gt 0
}

function Remove-ChocoPackageRecords {
    $chocoCommand = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCommand) {
        return
    }

    foreach ($packageName in $script:ChocolateyPackages) {
        if (-not (Test-ChocoPackageInstalled -PackageName $packageName)) {
            continue
        }

        Invoke-Step "remove Chocolatey package record $packageName" -Target $packageName -Action "Remove Chocolatey package" {
            & $chocoCommand.Source uninstall $packageName -y --no-progress *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "Chocolatey uninstall failed for $packageName"
            }
        } | Out-Null
    }
}

function Test-WingetPackageInstalled {
    param([string]$PackageName)

    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        return $false
    }

    $output = & $wingetCommand.Source list --name $PackageName --exact --source winget --disable-interactivity 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return (@($output) -join "`n") -match [regex]::Escape($PackageName)
}

function Remove-WingetPackageRecords {
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        return
    }

    foreach ($packageName in $script:WingetNames) {
        if (-not (Test-WingetPackageInstalled -PackageName $packageName)) {
            continue
        }

        Invoke-Step "remove winget package record $packageName" -Target $packageName -Action "Remove winget package" {
            & $wingetCommand.Source uninstall --name $packageName --exact --source winget --silent --disable-interactivity *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "winget uninstall failed for $packageName"
            }
        } | Out-Null
    }
}

function Test-ScoopPackageInstalled {
    param(
        [string]$PackageName,
        [switch]$Global
    )

    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoopCommand) {
        return $false
    }

    $args = @("list")
    if ($Global) {
        $args += "--global"
    }

    $output = & $scoopCommand.Source @args 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return @($output | Where-Object { $_ -match "^(?i)$([regex]::Escape($PackageName))\s" }).Count -gt 0
}

function Remove-ScoopPackageRecords {
    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoopCommand) {
        return
    }

    foreach ($packageName in $script:ScoopPackages) {
        if (Test-ScoopPackageInstalled -PackageName $packageName) {
            Invoke-Step "remove Scoop package record $packageName" -Target $packageName -Action "Remove Scoop package" {
                & $scoopCommand.Source uninstall $packageName *> $null
                if ($LASTEXITCODE -ne 0) {
                    throw "Scoop uninstall failed for $packageName"
                }
            } | Out-Null
        }

        if (Test-ScoopPackageInstalled -PackageName $packageName -Global) {
            Invoke-Step "remove Scoop global package record $packageName" -Target $packageName -Action "Remove Scoop global package" {
                & $scoopCommand.Source uninstall --global $packageName *> $null
                if ($LASTEXITCODE -ne 0) {
                    throw "Scoop uninstall --global failed for $packageName"
                }
            } | Out-Null
        }
    }
}

function Remove-WindowsPackageManagerRecords {
    if (-not ($App -or $Cli -or $Service)) {
        return
    }

    Remove-WingetPackageRecords
    Remove-ChocoPackageRecords
    Remove-ScoopPackageRecords
    Remove-NpmPackageRecords
}

function Remove-Native {
    param([pscustomobject]$Paths)

    Remove-WindowsPackageManagerRecords

    if ($Service) {
        foreach ($taskName in @("OpenClaw Gateway", "OpenClaw Gateway (User)")) {
            Remove-ScheduledTaskIfExists -TaskName $taskName
        }
        Remove-Target -Path $Paths.GatewayScript
    }

    $nativeTargets = New-Object System.Collections.Generic.List[string]
    if ($State) {
        $nativeTargets.Add($Paths.StateDir) | Out-Null
        $nativeTargets.Add($Paths.ConfigRoot) | Out-Null
        $nativeTargets.Add($Paths.ConfigPath) | Out-Null
    }
    if ($Workspace) {
        $nativeTargets.Add($Paths.WorkspaceDir) | Out-Null
    }
    if ($App) {
        $nativeTargets.Add($Paths.AppDir) | Out-Null
        $nativeTargets.Add($Paths.AppPath) | Out-Null
    }

    foreach ($target in (Get-OptimizedPaths -Paths $nativeTargets)) {
        Remove-Target -Path $target
    }

    if ($Cli) {
        foreach ($target in $Paths.CliTargets) {
            Remove-Target -Path $target
        }
    }
}

function Normalize-WslDistroName {
    param([string]$Name)

    if ($null -eq $Name) {
        return $null
    }

    $clean = -join ($Name.ToCharArray() | Where-Object { -not [char]::IsControl($_) })
    $clean = $clean.Trim()

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return $null
    }

    return $clean
}

function Get-WslDistros {
    $list = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $list) {
        return @()
    }

    $distros = foreach ($entry in @($list)) {
        $normalized = Normalize-WslDistroName -Name $entry
        if ($normalized) {
            $normalized
        }
    }

    return @(Get-UniqueStrings -Values $distros)
}

function Test-WslDistroReachable {
    param([string]$TargetDistro)

    $normalized = Normalize-WslDistroName -Name $TargetDistro
    if (-not $normalized) {
        return $false
    }

    if ($DryRun) {
        return $true
    }

    & wsl.exe --distribution $normalized --exec /bin/true *> $null
    return $LASTEXITCODE -eq 0
}

function Test-WslHasOpenClawSignals {
    param([string]$TargetDistro)

    if ($DryRun) {
        return $true
    }

    $probe = @'
if command -v openclaw >/dev/null 2>&1; then
  exit 0
fi
if [ -d "${OPENCLAW_STATE_DIR:-$HOME/.openclaw}" ]; then
  exit 0
fi
if [ -f "${OPENCLAW_CONFIG_PATH:-$HOME/.config/openclaw/config.json}" ]; then
  exit 0
fi
if [ -d "${OPENCLAW_HOME:-$HOME/.openclaw}/workspace" ]; then
  exit 0
fi
if ls "$HOME"/.config/systemd/user/openclaw-gateway*.service >/dev/null 2>&1; then
  exit 0
fi
exit 1
'@

    & wsl.exe --distribution $TargetDistro --exec sh -lc $probe *> $null
    return $LASTEXITCODE -eq 0
}

function Get-WslPackageManagerCleanupCommand {
    return @'
run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo "$@"
    return $?
  fi
  return 1
}

for pkg in openclaw; do
  if command -v npm >/dev/null 2>&1 && npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
    npm uninstall -g "$pkg" >/dev/null 2>&1 || true
  fi
done

for pkg in openclaw; do
  if command -v brew >/dev/null 2>&1 && brew list --formula "$pkg" >/dev/null 2>&1; then
    brew uninstall --formula "$pkg" >/dev/null 2>&1 || true
  fi
done

for pkg in openclaw openclaw-cli openclaw-gateway; do
  if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1 && dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then
    run_root env DEBIAN_FRONTEND=noninteractive apt-get -y purge "$pkg" >/dev/null 2>&1 || true
  fi
  if command -v rpm >/dev/null 2>&1 && command -v dnf >/dev/null 2>&1 && rpm -q "$pkg" >/dev/null 2>&1; then
    run_root dnf -y remove "$pkg" >/dev/null 2>&1 || true
  fi
  if command -v rpm >/dev/null 2>&1 && command -v yum >/dev/null 2>&1 && rpm -q "$pkg" >/dev/null 2>&1; then
    run_root yum -y remove "$pkg" >/dev/null 2>&1 || true
  fi
  if command -v pacman >/dev/null 2>&1 && pacman -Q "$pkg" >/dev/null 2>&1; then
    run_root pacman -Rn --noconfirm "$pkg" >/dev/null 2>&1 || true
  fi
  if command -v rpm >/dev/null 2>&1 && command -v zypper >/dev/null 2>&1 && rpm -q "$pkg" >/dev/null 2>&1; then
    run_root zypper --non-interactive rm "$pkg" >/dev/null 2>&1 || true
  fi
  if command -v snap >/dev/null 2>&1 && snap list "$pkg" >/dev/null 2>&1; then
    run_root snap remove --purge "$pkg" >/dev/null 2>&1 || true
  fi
done

for app_id in ai.openclaw.OpenClaw com.openclaw.OpenClaw bot.molt.OpenClaw openclaw; do
  if command -v flatpak >/dev/null 2>&1; then
    if flatpak info --user --app "$app_id" >/dev/null 2>&1; then
      flatpak uninstall --user --noninteractive -y --delete-data --app "$app_id" >/dev/null 2>&1 || true
    fi
    if flatpak info --system --app "$app_id" >/dev/null 2>&1; then
      run_root flatpak uninstall --system --noninteractive -y --delete-data --app "$app_id" >/dev/null 2>&1 || true
    fi
  fi
done
'@
}

function Get-WslServiceCleanupCommand {
    return @'
if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user cat openclaw-gateway.service >/dev/null 2>&1; then
    systemctl --user stop openclaw-gateway.service >/dev/null 2>&1 || true
    systemctl --user disable openclaw-gateway.service >/dev/null 2>&1 || true
  fi
fi
rm -f "$HOME"/.config/systemd/user/openclaw-gateway*.service
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi
'@
}

function Invoke-WslCommand {
    param(
        [string]$TargetDistro,
        [string]$CommandText,
        [string]$Description,
        [switch]$AllowFailure
    )

    $normalized = Normalize-WslDistroName -Name $TargetDistro
    if (-not $normalized) {
        Write-SkipLine "skip invalid WSL distro entry"
        return
    }

    if ($DryRun) {
        Write-Info "[dry-run] wsl.exe --distribution $normalized --exec sh -lc ""$CommandText"""
        Add-ReportAction -Message $Description
        return
    }

    $output = & wsl.exe --distribution $normalized --exec sh -lc $CommandText 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in @($output)) {
        if (-not [string]::IsNullOrWhiteSpace("$line")) {
            Write-Info "$line"
        }
    }

    if ($exitCode -eq 0 -or $AllowFailure) {
        Add-ReportAction -Message $Description
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        Write-WarnLine "WSL command failed for distro $normalized with exit code $exitCode"
    }
}

function Handle-Wsl {
    param([string[]]$TargetDistros)

    foreach ($target in $TargetDistros) {
        $normalizedTarget = Normalize-WslDistroName -Name $target
        if (-not $normalizedTarget) {
            Write-SkipLine "skip invalid WSL distro entry"
            continue
        }
        if (-not (Test-WslDistroReachable -TargetDistro $normalizedTarget)) {
            Write-SkipLine "skip unavailable WSL distro $normalizedTarget"
            continue
        }
        if (-not (Test-WslHasOpenClawSignals -TargetDistro $normalizedTarget)) {
            Write-SkipLine "skip WSL distro without OpenClaw signals $normalizedTarget"
            continue
        }

        Write-Info "profile mode for WSL: $Profiles ($normalizedTarget)"

        if ($Backup) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText 'if command -v openclaw >/dev/null 2>&1; then openclaw backup create --json; fi' -Description "run WSL backup in distro $normalizedTarget" -AllowFailure
        }

        if ($App -or $Cli -or $Service) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText (Get-WslPackageManagerCleanupCommand) -Description "remove WSL package-manager records in distro $normalizedTarget" -AllowFailure
        }

        if ($Service) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText (Get-WslServiceCleanupCommand) -Description "remove WSL service artifacts in distro $normalizedTarget" -AllowFailure
        }
        if ($State) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText 'rm -rf "${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"' -Description "remove WSL state directory in distro $normalizedTarget" -AllowFailure
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText 'config_root="$(dirname "${OPENCLAW_CONFIG_PATH:-$HOME/.config/openclaw/config.json}")"; rm -rf "$config_root"' -Description "remove WSL config directory in distro $normalizedTarget" -AllowFailure
        }
        if ($Workspace) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText 'rm -rf "${OPENCLAW_HOME:-$HOME/.openclaw}/workspace"' -Description "remove WSL workspace in distro $normalizedTarget" -AllowFailure
        }
        if ($Cli) {
            Invoke-WslCommand -TargetDistro $normalizedTarget -CommandText 'cli_path="$(command -v openclaw 2>/dev/null || true)"; if [ -n "$cli_path" ]; then cli_dir="$(dirname "$cli_path")"; cli_prefix="$(dirname "$cli_dir")"; rm -f "$cli_path" "$cli_dir/openclaw" "$cli_dir/openclaw.cmd" "$cli_dir/openclaw.ps1" "$cli_dir/openclaw.bat" "$cli_dir/openclaw.exe"; rm -rf "$cli_prefix/lib/node_modules/openclaw" "$cli_dir/node_modules/openclaw" "$cli_dir/node_modules/.bin/openclaw" "$cli_dir/node_modules/.bin/openclaw.cmd" "$cli_dir/node_modules/.bin/openclaw.ps1"; fi' -Description "remove WSL CLI artifacts in distro $normalizedTarget" -AllowFailure
        }
    }
}

function Invoke-ClawKiller {
    Write-Banner

    if (-not ($All -or $Service -or $State -or $Workspace -or $App -or $Cli)) {
        $script:All = $true
    }

    if ($All) {
        $script:Service = $true
        $script:State = $true
        $script:Workspace = $true
        $script:App = $true
        $script:Cli = $true
    }

    if ($Profiles -eq "current") {
        Write-WarnLine "Profiles=current is not implemented by this standalone script. Falling back to all."
        $script:Profiles = "all"
    }

    Write-Info "profile mode: $Profiles"

    if (-not (Confirm-UninstallIntent)) {
        Write-SkipLine "operation cancelled by user"
        Write-Info "cancelled."
        return
    }

    if ($Mode -in @("auto", "native")) {
        $nativePaths = Get-NativePaths
        if ($Backup) {
            Backup-Native -Paths $nativePaths
        }
        Remove-Native -Paths $nativePaths
    }

    if ($Mode -in @("auto", "wsl")) {
        $targetDistros = if ($Distro) {
            @((Normalize-WslDistroName -Name $Distro))
        }
        else {
            Get-WslDistros
        }
        $targetDistros = @(Get-UniqueStrings -Values ($targetDistros | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }))
        if ($targetDistros.Count -gt 0) {
            Handle-Wsl -TargetDistros $targetDistros
        }
        else {
            Write-SkipLine "skip WSL cleanup: no valid distro targets were detected"
        }
    }

    Write-Info "completed."
}

try {
    Invoke-ClawKiller
}
finally {
    Write-UninstallReport
}
