-- =====================================================================
-- 03-storage-simulacro.sql — un Storage MÍNIMO para el banco de pruebas.
-- NO es de producción y NO se pega en Supabase: allá Storage ya existe.
--
-- Imita solo lo que c3 necesita probar: la tabla storage.objects con RLS
-- y las policies de hoy según ESQUEMA-REAL.md («Storage fotos/recibos/%,
-- docs/%: cada quien lo suyo; borrar: solo el dueño»). Con él, la prueba de
-- Storage de c3-pruebas.sql corre de verdad (sin él sale «omitida»), y el
-- rojo muestra que sin c3 el dueño SÍ puede borrar la foto de un recibo.
--
-- Se carga ANTES de c3-puentes.sql (que crea su policy solo si existe
-- storage.objects), como un archivo más de correr.sh:
--   ./correr.sh c3x 03-storage-simulacro.sql ../../docs/conta/c1-plan-de-cuentas.sql \
--       ../../docs/conta/c2-libro.sql ../../docs/conta/c3-puentes.sql ../../docs/conta/c3-pruebas.sql
-- Lo carga editor_sql, dueño de la base del banco: la tabla es suya y él se
-- salta la RLS; las pruebas la miran con los roles de la API.
-- =====================================================================

create schema if not exists storage;
grant usage on schema storage to anon, authenticated, service_role;

create table if not exists storage.buckets (
  id     text primary key,
  name   text not null,
  public boolean not null default false
);
insert into storage.buckets (id, name) values ('fotos', 'fotos') on conflict (id) do nothing;

create table if not exists storage.objects (
  id         uuid        primary key default gen_random_uuid(),
  bucket_id  text        references storage.buckets (id),
  name       text,
  owner      uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  metadata   jsonb
);
create unique index if not exists objects_bucket_name on storage.objects (bucket_id, name);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;

-- Las de hoy (supuestas con lo que dice ESQUEMA-REAL.md; sus nombres reales
-- no se leyeron, y a c3 no le hacen falta: su policy es restrictiva).
drop policy if exists "sube lo suyo" on storage.objects;
create policy "sube lo suyo" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and owner = auth.uid());
drop policy if exists "lee lo suyo o el dueno" on storage.objects;
create policy "lee lo suyo o el dueno" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (owner = auth.uid() or public.es_dueno()));
drop policy if exists "dueno borra" on storage.objects;
create policy "dueno borra" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and public.es_dueno());
