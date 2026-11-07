-- =====================================================================
-- c9-pruebas.sql — el cierre del mes, la ronda, los activos fijos y la
-- reserva de impuestos se prueban a sí mismos (c9-cierre.sql). 7-nov-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c9-cierre.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 36 filas, todas
-- con ok = true (las que salen «omitida» dicen por qué y no son un fallo).
-- Si el editor se cansa antes del final, la corrida sigue en el servidor y
-- se lee después en pruebas.c9_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c8 y c9-cierre.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c9-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni la apertura de prueba, ni los cierres, ni los activos, ni
-- lo que la ronda escribió); la 34 lo comprueba. Ningún aviso sale al
-- teléfono: la sesión pone mxp.cierre_sin_push = '1' y la 26, que cuenta
-- los avisos, cambia fn_cartero por una copia que los apunta en una tabla
-- temporal (se deshace con la prueba, como c2-pruebas hace con el reloj).
--
-- VALEN CON DATOS REALES, SIN SUPONER QUE PRODUCCIÓN ESTÁ EN VERDE. Lo que
-- siembran es suyo («C9 PRUEBA …», montos redondos) y se deshace. Las
-- pruebas que necesitan el banco del período EN VERDE (la 11, y la 23, 24 y
-- 27 para cerrarlo) aparcan primero lo real que lo detiene, dentro de su
-- subtransacción: ignoran con su motivo los movimientos del banco del mes
-- que siguen sin clasificar, importan un lote vacío hasta el último día del
-- mes para cada cuenta cuyos archivos no llegan, concilian y confirman cada
-- cuenta al último día (con el saldo del libro y su motivo, si el archivo
-- dice otro), y quitan la API a toda función ajena SECURITY DEFINER que el
-- control «permisos» de c2 marque (hoy, en producción, fn_costos_marcar).
-- Si aun así queda algo en rojo que la prueba no puede aparcar (una
-- conciliación que c6 no deja confirmar porque falta la de apertura, un
-- casado que se contradice, una antigüedad que no cuadra con el mayor…), la
-- prueba sale «omitida» y dice qué quedó Y QUÉ DIJO LA CAPA al negarse (el
-- MX008 de c6 con «lo que falta», tal cual: lo mismo que Edgar vería en
-- Conciliar): no es un fallo, es el estado de los libros. Lo que ya existe
-- de verdad en la base se respeta: la 15 resta de 1590 lo que los activos
-- reales ya explican antes de dar de alta el suyo, así que sigue en verde
-- cuando la f12 cargue la cédula del CPA.
-- Las pruebas que cierran períodos toman antes «lock table periodos in
-- exclusive mode», como c2-pruebas: sin él se pueden trabar con un posteo de
-- la app. El período que se cierra es el mes abierto más viejo que ya
-- terminó (y la apertura antes, si sigue abierta, con un asiento de
-- apertura de prueba si no tiene el suyo).
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, tablas, vistas, funciones, la configuración,
--    el bucket «cierres» con sus 4 policies si hay Storage, pg_cron si hay
--    cron, cada objeto con su comentario «c9: …»);
--  2 las precondiciones en rojo (desde la app; sin fn_banco_control);
--  3 la API: anon y service_role nada; el equipo 42501; el dueño entra; las
--    vistas por rol; la ronda y sus auxiliares sin API;
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo sellado, RLS y
--    policy en cada tabla, vistas security_invoker, y los controles de c2
--    («permisos»), c6 («protecciones del banco») y c4 («protecciones de c4»)
--    en verde con c9 pegado;
--  5 v_cierre_estado (una fila por apertura y mes, el siguiente, terminado,
--    la confirmación, detienen y avisos de la última revisión);
--  6 el orden y el calendario (la apertura primero; un mes futuro no cierra;
--    si la apertura real no se puede poner en verde, omitida con lo que quedó);
--  7 la apertura sin su asiento (rojo) y con él (verde);
--  8 el cuadre del período;
--  9 el banco: un cargo sembrado sin clasificar pone el 40 en rojo con
--    cuántos y cuánto; ignorado, vuelve;
-- 10 las propuestas de la IA del mes sin decidir (aviso; sin c8, omitida);
-- 11 la conciliación al último día del mes: en rojo nombra las cuentas; con
--    cada cuenta conciliada y confirmada (aparcada), en verde; si c6 no deja
--    confirmar alguna, omitida con lo que c6 dijo;
-- 12 2010 por proveedor: el detalle, y una línea sin proveedor ni partida
--    (aviso);
-- 13 el auxiliar por obra (verde con su detalle; c2 no deja entrar la línea
--    sin obra que lo pondría en rojo);
-- 14 los recibos sin foto y con impuesto desconocido (avisos);
-- 15 1590 = activos (sin activos, verde y lo dice; el de prueba cuadra con el
--    resto de 1590 que los activos reales no explican; con otro de más, rojo);
-- 16 la depreciación del mes: el plan, el asiento Dr 6950 / Cr 1590 por
--    fn_postear, idempotente, el tope del residual, reversado se vuelve a
--    postear, v_activos_fijos;
-- 17 la baja de un activo (deja de depreciar; MX008 dos veces; sus frenos);
-- 18 el alta y sus frenos (22023, MX004, MX005; el método de la configuración);
-- 19 la cadena del libro: una función ajena SECURITY DEFINER que lee el
--    libro y la API ejecuta pone «libro: permisos» en rojo con qué hacer;
--    quitada, verde;
-- 20 las capas: sus renglones (banco, estados, puentes; p1 y c8 si están) y
--    el nivel que les toca (una alarma es aviso, un cuadre detiene);
-- 21 fn_cierre_cerrar con rojo → MX010 con la lista, y nada cerrado;
-- 22 la confirmación mal escrita → 22023, y nada cerrado;
-- 23 EL CIERRE: la apertura y después el mes, como el dueño por la API;
--    cierres con su hash, su balanza y su revisión; v_cierres con el nombre;
--    después escribir en el mes por fn_postear y como el SQL Editor da
--    MX002, un ajuste del CPA al mes cerrado entra en el siguiente, y cerrar
--    otra vez da MX002;
-- 24 el export (solo cerrado; la carpeta, el sha256, el archivo en Storage;
--    registra; repetir deja historial);
-- 25 la ronda (sus filas con el día de Miami, v_ronda_ultima, dos corridas,
--    los 90 días, apagada no escribe);
-- 26 los avisos de la ronda: un rojo nuevo manda UNO; repetido, ninguno; con
--    mxp.cierre_sin_push = '1' o aviso_push apagado, ninguno;
-- 27 la balanza de un mes cerrado que cambió por debajo de las guardas → la
--    ronda lo pone en rojo;
-- 28 la reserva 1030: sin % lo dice; con % calcula transfiere/sobra; marcar
--    y anular un estimado;
-- 29 el estimado que vence en 15 días (con el reloj fingido, como c2-pruebas);
-- 30 el DR-15 (lo cargado a 2300, la base del use tax de c8 si está, la nota);
-- 31 el hash del mayor (estable, cambia con una línea, el de un período vacío);
-- 32 la guarda de las tablas de c9 (a mano, MX003: también el dueño por la API);
-- 33 fn_cierre_config y sus frenos;
-- 34 nada queda al deshacer;
-- 35 el cierre de la suite: c2, c3, c6 y c4 en verde con c9 pegado (salvo lo
--    que ya estaba en rojo antes, que la prueba dice), c8 sin cuadres rojos,
--    y nada de c9 en la API ni SECURITY DEFINER;
-- 36 pegar c9 dos veces no hace daño: lo comprueba el banco (dos pegados
--    seguidos antes de esta suite); aquí, que fn_cierre_pegado responde y
--    que la configuración no se pisó.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el período que se cierra, hoy, lo que ya estaba en rojo.
create temp table if not exists _c9 (k text primary key, v text);
truncate _c9;
insert into _c9
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c9
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c9 values ('hoy', fn_fecha_miami(now())::text);
insert into _c9
select 'apertura', p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
-- el mes abierto más viejo que ya terminó (el que se cierra en las pruebas)
insert into _c9
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
-- el mes abierto siguiente al anterior (para el ajuste del CPA): el primero abierto después del «mes»
insert into _c9
select 'mes_sig', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > (select q.desde from periodos q where q.periodo = (select v from _c9 where k = 'mes'))
 order by p.desde limit 1;
-- un mes abierto que todavía no terminó (el calendario lo frena)
insert into _c9
select 'mes_futuro', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta >= fn_fecha_miami(now()) order by p.desde desc limit 1;
insert into _c9 values ('hay_c8', (to_regclass('public.contador_propuestas') is not null)::text);
insert into _c9 values ('hay_p1', (to_regclass('public.v_stripe_control') is not null)::text);
insert into _c9 values ('hay_storage', (to_regclass('storage.objects') is not null)::text);
insert into _c9 values ('hay_cron', exists (select 1 from pg_namespace where nspname = 'cron')::text);
grant select on _c9 to public;  -- las pruebas cambian de rol y siguen leyendo lo común
-- Lo que el aparcado (pg_temp.c9_aparcar) no pudo poner en verde y qué dijo
-- la capa al negarse (el MX008 de c6 con «lo que falta», el revoke que no
-- entró…): las pruebas que salen «omitida» lo enseñan, para que se lea el
-- estado de los libros con las palabras de la capa y no un «rojo» a secas.
create temp table if not exists _c9_aparcado (periodo text, donde text, dijo text);
truncate _c9_aparcado;
grant select on _c9_aparcado to public;

-- El control de c4 sin tope por reloj para la sesión (como c8-pruebas), y
-- ningún aviso al teléfono desde la ronda.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c9(k text) returns text language sql as $$ select v from _c9 where k = $1 $$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o el equipo por
-- la API (authenticated, en aal2), anon o service_role.
create or replace function pg_temp.c9_ser(quien text) returns void language plpgsql as $$
begin
  execute 'reset role';
  if quien = 'editor' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien in ('service_role', 'anon') then
    perform set_config('request.jwt.claims', json_build_object('role', quien)::text, true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute format('set local role %I', quien);
  else
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c9(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c9(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Una fila de la revisión, en una línea: ok|nivel|ir_a|detalle
create or replace function pg_temp.c9_fila(p_periodo text, p_orden int) returns text language sql as $$
  select format('%s|%s|%s|%s', case when x.ok then 'verde' else 'rojo' end, x.nivel, coalesce(x.ir_a, '-'), x.detalle)
    from fn_cierre_revisar(p_periodo) x where x.orden = p_orden
$$;
create or replace function pg_temp.c9_rojos(p_periodo text) returns text language sql as $$
  select coalesce(string_agg(x.control, '; ' order by x.orden), 'ninguno')
    from fn_cierre_revisar(p_periodo) x where x.nivel = 'detiene' and x.ok is distinct from true
$$;
-- El primer número de un texto («7 movimiento(s)…» → 7)
create or replace function pg_temp.c9_num(p text) returns int language sql as $$
  select nullif(substring(coalesce(p, '') from '^[^0-9]*([0-9]+)'), '')::int
$$;
-- Un monto como lo escribe fn_cierre_usd («-$8,666.67» → -8666.67)
create or replace function pg_temp.c9_usd(p text) returns numeric language sql as $$
  select nullif(replace(replace(coalesce(p, ''), '$', ''), ',', ''), '')::numeric
$$;

-- La apertura con un asiento de apertura de prueba si no tiene el suyo
-- (1600 contra 3100: no toca ninguna cuenta del banco). Devuelve 'ya había',
-- 'cerrada' o el número del asiento.
create or replace function pg_temp.c9_apertura() returns text language plpgsql as $$
declare
  p periodos;
begin
  select * into p from periodos where periodo = pg_temp.c9('apertura');
  if p.estado = 'cerrado' then return 'cerrada'; end if;
  if exists (select 1 from asientos a
              where a.periodo = p.periodo and a.tipo = 'apertura' and a.reversa_a is null
                and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    return 'ya había';
  end if;
  return fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(p.desde, 'YYYY-MM-DD'),
    'descripcion', 'C9 PRUEBA: apertura de prueba (se deshace)',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))))->>'numero';
end $$;

-- Un cargo del banco como lo trae Plaid (en nombre del dueño), casado por el
-- motor: sin ticket ni asiento que lo explique queda pendiente. Devuelve el
-- movimiento. (Como pg_temp.c8_cargo de c8-pruebas; la descripción empieza
-- por «C9 PRUEBA».)
create or replace function pg_temp.c9_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text, p_cuenta text default '1010')
returns uuid language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_mov    uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c9('dueno'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c9('dueno'), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', p_cuenta, 'nombre', 'Plaid · c9-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object('id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text,
                                                  'descripcion', p_desc, 'tipo', 'DEBIT', 'pendiente', false))));
  perform fn_banco_casar_todo(p_cuenta);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  return v_mov;
end $$;

-- APARCAR lo real que detiene un período (dentro de la prueba; se deshace):
-- los movimientos del banco del mes sin clasificar (ignorados con su
-- motivo), los archivos que no llegan al último día (un lote vacío con el
-- saldo del libro), las cuentas sin conciliar al último día (fn_conciliar,
-- su motivo si el archivo dice otro saldo, y confirmar), y la API de toda
-- función ajena SECURITY DEFINER que «permisos» marque. Cada cosa con su
-- excepción: lo que no se pueda, se queda, y lo que la capa dijo al negarse
-- se apunta en _c9_aparcado (pg_temp.c9_aparcado lo cuenta en una línea).
-- Devuelve lo que sigue deteniendo (nulo = nada: el período se puede cerrar).
create or replace function pg_temp.c9_aparcar(p_periodo text) returns text language plpgsql as $$
declare
  p periodos;
  r record;
  v jsonb;
  c conciliaciones;
