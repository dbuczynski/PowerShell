function Start-BUTCH_Transcript {
    <#
    .SYNOPSIS
        Manages logging (transcript) sessions in PowerShell.

    .DESCRIPTION
        The Start-BUTCH_Transcript function stops all currently running transcript sessions (preventing them from overlapping), 
        and then starts a new session if a value is provided for the TITLE parameter. The new log file is saved to the path 
        determined by the TranscriptPath parameter, module settings, or standard Desktop fallback.
        
        If an empty value or $null is passed as TITLE, the function will only stop the current sessions without starting a new one.

    .PARAMETER TITLE
        An identifier (e.g., ticket number, task name) that will become part of the log file name. 
        Passing an empty value (or $null) simply stops any active logging.

    .PARAMETER TranscriptPath
        Optional path for transcripts. If provided, it overrides the BUTCH_TranscriptPath variable initialized by the module for this specific session.
        If empty or omitted, the function falls back to BUTCH_TranscriptPath, or Desktop\PS\Transcripts if module hasn't set one.

    .EXAMPLE
        Start-BUTCH_Transcript -TITLE "12345"
        Stops active sessions and starts a new one, saving the logs to the module's initialized path (e.g., Desktop\PS\Transcripts\2026-05-04-12345.txt).

    .EXAMPLE
        ST test -TranscriptPath "C:\Logs"
        Uses the 'ST' alias to start logging and saves the file explicitly to C:\Logs.

    .EXAMPLE
        ST $null
        Stops the currently running logging without starting a new one.

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.String]
        Details about stopped and/or started transcripts.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.03 09:00
        Version: 2026.05.07.02
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(Position = 0, Mandatory = $true)][AllowEmptyString()][string]$TITLE,
        [ValidateNotNullOrEmpty()][ValidatePattern('\S')][string]$TranscriptPath = "PS\Transcripts"
    )
    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Warning "Module is not initialized! Please run Initialize-BUTCH first."
        }

        if ($PSBoundParameters.ContainsKey('TranscriptPath')) {
            $activePath = $TranscriptPath
        }
        elseif ($script:BUTCH_TranscriptPath) {
            $activePath = $script:BUTCH_TranscriptPath
        }
        else {
            $activePath = Join-Path -Path $([System.Environment]::GetFolderPath('Desktop')) -ChildPath "PS\Transcripts"
        }
    }
    PROCESS {
        Write-Information "Killing existing transcripts"
        while ($true) {
            
            try {
                Stop-Transcript -ErrorAction Stop
            }
            catch {
                break
            }

        }
        if ($TITLE) {
            $fileName = "$((Get-Date).ToString('yyyy-MM-dd'))-$TITLE.txt"
            if ([string]::IsNullOrWhiteSpace($activePath)) {
                $fullPath = $fileName
            }
            else {
                $fullPath = Join-Path -Path $activePath -ChildPath $fileName
            }
            Write-Information "Starting transcript: $fullPath"
            try {
                Start-Transcript -Append -Path $fullPath
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }
    }
    END {

    }
}

Set-Alias -Name 'ST' -Value Start-BUTCH_Transcript