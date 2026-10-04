\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
-- lo que dice el texto para la línea de crédito: «da de alta su número … con un lote vacío a su cuenta del plan»
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "LOC ····8899", "filas": []}') -> 'avisos' as alta_loc;
select fn_tarjeta_alta('8899', '2510', 'Línea de crédito') ->> 'cuenta' as loc_como_tarjeta;
select propuesta->>'texto' as texto from movimientos_banco where id_externo = 'E03';
-- sin poder darla de alta, ¿a 2510 a mano? (con y sin motivo)
begin;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'E03'), '[{"cuenta": "2510"}]') ->> 'estado' as loc_sin_motivo;
rollback;
begin;
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'E04'), '[{"cuenta": "2510"}]') ->> 'estado' as pago_loc_sin_motivo;
rollback;
