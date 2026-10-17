-- =====================================================================
-- c7-pruebas.sql — la conexión con Plaid se prueba a sí misma (c7-plaid.sql).
-- 17-oct-2026. Se pega DESPUÉS de c7 (o se corre en el banco de pruebas:
-- ./correr.sh … docs/conta/c7-pruebas.sql). Cada prueba escribe dentro de
-- una subtransacción y lo deshace (MXT00): nada queda, ni en Vault.
-- Lo que mira: quién puede llamar qué (la función de borde como postgres sí;
-- service_role, el dueño, el equipo y anon por la API, no), el token en Vault
-- y nunca en la tabla, la propuesta de cuentas por los 4 últimos, fijar la
-- cuenta con sus reglas, recibir lotes EN NOMBRE DEL DUEÑO (importado_por el
-- dueño, importado_rol el de la conexión), todo o nada, lo repetido, lo
-- quitado, el error, desconectar y volver a conectar, la rutina (pg_net con
-- el secreto de Vault), el freno de las cuentas sin fijar, y que los
-- controles de c2 («permisos») y c6 («protecciones del banco») siguen en
-- verde con c7 puesto.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: el dueño, alguien del equipo, un banco y una tarjeta del plan.
create temp table if not exists _c7 (k text primary key, v text);
truncate _c7;
insert into _c7
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c7
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c7
select 'banco', c.codigo from cuentas c where fn_banco_tipo_cuenta(c.codigo) = 'banco' order by c.codigo limit 1;
insert into _c7
select 'tarjeta', t.cuenta from tarjetas t where t.activa and fn_banco_tipo_cuenta(t.cuenta) = 'tarjeta' order by t.ultimos4 limit 1;
insert into _c7
select 'mask', t.ultimos4 from tarjetas t where t.cuenta = (select v from _c7 where k = 'tarjeta') order by 1 limit 1;
grant select on _c7 to public;  -- las pruebas cambian de rol (service_role, el dueño, anon) y siguen leyendo lo común

create or replace function pg_temp.c7(k text) returns text language sql as $$ select v from _c7 where v is not null and k = $1 $$;
-- las cuentas de Plaid de la prueba (la forma de /accounts/get, resumida)
create or replace function pg_temp.c7_cuentas() returns jsonb language sql as $$
  select jsonb_build_array(
    jsonb_build_object('account_id', 'acc-prueba-corriente', 'mask', '4392', 'nombre', 'Business Checking', 'oficial', 'Chase Business Complete Checking', 'tipo', 'depository', 'subtipo', 'checking'),
    jsonb_build_object('account_id', 'acc-prueba-tarjeta', 'mask', pg_temp.c7('mask'), 'nombre', 'Business Card', 'oficial', 'Tarjeta de prueba', 'tipo', 'credit', 'subtipo', 'credit card'),
    jsonb_build_object('account_id', 'acc-prueba-personal', 'mask', '9911', 'nombre', 'Personal Savings', 'oficial', null, 'tipo', 'depository', 'subtipo', 'savings'))
$$;
-- ser la función de borde (como postgres) / service_role (que ya no puede nada) / el dueño / el equipo / anon
create or replace function pg_temp.c7_ser(quien text) returns void language plpgsql as $$
begin
  if quien = 'servicio' then
    -- la función de borde entra como postgres (aquí, el dueño del banco de pruebas): sin cambiar de rol
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien = 'servicio_role' then
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute 'set local role service_role';
  elsif quien = 'anon' then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c7(quien), 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', pg_temp.c7(quien), true);
    execute 'set local role authenticated';
  end if;
end $$;
-- fijar las tres cuentas de la prueba (el banco, la tarjeta ya propuesta, la personal a «ignorar»)
create or replace function pg_temp.c7_fijar_todo() returns void language plpgsql as $$
begin
  perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco'));
  perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-personal', 'ignorar');
