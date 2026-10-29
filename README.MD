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

## Phase 1: Environment and compatibility set up

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
│	│   ├── Manifest.json
│ 	│   ├── OULinks.json
│   ├── RawGPOs
│   ├── Reports
│   │   ├── HTML
│   │   │   ├── report.html
│   │   ├── XML
│   │   │   ├── report.html
│   └── BackupExecution.log
```

## Phase 2: Core Scripts

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

## Phase 3: Schedule Task

### Register-Schedule.ps1

* Registers the new reoccuring schedule task by assigning parameters as necessary

```text
Register-ScheduledTask '
  -TaskName $TaskName '
  -Action (New-ScheduledTaskAction -Execute ...) '
  -Trigger (New-ScheduledTaskTrigger -Daily -At $ExecutionTime) '
  ...
```
* Run:

```text
.\Register-Schedule.ps1
```
* Verify the schedule registration
```text
Get-ScheduledTask -TaskName "Automated-GPO-Backup" | Select-Object TaskName, State
```


## What I learned
By working on this project, I learned:
* GPMC in RSAT enables remote GPO backup from a client machine
* Using proper PowerShell built-in variable is essential
```text
$PSHOME : full absolute path to the directory of the currently running script
$PSScriptRoot : stores the full directory path of the folder containing the currently running script
$PSCommandPath : stores the full directory path to the filename of the currently running script
$PSItem ($_) : evaluates the current object within the command pipeline
$Error : an array tracking all errors encountered during the currently running session
```
* 
