-- [Pestaña 1] (final 4c, L10) Plaid y QFX del mismo movimiento: apertura; números de la reserva y de Chase; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L10)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] llega PRIMERO Plaid, con el nombre corto (sin el número): «Online Transfer to CHK» por 2,000.00 el 5-nov; Casar; Edgar pulsa
-- su primer botón tal cual («A 1030»)
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1010", "nombre": "plaid-l10", "filas": [
  {"id": "plaid-l10-1", "fecha": "2026-11-05", "plaid_monto": "2000.00", "descripcion": "Online Transfer to CHK", "pendiente": false}]}') ->> 'filas_nuevas' as plaid;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
select o->>'texto' as boton1, fn_banco_transferencia((o->'args'->>'p_movimiento')::uuid, o->'args'->>'p_cuenta') ->> 'estado' as pulsado
  from v_banco_bandeja b, jsonb_array_elements(b.opciones) with ordinality x(o, n) where b.monto = -2000 and x.n = 1;

-- [Pestaña 3] llega el QFX de Chase con la misma transferencia, ENTERA: «ONLINE TRANSFER TO CHK ...7781» (la personal); Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l10.csv", "filas": [
  {"id": "Q01", "fecha": "2026-11-05", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 5", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-11-30"}') - 'archivo' - 'siguiente' as qfx;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
