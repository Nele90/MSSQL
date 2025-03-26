#Set Variables

$ScripInfo = '
#######################################################################
#  This script is used to copy database from one server to another    #
#  If destination server is part of Always on database can be added   #
#  using this scrit. Before run it on production pelase test on test  #
#  environemnt. Fell free to change the script accordingly.!          # 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}


#Start-process "C:\Users\radevic\OneDrive - SMA Solar Technology AG\Desktop\Copy_DB.ps1" -Credential "sma\radevic_admin"
$SourceServer = Read-Host -Prompt "Type source server name which you want to copy from"
$DestinationServer = Read-Host -Prompt "Type destination server name which you want to copy to"
$SourceDatabaseName = Read-Host -Prompt "Type source database name which you want to copy"
$DestinationDatabaseName = Read-Host -Prompt "Do you want to change name of database (Y/N)"
if ($DestinationDatabaseName -match 'Y') 
{
    $NewDestationDatabaseName = Read-Host -Prompt "Type new database name"
}

$SharedPath = Read-Host -Prompt "Type shared path where you backup will be done, both servers should have access to that path! ex:\\servername\TestSHare "
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N)"
$CodeBase = 'Copy-DbaDatabase -Source $SourceServer -Destination $DestinationServer -Database $SourceDatabaseName -BackupRestore -SharedPath $SharedPath'

#add new database name flag to the copy command
if ($DestinationDatabaseName -match 'Y') 
{
    $CodeBase1 = $CodeBase + ' -NewName $NewDestationDatabaseName'
}

#if whatif is N and new database name is set then below code will be executed
if ($WhatIF -match 'N' -and $DestinationDatabaseName -match 'Y')
{
    Write-host 'Running copy database script without whatif and with new database name'
    Invoke-Expression $CodeBase1 | Out-String -OutVariable out 
} 

#if whatif is N and new database name is not set then below code will be executed
if ($WhatIF -match 'N' -and $DestinationDatabaseName -match 'N')
{
    Write-host 'Running copy database script without whatif and with source database name'  
    Invoke-Expression $CodeBase | Out-String -OutVariable out 
}

#if whatif is Y and new database name is not set then below code will be executed
if ($WhatIF -match 'Y' -and $DestinationDatabaseName -match 'N')
{
    Write-host 'Running copy database script with whatif flag and with source database name'  
    $CodeBase4 = $CodeBase + ' -WhatIf' 
    Invoke-Expression $CodeBase4 | Out-String -OutVariable out 
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)"

} 
#if whatif is Y and new database name is set then below code will be executed
if ($WhatIF -match 'Y' -and $DestinationDatabaseName -match 'Y')
{
    Write-host 'Running copy database script with whatif and with new database name'  
    $CodeBase3 = $CodeBase1 + ' -WhatIf' 
    Invoke-Expression $CodeBase3 | Out-String -OutVariable out 
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)"

} 

#Brake script if Wahtif look suspisions
if ($AfterWhatIF -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
} 

#Run copy db code if whatif look fine and new db name is set
if ($AfterWhatIF -match 'Y' -and $DestinationDatabaseName -match 'Y')
{
    Write-host 'Running copy database script with new database name'    
    Invoke-Expression $CodeBase1 | Out-String -OutVariable out 
} 

#Run copy db code if whatif look fine and new db name is not set
if ($AfterWhatIF -match 'Y' -and $DestinationDatabaseName -match 'N')
{
    Write-host 'Running copy database script with source database name'
    Invoke-Expression $CodeBase | Out-String -OutVariable out 
} 




######################Add database to always on############################
#set variables
$AGCodebase = 'Add-DbaAgDatabase -SqlInstance $DestinationServer'

$AwalablityGroupUse = Read-Host -Prompt "Is destination server part of Always on, do you want to add database to AG?(Y/N)"

#Checking destination server for Awalability group name
if ($AwalablityGroupUse -match 'Y')
{ 
            Write-Host "Checking destination server for Awalability group name"
            $AGName = Get-DbaAvailabilityGroup -SqlInstance $DestinationServer | select-object -expandproperty AvailabilityGroup  
            $AGCodebase2 = $AGCodebase + ' -AvailabilityGroup $AGName'

}
else
{
Read-Host -Prompt "Press Enter to exit"
break
}

