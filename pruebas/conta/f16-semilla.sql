-- =====================================================================
-- f16-semilla.sql — la base del TABLERO (c16, la portada «Resumen» de
-- Contabilidad): un libro EN USO, de la apertura al 30-sep-2026 a HOY, con
-- algo que enseñar en cada tarjeta. SOLO PARA EL BANCO DE PRUEBAS: NO se
-- pega en Supabase. Todo inventado («ZZ …»): ni un nombre, ni un monto, ni
-- un número de verdad.
--
-- Se pega como editor_sql (el SQL Editor) sobre un clon de g12a (c1…c14 y
-- lo del 12-nov) o de g16a (lo mismo con la lista del 13-nov: c15 dentro),
-- SIN «-1» (trae sus transacciones; las partes del dueño cambian de rol
-- dentro de la suya):
--   psql -X -q -v ON_ERROR_STOP=1 -U editor_sql -d <bd> -f pruebas/conta/f16-semilla.sql
-- No hace falta c16: la semilla no lo usa (se puede pegar antes o después).
-- (14-nov, Fase 11c) Si la base trae la nómina con Gusto (c15), siembra
-- además DOS NÓMINAS DE GUSTO DE VERDAD (la sección 10: por el camino de
-- c15, con sus cargos en el banco); sin c15 (sobre g12a) se la salta, y el
-- tablero dice que la nómina no está pegada.
--
-- «HOY». Todo se fecha del 1-oct-2026 a hoy (en Miami), mes a mes: cuanto
-- más tarde se siembre, más meses trae. Para tener VARIOS MESES sin
-- esperar, se le dice el día:
--   psql … -v hoy=2027-03-10 -f pruebas/conta/f16-semilla.sql
-- y la semilla FINGE EL RELOJ de esa base (como c4-volumen.sh: solo la hora
-- de ahora cae ese día; cualquier otra fecha es la suya; c2 vuelve a sellar
-- sus huellas) y lo deja así: en esa base «hoy» es ese día. Sin «-v hoy»,
-- el reloj es el de verdad. Con el reloj fingido en 2027 la base cruza un
-- cambio de año (2026 → 2027).
--
-- LO QUE SIEMBRA (cada cosa por el camino de su capa: los puentes de c3,
-- fn_postear de c2, los cobros de c3, el banco y los préstamos de c6, Plaid
-- de c7, Stripe de p1, el WIP de c12; nada entra al libro por debajo):
--   · 6 obras (2 residenciales, 2 comerciales con retención, 2 de servicio)
--     y la APERTURA al 30-sep por su balanza de QuickBooks (c4): el banco,
--     dos facturas de antes que siguen por cobrar (una con retención), una
--     CUENTA POR PAGAR VIEJA (de agosto, vencida, sin pagar), la camioneta y
--     su PRÉSTAMO, las tarjetas, el capital y el resultado de enero a
--     septiembre;
--   · los TÉRMINOS de las facturas en Facturas → Ajustes: Net 30 (de fábrica
--     es «due on receipt»), para que la antigüedad tenga de todo;
--   · CADA MES: 6 facturas (unas cobradas enteras, una A MEDIAS, una sin
--     cobrar: vencidas de distinta edad y otras por vencer), sus cobros por
--     cheque y Zelle, un anticipo; tickets con las dos tarjetas (material,
--     combustible, herramienta, renta de equipo), un permiso por Zelle,
--     recibos a cuenta del supply (Net 30) y su pago (uno se queda sin
--     pagar), trabajos del sub y su pago, la renta, el seguro, el teléfono,
--     el software, el CPA, la publicidad, los cargos del banco, la nómina de
--     cada quincena (su journal entra con el débito del banco), el use tax
--     de dos compras y su pago al DOR, el pago de cada tarjeta, la CUOTA DEL
--     PRÉSTAMO y una distribución al accionista;
--   · UN CHEQUE QUE REBOTÓ (c3: su devolución, seis días después): la
--     factura vuelve a quedar por cobrar;
--   · STRIPE (p1): un cobro con tarjeta ya depositado en el banco, otro
--     cobrado que falta depositar y uno por cuenta de banco en camino;
--   · EL BANCO por PLAID (c7 → c6): lo que trae el banco de la cuenta y de
--     la Amex Gold, casado con el libro; movimientos POR REVISAR en la
--     Bandeja (recientes y uno de más de 30 días); los meses terminados,
--     conciliados; y otra conexión (la Amex Blue) que pide volver a entrar:
--     «con problemas»;
--   · EL WIP (c12) de octubre: lo de antes del libro confirmado en las dos
--     obras que ya andaban, el costo estimado de cada obra de precio fijo, y
--     el ajuste posteado (su reverso automático cae el 1-nov: el tablero lo
--     deja aparte mientras noviembre no tenga su propio ajuste);
--   · LO QUE LAS REVISIONES DEL TABLERO PIDIERON VER (13-nov): el estado de
--     cuenta de OCTUBRE de la Amex Blue, por archivo (su conexión de Plaid
--     pide volver a entrar): un saldo del banco de otro día, «al
--     31-oct-2026», que el tablero compara con el libro de ese día; y un
--     CHEQUE POSFECHADO (unos días después de hoy, dentro del mes) que no va
--     en el saldo de hoy y que la proyección de caja resta en su día;
--   · (14-nov, Fase 11c; solo con c15 en la base) LA NÓMINA DE GUSTO: tres
--     personas inventadas (dos de campo y el oficial), sus horas aprobadas
--     en dos obras, y DOS NÓMINAS por el camino de c15 (el journal
--     importado, la gente enlazada, la propuesta vista y posteada): la A,
--     con día de pago hace 11 días, y sus cargos de Gusto en el banco (el
--     neto y los impuestos, casados desde Nómina; el reempleo y la
--     manutención, esperando en la Bandeja); la B, con día de pago dentro de
--     3 días, ya posteada y sin cargos todavía (la proyección de la caja la
--     resta en su día). Lo que el oficial pagó de su bolsillo (dos compras
--     a su nombre) entra antes al libro: la nómina se lo reembolsa y la
--     cuenta de reembolsos queda en cero.
-- Lo que deja a propósito en la bandeja de los puentes: los papeles de la
-- semilla de siempre que esperan una regla o un dato (un ticket sin forma
-- de pago, uno con una tarjeta que no existe).
-- Al final enseña una línea por cosa sembrada (SEMILLA …).
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

