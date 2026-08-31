USE SQLDataEngineeringLab;
GO

INSERT INTO rpt.DimProduct
(
    ProductId,
    ProductName,
    Category,
    Price,
    CreationDate
)
SELECT
    p.ProductId,
    p.ProductName,
    p.StdCategory,
    p.Price,
    p.CreationDate

FROM stg.Products p

WHERE p.IsValid = 1
AND NOT EXISTS (SELECT 1 FROM
                rpt.DimProduct dp
                WHERE p.ProductId = dp.ProductId);
GO