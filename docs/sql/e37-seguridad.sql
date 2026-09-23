-- =====================================================================
-- E37 · Seguridad: lo que marcaba el asesor de Supabase, y un agujero
--       que el asesor NO marcaba y era el peor de todos
-- Supabase → SQL Editor. Se pega ENTERO. Idempotente: se puede pegar las
-- veces que haga falta, y la segunda no cambia nada.
--
-- ✅ APLICADO EN PRODUCCIÓN el 23-sep-2026 a las 20:55 UTC, como migración
--    e37_seguridad (Supabase → Database → Migrations). Comprobación 9/9 ✓;
--    el aviso de prueba salió (notificar: 200, enviadas 3, fallos 0). El
--    asesor de seguridad pasó de 5 a 0 funciones ejecutables sin sesión y de
--    5 a 0 sin search_path. Volver a pegarlo no cambia nada (idempotente).
--
-- NO cambia nada de lo que la cuadrilla, el portal del cliente, el del
-- contratista o Edgar hacen hoy. Probado antes en el banco local
-- (pruebas/seguridad/): primero se demostró cada agujero ABIERTO y después
-- CERRADO, y que los avisos al teléfono y el recordatorio del Notice to
-- Owner siguen saliendo igual.
--
-- Qué arregla, del más grave al menos:
--
--   1. LAS VISTAS DEL EQUIPO DEJABAN ESCRIBIR. proyectos_equipo,
--      recibos_equipo, materiales_equipo, alcances_equipo y
--      documentos_equipo son vistas "simples", y Postgres deja editar,
--      insertar y BORRAR a través de una vista simple. Como corren con los
--      permisos de su dueño (que se salta la seguridad por fila), cualquier
--      trabajador con sesión podía, desde fuera de la app, borrar todos los
--      recibos o cambiar el nombre, el estado o el cliente de cualquier obra.
--      La app solo las LEE: se les quita todo menos leer.
--
--   2. FUNCIONES QUE CUALQUIERA PODÍA LLAMAR SIN INICIAR SESIÓN. Ocho
--      funciones conservaban el permiso PUBLIC. La seria:
--      fn_nto_recordatorio, que no mira quién llama y crea un pendiente
--      URGENTE (con aviso al teléfono de todos) en la obra que le digan.
--      Las demás son de trigger (Postgres no deja llamarlas sueltas), pero
--      se cierran igual para que el asesor deje de marcarlas.
--
--   3. EL SECRETO DEL CARTERO SALE DEL CÓDIGO. fn_cartero llevaba escrito
--      en su cuerpo el valor con el que llama a la función notificar, y el
--      cuerpo de una función se lee desde el catálogo. Pasa a Supabase
--      Vault, cifrado. El valor lo mueve la propia base: NO aparece en este
--      archivo. Mismo valor que hoy, así que los avisos no se cortan.
--      Cambiarlo por uno nuevo es otro paso (E37b y E37c), que se hace
--      cuando Edgar quiera.
--
--   4. search_path FIJO en las cinco funciones que no lo tenían.
--
-- Qué NO toca, y por qué:
--   - Las vistas *_equipo siguen siendo SECURITY DEFINER. El asesor lo marca
--     como ERROR, pero pasarlas a security_invoker dejaría a la cuadrilla
--     viendo CERO filas: las tablas de fondo son solo del dueño. Lo peligroso
--     de que sean definer era escribir a través de ellas, y eso se cierra en
--     el bloque 1. Ese aviso del asesor se queda, a propósito.
--   - es_dueno() y es_activo() siguen abiertas a los usuarios con sesión:
--     las policies de TODAS las tablas las llaman como el usuario que
--     consulta, y la app llama rpc/es_activo. Cerrarlas lo rompería todo.
--   - fn_estuve (la app la llama al abrir), conteo_tablas y reponer_avisos
--     (las dos miran es_dueno() por dentro) se quedan como están.
--   - pg_net sigue en public: no se puede mover sin borrarlo y crearlo otra
--     vez (no es reubicable), y ganar eso no compensa el riesgo.
--
-- Qué tiene que ver Edgar al pegar:
--   - Una tabla de comprobación al final, con todas las filas en ✓.
--   - Un aviso en su teléfono: «🔑 Prueba del cartero». Si llega, los
--     avisos ya salen con el secreto guardado en Vault. Sale uno cada vez
--     que se pega este archivo.
-- =====================================================================


