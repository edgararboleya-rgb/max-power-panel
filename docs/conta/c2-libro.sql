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
--   A · Las tablas y unas funciones MÍNIMAS, sin controles. Existen para
--       probar en rojo: con solo el bloque A, c2-pruebas.sql tiene que
--       fallar porque los ataques ENTRAN, no porque falte una función.
--       Las mínimas se crean SOLO si la función no existe: pegar el
--       archivo por segunda vez nunca baja un control, ni un instante.
--   B · Los controles: triggers, numeración, cadena de hashes, período,
--       reverso, las funciones de verdad, RLS y permisos.
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código ANTES
-- de que enCristiano los pise):
--   MX000  falta algo que el archivo da por hecho (precondición)
--   MX001  descuadre: debe ≠ haber, o menos de dos líneas
--   MX002  período: cerrado, inexistente, de apertura, cierre fuera de
--          orden, o un intento de reabrir
--   MX003  inmutable: update, delete o truncate del libro; una línea
--          nueva en un asiento ya sellado; un contador que salta
--   MX004  cuenta: no existe, está inactiva o es de grupo
--   MX005  monto: más de dos decimales, cero, no numérico o fuera de rango
--   MX006  dimensión: la obra, el cost code, el co o la fase no son los
--          que pide la cuenta (cuentas.regla_obra / regla_cost_code)
--   MX007  reverso: ya reversado, reversar un reverso, reverso que no es
--          el espejo exacto, o un reversible sin su reverso del día 1
--   42501  permiso: solo el dueño postea; anon y service_role, nada
--   22023  entrada mal formada (clave desconocida, camino no válido…)
--   22007  fecha que no viene como texto AAAA-MM-DD
--   23505  en asientos_origen_unico: ese documento ya tiene su asiento
--          (la idempotencia de los puentes de f03)
--
-- QUIÉN LLAMA QUÉ (la frontera se decide aquí):
--   · El dueño, por RPC desde conta.js (grant a authenticated; cada
--     función comprueba es_dueno() por dentro):
--       fn_postear(asiento jsonb)         camino 'mano'
--       fn_reversar(asiento uuid, motivo) camino 'reverso'
--       fn_estado(periodo)                la fila de control (lee con RLS)
--       fn_verificar_cadena()             hashes, numeración, triggers, permisos
--       fn_abrir_periodo('AAAA-MM'), fn_cerrar_periodo(periodo)
--       fn_fecha_miami(t)                 «hoy» en Miami, calculado en SQL
--     Y lee directo (select, con la policy solo-dueño) cuentas, periodos,
--     contadores, asientos y asiento_lineas.
--   · Solo por dentro (sin grant a ningún rol de la API):
--       fn_postear_interno(asiento jsonb)  la usan los puentes de f03
--         (SECURITY DEFINER, camino 'puente', con su documento de origen)
--         y fn_aprobar de f07 (camino 'ia');
--       fn_reversar_interno(...)           la usan fn_reversar, el reverso
--         automático y los puentes (un recibo anulado se reversa).
--   · El SQL Editor (el dueño de la base) puede llamar a todas. Queda
--     escrito en cada asiento como rol_bd = 'postgres'.
--   · service_role (las funciones de borde, la IA) solo LEE: no ejecuta
--     ninguna función que escriba. «La IA propone, nunca postea» lo
--     garantiza la base, no la buena voluntad del código.
--
-- CÓMO SE ABRE Y SE CIERRA UN PERÍODO:
--   · Aquí nacen abiertos: la apertura (2026-09-APERTURA, solo el día
--     30-sep), octubre–diciembre de 2026 (paralelo) y los doce meses de
--     2027, más un período por año (2026 y 2027). Los meses de 2028 se
--     abren con fn_abrir_periodo('2028-01') (abre también el año).
--   · Se cierra con fn_cerrar_periodo(periodo), o con un update del
--     estado desde el SQL Editor: el trigger de periodos valida igual por
--     los dos caminos. Los meses se cierran en orden; la apertura cuando
--     se cuadre (semana del 18-ene); el año, cuando todos sus meses estén
--     cerrados (tras los ajustes del CPA). Al cerrar se guarda el hash de
--     la cadena en ese momento (cadena_al_cerrar).
--   · Un período cerrado NO se reabre (regla A de f08): los ajustes van
--     al período abierto, con tipo 'ajuste_cpa' y afecta_periodo.
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
    execute 'revoke execute on function public.fn_fecha_miami(timestamptz) from public, anon';
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

create index if not exists asientos_periodo_idx on public.asientos (periodo);
create index if not exists asientos_origen_idx  on public.asientos (origen_tabla, origen_id) where origen_tabla is not null;

-- ---------------------------------------------------------------------
-- A.5 · asiento_lineas — las líneas. Monto con signo: positivo = debe,
-- negativo = haber. El asiento cuadra cuando suman cero.
-- La FK a la cabecera es DIFERIDA a propósito: las líneas entran PRIMERO
-- y la cabecera DESPUÉS, para que el trigger de la cabecera las vea todas
-- al calcular el cuadre y el hash. Una línea sin cabecera no llega viva
-- al commit.
-- ---------------------------------------------------------------------
create table if not exists public.asiento_lineas (
  id           bigint        generated always as identity primary key,
  asiento_id   uuid          not null references public.asientos (id) deferrable initially deferred,
  orden        int           not null,
  cuenta       text          not null references public.cuentas (codigo),
  monto        numeric(14,2) not null,
  proyecto_id  text          references public.proyectos (id),
  cost_code    text          references public.codigos_partida (codigo),
  co           text,
  fase         text,
  memo         text,
  constraint asiento_lineas_orden_unico     unique (asiento_id, orden),
  constraint asiento_lineas_orden_positivo  check (orden >= 1),
  constraint asiento_lineas_monto_no_cero   check (monto <> 0)
);

create index if not exists asiento_lineas_cuenta_idx   on public.asiento_lineas (cuenta);
create index if not exists asiento_lineas_proyecto_idx on public.asiento_lineas (proyecto_id) where proyecto_id is not null;

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
