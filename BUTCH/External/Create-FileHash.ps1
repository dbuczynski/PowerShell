<#
.SYNOPSIS
    This script creates Hash-* files of files in a given folder which are not digitally signed
    
.DESCRIPTION
    This script creates Hash-* files of files in a given folder which are not digitally signed

.OUTPUTS
    Logging only in PowerShell window

.PARAMETER Path
    Folder with files to check for digitally signatures and building hashes.

.PARAMETER SignatureAlgorithm
    Optional Parameter for the Signature Algorithm used for building filehashes.

.EXAMPLE
    .\Create-FileHash.ps1 -Path C:\FilesToCheck -SignatureAlgorithm SHA256

.NOTES
    Authors
        [BS] Björn Schiemann
        
    2021-01-21, version 1.1

    The sample scripts provided here are not supported under any Microsoft
    standard support program or service. All scripts are provided AS IS without
    warranty of any kind. Microsoft further disclaims all implied warranties stop
    including, without limitation, any implied warranties of merchantability or
    of fitness for a particular purpose. The entire risk arising out of the use
    or performance of the sample scripts and documentation remains with you. In
    no event shall Microsoft, its authors, or anyone else involved in the
    creation, production, or delivery of the scripts be liable for any damages
    whatsoever (including, without limitation, damages for loss of business
    profits, business interruption, loss of business information, or other
    pecuniary loss) arising out of the use of or inability to use the sample
    scripts or documentation, even if Microsoft has been advised of the
    possibility of such damages.
#>

#region Parameters
param(
    [ValidateScript({
        if( -Not ($_ | Test-Path ) ){
            throw "File or folder does not exist"
        }
        return $true
    })]
    [parameter(Mandatory = $true)]
    [string]$Path,

    [ValidateSet('MD5','SHA1','SHA256','SHA384','SHA512')]
    $SignatureAlgorithm = 'SHA256'
)
#endregion Parameters

#region Functions
#========================================================================

Function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [String]$LogText,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Title1', 'Title2')]
        [String]$Type = 'Info',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('White', 'Yellow', 'Red', 'Cyan', 'Green', 'Grey', 'DarkYellow', 'DarkGray', 'Magenta')]
        [String]$Color = '',
        
        [Parameter(Mandatory=$false)]
        [Switch]$NoNewline = $false
    )
    
    $colors = @{
        'info' = [System.ConsoleColor]::DarkGray
        'error' = [System.ConsoleColor]::Red
        'warning' = [System.ConsoleColor]::Yellow
        'success' = [System.ConsoleColor]::Green
        'title1' = [System.ConsoleColor]::Magenta
        'title2' = [System.ConsoleColor]::Cyan
    }
    
    $logDate = "[$((get-date -format "yyyy-MM-dd HH:mm:ss"))] - "
    if ($script:logininitialized -eq $false) {
        $script:logininitialized = $True
        if (-not (Test-Path $Script:LogfilePath)) { New-Item -ItemType Directory -Force -Path $Script:LogfilePath }
        if (-not (Test-Path $Script:Logfile)) { $Script:FileHeader > $Script:Logfile }
        # Delete old Logfiles
        $DateToDelete = (Get-Date).AddDays(-$Script:DeleteLogsOlderThanDays)
        $LogfileList = Get-ChildItem "$($Script:LogfilePath)\*" -file -Include "*.$($LogfileName.Split('.')[-1])"
        foreach ($LogFile in $LogFileList) {
            If ($LogFile.LastWriteTime -lt $DateToDelete) {
                Write-Log "Remove old Logfile $($LogFile.Name)"
                Remove-Item $LogFile.FullName -Force
            }
        }
    }
    
    if (($colors.ContainsKey($Type)) -and ($color -eq '')) {
        $color = $colors[$Type]
    }
    
    $LinePrefix = $logDate + "[$Type]"
    Write-Host "$LinePrefix $LogText" -ForegroundColor $Color -NoNewline:$NoNewline
}

