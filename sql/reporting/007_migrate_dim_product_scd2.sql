USE SQLDataEngineeringLab;
GO

-- Find the existing unique constraint on ProductId and drop it if it exists.
-- This is necessary for SCD Type 2 because a product can have multiple
-- historical dimension rows with the same ProductId.

DECLARE @ConstraintName SYSNAME;

SELECT @ConstraintName = i.name
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.indexes AS i
    ON t.object_id = i.object_id
    AND i.is_unique_constraint = 1
INNER JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
INNER JOIN sys.columns AS c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE s.name = 'rpt'
  AND t.name = 'DimProduct'
  AND c.name = 'ProductId';


IF @ConstraintName IS NOT NULL
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL =
        'ALTER TABLE rpt.DimProduct DROP CONSTRAINT '
        + QUOTENAME(@ConstraintName);

    EXEC(@SQL);
END;
GO

--Add columns for SCD load (slowly changing dimension)
ALTER TABLE rpt.DimProduct
ADD
    EffectiveFrom DATETIME2 NOT NULL
        CONSTRAINT DF_DimProduct_EffectiveFrom DEFAULT SYSDATETIME(),
    EffectiveTo DATETIME2 NULL,
    IsCurrent BIT NOT NULL
        CONSTRAINT DF_DimProduct_IsCurrent DEFAULT 1;
GO

-- The existing dimension row represents the first known version of each product.
-- Use the product's business CreatedDate as the beginning of that version.
UPDATE rpt.DimProduct
SET EffectiveFrom = CreationDate;
GO


-- Create filtered unique index to prevent multiple current rows
-- for the same ProductId.
CREATE UNIQUE INDEX UX_DimProduct_ProductId_IsCurrent
ON rpt.DimProduct(ProductId)
WHERE IsCurrent = 1;
GO