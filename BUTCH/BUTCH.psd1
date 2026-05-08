@{
    RootModule           = 'BUTCH.psm1'
    GUID                 = 'f4585434-d121-450b-b3ea-db7fcddedb95'
    Author               = "Daniel Buczynski <DanielBuczynski@gmail.com>"
    CompanyName          = "githhub.com/dbuczynski"
    Description          = 'It does cool stuff for BUTCH.'
    ModuleVersion        = "2026.5.8.1"
    PowerShellVersion    = "5.1"
    CompatiblePSEditions = @('Core', 'Desktop')
    Copyright            = "© 2026 All rights reserved."
    FunctionsToExport    = @(
        'Initialize-BUTCH',
        'Clear-BUTCH',
        'Get-BUTCH',
        'Update-BUTCH',
        'Export-BUTCH_FileHash',
        'Get-BUTCH_BitLockerRecoveryKey',
        'Start-BUTCH_Transcript',
        'Test-BUTCH_AdCredentials'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @(
        'Init-BUTCH',
        'Reset-BUTCH',
        'ST'
    )
    FileList             = @(
        '.\BUTCH.psm1',
        '.\BUTCH.psd1',
        '.\Public\Clear-BUTCH.ps1',
        '.\Public\Export-BUTCH_FileHash.ps1',
        '.\Public\Get-BUTCH.ps1',
        '.\Public\Get-BUTCH_BitLockerRecoveryKey.ps1',
        '.\Public\Initialize-BUTCH.ps1',
        '.\Public\Start-BUTCH_Transcript.ps1',
        '.\Public\Test-BUTCH_AdCredentials.ps1',
        '.\Public\Update-BUTCH.ps1'
    )
}