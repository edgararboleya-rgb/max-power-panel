-- [Pestaña 1] (final 4c, L17) la apertura de verdad (balanza y mapeo) y su conciliación de apertura con un depósito en tránsito del
-- 30-sep por 3,200.00 (el cheque de un cliente); la personal ····7781 dada de alta
select fn_apertura_balanza_cargar('docs/apertura/balanza-l17.csv', '[
  {"cuenta_qb": "Chase Chk 4392", "debe": "52,146.01"},
  {"cuenta_qb": "Retained Earnings", "haber": "52,146.01"},
  {"cuenta_qb": "Net Income", "saldo": "0.00"},
  {"cuenta_qb": "TOTAL ASSETS", "saldo": "52,146.01"},
  {"cuenta_qb": "Total Liabilities", "saldo": "0.00"}]') ->> 'cuadra';
select fn_apertura_mapeo_qb('Chase Chk 4392', '1010') ->> 'cuenta', fn_apertura_mapeo_qb('Retained Earnings', '3900') ->> 'cuenta';
select fn_apertura('2026-09-30', 'docs/apertura/balanza-l17.csv') ->> 'asiento';
select fn_conciliacion_apertura('1010', '48,946.01', '[
  {"fecha": "2026-09-30", "monto": "3,200.00", "descripcion": "Depósito del 30-sep (cheque de NCH)"}]') - 'conciliacion';
select fn_conciliacion_confirmar((select id from conciliaciones where cuenta = '1010' and tipo = 'apertura')) ->> 'estado';
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;

-- [Pestaña 2] el 2-oct Chase trae +3,200.00 «ONLINE TRANSFER FROM CHK ...7781» (Edgar desde su cuenta personal; el cheque de NCH
-- todavía no se acreditó). Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-l17.csv", "filas": [
  {"id": "A1", "fecha": "2026-10-02", "monto": "3200.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 91", "tipo": "XFER"}],
  "saldo": "52146.01", "saldo_al": "2026-10-02"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar;
