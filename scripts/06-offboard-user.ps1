<#
.SYNOPSIS
    Offboards an employee who is leaving the company.

.DESCRIPTION
    1. Disables the account (logon stops immediately)
    2. Removes it from every group except Domain Users (the primary group)
    3. Stamps the date and the admin's name in Description
    4. Moves it to the Disabled Users OU

    The account is NOT deleted. Deleting it would lose its SID, which breaks file
    ownership and audit history. Companies usually keep disabled accounts for
    30-90 days and only then delete them.

.EXAMPLE
    .\06-offboard-user.ps1 -Username a.lomidze
#>

param(
    [Parameter(Mandatory)]
    [string]$Username
)

. "$PSScriptRoot\config.ps1"

$u = Get-ADUser -Filter "SamAccountName -eq '$Username'"
if (-not $u) {
    throw "User '$Username' not found."
}

Disable-ADAccount -Identity $u
Write-Host "Disabled: $Username" -ForegroundColor Green

Get-ADPrincipalGroupMembership -Identity $u |
    Where-Object { $_.Name -ne "Domain Users" } |
    ForEach-Object {
        Remove-ADGroupMember -Identity $_ -Members $u -Confirm:$false
        Write-Host "  removed from $($_.Name)"
    }

$stamp = Get-Date -Format "yyyy-MM-dd"
Set-ADUser -Identity $u -Description "Disabled $stamp - left company (by $env:USERNAME)"

Move-ADObject -Identity $u -TargetPath $DisabledOU
Write-Host "Moved to: $DisabledOU" -ForegroundColor Green
