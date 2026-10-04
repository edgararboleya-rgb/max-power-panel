-- [Pestaña 1] (final 4c, L01) apertura con la línea de crédito; mapeo y facturas #1101 (5,000.00) y #1103 (8,000.00) al libro
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L01)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "2510", "monto": "-10000.00"}, {"cuenta": "3900", "monto": "-40000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] Chase trae dinero de dos números que todavía NO se conocen (····8899 la línea de crédito, ····1097 la reserva), por
-- montos que explican facturas abiertas; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l01.csv", "filas": [
  {"id": "L01A", "fecha": "2026-11-14", "monto": "5000.00", "descripcion": "ONLINE TRANSFER FROM ACCT ...8899 TRANSACTION#: 501", "tipo": "XFER"},
  {"id": "L01B", "fecha": "2026-11-15", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM SAV ...1097 TRANSACTION#: 502", "tipo": "XFER"}],
  "saldo": "57000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;

-- [Pestaña 4] Edgar sigue el consejo de la bandeja: da de alta los dos números como de la empresa (lote vacío), SIN volver a «Casar»
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "LOC ····8899", "filas": []}') - 'archivo' as alta_loc;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') - 'archivo' as alta_reserva;
