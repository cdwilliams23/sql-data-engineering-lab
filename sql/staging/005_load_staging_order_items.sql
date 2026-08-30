USE SQLDataEngineeringLab;
GO

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
		oi.OrderItemId,
		oi.OrderId,
		oi.ProductId,
		oi.Quantity,
		oi.UnitPrice,
		CASE 
			WHEN oi.Quantity <=0 THEN 0
			WHEN oi.UnitPrice <= 0 THEN 0
			ELSE 1
		END as IsValid,
		NULLIF(
        CONCAT_WS(
            '; ',
            CASE
                WHEN oi.Quantity <0
                    THEN 'Quantity must be greater than 0'
            END,
            CASE
                WHEN oi.UnitPrice < 0
                    THEN 'UnitPrice must be greater than 0'
            END
        ),
        ''
    ) AS ValidationMessage
FROM src.OrderItems oi
WHERE NOT EXISTS (SELECT 1 FROM
				  stg.OrderItems si
				  WHERE si.OrderItemId = oi.OrderItemId
				  )
GO
