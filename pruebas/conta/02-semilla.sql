-- =====================================================================
-- 02-semilla.sql — datos de prueba del banco local. Se carga como
-- editor_sql (dueño de las tablas: se salta RLS, como el SQL Editor).
--
-- Todo va fechado en OCTUBRE de 2026 (la marcha en paralelo) salvo unos
-- pocos de SEPTIEMBRE, que existen para probar el guardarraíl de apertura
-- (nada anterior al 1-oct-2026 postea por puente).
--
-- Ids fijos para que las pruebas los puedan nombrar. Al final se mueven las
-- secuencias de identidad por encima del mayor id, para que un insert sin id
-- no choque.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Personas (uuids fijos; el último grupo dice quién es)
--   …0001 Edgar, dueño, activo
--   …0002 Gustavo, campo, activo       ← "el equipo" en las pruebas
--   …0003 Pedro, campo, INACTIVO       ← ya no trabaja: no debe ver nada
-- ---------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-4000-a000-000000000001', 'edgar@banco.local'),
  ('00000000-0000-4000-a000-000000000002', 'gustavo@banco.local'),
  ('00000000-0000-4000-a000-000000000003', 'pedro@banco.local')
on conflict (id) do nothing;

insert into perfiles (id, nombre, rol, creado, activo, en_grupo) values
  ('00000000-0000-4000-a000-000000000001', 'Edgar',   'dueno', '2026-01-02 09:00-05', true,  true),
  ('00000000-0000-4000-a000-000000000002', 'Gustavo', 'campo', '2026-02-10 09:00-05', true,  true),
  ('00000000-0000-4000-a000-000000000003', 'Pedro',   'campo', '2026-03-15 09:00-05', false, false)
on conflict (id) do nothing;

insert into costos_equipo (usuario_id, costo_hora, actualizado) values
  ('00000000-0000-4000-a000-000000000001', 45.00, '2026-09-01 08:00-04'),
  ('00000000-0000-4000-a000-000000000002', 28.50, '2026-09-01 08:00-04'),
  ('00000000-0000-4000-a000-000000000003', 24.00, '2026-06-01 08:00-04')
on conflict (usuario_id) do nothing;