end $$;
-- un lote de Plaid con filas inventadas para una cuenta del plan
create or replace function pg_temp.c7_lote(p_cuenta text, p_sufijo text default '', p_quitadas jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object(
    'origen', 'plaid', 'cuenta', p_cuenta, 'nombre', 'Plaid · prueba c7 · ' || p_cuenta || p_sufijo,
    'plaid_saldo', case when p_cuenta like '2100-%' then '1234.56' else '15979.78' end,
    'saldo_al', current_date::text,
    'filas', jsonb_build_array(
      jsonb_build_object('id', 'c7-tx-1' || p_sufijo, 'fecha', (current_date - 3)::text, 'plaid_monto', '171.98', 'descripcion', 'C7 PRUEBAS FERRETERIA', 'tipo', 'DEBIT', 'pendiente', false),
      jsonb_build_object('id', 'c7-tx-2' || p_sufijo, 'fecha', (current_date - 2)::text, 'plaid_monto', '-2500.00', 'descripcion', 'C7 PRUEBAS DEPOSITO', 'tipo', 'CREDIT', 'pendiente', false),
      jsonb_build_object('id', 'c7-tx-3p' || p_sufijo, 'fecha', (current_date - 1)::text, 'plaid_monto', '450.00', 'descripcion', 'C7 PRUEBAS PENDIENTE', 'tipo', 'DEBIT', 'pendiente', true)),
    'quitadas', p_quitadas)
$$;

-- 1. anon no ve las conexiones (ni la configuración)
do $$
declare v_obt text;
begin
  begin
    perform pg_temp.c7_ser('anon');
    select count(*)::text || ' filas' into v_obt from v_plaid_conexiones;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate;
  end;
  insert into _pruebas values (1, 'anon lee v_plaid_conexiones', 'error 42501', v_obt, v_obt = 'error 42501');
end $$;

-- 2. El equipo no da de alta un banco ni lee el token
do $$
declare v_obt text; v_obt2 text;
begin
  if pg_temp.c7('equipo') is null then
    insert into _pruebas values (2, 'equipo: alta y token', '42501 y 42501', 'omitida: no hay perfil de equipo', null); return;
  end if;
  begin
    perform pg_temp.c7_ser('equipo');
    begin
      perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
      v_obt := 'entró';
    exception when others then v_obt := sqlstate; end;
    begin
      perform fn_plaid_token('item-c7');
      v_obt2 := 'entró';
    exception when others then v_obt2 := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate;
  end;
  insert into _pruebas values (2, 'equipo: alta y token', '42501 y 42501', v_obt || ' y ' || v_obt2, v_obt = '42501' and v_obt2 = '42501');
end $$;

-- 3. El dueño tampoco da de alta ni lee el token ni recibe (eso es de la función de borde)
do $$
declare v_a text; v_t text; v_r text;
begin
  begin
    perform pg_temp.c7_ser('dueno');
    begin perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid); v_a := 'entró';
    exception when others then v_a := sqlstate; end;
    begin perform fn_plaid_token('item-c7'); v_t := 'entró';
    exception when others then v_t := sqlstate; end;
    begin perform fn_plaid_recibir('item-c7', '[]'::jsonb, 'c'); v_r := 'entró';
    exception when others then v_r := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_a := 'error ' || sqlstate;
  end;
  insert into _pruebas values (3, 'dueño: alta, token y recibir', '42501 ×3', format('%s %s %s', v_a, v_t, v_r), v_a = '42501' and v_t = '42501' and v_r = '42501');
end $$;

