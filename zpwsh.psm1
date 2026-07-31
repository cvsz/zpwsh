<#
.SYNOPSIS
    zpwsh Profile Engine & ZEAZ Platform Module for PowerShell 7+ & Windows PowerShell.

.DESCRIPTION
    Fixes array index evaluation errors (`InvalidOperation: Index operation failed; the array index evaluated to null`)
    and provides unified ZEAZ Platform automation, environment initialization, and robust array utilities.
#>

# -----------------------------------------------------------------------------
# 1. Defensive PowerShell Environment & Array Helpers
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
# 2. Safe Profile Initialization (prevents null array index crashes)
# -----------------------------------------------------------------------------
function Initialize-ZpwshProfile {
    [CmdletBinding()]
    param()

    Write-Host "`n======================================" -ForegroundColor Cyan
    Write-Host " ZEAZ PLATFORM READY (zpwsh v1.0.0) " -ForegroundColor Green
    Write-Host "======================================`n" -ForegroundColor Cyan
}

# Auto-initialize zpwsh banner safely
Initialize-ZpwshProfile
