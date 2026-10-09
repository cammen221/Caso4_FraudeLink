# FraudeLink - Detección de patrones de riesgo con Neo4j

FraudeLink es una solución orientada a grafos para representar y analizar relaciones entre clientes, cuentas, dispositivos, direcciones IP, comercios y transferencias.

El proyecto utiliza **Neo4j** como base de datos de grafos y **Neo4j Graph Data Science (GDS)** para ejecutar algoritmos como **PageRank** y **Louvain**.

La instancia de Neo4j se ejecuta localmente mediante Docker para facilitar la reproducción del proyecto.

---

# Índice

1. [Modelo del grafo](#modelo-del-grafo)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Prerrequisitos](#prerrequisitos)
4. [Instalación](#instalación)
5. [Carga de datos](#carga-de-datos)
6. [Ejecución](#ejecución)
7. [Centralidad con PageRank](#centralidad-con-pagerank)
8. [Detección de comunidades con Louvain](#detección-de-comunidades-con-louvain)
9. [Relación entre PageRank y Louvain](#relación-entre-pagerank-y-louvain)
10. [Consultas](#consultas)
11. [Comparación con el modelo relacional](#comparación-con-el-modelo-relacional)
12. [Pruebas](#pruebas)
13. [Demostración](#demostración)
14. [Archivos de modelo](#archivos-de-modelo)
15. [Tecnologías utilizadas](#tecnologías-utilizadas)

---

# Modelo del grafo

El grafo contiene los siguientes tipos de nodos:

| Nodo | Identificador |
|---|---|
| `Cliente` | `cliente_id` |
| `Cuenta` | `cuenta_id` |
| `Dispositivo` | `dispositivo_id` |
| `IP` | `ip_address` |
| `Comercio` | `comercio_id` |

Las relaciones utilizadas son:

| Relación | Origen | Destino |
|---|---|---|
| `POSEE` | Cliente | Cuenta |
| `USA_DISPOSITIVO` | Cuenta | Dispositivo |
| `CONECTA_DESDE` | Cuenta | IP |
| `TRANSFIERE_A` | Cuenta | Cuenta |
| `PAGA_EN` | Cuenta | Comercio |

Las relaciones pueden incluir propiedades como `fecha` y `monto`.

El modelo responde a la necesidad de representar conexiones entre cuentas, dispositivos, IP, comercios y transferencias de una forma que facilite el análisis de patrones de riesgo.

## Justificación del esquema

Cada decisión del modelo responde a un patrón de fraude que se quiere detectar:

| Decisión | Justificación |
|---|---|
| `Cliente` y `Cuenta` son nodos separados, unidos por `POSEE` | Una misma persona puede tener varias cuentas. Separarlos permite distinguir cuándo varias cuentas pertenecen a **identidades distintas** (requisito 2). |
| `Dispositivo` e `IP` son nodos, no propiedades de la cuenta | Si fueran una propiedad, encontrar cuentas que comparten un dispositivo exigiría comparar todas las cuentas entre sí. Como nodos, varias cuentas apuntan al mismo dispositivo o IP y el patrón compartido se ve con un solo salto. |
| `TRANSFIERE_A` es una relación entre cuentas, con `monto` y `fecha` | El dinero se mueve de cuenta a cuenta. Modelarlo como relación permite seguir la ruta del dinero (requisito 6) y detectar ciclos (requisito 3) recorriendo el grafo, en lugar de hacer un JOIN por cada salto. |
| `monto` y `fecha` van en la relación, no en un nodo `Transacción` | Cada transferencia une exactamente dos cuentas, así que basta con la relación. Los recorridos son más cortos (1 salto por transferencia en vez de 2) y las condiciones de fecha y monto se evalúan sobre la misma relación. |
| `Comercio` es un nodo, unido por `PAGA_EN` | Permite ver comercios que reciben pagos de muchas cuentas sospechosas, y que aparezcan como nodos centrales en PageRank. |
| Las relaciones tienen dirección | La dirección indica quién envía y quién recibe. Es necesaria para la ruta del dinero (6a) y para PageRank. Para comunidades (Louvain) se ignora la dirección en la proyección. |
| `cliente_id`, `cuenta_id`, `dispositivo_id`, `ip_address` y `comercio_id` tienen restricción de unicidad | Evitan nodos duplicados al cargar y aceleran la búsqueda del nodo inicial de cada consulta. |

---

# Estructura del proyecto

```text
Caso4_FraudeLink/
│
├── .env.example                 -> ejemplo de variables de conexión (sin contraseña real)
├── Benchmark.ipynb              -> pruebas de desempeño de los algoritmos GDS
├── centralidad.ipynb            -> PageRank y Louvain
├── creacion.datos.R             -> genera los CSV de data/
├── docker-compose.yml           -> instancia local de Neo4j
├── importar_datos.py            -> carga los CSV en Neo4j
├── modelo_final.json            -> modelo del grafo (Neo4j Data Importer)
├── README.md
│
├── data/                        -> CSV de nodos y relaciones
│
├── Consultas Neo4j/             -> consultas Cypher de los requisitos 2, 3, 6 y 7
│   ├── Consulta 2/
│   ├── Consulta 3/
│   ├── Consultas 6/
│   └── Consultas 7/
│
└── Consultas en SQL/            -> versión relacional y comparación con JOINs
    ├── 1_tablas_y_nodos.sql
    ├── 2_relaciones.sql
    ├── 3_transferencias.sql
    ├── 4_pagos_e_indices.sql
    └── Consultas.sql
```

## `.env`

Contiene las variables de conexión utilizadas para acceder a Neo4j.

El archivo `.env` **no se incluye en el repositorio** porque contiene la contraseña. En su lugar se incluye `.env.example`, que se copia y se completa localmente:

```env
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=cambiar_por_una_contraseña
```

El mismo `.env` lo usan `docker-compose.yml`, `importar_datos.py` y los notebooks, así que la contraseña se define en un solo lugar.

---

## `docker-compose.yml`

Define la instancia local de Neo4j utilizada por el proyecto.

El contenedor expone los siguientes puertos:

```text
7474 -> Neo4j Browser
7687 -> conexión Bolt
```

También habilita los plugins necesarios para trabajar con:

- APOC
- Neo4j Graph Data Science

Docker levanta la instancia de Neo4j, pero no carga automáticamente los datos.

La carga se realiza posteriormente mediante `importar_datos.py`.

---

## `creacion.datos.R`

Genera el conjunto de datos sintético utilizado en el proyecto.

El script utiliza una semilla fija:

```r
set.seed(42)
```

Esto permite generar los mismos datos de forma reproducible.

El script crea:

```text
4 000 clientes
5 000 cuentas
2 000 dispositivos
1 000 direcciones IP
500 comercios
```

Para un total de:

```text
12 500 nodos
```

También genera las relaciones:

```text
POSEE
USA_DISPOSITIVO
CONECTA_DESDE
TRANSFIERE_A
PAGA_EN
```

Los datos se exportan en formato CSV dentro de la carpeta:

```text
data/
```

El conjunto generado contiene aproximadamente:

```text
66 007 relaciones
```

Además, el generador incluye algunos patrones controlados, como ciclos de transferencias, para facilitar la detección de estructuras relevantes durante el análisis.

---

## `modelo_final.json`

Contiene la definición del modelo creado con Neo4j Data Importer.

Incluye información sobre:

- tipos de nodos;
- tipos de relaciones;
- propiedades;
- identificadores principales;
- dirección de las relaciones;
- archivos CSV asociados;
- mapeo entre columnas de los CSV y propiedades del grafo.

Este archivo funciona como la fuente de definición del modelo utilizada por el proceso de carga automatizado.

El JSON no se almacena directamente dentro de Neo4j.

`importar_datos.py` interpreta su contenido y construye el grafo correspondiente dentro de la instancia.

---

## `importar_datos.py`

Automatiza la carga de datos hacia la instancia de Neo4j.

El script:

1. Lee las variables de conexión desde `.env`.
2. Lee `modelo_final.json`.
3. Obtiene las etiquetas de nodos, relaciones, propiedades y llaves.
4. Lee los archivos CSV ubicados en `data/`.
5. Crea restricciones de unicidad.
6. Inserta los nodos.
7. Inserta las relaciones.
8. Muestra un resumen final de la carga.

Después de una carga completa se espera obtener:

```text
12 500 nodos
66 007 relaciones
```

---

## `Consultas Neo4j/`

Contiene las consultas Cypher de los requisitos 2, 3, 6 y 7. Cada carpeta tiene un `.txt` con las consultas comentadas línea por línea y el tiempo de respuesta de cada una, junto con los resultados exportados (`.json`) y las visualizaciones (`.svg`). Ver la sección [Consultas](#consultas).

---

## `Consultas en SQL/`

Contiene la versión relacional (SQL Server) de los mismos datos y las consultas 2, 3, 6 y 7 escritas con JOINs, para compararlas con Neo4j. Ver la sección [Comparación con el modelo relacional](#comparación-con-el-modelo-relacional).

---

## `centralidad.ipynb`

Notebook utilizado para realizar los análisis con Neo4j Graph Data Science.

Incluye:

```text
PageRank
Louvain
Ranking de cuentas
Ranking de comunidades
Visualizaciones
Explicación matemática
Interpretación de resultados
```

El notebook se conecta a la misma instancia de Neo4j ejecutada mediante Docker.

También puede verificar si los datos ya existen antes de ejecutar la carga automática.

---

# Prerrequisitos

Para ejecutar el proyecto se requiere:

- Docker Desktop
- Python 3
- Jupyter Notebook
- R
- Git
- Neo4j Graph Data Science
- Acceso a una terminal como PowerShell, CMD o terminal integrada de VS Code

Para la comparación con el modelo relacional (opcional) se requiere además:

- SQL Server (por ejemplo, SQL Server Express)
- SQL Server Management Studio (SSMS)

También es necesario contar con las siguientes bibliotecas de Python:

```text
neo4j
python-dotenv
graphdatascience
pandas
matplotlib
```

---

# Instalación

## 1. Clonar o descargar el proyecto

Ubicarse en la carpeta raíz del repositorio.

Ejemplo:

```bash
cd Caso4_FraudeLink
```

## 2. Instalar dependencias de Python

Ejecutar:

```bash
python -m pip install neo4j python-dotenv graphdatascience pandas matplotlib
```

## 3. Configurar `.env`

Copiar el archivo de ejemplo:

```bash
cp .env.example .env
```

En Windows (CMD):

```bash
copy .env.example .env
```

Luego abrir `.env` y cambiar `NEO4J_PASSWORD` por una contraseña propia:

```env
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=cambiar_por_una_contraseña
```

`docker-compose.yml` crea la instancia de Neo4j con esa misma contraseña, así que no hace falta escribirla en ningún otro archivo.

## 4. Iniciar Docker Desktop

Docker Desktop debe estar abierto y funcionando antes de iniciar la instancia.

## 5. Levantar Neo4j

Ejecutar:

```bash
docker compose up -d
```

Verificar que el contenedor esté activo:

```bash
docker ps
```

Neo4j Browser queda disponible en:

```text
http://localhost:7474
```

---

# Carga de datos

La carga de datos se divide en dos partes:

```text
generación de CSV
+
importación a Neo4j
```

## Generación de datos

Si la carpeta `data/` todavía no contiene los CSV, ejecutar:

```bash
Rscript creacion.datos.R
```

Este script genera los nodos y relaciones y guarda los archivos en:

```text
data/
```

Los archivos esperados incluyen:

```text
clientes.csv
cuentas.csv
dispositivos.csv
ips.csv
comercios.csv
posee.csv
usa_dispositivo.csv
conecta_desde.csv
paga_en.csv
transfiere_a.csv
```

## Importación hacia Neo4j

Ejecutar:

```bash
python importar_datos.py
```

El script utiliza:

```text
modelo_final.json
+
data/*.csv
```

para construir automáticamente el grafo dentro de la instancia de Neo4j.

El flujo es:

```text
creacion.datos.R
        ↓
     data/*.csv
        ↓
 modelo_final.json
        ↓
 importar_datos.py
        ↓
    Neo4j Docker
```

---

# Ejecución

Una vez que la instancia está activa y los datos están cargados, abrir:

```text
centralidad.ipynb
```

Ejecutar las celdas en orden.

El notebook utiliza la conexión definida en `.env`.

El flujo general del análisis es:

```text
Neo4j Docker
      ↓
centralidad.ipynb
      ↓
Proyección GDS
      ↓
PageRank
      ↓
Ranking de cuentas
      ↓
Louvain
      ↓
Ranking de comunidades
```

---

# Centralidad con PageRank

PageRank se utiliza para identificar cuentas con una posición estructural relevante dentro del grafo.

El algoritmo no considera únicamente cuántas conexiones tiene un nodo.

También considera la importancia de los nodos desde los cuales recibe conexiones.

Una forma simplificada de representar PageRank es:

$$
PR(v) =
(1-d)
+
d
\sum_{u \in In(v)}
\frac{PR(u)}{L(u)}
$$

donde:

- \(PR(v)\) representa el PageRank del nodo analizado.
- \(d\) representa el factor de amortiguación.
- \(In(v)\) representa los nodos que apuntan hacia \(v\).
- \(PR(u)\) representa la importancia del nodo de origen.
- \(L(u)\) representa la cantidad de conexiones salientes del nodo de origen.

El notebook crea una proyección temporal del grafo en memoria mediante GDS.

Esta proyección no modifica ni duplica los datos almacenados físicamente en Neo4j.

Después se ejecuta PageRank y se genera un ranking de las cuentas con mayor puntuación.

Un PageRank alto no representa automáticamente fraude.

Indica que una cuenta ocupa una posición estructuralmente relevante dentro de la red y puede ser priorizada para un análisis posterior.

---

# Detección de comunidades con Louvain

Después del análisis de centralidad se utiliza el algoritmo Louvain.

Louvain permite identificar grupos de cuentas que presentan una mayor concentración de conexiones entre sí que con el resto del grafo.

Para este análisis se crea una proyección independiente:

```text
fraudelink_comunidades
```

La proyección utiliza únicamente:

```text
Cuenta
TRANSFIERE_A
```

Las relaciones se proyectan como:

```text
UNDIRECTED
```

porque para la detección de comunidades interesa principalmente conocer qué cuentas se encuentran conectadas entre sí.

La proyección genera:

```text
5 000 nodos
60 014 relaciones proyectadas
```

Los 5 000 nodos corresponden a las cuentas existentes.

En la base existen:

```text
30 007 relaciones TRANSFIERE_A
```

Al utilizar orientación no dirigida, GDS representa internamente cada conexión en ambos sentidos:

```text
30 007 × 2 = 60 014
```

Esto ocurre únicamente dentro de la proyección temporal de GDS.

No duplica las relaciones almacenadas en Neo4j.

---

## Funcionamiento de Louvain

Louvain intenta maximizar una medida denominada modularidad.

La modularidad puede expresarse como:

$$
Q =
\frac{1}{2m}
\sum_{i,j}
\left(
A_{ij}
-
\frac{k_i k_j}{2m}
\right)
\delta(c_i,c_j)
$$

donde:

- \(A_{ij}\) representa la conexión entre los nodos \(i\) y \(j\).
- \(k_i\) y \(k_j\) representan el grado de ambos nodos.
- \(m\) representa la cantidad total de relaciones.
- \(c_i\) y \(c_j\) representan las comunidades asignadas.
- \(\delta(c_i,c_j)\) vale 1 cuando ambos nodos pertenecen a la misma comunidad.

Louvain agrupa nodos intentando aumentar la modularidad del grafo.

Cada cuenta recibe un:

```text
communityId
```

que identifica la comunidad a la que pertenece.

Este número es únicamente un identificador.

No representa un nivel de riesgo.

---

## Ranking de comunidades

Después de ejecutar Louvain, las cuentas se agrupan según su `communityId`.

Para cada comunidad se obtiene:

```text
communityId
cantidad_cuentas
muestra_cuentas
```

La columna:

```text
muestra_cuentas
```

contiene algunas cuentas de referencia pertenecientes a la comunidad.

Por ejemplo:

```text
communityId: 421
cantidad_cuentas: 348
muestra_cuentas: [CTA00001, CTA00003, CTA00015, ...]
```

Esto significa que la comunidad tiene 348 cuentas en total.

La muestra contiene solamente algunas cuentas para facilitar la lectura.

No representa las cuentas más importantes ni las más sospechosas.

---

# Relación entre PageRank y Louvain

PageRank y Louvain analizan características diferentes del mismo grafo.

## PageRank

Responde a la pregunta:

> ¿Qué cuentas tienen mayor importancia estructural dentro de la red?

El resultado es un ranking de nodos.

## Louvain

Responde a la pregunta:

> ¿Qué cuentas forman grupos fuertemente relacionados entre sí?

El resultado es una agrupación de cuentas en comunidades.

Los dos algoritmos son complementarios.

Una cuenta con PageRank elevado puede analizarse dentro de la comunidad a la que pertenece.

Esto permite pasar de:

```text
identificar una cuenta relevante
```

a:

```text
analizar la red a la que pertenece
```

Ni PageRank ni Louvain constituyen por sí mismos una prueba de fraude.

Los resultados pueden combinarse posteriormente con otros indicadores como:

```text
ciclos de transferencias
montos
fechas
dispositivos compartidos
direcciones IP compartidas
```

---

# Consultas

Las consultas de detección están en la carpeta `Consultas Neo4j/`, una subcarpeta por requisito. Se ejecutan en Neo4j Browser (`http://localhost:7474`) copiando **una consulta a la vez** desde el `.txt`. Cada consulta está comentada línea por línea y tiene anotado su tiempo de respuesta.

| Req. | Carpeta | Consulta | Qué detecta | Resultado clave | Tiempo |
|---|---|---|---|---|---|
| 2 | `Consulta 2/` | 2a | Dispositivos usados por varios clientes distintos | DIS00771 es usado por 14 clientes | 5 947 ms |
| 2 | `Consulta 2/` | 2b | IPs usadas por varios clientes distintos | 10.0.0.79 es usada por 19 clientes | 1 196 ms |
| 2 | `Consulta 2/` | 2c | Cuentas de dueños distintos que comparten dispositivo **e** IP | 47 parejas de cuentas | 2 797 ms |
| 3 | `Consulta 3/` | 3a | Cualquier ciclo de 3 a 4 transferencias que salga y vuelva a CTA00001, sin filtros (vista Graph) | 2 ciclos, entre ellos CTA00001 → CTA00002 → CTA00003 → CTA00001 | 507 ms |
| 3 | `Consulta 3/` | 3b | Ciclos sospechosos en todo el grafo: fechas en orden y montos que bajan como máximo un 10 % en cada salto | 2 ciclos: CTA00001→00002→00003 y CTA00010→00011→00012→00013 | 4 275 ms |
| 6 | `Consultas 6/` | 6a | Ruta del dinero entre dos cuentas sospechosas, respetando el orden de las fechas | CTA00010 → CTA01551 → CTA00476 → CTA01218 (intermediarios: CTA01551 y CTA00476) | 573 ms |
| 6 | `Consultas 6/` | 6b / 6c | Camino más corto entre CTA00001 y CTA01544 por cualquier vínculo (tabla y vista Graph) | 4 saltos | 513 ms |
| 7 | `Consultas 7/` | Ranking | Puntaje de riesgo que combina estructura (ciclo, dispositivo e IP compartidos) y propiedades (monto recibido desde agosto 2026) | CTA00013 es la cuenta más riesgosa (65 puntos) | 8 238 ms |
| 7 | `Consultas 7/` | Grafo / V4 | Vecindario de las cuentas más riesgosas (vista Graph) | — | 6 195 ms / 762 ms |

## Por qué importan estos patrones

- **Dispositivos e IP compartidos (req. 2):** varias identidades distintas operando desde el mismo equipo o red sugieren cuentas controladas por una misma persona (cuentas "mula" o identidades falsas).
- **Ciclos de transferencias (req. 3):** el dinero que sale de una cuenta, pasa por varias y vuelve al origen con montos levemente menores es un patrón típico de lavado de dinero (*layering*). No se ve mirando cada transacción por separado, solo al recorrer la cadena completa.
- **Caminos entre cuentas sospechosas (req. 6):** muestran por dónde pasa el dinero y qué cuentas actúan como intermediarias, aunque no tengan una relación directa.
- **Puntaje de riesgo (req. 7):** combina la estructura del grafo con las propiedades de las relaciones para priorizar qué cuentas revisar primero.

Las consultas del requisito 7 usan el criterio de ciclo de la consulta 3b: una cuenta suma 40 puntos si está en un ciclo sospechoso, hasta 25 si usa un dispositivo compartido por muchos clientes, hasta 15 si usa una IP compartida y hasta 20 según el monto recibido desde agosto de 2026. Con 60 puntos o más el nivel es ALTO.

---

# Comparación con el modelo relacional

Para comparar el grafo con un enfoque relacional tradicional, la carpeta `Consultas en SQL/` contiene los mismos datos en tablas de SQL Server y las consultas 2, 3, 6 y 7 escritas con JOINs, para compararlas con sus versiones en Cypher de la carpeta `Consultas Neo4j/`.

## Cómo ejecutarlo (SQL Server Management Studio)

1. Ejecutar en orden los archivos de `Consultas en SQL/`, cada uno completo con F5:
   - `1_tablas_y_nodos.sql`: crea la base `FraudeLink`, las tablas y los nodos. Al final debe dar **12 500**.
   - `2_relaciones.sql`: carga Posee, Usa_Dispositivo y Conecta_Desde. Debe dar **21 000**.
   - `3_transferencias.sql`: carga Transfiere_A. Debe dar **30 007**.
   - `4_pagos_e_indices.sql`: carga Paga_En y crea los índices. Debe dar **12 500 nodos y 66 007 relaciones**.
2. En `Consultas en SQL/Consultas.sql`, ejecutar una consulta a la vez. El tiempo aparece en la pestaña **Mensajes** como `elapsed time = X ms`.

Cada tipo de nodo del grafo es una tabla, y cada tipo de relación es otra tabla con dos llaves foráneas. Las tablas de relación tienen índices en sus llaves, que es lo que tendría un diseño relacional razonable, para que la comparación sea justa.

## Ambos motores dan el mismo resultado

| Consulta | Resultado (Neo4j y SQL) |
|---|---|
| 2a | DIS00771 es el dispositivo con más clientes distintos: 14 |
| 2b | 10.0.0.79 es la IP con más clientes distintos: 19 |
| 2c | 47 parejas de cuentas de dueños distintos comparten dispositivo e IP |
| 3b | 2 ciclos: CTA00001→00002→00003→00001 y CTA00010→00011→00012→00013→00010 |
| 6a | Ruta cronológica CTA00010→CTA01551→CTA00476→CTA01218 (3 saltos) |
| 6b | CTA00001 y CTA01544 están a 4 saltos por cualquier vínculo |
| 7 | Mismo top 20; CTA00013 en primer lugar con 65 puntos |

## Complejidad de las consultas

| Consulta | JOINs en SQL | Qué complica a SQL |
|---|---|---|
| 2a | 1 | Nada: es una agregación simple |
| 2b | 1 | Nada: es una agregación simple |
| 2c | 5 | Hay que unir la misma tabla consigo misma por dispositivo y por IP |
| 3b | 5 + UNION | Una consulta **por cada longitud** de ciclo (3 y 4 saltos). Un ciclo de 5 saltos exige otra consulta más |
| 6a | 1 (recursivo) | Hace falta una CTE recursiva que arrastre la ruta como texto |
| 6b | 8 UNION + ciclo WHILE | Los 4 tipos de vínculo están en 4 tablas: hay que juntarlas en una lista y recorrerla nivel por nivel |
| 7 | 13 | Ciclos, dispositivos, IP y montos son subconsultas separadas que luego se unen |

En Cypher la longitud del recorrido es solo un número (`*3..4`, `*1..6`) y los distintos tipos de relación van en el mismo patrón (`[:TRANSFIERE_A|USA_DISPOSITIVO|CONECTA_DESDE|POSEE]`). En SQL cada salto es un JOIN más y cada tipo de relación es otra tabla.

## Tiempos (ms)

| Consulta | Neo4j | SQL Server | Más rápido |
|---|---|---|---|
| 2a | 5 947 | 79 | SQL Server |
| 2b | 1 196 | 58 | SQL Server |
| 2c | 2 797 | 1 089 | SQL Server |
| 3b | 4 275 | 1 173 | SQL Server |
| 6a | 573 | 99 | SQL Server |
| 6b | 513 | 1 180 | **Neo4j** |
| 7 | 8 238 | 2 532 | SQL Server |

Los tiempos de Neo4j son el valor "completed after" de Neo4j Browser, y están anotados también en los `.txt` de la carpeta `Consultas Neo4j`. Los de SQL Server son el `elapsed time` de la pestaña Mensajes de SSMS (sin contar el tiempo de compilación). En la 6b, que tiene varios pasos, es la suma de todos sus pasos. Los tiempos de SQL Server también están anotados debajo de cada consulta en `Consultas en SQL/Consultas.sql`.

## Lectura de los resultados

- **Con este volumen de datos, SQL Server fue más rápido en 6 de las 7 consultas.** Con 12 500 nodos y 66 007 relaciones todo cabe en memoria, y con índices en las llaves los JOIN son baratos. La ventaja de velocidad del grafo no aparece a esta escala.
- **La única consulta donde Neo4j ganó fue la 6b (513 ms contra 1 180 ms).** Es justamente la que recorre el grafo por cualquier tipo de vínculo. En SQL hay que juntar primero las 4 tablas de relaciones en una sola lista de más de 100 000 conexiones y después recorrerla nivel por nivel. Neo4j solo sigue las relaciones de los nodos que va visitando.
- **La diferencia a favor del grafo está en escribir y mantener las consultas de varios saltos.** La 2c necesita 5 JOINs, la 3b necesita una consulta distinta por cada longitud de ciclo y la 7 necesita 13 JOINs. En Cypher cada una es un patrón, y la longitud del recorrido es solo un número (`*3..4`). Un ciclo de 5 saltos en SQL exige escribir otra consulta completa; en Cypher basta cambiar `*3..4` por `*3..5`.
- **Se espera que la diferencia cambie con más datos o recorridos más largos**, porque cada JOIN adicional multiplica las combinaciones que SQL tiene que revisar, mientras que Neo4j solo sigue las relaciones de los nodos que visita. La 6b ya muestra esa tendencia. Esto no se midió con volúmenes mayores en este proyecto.
- **Limitaciones:** los tiempos vienen de una sola ejecución en cada interfaz gráfica (Neo4j Browser y SSMS). Los tiempos de Neo4j incluyen el envío de resultados a la interfaz de visualización, y no se midieron en la misma computadora ni con el mismo método que los de SQL Server, así que la comparación de velocidad es aproximada.

---

# Pruebas

Las pruebas permiten comprobar que la instancia y los datos fueron cargados correctamente.

## Verificar cantidad de nodos

En Neo4j Browser ejecutar:

```cypher
MATCH (n)
RETURN count(n) AS total_nodos;
```

Resultado esperado:

```text
12500
```

## Verificar cantidad de relaciones

Ejecutar:

```cypher
MATCH ()-[r]->()
RETURN count(r) AS total_relaciones;
```

Resultado esperado:

```text
66007
```

## Verificar nodos por tipo

```cypher
MATCH (n)
RETURN labels(n)[0] AS tipo, count(*) AS cantidad
ORDER BY tipo;
```

## Verificar relaciones por tipo

```cypher
MATCH ()-[r]->()
RETURN type(r) AS relacion, count(*) AS cantidad
ORDER BY relacion;
```

## Verificar el esquema

```cypher
CALL db.schema.visualization();
```

Con esto se comprueba visualmente que existen:

```text
Cliente
Cuenta
Dispositivo
IP
Comercio
```

y las relaciones:

```text
POSEE
USA_DISPOSITIVO
CONECTA_DESDE
TRANSFIERE_A
PAGA_EN
```

También se comprueba desde `centralidad.ipynb` que las proyecciones GDS puedan crearse y que PageRank y Louvain devuelvan resultados válidos.

## Verificar las consultas

Cada consulta de `Consultas Neo4j/` tiene un resultado esperado (ver la tabla de la sección [Consultas](#consultas)). Por ejemplo, la consulta 3b debe devolver exactamente 2 ciclos y la 7 debe mostrar CTA00013 en el primer lugar con 65 puntos.

## Verificar la versión relacional

Al final de `4_pagos_e_indices.sql` se ejecuta un conteo que debe dar:

```text
nodos: 12500
relaciones: 66007
```

Las consultas de `Consultas.sql` deben devolver los mismos resultados que sus equivalentes en Neo4j.

---

# Demostración

Durante la demostración se recomienda seguir este orden.

## 1. Mostrar la instancia

Abrir:

```text
http://localhost:7474
```

y comprobar que Neo4j se encuentra activo.

## 2. Mostrar el esquema

Ejecutar:

```cypher
CALL db.schema.visualization();
```

Esto permite visualizar las etiquetas y relaciones existentes.

## 3. Mostrar el volumen de datos

Ejecutar:

```cypher
MATCH (n)
RETURN count(n);
```

y:

```cypher
MATCH ()-[r]->()
RETURN count(r);
```

Resultados esperados:

```text
12 500 nodos
66 007 relaciones
```

## 4. Mostrar dispositivos e IP compartidos

Ejecutar la consulta 2a de `Consultas Neo4j/Consulta 2/` y mostrar que DIS00771 es usado por 14 clientes distintos.

## 5. Mostrar una consulta de varios saltos con detección de ciclos

Ejecutar la consulta 3a en vista Graph para ver los ciclos que salen y vuelven a CTA00001. Luego ejecutar la 3b, que revisa todo el grafo y deja solo los ciclos sospechosos (fechas en orden y montos que bajan poco a poco): quedan 2.

## 6. Mostrar el camino entre cuentas sospechosas

Ejecutar la 6a (visualización) de `Consultas Neo4j/Consultas 6/` para mostrar la ruta del dinero CTA00010 → CTA01551 → CTA00476 → CTA01218 y sus intermediarios.

## 7. Mostrar el ranking de riesgo

Ejecutar el ranking de `Consultas Neo4j/Consultas 7/` y luego la visualización V4 del vecindario de CTA00013, la cuenta con mayor riesgo.

## 8. Mostrar PageRank

Ejecutar las celdas correspondientes en `centralidad.ipynb`.

Mostrar:

- proyección del grafo;
- ejecución de PageRank;
- ranking de cuentas;
- gráfico de las cuentas principales;
- explicación del significado de PageRank.

## 9. Mostrar Louvain

Ejecutar las celdas correspondientes a comunidades.

Mostrar:

- proyección de cuentas;
- ejecución de Louvain;
- asignación de `communityId`;
- ranking de comunidades;
- gráfico de las comunidades principales.

## 10. Explicar la relación entre ambos algoritmos

La demostración puede cerrarse explicando:

```text
PageRank
    ↓
identifica cuentas relevantes

Louvain
    ↓
identifica las comunidades donde se encuentran
```

Esto permite combinar análisis individual y análisis estructural del grafo.

## 11. Comparar contra JOINs relacionales

Mostrar en SSMS una consulta de `Consultas en SQL/Consultas.sql`, por ejemplo la 3b, al lado de su versión en Cypher. Explicar que en SQL cada salto es un JOIN más y cada longitud de ciclo es otra consulta, y presentar la tabla de tiempos de la sección [Comparación con el modelo relacional](#comparación-con-el-modelo-relacional).

---

# Archivos de modelo

## `modelo_final.json`

Es el modelo utilizado actualmente como fuente de definición para la carga automatizada.

`importar_datos.py` utiliza este archivo para interpretar:

```text
nodos
relaciones
propiedades
llaves
CSV asociados
direcciones
```


---

# Tecnologías utilizadas

- Neo4j
- Neo4j Graph Data Science
- Docker
- Python
- Jupyter Notebook
- R
- Cypher
- Pandas
- Matplotlib
- SQL Server y SQL Server Management Studio (comparación relacional)