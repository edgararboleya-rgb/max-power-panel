-- [Pestaña 1] (final 4c, L13) el emisor que nombra el banco: la Gold (Amex, ····2013) de la empresa
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L13)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;

-- [Pestaña 2] Chase paga una tarjeta de CHASE («CHASE CREDIT CRD AUTOPAY») y una de Bank of America («… CREDIT CARD BILL PAYMENT»):
-- ninguna es la Gold (Amex). La Gold trae dos pagos recibidos por lo mismo (Edgar la pagó desde su cuenta personal). Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l13.csv", "filas": [
  {"id": "C1", "fecha": "2026-11-08", "monto": "-640.00", "descripcion": "CHASE CREDIT CRD AUTOPAY PPD ID: 4760039224"},
  {"id": "C2", "fecha": "2026-11-12", "monto": "-910.00", "descripcion": "BANK OF AMERICA CREDIT CARD BILL PAYMENT"}],
  "saldo": "48450.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-nov-l13.csv", "filas": [
  {"id": "G1", "fecha": "2026-11-09", "monto": "640.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"},
  {"id": "G2", "fecha": "2026-11-13", "monto": "910.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_casar_todo() -> 'por_regla' as casar;
