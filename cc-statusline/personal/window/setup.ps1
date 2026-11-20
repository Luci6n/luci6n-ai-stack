# One-click installer: coralline statusline for Windows (Git Bash renderer).
# Uses the coralline.conf sitting next to this script (profile = this folder).
#
#   Double-click setup.cmd, or run:
#     powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1
#
# What it does:
#   1. makes sure Git for Windows (Git Bash) and jq are installed (via winget if missing),
#      plus JetBrainsMono Nerd Font (skip the font with: setup.cmd -NoFont)
#   2. installs upstream coralline, pinned to a release tag, through Git Bash
#      (the Bash renderer is required: the theme rotation in coralline.conf is shell
#      code, and the native PowerShell renderer does not execute it)
#   3. enables the subagent panel row
#   4. copies this folder's coralline.conf to ~\.claude\coralline.conf (existing one is backed up)
#
# Override the pinned release with:  $env:CORALLINE_REF = 'v0.21.0'

param([switch]$NoFont)   # skip the Nerd Font install:  setup.cmd -NoFont

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Ref       = if ($env:CORALLINE_REF) { $env:CORALLINE_REF } else { 'v0.20.1' }
$Here      = $PSScriptRoot
$ConfSrc   = Join-Path $Here 'coralline.conf'
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$Stamp     = Get-Date -Format 'yyyyMMddHHmmss'

function Write-Step([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Stop-Setup([string]$Message) { Write-Host ''; Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
function ConvertTo-GitBashPath([string]$Path) { return ($Path -replace '\\', '/') }

function Find-GitBash {
    $candidates = @()
    if ($env:ProgramFiles)         { $candidates += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') }
    if (${env:ProgramFiles(x86)})  { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe') }
    if ($env:LOCALAPPDATA)         { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe') }
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}

function Find-JqDir {
    $cmd = Get-Command jq -ErrorAction SilentlyContinue
    if ($cmd) { return (Split-Path -Parent $cmd.Source) }
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if (Test-Path (Join-Path $links 'jq.exe')) { return $links }
    return $null
}

function Install-WithWinget([string]$Id, [string]$Label) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Stop-Setup "$Label is missing and winget is not available. Install $Label manually, then run this again."
    }
    Write-Host "Installing $Label with winget (an admin prompt may appear)..."
    & winget install --id $Id -e --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Stop-Setup "winget could not install $Label (exit code $LASTEXITCODE). Install it manually, then run this again." }
}

if (-not (Test-Path $ConfSrc)) { Stop-Setup "coralline.conf not found next to this script ($Here)" }

# ---- 1. prerequisites ------------------------------------------------------
Write-Step 'Checking Git Bash and jq'
$bash = Find-GitBash
if (-not $bash) {
    Install-WithWinget 'Git.Git' 'Git for Windows'
    $bash = Find-GitBash
    if (-not $bash) { Stop-Setup 'Git for Windows was installed but bash.exe was not found. Close this window, open a new one, and run this again.' }
}
Write-Host "Git Bash: $bash"

$jqDir = Find-JqDir
if (-not $jqDir) {
    Install-WithWinget 'jqlang.jq' 'jq'
    $jqDir = Find-JqDir
    if (-not $jqDir) { Stop-Setup 'jq was installed but jq.exe was not found. Close this window, open a new one, and run this again.' }
}
Write-Host "jq: $jqDir"
# Make jq visible to Git Bash for this run (a fresh winget install is not on this session's PATH yet).
$env:PATH = "$jqDir;$env:PATH"

# Nerd Font (optional, non-fatal).
$fontNote = 'If icons look broken, set your terminal font to a Nerd Font.'
if ($NoFont) {
    Write-Host 'Skipping Nerd Font (-NoFont).'
}
elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'winget not available: skipping Nerd Font.'
}
else {
    & winget list --id DEVCOM.JetBrainsMonoNerdFont -e --source winget --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Nerd Font already installed (JetBrainsMono).'
        $fontNote = "Make sure your terminal font is set to 'JetBrainsMono Nerd Font'."
    }
    else {
        Write-Host 'Installing JetBrainsMono Nerd Font with winget...'
        & winget install --id DEVCOM.JetBrainsMonoNerdFont -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            $fontNote = "Installed JetBrainsMono Nerd Font. Now select it in your terminal's font settings (Windows Terminal: Settings > Profiles > Defaults > Appearance > Font face)."
        }
        else {
            Write-Warning 'Nerd Font install failed (non-fatal). Try: winget install DEVCOM.JetBrainsMonoNerdFont'
        }
    }
}

