-- =====================================================================
-- c0-banco-pruebas.sql — el banco se prueba a sí mismo: ¿imita a Supabase?
--
-- Sirve también de MOLDE para los docs/conta/c*-pruebas.sql:
--   * cada ataque es un do $$ … $$ con un begin … exception … end interno
--     (una subtransacción);
--   * dentro se suplanta al usuario (request.jwt.claims + set local role);
--   * al final del bloque interno se lanza MXT00 para DESHACER todo lo
--     escrito; el resultado viaja en variables de plpgsql, que no se deshacen;
--   * ya fuera de la subtransacción (otra vez como el rol del editor) se
--     apunta en _pruebas.
-- Nada persiste salvo _pruebas, que es temporal y muere con la sesión.
-- Se puede pegar tal cual en el SQL Editor de Supabase: solo lee perfiles
-- reales y todo lo que escribe lo deshace.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- 1. Como equipo, select de facturas da 0 filas.
do $$
declare
  v_equipo uuid;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_equipo is null then
    insert into _pruebas values (1, 'equipo lee facturas', '0 filas', 'omitida: no hay perfil de equipo', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*)::text || ' filas' into v_obt from facturas;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'equipo lee facturas', '0 filas', v_obt, v_obt = '0 filas');
end $$;

-- 2. Como equipo, insertar un recibo PROPIO funciona (y se deshace).
do $$
declare
  v_equipo uuid;
  v_proy   text;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_proy from proyectos order by id limit 1;
  if v_equipo is null then
    insert into _pruebas values (2, 'equipo sube un recibo suyo', 'insertado', 'omitida: no hay perfil de equipo', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    insert into recibos (proyecto_id, ruta, autor_id) values (v_proy, 'recibos/prueba-c0.jpg', v_equipo);
    v_obt := 'insertado';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'equipo sube un recibo suyo', 'insertado', v_obt, v_obt = 'insertado');
end $$;

-- 3. Como equipo, un recibo a nombre de OTRO lo frena RLS (42501).
do $$
declare
  v_equipo uuid;
  v_dueno  uuid;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_equipo is null or v_dueno is null then
    insert into _pruebas values (3, 'equipo sube recibo ajeno', '42501', 'omitida: faltan perfiles', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    insert into recibos (ruta, autor_id) values ('recibos/ajeno-c0.jpg', v_dueno);
    v_obt := 'insertado';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate;
  end;
  insert into _pruebas values (3, 'equipo sube recibo ajeno', '42501', v_obt, v_obt = '42501');
end $$;

-- 4. Como anon (sin sesión), facturas: 0 filas o permiso denegado.
do $$
declare
  v_obt text;
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    select count(*)::text || ' filas' into v_obt from facturas;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when insufficient_privilege then v_obt := '42501';
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'anon lee facturas', '0 filas o 42501', v_obt, v_obt in ('0 filas', '42501'));
end $$;

-- 5. Como dueño, ve TODO (mismas filas que el editor, que se salta RLS).
do $$
declare
  v_dueno uuid;
  v_total text;
  v_obt   text;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_dueno is null then
    insert into _pruebas values (5, 'dueño ve todo', '-', 'omitida: no hay dueño', null);
    return;
  end if;
  select format('facturas=%s recibos=%s horas=%s materiales=%s',
                (select count(*) from facturas), (select count(*) from recibos),
                (select count(*) from horas), (select count(*) from materiales))
    into v_total;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select format('facturas=%s recibos=%s horas=%s materiales=%s',
                  (select count(*) from facturas), (select count(*) from recibos),
                  (select count(*) from horas), (select count(*) from materiales))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'dueño ve todo', v_total, v_obt, v_obt = v_total);
end $$;

-- 6. Como equipo, corregir sus horas SIN permiso: lo frena
--    trg_guarda_correccion (P0001 con el mensaje de pedir permiso).
do $$
declare
  v_equipo uuid;
  v_hora   bigint;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_hora from horas
   where usuario_id = v_equipo and correccion_estado is null order by id limit 1;
  if v_equipo is null or v_hora is null then
    insert into _pruebas values (6, 'equipo corrige horas sin permiso', 'P0001 Pídele permiso', 'omitida: sin equipo u horas', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update horas set horas = horas + 1 where id = v_hora;
    v_obt := 'actualizado (' || (select count(*) from horas where id = v_hora)::text || ')';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 20);
  end;
  insert into _pruebas values (6, 'equipo corrige horas sin permiso', 'P0001 Pídele permiso', v_obt, v_obt like 'P0001 Pídele permiso%');
