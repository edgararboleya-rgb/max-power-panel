-- =====================================================================
-- c8-pruebas.sql — el contador (la IA que propone y nunca postea) se
-- prueba a sí mismo (c8-contador.sql). 31-oct-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c8-contador.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 25 filas, todas
-- con ok = true. Si el editor se cansa antes del final, la corrida sigue en
-- el servidor y se lee después en pruebas.c8_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c7, s1, p1 y c8-contador.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c8-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni los cargos que siembra, ni sus asientos, ni el gasto que
-- anota); la 24 lo comprueba. Los cargos son inventados (ids c8-…,
-- comercios de Ocala y Belleview, montos redondos) y entran por la cuenta
-- del banco de la empresa (1010) como los trae Plaid, en nombre del dueño;
-- la IA no se llama nunca: lo que contestaría se le da a la base tal cual
-- (fn_contador_propuesta_guardar), que es lo que la función de borde hace.
-- Ningún dato real.
--
-- Lo que mira, una prueba cada una:
-- la instalación (las cuatro tablas cerradas, la configuración con el dueño,
-- dónde se anota el gasto, las vistas) y quién puede llamar qué (la función
-- de borde como postgres sí; service_role, el dueño, el equipo y anon por
-- la API, no); el catálogo (nada SECURITY DEFINER ni en la API, cada
-- función con su comentario, ningún trigger, ningún prefijo sellado) y las
-- vistas por rol; las cuentas permitidas (nunca 6000, nunca un banco) y el
-- porqué de cada una que no; lo que espera y su contexto (el límite, el
-- orden, sin datos personales, las obras activas, los ejemplos); las
-- reglas antes que la IA (la más específica gana, el empate no decide, la
-- cuenta del banco, una rechazada no se repite, una rota no se aplica, las
-- partes con su redondeo); el tope (el propio, el de la app, el
-- interruptor; una ráfaga no se abre); las ráfagas (solo Opus y Fable, sus
-- centavos al precio de claude-opus-5-5 y su fila en el gasto del mes); lo
-- que contesta la IA (válido, inválido en todas sus formas, la pendiente
-- anterior caduca); aprobar (el asiento vivo de c6 en nombre del dueño,
-- su descripción y su procedencia, la regla aprendida limpia de números y
-- ciudades, el siguiente del mismo comercio por regla sin IA); la obra
-- (sin ella MX008 «elige la obra», con ella en la línea); clasificar
-- (editada, de Edgar sin propuesta, sin recordar, los errores de c6 tal
-- cual); rechazar; las reglas que dicta Edgar (alta con todos sus frenos y
-- baja con su motivo); el nombre del comercio y lo que se tapa (el correo
-- también en la forma normalizada de c6, «JPEREZ MAIL COM»; un hash o un
-- uuid enteros, nunca; el sello prompt_version, prefijo_hash y
-- reglas_version íntegro en «entrada»); una sola ráfaga a la vez (MX008 con
-- otra en marcha; una abierta hace más de cinco minutos se da por perdida
-- con su error); el control en rojo cuando toca (60 a 63 y 70 a 73, cada
-- uno provocado y vuelto a verde); la suplantación; las vistas del estado y
-- de la bandeja; y (la
-- 25) que al final c2 (fn_verificar_cadena), c3, c6 (fn_banco_control) y
-- c4 (fn_estados_control, salvo lo que ya estaba en rojo ANTES de empezar,
-- que la prueba dice: en el banco, «cuadre: apertura en el libro», que no
-- tiene apertura) siguen en verde y el control de c8 sin cuadres en rojo.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, la cuenta del banco, las obras y las fechas.
create temp table if not exists _c8 (k text primary key, v text);
truncate _c8;
insert into _c8
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c8
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
-- las obras activas (las que la IA ve), la primera de ellas y otra
insert into _c8
select 'obra', p.id from proyectos p where p.estado in ('aprobado', 'ejecucion', 'pausa') order by p.nombre, p.id limit 1;
insert into _c8
select 'obra2', p.id from proyectos p
 where p.estado in ('aprobado', 'ejecucion', 'pausa') and p.id <> (select v from _c8 where k = 'obra') order by p.nombre, p.id limit 1;
-- la cuenta del banco de la empresa (la de Plaid y de Chase: 1010) y una
-- tarjeta (una 2100-xxxx activa), para las reglas que valen solo en una
insert into _c8 values ('banco', '1010');
insert into _c8
select 'tarjeta', c.codigo from cuentas c where c.codigo like '2100-%' and c.imputable and c.activa order by c.codigo limit 1;
-- hoy (Miami) y el día de los cargos de prueba (del mes de hoy)
insert into _c8 values ('hoy', fn_fecha_miami(now())::text);
insert into _c8 values ('d', greatest(fn_fecha_miami(now()) - 3, date_trunc('month', fn_fecha_miami(now()))::date)::text);
grant select on _c8 to public;  -- las pruebas cambian de rol (service_role, el dueño, anon) y siguen leyendo lo común

-- El control de c4 sin tope por reloj (como en c4-pruebas y p1-pruebas).
do $$
begin
  perform set_config('c4.control_tope', '0', false);
end $$;

create or replace function pg_temp.c8(k text) returns text language sql as $$ select v from _c8 where k = $1 $$;

-- ser la función de borde (como postgres: sin sesión) / la misma en nombre
-- del dueño (sin cambiar de rol, como la sincronización de Plaid) /
-- service_role / anon / el dueño o el equipo por la API (en aal2)
create or replace function pg_temp.c8_ser(quien text) returns void language plpgsql as $$
begin
  execute 'reset role';
  if quien = 'servicio' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien = 'como_dueno' then
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c8('dueno'), 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', pg_temp.c8('dueno'), true);
  elsif quien in ('service_role', 'anon') then
    perform set_config('request.jwt.claims', json_build_object('role', quien)::text, true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute format('set local role %I', quien);
  else
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c8(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c8(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Lo de cada prueba, dentro de su subtransacción: el candado del casado
-- primero (el orden de la app, como c6-pruebas y p1-pruebas) y la función
-- de borde como quien llama.
create or replace function pg_temp.c8_montar() returns void language plpgsql as $$
begin
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  perform pg_temp.c8_ser('servicio');
end $$;

-- Un cargo del banco como lo trae Plaid (en nombre del dueño, como la
-- sincronización de la mañana), y «Casar» para que la bandeja lo mire (sin
-- ticket ni asiento que lo explique, queda «sin_ticket»). p_monto en
-- positivo = lo que salió. Devuelve el movimiento.
create or replace function pg_temp.c8_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text, p_cuenta text default null)
returns uuid language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_cta    text := coalesce(p_cuenta, pg_temp.c8('banco'));
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c8('dueno'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c8('dueno'), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', v_cta, 'nombre', 'Plaid · c8-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object(
               'id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text, 'descripcion', p_desc, 'tipo', 'DEBIT',
               'pendiente', false))));
  perform fn_banco_casar_todo(v_cta);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  return (select m.id from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1);
end $$;
-- El movimiento de un id de Plaid; su propuesta pendiente; la última
create or replace function pg_temp.c8_mov(p_id text) returns uuid language sql as $$
  select m.id from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1
$$;
create or replace function pg_temp.c8_prop(p_id text) returns uuid language sql as $$
  select p.id from contador_propuestas p where p.movimiento_id = pg_temp.c8_mov(p_id) and p.estado = 'pendiente'
$$;
create or replace function pg_temp.c8_ultima(p_id text) returns contador_propuestas language sql as $$
  select p from contador_propuestas p where p.movimiento_id = pg_temp.c8_mov(p_id) order by p.creado_el desc, p.id desc limit 1
$$;
-- «Des-casar» en nombre del dueño (la bandeja)
create or replace function pg_temp.c8_descasar(p_mov uuid, p_motivo text) returns void language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c8('dueno'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c8('dueno'), true);
  perform fn_banco_descasar(p_mov, p_motivo);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
end $$;
-- Las reglas que Edgar ya tenga para un comercio de prueba, aparcadas
-- (dentro de la prueba, se deshace): así lo que la prueba aprende es la
-- única regla que casa
create or replace function pg_temp.c8_sin_reglas(p_regex text) returns void language sql as $$
  update contador_reglas set activa = false where activa and patron ~* p_regex
$$;
-- El contador encendido y lejos de los topes (dentro de la prueba, se
-- deshace): lo que mira la prueba es lo suyo, no el gasto real del mes
create or replace function pg_temp.c8_al_dia() returns void language sql as $$
  update contador_config set activa = true, tope_mes_centavos = 1000000 where id = 1;
  update asistente_ajustes set valor = '1000000' where clave = 'tope_mes_centavos';
$$;
-- Una ráfaga abierta con la configuración de hoy, por el dueño. La base no
-- abre una ráfaga mientras otra siga abierta (MX008 «ya hay una ráfaga en
-- marcha»): la función de borde siempre cierra la suya; aquí, la que una
-- prueba dejó abierta se cierra antes, sin uso (0 centavos, sin error), como
-- haría la función.
create or replace function pg_temp.c8_lote(p_n int default 1) returns uuid language plpgsql as $$
declare
  v uuid;
begin
  perform fn_contador_lote_cerrar(l.id, '{}'::jsonb) from contador_lotes l where l.cerrado_el is null;
  select fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, c.modelo, c.effort, 'pv-c8-pruebas', 'ph-c8-pruebas', p_n) into v
    from contador_config c where c.id = 1;
  return v;
end $$;
-- Lo que la IA contestaría, dado a la base tal cual (lo que hace la función
-- de borde por cada respuesta)
create or replace function pg_temp.c8_ia(p_mov uuid, p_lote uuid, p_lineas jsonb, p_motivo text, p_conf numeric, p_flags jsonb default null,
                                          p_alt jsonb default null)
returns jsonb language sql as $$
  select fn_contador_propuesta_guardar(p_mov, p_lote,
           jsonb_build_object('movimiento', jsonb_build_object('desc_norm', m.desc_norm, 'monto', m.monto, 'fecha', m.fecha),
                              'reglas_version', 'x', 'prefijo_hash', 'ph-c8-pruebas'),
           jsonb_build_object('id', 'msg_c8', 'stop_reason', 'end_turn'),
           jsonb_strip_nulls(jsonb_build_object('lineas', p_lineas, 'motivo', p_motivo, 'confianza', p_conf, 'flags', p_flags,
                                                'alternativas', p_alt)),
           c.modelo, c.effort, 'pv-c8-pruebas')
    from movimientos_banco m cross join contador_config c where m.id = p_mov and c.id = 1
$$;
-- Las líneas de un asiento, en una cadena: cuenta monto [obra]
create or replace function pg_temp.c8_lineas(p_asiento uuid) returns text language sql as $$
  select string_agg(concat_ws(' ', l.cuenta, l.monto::text, case when l.proyecto_id is not null then 'obra:' || l.proyecto_id end), ' | '
                    order by l.orden)
    from asiento_lineas l where l.asiento_id = p_asiento
$$;
-- El control de c8: las filas en rojo de un nivel, o una fila
create or replace function pg_temp.c8_rojos(p_nivel text default 'cuadre') returns text language sql as $$
  select coalesce(string_agg(c.orden::text, ' ' order by c.orden), 'ninguno') from v_contador_control c where c.nivel = p_nivel and not c.ok
$$;
create or replace function pg_temp.c8_fila(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from v_contador_control c where c.orden = p_orden
$$;
-- Lo que hay en las tablas que c8 toca (la 24 lo compara)
create or replace function pg_temp.c8_conteos() returns text language sql as $$
  select format('config %s · reglas %s · lotes %s · propuestas %s · uso %s · movimientos %s · archivos %s · asientos %s · cuentas %s · '
                'perfiles %s · ajustes %s',
                (select count(*) from contador_config), (select count(*) from contador_reglas), (select count(*) from contador_lotes),
                (select count(*) from contador_propuestas),
                (select count(*) from asistente_costo_mes), (select count(*) from movimientos_banco), (select count(*) from archivos_banco),
                (select count(*) from asientos), (select count(*) from cuentas), (select count(*) from perfiles),
                (select count(*) from asistente_ajustes))
$$;

-- La foto de antes: lo que ya estaba en rojo en c2, c3, c4 y c6, y los
-- conteos.
insert into _c8 values ('conteos', pg_temp.c8_conteos());
insert into _c8 select 'rojos_c2', coalesce(string_agg(control, ', ' order by control), '') from fn_verificar_cadena() where not ok;
insert into _c8 select 'rojos_c3', coalesce(string_agg(control, ', ' order by control), '') from fn_puentes_verificar() where not ok;
insert into _c8 select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _c8 select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;


-- =====================================================================
-- La instalación y quién puede qué
-- =====================================================================

-- 1. Instalación: las 4 tablas con RLS y su única policy, la configuración
--    (modelo, esfuerzo, topes, el dueño activo), dónde se anota el gasto
--    (la vista de la app sobre asistente_uso, o una tabla), los ajustes de
--    la app, los índices únicos parciales, las 5 vistas con
--    security_invoker; nada falta (fn_contador_precondiciones nulo) y el
--    final del pegado dice sus 9 filas.
do $$
declare
  v_obt text; v_t int; v_cfg text; v_k char; v_uso text; v_aj text; v_idx int; v_v int; v_pre text; v_peg int;
begin
  begin
    perform pg_temp.c8_montar();
    select count(*) into v_t
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
       and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')
       and c.relrowsecurity
       and (select count(*) from pg_policy p where p.polrelid = c.oid) = 1
       and exists (select 1 from pg_policy p where p.polrelid = c.oid and p.polname = c.relname || '_dueno' and p.polcmd = 'r');
    select format('%s · %s · %s · hasta %s · tope %s · dueño %s', c.modelo, c.effort, case when c.activa then 'activa' else 'apagada' end,
                  c.max_por_rafaga, c.tope_mes_centavos,
                  case when exists (select 1 from perfiles p where p.id = c.dueno and p.rol = 'dueno' and coalesce(p.activo, true))
                       then 'activo' else 'MAL' end)
      into v_cfg from contador_config c where c.id = 1;
    select r.relkind into v_k from pg_class r where r.oid = to_regclass('public.asistente_costo_mes');
    v_uso := case when v_k = 'v' and (select r.relkind from pg_class r where r.oid = to_regclass('public.asistente_uso')) = 'r'
                    then 'vista sobre asistente_uso'
                  when v_k = 'r' then 'tabla' else 'MAL ' || coalesce(v_k::text, 'nada') end;
    select string_agg(a.clave || '=' || coalesce(nullif(a.valor ~ '^[0-9]+$', false)::text, 'MAL'), ' ' order by a.clave) into v_aj
      from asistente_ajustes a where a.clave in ('tope_mes_centavos', 'aviso_pct');
    select count(*) into v_idx from pg_indexes i
     where i.schemaname = 'public' and i.indexname in ('contador_reglas_patron_unico', 'contador_propuestas_una_pendiente')
       and i.indexdef ~* 'unique' and i.indexdef ~* 'where';
    select count(*) into v_v from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
       and c.relname in ('v_contador_cuentas', 'v_contador_reglas', 'v_contador_bandeja', 'v_contador_control', 'v_contador_estado')
       and coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    v_pre := coalesce(fn_contador_precondiciones(), 'nada falta');
    select count(*) into v_peg from fn_contador_pegado();
    v_obt := format('tablas %s | %s | gasto: %s | ajustes %s | índices %s | vistas %s | %s | pegado %s filas', v_t, v_cfg, v_uso, v_aj, v_idx,
                    v_v, v_pre, v_peg);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'instalación: 4 tablas cerradas, la configuración con su dueño, dónde se anota el gasto, los ajustes, los índices, las vistas, nada falta',
    'tablas 4 | claude-opus-5-5 · low · activa · hasta 20 · tope 3000 · dueño activo | gasto: vista sobre asistente_uso | ajustes aviso_pct=true tope_mes_centavos=true | índices 2 | vistas 5 | nada falta | pegado 9 filas',
    v_obt,
    v_obt in ('tablas 4 | claude-opus-5-5 · low · activa · hasta 20 · tope 3000 · dueño activo | gasto: vista sobre asistente_uso | ajustes aviso_pct=true tope_mes_centavos=true | índices 2 | vistas 5 | nada falta | pegado 9 filas',
              'tablas 4 | claude-opus-5-5 · low · activa · hasta 20 · tope 3000 · dueño activo | gasto: tabla | ajustes aviso_pct=true tope_mes_centavos=true | índices 2 | vistas 5 | nada falta | pegado 9 filas'));
