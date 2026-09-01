USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#OrderItemTransform') IS NOT NULL
    DROP TABLE #OrderItemTransform;

-- Build #OrderItemTransform
CREATE TABLE #OrderItemTransform
(
    OrderItemId INT PRIMARY KEY,
    OrderId INT NOT NULL,
    ProductId INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);

INSERT INTO #OrderItemTransform
(
    OrderItemId,
    OrderId,
    ProductId,
    Quantity,
    UnitPrice,
    IsValid,
    ValidationMessage
)
SELECT
        oi.OrderItemId,
		oi.OrderId,
		oi.ProductId,
		oi.Quantity,
		oi.UnitPrice,
		CASE 
			WHEN oi.Quantity <= 0 THEN 0
			WHEN oi.UnitPrice <= 0 THEN 0
			ELSE 1
		END as IsValid,
		NULLIF(
        CONCAT_WS(
            '; ',
            CASE
                WHEN oi.Quantity <= 0
                    THEN 'Quantity must be greater than 0'
            END,
            CASE
                WHEN oi.UnitPrice <= 0
                    THEN 'UnitPrice must be greater than 0'
            END
                ),
                ''
            ) AS ValidationMessage
    FROM src.OrderItems oi;

BEGIN TRY
    BEGIN TRANSACTION;
--Update existing rows that changed

UPDATE soi
    SET
        soi.OrderId = oit.OrderId,
        soi.ProductId = oit.ProductId,
        soi.Quantity = oit.Quantity,
        soi.UnitPrice = oit.UnitPrice,
        soi.StagedDate = SYSDATETIME(),
        soi.IsValid = oit.IsValid,
        soi.ValidationMessage = oit.ValidationMessage

    FROM stg.OrderItems soi
    INNER JOIN #OrderItemTransform oit
        ON soi.OrderItemId = oit.OrderItemId
    WHERE
       soi.OrderId <> oit.OrderId
    OR soi.ProductId <> oit.ProductId
    OR soi.Quantity <> oit.Quantity
    OR soi.UnitPrice <> oit.UnitPrice
    OR soi.IsValid <> oit.IsValid
    OR ISNULL(soi.ValidationMessage, '') <> ISNULL(oit.ValidationMessage, '');

    --insert rows that don't exist
    INSERT INTO stg.OrderItems
    (
        OrderItemId,
        OrderId,
        ProductId,
        Quantity,
        UnitPrice,
        IsValid,
        ValidationMessage
    )
    SELECT
        oit.OrderItemId,
        oit.OrderId,
        oit.ProductId,
        oit.Quantity,
        oit.UnitPrice,
        oit.IsValid,
        oit.ValidationMessage
    FROM #OrderItemTransform oit
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM stg.OrderItems soi
        WHERE soi.OrderItemId = oit.OrderItemId
    );


     COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
