-- =====================================================================
-- c7-plaid.sql — LA CONEXIÓN AUTOMÁTICA CON EL BANCO (Plaid) · f06 azul
-- 17-oct-2026 · se pega en el SQL Editor DESPUÉS de c6. Idempotente: se
-- puede volver a pegar entero.
--
-- Quién hace qué:
--   · La función de borde `plaid` (supabase/functions/plaid/index.ts) es la
--     única que habla con Plaid, con las llaves que viven en los secretos de
--     Edge Functions (PLAID_CLIENT_ID, PLAID_SECRET, PLAID_ENV). Crea el
--     link token, canjea el public token, pide /transactions/sync y, al
--     desconectar, /item/remove.
--   · La base guarda cada conexión (plaid_conexiones: institución, cuentas de
--     Plaid y a qué cuenta del plan va cada una, cursor, último resultado) y
--     el access_token EN VAULT (vault.secrets, nombre plaid_item_<item_id>):
--     nunca en una tabla normal ni en el navegador.
--   · Lo que Plaid trae entra por fn_banco_importar_filas (origen "plaid",
--     con plaid_monto y plaid_saldo tal cual, la base voltea el signo) y casa
--     con fn_banco_casar_todo: el mismo camino que un archivo QFX. El mismo
--     cargo por Plaid y por archivo entra una sola vez (c6: posible
--     duplicado si Plaid lo trae con otro id).
--   · EN NOMBRE DEL DUEÑO. Las funciones del banco exigen al dueño
--     (es_dueno()). La sincronización de las 6 de la mañana no tiene a Edgar
--     delante: fn_plaid_recibir (security definer, solo service_role) fija
--     auth.uid() al dueño que conectó esa cuenta mientras importa, y después
--     lo quita. Queda escrito: el lote se llama «Plaid · …», importado_rol
--     es service_role (fn_rol_llamante lee el rol de la llamada, no al
--     dueño de la función) y plaid_conexiones.ultimo_resultado guarda qué
--     entró. La función solo recibe lo que la función de borde le manda, y
--     la función de borde solo la llama con la llave de servicio de Supabase.
--   · La rutina diaria: pg_cron (como postgres) → fn_plaid_programado() →
--     pg_net POST a la función de borde con el secreto plaid_rutina_secreto
--     (en Vault; el mismo valor va en el secreto PLAID_RUTINA_SECRETO de Edge
--     Functions). La función sincroniza todas las conexiones activas.
--
-- Lo que llama conta.js (con la sesión del dueño): v_plaid_conexiones (leer),
-- fn_plaid_cuenta_fijar (a qué cuenta del plan va cada cuenta de Plaid) y la
-- función de borde (link_token, canjear, sincronizar, desconectar).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Las tablas
-- ---------------------------------------------------------------------
create table if not exists public.plaid_conexiones (
  id                  uuid        primary key default gen_random_uuid(),
  item_id             text        not null unique,
  institucion_id      text,
  institucion         text,
  estado              text        not null default 'activa',
  cursor              text,                                  -- el cursor de /transactions/sync; nulo = desde el principio
  cuentas             jsonb       not null default '[]'::jsonb,
  -- cada cuenta de Plaid: {"account_id", "mask", "nombre", "oficial", "tipo", "subtipo",
  --   "cuenta": "1010" | "2100-2013" | "ignorar" | (sin la llave = sin fijar), "propuesta": "…"}
  ultimo_sync         timestamptz,
  ultimo_error        text,
  ultimo_resultado    jsonb,
  creado_por          uuid        not null,                  -- el dueño que la conectó: en su nombre importa la rutina
  creado_el           timestamptz not null default now(),
  desconectada_el     timestamptz,
  desconectada_motivo text,
  constraint plaid_conexiones_estado check (estado in ('activa', 'error', 'desconectada'))
);
comment on table public.plaid_conexiones is 'Conexiones con Plaid (una por banco). El access_token vive en Vault: plaid_item_<item_id>.';

