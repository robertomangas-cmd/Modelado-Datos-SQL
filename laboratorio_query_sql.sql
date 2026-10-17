-- ==================================================================
/*
Ejercicio 1 — Catálogo de cursos de mayor costo

Pregunta de negocio

Dirección académica quiere revisar los cursos premium. Lista los cursos cuyo costo sea de 2,000 o más, con el programa al que pertenecen y el tipo de programa, del más caro al más barato (si hay empate, por código de curso).

Qué practicas: INNER JOIN de 3 tablas, WHERE, ORDER BY con varios criterios.

Pista: Recorre la cadena CURSO → PROGRAMA → TIPO_PROGRAMA.
*/
SELECT cu.codigo   AS curso_codigo,
       cu.nombre   AS curso,
       p.nombre    AS programa,
       tp.nombre   AS tipo_programa,
       cu.costo
FROM CURSO cu
JOIN PROGRAMA p        ON p.id_programa = cu.id_programa
JOIN TIPO_PROGRAMA tp  ON tp.id_tipo    = p.id_tipo
WHERE cu.costo >= 2000
ORDER BY cu.costo DESC, cu.codigo;

-- ==================================================================
/*
#### Ejercicio 2 — Inscripciones por estado

**Pregunta de negocio**

¿Cuántas inscripciones hay en cada estado (`inscrito`, `en_curso`, `finalizado`, `retirado`) y qué porcentaje representa cada una del total? Ordena de la más numerosa a la menos numerosa.

**Qué practicas:** `GROUP BY`, `COUNT`, subconsulta escalar para el total y `CAST` a decimal.

**Pista:** El total se obtiene con `(SELECT COUNT(*) FROM INSCRIPCION)`
*/
SELECT estado,
       COUNT(*) AS inscripciones,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM INSCRIPCION) AS DECIMAL(5,1)) AS porcentaje
FROM INSCRIPCION
GROUP BY estado
ORDER BY inscripciones DESC;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 3 — Carga de trabajo por maestro

**Pregunta de negocio**

¿Cuántas cargas académicas (curso + grupo + periodo) tiene asignadas cada maestro? Incluye a todos los maestros, aunque no tuvieran ninguna, y ordena de mayor a menor carga (desempata por código).

**Qué practicas:** `LEFT JOIN`, `COUNT` sobre una columna de la tabla de la derecha, `GROUP BY` con varias columnas.

**Pista:** Cuenta `c.id_carga` y no `COUNT(*)`: así un maestro sin cargas aparece con 0.
*/
SELECT m.codigo,
       m.nombre,
       m.especialidad,
       COUNT(c.id_carga) AS cargas
FROM MAESTRO m
LEFT JOIN CARGA_ACADEMICA c ON c.id_maestro = m.id_maestro
GROUP BY m.codigo, m.nombre, m.especialidad
ORDER BY cargas DESC, m.codigo;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 4 — Uso del catálogo de becas

**Pregunta de negocio**

Para cada tipo de beca del catálogo muestra su código, nombre, porcentaje de descuento, estado y **cuántas veces se ha utilizado** en una inscripción (las becas nunca usadas deben aparecer con 0). Ordena por código.

**Qué practicas:** `LEFT JOIN` entre catálogo y tabla de hechos; `COUNT` de una columna de la tabla opcional.

**Pista:** `BECA` es el catálogo; el uso queda registrado en `INSCRIPCION.id_beca`.
*/

SELECT b.codigo,
       b.nombre,
       b.porcentaje_descuento,
       b.estado,
       COUNT(i.id_inscripcion) AS veces_usada
FROM BECA b
LEFT JOIN INSCRIPCION i ON i.id_beca = b.id_beca
GROUP BY b.codigo, b.nombre, b.porcentaje_descuento, b.estado
ORDER BY b.codigo;
-- ==================================================================

-- ==================================================================
-- NIVEL INTERMEDIO
-- ==================================================================

-- ==================================================================
/* #### Ejercicio 5 — Los 10 mejores desempeños académicos

**Pregunta de negocio**

¿Cuáles son las 10 inscripciones **finalizadas** con mayor promedio de calificaciones? Muestra alumno, curso, carga, maestro, promedio y número de proyectos entregados. Desempata por código de alumno y luego por código de carga.

**Qué practicas:** Reutilizar una vista (`vw_desempeno_alumno_curso`), múltiples `JOIN`, `TOP` + `ORDER BY`.

**Pista:** La vista también incluye inscripciones en curso y retiradas con entregas calificadas: filtra por `i.estado`.
*/
SELECT TOP 10
       a.codigo AS alumno,
       a.nombre AS nombre_alumno,
       cu.nombre AS curso,
       ca.codigo AS carga,
       m.nombre  AS maestro,
       CAST(v.promedio_calificacion AS DECIMAL(4,2)) AS promedio,
       v.proyectos_entregados AS proyectos
FROM vw_desempeno_alumno_curso v
JOIN INSCRIPCION i       ON i.id_inscripcion = v.id_inscripcion
JOIN ALUMNO a            ON a.id_alumno      = v.id_alumno
JOIN CARGA_ACADEMICA ca  ON ca.id_carga      = i.id_carga
JOIN CURSO cu            ON cu.id_curso      = v.id_curso
JOIN MAESTRO m           ON m.id_maestro     = ca.id_maestro
WHERE i.estado = 'finalizado'
ORDER BY v.promedio_calificacion DESC, a.codigo, ca.codigo;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 6 — Ingreso bruto por área y tipo de programa

**Pregunta de negocio**

Finanzas quiere saber cuánto factura la escuela a precio de lista. Por **área** (Informatica, Finanzas, Administracion, Ciencias Politicas) y **tipo de programa**, calcula el número de inscripciones, el ingreso bruto (suma del costo del curso) y el ticket promedio. Excluye las inscripciones retiradas. Ordena por área y, dentro de cada área, por ingreso bruto descendente.

**Qué practicas:** `REPLACE` para extraer el área (ya no existe `CATEGORIA`: el área vive en `CURSO.descripcion`), agrupación por expresión, `SUM`, `AVG`.

**Pista:** `REPLACE(cu.descripcion, 'Curso de ', '')` devuelve el área. Agrupa por la misma expresión.
*/

SELECT REPLACE(cu.descripcion, 'Curso de ', '') AS area,
       tp.nombre                                   AS tipo_programa,
       COUNT(*)                                    AS inscripciones,
       SUM(cu.costo)                               AS ingreso_bruto,
       CAST(AVG(cu.costo) AS DECIMAL(10,2))        AS ticket_promedio
FROM INSCRIPCION i
JOIN CARGA_ACADEMICA c  ON c.id_carga    = i.id_carga
JOIN CURSO cu           ON cu.id_curso   = c.id_curso
JOIN PROGRAMA p         ON p.id_programa = cu.id_programa
JOIN TIPO_PROGRAMA tp   ON tp.id_tipo    = p.id_tipo
WHERE i.estado <> 'retirado'
GROUP BY REPLACE(cu.descripcion, 'Curso de ', ''), tp.nombre
ORDER BY area, ingreso_bruto DESC;
-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 7 — Alumnos constantes

**Pregunta de negocio**

¿Qué alumnos han **finalizado 3 o más cursos**? Para cada uno muestra cuántos cursos finalizó, en cuántos programas distintos y su promedio general (promedio de los promedios de cada curso). Ordena por promedio general descendente, luego por cursos finalizados descendente y por código.

**Qué practicas:** `GROUP BY` + `HAVING`, `COUNT(DISTINCT ...)`, promedio de promedios usando una vista.

**Pista:** `HAVING` filtra grupos ya agregados; `WHERE` filtra filas antes de agrupar.
*/

SELECT a.codigo,
       a.nombre,
       COUNT(*)                                   AS cursos_finalizados,
       COUNT(DISTINCT cu.id_programa)             AS programas_distintos,
       CAST(AVG(v.promedio_calificacion) AS DECIMAL(4,2)) AS promedio_general