end $$;

-- 2. Nadie de la API llama a c8 (ni el dueño: lo pide por la función de
--    borde); la función de borde (como postgres) sí
do $$
declare
  v_obt text; v_q text; v_c text; v_e text[]; v_res text[] := '{}'; v_srv text[] := '{}';
  c_llamadas constant text[] := array[
    'select fn_contador_tope()',
    'select fn_contador_pendientes(5)',
    'select fn_contador_reglas_aplicar(null)',
    'select fn_contador_lote_abrir(null, ''claude-opus-5-5'', ''low'', null, null, 1)',
    'select fn_contador_propuesta_guardar(gen_random_uuid(), gen_random_uuid(), null, null, ''{}''::jsonb, ''claude-opus-5-5'', ''low'', null)',
    'select fn_contador_lote_cerrar(gen_random_uuid(), ''{}''::jsonb)',
    'select fn_contador_clasificar(gen_random_uuid(), null, ''[]''::jsonb, null)',
    'select fn_contador_aprobar(gen_random_uuid(), null)',
    'select fn_contador_rechazar(gen_random_uuid(), null, ''x'')',
    'select fn_contador_caducar(gen_random_uuid(), null, ''x'')',
    'select fn_contador_regla_alta(null, ''x'', ''^X'', ''[]''::jsonb)',
    'select fn_contador_regla_baja(gen_random_uuid(), null, ''x'')',
    'select * from fn_contador_control()',
    'select fn_contador_resumen()',
    'select * from fn_contador_pegado()',
    'select fn_contador_nombre_comercio(''X'')'];
begin
  begin
    foreach v_q in array array['service_role', 'anon', 'dueno', 'equipo'] loop
      v_e := '{}';
      if v_q = 'equipo' and pg_temp.c8('equipo') is null then
        v_res := v_res || 'equipo: sin perfil (como si 42501)'::text;
        continue;
      end if;
      perform pg_temp.c8_ser(v_q);
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
    perform pg_temp.c8_ser('servicio');
    foreach v_c in array array['select fn_contador_tope()', 'select fn_contador_pendientes(5)', 'select * from fn_contador_control()',
                               'select fn_contador_resumen()', 'select * from fn_contador_pegado()'] loop
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
  insert into _pruebas values (2, 'service_role, anon, el dueño y el equipo por la API: 42501 en todo c8; la función de borde (postgres) entra',
    'service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: todas 42501 | servicio: entra', v_obt,
    v_obt in ('service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: todas 42501 | servicio: entra',
              'service_role: todas 42501 | anon: todas 42501 | dueno: todas 42501 | equipo: sin perfil (como si 42501) | servicio: entra'));
end $$;

-- 3. El catálogo: ninguna fn_contador_* SECURITY DEFINER ni en la API, cada
--    una con su comentario, nada que la API escriba en ia_*, las vistas
--    con security_invoker, ningún trigger de c8 y ningún prefijo sellado
--    (fn_banco_%, fn_puente_%, fn_estados_%, fn_stripe_%, fn_plaid_%) con
--    un comentario de c8
do $$
declare
  v_obt text; v_n int; v_def int; v_api int; v_com int; v_esc int; v_inv int; v_trg int; v_sel int;
