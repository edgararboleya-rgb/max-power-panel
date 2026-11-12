-- =====================================================================
-- correos-replica.sql — la tabla «correos» del cartero (la función de borde
-- correo, de la OTRA sesión) como está en producción, para el banco de
-- pruebas: el banco no la trae (no es de la contabilidad) y la función de
-- borde «facturas» (f10) apunta ahí cada factura que manda, con su tipo
-- propio («factura_app»), como hace el cartero con los suyos.
--
-- Las columnas son las de producción (pruebas/conta/esquema-columnas-
-- 23sep.json: id, proyecto_id, para, asunto, tipo, resend_id, enviado_por,
-- enviado_el, contratista_id). Las POLICIES de producción NO se conocen
-- desde aquí: este archivo SUPONE que el dueño puede insertar y leer (RLS
-- con es_dueno()). Si en producción no deja, la función «facturas» no se
-- cae: manda igual, apunta el envío en la factura (c11) y avisa de que el
-- registro de correos no entró (facturas-e2e.mjs lo prueba quitando la
-- policy). Lo usa pruebas/conta/facturas-e2e.mjs. Idempotente.
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
create policy "correos: el dueno" on public.correos for all to authenticated using (public.es_dueno()) with check (public.es_dueno());
