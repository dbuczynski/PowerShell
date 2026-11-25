function Keep-BUTCH_SystemAwake {
    <#
    .SYNOPSIS
        Prevents the operating system from sleeping, turning off the display, or locking due to inactivity.

    .DESCRIPTION
        This function keeps the Windows operating system awake and active by:
        1. Requesting continuous system and display execution states via SetThreadExecutionState (ES_CONTINUOUS, ES_SYSTEM_REQUIRED, ES_DISPLAY_REQUIRED).
        2. Monitoring user idle time via GetLastInputInfo API.
        3. Simulating a subtle mouse movement event via mouse_event whenever the user idle time reaches or exceeds the specified threshold ($MaxIdleSeconds).
        4. Optionally restricting stay-awake simulation to specific days of the week and hours of the day.

        The function supports three modes of operation:
        - Foreground (default): Runs in the current console session with optional live progress bar (-Verbose), restoring default state upon termination (e.g. Ctrl+C). If schedule parameters are omitted, it operates continuously (24/7).
        - Background (-Background): Launches a detached hidden background process and immediately releases the console. In background mode, schedule parameters default to SimulateOnDays '1-5' (Monday-Friday) and SimulateOnHours '8-15' (08:00 - 15:59). If an instance is already running in the background, it takes no action.
        - Break (-Break): Finds and terminates all background instances of Keep-BUTCH_SystemAwake.

    .PARAMETER MaxIdleSeconds
        The maximum duration in seconds that the system is permitted to remain idle before resetting the inactivity timer.
        Default is 60 seconds. Value must be at least 1.

    .PARAMETER SimulateOnDays
        Days of the week to simulate activity where 1=Monday through 7=Sunday.
        Supports single days, ranges, and comma-separated lists (e.g., '1,3-4,7' or '1-5').
        Defaults to '1-5' (Monday to Friday) when running in background mode.
        If omitted in foreground mode, day filtering is ignored.

    .PARAMETER SimulateOnHours
        Hours of the day (0..23) to simulate activity.
        Supports single hours, ranges, and comma-separated lists (e.g., '8-10,12-16' or '8-15' covering 08:00 to 15:59).
        Defaults to '8-15' when running in background mode.
        If omitted in foreground mode, hour filtering is ignored.

    .PARAMETER Background
        Runs the stay-awake process in the background as a detached hidden process and returns control to the console.
        If a background instance is already active, the function takes no action.

    .PARAMETER Break
        Terminates all instances of Keep-BUTCH_SystemAwake currently running in the background.

    .EXAMPLE
        Keep-BUTCH_SystemAwake
        Keeps the system awake continuously in the foreground using default settings (no schedule restrictions).

    .EXAMPLE
        Keep-BUTCH_SystemAwake -Background
        Starts the process in the background with default working hours schedule: Monday-Friday (1-5) and 08:00-15:59 (8-15).

    .EXAMPLE
        Keep-BUTCH_SystemAwake -SimulateOnDays 1,3-4,7 -SimulateOnHours 8-10,12-16
        Runs in the foreground, simulating activity only on specified days (Mon, Wed-Thu, Sun) and hours (08:00-10:59, 12:00-16:59).

    .EXAMPLE
        Keep-BUTCH_SystemAwake -MaxIdleSeconds 120 -SimulateOnDays 1-5 -SimulateOnHours 8-17 -Background
        Starts in the background with a 120-second idle threshold, operating Monday-Friday between 08:00 and 17:59.

    .EXAMPLE
        Keep-BUTCH_SystemAwake -Break
        Stops and terminates all background stay-awake instances.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. This function does not produce pipeline output objects.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.11.25 15:50
        Version: 2026.11.25.4
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>    
    [CmdletBinding(DefaultParameterSetName = 'Run')]
    param (
        [Parameter(ParameterSetName = 'Run', Position = 0, HelpMessage = "Maximum allowed idle time in seconds before triggering activity to keep the system awake.")]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxIdleSeconds = 60,

        [Parameter(ParameterSetName = 'Run', HelpMessage = "Days of week to simulate activity (1=Monday .. 7=Sunday). Example: '1,3-4,7' or '1-5'. Defaults to 1-5 in background.")]
        [string]$SimulateOnDays,

        [Parameter(ParameterSetName = 'Run', HelpMessage = "Hours of day to simulate activity (0..23). Example: '8-10,12-16' or '8-15'. Defaults to 8-15 in background.")]
        [string]$SimulateOnHours,

        [Parameter(ParameterSetName = 'Run', HelpMessage = "Run the stay-awake process in the background and return control to the console.")]
        [switch]$Background,

        [Parameter(ParameterSetName = 'Break', Mandatory = $true, HelpMessage = "Stop and terminate all background stay-awake instances.")]
        [switch]$Break
    )

    $workerMarker = 'BUTCH_KEEPAWAKE_BACKGROUND_WORKER'
    $pidDir = Join-Path $env:LOCALAPPDATA 'BUTCH'
    $pidFile = Join-Path $pidDir 'Keep-BUTCH_SystemAwake.pid'

    function Convert-ScheduleRange {
        param([string]$RangeString, [int]$MinVal, [int]$MaxVal)
        if ([string]::IsNullOrWhiteSpace($RangeString)) { return $null }
        $result = [System.Collections.Generic.HashSet[int]]::new()
        $parts = $RangeString -split ','
        foreach ($part in $parts) {
            $trimmed = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            if ($trimmed -match '^(\d+)\s*-\s*(\d+)$') {
                $start = [int]$matches[1]
                $end   = [int]$matches[2]
                if ($start -le $end) {
                    for ($i = $start; $i -le $end; $i++) {
                        if ($i -ge $MinVal -and $i -le $MaxVal) { [void]$result.Add($i) }
                    }
                }
                else {
                    for ($i = $start; $i -ge $end; $i--) {
                        if ($i -ge $MinVal -and $i -le $MaxVal) { [void]$result.Add($i) }
                    }
                }
            }
            elseif ($trimmed -match '^(\d+)$') {
                $val = [int]$matches[1]
                if ($val -ge $MinVal -and $val -le $MaxVal) { [void]$result.Add($val) }
            }
        }
        return @($result)
    }

    function Get-BackgroundInstances {
        $pids = [System.Collections.Generic.HashSet[int]]::new()

        # Check PID file if present
        if (Test-Path $pidFile) {
            $rawPid = Get-Content -Path $pidFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1
            if ($rawPid) {
                $savedPid = [int]$rawPid
                $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
                if ($proc -and ($proc.Name -match '^(powershell|pwsh)$')) {
                    [void]$pids.Add($savedPid)
                }
            }
        }

        # Query CIM for any processes running the background worker marker
        try {
            $cimProcs = Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe' OR Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
                Where-Object { ($_.ProcessId -ne $PID) -and ($_.CommandLine -like "*$workerMarker*") }
            foreach ($cp in $cimProcs) {
                [void]$pids.Add([int]$cp.ProcessId)
            }
        }
        catch {}

        # Validate that all collected PIDs are currently alive
        $alivePids = @()
        foreach ($id in $pids) {
            if (Get-Process -Id $id -ErrorAction SilentlyContinue) {
                $alivePids += $id
            }
        }

        return $alivePids
    }

    # Handle -Break: Stop all background instances
    if ($Break) {
        $runningPids = Get-BackgroundInstances
        if ($runningPids.Count -gt 0) {
            foreach ($id in $runningPids) {
                Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $pidFile) {
                Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Terminated background instance(s) of Keep-BUTCH_SystemAwake (PID: $($runningPids -join ', '))."
        }
        else {
            if (Test-Path $pidFile) {
                Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
            }
            Write-Host "No background instances of Keep-BUTCH_SystemAwake are currently running."
        }
        return
    }

    # Handle -Background: Run in background if not already running
    if ($Background) {
        $runningPids = Get-BackgroundInstances
        if ($runningPids.Count -gt 0) {
            Write-Verbose "Keep-BUTCH_SystemAwake is already running in the background (PID: $($runningPids -join ', '))."
            return
        }

        # Apply background defaults if schedule was not provided
        if ([string]::IsNullOrWhiteSpace($SimulateOnDays)) {
            $SimulateOnDays = '1-5'
        }
        if ([string]::IsNullOrWhiteSpace($SimulateOnHours)) {
            $SimulateOnHours = '8-15'
        }

        if (-not (Test-Path $pidDir)) {
            New-Item -ItemType Directory -Path $pidDir -Force | Out-Null
        }

        $powerShellExe = (Get-Process -Id $PID).Path
        if (-not $powerShellExe -or -not (Test-Path $powerShellExe)) {
            $powerShellExe = (Get-Command pwsh, powershell -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        }

        $workerScript = @'
param(
    [int]$MaxIdleSeconds = 60,
    [string]$SimulateOnDays,
    [string]$SimulateOnHours
)

function Convert-ScheduleRange {
    param([string]$RangeString, [int]$MinVal, [int]$MaxVal)
    if ([string]::IsNullOrWhiteSpace($RangeString)) { return $null }
    $result = [System.Collections.Generic.HashSet[int]]::new()
    $parts = $RangeString -split ','
    foreach ($part in $parts) {
        $trimmed = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^(\d+)\s*-\s*(\d+)$') {
            $start = [int]$matches[1]
            $end   = [int]$matches[2]
            if ($start -le $end) {
                for ($i = $start; $i -le $end; $i++) {
                    if ($i -ge $MinVal -and $i -le $MaxVal) { [void]$result.Add($i) }
                }
            }
            else {
                for ($i = $start; $i -ge $end; $i--) {
                    if ($i -ge $MinVal -and $i -le $MaxVal) { [void]$result.Add($i) }
                }
            }
        }
        elseif ($trimmed -match '^(\d+)$') {
            $val = [int]$matches[1]
            if ($val -ge $MinVal -and $val -le $MaxVal) { [void]$result.Add($val) }
        }
    }
    return @($result)
}

$allowedDays  = Convert-ScheduleRange $SimulateOnDays 1 7
$allowedHours = Convert-ScheduleRange $SimulateOnHours 0 23

$suffix = [guid]::NewGuid().ToString("N")
$sleepClassName = "SleepPreventer_$suffix"
$idleClassName = "IdleTime_$suffix"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class $sleepClassName {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);
}
"@

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class $idleClassName {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint GetIdleMilliseconds() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        GetLastInputInfo(ref lii);
        return unchecked((uint)Environment.TickCount) - lii.dwTime;
    }
}
"@

$SleepType = $sleepClassName -as [type]
$IdleType = $idleClassName -as [type]

$ES_CONTINUOUS = [uint32]::Parse("80000000", "HexNumber")
$ES_SYSTEM_REQUIRED = [uint32]::Parse("00000001", "HexNumber")
$ES_DISPLAY_REQUIRED = [uint32]::Parse("00000002", "HexNumber")
$MOUSEEVENTF_MOVE = 0x0001

$isExecutionStateSet = $false

try {
    while ($true) {
        $now = Get-Date
        $currentDay = if ($now.DayOfWeek -eq [System.DayOfWeek]::Sunday) { 7 } else { [int]$now.DayOfWeek }
        $currentHour = $now.Hour

        $isDayAllowed  = ($null -eq $allowedDays)  -or ($allowedDays -contains $currentDay)
        $isHourAllowed = ($null -eq $allowedHours) -or ($allowedHours -contains $currentHour)
        $isActiveWindow = $isDayAllowed -and $isHourAllowed

        if ($isActiveWindow) {
            if (-not $isExecutionStateSet) {
                $SleepType::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null
                $isExecutionStateSet = $true
            }

            $idleSeconds = [math]::Round($IdleType::GetIdleMilliseconds() / 1000, 1)
            if ($idleSeconds -ge $MaxIdleSeconds) {
                $SleepType::mouse_event($MOUSEEVENTF_MOVE, 0, 0, 0, 0)
                $idleSeconds = 0
            }
            Start-Sleep -Seconds 1
        }
        else {
            if ($isExecutionStateSet) {
                $SleepType::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
                $isExecutionStateSet = $false
            }
            Start-Sleep -Seconds 5
        }
    }
}
finally {
    $SleepType::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
}
'@

        $bytes = [System.Text.Encoding]::Unicode.GetBytes($workerScript)
        $base64 = [Convert]::ToBase64String($bytes)
        $workerCommand = "& ([scriptblock]::Create([System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$base64')))) -MaxIdleSeconds $MaxIdleSeconds -SimulateOnDays '$SimulateOnDays' -SimulateOnHours '$SimulateOnHours' # $workerMarker"

        $bgProcess = Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', $workerCommand) -PassThru
        if ($bgProcess) {
            Set-Content -Path $pidFile -Value $bgProcess.Id -Force
            Write-Host "Keep-BUTCH_SystemAwake started in the background (PID: $($bgProcess.Id))."
            Write-Host "Schedule: Days [$SimulateOnDays], Hours [$SimulateOnHours]." -ForegroundColor DarkGray
        }
        else {
            Write-Error "Failed to start Keep-BUTCH_SystemAwake in the background."
        }
        return
    }

    # Foreground execution
    $runningPids = Get-BackgroundInstances
    if ($runningPids.Count -gt 0) {
        Write-Warning "A background instance of Keep-BUTCH_SystemAwake is already running (PID: $($runningPids -join ', '))."
    }

    $allowedDays  = Convert-ScheduleRange $SimulateOnDays 1 7
    $allowedHours = Convert-ScheduleRange $SimulateOnHours 0 23

    $suffix = [guid]::NewGuid().ToString("N")
    $sleepClassName = "SleepPreventer_$suffix"
    $idleClassName = "IdleTime_$suffix"

    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class $sleepClassName {
            [DllImport("kernel32.dll")]
            public static extern uint SetThreadExecutionState(uint esFlags);
            
            [DllImport("user32.dll")]
            public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);
        }
