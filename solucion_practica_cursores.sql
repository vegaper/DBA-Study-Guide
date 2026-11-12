-- SOLUCIÓN DE LA PRÁCTICA DE PROCEDIMIENTOS Y CURSORES
-- MySQL 8.4.x. Archivo UTF-8.
-- La base practica_procedimientos NO debe existir al empezar.
-- Si ya hicisteis el ejercicio, no ejecutéis de nuevo la creación
-- sobre sus tablas. El Word explica cómo repetir solo las pruebas.
-- El archivo completo ejecuta las pruebas válidas y termina con
-- 13 notas y la media de Carla en 9.00.
-- Los intentos que deben fallar están comentados: quitad el primer
-- prefijo -- de sus líneas y ejecutad cada intento por separado.
-- Usad una sesión de laboratorio sin una transacción pendiente.
-- DELIMITER requiere un cliente compatible, como mysql o Workbench.


-- BLOQUE DB

-- Crea una base nueva con caracteres Unicode completos.
CREATE DATABASE practica_procedimientos
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

-- Selecciona la base sobre la que vamos a trabajar.
USE practica_procedimientos;

-- BLOQUE CURSOS

CREATE TABLE Cursos (
    -- Identificador generado al añadir un curso.
    id_curso INT NOT NULL AUTO_INCREMENT,
    -- El nombre es obligatorio y no puede repetirse.
    nombre VARCHAR(60) NOT NULL,
    PRIMARY KEY (id_curso),
    CONSTRAINT uq_cursos_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- BLOQUE ALUMNOS

CREATE TABLE Alumnos (
    id_alumno INT NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(40) NOT NULL,
    apellidos VARCHAR(80) NOT NULL,
    id_curso INT NOT NULL,
    -- No hay una media calculada al crear el alumno.
    media_calculada DECIMAL(4,2) NULL DEFAULT NULL,
    PRIMARY KEY (id_alumno),
    -- Cada alumno debe pertenecer a un curso existente.
    CONSTRAINT fk_alumnos_cursos
        FOREIGN KEY (id_curso) REFERENCES Cursos (id_curso)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    -- Acepta NULL o una media dentro del intervalo.
    CONSTRAINT ck_alumnos_media
        CHECK (media_calculada BETWEEN 0 AND 10)
) ENGINE = InnoDB;

-- BLOQUE ASIGNATURAS

CREATE TABLE Asignaturas (
    id_asignatura INT NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(80) NOT NULL,
    PRIMARY KEY (id_asignatura),
    CONSTRAINT uq_asignaturas_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- BLOQUE NOTAS

CREATE TABLE Notas (
    id_nota INT NOT NULL AUTO_INCREMENT,
    id_alumno INT NOT NULL,
    id_asignatura INT NOT NULL,
    -- NULL indica una calificación pendiente.
    calificacion DECIMAL(4,2) NULL DEFAULT NULL,
    PRIMARY KEY (id_nota),
    -- La pareja no se puede repetir, incluso con NULL.
    CONSTRAINT uq_notas_alumno_asignatura
        UNIQUE (id_alumno, id_asignatura),
    CONSTRAINT fk_notas_alumnos
        FOREIGN KEY (id_alumno)
        REFERENCES Alumnos (id_alumno)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_notas_asignaturas
        FOREIGN KEY (id_asignatura)
        REFERENCES Asignaturas (id_asignatura)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT ck_notas_calificacion
        CHECK (calificacion BETWEEN 0 AND 10)
) ENGINE = InnoDB;

-- BLOQUE LOAD_CURSOS

-- Fijamos los mismos identificadores que en el enunciado.
INSERT INTO Cursos (id_curso, nombre) VALUES
    (1, 'Grupo de mañana'),
    (2, 'Grupo de tarde'),
    (3, 'Grupo de fin de semana');

-- BLOQUE LOAD_ASIGNATURAS

INSERT INTO Asignaturas (id_asignatura, nombre) VALUES
    (1, 'SQL'),
    (2, 'Administración de sistemas'),
    (3, 'Seguridad de bases de datos');

-- BLOQUE LOAD_ALUMNOS

-- Omitimos media_calculada para que se aplique su defecto.
INSERT INTO Alumnos
    (id_alumno, nombre, apellidos, id_curso)
VALUES
    (1, 'Ana',   'López Martín',  1),
    (2, 'Bruno', 'Sánchez Gil',   1),
    (3, 'Carla', 'Ruiz Pérez',    1),
    (4, 'Diego', 'García Soto',   2),
    (5, 'Elena', 'Díaz Torres',   2),
    (6, 'Farah', 'Moreno León',   2);

-- BLOQUE LOAD_NOTAS

INSERT INTO Notas
    (id_nota, id_alumno, id_asignatura, calificacion)
VALUES
    (1,  1, 1, 8.00),
    (2,  1, 2, 6.00),
    (3,  1, 3, 7.50),
    (4,  2, 1, 4.00),
    (5,  2, 2, 6.00),
    (6,  2, 3, NULL),
    (7,  4, 1, 9.00),
    (8,  4, 2, 8.00),
    (9,  4, 3, 7.00),
    (10, 5, 1, 0.00),
    (11, 5, 2, 5.00),
    (12, 5, 3, NULL);

-- BLOQUE COUNTS

-- Cada consulta cuenta todas las filas de su tabla.
SELECT 'Cursos' AS tabla, COUNT(*) AS filas FROM Cursos
UNION ALL
SELECT 'Alumnos', COUNT(*) FROM Alumnos
UNION ALL
SELECT 'Asignaturas', COUNT(*) FROM Asignaturas
UNION ALL
SELECT 'Notas', COUNT(*) FROM Notas;

-- BLOQUE NULLS

-- Cuenta las notas pendientes, sin confundirlas con ceros.
SELECT COUNT(*) AS notas_pendientes
FROM Notas
WHERE calificacion IS NULL;

-- Cuenta las notas numéricas de valor cero.
SELECT COUNT(*) AS notas_cero
FROM Notas
WHERE calificacion = 0;

-- Al cargar los datos, las seis medias deben ser NULL.
SELECT COUNT(*) AS medias_sin_calcular
FROM Alumnos
WHERE media_calculada IS NULL;

-- BLOQUE ORPHANS

-- Las claves foráneas también impiden estos registros.
SELECT COUNT(*) AS referencias_invalidas
FROM Notas AS n
LEFT JOIN Alumnos AS a ON a.id_alumno = n.id_alumno
LEFT JOIN Asignaturas AS s
    ON s.id_asignatura = n.id_asignatura
WHERE a.id_alumno IS NULL OR s.id_asignatura IS NULL;

-- BLOQUE REGISTRAR

-- El cliente enviará la definición completa hasta //.
DELIMITER //

CREATE PROCEDURE registrar_nota(
    IN p_id_alumno INT,
    IN p_id_asignatura INT,
    IN p_calificacion DECIMAL(4,2)
)
BEGIN
    -- IS NULL comprueba la ausencia de identificador.
    IF p_id_alumno IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno no puede ser NULL';
    END IF;

    IF p_id_asignatura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La asignatura no puede ser NULL';
    END IF;

    -- La tabla admite pendientes; este procedimiento no.
    IF p_calificacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La calificacion no puede ser NULL';
    END IF;

    -- Los extremos 0 y 10 sí están permitidos.
    IF p_calificacion < 0 OR p_calificacion > 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La nota debe estar entre 0 y 10';
    END IF;

    -- NOT EXISTS es verdadero si no se encuentra la fila.
    IF NOT EXISTS (
        SELECT 1 FROM Alumnos
        WHERE id_alumno = p_id_alumno
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Asignaturas
        WHERE id_asignatura = p_id_asignatura
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La asignatura no existe';
    END IF;

    -- También rechaza una combinación con nota pendiente.
    IF EXISTS (
        SELECT 1 FROM Notas
        WHERE id_alumno = p_id_alumno
          AND id_asignatura = p_id_asignatura
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno ya tiene esa asignatura';
    END IF;

    -- Solo se escribe después de superar las validaciones.
    -- id_nota se genera; la media guardada no se modifica.
    INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
    VALUES (p_id_alumno, p_id_asignatura, p_calificacion);
END//

-- Recupera el separador habitual del cliente.
DELIMITER ;

CREATE PROCEDURE registrar_nota_null(
    IN p_id_alumno INT,
    IN p_id_asignatura INT,
    IN p_calificacion DECIMAL(4,2)
)
BEGIN
    -- IS NULL comprueba la ausencia de identificador.
    IF p_id_alumno IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno no puede ser NULL';
    END IF;

    IF p_id_asignatura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La asignatura no puede ser NULL';
    END IF;

    -- La tabla admite pendientes; este procedimiento no.
    IF p_calificacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La calificacion no puede ser NULL';
    END IF;

    -- Los extremos 0 y 10 sí están permitidos.
    IF p_calificacion < 0 OR p_calificacion > 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La nota debe estar entre 0 y 10';
    END IF;

    -- NOT EXISTS es verdadero si no se encuentra la fila.
    IF NOT EXISTS (
        SELECT 1 FROM Alumnos
        WHERE id_alumno = p_id_alumno
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Asignaturas
        WHERE id_asignatura = p_id_asignatura
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La asignatura no existe';
    END IF;

    -- Permitimos actualizar una nota NULL
    IF EXISTS (
    SELECT 1 FROM Notas
    WHERE id_alumno = p_id_alumno
      AND id_asignatura = p_id_asignatura
      AND calificacion IS NULL
    ) THEN

    -- Existe una nota pendiente: actualizar
    UPDATE Notas
    SET calificacion = p_calificacion
    WHERE id_alumno = p_id_alumno
      AND id_asignatura = p_id_asignatura
      AND calificacion IS NULL;

    ELSEIF EXISTS (
    SELECT 1 FROM Notas
    WHERE id_alumno = p_id_alumno
      AND id_asignatura = p_id_asignatura
    ) THEN

    -- Ya existe una calificación
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El alumno ya tiene una nota registrada';

    ELSE

    -- No existe el registro: insertar
    INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
    VALUES (p_id_alumno, p_id_asignatura, p_calificacion);
    END IF;
END//

-- Recupera el separador habitual del cliente.
DELIMITER ;

-- BLOQUE CURSOR

DELIMITER //

CREATE PROCEDURE recalcular_medias_curso(
    IN p_id_curso INT,
    OUT p_total_procesados INT
)
BEGIN
    -- Primero se declaran las variables locales.
    DECLARE v_fin BOOLEAN DEFAULT FALSE;
    DECLARE v_id_alumno INT;
    DECLARE v_media DECIMAL(4,2);

    -- Después se declara el cursor que recorrerá alumnos.
    DECLARE cur_alumnos CURSOR FOR
        SELECT id_alumno
        FROM Alumnos
        WHERE id_curso = p_id_curso
        ORDER BY id_alumno;

    -- Por último se declara el manejador del fin de datos.
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_fin = TRUE;

    -- El contador empieza desde cero en cada ejecución.
    SET p_total_procesados = 0;

    IF p_id_curso IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El curso no puede ser NULL';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Cursos WHERE id_curso = p_id_curso
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El curso no existe';
    END IF;

    -- La validación termina antes de abrir el recorrido.
    OPEN cur_alumnos;

    recorrer: LOOP
        -- Obtiene el siguiente identificador del cursor.
        FETCH cur_alumnos INTO v_id_alumno;

        -- Si FETCH no obtuvo una fila, no se procesa nada.
        IF v_fin THEN
            LEAVE recorrer;
        END IF;

        -- Sin GROUP BY, la agregación devuelve una fila.
        -- AVG ignora NULL e incluye el cero.
        SELECT ROUND(AVG(calificacion), 2)
        INTO v_media
        FROM Notas
        WHERE id_alumno = v_id_alumno;

        -- Si no hay notas numéricas, v_media contiene NULL.
        UPDATE Alumnos
        SET media_calculada = v_media
        WHERE id_alumno = v_id_alumno;

        -- Cuenta alumnos recorridos, no filas cambiadas.
        SET p_total_procesados = p_total_procesados + 1;
    END LOOP recorrer;

    -- Ya no necesitamos mantener abierto el cursor.
    CLOSE cur_alumnos;

    SELECT p_total_precesados AS Total_procesados;

END//

DELIMITER ;

-- BLOQUE INITIAL_CALLS

-- @total es una variable de la sesión que recibe el OUT.
CALL recalcular_medias_curso(1, @total);
SELECT @total AS alumnos_procesados; -- Esperado: 3.

CALL recalcular_medias_curso(2, @total);
SELECT @total AS alumnos_procesados; -- Esperado: 3.

-- Muestra las seis medias después de ambos cálculos.
SELECT id_alumno, nombre, id_curso, media_calculada
FROM Alumnos
ORDER BY id_alumno;

-- PRUEBAS DE ERROR ANTES DEL ALTA VÁLIDA
-- Deben conservar las 12 notas iniciales si se prueban aquí.

-- Alumno inexistente
-- Resultado: El alumno no existe
-- CALL registrar_nota(999, 1, 7.00);

-- Asignatura inexistente
-- Resultado: La asignatura no existe
-- CALL registrar_nota(3, 999, 7.00);

-- Nota superior al máximo
-- Resultado: La nota debe estar entre 0 y 10
-- CALL registrar_nota(3, 1, 11.00);

-- Nota negativa
-- Resultado: La nota debe estar entre 0 y 10
-- CALL registrar_nota(3, 1, -1.00);

-- Nota nula
-- Resultado: La calificacion no puede ser NULL
-- CALL registrar_nota(3, 1, NULL);

-- Pareja ya registrada
-- Resultado: El alumno ya tiene esa asignatura
-- CALL registrar_nota(1, 1, 8.00);

-- Identificador de alumno nulo
-- Resultado: El alumno no puede ser NULL
-- CALL registrar_nota(NULL, 1, 7.00);

-- Identificador de asignatura nulo
-- Resultado: La asignatura no puede ser NULL
-- CALL registrar_nota(3, NULL, 7.00);

-- Pareja que ya tiene una nota pendiente
-- Resultado: El alumno ya tiene esa asignatura
-- CALL registrar_nota(2, 3, 7.00);

-- BLOQUE CARLA_BEFORE

-- Antes del alta: Carla aún no tiene notas.
SELECT id_alumno, id_asignatura, calificacion
FROM Notas
WHERE id_alumno = 3;

-- Registra la única operación válida de alta de la prueba.
CALL registrar_nota(3, 1, 9.00);

-- Aparece una fila con SQL y 9.00, pero la media sigue NULL.
SELECT id_alumno, id_asignatura, calificacion
FROM Notas
WHERE id_alumno = 3;

SELECT id_alumno, nombre, media_calculada
FROM Alumnos
WHERE id_alumno = 3;

-- BLOQUE CARLA_AFTER

-- El nuevo cálculo incorpora la nota recién registrada.
CALL recalcular_medias_curso(1, @total);
SELECT @total AS alumnos_procesados; -- Esperado: 3.

SELECT id_alumno, nombre, id_curso, media_calculada
FROM Alumnos
ORDER BY id_alumno;

SELECT COUNT(*) AS total_notas FROM Notas; -- Esperado: 13.

-- BLOQUE CURSOR_SUCCESS

-- El curso existe, pero está vacío: devuelve cero.
CALL recalcular_medias_curso(3, @total);
SELECT @total AS alumnos_procesados; -- Esperado: 0.

-- Repetir el cálculo no cambia el significado del contador.
CALL recalcular_medias_curso(1, @total);
SELECT @total AS alumnos_procesados; -- Esperado: 3.

-- RESTO DE PRUEBAS DE ERROR
-- En este punto Notas contiene 13 filas.

-- Curso inexistente
-- Resultado: El curso no existe
-- CALL recalcular_medias_curso(999, @total);

-- Curso nulo
-- Resultado: El curso no puede ser NULL
-- CALL recalcular_medias_curso(NULL, @total);

-- Repetición del alta válida de Carla
-- Resultado: El alumno ya tiene esa asignatura
-- CALL registrar_nota(3, 1, 9.00);

-- Calificación fuera del intervalo
-- Resultado: CHECK · ck_notas_calificacion
-- INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
-- VALUES (6, 1, 11.00);

-- Media fuera del intervalo
-- Resultado: CHECK · ck_alumnos_media
-- UPDATE Alumnos SET media_calculada = 11.00
-- WHERE id_alumno = 6;

-- Alumno inexistente
-- Resultado: FK · fk_notas_alumnos
-- INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
-- VALUES (999, 1, 7.00);

-- Asignatura inexistente
-- Resultado: FK · fk_notas_asignaturas
-- INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
-- VALUES (6, 999, 7.00);

-- Nota duplicada
-- Resultado: UNIQUE · uq_notas_alumno_asignatura
-- INSERT INTO Notas (id_alumno, id_asignatura, calificacion)
-- VALUES (1, 1, 8.00);

-- Nombre de curso duplicado
-- Resultado: UNIQUE · uq_cursos_nombre
-- INSERT INTO Cursos (nombre) VALUES ('Grupo de mañana');

-- Nombre de asignatura duplicado
-- Resultado: UNIQUE · uq_asignaturas_nombre
-- INSERT INTO Asignaturas (nombre) VALUES ('SQL');

-- Curso con alumnos
-- Resultado: FK · fk_alumnos_cursos
-- DELETE FROM Cursos WHERE id_curso = 1;

-- Alumno con notas
-- Resultado: FK · fk_notas_alumnos
-- DELETE FROM Alumnos WHERE id_alumno = 1;

-- Cambio de clave de un curso referenciado
-- Resultado: FK · fk_alumnos_cursos
-- UPDATE Cursos SET id_curso = 99 WHERE id_curso = 1;

-- Nombre obligatorio nulo
-- Resultado: NOT NULL · Cursos.nombre
-- INSERT INTO Cursos (nombre) VALUES (NULL);

-- Deben mantenerse las 13 notas tras las pruebas fallidas.
SELECT COUNT(*) AS total_notas FROM Notas;

SELECT id_alumno, nombre, id_curso, media_calculada
FROM Alumnos
ORDER BY id_alumno;

-- RESTAURACIÓN OPCIONAL DEL LABORATORIO
-- No se ejecuta al lanzar el archivo completo.
-- -- Solo para repetir las pruebas en este laboratorio.
-- -- Elimina el alta de prueba de Carla, no las notas iniciales.
-- DELETE FROM Notas
-- WHERE id_alumno = 3 AND id_asignatura = 1;
-- 
-- -- Restablece el estado de las medias antes de calcularlas.
-- UPDATE Alumnos SET media_calculada = NULL;
-- 
-- SELECT COUNT(*) AS total_notas FROM Notas; -- Esperado: 12.
