-- =====================================================================
-- E37c · Cambiar el secreto del cartero — PASO 2 de 2: activar
-- Supabase → SQL Editor. Se pega entero. Idempotente: si ya se activó, no
-- toca nada (y vuelve a mandar el aviso de prueba).
--
-- SOLO DESPUÉS de los pasos 2 y 3 de E37b: los tres secretos puestos en
-- notificar y el código nuevo de notificar desplegado. Si se pega antes,
-- los avisos dejan de llegar hasta que se despliegue — no se pierde nada
-- más, y basta con desplegar notificar para que vuelvan.
--
-- Qué hace: el secreto nuevo pasa a ser el que usa fn_cartero, y el
-- «siguiente» se borra de Vault. No hay que tocar fn_cartero: ya lo lee de
-- Vault desde E37.
-- =====================================================================

do $$
declare
  v_nuevo text;
  v_id    uuid;
begin
  select decrypted_secret into v_nuevo
    from vault.decrypted_secrets where name = 'mxp_secreto_cartero_siguiente';
  if v_nuevo is null then
    raise notice 'E37c: no hay un secreto preparado (o ya se activó). No se toca nada.';
    return;
  end if;
  select id into v_id from vault.secrets where name = 'mxp_secreto_cartero';
  if v_id is null then
    raise exception 'E37c: falta el secreto de hoy en Vault: hay que pegar E37 primero.';
  end if;
  perform vault.update_secret(v_id, v_nuevo);
  delete from vault.secrets where name = 'mxp_secreto_cartero_siguiente';
end $$;

select public.fn_cartero(jsonb_build_object(
  'titulo', '🔑 Secreto nuevo activo',
  'cuerpo', 'El cartero ya usa el secreto nuevo (E37c). Sigue con el paso 5: la rutina de las 6 AM.',
  'para',   (select id from perfiles
              where rol = 'dueno' and coalesce(activo, true)
              order by creado limit 1)));

select case
  when exists (select 1 from vault.secrets where name = 'mxp_secreto_cartero_siguiente')
    then '✗ el secreto nuevo sigue sin activar'
  else '✓ activado. Si en un minuto no llega «🔑 Secreto nuevo activo», notificar todavía no tiene MXP_SECRETO_CARTERO: revisa el paso 2 de E37b.'
end as resultado;