-- ===== 1b. el dueño: los términos de las facturas (Facturas → Ajustes): Net 30 =====
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select (fn_emision_config('{"terminos_dias": 30}'::jsonb) ->> 'terminos_dias') as terminos \gset
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

-- ===== 4b. el SQL Editor: UN CHEQUE QUE REBOTÓ (c3) — el primer cheque de octubre, seis días después =====
begin;
select count(fn_cobro_devolver(c.id, c.fecha + 6, 'ZZ: el cheque rebotó (fondos insuficientes)')) as devueltos
  from (select c.id, c.fecha from cobros c
         where c.medio = 'cheque' and c.referencia like 'ZZ-C-2610-%' and c.estado = 'vigente' and c.fecha + 6 <= :'hoy'::date
         order by c.fecha, c.referencia limit 1) c \gset
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

-- ===== 6. EL BANCO (c6) por PLAID (c7): lo que el banco trae de la cuenta y de la Amex Gold, casado, y lo que queda POR REVISAR =====
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

-- ===== 8. el dueño: EL WIP DE OCTUBRE (c12) =====
-- (lo de antes del libro de las obras que ya andaban, inventado; el costo estimado de cada obra de precio fijo, holgado sobre lo
--  que ya lleva; y el ajuste posteado)
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select count(fn_wip_antes(o.proyecto_id, jsonb_build_object('costo', o.costo::text, 'facturado', o.facturado::text,
                                                           'nota', 'ZZ: lo de antes del libro, inventado para la semilla')))
         as antes
  from (values ('casa-perez-k3m9', 7400.00, 9100.00), ('oficina-nch-7xq2', 18250.00, 21400.00)) o(proyecto_id, costo, facturado)
 where exists (select 1 from v_wip_obras w where w.proyecto_id = o.proyecto_id and w.lleva_wip and w.de_antes) \gset
select count(fn_wip_revisar(w.proyecto_id, '2026-10', jsonb_build_object(
         'costo_estimado', round(((coalesce(w.antes_costo, 0)
                                   + coalesce((select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                where l.proyecto_id = w.proyecto_id and l.cuenta like '5%' and a.fecha_contable <= date '2026-10-31'), 0))
                                  * 2.4 + 3000)::numeric, 2)::text,
         'nota', 'ZZ: el estimado de la semilla')))
         as revisadas
  from v_wip_obras w
 where w.lleva_wip and w.activa \gset
