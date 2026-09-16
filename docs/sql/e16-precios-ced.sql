-- =====================================================================
-- E16 · Precios contra la cotizacion de CED (Mike Jarot, 15/09)
--       Quote Q1009347 · trabajo: NICKLAUS CHILDREN'S · vence 06/10/26
-- =====================================================================
-- ANTES DE CORRER NADA, LA TRAMPA:
--
-- Esta cotizacion es de un HOSPITAL. Los receptaculos que cotiza Mike son
-- HOSPITAL GRADE ($16,90 el duplex, $40,47 el GFCI). Tu catalogo dice
-- $1,44 y $16,39 — y eso NO esta mal: es el duplex comercial corriente.
-- Si machacas esas dos filas con los precios de hospital, TODOS tus bids
-- comerciales suben un 1.000 % en los receptaculos y pierdes los trabajos.
-- Por eso el hospital grade va como filas NUEVAS, no como cambio.
--
-- Lo que SI es comparable son las commodities: tubo, conectores, acoples,
-- grapas, cajas, anillos, cable, putty pad. Ahi tu catalogo esta entre un
-- 15 % y un 30 % por debajo de lo que te cobran HOY. Eso lo pagas tu.
-- =====================================================================

create table if not exists catalogo_items_respaldo_ced_20260916 as select * from catalogo_items;

-- ---------------------------------------------------------------------
-- BLOQUE 1 · COMMODITIES: tu precio al de CED de hoy  (19)
-- ---------------------------------------------------------------------

-- 1/2"     EMT CONDUIT
--   CED COND EMT050: $0.542 · tu catalogo: $0.525 · +3 %
--   7.000 ft cotizados.
update catalogo_items set precio = 0.542
   where item = '1/2"     EMT CONDUIT' and coalesce(precio,0) = 0.525;

-- 3/4"     EMT CONDUIT
--   CED COND EMT075: $1.0059 · tu catalogo: $0.85 · +18 %
--   5.000 ft cotizados.
update catalogo_items set precio = 1.0059
   where item = '3/4"     EMT CONDUIT' and coalesce(precio,0) = 0.85;

-- 1"       EMT CONDUIT
--   CED COND EMT100: $1.7323 · tu catalogo: $1.375 · +26 %
--   3.000 ft cotizados.
update catalogo_items set precio = 1.7323
   where item = '1"         EMT CONDUIT' and coalesce(precio,0) = 1.375;

-- 1/2"       EMT S.S. D/C CONNECTOR
--   CED SWIRE 631SI: $0.3977 · tu catalogo: $0.266 · +50 %
--   conector aislado de tornillo.
update catalogo_items set precio = 0.3977
   where item = '1/2"       EMT S.S. D/C CONNECTOR' and coalesce(precio,0) = 0.266;

-- 3/4"       EMT S.S. D/C CONNECTOR
--   CED SWIRE 632SI: $0.5469 · tu catalogo: $0.399 · +37 %
--   conector aislado de tornillo.
update catalogo_items set precio = 0.5469
   where item = '3/4"       EMT S.S. D/C CONNECTOR' and coalesce(precio,0) = 0.399;

-- 1/2"       EMT S.S. D/C COUPLING
--   CED SWIRE 641S: $0.3811 · tu catalogo: $0.306 · +25 %
update catalogo_items set precio = 0.3811
   where item = '1/2"       EMT S.S. D/C COUPLING' and coalesce(precio,0) = 0.306;

-- 3/4"       EMT S.S. D/C COUPLING
--   CED SWIRE 642S: $0.4309 · tu catalogo: $0.346 · +25 %
update catalogo_items set precio = 0.4309
   where item = '3/4"       EMT S.S. D/C COUPLING' and coalesce(precio,0) = 0.346;

-- 1/2"      EMT STRAP 1 HOLE STRAP
--   CED SWIRE 511: $0.0851 · tu catalogo: $0.0682 · +25 %
update catalogo_items set precio = 0.0851
   where item = '1/2"      EMT STRAP 1 HOLE STRAP' and coalesce(precio,0) = 0.0682;

-- 3/4"      EMT STRAP 1 HOLE STRAP
--   CED SWIRE 512: $0.1044 · tu catalogo: $0.0838 · +25 %
update catalogo_items set precio = 0.1044
   where item = '3/4"      EMT STRAP 1 HOLE STRAP' and coalesce(precio,0) = 0.0838;

-- 1"          EMT STRAP 1 HOLE STARP
--   CED SWIRE 513: $0.2087 · tu catalogo: $0.1676 · +25 %
update catalogo_items set precio = 0.2087
   where item = '1"          EMT STRAP 1 HOLE STARP' and coalesce(precio,0) = 0.1676;

