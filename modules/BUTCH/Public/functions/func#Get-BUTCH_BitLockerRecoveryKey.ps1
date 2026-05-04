function Get-BUTCH_BitLockerRecoveryKey {
    <#
    .SYNOPSIS
        Retrieves the BitLocker Recovery Key from Active Directory for a specified computer(s).

    .DESCRIPTION
        This function queries Active Directory for msFVE-RecoveryInformation objects associated
        with the specified ComputerName(s). It sorts the available recovery keys by creation date 
        (descending) and returns the recovery password along with the computer name(s).
        
        The function also validates if the computer(s) exists in AD before attempting the query.

    .PARAMETER ComputerName
        The name of the computer(s) to retrieve the BitLocker recovery key for. 
        This parameter accepts pipeline input (both by value and by property name).

    .EXAMPLE
        "LAPTOPABCD" | Get-BUTCH_BitLockerRecoveryKey
        Get-BUTCH_BitLockerRecoveryKey -ComputerName LAPTOPABCD
        Get-BUTCH_BitLockerRecoveryKey LAPTOPABCD
        "LAPTOPABCD","LAPTOPEFGH" | Get-BUTCH_BitLockerRecoveryKey
        Get-ADComputer -filter {Name -eq 'LAPTOPABCD'} | Get-BUTCH_BitLockerRecoveryKey
        Get-ADComputer -filter {Name -like 'LAPTOP*'} | Get-BUTCH_BitLockerRecoveryKey

    .INPUTS
        [System.String]

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.03.01
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell/tree/main/modules/BUTCH
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Computer name to be checked")]
        [ValidateScript({
                $ValueToValidate = $_
                try {
                    Get-ADComputer $_
                    return $true
                }
                catch {
                    Write-Error "Computer account '$ValueToValidate' doesn't exist in current Active Directory"
                    throw
                }
            })][String]$ComputerName
    )

    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Warning "Module is not initialized! Please run Initialize-BUTCH first."
        }
        Write-Verbose "Starting validation"
        $Output = @()
    }

    PROCESS {
        try {
            $Output += Get-ADObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -SearchBase (Get-ADComputer $ComputerName).DistinguishedName `
                -Properties msFVE-RecoveryPassword, whenCreated | Sort-Object whenCreated `
                -Descending | Select-Object @{Name = 'ComputerName'; Expression = { $ComputerName } }, msFVE-RecoveryPassword, whenCreated
        }
        catch {
            Write-Error "There was an issue: " + $_
            throw
        }
    }

    END {
        return $Output
    }
}
