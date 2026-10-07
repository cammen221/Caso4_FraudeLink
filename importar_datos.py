import os
import csv
import json
from pathlib import Path

from dotenv import load_dotenv
from neo4j import GraphDatabase


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
MODELO_PATH = BASE_DIR / "modelo_final.json"

load_dotenv(BASE_DIR / ".env")

NEO4J_URI = os.getenv("NEO4J_URI")
NEO4J_USERNAME = os.getenv("NEO4J_USERNAME")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")

if not all([NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD]):
    raise RuntimeError(
        "Faltan NEO4J_URI, NEO4J_USERNAME o NEO4J_PASSWORD en .env"
    )


driver = GraphDatabase.driver(
    NEO4J_URI,
    auth=(NEO4J_USERNAME, NEO4J_PASSWORD)
)

driver.verify_connectivity()

print("✓ Conexión con Neo4j establecida")


# Cargar el modelo de Neo4j
with open(MODELO_PATH, "r", encoding="utf-8") as f:
    modelo = json.load(f)

data_model = modelo["dataModel"]

schema = data_model["graphSchemaRepresentation"]["graphSchema"]
mapping = data_model["graphMappingRepresentation"]
extensions = data_model["graphSchemaExtensionsRepresentation"]


# Propiedades definidas en el modelo
property_by_id = {}

for node_label in schema["nodeLabels"]:
    for prop in node_label.get("properties", []):
        property_by_id[prop["$id"]] = {
            "name": prop["token"],
            "type": prop["type"]["type"]
        }

for rel_type in schema["relationshipTypes"]:
    for prop in rel_type.get("properties", []):
        property_by_id[prop["$id"]] = {
            "name": prop["token"],
            "type": prop["type"]["type"]
        }


label_by_id = {
    x["$id"]: x["token"]
    for x in schema["nodeLabels"]
}

relationship_type_by_id = {
    x["$id"]: x["token"]
    for x in schema["relationshipTypes"]
}


# Relacionar los IDs internos con las etiquetas de los nodos
node_by_id = {}

for node in schema["nodeObjectTypes"]:
    label_ref = node["labels"][0]["$ref"].replace("#", "")
    node_by_id[node["$id"]] = label_by_id[label_ref]


# Obtener tipo, origen y destino de cada relación
relationship_by_id = {}

for rel in schema["relationshipObjectTypes"]:
    rel_type_ref = rel["type"]["$ref"].replace("#", "")
    from_ref = rel["from"]["$ref"].replace("#", "")
    to_ref = rel["to"]["$ref"].replace("#", "")

    relationship_by_id[rel["$id"]] = {
        "type": relationship_type_by_id[rel_type_ref],
        "from": node_by_id[from_ref],
        "to": node_by_id[to_ref]
    }


# Propiedad llave de cada tipo de nodo
node_keys = {}

for item in extensions["nodeKeyProperties"]:
    node_ref = item["node"]["$ref"].replace("#", "")
    label = node_by_id[node_ref]

    property_ref = (
        item["keyProperties"][0]["$ref"]
        .replace("#", "")
    )

    node_keys[label] = property_by_id[property_ref]["name"]


def read_csv(filename):
    path = DATA_DIR / filename

    if not path.exists():
        raise FileNotFoundError(
            f"No existe el archivo: {path}"
        )

    with open(
        path,
        "r",
        encoding="utf-8-sig",
        newline=""
    ) as f:
        return list(csv.DictReader(f))


def execute_batches(query, rows, batch_size=1000):
    total = len(rows)

    with driver.session() as session:
        for start in range(0, total, batch_size):
            batch = rows[start:start + batch_size]

            session.run(
                query,
                rows=batch
            ).consume()

            processed = min(start + batch_size, total)

            print(f"   {processed}/{total}")


def cypher_value(field, property_type):
    if property_type == "float":
        return f"toFloat(row.`{field}`)"

    if property_type == "integer":
        return f"toInteger(row.`{field}`)"

    if property_type == "datetime":
        return f"datetime(row.`{field}`)"

    if property_type == "date":
        return f"date(row.`{field}`)"

    if property_type == "boolean":
        return f"toBoolean(row.`{field}`)"

    return f"row.`{field}`"


print("\n========== CONSTRAINTS ==========")

with driver.session() as session:
    for label, key_property in node_keys.items():
        constraint_name = f"{label}_{key_property}_unique"

        query = f"""
        CREATE CONSTRAINT `{constraint_name}`
        IF NOT EXISTS
        FOR (n:`{label}`)
        REQUIRE n.`{key_property}` IS UNIQUE
        """

        session.run(query).consume()

        print(f"✓ {label}.{key_property}")


