-- 13b BLOQUES GUIADOS. NO EJECUTAR TODO EL ARCHIVO.
-- Seleccionar UN bloque cada vez siguiendo el Word.
-- B06,B09,B12,B15,B25,B26,B31,B36,B39,B43 producen errores intencionados.
-- Los bloques B45-B47 son opcionales y usan dos conexiones distintas.
-- 00_preparar_13b.sql debe haber terminado correctamente.
-- DDL fuera de las transacciones; no cambiar de conexion sin recuperar B02.
USE academia_it;
SET NAMES utf8mb4;


-- B01 -----------------------------------------------------------
USE academia_it;
-- Version, base seleccionada y opciones de esta sesion.
SELECT VERSION(), DATABASE(), @@autocommit,
       @@sql_mode, @@lower_case_table_names;
SHOW GRANTS;
SHOW TRIGGERS FROM academia_it;
SHOW CREATE TABLE alumnos;
SHOW CREATE TABLE matriculas;
SHOW CREATE TABLE notas;

-- B02 -----------------------------------------------------------
-- Recuperamos los identificadores de nuestros alumnos.
SET @a=(SELECT id_alumno FROM alumnos
        WHERE email='lab13b.a@example.com');
SET @b=(SELECT id_alumno FROM alumnos
        WHERE email='lab13b.b@example.com');
SET @c=(SELECT id_alumno FROM alumnos
        WHERE email='lab13b.c@example.com');
-- A tiene dos matriculas y B tiene una.
SET @ma1=(SELECT MIN(id_matricula) FROM matriculas
          WHERE id_alumno=@a);
SET @ma2=(SELECT MAX(id_matricula) FROM matriculas
          WHERE id_alumno=@a);
SET @mb1=(SELECT id_matricula FROM matriculas
          WHERE id_alumno=@b);
SELECT @a,@b,@c,@ma1,@ma2,@mb1;
SELECT * FROM lab13b_resumen ORDER BY id_alumno;

-- B03 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_alumnos_bi
BEFORE INSERT ON alumnos
FOR EACH ROW
BEGIN
  -- Preparamos el dato de la nueva fila.
  SET NEW.email=LOWER(TRIM(NEW.email));
END//
DELIMITER ;

-- B04 -----------------------------------------------------------
START TRANSACTION;
INSERT INTO alumnos(nombre,apellido1,email,fecha_alta,activo)
VALUES('Lab13b D','Triggers13b',
       '  LAB13B.D@EXAMPLE.COM  ',CURDATE(),1);
SET @d=LAST_INSERT_ID();
SELECT id_alumno,email FROM alumnos WHERE id_alumno=@d;
-- Eliminamos los efectos de esta prueba completa.
ROLLBACK;
SELECT COUNT(*) AS alumno_d FROM alumnos
WHERE id_alumno=@d;

-- B05 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_alumnos_bu
BEFORE UPDATE ON alumnos
FOR EACH ROW
BEGIN
  SET NEW.email=LOWER(TRIM(NEW.email));
END//
DELIMITER ;
UPDATE alumnos SET email='  LAB13B.A@EXAMPLE.COM  '
WHERE id_alumno=@a;
SELECT email FROM alumnos WHERE id_alumno=@a;

-- B06 -----------------------------------------------------------
-- ERROR ESPERADO 1062. Ejecutar solo esta sentencia.
UPDATE alumnos SET email='  LAB13B.A@EXAMPLE.COM  '
WHERE id_alumno=@b;

-- B07 -----------------------------------------------------------
SELECT id_alumno,email FROM alumnos
WHERE id_alumno IN (@a,@b) ORDER BY id_alumno;

-- B08 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_alumnos_bd
BEFORE DELETE ON alumnos
FOR EACH ROW
BEGIN
  -- OLD contiene la fila que se quiere borrar.
  IF OLD.activo=1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='No se puede borrar un alumno activo';
  END IF;
END//
DELIMITER ;

-- B09 -----------------------------------------------------------
-- ERROR ESPERADO 1644. C no tiene matriculas.
DELETE FROM alumnos WHERE id_alumno=@c;

-- B10 -----------------------------------------------------------
START TRANSACTION;
UPDATE alumnos SET activo=0 WHERE id_alumno=@c;
DELETE FROM alumnos WHERE id_alumno=@c;
SELECT COUNT(*) AS existe_c FROM alumnos WHERE id_alumno=@c;
ROLLBACK;
SELECT id_alumno,activo FROM alumnos WHERE id_alumno=@c;

