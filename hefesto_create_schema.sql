
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
    TipoProduccion NVARCHAR(20), -- 'Fabricado' o 'Comprado'
    Color NVARCHAR(50),
	Tamaño NVARCHAR(50),
);

CREATE TABLE dimMonedas (
    MonedaID nchar(3) PRIMARY KEY,
    Moneda NVARCHAR(50)
);

CREATE TABLE dimTerritorios (
    TerritorioID INT PRIMARY KEY,
    NombreTerritorio NVARCHAR(100) NOT NULL,         -- Nombre del territorio (ej: "Southwest")
    Grupo NVARCHAR(50),                              -- Grupo comercial (ej: "North America")
    Pais NVARCHAR(50),                               -- País principal relacionado (ej: "United States")
    Region NVARCHAR(50)                              -- Región geográfica mayor o continente (ej: "América", "Europa", etc.)
);

-- ===========================
-- Tabla de Dimensión Tiempo
-- ===========================
CREATE TABLE dimTiempo (
    FechaID INT PRIMARY KEY, -- formato: YYYYMMDD
    FechaCompleta DATE NOT NULL,
    Año INT NOT NULL,
    Mes NVARCHAR(20) NOT NULL,
    NumeroMes INT NOT NULL,
    Trimestre INT NOT NULL,
    NombreTrimestre NVARCHAR(20),     -- Ej: "1er Trimestre"
    NombreSemestre NVARCHAR(20),      -- Ej: "1er Semestre"
    NumeroDia INT NOT NULL,           -- Ej: 1-31
    NombreDia NVARCHAR(20)            -- Ej: "Lunes"
);

-- =========================================
-- Dimensión unificada: Vendedores
-- =========================================

CREATE TABLE dimVendedores (
    VendedorID INT PRIMARY KEY,
    NombreCompleto NVARCHAR(101),
    CiudadID INT FOREIGN KEY REFERENCES dimCiudad(CiudadID),
    TerritorioID INT FOREIGN KEY REFERENCES dimTerritorios(TerritorioID),
    Cargo NVARCHAR(101),
    TipoContrato NVARCHAR(20), -- 'Asalariado' o 'No Asalariado'
    PorcentajeComision DECIMAL(5,2),
    Tipo NCHAR(2),
	Genero NVARCHAR(20)
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
    FechaID INT,
    PrecioLista DECIMAL(10,2),
    PrecioUnitario DECIMAL(10,2),  -- Ya con descuento aplicado
    CantidadUnidadesProducto INT,
    DiferenciaUnitario AS (
        PrecioLista - PrecioUnitario
    ) PERSISTED,
    DiferenciaTotal AS (
        (PrecioLista - PrecioUnitario) * CantidadUnidadesProducto
    ) PERSISTED,
    PRIMARY KEY (ProductoID, VendedorID, OrdenID),
    FOREIGN KEY (ProductoID) REFERENCES dimProductos(ProductoID),
    FOREIGN KEY (VendedorID) REFERENCES dimVendedores(VendedorID),
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID),
    FOREIGN KEY (FechaID) REFERENCES dimTiempo(FechaID)
);

-- Pregunta 2: Ventas en moneda extranjera
CREATE TABLE FactVentasMonedas (
    OrdenID INT,
    MonedaID NCHAR(3),
    VendedorID INT,
    FechaID INT,
    CantidadUnidadesVendidas INT,
    PrecioUnitario DECIMAL(10,2),
    TasaCambioPromedio DECIMAL(10,4),
    VentaMoneda AS (CantidadUnidadesVendidas * PrecioUnitario * TasaCambioPromedio) PERSISTED,
    FOREIGN KEY (OrdenID) REFERENCES dimOrdenes(OrdenID),
    FOREIGN KEY (MonedaID) REFERENCES dimMonedas(MonedaID),
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
