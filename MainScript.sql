/******************
* Project:     Streamlining Cloud Platform Document Migration (CDM)
* Description:    This script defines procedures that retrieves a CSV generated with get-childItem (GCI) in powershell and imports it into SQL Server and runs 
*              through different processes of filtering, cleaning and basic analysis using the tables, functions and procedures pre-created with other scripts. 
*              Then finally some output CSV files including a cleaned CSV file, summary file and error file will be produced. The process is automatic from 
*              beginning to end upon procedure execution.
*                 Additionally this project will be compeltely contained in SQL files (Although generating the CSV will require a line of powershell).
*
*              Multiple SQL concepts such as common table expressions (CTE) and cursors will be highlighted with comment chunks.
*
* Applicability:  While the operations below can be compelted purely with PowerShell, or interchangeablly with SQL, it can be difficult to interpret the 
*               process and progress of the script which significantly impacts the maintainability and readability of the procedures. By limiting ulanguage
*               used to SQL only, the processes are much more apparent and it offers much more flexibility for filtering or updating data using SSMS tables
*               at the cost of a slight increase and loss in some PowerShell functionality in runtime compared to pure PowerShell.
*               
*              
* Dependencies:  The following files need to be ran first before running this script. Though creating the procedures only will not raise any issues.
*               - CreTab.sql: Creates the tables
*               - ProFu.sql: Creates the supporting procedures and functions
*
* Creation Date:  25/05/2023
* Author: Alvis Chan
* Version:
*     - 1.0 - AC - 25/05 - Initial release
*
******************/

/*
 Procedure: Initial_import
 Parameter: @rootPath, path to CSV file to be imported (Currently restricted to CSV generated from GCI in PowerShell)
 Description: Imports the CSV and scans for oversized values in the CSV
*/
DROP PROCEDURE IF EXISTS dbo.[Initial_import]
GO
CREATE PROCEDURE dbo.[Initial_import]
    @rootPath NVARCHAR(200) = NULL
AS
BEGIN
    -- Import the CSV file into the temporary table
    EXEC dbo.[importCSV] @filePath = @rootPath, @tableName = 'default_import'

    /* Comment:
    -- Because of the nature of SQL tables, the maximum storage space allocated is pre-defined and
    -- cannot be changed and if data larger than defined sizes are inserted it will be truncated or 
    -- result in error output. Using maximum storage for each column puts a heavy load in the server, thus
    -- an optimisation is needed by storing the data in a temporary table first, than moving it to a 
    -- table with storage spaces 
    */

    -- Find the maximum length of the values in each column in the imported data
    DROP TABLE IF EXISTS #temp
    CREATE TABLE #temp (
        [ColumnName] NVARCHAR(MAX),
        [Length] NVARCHAR(MAX)
    )

    -- Cursor: Database object to traverse and process individual rows 
    -- variables for cursor use
    DECLARE @columnName NVARCHAR(MAX), @queryString NVARCHAR(MAX), @tempsize NVARCHAR(MAX)
    
    -- start cursor for column names
    DECLARE ColCursor CURSOR
    FOR SELECT name
        FROM sys.columns 
        WHERE object_id = OBJECT_ID('default_import')

    OPEN ColCursor

    -- get first value
    FETCH NEXT FROM ColCursor INTO
            @columnName

    WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @columnName = '['+@columnName+']'
            SET @tempSize = (SELECT CHARACTER_MAXIMUM_LENGTH 
                        FROM INFORMATION_SCHEMA.COLUMNS
                        WHERE TABLE_NAME = 'processed_import' AND COLUMN_NAME = SUBSTRING(@columnName,2,LEN(@columnName)-2))
            
            -- insert oversized rows into Truncated_Rows
            SET @queryString = 
                '
                INSERT INTO Truncated_Rows
                SELECT * FROM [dbo].[default_import]
                WHERE LEN(' + @columnName + ') > ' + @tempSize + '
                '
            ;

            EXEC sp_executesql @queryString

            -- Update TEMP_FS_IMPORT rows to ensure it fits in FS_Import
            SET @queryString = 
                '
                UPDATE [dbo].[default_import]
                SET ' +	@columnName + ' = CASE
                    WHEN ' + @tempsize + ' = -1 OR ' + @tempsize + ' IS NULL
                        THEN ' + @columnName + '
                    WHEN LEN(' + @columnName + ') > ' + @tempsize  + '
                        THEN SUBSTRING(' + @columnName + ',0,' + @tempsize + '-1)
                    ELSE' + @columnName + '
                END
                '
            ;

            EXEC sp_executesql @queryString

            -- get next column name
            FETCH NEXT FROM ColCursor INTO
                @columnName
        END
    CLOSE ColCursor
    DEALLOCATE ColCursor;
    -- end cursor

    -- Remove duplicates from Truncated_Rows
    WITH CTE AS (
        SELECT *,
            RN = ROW_NUMBER() OVER (PARTITION BY PSPath, FullName ORDER BY FullName)
        FROM [TRUNCATED_Rows]
    )
    DELETE FROM CTE WHERE RN > 1

    -- Insert from default_import into processed_import 
    SET @queryString = 
        '
        INSERT INTO [dbo].[processed_import]
        SELECT * FROM [dbo].[default_import]
        '
    ;

    EXEC sp_executesql @queryString

    -- Drop temporary table with max storage sizes
    -- DROP TABLE [dbo].[default_import]
