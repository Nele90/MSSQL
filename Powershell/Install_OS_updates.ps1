<#
.SYNOPSIS
Automates Windows Update management with reporting and safety checks.

.DESCRIPTION
This script checks for available Windows Updates using the PSWindowsUpdate module,
classifies them by severity (Critical, Important, Unspecified), and performs
automated installation when safe.

Key features:
- Retrieves updates from Microsoft Update
- Removes duplicate updates (based on KB or title)
- Assigns normalized severity levels
- Detects SQL-related updates and skips installation if found
- Installs updates silently (no reboot triggered)
- Generates a structured HTML report
- Sends email notifications for all execution scenarios

Execution scenarios:
1. No updates available → Informational email sent
2. SQL updates detected → Installation skipped, warning email sent
3. Updates installed → Summary email sent (restart required)

.NOTES
- Requires PSWindowsUpdate module (Install-Module PSWindowsUpdate)
- SMTP configuration must be provided
- Designed for automation (DevOps / scheduled tasks)
- Does not automatically reboot the server

.AUTHOR
<Your Name>

.DATE
$(Get-Date -Format "yyyy-MM-dd")
#>


Import-Module PSWindowsUpdate

$Server = $env:COMPUTERNAME
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm"


# Mail settings
$SMTP = "smtp server name"
$From = "sender"
# use this if you have multiple mails @("mail1","mail2")
$To = "mail" 

Write-Output "Checking available Windows updates..."

# GET UPDATES (RAW)
$updatesRaw = Get-WindowsUpdate -MicrosoftUpdate

# Deduplication
$updates = $updatesRaw | Group-Object {
    if ($_.KBArticleIDs) { ($_.KBArticleIDs -join ',') } else { $_.Title }
} | ForEach-Object { $_.Group[0] }

$updates = $updates | Sort-Object Title

# Define priority for sorting
$priority = @{
    "Critical"    = 1
    "Important"   = 2
    "Unspecified" = 3
}

# Function to determine severity
function Get-Severity {
    param($update)
    if ($update.MsrcSeverity) {
        switch ($update.MsrcSeverity.ToLower()) {
            "critical"  { return "Critical" }
            "important" { return "Important" }
            default     { return "Unspecified" }
        }
    } else {
        $title = $update.Title.ToLower()
        if ($title -match "cumulative update for microsoft server") { return "Critical" }
        elseif ($title -match "security update|sql server cumulative") { return "Important" }
        else { return "Unspecified" }
    }
}

# Add severity to updates
function Add-Severity {
    param($updateList)
    return $updateList | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name NormalizedSeverity -Value (Get-Severity $_) -Force
        $_
    }
}

# HTML header/style
function Get-HtmlHeader {
    param($title)
    return @"
<html>
<body style="font-family:Arial;background:#222;color:#ddd;">
<h2 style="color:#0078D7;">$title</h2>
<p><b>Server:</b> $Server</p>
<p><b>Report Date:</b> $(Get-Date -Format "dd/MM/yyyy")</p>
"@
}

# HTML table function
function Convert-UpdatesToHtmlTable {
    param([array]$UpdateList)

    $html = @"
<table style="border-collapse:collapse;width:100%;font-family:Arial;font-size:14px;">
<tr style="background-color:#005A9E;color:white;">
<th>#</th><th>Severity</th><th>KB</th><th>Title</th><th>Size</th>
</tr>
"@
    $i = 1
    foreach ($u in $UpdateList) {
        $sev = if ($u.NormalizedSeverity) { $u.NormalizedSeverity } else { "Unspecified" }
        switch ($sev) {
            "Critical"  { $color = "#D32F2F" }
            "Important" { $color = "#F57C00" }
            default     { $color = "#616161" }
        }
        $kb   = if ($u.KBArticleIDs) { $u.KBArticleIDs -join ", " } else { "N/A" }
        $size = if ($u.Size) { "$([math]::Round($u.Size/1MB,2)) MB" } else { "N/A" }

        $html += "<tr>"
        $html += "<td style='text-align:center;padding:4px;'>$i</td>"
        $html += "<td style='background:$color;color:white;font-weight:bold;text-align:center;padding:4px;'>$sev</td>"
        $html += "<td style='padding:4px;'>$kb</td>"
        $html += "<td style='padding:4px;'>$($u.Title)</td>"
        $html += "<td style='text-align:right;padding:4px;'>$size</td>"
        $html += "</tr>"
        $i++
    }
    $html += "</table>"
    return $html
}

