<#
.SYNOPSIS
    Creates one security group per department (GRP-IT, GRP-HR, ...) and adds
    every user whose Department attribute matches. Safe to re-run.
#>

. "$PSScriptRoot\config.ps1"

foreach ($dept in $Departments) {
    $name = "$GroupPrefix$dept"

    if (-not (Get-ADGroup -Filter "Name -eq '$name'")) {
        New-ADGroup -Name $name -GroupScope Global -GroupCategory Security -Path $GroupsOU -Description "Members of the $dept department"
        Write-Host "Created group: $name" -ForegroundColor Green
    }

    # Add-ADGroupMember fails on an empty list, so check first
    $members = @(Get-ADUser -Filter "Department -eq '$dept'")
    if ($members.Count -gt 0) {
        Add-ADGroupMember -Identity $name -Members $members
        Write-Host "  $name <- $($members.Count) user(s)"
    }
    else {
        Write-Warning "No users with Department '$dept' - $name left empty."
    }
}
