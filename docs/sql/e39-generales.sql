-- =====================================================================
-- e39 · GENERALES DEL PROYECTO, FUERA DEL TAKEOFF (29/09, Peninsula)
-- Edgar: «quisiera sacar eso del take off completo… que en el estimado me
-- salga aparte, con sus números y totales, y que lo pueda subir un poquito».
-- Viajes, hotel y per diem, permiso, PM y supervisión, lift y rentas,
-- disposición, overtime: cada estimado guarda su lista aparte del material
-- contado y un colchón en % para subirla entera.
-- Vacío = nada: ningún estimado que ya existe se mueve un centavo.
-- Se puede correr dos veces.
-- =====================================================================
alter table estimados add column if not exists gastos_generales jsonb;
alter table estimados add column if not exists generales_colchon_pct numeric
  check (generales_colchon_pct is null or (generales_colchon_pct >= 0 and generales_colchon_pct <= 1));

-- Comprobación (una sola fila)
select case when (select count(*) from information_schema.columns
                  where table_name = 'estimados' and column_name in ('gastos_generales', 'generales_colchon_pct')) = 2
            then '✓ estimados.gastos_generales y generales_colchon_pct existen' else '✗ falta alguna columna' end as generales;
