-- =====================================================================
-- C1 · El plan de cuentas — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, de una vez, ANTES que
-- c2-libro.sql (el libro cuelga de esta tabla). Idempotente: se puede
-- pegar dos veces seguidas sin error y sin duplicar nada.
--
-- Qué hace, en orden:
--   0. PRECONDICIONES. Comprueba lo que este archivo da por hecho y, si
--      falta algo, se para con un mensaje en español ANTES de tocar nada.
--      Sustituye al «bloque 0» de f01: el esquema ya se leyó el 23-sep
--      (docs/conta/ESQUEMA-REAL.md).
--   1. La tabla cuentas. El código no cambia nunca. Una cuenta con
--      movimientos no se borra: se inactiva. Cada cuenta dice qué
--      dimensiones exige a sus líneas (obra y cost code).
--   2. El plan de cuentas BORRADOR: el de f01 más las cuentas que añadió
--      la auditoría. ▶ Pendiente de que Edgar lo corrija.
--
-- LA DECISIÓN DE LOS COST CODES — aquí se asume la OPCIÓN B:
--   El cost code NO forma parte de la cuenta. Es una columna de cada
--   línea del libro (asiento_lineas.cost_code, en c2) con llave foránea a
--   la tabla que YA existe, codigos_partida(codigo). El plan se queda en
--   75 cuentas y el costo se corta por obra, por código, por los dos o
--   por ninguno. No se crea ninguna tabla cost_codes, y aquí NO se
--   inserta nada en codigos_partida: en producción ya tiene sus filas y
--   la maneja Edgar desde la app.
--   Qué cambiaría si Edgar eligiera la A (subcuentas 5100-08-ROUGH…):
--   cada código sería una fila más de esta tabla, hija de su cuenta de
--   costo (codigo '5100-08-ROUGH', padre '5100': el formato ya lo
--   admite); la cuenta madre pasaría a imputable = false; las 5xxx
--   pasarían a regla_cost_code = 'prohibida' (el código ya iría en la
--   cuenta) y la Fase 9 compararía por prefijo de cuenta en vez de por
--   columna. Serían 20 códigos × 9 cuentas = 180 cuentas más: por eso se
--   recomienda la B.
-- =====================================================================


-- =====================================================================
-- 0 · PRECONDICIONES — solo lee. Si algo falta, nada de lo de abajo se
--     aplica (el SQL Editor manda todo en una sola petición).
-- =====================================================================
do $$
declare
  v_falta text := '';
  v_tipo  text;
