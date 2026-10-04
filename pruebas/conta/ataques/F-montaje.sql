-- [Pestaña 1] apertura mínima, Gold y Blue dadas de alta; la reserva con su número conocido
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque F)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold, fn_tarjeta_alta('2009', '2100-2009', 'Amex Blue') ->> 'cuenta' as blue;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;

-- [Pestaña 2] un pase de Chase a una cuenta que el banco nombra por su nombre (sin número): «a la cuenta personal de Edgar»
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-f.csv", "filas": [
  {"id": "F01", "fecha": "2026-11-08", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO EDGAR M PERSONAL", "tipo": "XFER"}],
  "saldo": "49000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