FROM INSCRIPCION i
JOIN vw_desempeno_alumno_curso v ON v.id_inscripcion = i.id_inscripcion
JOIN ALUMNO a            ON a.id_alumno = i.id_alumno
JOIN CARGA_ACADEMICA c   ON c.id_carga  = i.id_carga
JOIN CURSO cu            ON cu.id_curso = c.id_curso
WHERE i.estado = 'finalizado'
GROUP BY a.codigo, a.nombre
HAVING COUNT(*) >= 3
ORDER BY promedio_general DESC, cursos_finalizados DESC, a.codigo;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 8 — Clasificación del desempeño docente

**Pregunta de negocio**

Clasifica a cada maestro combinando sus dos indicadores (`vw_desempeno_maestro`):

- **Destacado**: promedio de sus alumnos >= 8.7 **y** evaluación directa >= 4.2.
- **En observacion**: promedio de sus alumnos < 8.5 **y** evaluación directa < 3.9.
- **Regular**: cualquier otro caso.

Muestra código, nombre, especialidad, ambos promedios y la clasificación, ordenado por clasificación (Destacado, Regular, En observacion) y luego por código.

**Qué practicas:** Unir una vista con una tabla, `CASE` con condiciones compuestas, `ORDER BY` con `CASE`.

**Pista:** Para un orden propio usa `ORDER BY CASE clasificacion ... END`. Un alias no se puede usar dentro de otro `CASE` del mismo `SELECT`: calcula primero en una CTE.
*/

WITH base AS (
    SELECT m.codigo,
           m.nombre,
           m.especialidad,
           d.promedio_desempeno_alumnos  AS prom_alumnos,
           d.promedio_evaluacion_directa AS prom_evaluacion
    FROM vw_desempeno_maestro d
    JOIN MAESTRO m ON m.id_maestro = d.id_maestro
), clasificado AS (
    SELECT *,
           CASE
               WHEN prom_alumnos >= 8.7 AND prom_evaluacion >= 4.2 THEN 'Destacado'
               WHEN prom_alumnos <  8.5 AND prom_evaluacion <  3.9 THEN 'En observacion'
               ELSE 'Regular'
           END AS clasificacion
    FROM base
)
SELECT codigo, nombre, especialidad,
       CAST(prom_alumnos    AS DECIMAL(4,2)) AS prom_alumnos,
       CAST(prom_evaluacion AS DECIMAL(4,2)) AS prom_evaluacion,
       clasificacion
FROM clasificado
ORDER BY CASE clasificacion WHEN 'Destacado' THEN 1 WHEN 'Regular' THEN 2 ELSE 3 END, codigo;

-- ==================================================================

-- ==================================================================
-- NIVEL AVANZADO
-- ==================================================================

-- ==================================================================
/*
*Subconsultas correlacionadas con `APPLY`, funciones de ventana, CTE encadenadas y análisis de negocio completos.*

#### Ejercicio 9 — Ingreso neto generado por el incentivo de becas, por maestro

**Pregunta de negocio**

Este es el análisis que dejamos pendiente en el modelo de negocio. La beca es un **incentivo** para el maestro, no un castigo: cuando un alumno obtiene una beca por su desempeño en el curso de un maestro y la usa para inscribirse a un nuevo curso, el ingreso que paga en esa nueva inscripción se atribuye al **maestro del último curso que el alumno finalizó antes de inscribirse**.

Para cada maestro calcula: cuántas inscripciones con beca se le atribuyen, el ingreso bruto (costo del curso), el descuento otorgado y el **ingreso neto** (`costo × (1 − % descuento / 100)`). Ordena por ingreso neto descendente.

**Qué practicas:** CTE, `CROSS APPLY` con `TOP 1` (subconsulta correlacionada que devuelve una fila por alumno), agregaciones sobre cálculos.

**Pista:** Para cada inscripción con beca, busca en `INSCRIPCION` la inscripción **finalizada** del mismo alumno con la `fecha_fin` más reciente anterior a la `fecha_inscripcion` de la inscripción con beca.
*/

