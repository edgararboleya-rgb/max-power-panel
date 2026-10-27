-- =====================================================================
-- p1-stripe.sql — COBROS EN LÍNEA CON STRIPE · p1
-- 27-oct-2026, v1 · se pega en el SQL Editor DESPUÉS de c1, c2, c3, c4,
-- c6, c7 y s1. Idempotente: se puede volver a pegar entero (no pisa la
-- configuración, ni las cuentas que Edgar cambie, ni nada de lo que ya
-- entró al libro).
--
-- Qué hace:
--   · Edgar (el dueño, con el código del teléfono) pide desde la app un
--     ENLACE DE PAGO de una factura: por lo que el LIBRO dice que debe (no
--     por la casilla «pagada», que durante el paralelo con QuickBooks la
--     lleva él), de un solo uso, para pagar desde la cuenta de banco (ACH)
--     o con tarjeta. La app lo enseña para copiarlo y mandarlo.
--   · El cliente paga en Stripe. Stripe avisa (webhook) y el cobro entra
--     SOLO al libro por c3 (fn_cobro_registrar) contra la factura, por el
--     BRUTO, en la 1020 «Stripe — cobros en tránsito». Un pago por cuenta
--     de banco que todavía no liquida queda «en camino», sin asiento; uno
--     que falla no deja nada en el libro (y avisa).
--   · UN COBRO VIVO POR PAGO. Cada cambio del pago (un reembolso, una
--     disputa que retira el dinero, un reembolso que falla, una disputa
--     ganada) devuelve el cobro vivo ENTERO (fn_cobro_devolver, el camino
--     de c3 para el dinero que se devuelve) y registra uno nuevo por lo que
--     debe quedar (otra llave, la misma referencia pi_…). Así c3 nunca ve
--     dos cobros vivos del mismo pago (su regla «el mismo depósito no se
--     registra dos veces» los pararía) y el libro siempre dice lo que
--     Stripe dice hoy.
--   · Cuando Stripe deposita en Chase (payout), la base asienta su
--     composición (la lista de balance transactions que da Stripe) en DOS
--     asientos a mano, sin origen, con la misma fecha:
--       P1 «sale de Stripe»: Dr 1140 neto + Dr 6130 comisiones / Cr 1020
--          lo que ese depósito liquida;
--       P2 «llega a Chase»:  Dr 1010 neto / Cr 1140.
--     El depósito STRIPE que Plaid trae a la 1010 casa SOLO con la línea
--     de 1010 de P2 (regla R1 de c6, sin motivo). La 1140 «Stripe —
--     depósitos en camino a Chase» queda en cero al terminar cada
--     transacción; la 1020 vuelve a cero con cada depósito (su saldo es lo
--     cobrado en Stripe que falta depositar).
--     Por qué dos asientos y no uno: si el asiento que lleva la línea de
--     1010 tiene enfrente otra cuenta PROPIA (la 1020, que para c3 y c6 es
--     un banco), EL CRITERIO de c6 dice «transferencia entre cuentas
--     propias» y el banco dice «STRIPE» (un tercero): se contradicen, R1 no
--     lo casa nunca y casarlo sin motivo pone en rojo el cuadre 59. Con la
--     1140 (que no es banco) enfrente, R1 lo casa solo.
--   · Todo con su rastro: cada aviso de Stripe (stripe_eventos, sin datos
--     personales), cada enlace, cada pago (stripe_pagos, con la foto de lo
--     que Stripe dijo), cada cobro y devolución que puso en el libro
--     (stripe_pago_libro), cada depósito y su composición (stripe_payouts y
--     stripe_payout_lineas) y los avisos para Edgar (stripe_avisos). Los
--     ids de Stripe van en la referencia, la llave y las notas del cobro
--     (que c3 copia a la procedencia del asiento) y en la procedencia de P1
--     y P2.
--
-- Quién hace qué:
--   · La función de borde «stripe» (supabase/functions/stripe/index.ts) es
--     la ÚNICA que habla con Stripe, con la llave RESTRINGIDA y el secreto
--     del webhook en los secretos de Edge Functions (STRIPE_SECRET_KEY,
--     STRIPE_WEBHOOK_SECRET). A ESTA BASE entra directo, como postgres
--     (SUPABASE_DB_URL), igual que pg_cron o el SQL Editor. Guarda primero
--     cada aviso (fn_stripe_evento_guardar), contesta 200 a Stripe, y
--     después vuelve a pedir a Stripe el objeto VIVO (el pago, el depósito)
--     y se lo da a la base (fn_stripe_pago_sincronizar,
--     fn_stripe_payout_sincronizar): la base aplica el estado de HOY, y una
--     foto más vieja que la que ya tiene no toca nada. Lo que falla queda
--     «reintentar» (5 min, 15 min, 1 h, 4 h, 12 h) o «revisar».
--   · La rutina: pg_cron (como postgres), cada 15 minutos →
--     fn_stripe_programado() → pg_net POST a la función con el secreto
--     stripe_rutina_secreto (en Vault; el mismo valor va en el secreto
--     STRIPE_RUTINA_SECRETO de Edge Functions) → la función «barre»: lo que
--     quedó por procesar, lo que Stripe no entregó, los depósitos sin
--     casar y los enlaces por revisar.
--   · EN NOMBRE DEL DUEÑO. c3 y c6 exigen al dueño (es_dueno()). Lo de
--     Stripe pasa sin Edgar delante: las funciones de aquí fijan auth.uid()
--     al dueño de stripe_config (request.jwt.claims y claim.sub, solo
--     dentro de la transacción), comprueban es_dueno() y lo quitan al
--     terminar (como fn_plaid_recibir en c7). Queda escrito: cobros.
--     creado_por y asientos.usuario_id dicen el dueño, rol_bd dice
--     postgres (la función de borde, pg_cron o el SQL Editor).
--   · La app solo LEE las vistas v_stripe_* (el dueño). Todo lo que mueve
--     (crear un enlace, decir a qué va un pago, casar un depósito) lo pide
--     a la función de borde con su sesión en aal2 (el código del teléfono:
--     s1 solo frena PostgREST, por eso la función lo mira ella misma).
--
-- Por qué ninguna función de aquí está en la API (la lección de c7): c2
-- («permisos») y c6 («protecciones del banco», cuadre 90) toman por ajena
-- toda función SECURITY DEFINER que la API pueda ejecutar y que lea el
-- libro o el banco. Aquí ninguna fn_stripe_* es SECURITY DEFINER ni tiene
-- EXECUTE para anon, authenticated ni service_role; la guarda de todas es
-- fn_stripe_exigir() → fn_desde_editor() (c2): verdad para la función de
-- borde como postgres, para pg_cron y para el SQL Editor; falsa para
-- cualquier rol de la API. Ninguna lleva un prefijo que sellan otras capas
-- (fn_banco_%, fn_conciliacion_%, fn_puente_%, fn_estados_%…): todas son
-- fn_stripe_% y las vistas v_stripe_%. Ningún trigger en ninguna tabla.
-- Las vistas leen solo TABLAS (nunca vistas de c3, c4 ni c6: esas se
-- rehacen al volver a pegar su archivo, y se pararían con MX000).
--
-- Lo que este archivo NO toca: c1..c7, s1, es_dueno(), docs/sql, la
-- casilla «pagada» de las facturas ni su cobrado, cobrada_el, metodo_cobro
-- o link_pago (link_pago es de QuickBooks; c3, punto 10), puente_cuentas,
-- banco_descriptores, cliente.html. No reembolsa, no cancela y no contesta
-- disputas: eso se hace en el panel de Stripe y aquí se registra solo.
--
-- Las cuentas nuevas (se crean aquí, solo si faltan; c1 no se toca):
--   1020 «Stripe — cobros en tránsito» (activo, deudora, sin obra): LA
--        PUENTE. Tiene que ser 10xx: fn_cobro_registrar solo cobra a un
--        banco (fn_puente_es_banco). Para c4 es efectivo; para c6, un banco
--        sin estado de cuenta (la pantalla la esconde y nadie la concilia:
--        la vigila v_stripe_control).
--   1140 «Stripe — depósitos en camino a Chase» (activo, deudora, sin
--        obra): LA DE PASO, siempre en cero.
--   Y su fila de los estados (fn_estados_mapeo_derivar, c4): sin ella c4
--   dice en rojo «cuadre: mapeo completo».
--
-- Cómo se instala (Edgar, en este orden, con la cadena c1..c7 y s1 ya
-- pegada como dice pruebas/conta/README.md):
--   0. ANTES, en Stripe (modo real, el interruptor de prueba apagado):
--      · Settings → Payouts: calendario AUTOMÁTICO (p. ej. diario) a la
--        cuenta Chase ····4392, con el descriptor como viene (STRIPE).
--        Nunca payouts manuales ni instantáneos: de esos Stripe no da el
--        detalle y la app los deja «por revisar» (no los puede asentar).
--      · Balances: «Available» y «Pending» en $0.00. Si no lo están,
--        instala cuando Stripe haya depositado lo que hay (o anótalo): lo
--        cobrado antes de instalar se registra en la bandeja como siempre.
--        Un depósito que Stripe creó ANTES de pegar este archivo queda
--        «fuera de la app» solo (no se asienta dos veces). Lo que QuickBooks
--        tenía de Stripe en Undeposited Funds al 30-sep ya está en la 1010
--        por la apertura: si un depósito lo trae, ese depósito se saca de
--        la app con «Ya está en el libro» (no con «Decir a qué va»).
--      · Settings → Payment methods: ACH Direct Debit y Cards encendidos.
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla de 11 filas: la configuración, las dos cuentas («creada» la
--      primera vez, «ya estaba» al volver a pegar), el dueño, el secreto de
--      la rutina (cópialo a STRIPE_RUTINA_SECRETO, sin mandarlo por chat),
--      la URL del webhook, la versión de la API, los 20 eventos, los
--      permisos de la llave, la rutina de pg_cron y el control («0 cuadres
--      rojos · 0 alarmas»). Si algo de lo que da por hecho falta, para con
--      MX000 y no queda nada.
--   2. SQL Editor → pegar docs/conta/p1-pruebas.sql → 42 filas en true (en
--      producción la 40, y quizá la 32, salen «omitida» y dicen por qué).
--   3. Stripe → Developers → API keys → «+ Create restricted key», nombre
--      «Max Power app — cobros en línea», todo en None salvo (la fila
--      «permisos de la llave» de la tabla del paso 1 dice lo mismo):
--      Payment Links = Write · Checkout Sessions = Read · PaymentIntents =
--      Read · Charges = Read · Refunds = Read · Disputes = Read · Payouts =
--      Read · Balance = Read · Balance transaction sources = Read · Events
--      = Read. Copia la rk_live_… (una sk_live_ se rechaza).
--   4. Stripe → Developers → Webhooks → «Add endpoint»: la URL de la fila
--      «URL del webhook», versión de API 2026-09-30.endive y EXACTAMENTE
--      estos 20 eventos (la fila «eventos (márcalos en Stripe)»):
--      checkout.session.completed, checkout.session.async_payment_succeeded,
--      checkout.session.async_payment_failed, payment_intent.processing,
--      payment_intent.succeeded, payment_intent.payment_failed,
--      payment_intent.canceled, charge.refunded, refund.created,
--      refund.updated, refund.failed, charge.dispute.created,
--      charge.dispute.funds_withdrawn, charge.dispute.funds_reinstated,
--      charge.dispute.closed, payout.paid, payout.failed, payout.canceled,
--      payout.reconciliation_completed, payment_link.updated. Copia su
--      «Signing secret» (whsec_…).
--   5. Supabase → Edge Functions → Secrets: STRIPE_SECRET_KEY (la rk_live_),
--      STRIPE_WEBHOOK_SECRET (la whsec_) y STRIPE_RUTINA_SECRETO (la fila
--      del paso 1). Nunca MXP_BANCO_PRUEBAS ni MXP_DB_URL: son del banco de
--      pruebas, y con ellos la función no arranca.
--   6. La función «stripe» (Verify JWT apagado) y …/stripe?paso=salud:
--      ok, modo «real», llave_restringida, webhook, rutina y base en true.
--   7. En la app: Contabilidad → Bancos y tarjetas → «Cobros en línea
--      (Stripe)» → «Probar la llave»: todo con ✓ (hace las mismas llamadas
--      que la función; un ✗ dice qué permiso falta y cómo se llama en el
--      panel de Stripe).
--
-- Lo que llama la función de borde (como postgres): fn_stripe_evento_guardar,
-- fn_stripe_evento_cerrar, fn_stripe_pendientes, fn_stripe_barrido_anotar,
-- fn_stripe_enlace_preparar/_creado/_fallo/_desactivado, fn_stripe_enlace,
-- fn_stripe_pago_sincronizar, fn_stripe_pago_resolver,
-- fn_stripe_payout_sincronizar, fn_stripe_payout_linea_resolver,
-- fn_stripe_payout_casar, fn_stripe_aviso_visto, fn_stripe_resumen,
-- fn_stripe_control y fn_stripe_dueno_fijar. Montos: en dólares en las
-- tablas; en centavos (enteros) en las fotos y líneas que manda la función.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. La guarda, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- ¿Quién llama? La función de borde (como postgres), pg_cron o el SQL
-- Editor. Nadie de la API: se mira el rol de la llamada, no current_user.
create or replace function public.fn_stripe_exigir() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_desde_editor() then return; end if;
  raise exception using errcode = '42501',
    message = 'Esto lo hace la función de borde de Stripe (conectada como postgres), pg_cron o el SQL Editor; la app no.';
end $$;
revoke execute on function public.fn_stripe_exigir() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_exigir() is 'p1: la guarda de todas las fn_stripe_*: solo la función de borde (como postgres), pg_cron o el SQL Editor (fn_desde_editor).';

-- Lo que falta para pegar p1, en llano (nulo = nada). La usan la
-- precondición de abajo, el alta de las cuentas y las pruebas (la 2). Las
-- cuentas: si la puente o la de paso ya existen, tienen que tener la forma
-- de p1; si no, p1 no las pisa (nunca «on conflict do update»).
create or replace function public.fn_stripe_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta  text[] := '{}';
  v_x      text;
  v_puente text := '1020';
  v_paso   text := '1140';
  r        record;
begin
  foreach v_x in array array['fn_desde_editor()', 'es_dueno()', 'fn_postear_interno(jsonb)',
                             'fn_reversar_interno(uuid,text,text,jsonb)', 'fn_cobro_registrar(jsonb)',
                             'fn_cobro_devolver(uuid,date,text,text)', 'fn_puente_fecha(date)', 'fn_puente_es_banco(text)',
                             'fn_puente_cuenta_de(text)', 'fn_fecha_miami(timestamptz)', 'fn_banco_casar(uuid)',
                             'fn_banco_casar_con(uuid,jsonb,text)', 'fn_estados_mapeo_derivar()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'facturas', 'facturas_cobro', 'puente_cuentas', 'movimientos_banco', 'banco_casados',
                             'banco_casado_lineas', 'conciliaciones', 'plaid_conexiones', 'estados_mapeo', 'perfiles'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if not exists (select 1 from pg_namespace where nspname = 'vault') then
    v_falta := v_falta || 'el esquema vault'::text;
  end if;
  if cardinality(v_falta) > 0 then
    return format('p1 se pega después de c1, c2, c3, c4, c6, c7 y s1: falta %s.', array_to_string(v_falta, ', '));
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: los cobros en línea se registran en su nombre.';
  end if;
  -- Las cuentas que usa la configuración de hoy (si ya se pegó), o las de
  -- p1.
  if to_regclass('public.stripe_config') is not null then
    execute 'select coalesce((select cuenta_puente from public.stripe_config where id = 1), ''1020''),
                    coalesce((select cuenta_paso from public.stripe_config where id = 1), ''1140'')'
       into v_puente, v_paso;
  end if;
  for r in select c.*, case when c.codigo = v_puente then 'puente' else 'paso' end as papel
             from cuentas c where c.codigo in (v_puente, v_paso) loop
    if not (r.tipo = 'activo' and r.saldo_normal = 'debe' and r.imputable and r.activa and r.regla_obra = 'prohibida'
            and r.regla_cost_code = 'prohibida' and r.padre is null
            and (r.papel = 'paso' or left(r.codigo, 2) = '10') and (r.papel = 'puente' or left(r.codigo, 2) <> '10')) then
      return format('La cuenta %s ya existe con otra forma (%s, saldo %s, %s, %s, obra %s, código %s%s): p1 no la pisa; dime qué '
                    'es antes de seguir.', r.codigo, r.tipo, r.saldo_normal,
                    case when r.imputable then 'imputable' else 'de grupo' end,
                    case when r.activa then 'activa' else 'inactiva' end, r.regla_obra, r.regla_cost_code,
                    coalesce(', padre ' || r.padre, ''));
    end if;
  end loop;
  -- Nada ajeno colgado de las vistas de p1 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname like 'v\_stripe\_%'
     and dc.oid <> cv.oid and not (dc.relnamespace = 'public'::regnamespace and dc.relname like 'v\_stripe\_%');
  if v_x is not null then
    return format('%s depende(n) de las vistas de p1, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, pega '
                  'p1 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_stripe_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_precondiciones() is 'p1: lo que falta para pegar p1-stripe.sql (nulo = nada): c1..c7, Vault, el SQL Editor, un dueño activo y la forma de las cuentas 1020 y 1140 si ya existen.';

do $$
declare
  v text;
begin
  v := public.fn_stripe_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'p1-stripe NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee, nadie de la API
--    escribe; todo entra por las funciones de abajo, como postgres).
--    Montos en dólares, numeric(14,2). Llaves foráneas solo a facturas,
--    cobros, cobros_devoluciones, asientos, cuentas y entre tablas de p1;
--    nunca a una tabla de c6. Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila. dueno = en nombre de quién se registra
-- (como plaid_conexiones.creado_por); desde = cuándo se instaló (un pago
-- de antes no es de un enlace de la app); acepta_prueba solo en el banco
-- de pruebas (con una llave de prueba en producción no entra nada).
create table if not exists public.stripe_config (
  id                         int           primary key,
  funcion_url                text          not null default 'https://zeogjvwcmstmkwxjvykz.supabase.co/functions/v1/stripe',
  rutina_activa              boolean       not null default true,
  cuenta_puente              text          not null default '1020' references public.cuentas (codigo),
  cuenta_paso                text          not null default '1140' references public.cuentas (codigo),
  cuenta_comisiones          text          not null default '6130' references public.cuentas (codigo),
  cuenta_banco               text          not null default '1010' references public.cuentas (codigo),
  dueno                      uuid          not null,
  desde                      timestamptz   not null default now(),
  modo                       text,
  acepta_prueba              boolean       not null default false,
  version_api                text          not null default '2026-09-30.endive',
  dias_sin_deposito          int           not null default 10,
  ultimo_evento_el           timestamptz,
  ultimo_evento_tipo         text,
  ultimo_barrido_el          timestamptz,
  ultimo_barrido_completo_el timestamptz,
  ultimo_barrido             jsonb,
  ultimo_error               text,
  ultimo_error_el            timestamptz,
  actualizado                timestamptz   not null default now(),
  constraint stripe_config_una check (id = 1),
  constraint stripe_config_modo check (modo in ('prueba', 'real')),
  constraint stripe_config_dias check (dias_sin_deposito between 1 and 90)
);
comment on table public.stripe_config is 'p1: la configuración de los cobros en línea (una fila). Sin secretos: las llaves viven en Edge Functions y el de la rutina en Vault.';

-- Cada aviso de Stripe, guardado ANTES de procesarlo (sin datos personales:
-- fn_stripe_sin_datos). Uno por event.id: el repetido suma «veces».
create table if not exists public.stripe_eventos (
  id               text          primary key,
  tipo             text          not null,
  objeto_tipo      text,
  objeto_id        text,
  livemode         boolean       not null,
  api_version      text,
  creado_stripe    timestamptz   not null,
  datos            jsonb         not null,
  por              text          not null,
  recibido_el      timestamptz   not null default now(),
  veces            int           not null default 1,
  ultima_vez       timestamptz   not null default now(),
  estado           text          not null default 'recibido',
  intentos         int           not null default 0,
  proximo_intento  timestamptz,
  hecho_el         timestamptz,
  resultado        jsonb,
  ultimo_error     text,
  codigo_error     text,
  constraint stripe_eventos_id check (id ~ '^evt_[A-Za-z0-9_]+$'),
  constraint stripe_eventos_por check (por in ('webhook', 'barrido', 'pantalla')),
  constraint stripe_eventos_estado check (estado in ('recibido', 'hecho', 'ignorado', 'reintentar', 'revisar'))
);
create index if not exists stripe_eventos_pendientes_idx on public.stripe_eventos (estado, proximo_intento)
  where estado in ('recibido', 'reintentar');
create index if not exists stripe_eventos_objeto_idx on public.stripe_eventos (objeto_id);
comment on table public.stripe_eventos is 'p1: cada aviso (webhook) de Stripe, guardado antes de procesarlo, con su estado y sus reintentos.';

-- Los enlaces de pago (Payment Links de Stripe), uno vivo por factura.
create table if not exists public.stripe_enlaces (
  id                 uuid          primary key default gen_random_uuid(),
  factura_id         bigint        not null references public.facturas (id),
  factura_num        text          not null,
  proyecto_id        text,
  monto              numeric(14,2) not null,
  con_retencion      boolean       not null default false,
  saldo_cxc          numeric(14,2) not null,
  saldo_retencion    numeric(14,2) not null,
  estado             text          not null default 'creando',
  plink              text          unique,
  url                text,
  modo               text,
  idempotencia       text          not null unique,
  creado_por         uuid          not null,
  creado_el          timestamptz   not null default now(),
  activo_el          timestamptz,
  usado_el           timestamptz,
  sesion             text,
  pi                 text,
  desactivado_el     timestamptz,
  desactivado_motivo text,
  desactivado_por    text,
  error              text,
  reemplaza_a        uuid          references public.stripe_enlaces (id),
  constraint stripe_enlaces_monto check (monto between 0.50 and 999999.99),
  constraint stripe_enlaces_estado check (estado in ('creando', 'activo', 'usado', 'desactivado', 'fallido')),
  constraint stripe_enlaces_plink check (plink ~ '^plink_'),
  constraint stripe_enlaces_modo check (modo in ('prueba', 'real')),
  constraint stripe_enlaces_por check (desactivado_por in ('pantalla', 'rutina', 'stripe', 'p1'))
);
create unique index if not exists stripe_enlaces_uno_vivo on public.stripe_enlaces (factura_id) where estado in ('creando', 'activo');
comment on table public.stripe_enlaces is 'p1: los enlaces de pago de Stripe (un solo uso), uno vivo por factura. No escribe facturas.link_pago (es de QuickBooks).';

-- Un pago (PaymentIntent) y lo que hay de él en el libro: objetivo = lo
-- que debe haber (D4: lo cobrado menos lo reembolsado y lo retirado por
-- disputas, más lo reintegrado); en_libro = lo que hay (su cobro vivo).
create table if not exists public.stripe_pagos (
  id               uuid          primary key default gen_random_uuid(),
  pi               text          not null unique,
  enlace_id        uuid          references public.stripe_enlaces (id),
  plink            text,
  sesion           text,
  factura_id       bigint        references public.facturas (id),
  factura_num      text,
  proyecto_id      text,
  medio            text,
  monto            numeric(14,2) not null,
  moneda           text          not null default 'usd',
  estado           text          not null,
  estado_stripe    text          not null,
  cargo            text,
  reembolsado      numeric(14,2) not null default 0,
  disputa_retirada numeric(14,2) not null default 0,
  disputa_id       text,
  disputa_estado   text,
  disputa_vence    date,
  objetivo         numeric(14,2) not null default 0,
  en_libro         numeric(14,2) not null default 0,
  cobro_id         uuid          references public.cobros (id),
  version          int           not null default 0,
  cobrado_el       date,
  ultimo_cambio_el date,
  fallo            text,
  revisar          text,
  resuelto         jsonb,
  foto             jsonb,
  foto_al          timestamptz,
  ultimo_evento    text,
  creado_el        timestamptz   not null default now(),
  actualizado_el   timestamptz   not null default now(),
  constraint stripe_pagos_pi check (pi ~ '^pi_'),
  constraint stripe_pagos_medio check (medio in ('tarjeta', 'ach', 'otro')),
  constraint stripe_pagos_estado check (estado in ('iniciado', 'en_camino', 'cobrado', 'devuelto', 'en_disputa', 'fallido', 'revisar'))
);
create index if not exists stripe_pagos_factura_idx on public.stripe_pagos (factura_id);
create index if not exists stripe_pagos_estado_idx on public.stripe_pagos (estado)
  where estado in ('iniciado', 'en_camino', 'en_disputa', 'revisar');
comment on table public.stripe_pagos is 'p1: un pago de Stripe (PaymentIntent) por fila: su estado, la foto de lo que dijo Stripe y su cobro vivo en el libro.';

-- El rastro de cada movimiento de un pago en el libro (+ cobro, − devolución).
create table if not exists public.stripe_pago_libro (
  id              bigint        generated always as identity primary key,
  pago_id         uuid          not null references public.stripe_pagos (id),
  accion          text          not null,
  cobro_id        uuid          not null references public.cobros (id),
  devolucion_id   uuid          references public.cobros_devoluciones (id),
  asiento_id      uuid          references public.asientos (id),
  asiento         text,
  fecha_contable  date,
  monto           numeric(14,2) not null,
  llave           text,
  motivo          text,
  tardio          text,
  anticipo        numeric(14,2),
  evento          text,
  creado_el       timestamptz   not null default now(),
  constraint stripe_pago_libro_accion check (accion in ('cobro', 'devolucion')),
  constraint stripe_pago_libro_una unique (cobro_id, accion)
);
create index if not exists stripe_pago_libro_pago_idx on public.stripe_pago_libro (pago_id);
comment on table public.stripe_pago_libro is 'p1: cada cobro y cada devolución que un pago de Stripe puso en el libro (c3), con su asiento.';

-- Los depósitos de Stripe a Chase (payouts automáticos) y sus asientos:
-- asiento_salida = P1, asiento_llegada = P2, reverso_llegada = el de P2 si
-- el depósito falló, asiento_vuelta = P3 (el dinero que volvió a Stripe).
create table if not exists public.stripe_payouts (
  id                  uuid          primary key default gen_random_uuid(),
  po                  text          not null unique,
  monto               numeric(14,2) not null,
  moneda              text,
  llegada             date          not null,
  automatico          boolean,
  metodo              text,
  estado_stripe       text          not null,
  conciliacion_stripe text,
  bt_propio           text,
  bt_fallo            text,
  fallo_codigo        text,
  estado              text          not null,
  bruto               numeric(14,2),
  comisiones          numeric(14,2),
  vuelve              numeric(14,2),
  fuera               numeric(14,2),
  otros               numeric(14,2),
  n_pagos             int,
  fecha_asiento       date,
  fecha_documento     date,
  asiento_salida      uuid          references public.asientos (id),
  asiento_llegada     uuid          references public.asientos (id),
  reverso_llegada     uuid          references public.asientos (id),
  asiento_vuelta      uuid          references public.asientos (id),
  rehechos            jsonb         not null default '[]'::jsonb,
  revisar             text,
  esperando           jsonb,
  foto                jsonb,
  foto_al             timestamptz,
  ultimo_evento       text,
  creado_el           timestamptz   not null default now(),
  actualizado_el      timestamptz   not null default now(),
  constraint stripe_payouts_po check (po ~ '^po_'),
  constraint stripe_payouts_estado check (estado in ('en_camino', 'esperando_composicion', 'esperando_cobros', 'asentado', 'fallido',
                                                     'revisar', 'fuera'))
);
-- 'fuera': un depósito que no es de p1 (Stripe lo creó antes de instalar,
-- o Edgar dijo que su dinero ya está en el libro por otro camino): sin
-- asientos, y su depósito de Chase se lleva en la bandeja como antes.
alter table public.stripe_payouts add column if not exists creado_stripe timestamptz;
alter table public.stripe_payouts add column if not exists fuera_motivo text;
alter table public.stripe_payouts add column if not exists fuera_el timestamptz;
alter table public.stripe_payouts drop constraint if exists stripe_payouts_estado;
alter table public.stripe_payouts add constraint stripe_payouts_estado
  check (estado in ('en_camino', 'esperando_composicion', 'esperando_cobros', 'asentado', 'fallido', 'revisar', 'fuera'));
comment on table public.stripe_payouts is 'p1: los depósitos de Stripe a Chase (payouts automáticos), con sus asientos P1 (sale de Stripe), P2 (llega a Chase) y P3 (el dinero que volvió si falló); «fuera» si no son de p1 (de antes de instalar, o ya en el libro).';

-- La composición de cada depósito (las balance transactions de Stripe).
create table if not exists public.stripe_payout_lineas (
  payout_id   uuid          not null references public.stripe_payouts (id),
  txn         text          not null unique,
  tipo        text          not null,
  categoria   text,
  monto       numeric(14,2) not null,
  comision    numeric(14,2) not null,
  neto        numeric(14,2) not null,
  fuente      text,
  pi          text,
  pago_id     uuid          references public.stripe_pagos (id),
  clase       text          not null,
  cuenta      text          references public.cuentas (codigo),
  resuelto    jsonb,
  creado_stripe timestamptz,
  disponible  date,
  constraint stripe_payout_lineas_pk primary key (payout_id, txn),
  constraint stripe_payout_lineas_clase check (clase in ('pago', 'vuelve', 'comision', 'otro', 'propio'))
);
create index if not exists stripe_payout_lineas_pago_idx on public.stripe_payout_lineas (pago_id);
create index if not exists stripe_payout_lineas_fuente_idx on public.stripe_payout_lineas (fuente);
comment on table public.stripe_payout_lineas is 'p1: la composición de cada depósito de Stripe (sus balance transactions), clasificada: pago, vuelve, comision, otro o propio.';

-- Los avisos para Edgar (la pantalla, y lo grave también al teléfono).
create table if not exists public.stripe_avisos (
  id          bigint        generated always as identity primary key,
  clave       text          not null unique,
  nivel       text          not null,
  texto       text          not null,
  objeto      text,
  creado_el   timestamptz   not null default now(),
  repetido_el timestamptz,
  veces       int           not null default 1,
  visto_el    timestamptz,
  visto_por   uuid,
  constraint stripe_avisos_nivel check (nivel in ('info', 'warn', 'bad'))
);
comment on table public.stripe_avisos is 'p1: los avisos de los cobros en línea para Edgar (uno por clave; el repetido suma «veces»).';


-- ---------------------------------------------------------------------
-- 2. Las cuentas nuevas y su fila de los estados (c1 no se toca). Solo
--    si faltan («where not exists»: nada de «on conflict do update», para
--    no pisar lo que Edgar cambie). trg_cuentas_historial escribe el
--    INSERT; volver a pegar c1 no las toca (su upsert es de su lista).
-- ---------------------------------------------------------------------
create or replace function public.fn_stripe_cuentas_alta() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_x      text;
  v_nuevas text[] := '{}';
  v_mapeo  jsonb;
  v_n      int;
begin
  perform fn_stripe_exigir();
  v_x := fn_stripe_precondiciones();
  if v_x is not null then
    raise exception using errcode = 'MX000', message = 'p1-stripe NO se aplicó, no se tocó nada: ' || v_x;
  end if;
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
  select '1020', 'Stripe — cobros en tránsito', 'Stripe — payments in transit', 'activo', 'debe', true, 'prohibida', 'prohibida', null,
         'p1: cada cobro en línea entra por el bruto (fn_cobro_registrar) y cada depósito de Stripe lo liquida. Su saldo es lo cobrado en '
         'Stripe que falta depositar. Solo la mueve p1 (v_stripe_control).'
   where not exists (select 1 from cuentas where codigo = '1020')
     and (to_regclass('public.stripe_config') is null
          or coalesce((select c.cuenta_puente from stripe_config c where c.id = 1), '1020') = '1020');
  get diagnostics v_n = row_count;
  if v_n > 0 then v_nuevas := v_nuevas || '1020'::text; end if;
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
  select '1140', 'Stripe — depósitos en camino a Chase', 'Stripe — payouts in transit to bank', 'activo', 'debe', true, 'prohibida',
         'prohibida', null,
         'p1: cuenta de paso entre la 1020 y la 1010, para que el depósito de Chase case solo con su payout. Siempre en cero.'
   where not exists (select 1 from cuentas where codigo = '1140')
     and (to_regclass('public.stripe_config') is null
          or coalesce((select c.cuenta_paso from stripe_config c where c.id = 1), '1140') = '1140');
  get diagnostics v_n = row_count;
  if v_n > 0 then v_nuevas := v_nuevas || '1140'::text; end if;
  -- (sin esto c4 dice en rojo «cuadre: mapeo completo»)
  v_mapeo := fn_estados_mapeo_derivar();
  -- lo que enseña fn_stripe_pegado al final del pegado
  perform set_config('mxp.p1_alta', array_to_string(v_nuevas, ','), true);
  return jsonb_build_object('creadas', to_jsonb(v_nuevas), 'mapeo', v_mapeo);
end $$;
revoke execute on function public.fn_stripe_cuentas_alta() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_cuentas_alta() is 'p1: da de alta la 1020 (Stripe — cobros en tránsito) y la 1140 (Stripe — depósitos en camino a Chase) si faltan, y su fila de los estados (c4). MX000 si ya existen con otra forma.';

select public.fn_stripe_cuentas_alta();

-- La fila de la configuración: el dueño activo más antiguo. Al volver a
-- pegar no se pisa nada (ni desde ni el dueño).
insert into public.stripe_config (id, dueno)
select 1, p.id from public.perfiles p
 where p.rol = 'dueno' and coalesce(p.activo, true)
 order by p.creado
 limit 1
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS con una sola policy («solo el dueño lee»), nada
--    para la API salvo leer (el dueño), y el secreto de la rutina.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['stripe_config', 'stripe_eventos', 'stripe_enlaces', 'stripe_pagos', 'stripe_pago_libro', 'stripe_payouts',
                           'stripe_payout_lineas', 'stripe_avisos'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  -- las secuencias de las columnas identity (nacen con «grant all» para la API)
  execute 'revoke all on sequence public.stripe_pago_libro_id_seq, public.stripe_avisos_id_seq from public, anon, authenticated, '
          'service_role';
end $$;

-- El secreto con que la rutina se identifica ante la función de borde. Se
-- crea una vez; Edgar copia su valor (lo enseña la tabla del final) al
-- secreto STRIPE_RUTINA_SECRETO de Edge Functions. Nunca por el chat.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'stripe_rutina_secreto') then
    perform vault.create_secret(md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text), 'stripe_rutina_secreto',
                                'La rutina de Stripe (pg_cron → función de borde). El mismo valor va en STRIPE_RUTINA_SECRETO.');
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo interno (ninguna en la API; todas empiezan por fn_stripe_exigir)
-- ---------------------------------------------------------------------
create or replace function public.fn_stripe_cfg() returns public.stripe_config
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c stripe_config;
begin
  perform fn_stripe_exigir();
  select * into c from stripe_config where id = 1;
  if not found then
    raise exception using errcode = 'MX009', message = 'Falta la configuración de Stripe (stripe_config): vuelve a pegar p1-stripe.sql.';
  end if;
  return c;
end $$;
revoke execute on function public.fn_stripe_cfg() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_cfg() is 'p1: la fila de stripe_config.';

-- EN NOMBRE DEL DUEÑO (como fn_plaid_recibir, c7): guarda los claims de
-- ahora, fija auth.uid() al dueño de stripe_config SOLO dentro de esta
-- transacción y comprueba que siga siendo el dueño. fn_stripe_soltar los
-- deja como estaban. Siempre en pareja.
create or replace function public.fn_stripe_suplantar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg stripe_config;
  v   jsonb;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  v := jsonb_build_object('claims', current_setting('request.jwt.claims', true),
                          'sub', current_setting('request.jwt.claim.sub', true));
  perform set_config('request.jwt.claims', jsonb_build_object('sub', cfg.dueno, 'role', 'authenticated', 'stripe', true)::text, true);
  perform set_config('request.jwt.claim.sub', cfg.dueno::text, true);
  if not es_dueno() then
    raise exception using errcode = '42501',
      message = 'El dueño en nombre del cual registra Stripe (stripe_config.dueno) ya no es el dueño: no se registra nada. Entra a '
                'Cobros en línea como dueño para fijarlo.';
  end if;
  return v;
end $$;
revoke execute on function public.fn_stripe_suplantar() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_suplantar() is 'p1: fija auth.uid() al dueño de stripe_config dentro de la transacción (request.jwt.claims y claim.sub) y devuelve los de antes para fn_stripe_soltar.';

