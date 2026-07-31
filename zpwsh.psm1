<#
.SYNOPSIS
    zpwsh Engine - PowerShell helper module v2.0.0 Final Release

.DESCRIPTION
    PowerShell helper module providing safe array helpers, module import checks,
    managed profile injection, backup and restore, and diagnostic reporting.
#>

$script:ZPWSH_VERSION = "2.0.0"
$script:ZPWSH_MANAGED_BLOCK_START = '# >>> zpwsh v2.0.0 MANAGED BLOCK >>>'
$script:ZPWSH_MANAGED_BLOCK_END = '# <<< zpwsh v2.0.0 MANAGED BLOCK <<<'

# -----------------------------------------------------------------------------
# 1. Compatibility & Safe Array Indexing Engine
# -----------------------------------------------------------------------------
function Get-SafeArrayItem {
    param(
        [Parameter(Mandatory=$false)][object[]]$Array,
        [Parameter(Mandatory=$true)][int]$Index,
        [object]$Default = $null
    )
    if ($null -eq $Array -or $Index -lt 0 -or $Index -ge $Array.Count) {
        return $Default
    }
    $item = $Array[$Index]
    if ($null -eq $item) { return $Default }
    return $item
}

function Test-SafeIndex {
    param(
        [Parameter(Mandatory=$false)][object[]]$Array,
        [Parameter(Mandatory=$true)][int]$Index
    )
    return ($null -ne $Array -and $Index -ge 0 -and $Index -lt $Array.Count -and $null -ne $Array[$Index])
}

function Test-ZpwshIsWindows {
    [CmdletBinding()]
    param()

    try {
        return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    } catch {
        return ($env:OS -eq 'Windows_NT')
    }
}

function Get-ZpwshDefaultProfilePath {
    [CmdletBinding()]
    param(
        [ValidateSet('Desktop', 'Core')]
        [string]$Edition = $PSVersionTable.PSEdition
    )

    if (Test-ZpwshIsWindows) {
        $documentsRoot = Join-Path $HOME 'Documents'
        if ($Edition -eq 'Desktop') {
            $profileDirectory = Join-Path $documentsRoot 'WindowsPowerShell'
        } else {
            $profileDirectory = Join-Path $documentsRoot 'PowerShell'
        }
    } else {
        $profileDirectory = Join-Path (Join-Path $HOME '.config') 'powershell'
    }

    return (Join-Path $profileDirectory 'Microsoft.PowerShell_profile.ps1')
}

function Get-ZpwshOperatingSystem {
    [CmdletBinding()]
    param()

    $osDescription = $null
    try {
        $osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim()
    } catch {
        $osDescription = $null
    }

    if ($osDescription) {
        return $osDescription
    }

    if ($env:OS) {
        return $env:OS
    }

    return [System.Environment]::OSVersion.VersionString
}

function Get-ZpwshProfilePath {
    [CmdletBinding()]
    param(
        [string]$ProfilePath,
        [ValidateSet('Desktop', 'Core')]
        [string]$Edition = $PSVersionTable.PSEdition
    )

    if ($ProfilePath) {
        return $ProfilePath
    }

    if ($PROFILE) {
        return $PROFILE
    }

    return Get-ZpwshDefaultProfilePath -Edition $Edition
}

function Get-ZpwshManagedBlock {
    [CmdletBinding()]
    param(
        [string]$ModulePath
    )

    if (-not $ModulePath) {
        $ModulePath = Join-Path $PSScriptRoot 'zpwsh.psm1'
    }

    $quotedModulePath = "'" + ($ModulePath -replace "'", "''") + "'"

    return @"
$script:ZPWSH_MANAGED_BLOCK_START
if (Test-Path -LiteralPath $quotedModulePath) {
    Import-Module -LiteralPath $quotedModulePath -ErrorAction SilentlyContinue
}
$script:ZPWSH_MANAGED_BLOCK_END
"@
}

function Test-ZpwshManagedBlockPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Content
    )

    return ($Content -match '(?ms)^\s*# >>> zpwsh .*? MANAGED BLOCK >>>\s*.*?^\s*# <<< zpwsh .*? MANAGED BLOCK <<<')
}

function Remove-ZpwshManagedBlock {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [AllowEmptyString()]
        [string]$Content = ''
    )

    if (-not $Content) {
        return $Content
    }

    if (-not $PSCmdlet.ShouldProcess('Managed block content', 'Remove managed block markers')) {
        return $Content
    }

    $pattern = '(?ms)^\s*# >>> zpwsh .*? MANAGED BLOCK >>>\s*.*?^\s*# <<< zpwsh .*? MANAGED BLOCK <<<\s*'
    $cleanContent = [regex]::Replace($Content, $pattern, '').Trim()
    return $cleanContent
}

