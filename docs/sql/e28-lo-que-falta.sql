-- =========================================================================
-- E28 · LO QUE FALTA — las tres respuestas que no salieron en e22 (21/09)
-- Supabase → SQL Editor. UN solo pegado. SOLO LEE: no cambia nada.
--
-- Ya está comprobado con lo que pegó Edgar el 21/09:
--   e17 ✓ (la columna sin_lineales existe: el tubo y el cable NO se cobran
--          dos veces), e18 ✓ y e20 ✓ (17 recetas en orden 200-216 = 15 + 2),
--          y por tanto e19 ✓ (e20 lo exige).
--
-- Queda por saber: e11, e12, y si algún precio de e21 no se actualizó en
-- silencio. Devuelve UNA tabla corta. Mándame las filas que digan ✗.
-- =========================================================================

-- ── 1. Las columnas: e11 (la foto del número) y e12 (el precio de referencia) ──
with quiero(sql, tabla, col, para) as (values
  ('e11', 'estimados',      'bid_final',      'el número congelado (sin esto, congelar no guarda el número)'),
  ('e11', 'estimados',      'horas_final',    'las horas del número congelado'),
  ('e11', 'estimados',      'material_final', 'el material del número congelado'),
  ('e11', 'estimados',      'resultado',      'ganado / perdido, para el historial'),
  ('e11', 'estimados',      'competencia',    'por cuánto se perdió'),
  ('e12', 'catalogo_items', 'precio_ref',     'el precio de referencia de una fila'),
  ('e12', 'catalogo_items', 'horas_ref',      'las horas de referencia'),
  ('e12', 'catalogo_items', 'fuente_ref',     'de dónde salió ese precio'),
  ('e17', 'estimado_ensambles', 'sin_lineales', 'que la receta del plano no traiga su tubo ni su cable')
)
select q.sql                as bloque,
       q.tabla || '.' || q.col as columna,
       q.para               as para_que,
       case when c.column_name is null then '✗ FALTA — corre ' || q.sql
            else '✓' end    as estado
  from quiero q
  left join information_schema.columns c
         on c.table_name = q.tabla and c.column_name = q.col
 order by (c.column_name is not null), q.sql, q.col;

-- ── 2. Los precios de e21 que pudieron NO actualizarse en silencio ──────────
-- Los updates de e21 llevaban guarda («and precio = 0.542»). Si el valor no
-- era exacto, el update no hizo nada y NO dio error. Esto lo caza.
with esperado(que, item, val) as (values
  ('1/2" EMT',       '1/2"     EMT CONDUIT',                  0.6124),
  ('3/4" EMT',       '3/4"     EMT CONDUIT',                  1.0903),
  ('1" EMT',         '1"         EMT CONDUIT',                1.8776),
  ('1/2" conector',  '1/2"       EMT S.S. D/C CONNECTOR',     1.1679),
  ('3/4" conector',  '3/4"       EMT S.S. D/C CONNECTOR',     1.8074),
  ('1" conector',    '1"         EMT S.S. D/C CONNECTOR',     3.2247),
  ('1/2" acople',    '1/2"       EMT S.S. D/C COUPLING',      0.4529)
)
select e.que,
       e.val                                   as esperado,
       c.precio                                as real,
       case when c.item is null          then '✗ NO ESTÁ esa fila en el catálogo'
            when abs(c.precio - e.val) < 0.0001 then '✓'
            else '✗ REVISAR — el update de e21 no entró' end as estado
  from esperado e
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g')))
          = upper(btrim(regexp_replace(e.item, '\s+', ' ', 'g')))
 order by (case when c.item is not null and abs(c.precio - e.val) < 0.0001 then 1 else 0 end), e.que;

-- ── 3. Las recetas del hospital: que ningún componente quede sin precio ─────
-- Un componente que no casa con el catálogo entra a $0 y a 0 horas, callado.
select en.orden,
       en.nombre                                        as receta,
       count(*)                                         as componentes,
       count(*) filter (where c.item is null)           as sin_casar,
       count(*) filter (where c.item is not null and coalesce(c.precio, 0) = 0) as a_cero,
       case when count(*) filter (where c.item is null) > 0
              then '✗ REVISAR — hay componentes que no casan con el catálogo'
            when count(*) filter (where c.item is not null and coalesce(c.precio, 0) = 0) > 0
              then '· ojo: algún componente a $0 (puede ser «va por cotización»)'
            else '✓' end                                as estado
  from ensambles en
  join ensamble_items ei on ei.ensamble_id = en.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item,  '\s+', ' ', 'g')))
          = upper(btrim(regexp_replace(ei.item, '\s+', ' ', 'g')))
 where en.orden between 200 and 216
 group by en.orden, en.nombre
 order by (count(*) filter (where c.item is null) = 0), en.orden;
