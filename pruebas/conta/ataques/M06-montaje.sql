-- [Pestaña 1] (final 4d, M06; sobre la base M) Plaid trae a Chase, el 21-oct, +8,000.00 «Online Transfer from SAV» (el nombre corto:
-- dinero desde una cuenta de ahorro, sin número) por lo mismo que la #1103 tiene abierto; Casar
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1010", "nombre": "plaid-m06", "filas": [
  {"id": "PL-M6", "fecha": "2026-10-21", "plaid_monto": "-8000.00", "descripcion": "Online Transfer from SAV", "pendiente": false}]}')
       ->> 'filas_nuevas' as plaid;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
