\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- pulsado tal cual el primer botón (la cuota del préstamo)
select fn_prestamo_cuota((select id from prestamos where prestamista = 'ALLY AUTO'), (select id from movimientos_banco where id_externo = 'M8C'))
       ->> 'asiento' as cuota;
select m.id_externo, m.fecha, m.monto, m.estado, m.casado_clase, m.casado_regla,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ' order by l.orden) from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m order by m.fecha;
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 500) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
select fn_conciliar('1010', '2026-10-31', '48,970.67') ->> 'falta' as falta;
select fn_conciliacion_confirmar((select id from conciliaciones where cuenta = '1010' and fecha_corte = '2026-10-31')) ->> 'estado' as oct;
