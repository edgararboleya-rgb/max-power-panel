-- [Pestaña 1] (final 4c, L02b) apertura; la Gold (····2013); los números de la reserva (····1097) y de Chase (····4392); la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L02b)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] el CPA escribe A MANO el pase a la reserva del 5-nov (Dr 1030 / Cr 1010, 2,000.00) y el pago de la Gold del 7-nov
-- (Dr 2100-2013 / Cr 1010, 1,500.00)
select fn_postear('{"tipo": "normal", "fecha": "2026-11-05", "descripcion": "Pase a la reserva de impuestos (a mano)", "lineas": [
  {"cuenta": "1030", "monto": "2000.00"}, {"cuenta": "1010", "monto": "-2000.00"}]}') ->> 'numero' as pase_a_mano;
select fn_postear('{"tipo": "normal", "fecha": "2026-11-07", "descripcion": "Pago de la Amex Gold (a mano)", "lineas": [
  {"cuenta": "2100-2013", "monto": "1500.00"}, {"cuenta": "1010", "monto": "-1500.00"}]}') ->> 'numero' as pago_a_mano;

-- [Pestaña 3] Chase trae el 5-nov -2,000.00 a la cuenta PERSONAL de Edgar (····7781, dada de alta) y el 7-nov -1,500.00 al pago de
-- una tarjeta ····5555 que no es de la empresa; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "ultimos4": "4392", "nombre": "chase-nov-l02b.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 802", "tipo": "XFER"},
  {"id": "C02", "fecha": "2026-11-07", "monto": "-1500.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 5555 11/07"}],
  "saldo": "46500.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar;