begin
  perform pg_temp.c9_ser('editor');
  delete from _c9_aparcado where periodo = p_periodo;
  select * into p from periodos where periodo = p_periodo;
  if p.tipo = 'mes' then
    for r in select m.id from movimientos_banco m where m.periodo = p.periodo and m.estado = 'pendiente' loop
      begin
        perform fn_banco_ignorar(r.id, 'c9-pruebas: aparcado mientras dura la prueba (se deshace)');
      exception when others then
        insert into _c9_aparcado values (p_periodo, 'ignorar el movimiento ' || r.id, sqlstate || ' ' || sqlerrm);
      end;
    end loop;
    for r in select distinct m.cuenta from movimientos_banco m where m.fecha <= p.hasta order by 1 loop
      -- (un lote vacío con el saldo del libro al último día, en el signo del
      -- libro, si ningún archivo trae el saldo de ese día: así la
      -- conciliación tiene «lo que dijo el banco» y los archivos llegan al
      -- fin de mes)
      begin
        if not exists (select 1 from archivos_banco a
                        where a.cuenta = r.cuenta and a.retirado_el is null and a.saldo_al = p.hasta and a.saldo is not null) then
          perform fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', r.cuenta,
            'nombre', 'c9-pruebas: hasta el fin de mes ' || r.cuenta || ' (se deshace)', 'hasta', p.hasta::text,
            'saldo', fn_banco_saldo_libros(r.cuenta, p.hasta)::text, 'saldo_al', p.hasta::text, 'filas', '[]'::jsonb));
        end if;
      exception when others then
        insert into _c9_aparcado values (p_periodo, 'importar hasta el fin de mes ' || r.cuenta, sqlstate || ' ' || sqlerrm);
      end;
      begin
        if not exists (select 1 from conciliaciones x
                        where x.cuenta = r.cuenta and x.estado = 'confirmada' and x.tipo = 'normal' and x.fecha_corte >= p.hasta) then
          v := fn_conciliar(r.cuenta, p.hasta, null);
          select * into c from conciliaciones where id = (v->>'conciliacion')::uuid;
          if c.saldo_banco is null or c.diferencia is distinct from 0 then
            -- (el saldo del statement como lo dice el statement: en una
            -- tarjeta, lo que se debe en positivo)
            v := fn_conciliar(r.cuenta, p.hasta,
                   (case when fn_banco_tipo_cuenta(r.cuenta) = 'tarjeta' then -1 else 1 end * fn_banco_saldo_libros(r.cuenta, p.hasta))::text);
            select * into c from conciliaciones where id = (v->>'conciliacion')::uuid;
          end if;
          if coalesce(c.n_pide_motivo, 0) > 0 then
            perform fn_conciliacion_saldo(c.id, 'c9-pruebas: saldo del libro aparcado mientras dura la prueba', 'c9-pruebas (se deshace)');
          end if;
          perform fn_conciliacion_confirmar(c.id);
        end if;
      exception when others then
        -- (lo típico: el MX008 de fn_conciliacion_confirmar con «lo que
        -- falta» —en producción hoy, la conciliación de apertura de la 1010—)
        insert into _c9_aparcado values (p_periodo, 'conciliar ' || r.cuenta || ' al ' || p.hasta, sqlstate || ' ' || sqlerrm);
      end;
    end loop;
  end if;
  for r in select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(k.detalle->'fallan') x(t)
            where k.control = 'permisos' and x.t like 'la función % es SECURITY DEFINER%' loop
    begin
      execute format('revoke execute on function %s from public, anon, authenticated, service_role',
                     substring(r.t from 'la función (.+?) es SECURITY DEFINER'));
    exception when others then
      insert into _c9_aparcado values (p_periodo, 'quitar la API a ' || substring(r.t from 'la función (.+?) es SECURITY DEFINER'), sqlstate || ' ' || sqlerrm);
    end;
  end loop;
  return (select string_agg(x.control, '; ' order by x.orden)
            from fn_cierre_revisar(p_periodo) x where x.nivel = 'detiene' and x.ok is distinct from true);
end $$;

-- Lo que la capa dijo al negarse a aparcar algo del período, en una línea
-- («conciliar 1010 al 2026-10-31: MX008 La conciliación de 1010 al
-- 2026-10-31 no se confirma todavía. Lo que falta: la diferencia es -599.60,
-- y falta la conciliación de apertura de 1010 …»): cada mensaje recortado a
-- 400 letras, como mucho cinco y «… y N más». Nulo si todo se aparcó.
create or replace function pg_temp.c9_aparcado(p_periodo text) returns text language sql as $$
  with a as (select a.donde, case when length(a.dijo) > 400 then left(a.dijo, 400) || '…' else a.dijo end as dijo,
                    row_number() over (order by a.donde) as i, count(*) over () as n
               from _c9_aparcado a where a.periodo = p_periodo)
  select string_agg(a.donde || ': ' || a.dijo, ' · ' order by a.i)
         || case when max(a.n) > 5 then format(' · … y %s más', max(a.n) - 5) else '' end
    from a where a.i <= 5
$$;

-- CERRAR TODO: la apertura (con su asiento de prueba si hace falta) y
-- después el mes, como el dueño por la API, con todo aparcado antes.
-- Devuelve nulo si cerró los dos, o qué quedó deteniendo y, entre
-- paréntesis, qué dijo la capa al no dejar aparcarlo (la prueba sale
-- «omitida» con eso). Toma el candado de periodos primero (c2-pruebas).
create or replace function pg_temp.c9_cerrar_todo() returns text language plpgsql as $$
declare
  v_ap  text := pg_temp.c9('apertura');
  v_mes text := pg_temp.c9('mes');
  v_p   text;
  v_q   text;
begin
  if v_mes is null then
    return 'no hay un mes abierto que ya haya terminado';
  end if;
  lock table public.periodos in exclusive mode;
  perform pg_temp.c9_ser('editor');
  if (select estado from periodos where periodo = v_ap) = 'abierto' then
    perform pg_temp.c9_apertura();
    v_q := pg_temp.c9_aparcar(v_ap);
    if v_q is not null then return 'la apertura: ' || v_q || coalesce(' (' || pg_temp.c9_aparcado(v_ap) || ')', ''); end if;
    perform pg_temp.c9_ser('dueno');
    perform fn_cierre_cerrar(v_ap, 'CERRAR LA APERTURA');
    perform pg_temp.c9_ser('editor');
  end if;
  -- (otros meses abiertos antes del mes, cerrados también, en orden)
  for v_p in select p.periodo from periodos p
              where p.tipo = 'mes' and p.estado = 'abierto' and p.desde < (select q.desde from periodos q where q.periodo = v_mes)
              order by p.desde loop
    v_q := pg_temp.c9_aparcar(v_p);
    if v_q is not null then return fn_cierre_nombre(v_p) || ': ' || v_q || coalesce(' (' || pg_temp.c9_aparcado(v_p) || ')', ''); end if;
    perform pg_temp.c9_ser('dueno');
    perform fn_cierre_cerrar(v_p, fn_cierre_confirmacion(v_p));
    perform pg_temp.c9_ser('editor');
  end loop;
  v_q := pg_temp.c9_aparcar(v_mes);
  if v_q is not null then return fn_cierre_nombre(v_mes) || ': ' || v_q || coalesce(' (' || pg_temp.c9_aparcado(v_mes) || ')', ''); end if;
  perform pg_temp.c9_ser('dueno');
  perform fn_cierre_cerrar(v_mes, fn_cierre_confirmacion(v_mes));
  perform pg_temp.c9_ser('editor');
  return null;
end $$;

-- Lo que hay en lo que c9 toca (la 34 lo compara)
create or replace function pg_temp.c9_conteos() returns text language sql as $$
  select format('config %s · cierres %s · revisiones %s · ronda %s · activos %s · depreciaciones %s · estimados %s · asientos %s · '
                'cerrados %s · movimientos pendientes %s · conciliaciones %s · archivos %s · recibos %s · cuentas %s · perfiles %s · funciones %s',
                (select count(*) from cierre_config), (select count(*) from cierres), (select count(*) from cierre_revisiones),
                (select count(*) from ronda_resultados), (select count(*) from activos_fijos), (select count(*) from activos_depreciaciones),
                (select count(*) from reserva_estimados), (select count(*) from asientos), (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) from movimientos_banco where estado = 'pendiente'), (select count(*) from conciliaciones),
                (select count(*) from archivos_banco), (select count(*) from recibos), (select count(*) from cuentas),
                (select count(*) from perfiles), (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c9 values ('conteos', pg_temp.c9_conteos());
-- (lo de c4 y c6 que ya estaba en rojo ANTES de las pruebas: la 35 lo dice y no lo cuenta)
insert into _c9
select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _c9
select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, funciones, la configuración,
--    el bucket y sus policies (si hay Storage), pg_cron (si hay cron), y
--    cada objeto con su comentario «c9: …».
do $$
declare
  v_obt text;
  v_pre text;
  v_tab int; v_vis int; v_fn int; v_sin int; v_cfg text; v_bk text; v_cron text;
begin
  begin
    perform pg_temp.c9_ser('editor');
    v_pre := coalesce(fn_cierre_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public'
       and tablename in ('cierre_config', 'cierres', 'cierre_revisiones', 'ronda_resultados', 'activos_fijos', 'activos_depreciaciones', 'reserva_estimados');
    select count(*) into v_vis from pg_views where schemaname = 'public'
       and viewname in ('v_cierre_estado', 'v_cierres', 'v_ronda_ultima', 'v_activos_fijos', 'v_reserva_impuestos', 'v_dr15_mes');
    select count(*) into v_fn from pg_proc where pronamespace = 'public'::regnamespace
       and proname in ('fn_cierre_revisar', 'fn_cierre_cerrar', 'fn_cierre_export', 'fn_cierre_config', 'fn_cierre_hash_mayor', 'fn_cierre_balanza',
                       'fn_cierre_confirmacion', 'fn_cierre_pegado', 'fn_cierre_precondiciones', 'fn_ronda', 'fn_activo_alta', 'fn_activo_baja',
                       'fn_depreciacion_mes', 'fn_depreciacion_plan', 'fn_reserva_estimado_marcar', 'fn_reserva_estimado_anular');
    -- cada tabla, vista y función de c9 con su comentario «c9: …»
    select count(*) into v_sin
      from (select c.oid, obj_description(c.oid, 'pg_class') as d from pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
               and (c.relname in ('cierre_config', 'cierres', 'cierre_revisiones', 'ronda_resultados', 'activos_fijos', 'activos_depreciaciones',
                                  'reserva_estimados', 'v_cierre_estado', 'v_cierres', 'v_ronda_ultima', 'v_activos_fijos', 'v_reserva_impuestos', 'v_dr15_mes'))
            union all
            select p.oid, obj_description(p.oid, 'pg_proc') from pg_proc p
             where p.pronamespace = 'public'::regnamespace
               and (p.proname like 'fn\_cierre\_%' or p.proname like 'fn\_ronda%' or p.proname like 'fn\_activo\_%'
                    or p.proname like 'fn\_depreciacion\_%' or p.proname like 'fn\_reserva\_%')) x
     where coalesce(x.d, '') not like 'c9: %';
    select format('ronda %s · pct %s · metodo %s · push %s', ronda_activa, coalesce(reserva_pct::text, 'sin fijar'), metodo_depreciacion, aviso_push)
      into v_cfg from cierre_config where id = 1;
    if pg_temp.c9('hay_storage') = 'true' then
      execute $q$ select format('bucket %s · policies %s', (select count(*) from storage.buckets b where b.id = 'cierres' and not b.public),
                                (select count(*) from pg_policies pl where pl.schemaname = 'storage' and pl.tablename = 'objects' and pl.policyname like 'cierres: %')) $q$
        into v_bk;
    else
      v_bk := 'sin storage';
    end if;
    if pg_temp.c9('hay_cron') = 'true' then
      execute $q$ select coalesce((select 'cron ' || j.schedule from cron.job j where j.jobname = 'mxp-ronda-contable'), 'cron sin tarea') $q$ into v_cron;
    else
      v_cron := 'sin cron';
    end if;
    v_obt := format('%s · tablas %s · vistas %s · funciones %s · sin comentario %s · %s · %s · %s', v_pre, v_tab, v_vis, v_fn, v_sin, v_cfg, v_bk, v_cron);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: precondiciones, 7 tablas, 6 vistas, 16 funciones, todo con comentario c9, la configuración, el bucket (si hay Storage) y pg_cron (si hay cron)',
    'nada falta · tablas 7 · vistas 6 · funciones 16 · sin comentario 0 · ronda true · pct … · metodo linea_recta|manual · push … · bucket 1 · policies 4 (o sin storage) · cron 45 11 * * * (o sin cron)',
    v_obt,
    v_obt ~ '^nada falta · tablas 7 · vistas 6 · funciones 16 · sin comentario 0 · ronda (t|f) · pct [^·]+ · metodo (linea_recta|manual) · push (t|f) · (bucket 1 · policies 4|sin storage) · (cron 45 11 \* \* \*|sin cron)$');
end $$;

-- 2. Las precondiciones en rojo: desde la app, y sin una función de la que
--    c9 depende (se quita dentro de la prueba y se deshace).
do $$
declare
  v_obt text; v_a text; v_b text;
begin
  begin
    -- (desde la app no se instala nada: la función no está en la API)
    perform pg_temp.c9_ser('dueno');
    begin
      v_a := fn_cierre_precondiciones();
    exception when others then v_a := sqlstate;
    end;
    perform pg_temp.c9_ser('editor');
    drop function public.fn_banco_control(text, text[]);
    v_b := fn_cierre_precondiciones();
    v_obt := format('desde la app: %s | sin fn_banco_control: %s', coalesce(v_a, 'nada'),
                    case when v_b like '%fn_banco_control(text,text[])%' then 'la nombra' else coalesce(v_b, 'nada') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones: desde la app no se llaman (42501: desde la app no se instala nada); sin fn_banco_control la nombran',
    'desde la app: 42501 | sin fn_banco_control: la nombra', v_obt, v_obt = 'desde la app: 42501 | sin fn_banco_control: la nombra');
end $$;

-- 3. La API: anon y service_role no ejecutan nada; el equipo recibe 42501;
--    el dueño entra; las vistas por rol; la ronda y sus auxiliares sin API.
do $$
declare
  v_obt text;
  v_api text; v_sin text; v_anon text; v_eq text; v_due int; v_veq int; v_vdue int; v_srv text;
begin
  begin
    perform pg_temp.c9_ser('editor');
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_cierre_revisar', 'fn_cierre_cerrar', 'fn_cierre_export', 'fn_cierre_config', 'fn_activo_alta', 'fn_activo_baja',
                         'fn_depreciacion_mes', 'fn_reserva_estimado_marcar', 'fn_reserva_estimado_anular', 'fn_cierre_hash_mayor',
                         'fn_cierre_balanza', 'fn_cierre_confirmacion')
       and not (has_function_privilege('authenticated', p.oid, 'execute')
                and not has_function_privilege('anon', p.oid, 'execute')
                and not has_function_privilege('service_role', p.oid, 'execute'));
    -- las de la ronda y las internas: nadie de la API
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_ronda', 'fn_ronda_globales', 'fn_cierre_sin_api', 'fn_cierre_dueno', 'fn_cierre_precondiciones', 'fn_cierre_pegado', 'fn_cierre_guarda')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    -- anon: ni siquiera ejecuta
    perform pg_temp.c9_ser('anon');
    begin
      perform count(*) from fn_cierre_revisar(pg_temp.c9('mes'));
      v_anon := 'entró';
    exception when others then v_anon := sqlstate;
    end;
    perform pg_temp.c9_ser('service_role');
    begin
      perform fn_cierre_config('{"aviso_push": true}');
      v_srv := 'entró';
    exception when others then v_srv := sqlstate;
    end;
    -- el equipo: 42501 por dentro
    perform pg_temp.c9_ser('equipo');
    begin
      perform count(*) from fn_cierre_revisar(pg_temp.c9('mes'));
      v_eq := 'entró';
    exception when others then v_eq := sqlstate;
    end;
    select count(*) into v_veq from v_cierre_estado;
    -- el dueño: entra y ve
    perform pg_temp.c9_ser('dueno');
    select count(*) into v_due from fn_cierre_revisar(pg_temp.c9('mes'));
    select count(*) into v_vdue from v_cierre_estado;
    perform pg_temp.c9_ser('editor');
    v_obt := format('pantalla mal: %s | sin api mal: %s | anon %s | service_role %s | equipo %s, ve %s filas | dueño %s filas, ve %s de %s',
                    v_api, v_sin, v_anon, v_srv, v_eq, v_veq, case when v_due >= 10 then 'revisa' else v_due::text end, v_vdue,
                    (select count(*) from periodos where tipo in ('mes', 'apertura')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las de la pantalla solo authenticated; la ronda y las internas sin API; anon y service_role 42501; el equipo 42501 y no ve; el dueño revisa y ve todos los períodos',
    format('pantalla mal: ninguna | sin api mal: ninguna | anon 42501 | service_role 42501 | equipo 42501, ve 0 filas | dueño revisa filas, ve %s de %s',
           (select count(*) from periodos where tipo in ('mes', 'apertura')), (select count(*) from periodos where tipo in ('mes', 'apertura'))),
    v_obt,
    v_obt = format('pantalla mal: ninguna | sin api mal: ninguna | anon 42501 | service_role 42501 | equipo 42501, ve 0 filas | dueño revisa filas, ve %s de %s',
                   (select count(*) from periodos where tipo in ('mes', 'apertura')), (select count(*) from periodos where tipo in ('mes', 'apertura'))));
end $$;

-- 4. El catálogo: nada SECURITY DEFINER, ningún prefijo sellado, RLS y
--    policy en cada tabla, vistas security_invoker; y «permisos» (c2),
--    «protecciones del banco» (c6) y «protecciones de c4» en verde con c9.
do $$
declare
  v_obt text; v_def text; v_pref text; v_rls text; v_vis text; v_c2 text; v_c6 text; v_c4 text;
begin
  begin
    perform pg_temp.c9_ser('editor');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef
       and (p.proname like 'fn\_cierre\_%' or p.proname like 'fn\_ronda%' or p.proname like 'fn\_activo\_%'
            or p.proname like 'fn\_depreciacion\_%' or p.proname like 'fn\_reserva\_%');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_pref
      from pg_proc p where p.pronamespace = 'public'::regnamespace
       and (p.proname ~ '^fn_(banco|puente|estados|stripe|plaid|contador)_')
       and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c9: %';
    select coalesce(string_agg(t.tablename, ', '), 'ninguna') into v_rls
      from pg_tables t
     where t.schemaname = 'public'
       and t.tablename in ('cierre_config', 'cierres', 'cierre_revisiones', 'ronda_resultados', 'activos_fijos', 'activos_depreciaciones', 'reserva_estimados')
       and (not t.rowsecurity
            or not exists (select 1 from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t.tablename and pl.cmd = 'SELECT'));
    select coalesce(string_agg(c.relname, ', '), 'ninguna') into v_vis
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
       and c.relname in ('v_cierre_estado', 'v_cierres', 'v_ronda_ultima', 'v_activos_fijos', 'v_reserva_impuestos', 'v_dr15_mes')
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    select case when ok then 'verde' else 'rojo: ' || left(detalle::text, 300) end into v_c2 from fn_verificar_cadena() where control = 'permisos';
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c6
      from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) where vista = 'cuadre: protecciones del banco';
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c4
      from fn_estados_control('hoy', array['v_saldos_dinero']) where vista = 'cuadre: protecciones de c4';
    v_obt := format('definer: %s | prefijos sellados: %s | sin rls o policy: %s | sin security_invoker: %s | c2 permisos %s | c6 protecciones %s | c4 protecciones %s',
                    v_def, v_pref, v_rls, v_vis, v_c2, v_c6, v_c4);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: nada SECURITY DEFINER, ningún prefijo sellado, RLS y policy en cada tabla, vistas security_invoker; c2 «permisos», c6 y c4 «protecciones» en verde con c9 pegado',
    'definer: ninguna | prefijos sellados: ninguna | sin rls o policy: ninguna | sin security_invoker: ninguna | c2 permisos verde | c6 protecciones verde | c4 protecciones verde',
    v_obt,
    v_obt = 'definer: ninguna | prefijos sellados: ninguna | sin rls o policy: ninguna | sin security_invoker: ninguna | c2 permisos verde | c6 protecciones verde | c4 protecciones verde');
