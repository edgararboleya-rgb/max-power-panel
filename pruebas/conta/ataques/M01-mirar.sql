\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ' order by l.orden) from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m order by m.fecha;
select f.num, (select sum(l.monto) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = f.id::text and l.cuenta = '1110') as por_cobrar
  from facturas f where f.num in ('1103') order by 1;
select (select sum(l.monto) from asiento_lineas l where fn_banco_es_accionista(l.cuenta)) as patrimonio_movido;
-- EL CONTROL y la referencia
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 400) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
-- «Cuadrar» octubre: ¿se confirma?
select fn_conciliar('1010', '2026-10-31', '50,000.00') ->> 'falta' as falta;
select fn_conciliacion_confirmar((select id from conciliaciones where cuenta = '1010' and fecha_corte = '2026-10-31')) ->> 'estado' as oct;
select orden, vista, left(detalle, 300) from fn_banco_control('2026-10') where not ok;
