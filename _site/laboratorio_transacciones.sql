-- ============================================================
-- PREPARACIÓN DE LA PRÁCTICA DE TRANSACCIONES
-- MySQL 8.4 / tablas InnoDB / archivo UTF-8
-- ============================================================
-- Ejecutar una sola vez antes de comenzar la guía.
-- La base de datos laboratorio_transacciones no debe existir.
-- CREATE DATABASE devuelve un error si ya existe, para evitar
-- cargar estos datos sobre una práctica anterior.
--
-- Desde el cliente mysql, indicando la ruta real del archivo:
-- SOURCE /home/sysadmin/laboratorio_transacciones.sql;
--
-- Después, en las dos conexiones independientes (A y B):
-- USE laboratorio_transacciones;
--
-- Para repetir ejercicios, utilizar la preparación común de
-- la guía; no volver a ejecutar este archivo.
-- ============================================================

-- 1. Crear y seleccionar la base de datos.
-- utf8mb4 permite almacenar correctamente los caracteres Unicode.
CREATE DATABASE laboratorio_transacciones
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE laboratorio_transacciones;

-- 2. Crear la tabla de cuentas.
-- La clave primaria identifica cada cuenta de forma única.
-- DECIMAL almacena los importes con dos decimales de forma exacta.
-- InnoDB permite confirmar o deshacer las modificaciones.
CREATE TABLE cuentas (
    id_cuenta INT NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id_cuenta)
) ENGINE = InnoDB;

-- 3. Crear la tabla de productos.
-- stock es un número entero de unidades.
CREATE TABLE productos (
    id_producto INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL,
    PRIMARY KEY (id_producto)
) ENGINE = InnoDB;

-- 4. Insertar y confirmar los datos iniciales.
-- Los INSERT forman una única transacción de carga.
START TRANSACTION;

INSERT INTO cuentas (id_cuenta, titular, saldo)
VALUES
    (1, 'Ana', 1000.00),
    (2, 'Luis', 500.00);

INSERT INTO productos (id_producto, nombre, precio, stock)
VALUES
    (1, 'Teclado', 20.00, 1),
    (2, 'Ratón', 30.00, 10),
    (3, 'Monitor', 40.00, 5);

COMMIT;

-- 5. Comprobar los datos iniciales.
-- Resultado: dos cuentas y tres productos.
SELECT id_cuenta, titular, saldo
FROM cuentas
ORDER BY id_cuenta;

SELECT id_producto, nombre, precio, stock
FROM productos
ORDER BY id_producto;

-- Resultado esperado: 1500.00.
SELECT SUM(saldo) AS saldo_total
FROM cuentas;

-- Resultado esperado: 0; la cuenta 9999 no debe existir.
SELECT COUNT(*) AS cuentas_con_id_9999
FROM cuentas
WHERE id_cuenta = 9999;

-- Resultado esperado: las dos tablas utilizan InnoDB.
SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'laboratorio_transacciones'
ORDER BY TABLE_NAME;

