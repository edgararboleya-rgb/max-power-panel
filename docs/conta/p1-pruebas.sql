-- =====================================================================
-- p1-pruebas.sql — los cobros en línea con Stripe se prueban a sí mismos
-- (p1-stripe.sql). 27-oct-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de p1-stripe.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 42 filas, todas
-- con ok = true. En producción dos pueden salir «omitida» (ok nulo), y lo
-- dicen: la 40 (pg_net de verdad no apunta las llamadas; en el banco sí se
-- mira) y la 32 o el último tramo de la 33 si en esa base no se puede
-- confirmar una conciliación de prueba de la 1010 (dentro de la prueba, y se
-- deshace). Si el editor se cansa antes del final, la corrida sigue en el
-- servidor y se lee después en pruebas.p1_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena c1..c6,
-- el Vault y el pg_net de mentira de pruebas/seguridad/00-vault-shim.sql, c7,
-- s1 y p1-stripe.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/p1-pruebas.sql
-- (correr.sh solo pone su resumen a los c*-pruebas.sql; aquí se lee la
-- tabla del final, o pruebas.p1_resultado).
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda, ni en Vault; la 41 lo comprueba. Las fotos de Stripe son
-- inventadas (ids pi_P1T…, po_P1T…, plink_P1T…, montos redondos) y las
-- facturas de prueba llevan ids negativos (-16010xx), de una obra que ya
-- existe. Ningún dato real.
--
-- Lo que mira (SQL-01..SQL-42 de la especificación, una prueba cada una):
-- la instalación (las tablas cerradas, las dos cuentas y su fila de los
-- estados, el dueño, el secreto de la rutina) y la cuenta que ya existe con
-- otra forma; quién puede llamar qué (la función de borde como postgres sí;
-- service_role, el dueño, el equipo y anon por la API, no), el catálogo y
-- las vistas por rol; los avisos de Stripe guardados primero (repetidos, de
-- otro modo, sin datos personales, reintentos con espera); los enlaces (por
-- lo que debe el LIBRO, con todos sus frenos, sin tocar la factura); el pago
-- al libro EN NOMBRE DEL DUEÑO (tarjeta, ACH, microdepósitos, fallos,
-- sobrepagos, facturas que no lo aceptan, pagos sin factura y cómo se
-- resuelven, reembolsos y reembolsos que fallan con UN cobro vivo por pago,
-- disputas, meses cerrados y sin abrir); los depósitos de Stripe (P1 y P2,
-- su composición, lo que espera, lo que no cuadra, lo que la app no conoce,
-- fallidos antes y después de pagarse, el reverso a mano y rehacer); el
-- casado SOLO con el depósito de Chase (R1 de c6) y su contraprueba de un
-- solo asiento, el depósito que llega antes y la conciliación confirmada;
-- el control de p1 en rojo cuando algo ajeno toca sus cuentas, las alarmas
-- y lo pendiente de la rutina, los avisos al teléfono, la suplantación, la
-- rutina (pg_net con el secreto de Vault), y (la 42) que al final c2
-- (fn_verificar_cadena), c3, c6 (fn_banco_control) y c4 (fn_estados_control,
-- salvo lo que ya estaba en rojo ANTES de empezar, que la prueba dice: en el
-- banco, «cuadre: apertura en el libro», que no tiene apertura) siguen en
-- verde y el control de p1 sin cuadres en rojo.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, las cuentas de p1, las obras y las fechas.
create temp table if not exists _p1 (k text primary key, v text);
truncate _p1;
insert into _p1
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _p1
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _p1
select 'obra', p.id from proyectos p where p.tipo is not null order by (p.tipo = 'residencial') desc, p.id limit 1;
insert into _p1
select 'obra2', p.id from proyectos p
 where p.tipo is not null and p.id <> (select v from _p1 where k = 'obra') order by p.id limit 1;
insert into _p1
select x.k, x.v from stripe_config c
 cross join lateral (values ('puente', c.cuenta_puente), ('paso', c.cuenta_paso), ('comisiones', c.cuenta_comisiones),
                            ('banco', c.cuenta_banco)) as x(k, v)
 where c.id = 1;
insert into _p1 values ('cxc', (select cuenta from puente_cuentas where rol = 'cxc'));
insert into _p1 values ('ret', (select cuenta from puente_cuentas where rol = 'retencion_cxc'));
-- hoy (Miami), el día de las facturas de prueba (del mes de hoy) y la
-- llegada de los depósitos (después de la última conciliación confirmada
-- del banco, si la hay)
insert into _p1 values ('hoy', fn_fecha_miami(now())::text);
insert into _p1 values ('d', greatest(fn_fecha_miami(now()) - 3, date_trunc('month', fn_fecha_miami(now()))::date)::text);
insert into _p1 values ('llegada', greatest(fn_fecha_miami(now()),
  coalesce((select max(c.fecha_corte) + 1 from conciliaciones c
             where c.cuenta = (select v from _p1 where k = 'banco') and c.estado = 'confirmada' and c.tipo = 'normal'),
           fn_fecha_miami(now())))::text);
-- una cuenta de ingreso y una de gasto sin obra obligatoria (lo de fuera de la app)
insert into _p1
select 'ingreso', c.codigo from cuentas c
 where c.tipo in ('ingreso', 'otro_ingreso') and c.activa and c.imputable and c.regla_obra <> 'obligatoria'
 order by (c.codigo = '4900') desc, c.codigo limit 1;
insert into _p1
select 'gasto', c.codigo from cuentas c
 where c.tipo = 'gasto' and c.activa and c.imputable and c.regla_obra <> 'obligatoria'
   and c.codigo <> (select v from _p1 where k = 'comisiones')
 order by (c.codigo = '6500') desc, c.codigo limit 1;
insert into _p1
select 'capital', c.codigo from cuentas c
 where c.tipo = 'capital' and c.regla_obra = 'prohibida' and c.activa and c.imputable
 order by (c.codigo = '3900') desc, c.codigo limit 1;
grant select on _p1 to public;  -- las pruebas cambian de rol (service_role, el dueño, anon) y siguen leyendo lo común

-- Los avisos de prueba no salen al teléfono, y el control de c4 sin tope
-- por reloj (como en c4-pruebas).
do $$
begin
  perform set_config('mxp.stripe_sin_push', '1', false);
  perform set_config('c4.control_tope', '0', false);
end $$;

create or replace function pg_temp.p1(k text) returns text language sql as $$ select v from _p1 where k = $1 $$;

-- ser la función de borde (como postgres) / la misma en nombre del dueño
-- (sin cambiar de rol, como la sincronización de Plaid) / service_role /
-- anon / el dueño o el equipo por la API
create or replace function pg_temp.p1_ser(quien text) returns void language plpgsql as $$
begin
  execute 'reset role';
  if quien = 'servicio' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien = 'como_dueno' then
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.p1('dueno'), 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', pg_temp.p1('dueno'), true);
  elsif quien in ('service_role', 'anon') then
    perform set_config('request.jwt.claims', json_build_object('role', quien)::text, true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute format('set local role %I', quien);
  else
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.p1(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.p1(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Lo de cada prueba, dentro de su subtransacción: el candado del casado
-- primero (el orden de la app, como c6-pruebas), los avisos de prueba
-- aceptados (solo dentro de la prueba) y el mapeo del tipo de las dos
-- obras confirmado (sin él sus facturas se quedan en la bandeja).
create or replace function pg_temp.p1_montar() returns void language plpgsql as $$
declare
  r      record;
  v_tipo text;
  v_ing  text;
begin
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  update stripe_config set acepta_prueba = true, modo = 'prueba' where id = 1;
  for r in select distinct p.tipo from proyectos p where p.id in (pg_temp.p1('obra'), pg_temp.p1('obra2')) loop
    v_tipo := fn_puente_normalizar(r.tipo);
    if exists (select 1 from mapeo_tipo_proyecto m where m.tipo = v_tipo and m.confirmado_el is null) then
      perform fn_mapeo_confirmar('tipo_proyecto', v_tipo);
    elsif not exists (select 1 from mapeo_tipo_proyecto m where m.tipo = v_tipo) then
      select c.codigo into v_ing from cuentas c
       where c.tipo = 'ingreso' and c.regla_obra = 'obligatoria' and c.activa and c.imputable
       order by (c.codigo = '4010') desc, c.codigo limit 1;
      perform fn_mapeo_tipo_proyecto(v_tipo, v_ing);
    end if;
  end loop;
end $$;

-- Una factura de prueba (id negativo), con su puente en immediate: entra al
-- libro en el acto. p_obra '-' = sin obra (se queda en la bandeja).
create or replace function pg_temp.p1_factura(p_id bigint, p_monto numeric, p_ret numeric default 0, p_fecha date default null,
                                               p_obra text default null, p_estado text default 'emitida', p_pagada boolean default false)
returns bigint language plpgsql as $$
declare
  v_lista text;
begin
  select string_agg(quote_ident(t.tgname), ', ') into v_lista
    from pg_trigger t where t.tgname = 'trg_puente_facturas_despues' and t.tgconstraint <> 0;
  if v_lista is not null then
    execute 'set constraints ' || v_lista || ' immediate';
  end if;
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion, estado, pagada) overriding system value
  values (p_id, case when p_obra = '-' then null else coalesce(p_obra, pg_temp.p1('obra')) end, 'P1-' || abs(p_id),
          coalesce(p_fecha, pg_temp.p1('d')::date), p_monto, p_ret, p_estado, p_pagada);
  return p_id;
end $$;

-- Un enlace activo (lo que haría la función de borde: preparar, Stripe lo
-- crea, guardarlo). El plink es plink_<lo que sigue a pi_> del pago.
create or replace function pg_temp.p1_enlace(p_factura bigint, p_plink text, p_con_retencion boolean default false,
                                              p_aunque boolean default false)
returns uuid language plpgsql as $$
declare
  v jsonb;
begin
  v := fn_stripe_enlace_preparar(p_factura, pg_temp.p1('dueno')::uuid, 'prueba', p_con_retencion, p_aunque);
  perform fn_stripe_enlace_creado((v->>'enlace')::uuid,
                                  jsonb_build_object('id', p_plink, 'url', 'https://buy.stripe.com/test_' || p_plink, 'livemode', false,
                                                     'metadata', v->'metadata'));
  return (v->>'enlace')::uuid;
end $$;

-- Las piezas de una foto de Stripe (centavos)
create or replace function pg_temp.p1_cargo(p_pi text, p_estado text, p_centavos bigint, p_medio text default 'tarjeta',
                                             p_bt_fallo text default null)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('id', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
                                              'estado', p_estado, 'medio', p_medio, 'bt', 'txn_' || p_pi, 'bt_fallo', p_bt_fallo,
                                              'creado', extract(epoch from now())::bigint, 'monto', p_centavos))
$$;
create or replace function pg_temp.p1_reembolso(p_id text, p_centavos bigint, p_bt text, p_estado text default 'succeeded',
                                                 p_bt_fallo text default null)
returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'monto', p_centavos, 'estado', p_estado, 'creado', extract(epoch from now())::bigint,
                            'bt', p_bt, 'bt_fallo', p_bt_fallo, 'motivo_fallo', null)
$$;
create or replace function pg_temp.p1_bt(p_id text, p_categoria text, p_centavos bigint, p_comision bigint default 0)
returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'categoria', p_categoria, 'monto', p_centavos, 'comision', p_comision,
                            'creado', extract(epoch from now())::bigint)
$$;
create or replace function pg_temp.p1_disputa(p_id text, p_centavos bigint, p_estado text, p_bts jsonb, p_motivo text default 'fraudulent')
returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'monto', p_centavos, 'estado', p_estado, 'motivo', p_motivo,
                            'vence', extract(epoch from now() + interval '7 days')::bigint, 'bts', p_bts)
$$;
-- La foto de un pago: el enlace plink_<…> si existe (y sus metadatos); si
-- no, los metadatos con la factura que se diga (o ninguno).
create or replace function pg_temp.p1_foto(p_pi text, p_estado text, p_centavos bigint, p_factura bigint default null,
                                            p_medio text default 'tarjeta', p_extra jsonb default '{}'::jsonb)
returns jsonb language sql as $$
  select jsonb_build_object(
    'pi', p_pi, 'visto_el', clock_timestamp(), 'estado', p_estado, 'monto', p_centavos,
    'recibido', case when p_estado = 'succeeded' then p_centavos else 0 end, 'moneda', 'usd', 'livemode', false,
    'creado', extract(epoch from now())::bigint,
    'metadata', coalesce((select jsonb_build_object('mxp', 'p1', 'enlace', e.id::text, 'factura_id', e.factura_id::text, 'factura', e.factura_num,
                                                    'retencion', case when e.con_retencion then 'si' else 'no' end)
                            from stripe_enlaces e where e.plink = 'plink_' || substr(p_pi, 4)),
                         case when p_factura is not null then jsonb_build_object('factura_id', p_factura::text) else '{}'::jsonb end),
    'plink', (select e.plink from stripe_enlaces e where e.plink = 'plink_' || substr(p_pi, 4)),
    'sesion', 'cs_' || substr(p_pi, 4), 'sesion_completa', true, 'medio', p_medio,
    'cargo', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
    'fecha_exito', case when p_estado = 'succeeded' then pg_temp.p1('hoy') end,
    'cargos', jsonb_build_array(pg_temp.p1_cargo(p_pi, case p_estado when 'succeeded' then 'succeeded'
                                                                   when 'requires_payment_method' then 'failed' else 'pending' end,
                                                 p_centavos, p_medio)),
    'reembolsos', '[]'::jsonb, 'disputas', '[]'::jsonb, 'ultimo_error', null::jsonb) || p_extra
$$;
-- Un pago con tarjeta (o ACH) cobrado, con su enlace (si la factura se dice
-- y p_enlace), y su aviso de éxito.
create or replace function pg_temp.p1_pagar(p_pi text, p_factura bigint, p_centavos bigint, p_medio text default 'tarjeta',
                                             p_enlace boolean default true)
returns jsonb language plpgsql as $$
begin
  if p_enlace and p_factura is not null then
    perform pg_temp.p1_enlace(p_factura, 'plink_' || substr(p_pi, 4));
  end if;
  return fn_stripe_pago_sincronizar(pg_temp.p1_foto(p_pi, 'succeeded', p_centavos, p_factura, p_medio), 'evt_' || substr(p_pi, 4));
end $$;
-- La foto de un depósito y sus líneas (centavos)
create or replace function pg_temp.p1_payout(p_po text, p_estado text, p_centavos bigint, p_extra jsonb default '{}'::jsonb)
returns jsonb language sql as $$
  select jsonb_build_object('po', p_po, 'visto_el', clock_timestamp(), 'estado', p_estado, 'monto', p_centavos, 'moneda', 'usd',
                            'llegada', pg_temp.p1('llegada'), 'automatico', true, 'metodo', 'standard', 'conciliacion', 'completed',
                            'bt_propio', 'txn_' || p_po, 'bt_fallo', null, 'fallo_codigo', null) || p_extra
$$;
create or replace function pg_temp.p1_linea(p_txn text, p_tipo text, p_monto bigint, p_comision bigint default 0, p_pi text default null,
                                             p_fuente text default null)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'txn', p_txn, 'tipo', p_tipo,
    'categoria', case when p_tipo in ('charge', 'payment') then 'charge' when p_tipo in ('refund', 'payment_refund') then 'refund'
                      when p_tipo = 'adjustment' then 'dispute' when p_tipo ~ '_fee$' then 'fee' else p_tipo end,
    'monto', p_monto, 'comision', p_comision, 'neto', p_monto - p_comision, 'fuente', p_fuente, 'pi', p_pi,
    'creado', extract(epoch from now())::bigint))
$$;
create or replace function pg_temp.p1_propio(p_po text, p_centavos bigint) returns jsonb language sql as $$
  select pg_temp.p1_linea('txn_' || p_po, 'payout', -p_centavos, 0, null, p_po)
$$;
-- El saldo de una cuenta en el libro
create or replace function pg_temp.p1_saldo(p_cuenta text) returns numeric language sql as $$
  select coalesce(sum(l.monto), 0) from asiento_lineas l where l.cuenta = p_cuenta
$$;
-- Un depósito de Chase como lo trae Plaid (en nombre del dueño, como la
-- sincronización de la mañana). Devuelve el movimiento.
create or replace function pg_temp.p1_deposito(p_id text, p_fecha date, p_monto numeric, p_desc text default null) returns uuid
language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.p1('dueno'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.p1('dueno'), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', pg_temp.p1('banco'), 'nombre', 'Plaid · p1-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object(
               'id', p_id, 'fecha', p_fecha::text, 'plaid_monto', (-p_monto)::text,
               'descripcion', coalesce(p_desc, 'ORIG CO NAME:STRIPE CO ENTRY DESCR:TRANSFER SEC:CCD IND ID:ST-' || upper(p_id)),
               'tipo', 'XFER', 'pendiente', false))));
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  return (select m.id from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1);
end $$;
-- «Casar» de la cuenta del banco, en nombre del dueño
create or replace function pg_temp.p1_casar_todo() returns jsonb language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v        jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.p1('dueno'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.p1('dueno'), true);
  v := fn_banco_casar_todo(pg_temp.p1('banco'));
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  return v;
end $$;
-- El control de p1: las filas en rojo de un nivel, o una fila
create or replace function pg_temp.p1_rojos(p_nivel text default 'cuadre') returns text language sql as $$
  select coalesce(string_agg(c.orden::text, ' ' order by c.orden), 'ninguno') from v_stripe_control c where c.nivel = p_nivel and not c.ok
