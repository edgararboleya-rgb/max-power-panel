-- [Pestaña 1] como C: la apertura mínima y los números de la reserva (····1097) y de Chase (····4392) dados de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque C2)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030: su número ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010: su número ····4392", "filas": []}') -> 'avisos' as chase;

select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as alta_personal;

-- [Pestaña 2] la reserva trae un depósito de 2,000.00 el 6-nov (desde la cuenta personal de Edgar, por su nombre) y Chase un pase de
-- 2,000.00 el 8-nov a la cuenta ····7781 (la personal de Edgar, SIN dar de alta). R3 no los junta (el lado que entra es de antes).
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-06", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM EDGAR M MARTINEZ", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar, fn_banco_casar_todo() -> 'por_regla' ->> 'transferencias' as r3;
