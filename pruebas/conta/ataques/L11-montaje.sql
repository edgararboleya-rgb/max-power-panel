-- [Pestaña 1] (final 4c, L11) des-casar y volver a casar: apertura; números de la reserva y de Chase; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L11)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] el pase de verdad (por su número, los dos lados) y, 3 días después, un pase a la personal y un depósito de la reserva
-- «FROM EDGAR M MARTINEZ» por lo mismo; Casar (R3 junta el primero)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l11.csv", "filas": [
  {"id": "C1", "fecha": "2026-11-02", "monto": "-2500.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 1", "tipo": "XFER"},
  {"id": "C2", "fecha": "2026-11-05", "monto": "-2500.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 2", "tipo": "XFER"}],
  "saldo": "45000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov-l11.csv", "filas": [
  {"id": "R1", "fecha": "2026-11-03", "monto": "2500.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 1", "tipo": "XFER"},
  {"id": "R2", "fecha": "2026-11-06", "monto": "2500.00", "descripcion": "ONLINE TRANSFER FROM EDGAR M MARTINEZ", "tipo": "XFER"}],
  "saldo": "5000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva;
select fn_banco_casar_todo() -> 'por_regla' as casar;

-- [Pestaña 3] Edgar des-casa el pase de R3 (por error, con su motivo) y vuelve a «Casar»
select fn_banco_descasar((select id from movimientos_banco where id_externo = 'C1'), 'L11: lo miro otra vez') ->> 'estado' as descasado;
select fn_banco_casar_todo() -> 'por_motivo' as casar2;
