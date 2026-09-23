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
--          que pide la cuenta (cuentas.regla_obra / regla_cost_code), o
--          un asiento de apertura con cuentas de resultados
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


-- ---------------------------------------------------------------------
-- A.7 · Las funciones MÍNIMAS, sin controles. Mismo nombre, mismos
-- parámetros y mismo resultado que las de verdad del bloque B, para que
-- c2-pruebas.sql corra entero en rojo y cada ataque diga «entró».
-- Se crean SOLO si no existen: al volver a pegar el archivo, las de
-- verdad siguen puestas. Llevan los revoke de la regla de siempre desde
-- el primer momento (toda función nueva nace ejecutable por anon).
-- ---------------------------------------------------------------------
do $$
begin
  -- fn_postear MÍNIMA: sin permisos, sin cuadre, sin escala, sin período
  -- cerrado, sin cuentas ni dimensiones, sin reverso automático, sin
  -- cadena (hash de ceros), numerando con max + 1.
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
    execute 'revoke execute on function public.fn_postear(jsonb) from public, anon';
    execute 'revoke execute on function public.fn_postear(jsonb) from authenticated';
    execute 'grant execute on function public.fn_postear(jsonb) to authenticated';
  end if;

  -- fn_reversar MÍNIMA: espejo con la fecha del original, sin mirar si ya
  -- se reversó, si es un reverso ni si su período está cerrado.
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
    execute 'revoke execute on function public.fn_reversar(uuid, text) from public, anon';
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
    execute 'revoke execute on function public.fn_estado(text) from public, anon';
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
    execute 'revoke execute on function public.fn_verificar_cadena() from public, anon';
    execute 'revoke execute on function public.fn_verificar_cadena() from authenticated';
    execute 'grant execute on function public.fn_verificar_cadena() to authenticated';
  end if;

  -- fn_cerrar_periodo MÍNIMA: cierra sin mirar quién, orden ni cuadre.
  if to_regprocedure('public.fn_cerrar_periodo(text)') is null then
    execute $f$
      create function public.fn_cerrar_periodo(p_periodo text) returns jsonb
      language plpgsql security definer
      set search_path = public, pg_temp
      as $b$
      declare
        v_p periodos;
      begin
        update periodos set estado = 'cerrado', cerrado_el = now()
         where periodo = p_periodo
        returning * into v_p;
        return to_jsonb(v_p);
      end
      $b$
    $f$;
    execute 'revoke execute on function public.fn_cerrar_periodo(text) from public, anon';
    execute 'revoke execute on function public.fn_cerrar_periodo(text) from authenticated';
    execute 'grant execute on function public.fn_cerrar_periodo(text) to authenticated';
  end if;

  -- fn_abrir_periodo MÍNIMA: abre sin mirar quién.
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
    execute 'revoke execute on function public.fn_abrir_periodo(text) from public, anon';
    execute 'revoke execute on function public.fn_abrir_periodo(text) from authenticated';
    execute 'grant execute on function public.fn_abrir_periodo(text) to authenticated';
  end if;
end $$;


-- ==== BLOQUE B ====
-- =====================================================================
-- Los controles. Todo lo que sigue se puede volver a pegar: funciones con
-- «create or replace», triggers con «create or replace trigger» (sin un
-- instante sin guarda), restricciones solo si faltan.
-- =====================================================================

-- ---------------------------------------------------------------------
-- B.0 · Quién lee. Lo PRIMERO del bloque B: las tablas del bloque A nacen
-- abiertas (así es Supabase) y aquí se cierran antes que nada. Es el
-- bloque fijo de todo docs/conta/c*.sql, tabla por tabla: solo el dueño
-- lee (policy); nadie de la API escribe (todo entra por las funciones);
-- anon, nada. service_role conserva la lectura (la función «contador» de
-- f07 lee para proponer) y ninguna escritura. Los triggers, además,
-- frenan al propio SQL Editor.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['periodos','contadores','asientos','asiento_lineas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated, service_role', t);
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    execute format('create policy %I on public.%I for select to authenticated using (es_dueno())', t || '_dueno', t);
  end loop;
  -- La secuencia de los id de línea tampoco es de la API.
  execute format('revoke all on sequence %s from anon, authenticated, service_role',
                 pg_get_serial_sequence('public.asiento_lineas', 'id'));
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

-- ---------------------------------------------------------------------
-- B.2 · Quién llama. Dentro de una función SECURITY DEFINER current_user
-- es el dueño de la función, pero el ajuste «role» sigue diciendo con qué
-- rol entró la petición: authenticated, anon o service_role por la API;
-- 'none' en el SQL Editor (y en pg_cron), que entra como el dueño de la
-- base. Así cada asiento guarda el rol real, no el de la función.
-- ---------------------------------------------------------------------
create or replace function public.fn_rol_llamante() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(nullif(current_setting('role', true), 'none'), session_user::text)
$$;
revoke execute on function public.fn_rol_llamante() from public, anon, authenticated, service_role;

