-- =====================================================================
-- c17-bandeja.sql — LA BANDEJA NUEVA (Fase 7, «Dímelo con tus palabras»).
-- 21-nov-2026. Se pega en el SQL Editor de Supabase DESPUÉS de c1…c16
-- (pide c1, c2, c3, c6 y c8; c10 y lo demás, si están, se usan). No cambia
-- ninguna capa anterior: no toca sus tablas, sus funciones ni sus permisos;
-- todo lo de aquí se llama bandeja_*, fn_bandeja_* y v_bandeja_*.
--
-- QUÉ RESUELVE. La Bandeja de c6 enseñaba, por cada movimiento del banco,
-- un párrafo de contabilidad y una lista larga de botones; Edgar (el dueño:
-- electricista, no contable, con el teléfono) no sabía cuál tocar. Con esta
-- capa cada tarjeta lleva:
--   1. UNA recomendación en palabras llanas y con los montos, y su «Así es».
--   2. Debajo, «¿Qué es? Dímelo con tus palabras»: la frase de Edgar va a la
--      IA (la función de borde «contador», acción «dimelo») con lo que la app
--      ya sabe, y vuelve UNA propuesta de la LISTA CERRADA de abajo, con
--      «Así es» y «No, es otra cosa». Si no la encuentra, dice qué le falta.
--   3. «Más opciones»: la lista de siempre de c6, detrás.
-- Y arriba, POR COMERCIO: una decisión para todos los cargos de un mismo
-- comercio, y lo que llegue después de ese comercio entra solo («Registrado
-- solo», con «Deshacer»).
--
-- LAS TRES REGLAS QUE NO SE NEGOCIAN
--   · LA IA PROPONE Y NUNCA POSTEA. Lo que contesta se valida aquí contra la
--     lista cerrada, las cuentas, las obras, las facturas y los montos de la
--     base (fn_bandeja_validar) y queda guardado como propuesta. El asiento
--     lo hace una puerta de c6 (o de c10), con sus guardas de siempre, y solo
--     cuando el dueño toca «Así es» (fn_bandeja_aprobar, por la API, con su
--     sesión y su código del teléfono). El texto que Edgar lee lo escribe
--     ESTA capa con los datos ya validados; lo que la IA explica va aparte,
--     marcado como suyo.
--   · LO QUE ESCRIBE EL BANCO Y LO QUE ESCRIBE EDGAR SON DATOS, nunca
--     instrucciones: van en el mensaje, no en las instrucciones, y todo pasa
--     antes por la máscara de c8 (fn_contador_sin_datos: sin correos,
--     teléfonos ni números de cuenta).
--   · NADA INSEGURO ENTRA SOLO. Solo entra solo un CARGO de un comercio con
--     una regla que Edgar puso con «que entre solo», hasta el tope de
--     bandeja_config.solo_tope, cuando c6 no tiene nada mejor que decir de él
--     (su motivo es «sin ticket»), no parece un duplicado, y el banco (c6) lo
--     acepta SIN motivo escrito. Un depósito, un Zelle, un cheque, un retiro
--     de cajero, la nómina, un traspaso o un préstamo NUNCA entran solos por
--     esta capa: solo se proponen. (Los Zelle a la cuadrilla los registra
--     c10 con sus propias reglas, si Edgar las tiene encendidas: «la
--     cuadrilla, sola»; esta capa no los toca.)
--
-- LA LISTA CERRADA (lo que el banco ya sabe registrar; cada una, su puerta):
--   gasto         un gasto o un costo a una cuenta permitida, con su obra si
--                 la cuenta la pide (fn_banco_clasificar). En un depósito es
--                 la devolución de una compra.
--   personal      un cargo personal pagado desde la empresa: retiro del
--                 accionista, 3200 (fn_banco_clasificar, con su motivo).
--   cobro         el cobro de una o varias facturas con saldo en el libro,
--                 con la comisión del procesador si llegó neto
--                 (fn_banco_cobrar); la factura queda cobrada también en
--                 Proyectos.
--   anticipo      el anticipo de una obra, todavía sin factura
--                 (fn_banco_cobrar con la obra).
--   prestamo      dinero que entra de un prestamista: deuda, no un cobro
--                 (fn_banco_clasificar a la cuenta del préstamo, con su
--                 motivo).
--   aporte        dinero de Edgar a la empresa: préstamo del accionista
--                 (2900) o aportación (3100), con su motivo.
--   traspaso      dinero entre cuentas propias, o el pago de la tarjeta
--                 (fn_banco_transferencia).
--   cuadrilla     el pago a alguien de la cuadrilla: lo reparte c10 por sus
--                 horas (fn_jornal_pago). Solo con c10.
--   contratista   el pago a un subcontratista por una obra (5200, con la
--                 obra y, si se sabe, el proveedor).
--   otro_ingreso  otros ingresos (4900) o intereses del banco (4910), con su
--                 motivo.
--   banco         una de las opciones que c6 ya propone para ESE movimiento
--                 (casar con lo que ya está en el libro, la cuota de un
--                 préstamo, un cheque devuelto, un duplicado…): se llama tal
--                 cual la guardó c6, nunca con argumentos que vengan de fuera.
--   falta         nada que registrar: dice qué falta.
-- Nada más. Ignorar un movimiento, el use tax, la nómina o un asiento a mano
-- no están en la lista: siguen donde estaban.
--
-- UNA SOLA APP (lo que esta capa conecta con Proyectos)
--   · La factura que Edgar marcó cobrada en Proyectos es la respuesta del
--     depósito que la paga: va primero entre las candidatas, sola o en el
--     lote de un procesador de tarjetas (hasta 4 facturas; neto de la
--     comisión, hasta 3.5 % + $0.30 por factura, o bruto con la comisión
--     aparte). Y al revés: al registrar el cobro, la factura que queda sin
--     saldo se marca cobrada en Proyectos (pagada, cobrada_el).
--   · Un depósito de un prestamista (los de la tabla prestamos, por su
--     descriptor o su nombre, y los nombres corrientes del oficio) se propone
--     como préstamo ANTES de mirar facturas: nunca como el pago de un cliente.
--   · Un cargo de un comercio de obra, sin recibo, en un día en que la
--     cuadrilla reportó horas en UNA sola obra: se propone esa obra.
--   · El recibo subido a una obra sigue casando su cargo con esa obra por c6
--     («primero casar»); aquí solo se dice en llano cuando falta terminarlo.
--
-- LAS CATEGORÍAS EN DOS NIVELES (fn_bandeja_categorias): lo que Edgar ve.
--   Gastos:   Costo de obra · Gastos generales · Otros gastos · Personal
--   Ingresos: Cobro de obra · Otros ingresos · Préstamo o aporte · Entre tus
--             cuentas
-- La cuenta exacta la pone la app (la de la categoría, la de la regla de ese
-- comercio o la que sugiere su nombre) y se puede cambiar en la tarjeta.
--
-- LO QUE SE RECUERDA (bandeja_memoria): por contraparte del banco (el
-- comercio, a quién va o de quién viene un Zelle, quién deposita), lo que
-- Edgar dijo que es. La próxima vez SE PROPONE con eso; entra solo
-- únicamente lo del párrafo «nada inseguro». Una regla nunca fija una obra:
-- la obra se propone cada vez (la del día de la cuadrilla) o se pregunta.
--
-- CÓMO ESTÁ HECHA
--   · Lo determinista (leer, recomendar, hacer, deshacer, decidir por grupo,
--     registrar solo) son funciones SECURITY INVOKER que la pantalla llama
--     por la API como el dueño (como c10): cada una empieza por
--     fn_bandeja_exigir_dueno(), y las tablas se escriben solo con la marca
--     de la transacción (mx_bandeja.escribe), que ponen estas funciones.
--     Ninguna función es SECURITY DEFINER.
--   · Lo de la IA (fn_bandeja_dimelo_contexto y fn_bandeja_dimelo_guardar)
--     lo llama solo la función de borde, conectada como postgres (como c8:
--     fn_contador_exigir); no está en la API. Su gasto se anota donde el de
--     c8 (acción «contador_dimelo») y cuenta contra el mismo tope del mes.
--   · La tarea sin pantalla (fn_bandeja_solo_programado, pg_cron 11:18 y
--     20:54 UTC: después del jornal de c10 y antes de la IA de c8) corre la
--     rutina en nombre del dueño que la encendió, como la de c10.
--   · Lo que deja abierto de c8 (su propuesta pendiente para un cargo que ya
--     se registró) se devuelve (propuestas_ia) para que la pantalla lo cierre
--     por la función de borde; la tarea lo cierra por la puerta de c8.
--
-- AL PEGAR: MX000 sin tocar nada si falta algo; se puede volver a pegar (no
-- pisa la configuración ni lo recordado). La última sentencia es
-- «select * from fn_bandeja_pegado();»: todas sus filas dicen «ok».
-- Sus pruebas: docs/conta/c17-pruebas.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  c_tablas constant text[] := array['bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos'];
  c_vistas constant text[] := array['v_bandeja_control'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)',
                             'fn_banco_clasificar(uuid,jsonb,text)', 'fn_banco_cobrar(uuid,jsonb,text)',
                             'fn_banco_transferencia(uuid,text,text)', 'fn_banco_descasar(uuid,text)', 'fn_banco_casar(uuid)',
                             'fn_cobro_anular(uuid,text)',
                             'fn_banco_dice_nomina(text,text)', 'fn_contador_exigir()', 'fn_contador_cfg()',
                             'fn_contador_sin_datos(text)', 'fn_contador_sin_datos_norm(text,text,text)',
                             'fn_contador_sin_datos_jsonb(jsonb)', 'fn_contador_tope()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'facturas', 'recibos',
                             'horas', 'movimientos_banco', 'banco_casados', 'prestamos', 'tarjetas', 'puente_cuentas',
                             'contador_config', 'contador_propuestas', 'contador_reglas', 'asistente_uso', 'v_banco_bandeja',
                             'facturas_cobro', 'v_contador_cuentas'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c17 se pega después de c1, c2, c3, c6 y c8 (y de las demás capas si se usan), con las tablas de la app: falta %s.',
                  array_to_string(v_falta, ', '));
  end if;
  -- Las columnas de otras capas y de la app que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('movimientos_banco', 'desc_norm'), ('movimientos_banco', 'propuesta'), ('movimientos_banco', 'estado'),
                 ('movimientos_banco', 'posible_duplicado_de'), ('movimientos_banco', 'duplicado'), ('movimientos_banco', 'asiento_id'),
                 ('movimientos_banco', 'tipo_banco'), ('movimientos_banco', 'cheque'), ('movimientos_banco', 'fecha_transaccion'),
                 ('facturas', 'pagada'), ('facturas', 'cobrada_el'), ('facturas', 'metodo_cobro'), ('facturas', 'estado'),
                 ('facturas_cobro', 'saldo_cxc'), ('facturas_cobro', 'saldo_retencion'), ('facturas_cobro', 'saldo_libro'),
                 ('proyectos', 'nombre'), ('proyectos', 'cliente'), ('proyectos', 'estado'),
                 ('horas', 'fecha'), ('horas', 'proyecto_id'), ('horas', 'horas'),
                 ('prestamos', 'prestamista'), ('prestamos', 'descriptor'), ('prestamos', 'cuenta'), ('prestamos', 'estado'),
                 ('tarjetas', 'cuenta'), ('tarjetas', 'activa'), ('perfiles', 'rol'), ('perfiles', 'activo'), ('perfiles', 'nombre'),
                 ('cuentas', 'tipo'), ('cuentas', 'regla_obra'), ('cuentas', 'imputable'), ('cuentas', 'nombre_en'),
                 ('contador_propuestas', 'movimiento_id'), ('contador_propuestas', 'estado'), ('contador_config', 'modelo'),
                 ('asistente_uso', 'accion'), ('asistente_uso', 'costo_centavos')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3, c6 y c8 pegados?', v_x);
  end if;
  -- Una tabla con el nombre de las de c17 que no sea de c17: se para antes de
  -- tocar nada.
  foreach v_x in array array['bandeja_config:solo_tope', 'bandeja_memoria:clave', 'bandeja_dimelo:frase', 'bandeja_hechos:fuente'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c17 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c17 que no sea de c17: «create or
  -- replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c17: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_bandeja\_%'
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c17: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c17 y sin ser de c17: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: la Bandeja la contesta el dueño.';
  end if;
  return null;
end $$;
revoke execute on function public.fn_bandeja_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_precondiciones() is 'c17: lo que falta para pegar c17-bandeja.sql (nulo = nada).';

do $$
declare
  v text;
begin
  v := public.fn_bandeja_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c17-bandeja NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1 … c16 y después este archivo (docs/conta/PEGAR-21NOV.md).';
  end if;
end $$;

-- La marca de la versión pegada (la pantalla y las pruebas la leen).
create or replace function public.fn_bandeja_version() returns bigint
language sql immutable
set search_path = public, pg_temp
as $$ select 2026112101::bigint $$;
revoke execute on function public.fn_bandeja_version() from public, anon, service_role;
grant  execute on function public.fn_bandeja_version() to authenticated;
comment on function public.fn_bandeja_version() is 'c17: la marca de la versión pegada de c17-bandeja.sql.';

-- ¿Quién llama por la API? Solo el dueño (es_dueno). El SQL Editor pasa.
create or replace function public.fn_bandeja_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'La Bandeja de Contabilidad la ve y la contesta solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_bandeja_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_bandeja_exigir_dueno() to authenticated;
comment on function public.fn_bandeja_exigir_dueno() is 'c17: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor pasa.';

-- Lo que registra o recuerda algo lo dice ALGUIEN: queda escrito quién. El
-- SQL Editor a secas (sin sesión) no; la tarea de pg_cron fija al dueño.
create or replace function public.fn_bandeja_quien() returns uuid
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v uuid := auth.uid();
begin
  perform fn_bandeja_exigir_dueno();
  if v is null or not exists (select 1 from perfiles p where p.id = v and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501',
      message = 'Esto lo hace el dueño con su sesión (queda escrito quién): desde el SQL Editor a secas, no.';
  end if;
  return v;
end $$;
revoke execute on function public.fn_bandeja_quien() from public, anon, service_role;
grant  execute on function public.fn_bandeja_quien() to authenticated;
comment on function public.fn_bandeja_quien() is 'c17: el dueño con sesión que registra, recuerda o deshace (auth.uid); sin sesión de dueño, 42501.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; se escriben solo por
--    las funciones de aquí, con la marca de la transacción). Sin llaves
--    foráneas a las tablas de c6 ni de la app: no se les cuelga nada que
--    cambie cómo se borran (lo que quede suelto lo dice el control).
-- ---------------------------------------------------------------------
-- La configuración: una sola fila. solo: lo de «entra solo», encendido de
-- fábrica (sin reglas con «que entre solo» no entra nada). solo_tope: el
-- cargo más grande que entra solo. dimelo: la caja «Dímelo con tus
-- palabras»; su esfuerzo (el de c8 es «low» para clasificar en ráfaga; aquí
-- es UNA llamada que tiene que entender una frase: «medium»).
create table if not exists public.bandeja_config (
  id               int           primary key,
  solo             boolean       not null default true,
  solo_tope        numeric(14,2) not null default 500.00,
  solo_por         uuid,
  solo_el          timestamptz,
  solo_ultimo      jsonb,
  dimelo           boolean       not null default true,
  dimelo_effort    text          not null default 'medium',
  actualizado      timestamptz   not null default now(),
  actualizado_por  uuid,
  constraint bandeja_config_una    check (id = 1),
  constraint bandeja_config_tope   check (solo_tope between 0 and 5000),
  constraint bandeja_config_effort check (dimelo_effort in ('low', 'medium', 'high'))
);
comment on table public.bandeja_config is 'c17: la configuración de la Bandeja nueva (una fila): si lo que tiene regla «que entre solo» entra solo (solo), hasta qué monto (solo_tope), quién lo encendió y cómo fue la última corrida de la tarea (solo_ultimo), y la caja «Dímelo con tus palabras» (dimelo, dimelo_effort).';

-- LO QUE EDGAR YA DIJO de una contraparte del banco (el comercio, a quién
-- va o de quién viene un Zelle, quién deposita). clave: la de
-- fn_bandeja_contraparte («C:HOME DEPOT», «Z>:ZZ JUAN», «D:ZZ ALFA LLC»).
-- accion + datos: la plantilla de la lista cerrada (sin obra fija ni
-- factura: eso se resuelve con cada movimiento). solo: que entre solo lo que
-- llegue después (solo un comercio, y solo gasto o personal: lo comprueba
-- fn_bandeja_recordar). No se borra: se da de baja (activa = false).
create table if not exists public.bandeja_memoria (
  clave         text        primary key,
  nombre        text        not null,
  clase         text        not null,
  accion        text        not null,
  datos         jsonb       not null default '{}'::jsonb,
  texto         text        not null,
  solo          boolean     not null default false,
  activa        boolean     not null default true,
  origen        text        not null default 'tarjeta',
  veces         int         not null default 0,
  ultima_vez    timestamptz,
  creada_por    uuid,
  creada_el     timestamptz not null default now(),
  cambiada_por  uuid,
  cambiada_el   timestamptz,
  constraint bandeja_memoria_clase  check (clase in ('comercio', 'zelle_a', 'zelle_de', 'deposito', 'procesador')),
  constraint bandeja_memoria_accion check (accion in ('gasto', 'personal', 'cobro', 'anticipo', 'prestamo', 'aporte', 'traspaso',
                                                      'cuadrilla', 'contratista', 'otro_ingreso')),
  constraint bandeja_memoria_origen check (origen in ('tarjeta', 'grupo', 'dimelo')),
  constraint bandeja_memoria_solo   check (not solo or (clase = 'comercio' and accion in ('gasto', 'personal')))
);
comment on table public.bandeja_memoria is 'c17: lo que Edgar ya dijo de una contraparte del banco (el comercio, el destinatario o el remitente de un Zelle, quien deposita): la acción de la lista cerrada y sus datos (sin obra fija ni factura). La próxima vez se propone con eso; «solo» (que entre solo) únicamente un comercio con gasto o personal.';

-- LAS PROPUESTAS DEL «DÍMELO» (la traza de la IA): lo que Edgar escribió
-- (tapado), lo que se le dio a la IA (entrada, tapada) y lo que contestó
-- (salida, cruda), con qué modelo, esfuerzo y versión de las instrucciones;
-- la acción YA VALIDADA (accion, datos) y el texto que Edgar leyó; y cómo
-- acabó. «sin_propuesta»: la IA no la encontró o la base no la aceptó
-- (falta dice por qué).
create table if not exists public.bandeja_dimelo (
  id               uuid        primary key default gen_random_uuid(),
  movimiento_id    uuid        not null,
  frase            text        not null,
  grupo            boolean     not null default false,
  modelo           text,
  effort           text,
  prompt_version   text,
  entrada          jsonb,
  salida           jsonb,
  accion           text,
  datos            jsonb,
  texto            text,
  porque           text,
  falta            text,
  recordar         boolean     not null default false,
  estado           text        not null default 'pendiente',
  centavos         int         not null default 0,
  uso              jsonb,
  pedido_por       uuid,
  creado_el        timestamptz not null default now(),
  resuelto_por     uuid,
  resuelto_el      timestamptz,
  resuelto_motivo  text,
  hecho_id         uuid,
  constraint bandeja_dimelo_estado check (estado in ('pendiente', 'aprobada', 'rechazada', 'caducada', 'sin_propuesta')),
  constraint bandeja_dimelo_accion check (estado = 'sin_propuesta' or (accion is not null and datos is not null and texto is not null))
);
create index if not exists bandeja_dimelo_mov_idx on public.bandeja_dimelo (movimiento_id, creado_el desc);
create unique index if not exists bandeja_dimelo_una_idx on public.bandeja_dimelo (movimiento_id) where estado = 'pendiente';
comment on table public.bandeja_dimelo is 'c17: las propuestas de «Dímelo con tus palabras»: la frase de Edgar y lo que se le dio a la IA (tapados), su respuesta cruda, el sello (modelo, esfuerzo, versión), la acción de la lista cerrada ya validada por la base, el texto que Edgar leyó y cómo acabó. Una pendiente por movimiento. La IA nunca postea: aprobar es fn_bandeja_aprobar, del dueño.';

-- LO QUE LA BANDEJA NUEVA REGISTRÓ (el rastro): cada «Así es» de una
-- recomendación, de un «Dímelo» o de un grupo, y cada cosa que entró sola.
-- solo = entró sin que nadie la tocara (por una regla de Edgar). Deshacer
-- (fn_bandeja_deshacer) lo marca; lo deshecho no vuelve a entrar solo.
create table if not exists public.bandeja_hechos (
  id               uuid          primary key default gen_random_uuid(),
  movimiento_id    uuid          not null,
  accion           text          not null,
  datos            jsonb         not null default '{}'::jsonb,
  texto            text          not null,
  fuente           text          not null,
  solo             boolean       not null default false,
  memoria_clave    text,
  dimelo_id        uuid,
  monto            numeric(14,2) not null,
  asiento_id       uuid,
  corrio           text          not null default 'pantalla',
  por              uuid,
  el               timestamptz   not null default now(),
  deshecho_el      timestamptz,
  deshecho_por     uuid,
  deshecho_motivo  text,
  constraint bandeja_hechos_fuente check (fuente in ('recomendacion', 'dimelo', 'grupo', 'solo', 'mas')),
  constraint bandeja_hechos_solo   check (solo = (fuente = 'solo')),
  constraint bandeja_hechos_corrio check (corrio in ('pantalla', 'rutina'))
);
create index if not exists bandeja_hechos_mov_idx on public.bandeja_hechos (movimiento_id, el desc);
create index if not exists bandeja_hechos_solo_idx on public.bandeja_hechos (el desc) where solo;
comment on table public.bandeja_hechos is 'c17: lo que la Bandeja nueva registró: el movimiento, la acción de la lista cerrada y sus datos, el texto llano, de dónde vino (recomendación, dímelo, grupo, solo, más opciones), quién y cuándo, su asiento, y si se deshizo (con su motivo). Lo que entró solo (solo = true) es «Registrado solo».';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas (la de c10, en su forma): se escriben solo con
--    la marca de la transacción (mx_bandeja.escribe = el nombre de la
--    tabla). Lo que es rastro no se borra ni se reescribe.
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_bandeja.escribe', true), '');
  c_dim   constant text[] := array['estado', 'resuelto_por', 'resuelto_el', 'resuelto_motivo', 'hecho_id'];
  c_hec   constant text[] := array['deshecho_el', 'deshecho_por', 'deshecho_motivo'];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003', message = format('%s no se trunca: es rastro de la Bandeja.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'bandeja_config' then 'es la configuración (una fila); se cambia con fn_bandeja_config.'
                         when 'bandeja_memoria' then 'lo recordado se da de baja (fn_bandeja_memoria con activa = false) y queda.'
                         when 'bandeja_dimelo' then 'es la traza de lo que se le pidió a la IA.'
                         else 'lo registrado se deshace con su motivo (fn_bandeja_deshacer) y queda.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones de la Bandeja, no a mano.', tg_table_name);
  end if;
  if tg_op = 'UPDATE' then
    if tg_table_name = 'bandeja_hechos' then
      if (to_jsonb(old)->>'deshecho_el') is not null or (to_jsonb(new)->>'deshecho_el') is null
         or (to_jsonb(new) - c_hec) is distinct from (to_jsonb(old) - c_hec) then
        raise exception using errcode = 'MX003', message = 'Lo registrado no se edita: se deshace con su motivo, una vez.';
      end if;
    elsif tg_table_name = 'bandeja_dimelo' then
      if (to_jsonb(old)->>'estado') <> 'pendiente' or (to_jsonb(new)->>'estado') = 'pendiente'
         or (to_jsonb(new) - c_dim) is distinct from (to_jsonb(old) - c_dim) then
        raise exception using errcode = 'MX003', message = 'Una propuesta del «Dímelo» no se edita: se aprueba, se rechaza o caduca, una vez.';
      end if;
    elsif tg_table_name = 'bandeja_memoria' and (to_jsonb(new)->>'clave') is distinct from (to_jsonb(old)->>'clave') then
      raise exception using errcode = 'MX003', message = 'Lo recordado de una contraparte no cambia de contraparte.';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_bandeja_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_guarda() is 'c17: la guarda de las tablas de c17: se escriben solo con la marca de la transacción (mx_bandeja.escribe) que ponen sus funciones; lo registrado solo pasa a deshecho y una propuesta solo se resuelve, una vez; nada se borra.';

