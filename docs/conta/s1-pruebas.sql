-- =====================================================================
-- s1-pruebas.sql — el código del teléfono se prueba a sí mismo (s1-mfa.sql).
-- 24-oct-2026. Cada prueba escribe en una subtransacción y lo deshace.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

create or replace function pg_temp.s1_claims(p_sub uuid, p_rol text, p_aal text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object('sub', p_sub, 'role', p_rol, 'aal', p_aal))::text, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_sub::text, ''), true);
end $$;
-- la guarda, con su resultado en una palabra
create or replace function pg_temp.s1_guarda() returns text language plpgsql as $$
begin
  perform fn_mfa_exigir();
  return 'pasa';
exception
  when sqlstate 'PGRST' then return 'frena ' || coalesce((sqlerrm::json ->> 'code'), '?');
  when others then return 'error ' || sqlstate;
end $$;

-- 1. Sin factor: el dueño entra con la contraseña sola (aal1) y la API no frena
do $$
declare v_d uuid; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    delete from auth.mfa_factors where user_id = v_d;
    perform pg_temp.s1_claims(v_d, 'authenticated', 'aal1');
    v_obt := pg_temp.s1_guarda();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (1, 'sin factor, aal1: pasa', 'pasa', v_obt, v_obt = 'pasa');
end $$;

-- 2. Con factor verificado y aal1: frena con el código MFA (403)
do $$
declare v_d uuid; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status) values (v_d, 'prueba s1', 'totp', 'verified');
    perform pg_temp.s1_claims(v_d, 'authenticated', 'aal1');
    v_obt := pg_temp.s1_guarda();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (2, 'con factor verificado, aal1: frena', 'frena MFA', v_obt, v_obt = 'frena MFA');
end $$;

-- 3. Con factor verificado y aal2: pasa
do $$
declare v_d uuid; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status) values (v_d, 'prueba s1', 'totp', 'verified');
    perform pg_temp.s1_claims(v_d, 'authenticated', 'aal2');
    v_obt := pg_temp.s1_guarda();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (3, 'con factor verificado, aal2: pasa', 'pasa', v_obt, v_obt = 'pasa');
end $$;

-- 4. Un factor SIN verificar (lo empezó a activar y no terminó) no frena
do $$
declare v_d uuid; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status) values (v_d, 'prueba s1', 'totp', 'unverified');
    perform pg_temp.s1_claims(v_d, 'authenticated', 'aal1');
    v_obt := pg_temp.s1_guarda();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (4, 'factor sin verificar, aal1: pasa', 'pasa', v_obt, v_obt = 'pasa');
end $$;

-- 5. anon y service_role nunca frenan (aunque el sub tenga factor); sin JWT tampoco
do $$
declare v_d uuid; a text; b text; c text; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status) values (v_d, 'prueba s1', 'totp', 'verified');
    perform pg_temp.s1_claims(v_d, 'anon', 'aal1'); a := pg_temp.s1_guarda();
    perform pg_temp.s1_claims(v_d, 'service_role', null); b := pg_temp.s1_guarda();
    perform set_config('request.jwt.claims', '', true); c := pg_temp.s1_guarda();
    v_obt := a || ' | ' || b || ' | ' || c;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (5, 'anon, service_role y sin JWT: pasan', 'pasa | pasa | pasa', v_obt, v_obt = 'pasa | pasa | pasa');
end $$;

-- 6. El equipo (otro usuario, sin factor) con aal1 pasa aunque el dueño tenga factor
do $$
declare v_d uuid; v_e uuid; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_e from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  if v_e is null then insert into _pruebas values (6, 'el equipo sin factor pasa', 'pasa', 'omitida: no hay perfil de equipo', null); return; end if;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status) values (v_d, 'prueba s1', 'totp', 'verified');
    perform pg_temp.s1_claims(v_e, 'authenticated', 'aal1');
    v_obt := pg_temp.s1_guarda();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (6, 'el equipo sin factor pasa', 'pasa', v_obt, v_obt = 'pasa');
end $$;

-- 7. fn_mfa_estado dice lo que la pantalla necesita (y nada secreto)
do $$
declare v_d uuid; v_e jsonb; v_obt text;
begin
  select id into v_d from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  begin
    insert into auth.mfa_factors (user_id, friendly_name, factor_type, status, secret) values (v_d, 'prueba s1', 'totp', 'verified', 'SECRETO-QUE-NO-SALE');
    perform pg_temp.s1_claims(v_d, 'authenticated', 'aal2');
    execute 'set local role authenticated';
    v_e := fn_mfa_estado();
    v_obt := format('aal %s · verificados %s · exige %s · secreto %s', v_e->>'aal', v_e->>'factores_verificados', v_e->>'exige',
                    case when v_e::text like '%SECRETO%' then 'SALE' else 'no sale' end);
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null; when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm; end;
  insert into _pruebas values (7, 'fn_mfa_estado para la pantalla', 'aal aal2 · verificados 1 · exige true · secreto no sale', v_obt,
                               v_obt = 'aal aal2 · verificados 1 · exige true · secreto no sale');
end $$;

-- 8. Nada queda
do $$
declare v_obt text;
begin
  select count(*)::text || ' factores de prueba' into v_obt from auth.mfa_factors where friendly_name = 'prueba s1';
  insert into _pruebas values (8, 'nada queda al deshacer', '0 factores de prueba', v_obt, v_obt = '0 factores de prueba');
end $$;

select * from _pruebas order by n;
