<#
.SYNOPSIS
Daily Windows Updates reporting script.

.DESCRIPTION
This script retrieves available Windows Updates using the PSWindowsUpdate module
and sends a daily email report with a structured overview of pending updates.

Key features:
- Checks for available Windows Updates (no installation performed)
- Classifies updates by severity (Critical, Important, Unspecified)
- Uses MSRC severity when available, with fallback title-based logic
- Sorts updates by priority (Critical → Important → Unspecified)
- Generates a styled HTML report with:
  - Server name
  - Report date
  - Total updates count
  - Severity breakdown
  - Detailed update table (KB, title, size, severity)
- Sends email notification only when updates are available

.NOTES
- Requires PSWindowsUpdate module (Install-Module PSWindowsUpdate)
- SMTP configuration must be provided
- Read-only script (no changes made to the system)
- Intended for scheduled execution (e.g. daily task / DevOps pipeline)

.VERSION
1.0

.AUTHOR
<Your Name>

.DATE
$(Get-Date -Format "yyyy-MM-dd")
#>

Import-Module PSWindowsUpdate
 
$Server = $env:COMPUTERNAME
 
# Mail settings
# Mail settings
$SMTP = "smtp server name"
$From = "sender"
# use this if you have multiple mails @("mail1","mail2")
$To = "mail" 
 
# Get list of available updates
$updates = Get-WindowsUpdate
 
# Exit if no updates are available
if (!$updates) { return }
 
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
    }
    else {
        $title = $update.Title.ToLower()
        if ($title -match "cumulative update for microsoft server") {
            return "Critical"
        }
        elseif ($title -match "security update|sql server cumulative") {
            return "Important"
        }
        else {
            return "Unspecified"
        }
    }
}
 
# Add normalized severity to each update
$updates = $updates | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name NormalizedSeverity -Value (Get-Severity $_) -Force
    $_
}
 
# Sort updates
$sortedUpdates = $updates | Sort-Object { $priority[$_.NormalizedSeverity] }
 
#Wrap in @() to ensure array even with 0 or 1 result
$criticalCount    = @($updates | Where-Object { $_.NormalizedSeverity -eq "Critical" }).Count
$importantCount   = @($updates | Where-Object { $_.NormalizedSeverity -eq "Important" }).Count
$unspecifiedCount = @($updates | Where-Object { $_.NormalizedSeverity -eq "Unspecified" }).Count
$totalCount       = @($updates).Count
 
# HTML table function
function Convert-UpdatesToHtmlTable {
    param([array]$UpdateList)
 
    $html = @"
<table style="border-collapse: collapse; width: 100%; font-family: Arial; font-size: 14px;">
<tr style="background-color:#005A9E;color:white;">
<th>#</th><th>Severity</th><th>KB</th><th>Title</th><th>Size</th>
</tr>
"@
    $i = 1
    foreach ($u in $UpdateList) {
        switch ($u.NormalizedSeverity) {
            "Critical"  { $color = "#D32F2F" }
            "Important" { $color = "#F57C00" }
            default     { $color = "#616161" }
        }
        $kb    = if ($u.KBArticleIDs) { $u.KBArticleIDs -join ", " } else { "N/A" }
        $size  = "$([math]::Round($u.Size / 1MB, 2)) MB"
        $html += "<tr>"
        $html += "<td style='text-align:center;'>$i</td>"
        $html += "<td style='background:$color;color:white;font-weight:bold;text-align:center;'>$($u.NormalizedSeverity)</td>"
        $html += "<td>$kb</td>"
        $html += "<td>$($u.Title)</td>"
        $html += "<td style='text-align:right;'>$size</td>"
        $html += "</tr>"
        $i++
    }
    $html += "</table>"
    return $html
}
 
# Build email body
$body = @"
<html>
<body style="font-family:Arial;background:#222;color:#ddd;">
<h2 style="color:#0078D7;">Available Updates Report</h2>
<p><b>Server:</b> $Server</p>
<p><b>Report Date:</b> $(Get-Date -Format "dd/MM/yyyy")</p>
<p><b>Total Updates:</b> $totalCount</p>
<p><b style="color:#D32F2F;">Critical:</b> $criticalCount</p>
<p><b style="color:#F57C00;">Important:</b> $importantCount</p>
<p><b style="color:#999;">Unspecified:</b> $unspecifiedCount</p>
<br/>
$(Convert-UpdatesToHtmlTable -UpdateList $sortedUpdates)
</body>
</html>
"@
 
# Send email
Send-MailMessage `
    -From    $From `
    -To      $To `
    -Subject "$Server - Updates ($criticalCount Critical, $importantCount Important)" `
    -Body    $body `
    -SmtpServer $SMTP `
    -BodyAsHtml
