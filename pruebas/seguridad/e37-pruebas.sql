-- =====================================================================
-- e37-pruebas.sql — lo que E37 promete, atacado de verdad en el banco.
-- Se corre dos veces: ANTES de E37 (tiene que salir rojo justo donde E37
-- arregla) y DESPUÉS (todo verde). Mismo molde que pruebas/conta/c0: cada
-- ataque en una subtransacción que se deshace con MXT00.
-- Solo banco local (usa net._llamadas, que en Supabase no existe).
-- Usuarios del banco: Edgar …0001 (dueño), Gustavo …0002 (equipo).
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- 1. El equipo sigue LEYENDO las cinco vistas.
do $$ declare v_obt text; n1 int; n2 int; n3 int; n4 int; n5 int; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    select count(*) into n1 from proyectos_equipo; select count(*) into n2 from recibos_equipo;
    select count(*) into n3 from materiales_equipo; select count(*) into n4 from alcances_equipo;
    select count(*) into n5 from documentos_equipo;
    v_obt := case when n1 > 0 and n2 > 0 and n5 > 0 then 'lee' else format('lee %s/%s/%s/%s/%s', n1,n2,n3,n4,n5) end;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (1, 'equipo lee las vistas del equipo', 'lee', v_obt, v_obt = 'lee');
end $$;

