\pset format aligned
\pset pager off
-- ¿R1 casó SOLO el depósito de la personal con la línea del pase escrito a mano (clase «asiento», sin EL CRITERIO)?
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
-- lo mismo SIN la personal dada de alta (un número que no se conoce): ¿la bandeja ofrece casarlo sin motivo?
begin;
select fn_banco_descasar((select id from movimientos_banco where id_externo = 'R01'), 'L02: mirar la propuesta') ->> 'estado' as descasado;
select fn_banco_cuenta_personal('7781', null, false, 'L02: probar con un número que no se conoce') ->> 'activa' as baja;
select fn_banco_casar((select id from movimientos_banco where id_externo = 'R01')) ->> 'estado' as casar_uno;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
rollback;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
