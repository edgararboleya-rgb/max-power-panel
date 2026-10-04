\pset format aligned
\pset pager off
select m.id_externo, m.descripcion, fn_banco_otro_lado(m) as criterio from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
begin; select fn_banco_cuenta_personal('1007', 'Edgar · cuenta personal en Wells Fargo') ->> 'ultimos4' as personal_1007; rollback;
