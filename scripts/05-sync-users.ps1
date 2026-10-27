<#
.SYNOPSIS
    Treats data\users.csv as the source of truth (like an HR system) and brings
    AD in line with it: Department attribute, OU placement and group membership.

.NOTES
    Users that exist in AD but not in the CSV are left untouched.
#>

. "$PSScriptRoot\config.ps1"

foreach ($row in Import-Csv $CsvPath) {
    $sam = $row.Username
    $u   = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties Department

    if (-not $u) {
        Write-Warning "Missing in AD: $sam - run 02-create-users.ps1"
        continue
    }

    $newDept   = $row.Department
    $oldDept   = $u.Department
    $newGroup  = "$GroupPrefix$newDept"
    $targetOU  = "OU=$newDept,$UsersOU"
    $changed   = $false

    # 1. Department attribute (and the old department group)
    if ($oldDept -ne $newDept) {
        Write-Host "$($sam): Department '$oldDept' -> '$newDept'" -ForegroundColor Cyan

        $oldGroup = "$GroupPrefix$oldDept"
        if ($oldDept -and (Get-ADGroup -Filter "Name -eq '$oldGroup'")) {
            Remove-ADGroupMember -Identity $oldGroup -Members $u -Confirm:$false
            Write-Host "  removed from $oldGroup"
        }

        Set-ADUser -Identity $u -Department $newDept
        $changed = $true
    }

    # 2. OU placement
    if ($u.DistinguishedName -notlike "*,$targetOU") {
        Move-ADObject -Identity $u -TargetPath $targetOU
        Write-Host "  moved to $targetOU"
        $changed = $true
    }

    # 3. Group membership
    if (-not (Get-ADGroup -Filter "Name -eq '$newGroup'")) {
        Write-Warning "Group $newGroup not found - run 03-create-groups.ps1"
        continue
    }

    $isMember = Get-ADGroupMember -Identity $newGroup | Where-Object SamAccountName -eq $sam
    if (-not $isMember) {
        Add-ADGroupMember -Identity $newGroup -Members $sam
        Write-Host "  added to $newGroup"
        $changed = $true
    }

    if (-not $changed) {
        Write-Host "$($sam): OK" -ForegroundColor Green
    }
}
