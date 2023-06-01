/******************
* Script:     CDM Tables
* Description:    This script defines the tables called in CDM main script and procedures.
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
  Table: default_import
  Description: Holds the original import from 
*/
DROP TABLE IF EXISTS default_import
GO
CREATE TABLE default_import (
    [PSPath] NVARCHAR(MAX),
    [PSParentPath] NVARCHAR(MAX),
    [PSChildName] NVARCHAR(MAX),
    [PSDrive] NVARCHAR(MAX),
    [PSProvider] NVARCHAR(MAX),
    [PSIsContainer] NVARCHAR(MAX),
    [Mode] NVARCHAR(MAX),
    [BaseName] NVARCHAR(MAX),
    [Target] NVARCHAR(MAX),
    [LinkType] NVARCHAR(MAX),
    [Name] NVARCHAR(MAX),
    [FullName] NVARCHAR(MAX),
    [Parent] NVARCHAR(MAX),
    [Exists] NVARCHAR(MAX),
    [Root] NVARCHAR(MAX),
    [Extension] NVARCHAR(MAX),
    [CreationTime] NVARCHAR(MAX),
    [CreationTimeUtc] NVARCHAR(MAX),
    [LastAccessTime] NVARCHAR(MAX),
    [LastAccessTimeUtc] NVARCHAR(MAX),
    [LastWriteTime] NVARCHAR(MAX),
    [LastWriteTimeUtc] NVARCHAR(MAX),
    [Attributes] NVARCHAR(MAX)
)


/*
  Table: TRUNCATED_rows
  Description: Generate empty table for containing rows with oversized values.
*/
DROP TABLE IF EXISTS [TRUNCATED_rows]
SELECT * INTO [TRUNCATED_rows] 
FROM [dbo].[default_import]
WHERE 0 = 1

/*
  Table: processed_import
  Description: Holds the column length processed import 
*/
DROP TABLE IF EXISTS processed_import
GO
CREATE TABLE processed_import (
    [PSPath] NVARCHAR(200),
    [PSParentPath] NVARCHAR(200),
    [PSChildName] NVARCHAR(200),
    [PSDrive] NVARCHAR(200),
    [PSProvider] NVARCHAR(200),
    [PSIsContainer] NVARCHAR(200),
    [Mode] NVARCHAR(200),
    [BaseName] NVARCHAR(200),
    [Target] NVARCHAR(200),
    [LinkType] NVARCHAR(200),
    [Name] NVARCHAR(200),
    [FullName] NVARCHAR(200),
    [Parent] NVARCHAR(200),
    [Exists] NVARCHAR(200),
    [Root] NVARCHAR(200),
    [Extension] NVARCHAR(200),
    [CreationTime] NVARCHAR(200),
    [CreationTimeUtc] NVARCHAR(200),
    [LastAccessTime] NVARCHAR(200),
    [LastAccessTimeUtc] NVARCHAR(200),
    [LastWriteTime] NVARCHAR(200),
    [LastWriteTimeUtc] NVARCHAR(200),
    [Attributes] NVARCHAR(200)
)

/*
  Table: Illegal_characters_listing
  Description: Defines illegal characters that should not be included in folder names and file names.

  Comment: Offers flexibility when working with strings. These can be safe characters used for replace functions.
*/
CREATE TABLE [dbo].[ILLEGAL_CHARACTERS_LISTING]
    (
        [IllegalCharacters] [NVARCHAR](20) NOT NULL
    )
;

-- Insert data set into illegal extensions table
INSERT INTO [dbo].[ILLEGAL_CHARACTERS_LISTING]
	(IllegalCharacters)
    VALUES
   	('?'),('$'),('%'),('~')

GO	