-- B11 -----------------------------------------------------------
-- Abrimos la prueba; aun no la hemos terminado.
START TRANSACTION;
UPDATE alumnos SET activo=0 WHERE id_alumno=@a;

-- B12 -----------------------------------------------------------
-- ERROR ESPERADO 1451 por las relaciones existentes.
DELETE FROM alumnos WHERE id_alumno=@a;

-- B13 -----------------------------------------------------------
-- Cerrar la prueba aunque el DELETE anterior falle.
ROLLBACK;
SELECT activo FROM alumnos WHERE id_alumno=@a;

-- B14 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_notas_bi
BEFORE INSERT ON notas
FOR EACH ROW
BEGIN
  -- NULL representa una evaluacion pendiente.
  IF NEW.nota IS NOT NULL
     AND (NEW.nota<0 OR NEW.nota>10) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='La nota debe estar entre 0 y 10';
  END IF;
END//
DELIMITER ;

-- B15 -----------------------------------------------------------
-- ERROR ESPERADO 1644. 11 cabe en DECIMAL(4,2).
INSERT INTO notas(id_matricula,nota) VALUES(@ma1,11.00);

-- B16 -----------------------------------------------------------
SELECT COUNT(*) AS notas_de_prueba FROM notas
WHERE id_matricula IN (@ma1,@ma2,@mb1);

-- B17 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_notas_bu
BEFORE UPDATE ON notas
FOR EACH ROW
BEGIN
  -- Una nota conserva su identidad y su matricula.
  IF NEW.id_nota<>OLD.id_nota
     OR NEW.id_matricula<>OLD.id_matricula THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='No se puede reasignar una nota';
  END IF;
  IF NEW.nota IS NOT NULL
     AND (NEW.nota<0 OR NEW.nota>10) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='La nota debe estar entre 0 y 10';
  END IF;
END//
DELIMITER ;

-- B18 -----------------------------------------------------------
SHOW CREATE TABLE lab13b_resumen;
SELECT * FROM lab13b_resumen ORDER BY id_alumno;

-- B19 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_notas_ai
AFTER INSERT ON notas
FOR EACH ROW
BEGIN
  DECLARE v_alumno INT UNSIGNED;
  -- La nota apunta a una matricula, no al alumno directamente.
  SELECT id_alumno INTO v_alumno FROM matriculas
  WHERE id_matricula=NEW.id_matricula;
  -- Solo hay fila de resumen para A y B.
  UPDATE lab13b_resumen
  SET registradas=registradas+1,
      evaluadas=evaluadas+(NEW.nota IS NOT NULL),
      aprobadas=aprobadas+IFNULL(NEW.nota>=5,0),
      suma=suma+IFNULL(NEW.nota,0)
  WHERE id_alumno=v_alumno;
END//
DELIMITER ;

-- B20 -----------------------------------------------------------
-- Una sola sentencia incorpora dos filas para A.
INSERT INTO notas(id_matricula,nota,fecha_evaluacion,observaciones)
VALUES(@ma1,6.00,CURDATE(),'Evaluacion A1'),
      (@ma2,NULL,NULL,'Pendiente A2');
-- Una tercera fila pertenece a B.
INSERT INTO notas(id_matricula,nota,fecha_evaluacion,observaciones)
VALUES(@mb1,4.00,CURDATE(),'Evaluacion B1');
SELECT * FROM lab13b_resumen ORDER BY id_alumno;

-- B21 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_notas_au
AFTER UPDATE ON notas
FOR EACH ROW
BEGIN
  DECLARE v_alumno INT UNSIGNED;
  -- Evitamos recalcular si la nota sigue igual, incluso NULL.
  IF NOT (OLD.nota <=> NEW.nota) THEN
    SELECT id_alumno INTO v_alumno FROM matriculas
    WHERE id_matricula=NEW.id_matricula;
    -- Quitamos la aportacion anterior y sumamos la nueva.
    UPDATE lab13b_resumen
    SET evaluadas=evaluadas-(OLD.nota IS NOT NULL)
                           +(NEW.nota IS NOT NULL),
        aprobadas=aprobadas-IFNULL(OLD.nota>=5,0)
                           +IFNULL(NEW.nota>=5,0),
        suma=suma-IFNULL(OLD.nota,0)+IFNULL(NEW.nota,0)
    WHERE id_alumno=v_alumno;
  END IF;
