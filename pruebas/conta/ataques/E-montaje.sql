-- [Pestaña 1] apertura mínima, mapeos y facturas al libro (#1101 5,000.00 y #1103 8,000.00 abiertas), la débito y un ticket de Home Depot
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque E)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('9420', '1010', 'Chase débito (Edgar)') ->> 'cuenta' as debito;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta', fn_mapeo_tipo_proyecto('comercial', '4020') ->> 'cuenta';
select fn_mapeo_categoria('material', '5100') ->> 'cuenta';
select fn_mapeo_metodo_pago('debito', 'tarjeta') ->> 'forma';
insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
values ('casa-perez-k3m9', 'recibos/atq-e-hd.jpg', 5156.78, 'Home Depot', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-11-02 10:00-04', '2026-11-02', 'material', 'HD-E-1', 'debito', '9420');

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] noviembre: intereses por 8,000.00 (= la #1103), una devolución de Home Depot por 5,000.00 (= la #1101), y lo de la
-- línea de crédito (····8899): un retiro de ella y un pago a ella
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-e.csv", "filas": [
  {"id": "E01", "fecha": "2026-11-10", "monto": "8000.00", "descripcion": "CREDIT", "memo": "INTEREST PAYMENT"},
  {"id": "E02", "fecha": "2026-11-12", "monto": "5000.00", "descripcion": "HOME DEPOT #6345 MIAMI FL", "memo": "11/11 HOME DEPOT RETURN CARD 9420"},
  {"id": "E03", "fecha": "2026-11-14", "monto": "4000.00", "descripcion": "ONLINE TRANSFER FROM ACCT ...8899 TRANSACTION#: 501", "tipo": "XFER"},
  {"id": "E04", "fecha": "2026-11-20", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO ACCT ...8899 TRANSACTION#: 502", "tipo": "XFER"}],
  "saldo": "60000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
