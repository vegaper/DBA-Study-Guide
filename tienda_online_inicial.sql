-- PRÁCTICA TIENDA ONLINE | MySQL 8.4.x | InnoDB | UTF-8
-- Archivo para estudiantes. Solo crea la base, sus seis tablas y los datos.
-- No incluye vistas, procedimientos ni triggers resueltos.
-- Ejecutar COMPLETO en una conexión de laboratorio sin transacciones abiertas.
-- La base tienda_online_practica NO debe existir. Detener ante el primer error.
-- No se elimina ni se sobrescribe ninguna base de datos existente.
-- No cambiar el nombre de las tablas ni de las columnas durante la práctica.

SET NAMES utf8mb4;
CREATE DATABASE tienda_online_practica
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE tienda_online_practica;

-- Datos de contacto actuales. Los envíos conservarán su propia copia de dirección.
CREATE TABLE clientes (
  id_cliente INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL,
  direccion VARCHAR(150) NOT NULL,
  codigo_postal CHAR(5) NOT NULL,
  ciudad VARCHAR(80) NOT NULL,
  CONSTRAINT uq_clientes_email UNIQUE (email)
) ENGINE=InnoDB;

-- El precio actual de catálogo puede cambiar sin modificar ventas anteriores.
CREATE TABLE productos (
  id_producto INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(100) NOT NULL,
  precio_actual DECIMAL(10,2) NOT NULL,
  CONSTRAINT ck_productos_precio CHECK (precio_actual > 0)
) ENGINE=InnoDB;

