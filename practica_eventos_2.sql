-- Laboratorio de préstamos de material informático para MySQL 8.4.
-- Ejecutad este fichero una sola vez en una instancia de aula.
-- Si lab_prestamos_tic ya existe, deteneos y comprobad su origen.
-- Guardad y ejecutad el fichero en UTF-8.

CREATE DATABASE lab_prestamos_tic
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE lab_prestamos_tic;

CREATE TABLE equipos (
    id_equipo INT UNSIGNED PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE prestamos (
    id_prestamo INT UNSIGNED PRIMARY KEY,
    id_equipo INT UNSIGNED NOT NULL,
    prestatario VARCHAR(80) NOT NULL,
    vence_utc DATETIME NOT NULL,
    estado ENUM('ABIERTO', 'VENCIDO', 'DEVUELTO') NOT NULL,
    devuelto_utc DATETIME NULL,
    CONSTRAINT fk_prestamos_equipos
        FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo),
    INDEX ix_prestamos_estado_vence (estado, vence_utc)
) ENGINE = InnoDB;

CREATE TABLE historial_prestamos (
    id_cambio BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_prestamo INT UNSIGNED NOT NULL,
    estado_anterior ENUM('ABIERTO', 'VENCIDO', 'DEVUELTO') NOT NULL,
    estado_nuevo ENUM('ABIERTO', 'VENCIDO', 'DEVUELTO') NOT NULL,
    cambiado_utc DATETIME NOT NULL,
    CONSTRAINT fk_historial_prestamos
        FOREIGN KEY (id_prestamo) REFERENCES prestamos(id_prestamo)
) ENGINE = InnoDB;

CREATE TABLE revisiones_prestamos (
    id_revision BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ejecutado_utc DATETIME NOT NULL,
    prestamos_marcados INT UNSIGNED NOT NULL
) ENGINE = InnoDB;

START TRANSACTION;

INSERT INTO equipos (id_equipo, nombre)
VALUES
    (1, 'Portátil de aula'),
    (2, 'Proyector portátil'),
    (3, 'Cámara web'),
    (4, 'Tableta gráfica'),
    (5, 'Medidor de red');

-- Los plazos se calculan respecto a la hora de carga.
INSERT INTO prestamos
    (id_prestamo, id_equipo, prestatario, vence_utc, estado, devuelto_utc)
VALUES
    (101, 1, 'Lucía', UTC_TIMESTAMP() - INTERVAL 2 DAY, 'ABIERTO', NULL),
    (102, 2, 'Hugo', UTC_TIMESTAMP() - INTERVAL 1 DAY, 'ABIERTO', NULL),
    (103, 3, 'Nora', UTC_TIMESTAMP() + INTERVAL 2 DAY, 'ABIERTO', NULL),
    (104, 4, 'Dani', UTC_TIMESTAMP() + INTERVAL 3 DAY, 'ABIERTO', NULL),
    (105, 5, 'Irene', UTC_TIMESTAMP() - INTERVAL 1 DAY, 'DEVUELTO',
        UTC_TIMESTAMP() - INTERVAL 2 DAY);

COMMIT;

-- El historial y las revisiones se llenarán durante la práctica.
