-- [Pestaña 1] (4c) un préstamo de vehículo (2520) SIN descriptor, cuyo número (····5521) se da de alta con su lote vacío
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K3)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "2520", "monto": "-31415.26"}, {"cuenta": "3900", "monto": "-18584.74"}]}') ->> 'numero' as apertura;
select fn_prestamo_guardar(jsonb_build_object('prestamista', 'K3 CREDIT', 'descripcion', 'camioneta', 'principal', '52000.00', 'tasa_anual', '6.99',
  'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15, 'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', '2026-09-30',
  'cuenta_banco', '1010')) ->> 'prestamista' as prestamo;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2520", "ultimos4": "5521", "confirmo_cuenta": true, "nombre": "préstamo ····5521", "filas": []}') ->> 'cuenta' as alta;

-- [Pestaña 2] Chase paga la cuota con una transferencia que nombra el número; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-k3.csv", "filas": [
  {"id": "L01", "fecha": "2026-10-15", "monto": "-1029.33", "descripcion": "ONLINE TRANSFER TO ACCT ...5521 TRANSACTION#: 901", "tipo": "XFER"}],
  "saldo": "48970.67", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
