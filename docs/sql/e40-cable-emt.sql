-- =====================================================================
-- e40 · EL CABLEADO «EMT / tubería» SE PUEDE GUARDAR (06/10, Mariners)
-- La pantalla ofrece cuatro opciones de cableado (romex, mc, mixto, emt)
-- pero la restricción de la base solo aceptaba tres: elegir «EMT / tubería»
-- fallaba al guardar. Se amplía la lista. No toca ningún dato.
-- Ya corrido en Supabase el 06/10/2026. Se puede correr dos veces.
-- =====================================================================
alter table estimados drop constraint if exists estimados_cable_check;
alter table estimados add constraint estimados_cable_check
  check (cable is null or cable in ('romex','mc','mixto','emt'));

-- Comprobación (una sola fila)
select case when pg_get_constraintdef(oid) like '%emt%' then '✓ estimados.cable acepta emt' else '✗ sigue sin emt' end as cable
from pg_constraint where conname = 'estimados_cable_check';
