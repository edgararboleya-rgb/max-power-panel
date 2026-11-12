-- =====================================================================
-- correos-replica.sql — la tabla «correos» del cartero (la función de borde
-- correo, de la OTRA sesión) como está en producción, para el banco de
-- pruebas: el banco no la trae (no es de la contabilidad). La función de
-- borde «facturas» (f10) NO escribe en ella: el registro de los envíos de
-- una factura es el de c11 (emision_envios). facturas-e2e.mjs comprueba que
-- no la toca.
--
-- Las columnas son las de producción (pruebas/conta/esquema-columnas-
-- 23sep.json: id, proyecto_id, para, asunto, tipo, resend_id, enviado_por,
-- enviado_el, contratista_id), y la policy la de producción leída el
-- 12-nov-2026: el dueño solo LEE (ninguna policy de insert; el cartero
-- escribe con su llave de servicio). Idempotente.
-- =====================================================================
create table if not exists public.correos (
  id              bigserial    primary key,
  proyecto_id     text,
  para            text         not null,
  asunto          text         not null,
  tipo            text         not null,
  resend_id       text,
  enviado_por     uuid,
  enviado_el      timestamptz  not null default now(),
  contratista_id  text
);
alter table public.correos enable row level security;
grant select, insert on public.correos to authenticated;
grant usage on sequence public.correos_id_seq to authenticated;
drop policy if exists "correos: el dueno" on public.correos;
drop policy if exists "correos_lee_dueno" on public.correos;
create policy "correos_lee_dueno" on public.correos for select using (public.es_dueno());
