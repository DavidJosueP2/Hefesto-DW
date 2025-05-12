-- Crear base de datos
CREATE DATABASE AW_HefestoDW2025;
GO
USE AW_HefestoDW2025;
GO

-- ==================================
-- Dimensiones de ubicación geográfica
-- ==================================

CREATE TABLE dimPaises (
    idPais INT PRIMARY KEY,
    pais NVARCHAR(100)
);

CREATE TABLE dimProvincias (
    idProvincia INT PRIMARY KEY,
    idPais INT FOREIGN KEY REFERENCES dimPaises(idPais),
    provincia NVARCHAR(100)
);

CREATE TABLE dimCiudades (
    idCiudad INT PRIMARY KEY,
    idProvincia INT FOREIGN KEY REFERENCES dimProvincias(idProvincia),
    ciudad NVARCHAR(100)
);

CREATE TABLE dimUbicaciones (
    idUbicacion INT PRIMARY KEY,
    idCiudad INT FOREIGN KEY REFERENCES dimCiudades(idCiudad),
    barrio NVARCHAR(100)
);

-- ============================
-- Dimensiones analíticas
-- ============================

CREATE TABLE dimProductos (
    ProductoID INT PRIMARY KEY,
    Producto NVARCHAR(100),
    NumeroProducto NVARCHAR(50),
    EsFabricado BIT
);

CREATE TABLE dimOrdenes (
    OrdenID INT PRIMARY KEY,
    Estado NVARCHAR(15) -- Enviado, Cancelado, etc.
);

CREATE TABLE dimMonedas (
    MonedaID nchar(3) PRIMARY KEY,
    Moneda NVARCHAR(50)
);

CREATE TABLE dimTerritorios (
    TerritorioID INT PRIMARY KEY,
    Territorio NVARCHAR(100)
);

CREATE TABLE dimTiempo (
    FechaID INT PRIMARY KEY, -- formato: YYYYMMDD
    Año INT,
    Mes NVARCHAR(20),
    NumeroMes INT,
    Trimestre INT
);

-- =========================================
-- Dimensión unificada: Vendedores
-- =========================================

CREATE TABLE dimVendedores (
    VendedorID INT PRIMARY KEY, -- BusinessEntityID
    NombreCompleto NVARCHAR(100),
    Cargo NVARCHAR(100),
    EsAsalariado BIT,
    PorcentajeComision DECIMAL(5,2),
    idUbicacion INT FOREIGN KEY REFERENCES dimUbicaciones(idUbicacion),
    Tipo NCHAR(2)
);

-- ============================
-- Tablas de Hechos
-- ============================

-- Pregunta 1: Diferencia de precios
CREATE TABLE FactDiferenciaVentas (
    ProductoID INT,
    VendedorID INT,
    OrdenID INT,
    PrecioLista DECIMAL(10,2),
    PrecioUnitario DECIMAL(10,2),
    Cantidad INT,
    TotalDiferencia AS ((PrecioLista - PrecioUnitario) * Cantidad) PERSISTED,
    PRIMARY KEY (ProductoID, VendedorID, OrdenID),
    FOREIGN KEY (ProductoID) REFERENCES dimProductos(ProductoID),
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID)
);

-- Pregunta 2: Ventas en moneda extranjera
CREATE TABLE factVentasMonedas (
    MonedaID nchar(3),
    TerritorioID INT,
    VendedorID INT,
    FechaID INT,
    Cantidad INT,
    PrecioUnitario DECIMAL(10,2),
    TasaCambioPromedio DECIMAL(10,4),
    VentaMoneda AS (Cantidad * PrecioUnitario * TasaCambioPromedio) PERSISTED,
    PRIMARY KEY (MonedaID, TerritorioID, VendedorID, FechaID),
    FOREIGN KEY (MonedaID) REFERENCES dimMonedas(MonedaID),
    FOREIGN KEY (TerritorioID) REFERENCES dimTerritorios(TerritorioID),
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (FechaID) REFERENCES dimTiempo(FechaID)
);


-- Refactor de Pregunta 3: Todas las órdenes (no solo canceladas)
CREATE TABLE factOrdenes (
    OrdenID INT PRIMARY KEY,
    VendedorID INT,
    FechaID INT,
    Estado NVARCHAR(15),
    Canal NVARCHAR(20), -- Internet, Presencial, Ambos
    TotalOrden DECIMAL(10,2), -- TotalDue
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (FechaID) REFERENCES dimTiempo(FechaID),
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID)
);
