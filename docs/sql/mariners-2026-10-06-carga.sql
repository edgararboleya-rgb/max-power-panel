-- =====================================================================
-- MARINERS HOSPITAL CHILLERS REPLACEMENT · carga del estimado (06/10/2026)
-- Fuente: mariners-takeoff-completo.md (Edgar, 6-oct). Ya corrido en
-- Supabase el 06/10/2026: creó el estimado #47 (MXP MEP), 42 renglones y
-- 8 ítems de catálogo. Todo es ADITIVO y con guardas: se puede volver a
-- correr y no duplica nada.
-- Lo único que cambia el esquema es la restricción de `cable`, que no
-- aceptaba «emt» aunque la pantalla lo ofrece (ver e40-cable-emt.sql).
-- =====================================================================

-- 0. la pantalla ofrece «EMT / tubería» pero la base no lo aceptaba (no toca datos)
alter table estimados drop constraint if exists estimados_cable_check;
alter table estimados add constraint estimados_cable_check check (cable is null or cable in ('romex','mc','mixto','emt'));

-- A. ítems de catálogo que faltaban (nombres en inglés, como el catálogo)
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, orden, codigo)
select v.item, v.seccion, v.unidad, v.precio, v.horas, 1300 + v.n, v.codigo
from (values
 (1,'3-1/2" RIGID STRUT STRAP 304 SS','RACEWAY','E',5.79,0.07,'09-COND'),
 (2,'SOOW 2/4C 600V PORTABLE CORD','WIRING','LF',18.915,0.03,'08-ROUGH'),
 (3,'CORD GRIP 1-1/4"','RACEWAY','E',24.29,0.25,'09-COND'),
 (4,'ENGRAVED NAMEPLATE (1/4" LETTERS)','MISCELLANEOUS','E',30,0.25,'20-MISC'),
 (5,'RELOCATE DISCONNECT & CONTROL PANEL (per pump)','LABOR','EA',0,12,'20-MISC'),
 (6,'RELOCATE IRRIGATION CONTROLLER','LABOR','EA',0,8,'20-MISC'),
 (7,'ENERGIZED WORK WINDOW - 2 QUALIFIED ELECTRICIANS (per window)','LABOR','EA',0,8,'05-PANEL'),
 (8,'MEGGER TEST FEEDER (per feeder)','LABOR','EA',0,1.5,'05-PANEL')
) v(n,item,seccion,unidad,precio,horas,codigo)
where not exists (select 1 from catalogo_items c where upper(btrim(c.item)) = upper(btrim(v.item)));

-- B. el estimado (MXP MEP): escenario MEP, tax 7.5 % (Monroe), válido 13 días (la cuota CED vence 10/19)
insert into estimados (nombre, empresa, escenario, modo, estado, tipo, cliente, dueno, direccion, cable, soporte, pct_rack, tax_pct, valida_dias, factor,
  lineas_material, gastos_generales, no_incluye_extra, notas)