function Backup-ZpwshProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ProfilePath,
        [string]$BackupPath
    )

    if (-not $BackupPath) {
        $BackupPath = "$ProfilePath.zpwsh.backup"
    }

    $backupDirectory = Split-Path -Parent $BackupPath
    if ($backupDirectory -and -not (Test-Path -LiteralPath $backupDirectory)) {
        [System.IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
    }

    if (Test-Path -LiteralPath $ProfilePath) {
        $tempBackupPath = "$BackupPath.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            [System.IO.File]::Copy($ProfilePath, $tempBackupPath, $true)
            Move-Item -LiteralPath $tempBackupPath -Destination $BackupPath -Force
        } catch {
            if (Test-Path -LiteralPath $tempBackupPath) {
                Remove-Item -LiteralPath $tempBackupPath -Force -ErrorAction SilentlyContinue
            }
            throw
        }
    }

    return $BackupPath
}

function Restore-ZpwshProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ProfilePath,
        [string]$BackupPath
    )

    if (-not $BackupPath) {
        $BackupPath = "$ProfilePath.zpwsh.backup"
    }

    if (-not (Test-Path -LiteralPath $BackupPath)) {
        return $false
    }

    $profileDirectory = Split-Path -Parent $ProfilePath
    if ($profileDirectory -and -not (Test-Path -LiteralPath $profileDirectory)) {
        [System.IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
    }

    $tempProfilePath = "$ProfilePath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::Copy($BackupPath, $tempProfilePath, $true)
        Move-Item -LiteralPath $tempProfilePath -Destination $ProfilePath -Force
    } catch {
        if (Test-Path -LiteralPath $tempProfilePath) {
            Remove-Item -LiteralPath $tempProfilePath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    return $true
}

function Set-ZpwshManagedProfileBlock {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory=$true)][string]$ProfilePath,
        [string]$ModulePath
    )

    if (-not $ModulePath) {
        $ModulePath = Join-Path $PSScriptRoot 'zpwsh.psm1'
    }

    $profileDirectory = Split-Path -Parent $ProfilePath
    if ($profileDirectory -and -not (Test-Path -LiteralPath $profileDirectory)) {
        [System.IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
    }

    $existingContent = if (Test-Path -LiteralPath $ProfilePath) {
        Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction SilentlyContinue
    } else {
        ''
    }

    $cleanContent = Remove-ZpwshManagedBlock -Content $existingContent
    $managedBlock = Get-ZpwshManagedBlock -ModulePath $ModulePath

    if ($PSCmdlet.ShouldProcess($ProfilePath, 'Update managed profile block')) {
        if ([string]::IsNullOrWhiteSpace($cleanContent)) {
            Set-Content -LiteralPath $ProfilePath -Value $managedBlock -Encoding UTF8
        } else {
            $newContent = ($cleanContent.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedBlock.Trim())
            Set-Content -LiteralPath $ProfilePath -Value $newContent -Encoding UTF8
        }

        return $ProfilePath
    }
}

# -----------------------------------------------------------------------------
# 2. Module Manager & Compatibility Audit
# -----------------------------------------------------------------------------
function Test-ModuleImportSafety {
    param([Parameter(Mandatory=$true)][string]$ModuleName)

    $installedModules = Get-Module -ListAvailable $ModuleName -ErrorAction SilentlyContinue
    if (-not $installedModules) { return $false }

    foreach ($installed in $installedModules) {
        $candidatePath = $installed.ModuleBase
        if (-not $candidatePath) {
            $candidatePath = $installed.Path
        }

        if ($candidatePath -and (Test-Path -LiteralPath $candidatePath)) {
            return $true
        }
    }

    return $false
}

function Import-ZpwshModule {
    [CmdletBinding()]
    param()

    $modules = @('PSReadLine', 'CompletionPredictor', 'oh-my-posh', 'Terminal-Icons')
    foreach ($mod in $modules) {
        if (Test-ModuleImportSafety -ModuleName $mod) {
            Import-Module $mod -ErrorAction SilentlyContinue
        }
    }
}

