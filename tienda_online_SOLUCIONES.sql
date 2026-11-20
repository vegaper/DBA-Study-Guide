-- Soluciones de la práctica Tienda online.
-- Ejecutar después de 00_tienda_online_inicial.sql y antes de las pruebas.

SET NAMES utf8mb4;
USE tienda_online_practica;

-- Recrea únicamente los cinco objetos de la solución.
DROP VIEW IF EXISTS vista_resumen_pedidos;
DROP TRIGGER IF EXISTS trg_pedidos_au;
DROP TRIGGER IF EXISTS trg_envios_ai;
DROP PROCEDURE IF EXISTS sp_confirmar_pedido;
DROP PROCEDURE IF EXISTS sp_registrar_envio;

-- Una fila por pedido, incluso cuando no tiene líneas o no se ha enviado.
CREATE SQL SECURITY INVOKER VIEW vista_resumen_pedidos AS
SELECT
  p.id_pedido,
  p.fecha_pedido,
  c.nombre AS cliente,
  p.estado AS estado_pedido,
  -- Cuenta la clave del detalle: un pedido vacío tiene cero líneas.
  COUNT(d.id_detalle) AS numero_lineas,
  -- La suma sin filas sería NULL; en cantidades e importes se convierte a cero.
  COALESCE(SUM(d.cantidad), 0) AS total_unidades,
  COALESCE(SUM(d.cantidad * d.precio_unitario), 0.00)
    AS importe_total,
  pr.estado_preparacion,
  e.transportista,
  e.codigo_seguimiento,
  e.fecha_envio
FROM pedidos AS p
-- El cliente es obligatorio por su clave foránea y NOT NULL.
INNER JOIN clientes AS c ON c.id_cliente = p.id_cliente
-- Estas relaciones son opcionales para algunos pedidos.
LEFT JOIN detalle_pedido AS d ON d.id_pedido = p.id_pedido
LEFT JOIN preparacion_pedidos AS pr ON pr.id_pedido = p.id_pedido
LEFT JOIN envios AS e ON e.id_pedido = p.id_pedido
-- Se agrupan todas las columnas que no participan en agregaciones.
GROUP BY p.id_pedido, p.fecha_pedido, c.nombre, p.estado,
  pr.estado_preparacion, e.transportista,
  e.codigo_seguimiento, e.fecha_envio;
-- El orden se solicita al consultar la vista, no se presupone dentro de ella.

DELIMITER //
-- Reacciona a los dos cambios de estado admitidos.
CREATE TRIGGER trg_pedidos_au
AFTER UPDATE ON pedidos
FOR EACH ROW
BEGIN
  -- Comparar OLD y NEW evita actuar si se mantiene el mismo estado.
  IF OLD.estado <> NEW.estado THEN
    IF OLD.estado = 'BORRADOR' AND NEW.estado = 'PENDIENTE' THEN
      -- La restricción UNIQUE impide tener dos tareas para el mismo pedido.
      INSERT INTO preparacion_pedidos
        (id_pedido, fecha_creacion, estado_preparacion, fecha_completada)
      VALUES (NEW.id_pedido, CURRENT_TIMESTAMP, 'PENDIENTE', NULL);
    ELSEIF OLD.estado = 'PENDIENTE' AND NEW.estado = 'ENVIADO' THEN
      -- Conserva la tarea como histórico y anota su finalización.
      UPDATE preparacion_pedidos
      SET estado_preparacion = 'COMPLETADA',
          fecha_completada = CURRENT_TIMESTAMP
      WHERE id_pedido = NEW.id_pedido
        AND estado_preparacion = 'PENDIENTE';
      -- Debe haberse completado exactamente una tarea.
      IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El pedido no tiene una preparacion pendiente';
      END IF;
    ELSE
      -- Rechaza saltos de estado y retrocesos en una actualización.
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transicion de estado no permitida';
    END IF;
  END IF;
END //
DELIMITER ;

DELIMITER //
-- Registrar la salida activa el cambio comercial del pedido.
CREATE TRIGGER trg_envios_ai
AFTER INSERT ON envios
FOR EACH ROW
BEGIN
  -- No modifica envios: actualiza una tabla distinta de la que lo activa.
  UPDATE pedidos
  SET estado = 'ENVIADO'
  WHERE id_pedido = NEW.id_pedido AND estado = 'PENDIENTE';
  -- El UPDATE anterior activa trg_pedidos_au, que completa la preparación.
  IF ROW_COUNT() <> 1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Solo se pueden enviar pedidos pendientes';
  END IF;
END //
DELIMITER ;

