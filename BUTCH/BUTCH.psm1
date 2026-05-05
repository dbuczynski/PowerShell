$culture = $host.CurrentCulture.Name -replace '-\w*$', ''

Import-LocalizedData -UICulture $culture -BindingVariable Strings -FileName Strings -ErrorAction Ignore
if (-not $Strings) {
    Import-LocalizedData -UICulture 'en' -BindingVariable Strings -FileName Strings -ErrorAction Ignore
}

foreach ($directory in @('Public', 'External')) {
    Get-ChildItem -Recurse -Path "$PSScriptRoot\$directory\*.ps1" | ForEach-Object { . $_.FullName }
}

# Funkcja wywoływana automatycznie podczas Remove-Module
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Host "BUTCH Module is being removed. Cleaning up variables..." -ForegroundColor Cyan
    Clear-BUTCH -Force
}

$ESC = [char]27
$Reset   = "$ESC[0m"

# Standard colors
$Black   = "$ESC[30m"
$Red     = "$ESC[31m"
$Green   = "$ESC[32m"
$Yellow  = "$ESC[33m"
$Blue    = "$ESC[34m"
$Magenta = "$ESC[35m"
$Cyan    = "$ESC[36m"
$White   = "$ESC[37m"

# Bright variants
$BrightBlack   = "$ESC[90m"
$BrightRed     = "$ESC[91m"
$BrightGreen   = "$ESC[92m"
$BrightYellow  = "$ESC[93m"
$BrightBlue    = "$ESC[94m"
$BrightMagenta = "$ESC[95m"
$BrightCyan    = "$ESC[96m"
$BrightWhite   = "$ESC[97m"

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
Write-Information -InformationAction Continue "${BrightYellow}Get-BUTCH_BitLockerRecoveryKey ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Start-BUTCH_Transcript ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Test-BUTCH_AdCredentials ${Reset} "
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan} Aliases: ${Reset} " # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${BrightYellow}ST  ${Reset}          --> ${BrightCyan} Start-BUTCH_Transcript${Reset}"
Write-Information -InformationAction Continue "${BrightYellow}Reset-BUTCH ${Reset}  --> ${BrightCyan} Clear-BUTCH ${Reset} "
Write-Information -InformationAction Continue "${BrightYellow}Init-BUTCH ${Reset}   --> ${BrightCyan} Initialize-BUTCH ${Reset}"
Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue "${Cyan Aktualizacja on-line: ${Reset}" # -ForegroundColor Cyan

Write-Information -InformationAction Continue "${BrightYellow}irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex ${Reset}" # -ForegroundColor Cyan


Write-Information -InformationAction Continue "${Cyan}============================================================ ${Reset}" # -ForegroundColor Cyan
Write-Information -InformationAction Continue ""