insert into externos_equipo (id, nombre, costo_hora, activo) values
  (1, 'Luis (ayudante)', 20.00, true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Obras (ids text, con el formato de la app: slug + 4 letras)
-- ---------------------------------------------------------------------
insert into proyectos (id, tipo, nombre, direccion, cliente, estado, fase, estado_detalle, proxima_accion, ref, horas_estimadas) values
  ('casa-perez-k3m9',  'residencial', 'Casa Pérez',   '123 SW 8th St, Miami, FL',    'Familia Pérez', 'ejecucion', 'rough',        'Obra de prueba', 'Seguir rough', 'Por definir', 120),
  ('oficina-nch-7xq2', 'comercial',   'Oficina NCH',  '900 Brickell Ave, Miami, FL', 'NCH Group',     'ejecucion', 'mobilizacion', 'Obra de prueba', 'Pedir panel',  'Por definir', 480)
on conflict (id) do nothing;

insert into finanzas_proyecto (proyecto_id, contrato, cobrado, presupuesto_materiales) values
  ('casa-perez-k3m9',  18500.00, 0, 6000.00),
  ('oficina-nch-7xq2', 64250.00, 0, 22000.00)
on conflict (proyecto_id) do nothing;

insert into hitos (id, proyecto_id, titulo, condicion, monto, estado, orden, es_deposito) values
  (1, 'casa-perez-k3m9',  'Depósito',          'Al firmar',          5000.00, 'cobrado',   0, true),
  (2, 'casa-perez-k3m9',  'Rough aprobado',    'Inspección rough',   8000.00, 'pendiente', 1, false),
  (3, 'oficina-nch-7xq2', 'Movilización',      'Al empezar',         3200.50, 'facturado', 0, false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Los 20 códigos de partida (01-DEMO … 20-MISC).
-- REALES (aparecen en catalogo_items.codigo / docs): 01-DEMO, 03-UG,
--   05-PANEL, 06-FEED, 07-GND, 08-ROUGH, 09-COND, 10-DEV, 11-LIGHT, 13-LV,
--   15-GEN, 20-MISC.
-- INVENTADOS con el mismo formato (el repo no los trae): 02-TEMP, 04-SERV,
--   12-FA, 14-HVAC, 16-SOLAR, 17-EV, 18-SITE, 19-PERMIT.
-- Los nombres y la categoría también son del banco, no de producción.
-- ---------------------------------------------------------------------
insert into codigos_partida (codigo, nombre, nombre_en, categoria) values
  ('01-DEMO',   'Demolición',                    'Demolition',                 'preliminares'),
  ('02-TEMP',   'Luz provisional',               'Temporary power',            'preliminares'),
  ('03-UG',     'Subterráneo',                   'Underground',                'distribucion'),
  ('04-SERV',   'Acometida',                     'Service entrance',           'distribucion'),
  ('05-PANEL',  'Paneles y tableros',            'Panels and switchgear',      'distribucion'),
  ('06-FEED',   'Alimentadores',                 'Feeders',                    'distribucion'),
  ('07-GND',    'Puesta a tierra',               'Grounding',                  'distribucion'),
  ('08-ROUGH',  'Ramales (rough)',               'Branch rough-in',            'ramales'),
  ('09-COND',   'Tubería y accesorios',          'Conduit and fittings',       'ramales'),
  ('10-DEV',    'Dispositivos',                  'Wiring devices',             'acabados'),
  ('11-LIGHT',  'Iluminación',                   'Lighting',                   'acabados'),
  ('12-FA',     'Alarma de incendio',            'Fire alarm',                 'sistemas'),
  ('13-LV',     'Bajo voltaje',                  'Low voltage',                'sistemas'),
  ('14-HVAC',   'Conexión de equipos',           'Equipment connections',      'sistemas'),
  ('15-GEN',    'Generador y ATS',               'Generator and ATS',          'sistemas'),
  ('16-SOLAR',  'Fotovoltaico',                  'Solar PV',                   'sistemas'),
  ('17-EV',     'Cargadores de vehículo',        'EV chargers',                'sistemas'),
  ('18-SITE',   'Iluminación exterior y sitio',  'Site lighting',              'sistemas'),
  ('19-PERMIT', 'Permisos e inspecciones',       'Permits and inspections',    'generales'),
  ('20-MISC',   'Misceláneos y cierre',          'Miscellaneous and closeout', 'generales')
on conflict (codigo) do nothing;

-- ---------------------------------------------------------------------
-- Materiales (para que trg_recibo_marca_material tenga qué marcar)
-- ---------------------------------------------------------------------
insert into materiales (id, proyecto_id, descripcion, cantidad, estado, autor_id, creado, precio) values
  (1, 'casa-perez-k3m9',  'PANEL 200A 40 ESPACIOS', '1',   'falta', '00000000-0000-4000-a000-000000000001', '2026-10-01 08:00-04', 389.0000),
  (2, 'casa-perez-k3m9',  'THHN #12 STRANDED',      '500', 'falta', '00000000-0000-4000-a000-000000000002', '2026-10-01 08:05-04', 0.2726),
  (3, 'oficina-nch-7xq2', 'EMT 1/2 CONDUIT',        '300', 'falta', '00000000-0000-4000-a000-000000000002', '2026-10-02 08:00-04', 0.6124)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Recibos: los tres estados que usa la app (por_leer, leido, anulado),
-- con y sin total. metodo_pago lo llena la lectura del recibo en "cerebro".
-- Producción solo admite 7 categorías (material, labor_externo, permiso,
-- herramienta, combustible, renta_equipo, otro) y 5 formas de pago (debito,
-- credito, cuenta_proveedor, efectivo, zelle): lo dice su CHECK, leído el
-- 24-sep (02b-restricciones-produccion.sql). Aquí van valores distintos de
-- esas listas, y uno nulo con unos últimos 4 que no son de ninguna tarjeta.
-- ---------------------------------------------------------------------
insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, co, fecha, categoria, subtotal, tax, num_recibo, metodo_pago, ultimos4, po_job) values
  -- recién subido desde el teléfono: sin leer, sin total, sin fecha
  (1, 'casa-perez-k3m9',  'recibos/g/0001.jpg', null,     null,        null,                       'por_leer', '00000000-0000-4000-a000-000000000002', '2026-10-02 07:40-04', null, null,         'material', null,    null,  null,      null,          null,   null),
  -- leído, con impuesto, pagado con tarjeta
  (2, 'casa-perez-k3m9',  'recibos/g/0002.jpg', 245.37,   'CED',       'THHN #12 STRANDED 500 ft', 'leido',    '00000000-0000-4000-a000-000000000002', '2026-10-05 10:15-04', null, '2026-10-05', 'material', 229.32,  16.05, 'CED-88121', 'credito',     '4417', 'PEREZ'),
  -- leído, a cuenta del proveedor (vocabulario distinto)
  (3, 'oficina-nch-7xq2', 'recibos/e/0003.jpg', 1288.10,  'Platt',     'EMT y accesorios',         'leido',    '00000000-0000-4000-a000-000000000001', '2026-10-07 13:02-04', null, '2026-10-07', 'material', 1203.83, 84.27, 'PL-55190',  'cuenta_proveedor', null, 'NCH'),
  -- leído, SIN impuesto conocido (tax nulo) y total con 4 decimales (el
  -- repo guarda precios así: el redondeo a centavos es del libro)
  (4, 'oficina-nch-7xq2', 'recibos/g/0004.jpg', 19.9950,  'Home Depot','tornillería',              'leido',    '00000000-0000-4000-a000-000000000002', '2026-10-08 16:20-04', null, '2026-10-08', 'material', null,    null,  'HD-7781',   null,          null,   null),
  -- leído sin forma de pago y con unos últimos 4 que no son de ninguna tarjeta
  (5, 'casa-perez-k3m9',  'recibos/e/0005.jpg', 60.00,    'Shell',     'gasolina camioneta',       'leido',    '00000000-0000-4000-a000-000000000001', '2026-10-09 07:05-04', null, '2026-10-09', 'combustible', 60.00, 0,     null,      null,          '0092', null),
  -- anulado (con total): la app lo usa; contabilizarlo exige un reverso
  (6, 'casa-perez-k3m9',  'recibos/g/0006.jpg', 50.00,    'CED',       'duplicado',                'anulado',  '00000000-0000-4000-a000-000000000002', '2026-10-06 09:00-04', null, '2026-10-06', 'material', 46.73,   3.27,  'CED-88130', 'credito',     '4417', null),
  -- anulado sin total
  (7, 'oficina-nch-7xq2', 'recibos/g/0007.jpg', null,     null,        null,                       'anulado',  '00000000-0000-4000-a000-000000000002', '2026-10-06 09:01-04', null, null,         'material', null,    null,  null,      null,          null,   null),
  -- por leer pero ya con total (lo tecleó alguien)
  (8, 'oficina-nch-7xq2', 'recibos/e/0008.jpg', 412.00,   'Graybar',   null,                       'por_leer', '00000000-0000-4000-a000-000000000001', '2026-10-10 11:30-04', 'CO-1', '2026-10-10', 'material', null,  null,  null,      null,          null,   null),
  -- SEPTIEMBRE: antes de la apertura; el guardarraíl no lo deja postear
  (9, 'casa-perez-k3m9',  'recibos/g/0009.jpg', 310.00,   'CED',       'breakers',                 'leido',    '00000000-0000-4000-a000-000000000002', '2026-09-28 15:00-04', null, '2026-09-28', 'material', 289.72,  20.28, 'CED-87999', 'credito',     '4417', null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Facturas: pagadas y no. cobrado lo pone trg_factura_cobrada.
-- ---------------------------------------------------------------------
insert into facturas (id, proyecto_id, num, fecha, monto, pagada, hito_id, qb_id, cobrada_el, metodo_cobro, a_contratista) values
  (1, 'casa-perez-k3m9',  '1101', '2026-10-03', 5000.00, true,  1,    'QB-1101', '2026-10-06 10:00-04', 'cheque', false),
  (2, 'oficina-nch-7xq2', '1102', '2026-10-12', 3200.50, false, 3,    'QB-1102', null,                  null,     true),
  (3, 'casa-perez-k3m9',  '1103', '2026-10-20', 8000.00, false, 2,    null,      null,                  null,     false),
  -- SEPTIEMBRE, pagada: viene en la balanza de apertura, no por puente
  (4, 'casa-perez-k3m9',  '1098', '2026-09-25', 1500.00, true,  null, 'QB-1098', '2026-09-29 10:00-04', 'zelle',  false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Horas: del dueño y del equipo. Recuerda: horas NO postea dinero.
-- ---------------------------------------------------------------------
insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, creado, correccion_estado, co, llave_cliente) values
  (1, '2026-10-01', '00000000-0000-4000-a000-000000000001', 'casa-perez-k3m9',  'rough',        6.0, 'layout',        '2026-10-01 17:00-04', null,       null, 'k-0001'),
  (2, '2026-10-01', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9',  'rough',        8.0, 'rough cocina',  '2026-10-01 17:05-04', null,       null, 'k-0002'),
  (3, '2026-10-02', '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 'mobilizacion', 7.5, 'descarga',      '2026-10-02 16:30-04', null,       null, 'k-0003'),
  -- con permiso de corrección ya aprobado (un solo uso)
  (4, '2026-10-05', '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 'mobilizacion', 4.0, 'medio día',     '2026-10-05 13:00-04', 'aprobada', null, 'k-0004'),
  (5, '2026-10-06', '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 'rough',        8.0, null,            '2026-10-06 17:00-04', null,       'CO-1', 'k-0005'),
  -- SEPTIEMBRE
  (6, '2026-09-29', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9',  'rough',        8.0, 'antes del corte','2026-09-29 17:00-04', null,      null, 'k-0006'),
  (7, '2026-09-15', '00000000-0000-4000-a000-000000000003', 'casa-perez-k3m9',  'rough',        8.0, 'Pedro, cuando trabajaba', '2026-09-15 17:00-04', null, null, 'k-0007')
on conflict (id) do nothing;

insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, creado, externo_id) values
  (1, 'casa-perez-k3m9',  'Luis — ayudante, demolición 2 días', '2026-10-03', 'ajuste', 16, 320.00, '2026-10-03 18:00-04', 1),
  (2, 'oficina-nch-7xq2', 'Zanja subcontratada',               '2026-09-26', 'ajuste', null, 900.00, '2026-09-26 18:00-04', null)
on conflict (id) do nothing;

insert into pendientes (id, fecha, proyecto_id, descripcion, autor_id, resuelto, creado, prioridad) values
  (1, '2026-10-02', 'casa-perez-k3m9', 'Pedir inspección de rough', '00000000-0000-4000-a000-000000000001', false, '2026-10-02 08:00-04', 'normal')
on conflict (id) do nothing;

insert into asistente_ajustes (clave, valor) values
  ('tope_mes_centavos', '2000'),
  ('aviso_pct', '80')
on conflict (clave) do nothing;

insert into asistente_uso (id, usuario_id, rol, modelo, entrada, salida, creado, accion, resultado, costo_centavos, proyecto_id) values
  (1, '00000000-0000-4000-a000-000000000001', 'dueno', 'modelo-de-prueba', 1200, 300, '2026-10-04 09:00-04', 'leer_recibo', 'ok', 3, 'casa-perez-k3m9')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Las secuencias de identidad, por encima del mayor id sembrado.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  s text;
  m bigint;
begin
  foreach t in array array['facturas','recibos','horas','materiales','trabajos_externos',
                           'externos_equipo','hitos','pendientes','asistente_uso',
                           'alcances','catalogo_items','estimados','gastos_generales']
  loop
    s := pg_get_serial_sequence('public.' || t, 'id');
    execute format('select coalesce(max(id), 0) from public.%I', t) into m;
    if s is not null then
      perform setval(s, greatest(m, 1), m > 0);
    end if;
  end loop;
end $$;
