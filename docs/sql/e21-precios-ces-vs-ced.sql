-- =========================================================================
-- E21 · LOS DOS SUMINISTROS CRUZADOS, Y MANDA EL MÁS CARO
--   CED Supply  · Q1009347       (Nicklaus, 15/09)
--   C.E.S. Carrollwood · CWD/003993 (Tampa, 16/09 — Jose Margarito)
--
-- Regla de Edgar (17/09): «toma siempre el más caro de cada uno por si acaso,
-- estar cubierto». Aquí está aplicada renglón por renglón. Donde tu catálogo
-- ya era el más caro, NO SE TOCA y se dice por qué (bloque 2), para que se
-- vea que se revisó y no que se olvidó.
--
-- Corre DESPUÉS de e16, e18 y e19. Cada update lleva su guarda con el valor
-- que dejó el SQL anterior: si ya lo cambiaste a mano, esta línea no hace
-- nada y no te pisa el número.
--
-- ⚠⚠ LEE EL BLOQUE 0 ANTES DE CORRER ESTO ⚠⚠
-- =========================================================================

-- =========================================================================
-- BLOQUE 0 · LO QUE HAY QUE PREGUNTAR ANTES DE FIRMAR
-- =========================================================================
-- EL RELÉ UL 924 — $17.490 de una cotización de $22.177
--
--   CES cotizó 21 × LUTRON LUT-ELI-3PH a $832.86 = $17.490,29. Eso es el
--   79 % de la cotización entera, y 6 veces lo que costó todo lo demás junto.
--
--   El precio es real: online el LUT-ELI-3PH va de $649 a $1.164. El problema
--   no es el precio, es el APARATO. El LUT-ELI-3PH es una «Emergency Lighting
--   Interface» de GRAFIK Eye: un detector TRIFÁSICO de nivel de PANEL, uno
--   por sistema de control de luz. El plano (E-2.2 / P2-C) pide «UL 924
--   emergency lighting control relay, 21» — un relé POR LUMINARIA de
--   emergencia, que es otra cosa y cuesta entre $70 y $380:
--       Functional Devices ESRN (con override 0-10V)  ~$70
--       Bodine GTD20A                             $240 – $382
--       Wattstopper ELCU-200                      $531 MSRP
--
--   Si son 21 relés y no 21 interfaces, el renglón pasa de $17.490 a entre
--   $1.470 y $8.000. La diferencia es de $9.000 a $16.000 EN UN SOLO RENGLÓN.
--
--   Por la regla de Edgar aquí se pone $832.86 (el más caro, para estar
--   cubierto). Pero antes de firmar hay que preguntárselo al ingeniero o a
--   Jose, porque un bid con $16.000 de más se pierde. Cuando contesten,
--   descomenta UNA de estas líneas:
--
-- update catalogo_items set precio = 531.00 where item = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY' and precio = 832.86;  -- Wattstopper ELCU-200
-- update catalogo_items set precio = 382.00 where item = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY' and precio = 832.86;  -- Bodine GTD20A (el más caro de sus tres precios)
-- update catalogo_items set precio =  70.00 where item = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY' and precio = 832.86;  -- Functional Devices ESRN

-- =========================================================================
-- BLOQUE 1 · LOS 22 QUE SUBEN (CES es más caro, o nadie los tenía)
-- =========================================================================

-- ── Tubería EMT ──────────────────────────────────────────────────────────
-- 1/2": CED $0.542 · CES $0.6124 (+13 %)
update catalogo_items set precio = 0.6124 where item = '1/2"     EMT CONDUIT'   and precio = 0.542;
-- 3/4": CED $1.0059 · CES $1.0903 (+8 %)
update catalogo_items set precio = 1.0903 where item = '3/4"     EMT CONDUIT'   and precio = 1.0059;
-- 1": CED $1.7323 · CES $1.8776 (+8 %)
update catalogo_items set precio = 1.8776 where item = '1"         EMT CONDUIT' and precio = 1.7323;

-- ── Conectores: el salto más grande de las dos cotizaciones ───────────────
--   CES cotiza TOPAZ con garganta aislada (el bueno para hospital); CED
--   cotizó SWIRE. Triplica el precio, y en 221 puntos son 442 conectores.
-- 1/2": CED $0.3977 · CES $1.1679 (+194 %)
update catalogo_items set precio = 1.1679 where item = '1/2"       EMT S.S. D/C CONNECTOR' and precio = 0.3977;
-- 3/4": CED $0.5469 · CES $1.8074 (+230 %)
update catalogo_items set precio = 1.8074 where item = '3/4"       EMT S.S. D/C CONNECTOR' and precio = 0.5469;
-- 1": CED $0.9446 · CES $3.2247 (+241 %) — la fila que dio de alta e16
update catalogo_items set precio = 3.2247 where item = '1"         EMT S.S. D/C CONNECTOR' and precio = 0.9446;

