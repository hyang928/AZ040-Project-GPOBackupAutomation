# AZ040 - GPO Backup Automation
An automation method to backup Group Policy Objects(GPOs) within an Active Directory

## Features

* Remote Server Administration Tool (RSAT): a suite of Microsoft management tools to manage Windows Server roles and features remotely
* Group Policy Management Console (GPMC): one of optional features of RSAT to manage GPOs from a client machine 

## Tools used

* Windows PowerShell
* Visual Studio Code
* Git and GitHub
* Microsoft Edge
* Windows Copilot

## Sequence

## Phase1: Environment and compatibility set up

### RsatGPMC.ps1 

* Confirms Group Policy Management Console is installed on the VM
* GPMC is an optional feature under Remote Server Administration Tools (RSAT) for Windows 10/11
* This script verifies that GPMC is installed
* Run:

```text
.\RsatGPMC.ps1
```

### NTFSPermissions.ps1

* Disable inheritence, grant full control to local administrators and system
* Run:

```text
.\NTFSPermissions.ps1
```

### Initialize-GPOStorageSnapshot.ps1
* Structures the backup storage schema "C:\GPOBackups"
* Run:

```text
.\Initialize-GPOStorageSnapshot.ps1
```

* Backup Storage Schema structure

```text
C:\GPOBackups\
├── yyyy-mm-dd_hhmmss\
│   ├── Metadata
│	  │     ├── Manifest.json
│ 	│     ├── OULinks.json
│   ├── RawGPOs
│   ├── Reports
│   │   ├── HTML
│	  │   │    ├── report.html
│   │   ├── XML
│	  │   │    ├── report.html
│   └── BackupExecution.log
```

## Phase2: Core Scripts

### Backup-GPOAutomated.ps1: backup engine

* Collects inventory of GPOs - Get-GPO extracts domain GPOs
* Native GPO backup into RawGPOs - Backup-GPO executes backup 
* Generates Metadata & Manifest - Manifest.json matching GPO DN to the AD GUIDs, backup GUIDs, WMI filter bindings
* Captures OU links - OULinks.json mapping all policy links 
* Exports reports - Get-GPOReport to export .html and .xml files 
* Calculates expiration date from the Retention window
* Generates the backup log in C:\GPOBackups 
* Run:

```text
.\Backup-GPOAutomated.ps1
```
## What I learned
By working on this project, I learned:
* GPMC in RSAT enables remote GPO backup from a client machine
* 
