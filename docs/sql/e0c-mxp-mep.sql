-- =====================================================================
-- E0c · Estimados de MXP MEP (los de Roger)
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- Una columna. Vacía = tuyo (todo lo que ya existe sigue siendo tuyo).
-- 'mep' = trabajo de MXP MEP: sale de tu lista, va a su propia tarjeta, y la
-- app solo te da el número — sin proyecto, sin propuesta, sin contrato.
--
-- No toca precios, ni horas, ni la fórmula. Los estimados de MXP MEP se
-- calculan hoy con TUS números; cuando quieras darles los suyos (otros
-- salarios, otro overhead), eso es E8 y solo cambia los valores.
-- =====================================================================

alter table estimados add column if not exists empresa text;

alter table estimados drop constraint if exists estimados_empresa_chk;
alter table estimados add  constraint estimados_empresa_chk
  check (empresa is null or empresa in ('mep'));

comment on column estimados.empresa is
  'E0c · NULL = Max Power (lo normal). mep = MXP MEP, la division electrica del MEP de Roger: solo da el numero, no crea proyecto ni propuesta.';

-- Comprobación: al principio todo debe salir como tuyo.
select coalesce(empresa,'Max Power (tuyo)') as de_quien, count(*) as estimados
  from estimados group by 1 order by 2 desc;


-- =====================================================================
-- DESHACER
-- =====================================================================
--   alter table estimados drop constraint if exists estimados_empresa_chk;
--   alter table estimados drop column if exists empresa;
