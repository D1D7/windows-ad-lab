# Shared settings, dot-sourced by every script in this folder.
# Domain values are read from AD itself, so the scripts work in any domain.
# Only the lab-specific names below need changing.

Import-Module ActiveDirectory -ErrorAction Stop

$Domain      = Get-ADDomain
$DomainDN    = $Domain.DistinguishedName      # e.g. DC=lab,DC=local
$NetBIOS     = $Domain.NetBIOSName            # e.g. LAB
$UpnSuffix   = $Domain.DNSRoot                # e.g. lab.local

$LabOU       = "OU=LAB,$DomainDN"
$UsersOU     = "OU=Users,$LabOU"
$GroupsOU    = "OU=Groups,$LabOU"
$ComputersOU = "OU=Computers,$LabOU"
$DisabledOU  = "OU=Disabled Users,$LabOU"

$Departments = @("IT", "HR", "Finance", "Sales")
$GroupPrefix = "GRP-"

$CsvPath     = Join-Path $PSScriptRoot "..\data\users.csv"
$ShareRoot   = "C:\Shares\Company"
$ShareName   = "Company"
