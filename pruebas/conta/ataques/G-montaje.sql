-- [Pestaña 1] apertura mínima; la cuenta personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque G)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as alta;

-- [Pestaña 2] dos pases a la personal; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-g.csv", "filas": [
  {"id": "G01", "fecha": "2026-11-03", "monto": "-700.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 601", "tipo": "XFER"},
  {"id": "G02", "fecha": "2026-11-04", "monto": "-300.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 602", "tipo": "XFER"}],
  "saldo": "49000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;

-- [Pestaña 3] el primero, con su botón (3200, sin motivo); después Edgar da de baja la cuenta (la cerró) SIN correr «Casar»
select fn_banco_clasificar((o->'args'->>'p_movimiento')::uuid, o->'args'->'p_lineas', o->'args'->>'p_motivo') ->> 'estado' as g01_boton1
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.monto = -700 and x.n = 1;
select fn_banco_cuenta_personal('7781', null, false, 'La cerró en noviembre') ->> 'activa' as baja;
