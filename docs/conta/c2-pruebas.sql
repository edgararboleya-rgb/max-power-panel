-- =====================================================================
-- C2 · Las pruebas del libro — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1 y c2-libro.sql.
-- Lo que enseña al final es la tabla de resultados: una fila por ataque,
-- con lo esperado, lo obtenido y ok. Todo en true = el libro aguanta.
--
-- NO DEJA RASTRO. Cada ataque es un bloque «do» con una subtransacción
-- adentro: se suplanta al usuario (request.jwt.claims + set local role),
-- se ataca, y al final se lanza MXT00 para DESHACER todo lo escrito (los
-- asientos de prueba, los números, los cierres de período, las cuentas y
-- su historial). El resultado viaja en variables, que no se deshacen, y se
-- apunta en _pruebas, que es temporal y muere con la sesión. El libro no
-- tiene secuencias (una secuencia no se deshace con el rollback): no
-- avanza nada. La última prueba comprueba que todo quedó igual que al
-- empezar, secuencias, funciones y tablas del libro incluidas.
--
-- EL RELOJ FINGIDO. Un período se cierra cuando ya terminó (hora de
-- Miami), y muchas pruebas cierran meses que todavía no terminan. Dentro
-- de su subtransacción, esas pruebas rehacen fn_fecha_miami para que
-- «hoy» sea el día siguiente al del período que cierran
-- (pg_temp.mx_fingir_hoy, abajo); el MXT00 la deshace junto con todo lo
-- demás, y ninguna otra sesión la ve (lo que no se confirma no lo ve
-- nadie). Mientras dura, el control triggers sale en rojo por esa
-- función: por eso esas pruebas miran solo el control que prueban. Y como
-- la apertura se cierra con su asiento de apertura, si está abierta y sin
-- él, antes le ponen uno de balance, que se deshace igual. Algunas
-- pruebas hacen un ALTER TABLE (lo que prueban es justo eso) y toman por
-- un instante el candado de esa tabla, ANTES que el de la cadena: si la
-- app postea justo en ese momento, la prueba la espera (y no se esperan
-- la una a la otra). También se deshace.
--
-- EL CANDADO DE PERIODOS. El libro toma siempre primero la fila del
-- período («for share» al postear, el update al cerrar) y después el
-- candado de la cadena. Una prueba que postea y después cierra (o cierra
-- dos períodos seguidos) los tomaría al revés: si la app postea en ese
-- mes justo entonces, cada una esperaría a la otra y Postgres mataría el
-- posteo de la app (40P01, «deadlock detected», un HTTP 500 en inglés).
-- Por eso toda prueba que cierra períodos toma, como PRIMERA sentencia de
-- su subtransacción, «lock table public.periodos in exclusive mode» (o
-- «access exclusive» si después hace un ALTER TABLE de periodos): así la
-- app la espera a ella, unos milisegundos, y no se traban. El candado se
-- suelta con el MXT00. Los ayudantes que cierran lo exigen (MXT09).
--
-- Rojo primero, SOLO en el banco de pruebas (pruebas/conta/correr.sh con
-- «c2-libro.sql:A»; en Supabase c2-libro.sql se pega siempre entero): con
-- solo el bloque A, estas pruebas fallan porque los ataques ENTRAN
-- («entró»), no porque falte una tabla. Salvo:
--   · las de quién lee y quién postea (9, 10, 11, 23 y 34), que ya pasan:
--     el bloque A nace cerrado, para que pegarlo solo por error no abra el
--     libro a la API; y la 59 (lo que la app confirma), que con las
--     funciones mínimas también confirma;
--   · las que prueban c1 (el plan y su guarda: 29, 40, 42, 44, 45, 46, 50
--     y 64), que no depende del bloque A, y la del rastro (68);
--   · unas pocas que usan piezas que solo existen en el bloque B
--     (fn_postear_interno en la 41 y la 63; la guarda de periodos, que la
--     60 y la 65 apagan un momento), que fallan porque falta la pieza.
-- Con el bloque B, todas en true.
--
-- Los datos que usan se buscan, no se inventan: el dueño (rol 'dueno',
-- activo), uno del equipo (activo, no dueño), una obra, un cost code, las
-- cuentas por sus reglas y el mes abierto más antiguo (con su mes
-- siguiente). Si algo falta, la prueba sale «omitida» (ok vacío), no
-- falla. Unas pocas buscan una cuenta por su número o su etiqueta, a
-- propósito: prueban una decisión del plan (c1), y lo dicen.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- ---------------------------------------------------------------------
-- Antes de nada: lo que estas pruebas dan por hecho. Pegadas antes que
-- c1 y c2-libro.sql (o sobre un c2 que no llegó a aplicarse), paran aquí
-- con un mensaje en español, y no con un error de Postgres en inglés.
-- Pide solo lo del bloque A, para que el rojo del banco siga corriendo.
-- ---------------------------------------------------------------------
do $$
declare
  v_falta text := '';
begin
  if to_regclass('public.cuentas') is null or to_regclass('public.cuentas_historial') is null then
    v_falta := v_falta || ' · falta el plan de cuentas (c1-plan-de-cuentas.sql)';
  end if;
  if to_regclass('public.periodos') is null or to_regclass('public.contadores') is null
     or to_regclass('public.asientos') is null or to_regclass('public.asiento_lineas') is null
     or to_regprocedure('public.fn_postear(jsonb)') is null then
    v_falta := v_falta || ' · falta el libro (c2-libro.sql)';
  end if;
  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c2-pruebas NO se corrió: pega antes c1-plan-de-cuentas.sql y c2-libro.sql.' || v_falta;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Los ayudantes de las pruebas. Viven en pg_temp: mueren con la sesión
-- (no dejan rastro), nadie más los ve, y se llaman siempre con su esquema
-- delante (pg_temp nunca se busca para funciones).
--   · mx_foto(): cómo está el libro (filas, contadores, cierres, cuentas
--     inactivas, historial, secuencias, y las huellas de fn_fecha_miami y
--     de todas las funciones y tablas del libro). La última prueba la
--     compara con la del principio.
--   · mx_fingir_hoy(fecha): el reloj fingido (ver la cabecera). Rehace
--     fn_fecha_miami para que «hoy» sea esa fecha (o el hoy de verdad, si
--     es posterior). Solo se llama DENTRO de la subtransacción de una
--     prueba: su MXT00 la deshace.
--   · mx_apertura_con_asiento(): si la apertura está abierta y sin su
--     asiento de apertura, le pone uno de balance (banco contra capital).
--   · mx_preparar_cierre(periodo): finge que hoy es el día siguiente al
--     último día de ese período, deja la apertura con su asiento y cierra
--     en orden, como el SQL Editor, todo lo abierto ANTES de él.
--   · mx_cerrar_hasta(periodo): lo mismo, y cierra también ese período.
--   · mx_exigir_candado(): los dos de arriba y mx_apertura_con_asiento
--     la llaman antes de nada; si la prueba no tomó el candado de
--     periodos (ver la cabecera), se niega (MXT09).
-- Los cierres llevan «cerrado_el = now()» solo para que el rojo (el bloque
-- A solo, sin guarda) cumpla el check de la tabla; con el bloque B, la
-- guarda pone la hora del cierre y su foto.
-- ---------------------------------------------------------------------
create or replace function pg_temp.mx_foto() returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_huellas text := '-';
begin
  if to_regprocedure('public.fn_libro_huellas_calcular()') is not null then
    execute 'select left(md5(string_agg(h.tipo || '' '' || h.objeto || '' '' || h.md5, '','' order by h.tipo, h.objeto)), 12)
               from public.fn_libro_huellas_calcular() h'
       into v_huellas;
  end if;
  return format('asientos=%s lineas=%s contadores=%s periodos=%s cerrados=%s inactivas=%s historial=%s secuencias=%s reloj=%s huellas=%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from periodos),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) from cuentas where not activa),
                (select count(*) from cuentas_historial),
                (select coalesce(sum(coalesce(sq.last_value, 0)), 0)
                   from pg_class s
                   join pg_depend d on d.objid = s.oid and d.classid = 'pg_class'::regclass
                                   and d.refclassid = 'pg_class'::regclass
                   join pg_namespace n on n.oid = s.relnamespace
                   join pg_sequences sq on sq.schemaname = n.nspname and sq.sequencename = s.relname
                  where s.relkind = 'S'
                    and d.refobjid in (select c.oid from pg_class c
                                        where c.relnamespace = 'public'::regnamespace
                                          and c.relname in ('cuentas', 'cuentas_historial', 'periodos', 'contadores',
                                                            'asientos', 'asiento_lineas'))),
                left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12),
                v_huellas);
end $$;
revoke execute on function pg_temp.mx_foto() from public, anon, authenticated, service_role;

create or replace function pg_temp.mx_fingir_hoy(p_hoy date) returns void
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
revoke execute on function pg_temp.mx_fingir_hoy(date) from public, anon, authenticated, service_role;

create or replace function pg_temp.mx_exigir_candado() returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from pg_locks l
                  where l.locktype = 'relation' and l.relation = 'public.periodos'::regclass
                    and l.pid = pg_backend_pid() and l.granted
                    and l.mode in ('ExclusiveLock', 'AccessExclusiveLock')) then
    raise exception using errcode = 'MXT09',
      message = 'c2-pruebas: una prueba que cierra períodos toma antes, como primera sentencia de su subtransacción, '
                'lock table public.periodos in exclusive mode (ver la cabecera: sin él, se puede trabar con un '
                'posteo de la app).';
  end if;
end $$;
revoke execute on function pg_temp.mx_exigir_candado() from public, anon, authenticated, service_role;

create or replace function pg_temp.mx_apertura_con_asiento() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ap    periodos;
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_cap   text := nullif(current_setting('mx_pruebas.capital', true), '');
begin
  perform pg_temp.mx_exigir_candado();
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is null
     or exists (select 1 from asientos a
                 where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                   and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    return;
  end if;
  if v_banco is null or v_cap is null then
    raise exception using errcode = 'MXT09',
      message = 'c2-pruebas: no hay una cuenta de banco y una de capital para el asiento de apertura de prueba.';
  end if;
  perform fn_postear(jsonb_build_object(
    'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
    'descripcion', 'c2-pruebas: apertura de prueba (se deshace)',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_banco, 'monto', '1000.00'),
                                jsonb_build_object('cuenta', v_cap, 'monto', '-1000.00'))));
end $$;
revoke execute on function pg_temp.mx_apertura_con_asiento() from public, anon, authenticated, service_role;

