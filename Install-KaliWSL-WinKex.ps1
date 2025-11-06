<#
  Install-KaliWSL-WinKex.ps1
  Author: ChatGPT (for Abel)
  Purpose: Automatically install WSL, Kali Linux, and GUI support (Win-KeX with VNC)
  Notes:
    - Must be run as Administrator.
    - Reboot might be needed after enabling WSL/VM Platform.
    - Handles most common errors gracefully.
#>

# === Function: Error handling utility ===
function Throw-IfError($Message) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ ERROR: $Message" -ForegroundColor Red
        exit 1
    }
}

# === Check for Administrator privileges ===
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️ Please run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "=============================================="
Write-Host " Installing Kali Linux (WSL + GUI + VNC)"
Write-Host "==============================================`n" -ForegroundColor Cyan

# === Step 1: Enable required features ===
try {
    Write-Host "[1/6] Enabling WSL and Virtual Machine Platform..." -ForegroundColor Cyan
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    Write-Host "✅ WSL and Virtual Machine Platform enabled." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to enable WSL/VM Platform. Error: $_" -ForegroundColor Red
    exit 1
}

# === Step 2: Set WSL version 2 ===
Write-Host "[2/6] Setting WSL default version to 2..." -ForegroundColor Cyan
wsl --set-default-version 2
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Could not set WSL default to version 2. You might need Windows 10 build 1903+ or Windows 11." -ForegroundColor Yellow
} else {
    Write-Host "✅ WSL default version set to 2." -ForegroundColor Green
}

# === Step 3: Install Kali Linux ===
$KaliInstalled = wsl -l -v 2>$null | Select-String -Pattern "kali" -SimpleMatch
if ($KaliInstalled) {
    Write-Host "ℹ️ Kali Linux is already installed." -ForegroundColor Yellow
} else {
    Write-Host "[3/6] Installing Kali Linux..." -ForegroundColor Cyan
    try {
        wsl --install -d kali-linux
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️ The command failed. You may need to install Kali manually from Microsoft Store." -ForegroundColor Yellow
        } else {
            Write-Host "✅ Kali installation initiated. Please wait for setup to finish." -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Unable to start Kali installation. Error: $_" -ForegroundColor Red
        exit 1
    }
}

# === Step 4: Install Win-KeX (GUI) and VNC inside Kali ===
Write-Host "`n[4/6] Updating Kali and installing GUI tools..." -ForegroundColor Cyan

$KaliCmds = @'
set -e
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y kali-win-kex tigervnc-standalone-server tigervnc-common pulseaudio
sudo apt autoremove -y
'@

try {
    wsl -d kali-linux -- bash -c "$KaliCmds"
    Throw-IfError "Failed to install GUI tools inside Kali."
    Write-Host "✅ GUI (Win-KeX + VNC) installed successfully inside Kali." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to run package installation inside Kali. Error: $_" -ForegroundColor Red
    Write-Host "Tip: Try running 'sudo apt update && sudo apt install -y kali-win-kex' manually inside Kali." -ForegroundColor Yellow
}

# === Step 5: Create Desktop Shortcut ===
Write-Host "`n[5/6] Creating Desktop shortcut for Kali GUI..." -ForegroundColor Cyan
try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $lnkPath = Join-Path $desktop "Launch Kali WinKex.lnk"
    $target = (Get-Command wsl).Source
    $arguments = "-d kali-linux kex --win -s"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$env:SystemRoot\System32\wsl.exe"
    $shortcut.Description = "Launch Kali GUI (Win-KeX Window Mode)"
    $shortcut.Save()

    Write-Host "✅ Shortcut created: '$lnkPath'" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not create Desktop shortcut. Error: $_" -ForegroundColor Yellow
}

# === Step 6: Final instructions ===
Write-Host "`n[6/6] Setup Complete!" -ForegroundColor Green
Write-Host "----------------------------------------------"
Write-Host "📌 To launch Kali GUI (Win-KeX):" -ForegroundColor Cyan
Write-Host "   • Use Desktop shortcut  ➜  'Launch Kali WinKex.lnk'"
Write-Host "   • OR run in PowerShell: wsl -d kali-linux kex --win -s"
Write-Host ""
Write-Host "💡 To start VNC manually inside Kali:"
Write-Host "   • Run: tigervncserver -localhost no"
Write-Host "   • Then connect with VNC Viewer (127.0.0.1:5901)"
Write-Host ""
Write-Host "If you just enabled WSL for the first time, please REBOOT your system now." -ForegroundColor Yellow
Write-Host "----------------------------------------------"
