/* ============================================================
   EduTech Online - Modelo fisico v2 (DDL) - SQL Server
   Ajustes: CURSO, CARGA_ACADEMICA, inscripcion a carga academica,
            becas como catalogo, sin CATEGORIA, TIPO_PROGRAMA
            redefinido, costo en programa y curso.

   USO: ejecutar sobre la base ya creada. El script:
   - CONSERVA las tablas ALUMNO y MAESTRO (sin cambios) y sus datos.
   - ELIMINA y RECREA el resto (los datos de esas tablas se pierden).
   Si ya cargaste datos en las demas tablas, avisame antes de
   ejecutarlo para planear una migracion.
   ============================================================ */

IF DB_ID('EduTechOnline') IS NULL
    CREATE DATABASE EduTechOnline;
GO

USE EduTechOnline;
GO

/* ------------------------------------------------------------
   0. Limpieza de objetos de la version anterior
   ------------------------------------------------------------ */

DROP VIEW IF EXISTS dbo.vw_desempeno_maestro;
DROP VIEW IF EXISTS dbo.vw_desempeno_alumno_programa;
DROP VIEW IF EXISTS dbo.vw_desempeno_alumno_curso;
GO

DROP TABLE IF EXISTS dbo.EVALUACION_DOCENTE;
DROP TABLE IF EXISTS dbo.ENTREGA;
DROP TABLE IF EXISTS dbo.INSCRIPCION;   -- elimina tambien su trigger
DROP TABLE IF EXISTS dbo.CARGA_ACADEMICA;
DROP TABLE IF EXISTS dbo.PROYECTO;
DROP TABLE IF EXISTS dbo.CONTENIDO;
DROP TABLE IF EXISTS dbo.CURSO;
DROP TABLE IF EXISTS dbo.BECA;
DROP TABLE IF EXISTS dbo.PROGRAMA;
DROP TABLE IF EXISTS dbo.TIPO_PROGRAMA;
DROP TABLE IF EXISTS dbo.CATEGORIA;     -- entidad eliminada del modelo
GO

/* ------------------------------------------------------------
   1. Personas (sin cambios: se crean solo si no existen)
   ------------------------------------------------------------ */

IF OBJECT_ID('dbo.MAESTRO', 'U') IS NULL
BEGIN
    CREATE TABLE MAESTRO (
        id_maestro          INT IDENTITY(1,1) PRIMARY KEY,
        codigo              VARCHAR(10)     NOT NULL UNIQUE,
        nombre              NVARCHAR(150)   NOT NULL,
        documento_identidad VARCHAR(20)     NOT NULL UNIQUE,
        correo              NVARCHAR(150)   NOT NULL UNIQUE,
        especialidad        NVARCHAR(100)   NULL,
        fecha_alta          DATE            NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
        estado              VARCHAR(10)     NOT NULL DEFAULT ('activo')
            CONSTRAINT CK_MAESTRO_ESTADO CHECK (estado IN ('activo','inactivo'))
    );
END
GO

IF OBJECT_ID('dbo.ALUMNO', 'U') IS NULL
BEGIN
    CREATE TABLE ALUMNO (
        id_alumno           INT IDENTITY(1,1) PRIMARY KEY,
        codigo              VARCHAR(10)     NOT NULL UNIQUE,
        nombre              NVARCHAR(150)   NOT NULL,
        documento_identidad VARCHAR(20)     NOT NULL UNIQUE,
        correo              NVARCHAR(150)   NOT NULL UNIQUE,
        fecha_registro      DATE            NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
        estado              VARCHAR(10)     NOT NULL DEFAULT ('activo')
            CONSTRAINT CK_ALUMNO_ESTADO CHECK (estado IN ('activo','inactivo'))
    );
END
GO

/* ------------------------------------------------------------
   2. Tipo de programa (redefinido: formato de formacion)
      Ej.: Diplomado, Maestria, Curso libre
   ------------------------------------------------------------ */

CREATE TABLE TIPO_PROGRAMA (
    id_tipo         INT IDENTITY(1,1) PRIMARY KEY,
    codigo          VARCHAR(10)     NOT NULL UNIQUE,
    nombre          NVARCHAR(100)   NOT NULL,
    descripcion     NVARCHAR(255)   NULL
);
GO

/* ------------------------------------------------------------
   3. Programas academicos (sin categoria; con costo del paquete)
   ------------------------------------------------------------ */

