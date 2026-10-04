\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
-- en la reserva, «Desde 1010» tal cual (sin motivo), y después «Casar»
select fn_banco_transferencia((o->'args'->>'p_movimiento')::uuid, o->'args'->>'p_cuenta', o->'args'->>'p_motivo') ->> 'estado' as desde_1010
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.cuenta = '1030' and o->>'texto' like 'Desde 1010%';
select fn_banco_casar_todo() -> 'por_regla' as casar;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla from movimientos_banco m order by m.fecha;
select l.cuenta, l.monto, a.numero from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'movimientos_banco' order by a.numero, l.orden;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
