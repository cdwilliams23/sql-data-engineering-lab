USE SQLDataEngineeringLab;
GO

IF OBJECT_ID('tempdb..#CustomerCurrent') IS NOT NULL
    DROP TABLE #CustomerCurrent;

CREATE TABLE #CustomerCurrent
(
    CustomerId INT PRIMARY KEY,
    FirstName VARCHAR(100) NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    CreatedDate DATETIME2 NOT NULL
);

INSERT INTO #CustomerCurrent
(
    CustomerId,
    FirstName,
    LastName,
    Email,
    CreatedDate
)
SELECT
    CustomerId,
    FirstName,
    LastName,
    Email,
    CreatedDate

FROM stg.Customers
WHERE IsValid = 1;

BEGIN TRY
    BEGIN TRANSACTION;

Declare @CurrentTimeStamp DATETIME2 = SYSDATETIME();

--Update CreatedDate for every version of CustomerId
UPDATE dc
    SET dc.CreatedDate = cc.CreatedDate

FROM rpt.DimCustomer dc
INNER JOIN #CustomerCurrent cc
ON dc.CustomerId = cc.CustomerId
WHERE dc.CreatedDate <> cc.CreatedDate


-- Expire the current SCD2 row
UPDATE dc
SET
    dc.EffectiveTo = @CurrentTimeStamp,
    dc.IsCurrent = 0
FROM rpt.DimCustomer dc
INNER JOIN #CustomerCurrent cc
    ON dc.CustomerId = cc.CustomerId
WHERE dc.IsCurrent = 1
  AND
  (
         ISNULL(dc.FirstName, '') <> ISNULL(cc.FirstName, '')
      OR dc.LastName <> cc.LastName
      OR ISNULL(dc.Email, '') <> ISNULL(cc.Email, '')
  );

--Insert new current version
INSERT INTO rpt.DimCustomer
(
    CustomerId,
    FirstName,
    LastName,
    Email,
    CreatedDate,
    EffectiveFrom,
    EffectiveTo,
    IsCurrent
)
SELECT
    cc.CustomerId,
    cc.FirstName,
    cc.LastName,
    cc.Email,
    cc.CreatedDate,
    @CurrentTimeStamp,
    NULL,
    1

FROM #CustomerCurrent cc
WHERE NOT EXISTS (SELECT 1 FROM
                  rpt.DimCustomer dc
                  WHERE dc.CustomerId = cc.CustomerId
                  AND dc.IsCurrent = 1)

     COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO