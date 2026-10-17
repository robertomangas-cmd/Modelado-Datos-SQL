# Laboratorio de consultas — EduTech Online

**12 ejercicios (4 básicos, 4 intermedios y 4 avanzados)** para practicar T-SQL con preguntas de negocio sobre el modelo de gestión académica. Se resuelven sobre la base `EduTechOnline` con la **carga masiva** de datos (`edutech_online_datos_masivos.sql`).

---

## 0. Antes de empezar

### Requisitos

1. Modelo físico v2 creado (`edutech_online_modelo_fisico_v2.sql`), que incluye las vistas `vw_desempeno_alumno_curso` y `vw_desempeno_maestro`.
2. Carga masiva ejecutada (`edutech_online_datos_masivos.sql`).
3. Ejecutar todo en SQL Server Management Studio con `USE EduTechOnline;`.

Verificación rápida: las tablas deben tener estos conteos.

| Tabla | Filas | Tabla | Filas |
|---|---|---|---|
| ALUMNO | 130 | INSCRIPCION | 331 |
| MAESTRO | 16 | ENTREGA | 653 |
| PROGRAMA | 13 | EVALUACION_DOCENTE | 264 |
| CURSO | 30 | BECA | 6 |
| CARGA_ACADEMICA | 109 | PROYECTO | 67 |
| TIPO_PROGRAMA | 3 | CONTENIDO | 60 |

### Cómo usar este documento

- Intenta cada ejercicio **sin mirar el solucionario**. La pista está debajo del enunciado.
- Compara tu salida con el **resultado esperado**. Los decimales pueden diferir en el último dígito por redondeo.
- El solucionario está al final, con una breve explicación de cómo leer cada consulta.
- Las etiquetas de resultado (`En observacion`, `Sin siguiente inscripcion`…) van **sin acentos** a propósito, para evitar problemas de codificación al copiar.

### Lo que hay que recordar del modelo

- **Fecha de referencia de los datos: 2026-10-16.** Los cursos del bloque en curso están `en_curso` y los siguientes están `programada`.
- **La inscripción es a una carga académica** (curso + grupo + periodo). De ahí se obtienen el curso, el programa y el maestro.
- **El área ya no es una tabla.** Vive en `CURSO.descripcion` (por ejemplo, *Curso de Finanzas*) y en `MAESTRO.especialidad`.
- **Regla de beca:** se aplica en la siguiente inscripción si el alumno terminó su último curso hace menos de 1 mes y su promedio alcanza la calificación mínima del tipo de beca. Si varias becas aplican, se usa la de mayor porcentaje.
- `INSCRIPCION.id_beca` es `NULL` cuando no hay beca. Todas las evaluaciones docentes cuelgan de una inscripción finalizada.

### Mapa de relaciones para los `JOIN`

| Desde | Hacia | Condición |
|---|---|---|
| `CURSO` | `PROGRAMA` | `cu.id_programa = p.id_programa` |
| `PROGRAMA` | `TIPO_PROGRAMA` | `p.id_tipo = tp.id_tipo` |
| `CARGA_ACADEMICA` | `CURSO` | `c.id_curso = cu.id_curso` |
| `CARGA_ACADEMICA` | `MAESTRO` | `c.id_maestro = m.id_maestro` |
| `INSCRIPCION` | `CARGA_ACADEMICA` | `i.id_carga = c.id_carga` |
| `INSCRIPCION` | `ALUMNO` | `i.id_alumno = a.id_alumno` |
| `INSCRIPCION` | `BECA` | `i.id_beca = b.id_beca` (opcional) |
| `ENTREGA` | `INSCRIPCION` / `PROYECTO` | `e.id_inscripcion`, `e.id_proyecto` |
| `EVALUACION_DOCENTE` | `INSCRIPCION` | `ed.id_inscripcion = i.id_inscripcion` |

---
## Resumen de ejercicios

| # | Nivel | Tema | Conceptos |
|---|---|---|---|
| 1 | Básico | Catálogo de cursos de mayor costo | `INNER JOIN` de 3 tablas, `WHERE`, `ORDER BY` con varios criterios. |
| 2 | Básico | Inscripciones por estado | `GROUP BY`, `COUNT`, subconsulta escalar para el total y `CAST` a decimal. |
| 3 | Básico | Carga de trabajo por maestro | `LEFT JOIN`, `COUNT` sobre una columna de la tabla de la derecha, `GROUP BY` con varias columnas. |
| 4 | Básico | Uso del catálogo de becas | `LEFT JOIN` entre catálogo y tabla de hechos; `COUNT` de una columna de la tabla opcional. |
| 5 | Intermedio | Los 10 mejores desempeños académicos | Reutilizar una vista (`vw_desempeno_alumno_curso`), múltiples `JOIN`, `TOP` + `ORDER BY`. |
| 6 | Intermedio | Ingreso bruto por área y tipo de programa | `REPLACE` para extraer el área (ya no existe `CATEGORIA`: el área vive en `CURSO.descripcion`), agrupación por expresión, `SUM`, `AVG`. |
| 7 | Intermedio | Alumnos constantes | `GROUP BY` + `HAVING`, `COUNT(DISTINCT ...)`, promedio de promedios usando una vista. |
| 8 | Intermedio | Clasificación del desempeño docente | Unir una vista con una tabla, `CASE` con condiciones compuestas, `ORDER BY` con `CASE`. |
| 9 | Avanzado | Ingreso neto generado por el incentivo de becas, por maestro | CTE, `CROSS APPLY` con `TOP 1` (subconsulta correlacionada que devuelve una fila por alumno), agregaciones sobre cálculos. |
| 10 | Avanzado | Derecho a beca vs. uso real de la beca | Dos CTE encadenadas, `OUTER APPLY` + `TOP 1` (siguiente fila por alumno), `DATEADD`, `CASE` y `SUM(COUNT(*)) OVER ()` para el porcentaje. |
| 11 | Avanzado | Evolución mensual del ingreso y efecto de las becas | CTE de agregación mensual, `DATEFROMPARTS`, `LEFT JOIN` con `COALESCE`, función de ventana acumulada `SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)`. |
| 12 | Avanzado | Ranking docente por área con índice compuesto | CTE encadenadas, `RANK() OVER (PARTITION BY ...)` y `RANK() OVER (ORDER BY ...)` en la misma consulta, filtrar sobre el resultado de una función de ventana. |

---

## Enunciados

### Nivel básico

*Consultas sobre una o pocas tablas: filtros, uniones simples, agrupaciones y conteos.*

#### Ejercicio 1 — Catálogo de cursos de mayor costo

**Pregunta de negocio**

Dirección académica quiere revisar los cursos premium. Lista los cursos cuyo costo sea de **2,000 o más**, con el programa al que pertenecen y el tipo de programa, del más caro al más barato (si hay empate, por código de curso).

**Qué practicas:** `INNER JOIN` de 3 tablas, `WHERE`, `ORDER BY` con varios criterios.

**Pista:** Recorre la cadena `CURSO → PROGRAMA → TIPO_PROGRAMA`.


---

#### Ejercicio 2 — Inscripciones por estado

**Pregunta de negocio**

¿Cuántas inscripciones hay en cada estado (`inscrito`, `en_curso`, `finalizado`, `retirado`) y qué porcentaje representa cada una del total? Ordena de la más numerosa a la menos numerosa.

**Qué practicas:** `GROUP BY`, `COUNT`, subconsulta escalar para el total y `CAST` a decimal.

**Pista:** El total se obtiene con `(SELECT COUNT(*) FROM INSCRIPCION)`.


---

#### Ejercicio 3 — Carga de trabajo por maestro

**Pregunta de negocio**

¿Cuántas cargas académicas (curso + grupo + periodo) tiene asignadas cada maestro? Incluye a todos los maestros, aunque no tuvieran ninguna, y ordena de mayor a menor carga (desempata por código).

**Qué practicas:** `LEFT JOIN`, `COUNT` sobre una columna de la tabla de la derecha, `GROUP BY` con varias columnas.

**Pista:** Cuenta `c.id_carga` y no `COUNT(*)`: así un maestro sin cargas aparece con 0.

---

#### Ejercicio 4 — Uso del catálogo de becas

**Pregunta de negocio**

Para cada tipo de beca del catálogo muestra su código, nombre, porcentaje de descuento, estado y **cuántas veces se ha utilizado** en una inscripción (las becas nunca usadas deben aparecer con 0). Ordena por código.

**Qué practicas:** `LEFT JOIN` entre catálogo y tabla de hechos; `COUNT` de una columna de la tabla opcional.

**Pista:** `BECA` es el catálogo; el uso queda registrado en `INSCRIPCION.id_beca`.

---

### Nivel intermedio

*Reutilización de vistas, `HAVING`, `CASE`, cálculos entre tablas y promedios de promedios.*

#### Ejercicio 5 — Los 10 mejores desempeños académicos

**Pregunta de negocio**

¿Cuáles son las 10 inscripciones **finalizadas** con mayor promedio de calificaciones? Muestra alumno, curso, carga, maestro, promedio y número de proyectos entregados. Desempata por código de alumno y luego por código de carga.

**Qué practicas:** Reutilizar una vista (`vw_desempeno_alumno_curso`), múltiples `JOIN`, `TOP` + `ORDER BY`.

**Pista:** La vista también incluye inscripciones en curso y retiradas con entregas calificadas: filtra por `i.estado`.


---

#### Ejercicio 6 — Ingreso bruto por área y tipo de programa

**Pregunta de negocio**

Finanzas quiere saber cuánto factura la escuela a precio de lista. Por **área** (Informatica, Finanzas, Administracion, Ciencias Politicas) y **tipo de programa**, calcula el número de inscripciones, el ingreso bruto (suma del costo del curso) y el ticket promedio. Excluye las inscripciones retiradas. Ordena por área y, dentro de cada área, por ingreso bruto descendente.

