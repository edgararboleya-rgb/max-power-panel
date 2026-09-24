-- =====================================================================
-- C1 · El plan de cuentas — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, de una vez, ANTES que
-- c2-libro.sql (el libro cuelga de esta tabla). Idempotente: se puede
-- pegar dos veces seguidas sin error y sin duplicar nada. Volver a
-- pegarlo con el libro ya puesto (para corregir el plan) no toca el
-- libro. Si una versión NUEVA de este archivo cambia sus guardas (los
-- triggers de cuentas), después se vuelve a pegar c2-libro.sql: guarda
-- las huellas de las guardas, y su verificador lo pide en rojo.
--
-- Qué hace, en orden:
--   0. PRECONDICIONES. Comprueba lo que este archivo da por hecho y, si
--      falta algo, se para con un mensaje en español ANTES de tocar nada.
--      Sustituye al «bloque 0» de f01: el esquema ya se leyó el 23-sep
--      (docs/conta/ESQUEMA-REAL.md).
--   1. La tabla cuentas. El código no cambia nunca. Una cuenta con
--      movimientos no se borra: se inactiva; y con saldo vivo tampoco se
--      inactiva, ni se le endurece una regla de dimensión que dejaría ese
--      saldo atrapado (primero se traslada el saldo). Cada cuenta dice qué
--      dimensiones exige a sus líneas (obra y cost code). Todo cambio a
--      una cuenta queda escrito en cuentas_historial (quién, cuándo, antes
--      y después): un nombre o una etiqueta fiscal no cambian sin rastro.
--      El verificador de c2 compara cada cuenta con su último cambio
--      apuntado: un cambio que no pasó por el historial se ve.
--   2. El plan de cuentas BORRADOR: el de f01, lo que añadió la auditoría
--      del 21-sep y lo que añadió la del 23-sep (lo que pide el 1120-S, la
--      bolsa del burden real y los reembolsos a empleados). ▶ Pendiente
--      de que Edgar lo corrija.
--
-- LA DECISIÓN DE LOS COST CODES — aquí se asume la OPCIÓN B:
--   El cost code NO forma parte de la cuenta. Es una columna de cada
--   línea del libro (asiento_lineas.cost_code, en c2) con llave foránea a
--   la tabla que YA existe, codigos_partida(codigo). El plan se queda en
--   85 cuentas y el costo se corta por obra, por código, por los dos o
--   por ninguno. No se crea ninguna tabla cost_codes, y aquí NO se
--   inserta nada en codigos_partida: en producción ya tiene sus filas y
--   la maneja Edgar desde la app.
--   En el costo la obra es OBLIGATORIA y el cost code OPCIONAL. Así lo
--   pide f01 (punto 4: en el origen el código es opcional, nulo cuando
--   el ticket mezcla partidas) y así lo da por hecho f09 (compara por
--   código solo «lo capturado con código»). Hoy ninguna tabla origen
--   trae cost code (recibos, trabajos_externos y horas no lo tienen), y
--   el journal de nómina es por empleado: si el libro lo exigiera, el
--   puente de f03 tendría que inventarse uno (20-MISC) y ensuciaría para
--   siempre la comparación por código en un libro que no se edita. OJO:
--   f02 dice «exige proyecto_id y cost_code en 5xxx»; esa frase quedó
--   vieja y se corrige en f02, no aquí. Tampoco existe un código 'mixto'
--   en codigos_partida (es la tabla de Edgar en la app): un ticket mixto
--   entra sin código, o partido en una línea por código.
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
--   padre         la cuenta de cuatro dígitos de la que cuelga una
--                 subcuenta. La pone la base sola a partir del código
--                 (2100-4417 → 2100): quien añade una tarjeta a la lista
--                 no tiene que acordarse, y una subcuenta sin padre no
--                 entra (el check de abajo lo exige, no solo lo permite).
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
--                 verdad: 5011, 5015 y 5019 son bolsas del burden sin obra,
--                 y 5950 va por obra pero sin cost code. Los checks de abajo
--                 amarran lo que el plan no negocia: 6xxx, 7xxx y 9xxx
--                 nunca llevan obra; una 5xxx o exige obra o la prohíbe
--                 (nunca «a veces»: la Fase 9 cuadra el auxiliar por obra
--                 contra el mayor, y las bolsas sin obra quedan fuera de
--                 ese cuadre); un cost code obligatorio solo donde la obra
--                 también lo es, y ninguno donde la obra está prohibida.
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
  -- Una subcuenta cuelga de su cuenta de cuatro dígitos, y solo una
  -- subcuenta tiene padre. Escrito para que un padre que FALTA no pase:
  -- con «padre = split_part(...)» a secas, un padre nulo daba NULL y un
  -- check que da NULL deja pasar la fila.
  constraint cuentas_padre_coherente
    check (    (position('-' in codigo) > 0) = (padre is not null)
           and (padre is null or padre = split_part(codigo, '-', 1)))
);

-- ---------------------------------------------------------------------
-- El historial de cuentas: cada alta, cambio o baja de una cuenta, con
-- quién, cuándo, cómo estaba antes y cómo quedó. Renombrar una cuenta o
-- cambiarle la etiqueta fiscal es legítimo (QuickBooks también lo deja),
-- pero cambia cómo se LEE lo ya asentado: el hash de un asiento sella el
-- código de la cuenta, no su nombre ni su etiqueta. Por eso no se congela:
-- se deja escrito. El id es un uuid y no una secuencia: una secuencia no
-- se deshace con el rollback y las pruebas (c2-pruebas) dejarían rastro.
-- ---------------------------------------------------------------------
create table if not exists public.cuentas_historial (
  id           uuid        primary key default gen_random_uuid(),
  codigo       text        not null,
  operacion    text        not null,
  cambiado_el  timestamptz not null default clock_timestamp(),
  usuario_id   uuid,
  rol          text        not null,
  antes        jsonb,
  despues      jsonb,
  constraint cuentas_historial_operacion check (operacion in ('INSERT', 'UPDATE', 'DELETE')),
  constraint cuentas_historial_forma
    check (    (operacion = 'INSERT' and antes is null and despues is not null)
           or (operacion = 'UPDATE' and antes is not null and despues is not null)
           or (operacion = 'DELETE' and antes is not null and despues is null))
);
create index if not exists cuentas_historial_codigo_idx on public.cuentas_historial (codigo, cambiado_el);

