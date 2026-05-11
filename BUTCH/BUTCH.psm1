<#
.SYNOPSIS
    BUTCH — a PowerShell module for IT administrators working in Active Directory environments.

.DESCRIPTION
    The BUTCH module provides a set of utility functions designed to simplify common
    IT administration tasks, including:

      - Credential management and AD authentication (Initialize-BUTCH, Test-BUTCH_AdCredentials)
      - BitLocker recovery key retrieval from Active Directory (Get-BUTCH_BitLockerRecoveryKey)
      - Secure file distribution with hash verification (Export-BUTCH_FileHash)
      - Structured transcript / session logging (Start-BUTCH_Transcript)
      - Module lifecycle management (Initialize-BUTCH, Clear-BUTCH, Update-BUTCH)

    Before using most functions, initialize the module with:
        Initialize-BUTCH   (alias: Init-BUTCH)

    To check the current state:
        Get-BUTCH

    To update the module to the latest version:
        Update-BUTCH

.NOTES
    Author:   Daniel Buczynski <DanielBuczynski@gmail.com>
    Release:  2026.05.08 09:00
    Version:  2026.5.11.2
    License:  MIT
    Source:   https://github.com/dbuczynski/PowerShell

.LINK
    https://github.com/dbuczynski/PowerShell

.LINK
    https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1
#>

# Initialize module-scoped variables to avoid "variable not set" errors in strict mode
$script:BUTCH_IsInitialized         = $false
$script:BUTCH_Username              = $null
$script:BUTCH_Password              = $null
$script:BUTCH_HashDestinationPath   = $null
$script:BUTCH_TranscriptPath        = $null
$script:BUTCH_InitializedAt         = $null
$script:BUTCH_IsInitializedFromPrompt = $false

$culture = $host.CurrentCulture.Name -replace '-\w*$', ''

Import-LocalizedData -UICulture $culture -BindingVariable Strings -FileName Strings -ErrorAction Ignore
if (-not $Strings) {
    Import-LocalizedData -UICulture 'en' -BindingVariable Strings -FileName Strings -ErrorAction Ignore
}

# Private helper — defined here, NOT exported, inaccessible outside the module
function Read-BUTCH_Profile {
    $profilePath = Join-Path $env:APPDATA 'BUTCH\profile.json'
    if (-not (Test-Path $profilePath)) { return $null }
    try {
        $data           = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $securePassword = $data.PasswordEncrypted | ConvertTo-SecureString   # DPAPI — no key required
        $plainPassword  = [System.Net.NetworkCredential]::new('', $securePassword).Password
        return [PSCustomObject]@{
            Username            = [string]$data.Username
            Password            = [string]$plainPassword
            HashDestinationPath = [string]$data.HashDestinationPath
            TranscriptPath      = [string]$data.TranscriptPath
        }
    }
    catch {
        Write-Warning "BUTCH: Could not read saved profile: $_"
        return $null
    }
}

foreach ($directory in @('Public')) {
    Get-ChildItem -Recurse -Path "$PSScriptRoot\$directory\*.ps1" | ForEach-Object { . $_.FullName }
}

# Auto-load saved profile if available (silent — no prompts)
$__butchProfile = Read-BUTCH_Profile
if ($null -ne $__butchProfile) {
    $script:BUTCH_Username            = $__butchProfile.Username
    $script:BUTCH_Password            = $__butchProfile.Password
    $script:BUTCH_HashDestinationPath = $__butchProfile.HashDestinationPath
    $script:BUTCH_TranscriptPath      = $__butchProfile.TranscriptPath
    $script:BUTCH_IsInitialized       = $true
    [datetime]$script:BUTCH_InitializedAt       = Get-Date
    [bool]$script:BUTCH_IsInitializedFromPrompt = $false
    Remove-Variable __butchProfile -ErrorAction SilentlyContinue
}

# Funkcja wywoływana automatycznie podczas Remove-Module
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Host "BUTCH Module is being removed. Cleaning up variables..." -ForegroundColor Cyan
    Clear-BUTCH -Force
}

$ESC = [char]27
$Reset = "$ESC[0m"

# Standard colors
# $Black = "$ESC[30m"
# $Red = "$ESC[31m"
# $Green = "$ESC[32m"
$Yellow = "$ESC[33m"
# $Blue = "$ESC[34m"
# $Magenta = "$ESC[35m"
$Cyan = "$ESC[36m"
# $White = "$ESC[37m"

# Bright variants
# $BrightBlack = "$ESC[90m"
# $BrightRed = "$ESC[91m"
# $BrightGreen = "$ESC[92m"
$BrightYellow = "$ESC[93m"
# $BrightBlue = "$ESC[94m"
# $BrightMagenta = "$ESC[95m"
$BrightCyan = "$ESC[96m"
# $BrightWhite = "$ESC[97m"

# Display module information upon import

# Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
# Write-Information -InformationAction Continue ""

# $BrightWhite = "$ESC[97m"

Write-Information -InformationAction Continue ""
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan} BUTCH PowerShell Module ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue " Author:   Daniel Buczynski"
Write-Information -InformationAction Continue " Contact:  DanielBuczynski@gmail.com"
Write-Information -InformationAction Continue " License:  MIT License"
Write-Information -InformationAction Continue " Source:   https://github.com/dbuczynski/PowerShell"
Write-Information -InformationAction Continue ""
Write-Information -InformationAction Continue " NOTE: Please run: > ${Yellow}Init-BUTCH ${Reset}" # -ForegroundColor Yellow -NoNewline
Write-Information -InformationAction Continue " to add elevated credentials."
Write-Information -InformationAction Continue " These credentials may be required by some functions for"
Write-Information -InformationAction Continue " accessing Active Directory, network resources, and more."
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan} Most important function: ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${BrightYellow}Initialize-BUTCH ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Clear-BUTCH ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Update-BUTCH ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Get-BUTCH_BitLockerRecoveryKey ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Start-BUTCH_Transcript ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Test-BUTCH_AdCredentials ${Reset} "
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan} Aliases: ${Reset} " # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${BrightYellow}ST  ${Reset}          --> ${BrightCyan} Start-BUTCH_Transcript${Reset}"
Write-Information -InformationAction Continue "${BrightYellow}Reset-BUTCH ${Reset}  --> ${BrightCyan} Clear-BUTCH ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Init-BUTCH ${Reset}   --> ${BrightCyan} Initialize-BUTCH ${Reset}"
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan}Aktualizacja on-line:     ${Reset}" # oregroundColor Cyan

Write-Information -InformationAction Continue "${BrightYellow}irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex ${Reset}" # -ForegroundColor Cyan


Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue ""
