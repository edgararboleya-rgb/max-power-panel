-- =====================================================================
-- E0b · Cierre. Un solo pegado. Idempotente.
--
-- Dos cosas que la siembra del 14/09 no podía saber:
--
-- 1) El catálogo tiene 192 ítems a $0, no 186. Los 6 de más son los que
--    creamos en E2g esa misma tarde y nacieron a $0 a propósito, con sus
--    horas del Excel: DISTRIBUTION PANEL 225A, STARTER SIZE 0, MOTOR
--    CONNECTION (15-30) HP y 150A METER STACK (switchgear), más el ATS
--    400A y el UPS 10KVA. Por eso SWITCHGEAR salió con 82 y no 78.
--
-- 2) La sección GENERATOR + ATS + UPS no estaba en la lista de «lo cotiza
--    el supply house», porque cuando escribí la regla esa sección no tenía
--    ningún ítem a $0. Ahora tiene dos, y un ATS o un UPS llega por
--    cotización del proveedor igual que el switchgear. Entran SIN
--    confirmar (con «?»), el mismo trato que los otros 128: es una
--    suposición mía, y la cambias con el selector si me equivoco.
-- =====================================================================

update catalogo_items
   set cero_motivo = 'suministro'
 where cero_motivo is null
   and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) > 0
   and seccion = 'GENERATOR + ATS + UPS';
-- Esperado: 2 (AUTOMATIC TRANSFER SWITCH 400A, UPS SYSTEM 10KVA)


-- EL REPARTO FINAL. Esto es lo que quiero ver.
select coalesce(cero_motivo,'SIN CLASIFICAR — te preguntará') as motivo,
       count(*) as items,
       count(*) filter (where cero_revisado is null) as sin_confirmar
  from catalogo_items
 where coalesce(precio,0) = 0
 group by 1
 order by 2 desc;

-- Debe salir así (192 en total):
--   suministro       130   sin confirmar 130   ← el chip sale con «?»
--   falta_precio      25   sin confirmar   0
--   SIN CLASIFICAR    22   sin confirmar  22   ← los contestas tú, uno a uno
--   tarifa            10   sin confirmar   0
--   by_owner           3   sin confirmar   0   ← los únicos que van al contrato
--   solo_labor         2   sin confirmar   0
--
-- Los 22 sin clasificar son el diseño funcionando, no un fallo:
--   DEMOLITION 8 · LIGHTNING & GROUNDING 7 · UNDERGROUND 4 (backhoe,
--   trenching, backfilling, compacting) · PROJECT GENERAL 3.
-- Ninguno se adivina sin saber cómo trabajas tú, así que salen en ámbar
-- preguntando «¿quién lo pone?» cuando aparezcan en un estimado de verdad.
