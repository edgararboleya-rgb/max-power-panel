\pset format aligned
\pset pager off
-- R1 NO casa solo el pase a la personal con la línea que puso «Desde 1010» (se contradicen)
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.estado_motivo from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- casar_con {lineas} a mano sin motivo: MX008; clasificar a 3200 sin motivo: MX008 (la línea lo espera) con el porqué
begin;
select fn_banco_casar_con((select id from movimientos_banco where id_externo = 'C01'),
         (select jsonb_build_object('lineas', jsonb_build_array(jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden)))
            from asiento_lineas l join movimientos_banco r on r.asiento_id = l.asiento_id where r.id_externo = 'R01' and l.cuenta = '1010')) ->> 'estado' as lineas_sin_motivo;
rollback;
begin;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'C01'), '[{"cuenta": "3200"}]') ->> 'estado' as clasificar_3200;
rollback;
-- lo que propone la bandeja: des-casar el depósito (con su motivo), y después cada uno por lo que es
begin;
select fn_banco_descasar((select id from movimientos_banco where id_externo = 'R01'), 'K1: no venía de Chase') ->> 'estado' as descasado;
select fn_banco_casar_todo() -> 'por_motivo' as casar3;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
rollback;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
