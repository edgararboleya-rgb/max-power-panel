-- =====================================================================
-- f16-semilla.sql — la base del TABLERO (c16, la portada «Resumen» de
-- Contabilidad): un libro EN USO, de la apertura al 30-sep-2026 a HOY, con
-- algo que enseñar en cada tarjeta. SOLO PARA EL BANCO DE PRUEBAS: NO se
-- pega en Supabase. Todo inventado («ZZ …»): ni un nombre, ni un monto, ni
-- un número de verdad.
--
-- Se pega como editor_sql (el SQL Editor) sobre un clon de g12a (c1…c14):
--   psql -X -q -v ON_ERROR_STOP=1 -U editor_sql -d <bd> -f pruebas/conta/f16-semilla.sql
-- (SIN «-1»: trae sus transacciones; las partes del dueño cambian de rol
-- dentro de la suya). No hace falta c16: la semilla no lo usa.
--
-- «HOY». Todo se fecha del 1-oct-2026 a hoy (en Miami), mes a mes: cuanto
-- más tarde se siembre, más meses trae. Para tener VARIOS MESES sin
-- esperar, se le dice el día:
--   psql … -v hoy=2027-02-12 -f pruebas/conta/f16-semilla.sql
-- y la semilla FINGE EL RELOJ de esa base (como c4-volumen.sh: solo la hora
-- de ahora cae ese día; cualquier otra fecha es la suya) y lo deja así: en
-- esa base «hoy» es ese día (o el de verdad, cuando lo alcance). Sin «-v
-- hoy», el reloj es el de verdad.
--
-- LO QUE SIEMBRA (cada cosa, por el camino de su capa: los puentes de c3,
-- el banco de c6, los cobros en línea de p1…; nada entra al libro a mano
-- por debajo):
--   · 6 obras (2 residenciales, 2 comerciales con retención, 2 de servicio)
--     y la APERTURA al 30-sep por su balanza de QuickBooks (c4): banco,
--     dos facturas de antes que siguen por cobrar (una con retención), una
--     cuenta por pagar VIEJA (de agosto, sin pagar), la camioneta y su
--     préstamo, el capital y el resultado de enero a septiembre;
--   · CADA MES: 6 facturas (unas cobradas enteras, una a medias, una sin
--     cobrar: vencidas de distinta edad), sus cobros por cheque y Zelle,
--     un anticipo; tickets con las dos tarjetas (material, combustible,
--     herramienta, renta de equipo), un permiso, recibos a cuenta de un supply y sus
--     pagos (uno se queda sin pagar), trabajos de un sub y su pago, la
--     renta, el seguro, el teléfono, el software, la publicidad, los
--     cargos del banco, la nómina de cada quincena, el use tax de dos
--     compras y su pago, el pago de las tarjetas y la CUOTA DEL PRÉSTAMO;
--   · EL BANCO (c6): lo que trae Plaid de Chase y de la Amex, casado con
--     el libro, y movimientos POR REVISAR en la Bandeja (recientes y uno
--     viejo, de más de 30 días); octubre conciliado;
--   · PLAID (c7): una conexión al día y otra que pide volver a conectar;
--   · STRIPE (p1): un cobro con tarjeta ya depositado en Chase, otro
--     cobrado que falta depositar y uno por cuenta de banco en camino;
--   · FACTURAS POR LA APP (c11): una emitida hoy, que todavía no vence;
--   · EL WIP (c12) de octubre posteado, y el costo por obra (c10) con lo
--     que el libro trae.
-- Lo que deja a propósito en la bandeja de los puentes: los papeles de la
-- semilla de siempre que esperan una regla o un dato (un ticket sin forma
-- de pago, uno con una tarjeta que no existe).
-- =====================================================================
\set ON_ERROR_STOP 1
\set QUIET 1
\set dueno '00000000-0000-4000-a000-000000000001'
\set gus   '00000000-0000-4000-a000-000000000002'
select set_config('mxp.cierre_sin_push', '1', false) \gset
select set_config('mxp.stripe_sin_push', '1', false) \gset
select set_config('c4.control_tope', '0', false) \gset

-- ===== 0. «Hoy»: el de verdad, o el que se diga (-v hoy=AAAA-MM-DD) =====
\if :{?hoy}
select format($f$
  create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable
  set search_path = public, pg_temp as $b$
    select case when t between now() - interval '6 hours' and now() + interval '6 hours'
                then greatest((t at time zone 'America/New_York')::date, date %L)
                else (t at time zone 'America/New_York')::date end $b$
$f$, :'hoy'::date) as fingir \gset
:fingir;
-- (el reloj fingido cambió fn_fecha_miami: se vuelven a sellar las huellas de c2; en producción nadie la cambia)
select fn_libro_huellas_sellar('f16-semilla.sql: el reloj del banco de pruebas en ' || :'hoy') is not null as sellado \gset
\endif
select fn_fecha_miami(now()) as hoy \gset
select set_config('f16.hoy', :'hoy', false) \gset
select set_config('f16.dueno', :'dueno', false) \gset

