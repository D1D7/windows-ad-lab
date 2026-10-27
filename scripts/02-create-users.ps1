<#
.SYNOPSIS
    Bulk-creates users from data\users.csv. Safe to re-run: existing accounts are skipped.

.NOTES
    The initial password is typed at runtime and never stored in the repo.
    Every new user must change it at first logon.
#>

. "$PSScriptRoot\config.ps1"

$pass = Read-Host -AsSecureString "Initial password (12+ chars, upper/lower/digit/symbol)"

foreach ($row in Import-Csv $CsvPath) {
    $sam = $row.Username

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Host "Exists : $sam" -ForegroundColor Yellow
        continue
    }

    # Splatting: parameters in a hashtable instead of backtick line continuations.
    # Easier to read, and it does not break when copied and pasted.
    $params = @{
        Name                  = "$($row.FirstName) $($row.LastName)"
        GivenName             = $row.FirstName
        Surname               = $row.LastName
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$UpnSuffix"
        Department            = $row.Department
        Path                  = "OU=$($row.Department),$UsersOU"
        AccountPassword       = $pass
        Enabled               = $true
        ChangePasswordAtLogon = $true
    }

    try {
        New-ADUser @params -ErrorAction Stop
        Write-Host "Created: $sam" -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] {
        # New-ADUser creates the object first and sets the password second.
        # If the domain rejects the password, the account is left behind DISABLED.
        Write-Warning "$sam was created but is DISABLED: the password was rejected by domain policy."
        Write-Warning "Fix: Set-ADAccountPassword $sam -Reset  then  Enable-ADAccount $sam"
    }
    catch {
        Write-Warning "Failed : $sam - $($_.Exception.Message)"
    }
}
