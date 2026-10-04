-- [Pestaña 1] (final 4c, L06) apertura; la Gold (····2013) y la Blue (····2009) de la empresa; la Amex Platinum PERSONAL de Edgar
-- (····1006) dada de alta en 2900, del MISMO banco (American Express)
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L06)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold, fn_tarjeta_alta('2009', '2100-2009', 'Amex Blue') ->> 'cuenta' as blue;
select fn_tarjeta_alta('1006', '2900', 'Edgar · Amex Platinum personal') ->> 'cuenta' as platinum_personal;

-- [Pestaña 2] Chase paga dos veces a «AMEX»: (a) 1,500.00 nombrando los 4 últimos de la Platinum PERSONAL sueltos («ACH PMT 1006»);
-- (b) 640.00 con «CARD ENDING 1006». La Gold trae dos pagos recibidos por lo mismo (Edgar la pagó desde su cuenta personal). Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l06.csv", "filas": [
  {"id": "C01", "fecha": "2026-11-08", "monto": "-1500.00", "descripcion": "AMEX EPAYMENT ACH PMT 1006"},
  {"id": "C02", "fecha": "2026-11-12", "monto": "-640.00", "descripcion": "AMERICAN EXPRESS PAYMENT CARD ENDING 1006"}],
  "saldo": "47860.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-nov-l06.csv", "filas": [
  {"id": "G01", "fecha": "2026-11-09", "monto": "1500.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"},
  {"id": "G02", "fecha": "2026-11-13", "monto": "640.00", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_casar_todo() -> 'por_regla' as casar;
