-- ============================================================================
-- E23b · NICKLAUS: lo que le FALTABA al borrador — el plano de LUCES (17/09)
-- ============================================================================
-- Edgar reviso el borrador del e23 y tiene razon: el tubo y el cable que
-- llevaba eran SOLO los del plano de power (CSV de Bluebeam del 17/09:
-- 17.431 ft de #12 y 3.423 ft de 1/2" EMT). El plano de luces —10.343 ft de
-- #12 y 2.616 ft de 1/2" EMT, medidos por el— no estaba. Aqui entra, con su
-- merma (10 % cable, 5 % tubo) y los fittings de esa tuberia.
--
-- Y una cosa que el propio Edgar pidio al preguntar por los consumibles: el
-- borrador tenia 586 grapas y NI UN tapcon. Van los tapcons de las grapas de
-- power y de luces a 2 por grapa (la regla que el estimador usa en modo
-- planos). Si en obra van a metal deck con tornillo, cambia la cantidad.
--
-- Lo que NO se toca: cajas (162 deep + E-2.3), breakers (12 nuevos; los
-- otros 35 ckts entran en spares), dispositivos.
-- ============================================================================

insert into estimado_items (estimado_id, item, unidad, precio, horas, cantidad, origen, codigo, orden)
select e.id, v.item, v.unidad, v.precio, v.horas, v.cantidad, 'takeoff-nch-2026-09-17-luces', v.codigo, v.orden
  from estimados e, (values
    -- plano de luces, medido por Edgar
    ('# 12      THHN STRANDED CU.',        'MLF', 272.6,  6.0,  10.343, '08-ROUGH', 600),   -- 10.343 ft
    ('# 12      THHN STRANDED CU.',        'MLF', 272.6,  0,     1.034, '08-ROUGH', 601),   -- merma 10 %
    ('1/2"     EMT CONDUIT',               'LF',  0.6124, 0.03,  2616,  '09-COND',  610),   -- 2.616 ft
    ('1/2"     EMT CONDUIT',               'LF',  0.6124, 0,      131,  '09-COND',  611),   -- merma 5 %
    ('1/2"       EMT S.S. D/C COUPLING',   'E',   0.4529, 0.04,   262,  '09-COND',  620),   -- 1 cada 10 ft
    ('1/2"       EMT S.S. D/C CONNECTOR',  'E',   1.1679, 0.06,   210,  '09-COND',  621),   -- 2 por corrida de 25 ft (estimado: no hay conteo de corridas)
    ('1/2"      EMT STRAP 1 HOLE STRAP',   'E',   0.1459, 0.02,   327,  '09-COND',  622),   -- 1 cada 8 ft
    -- tapcons: 2 por grapa, de las 327 de luces y de las 586 que ya estaban (power + recetas)
    ('TAPCON 1/4" x 1-1/4"',               'E',   0.35,   0.01,  1826,  '09-COND',  630)
  ) as v(item, unidad, precio, horas, cantidad, codigo, orden)
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and not exists (select 1 from estimado_items x where x.estimado_id = e.id and x.origen = 'takeoff-nch-2026-09-17-luces');

-- Comprobar: el estimado entero. Antes: 52 renglones, 44.625,75 y 633,8 h.
-- Ahora debe dar 60 renglones, ~50.460 de material y ~776 h.
select count(*) as renglones,
       round(sum(cantidad * precio)::numeric, 2) as material,
       round(sum(cantidad * horas)::numeric, 1) as horas
  from estimado_items x join estimados e on e.id = x.estimado_id
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';

-- Y el cable y el tubo juntos, para cuadrar con Bluebeam (27.774 ft de #12 sin merma; 6.049 ft de 1/2" sin merma):
select item, sum(cantidad) as cantidad, unidad
  from estimado_items x join estimados e on e.id = x.estimado_id
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and (item like '%THHN%' or item like '%EMT CONDUIT%')
 group by item, unidad order by item;
