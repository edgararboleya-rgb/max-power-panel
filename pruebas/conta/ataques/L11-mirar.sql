\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla from movimientos_banco m order by m.fecha, m.cuenta;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
-- volver a juntar a mano lo que se contradice: sin motivo MX008, con motivo entra; y des-casarlo otra vez y «Casar» no lo junta solo
begin;
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'C2'), jsonb_build_object('movimiento', (select id from movimientos_banco where id_externo = 'R2'))) ->> 'estado' as c2_r2_sin_motivo;
rollback;
begin;
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'C2'), jsonb_build_object('movimiento', (select id from movimientos_banco where id_externo = 'R2')), 'L11: sí, era el mismo dinero') ->> 'estado' as c2_r2_con_motivo;
select fn_banco_descasar((select id from movimientos_banco where id_externo = 'R2'), 'L11: no, no era') ->> 'estado' as descasado2;
select fn_banco_casar_todo() -> 'por_regla' as casar3;
select m.id_externo, m.estado, m.casado_regla from movimientos_banco m order by m.fecha, m.cuenta;
select * from pg_temp.atq_auditar();
rollback;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
