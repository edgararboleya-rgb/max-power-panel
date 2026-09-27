-- =====================================================================
-- C6 · Las pruebas del banco — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1, c2-libro.sql,
-- c3-puentes.sql, c4-estados.sql y c6-banco.sql (pruebas/conta/README.md,
-- §0). Lo que enseña al final es la tabla de resultados: una fila por
-- prueba, con lo esperado, lo obtenido y ok. Todo en true = los archivos
-- del banco entran enteros y una sola vez, cada movimiento casa con lo
-- suyo o espera a Edgar con su propuesta, nada del banco va dos veces al
-- libro, la conciliación cuadra de verdad, y el equipo no ve nada.
--
-- NO DEJA RASTRO. Cada prueba es un bloque «do» con una subtransacción
-- adentro: arma lo que necesita con CUENTAS DE PRUEBA (el banco 1098, la
-- reserva 1097 y dos tarjetas, 2100-9996 «····9996» y 2100-9995
-- «····9995», que se crean y se deshacen con ella: así ni los movimientos
-- de verdad ni los de la prueba se cruzan), sus reglas, un proveedor y
-- papeles de prueba (recibos y facturas con ids negativos, «c6-pruebas»),
-- importa estados de cuenta de prueba, casa, concilia, y al final lanza
-- MXT00 para DESHACER todo: los archivos, los movimientos, los casados,
-- las conciliaciones, los asientos, los números, los cierres y el
-- historial. El resultado viaja en variables y se apunta en _pruebas, que
-- es temporal. La última prueba compara la foto del final con la del
-- principio.
--
-- LOS CANDADOS, en el orden de la app: primero el del casado (el que toman
-- las funciones del banco), después los de los recibos (los 512 cajones de
-- c3, si la prueba sube tickets), y al final periodos y la cadena (los
-- toma el libro al postear). pg_temp.c6_candados() toma los dos primeros
-- ANTES que nada; pedirlos con la cadena ya tomada es MXT10. Las que
-- cambian un instante algo que la app podría estar leyendo (vacían una
-- vista, cambian la marca de c2) van con lock_timeout de 2 s: si la app
-- la está usando, salen «omitida».
--
-- LOS DATOS se buscan, no se inventan: el dueño, uno del equipo (si no
-- hay, esas pruebas salen «omitidas»), dos obras con tipo y el mes
-- abierto más antiguo desde el corte. Tarda unos segundos en el banco de
-- pruebas.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;
set jit = off;

-- ---------------------------------------------------------------------
-- Antes de nada: lo que estas pruebas dan por hecho.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.movimientos_banco') is null or to_regprocedure('public.fn_banco_importar_ofx(text,text,text)') is null
     or to_regprocedure('public.fn_banco_control(text,text[])') is null or to_regprocedure('public.fn_banco_version()') is null
     or to_regclass('public.v_asiento_papel') is null or to_regprocedure('public.fn_cobro_registrar(jsonb)') is null then
    raise exception using
      errcode = 'MX000',
      message = 'c6-pruebas NO se corrió: pega antes c1-plan-de-cuentas.sql, c2-libro.sql, c3-puentes.sql, c4-estados.sql y '
                'c6-banco.sql.';
  end if;
  -- (Estas pruebas son las de ESTA versión del banco: con una c6-banco.sql
  -- anterior pegada, sus pruebas nuevas saldrían en rojo por lo que falta,
  -- no por un fallo del libro.)
  if public.fn_banco_version() < 2026092701 then
    raise exception using
      errcode = 'MX000',
      message = format('c6-pruebas NO se corrió: la c6-banco.sql pegada es anterior (marca %s; estas pruebas piden 2026092701 o '
                       'más). Vuelve a pegar la c6-banco.sql de esta entrega.', public.fn_banco_version());
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Los ayudantes (en pg_temp: mueren con la sesión y nadie más los ve; se
-- llaman con su esquema delante, y siempre como el editor).
--   · c6_foto(): cómo están el libro, los papeles, el banco y su
--     historial, las reglas, los contadores, las secuencias de la app, los
--     eventos, las huellas de c2 y las del banco.
--   · c6_como(quien): suplantar al dueño, al equipo o a anon (o volver a
--     ser el editor), como en c4.
--   · c6_candados(): el candado del casado y los de los recibos, antes que
--     periodos y la cadena (ver arriba).
--   · c6_montar(): las cuentas de prueba, sus tarjetas, las reglas
--     confirmadas, los descriptores de arranque (como vienen en
--     c6-banco.sql: lo que Edgar ajustó no cambia lo que prueban) y el
--     proveedor de prueba.
--   · c6_qfx(...) y c6_ofx_xml(...): un estado de cuenta en OFX 1.x (SGML,
--     como el QFX de Chase y de Amex) o en OFX 2.x (XML).
--   · c6_recibo(json): un recibo de prueba (id negativo), leído, con su
--     forma de pago (la tarjeta ····9996 si no se dice).
--   · c6_mov(cuenta, fitid): el movimiento de prueba por su FITID.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c6_foto() returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_seq     text;
  v_huellas text;
  v_banco   text := '-';
  v_ev      text := '-';
begin
  select left(md5(string_agg(h.tipo || ' ' || h.objeto || ' ' || h.md5, ',' order by h.tipo, h.objeto)), 12)
    into v_huellas
    from public.fn_libro_huellas_calcular() h;
  if to_regprocedure('public.fn_banco_huellas_calcular()') is not null then
    execute 'select left(md5(string_agg(h.tipo || '' '' || h.objeto || '' '' || h.md5, '','' order by h.tipo, h.objeto)), 12)
               from public.fn_banco_huellas_calcular() h' into v_banco;
  end if;
  if to_regclass('public.eventos') is not null then
    execute 'select count(*)::text from public.eventos' into v_ev;
  end if;
  select string_agg(format('%s=%s', t, coalesce((select s.last_value from pg_sequences s
                                                   where s.schemaname || '.' || s.sequencename = pg_get_serial_sequence('public.' || t, 'id')),
                                                  0)), ' ' order by t)
    into v_seq
    from unnest(array['recibos', 'facturas', 'horas', 'trabajos_externos', 'materiales', 'externos_equipo']) t;
  return format('asientos=%s lineas=%s contadores=%s cerrados=%s puente=%s cobros=%s aplic=%s devol=%s recibos=%s facturas=%s '
                'prov=%s alias=%s tarjetas=%s reglas=%s/%s/%s cuentas=%s eventos=%s '
                'banco=%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s descriptores=%s sec=[%s] huellas=%s/%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) || ':' || coalesce(sum(intentos), 0) from puente_documentos),
                (select count(*) from cobros), (select count(*) from aplicaciones_cobro), (select count(*) from cobros_devoluciones),
                (select count(*) from recibos), (select count(*) from facturas),
                (select count(*) from proveedores), (select count(*) from proveedores_alias), (select count(*) from tarjetas),
                (select count(*) from mapeo_categoria_recibo), (select count(*) from mapeo_metodo_pago),
                (select count(*) from mapeo_tipo_proyecto), (select count(*) from cuentas), v_ev,
                (select count(*) from banco_historial), (select count(*) from archivos_banco), (select count(*) from movimientos_banco),
                (select count(*) from movimientos_banco_ids), (select count(*) from banco_casados),
                (select count(*) from banco_casado_lineas), (select count(*) from conciliaciones),
                (select count(*) from conciliacion_partidas), (select count(*) from prestamos), (select count(*) from prestamo_cuotas),
                (select count(*) from prepagados), (select count(*) from prepagados_amortizaciones),
                (select count(*) from movimientos_banco where estado <> 'pendiente'),
                (select md5(string_agg(d.clave || d.patron || coalesce(d.cuenta, ''), ',' order by d.clave)) from banco_descriptores d),
                coalesce(v_seq, '-'), v_huellas, v_banco);
end $$;
revoke execute on function pg_temp.c6_foto() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_como(p_quien text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute 'reset role';
  if p_quien is null then
    perform set_config('request.jwt.claims', '', true);
    return;
  end if;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', case p_quien when 'dueno' then current_setting('mx6.dueno')
                                                           when 'equipo' then current_setting('mx6.equipo') end,
                                       'role', case when p_quien = 'anon' then 'anon' else 'authenticated' end)::text, true);
  execute format('set local role %I', case when p_quien = 'anon' then 'anon' else 'authenticated' end);
end $$;
revoke execute on function pg_temp.c6_como(text) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_candados() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_k int;
begin
  if exists (select 1 from pg_locks l
              where l.pid = pg_backend_pid() and l.granted
                and ((l.locktype = 'advisory' and l.classid::bigint = 0 and l.objid::bigint = 820260923 and l.objsubid = 1)
                     or (l.locktype = 'relation' and l.relation = 'public.periodos'::regclass and l.mode <> 'AccessShareLock'))) then
    raise exception using errcode = 'MXT10',
      message = 'c6-pruebas: el candado del casado y los de los recibos se toman antes que periodos y la cadena, como en la app.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  if (select count(*) from pg_locks l
       where l.pid = pg_backend_pid() and l.granted and l.locktype = 'advisory'
         and l.classid::bigint = 820260925 and l.objsubid = 2) < 512 then
    for v_k in 0 .. 511 loop
      perform pg_advisory_xact_lock(820260925, v_k);
    end loop;
  end if;
end $$;
revoke execute on function pg_temp.c6_candados() from public, anon, authenticated, service_role;

-- Los puentes diferidos de c3, en immediate dentro de la subtransacción
-- (el MXT00 los devuelve a diferidos), después de los candados.
create or replace function pg_temp.c6_inmediato() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_lista text;
begin
  perform pg_temp.c6_candados();
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v_lista
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v_lista is not null then
    execute 'set constraints ' || v_lista || ' immediate';
  end if;
end $$;
revoke execute on function pg_temp.c6_inmediato() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_montar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_prov uuid;
  v_t    text;
  r      record;
begin
  perform pg_temp.c6_inmediato();
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
  values ('1098', 'c6-pruebas: banco de prueba', 'c6 test bank', 'activo', 'debe', true, 'prohibida', 'prohibida'),
         ('1097', 'c6-pruebas: reserva de prueba', 'c6 test reserve', 'activo', 'debe', true, 'prohibida', 'prohibida'),
         ('2100-9996', 'c6-pruebas: tarjeta de prueba', 'c6 test card', 'pasivo', 'haber', true, 'prohibida', 'prohibida'),
         ('2100-9995', 'c6-pruebas: otra tarjeta de prueba', 'c6 test card 2', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
  on conflict (codigo) do nothing;
  perform fn_tarjeta_alta('9996', '2100-9996', 'c6-pruebas: tarjeta');
  perform fn_tarjeta_alta('9995', '2100-9995', 'c6-pruebas: otra tarjeta');
  perform fn_mapeo_categoria('material', '5100');
  perform fn_mapeo_metodo_pago('credito', 'tarjeta');
  perform fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor');
  perform fn_mapeo_metodo_pago('zelle', 'banco', '1098');
  perform fn_mapeo_metodo_pago('debito', 'banco', '1098');
  for v_t in select distinct fn_puente_normalizar(p.tipo) from proyectos p
              where p.id in (current_setting('mx6.obra'), current_setting('mx6.obra2')) loop
    perform fn_mapeo_tipo_proyecto(v_t, coalesce((select m.cuenta from mapeo_tipo_proyecto m where m.tipo = v_t),
                                                 case v_t when 'comercial' then '4020' when 'servicio' then '4030' else '4010' end));
  end loop;
  -- Los descriptores como vienen en c6-banco.sql (1.13).
  for r in select * from (values
      ('nomina',          '(GUSTO|PAYROLL|\mADP\M|PAYCHEX)'),
      ('cargo_banco',     '(SERVICE (FEE|CHARGE)|MONTHLY (SERVICE |MAINTENANCE )?FEE|MAINTENANCE FEE|WIRE (TRANSFER )?FEE|'
                          || 'OVERDRAFT|INSUFFICIENT FUNDS|\mNSF\M|ATM FEE|FOREIGN TRANSACTION FEE|ANNUAL (MEMBERSHIP )?FEE|'
                          || 'LATE (PAYMENT )?FEE|RETURNED PAYMENT FEE|STOP PAYMENT FEE)'),
      ('interes',         '(INTEREST (PAYMENT|EARNED|PAID|CREDIT)|^INTEREST$)'),
      ('interes_tarjeta', '(INTEREST CHARGE|FINANCE CHARGE|PURCHASE INTEREST)'),
      ('cajero',          '(\mATM\M|CASH WITHDRAWAL|WITHDRAWAL CASH)'),
      ('zelle_edgar',     'ZELLE (PAYMENT )?FROM EDGAR'),
      ('transferencia',   '(ONLINE TRANSFER|TRANSFER (TO|FROM)|BOOK TRANSFER|\mXFER\M)'),
      ('pago_tarjeta',    '(PAYMENT RECEIVED|AUTOPAY|THANK YOU|EPAYMENT|AMERICAN EXPRESS|\mAMEX\M)'),
      ('cheque_devuelto', '(RETURNED (ITEM|CHECK|DEPOSIT)|DEPOSITED ITEM RETURNED|RETURN(ED)? DEPOSIT|CHARGEBACK|REVERSAL)')) as v(clave, patron)
  loop
    perform fn_banco_descriptor(r.clave, r.patron, case r.clave when 'cargo_banco' then '6130' when 'interes' then '4910'
                                                                when 'interes_tarjeta' then '7100' end);
  end loop;
  v_prov := fn_proveedor_alta('C6 PRUEBAS SUPPLY', 'Net 30', array['c6 pruebas supply inc']);
  return jsonb_build_object('proveedor', v_prov);
end $$;
revoke execute on function pg_temp.c6_montar() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_recibo(p jsonb) returns bigint
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_id bigint;
  v_f  date := coalesce((p->>'fecha')::date, current_setting('mx6.desde')::date + 4);
begin
  insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, fecha, categoria, subtotal, tax,
                       num_recibo, metodo_pago, ultimos4)
  overriding system value
  values ((p->>'id')::bigint, coalesce(p->>'proyecto_id', current_setting('mx6.obra')),
          coalesce(p->>'ruta', 'recibos/c6-pruebas/' || (p->>'id') || '.jpg'), (p->>'total')::numeric,
          coalesce(p->>'proveedor', 'C6 PRUEBAS SUPPLY'), 'c6-pruebas', 'leido',
          nullif(current_setting('mx6.dueno', true), '')::uuid, (v_f + time '12:00') at time zone 'America/New_York',
          v_f, 'material', null, null, coalesce(p->>'num_recibo', 'C6-' || (p->>'id')),
          coalesce(p->>'metodo_pago', 'credito'), case when p ? 'ultimos4' then p->>'ultimos4'
                                                        when coalesce(p->>'metodo_pago', 'credito') = 'credito' then '9996' end)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function pg_temp.c6_recibo(jsonb) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_mov(p_cuenta text, p_fitid text) returns uuid
language sql
stable
set search_path = public, pg_temp
as $$ select m.id from movimientos_banco m where m.cuenta = p_cuenta and m.id_externo = p_fitid order by m.importado_el desc limit 1 $$;
revoke execute on function pg_temp.c6_mov(text, text) from public, anon, authenticated, service_role;

-- El asiento vivo de un papel.
create or replace function pg_temp.c6_vivo(p_tabla text, p_id text) returns uuid
language sql
stable
set search_path = public, pg_temp
as $$
  select a.id from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   order by a.cadena_pos desc limit 1
$$;
revoke execute on function pg_temp.c6_vivo(text, text) from public, anon, authenticated, service_role;
-- Un estado de cuenta OFX 1.x (SGML, como el QFX de Chase y de Amex).
--   p_tipo 'banco' | 'tarjeta'; p_movs: [{tipo, fecha, monto, id, nombre, memo, cheque, fecha_usuario}]
create or replace function pg_temp.c6_qfx(p_tipo text, p_acctid text, p_desde date, p_hasta date, p_saldo numeric, p_movs jsonb,
                                          p_saldo_al date default null)
returns text
language sql
immutable
as $$
  select concat_ws(E'\r\n',
    'OFXHEADER:100', 'DATA:OFXSGML', 'VERSION:102', 'SECURITY:NONE', 'ENCODING:USASCII', 'CHARSET:1252', 'COMPRESSION:NONE',
    'OLDFILEUID:NONE', 'NEWFILEUID:NONE', '',
    '<OFX>',
    '<SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO</STATUS><DTSERVER>' || to_char(p_hasta, 'YYYYMMDD') || '120000[0:GMT]'
      || '<LANGUAGE>ENG<FI><ORG>B1<FID>10898</FI><INTU.BID>10898</SONRS></SIGNONMSGSRSV1>',
    case when p_tipo = 'banco'
         then '<BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><STMTRS><CURDEF>USD'
              || '<BANKACCTFROM><BANKID>267084131<ACCTID>' || p_acctid || '<ACCTTYPE>CHECKING</BANKACCTFROM>'
         else '<CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD'
              || '<CCACCTFROM><ACCTID>' || p_acctid || '</CCACCTFROM>' end,
    '<BANKTRANLIST>',
    '<DTSTART>' || to_char(p_desde, 'YYYYMMDD') || '120000[0:GMT]',
    '<DTEND>' || to_char(p_hasta, 'YYYYMMDD') || '120000[0:GMT]',
    (select string_agg(concat_ws(E'\r\n', '<STMTTRN>', '<TRNTYPE>' || (m->>'tipo'),
                                 '<DTPOSTED>' || to_char((m->>'fecha')::date, 'YYYYMMDD') || '120000[0:GMT]',
                                 case when m ? 'fecha_usuario' then '<DTUSER>' || to_char((m->>'fecha_usuario')::date, 'YYYYMMDD') end,
                                 '<TRNAMT>' || (m->>'monto'),
                                 '<FITID>' || (m->>'id'),
                                 case when m ? 'cheque' then '<CHECKNUM>' || (m->>'cheque') end,
                                 '<NAME>' || (m->>'nombre'),
                                 case when m ? 'memo' then '<MEMO>' || (m->>'memo') end,
                                 '</STMTTRN>'), E'\r\n' order by o)
       from jsonb_array_elements(p_movs) with ordinality as x(m, o)),
    '</BANKTRANLIST>',
    case when p_saldo is not null
         then '<LEDGERBAL><BALAMT>' || p_saldo::text || '<DTASOF>' || to_char(coalesce(p_saldo_al, p_hasta), 'YYYYMMDD') || '120000[0:GMT]</LEDGERBAL>'
              || '<AVAILBAL><BALAMT>' || (p_saldo - 100)::text || '<DTASOF>' || to_char(p_hasta, 'YYYYMMDD') || '</AVAILBAL>' end,
    case when p_tipo = 'banco' then '</STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>', '')
$$;

