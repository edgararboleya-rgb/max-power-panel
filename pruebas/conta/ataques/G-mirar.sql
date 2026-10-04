\pset format aligned
\pset pager off
-- la bandeja ANTES de «Casar» (la propuesta guardada, de cuando la cuenta estaba de alta)
select * from pg_temp.atq_bandeja();
-- el botón viejo, tal cual (sin motivo)
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 70) as boton, resultado from pg_temp.atq_barrer();
-- «Casar»: ¿rehace la propuesta?
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select * from pg_temp.atq_bandeja();
-- lo ya casado con la cuenta de alta: el control
select orden, vista, left(detalle, 300) from fn_banco_control('2026-11') where not ok;
-- des-casar el primero y volver a clasificarlo con el mismo botón de antes, sin motivo
select fn_banco_descasar((select id from movimientos_banco where id_externo = 'G01'), 'la cuenta ya no es personal: revisar') ->> 'estado' as descasado;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'G01'), '[{"cuenta": "3200"}]') ->> 'estado' as otra_vez_sin_motivo;
