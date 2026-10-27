<#
.SYNOPSIS
    Shows every department group and its members on one line each.

.EXAMPLE
    .\07-group-report.ps1            # print to the screen
    .\07-group-report.ps1 -Export    # also save a CSV next to the repo's data folder
#>

param(
    [switch]$Export
)

. "$PSScriptRoot\config.ps1"

$report = Get-ADGroup -Filter "Name -like '$GroupPrefix*'" | Sort-Object Name | ForEach-Object {
    # @() makes an empty group give an empty array (Count 0) instead of $null
    $members = @(Get-ADGroupMember -Identity $_ | Sort-Object Name | Select-Object -ExpandProperty Name)
    [PSCustomObject]@{
        Group   = $_.Name
        Count   = $members.Count
        Members = $members -join ", "
    }
}

$report | Format-Table -AutoSize -Wrap

if ($Export) {
    $file = Join-Path $PSScriptRoot ("..\data\group-report-{0}.csv" -f (Get-Date -Format "yyyyMMdd"))
    $report | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
    Write-Host "Saved: $file" -ForegroundColor Green
}
