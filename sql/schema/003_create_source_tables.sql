CREATE TABLE src.Customers (
    CustomerId INT PRIMARY KEY,
    FirstName VARCHAR(100) NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE src.Products (
    ProductId INT PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreationDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE src.Orders (
    OrderId INT PRIMARY KEY,
    CustomerId INT NOT NULL,
    OrderDate DATETIME2 NOT NULL,
    OrderStatus VARCHAR(100) NOT NULL,

    CONSTRAINT fk_customer_order
        FOREIGN KEY (CustomerId) REFERENCES src.Customers(CustomerId)
);

CREATE TABLE src.OrderItems (
    OrderItemId INT PRIMARY KEY,
    OrderId INT NOT NULL,
    ProductId INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_orderItem_order
        FOREIGN KEY (OrderId) REFERENCES src.Orders(OrderId),

    CONSTRAINT fk_orderItem_product
        FOREIGN KEY (ProductId) REFERENCES src.Products(ProductId)
);