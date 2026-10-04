-- [Pestaña 1] lo fijo: apertura mínima, tarjetas (débito, Gold, Blue y la Visa PERSONAL de Edgar en 2900), mapeos, CED, préstamo
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque 4b)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "2530", "monto": "-31415.26"}, {"cuenta": "3900", "monto": "-18584.74"}]}') ->> 'numero' as apertura;
select fn_tarjeta_alta('9420', '1010', 'Chase débito (Edgar)') ->> 'cuenta' as debito,
       fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold') ->> 'cuenta' as gold,
       fn_tarjeta_alta('2009', '2100-2009', 'Amex Blue') ->> 'cuenta' as blue;
select fn_tarjeta_alta('6666', '2900', 'Edgar · Visa personal') ->> 'cuenta' as visa_personal;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta', fn_mapeo_tipo_proyecto('comercial', '4020') ->> 'cuenta',
       fn_mapeo_tipo_proyecto('servicio', '4030') ->> 'cuenta';
select fn_mapeo_categoria('material', '5100') ->> 'cuenta';
select fn_mapeo_metodo_pago('debito', 'tarjeta') ->> 'forma', fn_mapeo_metodo_pago('credito', 'tarjeta') ->> 'forma',
       fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor') ->> 'forma';
select fn_proveedor_alta('CED', 'Net 30', array['Consolidated Electrical Distributors']) is not null as ced;
select fn_prestamo_guardar('{"prestamista": "Ford Credit", "descripcion": "F-150 2024", "principal": "52000.00", "tasa_anual": "6.99",
  "cuota": "1029.33", "primer_pago": "2024-03-15", "dia_pago": 15, "plazo_meses": 60, "saldo_inicial": "31415.26",
  "saldo_inicial_al": "2026-09-30", "descriptor": "FORD CREDIT|FORD MOTOR CR"}') ->> 'prestamista' as prestamo;
-- la cuenta personal de Edgar dada de alta a propósito
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as personal;
-- tickets: CED a cuenta (1,245.60), Home Depot con la débito (156.78), Home Depot con la Gold (312.40)
insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
values ('oficina-nch-7xq2', 'recibos/atq-ced-1101.jpg', 1245.60, 'CED', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-11-01 09:00-04', '2026-11-01', 'material', 'S-ATQ-1', 'cuenta_proveedor', null),
       ('casa-perez-k3m9', 'recibos/atq-hd-1102.jpg', 156.78, 'Home Depot', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-11-02 10:00-04', '2026-11-02', 'material', 'HD-ATQ-2', 'debito', '9420'),
       ('oficina-nch-7xq2', 'recibos/atq-hd-1103.jpg', 312.40, 'Home Depot', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-11-03 15:00-04', '2026-11-03', 'material', 'HD-ATQ-3', 'credito', '2013');

-- [Pestaña 2] los puentes (las facturas #1101 5,000.00, #1102 3,200.50 y #1103 8,000.00 y los tickets al libro)
select fn_puentes_correr() -> 'errores' as errores;
select num, monto from facturas order by id;

-- [Pestaña 3] el QFX de noviembre de Chase: de todo
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-2026-11-ataque.csv", "filas": [
  {"id": "A01", "fecha": "2026-11-02", "monto": "5000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 101", "tipo": "XFER"},
  {"id": "A02", "fecha": "2026-11-03", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 102", "tipo": "XFER"},
  {"id": "A03", "fecha": "2026-11-04", "monto": "8000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...5512 TRANSACTION#: 103", "tipo": "XFER"},
  {"id": "A04", "fecha": "2026-11-05", "monto": "-1500.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 104", "tipo": "XFER"},
  {"id": "A05", "fecha": "2026-11-06", "monto": "-750.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 5555 11/06"},
  {"id": "A06", "fecha": "2026-11-07", "monto": "-400.00", "descripcion": "PAYMENT TO CHASE CARD ENDING IN 6666 11/07"},
  {"id": "A07", "fecha": "2026-11-08", "monto": "-1000.00", "descripcion": "ONLINE TRANSFER TO EDGAR M PERSONAL", "tipo": "XFER"},
  {"id": "A08", "fecha": "2026-11-09", "monto": "1000.00", "descripcion": "ONLINE TRANSFER FROM EDGAR M PERSONAL", "tipo": "XFER"},
  {"id": "A09", "fecha": "2026-11-10", "monto": "3200.50", "descripcion": "ZELLE PAYMENT FROM EDGAR MARTINEZ BAC123"},
  {"id": "A10", "fecha": "2026-11-11", "monto": "-300.00", "descripcion": "ZELLE PAYMENT TO EDGAR MARTINEZ JPM99X"},
  {"id": "A11", "fecha": "2026-11-12", "monto": "-200.00", "descripcion": "ATM WITHDRAWAL 11/12 MIAMI FL", "tipo": "ATM"},
  {"id": "A12", "fecha": "2026-11-15", "monto": "-1029.33", "descripcion": "FORD CREDIT ACH PMT"},
  {"id": "A13", "fecha": "2026-11-14", "monto": "-312.40", "descripcion": "AMEX EPAYMENT ACH PMT"},
  {"id": "A14", "fecha": "2026-11-16", "monto": "45.10", "descripcion": "HOME DEPOT #6345 MIAMI FL", "memo": "11/15 HOME DEPOT REFUND CARD 9420"},
  {"id": "A15", "fecha": "2026-11-17", "monto": "-15.00", "descripcion": "MONTHLY SERVICE FEE", "tipo": "SRVCHG"},
  {"id": "A16", "fecha": "2026-11-18", "monto": "3200.50", "descripcion": "CREDIT", "memo": "INTEREST PAYMENT"},
  {"id": "A17", "fecha": "2026-11-20", "monto": "-1245.60", "descripcion": "CHECK 1050", "cheque": "1050", "tipo": "CHECK"},
  {"id": "A18", "fecha": "2026-11-21", "monto": "5000.00", "descripcion": "REMOTE ONLINE DEPOSIT 1"},
  {"id": "A19", "fecha": "2026-11-23", "monto": "-88.10", "descripcion": "LOWES #01234 MIAMI FL", "memo": "11/22 LOWES #01234 MIAMI FL CARD 9420"},
  {"id": "A20", "fecha": "2026-11-24", "monto": "-2500.00", "descripcion": "ONLINE TRANSFER TO ACCT ...8899 TRANSACTION#: 120", "tipo": "XFER"},
  {"id": "A21", "fecha": "2026-11-25", "monto": "8000.00", "descripcion": "ONLINE TRANSFER FROM ACCT ...8899 TRANSACTION#: 121", "tipo": "XFER"},
  {"id": "A22", "fecha": "2026-11-26", "monto": "45.10", "descripcion": "DEPOSIT", "memo": "REFUND"}
  ], "saldo": "60000.00", "saldo_al": "2026-11-30"}') - 'archivo' - 'siguiente' as chase;
-- la Gold de noviembre: la compra del 3 y el pago recibido
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "2100-2013", "nombre": "gold-2026-11-ataque.csv", "filas": [
  {"id": "G01", "fecha": "2026-11-04", "monto": "-312.40", "descripcion": "THE HOME DEPOT #6311"},
  {"id": "G02", "fecha": "2026-11-13", "monto": "312.40", "descripcion": "PAYMENT RECEIVED - THANK YOU"}],
  "saldo": "0.00", "saldo_al": "2026-11-22"}') ->> 'filas_nuevas' as gold;
select fn_banco_casar_todo() - 'ms' - 'propuestas' as casar;
