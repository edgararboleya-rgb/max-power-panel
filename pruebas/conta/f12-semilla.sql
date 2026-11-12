-- =====================================================================
-- f12-semilla.sql — la base de la Fase 12a para la pantalla (pantalla.js):
-- un libro de octubre y noviembre de 2026 «en uso» con lo que enseñan las
-- páginas «Cédula de corte» (c13) y «Subs y 1099» (c14). SOLO PARA EL BANCO
-- DE PRUEBAS: NO se pega en Supabase. Todo inventado («ZZ …»): ni un nombre,
-- ni un monto, ni un TIN de verdad (los TIN tienen forma válida y no existen).
--
-- La pega pruebas/conta/f12-capturar.js como editor_sql (el SQL Editor), sobre
-- un clon de g10a con 06-produccion-facturas.sql, c13 y c14 pegados; las partes
-- del dueño cambian de rol dentro de su transacción. Después de esto el
-- capturador hace, en el mismo orden que la prueba de la pantalla, cada cosa
-- que la pantalla escribe, y guarda lo que contesta el banco en
-- pruebas/conta/pantalla-f12.json (la base simulada de las dos páginas).
--
-- La parte de la cédula es la de la base «sucia» con que se probó c13 (las
-- facturas, el proveedor, la tarjeta, el activo, la póliza, el préstamo, el
-- cobro en línea, la balanza de QuickBooks, los renglones a mano y dos
-- explicaciones, una de ellas vieja); se le añade un banco de prueba (1093)
-- conciliado con un depósito y un cheque en tránsito y un depósito de
-- después, y el WIP de octubre posteado. La de c14: dos subs (uno con ficha
-- completa salvo el W-9, otro sin ficha), el ayudante por decidir, un pago
-- con la tarjeta, un Zelle sin tercero, un pago de noviembre y uno que Edgar
-- pagó de su bolsillo (contra la 2900: «por otro camino»).
-- =====================================================================
\set ON_ERROR_STOP 1
\set QUIET 1
\set dueno '00000000-0000-4000-a000-000000000001'
\set gus   '00000000-0000-4000-a000-000000000002'
select set_config('mxp.cierre_sin_push', '1', false) \gset
-- ===== 1. el SQL Editor: los nombres de la semilla (inventados con «ZZ»), reglas, proveedores, tarjeta, contratos, facturas
begin;
update perfiles set nombre = 'Zzeli ZZ' where id = :'gus';
update perfiles set nombre = 'Zzpedro ZZ' where id = '00000000-0000-4000-a000-000000000003';
update proyectos set nombre = 'ZZ Casa Uno', cliente = 'ZZ Cliente Casa', direccion = '1 ZZ St, Ocala, FL' where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Dos', cliente = 'ZZ Cliente Oficina', direccion = '2 ZZ Ave, Ocala, FL' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres', cliente = 'ZZ Cliente Taller', direccion = '3 ZZ Rd, Ocala, FL' where id = 'taller-ruiz-5b2n';
select fn_mapeo_confirmar('tipo_proyecto');
select fn_proveedor_alta('ZZ REAL SUPPLY CO', 'Net 30', array['zz real supply']);
select fn_tarjeta_alta('2009', '2100-2009', 'ZZ REAL Blue');
insert into finanzas_proyecto (proyecto_id, contrato) values ('oficina-nch-7xq2', 12000)
  on conflict (proyecto_id) do update set contrato = excluded.contrato;
insert into facturas (proyecto_id, num, fecha, monto, retencion) values
  ('oficina-nch-7xq2', 'R-101', '2026-10-08', 5000, 500),
  ('casa-perez-k3m9',  'R-102', '2026-10-15', 1200, 0),
  ('casa-perez-k3m9',  'R-103', '2026-11-04', 900, 0);
commit;
-- ===== 2. el dueño: el libro de octubre y noviembre (la cédula)
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1),
                                                          'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
set local role authenticated;
create temp table _p (k text primary key, v text) on commit drop;
select fn_postear('{"fecha": "2026-10-01", "descripcion": "ZZ REAL: aporte inicial", "lineas": [{"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3100", "monto": "-50000.00"}]}') is not null as ok \gset
select fn_cobro_registrar(jsonb_build_object('fecha', '2026-10-20', 'monto', '2000.00', 'cuenta', '1010', 'medio', 'cheque', 'referencia', 'ZZ-CHK-1',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', (select id from public.facturas where num = 'R-101'), 'monto', '2000.00')))) is not null as ok \gset
select fn_postear('{"fecha": "2026-10-05", "descripcion": "ZZ REAL: una cuenta por cobrar a mano", "lineas": [{"cuenta": "1110", "monto": "250.00"}, {"cuenta": "3100", "monto": "-250.00"}]}') is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-10-06', 'descripcion', 'ZZ REAL: material a cuenta', 'lineas', jsonb_build_array(
         jsonb_build_object('cuenta', '5100', 'monto', '800.00', 'proyecto_id', 'casa-perez-k3m9'),
         jsonb_build_object('cuenta', '2010', 'monto', '-800.00', 'tercero_tipo', 'proveedor',
                            'tercero_id', (select id::text from public.proveedores where nombre = 'ZZ REAL SUPPLY CO'))))) is not null as ok \gset
