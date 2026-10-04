-- [Pestaña 1] (4c) el cheque y la transferencia: la apertura posteada y SIN conciliar (los primeros 30 días)
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K7)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;

-- [Pestaña 2] Chase de octubre: un pase a ····7781 (sin dar de alta) y un cheque de verdad
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-k7.csv", "filas": [
  {"id": "C01", "fecha": "2026-10-03", "monto": "-700.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 21", "tipo": "XFER"},
  {"id": "C02", "fecha": "2026-10-04", "monto": "-1250.00", "descripcion": "CHECK 1042", "tipo": "CHECK"}],
  "saldo": "48050.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