# -----------------------------------------------------------------------------
# 3. Health Check & Diagnostic Engine
# -----------------------------------------------------------------------------
function Test-ZpwshHealth {
    [CmdletBinding()]
    param()

    $profilePath = Get-ZpwshProfilePath
    $backupPath = "$profilePath.zpwsh.backup"
    $health = [ordered]@{
        Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Version         = $script:ZPWSH_VERSION
        PSVersion       = $PSVersionTable.PSVersion.ToString()
        PSEdition       = $PSVersionTable.PSEdition
        OS              = Get-ZpwshOperatingSystem
        ExecutionPolicy = (Get-ExecutionPolicy).ToString()
        ProfilePath     = $profilePath
        ProfileManaged  = $false
        ProfileBackup   = (Test-Path -LiteralPath $backupPath)
        MissingModules  = @()
        Modules         = @{}
        Status          = "PASS"
    }

    if (Test-Path -LiteralPath $profilePath) {
        try {
            $profileContent = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
            $health.ProfileManaged = Test-ZpwshManagedBlockPresent -Content $profileContent
        } catch {
            $health.ProfileManaged = $false
        }
    }

    $modules = @('PSReadLine', 'CompletionPredictor', 'oh-my-posh', 'Terminal-Icons')
    $missingModules = New-Object System.Collections.Generic.List[string]
    foreach ($m in $modules) {
        $avail = [bool](Get-Module -ListAvailable $m -ErrorAction SilentlyContinue)
        $health.Modules[$m] = $avail
        if (-not $avail) {
            [void]$missingModules.Add($m)
        }
    }

    if ($missingModules.Count -gt 0) {
        $health.MissingModules = $missingModules.ToArray()
        $health.Status = "WARN"
    }

    if ($health.ProfileManaged -and -not $health.ProfileBackup) {
        $health.Status = "WARN"
    }

    if (-not $health.ProfileManaged -and $health.ProfileBackup) {
        $health.Status = "WARN"
    }

    return [pscustomobject]$health
}