-- ===== 1. el SQL Editor: los nombres («ZZ»), las obras, las reglas, los proveedores, las tarjetas =====
begin;
update perfiles set nombre = 'Zzeli ZZ' where id = :'gus';
update perfiles set nombre = 'Zzpedro ZZ' where id = '00000000-0000-4000-a000-000000000003';
update proyectos set nombre = 'ZZ Casa Uno', cliente = 'ZZ Cliente Casa', direccion = '1 ZZ St, Ocala, FL' where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Dos', cliente = 'ZZ Cliente Oficina', direccion = '2 ZZ Ave, Ocala, FL' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres', cliente = 'ZZ Cliente Taller', direccion = '3 ZZ Rd, Ocala, FL' where id = 'taller-ruiz-5b2n';
insert into proyectos (id, tipo, nombre, direccion, cliente, estado, fase, estado_detalle, proxima_accion, ref, horas_estimadas) values
  ('zz-nave-cuatro-a1b2',  'comercial',   'ZZ Nave Cuatro',  '4 ZZ Blvd, Ocala, FL', 'ZZ Cliente Nave',     'ejecucion', 'rough', 'Obra de la semilla', 'Seguir', 'Por definir', 300),
  ('zz-casa-cinco-c3d4',   'residencial', 'ZZ Casa Cinco',   '5 ZZ Ln, Ocala, FL',   'ZZ Cliente Cinco',    'ejecucion', 'trim',  'Obra de la semilla', 'Seguir', 'Por definir', 80),
  ('zz-servicio-seis-e5f6','servicio',    'ZZ Servicio Seis','6 ZZ Way, Ocala, FL',  'ZZ Cliente Servicio', 'ejecucion', 'trim',  'Obra de la semilla', 'Seguir', 'Por definir', 12)
on conflict (id) do nothing;
insert into finanzas_proyecto (proyecto_id, contrato, cobrado, presupuesto_materiales) values
  ('zz-nave-cuatro-a1b2', 42000.00, 0, 15000.00),
  ('zz-casa-cinco-c3d4',   9800.00, 0,  3200.00)
on conflict (proyecto_id) do nothing;
select fn_mapeo_confirmar('tipo_proyecto') as reglas_tipo \gset
select fn_mapeo_confirmar('categoria') as reglas_categoria \gset
select fn_mapeo_confirmar('metodo_pago') as reglas_pago \gset
select fn_proveedor_alta('ZZ SUPPLY UNO', 'Net 30', array['zz supply uno', 'zz supply uno inc']) is not null as ok \gset
select fn_proveedor_alta('ZZ SUPPLY DOS', 'Net 15', array['zz supply dos']) is not null as ok \gset
select fn_proveedor_alta('ZZ SUB ZANJAS', 'Net 15', array['zz sub zanjas']) is not null as ok \gset
select fn_tarjeta_alta('2009', '2100-2009', 'ZZ Blue') is not null as ok \gset
commit;

-- ===== 2. el SQL Editor: la APERTURA al 30-sep por su balanza de QuickBooks (c4) =====
begin;
-- (las dos facturas de QuickBooks que siguen por cobrar al 30-sep, una con retención)
insert into facturas (proyecto_id, num, fecha, monto, retencion) values
  ('oficina-nch-7xq2', 'ZZ-QB-901', '2026-08-18', 4200.00, 420.00),
  ('casa-perez-k3m9',  'ZZ-QB-902', '2026-09-22', 2750.00, 0);
select fn_apertura_mapeo_trabajo('ZZ Cliente Oficina:ZZ Oficina Dos', 'oficina-nch-7xq2') is not null as ok \gset
select fn_apertura_mapeo_trabajo('ZZ Cliente Casa:ZZ Casa Uno', 'casa-perez-k3m9') is not null as ok \gset
select fn_apertura_balanza_cargar('docs/apertura/zz-f16.csv', jsonb_build_array(
    jsonb_build_object('cuenta_qb', 'ZZ Checking', 'debe', '41250.75'),
    jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'debe', '4200.00', 'factura_num', 'ZZ-QB-901', 'retencion', '420.00',
                       'cliente_trabajo', 'ZZ Cliente Oficina:ZZ Oficina Dos'),
    jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'debe', '2750.00', 'factura_num', 'ZZ-QB-902',
                       'cliente_trabajo', 'ZZ Cliente Casa:ZZ Casa Uno'),
    jsonb_build_object('cuenta_qb', 'Vehicles', 'debe', '38000.00'),
    jsonb_build_object('cuenta_qb', 'Accumulated Depreciation', 'haber', '9500.00'),
    -- (la cuenta por pagar VIEJA: una factura de agosto del supply, que sigue sin pagar)
    jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '3180.40', 'proveedor_qb', 'ZZ Supply Uno Inc',
                       'fecha_documento', '2026-08-10', 'vence', '2026-09-09', 'referencia', 'ZZ-B-77'),
    jsonb_build_object('cuenta_qb', 'Credit Cards:ZZ Blue 2009', 'haber', '640.00'),
    jsonb_build_object('cuenta_qb', 'Credit Cards:ZZ Gold 1007', 'haber', '1150.00'),
    jsonb_build_object('cuenta_qb', 'ZZ Truck Loan', 'haber', '24000.00'),
    jsonb_build_object('cuenta_qb', 'Common Stock', 'haber', '1000.00'),
    jsonb_build_object('cuenta_qb', 'Retained Earnings', 'haber', '4830.35'),
    jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '310000.00'),
    jsonb_build_object('cuenta_qb', 'Job Materials', 'debe', '148000.00'),
    jsonb_build_object('cuenta_qb', 'Payroll Expenses', 'debe', '96500.00'),
    jsonb_build_object('cuenta_qb', 'Rent Expense', 'debe', '16200.00'),
    jsonb_build_object('cuenta_qb', 'Insurance Expense', 'debe', '7400.00'),
    -- su control de QuickBooks (el Balance Sheet al 30-sep)
    jsonb_build_object('cuenta_qb', 'Net Income', 'haber', '41900.00'),
    jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'debe', '76700.75'),
    jsonb_build_object('cuenta_qb', 'Total Liabilities', 'haber', '28970.40'))) is not null as ok \gset
