\pset format aligned
\pset pager off
select m.id_externo, m.origen, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.posible_duplicado_de is not null as pdup from movimientos_banco m order by m.fecha, m.importado_el;
select * from pg_temp.atq_bandeja();
select b.texto from v_banco_bandeja b;
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
