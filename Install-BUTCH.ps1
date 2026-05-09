<#
.SYNOPSIS
    Installs or updates the BUTCH PowerShell module from GitHub.

.DESCRIPTION
    This script downloads the BUTCH module from the dbuczynski/PowerShell GitHub repository
    and installs it using a version-based subfolder structure (e.g., BUTCH\2026.5.7.1\).

    By default, the module is installed for the current user only.
    Use -AllUsers to install machine-wide (requires running as Administrator).

    By default, the latest version from the 'main' branch is installed.
    To install a specific historical version, use the -Version parameter together with 
    a GitHub Release tag (e.g., v2026.5.3.1). Tags must exist in the repository.

    This script can be run directly from the internet via:
        irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    To pass parameters when running remotely, use the ScriptBlock method:
        & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1'))) -AllUsers

    Alternatively, set variables before using iex:
        $BUTCHAllUsers = $true
        irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    To install a specific version this way, set $BUTCHVersion before running:
        $BUTCHVersion = 'v2026.5.3.1'
        irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

.PARAMETER Version
    Optional. The GitHub Release tag to install (e.g., 'v2026.5.3.1').
    If omitted, the latest version from the 'main' branch is used.

.PARAMETER AllUsers
    Optional. Installs the module machine-wide for all users.
    Requires the script to be run as Administrator.
    Default: installs for the current user only.

.EXAMPLE
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    Installs the latest version of the BUTCH module for the current user.

.EXAMPLE
    & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1'))) -AllUsers

    Installs machine-wide directly from GitHub (ScriptBlock method - supports all parameters).

.EXAMPLE
    $BUTCHAllUsers = $true
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    Installs machine-wide using the iex variable method.

.EXAMPLE
    .\Install-BUTCH.ps1 -AllUsers

    Installs the latest version machine-wide (run as Administrator).

.EXAMPLE
    .\Install-BUTCH.ps1 -Version v2026.5.3.1

    Installs a specific historical version using a GitHub Release tag.

.EXAMPLE
    $BUTCHVersion = 'v2026.5.3.1'
    irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex

    Installs a specific version when running from the internet (iex mode).

.NOTES
    Author: DanielBuczynski@gmail.com
    Release: 2026.05.09 10:00
    Version: 2026.05.09.01
    License: MIT

.LINK
    Latest version: https://github.com/dbuczynski/PowerShell

#>
param(
    [Parameter(Position = 0)]
    [string]$Version,

    [Parameter()]
    [switch]$AllUsers
)

# Obsługa trybu iex: jeśli parametry nie podane, sprawdź zmienne pomocnicze
if ([string]::IsNullOrWhiteSpace($Version) -and -not [string]::IsNullOrWhiteSpace($BUTCHVersion)) {
    $Version = $BUTCHVersion
}
if (-not $AllUsers -and $BUTCHAllUsers) {
    $AllUsers = [switch]$true
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

# Wybór ścieżki instalacji: użytkownik vs. globalnie (AllUsers)
# Sprawdź uprawnienia administratora (używane niezależnie od trybu)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($AllUsers) {
    # Ścieżka globalna: Program Files\PowerShell\Modules lub Windows\System32\WindowsPowerShell\...
    $targetModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator) |
        Where-Object { $_ -match 'Program Files' -or $_ -match 'System32' } |
        Select-Object -First 1
    if (-not $targetModulePath) {
        Write-Error "Could not determine a machine-wide Modules path from `$env:PSModulePath."
        return
    }
    if ($isAdmin) {
        Write-Host " Scope   : AllUsers (elevated) -> $targetModulePath" -ForegroundColor DarkGray
    }
    else {
        Write-Host " Scope   : AllUsers (will prompt for admin credentials) -> $targetModulePath" -ForegroundColor Yellow
        Write-Host "           Download will run as current user. Install step will use elevated credentials." -ForegroundColor DarkGray
    }
}
else {
    # Ścieżka bieżącego użytkownika (pierwszy element PSModulePath)
    $targetModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
    Write-Host " Scope   : CurrentUser -> $targetModulePath" -ForegroundColor DarkGray
}

$moduleRootPath = Join-Path $targetModulePath "BUTCH"

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

    if ($AllUsers -and -not $isAdmin) {
        # --- Instalacja z podniesieniem uprawnień (UAC) ---
        Write-Host ""
        Write-Host " Elevation (UAC) required for machine-wide installation." -ForegroundColor Yellow
        Write-Host " Please click 'Yes' in the system prompt." -ForegroundColor DarkGray

        # Tymczasowy log wynikowy
        $elevatedLog = Join-Path $env:TEMP "BUTCH_ElevatedInstall.log"
        if (Test-Path $elevatedLog) { Remove-Item $elevatedLog -Force }

        # Skrypt uruchamiany z podwyższonymi uprawnieniami
        # Używamy Base64, aby uniknąć problemów z cytowaniem w argumentach Start-Process
        $elevatedScript = @"
Set-StrictMode -Off
`$ErrorActionPreference = 'Stop'
try {
    if (-not (Test-Path '$moduleRootPath')) { New-Item -ItemType Directory -Path '$moduleRootPath' -Force | Out-Null }
    if (Test-Path '$modulePath')            { Remove-Item '$modulePath' -Recurse -Force }
    Copy-Item -Path '$sourceModulePath' -Destination '$modulePath' -Recurse -Force
    "SUCCESS" | Set-Content '$elevatedLog'
}
catch {
    "ERROR: `$($_.Exception.Message)" | Set-Content '$elevatedLog'
}
"@
        $encodedScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($elevatedScript))

        Write-Host "[3/4] Launching elevated install process..."
        $proc = Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedScript" `
            -Verb RunAs `
            -PassThru -Wait

        # Odczytaj log wynikowy
        if (Test-Path $elevatedLog) {
            $logContent = Get-Content $elevatedLog -Raw
            Remove-Item $elevatedLog -Force -ErrorAction SilentlyContinue
        }
        else {
            $logContent = "ERROR: Elevated process produced no output (UAC cancelled or process crashed)."
        }

        if ($logContent -match '^SUCCESS') {
            Write-Host ""
            Write-Host "SUCCESS! BUTCH module $moduleVersion installed for all users." -ForegroundColor Green
            Write-Host "         Run 'Import-Module BUTCH -RequiredVersion $moduleVersion' to load it." -ForegroundColor DarkGray
        }
        else {
            throw "Elevated install failed. $logContent"
        }
    }
    else {
        # --- Instalacja bezpośrednia (admin lub CurrentUser) ---
        if (-not (Test-Path $moduleRootPath)) { New-Item -ItemType Directory -Path $moduleRootPath | Out-Null }
        if (Test-Path $modulePath) { Remove-Item $modulePath -Recurse -Force -ErrorAction SilentlyContinue }
        Copy-Item -Path $sourceModulePath -Destination $modulePath -Recurse -Force

        # 4. Import
        Write-Host "[4/4] Importing BUTCH module (version $moduleVersion)..."
        Import-Module BUTCH -RequiredVersion $moduleVersion -Force

        Write-Host ""
        Write-Host "SUCCESS! BUTCH module $moduleVersion installed and loaded." -ForegroundColor Green
    }
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
