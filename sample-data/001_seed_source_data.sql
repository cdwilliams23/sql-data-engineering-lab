USE SQLDataEngineeringLab;
GO

INSERT INTO src.Customers
    (CustomerId, FirstName, LastName, Email, CreatedDate)
VALUES
    (1001, 'Andre', 'Brown', 'andre.brown@email.com', '2026-01-05 09:15:00'),
    (1002, 'Melissa', 'Grant', 'MELISSA.GRANT@email.com', '2026-01-08 14:22:00'),
    (1003, 'Kevin', 'Campbell', ' kevin.campbell@email.com ', '2026-01-12 11:05:00'),
    (1004, NULL, 'Williams', 'dwilliams@email.com', '2026-01-17 16:40:00'),
    (1005, 'Samantha', 'Reid', NULL, '2026-01-20 08:30:00');
GO

INSERT INTO src.Products
    (ProductId, ProductName,Category,Price,CreationDate)
VALUES
    (2001, 'GoPro Camera', 'TECH', 350.00,'2022-01-04 00:00:00'),
    (2002, 'AirForce 1 Low Top', 'Clothing', 69.99,'2022-04-12 00:00:00'),
    (2003, 'Iphone 13 Pro Max', 'TECH', 450.00,'2022-08-18 00:00:00'),
    (2004, 'Ninja Air Fryer', 'Appliance', 150.00,'2022-12-07 00:00:00'),
    (2005, 'LV Jacket', 'Clothing', 549.99,'2023-02-28 00:00:00'),
    (2006, 'GE 6 Burner Stove', 'Appliance', 1250.00,'2023-05-05 00:00:00'),
    (2007, 'Samsung Galaxy S26', 'tech', 950.00,'2023-06-09 00:00:00'),
    (2008, 'True Religion Jeans Men', 'CLOTHING', 399.99,'2023-09-16 00:00:00');
GO

INSERT INTO src.Orders
    (OrderId,CustomerId,OrderDate,OrderStatus)
VALUES
    (3001, 1001,'2024-05-04 15:33:00','DONE'),
    (3002, 1003,'2024-05-24 08:55:00','CANCEL'),
    (3003, 1004,'2025-06-02 07:33:00','PEND'),
    (3004, 1003,'2024-07-25 12:11:00','DONE'),
    (3005, 1004,'2024-09-05 13:48:00','done'),
    (3006, 1001,'2024-11-07 22:21:00','Pending');
GO

INSERT INTO src.OrderItems
    (OrderItemId,OrderId,ProductId,Quantity,UnitPrice)
VALUES
    (4001,3001,2002,1,69.99),
    (4002,3001,2005,2,549.99),
    (4003,3001,2008,1,399.99),
    (4004,3002,2001,2,350.00),
    (4005,3003,2003,4,450.00),
    (4006,3003,2007,2,950.00),
    (4007,3004,2006,1,1250.00),
    (4008,3004,2004,2,150.00),
    (4009,3004,2005,1,549.99),
    (4010,3005,2007,3,950.00),
    (4011,3005,2008,1,399.99),
    (4012,3006,2001,1,350.00),
    (4013,3006,2004,1,150.00);