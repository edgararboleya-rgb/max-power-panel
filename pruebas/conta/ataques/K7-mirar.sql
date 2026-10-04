\pset format aligned
\pset pager off
select id_externo, estado_motivo, propuesta ? 'aviso_apertura' as aviso_apertura, left(propuesta->>'aviso_apertura', 120) as aviso from movimientos_banco order by fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