-- El SQL Editor: sin «set role» y con la sesión del dueño de las tablas
-- del libro. Por la API la sesión es de «authenticator», que no es el
-- dueño, y el rol nunca es 'none'.
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
    'documento_ruta', a.documento_ruta,
    'propuesta_id',   a.propuesta_id::text,
    'procedencia',    a.procedencia::text,
    'usuario_id',     a.usuario_id::text,
    'rol_bd',         a.rol_bd,
    'creado_el',      to_char(a.creado_el at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'lineas', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                        'orden',       l.orden::text,
                        'cuenta',      l.cuenta,
                        'monto',       l.monto::text,
                        'proyecto_id', l.proyecto_id,
                        'cost_code',   l.cost_code,
                        'co',          l.co,
                        'fase',        l.fase,
                        'memo',        l.memo)) order by l.orden)
                 from public.asiento_lineas l
                where l.asiento_id = a.id)
  ))::text
$$;
revoke execute on function public.fn_asiento_canonico(public.asientos) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- B.4 · Restricciones que SON controles (por eso no están en el bloque A):
--   · un asiento se reversa una sola vez;
--   · la cadena no se bifurca: cada hash, y cada hash anterior, una vez;
--   · el hash tiene forma de sha256.
-- Solo se añaden si faltan: volver a pegar no reconstruye índices.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.asientos'::regclass and conname = 'asientos_reversa_a_unica') then
    alter table public.asientos add constraint asientos_reversa_a_unica unique (reversa_a);
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

-- Un documento, un asiento (el contrato de los puentes de f03): correr un
-- puente dos veces no duplica; la segunda da 23505 en este índice. El
-- reverso lleva el mismo origen que su original (así el papel enseña su
-- historia entera) y por eso no cuenta.
create unique index if not exists asientos_origen_unico
  on public.asientos (origen_tabla, origen_id)
  where origen_tabla is not null and camino not in ('reverso', 'reverso_automatico');


-- ---------------------------------------------------------------------
-- B.5 · La guarda de periodos (MX002). Un TRIGGER y no una policy: frena
-- también al SQL Editor, a fn_cerrar_periodo y a cualquier puente.
--   · Un período nace abierto, cuelga de su año y no va antes de la
--     apertura (el libro empieza el 30-sep-2026) ni antes de un mes ya
--     cerrado.
--   · Lo único que le pasa después es cerrarse. Los meses, en orden; el
--     año, cuando todos sus períodos estén cerrados; la apertura, cuando
--     se cuadre (puede quedarse abierta con octubre ya cerrado).
--   · Al cerrarse, la base apunta quién, cuándo y el hash de la cadena en
--     ese instante (con el candado de la cadena: nadie postea mientras).
--   · Cerrado no se reabre, no se toca y no se borra.
-- ---------------------------------------------------------------------
create or replace function public.fn_periodos_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_anio     periodos;
  v_abiertos text;
  v_suma     numeric;
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003', message = 'Los períodos no se truncan: el libro cuelga de ellos.';
  end if;

  if tg_op = 'DELETE' then
    if old.estado = 'cerrado' then
      raise exception using errcode = 'MX002',
        message = format('El período %s está cerrado: no se borra.', old.periodo);
    end if;
    return old;  -- con asientos, además, lo impide la FK de asientos.periodo
  end if;

  if tg_op = 'INSERT' then
    if new.estado <> 'abierto' or new.cerrado_el is not null or new.cerrado_por is not null
       or new.cerrado_rol is not null or new.cadena_al_cerrar is not null then
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
    if new.tipo = 'mes' then
      if exists (select 1 from periodos where tipo = 'apertura' and desde >= new.desde) then
        raise exception using errcode = 'MX002',
          message = format('El libro empieza en la apertura del 30-sep-2026: no hay meses antes (%s).', new.periodo);
      end if;
      if exists (select 1 from periodos where tipo = 'mes' and estado = 'cerrado' and desde > new.desde) then
        raise exception using errcode = 'MX002',
          message = format('No se abre %s: ya hay meses posteriores cerrados.', new.periodo);
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
       or new.cerrado_rol is not null or new.cadena_al_cerrar is not null then
      raise exception using errcode = 'MX002',
        message = format('El sello de cierre de %s lo pone la base al cerrarlo, no se escribe a mano.', old.periodo);
    end if;
    return new;
  end if;

  -- abierto → cerrado
  if new.tipo = 'mes' then
    select string_agg(p.periodo, ', ' order by p.desde) into v_abiertos
      from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde < new.desde;
    if v_abiertos is not null then
      raise exception using errcode = 'MX002',
        message = format('Los meses se cierran en orden: antes de %s hay que cerrar %s.', new.periodo, v_abiertos);
    end if;
  elsif new.tipo = 'anio' then
    select string_agg(p.periodo, ', ' order by p.desde) into v_abiertos
      from periodos p where p.tipo <> 'anio' and p.anio = new.anio and p.estado = 'abierto';
    if v_abiertos is not null then
      raise exception using errcode = 'MX002',
        message = format('El año %s se cierra cuando todos sus períodos estén cerrados; faltan: %s.', new.periodo, v_abiertos);
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

  new.cerrado_el       := now();
  new.cerrado_por      := auth.uid();
  new.cerrado_rol      := fn_rol_llamante();
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
-- B.7 · Cada línea, al entrar (vale para TODO camino: fn_postear, un
-- puente, o un insert a mano en el SQL Editor).
--   · MX003: una línea solo entra ANTES que su cabecera. Con la cabecera
--     ya puesta, el asiento está sellado: ni una línea más.
--   · MX004: la cuenta existe, está activa y es imputable.
--   · MX006: las dimensiones que pide la cuenta (cuentas.regla_obra y
--     regla_cost_code); cost_code, co y fase solo con obra; la obra y el
--     código existen.
-- La escala del monto (MX005) no se puede mirar aquí: numeric(14,2) ya
-- redondeó. La mira fn_postear_interno leyendo el texto.
-- ---------------------------------------------------------------------
create or replace function public.fn_asiento_lineas_al_insertar()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c cuentas;
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
  return new;
