

# importar_datos.py
import requests
from neo4j import GraphDatabase

# 1. Configurar la conexión a Neo4j
URI = "bolt://localhost:7687"
AUTH = ("neo4j", "tu_contraseña_aqui")

# 2. Obtener datos de la API de GitHub (Ejemplo: Colaboradores de un repo)
github_url = "https://github.com"
# Nota: Para repositorios privados o muchos datos, necesitarás un Token de GitHub
response = requests.get(github_url)
colaboradores = response.json()

# 3. Función para guardar los datos en Neo4j usando lenguaje Cypher
def guardar_en_grafo(tx, login, repo_name):
    query = """
    MERGE (u:User {username: $login})
    MERGE (r:Repository {name: $repo_name})
    MERGE (u)-[:CONTRIBUTED_TO]->(r)
    """
    tx.run(query, login=login, repo_name="mi-repositorio")

# 4. Ejecutar el proceso
with GraphDatabase.driver(URI, auth=AUTH) as driver:
    with driver.session() as session:
        for user in colaboradores:
            session.execute_write(guardar_en_grafo, user['login'], "mi-repositorio")

print("¡Datos de GitHub importados a Neo4j con éxito!")

