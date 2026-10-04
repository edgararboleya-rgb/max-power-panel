-- [Pestaña 1] (final 4c, L07) apertura; mapeo; los números de la reserva (····1097) y de Chase (····4392) dados de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L07)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] dos cobros anotados en 1010 (3,000.00 a la #1103 y 2,000.00 a la #1101, el 3-nov) que suman 5,000.00
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-11-03', 'monto', '3000.00', 'cuenta', '1010', 'medio', 'cheque', 'referencia', 'L07-1',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', (select id from facturas where num = '1103'), 'monto', '3000.00')))) ->> 'asiento' as cobro1;
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-11-03', 'monto', '2000.00', 'cuenta', '1010', 'medio', 'cheque', 'referencia', 'L07-2',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', (select id from facturas where num = '1101'), 'monto', '2000.00')))) ->> 'asiento' as cobro2;

-- [Pestaña 4] Chase: +5,000.00 desde la reserva por su número (suma los dos cobros); +8,000.00 con el número solo en la nota (NAME
-- cortado); +2,500.00 «DEPOSIT FROM SAV 1097» (sin «TRANSFER» ni XFER); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l07.csv", "filas": [
  {"id": "D01", "fecha": "2026-11-04", "monto": "5000.00", "descripcion": "ONLINE TRANSFER FROM SAV ...1097 TRANSACTION#: 77", "tipo": "XFER"},
  {"id": "D02", "fecha": "2026-11-06", "monto": "8000.00", "descripcion": "ONLINE TRANSFER FROM SAV ...109", "memo": "ONLINE TRANSFER FROM SAV ...1097 TRANSACTION#: 78"},
  {"id": "D03", "fecha": "2026-11-07", "monto": "2500.00", "descripcion": "DEPOSIT FROM SAV 1097"}],
  "saldo": "65500.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_regla' as casar;
