-- [Pestaña 1] (final 4d, M03; sobre la base M) la Gold dada de alta; el préstamo de la F-150 y su cuota de octubre registrada con el
-- statement ANTES que el banco (1,029.33, el 15-oct)
select fn_tarjeta_alta('2013', '2100-2013', 'Edgar · Amex Business Gold') ->> 'cuenta' as gold;
select fn_prestamo_guardar(jsonb_build_object('prestamista', 'ALLY AUTO', 'descripcion', 'F-150', 'principal', '52000.00',
         'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15, 'plazo_meses', 60,
         'saldo_inicial', '31415.26', 'saldo_inicial_al', '2026-09-30', 'cuenta_banco', '1010', 'descriptor', 'ALLY'))->>'id' as prestamo;
select fn_prestamo_cuota((select id from prestamos where prestamista = 'ALLY AUTO'), null, '2026-10-15', '1029.33') ->> 'asiento' as cuota_oct;

-- [Pestaña 2] Chase de octubre (la Gold todavía no subió su statement): el 13-oct un pase a la personal de Edgar por EXACTAMENTE la
-- cuota; el 20-oct el pago de la Gold (3,500.00); el 22-oct el pase a la reserva (····1097, 2,000.00); el 24-oct un cheque a un
-- subcontratista (1,500.00); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m03.csv", "filas": [
  {"id": "M3T", "fecha": "2026-10-13", "monto": "-1029.33", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 67", "tipo": "XFER"},
  {"id": "M3A", "fecha": "2026-10-20", "monto": "-3500.00", "descripcion": "AMERICAN EXPRESS ACH PMT M6342 WEB ID: 2005032111"},
  {"id": "M3R", "fecha": "2026-10-22", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 68", "tipo": "XFER"},
  {"id": "M3C", "fecha": "2026-10-24", "monto": "-1500.00", "descripcion": "CHECK 1044", "cheque": "1044", "tipo": "CHECK"}],
  "saldo": "41970.67", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