END

GO 

/*
  Procedure: [dbo].[createCSV]
  Parameters: @tableName, table name to be output as CSV
              @location, location of CSV with desired file name
              @instance, SQL server name
              @cols, specific columns in @tableName want to be selected into CSV, ignoring other column names (If empty defaults to all columns in @tableName)
  Description: Upon execution, creates a csv format of the table @tableName in @ instance at @location

  Example: EXEC [dbo].[createCSV] @tableName = 'processed_import', @location = 'C:\Users\Alvis\Desktop\out.csv', @instance = 'DESKTOP-TEST\SQLEXPRESS01', @cols = NULL
*/
DROP PROCEDURE IF EXISTS [dbo].[createCSV]
GO
CREATE PROCEDURE [dbo].[createCSV] (
    @tableName NVARCHAR(100) = NULL,
    @location NVARCHAR(1000) = NULL,
    @instance NVARCHAR(300) = NULL,
    @cols NVARCHAR(MAX) = NULL
)
AS
BEGIN
    /* Comment:
        There are two restrictions for @queryString when used for calling cmd or powershell lines:
            1. It must be VARCHAR
            2. It cannot be largest size
        Therefore it is set as @queryString VARCHAR(5000)
    */
    DECLARE @queryString VARCHAR(5000), @selectQuery NVARCHAR(MAX)
	--DECLARE @tableName NVARCHAR(MAX) = 'processed_import', @location NVARCHAR(MAX) = 'C:\PROJECTS\processed.csv', @instance NVARCHAR(MAX) = 'DESKTOP-N7G9DBN\SQLEXPRESS01', @cols NVARCHAR(MAX) = NULL


    IF(@cols IS NULL)
        BEGIN
            SELECT @cols = COALESCE(@cols + ', ', '') + ''''+COLUMN_NAME+''''
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = @tableName
            ORDER BY ORDINAL_POSITION
        END

    -- Return error there is no table, location or instance
    IF(@tableName IS NULL OR @location IS NULL OR @instance IS NULL)
        BEGIN
            PRINT '[dbo].[CreateCSV]: Error in processing @tableName, @location or @instance'
            
            RETURN
        END

    --set @cols = '''col1'',''col2'',''col3''

    SET @selectQuery = 'select '+@cols+' union all select * from ' + @tableName

    --SET @location = 'C:\Users\Alvis\Desktop\out.csv'

    --SET @instance = 'DESKTOP-N7G9DBN\SQLEXPRESS01'

    SET @queryString = 'bcp "' + @selectQuery + '" queryout "' + @location + '" -c -t, -T -S "'+@instance+'"'

    EXEC xp_cmdshell @queryString
END

GO

-- This process is to ensure the function xp_cmdshell is not blocked by internal settings.
EXEC sp_configure 'show advanced options', '1'
RECONFIGURE
EXEC sp_configure 'xp_cmdshell', '1' 
RECONFIGURE

-- Main script:
EXEC Initial_import @rootPath = 'C:\PROJECTS\Input.csv'

DROP TABLE IF EXISTS filtered_import
DROP TABLE IF EXISTS illegal_folders
DROP TABLE IF EXISTS illegal_files

-- Filter needed columns
SELECT 
    REPLACE(PSPATH,PSProvider+'::','') AS FilePath,
    REPLACE(PSParentPath,PSProvider+'::','') AS ParentPath,
    BaseName,
    Extension,
    [dbo].[GenerateKey]([CreationTimeUtc],[LastAccessTime],[LastWriteTimeUtc]) AS [Key],
    CreationTimeUtc,
    LastAccessTimeUtc,
    LastWriteTimeUtc,
    Attributes
INTO filtered_import
FROM processed_import

-- Find folders with illegal names using regex and place into table
SELECT *
INTO illegal_folders
FROM filtered_import
WHERE FilePath NOT LIKE '%[' + (
    SELECT STRING_AGG([IllegalCharacters], '') WITHIN GROUP (ORDER BY [IllegalCharacters])
    FROM [ILLEGAL_CHARACTERS_LISTING]
    ) + ']%'
    AND Extension IS NULL


-- Find files with illegal names using regex and place into table
SELECT *
INTO illegal_files
FROM filtered_import
WHERE FilePath NOT LIKE '%[' + (
    SELECT STRING_AGG([IllegalCharacters], '') WITHIN GROUP (ORDER BY [IllegalCharacters])
    FROM [ILLEGAL_CHARACTERS_LISTING]
    ) + ']%'
    AND Attributes = 'Archive'

-- Remove illegal entries from filtered_import
DELETE --SELECT *
FROM filtered_import
WHERE FilePath LIKE '%[' + (
    SELECT STRING_AGG([IllegalCharacters], '') WITHIN GROUP (ORDER BY [IllegalCharacters])
    FROM [ILLEGAL_CHARACTERS_LISTING]
    ) + ']%'

-- Output the desired table into a usable CSV file for storage or further processing in other environments.
EXEC CreateCSV @tableName = 'filtered_import', @location = 'C:\PROJECTS\filtered.csv', @instance = 'DESKTOP-N7G9DBN\SQLEXPRESS01', @cols = NULL