"@

    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class $idleClassName {
            [StructLayout(LayoutKind.Sequential)]
            public struct LASTINPUTINFO {
                public uint cbSize;
                public uint dwTime;
            }
            [DllImport("user32.dll")]
            public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
            
            public static uint GetIdleMilliseconds() {
                LASTINPUTINFO lii = new LASTINPUTINFO();
                lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref lii);
                return unchecked((uint)Environment.TickCount) - lii.dwTime;
            }
        }
"@

    $SleepType = $sleepClassName -as [type]
    $IdleType = $idleClassName -as [type]

    $ES_CONTINUOUS = [uint32]::Parse("80000000", "HexNumber")
    $ES_SYSTEM_REQUIRED = [uint32]::Parse("00000001", "HexNumber")
    $ES_DISPLAY_REQUIRED = [uint32]::Parse("00000002", "HexNumber")
    $MOUSEEVENTF_MOVE = 0x0001

    $resetCount = 0
    $isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and ($PSBoundParameters['Verbose'] -eq $true)
    $isExecutionStateSet = $false

    try {
        while ($true) {
            $now = Get-Date
            $currentDay = if ($now.DayOfWeek -eq [System.DayOfWeek]::Sunday) { 7 } else { [int]$now.DayOfWeek }
            $currentHour = $now.Hour

            $isDayAllowed  = ($null -eq $allowedDays)  -or ($allowedDays -contains $currentDay)
            $isHourAllowed = ($null -eq $allowedHours) -or ($allowedHours -contains $currentHour)
            $isActiveWindow = $isDayAllowed -and $isHourAllowed

            if ($isActiveWindow) {
                if (-not $isExecutionStateSet) {
                    $SleepType::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null
                    $isExecutionStateSet = $true
                }

                $idleSeconds = [math]::Round($IdleType::GetIdleMilliseconds() / 1000, 1)

                if ($idleSeconds -ge $MaxIdleSeconds) {
                    $SleepType::mouse_event($MOUSEEVENTF_MOVE, 0, 0, 0, 0)
                    $resetCount++
                    $idleSeconds = 0
                }

                if ($isVerbose) {
                    $percent = [math]::Min([int](($idleSeconds / $MaxIdleSeconds) * 100), 100)
                    Write-Progress -Activity "Preventing from too long idle time" `
                        -Status "Active Schedule | Idle: $idleSeconds / $MaxIdleSeconds s | Resets: $resetCount" `
                        -PercentComplete $percent
                }

                Start-Sleep -Seconds 1
            }
            else {
                if ($isExecutionStateSet) {
                    $SleepType::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
                    $isExecutionStateSet = $false
                }

                if ($isVerbose) {
                    Write-Progress -Activity "Preventing from too long idle time" `
                        -Status "Paused (Outside schedule: Day $currentDay, Hour $currentHour`:00) | Resets: $resetCount" `
                        -PercentComplete 0
                }

                Start-Sleep -Seconds 5
            }
        }
    }
    finally {
        $SleepType::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
        if ($isVerbose) {
            Write-Progress -Activity "Preventing from too long idle time" -Completed
        }
    }
}
