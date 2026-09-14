-- =====================================================================
-- E9a · Qué ensambles tienes hoy. Solo lectura, no cambia nada.
-- Necesito verlo antes de escribir los nuevos, para no duplicarte nada
-- y para respetar los que ya funcionan.
-- =====================================================================

-- 1) Los ensambles y cuántos componentes lleva cada uno
select e.id, e.nombre, e.modo, e.pies_editable, e.orden,
       count(ei.id) as componentes
  from ensambles e
  left join ensamble_items ei on ei.ensamble_id = e.id
 group by e.id, e.nombre, e.modo, e.pies_editable, e.orden
 order by e.modo, e.orden, e.nombre;

-- 2) EL QUE MÁS IMPORTA: componentes cuyo nombre NO existe en el catálogo.
--    Cada uno entra al bid a $0 Y a 0 horas, en silencio: ni material ni
--    mano de obra. Es el agujero que E0 destapó en el renglón, pero la
--    receta sigue rota por dentro.
select e.nombre as ensamble, ei.item as escrito_en_la_receta, ei.cantidad
  from ensamble_items ei
  join ensambles e on e.id = ei.ensamble_id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where c.id is null
 order by 1, 2;
-- 0 filas = todas las recetas apuntan a items que existen. Perfecto.
