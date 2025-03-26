Get-DbaDbTable -SqlInstance '''' -Database '''' -Table '''' | Export-DbaScript -Passthru 

Get-DbaTable -SqlInstance '' -Database '' | ForEach-Object { Export-DbaScript -InputObject $_ -Path ($_.Name + “.sql”) }
