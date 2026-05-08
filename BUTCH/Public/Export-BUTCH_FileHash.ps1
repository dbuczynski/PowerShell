function Export-BUTCH_FileHash {
    <#
    .SYNOPSIS
        Copies a file to a temporary location, generates its hash (CSV), and moves both to a destination path simultaneously.
    
    .DESCRIPTION
        This function takes one or more files from the pipeline. For each file, it copies the file to a temporary folder, 
        calculates its SHA256 hash (or other supported algorithm) along with its digital signature status, and generates a CSV hash file.
        It then copies both the file and the CSV hash file to the initialized BUTCH_HashDestinationPath. 
        Temporary files are automatically cleaned up.

    .PARAMETER Path
        The path to the file(s) to process. Accepts pipeline input.

    .PARAMETER SignatureAlgorithm
        The hashing algorithm to use. Defaults to 'SHA256'.

    .EXAMPLE
        "C:\temp\installer.exe" | Export-BUTCH_FileHash
        Processes installer.exe, generates its hash, and moves it to the module's defined destination path.

    .INPUTS
        [System.String[]]

    .OUTPUTS
        [PSCustomObject]
        Returns a summary object indicating success or failure for each processed file.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.5.4 15:00
        Version: 2026.5.8.4
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File does not exist or is a directory: $_"
            }
            return $true
        })]
        [string[]]$Path,

        [ValidateSet('MD5','SHA1','SHA256','SHA384','SHA512')]
        [string]$SignatureAlgorithm = 'SHA256'
    )

    BEGIN {
        if (-not $script:BUTCH_IsInitialized) {
            Write-Warning "Module is not initialized! Please run Init-BUTCH first."
            break
        }

        if ([string]::IsNullOrWhiteSpace($script:BUTCH_HashDestinationPath)) {
            Write-Warning "BUTCH_HashDestinationPath is not set. Please run Init-BUTCH and provide the destination path."
            break
        }

        if (-not (Test-Path $script:BUTCH_HashDestinationPath)) {
            try {
                New-Item -ItemType Directory -Path $script:BUTCH_HashDestinationPath -Force | Out-Null
            }
            catch {
                Write-Warning "Could not access or create destination path: $($script:BUTCH_HashDestinationPath)"
                break
            }
        }

        $Summary = @()
    }

    PROCESS {
        foreach ($File in $Path) {
            $FileItem = Get-Item -Path $File
            
            # Skip if it's already a hash file
            if ($FileItem.Name -like "HASH-*") {
                Write-Verbose "Skipping file $($FileItem.Name) as it is already a hash file."
                continue
            }

            try {
                # Create unique temp folder
                $TempFolder = Join-Path $env:TEMP ("BUTCH_HASH_" + [guid]::NewGuid().ToString().Substring(0,8))
                New-Item -ItemType Directory -Path $TempFolder | Out-Null

                # Copy file to temp folder
                $TempFile = Join-Path $TempFolder $FileItem.Name
                Copy-Item -Path $FileItem.FullName -Destination $TempFile -Force

                # Calculate Signature
                $DigSig = Get-AuthenticodeSignature -FilePath $TempFile
                
                # Calculate Hash
                $CalculatedHash = Get-FileHash $TempFile -Algorithm $SignatureAlgorithm
                $FileLastChangeTime = ([DateTime]$FileItem.LastWriteTimeUtc).ToString("yyyyMMddTHH:mm:ss")
                $HashTimeStamp = Get-Date -Format "yyyyMMddTHH:mm:ss"

                # Generate CSV content
                $HashFileName = "HASH-" + $FileItem.Name + ".csv"
                $TempHashFile = Join-Path $TempFolder $HashFileName
                
                Set-Content -Path $TempHashFile -Value '"FileName","Hash","Algorithm","FileLastChanged","HashTimestamp"'
                $CSVLine = "$($FileItem.Name),$($CalculatedHash.Hash),$($CalculatedHash.Algorithm),$($FileLastChangeTime),$($HashTimeStamp)"
                Add-Content -Path $TempHashFile -Value $CSVLine

                # Copy BOTH files simultaneously (as close as possible) to the destination
                Write-Verbose "Copying files to destination: $($script:BUTCH_HashDestinationPath)"
                Copy-Item -Path "$TempFolder\*" -Destination $script:BUTCH_HashDestinationPath -Force

                # Cleanup temp folder
                Remove-Item -Path $TempFolder -Recurse -Force

                $Summary += [PSCustomObject]@{
                    FileName         = $FileItem.Name
                    SourcePath       = $FileItem.FullName
                    DestinationPath  = $script:BUTCH_HashDestinationPath
                    Algorithm        = $SignatureAlgorithm
                    Hash             = $CalculatedHash.Hash
                    SignatureStatus  = if ($DigSig.SignatureType -ieq 'None') { 'NotSigned' } else { $DigSig.Status }
                    Status           = "Success"
                }
            }
            catch {
                Write-Error "Failed processing $($FileItem.Name): $_"
                $Summary += [PSCustomObject]@{
                    FileName         = $FileItem.Name
                    SourcePath       = $FileItem.FullName
                    DestinationPath  = $script:BUTCH_HashDestinationPath
                    Algorithm        = $SignatureAlgorithm
                    Hash             = $null
                    SignatureStatus  = $null
                    Status           = "Failed"
                }

                # Cleanup temp on error
                if (Test-Path $TempFolder) {
                    Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    END {
        return $Summary
    }
}