do $$
declare
  t text;
begin
  foreach t in array array['bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_bandeja_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_bandeja_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y la policy de escritura del
--    dueño donde escribe una función INVOKER (con la guarda delante: la
--    policy dice quién, la marca dice por dónde). anon y service_role, nada.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['bandeja_memoria', 'bandeja_hechos'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
end $$;

-- La fila de la configuración (con la marca): al volver a pegar no se pisa.
do $$
begin
  if not exists (select 1 from public.bandeja_config where id = 1) then
    perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
    insert into public.bandeja_config (id) values (1);
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero y fechas en llano, y los textos de c6 sin jerga.
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '$?'
              when p < 0 then '−$' || to_char(abs(p), 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_bandeja_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_bandeja_usd(numeric) to authenticated;
comment on function public.fn_bandeja_usd(numeric) is 'c17: dinero en texto: $1,234.50.';

create or replace function public.fn_bandeja_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '' else
    extract(day from p)::int || ' ' ||
    (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int] end
$$;
revoke execute on function public.fn_bandeja_dia(date) from public, anon, service_role;
grant  execute on function public.fn_bandeja_dia(date) to authenticated;
comment on function public.fn_bandeja_dia(date) is 'c17: una fecha en llano: 5 nov.';

-- Un texto de c6 (una opción, un aviso) sin jerga: sin nombres de funciones
-- ni sus ejemplos entre paréntesis, sin «· 6130» detrás de una cuenta ni
-- «(con su motivo)». Lo que queda es lo que Edgar puede leer.
create or replace function public.fn_bandeja_llano(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select nullif(btrim(regexp_replace(
           regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(coalesce(p, ''), '\s*\([^()]*(fn_|puentes_bandeja|\{")[^()]*\)', '', 'g'),
                 '\s*\(con su motivo( escrito)?\)', '', 'g'),
               '\s*·\s*[0-9]{4}(-[0-9]{4})?\M', '', 'g'),
             '\mfn_[a-z0-9_]+\M', 'la app', 'g'),
           '\s{2,}', ' ', 'g')), '')
$$;
revoke execute on function public.fn_bandeja_llano(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_llano(text) to authenticated;
comment on function public.fn_bandeja_llano(text) is 'c17: un texto de c6 sin jerga (nombres de funciones, códigos de cuenta detrás de un nombre, «con su motivo»).';


-- ---------------------------------------------------------------------
-- 5. LA CONTRAPARTE: quién es el otro lado de un movimiento, sacado de lo
--    que escribió el banco (desc_norm, la descripción ya normalizada por
--    c6: mayúsculas, sin signos). De ahí sale el GRUPO (la clave) y la
--    CLASE, que decide qué se puede hacer solo con él.
-- ---------------------------------------------------------------------
-- EL NOMBRE DEL COMERCIO: las primeras palabras hasta la primera que trae
-- un número (el de la tienda, una fecha), sin la forma de pago delante («POS
-- DEBIT», «SQ», «TST»), sin la ciudad y el estado del final («SHELL OIL
-- OCALA FL» → «SHELL OIL») y con tres palabras como mucho. Un ACH dice quién
-- cobra después de «ORIG CO NAME». Las tiendas dentro de una plataforma
-- («DOORDASH BURGERKING», «AMZN MKTP») se quedan en la plataforma. Nulo si
-- no queda nada con sentido (una palabra del banco sola: «DEPOSIT»).
create or replace function public.fn_bandeja_comercio(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  c_delante   constant text[] := array['POS', 'DEBIT', 'CREDIT', 'PURCHASE', 'CHECKCARD', 'CARD', 'DBT', 'CRD', 'VISA', 'MASTERCARD',
                                       'RECURRING', 'ONLINE', 'ACH', 'WEB', 'PPD', 'CCD', 'ELECTRONIC', 'WITHDRAWAL', 'EXTERNAL',
                                       'PAYMENT', 'PMT', 'BILL', 'BILLPAY', 'SQ', 'TST', 'PP', 'SP', 'PY', 'DD', 'THE', 'PREAUTHORIZED',
                                       'DIRECT', 'DEP', 'MISC', 'INTERNET', 'AUTHORIZED', 'ON'];
  c_estados   constant text[] := array['AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY',
                                       'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC',
                                       'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI',
                                       'WY', 'DC', 'PR'];
  c_sueltas   constant text[] := array['WWW', 'COM', 'NET', 'ORG', 'HTTPS', 'HTTP', 'INC', 'LLC', 'CORP', 'LTD'];
  c_genericas constant text[] := array['CHECK', 'CHEQUE', 'CHK', 'ATM', 'DEPOSIT', 'TRANSFER', 'XFER', 'FEE', 'WIRE', 'ZELLE', 'VENMO',
                                       'CASHAPP', 'MOBILE', 'REMOTE', 'CASH', 'COUNTER', 'BRANCH', 'TELLER', 'INTEREST', 'ID', 'REF',
                                       'NUMBER', 'NO', 'PAYMENT', 'PURCHASE', 'DEBIT', 'CREDIT', 'CARD', 'ONLINE', 'WITHDRAWAL'];
  c_una       constant text[] := array['DOORDASH', 'GRUBHUB', 'INSTACART', 'LYFT', 'AMAZON', 'AMZN', 'NETFLIX', 'SPOTIFY', 'KLARNA',
                                       'AFFIRM', 'AFTERPAY', 'PAYPAL', 'APPLE', 'GOOGLE', 'MICROSOFT', 'SUNPASS', 'HULU', 'INTUIT'];
  v  text := upper(btrim(coalesce(p, '')));
  m  text[];
  w  text[];
  r  text[] := '{}';
  x  text;
  i  int := 1;
  n  int;
begin
  if v = '' then
    return null;
  end if;
  m := regexp_match(v, 'ORIG CO NAME (.+?)(?: ORIG ID| CO ENTRY| SEC | DESC | IND ID| IND NAME| TRN |$)');
  if m is not null then
    v := m[1];
  end if;
  w := regexp_split_to_array(btrim(regexp_replace(v, '[#*&]', ' ', 'g')), '\s+');
  n := coalesce(array_length(w, 1), 0);
  -- lo que el banco pone delante (la forma de pago), fuera; nunca hasta dejarlo vacío
  while i < n and w[i] = any (c_delante) loop
    i := i + 1;
  end loop;
  for j in i .. n loop
    x := w[j];
    exit when x ~ '[0-9]' and cardinality(r) > 0;
    continue when x = '' or x = any (c_sueltas);
    r := r || x;
    exit when cardinality(r) >= 4;
  end loop;
  if cardinality(r) = 0 then
    return null;
  end if;
  if r[1] = any (c_una) then
    r := case when r[1] = 'AMZN' then array['AMAZON'] else r[1:1] end;
  elsif r[1] = 'UBER' then
    r := case when cardinality(r) > 1 and r[2] = 'EATS' then r[1:2] else r[1:1] end;
  elsif cardinality(r) >= 3 and r[cardinality(r)] = any (c_estados) then
    r := r[1:cardinality(r) - 2];
  elsif cardinality(r) = 2 and r[2] = any (c_estados) then
    r := r[1:1];
  end if;
  if cardinality(r) > 3 then
    r := r[1:3];
  end if;
  x := array_to_string(r, ' ');
  if length(x) < 3 or x ~ '^[0-9 ]+$' or r[1] = any (c_genericas) then
    return null;
  end if;
  return x;
end $$;
revoke execute on function public.fn_bandeja_comercio(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_comercio(text) to authenticated;
comment on function public.fn_bandeja_comercio(text) is 'c17: el nombre del comercio de una descripción normalizada del banco (sin la forma de pago, el número de tienda, la ciudad ni el estado; tres palabras como mucho); nulo si no hay comercio.';

-- LA CONTRAPARTE de un movimiento: {clase, clave, nombre}.
--   cheque         un cheque (no dice a quién): sin clave.
--   cajero         un retiro o un depósito de efectivo en el cajero: sin clave.
--   zelle_a/_de    un Zelle (o Venmo, Cash App) a alguien o de alguien: la
--                  clave lleva su nombre como lo escribe el banco.
--   nomina         lo que c6 reconoce como nómina (Gusto).
--   transferencia  entre cuentas propias, o el pago de una tarjeta.
--   procesador     el depósito de un procesador de tarjetas (Intuit,
--                  Stripe, Square…): junta cobros de clientes.
--   deposito       cualquier otro depósito (con clave si dice quién).
--   comercio       un cargo de un comercio: la clave es su nombre.
--   otro           un cargo que no dice de quién.
-- Solo un «comercio» puede entrar solo (y solo si Edgar lo dijo).
create or replace function public.fn_bandeja_contraparte(p_desc_norm text, p_memo text, p_monto numeric, p_tipo text, p_cheque text)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v    text := upper(btrim(coalesce(p_desc_norm, '')));
  m    text[];
  r    text[] := '{}';
  x    text;
  v_n  text;
begin
  if coalesce(p_tipo, '') = 'CHECK' or nullif(btrim(coalesce(p_cheque, '')), '') is not null or v ~ '^(CHECK|CHEQUE|CHK)( |$)' then
    return jsonb_build_object('clase', 'cheque', 'nombre', 'Cheque' || coalesce(' ' || nullif(btrim(p_cheque), ''), ''));
  end if;
  if coalesce(p_tipo, '') = 'ATM' or v ~ '(^| )ATM( |$)' or v ~ 'CASH (WITHDRAWAL|DEPOSIT)' then
    return jsonb_build_object('clase', 'cajero', 'nombre', case when p_monto > 0 then 'Depósito de efectivo' else 'Retiro de cajero' end);
  end if;
  m := regexp_match(v, '(?:^| )(?:ZELLE|VENMO|CASH ?APP)(?: (?:PAYMENT|TRANSFER|INSTANT|PMT))* (?:TO|FROM) (.+)$');
  if m is not null or v ~ '(^| )(ZELLE|VENMO)( |$)' then
    if m is not null then
      foreach x in array regexp_split_to_array(m[1], '\s+') loop
        exit when x ~ '[0-9]' or x in ('CONF', 'CONFIRMATION', 'REF', 'ID', 'MEMO', 'JPM', 'BAC', 'WFCT', 'ON', 'FOR', 'VIA');
        r := r || x;
        exit when cardinality(r) >= 4;
      end loop;
    end if;
    v_n := nullif(array_to_string(r, ' '), '');
    return jsonb_strip_nulls(jsonb_build_object(
      'clase', case when p_monto < 0 then 'zelle_a' else 'zelle_de' end,
      'clave', case when v_n is not null then 'Z' || case when p_monto < 0 then '>' else '<' end || ':' || v_n end,
      'nombre', coalesce(initcap(v_n), 'Zelle')));
  end if;
  if fn_banco_dice_nomina(v, p_memo) then
    return jsonb_build_object('clase', 'nomina', 'nombre', 'Nómina');
  end if;
  if coalesce(p_tipo, '') = 'XFER'
     or v ~ '(ONLINE TRANSFER|TRANSFER (TO|FROM)|BOOK TRANSFER|(^| )XFER( |$)|THANK YOU|AUTOPAY|(^| )AMEX( |$)|AMERICAN EXPRESS|CREDIT CA?RD|CARD ?MEMBER SERV)' then
    return jsonb_build_object('clase', 'transferencia', 'nombre', 'Entre cuentas');
  end if;
  if p_monto > 0 then
    m := regexp_match(v, '(?:^| )(INTUIT|QBPAYMENTS|QUICKBOOKS|QB PAYMENTS|STRIPE|SQUARE|SQ|PAYPAL|CLOVER|BANKCARD|MERCHANT|WORLDPAY)(?: |$)');
    if m is not null then
      x := case when m[1] in ('INTUIT', 'QBPAYMENTS', 'QUICKBOOKS', 'QB PAYMENTS') then 'INTUIT'
                when m[1] in ('SQUARE', 'SQ') then 'SQUARE'
                when m[1] in ('BANKCARD', 'MERCHANT') then 'TARJETAS' else m[1] end;
      return jsonb_build_object('clase', 'procesador', 'clave', 'P:' || x,
                                'nombre', case x when 'INTUIT' then 'Intuit Payments (QuickBooks)' when 'TARJETAS' then 'Cobros con tarjeta'
                                                 else initcap(x) end);
    end if;
    v_n := fn_bandeja_comercio(v);
    return jsonb_strip_nulls(jsonb_build_object('clase', 'deposito', 'clave', 'D:' || v_n, 'nombre', coalesce(v_n, 'Depósito')));
  end if;
  v_n := fn_bandeja_comercio(v);
  if v_n is null then
    return jsonb_build_object('clase', 'otro', 'nombre', 'Sin nombre');
  end if;
  return jsonb_build_object('clase', 'comercio', 'clave', 'C:' || v_n, 'nombre', v_n);
end $$;
revoke execute on function public.fn_bandeja_contraparte(text, text, numeric, text, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_contraparte(text, text, numeric, text, text) to authenticated;
comment on function public.fn_bandeja_contraparte(text, text, numeric, text, text) is 'c17: la contraparte de un movimiento del banco: {clase (cheque, cajero, zelle_a, zelle_de, nomina, transferencia, procesador, deposito, comercio, otro), clave (el grupo; nula si no dice quién), nombre}.';


-- ---------------------------------------------------------------------
-- 6. LAS CATEGORÍAS EN DOS NIVELES (lo que Edgar ve) y la cuenta de cada
--    una. La cuenta exacta se puede cambiar en la tarjeta; lo que se guarda
--    en el libro es siempre la cuenta, con su nombre de siempre.
-- ---------------------------------------------------------------------
-- El catálogo, fila a fila (lo fijo: sin leer nada de la base).
create or replace function public.fn_bandeja_cat()
returns table (orden int, grupo text, grupo_nombre text, lado text, clave text, nombre text, accion text, cuenta text, extra jsonb)
language sql immutable
set search_path = public, pg_temp
as $$
  select * from (values
    (101, 'costo',    'Costo de obra',     'gasto',   'material',      'Material',                              'gasto',        '5100', null::jsonb),
    (102, 'costo',    'Costo de obra',     'gasto',   'subcontratos',  'Subcontratos',                          'contratista',  '5200', null),
    (103, 'costo',    'Costo de obra',     'gasto',   'cuadrilla',     'Cuadrilla (mano de obra)',              'cuadrilla',    null,   null),
    (104, 'costo',    'Costo de obra',     'gasto',   'permisos',      'Permisos e inspecciones',               'gasto',        '5400', null),
    (105, 'costo',    'Costo de obra',     'gasto',   'equipo',        'Equipo y renta',                        'gasto',        '5300', null),
    (106, 'costo',    'Costo de obra',     'gasto',   'consumibles',   'Consumibles',                           'gasto',        '5500', null),
    (107, 'costo',    'Costo de obra',     'gasto',   'flete',         'Flete',                                 'gasto',        '5600', null),
    (201, 'general',  'Gastos generales',  'gasto',   'camioneta',     'Camioneta y gasolina',                  'gasto',        '6300', null),
    (202, 'general',  'Gastos generales',  'gasto',   'peajes',        'Peajes',                                'gasto',        '6300', null),
    (203, 'general',  'Gastos generales',  'gasto',   'seguros',       'Seguros',                               'gasto',        '6200', null),
    (204, 'general',  'Gastos generales',  'gasto',   'telefono',      'Teléfono e internet',                   'gasto',        '6120', null),
    (205, 'general',  'Gastos generales',  'gasto',   'oficina',       'Oficina y software',                    'gasto',        '6500', null),
    (206, 'general',  'Gastos generales',  'gasto',   'comidas',       'Comidas',                               'gasto',        '6350', null),
    (207, 'general',  'Gastos generales',  'gasto',   'publicidad',    'Publicidad',                            'gasto',        '6700', null),
    (208, 'general',  'Gastos generales',  'gasto',   'profesionales', 'Profesionales (contador, abogado)',     'gasto',        '6600', null),
    (209, 'general',  'Gastos generales',  'gasto',   'herramienta',   'Herramienta menor y uniformes',         'gasto',        '6400', null),
    (210, 'general',  'Gastos generales',  'gasto',   'renta',         'Renta del local',                       'gasto',        '6100', null),
    (211, 'general',  'Gastos generales',  'gasto',   'servicios',     'Luz, agua y servicios',                 'gasto',        '6110', null),
    (212, 'general',  'Gastos generales',  'gasto',   'licencias',     'Licencias y cuotas',                    'gasto',        '6800', null),
    (213, 'general',  'Gastos generales',  'gasto',   'viajes',        'Viajes y alojamiento',                  'gasto',        '6360', null),
    (214, 'general',  'Gastos generales',  'gasto',   'banco',         'Cargos del banco y de la tarjeta',      'gasto',        '6130', null),
    (215, 'general',  'Gastos generales',  'gasto',   'impuestos',     'Impuestos y tasas de la empresa',       'gasto',        '9000', null),
    (301, 'otros',    'Otros gastos',      'gasto',   'intereses',     'Intereses',                             'gasto',        '7100', null),
    (302, 'otros',    'Otros gastos',      'gasto',   'multas',        'Multas y recargos',                     'gasto',        '7920', null),
    (303, 'otros',    'Otros gastos',      'gasto',   'donaciones',    'Donaciones',                            'gasto',        '7910', null),
    (304, 'otros',    'Otros gastos',      'gasto',   'otros_gastos',  'Otro gasto',                            'gasto',        '7900', null),
    (401, 'personal', 'Personal',          'gasto',   'retiro',        'Es mío, no de la empresa (retiro del accionista)', 'personal', '3200', null),
    (501, 'cobro',    'Cobro de obra',     'ingreso', 'factura',       'El pago de una factura',                'cobro',        null,   null),
    (502, 'cobro',    'Cobro de obra',     'ingreso', 'anticipo',      'Un anticipo de una obra (sin factura todavía)', 'anticipo', null, null),
    (601, 'ingresos', 'Otros ingresos',    'ingreso', 'otro_ingreso',  'Otro ingreso (un reembolso, una recompensa)', 'otro_ingreso', '4900', null),
    (602, 'ingresos', 'Otros ingresos',    'ingreso', 'intereses_banco', 'Intereses que paga el banco',         'otro_ingreso', '4910', null),
    (603, 'ingresos', 'Otros ingresos',    'ingreso', 'devolucion',    'La devolución de una compra',           'gasto',        null,   '{"devolucion": true}'),
    (701, 'prestamo', 'Préstamo o aporte', 'ingreso', 'prestamo',      'Dinero de un préstamo',                 'prestamo',     '2540', null),
    (702, 'prestamo', 'Préstamo o aporte', 'ingreso', 'mio_prestado',  'Dinero mío que le presto a la empresa', 'aporte',       '2900', '{"tipo": "prestamo_accionista"}'),
    (703, 'prestamo', 'Préstamo o aporte', 'ingreso', 'mio_aportado',  'Dinero mío que aporto a la empresa',    'aporte',       '3100', '{"tipo": "aportacion"}'),
    (801, 'cuentas',  'Entre tus cuentas', 'ambos',   'traspaso',      'Un traspaso entre mis cuentas o el pago de mi tarjeta', 'traspaso', null, null)) as t(orden, grupo, grupo_nombre, lado, clave, nombre, accion, cuenta, extra)
$$;
revoke execute on function public.fn_bandeja_cat() from public, anon, service_role;
grant  execute on function public.fn_bandeja_cat() to authenticated;
comment on function public.fn_bandeja_cat() is 'c17: el catálogo de categorías de la Bandeja, fila a fila (grupo, categoría, acción de la lista cerrada, cuenta de fábrica).';

create or replace function public.fn_bandeja_categorias() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(z.g order by z.orden), '[]'::jsonb)
    from (select min(c.orden) as orden,
                 jsonb_build_object('clave', c.grupo, 'nombre', c.grupo_nombre, 'lado', c.lado,
                                    'sub', jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                             'clave', c.clave, 'nombre', c.nombre, 'accion', c.accion, 'cuenta', c.cuenta,
                                             'cuenta_nombre', k.nombre, 'cuenta_en', k.nombre_en,
                                             'obra', case when k.regla_obra = 'obligatoria' or c.accion = 'contratista' then true end))
                                           || coalesce(c.extra, '{}'::jsonb) order by c.orden)) as g
            from fn_bandeja_cat() c
            left join cuentas k on k.codigo = c.cuenta
           where c.cuenta is null or (k.codigo is not null and k.imputable and coalesce((to_jsonb(k)->>'activa')::boolean, true))
           group by c.grupo, c.grupo_nombre, c.lado) z
$$;
revoke execute on function public.fn_bandeja_categorias() from public, anon, service_role;
grant  execute on function public.fn_bandeja_categorias() to authenticated;
comment on function public.fn_bandeja_categorias() is 'c17: las categorías en dos niveles que ve Edgar (Costo de obra, Gastos generales, Otros gastos, Personal; Cobro de obra, Otros ingresos, Préstamo o aporte, Entre tus cuentas), cada una con su acción de la lista cerrada y su cuenta de fábrica.';

-- El nombre llano de una cuenta: el de su categoría («Material»,
-- «Camioneta y gasolina») o, si no tiene, el de la cuenta.
create or replace function public.fn_bandeja_cuenta_llana(p_cuenta text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(
    (select c.nombre from fn_bandeja_cat() c
      where c.cuenta = p_cuenta and c.accion in ('gasto', 'personal', 'otro_ingreso', 'contratista')
      order by c.orden limit 1),
    (select k.nombre from cuentas k where k.codigo = p_cuenta),
    p_cuenta)
$$;
revoke execute on function public.fn_bandeja_cuenta_llana(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_cuenta_llana(text) to authenticated;
comment on function public.fn_bandeja_cuenta_llana(text) is 'c17: el nombre llano de una cuenta (el de su categoría de la Bandeja, o el de la cuenta).';

-- LO QUE SUGIERE EL NOMBRE del comercio, antes de que Edgar diga nada: las
-- marcas corrientes del oficio y de la casa. Es solo una sugerencia: nunca
-- entra sola por esto. {accion, cuenta} o nulo.
create or replace function public.fn_bandeja_sugerida(p_nombre text) returns jsonb
language sql immutable
set search_path = public, pg_temp
as $$
  select case
    when p is null then null
    when p ~ '(NETFLIX|SPOTIFY|HULU|DISNEY|\mHBO\M|PARAMOUNT|PEACOCK|YOUTUBE|PLAYSTATION|XBOX|NINTENDO|\mSTEAM|EPIC GAMES|ROBLOX|DOORDASH|UBER EATS|GRUBHUB|INSTACART|KLARNA|AFFIRM|AFTERPAY|SEZZLE|MORTGAGE)'
      then jsonb_build_object('accion', 'personal', 'cuenta', '3200')
    when p ~ '(FACEBK|FACEBOOK|META ADS|GOOGLE ADS|\mYELP\M|\mANGI\M|THUMBTACK|HOMEADVISOR|VISTAPRINT)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6700')
    when p ~ '(HOME DEPOT|\mLOWES\M|\mLOWE S\M|\mCED\M|GRAYBAR|\mPLATT\M|\mREXEL\M|ELECTRIC(AL)? SUPPLY|CITY ELECTRIC|\mCES\M|FERGUSON|GRAINGER|ACE HARDWARE|MENARDS|\mWESCO\M|WINSUPPLY|ELLIOTT ELECTRIC|MAYER ELECTRIC)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '5100')
    when p ~ '(HARBOR FREIGHT|NORTHERN TOOL)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6400')
    when p ~ '(SUNBELT|UNITED RENTALS|HERC RENTALS)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '5300')
    when p ~ '(\mSHELL\M|CHEVRON|EXXON|\mMOBIL\M|\mBP\M|\mWAWA\M|RACETRAC|SUNOCO|MARATHON|CIRCLE K|7 ELEVEN|SPEEDWAY|MURPHY|BUC EE|\mCITGO\M|\mVALERO\M|SUNPASS|\mE ?PASS\M|\mTOLL|AUTOZONE|O ?REILLY|ADVANCE AUTO|JIFFY LUBE|DISCOUNT TIRE)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6300')
    when p ~ '(\mCOUNTY\M|\mCITY OF\M|\mBOCC\M|BUILDING DEP|\mPERMIT|\mDBPR\M)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '5400')
    when p ~ '(VERIZON|T MOBILE|TMOBILE|\mATT\M|COMCAST|XFINITY|SPECTRUM)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6120')
    when p ~ '(PROGRESSIVE|\mGEICO\M|STATE FARM|ALLSTATE|INSURANCE|\mNEXT INS)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6200')
    when p ~ '(QUICKBOOKS|\mINTUIT\M|\mGOOGLE\M|MICROSOFT|\mADOBE\M|DROPBOX|\mZOOM\M|OPENAI|ANTHROPIC|GODADDY|\mWIX\M|SUPABASE|GITHUB)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6500')
    when p ~ '(MCDONALD|BURGER KING|\mWENDY|CHICK FIL|\mSUBWAY\M|STARBUCKS|DUNKIN|TACO BELL|CHIPOTLE|POLLO TROPICAL|RESTAURANT|\mPIZZA|\mGRILL\M|\mCAFE\M)'
      then jsonb_build_object('accion', 'gasto', 'cuenta', '6350')
  end
  from (select upper(p_nombre) as p) x
$$;
revoke execute on function public.fn_bandeja_sugerida(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_sugerida(text) to authenticated;
comment on function public.fn_bandeja_sugerida(text) is 'c17: lo que sugiere el nombre de un comercio corriente (material, gasolina, permisos, personal…): {accion, cuenta} o nulo. Solo sugiere: nada entra solo por esto.';


-- LAS CUENTAS PROPIAS entre las que se traspasa dinero: los bancos (10xx) y
-- las tarjetas dadas de alta; sin las cuentas de paso de los cobros en
-- línea (las de stripe_config, si p1 está pegado: ahí no se traspasa a mano).
create or replace function public.fn_bandeja_cuentas_propias() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_paso text[] := '{}';
begin
  if to_regclass('public.stripe_config') is not null then
    begin
      execute 'select array_remove(array[max(cuenta_puente), max(cuenta_paso)], null) from public.stripe_config' into v_paso;
    exception when others then
      v_paso := '{}';
    end;
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('codigo', k.codigo, 'nombre', k.nombre,
                                                       'tarjeta', exists (select 1 from tarjetas t where t.cuenta = k.codigo))
                                    order by k.codigo), '[]'::jsonb)
            from cuentas k
           where k.imputable and coalesce((to_jsonb(k)->>'activa')::boolean, true) and not (k.codigo = any (coalesce(v_paso, '{}')))
             and (k.codigo ~ '^10[0-9]{2}$' or exists (select 1 from tarjetas t where t.cuenta = k.codigo)));
end $$;
revoke execute on function public.fn_bandeja_cuentas_propias() from public, anon, service_role;
grant  execute on function public.fn_bandeja_cuentas_propias() to authenticated;
comment on function public.fn_bandeja_cuentas_propias() is 'c17: las cuentas propias entre las que se traspasa dinero (bancos 10xx y tarjetas dadas de alta, sin las de paso de Stripe): [{codigo, nombre, tarjeta}].';


-- ---------------------------------------------------------------------
-- 7. LO QUE LA APP YA SABE y conecta: las facturas con saldo (y cuáles marcó
--    Edgar cobradas en Proyectos), los prestamistas, la obra del día.
-- ---------------------------------------------------------------------
-- Un monto que llega como texto o número en un JSON: nulo si no lo es.
create or replace function public.fn_bandeja_num(p text) returns numeric
language sql immutable
set search_path = public, pg_temp
as $$ select case when btrim(coalesce(p, '')) ~ '^-?[0-9]{1,12}(\.[0-9]{1,4})?$' then round(btrim(p)::numeric, 2) end $$;
revoke execute on function public.fn_bandeja_num(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_num(text) to authenticated;
comment on function public.fn_bandeja_num(text) is 'c17: un monto de un JSON (texto o número) a numeric con dos decimales; nulo si no es un monto.';

-- LAS FACTURAS CON SALDO EN EL LIBRO (las que un depósito puede pagar: las
-- del puente y las de antes del corte que entraron con la apertura), con su
-- obra, su cliente y si Edgar ya la marcó cobrada en Proyectos.
create or replace function public.fn_bandeja_facturas() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', f.id, 'num', f.num, 'proyecto_id', f.proyecto_id, 'obra', p.nombre, 'cliente', p.cliente, 'fecha', f.fecha,
           'monto', f.monto, 'saldo', coalesce(f.saldo_cxc, 0), 'retencion', nullif(coalesce(f.saldo_retencion, 0), 0),
           'marcada', coalesce(f.pagada, false) or f.cobrada_el is not null,
           'cobrada_el', (f.cobrada_el at time zone 'America/New_York')::date, 'metodo', fa.metodo_cobro))
           order by f.fecha desc, f.id desc), '[]'::jsonb)
    from facturas_cobro f
    join facturas fa on fa.id = f.id
    left join proyectos p on p.id = f.proyecto_id
   where coalesce(f.estado, 'emitida') <> 'anulada' and (coalesce(f.saldo_cxc, 0) > 0 or coalesce(f.saldo_retencion, 0) > 0)
$$;
revoke execute on function public.fn_bandeja_facturas() from public, anon, service_role;
grant  execute on function public.fn_bandeja_facturas() to authenticated;
comment on function public.fn_bandeja_facturas() is 'c17: las facturas con saldo en el libro (lo que un depósito puede pagar), con su obra, su cliente y si están marcadas cobradas en Proyectos.';

-- ¿QUÉ FACTURAS PAGA ESTE DEPÓSITO? Entre las que tienen saldo y son de su
-- fecha o anteriores (las doce más probables: primero las que Edgar marcó
-- cobradas en Proyectos esos días, después las más cercanas), UNA sola o
-- hasta cuatro juntas que sumen el depósito al centavo o, si lo deposita un
-- procesador de tarjetas, que lo superen en una comisión creíble (hasta
-- 3.5 % + $0.30 por factura). Solo contesta si la respuesta es ÚNICA entre
-- las mejores (todas marcadas antes que alguna sin marcar; exacto antes que
-- con comisión; menos facturas antes que más): {facturas: [{id, num, obra,
-- monto}], comision, bruto, marcadas}. Con varias respuestas igual de
-- buenas, {varias: n}: se pregunta. Sin ninguna, nulo.
create or replace function public.fn_bandeja_cobro_de(p_facturas jsonb, p_monto numeric, p_fecha date, p_procesador boolean)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_res jsonb;
  v_n   int;
begin
  if p_monto is null or p_monto <= 0 or jsonb_typeof(p_facturas) is distinct from 'array' then
    return null;
  end if;
  with recursive c as (
    select (x->>'id')::bigint as id, x->>'num' as num, (x->>'saldo')::numeric as saldo, x->>'obra' as obra,
           ((x->>'marcada')::boolean
            and (x->>'cobrada_el' is null or (x->>'cobrada_el')::date between p_fecha - 12 and p_fecha + 3)) as marcada,
           (x->>'fecha')::date as fecha
      from jsonb_array_elements(p_facturas) x
     where (x->>'saldo')::numeric > 0 and (x->>'fecha')::date <= p_fecha),
  k as (select c.*, row_number() over (order by c.marcada desc, abs(c.fecha - p_fecha), c.id) as n from c),
  s (ids, suma, marc, ult, cnt) as (
    select array[k.id], k.saldo, k.marcada::int, k.n, 1 from k where k.n <= 12
    union all
    select s.ids || k.id, s.suma + k.saldo, s.marc + k.marcada::int, k.n, s.cnt + 1
      from s join k on k.n > s.ult and k.n <= 12
     where s.cnt < 4 and s.suma < p_monto * 1.04 + 2),
  sol as (
    select s.*, (case when s.marc = s.cnt then 0 else 1 end) as t1, (case when s.suma = p_monto then 0 else 1 end) as t2
      from s
     where s.suma = p_monto
        or (p_procesador and s.suma > p_monto and s.suma - p_monto <= round(s.suma * 0.035 + 0.30 * s.cnt, 2))),
  mejor as (select * from sol where (t1, t2, cnt) = (select t1, t2, cnt from sol order by t1, t2, cnt limit 1))
  select (select count(*) from mejor),
         (select jsonb_build_object(
                   'facturas', (select jsonb_agg(jsonb_build_object('id', k.id, 'num', k.num, 'obra', k.obra, 'monto', k.saldo) order by k.fecha, k.id)
                                  from k where k.id = any (m.ids)),
                   'comision', nullif(m.suma - p_monto, 0), 'bruto', m.suma, 'marcadas', m.marc)
            from mejor m limit 1)
    into v_n, v_res;
  if coalesce(v_n, 0) = 0 then
    return null;
  elsif v_n > 1 then
    return jsonb_build_object('varias', v_n);
  end if;
  return jsonb_strip_nulls(v_res);
end $$;
revoke execute on function public.fn_bandeja_cobro_de(jsonb, numeric, date, boolean) from public, anon, service_role;
grant  execute on function public.fn_bandeja_cobro_de(jsonb, numeric, date, boolean) to authenticated;
comment on function public.fn_bandeja_cobro_de(jsonb, numeric, date, boolean) is 'c17: las facturas con saldo (una, o hasta cuatro juntas) que explican un depósito al centavo o, de un procesador de tarjetas, con su comisión; primero las marcadas cobradas en Proyectos. Solo si la respuesta es única; {varias} si hay que preguntar.';