-- ---------------------------------------------------------------------
-- La guarda de cuentas. Un TRIGGER y no una policy: la policy no frena
-- al SQL Editor; el trigger sí.
--   · una subcuenta recibe su padre del código (al entrar y al cambiar);
--   · el código no cambia nunca;
--   · con movimientos, tipo y saldo normal tampoco (cambiarían el sentido
--     de lo ya asentado: se crea otra cuenta y se reclasifica con un
--     asiento);
--   · con SALDO VIVO no se inactiva ni se vuelve de grupo: una cuenta que
--     ya no recibe asientos no recibe tampoco el que traslada su saldo, y
--     el saldo se quedaría atrapado (y un reverso de corrección tampoco
--     tendría a dónde ir). Primero se traslada el saldo, después se
--     inactiva. Saldo vivo: en una cuenta de balance (activo, pasivo,
--     capital), la suma de todo su historial; en una de resultados, la de
--     los años que todavía no se cierran (un ajuste del CPA puede tener
--     que llegar a ella hasta entonces). Y se mide POR OBRA Y POR CÓDIGO,
--     como el auxiliar, no solo el total: un total en cero puede esconder
--     una obra que debe 1,000 y otra en −1,000 (el cobro de una retención
--     aplicado a la obra equivocada). Inactivada, ya no entraría la
--     reclasificación entre obras, y la cédula de retención por obra (o
--     el costo por obra) quedaría mal para siempre;
--   · por lo mismo, con saldo vivo no cambia una REGLA DE DIMENSIÓN
--     (regla_obra, regla_cost_code) si ese saldo queda en una combinación
--     que la regla nueva ya no admite: a obligatoria con saldo vivo sin
--     obra (o sin código), a prohibida con saldo vivo con obra (o con
--     código). Ninguna línea podría ya llevarse ese saldo, y el auxiliar
--     por obra no cuadraría nunca contra el mayor (la CxC de apertura
--     entra sin obra; si después 1110 pasa a exigir obra, el cobro entra
--     con obra y el auxiliar queda con «sin obra +20000 / la obra −20000»
--     y el mayor en cero). Primero se traslada ese saldo con un asiento
--     bajo la regla de hoy; después se cambia la regla. Aflojar una regla
--     (a opcional) siempre se puede;
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
  v_con_mov  boolean := false;
  v_atrapado text;
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

  if tg_op = 'INSERT' then
    if position('-' in new.codigo) > 0 and new.padre is null then
      new.padre := split_part(new.codigo, '-', 1);
    end if;
    return new;
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
      message = format('El código de una cuenta no cambia nunca (%s → %s). Crea la cuenta nueva, traslada el saldo '
                       'con un asiento e inactiva la vieja.', old.codigo, new.codigo);
  end if;
  if position('-' in new.codigo) > 0 and new.padre is null then
    new.padre := split_part(new.codigo, '-', 1);
  end if;
  if v_con_mov and (new.tipo is distinct from old.tipo
                    or new.saldo_normal is distinct from old.saldo_normal) then
    raise exception using errcode = 'MX003',
      message = format('La cuenta %s tiene movimientos: su tipo y su saldo normal ya no cambian. '
                       'Crea otra cuenta y reclasifica con un asiento.', old.codigo);
  end if;
  -- Inactivar o volver de grupo: ninguna combinación de obra y código con
  -- saldo vivo (ver arriba). La lista dice cuáles, para trasladarlas.
  if v_con_mov
     and ((old.activa and not new.activa) or (old.imputable and not new.imputable))
     and to_regclass('public.asientos') is not null and to_regclass('public.periodos') is not null then
    execute $q$
      select string_agg(format('%s%s: %s', coalesce(x.obra, '(sin obra)'),
                               case when x.cc is not null then ' / ' || x.cc else '' end,
                               x.saldo), '; ' order by x.obra nulls first, x.cc nulls first)
        from (select l.proyecto_id as obra, l.cost_code as cc, sum(l.monto) as saldo
                from public.asiento_lineas l
                join public.asientos a on a.id = l.asiento_id
               where l.cuenta = $1
                 and (   $2 in ('activo', 'pasivo', 'capital')
                      or not exists (select 1 from public.periodos p
                                      where p.tipo = 'anio' and p.anio = a.anio and p.estado = 'cerrado'))
               group by l.proyecto_id, l.cost_code
              having sum(l.monto) <> 0) x
    $q$ into v_atrapado using old.codigo, old.tipo;
    if v_atrapado is not null then
      raise exception using errcode = 'MX003',
        message = format('La cuenta %s (%s) tiene saldo vivo (%s): antes de %s se traslada ese saldo con un asiento, '
                         'entre obras y códigos o a la cuenta que la sustituye. Si no, se queda atrapado: ya no entraría '
                         'ni el asiento que lo mueve. Cuenta por obra y por código, no solo el total: un total en cero '
                         'puede esconder una obra que debe y otra en negativo.', old.codigo, old.nombre, v_atrapado,
                         case when old.activa and not new.activa then 'inactivarla' else 'volverla cuenta de grupo' end);
    end if;
  end if;
  -- Una regla de dimensión que se endurece con saldo vivo (ver arriba). El
  -- saldo vivo se mide igual que para inactivar, por obra y por código.
  if v_con_mov
     and (new.regla_obra is distinct from old.regla_obra or new.regla_cost_code is distinct from old.regla_cost_code)
     and to_regclass('public.asientos') is not null and to_regclass('public.periodos') is not null then
    execute $q$
      select string_agg(format('%s%s: %s', coalesce(x.obra, '(sin obra)'),
                               case when x.obra is null then ''
                                    when x.cc is not null then ' / ' || x.cc
                                    when $5 then ' / (sin código)'
                                    else '' end,
                               x.saldo), '; ' order by x.obra nulls first, x.cc nulls first)
        from (select l.proyecto_id as obra, l.cost_code as cc, sum(l.monto) as saldo
                from public.asiento_lineas l
                join public.asientos a on a.id = l.asiento_id
               where l.cuenta = $1
                 and (   $2 in ('activo', 'pasivo', 'capital')
                      or not exists (select 1 from public.periodos p
                                      where p.tipo = 'anio' and p.anio = a.anio and p.estado = 'cerrado'))
               group by l.proyecto_id, l.cost_code
              having sum(l.monto) <> 0) x
       where ($3 and x.obra is null)         -- la obra pasa a obligatoria: saldo vivo sin obra
          or ($4 and x.obra is not null)     -- la obra pasa a prohibida: saldo vivo con obra
          or ($5 and x.cc is null)           -- el código pasa a obligatorio: saldo vivo sin código
          or ($6 and x.cc is not null)       -- el código pasa a prohibido: saldo vivo con código
    $q$ into v_atrapado
    using old.codigo, old.tipo,
          new.regla_obra = 'obligatoria' and old.regla_obra <> 'obligatoria',
          new.regla_obra = 'prohibida' and old.regla_obra <> 'prohibida',
          new.regla_cost_code = 'obligatoria' and old.regla_cost_code <> 'obligatoria',
          new.regla_cost_code = 'prohibida' and old.regla_cost_code <> 'prohibida';
    if v_atrapado is not null then
      raise exception using errcode = 'MX003',
        message = format('La cuenta %s (%s) tiene saldo vivo que la regla nueva ya no admitiría (%s): se quedaría atrapado, '
                         'porque ya ninguna línea podría llevárselo, y el auxiliar por obra no cuadraría nunca contra el '
                         'mayor. Primero traslada ese saldo con un asiento bajo la regla de hoy; después cambia la regla.',
                         old.codigo, old.nombre, v_atrapado);
    end if;
  end if;
  return new;