select count(fn_apertura_mapeo_qb(x.n, x.c)) as mapeos
  from (values ('ZZ Checking', '1010'), ('Accounts Receivable', '1110'), ('Vehicles', '1510'), ('Accumulated Depreciation', '1590'),
               ('Accounts Payable', '2010'), ('Credit Cards:ZZ Blue 2009', '2100-2009'), ('Credit Cards:ZZ Gold 1007', '2100-2013'),
               ('ZZ Truck Loan', '2530'), ('Common Stock', '3000'), ('Retained Earnings', '3900'), ('Construction Income', '4010'),
               ('Job Materials', '5100'), ('Payroll Expenses', '5000'), ('Rent Expense', '6100'), ('Insurance Expense', '6200')) x(n, c) \gset
select fn_apertura('2026-09-30', 'docs/apertura/zz-f16.csv') is not null as ok \gset
-- (el préstamo de la camioneta: venía de antes; lo que se debía al 30-sep, lo de la balanza)
select fn_prestamo_guardar('{"prestamista": "ZZ AUTO FIN", "descripcion": "camioneta ZZ", "principal": "36000.00", "tasa_anual": "6.5",
  "cuota": "705.00", "primer_pago": "2025-03-03", "dia_pago": 3, "plazo_meses": 60, "saldo_inicial": "24000.00",
  "saldo_inicial_al": "2026-09-30", "descriptor": "ZZ AUTO FIN"}') is not null as ok \gset
commit;

-- ===== 3. el SQL Editor: los papeles de la semilla de siempre entran (sus reglas ya están confirmadas) =====
begin;
select fn_puentes_correr() is not null as ok \gset
commit;

-- ===== 4. CADA MES, del 1-oct-2026 a hoy: lo que la empresa hace, por el camino de cada capa =====
-- (los puentes de c3 contabilizan cada papel al insertarlo, como en sus pruebas; fn_postear y los cobros, como el SQL Editor)
create temp table _zz_nomina (id text primary key, fecha date, neto numeric, lineas jsonb);
begin;
do $$
declare
  hoy    date := current_setting('f16.hoy')::date;
  dueno  uuid := current_setting('f16.dueno')::uuid;
  obras  text[] := array['casa-perez-k3m9', 'oficina-nch-7xq2', 'taller-ruiz-5b2n', 'zz-nave-cuatro-a1b2', 'zz-casa-cinco-c3d4',
                         'zz-servicio-seis-e5f6'];
  con_ret text[] := array['oficina-nch-7xq2', 'zz-nave-cuatro-a1b2'];
  sup1   uuid := (select id from proveedores where nombre = 'ZZ SUPPLY UNO');
  subz   uuid := (select id from proveedores where nombre = 'ZZ SUB ZANJAS');
  pres   uuid := (select id from prestamos where prestamista = 'ZZ AUTO FIN');
  d0 date; d1 date; mi int := 0; tag text; g int; f date; fc date; m numeric; r numeric; k int; o text; fid bigint; rid bigint; xid bigint;
  t numeric; tx numeric; v_c uuid; lin jsonb; s numeric;
