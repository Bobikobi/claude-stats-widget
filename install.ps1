<#
.SYNOPSIS
    Install (or remove) the Claude Stats Widget for the current user on Windows.
.DESCRIPTION
    Copies the widget into %LOCALAPPDATA%\Programs, draws the Clawd icon, and
    adds a Start Menu entry. Nothing is written outside the user profile and
    nothing needs administrator rights.
.PARAMETER Uninstall
    Remove everything this script installed. Settings are left alone.
.PARAMETER NoAutostart
    Skip the "start at login" prompt and do not install the Startup shortcut.
.PARAMETER NoDesktopShortcut
    Do not put a shortcut on the desktop.
.PARAMETER NoLaunch
    Install without starting the widget afterwards.
.PARAMETER Ref
    Branch or tag to fetch the widget from when running without a checkout.
.EXAMPLE
    irm https://raw.githubusercontent.com/Bobikobi/claude-stats-widget/main/install.ps1 | iex

    Installs without cloning anything. To pass switches this way, run the
    script as a scriptblock instead:

    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Bobikobi/claude-stats-widget/main/install.ps1))) -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$NoAutostart,
    [switch]$NoDesktopShortcut,
    [switch]$NoLaunch,
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 still negotiates TLS 1.0 by default, which GitHub
# refuses; without this the one-line install fails on a stock Windows 10.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$Name      = 'claude-stats-widget'
$InstallTo = Join-Path $env:LOCALAPPDATA "Programs\$Name"
$Target    = Join-Path $InstallTo "$Name.pyw"
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Stats Widget.lnk'
$Startup   = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Claude Stats Widget.lnk'
$IconPath  = Join-Path $env:LOCALAPPDATA "$Name\claude-clawd.ico"
# Ask Windows where the desktop is rather than assuming ~\Desktop: it moves
# when OneDrive backs up the folder, and it is localised.
$Desktop   = [Environment]::GetFolderPath('Desktop')
$DesktopLnk = if ($Desktop) { Join-Path $Desktop 'Claude Stats Widget.lnk' } else { $null }

if ($Uninstall) {
    Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
        Where-Object { $_.CommandLine -like "*$Name*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    foreach ($p in @($StartMenu, $Startup, $DesktopLnk, $InstallTo)) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            Remove-Item -LiteralPath $p -Recurse -Force
        }
    }
    Write-Host "Removed. Your settings in $env:APPDATA\$Name\config.json were left alone."
    return
}

# --- find a Python with Tk -------------------------------------------------
$pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonw) {
    $py = (Get-Command py.exe -ErrorAction SilentlyContinue).Source
    if ($py) { $pythonw = & $py -3 -c "import sys, os; print(os.path.join(os.path.dirname(sys.executable), 'pythonw.exe'))" }
}
if (-not $pythonw -or -not (Test-Path $pythonw)) {
    throw "Python 3 was not found on PATH. Install it from python.org or the Microsoft Store, then run this again."
}
$python = Join-Path (Split-Path $pythonw) 'python.exe'

& $python -c "import tkinter" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "This Python has no tkinter. Re-run the python.org installer and tick 'tcl/tk and IDLE'."
}

# --- find the widget itself ------------------------------------------------
# Next to this script when the repo was cloned; downloaded when the script is
# being piped straight into PowerShell, where there is no script root and no
# sibling file. Nothing else is needed: no git, no editor, no build step.
$source = if ($PSScriptRoot) { Join-Path $PSScriptRoot $Name } else { $null }
$temp = $null
if (-not $source -or -not (Test-Path $source)) {
    $url = "https://raw.githubusercontent.com/Bobikobi/$Name/$Ref/$Name"
    Write-Host "Fetching the widget from $Ref ..."
    $temp = Join-Path ([IO.Path]::GetTempPath()) "$Name-$([guid]::NewGuid()).py"
    Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
    $source = $temp
}

# --- install ---------------------------------------------------------------
New-Item -ItemType Directory -Force $InstallTo | Out-Null
Copy-Item $source $Target -Force
if ($temp) { Remove-Item $temp -Force -ErrorAction SilentlyContinue }

# draw the Clawd icon once, so the shortcut and the toasts have it
& $python $Target --write-icon 2>$null | Out-Null

$shell = New-Object -ComObject WScript.Shell

# WScript.Shell saves a shortcut through an ANSI path, so it simply fails on a
# localised folder - a Hebrew or Cyrillic desktop, or a OneDrive-redirected
# one, which is where the desktop lives on a lot of machines. Build the .lnk
# somewhere plain and let .NET move it, which is Unicode-clean.
$AsciiPattern = '^[\x20-\x7E]+$'
$AsciiTemp = $null
foreach ($candidate in @([IO.Path]::GetTempPath(), "$env:PUBLIC\Downloads", "$env:SystemDrive\")) {
    if (-not $candidate -or $candidate -notmatch $AsciiPattern) { continue }
    try {
        $probe = Join-Path $candidate ("csw-" + [guid]::NewGuid().ToString('N') + ".tmp")
        [IO.File]::WriteAllText($probe, 'x')
        Remove-Item -LiteralPath $probe -Force
        $AsciiTemp = $candidate
        break
    } catch {}
}

function New-WidgetShortcut([string]$Path) {
    $staged = $null
    if ($Path -notmatch $AsciiPattern -and $AsciiTemp) {
        $staged = Join-Path $AsciiTemp ("csw-" + [guid]::NewGuid().ToString('N') + ".lnk")
    }
    $lnk = $shell.CreateShortcut($(if ($staged) { $staged } else { $Path }))
    $lnk.TargetPath       = $pythonw
    $lnk.Arguments        = "`"$Target`""
    $lnk.WorkingDirectory = $InstallTo
    $lnk.Description      = 'Claude Code usage at a glance'
    if (Test-Path -LiteralPath $IconPath) { $lnk.IconLocation = $IconPath }
    $lnk.Save()
    if ($staged) {
        $parent = Split-Path -LiteralPath $Path
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Force $parent | Out-Null
        }
        Move-Item -LiteralPath $staged -Destination $Path -Force
    }
}

New-WidgetShortcut $StartMenu

if (-not $NoDesktopShortcut) {
    if ($DesktopLnk) {
        New-WidgetShortcut $DesktopLnk
        Write-Host "Desktop shortcut created."
    } else {
        Write-Warning 'Could not find your desktop folder; skipped that shortcut.'
    }
}

if (-not $NoAutostart) {
    # Piped into PowerShell there may be no console to answer with, and a
    # prompt that cannot be answered would hang the one-line install.
    $reply = 'n'
    try { $reply = Read-Host 'Start the widget automatically at login? [Y/n]' } catch {}
    if ($reply -notmatch '^[Nn]') {
        New-WidgetShortcut $Startup
        Write-Host 'Autostart enabled.'
    }
}

Write-Host "Installed to $Target"

if (-not $NoLaunch) {
    Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
        Where-Object { $_.CommandLine -like "*$Name*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Process -FilePath $pythonw -ArgumentList "`"$Target`"" -WorkingDirectory $InstallTo
    Write-Host 'Started. Look for it near the top right of your screen.'
} else {
    Write-Host "Launch it from the Start Menu, the desktop, or run: `"$pythonw`" `"$Target`""
}
