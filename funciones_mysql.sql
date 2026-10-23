-- FUNCIONES Y OPERADORES DE MySQL: PREPARACIÓN DEL LABORATORIO
-- Archivo: funciones_mysql.sql
-- Codificación del archivo: UTF-8.
--
-- Contiene las tablas y los datos de la versión revisada del documento:
-- Funciones_y_operadores_MySQL_academia_it.docx
--
-- Ejecución: abrir el archivo en MySQL Workbench y ejecutar el script completo,
-- o utilizar SOURCE funciones_mysql.sql; desde el cliente mysql si el archivo
-- se encuentra en el directorio actual del cliente.
-- Se necesitan permisos para crear bases de datos y tablas e insertar datos.
-- Ejecutar en una conexión de prácticas sin una transacción previa abierta.
-- La creación está prevista para una base nueva llamada funciones_mysql.
-- Si ese nombre ya existe, CREATE DATABASE producirá un error: debe revisarse
-- la base existente antes de volver a ejecutar la preparación.
--
-- Correspondencia con el Word:
--   laboratorio_funciones (nombre del Word) = funciones_mysql (este archivo).
-- Para las consultas posteriores, utilizar USE funciones_mysql;
-- y sustituir laboratorio_funciones por funciones_mysql cuando se mencione
-- expresamente el nombre de la base, por ejemplo en INFORMATION_SCHEMA.
-- El nombre utilizado por GET_LOCK es un identificador de coordinación:
-- puede conservarse aunque cambie el nombre de la base de datos.

-- 1. CONEXIÓN Y BASE DE DATOS

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE DATABASE funciones_mysql
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE funciones_mysql;

-- 2. CINCO TABLAS PERMANENTES
-- Cada tabla representa un caso autónomo, igual que en el documento.
-- Se conservan los nombres de columnas, tipos y restricciones del anexo.