-- 4. service_role da de alta: el token va a Vault (no a la tabla), la tarjeta
--    se propone por sus 4 últimos, el banco y la personal quedan sin fijar
do $$
declare v_res jsonb; v_obt text; v_tok text; v_en_tabla int;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    v_res := fn_plaid_item_alta('item-c7', 'access-sandbox-c7-secreto', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    v_tok := fn_plaid_token('item-c7');
    execute 'reset role';  -- a mirar la tabla con los ojos del editor
    select count(*) into v_en_tabla from plaid_conexiones c where c::text like '%access-sandbox-c7-secreto%';
    v_obt := format('%s | tarjeta→%s | sin fijar %s | token %s | en tabla %s | estado %s',
                    v_res->>'institucion',
                    (select x->>'cuenta' from jsonb_array_elements(v_res->'cuentas') x where x->>'account_id' = 'acc-prueba-tarjeta'),
                    v_res->>'cuentas_sin_fijar', case when v_tok = 'access-sandbox-c7-secreto' then 'ok' else 'MAL' end, v_en_tabla, v_res->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'la función (como postgres): alta, propuesta y token en Vault',
    format('Banco de prueba | tarjeta→%s | sin fijar 2 | token ok | en tabla 0 | estado activa', pg_temp.c7('tarjeta')), v_obt,
    v_obt = format('Banco de prueba | tarjeta→%s | sin fijar 2 | token ok | en tabla 0 | estado activa', pg_temp.c7('tarjeta')));
end $$;

-- 5. El dueño fija las cuentas: el banco a su cuenta, la personal a «ignorar»;
--    una tarjeta a un banco (y al revés) no entra; dos cuentas a la misma, no
do $$
declare v_res jsonb; v_obt text; e1 text; e2 text; e3 text; e4 text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('tarjeta')); e1 := 'entró'; exception when others then e1 := sqlstate; end;
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-tarjeta', pg_temp.c7('banco')); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', '6300'); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco'));
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-personal', pg_temp.c7('banco')); e4 := 'entró'; exception when others then e4 := sqlstate; end;
    v_res := fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-personal', 'ignorar');
    v_obt := format('%s %s %s %s | corriente→%s personal→%s | sin fijar %s', e1, e2, e3, e4,
                    (select x->>'cuenta' from jsonb_array_elements(v_res->'cuentas') x where x->>'account_id' = 'acc-prueba-corriente'),
                    (select x->>'cuenta' from jsonb_array_elements(v_res->'cuentas') x where x->>'account_id' = 'acc-prueba-personal'),
                    v_res->>'cuentas_sin_fijar');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la función fija las cuentas con sus reglas',
    format('MX004 MX004 MX004 MX008 | corriente→%s personal→ignorar | sin fijar 0', pg_temp.c7('banco')), v_obt,
    v_obt = format('MX004 MX004 MX004 MX008 | corriente→%s personal→ignorar | sin fijar 0', pg_temp.c7('banco')));
end $$;

-- 6. Nadie fija cuentas por la API (ni el dueño: lo pide por la función de borde)
do $$
declare v_obt text; e1 text; e2 text; e3 text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    if pg_temp.c7('equipo') is not null then
      perform pg_temp.c7_ser('equipo');
      begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco')); e1 := 'entró'; exception when others then e1 := sqlstate; end;
      execute 'reset role';
    else e1 := '42501'; end if;
    perform pg_temp.c7_ser('anon');
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco')); e2 := 'entró'; exception when others then e2 := sqlstate; end;
    execute 'reset role';
    perform pg_temp.c7_ser('dueno');
    begin perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco')); e3 := 'entró'; exception when others then e3 := sqlstate; end;
    v_obt := e1 || ' ' || e2 || ' ' || e3;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'equipo, anon y el dueño por la API no fijan cuentas (va por la función)', '42501 42501 42501', v_obt, v_obt = '42501 42501 42501');
end $$;

