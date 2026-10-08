
-- Estas son las consultas que se realizaron en Neo4j--

-- Se preparan los archivos para realizar las consultas--
USE FraudeLink;
SET STATISTICS TIME ON;   
GO

-- Consulta 2.a. Dispositivos compartidos por varios clientes.--
USE FraudeLink;               
SET STATISTICS TIME ON;         
SELECT TOP 20 u.dispositivo_id, COUNT(DISTINCT p.cliente_id) AS n_clientes
FROM Usa_Dispositivo u
JOIN Posee p ON p.cuenta_id = u.cuenta_id
GROUP BY u.dispositivo_id
HAVING COUNT(DISTINCT p.cliente_id) >= 2
ORDER BY n_clientes DESC;
GO

-- Duración: 79 ms--

-- Consulta 2.b. IP's compartidas por varios clientes--
USE FraudeLink;                 
SET STATISTICS TIME ON;        
SELECT TOP 20 c.ip_address, COUNT(DISTINCT p.cliente_id) AS n_clientes
FROM Conecta_Desde c
JOIN Posee p ON p.cuenta_id = c.cuenta_id
GROUP BY c.ip_address
HAVING COUNT(DISTINCT p.cliente_id) >= 2
ORDER BY n_clientes DESC;
GO

-- Duración: 58 ms--

-- Consulta 2.c. Cuentas que tinen distintos dueños y comparten una misma IP--
USE FraudeLink;                 
SET STATISTICS TIME ON;         
SELECT TOP 50 u1.cuenta_id AS cuenta_1, u2.cuenta_id AS cuenta_2
FROM Usa_Dispositivo u1
JOIN Usa_Dispositivo u2 ON u2.dispositivo_id = u1.dispositivo_id  
                       AND u1.cuenta_id < u2.cuenta_id            
JOIN Conecta_Desde c1   ON c1.cuenta_id = u1.cuenta_id            
JOIN Conecta_Desde c2   ON c2.cuenta_id = u2.cuenta_id           
                       AND c2.ip_address = c1.ip_address      
JOIN Posee p1           ON p1.cuenta_id = u1.cuenta_id            
JOIN Posee p2           ON p2.cuenta_id = u2.cuenta_id            
WHERE p1.cliente_id <> p2.cliente_id                              
GROUP BY u1.cuenta_id, u2.cuenta_id
ORDER BY cuenta_1, cuenta_2;

GO

-- Duración: 1089 ms--

-- Consulta 3.b. Ciclos de transferencia de 3 y 4 ciclos--
USE FraudeLink;                 
SET STATISTICS TIME ON;         
SELECT t1.cuenta_origen AS c1, t2.cuenta_origen AS c2, t3.cuenta_origen AS c3,
       NULL AS c4, 3 AS saltos
FROM Transfiere_A t1
JOIN Transfiere_A t2 ON t2.cuenta_origen = t1.cuenta_destino
     AND t2.fecha > t1.fecha AND t2.monto < t1.monto AND t2.monto >= 0.9 * t1.monto
JOIN Transfiere_A t3 ON t3.cuenta_origen = t2.cuenta_destino
     AND t3.cuenta_destino = t1.cuenta_origen                      
     AND t3.fecha > t2.fecha AND t3.monto < t2.monto AND t3.monto >= 0.9 * t2.monto
WHERE t2.cuenta_origen <> t3.cuenta_origen
  AND t1.cuenta_origen < t2.cuenta_origen AND t1.cuenta_origen < t3.cuenta_origen 
UNION ALL

SELECT t1.cuenta_origen, t2.cuenta_origen, t3.cuenta_origen, t4.cuenta_origen, 4
FROM Transfiere_A t1
JOIN Transfiere_A t2 ON t2.cuenta_origen = t1.cuenta_destino
     AND t2.fecha > t1.fecha AND t2.monto < t1.monto AND t2.monto >= 0.9 * t1.monto
JOIN Transfiere_A t3 ON t3.cuenta_origen = t2.cuenta_destino
     AND t3.fecha > t2.fecha AND t3.monto < t2.monto AND t3.monto >= 0.9 * t2.monto
JOIN Transfiere_A t4 ON t4.cuenta_origen = t3.cuenta_destino
     AND t4.cuenta_destino = t1.cuenta_origen
     AND t4.fecha > t3.fecha AND t4.monto < t3.monto AND t4.monto >= 0.9 * t3.monto
