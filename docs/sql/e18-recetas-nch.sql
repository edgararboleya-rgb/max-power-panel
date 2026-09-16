-- =========================================================================
-- E18 · Las recetas del HOSPITAL — Nicklaus Children's, Radiology Ultrasound
-- Supabase → SQL Editor. Un solo pegado. Idempotente: no duplica nada.
--
-- De dónde sale: del NCH-Radiology-Ultrasound-DEVICE-TAKEOFF.md que armó Edgar
-- (16/09). De las 80 recetas de E9 ese trabajo usaba 12 y le faltaban 13; aquí
-- van esas 13 más dos que salieron del mismo documento (el stub de datos con
-- sus 10 ft reales y el botón de la puerta). 15 recetas, 228 puntos.
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
-- 1) ALTAS al catálogo (10). Las que ya tengas no se tocan (ni el precio).
--    Dos son de REFERENCIA (no cotizadas): pídeselas a CED y corrige el precio.
-- -------------------------------------------------------------------------
-- 20A HOSPITAL GRADE TR RECEPTACLE
--   CED Q1009347 ln 32: 20A 125V HG RCPT, 63 a $16,90. Ya va en e16; aqui se repite por si e18 corre antes.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '20A HOSPITAL GRADE TR RECEPTACLE', 'WIRING DEVICES', 'E', 16.9, 0.4, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '20A HOSPITAL GRADE TR RECEPTACLE');

-- 20A GFCI HOSPITAL GRADE TR/WR
--   CED ln 33: 20A 125VAC COMM HG TRWR GFR IVORY, 14 a $40,47. Ya va en e16.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '20A GFCI HOSPITAL GRADE TR/WR', 'WIRING DEVICES', 'E', 40.47, 0.5, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '20A GFCI HOSPITAL GRADE TR/WR');

-- 20A HOSPITAL GRADE TR RECEPTACLE RED
--   CED ln 34: 20A 125V HG RCPT, 23 a $16,90 — los 23 de rama critica (rojos). Mismo precio que el ivory.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '20A HOSPITAL GRADE TR RECEPTACLE RED', 'WIRING DEVICES', 'E', 16.9, 0.4, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '20A HOSPITAL GRADE TR RECEPTACLE RED');

-- 20A GFCI HOSPITAL GRADE RED
--   CED ln 35: 20A 125VAC COMM HG GFR RED, 1 a $33,47.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '20A GFCI HOSPITAL GRADE RED', 'WIRING DEVICES', 'E', 33.47, 0.5, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '20A GFCI HOSPITAL GRADE RED');

-- 1G DUPLEX WALLPLATE RED
--   CED ln 37, 25 a $0,27. Ya va en e16.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '1G DUPLEX WALLPLATE RED', 'WIRING DEVICES', 'E', 0.27, 0.08, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '1G DUPLEX WALLPLATE RED');

-- PLATE ENGRAVING (per gang)
--   CED ln 38: PER GANG ON PLASTIC, $10,00. Detalle D4 (E-5.1): panel y ckt grabados en cada placa. Ya va en e16.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'PLATE ENGRAVING (per gang)', 'WIRING DEVICES', 'E', 10.0, 0, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'PLATE ENGRAVING (PER GANG)');

-- NEMA 1 ENCLOSURE 12x12x4
--   CED ln 23: Hubbell NSAV124M, 7 a $211,43 — lo que CED cotizo para las 7 cajas multigang de TV (spec TV3WTVSSW). Ya va en e16.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'NEMA 1 ENCLOSURE 12x12x4', 'SWITCHGEAR', 'E', 211.43, 1.5, '05-PANEL'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'NEMA 1 ENCLOSURE 12X12X4');

-- NEMA 1 ENCLOSURE COVER 12x12
--   CED ln 24: Hubbell NSAV12C, 7 a $69,72. Ya va en e16.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'NEMA 1 ENCLOSURE COVER 12x12', 'SWITCHGEAR', 'E', 69.72, 0.3, '05-PANEL'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'NEMA 1 ENCLOSURE COVER 12X12');

