-- [Pestaña 1] (final 4c, L02) apertura; los números de la reserva (····1097) y de Chase (····4392) dados de alta; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L02)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] el CPA (o Edgar, desde el SQL Editor) escribe A MANO el pase a la reserva del 5-nov: Dr 1030 / Cr 1010, 2,000.00
select fn_postear('{"tipo": "normal", "fecha": "2026-11-05", "descripcion": "Pase a la reserva de impuestos (a mano)", "lineas": [
  {"cuenta": "1030", "monto": "2000.00"}, {"cuenta": "1010", "monto": "-2000.00"}]}') ->> 'numero' as pase_a_mano;

-- [Pestaña 3] la reserva trae +2,000.00 el 6-nov, que el banco dice que viene de la cuenta PERSONAL de Edgar (····7781, dada de alta); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l02.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-06", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 801", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva;
select fn_banco_casar_todo() -> 'por_regla' as casar;
