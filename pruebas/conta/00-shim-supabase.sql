-- =====================================================================
-- 00-shim-supabase.sql — lo que Supabase trae de fábrica y un Postgres
-- pelado no. SOLO PARA EL BANCO DE PRUEBAS LOCAL. Nunca se pega en Supabase.
--
-- Lo corre correr.sh como SUPERUSUARIO (postgres del sistema) dentro de la
-- base recién creada, porque crear roles y extensiones lo pide. Todo lo
-- demás (01, 02 y los archivos que se prueban) se carga como "editor_sql",
-- que imita al rol "postgres" del SQL Editor de Supabase: no es
-- superusuario, es dueño de lo que hay en public y puede hacer SET ROLE a
-- anon, authenticated y service_role.
--
-- Por qué importa: en Supabase las tablas nacen ABIERTAS (grant all a anon
-- y authenticated por privilegios por defecto) y lo único que las cierra es
-- RLS. Si el banco no imitara eso, un revoke olvidado o una policy que falte
-- pasarían las pruebas aquí y abrirían un hueco allá.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Roles. Son de todo el cluster, no de la base: se crean una vez y los
--    comparten todas las bases del banco. Varios agentes pueden correr
--    correr.sh a la vez: el bloque toma un candado sobre pg_authid (que es
--    de todo el cluster, no de una base) para que no choquen dos
--    "create role" o dos "alter role" sobre el mismo rol.
-- ---------------------------------------------------------------------
do $$
declare
  r record;
begin
  lock table pg_catalog.pg_authid in share row exclusive mode;

  for r in select * from (values
      ('anon',         'create role anon nologin noinherit'),
      ('authenticated','create role authenticated nologin noinherit'),
      ('service_role', 'create role service_role nologin noinherit bypassrls'),
      -- En Supabase el rol postgres tiene BYPASSRLS y no es superusuario.
      -- De todas formas, como es dueño de las tablas, se salta RLS por serlo.
      ('editor_sql',   'create role editor_sql login nosuperuser inherit createrole createdb bypassrls password ''editor_sql''')
    ) as v(nombre, ddl)
  loop
    if not exists (select 1 from pg_roles where rolname = r.nombre) then
      execute r.ddl;
    end if;
  end loop;

  -- Si ya existían de antes con otros atributos, se corrigen (solo si hace falta).
  if exists (select 1 from pg_roles where rolname = 'anon' and (rolcanlogin or rolinherit or rolbypassrls)) then
    alter role anon nologin noinherit nobypassrls;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated' and (rolcanlogin or rolinherit or rolbypassrls)) then
    alter role authenticated nologin noinherit nobypassrls;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role' and (rolcanlogin or rolinherit or not rolbypassrls)) then
    alter role service_role nologin noinherit bypassrls;
  end if;
  if exists (select 1 from pg_roles where rolname = 'editor_sql' and (rolsuper or not rolcanlogin or not rolbypassrls)) then
    alter role editor_sql login nosuperuser inherit createrole createdb bypassrls password 'editor_sql';
  end if;

  -- El rol del SQL Editor es miembro de los tres roles de la API: por eso
  -- puede hacer "set local role authenticated" para suplantar a un usuario.
  if not pg_has_role('editor_sql', 'anon', 'member')
     or not pg_has_role('editor_sql', 'authenticated', 'member')
     or not pg_has_role('editor_sql', 'service_role', 'member') then
    grant anon, authenticated, service_role to editor_sql;
  end if;

  -- Como en Supabase: el search_path de cada sesión incluye extensions.
  if not exists (select 1 from pg_db_role_setting s join pg_roles pr on pr.oid = s.setrole
                  where pr.rolname = 'editor_sql' and s.setdatabase = 0) then
    alter role editor_sql    set search_path = "$user", public, extensions;
    alter role anon          set search_path = "$user", public, extensions;
    alter role authenticated set search_path = "$user", public, extensions;
    alter role service_role  set search_path = "$user", public, extensions;
  end if;
end $$;

-- La base es de editor_sql (en Supabase la base "postgres" es del rol
-- postgres); así editor_sql puede crear esquemas y, al ser public de
-- pg_database_owner, también es dueño de public.
do $$
begin
  execute format('alter database %I owner to editor_sql', current_database());
  execute format('alter database %I set search_path = "$user", public, extensions', current_database());
end $$;

-- ---------------------------------------------------------------------
-- 2. Esquema extensions con pgcrypto (y uuid-ossp), como en Supabase.
--    sha256(bytea) es nativo de Postgres; no depende de esto.
-- ---------------------------------------------------------------------
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
grant usage on schema extensions to anon, authenticated, service_role, editor_sql;
grant execute on all functions in schema extensions to anon, authenticated, service_role, editor_sql;

-- ---------------------------------------------------------------------
-- 3. Esquema auth: auth.uid(), auth.role(), auth.jwt() leen el token que
--    PostgREST deja en request.jwt.claims, igual que Supabase (con el
--    respaldo del formato viejo request.jwt.claim.sub que Supabase aún lee).
--    auth.users mínimo, por si algo quiere mirar ahí.
-- ---------------------------------------------------------------------
create schema if not exists auth;

create or replace function auth.uid() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;

create table if not exists auth.users (
  id         uuid primary key,
  email      text,
  created_at timestamptz default now()
);

grant usage on schema auth to anon, authenticated, service_role, editor_sql;
grant execute on function auth.uid(), auth.role(), auth.jwt()
  to anon, authenticated, service_role, editor_sql;
-- En Supabase el rol postgres puede leer y tocar auth.users; la API no.
grant select, insert, update, delete on auth.users to editor_sql, service_role;

-- ---------------------------------------------------------------------
-- 4. Esquema net: stub de pg_net. En producción net.http_post encola una
--    llamada HTTP (los avisos al teléfono). Aquí no hace nada y devuelve un
--    id falso. Firma real de pg_net para que las llamadas con nombre
--    (url := …, headers := …, body := …) funcionen igual.
-- ---------------------------------------------------------------------
create schema if not exists net;

create or replace function net.http_post(
  url                  text,
  body                 jsonb   default '{}'::jsonb,
  params               jsonb   default '{}'::jsonb,
  headers              jsonb   default '{"Content-Type": "application/json"}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint
language sql volatile as $$
  select 0::bigint  -- STUB del banco: no sale nada a la red
$$;

grant usage on schema net to anon, authenticated, service_role, editor_sql;
grant execute on function net.http_post(text, jsonb, jsonb, jsonb, integer)
  to anon, authenticated, service_role, editor_sql;

-- ---------------------------------------------------------------------
-- 5. Privilegios por defecto de Supabase sobre public. ESTO ES LO CRÍTICO:
--    toda tabla, secuencia y función que editor_sql cree en public nace con
--    grant all para anon, authenticated y service_role. La seguridad real
--    la ponen RLS y los revoke explícitos, igual que allá.
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant usage, create on schema public to editor_sql;

alter default privileges for role editor_sql in schema public
  grant all on tables    to anon, authenticated, service_role;
alter default privileges for role editor_sql in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges for role editor_sql in schema public
  grant all on functions to anon, authenticated, service_role;

-- Por si algo ya existía en public antes de este archivo.
grant all on all tables    in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;
