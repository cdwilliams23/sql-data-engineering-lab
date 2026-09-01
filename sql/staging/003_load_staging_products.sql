USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#ProductTransform') IS NOT NULL
    DROP TABLE #ProductTransform;

-- Build #ProductTransform
CREATE TABLE #ProductTransform
(
    ProductId INT PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    StdCategory VARCHAR(100) NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreationDate DATETIME2 NOT NULL,
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);

INSERT INTO #ProductTransform
(
    ProductId,
    ProductName,
    Category,
    StdCategory,
    Price,
    CreationDate,
    IsValid,
    ValidationMessage
)
SELECT
    p.ProductId,
    p.ProductName,
    p.Category,

    CASE
        WHEN LOWER(TRIM(p.Category)) = 'tech' THEN 'Technology'
        WHEN LOWER(TRIM(p.Category)) = 'clothing' THEN 'Clothing'
        WHEN LOWER(TRIM(p.Category)) = 'appliance' THEN 'Appliance'
        ELSE NULL
    END AS StdCategory,

    p.Price,
    p.CreationDate,

    CASE
        WHEN LOWER(TRIM(p.Category)) NOT IN ('tech','clothing','appliance') THEN 0
        ELSE 1
    END AS IsValid,

    CASE
        WHEN LOWER(TRIM(p.Category)) NOT IN ('tech','clothing','appliance')
            THEN 'Unknown Product Category'
    END AS ValidationMessage

FROM src.Products p;

BEGIN TRY
    BEGIN TRANSACTION;
--Update existing rows that changed

UPDATE sp
    SET
        sp.ProductName = pt.ProductName,
        sp.Category = pt.Category,
        sp.StdCategory = pt.StdCategory,
        sp.Price = pt.Price,
        sp.CreationDate = pt.CreationDate,       
        sp.StagedDate = SYSDATETIME(),
        sp.IsValid = pt.IsValid,
        sp.ValidationMessage = pt.ValidationMessage

    FROM stg.Products sp
    INNER JOIN #ProductTransform pt
        ON sp.ProductId = pt.ProductId
    WHERE
       sp.ProductName <> pt.ProductName
    OR sp.Category <> pt.Category
    OR ISNULL(sp.StdCategory, '') <> ISNULL(pt.StdCategory, '')
    OR sp.Price <> pt.Price
    OR sp.CreationDate <> pt.CreationDate
    OR sp.IsValid <> pt.IsValid
    OR ISNULL(sp.ValidationMessage, '') <> ISNULL(pt.ValidationMessage, '');

    --insert rows that don't exist
    INSERT INTO stg.Products
    (
        ProductId,
        ProductName,
        Category,
        StdCategory,
        Price,
        CreationDate,
        IsValid,
        ValidationMessage
    )
    SELECT
        pt.ProductId,
        pt.ProductName,
        pt.Category,
        pt.StdCategory,
        pt.Price,
        pt.CreationDate,
        pt.IsValid,
        pt.ValidationMessage
    FROM #ProductTransform pt
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM stg.Products sp
        WHERE sp.ProductId = pt.ProductId
    );


     COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO