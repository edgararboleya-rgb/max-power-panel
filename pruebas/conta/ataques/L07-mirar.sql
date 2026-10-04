\pset format aligned
\pset pager off
select m.id_externo, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, fn_banco_otro_lado(m)->>'clase' as criterio from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
