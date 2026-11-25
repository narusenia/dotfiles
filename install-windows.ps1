# Windows dev environment setup (PowerShell 7+ recommended)
#   .\install-windows.ps1            run everything
#   .\install-windows.ps1 tools ai   only the listed sections
#
# shortcut: written without a Windows machine to test on. Expect to fix
# details on first run; the structure mirrors install-osx.sh / install-linux.sh.

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Only)
$ErrorActionPreference = 'Stop'

$DotfilesRepo = 'https://github.com/NaruseNia/dotfiles.git'
$DotfilesDir  = Join-Path $HOME 'ghq\github.com\NaruseNia\dotfiles'

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
$esc = [char]27
function Paint($code, $text) { "$esc[38;5;${code}m$text$esc[0m" }
function Info($m) { Write-Host (Paint 244 "  · $m") }
function Ok($m)   { Write-Host (Paint 42  "  ✓ $m") }
function Warn($m) { Write-Host (Paint 214 "  ! $m") }
function Fail($m) { Write-Host (Paint 203 "  ✗ $m") }

function Banner {
  Write-Host ''
  @(
    '    ██████╗  ██████╗ ████████╗███████╗'
    '    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝'
    '    ██║  ██║██║   ██║   ██║   ███████╗'
    '    ██║  ██║██║   ██║   ██║   ╚════██║'
    '    ██████╔╝╚██████╔╝   ██║   ███████║'
    '    ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝'
  ) | ForEach-Object { Write-Host (Paint 212 $_) }
  $os = (Get-CimInstance Win32_OperatingSystem).Caption
  Write-Host "$esc[48;5;212m$esc[30m Windows setup $esc[0m " -NoNewline
  Write-Host (Paint 244 "$os · $env:USERNAME@$env:COMPUTERNAME · $(Get-Date -Format yyyy-MM-dd)")
  Write-Host ''
}

function Section($idx, $total, $title) {
  $bar = '━' * [Math]::Max(4, 44 - $title.Length)
  Write-Host ''
  Write-Host (Paint 99 "━━ [$idx/$total] ") -NoNewline
  Write-Host "$esc[1m$title $esc[0m" -NoNewline
  Write-Host (Paint 99 $bar)
}

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User')
  $shims = Join-Path $env:LOCALAPPDATA 'mise\shims'
  if (Test-Path $shims) { $env:Path = "$shims;$env:Path" }
}

function Winget-Install($id, $cmd) {
  if ($cmd -and (Have $cmd)) { Info "$id (already installed)"; return }
  winget install --id $id -e --accept-source-agreements --accept-package-agreements --silent | Out-Null
  if ($LASTEXITCODE -eq 0) { Ok "$id installed" } else { Fail "$id failed" }
  Refresh-Path
}

# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------
function Run-Base {
  Winget-Install 'Git.Git' 'git'
  Winget-Install 'jdx.mise' 'mise'
  Winget-Install 'Microsoft.PowerShell' 'pwsh'
}

function Run-Dotfiles {
  if (Test-Path (Join-Path $DotfilesDir '.git')) {
    Info "repo already at $DotfilesDir"
  } else {
    git clone $DotfilesRepo $DotfilesDir
    Ok "cloned to $DotfilesDir"
  }
  # mise reads [dotfiles] from its global config, which lives in the repo.
  # A symlink needs Developer Mode; otherwise fall back to a copy.
  $cfgDir = Join-Path $HOME '.config\mise'
  New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
  $cfg = Join-Path $cfgDir 'config.toml'
  $src = Join-Path $DotfilesDir 'home\.config\mise\config.toml'
  Remove-Item $cfg -Force -ErrorAction SilentlyContinue
  try   { New-Item -ItemType SymbolicLink -Path $cfg -Target $src | Out-Null; Ok 'mise config linked' }
  catch { Copy-Item $src $cfg; Warn 'Developer Mode off: mise config copied, not linked' }
  mise dot apply --force --yes
  if ($LASTEXITCODE -eq 0) { Ok 'dotfiles applied (copies unless Developer Mode is on)' } else { Fail 'mise dot apply failed' }
}