END//
DELIMITER ;

-- B22 -----------------------------------------------------------
UPDATE notas SET nota=8.00,fecha_evaluacion=CURDATE()
WHERE id_matricula=@ma2;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B23 -----------------------------------------------------------
UPDATE notas SET nota=NULL,fecha_evaluacion=NULL
WHERE id_matricula=@ma2;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
-- Recuperamos A2 para las pruebas posteriores.
UPDATE notas SET nota=8.00,fecha_evaluacion=CURDATE()
WHERE id_matricula=@ma2;

-- B24 -----------------------------------------------------------
UPDATE notas SET nota=nota,
  observaciones='Comentario actualizado'
WHERE id_matricula=@ma2;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B25 -----------------------------------------------------------
-- ERROR ESPERADO 1644. Ejecutar por separado.
UPDATE notas SET nota=-1 WHERE id_matricula=@ma1;

-- B26 -----------------------------------------------------------
-- ERROR ESPERADO 1644, antes de comprobar UNIQUE.
UPDATE notas SET id_matricula=@mb1 WHERE id_matricula=@ma1;

-- B27 -----------------------------------------------------------
DELIMITER //
CREATE TRIGGER tr13b_notas_ad
AFTER DELETE ON notas
FOR EACH ROW
BEGIN
  DECLARE v_alumno INT UNSIGNED;
  SELECT id_alumno INTO v_alumno FROM matriculas
  WHERE id_matricula=OLD.id_matricula;
  -- En DELETE solo existe la aportacion anterior.
  UPDATE lab13b_resumen
  SET registradas=registradas-1,
      evaluadas=evaluadas-(OLD.nota IS NOT NULL),
      aprobadas=aprobadas-IFNULL(OLD.nota>=5,0),
      suma=suma-IFNULL(OLD.nota,0)
  WHERE id_alumno=v_alumno;
END//
DELIMITER ;

-- B28 -----------------------------------------------------------
START TRANSACTION;
DELETE FROM notas WHERE id_matricula=@ma2;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
SELECT COUNT(*) AS fila_a2 FROM notas WHERE id_matricula=@ma2;
ROLLBACK;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B29 -----------------------------------------------------------
-- Comparamos el resumen guardado con el calculo real.
SELECT r.id_alumno,r.registradas,r.evaluadas,
       r.aprobadas,r.suma,
       COUNT(n.id_nota) AS real_registradas,
       COUNT(n.nota) AS real_evaluadas,
       SUM(IFNULL(n.nota>=5,0)) AS real_aprobadas,
       IFNULL(SUM(n.nota),0) AS real_suma
FROM lab13b_resumen r
JOIN matriculas m ON m.id_alumno=r.id_alumno
LEFT JOIN notas n ON n.id_matricula=m.id_matricula
GROUP BY r.id_alumno,r.registradas,r.evaluadas,
         r.aprobadas,r.suma
ORDER BY r.id_alumno;

-- B30 -----------------------------------------------------------
START TRANSACTION;
-- Los dos valores nuevos son validos.
UPDATE notas SET nota=nota+1
WHERE id_matricula IN (@ma1,@ma2);
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
ROLLBACK;

-- B31 -----------------------------------------------------------
-- ERROR ESPERADO 1644. Una fila propone 11.
UPDATE notas
SET nota=CASE WHEN id_matricula=@ma1 THEN 7.00 ELSE 11.00 END
WHERE id_matricula IN (@ma1,@ma2);

-- B32 -----------------------------------------------------------
SELECT id_matricula,nota FROM notas
WHERE id_matricula IN (@ma1,@ma2) ORDER BY id_matricula;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B33 -----------------------------------------------------------
START TRANSACTION;
UPDATE notas SET nota=9.00 WHERE id_matricula=@ma1;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
ROLLBACK;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B34 -----------------------------------------------------------
START TRANSACTION;
UPDATE notas SET nota=7.00 WHERE id_matricula=@ma1;
COMMIT;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
-- Dejamos otra vez el estado de referencia A1=6.
UPDATE notas SET nota=6.00 WHERE id_matricula=@ma1;

-- B35 -----------------------------------------------------------
START TRANSACTION;
UPDATE notas SET observaciones='Cambio previo pendiente'
WHERE id_matricula=@ma1;

-- B36 -----------------------------------------------------------
-- ERROR ESPERADO 1644; falla esta sentencia.
UPDATE notas SET nota=12.00 WHERE id_matricula=@ma2;

