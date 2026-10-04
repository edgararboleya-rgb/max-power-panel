-- [Pestaña 1] (final 4d, M02; sobre la base M) el préstamo de la F-150 (Ally, 1,029.33 al mes, el día 15, desde Chase; su saldo
-- de la apertura en 2530) y su cuota de octubre registrada con el statement ANTES que el banco
select fn_prestamo_guardar(jsonb_build_object('prestamista', 'ALLY AUTO', 'descripcion', 'F-150', 'principal', '52000.00',
         'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15, 'plazo_meses', 60,
         'saldo_inicial', '31415.26', 'saldo_inicial_al', '2026-09-30', 'cuenta_banco', '1010', 'descriptor', 'ALLY'))->>'id' as prestamo;
select fn_prestamo_cuota((select id from prestamos where prestamista = 'ALLY AUTO'), null, '2026-10-15', '1029.33') ->> 'asiento' as cuota_oct;

-- [Pestaña 2] Chase de octubre: el 17-oct Edgar se pasa 1,050.00 a su cuenta PERSONAL (····7781, dada de alta), y el 18-oct una
-- compra de 250.00 en Home Depot con la débito (sin ticket todavía); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m02.csv", "filas": [
  {"id": "M2T", "fecha": "2026-10-17", "monto": "-1050.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 66", "tipo": "XFER"},
  {"id": "M2H", "fecha": "2026-10-18", "monto": "-250.00", "descripcion": "HOME DEPOT #6345 MIAMI FL", "memo": "10/18 CARD 9420"}],
  "saldo": "48700.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
