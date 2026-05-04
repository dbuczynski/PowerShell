function Clear-BUTCH {
    <#
    .SYNOPSIS
        Clears the BUTCH module initialization data.

    .DESCRIPTION
        This function clears all module-scoped variables that were set during Initialize-BUTCH.
        It removes the username, password, Param1, Param2, and sets the initialization status to false.
        This function is also automatically called when the module is removed (via Remove-Module).

    .EXAMPLE
        Clear-BUTCH
        Wipes the memory of the current BUTCH session.
    #>
    [CmdletBinding()]
    param()
    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            throw "Module is not initialized! Please run Initialize-BUTCH first."
        }
    }
    process {
        Write-Verbose "Clearing BUTCH module initialization data..."

        # Wyczyść zmienne zakresowe (script scope)
        $script:BUTCH_Username = $null
        $script:BUTCH_Password = $null
        $script:BUTCH_Param1 = $null
        $script:BUTCH_Param2 = $null
        $script:BUTCH_IsInitialized = $false

        Write-Verbose "BUTCH module data has been cleared."
    }
}
