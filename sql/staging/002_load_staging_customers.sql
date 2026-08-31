USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#CustomerTransform') IS NOT NULL 
    DROP TABLE #CustomerTransform;

    --Build #CustomerTransform

CREATE TABLE #CustomerTransform
(
    CustomerId INT PRIMARY KEY,
    FirstName VARCHAR(100) NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    CreatedDate DATETIME2 NOT NULL,
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);

INSERT INTO #CustomerTransform
(  
    CustomerId,
    FirstName,
    LastName,
    Email,
    CreatedDate,
    IsValid,
    ValidationMessage
)
SELECT
        c.CustomerId,
        c.FirstName,
        c.LastName,
        LOWER(TRIM(c.Email)) AS Email,
        c.CreatedDate,
        CASE
            WHEN c.Email IS NULL THEN 0
            WHEN c.CreatedDate > o.EarliestOrderDate THEN 0
            ELSE 1
        END AS IsValid,
        NULLIF(
            CONCAT_WS(
                '; ',
                CASE
                    WHEN c.Email IS NULL THEN 'Email is missing'
                END,
                CASE
                    WHEN c.CreatedDate > o.EarliestOrderDate
                        THEN 'Customer creation date occurs after first order date'
                END
            ),
            ''
        ) AS ValidationMessage
    FROM src.Customers c
    LEFT JOIN
    (
        SELECT
            CustomerId,
            MIN(OrderDate) AS EarliestOrderDate
        FROM src.Orders
        GROUP BY CustomerId
    ) o
        ON c.CustomerId = o.CustomerId;

BEGIN TRY
    BEGIN TRANSACTION;
    --Update existing rows that changed

    UPDATE sc
    SET
        sc.FirstName = ct.FirstName,
        sc.LastName = ct.LastName,
        sc.Email = ct.Email,
        sc.CreatedDate = ct.CreatedDate,
        sc.StagedDate = SYSDATETIME(),
        sc.IsValid = ct.IsValid,
        sc.ValidationMessage = ct.ValidationMessage
    FROM stg.Customers sc
    INNER JOIN #CustomerTransform ct
        ON sc.CustomerId = ct.CustomerId
    WHERE
       ISNULL(sc.FirstName, '') <> ISNULL(ct.FirstName, '')
    OR sc.LastName <> ct.LastName
    OR ISNULL(sc.Email, '') <> ISNULL(ct.Email, '')
    OR sc.CreatedDate <> ct.CreatedDate
    OR sc.IsValid <> ct.IsValid
    OR ISNULL(sc.ValidationMessage, '') <> ISNULL(ct.ValidationMessage, '');


    --insert rows that dont exist
    INSERT INTO stg.Customers
    (
        CustomerId,
        FirstName,
        LastName,
        Email,
        CreatedDate,
        IsValid,
        ValidationMessage
    )
    SELECT
        ct.CustomerId,
        ct.FirstName,
        ct.LastName,
        ct.Email,
        ct.CreatedDate,
        ct.IsValid,
        ct.ValidationMessage
    FROM #CustomerTransform ct
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM stg.Customers sc
        WHERE sc.CustomerId = ct.CustomerId
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO


