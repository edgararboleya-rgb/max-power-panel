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
--     de esos cargos la base guarda UNA PROPUESTA (contador_propuestas): a qué
--     cuenta(s) va, con qué obra si la cuenta la pide, por qué (un motivo
--     de una frase que cita lo que se vio) y con qué confianza. Edgar la
--     aprueba con un toque («Así es»), la corrige («Según yo»: queda
--     «editada») o la rechaza («No es eso»). Nunca entra nada al libro sin
--     ese toque: ES LA PRIMERA REGLA DE LA IA (docs/CONTA-PLAN.md §4):
--     PROPONE, NUNCA POSTEA.
--   · DE DÓNDE SALE LA PROPUESTA, en este orden:
--       1. UNA REGLA (contador_reglas): «este comercio siempre va a esta cuenta».
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
--     (contador_propuestas.entrada, salida, prompt_version): lo que pide la fase
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
--     y las funciones de aquí fijan auth.uid() al dueño de contador_config
--     (request.jwt.claims y claim.sub, solo dentro de la transacción),
--     comprueban es_dueno() y lo sueltan al terminar. Queda escrito:
--     asientos.usuario_id dice el dueño, rol_bd dice postgres.
--   · LA APP solo LEE las vistas v_contador_* (el dueño). Todo lo que mueve
--     (proponer, aprobar, clasificar, rechazar, dar de alta o de baja una
--     regla) lo pide a la función de borde.
--
-- EL GASTO. La app ya tiene montado el tope de la IA: asistente_ajustes
-- (tope_mes_centavos, aviso_pct) y asistente_costo_mes (mes, accion,
-- llamadas, centavos, …), que en producción (y en el banco de pruebas) es
-- una VISTA sobre la tabla asistente_uso, una fila por llamada
-- (docs/conta/ESQUEMA-REAL.md). Por eso fn_contador_lote_cerrar anota cada
-- lote como una fila en asistente_uso (usuario_id el dueño, rol «dueno»,
-- el modelo, accion «contador_categorizar», vueltas = las llamadas del
-- lote, sus tokens de entrada, salida, caché leído y escrito, y sus
-- centavos), que la vista suma; y el tope mira siempre asistente_costo_mes:
-- los mismos números que la app enseña en «ojo, ya vas por el 80 % del
-- mes». Una base sin la app (el banco de pruebas de cero) no trae ninguna
-- de las dos: este archivo las crea entonces, tabla y vista, con la forma
-- exacta de la app; las que ya existen no se tocan. (Si en alguna base
-- asistente_costo_mes fuera una TABLA, el gasto se suma allí, una fila por
-- mes y acción.) Los centavos: (entrada × 400 + caché creado ×
-- 500 + caché leído × 20 + salida × 2000) / 1 000 000, redondeado: el
-- precio de claude-opus-5-5 por millón de tokens ($4 / $20, caché escrito
-- $5, leído $0.20), en céntimos de dólar. Dos topes: el global de la app
-- (todas las acciones del mes contra asistente_ajustes.tope_mes_centavos)
-- y el propio del contador (lo de «contador_%» contra
-- contador_config.tope_mes_centavos, 30.00 al mes de fábrica); y el interruptor
-- contador_config.activa.
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
--     la primera palabra se conserva aunque lo traiga: «7 ELEVEN»), sin la
--     forma de pago delante («POS DEBIT»), sin «#», y sin la ciudad ni el
--     estado del final (los estados de EE. UU. y las ciudades de Florida
--     que Edgar pisa; «WWW», «COM» sueltos). «THE HOME DEPOT 6341 OCALA
--     FL» → «THE HOME DEPOT». Un cheque («CHECK 1043»), un Zelle solo, un
--     número o una ciudad solos no son un comercio: no nace regla (una
--     «^CHECK» casaría con todos los cheques) y la respuesta lo dice; Edgar
--     dicta esa regla con su patrón. El patrón es «^» más ese nombre
--     escapado, tal cual pide el contrato (sin cierre de palabra: «^SHELL»
--     casa «SHELL OIL 57544» y también «SHELLFISH»; si eso molesta, Edgar
--     dicta la regla con su patrón).
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
--     más. Dos detalles que la verificación destapó: (1) c6 normaliza la
--     descripción ANTES de que c8 la vea, y al quitar la arroba y los
--     puntos el correo queda irreconocible para la máscara («JPEREZ@MAIL.
--     COM» → «JPEREZ MAIL COM»): desc_norm pasa siempre por fn_contador_
--     sin_datos_norm, que saca cada correo de la descripción cruda y de la
--     nota, lo normaliza como c6 (fn_banco_norm) y tapa esa tira; y, por si
--     la cruda no está a mano, la máscara también reconoce «<palabra> GMAIL
--     COM» (los dominios de correo corrientes). (2) La máscara de «8
--     dígitos o más» tapaba también dentro de los hashes del sello de la
--     trazabilidad («…71fd[número]e39e…»): un hash entero (md5, sha1,
--     sha256) o un uuid nunca es un dato de nadie y se deja tal cual, y en
--     el árbol de «entrada» las claves prompt_version, prefijo_hash y
--     reglas_version van íntegras por su nombre, pase lo que pase con la
--     máscara. Lo que la máscara NO alcanza, a sabiendas: un teléfono sin
--     separadores de siete dígitos («5551234») y una cuenta de siete
--     dígitos o menos («ACCT 1234567»): raros en una descripción del banco,
--     y taparlos a ciegas taparía los números de tienda y de cheque.
--   · UNA SOLA RÁFAGA A LA VEZ. Dos «Proponer» a la vez (dos pestañas, dos
--     aparatos) mandarían los mismos cargos a Anthropic y pagarían dos
--     veces: fn_contador_lote_abrir toma un candado y, si hay una ráfaga
--     abierta hace menos de cinco minutos, no abre otra (MX008 «ya hay una
--     ráfaga en marcha», que la pantalla enseña en llano). Una abierta hace
--     más de cinco minutos es una función que se cortó sin cerrar (Supabase
--     la mató, se cayó la red): al abrir la siguiente la base la da por
--     perdida, cerrada con su error y sin uso (su gasto no se conoce), y la
--     alarma 72 lo dice (mientras sigue abierta, y después por el error)
--     hasta la siguiente ráfaga limpia.
--   · EL GASTO SE ANOTA EN asistente_uso (desviación del apartado A del
--     contrato, a propósito): el contrato pedía una tabla asistente_costo_
--     mes con llave (mes, accion), pero en producción asistente_costo_mes
--     es una VISTA de la app sobre la tabla asistente_uso (docs/conta/
--     ESQUEMA-REAL.md), y lo que la app enseña en «ya vas por el 80 % del
--     mes» sale de ahí. Por eso, si faltan, aquí se crean la tabla y la
--     vista con la forma de la app (no la tabla del contrato), y el camino
--     «tabla» queda en fn_contador_gasto_anotar por si en alguna base
--     asistente_costo_mes fuera una tabla. Lo que ya existe no se toca: ni
--     se vuelve a dar permiso sobre ello (los grants van dentro del bloque
--     que crea); solo las dos filas de asistente_ajustes entran si faltan,
--     como pide el contrato.
--
-- Lo que este archivo NO toca: c1..c7, s1, p1, es_dueno(), docs/sql, las
-- tablas del banco (solo lee movimientos_banco y escribe en él POR c6),
-- asistente_ajustes de la app (solo crea las filas si faltan), el libro
-- (nunca fn_postear ni fn_postear_interno). No postea nada automático: ni
-- el use tax, ni la capitalización, ni una regla con confianza 1.
--
-- Las tablas se llaman contador_* (y no ia_*, como decía el plan de f07):
-- producción ya tiene una ia_propuestas de otra parte de la app (las dudas
-- que la revisión diaria del cerebro de Planos deja), con otras columnas.
-- El primer pegado en producción (31-oct) chocó con ella («column
-- movimiento_id does not exist», sin dejar nada); c8 no toca esa tabla, y
-- si una tabla con nombre de c8 ya existe y no es de c8, para con MX000.
--
-- Cómo se instala (Edgar, en este orden, con la cadena c1..c7, s1 y p1 ya
-- pegada como dice pruebas/conta/README.md):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración (modelo, esfuerzo, activa, los topes), el
--      dueño, las cuatro tablas, las cuentas que se proponen, las reglas
--      activas, lo que espera en la bandeja sin propuesta, el control («0
--      cuadres rojos · n alarmas») y el paso siguiente. Si ya hay cargos
--      «sin ticket» de hace más de dos días, sale 1 alarma: la 73 («la
--      llave y la función»), que es LA ESPERADA hasta la primera ráfaga (en
--      «Qué atender» dice «toca Proponer con la IA») y se apaga sola con
--      ella. Si algo de lo que da por hecho falta, para con MX000 y no
--      queda nada.
--   2. SQL Editor → pegar docs/conta/c8-pruebas.sql → 25 filas, todas en
--      true (cada una siembra sus cargos de prueba y los deshace; no toca
--      la bandeja real).
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
--   Para apagarla: update contador_config set activa = false where id = 1; (la
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
                             'fn_banco_casar(uuid)', 'fn_banco_descasar(uuid,text)', 'fn_banco_norm(text)'] loop
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
  -- Una tabla con el nombre de las de c8 que no sea de c8 (producción ya
  -- tenía una ia_propuestas de otra app: por eso las nuestras se llaman
  -- contador_*): se para antes de tocar nada, con «if not exists» la
  -- dejaríamos como está y lo siguiente reventaría a medias.
  foreach v_x in array array['contador_config:max_por_rafaga', 'contador_reglas:patron', 'contador_lotes:prefijo_hash', 'contador_propuestas:movimiento_id'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c8 (no tiene la columna %s): otra cosa usa ese nombre. No la toco; avisa antes de seguir.',
                    split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: las propuestas se aprueban en su nombre.';
  end if;
  -- Dónde se anota el gasto: la vista de la app asistente_costo_mes sobre
  -- la tabla asistente_uso (si faltan las dos, se crean aquí con su forma;
  -- si está la tabla y falta la vista, se crea la vista), o una tabla
  -- asistente_costo_mes.
  select c.relkind into v_k from pg_class c where c.oid = to_regclass('public.asistente_costo_mes');
  if v_k = 'v' and (select r.relkind from pg_class r where r.oid = to_regclass('public.asistente_uso')) is distinct from 'r' then
    return 'asistente_costo_mes es una vista y no hay una tabla asistente_uso donde anotar el gasto: no sé dónde apuntar cada ráfaga.';
  elsif v_k is not null and v_k not in ('r', 'v') then
    return format('asistente_costo_mes existe pero no es una tabla ni una vista (relkind %s).', v_k);
  elsif v_k is null and to_regclass('public.asistente_uso') is not null
        and (select r.relkind from pg_class r where r.oid = to_regclass('public.asistente_uso')) <> 'r' then
    return 'asistente_uso existe pero no es una tabla: no sé dónde apuntar el gasto de cada ráfaga.';
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
comment on function public.fn_contador_precondiciones() is 'c8: lo que falta para pegar c8-contador.sql (nulo = nada): c2 y c6, el SQL Editor, un dueño activo, dónde anotar el gasto, ninguna tabla ajena con nombre de c8 y nada ajeno sobre las vistas v_contador_*.';

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
-- El gasto y el tope de la app, SOLO si en esta base no existen (en
-- producción YA existen, de otra sesión, y no se tocan): la tabla
-- asistente_uso (una fila por llamada a la IA) y su vista
-- asistente_costo_mes (mes, accion, llamadas, centavos, entrada, salida,
-- cache_lectura), con la forma exacta de la app (docs/conta/ESQUEMA-REAL.md),
-- y asistente_ajustes con sus dos filas. Si asistente_uso existe y la
-- vista no, se crea solo la vista sobre ella.
do $$
begin
  if to_regclass('public.asistente_uso') is null and to_regclass('public.asistente_costo_mes') is null then
    create table public.asistente_uso (
      id              bigint      generated always as identity primary key,
      usuario_id      uuid        references public.perfiles (id),
      rol             text,
      modelo          text,
      entrada         integer     default 0,
      salida          integer     default 0,
      vueltas         integer     default 1,
      creado          timestamptz default now(),
      accion          text,
      cache_lectura   integer     default 0,
      cache_escritura integer     default 0,
      ms              integer,
      resultado       text,
      costo_centavos  integer,
      letras          integer,
      proyecto_id     text
    );
    comment on table public.asistente_uso is 'La app: cada llamada a la IA con sus tokens y sus centavos (la creó c8 porque esta base no la traía; en producción es de la app).';
    alter table public.asistente_uso enable row level security;
    create policy "dueno ve el gasto del asistente" on public.asistente_uso for select using (es_dueno());
    revoke all on public.asistente_uso from public, anon, authenticated, service_role;
    grant select on public.asistente_uso to authenticated;
    revoke all on sequence public.asistente_uso_id_seq from public, anon, authenticated, service_role;
  end if;
  if to_regclass('public.asistente_costo_mes') is null
     and (select c.relkind from pg_class c where c.oid = to_regclass('public.asistente_uso')) = 'r' then
    create view public.asistente_costo_mes with (security_invoker = true) as
    select to_char(u.creado at time zone 'America/New_York', 'YYYY-MM') as mes,
           coalesce(u.accion, 'asistente')                               as accion,
           count(*)                                                       as llamadas,
           coalesce(sum(u.costo_centavos), 0)                             as centavos,
           coalesce(sum(u.entrada), 0)                                    as entrada,
           coalesce(sum(u.salida), 0)                                     as salida,
           coalesce(sum(u.cache_lectura), 0)                              as cache_lectura
      from public.asistente_uso u
     group by 1, 2;
    comment on view public.asistente_costo_mes is 'La app: el gasto de la IA por mes y acción, sumado de asistente_uso (la creó c8 porque esta base no la traía).';
    revoke all on public.asistente_costo_mes from public, anon, authenticated, service_role;
    grant select on public.asistente_costo_mes to authenticated;
  end if;
  if to_regclass('public.asistente_ajustes') is null then
    create table public.asistente_ajustes (
      clave text primary key,
      valor text
    );
    comment on table public.asistente_ajustes is 'La app: los ajustes del asistente (tope_mes_centavos, aviso_pct) (la creó c8 porque esta base no la traía).';
    alter table public.asistente_ajustes enable row level security;
    create policy "ajustes asistente solo dueno" on public.asistente_ajustes to authenticated using (es_dueno()) with check (es_dueno());
    revoke all on public.asistente_ajustes from public, anon, authenticated, service_role;
    grant select on public.asistente_ajustes to authenticated;
  end if;
end $$;
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
create table if not exists public.contador_config (
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
  constraint contador_config_una    check (id = 1),
  constraint contador_config_modelo check (modelo ~ '^claude-(opus|fable)-' and modelo !~* '(haiku|sonnet)'),
  constraint contador_config_effort check (effort in ('low', 'medium', 'high', 'xhigh', 'max')),
  constraint contador_config_rafaga check (max_por_rafaga between 1 and 100),
  constraint contador_config_tope   check (tope_mes_centavos between 0 and 1000000)
);
comment on table public.contador_config is 'c8: la configuración del contador (una fila): modelo y esfuerzo, activa, cuántos por ráfaga, el tope propio del mes, el dueño en cuyo nombre se aprueba, la última ráfaga y su error. Sin secretos: la llave vive en Edge Functions.';

-- Las reglas: «este comercio va a esta cuenta». patron es una expresión
-- regular de Postgres (sin distinguir mayúsculas) contra desc_norm;
-- cuenta_banco nula = vale en cualquier cuenta; lineas = [{"cuenta",
-- "proyecto_id"?, "parte"?}] (parte = la fracción del monto, suman 1;
-- sin parte, una sola línea entera); pide_obra = alguna cuenta de sus
-- líneas pide obra y la regla no la trae (la propuesta la pedirá);
-- origen = la dictó Edgar o nació de una aprobación.
create table if not exists public.contador_reglas (
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
  constraint contador_reglas_origen check (origen in ('edgar', 'aprobacion')),
  constraint contador_reglas_nombre check (btrim(nombre) <> ''),
  constraint contador_reglas_patron check (btrim(patron) <> ''),
  constraint contador_reglas_lineas check (jsonb_typeof(lineas) = 'array' and jsonb_array_length(lineas) between 1 and 5)
);
create unique index if not exists contador_reglas_patron_unico on public.contador_reglas (patron, coalesce(cuenta_banco, '')) where activa;
create index if not exists contador_reglas_activas_idx on public.contador_reglas (activa) where activa;
comment on table public.contador_reglas is 'c8: las reglas del contador (un patrón contra la descripción del banco → sus líneas), dictadas por Edgar o aprendidas de lo que aprueba. Una activa por patrón y cuenta.';

-- Cada ráfaga de la función de borde: el modelo y el esfuerzo con que se
-- llamó, la versión del prompt y el hash del prefijo, cuántos movimientos
-- se mandaron, el uso sumado ({"input","output","cache_creacion",
-- "cache_lectura"} en tokens), sus centavos, quién la pidió y su error.
create table if not exists public.contador_lotes (
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
  constraint contador_lotes_accion check (accion ~ '^[a-z_]{3,40}$'),
  constraint contador_lotes_modelo check (modelo ~ '^claude-(opus|fable)-' and modelo !~* '(haiku|sonnet)'),
  constraint contador_lotes_effort check (effort in ('low', 'medium', 'high', 'xhigh', 'max')),
  constraint contador_lotes_n      check (n >= 0)
);
create index if not exists contador_lotes_creado_idx on public.contador_lotes (creado_el desc);
comment on table public.contador_lotes is 'c8: cada ráfaga a la IA: modelo, esfuerzo, versión del prompt, cuántos, el uso en tokens (entrada, salida, caché creado y leído), sus centavos y su error.';

-- Cada propuesta: de qué movimiento, de dónde salió (una regla, la IA o
-- Edgar), con qué se le preguntó a la IA (entrada: lo variable congelado
-- tal cual, sin datos personales) y qué contestó tal cual (salida), la
-- propuesta validada ({"lineas":[{"cuenta","monto"?,"proyecto_id"?}],
-- "motivo","confianza","flags":{…},"alternativas"?:[…]}), su estado y, si
-- Edgar la aprobó o la editó, las líneas que entraron, quién, cuándo, su
-- motivo y el asiento de c6. Una sola «pendiente» por movimiento.
create table if not exists public.contador_propuestas (
  id             uuid        primary key default gen_random_uuid(),
  movimiento_id  uuid        not null references public.movimientos_banco (id),
  accion         text        not null default 'categorizar',
  fuente         text        not null,
  regla_id       uuid        references public.contador_reglas (id),
  lote_id        uuid        references public.contador_lotes (id),
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
  constraint contador_propuestas_fuente  check (fuente in ('regla', 'ia', 'edgar')),
  constraint contador_propuestas_estado  check (estado in ('pendiente', 'aprobada', 'editada', 'rechazada', 'caducada')),
  constraint contador_propuestas_forma   check (jsonb_typeof(propuesta) = 'object' and jsonb_typeof(propuesta->'lineas') = 'array'),
  constraint contador_propuestas_de_ia   check (fuente <> 'ia' or (lote_id is not null and modelo is not null)),
  constraint contador_propuestas_de_regla check (fuente <> 'regla' or regla_id is not null),
  constraint contador_propuestas_cerrada check (estado not in ('aprobada', 'editada')
                                          or (asiento_id is not null and aprobado_el is not null and lineas_finales is not null))
);
-- (la nota de la base cuando cierra una propuesta sin Edgar: la IA propuso
-- otra vez, la regla se dio de baja, su asiento se reversó)
alter table public.contador_propuestas add column if not exists nota text;
create unique index if not exists contador_propuestas_una_pendiente on public.contador_propuestas (movimiento_id) where estado = 'pendiente';
create index if not exists contador_propuestas_mov_idx on public.contador_propuestas (movimiento_id, creado_el desc);
create index if not exists contador_propuestas_lote_idx on public.contador_propuestas (lote_id) where lote_id is not null;
create index if not exists contador_propuestas_regla_idx on public.contador_propuestas (regla_id) where regla_id is not null;
create index if not exists contador_propuestas_asiento_idx on public.contador_propuestas (asiento_id) where asiento_id is not null;
comment on table public.contador_propuestas is 'c8: cada propuesta de clasificación de un movimiento del banco (de una regla, de la IA o de Edgar): lo que se le dio a la IA, lo que contestó, la propuesta validada, su estado y, aprobada o editada, su asiento de c6.';

-- La fila de la configuración: el dueño activo más antiguo. Al volver a
-- pegar no se pisa nada.
insert into public.contador_config (id, dueno)
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
  foreach t in array array['contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas'] loop
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


-- ---------------------------------------------------------------------
-- 4. Lo interno (ninguna en la API; todas empiezan por fn_contador_exigir)
-- ---------------------------------------------------------------------
create or replace function public.fn_contador_cfg() returns public.contador_config
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c contador_config;
begin
  perform fn_contador_exigir();
  select * into c from contador_config where id = 1;
  if not found then
    raise exception using errcode = 'MX009', message = 'Falta la configuración del contador (contador_config): vuelve a pegar c8-contador.sql.';
  end if;
  return c;
end $$;
revoke execute on function public.fn_contador_cfg() from public, anon, authenticated, service_role;
comment on function public.fn_contador_cfg() is 'c8: la fila de contador_config.';

-- EN NOMBRE DEL DUEÑO (como fn_stripe_suplantar, p1): guarda los claims
-- de ahora, fija auth.uid() al dueño de contador_config SOLO dentro de esta
-- transacción y comprueba que siga siendo el dueño. fn_contador_soltar
-- los deja como estaban. Siempre en pareja.
create or replace function public.fn_contador_suplantar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg contador_config;
  v   jsonb;
begin
  perform fn_contador_exigir();
  cfg := fn_contador_cfg();
  v := jsonb_build_object('claims', current_setting('request.jwt.claims', true),
                          'sub', current_setting('request.jwt.claim.sub', true));
  perform set_config('request.jwt.claims', jsonb_build_object('sub', cfg.dueno, 'role', 'authenticated', 'contador', true)::text, true);
  perform set_config('request.jwt.claim.sub', cfg.dueno::text, true);
  if not es_dueno() then
    raise exception using errcode = '42501',
      message = 'El dueño en nombre del cual aprueba el contador (contador_config.dueno) ya no es el dueño: no se clasifica nada. Entra a la '
                'Bandeja como dueño para fijarlo.';
  end if;
  return v;
end $$;
revoke execute on function public.fn_contador_suplantar() from public, anon, authenticated, service_role;
comment on function public.fn_contador_suplantar() is 'c8: fija auth.uid() al dueño de contador_config dentro de la transacción (request.jwt.claims y claim.sub) y devuelve los de antes para fn_contador_soltar.';

create or replace function public.fn_contador_soltar(p jsonb) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  perform set_config('request.jwt.claims', coalesce(p->>'claims', ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(p->>'sub', ''), true);
end $$;
revoke execute on function public.fn_contador_soltar(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_contador_soltar(jsonb) is 'c8: deja request.jwt.claims y claim.sub como estaban antes de fn_contador_suplantar.';

-- El dueño de la sesión que pide algo por la función de borde pasa a ser
-- el de la configuración (si es el dueño activo).
create or replace function public.fn_contador_dueno_fijar(p_dueno uuid) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  if p_dueno is null or not exists (select 1 from perfiles p where p.id = p_dueno and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501', message = 'Solo el dueño maneja el contador (las propuestas y las reglas).';
  end if;
  update contador_config set dueno = p_dueno, actualizado = now() where id = 1 and dueno is distinct from p_dueno;
end $$;
revoke execute on function public.fn_contador_dueno_fijar(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_contador_dueno_fijar(uuid) is 'c8: el dueño activo que pide algo por la función pasa a ser en nombre de quien aprueba el contador; otro, 42501.';

-- Dinero en texto para los avisos y el control: $1,234.50.
create or replace function public.fn_contador_usd(p numeric) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  return case when p is null then '$?'
              when p < 0 then '−$' || to_char(abs(p), 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end;
end $$;
revoke execute on function public.fn_contador_usd(numeric) from public, anon, authenticated, service_role;
comment on function public.fn_contador_usd(numeric) is 'c8: dinero en texto ($1,234.50).';

-- Lo que NO se le da a la IA ni se guarda en «entrada»: correos, teléfonos
-- y números de cuenta (8 dígitos seguidos o más). El número de una tienda
-- (6341) o el de un cheque (1043) sí van: son parte de lo que dijo el
-- banco y la IA los necesita (y las reglas se prueban contra desc_norm,
-- que no se toca). Un correo se tapa en sus dos formas: tal cual lo
-- escribe el banco («JPEREZ@MAIL.COM») y como queda en desc_norm después
-- de que c6 le quite la arroba y los puntos («JPEREZ MAIL COM»: una
-- palabra, un dominio de correo corriente y COM, NET, ORG o US); para un
-- dominio cualquiera está fn_contador_sin_datos_norm, abajo, que lo saca
-- de la descripción cruda. Un hash entero (md5, sha1 o sha256: el sello
-- prompt_version, prefijo_hash y reglas_version de la trazabilidad) o un
-- uuid no es un dato de nadie y se deja tal cual: la máscara de «8 dígitos
-- o más» rompía el sello («…71fd[número]e39e…»). Lo que NO alcanza, a
-- sabiendas: un teléfono de siete dígitos sin separadores («5551234») y
-- una cuenta de siete dígitos o menos («ACCT 1234567»): en una descripción
-- del banco son raros, y taparlos a ciegas taparía números de tienda y de
-- cheque (3055551234 sí cae: son diez dígitos seguidos).
create or replace function public.fn_contador_sin_datos(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  if p is null then return null; end if;
  -- un hash entero (con alguna letra: 32 dígitos seguidos no son un hash) o un uuid: tal cual
  if (p ~* '^([0-9a-f]{32}|[0-9a-f]{40}|[0-9a-f]{64})$' and p ~* '[a-f]')
     or p ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return p;
  end if;
  return regexp_replace(
           regexp_replace(
             regexp_replace(
               regexp_replace(p, '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', '[correo]', 'g'),
               -- (el correo como lo deja c6 al normalizar: «JPEREZ MAIL COM»)
               '\m[[:alnum:]]+ (GMAIL|YAHOO|YMAIL|HOTMAIL|OUTLOOK|ICLOUD|AOL|MAIL|LIVE|MSN|PROTON|PROTONMAIL|ME) (COM|NET|ORG|US)\M',
               '[correo]', 'gi'),
             '\(?[0-9]{3}\)?[ .-]?[0-9]{3}[ .-][0-9]{4}', '[teléfono]', 'g'),
           '[0-9]{8,}', '[número]', 'g');
end $$;
revoke execute on function public.fn_contador_sin_datos(text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_sin_datos(text) is 'c8: tapa correos (tal cual y en la forma normalizada de c6), teléfonos y números de cuenta (8 dígitos o más) en un texto que va a la IA; un hash o un uuid enteros se dejan.';

-- La descripción NORMALIZADA (desc_norm) que va a la IA o a «entrada»: c6
-- deshace el correo al normalizar («JPEREZ@MAIL.COM» → «JPEREZ MAIL COM») y
-- la máscara de arriba solo lo reconoce si el dominio es uno corriente. Aquí
-- se saca cada correo de la descripción cruda y de la nota, se normaliza
-- igual que c6 (fn_banco_norm) y se tapa esa tira en desc_norm; después, lo
-- demás (fn_contador_sin_datos). Siempre que desc_norm salga de la base
-- hacia la IA o hacia «entrada», pasa por aquí con su descripción y su
-- nota (fn_contador_pendientes, fn_contador_reglas_aplicar,
-- fn_contador_clasificar). Las reglas siguen probándose contra el desc_norm
-- de la tabla, que no se toca.
create or replace function public.fn_contador_sin_datos_norm(p_norm text, p_descripcion text default null, p_memo text default null)
returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v        text := p_norm;
  v_correo text;
begin
  perform fn_contador_exigir();
  if v is null then return null; end if;
  for v_correo in
    select distinct fn_banco_norm(x[1])
      from regexp_matches(concat_ws(' ', p_descripcion, p_memo), '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', 'g') x
  loop
    if v_correo <> '' then
      v := regexp_replace(v, '\m' || fn_contador_regex_escapar(v_correo) || '\M', '[correo]', 'gi');
    end if;
  end loop;
  return fn_contador_sin_datos(v);
end $$;
revoke execute on function public.fn_contador_sin_datos_norm(text, text, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_sin_datos_norm(text, text, text) is 'c8: fn_contador_sin_datos sobre desc_norm, tapando antes cada correo de la descripción cruda y de la nota en la forma en que c6 lo normaliza («JPEREZ MAIL COM»).';

-- Lo mismo en todo un árbol JSON (lo que la función de borde congela en
-- «entrada»): cada texto, tapado; salvo el sello de la trazabilidad
-- (prompt_version, prefijo_hash y reglas_version: hashes, nunca datos de
-- nadie), que va entero por su nombre, pase lo que pase con la máscara. El
-- movimiento ya viene tapado de fn_contador_pendientes: esta segunda pasada
-- es por si la función de borde algún día mandara algo más.
create or replace function public.fn_contador_sin_datos_jsonb(p jsonb) returns jsonb
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_contador_exigir();
  if p is null then return null; end if;
  if jsonb_typeof(p) = 'object' then
    select coalesce(jsonb_object_agg(e.key, case when e.key in ('prompt_version', 'prefijo_hash', 'reglas_version') then e.value
                                                 else fn_contador_sin_datos_jsonb(e.value) end), '{}'::jsonb)
      into v
      from jsonb_each(p) e;
    return v;
  elsif jsonb_typeof(p) = 'array' then
    select coalesce(jsonb_agg(fn_contador_sin_datos_jsonb(x.v) order by x.n), '[]'::jsonb) into v
      from jsonb_array_elements(p) with ordinality as x(v, n);
    return v;
  elsif jsonb_typeof(p) = 'string' then
    return to_jsonb(fn_contador_sin_datos(p #>> '{}'));
  end if;
  return p;
end $$;
revoke execute on function public.fn_contador_sin_datos_jsonb(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_contador_sin_datos_jsonb(jsonb) is 'c8: fn_contador_sin_datos sobre cada texto de un árbol JSON, salvo el sello (prompt_version, prefijo_hash, reglas_version), que va entero.';

-- Un texto, escapado para usarlo literal dentro de una expresión regular.
create or replace function public.fn_contador_regex_escapar(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  return regexp_replace(p, '([\^$.|?*+()\[\]{}\\])', '\\\1', 'g');
end $$;
revoke execute on function public.fn_contador_regex_escapar(text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_regex_escapar(text) is 'c8: escapa un texto para que una expresión regular lo busque literal.';

-- ¿Es una expresión regular válida (y razonable: hasta 200 caracteres)?
-- Nulo = sí; si no, el porqué en llano.
create or replace function public.fn_contador_regex_valida(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  if coalesce(btrim(p), '') = '' then
    return 'el patrón está vacío';
  end if;
  if length(p) > 200 then
    return 'el patrón es demasiado largo (más de 200 caracteres)';
  end if;
  begin
    perform 'X' ~* p;
  exception when others then
    return format('el patrón no es una expresión regular válida (%s)', sqlerrm);
  end;
  if '' ~* p then
    return 'el patrón casa con un texto vacío: casaría con todo';
  end if;
  return null;
end $$;
revoke execute on function public.fn_contador_regex_valida(text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_regex_valida(text) is 'c8: nulo si el patrón es una expresión regular válida y no casa con todo; si no, el porqué.';

-- EL NOMBRE DEL COMERCIO de una descripción normalizada del banco: las
-- primeras palabras hasta la primera que trae un número (el número de la
-- tienda, el de confirmación, una fecha; la primera se conserva aunque lo
-- traiga: «7 ELEVEN»), sin la forma de pago delante («POS DEBIT»), sin
-- «#», y sin la ciudad ni el estado del final («THE HOME DEPOT 6341 OCALA
-- FL» → «THE HOME DEPOT»; «TST FIREHOUSE SUBS OCALA FL» → «TST FIREHOUSE
-- SUBS»). Como mucho cinco palabras. Nulo si no queda nada con sentido
-- (dos letras o menos, un número solo, o una palabra del banco sola:
-- «CHECK 1043» no es un comercio, y una regla «^CHECK» casaría con todos
-- los cheques).
create or replace function public.fn_contador_nombre_comercio(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  c_estados constant text[] := array['AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME',
                                     'MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA',
                                     'RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY','DC','PR'];
  -- las ciudades de Florida por donde Edgar compra (una o dos palabras), y
  -- las grandes del estado
  c_ciudades constant text[] := array['OCALA','BELLEVIEW','DUNNELLON','SUMMERFIELD','SILVER SPRINGS','LADY LAKE','THE VILLAGES',
                                      'WILDWOOD','LEESBURG','EUSTIS','MOUNT DORA','TAVARES','CLERMONT','GAINESVILLE','ALACHUA',
                                      'NEWBERRY','WILLISTON','INVERNESS','CRYSTAL RIVER','HOMOSASSA','BROOKSVILLE','SPRING HILL',
                                      'ORLANDO','KISSIMMEE','SANFORD','APOPKA','WINTER PARK','WINTER GARDEN','OCOEE','OVIEDO',
                                      'ALTAMONTE SPRINGS','LAKE MARY','DELAND','DELTONA','DAYTONA BEACH','PALM COAST','ST AUGUSTINE',
                                      'JACKSONVILLE','ORANGE PARK','TAMPA','BRANDON','LAKELAND','PLANT CITY','ST PETERSBURG',
                                      'CLEARWATER','LARGO','SARASOTA','BRADENTON','FORT MYERS','NAPLES','MIAMI','HIALEAH',
                                      'FORT LAUDERDALE','HOLLYWOOD','WEST PALM BEACH','BOCA RATON','MELBOURNE','PALM BAY','TITUSVILLE',
                                      'COCOA','TALLAHASSEE','PENSACOLA','PANAMA CITY','DESTIN','LAKE CITY','STARKE','PALATKA'];
  c_sueltas constant text[] := array['WWW','COM','NET','ORG','HTTPS','HTTP'];
  -- lo que el banco pone DELANTE del comercio (la forma de pago, no quién
  -- cobró): «POS DEBIT WAWA 5234» es WAWA
  c_delante constant text[] := array['POS','DEBIT','CREDIT','PURCHASE','CHECKCARD','CARD','DBT','CRD','VISA','RECURRING','ONLINE'];
  -- y lo que, solo, no es ningún comercio: una regla «^CHECK» o «^ZELLE»
  -- casaría con todos los cheques o todos los Zelle (un cheque es «CHECK
  -- 1043»: el comercio no está en la descripción; Edgar dicta la regla)
  c_genericas constant text[] := array['CHECK','CHEQUE','CHK','DEBIT','CREDIT','PURCHASE','POS','ATM','WITHDRAWAL','WITHDRAWL',
                                       'DEPOSIT','PAYMENT','PMT','TRANSFER','XFER','ONLINE','CARD','FEE','ACH','WIRE','ZELLE','VENMO',
                                       'PAYPAL','CASHAPP','SQ','TST','APLPAY','GOOGLE','APPLE','PAY'];
  v_t   text[];
  v_out text[] := '{}';
  v_i   int;
  v_n   int;
  v_dos text;
begin
  perform fn_contador_exigir();
  if coalesce(btrim(p), '') = '' then return null; end if;
  v_t := regexp_split_to_array(btrim(regexp_replace(upper(p), '\s+', ' ', 'g')), ' ');
  while cardinality(v_t) > 1 and v_t[1] = any (c_delante) loop
    v_t := v_t[2 : cardinality(v_t)];
  end loop;
  for v_i in 1 .. cardinality(v_t) loop
    exit when v_i > 1 and v_t[v_i] ~ '[0-9]';
    continue when v_t[v_i] in ('#', '&', '*');
    v_out := v_out || regexp_replace(v_t[v_i], '^#', '');
    exit when cardinality(v_out) >= 5;
  end loop;
  -- (solo un número —«1043»—: no es un comercio)
  if cardinality(v_out) = 1 and v_out[1] ~ '^[0-9]+$' then
    return null;
  end if;
  -- la ciudad y el estado del final
  loop
    v_n := cardinality(v_out);
    exit when v_n <= 1;
    if v_out[v_n] = any (c_estados) or v_out[v_n] = any (c_sueltas) then
      v_out := v_out[1 : v_n - 1];
      continue;
    end if;
    if v_out[v_n] = any (c_ciudades) then
      v_out := v_out[1 : v_n - 1];
      continue;
    end if;
    v_dos := case when v_n >= 3 then v_out[v_n - 1] || ' ' || v_out[v_n] end;
    if v_dos = any (c_ciudades) then
      v_out := v_out[1 : v_n - 2];
      continue;
    end if;
    exit;
  end loop;
  if cardinality(v_out) = 0 or length(array_to_string(v_out, ' ')) <= 2 then
    return null;
  end if;
  -- (una palabra del banco, una ciudad o un estado solos tampoco)
  if cardinality(v_out) = 1 and (v_out[1] = any (c_genericas) or v_out[1] = any (c_ciudades) or v_out[1] = any (c_estados)) then
    return null;
  end if;
  return array_to_string(v_out, ' ');
end $$;
revoke execute on function public.fn_contador_nombre_comercio(text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_nombre_comercio(text) is 'c8: el comercio de una descripción normalizada del banco (las primeras palabras, sin la forma de pago delante, sin números, sin «#» y sin la ciudad ni el estado del final), o nulo (un cheque, un Zelle o un número solos no son un comercio).';

-- ¿Puede proponerse (o elegirse) esta cuenta para un cargo del banco?
-- Nulo = sí (está en v_contador_cuentas); si no, el porqué en llano, para
-- que la función de borde y la pantalla lo digan.
create or replace function public.fn_contador_cuenta_permitida(p_cuenta text) returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c cuentas;
begin
  perform fn_contador_exigir();
  if coalesce(btrim(p_cuenta), '') = '' then
    return 'falta la cuenta';
  end if;
  if exists (select 1 from v_contador_cuentas v where v.codigo = btrim(p_cuenta)) then
    return null;
  end if;
  select * into c from cuentas where codigo = btrim(p_cuenta);
  if not found then
    return format('la cuenta %s no existe en el plan', btrim(p_cuenta));
  end if;
  return format('la cuenta %s (%s) %s', c.codigo, c.nombre,
    case
      when not c.activa then 'está inactiva'
      when not c.imputable then 'es de grupo: va a una de sus subcuentas'
      when c.tipo in ('ingreso', 'otro_ingreso') then 'es un ingreso: lo que entra del banco es el cobro de una factura o un anticipo (fn_banco_cobrar), nunca un ingreso a mano'
      when c.tipo = 'activo' and left(c.codigo, 2) = '10' then 'es un banco o la caja: el dinero entre cuentas propias es una transferencia (fn_banco_transferencia)'
      when c.codigo in ('1110', '1120') then 'es lo que se cobra a los clientes: entra por su cobro, no a mano'
      when c.codigo in ('1020', '1140') then 'es de Stripe (p1): solo la mueve p1'
      when c.codigo = '2010' then 'es lo que se debe a los proveedores: un pago se aplica a sus partidas (fn_banco_pagar_proveedor)'
      when c.codigo like '2100%' then 'es una tarjeta: su pago es una transferencia entre cuentas propias'
      when left(c.codigo, 2) = '50' then 'es mano de obra o su burden: entra solo por el journal de nómina (f11)'
      when c.codigo in ('6000', '6005') then 'es sueldo: entra solo por el journal de nómina, con sus retenciones'
      when c.codigo = '6010' then 'es el burden administrativo: solo por el journal de nómina'
      when c.codigo = '6950' then 'es la depreciación: la pone el cierre desde activos_fijos (f08)'
      when c.codigo = '6980' then 'son los incobrables: contra su provisión, en el cierre'
      when c.codigo in ('1200', '2400', '2410', '5950') then 'es del WIP (f10): la pone el cierre'
      when c.codigo = '2050' then 'es el devengo del cierre (se deshace solo el día 1): nunca desde el banco'
      when c.tipo = 'capital' then 'es patrimonio: desde el banco solo 3200 (lo que saca el accionista) o 1130 (lo que le presta la empresa)'
      when c.tipo = 'activo' and c.saldo_normal = 'haber' then 'es una contra-cuenta: no recibe un movimiento del banco'
      when c.tipo in ('costo', 'gasto', 'otro_gasto') and c.saldo_normal = 'haber' then 'es una contra-cuenta: no recibe un movimiento del banco'
      else 'no está entre las cuentas que se proponen desde el banco (v_contador_cuentas)' end);
end $$;
revoke execute on function public.fn_contador_cuenta_permitida(text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_cuenta_permitida(text) is 'c8: nulo si la cuenta está entre las que se proponen para un cargo del banco (v_contador_cuentas); si no, el porqué en llano.';


-- ---------------------------------------------------------------------
-- 5. Lo que espera, el tope, el contexto y las reglas
-- ---------------------------------------------------------------------
-- LOS CANDIDATOS: lo pendiente de la bandeja de c6 con motivo «sin_ticket»
-- (un cargo sin ticket ni asiento que lo explique; «dudosa» por si una
-- versión de c6 lo trae) y sin propuesta pendiente, los más viejos primero.
create or replace function public.fn_contador_candidatos()
returns table (movimiento_id uuid, cuenta text, cuenta_nombre text, fecha date, monto numeric, descripcion text, memo text,
               desc_norm text, tipo_banco text, dias int, motivo text, importado_el timestamptz)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  return query
    select m.id, m.cuenta, b.cuenta_nombre, m.fecha, m.monto, m.descripcion, m.memo, m.desc_norm, m.tipo_banco, b.dias::int, b.motivo,
           m.importado_el
      from v_banco_bandeja b
      join movimientos_banco m on m.id = b.movimiento_id
     where b.motivo in ('sin_ticket', 'dudosa') and m.estado = 'pendiente'
       and not exists (select 1 from contador_propuestas p where p.movimiento_id = m.id and p.estado = 'pendiente')
     order by m.fecha, m.importado_el, m.id;
end $$;
revoke execute on function public.fn_contador_candidatos() from public, anon, authenticated, service_role;
comment on function public.fn_contador_candidatos() is 'c8: lo que espera una propuesta: los movimientos «sin_ticket» (o «dudosa») de v_banco_bandeja sin propuesta pendiente, los más viejos primero.';

-- EL TOPE DE GASTO (la tercera regla de la IA): bloqueado si el contador
-- está apagado, si el gasto de TODAS las acciones del mes llegó al tope
-- global de la app (asistente_ajustes.tope_mes_centavos) o si lo del
-- contador (accion contador_%) llegó al suyo (contador_config.tope_mes_centavos).
-- «aviso»: ya va por el aviso_pct de alguno de los dos.
create or replace function public.fn_contador_tope() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg      contador_config;
  v_mes    text;
  v_total  bigint;
  v_cont   bigint;
  v_glob   int;
  v_pct    int;
  v_motivo text;
begin
  perform fn_contador_exigir();
  cfg := fn_contador_cfg();
  v_mes := to_char(fn_fecha_miami(now()), 'YYYY-MM');
  select coalesce(sum(x.centavos), 0), coalesce(sum(x.centavos) filter (where x.accion like 'contador\_%'), 0)
    into v_total, v_cont
    from asistente_costo_mes x
   where x.mes = v_mes;
  select case when a.valor ~ '^[0-9]{1,9}$' then a.valor::int end into v_glob from asistente_ajustes a where a.clave = 'tope_mes_centavos';
  v_glob := coalesce(v_glob, 10000);
  select case when a.valor ~ '^[0-9]{1,3}$' then a.valor::int end into v_pct from asistente_ajustes a where a.clave = 'aviso_pct';
  v_pct := coalesce(v_pct, 80);
  v_motivo := case
                when not cfg.activa then 'el contador está apagado (contador_config.activa = false): la bandeja sigue como siempre'
                when v_total >= v_glob
                  then format('el gasto de la IA de este mes (%s, todas las acciones) llegó al tope de la app (%s): hasta el mes que '
                              'viene, o sube asistente_ajustes.tope_mes_centavos', fn_contador_usd(v_total / 100.0),
                              fn_contador_usd(v_glob / 100.0))
                when v_cont >= cfg.tope_mes_centavos
                  then format('el gasto del contador de este mes (%s) llegó a su tope (%s): hasta el mes que viene, o sube '
                              'contador_config.tope_mes_centavos', fn_contador_usd(v_cont / 100.0), fn_contador_usd(cfg.tope_mes_centavos / 100.0))
              end;
  return jsonb_build_object(
    'mes', v_mes, 'centavos_mes_total', v_total, 'tope_global', v_glob, 'centavos_mes_contador', v_cont,
    'tope_contador', cfg.tope_mes_centavos, 'activa', cfg.activa, 'bloqueado', v_motivo is not null, 'motivo', v_motivo,
    'aviso_pct', v_pct,
    'aviso', v_motivo is null and (v_total * 100 >= v_glob * v_pct or v_cont * 100 >= cfg.tope_mes_centavos * v_pct),
    'restante_centavos', greatest(least(v_glob - v_total, cfg.tope_mes_centavos - v_cont), 0));
end $$;
revoke execute on function public.fn_contador_tope() from public, anon, authenticated, service_role;
comment on function public.fn_contador_tope() is 'c8: el gasto de la IA del mes contra el tope global de la app y el propio del contador: bloqueado (y por qué), aviso y lo que queda.';

-- LO QUE SE LE DA A LA IA: los movimientos que esperan (hasta el límite,
-- nunca más que max_por_rafaga) y el contexto: las cuentas permitidas, las
-- obras activas, las reglas activas (y su versión: md5 de todas, para
-- congelarla en cada propuesta), los últimos 30 ejemplos de lo que Edgar
-- clasificó (por comercio distinto: aprende de sus correcciones, también
-- de las que hizo a mano antes de la IA) y el tope. Todo ordenado y sin
-- fechas ni ids de lote: así el prefijo es idéntico entre llamadas y
-- cachea. Sin correos, teléfonos ni números de cuenta.
create or replace function public.fn_contador_pendientes(p_limite int default 20) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg       contador_config;
  v_lim     int;
  v_total   int;
  v_movs    jsonb;
  v_ctas    jsonb;
  v_obras   jsonb;
  v_reglas  jsonb;
  v_version text;
  v_ej      jsonb;
begin
  perform fn_contador_exigir();
  cfg := fn_contador_cfg();
  v_lim := least(greatest(coalesce(p_limite, cfg.max_por_rafaga), 1), cfg.max_por_rafaga);
  select count(*) into v_total from fn_contador_candidatos();
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'movimiento_id', c.movimiento_id, 'cuenta', c.cuenta, 'cuenta_nombre', c.cuenta_nombre, 'fecha', c.fecha, 'monto', c.monto,
           'descripcion', fn_contador_sin_datos(c.descripcion), 'memo', fn_contador_sin_datos(c.memo),
           'desc_norm', fn_contador_sin_datos_norm(c.desc_norm, c.descripcion, c.memo), 'tipo_banco', c.tipo_banco, 'dias', c.dias,
           'motivo', c.motivo))
           order by c.fecha, c.importado_el, c.movimiento_id), '[]'::jsonb)
    into v_movs
    from (select * from fn_contador_candidatos() limit v_lim) c;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('codigo', v.codigo, 'nombre', v.nombre, 'tipo', v.tipo,
                                                                  'regla_obra', v.regla_obra, 'etiqueta_fiscal', v.etiqueta_fiscal))
                            order by v.codigo), '[]'::jsonb)
    into v_ctas
    from v_contador_cuentas v;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'nombre', p.nombre, 'estado', p.estado, 'tipo', p.tipo) order by p.nombre, p.id),
                  '[]'::jsonb)
    into v_obras
    from proyectos p
   where p.estado in ('aprobado', 'ejecucion', 'pausa');
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('nombre', r.nombre, 'patron', r.patron, 'cuenta_banco', r.cuenta_banco,
                                                                  'lineas', r.lineas, 'pide_obra', r.pide_obra))
                            order by r.patron, coalesce(r.cuenta_banco, '')), '[]'::jsonb),
         md5(coalesce(string_agg(r.patron || '|' || coalesce(r.cuenta_banco, '') || '|' || r.lineas::text || '|' || r.pide_obra::text, E'\n'
                                 order by r.patron, coalesce(r.cuenta_banco, '')), ''))
    into v_reglas, v_version
    from contador_reglas r
   where r.activa;
  -- los ejemplos: lo que Edgar clasificó (por la IA o a mano, c6), vivo en
  -- el libro, uno por comercio distinto, los 30 últimos
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('desc', fn_contador_sin_datos_norm(e.desc_norm, e.descripcion, e.memo),
                                                                  'cuenta', e.cuenta, 'proyecto_id', e.proyecto_id))
                            order by e.casado_el desc, e.desc_norm), '[]'::jsonb)
    into v_ej
    from (select x.* from (select distinct on (m.desc_norm) m.desc_norm, m.descripcion, m.memo, l.cuenta, l.proyecto_id, m.casado_el
                             from movimientos_banco m
                             join lateral (select al.cuenta, al.proyecto_id from asiento_lineas al
                                            where al.asiento_id = m.asiento_id and al.cuenta <> m.cuenta
                                            order by abs(al.monto) desc, al.orden limit 1) l on true
                            where m.estado = 'casado' and m.casado_clase = 'clasificado' and m.asiento_id is not null
                              and not exists (select 1 from asientos r
                                               where r.reversa_a = m.asiento_id and r.camino in ('reverso', 'reverso_automatico'))
                            order by m.desc_norm, m.casado_el desc) x
           order by x.casado_el desc, x.desc_norm
           limit 30) e;
  return jsonb_build_object(
    'movimientos', v_movs, 'total', v_total, 'limite', v_lim,
    'contexto', jsonb_build_object('cuentas', v_ctas, 'proyectos', v_obras, 'reglas', v_reglas, 'reglas_version', v_version,
                                   'ejemplos', v_ej),
    'tope', fn_contador_tope(),
    'config', jsonb_build_object('modelo', cfg.modelo, 'effort', cfg.effort, 'max_por_rafaga', cfg.max_por_rafaga,
                                 'prompt_version', cfg.prompt_version, 'prefijo_hash', cfg.prefijo_hash));
end $$;
revoke execute on function public.fn_contador_pendientes(int) from public, anon, authenticated, service_role;
comment on function public.fn_contador_pendientes(int) is 'c8: los movimientos que esperan propuesta (hasta el límite) y el contexto para la IA: cuentas permitidas, obras activas, reglas y su versión, los últimos 30 ejemplos de Edgar, y el tope.';

-- LAS REGLAS, ANTES QUE LA IA (Postgres contesta gratis): para cada
-- movimiento que espera, la regla activa que casa (desc_norm ~* patron, y
-- de su cuenta o de cualquiera); si casan varias, la más específica (el
-- patrón más largo); un empate no decide y se deja a la IA. Una propuesta
-- de la regla ya rechazada para ese movimiento no se repite. La propuesta
-- lleva confianza 1, «Regla: <nombre>», sus líneas (con el monto de cada
-- parte, si son varias) y pide_obra si alguna cuenta pide obra y la regla
-- no la trae. Una regla cuya cuenta ya no se puede proponer no se aplica
-- (y se dice: reglas_rotas; el cuadre 62 la nombra).
create or replace function public.fn_contador_reglas_aplicar(p_dueno uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c        record;
  r        contador_reglas;
  v_best   contador_reglas;
  v_len    int;
  v_empate boolean;
  v_ok     boolean;
  v_rotas  text[] := '{}';
  v_n      int := 0;
  v_nc     int := 0;
  v_lineas jsonb;
  v_l      jsonb;
  v_nl     int;
  v_i      int;
  v_monto  numeric(14,2);
  v_suma   numeric(14,2);
  v_m      numeric(14,2);
  v_parte  numeric;
  v_mal    text;
  v_obra   boolean;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  -- (dos «Proponer» a la vez se esperan: milisegundos)
  perform pg_advisory_xact_lock(820261031, hashtext('contador:reglas'));
  for c in select * from fn_contador_candidatos() loop
    v_nc := v_nc + 1;
    v_best := null;
    v_len := null;
    v_empate := false;
    for r in select x.* from contador_reglas x
              where x.activa and (x.cuenta_banco is null or x.cuenta_banco = c.cuenta)
              order by length(x.patron) desc, x.creada_el loop
      begin
        v_ok := c.desc_norm ~* r.patron;
      exception when others then
        -- (un patrón que Postgres no puede leer: no debería existir, regla_alta lo valida)
        if not (r.nombre = any (v_rotas)) then v_rotas := v_rotas || r.nombre; end if;
        continue;
      end;
      continue when not v_ok;
      if v_best.id is null then
        v_best := r;
        v_len := length(r.patron);
      elsif length(r.patron) = v_len then
        v_empate := true;
        exit;
      else
        exit;
      end if;
    end loop;
    continue when v_best.id is null or v_empate;
    continue when exists (select 1 from contador_propuestas p
                           where p.movimiento_id = c.movimiento_id and p.regla_id = v_best.id and p.estado = 'rechazada');
    -- sus líneas, con el monto de cada parte (la última absorbe el redondeo)
    v_nl := jsonb_array_length(v_best.lineas);
    v_monto := abs(c.monto);
    v_suma := 0;
    v_i := 0;
    v_lineas := '[]'::jsonb;
    v_mal := null;
    v_obra := false;
    for v_l in select value from jsonb_array_elements(v_best.lineas) loop
      v_i := v_i + 1;
      v_mal := coalesce(v_mal, fn_contador_cuenta_permitida(v_l->>'cuenta'));
      if v_nl = 1 then
        v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', v_l->>'cuenta', 'proyecto_id', v_l->>'proyecto_id')));
      else
        v_parte := coalesce(nullif(v_l->>'parte', '')::numeric, 1.0 / v_nl);
        v_m := case when v_i = v_nl then v_monto - v_suma else round(v_monto * v_parte, 2) end;
        v_suma := v_suma + v_m;
        v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                      'cuenta', v_l->>'cuenta', 'monto', v_m::numeric(14,2)::text, 'proyecto_id', v_l->>'proyecto_id')));
      end if;
      v_obra := v_obra or (nullif(v_l->>'proyecto_id', '') is null
                           and exists (select 1 from cuentas k where k.codigo = v_l->>'cuenta' and k.regla_obra = 'obligatoria'));
    end loop;
    if v_mal is not null or (v_nl > 1 and v_suma <> v_monto) then
      if not (v_best.nombre = any (v_rotas)) then v_rotas := v_rotas || v_best.nombre; end if;
      continue;
    end if;
    begin
      insert into contador_propuestas (movimiento_id, fuente, regla_id, propuesta, entrada)
      values (c.movimiento_id, 'regla', v_best.id,
              jsonb_build_object('lineas', v_lineas, 'motivo', 'Regla: ' || v_best.nombre, 'confianza', 1,
                                 'flags', case when v_obra then '{"pide_obra": true}'::jsonb else '{}'::jsonb end),
              jsonb_build_object('regla', v_best.id, 'nombre', v_best.nombre, 'patron', v_best.patron,
                                 'desc_norm', fn_contador_sin_datos_norm(c.desc_norm, c.descripcion, c.memo)));
    exception when unique_violation then
      continue;   -- (otra ráfaga llegó antes a este movimiento)
    end;
    update contador_reglas set veces = veces + 1, ultima_vez = now() where id = v_best.id;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('propuestas', v_n, 'candidatos', v_nc, 'reglas_rotas', to_jsonb(v_rotas));
