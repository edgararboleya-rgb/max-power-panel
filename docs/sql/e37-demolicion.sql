-- =========================================================================
-- E37 · DEMOLICIÓN PARA TRABAJOS COMO MARINERS (26/09/2026)
-- YA CORRIDO en Supabase por Claude el 26/09 con el conector (solo añade).
-- Se deja aquí por el registro; es idempotente.
--   Chiller / equipo mecánico: 8 h — lo dijo Edgar.
--   Desconectivos y feeders: PROPUESTA de Claude, para que Edgar la corrija:
--     desconectivo hasta 200 A 1 h · 225–600 A 2 h
--     retirar feeder hasta 4/0 0,012 h/ft de corrida · 250–600 MCM 0,020 h/ft
-- Son solo mano de obra ($0, solo_labor). Planos los manda con estos nombres
-- desde el set «Demolition» de la biblioteca.
-- =========================================================================
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, orden, codigo, cero_motivo, cero_revisado)
select v.item, 'DEMOLITION', v.u, 0, v.h, 9000 + v.o, '01-DEMO', 'solo_labor', current_date
  from (values
    ('DEMO - Chiller / Mechanical Equipment (disconnect & make safe)', 'EA', 8.00,  1),
    ('DEMO - Disconnect Switch (up to 200A)',                          'EA', 1.00,  2),
    ('DEMO - Disconnect Switch (225-600A)',                            'EA', 2.00,  3),
    ('DEMO - Feeder Removal up to 4/0 (per LF of run)',                'LF', 0.012, 4),
    ('DEMO - Feeder Removal 250-600 MCM (per LF of run)',              'LF', 0.020, 5)
  ) as v(item, u, h, o)
 where not exists (select 1 from catalogo_items c
                    where upper(btrim(regexp_replace(c.item, '\s+', ' ', 'g'))) = upper(v.item));

select count(*) || ' renglones DEMO' as demolicion from catalogo_items where item ~ '^DEMO - ';
