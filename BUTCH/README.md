# BUTCH PowerShell Module

The **BUTCH** module is a custom administrative toolkit for PowerShell. It uses a secure, script-scoped state (`Init-BUTCH`) to retain credentials during a session, eliminating the need to repeatedly prompt for authentication when running AD queries or accessing network resources.

## 🚀 Easy Installation (No Download Required)

You don't need to manually download or clone the repository to use this module! Simply open your PowerShell console and run the automated installer one-liner:

```powershell
irm https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1 | iex
```

*This command downloads the latest version, extracts it to your user's standard `Modules` directory, and automatically imports it.*

## ⚙️ Features & Functions

Once imported, the module greets you with a customized banner and registers the following commands:

- **`Initialize-BUTCH`** (Alias: `Init-BUTCH`) - securely prompts for and stores AD credentials and parameters in the module's state. Run this first!
- **`Clear-BUTCH`** (Alias: `Reset-BUTCH`) - securely wipes the stored credentials from memory.
- **`Get-BUTCH_BitLockerRecoveryKey`** - Queries Active Directory for msFVE-RecoveryInformation.
- **`Test-BUTCH_AdCredentials`** - Verifies if AD credentials are correct via System.DirectoryServices.AccountManagement.
- **`Start-BUTCH_Transcript`** (Alias: `ST`) - Easily manages logging sessions, saving output securely to your Desktop.

## Structure
- **[`Public/`](./Public/)** - Contains the functions that are exported and visible to the user.
- **[`Private/`](./Private/)** - Contains testing scripts and internal functions not exported to the user.

## License
MIT License. See individual script `.NOTES` sections for details.