create table if not exists public.plaid_config (
  id             int         primary key,
  funcion_url    text        not null,
  rutina_activa  boolean     not null default true,
  actualizado    timestamptz not null default now(),
  constraint plaid_config_una check (id = 1)
);
insert into public.plaid_config (id, funcion_url)
values (1, 'https://zeogjvwcmstmkwxjvykz.supabase.co/functions/v1/plaid')
on conflict (id) do nothing;

alter table public.plaid_conexiones enable row level security;
alter table public.plaid_config enable row level security;
drop policy if exists plaid_conexiones_dueno on public.plaid_conexiones;
create policy plaid_conexiones_dueno on public.plaid_conexiones for select to authenticated using ((select es_dueno()));
drop policy if exists plaid_config_dueno on public.plaid_config;
create policy plaid_config_dueno on public.plaid_config for select to authenticated using ((select es_dueno()));
-- Nadie de la API escribe (todo entra por las funciones de abajo, security
-- definer); service_role tampoco toca las tablas directamente.
revoke all on public.plaid_conexiones, public.plaid_config from public, anon, authenticated, service_role;
grant select on public.plaid_conexiones, public.plaid_config to authenticated;

-- El secreto con que la rutina diaria se identifica ante la función de borde.
-- Se crea una vez; Edgar copia su valor (lo enseña el select del final) al
-- secreto PLAID_RUTINA_SECRETO de Edge Functions. Nunca por el chat.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'plaid_rutina_secreto') then
    perform vault.create_secret(md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text), 'plaid_rutina_secreto',
                                'La rutina diaria de Plaid (pg_cron → función de borde). El mismo valor va en PLAID_RUTINA_SECRETO.');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Lo interno
-- ---------------------------------------------------------------------
create or replace function public.fn_plaid_vault_nombre(p_item_id text) returns text
language sql immutable
as $$ select 'plaid_item_' || p_item_id $$;
revoke execute on function public.fn_plaid_vault_nombre(text) from public, anon, authenticated, service_role;

-- ¿Quién llama? La función de borde (con la llave de servicio: rol
-- service_role), el SQL Editor / pg_cron (fn_desde_editor), o el dueño con su
-- sesión si p_dueno_vale. Se mira el ROL de la llamada (fn_rol_llamante), no
-- current_user: dentro de una función security definer current_user es el
-- dueño de la función.
create or replace function public.fn_plaid_exigir(p_dueno_vale boolean) returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_rol_llamante() = 'service_role' or fn_desde_editor() then return; end if;
  if p_dueno_vale and es_dueno() then return; end if;
  raise exception using errcode = '42501',
    message = case when p_dueno_vale then 'Esto lo hace solo Edgar (el dueño) o la función de borde de Plaid.'
                   else 'Esto lo hace solo la función de borde de Plaid (service_role).' end;
end $$;
revoke execute on function public.fn_plaid_exigir(boolean) from public, anon, authenticated, service_role;

-- La conexión sin nada secreto (el token está en Vault y nunca sale por aquí)
create or replace function public.fn_plaid_resumen(p_id uuid) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select to_jsonb(c) || jsonb_build_object(
           'cuentas_sin_fijar', (select count(*) from jsonb_array_elements(c.cuentas) x where x->>'cuenta' is null),
           'tiene_token', exists (select 1 from vault.secrets s where s.name = fn_plaid_vault_nombre(c.item_id)))
    from plaid_conexiones c where c.id = p_id
$$;
revoke execute on function public.fn_plaid_resumen(uuid) from public, anon, authenticated, service_role;

