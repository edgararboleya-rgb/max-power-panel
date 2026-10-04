\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto,
       (select string_agg(l.cuenta || ' ' || l.monto, ', ' order by l.orden) from asiento_lineas l where l.asiento_id = m.asiento_id) as asiento
  from movimientos_banco m order by m.fecha;
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 400) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
-- (EL CRITERIO contra el libro, para el pase a la reserva casado con el ticket)
select m.id_externo, fn_banco_criterio_libro(m, m.asiento_id, m.casado_clase) - 'libro' - 'banco' as criterio
  from movimientos_banco m where m.estado = 'casado';
-- llegan las compras de verdad (la débito postea el 16 y el 17) y la reserva; Casar; la bandeja
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1010", "nombre": "plaid-m05b", "filas": [
  {"id": "PL-M5H", "fecha": "2026-10-16", "plaid_monto": "250.00", "descripcion": "HOME DEPOT #6345 MIAMI FL", "pendiente": false},
  {"id": "PL-M5G", "fecha": "2026-10-17", "plaid_monto": "180.00", "descripcion": "GRAYBAR ELECTRIC CO MIAMI FL", "pendiente": false}]}')
       ->> 'filas_nuevas' as plaid2;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-oct-m05.csv", "filas": [
  {"id": "R5", "fecha": "2026-10-14", "monto": "250.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 12", "tipo": "XFER"}],
  "saldo": "250.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as reserva;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select * from pg_temp.atq_bandeja();
