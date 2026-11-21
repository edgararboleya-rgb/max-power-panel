-- =====================================================================
-- c18-fiscal.sql — LA CONTABILIDAD EN INGLÉS para el contador (CPA):
-- nombres estándar de contratista en EE. UU., categorías, y cada cuenta
-- mapeada a su línea del Form 1120 (C-corp), del 1120-S (S-corp) y del
-- 1125-A (costo de ventas). 21-nov-2026. Se pega en el SQL Editor DESPUÉS
-- de c4-estados.sql (pide c1, c2 y c4); va detrás de c17 en el orden de
-- pegado, pero no depende de ella. No cambia ninguna capa anterior.
--
-- LO QUE DECIDIÓ EDGAR (21-nov): «Cuentas y reportes» en inglés. Los
-- nombres de las cuentas, los estados financieros y el paquete de fin de año
-- —lo que ve el CPA— salen en inglés; las PANTALLAS y sus textos le siguen
-- hablando en español a Edgar.
--
-- EL INGLÉS VA AL LADO. Nada de lo que ya existe cambia de nombre: ni
-- cuentas.nombre, ni cuentas.nombre_en, ni las etiquetas de estados_lineas
-- ni de estados_mapeo (otras piezas los leen: el conector, la IA de c8, las
-- reglas). Los nombres estándar viven en una tabla nueva (fiscal_cuentas),
-- y la pantalla y el paquete los toman de aquí.
--
-- LAS CATEGORÍAS (seccion_en), como las de cualquier contratista:
--   Assets · Liabilities · Equity · Income · Cost of Goods Sold (Job Costs)
--   · Operating Expenses · Other Income · Other Expense
-- y «Personal» (lo que Edgar saca) es Shareholder Distributions: capital, no
-- un gasto.
--
-- EL TIPO DE ENTIDAD ESTÁ PENDIENTE DE CONFIRMAR CON EL CPA. La corporación
-- (constituida en marzo de 2026, con su EIN) figura en el IRS como C-corp:
-- su carta CP 575 le asigna el Form 1120; la elección de S-corp (Form 2553)
-- no consta presentada para la Inc. (docs/CONTA-PLAN.md). Por eso:
--   · el mapeo está hecho para LAS DOS formas (linea_1120 y linea_1120s), más
--     el 1125-A, que es el mismo en las dos;
--   · la forma que se usa es UN ajuste (fiscal_config.forma, de fábrica
--     «1120»), que se cambia con fn_fiscal_forma('{"forma": "1120-S"}'); y
--   · mientras fiscal_config.confirmada sea falso, el paquete lo dice arriba,
--     en inglés, para que el CPA lo vea («pending confirmation»).
-- Los números de línea son los de los formularios del ejercicio 2025
-- (fiscal_config.formas_anio); si el IRS los mueve, se corrigen aquí
-- (fiscal_lineas) sin tocar el libro.
--
-- LO QUE ENTREGA
--   fiscal_config      una fila: la forma, si está confirmada, el año de los
--                      formularios.
--   fiscal_lineas      el catálogo de líneas de cada forma (1120, 1120-S,
--                      1125-A), con su texto en inglés, en su orden.
--   fiscal_cuentas     por cuenta: su nombre estándar en inglés, su
--                      categoría, su línea en cada forma y una nota para el
--                      CPA. «fijada» = alguien la cambió a mano (volver a
--                      pegar no la pisa).
--   v_fiscal_cuentas   TODAS las cuentas del plan con eso (y, la que no
--                      tenga fila, con lo que sale de su tipo y «mapeada»
--                      en falso: el control la enseña).
--   fn_fiscal_leer()   lo que la pantalla necesita para enseñar los estados
--                      en inglés: la configuración, los nombres y las
--                      etiquetas de las secciones.
--   fn_fiscal_paquete(año, forma)  EL PAQUETE DE FIN DE AÑO, en inglés: la
--                      balanza (trial balance), el estado de resultados, el
--                      balance general y el resumen por línea del formulario
--                      (y el 1125-A), con sus avisos. Sale de las vistas de
--                      c4 (v_balanza, v_resultados, v_balance_general): las
--                      mismas cifras que la pantalla. No calcula el impuesto
--                      ni la declaración: eso es del CPA. (Segunda vuelta,
--                      marca 2026112102: el capital del Schedule L sale del
--                      balance —las utilidades retenidas con el resultado
--                      del año y las distribuciones— con su conciliación
--                      M-2; el año que la app no lleva entero se dice arriba
--                      —PARTIAL YEAR—; y el 1125-A trae su línea 1.)
--   fn_fiscal_forma, fn_fiscal_cuenta   lo que se cambia, con rastro de
--                      quién y cuándo.
--   fn_fiscal_control, fn_fiscal_pegado
-- Sus pruebas: docs/conta/c18-pruebas.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
create or replace function public.fn_fiscal_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'perfiles', 'v_balanza', 'v_resultados', 'v_balance_general'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c18 se pega después de c1, c2 y c4: falta %s.', array_to_string(v_falta, ', '));
  end if;
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('cuentas', 'nombre_en'), ('cuentas', 'tipo'), ('v_balanza', 'saldo_final'), ('v_balanza', 'periodo'),
                 ('v_resultados', 'etiqueta_en'), ('v_resultados', 'mes'), ('v_balance_general', 'etiqueta_en'),
                 ('v_balance_general', 'cifra')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Está pegado c4-estados.sql?', v_x);
  end if;
  foreach v_x in array array['fiscal_config:forma', 'fiscal_lineas:etiqueta_en', 'fiscal_cuentas:linea_1120s'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c18 (no tiene la columna %s). No la toco; avisa antes de seguir.',
                    split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  select string_agg(p.oid::regprocedure::text, ', ') into v_x
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_fiscal\_%'
     and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c18: %';
  if v_x is not null then
    return format('ya hay en esta base funciones con nombre de c18 que no son de c18: %s. No las piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  return null;
end $$;
revoke execute on function public.fn_fiscal_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_fiscal_precondiciones() is 'c18: lo que falta para pegar c18-fiscal.sql (nulo = nada).';

do $$
declare
  v text;
begin
  v := public.fn_fiscal_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c18-fiscal NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1 … c17 y después este archivo (docs/conta/PEGAR-21NOV.md).';
  end if;
end $$;

create or replace function public.fn_fiscal_version() returns bigint
language sql immutable
set search_path = public, pg_temp
as $$ select 2026112102::bigint $$;
revoke execute on function public.fn_fiscal_version() from public, anon, service_role;
grant  execute on function public.fn_fiscal_version() to authenticated;
comment on function public.fn_fiscal_version() is 'c18: la marca de la versión pegada de c18-fiscal.sql.';

create or replace function public.fn_fiscal_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'Las cuentas y los reportes para el contador los ve y los cambia solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_fiscal_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_fiscal_exigir_dueno() to authenticated;
comment on function public.fn_fiscal_exigir_dueno() is 'c18: por la API solo el dueño (es_dueno); el SQL Editor pasa.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (solo el dueño lee; se escriben por las funciones de aquí,
--    con la marca de la transacción mx_fiscal.escribe).
-- ---------------------------------------------------------------------
create table if not exists public.fiscal_config (
  id               int         primary key,
  forma            text        not null default '1120',
  confirmada       boolean     not null default false,
  confirmada_por   uuid,
  confirmada_el    timestamptz,
  nota             text,
  formas_anio      int         not null default 2025,
  idioma_reportes  text        not null default 'en',
  actualizado      timestamptz not null default now(),
  actualizado_por  uuid,
  constraint fiscal_config_una    check (id = 1),
  constraint fiscal_config_forma  check (forma in ('1120', '1120-S')),
  constraint fiscal_config_idioma check (idioma_reportes in ('en', 'es'))
);
comment on table public.fiscal_config is 'c18: la configuración fiscal (una fila): la forma con la que declara la corporación (1120 = C-corp, lo que dice su CP 575; 1120-S = S-corp), si el CPA ya la confirmó, el año de los formularios cuyos números de línea se usan, y el idioma de las cuentas y los reportes (en).';

create table if not exists public.fiscal_lineas (
  forma        text not null,
  linea        text not null,
  orden        int  not null,
  etiqueta_en  text not null,
  primary key (forma, linea),
  constraint fiscal_lineas_forma check (forma in ('1120', '1120-S', '1125-A'))
);
comment on table public.fiscal_lineas is 'c18: el catálogo de líneas de cada formulario (Form 1120, Form 1120-S y Form 1125-A; página 1, y las de Schedule K, L, M-1 y M-2 que el plan de cuentas usa), con su texto en inglés y su orden.';

create table if not exists public.fiscal_cuentas (
  codigo        text        primary key references public.cuentas (codigo),
  nombre_en     text        not null,
  seccion_en    text        not null,
  grupo_en      text,
  orden         int         not null default 0,
  linea_1120    text,
  linea_1120s   text,
  linea_1125a   text,
  nota_en       text,
  fijada        boolean     not null default false,
  cambiada_por  uuid,
  cambiada_el   timestamptz,
  constraint fiscal_cuentas_seccion check (seccion_en in ('Assets', 'Liabilities', 'Equity', 'Income', 'Cost of Goods Sold (Job Costs)',
                                                         'Operating Expenses', 'Other Income', 'Other Expense'))
);
comment on table public.fiscal_cuentas is 'c18: por cuenta del plan, su nombre estándar en inglés (el de un contratista en EE. UU.), su categoría, su línea en el Form 1120 y en el 1120-S, su línea del 1125-A si es costo de ventas, y una nota para el CPA. fijada = cambiada a mano: volver a pegar no la pisa.';

create or replace function public.fn_fiscal_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op in ('TRUNCATE', 'DELETE') and coalesce(current_setting('mx_fiscal.escribe', true), '') <> tg_table_name then
    raise exception using errcode = 'MX003', message = format('%s no se borra a mano.', tg_table_name);
  end if;
  if coalesce(current_setting('mx_fiscal.escribe', true), '') <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones de c18 (fn_fiscal_forma, fn_fiscal_cuenta), no a mano.', tg_table_name);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke execute on function public.fn_fiscal_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_fiscal_guarda() is 'c18: la guarda de las tablas de c18: se escriben solo con la marca de la transacción (mx_fiscal.escribe).';

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['fiscal_config', 'fiscal_lineas', 'fiscal_cuentas'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_fiscal_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_fiscal_guarda()', t, t);
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  foreach t in array array['fiscal_config', 'fiscal_cuentas'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  execute 'create policy fiscal_cuentas_dueno_anade on public.fiscal_cuentas for insert to authenticated with check ((select es_dueno()))';
  execute 'grant insert on public.fiscal_cuentas to authenticated';
end $$;


-- ---------------------------------------------------------------------
-- 2. La siembra: la configuración (no se pisa), el catálogo de líneas (se
--    pone al día: es de esta capa) y el mapeo de cada cuenta (se pone al
--    día salvo lo «fijado» a mano).
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from public.fiscal_config where id = 1) then
    perform set_config('mx_fiscal.escribe', 'fiscal_config', true);
    insert into public.fiscal_config (id, nota)
    values (1, 'De fábrica: Form 1120 (C-corp), lo que dice la carta CP 575 de la corporación. Pendiente de confirmar con el CPA si se presentó el Form 2553 (S-corp).');
  end if;
  perform set_config('mx_fiscal.escribe', 'fiscal_lineas', true);
  delete from public.fiscal_lineas;
  insert into public.fiscal_lineas (forma, linea, orden, etiqueta_en) values
    ('1120', '1a',     10, 'Line 1a — Gross receipts or sales'),
    ('1120', '2',      20, 'Line 2 — Cost of goods sold (attach Form 1125-A)'),
    ('1120', '5',      30, 'Line 5 — Interest'),
    ('1120', '9',      40, 'Line 9 — Net gain or (loss) (attach Form 4797)'),
    ('1120', '10',     50, 'Line 10 — Other income'),
    ('1120', '12',     60, 'Line 12 — Compensation of officers (attach Form 1125-E)'),
    ('1120', '13',     70, 'Line 13 — Salaries and wages (less employment credits)'),
    ('1120', '14',     80, 'Line 14 — Repairs and maintenance'),
    ('1120', '15',     90, 'Line 15 — Bad debts'),
    ('1120', '16',    100, 'Line 16 — Rents'),
    ('1120', '17',    110, 'Line 17 — Taxes and licenses'),
    ('1120', '18',    120, 'Line 18 — Interest'),
    ('1120', '19',    130, 'Line 19 — Charitable contributions'),
    ('1120', '20',    140, 'Line 20 — Depreciation (attach Form 4562)'),
    ('1120', '22',    150, 'Line 22 — Advertising'),
    ('1120', '24',    160, 'Line 24 — Employee benefit programs'),
    ('1120', '26',    170, 'Line 26 — Other deductions (attach statement)'),
    ('1120', 'M-1',   180, 'Schedule M-1, line 5 — Expenses recorded on books not deducted on this return'),
    ('1120', 'M-2 5a', 190, 'Schedule M-2, line 5a — Distributions: cash'),
    ('1120', 'L1',    200, 'Schedule L, line 1 — Cash'),
    ('1120', 'L2a',   210, 'Schedule L, line 2a — Trade notes and accounts receivable'),
    ('1120', 'L2b',   220, 'Schedule L, line 2b — Less allowance for bad debts'),
    ('1120', 'L3',    230, 'Schedule L, line 3 — Inventories'),
    ('1120', 'L6',    240, 'Schedule L, line 6 — Other current assets'),
    ('1120', 'L7',    250, 'Schedule L, line 7 — Loans to shareholders'),
    ('1120', 'L10a',  260, 'Schedule L, line 10a — Buildings and other depreciable assets'),
    ('1120', 'L10b',  270, 'Schedule L, line 10b — Less accumulated depreciation'),
    ('1120', 'L14',   280, 'Schedule L, line 14 — Other assets'),
    ('1120', 'L16',   290, 'Schedule L, line 16 — Accounts payable'),
    ('1120', 'L17',   300, 'Schedule L, line 17 — Mortgages, notes, bonds payable in less than 1 year'),
    ('1120', 'L18',   310, 'Schedule L, line 18 — Other current liabilities'),
    ('1120', 'L19',   320, 'Schedule L, line 19 — Loans from shareholders'),
    ('1120', 'L20',   330, 'Schedule L, line 20 — Mortgages, notes, bonds payable in 1 year or more'),
    ('1120', 'L22b',  340, 'Schedule L, line 22b — Capital stock: common stock'),
    ('1120', 'L23',   350, 'Schedule L, line 23 — Additional paid-in capital'),
    ('1120', 'L25',   360, 'Schedule L, line 25 — Retained earnings—Unappropriated'),
    ('1120-S', '1a',   10, 'Line 1a — Gross receipts or sales'),
    ('1120-S', '2',    20, 'Line 2 — Cost of goods sold (attach Form 1125-A)'),
    ('1120-S', '4',    30, 'Line 4 — Net gain (loss) from Form 4797'),
    ('1120-S', '5',    40, 'Line 5 — Other income (loss)'),
    ('1120-S', '7',    50, 'Line 7 — Compensation of officers (attach Form 1125-E)'),
    ('1120-S', '8',    60, 'Line 8 — Salaries and wages (less employment credits)'),
    ('1120-S', '9',    70, 'Line 9 — Repairs and maintenance'),
    ('1120-S', '10',   80, 'Line 10 — Bad debts'),
    ('1120-S', '11',   90, 'Line 11 — Rents'),
    ('1120-S', '12',  100, 'Line 12 — Taxes and licenses'),
    ('1120-S', '13',  110, 'Line 13 — Interest'),
    ('1120-S', '14',  120, 'Line 14 — Depreciation (attach Form 4562)'),
    ('1120-S', '16',  130, 'Line 16 — Advertising'),
    ('1120-S', '18',  140, 'Line 18 — Employee benefit programs'),
    ('1120-S', '20',  150, 'Line 20 — Other deductions (attach statement)'),
    ('1120-S', 'K4',  160, 'Schedule K, line 4 — Interest income'),
    ('1120-S', 'K12a', 170, 'Schedule K, line 12a — Charitable contributions'),
    ('1120-S', 'K16c', 180, 'Schedule K, line 16c — Nondeductible expenses'),
    ('1120-S', 'K16d', 190, 'Schedule K, line 16d — Distributions (also Schedule M-2, line 7)'),
    ('1120-S', 'L1',  200, 'Schedule L, line 1 — Cash'),
    ('1120-S', 'L2a', 210, 'Schedule L, line 2a — Trade notes and accounts receivable'),
    ('1120-S', 'L2b', 220, 'Schedule L, line 2b — Less allowance for bad debts'),
    ('1120-S', 'L3',  230, 'Schedule L, line 3 — Inventories'),
    ('1120-S', 'L6',  240, 'Schedule L, line 6 — Other current assets'),
    ('1120-S', 'L7',  250, 'Schedule L, line 7 — Loans to shareholders'),
    ('1120-S', 'L10a', 260, 'Schedule L, line 10a — Buildings and other depreciable assets'),
    ('1120-S', 'L10b', 270, 'Schedule L, line 10b — Less accumulated depreciation'),
    ('1120-S', 'L14', 280, 'Schedule L, line 14 — Other assets'),
    ('1120-S', 'L16', 290, 'Schedule L, line 16 — Accounts payable'),
    ('1120-S', 'L17', 300, 'Schedule L, line 17 — Mortgages, notes, bonds payable in less than 1 year'),
    ('1120-S', 'L18', 310, 'Schedule L, line 18 — Other current liabilities'),
    ('1120-S', 'L19', 320, 'Schedule L, line 19 — Loans from shareholders'),
    ('1120-S', 'L20', 330, 'Schedule L, line 20 — Mortgages, notes, bonds payable in 1 year or more'),
    ('1120-S', 'L22', 340, 'Schedule L, line 22 — Capital stock'),
    ('1120-S', 'L23', 350, 'Schedule L, line 23 — Additional paid-in capital'),
    ('1120-S', 'L24', 360, 'Schedule L, line 24 — Retained earnings'),
    ('1125-A', '1',    10, 'Form 1125-A, line 1 — Inventory at beginning of year'),
    ('1125-A', '2',    20, 'Form 1125-A, line 2 — Purchases'),
    ('1125-A', '3',    30, 'Form 1125-A, line 3 — Cost of labor'),
    ('1125-A', '5',    50, 'Form 1125-A, line 5 — Other costs (attach schedule)'),
    ('1125-A', '7',    70, 'Form 1125-A, line 7 — Inventory at end of year');
  perform set_config('mx_fiscal.escribe', 'fiscal_cuentas', true);
  insert into public.fiscal_cuentas as fc (codigo, nombre_en, seccion_en, grupo_en, orden, linea_1120, linea_1120s, linea_1125a, nota_en)
  select v.codigo, v.nombre_en, v.seccion_en, v.grupo_en, v.orden, v.l1120, v.l1120s, v.l1125a, v.nota_en
    from (values
      ('1010', 'Operating Checking',                        'Assets', 'Current Assets', 1010, 'L1',   'L1',   null, null),
      ('1020', 'Stripe — Payments in Transit',              'Assets', 'Current Assets', 1020, 'L1',   'L1',   null, 'Clearing account for online payments; clears to the bank within days.'),
      ('1030', 'Tax Reserve Savings',                       'Assets', 'Current Assets', 1030, 'L1',   'L1',   null, null),
      ('1050', 'Petty Cash',                                'Assets', 'Current Assets', 1050, 'L1',   'L1',   null, null),
      ('1110', 'Accounts Receivable',                       'Assets', 'Current Assets', 1110, 'L2a',  'L2a',  null, null),
      ('1120', 'Retainage Receivable',                      'Assets', 'Current Assets', 1120, 'L2a',  'L2a',  null, null),
      ('1130', 'Due from Shareholder',                      'Assets', 'Other Assets',   1130, 'L7',   'L7',   null, 'Shareholder loan receivable; review for constructive distribution.'),
      ('1140', 'Stripe — Payouts in Transit',               'Assets', 'Current Assets', 1140, 'L1',   'L1',   null, 'Clearing account; payouts on their way to the bank.'),
      ('1190', 'Allowance for Doubtful Accounts',           'Assets', 'Current Assets', 1190, 'L2b',  'L2b',  null, 'Book allowance; tax uses the specific charge-off method.'),
      ('1200', 'Costs & Estimated Earnings in Excess of Billings', 'Assets', 'Current Assets', 1200, 'L6', 'L6', null, 'Underbillings (WIP schedule).'),
      ('1300', 'Materials Inventory',                       'Assets', 'Current Assets', 1300, 'L3',   'L3',   '7',  'Form 1125-A: ending inventory (line 7); prior year-end balance is line 1.'),
      ('1410', 'Prepaid Insurance',                         'Assets', 'Current Assets', 1410, 'L6',   'L6',   null, null),
      ('1420', 'Prepaid Surety Bonds',                      'Assets', 'Current Assets', 1420, 'L6',   'L6',   null, null),
      ('1510', 'Vehicles',                                  'Assets', 'Fixed Assets',   1510, 'L10a', 'L10a', null, null),
      ('1520', 'Tools & Equipment',                         'Assets', 'Fixed Assets',   1520, 'L10a', 'L10a', null, null),
      ('1530', 'Computer Equipment',                        'Assets', 'Fixed Assets',   1530, 'L10a', 'L10a', null, null),
      ('1540', 'Leasehold Improvements',                    'Assets', 'Fixed Assets',   1540, 'L10a', 'L10a', null, null),
      ('1590', 'Accumulated Depreciation',                  'Assets', 'Fixed Assets',   1590, 'L10b', 'L10b', null, 'Book depreciation; tax depreciation per Form 4562.'),
      ('1600', 'Deposits',                                  'Assets', 'Other Assets',   1600, 'L14',  'L14',  null, null),
      ('2010', 'Accounts Payable',                          'Liabilities', 'Current Liabilities', 2010, 'L16', 'L16', null, null),
      ('2020', 'Retainage Payable',                         'Liabilities', 'Current Liabilities', 2020, 'L16', 'L16', null, null),
      ('2050', 'Accrued Expenses',                          'Liabilities', 'Current Liabilities', 2050, 'L18', 'L18', null, null),
      ('2100', 'Credit Cards',                              'Liabilities', 'Current Liabilities', 2100, 'L18', 'L18', null, null),
      ('2210', 'Accrued Wages',                             'Liabilities', 'Current Liabilities', 2210, 'L18', 'L18', null, null),
      ('2215', 'Accrued Paid Time Off',                     'Liabilities', 'Current Liabilities', 2215, 'L18', 'L18', null, null),
      ('2220', 'Payroll Taxes Withheld (Form 941)',         'Liabilities', 'Current Liabilities', 2220, 'L18', 'L18', null, null),
      ('2225', 'FUTA Payable (Form 940)',                   'Liabilities', 'Current Liabilities', 2225, 'L18', 'L18', null, null),
      ('2230', 'Florida Reemployment Tax Payable (RT-6)',   'Liabilities', 'Current Liabilities', 2230, 'L18', 'L18', null, null),
      ('2240', 'Employee Deductions Payable',               'Liabilities', 'Current Liabilities', 2240, 'L18', 'L18', null, null),
      ('2250', 'Employee Reimbursements Payable',           'Liabilities', 'Current Liabilities', 2250, 'L18', 'L18', null, null),
      ('2300', 'Use Tax Payable',                           'Liabilities', 'Current Liabilities', 2300, 'L18', 'L18', null, 'Florida use tax (Form DR-15).'),
      ('2400', 'Billings in Excess of Costs & Estimated Earnings', 'Liabilities', 'Current Liabilities', 2400, 'L18', 'L18', null, 'Overbillings (WIP schedule).'),
      ('2410', 'Provision for Contract Losses',             'Liabilities', 'Current Liabilities', 2410, 'L18', 'L18', null, 'Book accrual; see account 5950.'),
      ('2510', 'Line of Credit',                            'Liabilities', 'Current Liabilities', 2510, 'L17', 'L17', null, null),
      ('2520', 'Vehicle Loans — Current Portion',           'Liabilities', 'Current Liabilities', 2520, 'L17', 'L17', null, null),
      ('2530', 'Vehicle Loans — Long-Term',                 'Liabilities', 'Long-Term Liabilities', 2530, 'L20', 'L20', null, null),
      ('2540', 'Business Loans — Current Portion',          'Liabilities', 'Current Liabilities', 2540, 'L17', 'L17', null, null),
      ('2550', 'Business Loans — Long-Term',                'Liabilities', 'Long-Term Liabilities', 2550, 'L20', 'L20', null, null),
      ('2900', 'Loan from Shareholder',                     'Liabilities', 'Long-Term Liabilities', 2900, 'L19', 'L19', null, null),
      ('3000', 'Common Stock',                              'Equity', 'Shareholder''s Equity', 3000, 'L22b', 'L22', null, null),
      ('3100', 'Additional Paid-In Capital',                'Equity', 'Shareholder''s Equity', 3100, 'L23',  'L23', null, null),
      ('3200', 'Shareholder Distributions',                 'Equity', 'Shareholder''s Equity', 3200, 'M-2 5a', 'K16d', null, 'Not an expense. C corporation: a dividend to the shareholder (Form 1099-DIV may apply). S corporation: Schedule K, line 16d and Schedule M-2, line 7. Includes personal charges paid by the company.'),
      ('3900', 'Retained Earnings',                         'Equity', 'Shareholder''s Equity', 3900, 'L25',  'L24', null, null),
      ('4010', 'Contract Revenue — Residential',            'Income', null, 4010, '1a', '1a', null, null),
      ('4020', 'Contract Revenue — Commercial',             'Income', null, 4020, '1a', '1a', null, null),
      ('4030', 'Service & T&M Revenue',                     'Income', null, 4030, '1a', '1a', null, null),
      ('4040', 'Change Order Revenue',                      'Income', null, 4040, '1a', '1a', null, null),
      ('4900', 'Other Income',                              'Other Income', null, 4900, '10', '5',  null, null),
      ('4910', 'Interest Income',                           'Other Income', null, 4910, '5',  'K4', null, 'S corporation: portfolio income, reported on Schedule K (not on page 1).'),
      ('4920', 'Gain (Loss) on Sale of Assets',             'Other Income', null, 4920, '9',  '4',  null, 'Form 4797.'),
      ('5000', 'Direct Labor',                              'Cost of Goods Sold (Job Costs)', null, 5000, '2', '2', '3', null),
      ('5001', 'Direct Labor — Officer',                    'Cost of Goods Sold (Job Costs)', null, 5001, '2', '2', '3', 'Officer compensation included in cost of labor: report on Form 1125-E and subtract what is claimed on Form 1125-A.'),
      ('5010', 'Labor Burden',                              'Cost of Goods Sold (Job Costs)', null, 5010, '2', '2', '5', 'Payroll taxes, workers'' compensation and benefits on direct labor.'),
      ('5011', 'Labor Burden Applied to Jobs',              'Cost of Goods Sold (Job Costs)', null, 5011, '2', '2', '5', 'Standard burden applied to jobs; nets against 5015 and 5019.'),
      ('5015', 'Labor Burden — Actual',                     'Cost of Goods Sold (Job Costs)', null, 5015, '2', '2', '5', null),
      ('5019', 'Labor Burden Variance',                     'Cost of Goods Sold (Job Costs)', null, 5019, '2', '2', '5', null),
      ('5100', 'Job Materials',                             'Cost of Goods Sold (Job Costs)', null, 5100, '2', '2', '2', null),
      ('5200', 'Subcontractors',                            'Cost of Goods Sold (Job Costs)', null, 5200, '2', '2', '5', 'Form 1099-NEC for each subcontractor paid $600 or more.'),
      ('5300', 'Equipment Rental',                          'Cost of Goods Sold (Job Costs)', null, 5300, '2', '2', '5', null),
      ('5400', 'Permits & Inspections',                     'Cost of Goods Sold (Job Costs)', null, 5400, '2', '2', '5', null),
      ('5500', 'Job Supplies',                              'Cost of Goods Sold (Job Costs)', null, 5500, '2', '2', '5', null),
      ('5600', 'Freight',                                   'Cost of Goods Sold (Job Costs)', null, 5600, '2', '2', '5', null),
      ('5900', 'Warranty & Rework',                         'Cost of Goods Sold (Job Costs)', null, 5900, '2', '2', '5', null),
      ('5950', 'Provision for Contract Losses',             'Cost of Goods Sold (Job Costs)', null, 5950, '2', '2', '5', 'Book accrual for expected losses; not deductible until realized (Schedule M-1 adjustment).'),
      ('6000', 'Admin Salaries',                            'Operating Expenses', null, 6000, '13', '8',  null, null),
      ('6005', 'Officer Compensation',                      'Operating Expenses', null, 6005, '12', '7',  null, 'Form 1125-E. S corporation: reasonable compensation of the shareholder-employee.'),
      ('6006', 'Shareholder Health Insurance (>2%)',        'Operating Expenses', null, 6006, '24', '7',  null, 'S corporation: include in the shareholder''s W-2 wages (line 7). C corporation: employee benefit programs (line 24).'),
      ('6010', 'Payroll Taxes & Burden — Admin',            'Operating Expenses', null, 6010, '17', '12', null, 'Employer payroll taxes; any workers'' compensation or benefits portion belongs in other deductions or employee benefits.'),
      ('6100', 'Rent',                                      'Operating Expenses', null, 6100, '16', '11', null, null),
      ('6110', 'Utilities',                                 'Operating Expenses', null, 6110, '26', '20', null, null),
      ('6120', 'Telephone & Internet',                      'Operating Expenses', null, 6120, '26', '20', null, null),
      ('6130', 'Bank & Merchant Fees',                      'Operating Expenses', null, 6130, '26', '20', null, null),
      ('6200', 'Insurance',                                 'Operating Expenses', null, 6200, '26', '20', null, 'General liability, auto and umbrella.'),
      ('6300', 'Vehicle Expense',                           'Operating Expenses', null, 6300, '26', '20', null, 'Fuel, tolls, repairs and maintenance (actual expenses).'),
      ('6350', 'Meals (50%)',                               'Operating Expenses', null, 6350, '26', '20', null, 'Booked at 100%; 50% deductible. Nondeductible half: Form 1120 Schedule M-1, line 5c / Form 1120-S Schedule K, line 16c.'),
      ('6360', 'Travel',                                    'Operating Expenses', null, 6360, '26', '20', null, null),
      ('6400', 'Small Tools & Uniforms',                    'Operating Expenses', null, 6400, '26', '20', null, null),
      ('6500', 'Office & Software',                         'Operating Expenses', null, 6500, '26', '20', null, null),
      ('6600', 'Professional Fees',                         'Operating Expenses', null, 6600, '26', '20', null, 'Accounting and legal.'),
      ('6610', 'License Qualifier Fees',                    'Operating Expenses', null, 6610, '26', '20', null, null),
      ('6700', 'Advertising',                               'Operating Expenses', null, 6700, '22', '16', null, null),
      ('6800', 'Licenses & Dues',                           'Operating Expenses', null, 6800, '17', '12', null, null),
      ('6900', 'Training',                                  'Operating Expenses', null, 6900, '26', '20', null, null),
      ('6950', 'Depreciation',                              'Operating Expenses', null, 6950, '20', '14', null, 'Book depreciation; tax depreciation per Form 4562 (Section 179 / bonus are the CPA''s election).'),
      ('6980', 'Bad Debt',                                  'Operating Expenses', null, 6980, '15', '10', null, 'Deductible when specifically charged off.'),
      ('9000', 'Taxes & Licenses',                          'Operating Expenses', null, 9000, '17', '12', null, 'Business taxes of the company (not the shareholder''s income tax).'),
      ('7100', 'Interest Expense',                          'Other Expense', null, 7100, '18', '13', null, null),
      ('7900', 'Other Expense',                             'Other Expense', null, 7900, '26', '20', null, null),
      ('7910', 'Charitable Contributions',                  'Other Expense', null, 7910, '19', 'K12a', null, 'C corporation: limited to 10% of taxable income. S corporation: passes through on Schedule K.'),
      ('7920', 'Penalties & Fines',                         'Other Expense', null, 7920, 'M-1', 'K16c', null, 'Nondeductible.')
    ) as v(codigo, nombre_en, seccion_en, grupo_en, orden, l1120, l1120s, l1125a, nota_en)
   where exists (select 1 from public.cuentas k where k.codigo = v.codigo)
  on conflict (codigo) do update
     set nombre_en = excluded.nombre_en, seccion_en = excluded.seccion_en, grupo_en = excluded.grupo_en, orden = excluded.orden,
         linea_1120 = excluded.linea_1120, linea_1120s = excluded.linea_1120s, linea_1125a = excluded.linea_1125a, nota_en = excluded.nota_en
   where not fc.fijada;
  perform set_config('mx_fiscal.escribe', '', true);
end $$;


-- ---------------------------------------------------------------------
-- 3. Las cuentas del plan, en inglés y con su línea: v_fiscal_cuentas.
--    TODAS las cuentas: la que no tiene fila en fiscal_cuentas (una tarjeta
--    dada de alta después, una cuenta nueva) sale con su nombre_en de
--    siempre, la categoría de su tipo y la línea «de bulto» de ese tipo, y
--    «mapeada» en falso: el control la enseña para que se le ponga la suya.
-- ---------------------------------------------------------------------
create or replace view public.v_fiscal_cuentas with (security_invoker = true) as
  select k.codigo,
         k.nombre,
         coalesce(fc.nombre_en, case when k.codigo like '2100-%' then 'Credit Card — ' || coalesce(k.nombre_en, k.nombre) end, k.nombre_en, k.nombre) as nombre_en,
         k.tipo,
         coalesce(fc.seccion_en, case k.tipo when 'activo' then 'Assets' when 'pasivo' then 'Liabilities' when 'capital' then 'Equity'
                                             when 'ingreso' then 'Income' when 'costo' then 'Cost of Goods Sold (Job Costs)'
                                             when 'gasto' then 'Operating Expenses' when 'otro_ingreso' then 'Other Income'
                                             else 'Other Expense' end) as seccion_en,
         coalesce(fc.grupo_en, case when k.tipo = 'pasivo' then 'Current Liabilities' when k.tipo = 'activo' then 'Current Assets' end) as grupo_en,
         coalesce(fc.orden, 99999) as orden,
         coalesce(fc.linea_1120, case k.tipo when 'activo' then case when k.codigo ~ '^10' then 'L1' else 'L6' end when 'pasivo' then 'L18'
                                             when 'capital' then 'L25' when 'ingreso' then '1a' when 'costo' then '2' when 'gasto' then '26'
                                             when 'otro_ingreso' then '10' else '26' end) as linea_1120,
         coalesce(fc.linea_1120s, case k.tipo when 'activo' then case when k.codigo ~ '^10' then 'L1' else 'L6' end when 'pasivo' then 'L18'
                                              when 'capital' then 'L24' when 'ingreso' then '1a' when 'costo' then '2' when 'gasto' then '20'
                                              when 'otro_ingreso' then '5' else '20' end) as linea_1120s,
         coalesce(fc.linea_1125a, case when k.tipo = 'costo' and fc.codigo is null then '5' end) as linea_1125a,
         fc.nota_en,
         (fc.codigo is not null or k.codigo like '2100-%') as mapeada,
         coalesce(fc.fijada, false) as fijada,
         k.imputable
    from public.cuentas k
    left join public.fiscal_cuentas fc on fc.codigo = k.codigo;
revoke all on public.v_fiscal_cuentas from public, anon, authenticated, service_role;
grant select on public.v_fiscal_cuentas to authenticated;
comment on view public.v_fiscal_cuentas is 'c18: todas las cuentas del plan con su nombre estándar en inglés, su categoría y su línea en el Form 1120, el 1120-S y el 1125-A; mapeada = tiene su fila (o es una tarjeta); la que no, sale con lo de su tipo.';


-- ---------------------------------------------------------------------
-- 4. Lo que se cambia: la forma (UN ajuste) y el mapeo de una cuenta.
-- ---------------------------------------------------------------------
-- fn_fiscal_forma('{"forma": "1120-S"}') cambia la forma; con
-- {"confirmada": true} queda escrito quién lo confirmó con el CPA y cuándo
-- (y deja de salir el aviso en el paquete); {"nota": "…"} guarda lo que dijo
-- el CPA. Cambiar la forma quita la confirmación, salvo que se confirme en
-- la misma llamada.
create or replace function public.fn_fiscal_forma(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r        fiscal_config;
  v_forma  text := nullif(btrim(coalesce(p->>'forma', '')), '');
  v_conf   boolean := case when p ? 'confirmada' then (p->>'confirmada')::boolean end;
begin
  perform fn_fiscal_exigir_dueno();
  if v_forma is not null and v_forma not in ('1120', '1120-S') then
    raise exception using errcode = '22023', message = 'La forma es «1120» (C-corp) o «1120-S» (S-corp).';
  end if;
  select * into r from fiscal_config where id = 1;
  perform set_config('mx_fiscal.escribe', 'fiscal_config', true);
  update fiscal_config
     set forma = coalesce(v_forma, forma),
         confirmada = coalesce(v_conf, case when v_forma is not null and v_forma <> r.forma then false else confirmada end),
         confirmada_por = case when coalesce(v_conf, false) then auth.uid()
                               when v_conf = false or (v_forma is not null and v_forma <> r.forma) then null else confirmada_por end,
         confirmada_el = case when coalesce(v_conf, false) then now()
                              when v_conf = false or (v_forma is not null and v_forma <> r.forma) then null else confirmada_el end,
         nota = case when p ? 'nota' then nullif(left(btrim(p->>'nota'), 600), '') else nota end,
         actualizado = now(), actualizado_por = auth.uid()
   where id = 1
  returning * into r;
  perform set_config('mx_fiscal.escribe', '', true);
  return jsonb_build_object('forma', r.forma, 'confirmada', r.confirmada, 'confirmada_el', r.confirmada_el, 'nota', r.nota);
end $$;
revoke execute on function public.fn_fiscal_forma(jsonb) from public, anon, service_role;
grant  execute on function public.fn_fiscal_forma(jsonb) to authenticated;
comment on function public.fn_fiscal_forma(jsonb) is 'c18: EL ajuste del tipo de entidad: {forma: «1120» | «1120-S»}, {confirmada: true} (lo confirmó el CPA: queda quién y cuándo) y {nota}. Cambiar la forma quita la confirmación.';

-- fn_fiscal_cuenta('{"codigo": "6300", "linea_1120": "26", …}') cambia el
-- nombre en inglés, la categoría, las líneas o la nota de una cuenta (o le
-- pone su fila a una que no la tenía) y la deja «fijada». Una línea tiene
-- que existir en el catálogo de su forma.
create or replace function public.fn_fiscal_cuenta(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v    record;
  r    fiscal_cuentas;
  v_c  text := nullif(btrim(coalesce(p->>'codigo', '')), '');
begin
  perform fn_fiscal_exigir_dueno();
  select * into v from v_fiscal_cuentas x where x.codigo = v_c;
  if not found then
    raise exception using errcode = '22023', message = 'Esa cuenta no está en el plan de cuentas.';
  end if;
  if (p ? 'linea_1120' and nullif(p->>'linea_1120', '') is not null
      and not exists (select 1 from fiscal_lineas l where l.forma = '1120' and l.linea = p->>'linea_1120'))
     or (p ? 'linea_1120s' and nullif(p->>'linea_1120s', '') is not null
         and not exists (select 1 from fiscal_lineas l where l.forma = '1120-S' and l.linea = p->>'linea_1120s'))
     or (p ? 'linea_1125a' and nullif(p->>'linea_1125a', '') is not null
         and not exists (select 1 from fiscal_lineas l where l.forma = '1125-A' and l.linea = p->>'linea_1125a')) then
    raise exception using errcode = '22023', message = 'Esa línea no está en el catálogo de su formulario (fiscal_lineas).';
  end if;
  perform set_config('mx_fiscal.escribe', 'fiscal_cuentas', true);
  insert into fiscal_cuentas as fc (codigo, nombre_en, seccion_en, grupo_en, orden, linea_1120, linea_1120s, linea_1125a, nota_en, fijada,
                                    cambiada_por, cambiada_el)
  values (v.codigo, coalesce(nullif(btrim(p->>'nombre_en'), ''), v.nombre_en), coalesce(nullif(p->>'seccion_en', ''), v.seccion_en),
          case when p ? 'grupo_en' then nullif(p->>'grupo_en', '') else v.grupo_en end, case when v.orden = 99999 then 90000 else v.orden end,
          case when p ? 'linea_1120' then nullif(p->>'linea_1120', '') else v.linea_1120 end,
          case when p ? 'linea_1120s' then nullif(p->>'linea_1120s', '') else v.linea_1120s end,
          case when p ? 'linea_1125a' then nullif(p->>'linea_1125a', '') else v.linea_1125a end,
          case when p ? 'nota_en' then nullif(left(btrim(p->>'nota_en'), 600), '') else v.nota_en end, true, auth.uid(), now())
  on conflict (codigo) do update
     set nombre_en = excluded.nombre_en, seccion_en = excluded.seccion_en, grupo_en = excluded.grupo_en,
         linea_1120 = excluded.linea_1120, linea_1120s = excluded.linea_1120s, linea_1125a = excluded.linea_1125a, nota_en = excluded.nota_en,
         fijada = true, cambiada_por = excluded.cambiada_por, cambiada_el = excluded.cambiada_el
  returning * into r;
  perform set_config('mx_fiscal.escribe', '', true);
  return to_jsonb(r);
end $$;
revoke execute on function public.fn_fiscal_cuenta(jsonb) from public, anon, service_role;
grant  execute on function public.fn_fiscal_cuenta(jsonb) to authenticated;
comment on function public.fn_fiscal_cuenta(jsonb) is 'c18: cambia el nombre en inglés, la categoría, las líneas del 1120 / 1120-S / 1125-A o la nota de una cuenta, y la deja fijada (volver a pegar no la pisa). Una línea que no está en el catálogo, 22023.';


-- ---------------------------------------------------------------------
-- 5. Lo que lee la pantalla (los estados en inglés) y EL PAQUETE.
-- ---------------------------------------------------------------------
-- fn_fiscal_leer(): la configuración, las etiquetas en inglés de las
-- secciones del estado de resultados (las de un contratista) y, por cuenta,
-- su nombre en inglés, su categoría y su línea en la forma elegida.
create or replace function public.fn_fiscal_leer() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg fiscal_config;
begin
  perform fn_fiscal_exigir_dueno();
  if current_user = 'service_role' then
    return null;
  end if;
  select * into cfg from fiscal_config where id = 1;
  return jsonb_build_object(
    'version', fn_fiscal_version(),
    'config', jsonb_build_object('forma', cfg.forma, 'confirmada', cfg.confirmada, 'confirmada_el', cfg.confirmada_el, 'nota', cfg.nota,
                                 'formas_anio', cfg.formas_anio, 'idioma_reportes', cfg.idioma_reportes,
                                 'entidad_en', case cfg.forma when '1120' then 'C corporation (Form 1120)' else 'S corporation (Form 1120-S)' end),
    'secciones', jsonb_build_object(
      'ingresos', 'Income', 'costo', 'Cost of Goods Sold (Job Costs)', 'utilidad_bruta', 'Gross Profit', 'gastos', 'Operating Expenses',
      'utilidad_operacion', 'Operating Income', 'otros_ingresos', 'Other Income', 'otros_gastos', 'Other Expense', 'utilidad_neta', 'Net Income',
      'perdida_neta', 'Net Loss', 'totales', 'Totals'),
    'cuentas', (select coalesce(jsonb_object_agg(v.codigo, jsonb_strip_nulls(jsonb_build_object(
                         'en', v.nombre_en, 'seccion', v.seccion_en, 'grupo', v.grupo_en,
                         'linea', case cfg.forma when '1120' then v.linea_1120 else v.linea_1120s end, 'linea_1125a', v.linea_1125a,
                         'mapeada', v.mapeada))), '{}'::jsonb)
                  from v_fiscal_cuentas v));
end $$;
revoke execute on function public.fn_fiscal_leer() from public, anon, service_role;
grant  execute on function public.fn_fiscal_leer() to authenticated;
comment on function public.fn_fiscal_leer() is 'c18: lo que la pantalla necesita para enseñar las cuentas y los estados en inglés: la configuración (forma, confirmada), las etiquetas de las secciones y, por cuenta, su nombre en inglés, su categoría y su línea en la forma elegida.';

-- EL PAQUETE DE FIN DE AÑO, en inglés. p_anio: el ejercicio (2026…);
-- p_forma: «1120» o «1120-S» (nulo = la de fiscal_config). Sale de las
-- vistas de c4 para el período del año: la balanza (v_balanza), el estado de
-- resultados (v_resultados) y el balance general (v_balance_general): las
-- mismas cifras que la pantalla de Estados. El resumen por línea suma, por
-- la línea de cada cuenta, lo del año (resultados) o el saldo al cierre
-- (balance); el 1125-A, las cuentas de costo por su línea. NO calcula el
-- impuesto, ni los ajustes fiscales (M-1), ni la depreciación fiscal: dice
-- en sus avisos lo que el CPA tiene que mirar. Solo lee.
-- (Segunda vuelta, 21-nov)
--   · EL CAPITAL DEL SCHEDULE L sale del balance de c4, no del saldo del
--     mayor: las utilidades retenidas (L25 en el 1120, L24 en el 1120-S) son
--     la 3900 MÁS los resultados de los años cerrados y por cerrar, MÁS el
--     resultado del año, MENOS las distribuciones (el cierre del ejercicio en
--     c4 es de presentación y no postea: con solo la 3900, las líneas L no
--     cuadraban y nada lo decía). Con ello va la conciliación de utilidades
--     retenidas (los renglones del Schedule M-2: saldo inicial, utilidad
--     según libros, distribuciones, saldo final) y «schedule_l» dice si las
--     líneas de activo son iguales a las de pasivo y capital.
--   · EL AÑO PARCIAL: si el libro de la app empieza dentro del año (2026:
--     el 1 de octubre; de enero a septiembre está QuickBooks), el paquete lo
--     dice ARRIBA (partial_year, period_start = el arranque del libro, el
--     título sin «Year-End» y el primer aviso): tres meses no se presentan
--     como el año. Y un año que la app NO lleva (anterior a su libro) sale
--     vacío y lo dice (in_books: false, su título y su aviso): ceros con
--     el título de un cierre no son el cierre de ese año.
--   · EL 1125-A lleva su línea 1 (el inventario al inicio) y «Purchases» es
--     lo comprado: el material gastado más lo que subió el inventario; así
--     1 + 2 + 3 + 5 − 7 es el costo de ventas de los libros (form_1125a_check).
create or replace function public.fn_fiscal_paquete(p_anio int, p_forma text default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg      fiscal_config;
  v_forma  text;
  v_per    text := p_anio::text;
  v_tb     jsonb;
  v_is     jsonb;
  v_bs     jsonb;
  v_tax    jsonb;
  v_cogs   jsonb;
  v_avisos text[] := '{}';
  v_x      text;
  v_desde  date;
  v_parc   boolean;
  v_hay    boolean;
  v_libro  date;
  v_cap    jsonb;
  v_l      jsonb;
  v_m2     jsonb;
  v_inv0   numeric;
  v_inv1   numeric;
  v_cogsb  numeric;
  v_chk    jsonb;
  v_lret   text;
begin
  perform fn_fiscal_exigir_dueno();
  if current_user = 'service_role' then
    return null;
  end if;
  if p_anio is null or p_anio < 2020 or p_anio > 2100 then
    raise exception using errcode = '22023', message = 'Di el ejercicio (el año, cuatro cifras).';
  end if;
  select * into cfg from fiscal_config where id = 1;
  v_forma := coalesce(nullif(btrim(coalesce(p_forma, '')), ''), cfg.forma);
  if v_forma not in ('1120', '1120-S') then
    raise exception using errcode = '22023', message = 'La forma es «1120» (C-corp) o «1120-S» (S-corp).';
  end if;
  -- la balanza del año, por cuenta, con su nombre en inglés y su línea
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'account', b.cuenta, 'name', v.nombre_en, 'name_es', v.nombre, 'category', v.seccion_en, 'group', v.grupo_en,
           'beginning', b.saldo_inicial, 'debits', b.debe, 'credits', b.haber, 'ending', b.saldo_final,
           'tax_line', case v_forma when '1120' then v.linea_1120 else v.linea_1120s end, 'form_1125a_line', v.linea_1125a,
           'note', v.nota_en)) order by b.cuenta), '[]'::jsonb)
    into v_tb
    from v_balanza b
    join v_fiscal_cuentas v on v.codigo = b.cuenta
   where b.periodo = v_per and b.nivel = 'cuenta';
  -- el estado de resultados: las secciones y los totales de c4 con la etiqueta de un contratista; las cuentas, con su nombre estándar
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'level', case r.nivel when 'seccion' then 'section' when 'cuenta' then 'account' when 'total' then 'total' else r.nivel end,
           'section', r.seccion, 'account', r.cuenta,
           'label', case when r.nivel = 'cuenta' then coalesce(v.nombre_en, r.etiqueta_en, r.etiqueta_es)
                         else coalesce(case r.linea when 'ingresos' then 'Income' when 'costo' then 'Cost of Goods Sold (Job Costs)'
                                                    when 'utilidad_bruta' then 'Gross Profit' when 'gastos' then 'Operating Expenses'
                                                    when 'utilidad_operacion' then 'Operating Income' when 'otros_ingresos' then 'Other Income'
                                                    when 'otros_gastos' then 'Other Expense'
                                                    when 'utilidad_neta' then case when coalesce(r.mes, 0) < 0 then 'Net Loss' else 'Net Income' end end,
                                       r.etiqueta_en, r.etiqueta_es) end,
           'amount', r.mes)) order by r.seccion_orden, r.linea_orden, r.orden), '[]'::jsonb)
    into v_is
    from v_resultados r
    left join v_fiscal_cuentas v on v.codigo = r.cuenta
   where r.periodo = v_per;
  -- el balance general al cierre del año (las etiquetas en inglés de c4; las cuentas, con su nombre estándar)
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'level', case g.nivel when 'seccion' then 'section' when 'linea' then 'line' when 'cuenta' then 'account'
                                 when 'componente' then 'component' when 'total' then 'total' else g.nivel end,
           'section', g.seccion, 'account', g.cuenta,
           'label', case when g.nivel = 'cuenta' then coalesce(v.nombre_en, g.etiqueta_en, g.etiqueta_es) else coalesce(g.etiqueta_en, g.etiqueta_es) end,
           'amount', g.cifra, 'balanced', case when g.linea = 'cuadra' then g.cuadra end)) order by g.seccion_orden, g.linea_orden, g.orden), '[]'::jsonb)
    into v_bs
    from v_balance_general g
    left join v_fiscal_cuentas v on v.codigo = g.cuenta
   where g.periodo = v_per;
  -- el resumen por línea del formulario: lo del año de las cuentas de resultados (en su signo de presentación: un ingreso y un
  -- gasto, en positivo) y el saldo al cierre de las de balance (un activo en positivo; un pasivo y el capital, en positivo)
  with mov as (
    select v.codigo, v.nombre_en, v.tipo, case v_forma when '1120' then v.linea_1120 else v.linea_1120s end as linea,
           case when v.tipo in ('ingreso', 'otro_ingreso') then -(b.saldo_final - b.saldo_inicial)
                when v.tipo in ('costo', 'gasto', 'otro_gasto') then b.saldo_final - b.saldo_inicial
                when v.tipo = 'activo' then b.saldo_final
                when v.codigo = '3200' then b.saldo_final - b.saldo_inicial
                else -b.saldo_final end as monto
      from v_balanza b
      join v_fiscal_cuentas v on v.codigo = b.cuenta
     where b.periodo = v_per and b.nivel = 'cuenta')
  select coalesce(jsonb_agg(jsonb_build_object(
           'form', v_forma, 'line', l.linea, 'label', l.etiqueta_en, 'amount', t.monto,
           'accounts', t.cuentas) order by l.orden), '[]'::jsonb)
    into v_tax
    from fiscal_lineas l
    join (select m.linea, sum(m.monto) as monto,
                 jsonb_agg(jsonb_build_object('account', m.codigo, 'name', m.nombre_en, 'amount', m.monto) order by m.codigo) as cuentas
            from mov m where m.monto <> 0 group by m.linea) t on t.linea = l.linea
   where l.forma = v_forma
     -- (las utilidades retenidas no son el saldo del mayor de la 3900: van abajo, del balance de c4)
     and l.linea <> case v_forma when '1120' then 'L25' else 'L24' end;
  -- EL CAPITAL DEL SCHEDULE L, como el balance de c4: sus renglones del capital al cierre del año. Las utilidades retenidas son
  -- todo el capital que no es capital social ni aportaciones (la 3900, los resultados de años anteriores, el del año y, restando,
  -- las distribuciones): así las líneas L de activo son las de pasivo y capital cuando el balance de c4 cuadra
  v_lret := case v_forma when '1120' then 'L25' else 'L24' end;
  select jsonb_build_object(
           'total', coalesce(max(g.cifra) filter (where g.linea = 'total_capital'), 0),
           'stock', coalesce(sum(g.cifra) filter (where g.nivel = 'linea' and g.linea = 'capital_social'), 0),
           'paid_in', coalesce(sum(g.cifra) filter (where g.nivel = 'linea' and g.linea = 'aportaciones'), 0),
           'net_income', coalesce(sum(g.cifra) filter (where g.nivel = 'linea' and g.linea = 'resultado_ejercicio'), 0),
           'components', coalesce(jsonb_agg(jsonb_build_object('name', coalesce(g.etiqueta_en, g.etiqueta_es), 'amount', g.cifra)
                                            order by g.linea_orden)
                                    filter (where g.nivel = 'linea' and g.seccion = 'capital'
                                              and g.linea not in ('capital_social', 'aportaciones') and coalesce(g.cifra, 0) <> 0), '[]'::jsonb))
    into v_cap
    from v_balance_general g
   where g.periodo = v_per and (g.seccion = 'capital' or g.linea = 'total_capital');
  if (v_cap->>'total')::numeric - (v_cap->>'stock')::numeric - (v_cap->>'paid_in')::numeric <> 0 then
    select coalesce(jsonb_agg(x.t order by x.o), '[]'::jsonb) into v_tax
      from (select t, (select l.orden from fiscal_lineas l where l.forma = v_forma and l.linea = t->>'line') as o
              from jsonb_array_elements(v_tax) t
            union all
            select jsonb_build_object('form', v_forma, 'line', l.linea, 'label', l.etiqueta_en,
                                      'amount', (v_cap->>'total')::numeric - (v_cap->>'stock')::numeric - (v_cap->>'paid_in')::numeric,
                                      'accounts', v_cap->'components',
                                      'note', 'Per the balance sheet: retained earnings account plus prior-year results, plus net income for the year, less shareholder distributions (the books do not post a year-end closing entry).'),
                   l.orden
              from fiscal_lineas l where l.forma = v_forma and l.linea = v_lret) x;
  end if;
  -- ¿cuadran las líneas L? (activo = pasivo + capital, por el orden del catálogo: 200–289 activo, 290–339 pasivo, 340–369 capital)
  select jsonb_build_object(
           'assets', coalesce(sum((t->>'amount')::numeric) filter (where l.orden between 200 and 289), 0),
           'liabilities', coalesce(sum((t->>'amount')::numeric) filter (where l.orden between 290 and 339), 0),
           'equity', coalesce(sum((t->>'amount')::numeric) filter (where l.orden between 340 and 369), 0))
    into v_l
    from jsonb_array_elements(v_tax) t
    join fiscal_lineas l on l.forma = v_forma and l.linea = t->>'line'
   where l.linea like 'L%';
  v_l := v_l || jsonb_build_object('liabilities_and_equity', (v_l->>'liabilities')::numeric + (v_l->>'equity')::numeric,
                                   'balanced', (v_l->>'assets')::numeric = (v_l->>'liabilities')::numeric + (v_l->>'equity')::numeric);
  -- la conciliación de las utilidades retenidas (los renglones del Schedule M-2), según libros
  select jsonb_build_object('dist', coalesce(sum(b.saldo_final - b.saldo_inicial) filter (where b.cuenta like '3200%'), 0),
                            'otros', coalesce(-sum(b.saldo_final - b.saldo_inicial) filter (where b.cuenta like '3900%'), 0))
    into v_m2
    from v_balanza b where b.periodo = v_per and b.nivel = 'cuenta' and (b.cuenta like '3200%' or b.cuenta like '3900%');
  v_m2 := jsonb_build_object(
    'basis', 'Per books',
    'ending', (v_cap->>'total')::numeric - (v_cap->>'stock')::numeric - (v_cap->>'paid_in')::numeric,
    'net_income', (v_cap->>'net_income')::numeric,
    'distributions', (v_m2->>'dist')::numeric,
    'other_changes', (v_m2->>'otros')::numeric,
    'beginning', (v_cap->>'total')::numeric - (v_cap->>'stock')::numeric - (v_cap->>'paid_in')::numeric
                 - (v_cap->>'net_income')::numeric + (v_m2->>'dist')::numeric - (v_m2->>'otros')::numeric);
  v_m2 := v_m2 || jsonb_build_object('rows', jsonb_build_array(
    jsonb_build_object('line', case v_forma when '1120' then 'M-2 1' else 'RE 1' end,
                       'label', case v_forma when '1120' then 'Schedule M-2, line 1 — Balance at beginning of year'
                                                           else 'Retained earnings per books — beginning of year' end, 'amount', v_m2->'beginning'),
    jsonb_build_object('line', case v_forma when '1120' then 'M-2 2' else 'RE 2' end,
                       'label', case v_forma when '1120' then 'Schedule M-2, line 2 — Net income (loss) per books' else 'Net income (loss) per books' end,
                       'amount', v_m2->'net_income'),
    jsonb_build_object('line', case v_forma when '1120' then 'M-2 3' else 'RE 3' end,
                       'label', case v_forma when '1120' then 'Schedule M-2, line 3 — Other increases (direct entries to retained earnings)'
                                                           else 'Other changes (direct entries to retained earnings)' end, 'amount', v_m2->'other_changes'),
    jsonb_build_object('line', case v_forma when '1120' then 'M-2 5a' else 'K16d' end,
                       'label', case v_forma when '1120' then 'Schedule M-2, line 5a — Distributions: cash'
                                                           else 'Distributions (Schedule K, line 16d)' end, 'amount', v_m2->'distributions'),
    jsonb_build_object('line', case v_forma when '1120' then 'M-2 8' else 'L24' end,
                       'label', case v_forma when '1120' then 'Schedule M-2, line 8 — Balance at end of year (Schedule L, line 25)'
                                                           else 'Retained earnings per books — end of year (Schedule L, line 24)' end, 'amount', v_m2->'ending')));
  -- el Form 1125-A: las cuentas de costo por su línea (y el inventario al cierre)
  select coalesce(jsonb_agg(jsonb_build_object('form', '1125-A', 'line', l.linea, 'label', l.etiqueta_en, 'amount', t.monto, 'accounts', t.cuentas)
                            order by l.orden), '[]'::jsonb)
    into v_cogs
    from fiscal_lineas l
    join (select v.linea_1125a as linea,
                 sum(case when v.tipo = 'activo' then b.saldo_final else b.saldo_final - b.saldo_inicial end) as monto,
                 jsonb_agg(jsonb_build_object('account', v.codigo, 'name', v.nombre_en,
                                              'amount', case when v.tipo = 'activo' then b.saldo_final else b.saldo_final - b.saldo_inicial end)
                           order by v.codigo) as cuentas
            from v_balanza b
            join v_fiscal_cuentas v on v.codigo = b.cuenta
           where b.periodo = v_per and b.nivel = 'cuenta' and v.linea_1125a is not null
             and (case when v.tipo = 'activo' then b.saldo_final else b.saldo_final - b.saldo_inicial end) <> 0
           group by v.linea_1125a) t on t.linea = l.linea
   where l.forma = '1125-A';
  -- el inventario (las cuentas de activo con línea del 1125-A): al inicio (línea 1) y al cierre (línea 7); y «Purchases» (línea
  -- 2) es lo COMPRADO: el material gastado más lo que subió el inventario. Así 1 + 2 + 3 + 5 − 7 es el costo de ventas de los libros
  select coalesce(sum(b.saldo_inicial), 0), coalesce(sum(b.saldo_final), 0) into v_inv0, v_inv1
    from v_balanza b join v_fiscal_cuentas v on v.codigo = b.cuenta
   where b.periodo = v_per and b.nivel = 'cuenta' and v.tipo = 'activo' and v.linea_1125a is not null;
  select coalesce(sum(b.saldo_final - b.saldo_inicial), 0) into v_cogsb
    from v_balanza b join v_fiscal_cuentas v on v.codigo = b.cuenta
   where b.periodo = v_per and b.nivel = 'cuenta' and v.tipo = 'costo';
  if v_inv0 <> 0 or v_inv1 <> 0 then
    select coalesce(jsonb_agg(x.t order by x.o), '[]'::jsonb) into v_cogs
      from (select case when t->>'line' = '2' and v_inv1 - v_inv0 <> 0
                        then jsonb_set(jsonb_set(t, '{amount}', to_jsonb((t->>'amount')::numeric + v_inv1 - v_inv0)),
                                       '{accounts}', (t->'accounts') || jsonb_build_array(jsonb_build_object(
                                         'name', 'Change in inventory (ending less beginning)', 'amount', v_inv1 - v_inv0)))
                        else t end as t,
                   (select l.orden from fiscal_lineas l where l.forma = '1125-A' and l.linea = t->>'line') as o
              from jsonb_array_elements(v_cogs) t
            union all
            select jsonb_build_object('form', '1125-A', 'line', l.linea, 'label', l.etiqueta_en, 'amount', v_inv0, 'accounts', '[]'::jsonb), l.orden
              from fiscal_lineas l where l.forma = '1125-A' and l.linea = '1' and v_inv0 <> 0
            union all
            -- (sin material gastado en el año y con inventario comprado: la línea 2 es solo lo que subió el inventario)
            select jsonb_build_object('form', '1125-A', 'line', l.linea, 'label', l.etiqueta_en, 'amount', v_inv1 - v_inv0,
                                      'accounts', jsonb_build_array(jsonb_build_object('name', 'Change in inventory (ending less beginning)',
                                                                                       'amount', v_inv1 - v_inv0))), l.orden
              from fiscal_lineas l
             where l.forma = '1125-A' and l.linea = '2' and v_inv1 - v_inv0 <> 0
               and not exists (select 1 from jsonb_array_elements(v_cogs) t where t->>'line' = '2')) x;
  end if;
  select jsonb_build_object(
           'line_6_total', coalesce(sum((t->>'amount')::numeric) filter (where t->>'line' <> '7'), 0),
           'line_7_ending_inventory', coalesce(sum((t->>'amount')::numeric) filter (where t->>'line' = '7'), 0),
           'line_8_cost_of_goods_sold', coalesce(sum((t->>'amount')::numeric) filter (where t->>'line' <> '7'), 0)
                                        - coalesce(sum((t->>'amount')::numeric) filter (where t->>'line' = '7'), 0),
           'cost_of_goods_sold_per_books', v_cogsb)
    into v_chk
    from jsonb_array_elements(v_cogs) t;
  v_chk := v_chk || jsonb_build_object('matches', (v_chk->>'line_8_cost_of_goods_sold')::numeric = v_cogsb);
  -- EL AÑO PARCIAL: desde cuándo lleva la app el libro de ese año
  select coalesce(min(r.acumulado_desde), make_date(p_anio, 1, 1)) into v_desde from v_resultados r where r.periodo = v_per;
  v_desde := greatest(v_desde, make_date(p_anio, 1, 1));
  v_parc := v_desde > make_date(p_anio, 1, 1);
  -- EL AÑO QUE LA APP NO LLEVA (anterior a su libro, o que todavía no existe): el paquete sale vacío, y lo dice; ceros con el
  -- título de un cierre de año no son el cierre de ese año
  v_hay := exists (select 1 from periodos p where p.tipo = 'anio' and p.anio = p_anio);
  select min(p.desde) into v_libro from periodos p where p.tipo = 'mes';
  -- los avisos, en inglés (es lo que lee el CPA)
  if not v_hay then
    v_avisos := v_avisos || format('NO BOOKS FOR %s IN THIS SYSTEM: this accounting system has no records for that year%s. This package is EMPTY; the records for %s are in the prior accounting system (QuickBooks).',
                                   p_anio, coalesce(format(' (its books start on %s)', v_libro), ''), p_anio);
  end if;
  if v_parc then
    v_avisos := v_avisos || format('PARTIAL YEAR: the books in this system start on %s (opening balances as of %s, carried over from the prior accounting system). The income statement and the tax-line amounts cover %s to %s only; activity from %s to %s is in the prior system (QuickBooks) and is NOT included here.',
                                   v_desde, v_desde - 1, v_desde, make_date(p_anio, 12, 31), make_date(p_anio, 1, 1), v_desde - 1);
  end if;
  if not cfg.confirmada then
    v_avisos := v_avisos || format('ENTITY TYPE PENDING CONFIRMATION: this package uses Form %s (%s). The corporation''s IRS notice CP 575 assigns Form 1120 (C corporation); an S election (Form 2553) has not been confirmed for this entity. Please confirm which form applies before relying on the tax-line summary; the line mapping for the other form is available on request.',
                                   v_forma, case v_forma when '1120' then 'C corporation' else 'S corporation' end);
  elsif v_forma <> cfg.forma then
    v_avisos := v_avisos || format('This package was prepared for Form %s on request; the confirmed form on file is Form %s.', v_forma, cfg.forma);
  end if;
  select string_agg(v.codigo || ' ' || v.nombre_en, '; ' order by v.codigo) into v_x
    from v_fiscal_cuentas v
   where not v.mapeada and exists (select 1 from v_balanza b where b.periodo = v_per and b.nivel = 'cuenta' and b.cuenta = v.codigo
                                      and (b.debe <> 0 or b.haber <> 0 or b.saldo_final <> 0));
  if v_x is not null then
    v_avisos := v_avisos || ('Accounts with activity and no specific tax-line mapping (a default line by account type was used): ' || v_x || '.');
  end if;
  if exists (select 1 from jsonb_array_elements(v_bs) x where x->>'balanced' = 'false') then
    v_avisos := v_avisos || 'The balance sheet does not balance for this period: do not rely on this package until the books are corrected.'::text;
  end if;
  if not (v_l->>'balanced')::boolean then
    v_avisos := v_avisos || format('Schedule L lines do not balance in this summary (assets %s; liabilities and equity %s): do not rely on the Schedule L lines until the books are corrected.',
                                   v_l->>'assets', v_l->>'liabilities_and_equity');
  end if;
  if not (v_chk->>'matches')::boolean then
    v_avisos := v_avisos || format('Form 1125-A lines do not add up to cost of goods sold per books (%s vs %s): an inventory or cost account may be missing its 1125-A line.',
                                   v_chk->>'line_8_cost_of_goods_sold', v_chk->>'cost_of_goods_sold_per_books');
  end if;
  if to_regclass('public.v_ejercicios') is not null then
    execute 'select case when not coalesce((select e.cerrado from public.v_ejercicios e where e.anio = $1), false) '
            'then ''The fiscal year is not closed in the books yet: figures may still change.'' end' into v_x using p_anio;
    if v_x is not null then
      v_avisos := v_avisos || v_x;
    end if;
  end if;
  v_avisos := v_avisos || format('Line numbers follow the %s forms; verify against the forms for tax year %s. Book figures only: no tax adjustments (Schedule M-1), tax depreciation or tax computation are included.',
                                 cfg.formas_anio, p_anio);
  return jsonb_build_object(
    'company', 'Max Power Electrical Solutions, Inc.',
    'title', case when not v_hay then format('Accounting Package — %s (no books for this year in this system)', p_anio)
                  when v_parc then format('Accounting Package — %s (partial year: %s to %s)', p_anio, v_desde, make_date(p_anio, 12, 31))
                  else format('Year-End Accounting Package — %s', p_anio) end,
    'fiscal_year', p_anio, 'period_start', v_desde, 'period_end', make_date(p_anio, 12, 31),
    'partial_year', v_parc, 'books_start', case when v_hay then v_desde else v_libro end, 'in_books', v_hay,
    'entity', jsonb_build_object('form', v_forma, 'type', case v_forma when '1120' then 'C corporation' else 'S corporation' end,
                                 'confirmed', cfg.confirmada and v_forma = cfg.forma, 'note', cfg.nota),
    'basis', 'Accrual basis, per books',
    'generated_at', now(),
    'warnings', to_jsonb(v_avisos),
    'trial_balance', v_tb, 'income_statement', v_is, 'balance_sheet', v_bs, 'tax_lines', v_tax, 'form_1125a', v_cogs,
    'schedule_l', v_l, 'retained_earnings', v_m2, 'form_1125a_check', v_chk,
    'chart_of_accounts', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                   'account', v.codigo, 'name', v.nombre_en, 'name_es', v.nombre, 'category', v.seccion_en, 'group', v.grupo_en,
                                   'form_1120_line', v.linea_1120, 'form_1120s_line', v.linea_1120s, 'form_1125a_line', v.linea_1125a,
                                   'note', v.nota_en)) order by v.codigo), '[]'::jsonb)
                            from v_fiscal_cuentas v where v.imputable));
