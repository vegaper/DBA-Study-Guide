-- MySQL 8.4 / InnoDB / UTF-8
-- Preparación inicial de la nueva práctica de bloqueos y aislamiento.
-- Ejecutar UNA VEZ en una conexión dedicada, sin trabajo pendiente.
-- lab_concurrencia NO debe existir. No ejecutar con la opción --force.
-- Si ya existe, utilizar 01_reiniciar_laboratorio_concurrencia.sql
-- solo cuando su estructura corresponda a esta práctica.
-- No se elimina ninguna base de datos preexistente.

SET NAMES utf8mb4;
CREATE DATABASE lab_concurrencia
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE lab_concurrencia;

-- Catálogo y precio. Se separan de existencias para poder proteger
-- un precio sin bloquear por ese motivo el registro de stock.
CREATE TABLE articulos (
    id_articulo INT NOT NULL,
    descripcion VARCHAR(80) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_articulo),
    KEY idx_precio (precio),
    CONSTRAINT ck_articulos_precio CHECK (precio > 0)
) ENGINE = InnoDB;

CREATE TABLE existencias (
    id_articulo INT NOT NULL,
    unidades INT NOT NULL,
    PRIMARY KEY (id_articulo),
    CONSTRAINT ck_existencias_unidades CHECK (unidades >= 0),
    CONSTRAINT fk_existencias_articulo FOREIGN KEY (id_articulo)
      REFERENCES articulos (id_articulo)
      ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- Cada presupuesto conserva el precio que se aplicó.
-- No descuenta stock ni equivale a una reserva comercial.
CREATE TABLE presupuestos (
    id_presupuesto INT NOT NULL,
    id_articulo INT NOT NULL,
    operador VARCHAR(20) NOT NULL,
    unidades INT NOT NULL,
    precio_aplicado DECIMAL(10,2) NOT NULL,
    importe DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_presupuesto),
    CONSTRAINT ck_presupuestos_valores CHECK (
      unidades > 0 AND precio_aplicado > 0 AND importe > 0),
    CONSTRAINT ck_presupuestos_importe CHECK (
      importe = unidades * precio_aplicado),
    CONSTRAINT fk_presupuestos_articulo FOREIGN KEY (id_articulo)
      REFERENCES articulos (id_articulo)
      ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE ventas (
    id_venta INT NOT NULL,
    id_articulo INT NOT NULL,
    operador VARCHAR(20) NOT NULL,
    unidades INT NOT NULL,
    precio_aplicado DECIMAL(10,2) NOT NULL,
    importe DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_venta),
    CONSTRAINT ck_ventas_valores CHECK (
      unidades > 0 AND precio_aplicado > 0 AND importe > 0),
    CONSTRAINT ck_ventas_importe CHECK (
      importe = unidades * precio_aplicado),
    CONSTRAINT fk_ventas_articulo FOREIGN KEY (id_articulo)
      REFERENCES articulos (id_articulo)
      ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

START TRANSACTION;
INSERT INTO articulos (id_articulo, descripcion, precio) VALUES
  (1, 'Teclado', 20.00),
  (2, 'Ratón', 30.00),
  (3, 'Monitor', 200.00),
  (4, 'Impresora', 150.00);
INSERT INTO existencias (id_articulo, unidades) VALUES
  (1, 1), (2, 10), (3, 5), (4, 2);
COMMIT;

SELECT a.id_articulo, a.descripcion, a.precio, e.unidades
FROM articulos AS a
JOIN existencias AS e ON e.id_articulo = a.id_articulo
ORDER BY a.id_articulo;
SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'lab_concurrencia' ORDER BY TABLE_NAME;

-- Para trabajar desde otra conexión: USE lab_concurrencia;
-- Configuración de A y B: seguir el documento Word.
