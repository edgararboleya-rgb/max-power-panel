-- [Pestaña 1] apertura mínima y la Gold dada de alta (····2013): su número se conoce
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque C3)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;

select fn_tarjeta_alta('5555', '2900', 'Edgar · Sapphire personal') ->> 'cuenta' as tarjeta_personal;

-- [Pestaña 2] Chase paga 640.00 a la tarjeta ····5555 (la Sapphire PERSONAL de Edgar, sin dar de alta), y la Gold trae un pago
-- recibido de 640.00 (que Edgar hizo desde su cuenta personal). Primero la Gold, después Chase.
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-nov.csv", "filas": [
  {"id": "G01", "fecha": "2026-11-09", "monto": "640.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-08", "monto": "-640.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 5555 11/08"}],
  "saldo": "49360.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' ->> 'transferencias' as r3;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_regla from movimientos_banco m order by m.fecha;
