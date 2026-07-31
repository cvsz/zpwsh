@{
    RootModule        = 'zpwsh.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'e8e49a0b-7b96-4d39-8a08-0b7f6c5eb8c7'
    Author            = 'cvsz'
    CompanyName       = 'Unknown'
    Copyright         = '(c) 2026 cvsz. All rights reserved.'
    Description       = 'PowerShell helper module with safe array helpers, profile management, diagnostics, and installer workflows.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @(
        'Get-SafeArrayItem',
        'Test-SafeIndex',
        'Get-ZpwshProfilePath',
        'Get-ZpwshManagedBlock',
        'Test-ZpwshManagedBlockPresent',
        'Remove-ZpwshManagedBlock',
        'Backup-ZpwshProfile',
        'Restore-ZpwshProfile',
        'Set-ZpwshManagedProfileBlock',
        'Test-ModuleImportSafety',
        'Import-ZpwshModule',
        'Test-ZpwshHealth',
        'Export-ZpwshDiagnostic',
        'Invoke-ZpwshInstaller'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport    = @('Import-ZpwshModules', 'Export-ZpwshDiagnostics')
    PrivateData       = @{
        PSData = @{
            Tags       = @('powershell', 'profile', 'diagnostics', 'installer')
            ReleaseNotes = 'Installer workflows, profile management, diagnostics, and hardening updates for zpwsh 2.0.0.'
        }
    }
}