$$;
create or replace function pg_temp.p1_fila(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from v_stripe_control c where c.orden = p_orden
$$;
-- Los rojos que aparecieron (los de antes, fuera)
create or replace function pg_temp.p1_nuevos(p_antes text, p_ahora text) returns text language sql as $$
  select coalesce(string_agg(x, ' ' order by x::int), 'ninguno')
    from unnest(string_to_array(p_ahora, ' ')) x
   where x <> 'ninguno' and not (x = any (string_to_array(p_antes, ' ')))
$$;
-- Las líneas de un asiento, en una cadena: cuenta monto [partida] [obra]
create or replace function pg_temp.p1_lineas(p_asiento uuid) returns text language sql as $$
  select string_agg(concat_ws(' ', l.cuenta, l.monto::text, l.partida_tabla || '/' || l.partida_id,
                              case when l.proyecto_id is not null then 'obra' end), ' | ' order by l.orden)
    from asiento_lineas l where l.asiento_id = p_asiento
$$;
-- Lo que hay en las tablas que p1 toca (la 41 lo compara)
create or replace function pg_temp.p1_conteos() returns text language sql as $$
  select format('config %s · eventos %s · enlaces %s · pagos %s · libro %s · payouts %s · lineas %s · avisos %s · cobros %s · '
                'devoluciones %s · asientos %s · archivos %s · movimientos %s · cuentas %s · vault %s',
                (select count(*) from stripe_config), (select count(*) from stripe_eventos), (select count(*) from stripe_enlaces),
                (select count(*) from stripe_pagos), (select count(*) from stripe_pago_libro), (select count(*) from stripe_payouts),
                (select count(*) from stripe_payout_lineas), (select count(*) from stripe_avisos), (select count(*) from cobros),
                (select count(*) from cobros_devoluciones), (select count(*) from asientos), (select count(*) from archivos_banco),
                (select count(*) from movimientos_banco), (select count(*) from cuentas), (select count(*) from vault.secrets))
$$;
-- El reloj fingido (como c3-pruebas): fn_fecha_miami con greatest(hoy, p_hoy)
create or replace function pg_temp.p1_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;
-- Cerrar hasta un mes (como c3-pruebas): finge el día siguiente, pone la
-- apertura si falta y cierra en orden. La prueba toma antes «lock table
-- periodos in exclusive mode».
create or replace function pg_temp.p1_cerrar_hasta(p_periodo text) returns void language plpgsql as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  select * into v_p from periodos where periodo = p_periodo;
  perform pg_temp.p1_fingir_hoy(v_p.hasta + 1);
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear(jsonb_build_object(
      'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'), 'descripcion', 'p1-pruebas: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', pg_temp.p1('banco'), 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', pg_temp.p1('capital'), 'monto', '-1000.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
  end loop;
end $$;

-- La foto de antes: lo que ya estaba en rojo en c2, c3, c4 y c6, y los
-- conteos.
insert into _p1 values ('conteos', pg_temp.p1_conteos());
insert into _p1 select 'rojos_c2', coalesce(string_agg(control, ', ' order by control), '') from fn_verificar_cadena() where not ok;
insert into _p1 select 'rojos_c3', coalesce(string_agg(control, ', ' order by control), '') from fn_puentes_verificar() where not ok;
insert into _p1 select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _p1 select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;


-- =====================================================================
-- La instalación y quién puede qué
-- =====================================================================

-- 1. Instalación: las 8 tablas con RLS y su única policy, las dos cuentas
--    con su forma, banco para c3 y c6 solo la puente, su fila de los
--    estados, su historial, la configuración con el dueño, el secreto de
--    la rutina; el alta otra vez no cambia nada.
do $$
declare
  v_obt text; v_t int; v_c1 text; v_c2 text; v_m text; v_h int; v_cfg text; v_v text; v_alta jsonb; v_antes text; v_desp text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    select count(*) into v_t
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
       and c.relname in ('stripe_config', 'stripe_eventos', 'stripe_enlaces', 'stripe_pagos', 'stripe_pago_libro', 'stripe_payouts',
                         'stripe_payout_lineas', 'stripe_avisos')
       and c.relrowsecurity
       and (select count(*) from pg_policy p where p.polrelid = c.oid) = 1
       and exists (select 1 from pg_policy p where p.polrelid = c.oid and p.polname = c.relname || '_dueno');
    select case when c.tipo = 'activo' and c.saldo_normal = 'debe' and c.imputable and c.activa and c.regla_obra = 'prohibida'
                     and c.regla_cost_code = 'prohibida' and c.padre is null then 'bien' else 'MAL' end
      into v_c1 from cuentas c where c.codigo = pg_temp.p1('puente');
    select case when c.tipo = 'activo' and c.saldo_normal = 'debe' and c.imputable and c.activa and c.regla_obra = 'prohibida'
                     and c.regla_cost_code = 'prohibida' and c.padre is null then 'bien' else 'MAL' end
      into v_c2 from cuentas c where c.codigo = pg_temp.p1('paso');
    select string_agg(m.cuenta || ' ' || m.seccion || '/' || m.linea || '/' || m.flujo_directo || '/' || m.flujo_indirecto, ' · ' order by m.cuenta) into v_m
      from estados_mapeo m where m.cuenta in (pg_temp.p1('puente'), pg_temp.p1('paso'));
    select count(distinct h.codigo) into v_h
      from cuentas_historial h where h.codigo in (pg_temp.p1('puente'), pg_temp.p1('paso')) and h.operacion = 'INSERT';
    select case when exists (select 1 from stripe_config c join perfiles p on p.id = c.dueno
                              where c.id = 1 and p.rol = 'dueno' and coalesce(p.activo, true)) then 'con su dueño' else 'MAL' end
      into v_cfg;
    select case when count(*) = 1 and min(length(s.decrypted_secret)) >= 32 then 'un secreto de 32 o más' else 'MAL ' || count(*) end
      into v_v from vault.decrypted_secrets s where s.name = 'stripe_rutina_secreto';
    v_antes := format('%s cuentas · %s mapeo · %s historial · desde %s', (select count(*) from cuentas), (select count(*) from estados_mapeo),
                      (select count(*) from cuentas_historial), (select c.desde from stripe_config c where c.id = 1));
    v_alta := fn_stripe_cuentas_alta();
    v_desp := format('%s cuentas · %s mapeo · %s historial · desde %s', (select count(*) from cuentas), (select count(*) from estados_mapeo),
                     (select count(*) from cuentas_historial), (select c.desde from stripe_config c where c.id = 1));
    v_obt := format('tablas %s | %s %s · %s %s | banco %s/%s · tipo c6 %s/%s | %s | historial %s | config %s | vault %s | otra vez: %s, %s',
                    v_t, pg_temp.p1('puente'), v_c1, pg_temp.p1('paso'), v_c2,
                    fn_puente_es_banco(pg_temp.p1('puente'))::text, fn_puente_es_banco(pg_temp.p1('paso'))::text,
                    coalesce(fn_banco_tipo_cuenta(pg_temp.p1('puente')), 'nulo'), coalesce(fn_banco_tipo_cuenta(pg_temp.p1('paso')), 'nulo'),
                    v_m, v_h, v_cfg, v_v, v_alta->'creadas', case when v_antes = v_desp then 'nada cambió' else 'CAMBIÓ' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'instalación: tablas cerradas, las dos cuentas, su fila de los estados, el dueño y el secreto; el alta otra vez no cambia nada',
    format('tablas 8 | %s bien · %s bien | banco true/false · tipo c6 banco/nulo | %s activo_circulante/efectivo/efectivo/efectivo · %s activo_circulante/cuentas_por_cobrar/cobros_clientes/op_cxc | historial 2 | config con su dueño | vault un secreto de 32 o más | otra vez: [], nada cambió',
           pg_temp.p1('puente'), pg_temp.p1('paso'), pg_temp.p1('puente'), pg_temp.p1('paso')), v_obt,
    v_obt = format('tablas 8 | %s bien · %s bien | banco true/false · tipo c6 banco/nulo | %s activo_circulante/efectivo/efectivo/efectivo · %s activo_circulante/cuentas_por_cobrar/cobros_clientes/op_cxc | historial 2 | config con su dueño | vault un secreto de 32 o más | otra vez: [], nada cambió',
                   pg_temp.p1('puente'), pg_temp.p1('paso'), pg_temp.p1('puente'), pg_temp.p1('paso')));
end $$;

-- 2. La puente con otra forma: el alta para con MX000 y no inserta nada
do $$
declare
  v_obt text; v_cod text; v_e text; v_n0 bigint; v_h0 bigint;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    select x into v_cod from unnest(array['1099', '1096', '1095', '1094', '1093']) x
     where not exists (select 1 from cuentas c where c.codigo = x) order by x desc limit 1;
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values (v_cod, 'p1-pruebas: otra forma (se deshace)', 'p1 test (other shape)', 'activo', 'debe', true, 'opcional', 'opcional');
    update stripe_config set cuenta_puente = v_cod where id = 1;
    v_n0 := (select count(*) from cuentas);
    v_h0 := (select count(*) from cuentas_historial);
    begin
      perform fn_stripe_cuentas_alta();
      v_e := 'entró';
    exception when others then
      v_e := sqlstate || case when sqlerrm like '%La cuenta ' || v_cod || ' ya existe con otra forma%' then ' «la cuenta ya existe con otra forma»'
                              else ' ' || sqlerrm end;
    end;
    v_obt := format('%s | %s', v_e, case when (select count(*) from cuentas) = v_n0 and (select count(*) from cuentas_historial) = v_h0
                                         then 'nada insertado' else 'INSERTÓ' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'la puente ya existe con otra forma: MX000 y no se toca nada',
    'MX000 «la cuenta ya existe con otra forma» | nada insertado', v_obt, v_obt = 'MX000 «la cuenta ya existe con otra forma» | nada insertado');
end $$;

-- 3. Nadie de la API llama a p1 (ni el dueño: lo pide por la función de
--    borde); la función de borde (como postgres) sí
do $$
declare
  v_obt text; v_q text; v_c text; v_e text[]; v_res text[] := '{}'; v_srv text[] := '{}';
  c_llamadas constant text[] := array[
    'select fn_stripe_evento_guardar(''{}''::jsonb, ''webhook'', ''prueba'')',
    'select fn_stripe_pago_sincronizar(''{}''::jsonb)',
    'select fn_stripe_payout_sincronizar(''{}''::jsonb)',
    'select fn_stripe_enlace_preparar(1, null, ''real'')',
    'select fn_stripe_payout_casar(''po_x'')',
    'select fn_stripe_pago_resolver(''pi_x'', ''{}''::jsonb, ''x'', null)',
    'select * from fn_stripe_control()',
    'select * from fn_stripe_pegado()',
    'select fn_stripe_programado()',
    'select fn_stripe_pendientes()'];
begin
  begin
    foreach v_q in array array['service_role', 'anon', 'dueno', 'equipo'] loop
      v_e := '{}';
      if v_q = 'equipo' and pg_temp.p1('equipo') is null then
        v_res := v_res || 'equipo: sin perfil (como si 42501)'::text;
        continue;
      end if;
      perform pg_temp.p1_ser(v_q);
      foreach v_c in array c_llamadas loop
        begin
          execute v_c;
          v_e := v_e || 'entró'::text;
        exception when others then
          v_e := v_e || sqlstate::text;
        end;
      end loop;
      execute 'reset role';
      v_res := v_res || format('%s: %s', v_q, case when v_e <@ array['42501'] then 'todas 42501' else array_to_string(v_e, ' ') end);
    end loop;
    perform pg_temp.p1_ser('servicio');
    foreach v_c in array array['select * from fn_stripe_control()', 'select fn_stripe_pendientes()', 'select fn_stripe_resumen()',
                               'select * from fn_stripe_pegado()'] loop
      begin
        execute v_c;
        v_srv := v_srv || 'entra'::text;
      exception when others then
        v_srv := v_srv || sqlstate::text;
      end;
    end loop;
    v_obt := array_to_string(v_res, ' | ') || ' | servicio: ' || case when v_srv <@ array['entra'] then 'entra' else array_to_string(v_srv, ' ') end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'service_role, anon, el dueño y el equipo por la API: 42501 en todo p1; la función de borde (postgres) entra',
    'service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: todas 42501 | servicio: entra', v_obt,
    v_obt in ('service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: todas 42501 | servicio: entra',
              'service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: sin perfil (como si 42501) | servicio: entra'));
end $$;

-- 4. El catálogo: ninguna fn_stripe_* SECURITY DEFINER ni en la API, nada
--    que la API escriba en stripe_*, las vistas con security_invoker y
--    ningún trigger de p1
do $$
declare
  v_obt text; v_def int; v_api int; v_esc int; v_inv int; v_trg int;
begin
  begin
    select count(*) into v_def from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_stripe%' and p.prosecdef;
    select count(*) into v_api from pg_proc p cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
     where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_stripe%' and has_function_privilege(r.r, p.oid, 'execute');
    select count(*) into v_esc from pg_class c
     cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
     cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'stripe\_%' and has_table_privilege(r.r, c.oid, q.q);
    select count(*) into v_inv from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname like 'v\_stripe\_%'
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    select count(*) into v_trg from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_proc f on f.oid = t.tgfoid
     where not t.tgisinternal and (c.relname like 'stripe\_%' or f.proname like 'fn\_stripe%' or t.tgname like '%stripe%');
    v_obt := format('definer %s | en la API %s | la API escribe %s | vistas sin invoker %s | triggers %s', v_def, v_api, v_esc, v_inv, v_trg);
  exception when others then
    v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'catálogo: nada SECURITY DEFINER ni en la API, la API no escribe, vistas security_invoker, sin triggers',
    'definer 0 | en la API 0 | la API escribe 0 | vistas sin invoker 0 | triggers 0', v_obt,
    v_obt = 'definer 0 | en la API 0 | la API escribe 0 | vistas sin invoker 0 | triggers 0');
end $$;

-- 5. Las vistas por rol: el dueño las lee (el estado, una fila); el equipo
--    no ve nada; anon, ni entrar
do $$
declare
  v_obt text; v_d text; v_e text; v_a text; v_v text; v_n bigint; v_l text[] := '{}';
begin
  begin
    perform pg_temp.p1_ser('dueno');
    select count(*)::text into v_d from v_stripe_estado;
    foreach v_v in array array['v_stripe_control', 'v_stripe_facturas', 'v_stripe_pagos', 'v_stripe_payouts', 'v_stripe_avisos',
                               'v_stripe_eventos'] loop
      execute format('select count(*) from public.%I', v_v) into v_n;
    end loop;
    execute 'reset role';
    if pg_temp.p1('equipo') is not null then
      perform pg_temp.p1_ser('equipo');
      foreach v_v in array array['v_stripe_estado', 'v_stripe_control', 'v_stripe_facturas', 'v_stripe_pagos', 'v_stripe_payouts',
                                 'v_stripe_avisos', 'v_stripe_eventos'] loop
        execute format('select count(*) from public.%I', v_v) into v_n;
        v_l := v_l || v_n::text;
      end loop;
      v_e := array_to_string(v_l, ' ');
      execute 'reset role';
    else
      v_e := '0 0 0 0 0 0 0';
    end if;
    perform pg_temp.p1_ser('anon');
    begin
      select count(*)::text into v_a from v_stripe_estado;
    exception when others then
      v_a := sqlstate;
    end;
    v_obt := format('dueño: estado %s, las demás se leen | equipo: %s | anon: %s', v_d, v_e, v_a);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'las vistas: el dueño sí, el equipo 0 filas, anon nada',
    'dueño: estado 1, las demás se leen | equipo: 0 0 0 0 0 0 0 | anon: 42501', v_obt,
    v_obt = 'dueño: estado 1, las demás se leen | equipo: 0 0 0 0 0 0 0 | anon: 42501');
end $$;


-- =====================================================================
-- Los avisos de Stripe: guardar primero, cerrar después
-- =====================================================================

-- 6. El mismo aviso dos veces (una fila, veces 2); uno de otro modo, o de
--    prueba en una base que no los acepta, queda ignorado (con aviso); lo
--    guardado no lleva datos personales
do $$
declare
  v_obt text; v_r1 jsonb; v_r2 jsonb; v_r3 jsonb; v_r4 jsonb; v_n int; v_av int; v_dp text;
  v_ev jsonb := jsonb_build_object('id', 'evt_P1T6A', 'tipo', 'payment_intent.succeeded', 'livemode', false,
                                   'api_version', '2026-09-30.endive', 'created', 1793030400,
                                   'objeto', jsonb_build_object('id', 'pi_P1T6', 'object', 'payment_intent', 'receipt_email', 'cliente@ejemplo.com',
                                                                'charges', jsonb_build_object('data', jsonb_build_array(jsonb_build_object(
                                                                  'billing_details', jsonb_build_object('name', 'Cliente Ejemplo'),
                                                                  'payment_method_details', jsonb_build_object('card', jsonb_build_object('last4', '4242'))))),
                                                                'shipping', jsonb_build_object('address', jsonb_build_object('line1', 'x'))));
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    v_r1 := fn_stripe_evento_guardar(v_ev, 'webhook', 'prueba');
    v_r2 := fn_stripe_evento_guardar(v_ev, 'webhook', 'prueba');
    select count(*) into v_n from stripe_eventos where id = 'evt_P1T6A';
    select case when e.datos::text ~* '(email|address|phone|billing_details|last4|shipping)' then 'CON datos personales' else 'sin datos personales' end
      into v_dp from stripe_eventos e where e.id = 'evt_P1T6A';
    -- livemode real con una llave de prueba
    v_r3 := fn_stripe_evento_guardar(v_ev || jsonb_build_object('id', 'evt_P1T6B', 'livemode', true), 'webhook', 'prueba');
    select count(*) into v_av from stripe_avisos where clave = 'modo';
    -- de prueba en una base que no los acepta
    update stripe_config set acepta_prueba = false where id = 1;
    v_r4 := fn_stripe_evento_guardar(v_ev || jsonb_build_object('id', 'evt_P1T6C'), 'webhook', 'prueba');
    v_obt := format('%s fila, veces %s, la segunda nuevo=%s | real con llave de prueba: %s (%s), aviso modo %s | prueba sin aceptarla: %s | %s',
                    v_n, v_r2->>'veces', v_r2->>'nuevo', v_r3->>'estado',
                    (select e.resultado->>'motivo' from stripe_eventos e where e.id = 'evt_P1T6B'), v_av, v_r4->>'estado', v_dp);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'el mismo aviso dos veces, otro modo ignorado, sin datos personales',
    '1 fila, veces 2, la segunda nuevo=false | real con llave de prueba: ignorado (modo), aviso modo 1 | prueba sin aceptarla: ignorado | sin datos personales',
    v_obt, v_obt = '1 fila, veces 2, la segunda nuevo=false | real con llave de prueba: ignorado (modo), aviso modo 1 | prueba sin aceptarla: ignorado | sin datos personales');
