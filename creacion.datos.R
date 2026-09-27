
# CONFIGURACION GENERAL
set.seed(42)

# Crear carpeta de salida
dir.create("data", showWarnings = FALSE)

# Cantidad de nodos
n_clientes     <- 4000
n_cuentas      <- 5000
n_dispositivos <- 2000
n_ips          <- 1000
n_comercios    <- 500


# NODO CLIENTES
clientes <- data.frame(
  cliente_id = sprintf("CLI%05d", 1:n_clientes),
  stringsAsFactors = FALSE
)


# NODO CUENTAS
cuentas <- data.frame(
  cuenta_id = sprintf("CTA%05d", 1:n_cuentas),
  stringsAsFactors = FALSE
)



# NODO DISPOSITIVOS
dispositivos <- data.frame(
  dispositivo_id = sprintf("DIS%05d", 1:n_dispositivos),
  stringsAsFactors = FALSE
)


# NODO DIRECCIONES IP
# Se generan identificadores IP unicos para evitar crear
# accidentalmente dos nodos distintos con la misma direccion.

generar_ip <- function(i) {
  
  bloque2 <- floor((i - 1) / (254 * 254)) %% 254
  bloque3 <- floor((i - 1) / 254) %% 254
  bloque4 <- ((i - 1) %% 254) + 1
  
  paste(
    "10",
    bloque2,
    bloque3,
    bloque4,
    sep = "."
  )
}

ips <- data.frame(
  ip_address = sapply(1:n_ips, generar_ip),
  stringsAsFactors = FALSE
)


# COMERCIOS
comercios <- data.frame(
  comercio_id = sprintf("COM%05d", 1:n_comercios),
  stringsAsFactors = FALSE
)



# GENERACION DE RELACIONES


# Cada cuenta pertenece a un cliente. Algunos clientes pueden poseer mas de una cuenta.
posee <- data.frame(
  cliente_id = sample(
    clientes$cliente_id,
    n_cuentas,
    replace = TRUE
  ),
  
  cuenta_id = cuentas$cuenta_id,
  
  fecha = sample(
    seq.Date(
      as.Date("2020-01-01"),
      as.Date("2026-09-01"),
      by = "day"
    ),
    n_cuentas,
    replace = TRUE
  ),
  
  stringsAsFactors = FALSE
)


# Al existir menos dispositivos que cuentas, diferentes cuentas pueden utilizar el mismo dispositivo.
n_usa_dispositivo <- 8000

usa_dispositivo <- data.frame(
  cuenta_id = sample(
    cuentas$cuenta_id,
    n_usa_dispositivo,
    replace = TRUE
  ),
  
  dispositivo_id = sample(
    dispositivos$dispositivo_id,
    n_usa_dispositivo,
    replace = TRUE
  ),
  
  fecha = sample(
    seq.Date(
      as.Date("2025-01-01"),
      as.Date("2026-09-01"),
      by = "day"
    ),
    n_usa_dispositivo,
    replace = TRUE
  ),
  
  stringsAsFactors = FALSE
)


# Una misma IP puede ser utilizada por diferentes cuentas.
n_conecta_desde <- 8000

conecta_desde <- data.frame(
  cuenta_id = sample(
    cuentas$cuenta_id,
    n_conecta_desde,
    replace = TRUE
  ),
  
  ip_address = sample(
    ips$ip_address,
    n_conecta_desde,
    replace = TRUE
  ),
  
  fecha = sample(
    seq.Date(
      as.Date("2025-01-01"),
      as.Date("2026-09-01"),
      by = "day"
    ),
    n_conecta_desde,
    replace = TRUE
  ),
  
  stringsAsFactors = FALSE
)


# Cada transferencia contiene monto y fecha.
n_transferencias <- 30000

transfiere_a <- data.frame(
  cuenta_origen = sample(
    cuentas$cuenta_id,
    n_transferencias,
    replace = TRUE
  ),
  
  cuenta_destino = sample(
    cuentas$cuenta_id,
    n_transferencias,
    replace = TRUE
  ),
  
  monto = round(
    runif(
      n_transferencias,
      min = 1000,
      max = 1500000
    ),
    2
  ),
  
  fecha = sample(
    seq.Date(
      as.Date("2025-01-01"),
      as.Date("2026-09-01"),
      by = "day"
    ),
    n_transferencias,
    replace = TRUE
  ),
  
  stringsAsFactors = FALSE
)


# Evitar transferencias de una cuenta hacia si misma
mismo <- transfiere_a$cuenta_origen ==
  transfiere_a$cuenta_destino

while (any(mismo)) {
  
  transfiere_a$cuenta_destino[mismo] <- sample(
    cuentas$cuenta_id,
    sum(mismo),
    replace = TRUE
  )
  
  mismo <- transfiere_a$cuenta_origen ==
    transfiere_a$cuenta_destino
}


