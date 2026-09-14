USE SQLDataEngineeringLab;
GO

CREATE OR ALTER PROCEDURE etl.usp_RunPipeline
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;

    INSERT INTO etl.ETLRun
    (
        [Status]
    )
    VALUES
    (
        'Running'
    );

    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC etl.usp_LoadStagingCustomers;
        EXEC etl.usp_LoadStagingProducts;
        EXEC etl.usp_LoadStagingOrders;
        EXEC etl.usp_LoadStagingOrderItems;
        EXEC etl.usp_LoadDimCustomer;
        EXEC etl.usp_LoadDimProduct;

        EXEC etl.usp_LoadDimDate
            @StartDate = @StartDate,
            @EndDate = @EndDate;

        EXEC etl.usp_LoadFactSales;

        COMMIT TRANSACTION;

        -- Mark ETLRun = Success
        UPDATE er
        SET
            er.[Status] = 'Success',
            er.EndTime = SYSDATETIME(),
            er.ErrorMessage = NULL
        FROM etl.ETLRun er
        WHERE er.RunId = @RunId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Mark ETLRun = Failed
        UPDATE er
        SET
            er.[Status] = 'Failed',
            er.EndTime = SYSDATETIME(),
            er.ErrorMessage = ERROR_MESSAGE()
        FROM etl.ETLRun er
        WHERE er.RunId = @RunId;

        THROW;
    END CATCH;
END;
GO