# zpwsh - PowerShell Preview Professional Theme v2.0.0 Final Release

Production-grade PowerShell Environment Framework & Professional Theme Suite for Windows 11, Windows Terminal, VS Code Terminal, ConHost, and PowerShell 7+ (Stable & Preview 7.5/7.6/7.7).

## Features

- **Transaction-Based Installer**: Atomic install, clean install, repair, uninstall, and automatic rollback.
- **Compatibility Engine**: Tested across PS Stable & PS 7.7 Preview, Windows Terminal, VS Code, and ConHost.
- **Dependency & Module Manager**: WinGet detection, offline fallback, safe compatibility checks before module import (PSReadLine, CompletionPredictor, OhMyPosh, Terminal-Icons).
- **Dynamic Theme Engine**: Dynamic theme generation, validation, migration, backup, and restore.
- **Managed Profile Engine**: Non-destructive managed blocks in `$PROFILE` with automatic backup & restore.
- **Health Check & Diagnostics**: System audits generating structured JSON, HTML, and TXT diagnostic reports.
- **Security & Integrity**: SHA-256 manifest verification and zero-destructive execution guarantee.

## Quick Installation

```powershell
Import-Module "$HOME/zpwsh/zpwsh.psm1"
Invoke-ZpwshInstaller -Apply
```

## Running Diagnostics & Health Checks

```powershell
Test-ZpwshHealth
Export-ZpwshDiagnostics -Format HTML
```

## License

MIT License - Copyright (c) 2026 cvsz
