[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install',

    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [ValidateSet('Auto', 'Desktop', 'Core')]
    [string]$TargetEdition = 'Auto',

    [string]$DestinationRoot,

    [switch]$SkipProfileUpdate,

    [switch]$Force,

    [switch]$AllowNonWindows
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ZpwshWindowsPlatform {
    try {
        return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    } catch {
        return ($env:OS -eq 'Windows_NT')
    }
}

function Get-ZpwshInstallerSourceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-ZpwshPackageVersion {
    param([string]$SourceRoot = (Get-ZpwshInstallerSourceRoot))

    $manifestPath = Join-Path $SourceRoot 'zpwsh.psd1'
    return (Test-ModuleManifest -Path $manifestPath).Version.ToString()
}

function Get-ZpwshModuleBasePath {
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope,
        [string]$DestinationRoot,
        [ValidateSet('Auto', 'Desktop', 'Core')]
        [string]$TargetEdition = 'Auto',
        [switch]$AllowNonWindows
    )

    if ($DestinationRoot) {
        return $DestinationRoot
    }

    if (-not (Test-ZpwshWindowsPlatform)) {
        if ($AllowNonWindows) {
            throw 'DestinationRoot is required when running the Windows installer outside Windows.'
        }

        throw 'This installer is intended for Windows.'
    }

    $effectiveEdition = if ($TargetEdition -eq 'Auto') { $PSVersionTable.PSEdition } else { $TargetEdition }

    if ($Scope -eq 'AllUsers') {
        if ($effectiveEdition -eq 'Desktop') {
            return (Join-Path (Join-Path $env:ProgramFiles 'WindowsPowerShell') 'Modules')
        }

        return (Join-Path (Join-Path $env:ProgramFiles 'PowerShell') 'Modules')
    }

    if ($effectiveEdition -eq 'Desktop') {
        return (Join-Path (Join-Path $HOME 'Documents\WindowsPowerShell') 'Modules')
    }

    return (Join-Path (Join-Path $HOME 'Documents\PowerShell') 'Modules')
}

function Copy-ZpwshPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $requiredItems = @(
        'zpwsh.psm1',
        'zpwsh.psd1'
    )

    $optionalItems = @(
        'README.md',
        'CHANGELOG.md',
        'TROUBLESHOOTING.md'
    )

    foreach ($item in $requiredItems) {
        $sourcePath = Join-Path $SourceRoot $item
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Required package file is missing: $item"
        }
    }

    foreach ($item in ($requiredItems + $optionalItems)) {
        $sourcePath = Join-Path $SourceRoot $item
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $targetPath = Join-Path $DestinationRoot $item
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    }
}

function Invoke-ZpwshWindowsInstaller {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [ValidateSet('Install', 'Uninstall')]
        [string]$Action = 'Install',

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [ValidateSet('Auto', 'Desktop', 'Core')]
        [string]$TargetEdition = 'Auto',

        [string]$DestinationRoot,

        [switch]$SkipProfileUpdate,

        [switch]$Force,

        [switch]$AllowNonWindows
    )

    $sourceRoot = Get-ZpwshInstallerSourceRoot
    $packageVersion = Get-ZpwshPackageVersion -SourceRoot $sourceRoot
    $moduleBasePath = Get-ZpwshModuleBasePath -Scope $Scope -DestinationRoot $DestinationRoot -TargetEdition $TargetEdition -AllowNonWindows:$AllowNonWindows
    $moduleTargetPath = Join-Path (Join-Path $moduleBasePath 'zpwsh') $packageVersion
    $moduleRootPath = Split-Path -Parent $moduleTargetPath

    if (-not (Test-ZpwshWindowsPlatform) -and -not $AllowNonWindows) {
        throw 'This installer is intended for Windows. Use -AllowNonWindows only for test or packaging smoke runs.'
    }

    if ($Action -eq 'Install') {
        $operation = "install zpwsh to $moduleTargetPath"
        if (-not $PSCmdlet.ShouldProcess($moduleTargetPath, $operation)) {
            return
        }

        if ((Test-Path -LiteralPath $moduleTargetPath) -and -not $Force) {
            throw "Destination already exists: $moduleTargetPath. Use -Force to replace it."
        }

        if (-not (Test-Path -LiteralPath $moduleRootPath)) {
            [System.IO.Directory]::CreateDirectory($moduleRootPath) | Out-Null
        }

        $stagingPath = "$moduleTargetPath.__staging.$([guid]::NewGuid().ToString('N'))"
        $backupPath = "$moduleTargetPath.__backup.$([guid]::NewGuid().ToString('N'))"

        try {
            [System.IO.Directory]::CreateDirectory($stagingPath) | Out-Null
            Copy-ZpwshPackage -SourceRoot $sourceRoot -DestinationRoot $stagingPath

            Test-ModuleManifest -Path (Join-Path $stagingPath 'zpwsh.psd1') | Out-Null

            if (Test-Path -LiteralPath $moduleTargetPath) {
                Move-Item -LiteralPath $moduleTargetPath -Destination $backupPath -Force
            }

            Move-Item -LiteralPath $stagingPath -Destination $moduleTargetPath -Force

            $manifestPath = Join-Path $moduleTargetPath 'zpwsh.psd1'
            Import-Module $manifestPath -Force
            if (-not $SkipProfileUpdate) {
                Invoke-ZpwshInstaller -Apply -Force -Silent
            }

            if (Test-Path -LiteralPath $backupPath) {
                Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            if (Test-Path -LiteralPath $stagingPath) {
                Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $moduleTargetPath) {
                Remove-Item -LiteralPath $moduleTargetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $backupPath) {
                Move-Item -LiteralPath $backupPath -Destination $moduleTargetPath -Force
            }
            throw
        }

        [pscustomobject]@{
            Action     = 'Install'
            ModulePath = $moduleTargetPath
            Scope      = $Scope
        }
        return
    }

    if ($Action -eq 'Uninstall') {
        $operation = "uninstall zpwsh from $moduleTargetPath"
        if (-not $PSCmdlet.ShouldProcess($moduleTargetPath, $operation)) {
            return
        }

        if (Test-Path -LiteralPath $moduleTargetPath) {
            $profileCleanupFailed = $false
            try {
                $manifestPath = Join-Path $moduleTargetPath 'zpwsh.psd1'
                Import-Module $manifestPath -Force -ErrorAction SilentlyContinue
                if (-not $SkipProfileUpdate) {
                    Invoke-ZpwshInstaller -Uninstall -Force -Silent
                }
            } catch {
                $profileCleanupFailed = $true
            }

            Remove-Item -LiteralPath $moduleTargetPath -Recurse -Force

            if ($profileCleanupFailed -and -not $SkipProfileUpdate) {
                Write-Warning "zpwsh files were removed, but profile cleanup could not run because the installed module could not be loaded."
            }
        }

        $moduleRoot = Split-Path -Parent $moduleTargetPath
        if ((Test-Path -LiteralPath $moduleRoot) -and -not (Get-ChildItem -LiteralPath $moduleRoot -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $moduleRoot -Force
        }

        [pscustomobject]@{
            Action     = 'Uninstall'
            ModulePath = $moduleTargetPath
            Scope      = $Scope
        }
    }
}

Invoke-ZpwshWindowsInstaller -Action $Action -Scope $Scope -TargetEdition $TargetEdition -DestinationRoot $DestinationRoot -SkipProfileUpdate:$SkipProfileUpdate -Force:$Force -AllowNonWindows:$AllowNonWindows
