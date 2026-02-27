<#
.SYNOPSIS
    IDM-Reset Tool - Automatic Setup Installer
    Downloads and configures everything needed to run the tool

.DESCRIPTION
    This script automates the entire setup process:
    1. Downloads the project from GitHub
    2. Sets up Python virtual environment
    3. Installs required dependencies
    4. Creates a global 'idm-reset-tool' command
    5. Creates a desktop shortcut

.EXAMPLE
    irm https://raw.githubusercontent.com/AliHamza-Coder/idm-reset-tool/main/setup.ps1 | iex
#>

# Stop on any error
$ErrorActionPreference = "Stop"

# Colors for output
$colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Success", "Error", "Warning", "Info")]
        [string]$Type = "Info"
    )
    $color = $colors[$Type]
    Write-Host $Message -ForegroundColor $color
}

# Banner
Clear-Host
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       IDM-Reset Tool - Automatic Setup Installer        ║" -ForegroundColor Cyan
Write-Host "║                    v3.2.0                                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Status "⚠️  This script should run as Administrator for best results" "Warning"
    Write-Host "Some features (like creating program shortcuts) may not work." -ForegroundColor Yellow
    Write-Host ""
    $continueNonAdmin = Read-Host "Continue anyway? (y/n)"
    if ($continueNonAdmin -ne 'y') {
        Write-Status "❌ Setup cancelled" "Error"
        exit 1
    }
    Write-Host ""
}

# Step 1: Check Python
Write-Status "📋 Checking Python installation..." "Info"
$pythonVersion = python --version 2>&1
if (-not $?) {
    Write-Status "❌ Python not found! Please install Python 3.6+ from https://www.python.org" "Error"
    Write-Host "Make sure to check 'Add Python to PATH' during installation."
    exit 1
}
Write-Status "✅ Python found: $pythonVersion" "Success"
Write-Host ""

# Step 2: Determine installation location
Write-Status "📁 Determining installation location..." "Info"
$installPath = "$env:LOCALAPPDATA\idm-reset-tool"
$projectPath = "$installPath\idm-reset-tool"

# Create installation directory
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    Write-Status "✅ Created installation directory: $installPath" "Success"
}
Write-Host ""

# Step 3: Clone or update repository
Write-Status "📥 Downloading idm-reset-tool from GitHub..." "Info"
if (Test-Path "$projectPath\.git") {
    Write-Status "📦 Repository already exists, updating..." "Info"
    Push-Location $projectPath
    try {
        git pull origin main 2>&1 | ForEach-Object { Write-Host "   $_" }
    }
    catch {
        Write-Status "⚠️  Could not update via git, will use zip download" "Warning"
    }
    Pop-Location
}
else {
    # Download as zip if git not available
    try {
        $zipPath = "$env:TEMP\idm-reset.zip"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile(
            "https://github.com/AliHamza-Coder/idm-reset-tool/archive/refs/heads/main.zip",
            $zipPath
        )
        
        Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
        Remove-Item $zipPath -Force
        
        # Move extracted folder
        if (Test-Path "$installPath\idm-reset-main") {
            Move-Item "$installPath\idm-reset-main" $projectPath -Force
        }
        
        Write-Status "✅ Downloaded successfully" "Success"
    }
    catch {
        Write-Status "❌ Download failed: $_" "Error"
        exit 1
    }
}
Write-Host ""

# Step 4: Create virtual environment
Write-Status "🐍 Setting up Python virtual environment..." "Info"
$venvPath = "$projectPath\venv"
if (-not (Test-Path "$venvPath\Scripts\python.exe")) {
    try {
        Push-Location $projectPath
        python -m venv venv
        Pop-Location
        Write-Status "✅ Virtual environment created" "Success"
    }
    catch {
        Write-Status "❌ Failed to create virtual environment: $_" "Error"
        exit 1
    }
}
else {
    Write-Status "✅ Virtual environment already exists" "Success"
}
Write-Host ""

