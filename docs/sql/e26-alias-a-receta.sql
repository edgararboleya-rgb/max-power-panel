-- ============================================================================
-- E26 · LA HERRAMIENTA DE BLUEBEAM APUNTA A LA RECETA (18/09/2026)
-- ============================================================================
-- El arreglo de los $100.000 de Nicklaus. Los 95 receptáculos llegaron al
-- estimador como UN ítem residencial pelado —sin caja, sin anillo, sin placa,
-- sin conectores, sin wirenuts— porque la tabla de alias solo sabía apuntar a
-- `catalogo_items`. Y marcar cada categoría a mano como «punto completo» no es
-- práctico (Edgar: «no lo veo práctico»).
--
-- Ahora el alias puede apuntar a una RECETA (Planos v34.E la mira primero).
-- Se dice UNA vez por herramienta de Bluebeam y vale para todos los planos.
-- La categoría que Edgar marque a mano en Planos sigue mandando sobre esto.
--
-- Tres bloques:
--   1. Las dos columnas.
--   2. Dos recetas genéricas que NO existían (el duplex 20A comercial en EMT —
--      el dispositivo más común de una obra comercial no tenía receta— y el
--      sensor de techo en EMT; solo estaba en MC).
--   3. Los alias: las herramientas de Bluebeam de Edgar → receta genérica
--      comercial en EMT; y los nombres de categoría del hospital → receta HG.
--      receta_full = true solo en los stubs (el tubo ES el punto).
-- Idempotente: lo que exista no se toca.
-- ============================================================================

-- ── 1. Las columnas ─────────────────────────────────────────────────────────
alter table alias_takeoff add column if not exists receta text;
alter table alias_takeoff add column if not exists receta_full boolean not null default false;
comment on column alias_takeoff.receta is
  'E26 · Si esta herramienta de Bluebeam es un PUNTO COMPLETO, el nombre exacto de la receta (ensambles.nombre). Planos la manda como receta x cantidad en vez de como item suelto. NULL = item de siempre.';
comment on column alias_takeoff.receta_full is
  'E26 · true = la receta va CON su tubo y su cable (stubs: el tubo es el punto). false = sin lineal, que Edgar lo mide en el plano.';

-- ── 2. Las dos recetas que faltaban ─────────────────────────────────────────
insert into ensambles (nombre, modo, pies_editable, orden, descripcion)
select v.nombre, v.modo, v.pies, v.orden, v.descripcion
  from (values
    ('RECEPTÁCULO 20A DUPLEX — EMT', 'comercial', true, 219, 'El punto de receptáculo 20A duplex comercial (spec grade, no HG) en EMT: caja 1900 deep, anillo 1G, 25 ft de 1/2" EMT con sus 2 conectores y acoples, 75 ft de #12, pigtail, wirenuts y placa. Es el dispositivo más común de una obra comercial y no tenía receta.'),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'comercial', true, 220, 'Sensor de ocupación de techo con su power pack, en EMT: caja 1900 con anillo de techo y colgador de T-bar, 20 ft de 1/2" EMT, 60 ft de #12, wirenuts y pigtail. Gemela de la de MC.')
  ) as v(nombre, modo, pies, orden, descripcion)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    ('RECEPTÁCULO 20A DUPLEX — EMT', '20A DUPLEX RECEPTACLE', 1),
    ('RECEPTÁCULO 20A DUPLEX — EMT', 'JB 1900 DEEP BOX', 1),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO 20A DUPLEX — EMT', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO 20A DUPLEX — EMT', '1G PLASTIC COVER RECEPTACLE', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'CEILING OCCUPANCY SENSOR', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'JB 1900 BOX', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'CEILING RING  1/2"', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'REMOTE POWER PACK', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'T-BAR BOX HANGER', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '1/2"     EMT CONDUIT', 20),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '# 12      THHN STRANDED CU.', 0.06),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', 'YELLOW WIRENUTS', 4),
    ('SENSOR DE OCUPACIÓN DE TECHO — EMT', '#12     GROUND PIGTAIL', 1)
  ) as v(receta, item, cantidad)
  join ensambles e on e.nombre = v.receta
 where not exists (select 1 from ensamble_items x where x.ensamble_id = e.id and x.item = v.item);

