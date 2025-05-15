-- 1. Insertar CABECERAS con valores iniciales en 0
DECLARE @i INT = 0;

WHILE @i < 5000
BEGIN
    DECLARE @RandomDay INT = ABS(CHECKSUM(NEWID())) % 365 + 1;
    DECLARE @OrderDate DATE = DATEADD(DAY, @RandomDay, '2012-01-01');

    -- Generar flag de orden online
    DECLARE @OnlineOrderFlag BIT = ABS(CHECKSUM(NEWID())) % 2;

    -- Declarar vendedor (solo si no es online)
    DECLARE @SalesPersonID INT = NULL;
    IF @OnlineOrderFlag = 0
        SELECT TOP 1 @SalesPersonID = BusinessEntityID FROM Sales.SalesPerson ORDER BY NEWID();

    INSERT INTO Sales.SalesOrderHeader (
        RevisionNumber,
        OrderDate,
        DueDate,
        ShipDate,
        Status,
        OnlineOrderFlag,
        PurchaseOrderNumber,
        AccountNumber,
        CustomerID,
        SalesPersonID,
        TerritoryID,
        BillToAddressID,
        ShipToAddressID,
        ShipMethodID,
        CreditCardID,
        CreditCardApprovalCode,
        CurrencyRateID,
        SubTotal,
        TaxAmt,
        Freight,
        Comment,
        ModifiedDate
    )
    SELECT
        1,
        @OrderDate,
        DATEADD(DAY, 5, @OrderDate),
        NULL,
        CASE ABS(CHECKSUM(NEWID())) % 5 WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 ELSE 6 END,
        @OnlineOrderFlag,
        'PO' + CAST(@i AS VARCHAR),
        '10-4020-' + RIGHT('00000' + CAST(@i AS VARCHAR), 5),
        (SELECT TOP 1 CustomerID FROM Sales.Customer ORDER BY NEWID()),
        @SalesPersonID,
        NULL,
        (SELECT TOP 1 AddressID FROM Person.Address ORDER BY NEWID()),
        (SELECT TOP 1 AddressID FROM Person.Address ORDER BY NEWID()),
        (SELECT TOP 1 ShipMethodID FROM Purchasing.ShipMethod ORDER BY NEWID()),
        (SELECT TOP 1 CreditCardID FROM Sales.CreditCard ORDER BY NEWID()),
        'APPROVED',
        NULL,
        0.00, -- SubTotal
        0.00, -- TaxAmt
        0.00, -- Freight
        NULL,
        GETDATE();

    SET @i += 1;
END;

-- 2. Insertar DETALLES para cabeceras que aún no tienen
INSERT INTO Sales.SalesOrderDetail (
    SalesOrderID,
    CarrierTrackingNumber,
    OrderQty,
    ProductID,
    SpecialOfferID,
    UnitPrice,
    UnitPriceDiscount,
    ModifiedDate
)
SELECT
    h.SalesOrderID,
    'TRK' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR),
    1 + ABS(CHECKSUM(NEWID())) % 5,
    sop.ProductID,
    sop.SpecialOfferID,
    -- UnitPrice será entre el 70% y 100% del ListPrice
    CAST(sop.ListPrice * (0.7 + (ABS(CHECKSUM(NEWID())) % 31) / 100.0) AS DECIMAL(10,2)),
    0.00,
    GETDATE()
FROM Sales.SalesOrderHeader h
CROSS APPLY (
    SELECT TOP 1 
        sop.ProductID, 
        sop.SpecialOfferID, 
        p.ListPrice
    FROM Sales.SpecialOfferProduct sop
    JOIN Production.Product p 
        ON p.ProductID = sop.ProductID
    WHERE p.ListPrice > 0
    ORDER BY NEWID()
) sop
WHERE h.Status IN (1,2,3,4,6)
  AND h.OrderDate BETWEEN '2012-01-01' AND '2012-12-31'
  AND NOT EXISTS (
    SELECT 1 
    FROM Sales.SalesOrderDetail d 
    WHERE d.SalesOrderID = h.SalesOrderID
);

-- 3. ACTUALIZAR SubTotal, TaxAmt y Freight según los detalles
UPDATE h
SET 
    SubTotal = x.Total,
    TaxAmt = ROUND(x.Total * 0.10, 2),
    Freight = ROUND(x.Total * 0.05, 2)