-- La cabecera identifica al cliente y el estado; las líneas van en otra tabla.
CREATE TABLE pedidos (
  id_pedido INT PRIMARY KEY AUTO_INCREMENT,
  id_cliente INT NOT NULL,
  fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado VARCHAR(10) NOT NULL DEFAULT 'BORRADOR',
  CONSTRAINT ck_pedidos_estado
    CHECK (estado IN ('BORRADOR','PENDIENTE','ENVIADO')),
  CONSTRAINT fk_pedidos_clientes FOREIGN KEY (id_cliente)
    REFERENCES clientes(id_cliente)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Se almacena el precio histórico de cada línea, no un total calculado.
CREATE TABLE detalle_pedido (
  id_detalle INT PRIMARY KEY AUTO_INCREMENT,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  CONSTRAINT uq_detalle_producto UNIQUE (id_pedido, id_producto),
  CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_detalle_precio CHECK (precio_unitario > 0),
  CONSTRAINT fk_detalle_pedidos FOREIGN KEY (id_pedido)
    REFERENCES pedidos(id_pedido)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_detalle_productos FOREIGN KEY (id_producto)
    REFERENCES productos(id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Una tarea como máximo por pedido. Permanece como histórico tras completarse.
CREATE TABLE preparacion_pedidos (
  id_preparacion INT PRIMARY KEY AUTO_INCREMENT,
  id_pedido INT NOT NULL,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_preparacion VARCHAR(10) NOT NULL DEFAULT 'PENDIENTE',
  fecha_completada DATETIME NULL,
  CONSTRAINT uq_preparacion_pedido UNIQUE (id_pedido),
  CONSTRAINT ck_preparacion_estado CHECK
    (estado_preparacion IN ('PENDIENTE','COMPLETADA')),
  CONSTRAINT ck_preparacion_fecha CHECK (
    (estado_preparacion = 'PENDIENTE' AND fecha_completada IS NULL)
    OR
    (estado_preparacion = 'COMPLETADA' AND fecha_completada IS NOT NULL)
  ),
  CONSTRAINT fk_preparacion_pedidos FOREIGN KEY (id_pedido)
    REFERENCES pedidos(id_pedido)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Un envío como máximo por pedido. El seguimiento es único dentro del transportista.
CREATE TABLE envios (
  id_envio INT PRIMARY KEY AUTO_INCREMENT,
  id_pedido INT NOT NULL,
  transportista VARCHAR(80) NOT NULL,
  codigo_seguimiento VARCHAR(60) NOT NULL,
  fecha_envio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  destinatario VARCHAR(100) NOT NULL,
  direccion_entrega VARCHAR(150) NOT NULL,
  codigo_postal CHAR(5) NOT NULL,
  ciudad VARCHAR(80) NOT NULL,
  CONSTRAINT uq_envios_pedido UNIQUE (id_pedido),
  CONSTRAINT uq_envios_seguimiento UNIQUE
    (transportista, codigo_seguimiento),
  CONSTRAINT ck_envios_transportista CHECK
    (CHAR_LENGTH(TRIM(transportista)) > 0),
  CONSTRAINT ck_envios_seguimiento CHECK
    (CHAR_LENGTH(TRIM(codigo_seguimiento)) > 0),
  CONSTRAINT fk_envios_pedidos FOREIGN KEY (id_pedido)
    REFERENCES pedidos(id_pedido)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- La carga de datos relacionados se confirma conjuntamente.
START TRANSACTION;

INSERT INTO clientes (id_cliente, nombre, email, direccion, codigo_postal, ciudad) VALUES
  (1, 'Ana García', 'ana.garcia@example.com', 'Calle Olmo 12', '28001', 'Madrid'),
  (2, 'Luis Martín', 'luis.martin@example.com', 'Calle Luna 8', '46001', 'Valencia'),
  (3, 'Marta López', 'marta.lopez@example.com', 'Avenida Norte 23', '41001', 'Sevilla'),
  (4, 'Javier Ruiz', 'javier.ruiz@example.com', 'Calle Río 5', '50001', 'Zaragoza'),
  (5, 'Lucía Pérez', 'lucia.perez@example.com', 'Plaza Mayor 4', '47001', 'Valladolid'),
  (6, 'Diego Sánchez', 'diego.sanchez@example.com', 'Calle Roble 19', '29001', 'Málaga'),
  (7, 'Elena Torres', 'elena.torres@example.com', 'Avenida Mar 31', '03001', 'Alicante'),
  (8, 'Pablo Romero', 'pablo.romero@example.com', 'Calle Sol 6', '15001', 'A Coruña'),
  (9, 'Sara Navarro', 'sara.navarro@example.com', 'Calle Prado 10', '33001', 'Oviedo'),
  (10, 'Hugo Díaz', 'hugo.diaz@example.com', 'Paseo Central 7', '39001', 'Santander');

INSERT INTO productos (id_producto, nombre, precio_actual) VALUES
  (1, 'Ratón inalámbrico', '24.90'),
  (2, 'Teclado USB', '29.90'),
  (3, 'Auriculares USB', '79.90'),
  (4, 'Webcam HD', '39.90'),
  (5, 'Memoria USB 64 GB', '12.50'),
  (6, 'SSD externo 500 GB', '69.00'),
  (7, 'Alfombrilla', '8.00'),
  (8, 'Hub USB', '22.00'),
  (9, 'Cable HDMI', '9.90'),
  (10, 'Soporte portátil', '25.00'),
  (11, 'Monitor 24 pulgadas', '149.00'),
  (12, 'Mochila portátil', '34.90'),
  (13, 'Cargador USB C', '32.00'),
  (14, 'Cable USB C', '7.50'),
  (15, 'Altavoces USB', '27.00');

INSERT INTO pedidos (id_pedido, id_cliente, fecha_pedido, estado) VALUES
  (1, 1, '2026-11-01 10:01:00', 'BORRADOR'),
  (2, 2, '2026-11-01 10:02:00', 'BORRADOR'),
  (3, 3, '2026-11-01 10:03:00', 'BORRADOR'),
  (4, 4, '2026-11-01 10:04:00', 'BORRADOR'),
  (5, 5, '2026-11-02 10:05:00', 'BORRADOR'),
  (6, 6, '2026-11-02 10:06:00', 'BORRADOR'),
  (7, 7, '2026-11-02 10:07:00', 'BORRADOR'),
  (8, 8, '2026-11-02 10:08:00', 'BORRADOR'),
  (9, 9, '2026-11-03 10:09:00', 'PENDIENTE'),
  (10, 10, '2026-11-03 10:10:00', 'PENDIENTE'),
  (11, 1, '2026-11-03 10:11:00', 'PENDIENTE'),
  (12, 2, '2026-11-03 10:12:00', 'PENDIENTE'),
  (13, 3, '2026-11-04 10:13:00', 'PENDIENTE'),
  (14, 4, '2026-11-04 10:14:00', 'PENDIENTE'),
  (15, 5, '2026-11-04 10:15:00', 'PENDIENTE'),
  (16, 6, '2026-11-04 10:16:00', 'ENVIADO'),
  (17, 7, '2026-11-05 10:17:00', 'ENVIADO'),
  (18, 8, '2026-11-05 10:18:00', 'ENVIADO'),
  (19, 9, '2026-11-05 10:19:00', 'ENVIADO'),
  (20, 10, '2026-11-05 10:20:00', 'ENVIADO');

INSERT INTO detalle_pedido (id_detalle, id_pedido, id_producto, cantidad, precio_unitario) VALUES
  (1, 1, 1, 2, '19.90'),
  (2, 1, 2, 1, '29.90'),
  (3, 1, 3, 1, '79.90'),
  (4, 3, 4, 1, '39.90'),
  (5, 3, 5, 2, '12.50'),
  (6, 4, 6, 1, '69.00'),
  (7, 4, 7, 2, '8.00'),
  (8, 5, 8, 1, '22.00'),
  (9, 5, 9, 2, '9.90'),
  (10, 6, 10, 1, '25.00'),
  (11, 6, 11, 1, '149.00'),
  (12, 7, 12, 1, '34.90'),
  (13, 7, 13, 1, '32.00'),
  (14, 8, 14, 3, '7.50'),
  (15, 8, 15, 1, '27.00'),
  (16, 9, 1, 1, '24.90'),
  (17, 9, 5, 2, '12.50'),
  (18, 9, 7, 1, '8.00'),
  (19, 10, 2, 1, '29.90'),
  (20, 10, 8, 1, '22.00'),
  (21, 10, 9, 1, '9.90'),
  (22, 11, 3, 1, '79.90'),
  (23, 11, 10, 1, '25.00'),
  (24, 11, 14, 2, '7.50'),
  (25, 12, 4, 2, '39.90'),
  (26, 12, 12, 1, '34.90'),
  (27, 12, 15, 1, '27.00'),
  (28, 13, 6, 1, '69.00'),
  (29, 13, 13, 1, '32.00'),
  (30, 13, 5, 1, '12.50'),
  (31, 14, 11, 1, '149.00'),
  (32, 14, 9, 2, '9.90'),
  (33, 14, 7, 1, '8.00'),
  (34, 15, 8, 2, '22.00'),
  (35, 15, 14, 2, '7.50'),
  (36, 15, 1, 1, '24.90'),
  (37, 16, 2, 1, '27.90'),
  (38, 16, 5, 2, '11.50'),
  (39, 17, 3, 1, '74.90'),
  (40, 17, 7, 1, '8.00'),
  (41, 18, 4, 1, '39.90'),
  (42, 18, 9, 2, '9.90'),
  (43, 19, 6, 1, '65.00'),
  (44, 19, 12, 1, '34.90'),
  (45, 20, 11, 1, '139.00');

-- Histórico inicial cargado expresamente sin triggers.

INSERT INTO preparacion_pedidos (id_preparacion, id_pedido, fecha_creacion, estado_preparacion, fecha_completada) VALUES
  (1, 9, '2026-11-06 09:09:00', 'PENDIENTE', NULL),
  (2, 10, '2026-11-06 09:10:00', 'PENDIENTE', NULL),
  (3, 11, '2026-11-06 09:11:00', 'PENDIENTE', NULL),
  (4, 12, '2026-11-06 09:12:00', 'PENDIENTE', NULL),
  (5, 13, '2026-11-06 09:13:00', 'PENDIENTE', NULL),
  (6, 14, '2026-11-06 09:14:00', 'PENDIENTE', NULL),
  (7, 15, '2026-11-06 09:15:00', 'PENDIENTE', NULL),
  (8, 16, '2026-11-06 09:16:00', 'COMPLETADA', '2026-11-06 12:16:00'),
  (9, 17, '2026-11-06 09:17:00', 'COMPLETADA', '2026-11-06 12:17:00'),
  (10, 18, '2026-11-06 09:18:00', 'COMPLETADA', '2026-11-06 12:18:00'),
  (11, 19, '2026-11-06 09:19:00', 'COMPLETADA', '2026-11-06 12:19:00'),
  (12, 20, '2026-11-06 09:20:00', 'COMPLETADA', '2026-11-06 12:20:00');

INSERT INTO envios (id_envio, id_pedido, transportista, codigo_seguimiento, fecha_envio, destinatario, direccion_entrega, codigo_postal, ciudad) VALUES
  (1, 16, 'RutaExpress', 'TRK-0016', '2026-11-06 12:16:00', 'Diego Sánchez', 'Calle Roble 19', '29001', 'Málaga'),
  (2, 17, 'RutaExpress', 'TRK-0017', '2026-11-06 12:17:00', 'Elena Torres', 'Avenida Mar 31', '03001', 'Alicante'),
  (3, 18, 'RutaExpress', 'TRK-0018', '2026-11-06 12:18:00', 'Pablo Romero', 'Calle Sol 6', '15001', 'A Coruña'),
  (4, 19, 'RutaExpress', 'TRK-0019', '2026-11-06 12:19:00', 'Sara Navarro', 'Calle Prado 10', '33001', 'Oviedo'),
  (5, 20, 'RutaExpress', 'TRK-0020', '2026-11-06 12:20:00', 'Hugo Díaz', 'Paseo Central 7', '39001', 'Santander');

COMMIT;

-- Comprobaciones de carga. No resuelven los objetos solicitados.
SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido
UNION ALL SELECT 'preparacion_pedidos', COUNT(*) FROM preparacion_pedidos
UNION ALL SELECT 'envios', COUNT(*) FROM envios;

SELECT estado, COUNT(*) AS pedidos
FROM pedidos GROUP BY estado ORDER BY estado;
-- Esperado: BORRADOR 8, ENVIADO 5, PENDIENTE 7.
-- Pedido 2: borrador vacío para la prueba de rechazo.
-- Pedido 1: 3 líneas, 4 unidades e importe 149.60.
