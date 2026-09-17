-- ============================================================================
-- E23 · EL ESTIMADO DE NICKLAUS, DE UNA VEZ (17/09/2026)
-- ============================================================================
-- Edgar: «ahora tengo que pasarlo todo manual». No: esto crea el estimado
-- BORRADOR con los 49 renglones del takeoff (docs/nch/TAKEOFF-NCH-COMPLETO.csv
-- y el Excel NCH-BID-2026-09-17.xlsx), ya explotados: cajas, anillos, tapas,
-- conectores, wirenuts, tubo y cable medidos en Bluebeam, breakers, luminarias.
-- Precio unitario = el MAS CARO entre CED Q1009347 y CES CWD/003993.
-- Material 44,003.97 · 633.8 horas. Se corre UNA vez.
--
-- Va como items sueltos (no como recetas) a proposito: es exactamente lo que
-- dice el Excel, sin depender de como el estimador explote cada receta, y sin
-- nada dos veces. El estimador le pone encima tu tarifa, overhead, utilidad,
-- merma (5 % tubo, 10 % cable en modo planos) y sus autos: revisalos.
--
-- OJO antes de entregar: el renglon UL 924 va a $832,86 (Lutron LUT-ELI-3PH,
-- lo que cotizo CES). Si es un rele por luminaria, cambia ese precio en el
-- estimador (o aqui, antes de correrlo). Y los troffers/exit/cans van a
-- precio de referencia: nadie los cotizo.
-- ============================================================================

