-- =====================================================================
-- E9f · Lo que encontraron los verificadores al revisar las 80 recetas
--       (16/09). Son datos del CATÁLOGO que no cuadran, no recetas.
--
-- Esto se corre ANTES que e9e-recetas-80.sql. Dos de estas filas no son
-- opcionales: mientras existan, dos recetas entran al bid con el precio
-- equivocado y nadie se entera.
--
-- Igual que en e9d: primero MIRAS, luego decides, y solo entonces corres
-- el UPDATE. No corras el archivo entero de una.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PARTE 0 · Lo que quedó pendiente de la semana pasada
-- ---------------------------------------------------------------------
alter table estimados add column if not exists notas text;

-- ---------------------------------------------------------------------
-- PARTE 1 · MIRAR (solo lectura)
-- ---------------------------------------------------------------------
-- 1.a Las filas con nombre repetido: el estimador casa por nombre
--     normalizado, así que con dos filas coge UNA y nadie sabe cuál.
--     Hoy quedan dos que tocan las recetas nuevas.
select upper(btrim(regexp_replace(item,'\s+',' ','g'))) as nombre,
       count(*) as veces,
       string_agg(id::text || ': $' || coalesce(precio,0)::text || ' / ' ||
                  coalesce(horas_unidad,0)::text || ' h', '  |  ' order by id) as filas
  from catalogo_items
 group by 1 having count(*) > 1
 order by 1;

-- 1.b Piezas de VERDAD que están a $0: el bid cobra la mano de obra y
--     regala el material. Las de DEMO, TESTING y PROGRAMMING están bien
--     a $0 (son horas); las demás no.
select item, unidad, precio, horas_unidad, codigo, seccion
  from catalogo_items
 where coalesce(precio,0) = 0
   and item not ilike 'DEMO%' and item not ilike '%TESTING%'
   and item not ilike '%PROGRAMMING%' and item not ilike '%INSPECTION%'
 order by horas_unidad desc;

-- 1.c El CAT6: mira la unidad contra el precio.
select item, unidad, precio, horas_unidad from catalogo_items
 where item ilike '%CAT6%' or item ilike '%SECURITY CABLE%' or item ilike '%RG6%'
 order by item;

-- ---------------------------------------------------------------------
-- PARTE 2 · LOS CASOS. Descomenta el que aceptes.
-- ---------------------------------------------------------------------

-- (1) 1G PLASTIC COVER RECEPTACLE está DOS VECES: una a $0,20 / 0,06 h y
--     otra a $0,55 / 0,08 h. Cuatro recetas residenciales y cuatro
--     comerciales la llevan. En Stuart compraste 51 a $0,55, así que esa
--     es la buena. Con las dos filas vivas, el join puede sumar las dos.
--     ESTO NO ES OPCIONAL si vas a usar las recetas de dispositivos.
-- delete from catalogo_items
--  where upper(btrim(regexp_replace(item,'\s+',' ','g'))) = '1G PLASTIC COVER RECEPTACLE'
--    and coalesce(precio,0) < 0.30;

-- (2) DOWN LIGHT está DOS VECES: una a $55 / 0,75 h (la pieza) y otra a
--     $0 / 0,8 h con un espacio al final (la de solo instalación). Las
--     recetas DOWN LIGHT — MC y DOWN LIGHT — EMT casan con la que el
--     motor encuentre primero: si coge la de $0, el down light entra al
--     bid regalado. Renombrar la de $0 las separa para siempre.
--     ESTO NO ES OPCIONAL si vas a usar las dos recetas de down light.
-- update catalogo_items set item = 'DOWN LIGHT - INSTALL ONLY'
--  where coalesce(precio,0) = 0 and btrim(item) = 'DOWN LIGHT';

-- (3) FIXTURES HOLDER CLIPS: 0,1 h por clip = 6 minutos por poner UN clip
--     de resorte en la retícula. Van 4 por luminaria, o sea 24 minutos de
--     clips por troffer. Las cuatro recetas de 2X2/2X4 los llevan y por
--     eso salen a 2,81 h en vez de 2,49.
-- update catalogo_items set horas_unidad = 0.02 where item = 'FIXTURES HOLDER CLIPS';

-- (4) La bell box de exterior: `2"x 4" BELL BOX-BOX` a 0,35 h y su tapa a
--     0,20 h suman 0,55 h. En tu Excel de Stuart el ítem de las DOS piezas
--     juntas (`2"x 4" BELL BOX-BOX AND DEVICE COVER`) va a 0,2 h. O sea:
--     por separado cobran casi el triple que juntas.
-- update catalogo_items set horas_unidad = 0.12 where item = '2"x 4"    BELL BOX-BOX';
-- update catalogo_items set horas_unidad = 0.08 where item = '2"x 4"    BELL BOX-DEVICE COVER';

-- (5) 20A DUPLEX RECEPTACLE USB está a $16,39 — que es EXACTAMENTE el
--     precio del 20A GFCI DUPLEX RECEPTACLE. Un precio arrastrado de otra
--     fila, no el de una pieza USB. En el propio catálogo están las piezas
--     USB de verdad: $42 la Leviton T5836 y $58 la USB-C PD de 60 W.
--     Las dos recetas USB nuevas usan ya la Leviton, así que esto solo
--     hace falta si sigues cotizando la fila vieja a mano.
-- update catalogo_items set precio = 42 where item = '20A DUPLEX RECEPTACLE USB';

