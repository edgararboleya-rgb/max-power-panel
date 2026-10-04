\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 60) as boton, left(resultado::text, 200) as resultado from pg_temp.atq_barrer();
select propuesta->>'texto' as texto from movimientos_banco where id_externo = 'F01';
