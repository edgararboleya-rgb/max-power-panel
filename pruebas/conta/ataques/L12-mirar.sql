\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
-- a mano, sin motivo: el pago partido (2510 + 7100 intereses), el desembolso a un gasto, y a otra cosa
begin; select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L1'), '[{"cuenta": "2510", "monto": "950.00"}, {"cuenta": "7100", "monto": "50.00"}]') ->> 'estado' as pago_partido; rollback;
begin; select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L2'), '[{"cuenta": "6130"}]') ->> 'estado' as desembolso_a_6130; rollback;
begin; select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L2'), '[{"cuenta": "2900"}]') ->> 'estado' as desembolso_a_2900; rollback;
begin; select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'L3'), '[{"cuenta": "2510"}]') ->> 'estado' as prestamo_a_2510; rollback;
-- los números: la personal 6611 otra vez como deuda; la línea 8899 como personal; el préstamo 5521 otra vez a otra deuda
begin; select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2530", "ultimos4": "6611", "confirmo_cuenta": true, "nombre": "x", "filas": []}') ->> 'cuenta' as personal_como_deuda; rollback;
begin; select fn_banco_cuenta_personal('8899', 'la línea como personal') ->> 'ultimos4' as loc_como_personal; rollback;
begin; select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2530", "ultimos4": "5521", "confirmo_cuenta": true, "nombre": "x", "filas": []}') ->> 'cuenta' as prestamo_otra_deuda; rollback;
-- y un lote con filas a 2510 (no trae estado de cuenta)
begin; select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "x", "filas": [{"id": "z", "fecha": "2026-11-10", "monto": "-5.00", "descripcion": "INTEREST"}]}') ->> 'cuenta' as loc_con_filas; rollback;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
select cuenta from v_banco_saldos order by 1;