WHERE t1.cuenta_origen <> t3.cuenta_origen
  AND t2.cuenta_origen <> t3.cuenta_origen AND t2.cuenta_origen <> t4.cuenta_origen
  AND t3.cuenta_origen <> t4.cuenta_origen
  AND t1.cuenta_origen < t2.cuenta_origen AND t1.cuenta_origen < t3.cuenta_origen
  AND t1.cuenta_origen < t4.cuenta_origen;
GO

-- Duración: 1173 ms--

-- Consulta 6.a. Ruta del dinero entre dos cuentas (CTA00010 y CTA01218)--
USE FraudeLink;                 
SET STATISTICS TIME ON;         
WITH ruta (cuenta, ultima_fecha, saltos, camino) AS (
    SELECT CAST('CTA00010' AS VARCHAR(10)), CAST('1900-01-01' AS DATE), 0,
           CAST('CTA00010' AS VARCHAR(200))                        
  UNION ALL
    SELECT t.cuenta_destino, t.fecha, r.saltos + 1,
           CAST(r.camino + ' > ' + t.cuenta_destino AS VARCHAR(200)) 
    FROM ruta r
    JOIN Transfiere_A t ON t.cuenta_origen = r.cuenta
                       AND t.fecha > r.ultima_fecha                
    WHERE r.saltos < 6 AND r.cuenta <> 'CTA01218'
)
SELECT TOP 1 camino, saltos
FROM ruta
WHERE cuenta = 'CTA01218'
ORDER BY saltos;
GO

-- Duración: 99 ms--

-- Consulta 6.b. Distancia que hay entre las cuentas anteriores por cualquier vínculo--
USE FraudeLink;                
SET STATISTICS TIME ON;         
DROP TABLE IF EXISTS #aristas, #visitados;

SELECT a, b INTO #aristas FROM (
          SELECT cuenta_origen AS a, cuenta_destino AS b FROM Transfiere_A
    UNION ALL SELECT cuenta_destino, cuenta_origen FROM Transfiere_A
    UNION ALL SELECT cuenta_id, 'D:' + dispositivo_id FROM Usa_Dispositivo
    UNION ALL SELECT 'D:' + dispositivo_id, cuenta_id FROM Usa_Dispositivo
    UNION ALL SELECT cuenta_id, 'I:' + ip_address FROM Conecta_Desde
    UNION ALL SELECT 'I:' + ip_address, cuenta_id FROM Conecta_Desde
    UNION ALL SELECT cuenta_id, 'C:' + cliente_id FROM Posee
    UNION ALL SELECT 'C:' + cliente_id, cuenta_id FROM Posee
) AS todas;
CREATE INDEX ix_aristas ON #aristas(a);

