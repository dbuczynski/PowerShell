# Public Functions

This directory contains scripts for functions that are **exported** to the user when the `BUTCH` module is imported.

Each `.ps1` file here represents a single PowerShell function. The `BUTCH.psm1` root script automatically scans this folder, dot-sources every file, and exports them so they can be used in your terminal.

**Best Practice:** Ensure every function placed here has properly formatted Comment-Based Help with `.SYNOPSIS`, `.DESCRIPTION`, `.INPUTS`, and `.OUTPUTS`.