end $$;

-- 5. v_cierre_estado: una fila por apertura y mes, un solo «siguiente» (el
--    abierto más viejo), terminado por el reloj de Miami, la confirmación
--    exacta, y detienen/avisos de la última revisión (tras correrla).
do $$
declare
  v_obt text; v_n int; v_sig text; v_sig2 text; v_term text; v_conf text; v_det int; v_rojo int; v_rev timestamptz;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    select count(*) into v_n from v_cierre_estado;
    select string_agg(periodo, ',') into v_sig from v_cierre_estado where siguiente;
    v_sig2 := fn_cierre_siguiente();
    select coalesce(string_agg(periodo, ','), 'ninguno') into v_term from v_cierre_estado where terminado <> (hasta < fn_fecha_miami(now()));
    select confirmacion into v_conf from v_cierre_estado where periodo = pg_temp.c9('mes');
    perform count(*) from fn_cierre_revisar(v_sig2);
    select detienen, revisado_el into v_det, v_rev from v_cierre_estado where periodo = v_sig2;
    select count(*) into v_rojo from fn_cierre_revisar(v_sig2) where nivel = 'detiene' and ok is distinct from true;
    perform pg_temp.c9_ser('editor');
    v_obt := format('filas %s de %s | siguiente %s = %s | terminado mal: %s | confirmación %s | detienen %s = rojos %s | revisado hoy %s',
                    v_n, (select count(*) from periodos where tipo in ('mes', 'apertura')), v_sig, v_sig2, v_term,
                    case when v_conf = 'CERRAR ' || fn_cierre_mes_nombre((select desde from periodos where periodo = pg_temp.c9('mes'))) || ' '
                                        || (select anio from periodos where periodo = pg_temp.c9('mes')) then 'exacta' else v_conf end,
                    v_det, v_rojo, v_rev >= now() - interval '1 minute');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'v_cierre_estado: una fila por apertura y mes, un solo siguiente, terminado por Miami, la confirmación exacta, detienen de la última revisión con su hora',
    format('filas %s de %s | siguiente %s = %s | terminado mal: ninguno | confirmación exacta | detienen N = rojos N | revisado hoy true',
           (select count(*) from periodos where tipo in ('mes', 'apertura')), (select count(*) from periodos where tipo in ('mes', 'apertura')),
           fn_cierre_siguiente(), fn_cierre_siguiente()),
    v_obt,
    v_obt ~ format('^filas %s de %s \| siguiente %s = %s \| terminado mal: ninguno \| confirmación exacta \| detienen ([0-9]+) = rojos \1 \| revisado hoy t',
                   (select count(*) from periodos where tipo in ('mes', 'apertura')), (select count(*) from periodos where tipo in ('mes', 'apertura')),
                   fn_cierre_siguiente(), fn_cierre_siguiente()));
end $$;

-- 6. El orden y el calendario: con la apertura abierta, el mes dice que
--    primero la apertura (detiene, ir_a cierre); con la apertura cerrada
--    (de prueba), en verde; un mes que no terminó, el calendario lo frena.
--    Si la apertura real no se puede poner en verde aparcando (un 1590 que
--    no cuadra con los activos, por ejemplo), la mitad del orden no se puede
--    probar: omitida con lo que quedó, como la 23 (no es un fallo de c9).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_q text;
begin
  if pg_temp.c9('mes') is null or pg_temp.c9('mes_futuro') is null then
    insert into _pruebas values (6, 'el orden (la apertura primero) y el calendario (un mes que no terminó no se cierra)', 'omitida', 'omitida: falta un mes terminado abierto o uno futuro', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    lock table public.periodos in exclusive mode;
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 10);
    v_c := pg_temp.c9_fila(pg_temp.c9('mes_futuro'), 15);
    if (select estado from periodos where periodo = pg_temp.c9('apertura')) = 'abierto' then
      perform pg_temp.c9_apertura();
      v_q := pg_temp.c9_aparcar(pg_temp.c9('apertura'));
      if v_q is not null then
        v_obt := format('omitida: la apertura no se pudo poner en verde para cerrarla (sigue en rojo: %s%s); con la apertura abierta el mes dice: %s',
                        v_q, coalesce(' · lo que dijo la capa: ' || pg_temp.c9_aparcado(pg_temp.c9('apertura')), ''),
                        case when v_a like 'rojo|detiene|cierre|Antes de cerrar % hay que cerrar la apertura%' then 'rojo, detiene, cierre, la nombra' else v_a end);
        raise exception using errcode = 'MXT00';
      end if;
      perform fn_cierre_cerrar(pg_temp.c9('apertura'), 'CERRAR LA APERTURA');
      v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 10);
      v_obt := format('con la apertura abierta: %s | cerrada: %s | mes futuro: %s',
                      case when v_a like 'rojo|detiene|cierre|Antes de cerrar % hay que cerrar la apertura%' then 'rojo, detiene, cierre, la nombra' else v_a end,
                      case when v_b like 'verde|detiene|cierre|Todo lo anterior%' then 'verde' else v_b end,
                      case when v_c like 'rojo|detiene|cierre|%termina el %: se cierra a partir del %' then 'rojo, detiene, lo dice' else v_c end);
    else
      v_obt := format('con la apertura abierta: %s | cerrada: %s | mes futuro: %s',
                      'rojo, detiene, cierre, la nombra',
                      case when v_a like 'verde|detiene|cierre|Todo lo anterior%' then 'verde' else v_a end,
                      case when v_c like 'rojo|detiene|cierre|%termina el %: se cierra a partir del %' then 'rojo, detiene, lo dice' else v_c end)
               || ' (la apertura ya estaba cerrada: la mitad del orden no se prueba)';
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'el orden: con la apertura abierta el mes dice «primero la apertura» (detiene, ir_a cierre); cerrada, verde; y el calendario frena un mes que no terminó',
    'con la apertura abierta: rojo, detiene, cierre, la nombra | cerrada: verde | mes futuro: rojo, detiene, lo dice (u omitida si la apertura real no se puede poner en verde)', v_obt,
    case when v_obt like 'omitida:%' then null
         else v_obt like 'con la apertura abierta: rojo, detiene, cierre, la nombra | cerrada: verde | mes futuro: rojo, detiene, lo dice%' end);
end $$;

-- 7. La apertura sin su asiento vivo (rojo, detiene, ir_a estados) y con él;
--    y su conciliación de apertura (50: aviso, ir_a conciliar), que no frena.
do $$
declare
  v_obt text; v_a text; v_b text; v_num text; v_c text;
begin
  if (select estado from periodos where periodo = pg_temp.c9('apertura')) = 'cerrado' then
    insert into _pruebas values (7, 'la apertura: sin su asiento vivo, rojo; con él, verde y lo nombra', 'omitida', 'omitida: la apertura ya está cerrada', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    v_a := pg_temp.c9_fila(pg_temp.c9('apertura'), 20);
    v_num := pg_temp.c9_apertura();
    v_b := pg_temp.c9_fila(pg_temp.c9('apertura'), 20);
    v_c := pg_temp.c9_fila(pg_temp.c9('apertura'), 50);
    v_obt := format('antes: %s | con asiento: %s | conciliación de apertura: %s',
                    case when v_num = 'ya había' then 'ya había asiento: ' || split_part(v_a, '|', 1)
                         when v_a like 'rojo|detiene|estados|Falta el asiento de apertura%' then 'rojo, detiene, estados' else v_a end,
                    case when v_b like 'verde|detiene|estados|El asiento de apertura % está vivo%' then 'verde y lo nombra' else v_b end,
                    case when v_c like 'verde|aviso|conciliar|Ninguna cuenta del banco tiene saldo en el asiento de apertura%'
                           or v_c like 'verde|aviso|conciliar|Las % cuenta(s) del banco con saldo en la apertura tienen su conciliación de apertura confirmada.'
                           or v_c ~ '^rojo\|aviso\|conciliar\|[0-9]+ de [0-9]+ cuenta\(s\) del banco sin conciliación de apertura confirmada: .+No frena la apertura'
                         then 'aviso, conciliar' else coalesce(v_c, 'no está') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'la apertura: sin su asiento vivo, rojo (detiene, ir_a estados); con él, verde y lo nombra; su conciliación de apertura avisa (50, ir_a conciliar) y no frena',
    'antes: rojo, detiene, estados (o ya había asiento: verde) | con asiento: verde y lo nombra | conciliación de apertura: aviso, conciliar', v_obt,
    v_obt in ('antes: rojo, detiene, estados | con asiento: verde y lo nombra | conciliación de apertura: aviso, conciliar',
              'antes: ya había asiento: verde | con asiento: verde y lo nombra | conciliación de apertura: aviso, conciliar'));
end $$;

-- 8. El cuadre del período: lo que dice fn_estado, en llano.
do $$
declare
  v_obt text; v_f text; e record;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    v_f := pg_temp.c9_fila(pg_temp.c9('mes'), 30);
    select * into e from fn_estado(pg_temp.c9('mes'));
    perform pg_temp.c9_ser('editor');
    v_obt := case when e.asientos = 0 and v_f like 'verde|detiene|conexiones|Sin asientos en %' then 'verde, sin asientos'
                  when e.asientos > 0 and v_f like format('verde|detiene|conexiones|%s asientos y %s líneas en %%: debe %s = haber %s.', e.asientos, e.filas,
                                                           fn_cierre_usd(e.total_debe), fn_cierre_usd(e.total_haber)) then 'verde, con sus cifras'
                  else v_f end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'el cuadre del período: asientos, líneas, debe = haber (fn_estado), en verde y en llano',
    'verde, con sus cifras (o verde, sin asientos)', v_obt, v_obt in ('verde, con sus cifras', 'verde, sin asientos'));
end $$;

-- 9. El banco: un cargo sembrado sin clasificar pone el 40 en rojo con
--    cuántos y cuánto (ir_a bandeja); ignorado con su motivo, vuelve a lo
--    de antes.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_mov uuid; v_antes int; v_fecha date;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (9, 'el banco: un cargo sin clasificar pone el 40 en rojo con cuántos y cuánto; ignorado, vuelve', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 40);
    v_antes := coalesce(case when v_a like 'verde%' then 0 else pg_temp.c9_num(split_part(v_a, '|', 4)) end, 0);
    v_mov := pg_temp.c9_cargo('c9-t9', v_fecha, 123.45, 'C9 PRUEBA FERRETERIA 77 OCALA FL');
    v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 40);
    perform fn_banco_ignorar(v_mov, 'c9-pruebas: no era de la empresa (se deshace)');
    v_c := pg_temp.c9_fila(pg_temp.c9('mes'), 40);
    v_obt := format('antes %s | con el cargo: %s, cuenta %s, dice el monto %s | ignorado: %s',
                    v_antes, split_part(v_b, '|', 1) || ', ' || split_part(v_b, '|', 2) || ', ' || split_part(v_b, '|', 3),
                    pg_temp.c9_num(split_part(v_b, '|', 4)), split_part(v_b, '|', 4) like '%$123.45%' or (v_antes > 0 and split_part(v_b, '|', 4) like '%cargos por $%'),
                    case when v_antes = 0 then split_part(v_c, '|', 1) else pg_temp.c9_num(split_part(v_c, '|', 4))::text end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'el banco: un cargo sembrado sin clasificar pone el 40 en rojo (detiene, ir_a bandeja) con cuántos y cuánto; ignorado con su motivo, vuelve a lo de antes',
    'antes N | con el cargo: rojo, detiene, bandeja, cuenta N+1, dice el monto true | ignorado: verde (o N)', v_obt,
    v_obt ~ '^antes ([0-9]+) \| con el cargo: rojo, detiene, bandeja, cuenta ([0-9]+), dice el monto t(rue)? \| ignorado: (verde|[0-9]+)$'
    and pg_temp.c9_num(substring(v_obt from 'cuenta ([0-9]+)')) = pg_temp.c9_num(v_obt) + 1
    and (substring(v_obt from 'ignorado: (.+)$') = 'verde' or substring(v_obt from 'ignorado: (.+)$') = pg_temp.c9_num(v_obt)::text));
end $$;

-- 10. Las propuestas de la IA del mes sin decidir (aviso, ir_a bandeja): una
--     propuesta pendiente sobre un cargo sembrado la pone en rojo.
do $$
declare
  v_obt text; v_a text; v_b text; v_mov uuid; v_antes int; v_fecha date;
