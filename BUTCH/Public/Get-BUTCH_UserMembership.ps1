function Get-BUTCH_UserMembership {
    <#
    .SYNOPSIS
        Retrieves Active Directory group membership for a specified user account or Distinguished Name.

    .DESCRIPTION
        This function queries Active Directory for the specified user (by account name or Distinguished Name),
        retrieves all groups the user belongs to (via the MemberOf property), and returns a list containing
        the user's SamAccountName, AccountName, GroupName, and GroupDescription.

    .PARAMETER Name
        The username or account name (SamAccountName) to query. Accepts pipeline input (by value or property name).
        If the input string appears to be a Distinguished Name, it will automatically be treated as such.

    .PARAMETER distinguishname
        The Distinguished Name (DN) of the user to query. Accepts pipeline input (by value or property name).

    .EXAMPLE
        Get-BUTCH_UserMembership -Name "jdoe"
        Retrieves group membership for user "jdoe".

    .EXAMPLE
        "jdoe" | Get-BUTCH_UserMembership
        Retrieves group membership for user "jdoe" via pipeline.

    .EXAMPLE
        Get-BUTCH_UserMembership -distinguishname "CN=John Doe,OU=Users,DC=domain,DC=com"
        Retrieves group membership using Distinguished Name.

    .EXAMPLE
        Get-ADUser -Filter "Enabled -eq $true" | Get-BUTCH_UserMembership
        Retrieves group membership for all enabled AD users passed via pipeline.

    .INPUTS
        [System.String]

    .OUTPUTS
        [PSCustomObject]
        Returns objects containing SamAccountName, AccountName, GroupName, and GroupDescription.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.9.2 13:00
        Version: 2026.9.2.1
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Please enter the username for which you want to check group membership.")]
        [Alias('SamAccountName', 'UserName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByDistinguishedName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Please enter the distinguished name of the user for which you want to check group membership.")]
        [Alias('DistinguishedName', 'DN')]
        [string]$distinguishname
    )

    BEGIN {
        $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($isInit -ne $true) {
            Write-Warning "Module is not initialized! Please run Initialize-BUTCH first."
        }
        $Output = @()
    }

    PROCESS {
        # If neither Name nor distinguishname was supplied, prompt for Name with comment in English
        if ([string]::IsNullOrWhiteSpace($Name) -and [string]::IsNullOrWhiteSpace($distinguishname)) {
            $Name = Read-Host -Prompt "Please enter the username for which you want to check group membership"
        }

        # Check if $Name looks like a Distinguished Name
        if ([string]::IsNullOrWhiteSpace($distinguishname) -and -not [string]::IsNullOrWhiteSpace($Name)) {
            if ($Name -match '(?i)^CN=|^OU=|^DC=' -or $Name -match '(?i)DC=') {
                $distinguishname = $Name
                $Name = $null
            }
        }

        $targetInput = if (-not [string]::IsNullOrWhiteSpace($distinguishname)) { $distinguishname } else { $Name }

        try {
            if ([string]::IsNullOrWhiteSpace($targetInput)) {
                throw "No user name or distinguished name was provided."
            }

            # Validate whether the user exists in Active Directory
            if (-not [string]::IsNullOrWhiteSpace($distinguishname)) {
                $adUser = Get-ADUser -Identity $distinguishname -Properties SamAccountName, Name, MemberOf -ErrorAction Stop
            }
            else {
                $adUser = Get-ADUser -Identity $Name -Properties SamAccountName, Name, MemberOf -ErrorAction Stop
            }

            if ($null -eq $adUser) {
                throw "User '$targetInput' was not found in Active Directory."
            }

            # Get list of groups using (Get-ADUser -Properties MemberOf $user).MemberOf
            $memberOfList = (Get-ADUser -Identity $adUser.DistinguishedName -Properties MemberOf -ErrorAction Stop).MemberOf

            if ($null -ne $memberOfList) {
                foreach ($groupDN in $memberOfList) {
                    try {
                        $groupObj = Get-ADGroup -Identity $groupDN -Properties Name, Description -ErrorAction Stop
                        $gName = $groupObj.Name
                        $gDesc = $groupObj.Description
                    }
                    catch {
                        $gName = $groupDN
                        $gDesc = $null
                    }

                    $Output += [PSCustomObject]@{
                        SamAccountName   = $adUser.SamAccountName
                        AccountName      = $adUser.Name
                        GroupName        = $gName
                        GroupDescription = $gDesc
                    }
                }
            }
        }
        catch {
            Write-Error "User validation or query failed for '$targetInput': $_"
        }
    }

    END {
        return $Output
    }
}