end $$;
revoke execute on function public.fn_contador_reglas_aplicar(uuid) from public, anon, authenticated, service_role;
comment on function public.fn_contador_reglas_aplicar(uuid) is 'c8: a cada movimiento que espera, la regla activa más específica que casa deja su propuesta (confianza 1); un empate, ninguna; una rechazada no se repite.';


-- ---------------------------------------------------------------------
-- 6. Las ráfagas (lotes) y el gasto
-- ---------------------------------------------------------------------
-- Abre una ráfaga: quién, con qué modelo y esfuerzo (solo Opus y Fable:
-- ni Haiku ni Sonnet, en ninguna parte), la versión del prompt y el hash
-- del prefijo, y cuántos movimientos se van a mandar. Con el tope del mes
-- gastado no se abre (MX008): no se gasta ni un token. UNA SOLA A LA VEZ:
-- con otra abierta hace menos de cinco minutos tampoco se abre (MX008 «ya
-- hay una ráfaga en marcha»: dos «Proponer» a la vez mandarían los mismos
-- cargos a Anthropic y pagarían dos veces); una abierta hace más es una
-- función que se cortó sin cerrar, y se da por perdida aquí (cerrada con su
-- error y sin uso: la alarma 72 lo dice).
create or replace function public.fn_contador_lote_abrir(p_por uuid, p_modelo text, p_effort text, p_prompt_version text,
                                                         p_prefijo_hash text, p_n int)