end $$;

-- 7. Cerrar con espera creciente (5 min, 15 min, 1 h); a los 20 intentos
--    (o a las 72 h) pasa a revisar con aviso; un mes sin abrir y un
--    permiso de la llave avisan
do $$
declare
  v_obt text; v_i text[] := '{}'; v_r jsonb; v_e1 text; v_e2 text; v_m int; v_ll int; v_ev jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    v_ev := jsonb_build_object('id', 'evt_P1T7A', 'tipo', 'payout.paid', 'livemode', false, 'created', 1793030400,
                               'objeto', jsonb_build_object('id', 'po_P1T7', 'object', 'payout'));
    perform fn_stripe_evento_guardar(v_ev, 'webhook', 'prueba');
    for i in 1 .. 3 loop
      v_r := fn_stripe_evento_cerrar('evt_P1T7A', 'reintentar', null, 'Stripe no contestó', 'STRIPE_CAIDO');
      v_i := v_i || ((v_r->>'proximo_intento')::timestamptz - now())::text;
    end loop;
    update stripe_eventos set intentos = 19 where id = 'evt_P1T7A';
    v_r := fn_stripe_evento_cerrar('evt_P1T7A', 'reintentar', null, 'sigue sin contestar', 'STRIPE_CAIDO');
    v_e1 := format('%s, aviso %s', v_r->>'estado', (select a.nivel from stripe_avisos a where a.clave = 'evento:evt_P1T7A'));
    perform fn_stripe_evento_guardar(v_ev || jsonb_build_object('id', 'evt_P1T7B'), 'webhook', 'prueba');
    update stripe_eventos set recibido_el = now() - interval '73 hours' where id = 'evt_P1T7B';
    v_r := fn_stripe_evento_cerrar('evt_P1T7B', 'reintentar', null, 'x', '500');
    v_e2 := v_r->>'estado';
    perform fn_stripe_evento_guardar(v_ev || jsonb_build_object('id', 'evt_P1T7C'), 'webhook', 'prueba');
    perform fn_stripe_evento_cerrar('evt_P1T7C', 'reintentar', null,
      'No hay período contable para el 2028-01-05: el mes todavía no se abrió. Se abre con fn_abrir_periodo(''AAAA-MM''), en orden.', 'MX002');
    select count(*) into v_m from stripe_avisos where clave = 'mes:2028-01' and nivel = 'bad';
    perform fn_stripe_evento_guardar(v_ev || jsonb_build_object('id', 'evt_P1T7D'), 'webhook', 'prueba');
    perform fn_stripe_evento_cerrar('evt_P1T7D', 'revisar', null,
      'A la llave de Stripe le falta un permiso: rak_payout_read (/v1/payouts).', 'STRIPE_PERMISO');
    select count(*) into v_ll from stripe_avisos where clave = 'llave' and nivel = 'bad';
    v_obt := format('esperas %s | intento 20: %s | 73 h: %s | mes sin abrir: aviso %s | permiso: aviso %s',
                    array_to_string(v_i, ', '), v_e1, v_e2, v_m, v_ll);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'cerrar un aviso: reintentos con espera, revisar a los 20 o a las 72 h, avisos de mes y de llave',
    'esperas 00:05:00, 00:15:00, 01:00:00 | intento 20: revisar, aviso bad | 73 h: revisar | mes sin abrir: aviso 1 | permiso: aviso 1', v_obt,
    v_obt = 'esperas 00:05:00, 00:15:00, 01:00:00 | intento 20: revisar, aviso bad | 73 h: revisar | mes sin abrir: aviso 1 | permiso: aviso 1');
end $$;


-- =====================================================================
-- Los enlaces de pago
-- =====================================================================

-- 8. Preparar el enlace de una factura de 1,000.00 con 100.00 de retención:
--    por lo que debe el libro (900.00), con su idempotencia y sus
--    metadatos; con la retención, 1,000.00; otra vez antes de guardarlo,
--    la misma carga; con llave de prueba en una base que no la acepta, no
do $$
declare
  v_obt text; v_p jsonb; v_p2 jsonb; v_p3 jsonb; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601081, 1000.00, 100.00);
    perform pg_temp.p1_factura(-1601082, 1000.00, 100.00);
    perform pg_temp.p1_factura(-1601083, 500.00);
    v_p := fn_stripe_enlace_preparar(-1601081, pg_temp.p1('dueno')::uuid, 'prueba');
    v_p2 := fn_stripe_enlace_preparar(-1601081, pg_temp.p1('dueno')::uuid, 'prueba');
    v_p3 := fn_stripe_enlace_preparar(-1601082, pg_temp.p1('dueno')::uuid, 'prueba', true);
    update stripe_config set acepta_prueba = false where id = 1;
    begin
      perform fn_stripe_enlace_preparar(-1601083, pg_temp.p1('dueno')::uuid, 'prueba');
      v_e := 'entró';
    exception when others then
      declare v_h text;
      begin
        get stacked diagnostics v_h = pg_exception_hint;
        v_e := sqlstate || ' ' || coalesce(v_h, '');
      end;
    end;
    v_obt := format('%s %s %s %s %s | con retención %s | otra vez: %s, %s | llave de prueba: %s',
                    v_p->>'accion', v_p->>'monto', v_p->>'centavos',
                    case when v_p->>'idempotencia' = 'mxp-enlace-' || (v_p->>'enlace') then 'idempotencia de su enlace' else 'MAL' end,
                    case when v_p->'metadata' = jsonb_build_object('mxp', 'p1', 'enlace', v_p->>'enlace', 'factura_id', '-1601081',
                                                                   'factura', 'P1-1601081', 'retencion', 'no')
                         then 'metadatos bien' else 'MAL ' || (v_p->'metadata')::text end,
                    v_p3->>'monto',
                    case when (v_p2->>'reanudar')::boolean then 'reanudar' else 'MAL' end,
                    case when v_p2->>'idempotencia' = v_p->>'idempotencia' then 'la misma' else 'OTRA' end, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'preparar el enlace: por el saldo del libro, su idempotencia y sus metadatos; con retención; reanudar; llave de prueba',
    'crear 900.00 90000 idempotencia de su enlace metadatos bien | con retención 1000.00 | otra vez: reanudar, la misma | llave de prueba: MX008 PRUEBA',
    v_obt, v_obt = 'crear 900.00 90000 idempotencia de su enlace metadatos bien | con retención 1000.00 | otra vez: reanudar, la misma | llave de prueba: MX008 PRUEBA');
end $$;

-- 9. Preparar rechaza: anulada, borrador, fuera del libro, sin saldo (con
--    la pista de la retención), con un pago en camino, a nombre del equipo,
--    y la casilla «pagada» sin confirmarlo. La factura no cambia.
do $$
declare
  v_obt text; v_r text[] := '{}'; v_x text; v_md5 text; v_md5b text; v_p jsonb; v_h text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601091, 500.00);
    perform fn_factura_anular(-1601091, 'p1-pruebas: se deshace');
    perform pg_temp.p1_factura(-1601092, 500.00, 0, null, null, 'borrador');
    perform pg_temp.p1_factura(-1601093, 500.00, 0, date '2026-09-15');
    perform pg_temp.p1_factura(-1601094, 100.00, 100.00);
    perform pg_temp.p1_factura(-1601095, 500.00);
    insert into stripe_pagos (pi, factura_id, factura_num, monto, estado, estado_stripe, medio)
    values ('pi_P1T9X', -1601095, 'P1-1601095', 500.00, 'en_camino', 'processing', 'ach');
    perform pg_temp.p1_factura(-1601096, 500.00, 0, null, null, 'emitida', true);
    select md5(row(f.pagada, f.cobrado, f.cobrada_el, f.metodo_cobro, f.link_pago, f.estado)::text) into v_md5 from facturas f where f.id = -1601096;
    foreach v_x in array array['-1601091', '-1601092', '-1601093', '-1601094', '-1601095'] loop
      begin
        perform fn_stripe_enlace_preparar(v_x::bigint, pg_temp.p1('dueno')::uuid, 'prueba');
        v_r := v_r || 'entró'::text;
      exception when others then
        v_r := v_r || (sqlstate || case when sqlerrm ~ 'Incluir la retención' then ' (retención)' else '' end);
      end;
    end loop;
    if pg_temp.p1('equipo') is not null then
      begin
        perform fn_stripe_enlace_preparar(-1601096, pg_temp.p1('equipo')::uuid, 'prueba');
        v_r := v_r || 'entró'::text;
      exception when others then
        v_r := v_r || sqlstate::text;
      end;
    else
      v_r := v_r || '42501'::text;
    end if;
    begin
      perform fn_stripe_enlace_preparar(-1601096, pg_temp.p1('dueno')::uuid, 'prueba');
      v_r := v_r || 'entró'::text;
    exception when others then
      get stacked diagnostics v_h = pg_exception_hint;
      v_r := v_r || (sqlstate || ' ' || coalesce(v_h, ''));
    end;
    v_p := fn_stripe_enlace_preparar(-1601096, pg_temp.p1('dueno')::uuid, 'prueba', false, true);
    select md5(row(f.pagada, f.cobrado, f.cobrada_el, f.metodo_cobro, f.link_pago, f.estado)::text) into v_md5b from facturas f where f.id = -1601096;
    v_obt := format('anulada %s | borrador %s | fuera del libro %s | sin saldo %s | pago en camino %s | equipo %s | pagada %s → confirmada: %s | la factura %s',
                    v_r[1], v_r[2], v_r[3], v_r[4], v_r[5], v_r[6], v_r[7], v_p->>'accion', case when v_md5 = v_md5b then 'igual' else 'CAMBIÓ' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'preparar rechaza lo que no se cobra en línea; la casilla pagada pide confirmarlo; la factura no se toca',
    'anulada MX008 | borrador MX008 | fuera del libro MX008 | sin saldo MX008 (retención) | pago en camino MX008 | equipo 42501 | pagada MX008 pagada_en_app → confirmada: crear | la factura igual',
    v_obt, v_obt = 'anulada MX008 | borrador MX008 | fuera del libro MX008 | sin saldo MX008 (retención) | pago en camino MX008 | equipo 42501 | pagada MX008 pagada_en_app → confirmada: crear | la factura igual');
end $$;

-- 10. El enlace creado, repetido, de otro, listo, a reemplazar, uno vivo por
--     factura, fallido, usado, desactivado por la rutina (con aviso) y uno
--     que la app no conoce
do $$
declare
  v_obt text; v_r text[] := '{}'; v_p jsonb; v_e uuid; v_e2 uuid; v_x jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601101, 500.00);
    perform pg_temp.p1_factura(-1601102, 500.00);
    perform pg_temp.p1_factura(-1601103, 500.00);
    v_p := fn_stripe_enlace_preparar(-1601101, pg_temp.p1('dueno')::uuid, 'prueba');
    v_e := (v_p->>'enlace')::uuid;
    begin
      perform fn_stripe_enlace_creado(v_e, jsonb_build_object('id', 'plink_P1T10A', 'url', 'https://buy.stripe.com/test_a', 'livemode', false,
                                                              'metadata', jsonb_build_object('enlace', gen_random_uuid()::text)));
      v_r := v_r || 'entró'::text;
    exception when others then v_r := v_r || sqlstate::text; end;
    v_x := fn_stripe_enlace_creado(v_e, jsonb_build_object('id', 'plink_P1T10A', 'url', 'https://buy.stripe.com/test_a', 'livemode', false,
                                                           'metadata', v_p->'metadata'));
    v_r := v_r || (v_x->>'enlace_estado');
    v_x := fn_stripe_enlace_creado(v_e, jsonb_build_object('id', 'plink_P1T10A', 'url', 'https://buy.stripe.com/test_a', 'livemode', false,
                                                           'metadata', v_p->'metadata'));
    v_r := v_r || (v_x->>'enlace_estado');
    begin
      perform fn_stripe_enlace_creado(v_e, jsonb_build_object('id', 'plink_P1T10B', 'url', 'https://buy.stripe.com/test_b', 'livemode', false,
                                                              'metadata', v_p->'metadata'));
      v_r := v_r || 'entró'::text;
    exception when others then v_r := v_r || sqlstate::text; end;
    v_r := v_r || (fn_stripe_enlace_preparar(-1601101, pg_temp.p1('dueno')::uuid, 'prueba')->>'accion');
    v_r := v_r || ((fn_stripe_enlace_preparar(-1601101, pg_temp.p1('dueno')::uuid, 'prueba', false, false, true)->>'accion')
                   || ' (' || (select count(*) from stripe_enlaces where factura_id = -1601101) || ')');
    begin
      insert into stripe_enlaces (factura_id, factura_num, monto, saldo_cxc, saldo_retencion, estado, idempotencia, creado_por)
      values (-1601101, 'P1-1601101', 500.00, 500.00, 0, 'creando', 'p1-pruebas-otro', pg_temp.p1('dueno')::uuid);
      v_r := v_r || 'entró'::text;
    exception when others then v_r := v_r || sqlstate::text; end;
    v_e2 := (fn_stripe_enlace_preparar(-1601102, pg_temp.p1('dueno')::uuid, 'prueba')->>'enlace')::uuid;
    v_r := v_r || (fn_stripe_enlace_fallo(v_e2, 'Stripe dijo que no')->>'estado');
    v_r := v_r || (fn_stripe_enlace_desactivado('plink_P1T10A', 'el cliente pagó', 'stripe', true)->>'estado');
    perform pg_temp.p1_enlace(-1601103, 'plink_P1T10C');
    v_x := fn_stripe_enlace_desactivado('plink_P1T10C', 'la factura ya debe menos', 'rutina');
    v_r := v_r || ((v_x->>'estado') || ' con aviso ' || (select count(*) from stripe_avisos a where a.clave = 'enlace:' || (v_x->>'id')));
    v_r := v_r || case when (fn_stripe_enlace_desactivado('plink_DESCONOCIDO', 'x', 'stripe')->>'ignorado')::boolean then 'ignorado' else 'MAL' end;
    v_obt := array_to_string(v_r, ' | ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'el enlace: creado, repetido, de otro, listo, reemplazar, uno vivo por factura, fallido, usado, desactivado, desconocido',
    '22023 | activo | activo | MX008 | listo | desactivar (1) | 23505 | fallido | usado | desactivado con aviso 1 | ignorado', v_obt,
    v_obt = '22023 | activo | activo | MX008 | listo | desactivar (1) | 23505 | fallido | usado | desactivado con aviso 1 | ignorado');
end $$;


-- =====================================================================
-- Un pago, al libro (en nombre del dueño)
-- =====================================================================

-- 11. Tarjeta cobrada por 900.00 (la factura de 1,000.00 con 100.00 de
--     retención): un cobro vigente Dr la puente / Cr 1110 con su partida y
--     su obra, por el puente de c3, en nombre del dueño, con su rastro; el
--     enlace queda usado; los claims, como estaban
do $$
declare
  v_obt text; v_r jsonb; c cobros; a asientos; s stripe_pagos; v_l text; v_claims text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601111, 1000.00, 100.00);
    v_r := pg_temp.p1_pagar('pi_P1T11', -1601111, 90000);
    v_claims := coalesce(current_setting('request.jwt.claims', true), '') || '|' || coalesce(current_setting('request.jwt.claim.sub', true), '');
    select * into s from stripe_pagos where pi = 'pi_P1T11';
    select * into c from cobros where id = s.cobro_id;
    select * into a from asientos where id = c.contabilizado_en;
    v_obt := format('%s | %s · %s %s | %s %s %s | notas %s | creado_por %s · usuario %s | rastro %s %s | %s %s/%s | enlace %s | claims %s',
                    pg_temp.p1_lineas(a.id), a.camino, a.origen_tabla, case when a.origen_id = c.id::text then 'su cobro' else 'MAL' end,
                    c.medio, case when c.referencia = 'pi_P1T11' then 'ref pi' else 'MAL' end, c.llave_cliente,
                    case when c.notas like '%evt_P1T11%' and c.notas like '%plink_P1T11%' then 'con evento y enlace' else 'MAL ' || c.notas end,
                    case when c.creado_por = pg_temp.p1('dueno')::uuid then 'dueño' else 'MAL' end,
                    case when a.usuario_id = pg_temp.p1('dueno')::uuid then 'dueño' else 'MAL' end,
                    (select string_agg(pl.accion || ' ' || pl.monto, ', ') from stripe_pago_libro pl where pl.pago_id = s.id),
                    case when (select pl.asiento_id from stripe_pago_libro pl where pl.pago_id = s.id) = a.id then 'con su asiento' else 'MAL' end,
                    s.estado, s.objetivo, s.en_libro, (select e.estado from stripe_enlaces e where e.id = s.enlace_id),
                    case when v_claims = '|' then 'como estaban' else 'MAL ' || v_claims end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'tarjeta cobrada: el cobro de c3 a la puente, contra su factura, en nombre del dueño y con su rastro',
    format('%s 900.00 | %s -900.00 facturas/-1601111 obra | puente · cobros su cobro | tarjeta ref pi stripe:pi_P1T11 | notas con evento y enlace | creado_por dueño · usuario dueño | rastro cobro 900.00 con su asiento | cobrado 900.00/900.00 | enlace usado | claims como estaban',
           pg_temp.p1('puente'), pg_temp.p1('cxc')), v_obt,
    v_obt = format('%s 900.00 | %s -900.00 facturas/-1601111 obra | puente · cobros su cobro | tarjeta ref pi stripe:pi_P1T11 | notas con evento y enlace | creado_por dueño · usuario dueño | rastro cobro 900.00 con su asiento | cobrado 900.00/900.00 | enlace usado | claims como estaban',
                   pg_temp.p1('puente'), pg_temp.p1('cxc')));