begin
  begin
    select count(*), count(*) filter (where p.prosecdef),
           count(*) filter (where has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')
                                  or has_function_privilege('service_role', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute')),
           count(*) filter (where coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c8:%')
      into v_n, v_def, v_api, v_com
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_contador\_%';
    select count(*) into v_esc from pg_class c
     cross join (values ('anon'), ('authenticated'), ('service_role')) r(r)
     cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')
       and has_table_privilege(r.r, c.oid, q.q);
    select count(*) into v_inv from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname like 'v\_contador\_%'
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    select count(*) into v_trg from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_proc f on f.oid = t.tgfoid
     where not t.tgisinternal
       and (c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas') or f.proname like 'fn\_contador\_%' or t.tgname like '%fn\_contador\_%');
    select count(*) into v_sel from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_puente\_%' or p.proname like 'fn\_estados\_%' or p.proname like 'fn\_stripe\_%'
            or p.proname like 'fn\_plaid\_%')
       and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c8%';
    v_obt := format('funciones %s | definer %s | en la API %s | sin comentario c8 %s | la API escribe %s | vistas sin invoker %s | triggers %s | '
                    'prefijos sellados %s', case when v_n >= 30 then '30 o más' else v_n::text end, v_def, v_api, v_com, v_esc, v_inv, v_trg, v_sel);
  exception when others then
    v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'catálogo: nada SECURITY DEFINER ni en la API, cada función comentada, la API no escribe, vistas security_invoker, sin triggers ni prefijos sellados',
    'funciones 30 o más | definer 0 | en la API 0 | sin comentario c8 0 | la API escribe 0 | vistas sin invoker 0 | triggers 0 | prefijos sellados 0',
    v_obt,
    v_obt = 'funciones 30 o más | definer 0 | en la API 0 | sin comentario c8 0 | la API escribe 0 | vistas sin invoker 0 | triggers 0 | prefijos sellados 0');
end $$;

-- 4. Las vistas por rol: el dueño las lee (el estado, una fila); el equipo
--    no ve nada (RLS: ni la configuración, ni reglas, ni propuestas, ni el
--    control, que nace de la configuración); anon, ni entrar
do $$
declare
  v_obt text; v_d text; v_e text; v_a text; v_v text; v_n bigint; v_l text[] := '{}';
begin
  begin
    perform pg_temp.c8_ser('dueno');
    select count(*)::text into v_d from v_contador_estado;
    foreach v_v in array array['v_contador_control', 'v_contador_bandeja', 'v_contador_reglas', 'v_contador_cuentas'] loop
      execute format('select count(*) from public.%I', v_v) into v_n;
    end loop;
    v_d := v_d || format(', control %s filas', (select count(*) from v_contador_control));
    execute 'reset role';
    if pg_temp.c8('equipo') is not null then
      perform pg_temp.c8_ser('equipo');
      foreach v_v in array array['v_contador_estado', 'v_contador_control', 'v_contador_bandeja', 'v_contador_reglas'] loop
        execute format('select count(*) from public.%I', v_v) into v_n;
        v_l := v_l || v_n::text;
      end loop;
      v_e := array_to_string(v_l, ' ');
      execute 'reset role';
    else
      v_e := '0 0 0 0';
    end if;
    perform pg_temp.c8_ser('anon');
    begin
      select count(*)::text into v_a from v_contador_estado;
    exception when others then
      v_a := sqlstate;
    end;
    v_obt := format('dueño: estado %s, las demás se leen | equipo: %s | anon: %s', v_d, v_e, v_a);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'las vistas: el dueño sí (el control con sus 11 filas), el equipo 0 filas, anon nada',
    'dueño: estado 1, control 11 filas, las demás se leen | equipo: 0 0 0 0 | anon: 42501', v_obt,
    v_obt = 'dueño: estado 1, control 11 filas, las demás se leen | equipo: 0 0 0 0 | anon: 42501');
end $$;

-- 5. Las cuentas permitidas (v_contador_cuentas): costo, gasto, otro gasto,
--    activo que no es banco, pasivo que no es 2010 ni tarjeta, 3200 y
--    1130; nunca 6000, un banco, la caja, lo que se cobra, las de Stripe,
--    2010, una tarjeta, la mano de obra, un ingreso, el resto del
--    patrimonio; y fn_contador_cuenta_permitida dice el porqué en llano
do $$
declare
  v_obt text; v_si text; v_no text; v_pq text[] := '{}'; v_x text;
begin
  begin
    select string_agg(x, ' ' order by x) into v_si
      from unnest(array['5100', '5200', '6300', '6500', '7100', '1130', '1510', '2300', '3200', '9000']) x
     where exists (select 1 from v_contador_cuentas v where v.codigo = x);
    select coalesce(string_agg(x, ' ' order by x), 'ninguna') into v_no
      from unnest(array['1010', '1050', '1110', '1120', '1020', '1140', '2010', pg_temp.c8('tarjeta'), '5000', '5010', '6000', '6005', '6950',
                        '3000', '3900', '4010', '4900', '2100']) x
     where exists (select 1 from v_contador_cuentas v where v.codigo = x);
    foreach v_x in array array['6000', '1010', '4010', '2010', '3900', '5000', '9999', ''] loop
      v_pq := v_pq || coalesce(fn_contador_cuenta_permitida(v_x), 'permitida');
    end loop;
    v_obt := format('sí: %s | de las que no, se cuela: %s | 6000 %s | 1010 %s | 4010 %s | 2010 %s | 3900 %s | 5000 %s | 9999 %s | vacía %s | 6300 %s',
                    v_si, v_no,
                    case when v_pq[1] ~ 'sueldo' then 'sueldo' else v_pq[1] end,
                    case when v_pq[2] ~ 'banco' then 'banco' else v_pq[2] end,
                    case when v_pq[3] ~ 'ingreso' then 'ingreso' else v_pq[3] end,
                    case when v_pq[4] ~ 'proveedores' then 'proveedores' else v_pq[4] end,
                    case when v_pq[5] ~ 'patrimonio' then 'patrimonio' else v_pq[5] end,
                    case when v_pq[6] ~ 'mano de obra' then 'mano de obra' else v_pq[6] end,
                    case when v_pq[7] ~ 'no existe' then 'no existe' else v_pq[7] end,
                    case when v_pq[8] ~ 'falta' then 'falta' else v_pq[8] end,
                    coalesce(fn_contador_cuenta_permitida('6300'), 'permitida'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'las cuentas permitidas: costo, gasto, activo que no es banco, pasivo, 3200 y 1130; nunca 6000, bancos, 2010, tarjetas, mano de obra, ingresos; el porqué en llano',
    'sí: 1130 1510 2300 3200 5100 5200 6300 6500 7100 9000 | de las que no, se cuela: ninguna | 6000 sueldo | 1010 banco | 4010 ingreso | 2010 proveedores | 3900 patrimonio | 5000 mano de obra | 9999 no existe | vacía falta | 6300 permitida',
    v_obt,
    v_obt = 'sí: 1130 1510 2300 3200 5100 5200 6300 6500 7100 9000 | de las que no, se cuela: ninguna | 6000 sueldo | 1010 banco | 4010 ingreso | 2010 proveedores | 3900 patrimonio | 5000 mano de obra | 9999 no existe | vacía falta | 6300 permitida');
end $$;


-- =====================================================================
-- Lo que espera, el contexto y las reglas
-- =====================================================================

-- 6. Lo que espera y su contexto: tres cargos sembrados salen «sin_ticket»
--    y son candidatos, los más viejos primero, hasta el límite (nunca más
--    que max_por_rafaga); el contexto trae las cuentas permitidas (nunca
--    6000 ni un banco), las obras activas, la versión de las reglas y los
--    ejemplos; lo que se le da no lleva correos ni teléfonos; un cargo con
--    propuesta pendiente ya no espera
do $$
declare
  v_obt text; v_m1 uuid; v_m2 uuid; v_m3 uuid; v_p jsonb; v_a text; v_b text; v_c text; v_d text; v_l uuid;
begin
  begin
    perform pg_temp.c8_montar();
    v_m1 := pg_temp.c8_cargo('c8-t6-1', pg_temp.c8('d')::date, 87.43, 'THE HOME DEPOT 6341 OCALA FL');
    v_m2 := pg_temp.c8_cargo('c8-t6-2', pg_temp.c8('d')::date + 1, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_m3 := pg_temp.c8_cargo('c8-t6-3', pg_temp.c8('d')::date + 2, 19.99, 'NETFLIX.COM 866-579-7172 CA juan@mail.com');
    v_a := format('bandeja: %s', (select string_agg(b.motivo, ' ' order by b.fecha) from v_banco_bandeja b where b.movimiento_id in (v_m1, v_m2, v_m3)));
    v_p := fn_contador_pendientes(2);
    v_b := format('límite 2 → %s movimientos de %s', jsonb_array_length(v_p->'movimientos'),
                  case when (v_p->>'total')::int >= 3 then '3 o más' else v_p->>'total' end);
    -- (la lista entera: los más viejos primero, y los tres sembrados en su orden)
    v_p := fn_contador_pendientes(20);
    v_b := v_b || format(' | orden %s, los tres %s | límite 99 → %s | movimiento con {%s}',
                         case when (select coalesce(bool_and(z.f <= z.sig), true)
                                      from (select (x->>'fecha')::date as f, lead((x->>'fecha')::date) over (order by o) as sig
                                              from jsonb_array_elements(v_p->'movimientos') with ordinality as t(x, o)) z) then 'bien' else 'MAL' end,
                         case when (select string_agg(case when (x->>'movimiento_id')::uuid = v_m1 then '1' when (x->>'movimiento_id')::uuid = v_m2 then '2'
                                                           else '3' end, '' order by o)
                                      from jsonb_array_elements(v_p->'movimientos') with ordinality as t(x, o)
                                     where (x->>'movimiento_id')::uuid in (v_m1, v_m2, v_m3)) = '123' then 'en su orden' else 'DESORDENADOS' end,
                         (fn_contador_pendientes(99)->>'limite'),
                         (select string_agg(k, ',' order by k) from jsonb_array_elements(v_p->'movimientos') x
                           cross join lateral jsonb_object_keys(x) k where (x->>'movimiento_id')::uuid = v_m1));
    v_c := format('cuentas %s (6000 %s, 1010 %s, 5100 %s con regla_obra %s) · obras %s (%s) · reglas_version %s · ejemplos %s',
                  jsonb_array_length(v_p->'contexto'->'cuentas'),
                  case when v_p->'contexto'->'cuentas' @> '[{"codigo": "6000"}]' then 'SÍ' else 'no' end,
                  case when v_p->'contexto'->'cuentas' @> '[{"codigo": "1010"}]' then 'SÍ' else 'no' end,
                  case when v_p->'contexto'->'cuentas' @> '[{"codigo": "5100"}]' then 'sí' else 'NO' end,
                  (select x->>'regla_obra' from jsonb_array_elements(v_p->'contexto'->'cuentas') x where x->>'codigo' = '5100'),
                  jsonb_array_length(v_p->'contexto'->'proyectos'),
                  case when jsonb_array_length(v_p->'contexto'->'proyectos') = (select count(*) from proyectos p where p.estado in ('aprobado', 'ejecucion', 'pausa'))
                            and v_p->'contexto'->'proyectos' @> jsonb_build_array(jsonb_build_object('id', pg_temp.c8('obra')))
                       then 'las activas' else 'OTRAS' end,
                  case when length(v_p->'contexto'->>'reglas_version') = 32 then 'md5' else 'MAL' end,
                  case when jsonb_typeof(v_p->'contexto'->'ejemplos') = 'array' and jsonb_array_length(v_p->'contexto'->'ejemplos') <= 30
                       then 'lista de 30 o menos' else 'MAL' end);
    -- lo que se le da: sin correo ni teléfono (el de Netflix: en la
    -- descripción tal cual se tapan los dos; en desc_norm c6 ya deshizo el
    -- correo —«JUAN MAIL COM», que la máscara de la cruda no reconoce— y c8
    -- lo vuelve a tapar por la descripción cruda, y el teléfono también), y
    -- con el número de la tienda
    v_d := format('netflix: %s | home depot: %s',
                  (select case when x->>'descripcion' ~ '\[correo\]' and x->>'descripcion' ~ '\[teléfono\]' and x->>'descripcion' !~ 'juan@|866'
                                    and x->>'desc_norm' = 'NETFLIX COM [teléfono] CA [correo]'
                               then 'sin correo ni teléfono (también en desc_norm)' else x->>'descripcion' || ' / ' || (x->>'desc_norm') end
                     from jsonb_array_elements(v_p->'movimientos') x where (x->>'movimiento_id')::uuid = v_m3),
                  (select case when x->>'desc_norm' = 'THE HOME DEPOT 6341 OCALA FL' then 'con su número de tienda' else x->>'desc_norm' end
                     from jsonb_array_elements(v_p->'movimientos') x where (x->>'movimiento_id')::uuid = v_m1));
    -- con una propuesta pendiente, ya no espera
    v_l := pg_temp.c8_lote(1);
    perform pg_temp.c8_ia(v_m2, v_l, '[{"cuenta": "6300"}]', 'WAWA es una gasolinera: combustible', 0.9);
    v_d := v_d || format(' | con propuesta: %s', case when exists (select 1 from fn_contador_candidatos() c where c.movimiento_id = v_m2)
                                                     then 'SIGUE' else 'ya no espera' end);
    v_obt := format('%s | %s | %s | %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'lo que espera y su contexto: sin_ticket, los más viejos primero hasta el límite, cuentas (nunca 6000 ni bancos), obras, reglas_version, ejemplos, sin datos personales',
    'bandeja: sin_ticket sin_ticket sin_ticket | límite 2 → 2 movimientos de 3 o más | orden bien, los tres en su orden | límite 99 → 20 | movimiento con {cuenta,cuenta_nombre,desc_norm,descripcion,dias,fecha,monto,motivo,movimiento_id,tipo_banco} | cuentas <n> (6000 no, 1010 no, 5100 sí con regla_obra obligatoria) · obras <n> (las activas) · reglas_version md5 · ejemplos lista de 30 o menos | netflix: sin correo ni teléfono (también en desc_norm) | home depot: con su número de tienda | con propuesta: ya no espera',
    v_obt,
    v_obt ~ ('^bandeja: sin_ticket sin_ticket sin_ticket \| límite 2 → 2 movimientos de 3 o más \| orden bien, los tres en su orden \| límite 99 → 20 \| '
             'movimiento con \{cuenta,cuenta_nombre,desc_norm,descripcion,dias,fecha,monto,motivo,movimiento_id,tipo_banco\} \| '
             'cuentas [0-9]+ \(6000 no, 1010 no, 5100 sí con regla_obra obligatoria\) · obras [0-9]+ \(las activas\) · reglas_version md5 · '
             'ejemplos lista de 30 o menos \| netflix: sin correo ni teléfono \(también en desc_norm\) \| home depot: con su número de tienda \| '
             'con propuesta: ya no espera$'));
end $$;

-- 7. Las reglas antes que la IA: la que casa deja su propuesta (confianza 1,
--    «Regla: …», regla_id, veces y última vez); la más específica gana; un
--    empate no decide; la de una cuenta del banco no vale en otra; una
--    rechazada no se repite para ese movimiento (pasa a la IA); una regla
--    cuya cuenta ya no se puede proponer no se aplica y se nombra
do $$
declare
  v_obt text; v_m1 uuid; v_m2 uuid; v_m3 uuid; v_m4 uuid; v_r jsonb; v_a text; v_b text; v_c text; v_d text; v_e text; v_corta uuid; v_larga uuid;
  v_w1 uuid; v_w2 uuid; v_pr contador_propuestas;
begin
  begin
    perform pg_temp.c8_montar();
    -- (comercios que no existen, para que ningún cargo real de la bandeja
    -- case con estas reglas: lo que se cuenta es solo lo de la prueba)
    v_m1 := pg_temp.c8_cargo('c8-t7-1', pg_temp.c8('d')::date, 45.00, 'PRUEBA C8 SHELL OIL 57544 OCALA FL');
    v_m2 := pg_temp.c8_cargo('c8-t7-2', pg_temp.c8('d')::date, 61.20, 'PRUEBA C8 WAWA 5234 BELLEVIEW FL');
    v_m3 := pg_temp.c8_cargo('c8-t7-3', pg_temp.c8('d')::date + 1, 171.98, 'PRUEBA C8 CES 1040 TAMPA FL');
    v_m4 := pg_temp.c8_cargo('c8-t7-4', pg_temp.c8('d')::date + 1, 13.99, 'PRUEBA C8 NFPA NATL FIRE PROTE MA');
    v_corta := (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Shell (corta)', '^PRUEBA C8 SHELL', '[{"cuenta": "6350"}]')->>'id')::uuid;
    v_larga := (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Shell (larga)', '^PRUEBA C8 SHELL OIL', '[{"cuenta": "6300"}]')->>'id')::uuid;
    v_w1 := (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Wawa uno', '^PRUEBA C8 WAWA', '[{"cuenta": "6300"}]')->>'id')::uuid;
    v_w2 := (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Wawa dos', '^PRUEBA C8 WAW.', '[{"cuenta": "6350"}]')->>'id')::uuid;
    -- CES: solo en la tarjeta, no en el banco
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'CES (tarjeta)', '^PRUEBA C8 CES ', '[{"cuenta": "5100"}]', pg_temp.c8('tarjeta'));
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'NFPA', '^PRUEBA C8 NFPA', '[{"cuenta": "6800"}]');
    v_r := fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_pr := pg_temp.c8_ultima('c8-t7-1');
    v_a := format('propuestas %s | shell: %s por %s, confianza %s, «%s», pide_obra %s',
                  (select count(*) from contador_propuestas q where q.movimiento_id in (v_m1, v_m2, v_m3, v_m4) and q.estado = 'pendiente'), v_pr.estado,
                  case when v_pr.regla_id = v_larga then 'la larga' when v_pr.regla_id = v_corta then 'LA CORTA' else 'otra' end,
                  v_pr.propuesta->>'confianza', v_pr.propuesta->>'motivo', coalesce(v_pr.propuesta->'flags'->>'pide_obra', 'no'));
    v_b := format('wawa (empate): %s | ces en el banco: %s | nfpa: %s',
                  case when pg_temp.c8_prop('c8-t7-2') is null then 'ninguna' else 'PROPUSO' end,
                  case when pg_temp.c8_prop('c8-t7-3') is null then 'ninguna' else 'PROPUSO' end,
                  coalesce((select p.propuesta->>'motivo' from contador_propuestas p where p.id = pg_temp.c8_prop('c8-t7-4')), 'NINGUNA'));
    v_c := format('veces: larga %s, corta %s, última vez %s',
                  (select r.veces from contador_reglas r where r.id = v_larga), (select r.veces from contador_reglas r where r.id = v_corta),
                  case when (select r.ultima_vez is not null from contador_reglas r where r.id = v_larga) then 'puesta' else 'MAL' end);
    -- otra vez: nada nuevo (ya tienen propuesta pendiente)
    v_r := fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_c := v_c || format(' | otra vez: %s nuevas', (select count(*) from contador_propuestas q where q.movimiento_id in (v_m1, v_m2, v_m3, v_m4)) - 2);
    -- rechazada: no se repite, y el movimiento vuelve a esperar (a la IA)
    perform fn_contador_rechazar(pg_temp.c8_prop('c8-t7-1'), pg_temp.c8('dueno')::uuid, 'c8-pruebas: no es eso');
    v_r := fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_d := format('rechazada: %s nuevas, shell %s', (select count(*) from contador_propuestas q where q.movimiento_id in (v_m1, v_m2, v_m3, v_m4)) - 2,
                  case when pg_temp.c8_prop('c8-t7-1') is null and exists (select 1 from fn_contador_candidatos() c where c.movimiento_id = v_m1)
                       then 'espera a la IA' else 'MAL' end);
    -- el empate se rompe dando de baja una: la otra propone
    perform fn_contador_regla_baja(v_w2, pg_temp.c8('dueno')::uuid, 'c8-pruebas: sobraba');
    v_r := fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_d := v_d || format(' | sin empate: wawa %s', coalesce((select p.propuesta->>'motivo' from contador_propuestas p where p.id = pg_temp.c8_prop('c8-t7-2')), 'NINGUNA'));
    -- una regla rota (su cuenta ya no se propone): no se aplica, y se nombra
    perform fn_contador_rechazar(pg_temp.c8_prop('c8-t7-4'), pg_temp.c8('dueno')::uuid, 'c8-pruebas: para volver a probar');
    update cuentas set activa = false where codigo = '6800';
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'NFPA bis', '^PRUEBA C8 NFPA NATL', '[{"cuenta": "6350"}]');
    update contador_reglas set lineas = '[{"cuenta": "6800"}]' where nombre = 'NFPA bis';
    v_r := fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_e := format('rota: %s, nfpa %s', v_r->'reglas_rotas', case when pg_temp.c8_prop('c8-t7-4') is null then 'sin propuesta' else 'PROPUSO' end);
    v_obt := format('%s | %s | %s | %s | %s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'las reglas antes que la IA: casa (confianza 1), la más específica gana, el empate no decide, la cuenta del banco, una rechazada no se repite, una rota no se aplica',
    'propuestas 2 | shell: pendiente por la larga, confianza 1, «Regla: Shell (larga)», pide_obra no | wawa (empate): ninguna | ces en el banco: ninguna | nfpa: Regla: NFPA | veces: larga 1, corta 0, última vez puesta | otra vez: 0 nuevas | rechazada: 0 nuevas, shell espera a la IA | sin empate: wawa Regla: Wawa uno | rota: ["NFPA bis"], nfpa sin propuesta',
    v_obt,
    v_obt = 'propuestas 2 | shell: pendiente por la larga, confianza 1, «Regla: Shell (larga)», pide_obra no | wawa (empate): ninguna | ces en el banco: ninguna | nfpa: Regla: NFPA | veces: larga 1, corta 0, última vez puesta | otra vez: 0 nuevas | rechazada: 0 nuevas, shell espera a la IA | sin empate: wawa Regla: Wawa uno | rota: ["NFPA bis"], nfpa sin propuesta');
end $$;

-- 8. Las partes: una regla de dos líneas (la cuota del préstamo: capital e
--    interés, mitad y mitad) deja una propuesta con el monto de cada parte
--    (la última absorbe el redondeo) y, aprobada, su asiento de c6 lleva las
--    dos líneas al centavo; la regla aprendida de una aprobación con dos
--    líneas guarda sus partes
do $$
declare
  v_obt text; v_m uuid; v_pr contador_propuestas; v_r jsonb; v_a text; v_b text; v_c text; v_m2 uuid;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_sin_reglas('ALLY|FORD');
    v_m := pg_temp.c8_cargo('c8-t8-1', pg_temp.c8('d')::date, 333.33, 'ALLY PAYMENT 112233 PPD');
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Ally (camioneta)', '^ALLY PAYMENT',
                                   '[{"cuenta": "2540", "parte": "0.5"}, {"cuenta": "7100", "parte": "0.5"}]');
    perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_pr := pg_temp.c8_ultima('c8-t8-1');
    v_a := format('propuesta: %s', (select string_agg((x->>'cuenta') || ' ' || (x->>'monto'), ' + ') from jsonb_array_elements(v_pr.propuesta->'lineas') x));
    v_r := fn_contador_aprobar(v_pr.id, pg_temp.c8('dueno')::uuid, null, false);
    v_b := format('%s, asiento: %s', v_r->>'estado', pg_temp.c8_lineas((v_r->>'asiento_id')::uuid));
    -- aprendida de una aprobación con dos líneas (otro comercio): las partes
    v_m2 := pg_temp.c8_cargo('c8-t8-2', pg_temp.c8('d')::date, 100.00, 'FORD CREDIT 998877 PPD');
    v_r := fn_contador_clasificar(v_m2, pg_temp.c8('dueno')::uuid, '[{"cuenta": "2520", "monto": "80.00"}, {"cuenta": "7100", "monto": "20.00"}]',
                                  'c8-pruebas: la cuota del camión', true);
    v_c := format('aprendida: %s → %s', v_r->'regla'->>'nombre',
                  (select string_agg((x->>'cuenta') || ' ' || (x->>'parte'), ' + ') from jsonb_array_elements(
                     (select r.lineas from contador_reglas r where r.id = (v_r->'regla'->>'regla')::uuid)) x));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'las partes: la regla de dos líneas reparte el monto (la última absorbe el redondeo), su asiento lleva las dos; la aprendida guarda sus partes',
    'propuesta: 2540 166.67 + 7100 166.66 | aprobada, asiento: 1010 -333.33 | 2540 166.67 | 7100 166.66 | aprendida: FORD CREDIT → 2520 0.8000 + 7100 0.2000',
    v_obt,
    v_obt = 'propuesta: 2540 166.67 + 7100 166.66 | aprobada, asiento: 1010 -333.33 | 2540 166.67 | 7100 166.66 | aprendida: FORD CREDIT → 2520 0.8000 + 7100 0.2000');
end $$;

-- 9. El tope de gasto (la tercera regla): con el gasto del contador en su
--    tope, bloqueado (y dice por qué); con el de TODA la IA en el tope de la
--    app, bloqueado; con el contador apagado, bloqueado; y una ráfaga no se
--    abre (MX008) sin gastar un token. Al día, no bloqueado (y el estado
--    lo dice igual).
do $$
declare
  v_obt text; v_t jsonb; v_a text; v_b text; v_c text; v_d text; v_e text; v_k char;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_al_dia();
    v_t := fn_contador_tope();
    v_a := format('al día: bloqueado %s, mes %s, estado %s', v_t->>'bloqueado', case when v_t->>'mes' = to_char(pg_temp.c8('hoy')::date, 'YYYY-MM') then 'el de hoy' else 'OTRO' end,
                  (select case when not e.bloqueado then 'no bloqueado' else 'MAL' end from v_contador_estado e));
    -- el propio: el contador ya gastó más que su tope
    update contador_config set tope_mes_centavos = 1 where id = 1;
    select r.relkind into v_k from pg_class r where r.oid = to_regclass('public.asistente_costo_mes');
    if v_k = 'v' then
      insert into asistente_uso (usuario_id, rol, modelo, entrada, salida, vueltas, accion, costo_centavos, resultado)
      values (pg_temp.c8('dueno')::uuid, 'dueno', 'claude-opus-5-5', 1000, 100, 1, 'contador_categorizar', 5, 'c8-pruebas');
    else
      insert into asistente_costo_mes (mes, accion, llamadas, centavos) values (to_char(pg_temp.c8('hoy')::date, 'YYYY-MM'), 'contador_categorizar', 1, 5)
      on conflict (mes, accion) do update set centavos = asistente_costo_mes.centavos + 5;
    end if;
    v_t := fn_contador_tope();
    v_b := format('propio: bloqueado %s, %s, estado %s', v_t->>'bloqueado',
                  case when v_t->>'motivo' ~ 'contador de este mes.*su tope' then 'dice su tope' else v_t->>'motivo' end,
                  (select e.bloqueado_motivo from v_contador_estado e));
    begin
      perform pg_temp.c8_lote(1);
      v_c := 'la ráfaga ENTRÓ';
    exception when others then
      v_c := format('ráfaga: %s %s', sqlstate, case when sqlerrm ~ '^No se abre la ráfaga' then 'no se abre' else sqlerrm end);
    end;
    update contador_config set tope_mes_centavos = 1000000 where id = 1;
    -- el de la app: toda la IA del mes contra asistente_ajustes
    update asistente_ajustes set valor = '1' where clave = 'tope_mes_centavos';
    v_t := fn_contador_tope();
    v_d := format('app: bloqueado %s, %s, estado %s', v_t->>'bloqueado',
                  case when v_t->>'motivo' ~ 'tope de la app' then 'dice el de la app' else v_t->>'motivo' end,
                  (select e.bloqueado_motivo from v_contador_estado e));
    update asistente_ajustes set valor = '1000000' where clave = 'tope_mes_centavos';
    -- apagado
    update contador_config set activa = false where id = 1;
    v_t := fn_contador_tope();
    v_e := format('apagado: bloqueado %s, %s, estado %s', v_t->>'bloqueado',
                  case when v_t->>'motivo' ~ 'apagado' then 'dice apagado' else v_t->>'motivo' end,
                  (select e.bloqueado_motivo from v_contador_estado e));
    update contador_config set activa = true where id = 1;
    v_t := fn_contador_tope();
    v_e := v_e || format(' | otra vez al día: bloqueado %s', v_t->>'bloqueado');
    v_obt := format('%s | %s | %s | %s | %s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'el tope: el propio del contador, el de la app y el interruptor bloquean (y dicen por qué); la ráfaga no se abre',
    'al día: bloqueado false, mes el de hoy, estado no bloqueado | propio: bloqueado true, dice su tope, estado tope del contador | ráfaga: MX008 no se abre | app: bloqueado true, dice el de la app, estado tope de la app | apagado: bloqueado true, dice apagado, estado apagado | otra vez al día: bloqueado false',
    v_obt,
    v_obt = 'al día: bloqueado false, mes el de hoy, estado no bloqueado | propio: bloqueado true, dice su tope, estado tope del contador | ráfaga: MX008 no se abre | app: bloqueado true, dice el de la app, estado tope de la app | apagado: bloqueado true, dice apagado, estado apagado | otra vez al día: bloqueado false');
end $$;

-- 10. Las ráfagas (lotes): solo Opus y Fable (ni Haiku ni Sonnet), el
--     esfuerzo conocido, hasta max_por_rafaga; cerrar calcula los centavos
--     al precio de claude-opus-5-5 (entrada 400, caché creado 500, caché
--     leído 20, salida 2000 por millón), anota el gasto del mes donde la
--     app lo lee (asistente_costo_mes sube, con su fila en asistente_uso) y
--     guarda en contador_config la versión del prompt, el prefijo y la hora; una
--     ráfaga no se cierra dos veces; un uso que no es entero no entra; con
--     una ráfaga en marcha no se abre otra (MX008)
do $$
declare
  v_obt text; v_x text; v_a text[] := '{}'; v_l uuid; v_r jsonb; v_antes bigint; v_antes_n bigint; v_b text; v_c text; v_d text; v_k char;
  v_mes text := to_char(pg_temp.c8('hoy')::date, 'YYYY-MM');
begin
  begin
    perform pg_temp.c8_montar();
    foreach v_x in array array['claude-haiku-4-5', 'claude-sonnet-5-5', 'gpt-5', 'claude-opus-5-5-sonnet', 'claude-fable-5-1'] loop
      begin
        v_l := fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, v_x, 'low', null, null, 1);
        v_a := v_a || 'entra'::text;
        -- (la base no abre otra mientras esta siga abierta: se cierra sin uso)
        perform fn_contador_lote_cerrar(v_l, '{}'::jsonb);
      exception when others then
        v_a := v_a || sqlstate::text;
      end;
    end loop;
    begin
      perform fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'turbo', null, null, 1);
      v_a := v_a || 'entra'::text;
    exception when others then v_a := v_a || sqlstate::text;
    end;
    begin
      perform fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'low', null, null, 21);
      v_a := v_a || 'entra'::text;
    exception when others then v_a := v_a || sqlstate::text;
    end;
    select coalesce(sum(x.centavos), 0), coalesce(sum(x.llamadas), 0) into v_antes, v_antes_n
      from asistente_costo_mes x where x.mes = v_mes and x.accion = 'contador_categorizar';
    v_l := fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'low', 'pv-c8-pruebas', 'ph-c8-pruebas', 3);
    v_r := fn_contador_lote_cerrar(v_l, '{"input": 1000000, "output": 100000, "cache_creacion": 200000, "cache_lectura": 3000000}');
    select r.relkind into v_k from pg_class r where r.oid = to_regclass('public.asistente_costo_mes');
    v_b := format('centavos %s (= 400 + 100 + 60 + 200) | gasto del mes: +%s centavos, +%s llamada(s), anotado en %s', v_r->>'centavos',
                  (select coalesce(sum(x.centavos), 0) from asistente_costo_mes x where x.mes = v_mes and x.accion = 'contador_categorizar') - v_antes,
                  (select coalesce(sum(x.llamadas), 0) from asistente_costo_mes x where x.mes = v_mes and x.accion = 'contador_categorizar') - v_antes_n,
                  v_r->>'anotado_en');
    if v_k = 'v' then
      v_b := v_b || format(' | asistente_uso: %s', (select format('%s · %s · %s · entrada %s · salida %s · leído %s · escrito %s · vueltas %s · %s · %s',
                                                                   u.accion, u.modelo, u.rol, u.entrada, u.salida, u.cache_lectura, u.cache_escritura,
                                                                   u.vueltas, u.costo_centavos, case when u.usuario_id = pg_temp.c8('dueno')::uuid then 'del dueño' else 'MAL' end)
                                                      from asistente_uso u order by u.id desc limit 1));
    else
      v_b := v_b || ' | asistente_uso: (asistente_costo_mes es una tabla aquí)';
    end if;
    v_c := format('contador_config: %s', (select format('pv %s · ph %s · ráfaga %s · error %s', c.prompt_version, c.prefijo_hash,
                                                   case when c.ultima_rafaga_el is not null then 'puesta' else 'MAL' end, coalesce(c.ultimo_error, 'ninguno'))
                                      from contador_config c where c.id = 1));
    begin
      perform fn_contador_lote_cerrar(v_l, '{"input": 1}');
      v_d := 'cerró DOS VECES';
    exception when others then v_d := format('dos veces: %s', sqlstate);
    end;
    v_l := fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'low', null, null, 1);
    -- (con esta abierta, otra no entra: dos «Proponer» a la vez pagarían dos veces)
    begin
      perform fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'low', null, null, 1);
      v_d := v_d || ' | dos a la vez: ENTRÓ';
    exception when others then
      v_d := v_d || format(' | dos a la vez: %s (%s)', sqlstate, case when sqlerrm ~ '^Ya hay una ráfaga en marcha .*espera' then 'en marcha' else sqlerrm end);
    end;
    begin
      perform fn_contador_lote_cerrar(v_l, '{"input": "mil"}');
      v_d := v_d || ' | uso mal: ENTRÓ';
    exception when others then v_d := v_d || format(' | uso mal: %s', sqlstate);
    end;
    v_r := fn_contador_lote_cerrar(v_l, '{}');
    v_d := v_d || format(' | sin uso: %s centavos', v_r->>'centavos');
    v_obt := format('modelos: %s | %s | %s | %s', array_to_string(v_a, ' '), v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'las ráfagas: solo Opus y Fable, el esfuerzo, hasta max_por_rafaga; cerrar calcula los centavos, anota el gasto del mes y guarda en contador_config; no se cierra dos veces; una sola a la vez',
    'modelos: 22023 22023 22023 22023 entra 22023 22023 | centavos 760 (= 400 + 100 + 60 + 200) | gasto del mes: +760 centavos, +1 llamada(s), anotado en asistente_uso | asistente_uso: contador_categorizar · claude-opus-5-5 · dueno · entrada 1000000 · salida 100000 · leído 3000000 · escrito 200000 · vueltas 3 · 760 · del dueño | contador_config: pv pv-c8-pruebas · ph ph-c8-pruebas · ráfaga puesta · error ninguno | dos veces: MX008 | dos a la vez: MX008 (en marcha) | uso mal: 22023 | sin uso: 0 centavos',
    v_obt,
    v_obt in ('modelos: 22023 22023 22023 22023 entra 22023 22023 | centavos 760 (= 400 + 100 + 60 + 200) | gasto del mes: +760 centavos, +1 llamada(s), anotado en asistente_uso | asistente_uso: contador_categorizar · claude-opus-5-5 · dueno · entrada 1000000 · salida 100000 · leído 3000000 · escrito 200000 · vueltas 3 · 760 · del dueño | contador_config: pv pv-c8-pruebas · ph ph-c8-pruebas · ráfaga puesta · error ninguno | dos veces: MX008 | dos a la vez: MX008 (en marcha) | uso mal: 22023 | sin uso: 0 centavos',
              'modelos: 22023 22023 22023 22023 entra 22023 22023 | centavos 760 (= 400 + 100 + 60 + 200) | gasto del mes: +760 centavos, +3 llamada(s), anotado en asistente_costo_mes | asistente_uso: (asistente_costo_mes es una tabla aquí) | contador_config: pv pv-c8-pruebas · ph ph-c8-pruebas · ráfaga puesta · error ninguno | dos veces: MX008 | dos a la vez: MX008 (en marcha) | uso mal: 22023 | sin uso: 0 centavos'));