end $$;

-- 7. Como equipo, CON permiso aprobado, sí corrige y el permiso se gasta.
do $$
declare
  v_equipo uuid;
  v_hora   bigint;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_hora from horas
   where usuario_id = v_equipo and correccion_estado = 'aprobada' order by id limit 1;
  if v_equipo is null or v_hora is null then
    insert into _pruebas values (7, 'equipo corrige con permiso', 'corregida, permiso gastado', 'omitida: no hay horas con permiso', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update horas set horas = horas + 1 where id = v_hora;
    select case when correccion_estado is null then 'corregida, permiso gastado'
                else 'permiso sigue: ' || correccion_estado end
      into v_obt from horas where id = v_hora;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'equipo corrige con permiso', 'corregida, permiso gastado', v_obt, v_obt = 'corregida, permiso gastado');
end $$;

-- 8. Marcar pagada una factura pone cobrado = monto (trg_factura_cobrada).
do $$
declare
  v_dueno uuid;
  v_fact  bigint;
  v_obt   text;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_fact from facturas
   where pagada is not true and monto > 0 order by id limit 1;
  if v_dueno is null or v_fact is null then
    insert into _pruebas values (8, 'marcar pagada pone cobrado = monto', 'cobrado = monto', 'omitida: sin dueño o factura abierta', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update facturas set pagada = true where id = v_fact;
    select case when cobrado = monto then 'cobrado = monto'
                else format('cobrado=%s monto=%s', cobrado, monto) end
      into v_obt from facturas where id = v_fact;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'marcar pagada pone cobrado = monto', 'cobrado = monto', v_obt, v_obt = 'cobrado = monto');
end $$;

-- 9. service_role se salta RLS: ve todas las facturas.
do $$
declare
  v_total text;
  v_obt   text;
begin
  select count(*)::text into v_total from facturas;
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
    execute 'set local role service_role';
    select count(*)::text into v_obt from facturas;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'service_role ve todas las facturas', v_total, v_obt, v_obt = v_total);
end $$;

-- 10. El equipo no lee recibos directo, pero sí por recibos_equipo.
do $$
declare
  v_equipo uuid;
  v_total  bigint;
  v_obt    text;
begin
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_equipo is null then
    insert into _pruebas values (10, 'equipo: recibos 0, recibos_equipo todos', '-', 'omitida: no hay perfil de equipo', null);
    return;
  end if;
  select count(*) into v_total from recibos;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select format('recibos=%s vista=%s', (select count(*) from recibos), (select count(*) from recibos_equipo))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'equipo: recibos 0, recibos_equipo todos',
    format('recibos=0 vista=%s', v_total), v_obt, v_obt = format('recibos=0 vista=%s', v_total));
end $$;

-- 11. Un perfil INACTIVO no lee horas ni sube recibos.
do $$
declare
  v_inact uuid;
  v_obt   text;
  v_ins   text;
begin
  select id into v_inact from perfiles where activo = false order by creado limit 1;
  if v_inact is null then
    insert into _pruebas values (11, 'inactivo: 0 horas y no sube recibos', 'horas=0 insert=42501', 'omitida: no hay perfil inactivo', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_inact, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select 'horas=' || count(*) into v_obt from horas;
    begin
      insert into recibos (ruta, autor_id) values ('recibos/inactivo-c0.jpg', v_inact);
      v_ins := 'insertado';
    exception when others then
      v_ins := sqlstate;
    end;
    v_obt := v_obt || ' insert=' || v_ins;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'inactivo: 0 horas y no sube recibos', 'horas=0 insert=42501', v_obt, v_obt = 'horas=0 insert=42501');
end $$;

-- 12. anon no inserta recibos (RLS: auth.uid() es nulo).
do $$
declare
  v_obt text;
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    insert into recibos (ruta) values ('recibos/anon-c0.jpg');
    v_obt := 'insertado';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate;
  end;
  insert into _pruebas values (12, 'anon sube un recibo', '42501', v_obt, v_obt = '42501');
end $$;

-- 13. Imitación CRÍTICA: una tabla nueva nace abierta para anon y
--     authenticated, y una función nueva nace ejecutable por anon. Si esto
--     no pasa, el banco escondería un revoke olvidado.
do $$
declare
  v_obt text;