DELIMITER //
-- Confirma un borrador que contiene al menos una línea.
CREATE PROCEDURE sp_confirmar_pedido(IN p_id_pedido INT)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
  DECLARE v_estado VARCHAR(10) DEFAULT NULL;
  DECLARE v_lineas INT DEFAULT 0;
  -- SELECT INTO sin fila activa NOT FOUND; se controla de forma explícita.
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_estado = NULL;
  -- Un error de validación o de un trigger también llega a este manejador.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    -- Devuelve el error original a quien ejecuta CALL.
    RESIGNAL;
  END;

  START TRANSACTION;
  IF p_id_pedido IS NULL OR p_id_pedido <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Identificador de pedido no valido';
  END IF;
  -- Bloquea este pedido hasta COMMIT o ROLLBACK.
  SELECT estado INTO v_estado
  FROM pedidos WHERE id_pedido = p_id_pedido FOR UPDATE;
  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El pedido no existe';
  END IF;
  IF v_estado <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Solo se pueden confirmar pedidos en BORRADOR';
  END IF;
  -- COUNT sin GROUP BY devuelve una fila incluso si no hay detalles.
  SELECT COUNT(*) INTO v_lineas
  FROM detalle_pedido WHERE id_pedido = p_id_pedido;
  IF v_lineas = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se puede confirmar un pedido sin productos';
  END IF;
  -- El trigger se encarga de crear la tarea; aquí no se duplica ese INSERT.
  UPDATE pedidos SET estado = 'PENDIENTE'
  WHERE id_pedido = p_id_pedido;
  COMMIT;
END //
DELIMITER ;

DELIMITER //
-- Registra la salida real del pedido dentro de la simulación del laboratorio.
CREATE PROCEDURE sp_registrar_envio(
  IN p_id_pedido INT,
  IN p_transportista VARCHAR(80),
  IN p_codigo_seguimiento VARCHAR(60)
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
  DECLARE v_estado VARCHAR(10) DEFAULT NULL;
  DECLARE v_id_cliente INT;
  DECLARE v_numero INT DEFAULT 0;
  DECLARE v_destinatario VARCHAR(100);
  DECLARE v_direccion VARCHAR(150);
  DECLARE v_codigo_postal CHAR(5);
  DECLARE v_ciudad VARCHAR(80);
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_estado = NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  IF p_id_pedido IS NULL OR p_id_pedido <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Identificador de pedido no valido';
  END IF;
  -- TRIM elimina espacios al principio y al final, no los interiores.
  IF p_transportista IS NULL
     OR CHAR_LENGTH(TRIM(p_transportista)) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El transportista es obligatorio';
  END IF;
  IF p_codigo_seguimiento IS NULL
     OR CHAR_LENGTH(TRIM(p_codigo_seguimiento)) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El codigo de seguimiento es obligatorio';
  END IF;

  SELECT estado, id_cliente INTO v_estado, v_id_cliente
  FROM pedidos WHERE id_pedido = p_id_pedido FOR UPDATE;
  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El pedido no existe';
  END IF;
  IF v_estado <> 'PENDIENTE' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Solo se pueden enviar pedidos pendientes';
  END IF;
  SELECT COUNT(*) INTO v_numero FROM envios
  WHERE id_pedido = p_id_pedido;
  IF v_numero <> 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El pedido ya tiene un envio';
  END IF;
  SELECT COUNT(*) INTO v_numero FROM preparacion_pedidos
  WHERE id_pedido = p_id_pedido AND estado_preparacion = 'PENDIENTE';
  IF v_numero <> 1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El pedido no tiene una preparacion pendiente';
  END IF;

  -- Captura la dirección actual en variables antes de insertar el envío.
  SELECT nombre, direccion, codigo_postal, ciudad
  INTO v_destinatario, v_direccion, v_codigo_postal, v_ciudad
  FROM clientes WHERE id_cliente = v_id_cliente;
  -- VALUES evita leer pedidos dentro de la sentencia que activa el trigger
  -- que, a su vez, modifica pedidos. Así se evita la restricción de MySQL 1442.
  INSERT INTO envios
    (id_pedido, transportista, codigo_seguimiento, fecha_envio,
     destinatario, direccion_entrega, codigo_postal, ciudad)
  VALUES
    (p_id_pedido, TRIM(p_transportista), TRIM(p_codigo_seguimiento),
     CURRENT_TIMESTAMP, v_destinatario, v_direccion,
     v_codigo_postal, v_ciudad);
  -- Los dos triggers actualizan pedido y preparación dentro de esta transacción.
  COMMIT;
END //

DELIMITER ;