CREATE TABLE personas (
    id INT NOT NULL PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL,
    apellido1 VARCHAR(30) NOT NULL,
    apellido2 VARCHAR(30) NULL,
    telefono VARCHAR(20) NULL,
    email VARCHAR(80) NULL,
    activo TINYINT NOT NULL,
    fecha_nacimiento DATE NULL,
    CHECK (activo IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE calificaciones (
    id INT NOT NULL PRIMARY KEY,
    alumno VARCHAR(30) NOT NULL,
    grupo CHAR(1) NOT NULL,
    nota DECIMAL(4,2) NULL,
    CHECK (nota IS NULL OR nota BETWEEN 0 AND 10)
) ENGINE = InnoDB;

CREATE TABLE pedidos (
    id INT NOT NULL PRIMARY KEY,
    producto VARCHAR(40) NOT NULL,
    unidades INT NOT NULL,
    precio DECIMAL(8,2) NOT NULL,
    descuento_pct DECIMAL(5,2) NOT NULL,
    fecha DATE NOT NULL,
    CHECK (unidades > 0),
    CHECK (precio >= 0),
    CHECK (descuento_pct BETWEEN 0 AND 100)
) ENGINE = InnoDB;

CREATE TABLE cursos (
    id INT NOT NULL PRIMARY KEY,
    nombre VARCHAR(40) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CHECK (fecha_fin >= fecha_inicio)
) ENGINE = InnoDB;

CREATE TABLE documentos (
    id INT NOT NULL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    contenido TEXT NOT NULL,
    FULLTEXT INDEX ft_documentos (titulo, contenido)
) ENGINE = InnoDB;

-- 3. DATOS INICIALES
-- Las tablas se crean antes de iniciar la transacción de carga.

START TRANSACTION;

-- Contactos: Ana tiene un teléfono válido; Luis y Sara, NULL;
-- Marta, texto vacío; Pablo, tres espacios; Elena, espacios exteriores.
-- No deben eliminarse esos espacios al cargar los datos.
INSERT INTO personas
    (id, nombre, apellido1, apellido2, telefono, email, activo, fecha_nacimiento)
VALUES
    (1, 'Ana', 'García', 'López', '600111222', 'ana@centro.es', 1, '2000-06-15'),
    (2, 'Luis', 'López', NULL, NULL, 'luis@centro.es', 0, '1998-11-20'),
    (3, 'Marta', 'López', 'Díaz', '', 'marta@centro.es', 1, '2005-10-18'),
    (4, 'Pablo', 'Soto', NULL, '   ', NULL, 1, '2000-10-19'),
    (5, 'Elena', 'García', 'Gil', ' 611333444 ', ' ELENA@CENTRO.ES ', 0, '1995-01-10'),
    (6, 'Sara', 'Ruiz', NULL, NULL, NULL, 1, NULL);

-- Pablo obtuvo un cero real. Marta, Sara y Diego tienen nota pendiente.
-- NULL representa una nota desconocida; no es una nota igual a cero.
INSERT INTO calificaciones
    (id, alumno, grupo, nota)
VALUES
    (1, 'Ana', 'A', 8),
    (2, 'Luis', 'A', 6),
    (3, 'Marta', 'A', NULL),
    (4, 'Pablo', 'A', 0),
    (5, 'Elena', 'B', 9),
    (6, 'Bruno', 'B', 9),
    (7, 'Sara', 'C', NULL),
    (8, 'Diego', 'C', NULL);

-- precio es unitario; descuento_pct contiene el porcentaje de descuento.
INSERT INTO pedidos
    (id, producto, unidades, precio, descuento_pct, fecha)
VALUES
    (1, 'Cuaderno', 3, 2.85, 0, '2026-10-01'),
    (2, 'Memoria USB', 2, 12.5, 10, '2026-10-15'),
    (3, 'Ratón', 1, 18.95, 5, '2026-10-18');

-- Las fechas fijas permiten reproducir los resultados del documento.
INSERT INTO cursos
    (id, nombre, fecha_inicio, fecha_fin)
VALUES
    (1, 'Redes', '2026-10-01', '2026-10-10'),
    (2, 'SQL', '2026-10-15', '2026-10-20'),
    (3, 'Linux', '2026-11-01', '2026-11-05');

-- El índice FULLTEXT abarca las columnas titulo y contenido.
INSERT INTO documentos
    (id, titulo, contenido)
VALUES
    (1, 'Seguridad en redes', 'Seguridad básica de redes y equipos'),
    (2, 'Seguridad en Linux', 'Seguridad y permisos en Linux'),
    (3, 'Administración de MySQL', 'Administración de bases de datos MySQL'),
    (4, 'Copias de seguridad', 'Copias y restauración de bases de datos'),
    (5, 'Hojas de cálculo', 'Fórmulas y gráficos con hojas de cálculo');

COMMIT;
-- El COMMIT confirma la carga y permite consultar los documentos mediante
-- el índice FULLTEXT.

-- 4. COMPROBACIÓN DE LOS REGISTROS
-- Resultado esperado:
-- personas: 6; calificaciones: 8; pedidos: 3; cursos: 3; documentos: 5.

SELECT 'personas' AS tabla, COUNT(*) AS filas FROM personas
UNION ALL
SELECT 'calificaciones', COUNT(*) FROM calificaciones
UNION ALL
SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL
SELECT 'cursos', COUNT(*) FROM cursos
UNION ALL
SELECT 'documentos', COUNT(*) FROM documentos;

-- Comprobación de las notas utilizadas en los ejemplos:
-- filas = 8; notas_conocidas = 5; suma_notas = 32.00;
-- media_conocidas = 6.40; media_pendientes_como_cero = 4.00.

SELECT COUNT(*) AS filas,
       COUNT(nota) AS notas_conocidas,
       SUM(nota) AS suma_notas,
       ROUND(AVG(nota), 2) AS media_conocidas,
       ROUND(AVG(COALESCE(nota, 0)), 2) AS media_pendientes_como_cero
FROM calificaciones;

-- 5. TABLA TEMPORAL DEL EJEMPLO DE LAST_INSERT_ID Y ROW_COUNT
-- Esta tabla se crea, se utiliza y se elimina en la misma conexión.
-- No es una sexta tabla permanente del laboratorio.
-- El Word incluye de nuevo su preparación para poder repetir el ejemplo.

CREATE TEMPORARY TABLE registro_funciones_demo (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    mensaje VARCHAR(40) NOT NULL
);

INSERT INTO registro_funciones_demo (mensaje) VALUES ('Prueba');

-- Resultado esperado: filas_insertadas = 1; identificador_generado = 1.
-- No intercalar otra sentencia entre el INSERT y este SELECT.
SELECT ROW_COUNT() AS filas_insertadas,
       LAST_INSERT_ID() AS identificador_generado;

-- Resultado esperado: -1, porque la sentencia anterior es un SELECT.
SELECT ROW_COUNT() AS resultado_despues_del_select;

DROP TEMPORARY TABLE registro_funciones_demo;

-- La base activa al finalizar continúa siendo funciones_mysql.
-- Las cinco tablas permanentes quedan cargadas para practicar las consultas.