create or replace function pg_temp.mx_preparar_cierre(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p periodos;
  v_q text;
begin
  perform pg_temp.mx_exigir_candado();
  select * into v_p from periodos where periodo = p_periodo;
  if v_p.periodo is null then
    raise exception using errcode = 'MXT09', message = format('c2-pruebas: no existe el período %s.', p_periodo);
  end if;
  perform pg_temp.mx_fingir_hoy(v_p.hasta + 1);
  perform pg_temp.mx_apertura_con_asiento();
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde < v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
  end loop;
end $$;
revoke execute on function pg_temp.mx_preparar_cierre(text) from public, anon, authenticated, service_role;

create or replace function pg_temp.mx_cerrar_hasta(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform pg_temp.mx_preparar_cierre(p_periodo);
  update periodos set estado = 'cerrado', cerrado_el = now() where periodo = p_periodo and estado = 'abierto';
end $$;
revoke execute on function pg_temp.mx_cerrar_hasta(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Guarda lo que usan todas las pruebas en ajustes
-- de la sesión (mx_pruebas.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno     uuid;
  v_equipo    uuid;
  v_obra      text;
  v_cc        text;
  v_c5        text;
  v_banco     text;
  v_gasto     text;
  v_capital   text;
  v_mes       text;
  v_desde     date;
  v_sig       text;
  v_sig_desde date;
  v_apertura  date;
  v_bueno     jsonb;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_obra from proyectos order by id limit 1;
  select codigo into v_cc from codigos_partida order by codigo limit 1;
  -- Las cuentas se eligen por sus reglas, no por número (si Edgar corrige
  -- el plan, las pruebas siguen valiendo); se prefiere la de siempre.
  -- El costo de obra: exige obra y admite cost code (en el costo el
  -- código es opcional, c1).
  select codigo into v_c5 from cuentas
   where tipo = 'costo' and regla_obra = 'obligatoria' and regla_cost_code <> 'prohibida' and activa and imputable
   order by (codigo = '5100') desc, codigo limit 1;
  select codigo into v_banco from cuentas
   where tipo = 'activo' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '1010') desc, codigo limit 1;
  select codigo into v_gasto from cuentas
   where tipo = 'gasto' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '6100') desc, codigo limit 1;
  -- El capital, para el asiento de apertura de prueba (balance únicamente).
  select codigo into v_capital from cuentas
   where tipo = 'capital' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '3900') desc, codigo limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' order by desde limit 1;
  select periodo, desde into v_sig, v_sig_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  select desde into v_apertura from periodos where tipo = 'apertura' order by desde limit 1;

  -- Un asiento bueno de 100.00 fechado el día 5 del mes abierto más antiguo.
  if v_obra is not null and v_cc is not null and v_c5 is not null and v_banco is not null and v_mes is not null then
    v_bueno := jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'),
      'descripcion', 'c2-pruebas: asiento de prueba (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_c5, 'monto', '100.00', 'proyecto_id', v_obra, 'cost_code', v_cc),
        jsonb_build_object('cuenta', v_banco, 'monto', '-100.00')));
  end if;

  perform set_config('mx_pruebas.dueno',     coalesce(v_dueno::text, ''), false);
  perform set_config('mx_pruebas.equipo',    coalesce(v_equipo::text, ''), false);
  perform set_config('mx_pruebas.obra',      coalesce(v_obra, ''), false);
  perform set_config('mx_pruebas.cc',        coalesce(v_cc, ''), false);
  perform set_config('mx_pruebas.c5',        coalesce(v_c5, ''), false);
  perform set_config('mx_pruebas.banco',     coalesce(v_banco, ''), false);
  perform set_config('mx_pruebas.gasto',     coalesce(v_gasto, ''), false);
  perform set_config('mx_pruebas.capital',   coalesce(v_capital, ''), false);
  perform set_config('mx_pruebas.mes',       coalesce(v_mes, ''), false);
  perform set_config('mx_pruebas.desde',     coalesce(v_desde::text, ''), false);
  perform set_config('mx_pruebas.sig',       coalesce(v_sig, ''), false);
  perform set_config('mx_pruebas.sig_desde', coalesce(v_sig_desde::text, ''), false);
  perform set_config('mx_pruebas.apertura',  coalesce(v_apertura::text, ''), false);
  perform set_config('mx_pruebas.bueno',     coalesce(v_bueno::text, ''), false);

  -- La foto del libro antes de las pruebas (la última prueba la compara).
  -- Cuenta también las secuencias de las tablas del libro: no debería
  -- haber ninguna (una secuencia no se deshace con el rollback); si
  -- alguien vuelve a poner un id con secuencia, las pruebas dejarían
  -- rastro y la última prueba lo canta. Y las huellas: el reloj fingido y
  -- los ALTER TABLE de algunas pruebas se tienen que haber deshecho.
  perform set_config('mx_pruebas.foto', pg_temp.mx_foto(), false);
end $$;


-- =====================================================================
-- Los ataques de f02
-- =====================================================================

