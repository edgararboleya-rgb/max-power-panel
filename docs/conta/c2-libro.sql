-- =====================================================================
-- C2 · El libro — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, de una vez, DESPUÉS de
-- c1-plan-de-cuentas.sql. Idempotente: se puede pegar dos veces seguidas
-- sin error y sin duplicar nada. Después se pega c2-pruebas.sql.
--
-- Son los invariantes de los libros. Si esto queda bien, ningún libro se
-- corrompe después; si queda mal, no hay pantalla que lo salve.
--
-- DOS BLOQUES, separados por la línea «-- ==== BLOQUE B ====»:
--   A · Las tablas y unas funciones MÍNIMAS, sin controles de contenido.
--       Existen para probar en rojo: con solo el bloque A, c2-pruebas.sql
--       tiene que fallar porque los ataques ENTRAN, no porque falte una
--       función. Las mínimas se crean SOLO si la función no existe: pegar
--       el archivo por segunda vez nunca baja un control, ni un instante.
--   B · Los controles: triggers, numeración, cadena de hashes, período,
--       reverso, las funciones de verdad y el verificador.
-- CAMBIO PARA c4 (f04, 25-sep-2026): la policy de lectura de las tablas
-- del libro (A.9) es «using ((select es_dueno()))» y no «using
-- (es_dueno())». Dice lo mismo (solo el dueño lee), pero Postgres
-- evalúa es_dueno() UNA vez por consulta y no una vez por fila leída: con
-- unos 10.000 asientos, las vistas de c4 bajan de 0,4-1,7 s a 0,1-0,4 s y
-- el control del Panel de 6,4 s a 2,4 s (el tope de la API es 8 s). Es la
-- forma que recomienda Supabase. Volver a pegar este archivo la cambia
-- (el bloque de A.9 rehace su policy), y el control «permisos» de
-- fn_verificar_cadena acepta las dos formas (c1 sigue con la de siempre).
-- Su prueba: la 78 de c2-pruebas.sql.
--
-- EL ROJO SE CORRE SOLO EN EL BANCO DE PRUEBAS (pruebas/conta/correr.sh
-- con «c2-libro.sql:A»). En Supabase este archivo se pega SIEMPRE entero:
-- entre un bloque A pegado solo y el bloque B, el libro no tiene guardas,
-- y lo que entre en esa ventana no se podría borrar después. Por si acaso
-- se pega solo por error, el bloque A nace cerrado (RLS y permisos, A.9)
-- y sus funciones mínimas solo dejan pasar al dueño; y el bloque B se
-- niega a ponerse encima de datos escritos sin controles (B.0, MX000).
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código ANTES
-- de que enCristiano los pise):
--   MX000  falta algo que el archivo da por hecho (precondición), o el
--          bloque B encuentra datos escritos con el bloque A solo
--   MX001  descuadre: debe ≠ haber, o menos de dos líneas
--   MX002  período: cerrado, inexistente, anterior a la apertura, a más
--          de lo permitido en el futuro, de apertura, fuera de orden, con
--          un hueco en el calendario, o un intento de reabrir o de borrar;
--          un cierre antes de que el período termine (hora de Miami), un
--          cierre fuera de read committed, la apertura sin su asiento, o
--          un año con el año anterior todavía abierto. El de un período
--          cerrado dice qué hacer: si es la apertura, el ajuste a la
--          apertura; si es de un ejercicio anterior, el ajuste de ese
--          ejercicio
--   MX003  inmutable: update, delete o truncate del libro; una línea
--          nueva en un asiento ya sellado (también si llega de otra sesión:
--          se mira otra vez al confirmar); un contador que salta o que
--          avanza sin su asiento (también se mira al confirmar); una obra
--          con asientos que se quiere borrar; una cuenta a la que se le
--          quiere cambiar una regla que dejaría su saldo atrapado (c1)
--   MX004  cuenta: no existe, está inactiva o es de grupo
--   MX005  monto: más de dos decimales, cero, no numérico o fuera de rango
--   MX006  dimensión: la obra, el cost code, el co o la fase no son los
--          que pide la cuenta (cuentas.regla_obra / regla_cost_code); o un
--          asiento de apertura, o un ajuste del CPA a la apertura, con
--          cuentas de resultados
--   MX007  reverso: ya reversado, reversar un reverso, reverso que no es
--          el espejo exacto, un reversible sin su reverso del día 1, un
--          devengo corregido en su mes cuyo reverso del día 1 sigue vivo,
--          un sustituto (sustituye_a) que no sustituye a un asiento
--          reversado de su mismo documento, el asiento de apertura con la
--          apertura ya cerrada (no se reversa: se ajusta), o el reverso o
--          el sustituto de un asiento de un ejercicio anterior que no va
--          como ajuste de ese ejercicio (salvo el sustituto de un papel
--          que ya es del año nuevo, B.8 paso 5); y, a mano, el asiento de
--          un PUENTE (fn_reversar no lo reversa y fn_postear no lo
--          sustituye: se corrige su papel y su puente pone el reverso y el
--          asiento nuevo; B.12 y B.14)
--   42501  permiso: solo el dueño postea; anon y service_role, nada
--   22023  entrada mal formada (clave desconocida, camino no válido,
--          afecta_periodo sin tipo ajuste_cpa, ajuste_cpa sin motivo…)
--   22007  fecha que no viene como texto AAAA-MM-DD
--   23505  ese documento ya tiene su asiento VIVO (la idempotencia de los
--          puentes de f03: correr un puente dos veces no duplica). Un
--          devengo reversible sigue vivo aunque ya tenga su reverso del
--          día 1: ese reverso es parte del devengo, no una corrección
--
-- QUIÉN LLAMA QUÉ (la frontera se decide aquí):
--   · El dueño, por RPC desde conta.js (grant a authenticated; cada
--     función comprueba es_dueno() por dentro). PostgREST casa el cuerpo
--     por NOMBRE de parámetro: _rpc('fn_postear', { p_asiento: {…} }).
--       fn_postear(p_asiento jsonb)               camino 'mano'
--       fn_reversar(p_asiento uuid, p_motivo text) camino 'reverso' (un
--         devengo reversible se corrige en su mes: su reverso va en su
--         misma fecha y, en la misma transacción, anula su reverso del
--         día 1). El asiento de un PUENTE no: se corrige su papel y su
--         puente lo rehace (MX007, con el camino según el papel)
--       fn_estado(p_periodo text)                 la fila de control (lee con RLS)
--       fn_verificar_cadena()                     hashes, numeración, triggers, permisos
--       fn_abrir_periodo(p_mes 'AAAA-MM'), fn_cerrar_periodo(p_periodo text)
--       fn_fecha_miami(t timestamptz)             «hoy» en Miami, calculado en SQL
--     Y lee directo (select, con la policy solo-dueño) cuentas,
--     cuentas_historial, periodos, contadores, asientos y asiento_lineas.
--   · Solo por dentro (sin grant a ningún rol de la API):
--       fn_postear_interno(asiento jsonb)  la usan los puentes de f03
--         (SECURITY DEFINER, camino 'puente', con su documento de origen).
--         En f07 la usará fn_aprobar con el camino 'ia'; hasta entonces lo
--         rechaza (f07 añade ia_propuestas y la FK de propuesta_id);
--       fn_reversar_interno(...)           la usan fn_reversar, el reverso
--         automático y los puentes (un recibo anulado se reversa).
--   · El SQL Editor (el dueño de la base) puede llamar a todas. Queda
--     escrito en cada asiento como rol_bd = 'postgres', con la conexión
--     de la que vino en la procedencia (application_name, dirección y
--     puerto del cliente).
--   · service_role (las funciones de borde, la IA) solo LEE: no ejecuta
--     ninguna función que escriba. «La IA propone, nunca postea» lo
--     garantiza la base PARA LO QUE ENTRA POR LA API. Una conexión directa
--     a Postgres (el secreto SUPABASE_DB_URL que Supabase da a toda
--     función de borde, o la contraseña de la base) ES el SQL Editor: la
--     base no la puede distinguir, y ninguna base se defiende de su dueño.
--     Por eso la regla para f07 (y para cualquier función de borde):
--     contador habla con la base SOLO por la API (supabase-js con la llave
--     de servicio), nunca con SUPABASE_DB_URL ni con un driver de
--     Postgres. Lo que entrara así llevaría en su procedencia la conexión
--     de la que vino: ayuda a notar un error honesto, no frena un abuso
--     (application_name lo pone quien se conecta).
--
-- CÓMO SE ABRE Y SE CIERRA UN PERÍODO:
--   · Aquí nacen abiertos: la apertura (2026-09-APERTURA, solo el día
--     30-sep), octubre–diciembre de 2026 (paralelo) y los doce meses de
--     2027, más un período por año (2026 y 2027). Los meses de 2028 se
--     abren con fn_abrir_periodo('2028-01'), en orden: el calendario no
--     tiene huecos (un mes se abre solo si existe el anterior) y ningún
--     período se borra.
--   · Se cierra con fn_cerrar_periodo(periodo), o con un update del
--     estado desde el SQL Editor: el trigger de periodos valida igual por
--     los dos caminos. Un período se cierra cuando YA TERMINÓ: a partir
--     del día siguiente a su último día, en hora de Miami (octubre, desde
--     el 1-nov; el año, desde el 1-ene siguiente). Como un cierre no se
--     deshace, cerrar antes de tiempo dejaría sin sitio lo que después se
--     fechara en ese mes. Todo se cierra en orden, y la APERTURA VA
--     PRIMERO: se cierra antes que octubre, y solo con su asiento de
--     apertura ya cargado y auditado (la balanza de QuickBooks al 30-sep,
--     f04): cerrada vacía, ya no habría dónde cargarla. Si quedara abierta
--     con octubre ya cerrado, un asiento fechado el 30-sep cambiaría el
--     saldo de balance de todos los meses cerrados. Lo que aparezca
--     después en la apertura se corrige en el mes abierto con un ajuste a
--     la apertura: tipo ajuste_cpa y afecta_periodo = '2026-09-APERTURA',
--     con cuentas de balance únicamente (lo de antes del 30-sep va contra
--     3900, nunca a un gasto o un ingreso del paralelo). Cerrada, la
--     apertura ya no se reversa entera: el reverso caería en octubre, el
--     balance de apertura quedaría vacío y la balanza buena ya no entraría
--     como apertura (MX007, y el mensaje dice lo del ajuste). ▶ Esto
--     adelanta el cierre de la apertura que el calendario del plan ponía
--     en la semana del 18-ene. El año se cierra cuando todos sus meses
--     existan y estén cerrados (tras los ajustes del CPA), y con el año
--     anterior ya cerrado: el cierre del año decide qué es «ejercicio
--     cerrado» (el saldo vivo de las cuentas de resultados en c1, el
--     arrastre a 3900 de f04), y con un año anterior abierto su resultado
--     quedaría fuera del arrastre. Por eso 2026, aunque sea el paralelo, se
--     cierra también aquí, antes que 2027. Al cerrar se guarda el hash de
--     la cadena en ese momento (cadena_al_cerrar). Se cierra en una
--     transacción read committed (la de siempre, la del SQL Editor y la de
--     la app): en repeatable read o serializable la foto del cierre sería
--     la del principio de la transacción y dejaría fuera lo que entró
--     después.
--   · Un período cerrado NO se reabre (regla A de f08): los ajustes van
--     al período abierto, con tipo 'ajuste_cpa' y afecta_periodo.
--   · Un error de un mes cerrado del MISMO año se corrige con fn_reversar:
--     el reverso cae en el mes abierto y es un asiento como su original.
--     Pero si el original es de un ejercicio ANTERIOR (el paralelo de
--     2026 corregido en 2027, o 2027 corregido en 2028), su reverso no
--     puede caer en el resultado del año en curso: sería el ingreso o el
--     costo de otro año (y la base del 1120-S de ese año). fn_reversar lo
--     marca solo como ajuste de ese ejercicio (tipo ajuste_cpa,
--     afecta_periodo = el período del original), que f04 pliega a 3900 y
--     enseña en el año que corrige («con ajustes posteriores»). El
--     sustituto de ese documento, igual, SALVO que el papel mismo haya
--     cambiado de año: el ticket de diciembre que en verdad era del 4 de
--     enero ya no es de ese ejercicio, y su sustituto es un asiento normal
--     de su fecha (lo dice el puente en procedencia.fecha_documento: B.8,
--     paso 5). Como ajuste del año viejo pondría un gasto de enero en el
--     año equivocado. El reverso automático del día 1
--     de un devengo de diciembre NO: ese deshace el devengo en enero a
--     propósito, y es un asiento normal del año nuevo. f03 decidió lo
--     mismo para un documento TARDÍO de un ejercicio anterior: su puente
--     lo fecha el día 1 del mes abierto, pero como ajuste de su ejercicio
--     (tipo ajuste_cpa, afecta_periodo = el mes cerrado del documento);
--     como asiento normal caería en el resultado del año siguiente. Dentro
--     del mismo año, la regla de §5.7 del plan tal cual: asiento normal el
--     día 1 del mes abierto, con la nota en la procedencia.
--
-- LO QUE ESTE ARCHIVO NO PUEDE HACER (dicho claro, para el auditor):
--   · Ningún control que vive DENTRO de la base frena ni delata a quien
--     es dueño de la base (el SQL Editor, la contraseña de Postgres, una
--     conexión con SUPABASE_DB_URL). Puede apagar los triggers, reescribir
--     un asiento, recalcular la cadena de hashes con fn_asiento_canonico
--     y reescribir también los contadores y periodos.cadena_al_cerrar; o
--     reemplazar las propias funciones. Después, fn_verificar_cadena da
--     todo en verde: el hash no lleva secreto y sus anclas están en la
--     misma base.
--   · Lo que fn_verificar_cadena SÍ caza: a quien toca el libro sin
--     recalcular (o recalcula sin arreglar las anclas), las guardas
--     apagadas o cambiadas (sus huellas), una tabla del libro reescrita
--     por debajo de sus triggers (un ALTER TABLE … TYPE … USING no dispara
--     ninguno: se ve en la huella de la tabla), los permisos abiertos, los
--     meses cerrados fuera de orden o reabiertos y vueltos a cerrar (la
--     hora y la foto de cada cierre van en el orden del calendario, y nada
--     fechado dentro de un período cerrado entra detrás de su foto), un año
--     cerrado con el anterior abierto (o antes que él), un período cerrado
--     antes de terminar, una segunda apertura, la apertura cerrada sin su
--     asiento de apertura vivo, una cuenta que cambió sin su fila en
--     cuentas_historial, y una función SECURITY DEFINER que lee o escribe
--     el libro y que la API puede ejecutar (y la vista que la llama, aunque
--     sea security_invoker).
--   · Contra el dueño de la base, la detección real es un ANCLA FUERA de
--     ella: el hash del mayor que sale por correo en cada cierre (f08,
--     CONTA-PLAN §3.6 y §5.6) y la balanza exportada. f08 guarda ese ancla
--     desde el primer cierre, y conviene mandar también el tope corriente
--     (número, posición en la cadena y hash) del mes ABIERTO, para cazar
--     un truncamiento o una reescritura del mes en curso.
-- =====================================================================


-- =====================================================================
-- ================================ BLOQUE A ============================
-- Las tablas, y las funciones mínimas para probar en rojo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A.0 · PRECONDICIONES — solo lee. Si algo falta, no se aplica nada.
-- ---------------------------------------------------------------------
do $$
declare
  v_falta text := '';
begin
  if to_regclass('public.cuentas') is null
     or not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'cuentas'
                       and column_name = 'regla_cost_code') then
    v_falta := v_falta || ' · falta la tabla cuentas de c1: pega antes c1-plan-de-cuentas.sql';
  elsif not exists (select 1 from public.cuentas) then
    v_falta := v_falta || ' · la tabla cuentas está vacía: pega antes c1-plan-de-cuentas.sql';
  end if;
  -- La versión de c1 que va con este archivo trae el historial de cuentas
  -- (el verificador de abajo revisa sus guardas y sus permisos).
  if to_regclass('public.cuentas_historial') is null then
    v_falta := v_falta || ' · falta cuentas_historial: pega antes la versión nueva de c1-plan-de-cuentas.sql';
  end if;
  if to_regprocedure('public.es_dueno()') is null then
    v_falta := v_falta || ' · falta la función public.es_dueno()';
  end if;
  if to_regprocedure('auth.uid()') is null then
    v_falta := v_falta || ' · falta auth.uid() (¿esto es Supabase?)';
  end if;
  if to_regclass('public.codigos_partida') is null
     or not exists (select 1 from pg_index i
                     where i.indrelid = 'public.codigos_partida'::regclass
                       and i.indisunique and i.indimmediate and i.indpred is null and i.indnkeyatts = 1
                       and i.indkey[0] = (select attnum from pg_attribute
                                           where attrelid = 'public.codigos_partida'::regclass and attname = 'codigo')) then
    v_falta := v_falta || ' · codigos_partida.codigo no existe o no es único (el libro le pone una FK)';
  end if;
  if to_regclass('public.proyectos') is null
     or (select data_type from information_schema.columns
          where table_schema = 'public' and table_name = 'proyectos' and column_name = 'id') is distinct from 'text'
     or not exists (select 1 from pg_index i
                     where i.indrelid = 'public.proyectos'::regclass
                       and i.indisunique and i.indimmediate and i.indpred is null and i.indnkeyatts = 1
                       and i.indkey[0] = (select attnum from pg_attribute
                                           where attrelid = 'public.proyectos'::regclass and attname = 'id')) then
    v_falta := v_falta || ' · proyectos.id no existe, no es text o no es único (el libro le pone una FK)';
  elsif not has_table_privilege('public.proyectos', 'TRIGGER') then
    v_falta := v_falta || ' · quien pega no puede poner triggers en proyectos (el libro le pone uno: una obra con asientos no se borra)';
  end if;
  -- Si ya hay un «asientos», tiene que ser el de este archivo.
  if to_regclass('public.asientos') is not null
     and not exists (select 1 from information_schema.columns
                      where table_schema = 'public' and table_name = 'asientos'
                        and column_name = 'hash_anterior') then
    v_falta := v_falta || ' · ya existe una tabla public.asientos que NO es la de este archivo';
  end if;

  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c2-libro NO se aplicó, no se tocó nada. Falta lo que este archivo da por hecho:' || v_falta;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- A.1 · fn_fecha_miami — versión MÍNIMA (ingenua a propósito: la fecha
-- del reloj de la sesión, que en UTC ya es 1-ene a las 7 pm del 31-dic de
-- Miami). La de verdad está en el bloque B. Va antes que las tablas
-- porque asientos.fecha_contable la usa de default.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.fn_fecha_miami(timestamptz)') is null then
    execute $f$
      create function public.fn_fecha_miami(t timestamptz) returns date
      language sql stable
      set search_path = public, pg_temp
      as 'select t::date'
    $f$;
    execute 'revoke execute on function public.fn_fecha_miami(timestamptz) from public, anon, service_role';
    execute 'revoke execute on function public.fn_fecha_miami(timestamptz) from authenticated';
    execute 'grant execute on function public.fn_fecha_miami(timestamptz) to authenticated';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- A.2 · periodos
-- Un período por mes, uno por la apertura (un solo día, el 30-sep-2026)
-- y uno por año. Los meses y la apertura no se pisan (exclusión por
-- rango); el año los abarca a propósito. «paralelo» marca octubre–
-- diciembre de 2026: los libros oficiales de ese año son QuickBooks.
-- ---------------------------------------------------------------------
create table if not exists public.periodos (
  periodo           text        primary key,
  tipo              text        not null,
  anio              int         not null,
  desde             date        not null,
  hasta             date        not null,
  estado            text        not null default 'abierto',
  paralelo          boolean     not null default false,
  cerrado_el        timestamptz,
  cerrado_por       uuid,
  cerrado_rol       text,
  cerrado_conexion  jsonb,
  cadena_al_cerrar  text,
  creado            timestamptz not null default now(),

  constraint periodos_tipo_valido   check (tipo in ('apertura','mes','anio')),
  constraint periodos_estado_valido check (estado in ('abierto','cerrado')),
  constraint periodos_rango
    check (desde <= hasta
           and extract(year from desde)::int = anio
           and extract(year from hasta)::int = anio),
  -- La forma de cada tipo, sin funciones que dependan de la zona horaria.
  constraint periodos_forma
    check (   (tipo = 'mes'
               and periodo = anio::text || '-' || lpad(extract(month from desde)::int::text, 2, '0')
               and desde = make_date(anio, extract(month from desde)::int, 1)
               and hasta = (desde + interval '1 month')::date - 1)
           or (tipo = 'anio'
               and periodo = anio::text
               and desde = make_date(anio, 1, 1)
               and hasta = make_date(anio, 12, 31))
           or (tipo = 'apertura'
               and periodo = anio::text || '-' || lpad(extract(month from desde)::int::text, 2, '0') || '-APERTURA'
               and desde = hasta)),
  constraint periodos_cierre_completo check ((estado = 'cerrado') = (cerrado_el is not null)),
  -- Un día cae en un solo mes (o en la apertura). El año no cuenta.
  constraint periodos_sin_traslape
    exclude using gist (daterange(desde, hasta, '[]') with &&) where (tipo <> 'anio')
);

-- Por si la tabla ya existía de un borrador anterior sin la columna.
alter table public.periodos add column if not exists cerrado_conexion jsonb;

-- ---------------------------------------------------------------------
-- A.3 · contadores — la numeración sin huecos. Una fila por serie
-- ('asientos-2027'); f10 añadirá la de facturas. Es una fila y no una
-- secuencia de Postgres porque la secuencia NO se deshace con el
-- rollback: un asiento rechazado dejaría un hueco.
-- ---------------------------------------------------------------------
create table if not exists public.contadores (
  serie   text   primary key,
  ultimo  bigint not null default 0,
  constraint contadores_serie_formato check (serie ~ '^[a-z_]+-[0-9]{4}$'),
  constraint contadores_ultimo_no_negativo check (ultimo >= 0)
);

-- ---------------------------------------------------------------------
-- A.4 · asientos — la cabecera.
-- Las columnas de sistema (numero, anio, secuencia, cadena_pos, periodo,
-- usuario_id, rol_bd, creado_el, hash_anterior, hash) las pone el
-- trigger del bloque B, pisando lo que mande quien inserta: nadie elige
-- su número, su período, su sello ni su hash.
-- sustituye_a: un documento tiene UN asiento vivo. Si su asiento estaba
-- mal (el mapeo del puente, una forma de pago mal leída, un recibo
-- anulado que se des-anula), se reversa, y el asiento nuevo del MISMO
-- documento dice a cuál sustituye. Así el papel enseña su historia
-- entera: original, reverso y sustituto, enlazados.
-- ---------------------------------------------------------------------
create table if not exists public.asientos (
  id               uuid        primary key default gen_random_uuid(),
  numero           text        not null,
  anio             int         not null,
  secuencia        int         not null,
  cadena_pos       bigint      not null,
  fecha_contable   date        not null default public.fn_fecha_miami(now()),
  periodo          text        not null references public.periodos (periodo),
  tipo             text        not null default 'normal',
  afecta_periodo   text        references public.periodos (periodo),
  camino           text        not null,
  descripcion      text        not null,
  motivo           text,
  reversa_a        uuid        references public.asientos (id),
  reversible       boolean     not null default false,
  origen_tabla     text,
  origen_id        text,
  sustituye_a      uuid        references public.asientos (id),
  documento_ruta   text,
  propuesta_id     uuid,
  procedencia      jsonb       not null default '{}'::jsonb,
  usuario_id       uuid,
  rol_bd           text        not null default current_user,
  creado_el        timestamptz not null default now(),
  hash_anterior    text        not null,
  hash             text        not null,

  constraint asientos_numero_unico          unique (numero),
  constraint asientos_anio_secuencia_unica  unique (anio, secuencia),
  constraint asientos_cadena_pos_unica      unique (cadena_pos),
  constraint asientos_numero_formato        check (numero = anio::text || '-' || lpad(secuencia::text, 6, '0')),
  constraint asientos_secuencia_rango       check (secuencia between 1 and 999999),
  constraint asientos_anio_de_la_fecha      check (anio = extract(year from fecha_contable)::int),
  constraint asientos_cadena_pos_positiva   check (cadena_pos >= 1),
  constraint asientos_tipo_valido           check (tipo in ('normal','apertura','ajuste_cpa')),
  constraint asientos_camino_valido         check (camino in ('mano','puente','ia','reverso','reverso_automatico')),
  constraint asientos_descripcion_llena     check (btrim(descripcion) <> ''),
  constraint asientos_reverso_coherente     check ((reversa_a is not null) = (camino in ('reverso','reverso_automatico'))),
  constraint asientos_reverso_con_motivo    check (reversa_a is null or coalesce(btrim(motivo), '') <> ''),
  constraint asientos_reverso_no_reversible check (not (reversible and reversa_a is not null)),
  constraint asientos_ajuste_cpa            check ((tipo = 'ajuste_cpa') = (afecta_periodo is not null)),
  constraint asientos_ajuste_cpa_motivo     check (tipo <> 'ajuste_cpa' or coalesce(btrim(motivo), '') <> ''),
  constraint asientos_ia_con_propuesta      check ((camino = 'ia') = (propuesta_id is not null)),
  constraint asientos_origen_completo       check ((origen_tabla is null) = (origen_id is null)),
  constraint asientos_puente_con_origen     check (camino <> 'puente' or origen_tabla is not null),
  constraint asientos_procedencia_objeto    check (jsonb_typeof(procedencia) = 'object')
);

-- Por si la tabla ya existía de un borrador anterior sin la columna.
alter table public.asientos add column if not exists sustituye_a uuid references public.asientos (id);

create index if not exists asientos_periodo_idx on public.asientos (periodo);
create index if not exists asientos_origen_idx  on public.asientos (origen_tabla, origen_id) where origen_tabla is not null;

-- ---------------------------------------------------------------------
-- A.5 · asiento_lineas — las líneas. Monto con signo: positivo = debe,
-- negativo = haber. El asiento cuadra cuando suman cero.
-- La FK a la cabecera es DIFERIDA a propósito: las líneas entran PRIMERO
-- y la cabecera DESPUÉS, para que el trigger de la cabecera las vea todas
-- al calcular el cuadre y el hash. Una línea sin cabecera no llega viva
-- al commit.
-- La llave es (asiento_id, orden), sin secuencia: una secuencia no se
-- deshace con el rollback, y cada asiento rechazado (o cada pegado de
-- c2-pruebas.sql) dejaría huecos en un número que un auditor leería.
-- El monto es numeric(14,2): se redondea a centavos AL GUARDAR, antes de
-- que ningún trigger lo vea. Por eso la escala (MX005) la mira
-- fn_postear_interno leyendo el texto; un insert directo desde el SQL
-- Editor no pasa por ahí y queda marcado en la procedencia de su asiento
-- como «insert_directo» (B.8).
-- El tercero de cada línea y la partida abierta que crea o salda (f03,
-- decidido ANTES del primer asiento real, porque una línea no se edita):
--   · tercero_tipo + tercero_id: CON QUIÉN es el saldo. 'proveedor'
--     (proveedores.id, la tabla de f03: el supply, el subcontratista, el
--     ayudante) o 'empleado' (perfiles.id: el reembolso que se le debe).
--     Así sale «qué se le debe a cada supply» (2010 por proveedor).
--   · partida_tabla + partida_id: QUÉ papel abierto crea o salda la línea.
--     El recibo a cuenta abre su partida en 2010; el pago de f06 la salda
--     con otra línea que nombra la misma partida. La factura abre la suya
--     en 1110 (y 1120, la retención); el cobro la salda. Un anticipo es
--     una partida del cobro mismo. Lo abierto es la partida cuya suma no
--     es cero.
-- Son columnas nulas: fn_asiento_canonico las sella solo cuando no son
-- nulas, así que no cambian ningún hash de antes. Un reverso las copia
-- (el espejo exacto incluye tercero y partida).
-- ---------------------------------------------------------------------
create table if not exists public.asiento_lineas (
  asiento_id    uuid          not null references public.asientos (id) deferrable initially deferred,
  orden         int           not null,
  cuenta        text          not null references public.cuentas (codigo),
  monto         numeric(14,2) not null,
  proyecto_id   text          references public.proyectos (id),
  cost_code     text          references public.codigos_partida (codigo),
  co            text,
  fase          text,
  memo          text,
  tercero_tipo  text,
  tercero_id    text,
  partida_tabla text,
  partida_id    text,
  constraint asiento_lineas_pk              primary key (asiento_id, orden),
  constraint asiento_lineas_orden_positivo  check (orden >= 1),
  constraint asiento_lineas_monto_no_cero   check (monto <> 0)
);

