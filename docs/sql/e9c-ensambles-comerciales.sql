-- =====================================================================
-- E9 · Las recetas que te faltaban: comercial en EMT y en MC
-- Supabase → SQL Editor. Un solo pegado. Idempotente (no duplica).
--
-- Tus 10 recetas de hoy están limpias — ni un componente huérfano — pero
-- TODAS son residenciales: romex, caja de plástico, staples y conector NM.
-- Y no tienes ninguna de modo PLANOS, que es el comercial.
--
-- Esto añade 8 recetas comerciales, en los dos métodos que de verdad usas
-- en obra: MC (comercial ligero, tienda, oficina) y EMT con THHN (obra
-- grande, lo que harías con Roger). Todos los componentes salen con el
-- NOMBRE EXACTO de tu catálogo, así que ninguna nace huérfana.
--
-- Las cantidades de cable son por unidad y se pueden medir: las cuatro con
-- pies_editable = true dejan poner los pies reales del plano.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) Dejar entrar el modo «comercial»
-- ---------------------------------------------------------------------
-- La tabla tiene una regla que solo admite ciertos modos, y «comercial»
-- no estaba en la lista. Esto la amplía conservando los que ya usas.
-- (Si quieres ver cómo está antes de tocarla:
--    select pg_get_constraintdef(oid) from pg_constraint
--     where conname = 'ensambles_modo_check';)
alter table ensambles drop constraint if exists ensambles_modo_check;
alter table ensambles add  constraint ensambles_modo_check
  check (modo in ('remodelacion','servicio','comercial','planos','rapido'));

-- ---------------------------------------------------------------------
-- 1) Las recetas
-- ---------------------------------------------------------------------
insert into ensambles (nombre, modo, pies_editable, orden)
select v.nombre, 'comercial', v.pies, v.orden
  from (values
    ('RECEPTÁCULO 20A — EMT',        true,  1),
    ('RECEPTÁCULO 20A — MC',         true,  2),
    ('SWITCH SENCILLO — EMT',        true,  3),
    ('SWITCH SENCILLO — MC',         true,  4),
    ('LUMINARIA 2X4 — EMT',          true,  5),
    ('LUMINARIA 2X4 — MC',           true,  6),
    ('CIRCUITO 20A DERIVADO — EMT',  true,  7),
    ('SALIDA DE DATOS — EMT',        true,  8)
  ) as v(nombre, pies, orden)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

