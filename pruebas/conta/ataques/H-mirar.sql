\pset format aligned
\pset pager off
select * from pg_temp.atq_bandeja();
select propuesta->>'texto' as texto from movimientos_banco where id_externo = 'R01';
-- el primer botón tal cual, y después llega Chase con su lado: ¿qué queda?
begin;
select fn_banco_cobrar((o->'args'->>'p_movimiento')::uuid, o->'args'->'p_aplicaciones', o->'args'->>'p_notas') ->> 'estado' as boton1
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.monto = 2000 and x.n = 1;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 701", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
select * from pg_temp.atq_bandeja();
select f.num, (select sum(l.monto) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = f.id::text and l.cuenta = '1110') as por_cobrar
  from facturas f where f.num in ('1101', '1103') order by 1;
select orden, vista, left(detalle, 250) from fn_banco_control('2026-11') where not ok;
rollback;
