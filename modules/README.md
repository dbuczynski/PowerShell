# PowerShell Modules

This directory contains standalone, fully structured PowerShell modules. Each subfolder here represents a distinct module that can be installed and imported into your PowerShell environment.

## Available Modules

| Module Name | Description |
| :--- | :--- |
| **[`BUTCH`](./BUTCH/)** | A specialized administrative module containing utilities for Active Directory, BitLocker recovery, and transcript logging. Designed with secure, stateful credentials handling. |

## Adding Future Modules
When adding new modules in the future, follow the established pattern:
1. Create a folder named after the module.
2. Inside, include a `.psd1` manifest and a `.psm1` root script.
3. Separate functions into `Public` (exported) and `Private` (internal) folders.
4. Update this README table to document the new module.