begin
  if pg_temp.c9('hay_c8') <> 'true' or pg_temp.c9('mes') is null then
    insert into _pruebas values (10, 'las propuestas de la IA del mes sin decidir (aviso)', 'omitida', 'omitida: sin c8 (o sin mes terminado) en esta base', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 42);
    v_antes := coalesce(case when v_a like 'verde%' then 0 else pg_temp.c9_num(split_part(v_a, '|', 4)) end, 0);
    v_mov := pg_temp.c9_cargo('c9-t10', v_fecha, 61.20, 'C9 PRUEBA WAWA 5234 BELLEVIEW FL');
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta, estado)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "6300"}], "motivo": "c9-pruebas (se deshace)", "confianza": 1}', 'pendiente') $q$ using v_mov;
    v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 42);
    v_obt := format('antes %s | con la propuesta: %s, %s, %s, cuenta %s', v_antes, split_part(v_b, '|', 1), split_part(v_b, '|', 2), split_part(v_b, '|', 3),
                    pg_temp.c9_num(split_part(v_b, '|', 4)));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'las propuestas de la IA del mes sin decidir: una pendiente sobre un cargo del mes pone el 42 en rojo (aviso, ir_a bandeja) y la cuenta',
    'antes N | con la propuesta: rojo, aviso, bandeja, cuenta N+1', v_obt,
    v_obt ~ '^antes [0-9]+ \| con la propuesta: rojo, aviso, bandeja, cuenta [0-9]+$'
    and pg_temp.c9_num(substring(v_obt from 'cuenta ([0-9]+)')) = pg_temp.c9_num(v_obt) + 1);
end $$;

-- 11. La conciliación al último día del mes: sin ella, el 50 en rojo nombra
--     las cuentas (detiene, ir_a conciliar); con cada cuenta conciliada y
--     confirmada (aparcada), en verde. Si c6 no deja confirmar alguna (falta
--     la conciliación de apertura de la cuenta, un saldo que no cuadra…), el
--     banco real no se pudo poner en verde: la prueba sale «omitida» con lo
--     que c6 dijo, tal cual, como la 23, 24 y 27 (no es un fallo de c9: es el
--     estado de los libros, el mismo que Edgar ve en Conciliar).
do $$
declare
  v_obt text; v_a text; v_b text; v_q text; v_n int; v_antes text;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (11, 'la conciliación al último día del mes', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select count(distinct m.cuenta) into v_n from movimientos_banco m where m.fecha <= (select hasta from periodos where periodo = pg_temp.c9('mes'));
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 50);
    v_antes := case when v_n = 0 and v_a like 'verde|detiene|conciliar|Ninguna cuenta%' then 'verde, ninguna cuenta'
                    when v_a like 'rojo|detiene|conciliar|% sin conciliar al %: %' then 'rojo, detiene, conciliar, las nombra'
                    when v_a like 'verde|detiene|conciliar|Las % cuenta(s) con estado de cuenta tienen su conciliación confirmada%' then 'ya conciliadas'
                    else v_a end;
    v_q := pg_temp.c9_aparcar(pg_temp.c9('mes'));
    v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 50);
    if v_b like 'verde|detiene|conciliar|%' then
      v_obt := format('cuentas con banco %s | antes: %s | aparcado: verde', v_n, v_antes);
    else
      v_obt := format('omitida: el banco no se pudo poner en verde (antes: %s). Queda en %s, %s: %s Lo que dijo la capa: %s',
                      v_antes, split_part(v_b, '|', 1), split_part(v_b, '|', 2), split_part(v_b, '|', 4),
                      coalesce(pg_temp.c9_aparcado(pg_temp.c9('mes')), 'nada (el aparcado no tropezó con ninguna excepción)'));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'la conciliación al último día del mes: sin ella el 50 nombra las cuentas (detiene, ir_a conciliar); con cada cuenta conciliada y confirmada, verde (si c6 no deja confirmar alguna, omitida con lo que c6 dijo)',
    'cuentas con banco N | antes: rojo, detiene, conciliar, las nombra (o ya conciliadas; o verde, ninguna cuenta) | aparcado: verde (u «omitida: el banco no se pudo poner en verde (…)» con lo que dijo c6)', v_obt,
    case when v_obt like 'omitida:%' then null
         else v_obt ~ '^cuentas con banco [0-9]+ \| antes: (rojo, detiene, conciliar, las nombra|ya conciliadas|verde, ninguna cuenta) \| aparcado: verde$' end);
end $$;

-- 12. 2010 por proveedor (aviso, ir_a estados): el detalle con el saldo y
--     los proveedores, y una línea sin proveedor ni partida lo pone en rojo.
do $$
declare
  v_obt text; v_a text; v_b text; v_cxp text; v_fecha date;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (12, '2010 por proveedor', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    v_cxp := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp'), '2010');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 60);
    perform fn_postear(jsonb_build_object('fecha', to_char(v_fecha, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: compra a crédito sin proveedor (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '77.00'), jsonb_build_object('cuenta', v_cxp, 'monto', '-77.00'))));
    v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 60);
    v_obt := format('antes: %s, %s, %s, habla de %s y de proveedores %s | con la línea sin proveedor: %s, la cuenta %s',
                    split_part(v_a, '|', 1), split_part(v_a, '|', 2), split_part(v_a, '|', 3), v_cxp,
                    split_part(v_a, '|', 4) like format('%s al %s: %%. Por proveedor: %%', v_cxp, v_fecha),
                    split_part(v_b, '|', 1), split_part(v_b, '|', 4) like '%sin proveedor ni partida por $%');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, '2010 por proveedor (aviso, ir_a estados): el saldo y los proveedores en el detalle; una línea de 2010 sin proveedor ni partida lo pone en rojo y la cuenta',
    'antes: verde|rojo, aviso, estados, habla de 2010 y de proveedores true | con la línea sin proveedor: rojo, la cuenta true', v_obt,
    v_obt ~ '^antes: (verde|rojo), aviso, estados, habla de [0-9A-Z-]+ y de proveedores t(rue)? \| con la línea sin proveedor: rojo, la cuenta t(rue)?$');
end $$;

-- 13. El auxiliar por obra = mayor (detiene, ir_a movimientos): en verde con
--     sus cifras (c2 no deja entrar la línea sin obra que lo pondría en rojo:
--     MX006).
do $$
declare
  v_obt text; v_a text; v_err text; v_fecha date; v_obra text;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (13, 'el auxiliar por obra = mayor', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    select id into v_obra from proyectos where estado in ('aprobado', 'ejecucion', 'pausa') order by id limit 1;
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 70);
    begin
      perform fn_postear(jsonb_build_object('fecha', to_char(v_fecha, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: material sin obra',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '10.00'), jsonb_build_object('cuenta', '2010', 'monto', '-10.00'))));
      v_err := 'entró';
    exception when others then v_err := sqlstate;
    end;
    v_obt := format('%s, %s, %s, con cifras %s | la línea sin obra: %s', split_part(v_a, '|', 1), split_part(v_a, '|', 2), split_part(v_a, '|', 3),
                    split_part(v_a, '|', 4) like 'Todas las líneas de cuentas que exigen obra llevan su obra en %: % obra(s), $% en líneas con obra.', v_err);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'el auxiliar por obra = mayor (detiene, ir_a movimientos): verde con sus cifras; la línea de costo sin obra no entra (c2, MX006)',
    'verde, detiene, movimientos, con cifras true | la línea sin obra: MX006', v_obt,
    v_obt ~ '^verde, detiene, movimientos, con cifras t(rue)? \| la línea sin obra: MX006$');
end $$;

-- 14. Los recibos del mes sin foto (80) y con impuesto desconocido (82):
--     avisos; un ticket anotado a mano sin foto ni impuesto, contabilizado
--     por su puente (c3), los pone en rojo y los cuenta.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text; v_fecha date; v_obra text; v_id bigint; v_est text; v_na int; v_nc int;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (14, 'los recibos del mes sin foto y con impuesto desconocido (avisos)', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    select id into v_obra from proyectos where estado in ('aprobado', 'ejecucion', 'pausa') order by id limit 1;
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 80);
    v_c := pg_temp.c9_fila(pg_temp.c9('mes'), 82);
    v_na := coalesce(case when v_a like 'verde%' then 0 else pg_temp.c9_num(split_part(v_a, '|', 4)) end, 0);
    v_nc := coalesce(case when v_c like 'verde%' then 0 else pg_temp.c9_num(split_part(v_c, '|', 4)) end, 0);
    -- (pagado por zelle: su regla trae la cuenta del banco de fábrica —la de
    -- «efectivo» no la trae hasta que Edgar diga de dónde sale—; las reglas
    -- de la categoría y de la forma de pago, confirmadas si siguen en
    -- borrador —en el banco lo están—, y los puentes corridos como
    -- «Reintentar puente»)
    begin
      perform fn_mapeo_confirmar('categoria', 'material');
    exception when others then null;
    end;
    begin
      perform fn_mapeo_confirmar('metodo_pago', 'zelle');
    exception when others then null;
    end;
    insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, fecha, categoria, metodo_pago, notas)
    values (v_obra, null, 88.00, 'C9 PRUEBA FERRETERIA', 'leido', pg_temp.c9('dueno')::uuid, v_fecha, 'material', 'zelle', 'C9 PRUEBA: anotado a mano (se deshace)')
    returning id into v_id;
    perform fn_puentes_correr();
    select pd.estado into v_est from puente_documentos pd where pd.tabla = 'recibos' and pd.documento_id = v_id::text;
    if v_est is distinct from 'contabilizado' then
      v_obt := format('omitida: el puente de c3 dejó el recibo de prueba en «%s», no contabilizado', coalesce(v_est, 'sin fila'));
    else
      v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 80);
      v_d := pg_temp.c9_fila(pg_temp.c9('mes'), 82);
      v_obt := format('sin foto: antes %s, con el ticket %s, %s, cuenta %s, lo nombra %s | impuesto: antes %s, con el ticket %s, %s, cuenta %s',
                      v_na, split_part(v_b, '|', 1), split_part(v_b, '|', 2), pg_temp.c9_num(split_part(v_b, '|', 4)), split_part(v_b, '|', 4) like '%' || v_id || '%',
                      v_nc, split_part(v_d, '|', 1), split_part(v_d, '|', 2), pg_temp.c9_num(split_part(v_d, '|', 4)));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'los recibos del mes: un ticket anotado a mano (sin foto, sin impuesto) que c3 contabiliza pone el 80 y el 82 en rojo (avisos) y los cuenta; el 80 lo nombra',
    'sin foto: antes N, con el ticket rojo, aviso, cuenta N+1, lo nombra true | impuesto: antes M, con el ticket rojo, aviso, cuenta M+1', v_obt,
    case when v_obt like 'omitida:%' then null
         else v_obt ~ '^sin foto: antes [0-9]+, con el ticket rojo, aviso, cuenta [0-9]+, lo nombra t(rue)? \| impuesto: antes [0-9]+, con el ticket rojo, aviso, cuenta [0-9]+$'
              and pg_temp.c9_num(substring(v_obt from 'sin foto: antes [0-9]+, con el ticket rojo, aviso, cuenta ([0-9]+)')) = pg_temp.c9_num(v_obt) + 1
              and pg_temp.c9_num(substring(v_obt from 'impuesto: antes [0-9]+, con el ticket rojo, aviso, cuenta ([0-9]+)')) = pg_temp.c9_num(substring(v_obt from 'impuesto: antes ([0-9]+)')) + 1 end);
end $$;

