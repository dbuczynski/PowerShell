Write-host hello

Set-Location C:\Users\dbuczynski\Antigravity\GIT-dbuczynski\PowerShell\modules


Import-module .\BUTCH\ -force -Verbose


initialize-BUTCH -Param1 2 -Param2 3 -Credential $kredki -Silent

Get-BUTCH   