end $$;


-- =====================================================================
-- Lo que contesta la IA, y lo que hace Edgar con ello
-- =====================================================================

-- 11. Una respuesta válida se guarda: pendiente, fuente «ia», de su ráfaga
--     y con su modelo, esfuerzo y versión del prompt; la propuesta
--     normalizada (la confianza a 3 decimales, el motivo recortado, los
--     flags conocidos y pide_obra puesto por la base según las cuentas, no
--     por la IA); las alternativas a cuentas que no se proponen se quitan
--     (y se dice cuántas); lo que se le dio (entrada) queda congelado sin
--     correos ni teléfonos, y con el sello de la trazabilidad (prompt_version,
--     prefijo_hash, reglas_version) entero aunque traiga tiras de ocho
--     dígitos o más dentro del hex; lo que contestó (salida) tal cual
do $$
declare
  v_obt text; v_m uuid; v_l uuid; v_r jsonb; p contador_propuestas; v_a text; v_b text; v_c text;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t11-1', pg_temp.c8('d')::date, 87.43, 'THE HOME DEPOT 6341 OCALA FL');
    v_l := pg_temp.c8_lote(1);
    v_r := fn_contador_propuesta_guardar(v_m, v_l,
             jsonb_build_object('movimiento', jsonb_build_object('desc_norm', 'THE HOME DEPOT 6341 OCALA FL', 'memo', 'tel 352-555-1234 juan@mail.com'),
                                'proyectos', jsonb_build_array(pg_temp.c8('obra')), 'reglas_version', '9b808f0013a56fdb9b7f8bf12345678b',
                                'prefijo_hash', 'bf5998663c555f49375d52ee71fd08779266e39e1d9072e95809f711410a6ec6',
                                'prompt_version', '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff'),
             '{"id": "msg_01", "stop_reason": "end_turn", "content": [{"type": "text", "text": "{...}"}]}'::jsonb,
             jsonb_build_object('lineas', '[{"cuenta": "5100"}]'::jsonb, 'motivo', '  Home Depot es material de obra: va a 5100 y pide la obra  ',
                                'confianza', 0.91234, 'flags', '{"pide_obra": false, "capitalizable": false, "use_tax": true}'::jsonb,
                                'alternativas', '[{"cuenta": "6400", "motivo": "herramienta menor"}, {"cuenta": "6000", "motivo": "no vale"}, {"cuenta": "1010", "motivo": "tampoco"}]'::jsonb),
             'claude-opus-5-5', 'low', 'pv-c8-pruebas');
    select * into p from contador_propuestas where id = (v_r->>'propuesta')::uuid;
    v_a := format('%s %s de la ráfaga %s, %s/%s/%s, pide_obra %s, alternativas fuera %s', p.estado, p.fuente,
                  case when p.lote_id = v_l then 'sí' else 'NO' end, p.modelo, p.effort, p.prompt_version, v_r->>'pide_obra', v_r->>'alternativas_fuera');
    v_b := format('propuesta: %s', p.propuesta::text);
    v_c := format('entrada: %s | salida: %s',
                  case when p.entrada::text !~ '352|juan|número' and p.entrada->'movimiento'->>'memo' = 'tel [teléfono] [correo]'
                            and p.entrada->>'reglas_version' = '9b808f0013a56fdb9b7f8bf12345678b'
                            and p.entrada->>'prefijo_hash' = 'bf5998663c555f49375d52ee71fd08779266e39e1d9072e95809f711410a6ec6'
                            and p.entrada->>'prompt_version' = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff'
                       then 'sin teléfono ni correo, con su sello entero' else p.entrada::text end,
                  case when p.salida->>'stop_reason' = 'end_turn' then 'tal cual' else 'MAL' end);
    v_c := v_c || format(' | bandeja: %s', (select format('%s · %s · %s · %s · pide_obra %s', b.fuente, b.resumen, b.confianza, b.flags::text, b.pide_obra::text)
                                              from v_contador_bandeja b where b.propuesta_id = p.id));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'una respuesta válida se guarda: pendiente, de su ráfaga, normalizada, pide_obra lo pone la base, alternativas filtradas, entrada sin datos personales y con su sello entero, salida tal cual',
    'pendiente ia de la ráfaga sí, claude-opus-5-5/low/pv-c8-pruebas, pide_obra true, alternativas fuera 2 | propuesta: {"flags": {"use_tax": true, "pide_obra": true, "capitalizable": false}, "lineas": [{"cuenta": "5100"}], "motivo": "Home Depot es material de obra: va a 5100 y pide la obra", "confianza": 0.912, "alternativas": [{"cuenta": "6400", "motivo": "herramienta menor"}]} | entrada: sin teléfono ni correo, con su sello entero | salida: tal cual | bandeja: ia · 5100 Material · 0.912 · {"use_tax": true, "pide_obra": true, "capitalizable": false} · pide_obra true',
    v_obt,
    v_obt = 'pendiente ia de la ráfaga sí, claude-opus-5-5/low/pv-c8-pruebas, pide_obra true, alternativas fuera 2 | propuesta: {"flags": {"use_tax": true, "pide_obra": true, "capitalizable": false}, "lineas": [{"cuenta": "5100"}], "motivo": "Home Depot es material de obra: va a 5100 y pide la obra", "confianza": 0.912, "alternativas": [{"cuenta": "6400", "motivo": "herramienta menor"}]} | entrada: sin teléfono ni correo, con su sello entero | salida: tal cual | bandeja: ia · 5100 Material · 0.912 · {"use_tax": true, "pide_obra": true, "capitalizable": false} · pide_obra true');
end $$;

