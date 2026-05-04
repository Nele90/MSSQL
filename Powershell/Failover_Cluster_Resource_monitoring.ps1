
Import-Module FailoverClusters

$server = $env:COMPUTERNAME
$time = Get-Date

# ======================
# CHECKS
# ======================

$nodes = Get-ClusterNode | Where-Object { $_.State -ne "Up" }
$resources = Get-ClusterResource | Where-Object { $_.State -ne "Online" }
$groups = Get-ClusterGroup | Where-Object {
    $_.State -ne "Online" -and $_.Name -ne "Available Storage"
}
$networks = Get-ClusterNetwork | Where-Object { $_.State -ne "Up" }
$interfaces = Get-ClusterNetworkInterface | Where-Object { $_.State -ne "Up" }

# ======================
# EXIT IF EVERYTHING OK
# ======================

if (
    !$nodes -and
    !$resources -and
    !$groups -and
    !$networks -and
    !$interfaces
) {
    return
}

# ======================
# HTML STYLE
# ======================

$html = @"
<html>
<head>
<style>
body { font-family: Segoe UI; font-size: 13px; }
h2 { color: #d9534f; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ddd; padding: 6px; }
th { background-color: #f2f2f2; }
.bad { color: #d9534f; font-weight: bold; }
.section { margin-top: 15px; }
</style>
</head>
<body>

<h2>Cluster Alert - $server</h2>
<b>Time:</b> $time
<hr>

"@

# ======================
# NODES
# ======================

if ($nodes) {
$html += "<div class='section'><h3>Nodes</h3><table><tr><th>Name</th><th>State</th></tr>"
foreach ($n in $nodes) {
    $html += "<tr><td>$($n.Name)</td><td class='bad'>$($n.State)</td></tr>"
}
$html += "</table></div>"
}

# ======================
# RESOURCES
# ======================

if ($resources) {
$html += "<div class='section'><h3>Resources</h3><table><tr><th>Name</th><th>State</th></tr>"
foreach ($r in $resources) {
    $html += "<tr><td>$($r.Name)</td><td class='bad'>$($r.State)</td></tr>"
}
$html += "</table></div>"
}

# ======================
# GROUPS
# ======================

if ($groups) {
$html += "<div class='section'><h3>Groups</h3><table><tr><th>Name</th><th>State</th><th>Owner</th></tr>"
foreach ($g in $groups) {
    $html += "<tr><td>$($g.Name)</td><td class='bad'>$($g.State)</td><td>$($g.OwnerNode)</td></tr>"
}
$html += "</table></div>"
}

# ======================
# NETWORKS
# ======================

if ($networks) {
$html += "<div class='section'><h3>Networks</h3><table><tr><th>Name</th><th>State</th><th>Role</th></tr>"
foreach ($n in $networks) {
    $html += "<tr><td>$($n.Name)</td><td class='bad'>$($n.State)</td><td>$($n.Role)</td></tr>"
}
$html += "</table></div>"
}

# ======================
# INTERFACES
# ======================

if ($interfaces) {
$html += "<div class='section'><h3>Network Interfaces</h3><table><tr><th>Node</th><th>Network</th><th>State</th></tr>"
foreach ($i in $interfaces) {
    $html += "<tr><td>$($i.Node)</td><td>$($i.Network)</td><td class='bad'>$($i.State)</td></tr>"
}
$html += "</table></div>"
}

# ======================
# CLOSE HTML
# ======================

$html += "</body></html>"

# ======================
# SEND MAIL (IMPORTANT FIX)
# ======================
# use this if you have multiple mails @("mail1","mail2")
Send-MailMessage `
    -To "mail" `
    -From "sender" `
    -Subject "Cluster ALERT - $server" `
    -Body $html `
    -BodyAsHtml `
    -SmtpServer "smtp server name"
