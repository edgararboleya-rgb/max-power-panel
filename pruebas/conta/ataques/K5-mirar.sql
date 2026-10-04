\pset format aligned
\pset pager off
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.estado_motivo from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
begin;
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'R01'), jsonb_build_object('cobro', (select c.id from cobros c where c.referencia = 'K5-1'))) ->> 'estado' as cobro_sin_motivo;
rollback;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
