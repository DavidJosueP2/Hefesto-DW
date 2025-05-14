
-- Crear base de datos
CREATE DATABASE AW_HefestoDW2025;
GO
USE AW_HefestoDW2025;
GO

-- ==================================
-- Dimensiones de ubicación geográfica
-- ==================================

-- Nuevo modelo jerárquico
CREATE TABLE dimPais (
    PaisID NVARCHAR(3) PRIMARY KEY,
    Nombre NVARCHAR(50) NOT NULL
);

CREATE TABLE dimEstado (
    EstadoID INT PRIMARY KEY,
    EstadoCode NCHAR(3) NOT NULL,
    Nombre NVARCHAR(50) NOT NULL,
    PaisID NVARCHAR(3) FOREIGN KEY REFERENCES dimPais(PaisID)
);

CREATE TABLE dimCiudad (
    CiudadID INT PRIMARY KEY,
    Nombre NVARCHAR(30) NOT NULL,
    CodigoPostal NVARCHAR(15) NOT NULL,
    EstadoID INT FOREIGN KEY REFERENCES dimEstado(EstadoID)
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
    VendedorID INT PRIMARY KEY,
    NombreCompleto NVARCHAR(101),  -- Campo combinado
    CiudadID INT FOREIGN KEY REFERENCES dimCiudad(CiudadID),
    Cargo NVARCHAR(101),
    EsAsalariado BIT,
    PorcentajeComision DECIMAL(5,2),
    Tipo NCHAR(2)
);

CREATE TABLE dimOrdenes (
    OrdenID INT PRIMARY KEY,
    VendedorID INT,  -- FK hacia dimVendedores
    FechaID INT,     -- FK hacia dimTiempo (OrderDate → FechaID formato YYYYMMDD)
    Estado NVARCHAR(15), -- Enviado, Cancelado, etc.
    Canal NVARCHAR(20),  -- Internet, Presencial, Ambos
    TotalPagado DECIMAL(10,2), -- TotalDue
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (FechaID) REFERENCES dimTiempo(FechaID)
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
CREATE TABLE FactVentasMonedas (
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
CREATE TABLE FactOrdenes (
    OrdenID INT PRIMARY KEY,
    VendedorID INT,
    FechaID INT,
    TotalOrden DECIMAL(10,2), -- TotalDue
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (FechaID) REFERENCES dimTiempo(FechaID),
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID)
);

