
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RootBackupDir = "C:\GPOBackups",

    [Parameter()]
    [int]$RetentionDays = 30
)

# 1. Compatibility Imports
# ActiveDirectory and GroupPolicy ship as RSAT Windows features, not PowerShell Gallery
# modules, so they must be installed via Add-WindowsCapability (requires an elevated session).
$IsElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "[-] Loading ActiveDirectory and GroupPolicy modules..." 
if (-not (Get-Module -ListAvailable -Name ActiveDirectory -SkipEditionCheck)) {
    if ($IsElevated) {
        Write-Host "[-] ActiveDirectory module not found. Installing RSAT-AD-PowerShell feature..." 
        Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
    }
    else {
        Write-Warning "The ActiveDirectory module is not installed and this session is not elevated. Re-run as Administrator to install it automatically, or run: Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'"
    }
}
Import-Module ActiveDirectory -UseWindowsPowerShell -WarningAction SilentlyContinue

if (-not (Get-Module -ListAvailable -Name GroupPolicy -SkipEditionCheck)) {
    if ($IsElevated) {
        Write-Host "[-] GroupPolicy module not found. Installing RSAT-GPMC feature..." 
        Add-WindowsCapability -Online -Name "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
    }
    else {
        Write-Warning "The GroupPolicy module is not installed and this session is not elevated. Re-run as Administrator to install it automatically, or run: Add-WindowsCapability -Online -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'"
    }
}
Import-Module GroupPolicy -UseWindowsPowerShell -WarningAction SilentlyContinue
# 2. Invoke Initialize-GPOStorageSchema.ps1
$InitScript = Join-Path -Path $PSScriptRoot -ChildPath "Initialize-GPOStorageSchema.ps1"
if (-not (Test-Path -Path $InitScript)) {
    throw "Initialization script not found at expected location: $InitScript"
}

Write-Host "[-] Calling Initialize-GPOStorageSchema.ps1..." 
# Parameter binding explicitly matches [string]$RootPath declared in Initialize-GPOStorageSchema.ps1
$Paths = & $InitScript -RootPath $RootBackupDir
if (-not $Paths -or -not $Paths.Root) {
    throw "Initialize-GPOStorageSchema.ps1 did not return valid directory hashtable."
}

# Start transcript logging directly inside the snapshot directory
Start-Transcript -Path (Join-Path -Path $Paths.Root -ChildPath "BackupExecution.log") -Append

try {
    # 3. Query all domain GPOs
    Write-Host "[-] Querying domain GPOs..." 
    $DomainGpos = Get-GPO -All
    Write-Host "[+] Found $($DomainGpos.Count) GPOs in the domain." -ForegroundColor Green

    # 4. Native GPO Backup into RawGPOs
    Write-Host "[-] Executing native GPO backups to $($Paths.RawGPOs)..." 
    $BackupResults = Backup-GPO -All -Path $Paths.RawGPOs -Comment "Automated Backup Run"

    # 5. Build and export Manifest.json
    Write-Host "[-] Compiling Manifest.json..." 
    $Manifest = foreach ($gpo in $DomainGpos) {
        $backupEntry = $BackupResults | Where-Object { $_.GpoId -eq $gpo.Id }
        [PSCustomObject]@{
            GpoDisplayName  = $gpo.DisplayName
            GpoGuid         = "$($gpo.Id)"
            BackupId        = if ($backupEntry) { "$($backupEntry.Id)" } else { $null }
            UserVersion     = $gpo.User.DSVersion
            ComputerVersion = $gpo.Computer.DSVersion
            GpoStatus       = "$($gpo.GpoStatus)"
            WmiFilter       = if ($gpo.WmiFilter) { $gpo.WmiFilter.Name } else { $null }
            BackupTimeUtc   = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    @($Manifest) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path -Path $Paths.Metadata -ChildPath "Manifest.json") -Encoding utf8

    # 6. Generate HTML and XML reports
    Write-Host "[-] Generating GPO configuration reports..." 
    foreach ($gpo in $DomainGpos) {
        $safeName = $gpo.DisplayName -replace '[\/\\:\*\?"<>\|]', '_'
        $htmlPath = Join-Path -Path $Paths.ReportsHtml -ChildPath "$safeName.html"
        $xmlPath  = Join-Path -Path $Paths.ReportsXml -ChildPath "$safeName.xml"

        Get-GPOReport -Guid $gpo.Id -ReportType Html -Path $htmlPath
        Get-GPOReport -Guid $gpo.Id -ReportType Xml -Path $xmlPath
    }

    # 7. Map Domain Root and OU link hierarchy
    Write-Host "[-] Mapping Active Directory link hierarchy..." 
    $OUs = (Get-ADOrganizationalUnit -Filter *).DistinguishedName

    $AllTargets = @($DomainDN) + @($OUs) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $LinkAssignments = foreach ($target in $AllTargets) {
        $inheritance = Get-GPInheritance -Target $target -ErrorAction SilentlyContinue
        if ($inheritance -and $inheritance.GpoLinks) {
            foreach ($link in $inheritance.GpoLinks) {
                [PSCustomObject]@{
                    TargetDN       = $target
                    GpoDisplayName = $link.DisplayName
                    GpoGuid        = if ($link.GpoId) { "$($link.GpoId)" } else { $null }
                    LinkOrder      = $link.Order
                    Enabled        = [bool]$link.Enabled
                    Enforced       = [bool]$link.Enforced
                }
            }
        }
    }
    @($LinkAssignments) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path -Path $Paths.Metadata -ChildPath "OULinks.json") -Encoding utf8

    # 8. Snapshot Retention Pruning
    Write-Host "[-] Checking retention window ($RetentionDays days)..." 
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $OldSnapshots = Get-ChildItem -Path $RootBackupDir -Directory | Where-Object {
        $_.CreationTime -lt $CutoffDate -and $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{6}$'
    }

    foreach ($old in $OldSnapshots) {
        Write-Host "[!] Pruning expired snapshot: $($old.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $old.FullName -Recurse -Force
    }

    Write-Host "`n[+] Backup cycle completed successfully. Output located at: $($Paths.Root)" -ForegroundColor Green
}
catch {
    Write-Error "Backup cycle failed: $_"
}
finally {
    Stop-Transcript
}
