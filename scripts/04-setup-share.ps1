<#
.SYNOPSIS
    Creates C:\Shares\Company with one folder per department and locks each
    folder to its department group.

.NOTES
    Two permission layers:
      Share level : wide open (Domain Users = Change). Real control is done in NTFS.
      NTFS level  : each folder = SYSTEM + Administrators (Full) + GRP-<Dept> (Modify).
    Access-Based Enumeration hides folders a user cannot open.
#>

. "$PSScriptRoot\config.ps1"

foreach ($dept in $Departments) {
    New-Item -ItemType Directory -Path (Join-Path $ShareRoot $dept) -Force | Out-Null
}

if (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue) {
    Write-Host "Share exists : \\$env:COMPUTERNAME\$ShareName" -ForegroundColor Yellow
}
else {
    New-SmbShare -Name $ShareName -Path $ShareRoot -FullAccess "$NetBIOS\Domain Admins" -ChangeAccess "$NetBIOS\Domain Users" -FolderEnumerationMode AccessBased | Out-Null
    Write-Host "Created share: \\$env:COMPUTERNAME\$ShareName" -ForegroundColor Green
}

foreach ($dept in $Departments) {
    $folder    = Join-Path $ShareRoot $dept
    $groupName = "$GroupPrefix$dept"

    # icacls fails with "No mapping between account names and security IDs"
    # when the group does not exist, so check first
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'")) {
        Write-Warning "Group $groupName not found - run 03-create-groups.ps1 first. Skipping $folder."
        continue
    }

    # /inheritance:r  drop inherited permissions
    # (OI)(CI)        apply to files and subfolders too
    # F = Full control, M = Modify
    icacls $folder /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "$($NetBIOS)\$($groupName):(OI)(CI)M" | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "NTFS set: $folder -> $NetBIOS\$groupName (Modify)" -ForegroundColor Green
    }
    else {
        Write-Warning "icacls failed on $folder (exit code $LASTEXITCODE)"
    }
}