create or replace function public.fn_stripe_soltar(p jsonb) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  perform set_config('request.jwt.claims', coalesce(p->>'claims', ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(p->>'sub', ''), true);
end $$;
revoke execute on function public.fn_stripe_soltar(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_soltar(jsonb) is 'p1: deja request.jwt.claims y claim.sub como estaban antes de fn_stripe_suplantar.';

-- El dueño de la sesión que pide algo por la función de borde pasa a ser
-- el de la configuración (si es el dueño activo).
create or replace function public.fn_stripe_dueno_fijar(p_dueno uuid) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  if p_dueno is null or not exists (select 1 from perfiles p where p.id = p_dueno and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501', message = 'Solo el dueño maneja los cobros en línea.';
  end if;
  update stripe_config set dueno = p_dueno, actualizado = now() where id = 1 and dueno is distinct from p_dueno;
end $$;
revoke execute on function public.fn_stripe_dueno_fijar(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_dueno_fijar(uuid) is 'p1: el dueño activo que pide algo por la función pasa a ser en nombre de quien registra Stripe; otro, 42501.';

-- Un aviso para Edgar (uno por clave: el repetido suma «veces»; si sube a
-- 'bad' se vuelve a abrir). Uno NUEVO y grave sale también al teléfono por
-- fn_cartero (si existe; nunca con mxp.stripe_sin_push = '1', las pruebas).
create or replace function public.fn_stripe_avisar(p_clave text, p_nivel text, p_texto text, p_objeto text default null) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_nuevo boolean;
  v_dueno uuid;
begin
  perform fn_stripe_exigir();
  if coalesce(btrim(p_clave), '') = '' or coalesce(btrim(p_texto), '') = '' or p_nivel is null or p_nivel not in ('info', 'warn', 'bad') then
    raise exception using errcode = '22023', message = 'Un aviso lleva clave, nivel (info, warn o bad) y texto.';
  end if;
  insert into stripe_avisos as a (clave, nivel, texto, objeto)
  values (p_clave, p_nivel, left(p_texto, 2000), p_objeto)
  on conflict (clave) do update
     set texto       = excluded.texto,
         nivel       = case when 'bad' in (a.nivel, excluded.nivel) then 'bad'
                            when 'warn' in (a.nivel, excluded.nivel) then 'warn' else 'info' end,
         objeto      = coalesce(excluded.objeto, a.objeto),
         repetido_el = now(),
         veces       = a.veces + 1,
         visto_el    = case when excluded.nivel = 'bad' and a.nivel <> 'bad' then null else a.visto_el end,
         visto_por   = case when excluded.nivel = 'bad' and a.nivel <> 'bad' then null else a.visto_por end
  returning (a.xmax = 0) into v_nuevo;
  if v_nuevo and p_nivel = 'bad' and to_regprocedure('public.fn_cartero(jsonb)') is not null
     and coalesce(current_setting('mxp.stripe_sin_push', true), '') <> '1' then
    select dueno into v_dueno from stripe_config where id = 1;
    begin
      perform fn_cartero(jsonb_build_object('titulo', 'Stripe: ' || left(p_texto, 60), 'cuerpo', p_texto, 'para', v_dueno));
    exception when others then
      raise warning 'fn_stripe_avisar: el aviso al teléfono no salió (%): %', sqlstate, sqlerrm;
    end;
  end if;
end $$;
revoke execute on function public.fn_stripe_avisar(text, text, text, text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_avisar(text, text, text, text) is 'p1: un aviso para Edgar (stripe_avisos); uno nuevo y grave también al teléfono (fn_cartero).';

-- Centavos de Stripe (un entero) → dólares.
create or replace function public.fn_stripe_dinero(p jsonb) returns numeric
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  if p is not null and ((jsonb_typeof(p) = 'number' and p::text ~ '^-?[0-9]+$')
                        or (jsonb_typeof(p) = 'string' and p #>> '{}' ~ '^-?[0-9]{1,15}$')) then
    return round((p #>> '{}')::numeric / 100, 2)::numeric(14,2);
  end if;
  raise exception using errcode = '22023',
    message = format('Un monto de Stripe va en centavos, como entero (llegó «%s»).', coalesce(p::text, 'nada'));
end $$;
revoke execute on function public.fn_stripe_dinero(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_dinero(jsonb) is 'p1: centavos de Stripe (entero JSON) → dólares numeric(14,2).';

-- Un instante de Stripe (unix en segundos) o un texto ISO → timestamptz.
create or replace function public.fn_stripe_instante(p jsonb) returns timestamptz
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  if p is null or jsonb_typeof(p) = 'null' then return null; end if;
  if (jsonb_typeof(p) = 'number' and p::text ~ '^[0-9]+$') or (jsonb_typeof(p) = 'string' and p #>> '{}' ~ '^[0-9]{9,11}$') then
    return to_timestamp((p #>> '{}')::bigint);
  end if;
  if jsonb_typeof(p) = 'string' and p #>> '{}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
    begin
      return (p #>> '{}')::timestamptz;
    exception when others then
      null;
    end;
  end if;
  raise exception using errcode = '22023', message = format('«%s» no es un instante (unix o ISO).', p::text);
end $$;
revoke execute on function public.fn_stripe_instante(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_instante(jsonb) is 'p1: un instante de Stripe (unix en segundos, o ISO) → timestamptz.';

-- El día en Miami de un instante de Stripe (o un 'AAAA-MM-DD' tal cual).
create or replace function public.fn_stripe_dia(p jsonb) returns date
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  if p is null or jsonb_typeof(p) = 'null' then return null; end if;
  if jsonb_typeof(p) = 'string' and p #>> '{}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return (p #>> '{}')::date;
  end if;
  return fn_fecha_miami(fn_stripe_instante(p));
end $$;
revoke execute on function public.fn_stripe_dia(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_dia(jsonb) is 'p1: el día en Miami de un instante de Stripe (un AAAA-MM-DD, tal cual).';

-- La fecha de llegada de un depósito: Stripe la da en UTC (medianoche):
-- 'AAAA-MM-DD' tal cual, o unix → el día UTC.
create or replace function public.fn_stripe_dia_utc(p jsonb) returns date
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  if p is null or jsonb_typeof(p) = 'null' then return null; end if;
  if jsonb_typeof(p) = 'string' and p #>> '{}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return (p #>> '{}')::date;
  end if;
  return (fn_stripe_instante(p) at time zone 'UTC')::date;
end $$;
revoke execute on function public.fn_stripe_dia_utc(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_dia_utc(jsonb) is 'p1: la fecha UTC de un instante de Stripe (la llegada de un depósito).';

-- Dinero en texto para los avisos: $1,234.50.
create or replace function public.fn_stripe_usd(p numeric) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  return case when p is null then '$?'
              when p < 0 then '−$' || to_char(abs(p), 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end;
end $$;
revoke execute on function public.fn_stripe_usd(numeric) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_usd(numeric) is 'p1: dinero en texto para los avisos ($1,234.50).';

-- Lo que NO se guarda de Stripe: datos personales y de la cuenta del
-- pagador, en todo el árbol.
create or replace function public.fn_stripe_sin_datos(p jsonb) returns jsonb
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  c_fuera constant text[] := array['address', 'phone', 'email', 'receipt_email', 'shipping', 'tax_ids', 'ip_address', 'fingerprint',
                                   'routing_number', 'last4', 'customer_details', 'billing_details'];
  v jsonb;
begin
  perform fn_stripe_exigir();
  if p is null then return null; end if;
  if jsonb_typeof(p) = 'object' then
    select coalesce(jsonb_object_agg(e.key, fn_stripe_sin_datos(e.value)), '{}'::jsonb) into v
      from jsonb_each(p) e
     where e.key <> all (c_fuera);
    return v;
  elsif jsonb_typeof(p) = 'array' then
    select coalesce(jsonb_agg(fn_stripe_sin_datos(x.v) order by x.n), '[]'::jsonb) into v
      from jsonb_array_elements(p) with ordinality as x(v, n);
    return v;
  end if;
  return p;
end $$;
revoke execute on function public.fn_stripe_sin_datos(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_sin_datos(jsonb) is 'p1: quita del árbol los datos personales y de cuenta del pagador (correo, teléfono, dirección, últimos 4, …).';

-- Lo que una factura debe en el LIBRO (no la casilla «pagada»).
create or replace function public.fn_stripe_saldo(p_factura bigint) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_cxc  text := fn_puente_cuenta_de('cxc');
  v_ret  text := fn_puente_cuenta_de('retencion_cxc');
  v_s1   numeric;
  v_s2   numeric;
  v_n    bigint;
begin
  perform fn_stripe_exigir();
  select coalesce(sum(l.monto) filter (where l.cuenta = v_cxc), 0), coalesce(sum(l.monto) filter (where l.cuenta = v_ret), 0), count(*)
    into v_s1, v_s2, v_n
    from asiento_lineas l
   where l.partida_tabla = 'facturas' and l.partida_id = p_factura::text and l.cuenta in (v_cxc, v_ret);
  return jsonb_build_object('saldo_cxc', v_s1, 'saldo_retencion', v_s2, 'lineas', v_n);
end $$;
revoke execute on function public.fn_stripe_saldo(bigint) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_saldo(bigint) is 'p1: lo que una factura debe en el libro: su partida en la cuenta por cobrar y en la retención (puente_cuentas).';

-- EL REPARTO de un cobro de Stripe: primero lo que la factura debe en
-- 1110 (su parte normal), después su retención (1120, es_retencion), y lo
-- que sobre, de anticipo de su obra. Montos en texto de dos decimales.
create or replace function public.fn_stripe_reparto(p_factura bigint, p_monto numeric) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  f      facturas;
  v_s    jsonb;
  v_a1   numeric(14,2);
  v_a2   numeric(14,2);
  v_ant  numeric(14,2);
  v_apps jsonb := '[]'::jsonb;
begin
  perform fn_stripe_exigir();
  select * into f from facturas where id = p_factura;
  if not found then
    raise exception using errcode = '22023', message = format('No existe la factura %s.', p_factura);
  end if;
  if p_monto is null or p_monto <= 0 then
    raise exception using errcode = '22023', message = 'El reparto es de un monto positivo.';
  end if;
  v_s   := fn_stripe_saldo(p_factura);
  v_a1  := least(p_monto, greatest((v_s->>'saldo_cxc')::numeric, 0));
  v_a2  := least(p_monto - v_a1, greatest((v_s->>'saldo_retencion')::numeric, 0));
  v_ant := p_monto - v_a1 - v_a2;
  if v_a1 > 0 then
    v_apps := v_apps || jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', v_a1::text));
  end if;
  if v_a2 > 0 then
    v_apps := v_apps || jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', v_a2::text, 'es_retencion', true));
  end if;
  if v_ant > 0 and f.proyecto_id is not null then
    v_apps := v_apps || jsonb_build_array(jsonb_build_object('proyecto_id', f.proyecto_id, 'monto', v_ant::text));
  end if;
  return jsonb_strip_nulls(jsonb_build_object('aplicaciones', v_apps, 'a_factura', v_a1, 'a_retencion', v_a2, 'anticipo', v_ant,
                                              'proyecto_id', f.proyecto_id,
                                              'sin_obra', case when v_ant > 0 and f.proyecto_id is null then true end));
end $$;
revoke execute on function public.fn_stripe_reparto(bigint, numeric) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_reparto(bigint, numeric) is 'p1: reparte un cobro de Stripe: 1110 hasta lo que debe la factura, después su retención (1120), y el resto de anticipo de su obra.';

-- La fecha de un asiento que toca la 1010: nunca dentro de una
-- conciliación confirmada de la 1010 (c6, cuadre 54): al día siguiente de
-- su corte, si cae antes.
create or replace function public.fn_stripe_fecha_banco(p_fecha date) returns date
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg stripe_config;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  return greatest(p_fecha, (select max(c.fecha_corte) + 1 from conciliaciones c
                             where c.cuenta = cfg.cuenta_banco and c.estado = 'confirmada' and c.tipo = 'normal'));
end $$;
revoke execute on function public.fn_stripe_fecha_banco(date) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_fecha_banco(date) is 'p1: la fecha, o el día siguiente al corte de la última conciliación confirmada de la cuenta del banco si cae antes.';

-- ¿Puede una línea de Stripe de «fuera» de la app (o una que Stripe trae y
-- la app no conoce) ir a esta cuenta? Un ingreso, un gasto, un costo o un
-- pasivo, sin obra obligatoria; nunca un banco o una tarjeta, la cuenta
-- por cobrar, la puente ni la de paso.
create or replace function public.fn_stripe_cuenta_libre(p_cuenta text) returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg stripe_config;
  c   cuentas;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  select * into c from cuentas where codigo = btrim(coalesce(p_cuenta, ''));
  if not found then
    raise exception using errcode = 'MX004', message = format('La cuenta %s no existe.', coalesce(p_cuenta, '(ninguna)'));
  end if;
  if not c.activa or not c.imputable then
    raise exception using errcode = 'MX004', message = format('La cuenta %s (%s) está inactiva o es de grupo.', c.codigo, c.nombre);
  end if;
  if c.codigo in (cfg.cuenta_puente, cfg.cuenta_paso) then
    raise exception using errcode = 'MX004', message = format('La cuenta %s es la de Stripe (puente o de paso): no.', c.codigo);
  end if;
  if fn_banco_tipo_cuenta(c.codigo) is not null or left(c.codigo, 2) = '10' then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s (%s) es un banco o una tarjeta: lo de Stripe llega a Chase con el depósito, no aquí.', c.codigo, c.nombre);
  end if;
  if c.codigo in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc')) then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s es la de cobrar a clientes: un pago a una factura se resuelve con la factura, no con la cuenta.', c.codigo);
  end if;
  if c.tipo not in ('ingreso', 'otro_ingreso', 'gasto', 'otro_gasto', 'costo', 'pasivo') then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s (%s) es de %s: va a un ingreso, un gasto, un costo o un pasivo.', c.codigo, c.nombre, c.tipo);
  end if;
  if c.regla_obra = 'obligatoria' then
    raise exception using errcode = 'MX004', message = format('La cuenta %s (%s) pide obra: elige una sin obra.', c.codigo, c.nombre);
  end if;
end $$;
revoke execute on function public.fn_stripe_cuenta_libre(text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_cuenta_libre(text) is 'p1: MX004 si la cuenta no sirve para lo de Stripe de fuera de la app (un banco, una tarjeta, cobrar a clientes, la puente, una con obra obligatoria…).';

-- LA ÚNICA PUERTA a fn_cobro_registrar (c3). El cobro entra a la puente,
-- con la referencia pi_… (el mismo pago con otra versión no es «el mismo
-- depósito» porque el anterior ya está devuelto), la llave de su versión y
-- en las notas el evento, el enlace y la llave (c3 las copia a la
-- procedencia del asiento). Si c3 no lo acepta contra la factura (anulada,
-- de fecha posterior, que no cabe…), entra entero de anticipo de su obra,
-- con aviso; si tampoco, {error} y el pago queda «por resolver». Un mes sin
-- abrir no es un error del pago: se relanza (el aviso se reintenta).
create or replace function public.fn_stripe_registrar(p_pago public.stripe_pagos, p_monto numeric, p_fecha date, p_llave text,
                                                      p_evento text, p_nota text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg      stripe_config;
  v_rep    jsonb;
  v_apps   jsonb;
  v_obra   text;
  v_fnum   text;
  v_cobro  jsonb;
  v_r      jsonb;
  v_err    text;
  v_cod    text;
  v_ant    numeric(14,2) := 0;
  v_resto  numeric(14,2);
  v_fact   facturas;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  if p_monto is null or p_monto <= 0 or p_fecha is null or coalesce(btrim(p_llave), '') = '' then
    raise exception using errcode = '22023', message = 'Registrar un cobro de Stripe lleva monto, fecha y llave.';
  end if;
  if p_pago.factura_id is not null then
    select * into v_fact from facturas where id = p_pago.factura_id;
  end if;
  v_fnum := coalesce(v_fact.num, p_pago.factura_num, '?');
  if coalesce(p_pago.resuelto ? 'proyecto_id', false) then
    v_obra := p_pago.resuelto->>'proyecto_id';
    v_apps := jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', p_monto::numeric(14,2)::text));
    v_ant  := p_monto;
  elsif p_pago.factura_id is null then
    return jsonb_build_object('error', 'el pago no dice a qué factura va', 'codigo', '22023');
  elsif v_fact.estado = 'anulada' then
    -- (su saldo ya es 0: sin esto entraría de anticipo sin decir por qué)
    v_obra := v_fact.proyecto_id;
    v_err  := format('La factura #%s está anulada: no se le cobra.', v_fact.num);
    v_cod  := 'MX008';
  else
    v_rep  := fn_stripe_reparto(p_pago.factura_id, p_monto);
    v_obra := v_rep->>'proyecto_id';
    if coalesce((v_rep->>'sin_obra')::boolean, false) then
      return jsonb_build_object('error', format('la factura #%s no tiene obra y el pago (%s) es más de lo que debe (%s): lo que sobra no '
                                                'puede quedar de anticipo', v_fnum, fn_stripe_usd(p_monto),
                                                fn_stripe_usd((v_rep->>'a_factura')::numeric + (v_rep->>'a_retencion')::numeric)),
                                'codigo', '22023');
    end if;
    v_apps := v_rep->'aplicaciones';
    v_ant  := (v_rep->>'anticipo')::numeric;
  end if;
  v_cobro := jsonb_build_object(
    'fecha', p_fecha::text, 'monto', p_monto::numeric(14,2)::text, 'cuenta', cfg.cuenta_puente,
    'medio', case p_pago.medio when 'ach' then 'ach' when 'tarjeta' then 'tarjeta' else 'otro' end,
    'referencia', p_pago.pi,
    'notas', format('Stripe · %s · %s · %s%s', coalesce(p_evento, 'sin evento'), coalesce(p_pago.plink, 'sin enlace'), p_llave,
                    coalesce(p_nota, '')),
    'llave_cliente', p_llave,
    'aplicaciones', coalesce(v_apps, '[]'::jsonb));
  if v_apps is not null then
    begin
      v_r := fn_cobro_registrar(v_cobro);
    exception when sqlstate 'MX008' or sqlstate 'MX002' or sqlstate 'MX006' or sqlstate '22023' then
      if sqlerrm ~* 'no se abri' then
        raise;
      end if;
      v_err := sqlerrm;
      v_cod := sqlstate;
    end;
  end if;
  if v_r is null then
    -- Entero de anticipo de la obra de la factura (si tiene; si Edgar ya
    -- dijo la obra, no hay otro intento).
    if v_obra is null or coalesce(p_pago.resuelto ? 'proyecto_id', false) then
      return jsonb_build_object('error', v_err, 'codigo', v_cod);
    end if;
    begin
      v_r := fn_cobro_registrar(v_cobro || jsonb_build_object(
               'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', p_monto::numeric(14,2)::text)),
               'notas', (v_cobro->>'notas') || ' · todo de anticipo: ' || left(v_err, 300)));
    exception when sqlstate 'MX008' or sqlstate 'MX002' or sqlstate 'MX006' or sqlstate '22023' then
      if sqlerrm ~* 'no se abri' then
        raise;
      end if;
      return jsonb_build_object('error', v_err || ' · y de anticipo de la obra tampoco entró: ' || sqlerrm, 'codigo', sqlstate);
    end;
    v_ant := p_monto;
    perform fn_stripe_avisar('sobra:' || p_pago.pi, 'warn',
      format('La factura #%s no aceptó el pago de Stripe (%s): quedó de anticipo de la obra %s. Aplícalo (fn_anticipo_aplicar) o devuélvelo '
             'desde Stripe.', v_fnum, v_err, v_obra), p_pago.pi);
  elsif v_ant > 0 and not coalesce(p_pago.resuelto ? 'proyecto_id', false) then
    v_resto := p_monto - v_ant;
    perform fn_stripe_avisar('sobra:' || p_pago.pi, 'warn',
      format('El cliente pagó %s por la #%s y el libro le cobraba %s: %s quedó de anticipo de la obra (¿pagó dos veces, o por cheque o '
             'Zelle?). Devuélvelo desde Stripe o aplícalo a otra factura.', fn_stripe_usd(p_monto), v_fnum, fn_stripe_usd(v_resto),
             fn_stripe_usd(v_ant)), p_pago.pi);
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'cobro', v_r->>'cobro', 'asiento', v_r->>'asiento',
    'asiento_id', (select c.contabilizado_en from cobros c where c.id = (v_r->>'cobro')::uuid),
    'fecha_contable', v_r->>'fecha_contable', 'tardio', v_r->>'tardio', 'anticipo', v_ant, 'ya_estaba', v_r->'ya_estaba',
    'error_factura', v_err));
end $$;
revoke execute on function public.fn_stripe_registrar(public.stripe_pagos, numeric, date, text, text, text)
  from public, anon, authenticated, service_role;
comment on function public.fn_stripe_registrar(public.stripe_pagos, numeric, date, text, text, text) is 'p1: la única puerta a fn_cobro_registrar (c3): el cobro de Stripe a la puente, contra su factura (o de anticipo de su obra si c3 no lo acepta), con su llave y su rastro.';


-- ---------------------------------------------------------------------
-- 5. Los avisos de Stripe (eventos): guardar primero, cerrar después
-- ---------------------------------------------------------------------
-- Guarda un aviso de Stripe (sin datos personales). p_evento = {id, tipo,
-- livemode, api_version, created, objeto, previos}. El mismo id otra vez
-- suma «veces». Un aviso de otro modo (de prueba con una llave real, o al
-- revés), o de prueba en una base que no los acepta, queda «ignorado».
create or replace function public.fn_stripe_evento_guardar(p_evento jsonb, p_por text, p_modo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg     stripe_config;
  v_id    text;
  v_tipo  text;
  v_live  boolean;
  v_est   text;
  v_int   int;
  v_veces int;
  v_nuevo boolean;
begin
  perform fn_stripe_exigir();
  if p_evento is null or jsonb_typeof(p_evento) <> 'object' then
    raise exception using errcode = '22023', message = 'El aviso de Stripe llega como un objeto JSON.';
  end if;
  v_id := p_evento->>'id';
  v_tipo := nullif(btrim(coalesce(p_evento->>'tipo', '')), '');
  if v_id is null or v_id !~ '^evt_[A-Za-z0-9_]+$' or v_tipo is null or jsonb_typeof(p_evento->'livemode') is distinct from 'boolean'
     or p_evento->'created' is null or (p_evento ? 'objeto' and jsonb_typeof(p_evento->'objeto') not in ('object', 'null')) then
    raise exception using errcode = '22023', message = 'Un aviso de Stripe lleva id (evt_…), tipo, livemode, created y objeto.';
  end if;
  if p_por is null or p_por not in ('webhook', 'barrido', 'pantalla') then
    raise exception using errcode = '22023', message = 'Por dónde llegó: webhook, barrido o pantalla.';
  end if;
  if p_modo is null or p_modo not in ('prueba', 'real') then
    raise exception using errcode = '22023', message = 'El modo de la llave es prueba o real.';
  end if;
  v_live := (p_evento->>'livemode')::boolean;
  cfg := fn_stripe_cfg();
  insert into stripe_eventos as e (id, tipo, objeto_tipo, objeto_id, livemode, api_version, creado_stripe, datos, por)
  values (v_id, v_tipo, p_evento->'objeto'->>'object', p_evento->'objeto'->>'id', v_live, p_evento->>'api_version',
          fn_stripe_instante(p_evento->'created'),
          jsonb_build_object('objeto', fn_stripe_sin_datos(p_evento->'objeto'), 'previos', fn_stripe_sin_datos(p_evento->'previos')),
          p_por)
  on conflict (id) do update set veces = e.veces + 1, ultima_vez = now()
  returning e.estado, e.intentos, e.veces, (e.xmax = 0) into v_est, v_int, v_veces, v_nuevo;
  -- el modo de la llave
  if cfg.modo is null then
    update stripe_config set modo = p_modo, actualizado = now() where id = 1;
  elsif cfg.modo <> p_modo then
    update stripe_config set modo = p_modo, actualizado = now() where id = 1;
    perform fn_stripe_avisar('llave:modo', 'info', 'La llave de Stripe cambió de modo (de prueba a real o al revés).');
  end if;
  if v_nuevo and (v_live <> (p_modo = 'real') or (p_modo = 'prueba' and not cfg.acepta_prueba)) then
    update stripe_eventos set estado = 'ignorado', hecho_el = now(), resultado = jsonb_build_object('motivo', 'modo')
     where id = v_id
    returning estado into v_est;
    perform fn_stripe_avisar('modo', 'warn',
      'Llegó un aviso de Stripe en modo de prueba (o la llave es de prueba): no se registró nada.', v_id);
  end if;
  update stripe_config set ultimo_evento_el = now(), ultimo_evento_tipo = v_tipo where id = 1;
  return jsonb_build_object('nuevo', v_nuevo, 'estado', v_est, 'intentos', v_int, 'veces', v_veces);
end $$;
revoke execute on function public.fn_stripe_evento_guardar(jsonb, text, text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_evento_guardar(jsonb, text, text) is 'p1: guarda un aviso de Stripe antes de procesarlo (uno por id; el repetido suma veces); de otro modo, ignorado.';

-- Cierra un aviso: hecho, ignorado, reintentar (con espera creciente) o
-- revisar. Escala a «revisar» a los 20 intentos o a las 72 horas, y avisa
-- lo que Edgar tiene que saber (un mes sin abrir, un permiso de la llave,
-- Stripe caído).
create or replace function public.fn_stripe_evento_cerrar(p_id text, p_estado text, p_resultado jsonb default null,
                                                          p_error text default null, p_codigo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ev     stripe_eventos;
  v_estado text := p_estado;
  v_mes    text;
begin
  perform fn_stripe_exigir();
  if p_estado is null or p_estado not in ('hecho', 'ignorado', 'reintentar', 'revisar') then
    raise exception using errcode = '22023', message = 'Un aviso se cierra hecho, ignorado, reintentar o revisar.';
  end if;
  select * into v_ev from stripe_eventos where id = p_id for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el aviso de Stripe %s.', coalesce(p_id, '(ninguno)'));
  end if;
  if v_estado = 'reintentar' and (v_ev.intentos + 1 >= 20 or now() - v_ev.recibido_el > interval '72 hours') then
    v_estado := 'revisar';
    perform fn_stripe_avisar('evento:' || p_id, 'bad',
      format('El aviso de Stripe %s (%s) lleva 3 días sin poder procesarse: %s. Toca «Volver a mirar» en Cobros en línea o revisa la llave.',
             p_id, v_ev.tipo, coalesce(p_error, 'sin detalle')), p_id);
  elsif v_estado = 'revisar' and v_ev.estado <> 'revisar' then
    perform fn_stripe_avisar('evento:' || p_id, 'bad',
      format('El aviso de Stripe %s (%s) no se pudo procesar: %s. Toca «Volver a mirar» en Cobros en línea.', p_id, v_ev.tipo,
             coalesce(p_error, 'sin detalle')), p_id);
  end if;
  update stripe_eventos
     set estado          = v_estado,
         intentos        = intentos + 1,
         hecho_el        = case when v_estado in ('hecho', 'ignorado') then now() else null end,
         proximo_intento = case when v_estado = 'reintentar'
                                then now() + case when intentos + 1 <= 1 then interval '5 minutes'
                                                  when intentos + 1 = 2 then interval '15 minutes'
                                                  when intentos + 1 = 3 then interval '1 hour'
                                                  when intentos + 1 = 4 then interval '4 hours'
                                                  else interval '12 hours' end end,
         resultado       = coalesce(p_resultado, resultado),
         ultimo_error    = case when v_estado in ('hecho', 'ignorado') then null else left(p_error, 600) end,
         codigo_error    = case when v_estado in ('hecho', 'ignorado') then null else p_codigo end
   where id = p_id
  returning * into v_ev;
  if p_codigo = 'MX002' and coalesce(p_error, '') ~* 'no se abri' then
    v_mes := coalesce(substring(p_error from '([0-9]{4}-[0-9]{2})-[0-9]{2}'), to_char(fn_fecha_miami(now()), 'YYYY-MM'));
    perform fn_stripe_avisar('mes:' || v_mes, 'bad',
      format('Hay cobros de Stripe esperando a que abras el mes %s (fn_abrir_periodo). Entran solos en cuanto lo abras.', v_mes));
  elsif p_codigo = 'STRIPE_PERMISO' then
    perform fn_stripe_avisar('llave', 'bad', coalesce(p_error, 'A la llave de Stripe le falta un permiso.'));
  elsif p_codigo = 'STRIPE_CAIDO' and v_ev.intentos >= 3 then
    perform fn_stripe_avisar('stripe_caido', 'warn',
      format('Stripe no contesta desde las %s; los avisos están guardados y entran solos cuando vuelva.',
             to_char(v_ev.recibido_el at time zone 'America/New_York', 'HH24:MI')));
  end if;
  if p_error is not null and v_estado not in ('hecho', 'ignorado') then
    update stripe_config set ultimo_error = left(p_error, 600), ultimo_error_el = now() where id = 1;
  end if;
  return jsonb_build_object('id', v_ev.id, 'estado', v_ev.estado, 'intentos', v_ev.intentos, 'proximo_intento', v_ev.proximo_intento);
end $$;
revoke execute on function public.fn_stripe_evento_cerrar(text, text, jsonb, text, text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_evento_cerrar(text, text, jsonb, text, text) is 'p1: cierra un aviso de Stripe (hecho, ignorado, reintentar con espera creciente, revisar) y avisa a Edgar lo que debe saber.';

-- Lo que la rutina tiene que mirar (la función de borde lo pide al barrer).
create or replace function public.fn_stripe_pendientes(p_limite int default 50) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg        stripe_config;
  v_lim      int := greatest(coalesce(p_limite, 50), 1);
  v_completo boolean;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  v_completo := cfg.ultimo_barrido_completo_el is null or cfg.ultimo_barrido_completo_el < now() - interval '55 minutes';
  return jsonb_build_object(
    'eventos', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'tipo', e.tipo,
                                                             'created', extract(epoch from e.creado_stripe)::bigint,
                                                             'livemode', e.livemode, 'datos', e.datos) order by e.recibido_el)
                           from (select * from stripe_eventos e
                                  where (e.estado = 'recibido' and e.recibido_el < now() - interval '5 minutes')
                                     or (e.estado = 'reintentar' and coalesce(e.proximo_intento, now()) <= now())
                                  order by e.recibido_el
                                  limit v_lim) e), '[]'::jsonb),
    'pagos', coalesce((select jsonb_agg(x.pi order by x.pi)
                         from (select distinct s.pi from stripe_pagos s
                                where (s.estado in ('iniciado', 'en_camino', 'en_disputa', 'revisar')
                                       and coalesce(s.foto_al, '-infinity'::timestamptz) < now() - interval '1 hour')
                                   or (s.objetivo <> s.en_libro and s.estado <> 'revisar' and not coalesce(s.resuelto ? 'fuera', false))
                                   or (v_completo and s.actualizado_el > now() - interval '48 hours')
                                limit v_lim) x), '[]'::jsonb),
    'payouts', coalesce((select jsonb_agg(p.po order by p.llegada, p.po)
                           from stripe_payouts p
                          where p.estado in ('en_camino', 'esperando_composicion', 'esperando_cobros')
                             or (p.estado = 'asentado' and not exists (
                                   select 1 from asiento_lineas al
                                     join banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden and bcl.vigente
                                     join banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                                    where al.asiento_id = p.asiento_llegada and al.cuenta = cfg.cuenta_banco))), '[]'::jsonb),
    'casar', coalesce((select jsonb_agg(p.po order by p.llegada, p.po)
                         from stripe_payouts p
                        where p.estado = 'asentado' and p.asiento_llegada is not null
                          and not exists (select 1 from asiento_lineas al
                                            join banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden
                                                                        and bcl.vigente
                                            join banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                                           where al.asiento_id = p.asiento_llegada and al.cuenta = cfg.cuenta_banco)), '[]'::jsonb),
    'enlaces_creando', coalesce((select jsonb_agg(jsonb_build_object(
                                          'id', e.id, 'idempotencia', e.idempotencia, 'creado_el', e.creado_el,
                                          'factura_id', e.factura_id, 'factura_num', e.factura_num,
                                          'centavos', (e.monto * 100)::bigint, 'monto', e.monto, 'con_retencion', e.con_retencion,
                                          'metadata', jsonb_build_object('mxp', 'p1', 'enlace', e.id::text, 'factura_id', e.factura_id::text,
                                                                         'factura', e.factura_num,
                                                                         'retencion', case when e.con_retencion then 'si' else 'no' end))
                                        order by e.creado_el)
                                   from stripe_enlaces e
                                  where e.estado = 'creando' and e.creado_el < now() - interval '5 minutes'), '[]'::jsonb),
    'enlaces_revisar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'plink', x.plink, 'motivo', x.motivo) order by x.creado_el)
                                   from (select e.id, e.plink, e.creado_el,
                                                case when f.estado = 'anulada' then format('la factura #%s se anuló', f.num)
                                                     when exists (select 1 from stripe_pagos s
                                                                   where s.factura_id = e.factura_id and s.estado in ('iniciado', 'en_camino'))
                                                     then format('hay un pago de la #%s en camino', f.num)
                                                     when (case when e.con_retencion
                                                                then (s0.sl->>'saldo_cxc')::numeric + (s0.sl->>'saldo_retencion')::numeric
                                                                else (s0.sl->>'saldo_cxc')::numeric end) < e.monto
                                                     then format('la #%s ya debe menos que el enlace (%s)', f.num, fn_stripe_usd(e.monto)) end
                                                  as motivo
                                           from stripe_enlaces e
                                           join facturas f on f.id = e.factura_id
                                          cross join lateral (select fn_stripe_saldo(e.factura_id) as sl) s0
                                          where e.estado = 'activo') x
                                  where x.motivo is not null), '[]'::jsonb),
    'enlaces_activos', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'plink', e.plink) order by e.creado_el)
                                   from stripe_enlaces e where e.estado = 'activo'), '[]'::jsonb),
    'completo_toca', v_completo,
    'eventos_desde', extract(epoch from greatest(now() - interval '3 days',
                                                 coalesce(cfg.ultimo_barrido_completo_el, cfg.desde) - interval '1 hour'))::bigint,
    'payouts_desde', extract(epoch from greatest(cfg.desde - interval '7 days', now() - interval '35 days'))::bigint);
end $$;
revoke execute on function public.fn_stripe_pendientes(int) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_pendientes(int) is 'p1: lo que la rutina tiene que mirar: avisos por procesar, pagos y depósitos por volver a pedir, depósitos por casar y enlaces por terminar o revisar.';

create or replace function public.fn_stripe_barrido_anotar(p_resultado jsonb, p_completo boolean) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  update stripe_config
     set ultimo_barrido_el = now(), ultimo_barrido = p_resultado,
         ultimo_barrido_completo_el = case when coalesce(p_completo, false) then now() else ultimo_barrido_completo_el end
   where id = 1;
end $$;
revoke execute on function public.fn_stripe_barrido_anotar(jsonb, boolean) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_barrido_anotar(jsonb, boolean) is 'p1: anota la hora y el resumen del último barrido de la rutina.';


-- ---------------------------------------------------------------------
-- 6. Los enlaces de pago
-- ---------------------------------------------------------------------
-- Prepara el enlace de una factura (la función de borde lo crea después en
-- Stripe con esta carga y esta Idempotency-Key). Por lo que el LIBRO dice
-- que debe; nunca escribe la factura. Devuelve {accion: crear | listo |
-- desactivar}.
create or replace function public.fn_stripe_enlace_preparar(p_factura bigint, p_dueno uuid, p_modo text,
                                                            p_con_retencion boolean default false,
                                                            p_aunque_pagada boolean default false,
                                                            p_reemplazar boolean default false)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg      stripe_config;
  f        facturas;
  v_s      jsonb;
  v_cxc    numeric(14,2);
  v_ret    numeric(14,2);
  v_aviso  text;
  v_monto  numeric(14,2);
  v_pago   stripe_pagos;
  e        stripe_enlaces;
  v_id     uuid;
  v_ant    uuid;
  v_conret boolean := coalesce(p_con_retencion, false);
begin
  perform fn_stripe_exigir();
  perform fn_stripe_dueno_fijar(p_dueno);
  cfg := fn_stripe_cfg();
  if p_modo is null or p_modo not in ('prueba', 'real') then
    raise exception using errcode = '22023', message = 'El modo de la llave es prueba o real.';
  end if;
  if p_modo = 'prueba' and not cfg.acepta_prueba then
    raise exception using errcode = 'MX008', hint = 'PRUEBA',
      message = 'La función tiene una llave de prueba (rk_test_): aquí no se crean enlaces de prueba. Pon la llave real (rk_live_) en '
                'STRIPE_SECRET_KEY.';
  end if;
  if p_factura is null then
    raise exception using errcode = '22023', message = 'Di de qué factura (factura_id).';
  end if;
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.factura:' || p_factura));
  select * into f from facturas where id = p_factura;
  if not found then
    raise exception using errcode = '22023', message = format('No existe la factura %s.', p_factura);
  end if;
  if f.estado = 'anulada' then
    raise exception using errcode = 'MX008', message = format('La factura #%s está anulada: no se cobra.', f.num);
  end if;
  if f.estado = 'borrador' then
    raise exception using errcode = 'MX008', message = format('La factura #%s es un borrador: emítela antes.', f.num);
  end if;
  v_s := fn_stripe_saldo(f.id);
  v_cxc := (v_s->>'saldo_cxc')::numeric;
  v_ret := (v_s->>'saldo_retencion')::numeric;
  if f.contabilizado_en is null and (v_s->>'lineas')::int = 0 then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s todavía no está en el libro (está en la bandeja o es de antes del corte sin su apertura): '
                       'resuélvela antes.', f.num);
  end if;
  select fc.aviso into v_aviso from facturas_cobro fc where fc.id = f.id;
  if coalesce(v_aviso, '') ~* '(dos veces|más por cobrar|en negativo)' then
    raise exception using errcode = 'MX008', message = format('No se cobra hasta arreglarla: %s', v_aviso);
  end if;
  v_monto := v_cxc + case when v_conret then v_ret else 0 end;
  if v_monto <= 0 then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s no debe nada en el libro%s.', f.num,
                       case when v_ret > 0 and not v_conret
                            then format(' (tiene %s de retención: marca «Incluir la retención»)', fn_stripe_usd(v_ret)) else '' end);
  end if;
  if v_monto < 0.50 then
    raise exception using errcode = 'MX008', message = 'Stripe no cobra menos de 0.50.';
  end if;
  if v_monto > 999999.99 then
    raise exception using errcode = 'MX008', message = format('La factura #%s debe %s: un enlace de pago llega hasta 999,999.99.', f.num,
                                                              fn_stripe_usd(v_monto));
  end if;
  select * into v_pago from stripe_pagos s
   where s.factura_id = f.id and s.estado in ('iniciado', 'en_camino')
   order by s.creado_el limit 1;
  if found then
    raise exception using errcode = 'MX008',
      message = format('Ya hay un pago por cuenta de banco de %s en camino por la factura #%s (desde el %s): espera a que se confirme o '
                       'falle antes de mandar otro enlace.', fn_stripe_usd(v_pago.monto), f.num,
                       fn_fecha_miami(v_pago.creado_el));
  end if;
  if coalesce(f.pagada, false) and not coalesce(p_aunque_pagada, false) then
    raise exception using errcode = 'MX008', hint = 'pagada_en_app',
      message = format('La casilla dice que la #%s está pagada (QuickBooks), pero el libro dice que debe %s. Si el cliente ya pagó por otro '
                       'lado, no mandes el enlace; si de verdad la debe, confírmalo.', f.num, fn_stripe_usd(v_monto));
  end if;
  -- El enlace vivo de la factura, si lo hay.
  select * into e from stripe_enlaces x where x.factura_id = f.id and x.estado in ('creando', 'activo') for update;
  if found and e.estado = 'creando' and e.creado_el >= now() - interval '23 hours' then
    return jsonb_build_object(
      'accion', 'crear', 'reanudar', true, 'enlace', e.id, 'idempotencia', e.idempotencia, 'centavos', (e.monto * 100)::bigint,
      'monto', e.monto, 'factura_id', e.factura_id, 'factura_num', e.factura_num, 'proyecto_id', e.proyecto_id,
      'con_retencion', e.con_retencion,
      'metadata', jsonb_build_object('mxp', 'p1', 'enlace', e.id::text, 'factura_id', e.factura_id::text, 'factura', e.factura_num,
                                     'retencion', case when e.con_retencion then 'si' else 'no' end));
  elsif found and e.estado = 'creando' then
    update stripe_enlaces set estado = 'fallido', error = 'se quedó a medias (más de 23 horas creándose)' where id = e.id;
  elsif found and e.estado = 'activo' and not coalesce(p_reemplazar, false) then
    return jsonb_build_object(
      'accion', 'listo',
      'enlace', jsonb_build_object('id', e.id, 'url', e.url, 'monto', e.monto, 'con_retencion', e.con_retencion, 'creado_el', e.creado_el,
                                   'plink', e.plink),
      'desfasado', e.monto <> v_monto or e.con_retencion <> v_conret);
  elsif found and e.estado = 'activo' then
    return jsonb_build_object(
      'accion', 'desactivar', 'enlace', e.id, 'plink', e.plink, 'motivo', 'reemplazado por uno nuevo');
  end if;
  -- Uno nuevo.
  select x.id into v_ant from stripe_enlaces x
   where x.factura_id = f.id and x.estado = 'desactivado' and x.desactivado_motivo = 'reemplazado por uno nuevo'
     and not exists (select 1 from stripe_enlaces y where y.reemplaza_a = x.id)
   order by x.desactivado_el desc nulls last limit 1;
  v_id := gen_random_uuid();
  insert into stripe_enlaces (id, factura_id, factura_num, proyecto_id, monto, con_retencion, saldo_cxc, saldo_retencion, estado,
                              idempotencia, creado_por, reemplaza_a)
  values (v_id, f.id, f.num, f.proyecto_id, v_monto, v_conret, v_cxc, v_ret, 'creando', 'mxp-enlace-' || v_id, p_dueno, v_ant);
  return jsonb_build_object(
    'accion', 'crear', 'enlace', v_id, 'idempotencia', 'mxp-enlace-' || v_id, 'centavos', (v_monto * 100)::bigint, 'monto', v_monto,
    'factura_id', f.id, 'factura_num', f.num, 'proyecto_id', f.proyecto_id, 'con_retencion', v_conret,
    'metadata', jsonb_build_object('mxp', 'p1', 'enlace', v_id::text, 'factura_id', f.id::text, 'factura', f.num,
                                   'retencion', case when v_conret then 'si' else 'no' end));
end $$;
revoke execute on function public.fn_stripe_enlace_preparar(bigint, uuid, text, boolean, boolean, boolean)
  from public, anon, authenticated, service_role;
comment on function public.fn_stripe_enlace_preparar(bigint, uuid, text, boolean, boolean, boolean) is 'p1: prepara el enlace de pago de una factura por lo que debe en el libro (crear, listo o desactivar el de ahora); nunca escribe la factura.';

-- Stripe ya creó el enlace: queda activo con su plink y su url.
create or replace function public.fn_stripe_enlace_creado(p_enlace uuid, p_link jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg     stripe_config;
  e       stripe_enlaces;
  v_plink text := p_link->>'id';
  v_url   text := p_link->>'url';
  v_modo  text;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  if p_link is null or jsonb_typeof(p_link) <> 'object' or v_plink is null or v_plink !~ '^plink_[A-Za-z0-9_]+$' then
    raise exception using errcode = '22023', message = 'Stripe devolvió un enlace sin su id (plink_…).';
  end if;
  if v_url is null or not (v_url ~ '^https://' or (cfg.acepta_prueba and v_url ~ '^http://')) then
    raise exception using errcode = '22023', message = format('La dirección del enlace de Stripe no es https (%s).', coalesce(v_url, 'ninguna'));
  end if;
  if p_link->'metadata'->>'enlace' is distinct from p_enlace::text then
    raise exception using errcode = '22023', message = 'Stripe devolvió un enlace que no es este (sus metadatos dicen otro).';
  end if;
  select * into e from stripe_enlaces where id = p_enlace for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese enlace.';
  end if;
  if exists (select 1 from stripe_enlaces x where x.plink = v_plink and x.id <> p_enlace) then
    raise exception using errcode = 'MX008', message = format('El enlace de Stripe %s ya es de otro enlace de la app.', v_plink);
  end if;
  if e.estado = 'activo' and e.plink = v_plink then
    return (select to_jsonb(v) from v_stripe_facturas v where v.factura_id = e.factura_id);
  end if;
  if e.estado not in ('creando', 'fallido') then
    raise exception using errcode = 'MX008', message = format('Ese enlace ya no se está creando (está %s).', e.estado);
  end if;
  v_modo := case when p_link->>'livemode' = 'true' then 'real' when p_link->>'livemode' = 'false' then 'prueba' else cfg.modo end;
  begin
    update stripe_enlaces
       set estado = 'activo', plink = v_plink, url = v_url, modo = v_modo, activo_el = now(), error = null
     where id = e.id;
  exception when unique_violation then
    raise exception using errcode = 'MX008', message = format('La factura #%s ya tiene otro enlace vivo.', e.factura_num);
  end;
  return (select to_jsonb(v) from v_stripe_facturas v where v.factura_id = e.factura_id);
end $$;
revoke execute on function public.fn_stripe_enlace_creado(uuid, jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_enlace_creado(uuid, jsonb) is 'p1: Stripe creó el enlace: queda activo con su plink y su url (devuelve la fila de v_stripe_facturas).';

create or replace function public.fn_stripe_enlace_fallo(p_enlace uuid, p_error text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e stripe_enlaces;
begin
  perform fn_stripe_exigir();
  update stripe_enlaces set estado = 'fallido', error = left(coalesce(p_error, 'Stripe no lo creó'), 600)
   where id = p_enlace and estado = 'creando'
  returning * into e;
  if not found then
    select * into e from stripe_enlaces where id = p_enlace;
    if not found then
      raise exception using errcode = '22023', message = 'No existe ese enlace.';
    end if;
  end if;
  return to_jsonb(e);
end $$;
revoke execute on function public.fn_stripe_enlace_fallo(uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_enlace_fallo(uuid, text) is 'p1: Stripe no creó el enlace: queda fallido con el error.';

-- Un enlace que ya no sirve (desactivado en la pantalla, por la rutina, en
-- Stripe, o usado: el cliente completó el pago).
create or replace function public.fn_stripe_enlace_desactivado(p_plink text, p_motivo text, p_por text, p_usado boolean default false)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e stripe_enlaces;
begin
  perform fn_stripe_exigir();
  if p_por is null or p_por not in ('pantalla', 'rutina', 'stripe', 'p1') then
    raise exception using errcode = '22023', message = 'Quién lo desactiva: pantalla, rutina, stripe o p1.';
  end if;
  select * into e from stripe_enlaces where plink = p_plink for update;
  if not found then
    return jsonb_build_object('ignorado', true, 'plink', p_plink);
  end if;
  if e.estado <> 'activo' then
    return to_jsonb(e) || jsonb_build_object('ya', true);
  end if;
  if coalesce(p_usado, false) then
    update stripe_enlaces set estado = 'usado', usado_el = coalesce(usado_el, now()) where id = e.id returning * into e;
  else
    update stripe_enlaces
       set estado = 'desactivado', desactivado_el = now(), desactivado_motivo = coalesce(nullif(btrim(p_motivo), ''), 'desactivado'),
           desactivado_por = p_por
     where id = e.id
    returning * into e;
    if p_por = 'rutina' then
      perform fn_stripe_avisar('enlace:' || e.id, 'warn',
        format('Desactivé el enlace de la #%s: %s. Si el cliente todavía debe, crea uno nuevo.', e.factura_num,
               coalesce(nullif(btrim(p_motivo), ''), 'ya no servía')), e.plink);
    end if;
  end if;
  return to_jsonb(e);
end $$;
revoke execute on function public.fn_stripe_enlace_desactivado(text, text, text, boolean) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_enlace_desactivado(text, text, text, boolean) is 'p1: un enlace activo pasa a desactivado (con su motivo y quién) o usado; uno que la app no conoce se ignora.';

create or replace function public.fn_stripe_enlace(p_enlace uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  e stripe_enlaces;
begin
  perform fn_stripe_exigir();
  select * into e from stripe_enlaces where id = p_enlace;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese enlace.';
  end if;
  if e.estado <> 'activo' then
    raise exception using errcode = 'MX008', message = 'Ese enlace ya no está activo.';
  end if;
  return to_jsonb(e);
end $$;
revoke execute on function public.fn_stripe_enlace(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_enlace(uuid) is 'p1: un enlace activo (MX008 si ya no lo está).';


-- ---------------------------------------------------------------------
-- 7. EL CORAZÓN: un pago de Stripe, al libro
-- ---------------------------------------------------------------------
-- p_foto: lo que la función de borde acaba de pedir a Stripe (centavos):
--   {"pi","visto_el","estado","monto","recibido","moneda","livemode","creado",
--    "metadata":{"mxp","enlace","factura_id","factura"},"plink","sesion",
--    "sesion_completa","medio":"tarjeta|ach|otro","cargo","fecha_exito",
--    "cargos":[{"id","estado","medio","bt","bt_fallo","creado","monto","disputado","disponible"}],
--    "reembolsos":[{"id","monto","estado","creado","bt","bt_fallo","motivo_fallo"}],
--    "disputas":[{"id","monto","estado","motivo","vence","bts":[{"id","categoria","monto","comision","creado"}]}],
--    "ultimo_error":{"codigo","mensaje"}|null,"cancelacion":…}
-- visto_el es la hora tomada ANTES de pedirlo: una foto más vieja que la
-- guardada no toca nada. Lo que debe haber en el libro (objetivo, D4): si
-- el pago se cobró, lo recibido menos lo reembolsado (con su balance
-- transaction, sin fallo), menos lo que las disputas retiraron, más lo que
-- reintegraron; si no, 0. Si el libro dice otra cosa: se devuelve el cobro
-- vivo entero y se registra uno nuevo por el objetivo, las dos cosas o
-- ninguna.
create or replace function public.fn_stripe_pago_sincronizar(p_foto jsonb, p_evento text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg           stripe_config;
  v_hoy         date := fn_fecha_miami(now());
  v_pi          text;
  v_visto       timestamptz;
  v_row         stripe_pagos;
  v_hay         boolean;
  v_antes       text;
  v_foto_antes  jsonb;
  v_modo        text;
  v_live        boolean;
  v_est         text;
  v_monto       numeric(14,2);
  v_recibido    numeric(14,2);
  v_moneda      text;
  v_creado      timestamptz;
  v_medio       text;
  v_cargo       text;
  v_meta        jsonb;
  v_enlace      stripe_enlaces;
  v_meta_fid    bigint;
  v_fid         bigint;
  v_fnum        text;
  v_obra        text;
  v_res         jsonb;
  v_fuera       boolean;
  v_revisar     text;
  v_r           numeric(14,2);
  v_r_dia       date;
  v_r_fallo     boolean;
  v_w           numeric(14,2);
  v_rn          numeric(14,2);
  v_d_dia       date;
  v_neto        numeric(14,2);
  v_objetivo    numeric(14,2);
  v_fcambio     date;
  v_fexito      date;
  v_bts         jsonb;
  v_disp        jsonb;
  v_abierta     boolean;
  v_s           jsonb;
  v_cobro       cobros;
  v_dev         jsonb;
  v_reg         jsonb;
  v_err         text;
  v_version     int;
  v_llave       text;
  v_fecha       date;
  v_motivo      text;
  v_cambios     jsonb := '[]'::jsonb;
  v_avisos      text[] := '{}';
  v_estado      text;
  v_fallo       text;
  v_cobro_nuevo uuid;
  v_libro_ok    boolean := true;
  v_libro_err   text;
  v_tardio      text;
  v_x           record;
  v_txt         text;
  v_antes_r     numeric(14,2);
  v_antes_w     numeric(14,2);
  c_uuid        constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  -- a) la forma, el candado del pago y la foto vieja
  if p_foto is null or jsonb_typeof(p_foto) <> 'object' then
    raise exception using errcode = '22023', message = 'La foto del pago llega como un objeto JSON.';
  end if;
  v_pi := p_foto->>'pi';
  if v_pi is null or v_pi !~ '^pi_[A-Za-z0-9_]+$' then
    raise exception using errcode = '22023', message = format('«%s» no es un pago de Stripe (pi_…).', coalesce(v_pi, ''));
  end if;
  begin
    v_visto := (p_foto->>'visto_el')::timestamptz;
  exception when others then
    v_visto := null;
  end;
  if v_visto is null then
    raise exception using errcode = '22023', message = 'La foto del pago dice cuándo se pidió a Stripe (visto_el).';
  end if;
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.pago:' || v_pi));
  select * into v_row from stripe_pagos where pi = v_pi for update;
  v_hay := found;
  if v_hay and v_row.foto_al > v_visto then
    return jsonb_build_object('viejo', true, 'pago', (select to_jsonb(v) from v_stripe_pagos v where v.pi = v_pi),
                              'estado', v_row.estado);
  end if;
  v_antes := v_row.estado;
  v_foto_antes := v_row.foto;
  v_antes_r := coalesce(v_row.reembolsado, 0);
  v_antes_w := coalesce((v_foto_antes->>'_w')::numeric, 0);

  -- b) el modo: los objetos que la llave lee son de su modo
  v_live := coalesce((p_foto->>'livemode')::boolean, cfg.modo = 'real');
  v_modo := coalesce(cfg.modo, case when v_live then 'real' else 'prueba' end);
  if v_live <> (v_modo = 'real') or (v_modo = 'prueba' and not cfg.acepta_prueba) then
    return jsonb_build_object('ignorado', 'modo', 'pi', v_pi);
  end if;

  v_est      := coalesce(p_foto->>'estado', '?');
  v_monto    := fn_stripe_dinero(coalesce(p_foto->'monto', '0'::jsonb));
  v_recibido := fn_stripe_dinero(coalesce(p_foto->'recibido', '0'::jsonb));
  v_moneda   := lower(coalesce(p_foto->>'moneda', 'usd'));
  v_creado   := fn_stripe_instante(p_foto->'creado');
  v_meta     := coalesce(p_foto->'metadata', '{}'::jsonb);
  v_medio    := coalesce(p_foto->>'medio',
                         (select x->>'medio' from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) with ordinality t(x, n)
                           order by t.n desc limit 1), 'otro');
  if v_medio not in ('tarjeta', 'ach', 'otro') then
    v_medio := 'otro';
  end if;
  v_cargo    := coalesce(p_foto->>'cargo',
                         (select x->>'id' from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) with ordinality t(x, n)
                           order by t.n desc limit 1));

  -- c) un intento fallido dentro de la página de pago (una tarjeta
  --    rechazada) no es un pago
  if not v_hay and v_est in ('requires_payment_method', 'canceled')
     and not exists (select 1 from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) x
                      where x->>'medio' = 'ach' and x->>'estado' = 'failed') then
    return jsonb_build_object('ignorado', 'intento en la página de pago', 'pi', v_pi);
  end if;

  -- d) a qué factura va
  v_res := v_row.resuelto;
  v_fuera := coalesce(v_res ? 'fuera', false);
  if p_foto->>'plink' is not null then
    select * into v_enlace from stripe_enlaces where plink = p_foto->>'plink';
  end if;
  if v_enlace.id is null and v_row.enlace_id is not null then
    select * into v_enlace from stripe_enlaces where id = v_row.enlace_id;
  end if;
  if v_enlace.id is null and v_meta->>'mxp' = 'p1' and coalesce(v_meta->>'enlace', '') ~ c_uuid then
    select * into v_enlace from stripe_enlaces where id = (v_meta->>'enlace')::uuid;
  end if;
  if coalesce(v_meta->>'factura_id', '') ~ '^-?[0-9]{1,18}$' then
    select f.id into v_meta_fid from facturas f where f.id = (v_meta->>'factura_id')::bigint;
  end if;
  v_revisar := null;
  if v_res ? 'factura_id' then
    v_fid := (v_res->>'factura_id')::bigint;
  elsif v_res ? 'proyecto_id' or v_fuera then
    v_fid := v_row.factura_id;
  elsif v_hay and v_row.en_libro > 0 then
    -- ya está en el libro contra su factura: esa es
    v_fid := v_row.factura_id;
  else
    if v_enlace.id is not null then
      v_fid := v_enlace.factura_id;
      if nullif(v_meta->>'factura_id', '') is not null and v_meta_fid is distinct from v_enlace.factura_id then
        v_revisar := 'los metadatos de Stripe dicen otra factura que el enlace';
      end if;
    elsif v_meta_fid is not null then
      v_fid := v_meta_fid;
    else
      v_revisar := 'no salió de un enlace de la app (ni enlace ni factura en sus metadatos)';
    end if;
    if v_revisar is null and v_moneda <> 'usd' then
      v_revisar := format('viene en %s, no en dólares', upper(v_moneda));
    end if;
    if v_revisar is null and v_creado is not null and v_creado < cfg.desde - interval '1 day' then
      v_revisar := format('es del %s, de antes de instalar los cobros en línea', fn_fecha_miami(v_creado));
    end if;
  end if;
  if v_fid is not null then
    select f.num, f.proyecto_id into v_fnum, v_obra from facturas f where f.id = v_fid;
  end if;

  -- e) lo que dice Stripe hoy: lo reembolsado, lo retirado y lo reintegrado
  select coalesce(sum(fn_stripe_dinero(r->'monto')), 0), max(fn_stripe_dia(r->'creado'))
    into v_r, v_r_dia
    from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) r
   where nullif(r->>'bt', '') is not null and nullif(r->>'bt_fallo', '') is null
     and coalesce(r->>'estado', '') not in ('failed', 'canceled');
  select exists (select 1 from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) r where nullif(r->>'bt_fallo', '') is not null)
    into v_r_fallo;
  select coalesce(sum(-fn_stripe_dinero(b->'monto')) filter (where b->>'categoria' = 'dispute'), 0),
         coalesce(sum(fn_stripe_dinero(b->'monto')) filter (where b->>'categoria' = 'dispute_reversal'), 0),
         max(fn_stripe_dia(b->'creado'))
    into v_w, v_rn, v_d_dia
    from jsonb_array_elements(coalesce(p_foto->'disputas', '[]'::jsonb)) d
   cross join lateral jsonb_array_elements(coalesce(d->'bts', '[]'::jsonb)) b;
  v_neto := case when v_est = 'succeeded' then greatest(v_recibido - v_r - v_w + v_rn, 0) else 0 end;
  v_objetivo := case when v_fuera then 0 else v_neto end;
  v_fcambio := greatest(v_r_dia, v_d_dia, case when v_r_fallo then v_hoy end);
  -- la disputa que se enseña: la abierta, o la última
  select x into v_disp
    from jsonb_array_elements(coalesce(p_foto->'disputas', '[]'::jsonb)) with ordinality t(x, n)
   order by (x->>'estado' in ('needs_response', 'under_review', 'warning_needs_response', 'warning_under_review')) desc, t.n desc
   limit 1;
  v_abierta := coalesce(v_disp->>'estado' in ('needs_response', 'under_review', 'warning_needs_response', 'warning_under_review'), false);
  -- las balance transactions que el pago conoce
  select coalesce(jsonb_agg(distinct b), '[]'::jsonb) into v_bts
    from (select x->>'bt' as b from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) x
          union all select x->>'bt_fallo' from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) x
          union all select x->>'bt' from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) x
          union all select x->>'bt_fallo' from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) x
          union all select y->>'id' from jsonb_array_elements(coalesce(p_foto->'disputas', '[]'::jsonb)) x
                    cross join lateral jsonb_array_elements(coalesce(x->'bts', '[]'::jsonb)) y) z
   where nullif(z.b, '') is not null;
  -- la fecha del éxito (D9): la del aviso; sin ella, la del cargo (tarjeta)
  -- o la de su dinero disponible (cuenta de banco), nunca después de hoy
  if coalesce(p_foto->>'fecha_exito', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    v_fexito := (p_foto->>'fecha_exito')::date;
  elsif v_est = 'succeeded' then
    select case when v_medio = 'tarjeta' then fn_stripe_dia(x->'creado')
                else least(v_hoy, coalesce(fn_stripe_dia(coalesce(x->'disponible', x->'available_on')), v_hoy)) end
      into v_fexito
      from jsonb_array_elements(coalesce(p_foto->'cargos', '[]'::jsonb)) with ordinality t(x, n)
     where x->>'estado' = 'succeeded'
     order by t.n desc limit 1;
    v_fexito := least(coalesce(v_fexito, v_hoy), v_hoy);
  end if;

  -- f) la fila del pago, al día
  if not v_hay then
    insert into stripe_pagos (pi, monto, moneda, estado, estado_stripe)
    values (v_pi, v_monto, v_moneda, 'iniciado', v_est)
    returning * into v_row;
  end if;
  update stripe_pagos
     set enlace_id        = coalesce(v_enlace.id, enlace_id),
         plink            = coalesce(p_foto->>'plink', v_enlace.plink, plink),
         sesion           = coalesce(p_foto->>'sesion', sesion),
         factura_id       = v_fid,
         factura_num      = v_fnum,
         proyecto_id      = coalesce(case when v_res ? 'proyecto_id' then v_res->>'proyecto_id' end, v_obra),
         medio            = v_medio,
         monto            = v_monto,
         moneda           = v_moneda,
         estado_stripe    = v_est,
         cargo            = v_cargo,
         reembolsado      = v_r,
         disputa_retirada = v_w - v_rn,
         disputa_id       = v_disp->>'id',
         disputa_estado   = v_disp->>'estado',
         disputa_vence    = fn_stripe_dia(v_disp->'vence'),
         objetivo         = v_objetivo,
         foto             = fn_stripe_sin_datos(p_foto) || jsonb_build_object('bts', v_bts),
         foto_al          = v_visto,
         ultimo_evento    = coalesce(p_evento, ultimo_evento),
         actualizado_el   = now()
   where id = v_row.id
  returning * into v_row;
  if v_enlace.id is not null and v_enlace.estado = 'activo'
     and (coalesce((p_foto->>'sesion_completa')::boolean, false) or v_est in ('processing', 'succeeded', 'requires_action')) then
    update stripe_enlaces set estado = 'usado', usado_el = now(), sesion = coalesce(p_foto->>'sesion', sesion), pi = v_pi
     where id = v_enlace.id;
  end if;

  -- g/h) el libro: si lo que hay no es lo que debe haber (y el pago sabe
  --      a qué va), se devuelve el cobro vivo entero y se registra el
  --      objetivo. Todo o nada; los errores pasajeros se relanzan.
  if v_revisar is null and not v_fuera and v_objetivo <> v_row.en_libro then
    v_s := fn_stripe_suplantar();
    if v_row.factura_id is not null then
      perform 1 from facturas where id = v_row.factura_id for update;
    end if;
    begin
      v_version := v_row.version;
      v_cobro_nuevo := null;
      v_fecha := null;
      if v_row.en_libro > 0 then
        select * into v_cobro from cobros where id = v_row.cobro_id;
        v_motivo := case when v_w > v_antes_w and v_w > 0
                         then format('Stripe: disputa %s (%s), fondos retirados', coalesce(v_disp->>'id', '?'),
                                     coalesce(v_disp->>'motivo', 'sin motivo'))
                         when v_est <> 'succeeded' then 'Stripe: el pago falló después de cobrado'
                         when v_r > v_antes_r then format('Stripe: reembolso de %s', fn_stripe_usd(v_r - v_antes_r))
                         when v_rn > 0 then format('Stripe: disputa %s ganada, fondos reintegrados', coalesce(v_disp->>'id', '?'))
                         when v_r_fallo then 'Stripe: un reembolso falló y el dinero volvió'
                         else format('Stripe: el pago cambió (%s en el libro, %s según Stripe)', fn_stripe_usd(v_row.en_libro),
                                     fn_stripe_usd(v_objetivo)) end;
        v_dev := fn_cobro_devolver(v_row.cobro_id, greatest(coalesce(v_fcambio, v_hoy), v_cobro.fecha), v_motivo, null);
        insert into stripe_pago_libro (pago_id, accion, cobro_id, devolucion_id, asiento_id, asiento, fecha_contable, monto, motivo,
                                       tardio, evento)
        values (v_row.id, 'devolucion', v_row.cobro_id, (v_dev->>'devolucion')::uuid,
                (select dv.contabilizado_en from cobros_devoluciones dv where dv.id = (v_dev->>'devolucion')::uuid),
                v_dev->>'asiento', (v_dev->>'fecha_contable')::date, -v_row.en_libro, v_motivo, v_dev->>'tardio', p_evento);
        v_cambios := v_cambios || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                       'accion', 'devolucion', 'cobro', v_row.cobro_id, 'devolucion', v_dev->>'devolucion', 'asiento', v_dev->>'asiento',
                       'monto', -v_row.en_libro, 'fecha', v_dev->>'fecha_contable', 'tardio', v_dev->>'tardio')));
        v_fecha := greatest(coalesce(v_fcambio, v_hoy), v_cobro.fecha);
      end if;
      if v_objetivo > 0 then
        v_version := v_version + 1;
        v_llave := case when v_version = 1 then 'stripe:' || v_pi else 'stripe:' || v_pi || ':v' || (v_version - 1) end;
        -- (la primera, la del éxito; las siguientes, la del hecho que la
        -- explica, nunca antes del último cobro de este pago)
        v_fecha := case when v_version = 1 then coalesce(v_fexito, v_hoy)
                        else coalesce(v_fecha,
                                      greatest(coalesce(v_fcambio, v_hoy),
                                               (select max(c.fecha) from stripe_pago_libro pl join cobros c on c.id = pl.cobro_id
                                                 where pl.pago_id = v_row.id))) end;
        v_reg := fn_stripe_registrar(v_row, v_objetivo, v_fecha, v_llave, p_evento,
                                     case when v_version > 1 then format(' · versión %s', v_version) else '' end);
        if v_reg ? 'error' then
          v_err := v_reg->>'error';
          raise exception using errcode = 'MXS01', message = v_err;
        end if;
        v_cobro_nuevo := (v_reg->>'cobro')::uuid;
        v_tardio := v_reg->>'tardio';
        insert into stripe_pago_libro (pago_id, accion, cobro_id, asiento_id, asiento, fecha_contable, monto, llave, tardio, anticipo, evento)
        values (v_row.id, 'cobro', v_cobro_nuevo, (v_reg->>'asiento_id')::uuid, v_reg->>'asiento', (v_reg->>'fecha_contable')::date,
                v_objetivo, v_llave, v_tardio, nullif((v_reg->>'anticipo')::numeric, 0), p_evento);
        v_cambios := v_cambios || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                       'accion', 'cobro', 'cobro', v_cobro_nuevo, 'asiento', v_reg->>'asiento', 'monto', v_objetivo,
                       'fecha', v_reg->>'fecha_contable', 'tardio', v_tardio, 'anticipo', nullif((v_reg->>'anticipo')::numeric, 0))));
      end if;
      update stripe_pagos
         set en_libro = v_objetivo, cobro_id = v_cobro_nuevo, version = v_version,
             cobrado_el = coalesce(cobrado_el, case when v_objetivo > 0 then v_fecha end),
             ultimo_cambio_el = v_hoy
       where id = v_row.id
      returning * into v_row;
    exception
      when sqlstate 'MXS01' then
        v_libro_ok := false;
        v_libro_err := v_err;
      when sqlstate '40001' or sqlstate '40P01' or sqlstate '55P03' or sqlstate '57014' then
        raise;
      when others then
        if sqlerrm ~* 'no se abri' or not (sqlstate like 'MX%' or sqlstate in ('22023', '22007')) then
          raise;
        end if;
        v_libro_ok := false;
        v_libro_err := sqlerrm;
    end;
    perform fn_stripe_soltar(v_s);
    select * into v_row from stripe_pagos where id = v_row.id;
  end if;

  -- i) el estado
  v_fallo := null;
  v_estado := case
                when v_revisar is not null or not v_libro_ok then 'revisar'
                when v_est = 'succeeded' and v_abierta then 'en_disputa'
                when v_est = 'succeeded' and v_neto = 0 then 'devuelto'
                when v_est = 'succeeded' then 'cobrado'
                when v_est = 'processing' then 'en_camino'
                when v_est in ('requires_payment_method', 'canceled') then 'fallido'
                else 'iniciado' end;
  if v_estado = 'fallido' then
    v_fallo := coalesce(p_foto->'ultimo_error'->>'mensaje', p_foto->'ultimo_error'->>'codigo',
                        case when nullif(p_foto->>'cancelacion', '') is not null then 'cancelado: ' || (p_foto->>'cancelacion') end,
                        'sin motivo de Stripe');
  end if;
  update stripe_pagos
     set estado = v_estado, fallo = v_fallo,
         revisar = case when v_estado = 'revisar' then coalesce(v_revisar, v_libro_err) end,
         actualizado_el = now()
   where id = v_row.id
  returning * into v_row;

  -- j) los avisos, por transición
  v_txt := coalesce('#' || v_row.factura_num, 'sin factura');
  if v_estado = 'fallido' and v_antes is distinct from 'fallido' then
    perform fn_stripe_avisar('pago:' || v_pi || ':fallido', 'bad',
      format('El pago %s de %s de la %s falló (%s): no entró nada al libro. El enlace ya se usó: crea uno nuevo si el cliente lo pide.',
             case v_medio when 'ach' then 'por cuenta de banco' when 'tarjeta' then 'con tarjeta' else 'en línea' end,
             fn_stripe_usd(v_monto), v_txt, v_fallo), v_pi);
    v_avisos := v_avisos || ('pago:' || v_pi || ':fallido');
  end if;
  if v_estado = 'revisar' and (v_antes is distinct from 'revisar' or v_row.revisar is distinct from (v_foto_antes->>'_revisar')) then
    perform fn_stripe_avisar('pago:' || v_pi || ':revisar', 'bad',
      format('El pago %s de %s no se pudo poner en ninguna factura (%s): dime a qué va en Cobros en línea. Hasta entonces el depósito que '
             'lo lleva espera.', v_pi, fn_stripe_usd(v_monto), v_row.revisar), v_pi);
    v_avisos := v_avisos || ('pago:' || v_pi || ':revisar');
  end if;
  if v_libro_ok and v_revisar is null and not v_fuera then
    -- los reembolsos que se cuentan ahora y antes no
    for v_x in select r->>'id' as id, fn_stripe_dinero(r->'monto') as monto
                 from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) r
                where nullif(r->>'bt', '') is not null and nullif(r->>'bt_fallo', '') is null
                  and coalesce(r->>'estado', '') not in ('failed', 'canceled')
                  and not exists (select 1 from jsonb_array_elements(coalesce(v_foto_antes->'reembolsos', '[]'::jsonb)) o
                                   where o->>'id' = r->>'id' and nullif(o->>'bt', '') is not null and nullif(o->>'bt_fallo', '') is null
                                     and coalesce(o->>'estado', '') not in ('failed', 'canceled')) loop
      perform fn_stripe_avisar('pago:' || v_pi || ':reembolso:' || coalesce(v_x.id, '?'), 'warn',
        case when v_objetivo > 0
             then format('Se devolvió %s de la %s en Stripe: el cobro se rehízo por %s y la factura vuelve a deber %s. Si la factura estaba '
                         'mal, haz su nota de crédito.', fn_stripe_usd(v_x.monto), v_txt, fn_stripe_usd(v_objetivo), fn_stripe_usd(v_x.monto))
             else format('Se devolvió %s de la %s en Stripe: el cobro se devolvió entero en el libro y la factura vuelve a deber %s. Si la '
                         'factura estaba mal, haz su nota de crédito.', fn_stripe_usd(v_x.monto), v_txt, fn_stripe_usd(v_x.monto)) end,
        v_pi);
      v_avisos := v_avisos || ('pago:' || v_pi || ':reembolso:' || coalesce(v_x.id, '?'));
    end loop;
    -- los reembolsos que fallaron ahora
    for v_x in select r->>'id' as id, fn_stripe_dinero(r->'monto') as monto
                 from jsonb_array_elements(coalesce(p_foto->'reembolsos', '[]'::jsonb)) r
                where nullif(r->>'bt_fallo', '') is not null
                  and not exists (select 1 from jsonb_array_elements(coalesce(v_foto_antes->'reembolsos', '[]'::jsonb)) o
                                   where o->>'id' = r->>'id' and nullif(o->>'bt_fallo', '') is not null) loop
      perform fn_stripe_avisar('pago:' || v_pi || ':reembolso_fallo:' || coalesce(v_x.id, '?'), 'warn',
        format('El reembolso de %s de la %s falló y el dinero volvió a Stripe: volvió a entrar al libro.', fn_stripe_usd(v_x.monto), v_txt),
        v_pi);
      v_avisos := v_avisos || ('pago:' || v_pi || ':reembolso_fallo:' || coalesce(v_x.id, '?'));
    end loop;
    -- las disputas
    for v_x in select d->>'id' as id, d->>'estado' as estado, coalesce(d->>'motivo', 'sin motivo') as motivo,
                      fn_stripe_dinero(coalesce(d->'monto', '0'::jsonb)) as monto, fn_stripe_dia(d->'vence') as vence,
                      exists (select 1 from jsonb_array_elements(coalesce(d->'bts', '[]'::jsonb)) b where b->>'categoria' = 'dispute')
                        as retirada,
                      (select o from jsonb_array_elements(coalesce(v_foto_antes->'disputas', '[]'::jsonb)) o
                        where o->>'id' = d->>'id' limit 1) as antes
                 from jsonb_array_elements(coalesce(p_foto->'disputas', '[]'::jsonb)) d loop
      if v_x.antes is null
         or (v_x.retirada and not exists (select 1 from jsonb_array_elements(coalesce(v_x.antes->'bts', '[]'::jsonb)) b
                                           where b->>'categoria' = 'dispute')) then
        if v_x.estado not in ('won', 'lost', 'warning_closed', 'prevented') then
          perform fn_stripe_avisar('pago:' || v_pi || ':disputa:' || coalesce(v_x.id, '?'), 'bad',
            case when v_x.retirada
                 then format('Disputa de %s en la %s (%s): Stripe retiró el dinero (y su comisión). El cobro se devolvió en el libro y la '
                             'factura vuelve a deber. Respóndela en Stripe antes del %s.%s', fn_stripe_usd(v_x.monto), v_txt, v_x.motivo,
                             coalesce(v_x.vence::text, '(sin fecha)'),
                             case when v_medio = 'ach' then ' Las disputas por cuenta de banco no se pueden impugnar.' else '' end)
                 else format('Consulta (disputa sin retiro) de %s en la %s (%s): todavía no se retiró dinero y el cobro sigue en el libro. '
                             'Respóndela en Stripe antes del %s.', fn_stripe_usd(v_x.monto), v_txt, v_x.motivo,
                             coalesce(v_x.vence::text, '(sin fecha)')) end, v_pi);
          v_avisos := v_avisos || ('pago:' || v_pi || ':disputa:' || coalesce(v_x.id, '?'));
        end if;
      end if;
      if v_x.estado = 'won' and coalesce(v_x.antes->>'estado', '') <> 'won' then
        perform fn_stripe_avisar('pago:' || v_pi || ':ganada:' || coalesce(v_x.id, '?'), 'info',
          format('Ganaste la disputa de la %s: el cobro volvió al libro.', v_txt), v_pi);
        v_avisos := v_avisos || ('pago:' || v_pi || ':ganada:' || coalesce(v_x.id, '?'));
      elsif v_x.estado = 'lost' and coalesce(v_x.antes->>'estado', '') <> 'lost' then
        perform fn_stripe_avisar('pago:' || v_pi || ':perdida:' || coalesce(v_x.id, '?'), 'warn',
          format('Perdiste la disputa de la %s: el cobro ya estaba devuelto y la factura debe %s. Si no lo vas a cobrar, nota de crédito o '
                 'incobrables con el CPA.', v_txt, fn_stripe_usd(v_x.monto)), v_pi);
        v_avisos := v_avisos || ('pago:' || v_pi || ':perdida:' || coalesce(v_x.id, '?'));
      end if;
    end loop;
    if v_tardio is not null then
      perform fn_stripe_avisar('pago:' || v_pi || ':tardio:v' || v_row.version, 'info',
        format('El cobro de Stripe de la %s es de un mes ya cerrado: %s', v_txt, v_tardio), v_pi);
      v_avisos := v_avisos || ('pago:' || v_pi || ':tardio:v' || v_row.version);
    end if;
  end if;
  -- (lo que el aviso de «revisar» y el de la disputa comparan la próxima vez)
  update stripe_pagos
     set foto = foto || jsonb_build_object('_w', v_w, '_revisar', revisar)
   where id = v_row.id;

  return jsonb_build_object('pago', (select to_jsonb(v) from v_stripe_pagos v where v.pi = v_pi),
                            'estado', v_estado, 'antes', v_antes, 'objetivo', v_objetivo, 'en_libro', v_row.en_libro,
                            'cambios', v_cambios, 'avisos', to_jsonb(v_avisos));
