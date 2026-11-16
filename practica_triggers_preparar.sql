-- 13b Practica guiada de triggers. MySQL 8.4.x, UTF-8.
-- Ejecutar UNA VEZ en una conexion nueva con autocommit=1.
-- Detenerse ante el primer error. No usar --force.
-- No recrea academia_it ni sus siete tablas originales.
USE academia_it;
SET NAMES utf8mb4;

DELIMITER //
CREATE PROCEDURE sp13b_preparar()
SQL SECURITY INVOKER
BEGIN
  DECLARE v_ca1, v_ca2 INT UNSIGNED;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  IF VERSION() NOT LIKE '8.4.%' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Se requiere MySQL 8.4.x';
  END IF;
  
  IF @@SESSION.autocommit <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Abrir conexion nueva con autocommit=1';
  END IF;
  
  IF (SELECT COUNT(*) FROM information_schema.TABLES
      WHERE TABLE_SCHEMA=DATABASE() AND ENGINE='InnoDB'
      AND TABLE_NAME IN ('alumnos','matriculas','notas','curso_asignatura')) <> 4 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Revisar nombres de tablas y motor InnoDB';
  END IF;
  
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA=DATABASE() AND
       ((TABLE_NAME='alumnos' AND COLUMN_NAME IN
          ('id_alumno','nombre','apellido1','email','fecha_alta','activo'))
       OR (TABLE_NAME='matriculas' AND COLUMN_NAME IN
          ('id_matricula','id_alumno','id_curso_asignatura','fecha_matricula','estado'))
       OR (TABLE_NAME='notas' AND COLUMN_NAME IN
          ('id_nota','id_matricula','nota','fecha_evaluacion','observaciones'))
       OR (TABLE_NAME='curso_asignatura' AND COLUMN_NAME='id_curso_asignatura'))) <> 17 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El esquema no coincide con el documentado';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.TRIGGERS
      WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE IN ('alumnos','notas')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Revisar triggers previos antes de preparar';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
      WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='lab13b_resumen') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ya existe lab13b_resumen; revisar ejecucion anterior';
  END IF;
  
  IF EXISTS (SELECT 1 FROM alumnos WHERE email IN
      ('lab13b.a@example.com','lab13b.b@example.com','lab13b.c@example.com')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ya existen correos reservados del laboratorio';
  END IF;
  
  SELECT MIN(id_curso_asignatura) INTO v_ca1 FROM curso_asignatura;
  SELECT MIN(id_curso_asignatura) INTO v_ca2 FROM curso_asignatura
    WHERE id_curso_asignatura>v_ca1;
  
  IF v_ca2 IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Se necesitan dos filas en curso_asignatura';
  END IF;
  
  -- El DDL confirma implicitamente. Esta tabla se crea antes de los datos.
  CREATE TABLE lab13b_resumen (
    id_alumno INT UNSIGNED PRIMARY KEY,
    registradas INT NOT NULL DEFAULT 0,
    evaluadas INT NOT NULL DEFAULT 0,
    aprobadas INT NOT NULL DEFAULT 0,
    suma DECIMAL(8,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk13b_resumen_alumno FOREIGN KEY (id_alumno)
      REFERENCES alumnos(id_alumno) ON DELETE RESTRICT,
    CONSTRAINT ck13b_resumen CHECK
      (registradas>=0 AND evaluadas>=0 AND aprobadas>=0
       AND aprobadas<=evaluadas AND evaluadas<=registradas AND suma>=0)
  ) ENGINE=InnoDB;
  
  START TRANSACTION;
  -- Guardamos recuentos para contrastar la limpieza en esta misma conexion.
  SET @base13b_alumnos=(SELECT COUNT(*) FROM alumnos);
  SET @base13b_matriculas=(SELECT COUNT(*) FROM matriculas);
  SET @base13b_notas=(SELECT COUNT(*) FROM notas);
  
  INSERT INTO alumnos(nombre,apellido1,email,fecha_alta,activo)
    VALUES('Lab13b A','Triggers13b','lab13b.a@example.com',CURDATE(),1);
  SET @a=LAST_INSERT_ID();
  INSERT INTO alumnos(nombre,apellido1,email,fecha_alta,activo)
    VALUES('Lab13b B','Triggers13b','lab13b.b@example.com',CURDATE(),1);
  SET @b=LAST_INSERT_ID();
  INSERT INTO alumnos(nombre,apellido1,email,fecha_alta,activo)
    VALUES('Lab13b C','Triggers13b','lab13b.c@example.com',CURDATE(),1);
  SET @c=LAST_INSERT_ID();
  INSERT INTO matriculas(id_alumno,id_curso_asignatura,fecha_matricula,estado)
    VALUES(@a,v_ca1,CURDATE(),'matriculado');
  SET @ma1=LAST_INSERT_ID();
  INSERT INTO matriculas(id_alumno,id_curso_asignatura,fecha_matricula,estado)
    VALUES(@a,v_ca2,CURDATE(),'matriculado');
  SET @ma2=LAST_INSERT_ID();
  INSERT INTO matriculas(id_alumno,id_curso_asignatura,fecha_matricula,estado)
    VALUES(@b,v_ca1,CURDATE(),'matriculado');
  SET @mb1=LAST_INSERT_ID();
  INSERT INTO lab13b_resumen(id_alumno) VALUES(@a),(@b);
  
  COMMIT;
  
  SELECT @a AS alumno_a,@b AS alumno_b,@c AS alumno_c,
         @ma1 AS matricula_a1,@ma2 AS matricula_a2,@mb1 AS matricula_b1;
  SELECT 'Preparacion completada; no se han creado triggers' AS resultado;
END//
DELIMITER ;
CALL sp13b_preparar();
-- Se conserva la rutina hasta la limpieza: no es necesario repetir CALL.
