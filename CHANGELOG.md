# CHANGELOG - zpwsh

All notable changes to the `zpwsh` PowerShell Preview Professional Theme project will be documented in this file.

## [2.0.0] - 2026-07-31 - Final Release

### Added
- **Core Installer**: Transaction-based atomic installation with rollback, clean install, repair, silent mode, and CI mode.
- **Compatibility Engine**: Comprehensive support for PowerShell Stable, PowerShell 7.7 Preview, Windows Terminal, VS Code Terminal, and ConHost.
- **Dependency & Module Manager**: WinGet auto-detection, version pinning, offline fallback, and pre-import compatibility verification for `PSReadLine`, `CompletionPredictor`, `Oh-My-Posh`, and `Terminal-Icons`.
- **Theme Engine**: Dynamic theme generation, validation, migration, backup, and restore capabilities.
- **Profile Manager**: Safe managed block injection with non-destructive profile backup and restore.
- **Health Check & Diagnostics Engine**: Automated health validation with report export capabilities in JSON, HTML, and TXT formats.
- **Logging**: Structured JSON logging, console logging, transcript recording, and debug/verbose modes.
- **Security**: SHA-256 verification, manifest validation, and safe rollback without mutating external resources.
- **Pester Test Suite**: Comprehensive unit and integration test coverage (`tests/zpwsh.Tests.ps1`).

### Fixed
- Resolved `InvalidOperation: Index operation failed; the array index evaluated to null` when initializing profile in PowerShell Preview.
- Fixed `Terminal-Icons` compatibility warning and array property dereferencing in PowerShell 7.7 Preview.
- Eliminated blank-line flooding and startup prompt delays.
