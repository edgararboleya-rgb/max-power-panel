-- =========================================================================
-- E35 · BREAKERS TRIFÁSICOS (solo instalación) Y EL DIMMER DE 150 W (23/09/2026)
-- Supabase → SQL Editor. UN solo pegado. Idempotente: si ya están, no toca nada.
--
-- 1) BREAKERS 3P DE RAMA. Planos los manda como 'BREAKER 3P 200A' y en el
--    catálogo no existían: llegaban SIN MAPEAR. Edgar (23/09): «eso normalmente
--    sale en los precios del gear que me da el supply… sería solo el montaje».
--    Así que van a $0 con motivo «suministro» (lo cotiza el supply house) y
--    SOLO sus horas de instalación: montarlo en el panelboard, apretar y rotular.
--    La terminación del feeder va aparte (la regla de horas del proyecto).
--    Las horas son las de Edgar (23/09), en minutos de montaje:
--      15–60 A 20 min · 70–100 A 35 min · 110–225 A 45 min
--      250–400 A 1 h 15 min · 450–600 A 1 h 30 min
--    (El 400 A caía en dos tramos: va con 250–400.)
--
-- 2) EL DIMMER DE 150 W. El de Barbi: Leviton Decora SureSlide 150 W LED, a
--    $18,36 en Home Depot (22/09). En el catálogo solo había el de 600 W y el
--    de 1000 W, así que se ponía a mano.
-- =========================================================================

-- ── 1. Los 26 breakers 3P, del 15 A al 600 A (los mismos amperajes de Planos) ──
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, orden, codigo, cero_motivo, cero_revisado)
select v.item, 'BREAKERS', 'E', 0, v.h, 2100 + v.o, '05-PANEL', 'suministro', current_date
  from (values
    ('BREAKER 3P 15A',  0.3333,  1), ('BREAKER 3P 20A',  0.3333,  2), ('BREAKER 3P 25A',  0.3333,  3),
    ('BREAKER 3P 30A',  0.3333,  4), ('BREAKER 3P 35A',  0.3333,  5), ('BREAKER 3P 40A',  0.3333,  6),
    ('BREAKER 3P 45A',  0.3333,  7), ('BREAKER 3P 50A',  0.3333,  8), ('BREAKER 3P 60A',  0.3333,  9),
    ('BREAKER 3P 70A',  0.5833, 10), ('BREAKER 3P 80A',  0.5833, 11), ('BREAKER 3P 90A',  0.5833, 12),
    ('BREAKER 3P 100A', 0.5833, 13), ('BREAKER 3P 110A', 0.7500, 14), ('BREAKER 3P 125A', 0.7500, 15),
    ('BREAKER 3P 150A', 0.7500, 16), ('BREAKER 3P 175A', 0.7500, 17), ('BREAKER 3P 200A', 0.7500, 18),
    ('BREAKER 3P 225A', 0.7500, 19), ('BREAKER 3P 250A', 1.2500, 20), ('BREAKER 3P 300A', 1.2500, 21),
    ('BREAKER 3P 350A', 1.2500, 22), ('BREAKER 3P 400A', 1.2500, 23), ('BREAKER 3P 450A', 1.5000, 24),
    ('BREAKER 3P 500A', 1.5000, 25), ('BREAKER 3P 600A', 1.5000, 26)
  ) as v(item, h, o)
 where not exists (select 1 from catalogo_items c
                    where upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g'))) = v.item);

-- ── 1b. Si ya se habían creado con las horas de la primera propuesta, se
--        corrigen a las de Edgar (sin tocar nada más) ────────────────────────
update catalogo_items c set horas_unidad = v.h
  from (values ('15',0.3333),('20',0.3333),('25',0.3333),('30',0.3333),('35',0.3333),('40',0.3333),('45',0.3333),('50',0.3333),('60',0.3333),
               ('70',0.5833),('80',0.5833),('90',0.5833),('100',0.5833),
               ('110',0.75),('125',0.75),('150',0.75),('175',0.75),('200',0.75),('225',0.75),
               ('250',1.25),('300',1.25),('350',1.25),('400',1.25),('450',1.50),('500',1.50),('600',1.50)) as v(a, h)
 where c.item = 'BREAKER 3P ' || v.a || 'A' and c.horas_unidad is distinct from v.h;

-- ── 2. El dimmer de 150 W ─────────────────────────────────────────────────
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, orden, codigo, precio_fecha, precio_fuente)
select 'DIMMER SWITCH 150W LED (LEVITON)', 'WIRING DEVICES', 'E', 18.36, 0.30, 767, '10-DEV',
       date '2026-09-22', 'Home Depot — Leviton Decora SureSlide 150W LED (compra de Barbi, 22/09/2026)'
 where not exists (select 1 from catalogo_items c
                    where upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g'))) = 'DIMMER SWITCH 150W LED (LEVITON)');

-- ── Comprobación (una sola fila; todo ✓) ───────────────────────────────────
select
  (select case when count(*) = 26 then '✓ 26 breakers 3P' else '✗ ' || count(*) || ' breakers 3P' end
     from catalogo_items where item ~ '^BREAKER 3P [0-9]+A$') as breakers_3p,
  (select case when count(*) = 26 and bool_and(precio = 0 and cero_motivo = 'suministro')
               then '✓ a $0, lo cotiza el supply' else '✗ revisar precio/motivo' end
     from catalogo_items where item ~ '^BREAKER 3P [0-9]+A$') as solo_montaje,
  (select case when round(sum(horas_unidad), 2) = 19.33 then '✓ horas de Edgar (20 min a 1 h 30)' else '✗ horas: ' || round(sum(horas_unidad), 2) end
     from catalogo_items where item ~ '^BREAKER 3P [0-9]+A$') as horas,
  (select case when count(*) = 1 then '✓ dimmer 150W a $' || max(precio) else '✗ dimmer' end
     from catalogo_items where item = 'DIMMER SWITCH 150W LED (LEVITON)') as dimmer;
