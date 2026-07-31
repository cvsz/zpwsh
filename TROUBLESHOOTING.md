# TROUBLESHOOTING & FAQ - zpwsh v2.0.0

## Common Issues & Solutions

### 1. `InvalidOperation: Index operation failed; the array index evaluated to null`
- **Cause**: Legacy profile script accessing uninitialized array variables in PowerShell 7.7 Preview.
- **Solution**: Upgrade to `zpwsh v2.0.0` which includes safe indexing wrappers (`Get-SafeArrayItem` / `Test-SafeIndex`).

### 2. Terminal-Icons Error in PowerShell 7.7 Preview
- **Cause**: Breaking object property changes in PS 7.7 Preview.
- **Solution**: `zpwsh` checks whether a module resolves to a real on-disk path before trying to import it. If the import fails, it is skipped without breaking prompt loading.

### 3. Running Diagnostic Audits
To generate a diagnostic report:
```powershell
Export-ZpwshDiagnostic -Format HTML
```

Legacy plural aliases remain available if you already use older command names.

### 4. Full Repair or Rollback
```powershell
# Repair installation
Invoke-ZpwshInstaller -Repair

# Perform complete clean rollback
Invoke-ZpwshInstaller -Clean -Force

# Remove the managed profile block and restore the backup when available
Invoke-ZpwshInstaller -Uninstall -Force

# Preview the change without modifying files
Invoke-ZpwshInstaller -Apply -WhatIf
```

If your profile or module path includes wildcard characters or apostrophes, the managed profile block now uses literal-path-safe quoting and should still load correctly.