begin
  -- Los dos candados que ya existen y se reutilizan (no se inventa otro).
  if to_regprocedure('public.es_dueno()') is null then
    v_falta := v_falta || ' · falta la función public.es_dueno()';
  end if;
  if to_regprocedure('public.es_activo()') is null then
    v_falta := v_falta || ' · falta la función public.es_activo()';
  end if;
  if to_regprocedure('auth.uid()') is null then
    v_falta := v_falta || ' · falta auth.uid() (¿esto es Supabase?)';
  end if;

  -- perfiles: de aquí salen el dueño y el equipo.
  if to_regclass('public.perfiles') is null then
    v_falta := v_falta || ' · falta la tabla public.perfiles';
  else
    select data_type into v_tipo from information_schema.columns
     where table_schema = 'public' and table_name = 'perfiles' and column_name = 'id';
    if v_tipo is distinct from 'uuid' then
      v_falta := v_falta || ' · perfiles.id no es uuid';
    end if;
    if not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = 'perfiles' and column_name = 'rol') then
      v_falta := v_falta || ' · perfiles no tiene la columna rol';
    end if;
  end if;

  -- codigos_partida: la dimensión de cost code (opción B). Tiene que
  -- existir, tener filas y un código único al que apuntar con una FK.
  if to_regclass('public.codigos_partida') is null then
    v_falta := v_falta || ' · falta la tabla public.codigos_partida';
  else
    select data_type into v_tipo from information_schema.columns
     where table_schema = 'public' and table_name = 'codigos_partida' and column_name = 'codigo';
    if v_tipo is distinct from 'text' then
      v_falta := v_falta || ' · codigos_partida.codigo no es text';
    elsif not exists (
        select 1 from pg_index i
         where i.indrelid = 'public.codigos_partida'::regclass
           and i.indisunique and i.indimmediate and i.indpred is null and i.indnkeyatts = 1
           and i.indkey[0] = (select attnum from pg_attribute
                               where attrelid = 'public.codigos_partida'::regclass and attname = 'codigo')) then
      v_falta := v_falta || ' · codigos_partida.codigo no tiene llave primaria ni unique (el libro le pondrá una FK)';
    end if;
    if not exists (select 1 from public.codigos_partida) then
      v_falta := v_falta || ' · codigos_partida está vacía (se esperaban los 20 códigos 01-DEMO … 20-MISC)';
    end if;
  end if;

  -- proyectos: toda dimensión de obra del libro es text y apunta aquí.
  if to_regclass('public.proyectos') is null then
    v_falta := v_falta || ' · falta la tabla public.proyectos';
  else
    select data_type into v_tipo from information_schema.columns
     where table_schema = 'public' and table_name = 'proyectos' and column_name = 'id';
    if v_tipo is distinct from 'text' then
      v_falta := v_falta || format(' · proyectos.id es %s y el libro lo da por text', coalesce(v_tipo, 'inexistente'));
    elsif not exists (
        select 1 from pg_index i
         where i.indrelid = 'public.proyectos'::regclass
           and i.indisunique and i.indimmediate and i.indpred is null and i.indnkeyatts = 1
           and i.indkey[0] = (select attnum from pg_attribute
                               where attrelid = 'public.proyectos'::regclass and attname = 'id')) then
      v_falta := v_falta || ' · proyectos.id no tiene llave primaria ni unique (el libro le pondrá una FK)';
    end if;
  end if;

  -- Si ya hay una tabla "cuentas", tiene que ser la de este archivo. Otra
  -- con el mismo nombre haría que "create table if not exists" se la
  -- saltara callado y todo lo de abajo fallara sin explicar por qué.
  if to_regclass('public.cuentas') is not null
     and not exists (select 1 from information_schema.columns
                      where table_schema = 'public' and table_name = 'cuentas'
                        and column_name = 'regla_cost_code') then
    v_falta := v_falta || ' · ya existe una tabla public.cuentas que NO es la de este archivo';
  end if;

  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c1-plan-de-cuentas NO se aplicó, no se tocó nada. Falta lo que este archivo da por hecho:' || v_falta,
      hint    = 'Ver docs/conta/ESQUEMA-REAL.md. Si el esquema cambió desde el 23-sep, hay que volver a leerlo antes de pegar.';
  end if;
end $$;


