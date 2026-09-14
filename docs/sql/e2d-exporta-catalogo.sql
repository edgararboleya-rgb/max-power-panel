-- E2d · Exportar el catálogo real y los alias de Supabase (solo lectura, no cambia nada).
-- Run → en Results, arriba a la derecha, Export → Download CSV → soltar el archivo en la conversación.
-- OJO al guardar: conservar SIEMPRE precio y horas (el 14/09 se perdieron al pasar a JSON y hubo que re-pedirlo).
-- Sale todo en una sola tabla: filas 'catalogo' (1072 items) y filas 'alias' (alias_takeoff).
select 'catalogo' as tabla, item, seccion, unidad, precio::text as precio, horas_unidad::text as horas, orden::text as orden, codigo, null::text as alias, null::text as factor, null::text as nota
from catalogo_items
union all
select 'alias', item, null, null, null, null, null, codigo, alias, factor::text, nota
from alias_takeoff
order by 1, 7 nulls last, 2;