CREATE TABLE PROGRAMA (
    id_programa     INT IDENTITY(1,1) PRIMARY KEY,
    codigo          VARCHAR(10)     NOT NULL UNIQUE,
    nombre          NVARCHAR(150)   NOT NULL,
    id_tipo         INT             NOT NULL,
    id_maestro      INT             NOT NULL,   -- maestro responsable
    descripcion     NVARCHAR(500)   NULL,
    duracion        NVARCHAR(50)    NULL,
    nivel           VARCHAR(15)     NULL
        CONSTRAINT CK_PROGRAMA_NIVEL CHECK (nivel IN ('basico','intermedio','avanzado')),
    costo           DECIMAL(10,2)   NOT NULL DEFAULT (0)
        CONSTRAINT CK_PROGRAMA_COSTO CHECK (costo >= 0),
    estado          VARCHAR(15)     NOT NULL DEFAULT ('en_preparacion')
        CONSTRAINT CK_PROGRAMA_ESTADO CHECK (estado IN ('activo','en_preparacion','cerrado')),
    CONSTRAINT FK_PROGRAMA_TIPO    FOREIGN KEY (id_tipo)    REFERENCES TIPO_PROGRAMA(id_tipo),
    CONSTRAINT FK_PROGRAMA_MAESTRO FOREIGN KEY (id_maestro) REFERENCES MAESTRO(id_maestro)
);
GO

/* ------------------------------------------------------------
   4. Cursos (nuevo): un programa tiene varios cursos
   ------------------------------------------------------------ */

CREATE TABLE CURSO (
    id_curso        INT IDENTITY(1,1) PRIMARY KEY,
    codigo          VARCHAR(10)     NOT NULL UNIQUE,
    id_programa     INT             NOT NULL,
    nombre          NVARCHAR(150)   NOT NULL,
    descripcion     NVARCHAR(500)   NULL,
    duracion        NVARCHAR(50)    NULL,
    costo           DECIMAL(10,2)   NOT NULL DEFAULT (0)
        CONSTRAINT CK_CURSO_COSTO CHECK (costo >= 0),
    estado          VARCHAR(15)     NOT NULL DEFAULT ('en_preparacion')
        CONSTRAINT CK_CURSO_ESTADO CHECK (estado IN ('activo','en_preparacion','cerrado')),
    CONSTRAINT FK_CURSO_PROGRAMA FOREIGN KEY (id_programa) REFERENCES PROGRAMA(id_programa)
);
GO

/* ------------------------------------------------------------
   5. Carga academica (nuevo): maestro asignado a curso/grupo
   ------------------------------------------------------------ */

CREATE TABLE CARGA_ACADEMICA (
    id_carga        INT IDENTITY(1,1) PRIMARY KEY,
    codigo          VARCHAR(20)     NOT NULL UNIQUE,
    id_curso        INT             NOT NULL,
    id_maestro      INT             NOT NULL,
    grupo           VARCHAR(10)     NOT NULL,
    fecha_inicio    DATE            NOT NULL,
    fecha_fin       DATE            NULL,
    estado          VARCHAR(15)     NOT NULL DEFAULT ('programada')
        CONSTRAINT CK_CARGA_ESTADO CHECK (estado IN ('programada','en_curso','cerrada')),
    CONSTRAINT FK_CARGA_CURSO   FOREIGN KEY (id_curso)   REFERENCES CURSO(id_curso),
    CONSTRAINT FK_CARGA_MAESTRO FOREIGN KEY (id_maestro) REFERENCES MAESTRO(id_maestro),
    CONSTRAINT UQ_CARGA_CURSO_GRUPO UNIQUE (id_curso, grupo, fecha_inicio),
    CONSTRAINT CK_CARGA_FECHAS CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);
GO

/* ------------------------------------------------------------
   6. Becas (redefinido): catalogo de tipos de beca
      id_programa NULL = beca general; con valor = beca del programa
   ------------------------------------------------------------ */