-- =====================================================================
-- 1 · LA TABLA cuentas
-- =====================================================================
-- Por qué cada columna:
--   codigo        cuatro dígitos, o cuatro dígitos y un sufijo para una
--                 subcuenta (2100-4417 = la tarjeta que acaba en 4417).
--                 Es la llave: NO cambia nunca (trigger de abajo).
--   tipo          la naturaleza de la cuenta. Va atada al primer dígito
--                 para que un error de dedo (una 1xxx «gasto») no entre.
--   saldo_normal  de qué lado crece. Casi siempre sale del tipo, pero las
--                 contra-cuentas van al revés (1190 y 1590 son activo con
--                 saldo acreedor; 3200 es capital con saldo deudor; 5011
--                 es costo con saldo acreedor). Por eso es explícita.
--   imputable     false = cuenta de grupo: no recibe asientos, solo agrupa
--                 a sus subcuentas (2100 agrupa una subcuenta por tarjeta).
--   activa        false = ya no recibe asientos nuevos, pero su historia
--                 queda. Es lo que se hace en vez de borrar.
--   regla_obra, regla_cost_code
--                 qué exige la cuenta a cada línea: 'obligatoria',
--                 'opcional' o 'prohibida'. El libro (c2) las hace cumplir
--                 con el error MX006. Son DATOS y no un «if 5xxx» escondido
--                 en una función porque el plan tiene excepciones de
--                 verdad: 5011 y 5019 son bolsas del burden sin obra, y
--                 5950 va por obra pero sin cost code. Los checks de abajo
--                 amarran lo que el plan no negocia: 6xxx, 7xxx y 9xxx
--                 nunca llevan obra; una 5xxx o exige obra o la prohíbe
--                 (nunca «a veces»: la Fase 9 cuadra el auxiliar por obra
--                 contra el mayor); y un cost code solo va donde la obra
--                 es obligatoria.
--   etiqueta_fiscal  pista para el CPA (f17): 'M&E 50%', '1099',
--                 'vehiculo'… Texto libre: el vocabulario lo fija el CPA.
create table if not exists public.cuentas (
  codigo           text        primary key,
  nombre           text        not null,
  nombre_en        text        not null,
  tipo             text        not null,
  padre            text        references public.cuentas (codigo),
  saldo_normal     text        not null,
  imputable        boolean     not null default true,
  activa           boolean     not null default true,
  regla_obra       text        not null,
  regla_cost_code  text        not null,
  etiqueta_fiscal  text,
  notas            text,
  creado           timestamptz not null default now(),

  constraint cuentas_codigo_formato
    check (codigo ~ '^[1-9][0-9]{3}(-[0-9A-Z]{1,12})?$'),
  constraint cuentas_nombres_llenos
    check (btrim(nombre) <> '' and btrim(nombre_en) <> ''),
  constraint cuentas_tipo_valido
    check (tipo in ('activo','pasivo','capital','ingreso','costo','gasto','otro_ingreso','otro_gasto')),
  -- El primer dígito manda sobre el tipo. No hay 8xxx en el plan: si un
  -- día hace falta, se abre aquí a propósito.
  constraint cuentas_tipo_por_rango
    check (   (left(codigo, 1) = '1' and tipo = 'activo')
           or (left(codigo, 1) = '2' and tipo = 'pasivo')
           or (left(codigo, 1) = '3' and tipo = 'capital')
           or (left(codigo, 1) = '4' and tipo in ('ingreso','otro_ingreso'))
           or (left(codigo, 1) = '5' and tipo = 'costo')
           or (left(codigo, 1) = '6' and tipo = 'gasto')
           or (left(codigo, 1) = '7' and tipo in ('otro_ingreso','otro_gasto'))
           or (left(codigo, 1) = '9' and tipo = 'gasto')),
  constraint cuentas_saldo_normal_valido
    check (saldo_normal in ('debe','haber')),
  constraint cuentas_reglas_validas
    check (    regla_obra      in ('obligatoria','opcional','prohibida')
           and regla_cost_code in ('obligatoria','opcional','prohibida')),
  -- Un cost code sin obra no significa nada.
  constraint cuentas_cost_code_solo_con_obra
    check (    (regla_cost_code <> 'obligatoria' or regla_obra = 'obligatoria')
           and (regla_obra <> 'prohibida' or regla_cost_code = 'prohibida')),
  -- El gasto general y lo de abajo nunca van por obra (plan, f02).
  constraint cuentas_sin_obra_fuera_del_costo
    check (left(codigo, 1) not in ('6','7','9') or regla_obra = 'prohibida'),
  -- Una 5xxx o es costo de obra o es una bolsa sin obra; nunca a medias.
  constraint cuentas_costo_con_obra_o_bolsa
    check (left(codigo, 1) <> '5' or regla_obra <> 'opcional'),
  -- Una subcuenta cuelga de su cuenta de cuatro dígitos.
  constraint cuentas_padre_coherente
    check (    (padre is null or padre <> codigo)
           and (position('-' in codigo) = 0 or padre = split_part(codigo, '-', 1)))
);

