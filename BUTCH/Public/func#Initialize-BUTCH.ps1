function Initialize-BUTCH {
    <#
    .SYNOPSIS
        Initializes the BUTCH module with required credentials and parameters.

    .DESCRIPTION
        This function sets up the required module-scoped variables (credentials, Param1, Param2) 
        that are needed by other functions in the BUTCH module. It should be run before using 
        commands that interact with the BUTCH environment.

    .PARAMETER Credential
        The PSCredential object containing the username and password. 
        You can pass the result of Get-Credential here.

    .PARAMETER Param1
        The first required string parameter (e.g., API Endpoint, Server Name).

    .PARAMETER Param2
        The second required string parameter (e.g., Environment, Tenant ID).

    .EXAMPLE
        $cred = Get-Credential
        Initialize-BUTCH -Credential $cred -Param1 "https://api.example.com" -Param2 "Production"

        Initializes the module and stores the provided configuration in the module's memory.

    .INPUTS
        None

    .OUTPUTS
        [void]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.03.01
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [pscredential]$Credential,

        [Parameter(Position = 1)]
        [string]$Param1,

        [Parameter(Position = 2)]
        [string]$Param2,

        [Parameter(Position = 3)]
        [string]$HashDestinationPath,

        [Parameter()]
        [switch]$Silent
    )

    begin {
        if ($Silent) {
            if (-not $Credential) { throw "Parameter -Credential is missing, but -Silent switch was used." }
            if ([string]::IsNullOrWhiteSpace($Param1)) { throw "Parameter -Param1 is missing, but -Silent switch was used." }
            if ([string]::IsNullOrWhiteSpace($Param2)) { throw "Parameter -Param2 is missing, but -Silent switch was used." }
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath)) { throw "Parameter -HashDestinationPath is missing, but -Silent switch was used." }
        }
        else {
            Write-Host "--- BUTCH Module Initialization ---" -ForegroundColor Cyan
            
            # Param1
            if ([string]::IsNullOrWhiteSpace($Param1)) {
                do {
                    $Param1 = Read-Host "Provide Param1 (required)"
                } while ([string]::IsNullOrWhiteSpace($Param1))
            }
            else {
                $inputParam1 = Read-Host "Provide Param1 [$Param1] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputParam1)) { 
                    $Param1 = $inputParam1 
                }
            }

            # Param2
            if ([string]::IsNullOrWhiteSpace($Param2)) {
                do {
                    $Param2 = Read-Host "Provide Param2 (required)"
                } while ([string]::IsNullOrWhiteSpace($Param2))
            }
            else {
                $inputParam2 = Read-Host "Provide Param2 [$Param2] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputParam2)) { 
                    $Param2 = $inputParam2 
                }
            }

            # HashDestinationPath
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath)) {
                do {
                    $HashDestinationPath = Read-Host "Provide HashDestinationPath (e.g., \\server\share$\folder\)"
                } while ([string]::IsNullOrWhiteSpace($HashDestinationPath))
            }
            else {
                $inputHashPath = Read-Host "Provide HashDestinationPath [$HashDestinationPath] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputHashPath)) { 
                    $HashDestinationPath = $inputHashPath 
                }
            }

            # Credential
            if ($Credential) {
                $username = $Credential.UserName
                Write-Host "Credentials provided on input:" -ForegroundColor Yellow
                Write-Host "  Username: $username"
                Write-Host "  Password: ********"
                $confirm = Read-Host "Do you confirm using these credentials? [Y/n] (Enter = Yes)"
                if ($confirm -eq 'n' -or $confirm -eq 'N') {
                    $Credential = Get-Credential -Message "Enter credentials for the BUTCH module (privileged access)"
                }
            }
            else {
                Write-Host "No credentials provided on input." -ForegroundColor Yellow
                $Credential = Get-Credential -Message "Enter credentials for the BUTCH module (privileged access)"
            }
        }
    }

    process {
        try {
            Write-Verbose "Initializing BUTCH module..."

            # Extract username and password from the object
            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password

            # Save to module-scoped variables
            $script:BUTCH_Username = $username
            $script:BUTCH_Password = $password
            $script:BUTCH_Param1 = $Param1
            $script:BUTCH_Param2 = $Param2
            $script:BUTCH_HashDestinationPath = $HashDestinationPath
            [datetime]$script:BUTCH_InitializedAt = Get-Date
            [bool]$script:BUTCH_IsInitializedFromPrompt = $Silent
            $script:BUTCH_IsInitialized = $true

            Write-Verbose "BUTCH module initialized successfully with user: $username"
        }
        catch {
            Write-Error "Failed to initialize BUTCH module: $_"
            throw
        }
    }
    END {
        Get-BUTCH   
    }
}

Set-Alias -Name 'Init-BUTCH' -Value Initialize-BUTCH
