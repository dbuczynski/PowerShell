function Clear-BUTCH {
    <#
    .SYNOPSIS
        Clears the BUTCH module initialization data.

    .DESCRIPTION
        This function clears all module-scoped variables that were set during Initialize-BUTCH.
        It removes the username, password, Param1, Param2, and sets the initialization status to false.
        This function is also automatically called when the module is removed (via Remove-Module).

    .PARAMETER Force
        Forces the clearance of the BUTCH module initialization data, bypassing the standard check that verifies whether the module was initialized first.

    .EXAMPLE
        Clear-BUTCH
        Wipes the memory of the current BUTCH session.

    .EXAMPLE
        Clear-BUTCH -Force
        Forces the clearance of variables even if the module was never initialized during this session, suppressing the initialization warning.

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.8 11:00
        Version: 2026.5.11.4
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()][switch]$Force
    )
    BEGIN {
        $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if (($isInit -ne $true) -and (-not $force)) {
            Write-Warning "Module is not initialized! Please run Initialize-BUTCH first."
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

Set-Alias -Name 'Reset-BUTCH' -Value Clear-BUTCH
