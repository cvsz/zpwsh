# zpwsh Pester Unit & Integration Test Suite

Describe "zpwsh v2.0.0 Core Engine Tests" {
    BeforeAll {
        Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'zpwsh.psd1') -Force
        $script:tempRoot = Join-Path $TestDrive 'zpwsh'
        $script:tempProfile = Join-Path $script:tempRoot 'Microsoft.PowerShell_profile.ps1'
        $script:tempBackup = "$script:tempProfile.zpwsh.backup"
    }

    Context "Safe Indexing Helpers" {
        It "Should safely return default when array is null or empty" {
            $result = Get-SafeArrayItem -Array $null -Index 0 -Default "fallback"
            $result | Should -Be "fallback"
        }

        It "Should safely return item when valid" {
            $arr = @("alpha", "beta")
            $result = Get-SafeArrayItem -Array $arr -Index 1
            $result | Should -Be "beta"
        }

        It "Should return false for invalid array bounds check" {
            $arr = @("alpha")
            (Test-SafeIndex -Array $arr -Index 5) | Should -Be $false
        }

        It "Should remove any zpwsh managed block version" {
            $content = @"
# preface
# >>> zpwsh v1.9.0 MANAGED BLOCK >>>
if (Test-Path 'C:\temp\zpwsh.psm1') {
    Import-Module 'C:\temp\zpwsh.psm1' -ErrorAction SilentlyContinue
}
# <<< zpwsh v1.9.0 MANAGED BLOCK <<<
# suffix
"@

            $clean = Remove-ZpwshManagedBlock -Content $content

            $clean | Should -Not -Match 'MANAGED BLOCK'
            (($clean -replace "`r", "").Trim()) | Should -Be "# preface`n# suffix"
        }

        It "Should emit literal-path safe module checks in the managed block" {
            $modulePath = Join-Path $script:tempRoot 'modules[1]'
            $managedBlock = Get-ZpwshManagedBlock -ModulePath $modulePath

            $managedBlock | Should -Match 'Test-Path -LiteralPath'
            $managedBlock | Should -Match 'Import-Module -LiteralPath'
            $managedBlock | Should -Match ([regex]::Escape($modulePath))
        }

        It "Should escape apostrophes in module paths inside the managed block" {
            $modulePath = Join-Path $script:tempRoot "Robert's Modules/zpwsh.psm1"
            $managedBlock = Get-ZpwshManagedBlock -ModulePath $modulePath

            $managedBlock | Should -Match "Robert''s Modules"
            $managedBlock | Should -Match "Test-Path -LiteralPath '.*Robert''s Modules.*'"
        }

        It "Should reject a partial managed block with only the start marker" {
            $partialContent = @"
# preface
# >>> zpwsh v2.0.0 MANAGED BLOCK >>>
if (Test-Path 'C:\temp\zpwsh.psm1') {
    Import-Module 'C:\temp\zpwsh.psm1' -ErrorAction SilentlyContinue
}
# suffix
"@

            Test-ZpwshManagedBlockPresent -Content $partialContent | Should -Be $false
        }

        It "Should resolve the correct fallback profile path for Windows PowerShell Desktop" {
            InModuleScope zpwsh {
                Mock Test-ZpwshIsWindows { $true }

                $path = Get-ZpwshDefaultProfilePath -Edition Desktop

                $path | Should -Match 'Documents[\\/]+WindowsPowerShell[\\/]Microsoft.PowerShell_profile.ps1$'
            }
        }

        It "Should resolve the correct fallback profile path for Windows PowerShell Core" {
            InModuleScope zpwsh {
                Mock Test-ZpwshIsWindows { $true }

                $path = Get-ZpwshDefaultProfilePath -Edition Core

                $path | Should -Match 'Documents[\\/]+PowerShell[\\/]Microsoft.PowerShell_profile.ps1$'
            }
        }
    }

    Context "Health Audit & Diagnostics" {
        It "Should generate health check status object" {
            InModuleScope zpwsh {
                Mock Get-Module {
                    [pscustomobject]@{ Name = 'MockModule'; ModuleBase = $TestDrive }
                } -ParameterFilter { $ListAvailable }

                $health = Test-ZpwshHealth
                $health | Should -BeOfType 'System.Management.Automation.PSCustomObject'
                $health.Status | Should -Be "PASS"
                $health.Version | Should -Be "2.0.0"
                $health.OS | Should -Not -BeNullOrEmpty
                $health.MissingModules.Count | Should -Be 0
            }
        }

        It "Should warn when optional modules are unavailable" {
            InModuleScope zpwsh {
                Mock Get-Module { @() } -ParameterFilter { $ListAvailable }

                $health = Test-ZpwshHealth
                $health.Status | Should -Be "WARN"
                $health.MissingModules.Count | Should -Be 4
                $health.MissingModules | Should -Contain 'PSReadLine'
            }
        }

        It "Should warn when the managed profile block exists without a backup" {
            $profileRoot = Join-Path $script:tempRoot 'health'
            $profilePath = Join-Path $profileRoot 'Microsoft.PowerShell_profile.ps1'

            New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
            Set-Content -LiteralPath $profilePath -Value (Get-ZpwshManagedBlock) -Encoding UTF8

            Mock Get-ZpwshProfilePath { $profilePath } -ModuleName zpwsh
            Mock Get-Module {
                [pscustomobject]@{ Name = 'MockModule'; ModuleBase = $TestDrive }
            } -ModuleName zpwsh -ParameterFilter { $ListAvailable }

            $health = Test-ZpwshHealth

            $health.Status | Should -Be "WARN"
            $health.ProfileManaged | Should -Be $true
            $health.ProfileBackup | Should -Be $false
        }
    }

    Context "Module Import Safety" {
        It "Should allow a later valid module when an earlier one is invalid" {
            InModuleScope zpwsh {
                Mock Get-Module {
                    @(
                        [pscustomobject]@{ ModuleBase = '/definitely/missing/module' },
                        [pscustomobject]@{ ModuleBase = $TestDrive }
                    )
                }

                Mock Test-Path {
                    param([string]$LiteralPath)
                    return $LiteralPath -eq $TestDrive
                }

                Test-ModuleImportSafety -ModuleName 'AnyModule' | Should -BeTrue
            }
        }

        It "Should accept a module discovered through Path when ModuleBase is empty" {
            InModuleScope zpwsh {
                Mock Get-Module {
                    @(
                        [pscustomobject]@{
                            ModuleBase = $null
                            Path       = $TestDrive
                        }
                    )
                }

                Mock Test-Path {
                    param([string]$LiteralPath)
                    return $LiteralPath -eq $TestDrive
                }

                Test-ModuleImportSafety -ModuleName 'PathOnlyModule' | Should -BeTrue
            }
        }
    }

    Context "Compatibility Aliases" {
        It "Should export legacy plural aliases for diagnostics and module import" {
            $importAlias = Get-Command Import-ZpwshModules -ErrorAction SilentlyContinue
            $exportAlias = Get-Command Export-ZpwshDiagnostics -ErrorAction SilentlyContinue

            $importAlias.CommandType | Should -Be 'Alias'
            $exportAlias.CommandType | Should -Be 'Alias'
            $importAlias.ResolvedCommandName | Should -Be 'Import-ZpwshModule'
            $exportAlias.ResolvedCommandName | Should -Be 'Export-ZpwshDiagnostic'
        }
    }

    Context "Installer Workflow" {
        BeforeEach {
            New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
            Set-Content -Path $script:tempProfile -Value "# existing profile" -Encoding UTF8
            if (Test-Path $script:tempBackup) {
                Remove-Item -Path $script:tempBackup -Force
            }
        }

        AfterEach {
            if (Test-Path $script:tempProfile) {
                Remove-Item -Path $script:tempProfile -Force
            }
            if (Test-Path $script:tempBackup) {
                Remove-Item -Path $script:tempBackup -Force
            }
        }

        It "Should apply a managed profile block and create a backup" {
            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile

            (Test-Path $script:tempBackup) | Should -Be $true
            $content = Get-Content -Path $script:tempProfile -Raw
            $content | Should -Match '# >>> zpwsh v2.0.0 MANAGED BLOCK >>>'
            $content | Should -Match 'Import-Module'
        }

        It "Should not mutate the profile when -WhatIf is used" {
            { Invoke-ZpwshInstaller -Apply -WhatIf -Force -ProfilePath $script:tempProfile } | Should -Not -Throw

            $content = Get-Content -Path $script:tempProfile -Raw
            $content.Trim() | Should -Be "# existing profile"
            (Test-Path $script:tempBackup) | Should -Be $false
        }

        It "Should restore the backup during clean uninstall" {
            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile
            Set-Content -Path $script:tempProfile -Value "# mutated profile" -Encoding UTF8

            Invoke-ZpwshInstaller -Clean -Silent -ProfilePath $script:tempProfile

            $content = Get-Content -Path $script:tempProfile -Raw
            $content.Trim() | Should -Be "# existing profile"
        }

        It "Should repair a mutated profile and keep a backup" {
            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile
            Set-Content -Path $script:tempProfile -Value "# repaired profile" -Encoding UTF8

            Invoke-ZpwshInstaller -Repair -Silent -Force -ProfilePath $script:tempProfile

            $content = Get-Content -Path $script:tempProfile -Raw
            $content | Should -Match '# existing profile'
            $content | Should -Match '# >>> zpwsh v2.0.0 MANAGED BLOCK >>>'
            (Test-Path $script:tempBackup) | Should -Be $true
        }

        It "Should uninstall and remove the backup" {
            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile

            Invoke-ZpwshInstaller -Uninstall -Silent -ProfilePath $script:tempProfile

            $content = Get-Content -Path $script:tempProfile -Raw
            $content.Trim() | Should -Be "# existing profile"
            (Test-Path $script:tempBackup) | Should -Be $false
        }

        It "Should roll back profile changes if apply fails" {
            Mock Set-ZpwshManagedProfileBlock {
                throw "simulated failure"
            } -ModuleName zpwsh

            { Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile } | Should -Throw

            $content = Get-Content -Path $script:tempProfile -Raw
            $content.Trim() | Should -Be "# existing profile"
        }

        It "Should refresh the backup before a repeated apply" {
            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $script:tempProfile
            Set-Content -Path $script:tempProfile -Value "# refreshed profile" -Encoding UTF8

            Mock Set-ZpwshManagedProfileBlock {
                throw "simulated failure"
            } -ModuleName zpwsh

            { Invoke-ZpwshInstaller -Apply -Silent -ProfilePath $script:tempProfile } | Should -Throw

            $content = Get-Content -Path $script:tempProfile -Raw
            $content.Trim() | Should -Be "# refreshed profile"
            (Get-Content -Path $script:tempBackup -Raw).Trim() | Should -Be "# refreshed profile"
        }

        It "Should reject conflicting installer modes" {
            { Invoke-ZpwshInstaller -Apply -Clean -Silent -ProfilePath $script:tempProfile } | Should -Throw
        }

        It "Should reject missing installer mode" {
            { Invoke-ZpwshInstaller -Silent -ProfilePath $script:tempProfile } | Should -Throw
        }

        It "Should handle profile paths containing wildcard characters" {
            $wildcardRoot = Join-Path $script:tempRoot 'profile[1]'
            $wildcardProfile = Join-Path $wildcardRoot 'Microsoft.PowerShell_profile.ps1'
            $wildcardBackup = "$wildcardProfile.zpwsh.backup"

            New-Item -ItemType Directory -Path $wildcardRoot -Force | Out-Null
            Set-Content -LiteralPath $wildcardProfile -Value "# existing profile" -Encoding UTF8

            Invoke-ZpwshInstaller -Apply -Silent -Force -ProfilePath $wildcardProfile

            (Test-Path -LiteralPath $wildcardProfile) | Should -Be $true
            (Test-Path -LiteralPath $wildcardBackup) | Should -Be $true

            Invoke-ZpwshInstaller -Uninstall -Silent -ProfilePath $wildcardProfile

            $content = Get-Content -LiteralPath $wildcardProfile -Raw
            $content.Trim() | Should -Be "# existing profile"
            (Test-Path -LiteralPath $wildcardBackup) | Should -Be $false
        }
    }

    Context "Diagnostics Export" {
        It "Should create nested output directories when exporting diagnostics" {
            $nestedRoot = Join-Path $script:tempRoot 'nested'
            $nestedReports = Join-Path $nestedRoot 'reports'
            $outputPath = Join-Path $nestedReports 'diagnostics.json'

            $result = Export-ZpwshDiagnostics -Format JSON -OutPath $outputPath

            $result | Should -Be $outputPath
            (Test-Path $outputPath) | Should -Be $true
        }

        It "Should render warning status with a non-green color in HTML diagnostics" {
            $htmlPath = Join-Path $script:tempRoot 'diagnostics.html'

            Mock Test-ZpwshHealth {
                [pscustomobject]@{
                    Status          = 'WARN'
                    PSVersion       = '7.6.4'
                    PSEdition       = 'Core'
                    ExecutionPolicy = 'Unrestricted'
                }
            } -ModuleName zpwsh

            $result = Export-ZpwshDiagnostics -Format HTML -OutPath $htmlPath

            $result | Should -Be $htmlPath
            $html = Get-Content -LiteralPath $htmlPath -Raw
            $html | Should -Match 'color:orange'
            $html | Should -Match '>WARN<'
        }
    }
}
