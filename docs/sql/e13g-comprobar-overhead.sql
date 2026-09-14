-- =====================================================================
-- E13g · Comprobación de un minuto. Solo lectura, no cambia nada.
--
-- En la tabla que sale de e13f, A/B/C enseñan overhead_pct = 0.0 — pero
-- eso puede ser dos cosas muy distintas y la consulta las pinta igual:
--   · VACÍO  (null) = «usa el overhead por hora». Correcto.
--   · CERO   (0)    = «usa el porcentaje, y el porcentaje es cero», que
--                     dejaría el overhead entero fuera del bid.
-- Con 320 horas serían $9.660 que no cobras y no se ven por ningún lado.
--
-- La app ya está blindada desde hoy: un 0 lo trata como vacío, así que
-- no puede pasar. Pero conviene ver el dato tal cual está.
-- =====================================================================

select id, nombre,
       case when overhead_pct is null then 'VACÍO — usa $/hora ✓'
            when overhead_pct = 0     then 'CERO — arréglalo con el update de abajo'
            else round(overhead_pct * 100, 1) || ' % del costo directo' end as overhead,
       overhead_hh as por_hora
  from escenarios order by (id = 'MEP'), id;

-- Si alguno de A, B o C sale como CERO, esta línea lo deja en vacío:
--   update escenarios set overhead_pct = null where id in ('A','B','C') and overhead_pct = 0;
