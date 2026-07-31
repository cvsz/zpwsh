# zpwsh Pester Unit & Integration Test Suite

Describe "zpwsh v2.0.0 Core Engine Tests" {
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
    }

    Context "Health Audit & Diagnostics" {
        It "Should generate health check status object" {
            $health = Test-ZpwshHealth
            $health.Status | Should -Be "PASS"
            $health.Version | Should -Be "2.0.0"
        }
    }
}
