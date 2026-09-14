USE SQLDataEngineeringLab;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadDimProduct
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#ProductCurrent') IS NOT NULL
        DROP TABLE #ProductCurrent;

    CREATE TABLE #ProductCurrent
    (
        ProductId INT PRIMARY KEY,
        ProductName VARCHAR(255) NOT NULL,
        Category VARCHAR(100) NOT NULL,
        Price DECIMAL(10,2) NOT NULL,
        CreationDate DATETIME2 NOT NULL
    );

    INSERT INTO #ProductCurrent
    (
        ProductId,
        ProductName,
        Category,
        Price,
        CreationDate
    )
    SELECT
        ProductId,
        ProductName,
        StdCategory,
        Price,
        CreationDate
    FROM stg.Products
    WHERE IsValid = 1;

    BEGIN TRY

        DECLARE @CurrentTimeStamp DATETIME2 = SYSDATETIME();

        -- Update CreationDate and Price for every version of ProductId (Type 1)
        UPDATE dp
        SET
            dp.CreationDate = pc.CreationDate,
            dp.Price = pc.Price
        FROM rpt.DimProduct dp
        INNER JOIN #ProductCurrent pc
            ON dp.ProductId = pc.ProductId
        WHERE dp.CreationDate <> pc.CreationDate
           OR dp.Price <> pc.Price;

        -- Expire the current SCD2 row
        UPDATE dp
        SET
            dp.EffectiveTo = @CurrentTimeStamp,
            dp.IsCurrent = 0
        FROM rpt.DimProduct dp
        INNER JOIN #ProductCurrent pc
            ON dp.ProductId = pc.ProductId
        WHERE dp.IsCurrent = 1
          AND
          (
                 dp.ProductName <> pc.ProductName
              OR dp.Category <> pc.Category
          );

        -- Insert new versions of existing products
        INSERT INTO rpt.DimProduct
        (
            ProductId,
            ProductName,
            Category,
            Price,
            CreationDate,
            EffectiveFrom,
            EffectiveTo,
            IsCurrent
        )
        SELECT
            pc.ProductId,
            pc.ProductName,
            pc.Category,
            pc.Price,
            pc.CreationDate,
            @CurrentTimeStamp,
            NULL,
            1
        FROM #ProductCurrent pc
        WHERE EXISTS
        (
            SELECT 1
            FROM rpt.DimProduct dp
            WHERE dp.ProductId = pc.ProductId
        )
        AND NOT EXISTS
        (
            SELECT 1
            FROM rpt.DimProduct dp
            WHERE dp.ProductId = pc.ProductId
              AND dp.IsCurrent = 1
        );

        -- Insert brand-new products
        INSERT INTO rpt.DimProduct
        (
            ProductId,
            ProductName,
            Category,
            Price,
            CreationDate,
            EffectiveFrom,
            EffectiveTo,
            IsCurrent
        )
        SELECT
            pc.ProductId,
            pc.ProductName,
            pc.Category,
            pc.Price,
            pc.CreationDate,
            pc.CreationDate,
            NULL,
            1
        FROM #ProductCurrent pc
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM rpt.DimProduct dp
            WHERE dp.ProductId = pc.ProductId
        );

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO