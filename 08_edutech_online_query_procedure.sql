/* EduTech Online - Laboratorio de procedimientos almacenados (T-SQL, SQL Server)
   Requisitos: modelo fisico v2 + carga masiva (edutech_online_datos_masivos.sql).
   Cada bloque CREATE OR ALTER PROCEDURE va en su propio lote (GO).
   Las pruebas usan fechas fijas (2026-10-16) para obtener siempre el mismo resultado. */
 
-- ==================================================================
-- Procedimiento 1 - Basico: sp_resumen_alumno
-- ==================================================================

/*
Procedimiento 1 — Resumen de un alumno

Especificación

Secretaría académica necesita consultar la situación de un alumno con una sola instrucción. Crea el procedimiento dbo.sp_resumen_alumno que reciba el código del alumno (@codigo_alumno VARCHAR(10)) y devuelva dos resultados:

Ficha y totales: código, nombre, estado, número de inscripciones, número de cursos finalizados y promedio general (promedio de los promedios de los cursos finalizados, con 2 decimales).
Historial: una fila por inscripción con código y nombre del curso, carga, maestro, fecha de inscripción, estado, promedio del curso y código de la beca aplicada (o NULL). Ordenado por fecha de inscripción.

Si el código no existe, el procedimiento debe fallar con un error claro (THROW) en lugar de devolver tablas vacías.

Qué practicas: Parámetro de entrada, variables locales, SET NOCOUNT ON, validación con IF + THROW, varios resultados en un mismo procedimiento, reutilización de una vista.

Pista: Primero busca el id_alumno en una variable; si es NULL, lanza el error. El mensaje de THROW debe ser una variable o literal: arma el texto con CONCAT.

*/



CREATE OR ALTER PROCEDURE dbo.sp_resumen_alumno
    @codigo_alumno VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @id_alumno INT;
 
    SELECT @id_alumno = id_alumno
    FROM ALUMNO
    WHERE codigo = @codigo_alumno;
 
    IF @id_alumno IS NULL
    BEGIN
        DECLARE @msg NVARCHAR(200) = CONCAT('El alumno ', @codigo_alumno, ' no existe.');
        THROW 50001, @msg, 1;
    END;
 
    -- Resultado 1: ficha y totales del alumno
    SELECT a.codigo,
           a.nombre,
           a.estado,
           COUNT(i.id_inscripcion) AS inscripciones,
           SUM(CASE WHEN i.estado = 'finalizado' THEN 1 ELSE 0 END) AS finalizadas,
           CAST(AVG(CASE WHEN i.estado = 'finalizado' THEN d.promedio_calificacion END)
                AS DECIMAL(4,2)) AS promedio_general
    FROM ALUMNO a
    LEFT JOIN INSCRIPCION i ON i.id_alumno = a.id_alumno
    LEFT JOIN vw_desempeno_alumno_curso d ON d.id_inscripcion = i.id_inscripcion
    WHERE a.id_alumno = @id_alumno
    GROUP BY a.codigo, a.nombre, a.estado;
 
    -- Resultado 2: historial de inscripciones
    SELECT cu.codigo AS curso_codigo,
           cu.nombre AS curso,
           c.codigo  AS carga,
           m.nombre  AS maestro,
           i.fecha_inscripcion,
           i.estado,
           CAST(d.promedio_calificacion AS DECIMAL(4,2)) AS promedio,
           b.codigo  AS beca
    FROM INSCRIPCION i
    JOIN CARGA_ACADEMICA c ON c.id_carga   = i.id_carga
    JOIN CURSO cu          ON cu.id_curso  = c.id_curso
    JOIN MAESTRO m         ON m.id_maestro = c.id_maestro
    LEFT JOIN BECA b       ON b.id_beca    = i.id_beca
    LEFT JOIN vw_desempeno_alumno_curso d ON d.id_inscripcion = i.id_inscripcion
    WHERE i.id_alumno = @id_alumno
    ORDER BY i.fecha_inscripcion, i.id_inscripcion;
END;
GO
 
-- Pruebas del procedimiento 1
-- Caso 1: alumno con 4 cursos finalizados
EXEC dbo.sp_resumen_alumno 'A027';
 
-- Caso 2: alumno con un retiro y becas
EXEC dbo.sp_resumen_alumno 'A019';
 
-- Caso 3: alumno que no existe (debe fallar con un mensaje claro)
BEGIN TRY
    EXEC dbo.sp_resumen_alumno 'A999';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO
 
-- ==================================================================
-- Procedimiento 2 - Intermedio: sp_calcular_beca
-- ==================================================================

/*
La regla de becas hoy se aplica «a mano». Encapsúlala en el procedimiento dbo.sp_calcular_beca, con estos parámetros:

Parámetro	        Tipo	        Dirección
@codigo_alumno	    VARCHAR(10)	    entrada
@codigo_carga	    VARCHAR(20)	    entrada (carga a la que quiere inscribirse)
@fecha_inscripcion	DATE	        entrada
@id_beca	        INT	salida      (NULL si no hay beca)
@porcentaje	        DECIMAL(5,2)	salida (0 si no hay beca)
@motivo	            VARCHAR(60)	    salida

Reglas (las mismas del modelo de negocio):

Se toma el último curso finalizado del alumno con fecha_fin anterior a la fecha de inscripción.
La beca solo vale si la inscripción ocurre dentro de 1 mes de esa fecha de fin.
Si vale, se elige la beca activa de mayor porcentaje cuya calificación mínima no supere el promedio de ese curso y que sea general o del mismo programa que el curso destino.
@motivo debe ser uno de: Sin curso finalizado previo, Beca vencida (mas de 1 mes), Promedio insuficiente o Beca aplicable.
Si el alumno o la carga no existen, debe lanzar un error.

Qué practicas: Parámetros de salida (OUTPUT), asignación con SELECT TOP 1 @var = ..., RETURN anticipado, DATEADD, CASE, reglas de negocio dentro de la base de datos.

Pista: Piensa el procedimiento como una cadena de filtros: si no hay curso previo sales con un motivo, si venció sales con otro, y solo si pasa ambos buscas la beca. Recuerda inicializar los parámetros de salida al comienzo.

*/

CREATE OR ALTER PROCEDURE dbo.sp_calcular_beca
    @codigo_alumno     VARCHAR(10),
    @codigo_carga      VARCHAR(20),
    @fecha_inscripcion DATE,
    @id_beca           INT           OUTPUT,
    @porcentaje        DECIMAL(5,2)  OUTPUT,
    @motivo            VARCHAR(60)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @id_alumno   INT,
            @id_programa INT,
            @fin_previo  DATE,
            @promedio    DECIMAL(9,6),
            @msg         NVARCHAR(200);
 
    SELECT @id_beca = NULL, @porcentaje = 0, @motivo = NULL;
 
    -- Validaciones de entrada
    SELECT @id_alumno = id_alumno FROM ALUMNO WHERE codigo = @codigo_alumno;
    IF @id_alumno IS NULL
    BEGIN
        SET @msg = CONCAT('El alumno ', @codigo_alumno, ' no existe.');
        THROW 50010, @msg, 1;
    END;
 
    SELECT @id_programa = cu.id_programa
    FROM CARGA_ACADEMICA c
    JOIN CURSO cu ON cu.id_curso = c.id_curso
    WHERE c.codigo = @codigo_carga;
    IF @id_programa IS NULL
    BEGIN
        SET @msg = CONCAT('La carga ', @codigo_carga, ' no existe.');
        THROW 50011, @msg, 1;
    END;
 
    -- Ultimo curso finalizado ANTES de la fecha de inscripcion
    SELECT TOP 1
           @fin_previo = i.fecha_fin,
           @promedio   = d.promedio_calificacion
    FROM INSCRIPCION i
    JOIN vw_desempeno_alumno_curso d ON d.id_inscripcion = i.id_inscripcion
    WHERE i.id_alumno = @id_alumno
      AND i.estado = 'finalizado'
      AND i.fecha_fin < @fecha_inscripcion
    ORDER BY i.fecha_fin DESC, i.id_inscripcion DESC;
 
    IF @fin_previo IS NULL
    BEGIN
        SET @motivo = 'Sin curso finalizado previo';
        RETURN;
    END;
 
    -- Vigencia: 1 mes desde la finalizacion del ultimo curso
    IF @fecha_inscripcion > DATEADD(MONTH, 1, @fin_previo)
    BEGIN
        SET @motivo = 'Beca vencida (mas de 1 mes)';
        RETURN;
    END;
 
    -- Beca de mayor porcentaje a la que el promedio da derecho
    SELECT TOP 1
           @id_beca    = b.id_beca,
           @porcentaje = b.porcentaje_descuento
    FROM BECA b
    WHERE b.estado = 'activa'
      AND b.calificacion_minima <= @promedio
      AND (b.id_programa IS NULL OR b.id_programa = @id_programa)
    ORDER BY b.porcentaje_descuento DESC;
 
    SET @motivo = CASE WHEN @id_beca IS NULL THEN 'Promedio insuficiente'
                       ELSE 'Beca aplicable' END;
