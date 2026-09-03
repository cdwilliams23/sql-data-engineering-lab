USE SQLDataEngineeringLab;
GO

CREATE TABLE rpt.DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL,
    FirstName VARCHAR(100) NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    CreatedDate DATETIME2 NOT NULL,
    EffectiveFrom DATETIME2 NOT NULL
        CONSTRAINT DF_DimCustomer_EffectiveFrom DEFAULT SYSDATETIME(),
    EffectiveTo DATETIME2 NULL,
    IsCurrent BIT NOT NULL
        CONSTRAINT DF_DimCustomer_IsCurrent DEFAULT 1
);
GO

CREATE UNIQUE INDEX UX_DimCustomer_CustomerId_IsCurrent
ON rpt.DimCustomer(CustomerId)
WHERE IsCurrent = 1;
GO

CREATE TABLE rpt.DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    ProductName VARCHAR(255) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CreationDate DATETIME2 NOT NULL,
    EffectiveFrom DATETIME2 NOT NULL
        CONSTRAINT DF_DimProduct_EffectiveFrom DEFAULT SYSDATETIME(),
    EffectiveTo DATETIME2 NULL,
    IsCurrent BIT NOT NULL
        CONSTRAINT DF_DimProduct_IsCurrent DEFAULT 1
);
GO

CREATE UNIQUE INDEX UX_DimProduct_ProductId_IsCurrent
ON rpt.DimProduct(ProductId)
WHERE IsCurrent = 1;
GO

CREATE TABLE rpt.DimDate (
    DateKey INT PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    [Year] INT NOT NULL,
    [Month] INT NOT NULL,
    [MonthName] NVARCHAR(20) NOT NULL,
    [Quarter] INT NOT NULL 
);
GO

CREATE TABLE rpt.FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    OrderItemId INT NOT NULL UNIQUE,
    OrderId INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    DateKey INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    SalesAmount DECIMAL(12,2) NOT NULL,

    CONSTRAINT FK_FactSales_Customer
        FOREIGN KEY (CustomerKey) REFERENCES rpt.DimCustomer(CustomerKey),

    CONSTRAINT FK_FactSales_Product
        FOREIGN KEY (ProductKey) REFERENCES rpt.DimProduct(ProductKey),

    CONSTRAINT FK_FactSales_Date
        FOREIGN KEY (DateKey) REFERENCES rpt.DimDate(DateKey)
);
GO