end $$;
revoke execute on function public.fn_asiento_lineas_al_insertar() from public, anon, authenticated, service_role;

create or replace trigger trg_asiento_lineas_al_insertar
  before insert on public.asiento_lineas
  for each row execute function public.fn_asiento_lineas_al_insertar();

-- ---------------------------------------------------------------------
-- B.8 · La cabecera, al entrar. Es el corazón del libro y vale para TODO
-- camino. En este orden:
--   0. Quién: a mano (o por la IA, f07) solo el dueño o el SQL Editor.
--   1. Período (MX002): lo pone la base según la fecha, nunca quien
--      inserta. Toma el período «for share»: si alguien lo está cerrando,
--      uno espera al otro y el asiento no se cuela en un mes cerrado.
--   2. Cuadre (MX001) con las líneas, que ya entraron; y la apertura,
--      solo con cuentas de balance (MX006).
--   3. Desde aquí, el candado de la cadena: un asiento a la vez en todo
--      el libro (se suelta al terminar la transacción).
--   4. Reverso (MX007): existe el original, no es un reverso, no tiene ya
--      el suyo, no va antes, y las líneas son su espejo exacto.
--   5. Número: contadores, «select … for update», DESPUÉS de validar. Si
--      algo falla después, el rollback deshace también el contador: no
--      hay hueco (una secuencia de Postgres sí lo dejaría).
--   6. El sello: quién, con qué rol y cuándo, puestos por la base.
--   7. El eslabón: posición, hash anterior y hash.
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
  v_n      int;
  v_suma   numeric;
  v_debe   numeric;
  v_serie  text;
  v_sec    bigint;
  v_cabeza asientos;
