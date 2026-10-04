-- [Pestaña 1] (final 4d, M05; sobre la base M) dos tickets de la débito de Chase (····9420) que sube la cuadrilla: 250.00 en
-- Home Depot el 14-oct y 180.00 en Graybar el 15-oct (entran al libro por su puente: Dr 5100 / Cr 1010)
insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
values ('casa-perez-k3m9', 'recibos/m05-hd.jpg', 250.00, 'THE HOME DEPOT', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-10-14 10:00-04', '2026-10-14', 'material', 'M05-HD', 'debito', '9420'),
       ('casa-perez-k3m9', 'recibos/m05-gb.jpg', 180.00, 'GRAYBAR ELECTRIC', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-10-15 10:00-04', '2026-10-15', 'material', 'M05-GB', 'debito', '9420');
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 2] Plaid trae el día: el 14-oct un pase de 250.00 a la RESERVA (····1097, de la empresa) y el 15-oct uno de 180.00 a
-- la cuenta PERSONAL de Edgar (····7781, dada de alta); las compras con la débito postean días después; Casar
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1010", "nombre": "plaid-m05", "filas": [
  {"id": "PL-M5R", "fecha": "2026-10-14", "plaid_monto": "250.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 12", "pendiente": false},
  {"id": "PL-M5P", "fecha": "2026-10-15", "plaid_monto": "180.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 13", "pendiente": false}]}')
       ->> 'filas_nuevas' as plaid;
select fn_banco_casar_todo() -> 'por_regla' as casar;
