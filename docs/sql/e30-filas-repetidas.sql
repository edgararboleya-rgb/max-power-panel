-- =========================================================================
-- E30 · FILAS REPETIDAS DEL CATÁLOGO (21/09)
-- Supabase → SQL Editor. El bloque 1 SOLO LEE. El 2 está COMENTADO a propósito.
--
-- De dónde sale: al comprobar los precios de e21, el
-- «1"  EMT S.S. D/C CONNECTOR» contestó DOS veces. Hay filas repetidas en
-- catalogo_items (mismo nombre, distinta fila).
--
-- Por qué importa: cuando una receta busca una pieza, el estimador se queda
-- con LA PRIMERA que encuentra, y el orden en que llegan del servidor no está
-- garantizado. Mientras las gemelas valgan lo mismo, da igual cuál coja. El
-- día que corrijas UNA con el precio del supply, la receta puede seguir
-- cobrando la otra — y no lo dice nadie. (El panel ya lo avisa desde v206.)
-- =========================================================================

-- ── 1. Las repetidas, y si valen lo mismo ──────────────────────────────────
-- Lo que NO vale lo mismo sale primero: eso es lo que puede mover un número.
with n as (
  select id, item, precio, horas_unidad, unidad,
         upper(btrim(regexp_replace(item, '\s+', ' ', 'g'))) as k
    from catalogo_items
)
select k                                   as nombre_normalizado,
       count(*)                            as veces,
       count(distinct coalesce(precio, 0)) as precios_distintos,
       count(distinct coalesce(horas_unidad, 0)) as horas_distintas,
       string_agg(id::text || ' → ' || coalesce(precio, 0)::text || ' $ · ' ||
                  coalesce(horas_unidad, 0)::text || ' h · «' || item || '»',
                  E'\n' order by id)       as filas,
       case when count(distinct coalesce(precio, 0)) > 1
              or count(distinct coalesce(horas_unidad, 0)) > 1
            then '✗ NO valen lo mismo — el número cambia según cuál coja'
            else '· iguales: hoy da igual, pero deja una sola' end as estado
  from n
 group by k
having count(*) > 1
 order by (count(distinct coalesce(precio, 0)) > 1
        or count(distinct coalesce(horas_unidad, 0)) > 1) desc, k;

-- ── 2. Borrar la de más — COMENTADO. Lee el bloque 1 ANTES ─────────────────
-- Antes de descomentar nada:
--   · Si las gemelas NO valen lo mismo, decide TÚ cuál es la buena. Esto se
--     queda con la de id MÁS BAJO, que no tiene por qué ser la correcta.
--   · Una fila del catálogo puede estar referenciada por recetas
--     (ensamble_items casa por NOMBRE, así que no se rompe) y por renglones de
--     estimados. El bloque 2a lo comprueba antes de borrar nada.

-- 2a · ¿alguna de las repetidas está usada por id en algún sitio?  (SOLO LEE)
-- with n as (
--   select id, upper(btrim(regexp_replace(item,'\s+',' ','g'))) as k from catalogo_items
-- ), dobles as (
--   select k, min(id) as se_queda, array_agg(id order by id) as todas
--     from n group by k having count(*) > 1
-- )
-- select d.k, d.se_queda, d.todas from dobles d order by d.k;

-- 2b · el borrado. Descomentar SOLO después de mirar 1 y 2a.
-- with n as (
--   select id, upper(btrim(regexp_replace(item,'\s+',' ','g'))) as k from catalogo_items
-- ), sobran as (
--   select id from n
--    where id not in (select min(id) from n group by k)
-- )
-- delete from catalogo_items where id in (select id from sobran);

-- 2c · comprobar que no quedó ninguna  (SOLO LEE)
-- with n as (
--   select upper(btrim(regexp_replace(item,'\s+',' ','g'))) as k from catalogo_items
-- )
-- select count(*) as repetidas_que_quedan
--   from (select k from n group by k having count(*) > 1) t;