function Export-ZpwshDiagnostic {
    [CmdletBinding()]
    param(
        [ValidateSet('JSON', 'HTML', 'TXT')]
        [string]$Format = 'JSON',
        [string]$OutPath
    )

    $data = Test-ZpwshHealth
    if (-not $OutPath) {
        $OutPath = Join-Path $HOME "zpwsh-diagnostics.$($Format.ToLower())"
    }

    $outDirectory = Split-Path -Parent $OutPath
    if ($outDirectory -and -not (Test-Path -LiteralPath $outDirectory)) {
        [System.IO.Directory]::CreateDirectory($outDirectory) | Out-Null
    }

    if ($Format -eq 'JSON') {
        $json = $data | ConvertTo-Json -Depth 4
        Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
    } elseif ($Format -eq 'HTML') {
        $statusColor = if ($data.Status -eq 'PASS') { 'green' } elseif ($data.Status -eq 'WARN') { 'orange' } else { 'red' }
        $html = @"
<!DOCTYPE html>
<html>
<head><title>zpwsh Diagnostic Report v2.0.0</title><style>body{font-family:sans-serif;background:#1e1e1e;color:#d4d4d4;padding:20px;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #444;padding:8px;text-align:left;} th{background:#333;}</style></head>
<body>
<h2>zpwsh v2.0.0 Health Audit Report</h2>
<p><strong>Status:</strong> <span style="color:$statusColor;">$($data.Status)</span></p>
<p><strong>PowerShell Version:</strong> $($data.PSVersion) ($($data.PSEdition))</p>
<p><strong>Execution Policy:</strong> $($data.ExecutionPolicy)</p>
</body>
</html>
"@
        Set-Content -LiteralPath $OutPath -Value $html -Encoding UTF8
    } else {
        $txt = "zpwsh v2.0.0 Health Audit - Status: $($data.Status) | PS: $($data.PSVersion)"
        Set-Content -LiteralPath $OutPath -Value $txt -Encoding UTF8
    }

    Write-Information "[zpwsh] Exported diagnostic report: $OutPath" -InformationAction Continue
    return $OutPath
}

# -----------------------------------------------------------------------------
# 4. Core Transactional Installer Engine
# -----------------------------------------------------------------------------
# PSScriptAnalyzer disable PSAvoidUsingWriteHost
function Invoke-ZpwshInstaller {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Apply,
        [switch]$Clean,
        [switch]$Repair,
        [switch]$Uninstall,
        [switch]$Silent,
        [switch]$Force,
        [string]$ProfilePath
    )

    $requestedModeCount = [int]([bool]$Apply) + [int]([bool]$Clean) + [int]([bool]$Repair) + [int]([bool]$Uninstall)

    if ($requestedModeCount -eq 0) {
        throw "Specify one installer mode: -Apply, -Clean, -Repair, or -Uninstall."
    }

    if ($requestedModeCount -gt 1) {
        throw "Only one installer mode can be used at a time: -Apply, -Clean, -Repair, or -Uninstall."
    }

    $ProfilePath = Get-ZpwshProfilePath -ProfilePath $ProfilePath
    $BackupPath = "$ProfilePath.zpwsh.backup"

    $operation = $null
    if ($Apply) {
        $operation = "apply managed profile configuration"
    } elseif ($Clean) {
        $operation = "clean managed profile configuration"
    } elseif ($Repair) {
        $operation = "repair managed profile configuration"
    } elseif ($Uninstall) {
        $operation = "uninstall managed profile configuration"
    }

    if (-not $PSCmdlet.ShouldProcess($ProfilePath, $operation)) {
        return
    }

    if (-not $Silent) {
        Write-Information "==========================================================" -InformationAction Continue
        Write-Information " zpwsh PowerShell helper module v2.0.0 Engine " -InformationAction Continue
        Write-Information "==========================================================" -InformationAction Continue
    }

    if ($Uninstall) {
        if (-not $Silent) { Write-Information "[zpwsh] Uninstalling managed profile configuration..." -InformationAction Continue }
        if (Restore-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath) {
            if (Test-Path -LiteralPath $BackupPath) {
                Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue
            }
        } elseif (Test-Path -LiteralPath $ProfilePath) {
            $content = Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction SilentlyContinue
            $cleanContent = Remove-ZpwshManagedBlock -Content $content
            if ([string]::IsNullOrWhiteSpace($cleanContent)) {
                Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
            } else {
                Set-Content -LiteralPath $ProfilePath -Value $cleanContent -Encoding UTF8
            }
        }
    } elseif ($Clean) {
        if (-not $Silent) { Write-Information "[zpwsh] Cleaning managed profile configuration..." -InformationAction Continue }
        if (Restore-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath) {
            if ($Force -and (Test-Path -LiteralPath $BackupPath)) {
                Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue
            }
        } elseif (Test-Path -LiteralPath $ProfilePath) {
            $content = Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction SilentlyContinue
            $cleanContent = Remove-ZpwshManagedBlock -Content $content
            if ([string]::IsNullOrWhiteSpace($cleanContent)) {
                Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
            } else {
                Set-Content -LiteralPath $ProfilePath -Value $cleanContent -Encoding UTF8
            }
        }
    } elseif ($Repair) {
        if (-not $Silent) { Write-Information "[zpwsh] Repairing profile from backup..." -InformationAction Continue }
        if (Test-Path -LiteralPath $BackupPath) {
            Restore-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath | Out-Null
        } else {
            Backup-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath | Out-Null
        }

        if (-not $Silent) { Write-Information "[zpwsh] Reapplying managed profile configuration..." -InformationAction Continue }
        try {
            Set-ZpwshManagedProfileBlock -ProfilePath $ProfilePath | Out-Null
        } catch {
            if (Test-Path -LiteralPath $BackupPath) {
                Restore-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath | Out-Null
            } elseif (Test-Path -LiteralPath $ProfilePath) {
                Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
            }
            throw
        }
    } elseif ($Apply) {
        if (-not $Silent) { Write-Information "[zpwsh] Backing up profile..." -InformationAction Continue }
        Backup-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath | Out-Null

        if (-not $Silent) { Write-Information "[zpwsh] Applying managed profile configuration..." -InformationAction Continue }
        try {
            Set-ZpwshManagedProfileBlock -ProfilePath $ProfilePath | Out-Null
        } catch {
            if (Test-Path -LiteralPath $BackupPath) {
                Restore-ZpwshProfile -ProfilePath $ProfilePath -BackupPath $BackupPath | Out-Null
            } elseif (Test-Path -LiteralPath $ProfilePath) {
                Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
            }
            throw
        }
    }

    if (-not $Silent) {
        Write-Information "[zpwsh] Transaction completed successfully!" -InformationAction Continue
    }
}
# PSScriptAnalyzer enable PSAvoidUsingWriteHost

# Auto-Initialize zpwsh System Engine
Import-ZpwshModule

Set-Alias -Name Import-ZpwshModules -Value Import-ZpwshModule
Set-Alias -Name Export-ZpwshDiagnostics -Value Export-ZpwshDiagnostic

Export-ModuleMember -Function @(
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
) -Alias @(
    'Import-ZpwshModules',
    'Export-ZpwshDiagnostics'
)
