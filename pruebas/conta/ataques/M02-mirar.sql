\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- pulsado tal cual el primer botón del pase a la personal («Es la cuota … a capital»)
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'M2T'),
                          (select o->'args'->'p_con' from v_banco_bandeja b cross join lateral jsonb_array_elements(b.opciones) o
                            where b.movimiento_id = (select id from movimientos_banco where id_externo = 'M2T') limit 1)) ->> 'estado' as pulsado;
select m.id_externo, m.fecha, m.monto, m.estado, m.casado_clase, m.casado_regla, bc.motivo,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ' order by l.orden) from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m left join banco_casados bc on bc.id = m.casado_id order by m.fecha;
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 400) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
select cuenta, sum(monto) from asiento_lineas where cuenta in ('2520', '2530', '3200', '7100') group by 1 order by 1;
select * from v_prestamos;
