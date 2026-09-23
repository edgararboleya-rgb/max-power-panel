-- =====================================================================
-- e34 · VALIDEZ DE LA PROPUESTA POR ESTIMADO (23/09, Mariners)
-- La propuesta decía «válida por 15 días» escrito a fuego. Con el cobre
-- moviéndose cada semana, cada estimado tiene que poder decir la suya.
-- Vacío = 15 días, como siempre: ningún estimado cambia.
-- Se puede correr dos veces.
-- =====================================================================
alter table estimados add column if not exists valida_dias integer
  check (valida_dias is null or (valida_dias between 1 and 365));

-- Comprobación (una sola fila)
select case when exists (select 1 from information_schema.columns
                         where table_name = 'estimados' and column_name = 'valida_dias')
            then '✓ estimados.valida_dias existe' else '✗ falta la columna' end as validez;