-- 1/2"      FLEX. METAL ST. CONNECT.
--   CED SWIRE 151I: $1.0631 · tu catalogo: $0.893 · +19 %
update catalogo_items set precio = 1.0631
   where item = '1/2"      FLEX. METAL ST. CONNECT.' and coalesce(precio,0) = 0.893;

-- 1" ISOLATING BUSHING
--   CED SWIRE 833: $0.189 · tu catalogo: $0.15 · +26 %
update catalogo_items set precio = 0.189
   where item = '1" ISOLATING BUSHING' and coalesce(precio,0) = 0.15;

-- JB 1900 DEEP BOX
--   CED SWIRE 52171S: $1.5743 · tu catalogo: $1.04 · +51 %
--   4SQ 2-1/8 deep con KO combo.
--   OJO: el bloque A2 la puso en $1,04 con tu factura de Stuart; CED de HOY dice $1,57.
--   Manda la de hoy.
update catalogo_items set precio = 1.5743
   where item = 'JB 1900 DEEP BOX' and coalesce(precio,0) = 1.04;

-- 1  GANG PLASTER RING 1/2"
--   CED SWIRE 52C14-5/8: $0.8617 · tu catalogo: $0.357 · +141 %
--   4SQ 5/8 deep 1G.
update catalogo_items set precio = 0.8617
   where item = '1  GANG PLASTER RING 1/2"' and coalesce(precio,0) = 0.357;

-- 2  GANG PLASTER RING 1/2"
--   CED SWIRE 52C18-5/8: $1.1269 · tu catalogo: $0.357 · +216 %
--   4SQ 5/8 deep 2G.
--   Tenia el precio del 1G copiado ($0,357): la auditoria ya lo habia olido.
update catalogo_items set precio = 1.1269
   where item = '2  GANG PLASTER RING 1/2"' and coalesce(precio,0) = 0.357;

-- 4"X4" BLANK COVER
--   CED SWIRE 52C1: $0.6297 · tu catalogo: $0.273 · +131 %
update catalogo_items set precio = 0.6297
   where item = '4"X4" BLANK COVER' and coalesce(precio,0) = 0.273;

-- PUTTY PAD SEAL
--   CED POST CHIP7070: $6.49 · tu catalogo: $2.8 · +132 %
--   firestop putty pad.
update catalogo_items set precio = 6.49
   where item = 'PUTTY PAD SEAL' and coalesce(precio,0) = 2.8;

-- # 12      THHN STRANDED CU.
--   CED WIRE THHN12STRBK: $254.54 por MIL pies · tu catalogo: $220.94 · +15 %
--   por MIL pies, negro trenzado.
update catalogo_items set precio = 254.54
   where item = '# 12      THHN STRANDED CU.' and coalesce(precio,0) = 220.94;

-- # 10      THHN STRANDED CU.
--   CED WIRE THHN10STRGN: $450.83 por MIL pies · tu catalogo: $340.69 · +32 %
--   por MIL pies, verde trenzado.
update catalogo_items set precio = 450.83
   where item = '# 10      THHN STRANDED CU.' and coalesce(precio,0) = 340.69;

-- ---------------------------------------------------------------------
-- BLOQUE 2 · ALTAS: lo que Mike cotiza y tu no tienes  (11)
-- ---------------------------------------------------------------------
-- Las dos primeras son un hueco de verdad: te falta el fitting de 1".

-- 1"         EMT S.S. D/C CONNECTOR
--   NO EXISTE en tu catalogo.
--   Tienes el 1/2", el 3/4" y del 1-1/4" para arriba: falta justo el de 1".
--   Cada corrida de 1" se cotiza hoy sin conectores.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('1"         EMT S.S. D/C CONNECTOR', 'RACEWAY', 'E', 0.9446, 0.08, '09-COND') on conflict do nothing;

-- 1"         EMT S.S. D/C COUPLING
--   Mismo hueco que el conector de 1".
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('1"         EMT S.S. D/C COUPLING', 'RACEWAY', 'E', 0.6299, 0.05, '09-COND') on conflict do nothing;

-- 20A HOSPITAL GRADE TR RECEPTACLE
--   Bryant BRY8300ITR.
--   Hospital grade + tamper resistant, lo que pide Nicklaus.
--   NO toca tu duplex corriente de $1,44.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('20A HOSPITAL GRADE TR RECEPTACLE', 'WIRING DEVICES', 'E', 16.9, 0.4, '10-DEV') on conflict do nothing;

-- 20A GFCI HOSPITAL GRADE TR/WR
--   Bryant GFRTW83I.
--   Hospital grade + TR + WR.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('20A GFCI HOSPITAL GRADE TR/WR', 'WIRING DEVICES', 'E', 40.47, 0.5, '10-DEV') on conflict do nothing;

