-- [Pestaña 1] (final 4d, M01; sobre la base M) un cobro de la #1103 (2,000.00 el 20-oct, cheque) y Chase de octubre: el depósito del
-- cheque el 21-oct y, el 28-oct, un pase a la cuenta PERSONAL de Edgar (····7781, dada de alta) por lo mismo; Casar
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-10-20', 'monto', '2000.00', 'cuenta', '1010', 'medio', 'cheque',
         'referencia', 'CHK 4471', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', 3, 'monto', '2000.00'))))
       ->> 'asiento' as cobro_1103;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m01.csv", "filas": [
  {"id": "M1D", "fecha": "2026-10-21", "monto": "2000.00", "descripcion": "REMOTE ONLINE DEPOSIT #7"},
  {"id": "M1T", "fecha": "2026-10-28", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 55", "tipo": "XFER"}],
  "saldo": "50000.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_regla' as casar;

-- [Pestaña 2] la app (c3, fn_cobro_devolver con grant a authenticated) dice que el cheque de la #1103 rebotó, CON el movimiento del
-- 28-oct (el pase a la personal); después «Casar»
select fn_cobro_devolver((select id from cobros where referencia = 'CHK 4471'), '2026-10-28', 'El cheque 4471 de Pérez rebotó',
                         (select id::text from movimientos_banco where id_externo = 'M1T')) ->> 'asiento' as devolucion;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