-- 15. 1590 = activos: sin activos, verde y lo dice (lo de QuickBooks se
--     comprueba en f12); con un activo cuya acumulada de arranque es lo que
--     1590 tiene, cuadra; con otro de más, rojo con la diferencia. Si ya hay
--     activos de verdad (la f12 cargó la cédula del CPA), su parte de 1590 ya
--     está explicada: el de prueba explica solo el resto (1590 menos lo que
--     la propia fila 90 dice que explican los reales, al último día del mes),
--     y si los reales explican MÁS de lo que 1590 tiene, antes entra a 1590
--     lo que falte. Así el cuadre es por la suma, no por casualidad, y la
--     prueba vale igual antes y después de la f12. El costo del activo de
--     prueba crece con su acumulada: fn_activo_alta exige inicial ≤ costo −
--     residual, y 1590 puede traer años de QuickBooks.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_fecha date; v_nreal int; v_esp0 numeric; v_s0 numeric; v_extra numeric; v_s numeric; v_ini numeric;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (15, '1590 = la depreciación acumulada de los activos', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_fecha from periodos where periodo = pg_temp.c9('mes');
    select count(*) into v_nreal from activos_fijos;
    select coalesce(-sum(l.monto), 0) into v_s0 from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '1590' and a.fecha_contable <= v_fecha;
    -- (el estado real: sin activos lo dice con el saldo; con activos, la misma
    -- fila dice cuánto explican al último día del mes: «… = $X según los N
    -- activo(s)» o «… y $X según los N activo(s)»)
    v_a := pg_temp.c9_fila(pg_temp.c9('mes'), 90);
    v_esp0 := case when v_nreal = 0 then 0
                   else pg_temp.c9_usd(substring(split_part(v_a, '|', 4) from ' (-?\$[0-9,]+\.[0-9][0-9]) según los [0-9]+ activo')) end;
    -- a 1590 entra de prueba lo que haga falta para que el activo de prueba
    -- explique 100 o más (si los reales explican más de lo que 1590 tiene,
    -- también esa diferencia)
    v_extra := greatest(v_esp0 - v_s0, 0) + 100.00;
    perform fn_postear(jsonb_build_object('fecha', to_char(v_fecha, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: depreciación a mano (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6950', 'monto', v_extra::text), jsonb_build_object('cuenta', '1590', 'monto', (-v_extra)::text))));
    select coalesce(-sum(l.monto), 0) into v_s from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '1590' and a.fecha_contable <= v_fecha;
    v_ini := v_s - v_esp0;  -- lo que explica el activo de prueba (100 si los reales ya cuadraban)
    perform pg_temp.c9_ser('dueno');
    perform fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA camioneta', 'placa_serie', 'C9-001', 'cuenta', '1510',
      'fecha_servicio', to_char(v_fecha - 400, 'YYYY-MM-DD'), 'costo', greatest(30000.00, v_ini + 2000.00)::text, 'residual', '1000.00', 'vida_meses', 84,
      'dep_acumulada_inicial', v_ini::text));
    perform pg_temp.c9_ser('editor');
    v_b := pg_temp.c9_fila(pg_temp.c9('mes'), 90);
    perform pg_temp.c9_ser('dueno');
    perform fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA taladro', 'cuenta', '1520', 'fecha_servicio', to_char(v_fecha - 100, 'YYYY-MM-DD'),
      'costo', '900.00', 'vida_meses', 36, 'dep_acumulada_inicial', '50.00'));
    perform pg_temp.c9_ser('editor');
    v_c := pg_temp.c9_fila(pg_temp.c9('mes'), 90);
    v_obt := format('sin activos: %s | cuadra: %s | de más: %s',
                    case when v_nreal > 0 then format('ya había %s activo(s) que explican %s (1590 %s)', v_nreal, fn_cierre_usd(v_esp0),
                                                      case when v_a like 'verde|%' then 'cuadraba' else 'no cuadraba' end)
                         when v_a like 'verde|detiene|cierre|No hay activos fijos dados de alta todavía%' || fn_cierre_usd(v_s0) || '%' then 'verde, lo dice con el saldo' else v_a end,
                    case when v_b like 'verde|detiene|cierre|1590 al %: ' || fn_cierre_usd(v_s) || ' en el libro = ' || fn_cierre_usd(v_s) || ' según los ' || (v_nreal + 1) || ' activo(s)%'
                         then 'verde, cifras iguales' else v_b end,
                    case when v_c like 'rojo|detiene|cierre|1590 al % no cuadra: %diferencia -$50.00%' then 'rojo, diferencia -$50.00' else v_c end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, '1590 = activos (detiene, ir_a cierre): sin activos verde y lo dice con el saldo (con activos reales, resta lo que ya explican); con un activo cuya acumulada de arranque es el resto de 1590, cuadra; con otro de más, rojo con la diferencia',
    'sin activos: verde, lo dice con el saldo (o ya había N activo(s) que explican $X (1590 cuadraba|no cuadraba)) | cuadra: verde, cifras iguales | de más: rojo, diferencia -$50.00', v_obt,
    v_obt ~ '^sin activos: (verde, lo dice con el saldo|ya había [0-9]+ activo\(s\) que explican -?\$[0-9,]+\.[0-9][0-9] \(1590 (cuadraba|no cuadraba)\)) \| cuadra: verde, cifras iguales \| de más: rojo, diferencia -\$50\.00$');
end $$;

-- 16. La depreciación del mes: el plan, el 92 en rojo, el asiento Dr 6950 /
--     Cr 1590 por fn_postear (una línea por activo), idempotente, el tope
--     del residual, v_activos_fijos, y reversado se vuelve a postear.
do $$
declare
  v_obt text; v_mes text := pg_temp.c9('mes'); v_desde date; v_hasta date; v_a text; v_b text; v_c text;
  v_r1 jsonb; v_r2 jsonb; v_r3 jsonb; v_lin text; v_plan text; v_act record; v_pre int;
begin
  if v_mes is null then
    insert into _pruebas values (16, 'la depreciación del mes', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select desde, hasta into v_desde, v_hasta from periodos where periodo = v_mes;
    select count(*) into v_pre from activos_fijos;
    perform pg_temp.c9_ser('dueno');
    -- 12.000 a 60 meses: 200 al mes; y uno al que le quedan 50 hasta el residual
    perform fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA camioneta', 'placa_serie', 'C9-001', 'cuenta', '1510',
      'fecha_servicio', to_char(v_desde, 'YYYY-MM-DD'), 'costo', '12000.00', 'residual', '0', 'vida_meses', 60));
    perform fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA compresor', 'cuenta', '1520', 'fecha_servicio', to_char(v_desde - 90, 'YYYY-MM-DD'),
      'costo', '1000.00', 'residual', '700.00', 'vida_meses', 2, 'dep_acumulada_inicial', '250.00'));
    -- y uno que entra en servicio después del mes: no deprecia este mes
    perform fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA laptop', 'cuenta', '1530', 'fecha_servicio', to_char(v_hasta + 1, 'YYYY-MM-DD'),
      'costo', '1500.00', 'vida_meses', 36));
    select string_agg(format('%s %s', regexp_replace(x.descripcion, '^C9 PRUEBA ', ''), x.monto), ', ' order by x.descripcion) into v_plan
      from fn_depreciacion_plan(v_mes) x;
    v_a := pg_temp.c9_fila(v_mes, 92);
    v_r1 := fn_depreciacion_mes(v_mes);
    v_r2 := fn_depreciacion_mes(v_mes);
    select string_agg(format('%s %s', l.cuenta, l.monto), ' | ' order by l.orden) into v_lin
      from asiento_lineas l where l.asiento_id = (v_r1->'asiento'->>'id')::uuid;
    v_b := pg_temp.c9_fila(v_mes, 92);
    select acumulada, valor_libros, meses_posteados, terminado into v_act from v_activos_fijos where descripcion = 'C9 PRUEBA camioneta';
    -- reversado, el mes vuelve a pedirla y se vuelve a postear
    perform fn_reversar((v_r1->'asiento'->>'id')::uuid, 'c9-pruebas: estaba mal (se deshace)');
    v_c := pg_temp.c9_fila(v_mes, 92);
    v_r3 := fn_depreciacion_mes(v_mes);
    perform pg_temp.c9_ser('editor');
    v_obt := format('plan: %s | antes: %s | asiento: %s · camino %s · descripción %s | otra vez: ya_estaba %s, mismo asiento %s | después: %s | camioneta acumulada %s, en libros %s, meses %s | reversado: %s | tercero asiento nuevo %s',
                    v_plan,
                    case when v_a like 'rojo|detiene|cierre|Falta la depreciación de %: $250.00 por 2 activo(s)%' then 'rojo, $250.00 por 2' else v_a end,
                    v_lin,
                    (select a.camino from asientos a where a.id = (v_r1->'asiento'->>'id')::uuid),
                    (select a.descripcion like 'Depreciación de % (c9: fn_depreciacion_mes, 2 activo(s))' from asientos a where a.id = (v_r1->'asiento'->>'id')::uuid),
                    v_r2->>'ya_estaba', v_r2->'asiento'->>'numero' = v_r1->'asiento'->>'numero',
                    case when v_b like 'verde|detiene|cierre|La depreciación de % está posteada: $250.00 por 2 activo(s)%' then 'verde, posteada' else v_b end,
                    v_act.acumulada, v_act.valor_libros, v_act.meses_posteados,
                    case when v_c like 'rojo|detiene|cierre|Falta la depreciación%' then 'rojo otra vez' else v_c end,
                    (v_r3->>'ya_estaba') = 'false' and v_r3->'asiento'->>'numero' <> v_r1->'asiento'->>'numero');
    if v_pre > 0 then v_obt := v_obt || ' (ya había activos de verdad: el plan y los montos pueden traer los suyos)'; end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'la depreciación del mes: el plan (200 + 50 hasta el residual; el que entra después no), el 92 en rojo, el asiento Dr 6950 por activo / Cr 1590 por fn_postear (camino mano), idempotente, v_activos_fijos, reversado se vuelve a pedir y postear',
    'plan: camioneta 200.00, compresor 50.00, laptop … | antes: rojo, $250.00 por 2 | asiento: 6950 200.00 | 6950 50.00 | 1590 -250.00 · camino mano · descripción true | otra vez: ya_estaba true, mismo asiento true | después: verde, posteada | camioneta acumulada 200.00, en libros 11800.00, meses 1 | reversado: rojo otra vez | tercero asiento nuevo true',
    v_obt,
    v_obt like 'plan: camioneta 200.00, compresor 50.00% | antes: rojo, $250.00 por 2 | asiento: 6950 200.00 | 6950 50.00 | 1590 -250.00 · camino mano · descripción t% | otra vez: ya_estaba true, mismo asiento t% | después: verde, posteada | camioneta acumulada 200.00, en libros 11800.00, meses 1 | reversado: rojo otra vez | tercero asiento nuevo t%'
    and (select count(*) from activos_fijos) = 0 or v_obt like '% | tercero asiento nuevo t% (ya había activos de verdad%');
end $$;

-- 17. La baja de un activo: deja de depreciar desde ese mes (y sigue si la
--     baja es después), MX008 dos veces, sus frenos, y 1590 lo sigue
--     contando hasta que tenga su asiento.
do $$
declare
  v_obt text; v_mes text := pg_temp.c9('mes'); v_desde date; v_hasta date; v_id uuid; v_id2 uuid; v_r jsonb;
  v_e1 text; v_e2 text; v_e3 text; v_n1 int; v_n2 int;
begin
  if v_mes is null then
    insert into _pruebas values (17, 'la baja de un activo', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select desde, hasta into v_desde, v_hasta from periodos where periodo = v_mes;
    perform pg_temp.c9_ser('dueno');
    v_id := (fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA generador', 'cuenta', '1520', 'fecha_servicio', to_char(v_desde - 400, 'YYYY-MM-DD'),
      'costo', '6000.00', 'vida_meses', 60, 'dep_acumulada_inicial', '1300.00'))->>'id')::uuid;
    v_id2 := (fn_activo_alta(jsonb_build_object('descripcion', 'C9 PRUEBA escalera', 'cuenta', '1520', 'fecha_servicio', to_char(v_desde - 400, 'YYYY-MM-DD'),
      'costo', '600.00', 'vida_meses', 60, 'dep_acumulada_inicial', '130.00'))->>'id')::uuid;
    select count(*) into v_n1 from fn_depreciacion_plan(v_mes) x where x.activo_id in (v_id, v_id2) and x.monto > 0;
    -- el generador se vende el 5 del mes: no deprecia el mes; la escalera se da de baja después del mes: sí
    begin
      perform fn_activo_baja(v_id2, v_desde - 500, 'antes de servicio');
      v_e2 := 'entró';
    exception when others then v_e2 := sqlstate;
    end;
    v_r := fn_activo_baja(v_id, v_desde + 4, 'vendido');
    perform fn_activo_baja(v_id2, v_hasta + 3, 'robada');
    select count(*) into v_n2 from fn_depreciacion_plan(v_mes) x where x.activo_id in (v_id, v_id2) and x.monto > 0;
    begin
      perform fn_activo_baja(v_id, v_desde + 4, 'otra vez');
      v_e1 := 'entró';
    exception when others then v_e1 := sqlstate;
    end;
    begin
      perform fn_activo_baja(gen_random_uuid(), v_desde, 'no existe');
      v_e3 := 'entró';
    exception when others then v_e3 := sqlstate;
    end;
    perform pg_temp.c9_ser('editor');
    v_obt := format('deprecian antes %s, después %s | baja: estado %s, nota 1590 sigue %s | dos veces %s | antes de servicio %s | no existe %s | 1590 esperado cuenta al vendido sin asiento %s',
                    v_n1, v_n2, v_r->>'estado', (v_r->>'nota') like 'Hasta que apuntes el asiento de la baja%', v_e1, v_e2, v_e3,
                    (select count(*) from v_activos_fijos v where v.id = v_id and v.estado = 'baja' and v.baja_asiento_id is null and v.acumulada = 1300.00));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'la baja: vendido en el mes no deprecia el mes (la baja posterior sí), estado baja con la nota de 1590, MX008 dos veces, 22023 antes de servicio o si no existe',
    'deprecian antes 2, después 1 | baja: estado baja, nota 1590 sigue true | dos veces MX008 | antes de servicio 22023 | no existe 22023 | 1590 esperado cuenta al vendido sin asiento 1',
    v_obt, v_obt ~ '^deprecian antes 2, después 1 \| baja: estado baja, nota 1590 sigue t(rue)? \| dos veces MX008 \| antes de servicio 22023 \| no existe 22023 \| 1590 esperado cuenta al vendido sin asiento 1$');
end $$;


-- 18. El alta y sus frenos: clave desconocida 22023, la cuenta no es 15xx
--     MX004, residual ≥ costo MX005, manual sin monto MX005, fecha mal
--     22023; y el método de las altas nuevas sale de la configuración.
do $$
declare
  v_obt text; e1 text; e2 text; e3 text; e4 text; e5 text; v_m1 text; v_m2 text;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    begin perform fn_activo_alta('{"descripcion":"x","cuenta":"1510","fecha_servicio":"2026-10-01","costo":"10","vida_meses":12,"color":"rojo"}'); e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin perform fn_activo_alta('{"descripcion":"x","cuenta":"6100","fecha_servicio":"2026-10-01","costo":"10","vida_meses":12}'); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    begin perform fn_activo_alta('{"descripcion":"x","cuenta":"1510","fecha_servicio":"2026-10-01","costo":"10","residual":"10","vida_meses":12}'); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    begin perform fn_activo_alta('{"descripcion":"x","cuenta":"1510","fecha_servicio":"2026-10-01","costo":"10","metodo":"manual"}'); e4 := 'entró'; exception when others then e4 := sqlstate; end;
    begin perform fn_activo_alta('{"descripcion":"x","cuenta":"1510","fecha_servicio":"1/10/2026","costo":"10","vida_meses":12}'); e5 := 'entró'; exception when others then e5 := sqlstate; end;
    v_m1 := fn_activo_alta('{"descripcion":"C9 PRUEBA a","cuenta":"1510","fecha_servicio":"2026-10-01","costo":"10","vida_meses":12}')->>'metodo';
    perform fn_cierre_config('{"metodo_depreciacion": "manual"}');
    v_m2 := fn_activo_alta('{"descripcion":"C9 PRUEBA b","cuenta":"1510","fecha_servicio":"2026-10-01","costo":"10","monto_mensual":"1"}')->>'metodo';
    perform pg_temp.c9_ser('editor');
    v_obt := format('clave %s | cuenta %s | residual %s | manual sin monto %s | fecha %s | métodos %s, %s', e1, e2, e3, e4, e5, v_m1, v_m2);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'el alta y sus frenos (22023, MX004, MX005) y el método de la configuración', 'clave 22023 | cuenta MX004 | residual MX005 | manual sin monto MX005 | fecha 22023 | métodos linea_recta, manual',
    v_obt, v_obt = 'clave 22023 | cuenta MX004 | residual MX005 | manual sin monto MX005 | fecha 22023 | métodos linea_recta, manual'
    or (v_obt like 'clave 22023 | cuenta MX004 | residual MX005 | manual sin monto MX005 | fecha 22023 | métodos manual, manual' and (select metodo_depreciacion from cierre_config) = 'manual'));
end $$;

-- 19. La cadena del libro: una función ajena SECURITY DEFINER que lee el
--     libro y la API ejecuta pone «libro: permisos» en rojo (detiene, ir_a
--     conexiones, con el revoke en qué hacer); quitada, el resumen en verde.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_q text;
begin
  begin
    perform pg_temp.c9_ser('editor');
    -- (lo que ya esté en rojo en permisos se aparca: la prueba mide lo suyo)
    v_q := pg_temp.c9_aparcar(pg_temp.c9('apertura'));
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    select format('%s|%s|%s|%s', case when ok then 'verde' else 'rojo' end, nivel, ir_a, que_hacer) into v_a
      from fn_cierre_revisar(pg_temp.c9('mes')) where control = 'libro: permisos';
    select detalle into v_c from fn_cierre_revisar(pg_temp.c9('mes')) where control = 'libro: permisos';
    drop function public.c9_prueba_lee_libro();
    select format('%s|%s', case when ok then 'verde' else 'rojo' end, control) into v_b
      from fn_cierre_revisar(pg_temp.c9('mes')) where control like 'libro: %' order by orden limit 1;
    v_obt := format('con la ajena: %s, nombra la función %s | sin ella: %s',
                    case when v_a like 'rojo|detiene|conexiones|%revoke execute on function%' then 'rojo, detiene, conexiones, dice el revoke' else v_a end,
                    v_c like '%c9_prueba_lee_libro%',
                    case when v_b = 'verde|libro: cadena, numeración, guardas y permisos' then 'verde, el resumen' else v_b end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'la cadena del libro: una función ajena SECURITY DEFINER que lee el libro y la API ejecuta pone «libro: permisos» en rojo (detiene, conexiones, con el revoke); quitada, el resumen en verde',
    'con la ajena: rojo, detiene, conexiones, dice el revoke, nombra la función true | sin ella: verde, el resumen', v_obt,
    v_obt ~ '^con la ajena: rojo, detiene, conexiones, dice el revoke, nombra la función t(rue)? \| sin ella: verde, el resumen$');
end $$;

