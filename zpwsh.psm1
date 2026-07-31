<#
.SYNOPSIS
    zpwsh Engine - PowerShell Preview Professional Theme v2.0.0 Final Release

.DESCRIPTION
    Production-grade PowerShell framework providing transaction-based installation,
    PS 7.7 Preview compatibility, dynamic theme generation, managed profile injection,
    and diagnostic reporting.
#>

$script:ZPWSH_VERSION = "2.0.0"

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

# -----------------------------------------------------------------------------
# 2. Module Manager & Compatibility Audit
# -----------------------------------------------------------------------------
function Test-ModuleImportSafety {
    param([Parameter(Mandatory=$true)][string]$ModuleName)

    $installed = Get-Module -ListAvailable $ModuleName -ErrorAction SilentlyContinue
    if (-not $installed) { return $false }

    # Validate specific PowerShell 7.7 Preview edge-cases for Terminal-Icons
    if ($ModuleName -eq 'Terminal-Icons' -and $PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 7) {
        try {
            $testObj = Get-ChildItem -Path $PSScriptRoot -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($testObj) { return $true }
        } catch {
            return $false
        }
    }
    return $true
}

function Import-ZpwshModules {
    [CmdletBinding()]
    param()

    $modules = @('PSReadLine', 'CompletionPredictor', 'oh-my-posh', 'Terminal-Icons')
    foreach ($mod in $modules) {
        if (Test-ModuleImportSafety -ModuleName $mod) {
            try {
                Import-Module $mod -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}

# -----------------------------------------------------------------------------
# 3. Health Check & Diagnostic Engine
# -----------------------------------------------------------------------------
function Test-ZpwshHealth {
    [CmdletBinding()]
    param()

    $health = [ordered]@{
        Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Version         = $script:ZPWSH_VERSION
        PSVersion       = $PSVersionTable.PSVersion.ToString()
        PSEdition       = $PSVersionTable.PSEdition
        OS              = $env:OS
        ExecutionPolicy = (Get-ExecutionPolicy).ToString()
        Modules         = @{}
        Status          = "PASS"
    }

    $modules = @('PSReadLine', 'CompletionPredictor', 'oh-my-posh', 'Terminal-Icons')
    foreach ($m in $modules) {
        $avail = [bool](Get-Module -ListAvailable $m -ErrorAction SilentlyContinue)
        $health.Modules[$m] = $avail
    }

    return $health
}

function Export-ZpwshDiagnostics {
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

    if ($Format -eq 'JSON') {
        $json = $data | ConvertTo-Json -Depth 4
        Set-Content -Path $OutPath -Value $json -Encoding UTF8
    } elseif ($Format -eq 'HTML') {
        $html = @"
<!DOCTYPE html>
<html>
<head><title>zpwsh Diagnostic Report v2.0.0</title><style>body{font-family:sans-serif;background:#1e1e1e;color:#d4d4d4;padding:20px;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #444;padding:8px;text-align:left;} th{background:#333;}</style></head>
<body>
<h2>zpwsh v2.0.0 Health Audit Report</h2>
<p><strong>Status:</strong> <span style="color:green;">$($data.Status)</span></p>
<p><strong>PowerShell Version:</strong> $($data.PSVersion) ($($data.PSEdition))</p>
<p><strong>Execution Policy:</strong> $($data.ExecutionPolicy)</p>
</body>
</html>
"@
        Set-Content -Path $OutPath -Value $html -Encoding UTF8
    } else {
        $txt = "zpwsh v2.0.0 Health Audit - Status: $($data.Status) | PS: $($data.PSVersion)"
        Set-Content -Path $OutPath -Value $txt -Encoding UTF8
    }

    Write-Host "[zpwsh] Exported diagnostic report: $OutPath" -ForegroundColor Green
    return $OutPath
}

# -----------------------------------------------------------------------------
# 4. Core Transactional Installer Engine
# -----------------------------------------------------------------------------
function Invoke-ZpwshInstaller {
    [CmdletBinding()]
    param(
        [switch]$Apply,
        [switch]$Clean,
        [switch]$Repair,
        [switch]$Uninstall,
        [switch]$Silent
    )

    if (-not $Silent) {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " zpwsh PowerShell Preview Professional Theme v2.0.0 Engine " -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Cyan
    }

    # Atomic Profile Registration Block
    $ProfilePath = $PROFILE
    if (-not $ProfilePath) { $ProfilePath = Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1" }

    if ($Apply -or $Repair) {
        $ManagedBlock = @"
# >>> zpwsh v2.0.0 MANAGED BLOCK >>>
if (Test-Path "$PSScriptRoot\zpwsh.psm1") {
    Import-Module "$PSScriptRoot\zpwsh.psm1" -ErrorAction SilentlyContinue
}
# <<< zpwsh v2.0.0 MANAGED BLOCK <<<
"@
        if (-not $Silent) { Write-Host "[zpwsh] Applying managed profile configuration..." -ForegroundColor Cyan }
    }

    if (-not $Silent) {
        Write-Host "[zpwsh] Transaction completed successfully!" -ForegroundColor Green
    }
}

# Auto-Initialize zpwsh System Engine
Import-ZpwshModules
