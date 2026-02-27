<#
.SYNOPSIS
    CA7 Registry Cleaner v3.2 (HKU Only)
    Scans HKU user hives for CLSID entries ENDING with CA7 and allows deletion

.DESCRIPTION
    This script scans only HKEY_USERS for CLSID keys ending with "CA7",
    displays them with subkeys, and optionally deletes them.
    Auto-elevates to Administrator if not already running as admin.

.EXAMPLE
    .\CA7-Cleaner.ps1
    Run with menu interface (auto-elevates if needed)

.EXAMPLE
    .\CA7-Cleaner.ps1 -Force
    Skip confirmation prompts during deletion

.PARAMETER Force
    Skip confirmation prompts
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Version
$script:Version = "3.2.0"

#region Auto-Elevation
# Check if running as administrator, if not, restart as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Administrator privileges required!" -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Cyan
    
    # Get the script path
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # If running from ISE or no path, use current location
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }
    
    # Build arguments
    $argString = ""
    if ($Force) {
        $argString = "-Force"
    }
    
    try {
        # Start new PowerShell process as admin
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $argString" -Verb runas -PassThru
        
        # Exit current non-elevated session
        exit 0
    }
    catch {
        Write-Error "Failed to elevate privileges: $_"
        Write-Host "`nPlease right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
#endregion

# Console setup (only runs when elevated)
$Host.UI.RawUI.WindowTitle = "CA7 Registry Cleaner v$script:Version"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region Helper Functions

function Show-Header {
    Clear-Host
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "           CA7 REGISTRY CLEANER v$script:Version" -ForegroundColor Yellow
    Write-Host "           (HKU Only - Ends with CA7)" -ForegroundColor Gray
    Write-Host "           [RUNNING AS ADMINISTRATOR]" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "1. Scan for CA7 entries" -ForegroundColor Green
    Write-Host "2. Scan and Delete CA7 entries" -ForegroundColor Red
    Write-Host "0. Exit" -ForegroundColor Gray
    Write-Host ""
}

function Ends-WithCA7 {
    param([string]$Name)
    
    # Remove braces if present and check if ends with CA7
    $cleanName = $Name -replace '[{}]', ''
    return $cleanName.ToUpper().EndsWith("CA7")
}

function Get-SubKeys {
    param([string]$Path)
    
    $subkeys = @()
    
    try {
        $regKey = [Microsoft.Win32.Registry]::Users.OpenSubKey($Path)
        if ($null -eq $regKey) { return $subkeys }
        
        $names = $regKey.GetSubKeyNames()
        foreach ($name in $names) {
            $fullPath = Join-Path $Path $name
            $subkeys += [PSCustomObject]@{
                Name = $name
                FullPath = $fullPath
            }
        }
        $regKey.Close()
    }
    catch {
        Write-Debug "Error getting subkeys for ${Path}: $_"
    }
    
    return $subkeys
}

function Export-RegistryKey {
    param(
        [string]$Path,
        [string]$HiveName = "HKU"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $tempDir = [System.IO.Path]::GetTempPath()
        $backupFile = Join-Path $tempDir "CA7_Backup_${HiveName}_$timestamp.reg"
        
        $fullPath = "$HiveName\$Path"
        
        # Use reg.exe for export
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "reg.exe"
        $psi.Arguments = "export `"$fullPath`" `"$backupFile`" /y"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.WaitForExit()
        
        if ($process.ExitCode -eq 0 -and (Test-Path $backupFile)) {
            return $backupFile
        }
        return $null
    }
    catch {
        Write-Warning "Backup failed: $_"
        return $null
    }
}

function Remove-RegistryKeyRecursive {
    param([string]$Path)
    
    try {
        # Open with Write permission
        $regKey = [Microsoft.Win32.Registry]::Users.OpenSubKey($Path, $true)
        if ($null -eq $regKey) { return $false }
        
        # First, delete all subkeys recursively
        $subKeyNames = $regKey.GetSubKeyNames()
        foreach ($subKeyName in $subKeyNames) {
            $subPath = Join-Path $Path $subKeyName
            $success = Remove-RegistryKeyRecursive -Path $subPath
            if (-not $success) {
                $regKey.Close()
                return $false
            }
        }
        
        $regKey.Close()
        
        # Now delete this key itself
        $parentPath = Split-Path $Path -Parent
        $keyName = Split-Path $Path -Leaf
        
        $parentKey = [Microsoft.Win32.Registry]::Users.OpenSubKey($parentPath, $true)
        if ($parentKey) {
            $parentKey.DeleteSubKey($keyName, $false)
            $parentKey.Close()
            return $true
        }
        return $false
    }
    catch [System.Security.SecurityException] {
        Write-Error "Permission denied deleting: $Path"
        return $false
    }
    catch {
        Write-Error "Error deleting ${Path}: $_"
        return $false
    }
}

#endregion

#region Main Functions

function Scan-HKUForCA7 {
    <#
    Scan only HKU user hives for CLSID keys ending with CA7
    #>
    $findings = @()
    
    Write-Host "Scanning HKU for entries ENDING with CA7..." -ForegroundColor Yellow
    Write-Host ""
    
    # Get all user SIDs from HKU
    $userSIDs = @()
    try {
        $hkuKey = [Microsoft.Win32.Registry]::Users
        $subKeyNames = $hkuKey.GetSubKeyNames()
        
        foreach ($sid in $subKeyNames) {
            # Only actual user SIDs (S-1-5-21...) excluding _Classes
            if ($sid -match '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                $userSIDs += $sid
            }
        }
    }
    catch {
        Write-Error "Cannot access HKU: $_"
        return $findings
    }
    
    if ($userSIDs.Count -eq 0) {
        Write-Warning "No user SIDs found in HKU"
        return $findings
    }
    
    Write-Host "Found $($userSIDs.Count) user profile(s) to scan" -ForegroundColor Gray
    Write-Host ""
    
    # Scan each user's Classes\Wow6432Node\CLSID
    foreach ($sid in $userSIDs) {
        $clsidPath = "$sid`_Classes\Wow6432Node\CLSID"
        Write-Host "Scanning $sid..." -ForegroundColor Cyan
        
        try {
            $clsidKey = [Microsoft.Win32.Registry]::Users.OpenSubKey($clsidPath)
            if ($null -eq $clsidKey) { 
                Write-Host "   (CLSID path not found)" -ForegroundColor DarkGray
                continue 
            }
            
            $foundInUser = $false
            $guidNames = $clsidKey.GetSubKeyNames()
            
            foreach ($guidName in $guidNames) {
                # STRICT CHECK: Only if ENDS with CA7
                if (Ends-WithCA7 -Name $guidName) {
                    $foundInUser = $true
                    $fullPath = Join-Path $clsidPath $guidName
                    
                    # Get subkeys inside this CA7 entry
                    $subkeys = Get-SubKeys -Path $fullPath
                    
                    $finding = [PSCustomObject]@{
                        SID = $sid
                        CLSIDPath = $clsidPath
                        FullPath = $fullPath
                        Name = $guidName
                        SubKeys = $subkeys
                    }
                    $findings += $finding
                    
                    Write-Host "   Found: $guidName" -ForegroundColor Green
                    
                    # Show subkeys if any
                    if ($subkeys.Count -gt 0) {
                        foreach ($sub in $subkeys) {
                            Write-Host "      Subkey: $($sub.Name)" -ForegroundColor Gray
                        }
                    }
                }
            }
            
            if (-not $foundInUser) {
                Write-Host "   (No CA7 entries found)" -ForegroundColor DarkGray
            }
            
            $clsidKey.Close()
        }
        catch {
            Write-Error "Error scanning ${clsidPath}: $_"
        }
    }
    
    return $findings
}

function Show-Findings {
    param([array]$Findings)
    
    if ($Findings.Count -eq 0) {
        Write-Host "`nNo registry entries ending with CA7 found in HKU." -ForegroundColor Red
        return
    }
    
    Write-Host "`n$("=" * 70)" -ForegroundColor Cyan
    Write-Host "         CA7 REGISTRY ENTRIES DETECTED (HKU ONLY)" -ForegroundColor Yellow
    Write-Host "$("=" * 70)" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Findings.Count; $i++) {
        $finding = $Findings[$i]
        $num = $i + 1
        
        Write-Host "`n$num. Registry Hive: HKU" -ForegroundColor White
        Write-Host "   User SID:  $($finding.SID)" -ForegroundColor Gray
        Write-Host "   Full Path: HKU\$($finding.FullPath)" -ForegroundColor Gray
        Write-Host "   Key Name:  $($finding.Name)" -ForegroundColor White
        
        # Show last 10 chars ending
        $cleanName = $finding.Name -replace '[{}]', ''
        if ($cleanName.Length -gt 10) {
            $endPart = $cleanName.Substring($cleanName.Length - 10)
            Write-Host "   Ends With: ...$endPart" -ForegroundColor Magenta
        }
        
        # Show subkeys
        if ($finding.SubKeys.Count -gt 0) {
            Write-Host "   SubKeys ($($finding.SubKeys.Count)):" -ForegroundColor Yellow
            foreach ($sub in $finding.SubKeys) {
                Write-Host "      * $($sub.Name)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "   SubKeys:   (none)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n$("=" * 70)" -ForegroundColor Cyan
    Write-Host "Total entries found: $($Findings.Count)" -ForegroundColor Green
    Write-Host "$("=" * 70)" -ForegroundColor Cyan
}

function Remove-CA7Entries {
    param(
        [array]$Findings,
        [switch]$Force
    )
    
    $results = @()
    
    if ($Findings.Count -eq 0) {
        return $results
    }
    
    # Confirmation
    if (-not $Force) {
        Write-Host "`nWARNING: This will PERMANENTLY delete the above entries!" -ForegroundColor Yellow
        Write-Host "   This action CANNOT be undone!" -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Do you want to proceed? (Type 'YES' to confirm)"
        if ($confirm -ne "YES") {
            Write-Host "`nOperation cancelled." -ForegroundColor Yellow
            return $results
        }
    }
    
    Write-Host "`nStarting deletion process..." -ForegroundColor Green
    Write-Host ""
    
    foreach ($finding in $Findings) {
        $name = $finding.Name
        $path = $finding.FullPath
        $sid = $finding.SID
        
        Write-Host "Processing: $name" -ForegroundColor Cyan
        Write-Host "   User: $sid" -ForegroundColor Gray
        
        # Create backup
        $backupPath = Export-RegistryKey -Path $path -HiveName "HKU"
        if ($backupPath) {
            Write-Host "   Backup: $backupPath" -ForegroundColor Green
        }
        else {
            Write-Host "   Backup failed, proceeding anyway..." -ForegroundColor Yellow
        }
        
        # Perform deletion
        $success = Remove-RegistryKeyRecursive -Path $path
        
        if ($success) {
            Write-Host "   Successfully deleted" -ForegroundColor Green
            $results += [PSCustomObject]@{
                Path = "HKU\$path"
                Success = $true
            }
        }
        else {
            Write-Host "   Failed to delete" -ForegroundColor Red
            $results += [PSCustomObject]@{
                Path = "HKU\$path"
                Success = $false
            }
        }
        Write-Host ""
    }
    
    return $results
}

function Show-Summary {
    param([array]$Results)
    
    if ($Results.Count -eq 0) { return }
    
    Write-Host "$("=" * 70)" -ForegroundColor Cyan
    Write-Host "                    DELETION SUMMARY" -ForegroundColor Yellow
    Write-Host "$("=" * 70)" -ForegroundColor Cyan
    
    $success = ($Results | Where-Object { $_.Success }).Count
    $failed = ($Results | Where-Object { -not $_.Success }).Count
    
    Write-Host "Successfully deleted: $success" -ForegroundColor Green
    Write-Host "Failed to delete:    $failed" -ForegroundColor Red
    
    if ($failed -gt 0) {
        Write-Host "`nFailed entries:" -ForegroundColor Yellow
        $Results | Where-Object { -not $_.Success } | ForEach-Object {
            Write-Host "   * $($_.Path)" -ForegroundColor Red
        }
    }
    
    if ($success -eq $Results.Count -and $success -gt 0) {
        Write-Host "`nAll CA7 entries have been successfully removed!" -ForegroundColor Green
    }
    
    Write-Host "$("=" * 70)" -ForegroundColor Cyan
}

#endregion

#region Main Execution

# Main loop (only runs when elevated)
while ($true) {
    Show-Header
    Show-Menu
    
    try {
        $choice = Read-Host "Select option (0-2)"
        [int]$option = [int]::Parse($choice)
    }
    catch {
        Write-Host "Invalid input! Please enter a number." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }
    
    switch ($option) {
        0 {
            Write-Host "`nGoodbye!" -ForegroundColor Green
            exit 0
        }
        
        1 {
            # Scan only
            $findings = Scan-HKUForCA7
            Show-Findings -Findings $findings
            
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        2 {
            # Scan and delete
            $findings = Scan-HKUForCA7
            Show-Findings -Findings $findings
            
            if ($findings.Count -eq 0) {
                Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            
            $results = Remove-CA7Entries -Findings $findings -Force:$Force
            Show-Summary -Results $results
            
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        default {
            Write-Host "Invalid option! Please select 0, 1, or 2." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}

#endregion