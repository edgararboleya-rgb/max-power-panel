-- =========================================================================
-- E31 · LOS ALIAS REPETIDOS, MIRANDO TAMBIÉN EL FACTOR (21/09)
-- Supabase → SQL Editor. UN solo select. SOLO LEE.
--
-- Por qué existe: e30 comparó a qué PIEZA apunta cada alias repetido, pero no
-- con qué FACTOR. El factor es el que divide los pies entre mil. Dos alias
-- iguales con distinto factor son un error de 1000× — es exactamente el fallo
-- del 16/09: «500 ft de 14/4 FPL por alias entraban como 500 MLF».
--
-- La app coge el PRIMERO que encuentra (.find), y el orden en que llegan del
-- servidor no está garantizado. Con el mismo item y el mismo factor da igual
-- cuál coja. Con distinto factor, el número cambia según el día.
-- =========================================================================

with a as (
  select id, upper(btrim(alias)) as k, alias, item,
         coalesce(factor, 1)::numeric as f
    from alias_takeoff
), d as (
  select k from a group by k having count(*) > 1
), g as (
  select a.k,
         count(*)                                      as veces,
         count(distinct upper(btrim(a.item)))          as piezas_distintas,
         count(distinct a.f)                           as factores_distintos,
         string_agg(distinct a.item, ' | ')            as apunta_a,
         string_agg(distinct a.f::text, ' | ')         as factores,
         min(a.id)                                     as se_queda
    from a join d on d.k = a.k
   group by a.k
)
select case when factores_distintos > 1 then '✗✗ FACTORES DISTINTOS — error de hasta 1000× según cuál coja'
            when piezas_distintas   > 1 then '✗ apunta a PIEZAS distintas — elige tú cuál vale'
            else '· mismo item y mismo factor: da igual cuál coja, pero deja uno' end as que_pasa,
       k          as alias,
       veces,
       apunta_a,
       factores,
       se_queda   as id_mas_bajo
  from g
 order by (factores_distintos > 1) desc, (piezas_distintas > 1) desc, k;

-- =========================================================================
-- DESPUÉS, y solo cuando no quede ningún ✗ — comentado.
-- El borrado conserva el id más bajo de cada alias. `alias_takeoff` no lo
-- referencia nadie por id (la app casa por NOMBRE), así que aquí es seguro.
-- =========================================================================
-- with a as (select id, upper(btrim(alias)) as k from alias_takeoff)
-- delete from alias_takeoff
--  where id not in (select min(id) from a group by k);

-- y el índice que impide que vuelva a pasar (va DESPUÉS del borrado):
-- create unique index if not exists alias_takeoff_alias_unico
--   on alias_takeoff (upper(btrim(alias)));
