USE [stkp]
GO

/****** Object:  View [dbo].[vw_ContractAnnex]    Script Date: 30.06.2024 23:34:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
INNER JOIN 
    Annex a ON c.Id = a.ContractId;
GO

