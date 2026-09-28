# Consultas – Requisitos 2 y 3

## Requisito 2: cuentas que comparten dispositivo o IP

### 2a. Dispositivos compartidos por varios clientes

``` cypher
MATCH (cl:Cliente)-[:POSEE]->(cu:Cuenta)-[:USA_DISPOSITIVO]->(d:Dispositivo)
WITH d, count(DISTINCT cl) AS n_clientes, collect(DISTINCT cu.cuenta_id) AS cuentas
WHERE n_clientes >= 2
RETURN d.dispositivo_id AS dispositivo, n_clientes, cuentas
ORDER BY n_clientes DESC
LIMIT 20;
```

### 2b. IPs compartidas por varios clientes

``` cypher
MATCH (cl:Cliente)-[:POSEE]->(cu:Cuenta)-[:CONECTA_DESDE]->(ip:IP)
WITH ip, count(DISTINCT cl) AS n_clientes, collect(DISTINCT cu.cuenta_id) AS cuentas
WHERE n_clientes >= 2
RETURN ip.ip_address AS ip, n_clientes, cuentas
ORDER BY n_clientes DESC
LIMIT 20;
```

### 2c. Cuentas que comparten dispositivo y además IP

``` cypher
MATCH (c1:Cliente)-[:POSEE]->(a1:Cuenta)-[:USA_DISPOSITIVO]->(d:Dispositivo)<-[:USA_DISPOSITIVO]-(a2:Cuenta)<-[:POSEE]-(c2:Cliente),
      (a1)-[:CONECTA_DESDE]->(ip:IP)<-[:CONECTA_DESDE]-(a2)
WHERE a1.cuenta_id < a2.cuenta_id AND c1 <> c2
RETURN a1.cuenta_id AS cuenta_1, a2.cuenta_id AS cuenta_2,
       collect(DISTINCT d.dispositivo_id) AS dispositivos,
       collect(DISTINCT ip.ip_address)    AS ips
LIMIT 50;
```

### 2d. Visualización del dispositivo más compartido

``` cypher
MATCH p = (cl:Cliente)-[:POSEE]->(cu:Cuenta)-[:USA_DISPOSITIVO]->(d:Dispositivo {dispositivo_id: 'DIS00771'})
RETURN p;
```

## Requisito 3: ciclos de transferencias de 3 o más saltos

### 3a. Ciclos desde una cuenta específica

``` cypher
MATCH p = (a:Cuenta {cuenta_id: 'CTA00001'})-[:TRANSFIERE_A*3..4]->(a)
RETURN p
LIMIT 10;
```

### 3b. Ciclos sospechosos en todo el grafo

``` cypher
MATCH p = (a:Cuenta)-[:TRANSFIERE_A*3..4]->(a)
WITH p, a, relationships(p) AS rs, nodes(p)[1..-1] AS internos
WHERE all(n IN internos WHERE single(m IN internos WHERE m = n))
  AND NOT a IN internos
  AND all(n IN internos WHERE a.cuenta_id < n.cuenta_id)
  AND all(i IN range(0, size(rs) - 2) WHERE
        rs[i].fecha < rs[i + 1].fecha
        AND rs[i + 1].monto < rs[i].monto
        AND rs[i + 1].monto >= rs[i].monto * 0.9)
RETURN [n IN nodes(p) | n.cuenta_id] AS ciclo,
       [r IN rs | r.monto] AS montos,
       size(rs) AS saltos;
```
