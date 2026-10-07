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
10. [Pruebas](#pruebas)
11. [Demostración](#demostración)
12. [Consultas](#consultas)
13. [Archivos de modelo](#archivos-de-modelo)
14. [Tecnologías utilizadas](#tecnologías-utilizadas)

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

---

# Estructura del proyecto

```text
Caso4_FraudeLink/
│
├── .env
├── centralidad.ipynb
├── consultas_fraudelink_6y7.txt
├── creacion.datos.R
├── docker-compose.yml
├── importar_datos.py
├── modelo_final.json
├── neo4j_importer_model_2026-09-28.json
└── README.md
```

## `.env`

Contiene las variables de conexión utilizadas para acceder a Neo4j.

Ejemplo:

```env
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=contraseña
```

Este archivo contiene información local de conexión y no debe almacenarse con credenciales reales en repositorios públicos.

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

Crear o completar el archivo `.env`:

```env
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=contraseña
```

La contraseña debe coincidir con la utilizada por la instancia de Neo4j.

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

## 4. Mostrar PageRank

Ejecutar las celdas correspondientes en `centralidad.ipynb`.

Mostrar:

- proyección del grafo;
- ejecución de PageRank;
- ranking de cuentas;
- gráfico de las cuentas principales;
- explicación del significado de PageRank.

## 5. Mostrar Louvain

Ejecutar las celdas correspondientes a comunidades.

Mostrar:

- proyección de cuentas;
- ejecución de Louvain;
- asignación de `communityId`;
- ranking de comunidades;
- gráfico de las comunidades principales.

## 6. Explicar la relación entre ambos algoritmos

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

---

# Consultas

El proyecto contiene consultas Cypher adicionales para analizar relaciones y patrones presentes en el grafo.

Estas consultas se encuentran principalmente en:

```text
consultas_fraudelink_6y7.txt
```

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