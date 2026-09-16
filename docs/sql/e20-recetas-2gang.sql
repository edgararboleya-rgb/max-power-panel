-- =========================================================================
-- E20 · Las recetas de 2 GANG del hospital (los pares que comparten caja)
-- Supabase → SQL Editor. Un solo pegado. Idempotente: no duplica nada.
--
-- Los pares que en el plano comparten UNA caja de 2 gang. Con las recetas de
-- 1 gang cada dispositivo traía su caja y su anillo: en Nicklaus, 21 cajas y 21
-- anillos de más. Aquí el par comparte caja, anillo, placa doble, tubo y tierra.
-- En Planos se cuenta 1 por caja doble y se restan 2 del conteo de sencillos.
-- Necesita e18 (las altas HG y el combo) y e19 (las placas de acero) corridos.
--
-- Cada componente EXISTE en tu catálogo con ese nombre exacto (comprobado uno
-- por uno contra el export del 16/09 con los bloques 0/A/A2 aplicados) o se da
-- de alta en el bloque 1 de este mismo SQL. Las horas y el precio NO se
-- escriben en la receta: los pone el catálogo.
--
-- El tubo y el cable de cada receta NO los cobra el takeoff de Planos (E17,
-- sin_lineales): esos los mides tú. EXCEPTO en las tres recetas «SOLO ROUGH
-- (STUB…)», donde el tubo ES el punto: a esas categorías márcales en Planos
-- «☑ Que la receta venga con su tubo y su cable».
-- =========================================================================

-- que el modo «comercial» esté permitido y la receta pueda llevar descripción
alter table ensambles drop constraint if exists ensambles_modo_check;
alter table ensambles add  constraint ensambles_modo_check
  check (modo in ('remodelacion','servicio','comercial','planos','rapido'));
alter table ensambles add column if not exists descripcion text;

-- -------------------------------------------------------------------------
-- 1) Sin altas: todo lo que usa ya está en el catálogo (e18 + e19).
--    Dos son de REFERENCIA (no cotizadas): pídeselas a CED y corrige el precio.
-- -------------------------------------------------------------------------
-- -------------------------------------------------------------------------
-- 2) Las recetas
-- -------------------------------------------------------------------------
insert into ensambles (nombre, modo, pies_editable, orden, descripcion)
select v.nombre, v.modo, v.pies, v.orden, v.descripcion
  from (values
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', 'comercial', true, 215, 'Dos receptáculos hospital grade TR en UNA caja con anillo de 2 gang y placa doble de acero grabada. Para los pares que en el plano comparten caja: se cuenta el PAR, no cada pieza.'),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', 'comercial', true, 216, 'Dos combos dimmer 0-10V + sensor en UNA caja de 2 gang (dos zonas de luz en el mismo cuarto), placa decora doble de acero grabada. Se cuenta el PAR.')
  ) as v(nombre, modo, pies, orden, descripcion)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

-- -------------------------------------------------------------------------
-- 3) Los componentes
-- -------------------------------------------------------------------------
insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    -- RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT · 8 en Nicklaus · punto 1.50 h / $66.08 · con tubo y cable 2.70 h / $95.77
    --   En Nicklaus hay 8 cajas de 2 gang con dos HG ivory. Con la receta de 1 gang cada uno traía su caja y su anillo: 8 cajas y 8 anillos de más. Aquí el par comparte caja, anillo, tubo y tierra. En Planos se cuenta 1 por cada caja doble y se restan 2 del conteo de sencillos.
    --   Vara: Como el RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT de E9 (2,70 h con tubo): dos dispositivos a 0,4 + caja 1900 deep 0,25 + anillo 2G 0,05 + placa 0,10 + fittings. Sin lineal ≈ 1,6 h el par, contra 2,14 de dos sencillos.
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '20A HOSPITAL GRADE TR RECEPTACLE', 2),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '2  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '2G DUPLEX WALLPLATE STAINLESS STEEL', 1),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', 'PLATE ENGRAVING (per gang)', 2),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', '#12     GROUND PIGTAIL', 2),
    ('RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT', 'YELLOW WIRENUTS', 4),

    -- DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT · 0 en Nicklaus · punto 1.87 h / $274.97 · con tubo y cable 3.07 h / $307.56
    --   Nicklaus tiene 13 cajas de switch de 2 gang; el par más probable en un cuarto de ultrasonido son dos zonas de luz, cada una con su combo. Los pares combo + sencillo o combo + sensor se siguen contando como sencillos (sobrante conocido de una caja y un anillo por par).
    --   Vara: Dos combos a 0,6 + caja 1900 deep + anillo 2G + placa + fittings ≈ 1,9 h el par sin lineal, contra 2,5 de dos sencillos. Hilos: fase compartida, dos retornos, neutro, tierra = 5 × 20 ft = 0,10 MLF, más el par 0-10V que va aparte (e19).
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', 2),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', 'JB 1900 DEEP BOX', 1),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '2  GANG PLASTER RING 1/2"', 1),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '2G DECORA WALLPLATE STAINLESS STEEL', 1),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', 'PLATE ENGRAVING (per gang)', 2),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '1/2"     EMT CONDUIT', 20),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '# 12      THHN STRANDED CU.', 0.1),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', '#12     GROUND PIGTAIL', 1),
    ('DIMMER 0-10V/SENSOR DOBLE (2 GANG) — EMT', 'YELLOW WIRENUTS', 6)
  ) as v(receta, item, cantidad)
  join ensambles e on e.nombre = v.receta
 where not exists (select 1 from ensamble_items x where x.ensamble_id = e.id and x.item = v.item);

-- -------------------------------------------------------------------------
-- 4) COMPROBAR (segundo pegado, aparte). Tiene que dar 2 filas, huerfanos = 0,
--    y las horas del punto parecidas a las del comentario de cada receta.
-- -------------------------------------------------------------------------
-- select e.nombre, count(ei.id) as componentes,
--        round(sum(ei.cantidad * coalesce(c.horas_unidad,0))::numeric, 2) as horas,
--        round(sum(ei.cantidad * coalesce(c.precio,0))::numeric, 2) as material,
--        count(*) filter (where c.id is null) as huerfanos
--   from ensambles e
--   join ensamble_items ei on ei.ensamble_id = e.id
--   left join catalogo_items c
--          on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
--           = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  where e.orden between 215 and 216
--  group by e.nombre, e.orden order by e.orden;
