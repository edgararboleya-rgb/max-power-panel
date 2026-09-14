-- =====================================================================
-- E13b · El sales tax de tu condado
-- Supabase → SQL Editor. Corre SOLO la línea que decidas.
--
-- Tus tres escenarios (A, B y C) tienen el sales tax al 7,00 %.
-- Hillsborough County está en 7,5 %: 6 % del estado + 1,5 % del condado
-- (0,5 % escuelas + 0,5 % indigent care + 0,5 % infraestructura).
-- Fuente: Florida DOR, forma DR-15DSS.
--
-- Medio punto sobre todo el material de cada trabajo. Con $60.000 de
-- material son $300 que pagas tú y no cobraste. En un año con $500.000
-- de material, $2.500.
--
-- OJO, y esto puede jugar a tu favor: el 1,5 % del condado solo se
-- aplica a los primeros $5.000 de CADA artículo. El 6 % del estado se
-- aplica a todo. Así que en un switchgear de $48.000 que llega como un
-- solo artículo, el tipo efectivo NO es 7,5 % sino mucho más cerca del
-- 6 %. Esto conviene confirmarlo con tu contador antes de tocar nada:
-- es una regla del estado, no un invento de la app.
-- =====================================================================

-- OPCIÓN 1 — Hillsborough al día (7,5 %) en tus tres escenarios.
-- Esta es la correcta si compras el material en Hillsborough y facturas
-- por artículos pequeños, que es lo normal en residencial y service.
--   update escenarios set tax_material = 0.075 where id in ('A','B','C');

-- OPCIÓN 2 — dejarlo como está (7,00 %). Tiene sentido si la mayor parte
-- de tu material entra en compras grandes donde el surtax se corta a los
-- primeros $5.000, porque entonces el tipo efectivo baja del 7,5 %.

-- El de MXP MEP ya está en 6,5 % (Orange County, que es donde están los
-- parques). Si el trabajo con Roger cae en otro condado, cámbialo:
--   update escenarios set tax_material = 0.07 where id = 'MEP';   -- Osceola
--   update escenarios set tax_material = 0.065 where id = 'MEP';  -- Orange

-- Y para un trabajo suelto fuera de tu condado no hace falta tocar el
-- escenario: en el resumen del estimado, el ✎ del sales tax lo cambia
-- solo para ese estimado.

-- Comprobación:
select id, nombre, round(tax_material * 100, 2) as sales_tax_pct
  from escenarios order by (id = 'MEP'), id;
