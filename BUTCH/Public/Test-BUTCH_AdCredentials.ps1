function Test-BUTCH_AdCredentials {
    <#
    .SYNOPSIS
        Verifies if the provided Active Directory credentials are valid.

    .DESCRIPTION
        This function tests whether a given username and password can successfully 
        authenticate against Active Directory. It returns strictly $true or $false.
        If the Credentials parameter is not provided, the function will interactively prompt 
        the user for them (with password masking via standard Windows prompt).

    .PARAMETER Credentials
        The PSCredential object to test. If omitted, the user will be prompted.

    .EXAMPLE
        Test-BUTCH_AdCredentials
        Prompts for credentials and returns $true or $false.

    .EXAMPLE
        $cred = Get-Credential
        Test-BUTCH_AdCredentials -Credentials $cred

    .INPUTS
        [System.Management.Automation.PSCredential]

    .OUTPUTS
        [System.Boolean]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.08.01
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [pscredential]$Credentials
    )

    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Warning "Module is not initialized! Please run Initialize-BUTCH first."
        }
        if (-not $Credentials) {
            $Credentials = Get-Credential -Message "Enter Active Directory credentials to verify"
        }
        [bool]$isValid = $false
    }

    PROCESS {
        $username = $Credentials.UserName
        $password = $Credentials.GetNetworkCredential().Password
        try {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement
            
            # Check if username is in DOMAIN\User format
            if ($username -match "\\") {
                $domain = $username.Split('\')[0]
                $user = $username.Split('\')[1]
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain)
                [bool]$isValid = $context.ValidateCredentials($user, $password)
            }
            else {
                # Try to use the default domain of the current computer
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain)
                [bool]$isValid = $context.ValidateCredentials($username, $password)
            }
        }
        catch {
            [bool]$isValid = $false
        }
    }
    END {
        # Return strictly a boolean
        Write-Verbose ("Authentication check status: " + $isValid)
        return [bool]$isValid
    }
}