begin
  execute 'set constraints trg_puente_recibos_despues, trg_puente_externos_despues, trg_puente_facturas_despues immediate';
  for d0 in select generate_series(date '2026-10-01', date_trunc('month', hoy)::date, interval '1 month')::date loop
    d1 := least((d0 + interval '1 month')::date - 1, hoy); tag := to_char(d0, 'YYMM');

    -- LAS FACTURAS del mes (seis; las de las obras comerciales, con su 10 % de retención) y SUS COBROS (si ya tocaban)
    for g in 1..6 loop
      f := d0 + (array[2, 6, 11, 15, 20, 25])[g];
      continue when f > hoy;
      o := obras[1 + (g + mi) % 6];
      m := round((1400 + ((g * 1373 + mi * 811) % 6200) + ((g * 37 + mi * 13) % 100) / 100.0)::numeric, 2);
      r := case when o = any (con_ret) then round(m * 0.10, 2) else 0 end;
      insert into facturas (proyecto_id, num, fecha, monto, retencion) values (o, 'ZZ-' || tag || '-' || g, f, m, r) returning id into fid;
      k := (g + mi) % 6;
      fc := f + (array[0, 19, 23, 12, 27, 16])[k + 1];
      if k <> 0 and fc <= hoy then
        -- k: 1 y 5, entera por cheque; 2, A MEDIAS por Zelle; 3, entera por Zelle; 4, entera por cheque (lo de la retención se queda)
        t := case when k = 2 then round((m - r) / 2, 2) else m - r end;
        perform fn_cobro_registrar(jsonb_build_object('fecha', fc::text, 'monto', t::text, 'cuenta', '1010',
          'medio', case when k in (2, 3) then 'zelle' else 'cheque' end, 'referencia', 'ZZ-C-' || tag || '-' || g,
          'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', fid, 'monto', t::text))));
      end if;
    end loop;
    -- (un anticipo de una obra de servicio, sin factura todavía: se queda a favor del cliente)
    if mi = 0 and d0 + 9 <= hoy then
      perform fn_cobro_registrar(jsonb_build_object('fecha', (d0 + 9)::text, 'monto', '600.00', 'cuenta', '1010', 'medio', 'zelle',
        'referencia', 'ZZ-ANT-1', 'proyecto_id', 'zz-servicio-seis-e5f6',
        'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', 'zz-servicio-seis-e5f6', 'monto', '600.00'))));
    end if;

    -- LOS TICKETS con las dos tarjetas: material (con su tax), combustible, herramienta y renta de equipo
    for g in 1..5 loop
      f := d0 + (array[3, 9, 14, 19, 24])[g];
      continue when f > hoy;
      t := round((40 + ((g * 97 + mi * 53) % 480) + ((g * 29 + mi * 7) % 100) / 100.0)::numeric, 2);
      tx := round(t * 0.07 / 1.07, 2);
      insert into recibos (proyecto_id, ruta, total, subtotal, tax, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago,
                           ultimos4, num_recibo)
      values (case when g in (1, 2, 5) then obras[1 + (g + mi) % 6] end, 'recibos/zz/' || tag || '/t' || g || '.jpg', t, t - tx, tx,
              (array['ZZ Depot', 'ZZ Depot', 'ZZ Gasolinera', 'ZZ Ferretera', 'ZZ Rentas'])[g], 'leido', dueno,
              (f + time '12:00') at time zone 'America/New_York', f,
              (array['material', 'material', 'combustible', 'herramienta', 'renta_equipo'])[g], 'credito',
              case when g % 2 = 1 then '2009' else '1007' end, 'ZZ-T-' || tag || '-' || g);
    end loop;
    -- LOS RECIBOS A CUENTA del supply (Net 30) y SU PAGO al mes siguiente (el tercero de cada mes se queda sin pagar)
    for g in 1..3 loop
      f := d0 + (array[4, 13, 22])[g];
      continue when f > hoy;
      t := round((350 + ((g * 211 + mi * 97) % 1900) + ((g * 17 + mi * 31) % 100) / 100.0)::numeric, 2);
      insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, num_recibo)
      values (obras[1 + (g + mi + 2) % 6], 'recibos/zz/' || tag || '/c' || g || '.jpg', t, 'ZZ Supply Uno Inc', 'leido', dueno,
              (f + time '12:00') at time zone 'America/New_York', f, 'material', 'cuenta_proveedor', 'ZZ-S-' || tag || '-' || g)
      returning id into rid;
      if g < 3 and f + 30 <= hoy then
        perform fn_postear(jsonb_build_object('fecha', (f + 30)::text, 'descripcion', 'ZZ: pago al supply, recibo ZZ-S-' || tag || '-' || g,
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', t::text, 'tercero_tipo', 'proveedor',
                                                         'tercero_id', sup1::text, 'partida_tabla', 'recibos', 'partida_id', rid::text),
                                      jsonb_build_object('cuenta', '1010', 'monto', (-t)::text))));
      end if;
    end loop;
    -- UN PERMISO pagado por Zelle (sale del banco)
    if d0 + 7 <= hoy then
      insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, num_recibo)
      values (obras[1 + mi % 6], 'recibos/zz/' || tag || '/p1.jpg', 185.00 + mi, 'ZZ Condado', 'leido', dueno,
              ((d0 + 7) + time '12:00') at time zone 'America/New_York', d0 + 7, 'permiso', 'zelle', 'ZZ-P-' || tag);
    end if;
    -- LOS TRABAJOS DEL SUB (5200 contra 2010, cada uno con su partida) y su pago a los 15 días
    for g in 1..2 loop
      f := d0 + (array[8, 18])[g];
      continue when f > hoy;
      t := round((900 + ((mi * 311 + g * 127) % 1500))::numeric, 2);
      insert into trabajos_externos (proyecto_id, descripcion, fecha, tipo, costo, proveedor_id, creado)
      values (obras[1 + (g + mi + 3) % 6], 'ZZ zanja ' || tag || '-' || g, f, 'ajuste', t, subz,
              (f + time '12:00') at time zone 'America/New_York')
      returning id into xid;
      if f + 15 <= hoy then
        perform fn_postear(jsonb_build_object('fecha', (f + 15)::text, 'descripcion', 'ZZ: pago al sub, zanja ' || tag || '-' || g,
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', t::text, 'tercero_tipo', 'proveedor',
                                                         'tercero_id', subz::text, 'partida_tabla', 'trabajos_externos',
                                                         'partida_id', xid::text),
                                      jsonb_build_object('cuenta', '1010', 'monto', (-t)::text))));
      end if;
    end loop;

    -- LOS GASTOS QUE SALEN DEL BANCO: renta, seguro, teléfono, software, profesionales (un mes sí y otro no), publicidad, cargos
    for g in 1..7 loop
      f := d0 + (array[0, 4, 8, 11, 14, 19, 27])[g];
      continue when f > hoy or (g = 5 and mi % 2 = 1);
      t := (array[1850.00, 412.37, 189.44 + mi, 96.20, 350.00, 120.00 + mi * 5, 25.00])[g];
      perform fn_postear(jsonb_build_object('fecha', f::text,
        'descripcion', 'ZZ: ' || (array['renta del local', 'seguro GL', 'teléfono y datos', 'software', 'CPA', 'publicidad', 'cargo del banco'])[g],
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', (array['6100', '6200', '6120', '6500', '6600', '6700', '6130'])[g],
                                                       'monto', t::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-t)::text))));
    end loop;
    -- LA NÓMINA de cada quincena (mano de obra de dos obras, el sueldo de oficina y lo retenido) NO se postea a mano: entra con su
    -- débito del banco por el journal del proveedor de nómina (fn_banco_nomina de c6, en 6): aquí solo se apunta la corrida
    for g in 1..2 loop
      f := d0 + (array[9, 23])[g];
      continue when f >= hoy;
      t := round((1650 + ((mi * 173 + g * 59) % 600))::numeric, 2);
      insert into _zz_nomina values ('zz-nom-' || tag || '-' || g, f, 2 * t + 400 - round((2 * t + 400) * 0.18, 2), jsonb_build_array(
        jsonb_build_object('cuenta', '5000', 'monto', t::text, 'proyecto_id', obras[1 + (g + mi) % 6], 'memo', 'ZZ sueldos de obra'),
        jsonb_build_object('cuenta', '5000', 'monto', (t - 400)::text, 'proyecto_id', obras[1 + (g + mi + 1) % 6], 'memo', 'ZZ sueldos de obra'),
        jsonb_build_object('cuenta', '6000', 'monto', '800.00', 'memo', 'ZZ sueldo de oficina'),
        jsonb_build_object('cuenta', '2220', 'monto', (-round((2 * t + 400) * 0.18, 2))::text, 'memo', 'ZZ retenciones')));
    end loop;
    -- (y el depósito de lo retenido en las corridas del mes anterior)
    if mi > 0 and d0 + 14 <= hoy then
      s := (select coalesce(-sum((x->>'monto')::numeric), 0) from _zz_nomina n, jsonb_array_elements(n.lineas) x
             where x->>'cuenta' = '2220' and n.fecha >= (d0 - interval '1 month')::date and n.fecha < d0);
      if s > 0 then
        perform fn_postear(jsonb_build_object('fecha', (d0 + 14)::text, 'descripcion', 'ZZ: depósito de lo retenido de la nómina',
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2220', 'monto', s::text),
                                      jsonb_build_object('cuenta', '1010', 'monto', (-s)::text))));
      end if;
    end if;
    -- EL USE TAX de dos compras del mes (a la 2300), y el pago al DOR del mes anterior
    for g in 1..2 loop
      f := d0 + (array[5, 16])[g];
      continue when f > hoy;
      t := (array[14.35, 22.80])[g] + mi;
      perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'ZZ: use tax de una compra sin impuesto',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', t::text, 'proyecto_id', obras[1 + (g + mi) % 6]),
                                    jsonb_build_object('cuenta', '2300', 'monto', (-t)::text))));
    end loop;
    if mi > 0 and d0 + 19 <= hoy then
      s := (select coalesce(-sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
             where l.cuenta = '2300' and a.fecha_contable < d0);
      if s > 0 then
        perform fn_postear(jsonb_build_object('fecha', (d0 + 19)::text, 'descripcion', 'ZZ: pago del DR-15 al DOR',
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2300', 'monto', s::text),
                                      jsonb_build_object('cuenta', '1010', 'monto', (-s)::text))));
      end if;
    end if;
    -- EL PAGO DE CADA TARJETA (lo que debía al terminar el mes anterior), el día 20
    if d0 + 20 <= hoy then
      for o in select x.c from (values ('2100-2009'), ('2100-2013')) x(c) loop
        s := (select coalesce(-sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
               where l.cuenta = o and a.fecha_contable < d0);
        if s > 0 then
          perform fn_postear(jsonb_build_object('fecha', (d0 + 20)::text, 'descripcion', 'ZZ: pago de la tarjeta ' || o,
            'lineas', jsonb_build_array(jsonb_build_object('cuenta', o, 'monto', s::text),
                                        jsonb_build_object('cuenta', '1010', 'monto', (-s)::text))));
        end if;
      end loop;
    end if;
    -- LA CUOTA DEL PRÉSTAMO, el día 3 (la fórmula la parte en capital e interés)
    if d0 + 2 <= hoy then
      perform fn_prestamo_cuota(pres, null, d0 + 2, '705.00');
    end if;
    -- UNA DISTRIBUCIÓN al accionista, el 27
    if d0 + 26 <= hoy then
      perform fn_postear(jsonb_build_object('fecha', (d0 + 26)::text, 'descripcion', 'ZZ: distribución al accionista',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200', 'monto', '2000.00'),
                                    jsonb_build_object('cuenta', '1010', 'monto', '-2000.00'))));
    end if;
    mi := mi + 1;
  end loop;
