-- SOLO para lab_concurrencia de esta práctica: borra los resultados
-- de sus ejercicios y restaura los cuatro artículos iniciales.
-- Antes: terminar sentencias en espera, UNLOCK TABLES si se usó,
-- ROLLBACK en A y B, y autocommit=1 en ambas conexiones.
-- Ejecutar únicamente en A, nunca entre pasos de un mismo caso.
ROLLBACK;
SET SESSION autocommit = 1;
USE lab_concurrencia;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION innodb_lock_wait_timeout = 300;
SET NAMES utf8mb4;
START TRANSACTION;
-- Hijos primero para respetar las claves foráneas.
DELETE FROM ventas;
DELETE FROM presupuestos;
DELETE FROM existencias;
DELETE FROM articulos;
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
SELECT (SELECT COUNT(*) FROM presupuestos) AS presupuestos,
       (SELECT COUNT(*) FROM ventas) AS ventas;
