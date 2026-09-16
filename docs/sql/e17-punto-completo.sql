-- ============================================================================
-- E17 · PUNTO COMPLETO — el takeoff de Planos manda RECETAS, no piezas sueltas
-- ============================================================================
-- El problema que resuelve (Edgar, 16/09/2026):
--
--   «yo cotice cable y tuberia como habiamos hablado pero la idea mia siempre
--    fue que la otra parte fuera automatica por ti pero en la IA de la app
--    pero cuando importamos el takeoff practicamente fue sin nada de eso solo
--    lo que yo estime y esa nunca fue la idea»
--
-- Antes: contar 100 receptaculos en Planos mandaba 100 receptaculos. Las 100
-- cajas, los 100 anillos, las 100 tapas, los 200 conectores, los 300 wirenuts
-- y los pigtails los ponia el a mano, uno por uno, o no entraban.
--
-- Ahora: a una categoria del Count se le dice de que RECETA es un punto
-- (Count ▾ → «Que sea un punto completo (receta)…»), y el takeoff manda
-- 100 × esa receta a `estimado_ensambles`. El estimador la explota sola.
--
-- El tubo y el cable de la receta NO se mandan. Edgar los MIDE sobre el plano
-- escalado, por tipo de tuberia, y esa medida ya entra como renglon propio.
-- Si la receta trajera ademas sus pies, el material se pagaria DOS VECES:
-- en 100 puntos son ~$2.970 y ~120 horas de mas (prueba e9, 16/09).
--
-- Esta columna es la bandera que dice «esta fila vino del plano: explotala
-- sin su lineal». Las filas de antes no la tienen y siguen explotando enteras.
-- ============================================================================

-- ── 1. La columna ───────────────────────────────────────────────────────────
alter table estimado_ensambles
  add column if not exists sin_lineales boolean not null default false;

comment on column estimado_ensambles.sin_lineales is
  'true = esta receta vino del takeoff de Planos como PUNTO COMPLETO: al '
  'explotarla se omiten el conduit y el conductor, porque Edgar los midio '
  'aparte sobre el plano y entran como renglon propio. Lo demas del punto '
  '(caja, anillo, tapa, conectores, acoples, grapas, wirenuts, pigtail) si '
  'entra. false = receta puesta a mano en el estimador: explota completa.';

-- ── 2. Comprobar ────────────────────────────────────────────────────────────
-- Tiene que decir sin_lineales | boolean | false
select column_name, data_type, column_default, is_nullable
  from information_schema.columns
 where table_name = 'estimado_ensambles'
   and column_name = 'sin_lineales';

-- Nada de lo viejo se movio: todas las filas de antes en false
select sin_lineales, count(*) as filas
  from estimado_ensambles
 group by 1
 order by 1;

-- ── 3. Que entro por el plano y que a mano (para mirarlo despues) ───────────
select e.nombre                as estimado,
       en.nombre               as receta,
       ee.cantidad,
       ee.pies,
       case when ee.sin_lineales then 'del plano (sin tubo ni cable)'
            else 'a mano (completa)' end as de_donde
  from estimado_ensambles ee
  join estimados e  on e.id  = ee.estimado_id
  join ensambles  en on en.id = ee.ensamble_id
 order by e.nombre, ee.sin_lineales desc, en.nombre;