end $$;

-- 12. La misma foto otra vez no hace nada; una foto más vieja que la
--     guardada no toca nada; tres avisos distintos del mismo pago, un cobro
do $$
declare
  v_obt text; v_r jsonb; v_r2 jsonb; v_viejo jsonb; v_f jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601121, 800.00);
    v_r := pg_temp.p1_pagar('pi_P1T12', -1601121, 80000);
    v_f := pg_temp.p1_foto('pi_P1T12', 'succeeded', 80000);
    v_r2 := fn_stripe_pago_sincronizar(v_f, 'evt_P1T12B');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T12', 'succeeded', 80000), 'evt_P1T12C');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T12', 'succeeded', 80000), 'evt_P1T12D');
    v_viejo := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T12', 'processing', 80000)
                                          || jsonb_build_object('visto_el', now() - interval '1 day'), 'evt_P1T12E');
    v_obt := format('otra vez: %s cambios | vieja: %s, sigue %s | %s cobro(s), %s asiento(s) de cobro',
                    jsonb_array_length(v_r2->'cambios'), case when (v_viejo->>'viejo')::boolean then 'viejo' else 'MAL' end,
                    (select s.estado from stripe_pagos s where s.pi = 'pi_P1T12'),
                    (select count(*) from cobros c where c.referencia = 'pi_P1T12'),
                    (select count(*) from asientos a join cobros c on a.origen_tabla = 'cobros' and a.origen_id = c.id::text
                      where c.referencia = 'pi_P1T12'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'idempotencia: la misma foto, una foto vieja y tres avisos del mismo pago',
    'otra vez: 0 cambios | vieja: viejo, sigue cobrado | 1 cobro(s), 1 asiento(s) de cobro', v_obt,
    v_obt = 'otra vez: 0 cambios | vieja: viejo, sigue cobrado | 1 cobro(s), 1 asiento(s) de cobro');
end $$;

-- 13. ACH: en camino sin asiento; cobrado con la fecha de su aviso; una
--     foto vieja de «processing» no lo toca. Otro: falla (sin asiento,
--     aviso). Una tarjeta rechazada dentro del checkout: ni fila ni aviso.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_r jsonb; v_t0 timestamptz;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601131, 500.00);
    perform pg_temp.p1_factura(-1601132, 500.00);
    perform pg_temp.p1_enlace(-1601131, 'plink_P1T13A');
    perform pg_temp.p1_enlace(-1601132, 'plink_P1T13B');
    v_t0 := clock_timestamp();
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13A', 'processing', 50000, null, 'ach'), 'evt_P1T13A');
    v_a := format('%s %s asiento(s)', v_r->>'estado', (select count(*) from stripe_pago_libro pl join stripe_pagos s on s.id = pl.pago_id
                                                       where s.pi = 'pi_P1T13A'));
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13A', 'succeeded', 50000, null, 'ach')
                                      || jsonb_build_object('fecha_exito', pg_temp.p1('d')), 'evt_P1T13B');
    v_a := v_a || format(' → %s el %s', v_r->>'estado',
                         (select c.fecha from stripe_pagos s join cobros c on c.id = s.cobro_id where s.pi = 'pi_P1T13A'));
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13A', 'processing', 50000, null, 'ach')
                                      || jsonb_build_object('visto_el', v_t0), 'evt_P1T13C');
    v_a := v_a || format(' → la vieja: %s, sigue %s', case when (v_r->>'viejo')::boolean then 'no toca' else 'MAL' end,
                         (select s.estado from stripe_pagos s where s.pi = 'pi_P1T13A'));
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13B', 'processing', 50000, null, 'ach'), 'evt_P1T13D');
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13B', 'requires_payment_method', 50000, null, 'ach')
                                      || jsonb_build_object('ultimo_error', jsonb_build_object('codigo', 'insufficient_funds',
                                                                                               'mensaje', 'fondos insuficientes')), 'evt_P1T13E');
    v_b := format('%s, %s cobro(s), aviso %s%s', v_r->>'estado', (select count(*) from cobros where referencia = 'pi_P1T13B'),
                  (select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T13B:fallido'),
                  case when (select a.texto from stripe_avisos a where a.clave = 'pago:pi_P1T13B:fallido') like '%crea uno nuevo%'
                       then ' «crea uno nuevo»' else '' end);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T13C', 'requires_payment_method', 50000), 'evt_P1T13F');
    v_c := format('%s, %s fila(s), %s aviso(s)', v_r->>'ignorado', (select count(*) from stripe_pagos where pi = 'pi_P1T13C'),
                  (select count(*) from stripe_avisos a where a.objeto = 'pi_P1T13C'));
    v_obt := v_a || ' | ' || v_b || ' | ' || v_c;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'ACH: en camino sin asiento, cobrado en la fecha de su aviso, la foto vieja no toca; ACH fallido; tarjeta rechazada',
    format('en_camino 0 asiento(s) → cobrado el %s → la vieja: no toca, sigue cobrado | fallido, 0 cobro(s), aviso bad «crea uno nuevo» | intento en la página de pago, 0 fila(s), 0 aviso(s)',
           pg_temp.p1('d')), v_obt,
    v_obt = format('en_camino 0 asiento(s) → cobrado el %s → la vieja: no toca, sigue cobrado | fallido, 0 cobro(s), aviso bad «crea uno nuevo» | intento en la página de pago, 0 fila(s), 0 aviso(s)',
                   pg_temp.p1('d')));
end $$;

-- 14. Microdepósitos: verificando la cuenta (iniciado); cancelado, fallido
--     con aviso; a los 13 días, la alarma 31 en rojo
do $$
declare
  v_obt text; v_a text; v_b text; v_c text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601141, 500.00);
    perform pg_temp.p1_factura(-1601142, 500.00);
    perform pg_temp.p1_enlace(-1601141, 'plink_P1T14A');
    perform pg_temp.p1_enlace(-1601142, 'plink_P1T14B');
    v_a := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T14A', 'requires_action', 50000, null, 'ach'), 'evt_P1T14A')->>'estado';
    v_b := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T14A', 'canceled', 50000, null, 'ach')
                                      || jsonb_build_object('cancelacion', 'abandoned'), 'evt_P1T14B')->>'estado';
    v_b := v_b || ' con aviso ' || coalesce((select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T14A:fallido'), 'NINGUNO');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T14B', 'requires_action', 50000, null, 'ach'), 'evt_P1T14C');
    v_c := pg_temp.p1_fila(31);
    update stripe_pagos set creado_el = now() - interval '13 days' where pi = 'pi_P1T14B';
    v_c := v_c || ' → ' || pg_temp.p1_fila(31);
    v_obt := format('%s → %s | alarma 31: %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'microdepósitos: iniciado, cancelado con aviso, y la alarma de los 12 días',
    'iniciado → fallido con aviso bad | alarma 31: verde → rojo', v_obt, v_obt = 'iniciado → fallido con aviso bad | alarma 31: verde → rojo');
end $$;

-- 15. Sobrepago: 1,200.00 a una factura que debe 1,000.00 (200.00 de
--     anticipo de su obra, con aviso); con retención, el exceso va primero
--     a la retención
do $$
declare
  v_obt text; v_a text; v_b text; s stripe_pagos;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601151, 1000.00);
    perform pg_temp.p1_factura(-1601152, 1000.00, 100.00);
    perform pg_temp.p1_pagar('pi_P1T15A', -1601151, 120000);
    select * into s from stripe_pagos where pi = 'pi_P1T15A';
    v_a := replace(pg_temp.p1_lineas((select c.contabilizado_en from cobros c where c.id = s.cobro_id)), s.cobro_id::text, '<cobro>')
           || ' · aviso ' || coalesce((select a.nivel from stripe_avisos a where a.clave = 'sobra:pi_P1T15A'), 'NINGUNO');
    perform pg_temp.p1_pagar('pi_P1T15B', -1601152, 120000);
    select * into s from stripe_pagos where pi = 'pi_P1T15B';
    v_b := replace(pg_temp.p1_lineas((select c.contabilizado_en from cobros c where c.id = s.cobro_id)), s.cobro_id::text, '<cobro>');
    v_obt := v_a || ' || ' || v_b;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'sobrepago: lo que sobra, de anticipo de la obra (con la retención primero)',
    format('%1$s 1200.00 | %2$s -1000.00 facturas/-1601151 obra | %2$s -200.00 cobros/<cobro> obra · aviso warn || %1$s 1200.00 | %2$s -900.00 facturas/-1601152 obra | %3$s -100.00 facturas/-1601152 obra | %2$s -200.00 cobros/<cobro> obra',
           pg_temp.p1('puente'), pg_temp.p1('cxc'), pg_temp.p1('ret')), v_obt,
    v_obt = format('%1$s 1200.00 | %2$s -1000.00 facturas/-1601151 obra | %2$s -200.00 cobros/<cobro> obra · aviso warn || %1$s 1200.00 | %2$s -900.00 facturas/-1601152 obra | %3$s -100.00 facturas/-1601152 obra | %2$s -200.00 cobros/<cobro> obra',
                   pg_temp.p1('puente'), pg_temp.p1('cxc'), pg_temp.p1('ret')));
end $$;

-- 16. La factura no acepta el pago: cobrada antes por cheque (todo de
--     anticipo), anulada después del enlace, o de fecha posterior al pago:
--     entra de anticipo de su obra, con el porqué en el aviso
do $$
declare
  v_obt text; v_r text[] := '{}'; v_x text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    -- a) cobrada antes por cheque en el banco
    perform pg_temp.p1_factura(-1601161, 1000.00);
    perform pg_temp.p1_enlace(-1601161, 'plink_P1T16A');
    perform pg_temp.p1_ser('como_dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.p1('d'), 'monto', '1000.00', 'medio', 'cheque', 'referencia', 'P1-PRUEBA-551',
                                                  'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -1601161, 'monto', '1000.00'))));
    perform pg_temp.p1_ser('servicio');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T16A', 'succeeded', 100000), 'evt_P1T16A');
    select a.texto into v_x from stripe_avisos a where a.clave = 'sobra:pi_P1T16A';
    v_r := v_r || format('cheque antes: anticipo %s (%s)',
                         (select pl.anticipo from stripe_pago_libro pl join stripe_pagos s on s.id = pl.pago_id where s.pi = 'pi_P1T16A'),
                         case when v_x like '%le cobraba $0.00%' then 'le cobraba $0.00' else coalesce(v_x, 'sin aviso') end);
    -- b) anulada después de mandar el enlace
    perform pg_temp.p1_factura(-1601162, 1000.00);
    perform pg_temp.p1_enlace(-1601162, 'plink_P1T16B');
    perform fn_factura_anular(-1601162, 'p1-pruebas: se deshace');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T16B', 'succeeded', 100000), 'evt_P1T16B');
    select a.texto into v_x from stripe_avisos a where a.clave = 'sobra:pi_P1T16B';
    v_r := v_r || format('anulada: anticipo %s (%s)',
                         (select pl.anticipo from stripe_pago_libro pl join stripe_pagos s on s.id = pl.pago_id where s.pi = 'pi_P1T16B'),
                         case when v_x like '%está anulada%' then 'está anulada' else coalesce(v_x, 'sin aviso') end);
    -- c) la factura es de después del pago
    perform pg_temp.p1_factura(-1601163, 1000.00, 0, pg_temp.p1('hoy')::date + 1);
    perform pg_temp.p1_enlace(-1601163, 'plink_P1T16C');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T16C', 'succeeded', 100000), 'evt_P1T16C');
    select a.texto into v_x from stripe_avisos a where a.clave = 'sobra:pi_P1T16C';
    v_r := v_r || format('posterior: anticipo %s (%s)',
                         (select pl.anticipo from stripe_pago_libro pl join stripe_pagos s on s.id = pl.pago_id where s.pi = 'pi_P1T16C'),
                         case when v_x like '%es anterior a la factura%' then 'es anterior a la factura' else coalesce(v_x, 'sin aviso') end);
    v_obt := array_to_string(v_r, ' | ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'la factura no acepta el pago: de anticipo de su obra, con el porqué',
    'cheque antes: anticipo 1000.00 (le cobraba $0.00) | anulada: anticipo 1000.00 (está anulada) | posterior: anticipo 1000.00 (es anterior a la factura)',
    v_obt, v_obt = 'cheque antes: anticipo 1000.00 (le cobraba $0.00) | anulada: anticipo 1000.00 (está anulada) | posterior: anticipo 1000.00 (es anterior a la factura)');
end $$;

-- 17. Un pago sin factura: por resolver (sin cobro, aviso, alarma 30); a
--     una factura con su motivo, cobrado; otra vez, MX008; sin motivo,
--     22023; «fuera» a un ingreso, sin cobro; «fuera» a un banco, la
--     cuenta por cobrar o la puente, MX004
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text; v_e text[] := '{}'; v_x text; v_r jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601171, 300.00);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T17A', 'succeeded', 30000), 'evt_P1T17A');
    v_a := format('%s, %s cobro(s), aviso %s, alarma 30 %s', v_r->>'estado', (select count(*) from cobros where referencia = 'pi_P1T17A'),
                  (select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T17A:revisar'), pg_temp.p1_fila(30));
    v_r := fn_stripe_pago_resolver('pi_P1T17A', jsonb_build_object('factura_id', -1601171), 'p1-pruebas: lo dijo Edgar',
                                   pg_temp.p1('dueno')::uuid);
    v_b := format('%s, %s cobro(s)', v_r->'pago'->>'estado', (select count(*) from cobros where referencia = 'pi_P1T17A'));
    begin
      perform fn_stripe_pago_resolver('pi_P1T17A', jsonb_build_object('factura_id', -1601171), 'otra vez', pg_temp.p1('dueno')::uuid);
      v_c := 'entró';
    exception when others then v_c := sqlstate; end;
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T17B', 'succeeded', 20000), 'evt_P1T17B');
    begin
      perform fn_stripe_pago_resolver('pi_P1T17B', jsonb_build_object('factura_id', -1601171), ' ', pg_temp.p1('dueno')::uuid);
      v_c := v_c || ' · sin motivo entró';
    exception when others then v_c := v_c || ' · sin motivo ' || sqlstate; end;
    v_r := fn_stripe_pago_resolver('pi_P1T17B', jsonb_build_object('fuera', jsonb_build_object('cuenta', pg_temp.p1('ingreso'))),
                                   'p1-pruebas: cobrado antes de la app', pg_temp.p1('dueno')::uuid);
    v_d := format('%s, %s cobro(s), fuera a %s', v_r->'pago'->>'estado', (select count(*) from cobros where referencia = 'pi_P1T17B'),
                  (select s.resuelto->'fuera'->>'cuenta' from stripe_pagos s where s.pi = 'pi_P1T17B'));
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T17C', 'succeeded', 20000), 'evt_P1T17C');
    foreach v_x in array array[pg_temp.p1('banco'), pg_temp.p1('cxc'), pg_temp.p1('puente')] loop
      begin
        perform fn_stripe_pago_resolver('pi_P1T17C', jsonb_build_object('fuera', jsonb_build_object('cuenta', v_x)), 'p1-pruebas',
                                        pg_temp.p1('dueno')::uuid);
        v_e := v_e || 'entró'::text;
      exception when others then v_e := v_e || sqlstate::text; end;
    end loop;
    v_obt := format('%s | resuelto: %s | otra vez %s | %s | fuera a banco, cxc, puente: %s', v_a, v_b, v_c, v_d, array_to_string(v_e, ' '));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'un pago sin factura: por resolver; a una factura, fuera, y lo que no se puede',
    format('revisar, 0 cobro(s), aviso bad, alarma 30 rojo | resuelto: cobrado, 1 cobro(s) | otra vez MX008 · sin motivo 22023 | cobrado, 0 cobro(s), fuera a %s | fuera a banco, cxc, puente: MX004 MX004 MX004',
           pg_temp.p1('ingreso')), v_obt,
    v_obt = format('revisar, 0 cobro(s), aviso bad, alarma 30 rojo | resuelto: cobrado, 1 cobro(s) | otra vez MX008 · sin motivo 22023 | cobrado, 0 cobro(s), fuera a %s | fuera a banco, cxc, puente: MX004 MX004 MX004',
                   pg_temp.p1('ingreso')));
end $$;

-- 18. Los metadatos dicen otra factura que el enlace: por resolver
do $$
declare
  v_obt text; v_r jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601181, 500.00);
    perform pg_temp.p1_factura(-1601182, 500.00);
    perform pg_temp.p1_enlace(-1601181, 'plink_P1T18');
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T18', 'succeeded', 50000)
                                      || jsonb_build_object('metadata', jsonb_build_object('mxp', 'p1', 'factura_id', '-1601182')), 'evt_P1T18');
    v_obt := format('%s: %s · %s cobro(s)', v_r->>'estado', (select s.revisar from stripe_pagos s where s.pi = 'pi_P1T18'),
                    (select count(*) from cobros where referencia = 'pi_P1T18'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'los metadatos de Stripe dicen otra factura que el enlace: por resolver',
    'revisar: los metadatos de Stripe dicen otra factura que el enlace · 0 cobro(s)', v_obt,
    v_obt = 'revisar: los metadatos de Stripe dicen otra factura que el enlace · 0 cobro(s)');
end $$;


-- =====================================================================
-- Reembolsos y disputas: un cobro vivo por pago
-- =====================================================================

-- 19. Reembolso parcial de 100.00 de 1,000.00: el cobro se devuelve entero y
--     se registra el nuevo por 900.00 (otra llave, la misma referencia), sin
--     el MX008 de «el mismo depósito». Contraprueba: otro cobro vivo del
--     mismo pago por lo mismo, sí da MX008.
do $$
declare
  v_obt text; v_p0 numeric; v_dev text; v_c cobros; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601191, 1000.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T19', -1601191, 100000);
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T19', 'succeeded', 100000)
                                       || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T19', 10000, 'txn_R_P1T19'))),
                                       'evt_P1T19R');
    select string_agg(dv.monto::text, ', ') into v_dev
      from cobros_devoluciones dv join cobros c on c.id = dv.cobro_id where c.referencia = 'pi_P1T19';
    select c.* into v_c from stripe_pagos s join cobros c on c.id = s.cobro_id where s.pi = 'pi_P1T19';
    perform pg_temp.p1_ser('como_dueno');
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', v_c.fecha, 'monto', '900.00', 'cuenta', pg_temp.p1('puente'), 'medio', 'tarjeta',
                                                    'referencia', 'pi_P1T19', 'llave_cliente', 'p1-pruebas:otro-hecho',
                                                    'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', pg_temp.p1('obra'),
                                                                                                          'monto', '900.00'))));
      v_e := 'entró';
    exception when others then v_e := sqlstate; end;
    perform pg_temp.p1_ser('servicio');
    v_obt := format('devuelto %s + cobro %s (%s, ref %s) | la factura debe %s | la puente +%s | otro cobro vivo igual: %s',
                    v_dev, v_c.monto, v_c.llave_cliente, v_c.referencia,
                    (select fc.saldo_cxc from facturas_cobro fc where fc.id = -1601191),
                    pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'reembolso parcial: devolver el cobro entero y registrar lo que queda (un cobro vivo por pago)',
    'devuelto 1000.00 + cobro 900.00 (stripe:pi_P1T19:v1, ref pi_P1T19) | la factura debe 100.00 | la puente +900.00 | otro cobro vivo igual: MX008',
    v_obt, v_obt = 'devuelto 1000.00 + cobro 900.00 (stripe:pi_P1T19:v1, ref pi_P1T19) | la factura debe 100.00 | la puente +900.00 | otro cobro vivo igual: MX008');
