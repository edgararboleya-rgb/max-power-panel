-- [Pestaña 1] (4c) R3 con un lado que no dice transferencia: la apertura y los números
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (4c K6)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010 ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2] dos pases a la reserva por su número: uno llega como «DEPOSIT» a secas, el otro como «REMOTE ONLINE DEPOSIT» (nombra a
-- alguien); y un pase sin número ni nombre («ONLINE TRANSFER TO SAVINGS») con su otro lado «ONLINE TRANSFER FROM CHECKING»
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-k6.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-02", "monto": "-300.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 11", "tipo": "XFER"},
  {"id": "C02", "fecha": "2026-11-09", "monto": "-400.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 12", "tipo": "XFER"},
  {"id": "C03", "fecha": "2026-11-16", "monto": "-500.00", "descripcion": "ONLINE TRANSFER TO SAVINGS", "tipo": "XFER"}],
  "saldo": "48800.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-k6.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-03", "monto": "300.00", "descripcion": "DEPOSIT"},
  {"id": "R02", "fecha": "2026-11-10", "monto": "400.00", "descripcion": "REMOTE ONLINE DEPOSIT #12"},
  {"id": "R03", "fecha": "2026-11-17", "monto": "500.00", "descripcion": "ONLINE TRANSFER FROM CHECKING", "tipo": "XFER"}],
  "saldo": "1200.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva;
select fn_banco_casar_todo() -> 'por_regla' ->> 'transferencias' as r3;
