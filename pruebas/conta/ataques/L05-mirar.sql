\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
select m.id_externo, m.estado, m.casado_clase, m.casado_regla from movimientos_banco m order by m.fecha;
-- lo casado con la personal de alta, después de la baja y del alta: el control y el rastro
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
select tabla, clave, accion, left(coalesce(motivo, ''), 60) as motivo from banco_historial where tabla = 'banco_cuentas_personales' order by cambiado_el;
-- otra baja, y lo de antes sigue casado: ¿el control lo dice?
begin;
select fn_banco_cuenta_personal('7781', null, false, 'L05: otra vez la cerró') ->> 'rehechas' as baja2;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
rollback;