-- ── Acoples ──────────────────────────────────────────────────────────────
-- 1/2": CED $0.3811 · CES $0.4529 (+19 %)
update catalogo_items set precio = 0.4529 where item = '1/2"       EMT S.S. D/C COUPLING' and precio = 0.3811;
-- 3/4": CED $0.4309 · CES $0.4336 (+0,6 %, casi iguales)
update catalogo_items set precio = 0.4336 where item = '3/4"       EMT S.S. D/C COUPLING' and precio = 0.4309;
-- 1": CED $0.6299 · CES $0.8007 (+27 %) — alta de e16
update catalogo_items set precio = 0.8007 where item = '1"           EMT S.S.D/C  COUPLING' and precio = 0.6299;

-- ── Grapas ───────────────────────────────────────────────────────────────
-- 1/2": CED $0.0851 · CES $0.1459 (+71 %)
update catalogo_items set precio = 0.1459 where item = '1/2"      EMT STRAP 1 HOLE STRAP' and precio = 0.0851;
-- 3/4": CED $0.1044 · CES $0.2045 (+96 %)
update catalogo_items set precio = 0.2045 where item = '3/4"      EMT STRAP 1 HOLE STRAP' and precio = 0.1044;

-- ── Flex de 3/8" para los 77 whips de luminaria (detalle D5) ──────────────
--   CES cotizó ALUMINIO 3/8" x 100 ft a $0.904/ft; tu catálogo tiene el de
--   ACERO a $0.21. Son materiales distintos: el de CES es el más caro y el
--   que cotizaron para ESTA obra. 77 whips x 6 ft = 462 ft: $418 contra $97.
update catalogo_items set precio = 0.904 where item = '3/8"      FLEX. METAL CONDUIT' and precio = 0.21;

-- ── Bushing de 1" CON LUG (nota C de E-2.1: jumper de tierra #6) ──────────
--   CES: MORRIS 14572, $4.35 cada uno. Tu catálogo tiene $3.04.
--   OJO: este NO es el de los 44 stubs de datos — ese es el «1" ISOLATING
--   BUSHING» de plástico ($0.189, bloque 2). Este es el metálico con lug.
update catalogo_items set precio = 4.35 where item = '1"         GROUNDING BUSHING' and precio = 3.04;

-- ── Cajas ────────────────────────────────────────────────────────────────
--   Los dos cotizan la caja 4" cuadrada de 2-1/8" de fondo (210 en CES):
--   CED $1.5743 · CES $1.8261 (+16 %).
update catalogo_items set precio = 1.8261 where item = '4"X 4" X 1 1/2"   1900 COMBO BOX' and precio = 1.5743;
--   Y ESTA ES LA QUE USAN LAS 15 RECETAS DEL HOSPITAL (e18): la JB 1900 DEEP
--   estaba a $1.04, un precio viejo. Los dos suministros dicen que una caja
--   de esas vale $1.57–1.83. Se pone la más cara.
--   ⚠ Esto también sube el punto de tus otras recetas que usan esta caja
--     (las de E9). Es una corrección de mercado, no un capricho del hospital.
--     Si no la quieres, comenta esta línea.
update catalogo_items set precio = 1.8261 where item = 'JB 1900 DEEP BOX' and precio = 1.04;
-- Anillo de 2 gang: CED $1.1269 · CES $1.2495 (+11 %)
update catalogo_items set precio = 1.2495 where item = '2  GANG PLASTER RING 1/2"' and precio = 1.1269;
-- Tapa ciega 4S: CED $0.6297 · CES $0.804 (+28 %) — 111 en la obra
update catalogo_items set precio = 0.804  where item = '4"X4" BLANK COVER' and precio = 0.6297;

-- ── Conductor ────────────────────────────────────────────────────────────
-- #12 THHN: CED $254.54/MLF · CES $272.60 (+7 %). Son 17,4 MLF medidos.
update catalogo_items set precio = 272.60 where item = '# 12      THHN STRANDED CU.' and precio = 254.54;

