Describe "zpwsh Windows Installer" {
    BeforeAll {
        $script:installerScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Install-Zpwsh.ps1'
        $script:launcherScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Install-Zpwsh.cmd'
        $script:buildScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Build-ZpwshInstaller.ps1'
        $script:packageVersion = (Test-ModuleManifest -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psd1')).Version.ToString()
    }

    It "Should install and uninstall the module package to a custom destination root" {
        $destinationRoot = Join-Path $TestDrive 'modules'
        $modulePath = Join-Path (Join-Path $destinationRoot 'zpwsh') $script:packageVersion
        $manifestPath = Join-Path $modulePath 'zpwsh.psd1'

        & $script:installerScript -Action Install -DestinationRoot $destinationRoot -AllowNonWindows -SkipProfileUpdate -Force | Out-Null

        (Test-Path -LiteralPath $manifestPath) | Should -Be $true
        (Test-Path -LiteralPath (Join-Path $modulePath 'zpwsh.psm1')) | Should -Be $true

        & $script:installerScript -Action Uninstall -DestinationRoot $destinationRoot -AllowNonWindows -SkipProfileUpdate -Force | Out-Null

        (Test-Path -LiteralPath $modulePath) | Should -Be $false
    }

    It "Should remove a broken installation even when the manifest cannot be loaded" {
        $destinationRoot = Join-Path $TestDrive 'broken'
        $modulePath = Join-Path (Join-Path $destinationRoot 'zpwsh') $script:packageVersion
        $payloadPath = Join-Path $modulePath 'payload.txt'

        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
        Set-Content -LiteralPath $payloadPath -Value 'broken package' -Encoding UTF8

        { & $script:installerScript -Action Uninstall -DestinationRoot $destinationRoot -AllowNonWindows -Force } | Should -Not -Throw

        (Test-Path -LiteralPath $modulePath) | Should -Be $false
    }

    It "Should not create the package when WhatIf is used" {
        $destinationRoot = Join-Path $TestDrive 'whatif-modules'
        $modulePath = Join-Path (Join-Path $destinationRoot 'zpwsh') $script:packageVersion

        & $script:installerScript -Action Install -DestinationRoot $destinationRoot -AllowNonWindows -SkipProfileUpdate -WhatIf | Out-Null

        (Test-Path -LiteralPath $modulePath) | Should -Be $false
    }

    It "Should expose a TargetEdition parameter for edition-specific installs" {
        $scriptText = Get-Content -LiteralPath $script:installerScript -Raw

        $scriptText | Should -Match 'TargetEdition'
        $scriptText | Should -Match "ValidateSet\('Auto', 'Desktop', 'Core'\)"
        $scriptText | Should -Match 'Invoke-ZpwshWindowsInstaller -Action \$Action -Scope \$Scope -TargetEdition \$TargetEdition'
    }

    It "Should prefer pwsh.exe in the launcher before falling back to powershell.exe" {
        $launcherText = Get-Content -LiteralPath $script:launcherScript -Raw

        $launcherText | Should -Match 'where pwsh'
        $launcherText | Should -Match 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File'
        $launcherText | Should -Match 'powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File'
    }

    It "Should build a zip package containing the Windows installer payload" {
        $outputPath = Join-Path $TestDrive 'dist/zpwsh-windows-installer.zip'
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $result = & $script:buildScript -SourceRoot $repoRoot -OutputPath $outputPath -Force

        $result.OutputPath | Should -Be $outputPath

        (Test-Path -LiteralPath $outputPath) | Should -Be $true

        $archiveEntries = [System.IO.Compression.ZipFile]::OpenRead($outputPath).Entries.FullName
        $archiveEntries | Should -Contain 'windows/Install-Zpwsh.ps1'
        $archiveEntries | Should -Contain 'windows/Install-Zpwsh.cmd'
        $archiveEntries | Should -Contain 'zpwsh.psm1'
        $archiveEntries | Should -Contain 'zpwsh.psd1'
    }

    It "Should not write the zip package when WhatIf is used" {
        $outputPath = Join-Path $TestDrive 'dist/whatif-zpwsh-windows-installer.zip'

        $result = & $script:buildScript -SourceRoot (Split-Path $PSScriptRoot -Parent) -OutputPath $outputPath -WhatIf

        (Test-Path -LiteralPath $outputPath) | Should -Be $false
        $result | Should -BeNullOrEmpty
    }

    It "Should derive the default zip name from the manifest version" {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $result = & $script:buildScript -SourceRoot $repoRoot -Force

        $expectedOutputPath = Join-Path (Join-Path $repoRoot 'dist') "zpwsh-windows-installer-$script:packageVersion.zip"
        $result.OutputPath | Should -Be $expectedOutputPath
        (Test-Path -LiteralPath $result.OutputPath) | Should -Be $true
    }

    It "Should build a zip package when OutputPath is a filename in the current directory" {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $outputPath = 'installer-test.zip'

        try {
            $result = & $script:buildScript -SourceRoot $repoRoot -OutputPath $outputPath -Force

            $result.OutputPath | Should -Be $outputPath
            (Test-Path -LiteralPath $outputPath) | Should -Be $true
        } finally {
            if (Test-Path -LiteralPath $outputPath) {
                Remove-Item -LiteralPath $outputPath -Force
            }
        }
    }

    It "Should derive the default zip path from SourceRoot when packaging a copied source tree" {
        $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zpwsh-source-" + [guid]::NewGuid().ToString('N'))
        $buildOutput = $null

        try {
            New-Item -ItemType Directory -Path $sourceRoot | Out-Null
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psd1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psm1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'README.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'CHANGELOG.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'TROUBLESHOOTING.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows') -Destination $sourceRoot -Recurse

            $buildOutput = & $script:buildScript -SourceRoot $sourceRoot -Force
            $expectedOutputPath = Join-Path (Join-Path $sourceRoot 'dist') "zpwsh-windows-installer-$script:packageVersion.zip"

            $buildOutput.OutputPath | Should -Be $expectedOutputPath
            (Test-Path -LiteralPath $buildOutput.OutputPath) | Should -Be $true
        } finally {
            if ($buildOutput -and (Test-Path -LiteralPath $buildOutput.OutputPath)) {
                Remove-Item -LiteralPath $buildOutput.OutputPath -Force
            }
            if (Test-Path -LiteralPath $sourceRoot) {
                Remove-Item -LiteralPath $sourceRoot -Recurse -Force
            }
        }
    }

    It "Should fail when a required installer payload file is missing from SourceRoot" {
        $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zpwsh-missing-payload-" + [guid]::NewGuid().ToString('N'))

        try {
            New-Item -ItemType Directory -Path $sourceRoot | Out-Null
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psd1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psm1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'README.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'CHANGELOG.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'TROUBLESHOOTING.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows') -Destination $sourceRoot -Recurse

            (Test-Path -LiteralPath (Join-Path $sourceRoot 'zpwsh.psm1')) | Should -Be $true
            Remove-Item -LiteralPath (Join-Path $sourceRoot 'zpwsh.psm1') -Force

            { & $script:buildScript -SourceRoot $sourceRoot -Force } | Should -Throw
        } finally {
            if (Test-Path -LiteralPath (Join-Path $sourceRoot 'zpwsh.psm1')) {
                Remove-Item -LiteralPath (Join-Path $sourceRoot 'zpwsh.psm1') -Force
            }
            if (Test-Path -LiteralPath $sourceRoot) {
                Remove-Item -LiteralPath $sourceRoot -Recurse -Force
            }
        }
    }

    It "Should fail when a required package file is missing from the installer source tree" {
        $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zpwsh-missing-package-" + [guid]::NewGuid().ToString('N'))
        $installerScript = Join-Path $sourceRoot 'windows/Install-Zpwsh.ps1'

        try {
            New-Item -ItemType Directory -Path $sourceRoot | Out-Null
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psd1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psm1') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'README.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'CHANGELOG.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'TROUBLESHOOTING.md') -Destination $sourceRoot
            Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows') -Destination $sourceRoot -Recurse

            Remove-Item -LiteralPath (Join-Path $sourceRoot 'zpwsh.psd1') -Force

            { & $installerScript -Action Install -DestinationRoot (Join-Path $TestDrive 'modules') -AllowNonWindows -SkipProfileUpdate -Force } | Should -Throw
        } finally {
            if (Test-Path -LiteralPath $sourceRoot) {
                Remove-Item -LiteralPath $sourceRoot -Recurse -Force
            }
        }
    }
}