-- 20. Las capas: sus renglones (banco, estados, puentes; p1 y c8 si están)
--     y el nivel que les toca: lo que la capa llama alarma es aviso, lo que
--     llama cuadre detiene.
do $$
declare
  v_obt text; v_b int; v_e int; v_p int; v_s int; v_i int; v_mal text;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    create temp table _c9_rev on commit drop as select * from fn_cierre_revisar(pg_temp.c9('mes'));
    select count(*) into v_b from _c9_rev where control like 'banco: %' and orden between 110 and 119;
    select count(*) into v_e from _c9_rev where control like 'estados: %';
    select count(*) into v_p from _c9_rev where control like 'puentes: %';
    select count(*) into v_s from _c9_rev where control like 'cobros en línea: %';
    select count(*) into v_i from _c9_rev where control like 'ia: %' and orden >= 145;
    -- las alarmas de p1 y c8 en rojo entran como aviso; sus cuadres, como detiene
    v_mal := 'ninguno';
    if pg_temp.c9('hay_p1') = 'true' then
      execute $q$ select coalesce(string_agg(r.control, ', '), 'ninguno')
                    from _c9_rev r join public.v_stripe_control s on r.control = 'cobros en línea: ' || regexp_replace(s.control, '^(stripe|vista): ', '')
                   where s.ok is distinct from true and r.nivel <> case when s.nivel = 'alarma' then 'aviso' else 'detiene' end $q$ into v_mal;
    end if;
    if pg_temp.c9('hay_c8') = 'true' and v_mal = 'ninguno' then
      execute $q$ select coalesce(string_agg(r.control, ', '), 'ninguno')
                    from _c9_rev r join public.v_contador_control s on r.control = 'ia: ' || regexp_replace(s.control, '^(ia|vista): ', '')
                   where s.ok is distinct from true and r.nivel <> case when s.nivel = 'alarma' then 'aviso' else 'detiene' end $q$ into v_mal;
    end if;
    perform pg_temp.c9_ser('editor');
    v_obt := format('banco %s | estados %s | puentes %s | cobros en línea %s (p1 %s) | ia %s (c8 %s) | niveles mal: %s',
                    (v_b >= 1)::text, (v_e >= 1)::text, (v_p >= 1)::text, (v_s >= 1)::text, pg_temp.c9('hay_p1'), (v_i >= 1)::text, pg_temp.c9('hay_c8'), v_mal);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'las capas en la revisión: renglón de banco, estados y puentes siempre; de cobros en línea si está p1 y de ia si está c8; una alarma entra como aviso y un cuadre como detiene',
    format('banco true | estados true | puentes true | cobros en línea %s (p1 %s) | ia %s (c8 %s) | niveles mal: ninguno', pg_temp.c9('hay_p1'), pg_temp.c9('hay_p1'), pg_temp.c9('hay_c8'), pg_temp.c9('hay_c8')),
    v_obt,
    v_obt = format('banco true | estados true | puentes true | cobros en línea %s (p1 %s) | ia %s (c8 %s) | niveles mal: ninguno', pg_temp.c9('hay_p1'), pg_temp.c9('hay_p1'), pg_temp.c9('hay_c8'), pg_temp.c9('hay_c8')));
end $$;

-- 21. fn_cierre_cerrar con algo en rojo: MX010 con la lista en llano, y nada
--     cerrado (el rojo se provoca: una función ajena DEFINER, por si todo lo
--     demás estuviera en verde).
do $$
declare
  v_obt text; v_e text; v_msg text; v_estado text; v_n int;
begin
  if pg_temp.c9('mes') is null then
    insert into _pruebas values (21, 'fn_cierre_cerrar con rojo → MX010 y nada cerrado', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    lock table public.periodos in exclusive mode;
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    perform pg_temp.c9_ser('dueno');
    begin
      perform fn_cierre_cerrar(pg_temp.c9('mes'), fn_cierre_confirmacion(pg_temp.c9('mes')));
      v_e := 'entró';
    exception when others then v_e := sqlstate; v_msg := sqlerrm;
    end;
    perform pg_temp.c9_ser('editor');
    select estado into v_estado from periodos where periodo = pg_temp.c9('mes');
    select count(*) into v_n from cierres where periodo = pg_temp.c9('mes');
    v_obt := format('%s, dice «lo detienen» %s y nombra permisos %s | período %s, cierres %s', v_e, v_msg like 'No se cierra %: % cosa(s) lo detienen. %',
                    v_msg like '%libro: permisos%', v_estado, v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'fn_cierre_cerrar con algo en rojo: MX010 con la lista en llano («N cosa(s) lo detienen» y cada una), y nada cerrado',
    'MX010, dice «lo detienen» true y nombra permisos true | período abierto, cierres 0', v_obt,
    v_obt ~ '^MX010, dice «lo detienen» t(rue)? y nombra permisos t(rue)? \| período abierto, cierres 0$');
end $$;

-- 22. La confirmación mal escrita: 22023, la pista trae la buena, y nada
--     cerrado (aunque todo esté en verde).
do $$
declare
  v_obt text; v_e text; v_hint text; v_q text; v_estado text; v_ap text := pg_temp.c9('apertura');
begin
  if (select estado from periodos where periodo = v_ap) = 'cerrado' and pg_temp.c9('mes') is null then
    insert into _pruebas values (22, 'la confirmación mal escrita → 22023 y nada cerrado', 'omitida', 'omitida: nada abierto que cerrar', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    lock table public.periodos in exclusive mode;
    if (select estado from periodos where periodo = v_ap) = 'cerrado' then v_ap := pg_temp.c9('mes'); else perform pg_temp.c9_apertura(); end if;
    v_q := pg_temp.c9_aparcar(v_ap);
    perform pg_temp.c9_ser('dueno');
    begin
      perform fn_cierre_cerrar(v_ap, lower(fn_cierre_confirmacion(v_ap)));
      v_e := 'entró';
    exception when others then v_e := sqlstate; get stacked diagnostics v_hint = pg_exception_hint;
    end;
    perform pg_temp.c9_ser('editor');
    select estado into v_estado from periodos where periodo = v_ap;
    v_obt := format('%s, la pista trae «%s» %s | período %s%s', v_e, fn_cierre_confirmacion(v_ap), v_hint = fn_cierre_confirmacion(v_ap), v_estado,
                    case when v_q is null then ' (con todo en verde)' else ' (quedaba en rojo: ' || v_q || ')' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'la confirmación mal escrita (en minúsculas): 22023 con la buena en la pista, y nada cerrado',
    '22023, la pista trae «CERRAR …» true | período abierto', v_obt, v_obt ~ '^22023, la pista trae «CERRAR [^»]+» t(rue)? \| período abierto');
end $$;

-- 23. EL CIERRE: la apertura y después el mes, como el dueño por la API;
--     cierres con hash, balanza y revisión; v_cierres con el nombre;
--     v_cierre_estado pasa al siguiente; escribir en el mes cerrado por
--     fn_postear y como el SQL Editor da MX002; el ajuste del CPA al mes
--     cerrado entra en el siguiente; cerrar otra vez da MX002.
do $$
declare
  v_obt text; v_q text; v_mes text := pg_temp.c9('mes'); v_ap text := pg_temp.c9('apertura'); c record; v_e1 text; v_e2 text; v_e3 text;
  v_aj text; v_sig text; v_nom text; v_cie int; v_hasta date;
begin
  begin
    v_q := pg_temp.c9_cerrar_todo();
    if v_q is not null then
      v_obt := 'omitida: no se pudo poner en verde: ' || v_q;
      raise exception using errcode = 'MXT00';
    end if;
    perform pg_temp.c9_ser('editor');
    select hasta into v_hasta from periodos where periodo = v_mes;
    select * into c from v_cierres where periodo = v_mes;
    select count(*) into v_cie from cierres where periodo in (v_ap, v_mes);
    v_sig := (select periodo from v_cierre_estado where siguiente);
    -- escribir en el mes cerrado: fn_postear (como el dueño) y el SQL Editor
    perform pg_temp.c9_ser('dueno');
    begin
      perform fn_postear(jsonb_build_object('fecha', to_char(v_hasta, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: en un mes cerrado',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '10.00'), jsonb_build_object('cuenta', '1010', 'monto', '-10.00'))));
      v_e1 := 'entró';
    exception when others then v_e1 := sqlstate;
    end;
    perform pg_temp.c9_ser('editor');
    begin
      insert into asiento_lineas (asiento_id, orden, cuenta, monto) values ('00000000-0000-4000-b000-0000000000c9', 1, '6100', 10.00);
      insert into asiento_lineas (asiento_id, orden, cuenta, monto) values ('00000000-0000-4000-b000-0000000000c9', 2, '1010', -10.00);
      insert into asientos (id, fecha_contable, camino, descripcion) values ('00000000-0000-4000-b000-0000000000c9', v_hasta, 'mano', 'C9 PRUEBA: editor en mes cerrado');
      v_e2 := 'entró';
    exception when others then v_e2 := sqlstate;
    end;
    -- el ajuste del CPA al mes cerrado entra en el siguiente abierto
    if pg_temp.c9('mes_sig') is not null then
      perform pg_temp.c9_ser('dueno');
      v_aj := fn_postear(jsonb_build_object('fecha', to_char((select desde from periodos where periodo = pg_temp.c9('mes_sig')) + 4, 'YYYY-MM-DD'),
        'descripcion', 'C9 PRUEBA: ajuste del CPA al mes cerrado', 'tipo', 'ajuste_cpa', 'afecta_periodo', v_mes, 'motivo', 'c9-pruebas (se deshace)',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '10.00'), jsonb_build_object('cuenta', '2010', 'monto', '-10.00'))))->>'periodo';
      begin
        perform fn_cierre_cerrar(v_mes, fn_cierre_confirmacion(v_mes));
        v_e3 := 'entró';
      exception when others then v_e3 := sqlstate;
      end;
      perform pg_temp.c9_ser('editor');
    else
      v_aj := 'sin mes siguiente'; v_e3 := 'MX002';
    end if;
    v_obt := format('cerrados %s (cierres %s) | %s: hash %s, balanza %s, revisión %s filas, cerró %s, rol %s | siguiente %s | fn_postear %s | editor %s | ajuste en %s | cerrar otra vez %s',
                    (select count(*) from periodos where periodo in (v_ap, v_mes) and estado = 'cerrado'), v_cie, v_mes,
                    (c.hash_mayor = fn_cierre_hash_mayor(v_mes))::text,
                    (c.revision is not null and (select fn_cierre_balanza(v_mes)) = (select balanza from cierres where periodo = v_mes))::text,
                    (jsonb_array_length(c.revision) >= 12)::text, c.cerrado_por_nombre, c.cerrado_rol, v_sig, v_e1, v_e2, v_aj, v_e3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'EL CIERRE: la apertura y el mes como el dueño por la API, cierres con hash, balanza y revisión, v_cierres con el nombre, el siguiente avanza, fn_postear y el SQL Editor dan MX002 en el mes cerrado, el ajuste del CPA entra en el siguiente, cerrar otra vez MX002',
    format('cerrados 2 (cierres 2) | %s: hash true, balanza true, revisión true filas, cerró %s, rol authenticated | siguiente %s | fn_postear MX002 | editor MX002 | ajuste en %s | cerrar otra vez MX002',
           pg_temp.c9('mes'), (select nombre from perfiles where id = pg_temp.c9('dueno')::uuid), coalesce(pg_temp.c9('mes_sig'), '?'), coalesce(pg_temp.c9('mes_sig'), 'sin mes siguiente')),
    v_obt,
    case when v_obt like 'omitida:%' then null
         else v_obt = format('cerrados 2 (cierres 2) | %s: hash true, balanza true, revisión true filas, cerró %s, rol authenticated | siguiente %s | fn_postear MX002 | editor MX002 | ajuste en %s | cerrar otra vez MX002',
                             pg_temp.c9('mes'), (select nombre from perfiles where id = pg_temp.c9('dueno')::uuid), coalesce(pg_temp.c9('mes_sig'), '?'), coalesce(pg_temp.c9('mes_sig'), 'sin mes siguiente')) end);
end $$;

-- 24. El export: solo de un período cerrado (MX002), la carpeta (22023), el
--     sha256 (22023), el archivo que no está en Storage o que mide otra
--     cosa (22023, si hay Storage); registra uno; repetir con dos deja historial; v_cierres.
do $$
declare
  v_obt text; v_q text; v_mes text := pg_temp.c9('mes'); e1 text; e2 text; e3 text; e4 text; e5 text; r1 jsonb; r2 jsonb; v_c record;
begin
  begin
    v_q := pg_temp.c9_cerrar_todo();
    if v_q is not null then
      v_obt := 'omitida: no se pudo poner en verde: ' || v_q;
      raise exception using errcode = 'MXT00';
    end if;
    perform pg_temp.c9_ser('editor');
    if pg_temp.c9('hay_storage') = 'true' then
      execute $q$ insert into storage.objects (bucket_id, name, owner) values ('cierres', $1 || '/mayor.csv', $2), ('cierres', $1 || '/balanza.pdf', $2) $q$
        using v_mes, pg_temp.c9('dueno')::uuid;
      execute $q$ insert into storage.objects (bucket_id, name, owner, metadata) values ('cierres', $1 || '/medida.csv', $2, '{"size": 50}'::jsonb) $q$
        using v_mes, pg_temp.c9('dueno')::uuid;
    end if;
    perform pg_temp.c9_ser('dueno');
    begin perform fn_cierre_export(pg_temp.c9('mes_futuro'), jsonb_build_array(jsonb_build_object('ruta', pg_temp.c9('mes_futuro') || '/x.csv', 'sha256', repeat('a', 64), 'bytes', 1))); e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin perform fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', 'otra/x.csv', 'sha256', repeat('a', 64), 'bytes', 1))); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    begin perform fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', v_mes || '/mayor.csv', 'sha256', 'xyz', 'bytes', 1))); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    if pg_temp.c9('hay_storage') = 'true' then
      begin perform fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', v_mes || '/nada.csv', 'sha256', repeat('a', 64), 'bytes', 1))); e4 := 'entró'; exception when others then e4 := sqlstate; end;
      begin perform fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', v_mes || '/medida.csv', 'sha256', repeat('a', 64), 'bytes', 51))); e5 := 'entró'; exception when others then e5 := sqlstate; end;
    else
      e4 := '22023 (sin storage: no se mira)';
      e5 := '22023 (sin storage: no se mira)';
    end if;
    r1 := fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', v_mes || '/mayor.csv', 'sha256', repeat('a', 64), 'bytes', 1234, 'tipo', 'text/csv')));
    r2 := fn_cierre_export(v_mes, jsonb_build_array(jsonb_build_object('ruta', v_mes || '/mayor.csv', 'sha256', repeat('a', 64), 'bytes', 1234),
                                                    jsonb_build_object('ruta', v_mes || '/balanza.pdf', 'sha256', repeat('b', 64), 'bytes', 99)));
    select export_ruta, exportado, exports_anteriores, exportado_por_nombre, jsonb_array_length(export_archivos) as n into v_c from v_cierres where periodo = v_mes;
    perform pg_temp.c9_ser('editor');
    v_obt := format('no cerrado %s | fuera de la carpeta %s | sha mal %s | no está en storage %s | mide otra cosa %s | primero: %s archivo, veces %s | segundo: %s archivos, veces %s, bytes %s | v_cierres: %s, exportado %s, anteriores %s, por %s, %s archivos',
                    e1, e2, e3, e4, e5, r1->>'archivos', r1->>'veces', r2->>'archivos', r2->>'veces', r2->>'bytes', v_c.export_ruta = v_mes || '/', v_c.exportado,
                    v_c.exports_anteriores, v_c.exportado_por_nombre, v_c.n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'el export: solo de un período cerrado, la carpeta, el sha256, el archivo en Storage y su tamaño; registra; repetir deja historial; v_cierres lo enseña con el nombre',
    format('no cerrado MX002 | fuera de la carpeta 22023 | sha mal 22023 | no está en storage 22023 | mide otra cosa 22023 | primero: 1 archivo, veces 1 | segundo: 2 archivos, veces 2, bytes 1333 | v_cierres: true, exportado true, anteriores 1, por %s, 2 archivos',
           (select nombre from perfiles where id = pg_temp.c9('dueno')::uuid)),
    v_obt,
    case when v_obt like 'omitida:%' then null
         else v_obt ~ format('^no cerrado MX002 \| fuera de la carpeta 22023 \| sha mal 22023 \| no está en storage 22023( \(sin storage: no se mira\))? \| mide otra cosa 22023( \(sin storage: no se mira\))? \| primero: 1 archivo, veces 1 \| segundo: 2 archivos, veces 2, bytes 1333 \| v_cierres: t(rue)?, exportado t(rue)?, anteriores 1, por %s, 2 archivos$',
                             (select nombre from perfiles where id = pg_temp.c9('dueno')::uuid)) end);
