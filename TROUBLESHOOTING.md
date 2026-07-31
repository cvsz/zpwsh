# TROUBLESHOOTING & FAQ - zpwsh v2.0.0

## Common Issues & Solutions

### 1. `InvalidOperation: Index operation failed; the array index evaluated to null`
- **Cause**: Legacy profile script accessing uninitialized array variables in PowerShell 7.7 Preview.
- **Solution**: Upgrade to `zpwsh v2.0.0` which includes safe indexing wrappers (`Get-SafeArrayItem` / `Test-SafeIndex`).

### 2. Terminal-Icons Error in PowerShell 7.7 Preview
- **Cause**: Breaking object property changes in PS 7.7 Preview.
- **Solution**: `zpwsh` validates module compatibility prior to importing. If an incompatible version is detected, it cleanly bypasses module registration without failing prompt loading.

### 3. Running Diagnostic Audits
To generate a diagnostic report:
```powershell
Export-ZpwshDiagnostics -Format HTML
```

### 4. Full Repair or Rollback
```powershell
# Repair installation
Invoke-ZpwshInstaller -Repair

# Perform complete clean rollback
Invoke-ZpwshInstaller -Clean -Force
```