# ─── 1. NO UPDATES ───────────────────────────────────────────────────────────
if (!$updates) {
    $body = (Get-HtmlHeader "Available Updates Report")
    $body += "<p style='color:#4CAF50;font-size:16px;'><b> No Windows updates available.</b></p>"
    $body += "</body></html>"

    Send-MailMessage `
        -From       $From `
        -To         $To `
        -Subject    "$Server - No Updates Available" `
        -Body       $body `
        -SmtpServer $SMTP `
        -BodyAsHtml
    return
}

# ─── 2. SQL DETECTED - SKIP ──────────────────────────────────────────────────
$sqlUpdates = $updates | Where-Object { $_.Title -match "SQL" }

if ($sqlUpdates) {
    $updates = Add-Severity $updates
    $sortedUpdates = $updates | Sort-Object { $priority[$_.NormalizedSeverity] }

    $criticalCount    = @($updates | Where-Object { $_.NormalizedSeverity -eq "Critical" }).Count
    $importantCount   = @($updates | Where-Object { $_.NormalizedSeverity -eq "Important" }).Count
    $unspecifiedCount = @($updates | Where-Object { $_.NormalizedSeverity -eq "Unspecified" }).Count
    $totalCount       = @($updates).Count

    $body = (Get-HtmlHeader "Available Updates Report - SQL Detected")
    $body += "<p><b>Total Updates:</b> $totalCount</p>"
    $body += "<p><b style='color:#D32F2F;'>Critical:</b> $criticalCount</p>"
    $body += "<p><b style='color:#F57C00;'>Important:</b> $importantCount</p>"
    $body += "<p><b style='color:#999;'>Unspecified:</b> $unspecifiedCount</p>"
    $body += "<p style='color:#D32F2F;font-size:15px;'><b> SQL updates detected - installation skipped!</b></p><br/>"
    $body += (Convert-UpdatesToHtmlTable -UpdateList $sortedUpdates)
    $body += "</body></html>"

    Write-Output "SQL updates detected - skipping install"

    Send-MailMessage `
        -From       $From `
        -To         $To `
        -Subject    "$Server - SQL Updates Detected (Skipped)" `
        -Body       $body `
        -SmtpServer $SMTP `
        -BodyAsHtml
    return
}

# ─── 3. INSTALL ──────────────────────────────────────────────────────────────
Write-Output "Installing updates..."

$installed = Install-WindowsUpdate `
    -MicrosoftUpdate `
    -AcceptAll `
    -IgnoreReboot `
    -Confirm:$false

# Dedupe installed
$installed = $installed | Group-Object {
    if ($_.KBArticleIDs) { ($_.KBArticleIDs -join ',') } else { $_.Title }
} | ForEach-Object { $_.Group[0] }

$installed = Add-Severity $installed
$sortedInstalled = $installed | Sort-Object { $priority[$_.NormalizedSeverity] }

$criticalCount    = @($installed | Where-Object { $_.NormalizedSeverity -eq "Critical" }).Count
$importantCount   = @($installed | Where-Object { $_.NormalizedSeverity -eq "Important" }).Count
$unspecifiedCount = @($installed | Where-Object { $_.NormalizedSeverity -eq "Unspecified" }).Count
$totalCount       = @($installed).Count

$body = (Get-HtmlHeader "Windows Updates Installed")
$body += "<p><b>Total Installed:</b> $totalCount</p>"
$body += "<p><b style='color:#D32F2F;'>Critical:</b> $criticalCount</p>"
$body += "<p><b style='color:#F57C00;'>Important:</b> $importantCount</p>"
$body += "<p><b style='color:#999;'>Unspecified:</b> $unspecifiedCount</p><br/>"

if ($sortedInstalled) {
    $body += (Convert-UpdatesToHtmlTable -UpdateList $sortedInstalled)
} else {
    $body += "<p>No updates were installed.</p>"
}

$body += "<p style='color:#D32F2F;'><b> Server restart required to complete installation.</b></p>"
$body += "</body></html>"

Write-Output "Updates installed"

Send-MailMessage `
    -From       $From `
    -To         $To `
    -Subject    "$Server - Windows Updates Installed (Restart Pending)" `
    -Body       $body `
    -SmtpServer $SMTP `
    -BodyAsHtml
