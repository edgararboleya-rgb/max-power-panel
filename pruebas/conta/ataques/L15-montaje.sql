-- [Pestaña 1] (final 4c, L15) el nombre de QuickBooks de la Gold lleva «1007» (así la nombra QuickBooks, no es su número de banco)
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L15)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold;
select fn_apertura_mapeo_qb('1007', '2100-2013', 'L15: la Gold en QuickBooks') ->> 'cuenta' as mapeo_gold;
select fn_apertura_mapeo_qb('Chase Chk 4392', '1010', 'L15') ->> 'cuenta' as mapeo_chase;

-- [Pestaña 2] Chase: un pase a una cuenta ····1007 que NO es la Gold (la de un subcontratista, o la personal de Edgar en otro banco)
-- y un depósito desde ella; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l15.csv", "filas": [
  {"id": "Q1", "fecha": "2026-11-04", "monto": "-800.00", "descripcion": "ONLINE TRANSFER TO CHK ...1007 TRANSACTION#: 71", "tipo": "XFER"},
  {"id": "Q2", "fecha": "2026-11-05", "monto": "1200.00", "descripcion": "ONLINE TRANSFER FROM CHK ...1007 TRANSACTION#: 72", "tipo": "XFER"}],
  "saldo": "50400.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
