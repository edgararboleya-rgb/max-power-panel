-- [Pestaña 1] (final 4c, L08) apertura; números de la reserva y de Chase; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L08)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] montos redondos el mismo día: (1) a la reserva y a Edgar por su número, y la reserva trae uno; (2) dos «TO SAVINGS» sin
-- número y la reserva trae uno «FROM CHECKING»; (3) uno a la reserva por su número y la reserva trae dos: «DEPOSIT» y uno desde la
-- personal. Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l08.csv", "filas": [
  {"id": "C1", "fecha": "2026-11-02", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 1", "tipo": "XFER"},
  {"id": "C2", "fecha": "2026-11-02", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 2", "tipo": "XFER"},
  {"id": "C3", "fecha": "2026-11-09", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO SAVINGS", "tipo": "XFER"},
  {"id": "C4", "fecha": "2026-11-09", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO SAVINGS", "tipo": "XFER"},
  {"id": "C5", "fecha": "2026-11-16", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 5", "tipo": "XFER"}],
  "saldo": "45000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l08.csv", "filas": [
  {"id": "R1", "fecha": "2026-11-03", "monto": "1000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 1", "tipo": "XFER"},
  {"id": "R2", "fecha": "2026-11-10", "monto": "1000.00", "descripcion": "ONLINE TRANSFER FROM CHECKING", "tipo": "XFER"},
  {"id": "R3", "fecha": "2026-11-17", "monto": "1000.00", "descripcion": "DEPOSIT"},
  {"id": "R4", "fecha": "2026-11-17", "monto": "1000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 6", "tipo": "XFER"}],
  "saldo": "4000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_regla' as casar;
