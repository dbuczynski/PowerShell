function New-BUTCH_ADAccount {
    <#
    .SYNOPSIS
        Creates an administrative AD-UI account based on an existing UI account and prepares an Outlook notification email.

    .DESCRIPTION
        This function creates a new administrative user account prefixed with 'AD-' in Active Directory
        based on an existing user account in the 'energy.local' domain.

        It runs with elevated credentials configured via Initialize-BUTCH (or explicitly supplied via -Credential),
        allowing standard users to execute it securely.

        The function performs the following steps:
        1. Validates privileged credentials from Initialize-BUTCH.
        2. Validates the target Organizational Unit (-Path or from Initialize-BUTCH) exists in AD.
        3. Validates that the target account 'AD-<Identity>' does not already exist.
        4. Validates the existence and readability of the Outlook mail template (-MailTemplate or from Initialize-BUTCH).
        5. Validates the sender signature (-Signature or from Initialize-BUTCH).
        6. Obtains a plaintext password (provided or generated via New-BUTCH_RandomPassword) and converts it to a SecureString.
        7. Creates the new user in AD copying custom attributes (extensionAttribute4, extensionAttribute5, rweIDAMrcd).
        8. Creates an Outlook email item from the specified template, sets confidentiality to strictly confidential,
           replaces %ADACCOUNT%, %ADPASSWORD%, and signature placeholders, sets the subject to 'XXX - New AD- Account',
           and saves the email as a draft without sending.

        Supports -WhatIf to simulate account creation and email drafting without applying changes.

    .PARAMETER Identity
        The base UI account name/SAMAccountName (e.g., 'UI123456').

    .PARAMETER RequestItemNumber
        The ServiceNow Request Item number (e.g., 'RITM1234567').
        Aliases: 'RITM', 'RequestItem'.

    .PARAMETER PlainPassword
        The plaintext password to assign to the new administrative account.
        Alias: 'Password'.

    .PARAMETER GeneratePassword
        Switch to generate a cryptographically secure random password automatically via New-BUTCH_RandomPassword.

    .PARAMETER Path
        Optional Active Directory OU path where the new account will be created.
        If omitted, the value configured in Initialize-BUTCH (ADAccountPath) is used.

    .PARAMETER MailTemplate
        Optional path to the Outlook mail template file (.oft, .html, or .txt).
        If omitted, the value configured in Initialize-BUTCH (MailTemplate) is used.

    .PARAMETER Signature
        Optional sender name/signature to use in the mail template.
        If omitted, the value configured in Initialize-BUTCH (Signature) is used.

    .PARAMETER Credential
        Optional privileged PSCredential object. If omitted, credentials configured in Initialize-BUTCH are used.

    .EXAMPLE
        New-BUTCH_ADAccount -Identity "UI123456" -RequestItemNumber "RITM0012345" -GeneratePassword
        Creates account 'AD-UI123456' with a generated password and prepares the Outlook email.

    .EXAMPLE
        New-BUTCH_ADAccount -Identity "UI123456" -RITM "RITM0012345" -Password "Secur3dP@ssw0rd!"
        Creates account 'AD-UI123456' with a specified password.

    .EXAMPLE
        New-BUTCH_ADAccount -Identity "UI123456" -RITM "RITM0012345" -GeneratePassword -Path "OU=Users,OU=Admins,DC=energy,DC=local" -WhatIf
        Simulates account creation and email drafting without making any changes in Active Directory or Outlook.

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.String]
        Returns a confirmation summary of the created account and password.

    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.11.25 15:50
        Version: 2026.11.25.4
        License: MIT
        This function is a part of the BUTCH PowerShell module.

    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>

    [CmdletBinding(DefaultParameterSetName = 'ProvidedPassword', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The base UI account name (e.g., UI123456).")]
        [string]$Identity,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "ServiceNow Request Item Number (e.g., RITM1234567).")]
        [Alias('RITM', 'RequestItem')]
        [string]$RequestItemNumber,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ProvidedPassword', HelpMessage = "Plaintext password for the new account.")]
        [Alias('Password')]
        [string]$PlainPassword,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'GeneratePassword', HelpMessage = "Generate a secure random password automatically.")]
        [switch]$GeneratePassword,

        [Parameter(Position = 3, HelpMessage = "Active Directory OU path where the new account will be created. Defaults to OU configured in Initialize-BUTCH.")]
        [Alias('OU', 'ADAccountPath', 'ADPath')]
        [string]$Path,

        [Parameter(Position = 4, HelpMessage = "Path to the Outlook mail template (.oft, .html, .txt). Defaults to template configured in Initialize-BUTCH.")]
        [Alias('Template', 'MailTemplatePath')]
        [string]$MailTemplate,

        [Parameter(Position = 5, HelpMessage = "Sender signature name to use in the mail template. Defaults to signature configured in Initialize-BUTCH.")]
        [Alias('SignedBy')]
        [string]$Signature,

        [Parameter(HelpMessage = "Privileged Active Directory credential. If omitted, credentials from Initialize-BUTCH are used.")]
        [pscredential]$Credential
    )

    begin {
        $FunctionName = $MyInvocation.MyCommand.Name

        # 1. Resolve privileged credentials from Initialize-BUTCH if not provided
        if (-not $Credential) {
            $isInit = Get-Variable -Name 'BUTCH_IsInitialized' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if ($isInit -ne $true) {
                throw "BUTCH module is not initialized! Please run Initialize-BUTCH first to configure elevated credentials, or pass -Credential."
            }

            $username = Get-Variable -Name 'BUTCH_Username' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            $password = Get-Variable -Name 'BUTCH_Password' -Scope Script -ValueOnly -ErrorAction SilentlyContinue

            if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
                throw "Privileged credentials from Initialize-BUTCH are empty or missing. Please run Initialize-BUTCH."
            }

            $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($username, $secPassword)
        }

        # 2. Resolve Path parameter or retrieve from Init-BUTCH
        if ([string]::IsNullOrWhiteSpace($Path)) {
            $Path = Get-Variable -Name 'BUTCH_ADAccountPath' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        }
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "Path parameter is missing and no default ADAccountPath is configured in Initialize-BUTCH."
        }

        # 3. Verify that the OU exists in Active Directory using privileged credentials
        try {
            $ouObject = Get-ADOrganizationalUnit -Identity $Path -Credential $Credential -ErrorAction Stop
            Write-Verbose "$FunctionName Verified OU exists: $Path"
        }
        catch {
            throw "The specified Organizational Unit path '$Path' does not exist in Active Directory or access was denied. Error: $_"
        }

        # 4. Check if user AD-$Identity already exists in Active Directory
        $ADAccount = "AD-" + $Identity
        try {
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$ADAccount'" -Credential $Credential -ErrorAction Stop
            if ($null -ne $existingUser) {
                throw "User account '$ADAccount' already exists in Active Directory."
            }
            Write-Verbose "$FunctionName Verified that '$ADAccount' does not already exist."
        }
        catch {
            if ($_.Exception.Message -like "*already exists*") {
                throw
            }
            throw "Failed to query Active Directory for existing account '$ADAccount': $_"
        }

        # 5. Resolve and validate Signature parameter or retrieve from Init-BUTCH
        if ([string]::IsNullOrWhiteSpace($Signature)) {
            $Signature = Get-Variable -Name 'BUTCH_Signature' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        }
        if ([string]::IsNullOrWhiteSpace($Signature)) {
            throw "Signature parameter is missing and no default Signature is configured in Initialize-BUTCH."
        }
        Write-Verbose "$FunctionName Using signature: $Signature"

        # 6. Resolve and validate MailTemplate parameter or retrieve from Init-BUTCH
        if ([string]::IsNullOrWhiteSpace($MailTemplate)) {
            $MailTemplate = Get-Variable -Name 'BUTCH_MailTemplate' -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        }
        if ([string]::IsNullOrWhiteSpace($MailTemplate)) {
            throw "MailTemplate parameter is missing and no default MailTemplate is configured in Initialize-BUTCH."
        }
        if (-not (Test-Path -Path $MailTemplate -PathType Leaf)) {
            throw "Mail template file does not exist at path: '$MailTemplate'."
        }
        try {
            $fileStream = [System.IO.File]::OpenRead((Resolve-Path $MailTemplate).Path)
            $fileStream.Close()
            Write-Verbose "$FunctionName Verified mail template file exists and is readable: $MailTemplate"
        }
        catch {
            throw "Mail template file at '$MailTemplate' cannot be read. Error: $_"
        }

        # 7. Obtain plaintext password and convert to SecureString
        if ($GeneratePassword) {
            Write-Verbose "$FunctionName Generating password via New-BUTCH_RandomPassword"
            $plainTextPassword = New-BUTCH_RandomPassword
            $SecuredPassword   = ConvertTo-SecureString -AsPlainText $plainTextPassword -Force
        }
        elseif ($PlainPassword) {
            Write-Verbose "$FunctionName Using password provided via parameter"
            $plainTextPassword = $PlainPassword
            $SecuredPassword   = ConvertTo-SecureString -AsPlainText $plainTextPassword -Force
        }
        else {
            throw "Missing password. Please provide -PlainPassword or use -GeneratePassword."
        }

        # 8. Retrieve source base user data from Active Directory
        try {
            $Account = Get-ADUser -Identity $Identity -Properties * -Credential $Credential -ErrorAction Stop
            Write-Verbose "$FunctionName Retrieved base user data for '$Identity'."
        }
        catch {
            throw "Failed to collect data about source user '$Identity' from Active Directory: $_"
        }
    }

    process {
        $ADName = $Account.Surname + ', ' + $Account.GivenName + ' (' + $ADAccount + ')'
        $ADUserPrincipalName = $ADAccount + '@energy.local'

        if ($PSCmdlet.ShouldProcess("Target: '$ADAccount' in '$Path'", "Create Active Directory Account")) {
            New-ADUser -SamAccountName $ADAccount `
                -Name $ADName `
                -Surname $Account.Surname `
                -GivenName $Account.GivenName `
                -Path $Path `
                -AccountPassword $SecuredPassword `
                -ChangePasswordAtLogon $false `
                -Enabled $true `
                -DisplayName $ADName `
                -UserPrincipalName $ADUserPrincipalName `
                -Manager $Account.SAMAccountName `
                -Credential $Credential

            $addAttributes = @{}
            if ($Account.extensionAttribute4) { $addAttributes['extensionAttribute4'] = $Account.extensionAttribute4 }
            if ($Account.extensionAttribute5) { $addAttributes['extensionAttribute5'] = $Account.extensionAttribute5 }
            if ($Account.rweIDAMrcd)          { $addAttributes['rweIDAMrcd']          = $Account.rweIDAMrcd }

            if ($addAttributes.Count -gt 0) {
                Set-ADUser -Identity $ADAccount -Add $addAttributes -Credential $Credential
            }

            Write-Verbose "$FunctionName Account '$ADAccount' created successfully in '$Path'."
        }
    }

    end {
        $outPut = "User $ADAccount created with password $plainTextPassword"

        # Prepare Outlook email from template
        if ($PSCmdlet.ShouldProcess("Draft email for '$ADAccount' ($RequestItemNumber)", "Prepare Outlook Email")) {
            try {
                $outlook = New-Object -ComObject Outlook.Application
                $resolvedTemplate = (Resolve-Path $MailTemplate).Path

                if ($resolvedTemplate -like "*.oft") {
                    $mail = $outlook.CreateItemFromTemplate($resolvedTemplate)
                }
                else {
                    $mail = $outlook.CreateItem(0) # 0 = olMailItem
                    $content = Get-Content -Path $resolvedTemplate -Raw -Encoding UTF8
                    if ($resolvedTemplate -match '\.html?$') {
                        $mail.HTMLBody = $content
                    }
                    else {
                        $mail.Body = $content
                    }
                }

                # Set Subject to "XXX - New AD- Account"
                $mail.Subject = "$RequestItemNumber - New AD- Account"

                # Set Recipient if not defined in template
                if ([string]::IsNullOrWhiteSpace($mail.To)) {
                    if ($Account.Mail) {
                        $mail.To = $Account.Mail
                    }
                    elseif ($Account.UserPrincipalName) {
                        $mail.To = $Account.UserPrincipalName
                    }
                }

                # Replace placeholders in HTMLBody
                if ($mail.HTMLBody) {
                    $mail.HTMLBody = $mail.HTMLBody -replace '%ADACCOUNT%', $ADAccount `
                                                    -replace '%ADPASSWORD%', $plainTextPassword
                    if ($mail.HTMLBody -match '%SIGNATURE%') {
                        $mail.HTMLBody = $mail.HTMLBody -replace '%SIGNATURE%', $Signature
                    }
                    elseif ($mail.HTMLBody -match 'Daniel Buczy[ńn]ski') {
                        $mail.HTMLBody = $mail.HTMLBody -replace 'Daniel Buczy[ńn]ski', $Signature
                    }
                }

                # Replace placeholders in Body
                if ($mail.Body) {
                    $mail.Body = $mail.Body -replace '%ADACCOUNT%', $ADAccount `
                                            -replace '%ADPASSWORD%', $plainTextPassword
                    if ($mail.Body -match '%SIGNATURE%') {
                        $mail.Body = $mail.Body -replace '%SIGNATURE%', $Signature
                    }
                    elseif ($mail.Body -match 'Daniel Buczy[ńn]ski') {
                        $mail.Body = $mail.Body -replace 'Daniel Buczy[ńn]ski', $Signature
                    }
                }

                # Set Confidentiality level: strictly confidential (olConfidential = 3)
                $mail.Sensitivity = 3

                # Save email as draft (do NOT send)
                $mail.Save()
                Write-Verbose "$FunctionName Outlook email prepared and saved to Drafts."
            }
            catch {
                Write-Warning "$FunctionName Failed to interact with Outlook application or template: $_"
            }
        }

        Write-Verbose "$FunctionName $outPut"
        return $outPut
    }
}
