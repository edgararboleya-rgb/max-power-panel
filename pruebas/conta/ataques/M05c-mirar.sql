\pset format aligned
\pset pager off
-- (M05c) el QFX del mes entero: nada casa solo, pero cada pase tiene UN botón, «Confirmar cruce con recibo …», sin pide_motivo.
-- Cada botón sin pide_motivo, pulsado en una subtransacción deshecha:
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- Pulsados de verdad los dos botones de los PASES (la reserva y la personal), tal cual:
select m.id_externo, fn_banco_casar_con(m.id, (select o->'args'->'p_con' from v_banco_bandeja b cross join lateral jsonb_array_elements(b.opciones) o
                                               where b.movimiento_id = m.id limit 1)) ->> 'estado' as pulsado
  from movimientos_banco m where m.id_externo in ('M5B-R', 'M5B-P') order by 1;
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto, bc.motivo
  from movimientos_banco m left join banco_casados bc on bc.id = m.casado_id order by m.fecha;
select m.id_externo, fn_banco_criterio_libro(m, m.asiento_id, m.casado_clase) - 'libro' - 'banco' as criterio
  from movimientos_banco m where m.estado = 'casado';
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 300) from fn_banco_control('2026-10') where not ok or orden = 59;
-- lo que queda en la bandeja (las compras de verdad)
select * from pg_temp.atq_bandeja();
