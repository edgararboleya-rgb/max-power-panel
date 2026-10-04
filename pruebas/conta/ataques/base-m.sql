-- [Pestaña 1] (final 4d, M*) la apertura de QuickBooks al 30-sep (Chase 50,000.00; el préstamo de la F-150 en 2530), su mapeo,
-- los mapeos de la app, la débito de Chase (····9420), la reserva por su número (····1097) y la personal de Edgar (····7781)
select fn_apertura_balanza_cargar('docs/apertura/balanza-2026-09-30.csv', '[
  {"cuenta_qb": "Chase Chk 4392", "debe": "50,000.00"},
  {"cuenta_qb": "Ally Auto Loan F-150", "haber": "31,415.26"},
  {"cuenta_qb": "Retained Earnings", "haber": "18,584.74"},
  {"cuenta_qb": "Net Income", "saldo": "0.00"},
  {"cuenta_qb": "TOTAL ASSETS", "saldo": "50,000.00"},
  {"cuenta_qb": "Total Liabilities", "saldo": "31,415.26"}]') ->> 'cuadra' as cuadra;
select fn_apertura_mapeo_qb('Chase Chk 4392', '1010') ->> 'cuenta', fn_apertura_mapeo_qb('Ally Auto Loan F-150', '2530') ->> 'cuenta',
       fn_apertura_mapeo_qb('Retained Earnings', '3900') ->> 'cuenta';
select fn_apertura('2026-09-30', 'docs/apertura/balanza-2026-09-30.csv') ->> 'asiento' as apertura;
select fn_mapeo_tipo_proyecto('residencial', '4010') ->> 'cuenta', fn_mapeo_tipo_proyecto('comercial', '4020') ->> 'cuenta',
       fn_mapeo_tipo_proyecto('servicio', '4030') ->> 'cuenta';
select fn_mapeo_categoria('material', '5100') ->> 'cuenta', fn_mapeo_metodo_pago('debito', 'banco', '1010') ->> 'forma';
select fn_tarjeta_alta('9420', '1010', 'Edgar · Chase débito') ->> 'cuenta' as debito;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030 ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_cuenta_personal('7781', 'Edgar · cuenta personal (Chase)') ->> 'ultimos4' as personal;

-- [Pestaña 2]
select fn_puentes_correr() -> 'errores' as errores;

-- [Pestaña 3] la conciliación de apertura (nada en tránsito) y su confirmación
select fn_conciliacion_apertura('1010', '50,000.00', '[]') ->> 'diferencia' as dif_apertura;
select fn_conciliacion_confirmar((select id from conciliaciones where cuenta = '1010' and tipo = 'apertura')) ->> 'estado' as apertura_1010;
