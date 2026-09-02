USE SQLDataEngineeringLab;
GO

-- Find the existing unique constraint on CustomerId and drop it if it exists.
-- This is necessary for SCD Type 2 because a customer can have multiple
-- historical dimension rows with the same CustomerId.

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
  AND t.name = 'DimCustomer'
  AND c.name = 'CustomerId';

IF @ConstraintName IS NOT NULL
BEGIN
    EXEC(
        'ALTER TABLE rpt.DimCustomer DROP CONSTRAINT '
        + QUOTENAME(@ConstraintName)
    );
END;
GO

--Add columns for SCD load (slowly changing dimension)
ALTER TABLE rpt.DimCustomer
ADD
    EffectiveFrom DATETIME2 NOT NULL
        CONSTRAINT DF_DimCustomer_EffectiveFrom DEFAULT SYSDATETIME(),
    EffectiveTo DATETIME2 NULL,
    IsCurrent BIT NOT NULL
        CONSTRAINT DF_DimCustomer_IsCurrent DEFAULT 1;
GO


--create filtered unique index to prevent multiple instances of IsCurrent = 1
CREATE UNIQUE INDEX UX_DimCustomer_CustomerId_IsCurrent
ON rpt.DimCustomer(CustomerId)
WHERE IsCurrent = 1;
GO