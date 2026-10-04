-- [Pestaña 1] (4c) como C3s: la Gold (····2013) y la tarjeta personal de Edgar ····5555 dada de alta en 2900
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K4)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;
select fn_tarjeta_alta('5555', '2900', 'Edgar · Sapphire personal') ->> 'cuenta' as tarjeta_personal;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010: su número ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2] la Gold PRIMERO, con su pago recibido; «Desde 1010» CON su motivo
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-nov.csv", "filas": [
  {"id": "G01", "fecha": "2026-11-09", "monto": "640.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'G01'), '1010', 'K4: la pagué desde Chase') ->> 'estado' as desde_1010;

-- [Pestaña 3] llega Chase con el pago a la tarjeta PERSONAL; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-08", "monto": "-640.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 5555 11/08"}],
  "saldo": "49360.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
