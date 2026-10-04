-- [Pestaña 1] (final 4c, L12) la línea de crédito y un préstamo dados de alta por su número; la personal ····6611 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L12)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "2510", "monto": "-10000.00"}, {"cuenta": "2520", "monto": "-20000.00"}, {"cuenta": "3900", "monto": "-20000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "LOC ····8899", "filas": []}') ->> 'cuenta' as alta_loc;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2520", "ultimos4": "5521", "confirmo_cuenta": true, "nombre": "préstamo ····5521", "filas": []}') ->> 'cuenta' as alta_prestamo;
select fn_banco_cuenta_personal('6611', 'Ahorros personales de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] Chase: el pago a la línea (-1,000.00), su desembolso (+5,000.00), un pago al préstamo SIN cuota registrada (-750.00)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l12.csv", "filas": [
  {"id": "L1", "fecha": "2026-11-04", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO ACCT ...8899 TRANSACTION#: 1", "tipo": "XFER"},
  {"id": "L2", "fecha": "2026-11-05", "monto": "5000.00", "descripcion": "ONLINE TRANSFER FROM ACCT ...8899 TRANSACTION#: 2", "tipo": "XFER"},
  {"id": "L3", "fecha": "2026-11-06", "monto": "-750.00", "descripcion": "ONLINE TRANSFER TO ACCT ...5521 TRANSACTION#: 3", "tipo": "XFER"}],
  "saldo": "53250.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