end $$;

-- 25. La ronda: sus filas con el día de Miami y la hora, v_ronda_ultima, dos
--     corridas seguidas, los 90 días, y apagada no escribe.
do $$
declare
  v_obt text; v_r1 int; v_r2 int; v_n1 int; v_n2 int; v_corr int; v_fecha text; v_u record; v_viejas int; v_apag int; v_n3 int;
begin
  begin
    perform pg_temp.c9_ser('editor');
    perform set_config('mxp.cierre_sin_push', '1', true);
    v_r1 := fn_ronda();
    select count(*), count(distinct corrida_el), min(fecha)::text into v_n1, v_corr, v_fecha from ronda_resultados where corrida_el >= now();
    select * into v_u from v_ronda_ultima limit 1;
    v_r2 := fn_ronda();
    select count(*) into v_n2 from ronda_resultados where corrida_el >= now();
    -- una fila vieja (de hace 91 días), con la marca de la guarda: la limpieza se la lleva
    perform set_config('mx_cierre.escribe', 'ronda_resultados', true);
    insert into ronda_resultados (fecha, corrida_el, periodo, orden, control, nivel, ok, detalle)
    values (fn_fecha_miami(now()) - 91, now() - interval '91 days', null, 1, 'c9-pruebas: vieja', 'aviso', true, 'se deshace');
    perform set_config('mx_cierre.escribe', '', true);
    perform fn_ronda();
    select count(*) into v_viejas from ronda_resultados where control = 'c9-pruebas: vieja';
    perform set_config('mx_cierre.escribe', 'cierre_config', true);
    update cierre_config set ronda_activa = false where id = 1;
    perform set_config('mx_cierre.escribe', '', true);
    select count(*) into v_n3 from ronda_resultados;
    v_apag := fn_ronda();
    v_obt := format('corrida: %s rojos, %s filas en 1 corrida, fecha %s | última: fecha %s, rojos %s, filas %s | segunda: %s rojos, filas %s | vieja de 91 días: queda %s | apagada: devuelve %s y escribe %s',
                    v_r1, v_n1, v_fecha = pg_temp.c9('hoy'), v_u.fecha = pg_temp.c9('hoy')::date, v_u.rojos = v_r1, v_u.filas = v_n1, v_r2, v_n2 = 2 * v_n1,
                    v_viejas, v_apag, (select count(*) from ronda_resultados) - v_n3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'la ronda: sus filas con el día de Miami, v_ronda_ultima (fecha, rojos, filas), dos corridas iguales, lo de más de 90 días se borra, apagada devuelve 0 y no escribe',
    'corrida: N rojos, F filas en 1 corrida, fecha true | última: fecha true, rojos true, filas true | segunda: N rojos, filas true | vieja de 91 días: queda 0 | apagada: devuelve 0 y escribe 0', v_obt,
    v_obt ~ '^corrida: ([0-9]+) rojos, [0-9]+ filas en 1 corrida, fecha t(rue)? \| última: fecha t(rue)?, rojos t(rue)?, filas t(rue)? \| segunda: \1 rojos, filas t(rue)? \| vieja de 91 días: queda 0 \| apagada: devuelve 0 y escribe 0$');
end $$;

-- 26. Los avisos de la ronda: un rojo nuevo manda UN aviso (fn_cartero,
--     grabado en una tabla temporal); repetido, ninguno; con
--     mxp.cierre_sin_push = '1', ninguno; con aviso_push apagado, ninguno;
--     si fn_cartero falla, la corrida siguiente lo reintenta (una vez).
do $$
declare
  v_obt text; v_n1 int; v_n2 int; v_n3 int; v_n4 int; v_n5 int; v_n6 int; v_n7 int; v_t text; v_t2 text; v_f boolean;
begin
  begin
    perform pg_temp.c9_ser('editor');
    create temp table _c9_push (cuerpo jsonb) on commit drop;
    perform set_config('mxp.cierre_sin_push', '1', true);
    perform fn_ronda();   -- la corrida de referencia (lo rojo de hoy ya no es nuevo)
    -- fn_cartero, por una copia que apunta (se deshace con la prueba)
    create or replace function public.fn_cartero(cuerpo jsonb) returns void language plpgsql security definer set search_path = public, pg_temp
      as $f$ begin insert into _c9_push values (cuerpo); end $f$;
    -- un rojo nuevo: una función ajena DEFINER que lee el libro
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    perform set_config('mxp.cierre_sin_push', '0', true);
    perform fn_ronda();
    select count(*), min(cuerpo->>'titulo') into v_n1, v_t from _c9_push;
    perform fn_ronda();
    select count(*) into v_n2 from _c9_push;
    -- otro rojo nuevo, con los avisos apagados por la sesión de pruebas
    drop function public.c9_prueba_lee_libro();
    perform fn_ronda();
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    perform set_config('mxp.cierre_sin_push', '1', true);
    perform fn_ronda();
    select count(*) into v_n3 from _c9_push;
    -- y con aviso_push apagado en la configuración
    drop function public.c9_prueba_lee_libro();
    perform set_config('mxp.cierre_sin_push', '0', true);
    perform fn_ronda();
    perform set_config('mx_cierre.escribe', 'cierre_config', true);
    update cierre_config set aviso_push = false where id = 1;
    perform set_config('mx_cierre.escribe', '', true);
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    perform fn_ronda();
    select count(*) into v_n4 from _c9_push;
    -- el aviso que no sale: fn_cartero falla; la corrida siguiente lo reintenta, y la otra ya no
    drop function public.c9_prueba_lee_libro();
    perform set_config('mx_cierre.escribe', 'cierre_config', true);
    update cierre_config set aviso_push = true where id = 1;
    perform set_config('mx_cierre.escribe', '', true);
    perform fn_ronda();
    create or replace function public.fn_cartero(cuerpo jsonb) returns void language plpgsql security definer set search_path = public, pg_temp
      as $f$ begin raise exception 'C9 PRUEBA: el cartero no sale'; end $f$;
    create function public.c9_prueba_lee_libro() returns bigint language sql security definer set search_path = public, pg_temp as 'select count(*) from asientos';
    grant execute on function public.c9_prueba_lee_libro() to authenticated;
    v_t2 := current_setting('client_min_messages');
    perform set_config('client_min_messages', 'error', true);   -- (el warning del cartero que falla, sin ruido)
    perform fn_ronda();
    perform set_config('client_min_messages', v_t2, true);
    select count(*) into v_n5 from _c9_push;
    select bool_or(q.aviso_fallo) into v_f from ronda_resultados q
     where q.corrida_el = (select max(corrida_el) from ronda_resultados) and q.control = 'libro: permisos';
    create or replace function public.fn_cartero(cuerpo jsonb) returns void language plpgsql security definer set search_path = public, pg_temp
      as $f$ begin insert into _c9_push values (cuerpo); end $f$;
    perform fn_ronda();
    select count(*) into v_n6 from _c9_push;
    perform fn_ronda();
    select count(*) into v_n7 from _c9_push;
    v_obt := format('rojo nuevo: %s aviso (%s) | repetido: %s | con sin_push: %s | con aviso_push apagado: %s | cartero que falla: %s (aviso_fallo %s), reintento: %s, después: %s',
                    v_n1, v_t, v_n2 - v_n1, v_n3 - v_n2, v_n4 - v_n3, v_n5 - v_n4, coalesce(v_f::text, 'nulo'), v_n6 - v_n5, v_n7 - v_n6);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'los avisos de la ronda: un rojo nuevo manda UN aviso al teléfono (fn_cartero) con su título; repetido, ninguno; con mxp.cierre_sin_push = 1, ninguno; con aviso_push apagado, ninguno; si el cartero falla, se reintenta una vez en la corrida siguiente',
    'rojo nuevo: 1 aviso (Contabilidad: libro: permisos) | repetido: 0 | con sin_push: 0 | con aviso_push apagado: 0 | cartero que falla: 0 (aviso_fallo true), reintento: 1, después: 0', v_obt,
    v_obt = 'rojo nuevo: 1 aviso (Contabilidad: libro: permisos) | repetido: 0 | con sin_push: 0 | con aviso_push apagado: 0 | cartero que falla: 0 (aviso_fallo true), reintento: 1, después: 0');
end $$;

-- 27. La balanza de un mes cerrado que cambió por debajo de las guardas: la
--     ronda pone «cierre guardado: <mes>» en rojo con qué hacer.
do $$
declare
  v_obt text; v_q text; v_mes text := pg_temp.c9('mes'); v_a text; v_b text;
begin
  begin
    v_q := pg_temp.c9_cerrar_todo();
    if v_q is not null then
      v_obt := 'omitida: no se pudo poner en verde: ' || v_q;
      raise exception using errcode = 'MXT00';
    end if;
    perform pg_temp.c9_ser('editor');
    perform set_config('mxp.cierre_sin_push', '1', true);
    perform fn_ronda();
    select format('%s|%s', case when ok then 'verde' else 'rojo' end, left(detalle, 60)) into v_a from v_ronda_ultima where control = 'cierre guardado: ' || v_mes;
    -- por debajo de las guardas (solo el dueño de la base puede): la balanza guardada cambia
    alter table public.cierres disable trigger trg_cierres_guarda;
    update cierres set balanza = '[]'::jsonb where periodo = v_mes;
    alter table public.cierres enable trigger trg_cierres_guarda;
    perform fn_ronda();
    select format('%s|%s|%s', case when ok then 'verde' else 'rojo' end, nivel, (detalle like '% cambió después de cerrarse: %la balanza difiere en %' and que_hacer like '%restaura del respaldo%')::text) into v_b
      from v_ronda_ultima where control = 'cierre guardado: ' || v_mes;
    v_obt := format('antes: %s | cambiada: %s', case when v_a like 'verde|La balanza y el hash del mayor%' then 'verde, iguales' else v_a end,
                    case when v_b = 'rojo|detiene|true' then 'rojo, detiene, lo dice y manda al respaldo' else v_b end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'la balanza de un mes cerrado que cambió por debajo de las guardas: la ronda pone «cierre guardado» en rojo (detiene), dice qué difiere y manda al respaldo',
    'antes: verde, iguales | cambiada: rojo, detiene, lo dice y manda al respaldo', v_obt,
    case when v_obt like 'omitida:%' then null else v_obt = 'antes: verde, iguales | cambiada: rojo, detiene, lo dice y manda al respaldo' end);
end $$;

-- 28. La reserva 1030: sin % lo dice; con % calcula (objetivo, transfiere o
--     sobra o al día); marcar un estimado lo resta (MX008 dos veces; sin
--     3200, 22023); anular lo devuelve (MX008 dos veces).
do $$
declare
  v_obt text; r0 record; r1 record; r2 record; r3 record; v_pago uuid; v_est uuid; e1 text; e2 text; e3 text; v_util numeric; v_obj numeric;
  v_fecha date;
