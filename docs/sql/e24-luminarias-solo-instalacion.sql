-- ============================================================================
-- E24 · LUMINARIAS QUE PONE OTRO: SOLO LA MANO (17/09/2026)
-- ============================================================================
-- Edgar, con la pantalla de Planos delante (STAK 2X2 5000 lm ×25, STAK 2X2
-- 2000 lm ×23, SCR 22 cleanroom ×20, LDN4 ×3 «SIN MAPEAR»):
--   «la IA tiene que saber que nosotros no ponemos las luces: por materiales
--    seria solo hora... la de 2000 lumens y la de 5000 es lo mismo en tiempo,
--    donde cambia es en el precio de la luz, y cuando tengamos la cuota la
--    ponemos aparte».
--
-- Ya existen LUMINARIA 2X2 — SOLO INSTALACIÓN y LUMINARIA 2X4 — SOLO
-- INSTALACIÓN (e9e). Faltaban el downlight y el exit sign. Aqui van, con un
-- item de catalogo de $0 y solo horas para colgar la luz que trae otro.
-- Planos v34.C manda a estas recetas cualquier luminaria que no este en el
-- catalogo (por su forma: 2X2 / 22 / STAK / SCR → 2x2; LDN4 / 4" → downlight)
-- y la luz en si va aparte como «Cotizacion de luminarias — pendiente».
-- Idempotente: lo que ya exista no se toca.
-- ============================================================================

-- 1) Los dos items de solo mano ($0, horas de colgar)
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'INSTALACIÓN DOWNLIGHT (LUZ POR OTROS)', 'LIGHTING FIXTURES', 'E', 0, 0.75, '11-LIGHT'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'INSTALACIÓN DOWNLIGHT (LUZ POR OTROS)');
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'INSTALACIÓN EXIT SIGN (LUZ POR OTROS)', 'LIGHTING FIXTURES', 'E', 0, 0.75, '11-LIGHT'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'INSTALACIÓN EXIT SIGN (LUZ POR OTROS)');

-- 2) Las dos recetas
insert into ensambles (nombre, modo, pies_editable, orden, descripcion)
select v.nombre, v.modo, v.pies, v.orden, v.descripcion
  from (values
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', 'comercial', false, 217, 'Colgar un downlight que trae el dueño (LDN4 y parecidos): caja 1900 con colgador de T-bar, whip de 3/8" flex de 6 ft con sus dos conectores, 3 hilos #12, wirenuts y pigtail. La luminaria NO: va en la cotización de luminarias. Mismo tiempo sea de 35 o de 10 W.'),
    ('EXIT SIGN — SOLO INSTALACIÓN', 'comercial', false, 218, 'Colgar un exit sign que trae el dueño (LQM y parecidos): caja 1900 con anillo de techo, 3 hilos #12, wirenuts y pigtail. El letrero NO: va en la cotización de luminarias.')
  ) as v(nombre, modo, pies, orden, descripcion)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

-- 3) Los componentes (mismos que RECESSED CAN 4" — EMT y EXIT SIGN — EMT, sin la luz y sin el EMT que mide Edgar)
insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', 'INSTALACIÓN DOWNLIGHT (LUZ POR OTROS)', 1),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', 'JB 1900 BOX', 1),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', 'T-BAR BOX HANGER', 1),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', '3/8"      FLEX. METAL CONDUIT', 6),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', '# 12      THHN STRANDED CU.', 0.018),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', 'YELLOW WIRENUTS', 3),
    ('DOWNLIGHT 4" — SOLO INSTALACIÓN', '#12     GROUND PIGTAIL', 1),
    ('EXIT SIGN — SOLO INSTALACIÓN', 'INSTALACIÓN EXIT SIGN (LUZ POR OTROS)', 1),
    ('EXIT SIGN — SOLO INSTALACIÓN', 'JB 1900 BOX', 1),
    ('EXIT SIGN — SOLO INSTALACIÓN', 'CEILING RING  1/2"', 1),
    ('EXIT SIGN — SOLO INSTALACIÓN', '# 12      THHN STRANDED CU.', 0.012),
    ('EXIT SIGN — SOLO INSTALACIÓN', 'YELLOW WIRENUTS', 3),
    ('EXIT SIGN — SOLO INSTALACIÓN', '#12     GROUND PIGTAIL', 1)
  ) as v(receta, item, cantidad)
  join ensambles e on e.nombre = v.receta
 where not exists (select 1 from ensamble_items x where x.ensamble_id = e.id and x.item = v.item);

-- 4) Comprobar: las cuatro recetas de solo instalacion y lo que cuesta cada una.
--    OJO: si la 2X2 o la 2X4 traen la luminaria CON precio, no son «solo
--    instalacion»: ponle 0 al item de la luz o cambialo por uno de solo mano.
select e.nombre, count(x.item) as piezas,
       round(sum(x.cantidad * c.precio)::numeric, 2) as material,
       round(sum(x.cantidad * c.horas_unidad)::numeric, 2) as horas,
       string_agg(case when c.precio > 20 then x.item || ' $' || c.precio end, ' · ') as caros
  from ensambles e
  join ensamble_items x on x.ensamble_id = e.id
  join catalogo_items c on upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(regexp_replace(x.item,'\s+',' ','g')))
 where e.nombre like '%SOLO INSTALACIÓN%'
 group by e.nombre order by e.nombre;
