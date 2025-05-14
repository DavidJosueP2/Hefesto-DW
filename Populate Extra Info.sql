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
