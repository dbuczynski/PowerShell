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
    Clear-BUTCH
}
