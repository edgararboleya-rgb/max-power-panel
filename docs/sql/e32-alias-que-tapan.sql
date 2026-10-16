-- =========================================================================
-- E32 · ALIAS QUE TAPAN UNA FILA DEL CATÁLOGO (21/09)
-- Supabase → SQL Editor. UN solo select. SOLO LEE.
--
-- POR QUÉ. Al emparejar una fila del takeoff, la app busca en este orden:
--   código → ALIAS → nombre exacto
-- El alias va ANTES que el nombre. Así que si existe un alias que se llama
-- igual que una fila de tu catálogo y apunta a OTRA pieza, esa otra es la que
-- entra al estimado: el nombre exacto no llega a mirarse. En silencio.
--
-- Salió de «CT CABINET»: el catálogo tiene `CT CABINET` (E · 2 h) y
-- `CT/METER CAN` (EA · 3 h), y en Bluebeam son DOS conteos distintos. Un alias
-- «CT CABINET» → «CT/METER CAN» le cambia la pieza y le suma una hora.
--
-- Esto busca TODOS los casos, no solo ese.
-- =========================================================================

with a as (
  select id, upper(btrim(regexp_replace(alias,'\s+',' ','g'))) as ka,
         upper(btrim(regexp_replace(item ,'\s+',' ','g'))) as ki,
         alias, item, coalesce(factor,1)::numeric as f
    from alias_takeoff
), c as (
  select id, upper(btrim(regexp_replace(item,'\s+',' ','g'))) as k,
         item, unidad, precio, horas_unidad
    from catalogo_items
)
select case when a.ki is distinct from cd.k then '✗ el alias TAPA una fila del catálogo y manda a otra pieza'
            else '· el alias apunta a su propia fila: inofensivo' end as que_pasa,
       a.alias                                   as alias,
       co.item                                   as lo_que_tapa,
       co.unidad || ' · ' || coalesce(co.horas_unidad,0)::text || ' h · ' ||
         coalesce(co.precio,0)::text || ' $'     as tapada,
       a.item                                    as manda_a,
       cd.unidad || ' · ' || coalesce(cd.horas_unidad,0)::text || ' h · ' ||
         coalesce(cd.precio,0)::text || ' $'     as destino,
       a.id                                      as id_del_alias
  from a
  join c co on co.k = a.ka           -- existe una fila del catálogo con ESE nombre
  left join c cd on cd.k = a.ki      -- y el alias manda a otra
 order by (a.ki is distinct from cd.k) desc, a.alias;

-- =========================================================================
-- SI SALE ALGÚN ✗, lo que hay que decidir es: ¿el alias está ahí a propósito
-- (Edgar quiere que ese nombre del plano vaya a otra pieza) o se coló?
--
-- Para el caso de «CT CABINET» la respuesta es clara y el borrado es este —
-- deja el alias que manda CT CABINET a CT CABINET y quita el que lo desvía:
-- =========================================================================
-- delete from alias_takeoff
--  where upper(btrim(alias)) = 'CT CABINET'
--    and upper(btrim(regexp_replace(item,'\s+',' ','g'))) <> 'CT CABINET';

-- Y los 49 alias repetidos que apuntan a lo mismo (ruido, cero impacto):
-- with a as (select id, upper(btrim(alias)) as k from alias_takeoff)
-- delete from alias_takeoff where id not in (select min(id) from a group by k);
-- create unique index if not exists alias_takeoff_alias_unico
--   on alias_takeoff (upper(btrim(alias)));
