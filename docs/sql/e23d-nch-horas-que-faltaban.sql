-- ============================================================================
-- E23d · NICKLAUS: las HORAS que no estaban en el borrador (17/09)
-- ============================================================================
-- Edgar: «lo que yo queria que arreglaras era lo de las horas». El borrador
-- tenia la mano de instalar cada pieza, pero no la de: terminar los circuitos
-- en el panel, demoler lo existente (hojas ED-1.1/1.2/1.3), rotular, poner en
-- marcha los dimmers 0-10V con sensor, y cerrar (as-built, pruebas).
-- Van como items de SOLO MANO ($0, horas) al catalogo — plantilla para
-- cualquier trabajo — y al estimado NCH con sus cantidades.
--
-- OJO, un numero es supuesto: la DEMOLICION va en 80 unidades (dispositivos
-- y luminarias existentes a quitar en las tres ED). No las conte una a una:
-- cambia la cantidad en el estimador cuando las cuentes.
-- ============================================================================

-- 1) los items de solo mano (idempotente)
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo, cero_revisado)
select v.item, 'LABOR', 'E', 0, v.h, v.codigo, 'solo_labor', current_date
  from (values
    ('TERMINACIÓN DE CIRCUITO EN PANEL (por ckt)',                 0.50, '05-PANEL'),
    ('ROTULADO DE CIRCUITO Y DIRECTORIO DE PANEL (por ckt)',       0.10, '05-PANEL'),
    ('DEMOLICIÓN DE DISPOSITIVO O LUMINARIA EXISTENTE (por unidad)', 0.35, '01-DEMO'),
    ('PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)',        0.25, '11-LIGHT'),
    ('AS-BUILT, PRUEBAS Y CIERRE (por proyecto)',                  8.00, '20-MISC')
  ) as v(item, h, codigo)
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(v.item));

-- 2) al estimado NCH
insert into estimado_items (estimado_id, item, unidad, precio, horas, cantidad, origen, codigo, orden)
select e.id, v.item, 'E', 0, v.h, v.cantidad, 'takeoff-nch-2026-09-17-horas', v.codigo, v.orden
  from estimados e, (values
    ('TERMINACIÓN DE CIRCUITO EN PANEL (por ckt)',                 0.50, 47, '05-PANEL', 800),   -- 47 circuitos nuevos
    ('ROTULADO DE CIRCUITO Y DIRECTORIO DE PANEL (por ckt)',       0.10, 47, '05-PANEL', 801),
    ('DEMOLICIÓN DE DISPOSITIVO O LUMINARIA EXISTENTE (por unidad)', 0.35, 80, '01-DEMO',  802),   -- SUPUESTO: cuentalos en las ED
    ('PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)',        0.25, 31, '11-LIGHT', 803),   -- 22 combos + 9 sensores
    ('AS-BUILT, PRUEBAS Y CIERRE (por proyecto)',                  8.00,  1, '20-MISC',  804)
  ) as v(item, h, cantidad, codigo, orden)
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026'
   and not exists (select 1 from estimado_items x where x.estimado_id = e.id and x.origen = 'takeoff-nch-2026-09-17-horas');

-- Comprobar: 70 renglones, mismo material (~64.090), horas ~896 (826 + 70)
select count(*) as renglones,
       round(sum(cantidad * precio)::numeric, 2) as material,
       round(sum(cantidad * horas)::numeric, 1) as horas
  from estimado_items x join estimados e on e.id = x.estimado_id
 where e.nombre = 'NCH Radiology Expansion Ultrasound — bid 17/09/2026';
