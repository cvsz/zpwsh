# zpwsh - ZEAZ PowerShell Platform Engine

`zpwsh` is the PowerShell engine and environment framework for the ZEAZ Platform on Windows 11 & Cross-Platform PowerShell 7+.

## Features

- **Null Index Safety Guard**: Prevents PowerShell `$PROFILE` errors such as `InvalidOperation: Index operation failed; the array index evaluated to null`.
- **ZEAZ Windows 11 Master Installation**: Integrated one-click master setup.
- **Cross-Platform Compatibility**: Full support for PowerShell Core (`pwsh`) and Windows PowerShell (`powershell.exe`).

## Installation

Add the following to your PowerShell `$PROFILE`:

```powershell
Import-Module "$HOME/zpwsh/zpwsh.psm1"
```

To edit your `$PROFILE`:
```powershell
notepad $PROFILE
```
