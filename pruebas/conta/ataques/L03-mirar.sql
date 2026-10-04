\pset format aligned
\pset pager off
-- ¿«R2 el cobro dice este movimiento» casó solo el pase de Chase como el cobro de un cliente?
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto from movimientos_banco m order by m.fecha;
-- llega Chase con su lado del pase; ¿qué ofrece la bandeja?
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l03.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 901", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar3;
select * from pg_temp.atq_bandeja();
select fecha, monto, left(descripcion, 34) as descripcion, motivo, n, left(boton, 80) as boton, resultado from pg_temp.atq_barrer();
-- pulsado «A 1030» tal cual: 1030 en libros contra su banco
begin;
select fn_banco_transferencia((select id from movimientos_banco where id_externo = 'C01'), '1030') ->> 'estado' as a_1030;
select cuenta, saldo_libros, saldo_banco from v_banco_saldos where cuenta in ('1010', '1030') order by 1;
select f.num, (select sum(l.monto) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = f.id::text and l.cuenta = '1110') as por_cobrar
  from facturas f where f.num in ('1101', '1103') order by 1;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
