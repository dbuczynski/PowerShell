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
        Version: 2026.5.11.4
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
        $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($isInit -eq $true) {
            [PSCustomObject]@{
                IsInitialized           = $true
                Username                = Get-Variable -Name 'BUTCH_Username' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                HasPassword             = [bool](Get-Variable -Name 'BUTCH_Password' -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
                HashDestinationPath     = Get-Variable -Name 'BUTCH_HashDestinationPath' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                TranscriptPath          = Get-Variable -Name 'BUTCH_TranscriptPath' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                InitializedAt           = Get-Variable -Name 'BUTCH_InitializedAt' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                IsInitializedFromPrompt = Get-Variable -Name 'BUTCH_IsInitializedFromPrompt' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            }
        }
        else {
            [PSCustomObject]@{
                IsInitialized = [bool]$isInit
            }
        }
    }
    END {
        
    }
}
