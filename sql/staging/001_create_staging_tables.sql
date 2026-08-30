USE SQLDataEngineeringLab;
GO

CREATE TABLE stg.Customers (
    CustomerId INT PRIMARY KEY,
    FirstName VARCHAR(100) NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    CreatedDate DATETIME2 NOT NULL,
    StagedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);
GO

CREATE TABLE stg.Products (
    ProductId INT PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreationDate DATETIME2 NOT NULL,
    StdCategory VARCHAR(100) NULL,
    StagedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL
);
GO

CREATE TABLE stg.Orders (
    OrderId INT PRIMARY KEY,
    CustomerId INT NOT NULL,
    OrderDate DATETIME2 NOT NULL,
    OrderStatus VARCHAR(100) NOT NULL,
    StdOrderStatus VARCHAR(100) NULL,
    StagedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL,

    CONSTRAINT fk_stg_customer_order
        FOREIGN KEY (CustomerId) REFERENCES stg.Customers(CustomerId)
);
GO

CREATE TABLE stg.OrderItems (
    OrderItemId INT PRIMARY KEY,
    OrderId INT NOT NULL,
    ProductId INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    StagedDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    IsValid BIT NOT NULL,
    ValidationMessage VARCHAR(500) NULL,

    CONSTRAINT fk_orderItem_order
        FOREIGN KEY (OrderId) REFERENCES stg.Orders(OrderId),

    CONSTRAINT fk_orderItem_product
        FOREIGN KEY (ProductId) REFERENCES stg.Products(ProductId)
);
GO