-- ── Dispositivos hospital grade ──────────────────────────────────────────
--   Los GFCI de CES son P&S self-test y cuestan bastante más que los de CED.
-- GFCI HG TR ivory: CED $40.47 · CES $56.99 (+41 %) — 14 unidades
update catalogo_items set precio = 56.99 where item = '20A GFCI HOSPITAL GRADE TR/WR' and precio = 40.47;
-- GFCI HG rojo: CED $33.47 · CES $56.99 (+70 %) — 1 unidad
update catalogo_items set precio = 56.99 where item = '20A GFCI HOSPITAL GRADE RED'   and precio = 33.47;

-- ── El relé UL 924 (lee el BLOQUE 0) ─────────────────────────────────────
update catalogo_items set precio = 832.86 where item = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY' and precio = 135;

-- ── El time clock: CES cotizó el aparato CORRECTO, y más barato ───────────
--   El plano pide «Intermatic 4PST con override y batería». En e19 puse de
--   referencia un ET8415C astronómico a $600 porque no tenía cotización.
--   CES cotizó el INTERMATIC T7401B: 40 A, 4PST de verdad, $224.62. Otro
--   distribuidor (Capital Electric) lo tiene a $270.22 — se pone ese.
--   Se corrige el nombre: el modelo es el T7401B, no el ET8415C.
--   El T7401B es MECÁNICO con reserva de 3,5 h, no astronómico: si el
--   ingeniero pide astronómico de verdad, vuelve a los $600 y avísame.
update catalogo_items
   set item = 'TIME CLOCK 4PST 40A W/ OVERRIDE (INTERMATIC T7401B)', precio = 270.22
 where item = 'TIME CLOCK 4-CIRCUIT ASTRONOMIC W/ OVERRIDE (INTERMATIC ET8415C)' and precio = 600;

-- ── El downlight de la Type C: ninguno le puso precio ────────────────────
--   El plano pide LDN4 35/10 LO4 WR MVOLT GZ10 (4" redondo, WET, 11 W).
--   CES lo cotizó sin precio. Online: $108.50 y $172.00 → se pone $172.
--   Tu catálogo tenía «4" RECESSED CAN LIGHT» a $35: ese es un can
--   residencial, no un LDN4 comercial wet-rated. Son 3 unidades.
update catalogo_items set precio = 172.00 where item = '4" RECESSED CAN LIGHT' and precio = 35;

-- =========================================================================
-- BLOQUE 2 · LOS 10 QUE **NO** SE TOCAN: tu catálogo ya es el más caro
-- =========================================================================
--   Revisados uno por uno. Aquí CES cotizó MÁS BARATO que lo que ya tienes,
--   así que por la regla de estar cubierto se queda lo tuyo.
--
--   fila del catálogo                        tuyo/CED      CES      quién manda
--   ─────────────────────────────────────── ─────────── ───────── ────────────
--   1" EMT STRAP 1 HOLE STARP                  0.2087     0.2006   CED  (−4 %)
--   4-11/16 BOX                                6.7500     2.8534   TÚ   (los dos suministros la dan a $2.85–3.30; tu $6.75 es el más caro)
--   1  GANG PLASTER RING 1/2"                  0.8617     0.8391   CED  (−3 %)
--   PUTTY PAD SEAL                             6.4900     5.9500   CED  (−8 %) — 60 unidades
--   RED FIRE CAULK 10.3 OZ TUBE               14.6300     9.8800   CED  (−32 %) — 12 tubos
--   # 10      THHN STRANDED CU.              450.8300   416.9300   CED  (−8 %)
--   20A HOSPITAL GRADE TR RECEPTACLE          16.9000    11.7400   CED  (−31 %) — 63 unidades, $325 de colchón
--   20A HOSPITAL GRADE TR RECEPTACLE RED      16.9000    11.7400   CED  (−31 %) — 23 unidades
--   1" ISOLATING BUSHING (los 44 stubs)        0.1890        n/c   CED  (el de CES es otro producto: metálico con lug, arriba)
--   3/8"      FLEX. METAL ST. CONNECT.         0.5880     0.4514   TÚ   (−23 %)
--
--   Nada que correr en este bloque: es la constancia de que se revisó.

-- =========================================================================
-- BLOQUE 3 · UN ALTA Y UN CAMBIO DE RECETA
-- =========================================================================
-- EL SWITCH SENCILLO DEL HOSPITAL NO ES EL TUYO DE $2,97
--   CES cotizó P&S CSB20AC1W: 20 A, 120/277 V, back & side wire, spec grade
--   COMERCIAL, $11.80. Tu «SINGLE POLE SWITCH» de $2.97 es el residencial.
--   No se le cambia el precio —eso te rompería todos los bids de casa— sino
--   que se da de alta el comercial y la receta del hospital apunta a él.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE', 'WIRING DEVICES', 'E', 11.80, 0.20, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE');

