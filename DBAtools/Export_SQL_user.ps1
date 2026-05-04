Export-SqlUser -SqlInstance SQL2016N2 -FilePath C:\temp\SQL2016N2-Users.sql
Notepad C:\temp\SQL2016N2-Users.sql 

## Export users from a database
Export-SqlUser -SqlInstance SQL2016N2 -FilePath C:\temp\SQL2016N2-Fadetoblack.sql -Databases Fadetoblack
notepad C:\temp\SQL2016N2-Fadetoblack.sql   

## Export a single user from a database
Export-SqlUser -SqlInstance SQL2016N2 -FilePath C:\temp\SQL2016N2-Lars-Fadetoblack.sql -User UlrichLars -Databases Fadetoblack
notepad C:\temp\SQL2016N2-Lars-Fadetoblack.sql         


## export for a different version
Export-SqlUser -SqlInstance SQL2016N2 -Databases FadetoBlack -User TheManager  -FilePath C:\temp\SQL2016N2-Manager-2000.sql  -DestinationVersion SQLServer2000
Notepad C:\temp\SQL2016N2-Manager-2000.sql 

  Export-SqlUser -SqlInstance SQL2016N2 -FilePath C:\temp\SQL2016N2-Users-2000.sql  -DestinationVersion SQLServer2000
 Notepad C:\temp\SQL2016N2-Users-2000.sql 
 