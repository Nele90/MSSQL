$hours = 1
$ms    = $hours * 3600000

$node = $env:COMPUTERNAME

$events = Get-WinEvent -LogName 'System' -FilterXPath @"
*[System[
    Provider[@Name='Microsoft-Windows-FailoverClustering']
    and (Level=1 or Level=2 or Level=3)
    and TimeCreated[timediff(@SystemTime) <= $ms]
]]
"@ -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, LevelDisplayName, Id, Message,
        @{Name='Node'; Expression={$node}}

if ($events) {

    $rows = foreach ($e in $events) {
        $color = switch ($e.LevelDisplayName) {
            'Critical' { '#c0392b' }
            'Error'    { '#e74c3c' }
            'Warning'  { '#e67e22' }
        }
        "<tr>
            <td style='padding:8px 12px;color:$color;font-weight:bold'>$($e.LevelDisplayName)</td>
            <td style='padding:8px 12px'>$($e.TimeCreated.ToString('dd.MM.yyyy HH:mm:ss'))</td>
            <td style='padding:8px 12px'>$($e.Node)</td>
            <td style='padding:8px 12px'>$($e.Id)</td>
            <td style='padding:8px 12px;white-space:pre-wrap'>$($e.Message)</td>
        </tr>"
    }

    $htmlBody = @"
<html><body style='font-family:Segoe UI,Arial;font-size:13px'>
<h2 style='color:#c0392b'>&#9888; Cluster Alert</h2>
<p>Time: <strong>$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</strong></p>
<p>Node: <strong>$node</strong></p>
<p>Found <strong>$($events.Count)</strong> error(s)/warning(s) in the last 1 hour.</p>
<table border='1' cellspacing='0' style='border-collapse:collapse;width:100%'>
  <tr style='background:#2c3e50;color:white'>
    <th style='padding:8px 12px'>Level</th>
    <th style='padding:8px 12px'>Time</th>
    <th style='padding:8px 12px'>Node</th>
    <th style='padding:8px 12px'>Event ID</th>
    <th style='padding:8px 12px'>Message</th>
  </tr>
  $($rows -join "`n")
</table>
</body></html>
"@

$SMTP = "smtp server name"
$From = "sender"
#use this if you have multiple mails @("mail1","mail2")
$To = "mail" 

    Send-MailMessage `
        -SmtpServer  $smtpServer `
        -From        $smtpFrom `
        -To          $smtpTo `
        -Subject     "[CLUSTER ALERT] $node - $($events.Count) error(s)/warning(s) found" `
        -Body        $htmlBody `
        -BodyAsHtml
}
