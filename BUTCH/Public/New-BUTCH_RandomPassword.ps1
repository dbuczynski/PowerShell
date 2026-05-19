function New-BUTCH_RandomPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically secure random password.

    .DESCRIPTION
        This function generates a random password of a specified minimum length using a cryptographically
        secure random number generator. It supports parameters to exclude specific character classes
        (uppercase, lowercase, numbers, special characters) or similar/ambiguous characters.
        
        The output is plaintext by default, but can be returned as a SecureString.
        If called with any input objects (pipeline or parameter), it returns PSCustomObject(s) containing 
        the input and generation details.

    .PARAMETER InputObject
        An optional input object or array of objects. If provided, a password is generated for each item.
        If provided, the function returns PSCustomObject(s) matching the input and password configuration details.

    .PARAMETER Lenght
        The minimum length of the generated password. Default is 20.
        Note: The parameter name is spelled '$Lenght' to match the module specification. Alias '$Length' is supported.

    .PARAMETER ExcludeSimilar
        If set, excludes characters that are visually similar and easily confused in standard fonts:
        o, O, 0, i, I, l, L, 1, | (pipe), ` (backtick).

    .PARAMETER ExcludeUpperCase
        If set, excludes uppercase letters (A-Z) from the password.

    .PARAMETER ExcludeLowerCase
        If set, excludes lowercase letters (a-z) from the password.

    .PARAMETER ExcludeNumbers
        If set, excludes numeric digits (0-9) from the password.

    .PARAMETER ExcludeSpecial
        If set, excludes special characters from the password.

    .PARAMETER SecureString
        If set, returns the password as a System.Security.SecureString object.

    .EXAMPLE
        New-BUTCH_RandomPassword
        Generates a single random password with default settings (20 characters, all classes enabled).

    .EXAMPLE
        New-BUTCH_RandomPassword -Lenght 16 -ExcludeSimilar -SecureString
        Generates a 16-character secure string password, excluding ambiguous characters.

    .EXAMPLE
        "user1", "user2", "user3" | New-BUTCH_RandomPassword
        Generates a password for each user and outputs a list of PSCustomObjects.

    .INPUTS
        [System.Object]

    .OUTPUTS
        [System.String], [System.Security.SecureString], or [PSCustomObject]

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.19 13:55
        Version: 2026.5.19.3
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [object[]]$InputObject,

        [Parameter(Position = 1)]
        [Alias('Length')]
        [ValidateRange(1, 2048)]
        [int]$Lenght = 20,

        [Parameter()][switch]$ExcludeSimilar,
        [Parameter()][switch]$ExcludeUpperCase,
        [Parameter()][switch]$ExcludeLowerCase,
        [Parameter()][switch]$ExcludeNumbers,
        [Parameter()][switch]$ExcludeSpecial,
        [Parameter()][switch]$SecureString
    )

    BEGIN {
        # Check if Init-BUTCH was executed
        $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($isInit -ne $true) {
            Write-Warning "Module is not initialized! Please run Init-BUTCH first."
        }

        # Initialize results storage
        $script:InputItems = [System.Collections.Generic.List[object]]::new()
        $script:Results = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Define character pools
        $upperPool   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $lowerPool   = "abcdefghijklmnopqrstuvwxyz"
        $numberPool  = "0123456789"
        $specialPool = "!@#$%^&*()_+-=[]{}|;:',.<>/?~"

        # Apply ExcludeSimilar if specified
        if ($ExcludeSimilar) {
            # o, O, 0, i, I, l, L, 1 are explicitly requested.
            # | (pipe) and ` (backtick) are also excluded as they cause reading issues.
            $similarChars = @('o', 'O', '0', 'i', 'I', 'l', 'L', '1', '|', '`')
            foreach ($char in $similarChars) {
                $upperPool   = $upperPool.Replace($char, '')
                $lowerPool   = $lowerPool.Replace($char, '')
                $numberPool  = $numberPool.Replace($char, '')
                $specialPool = $specialPool.Replace($char, '')
            }
        }

        # Build list of active pools for complexity enforcement
        $activePools = [System.Collections.Generic.List[string]]::new()
        if (-not $ExcludeUpperCase) { $activePools.Add($upperPool) }
        if (-not $ExcludeLowerCase) { $activePools.Add($lowerPool) }
        if (-not $ExcludeNumbers)   { $activePools.Add($numberPool) }
        if (-not $ExcludeSpecial)   { $activePools.Add($specialPool) }

        if ($activePools.Count -eq 0) {
            Throw "All character classes are excluded. Cannot generate a password."
        }

        # Combine active pools into a joint pool
        $jointPool = -join $activePools

        # Initialize RNGCryptoServiceProvider/RandomNumberGenerator
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

        # Helper function for generating secure random integers in range [0, Max-1]
        # Uses rejection sampling to avoid modulo bias
        function Get-SecureRandomInt {
            param([int]$Max)
            $bytes = [byte[]]::new(4)
            while ($true) {
                $rng.GetBytes($bytes)
                $val = [BitConverter]::ToUInt32($bytes, 0)
                $limit = [uint32]::MaxValue - ([uint32]::MaxValue % $Max)
                if ($val -lt $limit) {
                    return ($val % $Max)
                }
            }
        }

        # Helper to convert plain string to SecureString
        function ConvertTo-SecureStringHelper {
            param([string]$Plain)
            $sec = [System.Security.SecureString]::new()
            foreach ($c in $Plain.ToCharArray()) {
                $sec.AppendChar($c)
            }
            $sec.MakeReadOnly()
            return $sec
        }

        # Helper to set default display properties on PSCustomObject
        function Set-DefaultDisplayProperties {
            param([PSCustomObject]$Object)
            $defaultDisplaySet = @('InputObject', 'Password', 'SecuredPassword')
            $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
            $Object | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -Force | Out-Null
            return $Object
        }

        # Helper to generate a single password
        function New-SinglePassword {
            # Ensure length is at least the number of active pools to guarantee complexity
            $len = $Lenght
            if ($len -lt $activePools.Count) {
                $len = $activePools.Count
            }

            while ($true) {
                $chars = [System.Collections.Generic.List[char]]::new()

                # 1. Guarantee complexity by selecting 1 character from each active pool
                foreach ($pool in $activePools) {
                    $idx = Get-SecureRandomInt -Max $pool.Length
                    $chars.Add($pool[$idx])
                }

                # 2. Fill the rest of the password length from the joint pool
                while ($chars.Count -lt $len) {
                    $idx = Get-SecureRandomInt -Max $jointPool.Length
                    $chars.Add($jointPool[$idx])
                }

                # 3. Shuffle characters securely using Fisher-Yates shuffle
                $shuffled = [System.Collections.Generic.List[char]]::new($chars)
                for ($i = $shuffled.Count - 1; $i -gt 0; $i--) {
                    $j = Get-SecureRandomInt -Max ($i + 1)
                    $temp = $shuffled[$i]
                    $shuffled[$i] = $shuffled[$j]
                    $shuffled[$j] = $temp
                }

                $candidate = -join $shuffled

                # 4. Verify password quality against active pools
                $valid = $true
                if (-not $ExcludeUpperCase -and $candidate.IndexOfAny($upperPool.ToCharArray()) -lt 0) { $valid = $false }
                if (-not $ExcludeLowerCase -and $candidate.IndexOfAny($lowerPool.ToCharArray()) -lt 0) { $valid = $false }
                if (-not $ExcludeNumbers   -and $candidate.IndexOfAny($numberPool.ToCharArray()) -lt 0) { $valid = $false }
                if (-not $ExcludeSpecial   -and $candidate.IndexOfAny($specialPool.ToCharArray()) -lt 0) { $valid = $false }

                if ($valid) {
                    return $candidate
                }
            }
        }
    }

    PROCESS {
        if ($null -ne $InputObject) {
            foreach ($item in $InputObject) {
                if ($null -ne $item) {
                    $script:InputItems.Add($item)
                    $pass = New-SinglePassword

                    # Output details matching user request:
                    # * dla SecureString -eq $false: {wartość z input}, Password, SecuredPassword = (SecureString), ...
                    # * dla SecureString -eq $true: {wartość z input}, Password = $null, SecuredPassword, ...
                    if ($SecureString) {
                        $plainPass = $null
                        $securedPass = ConvertTo-SecureStringHelper $pass
                    }
                    else {
                        $plainPass = $pass
                        $securedPass = ConvertTo-SecureStringHelper $pass
                    }

                    $result = [PSCustomObject]@{
                        InputObject      = $item
                        Password         = $plainPass
                        SecuredPassword  = $securedPass
                        Lenght           = $Lenght
                        ExcludeUpperCase = $ExcludeUpperCase
                        ExcludeLowerCase = $ExcludeLowerCase
                        ExcludeNumbers   = $ExcludeNumbers
                        ExcludeSpecial   = $ExcludeSpecial
                        ExcludeSimilar   = $ExcludeSimilar
                    }
                    $result = Set-DefaultDisplayProperties -Object $result
                    $script:Results.Add($result)
                }
            }
        }
    }

    END {
        # Clean up RNG resource
        if ($null -ne $rng) {
            $rng.Dispose()
        }

        if ($script:InputItems.Count -eq 0) {
            # Self-standing execution
            $pass = New-SinglePassword
            Write-Information -MessageData ("Randomly generated password: " + $pass) -InformationAction Continue
            if ($SecureString) {
                return ConvertTo-SecureStringHelper $pass
            }
            else {
                return $pass
            }
        }
        elseif ($script:InputItems.Count -eq 1) {
            # Single element pipeline/parameter execution
            return $script:Results[0]
        }
        else {
            # Array execution - return the array of PSCustomObjects
            return $script:Results.ToArray()
        }
    }
}
