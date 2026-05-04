<#
.SYNOPSIS
    Installs or updates the BUTCH PowerShell module from GitHub.

.DESCRIPTION
    This script downloads the latest version of the dbuczynski/PowerShell repository,
    extracts the BUTCH module, and places it in the current user's standard PowerShell 
    Modules directory. It then automatically imports the module.

.EXAMPLE
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

.NOTES
    Author: DanielBuczynski@gmail.com
    Release: 2026.05.03 09:00
    Version: 2026.05.03.01
    License: MIT
    This function is a part of the BUTCH PowerShell module.
    
.LINK
    Latest version: https://github.com/dbuczynski/PowerShell/tree/main/modules/BUTCH

#>

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Installing BUTCH PowerShell Module" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Zdefiniuj ścieżki
$repoUrl = "https://github.com/dbuczynski/PowerShell/archive/refs/heads/main.zip"
$tempZip = Join-Path $env:TEMP "BUTCH_Install.zip"
$tempExt = Join-Path $env:TEMP "BUTCH_Extracted"

# Bezpieczne pobranie ścieżki modułów bieżącego użytkownika z PSModulePath
$userModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
$modulePath = Join-Path $userModulePath "BUTCH"

try {
    # 1. Pobieranie z GitHuba
    Write-Host "[1/4] Downloading latest version from GitHub..."
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZip -UseBasicParsing

    # 2. Rozpakowywanie
    Write-Host "[2/4] Extracting archive..."
    if (Test-Path $tempExt) { Remove-Item $tempExt -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive -Path $tempZip -DestinationPath $tempExt -Force

    # 3. Instalacja w Modules
    Write-Host "[3/4] Installing to: $modulePath..."
    if (Test-Path $modulePath) { Remove-Item $modulePath -Recurse -Force -ErrorAction SilentlyContinue }
    
    $sourceModulePath = Join-Path $tempExt "PowerShell-main\modules\BUTCH"
    
    # Upewnij się, że główny folder Modules istnieje
    if (-not (Test-Path $userModulePath)) { New-Item -ItemType Directory -Path $userModulePath | Out-Null }
    
    Copy-Item -Path $sourceModulePath -Destination $modulePath -Recurse -Force

    # 4. Import
    Write-Host "[4/4] Importing BUTCH module..."
    Import-Module BUTCH -Force

    Write-Host ""
    Write-Host "SUCCESS! BUTCH module installed and loaded." -ForegroundColor Green
}
catch {
    Write-Error "An error occurred during installation: $_"
}
finally {
    # Sprzątanie
    Write-Verbose "Cleaning up temporary files..."
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExt) { Remove-Item $tempExt -Recurse -Force -ErrorAction SilentlyContinue }
}