FROM Sales.SalesOrderHeader h
JOIN (
    SELECT 
        d.SalesOrderID,
        SUM(d.OrderQty * d.UnitPrice * (1 - d.UnitPriceDiscount)) AS Total
    FROM Sales.SalesOrderDetail d
    GROUP BY d.SalesOrderID
) x ON h.SalesOrderID = x.SalesOrderID
WHERE h.OrderDate BETWEEN '2012-01-01' AND '2012-12-31'
  AND h.Status != 5;

-----------------------------------------------------------------------------------------------
-- VERIFICACIONES
-----------------------------------------------------------------------------------------------
-- Verifica cantidad
SELECT Status, COUNT(*) 
FROM Sales.SalesOrderHeader
GROUP BY Status;

SELECT Estado, COUNT(*) 
FROM AW_HefestoDW2025.dbo.dimOrdenes
GROUP BY Estado;

SELECT 
    dimOr.Estado,
    COUNT(*) AS CantidadOrdenes
FROM AW_HefestoDW2025.dbo.FactOrdenes AS factor
JOIN AW_HefestoDW2025.dbo.dimOrdenes AS dimOr
    ON factor.OrdenID = dimOr.OrdenID
GROUP BY dimOr.Estado
ORDER BY dimOr.Estado;


-- Detalles insertados
SELECT COUNT(*) 
FROM Sales.SalesOrderDetail 
WHERE SalesOrderID IN (
    SELECT SalesOrderID 
    FROM Sales.SalesOrderHeader as he
    WHERE he.SalesOrderID > 75123
);

-----------------------------------------------------------------------------------------------
-- ELIMINACÓN DE DATOS FICTICIOS
-----------------------------------------------------------------------------------------------

-- Primero elimina los detalles relacionados
DELETE d
FROM Sales.SalesOrderDetail d
JOIN Sales.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID
WHERE h.Status != 5;

-- Luego elimina las cabeceras sin detalles
DELETE FROM Sales.SalesOrderHeader
WHERE Status != 5;

Select max(he.SalesOrderID) from AdventureWorks2022.Sales.SalesOrderHeader as he;
Select count(he.SalesOrderID) from AdventureWorks2022.Sales.SalesOrderHeader as he;
-- Última orden original 75123

SELECT COUNT(*) 
FROM Sales.SalesOrderHeader 
WHERE SalesPersonID IS NULL;


---------------------- Cosas 1era pregunta -------------------------------------
SELECT 
    ProductoID,
    VendedorID,
    OrdenID,
    PrecioLista,
    PrecioUnitario,
    Cantidad,
    TotalDiferencia,
    (PrecioLista - PrecioUnitario) * Cantidad AS ComprobacionManual,
    CASE 
        WHEN TotalDiferencia = (PrecioLista - PrecioUnitario) * Cantidad 
             THEN 'OK'
        ELSE 'DESIGUAL'
    END AS Resultado
FROM AW_HefestoDW2025.dbo.FactDiferenciaVentas;

SELECT 
    CASE 
        WHEN TotalDiferencia = (PrecioLista - PrecioUnitario) * Cantidad 
             THEN 'OK'
        ELSE 'DESIGUAL'
    END AS Resultado,
    COUNT(*) AS TotalFilas
FROM AW_HefestoDW2025.dbo.FactDiferenciaVentas
GROUP BY 
    CASE 
        WHEN TotalDiferencia = (PrecioLista - PrecioUnitario) * Cantidad 
             THEN 'OK'
        ELSE 'DESIGUAL'
    END;


SELECT COUNT(*) AS FilasConPrecioListaNulo
FROM AW_HefestoDW2025.dbo.FactDiferenciaVentas
WHERE PrecioLista IS NULL;


SELECT p.ProductID, p.Name
FROM AdventureWorks2022.Production.Product p
LEFT JOIN AdventureWorks2022.Production.ProductListPriceHistory plph
    ON p.ProductID = plph.ProductID
WHERE plph.ProductID IS NULL;


SELECT COUNT(*) AS ProductosSinPrecioHistorial
FROM AdventureWorks2022.Production.Product p
LEFT JOIN AdventureWorks2022.Production.ProductListPriceHistory plph
    ON p.ProductID = plph.ProductID
