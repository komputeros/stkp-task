### Rozwiązanie zadania testowego sql
W ramach rozwiązania zadania utworzyłem dwa obiekty SQL
- widok `vw_ContractAnnex`
- procedurę składowaną `sp_GetSchedules`


# vw_ContractAnnex

```sql
CREATE VIEW [dbo].[vw_ContractAnnex] AS
SELECT 
    c.Id AS ContractId,
    c.ClientId,
    c.ContractNumber,
    c.DateFrom,
    ISNULL(c.DateTo, CAST('9999-12-31' AS DATE)) AS DateTo,
    YEAR(c.DateFrom) AS Year,
    MONTH(c.DateFrom) AS Month,
    c.ContractTypeId
FROM 
    Contract c
UNION ALL
SELECT 
    c.Id AS ContractId,
    c.ClientId,
    c.ContractNumber,
    a.DateFrom,
    ISNULL(a.DateTo, CAST('9999-12-31' AS DATE)) AS DateTo,
    YEAR(a.DateFrom) AS Year,
    MONTH(a.DateFrom) AS Month,
    c.ContractTypeId
FROM 
    Contract c
JOIN 
    Annex a ON c.Id = a.ContractId;
GO
```
Przyjąłem iż dla `DateTo` równego `null` zastosuję wysoką datę `9999-12-31`. Takie rozwiązanie ułatwia mi często operowanie na datach.


# sp_GetSchedules

```sql
CREATE PROCEDURE [dbo].[sp_GetSchedules]
    @DataFrom DATE,
    @DateTo DATE,
    @ObjectID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @DataFrom > @DateTo
    BEGIN
        RAISERROR('DataFrom musi być wcześniejsza od DateTo', 16, 1);
        RETURN;
    END
  
    CREATE TABLE #TempDates (
        Year_Month VARCHAR(7),
        Year INT,
        Month INT
    );

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
        (DATEFROMPARTS(t.Year, t.Month, 1) <= v.DateTo AND EOMONTH(DATEFROMPARTS(t.Year, t.Month, 1)) >= v.DateFrom) 
    JOIN 
        [ContractType] ct ON v.ContractTypeId = ct.Id AND v.ContractTypeId IN (1, 3) 
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
        (@ObjectID IS NULL OR o.Id = @ObjectID)
    ORDER BY
        o.Id,
        t.Year_Month;

    DROP TABLE #TempDates;
END;
GO
```

Jako parmetry przyjemujemy zakresy dat jako typ `date` oraz wspomniany w zadaniu 'identyfikator Obiektu' który potraktowałem jako `[Object].Id`.
Została przeprowadzona prosta walidacja na  poziomie  `IF @DataFrom > @DateTo`
W procedurze jest tworzona jedna tabela tymczasowa `#TempDates`z 'rozpisanymi' miesiacami i latami dla podanego w parametrach zakresu dat. 

Wypełnienie tabeli można by wykonać za pomocą `while` (i tak bylo w pierwszej wersji) np.:

```sql
WHILE @CurrentDate <= @DateTo
    BEGIN
        INSERT INTO #TempDates (Year_Month, Year, Month)
        VALUES (
            FORMAT(@CurrentDate, 'yyyy-MM'),
            YEAR(@CurrentDate),
            MONTH(@CurrentDate)
        )
        SET @CurrentDate = DATEADD(MONTH, 1, @CurrentDate);
    END
```
Ale wykorzystanie `spt_values` wydaje się zabawniejszym rozwiązaniem.


Łączenie do widoku `vw_ContractAnnex` 
```sql
 JOIN
        [vw_ContractAnnex] v
    ON 
        (DATEFROMPARTS(t.Year, t.Month, 1) <= v.DateTo AND EOMONTH(DATEFROMPARTS(t.Year, t.Month, 1)) >= v.DateFrom) 
```
nie jest może przykładem najładniejszego rozwiązania ale wydaje mi się ze możemy je przyjąć zważywszy na wymaganie iż "Obiekt posiada aktualną Umowę w danym miesiącu (nawet chociażby przez jeden dzień)". Na pewno istniałoby tu pole do optymalizacji.

 Dalej mamy już typowe łączenia którymi sięgamy po potrzebne dane. 
 Wszystko warunkujemy tradycyjną już składnią dla parametrów które przy wartosci `null` mają zwracać 'wszystko a przy innej wartości przefiltrować wynik.
```sql
WHERE (@ObjectID IS NULL OR o.Id = @ObjectID) 
```
Zabawę kończymy dropem na tabelę tymczasową.


Mam nadzieję, że dobrze zrozumiałem zadanie i wykonałem je na zadowalającym poziomie.

### Pozdrawiam
