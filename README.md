# zpwsh - PowerShell Helper Module v2.0.0 Final Release

PowerShell module for safe array helpers, module import checks, profile block management, health checks, and diagnostics export.

## Features

- **Safe Array Helpers**: Null-safe indexing helpers for profile and startup scripts.
- **Compatibility Checks**: Pre-import checks for `PSReadLine`, `CompletionPredictor`, `oh-my-posh`, and `Terminal-Icons`.
- **Profile Management**: Managed profile block injection, cleanup, uninstall, backup, and restore support.
- **Health Check & Diagnostics**: Structured health audits with JSON, HTML, and TXT export, including `PASS` and `WARN` status states.
- **Installer Modes**: `-Apply`, `-Repair`, `-Clean`, `-Uninstall`, `-Silent`, `-Force`, and standard PowerShell dry-run support via `-WhatIf` / `-Confirm`.
- **Module Manifest**: Package entrypoint in `zpwsh.psd1` for clean module import and export control.

## Quick Installation

```powershell
Import-Module ./zpwsh.psd1
Invoke-ZpwshInstaller -Apply -Force
```

## Windows Installer

From a Windows shell, you can run the packaged installer directly:

```powershell
.\windows\Install-Zpwsh.ps1 -Action Install -Force
```

Or use the double-clickable launcher:

```cmd
windows\Install-Zpwsh.cmd
```

The installer copies the module into the standard PowerShell module location for the current edition and scope, then updates the managed profile block unless `-SkipProfileUpdate` is used.

Use `-TargetEdition Desktop`, `-TargetEdition Core`, or `-TargetEdition Auto` to control whether the module is installed for Windows PowerShell 5.1 or PowerShell 7+. The command-line launcher prefers `pwsh.exe` when it is available and falls back to `powershell.exe` otherwise.

## Build Package

To create a distributable Windows installer ZIP locally:

```powershell
./windows/Build-ZpwshInstaller.ps1 -Force
```

The GitHub Actions workflow at [`.github/workflows/windows-installer.yml`](.github/workflows/windows-installer.yml) builds the same package on `windows-latest` and uploads `dist/zpwsh-windows-installer-<version>.zip` as an artifact.

Tagged releases (`v*`) are published by [`.github/workflows/windows-release.yml`](.github/workflows/windows-release.yml), which uploads the versioned ZIP as a GitHub Release asset.

## Running Diagnostics & Health Checks

```powershell
Test-ZpwshHealth
Export-ZpwshDiagnostic -Format HTML
```

Legacy plural aliases (`Import-ZpwshModules`, `Export-ZpwshDiagnostics`) remain available for compatibility.

Managed profile updates are literal-path safe, so profile or module paths containing wildcard characters or apostrophes are handled correctly.

## License

MIT License - Copyright (c) 2026 cvsz
