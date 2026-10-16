-- =========================================================================
-- E36 · LOS DATOS DEL TRABAJO Y LOS ADJUNTOS DEL ESTIMADO (23/09/2026, Mariners)
-- Supabase → SQL Editor. Idempotente. No mueve ningún número.
--   dueno          el DUEÑO final de la obra (Baptist Health), aparte de quien
--                  nos contrata (el campo cliente)
--   direccion      la dirección de la obra: el formulario no la tenía y al
--                  convertir en proyecto salía «Por confirmar»
--   retencion_pct  lo que el contratante guarda de cada pago hasta el cierre
--                  (0,10 = 10 %). Vacío = sin retención, como hasta hoy.
--   adjuntos       [{titulo, ruta|url, fecha}]: planos, cuotas, el estimado de
--                  Claude. Al convertir pasan a los documentos del proyecto.
-- =========================================================================
alter table estimados add column if not exists dueno text;
alter table estimados add column if not exists direccion text;
alter table estimados add column if not exists retencion_pct numeric
  check (retencion_pct is null or (retencion_pct >= 0 and retencion_pct <= 0.2));
alter table estimados add column if not exists adjuntos jsonb;

-- Comprobación (una sola fila)
select case when (select count(*) from information_schema.columns
                   where table_name = 'estimados'
                     and column_name in ('dueno', 'direccion', 'retencion_pct', 'adjuntos')) = 4
            then '✓ dueño, dirección, retención y adjuntos listos' else '✗ falta alguna columna' end as datos_del_trabajo;
