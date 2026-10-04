\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ' order by l.orden) from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m order by m.fecha;
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 400) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
select * from pg_temp.atq_bandeja();