end $$;

-- 20. Reembolso total: devuelto, la puente como antes; un reembolso sin su
--     balance transaction todavía no cuenta; el mismo otra vez, nada
do $$
declare
  v_obt text; v_p0 numeric; v_r jsonb; v_a text; v_b text; v_c text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601201, 1000.00);
    perform pg_temp.p1_factura(-1601202, 1000.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T20A', -1601201, 100000);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T20A', 'succeeded', 100000)
                                      || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T20A', 100000, 'txn_R_P1T20A'))),
                                      'evt_P1T20R');
    v_a := format('%s, en el libro %s, la puente +%s', v_r->>'estado', v_r->>'en_libro', pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T20A', 'succeeded', 100000)
                                      || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T20A', 100000, 'txn_R_P1T20A'))),
                                      'evt_P1T20S');
    v_c := jsonb_array_length(v_r->'cambios')::text;
    perform pg_temp.p1_pagar('pi_P1T20B', -1601202, 100000);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T20B', 'succeeded', 100000)
                                      || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T20B', 40000, null, 'pending'))),
                                      'evt_P1T20T');
    v_b := format('%s, en el libro %s', v_r->>'estado', v_r->>'en_libro');
    v_obt := format('%s | otra vez: %s cambios | sin su balance transaction: %s', v_a, v_c, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'reembolso total; el que no tiene su balance transaction no cuenta; el mismo otra vez, nada',
    'devuelto, en el libro 0.00, la puente +0.00 | otra vez: 0 cambios | sin su balance transaction: cobrado, en el libro 1000.00', v_obt,
    v_obt = 'devuelto, en el libro 0.00, la puente +0.00 | otra vez: 0 cambios | sin su balance transaction: cobrado, en el libro 1000.00');
end $$;

-- 21. El reembolso falla y el dinero vuelve: se devuelve el de 900.00 y se
--     registra 1,000.00 (:v2), con aviso; todo o nada: si el nuevo no entra,
--     el cobro vivo sigue y el pago queda por resolver
do $$
declare
  v_obt text; v_p0 numeric; v_r jsonb; v_a text; v_b text; v_f jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601211, 1000.00);
    perform pg_temp.p1_factura(-1601212, 1000.00);
    perform pg_temp.p1_factura(-1601213, 1000.00, 0, null, '-');
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T21A', -1601211, 100000);
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T21A', 'succeeded', 100000)
                                       || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T21A', 10000, 'txn_R_P1T21A'))),
                                       'evt_P1T21R');
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T21A', 'succeeded', 100000)
                                      || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T21A', 10000, 'txn_R_P1T21A',
                                                                                                                 'failed', 'txn_RF_P1T21A'))),
                                      'evt_P1T21F');
    v_a := format('%s %s (%s) aviso %s | la puente +%s', v_r->>'estado', v_r->>'en_libro',
                  (select c.llave_cliente from stripe_pagos s join cobros c on c.id = s.cobro_id where s.pi = 'pi_P1T21A'),
                  coalesce((select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T21A:reembolso_fallo:re_P1T21A'), 'NINGUNO'),
                  pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0);
    -- todo o nada: el pago se lleva a una factura sin obra que no está en el
    -- libro: devolver entra, registrar no; se deshace el par
    perform pg_temp.p1_pagar('pi_P1T21B', -1601212, 100000);
    v_f := pg_temp.p1_foto('pi_P1T21B', 'succeeded', 100000)
           || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T21B', 10000, 'txn_R_P1T21B')));
    perform fn_stripe_pago_sincronizar(v_f, 'evt_P1T21S');
    update stripe_pagos set factura_id = -1601213 where pi = 'pi_P1T21B';
    v_r := fn_stripe_pago_sincronizar(v_f || jsonb_build_object('visto_el', clock_timestamp(), 'reembolsos',
                                        jsonb_build_array(pg_temp.p1_reembolso('re_P1T21B', 10000, 'txn_R_P1T21B', 'failed', 'txn_RF_P1T21B'))),
                                      'evt_P1T21T');
    v_b := format('%s, en el libro %s, su cobro %s', v_r->>'estado', v_r->>'en_libro',
                  (select case when c.estado = 'vigente' and not exists (select 1 from cobros_devoluciones dv where dv.cobro_id = c.id)
                               then 'sigue vivo (' || c.monto || ')' else 'MAL' end
                     from stripe_pagos s join cobros c on c.id = s.cobro_id where s.pi = 'pi_P1T21B'));
    v_obt := v_a || ' | todo o nada: ' || v_b;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'un reembolso que falla: el cobro vuelve entero; todo o nada si el nuevo no entra',
    'cobrado 1000.00 (stripe:pi_P1T21A:v2) aviso warn | la puente +1000.00 | todo o nada: revisar, en el libro 900.00, su cobro sigue vivo (900.00)',
    v_obt, v_obt = 'cobrado 1000.00 (stripe:pi_P1T21A:v2) aviso warn | la puente +1000.00 | todo o nada: revisar, en el libro 900.00, su cobro sigue vivo (900.00)');
end $$;

-- 22. Disputas: retirada (devuelto, en disputa, aviso con su fecha), ganada
--     (el cobro vuelve, aviso), perdida (nada más, devuelto, aviso; la de
--     cuenta de banco no se impugna), parcial (devuelto + lo que queda) y
--     una consulta sin retiro (en disputa, sin tocar el libro)
do $$
declare
  v_obt text; v_r jsonb; v_a text; v_b text; v_c text; v_d text; v_bt jsonb;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601221, 1000.00);
    perform pg_temp.p1_factura(-1601222, 1000.00);
    perform pg_temp.p1_factura(-1601223, 1000.00);
    perform pg_temp.p1_factura(-1601224, 1000.00);
    -- a) tarjeta: retirada y ganada
    perform pg_temp.p1_pagar('pi_P1T22A', -1601221, 100000);
    v_bt := jsonb_build_array(pg_temp.p1_bt('txn_D_P1T22A', 'dispute', -100000, 1500));
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22A', 'succeeded', 100000)
                                      || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22A', 100000, 'needs_response', v_bt))),
                                      'evt_P1T22A');
    v_a := format('%s %s, aviso %s%s', v_r->>'estado', v_r->>'en_libro',
                  (select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T22A:disputa:dp_P1T22A'),
                  case when (select a.texto from stripe_avisos a where a.clave = 'pago:pi_P1T22A:disputa:dp_P1T22A')
                            like '%antes del ' || (fn_fecha_miami(now() + interval '7 days'))::text || '%' then ' con su fecha' else '' end);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22A', 'succeeded', 100000)
                                      || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22A', 100000, 'won',
                                           v_bt || pg_temp.p1_bt('txn_DR_P1T22A', 'dispute_reversal', 100000)))), 'evt_P1T22B');
    v_a := v_a || format(' → ganada: %s %s, aviso %s', v_r->>'estado', v_r->>'en_libro',
                         (select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T22A:ganada:dp_P1T22A'));
    -- b) ACH: retirada y perdida
    perform pg_temp.p1_pagar('pi_P1T22B', -1601222, 100000, 'ach');
    v_bt := jsonb_build_array(pg_temp.p1_bt('txn_D_P1T22B', 'dispute', -100000, 1500));
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22B', 'succeeded', 100000, null, 'ach')
                                       || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22B', 100000, 'needs_response', v_bt,
                                                                                                              'insufficient_funds'))),
                                       'evt_P1T22C');
    v_b := case when (select a.texto from stripe_avisos a where a.clave = 'pago:pi_P1T22B:disputa:dp_P1T22B') like '%no se pueden impugnar%'
                then 'no se impugna' else 'MAL' end;
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22B', 'succeeded', 100000, null, 'ach')
                                      || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22B', 100000, 'lost', v_bt,
                                                                                                             'insufficient_funds'))),
                                      'evt_P1T22D');
    v_b := v_b || format(' → perdida: %s %s, %s cambios, aviso %s', v_r->>'estado', v_r->>'en_libro', jsonb_array_length(v_r->'cambios'),
                         (select a.nivel from stripe_avisos a where a.clave = 'pago:pi_P1T22B:perdida:dp_P1T22B'));
    -- c) parcial: 400.00 de 1,000.00
    perform pg_temp.p1_pagar('pi_P1T22C', -1601223, 100000);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22C', 'succeeded', 100000)
                                      || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22C', 40000, 'under_review',
                                           jsonb_build_array(pg_temp.p1_bt('txn_D_P1T22C', 'dispute', -40000, 1500))))), 'evt_P1T22E');
    v_c := format('%s %s (%s)', v_r->>'estado', v_r->>'en_libro',
                  (select string_agg(x->>'accion' || ' ' || (x->>'monto'), ', ') from jsonb_array_elements(v_r->'cambios') x));
    -- d) una consulta sin retiro
    perform pg_temp.p1_pagar('pi_P1T22D', -1601224, 100000);
    v_r := fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T22D', 'succeeded', 100000)
                                      || jsonb_build_object('disputas', jsonb_build_array(pg_temp.p1_disputa('dp_P1T22D', 100000,
                                           'warning_needs_response', '[]'::jsonb, 'general'))), 'evt_P1T22F');
    v_d := format('%s %s, %s cambios', v_r->>'estado', v_r->>'en_libro', jsonb_array_length(v_r->'cambios'));
    v_obt := format('retirada: %s | ACH: %s | parcial: %s | consulta: %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'disputas: al retirarse se devuelve; ganada vuelve; perdida, nada más; parcial; consulta sin retiro',
    'retirada: en_disputa 0.00, aviso bad con su fecha → ganada: cobrado 1000.00, aviso info | ACH: no se impugna → perdida: devuelto 0.00, 0 cambios, aviso warn | parcial: en_disputa 600.00 (devolucion -1000.00, cobro 600.00) | consulta: en_disputa 1000.00, 0 cambios',
    v_obt, v_obt = 'retirada: en_disputa 0.00, aviso bad con su fecha → ganada: cobrado 1000.00, aviso info | ACH: no se impugna → perdida: devuelto 0.00, 0 cambios, aviso warn | parcial: en_disputa 600.00 (devolucion -1000.00, cobro 600.00) | consulta: en_disputa 1000.00, 0 cambios');
end $$;

-- 23. El mes del pago, cerrado: el cobro entra el primer día del mes
--     abierto, con su nota de tardío (c3). Un mes que todavía no se abrió:
--     MX002 y no queda nada (el aviso se reintenta)
do $$
declare
  v_obt text; v_a text; v_b text; v_esp date; pl stripe_pago_libro; v_sin date; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    lock table public.periodos in exclusive mode;   -- antes que el candado de la cadena (como c3-pruebas)
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601231, 1000.00);
    perform pg_temp.p1_enlace(-1601231, 'plink_P1T23A');
    perform pg_temp.p1_cerrar_hasta(to_char(pg_temp.p1('hoy')::date, 'YYYY-MM'));
    v_esp := (fn_puente_fecha(pg_temp.p1('hoy')::date)->>'fecha')::date;
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T23A', 'succeeded', 100000), 'evt_P1T23A');
    select x.* into pl from stripe_pago_libro x join stripe_pagos s on s.id = x.pago_id where s.pi = 'pi_P1T23A';
    v_a := format('%s, %s', case when pl.fecha_contable = v_esp and v_esp > pg_temp.p1('hoy')::date then 'entró el primer día del mes abierto'
                                 else 'MAL ' || coalesce(pl.fecha_contable::text, 'sin cobro') end,
                  case when pl.tardio is not null then 'con su nota de tardío' else 'sin nota' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601232, 1000.00);
    perform pg_temp.p1_enlace(-1601232, 'plink_P1T23B');
    v_sin := (select max(p.hasta) + 1 from periodos p where p.tipo = 'mes');
    perform pg_temp.p1_fingir_hoy(v_sin - 10);
    begin
      perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T23B', 'succeeded', 100000)
                                         || jsonb_build_object('fecha_exito', (v_sin + 4)::text), 'evt_P1T23B');
      v_e := 'entró';
    exception when others then
      v_e := sqlstate || case when sqlerrm ~* 'no se abri' then ' «no se abrió»' else ' ' || sqlerrm end;
    end;
    v_b := format('%s | %s cobro(s), %s pago(s)', v_e, (select count(*) from cobros where referencia = 'pi_P1T23B'),
                  (select count(*) from stripe_pagos where pi = 'pi_P1T23B'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_b := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  v_obt := v_a || ' | sin abrir: ' || v_b;
  insert into _pruebas values (23, 'el mes del pago cerrado: tardío en el mes abierto; un mes sin abrir: MX002 y nada queda',
    'entró el primer día del mes abierto, con su nota de tardío | sin abrir: MX002 «no se abrió» | 0 cobro(s), 0 pago(s)', v_obt,
    v_obt = 'entró el primer día del mes abierto, con su nota de tardío | sin abrir: MX002 «no se abrió» | 0 cobro(s), 0 pago(s)');
end $$;


-- =====================================================================
-- Los depósitos de Stripe a Chase
-- =====================================================================

-- 24. El depósito completo (tarjeta 1,000.00 con 29.30 de comisión, ACH
--     500.00 con 4.00, un reembolso de 100.00 y un cargo de 1.00; neto
--     1,365.70): P1 Dr 1140 + Dr 6130 / Cr 1020 y P2 Dr 1010 / Cr 1140, a
--     mano, sin origen ni documento, con la misma fecha y su procedencia;
--     la puente y la de paso en cero; su papel existe para c4; otra vez,
--     nada
do $$
declare
  v_obt text; v_p0 numeric; v_r jsonb; p stripe_payouts; a1 asientos; a2 asientos; v_x text; v_n bigint;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601241, 1000.00);
    perform pg_temp.p1_factura(-1601242, 500.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T24A', -1601241, 100000);
    perform pg_temp.p1_pagar('pi_P1T24B', -1601242, 50000, 'ach');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T24A', 'succeeded', 100000)
                                       || jsonb_build_object('reembolsos', jsonb_build_array(pg_temp.p1_reembolso('re_P1T24', 10000, 'txn_R_P1T24'))),
                                       'evt_P1T24R');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T24', 'paid', 136570), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T24A', 'charge', 100000, 2930, 'pi_P1T24A', 'ch_P1T24A'),
             pg_temp.p1_linea('txn_pi_P1T24B', 'payment', 50000, 400, 'pi_P1T24B', 'py_P1T24B'),
             pg_temp.p1_linea('txn_R_P1T24', 'refund', -10000, 0, 'pi_P1T24A', 're_P1T24'),
             pg_temp.p1_linea('txn_F_P1T24', 'stripe_fee', -100),
             pg_temp.p1_propio('po_P1T24', 136570)), 'evt_P1T24P');
    select * into p from stripe_payouts where po = 'po_P1T24';
    select * into a1 from asientos where id = p.asiento_salida;
    select * into a2 from asientos where id = p.asiento_llegada;
    v_n := (select count(*) from asientos);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T24', 'paid', 136570), null, 'evt_P1T24Q');
    v_obt := format('%s | P1 %s | P2 %s | %s %s/%s, origen %s, documento %s, %s | procedencia %s | la puente +%s, la de paso %s | papel %s | pagos %s | otra vez: %s asientos nuevos',
                    v_r->>'estado', pg_temp.p1_lineas(a1.id), pg_temp.p1_lineas(a2.id), a1.camino, a2.camino,
                    case when a1.fecha_contable = a2.fecha_contable and a1.fecha_contable = pg_temp.p1('llegada')::date then 'misma fecha, la llegada'
                         else 'MAL ' || a1.fecha_contable || ' ' || a2.fecha_contable end,
                    coalesce(a1.origen_tabla, a2.origen_tabla, 'ninguno'), coalesce(a1.documento_ruta, a2.documento_ruta, 'ninguno'),
                    case when a1.usuario_id = pg_temp.p1('dueno')::uuid and a2.usuario_id = pg_temp.p1('dueno')::uuid then 'del dueño' else 'MAL' end,
                    case when a1.procedencia ?& array['funcion', 'paso', 'payout', 'evento', 'fecha_documento', 'pagos']
                              and a2.procedencia ?& array['funcion', 'paso', 'payout', 'fecha_documento']
                              and a1.procedencia->>'payout' = 'po_P1T24' and jsonb_array_length(a1.procedencia->'pagos') = 2
                         then 'bien' else 'MAL ' || a1.procedencia::text end,
                    pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0, pg_temp.p1_saldo(pg_temp.p1('paso')),
                    (select string_agg(x.papel_existe::text, '/' order by x.numero) from v_asiento_papel x where x.asiento_id in (a1.id, a2.id)),
                    (select string_agg(v.estado_pantalla, '/' order by v.pi) from v_stripe_pagos v where v.pi in ('pi_P1T24A', 'pi_P1T24B')),
                    (select count(*) from asientos) - v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'el depósito: P1 y P2 a mano, sin origen, la misma fecha, la puente y la de paso en cero',
    format('asentado | P1 %2$s 1365.70 | %3$s 34.30 | %1$s -1400.00 | P2 %4$s 1365.70 | %2$s -1365.70 | mano mano/misma fecha, la llegada, origen ninguno, documento ninguno, del dueño | procedencia bien | la puente +0.00, la de paso 0.00 | papel true/true | pagos en_payout/en_payout | otra vez: 0 asientos nuevos',
           pg_temp.p1('puente'), pg_temp.p1('paso'), pg_temp.p1('comisiones'), pg_temp.p1('banco')), v_obt,
    v_obt = format('asentado | P1 %2$s 1365.70 | %3$s 34.30 | %1$s -1400.00 | P2 %4$s 1365.70 | %2$s -1365.70 | mano mano/misma fecha, la llegada, origen ninguno, documento ninguno, del dueño | procedencia bien | la puente +0.00, la de paso 0.00 | papel true/true | pagos en_payout/en_payout | otra vez: 0 asientos nuevos',
                   pg_temp.p1('puente'), pg_temp.p1('paso'), pg_temp.p1('comisiones'), pg_temp.p1('banco')));