-- y la receta SWITCH SENCILLO 20A — EMT (los 7 del hospital) usa ese:
update ensamble_items ei
   set item = '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE'
  from ensambles e
 where e.id = ei.ensamble_id
   and e.nombre = 'SWITCH SENCILLO 20A — EMT'
   and ei.item = 'SINGLE POLE SWITCH';

-- =========================================================================
-- BLOQUE 4 · LO QUE SIGUE SIN PRECIO DE NADIE (pídelo a Jose)
-- =========================================================================
--   · Day-Brite FSSEZ440L840-UNV-DIM — la luminaria REAL de la Fase I (12).
--     CES la cotizó SIN precio; CED sustituyó por una Lithonia CSSL48 a
--     $72.86, que es lo que hay en el catálogo. La Day-Brite casi seguro
--     cuesta más: no me lo invento, se pide.
--   · Lithonia LQM S W RG MVOLT M6 — el exit sign (7). CES lo cotizó sin
--     precio; e19 lo puso a $80 con el precio de Geller ($80.35). Se queda.
--   · STAK 2X2 5000LM / 2000LM y SCR 22 HC cleanroom — los 66 troffers.
--     NINGUNA de las dos cotizaciones los incluye. Tu catálogo tiene
--     «24"X24" LED TROFFER (RECESSED)» a $75, que para un STAK de 5000 lm
--     80 CRI con COL y ZT es bajo. El documento recomienda EXCLUIR las
--     luminarias del bid salvo que tomes la opción de suministrarlas: si la
--     tomas, pide los 66 y los 20 de cleanroom antes de poner un número.
--   · Placas y grabado — CES no cotizó ninguna placa. Se quedan las de CED:
--     1G ivory $0.27, 1G roja $0.27, grabado $10/gang (e16).
--   · Caja de TV — CES no la cotizó. Se queda el enclosure Hubbell de CED
--     ($211.43 + $69.72 de tapa), que es lo que decidiste el 16/09.
--   · Par 0-10V 18/2 CMP y placas de acero — solo referencia online (e19).
--   · Combo dimmer 0-10V/sensor (22) — nadie lo cotizó. e19 lo dejó a $120
--     (Sensor Switch WSX D $118.91). Pídelo: son 22 unidades.

-- =========================================================================
-- BLOQUE 5 · COMPROBAR (segundo pegado, aparte)
-- =========================================================================
-- select item, precio, unidad, horas_unidad from catalogo_items
--  where item in (
--    '1/2"     EMT CONDUIT','3/4"     EMT CONDUIT','1"         EMT CONDUIT',
--    '1/2"       EMT S.S. D/C CONNECTOR','3/4"       EMT S.S. D/C CONNECTOR','1"         EMT S.S. D/C CONNECTOR',
--    '1/2"       EMT S.S. D/C COUPLING','3/4"       EMT S.S. D/C COUPLING','1"           EMT S.S.D/C  COUPLING',
--    '1/2"      EMT STRAP 1 HOLE STRAP','3/4"      EMT STRAP 1 HOLE STRAP','1"          EMT STRAP 1 HOLE STARP',
--    '3/8"      FLEX. METAL CONDUIT','1"         GROUNDING BUSHING','1" ISOLATING BUSHING',
--    '4"X 4" X 1 1/2"   1900 COMBO BOX','JB 1900 DEEP BOX','2  GANG PLASTER RING 1/2"','4"X4" BLANK COVER',
--    '# 12      THHN STRANDED CU.','20A GFCI HOSPITAL GRADE TR/WR','20A GFCI HOSPITAL GRADE RED',
--    'UL 924 EMERGENCY LIGHTING CONTROL RELAY','4" RECESSED CAN LIGHT',
--    '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE','TIME CLOCK 4PST 40A W/ OVERRIDE (INTERMATIC T7401B)')
--  order by item;
--
-- -- y que la receta del switch quedó apuntando al comercial (1 fila):
-- select e.nombre, ei.item, c.precio
--   from ensamble_items ei join ensambles e on e.id = ei.ensamble_id
--   left join catalogo_items c on upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  where e.nombre = 'SWITCH SENCILLO 20A — EMT' and ei.item like '%SWITCH%';