end $$;
commit;

-- ===== 5. STRIPE (p1): un cobro con tarjeta ya depositado en el banco, otro cobrado que falta depositar y uno por cuenta de banco en camino =====
-- (como la función de borde, que entra como postgres: aquí, el SQL Editor. Las «fotos» son las que le daría Stripe, inventadas)
begin;
update stripe_config set acepta_prueba = true, modo = 'prueba' where id = 1;
set constraints trg_puente_facturas_despues immediate;
insert into facturas (proyecto_id, num, fecha, monto, retencion) values
  ('zz-casa-cinco-c3d4',    'ZZ-ST-1', greatest(:'hoy'::date - 9, date '2026-10-01'), 1250.00, 0),
  ('zz-servicio-seis-e5f6', 'ZZ-ST-2', greatest(:'hoy'::date - 4, date '2026-10-01'),  860.00, 0),
  ('casa-perez-k3m9',       'ZZ-ST-3', greatest(:'hoy'::date - 3, date '2026-10-01'), 2100.00, 0);
-- la foto de un pago (centavos) y la de un depósito con sus líneas, como las de p1-pruebas.sql
create function pg_temp.zz_foto(p_pi text, p_estado text, p_centavos bigint, p_medio text, p_fecha date) returns jsonb language sql as $f$
  select jsonb_build_object(
    'pi', p_pi, 'visto_el', clock_timestamp(), 'estado', p_estado, 'monto', p_centavos,
    'recibido', case when p_estado = 'succeeded' then p_centavos else 0 end, 'moneda', 'usd', 'livemode', false,
    'creado', extract(epoch from now())::bigint,
    'metadata', (select jsonb_build_object('mxp', 'p1', 'enlace', e.id::text, 'factura_id', e.factura_id::text, 'factura', e.factura_num,
                                           'retencion', case when e.con_retencion then 'si' else 'no' end)
                   from stripe_enlaces e where e.plink = 'plink_' || substr(p_pi, 4)),
    'plink', 'plink_' || substr(p_pi, 4), 'sesion', 'cs_' || substr(p_pi, 4), 'sesion_completa', true, 'medio', p_medio,
    'cargo', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
    'fecha_exito', case when p_estado = 'succeeded' then p_fecha::text end,
    'cargos', jsonb_build_array(jsonb_build_object('id', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
                'estado', case p_estado when 'succeeded' then 'succeeded' else 'pending' end, 'medio', p_medio, 'bt', 'txn_' || p_pi,
                'creado', extract(epoch from now())::bigint, 'monto', p_centavos)),
    'reembolsos', '[]'::jsonb, 'disputas', '[]'::jsonb, 'ultimo_error', null::jsonb)