-- 0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH
--   REFERENCIA, no cotizado: combo 0-10V + sensor de pared (Lutron MS-Z101 / Sensor Switch WSX-D). Pedir a CED. Las 0,6 h: entre el dimmer (0,3) y el PIR de Stuart (1,26).
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', 'WIRING DEVICES', 'E', 145.0, 0.6, '10-DEV'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH');

-- UL 924 EMERGENCY LIGHTING CONTROL RELAY
--   REFERENCIA, no cotizado: rele UL 924 (Wattstopper ELCU-200 / Bodine GTD). Pedir a CED. Tu LIGHTING RELAY es $85 / 0,5 h; este lleva ademas la deteccion del normal.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'UL 924 EMERGENCY LIGHTING CONTROL RELAY', 'LIGHTING FIXTURES', 'E', 135.0, 0.75, '11-LIGHT'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY');

-- -------------------------------------------------------------------------
-- 2) Las recetas
-- -------------------------------------------------------------------------
insert into ensambles (nombre, modo, pies_editable, orden, descripcion)
select v.nombre, v.modo, v.pies, v.orden, v.descripcion
  from (values
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', 'comercial', true, 200, 'Punto de receptáculo hospital grade tamper resistant en EMT, con su placa grabada (panel + ckt) y tierra aislada aparte (517.13).'),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', 'comercial', true, 201, 'GFCI hospital grade TR en EMT (baños y a 6 ft de fregadero, nota D), placa grabada, tierra aislada aparte.'),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', 'comercial', true, 202, 'Receptáculo hospital grade TR ROJO de la rama crítica (panel CL2), placa roja grabada, en su propio sistema de EMT (517.31).'),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', 'comercial', true, 203, 'GFCI hospital grade ROJO de la rama crítica, placa roja grabada.'),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', 'comercial', true, 204, 'Caja multigang para monitor de TV: duplex HG + lado de bajo voltaje con divisor listado y jumper de tierra #6 (nota C de E-2.1).'),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', 'comercial', true, 205, 'Switch de pared combinado: dimmer 0-10V + sensor de ocupación, placa grabada. El par 0-10V al driver NO está en el catálogo (pendiente de alta).'),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', 'comercial', true, 206, 'Sensor de ocupación de pared (PIR) en EMT, con placa decora grabada (el documento lo cuenta entre los 37 gangs de switch).'),
    ('SWITCH SENCILLO 20A — EMT', 'comercial', true, 207, 'Switch sencillo 20A en EMT, placa grabada (panel + ckt).'),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', 'comercial', true, 208, 'Relé UL 924 en caja 4S sobre el techo con tapa ciega: deja la luz de emergencia encendida cuando se va el normal, por delante de cualquier control.'),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', 'comercial', true, 209, 'Caja 4S + anillo 1G + stub de 1" EMT 6" sobre el techo accesible, con bushing aislante y pull string. Sin cable ni jack: eso lo pone el IT del hospital. Marcar «con su tubo».'),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', 'comercial', true, 210, 'Caja 4S sobre la puerta + stub de 1" EMT con bushing y pull string. El lector, el cable y el cierre eléctrico los pone el vendor de seguridad de NCH. Marcar «con su tubo».'),
    ('WAP EN TECHO — SOLO ROUGH', 'comercial', false, 211, 'Caja 4S en el techo con colgador de T-bar y tapa ciega. El WAP y el CAT6 los pone IT (6 ft de holgura, key note 4).'),
    ('CÁMARA EN TECHO — SOLO ROUGH', 'comercial', false, 212, 'Caja 4S en el techo con colgador y tapa ciega. La cámara y su cable, por el vendor de seguridad (key note 2).'),
    ('SPEAKER DE VOCEO EN TECHO — SOLO ROUGH', 'comercial', false, 213, 'Caja 4S en el techo con colgador y tapa ciega para el speaker de voceo (NO fire alarm). Speaker y cable por el vendor (key note 3).'),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', 'comercial', true, 214, 'Caja 4S + anillo 1G + stub de 1/2" EMT con bushing y pull string para el botón de recepción. El botón y el cable, por el vendor de seguridad. Marcar «con su tubo».')
  ) as v(nombre, modo, pies, orden, descripcion)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

