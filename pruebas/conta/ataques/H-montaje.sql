-- [Pestaña 1] apertura mínima; mapeos y facturas al libro (#1101 5,000.00 y #1103 8,000.00 abiertas); los números de Chase
-- (····4392) y de la reserva (····1097) dados de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque H)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] llega PRIMERO el estado de cuenta de la reserva: +2,000.00 desde Chase (····4392), el pase del 3-nov
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-04", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 701", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