-- ---------------------------------------------------------------------
-- BLOQUE 1 · Las vistas del equipo: se leen, no se escriben
-- ---------------------------------------------------------------------
-- La app lee proyectos_equipo, recibos_equipo, materiales_equipo,
-- alcances_equipo y documentos_equipo (js/db.js) y nunca escribe en ellas.
-- El portal del cliente y el del contratista no las usan: van por la
-- función portal. Así que a los usuarios con sesión se les deja SELECT y se
-- les quita todo lo demás; a anon, todo.
do $$
declare
  v text;
begin
  foreach v in array array['proyectos_equipo', 'recibos_equipo', 'materiales_equipo',
                           'alcances_equipo', 'documentos_equipo', 'asistente_costo_mes']
  loop
    if to_regclass('public.' || v) is not null then
      execute format('revoke all on public.%I from public, anon', v);
      execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from authenticated', v);
      execute format('grant select on public.%I to authenticated', v);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- BLOQUE 2 · Funciones: nadie sin sesión llama nada
-- ---------------------------------------------------------------------
-- 2a · Las funciones de trigger. Postgres nunca deja llamarlas sueltas,
--      y los triggers las siguen disparando aunque nadie tenga permiso de
--      ejecutarlas (probado en el banco: el permiso se mira al CREAR el
--      trigger, no cada vez que dispara). Se cierran a todos menos al
--      servidor para que el asesor deje de marcarlas.
--      Se excluyen las que pertenecen a una extensión.
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as firma
      from pg_proc p
      join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public'
       and p.prorettype = 'trigger'::regtype
       and not exists (select 1 from pg_depend d
                        where d.classid = 'pg_proc'::regclass
                          and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.firma);
    execute format('grant execute on function %s to service_role', f.firma);
  end loop;
end $$;

-- 2b · fn_nto_recordatorio: la seria. Solo la llaman los triggers
--      fn_nto_al_apuntar_horas y fn_nto_al_arrancar, que corren como el
--      dueño de la base; la app no la llama nunca. Se cierra a todos.
do $$
begin
  if to_regprocedure('public.fn_nto_recordatorio(text)') is not null then
    revoke execute on function public.fn_nto_recordatorio(text) from public, anon, authenticated;
    grant execute on function public.fn_nto_recordatorio(text) to service_role;
  end if;
  -- dia_es: solo pone una fecha en español. Se le quita PUBLIC y anon,
  -- como a todas las demás.
  if to_regprocedure('public.dia_es(date)') is not null then
    revoke execute on function public.dia_es(date) from public, anon;
    grant execute on function public.dia_es(date) to authenticated, service_role;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- BLOQUE 3 · El secreto del cartero, a Vault
-- ---------------------------------------------------------------------
-- 3a · La base copia el valor que hoy está escrito dentro de fn_cartero y
--      lo guarda en Vault con el nombre mxp_secreto_cartero. El valor no
--      pasa por este archivo ni se enseña en pantalla.
--      Si ya está en Vault (segunda vez que se pega), no hace nada.
--      Si no lo encuentra en ninguno de los dos sitios, se para y no toca
--      NADA: el SQL Editor lo deshace todo.
do $$
declare
  v_def    text;
  v_actual text;
begin
  if exists (select 1 from vault.secrets where name = 'mxp_secreto_cartero') then
    return;
  end if;
  v_def := pg_get_functiondef('public.fn_cartero(jsonb)'::regprocedure);
  v_actual := substring(v_def from $re$'x-mxp-secreto'\s*,\s*'([^']+)'$re$);
  if v_actual is null then
    raise exception 'E37: no encontré el secreto del cartero ni dentro de fn_cartero ni en Vault. No se tocó nada. Avisa antes de seguir.';
  end if;
  perform vault.create_secret(
    v_actual,
    'mxp_secreto_cartero',
    'Cabecera x-mxp-secreto con la que fn_cartero llama a la función notificar (E37)');
end $$;