WITH becas_usadas AS (
    SELECT i.id_inscripcion,
           i.id_alumno,
           i.fecha_inscripcion,
           cu.costo,
           CAST(cu.costo * b.porcentaje_descuento / 100.0 AS DECIMAL(10,2)) AS descuento
    FROM INSCRIPCION i
    JOIN BECA b             ON b.id_beca   = i.id_beca
    JOIN CARGA_ACADEMICA c  ON c.id_carga  = i.id_carga
    JOIN CURSO cu           ON cu.id_curso = c.id_curso
)
SELECT m.codigo,
       m.nombre AS maestro,
       COUNT(*)                                  AS inscripciones_con_beca,
       CAST(SUM(bu.costo) AS DECIMAL(12,2))      AS ingreso_bruto,
       SUM(bu.descuento)                         AS descuento,
       SUM(bu.costo - bu.descuento)              AS ingreso_neto
FROM becas_usadas bu
CROSS APPLY (
    SELECT TOP 1 c2.id_maestro
    FROM INSCRIPCION p
    JOIN CARGA_ACADEMICA c2 ON c2.id_carga = p.id_carga
    WHERE p.id_alumno = bu.id_alumno
      AND p.estado = 'finalizado'
      AND p.fecha_fin < bu.fecha_inscripcion
    ORDER BY p.fecha_fin DESC
) origen
JOIN MAESTRO m ON m.id_maestro = origen.id_maestro
GROUP BY m.codigo, m.nombre
ORDER BY ingreso_neto DESC, m.codigo;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 10 — Derecho a beca vs. uso real de la beca

**Pregunta de negocio**

¿Qué pasó con los alumnos que **ganaron derecho a beca**? Considera cada inscripción finalizada con promedio >= 9.0 y observa la **siguiente inscripción** del mismo alumno (la primera con `fecha_inscripcion` posterior a la `fecha_fin` del curso). Clasifica el resultado en:

- **Sin siguiente inscripcion**: el alumno aún no se inscribió a nada más.
- **Fuera de vigencia**: se inscribió después de 1 mes de terminar el curso (la beca venció).
- **Con derecho y no uso la beca**: se inscribió dentro del mes pero sin aplicar beca.
- **Uso la beca**: se inscribió dentro del mes aplicando una beca.

Muestra la cantidad de casos de cada resultado y su porcentaje del total, de mayor a menor.

**Qué practicas:** Dos CTE encadenadas, `OUTER APPLY` + `TOP 1` (siguiente fila por alumno), `DATEADD`, `CASE` y `SUM(COUNT(*)) OVER ()` para el porcentaje.

**Pista:** Con `OUTER APPLY` conservas las inscripciones finalizadas que no tienen siguiente inscripción (la fecha llega en `NULL`).
*/

WITH finalizadas AS (
    SELECT i.id_inscripcion, i.id_alumno, i.fecha_fin
    FROM INSCRIPCION i
    JOIN vw_desempeno_alumno_curso v ON v.id_inscripcion = i.id_inscripcion
    WHERE i.estado = 'finalizado'
      AND v.promedio_calificacion >= 9.0
), siguiente AS (
    SELECT f.id_inscripcion, f.fecha_fin, s.fecha_inscripcion AS sig_fecha, s.id_beca AS sig_beca
    FROM finalizadas f
    OUTER APPLY (
        SELECT TOP 1 n.fecha_inscripcion, n.id_beca
        FROM INSCRIPCION n
        WHERE n.id_alumno = f.id_alumno
          AND n.fecha_inscripcion > f.fecha_fin
        ORDER BY n.fecha_inscripcion, n.id_inscripcion
    ) s
), clasificada AS (
    SELECT CASE
               WHEN sig_fecha IS NULL                              THEN 'Sin siguiente inscripcion'
               WHEN sig_fecha > DATEADD(MONTH, 1, fecha_fin)       THEN 'Fuera de vigencia'
               WHEN sig_beca IS NULL                               THEN 'Con derecho y no uso la beca'
               ELSE 'Uso la beca'
           END AS resultado
    FROM siguiente
)
SELECT resultado,
       COUNT(*) AS cantidad,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS porcentaje
FROM clasificada
GROUP BY resultado
ORDER BY cantidad DESC;

-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 11 — Evolución mensual del ingreso y efecto de las becas

**Pregunta de negocio**

Para el comité directivo: por **mes de inscripción**, muestra el número de inscripciones, el ingreso bruto (costo de lista), el descuento otorgado por becas, el ingreso neto, el porcentaje de descuento sobre el bruto y el **ingreso neto acumulado**. Excluye las inscripciones retiradas y ordena cronológicamente.