begin
  -- 0. Quién.
  if new.camino in ('mano', 'ia') and not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño postea asientos a mano.';
  end if;
  if coalesce(current_setting('mx_libro.reverso_de', true), '') = new.id::text and new.reversa_a is null then
    raise exception using errcode = 'MX007',
      message = 'Las líneas entraron como las de un reverso, pero la cabecera no dice qué asiento reversa.';
  end if;

  -- 1. Período.
  select * into v_per
    from periodos p
   where p.tipo <> 'anio' and new.fecha_contable between p.desde and p.hasta
     for share;
  if not found then
    raise exception using errcode = 'MX002',
      message = format('No hay período contable para el %s. El libro empieza en la apertura del 30-sep-2026; '
                       'un mes nuevo se abre con fn_abrir_periodo.', coalesce(new.fecha_contable::text, '(sin fecha)'));
  end if;
  if v_per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('El período %s está cerrado: nadie escribe ahí. Un documento tardío va al primer día del '
                       'período abierto; una corrección, con fn_reversar.', v_per.periodo);
  end if;
  if v_per.tipo = 'apertura' and new.tipo <> 'apertura' then
    raise exception using errcode = 'MX002',
      message = format('El período %s solo admite el asiento de apertura y sus reversos.', v_per.periodo);
  end if;
  if new.tipo = 'apertura' and v_per.tipo <> 'apertura' and new.reversa_a is null then
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

  -- 3. El candado de la cadena.
  perform pg_advisory_xact_lock(820260923);

  -- 4. Reverso.
  if new.reversa_a is not null then
    select * into v_orig from asientos where id = new.reversa_a;
    if not found then
      raise exception using errcode = 'MX007', message = 'El asiento que dice reversar no existe.';
    end if;
    if v_orig.reversa_a is not null then
      raise exception using errcode = 'MX007',
        message = format('%s es un reverso: un reverso no se reversa. La re-corrección es un asiento nuevo.', v_orig.numero);
    end if;
    if exists (select 1 from asientos where reversa_a = new.reversa_a) then
      raise exception using errcode = 'MX007', message = format('%s ya tiene su reverso.', v_orig.numero);
    end if;
    if new.fecha_contable < v_orig.fecha_contable then
      raise exception using errcode = 'MX007', message = 'Un reverso no va antes que su original.';
    end if;
    if new.tipo is distinct from v_orig.tipo or new.afecta_periodo is distinct from v_orig.afecta_periodo then
      raise exception using errcode = 'MX007', message = 'Un reverso conserva el tipo de su original.';
    end if;
    if new.camino = 'reverso_automatico'
       and (not v_orig.reversible
            or new.fecha_contable <> (date_trunc('month', v_orig.fecha_contable::timestamp) + interval '1 month')::date) then
      raise exception using errcode = 'MX007',
        message = 'El reverso automático es el de un asiento reversible y va el día 1 del mes siguiente.';
    end if;
    if exists (
         (select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
            from asiento_lineas l where l.asiento_id = v_orig.id
          except all
          select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
            from asiento_lineas l where l.asiento_id = new.id)
         union all
         (select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
            from asiento_lineas l where l.asiento_id = new.id
          except all
          select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
            from asiento_lineas l where l.asiento_id = v_orig.id)) then
      raise exception using errcode = 'MX007',
        message = format('Un reverso es el espejo exacto de su original (%s): las mismas cuentas y dimensiones, '
                         'con el signo cambiado.', v_orig.numero);
    end if;
  end if;

  -- 5. Número correlativo, sin huecos, por año.
  v_serie := 'asientos-' || new.anio;
  insert into contadores (serie, ultimo) values (v_serie, 0) on conflict (serie) do nothing;
  select c.ultimo + 1 into v_sec from contadores c where c.serie = v_serie for update;
  update contadores set ultimo = v_sec where serie = v_serie;
  new.secuencia := v_sec;
  new.numero    := new.anio::text || '-' || lpad(v_sec::text, 6, '0');

  -- 6. El sello.
  new.creado_el  := now();
  new.usuario_id := auth.uid();
  new.rol_bd     := fn_rol_llamante();

  -- 7. El eslabón.
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
-- ninguna excepción. Lo único que queda fuera es deshabilitar el trigger,
-- y eso lo detecta la cadena de hashes (fn_verificar_cadena).
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
-- siempre. Se comprueba al final de la transacción (diferido), porque el
-- reverso entra justo después del original.
-- (Un trigger de restricción no admite «or replace»: se borra y se crea.)
-- ---------------------------------------------------------------------
create or replace function public.fn_asientos_reversible_con_reverso()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from asientos r where r.reversa_a = new.id and r.camino = 'reverso_automatico') then
    raise exception using errcode = 'MX007',
      message = format('El asiento %s es reversible y no trae su reverso automático del día 1.', new.numero);
  end if;
  return null;
end $$;
revoke execute on function public.fn_asientos_reversible_con_reverso() from public, anon, authenticated, service_role;

