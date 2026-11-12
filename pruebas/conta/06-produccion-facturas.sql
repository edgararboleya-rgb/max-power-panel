-- =====================================================================
-- 06-produccion-facturas.sql — lo que producción tiene en «facturas» y en
-- Storage y el banco no tenía. SOLO PARA EL BANCO DE PRUEBAS: NO se pega en
-- Supabase (allá todo esto ya existe, y nada de esto es de la contabilidad).
--
-- Leído de producción el 12-nov-2026 (catálogo, solo lectura), después de
-- que c11-pruebas.sql diera allá 7 filas en falso por esto mismo (4 con
-- 23505 «ux_facturas_hito» y 3 con 42501 «Direct deletion from storage
-- tables is not allowed»). Con este archivo, una base del banco se comporta
-- «como producción» en esas tres cosas:
--
--   1. DOS ÍNDICES ÚNICOS en public.facturas, de la OTRA SESIÓN (la de la
--      app y la función qb; no son de ninguna capa c*):
--        ux_facturas_hito       unique (hito_id) where hito_id is not null
--                               → un hito, UNA sola fila de facturas: cuenta
--                                 TODAS, también las anuladas
--        ux_facturas_hito_viva  unique (hito_id) where hito_id is not null
--                               and estado is distinct from 'anulada'
--                               → un hito, una sola fila VIVA
--      Con el primero, después de anular la factura de un hito no entra otra
--      fila de facturas con ese hito_id mientras la anulada lo conserve. Es
--      lo que c11 maneja al emitir (docs/conta/c11-emision.sql, «El hito que
--      se vuelve a facturar»). Con cualquiera de los dos, dos filas vivas
--      con el mismo hito_id no caben: las pruebas que fabricaban ese caso a
--      mano van por otro camino.
--   2. EL TRIGGER trg_factura_cobrada de facturas (before insert or update,
--      función fn_factura_cobrada), también de la otra sesión. El banco YA
--      lo trae desde 01-replica-esquema.sql (leído el 23-sep, igual al del
--      12-nov): aquí solo se pone si falta, y si está NO se pisa.
--   3. EL CANDADO DE BORRADO DE STORAGE, de Supabase (no de la app): en
--      storage.objects el trigger protect_objects_delete (before delete, for
--      each statement → storage.protect_delete()). Un DELETE directo da
--      42501 «Direct deletion from storage tables is not allowed. Use the
--      Storage API instead.», toque filas o no (es por sentencia), salvo que
--      la transacción haya puesto antes
--        select set_config('storage.allow_delete_query', 'true', true);
--      que es lo que hace la API de Storage por dentro. Una prueba que borra
--      un objeto lo pone dentro de su subtransacción. Solo se pone si la
--      base tiene storage.objects (en el banco: 03-storage-simulacro.sql).
--      (En producción se leyó el de storage.objects; si Supabase tiene otro
--      igual en storage.buckets no se leyó, y ninguna prueba borra un
--      bucket: aquí no se pone.)
--
-- Cuándo se carga: DESPUÉS de c3-puentes.sql (el segundo índice nombra
-- facturas.estado, que la pone c3) y, para el punto 3, después de
-- 03-storage-simulacro.sql. Sobre una base ya armada (un clon de la cadena
-- entera) se pega tal cual. Como el SQL Editor, en una transacción:
--   PGPASSWORD=editor_sql psql -X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5433 \
--     -U editor_sql -d <bd> -1 -f pruebas/conta/06-produccion-facturas.sql
-- o como un archivo más de correr.sh, detrás de c3-puentes.sql.
-- Idempotente: cargarlo dos veces es cargarlo una. No trae datos.
-- Si la base ya tiene dos filas de facturas con el mismo hito, los índices
-- no se pueden crear y Postgres lo dice (en producción no las hay).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Los dos índices únicos de facturas (de la otra sesión)
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.facturas') is null
     or not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'facturas' and column_name = 'estado') then
    raise exception '06-produccion-facturas.sql se carga después de c3-puentes.sql: facturas.estado (que nombra el índice ux_facturas_hito_viva) la pone c3.';
  end if;
