/******************
* Script:     CDM Functions and Procedures
* Description:    This script defines the supporting procedures and functions called in CDM main script.
*
*              Multiple SQL concepts such as common table expressions (CTE) will be highlighted with comment chunks.
*              
* Creation Date:  25/05/2023
* Author: Alvis Chan
* Version:
*     - 1.0 - AC - 25/05 - Initial release
*
******************/

/*
  Procedure: importCSV
  Parameters: @filepath, the file path of CSV to be imported into SQL server. (returns user guide if left empty)
              @tableName, the table name in SQL server
  Description: Imports @fileName as a table in SQL server

  Example: dbo.[importCSV] @filePath = 'C:\folder\test.csv, @tableName = test'
*/
DROP PROCEDURE IF EXISTS dbo.[importCSV]
GO
CREATE PROCEDURE dbo.[importCSV]
    @filepath NVARCHAR(200) = NULL,
    @tableName NVARCHAR(200) = NULL
AS
BEGIN

    IF(@filePath IS NULL OR @tableName IS NULL)
        BEGIN
            PRINT '
                Procedure importCSV imports @fileName as default_import in SQL server.
                Example: dbo.[importCSV] @filePath = ''C:\folder\test.csv''
            '
            ;

            RETURN
        END
    ;

    DECLARE @queryString NVARCHAR(MAX)

    SET @queryString = 'TRUNCATE TABLE ' + @tableName

    EXEC sp_executesql @queryString

    SET @queryString = 'BULK INSERT ' + @tableName + '
			FROM ''' + @filepath + '''
			WITH(
    				CODEPAGE = ''65001'',
    				FORMAT = ''CSV'',
    				FIRSTROW = 2,
    				MAXERRORS = 2,
    				FIELDTERMINATOR = '','',
    				ROWTERMINATOR = ''\n''
			);'
    ;

	EXEC sp_executesql @queryString
END

GO

/*
  Function: CountBackSlash
  Parameters: @filepath, string variable
  Description: counts number of backslash characters '\' in @filepath
*/
DROP FUNCTION IF EXISTS [dbo].CountBackSlash
GO
CREATE FUNCTION [dbo].CountBackSlash(
    @filepath NVARCHAR(200)
)
RETURNS INT
AS 
BEGIN
    DECLARE @temp NVARCHAR(200)
    SET @temp = REPLACE(@filepath,'\','')
    RETURN LEN(@filepath) - LEN(@temp)
END

GO

/*
  Function: GenerateKey
  Parameters: @string1, @string2, @string3, strings used for creating a key
  Description: Generates a key based on 3 strings
*/
DROP FUNCTION IF EXISTS [dbo].[GenerateKey]
GO
CREATE FUNCTION [dbo].[GenerateKey] (
    @string1 NVARCHAR(500),
    @string2 NVARCHAR(500),
    @string3 NVARCHAR(500)
)
RETURNS NVARCHAR(1500)
AS
BEGIN
    DECLARE @key NVARCHAR(1500) = ''

    -- Remove spaces from the strings
    SET @string1 = REPLACE(@string1, ' ', '')
    SET @string2 = REPLACE(@string2, ' ', '')
    SET @string3 = REPLACE(@string3, ' ', '')
	
	DECLARE @maxLength INT = (SELECT MAX(LEN(s))
                          FROM (VALUES (@string1), (@string2), (@string3)) AS T(s))
	DECLARE @i INT = 1

	WHILE @i <= @maxLength
	BEGIN
		IF @i <= LEN(@string1)
			SET @key = @key + SUBSTRING(@string1, @i, 1)
		IF @i <= LEN(@string2)
			SET @key = @key + SUBSTRING(@string2, @i, 1)
		IF @i <= LEN(@string3)
			SET @key = @key + SUBSTRING(@string3, @i, 1)
    
		SET @i = @i + 1
	END

    RETURN @key
END

GO
