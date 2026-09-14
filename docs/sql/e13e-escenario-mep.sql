-- =====================================================================
-- E13e · El escenario de MXP MEP
-- Supabase → SQL Editor. Un solo pegado. Idempotente.
--
-- Hasta ahora los trabajos de Roger se calculaban con TUS números: tus
-- salarios de Tampa, tu overhead y el sales tax de Hillsborough. Esto les
-- da los suyos.
--
-- Nace copiando tu escenario A (el conservador), que es el más cercano a
-- una obra grande, y con el sales tax de Orange (6.5 %), que es donde
-- están los parques. TODOS esos números se cambian desde la app, en
-- ⚙ Escenarios, sin volver a tocar SQL: son un punto de partida, no una
-- decisión mía.
--
-- No toca ninguno de tus escenarios ni mueve ningún estimado tuyo.
-- =====================================================================

insert into escenarios (id, nombre, foreman, journeyman, helper,
                        pct_foreman, pct_journeyman, pct_helper,
                        benefits, tax_material, overhead_hh, profit)
select 'MEP', 'MXP MEP — con Roger',
       foreman, journeyman, helper,
       pct_foreman, pct_journeyman, pct_helper,
       benefits,
       0.065,              -- Orange County. Hillsborough es 0.075
       overhead_hh,
       profit
  from escenarios where id = 'A'
on conflict (id) do nothing;

-- Si tu tabla de escenarios tiene la columna `mezcla` (la cuadrilla en
-- lista), esta línea se la copia también. Si no la tiene, da error y se
-- ignora sin problema: la app la reconstruye de las tres columnas.
update escenarios d set mezcla = o.mezcla
  from escenarios o where d.id = 'MEP' and o.id = 'A' and d.mezcla is null;

-- Comprobación: deben salir A, B, C y MEP.
select id, nombre, foreman, journeyman, helper,
       round(benefits * 100, 1)      as benefits_pct,
       round(tax_material * 100, 2)  as sales_tax_pct,
       overhead_hh,
       round(profit * 100, 1)        as profit_pct
  from escenarios order by (id = 'MEP'), id;


-- =====================================================================
-- DESHACER
-- =====================================================================
-- OJO: si ya tienes estimados de MXP MEP usándolo, primero pásalos a otro:
--   update estimados set escenario = 'A' where escenario = 'MEP';
--   delete from escenarios where id = 'MEP';