select 'Mariners Hospital Chillers Replacement', 'mep', 'MEP', 'planos', 'borrador', 'Commercial',
  'MEP Integrated Systems, LLC', 'Baptist Health South Florida – Mariners Hospital', '91500 Overseas Hwy, Tavernier, FL 33070',
  'emt', 'unistrut', 0, 0.075, 13, 1,
  -- Bloque 1: la cuota CED como UNA cotización; los allowances que no son material instalado
  '[{"desc":"CED Q1009435 rev 6→7 (Mike Jarot) — GEAR: 2 switches 600A 3P fused NEMA 4X 304 SS, breaker 600A ABB XT5 + kit retrofit SWBD-B (allowance $11,297), clips Clase R + fusibles RK1 500A/400A + reducers (allowance $1,800), breakers 40A y 30A EQH1A (budget), SPD Ditek D100, desconectivo 60A NF NEMA 4X, SOOW 130 ft, cord grips, 40 lugs 350. Vence 10/19/26. Flete aparte.","monto":38143.01,"tipo":"cot"},
    {"desc":"Hilti firestop system (FS-ONE MAX / FS-601 + mineral wool) — 8 penetrations, comprar directo a Hilti","monto":600,"tipo":"allow"},
    {"desc":"Relocation material — 3 flood pumps + irrigation controller (rígido 3/4\"–1\" ~100 ft, LBs, 4 cajas NEMA 3R, #8/#10 THWN ~400 ft, straps SS, etiquetas WP)","monto":1500,"tipo":"allow"},
    {"desc":"SS hardware & anchors (racks de los switches y soportes)","monto":300,"tipo":"allow"}]'::jsonb,
  -- Otros gastos: flete $3,000 + x-ray $800 (otros), lift 2 semanas, PPE arc flash (equipo), disposición
  '{"lift_dias":10,"lift_semana":750,"equipo":1000,"dispo":500,"otros":3800}'::jsonb,
  E'Temporary chiller power cable (SO 3#350 + 1#1 with cam-lok) and its terminations: by the rental company.\nChillers, pumps and their internal wiring; HVAC controls and controls wiring (controls contractor).\nFire alarm devices and wiring (FA vendor). Max Power provides conduit and back boxes only.\nElectrical permit (by GC).\nReplacement of the existing ACC-1A feeder (Add Alternate 1) and repairs to the existing underground conduit.\nRedesign or additional work if ESI or the Owner does not accept the available replacement breaker.\nStructural work, concrete, pads, louvers, cutting and patching beyond the electrical penetrations.\nMechanical demolition.',
  E'CARGADO 06/10/2026 desde mariners-takeoff-completo.md (precio para el 06-oct; bid de MEP al GC el 07-oct).\n\nCOMO ENTRÓ EL MATERIAL\n• Bloque 1 (gear CED): una línea de cotización $38,143.01 + tax. Los equipos van además como renglones a $0 para que pongan SUS HORAS.\n• Bloque 2 (commodities): cantidades CALCULADAS (sin desperdicio) a precio unitario CED; la merma de la app (10 % cable, 5 % tubo) pone el desperdicio. Cable 350: 2,220 ft (A 660 + B 720 + E2 840); #1 G 740 ft; EMT 3-1/2": 340 ft (A 180, B 100, E2 60); rígido 3-1/2": 240 ft (B 100, E2 140); LT 3-1/2": 32 ft → 40.\n• Bloque 3: LBs a ~$350 (CED no cotizó), caja 36x36 temporal ~$600, multi-tap 350 ~$200, nameplates $30, Hilti/reubicaciones/herrajes como allowance. Los misceláneos ($800) NO van aparte: los cubre el 3 % de la app.\n• Por hoja (el estimador no guarda la hoja): E-1 = Tramo A + Tramo B + switches + caja temporal; E-2 = Tramo E2 + LT + FA + reubicaciones; E-5 = SPD + bomba temporal; E-4 = breaker 600A.\n\nOTROS GASTOS (sección 5): flete CED $3,000 + x-ray losa $800 (en «Otros»), lift 2 semanas $1,500, PPE arc flash $1,000 (Equipo), disposición $500. PENDIENTE EDGAR: viajes Ocala–Tavernier (mín. 6) y hospedaje de la cuadrilla en las 2 ventanas nocturnas; overtime.\n\nHORAS DE REFERENCIA (estimado independiente, por tarea, para calibrar contra la app): 1 Temporary Power (connect & remove) 90 · 2 Demolition ACC-1 & ACC-2 32 · 3 Relocations 50 · 4 New Feeders + Disconnects 160 · 5 Fire Alarm, 120V Controls, Surge 25 · 6 Testing & Closeout 30 · TOTAL 387 h.\n\nALTERNATES (fuera del precio base):\n• Alt 1 ADD (budget): reemplazar alimentador existente ACC-1A (2 corridas 3-1/2" EMT ~90 ft c/u, 660 ft 350, 220 ft #1, 2 pull boxes, halar cable viejo) ≈ $12,500 material + ~45 h. Solo si el existente no pasa mandrel/megger.\n• Alt 2 DEDUCT: si Trane trae protección de fábrica, quitar los 2 switches 600A (−$18,875 −$1,800 fusibles) y poner 2 cajas 36x36x12 NEMA 1 (+$900), −12 h. Pendiente Trane (Wagner Braga).\n• Alt 3 DEDUCT: GE Spectra SGLA36AT0600 nuevo de surplus aceptado por ESI: −$11,297 + ~$3,960 + flete ≈ −$7,000.\n\nPENDIENTES ANTES DE CERRAR: conteo final E2-01 y split interior/exterior · CED rev 7 · aceptación ABB XT5 + kit (ESI/dueño) · placa EQH1A (breakers 40A/30A) · protección de fábrica Trane · cam-lok o pelado (caja de aterrizaje) · fusibles del switch #2 durante el temporal (~$700) · flete firme y recepción en el hospital.'
where not exists (select 1 from estimados where nombre = 'Mariners Hospital Chillers Replacement' and empresa = 'mep');

