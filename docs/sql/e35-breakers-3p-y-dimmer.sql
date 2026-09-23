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
--    Las horas son una PROPUESTA por tamaño de frame, para que Edgar las corrija:
--      15–60 A  0,50 h · 70–100 A 0,75 h · 110–225 A 1,25 h
--      250–400 A 2,00 h · 450–600 A 3,00 h
--    (Como referencia: los MAIN CB 3P del catálogo van de 1 h a 8 h, pero un
--    main lleva más que un breaker de rama.)
--
-- 2) EL DIMMER DE 150 W. El de Barbi: Leviton Decora SureSlide 150 W LED, a
--    $18,36 en Home Depot (22/09). En el catálogo solo había el de 600 W y el
--    de 1000 W, así que se ponía a mano.
-- =========================================================================

-- ── 1. Los 26 breakers 3P, del 15 A al 600 A (los mismos amperajes de Planos) ──
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, orden, codigo, cero_motivo, cero_revisado)
select v.item, 'BREAKERS', 'E', 0, v.h, 2100 + v.o, '05-PANEL', 'suministro', current_date
  from (values
    ('BREAKER 3P 15A',  0.50,  1), ('BREAKER 3P 20A',  0.50,  2), ('BREAKER 3P 25A',  0.50,  3),
    ('BREAKER 3P 30A',  0.50,  4), ('BREAKER 3P 35A',  0.50,  5), ('BREAKER 3P 40A',  0.50,  6),
    ('BREAKER 3P 45A',  0.50,  7), ('BREAKER 3P 50A',  0.50,  8), ('BREAKER 3P 60A',  0.50,  9),
    ('BREAKER 3P 70A',  0.75, 10), ('BREAKER 3P 80A',  0.75, 11), ('BREAKER 3P 90A',  0.75, 12),
    ('BREAKER 3P 100A', 0.75, 13), ('BREAKER 3P 110A', 1.25, 14), ('BREAKER 3P 125A', 1.25, 15),
    ('BREAKER 3P 150A', 1.25, 16), ('BREAKER 3P 175A', 1.25, 17), ('BREAKER 3P 200A', 1.25, 18),
    ('BREAKER 3P 225A', 1.25, 19), ('BREAKER 3P 250A', 2.00, 20), ('BREAKER 3P 300A', 2.00, 21),
    ('BREAKER 3P 350A', 2.00, 22), ('BREAKER 3P 400A', 2.00, 23), ('BREAKER 3P 450A', 3.00, 24),
    ('BREAKER 3P 500A', 3.00, 25), ('BREAKER 3P 600A', 3.00, 26)
  ) as v(item, h, o)
 where not exists (select 1 from catalogo_items c
                    where upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g'))) = v.item);

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
  (select case when count(*) = 1 then '✓ dimmer 150W a $' || max(precio) else '✗ dimmer' end
     from catalogo_items where item = 'DIMMER SWITCH 150W LED (LEVITON)') as dimmer;