END;
GO
 
-- Pruebas del procedimiento 2
DECLARE @pruebas TABLE (alumno VARCHAR(10), carga VARCHAR(20), fecha DATE);
INSERT INTO @pruebas (alumno, carga, fecha) VALUES
    ('A035', 'C005-G1-2611', '2026-10-16'),   -- promedio 10.0
    ('A010', 'C005-G1-2611', '2026-10-16'),   -- promedio >= 9.5
    ('A041', 'C005-G1-2611', '2026-10-16'),   -- promedio >= 9.0
    ('A001', 'C005-G1-2611', '2026-10-16'),   -- ultimo curso hace mas de 1 mes
    ('A015', 'C005-G1-2611', '2026-10-16'),   -- promedio menor a 9.0
    ('A003', 'C005-G1-2611', '2026-10-16'),   -- primer curso del alumno
    ('A050', 'C014-G1-2604', '2026-04-05'),   -- beca exclusiva de la maestria
    ('A050', 'C005-G1-2604', '2026-04-05');   -- misma fecha, curso de otro programa
 
DECLARE @res TABLE (n INT IDENTITY(1,1), alumno VARCHAR(10), carga VARCHAR(20), fecha DATE,
                    id_beca INT, porcentaje DECIMAL(5,2), motivo VARCHAR(60));
DECLARE @a VARCHAR(10), @c VARCHAR(20), @f DATE,
        @id_beca INT, @pct DECIMAL(5,2), @motivo VARCHAR(60);
 
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT alumno, carga, fecha FROM @pruebas;
OPEN cur;
FETCH NEXT FROM cur INTO @a, @c, @f;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.sp_calcular_beca @a, @c, @f, @id_beca OUTPUT, @pct OUTPUT, @motivo OUTPUT;
    INSERT INTO @res (alumno, carga, fecha, id_beca, porcentaje, motivo)
    VALUES (@a, @c, @f, @id_beca, @pct, @motivo);
    FETCH NEXT FROM cur INTO @a, @c, @f;
END;
CLOSE cur;
DEALLOCATE cur;
 
SELECT r.alumno, r.carga, r.fecha, b.codigo AS beca, r.porcentaje, r.motivo
FROM @res r
LEFT JOIN BECA b ON b.id_beca = r.id_beca
ORDER BY r.n;
 
-- Errores esperados
BEGIN TRY
    EXEC dbo.sp_calcular_beca 'A999', 'C005-G1-2611', '2026-10-16', @id_beca OUTPUT, @pct OUTPUT, @motivo OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO
 
-- ==================================================================
-- Procedimiento 3 - Avanzado: sp_inscribir_alumno (requiere el procedimiento 2)
-- ==================================================================
/*
Nivel avanzado
Procedimiento 3 — Inscripción transaccional con beca automática

Especificación

Registrar una inscripción debe ser una operación única, validada y atómica. Crea dbo.sp_inscribir_alumno con los parámetros:

@codigo_alumno VARCHAR(10) y @codigo_carga VARCHAR(20) (entrada).
@fecha_inscripcion DATE = NULL (si no se indica, usa la fecha de hoy).
@id_inscripcion INT = NULL OUTPUT (devuelve el id creado).

El procedimiento debe:

Validar y lanzar un error distinto (con su propio número) cuando: el alumno no existe, el alumno está inactivo, la carga no existe, la carga está cerrada, o el alumno ya tiene una inscripción vigente (no retirada) en esa misma carga.
Dentro de una transacción, obtener la beca llamando a sp_calcular_beca (procedimiento anidado) e insertar la inscripción en estado inscrito con esa beca.
Ante cualquier fallo, revertir y relanzar el error original.
Devolver un comprobante: id, alumno, carga, curso, precio de lista, beca, porcentaje, descuento, ingreso neto y motivo de la beca.

Qué practicas: TRY/CATCH, BEGIN/COMMIT/ROLLBACK TRANSACTION, SET XACT_ABORT ON, THROW con números propios y relanzamiento, SCOPE_IDENTITY(), llamada a un procedimiento desde otro con parámetros OUTPUT, valores por defecto.

Pista: Haz todas las validaciones antes de abrir la transacción: así los errores previsibles no tocan datos. Dentro del CATCH, revisa @@TRANCOUNT antes del ROLLBACK. Para probar sin ensuciar la base, envuelve tus llamadas en BEGIN TRANSACTION ... ROLLBACK.
*/