-- 1. Descuadre por un centavo (el dueño, por fn_postear) → MX001.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (1, 'descuadre por un centavo (dueño, fn_postear)', 'MX001', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{lineas,1,monto}', '"-99.99"'));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (1, 'descuadre por un centavo (dueño, fn_postear)', 'MX001', v_obt, v_obt like 'MX001 %');
end $$;

-- 2. Mes cerrado, desde fn_postear: el editor cierra el mes abierto más
--    antiguo (con el reloj fingido: todavía no termina; y antes la
--    apertura, con su asiento, si sigue abierta: va primero) y el dueño
--    intenta postear en él → MX002.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (2, 'mes cerrado desde fn_postear (dueño)', 'MX002', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    perform pg_temp.mx_cerrar_hasta(v_mes);   -- reloj fingido; antes, la apertura con su asiento
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (2, 'mes cerrado desde fn_postear (dueño)', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 3. Mes cerrado, desde el SQL Editor: insert directo en las tablas, sin
--    pasar por fn_postear (las columnas de sistema van con valores de
--    relleno: el trigger las pisa) → MX002.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (3, 'mes cerrado desde el SQL Editor (insert directo)', 'MX002', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    perform pg_temp.mx_cerrar_hasta(v_mes);   -- reloj fingido; antes, la apertura con su asiento
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          hash_anterior, hash)
    values (v_id, v_anio || '-999999', v_anio, 999999, 999999999, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: insert directo en mes cerrado', repeat('0', 64), repeat('f', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (3, 'mes cerrado desde el SQL Editor (insert directo)', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 4. Update a una línea ya asentada, desde el SQL Editor → MX003.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (4, 'update a una línea (SQL Editor)', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    update asiento_lineas set monto = monto + 1 where asiento_id = v_id and orden = 1;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (4, 'update a una línea (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 5. Update a la cabecera: mover la fecha de un asiento a un mes cerrado,
--    desde el SQL Editor → MX003.
do $$
declare
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes       text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde     date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_obt       text;
begin
  if v_bueno is null or v_sig_desde is null then
    insert into _pruebas values (5, 'update a la cabecera: fecha a un mes cerrado (SQL Editor)', 'MX003', 'omitida: faltan dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    -- el asiento va en el mes siguiente; luego se cierra el mes anterior y
    -- se intenta llevar la fecha allí.
    v_id := (fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_sig_desde + 4, 'YYYY-MM-DD'))))->>'id')::uuid;
    perform pg_temp.mx_cerrar_hasta(v_mes);   -- reloj fingido; antes, la apertura con su asiento
    update asientos set fecha_contable = v_desde + 4, periodo = v_mes where id = v_id;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (5, 'update a la cabecera: fecha a un mes cerrado (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 6. Delete de las líneas y delete de la cabecera, desde el SQL Editor →
--    MX003 los dos.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_lin   text;
  v_cab   text;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (6, 'delete de líneas y de cabecera (SQL Editor)', 'lineas=MX003 cabecera=MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    begin
      delete from asiento_lineas where asiento_id = v_id;
      v_lin := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_lin := sqlstate;
    end;
    begin
      delete from asientos where id = v_id;
      v_cab := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cab := sqlstate;
    end;
    v_obt := format('lineas=%s cabecera=%s', v_lin, v_cab);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (6, 'delete de líneas y de cabecera (SQL Editor)', 'lineas=MX003 cabecera=MX003', v_obt,
                               v_obt = 'lineas=MX003 cabecera=MX003');
end $$;

-- 7. Truncate del libro, desde el SQL Editor → MX003.
do $$
declare
  v_obt text;
begin
  begin
    truncate asientos, asiento_lineas;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (7, 'truncate del libro (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 8. La fecha de frontera: 31-dic a las 7 pm de Miami, con la sesión en
--    UTC (donde ya es 1-ene). fn_fecha_miami tiene que decir 2026-12-31.
do $$
declare
  v_obt text;
begin
  begin
    execute 'set local timezone = ''UTC''';
    v_obt := fn_fecha_miami('2026-12-31 19:00-05'::timestamptz)::text;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (8, 'fecha 31-dic 19:00 Miami con la sesión en UTC', '2026-12-31', v_obt, v_obt = '2026-12-31');
end $$;

-- 9. Un trabajador con su login lee CERO filas del libro (aunque haya).
do $$
declare
  v_equipo uuid  := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_bueno  jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt    text;
begin
  if v_equipo is null or v_bueno is null then
    insert into _pruebas values (9, 'el equipo lee 0 filas del libro', 'asientos=0 lineas=0 cuentas=0 historial=0 periodos=0 contadores=0', 'omitida: no hay perfil de equipo o falta el asiento de prueba', null);
    return;
  end if;
  begin
    perform fn_postear(v_bueno);  -- como editor: que haya al menos un asiento
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select format('asientos=%s lineas=%s cuentas=%s historial=%s periodos=%s contadores=%s',
                  (select count(*) from asientos), (select count(*) from asiento_lineas),
                  (select count(*) from cuentas), (select count(*) from cuentas_historial),
                  (select count(*) from periodos), (select count(*) from contadores))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (9, 'el equipo lee 0 filas del libro', 'asientos=0 lineas=0 cuentas=0 historial=0 periodos=0 contadores=0',
                               v_obt, v_obt = 'asientos=0 lineas=0 cuentas=0 historial=0 periodos=0 contadores=0');
end $$;

-- 10. Un trabajador no puede postear (fn_postear) → 42501.
do $$
declare
  v_equipo uuid  := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_bueno  jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt    text;
begin
  if v_equipo is null or v_bueno is null then
    insert into _pruebas values (10, 'el equipo no puede postear', '42501', 'omitida: no hay perfil de equipo o falta el asiento de prueba', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (10, 'el equipo no puede postear', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 11. anon (sin sesión) no puede nada: ni leer el libro ni el plan, ni
--     postear, ni pedir el estado.
do $$
declare
  v_bueno jsonb := coalesce(nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb, '{}'::jsonb);
  v_mes   text  := coalesce(nullif(current_setting('mx_pruebas.mes', true), ''), '2026-10');
  v_a     text;
  v_c     text;
  v_p     text;
  v_e     text;
  v_obt   text;
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    begin
      select count(*) || ' filas' into v_a from asientos;
    exception when others then v_a := sqlstate;
    end;
    begin
      select count(*) || ' filas' into v_c from cuentas;
    exception when others then v_c := sqlstate;
    end;
    begin
      perform fn_postear(v_bueno);
      v_p := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_p := sqlstate;
    end;
    begin
      perform * from fn_estado(v_mes);
      v_e := 'entró';
    exception when others then v_e := sqlstate;
    end;
    v_obt := format('asientos=%s cuentas=%s postear=%s estado=%s', v_a, v_c, v_p, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (11, 'anon no puede nada', 'asientos=42501 cuentas=42501 postear=42501 estado=42501', v_obt,
                               v_obt = 'asientos=42501 cuentas=42501 postear=42501 estado=42501');
end $$;

-- 12. Reversar dos veces el mismo asiento (el dueño) → el segundo MX007.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (12, 'reversar dos veces (dueño)', 'MX007', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    perform fn_reversar(v_id, 'c2-pruebas: primer reverso');
    perform fn_reversar(v_id, 'c2-pruebas: segundo reverso');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (12, 'reversar dos veces (dueño)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 13. Reversar un reverso (el dueño) → MX007.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_rev   uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (13, 'reversar un reverso (dueño)', 'MX007', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id  := (fn_postear(v_bueno)->>'id')::uuid;
    v_rev := (fn_reversar(v_id, 'c2-pruebas: reverso')->>'id')::uuid;
    perform fn_reversar(v_rev, 'c2-pruebas: reverso del reverso');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (13, 'reversar un reverso (dueño)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 14. El reverso de un asiento de un período YA CERRADO cae el día 1 del
--     mes abierto siguiente, no en el cerrado.
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes       text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_sig       text  := nullif(current_setting('mx_pruebas.sig', true), '');
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_desde     date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id        uuid;
  v_r         jsonb;
  v_esp       text;
  v_obt       text;
begin
  v_esp := format('fecha=%s periodo=%s', v_sig_desde, v_sig);
  if v_dueno is null or v_bueno is null or v_sig is null then
    insert into _pruebas values (14, 'reverso de un asiento en período cerrado cae en el abierto', v_esp, 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    v_id := (fn_postear(v_bueno)->>'id')::uuid;   -- como editor, en el mes abierto más antiguo
    perform pg_temp.mx_cerrar_hasta(v_mes);   -- reloj fingido; antes, la apertura con su asiento
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_reversar(v_id, 'c2-pruebas: error hallado con el mes ya cerrado');
    v_obt := format('fecha=%s periodo=%s', v_r->>'fecha_contable', v_r->>'periodo');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (14, 'reverso de un asiento en período cerrado cae en el abierto', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. Bueno, descuadrado, bueno: el descuadrado no entra y los dos buenos
--     quedan con números seguidos (sin hueco).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_n1    int;
  v_n2    int;
  v_des   text;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (15, 'bueno, descuadrado, bueno: números sin hueco', 'descuadrado=MX001 salto=1', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_n1 := split_part(fn_postear(v_bueno)->>'numero', '-', 2)::int;
    begin
      perform fn_postear(jsonb_set(v_bueno, '{lineas,1,monto}', '"-99.99"'));
      v_des := 'entró';
    exception when others then v_des := sqlstate;
    end;
    v_n2 := split_part(fn_postear(v_bueno)->>'numero', '-', 2)::int;
    v_obt := format('descuadrado=%s salto=%s', v_des, v_n2 - v_n1);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (15, 'bueno, descuadrado, bueno: números sin hueco', 'descuadrado=MX001 salto=1', v_obt,
                               v_obt = 'descuadrado=MX001 salto=1');
end $$;

-- 16. Un monto con tres decimales → MX005 (numeric(14,2) lo redondearía
--     callado; la base lo rechaza antes).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (16, 'monto con tres decimales', 'MX005', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(jsonb_set(v_bueno, '{lineas,0,monto}', '"100.005"'), '{lineas,1,monto}', '"-100.005"'));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (16, 'monto con tres decimales', 'MX005', v_obt, v_obt like 'MX005 %');
end $$;

-- 17. Una cuenta inactiva no recibe asientos → MX004. Se usa una cuenta
--     NUEVA, creada aquí: en un libro con movimientos, la de gasto de
--     siempre puede tener saldo, y con saldo ya no se inactiva (prueba 45).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_nueva text;
  v_obt   text;
begin
  select min(c)::text into v_nueva
    from generate_series(6990, 6999) c
   where not exists (select 1 from cuentas where codigo = c::text);
  if v_dueno is null or v_banco is null or v_desde is null or v_nueva is null then
    insert into _pruebas values (17, 'cuenta inactiva', 'MX004', 'omitida: falta dueño, cuenta, código libre o mes abierto', null);
    return;
  end if;
  begin
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, regla_obra, regla_cost_code)
    values (v_nueva, 'c2-pruebas: cuenta de prueba', 'c2-pruebas: test account', 'gasto', 'debe', 'prohibida', 'prohibida');
    update cuentas set activa = false where codigo = v_nueva;   -- el editor la inactiva (no tiene saldo)
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: a una cuenta inactiva',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_nueva, 'monto', '50.00'),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-50.00'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (17, 'cuenta inactiva', 'MX004', v_obt, v_obt like 'MX004 %');
end $$;

-- 18. Costo (5xxx) sin obra → MX006.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (18, 'costo 5xxx sin obra', 'MX006', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno #- '{lineas,0,proyecto_id}' #- '{lineas,0,cost_code}');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (18, 'costo 5xxx sin obra', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 19. Gasto general (6xxx) con obra → MX006 (el overhead nunca va por obra
--     en el libro).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_gasto text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_gasto is null or v_banco is null or v_obra is null or v_desde is null then
    insert into _pruebas values (19, 'gasto 6xxx con obra', 'MX006', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: renta cargada a una obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '50.00', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-50.00'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (19, 'gasto 6xxx con obra', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 20. Un asiento reversible genera, en la misma transacción, su reverso
--     automático fechado el día 1 del mes siguiente.
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_esp       text;
  v_obt       text;
begin
  v_esp := format('reverso=%s camino=reverso_automatico', v_sig_desde);
  if v_dueno is null or v_bueno is null or v_sig_desde is null then
    insert into _pruebas values (20, 'reversible genera su reverso el día 1', v_esp, 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno || '{"reversible": true}'::jsonb)->>'id')::uuid;
    select format('reverso=%s camino=%s', coalesce(max(r.fecha_contable)::text, '-'), coalesce(max(r.camino), '-'))
      into v_obt
      from asientos r
     where r.reversa_a = v_id;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (20, 'reversible genera su reverso el día 1', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. La cadena, sana: después de postear, reversar y un reversible,
--     fn_verificar_cadena da sus diez controles en true (el detector no
--     grita de más). El reversible solo si el mes siguiente está abierto
--     (su reverso cae ahí): sin él, la prueba no puede fallar por eso.
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_obt       text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (21, 'cadena íntegra tras posteos normales', 'controles=10 fallan=0', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    perform fn_reversar(v_id, 'c2-pruebas: reverso');
    if v_sig_desde is not null then
      perform fn_postear(v_bueno || '{"reversible": true}'::jsonb);
    end if;
    select format('controles=%s fallan=%s', count(*), count(*) filter (where not v.ok))
      into v_obt
      from fn_verificar_cadena() v;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (21, 'cadena íntegra tras posteos normales', 'controles=10 fallan=0', v_obt, v_obt = 'controles=10 fallan=0');
end $$;

-- 22. LA FRONTERA, dicha con una prueba para que nadie lea en verde una
--     garantía que la base no da. El SQL Editor (el dueño de la base)
--     apaga los triggers de las líneas, mueve 10.00 de un lado a otro de un
--     asiento (sigue cuadrado) y los vuelve a encender:
--       · mientras están apagados, fn_verificar_cadena lo dice (triggers);
--       · después, la cadena delata el cambio (hash): lo tocó SIN
--         recalcular;
--       · pero si además recalcula el hash con fn_asiento_canonico, como
--         haría un dueño que sabe lo que hace, todos los controles vuelven
--         a true. Dentro de la base no se puede delatar al dueño de la
--         base: eso lo caza el hash exportado fuera en cada cierre (f08).
--     Lo esperado es exactamente eso: apagados=f ingenuo=f reencadenado=t.
--     Si el editor no tuviera permiso para apagar triggers (42501), la
--     prueba lo apunta como bueno: tampoco hay por dónde entrar.
do $$
declare
  v_bueno   jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id      uuid;
  v_apagado text;
  v_hash    text;
  v_todo    text;
  v_obt     text;
  v_ok      boolean;
begin
  if v_bueno is null then
    insert into _pruebas values (22, 'frontera: se delata al que edita sin recalcular; al dueño que recalcula, solo el hash exportado (f08)', 'apagados=f ingenuo=f reencadenado=t', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    lock table public.asientos, public.asiento_lineas in access exclusive mode;   -- antes que el de la cadena (ver la 24)
    v_id := (fn_postear(v_bueno)->>'id')::uuid;   -- queda en la punta de la cadena
    -- Un ALTER TABLE no corre con comprobaciones diferidas pendientes sobre
    -- la tabla (la FK diferida de las líneas recién puestas y el sello al
    -- confirmar): se disparan ya. Se deshace con la subtransacción.
    set constraints all immediate;
    begin
      execute 'alter table public.asiento_lineas disable trigger user';
    exception when insufficient_privilege then
      v_obt := format('el editor no puede apagar los triggers (%s)', sqlstate);
    end;
    if v_obt is null then
      select coalesce(max(v.ok::text), '-') into v_apagado from fn_verificar_cadena() v where v.control = 'triggers';
      update asiento_lineas set monto = monto + 10 where asiento_id = v_id and monto > 0;
      update asiento_lineas set monto = monto - 10 where asiento_id = v_id and monto < 0;
      execute 'alter table public.asiento_lineas enable trigger user';
      select coalesce(max(v.ok::text), '-') into v_hash from fn_verificar_cadena() v where v.control = 'hash';
      -- El dueño que sabe: recalcula el hash del asiento tocado (es la
      -- punta: no hay eslabones detrás que rehacer). Con el bloque A solo
      -- no hay cadena que recalcular.
      if to_regprocedure('public.fn_asiento_canonico(asientos)') is not null then
        execute 'alter table public.asientos disable trigger user';
        update asientos a set hash = encode(sha256(convert_to(fn_asiento_canonico(a), 'UTF8')), 'hex') where a.id = v_id;
        execute 'alter table public.asientos enable trigger user';
        select case when bool_and(v.ok) then 'true' else 'false' end into v_todo from fn_verificar_cadena() v;
      end if;
      v_obt := format('apagados=%s ingenuo=%s reencadenado=%s',
                      case v_apagado when 'false' then 'f' when 'true' then 't' else v_apagado end,
                      case v_hash when 'false' then 'f' when 'true' then 't' else v_hash end,
                      case v_todo when 'false' then 'f' when 'true' then 't' else v_todo end);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  v_ok := v_obt = 'apagados=f ingenuo=f reencadenado=t' or v_obt like 'el editor no puede apagar los triggers%';
  insert into _pruebas values (22, 'frontera: se delata al que edita sin recalcular; al dueño que recalcula, solo el hash exportado (f08)', 'apagados=f ingenuo=f reencadenado=t', v_obt, v_ok);
end $$;


-- =====================================================================
-- Más ataques: los que un auditor preguntaría después
-- =====================================================================

-- 23. service_role (las funciones de borde, la IA) no postea → 42501.
--     «La IA propone, nunca postea» lo garantiza la base.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (23, 'service_role no postea (la IA nunca postea)', '42501', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
    execute 'set local role service_role';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (23, 'service_role no postea (la IA nunca postea)', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 24. Un período cerrado no se reabre, ni desde el SQL Editor:
--       · con un update → MX002 (la guarda de periodos);
--       · con «ALTER TABLE … ALTER COLUMN … TYPE … USING (case …)», que
--         reescribe la tabla SIN disparar ningún trigger: se reabre el
--         mes, se postea en él y se vuelve a cerrar. Desde dentro no se
--         puede impedir, pero se delata: el mes quedó cerrado DESPUÉS del
--         siguiente, con su foto más adelante, y su asiento nuevo detrás
--         de la foto del siguiente (control periodos, que antes del ataque
--         estaba en true); y la tabla se reescribió (su huella: control
--         triggers). Antes, los nueve controles salían en verde.
do $$
declare
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes       text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_sig       text  := nullif(current_setting('mx_pruebas.sig', true), '');
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_upd       text;
  v_antes     boolean;
  v_despues   boolean;
  v_tabla     boolean;
  v_obt       text;
  v_esp       text := 'update=MX002 alter=periodos_antes:t,periodos_despues:f,huella_tabla:t';
begin
  if v_bueno is null or v_sig is null then
    insert into _pruebas values (24, 'un período cerrado no se reabre: update → MX002; ALTER TABLE … TYPE → se delata', v_esp, 'omitida: faltan dos meses abiertos seguidos o el asiento de prueba', null);
    return;
  end if;
  begin
    -- El candado de la tabla, ANTES que el de la cadena (lo toman los
    -- cierres y los posteos de abajo): si la app está posteando justo
    -- ahora, esta prueba la espera, y no al revés (sin eso, las dos se
    -- esperarían la una a la otra).
    lock table public.periodos in access exclusive mode;
    begin
      perform pg_temp.mx_cerrar_hasta(v_mes);
      update periodos set estado = 'abierto', cerrado_el = null, cerrado_por = null, cerrado_rol = null,
                          cadena_al_cerrar = null
       where periodo = v_mes;
      v_upd := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_upd := sqlstate;
    end;
    -- Un asiento en el mes y otro en el siguiente; se cierran los dos, en orden.
    perform fn_postear(v_bueno);
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_sig_desde + 4, 'YYYY-MM-DD'))));
    perform pg_temp.mx_cerrar_hasta(v_sig);
    select v.ok into v_antes from fn_verificar_cadena() v where v.control = 'periodos';
    -- El ataque, sin apagar ningún trigger.
    execute format($a$
      alter table public.periodos
        alter column estado           type text        using (case when periodo = %1$L then 'abierto' else estado end),
        alter column cerrado_el       type timestamptz using (case when periodo = %1$L then null else cerrado_el end),
        alter column cerrado_por      type uuid        using (case when periodo = %1$L then null else cerrado_por end),
        alter column cerrado_rol      type text        using (case when periodo = %1$L then null else cerrado_rol end),
        alter column cerrado_conexion type jsonb       using (case when periodo = %1$L then null else cerrado_conexion end),
        alter column cadena_al_cerrar type text        using (case when periodo = %1$L then null else cadena_al_cerrar end)
    $a$, v_mes);
    perform fn_postear(jsonb_set(v_bueno, '{descripcion}', '"c2-pruebas: metido en un mes ya cerrado (se deshace)"'));
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    select v.ok into v_despues from fn_verificar_cadena() v where v.control = 'periodos';
    select exists (select 1 from jsonb_array_elements_text(v.detalle->'huellas') h where h like 'tabla periodos:%')
      into v_tabla
      from fn_verificar_cadena() v where v.control = 'triggers';
    v_obt := format('update=%s alter=periodos_antes:%s,periodos_despues:%s,huella_tabla:%s', v_upd,
                    case when v_antes then 't' when not v_antes then 'f' else '-' end,
                    case when v_despues then 't' when not v_despues then 'f' else '-' end,
                    case when v_tabla then 't' when not v_tabla then 'f' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (24, 'un período cerrado no se reabre: update → MX002; ALTER TABLE … TYPE → se delata', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. El contador no se salta números, ni desde el SQL Editor → MX003 por
--     los tres caminos: un update de +5; un update de +1 (avanza de uno
--     en uno, pero sin su asiento: antes entraba, y el número que falta
--     ya no se podía postear nunca); y un «insert … on conflict do
--     nothing» sobre un asiento que ya existe (el trigger de la cabecera
--     subía el contador antes de que Postgres viera el choque: «INSERT 0
--     0», y el número gastado). Los dos últimos se ven también al
--     confirmar: se adelanta con set constraints.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid;
  v_serie text;
  v_a     text;
  v_b     text;
  v_c     text;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (25, 'saltar números en el contador (SQL Editor): +5, +1 y on conflict do nothing', '+5=MX003 +1=MX003 on_conflict=MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_serie := 'asientos-' || extract(year from v_desde)::int;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    begin
      update contadores set ultimo = ultimo + 5 where serie = v_serie;
      set constraints all immediate;
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      update contadores set ultimo = ultimo + 1 where serie = v_serie;
      set constraints all immediate;
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    begin
      insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                            hash_anterior, hash)
      select a.id, '-', 0, 0, 0, a.fecha_contable, '-', 'mano', 'c2-pruebas: reintento', repeat('0', 64), repeat('0', 64)
        from asientos a where a.id = v_id
      on conflict do nothing;
      set constraints all immediate;
      v_c := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_c := sqlstate;
    end;
    v_obt := format('+5=%s +1=%s on_conflict=%s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (25, 'saltar números en el contador (SQL Editor): +5, +1 y on conflict do nothing', '+5=MX003 +1=MX003 on_conflict=MX003', v_obt,
                               v_obt = '+5=MX003 +1=MX003 on_conflict=MX003');
end $$;

-- 26. Una línea nueva en un asiento ya sellado (SQL Editor) → MX003.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_gasto text  := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_id    uuid;
  v_obt   text;
begin
  if v_bueno is null or v_gasto is null then
    insert into _pruebas values (26, 'línea nueva en un asiento sellado (SQL Editor)', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    insert into asiento_lineas (asiento_id, orden, cuenta, monto) values (v_id, 3, v_gasto, 1.00);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (26, 'línea nueva en un asiento sellado (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 27. Un asiento descuadrado insertado a mano en el SQL Editor, sin
--     fn_postear: el trigger de la cabecera lo para igual → MX001.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (27, 'asiento descuadrado insertado a mano (SQL Editor)', 'MX001', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -99.99, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          hash_anterior, hash)
    values (v_id, v_anio || '-999998', v_anio, 999998, 999999998, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: descuadrado a mano', repeat('0', 64), repeat('e', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (27, 'asiento descuadrado insertado a mano (SQL Editor)', 'MX001', v_obt, v_obt like 'MX001 %');
end $$;

-- 28. Un «reverso» fabricado a mano que no es el espejo de su original
--     (SQL Editor) → MX007.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obra  text  := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text  := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text  := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_orig  uuid;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (28, 'reverso fabricado que no es espejo (SQL Editor)', 'MX007', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    v_orig := (fn_postear(v_bueno)->>'id')::uuid;   -- el original es de 100.00
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, -50.00, v_obra, v_cc), (v_id, 2, v_banco, 50.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          motivo, reversa_a, hash_anterior, hash)
    values (v_id, v_anio || '-999997', v_anio, 999997, 999999997, v_desde + 4, v_mes, 'reverso',
            'c2-pruebas: medio reverso', 'c2-pruebas', v_orig, repeat('0', 64), repeat('d', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (28, 'reverso fabricado que no es espejo (SQL Editor)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 29. Una cuenta con movimientos ni se borra ni cambia de código (SQL
--     Editor) → MX003 las dos. Es la guarda de c1.
do $$
declare
  v_gasto text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_bor   text;
  v_cod   text;
  v_obt   text;
begin
  if v_gasto is null or v_banco is null or v_desde is null then
    insert into _pruebas values (29, 'cuenta con movimientos: ni se borra ni cambia de código', 'borrar=MX003 codigo=MX003', 'omitida: falta cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: un gasto',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '75.00'),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-75.00'))));
    begin
      delete from cuentas where codigo = v_gasto;
      v_bor := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_bor := sqlstate;
    end;
    begin
      update cuentas set codigo = '6999' where codigo = v_gasto;
      v_cod := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cod := sqlstate;
    end;
    v_obt := format('borrar=%s codigo=%s', v_bor, v_cod);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (29, 'cuenta con movimientos: ni se borra ni cambia de código', 'borrar=MX003 codigo=MX003', v_obt,
                               v_obt = 'borrar=MX003 codigo=MX003');
end $$;

-- 30. fn_postear no acepta lo que no es suyo: una clave mal escrita
--     («reversibel») ni un camino dictado por el cliente → 22023 los dos.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mal   text;
  v_cam   text;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (30, 'clave mal escrita y camino dictado por el cliente', 'clave=22023 camino=22023', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_postear(v_bueno || '{"reversibel": true}'::jsonb);
      v_mal := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_mal := sqlstate;
    end;
    begin
      perform fn_postear(v_bueno || '{"camino": "puente"}'::jsonb);
      v_cam := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cam := sqlstate;
    end;
    v_obt := format('clave=%s camino=%s', v_mal, v_cam);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (30, 'clave mal escrita y camino dictado por el cliente', 'clave=22023 camino=22023', v_obt,
                               v_obt = 'clave=22023 camino=22023');
end $$;

-- 31. El sello lo pone la base: un asiento del dueño por la app queda con
--     camino mano, su usuario y el rol authenticated.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (31, 'el sello (camino, usuario, rol) lo pone la base', 'camino=mano usuario=dueño rol=authenticated', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    select format('camino=%s usuario=%s rol=%s', a.camino,
                  case when a.usuario_id = v_dueno then 'dueño' else coalesce(a.usuario_id::text, 'nulo') end,
                  a.rol_bd)
      into v_obt
      from asientos a where a.id = v_id;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (31, 'el sello (camino, usuario, rol) lo pone la base', 'camino=mano usuario=dueño rol=authenticated', v_obt,
                               v_obt = 'camino=mano usuario=dueño rol=authenticated');
end $$;

-- 32. fn_estado, la fila de control: un asiento de 100.00 suma dos filas
--     y 100.00 al debe, y el período sigue cuadrando.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_f0    bigint;
  v_d0    numeric;
  v_f1    bigint;
  v_d1    numeric;
  v_c1    boolean;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (32, 'fn_estado cuenta filas, suma el debe y cuadra', 'filas+2 debe+100.00 cuadra=t', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select e.filas, e.total_debe into v_f0, v_d0 from fn_estado(v_mes) e;
    perform fn_postear(v_bueno);
    select e.filas, e.total_debe, e.cuadra into v_f1, v_d1, v_c1 from fn_estado(v_mes) e;
    v_obt := format('filas+%s debe+%s cuadra=%s', v_f1 - v_f0, v_d1 - v_d0, case when v_c1 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (32, 'fn_estado cuenta filas, suma el debe y cuadra', 'filas+2 debe+100.00 cuadra=t', v_obt,
                               v_obt = 'filas+2 debe+100.00 cuadra=t');
end $$;

-- 33. El período de apertura solo admite el asiento de apertura: un
--     asiento normal fechado ese día → MX002.
do $$
declare
  v_dueno    uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno    jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_apertura date  := nullif(current_setting('mx_pruebas.apertura', true), '')::date;
  v_obt      text;
begin
  if v_dueno is null or v_bueno is null or v_apertura is null then
    insert into _pruebas values (33, 'la apertura solo admite la apertura', 'MX002', 'omitida: falta dueño o el período de apertura', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_apertura, 'YYYY-MM-DD'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (33, 'la apertura solo admite la apertura', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 34. Un trabajador no cierra un período (fn_cerrar_periodo) → 42501.
do $$
declare
  v_equipo uuid := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_mes    text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_obt    text;
begin
  if v_equipo is null or v_mes is null then
    insert into _pruebas values (34, 'el equipo no cierra un período', '42501', 'omitida: no hay perfil de equipo o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_mes);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (34, 'el equipo no cierra un período', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 35. Los meses se cierran en orden: el dueño intenta cerrar el mes
--     siguiente con el anterior abierto → MX002 (en orden). Con el reloj
--     fingido al final de ese mes siguiente, para que lo que salte sea el
--     orden y no la fecha.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_sig   text := nullif(current_setting('mx_pruebas.sig', true), '');
  v_obt   text;
begin
  if v_dueno is null or v_sig is null then
    insert into _pruebas values (35, 'cerrar un mes con el anterior abierto', 'MX002 (en orden)', 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    perform pg_temp.mx_fingir_hoy((select p.hasta + 1 from periodos p where p.periodo = v_sig));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_sig);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when sqlerrm like '%en orden%' then ' (en orden)' else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (35, 'cerrar un mes con el anterior abierto', 'MX002 (en orden)', v_obt, v_obt = 'MX002 (en orden)');
end $$;

-- 36. Un asiento reversible metido a mano SIN su reverso no llega al
--     commit (se adelanta la comprobación diferida con set constraints)
--     → MX007.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (36, 'reversible sin su reverso no llega al commit', 'MX007', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          reversible, hash_anterior, hash)
    values (v_id, v_anio || '-999996', v_anio, 999996, 999999996, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: devengo sin su reverso', true, repeat('0', 64), repeat('c', 64));
    set constraints all immediate;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (36, 'reversible sin su reverso no llega al commit', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 37. El asiento de apertura es balance únicamente: una línea a una
--     cuenta de resultados (5xxx) → MX006. Solo mientras la apertura siga
--     abierta (después, la base ya no deja escribir ahí: MX002).
do $$
declare
  v_dueno    uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno    jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_apertura date  := nullif(current_setting('mx_pruebas.apertura', true), '')::date;
  v_abierta  boolean;
  v_obt      text;
begin
  select p.estado = 'abierto' into v_abierta from periodos p where p.tipo = 'apertura' and p.desde = v_apertura;
  if v_dueno is null or v_bueno is null or not coalesce(v_abierta, false) then
    insert into _pruebas values (37, 'la apertura es balance únicamente', 'MX006', 'omitida: falta dueño o la apertura ya está cerrada', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_apertura, 'YYYY-MM-DD')))
                       || '{"tipo": "apertura"}'::jsonb);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (37, 'la apertura es balance únicamente', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 38. Un documento, un asiento: el mismo papel posteado dos veces por un
--     puente → el segundo da 23505 en asientos_origen_unico. Es la
--     idempotencia que usan los puentes de f03 (correr dos veces no
--     duplica). El puente se simula desde el SQL Editor.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id1   uuid := gen_random_uuid();
  v_id2   uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (38, 'un documento, un asiento (el puente corre dos veces)', '23505', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id1, 1, v_c5, 100.00, v_obra, v_cc), (v_id1, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          origen_tabla, origen_id, hash_anterior, hash)
    values (v_id1, v_anio || '-999995', v_anio, 999995, 999999995, v_desde + 4, v_mes, 'puente',
            'c2-pruebas: recibo por puente', 'recibos', 'c2-pruebas-1', repeat('0', 64), repeat('b', 64));
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id2, 1, v_c5, 100.00, v_obra, v_cc), (v_id2, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          origen_tabla, origen_id, hash_anterior, hash)
    values (v_id2, v_anio || '-999994', v_anio, 999994, 999999994, v_desde + 4, v_mes, 'puente',
            'c2-pruebas: el mismo recibo otra vez', 'recibos', 'c2-pruebas-1', repeat('1', 64), repeat('a', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (38, 'un documento, un asiento (el puente corre dos veces)', '23505', v_obt, v_obt like '23505 %');
end $$;

-- =====================================================================
-- Las que pidió la auditoría del 23-sep: cada una habría fallado antes
-- de su arreglo.
-- =====================================================================

-- 39. Una línea que llega TARDE a un asiento ya sellado, desde otra
--     sesión: la sesión A pone líneas y cabecera y aún no confirma; la B
--     cuelga otra línea del mismo asiento. El trigger de la línea de B no
--     ve la cabecera de A (así es una carrera); aquí se imita apagando ese
--     trigger. La guarda que se mira AL CONFIRMAR (el sello) la para →
--     MX003. Sin ella, quedaba sellado un asiento descuadrado para siempre.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_gasto text  := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_id    uuid;
  v_obt   text;
begin
  if v_bueno is null or v_gasto is null then
    insert into _pruebas values (39, 'una línea que llega tarde a un asiento sellado (otra sesión) no confirma', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    lock table public.asiento_lineas in access exclusive mode;   -- antes que el candado de la cadena (ver la 24)
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    set constraints all immediate;
    if exists (select 1 from pg_trigger
                where tgrelid = 'public.asiento_lineas'::regclass and tgname = 'trg_asiento_lineas_al_insertar') then
      execute 'alter table public.asiento_lineas disable trigger trg_asiento_lineas_al_insertar';
    end if;
    insert into asiento_lineas (asiento_id, orden, cuenta, monto) values (v_id, 3, v_gasto, 10.00);
    set constraints all immediate;   -- lo que hace el commit
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (39, 'una línea que llega tarde a un asiento sellado (otra sesión) no confirma', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 40. El costo exige obra, pero el cost code es OPCIONAL: un recibo con
--     obra y sin código entra (ninguna tabla origen trae cost code; f01 y
--     f09 lo dan por opcional). Antes: MX006.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (40, 'costo con obra y sin cost code entra', 'entró', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno #- '{lineas,0,cost_code}');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (40, 'costo con obra y sin cost code entra', 'entró', v_obt, v_obt = 'entró');
end $$;

-- 41. Un documento, un asiento VIVO. El puente postea un recibo con el
--     mapeo equivocado (se simula desde el SQL Editor con
--     fn_postear_interno). Otra vez el mismo papel → 23505. Se reversa.
--     Otra vez sin decir a cuál sustituye → MX007. La corrección a mano
--     (fn_postear) dice de qué papel sale y a cuál sustituye → entra,
--     enlazada. Y la cadena sigue sana.
do $$
declare
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_doc   jsonb;
  v_o1    uuid;
  v_s     uuid;
  v_viv   text;
  v_sin   text;
  v_sus   text;
  v_cad   text;
  v_obt   text;
begin
  if v_c5 is null or v_banco is null or v_obra is null or v_desde is null then
    insert into _pruebas values (41, 'reversar y sustituir el asiento de un documento', 'vivo=23505 sin_sustituye=MX007 sustituto=entró cadena=t', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_doc := jsonb_build_object(
    'camino', 'puente', 'origen_tabla', 'recibos', 'origen_id', 'c2-pruebas-41',
    'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: recibo por puente',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_c5, 'monto', '245.37', 'proyecto_id', v_obra),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-245.37')));
  begin
    v_o1 := (fn_postear_interno(v_doc)->>'id')::uuid;
    begin
      perform fn_postear_interno(v_doc);
      v_viv := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_viv := sqlstate;
    end;
    perform fn_reversar(v_o1, 'c2-pruebas: mapeo equivocado');
    begin
      perform fn_postear_interno(v_doc);
      v_sin := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_sin := sqlstate;
    end;
    v_s := (fn_postear(jsonb_build_object(
              'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: recibo corregido a mano',
              'origen_tabla', 'recibos', 'origen_id', 'c2-pruebas-41', 'sustituye_a', v_o1,
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_c5, 'monto', '245.37', 'proyecto_id', v_obra),
                                          jsonb_build_object('cuenta', v_banco, 'monto', '-245.37'))))->>'id')::uuid;
    select case when a.sustituye_a = v_o1 then 'entró' else 'sin enlace' end into v_sus from asientos a where a.id = v_s;
    select case when bool_and(v.ok) then 't' else 'f' end into v_cad from fn_verificar_cadena() v;
    v_obt := format('vivo=%s sin_sustituye=%s sustituto=%s cadena=%s', v_viv, v_sin, v_sus, v_cad);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (41, 'reversar y sustituir el asiento de un documento', 'vivo=23505 sin_sustituye=MX007 sustituto=entró cadena=t',
                               v_obt, v_obt = 'vivo=23505 sin_sustituye=MX007 sustituto=entró cadena=t');
end $$;

-- 42. La amortización mensual de la prima de WC (Dr 5015 / Cr 1410) es un
--     asiento de tiempo, no de una obra: entra en la bolsa del burden real,
--     sin obra. Antes iba a 5010, que exige obra: MX006. Por número a
--     propósito: prueba una decisión del plan (c1).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_desde is null or not exists (select 1 from cuentas where codigo = '1410') then
    insert into _pruebas values (42, 'la amortización de WC entra en el burden real, sin obra (Dr 5015 / Cr 1410)', 'entró', 'omitida: falta dueño, 1410 o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: amortización de la prima de WC',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '450.00'),
                                  jsonb_build_object('cuenta', '1410', 'monto', '-450.00'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (42, 'la amortización de WC entra en el burden real, sin obra (Dr 5015 / Cr 1410)', 'entró', v_obt, v_obt = 'entró');
end $$;

-- 43. Un año mal tecleado: un asiento fechado muy lejos en el futuro (el
--     día 5 del último mes abierto) → MX002 «futuro». Antes entraba y se
--     llevaba el primer número del año de los libros oficiales.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_tope  date;
  v_fecha date;
  v_obt   text;
begin
  -- El tope de la base: el mayor entre hoy + 45 días y el fin del mes
  -- siguiente al mes abierto más antiguo.
  v_tope := greatest(fn_fecha_miami(now()) + 45,
                     (date_trunc('month', v_desde::timestamp) + interval '2 month')::date - 1);
  select p.desde + 4 into v_fecha
    from periodos p where p.tipo = 'mes' and p.estado = 'abierto' order by p.desde desc limit 1;
  if v_dueno is null or v_bueno is null or v_fecha is null or v_fecha <= v_tope then
    insert into _pruebas values (43, 'un asiento fechado muy lejos en el futuro no entra', 'MX002 (futuro)', 'omitida: falta dueño o un mes abierto más allá del tope', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_fecha, 'YYYY-MM-DD'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when sqlerrm like '%futuro%' then ' (futuro)' else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (43, 'un asiento fechado muy lejos en el futuro no entra', 'MX002 (futuro)', v_obt, v_obt = 'MX002 (futuro)');
end $$;

-- 44. El plan aparta lo que el CPA necesita para el 1120-S (por su
--     etiqueta fiscal: compensación de oficiales, intereses, venta de
--     activos, donaciones, multas) y tiene la cuenta de reembolsos a
--     empleados que usa f03 (2250, por número: decisión del plan).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_eti   text;
  v_reem  text;
  v_obt   text;
begin
  select format('oficial=%s intereses=%s venta_activos=%s donaciones=%s multas=%s',
                exists (select 1 from cuentas where etiqueta_fiscal = 'oficial 1125-E' and activa),
                exists (select 1 from cuentas where etiqueta_fiscal = 'K-1 intereses' and activa),
                exists (select 1 from cuentas where etiqueta_fiscal = '4797' and activa),
                exists (select 1 from cuentas where etiqueta_fiscal = 'K-1 donaciones' and activa),
                exists (select 1 from cuentas where etiqueta_fiscal = 'no deducible' and activa))
    into v_eti;
  if v_dueno is null or v_c5 is null or v_obra is null or v_desde is null then
    v_reem := 'omitido';
  else
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      perform fn_postear(jsonb_build_object(
        'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: material pagado por un empleado',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_c5, 'monto', '60.00', 'proyecto_id', v_obra),
                                    jsonb_build_object('cuenta', '2250', 'monto', '-60.00'))));
      v_reem := 'entró';
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_reem := sqlstate;
    end;
  end if;
  v_obt := v_eti || ' reembolso=' || v_reem;
  insert into _pruebas values (44, 'el plan aparta lo del 1120-S y tiene reembolsos por pagar',
                               'oficial=t intereses=t venta_activos=t donaciones=t multas=t reembolso=entró', v_obt,
                               case when v_reem = 'omitido' then null
                                    else v_obt = 'oficial=t intereses=t venta_activos=t donaciones=t multas=t reembolso=entró' end);
end $$;

-- 45. Una cuenta con saldo vivo no se inactiva ni se vuelve de grupo
--     (SQL Editor) → MX003 las dos: el saldo se quedaría atrapado, ni el
--     asiento que lo traslada entraría.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_saldo numeric;
  v_ina   text;
  v_gru   text;
  v_obt   text;
begin
  if v_bueno is null or v_banco is null then
    insert into _pruebas values (45, 'una cuenta con saldo no se inactiva ni se vuelve de grupo', 'inactivar=MX003 grupo=MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform fn_postear(v_bueno);   -- el banco se mueve 100.00
    select coalesce(sum(l.monto), 0) into v_saldo from asiento_lineas l where l.cuenta = v_banco;
    if v_saldo = 0 then
      perform fn_postear(v_bueno);  -- por si el saldo anterior era justo +100.00
    end if;
    begin
      update cuentas set activa = false where codigo = v_banco;
      v_ina := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_ina := sqlstate;
    end;
    begin
      update cuentas set imputable = false where codigo = v_banco;
      v_gru := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_gru := sqlstate;
    end;
    v_obt := format('inactivar=%s grupo=%s', v_ina, v_gru);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (45, 'una cuenta con saldo no se inactiva ni se vuelve de grupo', 'inactivar=MX003 grupo=MX003', v_obt,
                               v_obt = 'inactivar=MX003 grupo=MX003');
end $$;

-- 46. Renombrar una cuenta (o cambiarle la etiqueta fiscal) deja rastro:
--     cuentas_historial guarda el antes y el después, y el historial no
--     se borra (MX003).
do $$
declare
  v_gasto text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_antes text;
  v_n     bigint;
  v_viejo text;
  v_bor   text;
  v_esp   text;
  v_obt   text;
begin
  select nombre into v_antes from cuentas where codigo = v_gasto;
  v_esp := format('rastro=1 antes=%s borrar=MX003', v_antes);
  if v_gasto is null or v_antes is null then
    insert into _pruebas values (46, 'renombrar una cuenta deja rastro en cuentas_historial', 'rastro=1 antes=… borrar=MX003', 'omitida: falta cuenta', null);
    return;
  end if;
  begin
    update cuentas set nombre = 'c2-pruebas: nombre nuevo', etiqueta_fiscal = 'c2-pruebas' where codigo = v_gasto;
    select count(*), max(h.antes->>'nombre') into v_n, v_viejo
      from cuentas_historial h
     where h.codigo = v_gasto and h.operacion = 'UPDATE' and h.despues->>'nombre' = 'c2-pruebas: nombre nuevo';
    begin
      delete from cuentas_historial where codigo = v_gasto;
      v_bor := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_bor := sqlstate;
    end;
    v_obt := format('rastro=%s antes=%s borrar=%s', v_n, v_viejo, v_bor);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (46, 'renombrar una cuenta deja rastro en cuentas_historial', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 47. El calendario no tiene huecos: abrir un mes saltándose el anterior
--     → MX002; borrar un mes abierto y vacío → MX002. Con un hueco, el mes
--     que falta ya no se podría abrir nunca.
do $$
declare
  v_ult   date;
  v_hueco text;
  v_a     text;
  v_b     text;
  v_obt   text;
begin
  select max(desde) into v_ult from periodos where tipo = 'mes';
  if v_ult is null then
    insert into _pruebas values (47, 'el calendario no tiene huecos (abrir saltado, borrar un mes)', 'hueco=MX002 borrar=MX002', 'omitida: no hay meses', null);
    return;
  end if;
  v_hueco := to_char(v_ult + interval '2 month', 'YYYY-MM');
  begin
    begin
      perform fn_abrir_periodo(v_hueco);
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      delete from periodos where periodo = to_char(v_ult, 'YYYY-MM');
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    v_obt := format('hueco=%s borrar=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (47, 'el calendario no tiene huecos (abrir saltado, borrar un mes)', 'hueco=MX002 borrar=MX002', v_obt,
                               v_obt = 'hueco=MX002 borrar=MX002');
end $$;

-- 48. La apertura se cierra ANTES que el primer mes: con la apertura
--     abierta, el dueño no cierra el mes que le sigue → MX002. Si no, un
--     asiento fechado el 30-sep (o el reverso de uno de apertura)
--     cambiaría el saldo de balance de los meses ya cerrados. Con el reloj
--     fingido al final del mes, para que lo que salte sea la apertura.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_mes is null
     or not exists (select 1 from periodos p
                     where p.tipo = 'apertura' and p.estado = 'abierto' and p.desde < v_desde) then
    insert into _pruebas values (48, 'con la apertura abierta no se cierra el primer mes', 'MX002 (la apertura primero)', 'omitida: la apertura ya está cerrada', null);
    return;
  end if;
  begin
    perform pg_temp.mx_fingir_hoy((select p.hasta + 1 from periodos p where p.periodo = v_mes));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_mes);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when lower(sqlerrm) like '%apertura%' then ' (la apertura primero)' else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (48, 'con la apertura abierta no se cierra el primer mes', 'MX002 (la apertura primero)', v_obt,
                               v_obt = 'MX002 (la apertura primero)');
end $$;

-- 49. La forma del ajuste del CPA se rechaza con código propio (22023) y
--     en español: afecta_periodo en un asiento normal, y un ajuste_cpa sin
--     motivo. Antes salía un 23514 en inglés y la app decía «pega un SQL».
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_a     text;
  v_b     text;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (49, 'ajuste del CPA mal formado: 22023 y no 23514', 'afecta_sin_ajuste=22023 ajuste_sin_motivo=22023', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_postear(v_bueno || jsonb_build_object('afecta_periodo', v_mes));
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      perform fn_postear(v_bueno || jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_mes));
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    v_obt := format('afecta_sin_ajuste=%s ajuste_sin_motivo=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (49, 'ajuste del CPA mal formado: 22023 y no 23514', 'afecta_sin_ajuste=22023 ajuste_sin_motivo=22023', v_obt,
                               v_obt = 'afecta_sin_ajuste=22023 ajuste_sin_motivo=22023');
end $$;

-- 50. Una subcuenta añadida como dice c1 (una fila más en la lista, sin
--     padre) cuelga sola de su cuenta de grupo.
do $$
declare
  v_grupo cuentas;
  v_sub   text;
  v_padre text;
  v_obt   text;
begin
  select * into v_grupo from cuentas
   where not imputable and position('-' in codigo) = 0
   order by (codigo = '2100') desc, codigo limit 1;
  v_sub := v_grupo.codigo || '-C2PRUEBAS';
  if v_grupo.codigo is null or exists (select 1 from cuentas where codigo = v_sub) then
    insert into _pruebas values (50, 'una subcuenta nueva cuelga sola de su cuenta de grupo', 'padre=(la de grupo)', 'omitida: no hay cuenta de grupo', null);
    return;
  end if;
  begin
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
    values (v_sub, 'c2-pruebas: tarjeta', 'c2-pruebas: card', v_grupo.tipo, v_grupo.saldo_normal, true, 'prohibida', 'prohibida', null, null);
    select coalesce(padre, '-') into v_padre from cuentas where codigo = v_sub;
    v_obt := 'padre=' || v_padre;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (50, 'una subcuenta nueva cuelga sola de su cuenta de grupo', 'padre=' || v_grupo.codigo, v_obt,
                               v_obt = 'padre=' || v_grupo.codigo);
end $$;

-- 51. Cerrar un período que no existe → MX002 (un nombre mal escrito, no
--     una caída del servidor: con P0002, PostgREST respondía 500).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_obt   text;
begin
  if v_dueno is null then
    insert into _pruebas values (51, 'cerrar un período que no existe', 'MX002', 'omitida: falta dueño', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo('2027-13');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (51, 'cerrar un período que no existe', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 52. Una obra con asientos no se borra, ni el dueño desde la app (lo que
--     hace DB.eliminarProyecto) → MX003, y el mensaje, que la app enseña
--     tal cual, dice la obra por su nombre y lo que sí se puede hacer hoy
--     (marcarla Completado). Antes: 23503 («eso apunta a algo que ya no
--     existe»), y después un «se archiva» que la app no tiene, con el id
--     interno de la obra.
do $$
declare
  v_dueno  uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno  jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obra   text  := nullif(current_setting('mx_pruebas.obra', true), '');
  v_nombre text;
  v_obt    text;
begin
  select coalesce(nullif(btrim(p.nombre), ''), p.id) into v_nombre from proyectos p where p.id = v_obra;
  if v_dueno is null or v_bueno is null or v_obra is null then
    insert into _pruebas values (52, 'una obra con asientos no se borra (el mensaje dice cuál y qué hacer)', 'MX003 (la obra por su nombre y qué hacer)', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno);
    delete from proyectos where id = v_obra;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when sqlerrm like '%«' || v_nombre || '»%' and sqlerrm like '%Completado%'
                                     and sqlerrm not like '%archiva%'
                                then ' (la obra por su nombre y qué hacer)'
                                else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (52, 'una obra con asientos no se borra (el mensaje dice cuál y qué hacer)', 'MX003 (la obra por su nombre y qué hacer)', v_obt,
                               v_obt = 'MX003 (la obra por su nombre y qué hacer)');
end $$;

-- 53. Una fecha anterior a la apertura dice que eso vive en QuickBooks (y
--     no manda a abrir un mes que la base no deja abrir) → MX002.
do $$
declare
  v_dueno    uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno    jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_apertura date  := nullif(current_setting('mx_pruebas.apertura', true), '')::date;
  v_obt      text;
begin
  if v_dueno is null or v_bueno is null or v_apertura is null then
    insert into _pruebas values (53, 'una fecha anterior a la apertura: eso vive en QuickBooks', 'MX002 (QuickBooks)', 'omitida: falta dueño o la apertura', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_apertura - 15, 'YYYY-MM-DD'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when sqlerrm like '%QuickBooks%' then ' (QuickBooks)' else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (53, 'una fecha anterior a la apertura: eso vive en QuickBooks', 'MX002 (QuickBooks)', v_obt, v_obt = 'MX002 (QuickBooks)');
end $$;

-- 54. Una guarda vaciada con «create or replace» (sin apagar ningún
--     trigger) se detecta: el control triggers compara las huellas y sale
--     en false. Antes solo miraba el nombre y si estaba habilitado.
do $$
declare
  v_t   boolean;
  v_obt text;
begin
  begin
    create or replace function public.fn_libro_inmutable()
    returns trigger
    language plpgsql
    set search_path = public, pg_temp
    as $f$ begin return coalesce(new, old); end $f$;
    select v.ok into v_t from fn_verificar_cadena() v where v.control = 'triggers';
    v_obt := 'triggers=' || case when v_t then 't' when not v_t then 'f' else '-' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (54, 'una guarda vaciada con create or replace se detecta (huellas)', 'triggers=f', v_obt, v_obt = 'triggers=f');
end $$;

-- 55. El control permisos ve la confidencialidad de verdad: la policy del
--     dueño editada a «using (true)», una policy ajena (la plantilla del
--     dashboard) y una vista que lee el libro sin security_invoker →
--     permisos en false las tres. Antes solo miraba que existiera una
--     policy con el nombre de siempre.
do $$
declare
  v_a   boolean;
  v_b   boolean;
  v_c   boolean;
  v_obt text;
begin
  begin
    begin
      alter policy asientos_dueno on public.asientos using (true);
      select v.ok into v_a from fn_verificar_cadena() v where v.control = 'permisos';
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create policy "c2-pruebas: lectura para todos" on public.asiento_lineas for select using (true);
      select v.ok into v_b from fn_verificar_cadena() v where v.control = 'permisos';
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c2_pruebas_libro_plano as
        select a.numero, l.cuenta, l.monto from public.asientos a join public.asiento_lineas l on l.asiento_id = a.id;
      select v.ok into v_c from fn_verificar_cadena() v where v.control = 'permisos';
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('policy_editada=%s policy_ajena=%s vista=%s',
                    case when v_a then 't' when not v_a then 'f' else '-' end,
                    case when v_b then 't' when not v_b then 'f' else '-' end,
                    case when v_c then 't' when not v_c then 'f' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (55, 'permisos ve una policy editada, una ajena y una vista sin security_invoker', 'policy_editada=f policy_ajena=f vista=f', v_obt,
                               v_obt = 'policy_editada=f policy_ajena=f vista=f');
end $$;

-- 56. El control permisos ve cualquier privilegio de la API que no sea
--     SELECT, también por columna (en Postgres 17 el «grant all» de
--     Supabase trae MAINTAIN, que el banco 16 no tiene: se prueba con
--     REFERENCES y con un UPDATE de una columna).
do $$
declare
  v_a   boolean;
  v_b   boolean;
  v_obt text;
begin
  begin
    begin
      grant references on public.asientos to authenticated;
      select v.ok into v_a from fn_verificar_cadena() v where v.control = 'permisos';
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      grant update (memo) on public.asiento_lineas to authenticated;
      select v.ok into v_b from fn_verificar_cadena() v where v.control = 'permisos';
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('tabla=%s columna=%s',
                    case when v_a then 't' when not v_a then 'f' else '-' end,
                    case when v_b then 't' when not v_b then 'f' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (56, 'permisos ve un privilegio de más (de tabla y de columna)', 'tabla=f columna=f', v_obt, v_obt = 'tabla=f columna=f');
end $$;

-- 57. Lo que entra por una conexión directa del dueño de la base (el SQL
--     Editor, pg_cron, o una función de borde con SUPABASE_DB_URL) lleva
--     la conexión en su procedencia, y un período que cierra así, en
--     cerrado_conexion; lo que entra por la app, no.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id1   uuid;
  v_id2   uuid;
  v_e     boolean;
  v_a     boolean;
  v_c     boolean;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (57, 'la conexión directa queda en la procedencia y en el cierre', 'editor=t app=f cierre=t', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    v_id1 := (fn_postear(v_bueno)->>'id')::uuid;   -- el SQL Editor
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id2 := (fn_postear(v_bueno)->>'id')::uuid;   -- la app
    execute 'reset role';                          -- otra vez el SQL Editor
    select a.procedencia ? 'conexion' into v_e from asientos a where a.id = v_id1;
    select a.procedencia ? 'conexion' into v_a from asientos a where a.id = v_id2;
    perform pg_temp.mx_preparar_cierre(v_mes);    -- reloj fingido; antes, la apertura con su asiento
    perform fn_cerrar_periodo(v_mes);
    select p.cerrado_conexion is not null into v_c from periodos p where p.periodo = v_mes;
    v_obt := format('editor=%s app=%s cierre=%s', case when v_e then 't' else 'f' end,
                    case when v_a then 't' else 'f' end, case when v_c then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (57, 'la conexión directa queda en la procedencia y en el cierre', 'editor=t app=f cierre=t', v_obt, v_obt = 'editor=t app=f cierre=t');
end $$;

-- 58. Un asiento insertado a mano en el SQL Editor, sin fn_postear, queda
--     marcado: sus montos no pasaron la mirada de la escala y
--     numeric(14,2) los redondeó (245.374 → 245.37). El que entra por
--     fn_postear no lleva la marca.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obra  text  := nullif(current_setting('mx_pruebas.obra', true), '');
  v_c5    text  := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid  := gen_random_uuid();
  v_id2   uuid;
  v_anio  int;
  v_p1    text;
  v_m1    text;
  v_p2    text;
  v_obt   text;
begin
  if v_bueno is null or v_obra is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (58, 'un insert directo queda marcado (sus montos no pasaron la escala)', 'directo=insert_directo monto=245.37 fn_postear=-', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id)
    values (v_id, 1, v_c5, 245.374, v_obra), (v_id, 2, v_banco, -245.374, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          hash_anterior, hash)
    values (v_id, v_anio || '-999993', v_anio, 999993, 999999993, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: cargado a mano desde el SQL Editor', repeat('0', 64), repeat('9', 64));
    select a.procedencia->>'puerta' into v_p1 from asientos a where a.id = v_id;
    select l.monto::text into v_m1 from asiento_lineas l where l.asiento_id = v_id and l.orden = 1;
    v_id2 := (fn_postear(v_bueno)->>'id')::uuid;
    select a.procedencia->>'puerta' into v_p2 from asientos a where a.id = v_id2;
    v_obt := format('directo=%s monto=%s fn_postear=%s', coalesce(v_p1, '-'), v_m1, coalesce(v_p2, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (58, 'un insert directo queda marcado (sus montos no pasaron la escala)', 'directo=insert_directo monto=245.37 fn_postear=-', v_obt,
                               v_obt = 'directo=insert_directo monto=245.37 fn_postear=-');
end $$;


-- =====================================================================
-- Las que pidió la auditoría del 24-sep: cada una habría fallado antes
-- de su arreglo.
-- =====================================================================

-- 59. Lo que hace la app, CONFIRMADO: el dueño, con el rol de la app
--     (authenticated), postea, reversa y deja un devengo reversible, y se
--     adelanta lo que hace el commit (set constraints all immediate) con
--     ese mismo rol; y aparte, corrige un devengo en su mes y confirma
--     igual. Las comprobaciones diferidas (el sello, el reversible, el
--     contador) corren con el rol de la sesión: antes el sello llamaba a
--     fn_asiento_canonico, que authenticated no puede ejecutar, y TODO
--     posteo y todo reverso que llegaba desde la app se abortaba al
--     confirmar con 42501 («tu usuario no tiene permiso»). Las demás
--     pruebas lo deshacen todo antes del commit, y por eso no lo veían.
--     Cada parte en su propia subtransacción («set constraints all
--     immediate» deja las comprobaciones inmediatas hasta que termina). El
--     devengo, solo si el mes siguiente está abierto (su reverso cae ahí).
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_a         text;
  v_b         text := 'confirma';
  v_obt       text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (59, 'lo que la app postea y reversa confirma (con el rol de la app)', 'posteo_y_reverso=confirma devengo_corregido=confirma', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      v_id := (fn_postear(v_bueno)->>'id')::uuid;
      perform fn_reversar(v_id, 'c2-pruebas: reverso desde la app');
      if v_sig_desde is not null then
        perform fn_postear(v_bueno || '{"reversible": true}'::jsonb);
      end if;
      set constraints all immediate;   -- lo que hace el commit, con el rol de la app
      v_a := 'confirma';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate || ' ' || left(sqlerrm, 60);
    end;
    if v_sig_desde is not null then
      begin
        v_id := (fn_postear(v_bueno || '{"reversible": true}'::jsonb)->>'id')::uuid;
        perform fn_reversar(v_id, 'c2-pruebas: el devengo se corrige en su mes');
        set constraints all immediate;
        v_b := 'confirma';
        raise exception using errcode = 'MXT01';
      exception
        when sqlstate 'MXT01' then null;
        when others then v_b := sqlstate || ' ' || left(sqlerrm, 60);
      end;
    end if;
    v_obt := format('posteo_y_reverso=%s devengo_corregido=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (59, 'lo que la app postea y reversa confirma (con el rol de la app)', 'posteo_y_reverso=confirma devengo_corregido=confirma', v_obt,
                               v_obt = 'posteo_y_reverso=confirma devengo_corregido=confirma');
end $$;

-- 60. Un período se cierra cuando YA TERMINÓ (hora de Miami), por
--     cualquier camino:
--       · con el reloj de verdad, el dueño intenta cerrar el primer
--         período abierto que todavía no termina (antes se cierran, como
--         el SQL Editor, los anteriores, que sí terminaron) → MX002;
--       · un mes cerrado no se «reabre» con fn_abrir_periodo (antes lo
--         devolvía como si nada) → MX002;
--       · si alguien lo cierra antes de tiempo por debajo de su guarda,
--         fn_verificar_cadena lo ve.
--     Antes, el 23-sep se cerraban desde la app la apertura, el paralelo
--     y los doce meses de 2027, para siempre.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_hoy   date := fn_fecha_miami(now());
  v_obj   periodos;
  v_q     text;
  v_a     text;
  v_b     text;
  v_c     text;
  v_obt   text;
begin
  select * into v_obj from periodos p
   where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.hasta >= v_hoy
   order by p.desde limit 1;
  if v_dueno is null or v_mes is null or v_obj.periodo is null then
    insert into _pruebas values (60, 'un período no se cierra antes de terminar (ni se reabre con fn_abrir_periodo)', 'adelantado=MX002 reabrir=MX002 verificar=lo_ve', 'omitida: falta dueño o un período abierto que todavía no termine', null);
    return;
  end if;
  begin
    -- «access exclusive»: más abajo hay un ALTER TABLE de periodos (ver la cabecera).
    lock table public.periodos in access exclusive mode;
    begin
      perform pg_temp.mx_apertura_con_asiento();
      for v_q in select p.periodo from periodos p
                  where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde < v_obj.desde
                  order by p.desde loop
        update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
      end loop;
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      perform fn_cerrar_periodo(v_obj.periodo);
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate || case when sqlerrm like '%termina el%' then '' else ' ' || left(sqlerrm, 50) end;
    end;
    begin
      perform pg_temp.mx_cerrar_hasta(v_mes);
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      perform fn_abrir_periodo(v_mes);
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    begin
      execute 'alter table public.periodos disable trigger trg_periodos_guarda';
      update periodos set estado = 'cerrado', cerrado_el = clock_timestamp(),
                          cadena_al_cerrar = coalesce((select a.hash from asientos a order by a.cadena_pos desc limit 1),
                                                      repeat('0', 64))
       where periodo = v_obj.periodo;
      execute 'alter table public.periodos enable trigger trg_periodos_guarda';
      select case when v.detalle->'cerrados_antes_de_terminar' ? v_obj.periodo then 'lo_ve' else 'no_lo_ve' end
        into v_c
        from fn_verificar_cadena() v where v.control = 'periodos';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_c := sqlstate;
    end;
    v_obt := format('adelantado=%s reabrir=%s verificar=%s', v_a, v_b, coalesce(v_c, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (60, 'un período no se cierra antes de terminar (ni se reabre con fn_abrir_periodo)', 'adelantado=MX002 reabrir=MX002 verificar=lo_ve', v_obt,
                               v_obt = 'adelantado=MX002 reabrir=MX002 verificar=lo_ve');
end $$;

-- 61. La apertura se cierra con su asiento de apertura dentro. Sin él →
--     MX002 (antes se cerraba vacía, como pedía el mensaje de cerrar
--     octubre, y la balanza de QuickBooks ya no tenía dónde entrar). Con
--     él, cierra. Con el reloj fingido al día siguiente de la apertura.
do $$
declare
  v_ap  periodos;
  v_a   text;
  v_b   text;
  v_obt text;
begin
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if v_ap.periodo is null or v_ap.estado <> 'abierto'
     or exists (select 1 from asientos a
                 where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                   and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    insert into _pruebas values (61, 'la apertura no se cierra sin su asiento de apertura', 'sin_asiento=MX002 con_asiento=cerrado', 'omitida: la apertura ya está cerrada o ya tiene su asiento', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    perform pg_temp.mx_fingir_hoy(v_ap.hasta + 1);
    begin
      update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_ap.periodo;
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate || case when sqlerrm like '%Falta el asiento de apertura%' then '' else ' ' || left(sqlerrm, 50) end;
    end;
    perform pg_temp.mx_apertura_con_asiento();
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_ap.periodo;
    select p.estado into v_b from periodos p where p.periodo = v_ap.periodo;
    v_obt := format('sin_asiento=%s con_asiento=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (61, 'la apertura no se cierra sin su asiento de apertura', 'sin_asiento=MX002 con_asiento=cerrado', v_obt,
                               v_obt = 'sin_asiento=MX002 con_asiento=cerrado');
end $$;

-- 62. Un ajuste del CPA a la apertura es balance únicamente: con un gasto
--     (la depreciación de enero a septiembre que faltaba en QuickBooks)
--     → MX006; contra el capital (3900) entra. Antes entraba el gasto y
--     caía en el resultado del paralelo, el que se compara contra
--     QuickBooks.
do $$
declare
  v_dueno   uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_gasto   text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco   text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_capital text := nullif(current_setting('mx_pruebas.capital', true), '');
  v_desde   date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_ap      text;
  v_a       text;
  v_b       text;
  v_obt     text;
begin
  select periodo into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if v_dueno is null or v_gasto is null or v_banco is null or v_capital is null or v_desde is null or v_ap is null then
    insert into _pruebas values (62, 'un ajuste del CPA a la apertura es balance únicamente', 'resultados=MX006 balance=entró', 'omitida: falta dueño, cuenta, mes abierto o la apertura', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    perform pg_temp.mx_cerrar_hasta(v_ap);   -- la apertura, cerrada (reloj fingido, con su asiento)
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_postear(jsonb_build_object(
        'tipo', 'ajuste_cpa', 'afecta_periodo', v_ap, 'motivo', 'c2-pruebas: AJE del CPA a la apertura',
        'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: ajuste a la apertura con un gasto',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '30.00'),
                                    jsonb_build_object('cuenta', v_banco, 'monto', '-30.00'))));
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      perform fn_postear(jsonb_build_object(
        'tipo', 'ajuste_cpa', 'afecta_periodo', v_ap, 'motivo', 'c2-pruebas: AJE del CPA a la apertura',
        'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: ajuste a la apertura contra el capital',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_capital, 'monto', '30.00'),
                                    jsonb_build_object('cuenta', v_banco, 'monto', '-30.00'))));
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    v_obt := format('resultados=%s balance=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (62, 'un ajuste del CPA a la apertura es balance únicamente', 'resultados=MX006 balance=entró', v_obt,
                               v_obt = 'resultados=MX006 balance=entró');
end $$;

-- 63. Un devengo reversible que sale de un documento (el ajuste de WIP de
--     f10, el devengo de horas de f03), posteado por su puente (se simula
--     desde el SQL Editor con fn_postear_interno, como la 41):
--       · correr el puente otra vez → 23505: su reverso automático del
--         día 1 es parte del devengo, no una corrección (antes: MX007, y
--         su mensaje llevaba a meter el devengo dos veces en el mes);
--       · un sustituto sin haberlo reversado → 23505 (sigue vivo);
--       · reversar su reverso automático → MX007;
--       · el dueño lo corrige en su mes con fn_reversar: su reverso va en
--         su fecha y anula su reverso del día 1; el devengo bueno entra
--         como sustituto. El mes queda con UN devengo, el bueno, y el
--         siguiente lo deshace una vez (antes fn_reversar daba MX007 y el
--         mes quedaba con los dos);
--       · un reverso de corrección metido a mano sin anular el reverso del
--         día 1 no llega al commit → MX007.
--     Y la cadena, sana (control reversos).
do $$
declare
  v_dueno     uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_c5        text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco     text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_obra      text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_mes       text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_sig       text := nullif(current_setting('mx_pruebas.sig', true), '');
  v_desde     date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_doc       jsonb;
  v_a         uuid;
  v_auto      uuid;
  v_b         uuid;
  v_x         uuid := gen_random_uuid();
  v_otra      text;
  v_sus0      text;
  v_rauto     text;
  v_corr      text;
  v_sus       text;
  v_m         numeric;
  v_s         numeric;
  v_rev       text;
  v_sin       text;
  v_obt       text;
  v_esp       text := 'otra_vez=23505 sustituto_antes=23505 reversar_auto=MX007 corregir=entró sustituto=entró '
                      'mes=120.00 siguiente=-120.00 reversos=t sin_anular=MX007';
begin
  if v_dueno is null or v_c5 is null or v_banco is null or v_obra is null or v_desde is null or v_sig is null then
    insert into _pruebas values (63, 'un devengo de un documento: el puente no lo duplica y se corrige en su mes', v_esp, 'omitida: faltan dueño, obra, cuentas o dos meses abiertos seguidos', null);
    return;
  end if;
  v_doc := jsonb_build_object(
    'camino', 'puente', 'origen_tabla', 'c2_pruebas_wip', 'origen_id', 'c2-pruebas-63',
    'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: devengo de un documento (se deshace)',
    'reversible', true,
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_c5, 'monto', '100.00', 'proyecto_id', v_obra),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-100.00')));
  begin
    v_a := (fn_postear_interno(v_doc)->>'id')::uuid;
    select r.id into v_auto from asientos r where r.reversa_a = v_a and r.camino = 'reverso_automatico';
    begin
      perform fn_postear_interno(v_doc);
      v_otra := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_otra := sqlstate;
    end;
    begin
      perform fn_postear_interno(v_doc || jsonb_build_object('sustituye_a', v_a));
      v_sus0 := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_sus0 := sqlstate;
    end;
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      perform fn_reversar(v_auto, 'c2-pruebas: reversar el reverso automático');
      v_rauto := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_rauto := sqlstate;
    end;
    -- La corrección, como la haría el dueño desde la app (se queda).
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      perform fn_reversar(v_a, 'c2-pruebas: el estimado revisado cambió');
      execute 'reset role';
      perform set_config('request.jwt.claims', '', true);
      v_corr := 'entró';
    exception
      when others then v_corr := sqlstate;
    end;
    -- El devengo bueno, como sustituto.
    begin
      perform fn_postear_interno(v_doc || jsonb_build_object(
        'sustituye_a', v_a,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_c5, 'monto', '120.00', 'proyecto_id', v_obra),
                                    jsonb_build_object('cuenta', v_banco, 'monto', '-120.00'))));
      v_sus := 'entró';
    exception
      when others then v_sus := sqlstate;
    end;
    select coalesce(sum(l.monto) filter (where a.periodo = v_mes), 0), coalesce(sum(l.monto) filter (where a.periodo = v_sig), 0)
      into v_m, v_s
      from asientos a
      join asiento_lineas l on l.asiento_id = a.id
     where a.origen_tabla = 'c2_pruebas_wip' and a.origen_id = 'c2-pruebas-63' and l.cuenta = v_c5;
    -- Lo que hace el commit (la corrección confirma) y la cadena, sana. En
    -- su propia subtransacción: «set constraints all immediate» deja las
    -- comprobaciones inmediatas hasta que termine, y lo de abajo mete las
    -- líneas antes que su cabecera.
    begin
      set constraints all immediate;
      select case when v.ok then 't' else 'f' end into v_rev from fn_verificar_cadena() v where v.control = 'reversos';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_rev := sqlstate;
    end;
    -- Un reverso de corrección metido a mano, sin anular el reverso del día 1.
    begin
      v_b := (fn_postear_interno(v_doc || '{"origen_id": "c2-pruebas-63b"}'::jsonb)->>'id')::uuid;
      insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id)
      values (v_x, 1, v_c5, -100.00, v_obra), (v_x, 2, v_banco, 100.00, null);
      insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion, motivo,
                            reversa_a, origen_tabla, origen_id, hash_anterior, hash)
      values (v_x, '-', 0, 0, 0, v_desde + 4, '-', 'reverso', 'c2-pruebas: reverso a mano del devengo', 'c2-pruebas',
              v_b, 'c2_pruebas_wip', 'c2-pruebas-63b', repeat('0', 64), repeat('0', 64));
      set constraints all immediate;
      v_sin := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_sin := sqlstate;
    end;
    v_obt := format('otra_vez=%s sustituto_antes=%s reversar_auto=%s corregir=%s sustituto=%s mes=%s siguiente=%s reversos=%s sin_anular=%s',
                    v_otra, v_sus0, v_rauto, v_corr, v_sus, v_m, v_s, coalesce(v_rev, '-'), v_sin);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (63, 'un devengo de un documento: el puente no lo duplica y se corrige en su mes', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 64. Con saldo vivo, una cuenta no endurece su regla de dimensión si lo
--     deja atrapado (la guarda de c1) → MX003 las dos: a obra obligatoria
--     con saldo sin obra, y a obra prohibida con saldo con obra. Antes
--     entraba: la CxC de apertura, sin obra, ya no se podía cobrar sin
--     obra, y el auxiliar por obra no cuadraba nunca contra el mayor.
do $$
declare
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_cta   text;
  v_mov   jsonb;
  v_saldo numeric;
  v_a     text;
  v_b     text;
  v_obt   text;
begin
  select codigo into v_cta from cuentas
   where tipo = 'activo' and regla_obra = 'opcional' and regla_cost_code = 'prohibida' and activa and imputable
   order by (codigo = '1110') desc, codigo limit 1;
  if v_cta is null or v_banco is null or v_obra is null or v_desde is null then
    insert into _pruebas values (64, 'con saldo vivo, una regla de dimensión no se endurece si lo atrapa', 'obligatoria=MX003 prohibida=MX003', 'omitida: falta una cuenta con obra opcional, banco, obra o mes abierto', null);
    return;
  end if;
  begin
    begin
      v_mov := jsonb_build_object(
        'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: saldo sin obra',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cta, 'monto', '100.00'),
                                    jsonb_build_object('cuenta', v_banco, 'monto', '-100.00')));
      perform fn_postear(v_mov);
      select coalesce(sum(l.monto), 0) into v_saldo from asiento_lineas l where l.cuenta = v_cta and l.proyecto_id is null;
      if v_saldo = 0 then
        perform fn_postear(v_mov);   -- por si el saldo anterior era justo −100.00
      end if;
      update cuentas set regla_obra = 'obligatoria' where codigo = v_cta;
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      v_mov := jsonb_build_object(
        'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: saldo con obra',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cta, 'monto', '100.00', 'proyecto_id', v_obra),
                                    jsonb_build_object('cuenta', v_banco, 'monto', '-100.00')));
      perform fn_postear(v_mov);
      select coalesce(sum(l.monto), 0) into v_saldo from asiento_lineas l where l.cuenta = v_cta and l.proyecto_id = v_obra;
      if v_saldo = 0 then
        perform fn_postear(v_mov);
      end if;
      update cuentas set regla_obra = 'prohibida' where codigo = v_cta;
      v_b := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    v_obt := format('obligatoria=%s prohibida=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (64, 'con saldo vivo, una regla de dimensión no se endurece si lo atrapa', 'obligatoria=MX003 prohibida=MX003', v_obt,
                               v_obt = 'obligatoria=MX003 prohibida=MX003');
end $$;

-- 65. El libro tiene UNA apertura, ni con su guarda apagada: una segunda,
--     anterior (con saldos que cambiarían el balance de todos los meses
--     cerrados), choca con el índice único → 23505. Y si además se quita
--     el índice, fn_verificar_cadena lo ve (control periodos). Antes, los
--     nueve controles en verde.
do $$
declare
  v_ap    periodos;
  v_desde date;
  v_nueva text;
  v_a     text;
  v_b     text;
  v_obt   text;
begin
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if v_ap.periodo is null then
    insert into _pruebas values (65, 'una sola apertura, ni con su guarda apagada', 'segunda=23505 sin_indice=periodos:f', 'omitida: no hay apertura', null);
    return;
  end if;
  v_desde := v_ap.desde - 30;
  v_nueva := to_char(v_desde, 'YYYY-MM') || '-APERTURA';
  begin
    lock table public.periodos in access exclusive mode;   -- el ALTER TABLE de abajo (ver la cabecera)
    begin
      execute 'alter table public.periodos disable trigger trg_periodos_guarda';
      insert into periodos (periodo, tipo, anio, desde, hasta, paralelo)
      values (v_nueva, 'apertura', extract(year from v_desde)::int, v_desde, v_desde, v_ap.paralelo);
      v_a := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_a := sqlstate;
    end;
    begin
      execute 'drop index public.periodos_una_apertura';
      execute 'alter table public.periodos disable trigger trg_periodos_guarda';
      insert into periodos (periodo, tipo, anio, desde, hasta, paralelo)
      values (v_nueva, 'apertura', extract(year from v_desde)::int, v_desde, v_desde, v_ap.paralelo);
      execute 'alter table public.periodos enable trigger trg_periodos_guarda';
      select case when v.ok then 't' else 'f' end into v_b from fn_verificar_cadena() v where v.control = 'periodos';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_b := sqlstate;
    end;
    v_obt := format('segunda=%s sin_indice=periodos:%s', v_a, coalesce(v_b, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (65, 'una sola apertura, ni con su guarda apagada', 'segunda=23505 sin_indice=periodos:f', v_obt,
                               v_obt = 'segunda=23505 sin_indice=periodos:f');
end $$;

-- 66. Una cuenta reescrita por debajo de sus triggers (ALTER TABLE … TYPE
--     … USING: inactiva una cuenta con saldo y le da la vuelta a su saldo
--     normal, sin pasar por su guarda ni dejar fila en cuentas_historial)
--     se delata: la cuenta ya no está como la dejó su último cambio
--     apuntado (control cuentas) y la tabla se reescribió (su huella,
--     control triggers). Antes, los nueve controles en verde.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_c     text;
  v_t     boolean;
  v_obt   text;
begin
  if v_bueno is null or v_banco is null then
    insert into _pruebas values (66, 'una cuenta reescrita con ALTER TABLE … TYPE se delata', 'cuentas=f huella_tabla=t', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    lock table public.cuentas in access exclusive mode;   -- antes que el candado de la cadena (ver la 24)
    perform fn_postear(v_bueno);   -- el banco se mueve
    execute format($a$
      alter table public.cuentas
        alter column activa       type boolean using (case when codigo = %1$L then false else activa end),
        alter column saldo_normal type text    using (case when codigo = %1$L
                                                           then (case saldo_normal when 'debe' then 'haber' else 'debe' end)
                                                           else saldo_normal end)
    $a$, v_banco);
    select case when v.ok then 't' else 'f' end into v_c from fn_verificar_cadena() v where v.control = 'cuentas';
    select exists (select 1 from jsonb_array_elements_text(v.detalle->'huellas') h where h like 'tabla cuentas:%')
      into v_t
      from fn_verificar_cadena() v where v.control = 'triggers';
    v_obt := format('cuentas=%s huella_tabla=%s', coalesce(v_c, '-'), case when v_t then 't' when not v_t then 'f' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (66, 'una cuenta reescrita con ALTER TABLE … TYPE se delata', 'cuentas=f huella_tabla=t', v_obt,
                               v_obt = 'cuentas=f huella_tabla=t');
end $$;

-- 67. Cerrar otra vez un período ya cerrado → MX002, con la hora del
--     cierre en Miami y sin segundos (antes salía en UTC, con
--     microsegundos: un cierre de fin de mes por la noche decía otro día).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_obt   text;
begin
  if v_dueno is null or v_mes is null then
    insert into _pruebas values (67, 'cerrar dos veces: la hora del cierre, en Miami', 'MX002 (hora de Miami)', 'omitida: falta dueño o mes abierto', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;   -- antes que el de la cadena (ver la cabecera)
    perform pg_temp.mx_cerrar_hasta(v_mes);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_mes);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || case when sqlerrm like '%hora de Miami%' and sqlerrm not like '%+00%'
                                then ' (hora de Miami)' else ' ' || left(sqlerrm, 60) end;
  end;
  insert into _pruebas values (67, 'cerrar dos veces: la hora del cierre, en Miami', 'MX002 (hora de Miami)', v_obt, v_obt = 'MX002 (hora de Miami)');
end $$;


-- 68. Las pruebas no dejaron rastro: el libro, el plan, su historial, las
--     secuencias y las huellas (el reloj fingido y los ALTER TABLE de
--     algunas pruebas se deshicieron) están igual que al empezar. Va la
--     última.
do $$
declare
  v_antes text := current_setting('mx_pruebas.foto', true);
  v_obt   text;
begin
  v_obt := pg_temp.mx_foto();
  insert into _pruebas values (68, 'las pruebas no dejan rastro (libro, plan, historial, secuencias y huellas)', v_antes, v_obt, v_obt = v_antes);
end $$;

select * from _pruebas order by n;
