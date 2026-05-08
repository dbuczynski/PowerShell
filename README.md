# PowerShell Repository

Welcome to my central PowerShell repository! This repository serves as a collection of custom scripts, tools, and fully-fledged modules designed to automate daily tasks, manage infrastructure, and enhance standard PowerShell functionality.

## Repository Structure

The repository is structured to hold the main module and standalone scripts:

- **[`/BUTCH`](./BUTCH)** - Contains the custom, structured `BUTCH` PowerShell module. It follows standard `.psd1` / `.psm1` architecture and is meant to be imported into your session.
- **`/scripts`** *(Planned)* - For standalone, one-off `.ps1` automation scripts.

---

## Installing BUTCH

### Quick Install (latest version, current user)

```powershell
irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1' | iex
```

---

### Install with Parameters

The `irm ... | iex` pattern does not support passing parameters directly.
Use one of the following methods instead:

#### ✅ Method 1 — ScriptBlock *(recommended, supports all parameters)*

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1'))) -AllUsers
```

Combine with `-Version` to install a specific release:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1'))) -AllUsers -Version v2026.5.3.1
```

#### ✅ Method 2 — Helper Variables *(iex-friendly)*

Set variables before piping to `iex`. Supported variables:

| Variable | Equivalent parameter | Example |
|---|---|---|
| `$BUTCHVersion` | `-Version` | `$BUTCHVersion = 'v2026.5.3.1'` |
| `$BUTCHAllUsers` | `-AllUsers` | `$BUTCHAllUsers = $true` |

```powershell
$BUTCHAllUsers = $true
$BUTCHVersion  = 'v2026.5.3.1'   # optional — omit for latest
irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1' | iex
```

#### ✅ Method 3 — Download then Run Locally

```powershell
irm 'https://raw.githubusercontent.com/dbuczynski/PowerShell/main/Install-BUTCH.ps1' -OutFile "$env:TEMP\Install-BUTCH.ps1"
& "$env:TEMP\Install-BUTCH.ps1" -AllUsers
```

---

### Install Scope

| Scenario | Command |
|---|---|
| Current user only *(default)* | `Install-BUTCH.ps1` |
| All users — run as Admin | `Install-BUTCH.ps1 -AllUsers` |
| All users — without Admin *(corporate)* | `Install-BUTCH.ps1 -AllUsers` → prompts for admin credentials |

> **Corporate environments:** Download runs under the current user (internet access required).
> The copy to the global Modules path is performed via an elevated `Start-Process` using
> the provided local Administrator credentials — no internet access required for that account.

---

### Installing a Specific Version

Tags must exist in the GitHub repository (e.g. `v2026.5.3.1`):

```powershell
.\Install-BUTCH.ps1 -Version v2026.5.3.1
```

---

## License

Unless stated otherwise within specific folders or modules, the code in this repository is provided under the **MIT License**. You are free to use, modify, and distribute it, provided you include the original copyright notice.