-- ---------------------------------------------------------------------
-- 2) Los componentes
-- ---------------------------------------------------------------------
-- Cómo leer las cantidades:
--   · Cable y tubo van por unidad: 0.025 MLF = 25 pies. THHN = pies × hilos.
--   · EMT: un acople cada 10 pies y una grapa cada 8, que es lo que pide el
--     código; dos conectores por salida (entra y sale).
--   · MC: dos conectores snap-in por salida.
--   · En comercial la caja es 4-11/16 con plaster ring, no caja de plástico.
insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    -- RECEPTÁCULO 20A — EMT (25 pies de 1/2", 3 hilos de #12)
    ('RECEPTÁCULO 20A — EMT', '20A DUPLEX RECEPTACLE',          1),
    ('RECEPTÁCULO 20A — EMT', '4-11/16 BOX',                    1),
    ('RECEPTÁCULO 20A — EMT', '1  GANG PLASTER RING 1/2"',      1),
    ('RECEPTÁCULO 20A — EMT', '1/2"     EMT CONDUIT',          25),
    ('RECEPTÁCULO 20A — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO 20A — EMT', '1/2"       EMT S.S. D/C COUPLING',  2.5),
    ('RECEPTÁCULO 20A — EMT', '1/2"      EMT STRAP 1 HOLE STRAP',  3),
    ('RECEPTÁCULO 20A — EMT', '# 12      THHN STRANDED CU.',   0.075),
    ('RECEPTÁCULO 20A — EMT', '#12     GROUND PIGTAIL',          1),
    ('RECEPTÁCULO 20A — EMT', 'YELLOW WIRENUTS',                 3),

    -- RECEPTÁCULO 20A — MC (25 pies de 12/2 MC)
    ('RECEPTÁCULO 20A — MC',  '20A DUPLEX RECEPTACLE',          1),
    ('RECEPTÁCULO 20A — MC',  '4-11/16 BOX',                    1),
    ('RECEPTÁCULO 20A — MC',  '1  GANG PLASTER RING 1/2"',      1),
    ('RECEPTÁCULO 20A — MC',  '12/2   MC',                  0.025),
    ('RECEPTÁCULO 20A — MC',  'MC SNAP-IN CONNECTOR 3/8"',      2),
    ('RECEPTÁCULO 20A — MC',  '#12     GROUND PIGTAIL',         1),
    ('RECEPTÁCULO 20A — MC',  'YELLOW WIRENUTS',                3),

    -- SWITCH SENCILLO — EMT (20 pies)
    ('SWITCH SENCILLO — EMT', 'SINGLE POLE SWITCH',             1),
    ('SWITCH SENCILLO — EMT', '4-11/16 BOX',                    1),
    ('SWITCH SENCILLO — EMT', '1  GANG PLASTER RING 1/2"',      1),
    ('SWITCH SENCILLO — EMT', '1/2"     EMT CONDUIT',          20),
    ('SWITCH SENCILLO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SWITCH SENCILLO — EMT', '1/2"       EMT S.S. D/C COUPLING',  2),
    ('SWITCH SENCILLO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP',  3),
    ('SWITCH SENCILLO — EMT', '# 12      THHN STRANDED CU.',   0.06),
    ('SWITCH SENCILLO — EMT', 'YELLOW WIRENUTS',                3),

    -- SWITCH SENCILLO — MC (20 pies)
    ('SWITCH SENCILLO — MC',  'SINGLE POLE SWITCH',             1),
    ('SWITCH SENCILLO — MC',  '4-11/16 BOX',                    1),
    ('SWITCH SENCILLO — MC',  '1  GANG PLASTER RING 1/2"',      1),
    ('SWITCH SENCILLO — MC',  '12/2   MC',                   0.02),
    ('SWITCH SENCILLO — MC',  'MC SNAP-IN CONNECTOR 3/8"',      2),
    ('SWITCH SENCILLO — MC',  'YELLOW WIRENUTS',                3),

    -- LUMINARIA 2X4 — EMT (15 pies desde la anterior)
    ('LUMINARIA 2X4 — EMT',   '24"X48" LED TROFFER (RECESSED)', 1),
    ('LUMINARIA 2X4 — EMT',   'JB 1900 BOX',                    1),
    ('LUMINARIA 2X4 — EMT',   '1/2"     EMT CONDUIT',          15),
    ('LUMINARIA 2X4 — EMT',   '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('LUMINARIA 2X4 — EMT',   '1/2"       EMT S.S. D/C COUPLING',  1.5),
    ('LUMINARIA 2X4 — EMT',   '1/2"      EMT STRAP 1 HOLE STRAP',  2),
    ('LUMINARIA 2X4 — EMT',   '# 12      THHN STRANDED CU.',  0.045),
    ('LUMINARIA 2X4 — EMT',   'YELLOW WIRENUTS',                3),

    -- LUMINARIA 2X4 — MC (15 pies)
    ('LUMINARIA 2X4 — MC',    '24"X48" LED TROFFER (RECESSED)', 1),
    ('LUMINARIA 2X4 — MC',    'JB 1900 BOX',                    1),
    ('LUMINARIA 2X4 — MC',    '12/2   MC',                  0.015),
    ('LUMINARIA 2X4 — MC',    'MC SNAP-IN CONNECTOR 3/8"',      2),
    ('LUMINARIA 2X4 — MC',    'YELLOW WIRENUTS',                3),

    -- CIRCUITO 20A DERIVADO — EMT: del panel a la primera salida, 60 pies
    ('CIRCUITO 20A DERIVADO — EMT', 'BREAKER 1P 20A',           1),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"     EMT CONDUIT',    60),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"       EMT S.S. D/C COUPLING',  6),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP',  8),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"       EMT ELBOW',     2),
    ('CIRCUITO 20A DERIVADO — EMT', '# 12      THHN STRANDED CU.', 0.18),
    ('CIRCUITO 20A DERIVADO — EMT', '1/2"       LOCKNUT',       2),

    -- SALIDA DE DATOS — EMT (tubo vacío con hilo guía; el cable lo pone el de low voltage)
    ('SALIDA DE DATOS — EMT', 'DATA OUTLET (1 PORT)',           1),
    ('SALIDA DE DATOS — EMT', '4-11/16 BOX',                    1),
    ('SALIDA DE DATOS — EMT', '1  GANG PLASTER RING 1/2"',      1),
    ('SALIDA DE DATOS — EMT', '1/2"     EMT CONDUIT',          30),
    ('SALIDA DE DATOS — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE DATOS — EMT', '1/2"       EMT S.S. D/C COUPLING',  3),
    ('SALIDA DE DATOS — EMT', '1/2"      EMT STRAP 1 HOLE STRAP',  4)
  ) as v(ensamble, item, cantidad)
  join ensambles e on e.nombre = v.ensamble and e.modo = 'comercial'
 where not exists (select 1 from ensamble_items x
                    where x.ensamble_id = e.id and x.item = v.item);

-- ---------------------------------------------------------------------
-- 3) COMPROBAR: ni un solo componente puede quedar sin catálogo
-- ---------------------------------------------------------------------
select e.nombre as ensamble, ei.item as componente, ei.cantidad,
       case when c.id is null then '✗ SIN CATÁLOGO — avísame' else 'ok' end as estado
  from ensambles e
  join ensamble_items ei on ei.ensamble_id = e.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where e.modo = 'comercial'
   and c.id is null
 order by 1, 2;
-- 0 filas = todas las recetas nuevas apuntan a items que existen.

-- Y el resumen: 8 recetas nuevas con lo que cuesta cada una
select e.nombre,
       count(ei.id)                                   as componentes,
       round(sum(ei.cantidad * coalesce(c.precio,0))::numeric, 2)       as material,
       round(sum(ei.cantidad * coalesce(c.horas_unidad,0))::numeric, 2) as horas
  from ensambles e
  join ensamble_items ei on ei.ensamble_id = e.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where e.modo = 'comercial'
 group by e.nombre, e.orden order by e.orden;


-- =====================================================================
-- DESHACER
-- =====================================================================
--   delete from ensamble_items where ensamble_id in (select id from ensambles where modo = 'comercial');
--   delete from ensambles where modo = 'comercial';
--   alter table ensambles drop constraint if exists ensambles_modo_check;
--   alter table ensambles add  constraint ensambles_modo_check
--     check (modo in ('remodelacion','servicio'));
