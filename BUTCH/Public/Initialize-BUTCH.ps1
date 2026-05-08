function Initialize-BUTCH {
    <#
    .SYNOPSIS
        Initializes the BUTCH module with required credentials and parameters.

    .DESCRIPTION
        This function sets up the required module-scoped variables (Credential, HashDestinationPath, TranscriptPath)
        that are needed by other functions in the BUTCH module. It should be run before using 
        commands that interact with the BUTCH environment.

    .PARAMETER Credential
        The PSCredential object containing the username and password. 
        You can pass the result of Get-Credential here.

    .PARAMETER HashDestinationPath
        Path for hashing distributions (e.g., \\server\share$\folder\).

    .PARAMETER TranscriptPath
        Default absolute path used by Start-BUTCH_Transcript to store log files.
        If omitted, the function will suggest Desktop\PS\Transcripts as default.

    .PARAMETER Silent
        Runs initialization without interactive prompts. All required parameters must be provided on input.

    .PARAMETER SaveProfile
        Saves the current initialization data (credentials, paths) to a local encrypted profile file
        at %APPDATA%\BUTCH\profile.json. The password is encrypted using DPAPI (tied to the current
        Windows user and machine). On next Import-Module BUTCH, the profile is loaded automatically
        without the need to run Initialize-BUTCH again.
        Use Clear-BUTCH -PurgeLocalSettings to remove the saved profile.

    .EXAMPLE
        $cred = Get-Credential
        Initialize-BUTCH -Silent -Credential $cred -HashDestinationPath "\\server\share$\folder\" -SaveProfile

        Fully non-interactive initialization with profile saved. On next session, Import-Module BUTCH
        will restore this configuration automatically.

    .EXAMPLE
        Initialize-BUTCH

        Starts interactive initialization. The user will be prompted for all required values.

    .EXAMPLE
        $cred = Get-Credential
        Initialize-BUTCH -Credential $cred -HashDestinationPath "\\server\share$\folder\"

        Runs interactive initialization with Credential and HashDestinationPath pre-filled.

    .EXAMPLE
        $cred = Get-Credential
        Initialize-BUTCH -Silent -Credential $cred -HashDestinationPath "\\server\share$\folder\" -TranscriptPath "C:\Logs"

        Fully non-interactive initialization. Useful in automated/scripted environments.

    .INPUTS
        None

    .OUTPUTS
        [void]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.08.02
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
        [string]$HashDestinationPath,

        [Parameter(Position = 2)]
        [string]$TranscriptPath,

        [Parameter()]
        [switch]$Silent,

        [Parameter()]
        [switch]$SaveProfile
    )

    begin {
        $defaultTranscriptPath = Join-Path -Path $([System.Environment]::GetFolderPath("Desktop")) -ChildPath "PS\Transcripts"

        if ($Silent) {
            if (-not $Credential)                                    { throw "Parameter -Credential is missing, but -Silent switch was used." }
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath))  { throw "Parameter -HashDestinationPath is missing, but -Silent switch was used." }
            if ([string]::IsNullOrWhiteSpace($TranscriptPath))       { $TranscriptPath = $defaultTranscriptPath }
        }
        else {
            Write-Host "--- BUTCH Module Initialization ---" -ForegroundColor Cyan

            # HashDestinationPath
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath)) {
                do {
                    $HashDestinationPath = Read-Host "Provide HashDestinationPath (e.g., \\server\share`$\folder\)"
                } while ([string]::IsNullOrWhiteSpace($HashDestinationPath))
            }
            else {
                $inputHashPath = Read-Host "Provide HashDestinationPath [$HashDestinationPath] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputHashPath)) {
                    $HashDestinationPath = $inputHashPath
                }
            }

            # TranscriptPath
            if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
                $inputTranscriptPath = Read-Host "Provide TranscriptPath (Enter = keep default: $defaultTranscriptPath)"
                if ([string]::IsNullOrWhiteSpace($inputTranscriptPath)) {
                    $TranscriptPath = $defaultTranscriptPath
                }
                else {
                    $TranscriptPath = $inputTranscriptPath
                }
            }
            else {
                $inputTranscriptPath = Read-Host "Provide TranscriptPath [$TranscriptPath] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputTranscriptPath)) {
                    $TranscriptPath = $inputTranscriptPath
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
            $script:BUTCH_Username              = $username
            $script:BUTCH_Password              = $password
            $script:BUTCH_HashDestinationPath   = $HashDestinationPath
            $script:BUTCH_TranscriptPath        = $TranscriptPath
            [datetime]$script:BUTCH_InitializedAt       = Get-Date
            [bool]$script:BUTCH_IsInitializedFromPrompt = $Silent
            $script:BUTCH_IsInitialized         = $true

            Write-Verbose "BUTCH module initialized successfully with user: $username"
        }
        catch {
            Write-Error "Failed to initialize BUTCH module: $_"
            throw
        }
    }

    END {
        if ($SaveProfile) {
            try {
                $profileDir  = Join-Path $env:APPDATA 'BUTCH'
                $profilePath = Join-Path $profileDir 'profile.json'

                if (-not (Test-Path $profileDir)) {
                    New-Item -ItemType Directory -Path $profileDir | Out-Null
                }

                $encryptedPassword = $Credential.Password | ConvertFrom-SecureString   # DPAPI, no key = user+machine bound

                @{
                    Username            = $script:BUTCH_Username
                    PasswordEncrypted   = $encryptedPassword
                    HashDestinationPath = $script:BUTCH_HashDestinationPath
                    TranscriptPath      = $script:BUTCH_TranscriptPath
                    SavedAt             = (Get-Date -Format 'o')
                } | ConvertTo-Json | Set-Content -Path $profilePath -Encoding UTF8

                Write-Host "BUTCH profile saved: $profilePath" -ForegroundColor Green
                Write-Verbose "Profile saved at: $profilePath"
            }
            catch {
                Write-Warning "BUTCH: Could not save profile: $_"
            }
        }
        Get-BUTCH
    }
}

Set-Alias -Name 'Init-BUTCH' -Value Initialize-BUTCH
