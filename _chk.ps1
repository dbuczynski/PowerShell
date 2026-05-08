$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    'c:\Users\dbuczynski\Antigravity\GIT-dbuczynski\PowerShell\Publish-BUTCH.ps1',
    [ref]$null, [ref]$errors)
if ($errors.Count -eq 0) { Write-Host 'No syntax errors found.' -ForegroundColor Green }
else { $errors | ForEach-Object { Write-Host "Line $($_.Extent.StartLineNumber) col $($_.Extent.StartColumnNumber): $($_.Message)" -ForegroundColor Red } }