-- Por si la tabla ya existía de un pegado anterior sin el tercero y la
-- partida (columnas nulas: no tocan ninguna fila ni ningún hash).
alter table public.asiento_lineas add column if not exists tercero_tipo  text;
alter table public.asiento_lineas add column if not exists tercero_id    text;
alter table public.asiento_lineas add column if not exists partida_tabla text;
alter table public.asiento_lineas add column if not exists partida_id    text;

-- Un borrador anterior de este archivo tenía un id con secuencia. Si esa
-- tabla existe y sigue vacía, se deja como la de arriba; con líneas no se
-- toca (el id no entra en el hash, así que tampoco estorba).
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'asiento_lineas' and column_name = 'id')
     and not exists (select 1 from public.asiento_lineas) then
    alter table public.asiento_lineas drop column id;
    alter table public.asiento_lineas drop constraint if exists asiento_lineas_orden_unico;
    alter table public.asiento_lineas add constraint asiento_lineas_pk primary key (asiento_id, orden);
  end if;
end $$;

create index if not exists asiento_lineas_cuenta_idx   on public.asiento_lineas (cuenta);
create index if not exists asiento_lineas_proyecto_idx on public.asiento_lineas (proyecto_id) where proyecto_id is not null;
-- Las partidas abiertas y los saldos por tercero (f03): la guarda de un
-- documento pregunta si alguna línea lo nombra, y la CxP y la CxC agrupan
-- por aquí.
create index if not exists asiento_lineas_partida_idx  on public.asiento_lineas (partida_tabla, partida_id) where partida_tabla is not null;
create index if not exists asiento_lineas_tercero_idx  on public.asiento_lineas (tercero_tipo, tercero_id) where tercero_tipo is not null;

-- ---------------------------------------------------------------------
-- A.6 · Los períodos con que arranca el libro. Solo se proponen los que
-- no existen (así el trigger de periodos del bloque B no juzga filas que
-- ya están, cerradas o no, al volver a pegar). Tres sentencias, en este
-- orden, porque un mes y la apertura cuelgan de su año.
-- ---------------------------------------------------------------------
insert into public.periodos (periodo, tipo, anio, desde, hasta, paralelo)
select v.periodo, v.tipo, v.anio, v.desde, v.hasta, v.paralelo
  from (values
          ('2026', 'anio', 2026, date '2026-01-01', date '2026-12-31', true),
          ('2027', 'anio', 2027, date '2027-01-01', date '2027-12-31', false)
       ) as v(periodo, tipo, anio, desde, hasta, paralelo)
 where not exists (select 1 from public.periodos p where p.periodo = v.periodo)
on conflict (periodo) do nothing;

insert into public.periodos (periodo, tipo, anio, desde, hasta, paralelo)
select '2026-09-APERTURA', 'apertura', 2026, date '2026-09-30', date '2026-09-30', true
 where not exists (select 1 from public.periodos p where p.periodo = '2026-09-APERTURA')
on conflict (periodo) do nothing;

insert into public.periodos (periodo, tipo, anio, desde, hasta, paralelo)
select to_char(m, 'YYYY-MM'), 'mes', extract(year from m)::int, m::date,
       (m + interval '1 month')::date - 1, m < timestamp '2027-01-01'
  from generate_series(timestamp '2026-10-01', timestamp '2027-12-01', interval '1 month') as m
 where not exists (select 1 from public.periodos p where p.periodo = to_char(m, 'YYYY-MM'))
 order by m
on conflict (periodo) do nothing;


-- ---------------------------------------------------------------------
-- A.7 · Quién llama. Dos ayudantes que usan las funciones de verdad del
-- bloque B y también las mínimas de abajo (por eso van aquí).
--   fn_rol_llamante: dentro de una función SECURITY DEFINER current_user
--     es el dueño de la función, pero el ajuste «role» sigue diciendo con
--     qué rol entró la petición: authenticated, anon o service_role por
--     la API; 'none' en el SQL Editor (y en pg_cron), que entra como el
--     dueño de la base. Así cada asiento guarda el rol real, no el de la
--     función.
--   fn_desde_editor: sin «set role» y con la sesión del dueño de las
--     tablas del libro. Por la API la sesión es de «authenticator», que no
--     es el dueño, y el rol nunca es 'none'. OJO: una conexión directa con
--     la contraseña de la base, o con SUPABASE_DB_URL desde una función de
--     borde, TAMBIÉN es «el editor»: la base no puede distinguirla (ver la
--     cabecera, QUIÉN LLAMA QUÉ).
-- ---------------------------------------------------------------------
create or replace function public.fn_rol_llamante() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(nullif(current_setting('role', true), 'none'), session_user::text)
$$;
revoke execute on function public.fn_rol_llamante() from public, anon, authenticated, service_role;

create or replace function public.fn_desde_editor() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(current_setting('role', true), 'none') = 'none'
     and pg_has_role(session_user,
                     (select c.relowner from pg_class c where c.oid = 'public.asientos'::regclass),
                     'member')
$$;
revoke execute on function public.fn_desde_editor() from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- A.8 · Las funciones MÍNIMAS, sin controles de contenido. Mismo nombre,
-- mismos parámetros y mismo resultado que las de verdad del bloque B,
-- para que c2-pruebas.sql corra entero en rojo y cada ataque diga
-- «entró». Se crean SOLO si no existen: al volver a pegar el archivo, las
-- de verdad siguen puestas. Llevan los revoke de la regla de siempre desde
-- el primer momento (toda función nueva nace ejecutable por anon), y las
-- que escriben dejan pasar SOLO al dueño (o al SQL Editor): si alguien
-- pega el bloque A solo por error en Supabase, ni un trabajador ni la
-- llave pública pueden escribir en el libro mientras falta el bloque B.
-- ---------------------------------------------------------------------
do $$
begin
  -- fn_postear MÍNIMA: sin cuadre, sin escala, sin período cerrado, sin
  -- cuentas ni dimensiones, sin reverso automático, sin cadena (hash de
  -- ceros), numerando con max + 1. Solo mira quién.
  if to_regprocedure('public.fn_postear(jsonb)') is null then
    execute $f$
      create function public.fn_postear(p_asiento jsonb) returns jsonb
      language plpgsql security definer
      set search_path = public, pg_temp
      as $b$
      declare
        v_id    uuid := gen_random_uuid();
        v_fecha date := coalesce((p_asiento->>'fecha')::date, fn_fecha_miami(now()));
        v_anio  int  := extract(year from coalesce((p_asiento->>'fecha')::date, fn_fecha_miami(now())))::int;
        v_sec   int;
        v_pos   bigint;
        v_per   text;
        v_l     jsonb;
        v_i     int := 0;
      begin
        if not (es_dueno() or fn_desde_editor()) then
          raise exception using errcode = '42501', message = 'Solo el dueño postea (versión mínima del bloque A).';
        end if;
        select coalesce(max(secuencia), 0) + 1 into v_sec from asientos where anio = v_anio;
        select coalesce(max(cadena_pos), 0) + 1 into v_pos from asientos;
        select periodo into v_per from periodos where tipo <> 'anio' and v_fecha between desde and hasta;
        for v_l in select value from jsonb_array_elements(p_asiento->'lineas') loop
          v_i := v_i + 1;
          insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo)
          values (v_id, v_i, v_l->>'cuenta', (v_l->>'monto')::numeric, v_l->>'proyecto_id',
                  v_l->>'cost_code', v_l->>'co', v_l->>'fase', v_l->>'memo');
        end loop;
        insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, tipo, camino,
                              descripcion, reversible, hash_anterior, hash)
        values (v_id, v_anio::text || '-' || lpad(v_sec::text, 6, '0'), v_anio, v_sec, v_pos, v_fecha, v_per,
                coalesce(p_asiento->>'tipo', 'normal'), 'mano',
                coalesce(nullif(btrim(p_asiento->>'descripcion'), ''), '(sin descripción)'),
                coalesce((p_asiento->>'reversible')::boolean, false), repeat('0', 64), repeat('0', 64));
        return jsonb_build_object('id', v_id, 'numero', v_anio::text || '-' || lpad(v_sec::text, 6, '0'),
                                  'fecha_contable', v_fecha, 'periodo', v_per, 'reverso', null);
      end
      $b$
    $f$;
    execute 'revoke execute on function public.fn_postear(jsonb) from public, anon, service_role';
    execute 'revoke execute on function public.fn_postear(jsonb) from authenticated';
    execute 'grant execute on function public.fn_postear(jsonb) to authenticated';
  end if;

  -- fn_reversar MÍNIMA: espejo con la fecha del original, sin mirar si ya
  -- se reversó, si es un reverso ni si su período está cerrado. Solo mira
  -- quién.
  if to_regprocedure('public.fn_reversar(uuid,text)') is null then
    execute $f$
      create function public.fn_reversar(p_asiento uuid, p_motivo text) returns jsonb
      language plpgsql security definer
      set search_path = public, pg_temp
      as $b$
      declare
        v_o   asientos;
        v_id  uuid := gen_random_uuid();
        v_sec int;
        v_pos bigint;
      begin
        if not (es_dueno() or fn_desde_editor()) then
          raise exception using errcode = '42501', message = 'Solo el dueño reversa (versión mínima del bloque A).';
        end if;
        select * into v_o from asientos where id = p_asiento;
        select coalesce(max(secuencia), 0) + 1 into v_sec from asientos where anio = v_o.anio;
        select coalesce(max(cadena_pos), 0) + 1 into v_pos from asientos;
        insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo)
        select v_id, orden, cuenta, -monto, proyecto_id, cost_code, co, fase, memo
          from asiento_lineas where asiento_id = p_asiento;
        insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, tipo, afecta_periodo,
                              camino, descripcion, motivo, reversa_a, hash_anterior, hash)
        values (v_id, v_o.anio::text || '-' || lpad(v_sec::text, 6, '0'), v_o.anio, v_sec, v_pos,
                v_o.fecha_contable, v_o.periodo, v_o.tipo, v_o.afecta_periodo, 'reverso',
                'Reverso de ' || v_o.numero, coalesce(nullif(btrim(p_motivo), ''), '(sin motivo)'),
                p_asiento, repeat('0', 64), repeat('0', 64));
        return jsonb_build_object('id', v_id, 'numero', v_o.anio::text || '-' || lpad(v_sec::text, 6, '0'),
                                  'fecha_contable', v_o.fecha_contable, 'periodo', v_o.periodo);
      end
      $b$
    $f$;
    execute 'revoke execute on function public.fn_reversar(uuid, text) from public, anon, service_role';
    execute 'revoke execute on function public.fn_reversar(uuid, text) from authenticated';
    execute 'grant execute on function public.fn_reversar(uuid, text) to authenticated';
  end if;

  -- fn_estado MÍNIMA: cuenta, pero dice que cuadra sin mirar.
  if to_regprocedure('public.fn_estado(text)') is null then
    execute $f$
      create function public.fn_estado(p_periodo text)
      returns table (periodo text, tipo text, estado text, paralelo boolean, asientos bigint, filas bigint,
                     total_debe numeric, total_haber numeric, cuadra boolean)
      language sql stable
      set search_path = public, pg_temp
      as $b$
        select p.periodo, p.tipo, p.estado, p.paralelo,
               (select count(*) from asientos a where a.periodo = p.periodo),
               (select count(*) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.periodo = p.periodo),
               0::numeric, 0::numeric, true
          from periodos p
         where p.periodo = p_periodo
      $b$
    $f$;
    execute 'revoke execute on function public.fn_estado(text) from public, anon, service_role';
    execute 'revoke execute on function public.fn_estado(text) from authenticated';
    execute 'grant execute on function public.fn_estado(text) to authenticated';
  end if;

  -- fn_verificar_cadena MÍNIMA: no verifica nada y dice que todo va bien.
  if to_regprocedure('public.fn_verificar_cadena()') is null then
    execute $f$
      create function public.fn_verificar_cadena()
      returns table (control text, ok boolean, detalle jsonb)
      language sql stable security definer
      set search_path = public, pg_temp
      as $b$
        select 'cadena'::text, true, jsonb_build_object('nota', 'versión mínima del bloque A: no verifica nada')
      $b$
    $f$;
    execute 'revoke execute on function public.fn_verificar_cadena() from public, anon, service_role';
    execute 'revoke execute on function public.fn_verificar_cadena() from authenticated';
    execute 'grant execute on function public.fn_verificar_cadena() to authenticated';
  end if;

  -- fn_cerrar_periodo MÍNIMA: cierra sin mirar orden ni cuadre (y sin
  -- guardar el hash). Solo mira quién.
  if to_regprocedure('public.fn_cerrar_periodo(text)') is null then
    execute $f$
      create function public.fn_cerrar_periodo(p_periodo text) returns jsonb
      language plpgsql security definer
      set search_path = public, pg_temp
      as $b$
      declare
        v_p periodos;
      begin
        if not (es_dueno() or fn_desde_editor()) then
          raise exception using errcode = '42501', message = 'Solo el dueño cierra (versión mínima del bloque A).';
        end if;
        update periodos set estado = 'cerrado', cerrado_el = now()
         where periodo = p_periodo
        returning * into v_p;
        return to_jsonb(v_p);
      end
      $b$
    $f$;
    execute 'revoke execute on function public.fn_cerrar_periodo(text) from public, anon, service_role';
    execute 'revoke execute on function public.fn_cerrar_periodo(text) from authenticated';
    execute 'grant execute on function public.fn_cerrar_periodo(text) to authenticated';
  end if;

  -- fn_abrir_periodo MÍNIMA: abre sin mirar el orden. Solo mira quién.
  if to_regprocedure('public.fn_abrir_periodo(text)') is null then
    execute $f$
      create function public.fn_abrir_periodo(p_mes text) returns jsonb
      language plpgsql security definer
      set search_path = public, pg_temp
      as $b$
      declare
        v_desde date := (p_mes || '-01')::date;
        v_anio  int  := extract(year from (p_mes || '-01')::date)::int;
        v_p     periodos;
      begin
        if not (es_dueno() or fn_desde_editor()) then
          raise exception using errcode = '42501', message = 'Solo el dueño abre (versión mínima del bloque A).';
        end if;
        insert into periodos (periodo, tipo, anio, desde, hasta)
        values (v_anio::text, 'anio', v_anio, make_date(v_anio, 1, 1), make_date(v_anio, 12, 31))
        on conflict (periodo) do nothing;
        insert into periodos (periodo, tipo, anio, desde, hasta)
        values (p_mes, 'mes', v_anio, v_desde, (v_desde + interval '1 month')::date - 1)
        on conflict (periodo) do nothing;
        select * into v_p from periodos where periodo = p_mes;
        return to_jsonb(v_p);
      end
      $b$
    $f$;
    execute 'revoke execute on function public.fn_abrir_periodo(text) from public, anon, service_role';
    execute 'revoke execute on function public.fn_abrir_periodo(text) from authenticated';
    execute 'grant execute on function public.fn_abrir_periodo(text) to authenticated';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- A.9 · Quién lee. Al final del bloque A, y no en el B: las tablas nacen
-- abiertas (así es Supabase: grant all a anon y authenticated) y se
-- cierran en el mismo bloque que las crea. Pegado solo, por error, el
-- bloque A no deja el libro abierto a la API. Es el bloque fijo de todo
-- docs/conta/c*.sql, tabla por tabla: solo el dueño lee (policy); nadie
-- de la API escribe (todo entra por las funciones); anon, nada.
-- service_role conserva la lectura (la función «contador» de f07 lee para
-- proponer) y ninguna escritura. Los triggers, además, frenan al propio
-- SQL Editor.
--   · «revoke all» y luego «grant select», y no una lista de privilegios:
--     en Postgres 17 (producción) el «grant all» de Supabase incluye
--     MAINTAIN (LOCK TABLE, VACUUM, CLUSTER…), que una lista escrita para
--     16 no nombra. «all» vale igual en 16 y en 17, y quita también lo
--     concedido por columna.
--   · Al volver a pegar se borra toda policy de estas tablas que no sea la
--     de aquí: una «Enable read access for all users» creada desde el
--     dashboard, o una editada a mano, no sobrevive a un pegado.
--   · Riesgo conocido y aceptado: authenticated necesita el SELECT de
--     tabla (la policy es la que filtra), y con él PostgREST puede dar la
--     ESTIMACIÓN del planificador («Prefer: count=planned»), que sale de
--     las estadísticas reales. Un trabajador puede asomar así cuántas
--     líneas hay por cuenta, por obra o por fecha; nunca un monto, una
--     descripción ni una contraparte (numeric no es «leakproof»: el
--     planificador no usa sus estadísticas para quien no puede ver las
--     filas). Pasa igual hoy con facturas y recibos. Cerrarlo pide un rol
--     propio para el dueño en el token (un hook de Supabase) o leer solo
--     por funciones; se decide si algún día hace falta el rol «contador».
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['periodos', 'contadores', 'asientos', 'asiento_lineas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl
              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname <> t || '_dueno' loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    -- «(select es_dueno())»: una vez por consulta, no por fila (ver la
    -- cabecera).
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
  end loop;
end $$;


-- ==== BLOQUE B ====
-- =====================================================================
-- Los controles. Todo lo que sigue se puede volver a pegar: funciones con
-- «create or replace», triggers con «create or replace trigger» (sin un
-- instante sin guarda), restricciones solo si faltan.
-- =====================================================================

-- ---------------------------------------------------------------------
-- B.0 · Antes de nada: el bloque B no se pone ENCIMA de datos escritos
-- sin controles. Si alguien pegó el bloque A solo (en Supabase, por
-- error) y en esa ventana entró algo por las funciones mínimas (un
-- asiento sin sellar, un contador suelto, un período cerrado sin la foto
-- de la cadena), el bloque B se niega con MX000 y no toca nada: puesto
-- encima, ese dato no se podría borrar nunca (lo impiden las guardas de
-- abajo) y el libro no volvería a aceptar un posteo. Con el bloque A solo
-- todavía se puede borrar a mano; después se vuelve a pegar el archivo.
-- Sobre un libro sano (volver a pegar el archivo entero) no encuentra
-- nada.
-- ---------------------------------------------------------------------
do $$
declare
  v_sucio text := '';
  v_n     bigint;
begin
  select count(*) into v_n from public.asientos where hash = repeat('0', 64);
  if v_n > 0 then
    v_sucio := v_sucio || format(' · %s asiento(s) sin sellar (hash de ceros): los escribió una función mínima', v_n);
  end if;
  select count(*) into v_n
    from public.contadores c
   where c.serie like 'asientos-%'
     and c.ultimo <> coalesce((select max(a.secuencia) from public.asientos a
                                where 'asientos-' || a.anio::text = c.serie), 0);
  if v_n > 0 then
    v_sucio := v_sucio || format(' · %s contador(es) de asientos que no casan con el libro', v_n);
  end if;
  select count(*) into v_n from public.periodos where estado = 'cerrado' and cadena_al_cerrar is null;
  if v_n > 0 then
    v_sucio := v_sucio || format(' · %s período(s) cerrado(s) sin la foto de la cadena (los cerró la función mínima)', v_n);
  end if;
  select count(*) into v_n from public.periodos where tipo = 'apertura';
  if v_n > 1 then
    v_sucio := v_sucio || format(' · %s aperturas: el libro tiene una sola (la del 30-sep-2026)', v_n);
  end if;
  if v_sucio <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c2-libro (bloque B) NO se aplicó, no se tocó nada: hay datos escritos con el bloque A solo, sin controles:' || v_sucio,
      hint    = 'Con el bloque A solo todavía se pueden borrar a mano (delete de asiento_lineas, asientos y contadores; '
                'update de periodos a abierto; delete de la apertura que sobra). Después se pega el archivo ENTERO.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- B.1 · La fecha de Miami, de verdad. Miami no tiene zona propia y 'EST'
-- no cambia con el verano: se usa America/New_York. Un cargo del 31-dic a
-- las 7 pm de Miami es 1-ene en UTC; aquí sigue siendo 31-dic, sea cual
-- sea la zona de la sesión. Nunca se deriva de un reloj de pantalla.
-- ---------------------------------------------------------------------
create or replace function public.fn_fecha_miami(t timestamptz) returns date
language sql stable
set search_path = public, pg_temp
as $$ select (t at time zone 'America/New_York')::date $$;
revoke execute on function public.fn_fecha_miami(timestamptz) from public, anon, authenticated, service_role;
grant  execute on function public.fn_fecha_miami(timestamptz) to authenticated;

-- (B.2 · Quién llama: fn_rol_llamante y fn_desde_editor están en A.7,
-- porque también las usan las funciones mínimas del bloque A.)

-- ---------------------------------------------------------------------
-- B.3 · La forma canónica de un asiento: el texto exacto que se sella con
-- sha256. UNA sola función para sellar (trigger) y para verificar
-- (fn_verificar_cadena): no hay dos caminos que puedan desviarse.
--   · Todo va como texto y sin depender de la sesión: la fecha con
--     to_char sobre timestamp, la hora en UTC con microsegundos, los
--     montos con sus dos decimales.
--   · Es un objeto JSON sin nulos (jsonb ordena las claves solo). Si una
--     fase futura añade una columna, entra aquí SOLO cuando no es nula:
--     así los hashes viejos siguen valiendo sin versión nueva.
--   · Incluye el hash anterior: por eso es una cadena. Cambiar un
--     centavo de un asiento viejo rompe su hash y el de todos los que
--     vienen detrás.
-- ---------------------------------------------------------------------
create or replace function public.fn_asiento_canonico(a public.asientos) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'formato',        'MXLIBRO-1',
    'hash_anterior',  a.hash_anterior,
    'cadena_pos',     a.cadena_pos::text,
    'id',             a.id::text,
    'numero',         a.numero,
    'fecha_contable', to_char(a.fecha_contable::timestamp, 'YYYY-MM-DD'),
    'periodo',        a.periodo,
    'tipo',           a.tipo,
    'afecta_periodo', a.afecta_periodo,
    'camino',         a.camino,
    'descripcion',    a.descripcion,
    'motivo',         a.motivo,
    'reversa_a',      a.reversa_a::text,
    'reversible',     a.reversible::text,
    'origen_tabla',   a.origen_tabla,
    'origen_id',      a.origen_id,
    'sustituye_a',    a.sustituye_a::text,
    'documento_ruta', a.documento_ruta,
    'propuesta_id',   a.propuesta_id::text,
    'procedencia',    a.procedencia::text,
    'usuario_id',     a.usuario_id::text,
    'rol_bd',         a.rol_bd,
    'creado_el',      to_char(a.creado_el at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'lineas', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                        'orden',         l.orden::text,
                        'cuenta',        l.cuenta,
                        'monto',         l.monto::text,
                        'proyecto_id',   l.proyecto_id,
                        'cost_code',     l.cost_code,
                        'co',            l.co,
                        'fase',          l.fase,
                        'memo',          l.memo,
                        -- f03: el tercero y la partida; solo cuando no son
                        -- nulos, así que los hashes de antes siguen valiendo.
                        'tercero_tipo',  l.tercero_tipo,
                        'tercero_id',    l.tercero_id,
                        'partida_tabla', l.partida_tabla,
                        'partida_id',    l.partida_id)) order by l.orden)
                 from public.asiento_lineas l
                where l.asiento_id = a.id)
  ))::text
$$;
revoke execute on function public.fn_asiento_canonico(public.asientos) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- B.4 · Restricciones que SON controles (por eso no están en el bloque A):
--   · un asiento tiene a lo sumo UN reverso de cada camino: el suyo
--     ('reverso', la corrección) y, si es un devengo reversible, su
--     reverso automático del día 1 ('reverso_automatico', que es parte
--     del devengo y no una corrección). Un devengo mal calculado se
--     corrige en su mes con su reverso de siempre, y por eso puede tener
--     los dos (B.8, paso 4). Un borrador anterior pedía un solo reverso
--     por asiento, y así un devengo no se podía corregir: se cambia;
--   · un asiento reversado se sustituye una sola vez, y el sustituto
--     lleva el documento de origen y no es un reverso;
--   · la cadena no se bifurca: cada hash, y cada hash anterior, una vez;
--   · el hash tiene forma de sha256;
--   · el libro tiene UNA apertura. Es la segunda red de la guarda de
--     periodos: aguanta aunque alguien la apague para meter otra (una
--     segunda apertura, anterior, cambiaría el balance de todos los meses
--     cerrados).
-- Solo se añaden si faltan: volver a pegar no reconstruye índices.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_un_reverso_por_camino') then
    alter table public.asientos add constraint asientos_un_reverso_por_camino unique (reversa_a, camino);
  end if;
  if exists (select 1 from pg_constraint
              where conrelid = 'public.asientos'::regclass and conname = 'asientos_reversa_a_unica') then
    alter table public.asientos drop constraint asientos_reversa_a_unica;
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_sustituye_a_unica') then
    alter table public.asientos add constraint asientos_sustituye_a_unica unique (sustituye_a);
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_sustituye_coherente') then
    alter table public.asientos add constraint asientos_sustituye_coherente
      check (sustituye_a is null
             or (sustituye_a <> id and origen_tabla is not null
                 and camino not in ('reverso', 'reverso_automatico')));
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_hash_unico') then
    alter table public.asientos add constraint asientos_hash_unico unique (hash);
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_hash_anterior_unico') then
    alter table public.asientos add constraint asientos_hash_anterior_unico unique (hash_anterior);
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_hash_formato') then
    alter table public.asientos add constraint asientos_hash_formato
      check (hash ~ '^[0-9a-f]{64}$' and hash_anterior ~ '^[0-9a-f]{64}$');
  end if;
end $$;

