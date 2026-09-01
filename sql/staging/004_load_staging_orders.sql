USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#OrderTransform') IS NOT NULL
    DROP TABLE #OrderTransform;

-- Build #OrderTransform
CREATE TABLE #OrderTransform
(
    OrderId INT PRIMARY KEY,
    CustomerId INT NOT NULL,
    OrderDate DATETIME2 NOT NULL,
    OrderStatus VARCHAR(100) NOT NULL,
    StdOrderStatus VARCHAR(100) NULL,
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);

INSERT INTO #OrderTransform
(
    OrderId,
    CustomerId,
    OrderDate,
    OrderStatus,
    StdOrderStatus,
    IsValid,
    ValidationMessage
)
SELECT
    o.OrderId,
    o.CustomerId,
    o.OrderDate,
    o.OrderStatus,
    CASE
        WHEN LOWER(TRIM(o.OrderStatus)) = 'done' THEN 'Completed'
        WHEN LOWER(TRIM(o.OrderStatus)) IN ('pend', 'pending') THEN 'Pending'
        WHEN LOWER(TRIM(o.OrderStatus)) = 'cancel' THEN 'Cancelled'
        ELSE NULL
    END AS StdOrderStatus,
    CASE
        WHEN LOWER(TRIM(o.OrderStatus)) NOT IN ('done', 'pend', 'pending', 'cancel') THEN 0
        WHEN o.OrderDate < c.CreatedDate THEN 0
        ELSE 1
    END AS IsValid,
    NULLIF(
        CONCAT_WS(
            '; ',
            CASE
                WHEN LOWER(TRIM(o.OrderStatus)) NOT IN ('done', 'pend', 'pending', 'cancel')
                    THEN 'Unknown Order Status'
            END,
            CASE
                WHEN o.OrderDate < c.CreatedDate
                    THEN 'Order date occurs before customer creation date'
            END
        ),
        ''
    ) AS ValidationMessage
FROM src.Orders o
INNER JOIN src.Customers c
    ON o.CustomerId = c.CustomerId;


BEGIN TRY
    BEGIN TRANSACTION;
--Update existing rows that changed

UPDATE so
    SET
        so.CustomerId = ot.CustomerId,
        so.OrderDate = ot.OrderDate,
        so.OrderStatus = ot.OrderStatus,
        so.StdOrderStatus = ot.StdOrderStatus,
        so.StagedDate = SYSDATETIME(),
        so.IsValid = ot.IsValid,
        so.ValidationMessage = ot.ValidationMessage

    FROM stg.Orders so
    INNER JOIN #OrderTransform ot
        ON so.OrderId = ot.OrderId
    WHERE
       so.CustomerId <> ot.CustomerId
    OR so.OrderDate <> ot.OrderDate
    OR so.OrderStatus <> ot.OrderStatus
    OR ISNULL(so.StdOrderStatus, '') <> ISNULL(ot.StdOrderStatus, '')
    OR so.IsValid <> ot.IsValid
    OR ISNULL(so.ValidationMessage, '') <> ISNULL(ot.ValidationMessage, '');

    --insert rows that don't exist
    INSERT INTO stg.Orders
    (
        OrderId,
        CustomerId,
        OrderDate,
        OrderStatus,
        StdOrderStatus,
        IsValid,
        ValidationMessage
    )
    SELECT
        ot.OrderId,
        ot.CustomerId,
        ot.OrderDate,
        ot.OrderStatus,
        ot.StdOrderStatus,
        ot.IsValid,
        ot.ValidationMessage
    FROM #OrderTransform ot
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM stg.Orders so
        WHERE so.OrderId = ot.OrderId
    );


     COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