-- 7. RECIBIR: dos lotes (banco y tarjeta) entran en nombre del dueño, casan,
--    y la conexión guarda cursor, hora y resultado. La pendiente no entra.
do $$
declare v_res jsonb; v_obt text; v_n int; v_por uuid; v_rol text; v_saldo numeric; v_arch int;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_fijar_todo();
    v_res := fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('banco')), pg_temp.c7_lote(pg_temp.c7('tarjeta'))), 'cursor-1',
                              jsonb_build_object('paginas', 2));
    execute 'reset role';
    select count(*), min(a.importado_por::text)::uuid, min(a.importado_rol) into v_n, v_por, v_rol
      from movimientos_banco m join archivos_banco a on a.id = m.archivo_id
     where m.origen = 'plaid' and m.descripcion like 'C7 PRUEBAS%';
    select count(*) into v_arch from archivos_banco where formato = 'plaid' and nombre like 'Plaid · prueba c7%';
    select saldo_banco into v_saldo from v_banco_saldos where cuenta = pg_temp.c7('banco');
    v_obt := format('%s movs | por %s | rol %s | archivos %s | cursor %s | lotes %s | nuevas %s | fuera %s | paginas %s | saldo banco %s | sync %s | error %s',
                    v_n, case when v_por = pg_temp.c7('dueno')::uuid then 'dueño' else coalesce(v_por::text, 'nadie') end,
                    case when v_rol = session_user::text then 'el de la conexión' else v_rol end, v_arch,
                    v_res->>'cursor', v_res->'ultimo_resultado'->>'lotes',
                    (select sum((x->>'filas_nuevas')::int) from jsonb_array_elements(v_res->'ultimo_resultado'->'importado') x),
                    (select sum((x->>'filas_fuera')::int) from jsonb_array_elements(v_res->'ultimo_resultado'->'importado') x),
                    v_res->'ultimo_resultado'->>'paginas', v_saldo, case when v_res->>'ultimo_sync' is null then 'sin hora' else 'con hora' end,
                    coalesce(v_res->>'ultimo_error', 'ninguno'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'recibir dos lotes en nombre del dueño',
    '4 movs | por dueño | rol el de la conexión | archivos 2 | cursor cursor-1 | lotes 2 | nuevas 4 | fuera 2 | paginas 2 | saldo banco 15979.78 | sync con hora | error ninguno', v_obt,
    v_obt = '4 movs | por dueño | rol el de la conexión | archivos 2 | cursor cursor-1 | lotes 2 | nuevas 4 | fuera 2 | paginas 2 | saldo banco 15979.78 | sync con hora | error ninguno');
end $$;

-- 8. Nada queda después de deshacer (ni el token en Vault, ni archivos, ni movimientos)
do $$
declare v_obt text;
begin
  select format('%s conexiones de prueba, %s secretos, %s archivos, %s movimientos',
                (select count(*) from plaid_conexiones where item_id = 'item-c7'),
                (select count(*) from vault.secrets where name = 'plaid_item_item-c7'),
                (select count(*) from archivos_banco where nombre like 'Plaid · prueba c7%'),
                (select count(*) from movimientos_banco where descripcion like 'C7 PRUEBAS%')) into v_obt;
  insert into _pruebas values (8, 'nada queda al deshacer', '0 conexiones de prueba, 0 secretos, 0 archivos, 0 movimientos', v_obt,
                               v_obt = '0 conexiones de prueba, 0 secretos, 0 archivos, 0 movimientos');
end $$;

-- 9. TODO O NADA: un lote malo (origen csv) tira la llamada entera; el cursor no avanza
do $$
declare v_obt text; v_err text; v_n int; v_cur text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_fijar_todo();
    begin
      perform fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('banco')), pg_temp.c7_lote(pg_temp.c7('tarjeta')) || '{"origen":"csv"}'::jsonb), 'cursor-malo');
      v_err := 'entró';
    exception when others then v_err := sqlstate; end;
    execute 'reset role';
    select count(*) into v_n from movimientos_banco where descripcion like 'C7 PRUEBAS%';
    select cursor into v_cur from plaid_conexiones where item_id = 'item-c7';
    v_obt := format('%s | %s movimientos | cursor %s', v_err, v_n, coalesce(v_cur, 'nulo'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'todo o nada: un lote malo no deja nada', '22023 | 0 movimientos | cursor nulo', v_obt, v_obt = '22023 | 0 movimientos | cursor nulo');
end $$;

-- 10. Lo repetido no entra dos veces; lo quitado se ignora con su motivo;
--     una quitada que nunca entró (la pendiente) no estorba
do $$
declare v_res jsonb; v_obt text; v_rep int; v_nue int; v_est text; v_mot text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_fijar_todo();
    perform fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('banco'))), 'cursor-1');
    v_res := fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('banco'), '', '["c7-tx-1", "c7-tx-3p"]'::jsonb)), 'cursor-2');
    execute 'reset role';
    select sum((x->>'filas_repetidas')::int), sum((x->>'filas_nuevas')::int) into v_rep, v_nue from jsonb_array_elements(v_res->'ultimo_resultado'->'importado') x;
    select m.estado, left(coalesce(m.estado_motivo, ''), 14) into v_est, v_mot
      from movimientos_banco m where m.descripcion = 'C7 PRUEBAS FERRETERIA' and m.origen = 'plaid' limit 1;
    v_obt := format('repetidas %s nuevas %s | quitada: %s «%s» | cursor %s', v_rep, v_nue, v_est, v_mot, v_res->>'cursor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'repetidas y quitadas', 'repetidas 2 nuevas 0 | quitada: ignorado «Plaid lo quitó» | cursor cursor-2', v_obt,
                               v_obt = 'repetidas 2 nuevas 0 | quitada: ignorado «Plaid lo quitó» | cursor cursor-2');