-- 1/2"      ALUM. FLEX CONDUIT
--   Flex de ALUMINIO.
--   No es tu flex metalico de acero ($0,263): es otra pieza.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('1/2"      ALUM. FLEX CONDUIT', 'RACEWAY', 'LF', 0.7353, 0.025, '09-COND') on conflict do nothing;

-- RED FIRE CAULK 10.3 OZ TUBE
--   Sellado cortafuego.
--   Va con el putty pad en cada penetracion.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('RED FIRE CAULK 10.3 OZ TUBE', 'MISCELLANEOUS', 'E', 14.63, 0.1, '20-MISC') on conflict do nothing;

-- 1G DUPLEX WALLPLATE RED
--   Tapa roja: el circuito de emergencia se identifica por color.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('1G DUPLEX WALLPLATE RED', 'WIRING DEVICES', 'E', 0.27, 0.08, '10-DEV') on conflict do nothing;

-- PLATE ENGRAVING (per gang)
--   Grabado de la tapa, por gang.
--   En hospital lo piden casi siempre y son $10 la unidad: 94 tapas grabadas son $940.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('PLATE ENGRAVING (per gang)', 'WIRING DEVICES', 'E', 10, 0, '10-DEV') on conflict do nothing;

-- 4 FT LED STRIP FIXTURE (adjustable)
--   Lithonia CSSL48.
--   Tu LED STRIP es por pie; esta es la luminaria de 4 ft entera.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('4 FT LED STRIP FIXTURE (adjustable)', 'LIGHTING FIXTURES', 'E', 72.86, 0.75, '11-LIGHT') on conflict do nothing;

-- NEMA 1 ENCLOSURE 12x12x4
--   Hubbell NSAV124M, con su tapa aparte.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('NEMA 1 ENCLOSURE 12x12x4', 'SWITCHGEAR', 'E', 211.43, 1.5, '05-PANEL') on conflict do nothing;

-- NEMA 1 ENCLOSURE COVER 12x12
--   Hubbell NSAV12C, la tapa del anterior.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values
  ('NEMA 1 ENCLOSURE COVER 12x12', 'SWITCHGEAR', 'E', 69.72, 0.3, '05-PANEL') on conflict do nothing;

-- ---------------------------------------------------------------------
-- BLOQUE 3 · TRES QUE MIRAS TU  (3)
-- ---------------------------------------------------------------------

-- 4-11/16 BOX   [tuyo $6.75 · CED $3.2977]
--   CED la cotiza a $3,30 y tu catalogo dice $6,75: aqui TU precio es el doble.
--   Puede que el tuyo incluya algo mas, o que sea de una carga vieja cara.
--   Si $3,30 es lo que pagas, estas inflando cada caja.
-- update catalogo_items set precio = 3.2977 where item = '4-11/16 BOX';

-- 1G PLASTIC COVER RECEPTACLE   [tuyo $0.55 · CED $0.27]
--   CED $0,27 contra tus $0,55.
--   El tuyo salio de Stuart.
--   Bajarlo te hace mas competitivo pero te come margen si de verdad pagas $0,55.
-- update catalogo_items set precio = 0.27 where item = '1G PLASTIC COVER RECEPTACLE';

-- 1/2"      FLEX. METAL CONDUIT   [tuyo $0.263 · CED $0.7353]
--   CED cotiza flex de ALUMINIO a $0,735; el tuyo es de acero a $0,263.
--   Son piezas distintas — por eso el aluminio va como alta aparte, no como cambio de este.
-- update catalogo_items set precio = 0.7353 where item = '1/2"      FLEX. METAL CONDUIT';

-- ---------------------------------------------------------------------
-- COMPROBAR
-- ---------------------------------------------------------------------
-- select item, unidad, precio, horas_unidad from catalogo_items
--  where item in ('1/2"     EMT CONDUIT', '3/4"     EMT CONDUIT', '1"         EMT CONDUIT', '1/2"       EMT S.S. D/C CONNECTOR', '3/4"       EMT S.S. D/C CONNECTOR', '1/2"       EMT S.S. D/C COUPLING', '3/4"       EMT S.S. D/C COUPLING', '1/2"      EMT STRAP 1 HOLE STRAP', '3/4"      EMT STRAP 1 HOLE STRAP', '1"          EMT STRAP 1 HOLE STARP', '1/2"      FLEX. METAL ST. CONNECT.', '1" ISOLATING BUSHING', 'JB 1900 DEEP BOX', '1  GANG PLASTER RING 1/2"', '2  GANG PLASTER RING 1/2"', '4"X4" BLANK COVER', 'PUTTY PAD SEAL', '# 12      THHN STRANDED CU.', '# 10      THHN STRANDED CU.')
--  order by item;