with e as (
  insert into estimados (nombre, cliente, direccion, estado, modo, notas)
  values (
    'NCH Radiology Expansion Ultrasound — bid 17/09/2026',
    'Nicklaus Children''s Health System',
    '3100 SW 62nd Ave, Miami FL 33155',
    'borrador',
    'remodelacion',   -- NO 'planos': en modo planos el estimador le sumaria SUS acoples, conectores, grapas y tapcons a los que ya vienen aqui (dos veces)
    'Takeoff completo 17/09: conteos del documento de dispositivos x recetas + tubo y cable medidos en Bluebeam. Precios: el mas caro CED/CES. Pendientes: producto del rele UL 924 (21 x $832,86), luminarias sin cotizar (STAK 2x2, SCR 22, Day-Brite), combo dimmer/sensor $120 ref.'
  )
  returning id
)
insert into estimado_items (estimado_id, item, unidad, precio, horas, cantidad, origen, codigo, orden)
select e.id, v.item, v.unidad, v.precio, v.horas, v.cantidad, 'takeoff-nch-2026-09-17', v.codigo, v.orden
from e, (values
  ('NEMA 1 ENCLOSURE 12x12x4', 'E', 211.43, 1.5, 7.0, '05-PANEL', 10),
  ('NEMA 1 ENCLOSURE COVER 12x12', 'E', 69.72, 0.3, 7.0, '05-PANEL', 20),
  ('BREAKER 1P 20A', 'E', 8.0, 0.25, 12.0, '05-PANEL', 30),
  ('# 12      THHN STRANDED CU.', 'MLF', 272.6, 6.0, 17.43, '08-ROUGH', 40),
  ('#12     GROUND PIGTAIL', 'E', 0.17, 0.01, 238.0, '08-ROUGH', 50),
  ('PULL STRING', 'MLF', 15.75, 4.0, 0.54, '08-ROUGH', 60),
  ('1/2"     EMT CONDUIT', 'LF', 0.6124, 0.03, 3433.0, '09-COND', 70),
  ('1"         EMT CONDUIT', 'LF', 1.8776, 0.045, 440.0, '09-COND', 80),
  ('1/2"       EMT S.S. D/C CONNECTOR', 'E', 1.1679, 0.06, 486.0, '09-COND', 90),
  ('JB 1900 DEEP BOX', 'E', 1.8261, 0.25, 206.0, '09-COND', 100),
  ('3/8"      FLEX. METAL CONDUIT', 'LF', 0.904, 0.025, 414.0, '09-COND', 110),
  ('1/2"       EMT S.S. D/C COUPLING', 'E', 0.4529, 0.04, 406.5, '09-COND', 120),
  ('1  GANG PLASTER RING 1/2"', 'E', 0.8617, 0.05, 156.0, '09-COND', 130),
  ('T-BAR BOX HANGER', 'E', 1.06, 0.05, 106.0, '09-COND', 140),
  ('1/2"      EMT STRAP 1 HOLE STRAP', 'E', 0.1459, 0.02, 586.0, '09-COND', 150),
  ('3/8"      FLEX. METAL ST. CONNECT.', 'E', 0.588, 0.08, 138.0, '09-COND', 160),
  ('JB 1900 BOX', 'E', 1.04, 0.25, 76.0, '09-COND', 170),
  ('1"           EMT S.S.D/C  COUPLING', 'E', 0.8007, 0.05, 44.0, '09-COND', 180),
  ('4"X4" BLANK COVER', 'E', 0.804, 0.07, 42.0, '09-COND', 190),
  ('1"           EMT S.S.D/C CONNECTOR', 'E', 0.5452, 0.08, 44.0, '09-COND', 200),
  ('1"          EMT STRAP 1 HOLE STARP', 'E', 0.2087, 0.025, 88.0, '09-COND', 210),
  ('4-11/16 BOX', 'E', 6.75, 0.35, 2.0, '09-COND', 220),
  ('2  GANG PLASTER RING 1/2"', 'E', 1.2495, 0.05, 8.0, '09-COND', 230),
  ('G 4000  WIREMOLD DIVIDER', 'LF', 0.84, 0.01, 7.0, '09-COND', 240),
  ('CEILING RING  1/2"', 'E', 0.599, 0.1, 7.0, '09-COND', 250),
  ('0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', 'E', 120.0, 0.6, 22.0, '10-DEV', 260),
  ('PLATE ENGRAVING (per gang)', 'E', 10.0, 0.0, 132.0, '10-DEV', 270),
  ('20A HOSPITAL GRADE TR RECEPTACLE', 'E', 16.9, 0.4, 63.0, '10-DEV', 280),
  ('20A GFCI HOSPITAL GRADE TR/WR', 'E', 56.99, 0.5, 14.0, '10-DEV', 290),
  ('PIR OCCUPANCY SENSOR', 'E', 66.16, 1.26, 9.0, '10-DEV', 300),
  ('20A HOSPITAL GRADE TR RECEPTACLE RED', 'E', 16.9, 0.4, 23.0, '10-DEV', 310),
  ('20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE', 'E', 11.8, 0.2, 7.0, '10-DEV', 320),
  ('20A GFCI HOSPITAL GRADE RED', 'E', 56.99, 0.5, 1.0, '10-DEV', 330),
  ('1G PLASTIC COVER RECEPTACLE', 'E', 0.55, 0.08, 54.0, '10-DEV', 340),
  ('1G PLASTIC COVER SWITCH', 'E', 0.24, 0.08, 38.0, '10-DEV', 350),
  ('1G DUPLEX WALLPLATE RED', 'E', 0.27, 0.08, 24.0, '10-DEV', 360),
  ('UL 924 EMERGENCY LIGHTING CONTROL RELAY', 'E', 832.86, 0.75, 21.0, '11-LIGHT', 370),
  ('24"X24" LED TROFFER (RECESSED)', 'E', 75.0, 1.0, 66.0, '11-LIGHT', 380),
  ('EXIT SIGN BACK/TOP MTD', 'E', 80.0, 0.75, 7.0, '11-LIGHT', 390),
  ('4" RECESSED CAN LIGHT', 'E', 172.0, 0.75, 3.0, '11-LIGHT', 400),
  ('TIME CLOCK 4PST 40A W/ OVERRIDE (INTERMATIC T7401B)', 'E', 270.22, 2.0, 1.0, '11-LIGHT', 410),
  ('FIXTURES HOLDER CLIPS', 'E', 0.45, 0.1, 264.0, '11-LIGHT', 420),
  ('1" ISOLATING BUSHING', 'E', 0.189, 0.15, 44.0, '13-LV', 430),
  ('1/2" ISOLATING BUSHING', 'EA', 0.07, 0.1, 1.0, '13-LV', 440),
  ('PUTTY PAD SEAL', 'E', 6.49, 0.0, 60.0, '20-MISC', 450),
  ('18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)', 'MLF', 330.0, 8.0, 1.0, '20-MISC', 460),
  ('YELLOW WIRENUTS', 'E', 0.26, 0.0, 798.0, '20-MISC', 470),
  ('RED FIRE CAULK 10.3 OZ TUBE', 'E', 14.63, 0.1, 12.0, '20-MISC', 480),
  ('2G DUPLEX WALLPLATE STAINLESS STEEL', 'E', 8.0, 0.1, 8.0, '20-MISC', 490),
  ('1/2"     EMT CONDUIT', 'LF', 0.6124, 0, 172, '09-COND', 500),          -- merma 5 % del tubo medido (3.433 ft)
  ('1"         EMT CONDUIT', 'LF', 1.8776, 0, 22, '09-COND', 510),          -- merma 5 % de los stubs (440 ft)
  ('# 12      THHN STRANDED CU.', 'MLF', 272.6, 0, 1.743, '08-ROUGH', 520)  -- merma 10 % del cable (17.430 ft), puntas y rollos
) as v(item, unidad, precio, horas, cantidad, codigo, orden);

-- ── Comprobar: debe dar 52 renglones (49 + 3 de merma), 44,625.44 de material y 633.8 horas ──
select count(*) as renglones,
       round(sum(cantidad * precio)::numeric, 2) as material,
       round(sum(cantidad * horas)::numeric, 2) as horas
from estimado_items
where origen = 'takeoff-nch-2026-09-17';

-- ── Si hay que deshacerlo (se corrio dos veces, etc.) ──
-- delete from estimado_items where origen = 'takeoff-nch-2026-09-17';
-- delete from estimados where nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';

-- ── Si YA lo habias corrido antes de este cambio (sin modo y sin merma): ──
-- update estimados set modo = 'remodelacion' where nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';
-- insert into estimado_items (estimado_id, item, unidad, precio, horas, cantidad, origen, codigo, orden)
-- select id, v.* from estimados, (values
--   ('1/2"     EMT CONDUIT', 'LF', 0.6124, 0, 172, 'takeoff-nch-2026-09-17', '09-COND', 500),
--   ('1"         EMT CONDUIT', 'LF', 1.8776, 0, 22, 'takeoff-nch-2026-09-17', '09-COND', 510),
--   ('# 12      THHN STRANDED CU.', 'MLF', 272.6, 0, 1.743, 'takeoff-nch-2026-09-17', '08-ROUGH', 520)
-- ) as v(item, unidad, precio, horas, cantidad, origen, codigo, orden)
-- where nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';
