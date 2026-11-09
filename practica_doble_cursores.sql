-- Utilizamos UTF-8 para conservar las tildes.
SET NAMES utf8mb4;

-- Creamos una base independiente para estas dos prácticas.
CREATE DATABASE laboratorio_cursor
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

-- Seleccionamos la base en la que trabajaremos.
USE laboratorio_cursor;

-- =====================================================
-- CASO A: FACTURACIÓN TELEFÓNICA
-- =====================================================

-- Cada contrato contiene los importes de octubre de 2026.
CREATE TABLE contratos (
    id_contrato INT PRIMARY KEY,
    cliente VARCHAR(50) NOT NULL,
    cuota DECIMAL(8,2) NOT NULL CHECK (cuota >= 0),
    extras DECIMAL(8,2) NOT NULL CHECK (extras >= 0),
    descuento DECIMAL(8,2) NOT NULL CHECK (descuento >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (cuota + extras >= descuento)
) ENGINE = InnoDB;

-- La cabecera identifica la factura y guarda su total.
CREATE TABLE facturas (
    id_factura INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato INT NOT NULL,
    periodo DATE NOT NULL,
    total DECIMAL(8,2) NOT NULL CHECK (total >= 0),

    -- Un contrato solo puede tener una factura del mismo mes.
    UNIQUE (id_contrato, periodo),

    FOREIGN KEY (id_contrato)
        REFERENCES contratos(id_contrato)
) ENGINE = InnoDB;

-- Cada factura tendrá sus conceptos: cuota, extras y descuento.
CREATE TABLE detalle_factura (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_factura INT NOT NULL,
    concepto VARCHAR(30) NOT NULL,
    importe DECIMAL(8,2) NOT NULL,

    FOREIGN KEY (id_factura)
        REFERENCES facturas(id_factura)
) ENGINE = InnoDB;

-- Cargamos tres situaciones diferentes.
INSERT INTO contratos
    (id_contrato, cliente, cuota, extras, descuento)
VALUES
    (1, 'Ana',   30.00,  0.00,  0.00),
    (2, 'Luis',  25.00, 12.50,  0.00),
    (3, 'Marta', 40.00,  5.00, 10.00);

-- =====================================================
-- CASO B: CIERRE DE PEDIDOS
-- =====================================================

-- Guardamos las existencias disponibles.
CREATE TABLE productos (
    id_producto INT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0)
) ENGINE = InnoDB;

-- Para simplificar, cada pedido contiene un solo producto.
CREATE TABLE pedidos (
    id_pedido INT PRIMARY KEY,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    pagado BOOLEAN NOT NULL,
    estado ENUM('pendiente', 'cerrado')
        NOT NULL DEFAULT 'pendiente',

    FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto)
) ENGINE = InnoDB;

-- Registramos qué salida de existencias corresponde a cada pedido.
CREATE TABLE movimientos_stock (
    id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT NOT NULL UNIQUE,
    id_producto INT NOT NULL,
    unidades INT NOT NULL CHECK (unidades < 0),

    FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido),

    FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto)
) ENGINE = InnoDB;

-- Existencias iniciales.
INSERT INTO productos VALUES
    (1, 'Teclado', 10),
    (2, 'Ratón',    8);

-- Dos pedidos están pagados; el tercero todavía no.
INSERT INTO pedidos
    (id_pedido, id_producto, cantidad, pagado)
VALUES
    (101, 1, 2, TRUE),
    (108, 2, 3, TRUE),
    (125, 1, 1, FALSE);

-- Comprobamos que se han cargado los datos.
SELECT * FROM contratos ORDER BY id_contrato;
SELECT * FROM productos ORDER BY id_producto;
SELECT * FROM pedidos ORDER BY id_pedido;