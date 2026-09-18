<#
.SYNOPSIS
    Tar bort bindningen av calc-knappen och, om du vill, installationsmappen.

.EXAMPLE
    .\uninstall.ps1 -RemoveFiles -RestartExplorer
#>
[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Excalibur",
    [switch]$RemoveFiles,
    [switch]$RestartExplorer
)

$ErrorActionPreference = 'Stop'

$appKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AppKey\18'
if (Test-Path $appKey) {
    Remove-Item $appKey -Recurse -Force
    Write-Host "Tog bort $appKey - calc-knappen går tillbaka till Windows kalkylator."
} else {
    Write-Host "Ingen bindning att ta bort."
}

if ($RemoveFiles -and (Test-Path $InstallDir)) {
    Get-Process -Name 'Excal32','excalibur-launcher' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object { $_.CloseMainWindow() | Out-Null; $_.WaitForExit(3000) | Out-Null }

    Remove-Item $InstallDir -Recurse -Force
    Write-Host "Tog bort $InstallDir"
}

if ($RestartExplorer) {
    Stop-Process -Name explorer -Force
}