-- ── 3. Los alias → receta ───────────────────────────────────────────────────
-- Una tabla temporal con lo que queremos, y de ahí UPDATE a los que existen e
-- INSERT a los que no. `item` queda como respaldo por si la receta no existe.
drop table if exists _al;
create temp table _al (alias text, item text, receta text, con_tubo boolean);   -- «full» es palabra reservada
insert into _al values
  -- A · las herramientas de Bluebeam de Edgar → la receta genérica comercial en EMT
  ('20A DUPLEX RECEPTACLE',          '20A DUPLEX RECEPTACLE',              'RECEPTÁCULO 20A DUPLEX — EMT',                    false),
  ('20A GFCI DUPLEX RECEPTACLE',     '20A GFCI DUPLEX RECEPTACLE',         'RECEPTÁCULO GFCI 20A — EMT',                      false),
  ('20A SINGLE RECEPTACLE USB',      '20A SINGLE RECEPTACLE USB',          'RECEPTÁCULO USB 20A — EMT',                       false),
  ('SINGLE POLE SWITCH',             'SINGLE POLE SWITCH',                 'SWITCH SENCILLO 20A — EMT',                       false),
  ('THREE WAY SWITCH',               'THREE WAY SWITCH',                   'SWITCH TRES VÍAS — EMT',                          false),
  ('FOUR WAY SWITCH',                'FOUR WAY SWITCH',                    'SWITCH CUATRO VÍAS — EMT',                        false),
  ('DIMMER SW. 600 WATTS',           'DIMMER SW. 600 WATTS',               'DIMMER DE PARED 600W — EMT',                      false),
  ('PASSIVE INFRA. OCUP. SENSOR',    'PASSIVE INFRA. OCUP. SENSOR',        'SENSOR DE OCUPACIÓN DE PARED — EMT',              false),
  ('CEILING OCCUPANCY SENSOR',       'CEILING OCCUPANCY SENSOR',           'SENSOR DE OCUPACIÓN DE TECHO — EMT',              false),
  ('2''X2'' RECE. FLUORESCENT',      '2''X2'' RECE. FLUORESCENT',          'LUMINARIA 2X2 — EMT',                             false),
  ('24"X24" LED TROFFER (RECESSED)', '24"X24" LED TROFFER (RECESSED)',     'LUMINARIA 2X2 — EMT',                             false),
  ('DOWN LIGHT',                     'DOWN LIGHT',                         'DOWN LIGHT — EMT',                                false),
  ('4" RECESSED CAN LIGHT',          '4" RECESSED CAN LIGHT',              'RECESSED CAN 4" — EMT',                           false),
  ('LED CAN LIGHT (RECESSED)',       'LED CAN LIGHT (RECESSED)',           'RECESSED CAN 4" — EMT',                           false),
  ('EXIT SIGN BACK/TOP MTD',         'EXIT SIGN BACK/TOP MTD',             'EXIT SIGN — EMT',                                 false),
  ('BATTERY LIGHT SURFACE',          'BATTERY LIGHT SURFACE',              'LUZ DE EMERGENCIA BATERÍA — EMT',                 false),
  ('COMBO PH/DATA',                  'COMBO PH/DATA',                      'SALIDA DE DATOS CAT6 2 PUERTOS — EMT',            false),
  ('COMPUTER OUTLET (4 JACKS)',      'COMPUTER OUTLET (4 JACKS)',          'SALIDA DE DATOS CAT6 2 PUERTOS — EMT',            false),
  ('TELEPHONE OUTLET (2 JACKS)',     'TELEPHONE OUTLET (2 JACKS)',         'SALIDA DE TELÉFONO — EMT',                        false),
  ('TV OUTLET',                      'TV OUTLET',                          'SALIDA DE TV / COAX — EMT',                       false),
  ('CCTV CAMERA',                    'CCTV CAMERA',                        'CÁMARA IP (PoE) EN TECHO — EMT',                  false),
  ('MANUAL PULL STATION',            'MANUAL PULL STATION',                'ESTACIÓN MANUAL (PULL STATION)',                  false),
  ('SMOKE DETECTOR W/BASE',          'SMOKE DETECTOR W/BASE',              'DETECTOR DE HUMO CON BASE',                       false),
  ('HEAT DETECTOR W/BASE',           'HEAT DETECTOR W/BASE',               'DETECTOR DE CALOR CON BASE',                      false),
  ('DUCT SMOKE DETECTOR',            'DUCT SMOKE DETECTOR',                'DETECTOR DE HUMO DE DUCTO',                       false),
  ('STROBE LIGHT W/BACKBOX',         'STROBE LIGHT W/BACKBOX',             'STROBE F/A',                                      false),
  ('HORN / STROBE LIGHT W/BACKBOX',  'HORN / STROBE LIGHT W/BACKBOX',      'HORN/STROBE F/A',                                 false),
  ('WP HORN / STROBE LIGHT W/BACKBOX','WP HORN / STROBE LIGHT W/BACKBOX',  'HORN/STROBE F/A INTEMPERIE (WP)',                 false),
  ('FIRE ALARM SPEAKER',             'FIRE ALARM SPEAKER',                 'BOCINA F/A (SPEAKER)',                            false),
  ('FIRE ALARM MODULE',              'FIRE ALARM MODULE',                  'MÓDULO DE MONITOREO F/A',                         false),
  -- B · los nombres de categoría del hospital (docs/nch/RECETAS-QUE-FALTAN.md) → receta HG
  ('HG duplex ivory',                '20A HOSPITAL GRADE TR RECEPTACLE',   'RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT',         false),
  ('HG duplex ivory DOBLE (2 gang)', '20A HOSPITAL GRADE TR RECEPTACLE',   'RECEPTÁCULO 20A HG TR DOBLE (2 GANG) — EMT',      false),
  ('HG GFCI ivory',                  '20A GFCI HOSPITAL GRADE TR/WR',      'RECEPTÁCULO GFCI 20A HOSPITAL GRADE TR — EMT',    false),
  ('HG duplex ROJO',                 '20A HOSPITAL GRADE TR RECEPTACLE RED','RECEPTÁCULO 20A HG TR ROJO (RAMA CRÍTICA) — EMT', false),
  ('HG GFCI ROJO',                   '20A GFCI HOSPITAL GRADE RED',        'RECEPTÁCULO GFCI 20A HG ROJO (RAMA CRÍTICA) — EMT', false),
  ('Caja TV multigang',              'NEMA 1 ENCLOSURE 12x12x4',           'SALIDA DE TV MULTIGANG CON DIVISOR — EMT',        false),
  ('Dimmer 0-10V + sensor',          '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', 'DIMMER 0-10V CON SENSOR DE OCUPACIÓN DE PARED — EMT', false),
  ('Sensor de ocupación pared',      'PIR OCCUPANCY SENSOR',               'SENSOR DE OCUPACIÓN DE PARED — EMT',              false),
  ('Switch sencillo',                '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE', 'SWITCH SENCILLO 20A — EMT',             false),
  ('Relé UL 924',                    'UL 924 EMERGENCY LIGHTING CONTROL RELAY', 'RELÉ DE EMERGENCIA UL 924 — EMT',            false),
  ('Data + data/tel',                '1" ISOLATING BUSHING',               'SALIDA DE DATOS — SOLO ROUGH (STUB 1" EMT)',      true),
  ('Card reader',                    '1" ISOLATING BUSHING',               'LECTOR DE TARJETA — SOLO ROUGH (STUB 1" EMT)',    true),
  ('WAP',                            'JB 1900 BOX',                        'WAP EN TECHO — SOLO ROUGH',                       false),
  ('Cámara',                         'JB 1900 BOX',                        'CÁMARA EN TECHO — SOLO ROUGH',                    false),
  ('Speaker voceo',                  'JB 1900 BOX',                        'SPEAKER DE VOCEO EN TECHO — SOLO ROUGH',          false),
  ('Botón puerta',                   '1/2" ISOLATING BUSHING',             'BOTÓN DE APERTURA DE PUERTA — SOLO ROUGH (STUB 1/2" EMT)', true),
  ('Troffer 2x2',                    '24"X24" LED TROFFER (RECESSED)',     'LUMINARIA 2X2 — EMT',                             false),
  ('Downlight 4"',                   '4" RECESSED CAN LIGHT',              'RECESSED CAN 4" — EMT',                           false),
  ('Exit sign',                      'EXIT SIGN BACK/TOP MTD',             'EXIT SIGN — EMT',                                 false),
  ('J-box HVAC',                     '4-11/16 BOX',                        'CAJA DE DERIVACION 4-11/16 EN PARED — EMT',       false);

