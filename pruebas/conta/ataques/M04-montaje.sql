-- [Pestaña 1] (final 4d, M04; sobre la base M) dos cobros anotados por la app SIN movimiento (dos cheques de la #1103: 1,200.00 y
-- 800.00, el 20-oct); el 21-oct Chase trae +2,000.00 que el banco dice que viene de la cuenta PERSONAL de Edgar (····7781); Casar
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-10-20', 'monto', '1200.00', 'cuenta', '1010', 'medio', 'cheque',
         'referencia', 'CHK 501', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', 3, 'monto', '1200.00')))) ->> 'asiento' as c1;
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-10-20', 'monto', '800.00', 'cuenta', '1010', 'medio', 'cheque',
         'referencia', 'CHK 502', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', 3, 'monto', '800.00')))) ->> 'asiento' as c2;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m04.csv", "filas": [
  {"id": "M4D", "fecha": "2026-10-21", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 70", "tipo": "XFER"}],
  "saldo": "52000.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_regla' as casar;