# INSERTAR CICLOS CONTROLADOS

ciclos_controlados <- data.frame(
  
  cuenta_origen = c(
    "CTA00001",
    "CTA00002",
    "CTA00003",
    
    "CTA00010",
    "CTA00011",
    "CTA00012",
    "CTA00013"
  ),
  
  cuenta_destino = c(
    "CTA00002",
    "CTA00003",
    "CTA00001",
    
    "CTA00011",
    "CTA00012",
    "CTA00013",
    "CTA00010"
  ),
  
  monto = c(
    750000,
    740000,
    730000,
    
    950000,
    940000,
    930000,
    920000
  ),
  
  fecha = as.Date(c(
    "2026-08-01",
    "2026-08-02",
    "2026-08-03",
    
    "2026-08-10",
    "2026-08-11",
    "2026-08-12",
    "2026-08-13"
  )),
  
  stringsAsFactors = FALSE
)

transfiere_a <- rbind(
  transfiere_a,
  ciclos_controlados
)

# Se ingresa el total de numero de pagos

n_pagos <- 15000

paga_en <- data.frame(
  cuenta_id = sample(
    cuentas$cuenta_id,
    n_pagos,
    replace = TRUE
  ),
  
  comercio_id = sample(
    comercios$comercio_id,
    n_pagos,
    replace = TRUE
  ),
  
  monto = round(
    runif(
      n_pagos,
      min = 500,
      max = 500000
    ),
    2
  ),
  
  fecha = sample(
    seq.Date(
      as.Date("2025-01-01"),
      as.Date("2026-09-01"),
      by = "day"
    ),
    n_pagos,
    replace = TRUE
  ),
  
  stringsAsFactors = FALSE
)


# VALIDACION DE NODOS
total_nodos <-
  nrow(clientes) +
  nrow(cuentas) +
  nrow(dispositivos) +
  nrow(ips) +
  nrow(comercios)


# VALIDACION DE RELACIONES
total_relaciones <-
  nrow(posee) +
  nrow(usa_dispositivo) +
  nrow(conecta_desde) +
  nrow(transfiere_a) +
  nrow(paga_en)


# VALIDACION DE IDENTIFICADORES UNICOS
stopifnot(
  !anyDuplicated(clientes$cliente_id),
  !anyDuplicated(cuentas$cuenta_id),
  !anyDuplicated(dispositivos$dispositivo_id),
  !anyDuplicated(ips$ip_address),
  !anyDuplicated(comercios$comercio_id)
)



# VALIDACION DE REFERENCIAS
stopifnot(
  all(posee$cliente_id %in% clientes$cliente_id),
  all(posee$cuenta_id %in% cuentas$cuenta_id),
  
  all(usa_dispositivo$cuenta_id %in% cuentas$cuenta_id),
  all(usa_dispositivo$dispositivo_id %in%
        dispositivos$dispositivo_id),
  
  all(conecta_desde$cuenta_id %in% cuentas$cuenta_id),
  all(conecta_desde$ip_address %in% ips$ip_address),
  
  all(transfiere_a$cuenta_origen %in% cuentas$cuenta_id),
  all(transfiere_a$cuenta_destino %in% cuentas$cuenta_id),
  
  all(paga_en$cuenta_id %in% cuentas$cuenta_id),
  all(paga_en$comercio_id %in% comercios$comercio_id)
)


# VALIDACION DE LOS MINIMOS DEL PROYECTO
if (total_nodos < 10000) {
  stop("ERROR: No se cumple el minimo de 10 000 nodos.")
}

if (total_relaciones < 50000) {
  stop("ERROR: No se cumple el minimo de 50 000 relaciones.")
}


# EXPORTACION DE LOS DATOS A CSV


# Nodos
write.csv(clientes,
          "data/clientes.csv",
          row.names = FALSE)

write.csv(cuentas,
          "data/cuentas.csv",
          row.names = FALSE)

write.csv(dispositivos,
          "data/dispositivos.csv",
          row.names = FALSE)

write.csv(ips,
          "data/ips.csv",
          row.names = FALSE)

write.csv(comercios,
          "data/comercios.csv",
          row.names = FALSE)


# Relaciones
write.csv(posee,
          "data/posee.csv",
          row.names = FALSE)

write.csv(usa_dispositivo,
          "data/usa_dispositivo.csv",
          row.names = FALSE)

write.csv(conecta_desde,
          "data/conecta_desde.csv",
          row.names = FALSE)

write.csv(transfiere_a,
          "data/transfiere_a.csv",
          row.names = FALSE)

write.csv(paga_en,
          "data/paga_en.csv",
          row.names = FALSE)