end $$;
revoke execute on function public.fn_stripe_pago_sincronizar(jsonb, text) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_pago_sincronizar(jsonb, text) is 'p1: aplica la foto de HOY de un pago de Stripe: su estado y, si el libro no dice lo que debe, devuelve el cobro vivo entero y registra el nuevo (todo o nada), en nombre del dueño.';

-- Edgar dice a qué va un pago «por resolver»: a una factura, de anticipo
-- de una obra, o «fuera» (dinero de antes de la app o que ya está en el
-- libro por otro camino: sus líneas del depósito van a esa cuenta). Con su
-- motivo. Vuelve a aplicar la foto guardada.
create or replace function public.fn_stripe_pago_resolver(p_pi text, p_decision jsonb, p_motivo text, p_dueno uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  s       stripe_pagos;
  f       facturas;
  v_res   jsonb;
  v_r     jsonb;
begin
  perform fn_stripe_exigir();
  perform fn_stripe_dueno_fijar(p_dueno);
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Di por qué va ahí (el motivo): queda escrito con el pago.';
  end if;
  if p_decision is null or jsonb_typeof(p_decision) <> 'object'
     or (select count(*) from jsonb_object_keys(p_decision) k where k in ('factura_id', 'proyecto_id', 'fuera')) <> 1 then
    raise exception using errcode = '22023', message = 'A qué va: UNA de factura_id, proyecto_id o fuera:{cuenta}.';
  end if;
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.pago:' || coalesce(p_pi, '')));
  select * into s from stripe_pagos where pi = p_pi for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el pago %s.', coalesce(p_pi, '(ninguno)'));
  end if;
  if s.estado <> 'revisar' then
    raise exception using errcode = 'MX008', message = 'Ese pago ya está resuelto.';
  end if;
  if p_decision ? 'factura_id' then
    if coalesce(p_decision->>'factura_id', '') !~ '^-?[0-9]{1,18}$' then
      raise exception using errcode = '22023', message = 'factura_id es el número interno de la factura.';
    end if;
    select * into f from facturas where id = (p_decision->>'factura_id')::bigint;
    if not found or f.estado <> 'emitida' then
      raise exception using errcode = 'MX008', message = format('La factura %s no existe o no está emitida.', p_decision->>'factura_id');
    end if;
    v_res := jsonb_build_object('factura_id', f.id);
  elsif p_decision ? 'proyecto_id' then
    if not exists (select 1 from proyectos p where p.id = p_decision->>'proyecto_id') then
      raise exception using errcode = '22023', message = format('La obra %s no existe.', coalesce(p_decision->>'proyecto_id', ''));
    end if;
    v_res := jsonb_build_object('proyecto_id', p_decision->>'proyecto_id');
  else
    perform fn_stripe_cuenta_libre(p_decision->'fuera'->>'cuenta');
    v_res := jsonb_build_object('fuera', jsonb_build_object('cuenta', btrim(p_decision->'fuera'->>'cuenta')));
  end if;
  v_res := v_res || jsonb_build_object('motivo', btrim(p_motivo), 'por', p_dueno, 'el', now());
  update stripe_pagos set resuelto = v_res, revisar = null where id = s.id;
  -- la foto guardada, otra vez (con su misma hora)
  v_r := fn_stripe_pago_sincronizar((s.foto - '_w' - '_revisar' - 'bts') || jsonb_build_object('visto_el', s.foto_al), 'resolver');
  return jsonb_build_object('pago', v_r->'pago', 'resultado', v_r,
                            'payouts', coalesce((select jsonb_agg(p.po order by p.llegada)
                                                   from stripe_payouts p
                                                  where p.estado in ('esperando_cobros', 'revisar')
                                                    and (p.esperando @> jsonb_build_array(jsonb_build_object('pi', p_pi))
                                                         or exists (select 1 from stripe_payout_lineas l
                                                                     where l.payout_id = p.id and l.pi = p_pi))), '[]'::jsonb));
end $$;
revoke execute on function public.fn_stripe_pago_resolver(text, jsonb, text, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_pago_resolver(text, jsonb, text, uuid) is 'p1: Edgar dice a qué va un pago por resolver (factura, anticipo de una obra o fuera de la app), con su motivo; se vuelve a aplicar su foto.';


-- ---------------------------------------------------------------------
-- 8. Los depósitos de Stripe a Chase (payouts)
-- ---------------------------------------------------------------------
-- ¿Está casada la línea de la cuenta del banco de un asiento? (P2)
create or replace function public.fn_stripe_p2_casado(p_asiento uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg stripe_config;
  v   jsonb;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  select jsonb_build_object('casado', bc.id, 'movimiento', bc.movimiento_id, 'regla', bc.regla, 'automatico', bc.automatico)
    into v
    from asiento_lineas al
    join banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden and bcl.vigente
    join banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
   where al.asiento_id = p_asiento and al.cuenta = cfg.cuenta_banco
   limit 1;
  return v;
end $$;
revoke execute on function public.fn_stripe_p2_casado(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_p2_casado(uuid) is 'p1: el casado vivo de la línea de la cuenta del banco de un asiento (P2), o nulo.';

-- ¿Tiene el asiento un reverso de corrección?
create or replace function public.fn_stripe_reversado(p_asiento uuid) returns uuid
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  return (select r.id from asientos r where r.reversa_a = p_asiento and r.camino = 'reverso' order by r.cadena_pos limit 1);
end $$;
revoke execute on function public.fn_stripe_reversado(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_reversado(uuid) is 'p1: el reverso de corrección de un asiento, o nulo.';

-- EL DEPÓSITO. p_foto: {"po","visto_el","estado","monto","moneda",
-- "llegada":"AAAA-MM-DD (UTC)","automatico","metodo","conciliacion",
-- "bt_propio","bt_fallo","fallo_codigo"}. p_lineas: su composición ENTERA
-- (centavos): [{"txn","tipo","categoria","monto","comision","neto","fuente",
-- "pi","creado","disponible"}]. Cuadra si la suma de los netos (sin la
-- propia del depósito) es su monto; se guarda, y desde ahí se usan las
-- guardadas. Antes de asentar, cada pago que trae está en el libro como
-- Stripe dice hoy (si no, espera). Pagado: P1 y P2 (misma fecha); fallido:
-- P1 si faltaba, el reverso de P2 si estaba libre, y P3.
create or replace function public.fn_stripe_payout_sincronizar(p_foto jsonb, p_lineas jsonb default null, p_evento text default null,
                                                               p_rehacer boolean default false)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg         stripe_config;
  v_hoy       date := fn_fecha_miami(now());
  v_po        text;
  v_visto     timestamptz;
  p           stripe_payouts;
  v_hay       boolean;
  v_antes     text;
  v_est       text;
  v_monto     numeric(14,2);
  v_moneda    text;
  v_llegada   date;
  v_auto      boolean;
  v_metodo    text;
  v_revisar   text;
  v_esperando jsonb := '[]'::jsonb;
  v_avisos    text[] := '{}';
  v_suma      numeric(14,2);
  v_n         int;
  v_x         record;
  v_cobros    numeric(14,2) := 0;
  v_vuelve    numeric(14,2) := 0;
  v_comis     numeric(14,2) := 0;
  v_fuera_m   numeric(14,2) := 0;
  v_otros     numeric(14,2) := 0;
  v_neto      numeric(14,2);
  v_npagos    int;
  v_pagos     jsonb;
  v_lin       jsonb;
  v_fdoc      date;
  v_fecha     date;
  v_fp        jsonb;
  v_asi       jsonb;
  v_s         jsonb;
  v_p1        jsonb;
  v_p2        jsonb;
  v_rev       jsonb;
  v_p3        jsonb;
  v_proc      jsonb;
  v_rehechos  jsonb;
  v_hecho     boolean;
  v_corte     date;
  v_codigo    text;
  v_cas       jsonb;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  -- a) la forma, el candado y la foto vieja
  if p_foto is null or jsonb_typeof(p_foto) <> 'object' then
    raise exception using errcode = '22023', message = 'La foto del depósito llega como un objeto JSON.';
  end if;
  v_po := p_foto->>'po';
  if v_po is null or v_po !~ '^po_[A-Za-z0-9_]+$' then
    raise exception using errcode = '22023', message = format('«%s» no es un depósito de Stripe (po_…).', coalesce(v_po, ''));
  end if;
  begin
    v_visto := (p_foto->>'visto_el')::timestamptz;
  exception when others then
    v_visto := null;
  end;
  if v_visto is null then
    raise exception using errcode = '22023', message = 'La foto del depósito dice cuándo se pidió a Stripe (visto_el).';
  end if;
  if p_lineas is not null and jsonb_typeof(p_lineas) <> 'array' then
    raise exception using errcode = '22023', message = 'La composición del depósito llega como una lista.';
  end if;
  if cfg.modo = 'prueba' and not cfg.acepta_prueba then
    return jsonb_build_object('ignorado', 'modo', 'po', v_po);
  end if;
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.payout:' || v_po));
  select * into p from stripe_payouts where po = v_po for update;
  v_hay := found;
  if v_hay and p.foto_al > v_visto then
    return jsonb_build_object('viejo', true, 'payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', p.estado);
  end if;
  v_antes   := p.estado;
  v_est     := coalesce(p_foto->>'estado', '?');
  v_monto   := fn_stripe_dinero(coalesce(p_foto->'monto', '0'::jsonb));
  v_moneda  := lower(coalesce(p_foto->>'moneda', 'usd'));
  v_llegada := coalesce(fn_stripe_dia_utc(p_foto->'llegada'), p.llegada, v_hoy);
  v_auto    := coalesce((p_foto->>'automatico')::boolean, true);
  v_metodo  := coalesce(p_foto->>'metodo', 'standard');
  v_codigo  := coalesce(p_foto->>'fallo_codigo', p.fallo_codigo, 'sin código');
  if not v_hay then
    insert into stripe_payouts (po, monto, moneda, llegada, automatico, metodo, estado_stripe, estado)
    values (v_po, v_monto, v_moneda, v_llegada, v_auto, v_metodo, v_est, 'en_camino')
    returning * into p;
  end if;
  update stripe_payouts
     set monto = v_monto, moneda = v_moneda, llegada = v_llegada, automatico = v_auto, metodo = v_metodo, estado_stripe = v_est,
         conciliacion_stripe = coalesce(p_foto->>'conciliacion', conciliacion_stripe),
         bt_propio = coalesce(p_foto->>'bt_propio', bt_propio), bt_fallo = coalesce(p_foto->>'bt_fallo', bt_fallo),
         fallo_codigo = coalesce(p_foto->>'fallo_codigo', fallo_codigo),
         foto = p_foto, foto_al = v_visto, ultimo_evento = coalesce(p_evento, ultimo_evento), actualizado_el = now()
   where id = p.id
  returning * into p;

  -- i) rehacer lo que se reversó a mano (P1, P2 o P3)
  if coalesce(p_rehacer, false) then
    v_hecho := false;
    v_rehechos := p.rehechos;
    if p.asiento_salida is not null and fn_stripe_reversado(p.asiento_salida) is not null then
      v_rehechos := v_rehechos || jsonb_build_array(jsonb_build_object('paso', 'salida', 'asiento', p.asiento_salida,
                                                                       'reverso', fn_stripe_reversado(p.asiento_salida), 'el', now()));
      p.asiento_salida := null;
      v_hecho := true;
    end if;
    if p.asiento_llegada is not null and p.reverso_llegada is null and fn_stripe_reversado(p.asiento_llegada) is not null then
      if fn_stripe_p2_casado(p.asiento_llegada) is not null then
        raise exception using errcode = 'MX008',
          message = 'La línea de Chase del asiento reversado sigue casada: des-cásala (fn_banco_descasar, con su motivo) y vuelve a rehacer.';
      end if;
      v_rehechos := v_rehechos || jsonb_build_array(jsonb_build_object('paso', 'llegada', 'asiento', p.asiento_llegada,
                                                                       'reverso', fn_stripe_reversado(p.asiento_llegada), 'el', now()));
      p.asiento_llegada := null;
      v_hecho := true;
    end if;
    if p.asiento_vuelta is not null and fn_stripe_reversado(p.asiento_vuelta) is not null then
      v_rehechos := v_rehechos || jsonb_build_array(jsonb_build_object('paso', 'vuelta', 'asiento', p.asiento_vuelta,
                                                                       'reverso', fn_stripe_reversado(p.asiento_vuelta), 'el', now()));
      p.asiento_vuelta := null;
      v_hecho := true;
    end if;
    if not v_hecho then
      raise exception using errcode = 'MX008', message = 'No hay nada que rehacer: ningún asiento de este depósito está reversado a mano.';
    end if;
    update stripe_payouts
       set rehechos = v_rehechos, asiento_salida = p.asiento_salida, asiento_llegada = p.asiento_llegada,
           asiento_vuelta = p.asiento_vuelta,
           estado = case when p.estado in ('asentado', 'fallido') then 'esperando_cobros' else p.estado end
     where id = p.id
    returning * into p;
  end if;

  -- Ya hecho: nada que hacer (sincronizarlo otra vez no hace nada).
  if (p.estado = 'asentado' and v_est = 'paid') or (p.estado = 'fallido' and v_est in ('failed', 'canceled')) then
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', p.estado,
                              'antes', v_antes,
                              'asientos', jsonb_build_object('salida', p.asiento_salida, 'llegada', p.asiento_llegada,
                                                             'reverso', p.reverso_llegada, 'vuelta', p.asiento_vuelta),
                              'fecha', p.fecha_asiento, 'esperando', p.esperando, 'revisar', p.revisar);
  end if;

  -- b) lo que la app no asienta
  v_revisar := case
                 when v_moneda <> 'usd' then format('viene en %s, no en dólares', upper(v_moneda))
                 when not v_auto then 'es un depósito manual'
                 when v_metodo = 'instant' then 'es un depósito instantáneo'
                 when v_monto <= 0 then format('su monto es %s', fn_stripe_usd(v_monto)) end;
  if v_revisar is not null and p.asiento_salida is null then
    update stripe_payouts set estado = 'revisar', revisar = v_revisar where id = p.id;
    perform fn_stripe_avisar('payout:' || v_po || ':revisar', 'bad',
      format('El depósito de Stripe %s (%s) %s: Stripe solo da la composición de los depósitos automáticos en dólares: deja los payouts en '
             'automático (Settings → Payouts). No lo asiento.', v_po, fn_stripe_usd(v_monto), v_revisar), v_po);
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                              'antes', v_antes, 'revisar', v_revisar, 'avisos', jsonb_build_array('payout:' || v_po || ':revisar'));
  end if;
  if v_est in ('pending', 'in_transit') then
    if p.asiento_salida is null then
      update stripe_payouts set estado = 'en_camino', revisar = null where id = p.id;
    end if;
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'en_camino',
                              'antes', v_antes);
  end if;
  if v_est not in ('paid', 'failed', 'canceled') then
    raise exception using errcode = '22023', message = format('Estado de depósito que no conozco: «%s».', v_est);
  end if;

  -- c) la composición: sin guardar, la que llega; guardada, la guardada
  if not exists (select 1 from stripe_payout_lineas l where l.payout_id = p.id) then
    if p_lineas is null then
      if v_est = 'paid' then
        update stripe_payouts set estado = 'esperando_composicion', revisar = null where id = p.id;
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po),
                                  'estado', 'esperando_composicion', 'antes', v_antes);
      elsif p.asiento_salida is null then
        update stripe_payouts set estado = 'revisar', revisar = 'sin el detalle del depósito fallido' where id = p.id;
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                                  'antes', v_antes, 'revisar', 'sin el detalle del depósito fallido');
      end if;
    else
      -- la forma de cada línea
      if exists (select 1 from jsonb_array_elements(p_lineas) x
                  where jsonb_typeof(x) <> 'object' or coalesce(x->>'txn', '') = '' or coalesce(x->>'tipo', '') = '') then
        raise exception using errcode = '22023', message = 'Cada línea de la composición lleva su txn y su tipo.';
      end if;
      -- cuadra: los netos (sin la propia del depósito) suman su monto
      select coalesce(sum(coalesce(fn_stripe_dinero(x->'neto'),
                                   fn_stripe_dinero(x->'monto') - fn_stripe_dinero(coalesce(x->'comision', '0'::jsonb)))), 0)
        into v_suma
        from jsonb_array_elements(p_lineas) x
       where not (x->>'txn' in (coalesce(p.bt_propio, '-'), coalesce(p.bt_fallo, '-'))
                  or (x->>'tipo' = 'payout' and coalesce(x->>'fuente', '') = v_po));
      if v_suma <> v_monto then
        update stripe_payouts set estado = 'revisar',
               revisar = format('el detalle no suma su neto (diferencia %s)', fn_stripe_usd(v_suma - v_monto))
         where id = p.id;
        perform fn_stripe_avisar('payout:' || v_po || ':cuadre', 'bad',
          format('El detalle del depósito %s no suma su neto (diferencia %s): no lo asiento.', v_po, fn_stripe_usd(v_suma - v_monto)), v_po);
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                                  'antes', v_antes, 'revisar', 'el detalle no suma su neto',
                                  'avisos', jsonb_build_array('payout:' || v_po || ':cuadre'));
      end if;
      select string_agg(l.txn || ' (de ' || q.po || ')', ', ') into v_revisar
        from jsonb_array_elements(p_lineas) x
        join stripe_payout_lineas l on l.txn = x->>'txn'
        join stripe_payouts q on q.id = l.payout_id
       where l.payout_id <> p.id;
      if v_revisar is not null then
        update stripe_payouts set estado = 'revisar', revisar = 'trae movimientos que ya son de otro depósito: ' || v_revisar where id = p.id;
        perform fn_stripe_avisar('payout:' || v_po || ':repetido', 'bad',
          format('El detalle del depósito %s trae movimientos que ya son de otro depósito (%s): no lo asiento.', v_po, v_revisar), v_po);
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                                  'antes', v_antes, 'revisar', v_revisar);
      end if;
      insert into stripe_payout_lineas (payout_id, txn, tipo, categoria, monto, comision, neto, fuente, pi, pago_id, clase, creado_stripe,
                                        disponible)
      select p.id, x->>'txn', x->>'tipo', x->>'categoria', fn_stripe_dinero(coalesce(x->'monto', '0'::jsonb)),
             fn_stripe_dinero(coalesce(x->'comision', '0'::jsonb)),
             coalesce(fn_stripe_dinero(x->'neto'), fn_stripe_dinero(coalesce(x->'monto', '0'::jsonb))
                                                   - fn_stripe_dinero(coalesce(x->'comision', '0'::jsonb))),
             nullif(x->>'fuente', ''), nullif(x->>'pi', ''), (select s.id from stripe_pagos s where s.pi = nullif(x->>'pi', '')),
             case when x->>'txn' in (coalesce(p.bt_propio, '-'), coalesce(p.bt_fallo, '-'))
                       or (x->>'tipo' = 'payout' and coalesce(x->>'fuente', '') = v_po) then 'propio'
                  when nullif(x->>'pi', '') is not null then 'pago'
                  when x->>'tipo' in ('payout_failure', 'payout_cancel') or coalesce(x->>'fuente', '') ~ '^po_' then 'vuelve'
                  when x->>'tipo' ~ '_fee$' then 'comision'
                  else 'otro' end,
             fn_stripe_instante(x->'creado'), fn_stripe_dia_utc(x->'disponible')
        from jsonb_array_elements(p_lineas) x;
    end if;
  end if;

  -- d) EL PREVUELO, con los candados de sus pagos (en orden): ¿cada pago
  --    está en el libro como Stripe dice hoy? (Solo si falta P1: con P1
  --    puesto, lo que queda —P2, P3 o rehacer— no depende de sus pagos.)
  if p.asiento_salida is null then
  for v_x in select distinct l.pi from stripe_payout_lineas l where l.payout_id = p.id and l.clase = 'pago' order by l.pi loop
    perform pg_advisory_xact_lock(820261027, hashtext('stripe.pago:' || v_x.pi));
  end loop;
  update stripe_payout_lineas l set pago_id = s.id
    from stripe_pagos s
   where l.payout_id = p.id and l.pago_id is null and l.pi = s.pi;
  v_revisar := null;
  -- los pagos
  for v_x in select l.pi, s.id as pago_id, s.estado, s.objetivo, s.en_libro, coalesce(s.resuelto ? 'fuera', false) as fuera,
                    s.foto->'bts' as bts, sum(l.monto) as suma,
                    bool_and(coalesce(s.foto->'bts', '[]'::jsonb) ? l.txn) as conoce
               from stripe_payout_lineas l
               left join stripe_pagos s on s.pi = l.pi
              where l.payout_id = p.id and l.clase = 'pago'
              group by l.pi, s.id, s.estado, s.objetivo, s.en_libro, s.resuelto, s.foto->'bts'
              order by l.pi loop
    if v_x.pago_id is null then
      v_esperando := v_esperando || jsonb_build_array(jsonb_build_object('pi', v_x.pi, 'motivo', 'sin datos del pago'));
    elsif v_x.estado = 'revisar' and not v_x.fuera then
      v_esperando := v_esperando || jsonb_build_array(jsonb_build_object('pi', v_x.pi, 'motivo', 'por resolver'));
    elsif not v_x.fuera and v_x.en_libro <> v_x.objetivo then
      v_esperando := v_esperando || jsonb_build_array(jsonb_build_object('pi', v_x.pi, 'motivo', 'el libro no está al día'));
    elsif not v_x.conoce then
      v_esperando := v_esperando || jsonb_build_array(jsonb_build_object('pi', v_x.pi,
                       'motivo', 'la composición trae un movimiento que el pago no conoce'));
    elsif v_x.estado = 'fallido' and v_x.suma <> 0 then
      v_revisar := coalesce(v_revisar || '; ', '') || format('el pago %s falló y sus movimientos en este depósito suman %s', v_x.pi,
                                                             fn_stripe_usd(v_x.suma));
    end if;
  end loop;
  -- lo que vuelve de un depósito fallido
  for v_x in select l.txn, l.fuente, l.monto, q.id as qid, q.estado as qestado, q.asiento_vuelta,
                    exists (select 1 from stripe_payout_lineas l2 join stripe_payouts q2 on q2.id = l2.payout_id
                             where l2.clase = 'vuelve' and l2.fuente = l.fuente and l2.payout_id <> p.id
                               and q2.asiento_salida is not null and fn_stripe_reversado(q2.asiento_salida) is null) as ya
               from stripe_payout_lineas l
               left join stripe_payouts q on q.po = l.fuente
              where l.payout_id = p.id and l.clase = 'vuelve' loop
    if v_x.ya then
      v_revisar := coalesce(v_revisar || '; ', '') || format('lo que volvió del depósito %s ya lo liquidó otro depósito', v_x.fuente);
    elsif v_x.qid is null or v_x.qestado <> 'fallido' or v_x.asiento_vuelta is null or fn_stripe_reversado(v_x.asiento_vuelta) is not null then
      v_esperando := v_esperando || jsonb_build_array(jsonb_build_object('po', v_x.fuente,
                       'motivo', 'el depósito fallido todavía no está registrado'));
    end if;
  end loop;
  -- lo que la app no conoce (sin cuenta)
  select coalesce(jsonb_agg(jsonb_build_object('txn', l.txn, 'tipo', l.tipo, 'monto', l.monto, 'motivo', 'a qué cuenta va')
                            order by l.txn), '[]'::jsonb), count(*)
    into v_lin, v_n
    from stripe_payout_lineas l
   where l.payout_id = p.id and l.clase = 'otro' and l.cuenta is null;
  if v_n > 0 then
    v_esperando := v_esperando || v_lin;
    v_revisar := coalesce(v_revisar || '; ', '') || format('%s movimiento(s) que la app no conoce: dime a qué cuenta va', v_n);
    for v_x in select l.txn, l.tipo, l.monto from stripe_payout_lineas l
                where l.payout_id = p.id and l.clase = 'otro' and l.cuenta is null order by l.txn loop
      perform fn_stripe_avisar('payout:' || v_po || ':otro:' || v_x.txn, 'bad',
        format('Stripe trae en el depósito %s un movimiento que la app no conoce (%s, %s): dime a qué cuenta va.', v_po, v_x.tipo,
               fn_stripe_usd(v_x.monto)), v_po);
      v_avisos := v_avisos || ('payout:' || v_po || ':otro:' || v_x.txn);
    end loop;
  end if;
  if v_revisar is not null then
    update stripe_payouts set estado = 'revisar', revisar = v_revisar, esperando = v_esperando where id = p.id;
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                              'antes', v_antes, 'revisar', v_revisar, 'esperando', v_esperando, 'avisos', to_jsonb(v_avisos));
  end if;
  if jsonb_array_length(v_esperando) > 0 then
    update stripe_payouts set estado = 'esperando_cobros', revisar = null, esperando = v_esperando where id = p.id;
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'esperando_cobros',
                              'antes', v_antes, 'esperando', v_esperando);
  end if;

  -- Las cifras: L (lo cobrado en la app que liquida), V (lo que vuelve de
  -- un depósito fallido), Lf (lo de fuera de la app, por cuenta), D (lo
  -- que la app no conoce, ya con su cuenta), C (las comisiones) y N (el
  -- neto que llega a Chase). N + C = L + V + Lf + D.
  select coalesce(sum(l.monto) filter (where l.clase = 'pago' and not coalesce(s.resuelto ? 'fuera', false)), 0),
         coalesce(sum(l.monto) filter (where l.clase = 'vuelve'), 0),
         coalesce(sum(l.monto) filter (where l.clase = 'pago' and coalesce(s.resuelto ? 'fuera', false)), 0),
         coalesce(sum(l.monto) filter (where l.clase = 'otro'), 0),
         coalesce(sum(l.comision) filter (where l.clase <> 'propio'), 0) - coalesce(sum(l.monto) filter (where l.clase = 'comision'), 0),
         count(distinct l.pi) filter (where l.clase = 'pago'),
         coalesce(jsonb_agg(distinct l.pi) filter (where l.clase = 'pago'), '[]'::jsonb)
    into v_cobros, v_vuelve, v_fuera_m, v_otros, v_comis, v_npagos, v_pagos
    from stripe_payout_lineas l
    left join stripe_pagos s on s.id = l.pago_id
   where l.payout_id = p.id;
  v_neto := p.monto;
  if v_neto + v_comis <> v_cobros + v_vuelve + v_fuera_m + v_otros then
    update stripe_payouts set estado = 'revisar',
           revisar = format('no cuadra: neto %s + comisiones %s ≠ cobros %s + vuelve %s + fuera %s + otros %s', v_neto, v_comis, v_cobros, v_vuelve, v_fuera_m, v_otros)
     where id = p.id;
    return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                              'antes', v_antes, 'revisar', 'no cuadra');
  end if;

  -- La fecha (D9): la llegada, o la del depósito de Chase si ya está y es
  -- antes; nunca dentro de una conciliación confirmada de la 1010.
  v_fdoc := v_llegada;
  if v_est = 'paid' then
    select count(*), min(m.fecha) into v_n, v_fecha
      from movimientos_banco m
     where m.cuenta = cfg.cuenta_banco and m.estado = 'pendiente' and m.monto = v_neto
       and m.fecha between v_llegada - 3 and v_llegada + 5 and m.desc_norm ~* '(^| )STRIPE( |$)';
    if v_n = 1 then
      v_fdoc := least(v_llegada, v_fecha);
    end if;
  end if;
  v_fecha := fn_stripe_fecha_banco(v_fdoc);
  else
    -- P1 ya está: sus cifras y su fecha
    v_neto := p.monto;
    v_comis := coalesce(p.comisiones, 0);
    v_npagos := coalesce(p.n_pagos, 0);
    v_fdoc := coalesce(p.fecha_documento, v_llegada);
    v_fecha := fn_stripe_fecha_banco(coalesce(p.fecha_asiento, v_fdoc));
  end if;
  v_fp := fn_puente_fecha(v_fecha);
  v_s := fn_stripe_suplantar();

  -- f) P1 «sale de Stripe»
  if p.asiento_salida is null then
    v_lin := '[]'::jsonb;
    v_lin := v_lin || jsonb_build_array(jsonb_build_object('cuenta', cfg.cuenta_paso, 'monto', v_neto::text,
                                                           'memo', format('Neto del depósito %s camino a Chase', v_po)));
    if v_comis <> 0 then
      v_lin := v_lin || jsonb_build_array(jsonb_build_object('cuenta', cfg.cuenta_comisiones, 'monto', v_comis::text,
                                                             'memo', format('Comisiones y cargos de Stripe del depósito %s (%s cobro(s))', v_po,
                                                                            v_npagos)));
    end if;
    if v_cobros + v_vuelve <> 0 then
      v_lin := v_lin || jsonb_build_array(jsonb_build_object('cuenta', cfg.cuenta_puente, 'monto', (-(v_cobros + v_vuelve))::text,
                                                             'memo', format('Lo cobrado en Stripe que liquida %s', v_po)));
    end if;
    for v_x in select r.cuenta, max(r.motivo) as motivo, sum(l.monto) as monto
                 from stripe_payout_lineas l
                 join stripe_pagos s on s.id = l.pago_id
                cross join lateral (select s.resuelto->'fuera'->>'cuenta' as cuenta, s.resuelto->>'motivo' as motivo) r
                where l.payout_id = p.id and l.clase = 'pago' and s.resuelto ? 'fuera'
                group by r.cuenta
               having sum(l.monto) <> 0
                order by r.cuenta loop
      v_lin := v_lin || jsonb_build_array(jsonb_build_object('cuenta', v_x.cuenta, 'monto', (-v_x.monto)::text,
                                                             'memo', left(format('Cobros de Stripe de fuera de la app (%s)', v_x.motivo), 300)));
    end loop;
    for v_x in select l.txn, l.tipo, l.cuenta, l.monto, l.resuelto->>'motivo' as motivo
                 from stripe_payout_lineas l
                where l.payout_id = p.id and l.clase = 'otro' and l.monto <> 0
                order by l.txn loop
      v_lin := v_lin || jsonb_build_array(jsonb_build_object('cuenta', v_x.cuenta, 'monto', (-v_x.monto)::text,
                                                             'memo', left(format('Stripe %s (%s): %s', v_x.txn, v_x.tipo, v_x.motivo), 300)));
    end loop;
    v_proc := jsonb_strip_nulls(jsonb_build_object(
      'funcion', 'fn_stripe_payout_sincronizar', 'paso', 'salida', 'payout', v_po, 'evento', p_evento, 'fecha_documento', v_fdoc,
      'llegada', v_llegada, 'bt_propio', p.bt_propio, 'pagos', v_pagos, 'tardio', v_fp->>'nota',
      'stripe', jsonb_build_object('bruto', v_cobros + v_vuelve + v_fuera_m + v_otros, 'comisiones', v_comis, 'vuelve', v_vuelve, 'fuera', v_fuera_m, 'otros', v_otros,
                                   'lineas', (select count(*) from stripe_payout_lineas l where l.payout_id = p.id))));
    v_asi := jsonb_build_object(
      'camino', 'mano', 'fecha', v_fp->>'fecha',
      'descripcion', format('Stripe · sale el depósito %s · %s cobro(s) · bruto %s − comisiones %s = neto %s', v_po, v_npagos,
                            v_cobros + v_vuelve + v_fuera_m + v_otros, v_comis, v_neto),
      'motivo', 'Lo posteó p1 (cobros en línea) con la composición que dio Stripe para ese depósito',
      'lineas', v_lin, 'procedencia', v_proc);
    if v_fp->>'tipo' = 'ajuste_cpa' then
      v_asi := v_asi || jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fp->>'afecta_periodo', 'motivo', v_fp->>'nota');
    end if;
    v_p1 := fn_postear_interno(v_asi);
    update stripe_payouts
       set asiento_salida = (v_p1->>'id')::uuid, bruto = v_cobros + v_vuelve + v_fuera_m + v_otros, comisiones = v_comis, vuelve = v_vuelve, fuera = v_fuera_m,
           otros = v_otros, n_pagos = v_npagos, fecha_asiento = (v_fp->>'fecha')::date, fecha_documento = v_fdoc
     where id = p.id
    returning * into p;
  end if;

  if v_est = 'paid' then
    -- g) P2 «llega a Chase»
    if p.asiento_llegada is null then
      v_asi := jsonb_build_object(
        'camino', 'mano', 'fecha', v_fp->>'fecha',
        'descripcion', format('Stripe · llega a Chase el depósito %s · %s', v_po, v_neto),
        'motivo', 'Lo posteó p1: el depósito que Stripe manda a Chase; casa solo con el movimiento STRIPE',
        'lineas', jsonb_build_array(
                    jsonb_build_object('cuenta', cfg.cuenta_banco, 'monto', v_neto::text,
                                       'memo', format('STRIPE · depósito %s (llega el %s)', v_po, v_llegada)),
                    jsonb_build_object('cuenta', cfg.cuenta_paso, 'monto', (-v_neto)::text, 'memo', 'Sale de la cuenta de paso')),
        'procedencia', jsonb_strip_nulls(jsonb_build_object(
                         'funcion', 'fn_stripe_payout_sincronizar', 'paso', 'llegada', 'payout', v_po, 'evento', p_evento,
                         'fecha_documento', v_fdoc, 'llegada', v_llegada, 'tardio', v_fp->>'nota')));
      if v_fp->>'tipo' = 'ajuste_cpa' then
        v_asi := v_asi || jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fp->>'afecta_periodo', 'motivo', v_fp->>'nota');
      end if;
      v_p2 := fn_postear_interno(v_asi);
      update stripe_payouts set asiento_llegada = (v_p2->>'id')::uuid where id = p.id returning * into p;
    end if;
    update stripe_payouts set estado = 'asentado', revisar = null, esperando = null where id = p.id returning * into p;
    perform fn_stripe_avisar('payout:' || v_po, 'info',
      format('Stripe depositó %s (depósito %s, %s cobro(s), comisiones %s): asientos %s y %s.', fn_stripe_usd(v_neto), v_po, v_npagos,
             fn_stripe_usd(v_comis), (select a.numero from asientos a where a.id = p.asiento_salida),
             (select a.numero from asientos a where a.id = p.asiento_llegada)), v_po);
    v_avisos := v_avisos || ('payout:' || v_po);
  else
    -- h) el depósito falló (o se canceló)
    if p.asiento_llegada is not null and p.reverso_llegada is null and fn_stripe_reversado(p.asiento_llegada) is null then
      v_cas := fn_stripe_p2_casado(p.asiento_llegada);
      if v_cas is not null then
        update stripe_payouts set estado = 'revisar',
               revisar = 'Stripe dice que falló, pero ya casó con un depósito de Chase' where id = p.id;
        perform fn_stripe_avisar('payout:' || v_po || ':fallo_casado', 'bad',
          format('Stripe dice que el depósito %s falló, pero ya casó con un depósito de Chase: mira el estado de cuenta.', v_po), v_po);
        perform fn_stripe_soltar(v_s);
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                                  'antes', v_antes, 'revisar', 'ya casó con Chase');
      end if;
      select max(c.fecha_corte) into v_corte from conciliaciones c
       where c.cuenta = cfg.cuenta_banco and c.estado = 'confirmada'
         and c.fecha_corte >= (select a.fecha_contable from asientos a where a.id = p.asiento_llegada);
      if v_corte is not null then
        update stripe_payouts set estado = 'revisar',
               revisar = format('falló y su asiento está dentro de la conciliación de %s al %s', cfg.cuenta_banco, v_corte)
         where id = p.id;
        perform fn_stripe_avisar('payout:' || v_po || ':fallo_conciliado', 'bad',
          format('Reabre la conciliación de %s al %s (fn_conciliacion_reabrir, con su motivo) y toca «Volver a mirar»: el depósito %s falló '
                 'y su asiento está dentro de ella.', cfg.cuenta_banco, v_corte, v_po), v_po);
        perform fn_stripe_soltar(v_s);
        return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', 'revisar',
                                  'antes', v_antes, 'revisar', 'dentro de una conciliación confirmada');
      end if;
      v_rev := fn_reversar_interno(p.asiento_llegada, format('Stripe: el depósito %s falló (%s): el dinero no llegó a Chase', v_po, v_codigo),
                                   'reverso', jsonb_build_object('funcion', 'fn_stripe_payout_sincronizar', 'payout', v_po));
      update stripe_payouts set reverso_llegada = (v_rev->>'id')::uuid where id = p.id returning * into p;
    end if;
    if p.asiento_vuelta is null then
      v_fp := fn_puente_fecha(v_hoy);
      v_asi := jsonb_build_object(
        'camino', 'mano', 'fecha', v_fp->>'fecha',
        'descripcion', format('Stripe · el depósito %s falló (%s): el dinero volvió al saldo de Stripe', v_po, v_codigo),
        'motivo', 'Lo posteó p1: Stripe devuelve a su saldo el depósito que no llegó y lo manda con el siguiente',
        'lineas', jsonb_build_array(
                    jsonb_build_object('cuenta', cfg.cuenta_puente, 'monto', v_neto::text,
                                       'memo', format('Vuelve al saldo de Stripe el depósito %s', v_po)),
                    jsonb_build_object('cuenta', cfg.cuenta_paso, 'monto', (-v_neto)::text, 'memo', 'Sale de la cuenta de paso')),
        'procedencia', jsonb_strip_nulls(jsonb_build_object(
                         'funcion', 'fn_stripe_payout_sincronizar', 'paso', 'vuelta', 'payout', v_po, 'evento', p_evento,
                         'fallo', v_codigo, 'tardio', v_fp->>'nota')));
      if v_fp->>'tipo' = 'ajuste_cpa' then
        v_asi := v_asi || jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fp->>'afecta_periodo', 'motivo', v_fp->>'nota');
      end if;
      v_p3 := fn_postear_interno(v_asi);
      update stripe_payouts set asiento_vuelta = (v_p3->>'id')::uuid where id = p.id returning * into p;
    end if;
    update stripe_payouts set estado = 'fallido', revisar = null, esperando = null where id = p.id returning * into p;
    perform fn_stripe_avisar('payout:' || v_po || ':fallido', 'bad',
      format('El depósito de Stripe %s (%s) no llegó a Chase (%s). Stripe lo devuelve a tu saldo y lo manda con el siguiente; revisa la '
             'cuenta de banco en Stripe.', v_po, fn_stripe_usd(v_neto), v_codigo), v_po);
    v_avisos := v_avisos || ('payout:' || v_po || ':fallido');
  end if;
  perform fn_stripe_soltar(v_s);
  return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = v_po), 'estado', p.estado,
                            'antes', v_antes,
                            'asientos', jsonb_build_object('salida', p.asiento_salida, 'llegada', p.asiento_llegada,
                                                           'reverso', p.reverso_llegada, 'vuelta', p.asiento_vuelta),
                            'fecha', p.fecha_asiento, 'tardio', v_fp->>'nota', 'esperando', null, 'revisar', null,
                            'avisos', to_jsonb(v_avisos));
