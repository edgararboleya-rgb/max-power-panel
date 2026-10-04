-- [Pestaña 1] (4c) como C2u: la apertura, los números de la reserva (····1097) y de Chase (····4392), la personal ····7781 DADA DE ALTA
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K1)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030: su número ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010: su número ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as alta_personal;

-- [Pestaña 2] la reserva PRIMERO: +2000 «FROM EDGAR M MARTINEZ»; «Desde 1010» CON su motivo (lo que ahora pide)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-06", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM EDGAR M MARTINEZ", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'R01'), '1010', 'K1: creo que la pasé desde Chase') ->> 'estado' as desde_1010_con_motivo;

-- [Pestaña 3] llega Chase: su pase del 5-nov a la PERSONAL dada de alta (····7781), por lo mismo; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
