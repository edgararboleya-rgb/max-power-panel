\pset format aligned
\pset pager off
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla from movimientos_banco m order by m.fecha;
-- EL CRITERIO de cada lado
select m.id_externo, m.descripcion, fn_banco_otro_lado(m) as otro_lado from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
