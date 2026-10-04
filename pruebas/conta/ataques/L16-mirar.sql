\pset format aligned
\pset pager off
-- ¿R1 casó SOLOS el cheque del cliente y el pase desde la reserva con las aportaciones escritas a mano (al patrimonio, sin motivo)?
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ') from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m order by m.fecha;
select f.num, (select sum(l.monto) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = f.id::text and l.cuenta = '1110') as por_cobrar
  from facturas f where f.num in ('1101', '1103') order by 1;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