$f$;
create function pg_temp.zz_enlace(p_num text, p_pi text) returns uuid language plpgsql as $f$
declare v jsonb;
begin
  v := fn_stripe_enlace_preparar((select id from facturas where num = p_num), current_setting('f16.dueno')::uuid, 'prueba', false, false);
  perform fn_stripe_enlace_creado((v->>'enlace')::uuid, jsonb_build_object('id', 'plink_' || substr(p_pi, 4),
            'url', 'https://buy.stripe.com/test_zz' || substr(p_pi, 4), 'livemode', false, 'metadata', v->'metadata'));
  return (v->>'enlace')::uuid;
end $f$;
select pg_temp.zz_enlace('ZZ-ST-1', 'pi_ZZF16A') is not null as ok \gset
select pg_temp.zz_enlace('ZZ-ST-2', 'pi_ZZF16B') is not null as ok \gset
select pg_temp.zz_enlace('ZZ-ST-3', 'pi_ZZF16C') is not null as ok \gset
select fn_stripe_pago_sincronizar(pg_temp.zz_foto('pi_ZZF16A', 'succeeded', 125000, 'tarjeta', greatest(:'hoy'::date - 8, date '2026-10-01')), 'evt_ZZF16A') is not null as ok \gset
select fn_stripe_pago_sincronizar(pg_temp.zz_foto('pi_ZZF16B', 'succeeded', 86000, 'tarjeta', greatest(:'hoy'::date - 2, date '2026-10-01')), 'evt_ZZF16B') is not null as ok \gset
select fn_stripe_pago_sincronizar(pg_temp.zz_foto('pi_ZZF16C', 'processing', 210000, 'ach', null), 'evt_ZZF16C') is not null as ok \gset
-- el depósito de Stripe al banco con el primer cobro (1,250.00 menos 36.55 de comisión), que llegó hace cinco días
select fn_stripe_payout_sincronizar(
  jsonb_build_object('po', 'po_ZZF16A', 'visto_el', clock_timestamp(), 'estado', 'paid', 'monto', 121345, 'moneda', 'usd',
                     'llegada', greatest(:'hoy'::date - 5, date '2026-10-02')::text, 'automatico', true, 'metodo', 'standard',
                     'conciliacion', 'completed', 'bt_propio', 'txn_po_ZZF16A', 'bt_fallo', null, 'fallo_codigo', null,
                     'creado', ceil(extract(epoch from now()))::bigint),
  jsonb_build_array(
    jsonb_build_object('txn', 'txn_pi_ZZF16A', 'tipo', 'charge', 'categoria', 'charge', 'monto', 125000, 'comision', 3655, 'neto', 121345,
                       'fuente', 'ch_ZZF16A', 'pi', 'pi_ZZF16A', 'creado', extract(epoch from now())::bigint),
    jsonb_build_object('txn', 'txn_po_ZZF16A', 'tipo', 'payout', 'categoria', 'payout', 'monto', -121345, 'comision', 0, 'neto', -121345,
                       'fuente', 'po_ZZF16A', 'creado', extract(epoch from now())::bigint)),
  'evt_ZZF16P') is not null as ok \gset