select fn_wip_postear('2026-10', null) ->> 'nota' as wip \gset
commit;

-- ===== 9. LO QUE LAS REVISIONES DEL TABLERO PIDIERON VER =====
-- (a) el dueño: el estado de cuenta de octubre de la Amex Blue, por archivo (un lote, como el CSV del banco): su saldo al 31-oct es el
--     del libro ese día (en el signo del libro: en una tarjeta, lo que se debe en negativo); sin movimientos nuevos.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select count(fn_banco_importar_filas(jsonb_build_object(
          'origen', 'csv', 'cuenta', '2100-2009', 'nombre', 'ZZ Blue · estado de cuenta de octubre',
          'saldo', (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                     where l.cuenta = '2100-2009' and a.fecha_contable <= date '2026-10-31')::text,
          'saldo_al', '2026-10-31', 'desde', '2026-10-01', 'hasta', '2026-10-31', 'filas', '[]'::jsonb))) as estado_blue
  from (select 1) u
 where :'hoy'::date > date '2026-10-31' \gset
commit;
-- (b) el SQL Editor: un cheque posfechado (un pago al seguro, unos días después de hoy y dentro del mes; si hoy es el último día del mes, no)
begin;
select count(fn_postear(jsonb_build_object('fecha', x.f::text, 'descripcion', 'ZZ: el seguro de la camioneta, con un cheque posfechado',
         'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6200', 'monto', '640.00'),
                                     jsonb_build_object('cuenta', '1010', 'monto', '-640.00'))))) as posfechado
  from (select least(:'hoy'::date + 4, (date_trunc('month', :'hoy'::date) + interval '1 month')::date - 1) as f) x
 where x.f > :'hoy'::date \gset
commit;

-- ===== 10. (14-nov, Fase 11c) LA NÓMINA DE GUSTO (c15), DE VERDAD =====
-- Solo si c15 está en esta base (sobre g12a, sin c15, no siembra nada: el tablero dice que la nómina no está pegada) y si el día de
-- pago de la primera cae ya dentro del libro (desde el 1-oct-2026).
-- Dos nóminas regulares de Gusto, cada dos semanas, de tres personas inventadas («ZZ Nomina Uno» y «ZZ Nomina Dos» —de campo— y
-- «ZZ Oficial Tres» —el accionista-oficial—), por el camino de c15 (el journal importado, la gente enlazada, la propuesta vista y
-- posteada), con sus horas aprobadas en dos obras de la semilla:
--   A · período de hoy−28 a hoy−15, día de pago hoy−11: posteada; sus cargos de Gusto en el banco (Plaid), dos días antes del día de
--       pago (y nunca antes del día 1 del mes de hoy: los meses de antes ya están conciliados): el NETO (5,171.63) y los IMPUESTOS
--       (1,522.54) casados desde Nómina → Cargos de Gusto; el REEMPLEO de Florida (166.51) y la MANUTENCIÓN (40.00) esperan en la
--       Bandeja;
--   B · período de hoy−14 a hoy−1, día de pago hoy+3: posteada (Gusto ya la corrió: su journal ya está) y SIN cargos todavía (Gusto
--       cobra dos días antes del día de pago): la proyección de la caja la resta en su día.
-- En cada período el oficial pagó 58.40 de su bolsillo (una compra a su nombre: queda debiéndosele en la cuenta de reembolsos a
-- empleados); cada nómina se lo reembolsa con su neto, y esa cuenta queda en cero.
-- Lo que el patrón paga por la gente de obra entra a la bolsa del burden real y sale a sus obras con cada nómina: queda en cero.
-- Nada de esto es de nadie: nombres «ZZ…», montos inventados que cuadran al centavo.
\set n_uno  '00000000-0000-4000-a000-0000000016a1'
\set n_dos  '00000000-0000-4000-a000-0000000016a2'
\set n_tres '00000000-0000-4000-a000-0000000016a3'
select set_config('f16.n_uno', :'n_uno', false) is not null as ok1, set_config('f16.n_dos', :'n_dos', false) is not null as ok2,
       set_config('f16.n_tres', :'n_tres', false) is not null as ok3 \gset
