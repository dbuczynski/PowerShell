@{
    RootModule           = 'BUTCH.psm1'
    GUID                 = 'f4585434-d121-450b-b3ea-db7fcddedb95'
    Author               = "Daniel Buczynski <DanielBuczynski@gmail.com>"
    CompanyName          = "githhub.com/dbuczynski"
    Description          = 'It does cool stuff for BUTCH.'
    ModuleVersion        = "2026.05.04"
    PowerShellVersion    = "5.1"
    CompatiblePSEditions = @('Core', 'Desktop')
    Copyright            = "© 2026 All rights reserved."
    FunctionsToExport    = '*'
    CmdletsToExport      = '*'
    VariablesToExport    = '*'
    AliasesToExport      = '*'
    FileList             = @(
        '.\Public\functions\'
    )
}