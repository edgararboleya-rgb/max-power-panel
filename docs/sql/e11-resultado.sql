-- =====================================================================
-- E11 · Ganado / perdido, y la FOTO del número con que se ofertó
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- Por qué hacen falta las dos cosas y no solo la primera:
--
-- `calcularEstimado` recalcula SIEMPRE desde el catálogo vivo. Eso está bien
-- para un estimado abierto, pero convierte cualquier historial en mentira: un
-- trabajo ofertado en marzo a 9,10 $/SF, mirado hoy con los precios de hoy,
-- diría otra cosa. Un benchmark así no sirve para calibrar nada.
--
-- Por eso, al marcar el resultado (y al convertir en proyecto) se guarda la
-- FOTO: bid, horas y material del momento. Los benchmarks salen de esa foto.
-- Un estimado sin foto entra igual, pero la app lo marca como «recalculado
-- con precios de hoy» y no lo mezcla en silencio.
-- =====================================================================

-- BLOQUE 1 — El resultado del estimado
alter table estimados add column if not exists resultado        text;
alter table estimados add column if not exists resultado_fecha  date;
alter table estimados add column if not exists resultado_motivo text;
alter table estimados add column if not exists resultado_nota   text;
-- Lo que ofertó el que ganó, si se llega a saber. Es el dato más valioso que
-- existe para calibrar: dice CUÁNTO de lejos se estaba, no solo que se perdió.
alter table estimados add column if not exists competencia      numeric;

alter table estimados drop constraint if exists estimados_resultado_chk;
alter table estimados add  constraint estimados_resultado_chk
  check (resultado is null or resultado in ('ganado','perdido','sin_respuesta','descartado'));

alter table estimados drop constraint if exists estimados_res_motivo_chk;
alter table estimados add  constraint estimados_res_motivo_chk
  check (resultado_motivo is null or resultado_motivo in
        ('precio','plazo','alcance','relacion','no_califico','otro'));

-- BLOQUE 2 — La foto del número con que se ofertó
alter table estimados add column if not exists bid_final      numeric;
alter table estimados add column if not exists horas_final    numeric;
alter table estimados add column if not exists material_final numeric;
alter table estimados add column if not exists cerrado_en     timestamptz;

-- BLOQUE 3 — Los convertidos de antes ya tienen su número: el contrato del
-- proyecto. Se copia como foto, que es el dato verdadero del día que se firmó.
update estimados e
   set bid_final  = f.contrato,
       cerrado_en = coalesce(e.cerrado_en, p.creado, now()),
       resultado  = coalesce(e.resultado, 'ganado'),
       resultado_fecha = coalesce(e.resultado_fecha, p.creado::date, current_date)
  from proyectos p
  join finanzas f on f.proyecto_id = p.id
 where e.proyecto_id = p.id
   and e.estado = 'convertido'
   and e.bid_final is null
   and f.contrato is not null
   and f.contrato > 0;

-- BLOQUE 4 — Qué quedó
select resultado,
       count(*)                                as estimados,
       count(bid_final)                        as con_foto,
       round(avg(bid_final)::numeric, 0)       as bid_medio,
       count(*) filter (where sqft > 0)        as con_sqft
  from estimados
 group by resultado
 order by resultado nulls first;

-- Para deshacerlo:
--   alter table estimados drop constraint if exists estimados_resultado_chk;
--   alter table estimados drop constraint if exists estimados_res_motivo_chk;
--   alter table estimados drop column if exists resultado, drop column if exists resultado_fecha,
--     drop column if exists resultado_motivo, drop column if exists resultado_nota,
--     drop column if exists competencia, drop column if exists bid_final,
--     drop column if exists horas_final, drop column if exists material_final,
--     drop column if exists cerrado_en;