select (to_regprocedure('public.fn_nomina_importar(jsonb,jsonb)') is not null and to_regclass('public.v_nomina_corridas') is not null
        and :'hoy'::date - 11 >= date '2026-10-01') as hay_c15 \gset
\if :hay_c15
-- (a) el SQL Editor: las tres personas (su usuario y su perfil), su tarifa, sus horas aprobadas de los dos períodos y las dos
--     compras que el oficial pagó de su bolsillo
begin;
insert into auth.users (id, email) values
  (:'n_uno',  'f16-n1@f16-pruebas.invalid'), (:'n_dos', 'f16-n2@f16-pruebas.invalid'), (:'n_tres', 'f16-n3@f16-pruebas.invalid')
on conflict (id) do nothing;
insert into perfiles (id, nombre, rol, activo) values
  (:'n_uno', 'ZZ Nomina Uno', 'campo', true), (:'n_dos', 'ZZ Nomina Dos', 'campo', true), (:'n_tres', 'ZZ Oficial Tres', 'campo', true)
on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
insert into costos_equipo (usuario_id, costo_hora) values (:'n_uno', 23), (:'n_dos', 20)
on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
-- (horas aprobadas por el dueño: Uno 84 h —12 h siete días—, Dos 76 h —9.5 h ocho días—, el oficial 16 h en obra; en cada período)
insert into horas (fecha, usuario_id, proyecto_id, horas, notas, aprobado_por, aprobado_el)
select p.d0 + x.k, x.u::uuid, x.obra, x.h, 'ZZ f16: horas de la nómina', :'dueno'::uuid, now()
  from (values (:'hoy'::date - 28), (:'hoy'::date - 14)) p(d0)
  cross join lateral (
    select g.k, :'n_uno' as u, case when g.k % 2 = 0 then 'zz-nave-cuatro-a1b2' else 'zz-casa-cinco-c3d4' end as obra, 12.0 as h
      from generate_series(0, 6) g(k)
    union all
    select g.k, :'n_dos', 'zz-nave-cuatro-a1b2', 9.5 from generate_series(0, 7) g(k)
    union all
    select g.k, :'n_tres', 'zz-nave-cuatro-a1b2', 8.0 from generate_series(1, 2) g(k)) x;
-- (lo que el oficial pagó de su bolsillo, una compra en cada período: queda debiéndosele, a su nombre, en la cuenta de reembolsos
--  a empleados —la app no tiene «reembolso» entre las formas de pago de un recibo: entra con un asiento a mano—)
select count(fn_postear(jsonb_build_object('fecha', x.f::text,
         'descripcion', 'ZZ: material que el oficial pagó de su bolsillo (se le reembolsa por la nómina)',
         'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '58.40', 'proyecto_id', 'zz-nave-cuatro-a1b2'),
                                     jsonb_build_object('cuenta', '2250', 'monto', '-58.40', 'tercero_tipo', 'empleado',
                                                        'tercero_id', :'n_tres'))))) as de_su_bolsillo
  from (values (greatest(:'hoy'::date - 20, date '2026-10-01')), (greatest(:'hoy'::date - 6, date '2026-10-01'))) x(f) \gset
commit;

-- (b) el dueño, con su código: la cuenta de lo sin obra, las dos nóminas (importar, enlazar, postear)
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select fn_nomina_config(jsonb_build_object('cuenta_sin_obra', '6000')) is not null as ok \gset
do $$
declare
  hoy  date := current_setting('f16.hoy')::date;
  cab  text := 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Regular hours,'
               'Regular earnings,Overtime hours,Overtime earnings,Gross earnings,Employee federal income tax,Employee social security tax,'
               'Employee medicare tax,Employee medicare additional tax,Employee taxes,Employee deductions,Net pay,Reimbursements,Check amount,'
               'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes,Employer cost';
  csv  text;
  r    jsonb;
  c    uuid;
  v_per record;