-- Las cuentas que Plaid trae, con la propuesta de la casa: una tarjeta cuyos 4
-- últimos están dados de alta en una subcuenta de 2100 va a esa cuenta; un
-- banco no se adivina (Edgar lo fija en la pantalla). Si la conexión ya
-- existía, lo que Edgar ya fijó se conserva.
create or replace function public.fn_plaid_cuentas_proponer(p_nuevas jsonb, p_viejas jsonb) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(
           jsonb_strip_nulls(jsonb_build_object(
             'account_id', n->>'account_id', 'mask', n->>'mask', 'nombre', n->>'nombre', 'oficial', n->>'oficial',
             'tipo', n->>'tipo', 'subtipo', n->>'subtipo',
             'cuenta', coalesce(v.v->>'cuenta', t.cuenta),
             'propuesta', case when v.v->>'cuenta' is not null then 'la que fijó Edgar'
                               when t.cuenta is not null then format('tarjeta ····%s dada de alta en %s', t.ultimos4, t.cuenta) end))
           order by n->>'tipo', n->>'mask'), '[]'::jsonb)
    from jsonb_array_elements(coalesce(p_nuevas, '[]'::jsonb)) n
    left join lateral (select v from jsonb_array_elements(coalesce(p_viejas, '[]'::jsonb)) v
                        where v->>'account_id' = n->>'account_id' limit 1) v on true
    left join tarjetas t on t.ultimos4 = right(coalesce(n->>'mask', ''), 4) and t.activa and left(t.cuenta, 5) = '2100-'
                        and n->>'tipo' = 'credit'
