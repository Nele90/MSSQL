# ── Configuration ──────────────────────────────────────────
$LogPath     = "C:\ProgramData\Veeam\Backup\MSSQLPluginLogs\useraccount\MSSQLVBRCommunicationManager.log"
$MinutesBack = 60
$dateFormat  = "dd.MM.yyyy HH:mm:ss.fff"
$cutoff      = (Get-Date).AddMinutes(-$MinutesBack)
$regex       = '\[(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}\.\d{3})\]'
$pattern     = "Error: Recovery chain for the database"
$inWindow    = $false

# ── Mail configuration ─────────────────────────────────────
$mailFrom    = "mail"
$mailTo      = "mail"
$smtpServer  = "mail"

# ── SQL Agent Job configuration ────────────────────────────
$sqlInstance = $env:COMPUTERNAME        # or "SERVER\INSTANCE"
$sqlJob      = "Veeam_User_DB_FULL"

# ── Search for error in log ────────────────────────────────
$found = $false

Get-Content $LogPath | foreach {
    if ($_ -match $regex) {
        try {
            $t = [datetime]::ParseExact($Matches[1], $dateFormat,
                 [System.Globalization.CultureInfo]::InvariantCulture)
            $inWindow = ($t -ge $cutoff)
        } catch { $inWindow = $false }
    }
    if ($inWindow -and ($_ -like "*$pattern*")) { $found = $true }
}

# ── Action ─────────────────────────────────────────────────
if ($found) {

    # 1. Send mail
    $body = @"
A broken recovery chain has been detected in the Veeam MSSQL log.

SQL Agent job '$sqlJob' has been started automatically on instance '$sqlInstance'.

Time: $(Get-Date -Format 'dd.MM.yyyy HH:mm')
"@

    Send-MailMessage `
        -From       $mailFrom `
        -To         $mailTo `
        -Subject    "[ALERT] SQL Full Backup started - $(Get-Date -Format 'dd.MM.yyyy HH:mm')" `
        -Body       $body `
        -SmtpServer $smtpServer `

    Write-Host "Mail sent." -ForegroundColor Green

    # 2. Start SQL Agent job
    $jobStatus = Get-DbaAgentJob -SqlInstance $sqlInstance -Job $sqlJob

    if ($jobStatus.CurrentRunStatus -eq "Executing") {
        Write-Host "Job '$sqlJob' is already running, skipping." -ForegroundColor Yellow
    } else {
        Start-DbaAgentJob -SqlInstance $sqlInstance -Job $sqlJob
        Write-Host "Job '$sqlJob' started." -ForegroundColor Green
    }
} else {
    Write-Host "No errors found in the last $MinutesBack minutes." -ForegroundColor Green
}