select fn_postear('{"fecha": "2026-10-07", "descripcion": "ZZ REAL: por pagar sin proveedor", "lineas": [{"cuenta": "6200", "monto": "60.00"}, {"cuenta": "2010", "monto": "-60.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-09", "descripcion": "ZZ REAL: costo de la oficina", "lineas": [{"cuenta": "5100", "monto": "4000.00", "proyecto_id": "oficina-nch-7xq2"}, {"cuenta": "1010", "monto": "-4000.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-10", "descripcion": "ZZ REAL: una provisión que no se deshace", "lineas": [{"cuenta": "6200", "monto": "300.00"}, {"cuenta": "2050", "monto": "-300.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-31", "descripcion": "ZZ REAL: devengo del cierre de octubre", "reversible": true, "lineas": [{"cuenta": "6200", "monto": "150.00"}, {"cuenta": "2050", "monto": "-150.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-11", "descripcion": "ZZ REAL: use tax de una compra", "lineas": [{"cuenta": "6200", "monto": "21.50"}, {"cuenta": "2300", "monto": "-21.50"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-12", "descripcion": "ZZ REAL: impuestos de nómina", "lineas": [{"cuenta": "6200", "monto": "700.00"}, {"cuenta": "2220", "monto": "-700.00"}]}') is not null as ok \gset
insert into _p select 'activo', fn_postear('{"fecha": "2026-10-02", "descripcion": "ZZ REAL: compra de un taladro", "lineas": [{"cuenta": "1520", "monto": "3000.00"}, {"cuenta": "1010", "monto": "-3000.00"}]}')->>'id';
select fn_activo_alta(jsonb_build_object('descripcion', 'ZZ REAL taladro magnético', 'placa_serie', 'ZZ-77', 'cuenta', '1520', 'fecha_servicio', '2026-10-02',
         'costo', '3000.00', 'metodo', 'linea_recta', 'vida_meses', 60, 'asiento_alta_id', (select v from _p where k = 'activo'))) is not null as ok \gset
select fn_depreciacion_mes('2026-10')->>'nota' as depreciacion \gset
select fn_postear('{"fecha": "2026-10-01", "descripcion": "ZZ REAL: pago de la póliza GL", "lineas": [{"cuenta": "1410", "monto": "2400.00"}, {"cuenta": "1010", "monto": "-2400.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-03", "descripcion": "ZZ REAL: desembolso del préstamo de la camioneta", "lineas": [{"cuenta": "1010", "monto": "30000.00"}, {"cuenta": "2530", "monto": "-30000.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-16", "descripcion": "ZZ REAL: un cobro en línea en Stripe", "lineas": [{"cuenta": "1020", "monto": "400.00"}, {"cuenta": "3100", "monto": "-400.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-11-05", "descripcion": "ZZ REAL: otro aporte, en noviembre", "lineas": [{"cuenta": "1010", "monto": "500.00"}, {"cuenta": "3100", "monto": "-500.00"}]}') is not null as ok \gset
commit;
-- ===== 3. el SQL Editor: la póliza, el préstamo, Stripe, QuickBooks
begin;
select fn_prepagado_guardar('{"descripcion": "ZZ REAL GL 2026-2027", "tipo": "seguro", "cuenta_gasto": "6200", "monto": "2400.00", "desde": "2026-10-01", "hasta": "2027-09-30"}') is not null as ok \gset
select fn_prestamo_guardar('{"prestamista": "ZZ REAL AUTO FIN", "descripcion": "camioneta", "principal": "30000.00", "tasa_anual": "6", "cuota": "600.00", "primer_pago": "2026-11-03", "saldo_inicial": "30000.00", "saldo_inicial_al": "2026-10-03"}') is not null as ok \gset
insert into stripe_pagos (pi, factura_num, medio, monto, estado, estado_stripe, objetivo, en_libro, cobrado_el)
values ('pi_zzreal0001', 'R-102', 'tarjeta', 400, 'cobrado', 'succeeded', 400, 400, '2026-10-16');
select fn_apertura_mapeo_qb('ZZ REAL QB Checking', '1010', 'ZZ REAL') is not null as ok \gset
select fn_comparacion_qb_cargar('2026-10', 'docs/qb/zz-real-2026-10.csv', '[{"cuenta_qb": "ZZ REAL QB Checking", "saldo": "68877.00"}, {"cuenta_qb": "ZZ REAL QB sin mapeo", "saldo": "-68877.00"}]'::jsonb) is not null as ok \gset
select fn_diferencia_anotar('2026-10', '1010', '123.00', 'puente', 'ZZ REAL: un depósito que QuickBooks tiene en noviembre') is not null as ok \gset
commit;
-- ===== 4. el dueño: amortizar, el WIP, y la cédula en uso (renglones, explicaciones, configuración)
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1),
                                                          'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
