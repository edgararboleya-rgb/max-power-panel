\pset format aligned
\pset pager off
-- la bandeja DESPUÉS del alta y ANTES de «Casar»: ¿botones viejos sin motivo que ya fallan?
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
-- «Casar»: las rehace
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
-- el texto de la línea de crédito (dice «sin motivo») y su botón tal cual / con motivo
select left(propuesta->>'texto', 400) as texto_loc from movimientos_banco where id_externo = 'L01A';
begin;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L01A'), '[{"cuenta": "2510"}]') ->> 'estado' as loc_2510_tal_cual;
rollback;
begin;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L01A'), '[{"cuenta": "2510"}]', 'L01: desembolso de la línea') ->> 'estado' as loc_2510_con_motivo;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
