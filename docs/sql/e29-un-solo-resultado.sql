-- =========================================================================
-- E29 · TODO EN UNA SOLA TABLA (21/09) — porque el editor de Supabase solo
-- enseña el resultado del ÚLTIMO select, y los checks partidos en bloques se
-- quedaban sin ver.
--
-- SOLO LEE. No cambia nada. Un pegado, un resultado, y se lee de arriba a
-- abajo: lo que esté mal sale PRIMERO.
--
-- Ya comprobado el 21/09 con lo que pegó Edgar: e17, e18, e19, e20, e11 y e12
-- corridos; las 17 recetas del hospital con sus 182 componentes, 0 sin casar y
-- 0 a $0. Lo que falta es lo de abajo: los updates de e21 llevaban guarda con
-- el precio EXACTO, así que con un valor distinto no cambiaban nada y salía
-- «successful» igual.
-- =========================================================================

with
-- ── las columnas que la app necesita ────────────────────────────────────────
cols(sql, tabla, col, para) as (values
  ('e11', 'estimados',          'bid_final',      'el número congelado (sin esto congelar no lo guarda)'),
  ('e11', 'estimados',          'horas_final',    'las horas del número congelado'),
  ('e11', 'estimados',          'material_final', 'el material del número congelado'),
  ('e11', 'estimados',          'resultado',      'ganado / perdido, para el historial'),
  ('e11', 'estimados',          'competencia',    'por cuánto se perdió'),
  ('e12', 'catalogo_items',     'precio_ref',     'el precio de referencia de una fila'),
  ('e12', 'catalogo_items',     'horas_ref',      'las horas de referencia'),
  ('e12', 'catalogo_items',     'fuente_ref',     'de dónde salió ese precio'),
  ('e17', 'estimado_ensambles', 'sin_lineales',   'que la receta del plano no traiga tubo ni cable')
),
-- ── los precios de e21 que pudieron no entrar en silencio ───────────────────
precios(que, item, val) as (values
  ('1/2" EMT',      '1/2"     EMT CONDUIT',               0.6124),
  ('3/4" EMT',      '3/4"     EMT CONDUIT',               1.0903),
  ('1" EMT',        '1"         EMT CONDUIT',             1.8776),
  ('1/2" conector', '1/2"       EMT S.S. D/C CONNECTOR',  1.1679),
  ('3/4" conector', '3/4"       EMT S.S. D/C CONNECTOR',  1.8074),
  ('1" conector',   '1"         EMT S.S. D/C CONNECTOR',  3.2247),
  ('1/2" acople',   '1/2"       EMT S.S. D/C COUPLING',   0.4529)
),
norm as (select id, item, precio,
                upper(btrim(regexp_replace(item, '\s+', ' ', 'g'))) as k
           from catalogo_items),

-- 1 · columnas
r1 as (
  select case when c.column_name is null then 0 else 9 end as ord,
         'columna'                as bloque,
         x.tabla || '.' || x.col  as que,
         x.para                   as detalle,
         null::numeric            as esperado,
         null::numeric            as real,
         case when c.column_name is null then '✗ FALTA — corre ' || x.sql else '✓' end as estado
    from cols x
    left join information_schema.columns c
           on c.table_name = x.tabla and c.column_name = x.col
),
-- 2 · precios de e21
r2 as (
  select case when n.item is null then 0
              when abs(n.precio - p.val) < 0.0001 then 9
              else 1 end          as ord,
         'precio e21'             as bloque,
         p.que                    as que,
         coalesce(n.item, p.item) as detalle,
         p.val                    as esperado,
         n.precio                 as real,
         case when n.item is null then '✗ esa fila NO está en el catálogo'
              when abs(n.precio - p.val) < 0.0001 then '✓'
              else '✗ REVISAR — el update de e21 no entró' end as estado
    from precios p
    left join norm n
           on n.k = upper(btrim(regexp_replace(p.item, '\s+', ' ', 'g')))
),
-- 3 · las recetas del hospital, una fila por receta
r3 as (
  select case when count(*) filter (where c.id is null) > 0 then 0
              when count(*) filter (where c.id is not null and coalesce(c.precio, 0) = 0) > 0 then 2
              else 9 end                    as ord,
         'receta ' || en.orden              as bloque,
         en.nombre                          as que,
         count(*) || ' componentes · ' ||
           count(*) filter (where c.id is null) || ' sin casar · ' ||
           count(*) filter (where c.id is not null and coalesce(c.precio, 0) = 0) || ' a $0' as detalle,
         null::numeric                      as esperado,
         null::numeric                      as real,
         case when count(*) filter (where c.id is null) > 0 then '✗ REVISAR — componentes que no casan'
              when count(*) filter (where c.id is not null and coalesce(c.precio, 0) = 0) > 0 then '· ojo: algo a $0'
              else '✓' end                  as estado
    from ensambles en
    join ensamble_items ei on ei.ensamble_id = en.id
    left join norm c on c.k = upper(btrim(regexp_replace(ei.item, '\s+', ' ', 'g')))
   where en.orden between 200 and 216
   group by en.orden, en.nombre
),
-- 4 · el recuento de siempre
r4 as (
  select 9 as ord, 'recuento' as bloque, 'recetas del hospital (200-216)' as que,
         'de ' || count(*) || ' recetas en total' as detalle,
         17::numeric as esperado,
         count(*) filter (where orden between 200 and 216)::numeric as real,
         case when count(*) filter (where orden between 200 and 216) = 17 then '✓'
              else '✗ REVISAR — deberían ser 17 (15 de e18 + 2 de e20)' end as estado
    from ensambles
)
select bloque, que, detalle, esperado, real, estado
  from (select * from r1 union all select * from r2
        union all select * from r3 union all select * from r4) t
 order by ord, bloque, que;
