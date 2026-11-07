-- Arreglo de fn_costos_marcar (pestaña «Costos» de cada obra), 7-nov-2026.
-- Por qué: es SECURITY DEFINER y lee el libro (asiento_lineas) con los
-- permisos de su dueño, y la API la puede ejecutar. El control «permisos»
-- de fn_verificar_cadena() (c2) la marca en rojo, y eso detiene el cierre.
-- Qué hace: la función pasa a correr con los permisos de quien la llama
-- (el dueño, que ya lee el libro por su policy), y costos_revision recibe
-- sus propias reglas: solo el dueño la lee y la escribe. Y como con esas
-- reglas el dueño también podría escribir la tabla DIRECTO por PostgREST
-- (POST/PATCH a /costos_revision, saltándose la función), un trigger le
-- pone a la tabla los mismos dos frenos de la función: la línea tiene que
-- ser de esa obra y la fase, una de las 10 del reporte de horas. Los mismos
-- mensajes, la misma vista. El equipo, anon y service_role no la ejecutan.
-- Se pega entero en el SQL Editor. Pegarlo dos veces no hace daño.
begin;

alter table public.costos_revision enable row level security;

drop policy if exists costos_revision_dueno_lee on public.costos_revision;
create policy costos_revision_dueno_lee on public.costos_revision
  for select to authenticated using ((select coalesce(es_dueno(), false)));

drop policy if exists costos_revision_dueno_crea on public.costos_revision;
create policy costos_revision_dueno_crea on public.costos_revision
  for insert to authenticated with check ((select coalesce(es_dueno(), false)));

drop policy if exists costos_revision_dueno_cambia on public.costos_revision;
create policy costos_revision_dueno_cambia on public.costos_revision
  for update to authenticated using ((select coalesce(es_dueno(), false))) with check ((select coalesce(es_dueno(), false)));

grant select, insert, update on public.costos_revision to authenticated;

-- Los frenos de la función, también en la tabla (para lo que entre sin pasar
-- por ella: PostgREST directo, el SQL Editor, service_role). SECURITY INVOKER:
-- lee recibos, materiales y asiento_lineas con la policy de quien escribe
-- (el dueño las lee todas). Es de trigger: c2 no la cuenta como sospechosa.
create or replace function public.fn_costos_revision_valida() returns trigger
language plpgsql security invoker set search_path to 'public', 'pg_temp' as $$
declare
  v_fases constant text[] := array['Movilización', 'Demolición', 'Rough-in', 'Underground', 'Panel / Servicio',
                                   'Trim-out', 'Low Voltage', 'Troubleshooting', 'Inspección / Correcciones', 'Service Call'];
  v_ok boolean := false;
begin
  if new.fuente = 'recibo' and new.ref ~ '^[0-9]+$' then
    select exists (select 1 from recibos where id = new.ref::bigint and proyecto_id = new.proyecto_id) into v_ok;
  elsif new.fuente = 'material' and new.ref ~ '^[0-9]+$' then
    select exists (select 1 from materiales where id = new.ref::bigint and proyecto_id = new.proyecto_id) into v_ok;
  elsif new.fuente = 'libro' and new.ref ~ '^[0-9a-f-]{36}#[0-9]+$' then
    select exists (select 1 from asiento_lineas where asiento_id = split_part(new.ref, '#', 1)::uuid
                   and orden = split_part(new.ref, '#', 2)::int and proyecto_id = new.proyecto_id) into v_ok;
  end if;
  if not v_ok then
    raise exception 'Esa línea de costo no es de esta obra.' using errcode = '22023';
  end if;
  if new.fase is not null and not (new.fase = any (v_fases)) then
    raise exception 'La fase «%» no es una de las 10 del reporte de horas.', new.fase using errcode = '22023';
  end if;
  return new;
end $$;
revoke execute on function public.fn_costos_revision_valida() from public, anon, authenticated, service_role;

drop trigger if exists trg_costos_revision_valida on public.costos_revision;
create trigger trg_costos_revision_valida before insert or update on public.costos_revision
  for each row execute function public.fn_costos_revision_valida();

alter function public.fn_costos_marcar(text, text, text, jsonb) security invoker;
revoke execute on function public.fn_costos_marcar(text, text, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_costos_marcar(text, text, text, jsonb) to authenticated;

commit;

-- Comprobación: tiene que salir «permisos | true».
select control, ok from public.fn_verificar_cadena() where control = 'permisos';
