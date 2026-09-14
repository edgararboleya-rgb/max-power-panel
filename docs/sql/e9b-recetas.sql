-- =====================================================================
-- E9b · Las recetas por dentro. Solo lectura, no cambia nada.
-- Una sola consulta: cada ensamble con sus componentes, el precio y las
-- horas que tienen HOY en el catálogo, y una marca cuando el nombre de la
-- receta no existe.
--
-- La columna «ojo» es la que importa:
--   ✗ SIN CATÁLOGO = ese componente entra al bid a $0 y a 0 horas, en
--     silencio. Ni material ni mano de obra. Nadie lo había contado.
-- =====================================================================

select e.nombre                                  as ensamble,
       e.modo,
       ei.item                                   as componente,
       ei.cantidad,
       c.unidad,
       c.precio,
       c.horas_unidad                            as horas,
       case when c.id is null then '✗ SIN CATÁLOGO' else '' end as ojo
  from ensambles e
  join ensamble_items ei on ei.ensamble_id = e.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 order by e.modo, e.orden, ei.item;