-- El tercero y la partida de una línea (f03), en su forma: van los dos
-- campos o ninguno, de un tipo que el libro conoce, y con el id escrito
-- como lo escribe Postgres (un uuid en minúsculas, un número sin ceros
-- delante): la misma partida escrita de dos maneras serían dos partidas, y
-- lo abierto no cuadraría nunca. Que el tercero y la partida EXISTAN lo
-- mira el trigger de cada línea (B.7); fn_postear_interno lo dice antes,
-- en español. Una fase que abra partidas en otra tabla (los préstamos de
-- f06, la nómina de f11) la añade aquí.
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asiento_lineas'::regclass and conname = 'asiento_lineas_tercero_forma') then
    alter table public.asiento_lineas add constraint asiento_lineas_tercero_forma
      check (    (tercero_tipo is null and tercero_id is null)
             or (tercero_tipo in ('proveedor', 'empleado')
                 and tercero_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'));
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asiento_lineas'::regclass and conname = 'asiento_lineas_partida_forma') then
    alter table public.asiento_lineas add constraint asiento_lineas_partida_forma
      check (    (partida_tabla is null and partida_id is null)
             or (partida_tabla in ('recibos', 'facturas', 'trabajos_externos')
                 and partida_id ~ '^(0|-?[1-9][0-9]*)$')
             or (partida_tabla = 'cobros'
                 and partida_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'));
  end if;
end $$;

create unique index if not exists periodos_una_apertura on public.periodos (tipo) where tipo = 'apertura';

-- Un documento, un asiento VIVO (el contrato de los puentes de f03):
-- correr un puente dos veces no duplica. Lo hace cumplir el trigger de la
-- cabecera (B.8), con el candado de la cadena puesto: un documento cuyo
-- asiento no está reversado da 23505. «Reversado» es con su reverso de
-- corrección (camino 'reverso'): el reverso automático del día 1 de un
-- devengo es parte del devengo, y no lo deja libre. Y si su asiento ya se
-- reversó, el nuevo dice a cuál sustituye (sustituye_a).
-- Este índice es la segunda red, para el PRIMER asiento de cada
-- documento: aguanta aunque alguien apague los triggers. No cuentan ni
-- los reversos (llevan el origen de su original: así el papel enseña su
-- historia entera) ni los sustitutos (su unicidad es la de sustituye_a).
-- Un borrador anterior lo tenía sin «sustituye_a is null»: se rehace.
do $$
begin
  if to_regclass('public.asientos_origen_unico') is not null
     and pg_get_indexdef(to_regclass('public.asientos_origen_unico')) not like '%sustituye_a IS NULL%' then
    drop index public.asientos_origen_unico;
  end if;
end $$;
create unique index if not exists asientos_origen_unico
  on public.asientos (origen_tabla, origen_id)
  where origen_tabla is not null and camino not in ('reverso', 'reverso_automatico') and sustituye_a is null;


-- ---------------------------------------------------------------------
-- B.5 · La guarda de periodos (MX002). Un TRIGGER y no una policy: frena
-- también al SQL Editor, a fn_cerrar_periodo y a cualquier puente.
--   · Un período nace abierto, cuelga de su año y no va antes de la
--     apertura (el libro empieza el 30-sep-2026) ni antes de un mes ya
--     cerrado. El libro tiene una sola apertura.
--   · El calendario va SEGUIDO: un mes se abre solo si existe el período
--     del día anterior (el mes anterior, o la apertura para el primero).
--     Con un hueco, el mes que falta ya no se podría abrir nunca (hay
--     meses posteriores cerrados) y lo fechado en él no tendría dónde
--     entrar.
--   · Lo único que le pasa después es cerrarse, y solo cuando YA TERMINÓ:
--     a partir del día siguiente a su último día, en hora de Miami (la
--     del reloj, fn_fecha_miami). Como un cierre no se deshace, un toque
--     de más en la pantalla de cierre (cerrar noviembre el 3-nov) dejaría
--     sin sitio todo lo que después se fechara en ese mes, y un año
--     cerrado de golpe dejaría el año sin dónde postear.
--   · Y TODO en orden: un mes se cierra con todos los períodos anteriores
--     ya cerrados, LA APERTURA INCLUIDA. Si la apertura siguiera abierta
--     con octubre cerrado, un asiento fechado el 30-sep (uno nuevo, o el
--     reverso de uno de apertura, que cae el mismo día) cambiaría el saldo
--     de balance de todos los meses ya cerrados sin que nadie escribiera
--     en ellos. Lo que aparezca después en la apertura se corrige en el
--     mes abierto.
--   · La apertura se cierra con su asiento de apertura VIVO dentro (la
--     balanza de QuickBooks al 30-sep, cargada y auditada en f04). Cerrada
--     vacía, la balanza ya no tendría dónde entrar: el 30-sep estaría
--     cerrado y un asiento de apertura con otra fecha no entra.
--   · El año se cierra cuando todos sus meses EXISTEN y están cerrados
--     (no basta con que estén cerrados los que existen), y con el año
--     anterior ya cerrado: los años, también en orden. El cierre del año
--     es lo que dice qué es «ejercicio cerrado» (el saldo vivo de las
--     cuentas de resultados en c1; el arrastre a 3900 de f04): con 2027
--     cerrado y 2026 abierto, el resultado de octubre–diciembre de 2026
--     quedaría fuera del arrastre y el balance de 2028 descuadraría.
--   · Al cerrarse, la base apunta quién, cuándo y el hash de la cadena en
--     ese instante (con el candado de la cadena: nadie postea mientras).
--     El candado sirve solo si la foto se toma DESPUÉS de tomarlo: así
--     pasa en read committed (cada consulta ve lo confirmado hasta ese
--     instante). En repeatable read o serializable la foto sería la del
--     principio de la transacción: un asiento del mes confirmado entre
--     medias quedaría fuera de cadena_al_cerrar y el período saldría
--     «tocado» para siempre (y el ancla que se exporta no casaría con el
--     libro). Por eso un cierre fuera de read committed se rechaza.
--   · Cerrado no se reabre ni se toca. Y ningún período se borra: ni uno
--     cerrado, ni uno abierto y vacío (dejaría un hueco en el calendario).
-- ---------------------------------------------------------------------
create or replace function public.fn_periodos_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_anio     periodos;
  v_abiertos text;
  v_faltan   text;
  v_suma     numeric;
  v_hoy      date;
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003', message = 'Los períodos no se truncan: el libro cuelga de ellos.';
  end if;

  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX002',
      message = format('El período %s no se borra: el calendario del libro va seguido, sin huecos. '
                       'Si se abrió de más, se queda abierto y vacío.', old.periodo);
  end if;

  if tg_op = 'INSERT' then
    if new.estado <> 'abierto' or new.cerrado_el is not null or new.cerrado_por is not null
       or new.cerrado_rol is not null or new.cerrado_conexion is not null or new.cadena_al_cerrar is not null then
      raise exception using errcode = 'MX002',
        message = format('El período %s nace abierto; se cierra después, con fn_cerrar_periodo.', new.periodo);
    end if;
    if new.tipo <> 'anio' then
      select * into v_anio from periodos where periodo = new.anio::text and tipo = 'anio';
      if not found then
        raise exception using errcode = 'MX002',
          message = format('Falta el período del año %s: se abre antes el año (fn_abrir_periodo lo hace solo).', new.anio);
      end if;
      if v_anio.estado = 'cerrado' then
        raise exception using errcode = 'MX002',
          message = format('El año %s ya está cerrado: no se le abren períodos.', new.anio);
      end if;
      if new.paralelo is distinct from v_anio.paralelo then
        raise exception using errcode = 'MX002',
          message = format('%s va con paralelo = %s, igual que su año.', new.periodo, v_anio.paralelo);
      end if;
    end if;
    if new.tipo = 'apertura' and exists (select 1 from periodos where tipo = 'apertura') then
      raise exception using errcode = 'MX002',
        message = format('El libro tiene una sola apertura: no se abre %s.', new.periodo);
    end if;
    if new.tipo = 'mes' then
      if exists (select 1 from periodos where tipo = 'apertura' and desde >= new.desde) then
        raise exception using errcode = 'MX002',
          message = format('El libro empieza en la apertura del 30-sep-2026: no hay meses antes (%s).', new.periodo);
      end if;
      if exists (select 1 from periodos where tipo = 'mes' and estado = 'cerrado' and desde > new.desde) then
        raise exception using errcode = 'MX002',
          message = format('No se abre %s: ya hay meses posteriores cerrados.', new.periodo);
      end if;
      if not exists (select 1 from periodos p
                      where p.tipo in ('mes', 'apertura') and new.desde - 1 between p.desde and p.hasta) then
        raise exception using errcode = 'MX002',
          message = format('No se abre %s: falta %s. El calendario del libro va seguido: los meses se abren en '
                           'orden, sin huecos.', new.periodo, to_char(new.desde - 1, 'YYYY-MM'));
      end if;
    end if;
    return new;
  end if;

  -- UPDATE
  if old.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('El período %s está cerrado: no se reabre ni se toca. Un ajuste va al período abierto '
                       '(tipo ajuste_cpa con afecta_periodo) y una corrección, con fn_reversar.', old.periodo);
  end if;
  if (new.periodo, new.tipo, new.anio, new.desde, new.hasta, new.paralelo, new.creado)
     is distinct from (old.periodo, old.tipo, old.anio, old.desde, old.hasta, old.paralelo, old.creado) then
    raise exception using errcode = 'MX003',
      message = format('El período %s no cambia de forma: lo único que le pasa es cerrarse.', old.periodo);
  end if;
  if new.estado = 'abierto' then
    if new.cerrado_el is not null or new.cerrado_por is not null
       or new.cerrado_rol is not null or new.cerrado_conexion is not null or new.cadena_al_cerrar is not null then
      raise exception using errcode = 'MX002',
        message = format('El sello de cierre de %s lo pone la base al cerrarlo, no se escribe a mano.', old.periodo);
    end if;
    return new;
  end if;

  -- abierto → cerrado
  -- La foto del cierre tiene que ser la de este instante (ver arriba).
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = 'MX002',
      message = format('El período %s se cierra en una transacción read committed (la de siempre), y esta es %s: con '
                       'repeatable read o serializable la foto del cierre sería la del principio de la transacción y '
                       'dejaría fuera lo que entró después.', new.periodo, current_setting('transaction_isolation'));
  end if;
  -- Solo lo que ya terminó, en hora de Miami, con el reloj de este instante.
  v_hoy := fn_fecha_miami(clock_timestamp());
  if new.hasta >= v_hoy then
    raise exception using errcode = 'MX002',
      message = format('El período %s termina el %s: se cierra a partir del día siguiente (%s), hora de Miami. Hoy es %s. '
                       'Un cierre no se deshace.', new.periodo, new.hasta, new.hasta + 1, v_hoy);
  end if;
  if new.tipo in ('mes', 'apertura') then
    select string_agg(p.periodo, ', ' order by p.desde) into v_abiertos
      from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde < new.desde;
    if v_abiertos is not null then
      raise exception using errcode = 'MX002',
        message = format('Todo se cierra en orden: antes de %s hay que cerrar %s.%s', new.periodo, v_abiertos,
                         case when exists (select 1 from periodos p where p.tipo = 'apertura' and p.estado = 'abierto'
                                                                       and p.desde < new.desde)
                              then ' La apertura va primero: carga y audita su asiento de apertura (la balanza de '
                                   'QuickBooks al 30-sep, f04) y después ciérrala. Lo que aparezca más tarde en ella '
                                   'se corrige en el mes abierto.'
                              else '' end);
    end if;
    if new.tipo = 'mes'
       and not exists (select 1 from periodos p
                        where p.tipo in ('mes', 'apertura') and new.desde - 1 between p.desde and p.hasta) then
      raise exception using errcode = 'MX002',
        message = format('No se cierra %s: falta %s en el calendario (hueco).', new.periodo, to_char(new.desde - 1, 'YYYY-MM'));
    end if;
    -- La apertura, con su asiento de apertura vivo (sin reversar) dentro.
    if new.tipo = 'apertura'
       and not exists (select 1 from asientos a
                        where a.periodo = new.periodo and a.tipo = 'apertura' and a.reversa_a is null
                          and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
      raise exception using errcode = 'MX002',
        message = format('Falta el asiento de apertura de %s: se carga desde la balanza de QuickBooks (f04) y se audita '
                         'antes de cerrarla. Cerrada, ya no entraría.', new.periodo);
    end if;
  elsif new.tipo = 'anio' then
    select string_agg(p.periodo, ', ' order by p.desde) into v_abiertos
      from periodos p where p.tipo <> 'anio' and p.anio = new.anio and p.estado = 'abierto';
    if v_abiertos is not null then
      raise exception using errcode = 'MX002',
        message = format('El año %s se cierra cuando todos sus períodos estén cerrados; faltan: %s.', new.periodo, v_abiertos);
    end if;
    select string_agg(to_char(m, 'YYYY-MM'), ', ' order by m) into v_faltan
      from generate_series(
             date_trunc('month', greatest(make_date(new.anio, 1, 1),
                                          coalesce((select max(p.hasta) + 1 from periodos p
                                                     where p.tipo = 'apertura' and p.anio = new.anio),
                                                   make_date(new.anio, 1, 1)))::timestamp),
             make_date(new.anio, 12, 1)::timestamp,
             interval '1 month') as m
     where not exists (select 1 from periodos p where p.tipo = 'mes' and p.desde = m::date);
    if v_faltan is not null then
      raise exception using errcode = 'MX002',
        message = format('El año %s no se cierra: le faltan meses en el calendario (%s).', new.periodo, v_faltan);
    end if;
    -- Los años, en orden (ver arriba).
    select string_agg(p.periodo, ', ' order by p.anio) into v_abiertos
      from periodos p where p.tipo = 'anio' and p.anio < new.anio and p.estado = 'abierto';
    if v_abiertos is not null then
      raise exception using errcode = 'MX002',
        message = format('Los años se cierran en orden: antes de %s hay que cerrar %s. El cierre del año dice qué es '
                         'ejercicio cerrado (lo que f04 arrastra a 3900): con un año anterior abierto, su resultado '
                         'quedaría fuera del arrastre y el balance descuadraría.', new.periodo, v_abiertos);
    end if;
  end if;

  -- El candado de la cadena: mientras se toma la foto, nadie postea.
  perform pg_advisory_xact_lock(820260923);

  select coalesce(sum(l.monto), 0) into v_suma
    from asientos a
    join asiento_lineas l on l.asiento_id = a.id
   where (new.tipo = 'anio' and a.anio = new.anio)
      or (new.tipo <> 'anio' and a.periodo = new.periodo);
  if v_suma <> 0 then
    raise exception using errcode = 'MX001',
      message = format('El período %s no cuadra (diferencia %s): no se cierra.', new.periodo, v_suma);
  end if;

  -- La hora del cierre, del reloj y con el candado puesto (como la de los
  -- asientos): todo asiento del período tiene una hora anterior.
  new.cerrado_el       := clock_timestamp();
  new.cerrado_por      := auth.uid();
  new.cerrado_rol      := fn_rol_llamante();
  -- Si lo cierra una conexión directa del dueño de la base (SQL Editor,
  -- pg_cron, o una función con SUPABASE_DB_URL), de dónde vino.
  new.cerrado_conexion := case when fn_desde_editor() then
                            jsonb_strip_nulls(jsonb_build_object(
                              'application_name', nullif(current_setting('application_name', true), ''),
                              'cliente',          host(inet_client_addr()),
                              'puerto',           inet_client_port()))
                          end;
  new.cadena_al_cerrar := coalesce((select a.hash from asientos a order by a.cadena_pos desc limit 1),
                                   repeat('0', 64));
  return new;
end $$;
revoke execute on function public.fn_periodos_guarda() from public, anon, authenticated, service_role;

create or replace trigger trg_periodos_guarda
  before insert or update or delete on public.periodos
  for each row execute function public.fn_periodos_guarda();

create or replace trigger trg_periodos_sin_truncate
  before truncate on public.periodos
  for each statement execute function public.fn_periodos_guarda();

-- ---------------------------------------------------------------------
-- B.6 · La guarda de contadores. Un número solo avanza de uno en uno: ni
-- se salta, ni se repite, ni se borra la serie. La serie de asientos de
-- un año empieza en cero (su primer asiento es el 1).
--   · El contador de asientos solo lo mueve el trigger de la cabecera
--     (B.8, paso 6), al numerar un asiento: un «update contadores» escrito
--     a mano en el SQL Editor se rechaza, aunque avance de uno en uno. Dos
--     de esos se saltaban dos números, y el que falta ya no se podría
--     postear nunca (el trigger siempre numera último + 1, y los asientos
--     no se borran): un hueco para siempre, que un auditor lee como un
--     asiento borrado.
--   · Y al CONFIRMAR (B.6b) el contador de cada año tiene que ser el
--     número de su último asiento. Caza lo que la guarda de arriba no ve:
--     un «insert … on conflict do nothing» sobre un asiento que ya existe
--     pasa por el trigger de la cabecera, que sube el contador ANTES de
--     que Postgres vea el choque; la fila no entra, el cliente lee
--     «INSERT 0 0», y el número quedaba gastado.
-- ---------------------------------------------------------------------
create or replace function public.fn_contadores_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = 'Los contadores no se truncan: la numeración sin huecos depende de ellos.';
  end if;
  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX003',
      message = format('El contador %s no se borra: la numeración sin huecos depende de él.', old.serie);
  end if;
  if tg_op = 'INSERT' then
    if new.serie like 'asientos-%' and new.ultimo <> 0 then
      raise exception using errcode = 'MX003',
        message = format('La serie %s empieza en cero: el primer asiento del año es el número 1.', new.serie);
    end if;
    return new;
  end if;
  if new.serie is distinct from old.serie or new.ultimo is distinct from old.ultimo + 1 then
    raise exception using errcode = 'MX003',
      message = format('El contador %s solo avanza de uno en uno (%s → %s): saltar o repetir un número rompe la numeración sin huecos.',
                       old.serie, old.ultimo, new.ultimo);
  end if;
  -- Desde dentro del trigger de la cabecera, esta guarda corre anidada (2);
  -- un update escrito a mano, no (1).
  if old.serie like 'asientos-%' and pg_trigger_depth() < 2 then
    raise exception using errcode = 'MX003',
      message = format('El contador %s solo lo mueve la base al numerar un asiento: un número gastado a mano ya no tendría '
                       'asiento, y la numeración quedaría con un hueco para siempre.', old.serie);
  end if;
  return new;
end $$;
revoke execute on function public.fn_contadores_guarda() from public, anon, authenticated, service_role;

create or replace trigger trg_contadores_guarda
  before insert or update or delete on public.contadores
  for each row execute function public.fn_contadores_guarda();

create or replace trigger trg_contadores_sin_truncate
  before truncate on public.contadores
  for each statement execute function public.fn_contadores_guarda();

-- ---------------------------------------------------------------------
-- B.6b · Al confirmar, cada contador de asientos que se movió en la
-- transacción está en el número de su último asiento (MX003). Diferido: al
-- final, cuando ya se sabe qué asientos entraron de verdad.
-- SECURITY DEFINER porque corre al CONFIRMAR, cuando ya no se está dentro
-- de fn_postear: el trigger corre con el rol de la sesión (authenticated,
-- por la API), que bajo RLS no vería los asientos que no son suyos (un
-- puente disparado por un trabajador). Sin grant a nadie: solo lo llama el
-- trigger. (Un trigger de restricción no admite «or replace»: se borra y
-- se crea.)
-- ---------------------------------------------------------------------
create or replace function public.fn_contadores_al_confirmar()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ultimo bigint;
  v_max    bigint;
begin
  if new.serie like 'asientos-%' then
    select c.ultimo into v_ultimo from contadores c where c.serie = new.serie;
    select coalesce(max(a.secuencia), 0) into v_max
      from asientos a
     where a.anio = split_part(new.serie, '-', 2)::int;
    if v_ultimo is distinct from v_max then
      raise exception using errcode = 'MX003',
        message = format('El contador %s va en %s y el último asiento de %s es el %s: un número no avanza sin su asiento '
                         '(la numeración quedaría con un hueco para siempre). No se confirma.',
                         new.serie, v_ultimo, split_part(new.serie, '-', 2), v_max);
    end if;
  end if;
  return null;
end $$;
revoke execute on function public.fn_contadores_al_confirmar() from public, anon, authenticated, service_role;

drop trigger if exists trg_contadores_al_confirmar on public.contadores;
create constraint trigger trg_contadores_al_confirmar
  after insert or update on public.contadores
  deferrable initially deferred
  for each row execute function public.fn_contadores_al_confirmar();


-- ---------------------------------------------------------------------
-- B.7 · Cada línea, al entrar (vale para TODO camino: fn_postear, un
-- puente, o un insert a mano en el SQL Editor).
--   · MX003: una línea solo entra ANTES que su cabecera. Con la cabecera
--     ya puesta, el asiento está sellado: ni una línea más. Aquí se mira
--     con lo que ve la transacción que inserta la línea; si la cabecera
--     la está poniendo OTRA sesión que aún no confirma, no se ve. Por eso
--     se vuelve a mirar al confirmar (B.7b).
--   · MX004: la cuenta existe, está activa y es imputable.
--   · MX006: las dimensiones que pide la cuenta (cuentas.regla_obra y
--     regla_cost_code); cost_code, co y fase solo con obra; la obra y el
--     código existen.
-- La escala del monto (MX005) no se puede mirar aquí: numeric(14,2) ya
-- redondeó al guardar. La mira fn_postear_interno leyendo el texto; un
-- insert directo queda marcado en su asiento (B.8, «insert_directo»).
-- ---------------------------------------------------------------------
create or replace function public.fn_asiento_lineas_al_insertar()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c     cuentas;
  v_tabla text;
  v_tipo  text;
  v_hay   boolean;
begin
  if exists (select 1 from asientos where id = new.asiento_id) then
    raise exception using errcode = 'MX003',
      message = 'Ese asiento ya está sellado: no admite líneas nuevas. Se corrige con fn_reversar y un asiento nuevo.';
  end if;

  select * into v_c from cuentas where codigo = new.cuenta;
  if not found then
    raise exception using errcode = 'MX004',
      message = format('Línea %s: la cuenta %s no existe en el plan de cuentas.', new.orden, coalesce(new.cuenta, '(vacía)'));
  end if;

  -- Las líneas de un reverso copian, con el signo cambiado, un asiento que
  -- ya pasó estas reglas cuando entró. No se juzgan otra vez contra el plan
  -- de hoy: una cuenta inactivada o una regla afinada después no pueden
  -- impedir corregir el pasado. A cambio, el trigger de la cabecera exige
  -- que sean el espejo exacto de su original (MX007).
  if new.asiento_id::text = coalesce(current_setting('mx_libro.reverso_de', true), '') then
    return new;
  end if;

  if not v_c.activa then
    raise exception using errcode = 'MX004',
      message = format('Línea %s: la cuenta %s (%s) está inactiva: ya no recibe asientos.', new.orden, v_c.codigo, v_c.nombre);
  end if;
  if not v_c.imputable then
    raise exception using errcode = 'MX004',
      message = format('Línea %s: la cuenta %s (%s) es de grupo: el asiento va a una de sus subcuentas.', new.orden, v_c.codigo, v_c.nombre);
  end if;

  if new.proyecto_id is null and (new.cost_code is not null or new.co is not null or new.fase is not null) then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: cost_code, co y fase solo van en una línea con obra (proyecto_id).', new.orden);
  end if;
  if v_c.regla_obra = 'obligatoria' and new.proyecto_id is null then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: la cuenta %s (%s) exige obra (proyecto_id).', new.orden, v_c.codigo, v_c.nombre);
  elsif v_c.regla_obra = 'prohibida' and new.proyecto_id is not null then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: la cuenta %s (%s) no va por obra: quita proyecto_id.', new.orden, v_c.codigo, v_c.nombre);
  end if;
  if v_c.regla_cost_code = 'obligatoria' and new.cost_code is null then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: la cuenta %s (%s) exige cost code.', new.orden, v_c.codigo, v_c.nombre);
  elsif v_c.regla_cost_code = 'prohibida' and new.cost_code is not null then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: la cuenta %s (%s) no lleva cost code.', new.orden, v_c.codigo, v_c.nombre);
  end if;
  if new.proyecto_id is not null and not exists (select 1 from proyectos where id = new.proyecto_id) then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: la obra %s no existe.', new.orden, new.proyecto_id);
  end if;
  if new.cost_code is not null and not exists (select 1 from codigos_partida where codigo = new.cost_code) then
    raise exception using errcode = 'MX006',
      message = format('Línea %s: el cost code %s no existe en codigos_partida.', new.orden, new.cost_code);
  end if;
  -- El tercero y la partida (f03) tienen que existir: una partida que no
  -- apunta a ningún papel quedaría abierta para siempre, y un tercero que
  -- no existe no tiene a quién pagarle. Su FORMA ya la miran las
  -- restricciones de la tabla (B.4). Las tablas de proveedores y de cobros
  -- llegan con c3: antes de pegarlo, una línea no los puede nombrar.
  if new.tercero_tipo is not null then
    v_tabla := case new.tercero_tipo when 'proveedor' then 'proveedores' when 'empleado' then 'perfiles' end;
    if v_tabla is null or to_regclass('public.' || v_tabla) is null then
      raise exception using errcode = 'MX006',
        message = format('Línea %s: el tercero «%s» no es de un tipo que el libro conozca todavía.', new.orden, new.tercero_tipo);
    end if;
    -- El id se compara en su tipo (uuid), para que use la llave primaria.
    select format_type(a.atttypid, null) into v_tipo
      from pg_attribute a where a.attrelid = to_regclass('public.' || v_tabla) and a.attname = 'id' and not a.attisdropped;
    execute format('select exists (select 1 from public.%I where id = $1::%s)', v_tabla, v_tipo) into v_hay using new.tercero_id;
    if not v_hay then
      raise exception using errcode = 'MX006',
        message = format('Línea %s: el %s %s no existe.', new.orden, new.tercero_tipo, new.tercero_id);
    end if;
  end if;
  if new.partida_tabla is not null then
    if to_regclass('public.' || new.partida_tabla) is null then
      raise exception using errcode = 'MX006',
        message = format('Línea %s: la partida es de la tabla %s, que no existe.', new.orden, new.partida_tabla);
    end if;
    select format_type(a.atttypid, null) into v_tipo
      from pg_attribute a where a.attrelid = to_regclass('public.' || new.partida_tabla) and a.attname = 'id' and not a.attisdropped;
    if v_tipo is null then
      raise exception using errcode = 'MX006',
        message = format('Línea %s: la tabla %s no tiene columna id: no puede ser una partida.', new.orden, new.partida_tabla);
    end if;
    execute format('select exists (select 1 from public.%I where id = $1::%s)', new.partida_tabla, v_tipo)
       into v_hay using new.partida_id;
    if not v_hay then
      raise exception using errcode = 'MX006',
        message = format('Línea %s: la partida %s %s no existe: una línea solo abre o salda un papel que está.',
                         new.orden, new.partida_tabla, new.partida_id);
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_asiento_lineas_al_insertar() from public, anon, authenticated, service_role;

create or replace trigger trg_asiento_lineas_al_insertar
  before insert on public.asiento_lineas
  for each row execute function public.fn_asiento_lineas_al_insertar();

-- ---------------------------------------------------------------------
-- B.7b · El sello se vuelve a mirar AL CONFIRMAR (MX003). La carrera que
-- cierra: la sesión A pone sus líneas y su cabecera y todavía no
-- confirma; la sesión B cuelga otra línea del mismo asiento. El trigger
-- de B.7 de la sesión B no ve la cabecera de A, la FK diferida la
-- encuentra al confirmar B, y quedaría sellado un asiento que no cuadra y
-- que ya no se puede corregir (update y delete dan MX003; su reverso
-- también descuadra). Aquí, al confirmar, si la cabecera ya existe, su
-- hash tiene que seguir saliendo de sus líneas: si llegó una de más, no
-- sale, y la transacción de la línea tardía no confirma.
-- En el camino normal (líneas y cabecera en la misma transacción) el
-- hash sale igual y no pasa nada. Con aislamiento repeatable read o
-- serializable, la cabecera de otra sesión no se ve ni al confirmar, y es
-- la FK diferida la que para la línea.
-- SECURITY DEFINER, y no es un detalle: un trigger diferido corre al
-- CONFIRMAR, cuando fn_postear (SECURITY DEFINER) ya terminó, y lo hace
-- con el rol que tiene la sesión en ese momento. Por la API ese rol es
-- authenticated, que no puede ejecutar fn_asiento_canonico (B.3) y que,
-- bajo RLS, no vería las cabeceras que no son suyas. Sin esto, todo
-- posteo y todo reverso que llegara desde la app se abortaba al confirmar
-- (42501), y la app le decía a Edgar «tu usuario no tiene permiso». Sin
-- grant a nadie: solo lo llama el trigger.
-- (Un trigger de restricción no admite «or replace»: se borra y se crea.)
-- ---------------------------------------------------------------------
create or replace function public.fn_asiento_lineas_sello_al_confirmar()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_a asientos;
begin
  select * into v_a from asientos where id = new.asiento_id;
  if found and v_a.hash is distinct from encode(sha256(convert_to(fn_asiento_canonico(v_a), 'UTF8')), 'hex') then
    raise exception using errcode = 'MX003',
      message = format('El asiento %s ya estaba sellado cuando llegó la línea %s: no admite líneas nuevas. '
                       'Se corrige con fn_reversar y un asiento nuevo.', v_a.numero, new.orden);
  end if;
  return null;
end $$;
revoke execute on function public.fn_asiento_lineas_sello_al_confirmar() from public, anon, authenticated, service_role;

drop trigger if exists trg_asiento_lineas_sello_diferido on public.asiento_lineas;
create constraint trigger trg_asiento_lineas_sello_diferido
  after insert on public.asiento_lineas
  deferrable initially deferred
  for each row execute function public.fn_asiento_lineas_sello_al_confirmar();

-- ---------------------------------------------------------------------
-- B.8 · La cabecera, al entrar. Es el corazón del libro y vale para TODO
-- camino. En este orden:
--   0. Quién: a mano (o por la IA, f07) solo el dueño o el SQL Editor. Y
--      la forma del ajuste del CPA (22023): afecta_periodo va solo con
--      tipo ajuste_cpa, y un ajuste_cpa lleva motivo.
--   1. Fecha y período (MX002):
--      · ni tan lejos en el futuro que sea un error de dedo: el tope es
--        el último día del mes siguiente al mes abierto más antiguo, o 45
--        días después de hoy en Miami (lo que quede más lejos). Un año mal
--        tecleado (2027 por 2026) o un 01/05 mal leído caerían en un mes
--        abierto de 2027 sin que nadie los viera, y el primero se llevaría
--        el número 2027-000001 de los libros oficiales. Los reversos no
--        miran el tope (el automático cae el día 1 del mes siguiente, a
--        propósito);
--      · el período lo pone la base según la fecha, nunca quien inserta.
--        Se toma «for share»: si alguien lo está cerrando, uno espera al
--        otro y el asiento no se cuela en un mes cerrado. Si no hay
--        período, el mensaje dice por qué: antes de la apertura, eso vive
--        en QuickBooks; después del último mes, se abre el mes;
--      · un período cerrado dice qué hacer, según cuál sea: la apertura,
--        el ajuste a la apertura (no se reversa); un mes de un ejercicio
--        anterior al abierto, el ajuste de ese ejercicio (fn_reversar lo
--        hace solo para una corrección); un mes del año en curso, lo de
--        siempre (el documento tardío, al primer día del mes abierto; la
--        corrección, con fn_reversar). Antes decía lo de siempre en los
--        tres casos, y en los dos primeros llevaba a un camino equivocado;
--      · un asiento de apertura va solo en la apertura, sus reversos
--        también: el reverso de uno de apertura va el mismo día, con la
--        apertura abierta. Cerrada, MX007: se ajusta, no se reversa.
--   2. Cuadre (MX001) con las líneas, que ya entraron; y la apertura,
--      solo con cuentas de balance (MX006). Lo mismo un ajuste del CPA que
--      afecta a la apertura: lo de antes del 30-sep ya está dentro de 3900
--      (vino de QuickBooks), así que una cuenta de resultados ahí es
--      siempre un error de clasificación, y caería en el resultado del
--      paralelo que se compara contra QuickBooks.
--   3. Desde aquí, el candado de la cadena: un asiento a la vez en todo
--      el libro (se suelta al terminar la transacción).
--   4. Reverso (MX007): existe el original, no tiene ya un reverso de ese
--      mismo camino, no va antes, y las líneas son su espejo exacto. Lleva
--      el tipo de su original, salvo la corrección (camino 'reverso') de
--      un asiento normal de un ejercicio ANTERIOR al del reverso: esa va
--      como ajuste de ese ejercicio (tipo ajuste_cpa, afecta_periodo = el
--      período del original), para que no caiga en el resultado del año
--      en curso (ver la cabecera, CÓMO SE ABRE Y SE CIERRA). Un
--      reverso no se reversa, con UNA excepción: el reverso automático
--      del día 1 de un devengo que se acaba de corregir en su mes. Así se
--      corrige un devengo (el ajuste de WIP de f10, el devengo de horas de
--      f03) antes de cerrar su mes: su reverso de corrección va en su
--      misma fecha, y el reverso de su reverso automático, el día 1; si
--      no, el mes siguiente deshacería dos veces lo mismo. Los dos entran
--      juntos (fn_reversar_interno); al confirmar se comprueba (B.10).
--      Con el mes del devengo ya cerrado no hay nada que corregir: ya se
--      deshizo solo el día 1.
--   5. Documento (23505 y MX007): un documento de origen tiene UN asiento
--      vivo, es decir, sin su reverso de corrección (el automático del
--      día 1 no cuenta: es parte del devengo). Si su asiento ya se
--      reversó, el nuevo dice a cuál sustituye (sustituye_a), y ese tiene
--      que ser del mismo documento y estar reversado. Si el sustituido es
--      de un ejercicio anterior, el sustituto también es un ajuste de ese
--      ejercicio (tipo ajuste_cpa, con afecta_periodo en ese año), como su
--      reverso: es la corrección TARDÍA de un papel de ese año. Salvo que
--      el papel ya no sea de ese año: un puente dice la fecha de su papel
--      en procedencia.fecha_documento (AAAA-MM-DD), y si esa fecha es del
--      año del sustituto, el sustituto es un asiento normal de su fecha
--      (la fecha del ticket se corrigió del 20-dic al 4-ene: el gasto es
--      de enero, y como ajuste del año viejo caería en el año fiscal
--      equivocado; y sin esta salida el papel quedaba fuera de los dos
--      años). Solo el camino puente: un sustituto a mano sigue la regla.
--   6. Número: contadores, «select … for update», DESPUÉS de validar. Si
--      algo falla después, el rollback deshace también el contador: no
--      hay hueco (una secuencia de Postgres sí lo dejaría).
--   7. El sello: quién, con qué rol y cuándo (la hora del reloj, con el
--      candado puesto), puestos por la base. En la procedencia, además:
--      · «conexion» (application_name, dirección y puerto del cliente)
--        cuando entra por una conexión directa del dueño de la base (el
--        SQL Editor, pg_cron, o una función con SUPABASE_DB_URL): ayuda a
--        distinguir quién fue;
--      · «puerta»: 'insert_directo' cuando las líneas NO entraron por
--        fn_postear_interno ni por fn_reversar_interno. Esas líneas no
--        pasaron la mirada de la escala: numeric(14,2) redondeó sus
--        montos a centavos sin avisar. El auditor las encuentra así.
--   8. El eslabón: posición, hash anterior y hash.
-- Todas las columnas de sistema se pisan: nadie elige su número, su
-- período, su sello ni su hash, ni siquiera el SQL Editor.
-- ---------------------------------------------------------------------
create or replace function public.fn_asientos_al_insertar()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_per    periodos;
  v_afecta periodos;
  v_orig   asientos;
  v_sust   asientos;
  v_n      int;
  v_suma   numeric;
  v_debe   numeric;
  v_serie  text;
  v_sec    bigint;
  v_cabeza asientos;
  v_hoy    date;
  v_tope   date;
  v_desde  date;
  v_vivos  text;
  v_libre  text;
  v_abierto_anio int;
  v_ej     int;
  v_doc_anio int;
begin
  -- 0. Quién, y la forma del ajuste del CPA.
  if new.camino in ('mano', 'ia') and not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño postea asientos a mano.';
  end if;
  if coalesce(current_setting('mx_libro.reverso_de', true), '') = new.id::text and new.reversa_a is null then
    raise exception using errcode = 'MX007',
      message = 'Las líneas entraron como las de un reverso, pero la cabecera no dice qué asiento reversa.';
  end if;
  if new.afecta_periodo is not null and new.tipo is distinct from 'ajuste_cpa' then
    raise exception using errcode = '22023',
      message = 'afecta_periodo va solo con un ajuste del CPA (tipo ajuste_cpa): dice a qué período cerrado corresponde.';
  end if;
  if new.tipo = 'ajuste_cpa' and new.afecta_periodo is null then
    raise exception using errcode = '22023',
      message = 'Un ajuste del CPA dice a qué período cerrado afecta (afecta_periodo), p. ej. ''2026-12''.';
  end if;
  if new.tipo = 'ajuste_cpa' and coalesce(btrim(new.motivo), '') = '' then
    raise exception using errcode = '22023',
      message = 'Un ajuste del CPA dice por qué (motivo), p. ej. «Ajuste del CPA a 2026 según la declaración».';
  end if;

  -- 1. Fecha y período.
  if new.camino not in ('reverso', 'reverso_automatico') then
    v_hoy  := fn_fecha_miami(now());
    v_tope := greatest(v_hoy + 45,
                       coalesce((select (date_trunc('month', min(p.desde)::timestamp) + interval '2 month')::date - 1
                                   from periodos p where p.tipo = 'mes' and p.estado = 'abierto'),
                                v_hoy + 45));
    if new.fecha_contable > v_tope then
      raise exception using errcode = 'MX002',
        message = format('Fecha en el futuro lejano: el %s pasa del tope del %s (hoy es %s en Miami). ¿El año o el mes '
                         'están bien? Un asiento se postea cuando llega su fecha.', new.fecha_contable, v_tope, v_hoy);
    end if;
  end if;
  select * into v_per
    from periodos p
   where p.tipo <> 'anio' and new.fecha_contable between p.desde and p.hasta
     for share;
  if not found then
    select min(p.desde) into v_desde from periodos p where p.tipo <> 'anio';
    if new.fecha_contable < v_desde then
      raise exception using errcode = 'MX002',
        message = format('El %s es anterior a la apertura del libro (%s): eso vive en QuickBooks y no entra en este '
                         'libro.', new.fecha_contable, v_desde);
    end if;
    raise exception using errcode = 'MX002',
      message = format('No hay período contable para el %s: el mes todavía no se abrió. Se abre con '
                       'fn_abrir_periodo(''AAAA-MM''), en orden.', coalesce(new.fecha_contable::text, '(sin fecha)'));
  end if;
  if v_per.estado <> 'abierto' then
    -- Cerrado. Qué hacer depende de cuál es (ver arriba).
    if v_per.tipo = 'apertura' then
      raise exception using errcode = 'MX002',
        message = format('La apertura (%s) ya está cerrada: nadie escribe ahí, y su asiento ya no se reversa. Lo que '
                         'faltó o sobró en ella se corrige en el mes abierto con un ajuste a la apertura: tipo '
                         'ajuste_cpa, afecta_periodo = ''%s'', con su motivo, solo con cuentas de balance y contra 3900 '
                         '(utilidades retenidas), nunca a un gasto o un ingreso del paralelo.', v_per.periodo, v_per.periodo);
    end if;
    select min(p.anio) into v_abierto_anio from periodos p where p.tipo = 'mes' and p.estado = 'abierto';
    if v_per.anio < v_abierto_anio then
      raise exception using errcode = 'MX002',
        message = format('El período %s está cerrado y es de %s, un ejercicio anterior al abierto (%s): nadie escribe '
                         'ahí. Lo que le falte a %s (un documento tardío, un error) entra en el mes abierto como ajuste '
                         'de ese ejercicio: tipo ajuste_cpa, afecta_periodo = ''%s'', con su motivo; así no cae en el '
                         'resultado de %s. Para corregir un asiento, fn_reversar: marca así su reverso, solo.',
                         v_per.periodo, v_per.anio, v_abierto_anio, v_per.anio, v_per.periodo, v_abierto_anio);
    end if;
    raise exception using errcode = 'MX002',
      message = format('El período %s está cerrado: nadie escribe ahí. Un documento tardío va al primer día del '
                       'período abierto; una corrección, con fn_reversar.', v_per.periodo);
  end if;
  if v_per.tipo = 'apertura' and new.tipo <> 'apertura' then
    raise exception using errcode = 'MX002',
      message = format('El período %s solo admite el asiento de apertura y sus reversos.', v_per.periodo);
  end if;
  -- Un asiento de apertura, solo en la apertura; sus reversos también (con
  -- la apertura abierta, fn_reversar lo pone el mismo día).
  if new.tipo = 'apertura' and v_per.tipo <> 'apertura' then
    if new.reversa_a is not null then
      raise exception using errcode = 'MX007',
        message = format('El reverso de un asiento de apertura va el mismo día de la apertura, con la apertura abierta. '
                         'Cerrada, ya no se reversa: lo que faltó o sobró se corrige en el mes abierto con un ajuste a la '
                         'apertura (tipo ajuste_cpa, afecta_periodo = ''%s''), solo con cuentas de balance, contra 3900.',
                         coalesce((select p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
                                  'la apertura'));
    end if;
    raise exception using errcode = 'MX002',
      message = 'Un asiento de apertura va fechado el día de la apertura (30-sep-2026).';
  end if;
  if new.tipo = 'ajuste_cpa' then
    select * into v_afecta from periodos where periodo = new.afecta_periodo;
    if not found or v_afecta.estado <> 'cerrado' or v_afecta.hasta >= new.fecha_contable then
      raise exception using errcode = 'MX002',
        message = format('Un ajuste del CPA afecta a un período ya cerrado y anterior a su fecha, y %s no lo es. '
                         'Si el período sigue abierto, el ajuste va dentro de él como asiento normal.',
                         coalesce(new.afecta_periodo, '(ninguno)'));
    end if;
  end if;
  new.periodo := v_per.periodo;
  new.anio    := extract(year from new.fecha_contable)::int;

  -- 2. Cuadre.
  select count(*), coalesce(sum(l.monto), 0), coalesce(sum(l.monto) filter (where l.monto > 0), 0)
    into v_n, v_suma, v_debe
    from asiento_lineas l
   where l.asiento_id = new.id;
  if v_n < 2 then
    raise exception using errcode = 'MX001',
      message = format('Un asiento lleva al menos dos líneas y este trae %s (las líneas entran antes que la cabecera).', v_n);
  end if;
  if v_suma <> 0 then
    raise exception using errcode = 'MX001',
      message = format('Descuadrado: debe %s, haber %s, diferencia %s. No entra.', v_debe, v_debe - v_suma, v_suma);
  end if;
  -- La apertura es balance únicamente (f04): los resultados de enero a
  -- septiembre de 2026 son de QuickBooks y llegan ya dentro del capital.
  if new.tipo = 'apertura' and exists (
       select 1 from asiento_lineas l join cuentas c on c.codigo = l.cuenta
        where l.asiento_id = new.id and c.tipo not in ('activo', 'pasivo', 'capital')) then
    raise exception using errcode = 'MX006',
      message = 'El asiento de apertura es balance únicamente: solo cuentas de activo, pasivo y capital.';
  end if;
  -- Un ajuste del CPA a la apertura, igual (v_afecta se leyó en el paso 1).
  if new.tipo = 'ajuste_cpa' and v_afecta.tipo = 'apertura' and exists (
       select 1 from asiento_lineas l join cuentas c on c.codigo = l.cuenta
        where l.asiento_id = new.id and c.tipo not in ('activo', 'pasivo', 'capital')) then
    raise exception using errcode = 'MX006',
      message = format('Un ajuste a la apertura (%s) es balance únicamente: lo de antes del 30-sep va contra 3900 '
                       '(utilidades retenidas), nunca a un gasto o un ingreso del paralelo.', new.afecta_periodo);
  end if;

  -- 3. El candado de la cadena.
  perform pg_advisory_xact_lock(820260923);

  -- 4. Reverso.
  if new.reversa_a is not null then
    select * into v_orig from asientos where id = new.reversa_a;
    if not found then
      raise exception using errcode = 'MX007', message = 'El asiento que dice reversar no existe.';
    end if;
    if v_orig.reversa_a is not null then
      -- La única excepción: anular el reverso automático de un devengo
      -- cuyo reverso de corrección ya entró (en su mismo mes, paso de abajo),
      -- en la misma fecha que ese reverso automático.
      if not (v_orig.camino = 'reverso_automatico' and new.camino = 'reverso'
              and exists (select 1 from asientos r where r.reversa_a = v_orig.reversa_a and r.camino = 'reverso')) then
        raise exception using errcode = 'MX007',
          message = format('%s es un reverso: un reverso no se reversa. La re-corrección es un asiento nuevo.%s', v_orig.numero,
                           case when v_orig.camino = 'reverso_automatico'
                                then ' Para corregir el devengo se reversa el devengo (fn_reversar): eso anula también '
                                     'su reverso del día 1.'
                                else '' end);
      end if;
      if new.fecha_contable <> v_orig.fecha_contable then
        raise exception using errcode = 'MX007',
          message = format('La anulación del reverso automático %s va en su misma fecha (%s).', v_orig.numero, v_orig.fecha_contable);
      end if;
    end if;
    if exists (select 1 from asientos r where r.reversa_a = new.reversa_a and r.camino = new.camino)
       or (new.camino = 'reverso_automatico' and exists (select 1 from asientos r where r.reversa_a = new.reversa_a)) then
      raise exception using errcode = 'MX007', message = format('%s ya tiene su reverso.', v_orig.numero);
    end if;
    if new.fecha_contable < v_orig.fecha_contable then
      raise exception using errcode = 'MX007', message = 'Un reverso no va antes que su original.';
    end if;
    -- El tipo: el de su original, salvo la corrección de un asiento normal
    -- de un ejercicio anterior, que es un ajuste de ese ejercicio.
    if new.camino = 'reverso' and v_orig.reversa_a is null and v_orig.tipo = 'normal' and new.anio > v_orig.anio then
      if new.tipo is distinct from 'ajuste_cpa' or new.afecta_periodo is distinct from v_orig.periodo then
        raise exception using errcode = 'MX007',
          message = format('%s es de %s, un ejercicio anterior al del reverso (%s): su reverso va como ajuste de ese '
                           'ejercicio (tipo ajuste_cpa, afecta_periodo = ''%s''), para que no caiga en el resultado de '
                           '%s. fn_reversar lo hace solo.', v_orig.numero, v_orig.anio, new.anio, v_orig.periodo, new.anio);
      end if;
    elsif new.tipo is distinct from v_orig.tipo or new.afecta_periodo is distinct from v_orig.afecta_periodo then
      raise exception using errcode = 'MX007', message = 'Un reverso conserva el tipo de su original.';
    end if;
    if new.camino = 'reverso_automatico'
       and (not v_orig.reversible
            or new.fecha_contable <> (date_trunc('month', v_orig.fecha_contable::timestamp) + interval '1 month')::date) then
      raise exception using errcode = 'MX007',
        message = 'El reverso automático es el de un asiento reversible y va el día 1 del mes siguiente.';
    end if;
    -- Un devengo se corrige DENTRO de su mes: su reverso va en su misma
    -- fecha. Con su mes cerrado ya se deshizo solo el día 1.
    if new.camino = 'reverso' and v_orig.reversible and new.fecha_contable <> v_orig.fecha_contable then
      raise exception using errcode = 'MX007',
        message = format('%s es un devengo reversible: se corrige dentro de su mes, con su reverso en su misma fecha (%s). '
                         'Con su mes ya cerrado, ya se deshizo solo el día 1: una diferencia se corrige con un asiento '
                         'en el mes abierto.', v_orig.numero, v_orig.fecha_contable);
    end if;
    -- El espejo incluye el tercero y la partida (f03): un reverso que
    -- saldara OTRA partida dejaría abierta la suya y cerraría una ajena.
    if exists (
         (select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                 l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
            from asiento_lineas l where l.asiento_id = v_orig.id
          except all
          select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                 l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
            from asiento_lineas l where l.asiento_id = new.id)
         union all
         (select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                 l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
            from asiento_lineas l where l.asiento_id = new.id
          except all
          select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                 l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
            from asiento_lineas l where l.asiento_id = v_orig.id)) then
      raise exception using errcode = 'MX007',
        message = format('Un reverso es el espejo exacto de su original (%s): las mismas cuentas, dimensiones, '
                         'terceros y partidas, con el signo cambiado.', v_orig.numero);
    end if;
  end if;

  -- 5. Documento: un asiento vivo por documento de origen. Con el candado
  --    de la cadena puesto: dos sesiones con el mismo papel no pasan las
  --    dos (la segunda ve la primera cuando le toca el candado).
  if new.origen_tabla is not null and new.camino not in ('reverso', 'reverso_automatico') then
    select string_agg(a.numero, ', ' order by a.cadena_pos) into v_vivos
      from asientos a
     where a.origen_tabla = new.origen_tabla and a.origen_id = new.origen_id
       and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso');
    if v_vivos is not null then
      raise exception using errcode = '23505',
        message = format('El documento %s %s ya tiene su asiento vivo (%s): no se postea dos veces. Si está mal, se '
                         'reversa con fn_reversar (un devengo, dentro de su mes: eso anula también su reverso del '
                         'día 1) y el asiento nuevo dice a cuál sustituye (sustituye_a).',
                         new.origen_tabla, new.origen_id, v_vivos);
    end if;
    if new.sustituye_a is null then
      select a.numero || ' (id ' || a.id || ')' into v_libre
        from asientos a
       where a.origen_tabla = new.origen_tabla and a.origen_id = new.origen_id
         and a.camino not in ('reverso', 'reverso_automatico')
         and not exists (select 1 from asientos s2 where s2.sustituye_a = a.id)
       order by a.cadena_pos desc
       limit 1;
      if v_libre is not null then
        raise exception using errcode = 'MX007',
          message = format('El documento %s %s ya tuvo asiento, reversado: %s. El nuevo dice que lo sustituye '
                           '(sustituye_a).', new.origen_tabla, new.origen_id, v_libre);
      end if;
    else
      select * into v_sust from asientos where id = new.sustituye_a;
      if not found
         or v_sust.origen_tabla is distinct from new.origen_tabla or v_sust.origen_id is distinct from new.origen_id
         or v_sust.camino in ('reverso', 'reverso_automatico') then
        raise exception using errcode = 'MX007',
          message = format('sustituye_a apunta a un asiento que no es de este documento (%s %s), o a un reverso.',
                           new.origen_tabla, new.origen_id);
      end if;
      if not exists (select 1 from asientos r where r.reversa_a = v_sust.id and r.camino = 'reverso') then
        raise exception using errcode = 'MX007',
          message = format('%s todavía no se reversó: primero fn_reversar, después el asiento que lo sustituye.',
                           v_sust.numero);
      end if;
      select a.numero into v_libre from asientos a where a.sustituye_a = v_sust.id;
      if v_libre is not null then
        raise exception using errcode = 'MX007',
          message = format('%s ya tiene su sustituto (%s): si también estaba mal, se reversa ese y se sustituye a él.',
                           v_sust.numero, v_libre);
      end if;
      -- De un ejercicio anterior (el de su afecta_periodo, si ya era un
      -- ajuste): el sustituto es un ajuste de ese ejercicio, como su
      -- reverso. v_afecta se leyó en el paso 1 (solo si es ajuste_cpa).
      -- Salvo que el PAPEL ya sea del año del sustituto (la fecha que el
      -- puente dejó en procedencia.fecha_documento): entonces no es la
      -- corrección tardía de un papel viejo, es un papel del año nuevo, y
      -- va como asiento normal de su fecha. Solo se lee el año (los cuatro
      -- primeros caracteres): una fecha mal formada no hace fallar al libro,
      -- deja la regla de siempre.
      v_ej := coalesce((select p.anio from periodos p where p.periodo = v_sust.afecta_periodo), v_sust.anio);
      v_doc_anio := case when new.camino = 'puente'
                              and coalesce(new.procedencia->>'fecha_documento', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                         then left(new.procedencia->>'fecha_documento', 4)::int end;
      if v_ej < new.anio and (new.tipo is distinct from 'ajuste_cpa' or v_afecta.anio is distinct from v_ej)
         and not (new.tipo = 'normal' and v_doc_anio is not distinct from new.anio) then
        raise exception using errcode = 'MX007',
          message = format('%s, al que este sustituye, es del ejercicio %s, anterior a este (%s): el sustituto es un '
                           'ajuste de ese ejercicio, como su reverso (tipo ajuste_cpa, afecta_periodo = un período '
                           'cerrado de %s, p. ej. ''%s'', con su motivo). Así no cae en el resultado de %s.',
                           v_sust.numero, v_ej, new.anio, v_ej, coalesce(v_sust.afecta_periodo, v_sust.periodo), new.anio);
      end if;
    end if;
  elsif new.sustituye_a is not null then
    raise exception using errcode = 'MX007',
      message = 'Un sustituto dice de qué documento sale (origen_tabla y origen_id): el mismo del asiento que sustituye.';
  end if;

  -- 6. Número correlativo, sin huecos, por año.
  v_serie := 'asientos-' || new.anio;
  insert into contadores (serie, ultimo) values (v_serie, 0) on conflict (serie) do nothing;
  select c.ultimo + 1 into v_sec from contadores c where c.serie = v_serie for update;
  update contadores set ultimo = v_sec where serie = v_serie;
  new.secuencia := v_sec;
  new.numero    := new.anio::text || '-' || lpad(v_sec::text, 6, '0');

  -- 7. El sello. La hora es la del reloj en este instante, con el candado
  --    ya puesto, y no now() (que es la hora en que EMPEZÓ la transacción):
  --    así las horas siguen el orden de la cadena y se pueden comparar con
  --    la hora de cierre de un período, tomada igual.
  new.creado_el  := clock_timestamp();
  new.usuario_id := auth.uid();
  new.rol_bd     := fn_rol_llamante();
  if fn_desde_editor() then
    new.procedencia := new.procedencia || jsonb_build_object('conexion', jsonb_strip_nulls(jsonb_build_object(
                         'application_name', nullif(current_setting('application_name', true), ''),
                         'cliente',          host(inet_client_addr()),
                         'puerto',           inet_client_port())));
  end if;
  if coalesce(current_setting('mx_libro.puerta', true), '') <> new.id::text
     and coalesce(current_setting('mx_libro.reverso_de', true), '') <> new.id::text then
    new.procedencia := new.procedencia || jsonb_build_object('puerta', 'insert_directo');
  end if;

  -- 8. El eslabón.
  select * into v_cabeza from asientos a order by a.cadena_pos desc limit 1;
  new.cadena_pos    := coalesce(v_cabeza.cadena_pos, 0) + 1;
  new.hash_anterior := coalesce(v_cabeza.hash, repeat('0', 64));
  new.hash          := encode(sha256(convert_to(fn_asiento_canonico(new), 'UTF8')), 'hex');
  return new;
end $$;
revoke execute on function public.fn_asientos_al_insertar() from public, anon, authenticated, service_role;

create or replace trigger trg_asientos_al_insertar
  before insert on public.asientos
  for each row execute function public.fn_asientos_al_insertar();

-- ---------------------------------------------------------------------
-- B.9 · Inmutabilidad (MX003). En TRIGGERS y no en policies: una policy
-- no frena al SQL Editor ni a una función SECURITY DEFINER; un trigger
-- sí. Ni la cabecera ni las líneas admiten update, delete o truncate, sin
-- ninguna excepción. Desde la API nadie los salta.
-- Lo que queda fuera es el DUEÑO DE LA BASE: puede apagar un trigger
-- (alter table … disable trigger) o vaciar esta función con «create or
-- replace». fn_verificar_cadena delata lo que se hizo así SIN recalcular:
-- el trigger apagado o cambiado (control triggers, con sus huellas) y el
-- asiento tocado (control hash). Pero quien además recalcula la cadena con
-- fn_asiento_canonico y reescribe los contadores y cadena_al_cerrar deja
-- todos los controles en verde: contra él, la detección es el hash
-- EXPORTADO fuera de la base (f08). Ver la cabecera, «Lo que este archivo
-- no puede hacer».
-- ---------------------------------------------------------------------
create or replace function public.fn_libro_inmutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception using errcode = 'MX003',
    message = format('El libro no se edita ni se borra (%s sobre %s). Un asiento se corrige con fn_reversar '
                     'y, si hace falta, un asiento nuevo.', tg_op, tg_table_name);
end $$;
revoke execute on function public.fn_libro_inmutable() from public, anon, authenticated, service_role;

create or replace trigger trg_asientos_inmutable
  before update or delete on public.asientos
  for each row execute function public.fn_libro_inmutable();
create or replace trigger trg_asientos_sin_truncate
  before truncate on public.asientos
  for each statement execute function public.fn_libro_inmutable();
create or replace trigger trg_asiento_lineas_inmutable
  before update or delete on public.asiento_lineas
  for each row execute function public.fn_libro_inmutable();
create or replace trigger trg_asiento_lineas_sin_truncate
  before truncate on public.asiento_lineas
  for each statement execute function public.fn_libro_inmutable();

-- ---------------------------------------------------------------------
-- B.10 · Un asiento reversible (el devengo de cierre) no llega al commit
-- sin su reverso automático del día 1: si no, el devengo se quedaría para
-- siempre. Y un devengo corregido en su mes (su reverso de corrección) no
-- llega al commit con su reverso automático vivo: el mes siguiente lo
-- desharía dos veces. Se comprueba al final de la transacción (diferido),
-- porque cada reverso entra justo después de su original.
-- SECURITY DEFINER por lo mismo que el sello (B.7b): corre al confirmar,
-- con el rol de la sesión, y bajo RLS alguien que no es el dueño (un
-- puente disparado por un trabajador) no vería los reversos y el control
-- daría un MX007 falso. Sin grant a nadie: solo lo llama el trigger.
-- (Un trigger de restricción no admite «or replace»: se borra y se crea.)
-- ---------------------------------------------------------------------
create or replace function public.fn_asientos_reversible_con_reverso()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_orig asientos;
  v_auto asientos;
begin
  if new.reversible
     and not exists (select 1 from asientos r where r.reversa_a = new.id and r.camino = 'reverso_automatico') then
    raise exception using errcode = 'MX007',
      message = format('El asiento %s es reversible y no trae su reverso automático del día 1.', new.numero);
  end if;
  if new.camino = 'reverso' then
    select * into v_orig from asientos where id = new.reversa_a;
    if found and v_orig.reversible then
      select * into v_auto from asientos where reversa_a = v_orig.id and camino = 'reverso_automatico';
      if found and not exists (select 1 from asientos n where n.reversa_a = v_auto.id and n.camino = 'reverso') then
        raise exception using errcode = 'MX007',
          message = format('El devengo %s se corrigió en su mes (%s), pero su reverso automático %s sigue vivo: el mes '
                           'siguiente lo desharía dos veces. fn_reversar lo anula en la misma transacción.',
                           v_orig.numero, new.numero, v_auto.numero);
      end if;
    end if;
  end if;
  return null;
end $$;
revoke execute on function public.fn_asientos_reversible_con_reverso() from public, anon, authenticated, service_role;

drop trigger if exists trg_asientos_reversible_diferido on public.asientos;
create constraint trigger trg_asientos_reversible_diferido
  after insert on public.asientos
  deferrable initially deferred
  for each row when (new.reversible or new.camino = 'reverso')
  execute function public.fn_asientos_reversible_con_reverso();


-- ---------------------------------------------------------------------
-- B.11 · fn_postear_interno(asiento jsonb) — la puerta de todo posteo.
-- SIN grant a ningún rol de la API: la usan fn_postear (camino 'mano'),
-- los puentes de f03 (SECURITY DEFINER, camino 'puente') y, en f07,
-- fn_aprobar (camino 'ia'). Una sola transacción: si algo falla, no queda
-- nada, ni el número.
--
-- El asiento es un objeto JSON:
--   { "camino": "mano" | "puente",
--     "fecha": "AAAA-MM-DD",            (si falta: hoy en Miami, en SQL)
--     "descripcion": "…",               (obligatoria: qué es)
--     "lineas": [ { "cuenta": "5100", "monto": "245.37",
--                   "proyecto_id": "…", "cost_code": "08-ROUGH",
--                   "co": "…", "fase": "…", "memo": "…",
--                   "tercero_tipo": "proveedor", "tercero_id": "uuid",
--                   "partida_tabla": "recibos", "partida_id": "123" }, … ],
--     "reversible": false,               (true = devengo que se reversa solo el día 1)
--     "tipo": "normal" | "apertura" | "ajuste_cpa",
--     "afecta_periodo": "2026-12",       (solo ajuste_cpa)
--     "motivo": "…",                     (obligatorio en ajuste_cpa)
--     "documento_ruta": "…",             (el papel en Storage, si no hay fila origen)
--     "origen_tabla": "recibos", "origen_id": "123",   (obligatorios en 'puente')
--     "sustituye_a": "uuid",             (el asiento REVERSADO de ese mismo
--                                         documento al que este sustituye)
--     "procedencia": { … } }             (lo que el puente quiera dejar escrito)
-- Monto con signo: positivo = debe, negativo = haber. Va como TEXTO
-- ("245.37"): se mira su escala antes de convertirlo, porque numeric(14,2)
-- redondearía callado. Nunca sale de una suma hecha en JavaScript.
-- Una clave desconocida se rechaza: un «reversibel» mal escrito no puede
-- pasar callado.
-- ---------------------------------------------------------------------
create or replace function public.fn_postear_interno(p_asiento jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves       constant text[] := array['camino','fecha','descripcion','lineas','reversible','tipo',
                                          'afecta_periodo','motivo','documento_ruta','origen_tabla',
                                          'origen_id','sustituye_a','procedencia','propuesta_id'];
  c_claves_linea constant text[] := array['cuenta','monto','proyecto_id','cost_code','co','fase','memo',
                                          'tercero_tipo','tercero_id','partida_tabla','partida_id'];
  c_uuid         constant text   := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_sobra      text;
  v_camino     text;
  v_txt        text;
  v_fecha      date;
  v_tipo       text;
  v_reversible boolean;
  v_proc       jsonb;
  v_l          jsonb;
  v_i          int := 0;
  v_monto      numeric;
  v_suma       numeric := 0;
  v_debe       numeric := 0;
  v_lineas     jsonb := '[]'::jsonb;
  v_id         uuid := gen_random_uuid();
  v_sustituye  uuid;
  v_a          asientos;
  v_rev        jsonb;
begin
  if p_asiento is null or jsonb_typeof(p_asiento) <> 'object' then
    raise exception using errcode = '22023', message = 'El asiento llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_asiento) as k
   where k <> all (c_claves);
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el asiento: %s.', v_sobra);
  end if;

  -- El camino, y quién puede cada uno.
  v_camino := p_asiento->>'camino';
  if v_camino = 'ia' then
    raise exception using errcode = '22023',
      message = 'El camino ia llega con la bandeja de la Fase 7 (fn_aprobar), con su propuesta_id.';
  elsif v_camino in ('reverso', 'reverso_automatico') then
    raise exception using errcode = '22023', message = 'Los reversos salen solo de fn_reversar.';
  elsif v_camino is null or v_camino not in ('mano', 'puente') then
    raise exception using errcode = '22023',
      message = format('Camino «%s» no válido: mano o puente.', coalesce(v_camino, ''));
  end if;
  if v_camino = 'mano' and not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño postea asientos a mano.';
  end if;
  if p_asiento ? 'propuesta_id' then
    raise exception using errcode = '22023', message = 'propuesta_id solo va con el camino ia (Fase 7).';
  end if;
  if v_camino = 'puente'
     and (coalesce(p_asiento->>'origen_tabla', '') = '' or coalesce(p_asiento->>'origen_id', '') = '') then
    raise exception using errcode = '22023',
      message = 'Un asiento de puente dice de qué documento sale (origen_tabla y origen_id).';
  end if;

  -- La fecha: texto AAAA-MM-DD; nunca un formato que dependa de la sesión.
  v_txt := p_asiento->>'fecha';
  if v_txt is null then
    v_fecha := fn_fecha_miami(now());
  elsif v_txt ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    begin
      v_fecha := v_txt::date;
    exception when others then
      raise exception using errcode = '22007', message = format('La fecha %s no existe.', v_txt);
    end;
  else
    raise exception using errcode = '22007',
      message = format('La fecha va como texto AAAA-MM-DD (llegó «%s»).', v_txt);
  end if;

  if coalesce(btrim(p_asiento->>'descripcion'), '') = '' then
    raise exception using errcode = '22023', message = 'Todo asiento dice qué es (descripcion).';
  end if;
  v_tipo := coalesce(p_asiento->>'tipo', 'normal');
  if v_tipo not in ('normal', 'apertura', 'ajuste_cpa') then
    raise exception using errcode = '22023',
      message = format('Tipo «%s» no válido: normal, apertura o ajuste_cpa.', v_tipo);
  end if;
  begin
    v_reversible := coalesce((p_asiento->>'reversible')::boolean, false);
  exception when others then
    raise exception using errcode = '22023', message = 'reversible es true o false.';
  end;
  if v_reversible and v_tipo <> 'normal' then
    raise exception using errcode = '22023',
      message = 'Solo un asiento normal es reversible (el devengo de cierre).';
  end if;
  -- La forma del ajuste del CPA, con su propio mensaje (sin esto la
  -- rechazaba un check de la tabla con un 23514 en inglés, y la app le
  -- habría dicho a Edgar que pegara un SQL).
  if coalesce(p_asiento->>'afecta_periodo', '') <> '' and v_tipo <> 'ajuste_cpa' then
    raise exception using errcode = '22023',
      message = 'afecta_periodo va solo con un ajuste del CPA (tipo ajuste_cpa): dice a qué período cerrado corresponde.';
  end if;
  if v_tipo = 'ajuste_cpa' and coalesce(p_asiento->>'afecta_periodo', '') = '' then
    raise exception using errcode = '22023',
      message = 'Un ajuste del CPA dice a qué período cerrado afecta (afecta_periodo), p. ej. ''2026-12''.';
  end if;
  if v_tipo = 'ajuste_cpa' and coalesce(btrim(p_asiento->>'motivo'), '') = '' then
    raise exception using errcode = '22023',
      message = 'Un ajuste del CPA dice por qué (motivo), p. ej. «Ajuste del CPA a 2026 según la declaración».';
  end if;
  v_proc := coalesce(p_asiento->'procedencia', '{}'::jsonb);
  if jsonb_typeof(v_proc) <> 'object' then
    raise exception using errcode = '22023', message = 'procedencia es un objeto JSON.';
  end if;
  -- El sustituto de un asiento reversado del mismo documento (B.8, paso 5).
  if coalesce(p_asiento->>'sustituye_a', '') <> '' then
    begin
      v_sustituye := (p_asiento->>'sustituye_a')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'sustituye_a es el id (uuid) del asiento reversado al que sustituye.';
    end;
    if coalesce(p_asiento->>'origen_tabla', '') = '' or coalesce(p_asiento->>'origen_id', '') = '' then
      raise exception using errcode = '22023',
        message = 'Un sustituto dice de qué documento sale (origen_tabla y origen_id): el mismo del asiento que sustituye.';
    end if;
  end if;

  -- Las líneas.
  if jsonb_typeof(p_asiento->'lineas') is distinct from 'array' then
    raise exception using errcode = 'MX001', message = 'El asiento no trae líneas (lineas es una lista).';
  end if;
  for v_l in select value from jsonb_array_elements(p_asiento->'lineas') loop
    v_i := v_i + 1;
    if jsonb_typeof(v_l) <> 'object' then
      raise exception using errcode = '22023', message = format('Línea %s: cada línea es un objeto JSON.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_l) as k
     where k <> all (c_claves_linea);
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Línea %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    if coalesce(v_l->>'cuenta', '') = '' then
      raise exception using errcode = 'MX004', message = format('Línea %s: falta la cuenta.', v_i);
    end if;
    -- El tercero y la partida (f03), en su forma, dicho en español antes de
    -- que lo pare una restricción de la tabla (un 23514 en inglés). Que
    -- existan lo mira el trigger de la línea.
    if (coalesce(v_l->>'tercero_tipo', '') = '') <> (coalesce(v_l->>'tercero_id', '') = '') then
      raise exception using errcode = '22023',
        message = format('Línea %s: el tercero va con su tipo y su id (tercero_tipo y tercero_id), los dos o ninguno.', v_i);
    end if;
    if coalesce(v_l->>'tercero_tipo', '') <> '' then
      if v_l->>'tercero_tipo' not in ('proveedor', 'empleado') then
        raise exception using errcode = 'MX006',
          message = format('Línea %s: tercero «%s» no válido: proveedor o empleado.', v_i, v_l->>'tercero_tipo');
      end if;
      if v_l->>'tercero_id' !~ c_uuid then
        raise exception using errcode = '22023',
          message = format('Línea %s: el id del tercero es un uuid en minúsculas (llegó «%s»).', v_i, v_l->>'tercero_id');
      end if;
    end if;
    if (coalesce(v_l->>'partida_tabla', '') = '') <> (coalesce(v_l->>'partida_id', '') = '') then
      raise exception using errcode = '22023',
        message = format('Línea %s: la partida va con su tabla y su id (partida_tabla y partida_id), las dos o ninguna.', v_i);
    end if;
    if coalesce(v_l->>'partida_tabla', '') <> '' then
      if v_l->>'partida_tabla' not in ('recibos', 'facturas', 'trabajos_externos', 'cobros') then
        raise exception using errcode = 'MX006',
          message = format('Línea %s: una partida es un recibo, una factura, un trabajo externo o un cobro (llegó «%s»).',
                           v_i, v_l->>'partida_tabla');
      end if;
      if (v_l->>'partida_tabla' = 'cobros' and v_l->>'partida_id' !~ c_uuid)
         or (v_l->>'partida_tabla' <> 'cobros' and v_l->>'partida_id' !~ '^(0|-?[1-9][0-9]*)$') then
        raise exception using errcode = '22023',
          message = format('Línea %s: el id de la partida %s no tiene la forma de su tabla (llegó «%s»).',
                           v_i, v_l->>'partida_tabla', v_l->>'partida_id');
      end if;
    end if;

    -- MX005: el monto se lee como texto y se mira su escala ANTES de
    -- convertirlo.
    v_txt := btrim(v_l->>'monto');
    if coalesce(v_txt, '') = '' then
      raise exception using errcode = 'MX005', message = format('Línea %s: falta el monto.', v_i);
    end if;
    begin
      v_monto := v_txt::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = format('Línea %s: «%s» no es un monto.', v_i, v_txt);
    end;
    if scale(v_monto) is null then  -- NaN o infinito
      raise exception using errcode = 'MX005', message = format('Línea %s: «%s» no es un monto.', v_i, v_txt);
    end if;
    if scale(v_monto) > 2 then
      raise exception using errcode = 'MX005',
        message = format('Línea %s: %s trae %s decimales; el libro va en centavos (máximo 2). '
                         'El redondeo se decide en el origen, a propósito.', v_i, v_txt, scale(v_monto));
    end if;
    if v_monto = 0 then
      raise exception using errcode = 'MX005', message = format('Línea %s: una línea en cero no dice nada.', v_i);
    end if;
    if abs(v_monto) >= 1000000000000 then
      raise exception using errcode = 'MX005', message = format('Línea %s: %s está fuera de rango.', v_i, v_txt);
    end if;

    v_suma := v_suma + v_monto;
    if v_monto > 0 then
      v_debe := v_debe + v_monto;
    end if;
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
      'orden',         v_i,
      'cuenta',        v_l->>'cuenta',
      'monto',         v_monto,
      'proyecto_id',   nullif(v_l->>'proyecto_id', ''),
      'cost_code',     nullif(v_l->>'cost_code', ''),
      'co',            nullif(v_l->>'co', ''),
      'fase',          nullif(v_l->>'fase', ''),
      'memo',          nullif(v_l->>'memo', ''),
      'tercero_tipo',  nullif(v_l->>'tercero_tipo', ''),
      'tercero_id',    nullif(v_l->>'tercero_id', ''),
      'partida_tabla', nullif(v_l->>'partida_tabla', ''),
      'partida_id',    nullif(v_l->>'partida_id', '')));
  end loop;

  -- MX001, antes de escribir nada (el trigger de la cabecera lo vuelve a
  -- mirar para quien entre por otro camino).
  if v_i < 2 then
    raise exception using errcode = 'MX001',
      message = format('Un asiento lleva al menos dos líneas y este trae %s.', v_i);
  end if;
  if v_suma <> 0 then
    raise exception using errcode = 'MX001',
      message = format('Descuadrado: debe %s, haber %s, diferencia %s. No entra.', v_debe, v_debe - v_suma, v_suma);
  end if;

  -- La marca de que estas líneas entraron por aquí (con la escala ya
  -- mirada): el trigger de la cabecera no las apunta como insert directo.
  perform set_config('mx_libro.puerta', v_id::text, true);

  -- Primero las líneas (cada una pasa su trigger: MX004, MX006)…
  insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo,
                              tercero_tipo, tercero_id, partida_tabla, partida_id)
  select v_id, x.orden, x.cuenta, x.monto, x.proyecto_id, x.cost_code, x.co, x.fase, x.memo,
         x.tercero_tipo, x.tercero_id, x.partida_tabla, x.partida_id
    from jsonb_to_recordset(v_lineas)
         as x(orden int, cuenta text, monto numeric, proyecto_id text, cost_code text, co text, fase text, memo text,
              tercero_tipo text, tercero_id text, partida_tabla text, partida_id text)
   order by x.orden;

  -- …y después la cabecera (su trigger: período, cuadre, documento,
  -- número, sello y hash).
  insert into asientos (id, fecha_contable, tipo, afecta_periodo, camino, descripcion, motivo, reversible,
                        origen_tabla, origen_id, sustituye_a, documento_ruta, procedencia)
  values (v_id, v_fecha, v_tipo, nullif(p_asiento->>'afecta_periodo', ''), v_camino,
          btrim(p_asiento->>'descripcion'), nullif(btrim(p_asiento->>'motivo'), ''), v_reversible,
          nullif(p_asiento->>'origen_tabla', ''), nullif(p_asiento->>'origen_id', ''), v_sustituye,
          nullif(p_asiento->>'documento_ruta', ''), v_proc)
  returning * into v_a;
  perform set_config('mx_libro.puerta', '', true);

  -- El devengo reversible trae su reverso del día 1, en la misma transacción.
  if v_reversible then
    v_rev := fn_reversar_interno(v_a.id, format('Reverso automático del devengo %s', v_a.numero),
                                 'reverso_automatico',
                                 jsonb_build_object('funcion', 'reverso automático'));
  end if;

  return jsonb_build_object('id', v_a.id, 'numero', v_a.numero, 'fecha_contable', v_a.fecha_contable,
                            'periodo', v_a.periodo, 'hash', v_a.hash, 'reverso', v_rev);
end $$;
revoke execute on function public.fn_postear_interno(jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- B.12 · fn_postear(asiento jsonb) — lo que llama conta.js (camino 'mano').
-- Solo el dueño (o el SQL Editor). El camino y el sello no los manda el
-- cliente: los pone la base. El origen (origen_tabla, origen_id) solo
-- viaja junto con sustituye_a: la corrección a mano del asiento reversado
-- de un documento dice de qué papel sale y a cuál sustituye. El PRIMER
-- asiento de un documento lo postea su puente (f03), no la mano; y el de
-- un papel que lleva su puente no se sustituye a mano (MX007).
--   _rpc('fn_postear', { p_asiento: { fecha, descripcion, lineas, … } })
-- ---------------------------------------------------------------------
create or replace function public.fn_postear(p_asiento jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño postea asientos.';
  end if;
  if p_asiento is null or jsonb_typeof(p_asiento) <> 'object' then
    raise exception using errcode = '22023', message = 'El asiento llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_asiento) as k
   where k not in ('fecha','descripcion','lineas','reversible','tipo','afecta_periodo','motivo','documento_ruta',
                   'origen_tabla','origen_id','sustituye_a');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('fn_postear no acepta %s: el camino y el sello los pone la base.', v_sobra);
  end if;
  if (p_asiento ? 'origen_tabla' or p_asiento ? 'origen_id') and coalesce(p_asiento->>'sustituye_a', '') = '' then
    raise exception using errcode = '22023',
      message = 'fn_postear lleva origen_tabla y origen_id solo para sustituir el asiento reversado de ese documento '
                '(sustituye_a). El primer asiento de un documento lo postea su puente.';
  end if;
  -- Un papel que lleva su PUENTE (f03) no se sustituye a mano: el puente
  -- lo tomaría por un papel que cambió, reversaría la corrección con un
  -- motivo falso y pondría el suyo. Se corrige el papel y su puente pone el
  -- asiento nuevo (fn_reversar dice cómo, según el papel).
  if exists (select 1 from asientos a
              where a.origen_tabla = p_asiento->>'origen_tabla' and a.origen_id = p_asiento->>'origen_id'
                and a.camino = 'puente') then
    raise exception using errcode = 'MX007',
      message = format('%s %s lo lleva su puente: su asiento no se sustituye a mano. Se corrige el papel y su puente pone el '
                       'reverso y el asiento nuevo (con su motivo); para mover un importe de cuenta sin tocar el papel, un '
                       'asiento a mano de reclasificación, sin origen.', p_asiento->>'origen_tabla', p_asiento->>'origen_id');
  end if;
  return fn_postear_interno(p_asiento || jsonb_build_object('camino', 'mano',
                                                            'procedencia', jsonb_build_object('funcion', 'fn_postear')));
end $$;
revoke execute on function public.fn_postear(jsonb) from public, anon, authenticated, service_role;
grant  execute on function public.fn_postear(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- B.13 · fn_reversar_interno — la única fábrica de reversos. Genera las
-- líneas espejo DESDE LA BASE (nadie se las dicta) y las postea con
-- reversa_a y motivo. Sin grant a la API: la usan fn_reversar, el reverso
-- automático y los puentes (un recibo que pasa a «anulado»).
-- La fecha del reverso (▶ regla que Edgar confirma):
--   · reverso automático: el día 1 del mes siguiente al original;
--   · si el período del original sigue abierto: la misma fecha;
--   · si está cerrado: greatest(fecha original, primer día del mes
--     abierto más antiguo POSTERIOR al original). El período de apertura
--     no cuenta como destino: solo admite la apertura.
-- El tipo del reverso: el de su original, salvo que corrija un asiento
-- normal de un ejercicio ANTERIOR al de la fecha del reverso: entonces va
-- como ajuste de ese ejercicio (tipo ajuste_cpa, afecta_periodo = el
-- período del original). Así el error del paralelo de 2026 corregido en
-- 2027 no mueve el resultado de 2027 (la base de su 1120-S): f04 lo
-- pliega a 3900 y lo enseña en 2026 «con ajustes posteriores». Dentro del
-- mismo año, el reverso es un asiento como su original (regla A de f08).
-- El asiento de apertura con la apertura ya cerrada no se reversa (MX007):
-- el reverso caería en octubre y dejaría el balance de apertura vacío, y
-- la balanza buena ya no entraría como apertura. Lo que la balanza traía
-- mal se corrige con un ajuste a la apertura (ver la cabecera).
-- Un devengo reversible (el ajuste de WIP de f10, el devengo de horas de
-- f03) se corrige DENTRO de su mes, antes de cerrarlo: su reverso va en su
-- misma fecha y, en la misma transacción, se anula su reverso automático
-- del día 1 (con su espejo, en su misma fecha). Así el mes queda sin el
-- devengo equivocado y el siguiente no deshace dos veces lo mismo; el
-- devengo bueno entra después como sustituto (sustituye_a), con su propio
-- reverso del día 1. Con el mes del devengo ya cerrado no hay nada que
-- corregir: ya se deshizo solo el día 1 (MX007, con qué hacer).
-- ---------------------------------------------------------------------
create or replace function public.fn_reversar_interno(p_asiento uuid, p_motivo text,
                                                      p_camino text default 'reverso',
                                                      p_procedencia jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_o     asientos;
  v_fecha date;
  v_id    uuid := gen_random_uuid();
  v_a     asientos;
  v_auto  asientos;
  v_anula jsonb;
  v_desc  text;
  v_tipo   text;
  v_afecta text;
begin
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Todo reverso dice por qué (motivo).';
  end if;
  if p_camino is null or p_camino not in ('reverso', 'reverso_automatico') then
    raise exception using errcode = '22023', message = 'El camino de un reverso es reverso o reverso_automatico.';
  end if;
  if p_procedencia is null or jsonb_typeof(p_procedencia) <> 'object' then
    raise exception using errcode = '22023', message = 'procedencia es un objeto JSON.';
  end if;

  select * into v_o from asientos where id = p_asiento;
  if not found then
    raise exception using errcode = 'MX007', message = 'No existe el asiento a reversar.';
  end if;
  -- Un reverso no se reversa, salvo el automático de un devengo cuyo
  -- reverso de corrección acaba de entrar (lo anula esta misma función,
  -- más abajo, llamándose a sí misma).
  if v_o.reversa_a is not null
     and not (v_o.camino = 'reverso_automatico' and p_camino = 'reverso'
              and exists (select 1 from asientos r where r.reversa_a = v_o.reversa_a and r.camino = 'reverso')) then
    raise exception using errcode = 'MX007',
      message = format('%s es un reverso: un reverso no se reversa. La re-corrección es un asiento nuevo.%s', v_o.numero,
                       case when v_o.camino = 'reverso_automatico'
                            then format(' Para corregir el devengo %s se reversa el devengo: eso anula también su '
                                        'reverso del día 1.', (select o.numero from asientos o where o.id = v_o.reversa_a))
                            else '' end);
  end if;
  if exists (select 1 from asientos where reversa_a = v_o.id and camino = p_camino)
     or (p_camino = 'reverso_automatico' and exists (select 1 from asientos where reversa_a = v_o.id)) then
    raise exception using errcode = 'MX007', message = format('%s ya se reversó.', v_o.numero);
  end if;
  -- La apertura cerrada no se reversa: se ajusta (ver arriba).
  if v_o.tipo = 'apertura'
     and exists (select 1 from periodos where periodo = v_o.periodo and estado = 'cerrado') then
    raise exception using errcode = 'MX007',
      message = format('%s es el asiento de apertura y la apertura (%s) ya está cerrada: no se reversa entero. Lo que la '
                       'balanza de QuickBooks traía mal se corrige en el mes abierto con un ajuste a la apertura: tipo '
                       'ajuste_cpa, afecta_periodo = ''%s'', con su motivo, solo con cuentas de balance y contra 3900 '
                       '(utilidades retenidas).', v_o.numero, v_o.periodo, v_o.periodo);
  end if;

  if p_camino = 'reverso_automatico' then
    v_fecha := (date_trunc('month', v_o.fecha_contable::timestamp) + interval '1 month')::date;
  elsif v_o.reversa_a is not null then
    -- La anulación de un reverso automático: en su misma fecha.
    v_fecha := v_o.fecha_contable;
  elsif exists (select 1 from periodos where periodo = v_o.periodo and estado = 'abierto') then
    v_fecha := v_o.fecha_contable;
  elsif v_o.reversible then
    raise exception using errcode = 'MX007',
      message = format('%s es un devengo reversible de un mes ya cerrado (%s): ya se deshizo solo el día 1 con %s, y no '
                       'hay nada que reversar. Si su monto estaba mal, la diferencia se corrige con un asiento en el mes '
                       'abierto.', v_o.numero, v_o.periodo,
                       coalesce((select r.numero from asientos r where r.reversa_a = v_o.id and r.camino = 'reverso_automatico'),
                                'su reverso automático'));
  else
    select min(p.desde) into v_fecha
      from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > v_o.fecha_contable;
    if v_fecha is null then
      raise exception using errcode = 'MX002',
        message = format('No hay un mes abierto después del %s para el reverso: ábrelo con fn_abrir_periodo.', v_o.fecha_contable);
    end if;
    v_fecha := greatest(v_o.fecha_contable, v_fecha);
  end if;

  -- El tipo (ver arriba): el de su original, o el ajuste de un ejercicio
  -- anterior.
  v_tipo   := v_o.tipo;
  v_afecta := v_o.afecta_periodo;
  if p_camino = 'reverso' and v_o.reversa_a is null and v_o.tipo = 'normal'
     and extract(year from v_fecha)::int > v_o.anio then
    v_tipo   := 'ajuste_cpa';
    v_afecta := v_o.periodo;
  end if;

  v_desc := case when v_o.reversa_a is not null
                 then format('Anula %s, el reverso automático del devengo %s, que se corrigió en su mes', v_o.numero,
                             (select o.numero from asientos o where o.id = v_o.reversa_a))
                 when v_tipo is distinct from v_o.tipo
                 then format('Reverso de %s (ajuste de %s, un ejercicio anterior): %s', v_o.numero, v_o.anio, v_o.descripcion)
                 else 'Reverso de ' || v_o.numero || ': ' || v_o.descripcion end;

  -- Las líneas de este reverso no se juzgan contra el plan de hoy (ver
  -- B.7); el trigger de la cabecera exige que sean el espejo exacto.
  perform set_config('mx_libro.reverso_de', v_id::text, true);
  insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo,
                              tercero_tipo, tercero_id, partida_tabla, partida_id)
  select v_id, l.orden, l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase, l.memo,
         l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
    from asiento_lineas l
   where l.asiento_id = v_o.id
   order by l.orden;

  insert into asientos (id, fecha_contable, tipo, afecta_periodo, camino, descripcion, motivo, reversa_a,
                        reversible, origen_tabla, origen_id, documento_ruta, procedencia)
  values (v_id, v_fecha, v_tipo, v_afecta, p_camino, v_desc, btrim(p_motivo), v_o.id,
          false, v_o.origen_tabla, v_o.origen_id, v_o.documento_ruta,
          p_procedencia || jsonb_build_object('reversa', v_o.numero))
  returning * into v_a;
  perform set_config('mx_libro.reverso_de', '', true);

  -- Un devengo corregido en su mes: su reverso automático del día 1 se
  -- anula ahora, en la misma transacción (al confirmar lo exige B.10).
  if p_camino = 'reverso' and v_o.reversible then
    select * into v_auto from asientos where reversa_a = v_o.id and camino = 'reverso_automatico';
    if found then
      v_anula := fn_reversar_interno(v_auto.id, p_motivo, 'reverso',
                                     p_procedencia || jsonb_build_object('anula_reverso_automatico_de', v_o.numero));
    end if;
  end if;

  return jsonb_strip_nulls(jsonb_build_object('id', v_a.id, 'numero', v_a.numero, 'fecha_contable', v_a.fecha_contable,
                                              'periodo', v_a.periodo, 'tipo', v_a.tipo, 'afecta_periodo', v_a.afecta_periodo,
                                              'hash', v_a.hash, 'reversa', v_o.numero, 'anula', v_anula));
end $$;
revoke execute on function public.fn_reversar_interno(uuid, text, text, jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- B.14 · fn_reversar(asiento uuid, motivo text) — lo que llama conta.js.
-- Solo el dueño (o el SQL Editor). Un reverso no se reversa; un asiento
-- se reversa una sola vez; el motivo es obligatorio. Un devengo
-- reversible, dentro de su mes: devuelve también la anulación de su
-- reverso del día 1 («anula»). Devuelve el tipo del reverso: un asiento
-- de un ejercicio anterior sale como ajuste de ese ejercicio (tipo
-- ajuste_cpa y su afecta_periodo), y conta.js lo dice así. El asiento de
-- un PUENTE no (MX007): se corrige su papel y su puente pone el reverso y
-- el asiento nuevo; el mensaje dice cómo, según el papel.
-- ---------------------------------------------------------------------
create or replace function public.fn_reversar(p_asiento uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_o asientos;
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño reversa asientos.';
  end if;
  -- El asiento de un PUENTE (f03) no se reversa a mano: el papel seguiría
  -- ahí sin asiento, y el siguiente backfill («reintentar puente», el de la
  -- noche, cualquier ✎) lo volvería a postear igual: la corrección quedaba
  -- doble (el gasto y la deuda, el ingreso y la CxC, el banco). Se corrige
  -- el papel, y su puente pone el reverso y el asiento nuevo; el mensaje
  -- dice cómo, según el papel.
  select * into v_o from asientos where id = p_asiento;
  if found and v_o.camino = 'puente' then
    raise exception using errcode = 'MX007',
      message = format('%s es el asiento del puente de %s %s: no se reversa a mano (el papel seguiría ahí, y el siguiente '
                       'backfill lo volvería a poner). %s Si lo que estaba mal era una regla (la cuenta de una categoría, de '
                       'una tarjeta, de un tipo de obra), corrige la regla y rehazlo: select fn_puentes_rehacer(%L, %L, '
                       '''motivo'');. Para mover un importe de cuenta sin tocar el papel, un asiento a mano de '
                       'reclasificación (fn_postear, sin origen).', v_o.numero, v_o.origen_tabla, v_o.origen_id,
                       case v_o.origen_tabla
                         when 'recibos' then format('Corrige el recibo (✎ en la app, o update recibos … where id = %s; en el '
                                                    'SQL Editor) y su puente pone el reverso y el asiento nuevo; si no va, '
                                                    'anúlalo: select fn_recibo_anular(%s, ''motivo'');.', v_o.origen_id,
                                                    v_o.origen_id)
                         when 'trabajos_externos' then format('Corrige el trabajo externo y su puente lo rehace; si no va, '
                                                              'anúlalo: select fn_externo_anular(%s, ''motivo'');.',
                                                              v_o.origen_id)
                         when 'facturas' then format('Una factura emitida se anula con su nota de crédito: select '
                                                     'fn_factura_anular(%s, ''motivo'');.', v_o.origen_id)
                         when 'cobros' then format('Un cobro mal registrado se anula: select fn_cobro_anular(%L, ''motivo'');; '
                                                   'un cheque que rebotó se devuelve en su fecha: select fn_cobro_devolver(%L, '
                                                   '''AAAA-MM-DD'', ''motivo'');.', v_o.origen_id, v_o.origen_id)
                         when 'aplicaciones_cobro' then 'Un anticipo aplicado se deshace con su cobro (fn_cobro_anular).'
                         when 'cobros_devoluciones' then 'Una devolución no se deshace: si fue un error, el cobro se registra '
                                                         'otra vez (fn_cobro_registrar).'
                         when 'notas_credito' then 'Una nota de crédito no se deshace: la factura anulada se queda anulada, y '
                                                   'la buena se emite de nuevo.'
                         when 'horas_devengo' then format('El devengo de un mes lo pone al día (o lo deshace): select '
                                                          'fn_horas_devengar(%L);.', v_o.origen_id)
                         else 'Se corrige su papel y su puente lo rehace.' end,
                       v_o.origen_tabla, v_o.origen_id);
  end if;
  return fn_reversar_interno(p_asiento, p_motivo, 'reverso', jsonb_build_object('funcion', 'fn_reversar'));
end $$;
revoke execute on function public.fn_reversar(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_reversar(uuid, text) to authenticated;


-- ---------------------------------------------------------------------
-- B.15 · fn_estado(periodo) — la fila de control que conta.js lee ANTES
-- de pintar: si cuadra = false, o filas = 0 donde el período tiene
-- asientos, la pantalla se niega a dibujar (f04, f05). Para un año, suma
-- todos sus períodos. Lee con los permisos de quien llama (RLS): el
-- equipo no ve ni el período (0 filas), el dueño lo ve todo.
-- ---------------------------------------------------------------------
create or replace function public.fn_estado(p_periodo text)
returns table (periodo text, tipo text, estado text, paralelo boolean, asientos bigint, filas bigint,
               total_debe numeric, total_haber numeric, cuadra boolean)
language sql
stable
set search_path = public, pg_temp
as $$
  with p as (
    select * from periodos pp where pp.periodo = p_periodo
  ), a as (
    select x.id
      from asientos x, p
     where (p.tipo = 'anio' and x.anio = p.anio)
        or (p.tipo <> 'anio' and x.periodo = p.periodo)
  ), l as (
    select y.monto from asiento_lineas y join a on a.id = y.asiento_id
  )
  select p.periodo, p.tipo, p.estado, p.paralelo,
         (select count(*) from a),
         (select count(*) from l),
         (select coalesce(sum(l.monto), 0) from l where l.monto > 0),
         (select coalesce(-sum(l.monto), 0) from l where l.monto < 0),
         (select coalesce(sum(l.monto), 0) = 0 from l)
    from p
$$;
revoke execute on function public.fn_estado(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_estado(text) to authenticated;

-- ---------------------------------------------------------------------
-- B.16 · fn_verificar_cadena() — lo que no se impide desde la API, se
-- detecta desde dentro… hasta donde se puede desde dentro (ver abajo).
-- Una fila por control, con la forma de ronda_resultados de f08
-- (control, ok, detalle). La ronda nocturna la llamará desde pg_cron; el
-- dueño, cuando quiera, por RPC. SECURITY DEFINER porque tiene que ver
-- TODO el libro y leer el catálogo; por eso comprueba primero quién es.
--   hash        cada asiento, recalculado desde lo guardado, da su hash
--   enlace      cada hash_anterior es el hash del asiento anterior; las
--               posiciones van 1, 2, 3… sin huecos
--   numeracion  por año, los números van del 1 al último sin huecos
--   contadores  cada contador de asientos está en el último número
--   cuadre      cada asiento suma cero y tiene al menos dos líneas
--   reversos    cada reverso es el espejo de su original y lleva su tipo
--               (o, si corrige un asiento normal de un ejercicio anterior,
--               el ajuste de ese ejercicio); cada
--               reversible tiene su reverso automático, del día 1; un
--               devengo corregido en su mes lo fue en su misma fecha y con
--               su reverso automático anulado; ningún otro reverso se
--               reversó; cada sustituto sustituye a un asiento reversado
--               (con su reverso de corrección, no solo el automático) de
--               su mismo documento, y si ese es de un ejercicio anterior,
--               es un ajuste de ese ejercicio; y ningún documento tiene
--               dos asientos vivos
--   periodos    en cada período cerrado: el hash del cierre sigue en la
--               cadena, y nada fechado hasta su último día entró después
--               del cierre ni detrás de su foto (esto también mira los
--               períodos posteriores: un mes reabierto por debajo de su
--               guarda, escrito y vuelto a cerrar deja un asiento detrás
--               de la foto del mes siguiente); se cerró cuando ya había
--               terminado; los meses se cerraron en orden, también en la
--               hora del cierre y en la posición de la foto (la apertura
--               antes, el año después de todos sus meses, y cada año
--               después del anterior); el calendario no tiene huecos; y
--               hay UNA apertura, nada antes de ella, y cerrada, con su
--               asiento de apertura VIVO (sin reverso de corrección), la
--               misma condición con que la deja cerrar su guarda (B.5)
--   triggers    las guardas existen, están habilitadas y llaman a su
--               función; su definición y la de las funciones del libro
--               siguen siendo las que dejó este archivo; las tablas del
--               libro no se reescribieron ni cambiaron de forma (columnas,
--               restricciones, índices; un ALTER TABLE … TYPE … USING
--               reescribe la tabla sin disparar ningún trigger); todo por
--               las huellas de B.22; y no hay triggers ajenos sobre el
--               libro
--   cuentas     cada cuenta está tal como la dejó su último cambio
--               apuntado en cuentas_historial, y ninguna desapareció sin
--               su baja: un cambio que no pasó por el trigger del
--               historial (el mismo ALTER TABLE, o el trigger apagado) no
--               pasa callado
--   permisos    RLS; en cada tabla del libro UNA policy, «solo el dueño
--               lee» tal cual (select, permisiva, authenticated,
--               es_dueno()); la API sin más privilegio que SELECT, ni por
--               tabla ni por columna (anon, ninguno); ninguna vista que lea
--               el libro sin security_invoker, directa o a través de otra
--               vista, ni vista materializada que lo copie a la API; las
--               funciones con el reparto de B.20 (a service_role se le
--               acepta EXECUTE en las de trigger, que nadie puede llamar
--               sueltas: es la convención de docs/sql/e37-seguridad.sql, y
--               volver a pegar e37 no debe encender una falsa alarma);
--               NINGUNA OTRA función SECURITY DEFINER que lea o escriba el
--               libro (que nombre una de sus tablas, o una vista que lo
--               lee, o llame a una puerta interna, a fn_estado o a otra de
--               ellas) y que la API pueda ejecutar: con los permisos de su
--               dueño se salta la policy, y en Supabase toda función nace
--               ejecutable por anon; ni una vista que llame a una de esas,
--               aunque sea security_invoker; y es_dueno() igual que cuando
--               se pegó este archivo (es compartida con Planos: si cambia,
--               alguien tiene que mirarla). Cada línea dice qué archivo la
--               arregla al volver a pegarlo (c1 o c2), o que no es de
--               ninguno de los dos
-- LO QUE NO VE (la frontera, dicha también en la cabecera): el dueño de la
-- base puede recalcular la cadena con fn_asiento_canonico y reescribir
-- sus anclas (contadores, cadena_al_cerrar, las horas de cierre), y hasta
-- las huellas o esta misma función. Entonces los diez controles dan
-- true. Contra él, el control es el hash exportado FUERA de la base en
-- cada cierre (f08).
-- ---------------------------------------------------------------------
create or replace function public.fn_verificar_cadena()
returns table (control text, ok boolean, detalle jsonb)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_n     bigint;
  v_malos jsonb;
  v_mas   jsonb;
  v_orden jsonb;
  v_antes jsonb;
  v_apert jsonb;
  -- Para el control permisos: lo que lee el libro (tablas, vistas y
  -- funciones que no son de este archivo), y lo que de eso ve la API.
  v_tablas     oid[];
  v_rel        oid[];
  v_rel_vistas oid[];
  v_nombres    text[];
  v_conocidas  oid[];
  v_semillas   oid[];
  v_fn_nombres text[];
  v_lee        oid[] := '{}';
  v_nuevas     oid[];
  v_rx_rel     text;
  v_rx_fn      text;
  v_sospechosas oid[];
  v_vistas_fn  oid[];
  v_app        text[];
  v_int        text[];
  v_fases      text[];
  c_tablas constant text[] := array['cuentas', 'cuentas_historial', 'periodos', 'contadores', 'asientos', 'asiento_lineas'];
  -- Las que llama conta.js (grant a authenticated) y las de dentro (sin
  -- grant a nadie de la API). Ver B.20. Una fase que añada una función
  -- que lee el libro y que la app llama a propósito la pone aquí, en el
  -- mismo pegado (y en las huellas de B.22).
  c_fn_app constant text[] := array['fn_postear(jsonb)', 'fn_reversar(uuid,text)', 'fn_estado(text)',
                                    'fn_verificar_cadena()', 'fn_cerrar_periodo(text)', 'fn_abrir_periodo(text)',
                                    'fn_fecha_miami(timestamptz)'];
  c_fn_internas constant text[] := array['fn_postear_interno(jsonb)', 'fn_reversar_interno(uuid,text,text,jsonb)',
                                         'fn_asiento_canonico(asientos)', 'fn_rol_llamante()', 'fn_desde_editor()',
                                         'fn_libro_huellas_calcular()', 'fn_libro_huellas()', 'fn_libro_huellas_sellar(text)',
                                         'fn_cuentas_guarda()', 'fn_cuentas_historial()', 'fn_cuentas_historial_inmutable()',
                                         'fn_periodos_guarda()', 'fn_contadores_guarda()', 'fn_contadores_al_confirmar()',
                                         'fn_asiento_lineas_al_insertar()',
                                         'fn_asiento_lineas_sello_al_confirmar()', 'fn_asientos_al_insertar()',
                                         'fn_libro_inmutable()', 'fn_asientos_reversible_con_reverso()',
                                         'fn_proyectos_con_libro()'];
  -- Las de las fases que vienen detrás, que tocan el libro a propósito. Se
  -- miran igual que las de arriba, pero SOLO SI YA EXISTEN: este archivo se
  -- pega antes que ellas. Las que llama conta.js (con es_dueno() por
  -- dentro), por nombre; las internas, por su prefijo: toda función
  -- fn_puente_… (singular) es una puerta interna de los puentes de f03 y no
  -- la ejecuta nadie de la API. Si falta una, lo dice el verificador de su
  -- fase (fn_puentes_verificar, en c3-puentes.sql), no este.
  c_fn_app_fases constant text[] := array[
    -- f03 · c3-puentes.sql
    'fn_puentes_correr(date)', 'fn_puentes_rehacer(text,text,text)', 'fn_puentes_verificar()',
    'fn_puentes_cuenta(text,text)', 'fn_factura_anular(bigint,text,date)', 'fn_cobro_registrar(jsonb)',
    'fn_cobro_anular(uuid,text)', 'fn_cobro_devolver(uuid,date,text,text)',
    'fn_anticipo_aplicar(uuid,bigint,text,date,boolean)', 'fn_horas_aprobar(uuid,date,date,jsonb)',
    'fn_horas_desaprobar(uuid,date,date,text)', 'fn_horas_devengar(text)', 'fn_recibo_anular(bigint,text)',
    'fn_externo_anular(bigint,text)', 'fn_mapeo_categoria(text,text,text)', 'fn_mapeo_metodo_pago(text,text,text)',
    'fn_mapeo_tipo_proyecto(text,text)', 'fn_mapeo_confirmar(text,text)', 'fn_tarjeta_alta(text,text,text,uuid)',
    'fn_proveedor_alta(text,text,text[],bigint)', 'fn_proveedor_alias(uuid,text)',
    'fn_puentes_antes_del_corte(text,bigint,text)', 'fn_puentes_confirmar(text,bigint,text,text)',
    'fn_recibo_desanular(bigint,text)'];
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño verifica la cadena.';
  end if;

  -- hash
  select count(*) into v_n from asientos;
  select coalesce(jsonb_agg(s.numero order by s.cadena_pos), '[]'::jsonb) into v_malos
    from (select a.numero, a.cadena_pos
            from asientos a
           where a.hash is distinct from encode(sha256(convert_to(fn_asiento_canonico(a), 'UTF8')), 'hex')
           order by a.cadena_pos
           limit 20) s;
  control := 'hash';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('asientos', v_n, 'alterados', v_malos);
  return next;

  -- enlace
  select coalesce(jsonb_agg(s.numero order by s.cadena_pos), '[]'::jsonb) into v_malos
    from (select c.numero, c.cadena_pos
            from (select a.numero, a.cadena_pos, a.hash_anterior,
                         lag(a.hash) over (order by a.cadena_pos) as previo,
                         row_number() over (order by a.cadena_pos) as rn
                    from asientos a) c
           where c.hash_anterior is distinct from coalesce(c.previo, repeat('0', 64))
              or c.cadena_pos <> c.rn
           order by c.cadena_pos
           limit 20) s;
  control := 'enlace';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('rotos', v_malos);
  return next;

  -- numeracion
  select coalesce(jsonb_agg(jsonb_build_object('anio', s.anio, 'asientos', s.n, 'primero', s.mn, 'ultimo', s.mx)
                            order by s.anio), '[]'::jsonb) into v_malos
    from (select a.anio, count(*) as n, min(a.secuencia) as mn, max(a.secuencia) as mx
            from asientos a group by a.anio) s
   where s.n <> s.mx or s.mn <> 1;
  control := 'numeracion';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('con_huecos', v_malos);
  return next;

  -- contadores
  select coalesce(jsonb_agg(jsonb_build_object('serie', s.serie, 'contador', s.ultimo, 'ultimo_asiento', s.mx)), '[]'::jsonb)
    into v_malos
    from (select coalesce(c.serie, 'asientos-' || x.anio) as serie, c.ultimo, x.mx
            from (select a.anio, max(a.secuencia) as mx from asientos a group by a.anio) x
            full join (select * from contadores where contadores.serie like 'asientos-%') c
                   on c.serie = 'asientos-' || x.anio
           where coalesce(c.ultimo, -1) <> coalesce(x.mx, 0)) s;
  control := 'contadores';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('descuadrados', v_malos);
  return next;

  -- cuadre
  select coalesce(jsonb_agg(s.numero), '[]'::jsonb) into v_malos
    from (select a.numero
            from asientos a
            left join asiento_lineas l on l.asiento_id = a.id
           group by a.id, a.numero, a.cadena_pos
          having count(l.orden) < 2 or coalesce(sum(l.monto), 0) <> 0
           order by a.cadena_pos
           limit 20) s;
  select count(*) into v_n
    from asiento_lineas l
   where not exists (select 1 from asientos a where a.id = l.asiento_id);
  control := 'cuadre';
  ok      := jsonb_array_length(v_malos) = 0 and v_n = 0;
  detalle := jsonb_build_object('descuadrados', v_malos, 'lineas_sin_cabecera', v_n);
  return next;

  -- reversos (y sustitutos)
  select coalesce(jsonb_agg(s.numero), '[]'::jsonb) into v_malos
    from (-- un reverso que no es el espejo de su original
          select r.numero
            from asientos r
            join asientos o on o.id = r.reversa_a
           where exists (
                   (select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                           l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                      from asiento_lineas l where l.asiento_id = o.id
                    except all
                    select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                           l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                      from asiento_lineas l where l.asiento_id = r.id)
                   union all
                   (select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                           l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                      from asiento_lineas l where l.asiento_id = r.id
                    except all
                    select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase,
                           l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                      from asiento_lineas l where l.asiento_id = o.id))
          union all
          -- un reversible sin su reverso automático
          select o.numero
            from asientos o
           where o.reversible
             and not exists (select 1 from asientos r where r.reversa_a = o.id and r.camino = 'reverso_automatico')
          union all
          -- un reverso automático que no es el de un reversible, o que no va el día 1 del mes siguiente
          select r.numero
            from asientos r
            join asientos o on o.id = r.reversa_a
           where r.camino = 'reverso_automatico'
             and (not o.reversible
                  or r.fecha_contable <> (date_trunc('month', o.fecha_contable::timestamp) + interval '1 month')::date)
          union all
          -- un reverso de un reverso que no es la anulación del reverso automático de un
          -- devengo corregido antes (en su misma fecha)
          select r.numero
            from asientos r
            join asientos o on o.id = r.reversa_a
           where o.reversa_a is not null
             and not (o.camino = 'reverso_automatico' and r.camino = 'reverso' and r.fecha_contable = o.fecha_contable
                      and exists (select 1 from asientos x
                                   where x.reversa_a = o.reversa_a and x.camino = 'reverso' and x.cadena_pos < r.cadena_pos))
          union all
          -- un devengo corregido fuera de su fecha, o con su reverso automático sin anular
          select o.numero
            from asientos o
            join asientos x on x.reversa_a = o.id and x.camino = 'reverso'
           where o.reversible
             and (x.fecha_contable <> o.fecha_contable
                  or not exists (select 1 from asientos ra
                                   join asientos n on n.reversa_a = ra.id and n.camino = 'reverso'
                                  where ra.reversa_a = o.id and ra.camino = 'reverso_automatico'))
          union all
          -- un sustituto que no sustituye a un asiento reversado (antes, con su reverso de
          -- corrección: el automático del día 1 no cuenta) de su documento
          select x.numero
            from asientos x
            left join asientos o on o.id = x.sustituye_a
           where x.sustituye_a is not null
             and (   o.id is null
                  or o.origen_tabla is distinct from x.origen_tabla or o.origen_id is distinct from x.origen_id
                  or o.camino in ('reverso', 'reverso_automatico')
                  or not exists (select 1 from asientos r
                                  where r.reversa_a = o.id and r.camino = 'reverso' and r.cadena_pos < x.cadena_pos))
          union all
          -- un reverso sin el tipo que le toca (B.8, paso 4): el de su original, o el ajuste
          -- del ejercicio anterior si corrige un asiento normal de ese ejercicio
          select r.numero
            from asientos r
            join asientos o on o.id = r.reversa_a
           where case when r.camino = 'reverso' and o.reversa_a is null and o.tipo = 'normal' and r.anio > o.anio
                      then r.tipo is distinct from 'ajuste_cpa' or r.afecta_periodo is distinct from o.periodo
                      else r.tipo is distinct from o.tipo or r.afecta_periodo is distinct from o.afecta_periodo end
          union all
          -- el sustituto de un asiento de un ejercicio anterior que no es un ajuste de ese
          -- ejercicio (B.8, paso 5), salvo el de un papel que ya es del año del sustituto
          -- (un puente, con procedencia.fecha_documento de ese año: asiento normal)
          select x.numero
            from asientos x
            join asientos o on o.id = x.sustituye_a
            left join periodos po on po.periodo = o.afecta_periodo
            left join periodos px on px.periodo = x.afecta_periodo
           where coalesce(po.anio, o.anio) < x.anio
             and (x.tipo is distinct from 'ajuste_cpa' or px.anio is distinct from coalesce(po.anio, o.anio))
             and not (x.camino = 'puente' and x.tipo = 'normal'
                      and coalesce(x.procedencia->>'fecha_documento', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                      and left(x.procedencia->>'fecha_documento', 4)::int = x.anio)
          union all
          -- un documento con dos asientos vivos (sin su reverso de corrección)
          select min(a.numero)
            from asientos a
           where a.origen_tabla is not null and a.camino not in ('reverso', 'reverso_automatico')
             and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
           group by a.origen_tabla, a.origen_id
          having count(*) > 1
          limit 20) s;
  control := 'reversos';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('malos', v_malos);
  return next;

  -- periodos
  -- · tocados: la foto de cada cierre sigue en la cadena, y NADA fechado
  --   hasta el último día del período entró después del cierre ni detrás
  --   de su foto. Por fecha y no por período, a propósito: un mes anterior
  --   reabierto por debajo de su guarda (un ALTER TABLE no dispara
  --   triggers), escrito y vuelto a cerrar, deja su asiento nuevo detrás
  --   de la foto del mes siguiente, que sí se cerró antes. Se calcula una
  --   vez por día (lo más adelante de la cadena y la hora más tardía de
  --   todo lo fechado hasta ese día), no una vez por período y asiento.
  with fotos as (
         select p.periodo, p.desde, p.hasta, p.cerrado_el, p.cadena_al_cerrar, f.cadena_pos as foto
           from periodos p
           left join asientos f on f.hash = p.cadena_al_cerrar
          where p.estado = 'cerrado'
       ),
       por_dia as (
         select a.fecha_contable, max(a.cadena_pos) as pos, max(a.creado_el) as creado
           from asientos a
          group by a.fecha_contable
       ),
       hasta_el_dia as (
         select d.fecha_contable,
                max(d.pos)    over (order by d.fecha_contable) as pos,
                max(d.creado) over (order by d.fecha_contable) as creado
           from por_dia d
       )
  select coalesce(jsonb_agg(s.periodo order by s.desde), '[]'::jsonb) into v_malos
    from (select f.periodo, f.desde
            from fotos f
            left join lateral (select h.pos, h.creado
                                 from hasta_el_dia h
                                where h.fecha_contable <= f.hasta
                                order by h.fecha_contable desc
                                limit 1) h on true
           where (f.cadena_al_cerrar is distinct from repeat('0', 64) and f.foto is null)
              or h.pos > coalesce(f.foto, 0)
              or h.creado > f.cerrado_el) s;
  -- · fuera de orden o con hueco: un mes sin el día anterior en el
  --   calendario; un mes (o la apertura) cerrado con otro anterior abierto,
  --   o cerrado DESPUÉS que uno posterior, o con su foto más adelante en la
  --   cadena que la de uno posterior; un año cerrado antes que alguno de
  --   sus períodos; y un año cerrado con el año anterior abierto, o antes
  --   que él (por la hora o por la foto).
  select coalesce(jsonb_agg(s.periodo order by s.desde), '[]'::jsonb) into v_orden
    from (select p.periodo, p.desde
            from periodos p
           where p.tipo = 'mes'
             and not exists (select 1 from periodos q
                              where q.tipo in ('mes', 'apertura') and p.desde - 1 between q.desde and q.hasta)
          union
          select p.periodo, p.desde
            from periodos p
           where p.tipo in ('mes', 'apertura') and p.estado = 'cerrado'
             and exists (select 1 from periodos q
                          where q.tipo in ('mes', 'apertura') and q.estado = 'abierto' and q.desde < p.desde)
          union
          select p.periodo, p.desde
            from periodos p
            left join asientos fp on fp.hash = p.cadena_al_cerrar
           where p.tipo in ('mes', 'apertura') and p.estado = 'cerrado'
             and exists (select 1
                           from periodos q
                           left join asientos fq on fq.hash = q.cadena_al_cerrar
                          where q.tipo in ('mes', 'apertura') and q.estado = 'cerrado' and q.desde > p.desde
                            and (q.cerrado_el < p.cerrado_el or coalesce(fq.cadena_pos, 0) < coalesce(fp.cadena_pos, 0)))
          union
          select p.periodo, p.desde
            from periodos p
            left join asientos fp on fp.hash = p.cadena_al_cerrar
           where p.tipo = 'anio' and p.estado = 'cerrado'
             and exists (select 1
                           from periodos q
                           left join asientos fq on fq.hash = q.cadena_al_cerrar
                          where q.tipo <> 'anio' and q.anio = p.anio
                            and (q.estado <> 'cerrado' or q.cerrado_el > p.cerrado_el
                                 or coalesce(fq.cadena_pos, 0) > coalesce(fp.cadena_pos, 0)))
          union
          select p.periodo, p.desde
            from periodos p
            left join asientos fp on fp.hash = p.cadena_al_cerrar
           where p.tipo = 'anio' and p.estado = 'cerrado'
             and exists (select 1
                           from periodos q
                           left join asientos fq on fq.hash = q.cadena_al_cerrar
                          where q.tipo = 'anio' and q.anio < p.anio
                            and (q.estado <> 'cerrado' or q.cerrado_el > p.cerrado_el
                                 or coalesce(fq.cadena_pos, 0) > coalesce(fp.cadena_pos, 0)))) s;
  -- · cerrado antes de terminar: la hora del cierre, en Miami, no es
  --   posterior a su último día.
  select coalesce(jsonb_agg(p.periodo order by p.desde), '[]'::jsonb) into v_antes
    from periodos p
   where p.estado = 'cerrado' and fn_fecha_miami(p.cerrado_el) <= p.hasta;
  -- · la apertura: una sola, nada antes de ella, y si está cerrada, con su
  --   asiento de apertura VIVO dentro (sin su reverso de corrección): la
  --   misma condición que pide su guarda para cerrarla (B.5). Antes bastaba
  --   con que existiera, y una apertura reversada entera salía en verde.
  select coalesce(jsonb_agg(s.falla), '[]'::jsonb) into v_apert
    from (select format('hay %s aperturas: el libro tiene una sola', count(*)) as falla
            from periodos
           where tipo = 'apertura'
          having count(*) <> 1
          union all
          select format('%s va antes de la apertura', p.periodo)
            from periodos p
           where p.tipo in ('mes', 'apertura')
             and exists (select 1 from periodos a where a.tipo = 'apertura' and p.desde < a.desde)
          union all
          select format('la apertura %s está cerrada sin su asiento de apertura vivo (falta, o se reversó)', p.periodo)
            from periodos p
           where p.tipo = 'apertura' and p.estado = 'cerrado'
             and not exists (select 1 from asientos a
                              where a.periodo = p.periodo and a.tipo = 'apertura' and a.reversa_a is null
                                and not exists (select 1 from asientos r
                                                 where r.reversa_a = a.id and r.camino = 'reverso'))) s;
  control := 'periodos';
  ok      := jsonb_array_length(v_malos) = 0 and jsonb_array_length(v_orden) = 0
             and jsonb_array_length(v_antes) = 0 and jsonb_array_length(v_apert) = 0;
  detalle := jsonb_build_object('cerrados', (select count(*) from periodos where periodos.estado = 'cerrado'),
                                'tocados', v_malos, 'fuera_de_orden_o_con_hueco', v_orden,
                                'cerrados_antes_de_terminar', v_antes, 'apertura', v_apert);
  return next;

  -- triggers: los esperados, habilitados y con su función…
  select coalesce(jsonb_agg(jsonb_build_object('tabla', e.tabla, 'trigger', e.nombre,
                                               'estado', coalesce(t.tgenabled::text, 'NO EXISTE'))), '[]'::jsonb)
    into v_malos
    from (values ('cuentas',           'trg_cuentas_guarda',                'fn_cuentas_guarda'),
                 ('cuentas',           'trg_cuentas_sin_truncate',          'fn_cuentas_guarda'),
                 ('cuentas',           'trg_cuentas_historial',             'fn_cuentas_historial'),
                 ('cuentas_historial', 'trg_cuentas_historial_inmutable',   'fn_cuentas_historial_inmutable'),
                 ('cuentas_historial', 'trg_cuentas_historial_sin_truncate', 'fn_cuentas_historial_inmutable'),
                 ('periodos',          'trg_periodos_guarda',               'fn_periodos_guarda'),
                 ('periodos',          'trg_periodos_sin_truncate',         'fn_periodos_guarda'),
                 ('contadores',        'trg_contadores_guarda',             'fn_contadores_guarda'),
                 ('contadores',        'trg_contadores_sin_truncate',       'fn_contadores_guarda'),
                 ('contadores',        'trg_contadores_al_confirmar',       'fn_contadores_al_confirmar'),
                 ('asientos',          'trg_asientos_al_insertar',          'fn_asientos_al_insertar'),
                 ('asientos',          'trg_asientos_inmutable',            'fn_libro_inmutable'),
                 ('asientos',          'trg_asientos_sin_truncate',         'fn_libro_inmutable'),
                 ('asientos',          'trg_asientos_reversible_diferido',  'fn_asientos_reversible_con_reverso'),
                 ('asiento_lineas',    'trg_asiento_lineas_al_insertar',    'fn_asiento_lineas_al_insertar'),
                 ('asiento_lineas',    'trg_asiento_lineas_sello_diferido', 'fn_asiento_lineas_sello_al_confirmar'),
                 ('asiento_lineas',    'trg_asiento_lineas_inmutable',      'fn_libro_inmutable'),
                 ('asiento_lineas',    'trg_asiento_lineas_sin_truncate',   'fn_libro_inmutable'),
                 ('proyectos',         'trg_proyectos_con_libro',           'fn_proyectos_con_libro')) as e(tabla, nombre, funcion)
    left join pg_trigger t
           on t.tgrelid = to_regclass('public.' || e.tabla) and t.tgname = e.nombre and not t.tgisinternal
   where t.oid is null
      or t.tgenabled not in ('O', 'A')
      or t.tgfoid is distinct from to_regprocedure('public.' || e.funcion || '()')::oid;
  -- …y sus huellas: la definición de cada trigger del libro y de cada
  -- función del libro, y la forma de cada tabla del libro, contra las que
  -- dejó el último pegado (B.22). Una guarda vaciada con «create or
  -- replace», un trigger cambiado o uno nuevo sobre el libro, o una tabla
  -- reescrita por debajo de sus triggers (ALTER TABLE … TYPE … USING, que
  -- no dispara ninguno), no pasan callados.
  if to_regprocedure('public.fn_libro_huellas()') is null then
    v_mas := '["faltan las huellas (fn_libro_huellas): vuelve a pegar c2-libro.sql"]'::jsonb;
  else
    select coalesce(jsonb_agg(format('%s %s: %s', coalesce(h.tipo, a.tipo), coalesce(h.objeto, a.objeto),
                                     case when h.objeto is null then 'nuevo, no lo puso este archivo'
                                          when a.objeto is null then 'ya no está'
                                          when coalesce(h.tipo, a.tipo) = 'tabla'
                                            then 'se reescribió o cambió de forma desde que se pegó (si fue un '
                                                 'VACUUM FULL o una restauración, vuelve a pegar c2-libro.sql)'
                                          else 'cambió desde que se pegó' end)
                              order by coalesce(h.objeto, a.objeto)), '[]'::jsonb)
      into v_mas
      from (select * from fn_libro_huellas() x where x.tipo in ('trigger', 'funcion', 'tabla')) h
      full join (select * from fn_libro_huellas_calcular() y where y.tipo in ('trigger', 'funcion', 'tabla')) a
             on a.tipo = h.tipo and a.objeto = h.objeto
     where a.md5 is distinct from h.md5;
  end if;
  control := 'triggers';
  ok      := jsonb_array_length(v_malos) = 0 and jsonb_array_length(v_mas) = 0;
  detalle := jsonb_build_object('fallan', v_malos, 'huellas', v_mas);
  return next;

  -- cuentas: cada cuenta, tal como la dejó su último cambio apuntado en
  -- cuentas_historial (sin «creado», que se escribe con la zona horaria de
  -- la sesión y no cambia nunca). Por inclusión (@>) y no por igualdad: una
  -- columna que añada una versión futura de c1 no está en las filas viejas
  -- del historial, y eso no es un cambio escondido. Y ninguna cuenta del
  -- historial desapareció sin su fila de baja.
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (select format('%s no está como la dejó su último cambio en cuentas_historial', c.codigo) as falla
            from cuentas c
           where not exists (select 1
                               from cuentas_historial h
                              where h.codigo = c.codigo and h.operacion <> 'DELETE'
                                and h.cambiado_el = (select max(h2.cambiado_el) from cuentas_historial h2
                                                      where h2.codigo = c.codigo)
                                and (to_jsonb(c) - 'creado') @> (h.despues - 'creado'))
          union all
          select format('%s ya no está y su historial no dice que se borró', h.codigo)
            from cuentas_historial h
           where h.operacion <> 'DELETE'
             and h.cambiado_el = (select max(h2.cambiado_el) from cuentas_historial h2 where h2.codigo = h.codigo)
             and not exists (select 1 from cuentas c where c.codigo = h.codigo)
           limit 20) s;
  control := 'cuentas';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('cuentas', (select count(*) from cuentas), 'sin_rastro', v_malos);
  return next;

  -- permisos
  -- · Lo que lee o escribe el libro sin ser de este archivo, hasta que no
  --   aparezca nada nuevo: las vistas que leen sus tablas (directo o a
  --   través de otra vista) o que llaman a una función de estas; y las
  --   funciones que no son del reparto de B.20 y que nombran en su cuerpo
  --   una tabla del libro o una de esas vistas (detrás de from, join, into,
  --   update…), o llaman a una puerta interna (fn_postear_interno,
  --   fn_reversar_interno, fn_asiento_canonico), a fn_estado o a otra
  --   función de estas, o dependen de ellas (un cuerpo BEGIN ATOMIC).
  --   fn_estado lee con los permisos de quien la llama: desde una función
  --   SECURITY DEFINER, con los de su dueño, que se salta la policy. Las
  --   otras de conta.js miran es_dueno() por dentro y, llamadas desde
  --   donde sea, dicen que no. Se busca en todos los esquemas que no son
  --   del sistema, sin las funciones de las extensiones. Por el texto se
  --   caza el error honesto (el revoke que se olvidó en un pegado); un SQL
  --   dinámico armado a propósito para esconderse no se ve.
  select coalesce(array_agg(c.oid), '{}') into v_tablas
    from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relname = any (c_tablas);
  -- El reparto entero: el de este archivo y el de las fases que ya están.
  select coalesce(array_agg(f), '{}') into v_fases
    from unnest(c_fn_app_fases) f
   where to_regprocedure('public.' || f) is not null;
  v_app := c_fn_app || v_fases;
  select c_fn_internas || coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text), '{}')
    into v_int
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_puente\_%';
  v_fases := v_fases || (select coalesce(array_agg(p.oid::regprocedure::text), '{}')
                           from pg_proc p
                          where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_puente\_%');
  select coalesce(array_agg(to_regprocedure('public.' || f)::oid), '{}') into v_conocidas
    from unnest(v_app || v_int) f
   where to_regprocedure('public.' || f) is not null;
  select coalesce(array_agg(to_regprocedure('public.' || f)::oid), '{}') into v_semillas
    from unnest(array['fn_postear_interno(jsonb)', 'fn_reversar_interno(uuid,text,text,jsonb)',
                      'fn_asiento_canonico(asientos)', 'fn_estado(text)']) f
   where to_regprocedure('public.' || f) is not null;
  loop
    with recursive dep(oid) as (
           select x.oid
             from (select unnest(v_tablas) as oid
                   union
                   select rw.ev_class
                     from pg_depend d
                     join pg_rewrite rw on rw.oid = d.objid
                    where d.classid = 'pg_rewrite'::regclass and d.refclassid = 'pg_proc'::regclass
                      and (d.refobjid = any (v_semillas) or d.refobjid = any (v_lee))) x
           union
           select rw.ev_class
             from dep
             join pg_depend d on d.refobjid = dep.oid and d.refclassid = 'pg_class'::regclass
                             and d.classid = 'pg_rewrite'::regclass
             join pg_rewrite rw on rw.oid = d.objid
            where rw.ev_class <> dep.oid
         )
    select coalesce(array_agg(distinct dep.oid), '{}') into v_rel from dep;
    select coalesce(array_agg(distinct c.relname::text), '{}') into v_nombres
      from pg_class c
     where c.oid = any (v_rel) and c.relname ~ '^[[:alnum:]_]+$';
    select coalesce(array_agg(distinct p.proname::text), '{}') into v_fn_nombres
      from pg_proc p
     where (p.oid = any (v_semillas) or p.oid = any (v_lee)) and p.proname ~ '^[[:alnum:]_]+$';
    v_rx_rel := '[[:<:]](from|join|into|update|table|only|truncate)[[:space:]]+'
                || '(([[:alnum:]_]+|"[^"]+")[[:space:]]*[.][[:space:]]*)?"?('
                || array_to_string(v_nombres, '|') || ')"?[[:>:]]';
    v_rx_fn  := '[[:<:]](' || array_to_string(v_fn_nombres, '|') || ')[[:space:]]*[(]';
    select coalesce(array_agg(p.oid), '{}') into v_nuevas
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
       and p.prokind in ('f', 'p')
       and not (p.oid = any (v_lee) or p.oid = any (v_conocidas) or p.oid = any (v_semillas))
       and not exists (select 1 from pg_depend e
                        where e.classid = 'pg_proc'::regclass and e.objid = p.oid and e.deptype = 'e')
       and (   (cardinality(v_nombres) > 0 and p.prosrc ~* v_rx_rel)
            or (cardinality(v_fn_nombres) > 0 and p.prosrc ~* v_rx_fn)
            or exists (select 1 from pg_depend d
                        where d.classid = 'pg_proc'::regclass and d.objid = p.oid
                          and (   (d.refclassid = 'pg_class'::regclass and d.refobjid = any (v_rel))
                               or (d.refclassid = 'pg_proc'::regclass
                                   and (d.refobjid = any (v_semillas) or d.refobjid = any (v_lee))))));
    exit when cardinality(v_nuevas) = 0;
    v_lee := v_lee || v_nuevas;
  end loop;
  -- · De esas funciones, las que son peligro: SECURITY DEFINER (corren con
  --   los permisos de su dueño, que se salta la policy), no de trigger
  --   (esas no se pueden llamar sueltas), y que la API puede ejecutar.
  select coalesce(array_agg(p.oid), '{}') into v_sospechosas
    from pg_proc p
   where p.oid = any (v_lee) and p.prosecdef and p.prokind = 'f'
     and p.prorettype not in ('trigger'::regtype, 'event_trigger'::regtype)
     and exists (select 1 from unnest(array['anon', 'authenticated', 'service_role']) r
                  where has_schema_privilege(r, p.pronamespace, 'USAGE')
                    and has_function_privilege(r, p.oid, 'EXECUTE'));
  -- · Las vistas que llaman a una de esas (o leen otra vista que la llama):
  --   aunque sean security_invoker, la función se salta la policy.
  with recursive vf(oid) as (
         select rw.ev_class
           from pg_depend d
           join pg_rewrite rw on rw.oid = d.objid
          where d.classid = 'pg_rewrite'::regclass and d.refclassid = 'pg_proc'::regclass
            and d.refobjid = any (v_sospechosas)
         union
         select rw.ev_class
           from vf
           join pg_depend d on d.refobjid = vf.oid and d.refclassid = 'pg_class'::regclass
                           and d.classid = 'pg_rewrite'::regclass
           join pg_rewrite rw on rw.oid = d.objid
          where rw.ev_class <> vf.oid
       )
  select coalesce(array_agg(distinct vf.oid), '{}') into v_vistas_fn from vf;
  -- · Las vistas que leen las tablas del libro, directo o a través de otra
  --   vista: sin security_invoker, leen con los permisos de su dueño.
  with recursive dep(oid) as (
         select unnest(v_tablas)
         union
         select rw.ev_class
           from dep
           join pg_depend d on d.refobjid = dep.oid and d.refclassid = 'pg_class'::regclass
                           and d.classid = 'pg_rewrite'::regclass
           join pg_rewrite rw on rw.oid = d.objid
          where rw.ev_class <> dep.oid
       )
  select coalesce(array_agg(distinct dep.oid), '{}') into v_rel_vistas from dep;
  select coalesce(jsonb_agg(s.falla), '[]'::jsonb) into v_malos
    from (select format('falta la tabla %s (vuelve a pegar %s)', t,
                        case when t like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end) as falla
            from unnest(c_tablas) t
           where to_regclass('public.' || t) is null
          union all
          select format('%s sin RLS (vuelve a pegar %s)', t,
                        case when t like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(c_tablas) t
           where to_regclass('public.' || t) is not null
             and not (select c.relrowsecurity from pg_class c where c.oid = to_regclass('public.' || t))
          union all
          select format('%s: la policy %s_dueno falta o no es «solo el dueño lee» (select, permisiva, authenticated, '
                        'es_dueno()) (vuelve a pegar %s)', t, t,
                        case when t like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(c_tablas) t
           where not exists (select 1 from pg_policies pl
                              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname = t || '_dueno'
                                and pl.cmd = 'SELECT' and pl.permissive = 'PERMISSIVE'
                                and pl.roles = array['authenticated']::name[]
                                -- (las dos formas: «es_dueno()» y «(select
                                -- es_dueno())», que Postgres guarda como
                                -- «( SELECT es_dueno() AS es_dueno)»)
                                and regexp_replace(pl.qual, '[[:space:]]', '', 'g')
                                      in ('es_dueno()', '(SELECTes_dueno()ASes_dueno)'))
          union all
          select format('%s tiene una policy ajena: %s (vuelve a pegar %s: la borra)', pl.tablename, pl.policyname,
                        case when pl.tablename like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from pg_policies pl
           where pl.schemaname = 'public' and pl.tablename = any (c_tablas) and pl.policyname <> pl.tablename || '_dueno'
          union all
          -- privilegios de tabla: la API solo SELECT; anon y PUBLIC, nada
          select format('%s tiene %s en %s (vuelve a pegar %s)', case when a.grantee = 0 then 'PUBLIC' else r.rolname::text end,
                        a.privilege_type, c.relname,
                        case when c.relname like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from pg_class c
            cross join lateral aclexplode(c.relacl) a
            left join pg_roles r on r.oid = a.grantee
           where c.relnamespace = 'public'::regnamespace and c.relname = any (c_tablas)
             and (a.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
             and (a.grantee = 0 or r.rolname = 'anon' or a.privilege_type <> 'SELECT')
          union all
          -- privilegios por columna: a la API, ninguno
          select format('%s tiene %s en la columna %s.%s (vuelve a pegar %s)',
                        case when a.grantee = 0 then 'PUBLIC' else r.rolname::text end,
                        a.privilege_type, c.relname, at.attname,
                        case when c.relname like 'cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from pg_class c
            join pg_attribute at on at.attrelid = c.oid and at.attacl is not null
            cross join lateral aclexplode(at.attacl) a
            left join pg_roles r on r.oid = a.grantee
           where c.relnamespace = 'public'::regnamespace and c.relname = any (c_tablas)
             and (a.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
          union all
          -- una vista que lee el libro con los permisos de su dueño se salta la policy
          select format('la vista %s.%s lee el libro sin security_invoker (no es de c1 ni de c2: se le pone '
                        'with (security_invoker = true), o se quita)', n.nspname, c.relname)
            from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where c.oid = any (v_rel_vistas) and c.relkind = 'v'
             and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                where o.option_name = 'security_invoker'), false)
          union all
          -- una vista materializada no tiene RLS: lo que copia lo lee quien tenga grant
          select format('la vista materializada %s.%s copia el libro y la puede leer la API (no es de c1 ni de c2: '
                        'se le quita la API, o se quita)', n.nspname, c.relname)
            from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where c.oid = any (v_rel_vistas) and c.relkind = 'm'
             and (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT'))
          union all
          -- las funciones: ver B.20
          select format('falta la función %s (vuelve a pegar %s)', f,
                        case when f like 'fn_cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(c_fn_app || c_fn_internas) f
           where to_regprocedure('public.' || f) is null
          union all
          select format('anon ejecuta %s (vuelve a pegar %s)', f,
                        case when f = any (v_fases) then 'c3-puentes.sql'
                             when f like 'fn_cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(v_app || v_int) f
           where to_regprocedure('public.' || f) is not null
             and has_function_privilege('anon', to_regprocedure('public.' || f)::oid, 'execute')
          union all
          select format('authenticated ejecuta %s (vuelve a pegar %s)', f,
                        case when f = any (v_fases) then 'c3-puentes.sql'
                             when f like 'fn_cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(v_int) f
           where to_regprocedure('public.' || f) is not null
             and has_function_privilege('authenticated', to_regprocedure('public.' || f)::oid, 'execute')
          union all
          -- A service_role se le acepta EXECUTE en las de trigger: nadie las
          -- puede llamar sueltas, y es lo que les da e37-seguridad.sql, que
          -- se puede volver a pegar (ver B.20).
          select format('service_role ejecuta %s (vuelve a pegar %s)', f,
                        case when f = any (v_fases) then 'c3-puentes.sql'
                             when f like 'fn_cuentas%' then 'c1-plan-de-cuentas.sql' else 'c2-libro.sql' end)
            from unnest(v_app || v_int) f
            join pg_proc p on p.oid = to_regprocedure('public.' || f)
           where p.prorettype <> 'trigger'::regtype
             and has_function_privilege('service_role', p.oid, 'execute')
          union all
          -- una función ajena, SECURITY DEFINER, que lee o escribe el libro y la API ejecuta
          select format('la función %s es SECURITY DEFINER, lee o escribe el libro y la puede ejecutar %s. No es de c1 '
                        'ni de c2: o es SECURITY INVOKER, o se le quita la API (revoke execute on function … from '
                        'public, anon, authenticated, service_role); si conta.js la llama a propósito, mira es_dueno() '
                        'por dentro y va en el reparto de B.20 (c_fn_app, o c_fn_app_fases si es de una fase posterior, '
                        'en c2-libro.sql)', p.oid::regprocedure,
                        (select string_agg(r, ', ' order by r)
                           from unnest(array['anon', 'authenticated', 'service_role']) r
                          where has_schema_privilege(r, p.pronamespace, 'USAGE')
                            and has_function_privilege(r, p.oid, 'EXECUTE')))
            from pg_proc p
           where p.oid = any (v_sospechosas)
          union all
          -- y la vista que la llama
          select format('la vista %s.%s lee el libro a través de una función SECURITY DEFINER que la API puede '
                        'ejecutar: aunque sea security_invoker, esa función se salta la policy (no es de c1 ni de c2)',
                        n.nspname, c.relname)
            from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where c.oid = any (v_vistas_fn)) s;
  -- es_dueno(), el candado del libro, igual que cuando se pegó.
  if to_regprocedure('public.fn_libro_huellas()') is null then
    v_mas := '["faltan las huellas (fn_libro_huellas): vuelve a pegar c2-libro.sql"]'::jsonb;
  else
    select coalesce(jsonb_agg(format('%s cambió desde que se pegó c2-libro.sql: revisa que siga diciendo «solo el '
                                     'dueño activo» y vuelve a pegar el archivo para fijar su huella nueva',
                                     coalesce(h.objeto, a.objeto))), '[]'::jsonb)
      into v_mas
      from (select * from fn_libro_huellas() x where x.tipo = 'candado') h
      full join (select * from fn_libro_huellas_calcular() y where y.tipo = 'candado') a
             on a.objeto = h.objeto
     where a.md5 is distinct from h.md5;
  end if;
  control := 'permisos';
  ok      := jsonb_array_length(v_malos) = 0 and jsonb_array_length(v_mas) = 0;
  detalle := jsonb_build_object('fallan', v_malos || v_mas);
  return next;
end $$;
revoke execute on function public.fn_verificar_cadena() from public, anon, authenticated, service_role;
grant  execute on function public.fn_verificar_cadena() to authenticated;

-- ---------------------------------------------------------------------
-- B.17 · fn_cerrar_periodo(periodo) — el dueño cierra un período. Las
-- reglas (ya terminó, en orden, la apertura con su asiento, cuadre, read
-- committed, sello y hash del cierre) viven en el trigger de periodos, así
-- que valen igual si se cierra desde el SQL Editor. f08 pondrá delante sus
-- comprobaciones (conciliaciones, auxiliar = mayor…) y hará el export
-- DESPUÉS del cierre, en su propia transacción: el período ya no cambia.
-- ---------------------------------------------------------------------
create or replace function public.fn_cerrar_periodo(p_periodo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_p periodos;
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño cierra un período.';
  end if;
  -- MX002 y no P0002: PostgREST devuelve la clase P0 (salvo P0001) como un
  -- error 500 del servidor, y esto es un nombre mal escrito, no una caída.
  select * into v_p from periodos where periodo = p_periodo;
  if not found then
    raise exception using errcode = 'MX002',
      message = format('No existe el período «%s»: revisa el nombre (AAAA-MM para un mes, AAAA para un año, '
                       'AAAA-MM-APERTURA para la apertura) o ábrelo antes con fn_abrir_periodo.', coalesce(p_periodo, ''));
  end if;
  -- La hora, en Miami y sin segundos: la sesión de la API va en UTC, y un
  -- cierre de fin de mes por la noche saldría con otro día (u otro mes).
  if v_p.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('El período %s ya estaba cerrado (desde el %s, hora de Miami).', p_periodo,
                       to_char(v_p.cerrado_el at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI'));
  end if;
  update periodos set estado = 'cerrado' where periodo = p_periodo
  returning * into v_p;
  return to_jsonb(v_p);
end $$;
revoke execute on function public.fn_cerrar_periodo(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_cerrar_periodo(text) to authenticated;

-- ---------------------------------------------------------------------
-- B.18 · fn_abrir_periodo('AAAA-MM') — el dueño abre un mes (y su año, si
-- falta). Si ya existe y está abierto, lo devuelve tal cual; si está
-- cerrado, MX002: devolverlo sin más parecería que lo reabrió, y un
-- período cerrado no se reabre. Las reglas (no antes de la apertura, no
-- antes de un mes cerrado, año abierto, y sin huecos: el mes anterior
-- tiene que existir) viven en el trigger.
-- ---------------------------------------------------------------------
create or replace function public.fn_abrir_periodo(p_mes text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_desde    date;
  v_anio     int;
  v_paralelo boolean;
  v_p        periodos;
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño abre un período.';
  end if;
  if p_mes is null or p_mes !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception using errcode = '22023', message = format('El mes va como texto AAAA-MM (llegó «%s»).', coalesce(p_mes, ''));
  end if;
  v_desde := (p_mes || '-01')::date;
  v_anio  := extract(year from v_desde)::int;
  if not exists (select 1 from periodos where periodo = v_anio::text) then
    insert into periodos (periodo, tipo, anio, desde, hasta, paralelo)
    values (v_anio::text, 'anio', v_anio, make_date(v_anio, 1, 1), make_date(v_anio, 12, 31), false);
  end if;
  select paralelo into v_paralelo from periodos where periodo = v_anio::text;
  if not exists (select 1 from periodos where periodo = p_mes) then
    insert into periodos (periodo, tipo, anio, desde, hasta, paralelo)
    values (p_mes, 'mes', v_anio, v_desde, (v_desde + interval '1 month')::date - 1, v_paralelo);
  end if;
  select * into v_p from periodos where periodo = p_mes;
  if v_p.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('El mes %s ya existe y está cerrado (desde el %s, hora de Miami): un período cerrado no se '
                       'reabre. Un ajuste va al período abierto (tipo ajuste_cpa con afecta_periodo).', p_mes,
                       to_char(v_p.cerrado_el at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI'));
  end if;
  return to_jsonb(v_p);
end $$;
revoke execute on function public.fn_abrir_periodo(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_abrir_periodo(text) to authenticated;


-- ---------------------------------------------------------------------
-- B.19 · Una obra con asientos no se borra ni cambia de id (MX003). La FK
-- de asiento_lineas.proyecto_id ya lo impedía, pero con un 23503 que la
-- app traduce como «eso apunta a algo que ya no existe»: falso, la obra
-- existe y lo que la protege es el libro. Este trigger lo dice claro, y
-- enCristiano deja pasar los MX tal cual: por eso el mensaje dice la
-- obra por su NOMBRE (el que Edgar ve en la app, no el id interno) y lo
-- que sí se puede hacer HOY en la app, que no tiene «archivar»: marcarla
-- Completado (o No aprobado). SECURITY DEFINER porque tiene que ver
-- TODAS las líneas del libro, sea quien sea quien borra (con RLS, alguien
-- que no es el dueño vería cero y el mensaje se perdería).
-- ---------------------------------------------------------------------
create or replace function public.fn_proyectos_con_libro()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and new.id is not distinct from old.id then
    return new;
  end if;
  if exists (select 1 from asiento_lineas where proyecto_id = old.id) then
    if tg_op = 'DELETE' then
      raise exception using errcode = 'MX003',
        message = format('La obra «%s» ya tiene movimientos en el libro contable: no se puede borrar. Si ya no se trabaja '
                         'en ella, márcala Completado (o No aprobado).', coalesce(nullif(btrim(old.nombre), ''), old.id));
    end if;
    raise exception using errcode = 'MX003',
      message = format('La obra «%s» ya tiene movimientos en el libro contable: su id (%s) ya no cambia.',
                       coalesce(nullif(btrim(old.nombre), ''), old.id), old.id);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke execute on function public.fn_proyectos_con_libro() from public, anon, authenticated, service_role;

create or replace trigger trg_proyectos_con_libro
  before delete or update of id on public.proyectos
  for each row execute function public.fn_proyectos_con_libro();

-- ---------------------------------------------------------------------
-- B.20 · Quién ejecuta. En Supabase toda función nace ejecutable por anon
-- y authenticated; por eso cada función de este archivo lleva su revoke
-- JUSTO DESPUÉS de crearla (arriba). El reparto queda así:
--   · internas (triggers, auxiliares, las dos puertas internas, las
--     huellas): nadie de la API; solo el dueño de la base y las funciones
--     SECURITY DEFINER;
--   · las que llama conta.js (fn_postear, fn_reversar, fn_estado,
--     fn_verificar_cadena, fn_abrir_periodo, fn_cerrar_periodo,
--     fn_fecha_miami): solo authenticated, y por dentro solo pasa el
--     dueño; ni anon ni service_role.
-- fn_verificar_cadena comprueba este reparto cada vez (control permisos).
-- Una excepción, a propósito: a service_role se le acepta EXECUTE en las
-- funciones de trigger. docs/sql/e37-seguridad.sql (ya en producción, y se
-- puede volver a pegar) se lo da a todas las de trigger de public, y no
-- abre nada: una función de trigger no se puede llamar suelta, y al
-- dispararse no se mira ese permiso. Sin la excepción, volver a pegar e37
-- ponía el control en rojo por nada, y un control que grita por nada deja
-- de creerse. Este archivo y c1 se lo siguen quitando al pegarse.
--
-- LA REGLA PARA LAS FASES QUE VIENEN (f03, f04, f05, f08…): una función
-- que lee o escribe el libro es SECURITY INVOKER (entonces la policy
-- manda, y no hace falta nada más), o, si tiene que ser SECURITY DEFINER:
-- lleva justo después su revoke de public, anon, authenticated y
-- service_role; si la llama la app a propósito, mira es_dueno() por dentro
-- y se añade a c_fn_app_fases (B.16) y a las huellas (B.22) de ESTE
-- archivo, que la conoce de antemano y la mira solo si ya existe. Las
-- internas de los puentes de f03 se llaman fn_puente_… (singular): el
-- verificador y las huellas las encuentran por el prefijo, y ninguna la
-- ejecuta nadie de la API. La fase termina su archivo resellando las
-- huellas con fn_libro_huellas_sellar() (B.22).
-- Una vista contable es security_invoker, y no llama a una función SECURITY
-- DEFINER que lea el libro. El control permisos da en rojo lo que se salga
-- de esto: una SECURITY DEFINER que nombra una tabla del libro (o una vista
-- que lo lee, o una puerta interna, o fn_estado) y que la API puede
-- ejecutar, y la vista que la llama. En Supabase toda función nace
-- ejecutable por anon: el revoke olvidado es el error más probable.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- B.21 · Lo que un auditor lee en pg_description (de aquí sale
-- docs/conta/MAPA-DATOS.md).
-- ---------------------------------------------------------------------
comment on table public.periodos is
  'Períodos contables (c2): un mes, la apertura (30-sep-2026, una sola) o un año. Nacen abiertos, seguidos y sin huecos; se cierran '
  'cuando ya terminaron (hora de Miami), en orden (la apertura primero, con su asiento de apertura; cada año después del anterior) y '
  'no se reabren ni se borran. Nadie escribe en un período cerrado.';
comment on column public.periodos.periodo          is 'AAAA-MM (mes), AAAA-MM-APERTURA o AAAA (año).';
comment on column public.periodos.tipo             is 'mes, apertura o anio.';
comment on column public.periodos.estado           is 'abierto o cerrado. De cerrado no se vuelve.';
comment on column public.periodos.paralelo         is 'true = marcha en paralelo con QuickBooks (octubre–diciembre de 2026 y la apertura): los libros oficiales de ese año son los de QuickBooks.';
comment on column public.periodos.cerrado_el       is 'Cuándo se cerró (lo pone la base).';
comment on column public.periodos.cerrado_por      is 'auth.uid() de quien lo cerró; nulo si fue desde el SQL Editor.';
comment on column public.periodos.cerrado_rol      is 'Rol con que se cerró: authenticated (la app) o el dueño de la base (SQL Editor).';
comment on column public.periodos.cerrado_conexion is 'Si lo cerró una conexión directa del dueño de la base (SQL Editor, pg_cron, SUPABASE_DB_URL): application_name, cliente y puerto. Nulo si fue por la app.';
comment on column public.periodos.cadena_al_cerrar is 'Hash de la cadena del libro en el instante del cierre: la foto que se comprueba después (dentro de la base; el ancla que vale contra el dueño de la base es la exportada en f08).';

comment on table public.contadores is
  'Numeración sin huecos (c2). Una fila por serie y año (asientos-2027). Solo avanza de uno en uno, y el de asientos solo al numerar '
  'un asiento: al confirmar, cada contador está en el número de su último asiento.';

comment on table public.asientos is
  'Cabecera de cada asiento del libro (c2). No se edita ni se borra: se corrige con fn_reversar. Número, período, sello y hash los pone la base.';
comment on column public.asientos.numero         is 'AAAA-NNNNNN, correlativo por año y sin huecos.';
comment on column public.asientos.cadena_pos     is 'Posición en la cadena de hashes (orden de posteo, en todo el libro).';
comment on column public.asientos.fecha_contable is 'La fecha del asiento, en hora de Miami. Decide el período.';
comment on column public.asientos.periodo        is 'El período que contiene la fecha. Lo pone la base.';
comment on column public.asientos.tipo           is 'normal, apertura o ajuste_cpa. El reverso o el sustituto de un asiento de un ejercicio anterior es un ajuste_cpa de ese ejercicio, salvo el sustituto de un papel que ya es del año nuevo (procedencia.fecha_documento de ese año): ese es normal.';
comment on column public.asientos.afecta_periodo is 'Solo ajuste_cpa: el período cerrado al que corresponde el ajuste (en el reverso de un asiento de un ejercicio anterior, el período del original).';
comment on column public.asientos.camino         is 'Por dónde entró: mano (el dueño), puente (automático, desde un documento), ia (propuesta aprobada, f07), reverso o reverso_automatico.';
comment on column public.asientos.descripcion    is 'Qué es el asiento, en palabras.';
comment on column public.asientos.motivo         is 'Por qué: obligatorio en un reverso y en un ajuste del CPA.';
comment on column public.asientos.reversa_a      is 'El asiento que este reversa. A lo sumo un reverso por camino: el de corrección (reverso) y, en un devengo, su reverso automático del día 1. Un reverso no se reversa, salvo el automático de un devengo corregido en su mes, que se anula junto con esa corrección.';
comment on column public.asientos.reversible     is 'true = devengo de cierre: nace con su reverso automático el día 1 del mes siguiente. Sigue vivo para su documento con ese reverso; se corrige dentro de su mes con fn_reversar.';
comment on column public.asientos.origen_tabla   is 'Tabla del documento origen (recibos, facturas…). Un documento, un asiento vivo (el reversado se sustituye).';
comment on column public.asientos.origen_id      is 'Id del documento origen, como texto.';
comment on column public.asientos.sustituye_a    is 'El asiento REVERSADO del mismo documento al que este sustituye (una corrección del mapeo, un documento des-anulado). Único.';
comment on column public.asientos.documento_ruta is 'Ruta del papel en Storage cuando no hay fila origen (la balanza de apertura en PDF…).';
comment on column public.asientos.propuesta_id   is 'Reservado para f07: la propuesta de la IA aprobada (ia_propuestas.id, uuid). OJO: no es la tabla propuestas, que son las de los clientes.';
comment on column public.asientos.procedencia    is 'El sello del camino: qué función lo posteó y lo que el puente dejó escrito (p. ej. la nota de un documento tardío, y fecha_documento: la fecha de su papel). '
                                                    'Lo pone la base: «conexion» (application_name, cliente, puerto) si entró por una conexión directa del dueño de la base; '
                                                    '«puerta» = insert_directo si sus líneas no pasaron por fn_postear_interno (sin la mirada de la escala: numeric(14,2) redondeó).';
comment on column public.asientos.usuario_id     is 'auth.uid() de la sesión que lo posteó (en un puente, quien subió el papel); nulo desde el SQL Editor.';
comment on column public.asientos.rol_bd         is 'Rol con que entró: authenticated (la app), o el dueño de la base (SQL Editor, pg_cron).';
comment on column public.asientos.creado_el      is 'Cuándo se posteó (hora del servidor).';
comment on column public.asientos.hash_anterior  is 'Hash del asiento anterior en la cadena (64 ceros el primero).';
comment on column public.asientos.hash           is 'sha256 de fn_asiento_canonico: el asiento entero, sus líneas y el hash anterior.';

comment on table public.asiento_lineas is
  'Líneas del libro (c2). Monto con signo: positivo = debe, negativo = haber; cada asiento suma cero. No se editan ni se borran.';
comment on column public.asiento_lineas.orden       is 'Posición de la línea dentro de su asiento.';
comment on column public.asiento_lineas.cuenta      is 'Cuenta del plan (cuentas.codigo).';
comment on column public.asiento_lineas.monto       is 'numeric(14,2), nunca cero. Positivo = debe, negativo = haber. Más de dos decimales: fn_postear los rechaza (MX005); un insert directo los redondea y su asiento queda marcado (procedencia.puerta).';
comment on column public.asiento_lineas.proyecto_id is 'Dimensión obra (proyectos.id). La exige o la prohíbe cuentas.regla_obra.';
comment on column public.asiento_lineas.cost_code   is 'Dimensión cost code (codigos_partida.codigo), opción B de f01. La exige o la prohíbe cuentas.regla_cost_code.';
comment on column public.asiento_lineas.co          is 'Change Order, copiado tal cual del origen (la FK a alcances llega en f10).';
comment on column public.asiento_lineas.fase        is 'Fase de la obra, opcional.';
comment on column public.asiento_lineas.memo        is 'Nota de la línea.';
comment on column public.asiento_lineas.tercero_tipo  is 'Con quién es el saldo (f03): proveedor (proveedores.id) o empleado (perfiles.id). Va con tercero_id, los dos o ninguno.';
comment on column public.asiento_lineas.tercero_id    is 'El id del tercero (uuid). Así sale lo que se le debe a cada supply (2010 por proveedor) y a cada empleado (2250).';
comment on column public.asiento_lineas.partida_tabla is 'La partida abierta que la línea crea o salda (f03): recibos, facturas, trabajos_externos o cobros (un anticipo).';
comment on column public.asiento_lineas.partida_id    is 'El id de esa partida. Lo abierto es la partida cuya suma, en su cuenta, no es cero. Un reverso copia tercero y partida.';

comment on function public.fn_postear(jsonb)          is 'Postea un asiento a mano (solo el dueño). Devuelve id, número, período y hash.';
comment on function public.fn_reversar(uuid, text)    is 'Reversa un asiento con su motivo (solo el dueño). Una vez; un reverso no se reversa. Un devengo, dentro de su mes, y anulando su reverso del día 1. El de un ejercicio anterior sale como ajuste de ese ejercicio; la apertura cerrada no se reversa (se ajusta).';
comment on function public.fn_estado(text)           is 'Fila de control de un período: asientos, filas, debe, haber y si cuadra.';
comment on function public.fn_verificar_cadena()      is 'Verifica hashes, enlaces, numeración, contadores, cuadre, reversos, cierres, triggers y tablas, cuentas contra su historial, y permisos.';
comment on function public.fn_cerrar_periodo(text)    is 'Cierra un período ya terminado (solo el dueño), en orden. No se reabre.';
comment on function public.fn_abrir_periodo(text)     is 'Abre un mes AAAA-MM y su año si falta (solo el dueño). Uno cerrado no se reabre (MX002).';
comment on function public.fn_fecha_miami(timestamptz) is 'La fecha en hora de Miami (America/New_York), calculada en SQL.';
comment on function public.fn_postear_interno(jsonb)  is 'La puerta interna de todo posteo (puentes, IA aprobada). Sin grant a la API.';
comment on function public.fn_reversar_interno(uuid, text, text, jsonb) is 'La única fábrica de reversos: las líneas espejo salen de la base. Sin grant a la API.';
comment on function public.fn_asiento_canonico(public.asientos) is 'El texto exacto que se sella con sha256: el asiento, sus líneas y el hash anterior.';
comment on function public.fn_proyectos_con_libro()   is 'Una obra con asientos en el libro no se borra ni cambia de id (MX003): se marca Completado o No aprobado.';


-- ---------------------------------------------------------------------
-- B.22 · Las huellas. Lo ÚLTIMO del archivo, con todo ya puesto: el md5
-- de la definición de cada trigger del libro, de cada función del libro,
-- de la forma de cada tabla del libro y de es_dueno(). fn_verificar_cadena
-- las compara cada vez (controles triggers y permisos): una guarda vaciada
-- con «create or replace», un trigger cambiado o añadido sobre el libro,
-- una tabla reescrita por debajo de sus triggers, o un es_dueno()
-- distinto, ya no pasan callados.
--   · La huella de una TABLA es su archivo en disco (relfilenode), su
--     dueño, sus columnas (nombre, tipo, not null, default), sus
--     restricciones y sus índices. Un «ALTER TABLE … ALTER COLUMN … TYPE
--     … USING (case …)» reescribe las filas que quiera SIN disparar ningún
--     trigger (así se reabría un mes cerrado o se inactivaba una cuenta
--     con saldo sin dejar rastro): al reescribir la tabla le da un archivo
--     nuevo, y eso cambia su huella. También la cambia quitar una
--     restricción o un índice (p. ej. la unicidad de la apertura). Un
--     VACUUM FULL, un CLUSTER o una restauración con pg_restore también
--     reescriben: después de uno legítimo, se vuelve a pegar este archivo.
--   · fn_libro_huellas_calcular() dice QUÉ se vigila y calcula las huellas
--     de hoy (con su search_path fijo, para que los nombres salgan igual
--     siempre).
--   · fn_libro_huellas() guarda las de este pegado: se reescribe aquí,
--     cada vez que se pega el archivo, con los valores literales.
-- Solo frena ACCIDENTES y cambios torpes: quien es dueño de la base puede
-- rehacer las huellas (basta con volver a pegar el archivo). Si un cambio
-- legítimo toca una guarda (una versión nueva de c1 o de c2, o Planos
-- cambia es_dueno), el control sale en rojo hasta que se vuelve a pegar
-- c2-libro.sql: es lo que se quiere, que alguien lo mire.
-- LAS FASES QUE VIENEN DETRÁS (c3…): sus funciones que tocan el libro y
-- sus triggers se vigilan desde aquí también, por nombre (las que llama la
-- app, la misma lista que c_fn_app_fases) o por prefijo (fn_puente_… y
-- trg_puente_…, en cualquier tabla); lo que todavía no existe no da fila.
-- Por eso una fase termina su archivo resellando con
-- fn_libro_huellas_sellar(), y lo EMPIEZA comprobando que el control
-- triggers está en verde: si resellara encima de una guarda tocada, la
-- bendeciría.
-- ---------------------------------------------------------------------
create or replace function public.fn_libro_huellas_calcular()
returns table (tipo text, objeto text, md5 text)
language sql
stable
set search_path = public, pg_temp
as $$
  select 'trigger'::text, c.relname || '.' || t.tgname, md5(pg_get_triggerdef(t.oid))
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
   where c.relnamespace = 'public'::regnamespace
     and not t.tgisinternal
     and (   c.relname in ('cuentas', 'cuentas_historial', 'periodos', 'contadores', 'asientos', 'asiento_lineas')
          or (c.relname = 'proyectos' and t.tgname = 'trg_proyectos_con_libro')
          or t.tgname like 'trg\_puente\_%')
  union all
  select 'funcion'::text, p.oid::regprocedure::text, md5(pg_get_functiondef(p.oid))
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and (   p.proname in ('fn_cuentas_guarda', 'fn_cuentas_historial', 'fn_cuentas_historial_inmutable',
                           'fn_fecha_miami', 'fn_rol_llamante', 'fn_desde_editor', 'fn_asiento_canonico',
                           'fn_periodos_guarda', 'fn_contadores_guarda', 'fn_contadores_al_confirmar',
                           'fn_asiento_lineas_al_insertar',
                           'fn_asiento_lineas_sello_al_confirmar', 'fn_asientos_al_insertar', 'fn_libro_inmutable',
                           'fn_asientos_reversible_con_reverso', 'fn_postear_interno', 'fn_postear',
                           'fn_reversar_interno', 'fn_reversar', 'fn_estado', 'fn_verificar_cadena',
                           'fn_cerrar_periodo', 'fn_abrir_periodo', 'fn_proyectos_con_libro',
                           'fn_libro_huellas_calcular', 'fn_libro_huellas_sellar',
                           -- f03 · c3-puentes.sql (las que llama la app)
                           'fn_puentes_correr', 'fn_puentes_rehacer', 'fn_puentes_verificar', 'fn_puentes_cuenta',
                           'fn_factura_anular', 'fn_cobro_registrar', 'fn_cobro_anular', 'fn_cobro_devolver',
                           'fn_anticipo_aplicar',
                           'fn_horas_aprobar', 'fn_horas_desaprobar', 'fn_horas_devengar', 'fn_recibo_anular',
                           'fn_externo_anular', 'fn_mapeo_categoria', 'fn_mapeo_metodo_pago', 'fn_mapeo_tipo_proyecto',
                           'fn_mapeo_confirmar', 'fn_tarjeta_alta', 'fn_proveedor_alta', 'fn_proveedor_alias',
                           'fn_puentes_antes_del_corte', 'fn_puentes_confirmar', 'fn_recibo_desanular')
          or p.proname like 'fn\_puente\_%')
  union all
  select 'tabla'::text, c.relname,
         md5(concat_ws(' | ',
               c.relfilenode::text,
               pg_get_userbyid(c.relowner),
               (select string_agg(format('%s %s %s %s', a.attname, format_type(a.atttypid, a.atttypmod),
                                         case when a.attnotnull then 'not null' else 'null' end,
                                         coalesce(pg_get_expr(d.adbin, d.adrelid), '-')), ', ' order by a.attnum)
                  from pg_attribute a
                  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
                 where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped),
               (select string_agg(co.conname || ' ' || pg_get_constraintdef(co.oid), ', ' order by co.conname)
                  from pg_constraint co
                 where co.conrelid = c.oid),
               (select string_agg(pg_get_indexdef(i.indexrelid), ', ' order by pg_get_indexdef(i.indexrelid))
                  from pg_index i
                 where i.indrelid = c.oid)))
    from pg_class c
   where c.relnamespace = 'public'::regnamespace
     and c.relkind in ('r', 'p')
     and c.relname in ('cuentas', 'cuentas_historial', 'periodos', 'contadores', 'asientos', 'asiento_lineas')
  union all
  select 'candado'::text, p.oid::regprocedure::text, md5(pg_get_functiondef(p.oid))
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'es_dueno'
$$;
revoke execute on function public.fn_libro_huellas_calcular() from public, anon, authenticated, service_role;

-- El sello: reescribe fn_libro_huellas() con las huellas de este momento,
-- como valores literales, y deja escrito en su comentario quién selló y
-- cuándo (hora de Miami). La llama este archivo al final, y la llaman al
-- final los archivos de las fases (c3…) que ponen triggers o funciones que
-- se vigilan desde aquí. Sin grant a nadie de la API: solo el SQL Editor.
create or replace function public.fn_libro_huellas_sellar(p_quien text default 'c2-libro.sql')
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_filas text;
  v_n     int;
begin
  select string_agg(format('(%L, %L, %L)', h.tipo, h.objeto, h.md5), E',\n    ' order by h.tipo, h.objeto), count(*)
    into v_filas, v_n
    from public.fn_libro_huellas_calcular() h;
  execute format($f$
    create or replace function public.fn_libro_huellas()
    returns table (tipo text, objeto text, md5 text)
    language sql
    immutable
    set search_path = public, pg_temp
    as $b$
      select * from (values
    %s
      ) as v(tipo, objeto, md5)
    $b$
  $f$, v_filas);
  execute 'revoke execute on function public.fn_libro_huellas() from public, anon, authenticated, service_role';
  execute format('comment on function public.fn_libro_huellas() is %L',
                 'Las huellas (md5) de las guardas, las funciones y las tablas del libro y es_dueno(), selladas por el último '
                 'pegado de ' || coalesce(nullif(btrim(p_quien), ''), '(sin nombre)') || ', el '
                 || to_char(now() at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI') || ' (Miami).');
  return v_n;
end $$;
revoke execute on function public.fn_libro_huellas_sellar(text) from public, anon, authenticated, service_role;

do $$
begin
  perform public.fn_libro_huellas_sellar('c2-libro.sql');
end $$;


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: los diez controles, en true.
-- =====================================================================
select * from public.fn_verificar_cadena();
