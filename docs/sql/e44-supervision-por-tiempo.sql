-- v258 (06/10/2026) · Supervisión por TIEMPO, no por % del labor.
-- Sin cambio de esquema: va dentro de gastos_generales (jsonb) como
-- sup_hsem (horas a la semana) × sup_sem (semanas) × sup_hora ($/h con cargas).
-- El «pm» en dinero de antes se sigue leyendo y se suma.
--
-- 1) Escenario MEP: cuadrilla productiva de 5 con las tarifas de siempre
--    (foreman trabajando 20 %, 2 journeymen 40 %, 2 helpers 40 %), beneficios
--    de vuelta al 25 % (desglose que suma 25). Sin rol de supervisión: el
--    superintendent va por tiempo en Otros gastos.
update escenarios set
  mezcla = '[{"rol":"Foreman","tarifa":45,"pct":0.20,"tipo":"prod"},{"rol":"Journeyman","tarifa":35,"pct":0.40,"tipo":"prod"},{"rol":"Helper","tarifa":20,"pct":0.40,"tipo":"prod"}]'::jsonb,
  foreman = 45, pct_foreman = 0.20, journeyman = 35, pct_journeyman = 0.40, helper = 20, pct_helper = 0.40,
  benefits = 0.25,
  benefits_detalle = '[{"k":"fica","pct":7.65},{"k":"futa","pct":0.1},{"k":"suta","pct":0.3},{"k":"wc","pct":2.97},{"k":"gl","pct":1.0},{"k":"pto","pct":4.2},{"k":"salud","pct":6.78},{"k":"otros","pct":2.0}]'::jsonb
where id = 'MEP';
-- 2) Mariners #47: 6 visitas × 10 h × $75 = $4,500 de supervisión
update estimados set gastos_generales = coalesce(gastos_generales, '{}'::jsonb) || '{"sup_hsem":10,"sup_sem":6,"sup_hora":75}'::jsonb
where id = 47;
