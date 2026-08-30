USE SQLDataEngineeringLab;
GO

INSERT INTO stg.Products 
      (
	  ProductId,
	  ProductName, 
	  Category,
      Price,
      CreationDate,
      StdCategory,
      IsValid,
      ValidationMessage
      )
SELECT
    p.ProductId,
    p.ProductName,
    p.Category,
    p.Price,
    p.CreationDate,
    CASE WHEN LOWER(TRIM(p.Category)) = 'tech' THEN 'Technology'
         WHEN LOWER(TRIM(p.Category)) = 'clothing' THEN 'Clothing'
         WHEN LOWER(TRIM(p.Category)) = 'appliance' THEN 'Appliance'
         ELSE NULL
         END as StdCategory,

    CASE WHEN LOWER(TRIM(p.Category)) NOT IN ('tech','clothing','appliance') THEN 0     
         ELSE 1
         END as IsValid,

    CASE WHEN LOWER(TRIM(p.Category)) NOT IN ('tech','clothing','appliance') THEN 'Unknown Product Category' 
         END as ValidationMessage

    FROM src.Products p
    WHERE NOT EXISTS (SELECT 1 FROM
                      stg.Products sp
                      WHERE sp.ProductId = p.ProductId) ;
  GO