CREATE TABLE BECA (
    id_beca             INT IDENTITY(1,1) PRIMARY KEY,
    codigo              VARCHAR(10)     NOT NULL UNIQUE,
    nombre              NVARCHAR(100)   NOT NULL,
    descripcion         NVARCHAR(255)   NULL,
    porcentaje_descuento DECIMAL(5,2)   NOT NULL
        CONSTRAINT CK_BECA_PCT CHECK (porcentaje_descuento > 0 AND porcentaje_descuento <= 100),
    calificacion_minima DECIMAL(4,2)    NOT NULL
        CONSTRAINT CK_BECA_CALIF CHECK (calificacion_minima BETWEEN 0 AND 10),
    id_programa         INT             NULL,
    estado              VARCHAR(10)     NOT NULL DEFAULT ('activa')
        CONSTRAINT CK_BECA_ESTADO CHECK (estado IN ('activa','inactiva')),
    CONSTRAINT FK_BECA_PROGRAMA FOREIGN KEY (id_programa) REFERENCES PROGRAMA(id_programa)
);
GO

/* ------------------------------------------------------------
   7. Inscripciones (modificado): alumno -> carga academica
      id_beca es OPCIONAL (NULL cuando no hay beca) y SIN UNIQUE:
      un tipo de beca puede aplicarse a muchas inscripciones.
   ------------------------------------------------------------ */

CREATE TABLE INSCRIPCION (
    id_inscripcion      INT IDENTITY(1,1) PRIMARY KEY,
    id_alumno           INT             NOT NULL,
    id_carga            INT             NOT NULL,
    id_beca             INT             NULL,
    fecha_inscripcion   DATE            NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
    fecha_fin           DATE            NULL,
    estado              VARCHAR(15)     NOT NULL DEFAULT ('inscrito')
        CONSTRAINT CK_INSCRIPCION_ESTADO CHECK (estado IN ('inscrito','en_curso','finalizado','retirado')),
    CONSTRAINT FK_INSCRIPCION_ALUMNO FOREIGN KEY (id_alumno) REFERENCES ALUMNO(id_alumno),
    CONSTRAINT FK_INSCRIPCION_CARGA  FOREIGN KEY (id_carga)  REFERENCES CARGA_ACADEMICA(id_carga),
    CONSTRAINT FK_INSCRIPCION_BECA   FOREIGN KEY (id_beca)   REFERENCES BECA(id_beca),
    CONSTRAINT CK_INSCRIPCION_FECHAS CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inscripcion)
);
GO

/* ------------------------------------------------------------
   8. Proyectos (modificado): dependen del curso
   ------------------------------------------------------------ */

CREATE TABLE PROYECTO (
    id_proyecto     INT IDENTITY(1,1) PRIMARY KEY,
    id_curso        INT             NOT NULL,
    nombre          NVARCHAR(150)   NOT NULL,
    descripcion     NVARCHAR(500)   NULL,
    fecha_limite    DATE            NOT NULL,
    CONSTRAINT FK_PROYECTO_CURSO FOREIGN KEY (id_curso) REFERENCES CURSO(id_curso)
);
GO

/* ------------------------------------------------------------
   9. Entregas (modificado): dependen de la inscripcion.
      El maestro que califica se deriva de la carga academica.
   ------------------------------------------------------------ */

CREATE TABLE ENTREGA (
    id_entrega          INT IDENTITY(1,1) PRIMARY KEY,
    id_inscripcion      INT             NOT NULL,
    id_proyecto         INT             NOT NULL,
    fecha_entrega       DATETIME2       NOT NULL DEFAULT (SYSDATETIME()),
    archivo_referencia  NVARCHAR(500)   NULL,
    calificacion        DECIMAL(4,2)    NULL
        CONSTRAINT CK_ENTREGA_CALIF CHECK (calificacion IS NULL OR calificacion BETWEEN 0 AND 10),
    comentarios         NVARCHAR(1000)  NULL,
    estado              VARCHAR(15)     NOT NULL DEFAULT ('pendiente')
        CONSTRAINT CK_ENTREGA_ESTADO CHECK (estado IN ('pendiente','entregado','calificado')),
    CONSTRAINT FK_ENTREGA_INSCRIPCION FOREIGN KEY (id_inscripcion) REFERENCES INSCRIPCION(id_inscripcion),
    CONSTRAINT FK_ENTREGA_PROYECTO    FOREIGN KEY (id_proyecto)    REFERENCES PROYECTO(id_proyecto),
    CONSTRAINT UQ_ENTREGA_INSC_PROY   UNIQUE (id_inscripcion, id_proyecto)
);
GO

/* ------------------------------------------------------------
   10. Repositorio de contenido (sin cambios)
   ------------------------------------------------------------ */