begin
  for v_per in select * from (values
      ('a', hoy - 28, hoy - 15, hoy - 11,
       array['ZZ Nomina,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1840.00,4.00,207.00,2047.00,150.00,126.91,29.68,0.00,306.59,0.00,1740.41,0.00,1740.41,126.91,29.68,12.28,55.27,224.14,2271.14',
             'ZZ Nomina,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,76.00,1520.00,0.00,0.00,1520.00,102.00,94.24,22.04,0.00,218.28,40.00,1261.72,0.00,1261.72,94.24,22.04,9.12,41.04,166.44,1686.44',
             'ZZ Oficial,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2600.00,0.00,0.00,2600.00,290.00,161.20,37.70,0.00,488.90,0.00,2111.10,58.40,2169.50,161.20,37.70,15.60,70.20,284.70,2884.70',
             'Totals,,,,,,,236.00,5960.00,4.00,207.00,6167.00,542.00,382.35,89.42,0.00,1013.77,40.00,5113.23,58.40,5171.63,382.35,89.42,37.00,166.51,675.28,6842.28']),
      ('b', hoy - 14, hoy - 1, hoy + 3,
       array['ZZ Nomina,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1840.00,0.00,0.00,1840.00,128.00,114.08,26.68,0.00,268.76,0.00,1571.24,0.00,1571.24,114.08,26.68,11.04,49.68,201.48,2041.48',
             'ZZ Nomina,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,76.00,1520.00,0.00,0.00,1520.00,102.00,94.24,22.04,0.00,218.28,40.00,1261.72,0.00,1261.72,94.24,22.04,9.12,41.04,166.44,1686.44',
             'ZZ Oficial,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2600.00,0.00,0.00,2600.00,290.00,161.20,37.70,0.00,488.90,0.00,2111.10,58.40,2169.50,161.20,37.70,15.60,70.20,284.70,2884.70',
             'Totals,,,,,,,236.00,5960.00,0.00,0.00,5960.00,520.00,369.52,86.42,0.00,975.94,40.00,4944.06,58.40,5002.46,369.52,86.42,35.76,160.92,652.62,6612.62'])
    ) x(k, desde, hasta, pago, filas) loop
    csv := cab || E'\n' || (select string_agg(format(f, to_char(v_per.desde, 'MM/DD/YYYY'), to_char(v_per.hasta, 'MM/DD/YYYY'),
                                                     to_char(v_per.pago, 'MM/DD/YYYY')), E'\n' order by o)
                              from unnest(v_per.filas) with ordinality u(f, o)) || E'\n';
    r := fn_nomina_importar(jsonb_build_object(
           'nombre', 'zz-f16-payroll-journal-' || v_per.k || '.csv', 'sha256', encode(sha256(convert_to(csv, 'UTF8')), 'hex'),
           'bytes', octet_length(csv),
           'filas', (select jsonb_agg(to_jsonb(string_to_array(l, ',')) order by o)
                       from unnest(string_to_array(rtrim(csv, E'\n'), E'\n')) with ordinality u(l, o))), '{}'::jsonb);
    c := (select (q ->> 'corrida')::uuid from jsonb_array_elements(r -> 'corridas') q where q ->> 'resultado' = 'nueva' limit 1);
    if c is null then
      raise exception 'f16-semilla: la nómina % no entró: %', v_per.k, left(r::text, 400);
    end if;
    if v_per.k = 'a' then
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Nomina Uno')),
                                                   'usuario_id', current_setting('f16.n_uno'), 'clase', 'campo', 'confirmar', true));
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Nomina Dos')),
                                                   'usuario_id', current_setting('f16.n_dos'), 'clase', 'campo', 'confirmar', true));
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Oficial Tres')),
                                                   'usuario_id', current_setting('f16.n_tres'), 'clase', 'oficial', 'confirmar', true));
    end if;
    perform fn_nomina_postear(c, fn_nomina_propuesta(c) ->> 'visto');
  end loop;
end $$;
commit;

-- (c) Plaid trae los cargos de Gusto de la nómina A (dos días antes de su día de pago; nunca antes del día 1 del mes de hoy)
begin;
create temp table _zz_gusto on commit drop as
select '1010'::text as cuenta, 'zz-gusto-' || x.k as id, greatest(:'hoy'::date - 13, date_trunc('month', :'hoy'::date)::date) as fecha,
       x.monto, x.descr, 'DEBIT'::text as tipo
  from (values ('net', -5171.63, 'GUSTO DES:NET 99F16A ID:ZZF16NET'), ('tax', -1522.54, 'GUSTO DES:TAX 99F16A ID:ZZF16TAX'),
               ('sui', -166.51, 'GUSTO DES:TAX 99F16S ID:ZZF16SUI'), ('csd', -40.00, 'GUSTO DES:CSD 99F16A ID:ZZF16CSD')) x(k, monto, descr);
