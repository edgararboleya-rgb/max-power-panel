-- [Pestaña 1] (final 4c, L16) apertura; mapeo; los números de la reserva y de Chase; facturas al libro
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L16)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "1030", "monto": "10000.00"}, {"cuenta": "3900", "monto": "-60000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] el CPA anota A MANO dos aportaciones de Edgar a Chase: 5,000.00 el 4-nov y 2,500.00 el 10-nov (Dr 1010 / Cr 3100)
select fn_postear('{"tipo": "normal", "fecha": "2026-11-04", "descripcion": "Aportación de Edgar (a mano)", "lineas": [
  {"cuenta": "1010", "monto": "5000.00"}, {"cuenta": "3100", "monto": "-5000.00"}]}') ->> 'numero' as aporte1;
select fn_postear('{"tipo": "normal", "fecha": "2026-11-10", "descripcion": "Aportación de Edgar (a mano)", "lineas": [
  {"cuenta": "1010", "monto": "2500.00"}, {"cuenta": "3100", "monto": "-2500.00"}]}') ->> 'numero' as aporte2;

-- [Pestaña 4] Chase trae: el 5-nov un cheque de un CLIENTE depositado por el móvil (5,000.00, lo que la factura #1101 tiene abierto) y el
-- 11-nov un pase DESDE LA RESERVA por su número (2,500.00); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l16.csv", "filas": [
  {"id": "D1", "fecha": "2026-11-05", "monto": "5000.00", "descripcion": "REMOTE ONLINE DEPOSIT #5"},
  {"id": "D2", "fecha": "2026-11-11", "monto": "2500.00", "descripcion": "ONLINE TRANSFER FROM SAV ...1097 TRANSACTION#: 81", "tipo": "XFER"}],
  "saldo": "57500.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar;
