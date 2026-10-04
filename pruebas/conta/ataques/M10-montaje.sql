-- [Pestaña 1] (final 4d, M10; sobre la base M) Chase de la primera semana de octubre (para que 1010 ya traiga estado de cuenta)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-1.csv", "filas": [
  {"id": "M10A", "fecha": "2026-10-02", "monto": "-50.00", "descripcion": "MONTHLY SERVICE FEE"}],
  "saldo": "49950.00", "saldo_al": "2026-10-07"}') ->> 'filas_nuevas' as chase1;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'M10A'), '[{"cuenta": "6130"}]') ->> 'estado' as fee;

-- [Pestaña 2] Plaid trae a la reserva, el 15-oct, +2,000.00 «Online Transfer from CHK» (el nombre corto); Casar; Edgar pulsa «Desde
-- 1010» tal cual (no pide motivo)
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1030", "nombre": "plaid-reserva-m10", "filas": [
  {"id": "PL-M10", "fecha": "2026-10-15", "plaid_monto": "-2000.00", "descripcion": "Online Transfer from CHK", "pendiente": false}]}') ->> 'filas_nuevas' as plaid;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select o->>'texto' as boton, o->'pide_motivo' as pm from v_banco_bandeja b, jsonb_array_elements(b.opciones) o where b.cuenta = '1030';
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'PL-M10'), '1010') ->> 'estado' as desde_1010;

-- [Pestaña 3] Chase de octubre: su lado, fechado el 14 (un día antes que el asiento); Casar (R1 lo casa con la línea y rehace el
-- asiento con la fecha más temprana)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-2.csv", "filas": [
  {"id": "M10C", "fecha": "2026-10-14", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 77", "tipo": "XFER"}],
  "saldo": "47950.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase2;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
