-- =====================================================================
-- E13a · Las cotizaciones del proveedor no pagan misceláneas
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- ESTE SQL ES OPCIONAL. La app ya funciona sin él: marcar una línea como
-- cotización se guarda dentro de `lineas_material`, que ya existe. La
-- columna de abajo sirve solo para poder darle a las cotizaciones un
-- markup distinto al del material EN UN ESTIMADO CONCRETO.
--
-- Si lo quieres para todos los estimados a la vez, no hace falta esta
-- columna: basta una fila en config_estimador (abajo del todo).
--
-- No toca ningún precio ni mueve ningún bid: mientras no marques una
-- línea como cotización, todo se calcula exactamente igual que antes.
-- =====================================================================

alter table estimados add column if not exists markup_cot_pct numeric;

comment on column estimados.markup_cot_pct is
  'E13a · Markup de las lineas marcadas como cotizacion del proveedor. NULL = el mismo markup del material (lo de siempre).';


-- Para ponerlo igual en todos los estimados (5 % sobre las cotizaciones):
--   insert into config_estimador (clave, valor) values ('markup_cot_pct', 0.05)
--     on conflict (clave) do update set valor = excluded.valor;
-- Para quitarlo:
--   delete from config_estimador where clave = 'markup_cot_pct';


-- DESHACER
--   alter table estimados drop column if exists markup_cot_pct;
