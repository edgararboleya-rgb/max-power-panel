\pset format aligned
\pset pager off
begin;
-- el depósito de la reserva «FROM EDGAR M MARTINEZ», clasificado como su aportación (3100) con su motivo
select fn_banco_clasificar(m.id, '[{"cuenta": "3100"}]', 'aportación de Edgar desde su cuenta personal (····7781)') ->> 'estado' as clasificado
  from movimientos_banco m where m.id_externo = 'R01';
-- llega Chase con el pase a la personal dada de alta
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select * from pg_temp.atq_bandeja();
select propuesta->>'texto' as texto from movimientos_banco where id_externo = 'C01';
select o->>'texto' as texto, o->>'llamar' as llamar, o->'args' as args from v_banco_bandeja b, jsonb_array_elements(b.opciones) o where b.cuenta = '1010';
savepoint s1;
-- (i) lo correcto: el pase a la personal dada de alta, a 3200 (su distribución), sin motivo
select fn_banco_clasificar(m.id, '[{"cuenta": "3200"}]') ->> 'estado' as distribucion from movimientos_banco m where m.id_externo = 'C01';
select l.cuenta, l.monto, a.numero from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'movimientos_banco' order by a.numero, l.orden;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback to s1;
-- (ii) lo que propone la bandeja: des-casar el depósito (con un motivo) y «Casar»
select fn_banco_descasar(m.id, 'la bandeja dice que es el otro lado') ->> 'estado' as descasado from movimientos_banco m where m.id_externo = 'R01';
select fn_banco_casar_todo() -> 'por_regla' as casar3;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.propuesta_motivo from v_banco_movimientos m order by m.fecha;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
