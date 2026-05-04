function Start-BUTCH_Transcript {
    <#
    .SYNOPSIS
        Manages logging (transcript) sessions in PowerShell.

    .DESCRIPTION
        The Start-BUTCH_Transcript function stops all currently running transcript sessions (preventing them from overlapping), 
        and then starts a new session if a value is provided for the RITM parameter. The new log file is saved to the user's Desktop.
        
        If an empty value or $null is passed as RITM, the function will only stop the current sessions without starting a new one.

    .PARAMETER RITM
        An identifier (e.g., ticket number, task name) that will become part of the log file name. 
        Passing an empty value (or $null) simply stops any active logging.

    .PARAMETER TranscriptPath
        The path for transcripts (default is "ps\transcripts").

    .EXAMPLE
        Start-BUTCH_Transcript -RITM "12345"
        Stops active sessions and starts a new one, saving the logs to a file on the Desktop (e.g., *-2026-05-04-12345.txt).

    .EXAMPLE
        ST test
        Uses the 'ST' alias to start logging (creates a file designated as 'test').

    .EXAMPLE
        ST $null
        Stops the currently running logging without starting a new one.

    .OUTPUTS
        Details about stopped and/or started transcripts.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.04 09:00
        Version: 2026.05.04.01
        
    .LINK
        https://github.com/dbuczynski/MODULES/blob/main/BUTCH/Public/ps1/func%23Start-BUTCH_Transcript.ps1
        
    .LINK
        https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(Position = 0, Mandatory = $true)][AllowEmptyString()][string]$RITM,
        [ValidateNotNullOrEmpty()][ValidatePattern('\S')][string]$TranscriptPath = "ps\transcripts"
    )
    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            throw "Module is not initialized! Please run Initialize-BUTCH first."
        }
    }
    PROCESS {
        while ($true) {
            try {
                Stop-Transcript -ErrorAction Stop
            }
            catch {
                break
            }

        }
        if ($RITM) {
            Start-Transcript -Append -Path ($([System.Environment]::GetFolderPath("Desktop")) + "\" + $SubPath + "-" + (Get-Date).ToString("yyyy-MM-dd") + "-" + $RITM + ".txt")
        }
    }
    END {
    }

}

Set-Alias -Name 'ST' -Value Start-BUTCH_Transcript