-- ---------------------------------------------------------------------
-- La guarda de cuentas. Un TRIGGER y no una policy: la policy no frena
-- al SQL Editor; el trigger sí.
--   · el código no cambia nunca;
--   · con movimientos, tipo y saldo normal tampoco (cambiarían el sentido
--     de lo ya asentado: se crea otra cuenta y se reclasifica con un
--     asiento);
--   · con movimientos no se borra: se inactiva;
--   · con el libro lleno no se trunca.
-- «Tiene movimientos» = aparece en asiento_lineas, que llega con c2.
-- Antes de c2 ninguna cuenta tiene movimientos y el borrador se corrige
-- libre. Además de esto, la FK de asiento_lineas.cuenta (c2) también
-- impide el borrado; el trigger está para decirlo en cristiano.
-- ---------------------------------------------------------------------
create or replace function public.fn_cuentas_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_con_mov boolean := false;
begin
  if tg_op = 'TRUNCATE' then
    if to_regclass('public.asiento_lineas') is not null then
      execute 'select exists (select 1 from public.asiento_lineas)' into v_con_mov;
    end if;
    if v_con_mov then
      raise exception using errcode = 'MX003',
        message = 'El plan de cuentas no se trunca: el libro ya tiene movimientos.';
    end if;
    return null;
  end if;

  if to_regclass('public.asiento_lineas') is not null then
    execute 'select exists (select 1 from public.asiento_lineas where cuenta = $1)'
      into v_con_mov using old.codigo;
  end if;

  if tg_op = 'DELETE' then
    if v_con_mov then
      raise exception using errcode = 'MX003',
        message = format('La cuenta %s tiene movimientos: no se borra, se inactiva (activa = false).', old.codigo);
    end if;
    return old;
  end if;

  -- UPDATE
  if new.codigo is distinct from old.codigo then
    raise exception using errcode = 'MX003',
      message = format('El código de una cuenta no cambia nunca (%s → %s). Crea la cuenta nueva e inactiva la vieja.',
                       old.codigo, new.codigo);
  end if;
  if v_con_mov and (new.tipo is distinct from old.tipo
                    or new.saldo_normal is distinct from old.saldo_normal) then
    raise exception using errcode = 'MX003',
      message = format('La cuenta %s tiene movimientos: su tipo y su saldo normal ya no cambian. '
                       'Crea otra cuenta y reclasifica con un asiento.', old.codigo);
  end if;
  return new;
end $$;

revoke execute on function public.fn_cuentas_guarda() from public, anon, authenticated, service_role;

-- «create or replace trigger» (PG14+) y no drop + create: al volver a
-- pegar el archivo no hay ni un instante sin la guarda.
create or replace trigger trg_cuentas_guarda
  before update or delete on public.cuentas
  for each row execute function public.fn_cuentas_guarda();

create or replace trigger trg_cuentas_sin_truncate
  before truncate on public.cuentas
  for each statement execute function public.fn_cuentas_guarda();

-- ---------------------------------------------------------------------
-- Quién lee. Bloque fijo de todo docs/conta/c*.sql: solo el dueño lee;
-- nadie de la API escribe (la tabla se mantiene desde este archivo, en el
-- SQL Editor). service_role conserva la lectura para que la función
-- «contador» (f07) pueda leer el plan al proponer; no escribe.
-- ---------------------------------------------------------------------
alter table public.cuentas enable row level security;
revoke all on public.cuentas from anon;
revoke insert, update, delete, truncate, references, trigger on public.cuentas from authenticated, service_role;
grant select on public.cuentas to authenticated, service_role;
drop policy if exists cuentas_dueno on public.cuentas;
create policy cuentas_dueno on public.cuentas for select to authenticated using (es_dueno());

-- Lo que un auditor lee en pg_description (de aquí sale MAPA-DATOS.md).
comment on table public.cuentas is
  'Plan de cuentas del libro (c1). El código no cambia nunca; con movimientos la cuenta no se borra, se inactiva. '
  'Cargado el 23-sep-2026 como BORRADOR, pendiente de que Edgar lo corrija. Cost codes: opción B (dimensión de la línea, no subcuentas).';