-- 3b · fn_cartero lee el secreto de Vault. Dos cambios más, los dos para
--      que un aviso nunca estorbe a quien está trabajando:
--      - si falta el secreto, avisa en el log y sale sin mandar nada;
--      - si algo falla al mandar, tampoco rompe el INSERT que lo disparó.
--      Antes, un fallo del envío podía tumbar el reporte de horas de un
--      trabajador.
create or replace function public.fn_cartero(cuerpo jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets
   where name = 'mxp_secreto_cartero';
  if v_secreto is null then
    raise warning 'fn_cartero: falta el secreto mxp_secreto_cartero en Vault; el aviso no sale (ver docs/sql/e37-seguridad.sql)';
    return;
  end if;
  perform net.http_post(
    url     := 'https://zeogjvwcmstmkwxjvykz.supabase.co/functions/v1/notificar',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-mxp-secreto', v_secreto),
    body    := cuerpo);
exception when others then
  raise warning 'fn_cartero: el aviso no salió (%): %', sqlstate, sqlerrm;
end $$;

revoke all on function public.fn_cartero(jsonb) from public, anon, authenticated;
grant execute on function public.fn_cartero(jsonb) to service_role;


-- ---------------------------------------------------------------------
-- BLOQUE 4 · search_path fijo en las cinco que no lo tenían
-- ---------------------------------------------------------------------
-- Sin search_path fijo, una función puede acabar usando un objeto con el
-- mismo nombre puesto en otro esquema. En fn_diario_punto (que corre como
-- el dueño de la base) eso era un riesgo de verdad; en las otras cuatro es
-- higiene. No cambia lo que hacen.
do $$
declare
  f text;
begin
  foreach f in array array['public.fn_diario_punto()', 'public.planos_touch()',
                           'public.fn_lev_tocado()', 'public.dia_es(date)',
                           'public.fn_factura_cobrada()']
  loop
    if to_regprocedure(f) is not null then
      execute format('alter function %s set search_path = public, pg_temp', f);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- BLOQUE 5 · Aviso de prueba a Edgar
-- ---------------------------------------------------------------------
-- Sale cuando termina el pegado. Si llega al teléfono, el cartero funciona
-- con el secreto de Vault.
select public.fn_cartero(jsonb_build_object(
  'titulo', '🔑 Prueba del cartero',
  'cuerpo', 'Si ves esto, los avisos ya salen con el secreto guardado en Vault (E37).',
  'para',   (select id from perfiles
              where rol = 'dueno' and coalesce(activo, true)
              order by creado limit 1)));


-- ---------------------------------------------------------------------
-- COMPROBACIÓN · todo tiene que salir en ✓
-- ---------------------------------------------------------------------
with vistas as (
  select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v' and c.relname like '%\_equipo'
), funcs as (
  select p.oid, p.prosecdef, p.proconfig, p.prorettype
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
     and not exists (select 1 from pg_depend d
                      where d.classid = 'pg_proc'::regclass
                        and d.objid = p.oid and d.deptype = 'e')
)
select n, comprobacion, case when ok then '✓' else '✗ REVISAR' end as resultado
from (values
  (1, 'Nadie escribe a través de las vistas del equipo',
      not exists (select 1 from vistas v
                   where has_table_privilege('authenticated', v.oid, 'INSERT')
                      or has_table_privilege('authenticated', v.oid, 'UPDATE')
                      or has_table_privilege('authenticated', v.oid, 'DELETE'))),
  (2, 'La cuadrilla sigue LEYENDO las vistas del equipo',
      not exists (select 1 from vistas v
                   where not has_table_privilege('authenticated', v.oid, 'SELECT'))),
  (3, 'Sin sesión no se ve ninguna vista del equipo',
      not exists (select 1 from vistas v
                   where has_table_privilege('anon', v.oid, 'SELECT'))),
  (4, 'Sin sesión no se ejecuta ninguna función SECURITY DEFINER',
      not exists (select 1 from funcs f
                   where f.prosecdef and has_function_privilege('anon', f.oid, 'EXECUTE'))),
  (5, 'fn_nto_recordatorio: solo la llaman los triggers',
      to_regprocedure('public.fn_nto_recordatorio(text)') is null
      or not has_function_privilege('authenticated', 'public.fn_nto_recordatorio(text)', 'EXECUTE')),
  (6, 'La app sigue pudiendo llamar es_activo y fn_estuve',
      (to_regprocedure('public.es_activo()') is null
       or has_function_privilege('authenticated', 'public.es_activo()', 'EXECUTE'))
      and (to_regprocedure('public.fn_estuve()') is null
       or has_function_privilege('authenticated', 'public.fn_estuve()', 'EXECUTE'))),
  (7, 'fn_cartero ya no lleva el secreto escrito',
      pg_get_functiondef('public.fn_cartero(jsonb)'::regprocedure)
        !~ $re$'x-mxp-secreto'\s*,\s*'[^']+'$re$),
  (8, 'El secreto del cartero está en Vault',
      exists (select 1 from vault.secrets where name = 'mxp_secreto_cartero')),
  (9, 'Ninguna función de public sin search_path fijo',
      not exists (select 1 from funcs f
                   where f.proconfig is null
                      or not exists (select 1 from unnest(f.proconfig) c
                                      where c like 'search_path=%')))
) as t(n, comprobacion, ok)
order by n;
