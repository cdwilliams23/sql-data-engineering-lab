USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#FactSalesCurrent') IS NOT NULL
    DROP TABLE #FactSalesCurrent;

CREATE TABLE #FactSalesCurrent
(
    OrderItemId INT PRIMARY KEY,
    OrderId INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    DateKey INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    SalesAmount DECIMAL(12,2) NOT NULL
);

INSERT INTO #FactSalesCurrent
(
    OrderItemId,
    OrderId,
    CustomerKey,
    ProductKey,
    DateKey,
    Quantity,
    UnitPrice,
    SalesAmount
)
SELECT
    oi.OrderItemId,
    oi.OrderId,
    c.CustomerKey,
    p.ProductKey,
    d.DateKey,
    oi.Quantity,
    oi.UnitPrice,
    oi.Quantity * oi.UnitPrice AS SalesAmount

FROM stg.OrderItems oi
INNER JOIN stg.Orders o
    ON oi.OrderId = o.OrderId
INNER JOIN rpt.DimCustomer c
    ON o.CustomerId = c.CustomerId
    AND o.OrderDate >= c.EffectiveFrom
    AND (
        o.OrderDate < c.EffectiveTo
        OR c.EffectiveTo IS NULL
    )
INNER JOIN rpt.DimProduct p
    ON oi.ProductId = p.ProductId
INNER JOIN rpt.DimDate d
    ON CAST(o.OrderDate AS DATE) = d.FullDate

WHERE oi.IsValid = 1
  AND o.IsValid = 1;

BEGIN TRY
   BEGIN TRANSACTION;

--Update existing rows that changed
UPDATE fs
 SET
    fs.OrderId = fsc.OrderId,
    fs.CustomerKey = fsc.CustomerKey,
    fs.ProductKey = fsc.ProductKey,
    fs.DateKey = fsc.DateKey,
    fs.Quantity = fsc.Quantity,
    fs.UnitPrice = fsc.UnitPrice,
    fs.SalesAmount = fsc.SalesAmount

 FROM rpt.FactSales fs
 INNER JOIN #FactSalesCurrent fsc
 ON fs.OrderItemId = fsc.OrderItemId
 WHERE fs.OrderId <> fsc.OrderId
 OR fs.CustomerKey <> fsc.CustomerKey
 OR fs.ProductKey <> fsc.ProductKey
 OR fs.DateKey <> fsc.DateKey
 OR fs.Quantity <> fsc.Quantity
 OR fs.UnitPrice <> fsc.UnitPrice
 OR fs.SalesAmount <> fsc.SalesAmount;

 --Insert new rows
INSERT INTO rpt.FactSales
(
    OrderItemId,
    OrderId,
    CustomerKey,
    ProductKey,
    DateKey,
    Quantity,
    UnitPrice,
    SalesAmount
)
SELECT
    fsc.OrderItemId,
    fsc.OrderId,
    fsc.CustomerKey,
    fsc.ProductKey,
    fsc.DateKey,
    fsc.Quantity,
    fsc.UnitPrice,
    fsc.SalesAmount
FROM #FactSalesCurrent fsc
WHERE NOT EXISTS
(
    SELECT 1
    FROM rpt.FactSales fs
    WHERE fs.OrderItemId = fsc.OrderItemId
);

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

