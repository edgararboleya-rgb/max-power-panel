-- [Pestaña 1] (final 4d, M01b; sobre la base M) el cobro de la #1103 (2,000.00 el 20-oct) y su depósito del 21-oct; Casar
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-10-20', 'monto', '2000.00', 'cuenta', '1010', 'medio', 'cheque',
         'referencia', 'CHK 4471', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', 3, 'monto', '2000.00'))))
       ->> 'asiento' as cobro_1103;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m01b-1.csv", "filas": [
  {"id": "M1D", "fecha": "2026-10-21", "monto": "2000.00", "descripcion": "REMOTE ONLINE DEPOSIT #7"}],
  "saldo": "52000.00", "saldo_al": "2026-10-21"}') ->> 'filas_nuevas' as chase_1;
select fn_banco_casar_todo() -> 'por_regla' as casar;

-- [Pestaña 2] el cliente avisa que el cheque rebotó y la app lo registra (fn_cobro_devolver, SIN movimiento: el banco todavía no lo
-- trae); el banco trae después, el 27-oct, un pase a la personal de Edgar por lo mismo (el aviso del rebote llegará en noviembre); Casar
select fn_cobro_devolver((select id from cobros where referencia = 'CHK 4471'), '2026-10-26', 'El cheque 4471 de Pérez rebotó') ->> 'asiento' as devolucion;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m01b-2.csv", "filas": [
  {"id": "M1T", "fecha": "2026-10-27", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 55", "tipo": "XFER"}],
  "saldo": "50000.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_2;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
