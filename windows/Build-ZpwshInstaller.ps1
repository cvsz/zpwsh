[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ZpwshInstallerScratchRootPath {
    param([string]$BaseName = 'zpwsh-installer')

    return (Join-Path ([System.IO.Path]::GetTempPath()) "$BaseName.$([guid]::NewGuid().ToString('N'))")
}

function Copy-ZpwshInstallerPayload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $requiredPayload = @(
        'windows/Install-Zpwsh.ps1',
        'windows/Install-Zpwsh.cmd',
        'zpwsh.psm1',
        'zpwsh.psd1'
    )

    $optionalPayload = @(
        'README.md',
        'CHANGELOG.md',
        'TROUBLESHOOTING.md'
    )

    foreach ($item in $requiredPayload) {
        $sourcePath = Join-Path $SourceRoot $item
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Required installer payload is missing: $item"
        }
    }

    foreach ($item in ($requiredPayload + $optionalPayload)) {
        $sourcePath = Join-Path $SourceRoot $item
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $destinationPath = Join-Path $DestinationRoot $item
        $destinationDirectory = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
        }

        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }
}

$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$packageVersion = (Test-ModuleManifest -Path (Join-Path $sourceRoot 'zpwsh.psd1')).Version.ToString()
$OutputPath = if ($OutputPath) {
    $OutputPath
} else {
    Join-Path $sourceRoot "dist/zpwsh-windows-installer-$packageVersion.zip"
}
$outputDirectory = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    $outputDirectory = (Get-Location).Path
}
$stagingRoot = $null
$buildResult = $null
try {
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Build Windows installer package')) {
        if (Test-Path -LiteralPath $OutputPath) {
            if (-not $Force) {
                throw "Output already exists: $OutputPath. Use -Force to replace it."
            }

            Remove-Item -LiteralPath $OutputPath -Force
        }

        if (-not (Test-Path -LiteralPath $outputDirectory)) {
            [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
        }

        $stagingRoot = Get-ZpwshInstallerScratchRootPath
        [System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
        Copy-ZpwshInstallerPayload -SourceRoot $sourceRoot -DestinationRoot $stagingRoot

        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Force
        }

        Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $OutputPath -Force

        $buildResult = [pscustomobject]@{
            SourceRoot = $sourceRoot
            OutputPath = $OutputPath
            PackageVersion = $packageVersion
        }
    }
} finally {
    if ($stagingRoot -and (Test-Path -LiteralPath $stagingRoot)) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$buildResult
