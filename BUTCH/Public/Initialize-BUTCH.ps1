function Initialize-BUTCH {
    <#
    .SYNOPSIS
        Initializes the BUTCH module with required credentials and parameters.

    .DESCRIPTION
        This function sets up the required module-scoped variables (Credential, HashDestinationPath,
        TranscriptPath, ADAccountPath, MailTemplate, Signature) that are needed by other functions
        in the BUTCH module. It should be run before using commands that interact with the BUTCH environment.

        When re-run, Initialize-BUTCH automatically recalls the configuration from the previous run
        (or saved profile at %APPDATA%\BUTCH\profile.json) and offers the previous values as defaults
        in interactive prompts, so you can press [Enter] to keep them without retyping.

    .PARAMETER Credential
        The PSCredential object containing the username and password. 
        You can pass the result of Get-Credential here.

    .PARAMETER HashDestinationPath
        Path for hashing distributions (e.g., \\server\share$\folder\).

    .PARAMETER TranscriptPath
        Default absolute path used by Start-BUTCH_Transcript to store log files.
        If omitted, defaults to previous value or Desktop\PS\Transcripts.

    .PARAMETER ADAccountPath
        Target Active Directory Organizational Unit (OU) path for newly created administrative accounts.
        If omitted, defaults to previous value or 'OU=Users,OU=Server Admins,DC=energy,DC=local'.

    .PARAMETER MailTemplate
        Absolute path to an Outlook email template file (.oft) used when sending account provisioning notifications.

    .PARAMETER Signature
        Sender signature name to place in administrative emails. Defaults to previous value or 'Daniel Buczyński'.

    .PARAMETER Silent
        Runs initialization without interactive prompts. Required values are taken from parameters
        or resolved from previous run / saved profile.

    .PARAMETER SaveProfile
        Explicitly displays confirmation that the current initialization data has been saved to the local
        encrypted profile file at %APPDATA%\BUTCH\profile.json. (Profile configuration is automatically
        persisted so subsequent sessions retain default settings).
        Use Clear-BUTCH -PurgeLocalSettings to remove the saved profile.

    .EXAMPLE
        Initialize-BUTCH

        Starts interactive initialization. Any values entered in previous runs are suggested as defaults;
        press Enter to keep them or type a new value.

    .EXAMPLE
        $cred = Get-Credential
        Initialize-BUTCH -Silent -Credential $cred -HashDestinationPath "\\server\share$\folder\"

        Non-interactive initialization. Omitted parameters use previously stored settings or standard defaults.

    .EXAMPLE
        Init-BUTCH

        Runs interactive initialization using the alias.

    .INPUTS
        None

    .OUTPUTS
        [void]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.11.25 16:20
        Version: 2026.11.25.5
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

        [Parameter(Position = 3)]
        [Alias('Path', 'OU', 'ADPath', 'OUForNewAdminAccount')]
        [string]$ADAccountPath,

        [Parameter(Position = 4)]
        [Alias('Template', 'MailTemplateForNewAdminAccount')]
        [string]$MailTemplate,

        [Parameter(Position = 5)]
        [Alias('SignedBy', 'SignatureName')]
        [string]$Signature,

        [Parameter()]
        [switch]$Silent,

        [Parameter()]
        [switch]$SaveProfile
    )

    begin {
        $defaultTranscriptPath = Join-Path -Path $([System.Environment]::GetFolderPath("Desktop")) -ChildPath "PS\Transcripts"
        $defaultADAccountPath  = "OU=Users,OU=Server Admins,DC=energy,DC=local"
        $defaultSignature      = "Daniel Buczyński"

        # Try to resolve previous configuration from memory or saved profile
        $profileDir  = Join-Path $env:APPDATA 'BUTCH'
        $profilePath = Join-Path $profileDir 'profile.json'
        $prevProfile = $null

        if (Test-Path $profilePath) {
            try {
                $rawProfile = Get-Content -Path $profilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json
                $secPass = $null
                $plainPass = $null
                if ($rawProfile.PasswordEncrypted) {
                    $secPass = $rawProfile.PasswordEncrypted | ConvertTo-SecureString -ErrorAction SilentlyContinue
                    if ($secPass) {
                        $plainPass = [System.Net.NetworkCredential]::new('', $secPass).Password
                    }
                }
                $prevProfile = [PSCustomObject]@{
                    Username            = [string]$rawProfile.Username
                    Password            = [string]$plainPass
                    HashDestinationPath = [string]$rawProfile.HashDestinationPath
                    TranscriptPath      = [string]$rawProfile.TranscriptPath
                    ADAccountPath       = [string]$rawProfile.ADAccountPath
                    MailTemplate        = [string]$rawProfile.MailTemplate
                    Signature           = [string]$rawProfile.Signature
                }
            }
            catch {}
        }

        # Candidate defaults: in-memory script:BUTCH_* takes precedence over saved profile file
        $prevUser = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_Username)) {
            $script:BUTCH_Username
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.Username)) {
            $prevProfile.Username
        } else { $null }

        $prevPass = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_Password)) {
            $script:BUTCH_Password
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.Password)) {
            $prevProfile.Password
        } else { $null }

        $prevHash = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_HashDestinationPath)) {
            $script:BUTCH_HashDestinationPath
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.HashDestinationPath)) {
            $prevProfile.HashDestinationPath
        } else { $null }

        $prevTranscript = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_TranscriptPath)) {
            $script:BUTCH_TranscriptPath
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.TranscriptPath)) {
            $prevProfile.TranscriptPath
        } else {
            $defaultTranscriptPath
        }

        $prevADPath = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_ADAccountPath)) {
            $script:BUTCH_ADAccountPath
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.ADAccountPath)) {
            $prevProfile.ADAccountPath
        } else {
            $defaultADAccountPath
        }

        $prevMail = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_MailTemplate)) {
            $script:BUTCH_MailTemplate
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.MailTemplate)) {
            $prevProfile.MailTemplate
        } else { $null }

        $prevSig = if (-not [string]::IsNullOrWhiteSpace($script:BUTCH_Signature)) {
            $script:BUTCH_Signature
        } elseif ($prevProfile -and -not [string]::IsNullOrWhiteSpace($prevProfile.Signature)) {
            $prevProfile.Signature
        } else {
            $defaultSignature
        }

        if ($Silent) {
            if (-not $Credential) {
                if (-not [string]::IsNullOrWhiteSpace($prevUser) -and -not [string]::IsNullOrWhiteSpace($prevPass)) {
                    $sec = ConvertTo-SecureString $prevPass -AsPlainText -Force
                    $Credential = New-Object System.Management.Automation.PSCredential ($prevUser, $sec)
                }
                else {
                    throw "Parameter -Credential is missing, but -Silent switch was used."
                }
            }
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath)) {
                if (-not [string]::IsNullOrWhiteSpace($prevHash)) {
                    $HashDestinationPath = $prevHash
                }
                else {
                    throw "Parameter -HashDestinationPath is missing, but -Silent switch was used."
                }
            }
            if ([string]::IsNullOrWhiteSpace($TranscriptPath)) { $TranscriptPath = $prevTranscript }
            if ([string]::IsNullOrWhiteSpace($ADAccountPath))  { $ADAccountPath = $prevADPath }
            if ([string]::IsNullOrWhiteSpace($MailTemplate))   { $MailTemplate = $prevMail }
            if ([string]::IsNullOrWhiteSpace($Signature))      { $Signature = $prevSig }
        }
        else {
            Write-Host "--- BUTCH Module Initialization ---" -ForegroundColor Cyan

            # HashDestinationPath
            if ([string]::IsNullOrWhiteSpace($HashDestinationPath)) {
                if (-not [string]::IsNullOrWhiteSpace($prevHash)) {
                    $inputHashPath = Read-Host "Provide HashDestinationPath [$prevHash] (Enter = keep)"
                    if ([string]::IsNullOrWhiteSpace($inputHashPath)) {
                        $HashDestinationPath = $prevHash
                    }
                    else {
                        $HashDestinationPath = $inputHashPath
                    }
                }
                else {
                    do {
                        $HashDestinationPath = Read-Host "Provide HashDestinationPath (e.g., \\server\share`$\folder\)"
                    } while ([string]::IsNullOrWhiteSpace($HashDestinationPath))
                }
            }
            else {
                $inputHashPath = Read-Host "Provide HashDestinationPath [$HashDestinationPath] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputHashPath)) {
                    $HashDestinationPath = $inputHashPath
                }
            }

            # TranscriptPath
            if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
                $inputTranscriptPath = Read-Host "Provide TranscriptPath [$prevTranscript] (Enter = keep)"
                if ([string]::IsNullOrWhiteSpace($inputTranscriptPath)) {
                    $TranscriptPath = $prevTranscript
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

            # OU for new Admin Account (ADAccountPath)
            if ([string]::IsNullOrWhiteSpace($ADAccountPath)) {
                $inputADPath = Read-Host "Provide OU for new Admin Account [$prevADPath] (Enter = keep)"
                if ([string]::IsNullOrWhiteSpace($inputADPath)) {
                    $ADAccountPath = $prevADPath
                }
                else {
                    $ADAccountPath = $inputADPath
                }
            }
            else {
                $inputADPath = Read-Host "Provide OU for new Admin Account [$ADAccountPath] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputADPath)) {
                    $ADAccountPath = $inputADPath
                }
            }

            # Mail Template for new Admin Account
            if ([string]::IsNullOrWhiteSpace($MailTemplate)) {
                if (-not [string]::IsNullOrWhiteSpace($prevMail)) {
                    $inputMailTemplate = Read-Host "Provide Mail Template for new Admin Account [$prevMail] (Enter = keep)"
                    if ([string]::IsNullOrWhiteSpace($inputMailTemplate)) {
                        $MailTemplate = $prevMail
                    }
                    elseif ($inputMailTemplate.Trim() -in @('none', 'clear', '$null', '""', "''")) {
                        $MailTemplate = $null
                    }
                    else {
                        $MailTemplate = $inputMailTemplate
                    }
                }
                else {
                    $inputMailTemplate = Read-Host "Provide Mail Template for new Admin Account (e.g. C:\Templates\NewAdminAccount.oft) (Optional)"
                    if (-not [string]::IsNullOrWhiteSpace($inputMailTemplate)) {
                        $MailTemplate = $inputMailTemplate
                    }
                }
            }
            else {
                $inputMailTemplate = Read-Host "Provide Mail Template for new Admin Account [$MailTemplate] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputMailTemplate)) {
                    if ($inputMailTemplate.Trim() -in @('none', 'clear', '$null', '""', "''")) {
                        $MailTemplate = $null
                    }
                    else {
                        $MailTemplate = $inputMailTemplate
                    }
                }
            }

            # Signed by (name)
            if ([string]::IsNullOrWhiteSpace($Signature)) {
                $inputSig = Read-Host "Provide Signed by (name) [$prevSig] (Enter = keep)"
                if ([string]::IsNullOrWhiteSpace($inputSig)) {
                    $Signature = $prevSig
                }
                else {
                    $Signature = $inputSig
                }
            }
            else {
                $inputSig = Read-Host "Provide Signed by (name) [$Signature] (Enter = keep)"
                if (-not [string]::IsNullOrWhiteSpace($inputSig)) {
                    $Signature = $inputSig
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
                    $Credential = Get-Credential -UserName $username -Message "Enter credentials for the BUTCH module (privileged access)"
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($prevUser) -and -not [string]::IsNullOrWhiteSpace($prevPass)) {
                Write-Host "Previous credentials found from last initialization:" -ForegroundColor Yellow
                Write-Host "  Username: $prevUser"
                Write-Host "  Password: ********"
                $confirm = Read-Host "Do you want to keep these credentials? [Y/n] (Enter = Yes)"
                if ($confirm -eq 'n' -or $confirm -eq 'N') {
                    $Credential = Get-Credential -UserName $prevUser -Message "Enter credentials for the BUTCH module (privileged access)"
                }
                else {
                    $sec = ConvertTo-SecureString $prevPass -AsPlainText -Force
                    $Credential = New-Object System.Management.Automation.PSCredential ($prevUser, $sec)
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
            $script:BUTCH_ADAccountPath         = $ADAccountPath
            $script:BUTCH_MailTemplate          = $MailTemplate
            $script:BUTCH_Signature             = $Signature
            [datetime]$script:BUTCH_InitializedAt       = Get-Date
            [bool]$script:BUTCH_IsInitializedFromPrompt = (-not $Silent)
            $script:BUTCH_IsInitialized         = $true

            Write-Verbose "BUTCH module initialized successfully with user: $username"
        }
        catch {
            Write-Error "Failed to initialize BUTCH module: $_"
            throw
        }
    }

    END {
        try {
            $profileDir  = Join-Path $env:APPDATA 'BUTCH'
            $profilePath = Join-Path $profileDir 'profile.json'

            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }

            $encryptedPassword = $Credential.Password | ConvertFrom-SecureString   # DPAPI, no key = user+machine bound
            
            @{
                Username            = $script:BUTCH_Username
                PasswordEncrypted   = $encryptedPassword
                HashDestinationPath = $script:BUTCH_HashDestinationPath
                TranscriptPath      = $script:BUTCH_TranscriptPath
                ADAccountPath       = $script:BUTCH_ADAccountPath
                MailTemplate        = $script:BUTCH_MailTemplate
                Signature           = $script:BUTCH_Signature
                SavedAt             = (Get-Date -Format 'o')
            } | ConvertTo-Json | Set-Content -Path $profilePath -Encoding UTF8

            Write-Verbose "Profile saved at: $profilePath"
            if ($SaveProfile) {
                Write-Host "BUTCH profile saved: $profilePath" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "BUTCH: Could not save profile: $_"
        }

        Get-BUTCH
    }
}

Set-Alias -Name 'Init-BUTCH' -Value Initialize-BUTCH