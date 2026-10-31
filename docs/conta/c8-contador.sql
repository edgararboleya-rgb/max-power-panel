-- =====================================================================
-- c8-contador.sql — EL CONTADOR: LA IA QUE PROPONE Y NUNCA POSTEA · c8
-- 31-oct-2026, v1 (fase 7, el motor de reglas y la bandeja de propuestas).
-- Se pega en el SQL Editor DESPUÉS de c1, c2, c3, c4, c6, c7, s1 y p1.
-- Idempotente: se puede volver a pegar entero (no pisa la configuración,
-- ni las reglas que Edgar dicte o apruebe, ni una propuesta, ni nada de lo
-- que ya entró al libro).
--
-- Qué hace:
--   · LA BANDEJA DEL BANCO (c6) deja cada cargo sin ticket ni asiento que
--     lo explique con el motivo «sin_ticket» («di de qué es»). Hasta hoy
--     Edgar lo clasificaba a mano, uno por uno. Desde aquí, para cada uno
--     de esos cargos la base guarda UNA PROPUESTA (ia_propuestas): a qué
--     cuenta(s) va, con qué obra si la cuenta la pide, por qué (un motivo
--     de una frase que cita lo que se vio) y con qué confianza. Edgar la
--     aprueba con un toque («Así es»), la corrige («Según yo»: queda
--     «editada») o la rechaza («No es eso»). Nunca entra nada al libro sin
--     ese toque: ES LA PRIMERA REGLA DE LA IA (docs/CONTA-PLAN.md §4):
--     PROPONE, NUNCA POSTEA.
--   · DE DÓNDE SALE LA PROPUESTA, en este orden:
--       1. UNA REGLA (ia_reglas): «este comercio siempre va a esta cuenta».
--          Es un patrón (una expresión regular de Postgres, sin distinguir
--          mayúsculas) que se prueba contra la descripción normalizada del
--          banco (movimientos_banco.desc_norm), con sus líneas (una o
--          varias cuentas, con la fracción de cada una: la cuota del
--          vehículo partida en capital e interés). Las dicta Edgar
--          (fn_contador_regla_alta) o nacen solas de lo que aprueba
--          («Recordar para este comercio»: fn_contador_clasificar). Lo que
--          casa con una regla NO va a la IA: lo contesta Postgres, gratis
--          (la frontera de §4: «lo que se contesta con una resta lo
--          contesta la base»). Si casan varias, gana la más específica (el
--          patrón más largo); un empate no decide nada y se deja a la IA.
--       2. LA IA (claude-opus-5-5 con effort «low», por la función de borde
--          «contador»): para lo que ninguna regla alcanza. Se le da el
--          plan de cuentas PERMITIDO (abajo), las obras activas, las reglas
--          y los últimos ejemplos de lo que Edgar clasificó, y el movimiento
--          (fecha, monto, descripción, nota, cuenta del banco, tipo). La
--          base guarda lo que se le dio (entrada, congelado y sin datos
--          personales), lo que contestó tal cual (salida) y la propuesta ya
--          validada: cada cuenta existe, está activa, es imputable y está
--          entre las permitidas; la obra existe; de 1 a 5 líneas; la
--          confianza entre 0 y 1. Una respuesta que no pasa NO se guarda
--          (fn_contador_propuesta_guardar dice por qué): SEGUNDA REGLA,
--          CITA O SE CALLA. Y una ráfaga nunca arranca con el tope del mes
--          gastado (fn_contador_tope): TERCERA REGLA, TOPE DE GASTO.
--       3. EDGAR (fuente «edgar»): lo que clasifica por su cuenta desde la
--          bandeja, sin propuesta delante, deja también su fila, aprobada,
--          para que el rastro sea uno solo.
--   · EL ÚNICO CAMINO AL LIBRO es fn_contador_clasificar, y por dentro es
--     fn_banco_clasificar (c6), EN NOMBRE DEL DUEÑO, con todos sus frenos
--     («primero casar, después clasificar»; un depósito nunca a ingreso;
--     nunca a una cuenta propia, a 2010, a 1110, a mano de obra ni a
--     sueldo; el motivo escrito para el patrimonio del accionista): c8 no
--     postea nada por su cuenta y no tiene un camino propio al libro. El
--     asiento es el de c6 (origen movimientos_banco, camino puente); la
--     propuesta guarda su id (asiento_id) y el asiento dice en su
--     descripción y en su procedencia «Propuesta de la IA #<id> aprobada
--     por Edgar: <el motivo de la IA>». Así, abriendo el asiento, se ve
--     qué vio la IA, qué contestó tal cual y con qué versión del prompt
--     (ia_propuestas.entrada, salida, prompt_version): lo que pide la fase
--     7 al terminar.
--
-- LAS REGLAS FIJAS DE LA S-CORP que la IA no reinterpreta (f07; van
-- escritas en las instrucciones de la función de borde y aquí en las
-- cuentas permitidas):
--   (a) Todo pago al IRS por el impuesto sobre la renta de Edgar va a 3200
--       (distribuciones al accionista): no es gasto de la empresa. No
--       incluye al DOR de Florida: el sales tax y el RT-6 sí son de la
--       empresa (2300, 2230). La IA marca «irs» y propone 3200.
--   (b) Todo cargo personal en una cuenta de la empresa va a 3200 (una
--       distribución) o a 1130 (cuenta por cobrar al accionista, si Edgar
--       lo va a devolver). La IA marca «personal»; Edgar elige.
--   (c) El sueldo de Edgar entra solo por la nómina (6005, y su parte de
--       obra en 5001), nunca como una transferencia: 6000, 6005, 50xx no
--       están entre las cuentas que se proponen (c6 tampoco los deja
--       entrar desde el banco).
-- LA CAPITALIZACIÓN: una compra de 2,500.00 o más por unidad y con vida de
--   más de un año es un activo fijo (15xx), no un gasto: la IA marca
--   «capitalizable» y propone la cuenta; Edgar decide (la baja y la
--   depreciación son de f08).
-- EL USE TAX: una compra fuera de Florida (o de un comercio que no cobra
--   el impuesto) sin impuesto visible marca «use_tax»: en la v1 NO se
--   postea nada automático (ni el 7.5 % a 2300): Edgar lo ve en la
--   propuesta y lo resuelve con el recibo (e13b ya avisa del tope del
--   surtax). Lo que llega con su ticket no pasa por aquí.
--
-- LAS CUENTAS PERMITIDAS (v_contador_cuentas, una sola fuente para la IA,
-- la validación, el selector «Según yo» de la pantalla y el cuadre 62):
-- las imputables y activas de tipo costo, gasto, otro_gasto, activo y
-- pasivo, más 3200 (y 1130, que es activo) del patrimonio, ordenadas por
-- código. Fuera: los bancos y la caja (10xx: el dinero entre cuentas
-- propias es una transferencia, c6), 1110 y 1120 (lo que se cobra entra
-- por su cobro), 1020 y 1140 (las de Stripe, p1), 2010 (a un proveedor se
-- le aplica a sus partidas) y las tarjetas 2100-xxxx; 6000, 6005, 6010 y
-- todo 50xx (sueldo, mano de obra y burden: solo por el journal de
-- nómina), 6950 y 6980 (depreciación e incobrables: los pone el cierre),
-- 1200, 2400, 2410 y 5950 (el WIP de f10), 2050 (el devengo del cierre),
-- las contra-cuentas (1190, 1590, 5011) y el resto del patrimonio (3000,
-- 3100, 3900). Ningún ingreso: lo que entra del banco es el cobro de una
-- factura o un anticipo (c6), y la IA solo mira cargos. Lo que c6 rechaza
-- de todos modos desde el banco se queda fuera para que ninguna propuesta
-- se caiga al aprobarla.
--
-- Quién hace qué:
--   · LA FUNCIÓN DE BORDE «contador» (supabase/functions/contador/index.ts)
--     es la ÚNICA que habla con Anthropic, con la llave en los secretos de
--     Edge Functions (ANTHROPIC_API_KEY: una llave NUEVA, aparte de la del
--     estimador, para ver el gasto contable por separado). A ESTA BASE
--     entra directo, como postgres (SUPABASE_DB_URL), igual que la de
--     Stripe. Su ráfaga: 1) fn_contador_reglas_aplicar (lo que casa con una
--     regla ya queda propuesto, sin gastar); 2) fn_contador_tope (bloqueado
--     → no gasta); 3) fn_contador_pendientes (los movimientos y el
--     contexto); 4) fn_contador_lote_abrir, una llamada sola primero (crea
--     el caché del prefijo) y después de tres en tres, cada respuesta →
--     fn_contador_propuesta_guardar; 5) fn_contador_lote_cerrar con el uso
--     sumado (tokens de entrada, salida, caché creado y leído): la base
--     calcula los centavos y los anota en el gasto del mes. Una respuesta
--     «refusal» o cortada por max_tokens se cuenta y no se guarda; nunca
--     se cambia de modelo (solo Opus y Fable: ni Haiku ni Sonnet, en
--     ninguna parte; la base lo exige).
--   · EN NOMBRE DEL DUEÑO (como p1): c6 exige es_dueno(). Lo que Edgar
--     aprueba lo pide a la función de borde con su sesión en aal2 (el
--     código del teléfono); la función se lo pide a la base como postgres,
--     y las funciones de aquí fijan auth.uid() al dueño de ia_config
--     (request.jwt.claims y claim.sub, solo dentro de la transacción),
--     comprueban es_dueno() y lo sueltan al terminar. Queda escrito:
--     asientos.usuario_id dice el dueño, rol_bd dice postgres.
--   · LA APP solo LEE las vistas v_contador_* (el dueño). Todo lo que mueve
--     (proponer, aprobar, clasificar, rechazar, dar de alta o de baja una
--     regla) lo pide a la función de borde.
--
-- EL GASTO. La app ya tiene montado el tope de la IA: asistente_ajustes
-- (tope_mes_centavos, aviso_pct) y asistente_costo_mes (mes, accion,
-- llamadas, centavos), que en producción (y en el banco de pruebas) es una
-- VISTA sobre la tabla asistente_uso (docs/conta/ESQUEMA-REAL.md). Por
-- eso fn_contador_lote_cerrar anota cada lote donde toque: si
-- asistente_costo_mes es una tabla (una base sin la app: este archivo la
-- crea entonces, con la forma de la app), una fila por mes y acción con
-- «llamadas += n»; si es la vista de la app, una fila en asistente_uso
-- (accion «contador_categorizar», vueltas = las llamadas del lote, sus
-- tokens y sus centavos), que la vista suma. El tope mira siempre
-- asistente_costo_mes: los mismos números que la app enseña en «ojo, ya
-- vas por el 80 % del mes». Los centavos: (entrada × 400 + caché creado ×
-- 500 + caché leído × 20 + salida × 2000) / 1 000 000, redondeado: el
-- precio de claude-opus-5-5 por millón de tokens ($4 / $20, caché escrito
-- $5, leído $0.20), en céntimos de dólar. Dos topes: el global de la app
-- (todas las acciones del mes contra asistente_ajustes.tope_mes_centavos)
-- y el propio del contador (lo de «contador_%» contra
-- ia_config.tope_mes_centavos, 30.00 al mes de fábrica); y el interruptor
-- ia_config.activa.
--
-- Por qué ninguna función de aquí está en la API (la lección de c7 y p1):
-- c2 («permisos») y c6 («protecciones del banco», cuadre 90) toman por
-- ajena toda función SECURITY DEFINER que la API pueda ejecutar y que lea
-- el libro o el banco. Aquí ninguna fn_contador_* es SECURITY DEFINER ni
-- tiene EXECUTE para anon, authenticated ni service_role; la guarda de
-- todas es fn_contador_exigir() → fn_desde_editor() (c2): verdad para la
-- función de borde como postgres, para pg_cron y para el SQL Editor; falsa
-- para cualquier rol de la API. Ninguna lleva un prefijo que sellan otras
-- capas (fn_banco_%, fn_puente_%, fn_estados_%, fn_stripe_%, fn_plaid_%):
-- todas son fn_contador_% y las vistas v_contador_%. Ningún trigger en
-- ninguna tabla. Las vistas leen solo TABLAS (nunca v_banco_bandeja ni
-- otra vista de c3, c4, c6 o p1: esas se rehacen al volver a pegar su
-- archivo y se pararían con MX000); la excepción es asistente_costo_mes,
-- la vista de la app, que no se vuelve a pegar con las fases (si algún
-- día se rehace, antes «drop view v_contador_estado, v_contador_control»
-- y después se vuelve a pegar este archivo). Y ninguna vista nombra
-- cuentas.activa ni cuentas.saldo_normal por su nombre (se leen de la
-- fila entera, como c6 y p1: c2-pruebas las reescribe a propósito).
--
-- Decisiones de diseño (lo que el contrato dejaba abierto):
--   · «dudosa» no es hoy un motivo de la bandeja de c6 (los suyos:
--     sin_ticket, clasificar, pago_proveedor, ticket_en_bandeja…); se
--     acepta por si una versión de c6 lo trae, y se documenta. Lo que la
--     IA mira es «sin_ticket»: cargos (monto < 0) sin ticket ni asiento.
--   · EL NOMBRE DEL COMERCIO de una regla aprendida (fn_contador_nombre_
--     comercio): las primeras palabras de desc_norm hasta la primera que
--     trae un número (el número de tienda, el de confirmación, una fecha;
--     la primera palabra se conserva aunque lo traiga: «7 ELEVEN»), sin
--     «#», y sin la ciudad ni el estado del final (los estados de EE. UU. y
--     las ciudades de Florida que Edgar pisa; «WWW», «COM» sueltos). «THE
--     HOME DEPOT 6341 OCALA FL» → «THE HOME DEPOT». El patrón es «^» más
--     ese nombre escapado, tal cual pide el contrato (sin cierre de
--     palabra: «^SHELL» casa «SHELL OIL 57544» y también «SHELLFISH»; si
--     eso molesta, Edgar dicta la regla con su patrón).
--   · LAS PARTES. Una regla con varias líneas guarda la fracción de cada
--     una («parte», suman 1); al aplicarla, cada línea lleva su monto
--     (redondeado al centavo; la última absorbe el redondeo). Una regla
--     aprendida de una aprobación con varias líneas guarda las partes que
--     Edgar aprobó.
--   · UNA PROPUESTA RECHAZADA de una regla no se vuelve a proponer para ese
--     mismo movimiento (si no, cada ráfaga la repetiría); el movimiento
--     pasa a la IA.
--   · «APROBADA» es también la propuesta que pedía obra y Edgar completó
--     con ella (las cuentas coinciden y la obra se puso donde faltaba);
--     «editada» cuando cambia una cuenta o una obra que la IA sí dio.
--   · UNA PROPUESTA APROBADA CUYO ASIENTO SE REVERSA A MANO (des-casar en
--     la bandeja) pone en rojo el cuadre 60 hasta que Edgar la cierra
--     (fn_contador_caducar, con su motivo) o la base la cierra sola al
--     clasificar otra vez ese movimiento. Nada se borra: queda «caducada»
--     con su nota.
--   · LA ALARMA 73 («la llave y la función») mira la fecha del banco de
--     los movimientos que esperan (no su importado_el, que c6 no deja
--     tocar y las pruebas no podrían fingir): hay cargos de hace más de
--     dos días sin propuesta y ninguna ráfaga ha corrido nunca.
--   · LO QUE SE LE DA A LA IA no lleva correos, teléfonos ni números de
--     cuenta: fn_contador_sin_datos los tapa en la descripción, la nota y
--     en todo lo que se guarda en «entrada». Un nombre propio que el
--     banco escribe en su descripción (un Zelle a una persona) es parte de
--     la descripción del banco y va; la función de borde no manda nada
--     más.
--
-- Lo que este archivo NO toca: c1..c7, s1, p1, es_dueno(), docs/sql, las
-- tablas del banco (solo lee movimientos_banco y escribe en él POR c6),
-- asistente_ajustes de la app (solo crea las filas si faltan), el libro
-- (nunca fn_postear ni fn_postear_interno). No postea nada automático: ni
-- el use tax, ni la capitalización, ni una regla con confianza 1.
--
-- Cómo se instala (Edgar, en este orden, con la cadena c1..c7, s1 y p1 ya
-- pegada como dice pruebas/conta/README.md):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración (modelo, esfuerzo, activa, los topes), el
--      dueño, las cuatro tablas, las cuentas que se proponen, las reglas
--      activas, lo que espera en la bandeja sin propuesta, el control («0
--      cuadres rojos · n alarmas») y el paso siguiente. Si algo de lo que
--      da por hecho falta, para con MX000 y no queda nada.
--   2. SQL Editor → pegar docs/conta/c8-pruebas.sql → todas las filas en
--      true (el número lo dice su cabecera).
--   3. console.anthropic.com → API keys → «Create key» (una NUEVA, solo
--      para el contador) → Supabase → Edge Functions → Secrets →
--      ANTHROPIC_API_KEY. Nunca MXP_BANCO_PRUEBAS, MXP_DB_URL ni
--      ANTHROPIC_BASE_URL: son del banco de pruebas, y con ellos la
--      función no arranca.
--   4. La función «contador» (Verify JWT apagado) y …/contador?paso=salud:
--      ok, llave, base, modelo claude-opus-5-5, effort low, prompt_version
--      y el tope.
--   5. En la app: Contabilidad → Bandeja → «Proponer con la IA (n)»: la
--      primera ráfaga. Después, en Conexiones y seguridad → «IA contable
--      (fase 7)»: el gasto del mes, la última ráfaga y las reglas.
--   Para apagarla: update ia_config set activa = false where id = 1; (la
--   bandeja sigue como siempre, y las reglas también).
--
-- Lo que llama la función de borde (como postgres): fn_contador_cfg,
-- fn_contador_tope, fn_contador_reglas_aplicar, fn_contador_pendientes,
-- fn_contador_lote_abrir, fn_contador_propuesta_guardar,
-- fn_contador_lote_cerrar, fn_contador_aprobar, fn_contador_clasificar,
-- fn_contador_rechazar, fn_contador_caducar, fn_contador_regla_alta,
-- fn_contador_regla_baja, fn_contador_control, fn_contador_resumen y
-- fn_contador_dueno_fijar. Montos: en dólares, numeric(14,2); los tokens,
-- enteros; el gasto, en centavos enteros.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. La guarda, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- ¿Quién llama? La función de borde (como postgres), pg_cron o el SQL
-- Editor. Nadie de la API: se mira el rol de la llamada, no current_user.
create or replace function public.fn_contador_exigir() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_desde_editor() then return; end if;
  raise exception using errcode = '42501',
    message = 'Esto lo hace la función de borde «contador» (conectada como postgres), pg_cron o el SQL Editor; la app no.';
