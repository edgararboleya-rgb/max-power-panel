\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.estado, m.casado_clase, m.casado_regla, m.casado_auto from movimientos_banco m order by m.fecha;
select 'REF' as k, left(contradice, 200), regla from fn_banco_criterio_casados();
select orden, vista, filas, ok from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
select fn_conciliar('1010', '2026-10-31', '52,000.00') ->> 'falta' as falta;