end $$;

create unique index if not exists ux_facturas_hito
  on public.facturas (hito_id)
  where hito_id is not null;

create unique index if not exists ux_facturas_hito_viva
  on public.facturas (hito_id)
  where hito_id is not null and estado is distinct from 'anulada';

-- ---------------------------------------------------------------------
-- 2. trg_factura_cobrada y su función (de la otra sesión): solo si faltan.
--    El cuerpo es el de producción, tal cual (sin search_path fijo, como
--    allá): al pasar a pagada, cobrado = monto; y cobrado nunca queda nulo.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.fn_factura_cobrada()') is null then
    execute $f$
      create function public.fn_factura_cobrada() returns trigger language plpgsql as $b$
      begin
        if new.pagada = true and (old.pagada is distinct from true) and coalesce(new.cobrado, 0) < new.monto then
          new.cobrado := new.monto;
        end if;
        if new.cobrado is null then new.cobrado := case when new.pagada then new.monto else 0 end; end if;
        return new;
      end $b$
    $f$;
  end if;
  if not exists (select 1 from pg_trigger t
                  where t.tgrelid = 'public.facturas'::regclass and t.tgname = 'trg_factura_cobrada' and not t.tgisinternal) then
    create trigger trg_factura_cobrada before insert or update on public.facturas
      for each row execute function public.fn_factura_cobrada();
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. El candado de borrado de Storage (de Supabase): solo si la base tiene
--    storage.objects, y solo lo que falte. El mensaje y el código son los
--    que dio producción el 12-nov.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice '06: esta base no tiene storage.objects (03-storage-simulacro.sql): el candado de borrado de Storage no se pone.';
    return;
  end if;
  if to_regprocedure('storage.protect_delete()') is null then
    execute $f$
      create function storage.protect_delete() returns trigger language plpgsql as $b$
      begin
        if coalesce(current_setting('storage.allow_delete_query', true), 'false') <> 'true' then
          raise exception 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            using errcode = '42501', hint = 'This prevents accidental data loss from orphaned objects.';
        end if;
        return null;
      end $b$
    $f$;
  end if;
  if not exists (select 1 from pg_trigger t
                  where t.tgrelid = 'storage.objects'::regclass and t.tgname = 'protect_objects_delete' and not t.tgisinternal) then
    create trigger protect_objects_delete before delete on storage.objects
      for each statement execute function storage.protect_delete();
  end if;
end $$;

-- Lo que quedó, a la vista (tres filas).
select 'facturas: índices únicos por hito' as que,
       coalesce((select string_agg(c.relname || case when pg_get_expr(i.indpred, i.indrelid) like '%anulada%'
                                                      then ' (solo las vivas)' else ' (todas, también las anuladas)' end,
                                   ' · ' order by c.relname)
                   from pg_index i join pg_class c on c.oid = i.indexrelid
                  where i.indrelid = 'public.facturas'::regclass and c.relname in ('ux_facturas_hito', 'ux_facturas_hito_viva')),
                'NINGUNO') as detalle
union all
select 'facturas: trg_factura_cobrada',
       coalesce((select 'está (' || p.proname || ')' from pg_trigger t join pg_proc p on p.oid = t.tgfoid
                  where t.tgrelid = 'public.facturas'::regclass and t.tgname = 'trg_factura_cobrada'), 'NO está')
union all
select 'storage: protect_objects_delete',
       case when to_regclass('storage.objects') is null then 'sin Storage en esta base'
            when exists (select 1 from pg_trigger t where t.tgrelid = to_regclass('storage.objects') and t.tgname = 'protect_objects_delete')
              then 'está: un DELETE directo da 42501 salvo con storage.allow_delete_query = true'
            else 'NO está' end;