# Step 5: Install dependencies
Write-Status "📦 Installing dependencies..." "Info"
try {
    & "$venvPath\Scripts\pip.exe" install --upgrade pip -q
    & "$venvPath\Scripts\pip.exe" install -r "$projectPath\requirements.txt" -q
    Write-Status "✅ Dependencies installed" "Success"
}
catch {
    Write-Status "❌ Failed to install dependencies: $_" "Error"
    exit 1
}
Write-Host ""

# Step 6: Create PowerShell command wrapper
Write-Status "📝 Creating global PowerShell command..." "Info"
$cmdPath = "$env:LOCALAPPDATA\Programs\idm-reset-tool"
if (-not (Test-Path $cmdPath)) {
    New-Item -ItemType Directory -Path $cmdPath -Force | Out-Null
}

$wrapperScript = @"
powershell.exe -NoExit -File \"$projectPath\main.ps1\" @args
"@

$wrapperPath = "$cmdPath\idm-reset-tool.ps1"
# Create batch launcher for the PowerShell command
$batchLauncher = @"
@echo off
cd /d \"$projectPath\"
powershell.exe -NoExit -File \"main.ps1\" %*
"@

$batchPath = "$cmdPath\idm-reset-tool.bat"
Set-Content -Path $batchPath -Value $batchLauncher -Force

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$cmdPath*") {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$userPath;$cmdPath",
        "User"
    )
    Write-Status "✅ Added to PATH" "Success"
}
else {
    Write-Status "✅ Already in PATH" "Success"
}
Write-Host ""

# Step 7: Create desktop shortcut (if admin)
if ($isAdmin) {
    Write-Status "🎯 Creating desktop shortcut..." "Info"
    try {
        $shell = New-Object -ComObject WScript.Shell
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = "$desktopPath\IDM-Reset-Tool.lnk"
        
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-NoExit -File `"$projectPath\main.ps1`""
        $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,16"
        $shortcut.Save()
        
        Write-Status "✅ Desktop shortcut created" "Success"
    }
    catch {
        Write-Status "⚠️  Could not create shortcut: $_" "Warning"
    }
}
Write-Host ""

# Step 8: Verification
Write-Status "🔍 Verifying installation..." "Info"
if ((Test-Path "$projectPath\main.py") -and (Test-Path "$venvPath\Scripts\python.exe")) {
    Write-Status "✅ Installation verified" "Success"
}
else {
    Write-Status "❌ Installation verification failed" "Error"
    exit 1
}
Write-Host ""

# Complete!
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✅ IDM-Reset Tool Setup Complete!                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Status "🚀 You can now run the tool in multiple ways:" "Success"
Write-Host ""
Write-Host "   1️⃣  From anywhere in PowerShell:" -ForegroundColor Cyan
Write-Host "       idm-reset-tool" -ForegroundColor Yellow
Write-Host ""
Write-Host "   2️⃣  From PowerShell in project folder:" -ForegroundColor Cyan
Write-Host "       python main.py" -ForegroundColor Yellow
Write-Host ""
Write-Host "   3️⃣  Using PowerShell version:" -ForegroundColor Cyan
Write-Host "       .\main.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "   4️⃣  Desktop shortcut (if created)" -ForegroundColor Cyan
Write-Host ""

Write-Status "💡 First run tip: Use --scan to preview changes before deletion:" "Info"
Write-Host "    idm-reset-tool --scan" -ForegroundColor Yellow
Write-Host ""

Write-Status "📚 For more help:" "Info"
Write-Host "    idm-reset-tool --help" -ForegroundColor Yellow
Write-Host ""

Write-Host "Installed to: $projectPath" -ForegroundColor Gray
Write-Host ""

# Offer to run immediately
$runNow = Read-Host "✨ Would you like to run the tool now? (y/n)"
if ($runNow -eq 'y') {
    Write-Host ""
    & python "$projectPath\main.py" --scan
}
