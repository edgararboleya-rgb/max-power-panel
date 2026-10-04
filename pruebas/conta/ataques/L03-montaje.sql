-- [Pestaña 1] (final 4c, L03) como H: apertura; mapeo; los números de la reserva (····1097) y de Chase (····4392) dados de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L03)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] la reserva trae PRIMERO +2,000.00 que el banco dice que viene de Chase (····4392); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l03.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-04", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 901", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar;

-- [Pestaña 4] la app (c3, la pantalla de cobros: fn_cobro_registrar, con grant a authenticated) registra el cobro de la #1103 CON el
-- movimiento de la reserva (movimiento_id, «f06»), sin pasar por fn_banco_cobrar; después «Casar»
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-11-04', 'monto', '2000.00', 'cuenta', '1030', 'medio', 'transferencia',
         'referencia', '901', 'movimiento_id', (select id from movimientos_banco where id_externo = 'R01')::text,
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', (select id from facturas where num = '1103'), 'monto', '2000.00'))))
       ->> 'asiento' as cobro_c3;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