CREATE TABLE #visitados (nodo VARCHAR(20) COLLATE DATABASE_DEFAULT PRIMARY KEY, distancia INT);
INSERT INTO #visitados VALUES ('CTA00001', 0);                     
DECLARE @nivel INT = 0;
WHILE @nivel < 8 AND NOT EXISTS (SELECT 1 FROM #visitados WHERE nodo = 'CTA01544')
BEGIN
    INSERT INTO #visitados (nodo, distancia)
    SELECT DISTINCT e.b, @nivel + 1                                
    FROM #visitados v
    JOIN #aristas e ON e.a = v.nodo
    WHERE v.distancia = @nivel
      AND NOT EXISTS (SELECT 1 FROM #visitados x WHERE x.nodo = e.b);  
    SET @nivel = @nivel + 1;
END;

SELECT distancia AS saltos FROM #visitados WHERE nodo = 'CTA01544';
DROP TABLE #aristas, #visitados;

GO

-- Duración: 1180 ms--

-- Consulta 7. Ranking de riesgo--
USE FraudeLink;                
SET STATISTICS TIME ON;         
WITH ciclos AS (                                   
    SELECT t1.cuenta_origen AS c1, t2.cuenta_origen AS c2, t3.cuenta_origen AS c3,
           CAST(NULL AS VARCHAR(10)) AS c4
    FROM Transfiere_A t1
    JOIN Transfiere_A t2 ON t2.cuenta_origen = t1.cuenta_destino
         AND t2.fecha > t1.fecha AND t2.monto < t1.monto AND t2.monto >= 0.9 * t1.monto
    JOIN Transfiere_A t3 ON t3.cuenta_origen = t2.cuenta_destino
         AND t3.cuenta_destino = t1.cuenta_origen
         AND t3.fecha > t2.fecha AND t3.monto < t2.monto AND t3.monto >= 0.9 * t2.monto
    WHERE t2.cuenta_origen <> t3.cuenta_origen
    UNION ALL
    SELECT t1.cuenta_origen, t2.cuenta_origen, t3.cuenta_origen, t4.cuenta_origen
    FROM Transfiere_A t1
    JOIN Transfiere_A t2 ON t2.cuenta_origen = t1.cuenta_destino
         AND t2.fecha > t1.fecha AND t2.monto < t1.monto AND t2.monto >= 0.9 * t1.monto
    JOIN Transfiere_A t3 ON t3.cuenta_origen = t2.cuenta_destino
         AND t3.fecha > t2.fecha AND t3.monto < t2.monto AND t3.monto >= 0.9 * t2.monto
    JOIN Transfiere_A t4 ON t4.cuenta_origen = t3.cuenta_destino
         AND t4.cuenta_destino = t1.cuenta_origen
         AND t4.fecha > t3.fecha AND t4.monto < t3.monto AND t4.monto >= 0.9 * t3.monto
    WHERE t1.cuenta_origen <> t3.cuenta_origen
      AND t2.cuenta_origen <> t3.cuenta_origen AND t2.cuenta_origen <> t4.cuenta_origen
      AND t3.cuenta_origen <> t4.cuenta_origen
),
en_ciclo AS (                                      
    SELECT c1 AS cuenta_id FROM ciclos UNION SELECT c2 FROM ciclos
    UNION SELECT c3 FROM ciclos UNION SELECT c4 FROM ciclos WHERE c4 IS NOT NULL
),
clientes_por_disp AS (                             
    SELECT u.dispositivo_id, COUNT(DISTINCT p.cliente_id) AS n
    FROM Usa_Dispositivo u JOIN Posee p ON p.cuenta_id = u.cuenta_id
    GROUP BY u.dispositivo_id
),
max_disp AS (                                     
    SELECT u.cuenta_id, MAX(cd.n) AS n
    FROM Usa_Dispositivo u JOIN clientes_por_disp cd ON cd.dispositivo_id = u.dispositivo_id
    GROUP BY u.cuenta_id
),
clientes_por_ip AS (                              
    SELECT c.ip_address, COUNT(DISTINCT p.cliente_id) AS n
    FROM Conecta_Desde c JOIN Posee p ON p.cuenta_id = c.cuenta_id
    GROUP BY c.ip_address
),
max_ip AS (                                        
    SELECT c.cuenta_id, MAX(ci.n) AS n
    FROM Conecta_Desde c JOIN clientes_por_ip ci ON ci.ip_address = c.ip_address
    GROUP BY c.cuenta_id
),
montos AS (                                        
    SELECT cuenta_destino AS cuenta_id, SUM(monto) AS monto
    FROM Transfiere_A WHERE fecha >= '2026-08-01'
    GROUP BY cuenta_destino
)
SELECT TOP 20 cu.cuenta_id AS cuenta,
       (CASE WHEN ec.cuenta_id IS NOT NULL THEN 40 ELSE 0 END)
     + (CASE WHEN COALESCE(md.n,0) >= 9  THEN 25 WHEN COALESCE(md.n,0) >= 7  THEN 10 ELSE 0 END)
     + (CASE WHEN COALESCE(mi.n,0) >= 16 THEN 15 WHEN COALESCE(mi.n,0) >= 12 THEN 5  ELSE 0 END)
     + (CASE WHEN COALESCE(m.monto,0) >= 1000000 THEN 20
             WHEN COALESCE(m.monto,0) >= 500000  THEN 10 ELSE 0 END) AS riesgo,
       ROUND(COALESCE(m.monto,0), 0) AS monto_ultimo_mes
FROM Cuenta cu
LEFT JOIN en_ciclo ec ON ec.cuenta_id = cu.cuenta_id
LEFT JOIN max_disp md ON md.cuenta_id = cu.cuenta_id
LEFT JOIN max_ip   mi ON mi.cuenta_id = cu.cuenta_id
LEFT JOIN montos   m  ON m.cuenta_id  = cu.cuenta_id
ORDER BY riesgo DESC, monto_ultimo_mes DESC;

GO

-- Duración: 2532 ms--