drop trigger if exists trg_asientos_reversible_diferido on public.asientos;
create constraint trigger trg_asientos_reversible_diferido
  after insert on public.asientos
  deferrable initially deferred
  for each row when (new.reversible)
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
--                   "co": "…", "fase": "…", "memo": "…" }, … ],
--     "reversible": false,               (true = devengo que se reversa solo el día 1)
--     "tipo": "normal" | "apertura" | "ajuste_cpa",
--     "afecta_periodo": "2026-12",       (solo ajuste_cpa)
--     "motivo": "…",                     (obligatorio en ajuste_cpa)
--     "documento_ruta": "…",             (el papel en Storage, si no hay fila origen)
--     "origen_tabla": "recibos", "origen_id": "123",   (obligatorios en 'puente')
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
                                          'origen_id','procedencia','propuesta_id'];
  c_claves_linea constant text[] := array['cuenta','monto','proyecto_id','cost_code','co','fase','memo'];
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
  v_proc := coalesce(p_asiento->'procedencia', '{}'::jsonb);
  if jsonb_typeof(v_proc) <> 'object' then
    raise exception using errcode = '22023', message = 'procedencia es un objeto JSON.';
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
      'orden',       v_i,
      'cuenta',      v_l->>'cuenta',
      'monto',       v_monto,
      'proyecto_id', nullif(v_l->>'proyecto_id', ''),
      'cost_code',   nullif(v_l->>'cost_code', ''),
      'co',          nullif(v_l->>'co', ''),
      'fase',        nullif(v_l->>'fase', ''),
      'memo',        nullif(v_l->>'memo', '')));
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

  -- Primero las líneas (cada una pasa su trigger: MX004, MX006)…
  insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo)
  select v_id, x.orden, x.cuenta, x.monto, x.proyecto_id, x.cost_code, x.co, x.fase, x.memo
    from jsonb_to_recordset(v_lineas)
         as x(orden int, cuenta text, monto numeric, proyecto_id text, cost_code text, co text, fase text, memo text)
   order by x.orden;

  -- …y después la cabecera (su trigger: período, cuadre, número, sello y hash).
  insert into asientos (id, fecha_contable, tipo, afecta_periodo, camino, descripcion, motivo, reversible,
                        origen_tabla, origen_id, documento_ruta, procedencia)
  values (v_id, v_fecha, v_tipo, nullif(p_asiento->>'afecta_periodo', ''), v_camino,
          btrim(p_asiento->>'descripcion'), nullif(btrim(p_asiento->>'motivo'), ''), v_reversible,
          nullif(p_asiento->>'origen_tabla', ''), nullif(p_asiento->>'origen_id', ''),
          nullif(p_asiento->>'documento_ruta', ''), v_proc)
  returning * into v_a;

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
-- Solo el dueño (o el SQL Editor). El camino, el origen y el sello no los
-- manda el cliente: los pone la base.
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
   where k not in ('fecha','descripcion','lineas','reversible','tipo','afecta_periodo','motivo','documento_ruta');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('fn_postear no acepta %s: el camino, el origen y el sello los pone la base.', v_sobra);
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
  if v_o.reversa_a is not null then
    raise exception using errcode = 'MX007',
      message = format('%s es un reverso: un reverso no se reversa. La re-corrección es un asiento nuevo.', v_o.numero);
  end if;
  if exists (select 1 from asientos where reversa_a = v_o.id) then
    raise exception using errcode = 'MX007', message = format('%s ya se reversó.', v_o.numero);
  end if;

  if p_camino = 'reverso_automatico' then
    v_fecha := (date_trunc('month', v_o.fecha_contable::timestamp) + interval '1 month')::date;
  elsif exists (select 1 from periodos where periodo = v_o.periodo and estado = 'abierto') then
    v_fecha := v_o.fecha_contable;
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

  -- Las líneas de este reverso no se juzgan contra el plan de hoy (ver
  -- B.7); el trigger de la cabecera exige que sean el espejo exacto.
  perform set_config('mx_libro.reverso_de', v_id::text, true);
  insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code, co, fase, memo)
  select v_id, l.orden, l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase, l.memo
    from asiento_lineas l
   where l.asiento_id = v_o.id
   order by l.orden;

  insert into asientos (id, fecha_contable, tipo, afecta_periodo, camino, descripcion, motivo, reversa_a,
                        reversible, origen_tabla, origen_id, documento_ruta, procedencia)
  values (v_id, v_fecha, v_o.tipo, v_o.afecta_periodo, p_camino,
          'Reverso de ' || v_o.numero || ': ' || v_o.descripcion, btrim(p_motivo), v_o.id,
          false, v_o.origen_tabla, v_o.origen_id, v_o.documento_ruta,
          p_procedencia || jsonb_build_object('reversa', v_o.numero))
  returning * into v_a;
  perform set_config('mx_libro.reverso_de', '', true);

  return jsonb_build_object('id', v_a.id, 'numero', v_a.numero, 'fecha_contable', v_a.fecha_contable,
                            'periodo', v_a.periodo, 'hash', v_a.hash, 'reversa', v_o.numero);
