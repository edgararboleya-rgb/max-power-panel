\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
select cuenta, saldo_libros, saldo_banco from v_banco_saldos where cuenta in ('1010', '1030') order by 1;
select orden, vista, left(detalle, 300) from fn_banco_control('2026-11') where not ok;
select orden, vista, left(detalle, 300) from fn_banco_control('2026-10') where not ok;