end $$;

revoke execute on function public.fn_cuentas_guarda() from public, anon, authenticated, service_role;

-- «create or replace trigger» (PG14+) y no drop + create: al volver a
-- pegar el archivo no hay ni un instante sin la guarda.
create or replace trigger trg_cuentas_guarda
  before insert or update or delete on public.cuentas
  for each row execute function public.fn_cuentas_guarda();

create or replace trigger trg_cuentas_sin_truncate
  before truncate on public.cuentas
  for each statement execute function public.fn_cuentas_guarda();

-- ---------------------------------------------------------------------
-- El historial se llena DESPUÉS de que la fila quedó escrita (after): si
-- el cambio no entra, tampoco queda en el historial. Un update que no
-- cambia nada no se apunta. Corre con los permisos de quien cambia la
-- cuenta, que solo puede ser el dueño de la base (la API no escribe en
-- cuentas): no hace falta SECURITY DEFINER.
-- ---------------------------------------------------------------------
create or replace function public.fn_cuentas_historial()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and to_jsonb(new) = to_jsonb(old) then
    return null;
  end if;
  insert into public.cuentas_historial (codigo, operacion, usuario_id, rol, antes, despues)
  values (case when tg_op = 'DELETE' then old.codigo else new.codigo end,
          tg_op,
          auth.uid(),
          coalesce(nullif(current_setting('role', true), 'none'), session_user::text),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return null;
end $$;

revoke execute on function public.fn_cuentas_historial() from public, anon, authenticated, service_role;

create or replace trigger trg_cuentas_historial
  after insert or update or delete on public.cuentas
  for each row execute function public.fn_cuentas_historial();

-- El historial no se edita ni se borra: es el rastro.
create or replace function public.fn_cuentas_historial_inmutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception using errcode = 'MX003',
    message = format('El historial de cuentas no se edita ni se borra (%s): es el rastro de cada cambio al plan.', tg_op);
end $$;

revoke execute on function public.fn_cuentas_historial_inmutable() from public, anon, authenticated, service_role;

create or replace trigger trg_cuentas_historial_inmutable
  before update or delete on public.cuentas_historial
  for each row execute function public.fn_cuentas_historial_inmutable();

create or replace trigger trg_cuentas_historial_sin_truncate
  before truncate on public.cuentas_historial
  for each statement execute function public.fn_cuentas_historial_inmutable();

-- ---------------------------------------------------------------------
-- El relleno del historial, una sola vez. Si el historial está VACÍO y ya
-- hay cuentas, este archivo se está pegando encima de un c1 anterior que
-- no lo tenía (el borrador del 23-sep). Cada cuenta que ya estaba entra
-- con una fila de alta, tal como está en este momento, y el rol lo dice
-- («… · relleno de c1»): así queda escrito de dónde sale esa fila. Sin
-- esto, el verificador de c2 (control cuentas) daba en rojo, para
-- siempre, todas las cuentas que el upsert de abajo no toca, con un
-- texto que se lee como una cuenta cambiada por debajo; y volver a pegar
-- no lo arreglaba (un update que no cambia nada no se apunta).
-- Solo con el historial vacío: con historial, una cuenta sin rastro es
-- justo lo que el verificador tiene que cantar, y un pegado no la
-- blanquea. Va antes del arreglo del padre y del upsert, para que lo que
-- ellos cambien quede apuntado encima, como un cambio más.
-- ---------------------------------------------------------------------
insert into public.cuentas_historial (codigo, operacion, usuario_id, rol, antes, despues)
select c.codigo, 'INSERT', auth.uid(),
       coalesce(nullif(current_setting('role', true), 'none'), session_user::text)
         || ' · relleno de c1: la cuenta ya existía cuando se creó el historial',
       null, to_jsonb(c)
  from public.cuentas c
 where not exists (select 1 from public.cuentas_historial)
 order by c.codigo;

-- ---------------------------------------------------------------------
-- Si la tabla ya existía de un pegado anterior con el check viejo del
-- padre, se cambia por el de la tabla. Antes se ponen los padres que
-- falten (una subcuenta añadida con el upsert viejo quedó sin padre),
-- para que el check nuevo no choque con filas que ya están. Va aquí, con
-- la guarda y el historial ya puestos, para que el arreglo quede escrito.
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_constraint
              where conrelid = 'public.cuentas'::regclass and conname = 'cuentas_padre_coherente'
                and pg_get_constraintdef(oid) not like '%padre IS NOT NULL%') then
    alter table public.cuentas drop constraint cuentas_padre_coherente;
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.cuentas'::regclass and conname = 'cuentas_padre_coherente') then
    update public.cuentas set padre = split_part(codigo, '-', 1)
     where position('-' in codigo) > 0 and padre is distinct from split_part(codigo, '-', 1);
    alter table public.cuentas add constraint cuentas_padre_coherente
      check (    (position('-' in codigo) > 0) = (padre is not null)
             and (padre is null or padre = split_part(codigo, '-', 1)));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Quién lee. Bloque fijo de todo docs/conta/c*.sql: solo el dueño lee;
