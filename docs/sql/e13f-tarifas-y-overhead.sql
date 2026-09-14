-- =====================================================================
-- E13f · Los salarios que pagas de verdad, y el overhead de MXP MEP
-- Supabase → SQL Editor. Se pega ENTERO, pero léelo antes: esto SÍ mueve
-- los precios de tus estimados en borrador y congelados. Los contratos
-- de los proyectos ya convertidos NO se tocan: ese número quedó guardado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOQUE 1 · Columnas nuevas
-- ---------------------------------------------------------------------
-- El overhead por PORCENTAJE del costo directo, que es el método del
-- Excel de Miami. Vacío = sigue el de siempre ($/hora-hombre).
alter table escenarios add column if not exists overhead_pct numeric;
alter table estimados  add column if not exists overhead_pct numeric;

comment on column escenarios.overhead_pct is
  'E13f · Overhead como % del costo directo (labor + material). NULL = por hora-hombre (overhead_hh), que es el metodo de Max Power.';


-- ---------------------------------------------------------------------
-- BLOQUE 2 · Tus salarios: los mismos en A, B y C
-- ---------------------------------------------------------------------
-- Foreman $45 · Journeyman $35 · Helper $20.
-- Lo que le pagas a tu gente es un hecho, no depende del escenario que
-- elijas en un bid. Lo que cambia entre A, B y C es lo comercial:
-- benefits, overhead y profit. Así, al comparar A contra C estás
-- comparando lo que de verdad estás decidiendo.
update escenarios set foreman = 45, journeyman = 35, helper = 20
 where id in ('A','B','C');

-- Y la cuadrilla en lista, si tu tabla la tiene (si no, da error y se ignora)
update escenarios set mezcla = jsonb_build_array(
    jsonb_build_object('rol','Foreman',   'tarifa',45,'pct',0.20),
    jsonb_build_object('rol','Journeyman','tarifa',35,'pct',0.50),
    jsonb_build_object('rol','Helper',    'tarifa',20,'pct',0.30))
 where id in ('A','B','C');


-- ---------------------------------------------------------------------
-- BLOQUE 3 · MXP MEP: superintendent y overhead por porcentaje
-- ---------------------------------------------------------------------
-- La cuadrilla con superintendent al 10 % de las horas, que es un super
-- por cada nueve hombres — lo normal en obra grande. Es el mismo método
-- del Excel: horas totales repartidas por porcentaje entre los roles.
update escenarios set
  mezcla = jsonb_build_array(
    jsonb_build_object('rol','Superintendent','tarifa',60,'pct',0.10),
    jsonb_build_object('rol','Foreman',       'tarifa',45,'pct',0.15),
    jsonb_build_object('rol','Journeyman',    'tarifa',35,'pct',0.40),
    jsonb_build_object('rol','Helper',        'tarifa',20,'pct',0.35)),
  foreman = 45, journeyman = 35, helper = 20,
  pct_foreman = 0.15, pct_journeyman = 0.40, pct_helper = 0.35,
  -- Overhead por PORCENTAJE, no por hora: tus gastos generales de Max
  -- Power (oficina, camiones, seguros) no aplican a una obra del MEP.
  -- 15 % es el centro del rango que NECA da para operaciones bien
  -- llevadas (14–16 %); el Excel de Miami usaba 10 %.
  overhead_pct = 0.15,
  benefits = 0.25
 where id = 'MEP';

-- Sale una tarifa mezclada de $33.75/h:
--   60×10% + 45×15% + 35×40% + 20×35%


-- ---------------------------------------------------------------------
-- COMPROBAR
-- ---------------------------------------------------------------------
select id, nombre, foreman, journeyman, helper,
       round(benefits * 100, 1)                     as benefits_pct,
       round(tax_material * 100, 2)                 as sales_tax_pct,
       overhead_hh,
       round(coalesce(overhead_pct, 0) * 100, 1)    as overhead_pct,
       round(profit * 100, 1)                       as profit_pct
  from escenarios order by (id = 'MEP'), id;


-- =====================================================================
-- DESHACER (los números de antes)
-- =====================================================================
--   update escenarios set foreman=40, journeyman=30, helper=19 where id='A';
--   update escenarios set foreman=43, journeyman=34, helper=22 where id='B';
--   update escenarios set foreman=46, journeyman=38, helper=25 where id='C';
--   update escenarios set overhead_pct = null where id = 'MEP';
