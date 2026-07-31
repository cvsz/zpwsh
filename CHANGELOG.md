# CHANGELOG - zpwsh

All notable changes to the `zpwsh` PowerShell helper module project will be documented in this file.

## [2.0.0] - 2026-07-31 - Final Release

### Added
- **Installer**: `Invoke-ZpwshInstaller` now supports `-Apply`, `-Repair`, `-Clean`, `-Uninstall`, `-Silent`, `-Force`, and PowerShell `-WhatIf` / `-Confirm`.
- **Profile Management**: Managed profile block injection now creates backups, restores cleanly, and removes old managed blocks before reapplying.
- **Health Check & Diagnostics**: `Test-ZpwshHealth` exposes profile and module state, and `Export-ZpwshDiagnostic` exports JSON, HTML, and TXT reports. Legacy plural aliases remain available.
- **Compatibility Checks**: Pre-import validation remains in place for `PSReadLine`, `CompletionPredictor`, `oh-my-posh`, and `Terminal-Icons`.
- **Module Manifest**: Added `zpwsh.psd1` as the import entrypoint with explicit exports.
- **Windows Installer**: Added `windows/Install-Zpwsh.ps1` plus a `windows/Install-Zpwsh.cmd` launcher for Windows-native installation and removal.
- **Windows Installer**: Added explicit `-TargetEdition` support and a launcher that prefers `pwsh.exe` before falling back to `powershell.exe`.
- **Windows Packaging**: Added `windows/Build-ZpwshInstaller.ps1` and a GitHub Actions workflow to build and upload the versioned Windows installer ZIP artifact.
- **Release Automation**: Added a tag-driven GitHub Release workflow that publishes the versioned Windows installer ZIP as a release asset.
- **Pester Test Suite**: Added installer workflow coverage using a throwaway profile path (`tests/zpwsh.Tests.ps1`).
- **Compatibility Hardening**: Improved OS reporting, module safety checks for mixed installation layouts, and literal-path-safe profile/module quoting.
- **Transactional Rollback**: `Invoke-ZpwshInstaller` now restores the previous profile if managed block injection fails during `-Apply` or `-Repair`.

### Fixed
- Resolved the `-Clean`/`-Uninstall` documentation gap by making both modes operate on the managed profile block and backup file.
- Fixed test coverage to exercise installer state changes instead of only helper functions.
- Fixed wildcard-sensitive profile and backup paths by switching to literal-safe filesystem handling.
- Fixed installer mutation rollback so failed `-Apply` and `-Repair` operations restore the prior profile content.
- Fixed default profile-path detection so Windows PowerShell 5.1 uses `WindowsPowerShell` while PowerShell Core uses `PowerShell`.
- Fixed managed profile block generation so module paths with wildcard characters or apostrophes are quoted safely.
- Fixed installer dry-run behavior so `-WhatIf` does not mutate files and validates through `ShouldProcess`.
- Fixed Windows package build dry-run cleanup so `-WhatIf` does not leave scratch directories behind.
- Fixed the Windows installer and package builder so install paths and ZIP names follow the module version from the manifest instead of hardcoding `2.0.0`.
- Fixed Windows installer uninstall so it still removes files when the installed manifest cannot be loaded, instead of failing the cleanup path.