commit;

-- ===== 6. EL BANCO (c6) por PLAID (c7): lo que el banco trae de Chase y de la Amex Gold, casado, y lo que queda POR REVISAR =====
-- (la función de borde entra como postgres —aquí, el SQL Editor— y fn_plaid_recibir importa y casa en nombre del dueño)
begin;
select fn_plaid_item_alta('item-zz-f16-uno', 'access-zz-f16-uno', 'ins_zz1', 'ZZ Banco Uno', jsonb_build_array(
    jsonb_build_object('account_id', 'acc-zz-corriente', 'mask', '4001', 'nombre', 'ZZ Business Checking', 'oficial', 'ZZ Checking', 'tipo', 'depository', 'subtipo', 'checking'),
    jsonb_build_object('account_id', 'acc-zz-gold', 'mask', '1007', 'nombre', 'ZZ Gold Card', 'oficial', 'ZZ Gold', 'tipo', 'credit', 'subtipo', 'credit card')),
  :'dueno'::uuid) is not null as ok \gset
select fn_plaid_cuenta_fijar('item-zz-f16-uno', 'acc-zz-corriente', '1010') is not null as ok \gset
select fn_plaid_cuenta_fijar('item-zz-f16-uno', 'acc-zz-gold', '2100-2013') is not null as ok \gset
-- (lo del libro que el banco ya trae: todo lo de las dos cuentas hasta ayer, menos los cheques de los dos últimos días, que siguen en
--  tránsito; y lo que el banco trae y el libro no tiene todavía: la Bandeja)
create temp table _zz_banco on commit drop as
select l.cuenta, 'zz-' || a.numero || '-' || l.orden as id, a.fecha_contable as fecha, l.monto,
       case when a.procedencia ? 'payout' then 'ORIG CO NAME:STRIPE CO ENTRY DESCR:TRANSFER SEC:CCD IND ID:ST-ZZ' || right(a.numero, 4)
            when a.origen_tabla = 'cobros' and a.descripcion ~* 'cheque' then 'DEPOSIT ID NUMBER ' || right(a.numero, 4)
            when a.origen_tabla = 'cobros' then 'Zelle payment from ZZ CLIENTE ' || right(a.numero, 3)
            when a.origen_tabla = 'prestamo_cuotas' then 'ZZ AUTO FIN PAYMENT ' || right(a.numero, 3)
            when a.origen_tabla = 'recibos' and l.cuenta = '1010' then 'Zelle payment to ZZ CONDADO ' || right(a.numero, 3)
            when a.origen_tabla = 'recibos' then upper(coalesce((select rc.proveedor from recibos rc where rc.id::text = a.origen_id), 'ZZ COMERCIO')) || ' #' || right(a.numero, 3)
            when l.cuenta like '2100-%' then 'PAYMENT RECEIVED - THANK YOU'
            when a.descripcion ~ 'tarjeta 2100-2013' then 'ZZ GOLD CARD EPAYMENT ' || right(a.numero, 3)
            else upper(regexp_replace(a.descripcion, '^ZZ: ', 'ZZ ')) || ' ' || right(a.numero, 3) end as descripcion,
       case when l.monto > 0 then 'CREDIT' else 'DEBIT' end as tipo
  from asiento_lineas l join asientos a on a.id = l.asiento_id
 where l.cuenta in ('1010', '2100-2013') and a.tipo <> 'apertura' and a.fecha_contable < :'hoy'::date
   and not (a.origen_tabla = 'cobros' and a.descripcion ~* 'cheque' and a.fecha_contable >= :'hoy'::date - 2);