end $$;

-- 25. Un depósito que no suma su neto: por revisar, sin asiento, aviso; uno
--     que trae un movimiento de otro depósito: por revisar
do $$
declare
  v_obt text; v_r jsonb; v_a text; v_b text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T25A', 'paid', 10000),
                                        jsonb_build_array(pg_temp.p1_linea('txn_O_P1T25A', 'adjustment', 9000)), 'evt_P1T25A');
    v_a := format('%s, %s asiento(s), aviso %s', v_r->>'estado',
                  (select count(*) from stripe_payouts p where p.po = 'po_P1T25A' and p.asiento_salida is not null),
                  (select a.nivel from stripe_avisos a where a.clave = 'payout:po_P1T25A:cuadre'));
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T25B', 'paid', 5000),
                                         jsonb_build_array(pg_temp.p1_linea('txn_O_P1T25B', 'reserve_transaction', 5000)), 'evt_P1T25B');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T25C', 'paid', 5000),
                                        jsonb_build_array(pg_temp.p1_linea('txn_O_P1T25B', 'reserve_transaction', 5000)), 'evt_P1T25C');
    v_b := format('%s: %s', v_r->>'estado', case when (select p.revisar from stripe_payouts p where p.po = 'po_P1T25C') like '%ya son de otro depósito%'
                                                 then 'ya son de otro depósito' else 'MAL' end);
    v_obt := v_a || ' | ' || v_b;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'un depósito que no cuadra, o que trae lo de otro: por revisar, sin asiento',
    'revisar, 0 asiento(s), aviso bad | revisar: ya son de otro depósito', v_obt, v_obt = 'revisar, 0 asiento(s), aviso bad | revisar: ya son de otro depósito');
end $$;

-- 26. Un depósito que trae un pago que p1 no tiene espera (sin asiento) y se
--     asienta al llegar el pago; uno que trae un reembolso que el pago no
--     conoce, espera
do $$
declare
  v_obt text; v_r jsonb; v_a text; v_b text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601261, 500.00);
    perform pg_temp.p1_factura(-1601262, 500.00);
    perform pg_temp.p1_enlace(-1601261, 'plink_P1T26A');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T26A', 'paid', 48520), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T26A', 'charge', 50000, 1480, 'pi_P1T26A'), pg_temp.p1_propio('po_P1T26A', 48520)), 'evt_P1T26A');
    v_a := format('%s %s, %s asiento(s)', v_r->>'estado', v_r->'esperando'->0->>'pi',
                  (select count(*) from stripe_payouts p where p.po = 'po_P1T26A' and p.asiento_salida is not null));
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T26A', 'succeeded', 50000), 'evt_P1T26B');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T26A', 'paid', 48520), null, 'evt_P1T26C');
    v_a := v_a || ' → ' || (v_r->>'estado');
    perform pg_temp.p1_pagar('pi_P1T26B', -1601262, 50000);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T26B', 'paid', 43520), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T26B', 'charge', 50000, 1480, 'pi_P1T26B'),
             pg_temp.p1_linea('txn_R_P1T26B', 'refund', -5000, 0, 'pi_P1T26B')), 'evt_P1T26D');
    v_b := format('%s: %s', v_r->>'estado', v_r->'esperando'->0->>'motivo');
    v_obt := v_a || ' | ' || v_b;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'el depósito espera al pago que falta, y al reembolso que el pago no conoce',
    'esperando_cobros pi_P1T26A, 0 asiento(s) → asentado | esperando_cobros: la composición trae un movimiento que el pago no conoce', v_obt,
    v_obt = 'esperando_cobros pi_P1T26A, 0 asiento(s) → asentado | esperando_cobros: la composición trae un movimiento que el pago no conoce');
end $$;

-- 27. Sin la composición todavía: espera; con ella, se asienta. Un depósito
--     manual, instantáneo o en otra moneda: por revisar
do $$
declare
  v_obt text; v_r jsonb; v_a text; v_b text[] := '{}';
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601271, 500.00);
    perform pg_temp.p1_pagar('pi_P1T27', -1601271, 50000);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T27A', 'paid', 48520, jsonb_build_object('conciliacion', 'in_progress')),
                                        null, 'evt_P1T27A');
    v_a := v_r->>'estado';
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T27A', 'paid', 48520), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T27', 'charge', 50000, 1480, 'pi_P1T27'), pg_temp.p1_propio('po_P1T27A', 48520)), 'evt_P1T27B');
    v_a := v_a || ' → ' || (v_r->>'estado');
    v_b := v_b || (fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T27B', 'paid', 1000, jsonb_build_object('automatico', false)),
                                                null, 'evt_P1T27C')->>'estado');
    v_b := v_b || (fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T27C', 'paid', 1000, jsonb_build_object('metodo', 'instant')),
                                                null, 'evt_P1T27D')->>'estado');
    v_b := v_b || (fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T27D', 'paid', 1000, jsonb_build_object('moneda', 'eur')),
                                                null, 'evt_P1T27E')->>'estado');
    v_obt := format('%s | manual, instantáneo, eur: %s | aviso «automático» %s', v_a, array_to_string(v_b, ' '),
                    (select count(*) from stripe_avisos a where a.clave like 'payout:po_P1T27_:revisar' and a.texto like '%deja los payouts en automático%'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'sin composición espera; manual, instantáneo o en otra moneda, por revisar',
    'esperando_composicion → asentado | manual, instantáneo, eur: revisar revisar revisar | aviso «automático» 3', v_obt,
    v_obt = 'esperando_composicion → asentado | manual, instantáneo, eur: revisar revisar revisar | aviso «automático» 3');
end $$;

-- 28. Un movimiento que la app no conoce (una reserva): por revisar con «a
--     qué cuenta va»; Edgar dice la cuenta (un gasto) y el depósito se
--     asienta con esa línea; a un banco, MX004
do $$
declare
  v_obt text; v_r jsonb; v_a text; v_b text; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T28', 'paid', 5000), jsonb_build_array(
             pg_temp.p1_linea('txn_O_P1T28', 'reserve_transaction', 5000), pg_temp.p1_propio('po_P1T28', 5000)), 'evt_P1T28A');
    v_a := format('%s: %s, aviso %s', v_r->>'estado', v_r->'esperando'->0->>'motivo',
                  (select a.nivel from stripe_avisos a where a.clave = 'payout:po_P1T28:otro:txn_O_P1T28'));
    begin
      perform fn_stripe_payout_linea_resolver('po_P1T28', 'txn_O_P1T28', pg_temp.p1('banco'), 'p1-pruebas', pg_temp.p1('dueno')::uuid);
      v_e := 'entró';
    exception when others then v_e := sqlstate; end;
    perform fn_stripe_payout_linea_resolver('po_P1T28', 'txn_O_P1T28', pg_temp.p1('gasto'), 'p1-pruebas: reserva que Stripe soltó',
                                            pg_temp.p1('dueno')::uuid);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T28', 'paid', 5000), null, 'evt_P1T28B');
    v_b := format('%s, P1 %s', v_r->>'estado',
                  pg_temp.p1_lineas((select p.asiento_salida from stripe_payouts p where p.po = 'po_P1T28')));
    v_obt := format('%s | a un banco: %s | %s', v_a, v_e, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'lo que la app no conoce: por revisar, Edgar dice la cuenta y se asienta',
    format('revisar: a qué cuenta va, aviso bad | a un banco: MX004 | asentado, P1 %s 50.00 | %s -50.00', pg_temp.p1('paso'), pg_temp.p1('gasto')),
    v_obt, v_obt = format('revisar: a qué cuenta va, aviso bad | a un banco: MX004 | asentado, P1 %s 50.00 | %s -50.00', pg_temp.p1('paso'), pg_temp.p1('gasto')));
end $$;

-- 29. EL CASADO SOLO: con P2 asentado, el depósito STRIPE que trae Plaid por
--     el neto casa con la línea de 1010 de P2 por R1 de c6, sin motivo; el
--     cuadre 59 de c6 en verde; el depósito «casado» y el pago «depositado»
do $$
declare
  v_obt text; v_mov uuid; m movimientos_banco; bc banco_casados; v_l text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601291, 1000.00);
    perform pg_temp.p1_pagar('pi_P1T29', -1601291, 100000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T29', 'paid', 97070), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T29', 'charge', 100000, 2930, 'pi_P1T29'), pg_temp.p1_propio('po_P1T29', 97070)), 'evt_P1T29');
    v_mov := pg_temp.p1_deposito('p1t29-po', pg_temp.p1('llegada')::date, 970.70);
    perform pg_temp.p1_casar_todo();
    select * into m from movimientos_banco where id = v_mov;
    select * into bc from banco_casados where id = m.casado_id;
    select case when exists (select 1 from banco_casado_lineas l join stripe_payouts p on p.asiento_llegada = l.asiento_id
                              where l.casado_id = bc.id and l.vigente and p.po = 'po_P1T29') then 'con la línea de P2' else 'MAL' end into v_l;
    v_obt := format('%s %s: %s, automático %s, motivo %s | cuadre 59 %s | %s / %s',
                    m.estado, v_l, bc.regla, bc.automatico::text, coalesce(bc.motivo, 'ninguno'),
                    (select case when x.ok then 'verde' else 'rojo' end from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) x
                      where x.vista = 'cuadre: el otro lado de cada casado'),
                    (select v.estado_pantalla from v_stripe_payouts v where v.po = 'po_P1T29'),
                    (select v.estado_pantalla from v_stripe_pagos v where v.pi = 'pi_P1T29'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'el depósito de Chase casa SOLO con P2 (R1 de c6, sin motivo)',
    'casado con la línea de P2: R1 cruce exacto con el libro (mismo monto, en su ventana), automático true, motivo ninguno | cuadre 59 verde | casado / depositado',
    v_obt, v_obt = 'casado con la línea de P2: R1 cruce exacto con el libro (mismo monto, en su ventana), automático true, motivo ninguno | cuadre 59 verde | casado / depositado');
end $$;

-- 30. La contraprueba: con UN asiento (Dr 1010 + Dr 6130 / Cr 1020) en vez de
--     P1 y P2, el mismo depósito no casa solo, y casarlo sin motivo da MX008
--     (EL CRITERIO de c6: el libro dice «cuenta propia», el banco «STRIPE»)
do $$
declare
  v_obt text; v_mov uuid; v_a jsonb; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601301, 1000.00);
    perform pg_temp.p1_pagar('pi_P1T30', -1601301, 100000);
    perform pg_temp.p1_ser('como_dueno');
    v_a := fn_postear(jsonb_build_object(
             'fecha', pg_temp.p1('llegada'), 'descripcion', 'p1-pruebas: el depósito en un solo asiento (se deshace)',
             'lineas', jsonb_build_array(jsonb_build_object('cuenta', pg_temp.p1('banco'), 'monto', '970.70'),
                                         jsonb_build_object('cuenta', pg_temp.p1('comisiones'), 'monto', '29.30'),
                                         jsonb_build_object('cuenta', pg_temp.p1('puente'), 'monto', '-1000.00'))));
    perform pg_temp.p1_ser('servicio');
    v_mov := pg_temp.p1_deposito('p1t30-po', pg_temp.p1('llegada')::date, 970.70);
    perform pg_temp.p1_casar_todo();
    perform pg_temp.p1_ser('como_dueno');
    begin
      perform fn_banco_casar_con(v_mov, jsonb_build_object('asiento', v_a->>'id'), null);
      v_e := 'entró';
    exception when others then
      v_e := sqlstate || case when sqlerrm like '%sin su motivo%' then ' «sin su motivo»' else ' ' || sqlerrm end;
    end;
    perform pg_temp.p1_ser('servicio');
    v_obt := format('solo: %s | sin motivo: %s', (select m.estado from movimientos_banco m where m.id = v_mov), v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'contraprueba: un solo asiento con la puente enfrente no casa solo y pide motivo',
    'solo: pendiente | sin motivo: MX008 «sin su motivo»', v_obt, v_obt = 'solo: pendiente | sin motivo: MX008 «sin su motivo»');
end $$;

