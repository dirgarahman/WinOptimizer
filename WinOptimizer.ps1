<#
.SYNOPSIS
    Windows Optimization Utility - WinOptimizer.ps1

.DESCRIPTION
    Analyzes system performance and recommends optimization actions for startup apps,
    background services, temporary files, and resource usage.
    Modes:
      - auto      : Analyze and recommend actions only (no changes made).
      - aggressive: Apply aggressive optimization settings.
      - rollback  : Restore settings to defaults.

.EXAMPLE
    .\WinOptimizer.ps1 auto
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("auto","aggressive","rollback")]
    [string]$mode
)

function Get-TempFolderSize {
    $tempPath = [IO.Path]::GetTempPath()
    $tempSize = (Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    return [math]::Round($tempSize / 1MB, 2)
}

Write-Host "🔍 Analyzing system performance and bloat..." -ForegroundColor Cyan

# Detect primary storage type
$osDrive = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 }
if (-not $osDrive) {
    $storageType = "Unknown"
} else {
    $storageType = $osDrive.MediaType
}

# Gather metrics
$startupApps = (Get-CimInstance Win32_StartupCommand).Count
$sysMainStatus = (Get-Service -Name "SysMain").Status
$wSearchStatus = (Get-Service -Name "WSearch").Status
$diagTrackStatus = (Get-Service -Name "DiagTrack").Status
$dmwapPushStatus = (Get-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue).Status
$freeDiskC = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$tempSize = Get-TempFolderSize
$pagingFileUsage = (Get-CimInstance Win32_PageFileUsage).CurrentUsage
$cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
$availRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue, 0)

# Display summary
Write-Host "Storage type: $storageType"
Write-Host "Startup Applications: $startupApps"
Write-Host "Service SysMain status: $sysMainStatus"
Write-Host "Service WSearch status: $wSearchStatus"
Write-Host "Service DiagTrack status: $diagTrackStatus"
Write-Host "Service dmwappushservice status: $dmwapPushStatus"
Write-Host "Free disk space on C: $freeDiskC GB"
Write-Host "Temp folder size: $tempSize MB"
Write-Host "Paging file usage: $pagingFileUsage MB"
Write-Host "Current CPU usage: {0:N1}%%" -f $cpuUsage
Write-Host "Available RAM: $availRAM MB"

# Mode actions
switch ($mode) {
    "auto" {
        Write-Host "`n➡ Based on this info:" -ForegroundColor Yellow
        if ($startupApps -gt 5 -or $tempSize -gt 500 -or $sysMainStatus -eq "Running" -or $wSearchStatus -eq "Running") {
            Write-Host "Recommendation: Aggressive cleanup is suggested."
        } else {
            Write-Host "Recommendation: System looks balanced. Minimal cleanup suggested."
        }
    }
    "aggressive" {
        Write-Host "⚡ Applying aggressive optimization..." -ForegroundColor Red
        # Disable unnecessary services
        Stop-Service -Name "SysMain" -Force
        Set-Service -Name "SysMain" -StartupType Disabled
        Stop-Service -Name "WSearch" -Force
        Set-Service -Name "WSearch" -StartupType Disabled
        Stop-Service -Name "DiagTrack" -Force
        Set-Service -Name "DiagTrack" -StartupType Disabled
        Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        # Clear temp files
        Remove-Item -Path ([IO.Path]::GetTempPath() + "*") -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Aggressive optimization applied."
    }
    "rollback" {
        Write-Host "⏪ Rolling back to default settings..." -ForegroundColor Green
        Set-Service -Name "SysMain" -StartupType Automatic
        Start-Service -Name "SysMain"
        Set-Service -Name "WSearch" -StartupType Automatic
        Start-Service -Name "WSearch"
        Set-Service -Name "DiagTrack" -StartupType Automatic
        Start-Service -Name "DiagTrack"
        Set-Service -Name "dmwappushservice" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
        Write-Host "✅ Rollback completed."
    }
}