-- C. los renglones: cantidad calculada, precio CED donde lo hay (null = el del catálogo), horas del catálogo.
--    (cid = id del catálogo; nom = nombre exacto cuando es nuevo o no se sabía el id)
insert into estimado_items (estimado_id, item, unidad, cantidad, precio, horas, codigo, origen, orden)
select e.id, c.item, c.unidad, v.qty, coalesce(v.precio, c.precio), c.horas_unidad, v.codigo, 'takeoff', v.orden
from (values
 -- alimentadores (06-FEED): 350 THW en MLF, #1 en MLF, tubo 3-1/2" EMT y rígido, LT, fittings, LBs, bushings, pull boxes, strut
 (551,null,2.22,13200,'06-FEED',1),(544,null,0.74,3410,'06-FEED',2),(250,null,340,9.21,'06-FEED',3),(138,null,240,17.33,'06-FEED',4),
 (393,null,40,15,'06-FEED',5),(403,null,8,106.75,'06-FEED',6),(330,null,24,18.29,'06-FEED',7),(340,null,40,12.67,'06-FEED',8),
 (260,null,14,56.38,'06-FEED',9),(151,null,12,65.39,'06-FEED',10),(173,null,12,12.05,'06-FEED',11),(228,null,6,350,'06-FEED',12),
 (162,null,20,18.14,'06-FEED',13),(435,null,3,264.52,'06-FEED',14),(467,null,150,5.70,'06-FEED',15),
 (null,'3-1/2" RIGID STRUT STRAP 304 SS',70,null,'06-FEED',16),
 (570,null,40,0,'06-FEED',17),                                   -- lugs 350: en la cuota CED → $0, solo horas
 (575,null,4,200,'02-TEMP',18),(436,null,1,600,'02-TEMP',19),   -- caja de aterrizaje del temporal y sus multi-taps
 (538,null,0.1,null,'08-ROUGH',20),(243,null,60,null,'08-ROUGH',21),(482,null,2,null,'13-LV',22),(484,null,2,null,'13-LV',23),
 (null,'ENGRAVED NAMEPLATE (1/4" LETTERS)',10,null,'20-MISC',24),
 -- gear: en la cuota CED → $0, solo horas
 (810,null,1,0,'05-PANEL',25),(640,null,2,0,'05-PANEL',26),(1174,null,1,0,'05-PANEL',27),(1154,null,1,0,'05-PANEL',28),(1152,null,1,0,'05-PANEL',29),
 (636,null,1,0,'02-TEMP',30),
 (null,'SOOW 2/4C 600V PORTABLE CORD',130,0,'02-TEMP',31),(null,'CORD GRIP 1-1/4"',2,0,'02-TEMP',32),
 -- demolición y desmontaje del Tramo B
 (1176,null,2,null,'01-DEMO',33),(1178,null,2,null,'01-DEMO',34),
 (null,'DEMO - Conduit Run (per LF)',200,null,'02-TEMP',35),(null,'DEMO - Wire Removal (per LF)',960,null,'02-TEMP',36),
 -- pruebas, cierre, reubicaciones, ventanas energizadas
 (809,null,1,null,'05-PANEL',37),(null,'AS-BUILT, PRUEBAS Y CIERRE (por proyecto)',1,null,'20-MISC',38),
 (null,'RELOCATE DISCONNECT & CONTROL PANEL (per pump)',3,null,'20-MISC',39),(null,'RELOCATE IRRIGATION CONTROLLER',1,null,'20-MISC',40),
 (null,'ENERGIZED WORK WINDOW - 2 QUALIFIED ELECTRICIANS (per window)',2,null,'05-PANEL',41),(null,'MEGGER TEST FEEDER (per feeder)',5,null,'05-PANEL',42)
) v(cid, nom, qty, precio, codigo, orden)
join catalogo_items c on (v.cid is not null and c.id = v.cid) or (v.cid is null and upper(btrim(c.item)) = upper(btrim(v.nom)))
join estimados e on e.nombre = 'Mariners Hospital Chillers Replacement' and e.empresa = 'mep'
where not exists (select 1 from estimado_items i where i.estimado_id = e.id);

-- Comprobación (una sola fila). El 06/10 dio: est_id 47 · 42 renglones · $49,589.46 · 422.2 h · 8 ítems nuevos
select e.id est_id, count(i.id) renglones, round(sum(i.cantidad*i.precio),2) material_renglones, round(sum(i.cantidad*i.horas),1) horas,
       (select count(*) from catalogo_items where orden between 1301 and 1308) cat_nuevos
from estimados e left join estimado_items i on i.estimado_id = e.id
where e.nombre = 'Mariners Hospital Chillers Replacement' and e.empresa = 'mep' group by e.id;
