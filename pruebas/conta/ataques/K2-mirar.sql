\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 90) as boton, resultado from pg_temp.atq_barrer();
select id_externo, left(propuesta->>'texto', 220) as texto from movimientos_banco order by fecha;
-- los dos botones primeros, tal cual, y el control
begin;
select fn_banco_clasificar((o->'args'->>'p_movimiento')::uuid, o->'args'->'p_lineas', o->'args'->>'p_motivo') ->> 'estado' as boton1
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where x.n = 1 order by b.fecha;
select l.cuenta, l.monto, a.numero from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'movimientos_banco' order by a.numero, l.orden;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
-- cobrar el desembolso a una factura sin notas: MX008; transferencia a 1030 sin motivo: MX008
begin;
select fn_banco_cobrar((select id from movimientos_banco where id_externo = 'E03'), (select jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', '4000.00')) from facturas f where f.num = '1103')) ->> 'estado' as cobrar_sin_notas;
rollback;
begin;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'E04'), '1030') ->> 'estado' as a_1030;
rollback;
-- y un número que ya es de otra cuenta no se da de alta a 2510
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2520", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "otra vez ····8899", "filas": []}') ->> 'cuenta' as repetido;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8899", "confirmo_cuenta": true, "nombre": "con saldo", "saldo": "-10000.00", "saldo_al": "2026-11-30", "filas": []}') ->> 'cuenta' as con_saldo;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-10') where not ok;