WHERE plph.ProductID IS NULL;

SELECT ProductID, Name, ListPrice
FROM AdventureWorks2022.Production.Product
WHERE ListPrice IS NULL OR ListPrice = 0;

SELECT COUNT(*) AS ProductosSinListPrice
FROM AdventureWorks2022.Production.Product
WHERE ListPrice IS NULL OR ListPrice = 0;

SELECT COUNT(*) from 
AdventureWorks2022.Sales.SalesOrderDetail as det
where det.ProductID in (
Select pro.ProductID from 
AdventureWorks2022.Production.Product as pro
where pro.ListPrice = 0 or pro.ListPrice is null
);


SELECT COUNT(*) AS VentasConVendedorSinDireccion
FROM AdventureWorks2022.Sales.SalesOrderHeader AS soh
JOIN AdventureWorks2022.Sales.SalesPerson AS sp
    ON soh.SalesPersonID = sp.BusinessEntityID
LEFT JOIN AdventureWorks2022.Person.BusinessEntityAddress AS bea
    ON sp.BusinessEntityID = bea.BusinessEntityID
LEFT JOIN AdventureWorks2022.Person.Address AS a
    ON bea.AddressID = a.AddressID
WHERE soh.SalesPersonID IS NOT NULL
  AND a.AddressID IS NULL;

  SELECT COUNT(*) AS VentasConTerritorioSinDireccion
FROM AdventureWorks2022.Sales.SalesOrderHeader AS soh
JOIN AdventureWorks2022.Sales.SalesTerritory AS t
    ON soh.TerritoryID = t.TerritoryID
LEFT JOIN AdventureWorks2022.Person.StateProvince AS sp
    ON t.TerritoryID = sp.TerritoryID
WHERE soh.TerritoryID IS NOT NULL
  AND sp.StateProvinceCode IS NULL;

-------------------------------------------------------------------------
------ Cosas 2da Pregunta ----------
-------------------------------------------------------------------------
SELECT 
    DISTINCT FromCurrencyCode, ToCurrencyCode
FROM 
    Sales.CurrencyRate
WHERE 
    FromCurrencyCode <> 'USD';
-- Todas las conversiones registradas en Sales.CurrencyRate tienen como moneda de origen USD.
-- En Sales.SalesOrderHeader existe el campo CurrencyRateID null cuando no tiene conversión, e id
-- cuando se dice que la venta tiene una tasa de conversión
-- No existe converisión de USD a USD
SELECT 
    ToCurrencyCode,
    AVG(AverageRate) AS PromedioTasa,
    MIN(AverageRate) AS TasaMin,
    MAX(AverageRate) AS TasaMax,
    COUNT(*) AS TotalTasas
FROM Sales.CurrencyRate
GROUP BY ToCurrencyCode
ORDER BY PromedioTasa DESC;

SELECT 
    MonedaID,
    COUNT(*) AS NumRegistros,
    AVG(TasaCambioPromedio) AS TasaPromedioCalculada,
    MIN(TasaCambioPromedio) AS TasaMinima,
    MAX(TasaCambioPromedio) AS TasaMaxima
FROM AW_HefestoDW2025.dbo.FactVentasMonedas
WHERE MonedaID = 'EUR'
GROUP BY MonedaID;

-------------------------------------------------------------------------
------ Cosas 3ra Pregunta ----------
-------------------------------------------------------------------------
SELECT 
    soh.SalesOrderID,
    soh.CurrencyRateID,
    soh.SubTotal,
    soh.TaxAmt,
    soh.Freight,
    soh.TotalDue,
    ISNULL((soh.SubTotal + soh.TaxAmt + soh.Freight), 0) AS TotalCalculadoManual,
    CASE 
        WHEN ISNULL((soh.SubTotal + soh.TaxAmt + soh.Freight), 0) = soh.TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS Comparacion
FROM Sales.SalesOrderHeader soh
WHERE soh.CurrencyRateID IS NOT NULL;

SELECT 
    COUNT(*) AS OrdenesConDiferencia
FROM Sales.SalesOrderHeader soh
WHERE soh.CurrencyRateID IS NOT NULL
  AND ISNULL((soh.SubTotal + soh.TaxAmt + soh.Freight), 0) <> soh.TotalDue;

