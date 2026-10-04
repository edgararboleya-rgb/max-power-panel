\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- y fn_banco_casar_con {movimiento} a mano, sin motivo
begin;
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'C01'),
                          jsonb_build_object('movimiento', (select id from movimientos_banco where id_externo = 'R01'))) ->> 'estado' as casar_con_sin_motivo;
select l.cuenta, l.monto from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'movimientos_banco' order by l.orden;
select orden, vista, left(detalle, 300) from fn_banco_control('2026-11') where not ok;
rollback;