**Qué practicas:** CTE de agregación mensual, `DATEFROMPARTS`, `LEFT JOIN` con `COALESCE`, función de ventana acumulada `SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)`.

**Pista:** Primero agrega por mes en una CTE y después aplica la ventana sobre esa CTE.
*/

WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(i.fecha_inscripcion), MONTH(i.fecha_inscripcion), 1) AS mes,
           COUNT(*)                                                         AS inscripciones,
           SUM(cu.costo)                                                    AS ingreso_bruto,
           SUM(cu.costo * COALESCE(b.porcentaje_descuento, 0) / 100.0)      AS descuento_becas
    FROM INSCRIPCION i
    JOIN CARGA_ACADEMICA c ON c.id_carga  = i.id_carga
    JOIN CURSO cu          ON cu.id_curso = c.id_curso
    LEFT JOIN BECA b       ON b.id_beca   = i.id_beca
    WHERE i.estado <> 'retirado'
    GROUP BY DATEFROMPARTS(YEAR(i.fecha_inscripcion), MONTH(i.fecha_inscripcion), 1)
)
SELECT mes,
       inscripciones,
       CAST(ingreso_bruto AS DECIMAL(12,2))                                   AS ingreso_bruto,
       CAST(descuento_becas AS DECIMAL(12,2))                                 AS descuento_becas,
       CAST(ingreso_bruto - descuento_becas AS DECIMAL(12,2))                 AS ingreso_neto,
       CAST(100.0 * descuento_becas / ingreso_bruto AS DECIMAL(5,1))          AS pct_descuento,
       CAST(SUM(ingreso_bruto - descuento_becas)
            OVER (ORDER BY mes ROWS UNBOUNDED PRECEDING) AS DECIMAL(12,2))    AS neto_acumulado
FROM mensual
ORDER BY mes;
-- ==================================================================

-- ==================================================================
/*
#### Ejercicio 12 — Ranking docente por área con índice compuesto

**Pregunta de negocio**

Dirección académica quiere reconocer a los **2 mejores maestros de cada área** (la especialidad del maestro). Define un **índice de desempeño docente** que pese 50% el promedio de calificaciones de sus alumnos (sobre 10) y 50% la evaluación directa que reciben (sobre 5):

`indice = ((prom_alumnos / 10) * 0.5 + (prom_evaluacion / 5) * 0.5) * 100`

Muestra el área, la posición dentro del área, la posición general, el maestro, sus dos promedios y el índice (1 decimal). Ordena por área y posición.

**Qué practicas:** CTE encadenadas, `RANK() OVER (PARTITION BY ...)` y `RANK() OVER (ORDER BY ...)` en la misma consulta, filtrar sobre el resultado de una función de ventana.

**Pista:** No puedes filtrar por `RANK()` en el mismo `SELECT` donde se calcula: calcúlalo en una CTE y filtra en la consulta externa. Calcula el índice sin redondear y redondea solo al mostrarlo.
*/

WITH desempeno AS (
    SELECT m.nombre,
           m.especialidad AS area,
           d.promedio_desempeno_alumnos  AS prom_alumnos,
           d.promedio_evaluacion_directa AS prom_evaluacion,
           ((d.promedio_desempeno_alumnos / 10.0) * 0.5
          + (d.promedio_evaluacion_directa / 5.0) * 0.5) * 100 AS indice
    FROM vw_desempeno_maestro d
    JOIN MAESTRO m ON m.id_maestro = d.id_maestro
), ranking AS (
    SELECT *,
           RANK() OVER (PARTITION BY area ORDER BY indice DESC) AS posicion_area,
           RANK() OVER (ORDER BY indice DESC)                   AS posicion_general
    FROM desempeno
)
SELECT area,
       posicion_area,
       posicion_general,
       nombre AS maestro,
       CAST(prom_alumnos    AS DECIMAL(4,2)) AS prom_alumnos,
       CAST(prom_evaluacion AS DECIMAL(4,2)) AS prom_evaluacion,
       CAST(indice AS DECIMAL(5,1))          AS indice
FROM ranking
WHERE posicion_area <= 2
ORDER BY area, posicion_area;
-- ==================================================================