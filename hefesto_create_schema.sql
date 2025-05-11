
-- Crear base de datos
CREATE DATABASE AW_HefestoDW2025;
GO
USE AW_HefestoDW2025;
GO

-- Dimensiones

CREATE TABLE dimProductos (
    ProductoID INT PRIMARY KEY,
    Producto NVARCHAR(100),
    NumeroProducto NVARCHAR(50),
    EsFabricado BIT
);

CREATE TABLE dimUbicacionVendedores (
    VendedorID INT PRIMARY KEY,
    Vendedor NVARCHAR(100),
    Ciudad NVARCHAR(100),
    Estado NVARCHAR(100),
    Pais NVARCHAR(100)
);

CREATE TABLE dimOrdenes (
    OrdenID INT PRIMARY KEY,
    Estado NVARCHAR(50)
);

CREATE TABLE dimMonedas (
    MonedaId INT PRIMARY KEY,
    Moneda NVARCHAR(50)
);

CREATE TABLE dimTerritorios (
    TerritorioId INT PRIMARY KEY,
    Territorio NVARCHAR(100)
);

CREATE TABLE dimVendedores (
    VendedorId INT PRIMARY KEY,
    Vendedor NVARCHAR(100),
    Tipo NVARCHAR(50)
);

CREATE TABLE dimTiempo (
    FechaId INT PRIMARY KEY,
    Año INT,
    Mes NVARCHAR(20),
    NumeroMes INT,
    Trimestre INT
);

CREATE TABLE dimCapitalHumano (
    IdEmpleado INT PRIMARY KEY,
    Cargo NVARCHAR(100),
    EsAsalariado BIT,
    PorcentajeComision DECIMAL(5,2)
);

-- Tablas de hechos

CREATE TABLE FactDiferenciaVentas (
    ProductoID INT,
    VendedorID INT,
    OrdenID INT,
    PrecioLista DECIMAL(10,2),
    PrecioUnitario DECIMAL(10,2),
    Cantidad INT,
    TotalDiferencia AS ((PrecioLista - PrecioUnitario) * Cantidad) PERSISTED,
    FOREIGN KEY (ProductoID) REFERENCES dimProductos(ProductoID),
    FOREIGN KEY (VendedorID) REFERENCES dimUbicacionVendedores(VendedorID),
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID)
);

CREATE TABLE factVentasMonedas (
    MonedaId INT,
    TerritorioId INT,
    VendedorId INT,
    FechaId INT,
    Cantidad INT,
    PrecioUnitario DECIMAL(10,2),
    TasaCambioPromedio DECIMAL(10,4),
    VentaMoneda AS (Cantidad * PrecioUnitario * TasaCambioPromedio) PERSISTED,
    FOREIGN KEY (MonedaId) REFERENCES dimMonedas(MonedaId),
    FOREIGN KEY (TerritorioId) REFERENCES dimTerritorios(TerritorioId),
    FOREIGN KEY (VendedorId) REFERENCES dimVendedores(VendedorId),
    FOREIGN KEY (FechaId) REFERENCES dimTiempo(FechaId)
);

CREATE TABLE factCancelaciones (
    IdEmpleado INT,
    DateKey INT,
    CantOrdenesCanceladas INT,
    ValorCancelado DECIMAL(10,2),
    PorcentajeCancelado DECIMAL(5,2),
    FOREIGN KEY (IdEmpleado) REFERENCES dimCapitalHumano(IdEmpleado),
    FOREIGN KEY (DateKey) REFERENCES dimTiempo(FechaId)
);
