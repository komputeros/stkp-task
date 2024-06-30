USE [stkp]
GO

/****** Object:  StoredProcedure [dbo].[sp_GetSchedules]    Script Date: 30.06.2024 23:34:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_GetSchedules]
    @DataFrom DATE,
    @DateTo DATE,
    @ObjectID INT = NULL --indetyfikator obiektu. Zakladam jako Object.id
AS
BEGIN
    SET NOCOUNT ON;

    -- Sprawdzenie czy parametry są prawidłowe
    IF @DataFrom > @DateTo
    BEGIN
        RAISERROR('DataFrom musi być wcześniejsza lub równa DateTo', 16, 1);
        RETURN;
    END

    -- Utworzenie tabeli tymczasowej z miesiacami i latami dla zakresu podanego w procedurze
    CREATE TABLE #TempDates (
        Year_Month VARCHAR(7),
        Year INT,
        Month INT
    );

    -- Wypełnienie tabeli tymczasowej danymi
    INSERT INTO #TempDates (Year_Month, Year, Month)
    SELECT 
        FORMAT(dateadd(month, number, @DataFrom), 'yyyy-MM') AS Year_Month,
        YEAR(dateadd(month, number, @DataFrom)) AS Year,
        MONTH(dateadd(month, number, @DataFrom)) AS Month
    FROM 
        master..spt_values
    WHERE 
        type = 'P'
        AND dateadd(month, number, @DataFrom) <= @DateTo;

  
    -- SELECT * FROM #TempDates;

    SELECT 
        t.Year_Month,
        t.Year,
        t.Month,
        ISNULL(ss.StatusName, 'Missing') AS Status,
        s.id AS ScheduleId,
        o.Id AS ObjectId,
        o.ObjectName,
        c.ClientName,
        v.ContractId,
        v.ContractNumber,
        ct.TypeName AS ContractType
    FROM 
        #TempDates t
    JOIN
        [vw_ContractAnnex] v
    ON 
        (DATEFROMPARTS(t.Year, t.Month, 1) <= v.DateTo AND EOMONTH(DATEFROMPARTS(t.Year, t.Month, 1)) >= v.DateFrom) --dopasowujemy umowy+aneksy do lat i miesiecy z podanego zakresu z widoku [vw_ContractAnnex]
    JOIN 
        [ContractType] ct ON v.ContractTypeId = ct.Id AND v.ContractTypeId IN (1, 3) --tylko protection i cleaning
    JOIN 
        [Client] c ON v.ClientId = c.Id
    JOIN 
        [ContractObject] co ON co.ContractId = v.ContractId
    JOIN 
        [Object] o ON co.ObjectId = o.Id
    LEFT JOIN 
        [Schedule] s ON o.Id = s.ObjectId AND s.Year = t.Year AND s.Month = t.Month
    LEFT JOIN 
        [ScheduleStatus] ss ON ss.Id = s.StatusId
    WHERE 
        (@ObjectID IS NULL OR o.Id = @ObjectID) -- i warunkujemy na opcje @ObjectID
    ORDER BY
        o.Id,
        t.Year_Month;

    DROP TABLE #TempDates;
END;
GO