$$;
revoke execute on function public.fn_plaid_cuentas_proponer(jsonb, jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Lo que llama la función de borde (service_role)
-- ---------------------------------------------------------------------
-- Alta (o reconexión) de un banco: guarda el token en Vault y la conexión.
create or replace function public.fn_plaid_item_alta(p_item_id text, p_access_token text, p_institucion_id text, p_institucion text,
                                                     p_cuentas jsonb, p_dueno uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id   uuid;
  v_nom  text := fn_plaid_vault_nombre(p_item_id);
  v_sec  uuid;
  c      plaid_conexiones;
begin
  perform fn_plaid_exigir(false);
  if fn_banco_limpio(p_item_id) is null or fn_banco_limpio(p_access_token) is null then
    raise exception using errcode = '22023', message = 'Faltan el item_id o el access_token de Plaid.';
  end if;
  if not exists (select 1 from perfiles p where p.id = p_dueno and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501', message = 'Solo el dueño conecta un banco.';
  end if;
  if jsonb_typeof(coalesce(p_cuentas, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'Las cuentas de Plaid llegan como una lista.';
  end if;
  select id into v_sec from vault.secrets where name = v_nom;
  if v_sec is null then
    perform vault.create_secret(p_access_token, v_nom, 'Plaid access token · ' || coalesce(p_institucion, p_item_id));
  else
    perform vault.update_secret(v_sec, p_access_token);
  end if;
  select * into c from plaid_conexiones where item_id = p_item_id;
  if c.id is null then
    insert into plaid_conexiones (item_id, institucion_id, institucion, cuentas, creado_por)
    values (p_item_id, p_institucion_id, p_institucion, fn_plaid_cuentas_proponer(p_cuentas, null), p_dueno)
    returning id into v_id;
  else
    update plaid_conexiones
       set institucion_id = coalesce(p_institucion_id, institucion_id), institucion = coalesce(p_institucion, institucion),
           cuentas = fn_plaid_cuentas_proponer(p_cuentas, c.cuentas),
           estado = 'activa', ultimo_error = null, desconectada_el = null, desconectada_motivo = null
     where id = c.id
    returning id into v_id;
  end if;
  return fn_plaid_resumen(v_id);
end $$;
revoke execute on function public.fn_plaid_item_alta(text, text, text, text, jsonb, uuid) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_item_alta(text, text, text, text, jsonb, uuid) to service_role;

-- El token, solo para la función de borde
create or replace function public.fn_plaid_token(p_item_id text) returns text
language plpgsql stable
security definer
set search_path = public, pg_temp
as $$
declare v text;
begin
  perform fn_plaid_exigir(false);
  select s.decrypted_secret into v from vault.decrypted_secrets s where s.name = fn_plaid_vault_nombre(p_item_id);
  if v is null then
    raise exception using errcode = 'MX004', message = format('No hay token de Plaid para la conexión %s (¿desconectada?).', p_item_id);
  end if;
  return v;
end $$;
revoke execute on function public.fn_plaid_token(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_token(text) to service_role;

-- La conexión (cursor y cuentas) para sincronizar
create or replace function public.fn_plaid_conexion(p_item_id text) returns jsonb
language plpgsql stable
security definer
set search_path = public, pg_temp
as $$
declare v uuid;
begin
  perform fn_plaid_exigir(true);
  select id into v from plaid_conexiones where item_id = p_item_id;
  if v is null then
    raise exception using errcode = 'MX004', message = format('No hay conexión de Plaid con el item %s.', p_item_id);
  end if;
  return fn_plaid_resumen(v);
end $$;
revoke execute on function public.fn_plaid_conexion(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_conexion(text) to service_role, authenticated;

-- Las conexiones que no están desconectadas (para la rutina)
create or replace function public.fn_plaid_activas() returns jsonb
language plpgsql stable
security definer
set search_path = public, pg_temp
as $$
begin
  perform fn_plaid_exigir(true);
  return coalesce((select jsonb_agg(fn_plaid_resumen(c.id) order by c.creado_el) from plaid_conexiones c where c.estado <> 'desconectada'),
                  '[]'::jsonb);
end $$;
revoke execute on function public.fn_plaid_activas() from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_activas() to service_role, authenticated;

-- LO QUE PLAID TRAJO, al libro. Un lote por cuenta (origen plaid, ver
-- fn_banco_importar_filas); después «Casar» de cada cuenta. Todo en una
-- transacción: si un lote no entra, nada entra y el cursor no avanza (la
-- función de borde vuelve a pedir desde el cursor viejo). En nombre del
-- dueño que conectó (ver la cabecera).
create or replace function public.fn_plaid_recibir(p_item_id text, p_lotes jsonb, p_cursor text, p_resultado jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c        plaid_conexiones;
  v_l      jsonb;
  v_r      jsonb;
  v_imp    jsonb := '[]'::jsonb;
  v_cas    jsonb := '[]'::jsonb;
  v_cta    text;
  v_claims text;
  v_sub    text;
  i        int;
begin
  perform fn_plaid_exigir(false);
  select * into c from plaid_conexiones where item_id = p_item_id for update;
  if c.id is null then
    raise exception using errcode = 'MX004', message = format('No hay conexión de Plaid con el item %s.', p_item_id);
  end if;
  if c.estado = 'desconectada' then
    raise exception using errcode = 'MX008', message = format('La conexión %s está desconectada: no recibe nada.', coalesce(c.institucion, p_item_id));
  end if;
  if jsonb_typeof(coalesce(p_lotes, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'Los lotes llegan como una lista (uno por cuenta).';
  end if;
  -- EL FRENO: con una cuenta de Plaid sin fijar no entra nada y el cursor no
  -- avanza. Si entrara, lo de esa cuenta ya consumido por el cursor no
  -- volvería a venir de Plaid. (La función de borde lo mira antes de pedir
  -- nada a Plaid; aquí es la guarda.)
  if exists (select 1 from jsonb_array_elements(c.cuentas) x where x->>'cuenta' is null) then
    raise exception using errcode = 'MX008',
      message = format('La conexión %s tiene cuentas sin fijar (····%s): di a qué cuenta del plan va cada una, o «ignorar», antes de sincronizar.',
                       coalesce(c.institucion, p_item_id),
                       (select string_agg(coalesce(x->>'mask', '?'), ', ····') from jsonb_array_elements(c.cuentas) x where x->>'cuenta' is null));
  end if;
  -- en nombre del dueño que conectó la cuenta, solo dentro de esta transacción
  v_claims := current_setting('request.jwt.claims', true);
  v_sub    := current_setting('request.jwt.claim.sub', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', c.creado_por, 'role', 'authenticated', 'plaid_rutina', true)::text, true);
  perform set_config('request.jwt.claim.sub', c.creado_por::text, true);
  if not es_dueno() then
    raise exception using errcode = '42501', message = 'El dueño que conectó esta cuenta ya no es el dueño: no se importa nada.';
  end if;
  for v_l in select x from jsonb_array_elements(coalesce(p_lotes, '[]'::jsonb)) x loop
    if v_l->>'origen' is distinct from 'plaid' then
      raise exception using errcode = '22023', message = 'Cada lote de Plaid lleva "origen": "plaid".';
    end if;
    v_r := fn_banco_importar_filas(v_l);
    v_imp := v_imp || jsonb_strip_nulls(jsonb_build_object(
      'cuenta', v_r->>'cuenta', 'nombre', v_l->>'nombre', 'archivo', v_r->'archivo', 'ya_estaba', v_r->'ya_estaba',
      'filas_leidas', v_r->'filas_leidas', 'filas_nuevas', v_r->'filas_nuevas', 'filas_repetidas', v_r->'filas_repetidas',
      'filas_fuera', v_r->'filas_fuera', 'antes_del_corte', v_r->'antes_del_corte', 'duplicados_posibles', v_r->'duplicados_posibles',
      'quitadas', v_r->'quitadas', 'saldo', v_r->'saldo', 'saldo_al', v_r->'saldo_al', 'avisos', v_r->'avisos'));
  end loop;
  for v_cta in select distinct x->>'cuenta' from jsonb_array_elements(coalesce(p_lotes, '[]'::jsonb)) x where x->>'cuenta' is not null loop
    i := 0;
    loop
      v_r := fn_banco_casar_todo(v_cta);
      i := i + 1;
      exit when coalesce((v_r->>'completo')::boolean, true) or i >= 10;
    end loop;
    v_cas := v_cas || jsonb_build_object('cuenta', v_cta, 'casados', v_r->'casados', 'pendientes', v_r->'pendientes',
                                         'por_motivo', v_r->'por_motivo', 'rondas', i);
  end loop;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  update plaid_conexiones
     set cursor = coalesce(p_cursor, cursor), ultimo_sync = now(), ultimo_error = null, estado = 'activa',
         ultimo_resultado = jsonb_build_object('cuando', now(), 'lotes', jsonb_array_length(coalesce(p_lotes, '[]'::jsonb)),
                                               'importado', v_imp, 'casado', v_cas) || coalesce(p_resultado, '{}'::jsonb)
   where id = c.id;
  return fn_plaid_resumen(c.id);
end $$;
revoke execute on function public.fn_plaid_recibir(text, jsonb, text, jsonb) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_recibir(text, jsonb, text, jsonb) to service_role;

-- Un error de Plaid o de la importación, escrito en la conexión (sin tocar el cursor)
create or replace function public.fn_plaid_error(p_item_id text, p_error text) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v uuid;
begin
  perform fn_plaid_exigir(false);
  update plaid_conexiones
     set ultimo_error = left(coalesce(p_error, 'error'), 600), estado = case when estado = 'desconectada' then estado else 'error' end
   where item_id = p_item_id
  returning id into v;
  if v is null then
    raise exception using errcode = 'MX004', message = format('No hay conexión de Plaid con el item %s.', p_item_id);
  end if;
  return fn_plaid_resumen(v);
end $$;
revoke execute on function public.fn_plaid_error(text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_error(text, text) to service_role;

-- Desconectar: la función de borde ya pidió /item/remove a Plaid; aquí se
-- borra el token de Vault y la conexión queda desconectada, con su motivo.
-- (El dueño también puede marcarla desde la pantalla si Plaid ya no la
-- reconoce; lo normal es por la función de borde, que avisa a Plaid.)
create or replace function public.fn_plaid_desconectar(p_item_id text, p_motivo text default null) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v uuid;
begin
  perform fn_plaid_exigir(true);
  update plaid_conexiones
     set estado = 'desconectada', desconectada_el = now(), desconectada_motivo = fn_banco_limpio(p_motivo), cursor = null
   where item_id = p_item_id
  returning id into v;
  if v is null then
    raise exception using errcode = 'MX004', message = format('No hay conexión de Plaid con el item %s.', p_item_id);
  end if;
  delete from vault.secrets where name = fn_plaid_vault_nombre(p_item_id);
  return fn_plaid_resumen(v);
end $$;
revoke execute on function public.fn_plaid_desconectar(text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_desconectar(text, text) to service_role, authenticated;

-- ---------------------------------------------------------------------
-- 4. Lo que llama la pantalla (el dueño)
-- ---------------------------------------------------------------------
-- A qué cuenta del plan va cada cuenta de Plaid: un banco (10xx) para una
-- cuenta depository, una tarjeta de la empresa (2100-…) para una credit, o
-- 'ignorar' si no es de la empresa (una cuenta personal bajo el mismo
-- usuario del banco). Sin esto, esa cuenta no se importa.
create or replace function public.fn_plaid_cuenta_fijar(p_item_id text, p_account_id text, p_cuenta text) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c      plaid_conexiones;
  v_cta  text;
  v_tipo text;
  v_pl   text;
begin
  perform fn_plaid_exigir(true);
  select * into c from plaid_conexiones where item_id = p_item_id for update;
  if c.id is null then
    raise exception using errcode = 'MX004', message = format('No hay conexión de Plaid con el item %s.', p_item_id);
  end if;
  select x->>'tipo' into v_pl from jsonb_array_elements(c.cuentas) x where x->>'account_id' = p_account_id;
  if not found then
    raise exception using errcode = 'MX004', message = 'Esa cuenta de Plaid no está en la conexión.';
  end if;
  v_cta := fn_banco_limpio(p_cuenta);
  if v_cta is null then
    raise exception using errcode = '22023', message = 'Di la cuenta del plan (''1010'', ''2100-2013''), o ''ignorar''.';
  end if;
  if v_cta <> 'ignorar' then
    v_cta := fn_banco_cuenta_resolver(v_cta);
    v_tipo := fn_banco_tipo_cuenta(v_cta);
    if v_tipo is null then
      raise exception using errcode = 'MX004',
        message = format('%s no es un banco (10xx) ni una tarjeta de crédito de la empresa (2100-…).', p_cuenta);
    end if;
    if v_pl = 'credit' and v_tipo <> 'tarjeta' then
      raise exception using errcode = 'MX004', message = format('La cuenta de Plaid es una tarjeta de crédito y %s es un banco.', v_cta);
    end if;
    if v_pl = 'depository' and v_tipo <> 'banco' then
      raise exception using errcode = 'MX004', message = format('La cuenta de Plaid es una cuenta de banco y %s es una tarjeta.', v_cta);
    end if;
    if exists (select 1 from jsonb_array_elements(c.cuentas) x where x->>'account_id' <> p_account_id and x->>'cuenta' = v_cta) then
      raise exception using errcode = 'MX008', message = format('Otra cuenta de esta conexión ya va a %s.', v_cta);
    end if;
    if exists (select 1 from plaid_conexiones o, jsonb_array_elements(o.cuentas) x
                where o.id <> c.id and o.estado <> 'desconectada' and x->>'cuenta' = v_cta) then
      raise exception using errcode = 'MX008', message = format('Otra conexión de Plaid ya trae %s.', v_cta);
    end if;
  end if;
  update plaid_conexiones
     set cuentas = (select jsonb_agg(case when x->>'account_id' = p_account_id
                                          then x || jsonb_build_object('cuenta', v_cta, 'propuesta', 'la que fijó Edgar')
                                          else x end order by o)
                      from jsonb_array_elements(c.cuentas) with ordinality as t(x, o))
   where id = c.id;
  return fn_plaid_resumen(c.id);
end $$;
revoke execute on function public.fn_plaid_cuenta_fijar(text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_plaid_cuenta_fijar(text, text, text) to authenticated, service_role;

-- La vista de la pantalla
drop view if exists public.v_plaid_conexiones;
create view public.v_plaid_conexiones with (security_invoker = true) as
select c.id, c.item_id, c.institucion_id, c.institucion, c.estado, c.cuentas,
       (select count(*) from jsonb_array_elements(c.cuentas) x where x->>'cuenta' is null) as cuentas_sin_fijar,
       c.cursor is not null as sincronizada_alguna_vez,
       c.ultimo_sync, c.ultimo_error, c.ultimo_resultado, c.creado_por, c.creado_el, c.desconectada_el, c.desconectada_motivo
  from public.plaid_conexiones c;
grant select on public.v_plaid_conexiones to authenticated;

-- ---------------------------------------------------------------------
-- 5. La rutina diaria (pg_cron → pg_net → la función de borde)
-- ---------------------------------------------------------------------
create or replace function public.fn_plaid_programado() returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_url text;
  v_sec text;
  v_id  bigint;
begin
  if not fn_desde_editor() and fn_rol_llamante() <> 'service_role' then
    raise exception using errcode = '42501', message = 'La rutina de Plaid la dispara pg_cron (o el SQL Editor).';
  end if;
  select funcion_url into v_url from plaid_config where id = 1 and rutina_activa;
  if v_url is null then return null; end if;
  if not exists (select 1 from plaid_conexiones where estado <> 'desconectada') then return null; end if;
  select s.decrypted_secret into v_sec from vault.decrypted_secrets s where s.name = 'plaid_rutina_secreto';
  if v_sec is null then
    raise exception using errcode = 'MX009', message = 'Falta el secreto plaid_rutina_secreto en Vault.';
  end if;
  select net.http_post(url := v_url,
                       body := jsonb_build_object('accion', 'sincronizar_todo'),
                       headers := jsonb_build_object('Content-Type', 'application/json', 'x-mxp-rutina', v_sec),
                       timeout_milliseconds := 60000)
    into v_id;
  return v_id;
end $$;
revoke execute on function public.fn_plaid_programado() from public, anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'mxp-plaid-sync';
    -- 11:00 UTC = 6 de la mañana en Miami en invierno (7 en verano)
    perform cron.schedule('mxp-plaid-sync', '0 11 * * *', 'select public.fn_plaid_programado()');
  end if;
end $$;

-- Lo que debe verse al pegar: la configuración y el secreto de la rutina
-- (ese valor se copia a Edge Functions → Secrets → PLAID_RUTINA_SECRETO).
-- Va en una función porque cron.job solo existe donde hay pg_cron
-- (producción sí; el banco de pruebas no).
create or replace function public.fn_plaid_pegado() returns table (que text, detalle text)
language plpgsql stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  return query select 'plaid_config'::text, c.funcion_url from plaid_config c;
  return query select 'plaid_rutina_secreto (cópialo a PLAID_RUTINA_SECRETO)'::text, s.decrypted_secret
                 from vault.decrypted_secrets s where s.name = 'plaid_rutina_secreto';
  return query select 'conexiones'::text, count(*)::text from plaid_conexiones;
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    return query execute $q$ select 'rutina pg_cron'::text, coalesce((select j.schedule from cron.job j where j.jobname = 'mxp-plaid-sync'), 'sin programar') $q$;
  else
    return query select 'rutina pg_cron'::text, 'sin pg_cron en esta base'::text;
  end if;
end $$;
revoke execute on function public.fn_plaid_pegado() from public, anon, authenticated, service_role;

select * from public.fn_plaid_pegado();
