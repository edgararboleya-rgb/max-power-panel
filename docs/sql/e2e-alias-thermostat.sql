-- =====================================================================
-- E2e · El alias «Thermostat» apunta a SINGLE POLE SWITCH. Su nota dice que
-- fue A PROPÓSITO: «solo la caja y el cable, el termostato lo pone HVAC» —
-- o sea, cobra la caja, el cable y la mano de obra de un punto, no el
-- aparato. Si eso es lo que quieres, NO corras nada. Si prefieres que
-- llegue «sin mapear» para decidirlo cada vez, opción A; si tienes un ítem
-- propio (p. ej. una salida de termostato con «5 #18 THERMOSTAT WIRE»),
-- opción B con su nombre EXACTO.
-- =====================================================================
-- ver antes
select * from alias_takeoff where alias ilike '%thermostat%' or item ilike '%thermostat%';

-- opción A: borrar el alias malo
delete from alias_takeoff where alias ilike 'thermostat%' and item ilike 'single pole switch%';

-- opción B (en vez de A): redirigirlo a tu ítem de termostato, con su nombre EXACTO
-- update alias_takeoff set item = 'NOMBRE EXACTO DEL ITEM', codigo = '10-DEV', nota = 'corregido 15/09'
--  where alias ilike 'thermostat%';