end $$;
revoke execute on function public.fn_fiscal_paquete(int, text) from public, anon, service_role;
grant  execute on function public.fn_fiscal_paquete(int, text) to authenticated;
comment on function public.fn_fiscal_paquete(int, text) is 'c18: el paquete de fin de año en inglés para el CPA: la balanza, el estado de resultados, el balance general y el resumen por línea del Form 1120 o del 1120-S (con el capital del Schedule L como el balance de c4 y la conciliación de utilidades retenidas) y el 1125-A (con su línea 1), con el plan de cuentas mapeado a las dos formas y sus avisos (el año parcial, el tipo de entidad pendiente de confirmar). Sale de las vistas de c4; solo lee; no calcula el impuesto.';


-- ---------------------------------------------------------------------
-- 6. El control y lo que debe verse al pegar.
-- ---------------------------------------------------------------------
create or replace function public.fn_fiscal_control()
returns table (orden int, control text, nivel text, ok boolean, filas bigint, esperadas bigint, detalle text)
language sql stable
set search_path = public, pg_temp
as $$
  with ve as (select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false) as si)
  select z.orden, z.control, z.nivel, z.ok, z.filas, z.esperadas, z.detalle
    from ve
    cross join lateral (
      select 10 as orden, 'fiscal: la configuración (una fila)'::text as control, 'cuadre'::text as nivel,
             (select count(*) from fiscal_config) = 1 as ok, (select count(*) from fiscal_config) as filas, 1::bigint as esperadas,
             null::text as detalle
      union all
      -- 20: cada línea usada por una cuenta existe en el catálogo de su forma
      select 20, 'fiscal: cada línea del mapeo está en el catálogo de su formulario', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → corrígela con fn_fiscal_cuenta' end
        from (select count(*) as n, left(string_agg(x.que, '; '), 800) as d
                from (select fc.codigo || ' → 1120 «' || fc.linea_1120 || '»' as que from fiscal_cuentas fc
                       where fc.linea_1120 is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1120' and l.linea = fc.linea_1120)
                      union all
                      select fc.codigo || ' → 1120-S «' || fc.linea_1120s || '»' from fiscal_cuentas fc
                       where fc.linea_1120s is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1120-S' and l.linea = fc.linea_1120s)
                      union all
                      select fc.codigo || ' → 1125-A «' || fc.linea_1125a || '»' from fiscal_cuentas fc
                       where fc.linea_1125a is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1125-A' and l.linea = fc.linea_1125a)) x) t
      union all
      -- 30: toda cuenta de costo va a la línea 2 (costo de ventas) y tiene su línea del 1125-A
      select 30, 'fiscal: el costo de obra va al costo de ventas (línea 2 y su línea del 1125-A)', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d end
        from (select count(*) as n, left(string_agg(v.codigo, ', '), 400) as d
                from v_fiscal_cuentas v
               where v.tipo = 'costo' and v.imputable and (v.linea_1120 <> '2' or v.linea_1120s <> '2' or v.linea_1125a is null)) t
      union all
      -- 35: las líneas L del resumen cuadran (activo = pasivo y capital) en el año en curso y en el anterior, si la app los lleva
      select 35, 'fiscal: el Schedule L cuadra (activo = pasivo y capital)', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → mira primero si el balance general de Estados cuadra; si cuadra, alguna cuenta de balance tiene una línea que no es del Schedule L (fn_fiscal_cuenta)' end
        from (select count(*) as n, left(string_agg(format('%s: activo %s, pasivo y capital %s', y.anio, y.s->>'assets', y.s->>'liabilities_and_equity'), '; '), 600) as d
                from (select p.anio, fn_fiscal_paquete(p.anio)->'schedule_l' as s
                        from periodos p
                       where ve.si and current_user <> 'service_role' and p.tipo = 'anio'
                         and p.anio between extract(year from fn_fecha_miami(now()))::int - 1 and extract(year from fn_fecha_miami(now()))::int) y
               where not coalesce((y.s->>'balanced')::boolean, false)) t
      union all
      -- 40 (aviso): cuentas imputables sin su fila de mapeo (salen con la línea de bulto de su tipo)
      select 40, 'fiscal: cada cuenta tiene su línea propia', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → ponle su línea con fn_fiscal_cuenta (mientras, sale con la de su tipo)' end
        from (select count(*) as n, left(string_agg(v.codigo || ' ' || v.nombre, '; ' order by v.codigo), 800) as d
                from v_fiscal_cuentas v where v.imputable and not v.mapeada) t
      union all
      -- 50 (aviso): el tipo de entidad sigue sin confirmar con el CPA
      select 50, 'fiscal: el tipo de entidad está confirmado con el CPA', 'aviso', coalesce((select g.confirmada from fiscal_config g where g.id = 1), false), 0, 0,
             (select format('se usa el Form %s y nadie ha dicho que el CPA lo confirmó → cuando lo confirme: select fn_fiscal_forma(''{"forma": "%s", "confirmada": true}''); (o «1120-S» si es S-corp)',
                            g.forma, g.forma)
                from fiscal_config g where g.id = 1 and not g.confirmada)
    ) z
   where ve.si
$$;
revoke execute on function public.fn_fiscal_control() from public, anon, service_role;
grant  execute on function public.fn_fiscal_control() to authenticated;
comment on function public.fn_fiscal_control() is 'c18: el control del mapeo fiscal: la configuración, que cada línea existe en su catálogo, que el costo va al costo de ventas y que las líneas del Schedule L cuadran (cuadres); las cuentas sin línea propia y el tipo de entidad sin confirmar (avisos).';

create or replace function public.fn_fiscal_pegado() returns table (que text, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_rojo text;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select string_agg(c.control || coalesce(': ' || c.detalle, ''), ' · ') into v_rojo from fn_fiscal_control() c where c.nivel = 'cuadre' and not c.ok;
  return query
  select 'version'::text, 'ok: ' || fn_fiscal_version()
  union all
  select 'forma', (select format('ok: Form %s (%s), %s', g.forma, case g.forma when '1120' then 'C-corp' else 'S-corp' end,
                                 case when g.confirmada then 'confirmada con el CPA' else 'PENDIENTE de confirmar con el CPA (el paquete lo avisa)' end)
                     from fiscal_config g where g.id = 1)
  union all
  select 'lineas', 'ok: ' || (select string_agg(x.forma || ': ' || x.n, ', ' order by x.forma)
                                from (select l.forma, count(*) as n from fiscal_lineas l group by l.forma) x)
  union all
  select 'cuentas', format('ok: %s cuentas con su nombre en inglés y su línea; %s imputables sin línea propia',
                           (select count(*) from fiscal_cuentas), (select count(*) from v_fiscal_cuentas v where v.imputable and not v.mapeada))
  union all
  select 'control', case when v_rojo is null then 'ok: los cuadres del mapeo fiscal están en verde' else 'ROJO: ' || v_rojo end
  union all
  select 'siguiente', 'ok: publica la app: Estados enseña las cuentas y los reportes en inglés y el «Paquete para el contador»';
end $$;
revoke execute on function public.fn_fiscal_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_fiscal_pegado() is 'c18: lo que debe verse al pegar c18-fiscal.sql: una fila por pieza, todas «ok».';

select * from public.fn_fiscal_pegado();
