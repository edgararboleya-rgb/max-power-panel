-- =========================================================================
-- E30 · FILAS REPETIDAS — y por qué se repitieron (21/09)
-- Supabase → SQL Editor. UN solo select sin comentar: el editor enseña el
-- último, así que aquí solo hay uno y lo dice todo. Lo demás va COMENTADO.
--
-- QUÉ PASÓ. Comprobando los precios de e21, el «1" EMT S.S. D/C CONNECTOR»
-- contestó DOS veces. Son 11 parejas, ids 1085-1095 y 1100-1110: dos bloques
-- seguidos, o sea un SQL que corrió dos veces.
--
-- POR QUÉ. e16-precios-ced.sql (y e15-alias-bluebeam.sql) insertan con
-- `on conflict do nothing`, y eso SOLO evita el duplicado si la tabla tiene un
-- índice ÚNICO en esa columna. Sin índice no hace nada: inserta y calla. Los
-- ficheros dicen «idempotente» y no lo son. Volverá a pasar cada vez.
--
-- POR QUÉ IMPORTA. Cuando una receta busca una pieza, el estimador se queda
-- con LA PRIMERA que encuentra, y el orden en que llegan del servidor no está
-- garantizado. Hoy las 11 parejas valen lo mismo: tu bid no cambia un centavo.
-- El día que corrijas UNA con el precio del supply, la receta puede seguir
-- cobrando la otra. (El panel ya lo avisa desde v206.)
--
-- CUIDADO AL BORRAR. `lev_recetas` apunta al catálogo POR ID: si se borra la
-- gemela referenciada, esa receta apunta a nada y sale a $0 en silencio. El
-- borrado de abajo conserva la referenciada; solo si no lo está ninguna, usa
-- la de id más bajo.
-- =========================================================================

with
n as (select id, item, precio, horas_unidad,
             upper(btrim(regexp_replace(item, '\s+', ' ', 'g'))) as k
        from catalogo_items),
dup as (select k from n group by k having count(*) > 1),
usada as (select distinct catalogo_item_id as id from lev_recetas),
marca as (select n.k, n.id, n.precio, n.horas_unidad, (u.id is not null) as ref
            from n join dup d on d.k = n.k
            left join usada u on u.id = n.id),

-- las piezas del catálogo repetidas
cat as (
  select case when count(*) filter (where ref) > 1 then 0
              when count(distinct coalesce(precio,0)) > 1
                or count(distinct coalesce(horas_unidad,0)) > 1 then 1
              else 5 end                                      as ord,
         'catalogo_items'                                     as tabla,
         k                                                    as nombre,
         count(*)                                             as veces,
         string_agg(id::text || case when ref then '*' else '' end || ' → ' ||
                    coalesce(precio,0)::text || ' $', ' | ' order by id) as filas,
         coalesce(min(id) filter (where ref), min(id))        as se_queda,
         case when count(*) filter (where ref) > 1
                then '✗ las DOS las usa lev_recetas — NO borres, avísame'
              when count(distinct coalesce(precio,0)) > 1
                or count(distinct coalesce(horas_unidad,0)) > 1
                then '✗ NO valen lo mismo — elige TÚ cuál se queda'
              when count(*) filter (where ref) = 1
                then '· se conserva la que usa lev_recetas (la del *)'
              else '· iguales y ninguna referenciada: se conserva la de id más bajo' end as que_hacer
    from marca group by k),

-- los alias repetidos (e15 tiene el mismo agujero)
ali as (
  select case when count(distinct item) > 1 then 1 else 5 end as ord,
         'alias_takeoff'                                      as tabla,
         upper(btrim(alias))                                  as nombre,
         count(*)                                             as veces,
         string_agg(distinct item, ' | ')                     as filas,
         null::bigint                                         as se_queda,
         case when count(distinct item) > 1
              then '✗ el mismo alias apunta a piezas DISTINTAS'
              else '· repetido pero apunta a lo mismo' end    as que_hacer
    from alias_takeoff
   group by upper(btrim(alias))
  having count(*) > 1),

-- y el resumen, para que se vea aunque no haya ninguna
fin as (
  select 9 as ord, 'resumen' as tabla,
         (select count(*) from cat)::text || ' pieza(s) y ' ||
         (select count(*) from ali)::text || ' alias repetidos' as nombre,
         null::bigint as veces, null::text as filas, null::bigint as se_queda,
         case when (select count(*) from cat) = 0 and (select count(*) from ali) = 0
              then '✓ no hay nada repetido'
              else '· mira las filas de arriba; lo que empieza por ✗ es lo que puede mover un número' end as que_hacer)

select tabla, nombre, veces, filas, se_queda, que_hacer
  from (select * from cat union all select * from ali union all select * from fin) t
 order by ord, tabla, nombre;

-- =========================================================================
-- LO QUE VIENE DESPUÉS — comentado. Léelo antes de descomentar.
-- =========================================================================

-- ── A. BORRAR las gemelas de más. Solo si NINGUNA fila de arriba tiene ✗ ──
-- with n as (
--   select id, upper(btrim(regexp_replace(item,'\s+',' ','g'))) as k from catalogo_items
-- ), dup as (select k from n group by k having count(*) > 1),
--   usada as (select distinct catalogo_item_id as id from lev_recetas),
--   se_queda as (
--     select n.k, coalesce(min(n.id) filter (where u.id is not null), min(n.id)) as id
--       from n join dup d on d.k = n.k
--       left join usada u on u.id = n.id
--      group by n.k)
-- delete from catalogo_items c
--  using n, se_queda s
--  where c.id = n.id and n.k = s.k and c.id <> s.id;

-- ── B. LA CAUSA. Los índices que hacen que `on conflict do nothing` sirva
--       de verdad. DESPUÉS de A, no antes: con repetidas delante, falla. ──
-- create unique index if not exists catalogo_items_item_unico
--   on catalogo_items (upper(btrim(regexp_replace(item, '\s+', ' ', 'g'))));
-- create unique index if not exists alias_takeoff_alias_unico
--   on alias_takeoff (upper(btrim(alias)));

-- ── C. Volver a correr el select de arriba: tiene que decir ✓ ─────────────