begin
  begin
    create table public._c0_tabla_nueva (x int);
    create function public._c0_fn_nueva() returns int language sql as 'select 1';
    select format('anon_tabla=%s auth_tabla=%s anon_fn=%s',
                  has_table_privilege('anon', 'public._c0_tabla_nueva', 'select,insert,update,delete'),
                  has_table_privilege('authenticated', 'public._c0_tabla_nueva', 'select,insert,update,delete'),
                  has_function_privilege('anon', 'public._c0_fn_nueva()', 'execute'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'tabla y función nuevas nacen abiertas (como Supabase)',
    'anon_tabla=t auth_tabla=t anon_fn=t', v_obt, v_obt = 'anon_tabla=t auth_tabla=t anon_fn=t');
end $$;

-- 14. auth.uid() y auth.role() leen el token como Supabase.
do $$
declare
  v_dueno uuid;
  v_obt   text;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_dueno is null then
    insert into _pruebas values (14, 'auth.uid() y auth.role()', '-', 'omitida: no hay dueño', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select format('uid_ok=%s role=%s dueno=%s', auth.uid() = v_dueno, auth.role(), es_dueno()) into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'auth.uid() y auth.role()', 'uid_ok=t role=authenticated dueno=t',
    v_obt, v_obt = 'uid_ok=t role=authenticated dueno=t');
end $$;

-- 15. El rol que corre esto NO es superusuario (como postgres en Supabase)
--     y aun así puede ponerse el traje de los tres roles de la API.
do $$
declare
  v_obt text;
begin
  select format('super=%s anon=%s auth=%s service=%s',
                r.rolsuper,
                pg_has_role(current_user, 'anon', 'member'),
                pg_has_role(current_user, 'authenticated', 'member'),
                pg_has_role(current_user, 'service_role', 'member'))
    into v_obt from pg_roles r where r.rolname = current_user;
  insert into _pruebas values (15, 'el editor no es superusuario y suplanta',
    'super=f anon=t auth=t service=t', v_obt, v_obt = 'super=f anon=t auth=t service=t');
end $$;

-- 16. Anular un recibo devuelve sus materiales a "falta"
--     (trg_recibo_marca_material), como dueño.
do $$
declare
  v_dueno  uuid;
  v_recibo bigint;
  v_obt    text;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select recibo_id into v_recibo from materiales
   where recibo_id is not null and estado = 'comprado' order by id limit 1;
  if v_dueno is null or v_recibo is null then
    insert into _pruebas values (16, 'anular recibo devuelve materiales', 'comprados=0', 'omitida: no hay material comprado', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set estado = 'anulado' where id = v_recibo;
    select 'comprados=' || count(*) into v_obt from materiales where recibo_id = v_recibo;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'anular recibo devuelve materiales', 'comprados=0', v_obt, v_obt = 'comprados=0');
end $$;

-- 17. Nada de lo anterior dejó rastro: el recibo de la prueba 2 no existe.
do $$
declare
  v_obt text;
begin
  select 'rastro=' || count(*) into v_obt from recibos where ruta like 'recibos/%-c0.jpg' or ruta = 'recibos/prueba-c0.jpg';
  insert into _pruebas values (17, 'las pruebas no dejan rastro', 'rastro=0', v_obt, v_obt = 'rastro=0');
end $$;

-- 18. Los revoke de la regla 4 muerden: quitarle la función solo a anon
--     NO basta (sigue por PUBLIC); con "from public, anon" y "from
--     authenticated" ya nadie de la API la ejecuta.
do $$
declare
  v_obt text;
begin
  begin
    create function public._c0_fn_revoke() returns int language sql as 'select 1';
    revoke execute on function public._c0_fn_revoke() from anon;
    v_obt := format('solo_anon:%s', has_function_privilege('anon', 'public._c0_fn_revoke()', 'execute'));
    revoke execute on function public._c0_fn_revoke() from public, anon;
    revoke execute on function public._c0_fn_revoke() from authenticated;
    v_obt := v_obt || format(' completo: anon=%s auth=%s',
               has_function_privilege('anon', 'public._c0_fn_revoke()', 'execute'),
               has_function_privilege('authenticated', 'public._c0_fn_revoke()', 'execute'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'revoke de funciones como en Supabase',
    'solo_anon:t completo: anon=f auth=f', v_obt, v_obt = 'solo_anon:t completo: anon=f auth=f');
end $$;

select * from _pruebas order by n;