end $$;

-- 11. El error se escribe sin tocar el cursor; el siguiente recibir lo limpia
do $$
declare v_res jsonb; v_obt text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_fijar_todo();
    perform fn_plaid_recibir('item-c7', '[]'::jsonb, 'cursor-1');
    v_res := fn_plaid_error('item-c7', 'ITEM_LOGIN_REQUIRED: the login details of this item have changed');
    v_obt := format('%s | %s | %s', v_res->>'estado', left(v_res->>'ultimo_error', 19), v_res->>'cursor');
    v_res := fn_plaid_recibir('item-c7', '[]'::jsonb, 'cursor-2');
    v_obt := v_obt || format(' → %s | %s | %s', v_res->>'estado', coalesce(v_res->>'ultimo_error', 'ninguno'), v_res->>'cursor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'el error y su limpieza', 'error | ITEM_LOGIN_REQUIRED | cursor-1 → activa | ninguno | cursor-2', v_obt,
                               v_obt = 'error | ITEM_LOGIN_REQUIRED | cursor-1 → activa | ninguno | cursor-2');
end $$;

-- 12. Desconectar (el dueño): el token se borra de Vault, no recibe más, el
--     token ya no se lee; volver a conectar conserva lo que Edgar fijó
do $$
declare v_res jsonb; v_obt text; e_r text; e_t text; v_sec int;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco'));
    v_res := fn_plaid_desconectar('item-c7', 'prueba');
    select count(*) into v_sec from vault.secrets where name = 'plaid_item_item-c7';
    begin perform fn_plaid_recibir('item-c7', '[]'::jsonb, 'x'); e_r := 'entró'; exception when others then e_r := sqlstate; end;
    begin perform fn_plaid_token('item-c7'); e_t := 'entró'; exception when others then e_t := sqlstate; end;
    v_obt := format('%s | motivo %s | secretos %s | token %s | recibir %s | tiene_token %s', v_res->>'estado', v_res->>'desconectada_motivo', v_sec, e_t, e_r, v_res->>'tiene_token');
    v_res := fn_plaid_item_alta('item-c7', 'access-c7-nuevo', 'ins_1', null, pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    v_obt := v_obt || format(' → %s | corriente→%s | %s | token %s', v_res->>'estado',
                             (select x->>'cuenta' from jsonb_array_elements(v_res->'cuentas') x where x->>'account_id' = 'acc-prueba-corriente'),
                             v_res->>'institucion', case when fn_plaid_token('item-c7') = 'access-c7-nuevo' then 'nuevo' else 'viejo' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'desconectar y volver a conectar',
    format('desconectada | motivo prueba | secretos 0 | token MX004 | recibir MX008 | tiene_token false → activa | corriente→%s | Banco de prueba | token nuevo', pg_temp.c7('banco')), v_obt,
    v_obt = format('desconectada | motivo prueba | secretos 0 | token MX004 | recibir MX008 | tiene_token false → activa | corriente→%s | Banco de prueba | token nuevo', pg_temp.c7('banco')));
end $$;

-- 13. Una segunda conexión no puede llevarse una cuenta que ya trae la primera
do $$
declare v_obt text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform fn_plaid_item_alta('item-c7-b', 'access-c7-b', 'ins_2', 'Otro banco', jsonb_build_array(jsonb_build_object('account_id', 'acc-b', 'mask', '1111', 'tipo', 'depository')), pg_temp.c7('dueno')::uuid);
    perform fn_plaid_cuenta_fijar('item-c7', 'acc-prueba-corriente', pg_temp.c7('banco'));
    begin perform fn_plaid_cuenta_fijar('item-c7-b', 'acc-b', pg_temp.c7('banco')); v_obt := 'entró'; exception when others then v_obt := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'la misma cuenta del plan en dos conexiones', 'MX008', v_obt, v_obt = 'MX008');
