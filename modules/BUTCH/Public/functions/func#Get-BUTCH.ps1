function Get-BUTCH {
    <#
    .SYNOPSIS
        Displays the current BUTCH module variables and initialization state.

    .DESCRIPTION
        This function returns a custom object containing the current values of the module-scoped variables
        (Param1, Param2, Username, and initialization status). For security reasons, the password is not displayed.

    .EXAMPLE
        Get-BUTCH
        Returns the current module state.
    #>
    [CmdletBinding()]
    param()

    BEGIN {

    }

    PROCESS {
        [PSCustomObject]@{
            IsInitialized           = [bool]$script:BUTCH_IsInitialized
            Username                = [string]$script:BUTCH_Username
            HasPassword             = [bool]$script:BUTCH_Password
            Param1                  = [string]$script:BUTCH_Param1
            Param2                  = [string]$script:BUTCH_Param2
            InitializedAt           = [datetime]$script:BUTCH_InitializedAt
            IsInitializedFromPrompt = [bool]$script:BUTCH_IsInitializedFromPrompt
        }
    }
    END {
        
    }
}