-- 12. Lo que no vale NO se guarda, y se dice por qué: una cuenta que no
--     se propone (6000, un banco, inexistente), 6 líneas, sin motivo, la
--     confianza fuera de 0..1, flags desconocidos, una obra que no existe,
--     una obra en una cuenta que no la lleva, montos que no suman, claves
--     que no se conocen, un movimiento que ya no está pendiente; nada queda
do $$
declare
  v_obt text; v_m uuid; v_l uuid; v_n0 bigint; v_res text[] := '{}'; v_r jsonb; v_casos jsonb; v_c jsonb;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t12-1', pg_temp.c8('d')::date, 100.00, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(1);
    v_n0 := (select count(*) from contador_propuestas);
    v_casos := jsonb_build_array(
      '{"lineas": [{"cuenta": "6000"}], "motivo": "sueldo", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "1010"}], "motivo": "banco", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "9999"}], "motivo": "no existe", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300", "monto": "20"}, {"cuenta": "6300", "monto": "20"}, {"cuenta": "6300", "monto": "20"}, {"cuenta": "6300", "monto": "20"}, {"cuenta": "6300", "monto": "10"}, {"cuenta": "6300", "monto": "10"}], "motivo": "seis líneas", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300"}], "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300"}], "motivo": "mucha confianza", "confianza": 1.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300"}], "motivo": "flags raros", "confianza": 0.5, "flags": {"postear": true}}'::jsonb,
      '{"lineas": [{"cuenta": "5100", "proyecto_id": "obra-que-no-existe"}], "motivo": "obra inventada", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300", "proyecto_id": "OBRA"}], "motivo": "obra donde no va", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300", "monto": "60.00"}, {"cuenta": "6350", "monto": "30.00"}], "motivo": "no suman", "confianza": 0.5}'::jsonb,
      '{"lineas": [{"cuenta": "6300"}], "motivo": "clave rara", "confianza": 0.5, "postear": true}'::jsonb,
      '{"lineas": [{"cuenta": "6300", "asiento": "x"}], "motivo": "clave rara en la línea", "confianza": 0.5}'::jsonb,
      '{"lineas": [], "motivo": "sin líneas", "confianza": 0.5}'::jsonb);
    for v_c in select value from jsonb_array_elements(v_casos) loop
      v_c := replace(v_c::text, '"OBRA"', to_jsonb(pg_temp.c8('obra'))::text)::jsonb;
      v_r := fn_contador_propuesta_guardar(v_m, v_l, '{}'::jsonb, '{}'::jsonb, v_c, 'claude-opus-5-5', 'low', 'pv');
      v_res := v_res || coalesce(v_r->>'codigo', 'GUARDÓ');
    end loop;
    -- un modelo que no es Opus ni Fable, aunque la propuesta valga: no se guarda nada (22023)
    begin
      perform fn_contador_propuesta_guardar(v_m, v_l, '{}'::jsonb, '{}'::jsonb, '{"lineas": [{"cuenta": "6300"}], "motivo": "combustible", "confianza": 0.5}',
                                            'claude-sonnet-5-5', 'low', 'pv');
      v_res := v_res || 'GUARDÓ'::text;
    exception when others then v_res := v_res || sqlstate::text;
    end;
    -- un movimiento que ya no está pendiente (se clasificó)
    perform fn_contador_clasificar(v_m, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', 'c8-pruebas', false);
    v_r := fn_contador_propuesta_guardar(v_m, v_l, '{}'::jsonb, '{}'::jsonb, '{"lineas": [{"cuenta": "6300"}], "motivo": "combustible", "confianza": 0.5}',
                                         'claude-opus-5-5', 'low', 'pv');
    v_res := v_res || (coalesce(v_r->>'codigo', 'GUARDÓ') || case when v_r->>'error' ~ 'ya no está pendiente' then ' (ya no está pendiente)' else '' end);
    v_obt := array_to_string(v_res, ' ') || format(' | guardadas %s (la de Edgar al clasificar)', (select count(*) from contador_propuestas) - v_n0);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'lo que no vale no se guarda y dice por qué: cuentas prohibidas, 6 líneas, sin motivo, confianza, flags, obras, montos, claves, modelo, movimiento ya clasificado',
    'MX004 MX004 MX004 22023 22023 22023 22023 MX006 MX006 MX001 22023 22023 22023 22023 MX008 (ya no está pendiente) | guardadas 1 (la de Edgar al clasificar)',
    v_obt,
    v_obt = 'MX004 MX004 MX004 22023 22023 22023 22023 MX006 MX006 MX001 22023 22023 22023 22023 MX008 (ya no está pendiente) | guardadas 1 (la de Edgar al clasificar)');
end $$;

-- 13. La pendiente anterior del mismo movimiento caduca cuando la IA propone
--     otra vez (con su nota), y solo hay una pendiente por movimiento (el
--     índice lo exige)
do $$
declare
  v_obt text; v_m uuid; v_l uuid; v_r1 jsonb; v_r2 jsonb; v_e text;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t13-1', pg_temp.c8('d')::date, 100.00, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(2);
    v_r1 := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6300"}]', 'combustible', 0.8);
    v_r2 := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6350"}]', 'comida', 0.6);
    v_obt := format('primera %s, segunda %s, caducó %s | pendientes del movimiento %s | nota «%s»',
                    (select p.estado from contador_propuestas p where p.id = (v_r1->>'propuesta')::uuid),
                    (select p.estado from contador_propuestas p where p.id = (v_r2->>'propuesta')::uuid),
                    case when (v_r2->>'caducada')::uuid = (v_r1->>'propuesta')::uuid then 'la primera' else 'OTRA' end,
                    (select count(*) from contador_propuestas p where p.movimiento_id = v_m and p.estado = 'pendiente'),
                    (select regexp_replace(p.nota, '\(ráfaga [0-9a-f-]+\)', '(ráfaga …)') from contador_propuestas p where p.id = (v_r1->>'propuesta')::uuid));
    begin
      insert into contador_propuestas (movimiento_id, fuente, propuesta, estado)
      values (v_m, 'edgar', '{"lineas": [{"cuenta": "6300"}], "motivo": "x", "confianza": 1}', 'pendiente');
      v_e := 'ENTRÓ';
    exception when others then v_e := sqlstate;
    end;
    v_obt := v_obt || format(' | otra pendiente a mano: %s', v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'la IA propone otra vez: la pendiente anterior caduca con su nota; una sola pendiente por movimiento',
    'primera caducada, segunda pendiente, caducó la primera | pendientes del movimiento 1 | nota «la IA propuso otra vez (ráfaga …)» | otra pendiente a mano: 23505',
    v_obt,
    v_obt = 'primera caducada, segunda pendiente, caducó la primera | pendientes del movimiento 1 | nota «la IA propuso otra vez (ráfaga …)» | otra pendiente a mano: 23505');
end $$;

-- 14. «ASÍ ES»: aprobar una propuesta de la IA sin obra deja su asiento
--     vivo por fn_banco_clasificar (c6) EN NOMBRE DEL DUEÑO (usuario_id el
--     dueño, rol_bd el de la base, camino puente, origen el movimiento),
--     con «Propuesta de la IA #<id> aprobada por Edgar: <motivo>» en la
--     descripción y en la procedencia; la propuesta queda aprobada con sus
--     líneas finales, quién, cuándo y el asiento; el movimiento sale de la
--     bandeja; la regla aprendida es limpia (WAWA, «^WAWA», origen
--     aprobación) y el siguiente cargo del mismo comercio sale por regla,
--     sin IA; aprobar dos veces, MX008
do $$
declare
  v_obt text; v_m uuid; v_m2 uuid; v_l uuid; v_r jsonb; p contador_propuestas; a asientos; v_a text; v_b text; v_c text; v_d text; v_e text;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_sin_reglas('WAWA');
    v_m := pg_temp.c8_cargo('c8-t14-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6300"}]', 'WAWA es una gasolinera: combustible del vehículo', 0.92);
    v_r := fn_contador_aprobar((v_r->>'propuesta')::uuid, pg_temp.c8('dueno')::uuid);
    select * into p from contador_propuestas where id = (v_r->>'propuesta')::uuid;
    select * into a from asientos where id = p.asiento_id;
    v_a := format('%s | asiento %s: %s | %s', v_r->>'estado', case when a.id is not null then 'vivo' else 'NO' end, pg_temp.c8_lineas(a.id),
                  format('usuario %s · rol_bd %s · camino %s · origen %s/%s · reversado %s',
                         case when a.usuario_id = pg_temp.c8('dueno')::uuid then 'el dueño' else 'OTRO' end,
                         case when a.rol_bd = fn_rol_llamante() then 'el de la base' else a.rol_bd end, a.camino, a.origen_tabla,
                         case when a.origen_id = v_m::text then 'el movimiento' else 'OTRO' end,
                         (exists (select 1 from asientos r where r.reversa_a = a.id))::text));
    v_b := format('descripción «%s» | procedencia %s',
                  regexp_replace(a.descripcion, p.id::text, '<id>'),
                  case when a.procedencia->>'motivo_edgar' = format('Propuesta de la IA #%s aprobada por Edgar: %s', p.id, 'WAWA es una gasolinera: combustible del vehículo')
                       then 'con el mismo motivo' else coalesce(a.procedencia->>'motivo_edgar', 'SIN motivo') end);
    v_c := format('propuesta: líneas finales %s, aprobada por %s %s, asiento %s | movimiento %s, %s en la bandeja', p.lineas_finales::text,
                  case when p.aprobado_por = pg_temp.c8('dueno')::uuid then 'el dueño' else 'OTRO' end,
                  case when p.aprobado_el is not null then 'hoy' else 'SIN fecha' end,
                  case when p.asiento_id = (select m.asiento_id from movimientos_banco m where m.id = v_m) then 'el del movimiento' else 'OTRO' end,
                  (select m.estado || '/' || m.casado_clase from movimientos_banco m where m.id = v_m),
                  case when exists (select 1 from v_banco_bandeja b where b.movimiento_id = v_m) then 'SIGUE' else 'ya no' end);
    v_d := format('regla: %s', (select format('%s · %s · %s · %s · pide_obra %s', r.nombre, r.patron, r.lineas::text, r.origen, r.pide_obra::text)
                                  from contador_reglas r where r.id = (v_r->'regla'->>'regla')::uuid));
    -- el siguiente WAWA: por regla, sin IA
    v_m2 := pg_temp.c8_cargo('c8-t14-2', pg_temp.c8('d')::date + 1, 48.10, 'WAWA 5112 OCALA FL');
    perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_d := v_d || format(' | el siguiente WAWA: %s', (select format('%s «%s» confianza %s', q.fuente, q.propuesta->>'motivo', q.propuesta->>'confianza')
                                                      from contador_propuestas q where q.id = pg_temp.c8_prop('c8-t14-2')));
    begin
      perform fn_contador_aprobar(p.id, pg_temp.c8('dueno')::uuid);
      v_e := 'aprobó DOS VECES';
    exception when others then v_e := format('dos veces: %s', sqlstate);
    end;
    v_obt := format('%s | %s | %s | %s | %s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'aprobar: el asiento vivo de c6 en nombre del dueño con «Propuesta de la IA #… aprobada por Edgar», la propuesta aprobada, el movimiento fuera de la bandeja, la regla aprendida limpia y el siguiente del comercio por regla',
    'aprobada | asiento vivo: 1010 -61.20 | 6300 61.20 | usuario el dueño · rol_bd el de la base · camino puente · origen movimientos_banco/el movimiento · reversado false | descripción «Propuesta de la IA #<id> aprobada por Edgar: WAWA es una gasolinera: combustible del vehículo: WAWA 5234 BELLEVIEW FL» | procedencia con el mismo motivo | propuesta: líneas finales [{"cuenta": "6300"}], aprobada por el dueño hoy, asiento el del movimiento | movimiento casado/clasificado, ya no en la bandeja | regla: WAWA · ^WAWA · [{"cuenta": "6300"}] · aprobacion · pide_obra false | el siguiente WAWA: regla «Regla: WAWA» confianza 1 | dos veces: MX008',
    v_obt,
    v_obt = 'aprobada | asiento vivo: 1010 -61.20 | 6300 61.20 | usuario el dueño · rol_bd el de la base · camino puente · origen movimientos_banco/el movimiento · reversado false | descripción «Propuesta de la IA #<id> aprobada por Edgar: WAWA es una gasolinera: combustible del vehículo: WAWA 5234 BELLEVIEW FL» | procedencia con el mismo motivo | propuesta: líneas finales [{"cuenta": "6300"}], aprobada por el dueño hoy, asiento el del movimiento | movimiento casado/clasificado, ya no en la bandeja | regla: WAWA · ^WAWA · [{"cuenta": "6300"}] · aprobacion · pide_obra false | el siguiente WAWA: regla «Regla: WAWA» confianza 1 | dos veces: MX008');
end $$;

-- 15. LA OBRA: una propuesta a 5100 (pide obra) no se aprueba sin ella
--     (MX008 «elige la obra», y nada entra al libro); con la obra, la línea
--     la lleva, queda «aprobada» (la obra se puso donde faltaba), su asiento
--     la lleva; la regla aprendida va sin obra (v1) y con pide_obra; el
--     siguiente Home Depot sale por regla pidiendo la obra; clasificar a
--     mano a 5100 sin obra, MX008 también; una obra que no existe, 22023
do $$
declare
  v_obt text; v_m uuid; v_m2 uuid; v_l uuid; v_r jsonb; v_pid uuid; v_a text; v_b text; v_c text; v_d text; v_n0 bigint; v_hint text;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_sin_reglas('HOME DEPOT');
    v_m := pg_temp.c8_cargo('c8-t15-1', pg_temp.c8('d')::date, 87.43, 'THE HOME DEPOT 6341 OCALA FL');
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "5100"}]', 'Home Depot: material de obra', 0.9);
    v_pid := (v_r->>'propuesta')::uuid;
    v_n0 := (select count(*) from asientos);
    begin
      perform fn_contador_aprobar(v_pid, pg_temp.c8('dueno')::uuid);
      v_a := 'aprobó SIN OBRA';
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_a := format('sin obra: %s %s, pista «%s»', sqlstate, case when sqlerrm ~ '^Elige la obra' then 'elige la obra' else sqlerrm end, v_hint);
    end;
    v_a := v_a || format(', asientos nuevos %s, propuesta %s', (select count(*) from asientos) - v_n0, (select q.estado from contador_propuestas q where q.id = v_pid));
    begin
      perform fn_contador_aprobar(v_pid, pg_temp.c8('dueno')::uuid, 'obra-que-no-existe');
      v_a := v_a || ' | obra inventada: ENTRÓ';
    exception when others then v_a := v_a || format(' | obra inventada: %s', sqlstate);
    end;
    v_r := fn_contador_aprobar(v_pid, pg_temp.c8('dueno')::uuid, pg_temp.c8('obra'));
    v_b := format('con obra: %s, líneas finales %s, asiento %s', v_r->>'estado',
                  replace((select q.lineas_finales::text from contador_propuestas q where q.id = v_pid), pg_temp.c8('obra'), '<obra>'),
                  replace(pg_temp.c8_lineas((v_r->>'asiento_id')::uuid), pg_temp.c8('obra'), '<obra>'));
    v_c := format('regla: %s', (select format('%s · %s · %s · pide_obra %s', r.nombre, r.patron, r.lineas::text, r.pide_obra::text)
                                  from contador_reglas r where r.id = (v_r->'regla'->>'regla')::uuid));
    v_m2 := pg_temp.c8_cargo('c8-t15-2', pg_temp.c8('d')::date + 1, 120.00, 'THE HOME DEPOT 2051 BELLEVIEW FL');
    perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_c := v_c || format(' | el siguiente: %s', (select format('%s «%s» pide_obra %s', q.fuente, q.propuesta->>'motivo', q.propuesta->'flags'->>'pide_obra')
                                                 from contador_propuestas q where q.id = pg_temp.c8_prop('c8-t15-2')));
    begin
      perform fn_contador_clasificar(v_m2, pg_temp.c8('dueno')::uuid, '[{"cuenta": "5100"}]', null, false);
      v_d := 'a mano sin obra: ENTRÓ';
    exception when others then v_d := format('a mano sin obra: %s', sqlstate);
    end;
    v_r := fn_contador_aprobar(pg_temp.c8_prop('c8-t15-2'), pg_temp.c8('dueno')::uuid, pg_temp.c8('obra2'));
    v_d := v_d || format(' | el siguiente con su obra: %s, %s', v_r->>'estado',
                         replace(pg_temp.c8_lineas((v_r->>'asiento_id')::uuid), pg_temp.c8('obra2'), '<obra2>'));
    v_obt := format('%s | %s | %s | %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'la obra: sin ella MX008 «elige la obra» (nada entra); con ella la línea la lleva y queda aprobada; la regla sin obra y con pide_obra; el siguiente por regla pide la obra',
    'sin obra: MX008 elige la obra, pista «elige la obra», asientos nuevos 0, propuesta pendiente | obra inventada: 22023 | con obra: aprobada, líneas finales [{"cuenta": "5100", "proyecto_id": "<obra>"}], asiento 1010 -87.43 | 5100 87.43 obra:<obra> | regla: THE HOME DEPOT · ^THE HOME DEPOT · [{"cuenta": "5100"}] · pide_obra true | el siguiente: regla «Regla: THE HOME DEPOT» pide_obra true | a mano sin obra: MX008 | el siguiente con su obra: aprobada, 1010 -120.00 | 5100 120.00 obra:<obra2>',
    v_obt,
    v_obt = 'sin obra: MX008 elige la obra, pista «elige la obra», asientos nuevos 0, propuesta pendiente | obra inventada: 22023 | con obra: aprobada, líneas finales [{"cuenta": "5100", "proyecto_id": "<obra>"}], asiento 1010 -87.43 | 5100 87.43 obra:<obra> | regla: THE HOME DEPOT · ^THE HOME DEPOT · [{"cuenta": "5100"}] · pide_obra true | el siguiente: regla «Regla: THE HOME DEPOT» pide_obra true | a mano sin obra: MX008 | el siguiente con su obra: aprobada, 1010 -120.00 | 5100 120.00 obra:<obra2>');