-- los que ya existen: se les pone la receta (el item se respeta)
update alias_takeoff a set receta = t.receta, receta_full = t.con_tubo
  from _al t
 where upper(btrim(regexp_replace(a.alias,'\s+',' ','g'))) = upper(btrim(regexp_replace(t.alias,'\s+',' ','g')));

-- los que no existen: se crean
insert into alias_takeoff (alias, item, factor, receta, receta_full)
select t.alias, t.item, 1, t.receta, t.con_tubo
  from _al t
 where not exists (select 1 from alias_takeoff a
        where upper(btrim(regexp_replace(a.alias,'\s+',' ','g'))) = upper(btrim(regexp_replace(t.alias,'\s+',' ','g'))));

drop table if exists _al;

-- ── 4. Comprobar ────────────────────────────────────────────────────────────
-- 4a. Cuántos alias apuntan ya a receta (deben ser 50) y cuántos a una receta que NO existe (debe ser 0)
select count(*) filter (where receta is not null) as con_receta,
       count(*) filter (where receta is not null and not exists (select 1 from ensambles e where e.nombre = a.receta)) as receta_inexistente
  from alias_takeoff a;

-- 4b. Si el segundo número no es 0, aquí están los culpables
select alias, receta from alias_takeoff a
 where receta is not null and not exists (select 1 from ensambles e where e.nombre = a.receta);

-- 4c. Las dos recetas nuevas, explotadas
select e.nombre, count(*) as piezas,
       round(sum(x.cantidad * c.precio)::numeric, 2) as material,
       round(sum(x.cantidad * c.horas_unidad)::numeric, 2) as horas
  from ensambles e join ensamble_items x on x.ensamble_id = e.id
  join catalogo_items c on upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(regexp_replace(x.item,'\s+',' ','g')))
 where e.nombre in ('RECEPTÁCULO 20A DUPLEX — EMT', 'SENSOR DE OCUPACIÓN DE TECHO — EMT')
 group by e.nombre;
