-- [Pestaña 1] (final 4c, L09) el orden al revés: apertura; números de la reserva y de Chase; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L09)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;

-- [Pestaña 2] llega PRIMERO la reserva: (a) +2,000 «FROM CHK ...4392» el 4-nov; (c) +3,000 «DEPOSIT» el 12-nov; (d) +700 «REMOTE ONLINE
-- DEPOSIT #3» el 20-nov. Y la Gold: (b) +640 «PAYMENT RECEIVED» el 9-nov. Casar; Edgar pulsa «Desde 1010» en (a) y (b) tal cual
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l09.csv", "filas": [
  {"id": "Ra", "fecha": "2026-11-04", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 21", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-05"}') ->> 'filas_nuevas' as reserva_a;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-nov-l09.csv", "filas": [
  {"id": "Gb", "fecha": "2026-11-09", "monto": "640.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'Ra'), '1010') ->> 'estado' as ra_desde_1010;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'Gb'), '1010') ->> 'estado' as gb_desde_1010;

-- [Pestaña 3] llega Chase: (a) el pase de 2,000 a la PERSONAL (no a la reserva) el 3-nov y el de verdad a la reserva el 4-nov; (b) el pago
-- de 640 a la tarjeta personal ····5555 SIN dar de alta; y otro a la Gold por su número; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l09.csv", "filas": [
  {"id": "Ca1", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 20", "tipo": "XFER"},
  {"id": "Ca2", "fecha": "2026-11-04", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 21", "tipo": "XFER"},
  {"id": "Cb1", "fecha": "2026-11-08", "monto": "-640.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 5555 11/08"},
  {"id": "Cb2", "fecha": "2026-11-10", "monto": "-640.00", "descripcion": "AMEX EPAYMENT ACH PMT 2013"}],
  "saldo": "45360.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