returns uuid
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_viva constant interval := interval '5 minutes';   -- (lo que una ráfaga puede durar, de sobra: la función se corta a los 2 min)
  cfg  contador_config;
  l    contador_lotes;
  v_t  jsonb;
  v_id uuid;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_por);
  cfg := fn_contador_cfg();
  if p_modelo is null or p_modelo !~ '^claude-(opus|fable)-' or p_modelo ~* '(haiku|sonnet)' then
    raise exception using errcode = '22023',
      message = format('Solo Opus y Fable (%s): ni Haiku ni Sonnet, en ninguna parte (llegó «%s»).', cfg.modelo, coalesce(p_modelo, ''));
  end if;
  if p_effort is null or p_effort not in ('low', 'medium', 'high', 'xhigh', 'max') then
    raise exception using errcode = '22023', message = format('El esfuerzo es low, medium, high, xhigh o max (llegó «%s»).', coalesce(p_effort, ''));
  end if;
  if p_n is null or p_n < 0 or p_n > cfg.max_por_rafaga then
    raise exception using errcode = '22023',
      message = format('Una ráfaga lleva de 0 a %s movimientos (max_por_rafaga); llegó %s.', cfg.max_por_rafaga, coalesce(p_n::text, 'nada'));
  end if;
  -- una sola ráfaga a la vez: el candado serializa la comprobación; las
  -- perdidas (abiertas hace más de c_viva) se cierran con su error primero
  perform pg_advisory_xact_lock(820261031, hashtext('contador:rafaga'));
  for l in select * from contador_lotes where cerrado_el is null and creado_el < now() - c_viva order by creado_el loop
    perform fn_contador_lote_cerrar(l.id, '{}'::jsonb,
      format('la ráfaga de las %s (hora de Miami) se cortó sin cerrar (la función no volvió en %s minutos): su gasto no quedó anotado',
             to_char(l.creado_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI'), (extract(epoch from c_viva) / 60)::int));
  end loop;
  select * into l from contador_lotes where cerrado_el is null order by creado_el limit 1;
  if found then
    raise exception using errcode = 'MX008',
      message = format('Ya hay una ráfaga en marcha (la abrió %s hace %s s): espera a que termine y vuelve a mirar la bandeja. Si la función '
                       'se cortó, la base la da por perdida a los %s minutos.',
                       coalesce((select p.nombre from perfiles p where p.id = l.por), 'el dueño'),
                       extract(epoch from now() - l.creado_el)::int, (extract(epoch from c_viva) / 60)::int);
  end if;
  v_t := fn_contador_tope();
  if (v_t->>'bloqueado')::boolean then
    raise exception using errcode = 'MX008', message = 'No se abre la ráfaga: ' || (v_t->>'motivo') || '.';
  end if;
  insert into contador_lotes (modelo, effort, prompt_version, prefijo_hash, n, por)
  values (p_modelo, p_effort, nullif(btrim(p_prompt_version), ''), nullif(btrim(p_prefijo_hash), ''), p_n, p_por)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.fn_contador_lote_abrir(uuid, text, text, text, text, int) from public, anon, authenticated, service_role;
comment on function public.fn_contador_lote_abrir(uuid, text, text, text, text, int) is 'c8: abre una ráfaga a la IA (modelo, esfuerzo, versión del prompt, hash del prefijo, cuántos); con el tope gastado o con otra ráfaga en marcha (abierta hace menos de 5 min), MX008; una abierta hace más se da por perdida (cerrada con su error).';

-- Anota el gasto de una ráfaga donde la app lo lee: en asistente_uso
-- (asistente_costo_mes es la vista de la app sobre ella: una fila por
-- ráfaga con el dueño, el modelo, sus tokens, vueltas = las llamadas y sus
-- centavos, resultado «ok» o el error; la vista suma) o, si en esa base
-- asistente_costo_mes fuera una tabla, allí (una fila por mes y acción,
-- con llamadas += n). Devuelve dónde quedó.
create or replace function public.fn_contador_gasto_anotar(p_mes text, p_modelo text, p_n int, p_usage jsonb, p_centavos int, p_por uuid,
                                                           p_error text)
returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_k   char;
  v_por uuid;
begin
  perform fn_contador_exigir();
  select c.relkind into v_k from pg_class c where c.oid = to_regclass('public.asistente_costo_mes');
  if v_k = 'r' then
    insert into asistente_costo_mes (mes, accion, llamadas, centavos, entrada, salida, cache_lectura)
    values (p_mes, 'contador_categorizar', coalesce(p_n, 0), coalesce(p_centavos, 0), (p_usage->>'input')::bigint, (p_usage->>'output')::bigint,
            (p_usage->>'cache_lectura')::bigint)
    on conflict (mes, accion) do update
       set llamadas      = asistente_costo_mes.llamadas + excluded.llamadas,
           centavos      = asistente_costo_mes.centavos + excluded.centavos,
           entrada       = asistente_costo_mes.entrada + excluded.entrada,
           salida        = asistente_costo_mes.salida + excluded.salida,
           cache_lectura = asistente_costo_mes.cache_lectura + excluded.cache_lectura;
    return 'asistente_costo_mes';
  elsif v_k = 'v' and (select r.relkind from pg_class r where r.oid = to_regclass('public.asistente_uso')) = 'r' then
    select p.id into v_por from perfiles p where p.id = p_por;
    insert into asistente_uso (usuario_id, rol, modelo, entrada, salida, vueltas, accion, cache_lectura, cache_escritura, resultado,
                               costo_centavos)
    values (v_por, 'dueno', p_modelo, (p_usage->>'input')::int, (p_usage->>'output')::int, coalesce(p_n, 0), 'contador_categorizar',
            (p_usage->>'cache_lectura')::int, (p_usage->>'cache_creacion')::int, coalesce(left(p_error, 200), 'ok'), coalesce(p_centavos, 0));
    return 'asistente_uso';
  end if;
  raise exception using errcode = 'MX009',
    message = 'No sé dónde anotar el gasto: asistente_costo_mes no es una tabla ni la vista de la app sobre asistente_uso.';
end $$;
revoke execute on function public.fn_contador_gasto_anotar(text, text, int, jsonb, int, uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_gasto_anotar(text, text, int, jsonb, int, uuid, text) is 'c8: anota el gasto de una ráfaga en asistente_costo_mes (tabla) o en asistente_uso (la vista de la app); devuelve dónde.';

-- Cierra una ráfaga con el uso sumado de sus llamadas ({"input","output",
-- "cache_creacion","cache_lectura"} en tokens; lo que falte cuenta 0) y,
-- si la cortó algo, su error. Los centavos: entrada × 400 + caché creado ×
-- 500 + caché leído × 20 + salida × 2000, entre un millón, redondeado (los
-- precios de claude-opus-5-5: $4 / $20, caché $5 / $0.20 por millón). Lo
-- anota en el gasto del mes y guarda en contador_config la versión del prompt,
-- el prefijo y la hora de la ráfaga (y su error, si lo hubo).
create or replace function public.fn_contador_lote_cerrar(p_lote uuid, p_usage jsonb, p_error text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  l        contador_lotes;
  v_u      jsonb := '{}'::jsonb;
  v_k      text;
  v_v      jsonb;
  v_cent   int;
  v_mes    text;
  v_donde  text;
begin
  perform fn_contador_exigir();
  select * into l from contador_lotes where id = p_lote for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa ráfaga (lote).';
  end if;
  if l.cerrado_el is not null then
    raise exception using errcode = 'MX008', message = format('La ráfaga %s ya está cerrada (el %s): su gasto ya está anotado.', l.id, l.cerrado_el);
  end if;
  if p_usage is not null and jsonb_typeof(p_usage) <> 'object' then
    raise exception using errcode = '22023', message = 'El uso de la ráfaga llega como un objeto {input, output, cache_creacion, cache_lectura}.';
  end if;
  foreach v_k in array array['input', 'output', 'cache_creacion', 'cache_lectura'] loop
    v_v := coalesce(p_usage->v_k, '0'::jsonb);
    if not ((jsonb_typeof(v_v) = 'number' and v_v::text ~ '^[0-9]{1,12}$')
            or (jsonb_typeof(v_v) = 'string' and v_v #>> '{}' ~ '^[0-9]{1,12}$')) then
      raise exception using errcode = '22023', message = format('El uso «%s» va en tokens, como entero (llegó %s).', v_k, v_v::text);
    end if;
    v_u := v_u || jsonb_build_object(v_k, (v_v #>> '{}')::bigint);
  end loop;
  v_cent := round(((v_u->>'input')::numeric * 400 + (v_u->>'cache_creacion')::numeric * 500 + (v_u->>'cache_lectura')::numeric * 20
                   + (v_u->>'output')::numeric * 2000) / 1000000)::int;
  v_mes := to_char(fn_fecha_miami(now()), 'YYYY-MM');
  update contador_lotes
     set usage = v_u, centavos = v_cent, cerrado_el = now(), error = left(nullif(btrim(p_error), ''), 600)
   where id = l.id
  returning * into l;
  v_donde := fn_contador_gasto_anotar(v_mes, l.modelo, l.n, v_u, v_cent, l.por, l.error);
  update contador_config
     set prompt_version   = coalesce(l.prompt_version, prompt_version),
         prefijo_hash     = coalesce(l.prefijo_hash, prefijo_hash),
         ultima_rafaga_el = now(),
         ultimo_error     = case when l.error is not null then l.error else ultimo_error end,
         ultimo_error_el  = case when l.error is not null then now() else ultimo_error_el end,
         actualizado      = now()
   where id = 1;
  return jsonb_build_object('lote', l.id, 'n', l.n, 'propuestas', (select count(*) from contador_propuestas p where p.lote_id = l.id),
                            'usage', v_u, 'centavos', v_cent, 'mes', v_mes, 'anotado_en', v_donde, 'error', l.error,
                            'tope', fn_contador_tope());
end $$;
revoke execute on function public.fn_contador_lote_cerrar(uuid, jsonb, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_lote_cerrar(uuid, jsonb, text) is 'c8: cierra una ráfaga con su uso en tokens: calcula sus centavos (precios de claude-opus-5-5), los anota en el gasto del mes y guarda en contador_config la versión del prompt, el prefijo, la hora y el error.';


-- ---------------------------------------------------------------------
-- 7. Las propuestas: validar, guardar, aprobar, clasificar, rechazar
-- ---------------------------------------------------------------------
-- LAS LÍNEAS de una propuesta o de Edgar ([{"cuenta","monto"?,
-- "proyecto_id"?}], de 1 a 5): cada cuenta permitida, la obra existe y la
-- cuenta la admite, con varias líneas cada una dice su monto y suman el
-- movimiento al centavo. Devuelve {lineas (normalizadas), pide_obra} o
-- {error, codigo} (la IA que falla no se guarda; Edgar lo ve en llano).
create or replace function public.fn_contador_lineas_validar(p_lineas jsonb, p_monto numeric) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_l     jsonb;
  v_i     int := 0;
  v_n     int;
  v_out   jsonb := '[]'::jsonb;
  v_mal   text;
  v_sobra text;
  c       cuentas;
  v_obra  text;
  v_txt   text;
  v_m     numeric;
  v_suma  numeric := 0;
  v_pide  boolean := false;
begin
  perform fn_contador_exigir();
  if p_lineas is null or jsonb_typeof(p_lineas) <> 'array' or jsonb_array_length(p_lineas) = 0 then
    return jsonb_build_object('error', 'las líneas van como una lista ([{"cuenta": "…", "monto"?, "proyecto_id"?}]), con al menos una',
                              'codigo', '22023');
  end if;
  v_n := jsonb_array_length(p_lineas);
  if v_n > 5 then
    return jsonb_build_object('error', format('como mucho 5 líneas (llegaron %s)', v_n), 'codigo', '22023');
  end if;
  for v_l in select value from jsonb_array_elements(p_lineas) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_l) <> 'object' then
      return jsonb_build_object('error', format('Línea %s: va como objeto JSON ({"cuenta": "…"})', v_i), 'codigo', '22023');
    end if;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_l) k where k not in ('cuenta', 'monto', 'proyecto_id');
    if v_sobra is not null then
      return jsonb_build_object('error', format('Línea %s: clave desconocida: %s (solo cuenta, monto y proyecto_id)', v_i, v_sobra),
                                'codigo', '22023');
    end if;
    if jsonb_typeof(v_l->'cuenta') is distinct from 'string' then
      return jsonb_build_object('error', format('Línea %s: falta la cuenta (un texto con su código)', v_i), 'codigo', 'MX004');
    end if;
    v_mal := fn_contador_cuenta_permitida(v_l->>'cuenta');
    if v_mal is not null then
      return jsonb_build_object('error', format('Línea %s: %s', v_i, v_mal), 'codigo', 'MX004');
    end if;
    select * into c from cuentas where codigo = btrim(v_l->>'cuenta');
    v_obra := nullif(btrim(coalesce(v_l->>'proyecto_id', '')), '');
    if v_l ? 'proyecto_id' and jsonb_typeof(v_l->'proyecto_id') not in ('string', 'null') then
      return jsonb_build_object('error', format('Línea %s: proyecto_id es el id de la obra (un texto)', v_i), 'codigo', '22023');
    end if;
    if v_obra is not null then
      if not exists (select 1 from proyectos p where p.id = v_obra) then
        return jsonb_build_object('error', format('Línea %s: la obra «%s» no existe', v_i, v_obra), 'codigo', 'MX006');
      end if;
      if c.regla_obra = 'prohibida' then
        return jsonb_build_object('error', format('Línea %s: la cuenta %s (%s) no lleva obra', v_i, c.codigo, c.nombre), 'codigo', 'MX006');
      end if;
    elsif c.regla_obra = 'obligatoria' then
      v_pide := true;
    end if;
    v_m := null;
    if v_l ? 'monto' and jsonb_typeof(v_l->'monto') <> 'null' then
      if jsonb_typeof(v_l->'monto') not in ('number', 'string') then
        return jsonb_build_object('error', format('Línea %s: el monto va en dólares (un número o un texto)', v_i), 'codigo', 'MX005');
      end if;
      v_txt := replace(btrim(v_l #>> '{monto}'), ',', '');
      if v_txt !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' or v_txt::numeric <= 0 then
        return jsonb_build_object('error', format('Línea %s: el monto va en dólares, positivo y con dos decimales como mucho (llegó «%s»)',
                                                  v_i, v_txt), 'codigo', 'MX005');
      end if;
      v_m := v_txt::numeric;
      v_suma := v_suma + v_m;
    elsif v_n > 1 then
      return jsonb_build_object('error', format('Línea %s: con varias líneas, cada una dice su monto', v_i), 'codigo', 'MX001');
    end if;
    v_out := v_out || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'cuenta', c.codigo, 'monto', case when v_m is not null then v_m::numeric(14,2)::text end, 'proyecto_id', v_obra)));
  end loop;
  if p_monto is not null and v_n > 1 and v_suma <> abs(p_monto) then
    return jsonb_build_object('error', format('Las líneas suman %s y el movimiento es de %s: tienen que sumar lo mismo, al centavo',
                                              v_suma::numeric(14,2), abs(p_monto)::numeric(14,2)), 'codigo', 'MX001');
  end if;
  if p_monto is not null and v_n = 1 and v_m is not null and v_m <> abs(p_monto) then
    return jsonb_build_object('error', format('La línea dice %s y el movimiento es de %s: una sola línea va entera (o sin monto)',
                                              v_m::numeric(14,2), abs(p_monto)::numeric(14,2)), 'codigo', 'MX001');
  end if;
  return jsonb_build_object('lineas', v_out, 'pide_obra', v_pide);
end $$;
revoke execute on function public.fn_contador_lineas_validar(jsonb, numeric) from public, anon, authenticated, service_role;
comment on function public.fn_contador_lineas_validar(jsonb, numeric) is 'c8: valida y normaliza las líneas de una propuesta (cuentas permitidas, obra, montos que suman el movimiento): {lineas, pide_obra} o {error, codigo}.';

-- GUARDAR LO QUE CONTESTÓ LA IA: la función de borde lo pide por cada
-- respuesta, ANTES de enseñar nada. Se guarda solo si pasa (si no, {error,
-- codigo} y nada queda): el movimiento sigue pendiente y «sin_ticket»; la
-- propuesta trae sus líneas válidas, un motivo (3 a 600 letras) y una
-- confianza entre 0 y 1; los flags son los conocidos (capitalizable,
-- use_tax, personal, irs, pide_obra), y pide_obra lo decide la base por
-- las cuentas; las alternativas a una cuenta que no se puede proponer se
-- quitan (se dice cuántas). La pendiente anterior del mismo movimiento
-- pasa a «caducada». Lo que se le dio (entrada) se guarda sin correos,
-- teléfonos ni números de cuenta.
create or replace function public.fn_contador_propuesta_guardar(p_movimiento uuid, p_lote uuid, p_entrada jsonb, p_salida jsonb,
                                                                p_propuesta jsonb, p_modelo text, p_effort text, p_prompt_version text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  l       contador_lotes;
  m       movimientos_banco;
  v_bmot  text;
  v_sobra text;
  v_conf  numeric;
  v_val   jsonb;
  v_flags jsonb;
  v_alt   jsonb;
  v_fuera int := 0;
  v_prev  uuid;
  v_id    uuid;
begin
  perform fn_contador_exigir();
  if p_movimiento is null or p_lote is null then
    raise exception using errcode = '22023', message = 'Guardar una propuesta lleva el movimiento y la ráfaga (lote).';
  end if;
  select * into l from contador_lotes where id = p_lote;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa ráfaga (lote).';
  end if;
  if p_modelo is null or p_modelo !~ '^claude-(opus|fable)-' or p_modelo ~* '(haiku|sonnet)' then
    raise exception using errcode = '22023', message = format('Solo Opus y Fable: ni Haiku ni Sonnet, en ninguna parte (llegó «%s»).', coalesce(p_modelo, ''));
  end if;
  if p_effort is null or p_effort not in ('low', 'medium', 'high', 'xhigh', 'max') then
    raise exception using errcode = '22023', message = format('El esfuerzo es low, medium, high, xhigh o max (llegó «%s»).', coalesce(p_effort, ''));
  end if;
  perform pg_advisory_xact_lock(820261031, hashtext('contador:' || p_movimiento::text));
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  if m.estado <> 'pendiente' then
    return jsonb_build_object('error', format('el movimiento ya no está pendiente (está %s): la propuesta no se guarda', m.estado),
                              'codigo', 'MX008');
  end if;
  select b.motivo into v_bmot from v_banco_bandeja b where b.movimiento_id = m.id;
  if v_bmot is null or v_bmot not in ('sin_ticket', 'dudosa') then
    return jsonb_build_object('error', format('la bandeja ya dice otra cosa de este movimiento (%s): la propuesta no se guarda',
                                              coalesce(v_bmot, 'ya no está en la bandeja')), 'codigo', 'MX008');
  end if;
  -- la forma de la propuesta
  if p_propuesta is null or jsonb_typeof(p_propuesta) <> 'object' then
    return jsonb_build_object('error', 'la propuesta llega como un objeto {lineas, motivo, confianza, flags?, alternativas?}', 'codigo', '22023');
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_propuesta) k
   where k not in ('lineas', 'motivo', 'confianza', 'flags', 'alternativas');
  if v_sobra is not null then
    return jsonb_build_object('error', format('la propuesta trae claves que no conozco: %s', v_sobra), 'codigo', '22023');
  end if;
  if jsonb_typeof(p_propuesta->'motivo') is distinct from 'string' or length(btrim(p_propuesta->>'motivo')) not between 3 and 600 then
    return jsonb_build_object('error', 'la propuesta no dice por qué (motivo, de 3 a 600 letras): sin motivo no se guarda («cita o se calla»)',
                              'codigo', '22023');
  end if;
  if jsonb_typeof(p_propuesta->'confianza') <> 'number' then
    return jsonb_build_object('error', 'la confianza va como un número entre 0 y 1', 'codigo', '22023');
  end if;
  v_conf := (p_propuesta->>'confianza')::numeric;
  if v_conf < 0 or v_conf > 1 then
    return jsonb_build_object('error', format('la confianza va entre 0 y 1 (llegó %s)', v_conf), 'codigo', '22023');
  end if;
  v_flags := coalesce(p_propuesta->'flags', '{}'::jsonb);
  if jsonb_typeof(v_flags) <> 'object'
     or exists (select 1 from jsonb_each(v_flags) f
                 where f.key not in ('capitalizable', 'use_tax', 'personal', 'irs', 'pide_obra') or jsonb_typeof(f.value) <> 'boolean') then
    return jsonb_build_object('error', 'los flags son un objeto con capitalizable, use_tax, personal, irs y pide_obra (true o false)',
                              'codigo', '22023');
  end if;
  v_val := fn_contador_lineas_validar(p_propuesta->'lineas', m.monto);
  if v_val ? 'error' then
    return jsonb_build_object('error', 'la propuesta no vale: ' || (v_val->>'error'), 'codigo', v_val->>'codigo');
  end if;
  -- pide_obra lo decide la base (las cuentas), no la IA
  v_flags := (v_flags - 'pide_obra') || case when (v_val->>'pide_obra')::boolean then '{"pide_obra": true}'::jsonb else '{}'::jsonb end;
  -- las alternativas: solo a cuentas que se pueden proponer
  if p_propuesta ? 'alternativas' and jsonb_typeof(p_propuesta->'alternativas') = 'array' then
    select coalesce(jsonb_agg(jsonb_build_object('cuenta', btrim(x->>'cuenta'), 'motivo', left(btrim(coalesce(x->>'motivo', '')), 300))
                              order by o), '[]'::jsonb),
           count(*) filter (where jsonb_typeof(x) <> 'object' or fn_contador_cuenta_permitida(x->>'cuenta') is not null)
      into v_alt, v_fuera
      from jsonb_array_elements(p_propuesta->'alternativas') with ordinality as a(x, o)
     where jsonb_typeof(x) = 'object' and fn_contador_cuenta_permitida(x->>'cuenta') is null;
    select count(*) - jsonb_array_length(v_alt) into v_fuera from jsonb_array_elements(p_propuesta->'alternativas');
    if jsonb_array_length(v_alt) > 5 then
      v_alt := (select jsonb_agg(e) from (select e from jsonb_array_elements(v_alt) e limit 5) z);
    end if;
    if jsonb_array_length(v_alt) = 0 then v_alt := null; end if;
  end if;
  -- la pendiente anterior, caducada; la nueva, pendiente
  update contador_propuestas
     set estado = 'caducada', nota = format('la IA propuso otra vez (ráfaga %s)', l.id)
   where movimiento_id = m.id and estado = 'pendiente'
  returning id into v_prev;
  insert into contador_propuestas (movimiento_id, fuente, lote_id, modelo, effort, prompt_version, entrada, salida, propuesta)
  values (m.id, 'ia', l.id, p_modelo, p_effort, nullif(btrim(p_prompt_version), ''), fn_contador_sin_datos_jsonb(p_entrada), p_salida,
          jsonb_strip_nulls(jsonb_build_object('lineas', v_val->'lineas', 'motivo', btrim(p_propuesta->>'motivo'),
                                               'confianza', round(v_conf, 3), 'flags', v_flags, 'alternativas', v_alt)))
  returning id into v_id;
  return jsonb_strip_nulls(jsonb_build_object('propuesta', v_id, 'estado', 'pendiente', 'pide_obra', (v_val->>'pide_obra')::boolean,
                                              'caducada', v_prev, 'alternativas_fuera', nullif(v_fuera, 0)));
end $$;
revoke execute on function public.fn_contador_propuesta_guardar(uuid, uuid, jsonb, jsonb, jsonb, text, text, text)
  from public, anon, authenticated, service_role;
comment on function public.fn_contador_propuesta_guardar(uuid, uuid, jsonb, jsonb, jsonb, text, text, text) is 'c8: guarda lo que contestó la IA para un movimiento, validado (cuentas permitidas, obra, montos, motivo, confianza, flags); si no vale, {error, codigo} y no se guarda. La pendiente anterior caduca.';

-- LA REGLA QUE NACE DE UNA APROBACIÓN («Recordar para este comercio»):
-- nombre = el comercio de desc_norm; patrón = «^» + el nombre escapado;
-- líneas = las cuentas de Edgar (con la parte de cada una si son varias;
-- sin la obra: v1); pide_obra según las cuentas; origen «aprobacion». Si ya
-- hay una activa con ese patrón (de cualquier origen), se actualiza y
-- queda escrito qué decía antes. Nulo si no se pudo sacar el comercio.
create or replace function public.fn_contador_regla_aprender(p_movimiento uuid, p_lineas jsonb, p_dueno uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  r        contador_reglas;
  v_nombre text;
  v_patron text;
  v_n      int;
  v_total  numeric;
  v_lineas jsonb;
  v_resto  numeric := 1;
  v_i      int := 0;
  v_l      jsonb;
  v_parte  numeric;
  v_pide   boolean;
  v_id     uuid;
begin
  perform fn_contador_exigir();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  v_nombre := fn_contador_nombre_comercio(m.desc_norm);
  if v_nombre is null then
    return jsonb_build_object('regla', null, 'motivo', format('no pude sacar el comercio de «%s»: dicta la regla con su patrón', m.desc_norm));
  end if;
  v_patron := '^' || fn_contador_regex_escapar(v_nombre);
  v_n := jsonb_array_length(p_lineas);
  if v_n = 1 then
    v_lineas := jsonb_build_array(jsonb_build_object('cuenta', p_lineas->0->>'cuenta'));
  else
    select sum((x->>'monto')::numeric) into v_total from jsonb_array_elements(p_lineas) x;
    v_lineas := '[]'::jsonb;
    for v_l in select value from jsonb_array_elements(p_lineas) loop
      v_i := v_i + 1;
      v_parte := case when v_i = v_n then v_resto else round((v_l->>'monto')::numeric / v_total, 4) end;
      v_resto := v_resto - v_parte;
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object('cuenta', v_l->>'cuenta', 'parte', v_parte));
    end loop;
  end if;
  select coalesce(bool_or(k.regla_obra = 'obligatoria'), false) into v_pide
    from jsonb_array_elements(v_lineas) x join cuentas k on k.codigo = x->>'cuenta';
  select * into r from contador_reglas where activa and patron = v_patron and cuenta_banco is null for update;
  if found then
    if r.lineas = v_lineas and r.pide_obra = v_pide then
      update contador_reglas set ultima_vez = coalesce(ultima_vez, now()) where id = r.id;
      return jsonb_build_object('regla', r.id, 'nombre', r.nombre, 'patron', r.patron, 'nueva', false, 'cambio', false);
    end if;
    update contador_reglas
       set lineas = v_lineas, pide_obra = v_pide, ultima_vez = now(),
           notas = left(concat_ws(E'\n', notas, format('%s: al aprobar el movimiento del %s por %s («%s») cambió de %s a %s',
                                                     fn_fecha_miami(now()), m.fecha, m.monto, m.desc_norm, r.lineas::text, v_lineas::text)), 4000)
     where id = r.id;
    return jsonb_build_object('regla', r.id, 'nombre', r.nombre, 'patron', r.patron, 'nueva', false, 'cambio', true, 'antes', r.lineas);
  end if;
  insert into contador_reglas (nombre, patron, lineas, pide_obra, origen, creada_por, notas)
  values (v_nombre, v_patron, v_lineas, v_pide, 'aprobacion', p_dueno,
          format('aprendida al aprobar el movimiento del %s por %s («%s»)', m.fecha, m.monto, m.desc_norm))
  returning id into v_id;
  return jsonb_build_object('regla', v_id, 'nombre', v_nombre, 'patron', v_patron, 'nueva', true, 'cambio', false);
end $$;
revoke execute on function public.fn_contador_regla_aprender(uuid, jsonb, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_contador_regla_aprender(uuid, jsonb, uuid) is 'c8: crea (o actualiza) la regla del comercio de un movimiento con las líneas que Edgar aprobó (sin la obra); nulo si no se pudo sacar el comercio.';

-- EL ÚNICO CAMINO AL LIBRO. Con el dueño suplantado llama a
-- fn_banco_clasificar (c6) con las líneas de Edgar y un motivo (c6 lo
-- exige): el suyo, o «Propuesta de la IA #<id> aprobada|editada por Edgar:
-- <el motivo de la IA>» si había propuesta, o «Clasificado por Edgar desde
-- la bandeja (fase 7)». Los errores de c6 (MX008, MX004, MX001…) pasan tal
-- cual. Si había propuesta pendiente (la que se dice, o la del movimiento):
-- «aprobada» si las líneas coinciden con las suyas (cuenta y obra por
-- línea; la obra que la propuesta pedía y Edgar puso cuenta como suya),
-- «editada» si no; sin propuesta, se inserta una fuente «edgar» ya aprobada
-- (el rastro es uno). Una aprobada anterior del mismo movimiento cuyo
-- asiento ya no vive queda «caducada». Si p_recordar, aprende (o
-- actualiza) la regla del comercio.
create or replace function public.fn_contador_clasificar(p_movimiento uuid, p_dueno uuid, p_lineas jsonb, p_motivo text,
                                                         p_recordar boolean default true, p_propuesta uuid default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  pr       contador_propuestas;
  v_val    jsonb;
  v_lineas jsonb;
  v_pl     jsonb;
  v_pide   boolean;
  v_coinc  boolean;
  v_estado text;
  v_motivo text;
  v_edgar  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_s      jsonb;
  v_res    jsonb;
  v_pid    uuid;
  v_regla  jsonb;
  v_i      int;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  -- (el candado del casado primero: el orden de c6; después el del
  -- movimiento en el contador)
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  perform pg_advisory_xact_lock(820261031, hashtext('contador:' || coalesce(p_movimiento::text, '')));
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  v_val := fn_contador_lineas_validar(p_lineas, m.monto);
  if v_val ? 'error' then
    raise exception using errcode = coalesce(v_val->>'codigo', '22023'), message = v_val->>'error';
  end if;
  v_lineas := v_val->'lineas';
  if (v_val->>'pide_obra')::boolean then
    raise exception using errcode = 'MX008', hint = 'elige la obra',
      message = format('Elige la obra: %s pide obra y la línea no la trae.',
                       (select string_agg(k.codigo || ' (' || k.nombre || ')', ', ')
                          from jsonb_array_elements(v_lineas) x join cuentas k on k.codigo = x->>'cuenta'
                         where k.regla_obra = 'obligatoria' and nullif(x->>'proyecto_id', '') is null));
  end if;
  -- la propuesta pendiente (la que se dice, o la del movimiento)
  if p_propuesta is not null then
    select * into pr from contador_propuestas where id = p_propuesta for update;
    if not found then
      raise exception using errcode = '22023', message = 'No existe esa propuesta.';
    end if;
    if pr.movimiento_id <> m.id then
      raise exception using errcode = '22023', message = 'Esa propuesta es de otro movimiento.';
    end if;
    if pr.estado <> 'pendiente' then
      raise exception using errcode = 'MX008', message = format('Esa propuesta ya está %s: no se aprueba dos veces.', pr.estado);
    end if;
  else
    select * into pr from contador_propuestas where movimiento_id = m.id and estado = 'pendiente' for update;
  end if;
  if pr.id is not null then
    v_pl := pr.propuesta->'lineas';
    v_pide := coalesce((pr.propuesta->'flags'->>'pide_obra')::boolean, false);
    v_coinc := jsonb_array_length(v_pl) = jsonb_array_length(v_lineas);
    if v_coinc then
      for v_i in 0 .. jsonb_array_length(v_lineas) - 1 loop
        if (v_pl->v_i->>'cuenta') is distinct from (v_lineas->v_i->>'cuenta')
           or not (coalesce(v_pl->v_i->>'proyecto_id', '') = coalesce(v_lineas->v_i->>'proyecto_id', '')
                   or (nullif(v_pl->v_i->>'proyecto_id', '') is null and v_pide))
           or (v_pl->v_i ? 'monto' and v_lineas->v_i ? 'monto'
               and (v_pl->v_i->>'monto')::numeric <> (v_lineas->v_i->>'monto')::numeric) then
          v_coinc := false;
          exit;
        end if;
      end loop;
    end if;
    v_estado := case when v_coinc then 'aprobada' else 'editada' end;
    v_motivo := format('Propuesta de la IA #%s %s por Edgar: %s', pr.id, v_estado, pr.propuesta->>'motivo')
                || coalesce(' · Edgar: ' || v_edgar, '');
  else
    v_estado := 'aprobada';
    v_motivo := coalesce(v_edgar, 'Clasificado por Edgar desde la bandeja (fase 7)');
  end if;
  -- c6, en nombre del dueño (sus errores pasan tal cual; la transacción se
  -- deshace entera, con la suplantación)
  v_s := fn_contador_suplantar();
  v_res := fn_banco_clasificar(m.id, v_lineas, left(v_motivo, 900));
  perform fn_contador_soltar(v_s);
  select * into m from movimientos_banco where id = m.id;
  if m.asiento_id is null or m.estado <> 'casado' then
    raise exception using errcode = 'MX008',
      message = format('c6 clasificó el movimiento pero no quedó con su asiento (está %s): no se guarda la propuesta.', m.estado);
  end if;
  -- lo aprobado antes para este movimiento cuyo asiento ya no vive
  update contador_propuestas p
     set estado = 'caducada', nota = format('%s: su asiento se reversó y el movimiento se volvió a clasificar', fn_fecha_miami(now()))
   where p.movimiento_id = m.id and p.estado in ('aprobada', 'editada') and p.id is distinct from pr.id
     and (p.asiento_id is null
          or exists (select 1 from asientos r where r.reversa_a = p.asiento_id and r.camino in ('reverso', 'reverso_automatico')));
  if pr.id is not null then
    update contador_propuestas
       set estado = v_estado, aprobado_por = p_dueno, aprobado_el = now(), lineas_finales = v_lineas, motivo_edgar = v_edgar,
           asiento_id = m.asiento_id
     where id = pr.id;
    v_pid := pr.id;
  else
    insert into contador_propuestas (movimiento_id, fuente, propuesta, estado, aprobado_por, aprobado_el, lineas_finales, motivo_edgar,
                               asiento_id, entrada)
    values (m.id, 'edgar', jsonb_build_object('lineas', v_lineas, 'motivo', v_motivo, 'confianza', 1, 'flags', '{}'::jsonb), 'aprobada',
            p_dueno, now(), v_lineas, v_edgar, m.asiento_id, jsonb_build_object('desc_norm', fn_contador_sin_datos_norm(m.desc_norm, m.descripcion, m.memo)))
    returning id into v_pid;
  end if;
  if coalesce(p_recordar, true) then
    v_regla := fn_contador_regla_aprender(m.id, v_lineas, p_dueno);
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'movimiento', m.id, 'asiento_id', m.asiento_id, 'asiento', (select a.numero from asientos a where a.id = m.asiento_id),
    'propuesta', v_pid, 'estado', v_estado, 'fuente', coalesce(pr.fuente, 'edgar'), 'lineas', v_lineas, 'motivo', v_motivo,
    'regla', v_regla, 'c6', v_res));
end $$;
revoke execute on function public.fn_contador_clasificar(uuid, uuid, jsonb, text, boolean, uuid) from public, anon, authenticated, service_role;
comment on function public.fn_contador_clasificar(uuid, uuid, jsonb, text, boolean, uuid) is 'c8: EL ÚNICO CAMINO AL LIBRO: fn_banco_clasificar (c6) en nombre del dueño con las líneas de Edgar; la propuesta pendiente queda aprobada o editada (o se inserta una de Edgar), y si se pide, se aprende la regla del comercio.';

-- «ASÍ ES»: aprobar la propuesta con sus propias líneas. Si pide obra, hay
-- que decirla (p_proyecto_id va a las líneas que la piden y no la traen);
-- sin ella, MX008 «elige la obra».
create or replace function public.fn_contador_aprobar(p_propuesta uuid, p_dueno uuid, p_proyecto_id text default null,
                                                      p_recordar boolean default true)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  pr       contador_propuestas;
  v_lineas jsonb;
  v_pide   boolean;
  v_obra   text := nullif(btrim(coalesce(p_proyecto_id, '')), '');
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  select * into pr from contador_propuestas where id = p_propuesta;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa propuesta.';
  end if;
  if pr.estado <> 'pendiente' then
    raise exception using errcode = 'MX008', message = format('Esa propuesta ya está %s: no se aprueba dos veces.', pr.estado);
  end if;
  v_lineas := pr.propuesta->'lineas';
  select coalesce(bool_or(k.regla_obra = 'obligatoria' and nullif(x->>'proyecto_id', '') is null), false) into v_pide
    from jsonb_array_elements(v_lineas) x join cuentas k on k.codigo = x->>'cuenta';
  if v_pide and v_obra is null then
    raise exception using errcode = 'MX008', hint = 'elige la obra',
      message = format('Elige la obra: la propuesta va a %s, que pide obra. Elígela en el selector y vuelve a aprobar.',
                       (select string_agg(k.codigo || ' (' || k.nombre || ')', ', ')
                          from jsonb_array_elements(v_lineas) x join cuentas k on k.codigo = x->>'cuenta'
                         where k.regla_obra = 'obligatoria' and nullif(x->>'proyecto_id', '') is null));
  end if;
  if v_obra is not null then
    if not exists (select 1 from proyectos p where p.id = v_obra) then
      raise exception using errcode = '22023', message = format('La obra «%s» no existe.', v_obra);
    end if;
    -- (solo a las líneas que la PIDEN y no la traen: una cuenta con obra
    -- opcional que la IA dejó sin obra se queda así; si Edgar la quiere con
    -- obra, lo dice en «Según yo»)
    select jsonb_agg(case when nullif(x->>'proyecto_id', '') is null and k.regla_obra = 'obligatoria'
                          then x || jsonb_build_object('proyecto_id', v_obra) else x end order by o)
      into v_lineas
      from jsonb_array_elements(v_lineas) with ordinality as a(x, o)
      join cuentas k on k.codigo = x->>'cuenta';
  end if;
  return fn_contador_clasificar(pr.movimiento_id, p_dueno, v_lineas, null, p_recordar, pr.id);
end $$;
revoke execute on function public.fn_contador_aprobar(uuid, uuid, text, boolean) from public, anon, authenticated, service_role;
comment on function public.fn_contador_aprobar(uuid, uuid, text, boolean) is 'c8: «Así es»: aprueba una propuesta pendiente con sus líneas (con la obra que Edgar elige si la pide); va por fn_contador_clasificar.';

-- «NO ES ESO»: la propuesta pendiente queda rechazada, con el motivo de
-- Edgar (o uno de fábrica). Una regla rechazada no se vuelve a proponer
-- para ese movimiento; el movimiento sigue en la bandeja.
create or replace function public.fn_contador_rechazar(p_propuesta uuid, p_dueno uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  pr contador_propuestas;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  select * into pr from contador_propuestas where id = p_propuesta for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa propuesta.';
  end if;
  if pr.estado <> 'pendiente' then
    raise exception using errcode = 'MX008', message = format('Esa propuesta ya está %s.', pr.estado);
  end if;
  update contador_propuestas
     set estado = 'rechazada', aprobado_por = p_dueno, aprobado_el = now(),
         motivo_edgar = coalesce(nullif(btrim(p_motivo), ''), 'No es eso (Edgar, desde la bandeja)')
   where id = pr.id
  returning * into pr;
  return jsonb_build_object('propuesta', pr.id, 'movimiento', pr.movimiento_id, 'estado', pr.estado, 'fuente', pr.fuente,
                            'motivo_edgar', pr.motivo_edgar);
end $$;
revoke execute on function public.fn_contador_rechazar(uuid, uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_rechazar(uuid, uuid, text) is 'c8: «No es eso»: una propuesta pendiente queda rechazada con el motivo de Edgar.';

-- UNA APROBADA CUYO ASIENTO YA NO VIVE (se des-casó en la bandeja, con su
-- reverso) la cierra Edgar con su motivo: queda «caducada» y el cuadre 60
-- vuelve a verde. Con el asiento vivo, no (MX008: si estaba mal, se
-- des-casa en la bandeja).
create or replace function public.fn_contador_caducar(p_propuesta uuid, p_dueno uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  pr contador_propuestas;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Cerrar una propuesta aprobada dice por qué (motivo): queda escrito.';
  end if;
  select * into pr from contador_propuestas where id = p_propuesta for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa propuesta.';
  end if;
  if pr.estado = 'pendiente' then
    raise exception using errcode = 'MX008', message = 'Esa propuesta está pendiente: se rechaza (fn_contador_rechazar), no se caduca.';
  end if;
  if pr.estado not in ('aprobada', 'editada') then
    raise exception using errcode = 'MX008', message = format('Esa propuesta ya está %s.', pr.estado);
  end if;
  if pr.asiento_id is not null
     and not exists (select 1 from asientos r where r.reversa_a = pr.asiento_id and r.camino in ('reverso', 'reverso_automatico')) then
    raise exception using errcode = 'MX008',
      message = 'Su asiento sigue vivo en el libro: si la clasificación estaba mal, des-cásala en la bandeja (fn_banco_descasar, con su '
                'motivo) y entonces ciérrala.';
  end if;
  update contador_propuestas
     set estado = 'caducada', nota = format('%s, Edgar: %s', fn_fecha_miami(now()), btrim(p_motivo))
   where id = pr.id
  returning * into pr;
  return jsonb_build_object('propuesta', pr.id, 'movimiento', pr.movimiento_id, 'estado', pr.estado, 'nota', pr.nota);
end $$;
revoke execute on function public.fn_contador_caducar(uuid, uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_caducar(uuid, uuid, text) is 'c8: Edgar cierra (caducada, con su motivo) una propuesta aprobada cuyo asiento se reversó; con el asiento vivo, MX008.';


-- ---------------------------------------------------------------------
-- 8. Las reglas que dicta Edgar
-- ---------------------------------------------------------------------
-- Alta: el nombre en llano, el patrón (una expresión regular válida que
-- no case con todo), las líneas ([{"cuenta","proyecto_id"?,"parte"?}]: con
-- varias, las partes suman 1) y, si vale solo en una cuenta del banco o
-- una tarjeta, cuál. Devuelve la regla y con cuántos movimientos que
-- esperan casa ahora mismo.
create or replace function public.fn_contador_regla_alta(p_dueno uuid, p_nombre text, p_patron text, p_lineas jsonb,
                                                         p_cuenta_banco text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_mal    text;
  v_cb     text := nullif(btrim(coalesce(p_cuenta_banco, '')), '');
  v_n      int;
  v_l      jsonb;
  v_i      int := 0;
  v_sobra  text;
  c        cuentas;
  v_obra   text;
  v_parte  numeric;
  v_suma   numeric := 0;
  v_lineas jsonb := '[]'::jsonb;
  v_pide   boolean := false;
  r        contador_reglas;
  v_casan  int;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  if length(btrim(coalesce(p_nombre, ''))) not between 2 and 80 then
    raise exception using errcode = '22023', message = 'La regla lleva un nombre en llano (el comercio), de 2 a 80 letras.';
  end if;
  v_mal := fn_contador_regex_valida(p_patron);
  if v_mal is not null then
    raise exception using errcode = '22023', message = format('El patrón: %s.', v_mal);
  end if;
  if v_cb is not null then
    select * into c from cuentas where codigo = v_cb;
    if not found or not ((c.tipo = 'activo' and left(c.codigo, 2) = '10') or (c.tipo = 'pasivo' and c.codigo like '2100-%')) then
      raise exception using errcode = 'MX004',
        message = format('«%s» no es una cuenta del banco ni una tarjeta de la empresa (1010, 1030, 2100-2013…): la regla vale en una de '
                         'esas, o en todas (sin cuenta).', v_cb);
    end if;
  end if;
  if p_lineas is null or jsonb_typeof(p_lineas) <> 'array' or jsonb_array_length(p_lineas) not between 1 and 5 then
    raise exception using errcode = '22023', message = 'Las líneas de la regla van como una lista ([{"cuenta", "proyecto_id"?, "parte"?}]), de 1 a 5.';
  end if;
  v_n := jsonb_array_length(p_lineas);
  for v_l in select value from jsonb_array_elements(p_lineas) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_l) <> 'object' then
      raise exception using errcode = '22023', message = format('Línea %s: va como objeto JSON.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_l) k where k not in ('cuenta', 'proyecto_id', 'parte');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Línea %s: clave desconocida: %s (solo cuenta, proyecto_id y parte).', v_i, v_sobra);
    end if;
    v_mal := fn_contador_cuenta_permitida(v_l->>'cuenta');
    if v_mal is not null then
      raise exception using errcode = 'MX004', message = format('Línea %s: %s.', v_i, v_mal);
    end if;
    select * into c from cuentas where codigo = btrim(v_l->>'cuenta');
    v_obra := nullif(btrim(coalesce(v_l->>'proyecto_id', '')), '');
    if v_obra is not null then
      if not exists (select 1 from proyectos p where p.id = v_obra) then
        raise exception using errcode = 'MX006', message = format('Línea %s: la obra «%s» no existe.', v_i, v_obra);
      end if;
      if c.regla_obra = 'prohibida' then
        raise exception using errcode = 'MX006', message = format('Línea %s: la cuenta %s (%s) no lleva obra.', v_i, c.codigo, c.nombre);
      end if;
    elsif c.regla_obra = 'obligatoria' then
      v_pide := true;
    end if;
    v_parte := null;
    if v_n > 1 then
      -- (coalesce: sin «parte», jsonb_typeof da nulo y «not in» no decidía:
      -- la regla entraba con partes nulas)
      if coalesce(jsonb_typeof(v_l->'parte'), 'null') not in ('number', 'string')
         or (v_l #>> '{parte}') !~ '^0*(\.[0-9]{1,4})?$|^1(\.0{1,4})?$' or (v_l #>> '{parte}')::numeric <= 0 then
        raise exception using errcode = '22023',
          message = format('Línea %s: con varias líneas cada una dice su parte (la fracción del monto, entre 0 y 1, hasta 4 decimales).', v_i);
      end if;
      v_parte := round((v_l #>> '{parte}')::numeric, 4);
      v_suma := v_suma + v_parte;
    end if;
    v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', c.codigo, 'proyecto_id', v_obra, 'parte', v_parte)));
  end loop;
  if v_n > 1 and abs(v_suma - 1) > 0.0001 then
    raise exception using errcode = 'MX001', message = format('Las partes suman %s: tienen que sumar 1.', v_suma);
  end if;
  begin
    insert into contador_reglas (nombre, patron, cuenta_banco, lineas, pide_obra, origen, creada_por, notas)
    values (btrim(p_nombre), btrim(p_patron), v_cb, v_lineas, v_pide, 'edgar', p_dueno, format('la dictó Edgar el %s', fn_fecha_miami(now())))
    returning * into r;
  exception when unique_violation then
    raise exception using errcode = 'MX008',
      message = format('Ya hay una regla activa con el patrón «%s»%s: dala de baja antes (fn_contador_regla_baja) o cambia el patrón.',
                       btrim(p_patron), coalesce(' para ' || v_cb, ''));
  end;
  -- (el alias no es «c»: así se llama la variable cuentas de arriba, y
  -- plpgsql la prefiere sobre el alias —«record c has no field desc_norm»—)
  select count(*) into v_casan from fn_contador_candidatos() k
   where k.desc_norm ~* r.patron and (r.cuenta_banco is null or r.cuenta_banco = k.cuenta);
  return to_jsonb(r) || jsonb_build_object('casan_ahora', v_casan);
end $$;
revoke execute on function public.fn_contador_regla_alta(uuid, text, text, jsonb, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_regla_alta(uuid, text, text, jsonb, text) is 'c8: Edgar dicta una regla (nombre, patrón válido, líneas a cuentas permitidas con sus partes, y en qué cuenta del banco vale); dice con cuántos movimientos que esperan casa ahora.';

-- Baja: con su motivo (queda en las notas); sus propuestas pendientes
-- caducan. No se borra nada.
create or replace function public.fn_contador_regla_baja(p_regla uuid, p_dueno uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r   contador_reglas;
  v_n int;
begin
  perform fn_contador_exigir();
  perform fn_contador_dueno_fijar(p_dueno);
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Quitar una regla dice por qué (motivo): queda escrito con ella.';
  end if;
  select * into r from contador_reglas where id = p_regla for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa regla.';
  end if;
  if not r.activa then
    raise exception using errcode = 'MX008', message = format('La regla «%s» ya está dada de baja.', r.nombre);
  end if;
  update contador_reglas
     set activa = false,
         notas = left(concat_ws(E'\n', notas, format('baja el %s: %s', fn_fecha_miami(now()), btrim(p_motivo))), 4000)
   where id = r.id
  returning * into r;
  update contador_propuestas
     set estado = 'caducada', nota = format('%s: la regla «%s» se dio de baja (%s)', fn_fecha_miami(now()), r.nombre, btrim(p_motivo))
   where regla_id = r.id and estado = 'pendiente';
  get diagnostics v_n = row_count;
  return to_jsonb(r) || jsonb_build_object('propuestas_caducadas', v_n);
end $$;
revoke execute on function public.fn_contador_regla_baja(uuid, uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_contador_regla_baja(uuid, uuid, text) is 'c8: Edgar da de baja una regla con su motivo; sus propuestas pendientes caducan. Nada se borra.';


-- ---------------------------------------------------------------------
-- 9. Las vistas de la pantalla (solo leen TABLAS —y asistente_costo_mes,
--    la de la app—; security_invoker: cada una con los permisos de quien
--    la lee, y el dueño ve todo). v_contador_cuentas va arriba (3).
-- ---------------------------------------------------------------------
-- Las reglas, con sus cuentas resueltas y cuántas propuestas pendientes
-- tienen.
create view public.v_contador_reglas with (security_invoker = true) as
select r.id, r.nombre, r.patron, r.cuenta_banco, cb.nombre as cuenta_banco_nombre, r.lineas,
       (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('cuenta', x.l->>'cuenta', 'cuenta_nombre', c.nombre,
                                                              'proyecto_id', x.l->>'proyecto_id', 'obra', pr.nombre,
                                                              'parte', (x.l->>'parte')::numeric))
                         order by x.o)
          from jsonb_array_elements(r.lineas) with ordinality as x(l, o)
          left join public.cuentas c on c.codigo = x.l->>'cuenta'
          left join public.proyectos pr on pr.id = x.l->>'proyecto_id') as lineas_detalle,
       (select string_agg((x.l->>'cuenta') || ' ' || coalesce(c.nombre, '?')
                          || coalesce(' (' || round((x.l->>'parte')::numeric * 100) || ' %)', ''), ' + ' order by x.o)
          from jsonb_array_elements(r.lineas) with ordinality as x(l, o)
          left join public.cuentas c on c.codigo = x.l->>'cuenta') as cuentas_texto,
       r.pide_obra, r.activa, r.origen, r.creada_por, p.nombre as creada_por_nombre, r.creada_el, r.veces, r.ultima_vez, r.notas,
       (select count(*) from public.contador_propuestas q where q.regla_id = r.id and q.estado = 'pendiente') as pendientes,
       (select count(*) from public.contador_propuestas q where q.regla_id = r.id and q.estado in ('aprobada', 'editada')) as aprobadas
  from public.contador_reglas r
  left join public.cuentas cb on cb.codigo = r.cuenta_banco
  left join public.perfiles p on p.id = r.creada_por
 order by r.activa desc, r.nombre, r.creada_el;
comment on view public.v_contador_reglas is 'c8: las reglas del contador (activas primero), con sus cuentas y obras resueltas, cuántas veces casaron y cuántas propuestas pendientes dejaron.';

-- La bandeja de la IA: por movimiento, su propuesta viva (la pendiente) o
-- la última, con las líneas resueltas (cuenta, obra, monto), el motivo, la
-- confianza, los flags, de dónde salió y, si ya entró, su asiento. Los
-- movimientos pendientes siempre; los demás, 120 días.
create view public.v_contador_bandeja with (security_invoker = true) as
with p as (select q.*, row_number() over (partition by q.movimiento_id order by (q.estado = 'pendiente') desc, q.creado_el desc) as rn
             from public.contador_propuestas q)
select p.movimiento_id, m.cuenta, m.fecha, m.monto, m.descripcion, m.estado as movimiento_estado,
       p.id as propuesta_id, p.fuente, p.estado, p.accion,
       (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                 'cuenta', x.l->>'cuenta', 'cuenta_nombre', c.nombre, 'tipo', c.tipo, 'monto', (x.l->>'monto')::numeric,
                 'proyecto_id', x.l->>'proyecto_id', 'obra', pr.nombre,
                 'pide_obra', (c.regla_obra = 'obligatoria' and nullif(x.l->>'proyecto_id', '') is null)))
               order by x.o)
          from jsonb_array_elements(p.propuesta->'lineas') with ordinality as x(l, o)
          left join public.cuentas c on c.codigo = x.l->>'cuenta'
          left join public.proyectos pr on pr.id = x.l->>'proyecto_id') as lineas,
       (select string_agg((x.l->>'cuenta') || ' ' || coalesce(c.nombre, '?'), ' + ' order by x.o)
          from jsonb_array_elements(p.propuesta->'lineas') with ordinality as x(l, o)
          left join public.cuentas c on c.codigo = x.l->>'cuenta') as resumen,
       p.propuesta->>'motivo' as motivo,
       (p.propuesta->>'confianza')::numeric as confianza,
       coalesce(p.propuesta->'flags', '{}'::jsonb) as flags,
       coalesce((p.propuesta->'flags'->>'pide_obra')::boolean, false) as pide_obra,
       p.propuesta->'alternativas' as alternativas,
       p.modelo, p.effort, p.prompt_version, p.regla_id, r.nombre as regla_nombre, p.lote_id,
       p.creado_el, p.aprobado_por, p.aprobado_el, p.lineas_finales, p.motivo_edgar, p.nota,
       p.asiento_id, a.numero as asiento,
       (p.estado in ('aprobada', 'editada') and p.asiento_id is not null
        and not exists (select 1 from public.asientos rv where rv.reversa_a = p.asiento_id and rv.camino in ('reverso', 'reverso_automatico')))
         as asiento_vivo,
       (now() at time zone 'America/New_York')::date - (p.creado_el at time zone 'America/New_York')::date as dias
  from p
  join public.movimientos_banco m on m.id = p.movimiento_id
  left join public.contador_reglas r on r.id = p.regla_id
  left join public.asientos a on a.id = p.asiento_id
 where p.rn = 1
   and (m.estado = 'pendiente' or p.creado_el > now() - interval '120 days');
comment on view public.v_contador_bandeja is 'c8: por movimiento, su propuesta viva (la pendiente) o la última: líneas resueltas, motivo, confianza, flags, fuente (regla, IA o Edgar), estado y, si entró, su asiento.';

-- EL CONTROL del contador (orden, control, nivel, ok, filas, esperadas,
-- detalle). Un «cuadre» en rojo: la pantalla no pinta la franja. Una
-- «alarma» en rojo: «Qué atender» en el Resumen.
create view public.v_contador_control with (security_invoker = true) as
with cfg as (select * from public.contador_config where id = 1),
     hoy as (select (now() at time zone 'America/New_York')::date as d,
                    to_char((now() at time zone 'America/New_York')::date, 'YYYY-MM') as mes),
     aj as (select coalesce((select case when a.valor ~ '^[0-9]{1,9}$' then a.valor::int end
                               from public.asistente_ajustes a where a.clave = 'tope_mes_centavos'), 10000) as tope_global),
     gasto as (select coalesce(sum(x.centavos), 0)::bigint as total,
                      coalesce(sum(x.centavos) filter (where x.accion like 'contador\_%'), 0)::bigint as contador
                 from public.asistente_costo_mes x cross join hoy
                where x.mes = hoy.mes),
     -- lo que espera sin propuesta (la misma regla que fn_contador_candidatos, escrita sobre las tablas)
     cand as (select count(*) as n, min(m.fecha) as desde
                from public.movimientos_banco m
               where m.estado = 'pendiente'
                 and not (m.posible_duplicado_de is not null and m.duplicado is null)
                 and m.propuesta->>'motivo' in ('sin_ticket', 'dudosa')
                 and not exists (select 1 from public.contador_propuestas p where p.movimiento_id = m.id and p.estado = 'pendiente')),
     vivo as (select a.id from public.asientos a
               where not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))),
     -- las ráfagas que se quedaron abiertas más de cinco minutos: la función se cortó sin cerrarlas (fn_contador_lote_abrir las da
     -- por perdidas al abrir la siguiente)
     abierta as (select count(*) as n, min(l.creado_el) as desde
                   from public.contador_lotes l
                  where l.cerrado_el is null and l.creado_el < now() - interval '5 minutes')
select z.orden, z.control, z.nivel, z.ok, z.filas, z.esperadas, z.detalle
  from cfg
 cross join hoy
 cross join aj
 cross join gasto
 cross join cand
 cross join abierta
 cross join lateral (
   select 10 as orden, 'vista: v_contador_bandeja'::text as control, 'cuadre'::text as nivel, true as ok,
          (select count(*) from public.v_contador_bandeja) as filas, (select count(*) from public.v_contador_bandeja) as esperadas,
          null::text as detalle
   union all
   select 11, 'vista: v_contador_reglas', 'cuadre', true, (select count(*) from public.v_contador_reglas),
          (select count(*) from public.v_contador_reglas), null
   union all
   select 12, 'ia: hay cuentas que proponer', 'cuadre', t.n > 0, t.n, 1,
          case when t.n = 0 then 'v_contador_cuentas no trae ninguna cuenta: ¿está c1-plan-de-cuentas.sql pegado?' end
     from (select count(*) as n from public.v_contador_cuentas) t
   union all
   -- 60: lo aprobado está en el libro (su asiento de c6 existe y nadie lo reversó)
   select 60, 'ia: cada propuesta aprobada o editada tiene su asiento vivo', 'cuadre', t.n = 0, t.n, 0,
          case when t.n > 0 then t.d || ' → ciérrala con fn_contador_caducar (con su motivo) o vuelve a clasificar el movimiento' end
     from (select count(*) as n,
                  left(string_agg(format('#%s (%s %s «%s»): %s', p.id, m.fecha, m.monto, coalesce(m.descripcion, ''),
                                         case when p.asiento_id is null then 'sin asiento'
                                              when a.id is null then 'su asiento no existe'
                                              else 'su asiento ' || a.numero || ' está reversado' end), '; '), 1500) as d
             from public.contador_propuestas p
             join public.movimientos_banco m on m.id = p.movimiento_id
             left join public.asientos a on a.id = p.asiento_id
            where p.estado in ('aprobada', 'editada') and (a.id is null or a.id not in (select v.id from vivo v))) t
   union all
   -- 61: ningún asiento VIVO dice «Propuesta de la IA #…» sin que esa propuesta exista, aprobada y con ese asiento (uno
   --     reversado ya no cuenta: su propuesta queda caducada, y eso lo vigila el 60)
   select 61, 'ia: ningún asiento con «Propuesta de la IA #» en su motivo sin su propuesta aprobada', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(a.numero || ' (' || left(a.descripcion, 90) || ')', '; '), 1500) as d
             from public.asientos a
            where a.camino not in ('reverso', 'reverso_automatico')
              and a.id in (select v.id from vivo v)
              and (a.descripcion ~ 'Propuesta de la IA #[0-9a-f-]{36}' or coalesce(a.procedencia->>'motivo_edgar', '') ~ 'Propuesta de la IA #[0-9a-f-]{36}')
              and not exists (select 1 from public.contador_propuestas p
                               where p.asiento_id = a.id and p.estado in ('aprobada', 'editada')
                                 and p.id::text = substring(coalesce(a.procedencia->>'motivo_edgar', a.descripcion)
                                                            from 'Propuesta de la IA #([0-9a-f-]{36})'))) t
   union all
   -- 62: cada línea de cada regla activa va a una cuenta que hoy se puede proponer
   select 62, 'ia: las reglas activas van a cuentas activas e imputables', 'cuadre', t.n = 0, t.n, 0,
          case when t.n > 0 then t.d || ' → da de baja la regla (fn_contador_regla_baja) y dicta otra' end
     from (select count(*) as n, left(string_agg(r.nombre || ' → ' || (x.l->>'cuenta'), '; '), 1500) as d
             from public.contador_reglas r
            cross join lateral jsonb_array_elements(r.lineas) x(l)
            where r.activa and not exists (select 1 from public.v_contador_cuentas v where v.codigo = x.l->>'cuenta')) t
   union all
   -- 63: las protecciones de la fase 7 (como el cuadre 34 de p1)
   select 63, 'ia: protecciones de la fase 7', 'cuadre', t.n = 0, t.n, 0, t.d
     from (select count(*) as n, left(string_agg(y.que, '; '), 1500) as d
             from (select p.oid::regprocedure::text || ' es SECURITY DEFINER' as que
                     from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_contador\_%' and p.prosecdef
                   union all
                   select p.oid::regprocedure::text || ' la puede ejecutar ' || r.r
                     from pg_proc p cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
                    where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_contador\_%'
                      and has_function_privilege(r.r, p.oid, 'execute')
                   union all
                   select c.relname || ' sin RLS'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                      and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas') and not c.relrowsecurity
                   union all
                   select c.relname || ' no tiene una sola policy «' || c.relname || '_dueno»'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                      and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')
                      and ((select count(*) from pg_policy pl where pl.polrelid = c.oid) <> 1
                           or not exists (select 1 from pg_policy pl where pl.polrelid = c.oid and pl.polname = c.relname || '_dueno'
                                             and pl.polcmd = 'r' and pl.polpermissive))
                   union all
                   select format('%s puede %s en %s', r.r, q.q, c.relname)
                     from pg_class c
                    cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
                    cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
                    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                      and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')
                      and has_table_privilege(r.r, c.oid, q.q)
                   union all
                   select format('%s puede leer %s', r.r, c.relname)
                     from pg_class c cross join (values ('anon'), ('service_role')) r(r)
                    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
                      and (c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas') or c.relname like 'v\_contador\_%')
                      and has_table_privilege(r.r, c.oid, 'SELECT')
                   union all
                   select c.relname || ' sin security_invoker'
                     from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname like 'v\_contador\_%'
                      and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                         where o.option_name = 'security_invoker'), false)
                   union all
                   select 'un trigger en ' || c.relname || ': ' || t.tgname
                     from pg_trigger t join pg_class c on c.oid = t.tgrelid
                    where not t.tgisinternal and c.relnamespace = 'public'::regnamespace
                      and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')) y) t
   union all
   -- 70: el gasto del mes, bajo los dos topes
   select 70, 'ia: el gasto del mes bajo el tope', 'alarma',
          not (gasto.total >= aj.tope_global or gasto.contador >= cfg.tope_mes_centavos), null, null,
          format('%s: la IA lleva $%s en total (el tope de la app es $%s) y el contador $%s (su tope, $%s)', hoy.mes,
                 to_char(gasto.total / 100.0, 'FM999,999,990.00'), to_char(aj.tope_global / 100.0, 'FM999,999,990.00'),
                 to_char(gasto.contador / 100.0, 'FM999,999,990.00'), to_char(cfg.tope_mes_centavos / 100.0, 'FM999,999,990.00'))
   union all
   select 71, 'ia: ninguna propuesta pendiente de más de 7 días', 'alarma', t.n = 0, t.n, 0, t.d
     from (select count(*) as n,
                  left(string_agg(format('%s %s «%s» (desde el %s)', m.fecha, m.monto, coalesce(m.descripcion, ''),
                                         (p.creado_el at time zone 'America/New_York')::date), '; '), 1500) as d
             from public.contador_propuestas p
             join public.movimientos_banco m on m.id = p.movimiento_id
            where p.estado = 'pendiente' and p.creado_el < now() - interval '7 days') t
   union all
   -- 72: la última ráfaga cerró sin error, y ninguna lleva más de cinco minutos abierta (esa es una función que se cortó: su gasto
   --     no está anotado)
   select 72, 'ia: la última ráfaga sin error', 'alarma',
          (cfg.ultimo_error is null or (cfg.ultima_rafaga_el is not null and cfg.ultima_rafaga_el > cfg.ultimo_error_el)) and abierta.n = 0,
          null, null,
          case when abierta.n > 0
               then format('%s ráfaga(s) abierta(s) desde las %s (hora de Miami) sin cerrar: la función se cortó antes de terminar y su gasto no '
                           'está anotado; la base la da por perdida al abrir la siguiente («Proponer con la IA»)',
                           abierta.n, to_char(abierta.desde at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI'))
               when cfg.ultimo_error is not null
               then format('el %s: %s', to_char(cfg.ultimo_error_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI'), cfg.ultimo_error)
               when cfg.ultima_rafaga_el is null then 'ninguna ráfaga ha corrido todavía'
               else 'la última fue el ' || to_char(cfg.ultima_rafaga_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI') || ' (hora de Miami)' end
   union all
   -- 73: hay cargos esperando desde hace más de dos días y ninguna ráfaga ha corrido nunca
   select 73, 'ia: la llave y la función', 'alarma',
          not (cfg.activa and cfg.ultima_rafaga_el is null and cand.n > 0 and cand.desde < hoy.d - 2), null, null,
          case when cfg.activa and cfg.ultima_rafaga_el is null and cand.n > 0 and cand.desde < hoy.d - 2
               then format('ninguna ráfaga ha corrido nunca y hay %s cargo(s) sin propuesta desde el %s: ¿está ANTHROPIC_API_KEY en los '
                           'secretos de Edge Functions y la función «contador» desplegada? Toca «Proponer con la IA» en la Bandeja',
                           cand.n, cand.desde)
               when not cfg.activa then 'el contador está apagado (contador_config.activa = false)'
               else format('%s cargo(s) esperan propuesta', cand.n) end
 ) z;
comment on view public.v_contador_control is 'c8: el control del contador: cuadres (si uno sale en rojo, la pantalla no pinta la franja de la IA) y alarmas (el gasto, lo pendiente de más de 7 días, la última ráfaga, la llave y la función).';

-- El estado del contador, en una fila (la franja de la Bandeja y la
-- tarjeta de Conexiones).
create view public.v_contador_estado with (security_invoker = true) as
with hoy as (select to_char((now() at time zone 'America/New_York')::date, 'YYYY-MM') as mes),
     aj as (select coalesce((select case when a.valor ~ '^[0-9]{1,9}$' then a.valor::int end
                               from public.asistente_ajustes a where a.clave = 'tope_mes_centavos'), 10000) as tope_global,
                   coalesce((select case when a.valor ~ '^[0-9]{1,3}$' then a.valor::int end
                               from public.asistente_ajustes a where a.clave = 'aviso_pct'), 80) as aviso_pct),
     gasto as (select coalesce(sum(x.centavos), 0)::bigint as total,
                      coalesce(sum(x.centavos) filter (where x.accion like 'contador\_%'), 0)::bigint as contador
                 from public.asistente_costo_mes x cross join hoy
                where x.mes = hoy.mes),
     cand as (select count(*) as n, min(m.fecha) as desde
                from public.movimientos_banco m
               where m.estado = 'pendiente'
                 and not (m.posible_duplicado_de is not null and m.duplicado is null)
                 and m.propuesta->>'motivo' in ('sin_ticket', 'dudosa')
                 and not exists (select 1 from public.contador_propuestas p where p.movimiento_id = m.id and p.estado = 'pendiente')),
     ctl as (select count(*) filter (where c.nivel = 'cuadre' and not c.ok) as rojos,
                    count(*) filter (where c.nivel = 'alarma' and not c.ok) as alarmas
               from public.v_contador_control c)
select true as instalado, c.modelo, c.effort, c.activa, c.max_por_rafaga, c.tope_mes_centavos, c.dueno,
       (select p.nombre from public.perfiles p where p.id = c.dueno) as dueno_nombre,
       c.prompt_version, c.prefijo_hash, c.ultima_rafaga_el, c.ultimo_error, c.ultimo_error_el, c.actualizado,
       cand.n as pendientes_sin_propuesta, cand.desde as pendientes_desde,
       (select count(*) from public.contador_propuestas p where p.estado = 'pendiente') as propuestas_pendientes,
       (select count(*) from public.contador_propuestas p where p.estado = 'pendiente' and p.fuente = 'regla') as propuestas_por_regla,
       (select count(*) from public.contador_propuestas p where p.estado = 'pendiente' and p.fuente = 'ia') as propuestas_por_ia,
       (select count(*) from public.contador_reglas r where r.activa) as reglas_activas,
       hoy.mes, gasto.total as centavos_mes_total, aj.tope_global, gasto.contador as centavos_mes_contador, aj.aviso_pct,
       (not c.activa or gasto.total >= aj.tope_global or gasto.contador >= c.tope_mes_centavos) as bloqueado,
       case when not c.activa then 'apagado'
            when gasto.total >= aj.tope_global then 'tope de la app'
            when gasto.contador >= c.tope_mes_centavos then 'tope del contador' end as bloqueado_motivo,
       (gasto.total * 100 >= aj.tope_global * aj.aviso_pct or gasto.contador * 100 >= c.tope_mes_centavos * aj.aviso_pct) as aviso,
       (select count(*) from public.contador_lotes l where l.cerrado_el is null) as lotes_abiertos,
       (select max(l.creado_el) from public.contador_lotes l) as ultimo_lote_el,
       (select l.centavos from public.contador_lotes l where l.cerrado_el is not null order by l.cerrado_el desc limit 1) as ultimo_lote_centavos,
       (select count(*) from public.contador_propuestas p where p.estado in ('aprobada', 'editada')) as aprobadas_total,
       (select count(*) from public.contador_propuestas p where p.estado = 'rechazada') as rechazadas_total,
       (select count(*) from public.v_contador_cuentas) as cuentas_permitidas,
       ctl.rojos as cuadres_rojos, ctl.alarmas
  from public.contador_config c
 cross join hoy
 cross join aj
 cross join gasto
 cross join cand
 cross join ctl
 where c.id = 1;
comment on view public.v_contador_estado is 'c8: el estado del contador en una fila: configuración, lo que espera, las propuestas pendientes, las reglas, el gasto del mes y sus topes, la última ráfaga y el control.';

do $$
declare
  v text;
begin
  foreach v in array array['v_contador_cuentas', 'v_contador_reglas', 'v_contador_bandeja', 'v_contador_control', 'v_contador_estado'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
    execute format('grant select on public.%I to authenticated', v);
  end loop;
  -- (asistente_costo_mes y asistente_ajustes no se tocan: la app ya los lee
  -- como authenticated, y si los creó este archivo, la sección 1 dio el
  -- grant al crearlos)
end $$;


-- ---------------------------------------------------------------------
-- 10. Lo demás que pide la función de borde, y el final del pegado
-- ---------------------------------------------------------------------
create or replace function public.fn_contador_control()
returns table (orden int, control text, nivel text, ok boolean, filas bigint, esperadas bigint, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  return query select c.orden, c.control, c.nivel, c.ok, c.filas, c.esperadas, c.detalle from v_contador_control c order by c.orden;
end $$;
revoke execute on function public.fn_contador_control() from public, anon, authenticated, service_role;
comment on function public.fn_contador_control() is 'c8: el control del contador (v_contador_control), para la función de borde y el SQL Editor.';

create or replace function public.fn_contador_resumen() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_contador_exigir();
  return jsonb_build_object(
    'config', (select to_jsonb(c) from contador_config c where c.id = 1),
    'estado', (select to_jsonb(e) from v_contador_estado e),
    'tope', fn_contador_tope(),
    'control_rojo', coalesce((select jsonb_agg(to_jsonb(x) order by x.orden) from v_contador_control x where not x.ok), '[]'::jsonb));
end $$;
revoke execute on function public.fn_contador_resumen() from public, anon, authenticated, service_role;
comment on function public.fn_contador_resumen() is 'c8: la configuración (sin secretos: no hay), el estado, el tope y lo que el control tiene en rojo.';

-- Lo que debe verse al pegar.
create or replace function public.fn_contador_pegado() returns table (que text, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c   contador_config;
  v_t jsonb;
  v_k char;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from contador_config where id = 1;
  v_t := fn_contador_tope();
  select r.relkind into v_k from pg_class r where r.oid = to_regclass('public.asistente_costo_mes');
  return query select 'contador_config'::text,
                      format('%s · effort %s · %s · hasta %s por ráfaga · tope propio %s al mes (el de la app: %s)', c.modelo, c.effort,
                             case when c.activa then 'activa' else 'APAGADA' end, c.max_por_rafaga,
                             fn_contador_usd(c.tope_mes_centavos / 100.0), fn_contador_usd((v_t->>'tope_global')::numeric / 100));
  return query select 'dueño'::text, coalesce((select p.nombre || ' · ' || p.id from perfiles p where p.id = c.dueno), c.dueno::text);
  return query select 'tablas'::text,
                      format('contador_config, contador_reglas (%s activas), contador_lotes (%s), contador_propuestas (%s pendientes, %s aprobadas o editadas)',
                             (select count(*) from contador_reglas r where r.activa), (select count(*) from contador_lotes),
                             (select count(*) from contador_propuestas p where p.estado = 'pendiente'),
                             (select count(*) from contador_propuestas p where p.estado in ('aprobada', 'editada')));
  return query select 'el gasto se anota en'::text,
                      case when v_k = 'r' then 'asistente_costo_mes (tabla)' else 'asistente_uso (asistente_costo_mes es la vista de la app)' end
                      || format(' · este mes: %s en total, %s del contador', fn_contador_usd((v_t->>'centavos_mes_total')::numeric / 100),
                                fn_contador_usd((v_t->>'centavos_mes_contador')::numeric / 100));
  return query select 'cuentas que se proponen'::text,
                      format('%s (v_contador_cuentas): %s', (select count(*) from v_contador_cuentas),
                             (select string_agg(v.codigo, ' ' order by v.codigo) from v_contador_cuentas v));
  return query select 'esperan propuesta'::text,
                      format('%s movimiento(s) «sin ticket» de la bandeja sin propuesta pendiente', (select count(*) from fn_contador_candidatos()));
  return query select 'última ráfaga'::text,
                      coalesce(to_char(c.ultima_rafaga_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI') || ' (hora de Miami)', 'ninguna todavía')
                      || coalesce(' · último error: ' || c.ultimo_error, '');
  return query select 'control'::text,
                      format('%s cuadres rojos · %s alarmas',
                             (select count(*) from v_contador_control x where x.nivel = 'cuadre' and not x.ok),
                             (select count(*) from v_contador_control x where x.nivel = 'alarma' and not x.ok))
                      || case when c.ultima_rafaga_el is null and exists (select 1 from v_contador_control x where x.orden = 73 and not x.ok)
                              then ' · la 73 («la llave y la función») es la esperada hasta la primera ráfaga: se apaga sola al tocar «Proponer con la IA»'
                              else '' end;
  return query select 'siguiente paso'::text,
                      'pega docs/conta/c8-pruebas.sql; pon ANTHROPIC_API_KEY (una llave nueva, solo para el contador) en Supabase → Edge '
                      'Functions → Secrets; despliega la función «contador» (Verify JWT apagado) y mira …/contador?paso=salud; después, en '
                      'la Bandeja, «Proponer con la IA».'::text;
end $$;
revoke execute on function public.fn_contador_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_contador_pegado() is 'c8: lo que enseña el final del pegado: la configuración, el dueño, las tablas, dónde se anota el gasto, las cuentas, lo que espera, la última ráfaga, el control y el paso siguiente.';

select * from public.fn_contador_pegado();
