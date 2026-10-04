\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_regla, fn_banco_otro_lado(m) as criterio from movimientos_banco m order by m.fecha, m.cuenta;
select * from pg_temp.atq_bandeja();