set local role authenticated;
select fn_prepagados_amortizar('2026-10') is not null as ok \gset
select fn_wip_revisar('oficina-nch-7xq2', '2026-10', '{"costo_estimado": "8000"}')->>'nota' as wip_revisar \gset
select fn_wip_postear('2026-10', null)->>'nota' as wip_postear \gset
select fn_cedula_config('{"avisar_desde": "2026-10", "patrimonio": "manual"}') is not null as ok \gset
select fn_cedula_renglon('{"cuenta": "1600", "concepto": "ZZ REAL: depósito en garantía del local", "monto": "500.00", "desde": "2026-09-30", "documento": "ZZ REAL contrato"}') is not null as ok \gset
select fn_cedula_renglon('{"cuenta": "2220", "concepto": "ZZ REAL: 941 por depositar", "monto": "700.00", "desde": "2026-10-12"}') is not null as ok \gset
select fn_cedula_renglon('{"cuenta": "3100", "concepto": "ZZ REAL: aportes según el acta", "monto": "51150.00", "desde": "2026-10-01", "documento": "ZZ REAL acta"}') is not null as ok \gset
select fn_cedula_explicar('2050', '2026-10-31', 'ZZ REAL: los 300 son la provisión de la auditoría de seguros') is not null as ok \gset
select fn_cedula_explicar('1110', '2026-10-31', 'ZZ REAL: los 250 son un saldo que venía de QuickBooks sin su factura') is not null as ok \gset
-- (después de explicar la 2050, entra algo más: esa explicación se queda vieja)
select fn_postear('{"fecha": "2026-10-28", "descripcion": "ZZ REAL: otra provisión, después de explicar", "lineas": [{"cuenta": "6200", "monto": "40.00"}, {"cuenta": "2050", "monto": "-40.00"}]}') is not null as ok \gset
commit;
-- ===== 5. el SQL Editor: el banco de prueba y los terceros de c14
begin;
insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
values ('1093', 'ZZ Banco de prueba', 'zz test bank', 'activo', 'debe', true, 'prohibida', 'prohibida');
select fn_proveedor_alta('ZZ Sub Electrico Uno', 'Net 30') is not null as ok \gset
select fn_proveedor_alta('ZZ Sub Zanjas Dos', 'Net 15') is not null as ok \gset
-- (el ayudante también tiene proveedor para sus trabajos externos: la misma persona de las dos formas, una ficha)
select fn_proveedor_alta('ZZ Zzeli Trabajos', 'Net 15') is not null as ok \gset
commit;
-- ===== 6. el dueño: el banco de prueba conciliado, el WIP de octubre y los pagos a los subs
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select fn_postear('{"fecha": "2026-10-02", "descripcion": "ZZ: un depósito al banco de prueba", "lineas": [{"cuenta": "1093", "monto": "1000.00"}, {"cuenta": "3100", "monto": "-1000.00"}]}') is not null as ok \gset
select fn_postear('{"fecha": "2026-10-19", "descripcion": "ZZ: el cheque 9301", "lineas": [{"cuenta": "6200", "monto": "200.00"}, {"cuenta": "1093", "monto": "-200.00"}]}') is not null as ok \gset
select (fn_conciliar('1093', '2026-10-31', '0.00')->>'conciliacion') as conc \gset
select fn_conciliacion_confirmar(:'conc'::uuid) is not null as ok \gset
select fn_postear('{"fecha": "2026-11-02", "descripcion": "ZZ: un depósito de noviembre", "lineas": [{"cuenta": "1093", "monto": "50.00"}, {"cuenta": "3100", "monto": "-50.00"}]}') is not null as ok \gset
select id as sub from proveedores where nombre = 'ZZ Sub Electrico Uno' \gset
select id as dos from proveedores where nombre = 'ZZ Sub Zanjas Dos' \gset
select id as sup from proveedores where nombre = 'ZZ REAL SUPPLY CO' \gset
-- la ficha completa del sub uno (con su TIN), la del ayudante por decidir
select fn_subs_ficha(jsonb_build_object('nombre_legal', 'ZZ Sub Electrico Uno LLC', 'nombre_comercial', 'ZZ Rayo', 'tipo_entidad', 'llc_un_socio', 'reporta', 'si',
  'direccion', '1 Calle Falsa', 'direccion2', 'Suite 2', 'ciudad', 'Ocala', 'estado', 'FL', 'zip', '34470', 'tercero', jsonb_build_object('tipo', 'proveedor', 'id', :'sub'))) ->> 'ficha_id' as f1 \gset
