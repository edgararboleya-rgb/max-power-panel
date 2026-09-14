-- =====================================================================
-- E13c y E13d · Lo que faltaba de la auditoría de la fórmula
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
-- NO mueve ningún precio: mientras no apuntes meses de obra ni toques el
-- desglose, todo se calcula exactamente igual que hoy.
-- =====================================================================

-- E13c · DE QUÉ SE COMPONE EL % DE BENEFICIOS
-- Tenerlo como un número suelto no se puede auditar: no sabes si el 25 %
-- cubre lo que de verdad te cuesta un empleado por encima del salario.
-- Ahora se desglosa en la app (⚙ Escenarios → «¿De qué se compone…?») y
-- el total sale de sumar las partes.
alter table escenarios add column if not exists benefits_detalle jsonb;

comment on column escenarios.benefits_detalle is
  'E13c · Las partes del % de beneficios: FICA, FUTA, paro de Florida, workers comp, GL, vacaciones, seguro medico, otros. El campo benefits es la suma.';

-- E13d · ESCALACIÓN PARA OBRAS LARGAS
-- Una obra de año y medio no se paga a precios de hoy. El gasto se
-- reparte a lo largo de la obra, así que el punto medio está a la mitad:
--   escalación = subida anual × años de obra ÷ 2
-- Con 4 % al año y 18 meses son 3 % sobre el costo directo.
alter table estimados add column if not exists meses_obra     integer;
alter table estimados add column if not exists escalacion_pct numeric;

comment on column estimados.meses_obra is
  'E13d · Cuanto dura la obra. Vacio = no se aplica escalacion (como hasta hoy).';

-- La subida anual de referencia. 4 % es un punto de partida razonable
-- para salarios y material en Florida; cámbialo cuando quieras.
insert into config_estimador (clave, valor) values ('escalacion_anual', 0.04)
  on conflict (clave) do nothing;

-- Comprobar
select clave, valor from config_estimador where clave in ('escalacion_anual','misc_pct','markup_cot_pct') order by clave;


-- =====================================================================
-- DESHACER
-- =====================================================================
--   alter table escenarios drop column if exists benefits_detalle;
--   alter table estimados  drop column if exists meses_obra, drop column if exists escalacion_pct;
--   delete from config_estimador where clave = 'escalacion_anual';