-- El mismo en OFX 2.x (XML, todo cerrado).
create or replace function pg_temp.c6_ofx_xml(p_tipo text, p_acctid text, p_desde date, p_hasta date, p_saldo numeric, p_movs jsonb)
returns text
language sql
immutable
as $$
  select concat_ws(E'\n',
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
    '<?OFX OFXHEADER="200" VERSION="220" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>',
    '<OFX>',
    '  <SIGNONMSGSRSV1><SONRS><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS><DTSERVER>' || to_char(p_hasta, 'YYYYMMDD')
      || '</DTSERVER><LANGUAGE>ENG</LANGUAGE></SONRS></SIGNONMSGSRSV1>',
    case when p_tipo = 'banco'
         then '  <BANKMSGSRSV1><STMTTRNRS><TRNUID>1</TRNUID><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS><STMTRS>'
              || '<CURDEF>USD</CURDEF><BANKACCTFROM><BANKID>267084131</BANKID><ACCTID>' || p_acctid
              || '</ACCTID><ACCTTYPE>SAVINGS</ACCTTYPE></BANKACCTFROM>'
         else '  <CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>1</TRNUID><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS>'
              || '<CCSTMTRS><CURDEF>USD</CURDEF><CCACCTFROM><ACCTID>' || p_acctid || '</ACCTID></CCACCTFROM>' end,
    '    <BANKTRANLIST>',
    '      <DTSTART>' || to_char(p_desde, 'YYYYMMDD') || '</DTSTART>',
    '      <DTEND>' || to_char(p_hasta, 'YYYYMMDD') || '</DTEND>',
    (select string_agg('      <STMTTRN><TRNTYPE>' || (m->>'tipo') || '</TRNTYPE><DTPOSTED>'
                       || to_char((m->>'fecha')::date, 'YYYYMMDD') || '000000.000[-5:EST]</DTPOSTED><TRNAMT>' || (m->>'monto')
                       || '</TRNAMT><FITID>' || (m->>'id') || '</FITID><NAME>' || (m->>'nombre') || '</NAME>'
                       || coalesce('<MEMO>' || (m->>'memo') || '</MEMO>', '') || '</STMTTRN>', E'\n' order by o)
       from jsonb_array_elements(p_movs) with ordinality as x(m, o)),
    '    </BANKTRANLIST>',
    case when p_saldo is not null
         then '    <LEDGERBAL><BALAMT>' || p_saldo::text || '</BALAMT><DTASOF>' || to_char(p_hasta, 'YYYYMMDD') || '</DTASOF></LEDGERBAL>' end,
    case when p_tipo = 'banco' then '  </STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '  </CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>')
$$;

-- ---------------------------------------------------------------------
-- El escenario de casi todas las pruebas, dentro de su subtransacción:
-- las cuentas y reglas de prueba (c6_montar), tres recibos (uno con la
-- tarjeta ····9996, uno por Zelle desde el banco de prueba, uno a cuenta
-- del proveedor), cuatro facturas de la obra y un cobro de 1,500.00 al
-- banco de prueba. Y los tres estados de cuenta del mes (D = el primer
-- día del mes abierto más antiguo):
--   · el banco 1098 (QFX de Chase, SGML): el cheque 1043 que venía de
--     septiembre, el Zelle al proveedor, el depósito del cobro, un Zelle
--     de un cliente (con &amp;), uno de Edgar, el cajero, el pago de la
--     Amex, la nómina de Gusto, el pase a la reserva, el pago al
--     proveedor, un depósito remoto y el cargo mensual del banco;
--   · la tarjeta ····9996 (QFX de Amex, CCSTMTRS): Home Depot (con su
--     ticket), una compra al proveedor sin ticket, el pago desde el
--     banco, el interés y la cuota anual;
--   · la reserva 1097 (OFX 2.x, XML): el pase desde el banco y el interés.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c6_escenario() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d       date := current_setting('mx6.desde')::date;
  v_obra  text := current_setting('mx6.obra');
  v_m     jsonb;
  v_cobro jsonb;
begin
  v_m := pg_temp.c6_montar();
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660001, 'total', 245.37, 'fecha', d + 4, 'proveedor', 'THE HOME DEPOT',
                                               'num_recibo', 'C6-HD-1'));
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660002, 'total', 310.00, 'fecha', d + 6, 'metodo_pago', 'zelle'));
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660003, 'total', 850.00, 'fecha', d + 8, 'metodo_pago', 'cuenta_proveedor'));
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
  values (-660001, v_obra, 'C6-1', d + 2, 3200.50, 0), (-660002, v_obra, 'C6-2', d + 3, 1000.00, 0),
         (-660003, v_obra, 'C6-3', d + 3, 777.77, 0), (-660004, v_obra, 'C6-4', d + 1, 5000.00, 0);
  v_cobro := fn_cobro_registrar(jsonb_build_object(
               'fecha', (d + 9)::text, 'monto', '1500.00', 'cuenta', '1098', 'medio', 'cheque', 'referencia', 'C6-5521',
               'duplicado_confirmado', 'c6-pruebas: dato de prueba',
               'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660004, 'monto', '1500.00'))));
  return v_m || jsonb_build_object('cobro', v_cobro->>'cobro');
end $$;
revoke execute on function pg_temp.c6_escenario() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_chase() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_qfx('banco', '000000001098', d, d + 27, -396.73, jsonb_build_array(
    jsonb_build_object('tipo', 'CHECK', 'fecha', d + 1, 'monto', '-1200.00', 'id', 'C6C1', 'nombre', 'CHECK 1043', 'cheque', '1043'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-310.00', 'id', 'C6C2', 'nombre', 'ZELLE PAYMENT TO C6 PRUEBAS',
                       'memo', 'INV C6-660002'),
    jsonb_build_object('tipo', 'DEP', 'fecha', d + 10, 'monto', '1500.00', 'id', 'C6C3', 'nombre', 'DEPOSIT', 'memo', 'CHECK C6-5521'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '3200.50', 'id', 'C6C4', 'nombre', 'ZELLE FROM JOHN SMITH &amp; SONS'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 15, 'monto', '1000.00', 'id', 'C6C5', 'nombre', 'ZELLE FROM EDGAR M'),
    jsonb_build_object('tipo', 'ATM', 'fecha', d + 16, 'monto', '-200.00', 'id', 'C6C6', 'nombre', 'ATM WITHDRAWAL 1234 MAIN ST'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 18, 'monto', '-500.00', 'id', 'C6C7', 'nombre', 'AMERICAN EXPRESS ACH PMT'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-4000.00', 'id', 'C6C8', 'nombre', 'GUSTO PAYROLL'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 20, 'monto', '1777.77', 'id', 'C6C12', 'nombre', 'REMOTE DEPOSIT'),
    jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '-2000.00', 'id', 'C6C9', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-850.00', 'id', 'C6C10', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
    jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_chase() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_amex() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_qfx('tarjeta', '372700000009996', d - 7, d + 22, -1173.26, jsonb_build_array(
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'fecha_usuario', d + 4, 'monto', '-245.37', 'id', 'C6A1',
                       'nombre', 'THE HOME DEPOT #6311'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 11, 'monto', '-1320.55', 'id', 'C6A2', 'nombre', 'C6 PRUEBAS SUPPLY'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 19, 'monto', '500.00', 'id', 'C6A3', 'nombre', 'PAYMENT RECEIVED - THANK YOU'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-12.34', 'id', 'C6A4', 'nombre', 'INTEREST CHARGE ON PURCHASES'),
    jsonb_build_object('tipo', 'FEE', 'fecha', d + 22, 'monto', '-95.00', 'id', 'C6A5', 'nombre', 'ANNUAL MEMBERSHIP FEE')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_amex() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_reserva() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_ofx_xml('banco', '1097', d, d + 27, 2000.42, jsonb_build_array(
    jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '2000.00', 'id', 'C6R1', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'),
    jsonb_build_object('tipo', 'INT', 'fecha', d + 27, 'monto', '0.42', 'id', 'C6R2', 'nombre', 'INTEREST PAYMENT')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_reserva() from public, anon, authenticated, service_role;

-- Importa los tres estados de cuenta (como el dueño, por la API) y casa lo
-- de las cuentas de prueba. Devuelve el resumen del casado.
create or replace function pg_temp.c6_importar_y_casar(p_como_dueno boolean default true) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c text := pg_temp.c6_chase();
  v_a text := pg_temp.c6_amex();
  v_r text := pg_temp.c6_reserva();
  v_x jsonb;
begin
  if p_como_dueno then
    perform pg_temp.c6_como('dueno');
  end if;
  perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
  perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
  perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
  v_x := fn_banco_casar_todo('1098');
  v_x := fn_banco_casar_todo('2100-9996');
  v_x := fn_banco_casar_todo('1097');
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return v_x;
end $$;
revoke execute on function pg_temp.c6_importar_y_casar(boolean) from public, anon, authenticated, service_role;

-- El estado de un movimiento de prueba en una palabra: su estado y, si
-- casó, la clase ('casado:recibo'); si espera, su motivo
-- ('pendiente:nomina').
create or replace function pg_temp.c6_est(p_cuenta text, p_fitid text) returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                     from movimientos_banco m where m.cuenta = p_cuenta and m.id_externo = p_fitid
                    order by m.importado_el desc limit 1), 'no_entró')
$$;
revoke execute on function pg_temp.c6_est(text, text) from public, anon, authenticated, service_role;

-- El reloj fingido y los cierres (como en c4-pruebas): «hoy» en Miami
-- pasa a ser ese día (fn_fecha_miami, dentro de la subtransacción: el
-- MXT00 la devuelve como era), y cerrar hasta un mes cierra en orden la
-- apertura (con un asiento de apertura mínimo de prueba si todavía no
-- hay uno: sin él no se cierra) y los meses hasta ese. Toma el candado de
-- periodos DESPUÉS de los del casado y los recibos (el orden de la app).
create or replace function pg_temp.c6_fingir_hoy(p_hoy date) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;
revoke execute on function pg_temp.c6_fingir_hoy(date) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_cerrar_hasta(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  perform pg_temp.c6_candados();
  lock table public.periodos in exclusive mode;
  select * into v_p from periodos where periodo = p_periodo;
  perform pg_temp.c6_fingir_hoy(greatest(v_p.hasta + 1, fn_fecha_miami(now())));
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'mano', 'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
      'descripcion', 'c6-pruebas: una apertura mínima para poder cerrar (se deshace)', 'documento_ruta', 'docs/c6-pruebas/apertura.pdf',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1050', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado' where periodo = v_q;
  end loop;
end $$;
revoke execute on function pg_temp.c6_cerrar_hasta(text) from public, anon, authenticated, service_role;

-- Lo que dice un cuadre del control del banco de un movimiento (o de lo
-- que sea): 'f' si el detalle lo nombra, 't' si no. Así las pruebas miran
-- SOLO lo suyo aunque el banco de verdad tenga otra cosa en rojo.
create or replace function pg_temp.c6_cuadre(p_vista text, p_periodo text, p_quien text) returns text
language sql
set search_path = public, pg_temp
as $$
  -- (Pide solo el grupo de vistas que calcula ese cuadre: el control
  -- entero, con un año de banco, tarda el doble.)
  select case when exists (select 1
                             from fn_banco_control(p_periodo,
                                    case when p_vista in ('cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso',
                                                          'cuadre: archivos intactos', 'cuadre: ningún ticket después de clasificar')
                                           then array['v_banco_movimientos']
                                         when p_vista = 'cuadre: conciliaciones confirmadas' then array['v_conciliacion']
                                         when p_vista = 'cuadre: préstamos' then array['v_prestamos']
                                         when p_vista = 'cuadre: prepagados' then array['v_prepagados'] end) c
                            where c.vista = p_vista and position(p_quien in coalesce(c.detalle, '')) > 0) then 'f' else 't' end
$$;
revoke execute on function pg_temp.c6_cuadre(text, text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Lo que usan todas las pruebas, en ajustes de la
-- sesión (mx6.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno  uuid;
  v_equipo uuid;
  v_obra   text;
  v_obra2  text;
  v_mes    text;
  v_desde  date;
  v_sig    text;
begin
  select id into v_dueno from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select p.id into v_obra from proyectos p where nullif(btrim(p.tipo), '') is not null order by p.id limit 1;
  select p.id into v_obra2 from proyectos p where nullif(btrim(p.tipo), '') is not null and p.id <> v_obra order by p.id limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde >= fn_puente_corte() order by desde limit 1;
  select periodo into v_sig from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  perform set_config('mx6.dueno',  coalesce(v_dueno::text, ''), false);
  perform set_config('mx6.equipo', coalesce(v_equipo::text, ''), false);
  perform set_config('mx6.obra',   coalesce(v_obra, ''), false);
  perform set_config('mx6.obra2',  coalesce(v_obra2, coalesce(v_obra, '')), false);
  perform set_config('mx6.mes',    coalesce(v_mes, ''), false);
  perform set_config('mx6.desde',  coalesce(v_desde::text, ''), false);
  perform set_config('mx6.sig',    coalesce(v_sig, ''), false);
  perform set_config('mx6.foto',   pg_temp.c6_foto(), false);
end $$;


-- =====================================================================
-- Los archivos del banco
-- =====================================================================

-- 1. El QFX de Chase (OFX 1.x, SGML), subido por Edgar desde la app: entra
--    ENTERO (su texto y su sha256), con sus 12 movimientos como los dijo el
--    banco (el cheque con su número, el «&amp;» como «&», el signo del
--    libro), el saldo final de LEDGERBAL (no el disponible, AVAILBAL) a su
--    fecha, y quién lo subió. Y al casar, cada uno con lo suyo: el Zelle
--    al proveedor con su ticket, el depósito con su cobro, el pago de la
--    Amex y el pase a la reserva como transferencias, el cargo del banco a
--    6130; lo demás espera con su motivo.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx6.dueno', true), '')::uuid;
  v_obt   text;
  v_esp   text := 'filas=12 nuevas=12 formato=ofx_sgml saldo=-396.73 al=+27 sha=t texto=t quien=dueño cheque=1043 amp=t '
                  'C1=pendiente:sin_ticket C2=casado:recibo C3=casado:cobro C4=pendiente:deposito_sin_cobro '
                  'C5=pendiente:aporte_edgar C6=pendiente:cajero C7=casado:transferencia C8=pendiente:nomina '
                  'C12=pendiente:deposito_sin_cobro C9=casado:transferencia C10=pendiente:pago_proveedor C11=casado:regla';
  v_x     jsonb;
  v_txt   text;
begin
  if v_dueno is null or current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (1, 'QFX de Chase: entra entero, cada movimiento como lo dijo el banco, y casa lo que casa', v_esp,
                                 'omitida: falta dueño o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    v_txt := pg_temp.c6_chase();
    perform pg_temp.c6_como('dueno');
    v_x := fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    execute 'reset role';
    perform pg_temp.c6_importar_y_casar();
    select format('filas=%s nuevas=%s formato=%s saldo=%s al=+%s sha=%s texto=%s quien=%s cheque=%s amp=%s',
                  v_x->>'filas_leidas', v_x->>'filas_nuevas', a.formato, a.saldo, a.saldo_al - current_setting('mx6.desde')::date,
                  a.sha256 = encode(sha256(convert_to(v_txt, 'UTF8')), 'hex'), a.texto = v_txt,
                  case when a.importado_por = v_dueno then 'dueño' else coalesce(a.importado_por::text, '-') end,
                  (select m.cheque from movimientos_banco m where m.archivo_id = a.id and m.id_externo = 'C6C1'),
                  exists (select 1 from movimientos_banco m where m.archivo_id = a.id and m.descripcion = 'ZELLE FROM JOHN SMITH & SONS'))
      into v_obt
      from archivos_banco a where a.id = (v_x->>'archivo')::uuid;
    v_obt := v_obt || ' ' || (select string_agg(replace(x, 'C6C', 'C') || '=' || pg_temp.c6_est('1098', x), ' ' order by o)
                                from unnest(array['C6C1', 'C6C2', 'C6C3', 'C6C4', 'C6C5', 'C6C6', 'C6C7', 'C6C8', 'C6C12', 'C6C9',
                                                  'C6C10', 'C6C11']) with ordinality as t(x, o));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (1, 'QFX de Chase: entra entero, cada movimiento como lo dijo el banco, y casa lo que casa', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 2. El QFX de la Amex (CREDITCARDMSGSRSV1 / CCSTMTRS), sin decir la
--    cuenta: va a la tarjeta ····9996 por sus 4 últimos (tabla tarjetas);
--    una compra en negativo (Cr 2100-9996), el pago en positivo; el saldo
--    que se debe en negativo, a la fecha de corte del statement; la fecha
--    de la compra (DTUSER) aparte de la del banco. Home Depot casa con su
--    ticket, el pago con el lado del banco, la cuota anual a 6130; la
--    compra al proveedor sin ticket y el interés esperan.
do $$
declare
  v_obt   text;
  v_esp   text := 'cuenta=2100-9996 tipo=tarjeta u4=9996 filas=5 saldo=-1173.26 al=+22 compra=-245.37 dtuser=+4 '
                  'A1=casado:recibo A2=pendiente:sin_ticket A3=casado:transferencia A4=pendiente:interes_tarjeta A5=casado:regla';
  v_x     jsonb;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (2, 'QFX de la Amex: a su tarjeta por los 4 últimos, compras en negativo, saldo al corte', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select format('cuenta=%s tipo=%s u4=%s filas=%s saldo=%s al=+%s compra=%s dtuser=+%s', a.cuenta,
                  (select case when c.tipo = 'pasivo' then 'tarjeta' else c.tipo end from cuentas c where c.codigo = a.cuenta),
                  a.ultimos4, a.filas_leidas, a.saldo, a.saldo_al - current_setting('mx6.desde')::date,
                  (select m.monto from movimientos_banco m where m.archivo_id = a.id and m.id_externo = 'C6A1'),
                  (select m.fecha_transaccion - current_setting('mx6.desde')::date from movimientos_banco m
                    where m.archivo_id = a.id and m.id_externo = 'C6A1'))
      into v_obt
      from archivos_banco a where a.nombre = 'c6-pruebas-amex.qfx';
    v_obt := v_obt || ' ' || (select string_agg(replace(x, 'C6A', 'A') || '=' || pg_temp.c6_est('2100-9996', x), ' ' order by x)
                                from unnest(array['C6A1', 'C6A2', 'C6A3', 'C6A4', 'C6A5']) x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (2, 'QFX de la Amex: a su tarjeta por los 4 últimos, compras en negativo, saldo al corte', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 3. Un OFX 2.x (XML, todo cerrado, fechas con zona «[-5:EST]»): la
--    reserva. Mismo resultado que el SGML: el pase desde el banco casa con
--    su otro lado (la misma transferencia, un asiento) y el interés va
--    solo a 4910 (regla fija: tipo INT, entra dinero y lo dice el
--    descriptor).
do $$
declare
  v_obt text;
  v_esp text := 'formato=ofx_xml filas=2 saldo=2000.42 R1=casado:transferencia R2=casado:regla interes=4910:-0.42 un_asiento=t';
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (3, 'OFX 2.x (XML): se lee igual; la transferencia es un asiento; el interés, a 4910 solo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select format('formato=%s filas=%s saldo=%s', a.formato, a.filas_leidas, a.saldo) into v_obt
      from archivos_banco a where a.nombre = 'c6-pruebas-reserva.ofx';
    v_obt := v_obt || format(' R1=%s R2=%s interes=%s un_asiento=%s', pg_temp.c6_est('1097', 'C6R1'), pg_temp.c6_est('1097', 'C6R2'),
                             (select l.cuenta || ':' || l.monto from asiento_lineas l
                               where l.asiento_id = (select m.asiento_id from movimientos_banco m
                                                      where m.id = pg_temp.c6_mov('1097', 'C6R2'))
                                 and l.cuenta <> '1097'),
                             (select m1.asiento_id = m2.asiento_id from movimientos_banco m1, movimientos_banco m2
                               where m1.id = pg_temp.c6_mov('1097', 'C6R1') and m2.id = pg_temp.c6_mov('1098', 'C6C9')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (3, 'OFX 2.x (XML): se lee igual; la transferencia es un asiento; el interés, a 4910 solo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 4. IDEMPOTENTE: el mismo archivo otra vez no entra (su sha256: «ya
--    estaba», con el resumen de la primera vez), y el mismo archivo con
--    otro nombre tampoco: no hay un movimiento de más ni un archivo de más.
do $$
declare
  v_obt text;
  v_esp text := 'segunda=ya_estaba otra_vez=ya_estaba archivos=1 movimientos=12';
  v_x   jsonb;
  v_y   jsonb;
  v_txt text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (4, 'el mismo archivo dos veces entra una', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_txt := pg_temp.c6_chase();
    perform fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    v_y := fn_banco_importar_ofx(v_txt, null, 'c6-pruebas-chase (1).qfx');
    v_obt := format('segunda=%s otra_vez=%s archivos=%s movimientos=%s',
                    case when (v_x->>'ya_estaba')::boolean then 'ya_estaba' else 'entró' end,
                    case when (v_y->>'ya_estaba')::boolean then 'ya_estaba' else 'entró' end,
                    (select count(*) from archivos_banco where cuenta = '1098'),
                    (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (4, 'el mismo archivo dos veces entra una', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 5. UN ARCHIVO QUE SE SOLAPA con otro (el banco exporta del 10 al 5 del
--    mes siguiente): solo entra lo nuevo; lo repetido se cuenta. Y dos
--    movimientos iguales el mismo día en el mismo archivo (dos cafés de
--    4.50) entran los dos: cada uno es un movimiento.
do $$
declare
  v_obt text;
  v_esp text := 'leidas=4 nuevas=2 repetidas=2 dos_cafes=2 total=14';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (5, 'un archivo que se solapa mete solo lo nuevo y cuenta lo repetido', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 20, d + 35, 100.00, jsonb_build_array(
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-850.00', 'id', 'C6C10', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
             jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE'),
             jsonb_build_object('tipo', 'POS', 'fecha', d + 28, 'monto', '-4.50', 'id', 'C6C13', 'nombre', 'CAFE C6'),
             jsonb_build_object('tipo', 'POS', 'fecha', d + 28, 'monto', '-4.50', 'id', 'C6C14', 'nombre', 'CAFE C6'))),
             null, 'c6-pruebas-solape.qfx');
    v_obt := format('leidas=%s nuevas=%s repetidas=%s dos_cafes=%s total=%s', v_x->>'filas_leidas', v_x->>'filas_nuevas',
                    v_x->>'filas_repetidas',
                    (select count(*) from movimientos_banco where cuenta = '1098' and descripcion = 'CAFE C6'),
                    (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (5, 'un archivo que se solapa mete solo lo nuevo y cuenta lo repetido', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 6. EL MISMO MOVIMIENTO POR PLAID Y POR ARCHIVO entra UNA vez: por Plaid
--    (el monto al revés, como lo da Plaid) y después el archivo con el
--    mismo cargo (misma fecha, monto y descripción): repetido, con los
--    dos ids. Uno con el mismo monto a dos días y otra descripción entra
--    marcado «posible duplicado» y espera (no casa, no se clasifica) hasta
--    que Edgar dice si es el mismo; «es el mismo» lo deja ignorado. Lo
--    pendiente de Plaid (pending) no entra nunca.
do $$
declare
  v_obt text;
  v_esp text := 'plaid=2+1fuera archivo=1nuevo+1repetido ids=2 dup=pendiente:posible_duplicado clasificar=MX008 '
                'dicho=ignorado total=3';
  v_p   jsonb;
  v_a   jsonb;
  v_dup uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (6, 'Plaid y el archivo: el mismo movimiento entra una vez; el parecido espera', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
             jsonb_build_object('id', 'c6-plaid-1', 'fecha', d + 3, 'plaid_monto', '87.65', 'descripcion', 'C6 FERRETERIA'),
             jsonb_build_object('id', 'c6-plaid-2', 'fecha', d + 4, 'plaid_monto', '12.00', 'descripcion', 'C6 CAFE', 'pendiente', true),
             jsonb_build_object('id', 'c6-plaid-3', 'fecha', d + 5, 'plaid_monto', '-40.00', 'descripcion', 'C6 REEMBOLSO'))));
    v_a := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 1000.00, jsonb_build_array(
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-87.65', 'id', 'C6P1', 'nombre', 'C6 FERRETERIA'),
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '40.00', 'id', 'C6P2', 'nombre', 'C6 REEMBOLSO CREDIT'))),
             '1098', 'c6-pruebas-plaid.qfx');
    v_dup := pg_temp.c6_mov('1098', 'C6P2');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(v_dup, '[{"cuenta": "6130"}]'::jsonb, 'c6-pruebas');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('plaid=%s+%sfuera archivo=%snuevo+%srepetido ids=%s dup=%s clasificar=%s', v_p->>'filas_nuevas', v_p->>'filas_fuera',
                    v_a->>'filas_nuevas', v_a->>'filas_repetidas',
                    (select count(*) from movimientos_banco_ids i where i.movimiento_id = pg_temp.c6_mov('1098', 'c6-plaid-1')),
                    pg_temp.c6_est('1098', 'C6P2'), v_x);
    perform fn_banco_duplicado(v_dup, true, 'c6-pruebas: es el mismo reembolso');
    v_obt := v_obt || format(' dicho=%s total=%s', (select m.estado from movimientos_banco m where m.id = v_dup),
                             (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (6, 'Plaid y el archivo: el mismo movimiento entra una vez; el parecido espera', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 7. UN ARCHIVO QUE NO SE PUEDE LEER no entra (nada, ni el archivo) y dice
--    por qué en español: vacío, que no es OFX, sin <OFX>, dos cuentas en
--    uno, sin la lista de movimientos, una fecha rota, un monto con tres
--    decimales, otra moneda, un movimiento sin FITID ni tipo… MX009 (MX005
--    el monto).
do $$
declare
  v_obt  text := '';
  v_esp  text := 'vacio=MX009 no_ofx=MX009 sin_ofx=MX009 dos=MX009 sin_lista=MX009 fecha=MX009 monto=MX005 moneda=MX009 '
                 'sin_tipo=MX009 espanol=t archivos=0';
  v_base text;
  v_k    text;
  v_t    text;
  v_x    text;
  v_es   boolean := true;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (7, 'un archivo malo no entra y dice por qué en español (MX009)', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_base := pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 10.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-1.00', 'id', 'C6M1', 'nombre', 'C6 MAL')));
    for v_k, v_t in select * from (values
        ('vacio', '   '),
        ('no_ofx', 'Fecha,Descripcion,Monto' || chr(10) || '10/03/2026,HOME DEPOT,-12.00'),
        ('sin_ofx', 'OFXHEADER:100' || chr(10) || 'DATA:OFXSGML' || chr(10) || '<BANKMSGSRSV1>'),
        ('dos', replace(v_base, '</BANKMSGSRSV1>', '</BANKMSGSRSV1><BANKMSGSRSV1><STMTTRNRS><STMTRS></STMTRS></STMTTRNRS></BANKMSGSRSV1>')),
        ('sin_lista', regexp_replace(v_base, '<BANKTRANLIST>.*</BANKTRANLIST>', '')),
        ('fecha', replace(v_base, '<DTPOSTED>' || to_char(d + 3, 'YYYYMMDD'), '<DTPOSTED>2026-1')),
        ('monto', replace(v_base, '<TRNAMT>-1.00', '<TRNAMT>-1.005')),
        ('moneda', replace(v_base, '<CURDEF>USD', '<CURDEF>MXN')),
        ('sin_tipo', replace(v_base, '<TRNTYPE>DEBIT', ''))) as x(k, t) loop
      begin
        perform fn_banco_importar_ofx(v_t, '1098', 'c6-pruebas-malo.qfx');
        v_x := 'entró';
      exception when others then
        v_x := sqlstate;
        v_es := v_es and (sqlerrm ~* '(archivo|monto|decimales|centavos|falta|cuenta)');
      end;
      v_obt := v_obt || v_k || '=' || v_x || ' ';
    end loop;
    v_obt := v_obt || format('espanol=%s archivos=%s', v_es, (select count(*) from archivos_banco where nombre = 'c6-pruebas-malo.qfx'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (7, 'un archivo malo no entra y dice por qué en español (MX009)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- El casado
-- =====================================================================

-- 8. TARJETA ↔ RECIBO, automático y con rastro: el cargo de Home Depot en
--    la tarjeta casa con la línea de 2100-9996 del asiento del ticket (el
--    que puso c3), por el mismo monto, con la fecha del ticket a menos de
--    3 días; queda dicho con qué regla, que fue automático, cuándo, y en
--    banco_historial (antes pendiente, después casado). No se postea nada
--    nuevo: el gasto ya entró con el ticket.
do $$
declare
  v_obt text;
  v_esp text := 'estado=casado clase=recibo ref=-660001 regla=R1 auto=t asiento=el_del_recibo lineas=1 asientos_nuevos=0 '
                'historial=pendiente>casado';
  v_m   uuid;
  v_n   bigint;
  v_p0  bigint;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (8, 'tarjeta ↔ recibo: casa sola con el asiento del ticket, con su regla y su rastro', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    -- (Lo de la prueba, no lo de la base: con el banco en uso ya hay
    -- casados que postearon, y restarlos todos daba negativo.)
    v_n := (select count(*) from asientos);
    v_p0 := (select count(*) from banco_casados c where c.posteado and c.deshecho_el is null);
    perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6A1');
    select format('estado=%s clase=%s ref=%s regla=%s auto=%s asiento=%s lineas=%s asientos_nuevos=%s historial=%s',
                  m.estado, m.casado_clase, m.casado_ref, split_part(m.casado_regla, ' ', 1), m.casado_auto,
                  case when m.asiento_id = pg_temp.c6_vivo('recibos', '-660001') then 'el_del_recibo' else coalesce(m.asiento_id::text, '-') end,
                  (select count(*) from banco_casado_lineas l where l.casado_id = m.casado_id and l.vigente),
                  (select count(*) from asientos) - v_n
                    - ((select count(*) from banco_casados c where c.posteado and c.deshecho_el is null) - v_p0),
                  (select h.antes->>'estado' || '>' || (h.despues->>'estado') from banco_historial h
                    where h.tabla = 'movimientos_banco' and h.clave = m.id::text and h.operacion = 'UPDATE'
                      and h.despues->>'estado' = 'casado' order by h.cambiado_el limit 1))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (8, 'tarjeta ↔ recibo: casa sola con el asiento del ticket, con su regla y su rastro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 9. UN TICKET REPARTIDO entre dos obras (la misma foto, dos recibos que
--    suman el cargo): el cargo casa con los DOS (sus dos líneas de la
--    tarjeta). Y dos tickets del mismo monto a menos de 3 días del mismo
--    cargo NO casan solos (no se adivina): se proponen los dos.
do $$
declare
  v_obt  text;
  v_esp  text := 'repartido=casado:recibo lineas=2 empate=pendiente:varios_candidatos opciones=2';
  v_obra2 text := current_setting('mx6.obra2', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (9, 'ticket repartido casa con sus dos recibos; dos iguales no se adivinan', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660011, 'total', 300.00, 'fecha', d + 2, 'ruta', 'recibos/c6-pruebas/rep.jpg'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660012, 'total', 120.45, 'fecha', d + 2, 'ruta', 'recibos/c6-pruebas/rep.jpg',
                                                 'proyecto_id', v_obra2));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660013, 'total', 66.60, 'fecha', d + 3, 'num_recibo', 'C6-E1'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660014, 'total', 66.60, 'fecha', d + 4, 'num_recibo', 'C6-E2'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 9, -487.05, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-420.45', 'id', 'C6T1', 'nombre', 'C6 PRUEBAS SUPPLY #2'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'monto', '-66.60', 'id', 'C6T2', 'nombre', 'C6 GASOLINERA'))),
              null, 'c6-pruebas-repartido.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_obt := format('repartido=%s lineas=%s empate=%s opciones=%s', pg_temp.c6_est('2100-9996', 'C6T1'),
                    (select count(*) from banco_casado_lineas l join movimientos_banco m on m.casado_id = l.casado_id
                      where m.id = pg_temp.c6_mov('2100-9996', 'C6T1') and l.vigente),
                    pg_temp.c6_est('2100-9996', 'C6T2'),
                    (select jsonb_array_length(m.propuesta->'opciones') from movimientos_banco m
                      where m.id = pg_temp.c6_mov('2100-9996', 'C6T2')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (9, 'ticket repartido casa con sus dos recibos; dos iguales no se adivinan', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 10. LA BANDEJA propone la obra: un cargo sin ticket el día que hubo
--     visita a UNA obra (eventos) sale en v_banco_bandeja con esa obra
--     propuesta; con visitas a dos obras ese día, no se adivina (sin obra).
do $$
declare
  v_obt  text;
  v_esp  text;
  v_obra text := current_setting('mx6.obra', true);
  v_o2   text := current_setting('mx6.obra2', true);
  v_f1   date;
  v_f2   date;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  v_esp := format('uno=sin_ticket:%s dos=sin_ticket:- bandeja=2', v_obra);
  if d is null or to_regclass('public.eventos') is null or v_o2 = v_obra then
    insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                                 'omitida: falta mes abierto, la tabla eventos o una segunda obra', null);
    return;
  end if;
  -- (Dos días del mes sin visitas de verdad: así las de la prueba son las únicas.)
  select min(x.f) into v_f1 from generate_series(d + 1, d + 25, interval '1 day') g(t), lateral (select g.t::date as f) x
   where not exists (select 1 from eventos e where e.fecha = x.f);
  select min(x.f) into v_f2 from generate_series(v_f1 + 1, d + 26, interval '1 day') g(t), lateral (select g.t::date as f) x
   where not exists (select 1 from eventos e where e.fecha = x.f);
  if v_f1 is null or v_f2 is null then
    insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                                 'omitida: no hay dos días del mes sin visitas', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into eventos (id, fecha, titulo, proyecto_id, estado) overriding system value
    values (-660001, v_f1, 'c6-pruebas: visita', v_obra, 'programado'),
           (-660002, v_f2, 'c6-pruebas: visita', v_obra, 'programado'),
           (-660003, v_f2, 'c6-pruebas: otra visita', v_o2, 'programado');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 27, -100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f1, 'monto', '-61.11', 'id', 'C6E1', 'nombre', 'C6 LOWES #1'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f2, 'monto', '-62.22', 'id', 'C6E2', 'nombre', 'C6 LOWES #2'))),
              null, 'c6-pruebas-eventos.qfx');
    perform fn_banco_casar_todo('2100-9996');
    select format('uno=%s:%s dos=%s:%s bandeja=%s',
                  max(b.motivo) filter (where b.monto = -61.11), coalesce(max(b.obra->>'proyecto_id') filter (where b.monto = -61.11), '-'),
                  max(b.motivo) filter (where b.monto = -62.22), coalesce(max(b.obra->>'proyecto_id') filter (where b.monto = -62.22), '-'),
                  count(*))
      into v_obt
      from v_banco_bandeja b where b.cuenta = '2100-9996';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 11. DEPÓSITO ↔ COBRO (R2): el depósito casa solo con el cobro que Edgar
--     registró (mismo monto, 1 día después) y el cobro queda con su
--     movimiento (cobros.movimiento_id: de nulo a su valor, lo único que
--     c3 deja). No se postea nada: el asiento es el del cobro.
do $$
declare
  v_obt text;
  v_esp text := 'deposito=casado:cobro asiento=el_del_cobro cobro_dice=el_movimiento';
  v_esc jsonb;
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (11, 'depósito ↔ cobro: casa solo y el cobro queda con su movimiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C3');
    select format('deposito=%s asiento=%s cobro_dice=%s', pg_temp.c6_est('1098', 'C6C3'),
                  case when m.asiento_id = c.contabilizado_en then 'el_del_cobro' else '-' end,
                  case when c.movimiento_id = v_m::text then 'el_movimiento' else coalesce(c.movimiento_id, 'nada') end)
      into v_obt
      from movimientos_banco m, cobros c where m.id = v_m and c.id = (v_esc->>'cobro')::uuid;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (11, 'depósito ↔ cobro: casa solo y el cobro queda con su movimiento', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 12. UN DEPÓSITO SIN COBRO propone las facturas abiertas que lo explican
--     (la de 3,200.50; y para el de 1,777.77, las DOS que suman) y espera;
--     con «fn_banco_cobrar» Edgar elige y se registra el cobro (c3) con
--     este movimiento: Dr el banco / Cr 1110 por factura, casado.
do $$
declare
  v_obt text;
  v_esp text := 'una=Factura #C6-1 dos=Facturas #C6-2 y #C6-3 cobrado=casado:cobro lineas=1098:1777.77|1110:-777.77|1110:-1000.00 '
                'cobro_dice=el_movimiento';
  v_m   uuid;
  v_op  jsonb;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (12, 'un depósito sin cobro propone sus facturas (una o dos) y fn_banco_cobrar registra el cobro',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_obt := format('una=%s', (select split_part(o->>'texto', ' (', 1) from movimientos_banco m,
                                      jsonb_array_elements(m.propuesta->'opciones') o
                                where m.id = pg_temp.c6_mov('1098', 'C6C4') and o->>'texto' like '%C6-1 %' limit 1));
    v_m := pg_temp.c6_mov('1098', 'C6C12');
    select o into v_op from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'texto' like 'Facturas #C6-2 y #C6-3%' limit 1;
    v_obt := v_obt || ' dos=' || coalesce(v_op->>'texto', '-');
    perform pg_temp.c6_como('dueno');
    perform fn_banco_cobrar(v_m, v_op->'args'->'p_aplicaciones', 'c6-pruebas');
    execute 'reset role';
    select v_obt || format(' cobrado=%s lineas=%s cobro_dice=%s', pg_temp.c6_est('1098', 'C6C12'),
                           (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto desc)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           (select case when c.movimiento_id = v_m::text then 'el_movimiento' else '-' end
                              from cobros c where c.id::text = m.casado_ref))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (12, 'un depósito sin cobro propone sus facturas (una o dos) y fn_banco_cobrar registra el cobro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 13. UN DEPÓSITO NUNCA VA A INGRESO: clasificarlo a una cuenta de ingreso
--     no entra (MX008, y dice que es su cobro); y si un asiento del banco
--     lo hiciera (uno escrito por la puerta interna, a propósito), el
--     control «depósitos nunca a ingreso» lo dice en rojo.
do $$
declare
  v_obt text;
  v_esp text := 'clasificar=MX008:cobro control_antes=t control_despues=f';
  v_m   uuid;
  v_x   text;
  v_ing text;
begin
  select codigo into v_ing from cuentas where tipo = 'ingreso' and activa and imputable order by (codigo = '4010') desc, codigo limit 1;
  if current_setting('mx6.desde', true) = '' or v_ing is null then
    insert into _pruebas values (13, 'un depósito nunca va a ingreso (y el control lo vigila)', v_esp,
                                 'omitida: falta mes abierto o una cuenta de ingreso', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C4');
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', v_ing, 'proyecto_id',
                                                                            current_setting('mx6.obra'))), 'c6-pruebas');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like '%cobro%' then ':cobro' else '' end;
    end;
    v_obt := 'clasificar=' || v_x || ' control_antes='
             || (select c.ok::text from fn_banco_control(current_setting('mx6.mes'), array['v_banco_movimientos']) c
                  where c.vista = 'cuadre: depósitos nunca a ingreso');
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', (select m.fecha from movimientos_banco m where m.id = v_m)::text,
      'descripcion', 'c6-pruebas: un depósito a ingreso (se deshace)', 'origen_tabla', 'movimientos_banco', 'origen_id', v_m::text,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '3200.50'),
                                  jsonb_build_object('cuenta', v_ing, 'monto', '-3200.50', 'proyecto_id', current_setting('mx6.obra')))));
    v_obt := v_obt || ' control_despues='
             || (select c.ok::text from fn_banco_control(current_setting('mx6.mes'), array['v_banco_movimientos']) c
                  where c.vista = 'cuadre: depósitos nunca a ingreso');
    v_obt := replace(replace(v_obt, 'true', 't'), 'false', 'f');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (13, 'un depósito nunca va a ingreso (y el control lo vigila)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 14. UN ZELLE DE EDGAR no es ingreso ni se casa solo: la bandeja propone
--     préstamo del accionista (2900) o aportación (3100); con el de 2900,
--     Dr el banco / Cr 2900.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=aporte_edgar opciones=2900,3100 elegido=1098:1000.00|2900:-1000.00';
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (14, 'un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C5');
    select format('propuesta=%s opciones=%s', m.propuesta->>'motivo',
                  (select string_agg(o->'args'->'p_lineas'->0->>'cuenta', ',' order by o->'args'->'p_lineas'->0->>'cuenta')
                     from jsonb_array_elements(m.propuesta->'opciones') o))
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, '[{"cuenta": "2900"}]'::jsonb, 'c6-pruebas: Edgar prestó');
    v_obt := v_obt || ' elegido=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.orden)
                                        from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                       where m.id = v_m);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (14, 'un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 15. EL PAGO DE LA TARJETA es una transferencia, UN asiento para los dos
--     estados de cuenta, venga primero el que venga: con el banco y la
--     Amex subidos en un orden, y en el otro (la Amex primero), el mismo
--     resultado: Dr 2100-9996 / Cr el banco, con la fecha del primero, y
--     los dos movimientos casados con ese asiento. Sin gasto.
do $$
declare
  v_obt text := '';
  v_esp text := 'banco_primero=1asiento:2100-9996:500.00|1098:-500.00:+18 tarjeta_primero=1asiento:2100-9996:500.00|1098:-500.00:+18';
  v_ord int;
  v_a   uuid;
  v_b   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (15, 'el pago de la tarjeta: un asiento para los dos lados, en cualquier orden', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  for v_ord in 1 .. 2 loop
    begin
      perform pg_temp.c6_montar();
      if v_ord = 1 then
        perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
        perform fn_banco_casar_todo('1098');
        perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
        perform fn_banco_casar_todo('2100-9996');
      else
        perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
        perform fn_banco_casar_todo('2100-9996');
        perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
        perform fn_banco_casar_todo('1098');
      end if;
      v_a := pg_temp.c6_mov('1098', 'C6C7');
      v_b := pg_temp.c6_mov('2100-9996', 'C6A3');
      select v_obt || case when v_ord = 1 then 'banco_primero=' else ' tarjeta_primero=' end
             || case when ma.asiento_id = mb.asiento_id then '1asiento' else 'dos_asientos' end || ':'
             || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto desc) from asiento_lineas l
                  where l.asiento_id = ma.asiento_id)
             || ':+' || ((select a.fecha_contable from asientos a where a.id = ma.asiento_id) - current_setting('mx6.desde')::date)
        into v_obt
        from movimientos_banco ma, movimientos_banco mb where ma.id = v_a and mb.id = v_b;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
    end;
  end loop;
  insert into _pruebas values (15, 'el pago de la tarjeta: un asiento para los dos lados, en cualquier orden', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 16. EL PASE A LA RESERVA CON UN SOLO LADO: llega el banco y la reserva
--     no; se propone la transferencia y Edgar la confirma
--     (fn_banco_transferencia): se postea con su contrapartida y el
--     movimiento queda «en tránsito»; cuando llega la reserva, su lado
--     casa SOLO con ESE asiento (R1) y los dos quedan casados. Nunca dos
--     asientos.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=transferencia_un_lado antes=en_transito:transferencia despues=casado:transferencia '
                'reserva=casado:transferencia mismo_asiento=t asientos_del_pase=1';
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (16, 'transferencia con un lado: se confirma, y el otro lado casa con ese asiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C9');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    perform pg_temp.c6_como('dueno');
    perform fn_banco_transferencia(v_m, '1097', 'c6-pruebas: a la reserva');
    execute 'reset role';
    v_obt := v_obt || ' antes=' || pg_temp.c6_est('1098', 'C6C9');
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' despues=%s reserva=%s mismo_asiento=%s asientos_del_pase=%s', pg_temp.c6_est('1098', 'C6C9'),
                             pg_temp.c6_est('1097', 'C6R1'),
                             (select m1.asiento_id = m2.asiento_id from movimientos_banco m1, movimientos_banco m2
                               where m1.id = v_m and m2.id = pg_temp.c6_mov('1097', 'C6R1')),
                             (select count(*) from asiento_lineas l where l.cuenta = '1097' and l.monto = 2000.00));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (16, 'transferencia con un lado: se confirma, y el otro lado casa con ese asiento', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 17. EL CAJERO pregunta: ¿caja chica (1050) o para Edgar (3200)? Nunca
--     automático. Con la caja chica: Dr 1050 / Cr el banco.
do $$
declare
  v_obt  text;
  v_caja text;
  v_esp  text;
  v_m    uuid;
begin
  v_caja := coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                       order by m.confirmado_el desc nulls last limit 1), '1050');
  v_esp := format('antes=pendiente:cajero opciones=%s,3200 elegido=1098:-200.00|%s:200.00', v_caja, v_caja);
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (17, 'el cajero pregunta caja chica o Edgar, nunca solo', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C6');
    select format('antes=%s opciones=%s', pg_temp.c6_est('1098', 'C6C6'),
                  (select string_agg(o->'args'->'p_lineas'->0->>'cuenta', ',' order by o->'args'->'p_lineas'->0->>'cuenta')
                     from jsonb_array_elements(m.propuesta->'opciones') o))
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', v_caja)), null);
    v_obt := v_obt || ' elegido=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.orden)
                                        from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                       where m.id = v_m);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (17, 'el cajero pregunta caja chica o Edgar, nunca solo', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 18. LA NÓMINA ESPERA su journal (f11): el débito de Gusto no se
--     clasifica sin decir por qué (MX008); cuando el journal está en el
--     libro (su línea del banco por el neto), casa SOLO con él.
do $$
declare
  v_obt text;
  v_esp text := 'antes=pendiente:nomina clasificar=MX008 con_journal=casado:asiento';
  v_m   uuid;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (18, 'la nómina espera su journal y casa sola con él', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C8');
    v_obt := 'antes=' || pg_temp.c6_est('1098', 'C6C8');
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "6130"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    -- El journal de la nómina (como lo pondrá f11): el neto sale del banco.
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'origen_tabla', 'nomina_c6_pruebas', 'origen_id', 'c6-pruebas-1',
      'fecha', (select m.fecha - 1 from movimientos_banco m where m.id = v_m)::text,
      'descripcion', 'c6-pruebas: journal de nómina (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2210', 'monto', '4000.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-4000.00'))));
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || ' clasificar=' || v_x || ' con_journal=' || pg_temp.c6_est('1098', 'C6C8');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (18, 'la nómina espera su journal y casa sola con él', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 19. LAS REGLAS FIJAS, solo cuando todo lo dice: el interés de la reserva
--     (tipo INT, entra dinero, «INTEREST PAYMENT») → 4910 y el cargo
--     mensual del banco (SRVCHG, sale, «MONTHLY SERVICE FEE») → 6130,
--     automáticos. El mismo cargo de tipo DEBIT (solo el descriptor lo
--     dice) no es automático: se propone.
do $$
declare
  v_obt text;
  v_esp text := 'interes=casado:regla:4910 cargo=casado:regla:6130 solo_descriptor=pendiente:cargo_banco';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (19, 'reglas fijas: 4910 y 6130 automáticas solo con tipo, signo y descriptor', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-16.00', 'id', 'C6F2', 'nombre', 'MONTHLY SERVICE FEE'))),
              '1098', 'c6-pruebas-reglas.qfx');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('1098');
    v_obt := format('interes=%s:%s cargo=%s:%s solo_descriptor=%s', pg_temp.c6_est('1097', 'C6R2'),
                    (select m.casado_ref from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6R2')),
                    pg_temp.c6_est('1098', 'C6C11'),
                    (select m.casado_ref from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C11')),
                    pg_temp.c6_est('1098', 'C6F2'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (19, 'reglas fijas: 4910 y 6130 automáticas solo con tipo, signo y descriptor', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 20. EL PAGO A UN PROVEEDOR (su nombre en la descripción) se aplica a sus
--     partidas abiertas de 2010, nunca a 5100: la bandeja lo propone, y
--     fn_banco_pagar_proveedor postea Dr 2010 con la partida del recibo /
--     Cr el banco; la partida queda en cero. Clasificarlo a un costo sin
--     decir por qué no entra (el gasto ya entró con el ticket).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=pago_proveedor a_costo=MX008 pagado=casado:pago_proveedor lineas=1098:-850.00|2010:850.00:recibos/-660003 '
                  'partida=0.00 a_5100=0';
  v_esc  jsonb;
  v_m    uuid;
  v_x    text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (20, 'pago a proveedor: Dr 2010 por sus partidas, nunca 5100', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C10');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                  null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform pg_temp.c6_como('dueno');
    perform fn_banco_pagar_proveedor(v_m, (v_esc->>'proveedor')::uuid, null);
    execute 'reset role';
    select v_obt || format(' a_costo=%s pagado=%s lineas=%s partida=%s a_5100=%s', v_x, pg_temp.c6_est('1098', 'C6C10'),
                           (select string_agg(l.cuenta || ':' || l.monto || coalesce(':' || l.partida_tabla || '/' || l.partida_id, ''),
                                              '|' order by l.orden)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           (select coalesce(sum(l.monto), 0) from asiento_lineas l
                             where l.cuenta = '2010' and l.partida_tabla = 'recibos' and l.partida_id = '-660003'),
                           (select count(*) from asiento_lineas l where l.asiento_id = m.asiento_id and l.cuenta = '5100'))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (20, 'pago a proveedor: Dr 2010 por sus partidas, nunca 5100', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 21. LOS PRÉSTAMOS: la cuota del banco se propone con la partición de la
--     fórmula (interés = round(saldo × tasa / 12)); registrada, Dr 2520
--     capital / Dr 7100 interés / Cr el banco, casada. Con el statement
--     del prestamista, manda él. Una cuota sin movimiento (el banco no ha
--     llegado) y el cargo, cuando llega, casa solo con ella. Y lo que dice
--     el libro en 2520 es lo que se debe (el control «préstamos»).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=cuota_prestamo formula=interes:182.99,capital:846.34 cuota1=1098:-1029.33|2520:846.34|7100:182.99 '
                 'cuota2=statement:850.00/179.33 sin_mov=casado:cuota_prestamo saldo=28870.30 libro_2520=28870.30 control=igual';
  v_p    uuid;
  v_m    uuid;
  v_pos  bigint;
  v_ok0  boolean;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (21, 'préstamos: fórmula, statement, cuota sin movimiento y 2520 = lo que se debe', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c where c.vista = 'cuadre: préstamos');
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS CREDIT', 'descripcion', 'camioneta de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS CREDIT'))->>'id')::uuid;
    -- El saldo del préstamo en el libro (la apertura lo traerá de QuickBooks; aquí, a mano en el mes).
    perform fn_postear(jsonb_build_object('fecha', (d - 1 + 1)::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1029.33', 'id', 'C6L1', 'nombre', 'C6 PRUEBAS CREDIT PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-1029.33', 'id', 'C6L2', 'nombre', 'C6 PRUEBAS CREDIT PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 17, 'monto', '-1029.33', 'id', 'C6L3', 'nombre', 'C6 PRUEBAS CREDIT PMT'))),
              '1098', 'c6-pruebas-prestamo.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6L1');
    select format('propuesta=%s formula=interes:%s,capital:%s', m.propuesta->>'motivo', m.propuesta->'particion'->>'interes',
                  m.propuesta->'particion'->>'capital')
      into v_obt from movimientos_banco m where m.id = v_m;
    perform pg_temp.c6_como('dueno');
    perform fn_prestamo_cuota(v_p, v_m);
    execute 'reset role';
    v_obt := v_obt || ' cuota1=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.cuenta)
                                       from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                      where m.id = v_m);
    perform fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6L2'), null, null, '850.00', null, 'c6-pruebas: statement');
    v_obt := v_obt || ' cuota2=' || (select q.fuente || ':' || q.capital || '/' || q.interes from prestamo_cuotas q
                                      where q.movimiento_id = pg_temp.c6_mov('1098', 'C6L2'));
    -- La tercera, registrada ANTES de que llegue su cargo (sin movimiento):
    -- el cargo del día 17 casa solo con su línea del banco.
    perform fn_prestamo_cuota(v_p, null, d + 17, '1029.33', '848.62', '180.71', 'c6-pruebas: antes que el banco');
    perform fn_banco_casar_todo('1098');
    -- (Lo que el libro dice de ESTE préstamo: lo que la prueba movió en 2520.
    -- Y el control dice lo mismo que antes de la prueba: sus cifras cuadran
    -- entre sí, y lo que ya había, igual que antes.)
    v_obt := v_obt || format(' sin_mov=%s saldo=%s libro_2520=%s control=%s', pg_temp.c6_est('1098', 'C6L3'),
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p),
                             (select -sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '2520'),
                             case when (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c
                                         where c.vista = 'cuadre: préstamos') is not distinct from v_ok0 then 'igual' else 'cambió' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (21, 'préstamos: fórmula, statement, cuota sin movimiento y 2520 = lo que se debe', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 22. LOS PREPAGADOS: una póliza de seguro que empezó en agosto (lo de
--     agosto y septiembre lo amortizó QuickBooks: llega con su saldo al
--     corte, 4,000.00, y el libro lo amortiza por días del corte a su fin)
--     y la prima de WC que empieza a mitad del mes (el mes parcial, por
--     días): un asiento estándar por mes y otro para WC (5015 contra 1410,
--     aparte: c3 no deja la mano de obra con otras cuentas); otra vez el
--     mismo mes, nada (idempotente); la póliza corregida (su monto sube
--     200.00, que van a lo que falta) rehace el mes (reverso y el bueno);
--     lo que dice el libro en 1410 es lo que falta por amortizar.
do $$
declare
  v_obt  text;
  v_esp  text := 'gl=407.89 wc=170.00 asientos=2 wc_solo=1410,5015 otra_vez=sin_cambios corregida=reverso+428.29 libro_1410=igual';
  v_gl   uuid;
  v_x    jsonb;
  v_pos  bigint;
  v_ok0  boolean;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
  v_ini  date;
  v_fin  date;
begin
  if d is null then
    insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  -- La póliza de GL empieza dos meses antes del corte y dura un año (365
  -- días); la de WC, a mitad del mes (el día 15) y dura 365 días.
  v_ini := (fn_puente_corte() - interval '2 months')::date;
  v_fin := (v_ini + interval '1 year')::date - 1;
  if d <> fn_puente_corte() or v_fin - v_ini + 1 <> 365 or extract(day from (d + interval '1 month')::date - 1) <> 31 then
    insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte (octubre)', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prepagados']) c where c.vista = 'cuadre: prepagados');
    v_gl := (fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL', 'tipo', 'seguro', 'cuenta_gasto', '6200',
               'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text, 'saldo_corte', '4000.00'))->>'id')::uuid;
    perform fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas WC', 'tipo', 'seguro', 'cuenta_gasto', '5015',
               'monto', '3650.00', 'desde', (d + 14)::text, 'hasta', (d + 14 + 364)::text));
    -- Lo que falta de GL (de la apertura) y la prima de WC pagada: en el libro.
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que falta de GL y WC (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '7650.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-7650.00'))));
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    select format('gl=%s wc=%s asientos=%s wc_solo=%s',
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_gl and a.vigente),
                  (select a.monto from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                    where p.descripcion = 'c6-pruebas WC' and a.vigente),
                  (select count(distinct a.asiento_id) from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                    where p.descripcion like 'c6-pruebas%' and a.vigente),
                  (select string_agg(distinct l.cuenta, ',' order by l.cuenta) from asiento_lineas l
                    where l.asiento_id = (select a.asiento_id from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                                           where p.descripcion = 'c6-pruebas WC' and a.vigente)))
      into v_obt;
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    v_obt := v_obt || ' otra_vez=' || case when (select bool_and((e->>'sin_cambios')::boolean) from jsonb_array_elements(v_x->'asientos') e
                                                  where e ? 'sin_cambios') and not exists (select 1 from jsonb_array_elements(v_x->'asientos') e
                                                                                              where e ? 'reverso')
                                           then 'sin_cambios' else v_x::text end;
    perform fn_prepagado_guardar(jsonb_build_object('id', v_gl, 'monto', '5000.00'));
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: la diferencia de la póliza (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '200.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-200.00'))));
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    v_obt := v_obt || ' corregida=' || case when exists (select 1 from jsonb_array_elements(v_x->'asientos') e where e ? 'reverso')
                                            then 'reverso+' else '' end
             || (select a.monto::text from prepagados_amortizaciones a where a.prepagado_id = v_gl and a.vigente);
    v_obt := v_obt || ' libro_1410=' || case when (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prepagados']) c
                                                    where c.vista = 'cuadre: prepagados') is not distinct from v_ok0
                                             then 'igual' else 'cambió' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- La conciliación
-- =====================================================================

-- 23. SE CONFIRMA CON SUS PARTIDAS EN TRÁNSITO: al corte (el día 20), un
--     cheque que el banco cobra después (en circulación) y un depósito del
--     último día que el banco trae después (en tránsito). Libros = banco +
--     en tránsito − en circulación: diferencia 0.00, se confirma, y queda
--     quién, cuándo y la huella de sus partidas. Cada partida dice qué es
--     (y cuándo lo trajo el banco).
do $$
declare
  v_obt text;
  v_esp text := 'transito=2 dep=900.00 car=400.00 dif=0.00 confirmada=t quien=t huella=t explica=t';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (23, 'se confirma con partidas en tránsito y diferencia 0.00', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- En el libro: el cheque 2001 del día 18 y el depósito del 20.
    perform fn_postear(jsonb_build_object('fecha', (d + 17)::text, 'descripcion', 'c6-pruebas: cheque 2001 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6200', 'monto', '400.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-400.00'))));
    perform fn_postear(jsonb_build_object('fecha', (d + 19)::text, 'descripcion', 'c6-pruebas: depósito del 20 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '900.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-900.00'))));
    -- El banco los trae después del corte.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 21, 'monto', '900.00', 'id', 'C6K1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 20, 'monto', '-400.00', 'id', 'C6K2', 'nombre', 'CHECK 2001',
                                 'cheque', '2001'))), '1098', 'c6-pruebas-conc.qfx');
    perform fn_banco_casar_todo('1098');
    perform pg_temp.c6_como('dueno');
    v_c := fn_conciliar('1098', d + 19, '0.00');
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    execute 'reset role';
    select format('transito=%s dep=%s car=%s dif=%s confirmada=%s quien=%s huella=%s explica=%s', c.n_transito, c.depositos_transito,
                  c.cargos_circulacion, c.diferencia, c.estado = 'confirmada',
                  c.confirmada_por = nullif(current_setting('mx6.dueno'), '')::uuid and c.confirmada_el is not null,
                  c.hash_partidas ~ '^[0-9a-f]{64}$',
                  (select bool_and(p.explicacion like '%trae el %' and p.explicacion like '%después del corte%')
                     from conciliacion_partidas p where p.conciliacion_id = c.id))
      into v_obt
      from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (23, 'se confirma con partidas en tránsito y diferencia 0.00', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 24. SIN CUADRAR NO SE CONFIRMA: sin el saldo del statement (y sin
--     archivo con saldo a esa fecha) no; con un saldo que no cuadra
--     (diferencia 10.00) tampoco, y dice cuánto (MX008). Con el bueno, sí
--     (el aporte del libro que el banco todavía no trae va en tránsito: el
--     banco dice 0.00).
do $$
declare
  v_obt text := '';
  v_esp text := 'sin_saldo=MX008 mal=MX008:10.00 bien=confirmada';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (24, 'sin saldo o con diferencia no se confirma; con 0.00 sí', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: aporte (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '250.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-250.00'))));
    v_c := fn_conciliar('1098', d + 9);
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'sin_saldo=' || v_x;
    v_c := fn_conciliar('1098', d + 9, '10.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate || case when sqlerrm like '%10.00%' then ':10.00' else '' end;
    end;
    v_obt := v_obt || ' mal=' || v_x;
    v_c := fn_conciliar('1098', d + 9, '0.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := (select c.estado from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid);
    exception when others then v_x := sqlstate || ' ' || left(sqlerrm, 80);
    end;
    v_obt := v_obt || ' bien=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (24, 'sin saldo o con diferencia no se confirma; con 0.00 sí', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 25. LO DEL BANCO SIN CASAR BLOQUEA: un movimiento pendiente al corte
--     (aunque la diferencia dé 0.00) no deja confirmar; casado o
--     clasificado, sí.
do $$
declare
  v_obt text;
  v_esp text := 'dif=0.00 sin_casar=1 confirmar=MX008 clasificado_y_confirmada=t';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (25, 'un movimiento sin casar bloquea la confirmación', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, -33.33, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-33.33', 'id', 'C6B1', 'nombre', 'C6 CARGO RARO'))),
              '1098', 'c6-pruebas-bloquea.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 9, '-33.33');
    v_obt := format('dif=%s sin_casar=%s', v_c->>'diferencia', v_c->>'n_sin_casar');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6B1'), '[{"cuenta": "6130"}]'::jsonb, null);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_obt := v_obt || ' confirmar=' || v_x || ' clasificado_y_confirmada='
             || (select (c.estado = 'confirmada')::text from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (25, 'un movimiento sin casar bloquea la confirmación', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 26. MÁS DE 30 DÍAS EN TRÁNSITO: un cheque del libro que el banco no
--     trae en 30 días sale como ALARMA (con cuántos días); no frena la
--     confirmación, pero se dice al confirmar. La clase y el motivo que
--     Edgar le pone (fn_conciliacion_partida) se quedan al recalcular.
do $$
declare
  v_obt text;
  v_esp text := 'alarmas=1 dias=31 motivo=se_queda confirmada=t dicha=1';
  v_c   jsonb;
  v_p   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (26, 'más de 30 días en tránsito: alarma, sin frenar', v_esp, 'omitida: falta el mes abierto y el siguiente',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('fecha', (d + 1)::text, 'descripcion', 'c6-pruebas: cheque 3001 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6200', 'monto', '75.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-75.00'))));
    v_c := fn_conciliar('1098', d + 32, '0.00');
    select p.id into v_p from conciliacion_partidas p where p.conciliacion_id = (v_c->>'conciliacion')::uuid;
    perform fn_conciliacion_partida(v_p, 'cargo_en_circulacion', 'c6-pruebas: el cheque 3001 lo tiene el cliente');
    v_c := fn_conciliar('1098', d + 32);
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    select format('alarmas=%s dias=%s motivo=%s confirmada=%s dicha=%s', c.n_alarmas, p.dias,
                  case when p.motivo = 'c6-pruebas: el cheque 3001 lo tiene el cliente' then 'se_queda' else coalesce(p.motivo, '-') end,
                  (c.estado = 'confirmada')::text, jsonb_array_length(v_c->'alarmas'))
      into v_obt
      from conciliaciones c join conciliacion_partidas p on p.conciliacion_id = c.id
     where c.id = (v_c->>'conciliacion')::uuid;
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (26, 'más de 30 días en tránsito: alarma, sin frenar', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 27. CONFIRMADA NO SE TOCA: ni por update (MX003), ni sus partidas, ni
--     recalculándola (MX008), ni des-casando un movimiento que está dentro
--     (MX008: se reabre antes).
-- 28. REABRIR deja rastro: con su motivo (sin él no), quién y cuándo, y en
--     banco_historial el antes (confirmada) y el después (abierta); se
--     recalcula y se confirma otra vez.
do $$
declare
  v_obt  text := '';
  v_obt2 text := '';
  v_esp  text := 'update=MX003 partida=MX003 conciliar=MX008 descasar=MX008';
  v_esp2 text := 'sin_motivo=22023 reabierta=abierta motivo=t historial=confirmada>abierta otra_vez=confirmada';
  v_c    jsonb;
  v_id   uuid;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (27, 'una conciliación confirmada no se toca', v_esp, 'omitida: falta mes abierto', null),
                                (28, 'reabrir una confirmada: con motivo y con rastro', v_esp2, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: aporte (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '250.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-250.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 250.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 3, 'monto', '250.00', 'id', 'C6Q1', 'nombre', 'DEPOSIT'))),
              '1098', 'c6-pruebas-confirmada.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 9);
    v_id := (v_c->>'conciliacion')::uuid;
    perform fn_conciliacion_confirmar(v_id);
    begin
      update conciliaciones set saldo_statement = 1 where id = v_id;
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'update=' || v_x;
    begin
      insert into conciliacion_partidas (conciliacion_id, lado, clase, fecha, monto) values (v_id, 'libro', 'error', d, 1);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' partida=' || v_x;
    begin
      perform fn_conciliar('1098', d + 9, '250.00');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' conciliar=' || v_x;
    begin
      perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6Q1'), 'c6-pruebas: estaba mal');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' descasar=' || v_x;
    -- 28
    begin
      perform fn_conciliacion_reabrir(v_id, ' ');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt2 := 'sin_motivo=' || v_x;
    perform pg_temp.c6_como('dueno');
    perform fn_conciliacion_reabrir(v_id, 'c6-pruebas: faltaba un cargo');
    execute 'reset role';
    select format(' reabierta=%s motivo=%s historial=%s', c.estado,
                  c.reabierta_motivo = 'c6-pruebas: faltaba un cargo' and c.reabierta_por = nullif(current_setting('mx6.dueno'), '')::uuid
                    and c.reabierta_el is not null,
                  (select h.antes->>'estado' || '>' || (h.despues->>'estado') from banco_historial h
                    where h.tabla = 'conciliaciones' and h.clave = v_id::text and h.antes->>'estado' = 'confirmada'
                    order by h.cambiado_el desc limit 1))
      into v_x from conciliaciones c where c.id = v_id;
    v_obt2 := v_obt2 || replace(v_x, '=true', '=t');
    perform fn_conciliar('1098', d + 9);
    perform fn_conciliacion_confirmar(v_id);
    v_obt2 := v_obt2 || ' otra_vez=' || (select c.estado from conciliaciones c where c.id = v_id);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (27, 'una conciliación confirmada no se toca', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false)),
                              (28, 'reabrir una confirmada: con motivo y con rastro', v_esp2, coalesce(v_obt2, '-'),
                               coalesce(v_obt2 = v_esp2, false));
end $$;

-- 29. LA TARJETA SE CONCILIA A SU FECHA DE CORTE (la del statement, no fin
--     de mes), con el saldo del archivo (lo que se debe, en negativo) o el
--     que escribe Edgar (en positivo, como lo dice el statement): igual.
--     Lo que casó sale en el grupo «casado» con su asiento.
do $$
declare
  v_obt text;
  v_esp text := 'corte=+22 libros=-1173.26 banco=-1173.26 dif=0.00 escrito=-1173.26 casados=5 confirmada=t';
  v_c   jsonb;
  v_id  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_m   uuid;
begin
  if d is null then
    insert into _pruebas values (29, 'la tarjeta se concilia a su fecha de corte', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    -- (lo que esperaba: la compra sin ticket y el interés, clasificados)
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: material sin ticket');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    -- (el pago desde el banco, ya casado con los dos lados)
    v_c := fn_conciliar('2100-9996', d + 22);
    v_id := (v_c->>'conciliacion')::uuid;
    select format('corte=+%s libros=%s banco=%s dif=%s', c.fecha_corte - d, c.saldo_libros, c.saldo_banco, c.diferencia)
      into v_obt from conciliaciones c where c.id = v_id;
    v_c := fn_conciliar('2100-9996', d + 22, '1,173.26');
    v_obt := v_obt || format(' escrito=%s casados=%s', v_c->>'saldo_banco',
                             (select count(*) from v_conciliacion_partidas p where p.conciliacion_id = v_id and p.grupo = 'casado'
                                and p.asiento_numero is not null));
    perform fn_conciliacion_confirmar(v_id);
    v_obt := v_obt || ' confirmada=' || (select (c.estado = 'confirmada')::text from conciliaciones c where c.id = v_id);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (29, 'la tarjeta se concilia a su fecha de corte', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 30. LA CONCILIACIÓN DE APERTURA (30-sep, la era QuickBooks): el cheque
--     1043 que estaba en circulación entra como partida; confirmada, el
--     cheque que cobra el banco en octubre casa SOLO con ella (por su
--     número y su monto), sin asiento (ya está en la apertura); la partida
--     dice con qué movimiento llegó, y la conciliación de octubre ya no la
--     trae.
do $$
declare
  v_obt text;
  v_esp text := 'apertura=confirmada cheque=casado:apertura sin_asiento=t resuelta=t en_octubre=0';
  v_c   jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (30, 'la conciliación de apertura: su cheque en circulación casa solo en octubre', v_esp,
                                 'omitida: falta mes abierto o la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- Sin asiento de apertura todavía (recién pegado), uno de prueba: la
    -- conciliación de apertura concilia su saldo. (Si ya está la de verdad,
    -- esa vale: la cuenta de prueba no tiene saldo en ella.)
    if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
      if (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) <> 'abierto' then
        raise exception using errcode = 'MXT01';
      end if;
      perform fn_postear(jsonb_build_object('tipo', 'apertura',
        'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
        'descripcion', 'c6-pruebas: apertura de prueba (se deshace)',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '1.00'),
                                    jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
    end if;
    v_c := fn_conciliacion_apertura('1098', '1200.00', jsonb_build_array(jsonb_build_object(
             'fecha', (d - 3)::text, 'monto', '-1200.00', 'cheque', '1043', 'descripcion', 'c6-pruebas: cheque 1043')));
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_obt := 'apertura=' || (v_c->>'estado');
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C1');
    v_obt := v_obt || format(' cheque=%s sin_asiento=%s resuelta=%s', pg_temp.c6_est('1098', 'C6C1'),
                             (select m.asiento_id is null from movimientos_banco m where m.id = v_m),
                             exists (select 1 from conciliacion_partidas p where p.resuelta_por_movimiento = v_m));
    v_c := fn_conciliar('1098', d + 27, '0.00');
    v_obt := v_obt || ' en_octubre=' || (select count(*) from conciliacion_partidas p
                                          where p.conciliacion_id = (v_c->>'conciliacion')::uuid and p.apertura_partida_id is not null);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (30, 'la conciliación de apertura: su cheque en circulación casa solo en octubre', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;


-- =====================================================================
-- Deshacer, y lo que no se toca
-- =====================================================================

-- 31. UN CHEQUE DEVUELTO: el depósito rebotado se propone como devolución
--     del cobro; fn_banco_devolver la registra con fn_cobro_devolver (c3)
--     en la fecha del banco y con este movimiento: Dr 1110 / Cr el banco.
--     El depósito se queda casado en su día.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=devolucion devuelto=casado:devolucion devolucion_dice=el_movimiento lineas=1098:-1500.00|1110:1500.00 '
                'deposito=casado:cobro';
  v_esc jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (31, 'cheque devuelto: la devolución del cobro con su movimiento', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 12, d + 13, 0.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 13, 'monto', '-1500.00', 'id', 'C6D1', 'nombre', 'DEPOSITED ITEM RETURNED'))),
              '1098', 'c6-pruebas-devuelto.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6D1');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    perform pg_temp.c6_como('dueno');
    perform fn_banco_devolver(v_m, (v_esc->>'cobro')::uuid, 'c6-pruebas: sin fondos');
    execute 'reset role';
    select v_obt || format(' devuelto=%s devolucion_dice=%s lineas=%s deposito=%s', pg_temp.c6_est('1098', 'C6D1'),
                           (select case when dv.movimiento_id = v_m::text then 'el_movimiento' else coalesce(dv.movimiento_id, '-') end
                              from cobros_devoluciones dv where dv.cobro_id = (v_esc->>'cobro')::uuid),
                           (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           pg_temp.c6_est('1098', 'C6C3'))
      into v_obt from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (31, 'cheque devuelto: la devolución del cobro con su movimiento', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 32. DES-CASAR, con su motivo (sin él, no): lo que puso el banco (el
--     Zelle de Edgar clasificado) se reversa con el motivo y el movimiento
--     vuelve a la bandeja con su propuesta; lo que solo se casó (el
--     depósito con su cobro) se suelta, y el cobro suelta su movimiento
--     (la marca de c3) sin volver a casar solo (lo que Edgar des-casó lo
--     elige él); la transferencia se reversa y suelta sus DOS lados. Cada
--     casado deshecho queda con quién, cuándo y por qué.
do $$
declare
  v_obt text;
  v_esp text := 'sin_motivo=22023 clasificado=pendiente:aporte_edgar reversado=t cobro=pendiente cobro_suelto=t '
                'transferencia=pendiente+pendiente rastro=3';
  v_esc jsonb;
  v_x   text;
  v_c5  uuid;
  v_c3  uuid;
  v_c7  uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (32, 'des-casar: con motivo; reversa lo que puso, suelta lo demás; queda el rastro', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6C5'), '[{"cuenta": "2900"}]'::jsonb, 'c6-pruebas');
    begin
      perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6C5'), '');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'sin_motivo=' || v_x;
    v_c5 := pg_temp.c6_mov('1098', 'C6C5');
    v_c3 := pg_temp.c6_mov('1098', 'C6C3');
    v_c7 := pg_temp.c6_mov('1098', 'C6C7');
    perform pg_temp.c6_como('dueno');
    perform fn_banco_descasar(v_c5, 'c6-pruebas: era un aporte');
    perform fn_banco_descasar(v_c3, 'c6-pruebas: era otro depósito');
    perform fn_banco_descasar(v_c7, 'c6-pruebas: no era el pago de la tarjeta');
    execute 'reset role';
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' clasificado=%s reversado=%s cobro=%s cobro_suelto=%s transferencia=%s+%s rastro=%s',
               pg_temp.c6_est('1098', 'C6C5'),
               exists (select 1 from banco_casados c join asientos r on r.reversa_a = c.asiento_id and r.id = c.reverso_id
                        where c.movimiento_id = pg_temp.c6_mov('1098', 'C6C5') and c.deshecho_motivo = 'c6-pruebas: era un aporte'),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C3')),
               (select c.movimiento_id is null from cobros c where c.id = (v_esc->>'cobro')::uuid),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C7')),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('2100-9996', 'C6A3')),
               (select count(*) from banco_casados c
                 where c.deshecho_el is not null and c.deshecho_por = nullif(current_setting('mx6.dueno'), '')::uuid
                   and c.deshecho_motivo like 'c6-pruebas:%'));
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (32, 'des-casar: con motivo; reversa lo que puso, suelta lo demás; queda el rastro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 33. LO QUE DIJO EL BANCO NO SE TOCA (MX003), ni desde el SQL Editor:
--     cambiar o borrar un movimiento, cambiar un archivo, borrar un
--     casado, escribir en el historial a mano, vaciar la tabla, o poner un
--     casado sin su función.
do $$
declare
  v_obt text := '';
  v_esp text := 'monto=MX003 borrar=MX003 archivo=MX003 casado=MX003 historial=MX003 truncate=MX003 casado_a_mano=MX003';
  v_k   text;
  v_q   text;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (33, 'lo que dijo el banco no se edita ni se borra (MX003)', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    for v_k, v_q in select * from (values
        ('monto', format('update public.movimientos_banco set monto = monto + 1 where id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('borrar', format('delete from public.movimientos_banco where id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('archivo', 'update public.archivos_banco set texto = texto || '' '' where nombre = ''c6-pruebas-chase.qfx'''),
        ('casado', format('delete from public.banco_casados where movimiento_id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('historial', 'insert into public.banco_historial (tabla, clave, operacion) values (''movimientos_banco'', ''x'', ''UPDATE'')'),
        ('truncate', 'truncate public.movimientos_banco cascade'),
        ('casado_a_mano', format('update public.movimientos_banco set estado = ''ignorado'', estado_motivo = ''a mano'' where id = %L',
                                 pg_temp.c6_mov('1098', 'C6C4')))) as x(k, q) loop
      begin
        execute 'set local lock_timeout = ''2s''';
        execute v_q;
        v_x := 'entró';
      exception when others then v_x := sqlstate;
      end;
      v_obt := v_obt || v_k || '=' || v_x || ' ';
    end loop;
    v_obt := rtrim(v_obt);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := v_obt || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (33, 'lo que dijo el banco no se edita ni se borra (MX003)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 34. EL EQUIPO Y ANON no ven nada del banco: el equipo (authenticated, no
--     dueño) lee 0 filas en cada vista y tabla, y no ejecuta ninguna
--     función del banco (42501, por dentro); anon ni abre las vistas ni
--     ejecuta nada (42501).
do $$
declare
  v_obt  text;
  v_esp  text := 'equipo_filas=0 equipo_importar=42501 equipo_casar=42501 equipo_control=42501 anon_vista=42501 anon_casar=42501';
  v_n    bigint := 0;
  v_x    bigint;
  v_v    text;
  v_r    text;
  v_txt  text;
  v_e1   text;
  v_e2   text;
  v_e3   text;
  v_a1   text;
  v_a2   text;
begin
  if current_setting('mx6.equipo', true) = '' or current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (34, 'el equipo y anon no ven ni ejecutan nada del banco', v_esp,
                                 'omitida: no hay nadie del equipo activo, o falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_txt := pg_temp.c6_chase();
    perform pg_temp.c6_como('equipo');
    foreach v_v in array array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion', 'v_conciliacion_partidas',
                               'v_prestamos', 'v_prepagados', 'v_papel_fases', 'movimientos_banco', 'archivos_banco', 'banco_casados',
                               'banco_historial', 'conciliaciones', 'prestamos', 'prepagados'] loop
      execute format('select count(*) from public.%I', v_v) into v_x;
      v_n := v_n + v_x;
    end loop;
    begin perform fn_banco_importar_ofx(v_txt, '1098', 'x'); v_e1 := 'entró'; exception when others then v_e1 := sqlstate; end;
    begin perform fn_banco_casar_todo(null, null); v_e2 := 'entró'; exception when others then v_e2 := sqlstate; end;
    begin perform * from fn_banco_control('hoy', null); v_e3 := 'entró'; exception when others then v_e3 := sqlstate; end;
    execute 'reset role';
    perform pg_temp.c6_como('anon');
    begin execute 'select count(*) from public.v_banco_movimientos' into v_x; v_a1 := 'entró'; exception when others then v_a1 := sqlstate; end;
    begin perform fn_banco_casar_todo(null, null); v_a2 := 'entró'; exception when others then v_a2 := sqlstate; end;
    execute 'reset role';
    v_obt := format('equipo_filas=%s equipo_importar=%s equipo_casar=%s equipo_control=%s anon_vista=%s anon_casar=%s', v_n, v_e1, v_e2,
                    v_e3, v_a1, v_a2);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (34, 'el equipo y anon no ven ni ejecutan nada del banco', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 35. TODA CIFRA BAJA: cada movimiento casado (salvo el de la apertura, que
--     no tiene asiento) lleva su asiento con su número y su papel, y
--     v_asiento_papel (c4) encuentra el papel de cada asiento que puso el
--     banco (el movimiento, la cuota, el mes de prepagados); cada partida
--     de una conciliación baja a su asiento o a su movimiento.
do $$
declare
  v_obt text;
  v_esp text := 'movimientos_sin_asiento=0 asientos_sin_papel=0 papel_del_banco=t partidas_sin_clic=0';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (35, 'toda cifra del banco baja a su asiento, su papel y su movimiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6C6'), '[{"cuenta": "1050"}]'::jsonb, null);
    v_c := fn_conciliar('1098', d + 27, '-396.73');
    select format('movimientos_sin_asiento=%s', count(*) filter (where v.estado in ('casado', 'en_transito')
                                                                   and v.casado_clase <> 'apertura'
                                                                   and (v.asiento_numero is null or v.papel_tabla is null)))
      into v_obt
      from v_banco_movimientos v where v.cuenta in ('1098', '2100-9996', '1097');
    select v_obt || format(' asientos_sin_papel=%s papel_del_banco=%s',
                           count(*) filter (where not p.papel_existe),
                           bool_and(p.papel like 'Movimiento del banco%') filter (where p.origen_tabla = 'movimientos_banco'))
      into v_obt
      from v_asiento_papel p
     where p.origen_tabla in ('movimientos_banco', 'prestamo_cuotas', 'prepagados')
       and p.asiento_id in (select m.asiento_id from movimientos_banco m where m.cuenta in ('1098', '2100-9996', '1097'));
    v_obt := v_obt || ' partidas_sin_clic=' || (select count(*) from v_conciliacion_partidas p
                                                 where p.conciliacion_id = (v_c->>'conciliacion')::uuid
                                                   and p.asiento_id is null and p.movimiento_id is null and p.apertura_partida_id is null
                                                   and p.grupo <> 'casado');
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (35, 'toda cifra del banco baja a su asiento, su papel y su movimiento', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 36. EL CONTROL que lee conta.js antes de pintar (fn_banco_control, el
--     contrato de fn_estados_control): con todo bien, cada vista con las
--     filas que dicen las tablas y los cuadres en verde; con una vista
--     vacía («esperaba N»), con una que ya no está (falló), con una lista
--     vacía o un nombre que no conoce: en rojo, no se pinta.
do $$
declare
  v_obt text;
  v_esp text := 'bien=t vacia=f:esperaba rota=f:falló lista_vacia=f desconocida=f';
  v_ok  boolean;
  v_det text;
  v_mes text := current_setting('mx6.mes', true);
begin
  if v_mes = '' then
    insert into _pruebas values (36, 'fn_banco_control: en verde con todo; en rojo con una vista vacía o rota', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform pg_temp.c6_como('dueno');
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos']) c
     where c.vista not in ('cuadre: prepagados', 'cuadre: préstamos');
    execute 'reset role';
    v_obt := 'bien=' || case when v_ok then 't' else 'f' end;
    execute 'set local lock_timeout = ''2s''';
    execute format('create or replace view public.v_banco_bandeja with (security_invoker = true) as select * from (%s) x where false',
                   rtrim(pg_get_viewdef('public.v_banco_bandeja'::regclass), '; ' || chr(10)));
    execute 'drop view public.v_conciliacion';
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control(v_mes, array['v_banco_bandeja']) c where c.vista = 'v_banco_bandeja';
    v_obt := v_obt || ' vacia=' || case when v_ok then 't' else 'f' end || case when v_det like '%esperaba%' then ':esperaba' else '' end;
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control(v_mes, array['v_conciliacion']) c where c.vista = 'v_conciliacion';
    v_obt := v_obt || ' rota=' || case when v_ok then 't' else 'f' end || case when v_det like '%falló%' then ':falló' else '' end;
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, '{}'::text[]) c;
    v_obt := v_obt || ' lista_vacia=' || case when v_ok then 't' else 'f' end;
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, array['v_banco_movimiento']) c where c.orden = 0;
    v_obt := v_obt || ' desconocida=' || case when v_ok then 't' else 'f' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (36, 'fn_banco_control: en verde con todo; en rojo con una vista vacía o rota', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 37. c2, c3 Y c4 AL DÍA: con la marca de un c2 anterior (fn_libro_version
--     2026092504), el control del banco lo dice en rojo, con qué volver a
--     pegar; con la de hoy, en verde.
do $$
declare
  v_obt text;
  v_esp text := 'hoy=t viejo=f:c2-libro.sql';
  v_ok  boolean;
  v_det text;
  v_src text;
begin
  select pg_get_functiondef('public.fn_libro_version()'::regprocedure) into v_src;
  select c.ok into v_ok from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: c2, c3 y c4 al día';
  v_obt := 'hoy=' || case when v_ok then 't' else 'f' end;
  begin
    execute 'set local lock_timeout = ''2s''';
    execute replace(v_src, '2026092601', '2026092504');
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control('hoy', array['v_banco_saldos']) c
     where c.vista = 'cuadre: c2, c3 y c4 al día';
    v_obt := v_obt || ' viejo=' || case when v_ok then 't' else 'f' end || case when v_det like '%c2-libro.sql%' then ':c2-libro.sql' else '' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida';
    when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (37, 'c2, c3 y c4 al día (su marca), o el control lo dice', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 38. c2 CONOCE AL BANCO: con el banco trabajando (archivos, casados,
--     asientos del banco, conciliación), el verificador del libro sigue en
--     verde (sus funciones de la app están en su reparto y en sus huellas),
--     y el asiento de un movimiento no se reversa a mano: fn_reversar dice
--     cómo (des-casarlo, MX007). Y ninguna vista del banco nombra
--     cuentas.activa, cuentas.saldo_normal, periodos.estado ni
--     periodos.cerrado_* (les fijaría el tipo, y las pruebas 24 y 66 de c2
--     las reescriben por debajo de sus triggers, como ataque).
do $$
declare
  v_obt text;
  v_esp text := 'libro=t reversar=MX007:fn_banco_descasar fijadas=0';
  v_ok  boolean;
  v_a   uuid;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' or current_setting('mx6.dueno', true) = '' then
    insert into _pruebas values (38, 'c2 conoce al banco: el libro en verde y fn_reversar dice cómo deshacer', v_esp,
                                 'omitida: falta mes abierto o el dueño', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select bool_and(v.ok) into v_ok from fn_verificar_cadena() v where v.control in ('triggers', 'permisos', 'cuadre', 'reversos');
    v_a := (select m.asiento_id from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C11'));
    perform pg_temp.c6_como('dueno');
    begin
      perform fn_reversar(v_a, 'c6-pruebas: a mano');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like '%fn_banco_descasar%' then ':fn_banco_descasar' else '' end;
    end;
    execute 'reset role';
    v_obt := 'libro=' || case when v_ok then 't' else 'f' end || ' reversar=' || v_x || ' fijadas='
             || (select count(*) from pg_depend dp
                   join pg_rewrite rw on rw.oid = dp.objid
                   join pg_class vw on vw.oid = rw.ev_class
                   join pg_attribute at on at.attrelid = dp.refobjid and at.attnum = dp.refobjsubid
                  where dp.classid = 'pg_rewrite'::regclass and dp.refclassid = 'pg_class'::regclass
                    and vw.relnamespace = 'public'::regnamespace
                    and vw.relname in ('v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                                       'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados')
                    and ((dp.refobjid = 'public.cuentas'::regclass and at.attname in ('activa', 'saldo_normal'))
                         or (dp.refobjid = 'public.periodos'::regclass and (at.attname = 'estado' or at.attname like 'cerrado%'))));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (38, 'c2 conoce al banco: el libro en verde y fn_reversar dice cómo deshacer', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 39. LA REVISIÓN ENTERA (fn_banco_verificar, desde el SQL Editor): con el
--     mes casado, una conciliación confirmada (recalculada, da lo mismo) y
--     los archivos leídos otra vez, todo en verde; y los controles de los
--     puentes (c3) también, con los asientos del banco en el libro: ninguno
--     en rojo por algo del escenario (con datos de verdad, un control de c3
--     puede venir en rojo por lo suyo: sale aquí solo si nombra un asiento
--     o un papel de esta prueba; lo demás lo dice c3-pruebas).
do $$
declare
  v_obt   text;
  v_esp   text := 'banco=t puentes=t';
  v_ok    boolean;
  v_ok2   boolean;
  v_c     jsonb;
  v_pos   bigint;
  d       date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (39, 'fn_banco_verificar y los controles de los puentes, en verde con el banco trabajando', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    -- (Dónde va la cadena: los asientos de la prueba son los de después.)
    select coalesce(max(a.cadena_pos), 0) into v_pos from asientos a;
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    -- (Solo las cuentas de la prueba: con un año de banco de verdad, la
    -- revisión entera tarda y la prueba tendría tomados los candados de los
    -- recibos todo ese tiempo.)
    select bool_and(v.ok) into v_ok from fn_banco_verificar(array['1098', '1097', '2100-9996', '2100-9995']) v
     where v.control not in ('control · cuadre: préstamos', 'control · cuadre: prepagados');
    select bool_and(p.ok
                    or not (exists (select 1 from asientos a where a.cadena_pos > v_pos and position(a.numero in p.detalle::text) > 0)
                            or p.detalle::text ~ '(-66[0-9]{4}|C6-|1098|1097|2100-999[56]|c6-pruebas)'))
      into v_ok2 from fn_puentes_verificar() p
     where p.control in ('triggers', 'documentos', 'use_tax', 'mano_de_obra', 'partidas', 'duplicados', 'vistas');
    v_obt := format('banco=%s puentes=%s', case when v_ok then 't' else 'f' end, case when v_ok2 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (39, 'fn_banco_verificar y los controles de los puentes, en verde con el banco trabajando', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- =====================================================================
-- Lo que corrigió la ronda de c6 (una prueba por hallazgo)
-- =====================================================================

-- 40. EL ZELLE DE UN CLIENTE NO ES UNA TRANSFERENCIA: el pago de una
--     tarjeta y el pase a la reserva se reconocen por la descripción del
--     banco (NAME, no la nota que escribe quien manda el dinero) y en su
--     dirección (del banco a la tarjeta). Un Zelle con «thank you» en la
--     nota y una compra de la tarjeta del mismo monto un día antes NO casan
--     solos (antes, como un adelanto de la tarjeta: el cobro no entraba
--     nunca y la compra se contaba dos veces); el Zelle propone la factura
--     que lo explica, sin ninguna transferencia, y la compra espera su
--     ticket.
do $$
declare
  v_obt text;
  v_esp text := 'zelle=pendiente:deposito_sin_cobro compra=pendiente:sin_ticket factura=t transferencias=0 opcion_tarjeta=0';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (40, 'el Zelle de un cliente con «thank you» no se casa como transferencia; propone su factura', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660401, current_setting('mx6.obra'), 'C6-40', d + 1, 3000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, 3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 10, 'monto', '3000.00', 'id', 'C6Z1', 'nombre', 'ZELLE FROM JOHN SMITH',
                                 'memo', 'Inv C6-40 thank you'))), '1098', 'c6-pruebas-zelle.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 12, -3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-3000.00', 'id', 'C6Z2', 'nombre', 'GRAYBAR ELECTRIC CO'))),
              null, 'c6-pruebas-graybar.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('2100-9996');
    select format('zelle=%s compra=%s factura=%s transferencias=%s opcion_tarjeta=%s', pg_temp.c6_est('1098', 'C6Z1'),
                  pg_temp.c6_est('2100-9996', 'C6Z2'),
                  case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o
                                     where o->>'llamar' = 'fn_banco_cobrar') then 't' else 'f' end,
                  (select count(*) from banco_casados c
                    where c.movimiento_id in (pg_temp.c6_mov('1098', 'C6Z1'), pg_temp.c6_mov('2100-9996', 'C6Z2'))
                      and c.clase = 'transferencia'),
                  (select count(*) from jsonb_array_elements(m.propuesta->'opciones') o where o->>'llamar' = 'fn_banco_transferencia'))
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6Z1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (40, 'el Zelle de un cliente con «thank you» no se casa como transferencia; propone su factura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 41. EL PASE A LA RESERVA QUE TARDA (un ACH a otro banco, 3 a 5 días
--     hábiles): dos pases semanales iguales, cada uno con su otro lado (el
--     que llega DESPUÉS de que sale, hasta 10 días), un asiento por pase;
--     el lado que Edgar confirmó primero y el otro que llega 5 días
--     después casa solo con ESE asiento; y fn_banco_transferencia sobre el
--     que llega no postea otra (MX008: antes, el mismo dinero dos veces).
do $$
declare
  v_obt text;
  v_esp text := 'semana1=mismo semana2=mismo asientos=2 otra_transferencia=MX008 otro_lado=casado:transferencia primero=casado';
  v_w5  uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (41, 'el pase a la reserva que tarda días casa con su otro lado, uno por pase, nunca dos', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 14, 1000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-700.00', 'id', 'C6W5', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-500.00', 'id', 'C6W1', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 12, 'monto', '-500.00', 'id', 'C6W2', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'))),
              '1098', 'c6-pruebas-pases.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 17, 1000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 10, 'monto', '500.00', 'id', 'C6W3', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 17, 'monto', '500.00', 'id', 'C6W4', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'))),
              '1097', 'c6-pruebas-reserva-pases.ofx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('1097');
    select format('semana1=%s semana2=%s asientos=%s',
                  case when a1.asiento_id = a3.asiento_id then 'mismo' else 'otro' end,
                  case when a2.asiento_id = a4.asiento_id then 'mismo' else 'otro' end,
                  (select count(distinct m.asiento_id) from movimientos_banco m
                    where m.id in (a1.id, a2.id, a3.id, a4.id)))
      into v_obt
      from movimientos_banco a1, movimientos_banco a2, movimientos_banco a3, movimientos_banco a4
     where a1.id = pg_temp.c6_mov('1098', 'C6W1') and a2.id = pg_temp.c6_mov('1098', 'C6W2')
       and a3.id = pg_temp.c6_mov('1097', 'C6W3') and a4.id = pg_temp.c6_mov('1097', 'C6W4');
    -- El de 700, confirmado por Edgar con un solo lado; su otro lado llega
    -- 5 días después (sin casar todavía).
    v_w5 := pg_temp.c6_mov('1098', 'C6W5');
    perform fn_banco_transferencia(v_w5, '1097');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d + 8, d + 9, 1700.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 8, 'monto', '700.00', 'id', 'C6W6', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'))),
              '1097', 'c6-pruebas-reserva-700.ofx');
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('1097', 'C6W6'), '1098');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' otra_transferencia=%s otro_lado=%s primero=%s', v_x, pg_temp.c6_est('1097', 'C6W6'),
                             (select m.estado from movimientos_banco m where m.id = v_w5));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (41, 'el pase a la reserva que tarda días casa con su otro lado, uno por pase, nunca dos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 42. LO QUE YA ESTÁ EN EL LIBRO A MÁS DE 3 DÍAS DEL BANCO se casa o se
--     propone, no se clasifica otra vez: la compra de la Amex posteada 6
--     días después de su ticket (su DTUSER = la fecha del ticket) casa
--     sola; la de la débito, sin DTUSER, a 6 días también; el cheque 1045
--     anotado a mano casa por su NÚMERO aunque el banco lo cobre 19 días
--     después; el cheque sin su número en el libro (28 días) se propone
--     («puede ser») y clasificarlo sin motivo no entra. Y el texto de un
--     cargo sin ticket no dice «Obra propuesta:  ().» sin obra.
do $$
declare
  v_obt text;
  v_esp text := 'amex=casado:recibo debito=casado:recibo cheque=casado:asiento debil=pendiente:varios_candidatos clasificar=MX008 '
                'texto=sin_hueco';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (42, 'lo del libro a más de 3 días (DTUSER, débito, cheque) se casa o se propone, no se clasifica', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660421, 'total', 89.99, 'fecha', d + 2, 'proveedor', 'SHELL OIL'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660422, 'total', 86.40, 'fecha', d + 4, 'metodo_pago', 'debito',
                                                 'proveedor', 'C6 FERRETERIA'));
    perform fn_postear(jsonb_build_object('fecha', (d + 1)::text, 'descripcion', 'c6-pruebas: la renta con el cheque 1045 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '-1000.00', 'memo', 'Cheque 1045'),
                                  jsonb_build_object('cuenta', '6100', 'monto', '1000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: un pago con cheque (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '-777.00'),
                                  jsonb_build_object('cuenta', '6100', 'monto', '777.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 9, -89.99, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 8, 'fecha_usuario', d + 2, 'monto', '-89.99', 'id', 'C6D1',
                                 'nombre', 'SHELL OIL 57442'))), null, 'c6-pruebas-shell.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, -1909.85, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-86.40', 'id', 'C6D2', 'nombre', 'C6 FERRETERIA #3'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 12, 'monto', '-45.45', 'id', 'C6D5', 'nombre', 'C6 SIN TICKET'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 20, 'monto', '-1000.00', 'id', 'C6D3', 'nombre', 'CHECK 1045',
                                 'cheque', '1045'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 30, 'monto', '-777.00', 'id', 'C6D4', 'nombre', 'CHECK 2001',
                                 'cheque', '2001'))), '1098', 'c6-pruebas-cheques.qfx');
    perform fn_banco_casar_todo('2100-9996');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6D4'), '[{"cuenta": "6100"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('amex=%s debito=%s cheque=%s debil=%s clasificar=%s texto=%s', pg_temp.c6_est('2100-9996', 'C6D1'),
                    pg_temp.c6_est('1098', 'C6D2'), pg_temp.c6_est('1098', 'C6D3'), pg_temp.c6_est('1098', 'C6D4'), v_x,
                    (select case when m.propuesta->>'texto' like '%()%' then 'con_hueco' else 'sin_hueco' end
                       from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6D5')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (42, 'lo del libro a más de 3 días (DTUSER, débito, cheque) se casa o se propone, no se clasifica', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 43. LA CUOTA YA REGISTRADA con el statement del prestamista (antes que
--     el banco) espera su cargo: si el cargo llega 14 días después, la
--     bandeja propone casar con ELLA (no registrar otra), fn_prestamo_cuota
--     no registra otra (MX008: antes, dos cuotas en el mes, capital e
--     interés dos veces), y casarla deja una sola cuota viva.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=cuota_prestamo:fn_banco_casar_con otra_cuota=MX008 casado=casado:cuota_prestamo cuotas=1';
  v_p   uuid;
  v_m   uuid;
  v_x   text;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (43, 'la cuota ya registrada espera su cargo: se casa con ella, no se registra otra', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS CREDIT', 'descripcion', 'camioneta de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS CREDIT'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_prestamo_cuota(v_p, null, d + 5, '1029.33', '848.62', '180.71', 'c6-pruebas: del statement');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-1029.33', 'id', 'C6Q1', 'nombre', 'C6 PRUEBAS CREDIT PMT'))),
              '1098', 'c6-pruebas-cuota.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6Q1');
    select m.propuesta->'opciones'->0, format('propuesta=%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->>'llamar')
      into v_op, v_obt
      from movimientos_banco m where m.id = v_m;
    begin
      perform fn_prestamo_cuota(v_p, v_m);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_casar_con(v_m, v_op->'args'->'p_con', null);
    v_obt := v_obt || format(' otra_cuota=%s casado=%s cuotas=%s', v_x, pg_temp.c6_est('1098', 'C6Q1'),
                             (select count(*) from prestamo_cuotas q where q.prestamo_id = v_p and q.anulada_el is null));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (43, 'la cuota ya registrada espera su cargo: se casa con ella, no se registra otra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 44. EL TICKET QUE LLEGA DESPUÉS DE CLASIFICAR su cargo ya no pasa
--     callado: el cargo sale en la bandeja («llego_su_ticket»), el control
--     lo dice en rojo, la conciliación lo pone como posible duplicado (no
--     como cargo en circulación) y no se confirma; «no es su ticket» pide
--     su motivo; cambiar la clasificación por el ticket (fn_banco_casar_con)
--     reversa la clasificación, casa el cargo con el ticket y deja el gasto
--     una vez; y entonces el control y la conciliación, en verde.
do $$
declare
  v_obt text;
  v_esp text := 'clasificado=casado:clasificado bandeja=llego_su_ticket control=f conciliacion=posible_duplicado:MX008 '
                'sin_motivo=22023 cambio=casado:recibo gasto_6400=0.00 control_despues=t confirma=confirmada';
  v_m   uuid;
  v_c   jsonb;
  v_x   text;
  v_y   text;
  v_pos bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (44, 'el ticket que llega después de clasificar se dice, bloquea y se cambia por la clasificación', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, -45.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-45.00', 'id', 'C6K1', 'nombre', 'C6 AMAZON MKTPLACE'))),
              null, 'c6-pruebas-amazon.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6K1');
    perform fn_banco_clasificar(v_m, '[{"cuenta": "6400"}]'::jsonb, null);
    v_obt := 'clasificado=' || pg_temp.c6_est('2100-9996', 'C6K1');
    -- La cuadrilla sube la foto días después.
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660441, 'total', 45.00, 'fecha', d + 9, 'proveedor', 'AMAZON'));
    perform fn_banco_casar_todo('2100-9996');
    v_obt := v_obt || ' bandeja=' || coalesce((select b.motivo from v_banco_bandeja b where b.movimiento_id = v_m), 'no_está')
             || ' control=' || pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text);
    v_c := fn_conciliar('2100-9996', d + 20, '45.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmó';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' conciliacion=' || coalesce((select string_agg(p.clase, ',') from conciliacion_partidas p
                                                     where p.conciliacion_id = (v_c->>'conciliacion')::uuid), '-') || ':' || v_x;
    begin
      perform fn_banco_duplicado(v_m, false, null);
      v_y := 'entró';
    exception when others then v_y := sqlstate;
    end;
    perform fn_banco_casar_con(v_m, jsonb_build_object('recibo', -660441), 'c6-pruebas: es su ticket');
    v_c := fn_conciliar('2100-9996', d + 20, '45.00');
    v_obt := v_obt || format(' sin_motivo=%s cambio=%s gasto_6400=%s control_despues=%s confirma=%s', v_y,
                             pg_temp.c6_est('2100-9996', 'C6K1'),
                             (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '6400'),
                             pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text),
                             fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (44, 'el ticket que llega después de clasificar se dice, bloquea y se cambia por la clasificación', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 45. UN DEPÓSITO NO VA A OTROS INGRESOS SIN SU MOTIVO: a 4900 sin motivo
--     no entra (MX008; antes entraba y el ingreso quedaba dos veces); con
--     su motivo escrito, sí, y el control lo acepta; los intereses del
--     banco (tipo INT) a 4910, sin motivo; y un asiento del banco que lleva
--     un depósito a 4900 sin motivo (por la puerta interna, a propósito)
--     sale en rojo en «depósitos nunca a ingreso».
do $$
declare
  v_obt text;
  v_esp text := 'sin_motivo=MX008 con_motivo=casado:clasificado intereses=casado:clasificado control=t interno=f';
  v_x   text;
  v_m3  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (45, 'un depósito no va a otros ingresos (49xx) sin su motivo; el control lo vigila', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 2603.21, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 6, 'monto', '2500.00', 'id', 'C6I1', 'nombre', 'C6 DEPOSITO VARIO'),
              jsonb_build_object('tipo', 'INT', 'fecha', d + 27, 'monto', '3.21', 'id', 'C6I2', 'nombre', 'C6 RENDIMIENTO'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 8, 'monto', '100.00', 'id', 'C6I3', 'nombre', 'C6 OTRO DEPOSITO'))),
              '1098', 'c6-pruebas-ingresos.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I1'), '[{"cuenta": "4900"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I1'), '[{"cuenta": "4900"}]'::jsonb,
                                'c6-pruebas: el reembolso de un seguro, no es de un cliente');
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I2'), '[{"cuenta": "4910"}]'::jsonb, null);
    v_m3 := pg_temp.c6_mov('1098', 'C6I3');
    v_obt := format('sin_motivo=%s con_motivo=%s intereses=%s control=%s', v_x, pg_temp.c6_est('1098', 'C6I1'),
                    pg_temp.c6_est('1098', 'C6I2'),
                    case when pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'),
                                                pg_temp.c6_mov('1098', 'C6I1')::text) = 't'
                          and pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'),
                                                pg_temp.c6_mov('1098', 'C6I2')::text) = 't' then 't' else 'f' end);
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', (d + 8)::text, 'descripcion', 'c6-pruebas: un depósito a otros ingresos sin motivo (se deshace)',
      'origen_tabla', 'movimientos_banco', 'origen_id', v_m3::text,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '4900', 'monto', '-100.00'))));
    v_obt := v_obt || ' interno=' || pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m3::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (45, 'un depósito no va a otros ingresos (49xx) sin su motivo; el control lo vigila', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 46. LOS PREPAGADOS DE ANTES DEL CORTE amortizan lo que dejó QuickBooks
--     (su saldo al corte, el número de la balanza), no un cálculo por
--     días: una póliza de 4,800.00 del 1-dic al 30-nov que QuickBooks
--     amortizó 1/12 al mes llega con 800.00; el libro amortiza 406.56 en
--     octubre y 393.44 en noviembre, y al vencer lo que la prueba puso en
--     1410 queda en 0.00 (antes, -2.19 y el control en rojo para siempre).
--     Sin su saldo al corte, la póliza no se da de alta.
do $$
declare
  v_obt text;
  v_esp text := 'sin_saldo=22023 oct=406.56 nov=393.44 falta=0.00 libro_1410=0.00';
  v_pos bigint;
  v_id  uuid;
  v_x   text;
  v_ini date;
  v_fin date;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (46, 'prepagados de antes del corte: se amortiza el saldo que dejó QuickBooks y 1410 queda en cero', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o no está abierto el siguiente',
                                 null);
    return;
  end if;
  v_ini := (d - interval '10 months')::date;
  v_fin := (d + interval '2 months')::date - 1;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    begin
      perform fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL QB', 'tipo', 'seguro', 'cuenta_gasto', '6200',
                'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_id := (fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL QB', 'tipo', 'seguro', 'cuenta_gasto', '6200',
               'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text, 'saldo_corte', '800.00'))->>'id')::uuid;
    -- Lo que dejó la apertura en 1410 para ella.
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que QuickBooks dejó en 1410 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '800.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-800.00'))));
    perform fn_prepagados_amortizar(current_setting('mx6.mes'));
    perform fn_prepagados_amortizar(current_setting('mx6.sig'));
    select format('sin_saldo=%s oct=%s nov=%s falta=%s libro_1410=%s', v_x,
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_id and a.vigente
                      and a.periodo = current_setting('mx6.mes')),
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_id and a.vigente
                      and a.periodo = current_setting('mx6.sig')),
                  (select x.por_amortizar from v_prepagados x where x.prepagado_id = v_id),
                  (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l join asientos a on a.id = l.asiento_id
                    where a.cadena_pos > v_pos and l.cuenta = '1410'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (46, 'prepagados de antes del corte: se amortiza el saldo que dejó QuickBooks y 1410 queda en cero', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 47. EL TICKET TARDÍO NO BLOQUEA LA CONCILIACIÓN PARA SIEMPRE: una compra
--     con la débito del último día del mes cuyo ticket se sube con el mes
--     ya cerrado (c3 lo postea el día 1 del mes abierto, «tardío») casa
--     con su cargo; en la conciliación de ese mes es una partida explicada
--     («en_libros_despues», no frena) y la conciliación se confirma.
--     (Con el reloj fingido: el mes cerrado dentro de la subtransacción.)
do $$
declare
  v_obt text;
  v_esp text := 'casado=casado:recibo tardio=t clase=en_libros_despues lista=true confirma=confirmada';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_fin date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (47, 'el ticket tardío (mes cerrado) casa y su conciliación se confirma con la partida explicada', v_esp,
                                 'omitida: falta mes abierto o el siguiente', null);
    return;
  end if;
  v_fin := (d + interval '1 month')::date - 1;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, v_fin, -133.70, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_fin, 'monto', '-133.70', 'id', 'C6F1', 'nombre', 'C6 FERRETERIA #9'))),
              '1098', 'c6-pruebas-tardio.qfx');
    perform pg_temp.c6_cerrar_hasta(current_setting('mx6.mes'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660471, 'total', 133.70, 'fecha', v_fin - 1, 'metodo_pago', 'debito',
                                                 'proveedor', 'C6 FERRETERIA'));
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', v_fin, '-133.70');
    v_obt := format('casado=%s tardio=%s clase=%s lista=%s confirma=%s', pg_temp.c6_est('1098', 'C6F1'),
                    (select case when a.procedencia ? 'tardio' then 't' else 'f' end from asientos a
                      where a.id = (select m.asiento_id from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6F1'))),
                    coalesce((select string_agg(p.clase, ',') from conciliacion_partidas p
                               where p.conciliacion_id = (v_c->>'conciliacion')::uuid), '-'),
                    v_c->>'lista_para_confirmar', fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa periodos (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (47, 'el ticket tardío (mes cerrado) casa y su conciliación se confirma con la partida explicada', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 48. LO QUE DIJO EL BANCO, CAMBIADO O BORRADO POR FUERA (con las guardas
--     apagadas un instante, algo que solo puede el dueño de la base): el
--     control ve el monto cambiado (su sello no da) y la revisión entera
--     relee el archivo fila por fila y ve los dos, el cambiado y el
--     borrado. Antes solo se contaban filas y los dos quedaban en verde.
--     Y un movimiento que entró antes de que hubiera sellos (sin sello)
--     sale en rojo hasta que el pegado lo sella: la guarda deja ponerle
--     SOLO el sello (con la marca «sellar:»), y ponerle el sello cambiando
--     otra cosa, no (MX003).
do $$
declare
  v_obt text;
  v_esp text := 'control=f verificar=f filas=2 sin_sello=f sellado=t con_cambio=MX003';
  v_m1  uuid;
  v_m2  uuid;
  v_m3  uuid;
  v_d   jsonb;
  v_s1  text;
  v_s2  text;
  v_s3  text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (48, 'un movimiento cambiado o borrado con las guardas apagadas sale en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m1 := pg_temp.c6_mov('1098', 'C6C5');
    v_m2 := pg_temp.c6_mov('1098', 'C6C8');
    v_m3 := pg_temp.c6_mov('1098', 'C6C6');
    alter table public.movimientos_banco disable trigger user;
    alter table public.movimientos_banco_ids disable trigger user;
    alter table public.archivos_banco disable trigger user;
    update public.movimientos_banco set monto = 100.00 where id = v_m1;
    update public.movimientos_banco set sello = null where id = v_m3;   -- como uno de la versión de antes
    delete from public.movimientos_banco_ids where movimiento_id = v_m2;
    delete from public.movimientos_banco where id = v_m2;
    update public.archivos_banco set filas_nuevas = filas_nuevas - 1, filas_leidas = filas_leidas - 1
     where id = (select m.archivo_id from movimientos_banco m where m.id = v_m1);
    alter table public.movimientos_banco enable trigger user;
    alter table public.movimientos_banco_ids enable trigger user;
    alter table public.archivos_banco enable trigger user;
    v_s1 := pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m3::text);
    -- Sellarlo con el sello y algo más cambiado: no.
    begin
      perform fn_banco_marca('sellar:' || v_m3);
      update public.movimientos_banco m
         set sello = fn_banco_sello(m.cuenta, m.ultimos4, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco, m.cheque,
                                    m.descripcion, m.memo, m.origen, m.id_externo, m.llave, m.archivo_id, m.fila,
                                    (select a.sha256 from archivos_banco a where a.id = m.archivo_id)),
             descripcion = 'OTRA COSA'
       where m.id = v_m3;
      v_s3 := 'entró';
    exception when others then v_s3 := sqlstate;
    end;
    -- Como lo sella el pegado (el mismo update de 1.11): solo el sello.
    perform fn_banco_marca('sellar:' || v_m3);
    update public.movimientos_banco m
       set sello = fn_banco_sello(m.cuenta, m.ultimos4, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco, m.cheque,
                                  m.descripcion, m.memo, m.origen, m.id_externo, m.llave, m.archivo_id, m.fila,
                                  (select a.sha256 from archivos_banco a where a.id = m.archivo_id))
     where m.id = v_m3;
    perform fn_banco_marca(null);
    v_s2 := pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m3::text);
    select v.detalle into v_d from fn_banco_verificar(array['1098']) v where v.control = 'archivos, leídos otra vez fila por fila';
    v_obt := format('control=%s verificar=%s filas=%s sin_sello=%s sellado=%s con_cambio=%s',
                    pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m1::text),
                    case when jsonb_array_length(v_d->'no_dan_lo_mismo') > 0 then 'f' else 't' end,
                    (select sum(jsonb_array_length(coalesce(x->'filas', '[]'::jsonb))) from jsonb_array_elements(v_d->'no_dan_lo_mismo') x),
                    v_s1, v_s2, v_s3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (48, 'un movimiento cambiado o borrado con las guardas apagadas sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 49. UNA CONCILIACIÓN CONFIRMADA NO SE ALTERA SIN REABRIRLA: si el ticket
--     de un cargo ya conciliado se anula, «Casar» no des-casa ese cargo
--     (antes volvía a la bandeja con la conciliación confirmada) y el
--     control dice cuál reabrir; y un movimiento que llega tarde con fecha
--     dentro de la confirmada (Plaid) la pone en rojo hasta reabrirla.
do $$
declare
  v_obt text;
  v_esp text := 'confirmada=confirmada sigue=casado:recibo control51=f:reabrir tarde=pendiente control54=f';
  v_c   jsonb;
  v_m   uuid;
  v_p   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (49, 'lo confirmado no cambia sin reabrir: sanar no des-casa; lo que llega tarde, en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    v_obt := 'confirmada=' || (fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    v_m := pg_temp.c6_mov('2100-9996', 'C6A1');
    perform fn_recibo_anular(-660001, 'c6-pruebas: el ticket estaba mal');
    perform fn_banco_casar_todo('2100-9996');
    v_obt := v_obt || ' sigue=' || pg_temp.c6_est('2100-9996', 'C6A1')
             || ' control51=' || pg_temp.c6_cuadre('cuadre: un movimiento, un casado', current_setting('mx6.mes'), v_m::text)
             || case when exists (select 1 from fn_banco_control(current_setting('mx6.mes'), null) c
                                   where c.vista = 'cuadre: un movimiento, un casado' and c.detalle like '%reábrela%') then ':reabrir'
                     else '' end;
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '2100-9996', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-tarde', 'fecha', d + 10, 'plaid_monto', '19.99', 'descripcion', 'C6 LLEGA TARDE'))));
    v_p := pg_temp.c6_mov('2100-9996', 'c6-plaid-tarde');
    v_obt := v_obt || ' tarde=' || (select m.estado from movimientos_banco m where m.id = v_p)
             || ' control54=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'), v_p::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (49, 'lo confirmado no cambia sin reabrir: sanar no des-casa; lo que llega tarde, en rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 50. UN DEVENGO NO EXPLICA UN MOVIMIENTO DEL BANCO: la línea de un asiento
--     reversible (el libro lo reversa solo el día 1) no casa con un
--     depósito del mismo monto (antes, el cruce exacto lo casaba y el
--     dinero no entraba nunca al libro), y casar con ella a mano tampoco.
do $$
declare
  v_obt text;
  v_esp text := 'deposito=pendiente a_mano=MX008';
  v_a   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (50, 'un devengo (asiento reversible) no casa con el banco', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_a := fn_postear(jsonb_build_object('fecha', (d + 5)::text, 'descripcion', 'c6-pruebas: un devengo (se deshace)', 'reversible', true,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '640.00'),
                                  jsonb_build_object('cuenta', '2050', 'monto', '-640.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 640.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 6, 'monto', '640.00', 'id', 'C6V1', 'nombre', 'C6 DEPOSITO'))),
              '1098', 'c6-pruebas-devengo.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_casar_con(pg_temp.c6_mov('1098', 'C6V1'), jsonb_build_object('asiento', v_a->>'id'), null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('deposito=%s a_mano=%s', (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6V1')), v_x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (50, 'un devengo (asiento reversible) no casa con el banco', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 51. EL MISMO MOVIMIENTO CON OTRO ID, O DE OTRO DÍA POR PLAID, espera; y
--     un id reutilizado para OTRO movimiento entra: el banco que cambia el
--     FITID entre dos descargas (misma fecha, monto y descripción) y Plaid
--     con un día de diferencia entran «posible duplicado» (antes, nuevos y
--     sin aviso: el dinero dos veces); el FITID que el banco repite para un
--     movimiento de otra fecha y monto entra como nuevo, con su aviso (antes
--     se daba por repetido y no entraba).
do $$
declare
  v_obt text;
  v_esp text := 'otro_fitid=pendiente:posible_duplicado plaid_otro_dia=pendiente:posible_duplicado reusado=nuevas:1,reusados:1';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (51, 'otro FITID o Plaid de otro día esperan; un FITID reutilizado entra con su aviso', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 7, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-58.10', 'id', 'C6U1', 'nombre', 'C6 TIENDA UNO'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-33.00', 'id', 'C6U2', 'nombre', 'C6 TIENDA DOS'))),
              '1098', 'c6-pruebas-semana1.qfx');
    -- La descarga del mes: el mismo movimiento del día 3 con otro FITID.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, 200.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-58.10', 'id', 'C6U1-B', 'nombre', 'C6 TIENDA UNO'))),
              '1098', 'c6-pruebas-mes.qfx');
    -- Plaid, un día después, con otra descripción.
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-dos', 'fecha', d + 6, 'plaid_monto', '33.00', 'descripcion', 'TIENDA DOS 123'))));
    -- El FITID C6U2 otra vez, pero para otro movimiento.
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 20, d + 27, 300.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-125.00', 'id', 'C6U2', 'nombre', 'C6 OTRA COSA'))),
              '1098', 'c6-pruebas-reusado.qfx');
    v_obt := format('otro_fitid=%s plaid_otro_dia=%s reusado=nuevas:%s,reusados:%s', pg_temp.c6_est('1098', 'C6U1-B'),
                    pg_temp.c6_est('1098', 'c6-plaid-dos'), v_x->>'filas_nuevas', coalesce(v_x->>'fitid_reusados', '0'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (51, 'otro FITID o Plaid de otro día esperan; un FITID reutilizado entra con su aviso', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 52. EL ESTADO DE CUENTA DE OTRA CUENTA NO ENTRA A ESTA: con 1098
--     recibiendo los archivos de ····1098, uno de ····7777 dicho a 1098
--     para (MX004, y dice cómo confirmarlo); confirmado a sabiendas (un
--     lote con «confirmo_cuenta»), entra. Y un lote de Plaid que dice
--     "cuenta": "1098" (la cuenta del plan) no guarda «1098» como los 4
--     últimos de nada.
do $$
declare
  v_obt text;
  v_esp text := 'otra_cuenta=MX004 confirmada=entra lote_ultimos4=-';
  v_x   text;
  v_y   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (52, 'el archivo de otra cuenta no entra sin confirmarlo; «cuenta» de un lote no son 4 últimos', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 5, 10.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 2, 'monto', '-1.00', 'id', 'C6N1', 'nombre', 'C6 UNO'))),
              '1098', 'c6-pruebas-1098.qfx');
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000007777', d, d + 5, 999.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-2.00', 'id', 'C6N2', 'nombre', 'C6 PERSONAL'))),
                '1098', 'c6-pruebas-7777.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '1098', 'ultimos4', '7777', 'confirmo_cuenta', true,
                                                       'nombre', 'c6-pruebas: número nuevo', 'filas', '[]'::jsonb));
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000007777', d, d + 5, 999.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-2.00', 'id', 'C6N2', 'nombre', 'C6 PERSONAL'))),
                '1098', 'c6-pruebas-7777.qfx');
      v_y := 'entra';
    exception when others then v_y := sqlstate;
    end;
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-u4', 'fecha', d + 4, 'plaid_monto', '3.00', 'descripcion', 'C6 TRES'))));
    v_obt := format('otra_cuenta=%s confirmada=%s lote_ultimos4=%s', v_x, v_y,
                    coalesce((select a.ultimos4 from archivos_banco a where a.formato = 'plaid' and a.cuenta = '1098'
                               order by a.importado_el desc limit 1), '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (52, 'el archivo de otra cuenta no entra sin confirmarlo; «cuenta» de un lote no son 4 últimos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 53. UN ARCHIVO GRANDE ENTRA: el importador crece con las filas, no con
--     su cuadrado (antes, un QFX de un año, 3,000 movimientos, no cabía
--     nunca en los 8 s de la API). Uno de 1,000 y otro de 3,000 (antes, uno
--     chico de calentamiento; y si no da, otra vez cada uno, con otros
--     montos, y se toma la vez más rápida: un tropiezo del servidor no
--     decide): el grande entra entero y tarda unas tres veces lo que el de
--     1,000 (con el cuadrado serían nueve; el importador de antes daba seis
--     y medio). Se mide la proporción, no los segundos: en Supabase todo
--     tarda más que en el banco de pruebas.
do $$
declare
  v_obt text;
  v_esp text := 'nuevas=1000+3000 lineal=t';
  v_x   jsonb;
  v_n1  text;
  v_n3  text;
  v_t   timestamptz;
  v_t1  numeric := null;
  v_t3  numeric := null;
  v_i   int;
  v_n   int;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (53, 'un archivo de 3,000 movimientos entra entero, y el tiempo crece con las filas', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- Cada archivo con sus propios montos (-k.15, -k.25, …): ninguno es
    -- «posible duplicado» de otro, y todos hacen el mismo trabajo.
    for v_i in 0 .. 4 loop
      v_n := case when v_i = 0 then 100 when v_i in (1, 3) then 1000 else 3000 end;
      exit when v_i = 3 and v_t3 < 4.5 * greatest(v_t1, 0.02);
      v_t := clock_timestamp();
      v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 0.00,
               (select jsonb_agg(jsonb_build_object('tipo', 'DEBIT', 'fecha', d + (g % 28),
                                                    'monto', to_char(-(g % 97 + 1) - 0.15 - v_i * 0.10, 'FM999990.00'),
                                                    'id', 'C6H' || v_i || '-' || g, 'nombre', 'C6 COMPRA ' || v_i || ' ' || g) order by g)
                  from generate_series(1, v_n) g)), '1098', 'c6-pruebas-grande-' || v_i || '.qfx');
      if v_n = 1000 then
        v_t1 := least(coalesce(v_t1, 1e9), extract(epoch from clock_timestamp() - v_t));
        v_n1 := coalesce(v_n1, v_x->>'filas_nuevas');
      elsif v_n = 3000 then
        v_t3 := least(coalesce(v_t3, 1e9), extract(epoch from clock_timestamp() - v_t));
        v_n3 := coalesce(v_n3, v_x->>'filas_nuevas');
      end if;
    end loop;
    v_obt := format('nuevas=%s+%s lineal=%s', v_n1, v_n3,
                    case when v_t3 < 4.5 * greatest(v_t1, 0.02) then 't' else format('f:%s/%s', round(v_t1, 2), round(v_t3, 2)) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (53, 'un archivo de 3,000 movimientos entra entero, y el tiempo crece con las filas', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 54. LAS PROTECCIONES VEN LO AJENO Y service_role NO LEE EL ESTADO DE
--     CUENTA ENTERO: una vista sin security_invoker sobre el banco (que le
--     da a quien la abra lo que la policy le niega) o una SECURITY DEFINER
--     ejecutable por la API que lee el banco por una función de ayuda
--     ponen «protecciones del banco» en rojo (antes, verde); y service_role
--     lee los archivos por columnas, pero no su texto (el número entero de
--     la cuenta y de la ruta).
do $$
declare
  v_obt text;
  v_esp text := 'vista=f definer=f limpio=t sr_texto=42501 sr_nombre=t';
  v_x   text;
  v_y   text;
  v_a   text;
  v_b   text;
begin
  begin
    execute 'create view public.c6_pruebas_extracto as select m.cuenta, m.fecha, m.monto, m.descripcion from public.movimientos_banco m';
    execute 'grant select on public.c6_pruebas_extracto to authenticated';
    select case when bool_and(c.ok) then 't' else 'f' end into v_x
      from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco';
    execute 'drop view public.c6_pruebas_extracto';
    execute 'create function public.c6_pruebas_ayuda() returns bigint language sql stable set search_path = public, pg_temp
               as $f$ select count(*) from public.movimientos_banco $f$';
    execute 'create function public.c6_pruebas_puerta() returns bigint language sql stable security definer
               set search_path = public, pg_temp as $f$ select public.c6_pruebas_ayuda() $f$';
    execute 'grant execute on function public.c6_pruebas_puerta() to authenticated';
    select case when bool_and(c.ok) then 't' else 'f' end into v_y
      from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco';
    execute 'drop function public.c6_pruebas_puerta()';
    execute 'drop function public.c6_pruebas_ayuda()';
    v_obt := format('vista=%s definer=%s limpio=%s', v_x, v_y,
                    (select case when bool_and(c.ok) then 't' else 'f' end
                       from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco'));
    execute 'set local role service_role';
    begin
      execute 'select count(texto) from public.archivos_banco';
      v_a := 'lee';
    exception when others then v_a := sqlstate;
    end;
    begin
      execute 'select count(nombre) from public.archivos_banco';
      v_b := 't';
    exception when others then v_b := sqlstate;
    end;
    execute 'reset role';
    v_obt := v_obt || format(' sr_texto=%s sr_nombre=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (54, 'las protecciones ven vistas y DEFINER ajenas; service_role no lee el texto de los archivos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 55. UN DEPÓSITO DE DOS CHEQUES YA ANOTADOS casa solo con los dos cobros
--     que lo suman (únicos y a días del depósito): antes salía «sin cobro»,
--     los mensajes llevaban a registrar un anticipo y el mismo dinero
--     entraba dos veces. El primer cobro queda con su movimiento. Y si dos
--     combinaciones pueden sumarlo, no se adivina: se propone.
do $$
declare
  v_obt  text;
  v_esp  text := 'deposito=casado:cobro lineas=2 primero=el_movimiento empate=pendiente:deposito_cobros opciones=2';
  v_c1   jsonb;
  v_obra text := current_setting('mx6.obra', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (55, 'un depósito de varios cobros ya anotados casa con ellos; con empate, se propone', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660551, v_obra, 'C6-551', d + 1, 1250.00, 0), (-660552, v_obra, 'C6-552', d + 1, 2750.00, 0),
           (-660553, v_obra, 'C6-553', d + 1, 1100.00, 0), (-660554, v_obra, 'C6-554', d + 1, 1400.00, 0),
           (-660555, v_obra, 'C6-555', d + 1, 1200.00, 0), (-660556, v_obra, 'C6-556', d + 1, 1300.00, 0);
    v_c1 := fn_cobro_registrar(jsonb_build_object('fecha', (d + 8)::text, 'monto', '1250.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-551', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660551, 'monto', '1250.00'))));
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 9)::text, 'monto', '2750.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-552', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660552, 'monto', '2750.00'))));
    -- Dos pares que suman 2,500.00 (1,100 + 1,400 y 1,200 + 1,300): no se adivina.
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 15)::text, 'monto', x.m, 'cuenta', '1098', 'medio', 'cheque',
              'referencia', x.r, 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', x.f, 'monto', x.m))))
      from (values ('1100.00', 'C6-553', -660553), ('1400.00', 'C6-554', -660554), ('1200.00', 'C6-555', -660555),
                   ('1300.00', 'C6-556', -660556)) as x(m, r, f);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 6500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 10, 'monto', '4000.00', 'id', 'C6S1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 16, 'monto', '2500.00', 'id', 'C6S2', 'nombre', 'DEPOSIT'))),
              '1098', 'c6-pruebas-cheques-juntos.qfx');
    perform fn_banco_casar_todo('1098');
    select format('deposito=%s lineas=%s primero=%s empate=%s opciones=%s', pg_temp.c6_est('1098', 'C6S1'),
                  (select count(*) from banco_casado_lineas l where l.casado_id = m.casado_id and l.vigente),
                  (select case when c.movimiento_id = m.id::text then 'el_movimiento' else coalesce(c.movimiento_id, 'nada') end
                     from cobros c where c.id = (v_c1->>'cobro')::uuid),
                  pg_temp.c6_est('1098', 'C6S2'),
                  (select count(*) from movimientos_banco m2, jsonb_array_elements(m2.propuesta->'opciones') o
                    where m2.id = pg_temp.c6_mov('1098', 'C6S2') and o->>'llamar' = 'fn_banco_casar_con'))
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6S1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (55, 'un depósito de varios cobros ya anotados casa con ellos; con empate, se propone', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 56. EL CHEQUE POR EL STATEMENT DE UN PROVEEDOR paga primero lo que traía
--     QuickBooks (su deuda sin partida de la apertura) y después sus
--     papeles: un cheque sin nombre por lo que se le debe se propone como
--     su pago (antes: «sin ticket»), y aplicado no deja nada «a favor» ni
--     dice «pagaste de más» (antes el FIFO saltaba lo de QuickBooks).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=pago_proveedor sin_nombre=t qb=1850.00 papel=1100.00 a_favor=0 aviso=quickbooks';
  v_prov uuid;
  v_m    uuid;
  v_r    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (56, 'el cheque por el statement de un proveedor paga primero lo de QuickBooks', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_prov := (pg_temp.c6_montar()->>'proveedor')::uuid;
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    -- Lo que traía QuickBooks (la apertura: a su nombre, sin partida).
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que se le debía en QuickBooks (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', '-1850.00', 'tercero_tipo', 'proveedor',
                                                     'tercero_id', v_prov::text),
                                  jsonb_build_object('cuenta', '3900', 'monto', '1850.00'))));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660561, 'total', 1100.00, 'fecha', d + 2, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 14, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 12, 'monto', '-2950.00', 'id', 'C6M1', 'nombre', 'CHECK 1042',
                                 'cheque', '1042'))), '1098', 'c6-pruebas-statement.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6M1');
    select format('propuesta=%s sin_nombre=%s', m.propuesta->>'motivo',
                  case when m.propuesta->>'texto' like '%sin nombre%' then 't' else 'f' end)
      into v_obt from movimientos_banco m where m.id = v_m;
    v_r := fn_banco_pagar_proveedor(v_m, v_prov, null);
    v_obt := v_obt || format(' qb=%s papel=%s a_favor=%s aviso=%s',
               (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.cuenta = '2010' and l.partida_tabla is null),
               (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.cuenta = '2010'
                   and l.partida_tabla = 'recibos'),
               (select count(*) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.memo like 'A favor%'),
               case when v_r->>'aviso' like '%QuickBooks%' and v_r->>'aviso' not like '%más que%' then 'quickbooks'
                    else coalesce(v_r->>'aviso', '-') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (56, 'el cheque por el statement de un proveedor paga primero lo de QuickBooks', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 57. UNA COMPRA CON LA DÉBITO EN EL MOSTRADOR DE UN PROVEEDOR no es el
--     pago de su cuenta: sin nada que diga pago y sin cuadrar con lo que
--     se le debe, la bandeja la pone como cargo sin ticket (el pago queda
--     como otra opción), y clasificarla a su costo no pide motivo. Antes la
--     única opción era «Pago a …», que saldaba una factura ajena y dejaba
--     la compra sin costo.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=sin_ticket pago_opcion=t clasificar=casado:clasificado';
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (57, 'la compra con la débito en el mostrador de un proveedor no se toma por su pago', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660571, 'total', 750.00, 'fecha', d + 1, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'POS', 'fecha', d + 5, 'monto', '-87.50', 'id', 'C6O1', 'nombre', 'C6 PRUEBAS SUPPLY #12',
                                 'memo', 'CARD 9420'))), '1098', 'c6-pruebas-mostrador.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6O1');
    select format('bandeja=%s pago_opcion=%s', m.propuesta->>'motivo',
                  case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o
                                     where o->>'llamar' = 'fn_banco_pagar_proveedor') then 't' else 'f' end)
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                null);
    v_obt := v_obt || ' clasificar=' || pg_temp.c6_est('1098', 'C6O1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (57, 'la compra con la débito en el mostrador de un proveedor no se toma por su pago', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 58. LA NÓMINA DEL PROVEEDOR ANTERIOR (antes de Gusto y de f11): su débito
--     espera su journal y la conciliación lo dice así (no «clasifícalos»);
--     desde el SQL Editor, fn_banco_nomina registra su journal (origen
--     nomina_proveedor: la mano de obra de verdad, 5000 con su obra, y los
--     impuestos patronales a 5015) y lo casa con el débito; el control de
--     mano de obra de c3 no lo cuenta (su asiento no sale entre los que
--     rompen la regla: con datos de verdad, ese control puede venir en rojo
--     por lo suyo) y el papel del asiento se encuentra.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=nomina falta=nomina journal=casado:asiento mano_de_obra=t papel=t';
  v_c   jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (58, 'la nómina del proveedor anterior: su journal con fn_banco_nomina, casado con su débito', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -4000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-4000.00', 'id', 'C6J1', 'nombre', 'ADP PAYROLL FEES'))),
              '1098', 'c6-pruebas-adp.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6J1');
    v_c := fn_conciliar('1098', d + 20, '-4000.00');
    v_obt := format('bandeja=%s falta=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m),
                    case when v_c->>'falta' like '%fn_banco_nomina%' then 'nomina' else coalesce(v_c->>'falta', '-') end);
    perform fn_banco_nomina(v_m, jsonb_build_array(
              jsonb_build_object('cuenta', '5000', 'monto', '3500.00', 'proyecto_id', current_setting('mx6.obra'), 'memo', 'Sueldos'),
              jsonb_build_object('cuenta', '5015', 'monto', '500.00', 'memo', 'Impuestos patronales')), 'c6-pruebas: ADP de octubre');
    v_obt := v_obt || format(' journal=%s mano_de_obra=%s papel=%s', pg_temp.c6_est('1098', 'C6J1'),
                             (select case when p.ok or not (coalesce(p.detalle->'asientos', '[]'::jsonb)
                                                            ? (select a.numero from asientos a
                                                                where a.id = (select m.asiento_id from movimientos_banco m where m.id = v_m)))
                                          then 't' else 'f' end
                                from fn_puentes_verificar() p where p.control = 'mano_de_obra'),
                             (select case when exists (select 1 from v_asiento_papel v
                                                        where v.asiento_id = (select m.asiento_id from movimientos_banco m where m.id = v_m)
                                                          and v.papel is not null) then 't' else 'f' end));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (58, 'la nómina del proveedor anterior: su journal con fn_banco_nomina, casado con su débito', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 59. CASAR NO REHACE LO QUE NO CAMBIÓ: con la bandeja propuesta, otra
--     llamada sin nada nuevo no rehace ninguna propuesta (antes rehacía la
--     de TODO lo pendiente en cada llamada: 2 a 5 s con la bandeja
--     atrasada, con el candado del casado tomado); abrir un movimiento
--     (fn_banco_casar) rehace la suya; y algo nuevo en el libro las rehace.
do $$
declare
  v_obt text;
  v_esp text := 'primera=t segunda=0 abrir=1 con_cambio=t';
  v_x   jsonb;
  v_y   jsonb;
  v_z   jsonb;
  v_w   jsonb;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (59, 'casar no rehace las propuestas que no cambiaron', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_casar_todo('1098');
    v_y := fn_banco_casar_todo('1098');
    v_z := fn_banco_casar(pg_temp.c6_mov('1098', 'C6C8'));
    perform fn_postear(jsonb_build_object('fecha', current_setting('mx6.desde'), 'descripcion', 'c6-pruebas: algo nuevo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '6130', 'monto', '-1.00'))));
    v_w := fn_banco_casar_todo('1098');
    v_obt := format('primera=%s segunda=%s abrir=%s con_cambio=%s',
                    case when (v_x->>'propuestas')::int > 0 then 't' else 'f:' || coalesce(v_x->>'propuestas', '-') end,
                    v_y->>'propuestas', v_z->'casar'->>'propuestas',
                    case when (v_w->>'propuestas')::int > 0 then 't' else 'f:' || coalesce(v_w->>'propuestas', '-') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (59, 'casar no rehace las propuestas que no cambiaron', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 60. LA REVISIÓN ENTERA NO RECALCULA LO QUE NO CAMBIÓ: con una
--     conciliación confirmada y nada nuevo, fn_banco_verificar no la
--     recalcula (la compara por su huella, en el control); con algo
--     posteado después con fecha dentro de su corte, la recalcula y lo dice
--     en rojo. Antes las recalculaba todas cada vez (8,5 s con 36).
do $$
declare
  v_obt text;
  v_esp text := 'sin_cambios=0 con_cambio=1 rojo=t';
  v_c   jsonb;
  v_d1  jsonb;
  v_d2  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (60, 'fn_banco_verificar recalcula solo las conciliaciones que pudieron cambiar', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    select v.detalle into v_d1 from fn_banco_verificar(array['2100-9996']) v where v.control = 'conciliaciones confirmadas, recalculadas';
    perform fn_postear(jsonb_build_object('fecha', (d + 10)::text, 'descripcion', 'c6-pruebas: algo con fecha dentro del corte (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9996', 'monto', '-5.00'),
                                  jsonb_build_object('cuenta', '6130', 'monto', '5.00'))));
    select v.detalle into v_d2 from fn_banco_verificar(array['2100-9996']) v where v.control = 'conciliaciones confirmadas, recalculadas';
    v_obt := format('sin_cambios=%s con_cambio=%s rojo=%s', v_d1->>'recalculadas', v_d2->>'recalculadas',
                    case when jsonb_array_length(v_d2->'no_dan_lo_mismo') > 0 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (60, 'fn_banco_verificar recalcula solo las conciliaciones que pudieron cambiar', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 62. LA BANDEJA ATRASADA NO SE ATASCA: la API corta cada llamada a los
--     8 s y deshace lo que hizo; el motor del casado mira el reloj, para
--     antes con «completo»: false, y la llamada siguiente sigue donde
--     quedó. Con el tope bajado a 0 (el ajuste mx_banco.tope_ms: cada
--     llamada casa uno y para), llamando hasta «completo», sale lo mismo
--     que de una vez: los mismos casados y las mismas propuestas.
do $$
declare
  v_obt    text;
  v_esp    text := 'tramos=t igual=t completo=t';
  v_uno    text;
  v_tramos text;
  v_n      int := 0;
  v_x      jsonb;
  v_c      text;
  v_a      text;
  v_r      text;
  v_cta    text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (62, 'la bandeja atrasada no se atasca: en tramos, lo mismo que de una vez', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  -- De una vez.
  begin
    perform pg_temp.c6_escenario();
    -- (Los archivos, antes de ser el dueño: pg_temp es del editor.)
    v_c := pg_temp.c6_chase();
    v_a := pg_temp.c6_amex();
    v_r := pg_temp.c6_reserva();
    perform pg_temp.c6_como('dueno');
    perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
    perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
    foreach v_cta in array array['1098', '2100-9996', '1097'] loop
      perform fn_banco_casar_todo(v_cta);
    end loop;
    execute 'reset role';
    select string_agg(m.cuenta || ':' || m.id_externo || '=' || m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                      || ':' || coalesce(m.casado_regla, m.propuesta->>'motivo', '-'), ',' order by m.cuenta, m.id_externo)
      into v_uno
      from movimientos_banco m where m.cuenta in ('1098', '1097', '2100-9996');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_uno := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  -- En tramos: el tope a 0 ms.
  begin
    perform pg_temp.c6_escenario();
    -- (Los archivos, antes de ser el dueño: pg_temp es del editor.)
    v_c := pg_temp.c6_chase();
    v_a := pg_temp.c6_amex();
    v_r := pg_temp.c6_reserva();
    perform pg_temp.c6_como('dueno');
    perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
    perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
    perform set_config('mx_banco.tope_ms', '0', true);
    -- (Cuenta por cuenta de la prueba, como conta.js después de importar: la
    -- bandeja de verdad no entra en el tramo.)
    foreach v_cta in array array['1098', '2100-9996', '1097'] loop
      loop
        v_n := v_n + 1;
        v_x := fn_banco_casar_todo(v_cta);
        exit when coalesce((v_x->>'completo')::boolean, false) or v_n >= 200;
      end loop;
    end loop;
    perform set_config('mx_banco.tope_ms', '', true);
    execute 'reset role';
    select string_agg(m.cuenta || ':' || m.id_externo || '=' || m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                      || ':' || coalesce(m.casado_regla, m.propuesta->>'motivo', '-'), ',' order by m.cuenta, m.id_externo)
      into v_tramos
      from movimientos_banco m where m.cuenta in ('1098', '1097', '2100-9996');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_tramos := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  v_obt := 'tramos=' || case when v_n > 2 then 't' else 'f:' || v_n end
           || ' igual=' || case when v_tramos = v_uno then 't' else 'f: ' || left(coalesce(v_tramos, '-'), 150) end
           || ' completo=' || case when coalesce((v_x->>'completo')::boolean, false) then 't' else 'f' end;
  insert into _pruebas values (62, 'la bandeja atrasada no se atasca: en tramos, lo mismo que de una vez', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 61. NO DEJA RASTRO: todo lo de arriba se deshizo. El libro, los papeles,
--     el banco y su historial, las reglas, los descriptores, los eventos,
--     los contadores, las secuencias de la app y las huellas están como al
--     empezar. Va la última.
do $$
declare
  v_antes text := current_setting('mx6.foto', true);
  v_ahora text;
begin
  v_ahora := pg_temp.c6_foto();
  insert into _pruebas values (61, 'no deja rastro: todo como al empezar', v_antes, v_ahora, v_ahora = v_antes);
end $$;

reset jit;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD, como el de c4: el SQL
-- Editor de Supabase deja de esperar a los pocos minutos y enseña un error
-- de red, pero la corrida sigue en el servidor hasta el final. Por eso la
-- tabla temporal _pruebas se copia aquí a pruebas.c6_resultado, fuera de
-- la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Si el editor se cansó, la
-- corrida entera se lee después con
--   select * from pruebas.c6_resultado order by n;
-- Guarda solo la última corrida, con su hora. No es parte del libro (la
-- foto de «no deja rastro» no la mira) y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c6_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c6_resultado from public, anon, authenticated, service_role;
truncate pruebas.c6_resultado;
insert into pruebas.c6_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