-- ¿ES DE UN PRESTAMISTA? Los préstamos dados de alta (por su descriptor o
-- por el nombre del prestamista como palabra entera) y, si no, las palabras
-- corrientes de un préstamo de negocio. {prestamo_id, prestamista, cuenta,
-- conocido} o nulo. Un depósito así NO es el cobro de un cliente.
create or replace function public.fn_bandeja_prestamista(p_desc_norm text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v  text := upper(coalesce(p_desc_norm, ''));
  r  record;
  w  text;
  m  text[];
begin
  if v = '' then
    return null;
  end if;
  for r in select p.id, p.prestamista, p.cuenta, p.descriptor from prestamos p order by p.creado_el, p.id loop
    select x.w into w
      from regexp_split_to_table(upper(regexp_replace(coalesce(r.prestamista, ''), '[^[:alnum:]]+', ' ', 'g')), ' ') with ordinality as x(w, n)
     where length(x.w) >= 4 and x.w not in ('BANK', 'LOAN', 'LOANS', 'CAPITAL', 'FINANCIAL', 'FINANCE', 'CREDIT', 'AUTO', 'BUSINESS', 'FUNDING')
     order by x.n limit 1;
    begin
      if (nullif(btrim(coalesce(r.descriptor, '')), '') is not null and v ~* r.descriptor)
         or (w is not null and v ~ ('\m' || w || '\M')) then
        return jsonb_build_object('prestamo_id', r.id, 'prestamista', r.prestamista, 'cuenta', r.cuenta, 'conocido', true);
      end if;
    exception when others then
      null;  -- un descriptor que no es una expresión regular válida: no casa
    end;
  end loop;
  m := regexp_match(v, '\m(ONDECK|ON DECK|KABBAGE|BLUEVINE|FUNDBOX|KAPITUS|LENDINGCLUB|LENDING CLUB|FUNDING CIRCLE|CREDIBLY|RAPID FINANCE|NATIONAL FUNDING|FORWARD FINANCING|HEADWAY CAPITAL|SBAD TREAS|SBA EIDL|SQUARE CAPITAL|SQ CAPITAL|QUICKBOOKS CAPITAL|QB CAPITAL|INTUIT FINANCING|WORKING CAPITAL|LOAN PROCEEDS|LOAN FUNDING|LOAN DISBURSEMENT|LOAN ADVANCE|CAPITAL ADVANCE|MERCHANT CASH ADVANCE)\M');
  if m is not null then
    return jsonb_build_object('prestamista', case when m[1] in ('ONDECK', 'ON DECK') then 'OnDeck' else initcap(m[1]) end,
                              'cuenta', '2540', 'conocido', false);
  end if;
  return null;
end $$;
revoke execute on function public.fn_bandeja_prestamista(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_prestamista(text) to authenticated;
comment on function public.fn_bandeja_prestamista(text) is 'c17: si la descripción del banco nombra a un prestamista (los dados de alta en prestamos, o las palabras corrientes de un préstamo de negocio): {prestamo_id, prestamista, cuenta, conocido} o nulo.';

-- LA OBRA DEL DÍA: si ese día la cuadrilla reportó horas en UNA sola obra,
-- esa obra. Con dos o más, o con ninguna, nulo (se pregunta).
create or replace function public.fn_bandeja_obra_del_dia(p_fecha date) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select case when count(*) = 1
              then jsonb_build_object('proyecto_id', min(x.id), 'nombre', min(x.nombre),
                                      'por', format('ese día (%s) la cuadrilla trabajó solo en esa obra', fn_bandeja_dia(p_fecha))) end
    from (select p.id, p.nombre
            from horas h
            join proyectos p on p.id = h.proyecto_id
           where h.fecha = p_fecha and coalesce(h.horas, 0) > 0
           group by p.id, p.nombre) x
$$;
revoke execute on function public.fn_bandeja_obra_del_dia(date) from public, anon, service_role;
grant  execute on function public.fn_bandeja_obra_del_dia(date) to authenticated;
comment on function public.fn_bandeja_obra_del_dia(date) is 'c17: la única obra en la que la cuadrilla reportó horas ese día ({proyecto_id, nombre, por}), o nulo si fueron varias o ninguna.';


-- ---------------------------------------------------------------------
-- 8. VALIDAR una acción de la LISTA CERRADA para un movimiento: lo que
--    conteste la IA, lo que recomiende la app y lo que elija Edgar pasan
--    todos por aquí antes de enseñarse o de registrarse. Devuelve {ok,
--    accion, datos (ya limpios: solo lo que la acción lleva), texto (lo que
--    Edgar lee, en llano y con los montos), falta (si no vale: qué falta),
--    pide_obra}. No escribe nada.
-- ---------------------------------------------------------------------
-- Las puertas de c6 que una opción suya puede llamar por la acción «banco».
create or replace function public.fn_bandeja_puertas() returns text[]
language sql immutable
set search_path = public, pg_temp
as $$
  select array['fn_banco_clasificar', 'fn_banco_cobrar', 'fn_banco_casar_con', 'fn_banco_transferencia', 'fn_banco_pagar_proveedor',
               'fn_banco_duplicado', 'fn_banco_devolver', 'fn_prestamo_cuota']
$$;
revoke execute on function public.fn_bandeja_puertas() from public, anon, service_role;
grant  execute on function public.fn_bandeja_puertas() to authenticated;
comment on function public.fn_bandeja_puertas() is 'c17: las puertas de c6 que la acción «banco» puede llamar (las de una opción que c6 guardó para ese movimiento); ninguna otra.';

-- Lo que pide una opción de c6 antes de llamarse: sus campos (pide) o su
-- motivo (pide_motivo), como la pantalla de siempre.
create or replace function public.fn_bandeja_opcion_pide(p_opcion jsonb) returns text[]
language sql immutable
set search_path = public, pg_temp
as $$
  select coalesce(array_agg(distinct t.p), '{}')
    from (select jsonb_array_elements_text(case when jsonb_typeof(p_opcion->'pide') = 'array' then p_opcion->'pide' else '[]'::jsonb end) as p
          union all
          select 'p_motivo'
           where p_opcion->>'pide_motivo' = 'true'
             and not (jsonb_typeof(p_opcion->'pide') = 'array' and jsonb_array_length(p_opcion->'pide') > 0)) t
$$;
revoke execute on function public.fn_bandeja_opcion_pide(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_opcion_pide(jsonb) to authenticated;
comment on function public.fn_bandeja_opcion_pide(jsonb) is 'c17: lo que una opción de c6 pide antes de llamarse (p_motivo, p_notas, p_capital, p_interes, p_partidas.motivo).';

-- Una opción de c6 dicha en llano.
create or replace function public.fn_bandeja_opcion_texto(p_opcion jsonb, p_monto numeric) returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_cta text;
  v_usd text := fn_bandeja_usd(abs(p_monto));
begin
  if p_opcion->>'llamar' = 'fn_banco_clasificar' and jsonb_typeof(p_opcion->'args'->'p_lineas') = 'array'
     and jsonb_array_length(p_opcion->'args'->'p_lineas') = 1 and not (p_opcion->'args'->'p_lineas'->0 ? 'factura_id') then
    v_cta := p_opcion->'args'->'p_lineas'->0->>'cuenta';
    return case v_cta
             when '3200' then format('Es tuyo, no de la empresa: %s que salen como retiro tuyo.', v_usd)
             when '2900' then format('Es dinero tuyo que le prestas a la empresa: %s.', v_usd)
             when '3100' then format('Es dinero tuyo que aportas a la empresa: %s.', v_usd)
             when '1050' then format('Es efectivo para la caja chica: %s.', v_usd)
             else format('Es «%s»: %s.', fn_bandeja_cuenta_llana(v_cta), v_usd) end;
  end if;
  return coalesce(regexp_replace(fn_bandeja_llano(p_opcion->>'texto'), '[.:;, ]+$', ''), 'Lo que propone el banco') || '.';
end $$;
revoke execute on function public.fn_bandeja_opcion_texto(jsonb, numeric) from public, anon, service_role;
grant  execute on function public.fn_bandeja_opcion_texto(jsonb, numeric) to authenticated;
comment on function public.fn_bandeja_opcion_texto(jsonb, numeric) is 'c17: una opción de c6 en palabras llanas (sin códigos de cuenta ni nombres de funciones).';

create or replace function public.fn_bandeja_validar(p_movimiento uuid, p_accion text, p_datos jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  d        jsonb := case when jsonb_typeof(p_datos) = 'object' then p_datos else '{}'::jsonb end;
  o        jsonb := '{}'::jsonb;
  k        cuentas;
  f        record;
  x        jsonb;
  v_falta  text;
  v_texto  text;
  v_obra   text;
  v_pide   boolean := false;
  v_usd    text;
  v_apps   jsonb := '[]'::jsonb;
  v_suma   numeric := 0;
  v_com    numeric;
  v_n      int;
  v_m      numeric;
  v_txt    text[] := '{}';
  v_nom    text;
  v_cta    text;
  v_id     text;
  v_i      int;
  v_op     jsonb;
  v_tarj   boolean;
  c_uuid   constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  perform fn_bandeja_exigir_dueno();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    return jsonb_build_object('ok', false, 'falta', 'Ese movimiento ya no existe.');
  end if;
  if m.estado <> 'pendiente' then
    return jsonb_build_object('ok', false, 'falta', 'Ese movimiento ya no está en la Bandeja.');
  end if;
  v_usd := fn_bandeja_usd(abs(m.monto));
  case coalesce(p_accion, '')
    when 'gasto' then
      select * into k from cuentas c where c.codigo = nullif(btrim(coalesce(d->>'cuenta', '')), '');
      if not found then
        v_falta := 'Falta decir qué tipo de gasto es.';
      elsif k.codigo in ('3200', '1130') or not exists (select 1 from v_contador_cuentas c where c.codigo = k.codigo) then
        v_falta := format('«%s» no se puede usar desde la Bandeja como un gasto.', k.nombre);
      else
        o := jsonb_build_object('cuenta', k.codigo);
        v_id := nullif(btrim(coalesce(d->>'proyecto_id', '')), '');
        if k.regla_obra in ('obligatoria', 'opcional') and v_id is not null then
          select p.nombre into v_obra from proyectos p where p.id = v_id;
          if v_obra is null then
            v_falta := 'Esa obra no existe en Proyectos.';
          else
            o := o || jsonb_build_object('proyecto_id', v_id);
          end if;
        end if;
        if v_falta is null and k.regla_obra = 'obligatoria' and not (o ? 'proyecto_id') then
          v_falta := format('Falta decir de qué obra es: «%s» va siempre a una obra.', fn_bandeja_cuenta_llana(k.codigo));
          v_pide := true;
        end if;
        v_texto := case when m.monto < 0
                        then format('Es un gasto de «%s»%s: %s.', fn_bandeja_cuenta_llana(k.codigo),
                                    coalesce(' de la obra ' || v_obra, case when v_pide then ' (falta la obra)' else '' end), v_usd)
                        else format('Es la devolución de una compra de «%s»%s: entran %s.', fn_bandeja_cuenta_llana(k.codigo),
                                    coalesce(' de la obra ' || v_obra, case when v_pide then ' (falta la obra)' else '' end), v_usd) end;
      end if;
    when 'personal' then
      if m.monto >= 0 then
        v_falta := 'Un gasto personal es dinero que sale, y esto es dinero que entró.';
      else
        o := jsonb_build_object('cuenta', '3200');
        v_texto := format('Es tuyo, no de la empresa: %s que salen como retiro tuyo (no es un gasto del negocio).', v_usd);
      end if;
    when 'cobro' then
      if m.monto <= 0 then
        v_falta := 'Un cobro es dinero que entra, y esto es dinero que salió.';
      elsif jsonb_typeof(d->'facturas') is distinct from 'array' or jsonb_array_length(d->'facturas') = 0 then
        v_falta := 'Falta decir qué factura paga este depósito.';
      else
        v_com := coalesce(fn_bandeja_num(d->>'comision'), 0);
        v_n := jsonb_array_length(d->'facturas');
        if v_com < 0 then
          v_falta := 'La comisión no puede ser negativa.';
        end if;
        for x in select value from jsonb_array_elements(d->'facturas') loop
          exit when v_falta is not null;
          v_id := case when jsonb_typeof(x) = 'object' then x->>'id' else x #>> '{}' end;
          select fc.id, fc.num, fc.proyecto_id, coalesce(fc.saldo_cxc, 0) as saldo, coalesce(fc.estado, 'emitida') as estado, p.nombre as obra
            into f
            from facturas_cobro fc
            left join proyectos p on p.id = fc.proyecto_id
           where fc.id = case when v_id ~ '^-?[0-9]{1,18}$' then v_id::bigint end;
          if not found then
            v_falta := 'Una de las facturas no existe en Proyectos.';
          elsif f.estado = 'anulada' then
            v_falta := format('La factura #%s está anulada.', f.num);
          elsif f.saldo <= 0 then
            v_falta := format('La factura #%s no tiene nada por cobrar en el libro: ya está cobrada allí, o todavía no ha entrado.', f.num);
          else
            v_m := coalesce(case when jsonb_typeof(x) = 'object' then fn_bandeja_num(x->>'monto') end,
                            case when v_n = 1 then m.monto + v_com else f.saldo end);
            if v_m <= 0 or v_m > f.saldo then
              v_falta := format('A la factura #%s le quedan %s por cobrar, y aquí le tocarían %s.', f.num, fn_bandeja_usd(f.saldo),
                                fn_bandeja_usd(v_m));
            else
              v_apps := v_apps || jsonb_build_object('id', f.id, 'num', f.num, 'obra', f.obra, 'proyecto_id', f.proyecto_id, 'monto', v_m);
              v_suma := v_suma + v_m;
              v_txt := v_txt || case when v_m < f.saldo
                                     then format('#%s de %s (%s de los %s que le quedan)', f.num, coalesce(f.obra, 'una obra'),
                                                 fn_bandeja_usd(v_m), fn_bandeja_usd(f.saldo))
                                     else format('#%s de %s (%s)', f.num, coalesce(f.obra, 'una obra'), fn_bandeja_usd(v_m)) end;
            end if;
          end if;
        end loop;
        if v_falta is null and (select count(distinct a->>'id') from jsonb_array_elements(v_apps) a) <> jsonb_array_length(v_apps) then
          v_falta := 'La misma factura está dos veces.';
        end if;
        if v_falta is null and v_suma - v_com <> m.monto then
          v_falta := format('Las facturas suman %s%s y el depósito es de %s: no cuadra.', fn_bandeja_usd(v_suma),
                            case when v_com > 0 then format(' (menos %s de comisión)', fn_bandeja_usd(v_com)) else '' end, v_usd);
        end if;
        o := jsonb_strip_nulls(jsonb_build_object('facturas', v_apps, 'comision', nullif(v_com, 0)));
        v_texto := case when v_n = 1 then format('Es el cobro de la factura %s.', v_txt[1])
                        else format('Es el cobro de %s facturas: %s.', v_n, array_to_string(v_txt, ', ')) end
                   || case when v_com > 0
                           then format(' Pagaron con tarjeta: el procesador se quedó %s de comisión y llegaron %s.',
                                       fn_bandeja_usd(v_com), v_usd)
                           else '' end;
      end if;
    when 'anticipo' then
      v_id := nullif(btrim(coalesce(d->>'proyecto_id', '')), '');
      select p.nombre into v_obra from proyectos p where p.id = v_id;
      if m.monto <= 0 then
        v_falta := 'Un anticipo es dinero que entra, y esto es dinero que salió.';
      elsif v_obra is null then
        v_falta := 'Falta decir de qué obra es el anticipo.';
        v_pide := true;
      else
        o := jsonb_build_object('proyecto_id', v_id);
      end if;
      v_texto := format('Es un anticipo de la obra %s (todavía sin factura): %s.', coalesce(v_obra, '(falta la obra)'), v_usd);
    when 'prestamo' then
      if m.monto <= 0 then
        v_falta := 'Un préstamo recibido es dinero que entra; la cuota de un préstamo tiene su propia opción.';
      else
        if coalesce(d->>'prestamo_id', '') ~ c_uuid then
          select p.prestamista, p.cuenta into v_nom, v_cta from prestamos p where p.id = (d->>'prestamo_id')::uuid;
          if v_nom is null then
            v_falta := 'Ese préstamo no está dado de alta.';
          else
            o := jsonb_build_object('prestamo_id', d->>'prestamo_id');
          end if;
        else
          v_nom := nullif(left(btrim(regexp_replace(coalesce(d->>'prestamista', ''), '\s+', ' ', 'g')), 80), '');
          v_cta := case when d->>'cuenta' in ('2510', '2520', '2540') then d->>'cuenta' else '2540' end;
          if v_nom is null then
            v_falta := 'Falta decir de quién es el préstamo.';
          end if;
        end if;
        if v_falta is null and not exists (select 1 from cuentas c where c.codigo = v_cta and c.imputable) then
          v_falta := 'La cuenta de ese préstamo no está en el plan de cuentas.';
        end if;
        o := o || jsonb_strip_nulls(jsonb_build_object('prestamista', v_nom, 'cuenta', v_cta));
        v_texto := format('Es dinero de un préstamo de %s: %s. Es una deuda, no el pago de un cliente.', coalesce(v_nom, '…'), v_usd);
      end if;
    when 'aporte' then
      if m.monto <= 0 then
        v_falta := 'Dinero tuyo a la empresa es dinero que entra, y esto es dinero que salió.';
      else
        v_cta := case when d->>'tipo' = 'aportacion' then '3100' else '2900' end;
        o := jsonb_build_object('tipo', case when v_cta = '3100' then 'aportacion' else 'prestamo_accionista' end, 'cuenta', v_cta);
        v_texto := case when v_cta = '3100' then format('Es dinero tuyo que aportas a la empresa: %s.', v_usd)
                        else format('Es dinero tuyo que le prestas a la empresa: %s (la empresa te lo debe).', v_usd) end;
      end if;
    when 'traspaso' then
      v_cta := nullif(btrim(coalesce(d->>'cuenta', '')), '');
      select c.nombre, exists (select 1 from tarjetas t where t.cuenta = c.codigo) into v_nom, v_tarj
        from cuentas c
       where c.codigo = v_cta and c.imputable and c.codigo <> m.cuenta
         and (c.codigo ~ '^10[0-9]{2}$' or exists (select 1 from tarjetas t where t.cuenta = c.codigo));
      if v_nom is null then
        v_falta := 'Falta decir con cuál de tus cuentas es el traspaso.';
      else
        o := jsonb_build_object('cuenta', v_cta);
        v_texto := case when v_tarj and m.monto < 0 then format('Es el pago de tu tarjeta %s: %s.', v_nom, v_usd)
                        when exists (select 1 from tarjetas t where t.cuenta = m.cuenta) and m.monto > 0
                          then format('Es el pago de esta tarjeta, hecho desde %s: %s.', v_nom, v_usd)
                        when m.monto < 0 then format('Es un traspaso a tu cuenta %s: %s.', v_nom, v_usd)
                        else format('Es un traspaso desde tu cuenta %s: %s.', v_nom, v_usd) end;
      end if;
    when 'cuadrilla' then
      if m.monto >= 0 then
        v_falta := 'El pago a la cuadrilla es dinero que sale, y esto es dinero que entró.';
      elsif to_regprocedure('public.fn_jornal_pago(jsonb)') is null then
        v_falta := 'El reparto de la mano de obra por horas todavía no está instalado.';
      else
        if coalesce(d->>'usuario_id', '') ~ c_uuid then
          select p.nombre into v_nom from perfiles p where p.id = (d->>'usuario_id')::uuid and p.rol <> 'dueno';
        end if;
        if v_nom is null then
          v_falta := 'Falta decir a quién de la cuadrilla se le pagó.';
        else
          o := jsonb_build_object('usuario_id', d->>'usuario_id');
          v_texto := format('Es el pago a %s, de la cuadrilla: %s. Se reparte entre las obras según sus horas.', v_nom, v_usd);
        end if;
      end if;
    when 'contratista' then
      v_id := nullif(btrim(coalesce(d->>'proyecto_id', '')), '');
      select p.nombre into v_obra from proyectos p where p.id = v_id;
      if coalesce(d->>'proveedor_id', '') ~ c_uuid then
        select p.nombre into v_nom from proveedores p where p.id = (d->>'proveedor_id')::uuid;
      end if;
      if m.monto >= 0 then
        v_falta := 'El pago a un subcontratista es dinero que sale, y esto es dinero que entró.';
      elsif v_obra is null then
        v_falta := 'Falta decir de qué obra es el pago al subcontratista.';
        v_pide := true;
      end if;
      o := jsonb_strip_nulls(jsonb_build_object('cuenta', '5200', 'proyecto_id', case when v_obra is not null then v_id end,
                                                'proveedor_id', case when v_nom is not null then d->>'proveedor_id' end));
      v_texto := format('Es el pago a un subcontratista%s por la obra %s: %s.', coalesce(' (' || v_nom || ')', ''),
                        coalesce(v_obra, '(falta la obra)'), v_usd);
    when 'otro_ingreso' then
      if m.monto <= 0 then
        v_falta := 'Un ingreso es dinero que entra, y esto es dinero que salió.';
      else
        v_cta := case when d->>'cuenta' = '4910' then '4910' else '4900' end;
        o := jsonb_build_object('cuenta', v_cta);
        v_texto := format('Es %s: %s. No es el pago de una factura.',
                          case when v_cta = '4910' then 'intereses que te paga el banco' else 'otro ingreso (un reembolso, una recompensa)' end, v_usd);
      end if;
    when 'banco' then
      v_i := case when coalesce(d->>'opcion', '') ~ '^[0-9]{1,2}$' then (d->>'opcion')::int end;
      v_op := case when v_i is not null and jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones'->v_i end;
      if v_op is null or jsonb_typeof(v_op) <> 'object' then
        v_falta := 'Esa opción ya no está entre las que el banco propone para este movimiento.';
      elsif not (coalesce(v_op->>'llamar', '') = any (fn_bandeja_puertas())) then
        v_falta := 'Esa opción se contesta en «Más opciones».';
      else
        o := jsonb_strip_nulls(jsonb_build_object(
               'opcion', v_i, 'llamar', v_op->>'llamar', 'pide', nullif(to_jsonb(fn_bandeja_opcion_pide(v_op)), '[]'::jsonb),
               'campos', case when jsonb_typeof(d->'campos') = 'object' then d->'campos' end));
        v_texto := fn_bandeja_opcion_texto(v_op, m.monto);
      end if;
    else
      raise exception using errcode = '22023',
        message = format('«%s» no está en la lista de lo que la Bandeja sabe registrar.', coalesce(p_accion, ''));
  end case;
  return jsonb_strip_nulls(jsonb_build_object(
    'ok', v_falta is null, 'accion', p_accion, 'datos', o, 'texto', v_texto, 'falta', v_falta, 'pide_obra', case when v_pide then true end));
end $$;
revoke execute on function public.fn_bandeja_validar(uuid, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_validar(uuid, text, jsonb) to authenticated;
comment on function public.fn_bandeja_validar(uuid, text, jsonb) is 'c17: valida una acción de la lista cerrada para un movimiento pendiente contra las cuentas, las obras, las facturas y los montos de la base: {ok, accion, datos, texto llano, falta, pide_obra}. No escribe nada. Otra acción, 22023.';


-- ---------------------------------------------------------------------
-- 9. RECORDAR lo que Edgar dijo de una contraparte (bandeja_memoria).
-- ---------------------------------------------------------------------
-- La plantilla de una acción ya validada: lo que vale para el próximo
-- movimiento de esa contraparte. Nunca una obra fija ni una factura: un
-- gasto de obra guarda «obra: dia» (la del día de la cuadrilla, o se
-- pregunta); un cobro o un anticipo guardan la obra del cliente (para
-- buscar SUS facturas la próxima vez).
create or replace function public.fn_bandeja_recordar(p_movimiento uuid, p_accion text, p_datos jsonb, p_solo boolean, p_origen text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  m       movimientos_banco;
  c       jsonb;
  t       jsonb;
  v_txt   text;
  v_solo  boolean;
  v_pid   text;
  r       bandeja_memoria;
begin
  v_quien := fn_bandeja_quien();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    return null;
  end if;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  if not (c ? 'clave') or (c->>'clase') not in ('comercio', 'zelle_a', 'zelle_de', 'deposito', 'procesador')
     or p_accion not in ('gasto', 'personal', 'cobro', 'anticipo', 'prestamo', 'aporte', 'traspaso', 'cuadrilla', 'contratista', 'otro_ingreso') then
    return null;   -- no dice quién (un cheque, el cajero) o no es algo que se recuerde (una opción de c6)
  end if;
  case p_accion
    when 'gasto' then
      t := jsonb_strip_nulls(jsonb_build_object(
             'cuenta', p_datos->>'cuenta',
             'obra', case when (select k.regla_obra from cuentas k where k.codigo = p_datos->>'cuenta') = 'obligatoria' then 'dia' end));
      v_txt := format('%s → %s%s', c->>'nombre', fn_bandeja_cuenta_llana(p_datos->>'cuenta'),
                      case when t ? 'obra' then ' (la obra, la del día de la cuadrilla; si no, te la pregunto)' else '' end);
    when 'personal' then
      t := '{}'::jsonb;
      v_txt := format('%s → es tuyo, no de la empresa', c->>'nombre');
    when 'cobro', 'anticipo' then
      select min(x->>'proyecto_id') into v_pid from jsonb_array_elements(coalesce(p_datos->'facturas', '[]'::jsonb)) x
      having count(distinct x->>'proyecto_id') = 1;
      v_pid := coalesce(p_datos->>'proyecto_id', v_pid);
      if v_pid is null then
        return null;   -- cobró facturas de varias obras: no hay un cliente que recordar
      end if;
      t := jsonb_build_object('proyecto_id', v_pid);
      v_txt := format('%s → paga la obra %s', c->>'nombre', coalesce((select p.nombre from proyectos p where p.id = v_pid), v_pid));
      p_accion := 'cobro';
    when 'prestamo' then
      t := jsonb_strip_nulls(jsonb_build_object('prestamo_id', p_datos->>'prestamo_id', 'prestamista', p_datos->>'prestamista',
                                                'cuenta', p_datos->>'cuenta'));
      v_txt := format('%s → dinero de un préstamo (%s)', c->>'nombre', coalesce(p_datos->>'prestamista', 'un prestamista'));
    when 'aporte' then
      t := jsonb_build_object('tipo', p_datos->>'tipo');
      v_txt := format('%s → dinero tuyo a la empresa', c->>'nombre');
    when 'traspaso' then
      t := jsonb_build_object('cuenta', p_datos->>'cuenta');
      v_txt := format('%s → entre tus cuentas (%s)', c->>'nombre', coalesce((select k.nombre from cuentas k where k.codigo = p_datos->>'cuenta'), ''));
    when 'cuadrilla' then
      t := jsonb_build_object('usuario_id', p_datos->>'usuario_id');
      v_txt := format('%s → pago a la cuadrilla', c->>'nombre');
    when 'contratista' then
      t := jsonb_strip_nulls(jsonb_build_object('proveedor_id', p_datos->>'proveedor_id'));
      v_txt := format('%s → pago a un subcontratista (te pregunto la obra)', c->>'nombre');
    else
      t := jsonb_build_object('cuenta', p_datos->>'cuenta');
      v_txt := format('%s → otros ingresos', c->>'nombre');
  end case;
  v_solo := coalesce(p_solo, false) and c->>'clase' = 'comercio' and p_accion in ('gasto', 'personal');
  perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
  insert into bandeja_memoria as bm (clave, nombre, clase, accion, datos, texto, solo, activa, origen, creada_por)
  values (c->>'clave', c->>'nombre', c->>'clase', p_accion, t, v_txt, v_solo, true,
          case when p_origen in ('grupo', 'dimelo') then p_origen else 'tarjeta' end, v_quien)
  on conflict (clave) do update
     set accion = excluded.accion, datos = excluded.datos, texto = excluded.texto, nombre = excluded.nombre, clase = excluded.clase,
         -- (lo que ya entraba solo sigue entrando solo si la acción es la misma; si cambia, hay que volver a decirlo)
         solo = excluded.solo or (bm.solo and bm.accion = excluded.accion and bm.datos = excluded.datos and p_solo is null),
         activa = true, origen = excluded.origen, cambiada_por = v_quien, cambiada_el = now()
  returning * into r;
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_build_object('clave', r.clave, 'nombre', r.nombre, 'texto', r.texto, 'solo', r.solo);
end $$;
revoke execute on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) to authenticated;
comment on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) is 'c17: guarda en bandeja_memoria lo que Edgar dijo de la contraparte de ese movimiento (la plantilla de la acción, sin obra fija ni factura); «solo» únicamente para un comercio con gasto o personal. Nulo si la contraparte no dice quién o la acción no se recuerda.';

-- Lo que Edgar cambia de lo recordado: {clave, activa} (darlo de baja o de
-- alta otra vez) y/o {clave, solo} (que entre solo, o que deje de entrar).
create or replace function public.fn_bandeja_memoria(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  r       bandeja_memoria;
begin
  v_quien := fn_bandeja_quien();
  select * into r from bandeja_memoria where clave = p->>'clave';
  if not found then
    raise exception using errcode = '22023', message = 'Eso no está entre lo que la Bandeja recuerda.';
  end if;
  if p ? 'solo' and (p->>'solo')::boolean and not (r.clase = 'comercio' and r.accion in ('gasto', 'personal')) then
    raise exception using errcode = 'MX008',
      message = 'Solo los cargos de un comercio (un gasto o algo personal) pueden entrar solos: un depósito, un Zelle o un préstamo siempre se te preguntan.';
  end if;
  perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
  update bandeja_memoria
     set activa = coalesce((p->>'activa')::boolean, activa),
         solo = coalesce((p->>'solo')::boolean, solo) and coalesce((p->>'activa')::boolean, activa),
         cambiada_por = v_quien, cambiada_el = now()
   where clave = r.clave
  returning * into r;
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_build_object('clave', r.clave, 'nombre', r.nombre, 'texto', r.texto, 'solo', r.solo, 'activa', r.activa);
end $$;
revoke execute on function public.fn_bandeja_memoria(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_memoria(jsonb) to authenticated;
comment on function public.fn_bandeja_memoria(jsonb) is 'c17: cambia lo recordado de una contraparte: {clave, activa} (baja o alta) y/o {clave, solo} (que entre solo o no; solo un comercio con gasto o personal: si no, MX008).';

-- La configuración: {solo: true|false} (lo de «entra solo»), {solo_tope:
-- "500.00"} y {dimelo: true|false}. Queda escrito quién encendió lo de solo.
create or replace function public.fn_bandeja_config(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  v_tope  numeric;
  r       bandeja_config;
begin
  v_quien := fn_bandeja_quien();
  if p ? 'solo_tope' then
    v_tope := fn_bandeja_num(p->>'solo_tope');
    if v_tope is null or v_tope < 0 or v_tope > 5000 then
      raise exception using errcode = '22023', message = 'El tope de lo que entra solo es un monto entre 0 y 5,000.00.';
    end if;
  end if;
  perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
  update bandeja_config
     set solo = coalesce((p->>'solo')::boolean, solo),
         solo_por = case when (p->>'solo')::boolean then v_quien else solo_por end,
         solo_el = case when (p->>'solo')::boolean then now() else solo_el end,
         solo_tope = coalesce(v_tope, solo_tope),
         dimelo = coalesce((p->>'dimelo')::boolean, dimelo),
         actualizado = now(), actualizado_por = v_quien
   where id = 1
  returning * into r;
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_build_object('solo', r.solo, 'solo_tope', r.solo_tope, 'dimelo', r.dimelo);
end $$;
revoke execute on function public.fn_bandeja_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_config(jsonb) to authenticated;
comment on function public.fn_bandeja_config(jsonb) is 'c17: cambia la configuración de la Bandeja nueva: {solo}, {solo_tope}, {dimelo}. Solo el dueño, con su sesión.';


-- ---------------------------------------------------------------------
-- 10. «ASÍ ES»: REGISTRAR una acción de la lista cerrada. Es la única
--     función de esta capa que hace que algo entre al libro, y no escribe
--     en él: valida (fn_bandeja_validar) y llama a la puerta de c6 (o de
--     c10) que corresponde, con las guardas de esa puerta. Devuelve SIEMPRE
--     un resultado (no lanza por lo que la puerta rechace):
--       {hecho: true, hecho_id, estado, asiento, texto, facturas_cobradas,
--        recordado, propuestas_ia}
--       {hecho: false, por_que, pide_motivo?, pide_obra?, campos?}
--     y nada queda a medias: lo que la puerta rechaza se deshace entero.
--     p_opciones: {fuente (recomendacion | dimelo | grupo | solo | mas),
--     motivo (lo que Edgar escribió), recordar, solo, dimelo_id, corrio}.
--
--     EL MOTIVO. c6 pide el motivo escrito cuando algo puede estar dos
--     veces en el libro o va al patrimonio. Aquí NO se le inventa uno para
--     saltarse ese freno: se pasa el que Edgar escribió (o su frase del
--     «Dímelo», que es exactamente eso); si falta y la puerta lo pide, se
--     devuelve pide_motivo con lo que dijo la puerta, en llano. Dos acciones
--     llevan el suyo porque SON la respuesta («es mío», «es un préstamo»),
--     y solo cuando c6 no tenía otra explicación para el movimiento, o
--     cuando el banco mismo nombra al prestamista.
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_hacer(p_movimiento uuid, p_accion text, p_datos jsonb default '{}'::jsonb,
                                                   p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien  uuid;
  op       jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  v_fuente text;
  v_motivo text;
  v_corrio text;
  m        movimientos_banco;
  v        jsonb;
  d        jsonb;
  c        jsonb;
  x        jsonb;
  v_res    jsonb;
  v_args   jsonb;
  v_sql    text;
  v_fn     text;
  v_mot    text;
  v_libre  boolean;
  v_err    text;
  v_hecho  uuid := gen_random_uuid();
  v_marc   jsonb := '[]'::jsonb;
  v_ia     jsonb;
  v_mem    jsonb;
  v_nota   text;
  v_num    text;
  p        text;
begin
  v_quien := fn_bandeja_quien();
  v_fuente := coalesce(nullif(op->>'fuente', ''), 'recomendacion');
  v_motivo := nullif(btrim(regexp_replace(coalesce(op->>'motivo', ''), '\s+', ' ', 'g')), '');
  v_corrio := case when op->>'corrio' = 'rutina' then 'rutina' else 'pantalla' end;
  if p_movimiento is null then
    raise exception using errcode = '22023', message = 'Falta el movimiento.';
  end if;
  if v_fuente not in ('recomendacion', 'dimelo', 'grupo', 'solo', 'mas') then
    raise exception using errcode = '22023', message = 'La fuente no es una de las de la Bandeja.';
  end if;
  perform pg_advisory_xact_lock(820261121, hashtext('bandeja:' || p_movimiento::text));
  v := fn_bandeja_validar(p_movimiento, p_accion, p_datos);
  if not coalesce((v->>'ok')::boolean, false) then
    return jsonb_strip_nulls(jsonb_build_object('hecho', false, 'movimiento_id', p_movimiento, 'por_que', v->>'falta',
                                                'pide_obra', v->'pide_obra'));
  end if;
  d := v->'datos';
  select * into m from movimientos_banco where id = p_movimiento;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  -- ¿c6 no tenía otra explicación para este movimiento?
  v_libre := coalesce(m.propuesta->>'motivo', 'sin_propuesta') in ('sin_ticket', 'clasificar', 'dudosa', 'sin_propuesta', 'deposito_sin_factura')
             and not (m.posible_duplicado_de is not null and m.duplicado is null);
  -- LO QUE ENTRA SOLO se comprueba aquí otra vez, entero (la rutina ya lo
  -- filtró): la etiqueta «solo» de un registro tiene que ser verdad.
  if v_fuente = 'solo' then
    if not (m.monto < 0 and c->>'clase' = 'comercio' and p_accion in ('gasto', 'personal') and v_libre
            and m.posible_duplicado_de is null
            and coalesce((select g.solo and abs(m.monto) <= g.solo_tope from bandeja_config g where g.id = 1), false)
            and exists (select 1 from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa and bm.solo and bm.accion = p_accion)
            and not exists (select 1 from bandeja_hechos h where h.movimiento_id = m.id and h.deshecho_el is not null)) then
      return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'por_que', 'Esto no puede entrar solo: se te pregunta.');
    end if;
    v_motivo := null;   -- lo que entra solo no lleva un motivo escrito por nadie: si la puerta lo pide, no entra
  end if;
  begin
    case p_accion
      when 'gasto' then
        v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                   'cuenta', d->>'cuenta', 'proyecto_id', d->>'proyecto_id'))), v_motivo);
      when 'personal' then
        v_mot := coalesce(v_motivo, case when v_libre then format('Gasto personal de Edgar pagado desde la empresa (%s): %s', c->>'nombre',
                                                                  case when v_fuente = 'solo' then 'regla suya en la Bandeja (entró solo)'
                                                                       else 'lo dijo en la Bandeja' end) end);
        if v_mot is null then
          return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'pide_motivo', true,
                   'por_que', 'Para este movimiento el banco tenía otra explicación: ' || coalesce(fn_bandeja_llano(m.propuesta->>'texto'), '')
                              || ' Si de verdad es tuyo, escribe por qué.');
        end if;
        v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', '3200')), v_mot);
      when 'cobro' then
        select jsonb_agg(jsonb_build_object('factura_id', (a->>'id')::bigint, 'monto', a->>'monto') order by n) into v_args
          from jsonb_array_elements(d->'facturas') with ordinality as t(a, n);
        if d ? 'comision' then
          v_args := v_args || jsonb_build_array(jsonb_build_object('comision', d->>'comision'));
        end if;
        v_res := fn_banco_cobrar(m.id, v_args, v_motivo);
      when 'anticipo' then
        v_res := fn_banco_cobrar(m.id, jsonb_build_array(jsonb_build_object('proyecto_id', d->>'proyecto_id', 'monto', m.monto::text)),
                                 v_motivo);
      when 'prestamo' then
        v_mot := coalesce(v_motivo,
                          case when v_libre or fn_bandeja_prestamista(m.desc_norm) is not null
                               then format('Desembolso de un préstamo de %s: es deuda, no el cobro de un cliente (Edgar lo confirmó en la Bandeja)',
                                           d->>'prestamista') end);
        if v_mot is null then
          return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'pide_motivo', true,
                   'por_que', 'Para este depósito el banco tenía otra explicación: ' || coalesce(fn_bandeja_llano(m.propuesta->>'texto'), '')
                              || ' Si de verdad es un préstamo, escribe de quién y por qué.');
        end if;
        v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', d->>'cuenta')), v_mot);
      when 'aporte', 'otro_ingreso' then
        if v_motivo is null then
          return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'pide_motivo', true,
                   'por_que', case when p_accion = 'aporte'
                                   then 'Escribe en una línea de dónde salió ese dinero tuyo (queda escrito en el libro).'
                                   else 'Escribe en una línea de qué es ese ingreso (queda escrito en el libro).' end);
        end if;
        v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', d->>'cuenta')), v_motivo);
      when 'traspaso' then
        v_res := fn_banco_transferencia(m.id, d->>'cuenta', v_motivo);
      when 'cuadrilla' then
        execute 'select public.fn_jornal_pago($1)'
          using jsonb_build_object('movimiento_id', m.id, 'usuario_id', d->>'usuario_id') into v_res;
      when 'contratista' then
        v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                   'cuenta', '5200', 'proyecto_id', d->>'proyecto_id',
                   'tercero_tipo', case when d ? 'proveedor_id' then 'proveedor' end, 'tercero_id', d->>'proveedor_id'))), v_motivo);
      when 'banco' then
        x := m.propuesta->'opciones'->((d->>'opcion')::int);
        v_fn := x->>'llamar';
        v_args := coalesce(x->'args', '{}'::jsonb) || jsonb_build_object('p_movimiento', m.id);
        foreach p in array fn_bandeja_opcion_pide(x) loop
          if p in ('p_motivo', 'p_notas', 'p_partidas.motivo') then
            if v_motivo is null then
              return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'pide_motivo', true,
                                        'por_que', 'Esto pide que escribas por qué (queda escrito en el libro).');
            end if;
            if p = 'p_partidas.motivo' then
              v_args := v_args || jsonb_build_object('p_partidas', jsonb_build_object(
                          'motivo', v_motivo,
                          'partidas', case when jsonb_typeof(v_args->'p_partidas') = 'array' then v_args->'p_partidas'
                                           else v_args->'p_partidas'->'partidas' end));
            else
              v_args := v_args || jsonb_build_object(p, v_motivo);
            end if;
          else
            if nullif(btrim(coalesce(d->'campos'->>p, '')), '') is null then
              return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'campos', to_jsonb(fn_bandeja_opcion_pide(x)),
                                        'por_que', 'Falta un dato que el banco pide para registrarlo.');
            end if;
            v_args := v_args || jsonb_build_object(p, btrim(d->'campos'->>p));
          end if;
        end loop;
        -- el motivo que Edgar escribió después de un freno de la puerta
        if v_motivo is not null then
          p := case v_fn when 'fn_banco_cobrar' then 'p_notas' when 'fn_banco_pagar_proveedor' then null else 'p_motivo' end;
          if p is not null and not (v_args ? p) then
            v_args := v_args || jsonb_build_object(p, v_motivo);
          end if;
        end if;
        select format('select public.%I(%s)', pr.proname,
                      string_agg(format('%I => %s', a.nombre,
                                        case when a.tipo = 'jsonb'::regtype::oid then format('($1->%L)', a.nombre)
                                             else format('($1->>%L)::%s', a.nombre, a.tipo::regtype) end), ', ' order by a.i))
          into v_sql
          from pg_proc pr
          cross join lateral (select n.nombre, t.tipo, n.i
                                from unnest(pr.proargnames) with ordinality as n(nombre, i)
                                join unnest(pr.proargtypes::oid[]) with ordinality as t(tipo, i) using (i)) a
         where pr.pronamespace = 'public'::regnamespace and pr.proname = v_fn and v_fn = any (fn_bandeja_puertas())
           and v_args ? a.nombre
         group by pr.oid, pr.proname
         limit 1;
        if v_sql is null then
          return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'por_que', 'Esa opción se contesta en «Más opciones».');
        end if;
        execute v_sql using v_args into v_res;
    end case;
  exception when others then
    -- Lo que la puerta rechaza por sus reglas se devuelve en llano y nada
    -- queda a medias; un error que no es de sus reglas se vuelve a lanzar.
    if sqlstate !~ '^MX' and sqlstate not in ('22023', '22007', '23514') then
      raise;
    end if;
    v_err := sqlerrm;
    return jsonb_strip_nulls(jsonb_build_object(
      'hecho', false, 'movimiento_id', p_movimiento, 'codigo', sqlstate,
      'pide_motivo', case when v_motivo is null and v_err ~* 'motivo' then true end,
      'por_que', coalesce(fn_bandeja_llano(v_err), 'El banco no lo aceptó.')));
  end;
  select * into m from movimientos_banco where id = p_movimiento;
  if m.estado = 'pendiente' then
    -- la puerta no lo registró y lo dice (el pago a la cuadrilla que pide decidir algo)
    return jsonb_strip_nulls(jsonb_build_object(
      'hecho', false, 'movimiento_id', m.id, 'dicho', case when p_accion = 'cuadrilla' then true end,
      'por_que', coalesce(v_res->>'por_que', v_res->>'nota', 'No se registró: sigue en la Bandeja.')));
  end if;
  -- UNA SOLA APP: la factura que quedó sin saldo en el libro queda cobrada
  -- también en Proyectos (si no lo estaba). Si no se puede, el cobro vale
  -- igual y se dice.
  if p_accion = 'cobro' then
    begin
      for x in select value from jsonb_array_elements(d->'facturas') loop
        if exists (select 1 from facturas_cobro fc where fc.id = (x->>'id')::bigint and coalesce(fc.saldo_libro, 0) <= 0)
           and exists (select 1 from facturas f where f.id = (x->>'id')::bigint and not coalesce(f.pagada, false)) then
          update facturas
             set pagada = true,
                 cobrada_el = coalesce(cobrada_el, (m.fecha + time '12:00') at time zone 'America/New_York')
           where id = (x->>'id')::bigint;
          v_marc := v_marc || jsonb_build_object('id', (x->>'id')::bigint, 'num', x->>'num');
        end if;
      end loop;
    exception when others then
      v_marc := '[]'::jsonb;
      v_nota := 'El cobro quedó registrado, pero no pude marcar la factura como cobrada en Proyectos: márcala allí.';
    end;
  end if;
  select a.numero into v_num from asientos a where a.id = m.asiento_id;
  perform set_config('mx_bandeja.escribe', 'bandeja_hechos', true);
  insert into bandeja_hechos (id, movimiento_id, accion, datos, texto, fuente, solo, memoria_clave, dimelo_id, monto, asiento_id, corrio, por)
  values (v_hecho, m.id, p_accion, d || case when jsonb_array_length(v_marc) > 0 then jsonb_build_object('marcadas', v_marc) else '{}'::jsonb end,
          v->>'texto', v_fuente, v_fuente = 'solo', c->>'clave',
          case when coalesce(op->>'dimelo_id', '') ~ '^[0-9a-fA-F-]{36}$' then (op->>'dimelo_id')::uuid end,
          m.monto, m.asiento_id, v_corrio, v_quien);
  perform set_config('mx_bandeja.escribe', '', true);
  -- lo recordado: se guarda si Edgar lo pidió, y se cuenta si ya estaba
  if coalesce((op->>'recordar')::boolean, false) then
    v_mem := fn_bandeja_recordar(m.id, p_accion, d, case when op ? 'solo' then (op->>'solo')::boolean end, v_fuente);
  end if;
  if c ? 'clave' then
    perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
    update bandeja_memoria set veces = veces + 1, ultima_vez = now() where clave = c->>'clave' and activa and accion = p_accion;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  -- lo de la IA de c8 que este registro deja abierto: lo cierra la pantalla
  -- por la función de borde, o la tarea por la puerta de c8
  select jsonb_agg(q.id order by q.creado_el) into v_ia
    from contador_propuestas q where q.movimiento_id = m.id and q.estado = 'pendiente';
  return jsonb_strip_nulls(jsonb_build_object(
    'hecho', true, 'hecho_id', v_hecho, 'movimiento_id', m.id, 'estado', m.estado, 'asiento_id', m.asiento_id, 'asiento', v_num,
    'texto', v->>'texto', 'monto', m.monto, 'facturas_cobradas', nullif(v_marc, '[]'::jsonb), 'recordado', v_mem,
    'propuestas_ia', v_ia, 'nota', v_nota));
