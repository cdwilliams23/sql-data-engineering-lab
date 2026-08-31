USE SQLDataEngineeringLab;
GO

INSERT INTO rpt.DimCustomer
(
    CustomerId,
    FirstName,
    LastName,
    Email,
    CreatedDate
)
SELECT
    c.CustomerId,
    c.FirstName,
    c.LastName,
    c.Email,
    c.CreatedDate

FROM stg.Customers c

WHERE c.IsValid = 1
AND NOT EXISTS (SELECT 1 FROM
                rpt.DimCustomer dc
                WHERE c.CustomerId = dc.CustomerId);
GO