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
                WHEN c.Email IS NULL
                    THEN 'Email is missing'
            END,
            CASE
                WHEN c.CreatedDate > o.EarliestOrderDate
                    THEN 'Customer creation date occurs after first order date'
            END
        ),
        ''
    ) AS ValidationMessage

FROM src.Customers c
LEFT OUTER JOIN (
    SELECT
        CustomerId,
        MIN(OrderDate) AS EarliestOrderDate
    FROM src.Orders
    GROUP BY CustomerId
) o
    ON c.CustomerId = o.CustomerId

WHERE NOT EXISTS (SELECT 1 FROM
                stg.Customers sc
                WHERE sc.CustomerId = c.CustomerId)
