function Update-BUTCH {
    <#
    .SYNOPSIS
        Checks for a newer version of the BUTCH module and updates if available.

    .DESCRIPTION
        Update-BUTCH compares the locally installed version of the BUTCH module with the 
        version available in the GitHub repository. If a newer version is found remotely, 
        the official Install-BUTCH.ps1 installer is downloaded and executed automatically.

        The local version is determined by querying the installed module manifest (BUTCH.psd1)
        via Get-Module -ListAvailable. The remote version is read directly from the manifest 
        file hosted on GitHub, without downloading the full archive.

    .PARAMETER Force
        Forces the reinstallation even if the local version matches or is newer than the remote one.

    .PARAMETER WhatIf
        Shows what would happen if the update ran without actually performing the update.

    .EXAMPLE
        Update-BUTCH

        Checks for a newer version and installs it if available.

    .EXAMPLE
        Update-BUTCH -Force

        Forces reinstallation of the module regardless of version comparison.

    .EXAMPLE
        Update-BUTCH -WhatIf

        Performs the version check and displays the result without installing anything.

    .INPUTS
        None

    .OUTPUTS
        [void]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.7 00:00
        Version: 2026.5.8.4
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
        $remoteManifestUrl  = 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/BUTCH/BUTCH.psd1'
        $remoteInstallerUrl = 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1'
    }

    PROCESS {
        # --- Wersja lokalna ---
        $localModule = Get-Module -Name 'BUTCH' -ListAvailable |
                       Sort-Object Version -Descending |
                       Select-Object -First 1

        if ($localModule) {
            $localVersion = $localModule.Version
            Write-Host "Local  version : " -NoNewline
            Write-Host "$localVersion" -ForegroundColor Cyan
        }
        else {
            Write-Host "Local  version : " -NoNewline
            Write-Host "not installed" -ForegroundColor Yellow
            $localVersion = [Version]'0.0.0.0'
        }

        # --- Wersja zdalna ---
        try {
            $remoteContent = Invoke-WebRequest -Uri $remoteManifestUrl -UseBasicParsing -ErrorAction Stop
            # Wyciągnij wartość ModuleVersion z treści pliku .psd1
            $versionMatch = [regex]::Match($remoteContent.Content, "ModuleVersion\s*=\s*[`"']([^`"']+)[`"']")
            if (-not $versionMatch.Success) {
                Write-Error "Could not parse ModuleVersion from remote manifest."
                return
            }
            $remoteVersion = [Version]$versionMatch.Groups[1].Value
            Write-Host "Remote version : " -NoNewline
            Write-Host "$remoteVersion" -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed to fetch remote manifest: $_"
            return
        }

        # --- Porównanie ---
        if ($remoteVersion -gt $localVersion -or $Force) {
            if ($Force -and $remoteVersion -le $localVersion) {
                Write-Host ""
                Write-Host "Version is up to date, but -Force was specified. Reinstalling..." -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "New version available: $remoteVersion (installed: $localVersion)" -ForegroundColor Green
            }

            if ($PSCmdlet.ShouldProcess("BUTCH module", "Install version $remoteVersion")) {
                Write-Host "Running installer..." -ForegroundColor Cyan
                Invoke-Expression (Invoke-WebRequest -Uri $remoteInstallerUrl -UseBasicParsing).Content
            }
        }
        else {
            Write-Host ""
            Write-Host "BUTCH is up to date (version $localVersion)." -ForegroundColor Green
        }
    }

    END {
    }
}