CREATE OR ALTER PROCEDURE dbo.sp_inscribir_alumno
    @codigo_alumno     VARCHAR(10),
    @codigo_carga      VARCHAR(20),
    @fecha_inscripcion DATE = NULL,
    @id_inscripcion    INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
 
    DECLARE @id_alumno     INT,
            @estado_alumno VARCHAR(10),
            @id_carga      INT,
            @estado_carga  VARCHAR(15),
            @id_beca       INT,
            @pct           DECIMAL(5,2),
            @motivo        VARCHAR(60),
            @msg           NVARCHAR(200);
 
    SET @fecha_inscripcion = ISNULL(@fecha_inscripcion, CAST(GETDATE() AS DATE));
 
    -- 1) Validaciones
    SELECT @id_alumno = id_alumno, @estado_alumno = estado
    FROM ALUMNO WHERE codigo = @codigo_alumno;
 
    IF @id_alumno IS NULL
    BEGIN
        SET @msg = CONCAT('El alumno ', @codigo_alumno, ' no existe.');
        THROW 50020, @msg, 1;
    END;
 
    IF @estado_alumno <> 'activo'
    BEGIN
        SET @msg = CONCAT('El alumno ', @codigo_alumno, ' esta inactivo.');
        THROW 50021, @msg, 1;
    END;
 
    SELECT @id_carga = id_carga, @estado_carga = estado
    FROM CARGA_ACADEMICA WHERE codigo = @codigo_carga;
 
    IF @id_carga IS NULL
    BEGIN
        SET @msg = CONCAT('La carga ', @codigo_carga, ' no existe.');
        THROW 50022, @msg, 1;
    END;
 
    IF @estado_carga = 'cerrada'
    BEGIN
        SET @msg = CONCAT('La carga ', @codigo_carga, ' esta cerrada.');
        THROW 50023, @msg, 1;
    END;
 
    IF EXISTS (SELECT 1 FROM INSCRIPCION
               WHERE id_alumno = @id_alumno
                 AND id_carga  = @id_carga
                 AND estado <> 'retirado')
    BEGIN
        SET @msg = CONCAT('El alumno ', @codigo_alumno, ' ya esta inscrito en la carga ', @codigo_carga, '.');
        THROW 50024, @msg, 1;
    END;
 
    -- 2) Alta de la inscripcion (con la beca que corresponda) en una transaccion
    BEGIN TRY
        BEGIN TRANSACTION;
 
        EXEC dbo.sp_calcular_beca @codigo_alumno, @codigo_carga, @fecha_inscripcion,
                                  @id_beca OUTPUT, @pct OUTPUT, @motivo OUTPUT;
 
        INSERT INTO INSCRIPCION (id_alumno, id_carga, id_beca, fecha_inscripcion, estado)
        VALUES (@id_alumno, @id_carga, @id_beca, @fecha_inscripcion, 'inscrito');
 
        SET @id_inscripcion = SCOPE_IDENTITY();
 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
 
    -- 3) Comprobante de la inscripcion
    SELECT i.id_inscripcion,
           a.codigo AS alumno,
           c.codigo AS carga,
           cu.nombre AS curso,
           cu.costo  AS precio_lista,
           b.codigo  AS beca,
           @pct      AS pct_descuento,
           CAST(cu.costo * @pct / 100 AS DECIMAL(10,2))       AS descuento,
           CAST(cu.costo * (1 - @pct / 100) AS DECIMAL(10,2)) AS ingreso_neto,
           @motivo   AS motivo_beca
    FROM INSCRIPCION i
    JOIN ALUMNO a          ON a.id_alumno  = i.id_alumno
    JOIN CARGA_ACADEMICA c ON c.id_carga   = i.id_carga
    JOIN CURSO cu          ON cu.id_curso  = c.id_curso
    LEFT JOIN BECA b       ON b.id_beca    = i.id_beca
    WHERE i.id_inscripcion = @id_inscripcion;
END;