comment on column public.cuentas.codigo          is 'Cuatro dígitos, o cuatro y un sufijo para una subcuenta (2100-4417). Inmutable.';
comment on column public.cuentas.nombre          is 'Nombre en español.';
comment on column public.cuentas.nombre_en       is 'Nombre en inglés, para el CPA y el paquete fiscal.';
comment on column public.cuentas.tipo            is 'activo, pasivo, capital, ingreso, costo, gasto, otro_ingreso u otro_gasto. Atado al primer dígito del código.';
comment on column public.cuentas.padre           is 'Cuenta de la que cuelga una subcuenta. Nulo en las cuentas de cuatro dígitos.';
comment on column public.cuentas.saldo_normal    is 'debe o haber: el lado del que crece. Las contra-cuentas van al revés de su tipo.';
comment on column public.cuentas.imputable       is 'false = cuenta de grupo: no recibe asientos, solo agrupa subcuentas.';
comment on column public.cuentas.activa          is 'false = no recibe asientos nuevos; su historia queda. Se inactiva en vez de borrar.';
comment on column public.cuentas.regla_obra      is 'Qué exige a cada línea sobre proyecto_id: obligatoria, opcional o prohibida (MX006).';
comment on column public.cuentas.regla_cost_code is 'Qué exige a cada línea sobre cost_code (codigos_partida): obligatoria, opcional o prohibida (MX006).';
comment on column public.cuentas.etiqueta_fiscal is 'Pista para el CPA: M&E 50%, 1099, vehiculo… Vocabulario del CPA.';
comment on column public.cuentas.notas           is 'Para qué es la cuenta y qué NO va en ella.';