end $$;

-- 16. «SEGÚN YO» (clasificar): con una propuesta de la IA a 6300, Edgar
--     dice 6400: queda «editada», con sus líneas finales, su motivo detrás
--     del de la IA en la descripción del asiento, y la regla aprende lo de
--     Edgar; sin propuesta delante, se inserta una fuente «edgar» ya
--     aprobada (el rastro es uno); con recordar = false no se crea regla;
--     los errores de c6 pasan tal cual (un movimiento ya casado: MX008 de
--     fn_banco_tomar); una línea con una cuenta prohibida ni llega a c6
do $$
declare
  v_obt text; v_m uuid; v_m2 uuid; v_l uuid; v_r jsonb; p contador_propuestas; a asientos; v_a text; v_b text; v_c text; v_d text; v_n0 bigint;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_sin_reglas('WAWA|SHELL');
    v_m := pg_temp.c8_cargo('c8-t16-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6300"}]', 'WAWA es una gasolinera: combustible', 0.9);
    v_r := fn_contador_clasificar(v_m, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6400"}]', 'fue hielo y guantes para la cuadrilla', true);
    select * into p from contador_propuestas where id = (v_r->>'propuesta')::uuid;
    select * into a from asientos where id = p.asiento_id;
    v_a := format('%s %s, finales %s, asiento %s | «%s» | regla %s', v_r->>'estado', p.fuente, p.lineas_finales::text, pg_temp.c8_lineas(a.id),
                  regexp_replace(a.descripcion, p.id::text, '<id>'),
                  (select format('%s → %s', r.nombre, r.lineas::text) from contador_reglas r where r.id = (v_r->'regla'->>'regla')::uuid));
    -- sin propuesta delante, y sin recordar
    v_m2 := pg_temp.c8_cargo('c8-t16-2', pg_temp.c8('d')::date, 45.00, 'SHELL OIL 57544 OCALA FL');
    v_n0 := (select count(*) from contador_reglas);
    v_r := fn_contador_clasificar(v_m2, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', null, false);
    select * into p from contador_propuestas where id = (v_r->>'propuesta')::uuid;
    select * into a from asientos where id = p.asiento_id;
    v_b := format('sin propuesta: %s %s, «%s», reglas nuevas %s', p.fuente, p.estado, a.descripcion, (select count(*) from contador_reglas) - v_n0);
    -- el error de c6, tal cual
    begin
      perform fn_contador_clasificar(v_m2, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', null, false);
      v_c := 'otra vez: ENTRÓ';
    exception when others then
      v_c := format('otra vez: %s %s', sqlstate, case when sqlerrm ~ 'ya está casado' and sqlerrm ~ 'fn_banco_descasar' then '«ya está casado… fn_banco_descasar» (c6)' else sqlerrm end);
    end;
    begin
      perform fn_contador_clasificar(v_m2, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6000"}]', null, false);
      v_d := 'a 6000: ENTRÓ';
    exception when others then v_d := format('a 6000: %s %s', sqlstate, case when sqlerrm ~ 'sueldo' then '«es sueldo»' else sqlerrm end);
    end;
    v_obt := format('%s | %s | %s | %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'clasificar: con propuesta distinta queda editada (y la regla aprende lo de Edgar); sin propuesta, una de Edgar aprobada; sin recordar no hay regla; los errores de c6 pasan tal cual',
    'editada ia, finales [{"cuenta": "6400"}], asiento 1010 -61.20 | 6400 61.20 | «Propuesta de la IA #<id> editada por Edgar: WAWA es una gasolinera: combustible · Edgar: fue hielo y guantes para la cuadrilla: WAWA 5234 BELLEVIEW FL» | regla WAWA → [{"cuenta": "6400"}] | sin propuesta: edgar aprobada, «Clasificado por Edgar desde la bandeja (fase 7): SHELL OIL 57544 OCALA FL», reglas nuevas 0 | otra vez: MX008 «ya está casado… fn_banco_descasar» (c6) | a 6000: MX004 «es sueldo»',
    v_obt,
    v_obt = 'editada ia, finales [{"cuenta": "6400"}], asiento 1010 -61.20 | 6400 61.20 | «Propuesta de la IA #<id> editada por Edgar: WAWA es una gasolinera: combustible · Edgar: fue hielo y guantes para la cuadrilla: WAWA 5234 BELLEVIEW FL» | regla WAWA → [{"cuenta": "6400"}] | sin propuesta: edgar aprobada, «Clasificado por Edgar desde la bandeja (fase 7): SHELL OIL 57544 OCALA FL», reglas nuevas 0 | otra vez: MX008 «ya está casado… fn_banco_descasar» (c6) | a 6000: MX004 «es sueldo»');
end $$;

-- 17. «NO ES ESO» (rechazar): la propuesta queda rechazada con el motivo de
--     Edgar (o uno de fábrica), quién y cuándo; nada entra al libro; el
--     movimiento sigue en la bandeja y vuelve a esperar propuesta; una
--     rechazada no se aprueba ni se rechaza otra vez (MX008); la IA sí
--     puede proponer otra cosa después
do $$
declare
  v_obt text; v_m uuid; v_l uuid; v_r jsonb; p contador_propuestas; v_a text; v_b text; v_c text; v_n0 bigint;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t17-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6350"}]', 'una comida', 0.4);
    v_n0 := (select count(*) from asientos);
    v_r := fn_contador_rechazar((v_r->>'propuesta')::uuid, pg_temp.c8('dueno')::uuid, '  no fue comida, fue gasolina ');
    select * into p from contador_propuestas where id = (v_r->>'propuesta')::uuid;
    v_a := format('%s «%s» por %s %s, asientos nuevos %s | movimiento %s, en la bandeja %s, espera propuesta %s', p.estado, p.motivo_edgar,
                  case when p.aprobado_por = pg_temp.c8('dueno')::uuid then 'el dueño' else 'OTRO' end,
                  case when p.aprobado_el is not null then 'hoy' else 'SIN fecha' end, (select count(*) from asientos) - v_n0,
                  (select m.estado from movimientos_banco m where m.id = v_m),
                  (exists (select 1 from v_banco_bandeja b where b.movimiento_id = v_m))::text,
                  (exists (select 1 from fn_contador_candidatos() c where c.movimiento_id = v_m))::text);
    begin
      perform fn_contador_aprobar(p.id, pg_temp.c8('dueno')::uuid);
      v_b := 'aprobar la rechazada: ENTRÓ';
    exception when others then v_b := format('aprobar la rechazada: %s', sqlstate);
    end;
    begin
      perform fn_contador_rechazar(p.id, pg_temp.c8('dueno')::uuid, 'otra vez');
      v_b := v_b || ' | rechazar otra vez: ENTRÓ';
    exception when others then v_b := v_b || format(' | rechazar otra vez: %s', sqlstate);
    end;
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6300"}]', 'combustible', 0.9);
    v_r := fn_contador_rechazar((v_r->>'propuesta')::uuid, pg_temp.c8('dueno')::uuid, null);
    v_c := format('la IA propone otra: %s | sin motivo: «%s»', (select q.estado from contador_propuestas q where q.id = (v_r->>'propuesta')::uuid),
                  v_r->>'motivo_edgar');
    v_c := v_c || format(' | bandeja de la IA: %s %s', (select b.estado from v_contador_bandeja b where b.movimiento_id = v_m),
                         (select count(*) from v_contador_bandeja b where b.movimiento_id = v_m));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'rechazar: rechazada con el motivo de Edgar, nada en el libro, el movimiento sigue y vuelve a esperar; no se aprueba ni se rechaza dos veces; la IA puede proponer otra',
    'rechazada «no fue comida, fue gasolina» por el dueño hoy, asientos nuevos 0 | movimiento pendiente, en la bandeja true, espera propuesta true | aprobar la rechazada: MX008 | rechazar otra vez: MX008 | la IA propone otra: rechazada | sin motivo: «No es eso (Edgar, desde la bandeja)» | bandeja de la IA: rechazada 1',
    v_obt,
    v_obt = 'rechazada «no fue comida, fue gasolina» por el dueño hoy, asientos nuevos 0 | movimiento pendiente, en la bandeja true, espera propuesta true | aprobar la rechazada: MX008 | rechazar otra vez: MX008 | la IA propone otra: rechazada | sin motivo: «No es eso (Edgar, desde la bandeja)» | bandeja de la IA: rechazada 1');
end $$;


-- =====================================================================
-- Las reglas que dicta Edgar, y lo que la base sabe sacar sola
-- =====================================================================

-- 18. El alta de una regla: válida (con cuántos casan ahora, en su cuenta
--     del banco o en todas); y todos sus frenos: patrón inválido o que casa
--     con todo, cuenta que no se propone, partes que no suman 1 (o sin
--     parte con varias líneas), repetida, cuenta del banco que no lo es,
--     nombre corto, obra que no existe, obra en cuenta que no la lleva;
--     v_contador_reglas la enseña con sus cuentas en texto
do $$
declare
  v_obt text; v_m uuid; v_r jsonb; v_res text[] := '{}'; v_q text; v_a text; v_b text;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t18-1', pg_temp.c8('d')::date, 171.98, 'PRUEBA C8 CES 1040 TAMPA FL');
    v_r := fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, ' CES (supply) ', '^PRUEBA C8 CES ', '[{"cuenta": "5100"}]');
    v_a := format('válida: «%s» %s casan_ahora %s, pide_obra %s', v_r->>'nombre', v_r->>'origen', v_r->>'casan_ahora', v_r->>'pide_obra');
    v_r := fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'CES en la tarjeta', '^PRUEBA C8 CES 1040', '[{"cuenta": "5100"}]', pg_temp.c8('tarjeta'));
    v_a := v_a || format(' | en la tarjeta: casan_ahora %s', v_r->>'casan_ahora');
    foreach v_q in array array[
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'mal', '(', '[{"cuenta": "5100"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'todo', '.*', '[{"cuenta": "5100"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'sueldo', '^GUSTO', '[{"cuenta": "6000"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'partes', '^ALLY', '[{"cuenta": "2540", "parte": "0.5"}, {"cuenta": "7100", "parte": "0.6"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'sin parte', '^ALLY', '[{"cuenta": "2540"}, {"cuenta": "7100"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'repetida', '^PRUEBA C8 CES ', '[{"cuenta": "5500"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'banco raro', '^X', '[{"cuenta": "5100"}]', '6300')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'X', '^X', '[{"cuenta": "5100"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'obra rara', '^X', '[{"cuenta": "5100", "proyecto_id": "obra-que-no-existe"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'obra donde no', '^X', '[{"cuenta": "6300", "proyecto_id": "OBRA"}]')$q$,
      $q$select fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'seis', '^X', '[{"cuenta": "5100"}, {"cuenta": "5100"}, {"cuenta": "5100"}, {"cuenta": "5100"}, {"cuenta": "5100"}, {"cuenta": "5100"}]')$q$] loop
      begin
        execute replace(v_q, '"OBRA"', '"' || pg_temp.c8('obra') || '"');
        v_res := v_res || 'ENTRÓ'::text;
      exception when others then v_res := v_res || sqlstate::text;
      end;
    end loop;
    v_b := format('vista: %s', (select format('%s → %s · activa %s · pendientes %s', v.nombre, v.cuentas_texto, v.activa::text, v.pendientes)
                                  from v_contador_reglas v where v.nombre = 'CES (supply)'));
    v_obt := format('%s | frenos: %s | %s', v_a, array_to_string(v_res, ' '), v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'el alta de una regla: válida (y cuántos casan ahora, en su cuenta o en todas) y todos sus frenos; la vista la enseña',
    'válida: «CES (supply)» edgar casan_ahora 1, pide_obra true | en la tarjeta: casan_ahora 0 | frenos: 22023 22023 MX004 MX001 22023 MX008 MX004 22023 MX006 MX006 22023 | vista: CES (supply) → 5100 Material · activa true · pendientes 0',
    v_obt,
    v_obt = 'válida: «CES (supply)» edgar casan_ahora 1, pide_obra true | en la tarjeta: casan_ahora 0 | frenos: 22023 22023 MX004 MX001 22023 MX008 MX004 22023 MX006 MX006 22023 | vista: CES (supply) → 5100 Material · activa true · pendientes 0');
end $$;

-- 19. La baja de una regla: con su motivo (queda en las notas), activa =
--     false, sus propuestas pendientes caducan (con su nota) y nada se
--     borra; sin motivo, 22023; dos veces, MX008; el patrón queda libre
--     para otra regla
do $$
declare
  v_obt text; v_m uuid; v_rid uuid; v_r jsonb; v_a text; v_b text; v_c text;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_sin_reglas('WAWA');
    v_m := pg_temp.c8_cargo('c8-t19-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_rid := (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Wawa', '^WAWA', '[{"cuenta": "6300"}]')->>'id')::uuid;
    perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_a := format('antes: propuesta %s', (select q.estado from contador_propuestas q where q.regla_id = v_rid));
    begin
      perform fn_contador_regla_baja(v_rid, pg_temp.c8('dueno')::uuid, '');
      v_a := v_a || ' | sin motivo: ENTRÓ';
    exception when others then v_a := v_a || format(' | sin motivo: %s', sqlstate);
    end;
    v_r := fn_contador_regla_baja(v_rid, pg_temp.c8('dueno')::uuid, 'ya no compro ahí');
    v_b := format('baja: activa %s, caducadas %s, notas «%s», propuesta %s, «%s»', v_r->>'activa', v_r->>'propuestas_caducadas',
                  regexp_replace(v_r->>'notas', '[0-9]{4}-[0-9]{2}-[0-9]{2}', '<fecha>', 'g'),
                  (select q.estado from contador_propuestas q where q.regla_id = v_rid),
                  (select regexp_replace(q.nota, '[0-9]{4}-[0-9]{2}-[0-9]{2}', '<fecha>') from contador_propuestas q where q.regla_id = v_rid));
    begin
      perform fn_contador_regla_baja(v_rid, pg_temp.c8('dueno')::uuid, 'otra vez');
      v_c := 'dos veces: ENTRÓ';
    exception when others then v_c := format('dos veces: %s', sqlstate);
    end;
    v_c := v_c || format(' | reglas %s (ninguna borrada) | el patrón libre: %s',
                         (select count(*) from contador_reglas r where r.id = v_rid),
                         (fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Wawa otra vez', '^WAWA', '[{"cuenta": "6350"}]')->>'activa'));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'la baja de una regla: con su motivo en las notas, sus pendientes caducan, nada se borra; sin motivo 22023; dos veces MX008; el patrón queda libre',
    'antes: propuesta pendiente | sin motivo: 22023 | baja: activa false, caducadas 1, notas «la dictó Edgar el <fecha>' || E'\n' || 'baja el <fecha>: ya no compro ahí», propuesta caducada, «<fecha>: la regla «Wawa» se dio de baja (ya no compro ahí)» | dos veces: MX008 | reglas 1 (ninguna borrada) | el patrón libre: true',
    v_obt,
    v_obt = 'antes: propuesta pendiente | sin motivo: 22023 | baja: activa false, caducadas 1, notas «la dictó Edgar el <fecha>' || E'\n' || 'baja el <fecha>: ya no compro ahí», propuesta caducada, «<fecha>: la regla «Wawa» se dio de baja (ya no compro ahí)» | dos veces: MX008 | reglas 1 (ninguna borrada) | el patrón libre: true');
end $$;

-- 20. Lo que la base saca sola: el comercio de una descripción del banco
--     (sin números, sin la forma de pago delante, sin la ciudad ni el
--     estado del final; un cheque, un número o una palabra del banco solos
--     no son un comercio), el escape de un texto para un patrón, si un
--     patrón vale, y lo que se tapa antes de dárselo a la IA: el correo tal
--     cual y en la forma normalizada de c6, el teléfono, la cuenta; un hash
--     o un uuid enteros se dejan; desc_norm con su descripción cruda tapa el
--     correo de cualquier dominio
do $$
declare
  v_obt text; v_a text; v_b text; v_c text;
begin
  begin
    select string_agg(coalesce(fn_contador_nombre_comercio(x), '∅'), ' · ' order by o) into v_a
      from unnest(array['THE HOME DEPOT 6341 OCALA FL', 'WAWA 5234 BELLEVIEW FL', '7 ELEVEN 34271 OCALA FL', 'TST FIREHOUSE SUBS OCALA FL',
                        'SQ JOES ELECTRIC SUPPLY OCALA FL', 'POS DEBIT WAWA 5234 BELLEVIEW FL', 'AMAZON MKTPL 2K3J9 AMZN COM BILL WA',
                        'NETFLIX COM 866 579 7172 CA', 'CHECK 1043', '1043', 'ZELLE', 'IRS USATAXPYMT 220261029 EDGAR', 'ZELLE PAYMENT TO JUAN PEREZ JPM99ABC',
                        'MIAMI', '', 'AB']) with ordinality as t(x, o);
    v_b := format('escape %s | patrón: «(» %s · «.*» %s · «^WAWA» %s | tapa: %s',
                  fn_contador_regex_escapar('A.B (C) $5*'),
                  case when fn_contador_regex_valida('(') ~ 'no es una expresión regular válida' then 'no vale' else coalesce(fn_contador_regex_valida('('), 'VALE') end,
                  case when fn_contador_regex_valida('.*') ~ 'casa con un texto vacío' then 'casa con todo' else coalesce(fn_contador_regex_valida('.*'), 'VALE') end,
                  coalesce(fn_contador_regex_valida('^WAWA'), 'vale'),
                  fn_contador_sin_datos('juan@mail.com tel 352-555-1234 o (352) 555 1234 acct 12345678 tienda 6341 fecha 10/15 ref 2K3J9'));
    -- lo que NO se tapa (un hash o un uuid enteros: el sello de la
    -- trazabilidad, aunque traigan ocho dígitos seguidos), el correo como lo
    -- deja c6 («JPEREZ MAIL COM»), y desc_norm por fn_contador_sin_datos_norm
    -- con su descripción cruda: el correo de un dominio cualquiera, el
    -- teléfono y la cuenta en su forma normalizada, y nada más
    v_c := format('hash %s · uuid %s · normalizado %s | desc_norm: zelle «%s» · dominio propio «%s» · sin correo «%s»',
                  case when fn_contador_sin_datos('bf5998663c555f49375d52ee71fd08779266e39e1d9072e95809f711410a6ec6')
                            = 'bf5998663c555f49375d52ee71fd08779266e39e1d9072e95809f711410a6ec6' then 'entero' else 'TOCADO' end,
                  case when fn_contador_sin_datos('12345678-1234-4123-8123-123456789012') = '12345678-1234-4123-8123-123456789012' then 'entero' else 'TOCADO' end,
                  fn_contador_sin_datos('ZELLE A JUAN JPEREZ GMAIL COM Y ANA MARIA HOTMAIL NET'),
                  fn_contador_sin_datos_norm('ZELLE PAYMENT TO JUAN PEREZ JPEREZ MAIL COM 305 555 1234 ACCT 1234567890',
                                             'ZELLE PAYMENT TO JUAN PEREZ JPEREZ@MAIL.COM 305-555-1234 ACCT 1234567890'),
                  fn_contador_sin_datos_norm('PAGO A JUAN PEREZELECTRIC COM REF 44', 'Pago a juan@perezelectric.com ref 44', null),
                  fn_contador_sin_datos_norm('WAWA 5234 BELLEVIEW FL', 'WAWA 5234 BELLEVIEW FL', 'nota sin correo'));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
  exception when others then
    v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'el comercio de una descripción del banco, el escape y la validez de un patrón, y lo que se tapa (correos tal cual y normalizados, teléfonos, números de cuenta; nunca un hash ni un uuid)',
    'THE HOME DEPOT · WAWA · 7 ELEVEN · TST FIREHOUSE SUBS · SQ JOES ELECTRIC SUPPLY · WAWA · AMAZON MKTPL · NETFLIX · ∅ · ∅ · ∅ · IRS USATAXPYMT · ZELLE PAYMENT TO JUAN PEREZ · ∅ · ∅ · ∅ | escape A\.B \(C\) \$5\* | patrón: «(» no vale · «.*» casa con todo · «^WAWA» vale | tapa: [correo] tel [teléfono] o [teléfono] acct [número] tienda 6341 fecha 10/15 ref 2K3J9 | hash entero · uuid entero · normalizado ZELLE A JUAN [correo] Y ANA [correo] | desc_norm: zelle «ZELLE PAYMENT TO JUAN PEREZ [correo] [teléfono] ACCT [número]» · dominio propio «PAGO A [correo] REF 44» · sin correo «WAWA 5234 BELLEVIEW FL»',
    v_obt,
    v_obt = 'THE HOME DEPOT · WAWA · 7 ELEVEN · TST FIREHOUSE SUBS · SQ JOES ELECTRIC SUPPLY · WAWA · AMAZON MKTPL · NETFLIX · ∅ · ∅ · ∅ · IRS USATAXPYMT · ZELLE PAYMENT TO JUAN PEREZ · ∅ · ∅ · ∅ | escape A\.B \(C\) \$5\* | patrón: «(» no vale · «.*» casa con todo · «^WAWA» vale | tapa: [correo] tel [teléfono] o [teléfono] acct [número] tienda 6341 fecha 10/15 ref 2K3J9 | hash entero · uuid entero · normalizado ZELLE A JUAN [correo] Y ANA [correo] | desc_norm: zelle «ZELLE PAYMENT TO JUAN PEREZ [correo] [teléfono] ACCT [número]» · dominio propio «PAGO A [correo] REF 44» · sin correo «WAWA 5234 BELLEVIEW FL»');
end $$;


-- =====================================================================
-- El control, la suplantación y las vistas
-- =====================================================================

-- 21. EL CONTROL en rojo cuando toca, y de vuelta a verde: 60 (una
--     aprobada cuyo asiento se des-casa a mano → rojo; Edgar la cierra con
--     fn_contador_caducar → verde; caducar con el asiento vivo o una
--     pendiente, MX008), 61 (un asiento que dice «Propuesta de la IA #…»
--     sin su propuesta aprobada), 62 (la cuenta de una regla activa se
--     desactiva), 63 (una fn_contador_* ejecutable por la API; una tabla
--     sin RLS), 70 (el gasto sobre el tope), 71 (una pendiente de 8 días),
--     72 (una ráfaga con error; una que se quedó abierta más de cinco
--     minutos —la función se cortó—, que la base da por perdida con su
--     error al abrir la siguiente), 73 (sin ráfaga nunca y cargos de hace
--     más de dos días; tras una ráfaga, verde)
do $$
declare
  v_obt text; v_m uuid; v_mv uuid; v_l uuid; v_r jsonb; v_pid uuid; v_a text; v_b text; v_c text; v_d text; v_e text; v_f text; v_g text; v_h text;
  v_antes text;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_al_dia();
    perform pg_temp.c8_sin_reglas('WAWA|SHELL|NFPA|NETFLIX|LOWES');
    v_antes := pg_temp.c8_rojos('cuadre');
    -- 73 primero: sin ráfaga nunca y un cargo de hace 3 días sin propuesta
    update contador_config set ultima_rafaga_el = null, ultimo_error = null, ultimo_error_el = null where id = 1;
    v_mv := pg_temp.c8_cargo('c8-t21-0', pg_temp.c8('hoy')::date - 3, 33.00, 'LOWES 1077 OCALA FL');
    v_h := format('73 sin ráfaga: %s', pg_temp.c8_fila(73));
    -- 60: aprobar y des-casar a mano
    v_m := pg_temp.c8_cargo('c8-t21-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m, v_l, '[{"cuenta": "6300"}]', 'combustible', 0.9);
    v_pid := (v_r->>'propuesta')::uuid;
    begin
      perform fn_contador_caducar(v_pid, pg_temp.c8('dueno')::uuid, 'c8-pruebas');
      v_a := 'caducar la pendiente: ENTRÓ';
    exception when others then v_a := format('caducar la pendiente: %s', sqlstate);
    end;
    perform fn_contador_aprobar(v_pid, pg_temp.c8('dueno')::uuid, null, false);
    perform fn_contador_lote_cerrar(v_l, '{"input": 1000, "output": 100}');
    v_h := v_h || format(' | tras la ráfaga: %s', pg_temp.c8_fila(73));
    begin
      perform fn_contador_caducar(v_pid, pg_temp.c8('dueno')::uuid, 'c8-pruebas');
      v_a := v_a || ' | caducar con el asiento vivo: ENTRÓ';
    exception when others then v_a := v_a || format(' | caducar con el asiento vivo: %s', sqlstate);
    end;
    v_a := v_a || format(' | 60 aprobada: %s', pg_temp.c8_fila(60));
    perform pg_temp.c8_descasar(v_m, 'c8-pruebas: estaba mal');
    v_a := v_a || format(' → des-casada: %s (%s)', pg_temp.c8_fila(60),
                         case when (select c.detalle from v_contador_control c where c.orden = 60) ~ 'está reversado.*fn_contador_caducar' then 'dice el asiento reversado y qué hacer' else 'MAL' end);
    perform fn_contador_caducar(v_pid, pg_temp.c8('dueno')::uuid, 'estaba mal: era otra cosa');
    v_a := v_a || format(' → caducada: %s, movimiento %s', pg_temp.c8_fila(60),
                         case when exists (select 1 from fn_contador_candidatos() c where c.movimiento_id = v_m) then 'vuelve a esperar' else 'MAL' end);
    -- 61: el asiento dice «Propuesta de la IA #…» y la propuesta ya no está aprobada
    v_r := fn_contador_clasificar(v_m, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', null, false);
    v_r := pg_temp.c8_ia(pg_temp.c8_cargo('c8-t21-2', pg_temp.c8('d')::date, 45.00, 'SHELL OIL 57544 OCALA FL'), pg_temp.c8_lote(1), '[{"cuenta": "6300"}]', 'combustible', 0.9);
    v_r := fn_contador_aprobar((v_r->>'propuesta')::uuid, pg_temp.c8('dueno')::uuid, null, false);
    v_b := format('61 aprobada: %s', pg_temp.c8_fila(61));
    update contador_propuestas set estado = 'rechazada', asiento_id = null where id = (v_r->>'propuesta')::uuid;
    v_b := v_b || format(' → sin su aprobada: %s', pg_temp.c8_fila(61));
    update contador_propuestas set estado = 'aprobada', asiento_id = (v_r->>'asiento_id')::uuid where id = (v_r->>'propuesta')::uuid;
    v_b := v_b || format(' → otra vez: %s', pg_temp.c8_fila(61));
    -- 62: la cuenta de una regla activa se desactiva
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'NFPA', '^NFPA', '[{"cuenta": "6800"}]');
    v_c := format('62: %s', pg_temp.c8_fila(62));
    update cuentas set activa = false where codigo = '6800';
    v_c := v_c || format(' → cuenta inactiva: %s (%s)', pg_temp.c8_fila(62),
                         case when (select c.detalle from v_contador_control c where c.orden = 62) ~ 'NFPA → 6800' then 'nombra la regla' else 'MAL' end);
    update cuentas set activa = true where codigo = '6800';
    v_c := v_c || format(' → otra vez: %s', pg_temp.c8_fila(62));
    -- 63: una función en la API; una tabla sin RLS
    v_d := format('63: %s', pg_temp.c8_fila(63));
    execute 'grant execute on function public.fn_contador_tope() to anon';
    v_d := v_d || format(' → fn en la API: %s', pg_temp.c8_fila(63));
    execute 'revoke execute on function public.fn_contador_tope() from anon';
    execute 'alter table public.contador_reglas disable row level security';
    v_d := v_d || format(' → sin RLS: %s', pg_temp.c8_fila(63));
    execute 'alter table public.contador_reglas enable row level security';
    v_d := v_d || format(' → otra vez: %s', pg_temp.c8_fila(63));
    -- 70: el tope
    v_e := format('70: %s', pg_temp.c8_fila(70));
    update contador_config set tope_mes_centavos = 0 where id = 1;
    v_e := v_e || format(' → tope 0: %s (%s)', pg_temp.c8_fila(70),
                         case when (select c.detalle from v_contador_control c where c.orden = 70) ~ '\$[0-9,]+\.[0-9]{2}' then 'en dólares' else 'MAL' end);
    update contador_config set tope_mes_centavos = 1000000 where id = 1;
    -- 71: una pendiente de 8 días
    v_r := pg_temp.c8_ia(pg_temp.c8_cargo('c8-t21-3', pg_temp.c8('d')::date, 19.99, 'NETFLIX COM CA'), pg_temp.c8_lote(1), '[{"cuenta": "6500"}]', 'software', 0.7);
    v_f := format('71: %s', pg_temp.c8_fila(71));
    update contador_propuestas set creado_el = now() - interval '8 days' where id = (v_r->>'propuesta')::uuid;
    v_f := v_f || format(' → 8 días: %s', pg_temp.c8_fila(71));
    -- 72: una ráfaga con error
    v_g := format('72: %s', pg_temp.c8_fila(72));
    perform fn_contador_lote_cerrar(pg_temp.c8_lote(1), '{"input": 10}', 'Anthropic contestó 529 dos veces');
    v_g := v_g || format(' → con error: %s (%s)', pg_temp.c8_fila(72),
                         case when (select c.detalle from v_contador_control c where c.orden = 72) ~ '529' then 'dice el error' else 'MAL' end);
    -- (otra ráfaga, más tarde, sin error: en la prueba el reloj no avanza,
    -- se finge que el error fue hace un minuto)
    update contador_config set ultimo_error_el = ultimo_error_el - interval '1 minute' where id = 1;
    perform fn_contador_lote_cerrar(pg_temp.c8_lote(1), '{"input": 10}');
    v_g := v_g || format(' → la siguiente sin error: %s', pg_temp.c8_fila(72));
    -- (una ráfaga que se quedó abierta más de cinco minutos: la función se
    -- cortó sin cerrarla; al abrir la siguiente —aquí a mano, no por el
    -- ayudante, que cierra las abiertas— la base la da por perdida, cerrada
    -- con su error y sin uso, y la nueva entra; una ráfaga limpia después
    -- vuelve a poner la alarma en verde)
    v_l := pg_temp.c8_lote(1);
    update contador_lotes set creado_el = now() - interval '6 minutes' where id = v_l;
    v_g := v_g || format(' → una abierta hace 6 min: %s (%s)', pg_temp.c8_fila(72),
                         case when (select c.detalle from v_contador_control c where c.orden = 72) ~ 'abierta.*sin cerrar.*se cortó' then 'dice que se cortó' else 'MAL' end);
    perform fn_contador_lote_abrir(pg_temp.c8('dueno')::uuid, 'claude-opus-5-5', 'low', null, null, 1);
    v_g := v_g || format(' → al abrir otra: %s, %s',
                         (select case when l.cerrado_el is not null and l.error ~ 'se cortó sin cerrar' and l.centavos = 0 then 'la perdida cerrada con su error'
                                      else format('MAL (%s %s)', l.cerrado_el, l.error) end
                            from contador_lotes l where l.id = v_l),
                         pg_temp.c8_fila(72));
    update contador_config set ultimo_error_el = ultimo_error_el - interval '1 minute' where id = 1;
    perform fn_contador_lote_cerrar((select l.id from contador_lotes l where l.cerrado_el is null), '{"input": 10}');
    v_g := v_g || format(' → la siguiente limpia: %s', pg_temp.c8_fila(72));
    v_obt := format('%s | %s | %s | %s | %s | %s | %s | %s | cuadres rojos nuevos: %s', v_h, v_a, v_b, v_c, v_d, v_e, v_f, v_g,
                    case when pg_temp.c8_rojos('cuadre') = v_antes then 'ninguno' else pg_temp.c8_rojos('cuadre') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'el control en rojo cuando toca y de vuelta a verde: 60 (des-casar, caducar), 61, 62, 63, 70, 71, 72 y 73',
    '73 sin ráfaga: rojo | tras la ráfaga: verde | caducar la pendiente: MX008 | caducar con el asiento vivo: MX008 | 60 aprobada: verde → des-casada: rojo (dice el asiento reversado y qué hacer) → caducada: verde, movimiento vuelve a esperar | 61 aprobada: verde → sin su aprobada: rojo → otra vez: verde | 62: verde → cuenta inactiva: rojo (nombra la regla) → otra vez: verde | 63: verde → fn en la API: rojo → sin RLS: rojo → otra vez: verde | 70: verde → tope 0: rojo (en dólares) | 71: verde → 8 días: rojo | 72: verde → con error: rojo (dice el error) → la siguiente sin error: verde → una abierta hace 6 min: rojo (dice que se cortó) → al abrir otra: la perdida cerrada con su error, rojo → la siguiente limpia: verde | cuadres rojos nuevos: ninguno',
    v_obt,
    v_obt = '73 sin ráfaga: rojo | tras la ráfaga: verde | caducar la pendiente: MX008 | caducar con el asiento vivo: MX008 | 60 aprobada: verde → des-casada: rojo (dice el asiento reversado y qué hacer) → caducada: verde, movimiento vuelve a esperar | 61 aprobada: verde → sin su aprobada: rojo → otra vez: verde | 62: verde → cuenta inactiva: rojo (nombra la regla) → otra vez: verde | 63: verde → fn en la API: rojo → sin RLS: rojo → otra vez: verde | 70: verde → tope 0: rojo (en dólares) | 71: verde → 8 días: rojo | 72: verde → con error: rojo (dice el error) → la siguiente sin error: verde → una abierta hace 6 min: rojo (dice que se cortó) → al abrir otra: la perdida cerrada con su error, rojo → la siguiente limpia: verde | cuadres rojos nuevos: ninguno');
end $$;

-- 22. La suplantación: la función de borde llega sin sesión; al clasificar,
--     c6 ve al dueño (el asiento lo dice) y al terminar la sesión vuelve a
--     estar vacía; otro dueño activo que pide algo pasa a ser el de la
--     configuración; si el dueño deja de serlo, nada se clasifica (42501)
--     y nada entra
do $$
declare
  v_obt text; v_m uuid; v_r jsonb; v_a text; v_b text; v_c text; v_n0 bigint; v_otro uuid;
begin
  begin
    perform pg_temp.c8_montar();
    v_m := pg_temp.c8_cargo('c8-t22-1', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    perform pg_temp.c8_ser('servicio');
    v_r := fn_contador_clasificar(v_m, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', null, false);
    v_a := format('asiento de %s | después, la sesión: claims «%s», sub «%s»',
                  case when (select a.usuario_id from asientos a where a.id = (v_r->>'asiento_id')::uuid) = pg_temp.c8('dueno')::uuid then 'el dueño' else 'OTRO' end,
                  coalesce(current_setting('request.jwt.claims', true), ''), coalesce(current_setting('request.jwt.claim.sub', true), ''));
    -- otro dueño activo pide algo: pasa a ser el de la configuración (el
    -- del equipo, hecho dueño dentro de la prueba: perfiles.id es de auth)
    if pg_temp.c8('equipo') is not null then
      v_otro := pg_temp.c8('equipo')::uuid;
      update perfiles set rol = 'dueno' where id = v_otro;
      perform fn_contador_reglas_aplicar(v_otro);
      v_b := format('otro dueño: config.dueno %s', case when (select c.dueno from contador_config c where c.id = 1) = v_otro then 'es el otro' else 'MAL' end);
      perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
      update perfiles set rol = 'campo' where id = v_otro;
    else
      v_b := 'otro dueño: config.dueno es el otro';
    end if;
    -- el dueño deja de serlo (el cargo se siembra antes: sembrar es de c6,
    -- y c6 también exige al dueño)
    v_m := pg_temp.c8_cargo('c8-t22-2', pg_temp.c8('d')::date, 45.00, 'SHELL OIL 57544 OCALA FL', null);
    update perfiles set activo = false where id = pg_temp.c8('dueno')::uuid;
    v_n0 := (select count(*) from asientos);
    begin
      perform fn_contador_clasificar(v_m, pg_temp.c8('dueno')::uuid, '[{"cuenta": "6300"}]', null, false);
      v_c := 'ya no dueño: ENTRÓ';
    exception when others then v_c := format('ya no dueño: %s', sqlstate);
    end;
    v_c := v_c || format(', asientos nuevos %s, sesión «%s»', (select count(*) from asientos) - v_n0, coalesce(current_setting('request.jwt.claims', true), ''));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'la suplantación: c6 ve al dueño y la sesión vuelve vacía; otro dueño pasa a ser el de la configuración; un dueño que ya no lo es, 42501 y nada entra',
    'asiento de el dueño | después, la sesión: claims «», sub «» | otro dueño: config.dueno es el otro | ya no dueño: 42501, asientos nuevos 0, sesión «»',
    v_obt,
    v_obt = 'asiento de el dueño | después, la sesión: claims «», sub «» | otro dueño: config.dueno es el otro | ya no dueño: 42501, asientos nuevos 0, sesión «»');
end $$;

-- 23. Las vistas de la pantalla: v_contador_estado cuenta lo que espera sin
--     propuesta, las pendientes (por regla y por IA), las reglas activas,
--     el gasto del mes y si está bloqueado; v_contador_bandeja da por
--     movimiento su propuesta viva (o la última) con las líneas resueltas
--     (nombre de cuenta y de obra), el motivo, la confianza, los flags, la
--     fuente y el asiento vivo; fn_contador_resumen junta todo sin secretos
do $$
declare
  v_obt text; v_m1 uuid; v_m2 uuid; v_m3 uuid; v_l uuid; v_r jsonb; e v_contador_estado; v_a text; v_b text; v_c text; v_e0 v_contador_estado;
begin
  begin
    perform pg_temp.c8_montar();
    perform pg_temp.c8_al_dia();
    perform pg_temp.c8_sin_reglas('WAWA|HOME DEPOT');
    select * into v_e0 from v_contador_estado;
    v_m1 := pg_temp.c8_cargo('c8-t23-1', pg_temp.c8('d')::date, 87.43, 'THE HOME DEPOT 6341 OCALA FL');
    v_m2 := pg_temp.c8_cargo('c8-t23-2', pg_temp.c8('d')::date, 61.20, 'WAWA 5234 BELLEVIEW FL');
    v_m3 := pg_temp.c8_cargo('c8-t23-3', pg_temp.c8('d')::date + 1, 45.00, 'SHELL OIL 57544 OCALA FL');
    perform fn_contador_regla_alta(pg_temp.c8('dueno')::uuid, 'Wawa', '^WAWA', '[{"cuenta": "6300"}]');
    perform fn_contador_reglas_aplicar(pg_temp.c8('dueno')::uuid);
    v_l := pg_temp.c8_lote(1);
    v_r := pg_temp.c8_ia(v_m1, v_l, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', pg_temp.c8('obra'))),
                         'Home Depot: material para la obra de la visita de ese día', 0.85, '{"use_tax": true}');
    perform fn_contador_lote_cerrar(v_l, '{"input": 1000000, "output": 100000}');
    select * into e from v_contador_estado;
    v_a := format('estado: espera +%s, pendientes +%s (regla +%s, ia +%s), reglas +%s, gasto del mes +%s centavos, bloqueado %s, cuadres rojos %s',
                  e.pendientes_sin_propuesta - v_e0.pendientes_sin_propuesta, e.propuestas_pendientes - v_e0.propuestas_pendientes,
                  e.propuestas_por_regla - v_e0.propuestas_por_regla, e.propuestas_por_ia - v_e0.propuestas_por_ia,
                  e.reglas_activas - v_e0.reglas_activas, e.centavos_mes_contador - v_e0.centavos_mes_contador, e.bloqueado::text, e.cuadres_rojos);
    v_b := format('bandeja: %s', (select string_agg(format('%s · %s · %s · %s · %s · %s · %s', b.fuente, b.estado, b.resumen,
                                                           replace(b.lineas::text, pg_temp.c8('obra'), '<obra>'), b.confianza,
                                                           coalesce(b.regla_nombre, '-'), b.flags::text), ' || ' order by b.movimiento_id = v_m1 desc)
                                    from v_contador_bandeja b where b.movimiento_id in (v_m1, v_m2)));
    v_b := replace(v_b, (select p.nombre from proyectos p where p.id = pg_temp.c8('obra')), '<nombre de la obra>');
    v_b := v_b || format(' | shell en la bandeja de la IA: %s', (select count(*) from v_contador_bandeja b where b.movimiento_id = v_m3));
    v_r := fn_contador_resumen();
    v_c := format('resumen: %s', (select string_agg(k, ',' order by k) from jsonb_object_keys(v_r) k));
    v_obt := format('%s | %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'las vistas: v_contador_estado cuenta lo que espera, las pendientes por fuente, las reglas y el gasto; v_contador_bandeja resuelve cuentas y obras; fn_contador_resumen',
    'estado: espera +1, pendientes +2 (regla +1, ia +1), reglas +1, gasto del mes +600 centavos, bloqueado false, cuadres rojos 0 | bandeja: ia · pendiente · 5100 Material · [{"obra": "<nombre de la obra>", "tipo": "costo", "cuenta": "5100", "pide_obra": false, "proyecto_id": "<obra>", "cuenta_nombre": "Material"}] · 0.850 · - · {"use_tax": true} || regla · pendiente · 6300 Vehículos — combustible y mantenimiento · [{"tipo": "gasto", "cuenta": "6300", "pide_obra": false, "cuenta_nombre": "Vehículos — combustible y mantenimiento"}] · 1 · Wawa · {} | shell en la bandeja de la IA: 0 | resumen: config,control_rojo,estado,tope',
    v_obt,
    v_obt = 'estado: espera +1, pendientes +2 (regla +1, ia +1), reglas +1, gasto del mes +600 centavos, bloqueado false, cuadres rojos 0 | bandeja: ia · pendiente · 5100 Material · [{"obra": "<nombre de la obra>", "tipo": "costo", "cuenta": "5100", "pide_obra": false, "proyecto_id": "<obra>", "cuenta_nombre": "Material"}] · 0.850 · - · {"use_tax": true} || regla · pendiente · 6300 Vehículos — combustible y mantenimiento · [{"tipo": "gasto", "cuenta": "6300", "pide_obra": false, "cuenta_nombre": "Vehículos — combustible y mantenimiento"}] · 1 · Wawa · {} | shell en la bandeja de la IA: 0 | resumen: config,control_rojo,estado,tope');
end $$;


-- =====================================================================
-- El final
-- =====================================================================

-- 24. Nada queda: las tablas de c8, el gasto, el banco, los asientos, las
--     cuentas, los perfiles y los ajustes, igual que al empezar
do $$
declare
  v_obt text;
begin
  v_obt := case when pg_temp.c8_conteos() = pg_temp.c8('conteos') then 'igual que al empezar'
                else 'antes: ' || pg_temp.c8('conteos') || ' · ahora: ' || pg_temp.c8_conteos() end;
  insert into _pruebas values (24, 'nada queda al deshacer', 'igual que al empezar', v_obt, v_obt = 'igual que al empezar');
end $$;

-- 25. Con c8 puesto, c2 (la cadena y «permisos»), c3 (los puentes), c6 (el
--     banco, con «protecciones del banco») y c4 (los estados: salvo lo que
--     ya estaba en rojo antes de las pruebas, que se dice) siguen en verde;
--     el control de c8 sin cuadres en rojo; nada de c8 en la API ni
--     SECURITY DEFINER
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_c8 text; v_api text;
begin
  begin
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena() where not ok;
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar() where not ok;
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy') where not ok;
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c8('rojos_c4'), ', ')));
    v_c8 := pg_temp.c8_rojos('cuadre');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_contador\_%'
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | c8 cuadres en rojo: %s | c8 en la API o definer: %s', v_c2, v_c3, v_c6, v_c4, v_c8, v_api);
  exception
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'el cierre: c2, c3, c6 y c4 en verde con c8 puesto; el control de c8 sin cuadres en rojo; nada en la API',
    'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres en rojo: ninguno | c8 en la API o definer: ninguna',
    v_obt || case when pg_temp.c8('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.c8('rojos_c4') || ')' else '' end,
    v_obt = 'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres en rojo: ninguno | c8 en la API o definer: ninguna');
end $$;


-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6 y
-- p1): si el SQL Editor deja de esperar, la corrida sigue en el servidor
-- hasta el final y se lee después con
--   select * from pruebas.c8_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c8_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c8_resultado from public, anon, authenticated, service_role;
truncate pruebas.c8_resultado;
insert into pruebas.c8_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