end $$;
revoke execute on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) to authenticated;
comment on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) is 'c17: «Así es»: valida una acción de la lista cerrada y la registra por la puerta de c6 (o de c10) que corresponde, con las guardas de esa puerta. Devuelve {hecho: true, …} o {hecho: false, por_que, pide_motivo, pide_obra, campos}; nada queda a medias. Deja el rastro en bandeja_hechos y, al cobrar, marca la factura cobrada en Proyectos.';

-- DESHACER algo que la Bandeja registró (lo que entró solo, o un «Así es»
-- equivocado), con su motivo: se des-casa por la puerta de c6 (su asiento
-- se reversa y el movimiento vuelve a la Bandeja), la factura que esta capa
-- marcó cobrada en Proyectos se desmarca, y lo deshecho NO vuelve a entrar
-- solo. Un cobro o un anticipo, además, se anula por la puerta de c3 (la
-- factura vuelve a quedar por cobrar). Si el movimiento ya no está como lo
-- dejó este registro (alguien lo des-casó por otro lado), solo se marca.
create or replace function public.fn_bandeja_deshacer(p_hecho uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  h       bandeja_hechos;
  m       movimientos_banco;
  v_res   jsonb;
  x       jsonb;
  v_cobro uuid;
  v_mot   text := nullif(btrim(regexp_replace(coalesce(p_motivo, ''), '\s+', ' ', 'g')), '');
begin
  v_quien := fn_bandeja_quien();
  if v_mot is null or length(v_mot) < 3 then
    raise exception using errcode = '22023', message = 'Deshacer dice por qué (queda escrito).';
  end if;
  select * into h from bandeja_hechos where id = p_hecho;
  if not found then
    raise exception using errcode = '22023', message = 'Eso no está entre lo que la Bandeja registró.';
  end if;
  perform pg_advisory_xact_lock(820261121, hashtext('bandeja:' || h.movimiento_id::text));
  select * into h from bandeja_hechos where id = p_hecho;
  if h.deshecho_el is not null then
    raise exception using errcode = 'MX008', message = 'Eso ya estaba deshecho.';
  end if;
  select * into m from movimientos_banco where id = h.movimiento_id;
  if found and m.estado <> 'pendiente' and m.asiento_id is not distinct from h.asiento_id then
    v_cobro := case when m.casado_clase = 'cobro' and coalesce(m.casado_ref, '') ~ '^[0-9a-fA-F-]{36}$' then m.casado_ref::uuid end;
    v_res := fn_banco_descasar(m.id, v_mot);
    -- un cobro o un anticipo: des-casar suelta el depósito pero deja el cobro anotado; se anula (la factura vuelve a
    -- quedar por cobrar) y c6 vuelve a proponer para el depósito
    if h.accion in ('cobro', 'anticipo') and v_cobro is not null
       and exists (select 1 from cobros k where k.id = v_cobro and k.estado = 'vigente') then
      perform fn_cobro_anular(v_cobro, v_mot);
      perform fn_banco_casar(m.id);
    end if;
    if h.accion = 'cobro' then
      for x in select value from jsonb_array_elements(coalesce(h.datos->'marcadas', '[]'::jsonb)) loop
        update facturas set pagada = false, cobrada_el = null
         where id = (x->>'id')::bigint and coalesce(pagada, false)
           and exists (select 1 from facturas_cobro fc where fc.id = facturas.id and coalesce(fc.saldo_libro, 0) > 0);
      end loop;
    end if;
  end if;
  perform set_config('mx_bandeja.escribe', 'bandeja_hechos', true);
  update bandeja_hechos set deshecho_el = now(), deshecho_por = v_quien, deshecho_motivo = v_mot where id = h.id;
  perform set_config('mx_bandeja.escribe', '', true);
  select * into m from movimientos_banco where id = h.movimiento_id;
  return jsonb_strip_nulls(jsonb_build_object('deshecho', true, 'hecho_id', h.id, 'movimiento_id', h.movimiento_id, 'estado', m.estado,
                                              'banco', v_res));
end $$;
revoke execute on function public.fn_bandeja_deshacer(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_deshacer(uuid, text) to authenticated;
comment on function public.fn_bandeja_deshacer(uuid, text) is 'c17: deshace, con su motivo, algo que la Bandeja registró: lo des-casa por c6 (su asiento se reversa y vuelve a la Bandeja), desmarca la factura que esta capa marcó cobrada y lo deja marcado: lo deshecho no vuelve a entrar solo.';


-- ---------------------------------------------------------------------
-- 11. LA RECOMENDACIÓN: UNA sola, o ninguna. Por orden: lo que el banco
--     mismo dice que es un préstamo; lo que c6 ya sabe con certeza (un
--     traspaso, los intereses, la cuota de un préstamo); lo que Edgar ya
--     dijo de esa contraparte (la memoria); las facturas que explican el
--     depósito (primero las marcadas cobradas en Proyectos); la propuesta
--     pendiente de la IA de c8; y lo que sugiere el nombre del comercio.
--     Devuelve {accion, datos, texto, porque, fuente (banco | app | memoria
--     | ia | nombre), pide_obra, pide_motivo, pide} o {aviso} (nada que
--     tocar aquí: se contesta en otra parte o en «Más opciones») o nulo
--     (no se sabe: «Dímelo»). No escribe nada.
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_recomendar(p_movimiento uuid, p_ctx jsonb default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  mem     bandeja_memoria;
  q       record;
  c       jsonb;
  ops     jsonb;
  v_fact  jsonb;
  cb      jsonb;
  pr      jsonb;
  ob      jsonb;
  sg      jsonb;
  v       jsonb;
  v_mot   text;
  v_acc   text;
  v_dat   jsonb := '{}'::jsonb;
  v_por   text;
  v_fte   text;
  v_dia   date;
  v_proc  boolean;
  v_n     int;
  v_cta   text;
  v_obra  boolean;
begin
  perform fn_bandeja_exigir_dueno();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found or m.estado <> 'pendiente' then
    return null;
  end if;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  v_mot := coalesce(m.propuesta->>'motivo', 'sin_propuesta');
  ops := case when jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones' else '[]'::jsonb end;
  v_n := jsonb_array_length(ops);
  v_dia := coalesce(m.fecha_transaccion, m.fecha);
  v_proc := c->>'clase' = 'procesador';
  -- Lo que se contesta en otra parte, o en «Más opciones»: se dice en llano.
  if m.posible_duplicado_de is not null and m.duplicado is null then
    return jsonb_build_object('fuente', 'banco',
      'aviso', 'Se parece a otro movimiento que ya está. Dime primero si es el mismo o es otro: está en «Más opciones».');
  end if;
  if v_mot in ('nomina', 'ticket_en_bandeja', 'otro_total', 'llego_su_ticket', 'quitada', 'devolucion', 'partida_apertura', 'partidas')
     or (v_mot = 'varios_candidatos' and v_n <> 1) then
    return jsonb_build_object('fuente', 'banco', 'aviso', case v_mot
      when 'nomina' then 'Es de la nómina (Gusto): se casa desde Contabilidad → Nómina, no aquí.'
      when 'ticket_en_bandeja' then 'Ya subiste el recibo de esta compra, pero le falta un dato para entrar al libro. Cuando lo termines, este cargo se casa solo con él y con su obra.'
      when 'otro_total' then 'Hay un recibo que se le parece, pero con otro total. Corrige el total del recibo en la app y este cargo se casa solo con él.'
      when 'llego_su_ticket' then 'El recibo de este cargo llegó después de registrarlo. Cámbialo por su recibo en «Más opciones».'
      when 'quitada' then 'El banco quitó este movimiento. Mira qué hacer con él en «Más opciones».'
      when 'devolucion' then 'Parece un cheque o un depósito que el banco devolvió. Dime de cuál es en «Más opciones».'
      when 'varios_candidatos' then 'Coincide con varias cosas que ya están en el libro. Elige cuál en «Más opciones».'
      else 'Puede ser algo que venía de QuickBooks, de antes del 1 de octubre. Míralo en «Más opciones».' end);
  end if;
  select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa;
  if m.monto > 0 then
    pr := fn_bandeja_prestamista(m.desc_norm);
    if pr is not null then
      -- UN PRÉSTAMO NO ES UN COBRO: antes que cualquier factura
      v_acc := 'prestamo'; v_dat := pr - 'conocido'; v_fte := 'app';
      v_por := format('El banco dice que lo deposita %s, un prestamista%s.', pr->>'prestamista',
                      case when (pr->>'conocido')::boolean then ' que ya tienes dado de alta' else '' end);
    elsif v_mot in ('transferencia_otro_lado', 'transferencia_un_lado', 'abono_tarjeta', 'interes', 'cobro_que_lo_nombra', 'otro_lado_clasificado')
          and v_n >= 1 then
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif mem.clave is not null then
      v_fte := 'memoria'; v_por := 'Ya me lo dijiste antes: ' || mem.texto || '.';
      if mem.accion = 'cobro' then
        v_fact := coalesce(p_ctx->'facturas', fn_bandeja_facturas());
        cb := fn_bandeja_cobro_de((select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(v_fact) x
                                    where x->>'proyecto_id' = mem.datos->>'proyecto_id'), m.monto, m.fecha, v_proc);
        if not (coalesce(cb, '{}'::jsonb) ? 'facturas') then
          cb := fn_bandeja_cobro_de(v_fact, m.monto, m.fecha, v_proc);
        end if;
        if coalesce(cb, '{}'::jsonb) ? 'facturas' then
          v_acc := 'cobro'; v_dat := jsonb_strip_nulls(jsonb_build_object('facturas', cb->'facturas', 'comision', cb->'comision'));
        else
          v_acc := 'anticipo'; v_dat := jsonb_build_object('proyecto_id', mem.datos->>'proyecto_id');
          v_por := v_por || ' No hay una factura suya con ese saldo: entra como anticipo de esa obra.';
        end if;
      else
        v_acc := mem.accion; v_dat := mem.datos;
      end if;
    elsif c->>'clase' <> 'cajero' then
      v_fact := coalesce(p_ctx->'facturas', fn_bandeja_facturas());
      cb := fn_bandeja_cobro_de(v_fact, m.monto, m.fecha, v_proc);
      if coalesce(cb, '{}'::jsonb) ? 'facturas' then
        v_acc := 'cobro'; v_fte := 'app';
        v_dat := jsonb_strip_nulls(jsonb_build_object('facturas', cb->'facturas', 'comision', cb->'comision'));
        v_por := case when (cb->>'marcadas')::int = jsonb_array_length(cb->'facturas')
                      then case when jsonb_array_length(cb->'facturas') = 1 then 'La marcaste cobrada en Proyectos y su saldo es justo este depósito'
                                else 'Las marcaste cobradas en Proyectos y juntas suman este depósito' end
                      else case when jsonb_array_length(cb->'facturas') = 1 then 'Es la única factura por cobrar con ese monto'
                                else 'Son las únicas facturas por cobrar que juntas suman este depósito' end end
                 || case when cb ? 'comision' then ', menos la comisión de la tarjeta.' else '.' end;
      elsif v_n = 1 and v_mot in ('deposito_cobro', 'deposito_otro_cobro', 'reembolso_proveedor', 'varios_candidatos') then
        v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
      end if;
    end if;
  else
    if (v_mot in ('transferencia_otro_lado', 'transferencia_un_lado', 'abono_tarjeta', 'interes_tarjeta', 'cargo_banco', 'cuota_prestamo',
                  'cobro_que_lo_nombra', 'otro_lado_clasificado') and v_n >= 1)
       or (v_mot in ('pago_proveedor', 'deuda_propia', 'varios_candidatos') and v_n = 1) then
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif mem.clave is not null then
      v_acc := mem.accion; v_dat := mem.datos - 'obra'; v_fte := 'memoria';
      v_por := 'Ya me lo dijiste antes: ' || mem.texto || '.';
    elsif fn_bandeja_prestamista(m.desc_norm) is not null then
      return jsonb_build_object('fuente', 'app',
        'aviso', format('Parece la cuota de un préstamo de %s que todavía no está dado de alta en Contabilidad. Hasta que se dé de alta (una vez, con su contrato) no se puede repartir entre capital e intereses.',
                        fn_bandeja_prestamista(m.desc_norm)->>'prestamista'));
    else
      select p.id, p.propuesta, p.fuente into q
        from contador_propuestas p
       where p.movimiento_id = m.id and p.estado = 'pendiente'
       order by p.creado_el desc limit 1;
      if found and jsonb_typeof(q.propuesta->'lineas') = 'array' and jsonb_array_length(q.propuesta->'lineas') >= 1 then
        -- LA PROPUESTA DE LA IA (c8): se aprueba por su función de siempre
        v_cta := q.propuesta->'lineas'->0->>'cuenta';
        v_obra := coalesce((select k.regla_obra from cuentas k where k.codigo = v_cta), 'prohibida') in ('obligatoria', 'opcional');
        ob := case when v_obra then coalesce(
                case when nullif(q.propuesta->'lineas'->0->>'proyecto_id', '') is not null
                          and coalesce((q.propuesta->'obra'->>'fuerte')::boolean, true)
                     then (select jsonb_build_object('proyecto_id', pj.id, 'nombre', pj.nombre, 'por', 'la propuso la IA')
                             from proyectos pj where pj.id = q.propuesta->'lineas'->0->>'proyecto_id') end,
                fn_bandeja_obra_del_dia(v_dia)) end;
        return jsonb_strip_nulls(jsonb_build_object(
          'accion', 'ia', 'fuente', 'ia',
          'datos', jsonb_strip_nulls(jsonb_build_object('propuesta_id', q.id, 'cuenta', v_cta, 'proyecto_id', ob->>'proyecto_id',
                                                        'lineas', jsonb_array_length(q.propuesta->'lineas'))),
          'texto', case when jsonb_array_length(q.propuesta->'lineas') = 1
                        then format('Es un gasto de «%s»%s: %s.', fn_bandeja_cuenta_llana(v_cta),
                                    coalesce(' de la obra ' || (ob->>'nombre'), ''), fn_bandeja_usd(abs(m.monto)))
                        else format('Se reparte entre %s: %s.',
                                    (select string_agg('«' || fn_bandeja_cuenta_llana(l->>'cuenta') || '»', ' y ' order by n)
                                       from jsonb_array_elements(q.propuesta->'lineas') with ordinality as t(l, n)),
                                    fn_bandeja_usd(abs(m.monto))) end,
          'porque', case q.fuente when 'regla' then 'Por una regla que ya aprendió de ti' when 'edgar' then 'Ya lo habías dicho tú' else 'Lo propone la IA' end
                    || coalesce(': ' || nullif(left(q.propuesta->>'motivo', 240), ''), '') || coalesce(' (' || (ob->>'por') || ')', ''),
          'pide_obra', case when v_obra and ob is null
                                 and (select k.regla_obra from cuentas k where k.codigo = v_cta) = 'obligatoria' then true end));
      end if;
      if v_proc or (m.desc_norm ~ '(^| )(INTUIT|QBPAYMENTS|QUICKBOOKS|STRIPE|SQUARE|CLOVER|BANKCARD|MERCHANT|WORLDPAY)( |$)'
                    and m.desc_norm ~ '(FEE|DISCOUNT|PROCESSING|TRAN FEE|MERCH)' and abs(m.monto) <= 500) then
        v_acc := 'gasto'; v_dat := jsonb_build_object('cuenta', '6130'); v_fte := 'app';
        v_por := 'Es lo que cobra el procesador de tarjetas por los pagos de tus clientes.';
      else
        sg := fn_bandeja_sugerida(c->>'nombre');
        if sg is not null and c->>'clase' = 'comercio' then
          v_acc := sg->>'accion'; v_dat := case when v_acc = 'gasto' then jsonb_build_object('cuenta', sg->>'cuenta') else '{}'::jsonb end;
          v_fte := 'nombre'; v_por := format('Por el nombre del comercio (%s).', c->>'nombre');
        end if;
      end if;
    end if;
  end if;
  if v_acc is null then
    return null;
  end if;
  -- la obra de un gasto de obra: la del día de la cuadrilla, o la de la visita que vio c6
  if v_acc in ('gasto', 'contratista') and not (v_dat ? 'proyecto_id')
     and (v_acc = 'contratista' or (select k.regla_obra from cuentas k where k.codigo = v_dat->>'cuenta') = 'obligatoria') then
    ob := coalesce(fn_bandeja_obra_del_dia(v_dia),
                   case when m.propuesta->'obra' ? 'proyecto_id'
                        then jsonb_build_object('proyecto_id', m.propuesta->'obra'->>'proyecto_id', 'nombre', m.propuesta->'obra'->>'nombre',
                                                'por', 'ese día hubo una visita a esa obra') end);
    if ob is not null then
      v_dat := v_dat || jsonb_build_object('proyecto_id', ob->>'proyecto_id');
    end if;
  end if;
  v := fn_bandeja_validar(m.id, v_acc, v_dat);
  if not coalesce((v->>'ok')::boolean, false) and not coalesce((v->>'pide_obra')::boolean, false) then
    return null;   -- lo recordado ya no vale (la cuenta, la persona o el préstamo cambiaron): se pregunta
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'accion', v_acc, 'datos', case when (v->>'ok')::boolean then v->'datos' else v_dat end, 'texto', v->>'texto',
    'porque', nullif(concat_ws(' ', v_por, case when ob is not null then 'La obra: ' || (ob->>'por') || '.' end), ''),
    'fuente', v_fte, 'pide_obra', v->'pide_obra',
    'pide_motivo', case when v_acc in ('aporte', 'otro_ingreso')
                             or (v_acc = 'banco' and v->'datos'->'pide' ?| array['p_motivo', 'p_notas', 'p_partidas.motivo']) then true end,
    'pide', case when v_acc = 'banco' then (select nullif(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements_text(coalesce(v->'datos'->'pide', '[]'::jsonb)) e
                                             where e not in ('p_motivo', 'p_notas', 'p_partidas.motivo')) end));
end $$;
revoke execute on function public.fn_bandeja_recomendar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_recomendar(uuid, jsonb) to authenticated;
comment on function public.fn_bandeja_recomendar(uuid, jsonb) is 'c17: LA recomendación de un movimiento pendiente (una o ninguna): {accion de la lista cerrada (o «ia»: la propuesta de c8), datos, texto llano, porque, fuente, pide_obra, pide_motivo, pide}, o {aviso}, o nulo. Un depósito de un prestamista se propone como préstamo antes de mirar facturas. No escribe nada.';


-- ---------------------------------------------------------------------
-- 12. DECIDIR POR GRUPO y LO QUE ENTRA SOLO.
-- ---------------------------------------------------------------------
-- UNA DECISIÓN PARA TODOS los pendientes de una contraparte (p_clave:
-- «C:HOME DEPOT») o para el lote de un motivo de c6 (p_clave «M:…»: los
-- intereses de la tarjeta, los cargos del banco, las cuotas: se acepta la
-- primera opción de c6 de cada uno). Cada movimiento pasa por
-- fn_bandeja_hacer con sus guardas: el que algo frena se queda en la
-- Bandeja y se dice por qué. De un grupo se salta el movimiento para el que
-- c6 tiene OTRA explicación (su recibo, un duplicado). p_opciones:
-- {recordar (de fábrica sí), solo (que lo siguiente entre solo), motivo,
-- movimientos: [los que la pantalla enseñó: solo esos]}. Sin obra en los
-- datos, cada gasto de obra va a la del día de la cuadrilla. Devuelve {clave,
-- hechos, monto, quedan: [{movimiento_id, por_que}], recordado,
-- propuestas_ia, sigue (cortó por reloj: llámala otra vez)}.
create or replace function public.fn_bandeja_grupo(p_clave text, p_accion text default null, p_datos jsonb default '{}'::jsonb,
                                                   p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien  uuid;
  op       jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  d0       jsonb := case when jsonb_typeof(p_datos) = 'object' then p_datos else '{}'::jsonb end;
  v_lote   boolean := coalesce(p_clave, '') like 'M:%';
  v_fin    timestamptz := clock_timestamp() + interval '18 seconds';
  m        movimientos_banco;
  c        jsonb;
  d        jsonb;
  r        jsonb;
  ob       jsonb;
  v_hechos jsonb := '[]'::jsonb;
  v_quedan jsonb := '[]'::jsonb;
  v_ia     jsonb := '[]'::jsonb;
  v_mem    jsonb;
  v_monto  numeric := 0;
  v_sigue  boolean := false;
  v_ultimo uuid;
  v_obra   boolean := false;
begin
  v_quien := fn_bandeja_quien();
  if coalesce(p_clave, '') !~ '^(C|D|P|M|Z[<>]):.+' then
    raise exception using errcode = '22023', message = 'Falta el grupo.';
  end if;
  if not v_lote then
    if p_accion is null or p_accion not in ('gasto', 'personal', 'cobro', 'anticipo', 'prestamo', 'aporte', 'traspaso', 'cuadrilla',
                                            'contratista', 'otro_ingreso') then
      raise exception using errcode = '22023', message = 'Falta decir qué son los movimientos de ese grupo.';
    end if;
    if p_accion = 'cobro' then
      raise exception using errcode = 'MX008',
        message = 'Los cobros se contestan de uno en uno: cada depósito paga sus propias facturas.';
    end if;
    v_obra := p_accion = 'contratista'
              or (p_accion = 'gasto' and (select k.regla_obra from cuentas k where k.codigo = d0->>'cuenta') = 'obligatoria');
  end if;
  for m in select mb.* from movimientos_banco mb where mb.estado = 'pendiente' order by mb.fecha, mb.id loop
    -- (la pantalla manda los que enseñó: lo que llegó después, o lo que tiene su propia tarjeta, no entra en esta respuesta)
    continue when jsonb_typeof(op->'movimientos') = 'array' and not (op->'movimientos' ? m.id::text);
    if v_lote then
      continue when coalesce(m.propuesta->>'motivo', '') <> substring(p_clave from 3)
                 or jsonb_typeof(m.propuesta->'opciones') is distinct from 'array' or jsonb_array_length(m.propuesta->'opciones') < 1;
    else
      c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
      continue when c->>'clave' is distinct from p_clave;
    end if;
    if clock_timestamp() > v_fin then
      v_sigue := true;
      exit;
    end if;
    v_ultimo := m.id;
    if m.posible_duplicado_de is not null and m.duplicado is null then
      v_quedan := v_quedan || jsonb_build_object('movimiento_id', m.id, 'por_que', 'Se parece a otro movimiento: dime primero si es el mismo.');
      continue;
    end if;
    if v_lote then
      r := fn_bandeja_hacer(m.id, 'banco', jsonb_build_object('opcion', 0),
                            jsonb_strip_nulls(jsonb_build_object('fuente', 'grupo', 'motivo', op->>'motivo')));
    else
      -- (lo que c6 solo SUPONE de un depósito —un pago parcial, una factura sin su cobro— no es otra explicación: la
      -- puerta lo guarda igual con sus frenos)
      if coalesce(m.propuesta->>'motivo', 'sin_propuesta') not in ('sin_ticket', 'clasificar', 'dudosa', 'sin_propuesta', 'deposito_sin_factura',
                                                                   'deposito_parcial', 'deposito_sin_cobro')
         and nullif(btrim(coalesce(op->>'motivo', '')), '') is null then
        v_quedan := v_quedan || jsonb_build_object('movimiento_id', m.id,
                                                   'por_que', 'Para este el banco tiene otra explicación: míralo aparte.');
        continue;
      end if;
      d := d0;
      if v_obra and not (d ? 'proyecto_id') then
        ob := fn_bandeja_obra_del_dia(coalesce(m.fecha_transaccion, m.fecha));
        if ob is not null then
          d := d || jsonb_build_object('proyecto_id', ob->>'proyecto_id');
        end if;
      end if;
      r := fn_bandeja_hacer(m.id, p_accion, d, jsonb_strip_nulls(jsonb_build_object('fuente', 'grupo', 'motivo', op->>'motivo')));
    end if;
    if coalesce((r->>'hecho')::boolean, false) then
      v_hechos := v_hechos || jsonb_build_object('movimiento_id', m.id, 'hecho_id', r->>'hecho_id', 'monto', m.monto, 'texto', r->>'texto');
      v_monto := v_monto + m.monto;
      v_ia := v_ia || coalesce(r->'propuestas_ia', '[]'::jsonb);
    else
      v_quedan := v_quedan || jsonb_strip_nulls(jsonb_build_object('movimiento_id', m.id, 'por_que', r->>'por_que',
                                                                  'pide_obra', r->'pide_obra', 'pide_motivo', r->'pide_motivo'));
    end if;
  end loop;
  -- lo que se recuerda del grupo, aunque ninguno haya entrado (a todos les falta la obra)
  if not v_lote and coalesce((op->>'recordar')::boolean, true) and v_ultimo is not null then
    v_mem := fn_bandeja_recordar(v_ultimo, p_accion, d0 - 'proyecto_id', case when op ? 'solo' then (op->>'solo')::boolean end, 'grupo');
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'clave', p_clave, 'hechos', jsonb_array_length(v_hechos), 'monto', v_monto, 'registrados', v_hechos, 'quedan', v_quedan,
    'recordado', v_mem, 'propuestas_ia', nullif(v_ia, '[]'::jsonb), 'sigue', case when v_sigue then true end));
end $$;
revoke execute on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) to authenticated;
comment on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) is 'c17: una decisión para todos los pendientes de una contraparte (o el lote de un motivo de c6, «M:…»): cada uno pasa por fn_bandeja_hacer con sus guardas; el que algo frena se queda y se dice por qué. Guarda lo dicho en la memoria (con «solo» si Edgar lo pide y es un comercio).';

