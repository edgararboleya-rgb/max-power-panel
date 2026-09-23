-- =====================================================================
-- E37b · Cambiar el secreto del cartero — PASO 1 de 2: preparar
-- Supabase → SQL Editor. Se pega entero. Idempotente: pegarlo otra vez
-- enseña el MISMO secreto nuevo, no inventa otro.
--
-- Por qué cambiarlo: el valor de hoy estuvo escrito en fn_cartero, en el
-- código de la función notificar y en el texto de la rutina de las 6 AM.
-- Hay que darlo por visto. Y como notificar tiene apagada la verificación
-- de sesión, ese secreto es lo ÚNICO que impide mandar avisos falsos a los
-- teléfonos del equipo.
--
-- El cambio se hace SIN cortar ni un aviso: durante unos minutos (o unos
-- días, si hace falta) notificar acepta el viejo Y el nuevo.
--
-- Antes: tiene que estar pegado E37 (el secreto de hoy ya en Vault).
--
-- LOS PASOS, EN ESTE ORDEN:
--   1. Pega ESTE archivo. Sale una fila con dos valores.
--   2. Supabase → Edge Functions → notificar → Secrets (o "Manage secrets").
--      Crea tres:
--        MXP_SECRETO_CARTERO           = la 1.ª columna (el nuevo)
--        MXP_SECRETO_CARTERO_ANTERIOR  = la 2.ª columna (el de hoy)
--        VAPID_PRIVADA                 = el valor de la línea
--                                        const VAPID_PRIVADA = "…"
--                                        del código que tiene HOY notificar
--   3. En el editor de notificar: borra todo, pega
--      supabase/functions/notificar/index.ts de este repo, y Deploy.
--      Desde ahí acepta el secreto viejo y el nuevo.
--   4. Pega E37c. Desde ahí la base manda el nuevo. Llega un aviso
--      «🔑 Secreto nuevo activo» al teléfono.
--   5. Cambia el secreto viejo por el nuevo en la rutina «Rutina diaria
--      única — 6 AM»: está en el paso F, en la llamada a notificar.
--   6. Espera a que la rutina corra una vez (6 AM) y mira el log de
--      notificar: si NO aparece la línea «llamada con el secreto ANTERIOR»,
--      ya nadie usa el viejo. Borra MXP_SECRETO_CARTERO_ANTERIOR.
-- =====================================================================

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'mxp_secreto_cartero') then
    raise exception 'E37b: primero hay que pegar E37: el secreto de hoy todavía no está en Vault.';
  end if;
  if not exists (select 1 from vault.secrets where name = 'mxp_secreto_cartero_siguiente') then
    -- 64 caracteres hexadecimales al azar, del mismo generador que ya usan
    -- las llaves del portal (gen_random_uuid), con el prefijo de siempre.
    perform vault.create_secret(
      'mxp_' || replace(gen_random_uuid()::text, '-', '')
             || replace(gen_random_uuid()::text, '-', ''),
      'mxp_secreto_cartero_siguiente',
      'Secreto NUEVO del cartero, preparado por E37b; lo activa E37c');
  end if;
end $$;

select
  (select decrypted_secret from vault.decrypted_secrets
    where name = 'mxp_secreto_cartero_siguiente') as "MXP_SECRETO_CARTERO (el nuevo)",
  (select decrypted_secret from vault.decrypted_secrets
    where name = 'mxp_secreto_cartero')           as "MXP_SECRETO_CARTERO_ANTERIOR (el de hoy)";
