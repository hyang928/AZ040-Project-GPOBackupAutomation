#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$TaskName      = "Automated-GPO-Backup",
    [string]$ScriptPath    = "C:\Projects\GPO-Automation\Backup-GPOAutomated.ps1",
    [string]$ExecutionTime = "02:00AM"
)

$PwshPath = "$PSHOME\pwsh.exe"
if (-not (Test-Path $PwshPath)) { throw "PowerShell 7 not found at: $PwshPath" }

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action (New-ScheduledTaskAction -Execute $PwshPath -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`"") `
    -Trigger (New-ScheduledTaskTrigger -Daily -At $ExecutionTime) `
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)) `
    -User "NT AUTHORITY\SYSTEM" `
    -RunLevel Highest `
    -Description "Automated daily snapshot of AD GPOs, link hierarchies, and audit reports via PowerShell 7." `
    -Force | Out-Null

Write-Host "[+] Scheduled task '$TaskName' registered successfully to run daily at $ExecutionTime." -ForegroundColor Green
