-- [Pestaña 1] (final 4d, M08; sobre la base M) el préstamo de la F-150 (Ally: su saldo de la apertura, todo en 2530, el largo plazo,
-- como lo trae QuickBooks) y el número de su cuenta (····5566) dado de alta como de la empresa con el lote vacío, a 2520 (la
-- «corriente» de los préstamos de vehículo: la que Edgar asocia a la cuota)
select fn_prestamo_guardar(jsonb_build_object('prestamista', 'ALLY AUTO', 'descripcion', 'F-150', 'principal', '52000.00',
         'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15, 'plazo_meses', 60,
         'saldo_inicial', '31415.26', 'saldo_inicial_al', '2026-09-30', 'cuenta_banco', '1010'))->>'id' as prestamo;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "2520", "ultimos4": "5566", "confirmo_cuenta": true, "nombre": "Ally ····5566", "filas": []}') -> 'avisos' as ally;

-- [Pestaña 2] Chase de octubre: la cuota del 15-oct, que el banco describe con el número del préstamo; Casar
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-m08.csv", "filas": [
  {"id": "M8C", "fecha": "2026-10-15", "monto": "-1029.33", "descripcion": "ONLINE TRANSFER TO ACCT ...5566 ALLY AUTO LOAN", "tipo": "XFER"}],
  "saldo": "48970.67", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