select fn_plaid_recibir('item-zz-f16-uno', jsonb_build_array(jsonb_build_object(
         'origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · ZZ Banco Uno · 1010',
         'plaid_saldo', ((select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '1010' and a.tipo = 'apertura')
                         + (select coalesce(sum(m.monto), 0) from movimientos_banco m where m.cuenta = '1010')
                         + (select sum(g.monto) from _zz_gusto g))::text,
         'saldo_al', :'hoy',
         'filas', (select jsonb_agg(jsonb_build_object('id', g.id, 'fecha', g.fecha::text, 'plaid_monto', (-g.monto)::text,
                                                       'descripcion', g.descr, 'tipo', g.tipo, 'pendiente', false) order by g.id)
                     from _zz_gusto g))), 'cursor-zz-f16-gusto', '{"por": "f16-semilla: la nómina de Gusto"}') is not null as ok \gset
commit;

-- (d) el dueño, con su código: casa el neto y los impuestos de la nómina A desde Nómina → Cargos de Gusto
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
do $$
declare
  ca uuid := (select k.id from nomina_corridas k where k.estado = 'posteada' order by k.dia_pago limit 1);
begin
  perform fn_nomina_cargo_casar((select id from movimientos_banco where id_externo = 'zz-gusto-net'),
            jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2210', 'monto', '5171.63')), null);
  perform fn_nomina_cargo_casar((select id from movimientos_banco where id_externo = 'zz-gusto-tax'),
            jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2220', 'monto', '1485.54'),
                              jsonb_build_object('corrida', ca, 'cuenta', '2225', 'monto', '37.00')), null);
end $$;
commit;
\endif

-- ===== lo sembrado, en una línea por cosa =====
\unset QUIET
select 'SEMILLA ' || x.que || ': ' || x.cuanto as semilla
  from (values
    (1, 'hoy', (select fn_fecha_miami(now())::text)),
    (2, 'asientos', (select count(*) || ' (del ' || min(fecha_contable) || ' al ' || max(fecha_contable) || ')' from asientos)),
    (3, 'facturas', (select count(*)::text from facturas)),
    (4, 'cobros', (select count(*) || ' (' || count(*) filter (where id in (select cobro_id from cobros_devoluciones)) || ' devuelto)' from cobros)),
    (5, 'movimientos del banco', (select count(*) || ' (' || count(*) filter (where estado = 'pendiente') || ' por revisar)' from movimientos_banco)),
    (6, 'conciliaciones confirmadas', (select count(*)::text from conciliaciones where estado = 'confirmada')),
    (7, 'cuotas del préstamo', (select count(*)::text from prestamo_cuotas where anulada_el is null)),
    (8, 'pagos en Stripe', (select count(*)::text from stripe_pagos)),
    (9, 'conexiones de Plaid', (select string_agg(institucion || ' ' || estado, ', ' order by institucion) from plaid_conexiones)),
    (10, 'WIP posteado', (select count(*)::text from wip_ajustes where deshecho_el is null)),
    (11, 'saldo del banco de otro día', (select coalesce(string_agg(s.cuenta || ' al ' || s.saldo_banco_al, ', '), 'ninguno')
                                           from v_banco_saldos s where s.saldo_banco_al < fn_fecha_miami(now()))),
    (12, 'posfechados', (select count(*) || ' con fecha de después de hoy' from asientos where fecha_contable > fn_fecha_miami(now()))),
    -- (14-nov, Fase 11c) las nóminas de Gusto (c15): sus asientos en el libro y los cargos de Gusto que esperan en la Bandeja
    (13, 'nóminas de Gusto', (select count(*) || ' en el libro (' || count(*) filter (where a.fecha_contable > fn_fecha_miami(now()))
                                     || ' con día de pago después de hoy)' from asientos a
                               where a.origen_tabla = 'nomina_corridas' and a.reversa_a is null
                                 and not exists (select 1 from asientos r where r.reversa_a = a.id))),
    (14, 'cargos de Gusto en la Bandeja', (select count(*) || ' por casar' from movimientos_banco m
                                            where m.estado = 'pendiente' and m.descripcion like 'GUSTO %'))) x(o, que, cuanto)
 order by x.o;
