USE SQLDataEngineeringLab;
GO

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
INNER JOIN rpt.DimProduct p
    ON oi.ProductId = p.ProductId
INNER JOIN rpt.DimDate d
    ON CAST(o.OrderDate AS DATE) = d.FullDate

WHERE oi.IsValid = 1
  AND o.IsValid = 1
  AND NOT EXISTS (
      SELECT 1
      FROM rpt.FactSales fs
      WHERE fs.OrderItemId = oi.OrderItemId
  );
GO