-- =====================================================================
-- E9d · Seis datos del catálogo que no cuadran (encontrados el 16/09 al
--       preparar las recetas, comprobados uno por uno contra tu export
--       y contra lo que TÚ cobraste a mano en Stuart y UM).
--
-- OJO, ESTO MUEVE DINERO: las horas y los precios del catálogo los leen
-- TODAS las recetas y todos los estimados que no estén congelados. Por eso
-- va en tres partes: primero MIRAS, luego decides, y solo entonces corres
-- el UPDATE que quieras. No corras el archivo entero de una.
--
-- Nada de esto es opinión mía sobre cómo trabajas: son números que se
-- contradicen entre sí (un four-way que cuesta cinco veces un three-way)
-- o filas duplicadas donde el estimador no sabe cuál coger.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PARTE 1 · MIRAR (solo lectura, corre esto primero)
-- ---------------------------------------------------------------------
-- 1.a Los seis datos, uno al lado del otro con su pariente sano
select item, unidad, precio, horas_unidad, codigo, seccion
  from catalogo_items
 where item in (
   'FOUR WAY SWITCH', 'THREE WAY SWITCH', 'SINGLE POLE SWITCH',
   '20A GFCI DUPLEX RECEPTACLE', '20A DUPLEX RECEPTACLE',
   '15A DUPLEX TAMPER RESISTANT', '15A DUPLEX RECEPTACLE',
   'WP DEVICES COVERS')
 order by item;

-- 1.b Las filas DUPLICADAS (mismo nombre, dos veces): el estimador casa por
--     nombre, así que con dos filas coge una de las dos y nadie sabe cuál.
select upper(btrim(regexp_replace(item,'\s+',' ','g'))) as nombre,
       count(*) as veces,
       string_agg(id::text || ': $' || coalesce(precio,0)::text || ' / ' || coalesce(horas_unidad,0)::text || ' h', '  |  ' order by id) as filas
  from catalogo_items
 group by 1 having count(*) > 1
 order by 1;

-- 1.c A cuántos estimados VIVOS les afectaría tocar esos ítems
select c.item, count(distinct i.estimado_id) as estimados, sum(i.cantidad) as cantidad
  from catalogo_items c
  join estimado_items i on upper(btrim(regexp_replace(i.item,'\s+',' ','g')))
                         = upper(btrim(regexp_replace(c.item,'\s+',' ','g')))
 where c.item in ('FOUR WAY SWITCH','20A GFCI DUPLEX RECEPTACLE','15A DUPLEX TAMPER RESISTANT','1G PLASTIC COVER RECEPTACLE','WP DEVICES COVERS')
 group by c.item order by estimados desc;

-- ---------------------------------------------------------------------
-- PARTE 2 · LOS SEIS CASOS, con el porqué. Descomenta el que aceptes.
-- ---------------------------------------------------------------------

-- (1) FOUR WAY SWITCH: 1,25 h por unidad. El THREE WAY está en 0,25 y el
--     SINGLE POLE en 0,20 — y en Stuart tú cobraste 0,25 h por los seis
--     three-way. Un four-way se instala igual que un three-way (una caja,
--     cuatro hilos): 1,25 h son CINCO veces el three-way, y cada uno mete
--     ~$50 de más en el bid. Parece un tecleo (1.25 por 0.25).
-- update catalogo_items set horas_unidad = 0.30 where item = 'FOUR WAY SWITCH';

-- (2) 20A GFCI DUPLEX RECEPTACLE: el catálogo dice 0,5 h; tu Excel de Stuart
--     cobró 0,3 h (15 unidades). El duplex normal está en 0,4. Si 0,5 es lo
--     que de verdad te toma (el GFCI lleva más cable en la caja), déjalo y
--     no corras esto; si el bueno es el de tu hoja, corre el update.
-- update catalogo_items set horas_unidad = 0.30 where item = '20A GFCI DUPLEX RECEPTACLE';

-- (3) 15A DUPLEX TAMPER RESISTANT: 0,5 h contra 0,3 h del 15A normal. Es la
--     misma pieza con obturador: se instala igual.
-- update catalogo_items set horas_unidad = 0.30 where item = '15A DUPLEX TAMPER RESISTANT';

-- (4) 1G PLASTIC COVER RECEPTACLE está DOS VECES: $0,20/0,06 h y $0,55/0,08 h.
--     En Stuart usaste 51 a $0,55. Esto NO es de opinión: con dos filas
--     iguales el estimador coge una de las dos sin criterio. Borra la otra.
-- delete from catalogo_items
--  where item = '1G PLASTIC COVER RECEPTACLE' and precio = 0.20;

-- (5) DOWN LIGHT también está dos veces: una a $0 / 0,8 h SIN sección (así
--     entran las filas que se cargaron sueltas) y otra a $55 / 0,75 h en
--     LIGHTING FIXTURES. La de $0 es útil si la luminaria la pone el dueño
--     —en Stuart las cuatro fueron a $0— pero entonces merece llamarse
--     distinto para que no se confundan al buscar.
-- update catalogo_items set item = 'DOWN LIGHT - INSTALL ONLY', seccion = 'LIGHTING FIXTURES', codigo = '11-LIGHT'
--  where item = 'DOWN LIGHT' and coalesce(precio,0) = 0;
--     (10A FUSES y LIGHTING RELAY también están duplicados, pero las dos
--      filas son idénticas: no cambian ningún número, solo ensucian la
--      búsqueda. Si quieres limpiarlas:)
-- delete from catalogo_items a using catalogo_items b
--  where a.id > b.id and a.item = b.item and a.item in ('10A  FUSES','LIGHTING RELAY');

-- (6) WP DEVICES COVERS: $65 con 0,008 h (medio minuto). O el precio es de
--     otra cosa o las horas se cargaron mal; tal como está, un receptáculo
--     exterior se lleva $65 de tapa y no cobra la mano de obra de ponerla.
--     No lo cambio a ciegas: dime qué pieza es y lo dejamos bien.
-- select id, item, precio, horas_unidad, seccion from catalogo_items where item = 'WP DEVICES COVERS';

-- ---------------------------------------------------------------------
-- PARTE 3 · COMPROBAR DESPUÉS (segundo pegado)
-- ---------------------------------------------------------------------
-- select item, precio, horas_unidad from catalogo_items
--  where item in ('FOUR WAY SWITCH','THREE WAY SWITCH','20A GFCI DUPLEX RECEPTACLE',
--                 '15A DUPLEX TAMPER RESISTANT','1G PLASTIC COVER RECEPTACLE')
--  order by item;