end $$;
revoke execute on function public.fn_stripe_payout_sincronizar(jsonb, jsonb, text, boolean) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_payout_sincronizar(jsonb, jsonb, text, boolean) is 'p1: un depósito de Stripe a Chase: su composición, el prevuelo de sus pagos y sus asientos P1 y P2 (pagado) o P3 (fallido), en nombre del dueño.';

-- Edgar dice a qué cuenta va una línea del depósito que la app no conoce.
create or replace function public.fn_stripe_payout_linea_resolver(p_po text, p_txn text, p_cuenta text, p_motivo text, p_dueno uuid)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  p stripe_payouts;
  l stripe_payout_lineas;
begin
  perform fn_stripe_exigir();
  perform fn_stripe_dueno_fijar(p_dueno);
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Di qué es ese movimiento de Stripe (el motivo): queda escrito con la línea.';
  end if;
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.payout:' || coalesce(p_po, '')));
  select * into p from stripe_payouts where po = p_po for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el depósito %s.', coalesce(p_po, '(ninguno)'));
  end if;
  select * into l from stripe_payout_lineas where payout_id = p.id and txn = p_txn for update;
  if not found or l.clase <> 'otro' then
    raise exception using errcode = 'MX008', message = 'Esa no es una línea de este depósito que la app no conoce.';
  end if;
  if p.asiento_salida is not null then
    raise exception using errcode = 'MX008', message = 'Ese depósito ya está asentado: su línea ya no cambia.';
  end if;
  perform fn_stripe_cuenta_libre(p_cuenta);
  update stripe_payout_lineas
     set cuenta = btrim(p_cuenta), resuelto = jsonb_build_object('motivo', btrim(p_motivo), 'por', p_dueno, 'el', now())
   where payout_id = p.id and txn = p_txn;
  return jsonb_build_object('payout', (select to_jsonb(v) from v_stripe_payouts v where v.po = p_po));
