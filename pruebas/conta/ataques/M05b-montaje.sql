-- [Pestaña 1] (final 4d, M05b; sobre la base M) lo de M05 pero con el QFX de Chase del MES ENTERO: los dos tickets de la débito
-- (Home Depot 250.00 el 14-oct, Graybar 180.00 el 15-oct) y, en el mismo archivo, el pase a la reserva (14-oct), el pase a la
-- personal (15-oct) y las dos compras (16 y 17-oct); Casar
insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
values ('casa-perez-k3m9', 'recibos/m05b-hd.jpg', 250.00, 'THE HOME DEPOT', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-10-14 10:00-04', '2026-10-14', 'material', 'M5B-HD', 'debito', '9420'),
       ('casa-perez-k3m9', 'recibos/m05b-gb.jpg', 180.00, 'GRAYBAR ELECTRIC', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-10-15 10:00-04', '2026-10-15', 'material', 'M5B-GB', 'debito', '9420');
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 2]
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m05b.csv", "filas": [
  {"id": "M5B-R", "fecha": "2026-10-14", "monto": "-250.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 12", "tipo": "XFER"},
  {"id": "M5B-P", "fecha": "2026-10-15", "monto": "-180.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 13", "tipo": "XFER"},
  {"id": "M5B-H", "fecha": "2026-10-16", "monto": "-250.00", "descripcion": "HOME DEPOT #6345 MIAMI FL", "tipo": "DEBIT"},
  {"id": "M5B-G", "fecha": "2026-10-17", "monto": "-180.00", "descripcion": "GRAYBAR ELECTRIC CO MIAMI FL", "tipo": "DEBIT"}]}')
       ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_regla' as casar;
