-- [Pestaña 1] (4c) [e]: apertura, mapeos, las facturas #1101 y #1103 abiertas; el número de la línea de crédito (····8899) DADO DE ALTA con
-- su lote vacío a 2510, como aconseja la bandeja
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K2)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "2510", "monto": "-10000.00"}, {"cuenta": "3900", "monto": "-40000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "LOC ····8899", "filas": []}') - 'archivo' as alta_loc;
-- (otra vez: no duplica)
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "LOC ····8899", "filas": []}') ->> 'ya_estaba' as otra_vez;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] Chase: un desembolso de la línea (+4000) y un pago a ella (-1000); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-k2.csv", "filas": [
  {"id": "E03", "fecha": "2026-11-14", "monto": "4000.00", "descripcion": "ONLINE TRANSFER FROM ACCT ...8899 TRANSACTION#: 501", "tipo": "XFER"},
  {"id": "E04", "fecha": "2026-11-20", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO ACCT ...8899 TRANSACTION#: 502", "tipo": "XFER"}],
  "saldo": "53000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