end $$;
revoke execute on function public.fn_reversar_interno(uuid, text, text, jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- B.14 · fn_reversar(asiento uuid, motivo text) — lo que llama conta.js.
-- Solo el dueño (o el SQL Editor). Un reverso no se reversa; un asiento
-- se reversa una sola vez; el motivo es obligatorio.
-- ---------------------------------------------------------------------
create or replace function public.fn_reversar(p_asiento uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Solo el dueño reversa asientos.';
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
-- B.16 · fn_verificar_cadena() — lo que no se puede impedir, se detecta.
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
--   reversos    cada reverso es el espejo de su original y cada
--               reversible tiene su reverso automático
--   periodos    en cada período cerrado: el hash del cierre sigue en la
--               cadena y nada entró después del cierre
--   triggers    las guardas existen y están habilitadas
--   permisos    RLS, policies y grants como los dejó este archivo
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
  c_tablas constant text[] := array['cuentas','periodos','contadores','asientos','asiento_lineas'];
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
          having count(l.id) < 2 or coalesce(sum(l.monto), 0) <> 0
           order by a.cadena_pos
           limit 20) s;
  select count(*) into v_n
    from asiento_lineas l
   where not exists (select 1 from asientos a where a.id = l.asiento_id);
  control := 'cuadre';
  ok      := jsonb_array_length(v_malos) = 0 and v_n = 0;
  detalle := jsonb_build_object('descuadrados', v_malos, 'lineas_sin_cabecera', v_n);
  return next;

  -- reversos
  select coalesce(jsonb_agg(s.numero), '[]'::jsonb) into v_malos
    from (select r.numero
            from asientos r
            join asientos o on o.id = r.reversa_a
           where exists (
                   (select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
                      from asiento_lineas l where l.asiento_id = o.id
                    except all
                    select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
                      from asiento_lineas l where l.asiento_id = r.id)
                   union all
                   (select l.cuenta, l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
                      from asiento_lineas l where l.asiento_id = r.id
                    except all
                    select l.cuenta, -l.monto, l.proyecto_id, l.cost_code, l.co, l.fase
                      from asiento_lineas l where l.asiento_id = o.id))
          union all
          select o.numero
            from asientos o
           where o.reversible
             and not exists (select 1 from asientos r where r.reversa_a = o.id and r.camino = 'reverso_automatico')
          limit 20) s;
  control := 'reversos';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('malos', v_malos);
  return next;

  -- periodos
  select coalesce(jsonb_agg(s.periodo), '[]'::jsonb) into v_malos
    from (select p.periodo
            from periodos p
           where p.estado = 'cerrado'
             and (   (p.cadena_al_cerrar is distinct from repeat('0', 64)
                      and not exists (select 1 from asientos a where a.hash = p.cadena_al_cerrar))
                  or exists (select 1 from asientos a
                              where a.periodo = p.periodo and a.creado_el > p.cerrado_el)
                  or exists (select 1 from asientos a
                              where a.periodo = p.periodo
                                and a.cadena_pos > coalesce((select b.cadena_pos from asientos b
                                                              where b.hash = p.cadena_al_cerrar), 0)))
           order by p.desde) s;
  control := 'periodos';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('cerrados', (select count(*) from periodos where periodos.estado = 'cerrado'),
                                'tocados', v_malos);
  return next;

  -- triggers
  select coalesce(jsonb_agg(jsonb_build_object('tabla', e.tabla, 'trigger', e.nombre,
                                               'estado', coalesce(t.tgenabled::text, 'NO EXISTE'))), '[]'::jsonb)
    into v_malos
    from (values ('cuentas',        'trg_cuentas_guarda'),
                 ('cuentas',        'trg_cuentas_sin_truncate'),
                 ('periodos',       'trg_periodos_guarda'),
                 ('periodos',       'trg_periodos_sin_truncate'),
                 ('contadores',     'trg_contadores_guarda'),
                 ('contadores',     'trg_contadores_sin_truncate'),
                 ('asientos',       'trg_asientos_al_insertar'),
                 ('asientos',       'trg_asientos_inmutable'),
                 ('asientos',       'trg_asientos_sin_truncate'),
                 ('asientos',       'trg_asientos_reversible_diferido'),
                 ('asiento_lineas', 'trg_asiento_lineas_al_insertar'),
                 ('asiento_lineas', 'trg_asiento_lineas_inmutable'),
                 ('asiento_lineas', 'trg_asiento_lineas_sin_truncate')) as e(tabla, nombre)
    left join pg_trigger t
           on t.tgrelid = to_regclass('public.' || e.tabla) and t.tgname = e.nombre
   where t.oid is null or t.tgenabled not in ('O', 'A');
  control := 'triggers';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;

  -- permisos
  select coalesce(jsonb_agg(s.falla), '[]'::jsonb) into v_malos
    from (select format('%s sin RLS', t) as falla
            from unnest(c_tablas) t
           where not (select c.relrowsecurity from pg_class c where c.oid = to_regclass('public.' || t))
          union all
          select format('%s sin la policy %s_dueno', t, t)
            from unnest(c_tablas) t
           where not exists (select 1 from pg_policies pl
                              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname = t || '_dueno')
          union all
          select format('anon tiene permisos en %s', t)
            from unnest(c_tablas) t
           where has_table_privilege('anon', 'public.' || t, 'select,insert,update,delete,truncate,references,trigger')
          union all
          select format('%s puede escribir en %s', r, t)
            from unnest(c_tablas) t, unnest(array['authenticated','service_role']) r
           where has_table_privilege(r, 'public.' || t, 'insert,update,delete,truncate')
          union all
          select format('anon ejecuta %s', f)
            from unnest(array['fn_postear(jsonb)','fn_reversar(uuid,text)','fn_estado(text)','fn_verificar_cadena()',
                              'fn_cerrar_periodo(text)','fn_abrir_periodo(text)','fn_fecha_miami(timestamptz)',
                              'fn_postear_interno(jsonb)','fn_reversar_interno(uuid,text,text,jsonb)']) f
           where has_function_privilege('anon', 'public.' || f, 'execute')
          union all
          select format('%s ejecuta %s', r, f)
            from unnest(array['fn_postear_interno(jsonb)','fn_reversar_interno(uuid,text,text,jsonb)']) f,
                 unnest(array['authenticated','service_role']) r
           where has_function_privilege(r, 'public.' || f, 'execute')
          union all
          select format('service_role ejecuta %s', f)
            from unnest(array['fn_postear(jsonb)','fn_reversar(uuid,text)','fn_cerrar_periodo(text)',
                              'fn_abrir_periodo(text)']) f
           where has_function_privilege('service_role', 'public.' || f, 'execute')) s;
  control := 'permisos';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;
end $$;
revoke execute on function public.fn_verificar_cadena() from public, anon, authenticated, service_role;
grant  execute on function public.fn_verificar_cadena() to authenticated;

-- ---------------------------------------------------------------------
-- B.17 · fn_cerrar_periodo(periodo) — el dueño cierra un período. Las
-- reglas (orden, cuadre, sello y hash del cierre) viven en el trigger de
-- periodos, así que valen igual si se cierra desde el SQL Editor. f08
-- pondrá delante sus comprobaciones (conciliaciones, auxiliar = mayor…).
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
  select * into v_p from periodos where periodo = p_periodo;
  if not found then
    raise exception using errcode = 'P0002', message = format('No existe el período %s.', coalesce(p_periodo, ''));
  end if;
  if v_p.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('El período %s ya estaba cerrado (desde %s).', p_periodo, v_p.cerrado_el);
  end if;
  update periodos set estado = 'cerrado' where periodo = p_periodo
  returning * into v_p;
  return to_jsonb(v_p);
end $$;
revoke execute on function public.fn_cerrar_periodo(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_cerrar_periodo(text) to authenticated;

-- ---------------------------------------------------------------------
-- B.18 · fn_abrir_periodo('AAAA-MM') — el dueño abre un mes (y su año, si
-- falta). Si ya existe, lo devuelve tal cual. Las reglas (no antes de la
-- apertura, no antes de un mes cerrado, año abierto) viven en el trigger.
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
  return to_jsonb(v_p);
end $$;
revoke execute on function public.fn_abrir_periodo(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_abrir_periodo(text) to authenticated;


-- ---------------------------------------------------------------------
-- B.19 · Quién ejecuta. En Supabase toda función nace ejecutable por anon
-- y authenticated; por eso cada función de este archivo lleva su revoke
-- JUSTO DESPUÉS de crearla (arriba). El reparto queda así:
--   · internas (triggers, auxiliares, las dos puertas internas): nadie de
--     la API; solo el dueño de la base y las funciones SECURITY DEFINER;
--   · las que llama conta.js (fn_postear, fn_reversar, fn_estado,
--     fn_verificar_cadena, fn_abrir_periodo, fn_cerrar_periodo,
--     fn_fecha_miami): solo authenticated, y por dentro solo pasa el
--     dueño; ni anon ni service_role.
-- fn_verificar_cadena comprueba este reparto cada vez (control permisos).
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- B.20 · Lo que un auditor lee en pg_description (de aquí sale
-- docs/conta/MAPA-DATOS.md).
-- ---------------------------------------------------------------------
comment on table public.periodos is
  'Períodos contables (c2): un mes, la apertura (30-sep-2026) o un año. Nacen abiertos, se cierran en orden y no se reabren. Nadie escribe en un período cerrado.';
comment on column public.periodos.periodo          is 'AAAA-MM (mes), AAAA-MM-APERTURA o AAAA (año).';
comment on column public.periodos.tipo             is 'mes, apertura o anio.';
comment on column public.periodos.estado           is 'abierto o cerrado. De cerrado no se vuelve.';
comment on column public.periodos.paralelo         is 'true = marcha en paralelo con QuickBooks (octubre–diciembre de 2026 y la apertura): los libros oficiales de ese año son los de QuickBooks.';
comment on column public.periodos.cerrado_el       is 'Cuándo se cerró (lo pone la base).';
comment on column public.periodos.cerrado_por      is 'auth.uid() de quien lo cerró; nulo si fue desde el SQL Editor.';
comment on column public.periodos.cerrado_rol      is 'Rol con que se cerró: authenticated (la app) o el dueño de la base (SQL Editor).';
comment on column public.periodos.cadena_al_cerrar is 'Hash de la cadena del libro en el instante del cierre: la foto que se comprueba después.';

comment on table public.contadores is
  'Numeración sin huecos (c2). Una fila por serie y año (asientos-2027). Solo avanza de uno en uno.';

comment on table public.asientos is
  'Cabecera de cada asiento del libro (c2). No se edita ni se borra: se corrige con fn_reversar. Número, período, sello y hash los pone la base.';
comment on column public.asientos.numero         is 'AAAA-NNNNNN, correlativo por año y sin huecos.';
comment on column public.asientos.cadena_pos     is 'Posición en la cadena de hashes (orden de posteo, en todo el libro).';
comment on column public.asientos.fecha_contable is 'La fecha del asiento, en hora de Miami. Decide el período.';
comment on column public.asientos.periodo        is 'El período que contiene la fecha. Lo pone la base.';
comment on column public.asientos.tipo           is 'normal, apertura o ajuste_cpa.';
comment on column public.asientos.afecta_periodo is 'Solo ajuste_cpa: el período cerrado al que corresponde el ajuste.';
comment on column public.asientos.camino         is 'Por dónde entró: mano (el dueño), puente (automático, desde un documento), ia (propuesta aprobada, f07), reverso o reverso_automatico.';
comment on column public.asientos.descripcion    is 'Qué es el asiento, en palabras.';
comment on column public.asientos.motivo         is 'Por qué: obligatorio en un reverso y en un ajuste del CPA.';
comment on column public.asientos.reversa_a      is 'El asiento que este reversa. Único: un asiento se reversa una sola vez; un reverso no se reversa.';
comment on column public.asientos.reversible     is 'true = devengo de cierre: nace con su reverso automático el día 1 del mes siguiente.';
comment on column public.asientos.origen_tabla   is 'Tabla del documento origen (recibos, facturas…). Un documento, un asiento.';
comment on column public.asientos.origen_id      is 'Id del documento origen, como texto.';
comment on column public.asientos.documento_ruta is 'Ruta del papel en Storage cuando no hay fila origen (la balanza de apertura en PDF…).';
comment on column public.asientos.propuesta_id   is 'Reservado para f07: la propuesta de la IA aprobada (ia_propuestas.id, uuid). OJO: no es la tabla propuestas, que son las de los clientes.';
comment on column public.asientos.procedencia    is 'El sello del camino: qué función lo posteó y lo que el puente dejó escrito (p. ej. la nota de un documento tardío).';
comment on column public.asientos.usuario_id     is 'auth.uid() de la sesión que lo posteó (en un puente, quien subió el papel); nulo desde el SQL Editor.';
comment on column public.asientos.rol_bd         is 'Rol con que entró: authenticated (la app), o el dueño de la base (SQL Editor, pg_cron).';
comment on column public.asientos.creado_el      is 'Cuándo se posteó (hora del servidor).';
comment on column public.asientos.hash_anterior  is 'Hash del asiento anterior en la cadena (64 ceros el primero).';
comment on column public.asientos.hash           is 'sha256 de fn_asiento_canonico: el asiento entero, sus líneas y el hash anterior.';

comment on table public.asiento_lineas is
  'Líneas del libro (c2). Monto con signo: positivo = debe, negativo = haber; cada asiento suma cero. No se editan ni se borran.';
comment on column public.asiento_lineas.orden       is 'Posición de la línea dentro de su asiento.';
comment on column public.asiento_lineas.cuenta      is 'Cuenta del plan (cuentas.codigo).';
comment on column public.asiento_lineas.monto       is 'numeric(14,2), nunca cero. Positivo = debe, negativo = haber.';
comment on column public.asiento_lineas.proyecto_id is 'Dimensión obra (proyectos.id). La exige o la prohíbe cuentas.regla_obra.';
comment on column public.asiento_lineas.cost_code   is 'Dimensión cost code (codigos_partida.codigo), opción B de f01. La exige o la prohíbe cuentas.regla_cost_code.';
comment on column public.asiento_lineas.co          is 'Change Order, copiado tal cual del origen (la FK a alcances llega en f10).';
comment on column public.asiento_lineas.fase        is 'Fase de la obra, opcional.';
comment on column public.asiento_lineas.memo        is 'Nota de la línea.';

comment on function public.fn_postear(jsonb)          is 'Postea un asiento a mano (solo el dueño). Devuelve id, número, período y hash.';
comment on function public.fn_reversar(uuid, text)    is 'Reversa un asiento con su motivo (solo el dueño). Una vez; un reverso no se reversa.';
comment on function public.fn_estado(text)           is 'Fila de control de un período: asientos, filas, debe, haber y si cuadra.';
comment on function public.fn_verificar_cadena()      is 'Verifica hashes, enlaces, numeración, contadores, cuadre, reversos, cierres, triggers y permisos.';
comment on function public.fn_cerrar_periodo(text)    is 'Cierra un período (solo el dueño). No se reabre.';
comment on function public.fn_abrir_periodo(text)     is 'Abre un mes AAAA-MM y su año si falta (solo el dueño).';
comment on function public.fn_fecha_miami(timestamptz) is 'La fecha en hora de Miami (America/New_York), calculada en SQL.';
comment on function public.fn_postear_interno(jsonb)  is 'La puerta interna de todo posteo (puentes, IA aprobada). Sin grant a la API.';
comment on function public.fn_reversar_interno(uuid, text, text, jsonb) is 'La única fábrica de reversos: las líneas espejo salen de la base. Sin grant a la API.';
comment on function public.fn_asiento_canonico(public.asientos) is 'El texto exacto que se sella con sha256: el asiento, sus líneas y el hash anterior.';


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: los nueve controles, en true.
-- =====================================================================
select * from public.fn_verificar_cadena();
