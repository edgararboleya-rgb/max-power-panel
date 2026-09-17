-- ============================================================================
-- E23c · NICKLAUS: la instalacion de las luces EXPLICITA y las luces en si
--        como cotizacion pendiente con precio de referencia (17/09)
-- ============================================================================
-- Edgar: «incluyemelo todo en el borrador». Antes la mano de colgar cada luz
-- iba escondida en las horas de la linea de la luminaria (66 troffers a $75 y
-- 1,0 h). Ahora:
--   1. La MANO va en su propio renglon de $0 con sus horas (LUZ POR OTROS),
--      con las cantidades del plano: 68 troffers (25 STAK 5000 + 23 STAK 2000
--      + 20 SCR 22), 3 downlights, 7 exits. Y los accesorios de los 2 troffers
--      de mas (clips, hanger, whip, caja, wirenuts, pigtail).
--   2. La LUZ en si va por modelo, como cotizacion pendiente, al precio de
--      ARRIBA del rango de calle (regla de Edgar: estar cubierto). Cuando Jose
--      cotice, se cambia el unitario y ya. NO son precios cotizados.
--        STAK 2X2 (5.000 y 2.000 lm: mismo troffer) $150 · SCR 22 cleanroom
--        $550 · LDN4 $220 · LQM exit $110
-- Se corre UNA vez, despues del e23 y del e23b.
-- ============================================================================

-- 0) el item de solo mano del 2x2 (los del downlight y el exit los trae el e24)
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select 'INSTALACIÓN LUMINARIA 2X2 (LUZ POR OTROS)', 'LIGHTING FIXTURES', 'E', 0, 1.0, '11-LIGHT'
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = 'INSTALACIÓN LUMINARIA 2X2 (LUZ POR OTROS)');

-- 1) las tres lineas de luminaria pasan a ser SOLO LA MANO (mismas horas, $0)
update estimado_items x set item = 'INSTALACIÓN LUMINARIA 2X2 (LUZ POR OTROS)', precio = 0, cantidad = 68
  from estimados e where e.id = x.estimado_id and e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and x.item = '24"X24" LED TROFFER (RECESSED)';
update estimado_items x set item = 'INSTALACIÓN EXIT SIGN (LUZ POR OTROS)', precio = 0
  from estimados e where e.id = x.estimado_id and e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and x.item = 'EXIT SIGN BACK/TOP MTD';
update estimado_items x set item = 'INSTALACIÓN DOWNLIGHT (LUZ POR OTROS)', precio = 0
  from estimados e where e.id = x.estimado_id and e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and x.item = '4" RECESSED CAN LIGHT';

-- 2) los accesorios de los 2 troffers de mas (66 → 68)
update estimado_items x set cantidad = cantidad + d.mas
  from estimados e, (values
    ('FIXTURES HOLDER CLIPS', 8), ('T-BAR BOX HANGER', 2), ('3/8"      FLEX. METAL CONDUIT', 12),
    ('3/8"      FLEX. METAL ST. CONNECT.', 4), ('JB 1900 BOX', 2), ('YELLOW WIRENUTS', 6), ('#12     GROUND PIGTAIL', 2)
  ) as d(item, mas)
 where e.id = x.estimado_id and e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and x.item = d.item and x.origen = 'takeoff-nch-2026-09-17';

-- 3) las luces en si: cotizacion pendiente, precio de referencia ARRIBA del rango
insert into estimado_items (estimado_id, item, unidad, precio, horas, cantidad, origen, codigo, orden)
select e.id, v.item, 'E', v.precio, 0, v.cantidad, 'cotizacion-referencia', '11-LIGHT', v.orden
  from estimados e, (values
    ('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 5000LM 80CRI 35K MVOLT (ref. $150, pedir a Jose)',   150, 25, 700),
    ('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 2000LM 80CRI 35K MVOLT (ref. $150, pedir a Jose)',   150, 23, 701),
    ('COTIZACIÓN PENDIENTE — LITHONIA SCR 22 CLEANROOM 2X2 (ref. $550, pedir a Jose — el caro)',    550, 20, 702),
    ('COTIZACIÓN PENDIENTE — LITHONIA LDN4 35/10 LO4 4" RECESSED (ref. $220)',                       220,  3, 703),
    ('COTIZACIÓN PENDIENTE — LITHONIA LQM EXIT SIGN (ref. $110)',                                    110,  7, 704)
  ) as v(item, precio, cantidad, orden)
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and not exists (select 1 from estimado_items x where x.estimado_id = e.id and x.origen = 'cotizacion-referencia');

-- Comprobar: 65 renglones, ~64.090 de material, ~826 h
select count(*) as renglones,
       round(sum(cantidad * precio)::numeric, 2) as material,
       round(sum(cantidad * horas)::numeric, 1) as horas
  from estimado_items x join estimados e on e.id = x.estimado_id
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';

-- Y solo las luces, para verlas juntas: mano (0 $, horas) y cotizacion (precio, 0 h)
select item, cantidad, precio, horas, round((cantidad * precio)::numeric, 2) as material, round((cantidad * horas)::numeric, 1) as h
  from estimado_items x join estimados e on e.id = x.estimado_id
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and (item like 'INSTALACIÓN%' or item like 'COTIZACIÓN%')
 order by item;
