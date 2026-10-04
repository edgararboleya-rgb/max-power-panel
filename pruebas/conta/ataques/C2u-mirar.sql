\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
begin;
-- «Desde 1010» tal cual (sin motivo) en la reserva, ANTES de que llegue Chase
select fn_banco_transferencia((o->'args'->>'p_movimiento')::uuid, o->'args'->>'p_cuenta', o->'args'->>'p_motivo') ->> 'estado' as desde_1010
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.cuenta = '1030' and o->>'texto' like 'Desde 1010%';
-- llega Chase: su pase del 5-nov a la cuenta PERSONAL dada de alta (····7781), por lo mismo
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_regla' as casar2;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla from v_banco_movimientos m order by m.fecha;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
-- la consulta del README (paso 1 de «Después de c6»): ¿lo enseña?
select fecha, cuenta, monto, descripcion, casado_regla from v_banco_movimientos where casado_clase = 'transferencia' and casado_auto order by fecha;
rollback;
-- sin pulsar nada: llega Chase y «Casar»
begin;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar3;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.propuesta_motivo, m.casado_regla from v_banco_movimientos m order by m.fecha;
rollback;
