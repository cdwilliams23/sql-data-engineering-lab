USE SQLDataEngineeringLab;
GO

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
	o.OrderId,
	o.CustomerId,
	o.OrderDate,
	o.OrderStatus,
	CASE 
		WHEN LOWER(TRIM(o.OrderStatus)) = 'done' THEN 'Completed'
		WHEN LOWER(TRIM(o.OrderStatus)) = 'pend' THEN 'Pending'
		WHEN LOWER(TRIM(o.OrderStatus)) = 'pending' THEN 'Pending'
		WHEN LOWER(TRIM(o.OrderStatus)) = 'cancel' THEN 'Cancelled'
		ELSE NULL
	END as StdOrderStatus,
	CASE
		WHEN LOWER(TRIM(o.OrderStatus)) NOT IN ('done','pend','pending','cancel') THEN 0
        WHEN o.OrderDate < c.CreatedDate THEN 0		
        ELSE 1
    END AS IsValid,
	NULLIF(
        CONCAT_WS(
            '; ',
            CASE
                WHEN LOWER(TRIM(o.OrderStatus)) NOT IN ('done','pend','pending','cancel')
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
LEFT OUTER JOIN src.Customers c
on o.CustomerId = c.CustomerId
WHERE NOT EXISTS ( SELECT 1 FROM
				   stg.Orders so
				   WHERE so.OrderId = o.OrderId)