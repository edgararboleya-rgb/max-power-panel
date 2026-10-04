-- [Pestaña 1] (final 4c, L05) apertura; mapeo; la personal ····7781 DADA DE ALTA
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (final 4c L05)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta';
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') - 'creado_el' - 'cambiado_el' as alta1;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] Chase de noviembre: un retiro y un depósito con la personal; el depósito por lo que explica la factura #1101 (5,000.00)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov-l05.csv", "filas": [
  {"id": "P01", "fecha": "2026-11-03", "monto": "-500.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 11", "tipo": "XFER"},
  {"id": "P02", "fecha": "2026-11-04", "monto": "5000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 12", "tipo": "XFER"},
  {"id": "P03", "fecha": "2026-11-10", "monto": "-300.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 13", "tipo": "XFER"}],
  "saldo": "54200.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase;
select fn_banco_casar_todo() -> 'por_motivo' as casar;
-- el primer retiro, con su botón sin motivo (distribución): casado con la personal dada de alta
select fn_banco_clasificar((select id from movimientos_banco where id_externo = 'P01'), '[{"cuenta": "3200"}]') ->> 'estado' as p01_3200;

-- [Pestaña 4] la BAJA de la personal (con su motivo), sin «Casar»
select fn_banco_cuenta_personal('7781', null, false, 'L05: la cerró') - 'creado_el' - 'cambiado_el' as baja;

-- [Pestaña 5] y la vuelve a dar de ALTA (otra vez la suya), sin «Casar»
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar (otra vez)') - 'creado_el' - 'cambiado_el' as alta2;