#Add database flag to add db to ag code
if ($DestinationDatabaseName -match 'Y') 
{
    $AGCodebase3 = $AGCodebase2 + ' -Database $NewDestationDatabaseName -SeedingMode Automatic -Confirm'
}
else
{
    $AGCodebase4 = $AGCodebase2 + ' -Database $SourceDatabaseName -SeedingMode Automatic -Confirm'
}


#Set variable to check DB recovery model
$CheckDbRecovery = Get-DbaDatabase -SqlInstance $DestinationServer -Database $NewDestationDatabaseName | Select-object -expandproperty RecoveryModel

#If db is not in FULL recovery it will be changed to FULL, new db name
if ($CheckDbRecovery -notmatch 'Full' -and $DestinationDatabaseName -match 'Y')
{
    Write-host "Check if database is in FULL recovery if not it will be change as it's mantatory for AG"
    Set-DbaDbRecoveryModel -SqlInstance $DestinationServer -RecoveryModel FULL -Database $NewDestationDatabaseName -Confirm:$true -Verbose
}


#If db is not in FULL recovery it will be changed to FULL, source db name
if ($CheckDbRecovery -notmatch 'Full' -and $DestinationDatabaseName -match 'N')
{
    Write-host "Check if database is in FULL recovery if not it will be change as it's mantatory for AG"
    Set-DbaDbRecoveryModel -SqlInstance $DestinationServer -RecoveryModel FULL -Database $SourceDatabaseName -Confirm:$true -Verbose
}

#if whatif flag is used and new db name is provided run below code
$WhatIF1 = Read-Host -Prompt "Do you want to use WhatIf (Y/N)"

if ($WhatIF1 -match 'Y' -and $DestinationDatabaseName -match 'Y')
{
    $AGCodebase3WF = $AGCodebase3 + ' -WhatIf' 
    #Write-host "Backup of db needs to be done before adding it to AG, backup will be done to NULL device"
    #Backup-DbaDatabase -SqlInstance $DestinationServer -Database $NewDestationDatabaseName -FilePath NULL
    Write-host 'Running add database to ag script with whatif flag and new database name'    
    Invoke-Expression $AGCodebase3WF | Out-String -OutVariable out 
} 

#if whatif flag is used and no new db name is provided run below code
if ($WhatIF1 -match 'Y' -and $DestinationDatabaseName -match 'N')
{
    $AGCodebase4WF = $AGCodebase4 + ' -WhatIf' 
    #Write-host "Backup of db needs to be done before adding it to AG, backup will be done to NULL device"
    #Backup-DbaDatabase -SqlInstance $DestinationServer -Database $SourceDatabaseName -FilePath NULL
    Write-host 'Running add database to ag script with whatif flag and source database name' 
    Invoke-Expression $AGCodebase4WF | Out-String -OutVariable out 
} 

#If whatif is N then stop execution of the script
$AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)"

if ($AfterWhatIF -match 'N' -and ($DestinationDatabaseName -match 'N' -or $DestinationDatabaseName -match 'Y' ))
{
    Read-Host -Prompt "Press enter to exit"
    break
} 

#If whatif look fine and new db name is used run below code else stop script
if ($AfterWhatIF -match 'Y' -and $DestinationDatabaseName -match 'Y')
{
    Write-host 'Running add database to ag script without whatif flag and new database name'
    Invoke-Expression $AGCodebase3 | Out-String -OutVariable out 
} 
else 
{
    Read-Host -Prompt "Script has been executed successfully press enter to exit"
    break
}

#If whatif look fine and no new db name is used run below code else stop script
if ($AfterWhatIF -match 'Y' -and $DestinationDatabaseName -match 'N')
{
    Write-host 'Running add database to ag script without whatif flag and source database name'
    Invoke-Expression $AGCodebase4 | Out-String -OutVariable out 
} 
else 
{
    Read-Host -Prompt "Script has been executed successfully press enter to exit"
    break
}