insert into _zz_banco values
  ('2100-2013', 'zz-pend-1', greatest(date '2026-10-06', :'hoy'::date - 37), -64.18, 'ZZ CARGO DESCONOCIDO 4471', 'DEBIT'),
  ('1010', 'zz-pend-2', :'hoy'::date - 8,  -212.40, 'ZZ HARDWARE STORE 55', 'DEBIT'),
  ('1010', 'zz-pend-3', :'hoy'::date - 5,   -58.90, 'ZZ GAS STATION 12', 'DEBIT'),
  ('1010', 'zz-pend-4', :'hoy'::date - 3, -1430.00, 'Zelle payment to ZZ ELECTRICISTA', 'DEBIT'),
  ('1010', 'zz-pend-5', :'hoy'::date - 2,   -89.99, 'ZZ SOFTWARE SUBSCRIPTION', 'DEBIT'),
  ('1010', 'zz-pend-6', :'hoy'::date - 4,  2300.00, 'DEPOSIT ID NUMBER 7741', 'CREDIT'),
  ('1010', 'zz-pend-7', :'hoy'::date - 1,   750.00, 'Zelle payment from ZZ CLIENTE CINCO', 'CREDIT'),
  ('2100-2013', 'zz-pend-8', :'hoy'::date - 6, -143.27, 'ZZ DEPOT 0101', 'DEBIT'),
  ('2100-2013', 'zz-pend-9', :'hoy'::date - 2,  -37.61, 'ZZ GASOLINERA 7', 'DEBIT');
-- (y el débito de cada corrida de nómina, que todavía no está en el libro: entra abajo con su journal)
insert into _zz_banco select '1010', n.id, n.fecha, -n.neto, 'ZZ PAYROLL SERVICE ' || right(n.id, 6), 'DEBIT' from _zz_nomina n;
select fn_plaid_recibir('item-zz-f16-uno', (
  select jsonb_agg(jsonb_build_object(
           'origen', 'plaid', 'cuenta', c.cuenta, 'nombre', 'Plaid · ZZ Banco Uno · ' || c.cuenta,
           -- el saldo que da el banco: el de la apertura más todo lo que trae (en la tarjeta, lo que se debe, en positivo)
           'plaid_saldo', (case when c.cuenta = '1010' then 1 else -1 end
                           * ((select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                where l.cuenta = c.cuenta and a.tipo = 'apertura')
                              + (select sum(b.monto) from _zz_banco b where b.cuenta = c.cuenta)))::text,
           'saldo_al', :'hoy',
           'filas', (select jsonb_agg(jsonb_build_object('id', b.id, 'fecha', b.fecha::text, 'plaid_monto', (-b.monto)::text,
                                                         'descripcion', b.descripcion, 'tipo', b.tipo, 'pendiente', false)
                                      order by b.fecha, b.id)
                       from _zz_banco b where b.cuenta = c.cuenta)))
    from (values ('1010'), ('2100-2013')) c(cuenta)), 'cursor-zz-1', '{"por": "f16-semilla"}') is not null as ok \gset
-- (el journal de cada corrida de nómina, con su débito del banco: la única puerta de la mano de obra al libro antes de Gusto)
select count(fn_banco_nomina(m.id, n.lineas, 'ZZ: el journal de la corrida')) as nominas
  from _zz_nomina n join movimientos_banco m on m.id_externo = n.id \gset
-- (otra conexión, que pide volver a entrar al banco: «con problemas»)
select fn_plaid_item_alta('item-zz-f16-dos', 'access-zz-f16-dos', 'ins_zz2', 'ZZ Banco Dos', jsonb_build_array(
    jsonb_build_object('account_id', 'acc-zz-blue', 'mask', '2009', 'nombre', 'ZZ Blue Card', 'oficial', 'ZZ Blue', 'tipo', 'credit', 'subtipo', 'credit card')),
  :'dueno'::uuid) is not null as ok \gset
select fn_plaid_cuenta_fijar('item-zz-f16-dos', 'acc-zz-blue', '2100-2009') is not null as ok \gset
select fn_plaid_error('item-zz-f16-dos', 'ITEM_LOGIN_REQUIRED: el banco pide volver a entrar') is not null as ok \gset
commit;

-- ===== 7. el dueño: confirma los cruces que el banco deja «por confirmar» y concilia el banco en cada mes ya terminado =====
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
-- (el pago de la tarjeta y la distribución: el banco los nombra de otra forma y espera a que Edgar diga «es este asiento»)
select count(fn_banco_casar_con(m.id, jsonb_build_object('lineas', jsonb_build_array(jsonb_build_object(
         'asiento_id', a.id, 'orden', split_part(m.id_externo, '-', 4)::int))), 'ZZ: es este asiento del libro')) as cruces
  from movimientos_banco m join asientos a on a.numero = substring(m.id_externo from '^zz-(\d{4}-\d{6})-')
 where m.estado = 'pendiente' and m.id_externo ~ '^zz-\d{4}-\d{6}-\d+$' \gset
do $$
declare
  hoy date := current_setting('f16.hoy')::date;
  h   date; v jsonb;
begin
  for h in select (generate_series(date '2026-10-01', date_trunc('month', hoy)::date - 1, interval '1 month') + interval '1 month')::date - 1 loop
    v := fn_conciliar('1010', h, (select ((select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                              where l.cuenta = '1010' and a.tipo = 'apertura')
                                           + coalesce(sum(m.monto), 0))::text
                                    from movimientos_banco m where m.cuenta = '1010' and m.fecha <= h));
    if (v->>'lista_para_confirmar')::boolean then
      perform fn_conciliacion_confirmar((v->>'conciliacion')::uuid);
    end if;
  end loop;
end $$;
commit;