select fn_subs_tin_guardar(:'f1', '{"tin": "00-0000071"}') ->> 'ficha' is not null as ok \gset
select fn_subs_ficha(jsonb_build_object('nombre_legal', 'Zzeli Ayudante ZZ', 'tipo_entidad', 'individual', 'tercero', jsonb_build_object('tipo', 'empleado', 'id', :'gus'))) ->> 'ficha_id' is not null as ok \gset
-- los pagos: al sub uno (directo y con la Amex), al ayudante, al sub dos (sin ficha), uno sin tercero, uno de su bolsillo, material al supply
select fn_postear(jsonb_build_object('fecha', '2026-10-14', 'descripcion', 'ZZ: pago al sub uno', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '1500.00', 'proyecto_id', 'oficina-nch-7xq2', 'tercero_tipo', 'proveedor', 'tercero_id', :'sub'), jsonb_build_object('cuenta', '1010', 'monto', '-1500.00')))) is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-10-15', 'descripcion', 'ZZ: jornal a mano', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '800.00', 'proyecto_id', 'oficina-nch-7xq2', 'tercero_tipo', 'empleado', 'tercero_id', :'gus'), jsonb_build_object('cuenta', '1010', 'monto', '-800.00')))) is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-10-16', 'descripcion', 'ZZ: Zelle payment to ZZ SUB ELECTRICO UNO', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '450.00', 'proyecto_id', 'oficina-nch-7xq2'), jsonb_build_object('cuenta', '1010', 'monto', '-450.00')))) is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-10-17', 'descripcion', 'ZZ: con la Amex', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '300.00', 'proyecto_id', 'oficina-nch-7xq2', 'tercero_tipo', 'proveedor', 'tercero_id', :'sub'), jsonb_build_object('cuenta', '2100-2013', 'monto', '-300.00')))) is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-10-21', 'descripcion', 'ZZ: zanja de la casa', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '2400.00', 'proyecto_id', 'casa-perez-k3m9', 'tercero_tipo', 'proveedor', 'tercero_id', :'dos'), jsonb_build_object('cuenta', '1010', 'monto', '-2400.00')))) is not null as ok \gset
select fn_postear(jsonb_build_object('fecha', '2026-11-03', 'descripcion', 'ZZ: otro pago al sub uno', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '250.00', 'proyecto_id', 'oficina-nch-7xq2', 'tercero_tipo', 'proveedor', 'tercero_id', :'sub'), jsonb_build_object('cuenta', '1010', 'monto', '-250.00')))) is not null as ok \gset
-- (y uno que Edgar le pagó al sub dos de su bolsillo, contra el préstamo del accionista: «por otro camino», que el 1099 no cuenta
-- hasta que se marque «pagado»)
select fn_postear(jsonb_build_object('fecha', '2026-10-23', 'descripcion', 'ZZ: zanja extra, la pagó Edgar de su bolsillo', 'lineas', jsonb_build_array(
  jsonb_build_object('cuenta', '5200', 'monto', '200.00', 'proyecto_id', 'casa-perez-k3m9', 'tercero_tipo', 'proveedor', 'tercero_id', :'dos'), jsonb_build_object('cuenta', '2900', 'monto', '-200.00')))) is not null as ok \gset
-- el WIP de octubre: lo de antes de la oficina confirmado, revisada otra vez y posteado (la cédula compara la 1200 obra por obra)
select fn_wip_antes('oficina-nch-7xq2', '{"costo": "900.00", "facturado": "0.00"}') is not null as ok \gset
select fn_wip_revisar('oficina-nch-7xq2', '2026-10', '{"costo_estimado": "8000.00"}') is not null as ok \gset
select fn_wip_postear('2026-10', null)->>'nota' as wip \gset
commit;
\unset QUIET
select 'f12-semilla: lista' as fin;
