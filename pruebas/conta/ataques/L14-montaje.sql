-- [Pestaña 1] (final 4c, L14) apertura; los números de la reserva y de Chase dados de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L14)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2] la reserva llega primero: +2,000.00 «FROM CHK ...4392» el 6-nov; Edgar pulsa «Desde 1010» (sin motivo: está bien)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l14.csv", "filas": [
  {"id": "R1", "fecha": "2026-11-06", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 61", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'R1'), '1010') ->> 'estado' as desde_1010;

-- [Pestaña 3] Chase trae en esos días un CHEQUE de 2,000.00 (a un proveedor) y un ACH a secas; el pase de verdad está en el mes anterior
-- (fuera de la ventana). Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l14.csv", "filas": [
  {"id": "K1", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "CHECK 1234", "cheque": "1234", "tipo": "CHECK"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