end $$;

-- 14. El dueño ve la conexión en la vista (con cuentas_sin_fijar); el equipo, nada
do $$
declare v_obt text; v_d text; v_e text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_ser('dueno');
    select format('%s fila(s), sin fijar %s', count(*), min(cuentas_sin_fijar)) into v_d from v_plaid_conexiones where item_id = 'item-c7';
    execute 'reset role';
    if pg_temp.c7('equipo') is not null then
      perform pg_temp.c7_ser('equipo');
      select count(*)::text || ' fila(s)' into v_e from v_plaid_conexiones;
    else v_e := '0 fila(s)'; end if;
    v_obt := v_d || ' | equipo ' || v_e;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'la vista: dueño sí, equipo no', '1 fila(s), sin fijar 2 | equipo 0 fila(s)', v_obt, v_obt = '1 fila(s), sin fijar 2 | equipo 0 fila(s)');
end $$;

-- 15. La rutina: con una conexión viva manda el POST a la función con el
--     secreto de Vault; sin conexiones, no manda nada. (Aquí pg_net es el
--     stub del banco: en producción encola la llamada de verdad.)
do $$
declare v_obt text; v_id bigint; v_antes int; v_desp int; v_ok text; v_nada bigint;
begin
  begin
    v_nada := fn_plaid_programado();
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    execute 'reset role';
    if to_regclass('net._llamadas') is null then
      v_obt := 'omitida: el stub de pg_net no guarda las llamadas (sin pruebas/seguridad/00-vault-shim.sql)';
    else
      execute 'select count(*) from net._llamadas' into v_antes;
      v_id := fn_plaid_programado();
      execute 'select count(*) from net._llamadas' into v_desp;
      execute $q$ select case when l.url = (select funcion_url from plaid_config) and l.body->>'accion' = 'sincronizar_todo'
                                   and l.headers->>'x-mxp-rutina' = (select decrypted_secret from vault.decrypted_secrets where name = 'plaid_rutina_secreto')
                              then 'url, acción y secreto bien' else 'MAL: ' || l.url || ' ' || l.body::text end
                    from net._llamadas l order by l.id desc limit 1 $q$ into v_ok;
      v_obt := format('sin conexiones → %s | con una → %s llamada(s), %s', coalesce(v_nada::text, 'nada'), v_desp - v_antes, v_ok);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'la rutina diaria (pg_net con el secreto)', 'sin conexiones → nada | con una → 1 llamada(s), url, acción y secreto bien', v_obt,
                               case when v_obt like 'omitida%' then null else v_obt = 'sin conexiones → nada | con una → 1 llamada(s), url, acción y secreto bien' end);
end $$;

-- 16. El dueño no dispara la rutina desde la API (42501)
do $$
declare v_obt text;
begin
  begin
    perform pg_temp.c7_ser('dueno');
    begin perform fn_plaid_programado(); v_obt := 'entró'; exception when others then v_obt := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'el dueño no dispara la rutina por la API', '42501', v_obt, v_obt = '42501');
end $$;

-- 17. Alta con un dueño que no es el dueño (alguien del equipo): no entra
do $$
declare v_obt text;
begin
  if pg_temp.c7('equipo') is null then
    insert into _pruebas values (17, 'alta a nombre de alguien del equipo', '42501', 'omitida: no hay perfil de equipo', null); return;
  end if;
  begin
    perform pg_temp.c7_ser('servicio');
    begin perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('equipo')::uuid); v_obt := 'entró';
    exception when others then v_obt := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'alta a nombre de alguien del equipo', '42501', v_obt, v_obt = '42501');
