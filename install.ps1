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
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$NoAutostart
)

$ErrorActionPreference = 'Stop'

$Name      = 'claude-stats-widget'
$InstallTo = Join-Path $env:LOCALAPPDATA "Programs\$Name"
$Target    = Join-Path $InstallTo "$Name.pyw"
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Stats Widget.lnk'
$Startup   = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Claude Stats Widget.lnk'
$IconPath  = Join-Path $env:LOCALAPPDATA "$Name\claude-clawd.ico"

if ($Uninstall) {
    Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
        Where-Object { $_.CommandLine -like "*$Name*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    foreach ($p in @($StartMenu, $Startup, $InstallTo)) {
        if (Test-Path $p) { Remove-Item -Recurse -Force $p }
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

# --- install ---------------------------------------------------------------
$source = Join-Path $PSScriptRoot $Name
if (-not (Test-Path $source)) { throw "Cannot find $Name next to this script." }

New-Item -ItemType Directory -Force $InstallTo | Out-Null
Copy-Item $source $Target -Force

# draw the Clawd icon once, so the shortcut and the toasts have it
& $python $Target --write-icon 2>$null | Out-Null

$shell = New-Object -ComObject WScript.Shell
function New-WidgetShortcut([string]$Path) {
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath       = $pythonw
    $lnk.Arguments        = "`"$Target`""
    $lnk.WorkingDirectory = $InstallTo
    $lnk.Description      = 'Claude Code usage at a glance'
    if (Test-Path $IconPath) { $lnk.IconLocation = $IconPath }
    $lnk.Save()
}

New-WidgetShortcut $StartMenu

if (-not $NoAutostart) {
    $reply = Read-Host 'Start the widget automatically at login? [Y/n]'
    if ($reply -notmatch '^[Nn]') {
        New-WidgetShortcut $Startup
        Write-Host 'Autostart enabled.'
    }
}

Write-Host "Installed to $Target"
Write-Host "Launch it from the Start Menu, or run: `"$pythonw`" `"$Target`""
