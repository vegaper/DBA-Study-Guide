-- LABORATORIO AUTONOMO MYSQL 8.4 / INNODB
DROP DATABASE IF EXISTS laboratorio_transacciones_seguras;
CREATE DATABASE laboratorio_transacciones_seguras CHARACTER SET utf8mb4;
USE laboratorio_transacciones_seguras;
CREATE TABLE cuentas(id_cuenta VARCHAR(10) PRIMARY KEY, titular VARCHAR(50) NOT NULL, saldo DECIMAL(12,2) NOT NULL, CONSTRAINT ck_saldo CHECK(saldo>=0)) ENGINE=InnoDB;
CREATE TABLE productos(id_producto INT PRIMARY KEY, nombre VARCHAR(60) NOT NULL, stock INT NOT NULL, precio DECIMAL(10,2) NOT NULL, CONSTRAINT ck_stock CHECK(stock>=0)) ENGINE=InnoDB;
CREATE TABLE clientes(id_cliente INT PRIMARY KEY, nombre VARCHAR(60) NOT NULL, email VARCHAR(100) NOT NULL UNIQUE) ENGINE=InnoDB;
CREATE TABLE pedidos(id_pedido INT PRIMARY KEY, id_cliente INT NOT NULL, estado VARCHAR(20) NOT NULL, FOREIGN KEY(id_cliente) REFERENCES clientes(id_cliente)) ENGINE=InnoDB;
CREATE TABLE detalle_pedido(id_pedido INT NOT NULL, id_producto INT NOT NULL, cantidad INT NOT NULL, PRIMARY KEY(id_pedido,id_producto), FOREIGN KEY(id_pedido) REFERENCES pedidos(id_pedido), FOREIGN KEY(id_producto) REFERENCES productos(id_producto), CHECK(cantidad>0)) ENGINE=InnoDB;
CREATE TABLE plazas(id_plaza INT PRIMARY KEY, ocupada_por INT NULL UNIQUE, FOREIGN KEY(ocupada_por) REFERENCES clientes(id_cliente)) ENGINE=InnoDB;
DELIMITER $$
CREATE PROCEDURE reiniciar_datos()
BEGIN
    -- Si alguna instrucción falla, deshacer todo el reinicio y comunicar el error.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Primero se eliminan las filas de las tablas dependientes.
    DELETE FROM detalle_pedido;
    DELETE FROM pedidos;
    DELETE FROM plazas;  -- ANTES solo se liberaban las plazas: sus IDs seguían existiendo.
    DELETE FROM productos;
    DELETE FROM cuentas;
    DELETE FROM clientes;

    -- Restaurar exactamente el estado inicial, incluido el de las plazas.
    INSERT INTO cuentas (id_cuenta,titular,saldo)
    VALUES ('A','Ana',500),('B','Bruno',200),('C','Carla',0);

    INSERT INTO productos (id_producto,nombre,stock,precio)
    VALUES (1,'Teclado',5,20),(2,'Ratón',2,15),(3,'Monitor',1,150);

    INSERT INTO clientes (id_cliente,nombre,email)
    VALUES (1,'Ana','ana@ejemplo.test'),(2,'Bruno','bruno@ejemplo.test');

    INSERT INTO plazas (id_plaza,ocupada_por)
    VALUES (1,NULL),(2,NULL);

    COMMIT;
END$$
DELIMITER ;
CALL reiniciar_datos();

-- Procedimiento: valida resultado de cada UPDATE y revierte ante excepciones
DELIMITER $$
CREATE PROCEDURE transferir(IN p_origen VARCHAR(10),IN p_destino VARCHAR(10),IN p_importe DECIMAL(12,2))
BEGIN
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 IF p_importe IS NULL OR p_importe<=0 OR p_origen IS NULL OR p_destino IS NULL OR p_origen=p_destino THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Parametros invalidos';
 END IF;
 UPDATE cuentas SET saldo=saldo-p_importe WHERE id_cuenta=p_origen AND saldo>=p_importe;
 IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Origen inexistente o saldo insuficiente'; END IF;
 UPDATE cuentas SET saldo=saldo+p_importe WHERE id_cuenta=p_destino;
 IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Destino inexistente'; END IF;
 COMMIT;
END$$
CREATE PROCEDURE vender(IN p_producto INT,IN p_cantidad INT)
BEGIN
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 IF p_cantidad IS NULL OR p_cantidad<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cantidad invalida'; END IF;
 UPDATE productos SET stock=stock-p_cantidad WHERE id_producto=p_producto AND stock>=p_cantidad;
 IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Producto inexistente o stock insuficiente'; END IF;
 COMMIT;
END$$
DELIMITER ;