CREATE TABLE CONTENIDO (
    id_contenido        INT IDENTITY(1,1) PRIMARY KEY,
    id_programa         INT             NOT NULL,
    id_maestro          INT             NOT NULL,
    tipo_contenido      VARCHAR(20)     NOT NULL
        CONSTRAINT CK_CONTENIDO_TIPO CHECK (tipo_contenido IN ('video','lectura','presentacion','ejercicio','otro')),
    nombre              NVARCHAR(150)   NOT NULL,
    fecha_publicacion   DATE            NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
    referencia_archivo  NVARCHAR(500)   NOT NULL,
    estado              VARCHAR(10)     NOT NULL DEFAULT ('visible')
        CONSTRAINT CK_CONTENIDO_ESTADO CHECK (estado IN ('visible','oculto')),
    CONSTRAINT FK_CONTENIDO_PROGRAMA FOREIGN KEY (id_programa) REFERENCES PROGRAMA(id_programa),
    CONSTRAINT FK_CONTENIDO_MAESTRO  FOREIGN KEY (id_maestro)  REFERENCES MAESTRO(id_maestro)
);
GO

/* ------------------------------------------------------------
   11. Evaluacion docente (modificado)
       Se ancla a la inscripcion: de ahi se derivan el curso y el
       maestro evaluado (inscripcion -> carga academica).
       Una evaluacion por inscripcion; obligatoria para finalizar
       (ver trigger).
   ------------------------------------------------------------ */

CREATE TABLE EVALUACION_DOCENTE (
    id_evaluacion       INT IDENTITY(1,1) PRIMARY KEY,
    id_inscripcion      INT             NOT NULL UNIQUE,
    fecha_evaluacion    DATE            NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
    calificacion        DECIMAL(3,1)    NOT NULL
        CONSTRAINT CK_EVALDOC_CALIF CHECK (calificacion BETWEEN 1 AND 5),
    comentarios         NVARCHAR(1000)  NULL,
    CONSTRAINT FK_EVALDOC_INSCRIPCION FOREIGN KEY (id_inscripcion) REFERENCES INSCRIPCION(id_inscripcion)
);
GO

/* Obliga a que exista la evaluacion docente antes de permitir
   que una inscripcion pase a estado 'finalizado' */
CREATE TRIGGER TR_INSCRIPCION_EVALUACION_OBLIGATORIA
ON INSCRIPCION
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.estado = 'finalizado'
          AND NOT EXISTS (
              SELECT 1
              FROM EVALUACION_DOCENTE ed
              WHERE ed.id_inscripcion = i.id_inscripcion
          )
    )
    BEGIN
        RAISERROR('No se puede finalizar la inscripcion sin registrar la evaluacion del maestro.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

/* ============================================================
   Vistas de apoyo
   ============================================================ */

/* Desempeno academico del alumno por inscripcion (curso/grupo) */
CREATE VIEW vw_desempeno_alumno_curso AS
SELECT
    i.id_inscripcion,
    i.id_alumno,
    c.id_curso,
    AVG(e.calificacion) AS promedio_calificacion,
    COUNT(e.id_entrega) AS proyectos_entregados
FROM INSCRIPCION i
JOIN CARGA_ACADEMICA c ON c.id_carga = i.id_carga
JOIN ENTREGA e         ON e.id_inscripcion = i.id_inscripcion
WHERE e.estado = 'calificado'
GROUP BY i.id_inscripcion, i.id_alumno, c.id_curso;
GO

/* Desempeno del maestro: resultado de sus alumnos (indirecto) y
   evaluaciones directas, ambos a traves de la carga academica.
   El ingreso generado por becas queda pendiente para el
   laboratorio de consultas. */
CREATE VIEW vw_desempeno_maestro AS
SELECT
    m.id_maestro,
    m.nombre,
    (SELECT AVG(e.calificacion)
     FROM ENTREGA e
     JOIN INSCRIPCION i      ON i.id_inscripcion = e.id_inscripcion
     JOIN CARGA_ACADEMICA c  ON c.id_carga = i.id_carga
     WHERE c.id_maestro = m.id_maestro AND e.estado = 'calificado'
    ) AS promedio_desempeno_alumnos,
    (SELECT AVG(ed.calificacion)
     FROM EVALUACION_DOCENTE ed
     JOIN INSCRIPCION i2     ON i2.id_inscripcion = ed.id_inscripcion
     JOIN CARGA_ACADEMICA c2 ON c2.id_carga = i2.id_carga
     WHERE c2.id_maestro = m.id_maestro
    ) AS promedio_evaluacion_directa
FROM MAESTRO m;
GO