function Run-Tools {
  mise install --yes
  if ($LASTEXITCODE -eq 0) { Ok 'all mise tools installed' } else { Warn 'some tools failed — rerun: mise install' }
  Refresh-Path
}

function Run-Apps {
  Winget-Install 'wez.wezterm'           $null
  Winget-Install 'Vivaldi.Vivaldi'       $null
}

function Run-Ai {
  if (Have 'claude') { Info 'claude (already installed)' } else { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression; Ok 'claude installed' }
  Winget-Install 'Google.AntigravityCLI' 'agy'
  if (Have 'codex') { Info 'codex (already installed)' }
  else { mise x node -- npm install -g '@openai/codex'; if ($LASTEXITCODE -eq 0) { Ok 'codex installed' } else { Fail 'codex failed' } }
}

function Run-Identity {
  $key = Join-Path $HOME '.ssh\id_ed25519'
  if (Test-Path $key) { Info "SSH key already at $key" }
  else {
    $email = Read-Host 'Email for SSH key'
    New-Item -ItemType Directory -Force -Path (Split-Path $key) | Out-Null
    ssh-keygen -t ed25519 -C $email -f $key -N '""'
    Get-Content "$key.pub" | Set-Clipboard
    Ok 'SSH key generated (public key copied to clipboard)'
  }
  gh auth status 2>$null; if ($LASTEXITCODE -ne 0) { gh auth login -s admin:public_key }
  $pub = (Get-Content "$key.pub").Split(' ')[1]
  if (-not ((gh ssh-key list) -match [regex]::Escape($pub))) { gh ssh-key add "$key.pub" -t $env:COMPUTERNAME; Ok 'SSH key uploaded' }
  else { Info 'SSH key already on GitHub' }
  git -C $DotfilesDir remote set-url origin git@github.com:NaruseNia/dotfiles.git
  Ok 'dotfiles remote switched to SSH'
}

function Run-Nvim {
  $dir = Join-Path $env:LOCALAPPDATA 'nvim'
  if (Test-Path $dir) { Info "nvim config already at $dir" }
  else { git clone https://github.com/NaruseNia/nvim.git $dir; Ok 'nvim config cloned' }
  nvim --headless '+Lazy! sync' +qa
  Ok 'neovim plugins synced'
}

$Sections = [ordered]@{
  base     = @{ Title = 'Git · mise · PowerShell (winget)'; Fn = { Run-Base } }
  dotfiles = @{ Title = 'Dotfiles (mise dot)';              Fn = { Run-Dotfiles } }
  tools    = @{ Title = 'Runtimes & CLI tools (mise)';      Fn = { Run-Tools } }
  apps     = @{ Title = 'Apps (winget)';                    Fn = { Run-Apps } }
  ai       = @{ Title = 'AI tools: claude · codex · agy';   Fn = { Run-Ai } }
  identity = @{ Title = 'SSH key · gh auth';                Fn = { Run-Identity } }
  nvim     = @{ Title = 'Neovim config';                    Fn = { Run-Nvim } }
}

if (-not (Have 'winget')) { Write-Error 'winget not found. Install "App Installer" from the Microsoft Store first.' }

$toRun = if ($Only) { $Only } else { @($Sections.Keys) }
foreach ($s in $toRun) { if (-not $Sections.Contains($s)) { Write-Error "Unknown section: $s (valid: $($Sections.Keys -join ', '))" } }

Banner
$results = @()
$i = 0
foreach ($s in $toRun) {
  $i++
  Section $i $toRun.Count $Sections[$s].Title
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $status = '✓'
  try { & $Sections[$s].Fn } catch { Fail $_.Exception.Message; $status = '✗' }
  $results += [pscustomobject]@{ Status = $status; Section = $s; Time = "$([int]$sw.Elapsed.TotalSeconds)s" }
}

Write-Host ''
Write-Host (Paint 42 '  ╔═══════════════════╗')
Write-Host (Paint 42 '  ║    ✓  All done    ║')
Write-Host (Paint 42 '  ╚═══════════════════╝')
$results | Format-Table -AutoSize
Write-Host (Paint 214 "  dotfiles  $DotfilesDir")
Write-Host (Paint 214 '  Restart the terminal to pick up PATH changes.')