-- B37 -----------------------------------------------------------
SELECT nota,observaciones FROM notas
WHERE id_matricula=@ma1;
-- Revertimos tambien el cambio anterior de observaciones.
ROLLBACK;
SELECT nota,observaciones FROM notas
WHERE id_matricula=@ma1;

-- B38 -----------------------------------------------------------
START TRANSACTION;
-- Averia simulada en una cifra derivada, solo dentro de la prueba.
UPDATE lab13b_resumen SET suma=0 WHERE id_alumno=@a;

-- B39 -----------------------------------------------------------
-- ERROR ESPERADO 3819 en ck13b_resumen.
-- El AFTER intentaria dejar la suma en -8.
DELETE FROM notas WHERE id_matricula=@ma2;

-- B40 -----------------------------------------------------------
SELECT nota FROM notas WHERE id_matricula=@ma2;
SELECT suma FROM lab13b_resumen WHERE id_alumno=@a;
-- Se revierte ademas la averia de la sentencia anterior.
ROLLBACK;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B41 -----------------------------------------------------------
DELIMITER //
CREATE PROCEDURE sp13b_evaluar_pareja(
  IN p_m1 INT UNSIGNED, IN p_n1 DECIMAL(4,2),
  IN p_m2 INT UNSIGNED, IN p_n2 DECIMAL(4,2))
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
  DECLARE v_encontradas INT;
  -- Ante cualquier error deshacemos TODA esta operacion.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  IF p_m1 IS NULL OR p_m2 IS NULL OR p_m1=p_m2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='Indicar dos matriculas distintas';
  END IF;
  START TRANSACTION;
  -- Solo se admite trabajar con notas de nuestros A y B.
  SELECT COUNT(*) INTO v_encontradas
  FROM notas n JOIN matriculas m USING(id_matricula)
  JOIN lab13b_resumen r USING(id_alumno)
  WHERE n.id_matricula IN (p_m1,p_m2);
  IF v_encontradas<>2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='Faltan notas del laboratorio';
  END IF;
  UPDATE notas SET nota=p_n1,fecha_evaluacion=CURDATE()
  WHERE id_matricula=p_m1;
  UPDATE notas SET nota=p_n2,fecha_evaluacion=CURDATE()
  WHERE id_matricula=p_m2;
  COMMIT;
END//
DELIMITER ;

-- B42 -----------------------------------------------------------
-- Llamar sin otra transaccion abierta.
CALL sp13b_evaluar_pareja(@ma1,7.00,@ma2,9.00);
SELECT id_matricula,nota FROM notas
WHERE id_matricula IN (@ma1,@ma2) ORDER BY id_matricula;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;

-- B43 -----------------------------------------------------------
-- ERROR ESPERADO 1644 en la segunda actualizacion.
CALL sp13b_evaluar_pareja(@ma1,10.00,@ma2,11.00);

-- B44 -----------------------------------------------------------
SELECT id_matricula,nota FROM notas
WHERE id_matricula IN (@ma1,@ma2) ORDER BY id_matricula;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
-- Recuperamos el estado de referencia de esta practica.
CALL sp13b_evaluar_pareja(@ma1,6.00,@ma2,8.00);

-- B45 -----------------------------------------------------------
-- Solo en la conexion A de la ampliacion opcional.
START TRANSACTION;
UPDATE notas SET nota=9.00 WHERE id_matricula=@ma1;
SELECT * FROM lab13b_resumen WHERE id_alumno=@a;
-- No confirmar todavia; pasar a la conexion B.

-- B46 -----------------------------------------------------------
-- Solo en una conexion B nueva con autocommit=1.
USE academia_it;
SELECT a.email,r.registradas,r.evaluadas,r.aprobadas,r.suma
FROM lab13b_resumen r JOIN alumnos a USING(id_alumno)
WHERE a.email='lab13b.a@example.com';

-- B47 -----------------------------------------------------------
-- De nuevo en A.
ROLLBACK;

-- B48 -----------------------------------------------------------
SELECT TRIGGER_NAME,EVENT_OBJECT_TABLE,
       ACTION_TIMING,EVENT_MANIPULATION,ACTION_ORDER
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='academia_it'
  AND LEFT(TRIGGER_NAME,6)='tr13b_'
ORDER BY EVENT_OBJECT_TABLE,ACTION_TIMING,EVENT_MANIPULATION;
SHOW CREATE TRIGGER academia_it.tr13b_notas_au;
