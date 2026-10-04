\pset format aligned
\pset pager off
-- ¿R1 casó SOLO el cheque con la línea del pase («Desde 1010»)? (fn_banco_lados: un tercero que no nombra a nadie, y el otro lado
-- nombra su cuenta por su número: «solas»)
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto from movimientos_banco m order by m.fecha;
select * from pg_temp.atq_auditar();
select * from pg_temp.atq_bandeja();
