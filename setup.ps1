<#
.SYNOPSIS
    IDM-Reset Tool - One-Line Direct Launch
    Downloads and runs main.ps1 instantly

.EXAMPLE
    irm https://raw.githubusercontent.com/AliHamza-Coder/idm-reset-tool/main/setup.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# Banner
Clear-Host
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            IDM-Reset Tool - Direct Launch                 ║" -ForegroundColor Cyan
Write-Host "║                    v3.2.0                                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/AliHamza-Coder/idm-reset-tool/main/setup.ps1 | iex`"" -Verb runas -PassThru | Wait-Process
        exit 0
    }
    catch {
        Write-Host "Could not elevate. Run as Administrator." -ForegroundColor Red
        exit 1
    }
}

# Download & Extract
Write-Host "Downloading IDM-Reset Tool..." -ForegroundColor Cyan
$tempDir = "$env:TEMP\idm-reset-tool-temp"
$zipPath = "$env:TEMP\idm-reset-tool.zip"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}

try {
    # Download
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile(
        "https://github.com/AliHamza-Coder/idm-reset-tool/archive/refs/heads/main.zip",
        $zipPath
    )
    
    # Extract
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    $projectPath = "$tempDir\idm-reset-tool-main"
    
    Write-Host "✅ Downloaded successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    exit 1
}

# Run main.ps1 directly
Write-Host "Launching IDM-Reset Tool..." -ForegroundColor Cyan
Write-Host ""

try {
    & "$projectPath\main.ps1"
    
    # Cleanup after tool closes
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