end $$;
revoke execute on function public.fn_stripe_payout_linea_resolver(text, text, text, text, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_payout_linea_resolver(text, text, text, text, uuid) is 'p1: Edgar dice a qué cuenta va una línea de un depósito de Stripe que la app no conoce, con su motivo.';

-- CASAR un depósito asentado con su movimiento de Chase, SIEMPRE en su
-- propia transacción (c6 toma primero el candado del casado y después la
-- cadena: casar en la transacción que postea invertiría el orden frente a
-- la sincronización de Plaid). Sin movimiento: si hay UNO pendiente que
-- puede ser él (STRIPE, el neto, cerca de la llegada), «Casar» de c6 (R1
-- decide); si no, nada (Plaid casa por la mañana). Con el movimiento que
-- eligió Edgar: «Casar»; si sigue pendiente, con el asiento P2 y su motivo.
create or replace function public.fn_stripe_payout_casar(p_po text, p_movimiento uuid default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg     stripe_config;
  p       stripe_payouts;
  m       movimientos_banco;
  v_cas   jsonb;
  v_s     jsonb;
  v_ids   uuid[];
  v_mov   uuid;
begin
  perform fn_stripe_exigir();
  cfg := fn_stripe_cfg();
  perform pg_advisory_xact_lock(820261027, hashtext('stripe.payout:' || coalesce(p_po, '')));
  select * into p from stripe_payouts where po = p_po;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el depósito %s.', coalesce(p_po, '(ninguno)'));
  end if;
  if p.estado <> 'asentado' or p.asiento_llegada is null then
    raise exception using errcode = 'MX008', message = format('El depósito %s no está asentado (está %s): no se casa.', p_po, p.estado);
  end if;
  v_cas := fn_stripe_p2_casado(p.asiento_llegada);
  if v_cas is not null then
    return jsonb_build_object('po', p_po, 'casado', true, 'ya', true, 'movimiento', v_cas->>'movimiento', 'regla', v_cas->>'regla',
                              'automatico', (v_cas->>'automatico')::boolean);
  end if;
  if p_movimiento is not null then
    select * into m from movimientos_banco where id = p_movimiento;
    if not found or m.cuenta <> cfg.cuenta_banco or m.estado <> 'pendiente' or m.monto <> p.monto then
      raise exception using errcode = 'MX008',
        message = format('Ese movimiento no es este depósito: tiene que ser de %s, estar pendiente y ser por %s.', cfg.cuenta_banco,
                         fn_stripe_usd(p.monto));
    end if;
  end if;
  v_s := fn_stripe_suplantar();
  if p_movimiento is null then
    select coalesce(array_agg(x.id order by x.fecha), '{}') into v_ids
      from movimientos_banco x
     where x.cuenta = cfg.cuenta_banco and x.estado = 'pendiente' and x.monto = p.monto
       and x.fecha between p.llegada - 3 and p.llegada + 5 and x.desc_norm ~* '(^| )STRIPE( |$)';
    if cardinality(v_ids) = 1 then
      v_mov := v_ids[1];
      perform fn_banco_casar(v_mov);
    end if;
  else
    v_mov := p_movimiento;
    perform fn_banco_casar(v_mov);
    if (select x.estado from movimientos_banco x where x.id = v_mov) = 'pendiente' then
      perform fn_banco_casar_con(v_mov, jsonb_build_object('asiento', p.asiento_llegada),
                                 format('Stripe p1: depósito %s del %s por %s (lo eligió Edgar)', p_po, p.llegada, p.monto));
    end if;
  end if;
  perform fn_stripe_soltar(v_s);
  v_cas := fn_stripe_p2_casado(p.asiento_llegada);
  return jsonb_strip_nulls(jsonb_build_object(
    'po', p_po, 'casado', v_cas is not null, 'movimiento', coalesce(v_cas->>'movimiento', v_mov::text), 'regla', v_cas->>'regla',
    'automatico', (v_cas->>'automatico')::boolean,
    'candidatos', case when p_movimiento is null then coalesce(cardinality(v_ids), 0) end));
end $$;
revoke execute on function public.fn_stripe_payout_casar(text, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_payout_casar(text, uuid) is 'p1: casa un depósito asentado con su movimiento de Chase (R1 de c6; o el que eligió Edgar, con su motivo), en su propia transacción.';


-- ---------------------------------------------------------------------
-- 9. Las vistas de la pantalla (solo leen TABLAS; security_invoker: cada
--    una con los permisos de quien la lee, y el dueño ve todo)
-- ---------------------------------------------------------------------
drop view if exists public.v_stripe_estado, public.v_stripe_control, public.v_stripe_facturas, public.v_stripe_pagos,
                    public.v_stripe_payouts, public.v_stripe_avisos, public.v_stripe_eventos;

-- Las facturas que se pueden cobrar en línea: las emitidas con saldo en el
-- libro, más las que tienen un enlace vivo o un pago en camino.
create view public.v_stripe_facturas with (security_invoker = true) as
with cfg as (select * from public.stripe_config where id = 1),
     ctas as (select (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxc') as cxc,
                     (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc') as ret),
     s as (select l.partida_id,
                  coalesce(sum(l.monto) filter (where l.cuenta = ctas.cxc), 0) as saldo_cxc,
                  coalesce(sum(l.monto) filter (where l.cuenta = ctas.ret), 0) as saldo_retencion,
                  count(*) as lineas
             from public.asiento_lineas l cross join ctas
            where l.partida_tabla = 'facturas' and l.cuenta in (ctas.cxc, ctas.ret)
            group by l.partida_id),
     x as (select f.id as factura_id, f.num, f.fecha, f.proyecto_id, pr.nombre as obra, pr.cliente, round(f.monto, 2) as monto_factura,
                  coalesce(f.pagada, false) as pagada, f.estado as factura_estado,
                  (f.contabilizado_en is not null or coalesce(s.lineas, 0) > 0) as en_libro,
                  coalesce(s.saldo_cxc, 0)::numeric(14,2) as saldo_cxc, coalesce(s.saldo_retencion, 0)::numeric(14,2) as saldo_retencion,
                  e.id as enlace_id, e.estado as enlace_estado, e.url as enlace_url, e.monto as enlace_monto,
                  e.con_retencion as enlace_con_retencion, e.creado_el as enlace_creado_el,
                  coalesce(e.estado = 'activo'
                           and e.monto <> coalesce(s.saldo_cxc, 0) + case when e.con_retencion then coalesce(s.saldo_retencion, 0) else 0 end,
                           false) as enlace_desfasado,
                  coalesce(pg.monto, 0)::numeric(14,2) as en_camino_monto, coalesce(pg.n, 0) as en_camino_n
             from public.facturas f
             cross join cfg
             left join s on s.partida_id = f.id::text
             left join public.proyectos pr on pr.id = f.proyecto_id
             left join lateral (select e0.* from public.stripe_enlaces e0
                                 where e0.factura_id = f.id and e0.estado in ('creando', 'activo')
                                 order by e0.creado_el desc limit 1) e on true
             left join lateral (select sum(p0.monto) as monto, count(*) as n from public.stripe_pagos p0
                                 where p0.factura_id = f.id and p0.estado in ('iniciado', 'en_camino')) pg on true
            where (f.estado = 'emitida' and (coalesce(s.saldo_cxc, 0) > 0 or coalesce(s.saldo_retencion, 0) > 0))
               or e.id is not null or coalesce(pg.n, 0) > 0)
select x.factura_id, x.num, x.fecha, x.proyecto_id, x.obra, x.cliente, x.monto_factura, x.pagada, x.en_libro, x.saldo_cxc,
       x.saldo_retencion, x.enlace_id, x.enlace_estado, x.enlace_url, x.enlace_monto, x.enlace_con_retencion, x.enlace_creado_el,
       x.enlace_desfasado, x.en_camino_monto, x.en_camino_n,
       q.por_que_no is null as puede_enlace,
       q.por_que_no
  from x
 cross join lateral (select case
                              when x.factura_estado = 'anulada' then 'factura anulada'
                              when x.factura_estado = 'borrador' then 'factura en borrador'
                              when x.en_camino_n > 0 then 'pago en camino'
                              when not x.en_libro then 'fuera del libro'
                              when x.saldo_cxc < 0 or x.saldo_retencion < 0
                                   or (x.monto_factura is not null and x.saldo_cxc + x.saldo_retencion > x.monto_factura)
                                then 'revisa la factura (aviso de c3)'
                              when x.saldo_cxc + x.saldo_retencion <= 0 then 'sin saldo en el libro'
                              when x.saldo_cxc + x.saldo_retencion < 0.50 then 'menos de 0.50'
                            end as por_que_no) q;
comment on view public.v_stripe_facturas is 'p1: las facturas que se pueden cobrar en línea, con lo que deben en el LIBRO (no la casilla «pagada»), su enlace vivo y si hay un pago en camino.';

-- Los pagos en línea (los de 120 días, más los que no han terminado o les
-- falta depositar). falta_depositar = lo que hay en el libro menos lo que
-- ya liquidaron sus depósitos asentados.
create view public.v_stripe_pagos with (security_invoker = true) as
with cfg as (select * from public.stripe_config where id = 1),
     hoy as (select (now() at time zone 'America/New_York')::date as d),
     dep as (select l.pago_id, sum(l.monto) as liquidado,
                    jsonb_agg(distinct q.po) as payouts,
                    bool_and(exists (select 1 from public.asiento_lineas al
                                       join public.banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden
                                                                          and bcl.vigente
                                       join public.banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                                      cross join cfg
                                      where al.asiento_id = q.asiento_llegada and al.cuenta = cfg.cuenta_banco)) as todos_casados,
                    max((select m.fecha from public.asiento_lineas al
                           join public.banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden and bcl.vigente
                           join public.banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                           join public.movimientos_banco m on m.id = bc.movimiento_id
                          cross join cfg
                          where al.asiento_id = q.asiento_llegada and al.cuenta = cfg.cuenta_banco
                          limit 1)) as deposito_fecha
               from public.stripe_payout_lineas l
               join public.stripe_payouts q on q.id = l.payout_id
              where l.clase = 'pago' and l.pago_id is not null and q.asiento_salida is not null
                and not exists (select 1 from public.asientos r where r.reversa_a = q.asiento_salida and r.camino = 'reverso')
              group by l.pago_id),
     x as (select s.*,
                  case when coalesce(s.resuelto ? 'fuera', false) then 0
                       else s.en_libro - coalesce(dep.liquidado, 0) end::numeric(14,2) as falta_depositar,
                  dep.payouts, dep.todos_casados, dep.deposito_fecha
             from public.stripe_pagos s
             cross join cfg
             left join dep on dep.pago_id = s.id)
select x.id, x.pi, x.estado,
       case when x.estado = 'cobrado' and x.falta_depositar = 0 and x.payouts is not null
            then case when coalesce(x.todos_casados, false) then 'depositado' else 'en_payout' end
            else x.estado end as estado_pantalla,
       x.estado_stripe, x.medio, x.monto, x.objetivo, x.en_libro, x.reembolsado, x.disputa_retirada, x.disputa_estado, x.disputa_vence,
       x.factura_id, x.factura_num, pr.nombre as obra, x.enlace_id,
       (select a.numero from public.cobros c join public.asientos a on a.id = c.contabilizado_en where c.id = x.cobro_id) as cobro_asiento,
       x.cobrado_el, x.ultimo_cambio_el, x.falta_depositar, coalesce(x.payouts, '[]'::jsonb) as payouts, x.deposito_fecha, x.fallo,
       x.revisar, x.resuelto, hoy.d - (x.creado_el at time zone 'America/New_York')::date as dias, x.creado_el, x.actualizado_el
  from x
 cross join hoy
  left join public.proyectos pr on pr.id = x.proyecto_id
 where x.creado_el > now() - interval '120 days'
    or x.estado in ('iniciado', 'en_camino', 'en_disputa', 'revisar')
    or x.falta_depositar <> 0;
comment on view public.v_stripe_pagos is 'p1: los pagos en línea con su estado (en camino, cobrado, en el depósito, depositado, devuelto, en disputa, falló, por resolver) y lo que falta depositar.';

-- Los depósitos de Stripe a Chase (120 días, más los no terminados).
create view public.v_stripe_payouts with (security_invoker = true) as
with cfg as (select * from public.stripe_config where id = 1),
     hoy as (select (now() at time zone 'America/New_York')::date as d),
     x as (select p.*, cb.casado_id, cb.movimiento_id, cb.regla as casado_regla, cb.automatico as casado_automatico
             from public.stripe_payouts p
             cross join cfg
             left join lateral (select bc.id as casado_id, bc.movimiento_id, bc.regla, bc.automatico
                                  from public.asiento_lineas al
                                  join public.banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden
                                                                     and bcl.vigente
                                  join public.banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                                 where al.asiento_id = p.asiento_llegada and al.cuenta = cfg.cuenta_banco
                                 limit 1) cb on true)
select x.id, x.po, x.estado,
       case when x.estado = 'asentado' and x.casado_id is not null then 'casado' else x.estado end as estado_pantalla,
       x.estado_stripe, x.monto, x.llegada, x.bruto, x.comisiones, x.vuelve, x.fuera, x.otros, x.n_pagos, x.fecha_asiento,
       (select a.numero from public.asientos a where a.id = x.asiento_salida) as asiento_salida_num,
       (select a.numero from public.asientos a where a.id = x.asiento_llegada) as asiento_llegada_num,
       (select a.numero from public.asientos a where a.id = x.asiento_vuelta) as asiento_vuelta_num,
       exists (select 1 from public.asientos r
                where r.reversa_a in (x.asiento_salida, x.asiento_llegada, x.asiento_vuelta) and r.camino = 'reverso'
                  and r.id is distinct from x.reverso_llegada) as reversado,
       x.movimiento_id, m.fecha as movimiento_fecha, m.descripcion as movimiento_descripcion, x.casado_regla, x.casado_automatico,
       case when x.estado = 'asentado' and x.casado_id is null
            then coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'fecha', c.fecha, 'descripcion', c.descripcion)
                                            order by c.fecha, c.id)
                             from public.movimientos_banco c cross join cfg
                            where c.cuenta = cfg.cuenta_banco and c.estado = 'pendiente' and c.monto = x.monto
                              and c.fecha between x.llegada - 3 and x.llegada + 5), '[]'::jsonb)
            else '[]'::jsonb end as candidatos,
       case when x.estado = 'asentado' and x.casado_id is null then hoy.d - x.llegada end as dias_sin_casar,
       x.revisar, x.esperando,
       coalesce((select jsonb_agg(jsonb_build_object('txn', l.txn, 'tipo', l.tipo, 'clase', l.clase, 'monto', l.monto,
                                                     'comision', l.comision, 'neto', l.neto, 'factura_num', s.factura_num, 'pi', l.pi,
                                                     'cuenta', l.cuenta)
                                  order by l.clase, l.txn)
                   from public.stripe_payout_lineas l
                   left join public.stripe_pagos s on s.id = l.pago_id
                  where l.payout_id = x.id), '[]'::jsonb) as lineas,
       x.creado_el
  from x
 cross join hoy
  left join public.movimientos_banco m on m.id = x.movimiento_id
 where x.llegada > hoy.d - 120
    or x.estado not in ('asentado', 'fallido')
    or (x.estado = 'asentado' and x.casado_id is null);
comment on view public.v_stripe_payouts is 'p1: los depósitos de Stripe a Chase con su composición, sus asientos y su casado con el movimiento de Chase (o los candidatos).';

create view public.v_stripe_avisos with (security_invoker = true) as
select a.id, a.nivel, a.texto, a.objeto, a.creado_el, a.repetido_el, a.veces
  from public.stripe_avisos a
 where a.visto_el is null
 order by case a.nivel when 'bad' then 0 when 'warn' then 1 else 2 end, a.creado_el desc;
comment on view public.v_stripe_avisos is 'p1: los avisos de los cobros en línea que Edgar no ha visto (los graves primero).';

create view public.v_stripe_eventos with (security_invoker = true) as
select e.id, e.tipo, e.estado, e.por, e.recibido_el, e.veces, e.intentos, e.proximo_intento, e.hecho_el, e.ultimo_error
  from public.stripe_eventos e
 order by e.recibido_el desc
 limit 100;
comment on view public.v_stripe_eventos is 'p1: los últimos 100 avisos de Stripe (sin sus datos).';

-- EL CONTROL de los cobros en línea (orden, control, nivel, ok, filas,
-- esperadas, detalle). Un «cuadre» en rojo: la pantalla no pinta números.
-- Una «alarma» en rojo: la lista amarilla de arriba.
create view public.v_stripe_control with (security_invoker = true) as
with cfg as (select * from public.stripe_config where id = 1),
     hoy as (select (now() at time zone 'America/New_York')::date as d),
     -- los asientos de p1 que pueden tocar la puente y la de paso
     ases as (select q.asiento_salida as id from public.stripe_payouts q where q.asiento_salida is not null
              union select q.asiento_llegada from public.stripe_payouts q where q.asiento_llegada is not null
              union select q.asiento_vuelta from public.stripe_payouts q where q.asiento_vuelta is not null
              union select (r->>'asiento')::uuid from public.stripe_payouts q, jsonb_array_elements(q.rehechos) r),
     vivo as (select a.id, a.numero from public.asientos a
               where not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico')))
select z.orden, z.control, z.nivel, z.ok, z.filas, z.esperadas, z.detalle
  from cfg
 cross join hoy
 cross join lateral (
   select 10 as orden, 'vista: v_stripe_facturas'::text as control, 'cuadre'::text as nivel, true as ok,
          (select count(*) from public.v_stripe_facturas) as filas, (select count(*) from public.v_stripe_facturas) as esperadas,
          null::text as detalle
   union all
   select 11, 'vista: v_stripe_pagos', 'cuadre', true, (select count(*) from public.v_stripe_pagos),
          (select count(*) from public.v_stripe_pagos), null
   union all
   select 12, 'vista: v_stripe_payouts', 'cuadre', true, (select count(*) from public.v_stripe_payouts),
          (select count(*) from public.v_stripe_payouts), null
   union all
   -- 20: toda línea de la puente es de un cobro o una devolución de p1, de
   -- P1 o P3 (o uno rehecho), o el reverso de uno de esos
   select 20, 'stripe: la puente solo la mueve Stripe', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n,
                  left(string_agg(distinct a.numero || ' (' || a.descripcion || ')', '; '), 1500) as d
             from public.asiento_lineas l
             join public.asientos a on a.id = l.asiento_id
            where l.cuenta = cfg.cuenta_puente
              and not (   (a.origen_tabla = 'cobros' and a.origen_id in (select pl.cobro_id::text from public.stripe_pago_libro pl
                                                                          where pl.accion = 'cobro'))
                       or (a.origen_tabla = 'cobros_devoluciones'
                           and a.origen_id in (select pl.devolucion_id::text from public.stripe_pago_libro pl
                                                where pl.accion = 'devolucion' and pl.devolucion_id is not null))
                       or a.id in (select ases.id from ases)
                       or a.reversa_a in (select ases.id from ases))) t
   union all
   -- 21: la puente = lo que falta depositar (+ lo que volvió de un depósito
   -- fallido y no ha liquidado otro)
   select 21, 'stripe: la puente = lo que falta depositar', 'cuadre', t.saldo = t.falta + t.vueltos, null, null,
          format('la %s tiene %s; lo que falta depositar suma %s y lo vuelto sin liquidar %s (diferencia %s)', cfg.cuenta_puente, t.saldo,
                 t.falta, t.vueltos, t.saldo - t.falta - t.vueltos)
     from (select (select coalesce(sum(l.monto), 0) from public.asiento_lineas l where l.cuenta = cfg.cuenta_puente) as saldo,
                  (select coalesce(sum(v.falta_depositar), 0) from public.v_stripe_pagos v) as falta,
                  (select coalesce(sum(q.monto - coalesce((select sum(l2.monto) from public.stripe_payout_lineas l2
                                                             join public.stripe_payouts q2 on q2.id = l2.payout_id
                                                            where l2.clase = 'vuelve' and l2.fuente = q.po
                                                              and q2.asiento_salida in (select vivo.id from vivo)), 0)), 0)
                     from public.stripe_payouts q
                    where q.estado = 'fallido' and q.asiento_vuelta in (select vivo.id from vivo)) as vueltos) t
   union all
   select 22, format('stripe: ningún cobro sin depositar de más de %s días', cfg.dias_sin_deposito), 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(v.pi || ' (' || coalesce('#' || v.factura_num, 'sin factura') || ', '
                                                 || v.falta_depositar || ')', '; '), 1500) as d
             from public.v_stripe_pagos v
            where v.falta_depositar <> 0 and coalesce(v.ultimo_cambio_el, (v.creado_el at time zone 'America/New_York')::date)
                                             < hoy.d - cfg.dias_sin_deposito) t
   union all
   -- 23: la de paso, en cero y solo con asientos de p1
   select 23, 'stripe: la cuenta de paso en cero', 'cuadre', t.saldo = 0 and t.ajenas = 0, t.ajenas, 0,
          format('la %s tiene %s%s', cfg.cuenta_paso, t.saldo, coalesce('; ajenos: ' || t.d, ''))
     from (select coalesce(sum(l.monto), 0) as saldo,
                  count(*) filter (where not (a.id in (select ases.id from ases) or a.reversa_a in (select ases.id from ases))) as ajenas,
                  left(string_agg(distinct a.numero, ', ') filter (where not (a.id in (select ases.id from ases)
                                                                              or a.reversa_a in (select ases.id from ases))), 1500) as d
             from public.asiento_lineas l
             join public.asientos a on a.id = l.asiento_id
            where l.cuenta = cfg.cuenta_paso) t
   union all
   select 24, 'stripe: cada depósito pagado está en el libro', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(q.po || ' (' || q.estado || ')', '; '), 1500) as d
             from public.stripe_payouts q
            where q.estado_stripe = 'paid' and q.asiento_llegada is null and q.llegada < hoy.d - 1) t
   union all
   -- 25: ningún P1, P2 o P3 con un reverso que no puso p1
   select 25, 'stripe: ningún asiento de Stripe reversado a mano', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(q.po || ': ' || o.numero || ' reversado con ' || r.numero, '; '), 1500) as d
             from public.stripe_payouts q
             join public.asientos o on o.id in (q.asiento_salida, q.asiento_llegada, q.asiento_vuelta)
             join public.asientos r on r.reversa_a = o.id and r.camino = 'reverso'
            where r.id is distinct from q.reverso_llegada) t
   union all
   select 26, 'stripe: cada depósito casa con Chase', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(v.po || ' (llegó el ' || v.llegada || ')', '; '), 1500) as d
             from public.v_stripe_payouts v
            where v.estado = 'asentado' and v.estado_pantalla <> 'casado' and v.llegada < hoy.d - 5) t
   union all
   -- 27: un depósito STRIPE de Chase casado con otra cosa (resuelto a mano
   -- en la bandeja: el dinero estaría dos veces)
   select 27, 'stripe: ningún depósito STRIPE casado con otra cosa', 'cuadre', t.n = 0, t.n, 0,
          case when t.n > 0 then t.d || ': se resolvió a mano en la bandeja y el dinero estaría dos veces; des-cásalo' end
     from (select count(*) as n, left(string_agg(m.fecha || ' ' || m.monto || ' «' || coalesce(m.descripcion, '') || '»', '; '), 1500) as d
             from public.movimientos_banco m
             join public.banco_casados bc on bc.id = m.casado_id and bc.deshecho_el is null
            where m.cuenta = cfg.cuenta_banco and m.monto > 0 and m.desc_norm ~* '(^| )STRIPE( |$)'
              and m.fecha >= (cfg.desde at time zone 'America/New_York')::date
              and not exists (select 1 from public.banco_casado_lineas bcl
                                join public.stripe_payouts q on q.asiento_llegada = bcl.asiento_id
                                join public.asiento_lineas al on al.asiento_id = bcl.asiento_id and al.orden = bcl.orden
                               where bcl.casado_id = bc.id and bcl.vigente and al.cuenta = cfg.cuenta_banco)) t
   union all
   -- 28: el cobro vivo de cada pago sigue vivo y dice lo que hay en el libro
   select 28, 'stripe: cada cobro de Stripe sigue vivo', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(y.que, '; '), 1500) as d
             from (select s.pi || ': ' ||
                          case when s.cobro_id is null then format('sin cobro y el libro dice %s', s.en_libro)
                               when c.id is null then 'su cobro ya no existe'
                               when c.estado <> 'vigente' then 'su cobro está anulado'
                               when exists (select 1 from public.cobros_devoluciones dv where dv.cobro_id = c.id)
                                 then 'su cobro está devuelto'
                               when c.contabilizado_en is null or c.contabilizado_en not in (select vivo.id from vivo)
                                 then 'su cobro no tiene asiento vivo'
                               when c.monto <> s.en_libro then format('su cobro es de %s y el libro dice %s', c.monto, s.en_libro)
                               else format('el rastro suma %s y el libro dice %s',
                                           (select coalesce(sum(pl.monto), 0) from public.stripe_pago_libro pl where pl.pago_id = s.id),
                                           s.en_libro) end as que
                     from public.stripe_pagos s
                     left join public.cobros c on c.id = s.cobro_id
                    where (s.cobro_id is null and s.en_libro <> 0)
                       or (s.cobro_id is not null
                           and (c.id is null or c.estado <> 'vigente'
                                or exists (select 1 from public.cobros_devoluciones dv where dv.cobro_id = c.id)
                                or c.contabilizado_en is null or c.contabilizado_en not in (select vivo.id from vivo)
                                or c.monto <> s.en_libro))
                       or s.en_libro <> (select coalesce(sum(pl.monto), 0) from public.stripe_pago_libro pl where pl.pago_id = s.id)
                   union all
                   select 'la devolución ' || coalesce(pl.devolucion_id::text, '?') || ' del cobro ' || pl.cobro_id
                          || ' no está (o no está en el libro)'
                     from public.stripe_pago_libro pl
                     left join public.cobros_devoluciones dv on dv.id = pl.devolucion_id
                    where pl.accion = 'devolucion'
                      and (dv.id is null or dv.contabilizado_en is null or dv.contabilizado_en not in (select vivo.id from vivo))) y) t
   union all
   select 29, 'stripe: ningún aviso de Stripe sin procesar', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(e.id || ' (' || e.tipo || ', ' || e.estado || ')', '; '), 1500) as d
             from public.stripe_eventos e
            where (e.estado = 'recibido' and e.recibido_el < now() - interval '15 minutes')
               or e.estado in ('reintentar', 'revisar')) t
   union all
   select 30, 'stripe: ningún pago por resolver', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(s.pi || ': ' || coalesce(s.revisar, '?'), '; '), 1500) as d
             from public.stripe_pagos s where s.estado = 'revisar') t
   union all
   select 31, 'stripe: pagos por cuenta de banco a tiempo', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(s.pi || ' (' || s.estado || ' desde el '
                                                 || (s.creado_el at time zone 'America/New_York')::date || ')', '; '), 1500) as d
             from public.stripe_pagos s
            where (s.estado = 'en_camino' and (s.creado_el at time zone 'America/New_York')::date < hoy.d - 10)
               or (s.estado = 'iniciado' and (s.creado_el at time zone 'America/New_York')::date < hoy.d - 12)) t
   union all
   select 32, 'stripe: la revisión automática corre', 'alarma',
          not (cfg.rutina_activa and cfg.desde < now() - interval '2 hours'
               and (cfg.ultimo_barrido_el is null or cfg.ultimo_barrido_el < now() - interval '2 hours')),
          null, null,
          case when cfg.ultimo_barrido_el is null then 'nunca ha corrido' else 'la última fue el ' || cfg.ultimo_barrido_el::text end
   union all
   select 33, 'stripe: Plaid no trae la puente ni la paso', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(coalesce(pc.institucion, pc.item_id) || ' → ' || (x->>'cuenta'), '; '), 1500) as d
             from public.plaid_conexiones pc
            cross join lateral jsonb_array_elements(pc.cuentas) x
            where pc.estado <> 'desconectada' and x->>'cuenta' in (cfg.cuenta_puente, cfg.cuenta_paso)) t
   union all
   -- 34: las protecciones de p1 (como el cuadre 90 de c6 y «permisos» de c2)
   select 34, 'stripe: protecciones de p1', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(y.que, '; '), 1500) as d
             from (select p.oid::regprocedure::text || ' es SECURITY DEFINER' as que
                     from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_stripe%' and p.prosecdef
                   union all
                   select p.oid::regprocedure::text || ' la puede ejecutar ' || r.r
                     from pg_proc p cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
                    where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_stripe%'
                      and has_function_privilege(r.r, p.oid, 'execute')
                   union all
                   select c.relname || ' sin RLS'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                      and c.relname like 'stripe\_%' and not c.relrowsecurity
                   union all
                   select c.relname || ' no tiene una sola policy «' || c.relname || '_dueno»'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'stripe\_%'
                      and ((select count(*) from pg_policy pl where pl.polrelid = c.oid) <> 1
                           or not exists (select 1 from pg_policy pl where pl.polrelid = c.oid and pl.polname = c.relname || '_dueno'
                                             and pl.polcmd = 'r' and pl.polpermissive))
                   union all
                   select format('%s puede %s en %s', r.r, q.q, c.relname)
                     from pg_class c
                    cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
                    cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
                    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'stripe\_%'
                      and has_table_privilege(r.r, c.oid, q.q)
                   union all
                   select format('%s puede leer %s', r.r, c.relname)
                     from pg_class c cross join (values ('anon'), ('service_role')) r(r)
                    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v') and c.relname ~ '^v?_?stripe_'
                      and has_table_privilege(r.r, c.oid, 'SELECT')
                   union all
                   select format('%s puede usar la secuencia %s', r.r, c.relname)
                     from pg_class c cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
                    where c.relnamespace = 'public'::regnamespace and c.relkind = 'S' and c.relname like 'stripe\_%'
                      and has_sequence_privilege(r.r, c.oid, 'USAGE')
                   union all
                   select c.relname || ' sin security_invoker'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname like 'v\_stripe\_%'
                      and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                         where o.option_name = 'security_invoker'), false)
                   union all
                   select 'un trigger en ' || c.relname || ': ' || t.tgname
                     from pg_trigger t join pg_class c on c.oid = t.tgrelid
                    where not t.tgisinternal and c.relnamespace = 'public'::regnamespace and c.relname like 'stripe\_%') y) t
   union all
   select 35, 'stripe: enlaces vivos al día', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg('#' || e.factura_num || ': ' || y.que, '; '), 1500) as d
             from public.stripe_enlaces e
             join public.facturas f on f.id = e.factura_id
            cross join lateral (select case
                                         when e.estado = 'creando' and e.creado_el < now() - interval '1 hour'
                                           then 'se quedó creándose'
                                         when e.estado = 'activo' and f.estado = 'anulada' then 'la factura está anulada'
                                         when e.estado = 'activo'
                                              and (select coalesce(sum(l.monto) filter (where l.cuenta = (select pc.cuenta from public.puente_cuentas pc
                                                                                                           where pc.rol = 'cxc')), 0)
                                                          + case when e.con_retencion
                                                                 then coalesce(sum(l.monto) filter (where l.cuenta = (select pc.cuenta
                                                                                                                       from public.puente_cuentas pc
                                                                                                                      where pc.rol = 'retencion_cxc')), 0)
                                                                 else 0 end
                                                     from public.asiento_lineas l
                                                    where l.partida_tabla = 'facturas' and l.partida_id = e.factura_id::text) < e.monto
                                           then 'la factura ya debe menos que el enlace' end as que) y
            where y.que is not null) t
   union all
   -- 36: las cuentas de Stripe, con su forma y su fila de los estados. La
   --     forma se lee de la fila entera (to_jsonb(c) @> …), no columna por
   --     columna: una vista que nombra cuentas.activa o cuentas.saldo_normal
   --     no deja reescribirlas con ALTER TABLE … TYPE, y c2-pruebas (la 66)
   --     lo hace a propósito para ver que c2 lo delata.
   select 36, 'stripe: las cuentas de Stripe en su sitio', 'cuadre', t.d is null, null, null, t.d
     from (select nullif(concat_ws('; ',
                    case when not exists (select 1 from public.cuentas c
                                           where c.codigo = cfg.cuenta_puente and left(c.codigo, 2) = '10'
                                             and to_jsonb(c) @> jsonb_build_object('activa', true, 'imputable', true, 'tipo', 'activo',
                                                                                   'saldo_normal', 'debe', 'regla_obra', 'prohibida',
                                                                                   'regla_cost_code', 'prohibida', 'padre', null))
                         then format('la puente %s no está como p1 la dejó (activa, deudora, sin obra, 10xx)', cfg.cuenta_puente) end,
                    case when not exists (select 1 from public.cuentas c
                                           where c.codigo = cfg.cuenta_paso and left(c.codigo, 2) <> '10'
                                             and to_jsonb(c) @> jsonb_build_object('activa', true, 'imputable', true, 'tipo', 'activo',
                                                                                   'saldo_normal', 'debe', 'regla_obra', 'prohibida',
                                                                                   'regla_cost_code', 'prohibida', 'padre', null))
                         then format('la de paso %s no está como p1 la dejó (activa, deudora, sin obra, fuera de 10xx)', cfg.cuenta_paso) end,
                    case when not exists (select 1 from public.cuentas c
                                           where c.codigo = cfg.cuenta_comisiones
                                             and to_jsonb(c) @> jsonb_build_object('activa', true, 'imputable', true))
                         then format('la de comisiones %s no está activa', cfg.cuenta_comisiones) end,
                    case when not exists (select 1 from public.cuentas c
                                           where c.codigo = cfg.cuenta_banco and left(c.codigo, 2) = '10'
                                             and to_jsonb(c) @> jsonb_build_object('activa', true, 'imputable', true))
                         then format('el banco %s no está activo', cfg.cuenta_banco) end,
                    case when not exists (select 1 from public.estados_mapeo em where em.cuenta = cfg.cuenta_puente)
                           or not exists (select 1 from public.estados_mapeo em where em.cuenta = cfg.cuenta_paso)
                         then 'falta su fila de los estados (select fn_estados_mapeo_derivar();)' end), '') as d) t
   union all
   select 37, 'stripe: nadie concilia la puente ni la paso', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(c.cuenta || ' al ' || c.fecha_corte || ' (' || c.estado || ')', '; '), 1500) as d
             from public.conciliaciones c where c.cuenta in (cfg.cuenta_puente, cfg.cuenta_paso)) t
   union all
   select 38, 'stripe: depósitos esperando o por revisar', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(q.po || ' (' || q.estado || coalesce(': ' || q.revisar, '') || ')', '; '), 1500) as d
             from public.stripe_payouts q
            where q.estado in ('esperando_composicion', 'esperando_cobros', 'revisar') and q.creado_el < now() - interval '2 days') t
   union all
   select 39, 'stripe: llave de prueba', 'alarma', not (coalesce(cfg.modo, '') = 'prueba' and not cfg.acepta_prueba), null, null,
          case when cfg.modo = 'prueba' and not cfg.acepta_prueba
               then 'la función tiene una llave de prueba (rk_test_): en producción no entra nada; pon la real (rk_live_)' end
 ) z;
