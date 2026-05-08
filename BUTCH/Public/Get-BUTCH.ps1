function Get-BUTCH {
    <#
    .SYNOPSIS
        Displays the current BUTCH module variables and initialization state.

    .DESCRIPTION
        This function returns a custom object containing the current values of the module-scoped variables
        (Username, and initialization status). For security reasons, the password is not displayed.

    .EXAMPLE
        Get-BUTCH
        Returns the current module state.

    .INPUTS
        None

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.3 09:00
        Version: 2026.5.8.4
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell


    #>
    [CmdletBinding()]
    param()

    BEGIN {

    }

    PROCESS {
        if ([bool]$script:BUTCH_IsInitialized) {
            [PSCustomObject]@{
                IsInitialized           = [bool]$script:BUTCH_IsInitialized
                Username                = [string]$script:BUTCH_Username
                HasPassword             = [bool]$script:BUTCH_Password
                HashDestinationPath     = [string]$script:BUTCH_HashDestinationPath
                TranscriptPath          = [string]$script:BUTCH_TranscriptPath
                InitializedAt           = [datetime]$script:BUTCH_InitializedAt
                IsInitializedFromPrompt = [bool]$script:BUTCH_IsInitializedFromPrompt
            }
        }
        else {
            [PSCustomObject]@{
                IsInitialized = [bool]$script:BUTCH_IsInitialized
            }
        }
    }
    END {
        
    }
}