**Qué practicas:** `REPLACE` para extraer el área (ya no existe `CATEGORIA`: el área vive en `CURSO.descripcion`), agrupación por expresión, `SUM`, `AVG`.

**Pista:** `REPLACE(cu.descripcion, 'Curso de ', '')` devuelve el área. Agrupa por la misma expresión.

---

#### Ejercicio 7 — Alumnos constantes

**Pregunta de negocio**

¿Qué alumnos han **finalizado 3 o más cursos**? Para cada uno muestra cuántos cursos finalizó, en cuántos programas distintos y su promedio general (promedio de los promedios de cada curso). Ordena por promedio general descendente, luego por cursos finalizados descendente y por código.

**Qué practicas:** `GROUP BY` + `HAVING`, `COUNT(DISTINCT ...)`, promedio de promedios usando una vista.

**Pista:** `HAVING` filtra grupos ya agregados; `WHERE` filtra filas antes de agrupar.


---

#### Ejercicio 8 — Clasificación del desempeño docente

**Pregunta de negocio**

Clasifica a cada maestro combinando sus dos indicadores (`vw_desempeno_maestro`):

- **Destacado**: promedio de sus alumnos >= 8.7 **y** evaluación directa >= 4.2.
- **En observacion**: promedio de sus alumnos < 8.5 **y** evaluación directa < 3.9.
- **Regular**: cualquier otro caso.

Muestra código, nombre, especialidad, ambos promedios y la clasificación, ordenado por clasificación (Destacado, Regular, En observacion) y luego por código.

**Qué practicas:** Unir una vista con una tabla, `CASE` con condiciones compuestas, `ORDER BY` con `CASE`.

**Pista:** Para un orden propio usa `ORDER BY CASE clasificacion ... END`. Un alias no se puede usar dentro de otro `CASE` del mismo `SELECT`: calcula primero en una CTE.

---

### Nivel avanzado

*Subconsultas correlacionadas con `APPLY`, funciones de ventana, CTE encadenadas y análisis de negocio completos.*

#### Ejercicio 9 — Ingreso neto generado por el incentivo de becas, por maestro

**Pregunta de negocio**

Este es el análisis que dejamos pendiente en el modelo de negocio. La beca es un **incentivo** para el maestro, no un castigo: cuando un alumno obtiene una beca por su desempeño en el curso de un maestro y la usa para inscribirse a un nuevo curso, el ingreso que paga en esa nueva inscripción se atribuye al **maestro del último curso que el alumno finalizó antes de inscribirse**.

Para cada maestro calcula: cuántas inscripciones con beca se le atribuyen, el ingreso bruto (costo del curso), el descuento otorgado y el **ingreso neto** (`costo × (1 − % descuento / 100)`). Ordena por ingreso neto descendente.

**Qué practicas:** CTE, `CROSS APPLY` con `TOP 1` (subconsulta correlacionada que devuelve una fila por alumno), agregaciones sobre cálculos.

**Pista:** Para cada inscripción con beca, busca en `INSCRIPCION` la inscripción **finalizada** del mismo alumno con la `fecha_fin` más reciente anterior a la `fecha_inscripcion` de la inscripción con beca.


---

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

---

#### Ejercicio 11 — Evolución mensual del ingreso y efecto de las becas

**Pregunta de negocio**

Para el comité directivo: por **mes de inscripción**, muestra el número de inscripciones, el ingreso bruto (costo de lista), el descuento otorgado por becas, el ingreso neto, el porcentaje de descuento sobre el bruto y el **ingreso neto acumulado**. Excluye las inscripciones retiradas y ordena cronológicamente.

**Qué practicas:** CTE de agregación mensual, `DATEFROMPARTS`, `LEFT JOIN` con `COALESCE`, función de ventana acumulada `SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)`.

**Pista:** Primero agrega por mes en una CTE y después aplica la ventana sobre esa CTE.

---

#### Ejercicio 12 — Ranking docente por área con índice compuesto

**Pregunta de negocio**

Dirección académica quiere reconocer a los **2 mejores maestros de cada área** (la especialidad del maestro). Define un **índice de desempeño docente** que pese 50% el promedio de calificaciones de sus alumnos (sobre 10) y 50% la evaluación directa que reciben (sobre 5):

`indice = ((prom_alumnos / 10) * 0.5 + (prom_evaluacion / 5) * 0.5) * 100`

Muestra el área, la posición dentro del área, la posición general, el maestro, sus dos promedios y el índice (1 decimal). Ordena por área y posición.

**Qué practicas:** CTE encadenadas, `RANK() OVER (PARTITION BY ...)` y `RANK() OVER (ORDER BY ...)` en la misma consulta, filtrar sobre el resultado de una función de ventana.

**Pista:** No puedes filtrar por `RANK()` en el mismo `SELECT` donde se calcula: calcúlalo en una CTE y filtra en la consulta externa. Calcula el índice sin redondear y redondea solo al mostrarlo.