print("\n========== NODOS ==========")

for node_mapping in mapping["nodeMappings"]:
    node_ref = (
        node_mapping["node"]["$ref"]
        .replace("#", "")
    )

    label = node_by_id[node_ref]
    filename = node_mapping["tableName"]
    key_property = node_keys[label]

    mappings = []

    for pm in node_mapping["propertyMappings"]:
        field = pm["fieldName"]

        property_ref = (
            pm["property"]["$ref"]
            .replace("#", "")
        )

        property_info = property_by_id[property_ref]

        mappings.append({
            "field": field,
            "property": property_info["name"],
            "type": property_info["type"]
        })

    key_mapping = next(
        x for x in mappings
        if x["property"] == key_property
    )

    query = f"""
    UNWIND $rows AS row

    MERGE (n:`{label}` {{
        `{key_property}`:
        {cypher_value(key_mapping["field"], key_mapping["type"])}
    }})
    """

    set_expressions = []

    for item in mappings:
        if item["property"] == key_property:
            continue

        set_expressions.append(
            f"""
            n.`{item["property"]}` =
            {cypher_value(item["field"], item["type"])}
            """
        )

    if set_expressions:
        query += "\nSET " + ",".join(set_expressions)

    rows = read_csv(filename)

    print(f"\n{filename} -> :{label}")

    execute_batches(query, rows)

    print(f"✓ {label} terminado")


print("\n========== RELACIONES ==========")

for rel_mapping in mapping["relationshipMappings"]:
    relationship_ref = (
        rel_mapping["relationship"]["$ref"]
        .replace("#", "")
    )

    rel_info = relationship_by_id[relationship_ref]

    rel_type = rel_info["type"]
    from_label = rel_info["from"]
    to_label = rel_info["to"]

    filename = rel_mapping["tableName"]

    from_key = node_keys[from_label]
    to_key = node_keys[to_label]

    from_field = list(
        rel_mapping["fromMappings"].values()
    )[0]

    to_field = list(
        rel_mapping["toMappings"].values()
    )[0]

    properties = []

    for pm in rel_mapping.get(
        "propertyMappings",
        []
    ):
        field = pm["fieldName"]

        property_ref = (
            pm["property"]["$ref"]
            .replace("#", "")
        )

        property_info = property_by_id[property_ref]

        properties.append({
            "field": field,
            "property": property_info["name"],
            "type": property_info["type"]
        })

    properties_cypher = []

    for prop in properties:
        value = cypher_value(
            prop["field"],
            prop["type"]
        )

        properties_cypher.append(
            f"`{prop['property']}`: {value}"
        )

    relationship_properties = ", ".join(
        properties_cypher
    )

    query = f"""
    UNWIND $rows AS row

    MATCH (from:`{from_label}` {{
        `{from_key}`: row.`{from_field}`
    }})

    MATCH (to:`{to_label}` {{
        `{to_key}`: row.`{to_field}`
    }})

    MERGE (from)-[r:`{rel_type}` {{
        {relationship_properties}
    }}]->(to)
    """

    rows = read_csv(filename)

    print(
        f"\n{filename}"
        f" -> (:{from_label})"
        f"-[:{rel_type}]->"
        f"(:{to_label})"
    )

    execute_batches(query, rows)

    print(f"{rel_type} terminado")


print("\n========== RESULTADO ==========")

with driver.session() as session:
    print("\nNodos:")

    result = session.run("""
    MATCH (n)
    RETURN labels(n)[0] AS tipo,
           count(*) AS cantidad
    ORDER BY tipo
    """)

    total_nodes = 0

    for row in result:
        cantidad = row["cantidad"]
        total_nodes += cantidad

        print(
            f"  {row['tipo']}: {cantidad}"
        )

    print(f"  TOTAL: {total_nodes}")

    print("\nRelaciones:")

    result = session.run("""
    MATCH ()-[r]->()
    RETURN type(r) AS tipo,
           count(*) AS cantidad
    ORDER BY tipo
    """)

    total_relationships = 0

    for row in result:
        cantidad = row["cantidad"]
        total_relationships += cantidad

        print(
            f"  {row['tipo']}: {cantidad}"
        )

    print(f"  TOTAL: {total_relationships}")


driver.close()

print("\n✓ Importación automática finalizada")