-- [Pestaña 1] apertura mínima; la personal ····7781 dada de alta
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque I)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as alta;

-- [Pestaña 2] un lote de Plaid (los montos al revés, como los da Plaid; descripciones en minúsculas)
select fn_banco_importar_filas('{"origen": "plaid", "cuenta": "1010", "nombre": "plaid 1010 nov", "plaid_saldo": "49200.00", "saldo_al": "2026-11-30", "filas": [
  {"id": "pl-1", "fecha": "2026-11-05", "plaid_monto": "500.00", "descripcion": "Online Transfer to CHK ...7781 transaction#: 9001 11/05"},
  {"id": "pl-2", "fecha": "2026-11-06", "plaid_monto": "-300.00", "descripcion": "Online Transfer from SAV ...1097 transaction#: 9002 11/06"},
  {"id": "pl-3", "fecha": "2026-11-07", "plaid_monto": "-1000.00", "descripcion": "Online Transfer from CHK ...7781 transaction#: 9003 11/07", "memo": "para la nomina"}]}') - 'archivo' - 'siguiente' as plaid;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