-- LA RUTINA QUE REGISTRA SOLA. Entra solo, y solo, lo que cumple TODO esto:
--   · bandeja_config.solo está encendido;
--   · es un CARGO (dinero que sale) de un COMERCIO (no un Zelle, un cheque,
--     el cajero, la nómina, un traspaso ni un prestamista);
--   · ese comercio tiene una regla ACTIVA con «que entre solo» (la puso
--     Edgar), y es un gasto o algo personal;
--   · no pasa del tope (bandeja_config.solo_tope);
--   · c6 no tiene nada mejor que decir de él (su motivo es «sin ticket») y
--     no lo señaló como posible duplicado;
--   · nadie lo deshizo antes;
--   · si la cuenta pide obra, ese día la cuadrilla trabajó en UNA sola
--     (si no, espera a Edgar);
--   · y la puerta de c6 lo acepta SIN motivo escrito (un mes cerrado, algo
--     que puede estar ya en el libro: no entra).
-- Lo comprueba otra vez fn_bandeja_hacer con la fuente «solo». p: {segundos
-- (el reloj: 12 de fábrica), corrio (pantalla | rutina)}. Devuelve
-- {encendido, registrados: [...], esperan (con regla, sin obra ese día), no
-- (la puerta no los aceptó), completo, propuestas_ia}.
create or replace function public.fn_bandeja_solo(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  cfg     bandeja_config;
  mem     bandeja_memoria;
  m       movimientos_banco;
  c       jsonb;
  d       jsonb;
  r       jsonb;
  ob      jsonb;
  v_reg   jsonb := '[]'::jsonb;
  v_ia    jsonb := '[]'::jsonb;
  v_esp   int := 0;
  v_no    int := 0;
  v_comp  boolean := true;
  v_fin   timestamptz;
begin
  v_quien := fn_bandeja_quien();
  select * into cfg from bandeja_config where id = 1;
  if not coalesce(cfg.solo, false) or not exists (select 1 from bandeja_memoria bm where bm.activa and bm.solo) then
    return jsonb_build_object('encendido', coalesce(cfg.solo, false), 'registrados', '[]'::jsonb, 'esperan', 0, 'no', 0, 'completo', true);
  end if;
  v_fin := clock_timestamp() + make_interval(secs => least(greatest(coalesce(fn_bandeja_num(p->>'segundos'), 12), 1), 25));
  for m in select mb.* from movimientos_banco mb
            where mb.estado = 'pendiente' and mb.monto < 0 and abs(mb.monto) <= cfg.solo_tope
              and coalesce(mb.propuesta->>'motivo', '') in ('sin_ticket', 'dudosa')
              and mb.posible_duplicado_de is null
              and not exists (select 1 from bandeja_hechos h where h.movimiento_id = mb.id and h.deshecho_el is not null)
            order by mb.fecha, mb.id loop
    if clock_timestamp() > v_fin then
      v_comp := false;
      exit;
    end if;
    c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
    continue when c->>'clase' <> 'comercio' or not (c ? 'clave');
    select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa and bm.solo and bm.accion in ('gasto', 'personal');
    continue when not found;
    d := mem.datos - 'obra';
    if mem.accion = 'gasto' and mem.datos->>'obra' = 'dia' then
      ob := fn_bandeja_obra_del_dia(coalesce(m.fecha_transaccion, m.fecha));
      if ob is null then
        v_esp := v_esp + 1;
        continue;
      end if;
      d := d || jsonb_build_object('proyecto_id', ob->>'proyecto_id');
    end if;
    r := fn_bandeja_hacer(m.id, mem.accion, d, jsonb_build_object('fuente', 'solo', 'corrio', coalesce(p->>'corrio', 'pantalla')));
    if coalesce((r->>'hecho')::boolean, false) then
      v_reg := v_reg || jsonb_build_object('hecho_id', r->>'hecho_id', 'movimiento_id', m.id, 'fecha', m.fecha, 'monto', m.monto,
                                           'descripcion', m.descripcion, 'texto', r->>'texto');
      v_ia := v_ia || coalesce(r->'propuestas_ia', '[]'::jsonb);
    else
      v_no := v_no + 1;
    end if;
  end loop;
  return jsonb_strip_nulls(jsonb_build_object('encendido', true, 'registrados', v_reg, 'esperan', v_esp, 'no', v_no, 'completo', v_comp,
                                              'propuestas_ia', nullif(v_ia, '[]'::jsonb)));
end $$;
revoke execute on function public.fn_bandeja_solo(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_solo(jsonb) to authenticated;
comment on function public.fn_bandeja_solo(jsonb) is 'c17: LA RUTINA QUE REGISTRA SOLA (una regla de Edgar, no la IA): los cargos de un comercio con regla «que entre solo», hasta el tope, que c6 da por «sin ticket», sin sospecha de duplicado, nunca deshechos, con su obra del día si la cuenta la pide, y que la puerta de c6 acepta sin motivo. Nunca un depósito, un Zelle, un cheque, el cajero, la nómina ni un traspaso.';

-- LA TAREA SIN PANTALLA (pg_cron, o el SQL Editor; sin API): corre la
-- rutina EN NOMBRE DEL DUEÑO que encendió lo de solo (el mecanismo de c10,
-- copiado) y cierra por la puerta de c8 las propuestas de la IA que lo
-- registrado deja abiertas. NUNCA FALLA HACIA FUERA: lo que pase queda en
-- bandeja_config.solo_ultimo y lo dice el control.
create or replace function public.fn_bandeja_solo_programado() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg      bandeja_config;
  v_dueno  uuid;
  v_claims text;
  v_sub    text;
  v_res    jsonb;
  v_cerr   int := 0;
  v_err    text;
  v_ult    jsonb;
  i        text;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501',
      message = 'La tarea que registra sola la dispara pg_cron (o el SQL Editor); la app llama a fn_bandeja_solo.';
  end if;
  select * into cfg from bandeja_config where id = 1;
  if not coalesce(cfg.solo, false) then
    return jsonb_build_object('encendido', false);
  end if;
  begin
    select p.id into v_dueno
      from perfiles p
     where p.rol = 'dueno' and coalesce(p.activo, true)
     order by (p.id is not distinct from cfg.solo_por) desc, p.creado, p.id
     limit 1;
    if v_dueno is null then
      raise exception using errcode = '42501', message = 'no hay un dueño activo en cuyo nombre registrar';
    end if;
    v_claims := current_setting('request.jwt.claims', true);
    v_sub    := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claims', jsonb_build_object('sub', v_dueno, 'role', 'authenticated', 'bandeja_solo', true)::text, true);
    perform set_config('request.jwt.claim.sub', v_dueno::text, true);
    if not es_dueno() then
      raise exception using errcode = '42501', message = 'el dueño en cuyo nombre se registra ya no es el dueño';
    end if;
    v_res := fn_bandeja_solo(jsonb_build_object('segundos', 20, 'corrio', 'rutina'));
    if to_regprocedure('public.fn_contador_rechazar(uuid,uuid,text)') is not null then
      for i in select jsonb_array_elements_text(coalesce(v_res->'propuestas_ia', '[]'::jsonb)) loop
        begin
          execute 'select public.fn_contador_rechazar($1, $2, $3)'
            using i::uuid, v_dueno, 'Lo registró una regla de Edgar en la Bandeja (entró solo)';
          v_cerr := v_cerr + 1;
        exception when others then
          null;  -- sigue abierta: la pantalla la cierra al abrir la Bandeja
        end;
      end loop;
    end if;
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  exception when others then
    v_err := sqlstate || ': ' || sqlerrm;
    v_res := null;
    v_cerr := 0;
  end;
  v_ult := jsonb_strip_nulls(jsonb_build_object(
    'el', clock_timestamp(), 'registrados', coalesce(jsonb_array_length(v_res->'registrados'), 0),
    'monto', (select coalesce(sum((x->>'monto')::numeric), 0) from jsonb_array_elements(coalesce(v_res->'registrados', '[]'::jsonb)) x),
    'esperan', coalesce((v_res->>'esperan')::int, 0), 'no', coalesce((v_res->>'no')::int, 0),
    'completo', coalesce((v_res->>'completo')::boolean, v_err is null), 'ia_cerradas', v_cerr, 'error', left(v_err, 600)));
  perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
  update bandeja_config set solo_ultimo = v_ult where id = 1;
  perform set_config('mx_bandeja.escribe', '', true);
  return v_ult || jsonb_build_object('encendido', true);
end $$;
revoke execute on function public.fn_bandeja_solo_programado() from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_solo_programado() is 'c17: la tarea de madrugada y de la tarde (pg_cron, o el SQL Editor; sin API): corre fn_bandeja_solo (20 s) en nombre del dueño que lo encendió, cierra por la puerta de c8 las propuestas de la IA que deja abiertas y deja en bandeja_config.solo_ultimo lo que pasó. Nunca falla hacia fuera.';

-- Las dos tareas, solo donde hay pg_cron (producción): a las 11:18 UTC
-- (después de Plaid, 11:00, y del jornal de c10, 11:12; antes de la IA de
-- c8, 11:25: así la IA no gasta en proponer para lo que ya entró solo) y a
-- las 20:54 UTC (después del jornal, 20:50; antes de la IA, 21:00).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname in ('mxp-bandeja-solo-manana', 'mxp-bandeja-solo-tarde');
    perform cron.schedule('mxp-bandeja-solo-manana', '18 11 * * *', 'select public.fn_bandeja_solo_programado()');
    perform cron.schedule('mxp-bandeja-solo-tarde', '54 20 * * *', 'select public.fn_bandeja_solo_programado()');
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 13. «DÍMELO CON TUS PALABRAS»: lo que llama la función de borde
--     «contador» (acción «dimelo»), conectada como postgres (la guarda de
--     c8: fn_contador_exigir; nada de esto está en la API), y lo que hace
--     el dueño con la propuesta (aprobar, rechazar: por la API).
-- ---------------------------------------------------------------------
-- EL CONTEXTO que se le da a la IA para UN movimiento y UNA frase de Edgar.
-- {config: {modelo, effort}, tope, fijo: {…}, movimiento: {…}, facturas,
-- fuera_del_libro, parecidos, frase}. «fijo» es lo que no cambia de un
-- movimiento a otro (va delante y se cachea): las categorías con su cuenta,
-- las obras, las cuentas propias y las tarjetas, los préstamos, la
-- cuadrilla, los proveedores y lo que Edgar ya enseñó. TODO sale tapado por
-- la máscara de c8 (sin correos, teléfonos ni números de cuenta), también
-- la frase. Con el tope del mes gastado, {bloqueado, motivo}: ni un token.
create or replace function public.fn_bandeja_dimelo_contexto(p_movimiento uuid, p_dueno uuid, p_frase text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg8     contador_config;
  cfg      bandeja_config;
  m        movimientos_banco;
  c        jsonb;
  v_frase  text := nullif(btrim(regexp_replace(coalesce(p_frase, ''), '\s+', ' ', 'g')), '');
  v_tope   jsonb;
  v_fijo   jsonb;
  v_mov    jsonb;
  v_fact   jsonb;
begin
  perform fn_contador_exigir();
  if p_dueno is null or not exists (select 1 from perfiles p where p.id = p_dueno and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501', message = 'La Bandeja la contesta solo Edgar (el dueño).';
  end if;
  cfg8 := fn_contador_cfg();
  select * into cfg from bandeja_config where id = 1;
  if not coalesce(cfg.dimelo, false) then
    raise exception using errcode = 'MX008', message = 'La caja «Dímelo con tus palabras» está apagada.';
  end if;
  if v_frase is null or length(v_frase) < 3 or length(v_frase) > 600 then
    raise exception using errcode = '22023', message = 'Escribe qué es en una frase (hasta 600 letras).';
  end if;
  select * into m from movimientos_banco where id = p_movimiento;
  if not found or m.estado <> 'pendiente' then
    raise exception using errcode = 'MX008', message = 'Ese movimiento ya no está en la Bandeja.';
  end if;
  v_tope := fn_contador_tope();
  if coalesce((v_tope->>'bloqueado')::boolean, false) then
    return jsonb_build_object('bloqueado', true, 'motivo', v_tope->>'motivo', 'tope', v_tope);
  end if;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  v_fact := fn_bandeja_facturas();
  v_fijo := jsonb_build_object(
    'categorias', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                            'grupo', g->>'nombre', 'categoria', s->>'nombre', 'accion', s->>'accion', 'cuenta', s->>'cuenta',
                            'tipo', s->>'tipo', 'pide_obra', s->'obra')) order by gi, si), '[]'::jsonb)
                     from jsonb_array_elements(fn_bandeja_categorias()) with ordinality as a(g, gi)
                     cross join lateral jsonb_array_elements(a.g->'sub') with ordinality as b(s, si)),
    'cuentas', (select coalesce(jsonb_agg(jsonb_build_object('cuenta', k.codigo, 'nombre', k.nombre, 'obra', k.regla_obra) order by k.codigo), '[]'::jsonb)
                  from v_contador_cuentas vc join cuentas k on k.codigo = vc.codigo
                 where k.tipo in ('costo', 'gasto', 'otro_gasto') or k.codigo ~ '^15'),
    'obras', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', x.id, 'nombre', x.nombre, 'cliente', x.cliente, 'estado', x.estado))
                                        order by x.act desc, x.nombre), '[]'::jsonb)
                from (select p.id, p.nombre, p.cliente, p.estado, (p.estado in ('aprobado', 'ejecucion', 'pausa')) as act
                        from proyectos p
                       where p.estado in ('aprobado', 'ejecucion', 'pausa')
                          or exists (select 1 from jsonb_array_elements(v_fact) f where f->>'proyecto_id' = p.id)
                          or p.actualizado > now() - interval '400 days'
                       order by (p.estado in ('aprobado', 'ejecucion', 'pausa')) desc, p.actualizado desc nulls last
                       limit 80) x),
    'cuentas_propias', (select coalesce(jsonb_agg(jsonb_build_object(
                                 'cuenta', x->>'codigo', 'nombre', x->>'nombre',
                                 'tipo', case when (x->>'tarjeta')::boolean then 'tarjeta' else 'banco' end) order by x->>'codigo'), '[]'::jsonb)
                          from jsonb_array_elements(fn_bandeja_cuentas_propias()) x),
    'prestamos', (select coalesce(jsonb_agg(jsonb_build_object('prestamo_id', p.id, 'prestamista', p.prestamista) order by p.creado_el), '[]'::jsonb)
                    from prestamos p),
    'cuadrilla', case when to_regprocedure('public.fn_jornal_pago(jsonb)') is null then '[]'::jsonb
                      else (select coalesce(jsonb_agg(jsonb_build_object('usuario_id', p.id, 'nombre', p.nombre) order by p.nombre), '[]'::jsonb)
                              from perfiles p where p.rol <> 'dueno' and coalesce(p.activo, true)) end,
    'proveedores', case when to_regclass('public.proveedores') is null then '[]'::jsonb
                        else (select coalesce(jsonb_agg(jsonb_build_object('proveedor_id', x.id, 'nombre', x.nombre) order by x.nombre), '[]'::jsonb)
                                from (select pv.id, pv.nombre from proveedores pv where coalesce(pv.activo, true) order by pv.creado_el desc limit 60) x) end,
    'lo_que_edgar_ya_enseno', (select coalesce(jsonb_agg(x.t order by x.t), '[]'::jsonb)
                                 from (select bm.texto as t from bandeja_memoria bm where bm.activa order by bm.ultima_vez desc nulls last limit 60) x));
  v_mov := jsonb_strip_nulls(jsonb_build_object(
    'fecha', m.fecha, 'monto', m.monto, 'es', case when m.monto < 0 then 'dinero que salió' else 'dinero que entró' end,
    'descripcion', fn_contador_sin_datos(m.descripcion), 'memo', fn_contador_sin_datos(m.memo),
    'cuenta', m.cuenta, 'cuenta_nombre', (select k.nombre from cuentas k where k.codigo = m.cuenta), 'tipo_banco', m.tipo_banco,
    'contraparte', jsonb_build_object('clase', c->>'clase', 'nombre', c->>'nombre'),
    'obra_del_dia', fn_bandeja_obra_del_dia(coalesce(m.fecha_transaccion, m.fecha)) - 'por',
    'prestamista', fn_bandeja_prestamista(m.desc_norm) - 'cuenta',
    'lo_que_dice_el_banco', left(fn_bandeja_llano(m.propuesta->>'texto'), 500),
    'opciones_del_banco', (select nullif(jsonb_agg(jsonb_build_object('opcion', (n - 1)::int, 'texto', fn_bandeja_opcion_texto(o, m.monto)) order by n), '[]'::jsonb)
                             from jsonb_array_elements(case when jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones'
                                                            else '[]'::jsonb end) with ordinality as t(o, n)
                            where o->>'llamar' = any (fn_bandeja_puertas())
                              and not (fn_bandeja_opcion_pide(o) && array['p_capital', 'p_interes']))));
  return fn_contador_sin_datos_jsonb(jsonb_build_object(
    'bloqueado', false,
    'config', jsonb_build_object('modelo', cfg8.modelo, 'effort', cfg.dimelo_effort),
    'tope', v_tope,
    'fijo', v_fijo,
    'movimiento', v_mov,
    'facturas_por_cobrar', (select coalesce(jsonb_agg(x.f - 'monto' order by x.n), '[]'::jsonb)
                              from (select f, n from jsonb_array_elements(v_fact) with ordinality as t(f, n) order by n limit 40) x),
    'facturas_fuera_del_libro', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                          'num', fc.num, 'obra', p.nombre, 'cliente', p.cliente, 'fecha', fc.fecha, 'monto', fc.monto,
                                          'marcada_cobrada', coalesce(fc.pagada, false))) order by fc.fecha desc), '[]'::jsonb)
                                   from (select * from facturas_cobro z
                                          where coalesce(z.estado, 'emitida') <> 'anulada' and coalesce(z.saldo_libro, 0) = 0
                                            and coalesce(z.cobrado_libro, 0) = 0 and z.fecha > m.fecha - 200
                                          order by z.fecha desc limit 15) fc
                                   left join proyectos p on p.id = fc.proyecto_id),
    'parecidos_ya_resueltos', (select coalesce(jsonb_agg(jsonb_build_object('fecha', x.fecha, 'monto', x.monto, 'fue', x.texto) order by x.el desc), '[]'::jsonb)
                                 from (select mb.fecha, h.monto, h.texto, h.el
                                         from bandeja_hechos h join movimientos_banco mb on mb.id = h.movimiento_id
                                        where h.deshecho_el is null and c ? 'clave' and h.memoria_clave = c->>'clave'
                                        order by h.el desc limit 6) x),
    'frase', v_frase));
