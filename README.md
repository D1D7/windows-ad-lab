# Windows Server AD Lab: a small company in PowerShell

A home lab that builds the Active Directory setup of a small company from scratch,
using PowerShell only: OU structure, bulk user creation, department groups,
a shared folder with group-based permissions, HR-driven sync and offboarding.

Every script is **idempotent**: running it twice changes nothing the second time.

## Environment

| | |
|---|---|
| Server | Windows Server 2025, AD DS + DNS roles (domain controller) |
| Domain | `lab.local` (NetBIOS `LAB`) |
| Host | VMware Workstation Pro |
| Tools | PowerShell 5.1, ActiveDirectory module, `icacls`, SMB |

## What gets built

```
lab.local
└── LAB
    ├── Users
    │   ├── IT        Giorgi Beridze, Davit Maisuradze
    │   ├── HR        Nino Kapanadze
    │   ├── Finance   Levan Gelashvili
    │   └── Sales     Ana Lomidze
    ├── Groups        GRP-IT, GRP-HR, GRP-Finance, GRP-Sales
    ├── Computers
    └── Disabled Users

\\DC\Company  (C:\Shares\Company)
    ├── IT       -> GRP-IT       Modify
    ├── HR       -> GRP-HR       Modify
    ├── Finance  -> GRP-Finance  Modify
    └── Sales    -> GRP-Sales    Modify
```

Each employee sees and opens only their own department's folder.

## Scripts

| # | Script | What it does |
|---|---|---|
| | `config.ps1` | Shared settings. Reads domain values from AD, so nothing is hard-coded to `lab.local` |
| 01 | `01-create-ous.ps1` | Creates the OU tree |
| 02 | `02-create-users.ps1` | Bulk-creates users from `data/users.csv` (password typed at runtime, change forced at first logon) |
| 03 | `03-create-groups.ps1` | Creates one security group per department and fills it from the `Department` attribute |
| 04 | `04-setup-share.ps1` | Creates the `Company` share with Access-Based Enumeration and per-department NTFS permissions |
| 05 | `05-sync-users.ps1` | Treats the CSV as the HR source of truth: fixes Department, OU and group membership |
| 06 | `06-offboard-user.ps1` | Leaver process: disable, strip groups, stamp date, move to `Disabled Users` |
| 07 | `07-group-report.ps1` | Group membership report, optional CSV export |

## How to run

On the domain controller, PowerShell **as Administrator**:

```powershell
cd C:\windows-ad-lab\scripts

# Files downloaded from GitHub are marked as "from the internet"
Get-ChildItem .. -Recurse | Unblock-File

.\01-create-ous.ps1
.\02-create-users.ps1
.\03-create-groups.ps1
.\04-setup-share.ps1
.\05-sync-users.ps1
.\07-group-report.ps1

# When someone leaves
.\06-offboard-user.ps1 -Username a.lomidze
```

## Design decisions

**Share permissions wide, NTFS permissions tight.** When both apply, the stricter one wins.
The share gives `Domain Users` Change, and the real control lives in NTFS
(`SYSTEM` + `Administrators` Full, `GRP-<Dept>` Modify, inheritance removed).
One place to manage access, and it also applies to local access.

**Access-Based Enumeration.** Users don't even see folders they can't open.

**Groups, not users, on folders.** Permissions are granted to `GRP-<Dept>` only.
Moving a person between departments means changing group membership, not editing ACLs.

**HR list is the source of truth.** In real companies the HR system says who works where,
and AD follows. `05-sync-users.ps1` found three accounts whose Department in AD
disagreed with the HR list and corrected them, including their OU and groups.

**Disable, don't delete.** Deleting an account loses its SID: file ownership and
audit history break. Leavers are disabled, stamped and parked in `Disabled Users`.

**No passwords in the repo.** The initial password is typed at runtime (`Read-Host -AsSecureString`).

## Troubleshooting log

Real problems hit while building this lab, and what they taught:

| Symptom | Cause | Fix |
|---|---|---|
| `New-ADUser: The password does not meet the length, complexity, or history requirement` and the user exists afterwards with `Enabled: False` | `New-ADUser` creates the object first, sets the password second. A rejected password leaves a disabled account behind | `Set-ADAccountPassword -Reset` + `Enable-ADAccount`. The script now catches this case and says so |
| `New-ADUser: Cannot convert ... AccountPassword` | Plain string passed where a `SecureString` is required | `Read-Host -AsSecureString` |
| `icacls: No mapping between account names and security IDs was done` | The group named in the ACL did not exist yet | Create groups before setting permissions. The share script now checks first |
| `Add-ADGroupMember: Cannot validate argument on parameter 'Members'. The argument is null or empty` | No user had that Department, so the member list was empty | Check the list before adding. The group script now warns instead of failing |
| Pasted multi-line command never runs, console stuck at `>>` | Backtick line continuations and quotes break when pasted | Save as `.ps1` and run the file; use splatting (`@params`) instead of backticks |
| Group report shows unexpected members | Accounts from earlier experiments had different Department values | `05-sync-users.ps1` reconciles AD with the HR list |

## Roadmap

- [ ] Windows 11 client joined to the domain, logon as a lab user
- [ ] GPO: map `\\DC\Company` as a network drive per user
- [ ] GPO: password and account lockout policy, Fine-Grained Password Policy for admins
- [ ] Second domain controller and replication check
- [ ] Scheduled sync from the HR CSV

---

## ქართულად

Windows Server-ის სახლის ლაბი, სადაც მხოლოდ PowerShell-ით აწყობილია პატარა კომპანიის Active Directory:
OU სტრუქტურა, მომხმარებლების მასობრივი შექმნა CSV-დან, დეპარტამენტების ჯგუფები, საერთო საქაღალდე,
სადაც თითოეული თანამშრომელი მხოლოდ თავის საქაღალდეს ხედავს, HR-ის სიასთან სინქრონიზაცია და
სამსახურიდან წასული თანამშრომლის ანგარიშის დახურვა. სკრიპტები ნებისმიერ დომენზე იმუშავებს და
ორჯერ გაშვებით არაფერს აფუჭებს. "Troubleshooting log" ცხრილში ლაბის აწყობისას რეალურად შემხვედრი
შეცდომები და მათი გამოსწორებაა.
