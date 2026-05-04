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

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.03.01
        
    .LINK
        https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Error "Module is not initialized! Please run Initialize-BUTCH first."
            break
        }
    }
    process {
        Write-Information "Clearing BUTCH module initialization data..."

        # Get all variables matching the pattern
        $varsToRemove = Get-Variable -Name "BUTCH_*" -Scope Script -ErrorAction SilentlyContinue

        if ($null -ne $varsToRemove) {
            foreach ($var in $varsToRemove) {
                # Support for -WhatIf and -Confirm
                if ($PSCmdlet.ShouldProcess("Module Variable: `$script:$($var.Name)", "Remove")) {
                    Remove-Variable -Name $var.Name -Scope Script -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Information "No variables starting with BUTCH_ found to remove."
        }

        Write-Information "BUTCH module data clearance completed."
    }
}