end $$;
revoke execute on function public.fn_bandeja_dimelo_contexto(uuid, uuid, text) from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_dimelo_contexto(uuid, uuid, text) is 'c17: lo que la función de borde le da a la IA para «Dímelo con tus palabras»: lo fijo (categorías, cuentas, obras, cuentas propias, préstamos, cuadrilla, proveedores, lo ya enseñado), el movimiento, las facturas por cobrar y las de fuera del libro, lo parecido ya resuelto y la frase; todo tapado por la máscara de c8. Con el tope gastado, {bloqueado}. Solo desde la función de borde (fn_contador_exigir).';

-- GUARDAR lo que contestó la IA: se anota su gasto (acción
-- «contador_dimelo», donde lo anota c8: cuenta contra el mismo tope), la
-- propuesta anterior de ese movimiento caduca, y la respuesta se VALIDA
-- (fn_bandeja_validar) antes de guardarse como propuesta «pendiente». Lo
-- que no vale, o un «falta», queda «sin_propuesta» con su porqué. Nada se
-- registra en el libro aquí. p_respuesta: {accion, cuenta, proyecto_id,
-- facturas: [{id, monto}], comision, prestamo_id, prestamista, tipo,
-- cuenta_destino, usuario_id, proveedor_id, opcion, recordar, explicacion,
-- falta}. p_usage: {input, output, cache_creacion, cache_lectura}.
create or replace function public.fn_bandeja_dimelo_guardar(p_movimiento uuid, p_dueno uuid, p_frase text, p_grupo boolean, p_entrada jsonb,
                                                            p_salida jsonb, p_respuesta jsonb, p_modelo text, p_effort text,
                                                            p_prompt_version text, p_usage jsonb, p_error text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r        jsonb := case when jsonb_typeof(p_respuesta) = 'object' then p_respuesta else null end;
  v_frase  text := fn_contador_sin_datos(nullif(btrim(regexp_replace(coalesce(p_frase, ''), '\s+', ' ', 'g')), ''));
  v_cent   int;
  v_k      char;
  v_acc    text;
  v_dat    jsonb;
  v        jsonb;
  v_falta  text;
  v_est    text := 'sin_propuesta';
  v_id     uuid := gen_random_uuid();
  v_s      jsonb;
  c_lista  constant text[] := array['gasto', 'personal', 'cobro', 'anticipo', 'prestamo', 'aporte', 'traspaso', 'cuadrilla', 'contratista',
                                    'otro_ingreso', 'banco'];
begin
  perform fn_contador_exigir();
  if p_dueno is null or not exists (select 1 from perfiles p where p.id = p_dueno and p.rol = 'dueno' and coalesce(p.activo, true)) then
    raise exception using errcode = '42501', message = 'La Bandeja la contesta solo Edgar (el dueño).';
  end if;
  if v_frase is null then
    raise exception using errcode = '22023', message = 'Falta la frase.';
  end if;
  -- el gasto (los precios de c8: entrada 400, caché creado 500, caché leído 20, salida 2000 centavos por millón)
  v_cent := round((coalesce((p_usage->>'input')::numeric, 0) * 400 + coalesce((p_usage->>'cache_creacion')::numeric, 0) * 500
                   + coalesce((p_usage->>'cache_lectura')::numeric, 0) * 20 + coalesce((p_usage->>'output')::numeric, 0) * 2000) / 1000000.0)::int;
  if coalesce((p_usage->>'input')::numeric, 0) + coalesce((p_usage->>'output')::numeric, 0)
     + coalesce((p_usage->>'cache_creacion')::numeric, 0) + coalesce((p_usage->>'cache_lectura')::numeric, 0) > 0 then
    select k.relkind into v_k from pg_class k where k.oid = to_regclass('public.asistente_costo_mes');
    if v_k = 'r' then
      execute 'insert into asistente_costo_mes (mes, accion, llamadas, centavos, entrada, salida, cache_lectura) values ($1, $2, 1, $3, $4, $5, $6) '
              'on conflict (mes, accion) do update set llamadas = asistente_costo_mes.llamadas + 1, centavos = asistente_costo_mes.centavos + excluded.centavos, '
              'entrada = asistente_costo_mes.entrada + excluded.entrada, salida = asistente_costo_mes.salida + excluded.salida, '
              'cache_lectura = asistente_costo_mes.cache_lectura + excluded.cache_lectura'
        using to_char(fn_fecha_miami(now()), 'YYYY-MM'), 'contador_dimelo', v_cent, coalesce((p_usage->>'input')::bigint, 0),
              coalesce((p_usage->>'output')::bigint, 0), coalesce((p_usage->>'cache_lectura')::bigint, 0);
    else
      insert into asistente_uso (usuario_id, rol, modelo, entrada, salida, vueltas, accion, cache_lectura, cache_escritura, resultado, costo_centavos)
      values (p_dueno, 'dueno', p_modelo, coalesce((p_usage->>'input')::int, 0), coalesce((p_usage->>'output')::int, 0), 1, 'contador_dimelo',
              coalesce((p_usage->>'cache_lectura')::int, 0), coalesce((p_usage->>'cache_creacion')::int, 0), coalesce(left(p_error, 200), 'ok'), v_cent);
    end if;
  end if;
  -- la respuesta, a una acción de la lista cerrada
  if p_error is not null or r is null then
    v_falta := 'La IA no contestó' || coalesce(' (' || left(p_error, 200) || ')', '') || '. Prueba otra vez, o elige en «Más opciones».';
  else
    v_acc := r->>'accion';
    if v_acc is null or not (v_acc = any (c_lista)) then
      v_falta := coalesce(nullif(left(fn_contador_sin_datos(btrim(coalesce(r->>'falta', ''))), 400), ''),
                          'No encontré a qué corresponde con lo que la app sabe. Dime algo más: la obra, el cliente o de qué fue.');
      v_acc := null;
    else
      v_dat := jsonb_strip_nulls(case v_acc
        when 'gasto' then jsonb_build_object('cuenta', r->>'cuenta', 'proyecto_id', r->>'proyecto_id')
        when 'cobro' then jsonb_build_object('facturas', case when jsonb_typeof(r->'facturas') = 'array' then r->'facturas' end,
                                             'comision', r->>'comision')
        when 'anticipo' then jsonb_build_object('proyecto_id', r->>'proyecto_id')
        when 'prestamo' then jsonb_build_object('prestamo_id', r->>'prestamo_id', 'prestamista', r->>'prestamista')
        when 'aporte' then jsonb_build_object('tipo', r->>'tipo')
        when 'traspaso' then jsonb_build_object('cuenta', r->>'cuenta_destino')
        when 'cuadrilla' then jsonb_build_object('usuario_id', r->>'usuario_id')
        when 'contratista' then jsonb_build_object('proyecto_id', r->>'proyecto_id', 'proveedor_id', r->>'proveedor_id')
        when 'otro_ingreso' then jsonb_build_object('cuenta', r->>'cuenta')
        when 'banco' then jsonb_build_object('opcion', r->>'opcion')
        else '{}'::jsonb end);
      -- (la validación lee como el dueño: en su nombre, solo dentro de esta transacción)
      v_s := fn_contador_suplantar();
      v := fn_bandeja_validar(p_movimiento, v_acc, v_dat);
      perform fn_contador_soltar(v_s);
      if coalesce((v->>'ok')::boolean, false) or coalesce((v->>'pide_obra')::boolean, false) then
        v_est := 'pendiente';
        v_dat := v->'datos';
        v_falta := case when not (v->>'ok')::boolean then v->>'falta' end;
      else
        v_falta := coalesce(v->>'falta', 'No se puede registrar así.');
      end if;
    end if;
  end if;
  perform set_config('mx_bandeja.escribe', 'bandeja_dimelo', true);
  update bandeja_dimelo
     set estado = 'caducada', resuelto_por = p_dueno, resuelto_el = now(), resuelto_motivo = 'Edgar lo volvió a decir'
   where movimiento_id = p_movimiento and estado = 'pendiente';
  insert into bandeja_dimelo (id, movimiento_id, frase, grupo, modelo, effort, prompt_version, entrada, salida, accion, datos, texto, porque,
                              falta, recordar, estado, centavos, uso, pedido_por)
  values (v_id, p_movimiento, v_frase, coalesce(p_grupo, false), p_modelo, p_effort, nullif(btrim(coalesce(p_prompt_version, '')), ''),
          fn_contador_sin_datos_jsonb(p_entrada), p_salida,
          case when v_est = 'pendiente' then v_acc end, case when v_est = 'pendiente' then v_dat end,
          case when v_est = 'pendiente' then v->>'texto' end,
          nullif(left(fn_contador_sin_datos(btrim(regexp_replace(coalesce(r->>'explicacion', ''), '\s+', ' ', 'g'))), 300), ''),
          v_falta, coalesce((r->>'recordar')::boolean, false) and v_est = 'pendiente', v_est, coalesce(v_cent, 0), p_usage, p_dueno);
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'dimelo_id', v_id, 'movimiento_id', p_movimiento, 'estado', v_est, 'accion', case when v_est = 'pendiente' then v_acc end,
    'datos', case when v_est = 'pendiente' then v_dat end, 'texto', case when v_est = 'pendiente' then v->>'texto' end,
    'porque', nullif(left(fn_contador_sin_datos(btrim(regexp_replace(coalesce(r->>'explicacion', ''), '\s+', ' ', 'g'))), 300), ''),
    'falta', v_falta, 'pide_obra', case when v_est = 'pendiente' then v->'pide_obra' end,
    -- (lo que el banco pide para esa opción y no es el motivo: el capital y el interés de una cuota; se mandan al aprobar)
    'pide', case when v_est = 'pendiente' and v_acc = 'banco'
                 then (select nullif(jsonb_agg(e), '[]'::jsonb)
                         from jsonb_array_elements_text(coalesce(v->'datos'->'pide', '[]'::jsonb)) e
                        where e not in ('p_motivo', 'p_notas', 'p_partidas.motivo')) end,
    'recordar', coalesce((r->>'recordar')::boolean, false) and v_est = 'pendiente',
    'centavos', coalesce(v_cent, 0), 'tope', fn_contador_tope()));
end $$;
revoke execute on function public.fn_bandeja_dimelo_guardar(uuid, uuid, text, boolean, jsonb, jsonb, jsonb, text, text, text, jsonb, text)
  from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_dimelo_guardar(uuid, uuid, text, boolean, jsonb, jsonb, jsonb, text, text, text, jsonb, text) is 'c17: guarda lo que la IA contestó a un «Dímelo»: anota su gasto (acción contador_dimelo), caduca la propuesta anterior de ese movimiento y valida la respuesta contra la lista cerrada y la base; lo que vale queda «pendiente» (lo aprueba el dueño con fn_bandeja_aprobar), lo demás «sin_propuesta» con su porqué. No registra nada en el libro. Solo desde la función de borde.';

