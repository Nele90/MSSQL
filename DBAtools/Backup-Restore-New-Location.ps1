#region Helper functions
function Ask-YesNo {
    param([string]$Question)
    do {
        $answer = Read-Host "$Question (Y/N)"
    } until ($answer -match '^[YyNn]$')
    return $answer -match '^[Yy]$'
}

function Ask-BackupType {
    do {
        $type = Read-Host "Backup type (Full | Log | Differential)"
    } until ($type -in @('Full','Log','Differential'))
    return $type
}

function Parse-Databases {
    param([string]$Input)
    if ($Input -eq '*') {
        return Get-DbaDatabase -SqlInstance $SourceServer | Where-Object { $_.IsSystemObject -eq $false } | Select-Object -ExpandProperty Name
    } else {
        return $Input -split '\s*,\s*'
    }
}
#endregion

Write-Host @'
#######################################################################
# Backup & Restore Multiple Databases (dbatools)
# - CopyOnly backup
# - Optional WhatIf
# - Optional new data/log locations
# Test before production use
#######################################################################
'@

if (-not (Ask-YesNo "Do you want to start the script")) { return }

#region Backup
$SourceServer   = Read-Host "Source SQL Server"
$DatabasesInput = Read-Host "Source database names (comma-separated) or * for all user DBs"
$Databases      = Parse-Databases $DatabasesInput

$BackupType     = Ask-BackupType
$SharedPath     = Read-Host 'Shared path (example: \\server\share\)'
$UseWhatIf      = Ask-YesNo "Use WhatIf for backup?"

foreach ($Database in $Databases) {
    $BackupFile = "$Database.bak"
    $BackupParams = @{
        SqlInstance = $SourceServer
        Database    = $Database
        Path        = $SharedPath
        FilePath    = $BackupFile
        Type        = $BackupType
        CopyOnly    = $true
    }

    if ($UseWhatIf) {
        Write-Host "`n[WhatIf] Backup: $Database"
        Backup-DbaDatabase @BackupParams -WhatIf
        if (-not (Ask-YesNo "Does WhatIf look correct for $Database, continue?")) { continue }
    }

    Write-Host "`nBacking up $Database..."
    Backup-DbaDatabase @BackupParams
}
#endregion

#region Restore
$DestServer = Read-Host "Destination SQL Server"

$ChangeLocations = Ask-YesNo "Change data and log file locations?"
if ($ChangeLocations) {
    $NewDataDir = Read-Host 'New data directory (e.g. G:\Data)'
    $NewLogDir  = Read-Host 'New log directory (e.g. F:\Log)'
}

$UseWhatIfRestore = Ask-YesNo "Use WhatIf for restore?"

foreach ($Database in $Databases) {
    $DestDatabase = $Database # could prompt for mapping if desired
    $BackupFullPath = Join-Path $SharedPath "$Database.bak"

    $RestoreParams = @{
        SqlInstance             = $DestServer
        Database                = $DestDatabase
        Path                    = $BackupFullPath
        ReplaceDbNameInFile     = $true
    }

    if ($ChangeLocations) {
        $RestoreParams.DestinationDataDirectory = $NewDataDir
        $RestoreParams.DestinationLogDirectory  = $NewLogDir
    }

    if ($UseWhatIfRestore) {
        Write-Host "`n[WhatIf] Restoring $Database..."
        Restore-DbaDatabase @RestoreParams -WhatIf
        if (-not (Ask-YesNo "Does WhatIf look correct for $Database, continue?")) { continue }
    }

    Write-Host "`nRestoring $Database..."
    Restore-DbaDatabase @RestoreParams
}
#endregion

#region Cleanup
if (Ask-YesNo "Do you want to remove backup files?") {
    foreach ($Database in $Databases) {
        $BackupFullPath = Join-Path $SharedPath "$Database.bak"
        if (Ask-YesNo "Use WhatIf for delete $Database?") {
            Remove-Item $BackupFullPath -WhatIf -Verbose
            if (-not (Ask-YesNo "Delete looks OK, continue?")) { continue }
        }
        Remove-Item $BackupFullPath -Verbose
    }
}
#endregion

Write-Host "`nAll done ✅"
