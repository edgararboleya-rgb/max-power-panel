\pset format aligned
\pset pager off
-- ¿R1 casó SOLOS los retiros de Chase (a la personal dada de alta; al pago de una tarjeta que no es de la empresa) con las líneas
-- de 1010 de los asientos escritos a mano?
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto,
       fn_banco_otro_lado(m) ->> 'clase' as otro_lado from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
-- la conciliación de 1010 al 30-nov (lo que el libro tiene y el banco no)
select cuenta, fecha_corte, saldo_banco, saldo_libro, diferencia from v_banco_saldos where cuenta in ('1010', '1030');