-- 31. El depósito de Chase llega ANTES que el asiento: la fecha del depósito
--     (si es antes de la llegada) es la del documento y la de P1 y P2 (o, si
--     el libro no la deja —una conciliación confirmada o un mes cerrado—, el
--     primer día que deja), y casar (otra llamada) lo casa por R1. Con dos
--     movimientos iguales en la ventana no casa solo; Edgar elige uno y casa
--     con su motivo.
do $$
declare
  v_obt text; v_a text; v_b text; v_mov uuid; v_mov2 uuid; v_r jsonb; v_d date; v_esp date;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601311, 1000.00);
    perform pg_temp.p1_pagar('pi_P1T31', -1601311, 100000);
    v_d := pg_temp.p1('llegada')::date - 1;
    v_esp := (fn_puente_fecha(greatest(v_d, coalesce((select max(c.fecha_corte) + 1 from conciliaciones c
                                                       where c.cuenta = pg_temp.p1('banco') and c.estado = 'confirmada'
                                                         and c.tipo = 'normal'), v_d)))->>'fecha')::date;
    v_mov := pg_temp.p1_deposito('p1t31-po', v_d, 970.70);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T31', 'paid', 97070), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T31', 'charge', 100000, 2930, 'pi_P1T31'), pg_temp.p1_propio('po_P1T31', 97070)), 'evt_P1T31');
    v_r := fn_stripe_payout_casar('po_P1T31');
    v_a := format('fecha %s, documento %s | casado %s, %s',
                  case when (select p.fecha_asiento from stripe_payouts p where p.po = 'po_P1T31') = v_esp
                       then case when v_esp = v_d then 'la del depósito' else 'la que deja el libro' end else 'MAL' end,
                  case when (select p.fecha_documento from stripe_payouts p where p.po = 'po_P1T31') = v_d then 'la del depósito' else 'MAL' end,
                  v_r->>'casado', v_r->>'regla');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601312, 2000.00);
    perform pg_temp.p1_pagar('pi_P1T31B', -1601312, 200000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T31B', 'paid', 194170), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T31B', 'charge', 200000, 5830, 'pi_P1T31B'), pg_temp.p1_propio('po_P1T31B', 194170)), 'evt_P1T31B');
    v_mov := pg_temp.p1_deposito('p1t31-b1', pg_temp.p1('llegada')::date, 1941.70);
    v_mov2 := pg_temp.p1_deposito('p1t31-b2', pg_temp.p1('llegada')::date + 1, 1941.70);
    perform pg_temp.p1_casar_todo();
    v_r := fn_stripe_payout_casar('po_P1T31B');
    v_b := format('dos iguales: casado %s (%s candidatos)', v_r->>'casado', v_r->>'candidatos');
    v_r := fn_stripe_payout_casar('po_P1T31B', v_mov);
    v_b := v_b || format(' → elegido: casado %s, automático %s, motivo %s', v_r->>'casado', v_r->>'automatico',
                         case when (select bc.motivo from movimientos_banco m join banco_casados bc on bc.id = m.casado_id where m.id = v_mov)
                                   like 'Stripe p1: depósito po_P1T31B%' then 'Stripe p1: …' else 'MAL' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_b := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  v_obt := v_a || ' | ' || v_b;
  insert into _pruebas values (31, 'el depósito antes que el asiento: su fecha, y casar después; dos iguales, Edgar elige',
    'fecha la del depósito, documento la del depósito | casado true, R1 cruce exacto con el libro (mismo monto, en su ventana) | dos iguales: casado false (2 candidatos) → elegido: casado true, automático false, motivo Stripe p1: …',
    v_obt, v_obt in ('fecha la del depósito, documento la del depósito | casado true, R1 cruce exacto con el libro (mismo monto, en su ventana) | dos iguales: casado false (2 candidatos) → elegido: casado true, automático false, motivo Stripe p1: …',
                     'fecha la que deja el libro, documento la del depósito | casado true, R1 cruce exacto con el libro (mismo monto, en su ventana) | dos iguales: casado false (2 candidatos) → elegido: casado true, automático false, motivo Stripe p1: …'));
end $$;

-- 32. Con una conciliación confirmada del banco que cubre la llegada: P1 y P2
--     al día siguiente de su corte (con la fecha del documento = la
--     llegada), «conciliaciones confirmadas» de c6 en verde y R1 casa por la
--     fecha del documento. (Si en esta base no se puede confirmar una
--     conciliación de prueba —producción, con el banco en uso—, omitida.)
do $$
declare
  v_obt text; v_corte date; v_saldo numeric; v_c jsonb; v_omit text; p stripe_payouts; v_mov uuid; v_cas text; v_54 text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    v_corte := pg_temp.p1('llegada')::date - 1;
    select coalesce(sum(l.monto), 0)::numeric(14,2) into v_saldo
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = pg_temp.p1('banco') and a.fecha_contable <= v_corte;
    begin
      perform pg_temp.p1_ser('como_dueno');
      v_c := fn_conciliar(pg_temp.p1('banco'), v_corte, v_saldo::text);
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      perform pg_temp.p1_ser('servicio');
    exception when others then
      v_omit := format('omitida: no se pudo confirmar una conciliación de prueba de %s al %s (%s)', pg_temp.p1('banco'), v_corte, sqlerrm);
    end;
    if v_omit is null then
      perform pg_temp.p1_factura(-1601321, 1000.00, 0, v_corte - 1);
      perform pg_temp.p1_pagar('pi_P1T32', -1601321, 100000);
      perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T32', 'paid', 97070, jsonb_build_object('llegada', v_corte::text)),
                                           jsonb_build_array(pg_temp.p1_linea('txn_pi_P1T32', 'charge', 100000, 2930, 'pi_P1T32'),
                                                             pg_temp.p1_propio('po_P1T32', 97070)), 'evt_P1T32');
      select * into p from stripe_payouts where po = 'po_P1T32';
      v_mov := pg_temp.p1_deposito('p1t32-po', v_corte + 1, 970.70);
      perform pg_temp.p1_casar_todo();
      select coalesce((select bc.regla from movimientos_banco m join banco_casados bc on bc.id = m.casado_id where m.id = v_mov), 'sin casar')
        into v_cas;
      select case when x.ok then 'verde' else 'rojo: ' || x.detalle end into v_54
        from fn_banco_control('hoy', array['cuadre: conciliaciones confirmadas']) x where x.vista = 'cuadre: conciliaciones confirmadas';
      v_obt := format('P1 y P2 %s, documento %s | conciliaciones confirmadas %s | %s',
                      case when p.fecha_asiento = v_corte + 1 then 'el día siguiente al corte' else 'MAL ' || p.fecha_asiento end,
                      case when p.fecha_documento = v_corte then 'la llegada' else 'MAL ' || p.fecha_documento end, v_54, v_cas);
    else
      v_obt := v_omit;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'con la conciliación del banco confirmada: P1 y P2 después de su corte; R1 casa por la fecha del documento',
    'P1 y P2 el día siguiente al corte, documento la llegada | conciliaciones confirmadas verde | R1 cruce exacto con el libro (mismo monto, en su ventana)',
    v_obt, case when v_obt like 'omitida%' then null
                else v_obt = 'P1 y P2 el día siguiente al corte, documento la llegada | conciliaciones confirmadas verde | R1 cruce exacto con el libro (mismo monto, en su ventana)' end);
end $$;

-- 33. El depósito falla DESPUÉS de pagado (sin casar): P2 se reversa, P3 lo
--     devuelve a la puente, la de paso en cero, aviso; el siguiente con su
--     «payout_failure» lo liquida. Ya casado con Chase: por revisar sin
--     tocar nada. Con P2 dentro de una conciliación confirmada: por revisar
--     («reabre la conciliación»; omitida si no se puede montar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_p0 numeric; v_r jsonb; p stripe_payouts; v_mov uuid; v_cc jsonb; v_n bigint;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601331, 1000.00);
    perform pg_temp.p1_factura(-1601332, 1000.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T33', -1601331, 100000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33', 'paid', 97070), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T33', 'charge', 100000, 2930, 'pi_P1T33'), pg_temp.p1_propio('po_P1T33', 97070)), 'evt_P1T33A');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33', 'failed', 97070, jsonb_build_object('fallo_codigo', 'account_closed',
                                                                                                         'bt_fallo', 'txn_PF_P1T33')),
                                        null, 'evt_P1T33B');
    select * into p from stripe_payouts where po = 'po_P1T33';
    v_a := format('%s: P2 reversado %s, P3 %s | la puente +%s, la de paso %s | aviso %s', v_r->>'estado',
                  case when p.reverso_llegada is not null then 'sí' else 'NO' end, pg_temp.p1_lineas(p.asiento_vuelta),
                  pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0, pg_temp.p1_saldo(pg_temp.p1('paso')),
                  (select a.nivel from stripe_avisos a where a.clave = 'payout:po_P1T33:fallido'));
    -- el siguiente lo trae de vuelta (con un cobro nuevo)
    perform pg_temp.p1_pagar('pi_P1T33B', -1601332, 100000);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33B', 'paid', 194140), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T33B', 'charge', 100000, 2930, 'pi_P1T33B'),
             pg_temp.p1_linea('txn_PF_P1T33', 'payout_failure', 97070, 0, null, 'po_P1T33'),
             pg_temp.p1_propio('po_P1T33B', 194140)), 'evt_P1T33C');
    v_a := v_a || format(' → el siguiente %s, la puente +%s', v_r->>'estado', pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  -- ya casado con Chase
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601333, 1000.00);
    perform pg_temp.p1_pagar('pi_P1T33C', -1601333, 100000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33C', 'paid', 97070), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T33C', 'charge', 100000, 2930, 'pi_P1T33C'), pg_temp.p1_propio('po_P1T33C', 97070)), 'evt_P1T33D');
    v_mov := pg_temp.p1_deposito('p1t33-c', pg_temp.p1('llegada')::date, 970.70);
    perform fn_stripe_payout_casar('po_P1T33C');
    v_n := (select count(*) from asientos);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33C', 'failed', 97070, jsonb_build_object('fallo_codigo', 'account_closed')),
                                        null, 'evt_P1T33E');
    v_b := format('%s, %s asientos nuevos', v_r->>'estado', (select count(*) from asientos) - v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_b := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  -- P2 dentro de una conciliación confirmada
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601334, 1000.00, 0, pg_temp.p1('llegada')::date - 2);
    perform pg_temp.p1_pagar('pi_P1T33D', -1601334, 100000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33D', 'paid', 97070,
                                                           jsonb_build_object('llegada', (pg_temp.p1('llegada')::date - 1)::text)),
                                         jsonb_build_array(pg_temp.p1_linea('txn_pi_P1T33D', 'charge', 100000, 2930, 'pi_P1T33D'),
                                                           pg_temp.p1_propio('po_P1T33D', 97070)), 'evt_P1T33F');
    begin
      perform pg_temp.p1_ser('como_dueno');
      v_cc := fn_conciliar(pg_temp.p1('banco'), pg_temp.p1('llegada')::date - 1,
                           (select coalesce(sum(l.monto), 0)::numeric(14,2) - 970.70 from asiento_lineas l join asientos a on a.id = l.asiento_id
                             where l.cuenta = pg_temp.p1('banco') and a.fecha_contable <= pg_temp.p1('llegada')::date - 1)::text);
      perform fn_conciliacion_confirmar((v_cc->>'conciliacion')::uuid);
      perform pg_temp.p1_ser('servicio');
      v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T33D', 'failed', 97070, jsonb_build_object('fallo_codigo', 'account_closed',
                                                                    'llegada', (pg_temp.p1('llegada')::date - 1)::text)), null, 'evt_P1T33G');
      v_c := format('%s: %s', v_r->>'estado',
                    case when (select a.texto from stripe_avisos a where a.clave = 'payout:po_P1T33D:fallo_conciliado') like 'Reabre la conciliación%'
                         then 'reabre la conciliación' else 'MAL' end);
    exception when others then
      v_c := 'omitida (' || sqlstate || ': ' || left(sqlerrm, 120) || ')';
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_c := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  v_obt := v_a || ' | ya casado: ' || v_b || ' | conciliado: ' || v_c;
  insert into _pruebas values (33, 'el depósito falla después de pagado: P2 reversado y P3; el siguiente lo liquida; casado o conciliado, por revisar',
    format('fallido: P2 reversado sí, P3 %s 970.70 | %s -970.70 | la puente +970.70, la de paso 0.00 | aviso bad → el siguiente asentado, la puente +0.00 | ya casado: revisar, 0 asientos nuevos | conciliado: revisar: reabre la conciliación',
           pg_temp.p1('puente'), pg_temp.p1('paso')), v_obt,
    case when v_c like 'omitida%' then null
         else v_obt = format('fallido: P2 reversado sí, P3 %s 970.70 | %s -970.70 | la puente +970.70, la de paso 0.00 | aviso bad → el siguiente asentado, la puente +0.00 | ya casado: revisar, 0 asientos nuevos | conciliado: revisar: reabre la conciliación',
                             pg_temp.p1('puente'), pg_temp.p1('paso')) end);
end $$;

-- 34. El depósito falla ANTES de pagarse: P1 y P3 (sin P2), la de paso en
--     cero, y el siguiente lo liquida. Un ACH que falla dentro de un
--     depósito (payment + payment_failure_refund): cero en la puente y sus
--     4.00 a 6130.
do $$
declare
  v_obt text; v_a text; v_b text; v_p0 numeric; v_r jsonb; p stripe_payouts; v_c0 numeric;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601341, 1000.00);
    perform pg_temp.p1_factura(-1601342, 1000.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    perform pg_temp.p1_pagar('pi_P1T34', -1601341, 100000);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T34', 'failed', 97070, jsonb_build_object('fallo_codigo', 'no_account')),
                                        jsonb_build_array(pg_temp.p1_linea('txn_pi_P1T34', 'charge', 100000, 2930, 'pi_P1T34'),
                                                          pg_temp.p1_propio('po_P1T34', 97070)), 'evt_P1T34A');
    select * into p from stripe_payouts where po = 'po_P1T34';
    v_a := format('%s: P1 %s, P2 %s, P3 %s | la de paso %s', v_r->>'estado', case when p.asiento_salida is not null then 'sí' else 'NO' end,
                  case when p.asiento_llegada is not null then 'SÍ' else 'no' end, case when p.asiento_vuelta is not null then 'sí' else 'NO' end,
                  pg_temp.p1_saldo(pg_temp.p1('paso')));
    perform pg_temp.p1_pagar('pi_P1T34B', -1601342, 100000);
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T34B', 'paid', 194140), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T34B', 'charge', 100000, 2930, 'pi_P1T34B'),
             pg_temp.p1_linea('txn_PF_P1T34', 'payout_failure', 97070, 0, null, 'po_P1T34'),
             pg_temp.p1_propio('po_P1T34B', 194140)), 'evt_P1T34B');
    v_a := v_a || format(' → el siguiente %s, la puente +%s', v_r->>'estado', pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601343, 1000.00);
    perform pg_temp.p1_factura(-1601344, 500.00);
    v_p0 := pg_temp.p1_saldo(pg_temp.p1('puente'));
    v_c0 := pg_temp.p1_saldo(pg_temp.p1('comisiones'));
    perform pg_temp.p1_pagar('pi_P1T34C', -1601343, 100000);
    perform pg_temp.p1_enlace(-1601344, 'plink_P1T34D');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T34D', 'processing', 50000, null, 'ach'), 'evt_P1T34C');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T34D', 'requires_payment_method', 50000, null, 'ach')
                                       || jsonb_build_object('cargos', jsonb_build_array(pg_temp.p1_cargo('pi_P1T34D', 'failed', 50000, 'ach', 'txn_PFR_P1T34D')),
                                                             'ultimo_error', jsonb_build_object('codigo', 'insufficient_funds', 'mensaje', 'fondos insuficientes')),
                                       'evt_P1T34D');
    v_r := fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T34C', 'paid', 96670), jsonb_build_array(
             pg_temp.p1_linea('txn_pi_P1T34C', 'charge', 100000, 2930, 'pi_P1T34C'),
             pg_temp.p1_linea('txn_pi_P1T34D', 'payment', 50000, 0, 'pi_P1T34D'),
             pg_temp.p1_linea('txn_PFR_P1T34D', 'payment_failure_refund', -50000, 400, 'pi_P1T34D'),
             pg_temp.p1_propio('po_P1T34C', 96670)), 'evt_P1T34E');
    v_b := format('%s, la puente +%s, a comisiones +%s', v_r->>'estado', pg_temp.p1_saldo(pg_temp.p1('puente')) - v_p0,
                  pg_temp.p1_saldo(pg_temp.p1('comisiones')) - v_c0);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_b := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  v_obt := v_a || ' | ACH fallido en el depósito: ' || v_b;
  insert into _pruebas values (34, 'el depósito falla antes de pagarse (P1 y P3); un ACH fallido dentro de un depósito',
    'fallido: P1 sí, P2 no, P3 sí | la de paso 0.00 → el siguiente asentado, la puente +0.00 | ACH fallido en el depósito: asentado, la puente +0.00, a comisiones +33.30',
    v_obt, v_obt = 'fallido: P1 sí, P2 no, P3 sí | la de paso 0.00 → el siguiente asentado, la puente +0.00 | ACH fallido en el depósito: asentado, la puente +0.00, a comisiones +33.30');
end $$;

-- 35. El dueño reversa P2 a mano: el cuadre 25 en rojo; sincronizar no lo
--     toca; rehacer lo vuelve a poner y el control queda en verde
do $$
declare
  v_obt text; p stripe_payouts; v_a text; v_b text; v_c text; v_e text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601351, 1000.00);
    perform pg_temp.p1_pagar('pi_P1T35', -1601351, 100000);
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T35', 'paid', 97070), jsonb_build_array(
              pg_temp.p1_linea('txn_pi_P1T35', 'charge', 100000, 2930, 'pi_P1T35'), pg_temp.p1_propio('po_P1T35', 97070)), 'evt_P1T35A');
    select * into p from stripe_payouts where po = 'po_P1T35';
    perform pg_temp.p1_ser('dueno');
    perform fn_reversar(p.asiento_llegada, 'p1-pruebas: a mano (se deshace)');
    perform pg_temp.p1_ser('servicio');
    v_a := format('25 %s, 23 %s', pg_temp.p1_fila(25), pg_temp.p1_fila(23));
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T35', 'paid', 97070), null, 'evt_P1T35B');
    v_b := format('%s, 25 %s', (select x.estado from stripe_payouts x where x.po = 'po_P1T35'), pg_temp.p1_fila(25));
    begin
      perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T35X', 'paid', 100), null, 'evt_P1T35X', true);
      v_e := 'entró';
    exception when others then v_e := sqlstate; end;
    perform fn_stripe_payout_sincronizar(pg_temp.p1_payout('po_P1T35', 'paid', 97070), null, 'evt_P1T35C', true);
    select * into p from stripe_payouts where po = 'po_P1T35';
    v_c := format('%s, rehechos %s, 25 %s, 23 %s', p.estado, jsonb_array_length(p.rehechos), pg_temp.p1_fila(25), pg_temp.p1_fila(23));
    v_obt := format('reversado: %s | sin rehacer: %s | rehacer sin nada: %s | rehecho: %s', v_a, v_b, v_e, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'P2 reversado a mano: el cuadre 25 en rojo hasta rehacerlo',
    'reversado: 25 rojo, 23 rojo | sin rehacer: asentado, 25 rojo | rehacer sin nada: MX008 | rehecho: asentado, rehechos 1, 25 verde, 23 verde', v_obt,
    v_obt = 'reversado: 25 rojo, 23 rojo | sin rehacer: asentado, 25 rojo | rehacer sin nada: MX008 | rehecho: asentado, rehechos 1, 25 verde, 23 verde');
end $$;

-- 36. Algo ajeno toca lo de Stripe y el control lo dice: un asiento a mano a
--     la puente (20 y 21), un cobro de Stripe anulado a mano (21 y 28), Plaid
--     trae la puente (33), alguien concilia la puente (37), un depósito
--     STRIPE casado a mano con otra cosa (27) y la de paso desactivada (36)
do $$
declare
  v_obt text; v_r text[] := '{}'; v_antes text; v_mov uuid; v_a jsonb; v_i int;