-- 2. El equipo NO puede borrar recibos a través de recibos_equipo.
do $$ declare v_obt text; k int; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    delete from recibos_equipo where id = (select min(id) from recibos_equipo);
    get diagnostics k = row_count; v_obt := 'borró ' || k;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (2, 'equipo borra un recibo por recibos_equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 3. El equipo NO puede cambiar una obra a través de proyectos_equipo.
do $$ declare v_obt text; k int; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    update proyectos_equipo set nombre = 'CAMBIADO', estado = 'cancelado' where id = 'casa-perez-k3m9';
    get diagnostics k = row_count; v_obt := 'cambió ' || k;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (3, 'equipo cambia nombre y estado de una obra', '42501', v_obt, v_obt = '42501');
end $$;

-- 4. El equipo NO puede meter material a través de materiales_equipo.
do $$ declare v_obt text; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    insert into materiales_equipo (id, proyecto_id, descripcion) values (999999, 'casa-perez-k3m9', 'Prueba E37');
    v_obt := 'insertó';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (4, 'equipo inserta por materiales_equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 5. El equipo NO puede borrar a través de alcances_equipo.
do $$ declare v_obt text; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    delete from alcances_equipo where true;
    v_obt := 'permitido';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (5, 'equipo borra por alcances_equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 6. El equipo NO puede cambiar documentos a través de documentos_equipo.
do $$ declare v_obt text; k int; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    update documentos_equipo set titulo = 'CAMBIADO' where true;
    get diagnostics k = row_count; v_obt := 'cambió ' || k;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (6, 'equipo cambia un documento por documentos_equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 7. Sin sesión no se ve proyectos_equipo.
do $$ declare v_obt text; k int; begin
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    select count(*) into k from proyectos_equipo; v_obt := k || ' filas';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := sqlstate; end;
  insert into _pruebas values (7, 'sin sesión lee proyectos_equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 8 y 9. fn_nto_recordatorio: ni sin sesión ni el equipo.
do $$ declare v_anon text; v_eq text; begin
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    perform fn_nto_recordatorio('casa-perez-k3m9'); v_anon := 'la llamó';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_anon := sqlstate; end;
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    perform fn_nto_recordatorio('casa-perez-k3m9'); v_eq := 'la llamó';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_eq := sqlstate; end;
  insert into _pruebas values (8, 'sin sesión llama fn_nto_recordatorio', '42501', v_anon, v_anon = '42501');
  insert into _pruebas values (9, 'el equipo llama fn_nto_recordatorio', '42501', v_eq, v_eq = '42501');
end $$;

-- 10. Las horas del equipo en una obra por contrato siguen haciendo nacer el
--     recordatorio del Notice to Owner, y salen los dos avisos (horas +
--     urgente). La cadena de triggers no se rompe con los permisos cerrados.
do $$ declare v_obt text; a0 int; a1 int; np int; begin
  begin
    update proyectos set contratista_modo = 'contrato', estado = 'propuesta', nto_enviado_el = null
     where id = 'casa-perez-k3m9';
    delete from pendientes where proyecto_id = 'casa-perez-k3m9'
       and (descripcion like 'Mandar el Notice to Owner%' or descripcion like 'OJO — el plazo%');
    select count(*) into a0 from net._llamadas;
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    insert into horas (fecha, usuario_id, proyecto_id, horas)
    values ((now() at time zone 'America/New_York')::date, '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 3);
    execute 'reset role';
    select count(*) into np from pendientes where proyecto_id = 'casa-perez-k3m9' and prioridad = 'urgente'
       and (descripcion like 'Mandar el Notice to Owner%' or descripcion like 'OJO — el plazo%');
    select count(*) into a1 from net._llamadas;
    v_obt := case when np = 1 then 'recordatorio' else 'sin recordatorio' end || ' + ' || (a1 - a0) || ' avisos';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (10, 'horas del equipo → recordatorio NTO y avisos', 'recordatorio + 2 avisos', v_obt, v_obt = 'recordatorio + 2 avisos');
end $$;

-- 11. El aviso sale con el secreto correcto (el de Vault si ya está; si no,
--     el que estaba escrito). No se enseña: solo si coincide.
do $$ declare v_obt text; v_hdr text; v_esperado text; begin
  select coalesce((select decrypted_secret from vault.decrypted_secrets where name = 'mxp_secreto_cartero'),
                  'mxp_deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') into v_esperado;
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    insert into horas (fecha, usuario_id, proyecto_id, horas)
    values ((now() at time zone 'America/New_York')::date, '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 2);
    execute 'reset role';
    select headers->>'x-mxp-secreto' into v_hdr from net._llamadas order by id desc limit 1;
    v_obt := case when v_hdr = v_esperado then 'mismo secreto' when v_hdr is null then 'no salió' else 'OTRO secreto' end;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (11, 'el aviso sale con el secreto correcto', 'mismo secreto', v_obt, v_obt = 'mismo secreto');
end $$;

-- 12. Edgar da de alta un contratista → nace su llave (trigger con la
--     función ya cerrada a los usuarios con sesión).
do $$ declare v_obt text; k int; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}', true);
    execute 'set local role authenticated';
    insert into contratistas (id, nombre) values ('gc-prueba-e37', 'GC de prueba E37');
    execute 'reset role';
    select count(*) into k from contratista_llaves where contratista_id = 'gc-prueba-e37';
    v_obt := case when k = 1 then 'llave creada' else 'sin llave' end;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (12, 'contratista nuevo → nace su llave del portal', 'llave creada', v_obt, v_obt = 'llave creada');
end $$;

-- 13. Edgar marca pagada una factura → cobrado = monto (fn_factura_cobrada,
--     ya con search_path fijo).
do $$ declare v_obt text; v_id bigint; v_cob numeric; v_mon numeric; begin
  select id into v_id from facturas where not coalesce(pagada, false) and monto > 0 order by id limit 1;
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}', true);
    execute 'set local role authenticated';
    update facturas set pagada = true where id = v_id returning cobrado, monto into v_cob, v_mon;
    v_obt := case when v_cob = v_mon then 'cobrado = monto' else format('cobrado %s ≠ monto %s', v_cob, v_mon) end;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (13, 'factura marcada pagada → cobrado = monto', 'cobrado = monto', v_obt, v_obt = 'cobrado = monto');
end $$;

-- 14. La app sigue pudiendo llamar es_activo() y fn_estuve().
do $$ declare v_obt text; v_act boolean; begin
  begin
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    v_act := es_activo();
    perform fn_estuve();
    v_obt := 'es_activo=' || v_act || ' y fn_estuve ok';
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (14, 'el equipo llama es_activo y fn_estuve', 'es_activo=true y fn_estuve ok', v_obt, v_obt = 'es_activo=true y fn_estuve ok');
end $$;

-- 15 y 16. El secreto sale del cuerpo de fn_cartero y está en Vault, con el
--          mismo valor que tenía.
do $$ declare v_def text; v_ok15 boolean; v_ok16 boolean; begin
  v_def := pg_get_functiondef('public.fn_cartero(jsonb)'::regprocedure);
  v_ok15 := v_def !~ $re$'x-mxp-secreto'\s*,\s*'[^']+'$re$;
  v_ok16 := exists (select 1 from vault.decrypted_secrets where name = 'mxp_secreto_cartero'
                     and decrypted_secret = 'mxp_deadbeefdeadbeefdeadbeefdeadbeefdeadbeef');
  insert into _pruebas values (15, 'fn_cartero ya no lleva el secreto escrito', 'sin secreto',
    case when v_ok15 then 'sin secreto' else 'lo lleva escrito' end, v_ok15);
  insert into _pruebas values (16, 'el secreto está en Vault, con el mismo valor', 'en Vault',
    case when v_ok16 then 'en Vault' else 'no está' end, v_ok16);
end $$;

-- 17. Si faltara el secreto en Vault, las horas del equipo entran igual: el
--     aviso no sale, pero el trabajo no se pierde.
do $$ declare v_obt text; a0 int; a1 int; begin
  begin
    delete from vault.secrets where name = 'mxp_secreto_cartero';
    select count(*) into a0 from net._llamadas;
    perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
    execute 'set local role authenticated';
    insert into horas (fecha, usuario_id, proyecto_id, horas)
    values ((now() at time zone 'America/New_York')::date, '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 1);
    execute 'reset role';
    select count(*) into a1 from net._llamadas;
    v_obt := 'insertado, ' || case when a1 = a0 then 'sin aviso' else 'con aviso' end;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (17, 'sin secreto en Vault, las horas entran igual', 'insertado, sin aviso', v_obt, v_obt = 'insertado, sin aviso');
end $$;

-- 18, 19 y 20. Lo que mira el asesor, leído del catálogo.
do $$ declare k18 int; k19 int; k20 int; begin
  select count(*) into k18 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE');
  select count(*) into k19 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
     and has_function_privilege('authenticated', p.oid, 'EXECUTE');
  select count(*) into k20 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  insert into _pruebas values (18, 'funciones SECURITY DEFINER que anon ejecuta', '0', k18::text, k18 = 0);
  insert into _pruebas values (19, 'funciones de trigger que el equipo ejecuta', '0', k19::text, k19 = 0);
  insert into _pruebas values (20, 'funciones sin search_path fijo', '0', k20::text, k20 = 0);
end $$;

select * from _pruebas order by n;
