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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Verbose "Module is not initialized! Please run Initialize-BUTCH first."
            break
        }
    }
    process {
        Write-Verbose "Clearing BUTCH module initialization data..."

        # Get all variables matching the pattern
        $varsToRemove = Get-Variable -Name "BUTCH_*" -Scope Script -ErrorAction SilentlyContinue

        if ($null -ne $varsToRemove) {
            foreach ($var in $varsToRemove) {
                # Support for -WhatIf and -Confirm
                if ($PSCmdlet.ShouldProcess("Now Module Variable: `$script:$($var.Name)", "Remove")) {
                    Write-Verbose "Now Removing variable: `$script:$($var.Name)"
                    Remove-Variable -Name $var.Name -Scope Script -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Verbose "No variables starting with BUTCH_ found to remove."
        }

        Write-Verbose "BUTCH module data clearance completed."
    }
}
