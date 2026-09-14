CREATE OR ALTER PROCEDURE etl.usp_LoadDimDate
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate > @EndDate
        THROW 50001, 'StartDate cannot be after EndDate.', 1;

    ;WITH DateCTE AS
    (
        SELECT @StartDate AS FullDate

        UNION ALL

        SELECT DATEADD(DAY, 1, FullDate)
        FROM DateCTE
        WHERE FullDate < @EndDate
    )
    INSERT INTO rpt.DimDate
    (
        DateKey,
        FullDate,
        [Year],
        [Month],
        [MonthName],
        [Quarter]
    )
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), FullDate, 112)) AS DateKey,
        FullDate,
        YEAR(FullDate) AS [Year],
        MONTH(FullDate) AS [Month],
        DATENAME(MONTH, FullDate) AS [MonthName],
        DATEPART(QUARTER, FullDate) AS [Quarter]
    FROM DateCTE
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM rpt.DimDate d
        WHERE d.DateKey =
            CONVERT(INT, CONVERT(CHAR(8), DateCTE.FullDate, 112))
    )
    OPTION (MAXRECURSION 0);
END;
GO