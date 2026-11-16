-- Limpieza opcional AL TERMINAR. Conexion sin transaccion pendiente.
-- Detenerse ante el primer error; no usar --force.
USE academia_it;
SET NAMES utf8mb4;
DELIMITER //
CREATE PROCEDURE sp13b_limpiar()
SQL SECURITY INVOKER
BEGIN
  DECLARE v_a,v_b,v_c INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  -- No se borran filas si no conservan los marcadores esperados.
  SELECT MAX(CASE WHEN email='lab13b.a@example.com' THEN id_alumno END),
         MAX(CASE WHEN email='lab13b.b@example.com' THEN id_alumno END),
         MAX(CASE WHEN email='lab13b.c@example.com' THEN id_alumno END)
  INTO v_a,v_b,v_c FROM alumnos
  WHERE apellido1='Triggers13b' AND nombre IN ('Lab13b A','Lab13b B','Lab13b C');
  IF v_a IS NULL OR v_b IS NULL OR v_c IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan alumnos identificables; revisar sin borrar';
  END IF;
  IF (SELECT COUNT(*) FROM alumnos
      WHERE (id_alumno=v_a AND nombre='Lab13b A')
         OR (id_alumno=v_b AND nombre='Lab13b B')
         OR (id_alumno=v_c AND nombre='Lab13b C'))<>3 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Los marcadores de alumnos no coinciden';
  END IF;
  IF (SELECT COUNT(*) FROM matriculas WHERE id_alumno=v_a)<>2
     OR (SELECT COUNT(*) FROM matriculas WHERE id_alumno=v_b)<>1
     OR EXISTS(SELECT 1 FROM matriculas WHERE id_alumno=v_c) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matriculas distintas de las preparadas; revisar';
  END IF;
  IF (SELECT COUNT(*) FROM lab13b_resumen)<>2
     OR (SELECT COUNT(*) FROM lab13b_resumen WHERE id_alumno IN(v_a,v_b))<>2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El resumen tiene filas inesperadas';
  END IF;
  IF EXISTS(SELECT 1 FROM information_schema.TRIGGERS
      WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE IN('alumnos','notas')
      AND TRIGGER_NAME NOT IN('tr13b_alumnos_bi','tr13b_alumnos_bu','tr13b_alumnos_bd',
        'tr13b_notas_bi','tr13b_notas_bu','tr13b_notas_ai','tr13b_notas_au','tr13b_notas_ad')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Hay triggers ajenos; revisar antes de limpiar';
  END IF;
  START TRANSACTION;
  -- Primero las notas. AFTER DELETE aun puede actualizar el resumen.
  DELETE n FROM notas n JOIN matriculas m USING(id_matricula)
  WHERE m.id_alumno IN(v_a,v_b);
  DELETE FROM matriculas WHERE id_alumno IN(v_a,v_b);
  DELETE FROM lab13b_resumen WHERE id_alumno IN(v_a,v_b);
  -- Permitimos que BEFORE DELETE deje eliminar a los tres alumnos.
  UPDATE alumnos SET activo=0 WHERE id_alumno IN(v_a,v_b,v_c);
  DELETE FROM alumnos WHERE id_alumno IN(v_a,v_b,v_c);
  COMMIT;
  SELECT 'Datos de prueba eliminados; retirar ahora objetos 13b' AS resultado;
END//
DELIMITER ;
CALL sp13b_limpiar();
-- A partir de aqui solo se eliminan nombres propios de esta practica.
DROP TRIGGER IF EXISTS tr13b_alumnos_bi;
DROP TRIGGER IF EXISTS tr13b_alumnos_bu;
DROP TRIGGER IF EXISTS tr13b_alumnos_bd;
DROP TRIGGER IF EXISTS tr13b_notas_bi;
DROP TRIGGER IF EXISTS tr13b_notas_bu;
DROP TRIGGER IF EXISTS tr13b_notas_ai;
DROP TRIGGER IF EXISTS tr13b_notas_au;
DROP TRIGGER IF EXISTS tr13b_notas_ad;
DROP PROCEDURE IF EXISTS sp13b_evaluar_pareja;
DROP TABLE lab13b_resumen;
DROP PROCEDURE sp13b_preparar;
DROP PROCEDURE sp13b_limpiar;
SELECT COUNT(*) AS alumnos_reservados FROM alumnos
WHERE email IN('lab13b.a@example.com','lab13b.b@example.com','lab13b.c@example.com');
-- Si seguimos en la conexion original, deben coincidir estos pares.
SELECT (SELECT COUNT(*) FROM alumnos) AS alumnos_actuales,
       @base13b_alumnos AS alumnos_iniciales,
       (SELECT COUNT(*) FROM matriculas) AS matriculas_actuales,
       @base13b_matriculas AS matriculas_iniciales,
       (SELECT COUNT(*) FROM notas) AS notas_actuales,
       @base13b_notas AS notas_iniciales;
