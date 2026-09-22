-- =========================================================================
-- E33 · PRECIOS DEL CABLE THHN/THWN-2 (22/09/2026)
-- Supabase → SQL Editor. UN solo pegado. Idempotente.
--
-- DE DÓNDE SALEN. Los eligió Edgar: página de GLOBAL Cable & Wire, «THHN/THWN-2
-- Copper Building Wire», 22/09/2026. Sus palabras: «me parecen bastante
-- coherentes y a veces por encima de los supply, que para mí es mejor».
--   NO son una cotización de CED ni de CES. Son precio de LISTA, y por eso van
--   con su fecha y su fuente: cuando llegue la cuota del supply, la más cara
--   manda, que es la regla de la casa.
--
-- OJO CON DOS. El #12 sube un 72 % y el #10 un 47 %, cuando todo lo demás sube
-- un 11-16 %. En esa página los calibres chicos tienen DOS precios: por rollo
-- («sold by the spool», «100ft or 250ft Coil») y AL CORTE («by the foot»), y el
-- corte siempre es más caro. Aquí va el del corte porque es el que se ve. El
-- #12 es el cable que más gasta Edgar —en Nicklaus, unos 13.800 ft— así que ese
-- 72 % son ~$2.200 en un solo trabajo. Mirar el precio del ROLLO antes de dar
-- estos dos por buenos. Los bloques 2 y 3 están separados justo por eso.
--
-- LO QUE ARREGLA DE PASO. El 400, 500 y 600 MCM estaban MAL en el catálogo: el
-- 400 ($7.425/MLF) salía más barato que el 350 ($12.647). Suben un 102-116 %,
-- que no es que lo nuevo sea caro: es que lo viejo estaba roto.
--
-- El catálogo guarda el cable en MLF (miles de pies): $/pie × 1000.
-- Los nombres NO se tocan. Los MCM se siguen llamando «THW» en el catálogo
-- aunque el producto sea THHN/THWN-2: renombrarlos dejaría sin casar los
-- estimados viejos. Es cosmético y se puede hacer otro día.
-- =========================================================================

-- ── 0. ANTES DE TOCAR NADA: lo que hay hoy (solo lee) ──────────────────────
select item, unidad, precio, precio_fecha, precio_fuente
  from catalogo_items
 where item ~* '(THHN|THW).*CU\.'
 order by orden, item;

-- ── 1. LO QUE NO TIENE DUDA: del #8 al 600 MCM ─────────────────────────────
-- Suben un 11-16 %, salvo el #3 que baja un 6 % y los tres MCM que estaban mal.
update catalogo_items set precio = v.p, precio_fecha = date '2026-09-22',
       precio_fuente = 'GLOBAL Cable & Wire — lista THHN/THWN-2 22/09/2026'
  from (values
    ('# 8         THHN STRANDED CU.',    900.00),
    ('# 6       THHN STRANDED CU.',     1320.00),
    ('# 4         THHN STRANDED CU.',   2070.00),
    ('# 3         THHN STRANDED CU.',   2440.00),
    ('# 2       THHN STRANDED CU.',     3170.00),
    ('# 1         THHN STRANDED CU.',   3500.00),
    ('# 1/0   THHN STRANDED CU.',       4350.00),
    ('# 2/0   THHN STRANDED CU.',       5510.00),
    ('# 3/0    THHN STRANDED CU.',      6890.00),
    ('# 4/0   THHN STRANDED CU.',       8470.00),
    ('# 250   MCM THW CU.',            10070.00),
    ('# 300   MCM THW CU.',            12190.00),
    ('# 350   MCM THW CU.',            14180.00),
    ('# 400   MCM THW CU.',            15020.00),
    ('# 500   MCM THW CU.',            19940.00),
    ('# 600   MCM THW CU.',            25190.00)
  ) as v(nom, p)
 where upper(btrim(regexp_replace(catalogo_items.item, '\s+', ' ', 'g')))
     = upper(btrim(regexp_replace(v.nom, '\s+', ' ', 'g')));

-- ── 2. EL #12 Y EL #10 — COMENTADOS. Mira el precio del ROLLO primero ──────
-- Son los dos que más se usan y los dos que más suben. Si el rollo sale más
-- barato que el corte, pon aquí el del rollo y descomenta.
-- update catalogo_items set precio = v.p, precio_fecha = date '2026-09-22',
--        precio_fuente = 'GLOBAL Cable & Wire — lista THHN/THWN-2 22/09/2026'
--   from (values
--     ('# 12      THHN STRANDED CU.',  380.00),   -- $0,38/pie AL CORTE. Rollo: mirar
--     ('# 10      THHN STRANDED CU.',  500.00)    -- $0,50/pie AL CORTE. Rollo 100/250 ft: $0,45
--   ) as v(nom, p)
--  where upper(btrim(regexp_replace(catalogo_items.item, '\s+', ' ', 'g')))
--      = upper(btrim(regexp_replace(v.nom, '\s+', ' ', 'g')));

-- ── 3. EL #14 — sin precio en la página: solo sale por rollo. Sin tocar. ────

-- ── 4. COMPROBAR (solo lee). Lo que no diga ✓ hay que mirarlo ──────────────
with esperado(nom, p) as (values
  ('# 8         THHN STRANDED CU.',    900.00), ('# 6       THHN STRANDED CU.',    1320.00),
  ('# 4         THHN STRANDED CU.',   2070.00), ('# 3         THHN STRANDED CU.',  2440.00),
  ('# 2       THHN STRANDED CU.',     3170.00), ('# 1         THHN STRANDED CU.',  3500.00),
  ('# 1/0   THHN STRANDED CU.',       4350.00), ('# 2/0   THHN STRANDED CU.',      5510.00),
  ('# 3/0    THHN STRANDED CU.',      6890.00), ('# 4/0   THHN STRANDED CU.',      8470.00),
  ('# 250   MCM THW CU.',            10070.00), ('# 300   MCM THW CU.',           12190.00),
  ('# 350   MCM THW CU.',            14180.00), ('# 400   MCM THW CU.',           15020.00),
  ('# 500   MCM THW CU.',            19940.00), ('# 600   MCM THW CU.',           25190.00)
)
select e.nom, e.p as esperado, c.precio as real,
       c.precio_fecha, c.precio_fuente,
       case when c.item is null then '✗ esa fila NO está en el catálogo'
            when abs(c.precio - e.p) < 0.01 then '✓'
            else '✗ no entró' end as estado
  from esperado e
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g')))
          = upper(btrim(regexp_replace(e.nom, '\s+', ' ', 'g')))
 order by (case when c.item is not null and abs(c.precio - e.p) < 0.01 then 1 else 0 end), e.nom;