-- =====================================================================
-- 2 · EL PLAN DE CUENTAS — ▶ BORRADOR, pendiente de que Edgar lo corrija
-- =====================================================================
-- Es el borrador de f01 con lo que añadió la auditoría del 21-sep: 1130,
-- 2215, 2410, 5011, 5019, 5950, 6120, 6350, 6360, 6610, 6980 y la 9000
-- renombrada («de la EMPRESA»: el impuesto sobre la renta de Edgar no es
-- gasto, va a 3200).
--
-- Cómo se corrige: se edita ESTA lista y se vuelve a pegar el archivo.
--   · nombre, tipo, reglas, etiqueta y notas se actualizan solos (el
--     upsert de abajo solo toca las filas que cambiaron);
--   · «activa» NO la toca el upsert: una cuenta inactivada se queda así;
--   · una cuenta que SOBRA no desaparece por quitarla de la lista: se
--     borra aquí con un delete explícito mientras no tenga movimientos;
--     con movimientos, se inactiva (el trigger no deja otra cosa);
--   · con movimientos, cambiarle el tipo o el saldo normal hace fallar
--     el pegado entero (MX003). Es a propósito.
--
-- Las reglas de dimensión de este borrador:
--   · 4010–4040 exigen obra; 4900 la admite.
--   · Las 5xxx exigen obra y cost code, salvo las bolsas del burden (5011
--     y 5019: sin obra) y 5950 (por obra, sin cost code).
--   · 6xxx, 7xxx y 9000 nunca llevan obra.
--   · En el balance, solo lo que es de una obra por naturaleza la exige
--     (1120, 1200, 2020, 2400, 2410); 1110, 1190 y 1420 la admiten; el
--     resto la prohíbe. f03 y f10 pueden afinarlo.
-- 2100 es cuenta de GRUPO (no imputable): una subcuenta por tarjeta,
-- 2100-XXXX con los últimos 4. ▶ Faltan las tarjetas de Edgar.
insert into public.cuentas as c
  (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
values
  -- 1000 · Activo
  ('1010', 'Banco operativo',                           'Operating bank account',                              'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1020', 'Banco de nómina',                           'Payroll bank account',                                'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'Si se quiere separar del operativo.'),
  ('1030', 'Reserva de impuestos',                      'Tax reserve account',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1110', 'Cuentas por cobrar',                        'Accounts receivable',                                 'activo',  'debe',  true,  'opcional',    'prohibida',   null,           'Por factura (f03). La obra va cuando la factura la tiene.'),
  ('1120', 'Retención por cobrar',                      'Retainage receivable',                                'activo',  'debe',  true,  'obligatoria', 'prohibida',   null,           'Retainage, siempre por obra. En QuickBooks es un parche.'),
  ('1130', 'Cuenta por cobrar al accionista',           'Due from shareholder',                                'activo',  'debe',  true,  'prohibida',   'prohibida',   'accionista',   'Con nota firmada e interés.'),
  ('1190', 'Provisión de incobrables',                  'Allowance for doubtful accounts',                     'activo',  'haber', true,  'opcional',    'prohibida',   null,           'Contra-activo de 1110. El gasto va a 6980.'),
  ('1200', 'Costo y utilidad en exceso de facturación', 'Costs and estimated earnings in excess of billings',  'activo',  'debe',  true,  'obligatoria', 'prohibida',   null,           'WIP sub-facturado, por obra (f10).'),
  ('1300', 'Material en bodega',                        'Materials inventory',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'Lo comprado sin obra. Al salir a una obra pasa a 5100 con su obra.'),
  ('1410', 'Seguros pagados por adelantado',            'Prepaid insurance',                                   'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'La prima de WC se amortiza a 5010; GL, auto y sombrilla a 6200.'),
  ('1420', 'Fianzas',                                   'Prepaid surety bonds',                                'activo',  'debe',  true,  'opcional',    'prohibida',   null,           'Una fianza de cumplimiento es de un contrato: puede ir por obra.'),
  ('1510', 'Vehículos',                                 'Vehicles',                                            'activo',  'debe',  true,  'prohibida',   'prohibida',   'vehiculo',     'Por placa como etiqueta en activos_fijos (f08), no subcuentas.'),
  ('1520', 'Herramienta y equipo',                      'Tools and equipment',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1530', 'Cómputo',                                   'Computer equipment',                                  'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1540', 'Mejoras al local',                          'Leasehold improvements',                              'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1590', 'Depreciación acumulada',                    'Accumulated depreciation',                            'activo',  'haber', true,  'prohibida',   'prohibida',   null,           'Contra-activo. Igual a la suma de activos_fijos (f08).'),
  ('1600', 'Depósitos',                                 'Deposits',                                            'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),

  -- 2000 · Pasivo
  ('2010', 'Cuentas por pagar',                         'Accounts payable',                                    'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Una línea abierta por proveedor (f03); se concilia contra el statement del supply (f08).'),
  ('2020', 'Retención por pagar a subcontratistas',     'Retainage payable to subcontractors',                 'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'Por obra.'),
  ('2100', 'Tarjetas de crédito',                       'Credit cards',                                        'pasivo',  'haber', false, 'prohibida',   'prohibida',   null,           'Cuenta de GRUPO: no recibe asientos. Una subcuenta por tarjeta (2100-XXXX, los últimos 4).'),
  ('2210', 'Sueldos acumulados',                        'Accrued wages',                                       'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2215', 'Vacaciones devengadas',                     'Accrued paid time off',                               'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Solo si se devenga PTO.'),
  ('2220', 'Impuestos de nómina retenidos',             'Payroll taxes withheld (941)',                        'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Del journal del proveedor de nómina (f11).'),
  ('2230', 'Reempleo de Florida por pagar',             'Florida reemployment tax payable (RT-6)',             'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2240', 'Deducciones a empleados',                   'Employee deductions payable',                         'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2300', 'Use tax por pagar',                         'Use tax payable',                                     'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Compras sin impuesto de Florida y ventas al detalle. NUNCA desde un recibo que ya trae impuesto.'),
  ('2400', 'Facturación en exceso de costo',            'Billings in excess of costs and estimated earnings',  'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'WIP sobre-facturado, por obra (f10).'),
  ('2410', 'Provisión por pérdida en contratos',        'Provision for losses on contracts',                   'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'Contra 5950: la pérdida completa el mes que se detecta (f10).'),
  ('2510', 'Línea de crédito',                          'Line of credit',                                      'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2520', 'Préstamos de vehículo — corriente',         'Vehicle loans — current portion',                     'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2530', 'Préstamos de vehículo — largo plazo',       'Vehicle loans — long-term portion',                   'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2900', 'Préstamo del accionista',                   'Loan from shareholder',                               'pasivo',  'haber', true,  'prohibida',   'prohibida',   'accionista',   'Lo que Edgar paga de su bolsillo por la empresa (f03).'),

  -- 3000 · Capital
  ('3000', 'Capital social',                            'Common stock',                                        'capital', 'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('3100', 'Aportaciones',                              'Additional paid-in capital',                          'capital', 'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('3200', 'Distribuciones al accionista',              'Shareholder distributions',                           'capital', 'debe',  true,  'prohibida',   'prohibida',   'distribucion', 'S-corp. El impuesto sobre la renta de Edgar va aquí: no es gasto de la empresa.'),
  ('3900', 'Utilidades retenidas',                      'Retained earnings',                                   'capital', 'haber', true,  'prohibida',   'prohibida',   null,           'Apertura más resultados de ejercicios cerrados (f04).'),

  -- 4000 · Ingreso
  ('4010', 'Contrato — residencial',                    'Contract revenue — residential',                      'ingreso', 'haber', true,  'obligatoria', 'prohibida',   null,           null),
  ('4020', 'Contrato — comercial',                      'Contract revenue — commercial',                       'ingreso', 'haber', true,  'obligatoria', 'prohibida',   null,           null),
  ('4030', 'Servicio y T&M',                            'Service and T&M revenue',                             'ingreso', 'haber', true,  'obligatoria', 'prohibida',   null,           null),
  ('4040', 'Órdenes de cambio',                         'Change order revenue',                                'ingreso', 'haber', true,  'obligatoria', 'prohibida',   null,           'El CO va en la columna co de la línea.'),
  ('4900', 'Otros ingresos',                            'Other income',                                        'otro_ingreso', 'haber', true, 'opcional', 'prohibida',   null,           null),

  -- 5000 · Costo directo (aquí pega la decisión de cost codes: opción B)
  ('5000', 'Mano de obra directa',                      'Direct labor',                                        'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           'ÚNICA fuente de dólares: el journal del proveedor de nómina (f11). horas no postea dinero.'),
  ('5010', 'Burden de mano de obra',                    'Labor burden',                                        'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           'Impuestos patronales del journal + prima de WC amortizada desde 1410. El GL nunca va aquí: va a 6200.'),
  ('5011', 'Burden aplicado a obra',                    'Applied labor burden',                                'costo',   'haber', true,  'prohibida',   'prohibida',   null,           'Crédito del burden aplicado (Dr 5010-obra / Cr 5011, f09). Bolsa sin obra.'),
  ('5019', 'Variación de burden',                       'Labor burden variance',                               'costo',   'debe',  true,  'prohibida',   'prohibida',   null,           'Real contra aplicado; se cierra en f08. Bolsa sin obra.'),
  ('5100', 'Material',                                  'Materials',                                           'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           'El total del recibo con su impuesto incluido (f03).'),
  ('5200', 'Subcontratos',                              'Subcontracts',                                        'costo',   'debe',  true,  'obligatoria', 'obligatoria', '1099',         null),
  ('5300', 'Equipo y renta',                            'Equipment and rentals',                               'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           null),
  ('5400', 'Permisos e inspecciones',                   'Permits and inspections',                             'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           null),
  ('5500', 'Consumibles',                               'Consumables',                                         'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           null),
  ('5600', 'Flete',                                     'Freight',                                             'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           null),
  ('5900', 'Garantía y retrabajo',                      'Warranty and rework',                                 'costo',   'debe',  true,  'obligatoria', 'obligatoria', null,           null),
  ('5950', 'Pérdida en contrato',                       'Provision for contract losses',                       'costo',   'debe',  true,  'obligatoria', 'prohibida',   null,           'Contra 2410, la pérdida completa el mes que se detecta (f10). Por obra, sin cost code.'),

  -- 6000 · Gasto general (nunca por obra)
  ('6000', 'Sueldo administrativo',                     'Administrative salaries',                             'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'El sueldo de Edgar entra solo por nómina, aquí; nunca como transferencia (f07).'),
  ('6010', 'Burden administrativo',                     'Administrative payroll burden',                       'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6100', 'Renta',                                     'Rent',                                                'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6110', 'Servicios',                                 'Utilities',                                           'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6120', 'Teléfono y datos',                          'Telephone and internet',                              'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6200', 'Seguros — GL, auto, sombrilla',             'Insurance — general liability, auto, umbrella',       'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'El GL nunca va también en el burden (5010).'),
  ('6300', 'Vehículos — combustible y mantenimiento',   'Vehicles — fuel and maintenance',                     'gasto',   'debe',  true,  'prohibida',   'prohibida',   'vehiculo',     null),
  ('6350', 'Comidas (50 %)',                            'Meals (50% deductible)',                              'gasto',   'debe',  true,  'prohibida',   'prohibida',   'M&E 50%',      null),
  ('6360', 'Viajes y alojamiento',                      'Travel and lodging',                                  'gasto',   'debe',  true,  'prohibida',   'prohibida',   'viajes',       null),
  ('6400', 'Herramienta menor y uniformes',             'Small tools and uniforms',                            'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6500', 'Oficina y software',                        'Office and software',                                 'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6600', 'Profesionales — CPA y legal',               'Professional fees — accounting and legal',            'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6610', 'Qualifier y licencia',                      'License qualifier',                                   'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           '▶ Edgar confirma con el CPA si el qualifier cobra por W-2 o por 1099 (si es 1099, etiqueta 1099).'),
  ('6700', 'Publicidad',                                'Advertising',                                         'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6800', 'Licencias y cuotas',                        'Licenses and dues',                                   'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6900', 'Formación',                                 'Training',                                            'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6950', 'Depreciación',                              'Depreciation',                                        'gasto',   'debe',  true,  'prohibida',   'prohibida',   'depreciacion', 'Desde activos_fijos (f08).'),
  ('6980', 'Incobrables',                               'Bad debt expense',                                    'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'Contra 1190.'),

  -- 7000 · Otros
  ('7100', 'Intereses',                                 'Interest expense',                                    'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   null,           null),
  ('7200', 'Cargos bancarios y comisiones de tarjeta',  'Bank charges and card processing fees',               'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   null,           null),
  ('7900', 'Otros gastos',                              'Other expenses',                                      'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   null,           null),
  -- 9000: gasto de operación (en el P&L va con los gastos; el número solo
  -- la aparta para que se vea).
  ('9000', 'Impuestos y tasas de la EMPRESA',           'Business taxes and licenses',                         'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'Propiedad tangible (DR-405), annual report de Sunbiz. El impuesto sobre la renta de Edgar NO es gasto: va a 3200.')
on conflict (codigo) do update set
  nombre          = excluded.nombre,
  nombre_en       = excluded.nombre_en,
  tipo            = excluded.tipo,
  saldo_normal    = excluded.saldo_normal,
  imputable       = excluded.imputable,
  regla_obra      = excluded.regla_obra,
  regla_cost_code = excluded.regla_cost_code,
  etiqueta_fiscal = excluded.etiqueta_fiscal,
  notas           = excluded.notas
where (c.nombre, c.nombre_en, c.tipo, c.saldo_normal, c.imputable,
       c.regla_obra, c.regla_cost_code, c.etiqueta_fiscal, c.notas)
      is distinct from
      (excluded.nombre, excluded.nombre_en, excluded.tipo, excluded.saldo_normal, excluded.imputable,
       excluded.regla_obra, excluded.regla_cost_code, excluded.etiqueta_fiscal, excluded.notas);


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: el plan, para reconocerlo.
-- Esperado: 75 cuentas (74 imputables; 2100 es de grupo).
-- =====================================================================
select codigo, nombre, tipo, saldo_normal as saldo, imputable, activa,
       regla_obra as obra, regla_cost_code as cost_code, etiqueta_fiscal
  from public.cuentas
 order by codigo;
