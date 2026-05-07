<#
.SYNOPSIS
    Installs or updates the BUTCH PowerShell module from GitHub.

.DESCRIPTION
    This script downloads the BUTCH module from the dbuczynski/PowerShell GitHub repository
    and installs it in the current user's standard PowerShell Modules directory using 
    version-based subfolder structure (e.g., BUTCH\2026.5.7.1\).

    By default, the latest version from the 'main' branch is installed.
    To install a specific historical version, use the -Version parameter together with 
    a GitHub Release tag (e.g., v2026.5.3.1). Tags must exist in the repository.

    This script can be run directly from the internet via:
        irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    To install a specific version this way, set $BUTCHVersion before running:
        $BUTCHVersion = 'v2026.5.3.1'
        irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

.PARAMETER Version
    Optional. The GitHub Release tag to install (e.g., 'v2026.5.3.1').
    If omitted, the latest version from the 'main' branch is used.

.EXAMPLE
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    Installs the latest version of the BUTCH module.

.EXAMPLE
    .\Install-BUTCH.ps1 -Version v2026.5.3.1

    Installs a specific historical version using a GitHub Release tag.

.EXAMPLE
    $BUTCHVersion = 'v2026.5.3.1'
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    Installs a specific version when running from the internet (iex mode).

.NOTES
    Author: DanielBuczynski@gmail.com
    Release: 2026.05.07 00:00
    Version: 2026.05.07.01
    License: MIT

.LINK
    Latest version: https://github.com/dbuczynski/PowerShell

#>
param(
    [Parameter(Position = 0)]
    [string]$Version
)

# Obsługa trybu iex: jeśli $Version nie podany jako parametr, sprawdź zmienną $BUTCHVersion
if ([string]::IsNullOrWhiteSpace($Version) -and -not [string]::IsNullOrWhiteSpace($BUTCHVersion)) {
    $Version = $BUTCHVersion
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Installing BUTCH PowerShell Module"         -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Zdefiniuj URL w zależności od wersji
if ([string]::IsNullOrWhiteSpace($Version)) {
    $repoUrl   = "https://github.com/dbuczynski/PowerShell/archive/refs/heads/main.zip"
    $archiveSuffix = "PowerShell-main"
    Write-Host " Source  : latest (main branch)" -ForegroundColor DarkGray
}
else {
    # Normalizacja: dodaj 'v' jeśli brakuje
    if (-not $Version.StartsWith('v')) { $Version = "v$Version" }
    $repoUrl   = "https://github.com/dbuczynski/PowerShell/archive/refs/tags/$Version.zip"
    $archiveSuffix = "PowerShell-$($Version.TrimStart('v'))"
    Write-Host " Source  : release tag $Version" -ForegroundColor DarkGray
}

$tempZip = Join-Path $env:TEMP "BUTCH_Install.zip"
$tempExt = Join-Path $env:TEMP "BUTCH_Extracted"

# Bezpieczne pobranie ścieżki modułów bieżącego użytkownika z PSModulePath
$userModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
$moduleRootPath = Join-Path $userModulePath "BUTCH"

try {
    # 1. Pobieranie z GitHuba
    Write-Host "[1/4] Downloading from GitHub..."
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZip -UseBasicParsing

    # 2. Rozpakowywanie
    Write-Host "[2/4] Extracting archive..."
    if (Test-Path $tempExt) { Remove-Item $tempExt -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive -Path $tempZip -DestinationPath $tempExt -Force

    # 3. Instalacja w Modules
    $sourceModulePath = Join-Path $tempExt "$archiveSuffix\BUTCH"

    # Odczytaj wersję z pliku manifestu
    $psdPath      = Join-Path $sourceModulePath "BUTCH.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $psdPath).ModuleVersion
    $modulePath   = Join-Path $moduleRootPath $moduleVersion

    Write-Host "[3/4] Installing version $moduleVersion to: $modulePath..."

    # Upewnij się, że foldery istnieją
    if (-not (Test-Path $moduleRootPath)) { New-Item -ItemType Directory -Path $moduleRootPath | Out-Null }
    if (Test-Path $modulePath) { Remove-Item $modulePath -Recurse -Force -ErrorAction SilentlyContinue }

    Copy-Item -Path $sourceModulePath -Destination $modulePath -Recurse -Force

    # 4. Import
    Write-Host "[4/4] Importing BUTCH module (version $moduleVersion)..."
    Import-Module BUTCH -RequiredVersion $moduleVersion -Force

    Write-Host ""
    Write-Host "SUCCESS! BUTCH module $moduleVersion installed and loaded." -ForegroundColor Green
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