-- (6) CAT6 CABLE: $0,18 y 0,02 h con unidad MLF. Eso dice «18 centavos y
--     un minuto por cada MIL PIES de CAT6». Son números por PIE cargados
--     en una fila de MLF. Los otros cables de datos van a 8 h/MLF.
--     No lo corro yo porque no sé tu precio de compra: mira 1.c y decide.
--     Si el precio bueno es $180/MLF y 8 h/MLF:
-- update catalogo_items set precio = 180, horas_unidad = 8 where item = 'CAT6 CABLE';

-- (7) THREE POLE SWITCH a 1,3 h/u. Es el mismo caso del FOUR WAY de e9d
--     (el DOUBLE POLE está a 0,30). No lo toco porque ninguna receta nueva
--     lo usa, pero está ahí esperando.
-- update catalogo_items set horas_unidad = 0.35 where item = 'THREE POLE SWITCH';

-- ---------------------------------------------------------------------
-- PARTE 3 · LO QUE FALTA EN EL CATÁLOGO
--   Ninguna receta lo usa (por eso las 80 entran limpias), pero sin
--   estos ítems hay puntos que se cotizan incompletos. Dalos de alta
--   cuando tengas el precio y te digo en qué recetas entran.
-- ---------------------------------------------------------------------
-- insert into catalogo_items (item, unidad, precio, horas_unidad, codigo, seccion) values
--   ('1 GANG OLD WORK PLASTIC BOX (cut-in)', 'E',  1.20, 0.30, '09-COND', 'BOXES'),
--   ('2 GANG OLD WORK PLASTIC BOX (cut-in)', 'E',  2.10, 0.35, '09-COND', 'BOXES'),
--   ('2G PLASTIC COVER RECEPTACLE',          'E',  0.45, 0.10, '10-DEV',  'WIRING DEVICES'),
--   ('1G DECORA WALL PLATE',                 'E',  0.60, 0.08, '10-DEV',  'WIRING DEVICES'),
--   ('4-11/16 BLANK COVER',                  'E',  1.10, 0.07, '09-COND', 'BOXES'),
--   ('WP IN-USE COVER 2X4 (burbuja)',        'E', 14.00, 0.15, '10-DEV',  'WIRING DEVICES'),
--   ('MC ANTI-SHORT BUSHING 3/8"',           'E',  0.05, 0.01, '09-COND', 'MC'),
--   ('NM CABLE CONNECTOR 3/4"',              'E',  0.95, 0.05, '09-COND', 'CONNECTORS'),
--   ('BREAKER 3P 30A',                       'E', 180.00, 0.35, '05-PANEL','BREAKERS'),
--   ('DEMO - Boxes',                         'EA', 0.00, 0.10, '01-DEMO', 'DEMOLITION'),
--   ('REQUEST-TO-EXIT (REX) MOTION SENSOR',  'EA', 95.00, 0.50, '13-LV',  'ACCESS CONTROL'),
--   ('REX PUSH BUTTON',                      'EA', 45.00, 0.35, '13-LV',  'ACCESS CONTROL'),
--   ('FIXTURE STUD / CROSSBAR 4"',           'E',  0.85, 0.05, '11-LIGHT','FIXTURES'),
--   ('6" RECESSED CAN LIGHT',                'E', 45.00, 0.85, '11-LIGHT','LIGHTING FIXTURES'),
--   ('1/2" EMT RAIN-TIGHT COMPRESSION CONNECTOR','E', 1.85, 0.06, '09-COND','CONNECTORS');

-- ---------------------------------------------------------------------
-- PARTE 4 · COMPROBAR (después de e9e)
-- ---------------------------------------------------------------------
-- 4.a Ninguna receta con componente huérfano (tiene que salir 0 filas)
-- select e.nombre, ei.item
--   from ensambles e
--   join ensamble_items ei on ei.ensamble_id = e.id
--   left join catalogo_items c
--          on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
--           = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  where c.id is null;

-- 4.b Ninguna receta con un componente que case con DOS filas del catálogo
-- select e.nombre, ei.item, count(c.id) as filas
--   from ensambles e
--   join ensamble_items ei on ei.ensamble_id = e.id
--   join catalogo_items c
--     on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
--      = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  group by e.nombre, ei.item having count(c.id) > 1;

-- 4.c Las 80 con sus horas y su material
-- select e.nombre, e.modo, count(ei.id) as componentes,
--        round(sum(ei.cantidad * coalesce(c.horas_unidad,0))::numeric, 2) as horas,
--        round(sum(ei.cantidad * coalesce(c.precio,0))::numeric, 2) as material
--   from ensambles e
--   join ensamble_items ei on ei.ensamble_id = e.id
--   left join catalogo_items c
--          on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
--           = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  where e.orden >= 100
--  group by e.nombre, e.modo, e.orden order by e.modo, e.orden;
