-- s1-mfa-403.sql (17/11/2026) · Corrido en Supabase el 17/11, con el OK de Edgar.
--
-- QUÉ ARREGLA: las tres funciones que exigen el código del teléfono levantaban
--   raise sqlstate 'PGRST' ... detail = json_build_object('status', 403)::text
-- y PostgREST exige que ese DETAIL traiga también 'headers'. Como no lo traía, no
-- podía leer el error y contestaba 500 «PGRST121 Could not parse JSON» en vez del
-- 403 con el cuerpo {"code":"MFA", ...}. Resultado: la app operativa no se enteraba
-- de que faltaba el código (db.js mira data.code === "MFA"), y MXP Planos se quedó en
-- «no subió» desde el 25/10 sin decir por qué.
--
-- QUÉ CAMBIA: solo esa línea, en las tres funciones. Mismo dueño, mismos permisos,
-- mismo SECURITY DEFINER (CREATE OR REPLACE los conserva).
--   public.fn_mfa_exigir()            (db_pre_request de PostgREST: toda la app)
--   public.fn_subs_exigir_codigo()    (TIN y hoja del 1099)
--   public.fn_nomina_exigir_codigo()  (nómina)

do $do$
declare
  f text;
  d text;
  viejo constant text := $s$json_build_object('status', 403)::text$s$;
  nuevo constant text := $s$json_build_object('status', 403, 'headers', json_build_object())::text$s$;
begin
  foreach f in array array['public.fn_mfa_exigir()', 'public.fn_subs_exigir_codigo()', 'public.fn_nomina_exigir_codigo()'] loop
    d := pg_get_functiondef(f::regprocedure);
    if (length(d) - length(replace(d, viejo, ''))) / length(viejo) <> 1 then
      raise exception 'En % la línea no está exactamente una vez: no toco nada', f;
    end if;
    execute replace(d, viejo, nuevo);
  end loop;
end
$do$;

-- Comprobación (solo lee; se deshace): una sesión aal1 de una cuenta con factor
-- recibe SQLSTATE PGRST con detail {"status":403,"headers":{}} y code MFA; una aal2 pasa.
-- Resultado del 17/11: {"code":"MFA","detail":{"status":403,"headers":{}},"sqlstate":"PGRST"} · «aal2 pasa».
-- Y en los registros de la API, las peticiones de Planos pasaron de 500 a 403 a las 23:26 UTC.