end $$;
revoke execute on function public.fn_contador_exigir() from public, anon, authenticated, service_role;
comment on function public.fn_contador_exigir() is 'c8: la guarda de todas las fn_contador_*: solo la función de borde (como postgres), pg_cron o el SQL Editor (fn_desde_editor).';

-- Lo que falta para pegar c8, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas (la 1).
create or replace function public.fn_contador_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_k     char;
begin
  foreach v_x in array array['fn_desde_editor()', 'es_dueno()', 'fn_fecha_miami(timestamptz)', 'fn_banco_clasificar(uuid,jsonb,text)',
                             'fn_banco_casar(uuid)', 'fn_banco_descasar(uuid,text)'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'proyectos', 'perfiles', 'asientos', 'asiento_lineas', 'movimientos_banco', 'banco_casados'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if to_regclass('public.v_banco_bandeja') is null then
    v_falta := v_falta || 'la vista v_banco_bandeja (c6)'::text;
  end if;
  if to_regclass('public.movimientos_banco') is not null
     and not exists (select 1 from information_schema.columns
                      where table_schema = 'public' and table_name = 'movimientos_banco' and column_name = 'desc_norm') then
    v_falta := v_falta || 'movimientos_banco.desc_norm (c6)'::text;
  end if;
  if cardinality(v_falta) > 0 then
    return format('c8 se pega después de c1, c2, c3, c4, c6, c7, s1 y p1: falta %s.', array_to_string(v_falta, ', '));
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: las propuestas se aprueban en su nombre.';
  end if;
  -- Dónde se anota el gasto: la tabla asistente_costo_mes (si no está, se
  -- crea aquí), o la vista de la app sobre asistente_uso (y entonces
  -- asistente_uso tiene que ser una tabla).
  select c.relkind into v_k from pg_class c where c.oid = to_regclass('public.asistente_costo_mes');
  if v_k = 'v' and (select r.relkind from pg_class r where r.oid = to_regclass('public.asistente_uso')) is distinct from 'r' then
    return 'asistente_costo_mes es una vista y no hay una tabla asistente_uso donde anotar el gasto: no sé dónde apuntar cada ráfaga.';
  elsif v_k is not null and v_k not in ('r', 'v') then
    return format('asistente_costo_mes existe pero no es una tabla ni una vista (relkind %s).', v_k);
  end if;
  -- Nada ajeno colgado de las vistas de c8 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname like 'v\_contador\_%'
     and dc.oid <> cv.oid and not (dc.relnamespace = 'public'::regnamespace and dc.relname like 'v\_contador\_%');
  if v_x is not null then
    return format('%s depende(n) de las vistas de c8, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, pega '
                  'c8 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_contador_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_contador_precondiciones() is 'c8: lo que falta para pegar c8-contador.sql (nulo = nada): c2 y c6, el SQL Editor, un dueño activo, dónde anotar el gasto y nada ajeno sobre las vistas v_contador_*.';

do $$
declare
  v text;
begin
  v := public.fn_contador_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c8-contador NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee, nadie de la API
--    escribe; todo entra por las funciones de abajo, como postgres).
--    Montos en dólares, numeric(14,2); tokens y centavos, enteros. Llaves
--    foráneas solo a movimientos_banco, asientos, cuentas, proyectos y
--    entre tablas de c8. Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- El tope de la app, si en esta base no existe (en producción YA existe,
-- de otra sesión, y no se toca: asistente_costo_mes es allí una vista
-- sobre asistente_uso, y asistente_ajustes trae sus filas).
create table if not exists public.asistente_costo_mes (
  mes           text   not null,
  accion        text   not null,
  llamadas      bigint not null default 0,
  centavos      bigint not null default 0,
  entrada       bigint not null default 0,
  salida        bigint not null default 0,
  cache_lectura bigint not null default 0,
  constraint asistente_costo_mes_pk primary key (mes, accion)
);
create table if not exists public.asistente_ajustes (
  clave text primary key,
  valor text
);
insert into public.asistente_ajustes (clave, valor)
values ('tope_mes_centavos', '10000'), ('aviso_pct', '80')
on conflict (clave) do nothing;

-- La configuración: una sola fila. dueno = en nombre de quién se aprueba
-- (como stripe_config.dueno); modelo y effort, lo que la función de borde
-- manda a Anthropic (solo Opus y Fable: ni Haiku ni Sonnet, nunca);
-- max_por_rafaga, cuántos movimientos como mucho por «Proponer»;
-- tope_mes_centavos, el tope propio del contador (además del global de la
-- app); prompt_version y prefijo_hash, los de la última ráfaga (sha256
-- del texto de las instrucciones y del prefijo entero: si cambian, las
-- propuestas viejas se distinguen por el suyo).
create table if not exists public.ia_config (
  id                int         primary key,
  modelo            text        not null default 'claude-opus-5-5',
  effort            text        not null default 'low',
  activa            boolean     not null default true,
  max_por_rafaga    int         not null default 20,
  tope_mes_centavos int         not null default 3000,
  dueno             uuid        not null,
  prompt_version    text,
  prefijo_hash      text,
  ultima_rafaga_el  timestamptz,
  ultimo_error      text,
  ultimo_error_el   timestamptz,
  actualizado       timestamptz not null default now(),
  constraint ia_config_una    check (id = 1),
  constraint ia_config_modelo check (modelo ~ '^claude-(opus|fable)-' and modelo !~* '(haiku|sonnet)'),
  constraint ia_config_effort check (effort in ('low', 'medium', 'high', 'xhigh', 'max')),
  constraint ia_config_rafaga check (max_por_rafaga between 1 and 100),
  constraint ia_config_tope   check (tope_mes_centavos between 0 and 1000000)
);
comment on table public.ia_config is 'c8: la configuración del contador (una fila): modelo y esfuerzo, activa, cuántos por ráfaga, el tope propio del mes, el dueño en cuyo nombre se aprueba, la última ráfaga y su error. Sin secretos: la llave vive en Edge Functions.';

-- Las reglas: «este comercio va a esta cuenta». patron es una expresión
-- regular de Postgres (sin distinguir mayúsculas) contra desc_norm;
-- cuenta_banco nula = vale en cualquier cuenta; lineas = [{"cuenta",
-- "proyecto_id"?, "parte"?}] (parte = la fracción del monto, suman 1;
-- sin parte, una sola línea entera); pide_obra = alguna cuenta de sus
-- líneas pide obra y la regla no la trae (la propuesta la pedirá);
-- origen = la dictó Edgar o nació de una aprobación.
create table if not exists public.ia_reglas (
  id           uuid        primary key default gen_random_uuid(),
  nombre       text        not null,
  patron       text        not null,
  cuenta_banco text        references public.cuentas (codigo),
  lineas       jsonb       not null,
  pide_obra    boolean     not null default false,
  activa       boolean     not null default true,
  origen       text        not null,
  creada_por   uuid,
  creada_el    timestamptz not null default now(),
  veces        int         not null default 0,
  ultima_vez   timestamptz,
  notas        text,
  constraint ia_reglas_origen check (origen in ('edgar', 'aprobacion')),
  constraint ia_reglas_nombre check (btrim(nombre) <> ''),
  constraint ia_reglas_patron check (btrim(patron) <> ''),
  constraint ia_reglas_lineas check (jsonb_typeof(lineas) = 'array' and jsonb_array_length(lineas) between 1 and 5)
);
create unique index if not exists ia_reglas_patron_unico on public.ia_reglas (patron, coalesce(cuenta_banco, '')) where activa;
create index if not exists ia_reglas_activas_idx on public.ia_reglas (activa) where activa;
comment on table public.ia_reglas is 'c8: las reglas del contador (un patrón contra la descripción del banco → sus líneas), dictadas por Edgar o aprendidas de lo que aprueba. Una activa por patrón y cuenta.';

-- Cada ráfaga de la función de borde: el modelo y el esfuerzo con que se
-- llamó, la versión del prompt y el hash del prefijo, cuántos movimientos
-- se mandaron, el uso sumado ({"input","output","cache_creacion",
-- "cache_lectura"} en tokens), sus centavos, quién la pidió y su error.
create table if not exists public.ia_lotes (
  id             uuid        primary key default gen_random_uuid(),
  accion         text        not null default 'categorizar',
  modelo         text        not null,
  effort         text        not null,
  prompt_version text,
  prefijo_hash   text,
  n              int         not null default 0,
  usage          jsonb,
  centavos       int,
  por            uuid,
  creado_el      timestamptz not null default now(),
  cerrado_el     timestamptz,
  error          text,
  constraint ia_lotes_accion check (accion ~ '^[a-z_]{3,40}$'),
  constraint ia_lotes_modelo check (modelo ~ '^claude-(opus|fable)-' and modelo !~* '(haiku|sonnet)'),
  constraint ia_lotes_effort check (effort in ('low', 'medium', 'high', 'xhigh', 'max')),
  constraint ia_lotes_n      check (n >= 0)
);
create index if not exists ia_lotes_creado_idx on public.ia_lotes (creado_el desc);
comment on table public.ia_lotes is 'c8: cada ráfaga a la IA: modelo, esfuerzo, versión del prompt, cuántos, el uso en tokens (entrada, salida, caché creado y leído), sus centavos y su error.';

-- Cada propuesta: de qué movimiento, de dónde salió (una regla, la IA o
-- Edgar), con qué se le preguntó a la IA (entrada: lo variable congelado
-- tal cual, sin datos personales) y qué contestó tal cual (salida), la
-- propuesta validada ({"lineas":[{"cuenta","monto"?,"proyecto_id"?}],
-- "motivo","confianza","flags":{…},"alternativas"?:[…]}), su estado y, si
-- Edgar la aprobó o la editó, las líneas que entraron, quién, cuándo, su
-- motivo y el asiento de c6. Una sola «pendiente» por movimiento.
create table if not exists public.ia_propuestas (
  id             uuid        primary key default gen_random_uuid(),
  movimiento_id  uuid        not null references public.movimientos_banco (id),
  accion         text        not null default 'categorizar',
  fuente         text        not null,
  regla_id       uuid        references public.ia_reglas (id),
  lote_id        uuid        references public.ia_lotes (id),
  modelo         text,
  effort         text,
  prompt_version text,
  entrada        jsonb,
  salida         jsonb,
  propuesta      jsonb       not null,
  estado         text        not null default 'pendiente',
  aprobado_por   uuid,
  aprobado_el    timestamptz,
  lineas_finales jsonb,
  motivo_edgar   text,
  asiento_id     uuid        references public.asientos (id),
  creado_el      timestamptz not null default now(),
  constraint ia_propuestas_fuente  check (fuente in ('regla', 'ia', 'edgar')),
  constraint ia_propuestas_estado  check (estado in ('pendiente', 'aprobada', 'editada', 'rechazada', 'caducada')),
  constraint ia_propuestas_forma   check (jsonb_typeof(propuesta) = 'object' and jsonb_typeof(propuesta->'lineas') = 'array'),
  constraint ia_propuestas_de_ia   check (fuente <> 'ia' or (lote_id is not null and modelo is not null)),
  constraint ia_propuestas_de_regla check (fuente <> 'regla' or regla_id is not null),
  constraint ia_propuestas_cerrada check (estado not in ('aprobada', 'editada')
                                          or (asiento_id is not null and aprobado_el is not null and lineas_finales is not null))
);
-- (la nota de la base cuando cierra una propuesta sin Edgar: la IA propuso
-- otra vez, la regla se dio de baja, su asiento se reversó)
alter table public.ia_propuestas add column if not exists nota text;
create unique index if not exists ia_propuestas_una_pendiente on public.ia_propuestas (movimiento_id) where estado = 'pendiente';
create index if not exists ia_propuestas_mov_idx on public.ia_propuestas (movimiento_id, creado_el desc);
create index if not exists ia_propuestas_lote_idx on public.ia_propuestas (lote_id) where lote_id is not null;
create index if not exists ia_propuestas_regla_idx on public.ia_propuestas (regla_id) where regla_id is not null;
create index if not exists ia_propuestas_asiento_idx on public.ia_propuestas (asiento_id) where asiento_id is not null;
comment on table public.ia_propuestas is 'c8: cada propuesta de clasificación de un movimiento del banco (de una regla, de la IA o de Edgar): lo que se le dio a la IA, lo que contestó, la propuesta validada, su estado y, aprobada o editada, su asiento de c6.';

-- La fila de la configuración: el dueño activo más antiguo. Al volver a
-- pegar no se pisa nada.
insert into public.ia_config (id, dueno)
select 1, p.id from public.perfiles p
 where p.rol = 'dueno' and coalesce(p.activo, true)
 order by p.creado
 limit 1
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- 2. Los permisos: RLS con una sola policy («solo el dueño lee») y nada
--    para la API salvo leer (el dueño).
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['ia_config', 'ia_reglas', 'ia_lotes', 'ia_propuestas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. LAS CUENTAS PERMITIDAS: la única fuente (la IA, la validación, el
--    selector de la pantalla y el cuadre 62). Solo lee cuentas; activa y
--    saldo_normal se leen de la fila entera (c2-pruebas las reescribe).
-- ---------------------------------------------------------------------
drop view if exists public.v_contador_estado, public.v_contador_control, public.v_contador_bandeja, public.v_contador_reglas,
                    public.v_contador_cuentas;

create view public.v_contador_cuentas with (security_invoker = true) as
with c as (select x.codigo, x.nombre, x.tipo, x.imputable, x.regla_obra, x.etiqueta_fiscal,
                  (to_jsonb(x)->>'activa')::boolean as activa, to_jsonb(x)->>'saldo_normal' as saldo_normal
             from public.cuentas x)
select c.codigo, c.nombre, c.tipo, c.regla_obra, c.saldo_normal, c.etiqueta_fiscal,
       (c.regla_obra = 'obligatoria') as pide_obra
  from c
 where c.activa and c.imputable
   and c.tipo in ('costo', 'gasto', 'otro_gasto', 'activo', 'pasivo', 'capital')
   -- los bancos y la caja: el dinero entre cuentas propias es una transferencia (c6)
   and not (c.tipo = 'activo' and left(c.codigo, 2) = '10')
   -- lo que se cobra entra por su cobro; las de Stripe solo las mueve p1
   and c.codigo not in ('1110', '1120', '1020', '1140')
   -- a un proveedor se le aplica a sus partidas; las tarjetas son cuentas propias
   and not (c.tipo = 'pasivo' and (c.codigo = '2010' or c.codigo like '2100%'))
   -- del patrimonio, solo la distribución (3200; 1130 entra como activo)
   and (c.tipo <> 'capital' or c.codigo = '3200')
   -- las contra-cuentas (1190, 1590, 5011) no reciben un movimiento del banco
   and not (c.tipo = 'activo' and c.saldo_normal = 'haber')
   and not (c.tipo in ('costo', 'gasto', 'otro_gasto') and c.saldo_normal = 'haber')
   -- mano de obra y burden (50xx), sueldo (6000, 6005) y burden administrativo (6010): solo por el journal de nómina
   and left(c.codigo, 2) <> '50'
   and c.codigo not in ('6000', '6005', '6010')
   -- lo que pone el cierre: depreciación, incobrables, el WIP (f10) y el devengo (2050)
   and c.codigo not in ('6950', '6980', '1200', '2400', '2410', '5950', '2050')
 order by c.codigo;
comment on view public.v_contador_cuentas is 'c8: las cuentas a las que el contador puede proponer (y Edgar elegir en «Según yo») un cargo del banco: costo, gasto, otro gasto, activo que no es un banco, pasivo que no es 2010 ni una tarjeta, 3200 y 1130; fuera lo que entra solo por nómina, por el cierre o por su propio camino.';
