-- =====================================================================
-- s1-mfa.sql — EL CÓDIGO DEL TELÉFONO (segundo factor, TOTP) EN LA ENTRADA
-- 24-oct-2026 · se pega en el SQL Editor (en cualquier orden respecto a c*).
-- Idempotente.
--
-- Qué hace: a quien tenga activado el segundo factor (hoy, Edgar: Supabase
-- Auth, factor TOTP verificado) la API de datos le exige haberlo pasado en
-- esta sesión (el token lleva «aal2»). Si entra solo con la contraseña
-- («aal1»), cada petición a la API contesta 403 con el código «MFA» y la app
-- le pide el código. A quien no tiene factor (el equipo) no le cambia nada.
--
-- Cómo: PostgREST llama a fn_mfa_exigir() antes de cada petición
-- (pgrst.db_pre_request, documentado por Supabase). La función mira el JWT
-- (rol, sub, aal) y auth.mfa_factors; solo frena cuando el usuario tiene un
-- factor verificado y la sesión es aal1. Nada más: ni toca es_dueno() —que
-- c2 sella como «candado»—, ni las policies, ni el libro. Las funciones de
-- borde (que entran directo como postgres), pg_cron y el SQL Editor no pasan
-- por PostgREST: no les afecta. Storage y Realtime tampoco (no se usan para
-- dinero).
--
-- Lo que la app hace con esto (js/db.js, js/app.js, js/conta.js): al entrar
-- con contraseña, si la cuenta tiene factor, pide el código de 6 dígitos
-- (reto + verificación en Supabase Auth) y guarda la sesión aal2; en
-- Contabilidad → Bancos y tarjetas, la tarjeta «El código del teléfono»
-- activa el factor (QR para la app de códigos del iPhone) o lo quita; y
-- «Conectar un banco» (Plaid) solo se habilita con el código activo.
--
-- SI HUBIERA QUE APAGARLO DE URGENCIA (nadie entra, por ejemplo):
--   alter role authenticator reset pgrst.db_pre_request;
--   notify pgrst, 'reload config';
-- =====================================================================

create or replace function public.fn_mfa_exigir() returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claims jsonb;
  v_uid    uuid;
  v_tiene  boolean := false;
begin
  v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  if v_claims is null then return; end if;
  -- solo las sesiones de personas: anon y service_role no tienen factor
  if v_claims->>'role' is distinct from 'authenticated' then return; end if;
  -- ya pasó el segundo factor en esta sesión
  if v_claims->>'aal' = 'aal2' then return; end if;
  -- ¿tiene un factor verificado? (si algo falla al mirar, no se frena a nadie)
  begin
    v_uid := (v_claims->>'sub')::uuid;
    if v_uid is null then return; end if;
    select exists (select 1 from auth.mfa_factors f where f.user_id = v_uid and f.status = 'verified') into v_tiene;
  exception when others then
    return;
  end;
  if not v_tiene then return; end if;
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code',    'MFA',
      'message', 'Falta el código del teléfono: entra otra vez y escríbelo.',
      'details', 'Esta cuenta tiene activado el segundo factor y esta sesión no lo pasó (aal1).',
      'hint',    'mfa')::text,
    detail = json_build_object('status', 403)::text;
end $$;
comment on function public.fn_mfa_exigir() is 'La guarda de cada petición de la API (pgrst.db_pre_request): con factor TOTP verificado, la sesión tiene que ser aal2. s1-mfa.sql.';
-- La corre PostgREST ya con el rol de la petición: los tres roles de la API
-- la ejecutan (no lee ni escribe nada del libro ni del banco).
revoke execute on function public.fn_mfa_exigir() from public;
grant execute on function public.fn_mfa_exigir() to anon, authenticated, service_role;

-- ¿Cómo está la cuenta de quien pregunta? (para la pantalla: sin secretos)
create or replace function public.fn_mfa_estado() returns jsonb
language plpgsql stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_uid    uuid  := auth.uid();
begin
  if v_uid is null then return jsonb_build_object('sesion', false); end if;
  return jsonb_build_object(
    'sesion', true,
    'aal', coalesce(v_claims->>'aal', 'aal1'),
    'factores_verificados', (select count(*) from auth.mfa_factors f where f.user_id = v_uid and f.status = 'verified'),
    'factores_sin_verificar', (select count(*) from auth.mfa_factors f where f.user_id = v_uid and f.status <> 'verified'),
    'exige', exists (select 1 from auth.mfa_factors f where f.user_id = v_uid and f.status = 'verified'));
end $$;
revoke execute on function public.fn_mfa_estado() from public, anon, service_role;
grant execute on function public.fn_mfa_estado() to authenticated;

-- Y PostgREST la llama antes de cada petición (la configuración del rol
-- authenticator, que es el de la API). «notify» hace que la relea ya.
do $$
begin
  execute 'alter role authenticator set pgrst.db_pre_request = ''public.fn_mfa_exigir''';
  notify pgrst, 'reload config';
exception when insufficient_privilege or undefined_object then
  raise notice 'No se pudo fijar pgrst.db_pre_request (%): en el banco de pruebas no hay rol authenticator; en producción avisa.', sqlerrm;
end $$;

-- Lo que debe verse al pegar
select 'pre_request del rol authenticator' as que,
       coalesce((select array_to_string(array(select x from unnest(r.rolconfig) x where x like 'pgrst.db_pre_request=%'), '') from pg_roles r where r.rolname = 'authenticator'), 'sin rol authenticator (banco de pruebas)') as detalle
union all
select 'fn_mfa_exigir la ejecutan', (select string_agg(g, ', ' order by g) from unnest(array['anon', 'authenticated', 'service_role']) g where has_function_privilege(g, 'public.fn_mfa_exigir()', 'execute'))
union all
select 'factores TOTP verificados hoy', (select count(*)::text from auth.mfa_factors where status = 'verified');
