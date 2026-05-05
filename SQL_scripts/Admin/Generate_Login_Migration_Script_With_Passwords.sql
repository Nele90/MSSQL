DECLARE @login_name sysname
SET @login_name = NULL

DECLARE @name sysname
DECLARE @type varchar (1)
DECLARE @hasaccess int
DECLARE @denylogin int
DECLARE @is_disabled int
DECLARE @PWD_varbinary  varbinary (256)
DECLARE @PWD_string  varchar (514)
DECLARE @SID_varbinary varbinary (85)
DECLARE @SID_string varchar (514)
DECLARE @tmpstr  varchar (1024)
DECLARE @is_policy_checked varchar (3)
DECLARE @is_expiration_checked varchar (3)

DECLARE @defaultdb sysname

IF (@login_name IS NULL)
  DECLARE login_curs CURSOR FOR
    SELECT
      p.sid,
      p.name,
      p.type,
      p.is_disabled,
      p.default_database_name,
      l.hasaccess,
      l.denylogin
    FROM sys.server_principals p
    LEFT JOIN sys.syslogins l
    ON ( l.name = p.name )
    WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa'
ELSE
  DECLARE login_curs CURSOR FOR
    SELECT
      p.sid,
      p.name,
      p.type,
      p.is_disabled,
      p.default_database_name,
      l.hasaccess,
      l.denylogin
    FROM sys.server_principals p
    LEFT JOIN sys.syslogins l
    ON ( l.name = p.name )
    WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name = @login_name
OPEN login_curs

FETCH NEXT FROM login_curs
INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
IF (@@fetch_status = -1)
BEGIN
  PRINT 'No login(s) found.'
  CLOSE login_curs
  DEALLOCATE login_curs
END
SET @tmpstr = '/* sp_help_revlogin script '
PRINT @tmpstr
SET @tmpstr = '** Generated ' + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @tmpstr
PRINT ''
WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN
    PRINT ''
    SET @tmpstr = '-- Login: ' + @name
    PRINT @tmpstr
    IF (@type IN ( 'G', 'U'))
    BEGIN -- NT authenticated account/group

      SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) +
        ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
    END
    ELSE BEGIN -- SQL Server authentication
        -- obtain password and sid
        SET @PWD_varbinary = CAST( LOGINPROPERTY( @name, 'PasswordHash' ) AS varbinary (256) )
        SELECT
          @PWD_string = sys.fn_varbintohexstr(@PWD_varbinary),
          @SID_string = sys.fn_varbintohexstr(@SID_varbinary)

        -- obtain password policy state
        SELECT @is_policy_checked =
          CASE is_policy_checked
            WHEN 1 THEN 'ON'
            WHEN 0 THEN 'OFF'
            ELSE NULL
          END
        FROM sys.sql_logins WHERE name = @name
        SELECT @is_expiration_checked =
          CASE is_expiration_checked
            WHEN 1 THEN 'ON'
            WHEN 0 THEN 'OFF'
            ELSE NULL
          END
        FROM sys.sql_logins WHERE name = @name

        SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) +
          ' WITH PASSWORD = ' + @PWD_string +
          ' HASHED, SID = ' + @SID_string +
          ', DEFAULT_DATABASE = [' + @defaultdb + ']'

        IF ( @is_policy_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
        END
        IF ( @is_expiration_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
        END
    END
    IF (@denylogin = 1)
    BEGIN -- login is denied access
      SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME( @name )
    END
    ELSE IF (@hasaccess = 0)
    BEGIN -- login exists but does not have access
      SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO ' + QUOTENAME( @name )
    END
    IF (@is_disabled = 1)
    BEGIN -- login is disabled
      SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME( @name ) + ' DISABLE'
    END

    SELECT
      @tmpstr = @tmpstr + ISNULL(CHAR(13) + CHAR(10) + 'EXEC sp_addsrvrolemember ' +
      QUOTENAME(@name,'''') + ', ' + QUOTENAME(r.name,'''') + ';','')
    FROM sys.server_principals AS r
    INNER JOIN sys.server_role_members AS m
    ON r.principal_id = m.role_principal_id
    INNER JOIN sys.server_principals AS p
    ON p.principal_id = m.member_principal_id
    WHERE (p.type IN ('G', 'U', 'S')
    AND p.sid <> 0x01)
    AND p.name = @name

    SET @tmpstr = @tmpstr + CHAR(13) + CHAR(10) + 'GO'

    PRINT @tmpstr

  END

  FETCH NEXT FROM login_curs
  INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
END
CLOSE login_curs
DEALLOCATE login_curs