WITH TotalesPorOrden AS (
    SELECT 
        soh.SalesOrderID,
        soh.CurrencyRateID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight,
        SUM(sod.LineTotal) AS SubTotalManual
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE soh.CurrencyRateID IS NOT NULL
    GROUP BY 
        soh.SalesOrderID,
        soh.CurrencyRateID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight
)
SELECT 
    CASE 
        WHEN SubTotalManual + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS Comparacion,
    COUNT(*) AS CantidadOrdenes
FROM TotalesPorOrden
GROUP BY 
    CASE 
        WHEN SubTotalManual + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END;

select COUNT(*)
from AdventureWorks2022.Sales.SalesOrderHeader;

WITH TotalesUSD AS (
    SELECT 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight,
        SUM(sod.LineTotal) AS SubTotalManual
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE soh.CurrencyRateID IS NULL
    GROUP BY 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight
)
SELECT 
    CASE 
        WHEN SubTotalManual + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS Comparacion,
    COUNT(*) AS CantidadOrdenes
FROM TotalesUSD
GROUP BY 
    CASE 
        WHEN SubTotalManual + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END;

SELECT 
    CASE 
        WHEN CurrencyRateID IS NULL THEN 'SIN CurrencyRateID (USD)'
        ELSE 'CON CurrencyRateID (Moneda extranjera)'
    END AS TipoOrden,
    COUNT(*) AS CantidadOrdenes
FROM Sales.SalesOrderHeader
GROUP BY 
    CASE 
        WHEN CurrencyRateID IS NULL THEN 'SIN CurrencyRateID (USD)'
        ELSE 'CON CurrencyRateID (Moneda extranjera)'
    END;

WITH TotalesConDescuento AS (
    SELECT 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight,
        SUM(
            sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)
        ) AS SubTotalCalculado
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE soh.CurrencyRateID IS NOT NULL
    GROUP BY 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight
)
SELECT 
    CASE 
        WHEN SubTotalCalculado + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS Comparacion,
    COUNT(*) AS CantidadOrdenes
FROM TotalesConDescuento
GROUP BY 
    CASE 
        WHEN SubTotalCalculado + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END;

WITH TotalesUSD AS (
    SELECT 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight,
        SUM(
            sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)
        ) AS SubTotalCalculado
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE soh.CurrencyRateID IS NULL
    GROUP BY 
        soh.SalesOrderID,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight
)
SELECT 
    CASE 
        WHEN SubTotalCalculado + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS Comparacion,
    COUNT(*) AS CantidadOrdenes
FROM TotalesUSD
GROUP BY 
    CASE 
        WHEN SubTotalCalculado + TaxAmt + Freight = TotalDue THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END;


---------------- Calculos Iniciales que funcan ----------------------------------
/*
The CALCULATE command controls the aggregation of leaf cells in the cube.
If the CALCULATE command is deleted or modified, the data within the cube is affected.
You should edit this command only if you manually specify how the cube is aggregated.
*/
CALCULATE;

-- Total global de órdenes (sin slicers)
CREATE MEMBER CURRENTCUBE.[Measures].[Total Ordenes Global]
AS ([Measures].[Cantidad Ordenes], [Dim Ordenes].[Estado].[All]), VISIBLE = 0;

-- Porcentaje de órdenes por estado
CREATE MEMBER CURRENTCUBE.[Measures].[% Ordenes por Estado]
AS 
IIF(
  [Measures].[Total Ordenes Global] = 0,
  NULL,
  [Measures].[Cantidad Ordenes] / [Measures].[Total Ordenes Global]
), 
FORMAT_STRING = "Percent", VISIBLE = 1;

-- Total global de valor
CREATE MEMBER CURRENTCUBE.[Measures].[Total Valor Global]
AS ([Measures].[Total Orden], [Dim Ordenes].[Estado].[All]), VISIBLE = 0;

-- Porcentaje de valor por estado
CREATE MEMBER CURRENTCUBE.[Measures].[% Valor por Estado]
AS 
IIF(
  [Measures].[Total Valor Global] = 0,
  NULL,
  [Measures].[Total Orden] / [Measures].[Total Valor Global]
), 
FORMAT_STRING = "Percent", VISIBLE = 1;
