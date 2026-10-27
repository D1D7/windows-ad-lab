<#
.SYNOPSIS
    Creates the lab OU structure. Safe to re-run: existing OUs are skipped.

    LAB
    +-- Users
    |   +-- IT / HR / Finance / Sales
    +-- Groups
    +-- Computers
    +-- Disabled Users
#>

. "$PSScriptRoot\config.ps1"

function New-OUIfMissing {
    param([string]$Name, [string]$Path)

    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel
    if ($existing) {
        Write-Host "Exists : OU=$Name,$Path" -ForegroundColor Yellow
    }
    else {
        New-ADOrganizationalUnit -Name $Name -Path $Path
        Write-Host "Created: OU=$Name,$Path" -ForegroundColor Green
    }
}

New-OUIfMissing -Name "LAB" -Path $DomainDN

foreach ($ou in "Users", "Groups", "Computers", "Disabled Users") {
    New-OUIfMissing -Name $ou -Path $LabOU
}

foreach ($dept in $Departments) {
    New-OUIfMissing -Name $dept -Path $UsersOU
}