-- -------------------------------------------------------------------------
-- 3) Los componentes
-- -------------------------------------------------------------------------
insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    -- RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT · 56 en Nicklaus · punto 1.07 h / $31.30 · con tubo y cable 2.27 h / $60.99
    --   El punto de fuerza del hospital. OJO al contar en Planos: el documento dice 63 HG ivory, pero 7 de esos van DENTRO de las 7 cajas multigang de TV y la receta de TV ya trae su receptáculo — así que en Planos se cuentan 56 aquí y 7 en la de TV, o el receptáculo sale dos veces. HG por 517.18(B), TR por 406.12, placa grabada por el detalle D4, y la tierra verde #12 aparte porque 517.13 pide raceway metálico MÁS conductor aislado.
    --   Vara: Vara de Edgar: dispositivo 0,3-0,4 + caja 0,25 + tapa 0,08 = 0,63-0,73 h el punto pelado. Aquí el punto sin lineal da ~1,05 h con caja 1900 deep, anillo, 2 conectores, 2,5 acoples y 3 grapas. Con 25 ft de tubo e hilo, ~2,2 h: en la banda del RECEPTÁCULO GFCI 20A — EMT (2,39).
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '20A HOSPITAL GRADE TR RECEPTACLE', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT', 'YELLOW WIRENUTS', 3),

    -- RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT · 14 en Nicklaus · punto 1.17 h / $54.87 · con tubo y cable 2.37 h / $84.56
    --   14 en Nicklaus: 5 baños + los de los cuartos de ultrasonido junto al fregadero. La nota D de E-2.1 obliga GFCI a 6 ft de un sink aunque el plano no lo dibuje.
    --   Vara: Igual que el HG sencillo más 0,1 h del GFCI (0,5 contra 0,4 en el catálogo). Stuart: 15 GFCI a 0,30 h la pieza.
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '20A GFCI HOSPITAL GRADE TR/WR', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT', 'YELLOW WIRENUTS', 3),

    -- RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT · 23 en Nicklaus · punto 1.07 h / $31.02 · con tubo y cable 2.27 h / $60.71
    --   23 en Nicklaus, en los 6 cuartos de ultrasonido y el control room. Rojo por el detalle D4 (life safety, critical y equipment van en rojo). Va en un sistema de EMT SEPARADO del normal: 517.31(C)(1) prohíbe compartir raceway, caja o gabinete.
    --   Vara: Las mismas horas que el ivory: el dispositivo rojo cuesta igual ($16,90 en CED) y se instala igual. Lo que sube es el tubo aparte, y eso lo mide Edgar.
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '20A HOSPITAL GRADE TR RECEPTACLE RED', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1G DUPLEX WALLPLATE RED', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', 'YELLOW WIRENUTS', 3),

    -- RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT · 1 en Nicklaus · punto 1.17 h / $47.59 · con tubo y cable 2.37 h / $77.28
    --   Uno solo en Nicklaus (Ultrasound 8-1804). Existe para que el conteo no lo mande como pieza pelada.
    --   Vara: Igual que el GFCI ivory.
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '20A GFCI HOSPITAL GRADE RED', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1G DUPLEX WALLPLATE RED', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', 'YELLOW WIRENUTS', 3),

    -- SALIDA DE TV MULTIGANG CON DIVISOR — EMT · 7 en Nicklaus · punto 2.50 h / $301.34 · con tubo y cable 3.72 h / $333.37
    --   7 en Nicklaus, una por cuarto de ultrasonido y una en el control room. La spec pide TV3WTVSSW; CED cotizó un Hubbell NSAV124M 12x12x4 con su tapa como sustituto — confirmar con el ingeniero antes de comprar. El receptáculo va dentro del enclosure, sin placa: el documento no lo cuenta entre los 131 gangs grabados.
    --   Vara: 1,5 h la caja grande + 0,3 la tapa + 0,4 el receptáculo + fittings ≈ 2,4 h el punto sin lineal. Es la salida más cara del trabajo después del panel: $211 + $70 solo la caja.
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', 'NEMA 1 ENCLOSURE 12x12x4', 1),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', 'NEMA 1 ENCLOSURE COVER 12x12', 1),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '20A HOSPITAL GRADE TR RECEPTACLE', 1),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', 'G 4000  WIREMOLD DIVIDER', 1),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '# 6       THHN STRANDED CU.', 0.002),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '1/2"     EMT CONDUIT', 25),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', '#12     GROUND PIGTAIL', 1),
    ('SALIDA DE TV MULTIGANG CON DIVISOR — EMT', 'YELLOW WIRENUTS', 3),

    -- DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT · 22 en Nicklaus · punto 1.25 h / $159.20 · con tubo y cable 2.33 h / $187.37
    --   22 en Nicklaus: el control de luz de casi todos los cuartos. Toda la luminaria es 0-10V (E-2.2) y el switch tiene que ser compatible con el driver (nota típica).
    --   Vara: 0,6 h el dispositivo (entre el dimmer 0,3 y el PIR de Stuart 1,26) + caja + anillo + fittings ≈ 1,2 h sin lineal. 4 hilos #12 (fase, neutro, retorno, tierra) a 20 ft = 0,08 MLF. El par 0-10V morado/gris no existe en tu catálogo: hay que darlo de alta.
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', 'JB 1900 DEEP BOX', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"     EMT CONDUIT', 20),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '# 12      THHN STRANDED CU.', 0.08),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', '#12     GROUND PIGTAIL', 1),
    ('DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', 'YELLOW WIRENUTS', 4),

    -- SENSOR DE OCUPACIÓN DE PARED — EMT · 9 en Nicklaus · punto 1.91 h / $80.36 · con tubo y cable 2.99 h / $108.53
    --   9 en Nicklaus. Existía solo en MC; el hospital va todo en EMT (517.31(C)(3) no admite MC para la rama esencial).
    --   Vara: Vara directa de Stuart: 6 PASSIVE INFRA. OCUP. SENSOR a 1,26 h y $66,16 = el PIR OCCUPANCY SENSOR del catálogo. Misma receta que la de MC, con el tubo en vez del cable.
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', 'PIR OCCUPANCY SENSOR', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', 'JB 1900 DEEP BOX', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"     EMT CONDUIT', 20),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '# 12      THHN STRANDED CU.', 0.08),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', '#12     GROUND PIGTAIL', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — EMT', 'YELLOW WIRENUTS', 4),

    -- SWITCH SENCILLO 20A — EMT · 7 en Nicklaus · punto 0.85 h / $16.91 · con tubo y cable 1.81 h / $40.66
    --   7 en Nicklaus (3 under-cabinet, 3 recepción, 1 vestíbulo). Había tres y cuatro vías en EMT pero NO el sencillo — el más común de todos.
    --   Vara: SINGLE POLE SWITCH = 0,20 h en tu catálogo. El punto sin lineal ≈ 0,8 h; con 20 ft de tubo, 1,8 h: igual que el SWITCH SENCILLO — ROMEX trasladado a tubo, y 0,2 h por debajo del TRES VÍAS — EMT (1,99).
    ('SWITCH SENCILLO 20A — EMT', 'SINGLE POLE SWITCH', 1),
    ('SWITCH SENCILLO 20A — EMT', 'JB 1900 DEEP BOX', 1),
    ('SWITCH SENCILLO 20A — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SWITCH SENCILLO 20A — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH SENCILLO 20A — EMT', 'PLATE ENGRAVING (per gang)', 1),
    ('SWITCH SENCILLO 20A — EMT', '1/2"     EMT CONDUIT', 20),
    ('SWITCH SENCILLO 20A — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SWITCH SENCILLO 20A — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('SWITCH SENCILLO 20A — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SWITCH SENCILLO 20A — EMT', '# 12      THHN STRANDED CU.', 0.06),
    ('SWITCH SENCILLO 20A — EMT', '#12     GROUND PIGTAIL', 1),
    ('SWITCH SENCILLO 20A — EMT', 'YELLOW WIRENUTS', 3),

    -- RELÉ DE EMERGENCIA UL 924 — EMT · 21 en Nicklaus · punto 1.39 h / $140.34 · con tubo y cable 1.99 h / $156.64
    --   21 en Nicklaus: 'toda luminaria de emergencia llevará relé de emergencia (typ)'. Estas 21 cajas NO están en las 104 de iluminación del documento: se suman.
    --   Vara: 0,75 h el relé (tu LIGHTING RELAY es 0,5; este además sensa el circuito normal) + caja + colgador + tapa + 3 conectores ≈ 1,3 h sin lineal. 5 hilos a 10 ft (normal sensado, emergencia, neutro, salida, tierra) = 0,05 MLF.
    ('RELÉ DE EMERGENCIA UL 924 — EMT', 'UL 924 EMERGENCY LIGHTING CONTROL RELAY', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', 'JB 1900 DEEP BOX', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', 'T-BAR BOX HANGER', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '4"X4" BLANK COVER', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '1/2"     EMT CONDUIT', 10),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 3),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '# 12      THHN STRANDED CU.', 0.05),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', '#12     GROUND PIGTAIL', 1),
    ('RELÉ DE EMERGENCIA UL 924 — EMT', 'YELLOW WIRENUTS', 6),

    -- SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT) · 39 en Nicklaus · punto 0.68 h / $3.16 · con tubo y cable 1.13 h / $16.91
    --   30 data + 9 data/teléfono en Nicklaus. La nota D de E-2.3 pide el stub de 1" con pull string; la E dice que TODO el cableado de voz y datos lo instala IT. El CONDUIT VACÍO 1" de E9 trae 25 ft y anillo de 2G: aquí son ~10 ft (pared + 6" sobre el techo) y anillo de 1G, como dice el documento. Con 25 ft serían 660 ft de 1" de más.
    --   Vara: EMT 1" a 0,045 h/ft x 10 = 0,45 h + caja 0,25 + anillo 0,05 + bushing 0,15 + fittings ≈ 1,1 h. Es el punto ENTERO: el tubo es el alcance, por eso esta receta va con la bandera «con su tubo y su cable».
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', 'JB 1900 DEEP BOX', 1),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1  GANG PLASTER RING 1/2"', 1),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1"         EMT CONDUIT', 10),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1"           EMT S.S.D/C CONNECTOR', 1),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1"           EMT S.S.D/C  COUPLING', 1),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1"          EMT STRAP 1 HOLE STARP', 2),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', '1" ISOLATING BUSHING', 1),
    ('SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)', 'PULL STRING', 0.012),

    -- LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT) · 5 en Nicklaus · punto 0.70 h / $3.08 · con tubo y cable 1.15 h / $16.83
    --   5 en Nicklaus (key note 5 de E-2.3). El LECTOR DE TARJETA — EMT de E9 trae el lector, el strike, el magnético y 150 ft de cable: aquí nada de eso es nuestro.
    --   Vara: Igual que el stub de datos con tapa ciega en vez de anillo: ≈ 1,1 h.
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', 'JB 1900 DEEP BOX', 1),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '4"X4" BLANK COVER', 1),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '1"         EMT CONDUIT', 10),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '1"           EMT S.S.D/C CONNECTOR', 1),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '1"           EMT S.S.D/C  COUPLING', 1),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '1"          EMT STRAP 1 HOLE STARP', 2),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', '1" ISOLATING BUSHING', 1),
    ('LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)', 'PULL STRING', 0.012),

    -- WAP EN TECHO — SOLO ROUGH · 7 en Nicklaus · punto 0.37 h / $2.37 · con tubo y cable 0.37 h / $2.37
    --   7 en Nicklaus. La receta de E9 trae el aparato ($285) y el CAT6: aquí solo la caja.
    --   Vara: Caja 0,25 + colgador 0,05 + tapa 0,07 = 0,37 h. Es lo que cuesta dejar una caja ciega en el techo.
    ('WAP EN TECHO — SOLO ROUGH', 'JB 1900 DEEP BOX', 1),
    ('WAP EN TECHO — SOLO ROUGH', 'T-BAR BOX HANGER', 1),
    ('WAP EN TECHO — SOLO ROUGH', '4"X4" BLANK COVER', 1),

    -- CÁMARA EN TECHO — SOLO ROUGH · 3 en Nicklaus · punto 0.37 h / $2.37 · con tubo y cable 0.37 h / $2.37
    --   3 en Nicklaus. Misma caja que el WAP; nombre aparte para que el conteo de Planos las lleve por separado.
    --   Vara: 0,37 h, igual que el WAP.
    ('CÁMARA EN TECHO — SOLO ROUGH', 'JB 1900 DEEP BOX', 1),
    ('CÁMARA EN TECHO — SOLO ROUGH', 'T-BAR BOX HANGER', 1),
    ('CÁMARA EN TECHO — SOLO ROUGH', '4"X4" BLANK COVER', 1),

    -- SPEAKER DE VOCEO EN TECHO — SOLO ROUGH · 6 en Nicklaus · punto 0.37 h / $2.37 · con tubo y cable 0.37 h / $2.37
    --   6 en Nicklaus. La BOCINA F/A (SPEAKER) de E9 es de fire alarm con su 18/2 shielded: no es esto.
    --   Vara: 0,37 h, igual que el WAP.
    ('SPEAKER DE VOCEO EN TECHO — SOLO ROUGH', 'JB 1900 DEEP BOX', 1),
    ('SPEAKER DE VOCEO EN TECHO — SOLO ROUGH', 'T-BAR BOX HANGER', 1),
    ('SPEAKER DE VOCEO EN TECHO — SOLO ROUGH', '4"X4" BLANK COVER', 1),

    -- BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT) · 1 en Nicklaus · punto 0.59 h / $2.36 · con tubo y cable 0.89 h / $7.61
    --   Uno en Nicklaus (recepción). Existe para que el conteo no lo mande pelado.
    --   Vara: Caja 0,25 + anillo 0,05 + 10 ft de 1/2" 0,30 + fittings ≈ 0,8 h.
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', 'JB 1900 DEEP BOX', 1),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1  GANG PLASTER RING 1/2"', 1),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1/2"     EMT CONDUIT', 10),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1/2"       EMT S.S. D/C CONNECTOR', 1),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', '1/2" ISOLATING BUSHING', 1),
    ('BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', 'PULL STRING', 0.012)
  ) as v(receta, item, cantidad)
  join ensambles e on e.nombre = v.receta
 where not exists (select 1 from ensamble_items x where x.ensamble_id = e.id and x.item = v.item);

-- -------------------------------------------------------------------------
-- 4) COMPROBAR (segundo pegado, aparte). Tiene que dar 15 filas, huerfanos = 0,
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
--  where e.orden between 200 and 214
--  group by e.nombre, e.orden order by e.orden;
