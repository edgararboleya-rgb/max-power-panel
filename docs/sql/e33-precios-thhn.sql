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
-- LOS CALIBRES CHICOS, AL PRECIO DEL ROLLO. En esa página el #14, el #12 y el
-- #10 tienen DOS precios: por rollo y AL CORTE («by the foot»), y el corte
-- siempre es más caro. El bloque 2 se quedó esperando hasta que Edgar miró el
-- rollo (22/09): #14 $137,80 / #12 $175 / #10 $225, los tres de 500 pies. Esos
-- son los que van, no los del corte — y son los que de verdad paga.
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

-- ── 2. EL #14, EL #12 Y EL #10 — AL PRECIO DEL ROLLO (22/09, Edgar) ─────
-- Se dejó esto comentado a propósito hasta saber el precio del ROLLO, porque el
-- de la página era al corte y el corte siempre es más caro. Edgar lo confirmó:
--   #14  rollo de 500 ft = $137,80  → $0,2756/pie →   275,60 /MLF
--   #12  rollo de 500 ft = $175,00  → $0,35/pie   →   350,00 /MLF  (al corte era 380)
--   #10  rollo de 500 ft = $225,00  → $0,45/pie   →   450,00 /MLF  (al corte era 500)
-- El #12 es el cable que más gasta: en Nicklaus, unos 13.800 ft. Con el precio
-- del rollo eso son ~$1.780 más que lo que había en el catálogo, no los ~$2.200
-- que habría metido el precio al corte.
update catalogo_items set precio = v.p, precio_fecha = date '2026-09-22',
       precio_fuente = 'GLOBAL Cable & Wire — rollo 500 ft, THHN/THWN-2, 22/09/2026'
  from (values
    ('# 14      THHN SOLID CU.',       275.60),
    ('# 12      THHN STRANDED CU.',    350.00),
    ('# 10      THHN STRANDED CU.',    450.00)
  ) as v(nom, p)
 where upper(btrim(regexp_replace(catalogo_items.item, '\s+', ' ', 'g')))
     = upper(btrim(regexp_replace(v.nom, '\s+', ' ', 'g')));

-- ── 3. (nada pendiente) ─────────────────────────────────────────

-- ── 4. COMPROBAR (solo lee). Lo que no diga ✓ hay que mirarlo ──────────────
with esperado(nom, p) as (values
  ('# 8         THHN STRANDED CU.',    900.00), ('# 6       THHN STRANDED CU.',    1320.00),
  ('# 4         THHN STRANDED CU.',   2070.00), ('# 3         THHN STRANDED CU.',  2440.00),
  ('# 2       THHN STRANDED CU.',     3170.00), ('# 1         THHN STRANDED CU.',  3500.00),
  ('# 1/0   THHN STRANDED CU.',       4350.00), ('# 2/0   THHN STRANDED CU.',      5510.00),
  ('# 3/0    THHN STRANDED CU.',      6890.00), ('# 4/0   THHN STRANDED CU.',      8470.00),
  ('# 250   MCM THW CU.',            10070.00), ('# 300   MCM THW CU.',           12190.00),
  ('# 350   MCM THW CU.',            14180.00), ('# 400   MCM THW CU.',           15020.00),
  ('# 500   MCM THW CU.',            19940.00), ('# 600   MCM THW CU.',           25190.00),
  ('# 14      THHN SOLID CU.',         275.60), ('# 12      THHN STRANDED CU.',     350.00),
  ('# 10      THHN STRANDED CU.',      450.00)
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
