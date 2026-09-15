-- =====================================================================
-- E12 · Precios de referencia y de dónde salen
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- Dos cosas distintas, y por eso van en columnas distintas:
--
--  · `precio` y `horas_unidad` son TUYOS. Es lo que tú pagas y lo que tú
--    tardas. Mandan siempre: son los que cotizan.
--  · `precio_ref` y `horas_ref` son de FUERA — una cotización del supply,
--    RSMeans, NECA. Sirven para comparar («¿voy caro o barato?»), NUNCA
--    para cotizar solos.
--
-- Las bases compradas (RSMeans / NECA) tienen licencia de uso INTERNO: se
-- quedan en esta columna, no salen en ninguna propuesta y no viajan a otra
-- empresa. Lo único que cruza empresas es lo tuyo.
-- =====================================================================

alter table catalogo_items add column if not exists precio_ref  numeric;
alter table catalogo_items add column if not exists horas_ref   numeric;
alter table catalogo_items add column if not exists fuente_ref  text;
alter table catalogo_items add column if not exists ref_fecha   date;

-- Cuándo se tocó por última vez el precio TUYO. Sin esto no hay forma de
-- saber si un precio es de esta primavera o de hace tres años.
alter table catalogo_items add column if not exists precio_fecha date;
alter table catalogo_items add column if not exists precio_fuente text;

-- Qué hay hoy
select count(*)                                as items,
       count(precio_ref)                       as con_referencia,
       count(precio_fecha)                     as con_fecha_de_precio,
       count(*) filter (where precio = 0)      as a_cero
  from catalogo_items;

-- Para deshacerlo:
--   alter table catalogo_items drop column if exists precio_ref, drop column if exists horas_ref,
--     drop column if exists fuente_ref, drop column if exists ref_fecha,
--     drop column if exists precio_fecha, drop column if exists precio_fuente;