comment on view public.v_stripe_control is 'p1: el control de los cobros en línea: cuadres (si uno sale en rojo, la pantalla no pinta) y alarmas.';

-- El estado de la conexión, en una fila.
create view public.v_stripe_estado with (security_invoker = true) as
with ctl as (select count(*) filter (where c.nivel = 'cuadre' and not c.ok) as rojos,
                    count(*) filter (where c.nivel = 'alarma' and not c.ok) as alarmas
               from public.v_stripe_control c),
     pg as (select coalesce(sum(v.falta_depositar), 0)::numeric(14,2) as falta, count(*) filter (where v.falta_depositar <> 0) as n_falta
              from public.v_stripe_pagos v)
select true as instalado, c.modo, c.acepta_prueba, c.dueno, c.desde, c.funcion_url, c.rutina_activa,
       c.cuenta_puente, (select x.nombre from public.cuentas x where x.codigo = c.cuenta_puente) as cuenta_puente_nombre,
       c.cuenta_paso, c.cuenta_comisiones, c.cuenta_banco,
       (select coalesce(sum(l.monto), 0) from public.asiento_lineas l where l.cuenta = c.cuenta_puente)::numeric(14,2) as saldo_puente,
       (select coalesce(sum(l.monto), 0) from public.asiento_lineas l where l.cuenta = c.cuenta_paso)::numeric(14,2) as saldo_paso,
       pg.falta as por_depositar, pg.n_falta as n_por_depositar,
       (select coalesce(sum(q.monto - coalesce((select sum(l2.monto) from public.stripe_payout_lineas l2
                                                  join public.stripe_payouts q2 on q2.id = l2.payout_id
                                                 where l2.clase = 'vuelve' and l2.fuente = q.po and q2.asiento_salida is not null), 0)), 0)
          from public.stripe_payouts q where q.estado = 'fallido')::numeric(14,2) as vueltos_sin_liquidar,
       (select coalesce(sum(s.monto), 0) from public.stripe_pagos s where s.estado in ('iniciado', 'en_camino'))::numeric(14,2)
         as en_camino_monto,
       (select count(*) from public.stripe_pagos s where s.estado in ('iniciado', 'en_camino')) as en_camino_n,
       (select count(*) from public.stripe_enlaces e where e.estado = 'activo') as enlaces_activos,
       c.ultimo_evento_el, c.ultimo_evento_tipo,
       (select count(*) from public.stripe_eventos e where e.estado in ('recibido', 'reintentar')) as eventos_pendientes,
       (select count(*) from public.stripe_eventos e where e.estado = 'revisar') as eventos_revisar,
       c.ultimo_barrido_el, c.ultimo_barrido_completo_el, c.ultimo_error, c.ultimo_error_el,
       (select count(*) from public.stripe_avisos a where a.visto_el is null) as avisos_abiertos,
       (select count(*) from public.stripe_pagos s where s.estado = 'revisar') as pagos_revisar,
       (select count(*) from public.stripe_payouts q where q.estado in ('en_camino', 'esperando_composicion', 'esperando_cobros', 'revisar'))
         as payouts_pendientes,
       ctl.rojos as cuadres_rojos, ctl.alarmas
  from public.stripe_config c
 cross join ctl
 cross join pg
 where c.id = 1;
