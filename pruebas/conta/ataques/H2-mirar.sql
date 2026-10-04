\pset format aligned
\pset pager off
-- (1) sin pulsar nada: llega Chase con su lado; ¿casa solo?
begin;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 701", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select cuenta, fecha, monto, descripcion, estado, casado_clase, casado_regla from v_banco_movimientos where id_externo in ('R01', 'C01') order by cuenta;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
-- (2) «Desde 1010» tal cual antes de que llegue Chase; después llega Chase
begin;
select o->>'texto' as boton, o->>'llamar' as llamar, o->'args' as args
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.monto = 2000 and o->>'texto' like 'Desde 1010%';
select fn_banco_transferencia((o->'args'->>'p_movimiento')::uuid, o->'args'->>'p_cuenta') ->> 'estado' as desde
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.monto = 2000 and o->>'texto' like 'Desde 1010%';
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 701", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select cuenta, fecha, monto, descripcion, estado, casado_clase, casado_regla from v_banco_movimientos where id_externo in ('R01', 'C01') order by cuenta;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