begin
  for v_i in 1 .. 6 loop
    begin
      perform pg_temp.p1_ser('servicio');
      perform pg_temp.p1_montar();
      v_antes := pg_temp.p1_rojos('cuadre');
      if v_i = 1 then
        perform fn_postear(jsonb_build_object('fecha', pg_temp.p1('hoy'), 'descripcion', 'p1-pruebas: ajeno a la puente (se deshace)',
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', pg_temp.p1('puente'), 'monto', '100.00'),
                                      jsonb_build_object('cuenta', pg_temp.p1('capital'), 'monto', '-100.00'))));
      elsif v_i = 2 then
        perform pg_temp.p1_factura(-1601361, 1000.00);
        perform pg_temp.p1_pagar('pi_P1T36', -1601361, 100000);
        perform fn_cobro_anular((select s.cobro_id from stripe_pagos s where s.pi = 'pi_P1T36'), 'p1-pruebas: a mano');
      elsif v_i = 3 then
        insert into plaid_conexiones (item_id, institucion, estado, cuentas, creado_por)
        values ('item-p1-pruebas', 'Banco de prueba p1', 'activa',
                jsonb_build_array(jsonb_build_object('account_id', 'acc-p1', 'mask', '0000', 'tipo', 'depository', 'cuenta', pg_temp.p1('puente'))),
                pg_temp.p1('dueno')::uuid);
      elsif v_i = 4 then
        perform pg_temp.p1_ser('como_dueno');
        perform fn_conciliar(pg_temp.p1('puente'), pg_temp.p1('hoy')::date, '0.00');
        perform pg_temp.p1_ser('servicio');
      elsif v_i = 5 then
        v_mov := pg_temp.p1_deposito('p1t36-ajeno', pg_temp.p1('llegada')::date, 123.45);
        perform pg_temp.p1_ser('como_dueno');
        v_a := fn_postear(jsonb_build_object('fecha', pg_temp.p1('llegada'), 'descripcion', 'p1-pruebas: otro ingreso (se deshace)',
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', pg_temp.p1('banco'), 'monto', '123.45'),
                                      jsonb_build_object('cuenta', pg_temp.p1('ingreso'), 'monto', '-123.45'))));
        perform fn_banco_casar_con(v_mov, jsonb_build_object('asiento', v_a->>'id'), 'p1-pruebas: lo resolví a mano');
        perform pg_temp.p1_ser('servicio');
      else
        update cuentas set activa = false where codigo = pg_temp.p1('paso');
      end if;
      v_r := v_r || pg_temp.p1_nuevos(v_antes, pg_temp.p1_rojos('cuadre'));
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_r := v_r || ('error ' || sqlstate || ': ' || sqlerrm);
    end;
  end loop;
  v_obt := format('a mano a la puente: %s | cobro anulado: %s | Plaid trae la puente: %s | conciliar la puente: %s | STRIPE casado con otra cosa: %s | la de paso desactivada: %s',
                  v_r[1], v_r[2], v_r[3], v_r[4], v_r[5], v_r[6]);
  insert into _pruebas values (36, 'lo ajeno pone en rojo su cuadre de p1',
    'a mano a la puente: 20 21 | cobro anulado: 21 28 | Plaid trae la puente: 33 | conciliar la puente: 37 | STRIPE casado con otra cosa: 27 | la de paso desactivada: 36', v_obt,
    v_obt = 'a mano a la puente: 20 21 | cobro anulado: 21 28 | Plaid trae la puente: 33 | conciliar la puente: 37 | STRIPE casado con otra cosa: 27 | la de paso desactivada: 36');
end $$;

-- 37. Las alarmas (amarillas: ningún cuadre en rojo): un aviso sin procesar
--     de hace 20 minutos, un pago por resolver, un ACH en camino de 11 días,
--     un cobro de hace 11 días sin depositar, un depósito asentado de hace 6
--     días sin casar y un enlace de una factura anulada; fn_stripe_pendientes
--     los lista (no el aviso con su próximo intento en el futuro)
do $$
declare
  v_obt text; v_aa text; v_ac text; v_k jsonb; v_e uuid;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    update stripe_config set ultimo_barrido_el = now(), ultimo_barrido_completo_el = now() where id = 1;
    v_aa := pg_temp.p1_rojos('alarma');
    v_ac := pg_temp.p1_rojos('cuadre');
    perform fn_stripe_evento_guardar(jsonb_build_object('id', 'evt_P1T37A', 'tipo', 'payment_intent.succeeded', 'livemode', false,
                                                        'created', 1793030400, 'objeto', jsonb_build_object('id', 'pi_P1T37X')), 'webhook', 'prueba');
    update stripe_eventos set recibido_el = now() - interval '20 minutes' where id = 'evt_P1T37A';
    perform fn_stripe_evento_guardar(jsonb_build_object('id', 'evt_P1T37B', 'tipo', 'payment_intent.succeeded', 'livemode', false,
                                                        'created', 1793030400, 'objeto', jsonb_build_object('id', 'pi_P1T37Y')), 'webhook', 'prueba');
    perform fn_stripe_evento_cerrar('evt_P1T37B', 'reintentar', null, 'Stripe no contestó', 'STRIPE_CAIDO');
    update stripe_eventos set recibido_el = now() - interval '20 minutes' where id = 'evt_P1T37B';
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T37A', 'succeeded', 10000), 'evt_P1T37C');
    update stripe_pagos set foto_al = now() - interval '2 hours' where pi = 'pi_P1T37A';
    perform pg_temp.p1_factura(-1601371, 500.00);
    perform pg_temp.p1_enlace(-1601371, 'plink_P1T37B');
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T37B', 'processing', 50000, null, 'ach'), 'evt_P1T37D');
    update stripe_pagos set creado_el = now() - interval '11 days', foto_al = now() - interval '2 hours' where pi = 'pi_P1T37B';
    perform pg_temp.p1_factura(-1601372, 500.00);
    perform pg_temp.p1_pagar('pi_P1T37C', -1601372, 50000);
    update stripe_pagos set ultimo_cambio_el = pg_temp.p1('hoy')::date - 11 where pi = 'pi_P1T37C';
    insert into stripe_payouts (po, monto, llegada, estado_stripe, estado)
    values ('po_P1T37', 1.00, pg_temp.p1('hoy')::date - 6, 'paid', 'asentado');
    perform pg_temp.p1_factura(-1601373, 500.00);
    v_e := (fn_stripe_enlace_preparar(-1601373, pg_temp.p1('dueno')::uuid, 'prueba')->>'enlace')::uuid;
    update stripe_enlaces set creado_el = now() - interval '10 minutes' where id = v_e;
    perform pg_temp.p1_factura(-1601374, 500.00);
    perform pg_temp.p1_enlace(-1601374, 'plink_P1T37E');
    perform fn_factura_anular(-1601374, 'p1-pruebas: se deshace');
    v_k := fn_stripe_pendientes();
    v_obt := format('alarmas nuevas: %s | cuadres nuevos: %s | pendientes: eventos %s · pagos %s · payouts %s · creando %s · por revisar %s',
                    pg_temp.p1_nuevos(v_aa, pg_temp.p1_rojos('alarma')), pg_temp.p1_nuevos(v_ac, pg_temp.p1_rojos('cuadre')),
                    (select string_agg(x->>'id', ' ' order by x->>'id') from jsonb_array_elements(v_k->'eventos') x where x->>'id' like 'evt_P1T37%'),
                    (select string_agg(x #>> '{}', ' ' order by x #>> '{}') from jsonb_array_elements(v_k->'pagos') x where x #>> '{}' like 'pi_P1T37%'),
                    (select string_agg(x #>> '{}', ' ') from jsonb_array_elements(v_k->'payouts') x where x #>> '{}' like 'po_P1T37%'),
                    (select count(*) from jsonb_array_elements(v_k->'enlaces_creando') x where (x->>'id')::uuid = v_e),
                    (select string_agg(x->>'motivo', ' ') from jsonb_array_elements(v_k->'enlaces_revisar') x where x->>'plink' = 'plink_P1T37E'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'las alarmas (sin cuadres en rojo) y lo que la rutina tiene pendiente',
    'alarmas nuevas: 22 24 26 29 30 31 35 | cuadres nuevos: ninguno | pendientes: eventos evt_P1T37A · pagos pi_P1T37A pi_P1T37B · payouts po_P1T37 · creando 1 · por revisar la factura #P1-1601374 se anuló',
    v_obt, v_obt = 'alarmas nuevas: 22 24 26 29 30 31 35 | cuadres nuevos: ninguno | pendientes: eventos evt_P1T37A · pagos pi_P1T37A pi_P1T37B · payouts po_P1T37 · creando 1 · por revisar la factura #P1-1601374 se anuló');
end $$;

-- 38. Los avisos: la misma clave no se duplica; si sube a grave se vuelve a
--     abrir; «Entendido» lo saca de la lista; al teléfono solo uno nuevo y
--     grave, y nunca con mxp.stripe_sin_push = '1'
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text; v_id bigint;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform fn_stripe_avisar('p1-pruebas:a', 'warn', 'primero');
    perform fn_stripe_avisar('p1-pruebas:a', 'warn', 'segundo');
    select format('%s fila, veces %s, «%s»', count(*), max(a.veces), max(a.texto)) into v_a from stripe_avisos a where a.clave = 'p1-pruebas:a';
    update stripe_avisos set visto_el = now() where clave = 'p1-pruebas:a';
    perform fn_stripe_avisar('p1-pruebas:a', 'bad', 'tercero');
    select format('%s, %s', a.nivel, case when a.visto_el is null then 'abierto otra vez' else 'sigue visto' end), a.id
      into v_b, v_id from stripe_avisos a where a.clave = 'p1-pruebas:a';
    perform fn_stripe_aviso_visto(v_id, pg_temp.p1('dueno')::uuid);
    v_c := case when exists (select 1 from v_stripe_avisos v where v.id = v_id) then 'sigue en la lista' else 'fuera de la lista' end;
    create temp table if not exists _p1_cartero (cuerpo jsonb);
    execute 'create or replace function public.fn_cartero(cuerpo jsonb) returns void language plpgsql as '
            '$f$ begin insert into _p1_cartero values (cuerpo); end $f$';
    perform set_config('mxp.stripe_sin_push', '', true);
    perform fn_stripe_avisar('p1-pruebas:b', 'bad', 'grave');
    perform fn_stripe_avisar('p1-pruebas:b', 'bad', 'grave otra vez');
    perform fn_stripe_avisar('p1-pruebas:c', 'warn', 'no grave');
    perform set_config('mxp.stripe_sin_push', '1', true);
    perform fn_stripe_avisar('p1-pruebas:d', 'bad', 'grave sin teléfono');
    select format('%s al teléfono («%s», para el dueño: %s)', count(*), max(c.cuerpo->>'titulo'),
                  bool_and(c.cuerpo->>'para' = pg_temp.p1('dueno'))::text) into v_d from _p1_cartero c;
    v_obt := format('%s | %s | %s | %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'los avisos: uno por clave, se reabre si sube a grave, «Entendido», y al teléfono solo lo nuevo y grave',
    '1 fila, veces 2, «segundo» | bad, abierto otra vez | fuera de la lista | 1 al teléfono («Stripe: grave», para el dueño: true)', v_obt,
    v_obt = '1 fila, veces 2, «segundo» | bad, abierto otra vez | fuera de la lista | 1 al teléfono («Stripe: grave», para el dueño: true)');
end $$;

-- 39. Suplantar: si el dueño de la configuración ya no es el dueño, 42501 y
--     no se registra nada; los claims de quien llama quedan como estaban
do $$
declare
  v_obt text; v_e text; v_claims text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    perform pg_temp.p1_factura(-1601391, 500.00);
    perform pg_temp.p1_factura(-1601392, 500.00);
    perform pg_temp.p1_enlace(-1601391, 'plink_P1T39A');
    perform pg_temp.p1_enlace(-1601392, 'plink_P1T39B');
    if pg_temp.p1('equipo') is not null then
      update stripe_config set dueno = pg_temp.p1('equipo')::uuid where id = 1;
      begin
        perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T39A', 'succeeded', 50000), 'evt_P1T39A');
        v_e := 'entró';
      exception when others then v_e := sqlstate; end;
      v_e := format('%s, %s cobro(s), %s pago(s)', v_e, (select count(*) from cobros where referencia = 'pi_P1T39A'),
                    (select count(*) from stripe_pagos where pi = 'pi_P1T39A'));
      update stripe_config set dueno = pg_temp.p1('dueno')::uuid where id = 1;
    else
      v_e := '42501, 0 cobro(s), 0 pago(s)';
    end if;
    perform set_config('request.jwt.claims', '{"marca":"antes"}', true);
    perform set_config('request.jwt.claim.sub', 'marca-sub', true);
    perform fn_stripe_pago_sincronizar(pg_temp.p1_foto('pi_P1T39B', 'succeeded', 50000), 'evt_P1T39B');
    v_claims := current_setting('request.jwt.claims', true) || ' ' || current_setting('request.jwt.claim.sub', true);
    v_obt := format('ya no es el dueño: %s | claims después: %s | cobro del que sí: %s', v_e, v_claims,
                    (select case when c.creado_por = pg_temp.p1('dueno')::uuid then 'del dueño' else 'MAL' end
                       from cobros c where c.referencia = 'pi_P1T39B'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'en nombre del dueño: si ya no lo es, nada; los claims de quien llama, intactos',
    'ya no es el dueño: 42501, 0 cobro(s), 0 pago(s) | claims después: {"marca":"antes"} marca-sub | cobro del que sí: del dueño', v_obt,
    v_obt = 'ya no es el dueño: 42501, 0 cobro(s), 0 pago(s) | claims después: {"marca":"antes"} marca-sub | cobro del que sí: del dueño');
end $$;

-- 40. La rutina: pg_net con la URL, la acción «barrer» y el secreto de
--     Vault; apagada, nada; sin el secreto, MX009; desde la API, 42501. (Con
--     el pg_net de mentira del banco, que apunta lo que manda; si no lo
--     apunta, omitida.)
do $$
declare
  v_obt text; v_n0 bigint; v_n1 bigint; v_ok text; v_apag text; v_sin text; v_api text;
begin
  begin
    perform pg_temp.p1_ser('servicio');
    perform pg_temp.p1_montar();
    if to_regclass('net._llamadas') is null then
      v_obt := 'omitida: el pg_net del banco no apunta las llamadas (sin pruebas/seguridad/00-vault-shim.sql)';
    else
      execute 'select count(*) from net._llamadas' into v_n0;
      perform fn_stripe_programado();
      execute 'select count(*) from net._llamadas' into v_n1;
      execute $q$ select case when l.url = (select c.funcion_url from stripe_config c where c.id = 1) and l.body->>'accion' = 'barrer'
                                   and l.headers->>'x-mxp-rutina' = (select s.decrypted_secret from vault.decrypted_secrets s
                                                                      where s.name = 'stripe_rutina_secreto')
                              then 'url, barrer y el secreto' else 'MAL: ' || l.url || ' ' || l.body::text end
                    from net._llamadas l order by l.id desc limit 1 $q$ into v_ok;
      update stripe_config set rutina_activa = false where id = 1;
      v_apag := coalesce(fn_stripe_programado()::text, 'nada');
      update stripe_config set rutina_activa = true where id = 1;
      delete from vault.secrets where name = 'stripe_rutina_secreto';
      begin
        perform fn_stripe_programado();
        v_sin := 'entró';
      exception when others then v_sin := sqlstate; end;
      perform pg_temp.p1_ser('dueno');
      begin
        perform fn_stripe_programado();
        v_api := 'entró';
      exception when others then v_api := sqlstate; end;
      execute 'reset role';
      v_obt := format('%s llamada(s), %s | apagada: %s | sin secreto: %s | desde la API: %s', v_n1 - v_n0, v_ok, v_apag, v_sin, v_api);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'la rutina: pg_net con la URL, «barrer» y el secreto de Vault',
    '1 llamada(s), url, barrer y el secreto | apagada: nada | sin secreto: MX009 | desde la API: 42501', v_obt,
    case when v_obt like 'omitida%' then null
         else v_obt = '1 llamada(s), url, barrer y el secreto | apagada: nada | sin secreto: MX009 | desde la API: 42501' end);
end $$;


-- =====================================================================
-- El final
-- =====================================================================

-- 41. Nada queda: las tablas de p1, los cobros, las devoluciones, los
--     asientos, el banco, las cuentas y Vault, igual que al empezar
do $$
declare
  v_obt text;
begin
  v_obt := case when pg_temp.p1_conteos() = pg_temp.p1('conteos') then 'igual que al empezar'
                else 'antes: ' || pg_temp.p1('conteos') || ' · ahora: ' || pg_temp.p1_conteos() end;
  insert into _pruebas values (41, 'nada queda al deshacer (ni en Vault)', 'igual que al empezar', v_obt, v_obt = 'igual que al empezar');
end $$;

-- 42. Con p1 puesto, c2 (la cadena y «permisos»), c3 (los puentes), c6 (el
--     banco, con «protecciones del banco») y c4 (los estados: salvo lo que ya
--     estaba en rojo antes de las pruebas, que se dice) siguen en verde; el
--     control de p1 sin cuadres en rojo; nada de p1 en la API ni SECURITY
--     DEFINER
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_p1 text; v_api text;
begin
  begin
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena() where not ok;
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar() where not ok;
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy') where not ok;
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.p1('rojos_c4'), ', ')));
    v_p1 := pg_temp.p1_rojos('cuadre');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_stripe%'
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | p1 cuadres en rojo: %s | p1 en la API o definer: %s', v_c2, v_c3, v_c6, v_c4, v_p1, v_api);
  exception
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'el cierre: c2, c3, c6 y c4 en verde con p1 puesto; el control de p1 sin cuadres en rojo; nada en la API',
    'c2 verde | c3 verde | c6 verde | c4 verde | p1 cuadres en rojo: ninguno | p1 en la API o definer: ninguna',
    v_obt || case when pg_temp.p1('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.p1('rojos_c4') || ')' else '' end,
    v_obt = 'c2 verde | c3 verde | c6 verde | c4 verde | p1 cuadres en rojo: ninguno | p1 en la API o definer: ninguna');
end $$;


-- Lo que se puso para la sesión, como estaba
reset mxp.stripe_sin_push;
reset c4.control_tope;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4 y c6):
-- si el SQL Editor deja de esperar, la corrida sigue en el servidor hasta
-- el final y se lee después con
--   select * from pruebas.p1_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.p1_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.p1_resultado from public, anon, authenticated, service_role;
truncate pruebas.p1_resultado;
insert into pruebas.p1_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
