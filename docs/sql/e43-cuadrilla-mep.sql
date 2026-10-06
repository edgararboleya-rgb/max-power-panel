-- v257 (06/10/2026) · Mano de obra por composición de cuadrilla.
-- No cambia el esquema: `mezcla` (jsonb) ya existía en escenarios y estimados.
-- Cada rol lleva ahora `tipo`: "prod" (se reparte las horas del estimado; sus %
-- suman 100) o "sup" (supervisión: % adicional encima). Sin tipo = productivo.
--
-- 1) La cuadrilla nueva del escenario MEP (valores iniciales de Edgar).
--    El $/h ya es con cargas (o lo que factura el sub) → beneficios en 0.
update escenarios set
  mezcla = '[{"rol":"Electrician","tarifa":45,"pct":0.60,"tipo":"prod"},{"rol":"Helper","tarifa":28,"pct":0.40,"tipo":"prod"},{"rol":"Foreman","tarifa":55,"pct":0.30,"tipo":"sup"},{"rol":"Superintendent","tarifa":65,"pct":0.15,"tipo":"sup"}]'::jsonb,
  foreman = 45, pct_foreman = 0.60, journeyman = 28, pct_journeyman = 0.40, helper = 55, pct_helper = 0.30,
  benefits = 0,
  benefits_detalle = '[{"k":"fica","pct":0},{"k":"futa","pct":0},{"k":"suta","pct":0},{"k":"wc","pct":0},{"k":"gl","pct":0},{"k":"pto","pct":0},{"k":"salud","pct":0},{"k":"otros","pct":0}]'::jsonb
where id = 'MEP';

-- 2) Los estimados MEP que ya estaban (NCH #38 y Peninsula #44, congelado) se
--    quedan con la cuadrilla vieja como propia, para que no se muevan un centavo.
--    Mariners #47 hereda la nueva, que es lo que se pidió.
update estimados set mezcla = '[{"rol":"Superintendent","tarifa":60,"pct":0.10,"tipo":"prod"},{"rol":"Foreman","tarifa":45,"pct":0.15,"tipo":"prod"},{"rol":"Journeyman","tarifa":35,"pct":0.40,"tipo":"prod"},{"rol":"Helper","tarifa":20,"pct":0.35,"tipo":"prod"}]'::jsonb,
  benefits_pct = coalesce(benefits_pct, 0.25)
where id in (38, 44) and (mezcla is null or jsonb_array_length(mezcla)=0);
