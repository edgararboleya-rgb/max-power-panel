-- [Pestaña 1] (4c) como H, con un cobro de 2,000.00 anotado en la reserva (un cheque de la #1103) el 3-nov
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K5)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] el cobro anotado
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-11-03', 'monto', '2000.00', 'cuenta', '1030', 'medio', 'cheque', 'referencia', 'K5-1',
         'aplicaciones', (select jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', '2000.00')) from facturas f where f.num = '1103'))) ->> 'cobro' is not null as cobro;

-- [Pestaña 4] la reserva: +2,000.00 desde Chase (····4392) el 4-nov; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-04", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 701", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_regla' as casar;
