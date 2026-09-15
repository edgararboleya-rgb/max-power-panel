-- =====================================================================
-- E10 · Comprobar que el estimador está listo para recibir los borradores
-- que crea MXP Planos desde el scope (Materiales → Scope). Solo lectura.
-- Supabase → SQL Editor → pegar → Run.
--
-- Planos escribe: estimados (nombre, cliente, direccion, estado, modo,
-- notas), estimado_ensambles (estimado_id, ensamble_id, cantidad) y
-- estimado_items (estimado_id, item, unidad, precio, horas, cantidad,
-- orden, origen, codigo). Si falta una columna, Planos reintenta sin ella
-- y lo avisa; con esto se ve antes.
-- =====================================================================
select table_name, column_name, data_type
  from information_schema.columns
 where table_schema = 'public'
   and (
     (table_name = 'estimados'          and column_name in ('modo','notas','estado','cliente','direccion')) or
     (table_name = 'estimado_items'     and column_name in ('origen','codigo','unidad','precio','horas','orden')) or
     (table_name = 'estimado_ensambles' and column_name in ('ensamble_id','cantidad','pies'))
   )
 order by table_name, column_name;

-- las recetas que el cerebro puede proponer (nombre exacto, modo)
select modo, count(*) as recetas, string_agg(nombre, ' · ' order by orden) as nombres
  from ensambles group by modo order by modo;

-- recetas con algún componente que NO existe en el catálogo (entran a $0 y 0 h)
select e.nombre as receta, ei.item as componente_huerfano
  from ensambles e
  join ensamble_items ei on ei.ensamble_id = e.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g'))) = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where c.id is null
 order by e.nombre;
