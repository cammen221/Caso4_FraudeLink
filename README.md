# Caso4 FraudeLink detección de patrones de riesgo con Neoj4

Descripción:
Proyecto del grupo 7. Representa clientes, cuentas, dispositivos, direcciones IP, comercios y transacciones como un grafo para explorar conexiones y posibles patrones de riesgo.


## 1. Nodos
|Elemento| Propiedades Claves|
|---|---|
|'Cliente'| 'cliente_id'|
|'Cuenta' | 'cuenta_id' |
|'Dispositivo'| 'dispositivo_id'|
|'IP' |'ip_address'|
|'Comercio'| 'comercio_id'|

## 2.Relaciones
|Relación| Dirección| Propiedades| Justificación|
|---|---|---|---|
|'POSEE'| 'cliente-cuenta'|'fecha'|'Un cliente puede tener varias cuentas'|
|'USA_DISPOSITIVO'|'cuenta-dispositivo'|'fecha o frecuencia'|'Dectectar un mismo dispositivo usado por diferentes cuentas'|
|'CONECTA_DESDE'|'cuenta-IP'|'fecha o frecuencia'|'Dectectar una misma IP usada por varias identidades distintas'|
|'TRANSFIERE_A'|'cuenta-cuenta'|'monto,fecha'|'Cuenta origen envia dinero a la cuenta destino'|
|'PAGA_EN'|'cuenta-comercio'|'monto,fecha'|'Cuenta paga al comercio. Se modela diferente a TRANSFIERE_A, el destino es una comercio, no otra cuenta'|
