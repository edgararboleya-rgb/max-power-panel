-- =========================================================================
-- E19 · PRECIOS DE REFERENCIA para Nicklaus — buscados online el 16/09/2026
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- Lo pidió Edgar: «propónmelo tú buscando online qué precio se ajusta y
-- después nos encargamos de ajustarlo mejor cuando me los dé CED».
--
-- REGLA: cada precio de aquí es de REFERENCIA. Cuando llegue la cotización
-- de CED, el bloque 4 (comentado) los pisa con el número real. Ninguno de
-- estos toca un $0 puesto a propósito («va por cotización»): el único $0
-- que se llena es el EXIT SIGN, que Edgar pidió llenar el 16/09.
-- =========================================================================

-- ── 1. EXIT SIGN: la fila que usan las recetas EXIT SIGN — EMT / — MC ──────
--   Lithonia LQM S W 3 R 120/277 EL N M6 (termoplástico, letras rojas,
--   batería 90 min) — el tipo X de la E-2.2, 7 en Nicklaus.
--   Geller Lighting $80,35 · Superior Lighting $84,70 · Home Depot $42,82
--   (retail). Se pone el de distribuidor: $80. Solo si sigue a $0.
update catalogo_items set precio = 80.00
 where upper(btrim(regexp_replace(item,'\s+',' ','g'))) = 'EXIT SIGN BACK/TOP MTD'
   and coalesce(precio, 0) = 0;

-- ── 2. El combo dimmer 0-10V + sensor: de $145 (estimado) a $120 (verificado)
--   Las luminarias son todas Lithonia (Acuity), así que el control que casa
--   es Sensor Switch WSX D WH: $118,91 en NorthEast Electrical. La alternativa
--   Lutron Maestro MS-Z101-WH está a $94,95 (ProLighting, trade). Se pone
--   $120. Solo si sigue en los $145 que puso e18.
update catalogo_items set precio = 120.00
 where upper(btrim(regexp_replace(item,'\s+',' ','g'))) = '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH'
   and coalesce(precio, 0) = 145;

-- ── 3. ALTAS (6) ───────────────────────────────────────────────────────────
--   Placas de acero inoxidable 302/304 (Leviton serie 84xxx): el documento
--   las recomienda en vez de las plásticas que cotizó CED. OJO: las 24
--   ROJAS no pueden ser de acero — el detalle D4 pide rojo en las ramas
--   esencial/crítica/equipos, y eso solo existe en plástico/nylon. El inox
--   aplica a las 54 + 8 ivory y a las 24 decora de switch.
--   Home Depot $4,50 (84003) · Leviton $9,31 / Home Depot $6,55 (84016) ·
--   Platt $6,69 (84401-40) · Leviton $10,49 (84409-40).
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select v.item, v.seccion, v.unidad, v.precio, v.horas, v.codigo
  from (values
    ('1G DUPLEX WALLPLATE STAINLESS STEEL',  'WIRING DEVICES', 'E',   4.50, 0.08, '10-DEV'),
    ('2G DUPLEX WALLPLATE STAINLESS STEEL',  'WIRING DEVICES', 'E',   8.00, 0.10, '10-DEV'),
    ('1G DECORA WALLPLATE STAINLESS STEEL',  'WIRING DEVICES', 'E',   6.69, 0.08, '10-DEV'),
    ('2G DECORA WALLPLATE STAINLESS STEEL',  'WIRING DEVICES', 'E',  10.49, 0.10, '10-DEV'),
    -- El par 0-10V morado/gris al driver: 18/2 CL3P plenum. No existía en
    -- el catálogo. Syston 8008 1000 ft: hasta $329,99 en su tienda. Por MIL
    -- pies, a las 8 h/MLF de los demás cables de baja tensión de Edgar.
    -- Para Nicklaus: ~1 MLF (66 luminarias en cadena + 22 switches).
    ('18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)', 'WIRING', 'MLF', 330.00, 8.00, '08-ROUGH'),
    -- El time clock del panel NH1: «Intermatic 4PST con override y batería».
    -- Intermatic ET8415C (4 circuitos, 7 días astronómico, respaldo 100 h,
    -- NEMA 1). El de 2 circuitos ET8215C está a $343,91 en Home Depot; el
    -- de 4 con ethernet y caja 3R (ET90415CR) a $1.472. Se pone $600, entre
    -- los dos. Tu ASTRONOMICAL TIME CLOCK de $80 es el residencial de 1 ckt.
    ('TIME CLOCK 4-CIRCUIT ASTRONOMIC W/ OVERRIDE (INTERMATIC ET8415C)', 'LIGHTING FIXTURES', 'E', 600.00, 2.00, '11-LIGHT')
  ) as v(item, seccion, unidad, precio, horas, codigo)
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(v.item));

-- ── 4. CUANDO LLEGUE CED: pisar la referencia con el precio real ──────────
--   Descomentar, poner el número, correr. Cada línea con su guarda para no
--   pisar un precio que ya se haya corregido a mano.
-- update catalogo_items set precio = 0.00 where item = '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH' and precio = 120;
-- update catalogo_items set precio = 0.00 where item = 'UL 924 EMERGENCY LIGHTING CONTROL RELAY'      and precio = 135;
-- update catalogo_items set precio = 0.00 where item = 'EXIT SIGN BACK/TOP MTD'                        and precio = 80;
-- update catalogo_items set precio = 0.00 where item = '18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)'   and precio = 330;
-- update catalogo_items set precio = 0.00 where item = 'TIME CLOCK 4-CIRCUIT ASTRONOMIC W/ OVERRIDE (INTERMATIC ET8415C)' and precio = 600;
-- update catalogo_items set precio = 0.00 where item = '1G DUPLEX WALLPLATE STAINLESS STEEL' and precio = 4.5;
-- update catalogo_items set precio = 0.00 where item = '2G DUPLEX WALLPLATE STAINLESS STEEL' and precio = 8;
-- update catalogo_items set precio = 0.00 where item = '1G DECORA WALLPLATE STAINLESS STEEL' and precio = 6.69;
-- update catalogo_items set precio = 0.00 where item = '2G DECORA WALLPLATE STAINLESS STEEL' and precio = 10.49;

-- ── 5. COMPROBAR (aparte) ──────────────────────────────────────────────────
-- select item, precio, horas_unidad, unidad from catalogo_items
--  where item in ('EXIT SIGN BACK/TOP MTD','0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH',
--                 'UL 924 EMERGENCY LIGHTING CONTROL RELAY','18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)',
--                 'TIME CLOCK 4-CIRCUIT ASTRONOMIC W/ OVERRIDE (INTERMATIC ET8415C)')
--     or item like '%WALLPLATE STAINLESS STEEL'
--  order by item;
