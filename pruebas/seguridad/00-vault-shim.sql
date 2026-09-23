-- =====================================================================
-- 00-vault-shim.sql — lo que el banco de la contabilidad no trae y E37
-- necesita: Supabase Vault y un pg_net que apunta lo que manda.
-- Lo corre el SUPERUSUARIO (en Supabase, vault y net son de supabase_admin).
-- Solo banco local. No se pega en Supabase.
-- =====================================================================

-- Vault: misma interfaz que producción (create_secret, update_secret,
-- secrets, decrypted_secrets) y los mismos permisos que tiene ahí el rol
-- del SQL Editor (leído el 23-sep): lee y borra secrets, NO los edita a
-- mano, ejecuta create/update, y lee decrypted_secrets. anon y
-- authenticated, nada.
create schema if not exists vault;
create table if not exists vault.secrets (
  id          uuid primary key default gen_random_uuid(),
  name        text unique,
  description text not null default '',
  secret      text not null,
  key_id      uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create or replace view vault.decrypted_secrets as
  select id, name, description, secret, secret as decrypted_secret, key_id, created_at, updated_at
    from vault.secrets;

create or replace function vault.create_secret(new_secret text, new_name text default null,
    new_description text default '', new_key_id uuid default null)
returns uuid language plpgsql security definer set search_path = vault, pg_temp as $$
declare v uuid;
begin
  insert into vault.secrets (name, description, secret, key_id)
  values (new_name, coalesce(new_description, ''), new_secret, new_key_id)
  returning id into v;
  return v;
end $$;

create or replace function vault.update_secret(secret_id uuid, new_secret text default null,
    new_name text default null, new_description text default null, new_key_id uuid default null)
returns void language plpgsql security definer set search_path = vault, pg_temp as $$
begin
  update vault.secrets
     set secret = coalesce(new_secret, secret), name = coalesce(new_name, name),
         description = coalesce(new_description, description),
         key_id = coalesce(new_key_id, key_id), updated_at = now()
   where id = secret_id;
end $$;

revoke all on schema vault from public;
revoke all on all tables in schema vault from public, anon, authenticated, service_role;
revoke all on all functions in schema vault from public, anon, authenticated, service_role;
grant usage on schema vault to editor_sql, service_role;
grant select, delete on vault.secrets to editor_sql;
grant select on vault.decrypted_secrets to editor_sql;
grant execute on function vault.create_secret(text, text, text, uuid),
                          vault.update_secret(uuid, text, text, text, uuid) to editor_sql;

-- pg_net con la firma REAL (5 argumentos con valores por defecto). El stub
-- de 3 argumentos del banco se quita: con los dos, una llamada con nombres
-- sería ambigua. Cada llamada queda apuntada en net._llamadas para que las
-- pruebas vean qué cabecera salió.
drop function if exists net.http_post(text, jsonb, jsonb);
create table if not exists net._llamadas (
  id      bigserial primary key,
  url     text,
  headers jsonb,
  body    jsonb,
  creado  timestamptz not null default clock_timestamp()
);
create or replace function net.http_post(url text, body jsonb default '{}'::jsonb,
    params jsonb default '{}'::jsonb,
    headers jsonb default '{"Content-Type": "application/json"}'::jsonb,
    timeout_milliseconds integer default 5000)
returns bigint language plpgsql security definer set search_path = net, pg_temp as $$
declare v bigint;
begin
  insert into net._llamadas (url, headers, body) values (url, headers, body) returning id into v;
  return v;
end $$;
revoke all on function net.http_post(text, jsonb, jsonb, jsonb, integer) from public, anon, authenticated;
grant execute on function net.http_post(text, jsonb, jsonb, jsonb, integer) to editor_sql, service_role;
grant usage on schema net to editor_sql, service_role;
grant select, delete on net._llamadas to editor_sql;
