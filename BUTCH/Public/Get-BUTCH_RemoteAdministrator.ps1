function Get-BUTCH_RemoteAdministrator {
    <#
    .SYNOPSIS
        Retrieves members of the local Administrators group from remote computers.

    .DESCRIPTION
        This function connects to remote computers using PowerShell Remoting (Invoke-Command) and retrieves
        the members of the local Administrators group. The local Administrators group is identified
        dynamically by its Well-Known SID (S-1-5-32-544), making this command independent of the system's locale
        or regional settings.

        It requires that the BUTCH module has been initialized using Initialize-BUTCH, as it uses the
        credentials saved during module initialization for the remote connections.

        It accepts computer names as strings, or Active Directory computer objects piped directly from Get-ADComputer.
        If a piped object is not a computer (determined by ObjectClass not being 'computer'), it is rejected.

    .PARAMETER ComputerName
        The name of the remote computer(s) to query. Accepts strings or objects from the pipeline.
        Supports pipeline binding by property name (e.g. from Get-ADComputer properties like Name or SamAccountName).

    .EXAMPLE
        Get-BUTCH_RemoteAdministrator -ComputerName "PC01"
        Retrieves administrators for computer "PC01".

    .EXAMPLE
        "PC01", "PC02" | Get-BUTCH_RemoteAdministrator
        Retrieves administrators for "PC01" and "PC02" sequentially.

    .EXAMPLE
        Get-ADComputer -Filter "Name -like 'SRV*'" | Get-BUTCH_RemoteAdministrator
        Retrieves administrators for all AD computers matching the filter.

    .INPUTS
        [System.Object]

    .OUTPUTS
        [PSCustomObject] containing ComputerName, Status, GroupName, and Members.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.19 14:45
        Version: 2026.5.19.6
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name', 'SamAccountName', 'CN')]
        [object[]]$ComputerName
    )

    BEGIN {
        $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($isInit -ne $true) {
            Throw "BUTCH: Module is not initialized! Please run Initialize-BUTCH first to configure credentials."
        }

        $username = Get-Variable -Name 'BUTCH_Username' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        $password = Get-Variable -Name 'BUTCH_Password' -Scope Script -ValueOnly -ErrorAction SilentlyContinue

        if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
            Throw "BUTCH: Initialization credentials are empty or missing. Please run Initialize-BUTCH."
        }

        Write-Verbose "Retrieved credentials for user: $username"
        $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($username, $secPassword)
    }

    PROCESS {
        foreach ($item in $ComputerName) {
            if ($null -eq $item) { continue }

            $computer = $null
            $isComputerType = $true

            # Check if the input is a rich object (e.g. AD computer object)
            if ($item.PSObject -ne $null) {
                $objectClass = $null
                if ($item.PSObject.Properties['ObjectClass'] -ne $null) {
                    $objectClass = $item.ObjectClass
                }

                # If ObjectClass is present and it is NOT 'computer', reject the object
                if ($null -ne $objectClass -and $objectClass -ne 'computer') {
                    $itemName = $item.Name
                    if ([string]::IsNullOrWhiteSpace($itemName) -and $item.PSObject.Properties['SamAccountName'] -ne $null) {
                        $itemName = $item.SamAccountName
                    }
                    if ([string]::IsNullOrWhiteSpace($itemName)) {
                        $itemName = $item.ToString()
                    }
                    Write-Error "Object '$itemName' is of class '$objectClass', but a computer account is required."
                    $isComputerType = $false
                }
                else {
                    # Attempt to resolve name from common AD computer properties
                    if ($item.PSObject.Properties['DNSHostName'] -ne $null -and -not [string]::IsNullOrWhiteSpace($item.DNSHostName)) {
                        $computer = $item.DNSHostName
                    }
                    elseif ($item.PSObject.Properties['Name'] -ne $null -and -not [string]::IsNullOrWhiteSpace($item.Name)) {
                        $computer = $item.Name
                    }
                    elseif ($item.PSObject.Properties['SamAccountName'] -ne $null -and -not [string]::IsNullOrWhiteSpace($item.SamAccountName)) {
                        $computer = $item.SamAccountName
                    }
                    else {
                        $computer = $item.ToString()
                    }
                }
            }
            else {
                # Simple type (e.g., String)
                $computer = $item.ToString()
            }

            # Skip if type check failed or computer name is empty
            if (-not $isComputerType -or [string]::IsNullOrWhiteSpace($computer)) {
                continue
            }

            Write-Verbose "Checking local Administrators group on computer: $computer"

            $status = $false
            $groupName = $null
            $members = @()

            try {
                $remoteResult = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
                    $adminGroup = Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-544' }
                    if (-not $adminGroup) {
                        throw "Local Administrators group (SID S-1-5-32-544) was not found on this system."
                    }
                    $gName = $adminGroup.Name
                    $mList = @(Get-LocalGroupMember -Group $gName | Select-Object -ExpandProperty Name)
                    
                    [PSCustomObject]@{
                        GroupName = $gName
                        Members   = $mList
                    }
                } -ErrorAction Stop

                $status = $true
                $groupName = $remoteResult.GroupName
                $members = $remoteResult.Members
            }
            catch {
                Write-Error "Failed to retrieve local Administrators for '$computer': $_"
                $status = $false
            }

            [PSCustomObject]@{
                ComputerName = $computer
                Status       = $status
                GroupName    = $groupName
                Members      = $members
            }
        }
    }

    END {
        # Reserved for potential resource cleanup
    }
}
            }

            $outputObj = [PSCustomObject]@{
                ComputerName = $computer
                Status       = $status
                GroupName    = $groupName
                Members      = $members
                ErrorMessage = $errorMessage
            }
            Set-DefaultDisplayProperties -Object $outputObj
        }
    }

    END {
        # Reserved for potential resource cleanup
    }
}
