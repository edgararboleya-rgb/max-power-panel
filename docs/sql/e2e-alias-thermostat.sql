-- =====================================================================
-- E2e · El alias «Thermostat» apuntaba a SINGLE POLE SWITCH (visto el 14/09
-- en el export). Un termostato no es un switch: se le quita ese destino.
-- Si tienes un ítem de termostato en el catálogo, ponlo en la segunda
-- sentencia; si no, se borra el alias y la fila llegará «sin mapear»
-- (mejor que cotizar un switch de $2.97 por un termostato).
-- =====================================================================
-- ver antes
select * from alias_takeoff where alias ilike '%thermostat%' or item ilike '%thermostat%';

-- opción A: borrar el alias malo
delete from alias_takeoff where alias ilike 'thermostat%' and item ilike 'single pole switch%';

-- opción B (en vez de A): redirigirlo a tu ítem de termostato, con su nombre EXACTO
-- update alias_takeoff set item = 'NOMBRE EXACTO DEL ITEM', codigo = '10-DEV', nota = 'corregido 15/09'
--  where alias ilike 'thermostat%';