-- nadie de la API escribe (las tablas se mantienen desde este archivo, en
-- el SQL Editor). service_role conserva la lectura para que la función
-- «contador» (f07) pueda leer el plan al proponer; no escribe.
--   · «revoke all» y luego «grant select», y no una lista de privilegios:
--     en Postgres 17 (producción) el «grant all» de Supabase incluye
--     MAINTAIN, que una lista escrita para 16 no nombra y con el que un
--     trabajador podría tomar un LOCK sobre la tabla. «all» vale igual en
--     16 y en 17, y también quita lo concedido por columna.
--   · Al volver a pegar se borra toda policy de estas tablas que no sea la
--     de aquí (p. ej. una «Enable read access for all users» creada desde
--     el dashboard): solo el dueño lee, y lo dice una sola policy.
--   · Riesgo conocido y aceptado: authenticated necesita el SELECT de
--     tabla (la policy es la que filtra), y con él PostgREST puede dar la
--     ESTIMACIÓN del planificador («Prefer: count=planned»), que sale de
--     las estadísticas reales. Así se asoma cuántas filas hay por valor
--     (cuentas por código), nunca un monto ni un nombre. Quitarlo pide un
--     rol propio para el dueño en el token o leer solo por funciones; se
--     decide si algún día hace falta el rol «contador».
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['cuentas', 'cuentas_historial'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl
              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname <> t || '_dueno' loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    execute format('create policy %I on public.%I for select to authenticated using (es_dueno())', t || '_dueno', t);
  end loop;
end $$;

-- Lo que un auditor lee en pg_description (de aquí sale MAPA-DATOS.md).
comment on table public.cuentas is
  'Plan de cuentas del libro (c1). El código no cambia nunca; con movimientos la cuenta no se borra, se inactiva, y con saldo vivo '
  'tampoco se inactiva ni se le endurece una regla de dimensión que lo dejaría atrapado. Cada cambio queda en cuentas_historial. Cargado el 23-sep-2026 como BORRADOR, pendiente de que Edgar lo '
  'corrija. Cost codes: opción B (dimensión de la línea, no subcuentas).';
comment on column public.cuentas.codigo          is 'Cuatro dígitos, o cuatro y un sufijo para una subcuenta (2100-4417). Inmutable.';
comment on column public.cuentas.nombre          is 'Nombre en español.';
comment on column public.cuentas.nombre_en       is 'Nombre en inglés, para el CPA y el paquete fiscal.';
comment on column public.cuentas.tipo            is 'activo, pasivo, capital, ingreso, costo, gasto, otro_ingreso u otro_gasto. Atado al primer dígito del código.';
comment on column public.cuentas.padre           is 'Cuenta de la que cuelga una subcuenta (la pone la base a partir del código). Nulo en las cuentas de cuatro dígitos.';
comment on column public.cuentas.saldo_normal    is 'debe o haber: el lado del que crece. Las contra-cuentas van al revés de su tipo.';
comment on column public.cuentas.imputable       is 'false = cuenta de grupo: no recibe asientos, solo agrupa subcuentas. Con saldo vivo (en cualquier obra o código) no pasa a false.';
comment on column public.cuentas.activa          is 'false = no recibe asientos nuevos; su historia queda. Se inactiva en vez de borrar, y solo sin saldo vivo en ninguna obra ni código.';
comment on column public.cuentas.regla_obra      is 'Qué exige a cada línea sobre proyecto_id: obligatoria, opcional o prohibida (MX006). Con saldo vivo, no se endurece si lo dejaría atrapado.';
comment on column public.cuentas.regla_cost_code is 'Qué exige a cada línea sobre cost_code (codigos_partida): obligatoria, opcional o prohibida (MX006). Con saldo vivo, no se endurece si lo dejaría atrapado.';
comment on column public.cuentas.etiqueta_fiscal is 'Pista para el CPA: M&E 50%, 1099, vehiculo… Vocabulario del CPA.';
comment on column public.cuentas.notas           is 'Para qué es la cuenta y qué NO va en ella.';

comment on table public.cuentas_historial is
  'Cada alta, cambio o baja de una cuenta (c1): quién, cuándo, antes y después. Lo llena un trigger; no se edita ni se borra. '
  'Un nombre o una etiqueta fiscal cambian cómo se lee lo ya asentado: aquí queda cuándo y de qué a qué.';
comment on column public.cuentas_historial.operacion is 'INSERT, UPDATE o DELETE.';
comment on column public.cuentas_historial.usuario_id is 'auth.uid() de quien hizo el cambio; nulo desde el SQL Editor.';
comment on column public.cuentas_historial.rol        is 'Rol con que se hizo el cambio (el dueño de la base desde el SQL Editor). Un alta que dice «relleno de c1» es una cuenta que ya estaba cuando se creó el historial.';
comment on column public.cuentas_historial.antes      is 'La fila como estaba (nula en un alta).';
comment on column public.cuentas_historial.despues    is 'La fila como quedó (nula en una baja).';


-- =====================================================================
-- 2 · EL PLAN DE CUENTAS — ▶ BORRADOR, pendiente de que Edgar lo corrija
-- =====================================================================
-- Es el borrador de f01 con lo que añadió la auditoría del 21-sep: 1130,
-- 2215, 2410, 5011, 5019, 5950, 6120, 6350, 6360, 6610, 6980 y la 9000
-- renombrada («de la EMPRESA»: el impuesto sobre la renta de Edgar no es
-- gasto, va a 3200). Y lo que añadió la del 23-sep:
--   · lo que el CPA necesita APARTE para el 1120-S de una S-corp: 6005 la
--     compensación del accionista-oficial (línea 7 y Form 1125-E) y 5001
--     su parte de obra; 6006 su seguro médico (>2 %, va a su W-2); 4910
--     los intereses cobrados (K-1); 4920 la ganancia o pérdida por venta
--     de activos (Form 4797); 7910 las donaciones (K-1) y 7920 las multas
--     (no deducibles, M-1). Sin cuenta no hay etiqueta, y sin etiqueta el
--     paquete de f17 tendría que leer memos;
--   · 2250, los reembolsos a empleados por pagar (f03 la usa: «lo de un
--     empleado, a reembolsos por pagar»);
--   · 5015, la bolsa del burden REAL, sin obra (ver 5010);
--   · 7200 pasa a 6130: la comisión de tarjeta y los cargos del banco son
--     gasto de operación. Debajo de la utilidad de operación la bajaban,
--     y esa utilidad es la que miran el banco y la afianzadora.
-- Y lo que añadió la del 24-sep, dos pasivos que no tenían dónde ir:
--   · 2050, los costos y gastos devengados por pagar: el devengo de cierre
--     sin factura (el avance de un sub sin facturar, el material recibido
--     sin factura), que el WIP de f10 necesita como costo a la fecha. En
--     2010 no cabe: 2010 va por proveedor y se concilia contra el
--     statement de cada supply (f08), y un devengo no está en ningún
--     statement;
--   · 2225, el FUTA por pagar (940): el journal de Gusto lo da aparte, y
--     la balanza de QuickBooks trae su pasivo. En 2220 o en 2230 rompía el
--     amarre de f11 (2220 contra el 941, 2230 contra el RT-6).
-- ▶ Edgar confirma con el CPA las cuentas del 1120-S (y si la parte de
-- obra de su sueldo va en 5001 o prefiere otra forma de apartarla).
--
-- Cómo se corrige: se edita ESTA lista y se vuelve a pegar el archivo.
--   · nombre, tipo, reglas, etiqueta y notas se actualizan solos (el
--     upsert de abajo solo toca las filas que cambiaron), y cada cambio
--     queda en cuentas_historial;
--   · el padre de una subcuenta lo pone la base a partir del código: una
--     tarjeta se añade como una fila más ('2100-4417', …) y cuelga sola
--     de 2100;
--   · «activa» NO la toca el upsert: una cuenta inactivada se queda así;
--   · una cuenta que SOBRA no desaparece por quitarla de la lista: se
--     borra aquí con un delete explícito mientras no tenga movimientos
--     (como 7200, justo antes de la lista); con movimientos, se inactiva
--     (el trigger no deja otra cosa), y con saldo vivo, antes se traslada
--     el saldo;
--   · con movimientos, cambiarle el tipo o el saldo normal hace fallar
--     el pegado entero (MX003), y también endurecerle una regla de
--     dimensión que dejaría atrapado su saldo vivo. Es a propósito.
--
-- Las reglas de dimensión de este borrador:
--   · 4010–4040 exigen obra; 4900 la admite; 4910 y 4920 no la llevan.
--   · Las 5xxx exigen obra y ADMITEN cost code (opcional: ver arriba, la
--     decisión de los cost codes), salvo las bolsas del burden (5011, 5015
--     y 5019: sin obra) y 5950 (por obra, sin cost code).
--   · 6xxx, 7xxx y 9000 nunca llevan obra.
--   · En el balance, solo lo que es de una obra por naturaleza la exige
--     (1120, 1200, 2020, 2400, 2410); 1110, 1190, 1420 y 2050 la admiten;
--     el resto la prohíbe. f03 y f10 pueden afinarlo; con el libro ya en
--     marcha, la guarda no deja endurecer una regla que atraparía saldo
--     vivo (antes se traslada ese saldo con un asiento).
--
-- EL BURDEN, sin que ningún dólar llegue dos veces a la obra:
--   · 5015 (bolsa, sin obra) recibe el burden REAL: los impuestos
--     patronales del journal de nómina (f11), la prima de WC amortizada
--     desde 1410 y su ajuste de auditoría. Son asientos de tiempo, no de
--     una obra: por eso no pueden ir directo a 5010, que exige obra.
--   · 5010 (por obra) solo recibe lo que se REPARTE a las obras: o el real
--     (Dr 5010-obra / Cr 5015, el reparto por horas de f09), o el
--     aplicado a tasa estándar (Dr 5010-obra / Cr 5011), nunca los dos.
--   · Con tasa aplicada, el cierre de f08 lleva 5015 − 5011 a 5019 (la
--     variación). Sin tasa aplicada, 5011 y 5019 no se usan.
--   · El cuadre «auxiliar 5xxx por obra = mayor» deja fuera las bolsas
--     sin obra (5011, 5015, 5019).
--
-- Las cuentas que SOBRAN del borrador anterior: 7200 («Cargos bancarios
-- y comisiones de tarjeta») pasó a 6130. Se borra si no tiene movimientos
-- (lo normal: el libro aún no arrancó). Si ya los tuviera, se deja como
-- está: la guarda no deja borrarla, y inactivarla con saldo tampoco; eso
-- lo decide Edgar a mano, trasladando antes el saldo.
-- Va ANTES de la lista, y solo borra la fila retirada (por su nombre): si
-- Edgar vuelve a poner una 7200 en la lista, con otro nombre, la lista la
-- da de alta y ningún pegado posterior la borra. Puesto después de la
-- lista, la daba de alta y la borraba en el mismo pegado, sin avisar.
do $$
declare
  v_con_mov boolean := false;
begin
  if exists (select 1 from public.cuentas
              where codigo = '7200' and nombre = 'Cargos bancarios y comisiones de tarjeta') then
    if to_regclass('public.asiento_lineas') is not null then
      execute 'select exists (select 1 from public.asiento_lineas where cuenta = ''7200'')' into v_con_mov;
    end if;
    if not v_con_mov then
      delete from public.cuentas where codigo = '7200';
    end if;
  end if;
end $$;

-- 2100 es cuenta de GRUPO (no imputable): una subcuenta por tarjeta,
-- 2100-XXXX con los últimos 4. ▶ Faltan las tarjetas de Edgar.
insert into public.cuentas as c
  (codigo, nombre, nombre_en, tipo, padre, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
select v.codigo, v.nombre, v.nombre_en, v.tipo,
       case when position('-' in v.codigo) > 0 then split_part(v.codigo, '-', 1) end,
       v.saldo_normal, v.imputable, v.regla_obra, v.regla_cost_code, v.etiqueta_fiscal, v.notas
  from (values
  -- 1000 · Activo
  ('1010', 'Banco operativo',                           'Operating bank account',                              'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1030', 'Reserva de impuestos',                      'Tax reserve account',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1050', 'Efectivo (caja chica)',                     'Cash on hand (petty cash)',                           'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'El efectivo que se saca de Chase para pagar en efectivo (Edgar, 24-sep): el retiro entra aquí (Dr 1050 / Cr 1010) y cada compra en efectivo sale de aquí. El saldo es el efectivo que debe haber en el bolsillo. Un retiro para Edgar NO es de esta cuenta: va a 3200.'),
  ('1110', 'Cuentas por cobrar',                        'Accounts receivable',                                 'activo',  'debe',  true,  'opcional',    'prohibida',   null,           'Por factura (f03). La obra va cuando la factura la tiene.'),
  ('1120', 'Retención por cobrar',                      'Retainage receivable',                                'activo',  'debe',  true,  'obligatoria', 'prohibida',   null,           'Retainage, siempre por obra. En QuickBooks es un parche.'),
  ('1130', 'Cuenta por cobrar al accionista',           'Due from shareholder',                                'activo',  'debe',  true,  'prohibida',   'prohibida',   'accionista',   'Con nota firmada e interés (el interés cobrado va a 4910).'),
  ('1190', 'Provisión de incobrables',                  'Allowance for doubtful accounts',                     'activo',  'haber', true,  'opcional',    'prohibida',   null,           'Contra-activo de 1110. El gasto va a 6980.'),
  ('1200', 'Costo y utilidad en exceso de facturación', 'Costs and estimated earnings in excess of billings',  'activo',  'debe',  true,  'obligatoria', 'prohibida',   null,           'WIP sub-facturado, por obra (f10).'),
  ('1300', 'Material en bodega',                        'Materials inventory',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'Lo comprado sin obra. Al salir a una obra pasa a 5100 con su obra.'),
  ('1410', 'Seguros pagados por adelantado',            'Prepaid insurance',                                   'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           'La prima de WC se amortiza a 5015 (burden real, sin obra); GL, auto y sombrilla a 6200.'),
  ('1420', 'Fianzas',                                   'Prepaid surety bonds',                                'activo',  'debe',  true,  'opcional',    'prohibida',   null,           'Una fianza de cumplimiento es de un contrato: puede ir por obra.'),
  ('1510', 'Vehículos',                                 'Vehicles',                                            'activo',  'debe',  true,  'prohibida',   'prohibida',   'vehiculo',     'Por placa como etiqueta en activos_fijos (f08), no subcuentas.'),
  ('1520', 'Herramienta y equipo',                      'Tools and equipment',                                 'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1530', 'Cómputo',                                   'Computer equipment',                                  'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1540', 'Mejoras al local',                          'Leasehold improvements',                              'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('1590', 'Depreciación acumulada',                    'Accumulated depreciation',                            'activo',  'haber', true,  'prohibida',   'prohibida',   null,           'Contra-activo. Igual a la suma de activos_fijos (f08).'),
  ('1600', 'Depósitos',                                 'Deposits',                                            'activo',  'debe',  true,  'prohibida',   'prohibida',   null,           null),

  -- 2000 · Pasivo
  ('2010', 'Cuentas por pagar',                         'Accounts payable',                                    'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Una línea abierta por proveedor (f03); se concilia contra el statement del supply (f08). Lo devengado sin factura no va aquí: va a 2050.'),
  ('2020', 'Retención por pagar a subcontratistas',     'Retainage payable to subcontractors',                 'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'Por obra.'),
  ('2050', 'Costos y gastos devengados por pagar',      'Accrued costs and expenses',                          'pasivo',  'haber', true,  'opcional',    'prohibida',   null,           'El devengo de cierre sin factura (el avance de un sub sin facturar, el material recibido sin factura): reversible, se deshace solo el día 1 (c2). Nunca contra 2010, que se concilia contra el statement de cada proveedor. Los sueldos devengados van a 2210 y el PTO a 2215.'),
  ('2100', 'Tarjetas de crédito',                       'Credit cards',                                        'pasivo',  'haber', false, 'prohibida',   'prohibida',   null,           'Cuenta de GRUPO: no recibe asientos. Una subcuenta por tarjeta (2100-XXXX, los últimos 4); cuelga sola de 2100.'),
  ('2100-2009', 'Amex Business Blue',                  'Amex Business Blue',                                  'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'La tarjeta que acaba en 2009 (Edgar, 24-sep). En QuickBooks: Amex Blue (2009).'),
  ('2100-2013', 'Amex Business Gold',                  'Amex Business Gold',                                  'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'La tarjeta que acaba en 2013 (Edgar, 24-sep). En QuickBooks la Gold figura como 1007.'),
  ('2210', 'Sueldos acumulados',                        'Accrued wages',                                       'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2215', 'Vacaciones devengadas',                     'Accrued paid time off',                               'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Solo si se devenga PTO.'),
  ('2220', 'Impuestos de nómina retenidos',             'Payroll taxes withheld (941)',                        'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Solo el 941: lo retenido al empleado (impuesto federal, Social Security y Medicare) y la parte patronal de Social Security y Medicare, que se depositan juntos. Del journal del proveedor de nómina (f11). El FUTA va a 2225 y el RT-6 a 2230.'),
  ('2225', 'FUTA por pagar',                            'Federal unemployment tax payable (940)',              'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'El FUTA patronal (940), del journal del proveedor de nómina (f11). Aparte del 941 (2220) y del RT-6 (2230): cada uno amarra contra su declaración.'),
  ('2230', 'Reempleo de Florida por pagar',             'Florida reemployment tax payable (RT-6)',             'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2240', 'Deducciones a empleados',                   'Employee deductions payable',                         'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2250', 'Reembolsos a empleados por pagar',          'Employee reimbursements payable',                     'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Lo que un empleado pagó de su bolsillo por la empresa (f03: recibo con forma de pago reembolso). Lo de Edgar va a 2900.'),
  ('2300', 'Use tax por pagar',                         'Use tax payable',                                     'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           'Compras sin impuesto de Florida y ventas al detalle. NUNCA desde un recibo que ya trae impuesto.'),
  ('2400', 'Facturación en exceso de costo',            'Billings in excess of costs and estimated earnings',  'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'WIP sobre-facturado, por obra (f10).'),
  ('2410', 'Provisión por pérdida en contratos',        'Provision for losses on contracts',                   'pasivo',  'haber', true,  'obligatoria', 'prohibida',   null,           'Contra 5950: la pérdida completa el mes que se detecta (f10).'),
  ('2510', 'Línea de crédito',                          'Line of credit',                                      'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2520', 'Préstamos de vehículo — corriente',         'Vehicle loans — current portion',                     'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2530', 'Préstamos de vehículo — largo plazo',       'Vehicle loans — long-term portion',                   'pasivo',  'haber', true,  'prohibida',   'prohibida',   null,           null),
  ('2900', 'Préstamo del accionista',                   'Loan from shareholder',                               'pasivo',  'haber', true,  'prohibida',   'prohibida',   'accionista',   'Lo que Edgar paga de su bolsillo por la empresa (f03). Lo de un empleado va a 2250.'),

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
  ('4900', 'Otros ingresos',                            'Other income',                                        'otro_ingreso', 'haber', true, 'opcional', 'prohibida',   null,           'Lo que no es contrato ni tiene cuenta propia (no los intereses: 4910; no la venta de un activo: 4920).'),
  ('4910', 'Ingresos por intereses',                    'Interest income',                                     'otro_ingreso', 'haber', true, 'prohibida', 'prohibida',  'K-1 intereses', 'Intereses cobrados (el préstamo al accionista, 1130; la cuenta del banco). En el K-1 van aparte (portafolio). ▶ Edgar confirma con el CPA.'),
  ('4920', 'Ganancia o pérdida en venta de activos',    'Gain or loss on disposal of assets',                  'otro_ingreso', 'haber', true, 'prohibida', 'prohibida',  '4797',         'La baja o venta de un activo fijo (f08): precio contra valor en libros. Va al Form 4797 (§1231). ▶ Edgar confirma con el CPA.'),

  -- 5000 · Costo directo (aquí pega la decisión de cost codes: opción B;
  -- la obra es obligatoria y el cost code opcional)
  ('5000', 'Mano de obra directa',                      'Direct labor',                                        'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           'ÚNICA fuente de dólares: el journal del proveedor de nómina (f11). horas no postea dinero.'),
  ('5001', 'Mano de obra directa — accionista-oficial', 'Direct labor — officer',                              'costo',   'debe',  true,  'obligatoria', 'opcional',    'oficial 1125-E', 'La parte de obra del sueldo de Edgar, del journal (f11). Con 6005 suma la compensación de oficiales del 1120-S (1125-E, línea 3 la parte en costo). ▶ Edgar decide con el CPA.'),
  ('5010', 'Burden de mano de obra',                    'Labor burden',                                        'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           'Burden POR OBRA. Solo le llega lo que se reparte a las obras: el real desde 5015 (Dr 5010-obra / Cr 5015, f09) o el aplicado a tasa (Dr 5010-obra / Cr 5011), nunca los dos. Nunca directo del journal ni de 1410. El GL nunca va aquí: va a 6200.'),
  ('5011', 'Burden aplicado a obra',                    'Applied labor burden',                                'costo',   'haber', true,  'prohibida',   'prohibida',   null,           'Crédito del burden aplicado a tasa estándar (Dr 5010-obra / Cr 5011, f09). Bolsa sin obra. Sin tasa aplicada no se usa.'),
  ('5015', 'Burden real',                               'Actual labor burden',                                 'costo',   'debe',  true,  'prohibida',   'prohibida',   null,           'Bolsa sin obra del burden REAL: impuestos patronales del journal (f11), prima de WC amortizada desde 1410 y su ajuste de auditoría. Sale a las obras por reparto (Dr 5010-obra / Cr 5015, f09); con tasa aplicada, el cierre lleva 5015 − 5011 a 5019 (f08).'),
  ('5019', 'Variación de burden',                       'Labor burden variance',                               'costo',   'debe',  true,  'prohibida',   'prohibida',   null,           'Real (5015) contra aplicado (5011); se cierra en f08. Bolsa sin obra.'),
  ('5100', 'Material',                                  'Materials',                                           'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           'El total del recibo con su impuesto incluido (f03).'),
  ('5200', 'Subcontratos',                              'Subcontracts',                                        'costo',   'debe',  true,  'obligatoria', 'opcional',    '1099',         null),
  ('5300', 'Equipo y renta',                            'Equipment and rentals',                               'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           null),
  ('5400', 'Permisos e inspecciones',                   'Permits and inspections',                             'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           null),
  ('5500', 'Consumibles',                               'Consumables',                                         'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           null),
  ('5600', 'Flete',                                     'Freight',                                             'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           null),
  ('5900', 'Garantía y retrabajo',                      'Warranty and rework',                                 'costo',   'debe',  true,  'obligatoria', 'opcional',    null,           null),
  ('5950', 'Pérdida en contrato',                       'Provision for contract losses',                       'costo',   'debe',  true,  'obligatoria', 'prohibida',   null,           'Contra 2410, la pérdida completa el mes que se detecta (f10). Por obra, sin cost code.'),

  -- 6000 · Gasto general (nunca por obra)
  ('6000', 'Sueldo administrativo',                     'Administrative salaries',                             'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'Sueldos de oficina de quien NO es oficial. El de Edgar va a 6005 (y su parte de obra a 5001).'),
  ('6005', 'Compensación de oficiales',                 'Compensation of officers',                            'gasto',   'debe',  true,  'prohibida',   'prohibida',   'oficial 1125-E', 'El sueldo de Edgar como oficial (la parte que no es de obra), solo por nómina; nunca como transferencia (f07). 1120-S línea 7 y Form 1125-E. ▶ Edgar confirma con el CPA.'),
  ('6006', 'Seguro médico del accionista (>2 %)',       'Shareholder health insurance (more than 2% owner)',   'gasto',   'debe',  true,  'prohibida',   'prohibida',   'W-2 accionista', 'La prima del seguro médico de Edgar: va en su W-2 y el CPA la trata aparte. ▶ Edgar confirma con el CPA.'),
  ('6010', 'Burden administrativo',                     'Administrative payroll burden',                       'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6100', 'Renta',                                     'Rent',                                                'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6110', 'Servicios',                                 'Utilities',                                           'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6120', 'Teléfono y datos',                          'Telephone and internet',                              'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           null),
  ('6130', 'Cargos bancarios y comisiones de tarjeta',  'Bank charges and card processing fees',               'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'Gasto de operación (antes 7200, debajo de la utilidad de operación).'),
  ('6200', 'Seguros — GL, auto, sombrilla',             'Insurance — general liability, auto, umbrella',       'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'El GL nunca va también en el burden (5010, 5015).'),
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
  ('7900', 'Otros gastos',                              'Other expenses',                                      'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   null,           'Lo que no tiene cuenta propia (no las donaciones: 7910; no las multas: 7920).'),
  ('7910', 'Donaciones',                                'Charitable contributions',                            'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   'K-1 donaciones', 'No son gasto deducible de la S-corp: pasan al K-1 de Edgar. ▶ Edgar confirma con el CPA.'),
  ('7920', 'Multas y recargos',                         'Fines and penalties',                                 'otro_gasto', 'debe', true, 'prohibida',   'prohibida',   'no deducible', 'No deducibles (conciliación M-1). Los recargos por pagar tarde un impuesto también van aquí.'),
  -- 9000: gasto de operación (en el P&L va con los gastos; el número solo
  -- la aparta para que se vea).
  ('9000', 'Impuestos y tasas de la EMPRESA',           'Business taxes and licenses',                         'gasto',   'debe',  true,  'prohibida',   'prohibida',   null,           'Propiedad tangible (DR-405), annual report de Sunbiz. El impuesto sobre la renta de Edgar NO es gasto: va a 3200.')
  ) as v(codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code, etiqueta_fiscal, notas)
 order by v.codigo
on conflict (codigo) do update set
  nombre          = excluded.nombre,
  nombre_en       = excluded.nombre_en,
  tipo            = excluded.tipo,
  padre           = excluded.padre,
  saldo_normal    = excluded.saldo_normal,
  imputable       = excluded.imputable,
  regla_obra      = excluded.regla_obra,
  regla_cost_code = excluded.regla_cost_code,
  etiqueta_fiscal = excluded.etiqueta_fiscal,
  notas           = excluded.notas
where (c.nombre, c.nombre_en, c.tipo, c.padre, c.saldo_normal, c.imputable,
       c.regla_obra, c.regla_cost_code, c.etiqueta_fiscal, c.notas)
      is distinct from
      (excluded.nombre, excluded.nombre_en, excluded.tipo, excluded.padre, excluded.saldo_normal, excluded.imputable,
       excluded.regla_obra, excluded.regla_cost_code, excluded.etiqueta_fiscal, excluded.notas);


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: el plan, para reconocerlo.
-- Esperado: 88 cuentas (87 imputables; 2100 es de grupo, con las dos
-- Amex: 2100-2009 la Blue y 2100-2013 la Gold; 1050 la caja chica).
-- =====================================================================
select codigo, nombre, tipo, saldo_normal as saldo, imputable, activa,
       regla_obra as obra, regla_cost_code as cost_code, etiqueta_fiscal
  from public.cuentas
 order by codigo;
