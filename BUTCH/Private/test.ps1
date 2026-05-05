Write-host hello

Set-Location C:\Users\dbuczynski\Antigravity\GIT-dbuczynski\PowerShell


Import-module C:\Users\dbuczynski\Antigravity\GIT-dbuczynski\PowerShell\BUTCH\ -force -Verbose

Remove-module BUTCH -Force -Verbose -InformationAction Continue

$kredki = get-credential -UserName testing -Message "nowe kredki"
Initialize-BUTCH -Param1 2 -Param2 3 -Credential $kredki -Silent | out-null

Get-BUTCH   
 

Clear-Host; Clear-BUTCH -WhatIf
Clear-Host; Clear-BUTCH -Verbose -WhatIf
Clear-Host; Clear-BUTCH -InformationAction Continue -WhatIf
Clear-Host; Clear-BUTCH -Verbose -InformationAction Continue -WhatIf


Clear-Host; Clear-BUTCH
Clear-Host; Clear-BUTCH -Verbose
Clear-Host; Clear-BUTCH -InformationAction Continue
Clear-Host; Clear-BUTCH -Verbose -InformationAction Continue

Test-BUTCH_AdCredentials