# ---- 2. upstream coralline -------------------------------------------------
Write-Step "Installing coralline $Ref (upstream)"
$installer = Join-Path $env:TEMP "coralline-install-$Stamp.sh"
try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/Nanako0129/coralline/$Ref/install.sh" -OutFile $installer
    & $bash (ConvertTo-GitBashPath $installer) --install-only --ref $Ref
    if ($LASTEXITCODE -ne 0) { Stop-Setup "The coralline installer failed (exit code $LASTEXITCODE)." }
}
finally {
    if (Test-Path $installer) { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

# ---- 3. subagent panel row -------------------------------------------------
Write-Step 'Enabling subagent status row'
$configure = (ConvertTo-GitBashPath $ClaudeDir) + '/coralline/configure.sh'
& $bash $configure --subagent-rows=on
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Could not enable the subagent row (non-fatal). Run in Git Bash: bash ~/.claude/coralline/configure.sh --subagent-rows=on'
}

# ---- 4. your config --------------------------------------------------------
Write-Step 'Installing your coralline.conf'
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
$dest = Join-Path $ClaudeDir 'coralline.conf'
# Strip CR bytes so the file stays LF even if git converted line endings (bash breaks on "24h\r").
$clean = [byte[]]([IO.File]::ReadAllBytes($ConfSrc) | Where-Object { $_ -ne 13 })
$same = $false
if (Test-Path $dest) {
    $existing = [IO.File]::ReadAllBytes($dest)
    $same = ([Convert]::ToBase64String($existing) -eq [Convert]::ToBase64String($clean))
}
if ($same) {
    Write-Host "Already up to date: $dest"
}
else {
    if (Test-Path $dest) {
        Copy-Item -LiteralPath $dest -Destination "$dest.bak.$Stamp"
        Write-Host "Backed up existing config to $dest.bak.$Stamp"
    }
    [IO.File]::WriteAllBytes($dest, $clean)
    Write-Host "Wrote $dest"
}

# ---- 5. per-launch theme rotation hook -------------------------------------
# coralline.conf looks its session up in theme-rotation.state; this SessionStart hook
# advances that rotation once per launch/resume (rotate-theme.sh).
Write-Step 'Installing theme-rotation hook'
$hookSrc = Join-Path $Here 'rotate-theme.sh'
if (-not (Test-Path $hookSrc)) {
    Write-Warning 'rotate-theme.sh not found next to this script: skipping the per-launch hook (themes will only change per new session).'
}
else {
    $hookDest = Join-Path $ClaudeDir 'coralline\rotate-theme.sh'
    [IO.File]::WriteAllBytes($hookDest, [byte[]]([IO.File]::ReadAllBytes($hookSrc) | Where-Object { $_ -ne 13 }))
    Write-Host "Wrote $hookDest"

    $settingsPath = Join-Path $ClaudeDir 'settings.json'
    $hookCmd = 'bash ~/.claude/coralline/rotate-theme.sh'
    $s = if (Test-Path $settingsPath) { Get-Content -Raw $settingsPath | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (-not $s.PSObject.Properties['hooks']) { $s | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    $existing = @(); if ($s.hooks.PSObject.Properties['SessionStart']) { $existing = @($s.hooks.SessionStart) }
    $already = $existing | Where-Object { $_.hooks | Where-Object { $_.command -eq $hookCmd } }
    if ($already) {
        Write-Host 'SessionStart hook already present in settings.json.'
    }
    else {
        if (Test-Path $settingsPath) { Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak.$Stamp" }
        $entry = [pscustomobject]@{ matcher = 'startup|resume'; hooks = @([pscustomobject]@{ type = 'command'; command = $hookCmd }) }
        $newList = @($existing) + $entry
        if ($s.hooks.PSObject.Properties['SessionStart']) { $s.hooks.SessionStart = $newList }
        else { $s.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $newList }
        [IO.File]::WriteAllText($settingsPath, ($s | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
        Write-Host "Added SessionStart hook to $settingsPath"
    }
}

# ---- done ------------------------------------------------------------------
Write-Step 'Done'
Write-Host 'Restart Claude Code to see the new statusline.'
Write-Host $fontNote