comment on view public.v_stripe_estado is 'p1: el estado de los cobros en línea en una fila (la tarjeta de Bancos y tarjetas).';

do $$
declare
  v text;
begin
  foreach v in array array['v_stripe_estado', 'v_stripe_control', 'v_stripe_facturas', 'v_stripe_pagos', 'v_stripe_payouts',
                           'v_stripe_avisos', 'v_stripe_eventos'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
    execute format('grant select on public.%I to authenticated', v);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 10. Lo demás que pide la función de borde
-- ---------------------------------------------------------------------
create or replace function public.fn_stripe_aviso_visto(p_aviso bigint, p_dueno uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a stripe_avisos;
begin
  perform fn_stripe_exigir();
  perform fn_stripe_dueno_fijar(p_dueno);
  update stripe_avisos set visto_el = now(), visto_por = p_dueno where id = p_aviso returning * into a;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese aviso.';
  end if;
  return to_jsonb(a);
end $$;
revoke execute on function public.fn_stripe_aviso_visto(bigint, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_stripe_aviso_visto(bigint, uuid) is 'p1: Edgar vio un aviso («Entendido»).';

create or replace function public.fn_stripe_resumen() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  return jsonb_build_object(
    'config', (select to_jsonb(c) from stripe_config c where c.id = 1),
    'estado', (select to_jsonb(e) from v_stripe_estado e),
    'control_rojo', coalesce((select jsonb_agg(to_jsonb(x) order by x.orden) from v_stripe_control x where not x.ok), '[]'::jsonb));
end $$;
revoke execute on function public.fn_stripe_resumen() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_resumen() is 'p1: la configuración (sin secretos: no hay), el estado y lo que el control tiene en rojo.';

create or replace function public.fn_stripe_control()
returns table (orden int, control text, nivel text, ok boolean, filas bigint, esperadas bigint, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_stripe_exigir();
  return query select c.orden, c.control, c.nivel, c.ok, c.filas, c.esperadas, c.detalle from v_stripe_control c order by c.orden;
end $$;
revoke execute on function public.fn_stripe_control() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_control() is 'p1: el control de los cobros en línea (v_stripe_control), para la función de borde y el SQL Editor.';

-- La rutina (pg_cron → pg_net → la función de borde, acción barrer).
create or replace function public.fn_stripe_programado() returns bigint
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_url text;
  v_sec text;
  v_id  bigint;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'La rutina de Stripe la dispara pg_cron (o el SQL Editor).';
  end if;
  select funcion_url into v_url from stripe_config where id = 1 and rutina_activa;
  if v_url is null then return null; end if;
  select s.decrypted_secret into v_sec from vault.decrypted_secrets s where s.name = 'stripe_rutina_secreto';
  if v_sec is null then
    raise exception using errcode = 'MX009', message = 'Falta el secreto stripe_rutina_secreto en Vault: vuelve a pegar p1-stripe.sql.';
  end if;
  select net.http_post(url := v_url,
                       body := jsonb_build_object('accion', 'barrer'),
                       headers := jsonb_build_object('Content-Type', 'application/json', 'x-mxp-rutina', v_sec),
                       timeout_milliseconds := 60000)
    into v_id;
  return v_id;
end $$;
revoke execute on function public.fn_stripe_programado() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_programado() is 'p1: la rutina de Stripe (pg_cron cada 15 min → pg_net POST a la función de borde con el secreto de Vault, acción barrer).';

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'mxp-stripe-barrer';
    -- cada 15 minutos, a los 7, 22, 37 y 52 (lejos de la de Plaid, a las 11:00 UTC)
    perform cron.schedule('mxp-stripe-barrer', '7-59/15 * * * *', 'select public.fn_stripe_programado()');
  end if;
end $$;

-- Lo que debe verse al pegar (va en una función porque cron.job solo
-- existe donde hay pg_cron: producción sí, el banco de pruebas no).
create or replace function public.fn_stripe_pegado() returns table (que text, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c     stripe_config;
  v_alt text := coalesce(current_setting('mxp.p1_alta', true), '');
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from stripe_config where id = 1;
  return query select 'stripe_config'::text,
                      format('%s · modo %s · acepta prueba: %s', c.funcion_url, coalesce(c.modo, 'sin avisos todavía'),
                             case when c.acepta_prueba then 'sí (solo el banco de pruebas)' else 'no' end);
  return query select format('cuenta %s · %s', x.codigo, x.nombre),
                      format('%s · %s / %s', case when x.codigo = any (string_to_array(v_alt, ',')) then 'creada' else 'ya estaba' end,
                             coalesce(m.seccion, 'sin fila de los estados'), coalesce(m.linea, '-'))
                 from cuentas x left join estados_mapeo m on m.cuenta = x.codigo
                where x.codigo in (c.cuenta_puente, c.cuenta_paso)
                order by x.codigo;
  return query select 'dueño'::text, coalesce((select p.nombre || ' · ' || p.id from perfiles p where p.id = c.dueno), c.dueno::text);
  return query select 'stripe_rutina_secreto (cópialo a STRIPE_RUTINA_SECRETO)'::text, s.decrypted_secret
                 from vault.decrypted_secrets s where s.name = 'stripe_rutina_secreto';
  return query select 'URL del webhook'::text, c.funcion_url;
  return query select 'versión de API'::text, c.version_api;
  return query select 'eventos (márcalos en Stripe)'::text,
    'checkout.session.completed, checkout.session.async_payment_succeeded, checkout.session.async_payment_failed, '
    'payment_intent.processing, payment_intent.succeeded, payment_intent.payment_failed, payment_intent.canceled, charge.refunded, '
    'refund.created, refund.updated, refund.failed, charge.dispute.created, charge.dispute.funds_withdrawn, '
    'charge.dispute.funds_reinstated, charge.dispute.closed, payout.paid, payout.failed, payout.canceled, '
    'payout.reconciliation_completed, payment_link.updated'::text;
  return query select 'permisos de la llave'::text,
    'Llave RESTRINGIDA (rk_live_…), todo en None salvo: Payment Links = Write · Checkout Sessions = Read · PaymentIntents = Read · '
    'Charges = Read · Refunds = Read · Disputes = Read · Payouts = Read · Balance = Read · Balance transaction sources = Read · '
    'Events = Read (si al crear el primer enlace pide rak_product_write o rak_price_write: Products o Prices = Write)'::text;
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    return query execute $q$ select 'rutina pg_cron'::text, coalesce((select j.schedule from cron.job j where j.jobname = 'mxp-stripe-barrer'), 'sin programar') $q$;
  else
    return query select 'rutina pg_cron'::text, 'sin pg_cron en esta base'::text;
  end if;
  return query select 'control'::text,
                      format('%s cuadres rojos · %s alarmas',
                             (select count(*) from v_stripe_control x where x.nivel = 'cuadre' and not x.ok),
                             (select count(*) from v_stripe_control x where x.nivel = 'alarma' and not x.ok));
end $$;
revoke execute on function public.fn_stripe_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_stripe_pegado() is 'p1: lo que enseña el final del pegado: la configuración, las cuentas, el dueño, el secreto de la rutina, el webhook, la versión, los eventos, los permisos de la llave, la rutina y el control.';

select * from public.fn_stripe_pegado();
