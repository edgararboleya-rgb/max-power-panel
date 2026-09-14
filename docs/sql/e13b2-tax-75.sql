-- =====================================================================
-- E13b (decidido) · El sales tax de Hillsborough al día
-- Un solo pegado. Sube tus tres escenarios de 7,00 % a 7,50 %.
--
-- Por qué: Hillsborough es 6 % del estado + 1,5 % del condado. El 1,5 %
-- solo se aplica a los primeros $5.000 de CADA artículo, pero tu material
-- corriente (cajas, cable, breakers, receptáculos, cans) está muy por
-- debajo de esa cifra por artículo, así que paga el 7,5 % completo. Y ese
-- material corriente es la mayor parte de tus trabajos.
--
-- Para el equipo grande, que es donde el tipo efectivo baja, ya tienes dos
-- herramientas: marcarlo como cotización con el ◉ y, si hace falta,
-- ajustar el tax de ESE estimado con el lápiz del resumen.
--
-- OJO: esto cambia el precio de tus estimados en borrador y congelados.
-- Los contratos de proyectos ya convertidos no se tocan.
-- =====================================================================

update escenarios set tax_material = 0.075 where id in ('A','B','C');

-- MEP se queda en 6,5 % (Orange County), que es donde están los parques.

select id, nombre, round(tax_material * 100, 2) as sales_tax_pct
  from escenarios order by (id = 'MEP'), id;