end $$;

-- 18. Un lote sin «cuenta» no entra (MX004 de c6: no sabe de qué cuenta es)
do $$
declare v_obt text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_fijar_todo();
    begin perform fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('banco')) - 'cuenta'), 'c'); v_obt := 'entró';
    exception when others then v_obt := sqlstate; end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'un lote sin cuenta no entra', 'MX004', v_obt, v_obt = 'MX004');
end $$;

-- 19. EL FRENO: con una cuenta sin fijar no se recibe nada y el cursor no avanza
do $$
declare v_obt text; v_cur text;
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    begin perform fn_plaid_recibir('item-c7', jsonb_build_array(pg_temp.c7_lote(pg_temp.c7('tarjeta'))), 'cursor-1'); v_obt := 'entró';
    exception when others then v_obt := sqlstate || ' ' || regexp_replace(sqlerrm, ':.*$', ''); end;
    execute 'reset role';
    select coalesce(cursor, 'nulo') into v_cur from plaid_conexiones where item_id = 'item-c7';
    v_obt := v_obt || ' | cursor ' || v_cur || ' | movs ' || (select count(*) from movimientos_banco where descripcion like 'C7 PRUEBAS%');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'el freno: cuentas sin fijar', 'MX008 La conexión Banco de prueba tiene cuentas sin fijar (····4392, ····9911) | cursor nulo | movs 0', v_obt,
                               v_obt = 'MX008 La conexión Banco de prueba tiene cuentas sin fijar (····4392, ····9911) | cursor nulo | movs 0');
end $$;

-- 20. service_role (la llave de servicio, por la API) tampoco puede nada de c7:
--     ni alta, ni token, ni recibir, ni error, ni desconectar, ni leer las conexiones
do $$
declare v_obt text; e text[] := '{}';
begin
  begin
    perform pg_temp.c7_ser('servicio');
    perform fn_plaid_item_alta('item-c7', 'access-c7', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid);
    perform pg_temp.c7_ser('servicio_role');
    begin perform fn_plaid_item_alta('item-c7', 'x', 'ins_1', 'Banco de prueba', pg_temp.c7_cuentas(), pg_temp.c7('dueno')::uuid); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    begin perform fn_plaid_token('item-c7'); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    begin perform fn_plaid_recibir('item-c7', '[]'::jsonb, 'c'); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    begin perform fn_plaid_error('item-c7', 'x'); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    begin perform fn_plaid_desconectar('item-c7', 'x'); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    begin perform fn_plaid_activas(); e := e || 'entró'; exception when others then e := e || sqlstate; end;
    v_obt := array_to_string(e, ' ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'service_role por la API no puede nada de c7', '42501 ×6', v_obt, v_obt = '42501 42501 42501 42501 42501 42501');
end $$;

-- 21. Con c7 puesto, los controles de c2 («permisos») y c6 («protecciones
--     del banco») siguen en verde, y ninguna fn_plaid_* es ejecutable por la API
do $$
declare v_obt text; v_c2 text; v_c6 text; v_api text;
begin
  begin
    select coalesce(string_agg(control, ', '), 'verde') into v_c2 from fn_verificar_cadena() where not ok and control = 'permisos';
    select coalesce(string_agg(vista, ', '), 'verde') into v_c6 from fn_banco_control('hoy') where not ok and vista = 'cuadre: protecciones del banco';
    select coalesce(string_agg(p.proname || '→' || g, ', '), 'ninguna') into v_api
      from pg_proc p, unnest(array['anon', 'authenticated', 'service_role']) g
     where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_plaid%' and has_function_privilege(g, p.oid, 'execute');
    v_obt := format('c2 %s | c6 %s | en la API: %s', v_c2, v_c6, v_api);
  exception
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'c2 «permisos» y c6 «protecciones» en verde con c7; nada de c7 en la API', 'c2 verde | c6 verde | en la API: ninguna', v_obt,
                               v_obt = 'c2 verde | c6 verde | en la API: ninguna');
end $$;

select * from _pruebas order by n;