-- «ASÍ ES» de una propuesta del «Dímelo»: la registra fn_bandeja_hacer con
-- la acción YA VALIDADA que se guardó (nunca con algo que venga de fuera),
-- y con LA FRASE DE EDGAR como motivo escrito. p_opciones: {proyecto_id (la
-- obra que faltaba), motivo (otro motivo), campos (lo que el banco pide para
-- esa opción: el capital y el interés de una cuota), recordar, solo}.
-- Devuelve lo de fn_bandeja_hacer; con hecho: false la propuesta sigue
-- pendiente.
create or replace function public.fn_bandeja_aprobar(p_dimelo uuid, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  op      jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  q       bandeja_dimelo;
  d       jsonb;
  r       jsonb;
begin
  v_quien := fn_bandeja_quien();
  select * into q from bandeja_dimelo where id = p_dimelo;
  if not found then
    raise exception using errcode = '22023', message = 'Esa propuesta no existe.';
  end if;
  if q.estado <> 'pendiente' then
    raise exception using errcode = 'MX008', message = 'Esa propuesta ya no está pendiente: vuelve a abrir la Bandeja.';
  end if;
  d := q.datos || case when nullif(btrim(coalesce(op->>'proyecto_id', '')), '') is not null
                            and q.accion in ('gasto', 'anticipo', 'contratista')
                       then jsonb_build_object('proyecto_id', btrim(op->>'proyecto_id')) else '{}'::jsonb end
              || case when q.accion = 'banco' and jsonb_typeof(op->'campos') = 'object'
                      then jsonb_build_object('campos', op->'campos') else '{}'::jsonb end;
  r := fn_bandeja_hacer(q.movimiento_id, q.accion, d, jsonb_strip_nulls(jsonb_build_object(
         'fuente', 'dimelo', 'dimelo_id', q.id,
         'motivo', coalesce(nullif(btrim(coalesce(op->>'motivo', '')), ''), 'Edgar dijo: «' || q.frase || '»'),
         'recordar', coalesce((op->>'recordar')::boolean, q.recordar), 'solo', op->'solo')));
  if coalesce((r->>'hecho')::boolean, false) then
    perform set_config('mx_bandeja.escribe', 'bandeja_dimelo', true);
    update bandeja_dimelo
       set estado = 'aprobada', resuelto_por = v_quien, resuelto_el = now(), hecho_id = (r->>'hecho_id')::uuid
     where id = q.id;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  return r || jsonb_build_object('dimelo_id', q.id);
end $$;
revoke execute on function public.fn_bandeja_aprobar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_aprobar(uuid, jsonb) to authenticated;
comment on function public.fn_bandeja_aprobar(uuid, jsonb) is 'c17: el «Así es» de una propuesta del «Dímelo» (solo el dueño, por la API): la registra fn_bandeja_hacer con la acción ya validada que se guardó y la frase de Edgar como motivo escrito. La IA nunca llega aquí.';

-- «NO, ES OTRA COSA»: la propuesta queda rechazada (con su motivo, si lo
-- hay) y el movimiento sigue en la Bandeja.
create or replace function public.fn_bandeja_rechazar(p_dimelo uuid, p_motivo text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  q       bandeja_dimelo;
begin
  v_quien := fn_bandeja_quien();
  select * into q from bandeja_dimelo where id = p_dimelo;
  if not found then
    raise exception using errcode = '22023', message = 'Esa propuesta no existe.';
  end if;
  if q.estado = 'pendiente' then
    perform set_config('mx_bandeja.escribe', 'bandeja_dimelo', true);
    update bandeja_dimelo
       set estado = 'rechazada', resuelto_por = v_quien, resuelto_el = now(),
           resuelto_motivo = coalesce(nullif(left(btrim(coalesce(p_motivo, '')), 300), ''), 'No, es otra cosa')
     where id = q.id;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  return jsonb_build_object('dimelo_id', q.id, 'estado', 'rechazada', 'movimiento_id', q.movimiento_id);
end $$;
revoke execute on function public.fn_bandeja_rechazar(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_rechazar(uuid, text) to authenticated;
comment on function public.fn_bandeja_rechazar(uuid, text) is 'c17: «No, es otra cosa»: rechaza una propuesta pendiente del «Dímelo»; el movimiento sigue en la Bandeja.';


-- ---------------------------------------------------------------------
-- 14. LO QUE LEE LA PANTALLA, de una vez: fn_bandeja_leer().
--     {version, config, categorias, cuentas_propias, prestamos, cuadrilla,
--      tarjetas: {<movimiento_id>: {clave, nombre, clase, rec, dimelo,
--      deshecho}}, grupos: [{clave, nombre, clase, n, total, movimientos,
--      rec, memoria, solo_ok}], solos: [lo que entró solo en 14 días],
--      recientes: [los últimos «Así es», para deshacer], memoria: [...],
--      ia_abiertas: [propuestas de la IA (c8) que siguen pendientes en
--      movimientos que esta capa ya registró: la pantalla las cierra],
--      parcial (cortó por reloj: faltan recomendaciones)}.
--     Solo lee; a quien no es el dueño no le devuelve nada.
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_leer(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg       bandeja_config;
  m         record;
  c         jsonb;
  rec       jsonb;
  dim       jsonb;
  ctx       jsonb;
  v_tarj    jsonb := '{}'::jsonb;
  v_lista   jsonb := '[]'::jsonb;
  v_grupos  jsonb;
  v_lotes   jsonb;
  v_fin     timestamptz := clock_timestamp() + interval '8 seconds';
  v_parcial boolean := false;
begin
  perform fn_bandeja_exigir_dueno();
  if current_user = 'service_role' then
    return null;
  end if;
  select * into cfg from bandeja_config where id = 1;
  ctx := jsonb_build_object('facturas', fn_bandeja_facturas());
  for m in select mb.id, mb.fecha, mb.monto, mb.desc_norm, mb.memo, mb.tipo_banco, mb.cheque, mb.propuesta
             from movimientos_banco mb where mb.estado = 'pendiente' order by mb.fecha, mb.id loop
    c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
    if clock_timestamp() > v_fin then
      v_parcial := true;
      rec := null;
    else
      rec := fn_bandeja_recomendar(m.id, ctx);
    end if;
    select jsonb_strip_nulls(jsonb_build_object('dimelo_id', q.id, 'estado', q.estado, 'frase', q.frase, 'accion', q.accion, 'datos', q.datos,
                                                'texto', q.texto, 'porque', q.porque, 'falta', q.falta, 'recordar', q.recordar,
                                                'pide_obra', case when q.estado = 'pendiente' and q.falta is not null then true end))
      into dim
      from bandeja_dimelo q
     where q.movimiento_id = m.id and q.estado in ('pendiente', 'sin_propuesta') and q.creado_el > now() - interval '7 days'
       and not exists (select 1 from bandeja_dimelo z where z.movimiento_id = q.movimiento_id and z.creado_el > q.creado_el)
     order by q.creado_el desc limit 1;
    if not found then
      dim := null;
    end if;
    v_tarj := v_tarj || jsonb_build_object(m.id::text, jsonb_strip_nulls(jsonb_build_object(
                'clave', c->>'clave', 'nombre', c->>'nombre', 'clase', c->>'clase', 'rec', rec, 'dimelo', dim,
                'deshecho', case when exists (select 1 from bandeja_hechos h where h.movimiento_id = m.id and h.deshecho_el is not null)
                                 then true end)));
    v_lista := v_lista || jsonb_build_object('id', m.id, 'monto', m.monto, 'clave', c->>'clave', 'nombre', c->>'nombre', 'clase', c->>'clase',
                                             'motivo', coalesce(m.propuesta->>'motivo', 'sin_propuesta'), 'acc', rec->>'accion',
                                             'cta', rec->'datos'->>'cuenta', 'pide', rec->'pide', 'pm', rec->'pide_motivo',
                                             'av', case when rec ? 'aviso' then true end);
  end loop;
  -- LOS GRUPOS: dos o más pendientes de la misma contraparte. La recomendación del grupo: lo que Edgar ya dijo, lo que sugiere
  -- el nombre, o lo que la IA propone para la mayoría (seis de cada diez con la misma cuenta).
  select coalesce(jsonb_agg(z.g order by z.n desc, z.total), '[]'::jsonb) into v_grupos
    from (select a.n, a.total,
                 jsonb_strip_nulls(jsonb_build_object(
                   'clave', a.clave, 'nombre', a.nombre, 'clase', a.clase, 'n', a.n, 'total', a.total, 'movimientos', a.movs,
                   'solo_ok', case when a.clase = 'comercio' then true end,
                   'memoria', (select jsonb_build_object('accion', bm.accion, 'datos', bm.datos, 'texto', bm.texto, 'solo', bm.solo)
                                 from bandeja_memoria bm where bm.clave = a.clave and bm.activa),
                   'rec', coalesce(
                     (select jsonb_strip_nulls(jsonb_build_object('accion', bm.accion, 'datos', bm.datos - 'obra', 'fuente', 'memoria',
                                                                  'obra', bm.datos->>'obra'))
                        from bandeja_memoria bm
                       where bm.clave = a.clave and bm.activa and bm.accion in ('gasto', 'personal', 'contratista')),
                     case when a.clase = 'comercio' and a.sg is not null
                          then jsonb_build_object('accion', a.sg->>'accion', 'fuente', 'nombre',
                                                  'datos', case when a.sg->>'accion' = 'gasto' then jsonb_build_object('cuenta', a.sg->>'cuenta')
                                                                else '{}'::jsonb end) end,
                     case when a.clase = 'comercio' and a.cta is not null and a.n_cta * 10 >= a.n * 6
                          then jsonb_build_object('accion', case when a.cta = '3200' then 'personal' else 'gasto' end, 'fuente', 'ia',
                                                  'datos', case when a.cta = '3200' then '{}'::jsonb
                                                                else jsonb_build_object('cuenta', a.cta) end) end))) as g
            from (select b.*, fn_bandeja_sugerida(b.nombre) as sg,
                         (select count(*) from jsonb_array_elements(v_lista) y where y->>'clave' = b.clave and y->>'cta' = b.cta) as n_cta
                    from (select x->>'clave' as clave, min(x->>'nombre') as nombre, min(x->>'clase') as clase, count(*) as n,
                                 sum((x->>'monto')::numeric) as total, jsonb_agg(x->>'id') as movs,
                                 mode() within group (order by x->>'cta') as cta
                            from jsonb_array_elements(v_lista) x
                           where x->>'clave' is not null and x->>'clase' in ('comercio', 'zelle_a', 'zelle_de', 'deposito', 'procesador')
                             -- (lo que el banco ya reconoce va en su lote; lo que se contesta en otra parte no entra en un grupo)
                             and x->>'acc' is distinct from 'banco' and x->>'av' is null
                           group by x->>'clave'
                          having count(*) >= 2) b) a) z;
  -- (el texto llano de la recomendación de cada grupo)
  select coalesce(jsonb_agg(case when g->'rec' is null then g else jsonb_set(g, '{rec,texto}', to_jsonb(
           case g->'rec'->>'accion'
             when 'personal' then 'Son tuyos, no de la empresa (retiro del accionista).'
             when 'contratista' then 'Son pagos a un subcontratista: te pregunto la obra de cada uno.'
             else format('Son «%s»%s.', fn_bandeja_cuenta_llana(g->'rec'->'datos'->>'cuenta'),
                         case when (select k.regla_obra from cuentas k where k.codigo = g->'rec'->'datos'->>'cuenta') = 'obligatoria'
                              then ': de qué obra, la del día de la cuadrilla en cada uno, o la que tú digas' else '' end) end)) end
           order by n), '[]'::jsonb)
    into v_grupos
    from jsonb_array_elements(v_grupos) with ordinality as t(g, n);
  -- LOS LOTES de c6: lo que c6 ya reconoce igual en varios (intereses, cargos del banco, cuotas): aceptar todos de una vez.
  select coalesce(jsonb_agg(z.g order by z.n desc), '[]'::jsonb) into v_lotes
    from (select count(*) as n,
                 jsonb_build_object('clave', 'M:' || (x->>'motivo'), 'clase', 'lote', 'n', count(*), 'total', sum((x->>'monto')::numeric),
                                    'movimientos', jsonb_agg(x->>'id'),
                                    'nombre', case x->>'motivo' when 'interes_tarjeta' then 'Intereses de la tarjeta'
                                                                when 'cargo_banco' then 'Cargos del banco'
                                                                when 'interes' then 'Intereses que paga el banco'
                                                                else 'Cuotas de préstamos' end,
                                    'rec', jsonb_build_object('accion', 'banco', 'fuente', 'banco',
                                                              'texto', 'El banco ya los reconoce: se registran todos como propone.')) as g
            from jsonb_array_elements(v_lista) x
           where x->>'motivo' in ('interes_tarjeta', 'cargo_banco', 'interes', 'cuota_prestamo') and x->>'acc' = 'banco'
             and x->>'pide' is null and x->>'pm' is null
           group by x->>'motivo'
          having count(*) >= 2) z;
  return jsonb_build_object(
    'version', fn_bandeja_version(),
    'config', jsonb_build_object('solo', cfg.solo, 'solo_tope', cfg.solo_tope, 'dimelo', cfg.dimelo,
                                 'c10', to_regprocedure('public.fn_jornal_pago(jsonb)') is not null, 'solo_ultimo', cfg.solo_ultimo),
    'categorias', fn_bandeja_categorias(),
    'cuentas_propias', fn_bandeja_cuentas_propias(),
    'prestamos', (select coalesce(jsonb_agg(jsonb_build_object('id', pr.id, 'prestamista', pr.prestamista) order by pr.creado_el), '[]'::jsonb)
                    from prestamos pr),
    'cuadrilla', case when to_regprocedure('public.fn_jornal_pago(jsonb)') is null then '[]'::jsonb
                      else (select coalesce(jsonb_agg(jsonb_build_object('usuario_id', pf.id, 'nombre', pf.nombre) order by pf.nombre), '[]'::jsonb)
                              from perfiles pf where pf.rol <> 'dueno' and coalesce(pf.activo, true)) end,
    'tarjetas', v_tarj,
    'grupos', v_lotes || v_grupos,
    'solos', (select coalesce(jsonb_agg(jsonb_build_object('hecho_id', h.id, 'movimiento_id', h.movimiento_id, 'fecha', mb.fecha,
                                                           'monto', h.monto, 'descripcion', mb.descripcion, 'texto', h.texto, 'el', h.el,
                                                           'asiento', a.numero, 'corrio', h.corrio) order by h.el desc), '[]'::jsonb)
                from bandeja_hechos h
                join movimientos_banco mb on mb.id = h.movimiento_id
                left join asientos a on a.id = h.asiento_id
               where h.solo and h.deshecho_el is null and h.el > now() - interval '14 days'),
    'recientes', (select coalesce(jsonb_agg(jsonb_build_object('hecho_id', x.id, 'movimiento_id', x.movimiento_id, 'fecha', x.fecha,
                                                               'monto', x.monto, 'descripcion', x.descripcion, 'texto', x.texto, 'el', x.el,
                                                               'fuente', x.fuente) order by x.el desc), '[]'::jsonb)
                    from (select h.id, h.movimiento_id, mb.fecha, h.monto, mb.descripcion, h.texto, h.el, h.fuente
                            from bandeja_hechos h
                            join movimientos_banco mb on mb.id = h.movimiento_id
                           where not h.solo and h.deshecho_el is null and h.el > now() - interval '3 days'
                             and mb.estado <> 'pendiente' and mb.asiento_id is not distinct from h.asiento_id
                           order by h.el desc limit 12) x),
    'memoria', (select coalesce(jsonb_agg(jsonb_build_object('clave', bm.clave, 'nombre', bm.nombre, 'clase', bm.clase, 'accion', bm.accion,
                                                             'texto', bm.texto, 'solo', bm.solo, 'veces', bm.veces) order by bm.nombre), '[]'::jsonb)
                  from bandeja_memoria bm where bm.activa),
    -- lo de la IA (c8) que quedó abierto en movimientos que esta capa ya registró: la pantalla lo cierra por la función de borde
    'ia_abiertas', (select coalesce(jsonb_agg(q.id order by q.creado_el), '[]'::jsonb)
                      from contador_propuestas q
                     where q.estado = 'pendiente'
                       and exists (select 1 from bandeja_hechos h join movimientos_banco mb on mb.id = h.movimiento_id
                                    where h.movimiento_id = q.movimiento_id and h.deshecho_el is null and mb.estado <> 'pendiente')),
    'parcial', v_parcial);
end $$;
revoke execute on function public.fn_bandeja_leer(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_leer(jsonb) to authenticated;
comment on function public.fn_bandeja_leer(jsonb) is 'c17: lo que la Bandeja nueva lee de una vez: la configuración, las categorías, las cuentas propias, los préstamos, la cuadrilla, la tarjeta de cada movimiento pendiente (contraparte, recomendación y propuesta del «Dímelo»), los grupos con su recomendación, lo que entró solo (14 días), lo último registrado y lo recordado. Solo lee.';


-- ---------------------------------------------------------------------
-- 15. EL CONTROL de esta capa (como el de c8 y c10: «cuadre» si es un
--     hecho que tiene que cumplirse siempre; «aviso» si es algo que mirar).
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_control()
returns table (orden int, control text, nivel text, ok boolean, filas bigint, esperadas bigint, detalle text)
language sql stable
set search_path = public, pg_temp
as $$
  with ve as (select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false) as si),
       cfg as (select * from bandeja_config where id = 1),
       vivo as (select h.*, mb.estado as mov_estado, mb.asiento_id as mov_asiento, mb.descripcion, mb.fecha
                  from bandeja_hechos h left join movimientos_banco mb on mb.id = h.movimiento_id
                 where h.deshecho_el is null)
  select z.orden, z.control, z.nivel, z.ok, z.filas, z.esperadas, z.detalle
    from ve
    cross join lateral (
      select 10 as orden, 'bandeja: la configuración (una fila)'::text as control, 'cuadre'::text as nivel,
             (select count(*) from cfg) = 1 as ok, (select count(*) from cfg) as filas, 1::bigint as esperadas,
             case when (select count(*) from cfg) <> 1 then 'falta la fila de bandeja_config: vuelve a pegar c17-bandeja.sql' end as detalle
      union all
      -- 20: lo que entró solo es SOLO lo permitido (un cargo de un comercio, hasta el tope de entonces no se sabe: se mira el de hoy ×10)
      select 20, 'bandeja: nada entró solo fuera de lo permitido', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → deshazlo en la Bandeja (Registrado solo → Deshacer) y avisa' end
        from (select count(*) as n, left(string_agg(format('%s %s «%s»', v.fecha, v.monto, coalesce(v.descripcion, '')), '; '), 1200) as d
                from vivo v
               where v.solo and (v.monto >= 0 or v.accion not in ('gasto', 'personal') or coalesce(v.memoria_clave, '') not like 'C:%'
                                 or abs(v.monto) > 5000)) t
      union all
      -- 30: una propuesta del «Dímelo» aprobada tiene su registro
      select 30, 'bandeja: cada propuesta aprobada del «Dímelo» tiene su registro', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then format('%s propuesta(s) aprobada(s) sin su registro en bandeja_hechos', t.n) end
        from (select count(*) as n from bandeja_dimelo q
               where q.estado = 'aprobada' and not exists (select 1 from bandeja_hechos h where h.id = q.hecho_id)) t
      union all
      -- 40: permisos: ninguna función de la capa es SECURITY DEFINER, las tablas con RLS, y anon no ejecuta nada
      select 40, 'bandeja: permisos (sin SECURITY DEFINER, RLS, nada para anon)', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → vuelve a pegar c17-bandeja.sql' end
        from (select count(*) as n, left(string_agg(x.que, '; '), 1200) as d
                from (select 'SECURITY DEFINER: ' || p.proname as que
                        from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_bandeja\_%' and p.prosecdef
                      union all
                      select 'anon ejecuta ' || p.proname
                        from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_bandeja\_%'
                         and has_function_privilege('anon', p.oid, 'execute')
                      union all
                      select 'la API ejecuta ' || p.proname
                        from pg_proc p where p.pronamespace = 'public'::regnamespace
                         and p.proname in ('fn_bandeja_dimelo_contexto', 'fn_bandeja_dimelo_guardar', 'fn_bandeja_solo_programado',
                                           'fn_bandeja_precondiciones', 'fn_bandeja_guarda')
                         and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'))
                      union all
                      select 'sin RLS: ' || k.relname
                        from pg_class k where k.relnamespace = 'public'::regnamespace
                         and k.relname in ('bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos') and not k.relrowsecurity
                      union all
                      select 'anon lee ' || k.relname
                        from pg_class k where k.relnamespace = 'public'::regnamespace
                         and k.relname in ('bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos')
                         and (has_table_privilege('anon', k.oid, 'select') or has_table_privilege('service_role', k.oid, 'select'))) x) t
      union all
      -- 50: una regla «que entre solo» es de un comercio y de gasto o personal (lo impide la tabla; aquí se ve)
      select 50, 'bandeja: las reglas «que entre solo» son de comercios', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d end
        from (select count(*) as n, left(string_agg(bm.clave, '; '), 600) as d
                from bandeja_memoria bm where bm.solo and not (bm.clase = 'comercio' and bm.accion in ('gasto', 'personal'))) t
      union all
      -- 60 (aviso): lo registrado que alguien des-casó por otro lado (sigue marcado como hecho)
      select 60, 'bandeja: lo registrado sigue como se dejó', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → se des-casó fuera de la Bandeja: vuelve a contestarlo allí' end
        from (select count(*) as n, left(string_agg(format('%s %s «%s»', v.fecha, v.monto, coalesce(v.descripcion, '')), '; '), 1200) as d
                from vivo v
               where v.mov_estado is null or v.mov_estado = 'pendiente' or v.mov_asiento is distinct from v.asiento_id) t
      union all
      -- 70 (aviso): dinero de un préstamo registrado sin que el préstamo esté dado de alta
      select 70, 'bandeja: los préstamos recibidos están dados de alta', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → da de alta el préstamo con su contrato (fn_prestamo_guardar, en el SQL Editor): sin eso sus cuotas no se reparten entre capital e intereses' end
        from (select count(*) as n, left(string_agg(format('%s %s de %s', v.fecha, v.monto, coalesce(v.datos->>'prestamista', '?')), '; '), 800) as d
                from vivo v
               where v.accion = 'prestamo' and not (v.datos ? 'prestamo_id')
                 and not exists (select 1 from prestamos p
                                  where upper(p.prestamista) like '%' || upper(split_part(coalesce(v.datos->>'prestamista', '¿'), ' ', 1)) || '%')) t
      union all
      -- 80 (aviso): la tarea que registra sola falló la última vez
      select 80, 'bandeja: la tarea que registra sola', 'aviso', (select (c.solo_ultimo->>'error') is null from cfg c), 0, 0,
             (select 'la última corrida falló: ' || (c.solo_ultimo->>'error') from cfg c where c.solo_ultimo ? 'error')
      union all
      -- 90 (aviso): lo de la IA (c8) que sigue pendiente en un movimiento que la Bandeja ya registró (la pantalla lo cierra
      --     al abrirse, y la tarea lo suyo; si queda, el cierre del mes lo cuenta como «esperando tu toque»)
      select 90, 'bandeja: ninguna propuesta de la IA abierta en lo ya registrado', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then format('%s propuesta(s) de la IA siguen pendientes en movimientos que ya se registraron desde la Bandeja → abre la Bandeja con el código del teléfono: se cierran solas', t.n) end
        from (select count(*) as n from contador_propuestas q
               where q.estado = 'pendiente'
                 and exists (select 1 from vivo v where v.movimiento_id = q.movimiento_id and v.mov_estado is distinct from 'pendiente'
                                                    and v.mov_estado is not null)) t
    ) z
   where ve.si
$$;
revoke execute on function public.fn_bandeja_control() from public, anon, service_role;
grant  execute on function public.fn_bandeja_control() to authenticated;
comment on function public.fn_bandeja_control() is 'c17: el control de la Bandeja nueva: la configuración, que nada entró solo fuera de lo permitido, que cada propuesta aprobada tiene su registro, los permisos y las reglas «que entre solo» (cuadres), y lo registrado que se des-casó por fuera, los préstamos sin dar de alta, la tarea y lo de la IA que quedó abierto en lo ya registrado (avisos).';

drop view if exists public.v_bandeja_control;
create view public.v_bandeja_control with (security_invoker = true) as
  select * from public.fn_bandeja_control();
revoke all on public.v_bandeja_control from public, anon, authenticated, service_role;
grant select on public.v_bandeja_control to authenticated;
comment on view public.v_bandeja_control is 'c17: el control de la Bandeja nueva (fn_bandeja_control): una fila por cuadre o aviso.';


-- ---------------------------------------------------------------------
-- 16. Lo que debe verse al pegar: fn_bandeja_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_bandeja_pegado() returns table (que text, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_cron text := 'no hay pg_cron en esta base (el banco de pruebas): la rutina corre al abrir la Bandeja';
  v_rojo text;
  v_n    int;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  -- (cron.job solo existe donde hay pg_cron: por eso va con execute. Si falta alguna de las dos, la fila NO empieza por «ok»)
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    begin
      execute $q$ select case when count(*) = 2 then 'ok: ' else 'FALTA alguna de las dos tareas (vuelve a pegar este archivo): ' end
                         || coalesce(string_agg(j.jobname || ' («' || j.schedule || '»)', ', ' order by j.jobname), 'no hay ninguna programada')
                    from cron.job j where j.jobname in ('mxp-bandeja-solo-manana', 'mxp-bandeja-solo-tarde') $q$ into v_cron;
    exception when others then
      v_cron := format('no se pudo leer pg_cron (%s): lo que tiene que entrar solo entra igual al abrir la Bandeja', sqlstate);
    end;
  end if;
  select string_agg(c.control || coalesce(': ' || c.detalle, ''), ' · ') into v_rojo from fn_bandeja_control() c where c.nivel = 'cuadre' and not c.ok;
  select count(*) into v_n from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_bandeja\_%';
  return query
  select 'version'::text, 'ok: ' || fn_bandeja_version()
  union all
  select 'tablas', case when (select count(*) from pg_class k where k.relnamespace = 'public'::regnamespace and k.relkind = 'r'
                                 and k.relname in ('bandeja_config', 'bandeja_memoria', 'bandeja_dimelo', 'bandeja_hechos') and k.relrowsecurity) = 4
                        then 'ok: bandeja_config, bandeja_memoria, bandeja_dimelo y bandeja_hechos, con RLS' else 'FALTA alguna tabla o su RLS' end
  union all
  select 'funciones', 'ok: ' || v_n || ' funciones fn_bandeja_*, ninguna SECURITY DEFINER'
  union all
  select 'configuracion', (select format('ok: lo de «entra solo» %s (tope %s); «Dímelo» %s (esfuerzo %s)',
                                         case when g.solo then 'encendido' else 'apagado' end, fn_bandeja_usd(g.solo_tope),
                                         case when g.dimelo then 'encendido' else 'apagado' end, g.dimelo_effort)
                             from bandeja_config g where g.id = 1)
  union all
  select 'categorias', 'ok: ' || (select count(*) from jsonb_array_elements(fn_bandeja_categorias())) || ' grupos, '
                       || (select count(*) from jsonb_array_elements(fn_bandeja_categorias()) g, jsonb_array_elements(g->'sub')) || ' categorías'
  union all
  select 'tareas', v_cron
  union all
  select 'control', case when v_rojo is null then 'ok: los cuadres de la Bandeja están en verde' else 'ROJO: ' || v_rojo end
  union all
  select 'siguiente', 'ok: ahora vuelve a desplegar la función «contador» (trae la acción «dimelo») y publica la app';
end $$;
revoke execute on function public.fn_bandeja_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_pegado() is 'c17: lo que debe verse al pegar c17-bandeja.sql: una fila por pieza, todas «ok».';

-- (cada función de la capa lleva su comentario «c17: …»: la precondición lo usa para no pisar nada ajeno)
do $$
declare
  v text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into v
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_bandeja\_%'
     and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c17: %';
  if v is not null then
    raise exception using errcode = 'MX000', message = 'c17-bandeja: funciones sin su comentario «c17: …»: ' || v;
  end if;
end $$;

select * from public.fn_bandeja_pegado();
