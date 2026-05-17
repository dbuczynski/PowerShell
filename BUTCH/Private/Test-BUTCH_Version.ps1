function Test-BUTCH_Version {
    <#
    .SYNOPSIS
        Displays the version information for this function.

    .DESCRIPTION
        This function extracts the version number from the .NOTES section of its own
        Command-Based Help when called with the -Version parameter.

    .PARAMETER Version
        When specified, the function displays its version extracted from .NOTES and exits.

    .EXAMPLE
        Test-BUTCH_Version -Version

        Outputs the version information.

    .INPUTS
        None

    .OUTPUTS
        [void]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.15 12:15
        Version: 2026.5.15.1
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Version
    )

    begin {
        if ($Version) {
            try {
                # Pobierz pomoc dla bieżącej funkcji
                $help = Get-Help $MyInvocation.MyCommand.Name -ErrorAction Stop
                
                # Spróbuj pobrać notatki (w PS 5.1 często są w alertSet, w PS 7+ często w .notes)
                $notes = ""
                if ($help.notes) {
                    $notes = $help.notes | Out-String
                }
                elseif ($help.alertSet.alert) {
                    $notes = $help.alertSet.alert | Out-String
                }

                # Wyciągnij wersję za pomocą regex
                if ($notes -and $notes -match '(?m)^\s*Version:\s*(.*)$') {
                    $ver = $Matches[1].Trim()
                    Write-Information -InformationAction Continue ("BUTCH Module - [$($MyInvocation.MyCommand.Name)] Version: $ver")
                }
                else {
                    Write-Warning "Version information not found in .NOTES for '$($MyInvocation.MyCommand.Name)'."
                }
            }
            catch {
                Write-Warning "Could not retrieve help for '$($MyInvocation.MyCommand.Name)': $_"
            }
            # Uwaga: Nie blokujemy dalszego wykonania (brak 'return')
        }
    }

    process {
        return "Hello World from PROCESS block"
    }

    end {
        # Miejsce na ewentualne czyszczenie zasobów
    }
}