begin
  begin
    perform pg_temp.c9_ser('editor');
    v_fecha := greatest((select min(p.desde) from periodos p where p.tipo = 'mes' and p.estado = 'abierto'), fn_fecha_miami(now()) - 40);
    perform pg_temp.c9_ser('dueno');
    perform fn_cierre_config('{"reserva_pct": null}');
    select * into r0 from v_reserva_impuestos;
    perform fn_cierre_config('{"reserva_pct": 25}');
    select * into r1 from v_reserva_impuestos;
    v_util := r1.utilidad_anio;
    v_obj := greatest(round(v_util * 0.25, 2), 0);
    -- un estimado pagado (Dr 3200 / Cr 1010) de 50
    v_pago := (fn_postear(jsonb_build_object('fecha', to_char(fn_fecha_miami(now()), 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: estimado al IRS (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200', 'monto', '50.00'), jsonb_build_object('cuenta', '1010', 'monto', '-50.00'))))->>'id')::uuid;
    v_est := (fn_reserva_estimado_marcar(v_pago, 'c9-pruebas')->>'id')::uuid;
    select * into r2 from v_reserva_impuestos;
    begin perform fn_reserva_estimado_marcar(v_pago); e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin
      perform fn_reserva_estimado_marcar((fn_postear(jsonb_build_object('fecha', to_char(fn_fecha_miami(now()), 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: no es un estimado',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '5.00'), jsonb_build_object('cuenta', '1010', 'monto', '-5.00'))))->>'id')::uuid);
      e2 := 'entró';
    exception when others then e2 := sqlstate;
    end;
    perform fn_reserva_estimado_anular(v_est, 'c9-pruebas: marcado por error');
    select * into r3 from v_reserva_impuestos;
    begin perform fn_reserva_estimado_anular(v_est, 'otra vez'); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    perform pg_temp.c9_ser('editor');
    v_obt := format('sin %%: %s, objetivo %s | con 25 %%: objetivo %s, pagados %s, mensaje %s | con el estimado: pagados %s, objetivo_1030 %s | dos veces %s | sin 3200 %s | anulado: pagados %s | anular dos veces %s',
                    case when r0.mensaje like 'Falta el %% que fije el CPA%' then 'lo dice' else r0.mensaje end, coalesce(r0.objetivo::text, 'nulo'),
                    r1.objetivo = v_obj, r1.estimados_pagados,
                    case when r1.mensaje like 'Transfiere $%' then 'transfiere' when r1.mensaje like 'Sobra $%' then 'sobra' when r1.mensaje like 'La reserva (1030) está al día%' then 'al día' else r1.mensaje end,
                    r2.estimados_pagados - r1.estimados_pagados, r2.objetivo_1030 = greatest(v_obj - r2.estimados_pagados, 0), e1, e2,
                    r3.estimados_pagados - r1.estimados_pagados, e3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'la reserva 1030: sin % lo dice y no inventa cifras; con 25 % calcula el objetivo y dice transfiere/sobra/al día; un estimado marcado se resta (MX008 dos veces; sin 3200, 22023); anulado vuelve (MX008 dos veces)',
    'sin %: lo dice, objetivo nulo | con 25 %: objetivo true, pagados P, mensaje transfiere|sobra|al día | con el estimado: pagados 50.00, objetivo_1030 true | dos veces MX008 | sin 3200 22023 | anulado: pagados 0.00 | anular dos veces MX008',
    v_obt,
    v_obt ~ '^sin %: lo dice, objetivo nulo \| con 25 %: objetivo t(rue)?, pagados [0-9.]+, mensaje (transfiere|sobra|al día) \| con el estimado: pagados 50\.00, objetivo_1030 t(rue)? \| dos veces MX008 \| sin 3200 22023 \| anulado: pagados 0\.00 \| anular dos veces MX008$');
end $$;

-- 29. El estimado que vence en 15 días: con el reloj fingido (fn_fecha_miami
--     devuelve al menos ese día, como c2-pruebas), la vista lo dice y la
--     ronda avisa (aviso, no detiene).
do $$
declare
  v_obt text; r record; v_g text; v_hoy date := pg_temp.c9('hoy')::date; v_fijo date;
begin
  begin
    perform pg_temp.c9_ser('editor');
    -- el 3 de enero siguiente: el 15-ene vence en 12 días
    v_fijo := make_date(extract(year from v_hoy)::int + 1, 1, 3);
    execute format($f$ create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp
                       as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$ $f$, v_fijo);
    select * into r from v_reserva_impuestos;
    select format('%s|%s|%s', case when (x->>'ok')::boolean then 'verde' else 'rojo' end, x->>'nivel', x->>'detalle') into v_g
      from jsonb_array_elements(fn_ronda_globales()) x where x->>'control' = 'reserva: próximo estimado';
    v_obt := format('hoy fingido %s | próximo %s, en %s días, en 15 días %s | la ronda: %s',
                    r.hoy = v_fijo, r.proximo_estimado, r.dias_para_estimado, r.estimado_en_15_dias,
                    case when v_g like 'rojo|aviso|El impuesto estimado vence el ' || make_date(extract(year from v_hoy)::int + 1, 1, 15) || ' (en 12 días)%' then 'rojo, aviso, lo dice' else v_g end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'el estimado que vence en 15 días (reloj fingido al 3-ene): la vista dice el 15-ene, 12 días, en 15 días; la ronda avisa (aviso)',
    format('hoy fingido true | próximo %s, en 12 días, en 15 días true | la ronda: rojo, aviso, lo dice', make_date(extract(year from pg_temp.c9('hoy')::date)::int + 1, 1, 15)),
    v_obt, v_obt ~ format('^hoy fingido t(rue)? \| próximo %s, en 12 días, en 15 días t(rue)? \| la ronda: rojo, aviso, lo dice$', make_date(extract(year from pg_temp.c9('hoy')::date)::int + 1, 1, 15)));
end $$;

-- 30. El DR-15: lo cargado a 2300 en el mes y su saldo; la base del use tax
--     de las propuestas de c8 aprobadas con la marca use_tax (si está c8);
--     la nota dice lo que no se sabe.
do $$
declare
  v_obt text; v_mes text := pg_temp.c9('mes'); v_hasta date; r0 record; r1 record; v_mov uuid; v_as uuid; v_base text;
begin
  if v_mes is null then
    insert into _pruebas values (30, 'el DR-15', 'omitida', 'omitida: no hay un mes terminado abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c9_ser('editor');
    select hasta into v_hasta from periodos where periodo = v_mes;
    select * into r0 from v_dr15_mes where periodo = v_mes;
    perform fn_postear(jsonb_build_object('fecha', to_char(v_hasta, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: use tax devengado (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '7.50'), jsonb_build_object('cuenta', '2300', 'monto', '-7.50'))));
    if pg_temp.c9('hay_c8') = 'true' then
      v_mov := pg_temp.c9_cargo('c9-t30', v_hasta, 100.00, 'C9 PRUEBA AMAZON MKTPL 2026 WA');
      select a.id into v_as from asientos a order by a.cadena_pos desc limit 1;
      execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta, estado, aprobado_por, aprobado_el, lineas_finales, asiento_id)
                  values ($1, 'edgar', '{"lineas": [{"cuenta": "6500"}], "motivo": "c9-pruebas", "confianza": 1, "flags": {"use_tax": true}}', 'aprobada', $2, now(),
                          '[{"cuenta": "6500", "monto": 100.00}]', $3) $q$ using v_mov, pg_temp.c9('dueno')::uuid, v_as;
      select * into r1 from v_dr15_mes where periodo = v_mes;
      v_base := format('base +%s (%s compra)', r1.compras_use_tax_base - r0.compras_use_tax_base, r1.compras_use_tax_n - r0.compras_use_tax_n);
    else
      select * into r1 from v_dr15_mes where periodo = v_mes;
      v_base := case when r1.compras_use_tax_base is null and r1.nota like 'Sin el contador (c8)%' then 'base nula, la nota lo dice' else 'base ' || coalesce(r1.compras_use_tax_base::text, 'nula') end;
    end if;
    v_obt := format('2300 cargado +%s, saldo +%s | %s | ventas %s, sales tax %s, la nota lo dice %s',
                    r1.use_tax_cargado_2300 - r0.use_tax_cargado_2300, r1.use_tax_saldo_2300 - r0.use_tax_saldo_2300, v_base,
                    coalesce(r1.ventas_gravables::text, 'nulas'), coalesce(r1.sales_tax_cobrado::text, 'nulo'), r1.nota like '%no se saben%');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'el DR-15 (v_dr15_mes): lo cargado a 2300 en el mes y su saldo; la base del use tax de las compras que la IA marcó y Edgar aprobó (c8; sin c8, nula y lo dice); ventas y sales tax nulos con su nota',
    case when pg_temp.c9('hay_c8') = 'true' then '2300 cargado +7.50, saldo +7.50 | base +100.00 (1 compra) | ventas nulas, sales tax nulo, la nota lo dice true'
         else '2300 cargado +7.50, saldo +7.50 | base nula, la nota lo dice | ventas nulas, sales tax nulo, la nota lo dice true' end,
    v_obt,
    v_obt ~ case when pg_temp.c9('hay_c8') = 'true' then '^2300 cargado \+7\.50, saldo \+7\.50 \| base \+100\.00 \(1 compra\) \| ventas nulas, sales tax nulo, la nota lo dice t(rue)?$'
                 else '^2300 cargado \+7\.50, saldo \+7\.50 \| base nula, la nota lo dice \| ventas nulas, sales tax nulo, la nota lo dice t(rue)?$' end);
end $$;

-- 31. El hash del mayor: estable, de 64 hex, cambia con una línea más, y el
--     de un período vacío es el sha256 del texto vacío.
do $$
declare
  v_obt text; h1 text; h2 text; h3 text; h0 text; v_mes text := pg_temp.c9('mes'); v_hasta date;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    select hasta into v_hasta from periodos where periodo = v_mes;
    h1 := fn_cierre_hash_mayor(v_mes);
    h2 := fn_cierre_hash_mayor(v_mes);
    perform fn_postear(jsonb_build_object('fecha', to_char(v_hasta, 'YYYY-MM-DD'), 'descripcion', 'C9 PRUEBA: una línea más (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '1.00'), jsonb_build_object('cuenta', '1010', 'monto', '-1.00'))));
    h3 := fn_cierre_hash_mayor(v_mes);
    h0 := fn_cierre_hash_mayor((select periodo from periodos p where p.tipo = 'mes' and not exists (select 1 from asientos a where a.periodo = p.periodo) order by p.desde desc limit 1));
    perform pg_temp.c9_ser('editor');
    v_obt := format('estable %s | 64 hex %s | cambia %s | vacío = sha256('''') %s', h1 = h2, h1 ~ '^[0-9a-f]{64}$', h3 <> h1,
                    h0 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'el hash del mayor: estable, 64 hex, cambia con una línea más, y el de un período vacío es el sha256 del texto vacío',
    'estable true | 64 hex true | cambia true | vacío = sha256('''') true', v_obt, v_obt ~ '^estable t(rue)? \| 64 hex t(rue)? \| cambia t(rue)? \| vacío = sha256\(''''\) t(rue)?$');
end $$;

-- 32. La guarda de las tablas de c9: a mano, MX003 (también el dueño por la
--     API); un cierre no se borra ni se edita; una fila de la ronda no se
--     edita.
do $$
declare
  v_obt text; e1 text; e2 text; e3 text; e4 text; e5 text; e6 text; v_q text;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    begin update cierre_config set ronda_activa = false where id = 1; e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin insert into activos_fijos (descripcion, cuenta, fecha_servicio, costo, vida_meses) values ('x', '1510', '2026-10-01', 10, 12); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    perform pg_temp.c9_ser('editor');
    begin insert into cierres (periodo, cerrado_el, revision, hash_mayor, balanza, asientos, lineas) values (pg_temp.c9('mes'), now(), '[]', repeat('a', 64), '[]', 0, 0); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    perform set_config('mxp.cierre_sin_push', '1', true);
    perform fn_ronda();
    begin update ronda_resultados set ok = true where ok is distinct from true; e4 := 'entró'; exception when others then e4 := sqlstate; end;
    begin delete from ronda_resultados; e5 := 'entró'; exception when others then e5 := sqlstate; end;
    -- un cierre de verdad (si se puede): ni borrar ni editar
    v_q := pg_temp.c9_cerrar_todo();
    perform pg_temp.c9_ser('editor');
    if v_q is null then
      begin delete from cierres where periodo = pg_temp.c9('mes'); e6 := 'entró'; exception when others then e6 := sqlstate; end;
      begin
        perform set_config('mx_cierre.escribe', 'cierres', true);
        update cierres set hash_mayor = repeat('b', 64) where periodo = pg_temp.c9('mes');
        e6 := e6 || ' ' || 'entró';
      exception when others then e6 := e6 || ' ' || sqlstate;
      end;
      perform set_config('mx_cierre.escribe', '', true);
    else
      e6 := 'MX003 MX003 (sin cerrar: ' || v_q || ')';
    end if;
    v_obt := format('config por la API %s | activo por la API %s | cierre a mano %s | ronda editar %s | ronda borrar %s | cierre borrar y editar %s', e1, e2, e3, e4, e5, e6);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'la guarda de las tablas de c9: a mano MX003 (el dueño por la API también); un cierre no se borra ni se edita (ni con la marca); una fila de la ronda no se edita ni se borra',
    'config por la API MX003 | activo por la API MX003 | cierre a mano MX003 | ronda editar MX003 | ronda borrar MX003 | cierre borrar y editar MX003 MX003', v_obt,
    v_obt like 'config por la API MX003 | activo por la API MX003 | cierre a mano MX003 | ronda editar MX003 | ronda borrar MX003 | cierre borrar y editar MX003 MX003%');
end $$;

-- 33. fn_cierre_config y sus frenos: clave desconocida 22023, % fuera de
--     rango MX005, método raro 22023, booleano que no lo es 22023; y lo que
--     cambia, cambia (y vuelve al deshacer: la 34).
do $$
declare
  v_obt text; e1 text; e2 text; e3 text; e4 text; r jsonb;
begin
  begin
    perform pg_temp.c9_ser('dueno');
    begin perform fn_cierre_config('{"color": "cobre"}'); e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin perform fn_cierre_config('{"reserva_pct": 150}'); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    begin perform fn_cierre_config('{"metodo_depreciacion": "acelerada"}'); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    begin perform fn_cierre_config('{"aviso_push": "sí"}'); e4 := 'entró'; exception when others then e4 := sqlstate; end;
    r := fn_cierre_config('{"ronda_activa": false, "reserva_pct": 21.5, "metodo_depreciacion": "manual", "aviso_push": false}');
    perform pg_temp.c9_ser('editor');
    v_obt := format('clave %s | pct 150 %s | método %s | booleano %s | cambia: %s %s %s %s, quién %s', e1, e2, e3, e4,
                    r->>'ronda_activa', r->>'reserva_pct', r->>'metodo_depreciacion', r->>'aviso_push', r->>'actualizado_por' = pg_temp.c9('dueno'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'fn_cierre_config y sus frenos (22023, MX005), y lo que cambia queda con quién',
    'clave 22023 | pct 150 MX005 | método 22023 | booleano 22023 | cambia: false 21.50 manual false, quién true', v_obt,
    v_obt ~ '^clave 22023 \| pct 150 MX005 \| método 22023 \| booleano 22023 \| cambia: false 21\.50? manual false, quién t(rue)?$');
end $$;

-- 34. Nada queda: lo de c9, el libro, los períodos, el banco, las
--     conciliaciones, los recibos, las cuentas, los perfiles y las funciones,
--     igual que al empezar.
do $$
declare
  v_obt text;
begin
  perform pg_temp.c9_ser('editor');
  v_obt := case when pg_temp.c9_conteos() = pg_temp.c9('conteos') then 'igual que al empezar'
                else 'antes: ' || pg_temp.c9('conteos') || ' · ahora: ' || pg_temp.c9_conteos() end;
  insert into _pruebas values (34, 'nada queda al deshacer', 'igual que al empezar', v_obt, v_obt = 'igual que al empezar');
end $$;

-- 35. El cierre de la suite: c2 (la cadena y «permisos»), c3, c6 y c4 en
--     verde con c9 pegado (salvo lo que ya estaba en rojo antes, que se
--     dice), c8 sin cuadres rojos, y nada de c9 en la API ni DEFINER.
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_c8 text; v_api text;
begin
  begin
    perform pg_temp.c9_ser('editor');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena() where not ok;
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar() where not ok;
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c9('rojos_c6'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c9('rojos_c4'), ', ')));
    if pg_temp.c9('hay_c8') = 'true' then
      execute $q$ select coalesce(string_agg(orden::text, ' ' order by orden), 'ninguno') from public.v_contador_control where nivel = 'cuadre' and not ok $q$ into v_c8;
    else
      v_c8 := 'ninguno';
    end if;
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and (p.proname like 'fn\_cierre\_%' or p.proname like 'fn\_ronda%' or p.proname like 'fn\_activo\_%' or p.proname like 'fn\_depreciacion\_%' or p.proname like 'fn\_reserva\_%')
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | c8 cuadres rojos: %s | c9 anon/service_role o definer: %s', v_c2, v_c3, v_c6, v_c4, v_c8, v_api);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'el cierre de la suite: c2, c3, c6 y c4 en verde con c9 puesto (salvo lo que ya estaba en rojo antes), c8 sin cuadres rojos, nada de c9 para anon o service_role ni SECURITY DEFINER',
    'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres rojos: ninguno | c9 anon/service_role o definer: ninguna',
    v_obt || case when pg_temp.c9('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.c9('rojos_c4') || ')' else '' end
          || case when pg_temp.c9('rojos_c6') <> '' then ' (ya en rojo antes, en c6: ' || pg_temp.c9('rojos_c6') || ')' else '' end,
    v_obt = 'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres rojos: ninguno | c9 anon/service_role o definer: ninguna');
end $$;

-- 36. Pegar dos veces no hace daño: el banco lo corre (dos pegados seguidos
--     antes de esta suite); aquí, que fn_cierre_pegado responde con sus
--     filas y que la configuración sigue siendo UNA fila con id 1.
do $$
declare
  v_obt text; v_n int; v_cfg int;
begin
  begin
    perform pg_temp.c9_ser('editor');
    select count(*) into v_n from fn_cierre_pegado();
    select count(*) into v_cfg from cierre_config;
    v_obt := format('pegado %s filas | configuración %s fila (id %s)', v_n, v_cfg, (select id from cierre_config limit 1));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'fn_cierre_pegado responde (lo que enseña el final del pegado) y la configuración es una fila; pegar dos veces no la pisa (lo corre el banco)',
    'pegado 12 filas | configuración 1 fila (id 1)', v_obt, v_obt = 'pegado 12 filas | configuración 1 fila (id 1)');
end $$;


-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1 y c8): si el SQL Editor deja de esperar, la corrida sigue en el
-- servidor hasta el final y se lee después con
--   select * from pruebas.c9_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c9_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c9_resultado from public, anon, authenticated, service_role;
truncate pruebas.c9_resultado;
insert into pruebas.c9_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