#========================================================================
Function Test-FileHashAndCreate {
    #====================================================================
    [CmdletBinding()]
    param (
        [Parameter()]
        $File
    )
    
    if ($File.Name -like "HASH-*") {
        #"HASH-*" files cannot get hashes"
        Return
    }
    
    # Check if File has valid digital signature
    # If not, hash file has to be created.
    $FileFullName = $File.FullName
    $DigSig = Get-AuthenticodeSignature -FilePath $FileFullName
    
    If ($DigSig.SignatureType -ieq 'None') {
        $DigSigFileStatus = 'NotSigned'
    } Else {
        $DigSigFileStatus = $DigSig.Status
    }
    
    switch ($DigSigFileStatus) {
        'Valid' {
            Write-LOG "Certificate Subject: $($DigSig.SignerCertificate.Subject)"
            Write-LOG "Certificate Issuer: $($DigSig.SignerCertificate.Issuer)"
            Write-LOG "$($File.Name) has a valid digital signature." -Type Success
            Return $True
        }
        'HashMismatch' {
            Write-LOG "$($File.Name) The hash of the file does not match the hash stored along with the signature." -Type Error
            Write-LOG "File has changed after signing! -- Manuell INVESTIGATION NEEDED!" -Type Error
            Return $False
        }
        'NotSigned' {
            Write-LOG "$($File.Name) has no digital signature."
        }
        Default {
            Write-LOG "Certificate Subject: $($DigSig.SignerCertificate.Subject)"
            Write-LOG "Certificate Issuer: $($DigSig.SignerCertificate.Issuer)"
            Write-LOG "$($File.Name) has a non valid digital signature. Signature Message: $($DigSig.StatusMessage)" -Type Warning
        }
    }
    
    Write-Log "Hash comparison needed."
    $HashFileName = "HASH-" + $File.Name + ".csv"
    Write-LOG "Hash file: $HashFileName"
    $HashFileFullName = Join-Path (Split-Path $FileFullName) $HashFileName
    $HashTimeStamp = get-Date -Format "yyyyMMddTHH:mm:ss"

    # If there is already a HASH-file, no new HASH has to be created.
    if (-not(Test-Path $HashFileFullName)) {
        Write-LOG "Creating CSV HASH file."
        $CalculatedHash = Get-FileHash $FileFullName -Algorithm $SignatureAlgorithm
        Write-LOG "Calculated Hash: $($SignatureAlgorithm): $($CalculatedHash.Hash)"
        $FileLastChangeTime = ([DateTime]$File.LastWriteTimeUtc).ToString("yyyyMMddTHH:mm:ss")
        Set-Content -Path $HashFileFullName -Value '"FileName","Hash","Algorithm","FileLastChanged","HashTimestamp"'
        $CSVContent = @(
            "$($file.Name),$($CalculatedHash.Hash),$($CalculatedHash.Algorithm),$($FileLastChangeTime),$($HashTimeStamp)"
        )
        $CSVContent | ForEach-Object { Add-content -path $HashFileFullName -Value $_ }
        Write-LOG "HASH file created." -Type Success
    }
    else {
        # Check and log existing hash files
        $HashCSV = Import-Csv $HashFileFullName
        if ($($HashCSV.FileName) -ieq $($File.Name)) {
            #Hash verification
            $CalculatedHash = Get-FileHash $FileFullName -Algorithm $HashCSV.Algorithm
            if ($($HashCSV.Hash) -eq $($CalculatedHash.Hash)) {
                #Read info and Log it.
                Write-LOG "Hash file already exists. Hash file INFO:" -Type Success
                Write-LOG "File Name          : $($HashCSV.FileName)"
                Write-LOG "Hash Value         : $($HashCSV.Algorithm): $($HashCSV.Hash)"
                Write-LOG "FileLastChanged: $($HashCSV.FileLastChanged)"
                Write-LOG "HashTimeStamp  : $($HashCSV.HashTimestamp)"
            } else {
                Write-LOG "##### HASH WRONG! -- Manuell INVESTIGATION NEEDED! ####" -Type Error
                $HashFileNew = "HASH-ERROR-" + $File.Name + ".csv"
                Write-LOG "Calculated Hash: $($HashCSV.Algorithm): $($CalculatedHash.Hash)"
                Write-LOG "Hash from file : $($HashCSV.Algorithm): $($HashCSV.Hash)"
                Move-Item $HashFileFullName -Destination (Join-Path (Split-Path $HashFileFullName) $HashFileNew) -Force
            }
        }
    }
}

function New-MasterHashTable {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path,
        [string]$HashMasterTable
    )
    
    if (Test-Path $HashMasterTable) {Remove-Item $HashMasterTable -Force}
    foreach ($File in (Get-ChildItem $Path -File -Filter 'HASH-*.csv')) {
        Import-Csv $File.FullName | Export-Csv $HashMasterTable -Append -NoTypeInformation
    }
}
#========================================================================
#endregion Functions

#region MAIN
#========================================================================
if ( Test-Path $path -PathType Leaf ) {
    Write-Log "Start checking file: $path" -Type Title1
    Test-FileHashAndCreate -File (Get-Item -path $path) | Out-Null
    $path = split-Path $Path -Parent
} else {
    Write-Log "Start checking all files from folder: $path" -Type Title1
    foreach ($File in (Get-ChildItem $Path -File)) {
        Write-Log "File: $($File.name)"
        Test-FileHashAndCreate -File $File | Out-Null
    }
}

$HashMasterTable = Join-Path $Path 'Hash-##MasterTable.csv'
Write-Log "Creating Hash Master Table $HashMasterTable" -Type Title2
New-MasterHashTable -Path $Path -HashMasterTable $HashMasterTable
Write-LOG "#### Script finished." -Type Title1
#endregion MAIN
