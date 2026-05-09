<#
.SYNOPSIS
    Publishes a new release of the BUTCH module to GitHub.

.DESCRIPTION
    This script automates the full release workflow for the BUTCH PowerShell module:

    1. Scans all Public\*.ps1 files and reads the 'Version:' field from their headers.
    2. Selects the highest version found across all function files.
    3. Verifies (and if needed, updates) the BUTCH.psd1 manifest to match that version.
    4. Commits all pending changes to Git.
    5. Pushes the commit to the remote (GitHub).
    6. Creates a Git tag matching the version (e.g., v2026.5.7.1).
    7. Pushes the tag to GitHub, making it available as a downloadable release.

.PARAMETER CommitMessage
    Optional custom commit message. 
    If omitted, defaults to: "release <version>"

.PARAMETER DryRun
    Performs all checks and shows what would happen, but makes no changes to Git or the manifest.

.EXAMPLE
    .\Publish-BUTCH.ps1

    Runs the full release workflow using the highest version found in function headers.

.EXAMPLE
    .\Publish-BUTCH.ps1 -DryRun

    Shows all steps without making any changes.

.EXAMPLE
    .\Publish-BUTCH.ps1 -CommitMessage "release 2026.5.7.1 - added Update-BUTCH function"

    Runs the full release with a custom commit message.

.NOTES
    Author: DanielBuczynski@gmail.com
    Release: 2026.5.7 00:00
    Version: 2026.5.9.1
    License: MIT
    Requires: Git installed and configured, remote 'origin' pointing to GitHub.

.LINK
    Latest version: https://github.com/dbuczynski/PowerShell

#>
param(
    [Parameter(Position = 0)]
    [string]$CommitMessage,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$publicPath = Join-Path $repoRoot "BUTCH\Public"
$psdPath = Join-Path $repoRoot "BUTCH\BUTCH.psd1"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " BUTCH Module - Release Workflow"             -ForegroundColor Cyan
if ($DryRun) {
    Write-Host " [DRY RUN - no changes will be made]"    -ForegroundColor Yellow
}
Write-Host "=============================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# KROK 1: Odczytaj wersje z plików funkcji oraz skryptów głównych
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[1/5] Scanning files for Version headers..." -ForegroundColor White

$versionPattern = '^\s+Version:\s+(\d{4}\.\d{1,2}\.\d{1,2}\.\d{1,2})\s*$'
$versions = @()

# Lista plików do sprawdzenia: folder Public oraz skrypty instalacyjne/publikacyjne w głównym katalogu
$filesToScan = @(
    (Get-ChildItem -Path $publicPath -Filter "*.ps1" -Recurse),
    (Get-ChildItem -Path $repoRoot -Filter "Install-BUTCH.ps1"),
    (Get-ChildItem -Path $repoRoot -Filter "Publish-BUTCH.ps1")
)

$filesToScan | ForEach-Object {
    if ($_ -is [System.IO.FileInfo]) {
        $fileItem = $_
        $match = Select-String -Path $fileItem.FullName -Pattern $versionPattern | Select-Object -First 1
        if ($match) {
            $rawVer = $match.Matches[0].Groups[1].Value
            $versions += [PSCustomObject]@{
                File    = $fileItem.Name
                Raw     = $rawVer
                Version = [Version]$rawVer
            }
            Write-Host ("  {0,-50} {1}" -f $fileItem.Name, $rawVer) -ForegroundColor DarkGray
        }
        else {
            Write-Warning "  No Version header found in: $($fileItem.Name)"
        }
    }
}

if ($versions.Count -eq 0) {
    Write-Error "No version information found in any scanned files. Aborting."
    exit 1
}

$highestEntry = $versions | Sort-Object Version -Descending | Select-Object -First 1
$highestRaw = $highestEntry.Raw        # e.g. 2026.05.07.01
$highestSource = $highestEntry.File

# Konwersja do formatu psd1: usuń wiodące zera (2026.05.07.01 → 2026.5.7.1)
$psdVersion = ($highestRaw -split '\.') | ForEach-Object { [int]$_ } | ForEach-Object { $_.ToString() }
$psdVersion = $psdVersion -join '.'     # e.g. 2026.5.7.1

Write-Host ""
Write-Host "  Highest version : $highestRaw (from $highestSource)" -ForegroundColor Green
Write-Host "  psd1 format     : $psdVersion" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 2: Zweryfikuj/zaktualizuj BUTCH.psd1
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Verifying BUTCH.psd1 manifest..." -ForegroundColor White

$psdData = Import-PowerShellDataFile -Path $psdPath
$currentPsdVersion = $psdData.ModuleVersion

Write-Host "  Current psd1 ModuleVersion : $currentPsdVersion"

if ([Version]$currentPsdVersion -lt [Version]$psdVersion) {
    Write-Host "  Updating ModuleVersion to: $psdVersion" -ForegroundColor Yellow

    if (-not $DryRun) {
        $psdContent = Get-Content $psdPath -Raw
        $psdContent = $psdContent -replace '(ModuleVersion\s*=\s*")[^"]+(")', "`${1}$psdVersion`$2"
        Set-Content -Path $psdPath -Value $psdContent -NoNewline
        Write-Host "  BUTCH.psd1 updated." -ForegroundColor Green
    }
    else {
        Write-Host "  [DRY RUN] Would update ModuleVersion from $currentPsdVersion to $psdVersion" -ForegroundColor Yellow
    }
}
elseif ([Version]$currentPsdVersion -gt [Version]$psdVersion) {
    Write-Warning "  psd1 version ($currentPsdVersion) is HIGHER than the highest function version ($psdVersion)."
    Write-Warning "  Using psd1 version as authoritative."
    $psdVersion = $currentPsdVersion
}
else {
    Write-Host "  psd1 version matches highest function version. OK." -ForegroundColor Green
}

$tagName = "v$psdVersion"

# -----------------------------------------------------------------------------
# KROK 3: Git add + commit
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/5] Committing changes to Git..." -ForegroundColor White

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $CommitMessage = "release $psdVersion"
}
Write-Host "  Commit message: $CommitMessage"

if (-not $DryRun) {
    Push-Location $repoRoot
    git add .
    git commit -m $CommitMessage
    Pop-Location
}
else {
    Write-Host "  [DRY RUN] Would run: git add . && git commit -m `"$CommitMessage`"" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# KROK 4: Git push
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/5] Pushing to remote (origin)..." -ForegroundColor White

if (-not $DryRun) {
    Push-Location $repoRoot
    git push
    Pop-Location
}
else {
    Write-Host "  [DRY RUN] Would run: git push" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# KROK 5: Git tag + push tag
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/5] Creating and pushing tag: $tagName..." -ForegroundColor White

if (-not $DryRun) {
    Push-Location $repoRoot
    git tag $tagName
    git push origin $tagName
    Pop-Location
    Write-Host "  Tag $tagName created and pushed." -ForegroundColor Green
}
else {
    Write-Host "  [DRY RUN] Would run: git tag $tagName && git push origin $tagName" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Podsumowanie
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host " [DRY RUN] Release $psdVersion simulation complete." -ForegroundColor Yellow
}
else {
    Write-Host " Release $psdVersion published successfully!" -ForegroundColor Green
    Write-Host " GitHub tag : $tagName"                        -ForegroundColor DarkGray
    Write-Host " Install    : .\Install-BUTCH.ps1 -Version $tagName" -ForegroundColor DarkGray
}
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
