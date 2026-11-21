-- =====================================================================
-- c17-bandeja.sql — LA BANDEJA NUEVA (Fase 7, «Dímelo con tus palabras»).
-- 21-nov-2026 (tercera vuelta, tras la segunda revisión: marca 2026112103).
-- Se pega en el SQL Editor de Supabase DESPUÉS de c1…c16 (pide c1, c2, c3, c6 y c8;
-- c10 y lo demás, si están, se usan). No cambia ninguna capa anterior: no
-- toca sus tablas, sus funciones ni sus permisos; todo lo de aquí se llama
-- bandeja_*, fn_bandeja_* y v_bandeja_*.
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
-- Y arriba, POR COMERCIO: una decisión para todos los CARGOS de un mismo
-- comercio (los depósitos se contestan de uno en uno: cada uno paga sus
-- facturas), y lo que llegue después de ese comercio y NO lleve obra puede
-- entrar solo («Registrado solo», con «Deshacer»).
--
-- LAS CUATRO REGLAS QUE NO SE NEGOCIAN
--   · LA IA PROPONE Y NUNCA POSTEA. Lo que contesta se valida aquí contra la
--     lista cerrada, las cuentas, las obras, las facturas y los montos de la
--     base (fn_bandeja_validar) y queda guardado como propuesta. El asiento
--     lo hace una puerta de c6 (o de c10), con sus guardas de siempre, y solo
--     cuando el dueño toca «Así es» (fn_bandeja_aprobar, por la API, con su
--     sesión y su código del teléfono). El texto que Edgar lee lo escribe
--     ESTA capa con los datos ya validados; lo que la IA explica va aparte,
--     marcado como suyo. Lo que la IA diga de «recordarlo» solo deja marcada
--     la casilla: recordar lo decide Edgar.
--   · LO QUE ESCRIBE EL BANCO Y LO QUE ESCRIBE EDGAR SON DATOS, nunca
--     instrucciones: van en el mensaje, no en las instrucciones (tampoco lo
--     ya recordado, que lleva el nombre que escribió el banco), y todo pasa
--     antes por la máscara (fn_bandeja_sin_datos: la de c8 —correos,
--     teléfonos, números de cuenta— y además el número que va detrás de la
--     palabra que dice lo que es —cuenta, tarjeta, ssn…—, una tarjeta
--     escrita en grupos, un SSN o un ITIN, un EIN y un teléfono de siete
--     dígitos; el nombre de quien paga por Zelle sale de la descripción ya
--     tapada: a veces es un correo). Lo que la IA escribe y Edgar va a leer
--     se guarda sin enlaces.
--   · UN MOTIVO NO SE INVENTA NI SE HEREDA. Las puertas de c6 frenan lo que
--     puede estar dos veces en el libro o va a donde no debe («si de verdad
--     es otra cosa, dilo en el motivo»): para c6, un motivo escrito es «lo
--     leí y aun así». Por eso aquí la puerta se llama SIEMPRE PRIMERO SIN
--     MOTIVO; si frena, la tarjeta enseña lo que dijo, en llano, y solo
--     entonces deja escribir un porqué, que viaja con la huella de ESE freno
--     (fn_bandeja_hacer: «visto»). La frase que Edgar le dijo a la IA no es
--     un motivo; la línea que esta capa escribe en «es mío» (c6 la pide
--     siempre) solo se usa después de ENSAYAR la puerta sin motivo
--     (fn_bandeja_ensayo); y una opción de c6 se registra solo si sigue
--     siendo la que se enseñó (su huella), no la que hoy ocupe su número.
--     Y ESTA CAPA TIENE SU PROPIO FRENO: cuando el banco mismo dice que un
--     depósito lo pone un prestamista, o el propio Edgar, cualquier
--     respuesta que lo trate como dinero de un cliente (el cobro de una
--     factura, un anticipo, un ingreso, el botón del banco que cobra) frena
--     igual, con su huella, venga de la lista, de la IA o de un botón.
--   · NADA INSEGURO ENTRA SOLO. Solo entra solo un CARGO de un comercio con
--     una regla que Edgar puso con «que entre solo», de algo personal o de un
--     gasto que NO LLEVA OBRA, hasta el tope de bandeja_config.solo_tope,
--     cuando c6 no tiene nada mejor que decir de él (su motivo es «sin
--     ticket»), no parece un duplicado, y la puerta de c6, HOY y sin motivo,
--     lo acepta. Un costo de obra, un depósito, un Zelle, un cheque, un
--     retiro de cajero, la nómina, un traspaso o un préstamo NUNCA entran
--     solos por esta capa: solo se proponen. (Los Zelle a la cuadrilla los
--     registra c10 con sus propias reglas, si Edgar las tiene encendidas:
--     «la cuadrilla, sola»; esta capa no los toca.) Lo que Edgar YA contestó
--     no lo cambia nadie más que él: el recibo que llega después de
--     registrar su cargo se pregunta (arriba, de un toque), no se cambia
--     solo. Y deshacer una respuesta apaga «que lo siguiente entre solo» de
--     ese comercio.
--
-- LA LISTA CERRADA (lo que el banco ya sabe registrar; cada una, su puerta):
--   gasto         un gasto o un costo (o, en un cargo, la compra de un
--                 equipo), con su obra si la cuenta la pide
--                 (fn_banco_clasificar). En un depósito es la devolución de
--                 una compra.
--   personal      un cargo personal pagado desde la empresa: retiro del
--                 accionista, 3200 (fn_banco_clasificar, con la línea de
--                 esta capa, después del ensayo). En un depósito es la
--                 devolución de algo suyo (baja lo retirado), con su línea
--                 escrita.
--   cobro         el cobro de una o varias facturas con saldo en el libro
--                 (entero, una parte, o su retención), con la comisión del
--                 procesador si llegó neto y quien deposita ES un procesador
--                 (fn_banco_cobrar); la factura queda cobrada también en
--                 Proyectos.
--   anticipo      el anticipo de una obra, dinero a cuenta sin aplicarlo a
--                 ninguna factura (fn_banco_cobrar con la obra).
--   prestamo      dinero que entra de un prestamista: deuda, no un cobro
--                 (fn_banco_clasificar a la cuenta del préstamo).
--   aporte        dinero de Edgar a la empresa: préstamo del accionista
--                 (2900) o aportación (3100), con su línea escrita.
--   traspaso      dinero entre cuentas propias, o el pago de la tarjeta
--                 (fn_banco_transferencia).
--   cuadrilla     el pago a alguien de la cuadrilla: lo reparte c10 por sus
--                 horas (fn_jornal_pago). Solo con c10.
--   contratista   el pago a un subcontratista por una obra (5200, con la
--                 obra y, si se sabe, el proveedor).
--   otro_ingreso  otros ingresos (4900) o intereses del banco (4910), con su
--                 línea escrita.
--   banco         una de las opciones que c6 ya propone para ESE movimiento
--                 (casar con lo que ya está en el libro, la cuota de un
--                 préstamo, un cheque devuelto, un duplicado, el recibo que
--                 llegó después…): se llama tal cual la guardó c6, nunca con
--                 argumentos que vengan de fuera, y solo si es la misma que
--                 se enseñó.
--   falta         nada que registrar: dice qué falta.
-- Nada más. Ignorar un movimiento, el use tax, la nómina o un asiento a mano
-- no están en la lista: siguen donde estaban.
--
-- UNA SOLA APP (lo que esta capa conecta con Proyectos)
--   · La factura que Edgar marcó cobrada en Proyectos es la respuesta del
--     depósito que la paga: va primero entre las candidatas. La respuesta
--     tiene que ser ÚNICA entre TODAS las facturas con saldo (no entre las
--     más cercanas): una sola, o el lote de un procesador de tarjetas (hasta
--     4 facturas) con la comisión que ese procesador cobra de verdad,
--     factura a factura (bandeja_config.tarifas: todas las de la lista se
--     prueban siempre, las que Edgar ya confirmó delante; una que no está
--     se apunta solo de un LOTE de dos facturas o más con un tanto por
--     ciento limpio, y se puede olvidar). Una comisión que ninguna tarifa
--     explica no se recomienda («aproximado» cerraba la factura que no
--     era). Con dos respuestas posibles no se recomienda ninguna. Y el
--     cobro que YA estaba anotado y espera su depósito va antes que
--     cualquier factura.
--   · Al registrar un cobro (también por una opción de c6), Proyectos queda
--     al día: la factura sin saldo, cobrada (pagada, cobrada_el); la pagada
--     a cuenta, con su abono; y «Cobrado» de la obra sube lo que haga falta.
--     Deshacer deja Proyectos como dice el libro en ese momento (con dos
--     pagos a cuenta, lo que quede del otro) y le resta a «Cobrado» lo que
--     ese registro le sumó.
--   · Un depósito de un prestamista (los de la tabla prestamos, por su
--     descriptor o su nombre entero, y las marcas corrientes del oficio) se
--     propone como préstamo ANTES de mirar facturas; el dinero que manda el
--     propio Edgar, como dinero suyo: nunca como el pago de un cliente (y
--     si Edgar contesta que sí lo es, frena: el freno de esta capa).
--   · Un cargo de un comercio de obra, sin recibo, en un día en que la
--     cuadrilla reportó horas en UNA sola obra: se PROPONE esa obra.
--   · El recibo subido a una obra sigue casando su cargo con esa obra por c6
--     («primero casar»). Y si el recibo llega DESPUÉS de registrar el cargo
--     aquí, la Bandeja lo enseña arriba con «Es su recibo: cámbialo» (el
--     gasto queda una vez, en la obra del recibo) / «Es otra compra»: se
--     contesta de un toque, y nada se cambia solo (fn_bandeja_recibos solo
--     pide a c6 que lo mire: para c6, un cargo pendiente con un recibo libre
--     de su monto ES el de ese recibo, y lo cambiado solo no tenía vuelta).
--   · El pago a la cuadrilla que repartió c10 se deshace por la puerta de
--     c10 (su reparto queda deshecho).
--
-- LAS CATEGORÍAS EN DOS NIVELES (fn_bandeja_categorias): lo que Edgar ve.
--   Gastos:   Costo de obra · Gastos generales · Otros gastos · Personal
--   Ingresos: Cobro de obra · Otros ingresos · Préstamo o aporte · Entre tus
--             cuentas
-- La cuenta exacta la pone la app (la de la categoría, la de la regla de ese
-- comercio o la que sugiere la descripción del banco) y se puede cambiar en
-- la tarjeta.
--
-- LO QUE SE RECUERDA (bandeja_memoria): por contraparte del banco (el
-- comercio, a quién va o de quién viene un Zelle, quién deposita —nunca el
-- canal del pago ni un procesador de tarjetas, que deposita lo de muchos—),
-- lo que Edgar dijo que es. La próxima vez SE PROPONE con eso; entra solo
-- únicamente lo del párrafo «nada inseguro». Una regla nunca fija una obra:
-- la obra se propone cada vez (la del día de la cuadrilla) o se pregunta.
-- Un ayuntamiento o un condado cobran cosas distintas con el mismo nombre
-- (la luz, un permiso): son contrapartes distintas. Y lo recordado de un
-- comercio no se aplica (ni entra solo) cuando la descripción de ahora
-- sugiere otra cosa que la de cuando Edgar lo dijo.
--
-- CON LA BANDEJA LLENA (tercera vuelta). La API corta cada llamada a los 8
-- segundos y producción va unas diez veces más despacio que el banco de
-- pruebas. Por eso:
--   · fn_bandeja_leer recomienda POR UNIDADES (un grupo de cargos, entero;
--     lo demás, de uno en uno) y por reloj (2.5 s de fábrica): lo que no dio
--     tiempo vuelve en «faltan», con su tarjeta «pensando», y la pantalla lo
--     pide otra vez con {ids} (solo lo pedido se mira). Siempre al menos una
--     unidad por llamada: avanza.
--   · decidir un grupo, deshacer una tanda y la rutina que registra sola
--     cortan por su reloj (3 s) y dicen «sigue»; la pantalla llama otra vez.
--   · nada de expresiones regulares en lo que se hace por cada tarjeta
--     (Postgres guarda compiladas solo 32: con más, se recompilaban todas
--     en cada movimiento).
-- Lo mide pruebas/conta/c17-volumen.sh con 400 y con 1,000 pendientes.
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
                 ('tarjetas', 'cuenta'), ('tarjetas', 'activa'), ('tarjetas', 'ultimos4'), ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('perfiles', 'nombre'), ('recibos', 'contabilizado_en'), ('facturas', 'cobrado'),
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
as $$ select 2026112103::bigint $$;
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
-- llegue después (solo un comercio, y solo algo personal o un gasto que NO
-- lleva obra: lo comprueba fn_bandeja_recordar). No se borra: se da de baja
-- (activa = false).
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
  constraint bandeja_memoria_solo   check (not solo or (clase = 'comercio' and accion in ('gasto', 'personal') and not (datos ? 'obra')))
);
comment on table public.bandeja_memoria is 'c17: lo que Edgar ya dijo de una contraparte del banco (el comercio, el destinatario o el remitente de un Zelle, quien deposita): la acción de la lista cerrada y sus datos (sin obra fija ni factura). La próxima vez se propone con eso; «solo» (que entre solo) únicamente un comercio con algo personal o con un gasto que no lleva obra.';

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
-- (21-nov, segunda vuelta) Lo que se añade a las tablas de arriba; con «if not
-- exists»: volver a pegar no pisa nada.
--   bandeja_config.tarifas   lo que se queda cada procesador de tarjetas por
--     cada cobro: [{proc, pct, fijo, tope?}]. Con ellas se reconoce el LOTE de
--     un procesador (qué facturas junta un depósito neto de comisiones) al
--     centavo, factura a factura, y no «lo que quepa hasta un 3.5 %». Las de
--     fábrica son las públicas de cada uno; la que no esté se aprende del
--     primer lote que Edgar confirme (origen «aprendida»).
--   bandeja_hechos.tanda     la decisión de grupo a la que pertenece un
--     registro («Así es para los 25»): se deshace entera, con un solo motivo.
alter table public.bandeja_config add column if not exists tarifas jsonb not null default '[
  {"proc": "INTUIT", "pct": 2.99, "fijo": 0},    {"proc": "INTUIT", "pct": 2.5, "fijo": 0},
  {"proc": "INTUIT", "pct": 3.5, "fijo": 0},     {"proc": "INTUIT", "pct": 1, "fijo": 0},
  {"proc": "INTUIT", "pct": 1, "fijo": 0, "tope": 15},
  {"proc": "INTUIT", "pct": 2.9, "fijo": 0.25},  {"proc": "INTUIT", "pct": 2.4, "fijo": 0.25},
  {"proc": "INTUIT", "pct": 3.4, "fijo": 0.25},
  {"proc": "STRIPE", "pct": 2.9, "fijo": 0.30},  {"proc": "STRIPE", "pct": 0.8, "fijo": 0, "tope": 5},
  {"proc": "SQUARE", "pct": 2.6, "fijo": 0.15},  {"proc": "SQUARE", "pct": 2.6, "fijo": 0.10},
  {"proc": "SQUARE", "pct": 2.9, "fijo": 0.30},  {"proc": "SQUARE", "pct": 3.3, "fijo": 0.30},
  {"proc": "SQUARE", "pct": 3.5, "fijo": 0.15},
  {"proc": "PAYPAL", "pct": 3.49, "fijo": 0.49}, {"proc": "PAYPAL", "pct": 2.99, "fijo": 0.49},
  {"proc": "CLOVER", "pct": 2.6, "fijo": 0.10},  {"proc": "CLOVER", "pct": 3.5, "fijo": 0.10}]'::jsonb;
alter table public.bandeja_hechos add column if not exists tanda uuid;
create index if not exists bandeja_hechos_tanda_idx on public.bandeja_hechos (tanda) where tanda is not null;
-- (21-nov, tercera vuelta)
--   bandeja_memoria.sugerida   lo que SUGERÍA la descripción del banco del
--     movimiento con que Edgar enseñó esa regla («gasto|6110»; nulo: nada). Lo
--     recordado vale para lo que el banco describe como entonces: si la
--     descripción de ahora sugiere OTRA cosa que la de entonces (la factura de
--     la luz y el permiso de obra de una misma ciudad, que comparten nombre),
--     lo recordado no se aplica ni entra solo: se propone por la descripción.
alter table public.bandeja_memoria add column if not exists sugerida text;
--   bandeja_memoria.privado    el nombre de esa contraparte sale de un CORREO
--     (un Zelle a o de «alguien@…»): es de aquí, para reconocer su próximo
--     movimiento, pero no va a la IA (lo ya enseñado se le manda sin él).
alter table public.bandeja_memoria add column if not exists privado boolean not null default false;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bandeja_config_tarifas' and conrelid = 'public.bandeja_config'::regclass) then
    alter table public.bandeja_config add constraint bandeja_config_tarifas check (jsonb_typeof(tarifas) = 'array');
  end if;
  -- una regla «que entre solo» NO lleva obra (apartado 12): lo que hubiera de antes deja de entrar solo, y la tabla lo impide
  if exists (select 1 from pg_constraint where conname = 'bandeja_memoria_solo' and conrelid = 'public.bandeja_memoria'::regclass
                and pg_get_constraintdef(oid) not like '%obra%') then
    perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
    update public.bandeja_memoria set solo = false where solo and datos ? 'obra';
    perform set_config('mx_bandeja.escribe', '', true);
    alter table public.bandeja_memoria drop constraint bandeja_memoria_solo;
    alter table public.bandeja_memoria add constraint bandeja_memoria_solo
      check (not solo or (clase = 'comercio' and accion in ('gasto', 'personal') and not (datos ? 'obra')));
  end if;
end $$;


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
-- ni sus ejemplos entre paréntesis, sin nombres de argumentos («(p_notas)»)
-- ni códigos sueltos entre paréntesis («(categoria_borrador)», «(1050)»),
-- sin «· 6130» detrás de una cuenta ni «(con su motivo)». Lo que queda es
-- lo que Edgar puede leer.
create or replace function public.fn_bandeja_llano(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select nullif(btrim(regexp_replace(
           regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace(
                       regexp_replace(coalesce(p, ''), '\s*\([^()]*(fn_|puentes_bandeja|\{"|select |\mp_[a-z_]+)[^()]*\)', '', 'g'),
                       '\s*\((con su motivo( escrito)?|[a-z]+(_[a-z0-9]+)+)\)', '', 'g'),
                     '\s*\([0-9]{4}(-[0-9]{4})?(\s*(/|,|y|o)\s*[0-9]{4}(-[0-9]{4})?)*(,[^()]*)?\)', '', 'g'),
                   '\s*·\s*[0-9]{4}(-[0-9]{4})?\M', '', 'g'),
                 '\mfn_[a-z0-9_]+\M', 'la app', 'g'),
               'dilo en (el motivo|las notas)|di por qué en las notas', 'escribe por qué', 'g'),
             'la bandeja de los puentes', 'la lista de recibos por completar', 'g'),
           '\s{2,}', ' ', 'g')), '')
$$;
revoke execute on function public.fn_bandeja_llano(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_llano(text) to authenticated;
comment on function public.fn_bandeja_llano(text) is 'c17: un texto de c6 sin jerga (nombres de funciones y de argumentos, códigos entre paréntesis o detrás de una cuenta, «con su motivo»).';

-- LO QUE DICE UNA PUERTA DE c6 CUANDO FRENA, en llano. Las puertas del banco
-- frenan con frases escritas para quien usa el SQL Editor («cásalo
-- (fn_banco_casar_con)…, dilo en el motivo»). Aquí cada freno conocido tiene
-- su frase para Edgar, con lo que importa (qué recibo, qué factura, cuánto)
-- y sin nombres de funciones ni códigos; el que no se conoce pasa por
-- fn_bandeja_llano. Es el texto que la tarjeta enseña ANTES de dejar escribir
-- un motivo (ver «EL FRENO», en el apartado 10). p_c6: lo que c6 pensaba del
-- movimiento (el motivo de su propuesta). Con él, el freno de un depósito
-- dice lo que hay de verdad: c6 frena igual «una factura por ese monto», «un
-- cobro ya anotado» y «alguna factura mayor que el depósito, por si fuera
-- una parte» (deposito_parcial), y en producción, con facturas abiertas, lo
-- último sale en casi todo depósito que no es un cobro (el efectivo del
-- cajero, dinero de Edgar): decir ahí «hay una factura que explica este
-- depósito» no era verdad.
drop function if exists public.fn_bandeja_freno_llano(text);
create or replace function public.fn_bandeja_freno_llano(p text, p_c6 text default null) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v  text := coalesce(p, '');
  m  text[];
  d  text;
  c_si constant text := ' Si de verdad es otra cosa, escribe por qué.';
begin
  if v = '' then
    return 'El banco no lo aceptó.';
  end if;
  -- su recibo, del día D por T (lo que c6 escribe «el recibo 123 del 2026-11-05 por 107.00»)
  m := regexp_match(v, 'el recibo [0-9]+ del ([0-9]{4}-[0-9]{2}-[0-9]{2}) por ([0-9]+(?:\.[0-9]+)?)');
  d := case when m is not null then format(' (el del %s por %s)', fn_bandeja_dia(m[1]::date), fn_bandeja_usd(m[2]::numeric)) else '' end;
  if v ~ '^Su ticket ya está subido' then
    return format('Ya subiste el recibo de esta compra%s y le falta un dato para entrar al libro. Cuando lo termines, este cargo se casa solo '
                  'con él y con su obra; si lo registro ahora, el gasto quedaría dos veces. Si de verdad es otra compra, escribe por qué.', d);
  elsif v ~ '^Puede ser su ticket con OTRO total' then
    return format('Hay un recibo que se le parece, pero con otro total%s. ¿Se leyó sin el impuesto? Corrige el total del recibo en la app y '
                  'este cargo se casa solo con él; si lo registro ahora, el gasto quedaría dos veces. Si de verdad es otra compra, escribe '
                  'por qué.', d);
  elsif v ~ '^Este movimiento casa solo' then
    return 'Esto ya estaba en el libro y casa solo con ello: no hay que registrarlo otra vez. Toca «Casar otra vez», arriba.';
  elsif v ~ '^Esto ya está en el libro' then
    return format('Esto ya está en el libro%s: no hay que registrarlo otra vez (quedaría dos veces). Toca «Casar otra vez», arriba, o cásalo '
                  'en «Más opciones».', case when v ~ 'el recibo' then replace(d, ' (el', ' (su recibo,') when v ~ 'un cobro' then ' (un cobro ya anotado)'
                                             when v ~ 'la transferencia' then ' (un traspaso ya registrado)' else '' end);
  elsif v ~ '^Puede ser esto del libro' then
    return 'Puede ser algo que ya está en el libro por el mismo monto (un cheque que tardó en cobrarse). Si lo es, cásalo con él en «Más '
           'opciones»: registrarlo aquí lo pondría dos veces.' || c_si;
  elsif v ~ '^Ya está registrada' then
    return 'La cuota de ese préstamo ya está registrada y espera su cargo del banco: cásala con él en «Más opciones». Registrarla aquí la '
           'pondría dos veces.' || c_si;
  elsif v ~ 'Un anticipo de la obra dejaría' then
    return 'Hay facturas por cobrar que explican este depósito: un anticipo las dejaría sin cobrar y al cliente con un saldo a favor que no '
           'es. Si es el pago de esas facturas, regístralo como su cobro. Si de verdad es un anticipo, escribe por qué.';
  elsif v ~ '(propone un cobro o una factura que explica este depósito|Este depósito lo explica)' then
    m := regexp_match(v, 'la factura #(\S+) \([^)]*\), abierta por ([0-9]+(?:\.[0-9]+)?)');
    if m is null and v !~ 'el cobro del' and p_c6 = 'deposito_parcial' then
      -- (c6 solo SUPONE un pago a cuenta: ninguna factura tiene ese monto)
      return 'Hay facturas por cobrar mayores que este depósito: podría ser una parte de una de ellas (un pago a cuenta). Si lo es, '
             'regístralo como el cobro de esa factura.' || c_si;
    end if;
    return format('Hay %s que explica este depósito. Si es el pago de un cliente, regístralo como %s.%s',
                  case when m is not null then format('una factura por cobrar (la #%s, por %s)', m[1], fn_bandeja_usd(m[2]::numeric))
                       when v ~ 'el cobro del' or p_c6 in ('deposito_cobro', 'deposito_cobros', 'deposito_otro_cobro')
                         then 'un cobro ya anotado, sin su depósito,'
                       when p_c6 = 'deposito_sin_cobro' then 'una factura por cobrar por ese mismo monto'
                       else 'una factura por cobrar (o un cobro ya anotado)' end,
                  case when v ~ 'el cobro del' or p_c6 in ('deposito_cobro', 'deposito_cobros', 'deposito_otro_cobro')
                       then 'el depósito de ese cobro (está en «Más opciones»)' else 'el cobro de esa factura' end, c_si);
  elsif v ~ 'es del patrimonio del accionista' then
    return 'Es dinero tuyo (lo que sacas de la empresa o pones en ella): escribe en una línea de qué es, para que quede en el libro.'
           || case when v ~ 'este depósito lo explica' then ' Ojo: hay una factura por cobrar por ese mismo monto; si es el pago de un cliente, es su cobro.'
                   else '' end;
  elsif v ~ '^Es un depósito devuelto' then
    return 'Parece un cheque que el banco devolvió: se devuelve su cobro (en «Más opciones») y la factura vuelve a quedar por cobrar. No es '
           'un gasto.' || c_si;
  elsif v ~ '^Es un (débito|depósito) de nómina' then
    return 'Es de la nómina (Gusto): se casa desde Contabilidad → Nómina, no aquí.' || c_si;
  elsif v ~ '(partida en tránsito de la conciliación de apertura|lo que QuickBooks tenía en tránsito)' then
    return 'Puede ser algo que venía de QuickBooks, de antes del 1 de octubre: ya está contado en el saldo con que arrancó la app, y '
           'registrarlo lo pondría dos veces.' || c_si;
  elsif v ~ 'es dinero entre cuentas propias, una transferencia' then
    return 'El banco dice que es dinero entre tus cuentas (un traspaso), no un gasto ni un cobro: regístralo como traspaso.' || c_si;
  elsif v ~ 'una deuda de la empresa, dada de alta por su número' then
    return 'El banco dice que este dinero es de una deuda de la empresa que ya está dada de alta (lo que entra de ella es deuda; lo que se '
           'le paga, baja la deuda).' || c_si;
  elsif v ~ 'viene de tu cuenta personal' then
    return 'El banco dice que este depósito viene de tu cuenta personal: es dinero tuyo a la empresa, no el cobro de un cliente.' || c_si;
  elsif v ~ '^Parece un pago a un proveedor con partidas abiertas' then
    return 'Parece el pago a un proveedor al que le debes: su gasto ya entró con sus recibos, y registrarlo como gasto lo pondría dos '
           'veces. Si de verdad es otra compra, escribe por qué.';
  elsif v ~ '^Parece el reembolso de un proveedor' then
    return 'Parece un reembolso de un proveedor que te debía dinero: va contra lo que tenía a tu favor. Si de verdad es la devolución de '
           'otra compra, escribe por qué.';
  elsif v ~ 'es más de lo que se queda un procesador' then
    m := regexp_match(v, '^La comisión \(([0-9]+(?:\.[0-9]+)?), el ([0-9.]+) %');
    return format('La diferencia%s es más de lo que se queda un procesador de tarjetas (como mucho un 3.5 %% más 30 centavos por factura). '
                  'Si el cliente pagó menos, es un pago parcial. Si de verdad es la comisión, escribe por qué.',
                  case when m is not null then format(' (%s, el %s %%)', fn_bandeja_usd(m[1]::numeric), m[2]) else '' end);
  elsif v ~ 'no nombra a ningún procesador de tarjetas' then
    return 'Este depósito no viene de un procesador de tarjetas: lo que falta para cubrir la factura puede ser que el cliente pagó menos '
           '(un pago parcial), no una comisión. Si de verdad es la comisión, escribe por qué.';
  elsif v ~ '^Las facturas suman .* si es un cobro con tarjeta depositado neto' then
    return 'Las facturas suman más que el depósito. Si pagaron con tarjeta, lo que falta es la comisión del procesador (dilo así); si no, '
           'es un pago parcial: di cuánto va a cada factura.';
  elsif v ~ '^Hay cobros anotados sin su depósito' then
    return 'Hay un cobro ya anotado, de otro monto, que espera su depósito: si es este mismo dinero, cásalo con él en «Más opciones» '
           '(registrar otro lo pondría dos veces). Si de verdad es otro, escribe por qué.';
  elsif v ~ '^Un abono en la tarjeta que no dice que es un pago' then
    return 'Un abono en la tarjeta que no dice que es un pago suele ser la devolución de una compra. Si de verdad fue un pago a la '
           'tarjeta, escribe por qué.';
  elsif v ~ 'no dice que sea dinero entre cuentas propias' then
    return 'El banco no dice que esto sea un traspaso entre tus cuentas: un cobro automático (la luz, el seguro) es un gasto. Si de verdad '
           'es un traspaso, escribe por qué.';
  elsif v ~ '^(No se postea como transferencia|En .* su otro lado ya se casó como otra cosa|Una tarjeta que manda dinero a un banco)' then
    return 'El banco no confirma que esto sea un traspaso con esa cuenta (su otro lado no aparece, o ya se registró como otra cosa). Si de '
           'verdad lo es, escribe por qué.';
  elsif v ~ '^Di por qué no es su ticket' then
    return 'Si es otra compra, el gasto queda dos veces en el libro a propósito (la que registraste y la del recibo). Escribe en una '
           'línea por qué es otra compra: queda escrito.';
  elsif v ~ '^Corregir un cobro anotado por otro monto' then
    return 'Hay un cobro ya anotado por otro monto: si este depósito es ese cobro, se corrige con él. Escribe por qué el monto era otro.';
  elsif v ~ 'ya está (casado|ignorado|en_transito)' then
    return 'Ese movimiento ya no está en la Bandeja.';
  elsif v ~ 'puede ser el mismo que otro que ya entró' then
    return 'Se parece a otro movimiento que ya está: dime primero si es el mismo o es otro, en «Más opciones».';
  end if;
  return coalesce(fn_bandeja_llano(v), 'El banco no lo aceptó.');
end $$;
revoke execute on function public.fn_bandeja_freno_llano(text, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_freno_llano(text, text) to authenticated;
comment on function public.fn_bandeja_freno_llano(text, text) is 'c17: lo que dice una puerta de c6 cuando frena, en palabras de Edgar (qué recibo, qué factura, cuánto), sin nombres de funciones ni códigos; con lo que c6 pensaba del movimiento (p_c6), el freno de un depósito dice si hay una factura por ese monto, un cobro ya anotado o solo alguna factura mayor.';


-- ---------------------------------------------------------------------
-- 5. LA CONTRAPARTE: quién es el otro lado de un movimiento, sacado de lo
--    que escribió el banco (desc_norm, la descripción ya normalizada por
--    c6: mayúsculas, sin signos). De ahí sale el GRUPO (la clave) y la
--    CLASE, que decide qué se puede hacer solo con él.
-- ---------------------------------------------------------------------
-- EL NOMBRE DEL COMERCIO: las primeras palabras hasta la primera que trae
-- un número (el de la tienda), sin lo que el banco pone delante (la forma
-- de pago —«POS DEBIT», «SQ», «TST»—, la fecha —«11/02»— o el número de la
-- tarjeta —«XXXXX1234»—), sin la ciudad y el estado del final («ZZ TACOS
-- OCALA FL» → «ZZ TACOS»), sin la palabra de cómo se paga («VERIZON
-- WIRELESS AUTOPAY» y «VERIZON WIRELESS PAYMENTS» son «VERIZON WIRELESS»)
-- y con tres palabras como mucho. Un ACH dice quién cobra después de «ORIG
-- CO NAME». Una CADENA conocida es siempre su marca, la tienda que sea
-- («HOME DEPOT WEST PALM» → «HOME DEPOT»; «LOWE'S», que c6 deja en «LOWE
-- S», → «LOWES»). Las tiendas dentro de una plataforma («DOORDASH
-- BURGERKING», «AMZN MKTP») se quedan en la plataforma; las de USO MIXTO
-- llevan qué es («GOOGLE ADS» no es «GOOGLE YOUTUBE» ni «MICROSOFT XBOX» es
-- «MICROSOFT»), y PayPal, la tienda de detrás. Nulo si no queda nada con
-- sentido (una palabra del banco sola: «DEPOSIT»).
-- (Tercera vuelta) SIN EXPRESIONES REGULARES en el camino corriente: Postgres
-- guarda compiladas solo las 32 últimas, y entre esta función, la
-- contraparte, el prestamista y lo que sugiere la descripción se usaban más
-- de cuarenta por movimiento: con la Bandeja llena cada una se volvía a
-- compilar en cada tarjeta (de 2 a 3 ms por movimiento solo en eso).
create or replace function public.fn_bandeja_comercio(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  c_delante   constant text[] := array['POS', 'DEBIT', 'CREDIT', 'PURCHASE', 'CHECKCARD', 'CARD', 'DBT', 'CRD', 'VISA', 'MASTERCARD',
                                       'RECURRING', 'ONLINE', 'ACH', 'WEB', 'PPD', 'CCD', 'ELECTRONIC', 'WITHDRAWAL', 'EXTERNAL',
                                       'PAYMENT', 'PMT', 'BILL', 'BILLPAY', 'SQ', 'TST', 'PP', 'SP', 'PY', 'DD', 'THE', 'PREAUTHORIZED',
                                       'DIRECT', 'DEP', 'MISC', 'INTERNET', 'AUTHORIZED', 'ON'];
  -- (sin los que también son una palabra o una sigla de empresa: CO, PA, IN, LA, ME, OR, OK, DE, AL, HI, OH, ID. «ZZ LUMBER CO» no
  -- es una ferretería de Colorado)
  c_estados   constant text[] := array['AK', 'AZ', 'AR', 'CA', 'CT', 'FL', 'GA', 'IL', 'IA', 'KS', 'KY', 'MD', 'MA', 'MI', 'MN', 'MS',
                                       'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT',
                                       'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC', 'PR'];
  c_sueltas   constant text[] := array['WWW', 'COM', 'NET', 'ORG', 'HTTPS', 'HTTP', 'INC', 'LLC', 'CORP', 'LTD'];
  -- (cómo se paga, no a quién: detrás del nombre no cuenta; tampoco las siglas de un cobro por ACH)
  c_ruido     constant text[] := array['AUTOPAY', 'PAYMENT', 'PAYMENTS', 'PMT', 'PMTS', 'PYMT', 'EPAY', 'EPAYMENT', 'BILLPAY', 'PPD', 'CCD', 'ACH',
                                       'ID'];
  c_genericas constant text[] := array['CHECK', 'CHEQUE', 'CHK', 'ATM', 'DEPOSIT', 'TRANSFER', 'XFER', 'FEE', 'WIRE', 'ZELLE', 'VENMO',
                                       'CASHAPP', 'MOBILE', 'REMOTE', 'CASH', 'COUNTER', 'BRANCH', 'TELLER', 'INTEREST', 'ID', 'REF',
                                       'NUMBER', 'NO', 'PAYMENT', 'PURCHASE', 'DEBIT', 'CREDIT', 'CARD', 'ONLINE', 'WITHDRAWAL',
                                       'FEDWIRE', 'RTP', 'CHIPS', 'THANK', 'AUTOPAY'];
  c_una       constant text[] := array['DOORDASH', 'GRUBHUB', 'INSTACART', 'LYFT', 'AMAZON', 'NETFLIX', 'SPOTIFY', 'KLARNA', 'AFFIRM',
                                       'AFTERPAY', 'APPLE', 'SUNPASS', 'HULU'];
  c_marcas    constant text[] := array['HOME DEPOT', 'LOWES', 'ACE HARDWARE', 'HARBOR FREIGHT', 'NORTHERN TOOL', 'CITY ELECTRIC',
                                       'GRAYBAR', 'FERGUSON', 'GRAINGER', 'WESCO', 'REXEL', 'WALMART', 'WAL MART', 'SAMS CLUB', 'COSTCO',
                                       'TARGET', 'PUBLIX', 'WINN DIXIE', 'WAWA', 'RACETRAC', 'CIRCLE K', '7 ELEVEN', 'SHELL', 'CHEVRON',
                                       'EXXON', 'EXXONMOBIL', 'MOBIL', 'SUNOCO', 'MARATHON', 'SPEEDWAY', 'MURPHY', 'CITGO', 'VALERO',
                                       'MCDONALDS', 'BURGER KING', 'WENDYS', 'CHICK FIL A', 'SUBWAY', 'STARBUCKS', 'DUNKIN', 'TACO BELL',
                                       'CHIPOTLE', 'POLLO TROPICAL', 'AUTOZONE', 'OREILLY', 'ADVANCE AUTO', 'SUNBELT', 'UNITED RENTALS'];
  c_union     constant text[] := array['DE', 'DEL', 'LA', 'LAS', 'LOS', 'EL', 'Y', 'OF', 'AND', 'THE'];
  c_dig       constant text := '0123456789';
  v  text := upper(btrim(coalesce(p, '')));
  e  text;
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
  if position('ORIG CO NAME ' in v) > 0 then
    m := regexp_match(v, 'ORIG CO NAME (.+?)(?: ORIG ID| CO ENTRY| SEC | DESC | IND ID| IND NAME| TRN |$)');
    if m is not null then
      v := m[1];
    end if;
  end if;
  v := translate(v, '#*&', '   ');
  -- (el apóstrofo que c6 volvió un espacio: «LOWE S» → «LOWES», «MCDONALD S» → «MCDONALDS»)
  if position(' S ' in v || ' ') > 0 then
    v := regexp_replace(v, '\m([A-Z]{3,}) S\M', '\1S', 'g');
  end if;
  w := array_remove(string_to_array(btrim(v), ' '), '');
  n := coalesce(array_length(w, 1), 0);
  e := ' ' || v || ' ';
  -- lo que el banco pone delante (la forma de pago, la fecha, el número de la tarjeta), fuera; nunca hasta dejarlo vacío
  while i < n loop
    x := w[i];
    if x = any (c_delante) or (length(x) >= 4 and translate(x, c_dig, '') = '')
       or (left(x, 1) = 'X' and ltrim(x, 'X') <> '' and translate(ltrim(x, 'X'), c_dig, '') = '') then
      i := i + 1;
    elsif length(x) <= 2 and translate(x, c_dig, '') = '' and length(w[i + 1]) <= 2 and translate(w[i + 1], c_dig, '') = '' and i + 1 < n then
      i := i + 2;   -- una fecha: «11 02»
    else
      exit;
    end if;
  end loop;
  for j in i .. n loop
    x := w[j];
    exit when translate(x, c_dig, '') <> x and cardinality(r) > 0;
    continue when x = any (c_sueltas) or (cardinality(r) > 0 and x = any (c_ruido));
    r := r || x;
    exit when cardinality(r) >= 4;
  end loop;
  if cardinality(r) = 0 then
    return null;
  end if;
  if r[1] = 'AMZN' then
    r[1] := 'AMAZON';
  elsif r[1] = 'MSFT' then
    r[1] := 'MICROSOFT';
  end if;
  if r[1] = 'GOOGLE' then
    -- (por la descripción entera: «GOOGLE ADS1234567» trae el número pegado, y la palabra con números ya no está en el nombre)
    r := case when position(' GOOGLE ADS' in e) > 0 or position(' GOOGLE ADWORDS' in e) > 0 then array['GOOGLE', 'ADS']
              when position(' GOOGLE YOUTUBE' in e) > 0 then array['GOOGLE', 'YOUTUBE']
              when r[2] in ('WORKSPACE', 'GSUITE', 'STORAGE', 'CLOUD', 'ONE', 'DOMAINS', 'FI', 'PLAY', 'NEST', 'VOICE') then r[1:2]
              else r[1:1] end;
  elsif r[1] = 'MICROSOFT' then
    r := case when 'XBOX' = any (r) then array['MICROSOFT', 'XBOX'] else r[1:1] end;
  elsif r[1] = 'INTUIT' then
    r := case when position('QBOOKS' in e) > 0 or position('QUICKBOOKS' in e) > 0 or position(' QB ' in e) > 0 or position(' QBO ' in e) > 0
              then array['INTUIT', 'QUICKBOOKS'] else r[1:1] end;
  elsif r[1] = 'PAYPAL' then
    r := r[1:least(3, cardinality(r))];
  elsif r[1] = any (c_una) then
    r := r[1:1];
  elsif r[1] = 'UBER' then
    r := case when cardinality(r) > 1 and r[2] = 'EATS' then r[1:2] else r[1:1] end;
  else
    select b.b into x from unnest(c_marcas) as b(b) where array_to_string(r, ' ') || ' ' like b.b || ' %' order by length(b.b) desc limit 1;
    if x is not null then
      r := string_to_array(x, ' ');
    elsif cardinality(r) >= 3 and r[cardinality(r)] = any (c_estados) then
      r := r[1:cardinality(r) - 2];
    elsif cardinality(r) = 2 and r[2] = any (c_estados) then
      r := r[1:1];
    end if;
    if cardinality(r) > 3 and not (r[3] = any (c_union)) then
      r := r[1:3];
    end if;
  end if;
  x := array_to_string(r, ' ');
  if length(x) < 3 or translate(x, c_dig || ' ', '') = '' or r[1] = any (c_genericas) then
    return null;
  end if;
  return x;
end $$;
revoke execute on function public.fn_bandeja_comercio(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_comercio(text) to authenticated;
comment on function public.fn_bandeja_comercio(text) is 'c17: el nombre del comercio de una descripción normalizada del banco (sin la forma de pago, la fecha, el número de tienda, la ciudad ni el estado; una cadena conocida, su marca; una plataforma de uso mixto, con qué es; tres palabras como mucho); nulo si no hay comercio.';

-- LA CONTRAPARTE de un movimiento: {clase, clave, nombre}.
--   cheque         un cheque (no dice a quién): sin clave.
--   cajero         un retiro o un depósito de efectivo en el cajero: sin clave.
--   zelle_a/_de    un Zelle (o Venmo, Cash App) a alguien o de alguien: la
--                  clave lleva su nombre como lo escribe el banco.
--   nomina         lo que c6 reconoce como nómina (Gusto).
--   transferencia  entre cuentas propias, o el pago de una tarjeta. «AUTOPAY»
--                  y «THANK YOU» solos NO lo son: el cobro automático de la
--                  luz, del teléfono o del seguro es un gasto de su comercio
--                  («VERIZON WIRELESS AUTOPAY»). Solo cuando el texto nombra
--                  una tarjeta (la emisora, o los cuatro últimos de una dada
--                  de alta), o es el abono que la tarjeta recibe.
--   procesador     el depósito de un procesador de tarjetas (Intuit,
--                  Stripe, Square…): junta cobros de clientes.
--   deposito       cualquier otro depósito, con clave SOLO si dice quién
--                  paga: en una transferencia o un pago inmediato el nombre
--                  va detrás de «BNF=», «B/O:» u «ORIG CO NAME»; el nombre
--                  del canal («REAL TIME PAYMENT», «FEDWIRE») no es de nadie
--                  (con él por clave, lo recordado de un cliente valdría
--                  para todos los que pagan por ese canal).
--   comercio       un cargo de un comercio: la clave es su nombre. Lo que
--                  un procesador de tarjetas COBRA por sus cobros lleva su
--                  propia clave («INTUIT COMISIONES»): no es la suscripción
--                  de QuickBooks. Y UN AYUNTAMIENTO O UN CONDADO cobra cosas
--                  distintas con el mismo nombre (la luz y el agua, un
--                  permiso de obra): su clave lleva cuál, cuando la
--                  descripción lo dice («CITY OF OCALA PERMISOS», «CITY OF
--                  OCALA SERVICIOS»). Con una sola clave, recordar la
--                  factura de la luz mandaba los permisos a «Luz, agua y
--                  servicios» (y, con «que entre solo», sin un toque).
--   otro           un cargo que no dice de quién.
-- Solo un «comercio» puede entrar solo (y solo si Edgar lo dijo).
create or replace function public.fn_bandeja_contraparte(p_desc_norm text, p_memo text, p_monto numeric, p_tipo text, p_cheque text)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c_proc constant text := '(?:^| )(INTUIT|QBPAYMENTS|QUICKBOOKS|QB PAYMENTS|STRIPE|SQUARE|SQ|PAYPAL|CLOVER|BANKCARD|MERCHANT|WORLDPAY)(?: |$)';
  v    text := upper(btrim(coalesce(p_desc_norm, '')));
  e    text;    -- con un espacio a cada lado: «( |^)X( |$)» es « X »
  t    text;    -- y además sin # ni &: el borde de una palabra es un espacio
  m    text[];
  r    text[] := '{}';
  x    text;
  v_n  text;
  sg   jsonb;
begin
  e := ' ' || v || ' ';
  t := translate(e, '#&', '  ');
  if coalesce(p_tipo, '') = 'CHECK' or nullif(btrim(coalesce(p_cheque, '')), '') is not null
     or split_part(v, ' ', 1) in ('CHECK', 'CHEQUE', 'CHK') then
    return jsonb_build_object('clase', 'cheque', 'nombre', 'Cheque' || coalesce(' ' || nullif(btrim(p_cheque), ''), ''));
  end if;
  if coalesce(p_tipo, '') = 'ATM' or position(' ATM ' in e) > 0 or position('CASH WITHDRAWAL' in v) > 0 or position('CASH DEPOSIT' in v) > 0 then
    return jsonb_build_object('clase', 'cajero', 'nombre', case when p_monto > 0 then 'Depósito de efectivo' else 'Retiro de cajero' end);
  end if;
  if position('ZELLE' in v) > 0 or position('VENMO' in v) > 0 or position('CASH' in v) > 0 then
    m := regexp_match(v, '(?:^| )(?:ZELLE|VENMO|CASH ?APP)(?: (?:PAYMENT|TRANSFER|INSTANT|PMT))* (?:TO|FROM) (.+)$');
    if m is not null or position(' ZELLE ' in e) > 0 or position(' VENMO ' in e) > 0 then
      if m is not null then
        foreach x in array string_to_array(m[1], ' ') loop
          continue when x = '';
          exit when translate(x, '0123456789', '') <> x or x in ('CONF', 'CONFIRMATION', 'REF', 'ID', 'MEMO', 'JPM', 'BAC', 'WFCT', 'ON', 'FOR', 'VIA');
          r := r || x;
          exit when cardinality(r) >= 4;
        end loop;
      end if;
      v_n := nullif(array_to_string(r, ' '), '');
      return jsonb_strip_nulls(jsonb_build_object(
        'clase', case when p_monto < 0 then 'zelle_a' else 'zelle_de' end,
        'clave', case when v_n is not null then 'Z' || case when p_monto < 0 then '>' else '<' end || ':' || v_n end,
        -- (el nombre como se escribe: «Zz Alfa Holdings Llc» no; las siglas —LLC, INC, lo que no lleva vocales— se quedan en mayúsculas)
        'nombre', coalesce((select string_agg(case when z.w in ('LLC', 'INC', 'CORP', 'LLP', 'PLLC', 'LP', 'PA', 'USA', 'DBA')
                                                        or translate(z.w, 'AEIOUY', '') = z.w then z.w else initcap(z.w) end,
                                              ' ' order by z.i)
                              from unnest(r) with ordinality as z(w, i)), 'Zelle')));
    end if;
    m := null;
  end if;
  if fn_banco_dice_nomina(v, p_memo) then
    return jsonb_build_object('clase', 'nomina', 'nombre', 'Nómina');
  end if;
  if coalesce(p_tipo, '') = 'XFER'
     or position('ONLINE TRANSFER' in v) > 0 or position('TRANSFER TO' in v) > 0 or position('TRANSFER FROM' in v) > 0
     or position(' XFER ' in e) > 0 or position(' AMEX ' in e) > 0 or position('AMERICAN EXPRESS' in v) > 0
     or position('CREDIT CARD' in v) > 0 or position('CREDIT CRD' in v) > 0
     or position('CARDMEMBER SERV' in v) > 0 or position('CARD MEMBER SERV' in v) > 0 then
    return jsonb_build_object('clase', 'transferencia', 'nombre', 'Entre cuentas');
  end if;
  -- («AUTOPAY» y «THANK YOU»: el abono que recibe la tarjeta, o un cargo que nombra una tarjeta. El cobro automático de un comercio, no)
  if (position('THANK YOU' in v) > 0 or position('AUTOPAY' in v) > 0)
     and (p_monto > 0
          or position('CHASE CARD' in v) > 0 or position('CAPITAL ONE' in v) > 0 or position('CITI CARD' in v) > 0
          or position('CITICARD' in v) > 0 or position(' DISCOVER ' in t) > 0 or position('BARCLAY' in v) > 0
          or position('EPAYMENT' in v) > 0 or position(' CARD ' in t) > 0
          or exists (select 1 from tarjetas tj
                      where coalesce(tj.activa, true) and nullif(btrim(coalesce(tj.ultimos4, '')), '') is not null
                        and position(' ' || tj.ultimos4 || ' ' in t) > 0)) then
    return jsonb_build_object('clase', 'transferencia', 'nombre', 'Entre cuentas');
  end if;
  if position('INTUIT' in v) > 0 or position('QBPAYMENTS' in v) > 0 or position('QUICKBOOKS' in v) > 0 or position('QB PAYMENTS' in v) > 0
     or position('STRIPE' in v) > 0 or position('SQUARE' in v) > 0 or position(' SQ ' in e) > 0 or position('PAYPAL' in v) > 0
     or position('CLOVER' in v) > 0 or position('BANKCARD' in v) > 0 or position('MERCHANT' in v) > 0 or position('WORLDPAY' in v) > 0 then
    m := regexp_match(v, c_proc);
  end if;
  if m is not null then
    x := case when m[1] in ('INTUIT', 'QBPAYMENTS', 'QUICKBOOKS', 'QB PAYMENTS') then 'INTUIT'
              when m[1] in ('SQUARE', 'SQ') then 'SQUARE'
              when m[1] in ('BANKCARD', 'MERCHANT') then 'TARJETAS' else m[1] end;
    v_n := case x when 'INTUIT' then 'Intuit Payments (QuickBooks)' when 'TARJETAS' then 'Cobros con tarjeta' else initcap(x) end;
  end if;
  if p_monto > 0 then
    if m is not null then
      return jsonb_build_object('clase', 'procesador', 'clave', 'P:' || x, 'nombre', v_n, 'proc', x);
    end if;
    -- quién paga: detrás de la marca del banco, si la hay; el nombre del canal no es de nadie
    m := regexp_match(v, '^(?:.* )?(?:BNF|B O|ORIGINATOR|REMITTER|ORDERING CUSTOMER) (.+)$');
    if m is null then
      m := regexp_match(v, '^(?:.* )?(?:RECD FROM|RECEIVED FROM|DEPOSIT FROM|PAYMENT FROM|CREDIT FROM) (.+)$');
    end if;
    if m is not null then
      v_n := fn_bandeja_comercio(regexp_replace(m[1], ' (REF|TRN|ID|SRF|OBI|RFB|IMAD|OMAD|BBI|SSN|ORIG ID|CO ENTRY|SEC|DESC|IND ID|IND NAME)( .*)?$', ''));
    elsif v ~ '^(REAL TIME (PAYMENT|TRANSFER)|RTP|FEDWIRE|FED WIRE|INCOMING (WIRE|DOMESTIC)|WIRE (TRANSFER|TYPE|IN|FROM)|DOMESTIC WIRE|INTERNATIONAL WIRE|CHIPS|BOOK TRANSFER|FUNDS TRANSFER|ACH CREDIT|ELECTRONIC DEPOSIT)( |$)' then
      v_n := null;
    else
      v_n := fn_bandeja_comercio(v);
    end if;
    return jsonb_strip_nulls(jsonb_build_object('clase', 'deposito', 'clave', 'D:' || v_n, 'nombre', coalesce(v_n, 'Depósito')));
  end if;
  -- lo que el procesador COBRA por los cobros con tarjeta: su propia clave
  if m is not null and (position(' FEE' in t) > 0 or position('DISCOUNT' in v) > 0 or position('PROCESSING' in v) > 0 or position(' MERCH' in t) > 0) then
    return jsonb_build_object('clase', 'comercio', 'clave', 'C:' || x || ' COMISIONES', 'nombre', v_n || ' · comisiones de tarjeta', 'comision', true);
  end if;
  v_n := fn_bandeja_comercio(v);
  if v_n is null then
    return jsonb_build_object('clase', 'otro', 'nombre', 'Sin nombre');
  end if;
  -- un ayuntamiento o un condado: la clave lleva QUÉ cobra, si la descripción lo dice (un permiso, o la luz y el agua)
  if position(' CITY OF ' in t) > 0 or position(' COUNTY ' in t) > 0 or position(' TOWN OF ' in t) > 0 or position(' VILLAGE OF ' in t) > 0 then
    sg := fn_bandeja_sugerida(v);
    if sg->>'cuenta' = '5400' then
      return jsonb_build_object('clase', 'comercio', 'clave', 'C:' || v_n || ' PERMISOS', 'nombre', v_n || ' · permisos');
    elsif sg->>'cuenta' = '6110' then
      return jsonb_build_object('clase', 'comercio', 'clave', 'C:' || v_n || ' SERVICIOS', 'nombre', v_n || ' · luz y agua');
    end if;
  end if;
  return jsonb_build_object('clase', 'comercio', 'clave', 'C:' || v_n, 'nombre', v_n);
end $$;
revoke execute on function public.fn_bandeja_contraparte(text, text, numeric, text, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_contraparte(text, text, numeric, text, text) to authenticated;
comment on function public.fn_bandeja_contraparte(text, text, numeric, text, text) is 'c17: la contraparte de un movimiento del banco: {clase (cheque, cajero, zelle_a, zelle_de, nomina, transferencia, procesador, deposito, comercio, otro), clave (el grupo; nula si no dice quién: el canal de un pago no es de nadie; la de un ayuntamiento o un condado lleva qué cobra: PERMISOS o SERVICIOS), nombre}.';


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
    (601, 'ingresos', 'Otros ingresos',    'ingreso', 'otro_ingreso',  'Otro ingreso (una recompensa, un premio)', 'otro_ingreso', '4900', null),
    (602, 'ingresos', 'Otros ingresos',    'ingreso', 'intereses_banco', 'Intereses que paga el banco',         'otro_ingreso', '4910', null),
    (603, 'ingresos', 'Otros ingresos',    'ingreso', 'devolucion',    'La devolución de una compra',           'gasto',        null,   '{"devolucion": true}'),
    (604, 'ingresos', 'Otros ingresos',    'ingreso', 'devolucion_mia', 'La devolución de algo mío (un cargo personal)', 'personal', '3200', '{"devolucion": true}'),
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
-- «Camioneta y gasolina») o, si no tiene, el de la cuenta. (Tercera vuelta:
-- los nombres van aquí en su propia lista —la primera categoría de cada
-- cuenta del catálogo de arriba; la prueba 5 comprueba que digan lo mismo—
-- porque esta función se llama una o dos veces por tarjeta, y leyendo el
-- catálogo cada vez se iba en ella la cuarta parte de la lectura de la
-- Bandeja.)
create or replace function public.fn_bandeja_cuenta_llana(p_cuenta text) returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  v := case p_cuenta
         when '5100' then 'Material'
         when '5200' then 'Subcontratos'
         when '5400' then 'Permisos e inspecciones'
         when '5300' then 'Equipo y renta'
         when '5500' then 'Consumibles'
         when '5600' then 'Flete'
         when '6300' then 'Camioneta y gasolina'
         when '6200' then 'Seguros'
         when '6120' then 'Teléfono e internet'
         when '6500' then 'Oficina y software'
         when '6350' then 'Comidas'
         when '6700' then 'Publicidad'
         when '6600' then 'Profesionales (contador, abogado)'
         when '6400' then 'Herramienta menor y uniformes'
         when '6100' then 'Renta del local'
         when '6110' then 'Luz, agua y servicios'
         when '6800' then 'Licencias y cuotas'
         when '6360' then 'Viajes y alojamiento'
         when '6130' then 'Cargos del banco y de la tarjeta'
         when '9000' then 'Impuestos y tasas de la empresa'
         when '7100' then 'Intereses'
         when '7920' then 'Multas y recargos'
         when '7910' then 'Donaciones'
         when '7900' then 'Otro gasto'
         when '3200' then 'Es mío, no de la empresa (retiro del accionista)'
         when '4900' then 'Otro ingreso (una recompensa, un premio)'
         when '4910' then 'Intereses que paga el banco'
       end;
  if v is null then
    select k.nombre into v from cuentas k where k.codigo = p_cuenta;
  end if;
  return coalesce(v, p_cuenta);
end $$;
revoke execute on function public.fn_bandeja_cuenta_llana(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_cuenta_llana(text) to authenticated;
comment on function public.fn_bandeja_cuenta_llana(text) is 'c17: el nombre llano de una cuenta (el de su categoría de la Bandeja, o el de la cuenta).';

-- LO QUE SUGIERE LA DESCRIPCIÓN del banco, antes de que Edgar diga nada: las
-- marcas corrientes del oficio y de la casa. Mira la descripción ENTERA
-- (normalizada), no el nombre ya recortado: «GOOGLE *YOUTUBE» y «MICROSOFT
-- *XBOX» son de la casa, «GOOGLE ADS» es publicidad, y una plataforma sola
-- («GOOGLE», «MICROSOFT», «APPLE», «AMAZON») no sugiere nada. Lo de un
-- ayuntamiento o un condado es un permiso solo si lo dice (PERMIT, BLDG,
-- BUILDING, BOCC…): su recibo de luz y agua va a servicios, la renovación de
-- la licencia (DBPR) a licencias, y el recaudador (TAX COLLECTOR), a nada.
-- Es solo una sugerencia: nunca entra sola por esto. {accion, cuenta} o nulo.
-- CÓMO ESTÁ HECHA (tercera vuelta): una lista de palabras por regla, y se
-- busca cada una en la descripción (sin expresiones regulares: eran quince,
-- y con las de la contraparte pasaban de las 32 que Postgres guarda
-- compiladas). Cada entrada lleva delante las dos letras de su regla; un
-- espacio delante de la palabra quiere decir «empieza una palabra» y uno
-- detrás, «la termina» (« HULU » es la palabra entera; « TOLL», lo que
-- empieza por TOLL; «DISNEY», en cualquier sitio). Las reglas se miran en
-- el orden de abajo y gana la primera.
create or replace function public.fn_bandeja_sugerida(p_desc text) returns jsonb
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  c_pat constant text[] := array[
    -- pe: lo personal (la casa, los juegos, la comida a domicilio, lo comprado a plazos, la hipoteca)
    'peNETFLIX', 'peSPOTIFY', 'pe HULU ', 'peDISNEY', 'pe HBO ', 'pePARAMOUNT', 'pePEACOCK', 'peYOUTUBE', 'pePLAYSTATION', 'pe XBOX ',
    'peGAME PASS', 'peNINTENDO', 'pe STEAM', 'peEPIC GAMES', 'peROBLOX', 'peTWITCH', 'peDOORDASH', 'peUBER EATS', 'peGRUBHUB',
    'peINSTACART', 'peKLARNA', 'peAFFIRM', 'peAFTERPAY', 'peSEZZLE', 'peMORTGAGE',
    -- pu: publicidad
    'puFACEBK', 'puFACEBOOK', 'puMETA ADS', 'puGOOGLE ADS', 'pu ADWORDS ', 'pu YELP ', 'pu ANGI ', 'puTHUMBTACK', 'puHOMEADVISOR',
    'puVISTAPRINT',
    -- pr + fe: lo que un procesador de tarjetas COBRA por los cobros (no es la suscripción de QuickBooks)
    'pr INTUIT ', 'prQBPAYMENTS', 'prQUICKBOOKS', 'prQB PAYMENTS', 'pr STRIPE ', 'pr SQUARE ', 'pr PAYPAL ', 'pr CLOVER ', 'prBANKCARD',
    'pr MERCHANT ', 'prWORLDPAY',
    'fe FEE', 'feDISCOUNT', 'fePROCESSING', 'fe MERCH',
    -- ma: material de obra
    'maHOME DEPOT', 'ma LOWES ', 'ma LOWE S ', 'ma CED ', 'maGRAYBAR', 'ma PLATT ', 'ma REXEL ', 'maELECTRIC SUPPLY', 'maELECTRICAL SUPPLY',
    'maCITY ELECTRIC', 'ma CES ', 'maFERGUSON', 'maGRAINGER', 'maACE HARDWARE', 'maMENARDS', 'ma WESCO ', 'maWINSUPPLY',
    'maELLIOTT ELECTRIC', 'maMAYER ELECTRIC',
    -- he: herramienta menor · re: renta de equipo
    'heHARBOR FREIGHT', 'heNORTHERN TOOL',
    'reSUNBELT', 'reUNITED RENTALS', 'reHERC RENTALS',
    -- ga: la camioneta (gasolina, peajes, refacciones)
    'ga SHELL ', 'gaCHEVRON', 'gaEXXON', 'ga MOBIL ', 'ga BP ', 'ga WAWA ', 'gaRACETRAC', 'gaSUNOCO', 'gaMARATHON', 'gaCIRCLE K',
    'ga7 ELEVEN', 'gaSPEEDWAY', 'gaMURPHY', 'gaBUC EE', 'ga CITGO ', 'ga VALERO ', 'gaSUNPASS', 'ga E PASS ', 'ga EPASS ', 'ga TOLL',
    'gaAUTOZONE', 'gaO REILLY', 'gaOREILLY', 'gaADVANCE AUTO', 'gaJIFFY LUBE', 'gaDISCOUNT TIRE',
    -- go + ut: los servicios de un ayuntamiento o un condado · lu: la compañía de la luz
    'go CITY OF ', 'go COUNTY ', 'go TOWN OF ', 'go VILLAGE OF ',
    'utUTILIT', 'ut WATER ', 'utSEWER', 'ut ELECTRIC ', 'utSOLID WASTE', 'utGARBAGE',
    'lu FPL ', 'luFLORIDA POWER', 'luDUKE ENERGY', 'lu TECO ',
    -- tx: el recaudador (no se sugiere nada) · li: licencias · pm: permisos
    'txTAX COLLECTOR',
    'li DBPR ',
    'pm PERMIT', 'pm BLDG ', 'pmBUILDING DEP', 'pmBUILDING DIV', 'pmBUILDING SERV', 'pmBUILDING SAFETY', 'pmBUILDING INSP', 'pm BOCC ',
    'pm INSPECTION', 'pmGROWTH M', 'pmCODE ENF', 'pm ZONING',
    -- te: teléfono e internet · se: seguros
    'teVERIZON', 'teT MOBILE', 'teTMOBILE', 'te ATT ', 'teCOMCAST', 'teXFINITY', 'teSPECTRUM',
    'sePROGRESSIVE', 'se GEICO ', 'seSTATE FARM', 'seALLSTATE', 'seINSURANCE', 'se NEXT INS',
    -- of: oficina y software
    'ofQUICKBOOKS', 'ofQBOOKS', 'of INTUIT ', 'ofGOOGLE WORKSPACE', 'ofGOOGLE GSUITE', 'ofGOOGLE STORAGE', 'ofGOOGLE CLOUD', 'ofGOOGLE ONE',
    'ofGOOGLE DOMAINS', 'of GSUITE ', 'ofMICROSOFT 365', 'ofMICROSOFT OFFICE', 'ofOFFICE 365', 'of ADOBE ', 'ofDROPBOX', 'of ZOOM ',
    'ofOPENAI', 'ofANTHROPIC', 'ofGODADDY', 'of WIX ', 'ofSUPABASE', 'ofGITHUB',
    -- co: comidas
    'coMCDONALD', 'coBURGER KING', 'co WENDY', 'coCHICK FIL', 'co SUBWAY ', 'coSTARBUCKS', 'coDUNKIN', 'coTACO BELL', 'coCHIPOTLE',
    'coPOLLO TROPICAL', 'coRESTAURANT', 'co PIZZA', 'co GRILL ', 'co CAFE '];
  p  text;
  h  text[];
begin
  if p_desc is null then
    return null;
  end if;
  -- (lo que no es letra ni número separa palabras, como en la descripción normalizada de c6)
  p := ' ' || translate(upper(p_desc), '#&*.,;:/\-_()[]''"+=!?@$%', '                          ') || ' ';
  select array_agg(distinct left(x.x, 2)) into h from unnest(c_pat) as x(x) where position(substr(x.x, 3) in p) > 0;
  if h is null then
    return null;
  end if;
  return case
    when 'pe' = any (h) then jsonb_build_object('accion', 'personal', 'cuenta', '3200')
    when 'pu' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6700')
    when 'pr' = any (h) and 'fe' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6130')
    when 'ma' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '5100')
    when 'he' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6400')
    when 're' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '5300')
    when 'ga' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6300')
    -- lo de un ayuntamiento, un condado o la compañía de la luz: los servicios no son un permiso
    when ('go' = any (h) and 'ut' = any (h)) or 'lu' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6110')
    when 'tx' = any (h) then null
    when 'li' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6800')
    when 'pm' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '5400')
    when 'te' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6120')
    when 'se' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6200')
    when 'of' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6500')
    when 'co' = any (h) then jsonb_build_object('accion', 'gasto', 'cuenta', '6350')
  end;
end $$;
revoke execute on function public.fn_bandeja_sugerida(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_sugerida(text) to authenticated;
comment on function public.fn_bandeja_sugerida(text) is 'c17: lo que sugiere la descripción del banco de un comercio corriente (material, gasolina, permisos, servicios, lo personal…): {accion, cuenta} o nulo. Solo sugiere: nada entra solo por esto.';

-- ¿VALE LO RECORDADO PARA ESTE CARGO? Lo que Edgar dijo de un comercio vale
-- para lo que el banco describe como entonces. Si la descripción de AHORA
-- sugiere algo (un permiso) que no es ni lo recordado (la luz) ni lo que
-- sugería la descripción con que se enseñó (bandeja_memoria.sugerida), es
-- otra cosa con el mismo nombre: lo recordado no se aplica ni entra solo; se
-- propone por la descripción y se pregunta. p_recordado y p_sugerida:
-- «accion|cuenta» (lo que la regla dice, y lo que sugería entonces).
create or replace function public.fn_bandeja_memoria_vale(p_recordado text, p_sugerida text, p_desc_norm text) returns boolean
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  sg jsonb := fn_bandeja_sugerida(p_desc_norm);
  v  text;
begin
  if sg is null then
    return true;
  end if;
  v := (sg->>'accion') || '|' || coalesce(sg->>'cuenta', '');
  return v = coalesce(p_recordado, '') or v = coalesce(p_sugerida, '');
end $$;
revoke execute on function public.fn_bandeja_memoria_vale(text, text, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_memoria_vale(text, text, text) to authenticated;
comment on function public.fn_bandeja_memoria_vale(text, text, text) is 'c17: si lo recordado de un comercio vale para un cargo: no, cuando la descripción de ahora sugiere otra cosa que lo recordado y que lo que sugería la descripción con que se enseñó (el permiso y la luz de una misma ciudad).';


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

-- ¿QUÉ FACTURAS PAGA ESTE DEPÓSITO? Entre TODAS las que tienen saldo y son
-- de su fecha o anteriores (no las doce más cercanas: con más facturas
-- abiertas que esas, «la única» no lo era), UNA sola o varias juntas que:
--   · sumen el depósito AL CENTAVO; o,
--   · si lo deposita un procesador de tarjetas (p_proc: INTUIT, STRIPE,
--     SQUARE…), lo sumen NETO DE SU COMISIÓN, calculada factura a factura
--     con UNA de las tarifas de ese procesador (bandeja_config.tarifas: un
--     tanto por ciento más un fijo). No «lo que quepa hasta un 3.5 %»: con
--     una docena de facturas abiertas casi cualquier depósito cabía en
--     alguna combinación, y la app recomendaba facturas equivocadas más
--     veces de las que acertaba.
-- CUÁNTAS FACTURAS JUNTAS se buscan lo decide CUÁNTAS HAY: con muchas
-- facturas por cobrar, que tres o cuatro sumen un depósito al centavo puede
-- ser pura casualidad (con cien, casi cualquier monto es la suma de algunas
-- cuatro). Se buscan juegos de hasta cuatro solo mientras las combinaciones
-- posibles (por las tarifas que se prueban) no pasen de veinte mil; si no,
-- de tres, de dos, o la factura sola. Lo que no se busca no se recomienda:
-- se pregunta (y Edgar lo dice con sus palabras).
-- Primero entre las MARCADAS COBRADAS en Proyectos (Edgar ya dijo que esas
-- se pagaron); si entre ellas no hay respuesta, entre todas. Solo contesta
-- si la respuesta es ÚNICA en su escalón: exacto, antes que con una tarifa
-- que Edgar ya CONFIRMÓ (la de un lote que aprobó: veces), antes que con las
-- demás de la lista (NO «menos facturas antes que más»): {facturas: [{id,
-- num, obra, monto}], comision, bruto, marcadas, tarifa}. Con varias igual
-- de buenas, {varias: n}: se pregunta. Sin ninguna, nulo.
-- (Tercera vuelta) LAS TARIFAS DE LA LISTA SE PRUEBAN SIEMPRE: antes, con una
-- confirmada solo se probaban las confirmadas, y confirmar el primer lote de
-- tarjeta (2.99 %) dejaba sin reconocer el depósito pagado por transferencia
-- (1 %); y una «comisión» rara aprendida de un solo cobro apagaba todas las
-- buenas. Y YA NO HAY «RESPALDO» (la única combinación que cabía hasta el
-- 3.5 %, «míralo bien»): con diez facturas por cobrar acertaba tres de cada
-- cuatro veces y las demás recomendaba facturas que no eran. Un procesador
-- con una tarifa que no está en la lista se contesta una vez a mano (o
-- diciéndolo) y su tarifa queda apuntada: el siguiente lote ya se reconoce.
drop function if exists public.fn_bandeja_cobro_de(jsonb, numeric, date, boolean);
create or replace function public.fn_bandeja_cobro_de(p_facturas jsonb, p_monto numeric, p_fecha date, p_proc text default null)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_f     jsonb;
  v_fn    jsonb;
  v_tar   jsonb := '[]'::jsonb;
  v_res   jsonb;
  v_n     int;
  v_t     int;
  v_k     int;
  n       numeric;
  n_marc  int;
  c_tope  constant numeric := 20000;
begin
  if p_monto is null or p_monto <= 0 or jsonb_typeof(p_facturas) is distinct from 'array' then
    return null;
  end if;
  -- (lo que a cada factura se le puede cobrar: su saldo; y a la que ya solo le queda su retención, la retención)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', (x->>'id')::bigint, 'num', x->>'num', 'saldo', y.s, 'obra', x->>'obra', 'fecha', x->>'fecha',
           'marcada', coalesce((x->>'marcada')::boolean, false)
                      and (x->>'cobrada_el' is null or (x->>'cobrada_el')::date between p_fecha - 12 and p_fecha + 3))), '[]'::jsonb)
    into v_f
    from jsonb_array_elements(p_facturas) x
    cross join lateral (select case when coalesce((x->>'saldo')::numeric, 0) > 0 then (x->>'saldo')::numeric
                                    else coalesce((x->>'retencion')::numeric, 0) end as s) y
   where y.s > 0 and (x->>'fecha')::date <= p_fecha and y.s <= p_monto * 1.05 + 5;
  if jsonb_array_length(v_f) = 0 then
    return null;
  end if;
  if p_proc is not null then
    -- las tarifas de ese procesador, todas; «conf»: la que Edgar ya confirmó con un lote (una de la lista, una vez; una aprendida, dos)
    select coalesce(jsonb_agg(y || jsonb_build_object('conf', coalesce((y->>'veces')::int, 0) >= case when y->>'origen' = 'aprendida' then 2 else 1 end)),
                    '[]'::jsonb)
      into v_tar
      from bandeja_config g, jsonb_array_elements(g.tarifas) y
     where g.id = 1 and y->>'proc' = p_proc and jsonb_typeof(y->'pct') = 'number';
  end if;
  v_t := 1 + jsonb_array_length(v_tar);
  select count(*) into n_marc from jsonb_array_elements(v_f) x where (x->>'marcada')::boolean;
  -- nivel 1: solo las marcadas cobradas en Proyectos; nivel 2: todas
  for v_niv in 1 .. 2 loop
    if v_niv = 1 then
      continue when n_marc = 0;
      select jsonb_agg(x) into v_fn from jsonb_array_elements(v_f) x where (x->>'marcada')::boolean;
    else
      continue when n_marc = jsonb_array_length(v_f);
      v_fn := v_f;
    end if;
    n := jsonb_array_length(v_fn);
    -- hasta cuántas juntas: mientras las combinaciones (por cada tarifa que se prueba) no pasen del tope
    v_k := case when n * (n - 1) * (n - 2) * (n - 3) / 24 * v_t <= c_tope then 4
                when n * (n - 1) * (n - 2) / 6 * v_t <= c_tope then 3
                when n * (n - 1) / 2 * v_t <= c_tope then 2
                else 1 end;
    with f as materialized (
      select * from jsonb_to_recordset(v_fn) as x(id bigint, num text, saldo numeric, obra text, fecha date, marcada boolean)),
    t as materialized (
      -- (esc: el escalón de la respuesta. 0: suman al centavo; 1: con una tarifa confirmada; 2: con otra de la lista)
      select 0 as tn, 0::numeric as pct, 0::numeric as fijo, null::numeric as tope, 0 as esc
      union all
      select (row_number() over ())::int, (y->>'pct')::numeric, coalesce((y->>'fijo')::numeric, 0), (y->>'tope')::numeric,
             case when (y->>'conf')::boolean then 1 else 2 end
        from jsonb_array_elements(v_tar) y),
    -- cada factura con cada tarifa: lo que llega al banco de ella
    i as materialized (
      select f.id, t.tn,
             f.saldo - case when t.tn = 0 then 0 else least(round(f.saldo * t.pct / 100 + t.fijo, 2), coalesce(t.tope, f.saldo)) end as neto
        from f cross join t),
    p as materialized (
      select a.tn, a.id as i1, b.id as i2, a.neto + b.neto as neto
        from i a join i b on b.tn = a.tn and b.id > a.id
       where v_k >= 2 and a.neto + b.neto <= p_monto + 0.02),
    sol as (
      -- (con comisión, un centavo de holgura: cómo redondea cada procesador el medio centavo no se sabe)
      select array[i.id] as ids, i.tn from i where abs(i.neto - p_monto) <= case when i.tn = 0 then 0 else 0.01 end
      union all
      select array[p.i1, p.i2], p.tn from p where abs(p.neto - p_monto) <= case when p.tn = 0 then 0 else 0.01 end
      union all
      select array[p.i1, p.i2, i.id], p.tn
        from p
        cross join generate_series(-1, 1) as o(c)
        join i on i.tn = p.tn and i.neto = p_monto - p.neto + o.c / 100.0 and i.id > p.i2
       where v_k >= 3 and (p.tn > 0 or o.c = 0)
      union all
      select array[a.i1, a.i2, b.i1, b.i2], a.tn
        from p a
        cross join generate_series(-1, 1) as o(c)
        join p b on b.tn = a.tn and b.neto = p_monto - a.neto + o.c / 100.0 and b.i1 > a.i2
       where v_k >= 4 and (a.tn > 0 or o.c = 0)),
    -- (un mismo juego de facturas puede casar con dos tarifas: es UNA respuesta; la de mejor escalón)
    s2 as (select distinct on (s.ids) s.ids, s.tn, t.esc from sol s join t on t.tn = s.tn order by s.ids, t.esc, s.tn),
    s3 as (select s2.ids, s2.tn, s2.esc, cardinality(s2.ids) as cnt,
                  (select count(*) from f where f.id = any (s2.ids) and f.marcada) as marc,
                  (select sum(f.saldo) from f where f.id = any (s2.ids)) as suma
             from s2),
    mejor as (select * from s3 where s3.esc = (select min(z.esc) from s3 z))
    select (select count(*) from mejor),
           (select jsonb_build_object(
                     'facturas', (select jsonb_agg(jsonb_build_object('id', f.id, 'num', f.num, 'obra', f.obra, 'monto', f.saldo) order by f.fecha, f.id)
                                    from f where f.id = any (m.ids)),
                     'comision', nullif(m.suma - p_monto, 0), 'bruto', m.suma, 'marcadas', m.marc,
                     'tarifa', (select jsonb_strip_nulls(jsonb_build_object('pct', t.pct, 'fijo', t.fijo, 'tope', t.tope)) from t where t.tn = m.tn and t.tn > 0))
              from mejor m limit 1)
      into v_n, v_res;
    if v_n = 1 then
      return jsonb_strip_nulls(v_res);
    elsif v_n > 1 then
      return jsonb_build_object('varias', v_n);
    end if;
  end loop;
  return null;
end $$;
revoke execute on function public.fn_bandeja_cobro_de(jsonb, numeric, date, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_cobro_de(jsonb, numeric, date, text) to authenticated;
comment on function public.fn_bandeja_cobro_de(jsonb, numeric, date, text) is 'c17: las facturas con saldo (una, o varias juntas: hasta cuatro mientras haya pocas por cobrar; con muchas, menos, para que una suma no cuadre por casualidad) que explican un depósito al centavo o, de un procesador de tarjetas, netas de su comisión según una de sus tarifas (factura a factura; las confirmadas, antes); primero entre las marcadas cobradas en Proyectos. Solo si la respuesta es única; {varias} si hay que preguntar.';

-- La tarifa de un procesador que explica una comisión: de las suyas en
-- bandeja_config.tarifas, la primera que, factura a factura, da esa comisión
-- (con un centavo de holgura por factura; las confirmadas, antes). Nulo si
-- ninguna.
create or replace function public.fn_bandeja_tarifa(p_proc text, p_montos numeric[], p_comision numeric) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select y.y || jsonb_build_object('n', y.n)
    from bandeja_config g
    cross join lateral jsonb_array_elements(g.tarifas) with ordinality as y(y, n)
   where g.id = 1 and y.y->>'proc' = p_proc and jsonb_typeof(y.y->'pct') = 'number' and coalesce(p_comision, 0) > 0
     and abs((select sum(least(round(s * (y.y->>'pct')::numeric / 100 + coalesce((y.y->>'fijo')::numeric, 0), 2), coalesce((y.y->>'tope')::numeric, s)))
                from unnest(p_montos) s) - p_comision) <= 0.01 * cardinality(p_montos)
   order by coalesce((y.y->>'veces')::int, 0) desc, y.n
   limit 1
$$;
revoke execute on function public.fn_bandeja_tarifa(text, numeric[], numeric) from public, anon, service_role;
grant  execute on function public.fn_bandeja_tarifa(text, numeric[], numeric) to authenticated;
comment on function public.fn_bandeja_tarifa(text, numeric[], numeric) is 'c17: la tarifa de un procesador de tarjetas (de bandeja_config.tarifas) que, factura a factura, da esa comisión (las confirmadas, antes), con su lugar en la lista (n); nulo si ninguna.';

-- APRENDER del cobro con comisión que Edgar confirmó (facturas ENTERAS: de
-- un pago a cuenta no se aprende nada, lo decide quien llama):
--   · si una tarifa de la lista lo explica, queda CONFIRMADA una vez más
--     (veces): sus lotes se recomiendan antes que los de las demás;
--   · si ninguna lo explicaba, es un LOTE (dos facturas o más: de una sola
--     «comisión» escrita a mano no se saca una tarifa) y la comisión es un
--     tanto por ciento limpio (dos decimales, sin fijo) de cada factura, se
--     APUNTA (origen «aprendida», veces 1): desde entonces se prueba como
--     las de la lista, y con el segundo lote que la confirme pasa delante.
-- Devuelve la tarifa tocada ({proc, pct, fijo, tope?, origen?, veces}) o
-- nulo: fn_bandeja_hacer la deja en su registro, y deshacerlo le quita esa
-- vez (fn_bandeja_tarifa_olvidar).
create or replace function public.fn_bandeja_tarifa_aprender(p_proc text, p_montos numeric[], p_comision numeric) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_pct numeric;
  v_t   jsonb;
begin
  perform fn_bandeja_quien();
  if p_proc is null or coalesce(p_comision, 0) <= 0 or coalesce(cardinality(p_montos), 0) = 0 then
    return null;
  end if;
  v_t := fn_bandeja_tarifa(p_proc, p_montos, p_comision);
  if v_t is not null then
    -- la tarifa de la lista que explica este cobro queda confirmada (una vez más)
    perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
    update bandeja_config
       set tarifas = jsonb_set(tarifas, array[((v_t->>'n')::int - 1)::text, 'veces'], to_jsonb(coalesce((v_t->>'veces')::int, 0) + 1)),
           actualizado = now()
     where id = 1;
    perform set_config('mx_bandeja.escribe', '', true);
    return (v_t - 'n') || jsonb_build_object('veces', coalesce((v_t->>'veces')::int, 0) + 1);
  end if;
  if cardinality(p_montos) < 2 then
    return null;   -- una sola factura con una comisión que no es de la lista: puede ser un pago corto; no se aprende
  end if;
  v_pct := round(p_comision / (select sum(s) from unnest(p_montos) s) * 100, 2);
  if v_pct < 0.25 or v_pct > 3.5
     or abs((select sum(round(s * v_pct / 100, 2)) from unnest(p_montos) s) - p_comision) > 0.01 * cardinality(p_montos) then
    return null;   -- no es un tanto por ciento limpio de cada factura: no se aprende nada de un caso raro
  end if;
  v_t := jsonb_build_object('proc', p_proc, 'pct', v_pct, 'fijo', 0, 'origen', 'aprendida', 'veces', 1);
  perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
  update bandeja_config set tarifas = tarifas || jsonb_build_array(v_t), actualizado = now() where id = 1;
  perform set_config('mx_bandeja.escribe', '', true);
  return v_t;
end $$;
revoke execute on function public.fn_bandeja_tarifa_aprender(text, numeric[], numeric) from public, anon, service_role;
grant  execute on function public.fn_bandeja_tarifa_aprender(text, numeric[], numeric) to authenticated;
comment on function public.fn_bandeja_tarifa_aprender(text, numeric[], numeric) is 'c17: aprende del cobro con comisión que Edgar confirmó: la tarifa de la lista que lo explica queda confirmada (veces) y, si ninguna lo explicaba, es un lote de dos facturas o más y es un tanto por ciento limpio de cada una, se apunta en bandeja_config.tarifas (origen «aprendida»). Devuelve la tarifa tocada. Solo el dueño, con su sesión.';

-- OLVIDAR lo que un cobro enseñó de una tarifa: al deshacerlo (p_todo falso:
-- se le quita esa vez; la aprendida que se queda sin ninguna se borra de la
-- lista) o porque Edgar la quita de «Lo que recuerdo» (p_todo: la aprendida
-- se borra; a una de la lista se le quitan sus confirmaciones). p: {proc,
-- pct, fijo, tope}. Devuelve {proc, pct, quitada | veces} o nulo si no está.
create or replace function public.fn_bandeja_tarifa_olvidar(p jsonb, p_todo boolean default false) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_i   int;
  v_t   jsonb;
  v_n   int;
  v_fue boolean;
begin
  perform fn_bandeja_quien();
  select y.n::int - 1, y.y into v_i, v_t
    from bandeja_config g
    cross join lateral jsonb_array_elements(g.tarifas) with ordinality as y(y, n)
   where g.id = 1 and y.y->>'proc' = p->>'proc' and (y.y->>'pct')::numeric = (p->>'pct')::numeric
     and coalesce((y.y->>'fijo')::numeric, 0) = coalesce((p->>'fijo')::numeric, 0)
     and (y.y->>'tope')::numeric is not distinct from (p->>'tope')::numeric
   order by (y.y->>'origen' = 'aprendida') desc nulls last, y.n
   limit 1;
  if v_i is null then
    return null;
  end if;
  v_n := case when coalesce(p_todo, false) then 0 else greatest(coalesce((v_t->>'veces')::int, 0) - 1, 0) end;
  v_fue := coalesce(v_t->>'origen' = 'aprendida', false) and v_n = 0;
  perform set_config('mx_bandeja.escribe', 'bandeja_config', true);
  update bandeja_config
     set tarifas = case when v_fue then tarifas - v_i
                        when v_n = 0 then jsonb_set(tarifas, array[v_i::text], (tarifas->v_i) - 'veces')
                        else jsonb_set(tarifas, array[v_i::text, 'veces'], to_jsonb(v_n)) end,
         actualizado = now()
   where id = 1;
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_strip_nulls(jsonb_build_object('proc', v_t->>'proc', 'pct', (v_t->>'pct')::numeric, 'quitada', case when v_fue then true end,
                                              'veces', case when not v_fue then v_n end));
end $$;
revoke execute on function public.fn_bandeja_tarifa_olvidar(jsonb, boolean) from public, anon, service_role;
grant  execute on function public.fn_bandeja_tarifa_olvidar(jsonb, boolean) to authenticated;
comment on function public.fn_bandeja_tarifa_olvidar(jsonb, boolean) is 'c17: olvida lo que un cobro enseñó de la tarifa de un procesador: le quita una confirmación (al deshacer ese cobro) o todas (p_todo: la quita Edgar); la aprendida que se queda sin ninguna se borra de la lista. Solo el dueño, con su sesión.';

-- ¿ES DE UN PRESTAMISTA? Los préstamos dados de alta, por su DESCRIPTOR (lo
-- que escribe el banco, dicho al darlo de alta) o por su NOMBRE ENTERO (todas
-- sus palabras, en orden y seguidas: «ZZ CAPITAL UNO»); y, si no, las marcas
-- corrientes de un préstamo de negocio (si esa marca es la de UN préstamo
-- dado de alta, es ese). UNA palabra del nombre no basta: un cliente que se
-- apellida como el banco del préstamo, o el banco de origen de una
-- transferencia, salían como un préstamo. Un Zelle (o Venmo, Cash App) lo
-- manda una persona o un cliente, nunca un prestamista. {prestamo_id,
-- prestamista, cuenta, conocido, por (descriptor | nombre | marca)} o nulo.
-- Un depósito así NO es el cobro de un cliente: fn_bandeja_recomendar lo
-- propone como préstamo y fn_bandeja_hacer FRENA cualquier otra respuesta
-- que lo trate como dinero de un cliente (venga de donde venga: la lista,
-- lo que entendió la IA o una opción de c6).
create or replace function public.fn_bandeja_prestamista(p_desc_norm text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v      text := upper(coalesce(p_desc_norm, ''));
  e      text;
  r      record;
  m      text[];
  v_nom  text;
  v_n    int;
  v_id   uuid;
begin
  e := ' ' || v || ' ';
  if v = '' or position(' ZELLE ' in e) > 0 or position(' VENMO ' in e) > 0 or position(' CASHAPP ' in e) > 0 or position(' CASH APP ' in e) > 0 then
    return null;
  end if;
  for r in select p.id, p.prestamista, p.cuenta, p.descriptor from prestamos p order by p.creado_el, p.id loop
    begin
      if nullif(btrim(coalesce(r.descriptor, '')), '') is not null and v ~* r.descriptor then
        return jsonb_build_object('prestamo_id', r.id, 'prestamista', r.prestamista, 'cuenta', r.cuenta, 'conocido', true, 'por', 'descriptor');
      end if;
    exception when others then
      null;  -- un descriptor que no es una expresión regular válida: no casa
    end;
    v_nom := btrim(regexp_replace(upper(coalesce(r.prestamista, '')), '[^[:alnum:]]+', ' ', 'g'));
    v_nom := btrim(regexp_replace(v_nom, '( (INC|LLC|CORP|CO|LTD|NA))+$', ''));
    if position(' ' in v_nom) > 0 and position(' ' || v_nom || ' ' in e) > 0 then
      return jsonb_build_object('prestamo_id', r.id, 'prestamista', r.prestamista, 'cuenta', r.cuenta, 'conocido', true, 'por', 'nombre');
    end if;
  end loop;
  m := regexp_match(v, '\m(ONDECK|ON DECK|KABBAGE|BLUEVINE|FUNDBOX|KAPITUS|LENDINGCLUB|LENDING CLUB|FUNDING CIRCLE|CREDIBLY|RAPID FINANCE|NATIONAL FUNDING|FORWARD FINANCING|HEADWAY CAPITAL|SQUARE CAPITAL|SQ CAPITAL|QUICKBOOKS CAPITAL|QB CAPITAL|INTUIT FINANCING)\M');
  if m is not null then
    select count(*), min(p.id::text)::uuid into v_n, v_id
      from prestamos p
     where regexp_replace(upper(coalesce(p.prestamista, '')), '[^[:alnum:]]+', '', 'g') like '%' || replace(m[1], ' ', '') || '%';
    if v_n = 1 then
      return (select jsonb_build_object('prestamo_id', p.id, 'prestamista', p.prestamista, 'cuenta', p.cuenta, 'conocido', true, 'por', 'marca')
                from prestamos p where p.id = v_id);
    end if;
    return jsonb_build_object('prestamista', case when m[1] in ('ONDECK', 'ON DECK') then 'OnDeck' else initcap(m[1]) end,
                              'cuenta', '2540', 'conocido', false, 'por', 'marca');
  end if;
  m := regexp_match(v, '\m(SBAD TREAS|SBA EIDL|WORKING CAPITAL|LOAN PROCEEDS|LOAN FUNDING|LOAN DISBURSEMENT|LOAN ADVANCE|CAPITAL ADVANCE|MERCHANT CASH ADVANCE)\M');
  if m is not null then
    return jsonb_build_object('prestamista', initcap(m[1]), 'cuenta', '2540', 'conocido', false, 'por', 'marca');
  end if;
  return null;
end $$;
revoke execute on function public.fn_bandeja_prestamista(text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_prestamista(text) to authenticated;
comment on function public.fn_bandeja_prestamista(text) is 'c17: si la descripción del banco nombra a un prestamista (los dados de alta en prestamos, por su descriptor o su nombre entero; o las marcas corrientes de un préstamo de negocio): {prestamo_id, prestamista, cuenta, conocido, por} o nulo. Nunca por una palabra suelta ni en un Zelle.';

-- LOS PENDIENTES QUE PUEDEN SER DE UN PRESTAMISTA, de una vez: los que
-- nombran una marca de préstamo, o casan con el descriptor o con el nombre
-- entero de un préstamo dado de alta. Es para fn_bandeja_leer: mirar eso
-- movimiento a movimiento (un descriptor por préstamo, cada uno una
-- expresión regular) costaba más que todo lo demás de la tarjeta; aquí cada
-- descriptor se mira una vez contra todos. Devuelve {<movimiento>: true}
-- de los que HAY QUE MIRAR con fn_bandeja_prestamista (de más, nunca de
-- menos); los demás no son de un prestamista.
create or replace function public.fn_bandeja_prestamista_quiza(p_ids uuid[] default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v      uuid[];
  x      uuid[];
  r      record;
  v_nom  text;
begin
  perform fn_bandeja_exigir_dueno();
  select coalesce(array_agg(mb.id), '{}') into v
    from movimientos_banco mb
   where mb.estado = 'pendiente' and (p_ids is null or mb.id = any (p_ids))
     and upper(mb.desc_norm) ~ '\m(ONDECK|ON DECK|KABBAGE|BLUEVINE|FUNDBOX|KAPITUS|LENDINGCLUB|LENDING CLUB|FUNDING CIRCLE|CREDIBLY|RAPID FINANCE|NATIONAL FUNDING|FORWARD FINANCING|HEADWAY CAPITAL|SQUARE CAPITAL|SQ CAPITAL|QUICKBOOKS CAPITAL|QB CAPITAL|INTUIT FINANCING|SBAD TREAS|SBA EIDL|WORKING CAPITAL|LOAN PROCEEDS|LOAN FUNDING|LOAN DISBURSEMENT|LOAN ADVANCE|CAPITAL ADVANCE|MERCHANT CASH ADVANCE)\M';
  for r in select p.prestamista, p.descriptor from prestamos p loop
    begin
      if nullif(btrim(coalesce(r.descriptor, '')), '') is not null then
        select array_agg(mb.id) into x
          from movimientos_banco mb
         where mb.estado = 'pendiente' and (p_ids is null or mb.id = any (p_ids)) and upper(mb.desc_norm) ~* r.descriptor;
        v := v || coalesce(x, '{}');
      end if;
    exception when others then
      null;  -- un descriptor que no es una expresión regular válida: no casa con nada
    end;
    v_nom := btrim(regexp_replace(upper(coalesce(r.prestamista, '')), '[^[:alnum:]]+', ' ', 'g'));
    v_nom := btrim(regexp_replace(v_nom, '( (INC|LLC|CORP|CO|LTD|NA))+$', ''));
    if position(' ' in v_nom) > 0 then
      select array_agg(mb.id) into x
        from movimientos_banco mb
       where mb.estado = 'pendiente' and (p_ids is null or mb.id = any (p_ids))
         and position(' ' || v_nom || ' ' in ' ' || upper(mb.desc_norm) || ' ') > 0;
      v := v || coalesce(x, '{}');
    end if;
  end loop;
  return (select coalesce(jsonb_object_agg(u.id, true), '{}'::jsonb) from (select distinct unnest(v) as id) u);
end $$;
revoke execute on function public.fn_bandeja_prestamista_quiza(uuid[]) from public, anon, service_role;
grant  execute on function public.fn_bandeja_prestamista_quiza(uuid[]) to authenticated;
comment on function public.fn_bandeja_prestamista_quiza(uuid[]) is 'c17: los movimientos pendientes que pueden ser de un prestamista ({id: true}), mirados de una vez (cada descriptor contra todos): los únicos que fn_bandeja_leer manda mirar con fn_bandeja_prestamista.';

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

-- LA HUELLA de una opción de c6: a qué puerta llama y con qué. c6 rehace las
-- opciones de un pendiente en cada «Casar» (al importar, cada mañana con
-- Plaid, con el botón): el NÚMERO de una opción puede pasar a ser otra cosa
-- entre que Edgar la lee y la toca. La huella viaja con lo que se enseñó y
-- se compara al registrar: lo que se registra es lo que Edgar leyó, o nada.
create or replace function public.fn_bandeja_opcion_huella(p_opcion jsonb) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select md5(coalesce(p_opcion->>'llamar', '') || '|' || coalesce((p_opcion->'args')::text, '')) $$;
revoke execute on function public.fn_bandeja_opcion_huella(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_opcion_huella(jsonb) to authenticated;
comment on function public.fn_bandeja_opcion_huella(jsonb) is 'c17: la huella de una opción de c6 (la puerta que llama y sus argumentos): lo que se registra es la opción que Edgar leyó, no la que haya hoy en ese número.';

-- Una opción de c6 dicha en llano: no la etiqueta corta de su botón («A
-- 2100-2013 (Amex Business Gold)», «Cuota de ZZ Capital Uno»), sino lo que
-- la opción HACE (la puerta que llama y sus argumentos), con el monto y sin
-- códigos de cuenta: «Es el pago de tu tarjeta Amex Business Gold:
-- $4,305.89 (sale del banco y baja lo que debes en la tarjeta)».
drop function if exists public.fn_bandeja_opcion_texto(jsonb, numeric);
create or replace function public.fn_bandeja_opcion_texto(p_opcion jsonb, p_monto numeric, p_movimiento uuid default null) returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c_uuid constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  v_fn   text := coalesce(p_opcion->>'llamar', '');
  a      jsonb := case when jsonb_typeof(p_opcion->'args') = 'object' then p_opcion->'args' else '{}'::jsonb end;
  v_usd  text := fn_bandeja_usd(abs(p_monto));
  m      movimientos_banco;
  x      jsonb;
  r      record;
  v_cta  text;
  v_nom  text;
  v_obra text;
  v_tipo text;
  v_tarj boolean;
  v_f    date;
  v_num  numeric;
  v_com  numeric := 0;
  v_id   uuid;
  v_n    int;
  v_txt  text[] := '{}';
  v_t    text;
begin
  if p_movimiento is not null then
    select * into m from movimientos_banco where id = p_movimiento;
  end if;
  if v_fn = 'fn_banco_clasificar' and jsonb_typeof(a->'p_lineas') = 'array' and jsonb_array_length(a->'p_lineas') = 1 then
    x := a->'p_lineas'->0;
    v_cta := x->>'cuenta';
    if x ? 'factura_id' then
      return format('Es un cheque devuelto de la factura #%s: vuelve a quedar por cobrar (%s).',
                    coalesce((select f.num from facturas f where f.id = case when x->>'factura_id' ~ '^-?[0-9]{1,18}$' then (x->>'factura_id')::bigint end), '?'), v_usd);
    end if;
    select k.tipo, k.nombre into v_tipo, v_nom from cuentas k where k.codigo = v_cta;
    v_obra := (select p.nombre from proyectos p where p.id = x->>'proyecto_id');
    return case
             when v_cta = '3200' then format('Es tuyo, no de la empresa: %s que salen como retiro tuyo.', v_usd)
             when v_cta = '2900' then format('Es dinero tuyo que le prestas a la empresa: %s.', v_usd)
             when v_cta = '3100' then format('Es dinero tuyo que aportas a la empresa: %s.', v_usd)
             when v_cta = '1050' then format('Es efectivo para la caja chica: %s.', v_usd)
             when v_tipo = 'pasivo' and p_monto < 0 then format('Es un pago a «%s»: %s (baja lo que se debe).', coalesce(v_nom, 'una deuda'), v_usd)
             when v_tipo = 'pasivo' then format('Es dinero de «%s»: %s (sube lo que se debe; no es un ingreso).', coalesce(v_nom, 'una deuda'), v_usd)
             when p_monto > 0 and v_tipo in ('costo', 'gasto', 'otro_gasto')
               then format('Es la devolución de una compra de «%s»%s: entran %s.', fn_bandeja_cuenta_llana(v_cta), coalesce(' de la obra ' || v_obra, ''), v_usd)
             else format('Es «%s»%s: %s.', fn_bandeja_cuenta_llana(v_cta), coalesce(' de la obra ' || v_obra, ''), v_usd) end;
  elsif v_fn = 'fn_banco_transferencia' then
    select k.nombre, exists (select 1 from tarjetas t where t.cuenta = k.codigo) into v_nom, v_tarj
      from cuentas k where k.codigo = a->>'p_cuenta';
    if v_nom is not null then
      return case when v_tarj and p_monto < 0
                    then format('Es el pago de tu tarjeta %s: %s (sale del banco y baja lo que debes en la tarjeta).', v_nom, v_usd)
                  when p_monto > 0 and m.id is not null and exists (select 1 from tarjetas t where t.cuenta = m.cuenta)
                    then format('Es el pago de esta tarjeta, hecho desde %s: %s.', v_nom, v_usd)
                  when p_monto < 0 then format('Es dinero que pasaste a tu cuenta %s: %s (un traspaso, no un gasto).', v_nom, v_usd)
                  else format('Es dinero que llegó de tu cuenta %s: %s (un traspaso, no un ingreso).', v_nom, v_usd) end;
    end if;
  elsif v_fn = 'fn_banco_casar_con' and jsonb_typeof(a->'p_con') = 'object' then
    x := a->'p_con';
    if coalesce(x->>'movimiento', '') ~ c_uuid then
      select mb.fecha, k.nombre into v_f, v_nom
        from movimientos_banco mb join cuentas k on k.codigo = mb.cuenta where mb.id = (x->>'movimiento')::uuid;
      return format('Es un traspaso entre tus cuentas (%s): su otro lado es el movimiento del %s en %s.', v_usd, fn_bandeja_dia(v_f),
                    coalesce(v_nom, 'tu otra cuenta'));
    elsif coalesce(x->>'cobro', '') ~ c_uuid then
      select c.fecha, c.monto into v_f, v_num from cobros c where c.id = (x->>'cobro')::uuid;
      return format('Es el depósito de un cobro que ya estaba anotado (el del %s por %s).', fn_bandeja_dia(v_f), fn_bandeja_usd(v_num));
    elsif x ? 'partida_apertura' then
      return 'Es algo que venía de QuickBooks, de antes del 1 de octubre: ya está contado en el saldo con que arrancó la app.';
    end if;
    v_id := coalesce(case when coalesce(x->>'asiento', '') ~ c_uuid then (x->>'asiento')::uuid end,
                     case when jsonb_typeof(x->'lineas') = 'array' and coalesce(x->'lineas'->0->>'asiento_id', '') ~ c_uuid
                          then (x->'lineas'->0->>'asiento_id')::uuid end,
                     (select rc.contabilizado_en from recibos rc
                       where rc.id = case when x->>'recibo' ~ '^-?[0-9]{1,18}$' then (x->>'recibo')::bigint end));
    select z.origen_tabla, z.origen_id, z.fecha_contable into r from asientos z where z.id = v_id;
    if r.origen_tabla = 'recibos' then
      v_n := coalesce((select count(distinct l->>'asiento_id') from jsonb_array_elements(case when jsonb_typeof(x->'lineas') = 'array' then x->'lineas'
                                                                                               else '[]'::jsonb end) l), 1);
      select coalesce(rc.fecha, r.fecha_contable), rc.total, p.nombre into v_f, v_num, v_obra
        from recibos rc left join proyectos p on p.id = rc.proyecto_id
       where rc.id = case when r.origen_id ~ '^-?[0-9]{1,18}$' then r.origen_id::bigint end;
      return case when v_n > 1 then format('Es su recibo, repartido entre %s obras (la misma foto, %s).', v_n, v_usd)
                  else format('Es su recibo: el del %s por %s%s.', fn_bandeja_dia(v_f), fn_bandeja_usd(coalesce(v_num, abs(p_monto))),
                              coalesce(', de la obra ' || v_obra, '')) end
             || case when m.estado = 'casado' then ' Se cambia lo que se había registrado por el recibo (el gasto queda una sola vez).' else '' end;
    elsif r.origen_tabla = 'cobros' then
      return format('Es el depósito de un cobro que ya estaba anotado (del %s).', fn_bandeja_dia(r.fecha_contable));
    elsif v_id is not null and exists (select 1 from prestamo_cuotas q where q.asiento_id = v_id) then
      return (select format('Es la cuota de %s del %s, que ya estaba registrada: se casa con ella.', p.prestamista, fn_bandeja_dia(q.fecha))
                from prestamo_cuotas q join prestamos p on p.id = q.prestamo_id where q.asiento_id = v_id limit 1);
    elsif v_id is not null then
      return format('Ya está en el libro: es el otro lado de un traspaso del %s (%s).', fn_bandeja_dia(r.fecha_contable), v_usd);
    end if;
  elsif v_fn = 'fn_banco_cobrar' and jsonb_typeof(a->'p_aplicaciones') = 'array' then
    v_n := (select count(*) from jsonb_array_elements(a->'p_aplicaciones') y where y ? 'factura_id' or y ? 'proyecto_id');
    select coalesce(sum(fn_bandeja_num(y->>'comision')), 0) into v_com from jsonb_array_elements(a->'p_aplicaciones') y where y ? 'comision';
    for x in select value from jsonb_array_elements(a->'p_aplicaciones') loop
      if x ? 'factura_id' then
        select fc.num, coalesce(fc.saldo_cxc, 0) as saldo, coalesce(fc.saldo_retencion, 0) as ret, p.nombre as obra into r
          from facturas_cobro fc left join proyectos p on p.id = fc.proyecto_id
         where fc.id = case when x->>'factura_id' ~ '^-?[0-9]{1,18}$' then (x->>'factura_id')::bigint end;
        v_num := coalesce(fn_bandeja_num(x->>'monto'), case when v_n = 1 then p_monto + v_com end);
        v_txt := v_txt || case
          when coalesce((x->>'es_retencion')::boolean, false)
            then format('la retención de la factura #%s de %s (%s)', r.num, coalesce(r.obra, 'una obra'), fn_bandeja_usd(v_num))
          when v_num < r.saldo
            then format('una parte de la factura #%s de %s (%s de los %s que le quedan: quedarían %s por cobrar)', r.num, coalesce(r.obra, 'una obra'),
                        fn_bandeja_usd(v_num), fn_bandeja_usd(r.saldo), fn_bandeja_usd(r.saldo - v_num))
          else format('la factura #%s de %s (%s)', r.num, coalesce(r.obra, 'una obra'), fn_bandeja_usd(v_num)) end;
      elsif x ? 'proyecto_id' then
        v_txt := v_txt || format('un anticipo de la obra %s (%s)', coalesce((select p.nombre from proyectos p where p.id = x->>'proyecto_id'), '?'),
                                 fn_bandeja_usd(coalesce(fn_bandeja_num(x->>'monto'), p_monto)));
      end if;
    end loop;
    if cardinality(v_txt) > 0 then
      return format('Es el cobro de %s.', array_to_string(v_txt, ' y de '))
             || case when v_com > 0 then format(' Pagaron con tarjeta: el procesador se quedó %s de comisión y llegaron %s.', fn_bandeja_usd(v_com), v_usd)
                     else '' end;
    end if;
  elsif v_fn = 'fn_banco_pagar_proveedor' then
    v_nom := (select pv.nombre from proveedores pv where pv.id = case when coalesce(a->>'p_proveedor', '') ~ c_uuid then (a->>'p_proveedor')::uuid end);
    if v_nom is not null then
      return case when p_monto < 0 then format('Es el pago a %s: %s (baja lo que le debes; su gasto ya entró con sus recibos).', v_nom, v_usd)
                  else format('Es un reembolso de %s: %s (contra lo que tenía a tu favor).', v_nom, v_usd) end;
    end if;
  elsif v_fn = 'fn_banco_duplicado' then
    return case when coalesce((a->>'p_es_el_mismo')::boolean, false) then 'Es el mismo movimiento que ya entró por otro lado: este no cuenta.'
                when m.estado = 'casado' then 'No es su recibo: es otra compra (las dos cuentan).'
                else 'Es otro movimiento, distinto del que ya estaba: los dos cuentan.' end;
  elsif v_fn = 'fn_banco_devolver' and coalesce(a->>'p_cobro', '') ~ c_uuid then
    select c.fecha, c.monto into v_f, v_num from cobros c where c.id = (a->>'p_cobro')::uuid;
    return format('Es un cheque que el banco devolvió: se deshace el cobro del %s por %s y la factura vuelve a quedar por cobrar.',
                  fn_bandeja_dia(v_f), fn_bandeja_usd(v_num));
  elsif v_fn = 'fn_prestamo_cuota' and coalesce(a->>'p_prestamo', '') ~ c_uuid then
    v_nom := (select p.prestamista from prestamos p where p.id = (a->>'p_prestamo')::uuid);
    if p_opcion->'pide' ?| array['p_capital', 'p_interes'] then
      return format('Es un pago a %s: %s. Dime cuánto bajó la deuda y cuánto fue de intereses (lo dice su estado de cuenta).',
                    coalesce(v_nom, 'un préstamo'), v_usd);
    end if;
    x := case when a ? 'p_capital' then jsonb_build_object('capital', a->>'p_capital', 'interes', a->>'p_interes') else m.propuesta->'particion' end;
    return format('Es la cuota de %s: %s%s.', coalesce(v_nom, 'un préstamo'), v_usd,
                  case when fn_bandeja_num(x->>'capital') is not null and fn_bandeja_num(x->>'interes') is not null
                       then format(' (%s bajan la deuda y %s son intereses)', fn_bandeja_usd(fn_bandeja_num(x->>'capital')),
                                   fn_bandeja_usd(fn_bandeja_num(x->>'interes'))) else '' end);
  end if;
  -- lo demás: el texto de c6, sin jerga y con el nombre de la obra donde trae su identificador
  v_t := coalesce(regexp_replace(fn_bandeja_llano(p_opcion->>'texto'), '[.:;, ]+$', ''), 'Lo que propone el banco');
  for r in select distinct p.id, p.nombre from regexp_matches(v_t, '\(([a-z0-9]+(?:-[a-z0-9]+)+)\)', 'g') g join proyectos p on p.id = g[1] loop
    v_t := replace(v_t, '(' || r.id || ')', '(' || r.nombre || ')');
  end loop;
  return v_t || '.';
end $$;
revoke execute on function public.fn_bandeja_opcion_texto(jsonb, numeric, uuid) from public, anon, service_role;
grant  execute on function public.fn_bandeja_opcion_texto(jsonb, numeric, uuid) to authenticated;
comment on function public.fn_bandeja_opcion_texto(jsonb, numeric, uuid) is 'c17: una opción de c6 en palabras llanas, por lo que HACE (su puerta y sus argumentos) y con el monto: sin códigos de cuenta ni nombres de funciones.';

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
  c        jsonb;
  v_falta  text;
  v_texto  text;
  v_obra   text;
  v_est    text;
  v_pide   boolean := false;
  v_cambio boolean := false;
  v_usd    text;
  v_apps   jsonb := '[]'::jsonb;
  v_suma   numeric := 0;
  v_tope   numeric := 0;
  v_com    numeric;
  v_n      int;
  v_m      numeric;
  v_rt     numeric;
  v_txt    text[] := '{}';
  v_nom    text;
  v_cta    text;
  v_id     text;
  v_i      int;
  v_op     jsonb;
  v_tarj   boolean;
  v_cta_a  boolean := false;
  pr       jsonb;
  c_uuid   constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  c_activa constant text[] := array['aprobado', 'ejecucion', 'pausa'];
begin
  perform fn_bandeja_exigir_dueno();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    return jsonb_build_object('ok', false, 'falta', 'Ese movimiento ya no existe.');
  end if;
  -- (un cargo ya registrado cuyo recibo llegó después se contesta con las opciones que c6 le puso: «es su recibo» o «es otra compra»)
  if m.estado <> 'pendiente' and not (coalesce(p_accion, '') = 'banco' and m.estado = 'casado' and m.propuesta->>'motivo' = 'llego_su_ticket') then
    -- (fuera: ya no espera respuesta —se registró desde otra pestaña, o la contestación de antes se perdió por el camino—; la
    -- pantalla no lo da por «no guardado»: vuelve a leer la Bandeja)
    return jsonb_build_object('ok', false, 'fuera', true, 'falta', 'Ese movimiento ya no está en la Bandeja: ya estaba contestado.');
  end if;
  v_usd := fn_bandeja_usd(abs(m.monto));
  case coalesce(p_accion, '')
    when 'gasto' then
      select * into k from cuentas c2 where c2.codigo = nullif(btrim(coalesce(d->>'cuenta', '')), '');
      if not found then
        v_falta := 'Falta decir qué tipo de gasto es.';
      elsif k.codigo in ('3200', '1130') or not exists (select 1 from v_contador_cuentas c2 where c2.codigo = k.codigo)
            -- (un gasto es un costo o un gasto; en un cargo, también la compra de un equipo —15xx—. Una deuda, el patrimonio o lo
            -- que se debe de nómina tienen su propia respuesta, no «gasto»)
            or not (k.tipo in ('costo', 'gasto', 'otro_gasto') or (m.monto < 0 and k.tipo = 'activo' and k.codigo like '15%')) then
        v_falta := format('«%s» no se puede usar desde la Bandeja como un gasto.', k.nombre);
      else
        o := jsonb_build_object('cuenta', k.codigo);
        v_id := nullif(btrim(coalesce(d->>'proyecto_id', '')), '');
        if k.regla_obra in ('obligatoria', 'opcional') and v_id is not null then
          select p.nombre, p.estado into v_obra, v_est from proyectos p where p.id = v_id;
          if v_obra is null then
            v_falta := 'Esa obra no existe en Proyectos.';
          else
            o := o || jsonb_build_object('proyecto_id', v_id);
            v_obra := v_obra || case when v_est = any (c_activa) then '' else ' (que ya no está en marcha)' end;
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
      o := jsonb_build_object('cuenta', '3200');
      if m.monto < 0 then
        v_texto := format('Es tuyo, no de la empresa: %s que salen como retiro tuyo (no es un gasto del negocio).', v_usd);
      else
        -- (la devolución de un cargo personal: lo que salió como retiro tuyo, vuelve; no es un ingreso del negocio)
        v_texto := format('Es la devolución de algo tuyo (un cargo personal que te devolvieron): entran %s y baja lo que llevas '
                          'retirado. No es un ingreso del negocio.', v_usd);
      end if;
    when 'cobro' then
      if m.monto <= 0 then
        v_falta := 'Un cobro es dinero que entra, y esto es dinero que salió.';
      elsif jsonb_typeof(d->'facturas') is distinct from 'array' or jsonb_array_length(d->'facturas') = 0 then
        v_falta := 'Falta decir qué factura paga este depósito.';
      else
        v_com := coalesce(fn_bandeja_num(d->>'comision'), 0);
        v_n := jsonb_array_length(d->'facturas');
        c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
        if v_com < 0 then
          v_falta := 'La comisión no puede ser negativa.';
        elsif v_com > 0 and c->>'clase' is distinct from 'procesador' then
          -- (una comisión es lo que se queda un procesador de tarjetas: un Zelle o un cheque corto es un pago parcial)
          v_falta := 'Este depósito no viene de un procesador de tarjetas: lo que falta para cubrir la factura no es una comisión. Si el '
                     'cliente pagó menos, es un pago parcial: di cuánto va a cada factura.';
        elsif v_com >= m.monto then
          v_falta := 'La comisión no puede ser más que lo que llegó al banco.';
        end if;
        for x in select value from jsonb_array_elements(d->'facturas') loop
          exit when v_falta is not null;
          v_id := case when jsonb_typeof(x) = 'object' then x->>'id' else x #>> '{}' end;
          select fc.id, fc.num, fc.proyecto_id, coalesce(fc.saldo_cxc, 0) as saldo, coalesce(fc.saldo_retencion, 0) as ret,
                 coalesce(fc.estado, 'emitida') as estado, p.nombre as obra
            into f
            from facturas_cobro fc
            left join proyectos p on p.id = fc.proyecto_id
           where fc.id = case when v_id ~ '^-?[0-9]{1,18}$' then v_id::bigint end;
          if not found then
            v_falta := 'Una de las facturas no existe en Proyectos.';
          elsif f.estado = 'anulada' then
            v_falta := format('La factura #%s está anulada.', f.num);
          elsif f.saldo <= 0 and f.ret <= 0 then
            v_falta := format('La factura #%s no tiene nada por cobrar en el libro: ya está cobrada allí, o todavía no ha entrado.', f.num);
          else
            -- lo que se le aplica: primero a lo que se le debe y, lo que pase de eso, a su retención
            v_m := coalesce(case when jsonb_typeof(x) = 'object' then fn_bandeja_num(x->>'monto') end,
                            case when v_n = 1 then m.monto + v_com when f.saldo > 0 then f.saldo else f.ret end);
            v_rt := greatest(v_m - f.saldo, 0);
            if v_m <= 0 or v_rt > f.ret then
              v_falta := case when f.saldo <= 0
                              then format('A la factura #%s solo le queda su retención (%s), y aquí le tocarían %s.', f.num, fn_bandeja_usd(f.ret),
                                          fn_bandeja_usd(v_m))
                              else format('A la factura #%s le quedan %s por cobrar%s, y aquí le tocarían %s.', f.num, fn_bandeja_usd(f.saldo),
                                          case when f.ret > 0 then format(' (más %s de retención)', fn_bandeja_usd(f.ret)) else '' end,
                                          fn_bandeja_usd(v_m)) end;
            else
              v_apps := v_apps || jsonb_strip_nulls(jsonb_build_object('id', f.id, 'num', f.num, 'obra', f.obra, 'proyecto_id', f.proyecto_id,
                                                                       'monto', v_m, 'retencion', nullif(v_rt, 0)));
              v_cta_a := v_cta_a or (f.saldo > 0 and v_m < f.saldo);
              v_suma := v_suma + v_m;
              v_tope := v_tope + round(0.035 * v_m + 0.30, 2);
              v_txt := v_txt || case when f.saldo <= 0
                                       then format('#%s de %s, su retención (%s)', f.num, coalesce(f.obra, 'una obra'), fn_bandeja_usd(v_m))
                                     when v_rt > 0
                                       then format('#%s de %s (%s, con su retención)', f.num, coalesce(f.obra, 'una obra'), fn_bandeja_usd(v_m))
                                     when v_m < f.saldo
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
        -- (el tope de c6, factura a factura: 3.5 % más 30 centavos de cada una)
        if v_falta is null and v_com > v_tope then
          v_falta := format('La diferencia (%s) es más de lo que se queda un procesador de tarjetas (como mucho un 3.5 %% más 30 centavos '
                            'por factura: %s). Si el cliente pagó menos, es un pago parcial: di cuánto va a cada factura.',
                            fn_bandeja_usd(v_com), fn_bandeja_usd(v_tope));
        end if;
        -- (a_cuenta: alguna factura no queda saldada. De un pago a cuenta no se aprende la tarifa de un procesador)
        o := jsonb_strip_nulls(jsonb_build_object('facturas', v_apps, 'comision', nullif(v_com, 0), 'a_cuenta', case when v_cta_a then true end));
        v_texto := case when v_n = 1 then format('Es el cobro de la factura %s.', v_txt[1])
                        else format('Es el cobro de %s facturas: %s.', v_n, array_to_string(v_txt, ', ')) end
                   || case when v_com > 0
                           then format(' Pagaron con tarjeta: %s se quedó %s de comisión y llegaron %s.',
                                       coalesce(c->>'nombre', 'el procesador'), fn_bandeja_usd(v_com), v_usd)
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
      v_texto := format('Es un anticipo de la obra %s (dinero a cuenta, sin aplicarlo a ninguna factura): %s.', coalesce(v_obra, '(falta la obra)'), v_usd);
    when 'prestamo' then
      if m.monto <= 0 then
        v_falta := 'Un préstamo recibido es dinero que entra; la cuota de un préstamo tiene su propia opción.';
      else
        pr := fn_bandeja_prestamista(m.desc_norm);
        if coalesce(d->>'prestamo_id', '') ~ c_uuid then
          select p.prestamista, p.cuenta into v_nom, v_cta from prestamos p where p.id = (d->>'prestamo_id')::uuid;
          if v_nom is null then
            v_falta := 'Ese préstamo no está dado de alta.';
          else
            o := jsonb_build_object('prestamo_id', d->>'prestamo_id');
          end if;
        elsif coalesce((pr->>'conocido')::boolean, false) then
          -- (el banco mismo nombra a uno DADO DE ALTA: es ese, con su cuenta, aunque de fuera venga solo un nombre. Antes salía
          -- «todavía no está dado de alta» de un préstamo que sí lo estaba, y su dinero iba a la cuenta de los que no)
          v_nom := pr->>'prestamista';
          v_cta := pr->>'cuenta';
          o := jsonb_build_object('prestamo_id', pr->>'prestamo_id');
        else
          -- (el nombre puede venir de la IA: solo letras, números y . & ' -, sin números largos, cuarenta letras)
          v_nom := regexp_replace(coalesce(d->>'prestamista', ''), '[0-9][0-9 .()-]{6,}[0-9]', ' ', 'g');
          v_nom := nullif(left(btrim(regexp_replace(regexp_replace(v_nom, '[^[:alnum:] .&''-]+', ' ', 'g'), '\s+', ' ', 'g')), 40), '');
          v_cta := case when d->>'cuenta' in ('2510', '2520', '2540') then d->>'cuenta' else '2540' end;
          if v_nom is null then
            v_falta := 'Falta decir de quién es el préstamo.';
          end if;
        end if;
        if v_falta is null and not exists (select 1 from cuentas c2 where c2.codigo = v_cta and c2.imputable) then
          v_falta := 'La cuenta de ese préstamo no está en el plan de cuentas.';
        end if;
        o := o || jsonb_strip_nulls(jsonb_build_object('prestamista', v_nom, 'cuenta', v_cta));
        v_texto := format('Es dinero de un préstamo de %s: %s. Es una deuda, no el pago de un cliente.%s', coalesce(v_nom, '…'), v_usd,
                          case when o ? 'prestamo_id' or v_nom is null then '' else ' (Ese préstamo todavía no está dado de alta en la app.)' end);
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
      -- (las cuentas entre las que se traspasa: los bancos y las tarjetas, sin las de paso de los cobros en línea)
      select y->>'nombre', (y->>'tarjeta')::boolean into v_nom, v_tarj
        from jsonb_array_elements(fn_bandeja_cuentas_propias()) y
       where y->>'codigo' = v_cta and y->>'codigo' <> m.cuenta;
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
          select p.nombre into v_nom from perfiles p where p.id = (d->>'usuario_id')::uuid and p.rol <> 'dueno' and coalesce(p.activo, true);
        end if;
        if v_nom is null then
          v_falta := 'Falta decir a quién de la cuadrilla se le pagó (alguien que siga dado de alta).';
        else
          o := jsonb_build_object('usuario_id', d->>'usuario_id');
          v_texto := format('Es el pago a %s, de la cuadrilla: %s. Se reparte entre las obras según sus horas.', v_nom, v_usd);
        end if;
      end if;
    when 'contratista' then
      v_id := nullif(btrim(coalesce(d->>'proyecto_id', '')), '');
      select p.nombre || case when p.estado = any (c_activa) then '' else ' (que ya no está en marcha)' end into v_obra from proyectos p where p.id = v_id;
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
                          case when v_cta = '4910' then 'intereses que te paga el banco' else 'otro ingreso (una recompensa, un premio)' end, v_usd);
      end if;
    when 'banco' then
      v_i := case when coalesce(d->>'opcion', '') ~ '^[0-9]{1,2}$' then (d->>'opcion')::int end;
      v_op := case when v_i is not null and jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones'->v_i end;
      if v_op is null or jsonb_typeof(v_op) <> 'object' then
        v_falta := 'Esa opción ya no está entre las que el banco propone para este movimiento.';
        v_cambio := d ? 'huella';
      elsif d ? 'huella' and d->>'huella' is distinct from fn_bandeja_opcion_huella(v_op) then
        -- (c6 rehízo sus opciones desde que se enseñó: lo que hay hoy en ese número es otra cosa)
        v_falta := 'Lo que el banco proponía para este movimiento cambió desde que lo viste: mira lo que propone ahora.';
        v_cambio := true;
      elsif not (coalesce(v_op->>'llamar', '') = any (fn_bandeja_puertas())) then
        v_falta := 'Esa opción se contesta en «Más opciones».';
      else
        o := jsonb_strip_nulls(jsonb_build_object(
               'opcion', v_i, 'llamar', v_op->>'llamar', 'huella', fn_bandeja_opcion_huella(v_op),
               'pide', nullif(to_jsonb(fn_bandeja_opcion_pide(v_op)), '[]'::jsonb),
               'campos', case when jsonb_typeof(d->'campos') = 'object' then d->'campos' end));
        v_texto := fn_bandeja_opcion_texto(v_op, m.monto, m.id);
      end if;
    else
      raise exception using errcode = '22023',
        message = format('«%s» no está en la lista de lo que la Bandeja sabe registrar.', coalesce(p_accion, ''));
  end case;
  return jsonb_strip_nulls(jsonb_build_object(
    'ok', v_falta is null, 'accion', p_accion, 'datos', o, 'texto', v_texto, 'falta', v_falta, 'pide_obra', case when v_pide then true end,
    'cambio', case when v_cambio then true end));
end $$;
revoke execute on function public.fn_bandeja_validar(uuid, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_validar(uuid, text, jsonb) to authenticated;
comment on function public.fn_bandeja_validar(uuid, text, jsonb) is 'c17: valida una acción de la lista cerrada para un movimiento pendiente contra las cuentas, las obras, las facturas y los montos de la base: {ok, accion, datos, texto llano, falta, pide_obra, cambio}. No escribe nada. Otra acción, 22023.';


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
  v_sg    text;
  sg      jsonb;
  r       bandeja_memoria;
begin
  v_quien := fn_bandeja_quien();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    return null;
  end if;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  -- (lo que sugería la descripción de ESTE movimiento: con ello se sabe después si otro del mismo nombre es lo mismo)
  sg := case when m.monto < 0 then fn_bandeja_sugerida(m.desc_norm) end;
  v_sg := case when sg is not null then (sg->>'accion') || '|' || coalesce(sg->>'cuenta', '') end;
  if not (c ? 'clave') or (c->>'clase') not in ('comercio', 'zelle_a', 'zelle_de', 'deposito', 'procesador')
     or p_accion not in ('gasto', 'personal', 'cobro', 'anticipo', 'prestamo', 'aporte', 'traspaso', 'cuadrilla', 'contratista', 'otro_ingreso') then
    return null;   -- no dice quién (un cheque, el cajero) o no es algo que se recuerde (una opción de c6)
  end if;
  -- (un procesador de tarjetas deposita lo de MUCHOS clientes: de él no se recuerda «paga la obra X»)
  if c->>'clase' = 'procesador' and p_accion in ('cobro', 'anticipo') then
    return null;
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
  -- «que entre solo»: solo un comercio, y solo lo que NO lleva obra (un gasto general, o algo personal). Un costo de obra se
  -- PROPONE cada vez con la obra del día: qué obra fue no lo sabe una regla, y de esas compras suele llegar el recibo
  v_solo := coalesce(p_solo, false) and c->>'clase' = 'comercio'
            and (p_accion = 'personal' or (p_accion = 'gasto' and not (t ? 'obra')));
  perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
  insert into bandeja_memoria as bm (clave, nombre, clase, accion, datos, texto, solo, activa, origen, creada_por, sugerida, privado)
  values (c->>'clave', c->>'nombre', c->>'clase', p_accion, t, v_txt, v_solo, true,
          case when p_origen in ('grupo', 'dimelo') then p_origen else 'tarjeta' end, v_quien, v_sg,
          -- (el nombre de quien manda o recibe sale de un correo: no va a la IA)
          c->>'clase' in ('zelle_a', 'zelle_de', 'deposito')
          and concat_ws(' ', m.descripcion, m.memo) ~ '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}')
  on conflict (clave) do update
     set accion = excluded.accion, datos = excluded.datos, texto = excluded.texto, nombre = excluded.nombre, clase = excluded.clase,
         sugerida = excluded.sugerida, privado = excluded.privado,
         -- (lo que ya entraba solo sigue entrando solo si la acción es la misma; si cambia, hay que volver a decirlo)
         solo = excluded.solo or (bm.solo and bm.accion = excluded.accion and bm.datos = excluded.datos and p_solo is null
                                  and not (excluded.datos ? 'obra')),
         activa = true, origen = excluded.origen, cambiada_por = v_quien, cambiada_el = now()
  returning * into r;
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'clave', r.clave, 'nombre', r.nombre, 'texto', r.texto, 'solo', r.solo,
    'solo_no', case when coalesce(p_solo, false) and not r.solo
                    then case when t ? 'obra' then 'Lo que va a una obra no entra solo: te lo propongo cada vez con la obra del día.'
                              else 'Solo los cargos de un comercio (un gasto general o algo personal) pueden entrar solos.' end end));
end $$;
revoke execute on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) to authenticated;
comment on function public.fn_bandeja_recordar(uuid, text, jsonb, boolean, text) is 'c17: guarda en bandeja_memoria lo que Edgar dijo de la contraparte de ese movimiento (la plantilla de la acción, sin obra fija ni factura); «solo» únicamente para un comercio con un gasto que no lleva obra o con algo personal. Nulo si la contraparte no dice quién, si es un procesador de tarjetas (cobra por muchos clientes) o si la acción no se recuerda.';

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
  if p ? 'solo' and (p->>'solo')::boolean and r.datos ? 'obra' then
    raise exception using errcode = 'MX008',
      message = 'Lo que va a una obra no entra solo: te lo propongo cada vez con la obra del día (qué obra fue no lo sabe una regla, y de esas compras suele llegar el recibo).';
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
--        recordado, propuestas_ia, propuestas_ia_iguales}
--       {hecho: false, por_que, pide_motivo?, freno?, sugerido?, pide_obra?,
--        campos?, cambio?, resuelto?, dicho?, fuera?}
--     (cambio: lo que el banco proponía ya es otra cosa; resuelto: casó solo
--     con lo que ya estaba en el libro; dicho: c10 apuntó de quién es el
--     pago y ahora toca repartirlo; fuera: ya no espera respuesta. En los
--     cuatro la pantalla vuelve a leer la Bandeja en vez de insistir.)
--     y nada queda a medias: lo que la puerta rechaza se deshace entero.
--     p_opciones: {fuente (recomendacion | dimelo | grupo | solo | mas),
--     motivo (lo que Edgar escribió), visto (la huella del freno que vio),
--     recordar, solo, dimelo_id, corrio, tanda}.
--
--     EL FRENO. Las puertas de c6 frenan lo que puede estar dos veces en el
--     libro o va a donde no debe, con un «si de verdad es otra cosa, dilo en
--     el motivo»: para c6, un motivo escrito es «lo leí y aun así». Por eso
--     aquí la puerta se llama SIEMPRE PRIMERO SIN MOTIVO, venga de donde
--     venga la respuesta (la recomendación, la lista, un grupo, lo que
--     entendió la IA). Si la puerta frena, se devuelve lo que dijo, en llano
--     (por_que), con pide_motivo y la HUELLA de ese freno; y un motivo solo lo
--     levanta si llega JUNTO con esa huella (visto): Edgar lo escribió después
--     de leerlo. La frase que Edgar le dijo a la IA NO es un motivo: la
--     escribió antes de saber que había un freno, y no lo contesta. (Antes
--     viajaba como motivo y apagaba todos los frenos: el gasto de un recibo
--     ya subido entraba dos veces, la nómina a un gasto, y una «comisión» del
--     45 % cerraba la factura de un cliente que pagó la mitad.)
--
--     LO QUE c6 SIEMPRE PIDE POR ESCRITO (lo que va al patrimonio del dueño
--     —«es mío», dinero suyo a la empresa— y los otros ingresos) lleva su
--     línea: la que Edgar escribe o, en «es mío», la de esta capa (es SU
--     respuesta, o su regla). Pero una línea escrita apagaría también los
--     demás frenos de la puerta; así que ANTES se ENSAYA la puerta sin motivo
--     con una cuenta de gasto corriente, en una subtransacción que siempre se
--     deshace (fn_bandeja_ensayo): solo si c6 no tiene nada que decir de ese
--     movimiento se registra con la línea. Lo que ENTRA SOLO pasa por lo
--     mismo: nada entra solo si la puerta, hoy, lo frenaría.
--
--     EL FRENO DE ESTA CAPA (tercera vuelta). Lo que la app sabe de un
--     DEPÓSITO —el banco mismo nombra a un prestamista, o c6 reconoce que lo
--     manda el propio Edgar— antes solo lo miraba la recomendación: con una
--     factura por ese mismo monto, «es el cobro de esa factura» (de la
--     lista, de la IA o del botón de c6 que cobra) entraba sin un aviso. Ahora
--     la respuesta que lo trata como dinero de un cliente (cobro, anticipo,
--     otro ingreso, la devolución de una compra, la opción de c6 que cobra)
--     FRENA aquí, en llano y con su huella como los frenos de c6 (la puerta
--     real se ENSAYA para decir de una vez lo que diga también c6): solo
--     entra si Edgar lo lee y escribe por qué. Y cuando la respuesta ES la que
--     dice el banco (un préstamo, dinero suyo) y c6 la frena por si fuera un
--     cobro, el texto no manda a cobrar la factura: dice que el banco mismo
--     lo tiene por un préstamo (o por dinero de Edgar) y pide confirmarlo.
-- ---------------------------------------------------------------------
-- LA PUERTA de una acción ya validada: la de c6 (o la de c10) que le toca,
-- con el motivo que se le dé (o ninguno). Lo que la puerta rechace, lo lanza.
create or replace function public.fn_bandeja_puerta(p_movimiento uuid, p_accion text, p_datos jsonb, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d       jsonb := coalesce(p_datos, '{}'::jsonb);
  m       movimientos_banco;
  x       jsonb;
  v_args  jsonb;
  v_fn    text;
  v_sql   text;
  v_res   jsonb;
  p       text;
begin
  perform fn_bandeja_quien();
  select * into m from movimientos_banco where id = p_movimiento;
  case p_accion
    when 'gasto' then
      return fn_banco_clasificar(m.id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'cuenta', d->>'cuenta', 'proyecto_id', d->>'proyecto_id'))), p_motivo);
    when 'personal' then
      return fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', '3200')), p_motivo);
    when 'cobro' then
      -- cada factura: lo que va a lo que se le debe y, si lo hay, lo que va a su retención
      select jsonb_agg(z.a order by z.n, z.k) into v_args
        from (select t.n, 1 as k,
                     jsonb_build_object('factura_id', (t.a->>'id')::bigint,
                                        'monto', ((t.a->>'monto')::numeric - coalesce((t.a->>'retencion')::numeric, 0))::text) as a
                from jsonb_array_elements(d->'facturas') with ordinality as t(a, n)
               where (t.a->>'monto')::numeric - coalesce((t.a->>'retencion')::numeric, 0) > 0
              union all
              select t.n, 2, jsonb_build_object('factura_id', (t.a->>'id')::bigint, 'monto', t.a->>'retencion', 'es_retencion', true)
                from jsonb_array_elements(d->'facturas') with ordinality as t(a, n)
               where coalesce((t.a->>'retencion')::numeric, 0) > 0) z;
      if d ? 'comision' then
        v_args := v_args || jsonb_build_array(jsonb_build_object('comision', d->>'comision'));
      end if;
      return fn_banco_cobrar(m.id, v_args, p_motivo);
    when 'anticipo' then
      return fn_banco_cobrar(m.id, jsonb_build_array(jsonb_build_object('proyecto_id', d->>'proyecto_id', 'monto', m.monto::text)), p_motivo);
    when 'prestamo', 'aporte', 'otro_ingreso' then
      return fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', d->>'cuenta')), p_motivo);
    when 'traspaso' then
      return fn_banco_transferencia(m.id, d->>'cuenta', p_motivo);
    when 'cuadrilla' then
      execute 'select public.fn_jornal_pago($1)'
        using jsonb_build_object('movimiento_id', m.id, 'usuario_id', d->>'usuario_id') into v_res;
      return v_res;
    when 'contratista' then
      return fn_banco_clasificar(m.id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'cuenta', '5200', 'proyecto_id', d->>'proyecto_id',
               'tercero_tipo', case when d ? 'proveedor_id' then 'proveedor' end, 'tercero_id', d->>'proveedor_id'))), p_motivo);
    when 'banco' then
      -- la opción de c6, TAL CUAL la guardó (la huella ya se comprobó al validar): su puerta y sus argumentos; de fuera solo
      -- entran los datos que ella misma pide (el capital y el interés de una cuota) y el motivo
      x := m.propuesta->'opciones'->((d->>'opcion')::int);
      v_fn := x->>'llamar';
      v_args := coalesce(x->'args', '{}'::jsonb) || jsonb_build_object('p_movimiento', m.id);
      foreach p in array fn_bandeja_opcion_pide(x) loop
        if p not in ('p_motivo', 'p_notas', 'p_partidas.motivo') then
          v_args := v_args || jsonb_build_object(p, btrim(d->'campos'->>p));
        end if;
      end loop;
      if p_motivo is not null then
        if v_fn = 'fn_banco_pagar_proveedor' then
          v_args := v_args || jsonb_build_object('p_partidas', jsonb_build_object(
                      'motivo', p_motivo,
                      'partidas', case when jsonb_typeof(v_args->'p_partidas') = 'array' then v_args->'p_partidas'
                                       else v_args->'p_partidas'->'partidas' end));
        else
          v_args := v_args || jsonb_build_object(case when v_fn = 'fn_banco_cobrar' then 'p_notas' else 'p_motivo' end, p_motivo);
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
        raise exception using errcode = 'MX008', message = 'Esa opción se contesta en «Más opciones».';
      end if;
      execute v_sql using v_args into v_res;
      return v_res;
    else
      raise exception using errcode = '22023', message = 'Esa acción no tiene puerta.';
  end case;
end $$;
revoke execute on function public.fn_bandeja_puerta(uuid, text, jsonb, text) from public, anon, service_role;
grant  execute on function public.fn_bandeja_puerta(uuid, text, jsonb, text) to authenticated;
comment on function public.fn_bandeja_puerta(uuid, text, jsonb, text) is 'c17: llama a la puerta de c6 (o de c10) de una acción ya validada, con el motivo que se le dé (o ninguno). Lo que la puerta rechace, lo lanza. La usa fn_bandeja_hacer; por sí sola no deja rastro.';

-- EL ENSAYO: ¿qué diría la puerta de c6 de este movimiento SIN motivo, si la
-- respuesta fuera un gasto corriente? Se la llama de verdad con una cuenta
-- neutra («Otros gastos») dentro de una subtransacción que SIEMPRE se
-- deshace: nada queda. Nulo = c6 no tiene nada que decir (ni su recibo, ni
-- una factura que lo explique, ni la nómina, ni una partida de antes del
-- corte…); si frena, {codigo, mensaje} con lo que dijo.
create or replace function public.fn_bandeja_ensayo(p_movimiento uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_neutra text;
begin
  perform fn_bandeja_quien();
  select k.codigo into v_neutra
    from cuentas k
   where k.codigo in ('7900', '6500', '6130') and k.imputable and coalesce((to_jsonb(k)->>'activa')::boolean, true)
     and k.tipo in ('gasto', 'otro_gasto') and k.regla_obra is distinct from 'obligatoria'
   order by (k.codigo = '7900') desc, k.codigo
   limit 1;
  if v_neutra is null then
    return jsonb_build_object('codigo', 'MX004', 'mensaje', 'No hay en el plan una cuenta de gasto corriente con la que comprobar este movimiento.');
  end if;
  begin
    perform fn_banco_clasificar(p_movimiento, jsonb_build_array(jsonb_build_object('cuenta', v_neutra)), null);
    raise exception using errcode = 'MXB00', message = 'el ensayo se deshace siempre';
  exception
    when sqlstate 'MXB00' then
      return null;
    when others then
      if sqlstate !~ '^MX' and sqlstate not in ('22023', '22007', '23514') then
        raise;
      end if;
      return jsonb_build_object('codigo', sqlstate, 'mensaje', sqlerrm);
  end;
end $$;
revoke execute on function public.fn_bandeja_ensayo(uuid) from public, anon, service_role;
grant  execute on function public.fn_bandeja_ensayo(uuid) to authenticated;
comment on function public.fn_bandeja_ensayo(uuid) is 'c17: ensaya la puerta de c6 sin motivo con una cuenta de gasto corriente, en una subtransacción que siempre se deshace: nulo si c6 no frenaría ese movimiento; si no, {codigo, mensaje}. Nada queda.';

-- UNA SOLA APP, al cobrar: lo que un cobro del libro deja dicho en
-- Proyectos, para cada factura que ese cobro tocó:
--   · sin saldo en el libro → queda cobrada (pagada, cobrada_el);
--   · con saldo todavía (un pago a cuenta) → queda lo abonado (cobrado);
--   · y «Cobrado» del proyecto (finanzas_proyecto.cobrado, la casilla que
--     Edgar lleva a mano: la app pregunta al marcar una factura) sube lo
--     que haga falta para no quedar por debajo de lo que sus facturas dicen
--     cobrado, y nunca más que lo que este cobro aplicó. (La #1110 no
--     cuenta en lo cobrado de la obra: la regla 5 de Proyectos.)
-- Devuelve lo que cambió, con cómo estaba: [{id, num, que, pagada,
-- cobrada_el, cobrado, proyecto_id, sumado}]. Deshacer lo devuelve.
create or replace function public.fn_bandeja_proyectos(p_cobro uuid, p_fecha date) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r       record;
  v_marc  jsonb := '[]'::jsonb;
  v_que   text;
  v_obj   numeric;
  v_cob   numeric;
  v_sum   numeric;
begin
  perform fn_bandeja_quien();
  for r in select f.id, f.num, f.proyecto_id, f.monto, coalesce(f.pagada, false) as pagada, f.cobrada_el, f.cobrado,
                  coalesce(fc.saldo_libro, 0) as saldo_libro, coalesce(fc.cobrado_libro, 0) as cobrado_libro, x.aplicado
             from (select a.factura_id, sum(a.monto) as aplicado from aplicaciones_cobro a
                    where a.cobro_id = p_cobro and a.factura_id is not null group by a.factura_id) x
             join facturas f on f.id = x.factura_id
             join facturas_cobro fc on fc.id = f.id
            where coalesce(fc.estado, 'emitida') <> 'anulada' and not coalesce(f.pagada, false)
            order by f.id loop
    if r.saldo_libro <= 0 then
      update facturas
         set pagada = true, cobrada_el = coalesce(cobrada_el, (p_fecha + time '12:00') at time zone 'America/New_York')
       where id = r.id;
      v_que := 'cobrada';
    elsif r.cobrado_libro > coalesce(r.cobrado, 0) then
      update facturas set cobrado = r.cobrado_libro where id = r.id;
      v_que := 'abono';
    else
      continue;
    end if;
    v_sum := 0;
    if r.num is distinct from '1110' then
      select fp.cobrado into v_cob from finanzas_proyecto fp where fp.proyecto_id = r.proyecto_id and fp.contrato is not null for update;
      if found then
        select coalesce(sum(case when coalesce(f2.pagada, false) then coalesce(f2.monto, 0) else coalesce(f2.cobrado, 0) end), 0) into v_obj
          from facturas f2
         where f2.proyecto_id = r.proyecto_id and f2.num is distinct from '1110' and coalesce(f2.estado, 'emitida') <> 'anulada';
        v_sum := least(greatest(v_obj - coalesce(v_cob, 0), 0), r.aplicado);
        if v_sum > 0 then
          update finanzas_proyecto set cobrado = round(coalesce(cobrado, 0) + v_sum, 2) where proyecto_id = r.proyecto_id;
        end if;
      end if;
    end if;
    v_marc := v_marc || jsonb_strip_nulls(jsonb_build_object(
                'id', r.id, 'num', r.num, 'que', v_que, 'proyecto_id', r.proyecto_id, 'sumado', nullif(v_sum, 0),
                'antes', jsonb_build_object('pagada', r.pagada, 'cobrada_el', r.cobrada_el, 'cobrado', r.cobrado)));
  end loop;
  return v_marc;
end $$;
revoke execute on function public.fn_bandeja_proyectos(uuid, date) from public, anon, service_role;
grant  execute on function public.fn_bandeja_proyectos(uuid, date) to authenticated;
comment on function public.fn_bandeja_proyectos(uuid, date) is 'c17: lo que un cobro del libro deja dicho en Proyectos: la factura sin saldo queda cobrada, la pagada a cuenta con su abono, y «Cobrado» del proyecto sube lo que haga falta. Devuelve lo que cambió y cómo estaba (para deshacerlo).';

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
  mem      bandeja_memoria;
  v        jsonb;
  d        jsonb;
  c        jsonb;
  x        jsonb;
  pr       jsonb;
  v_res    jsonb;
  v_fr     jsonb;
  v_tok    text;
  v_mot    text;
  v_c6     text;
  v_propio text;
  v_txt    text;
  v_con    boolean := false;
  v_lev    boolean;
  v_libre  boolean;
  v_antes  boolean;
  v_cobra  boolean;
  v_as0    uuid;
  v_hecho  uuid := gen_random_uuid();
  v_marc   jsonb := '[]'::jsonb;
  v_cobro  uuid;
  v_nuevo  boolean := false;
  v_tanda  uuid;
  v_ia     jsonb;
  v_ia_ig  jsonb;
  v_mem    jsonb;
  v_tar    jsonb;
  v_nota   text;
  v_num    text;
  v_fac    text[];
  v_hay    text;
  p        text;
  c_regla  constant text := '^(MX[0-9A-Z]+|22023|22007|23514)$';
  c_expl   constant text := '(propone un cobro o una factura que explica este depósito|Este depósito lo explica)';
begin
  v_quien := fn_bandeja_quien();
  v_fuente := coalesce(nullif(op->>'fuente', ''), 'recomendacion');
  v_motivo := nullif(btrim(regexp_replace(coalesce(op->>'motivo', ''), '\s+', ' ', 'g')), '');
  v_corrio := case when op->>'corrio' = 'rutina' then 'rutina' else 'pantalla' end;
  v_tanda := case when v_fuente = 'grupo' and coalesce(op->>'tanda', '') ~ '^[0-9a-fA-F-]{36}$' then (op->>'tanda')::uuid end;
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
                                                'pide_obra', v->'pide_obra', 'cambio', v->'cambio', 'fuera', v->'fuera'));
  end if;
  d := v->'datos';
  select * into m from movimientos_banco where id = p_movimiento;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  v_antes := m.estado <> 'pendiente';   -- (un cargo ya registrado cuyo recibo llegó después)
  v_as0 := m.asiento_id;
  -- ¿c6 no tenía otra explicación para este movimiento? (lo que guardó la última vez que lo miró)
  v_c6 := coalesce(m.propuesta->>'motivo', 'sin_propuesta');
  v_libre := v_c6 in ('sin_ticket', 'clasificar', 'dudosa', 'sin_propuesta')
             and not (m.posible_duplicado_de is not null and m.duplicado is null);
  -- LO QUE ENTRA SOLO se comprueba aquí otra vez, entero (la rutina ya lo
  -- filtró): un cargo de un comercio con regla «que entre solo», de algo
  -- personal o de un gasto que NO lleva obra, hasta el tope, sin otra
  -- explicación de c6, sin sospecha de duplicado, nunca deshecho, y descrito
  -- por el banco como cuando Edgar puso la regla (fn_bandeja_memoria_vale).
  -- Y no lleva un motivo escrito por nadie: si la puerta, hoy, lo frena, no
  -- entra.
  if v_fuente = 'solo' then
    select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa and bm.solo and bm.accion = p_accion;
    if not (m.monto < 0 and c->>'clase' = 'comercio' and p_accion in ('gasto', 'personal') and v_libre
            and m.posible_duplicado_de is null and not (d ? 'proyecto_id')
            and (p_accion = 'personal' or (select k.regla_obra from cuentas k where k.codigo = d->>'cuenta') is distinct from 'obligatoria')
            and coalesce((select g.solo and abs(m.monto) <= g.solo_tope from bandeja_config g where g.id = 1), false)
            and mem.clave is not null
            and fn_bandeja_memoria_vale(p_accion || '|' || coalesce(d->>'cuenta', ''), mem.sugerida, m.desc_norm)
            and not exists (select 1 from bandeja_hechos h where h.movimiento_id = m.id and h.deshecho_el is not null)) then
      return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'por_que', 'Esto no puede entrar solo: se te pregunta.');
    end if;
    v_motivo := null;
  end if;
  -- lo que una opción de c6 pide además del motivo (el capital y el interés de una cuota)
  if p_accion = 'banco' then
    foreach p in array fn_bandeja_opcion_pide(m.propuesta->'opciones'->((d->>'opcion')::int)) loop
      if p not in ('p_motivo', 'p_notas', 'p_partidas.motivo') and nullif(btrim(coalesce(d->'campos'->>p, '')), '') is null then
        return jsonb_build_object('hecho', false, 'movimiento_id', m.id,
                                  'campos', to_jsonb(fn_bandeja_opcion_pide(m.propuesta->'opciones'->((d->>'opcion')::int))),
                                  'por_que', 'Falta un dato que el banco pide para registrarlo.');
      end if;
    end loop;
  end if;
  -- 0. LO QUE LA APP YA SABE DE ESE DEPÓSITO. Si el banco mismo nombra a un
  --    PRESTAMISTA, o dice que el dinero lo manda EL PROPIO EDGAR, la
  --    respuesta que lo trata como dinero de un cliente (el cobro de una
  --    factura, un anticipo, un ingreso, la devolución de una compra, o la
  --    opción de c6 que cobra) FRENA, venga de donde venga: de la lista, de
  --    lo que entendió la IA o de un botón del banco. Es el freno de ESTA
  --    capa (c6 no lo tiene en su puerta de cobrar), con su huella como los
  --    demás: Edgar lo lee y, si de verdad es eso, escribe por qué.
  if m.monto > 0 and not v_antes then
    v_cobra := p_accion in ('cobro', 'anticipo') or (p_accion = 'banco' and d->>'llamar' = 'fn_banco_cobrar');
    if v_cobra or p_accion in ('otro_ingreso', 'gasto', 'personal') then
      pr := fn_bandeja_prestamista(m.desc_norm);
      v_txt := case when v_cobra then 'el pago de un cliente' when p_accion = 'otro_ingreso' then 'un ingreso del negocio'
                    else 'la devolución de una compra' end;
      if pr is not null then
        v_propio := format('El banco dice que este dinero lo deposita %s, un prestamista%s: es una deuda, no %s.', pr->>'prestamista',
                           case when (pr->>'conocido')::boolean then ' que ya tienes dado de alta' else '' end, v_txt);
      elsif v_c6 = 'aporte_edgar' then
        v_propio := format('El banco dice que este dinero lo mandaste tú: es dinero tuyo a la empresa, no %s.', v_txt);
      end if;
    end if;
  end if;
  -- 1. LA PUERTA, SIN MOTIVO: de verdad; o ENSAYADA (se deshace siempre) si la respuesta es de las que c6 pide siempre por
  --    escrito, o si esta capa ya tiene un freno que enseñar (para leer de una vez lo que diga también c6)
  if p_accion in ('personal', 'aporte', 'otro_ingreso') then
    v_fr := fn_bandeja_ensayo(m.id);
  elsif v_propio is not null then
    begin
      perform fn_bandeja_puerta(m.id, p_accion, d, null);
      raise exception using errcode = 'MXB00', message = 'el ensayo se deshace siempre';
    exception
      when sqlstate 'MXB00' then
        v_fr := null;
      when others then
        if sqlstate !~ c_regla then
          raise;
        end if;
        v_fr := jsonb_build_object('codigo', sqlstate, 'mensaje', sqlerrm);
    end;
  else
    begin
      v_res := fn_bandeja_puerta(m.id, p_accion, d, null);
    exception when others then
      if sqlstate !~ c_regla then
        raise;
      end if;
      v_fr := jsonb_build_object('codigo', sqlstate, 'mensaje', sqlerrm);
    end;
  end if;
  -- 2. EL FRENO: lo que la puerta dijo sin motivo, y lo que esta capa sabe
  if v_fr is not null or v_propio is not null then
    -- (ya estaba en el libro y casa solo —su recibo, su cobro—: se casa de verdad y no hay nada que registrar)
    if v_fr->>'mensaje' ~ '^Este movimiento casa solo' then
      perform fn_banco_casar(m.id);
      select * into m from movimientos_banco where id = p_movimiento;
      if m.estado <> 'pendiente' then
        return jsonb_build_object('hecho', false, 'resuelto', true, 'movimiento_id', m.id, 'estado', m.estado,
                                  'por_que', 'Esto ya estaba en el libro: quedó casado con ello y no hay que registrarlo otra vez.');
      end if;
    end if;
    v_tok := md5(m.id::text || '|' || p_accion || '|' || coalesce(v_propio, '') || '|' || coalesce(v_fr->>'mensaje', ''));
    v_lev := v_fr is null or ((v_fr->>'codigo') in ('MX008', '22023') and (v_fr->>'mensaje') ~* '(dilo en |di por qué|dice por qué)');
    if v_lev and v_motivo is not null and op->>'visto' = v_tok and v_fuente <> 'solo' then
      -- Edgar leyó ESTE freno y escribió su porqué: la puerta, con su motivo
      v_mot := v_motivo;
      v_con := true;
    else
      pr := case when p_accion = 'prestamo' then fn_bandeja_prestamista(m.desc_norm) end;
      -- (la factura que c6 nombra, si nombra una: se dice cuál)
      v_fac := regexp_match(coalesce(v_fr->>'mensaje', ''), 'la factura #(\S+) \([^)]*\), abierta por ([0-9]+(?:\.[0-9]+)?)');
      v_hay := case when v_fac is not null
                    then format('Hay una factura por cobrar (la #%s, por %s), y el banco frena por si este depósito fuera un pago de ella.',
                                v_fac[1], fn_bandeja_usd(v_fac[2]::numeric))
                    else 'Hay facturas por cobrar, y el banco frena por si este depósito fuera el pago de una.' end;
      v_txt := case
        when v_fr is null then v_propio || ' Si de verdad es eso, escribe por qué.'
        when v_propio is not null then v_propio || ' Además: ' || fn_bandeja_freno_llano(v_fr->>'mensaje', v_c6)
        -- (la respuesta ES la que el banco mismo dice —un préstamo, dinero de Edgar— y c6 la frena por si fuera un cobro: el freno
        -- no manda a cobrar la factura)
        when p_accion = 'prestamo' and pr is not null and v_lev and (v_fr->>'mensaje') ~ c_expl
          then v_hay || format(' Pero él mismo dice que lo deposita %s, un prestamista: si es el dinero del préstamo, confírmalo aquí abajo.',
                               pr->>'prestamista')
        when p_accion = 'aporte' and v_c6 = 'aporte_edgar' and v_lev and (v_fr->>'mensaje') ~ c_expl
          then v_hay || ' Pero él mismo dice que lo mandaste tú: si es dinero tuyo a la empresa, confírmalo aquí abajo.'
        else fn_bandeja_freno_llano(v_fr->>'mensaje', v_c6) end;
      return jsonb_strip_nulls(jsonb_build_object(
        'hecho', false, 'movimiento_id', m.id, 'codigo', coalesce(v_fr->>'codigo', 'MX008'),
        'pide_motivo', case when v_lev and v_fuente <> 'solo' then true end,
        'freno', case when v_lev and v_fuente <> 'solo' then v_tok end,
        'por_que', v_txt,
        -- (el banco mismo nombra al prestamista: la respuesta al freno ya está dicha; Edgar la confirma o la cambia)
        'sugerido', case when v_lev and pr is not null
                         then format('Es un préstamo de %s (lo dice el banco), no el pago de un cliente', pr->>'prestamista') end));
    end if;
  elsif p_accion in ('personal', 'aporte', 'otro_ingreso') then
    -- (c6 no tiene nada que decir de este movimiento: la línea que estas respuestas llevan siempre. La de esta capa, solo en «es
    -- mío» y si c6 no tenía otra explicación: un retiro del cajero, por ejemplo, lleva la línea de Edgar)
    v_mot := coalesce(v_motivo,
                      case when p_accion = 'personal' and v_libre and m.monto < 0
                           then format('Gasto personal de Edgar pagado desde la empresa (%s): %s', c->>'nombre',
                                       case when v_fuente = 'solo' then 'regla suya en la Bandeja (entró solo)' else 'lo dijo en la Bandeja' end) end);
    if v_mot is null then
      return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'pide_motivo', true,
               'por_que', case when p_accion = 'aporte'
                                 then 'Escribe en una línea de dónde salió ese dinero tuyo (queda escrito en el libro).'
                               when p_accion = 'otro_ingreso'
                                 then 'Escribe en una línea de qué es ese ingreso (queda escrito en el libro).'
                               when m.monto > 0
                                 then 'Escribe en una línea de qué era lo tuyo que te devolvieron (queda escrito en el libro).'
                               when c->>'clase' = 'cajero'
                                 then 'Es efectivo que salió del cajero. Si fue para ti, escribe en una línea para qué (queda escrito en el libro).'
                               else 'Para este movimiento el banco tenía otra explicación. Si de verdad es tuyo, escribe en una línea de qué '
                                    'fue (queda escrito en el libro).' end);
    end if;
    v_con := true;
  end if;
  if v_con then
    begin
      v_res := fn_bandeja_puerta(m.id, p_accion, d, v_mot);
    exception when others then
      if sqlstate !~ c_regla then
        raise;
      end if;
      return jsonb_build_object('hecho', false, 'movimiento_id', p_movimiento, 'codigo', sqlstate,
                                'por_que', fn_bandeja_freno_llano(sqlerrm, v_c6));
    end;
  end if;
  select * into m from movimientos_banco where id = p_movimiento;
  if m.estado = 'pendiente' then
    -- la puerta no lo registró y lo dice (el pago a la cuadrilla que pide decidir algo)
    return jsonb_strip_nulls(jsonb_build_object(
      'hecho', false, 'movimiento_id', m.id, 'dicho', case when p_accion = 'cuadrilla' then true end,
      'por_que', coalesce(v_res->>'por_que', v_res->>'nota', 'No se registró: sigue en la Bandeja.')));
  end if;
  -- UNA SOLA APP: si quedó casado con un cobro, lo que ese cobro deja dicho
  -- en Proyectos (la factura cobrada, o su abono, y «Cobrado» de la obra).
  -- Si no se puede, el cobro vale igual y se dice.
  if m.casado_clase = 'cobro' and coalesce(m.casado_ref, '') ~ '^[0-9a-fA-F-]{36}$' then
    v_cobro := m.casado_ref::uuid;
    -- (¿el cobro lo creó este registro, o ya estaba anotado y el depósito solo se casó con él? Deshacer anula solo el primero)
    v_nuevo := p_accion in ('cobro', 'anticipo') or (p_accion = 'banco' and d->>'llamar' = 'fn_banco_cobrar');
    begin
      v_marc := fn_bandeja_proyectos(v_cobro, m.fecha);
    exception when others then
      v_marc := '[]'::jsonb;
      v_nota := 'El cobro quedó registrado, pero no pude dejarlo dicho en Proyectos: marca allí la factura como cobrada.';
    end;
    -- la tarifa del procesador que este cobro confirma (o enseña): de facturas ENTERAS; de un pago a cuenta no se aprende nada
    if p_accion = 'cobro' and d ? 'comision' and c->>'clase' = 'procesador' and not coalesce((d->>'a_cuenta')::boolean, false) then
      begin
        v_tar := fn_bandeja_tarifa_aprender(c->>'proc', (select array_agg((a->>'monto')::numeric) from jsonb_array_elements(d->'facturas') a),
                                            (d->>'comision')::numeric);
      exception when others then
        v_tar := null;
      end;
    end if;
  end if;
  select a.numero into v_num from asientos a where a.id = m.asiento_id;
  perform set_config('mx_bandeja.escribe', 'bandeja_hechos', true);
  -- lo que este registro sustituye (el recibo que llegó después): lo anterior de ese movimiento queda deshecho, con su porqué
  update bandeja_hechos
     set deshecho_el = now(), deshecho_por = v_quien, deshecho_motivo = 'Llegó su recibo: lo registrado se cambió por él'
   where movimiento_id = m.id and deshecho_el is null and asiento_id is distinct from m.asiento_id;
  if not (v_antes and m.asiento_id is not distinct from v_as0) then
    insert into bandeja_hechos (id, movimiento_id, accion, datos, texto, fuente, solo, memoria_clave, dimelo_id, monto, asiento_id, corrio, por, tanda)
    values (v_hecho, m.id, p_accion,
            d || jsonb_strip_nulls(jsonb_build_object('marcadas', nullif(v_marc, '[]'::jsonb), 'cobro', v_cobro,
                                                      'cobro_nuevo', case when v_cobro is not null then v_nuevo end,
                                                      'motivo', case when v_con and (v_fr is not null or v_propio is not null) then v_mot end,
                                                      'tarifa', case when v_tar is not null then v_tar - 'veces' - 'origen' end)),
            v->>'texto', v_fuente, v_fuente = 'solo', c->>'clave',
            case when coalesce(op->>'dimelo_id', '') ~ '^[0-9a-fA-F-]{36}$' then (op->>'dimelo_id')::uuid end,
            m.monto, m.asiento_id, v_corrio, v_quien, v_tanda);
  else
    v_hecho := null;
  end if;
  perform set_config('mx_bandeja.escribe', '', true);
  -- lo recordado: se guarda si Edgar lo pidió, y se cuenta si ya estaba
  if coalesce((op->>'recordar')::boolean, false) and not v_antes then
    v_mem := fn_bandeja_recordar(m.id, p_accion, d, case when op ? 'solo' then (op->>'solo')::boolean end, v_fuente);
  end if;
  if c ? 'clave' then
    perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
    update bandeja_memoria set veces = veces + 1, ultima_vez = now() where clave = c->>'clave' and activa and accion = p_accion;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  -- lo de la IA de c8 que este registro deja abierto: lo cierra la pantalla
  -- por la función de borde, o la tarea por la puerta de c8. Y, de ellas, las
  -- que proponían LO MISMO que se acaba de registrar (una sola línea, a esta
  -- cuenta): c8 solo sabe cerrar una pendiente «rechazándola», pero su nota
  -- no tiene por qué decir que Edgar contestó otra cosa
  select jsonb_agg(q.id order by q.creado_el),
         jsonb_agg(q.id order by q.creado_el)
           filter (where d->>'cuenta' is not null and p_accion in ('gasto', 'personal', 'contratista')
                         and case when jsonb_typeof(q.propuesta->'lineas') = 'array' then jsonb_array_length(q.propuesta->'lineas') end = 1
                         and q.propuesta->'lineas'->0->>'cuenta' = d->>'cuenta')
    into v_ia, v_ia_ig
    from contador_propuestas q where q.movimiento_id = m.id and q.estado = 'pendiente';
  return jsonb_strip_nulls(jsonb_build_object(
    'hecho', true, 'hecho_id', v_hecho, 'movimiento_id', m.id, 'estado', m.estado, 'asiento_id', m.asiento_id, 'asiento', v_num,
    'texto', v->>'texto', 'monto', m.monto,
    'facturas_cobradas', (select nullif(jsonb_agg(jsonb_build_object('id', y->'id', 'num', y->'num')), '[]'::jsonb)
                            from jsonb_array_elements(v_marc) y where y->>'que' = 'cobrada'),
    'cobrado_proyectos', (select nullif(sum((y->>'sumado')::numeric), 0) from jsonb_array_elements(v_marc) y),
    'recordado', v_mem, 'propuestas_ia', v_ia, 'propuestas_ia_iguales', v_ia_ig, 'nota', v_nota));
end $$;
revoke execute on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) to authenticated;
comment on function public.fn_bandeja_hacer(uuid, text, jsonb, jsonb) is 'c17: «Así es»: valida una acción de la lista cerrada y la registra por la puerta de c6 (o de c10) que corresponde, SIEMPRE primero sin motivo: si la puerta frena (o esta capa: un depósito que el banco dice de un prestamista o del propio Edgar no entra como dinero de un cliente), devuelve lo que dijo (en llano) y la huella de ese freno, y un motivo solo lo levanta con ella. Devuelve {hecho: true, …} o {hecho: false, por_que, pide_motivo, freno, pide_obra, campos}; nada queda a medias. Deja el rastro en bandeja_hechos y, al cobrar, lo deja dicho en Proyectos.';

-- LO QUE REGISTRÓ LA IA DE ANTES (c8) AL APROBAR SU PROPUESTA desde la
-- tarjeta nueva: el «Así es» de una recomendación que venía de una propuesta
-- pendiente de c8 se registra por SU camino de siempre (la función de borde
-- «contador», acción «aprobar»: ella clasifica, aprende su regla y cuenta el
-- acierto en su marcador). Pero ese camino no deja rastro aquí: la respuesta
-- no salía en «Lo que contestaste estos días», no se podía deshacer desde la
-- Bandeja y no ofrecía «Recordarlo». Esta función ANOTA ese registro: no
-- toca el libro. Comprueba que el movimiento quedó clasificado con el
-- asiento de una propuesta de c8 aprobada (o editada: Edgar cambió la obra)
-- y deja su fila en bandeja_hechos (la acción y los datos, leídos del
-- asiento: una sola línea de gasto, o «es mío»), con lo que Edgar pidió
-- recordar. p_opciones: {recordar, solo}. Devuelve {hecho: true, hecho_id,
-- texto, asiento, recordado} o {hecho: false, por_que}. Llamarla dos veces
-- no anota dos veces.
create or replace function public.fn_bandeja_anotar(p_movimiento uuid, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  op      jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  m       movimientos_banco;
  q       contador_propuestas;
  c       jsonb;
  d       jsonb;
  v_acc   text;
  v_txt   text;
  v_cta   text;
  v_pid   text;
  v_obra  text;
  v_n     int;
  v_id    uuid;
  v_mem   jsonb;
  v_num   text;
begin
  v_quien := fn_bandeja_quien();
  if p_movimiento is null then
    raise exception using errcode = '22023', message = 'Falta el movimiento.';
  end if;
  perform pg_advisory_xact_lock(820261121, hashtext('bandeja:' || p_movimiento::text));
  select * into m from movimientos_banco where id = p_movimiento;
  if not found or m.estado <> 'casado' or m.casado_clase is distinct from 'clasificado' or m.asiento_id is null then
    return jsonb_build_object('hecho', false, 'movimiento_id', p_movimiento, 'por_que', 'Ese movimiento no quedó registrado.');
  end if;
  select * into q from contador_propuestas p
   where p.movimiento_id = m.id and p.asiento_id = m.asiento_id and p.estado in ('aprobada', 'editada')
   order by p.aprobado_el desc nulls last limit 1;
  if not found then
    return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'por_que', 'Eso no lo registró la IA al aprobar su propuesta.');
  end if;
  select h.id into v_id from bandeja_hechos h where h.movimiento_id = m.id and h.asiento_id = m.asiento_id and h.deshecho_el is null limit 1;
  select a.numero into v_num from asientos a where a.id = m.asiento_id;
  -- lo que entró, leído del asiento: las líneas que no son la del banco
  select count(*), min(l.cuenta), min(l.proyecto_id) into v_n, v_cta, v_pid
    from asiento_lineas l where l.asiento_id = m.asiento_id and l.cuenta <> m.cuenta;
  if v_n <> 1 then
    return jsonb_build_object('hecho', false, 'movimiento_id', m.id, 'asiento', v_num,
                              'por_que', 'Quedó registrado repartido entre varias cuentas: se deshace desde Banco → Movimientos.');
  end if;
  v_acc := case when v_cta = '3200' then 'personal' else 'gasto' end;
  v_obra := (select p.nombre from proyectos p where p.id = v_pid);
  d := jsonb_strip_nulls(jsonb_build_object('cuenta', v_cta, 'proyecto_id', v_pid, 'propuesta_ia', q.id));
  v_txt := case when v_acc = 'personal'
                then format('Es tuyo, no de la empresa: %s que salen como retiro tuyo (no es un gasto del negocio).', fn_bandeja_usd(abs(m.monto)))
                else format('Es un gasto de «%s»%s: %s.', fn_bandeja_cuenta_llana(v_cta), coalesce(' de la obra ' || v_obra, ''),
                            fn_bandeja_usd(abs(m.monto))) end;
  c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
  if v_id is null then
    v_id := gen_random_uuid();
    perform set_config('mx_bandeja.escribe', 'bandeja_hechos', true);
    insert into bandeja_hechos (id, movimiento_id, accion, datos, texto, fuente, solo, memoria_clave, monto, asiento_id, corrio, por)
    values (v_id, m.id, v_acc, d, v_txt, 'recomendacion', false, c->>'clave', m.monto, m.asiento_id, 'pantalla', v_quien);
    perform set_config('mx_bandeja.escribe', '', true);
    if coalesce((op->>'recordar')::boolean, false) then
      v_mem := fn_bandeja_recordar(m.id, v_acc, d - 'propuesta_ia' - 'proyecto_id', case when op ? 'solo' then (op->>'solo')::boolean end, 'tarjeta');
    end if;
    if c ? 'clave' then
      perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
      update bandeja_memoria set veces = veces + 1, ultima_vez = now() where clave = c->>'clave' and activa and accion = v_acc;
      perform set_config('mx_bandeja.escribe', '', true);
    end if;
  end if;
  return jsonb_strip_nulls(jsonb_build_object('hecho', true, 'hecho_id', v_id, 'movimiento_id', m.id, 'estado', m.estado,
                                              'asiento_id', m.asiento_id, 'asiento', v_num, 'texto', v_txt, 'monto', m.monto,
                                              'recordado', v_mem));
end $$;
revoke execute on function public.fn_bandeja_anotar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_anotar(uuid, jsonb) to authenticated;
comment on function public.fn_bandeja_anotar(uuid, jsonb) is 'c17: anota en el rastro de la Bandeja (bandeja_hechos) lo que la IA de c8 registró al aprobar su propuesta desde la tarjeta nueva, para que salga en «Lo que contestaste estos días», se pueda deshacer y se recuerde como las demás respuestas. No toca el libro; dos veces no anota dos veces. Solo el dueño, con su sesión.';

-- DESHACER algo que la Bandeja registró (lo que entró solo, o un «Así es»
-- equivocado), con su motivo: se des-casa por la puerta de c6 (su asiento
-- se reversa y el movimiento vuelve a la Bandeja) y lo deshecho NO vuelve a
-- entrar solo. Además:
--   · EL PAGO A LA CUADRILLA que repartió c10 se deshace por la puerta de
--     c10 (fn_jornal_deshacer: su reparto queda deshecho y sus horas libres);
--     des-casarlo a secas dejaba el reparto «aplicado» con su asiento
--     reversado y el control de c10 en rojo.
--   · Si lo registrado creó un COBRO (el pago de una factura, un anticipo,
--     también por una opción de c6), ese cobro se anula por la puerta de c3
--     y la factura vuelve a quedar por cobrar; un cobro que ya estaba
--     anotado y con el que el depósito solo se casó, se queda.
--   · PROYECTOS queda como dice EL LIBRO en ese momento (no como la foto de
--     «antes» de ese registro: con dos pagos a cuenta de una factura,
--     deshacer el primero la dejaba con cero cobrado teniendo el libro el
--     segundo): cada factura que ese cobro tocó, cobrada solo si el libro no
--     le deja saldo, y con lo abonado que el libro diga; y a «Cobrado» de la
--     obra se le resta lo que ese registro le sumó.
--   · LA TARIFA del procesador que ese cobro confirmó pierde esa vez.
--   · «QUE LO SIGUIENTE ENTRE SOLO» de esa contraparte SE APAGA (la regla
--     sigue recordada: se propone): quien deshace una respuesta no quiere
--     que el siguiente cargo de ese comercio entre sin preguntar con la
--     misma respuesta. p_opciones {deja_solo: false} la deja encendida (el
--     cargo de más de un comercio cuya regla está bien).
-- Si el movimiento ya no está como lo dejó este registro (alguien lo
-- des-casó por otro lado), solo se marca. Devuelve {deshecho, estado,
-- cobro_anulado, solo_apagado (el nombre del comercio), ia_caducar (las
-- propuestas de c8 aprobadas cuyo asiento se acaba de reversar: la pantalla
-- las cierra por la función de borde)}.
drop function if exists public.fn_bandeja_deshacer(uuid, text);
create or replace function public.fn_bandeja_deshacer(p_hecho uuid, p_motivo text, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_quien uuid;
  op      jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  h       bandeja_hechos;
  m       movimientos_banco;
  v_res   jsonb;
  x       jsonb;
  v_cobro uuid;
  v_rep   uuid;
  v_anul  boolean := false;
  v_sl    numeric;
  v_cl    numeric;
  v_ia    jsonb;
  v_apag  text;
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
    -- lo de la IA (c8) aprobado con este asiento: al reversarlo queda sin asiento vivo, y lo cierra la pantalla
    select jsonb_agg(q.id order by q.creado_el) into v_ia
      from contador_propuestas q
     where q.movimiento_id = m.id and q.asiento_id = h.asiento_id and q.estado in ('aprobada', 'editada');
    v_cobro := case when m.casado_clase = 'cobro' and coalesce(m.casado_ref, '') ~ '^[0-9a-fA-F-]{36}$' then m.casado_ref::uuid end;
    -- el pago a la cuadrilla que repartió c10: por la puerta de c10 (ella des-casa por c6 y deja su reparto deshecho)
    if to_regclass('public.jornal_repartos') is not null and to_regprocedure('public.fn_jornal_deshacer(uuid,text)') is not null then
      execute 'select r.id from public.jornal_repartos r where r.movimiento_id = $1 and r.asiento_id = $2 and r.estado = ''aplicado'' '
              'order by r.creado_el desc limit 1' into v_rep using m.id, h.asiento_id;
    end if;
    if v_rep is not null then
      execute 'select public.fn_jornal_deshacer($1, $2)' into v_res using v_rep, v_mot;
    else
      v_res := fn_banco_descasar(m.id, v_mot);
    end if;
    -- el cobro que ESTE registro creó: des-casar suelta el depósito pero deja el cobro anotado; se anula (la factura vuelve a
    -- quedar por cobrar) y c6 vuelve a proponer para el depósito
    if v_cobro is not null
       and (h.accion in ('cobro', 'anticipo') or coalesce((h.datos->>'cobro_nuevo')::boolean, false)
            or (h.accion = 'banco' and h.datos->>'llamar' = 'fn_banco_cobrar'))
       and exists (select 1 from cobros k where k.id = v_cobro and k.estado = 'vigente') then
      perform fn_cobro_anular(v_cobro, v_mot);
      perform fn_banco_casar(m.id);
      v_anul := true;
    end if;
    -- Proyectos, como dice EL LIBRO ahora: cada factura que este registro tocó
    for x in select value from jsonb_array_elements(coalesce(h.datos->'marcadas', '[]'::jsonb)) loop
      select coalesce(fc.saldo_libro, 0), coalesce(fc.cobrado_libro, 0) into v_sl, v_cl
        from facturas_cobro fc where fc.id = (x->>'id')::bigint;
      if found and v_sl > 0 then
        update facturas f
           set pagada = false, cobrada_el = null, cobrado = v_cl
         where f.id = (x->>'id')::bigint
           and (coalesce(f.pagada, false) or coalesce(f.cobrado, 0) is distinct from v_cl);
      end if;
      if coalesce((x->>'sumado')::numeric, 0) > 0 then
        update finanzas_proyecto
           set cobrado = round(greatest(coalesce(cobrado, 0) - (x->>'sumado')::numeric, 0), 2)
         where proyecto_id = x->>'proyecto_id';
      end if;
    end loop;
    -- la tarifa del procesador que este cobro confirmó (o enseñó): pierde esa vez
    if h.datos ? 'tarifa' then
      begin
        perform fn_bandeja_tarifa_olvidar(h.datos->'tarifa', false);
      exception when others then
        null;
      end;
    end if;
  end if;
  perform set_config('mx_bandeja.escribe', 'bandeja_hechos', true);
  update bandeja_hechos set deshecho_el = now(), deshecho_por = v_quien, deshecho_motivo = v_mot where id = h.id;
  perform set_config('mx_bandeja.escribe', '', true);
  -- «que lo siguiente entre solo» de esa contraparte se apaga (salvo que Edgar diga que siga)
  if coalesce((op->>'deja_solo')::boolean, true) and h.memoria_clave is not null then
    perform set_config('mx_bandeja.escribe', 'bandeja_memoria', true);
    update bandeja_memoria set solo = false, cambiada_por = v_quien, cambiada_el = now()
     where clave = h.memoria_clave and solo
    returning nombre into v_apag;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  select * into m from movimientos_banco where id = h.movimiento_id;
  return jsonb_strip_nulls(jsonb_build_object('deshecho', true, 'hecho_id', h.id, 'movimiento_id', h.movimiento_id, 'estado', m.estado,
                                              'cobro_anulado', case when v_anul then true end, 'banco', v_res,
                                              'solo_apagado', v_apag, 'ia_caducar', v_ia));
end $$;
revoke execute on function public.fn_bandeja_deshacer(uuid, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_deshacer(uuid, text, jsonb) to authenticated;
comment on function public.fn_bandeja_deshacer(uuid, text, jsonb) is 'c17: deshace, con su motivo, algo que la Bandeja registró: lo des-casa por c6 (el pago a la cuadrilla, por c10), anula el cobro que ese registro creó, deja Proyectos como dice el libro (la factura, su abono y «Cobrado» de la obra), quita la vez de la tarifa que confirmó, apaga «que entre solo» de esa contraparte (salvo deja_solo: false) y lo deja marcado: lo deshecho no vuelve a entrar solo.';

-- DESHACER UNA DECISIÓN DE GRUPO entera («Así es para los 25», con la obra
-- equivocada): todos los registros vivos de esa tanda, con UN motivo. Cada
-- uno pasa por fn_bandeja_deshacer (y «que entre solo» de ese comercio se
-- apaga, salvo deja_solo: false); el que no se pueda (un mes ya cerrado) se
-- queda y se dice. Corta por reloj mucho antes del corte de la API (3 s de
-- fábrica; p_opciones {ms}) y dice «sigue»: se la llama otra vez.
drop function if exists public.fn_bandeja_deshacer_tanda(uuid, text);
create or replace function public.fn_bandeja_deshacer_tanda(p_tanda uuid, p_motivo text, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  op       jsonb := case when jsonb_typeof(p_opciones) = 'object' then p_opciones else '{}'::jsonb end;
  h        record;
  r        jsonb;
  v_n      int := 0;
  v_quedan jsonb := '[]'::jsonb;
  v_ia     jsonb := '[]'::jsonb;
  v_apag   text;
  v_sigue  boolean := false;
  v_fin    timestamptz;
begin
  perform fn_bandeja_quien();
  if p_tanda is null or nullif(btrim(coalesce(p_motivo, '')), '') is null or length(btrim(p_motivo)) < 3 then
    raise exception using errcode = '22023', message = 'Deshacer dice por qué (queda escrito).';
  end if;
  v_fin := clock_timestamp() + make_interval(secs => least(greatest(coalesce(fn_bandeja_num(op->>'ms'), 3000), 50), 6000) / 1000.0);
  for h in select b.id, b.movimiento_id from bandeja_hechos b where b.tanda = p_tanda and b.deshecho_el is null order by b.el, b.id loop
    if v_n > 0 and clock_timestamp() > v_fin then
      v_sigue := true;
      exit;
    end if;
    begin
      r := fn_bandeja_deshacer(h.id, p_motivo, jsonb_build_object('deja_solo', coalesce((op->>'deja_solo')::boolean, true)));
      v_n := v_n + 1;
      v_ia := v_ia || coalesce(r->'ia_caducar', '[]'::jsonb);
      v_apag := coalesce(r->>'solo_apagado', v_apag);
    exception when others then
      if sqlstate !~ '^(MX[0-9A-Z]+|22023|22007|23514)$' then
        raise;
      end if;
      v_quedan := v_quedan || jsonb_build_object('hecho_id', h.id, 'movimiento_id', h.movimiento_id, 'por_que', fn_bandeja_freno_llano(sqlerrm));
    end;
  end loop;
  return jsonb_strip_nulls(jsonb_build_object('tanda', p_tanda, 'deshechos', v_n, 'quedan', v_quedan, 'sigue', case when v_sigue then true end,
                                              'solo_apagado', v_apag, 'ia_caducar', nullif(v_ia, '[]'::jsonb)));
end $$;
revoke execute on function public.fn_bandeja_deshacer_tanda(uuid, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_deshacer_tanda(uuid, text, jsonb) to authenticated;
comment on function public.fn_bandeja_deshacer_tanda(uuid, text, jsonb) is 'c17: deshace entera una decisión de grupo (todos los registros vivos de esa tanda) con un solo motivo; el que no se pueda se queda y se dice; corta por reloj (3 s de fábrica) y dice «sigue».';


-- ---------------------------------------------------------------------
-- 11. LA RECOMENDACIÓN: UNA sola, o ninguna. Por orden, en un DEPÓSITO: lo
--     que ya está en el libro (el otro lado de un traspaso, un cobro que lo
--     nombra); lo que el banco mismo dice que es un préstamo; lo que c6
--     reconoce con certeza (un traspaso, los intereses, dinero del propio
--     Edgar: nunca el cobro de un cliente); lo que Edgar ya dijo de esa
--     contraparte (la memoria: SUS facturas, o una parte de la única que
--     tiene por cobrar; si no cuadra con ninguna, se pregunta: nunca se
--     supone un anticipo); las facturas que explican el depósito, entre
--     TODAS las que tienen saldo (primero las marcadas cobradas en
--     Proyectos); y la única opción que c6 propone (la retención de una
--     factura). En un CARGO: lo que c6 reconoce con certeza (un traspaso,
--     los intereses, la cuota de un préstamo); lo que cobra el procesador
--     de tarjetas; lo que Edgar ya dijo; la propuesta pendiente de la IA de
--     c8; y lo que sugiere la descripción del comercio.
--     Devuelve {accion, datos, texto, porque, fuente (banco | app | memoria
--     | ia | nombre), pide_obra, pide_motivo, pide} o {aviso} (nada que
--     tocar aquí: se contesta en otra parte, en «Más opciones» o diciéndolo)
--     o nulo (no se sabe: «Dímelo»). No escribe nada.
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
  v_suyas jsonb;
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
  v_proc  text;
  v_cli   text;
  v_n     int;
  v_k     int;
  v_cta   text;
  v_tope  numeric;
  v_ia    uuid;
  v_oia   text;
  v_firme boolean := false;
begin
  perform fn_bandeja_exigir_dueno();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found or m.estado <> 'pendiente' then
    return null;
  end if;
  -- (fn_bandeja_leer ya calculó la contraparte de cada movimiento y qué pendientes pueden ser de un prestamista: no se repite)
  c := coalesce(p_ctx->'c', fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque));
  v_mot := coalesce(m.propuesta->>'motivo', 'sin_propuesta');
  ops := case when jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones' else '[]'::jsonb end;
  v_n := jsonb_array_length(ops);
  v_dia := coalesce(m.fecha_transaccion, m.fecha);
  v_proc := case when c->>'clase' = 'procesador' then c->>'proc' end;
  -- Lo que se contesta en otra parte, o en «Más opciones»: se dice en llano.
  if m.posible_duplicado_de is not null and m.duplicado is null then
    return jsonb_build_object('fuente', 'banco',
      'aviso', 'Se parece a otro movimiento que ya está. Dime primero si es el mismo o es otro: está en «Más opciones».');
  end if;
  if v_mot in ('nomina', 'ticket_en_bandeja', 'otro_total', 'quitada', 'devolucion', 'partida_apertura', 'partidas')
     or (v_mot = 'varios_candidatos' and v_n <> 1) then
    return jsonb_build_object('fuente', 'banco', 'aviso', case v_mot
      when 'nomina' then 'Es de la nómina (Gusto): se casa desde Contabilidad → Nómina, no aquí.'
      when 'ticket_en_bandeja' then 'Ya subiste el recibo de esta compra, pero le falta un dato para entrar al libro. Cuando lo termines, este cargo se casa solo con él y con su obra.'
      when 'otro_total' then 'Hay un recibo que se le parece, pero con otro total. Corrige el total del recibo en la app y este cargo se casa solo con él.'
      when 'quitada' then 'El banco quitó este movimiento. Mira qué hacer con él en «Más opciones».'
      when 'devolucion' then 'Parece un cheque o un depósito que el banco devolvió. Dime de cuál es en «Más opciones».'
      when 'varios_candidatos' then 'Coincide con varias cosas que ya están en el libro. Elige cuál en «Más opciones».'
      else 'Puede ser algo que venía de QuickBooks, de antes del 1 de octubre. Míralo en «Más opciones».' end);
  end if;
  select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa;
  pr := case when p_ctx ? 'prest' and not (p_ctx->'prest' ? m.id::text) then null else fn_bandeja_prestamista(m.desc_norm) end;
  if m.monto > 0 then
    if v_mot in ('transferencia_otro_lado', 'cobro_que_lo_nombra', 'otro_lado_clasificado') and v_n >= 1 then
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif pr is not null then
      -- UN PRÉSTAMO NO ES UN COBRO: antes que cualquier factura (si c6 lo tomaba por el pago de una, lo dirá al tocar «Así es»)
      v_acc := 'prestamo'; v_dat := pr - 'conocido' - 'por'; v_fte := 'app';
      v_por := format('El banco dice que lo deposita %s, un prestamista%s.', pr->>'prestamista',
                      case when (pr->>'conocido')::boolean then ' que ya tienes dado de alta' else '' end);
    elsif v_mot in ('transferencia_un_lado', 'abono_tarjeta', 'interes') and v_n >= 1 then
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif v_mot = 'aporte_edgar' then
      -- DINERO DEL PROPIO EDGAR: nunca el cobro de un cliente, aunque una factura tenga ese mismo monto
      v_acc := 'aporte'; v_dat := jsonb_build_object('tipo', 'prestamo_accionista'); v_fte := 'banco';
      v_por := 'El banco dice que este dinero lo mandaste tú: es dinero tuyo a la empresa, no el pago de un cliente.';
    elsif v_mot in ('deposito_cobro', 'deposito_cobros') and v_n >= 1 and ops->0->>'llamar' = 'fn_banco_casar_con' then
      -- UN COBRO QUE YA ESTABA ANOTADO y espera su depósito (por ese monto): es lo que ya está en el libro. Pero si además una
      -- factura por cobrar tiene ese mismo monto, hay dos lecturas (casarlo con el cobro, o cobrar esa otra factura: el dinero
      -- quedaría dos veces): no se recomienda ninguna
      v_fact := coalesce(p_ctx->'facturas', fn_bandeja_facturas());
      cb := fn_bandeja_cobro_de(v_fact, m.monto, m.fecha, v_proc);
      if cb is not null then
        return jsonb_build_object('fuente', 'banco',
          'aviso', 'Este depósito puede ser el de un cobro que ya estaba anotado por ese monto, o el pago de otra factura por cobrar '
                   'con ese mismo monto. Elige cuál en «Más opciones», o dímelo abajo: si se registran los dos, el dinero queda dos veces.');
      end if;
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif mem.clave is not null then
      v_fte := 'memoria'; v_por := 'Ya me lo dijiste antes: ' || mem.texto || '.';
      if mem.accion = 'cobro' then
        v_fact := coalesce(p_ctx->'facturas', fn_bandeja_facturas());
        -- SUS facturas: las de la obra recordada y las de las demás obras de ese mismo cliente
        v_cli := (select nullif(lower(btrim(p.cliente)), '') from proyectos p where p.id = mem.datos->>'proyecto_id');
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_suyas
          from jsonb_array_elements(v_fact) x
         where x->>'proyecto_id' = mem.datos->>'proyecto_id' or (v_cli is not null and lower(btrim(x->>'cliente')) = v_cli);
        cb := fn_bandeja_cobro_de(v_suyas, m.monto, m.fecha, v_proc);
        if coalesce(cb, '{}'::jsonb) ? 'facturas' then
          v_acc := 'cobro'; v_dat := jsonb_strip_nulls(jsonb_build_object('facturas', cb->'facturas', 'comision', cb->'comision'));
        else
          -- UN PAGO A CUENTA: no cuadra con una factura entera. Si de las suyas hay UNA sola por cobrar, y por más que el
          -- depósito, es una parte de ella
          select count(*), min(x->>'id') filter (where (x->>'saldo')::numeric > m.monto) into v_k, v_cta
            from jsonb_array_elements(v_suyas) x where (x->>'saldo')::numeric > 0 and (x->>'fecha')::date <= m.fecha;
          if v_k = 1 and v_cta is not null then
            v_acc := 'cobro'; v_dat := jsonb_build_object('facturas', jsonb_build_array(jsonb_build_object('id', v_cta::bigint, 'monto', m.monto)));
            v_por := v_por || ' No cuadra con una factura entera: va como una parte de la única que tiene por cobrar.';
          else
            -- ni entera ni a cuenta de las SUYAS. Si cuadra justo con la factura de OTRO cliente se propone esa, diciéndolo (no con
            -- la razón de lo recordado: antes salía «Ya me lo dijiste: paga la obra X» delante de la factura de otra obra); si
            -- no, se pregunta: un «anticipo» supuesto dejaría la factura entera por cobrar
            cb := fn_bandeja_cobro_de(v_fact, m.monto, m.fecha, v_proc);
            if coalesce(cb, '{}'::jsonb) ? 'facturas' and not (cb ? 'comision') then
              v_acc := 'cobro'; v_fte := 'app';
              v_dat := jsonb_build_object('facturas', cb->'facturas');
              v_por := format('Me dijiste que %s, pero este depósito no cuadra con ninguna factura suya: cuadra justo con %s, que es de '
                              'otra obra. Míralo bien antes de tocar.', mem.texto,
                              case when jsonb_array_length(cb->'facturas') = 1 then 'esta factura' else 'estas facturas' end);
            else
              return jsonb_build_object('fuente', 'memoria',
                'aviso', format('Ya me dijiste esto: %s. Pero este depósito no cuadra con ninguna factura suya por cobrar. Dime abajo qué es: '
                                'el pago de una factura, una parte de ella o un anticipo.', mem.texto));
            end if;
          end if;
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
                 || case when cb ? 'comision'
                           then format(', menos la comisión de la tarjeta (el %s %%%s de cada factura).', cb->'tarifa'->>'pct',
                                       case when coalesce((cb->'tarifa'->>'fijo')::numeric, 0) > 0
                                            then ' más ' || fn_bandeja_usd((cb->'tarifa'->>'fijo')::numeric) else '' end)
                         else '.' end;
      elsif v_n = 1 and v_mot in ('deposito_cobro', 'deposito_otro_cobro', 'deposito_sin_cobro', 'reembolso_proveedor', 'varios_candidatos') then
        -- (la única opción de c6: el cobro que ya estaba anotado, la retención de una factura, el reembolso de un proveedor)
        v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
      end if;
    end if;
  else
    if (v_mot in ('transferencia_otro_lado', 'transferencia_un_lado', 'abono_tarjeta', 'interes_tarjeta', 'cargo_banco', 'cuota_prestamo',
                  'cobro_que_lo_nombra', 'otro_lado_clasificado') and v_n >= 1)
       or (v_mot in ('pago_proveedor', 'deuda_propia', 'varios_candidatos') and v_n = 1) then
      v_acc := 'banco'; v_dat := jsonb_build_object('opcion', 0); v_fte := 'banco';
    elsif coalesce((c->>'comision')::boolean, false) and abs(m.monto) <= 500 then
      -- LO QUE COBRA EL PROCESADOR por los pagos con tarjeta (antes que lo recordado: no es la suscripción de QuickBooks)
      v_acc := 'gasto'; v_dat := jsonb_build_object('cuenta', '6130'); v_fte := 'app';
      v_por := 'Es lo que cobra el procesador de tarjetas por los pagos de tus clientes.';
    elsif mem.clave is not null
          -- (lo recordado vale para lo que el banco describe como entonces: el permiso y la luz de una misma ciudad no son lo mismo)
          and fn_bandeja_memoria_vale(mem.accion || '|' || coalesce(mem.datos->>'cuenta', case when mem.accion = 'personal' then '3200' else '' end),
                                      mem.sugerida, m.desc_norm) then
      v_acc := mem.accion; v_dat := mem.datos - 'obra'; v_fte := 'memoria';
      v_por := 'Ya me lo dijiste antes: ' || mem.texto || '.';
      if mem.solo then
        select g.solo_tope into v_tope from bandeja_config g where g.id = 1 and g.solo;
        v_por := v_por || case when v_tope is not null and abs(m.monto) > v_tope
                                 then format(' No entró solo porque pasa de %s.', fn_bandeja_usd(v_tope))
                               when exists (select 1 from bandeja_hechos h where h.movimiento_id = m.id and h.deshecho_el is not null)
                                 then ' No entró solo porque ya lo deshiciste una vez.'
                               else '' end;
      end if;
    elsif pr is not null then
      return jsonb_strip_nulls(jsonb_build_object('fuente', 'app',
        'sin_alta', case when not coalesce((pr->>'conocido')::boolean, false) then pr->>'prestamista' end,
        'aviso', case when (pr->>'conocido')::boolean
                      then format('Parece un pago a %s, un préstamo que ya tienes dado de alta, pero el banco lo escribe distinto de como quedó '
                                  'apuntado: por eso no se reparte solo entre lo que baja la deuda y los intereses. Dímelo abajo, o míralo '
                                  'en «Más opciones».', pr->>'prestamista')
                      else format('Parece la cuota de un préstamo de %s que todavía no está dado de alta en Contabilidad. Hasta que se dé de '
                                  'alta (una vez, con su contrato) no se puede repartir entre capital e intereses.', pr->>'prestamista') end));
    else
      select p.id, p.propuesta, p.fuente into q
        from contador_propuestas p
       where p.movimiento_id = m.id and p.estado = 'pendiente'
       order by p.creado_el desc limit 1;
      if found and jsonb_typeof(q.propuesta->'lineas') = 'array' and jsonb_array_length(q.propuesta->'lineas') = 1 then
        -- LA PROPUESTA PENDIENTE DE LA IA DE ANTES (c8), dicha como las demás: «es tuyo» si va a tu retiro, o el gasto de su
        -- categoría (con la obra que traía, si era firme). El porqué es fijo: el motivo libre de c8 trae códigos de cuenta y jerga.
        -- Se aprueba por SU camino (la función de borde: ella la registra, aprende su regla y cuenta el acierto) y la Bandeja
        -- anota el registro (fn_bandeja_anotar): por eso lleva propuesta_ia
        v_cta := q.propuesta->'lineas'->0->>'cuenta';
        v_ia := q.id; v_fte := 'ia';
        if v_cta = '3200' then
          v_acc := 'personal';
        else
          v_acc := 'gasto';
          -- (la obra de la propuesta se preselecciona SOLO si es firme —flags.obra_fuerte, lo mismo que mira la tarjeta de c8— y
          -- sigue en marcha. Una floja, o una que ya se cerró, SE PIDE: sin la obra de Edgar, la puerta de c8 registraría la
          -- que trae la línea, que no es la que esta tarjeta enseña)
          v_oia := nullif(q.propuesta->'lineas'->0->>'proyecto_id', '');
          v_firme := v_oia is not null and coalesce((q.propuesta->'flags'->>'obra_fuerte')::boolean, false)
                     and (select k.regla_obra from cuentas k where k.codigo = v_cta) in ('obligatoria', 'opcional')
                     and exists (select 1 from proyectos pj where pj.id = v_oia and pj.estado in ('aprobado', 'ejecucion', 'pausa'));
          v_dat := jsonb_strip_nulls(jsonb_build_object('cuenta', v_cta, 'proyecto_id', case when v_firme then v_oia end));
        end if;
        v_por := case q.fuente when 'regla' then 'Por una regla que la app ya aprendió de ti.'
                               when 'edgar' then 'Ya lo habías dicho tú.'
                               else 'Lo propone la IA, por el comercio y por lo que ya contestaste otras veces.' end
                 || case when v_dat ? 'proyecto_id' then ' La obra la propone ella: mírala.' else '' end;
      elsif found and jsonb_typeof(q.propuesta->'lineas') = 'array' and jsonb_array_length(q.propuesta->'lineas') > 1 then
        return jsonb_build_object('fuente', 'ia',
          'aviso', format('La IA propone repartirlo entre %s. Míralo en «Más opciones» (ahí está su «Así es»), o dímelo abajo.',
                          (select string_agg('«' || fn_bandeja_cuenta_llana(l->>'cuenta') || '»', ' y ' order by n)
                             from jsonb_array_elements(q.propuesta->'lineas') with ordinality as t(l, n))));
      else
        -- lo que sugiere la descripción ENTERA del banco (no el nombre ya recortado)
        sg := fn_bandeja_sugerida(m.desc_norm);
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
    if v_ia is not null then
      -- (la IA de antes propuso algo que la tarjeta nueva no sabe decir: una cuenta que no es de gasto)
      return jsonb_build_object('fuente', 'ia', 'aviso', 'La IA tiene una propuesta para este cargo: mírala en «Más opciones» (ahí está su «Así es»), o dímelo abajo.');
    end if;
    return null;   -- lo recordado ya no vale (la cuenta, la persona o el préstamo cambiaron): se pregunta
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'accion', v_acc, 'datos', case when (v->>'ok')::boolean then v->'datos' else v_dat end, 'texto', v->>'texto',
    'porque', nullif(concat_ws(' ', v_por, case when ob is not null then 'La obra: ' || (ob->>'por') || '.' end), ''),
    -- (la obra floja de una propuesta de c8, sin otra que poner en su lugar: hay que elegirla)
    'fuente', v_fte, 'pide_obra', case when v_oia is not null and not v_firme and not (v_dat ? 'proyecto_id') then to_jsonb(true)
                                       else v->'pide_obra' end,
    'propuesta_ia', v_ia,
    'pide_motivo', case when v_acc in ('aporte', 'otro_ingreso') or (v_acc = 'personal' and m.monto > 0)
                             or (v_acc = 'banco' and v->'datos'->'pide' ?| array['p_motivo', 'p_notas', 'p_partidas.motivo']) then true end,
    'pide', case when v_acc = 'banco' then (select nullif(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements_text(coalesce(v->'datos'->'pide', '[]'::jsonb)) e
                                             where e not in ('p_motivo', 'p_notas', 'p_partidas.motivo')) end));
end $$;
revoke execute on function public.fn_bandeja_recomendar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_recomendar(uuid, jsonb) to authenticated;
comment on function public.fn_bandeja_recomendar(uuid, jsonb) is 'c17: LA recomendación de un movimiento pendiente (una o ninguna): {accion de la lista cerrada, datos, texto llano, porque, fuente (banco, app, memoria, ia, nombre), pide_obra, pide_motivo, pide, propuesta_ia (la propuesta pendiente de c8 de la que sale: se aprueba por su camino)}, o {aviso}, o nulo. Un depósito de un prestamista se propone como préstamo antes de mirar facturas; dinero del propio Edgar, nunca como el cobro de un cliente; un cobro ya anotado que espera su depósito, antes que cualquier factura; un pagador recordado sin factura que cuadre, se pregunta; lo recordado de un comercio no vale si la descripción de ahora sugiere otra cosa. No escribe nada.';


-- ---------------------------------------------------------------------
-- 12. DECIDIR POR GRUPO y LO QUE ENTRA SOLO.
-- ---------------------------------------------------------------------
-- UNA DECISIÓN PARA TODOS los CARGOS pendientes de una contraparte (p_clave:
-- «C:HOME DEPOT», «Z>:ZZ JUAN») o para el lote de un motivo de c6 (p_clave
-- «M:…», y solo estos cuatro: los intereses de la tarjeta, los cargos del
-- banco, los intereses que paga el banco y las cuotas de un préstamo: se
-- acepta la primera opción de c6 de cada uno). LOS DEPÓSITOS NO SE DECIDEN
-- POR GRUPO (MX008): cada depósito de un cliente o de un procesador de
-- tarjetas paga SUS facturas, y una respuesta para todos («un anticipo de
-- la obra X») registraba de un toque seis depósitos de Intuit en una sola
-- obra. Cada movimiento pasa por fn_bandeja_hacer con sus guardas (la
-- puerta, sin motivo): el que algo frena se queda en la Bandeja y se dice
-- por qué. p_opciones: {recordar (de fábrica sí), solo (que lo siguiente
-- entre solo), movimientos: [los que la pantalla enseñó: solo esos], tanda
-- (la de una llamada anterior que cortó por reloj), ms (el reloj: 3 s de
-- fábrica, muy por debajo del corte de la API)}. Sin obra en los datos,
-- cada gasto de obra va a la del día de la cuadrilla (Edgar lo eligió así
-- para el grupo); el que no tenga una sola, se queda. Devuelve {clave,
-- tanda, hechos, monto, quedan: [{movimiento_id, por_que}], recordado,
-- propuestas_ia, propuestas_ia_iguales (de esas, las que proponían lo mismo
-- que se registró), sigue (cortó por reloj: llámala otra vez, con su tanda)}.
-- Lo ya mirado en una llamada anterior de la misma tanda (registrado, o
-- frenado) no se vuelve a mirar: la pantalla quita de «movimientos» los que
-- ya le contestaron.
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
  v_fin    timestamptz;
  v_tanda  uuid := case when coalesce(op->>'tanda', '') ~ '^[0-9a-fA-F-]{36}$' then (op->>'tanda')::uuid else gen_random_uuid() end;
  m        movimientos_banco;
  c        jsonb;
  d        jsonb;
  r        jsonb;
  ob       jsonb;
  v_hechos jsonb := '[]'::jsonb;
  v_quedan jsonb := '[]'::jsonb;
  v_ia     jsonb := '[]'::jsonb;
  v_ia_ig  jsonb := '[]'::jsonb;
  v_mem    jsonb;
  v_monto  numeric := 0;
  v_sigue  boolean := false;
  v_ultimo uuid;
  v_obra   boolean := false;
  v_k      int := 0;
begin
  v_quien := fn_bandeja_quien();
  if coalesce(p_clave, '') !~ '^(C|D|P|M|Z[<>]):.+' then
    raise exception using errcode = '22023', message = 'Falta el grupo.';
  end if;
  if v_lote then
    if substring(p_clave from 3) not in ('interes_tarjeta', 'cargo_banco', 'interes', 'cuota_prestamo') then
      raise exception using errcode = '22023',
        message = 'De una vez solo se aceptan los intereses de la tarjeta, los cargos del banco, los intereses que paga el banco y las cuotas de un préstamo.';
    end if;
  else
    if p_clave ~ '^(D|P|Z<):' then
      raise exception using errcode = 'MX008',
        message = 'Los depósitos se contestan de uno en uno: cada uno paga sus propias facturas (o es otra cosa), y una respuesta para todos los registraría mal.';
    end if;
    if p_accion is null or p_accion not in ('gasto', 'personal', 'traspaso', 'cuadrilla', 'contratista') then
      raise exception using errcode = '22023', message = 'Falta decir qué son los cargos de ese grupo.';
    end if;
    v_obra := p_accion = 'contratista'
              or (p_accion = 'gasto' and (select k.regla_obra from cuentas k where k.codigo = d0->>'cuenta') = 'obligatoria');
  end if;
  v_fin := clock_timestamp() + make_interval(secs => least(greatest(coalesce(fn_bandeja_num(op->>'ms'), 3000), 50), 6000) / 1000.0);
  for m in select mb.* from movimientos_banco mb
            where mb.estado = 'pendiente'
              -- (la pantalla manda los que enseñó: lo que llegó después, o lo que tiene su propia tarjeta, no entra en esta respuesta)
              and (jsonb_typeof(op->'movimientos') is distinct from 'array' or op->'movimientos' ? mb.id::text)
            order by mb.fecha, mb.id loop
    if v_lote then
      continue when coalesce(m.propuesta->>'motivo', '') <> substring(p_clave from 3)
                 or jsonb_typeof(m.propuesta->'opciones') is distinct from 'array' or jsonb_array_length(m.propuesta->'opciones') < 1;
    else
      c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
      continue when c->>'clave' is distinct from p_clave;
    end if;
    -- (el reloj: siempre al menos uno por llamada; los que falten, en la siguiente, con «sigue»)
    if v_k > 0 and clock_timestamp() > v_fin then
      v_sigue := true;
      exit;
    end if;
    v_k := v_k + 1;
    v_ultimo := m.id;
    if m.posible_duplicado_de is not null and m.duplicado is null then
      v_quedan := v_quedan || jsonb_build_object('movimiento_id', m.id, 'por_que', 'Se parece a otro movimiento: dime primero si es el mismo.');
      continue;
    end if;
    if v_lote then
      r := fn_bandeja_hacer(m.id, 'banco', jsonb_build_object('opcion', 0), jsonb_build_object('fuente', 'grupo', 'tanda', v_tanda));
    else
      -- (lo que c6 reconoce de otra forma —su recibo, un traspaso, la nómina— no es de este grupo: tiene su propia tarjeta)
      if coalesce(m.propuesta->>'motivo', 'sin_propuesta') not in ('sin_ticket', 'clasificar', 'dudosa', 'sin_propuesta') then
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
      r := fn_bandeja_hacer(m.id, p_accion, d, jsonb_build_object('fuente', 'grupo', 'tanda', v_tanda));
    end if;
    if coalesce((r->>'hecho')::boolean, false) then
      v_hechos := v_hechos || jsonb_build_object('movimiento_id', m.id, 'hecho_id', r->>'hecho_id', 'monto', m.monto, 'texto', r->>'texto');
      v_monto := v_monto + m.monto;
      v_ia := v_ia || coalesce(r->'propuestas_ia', '[]'::jsonb);
      v_ia_ig := v_ia_ig || coalesce(r->'propuestas_ia_iguales', '[]'::jsonb);
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
    'clave', p_clave, 'tanda', v_tanda, 'hechos', jsonb_array_length(v_hechos), 'monto', v_monto, 'registrados', v_hechos, 'quedan', v_quedan,
    'recordado', v_mem, 'propuestas_ia', nullif(v_ia, '[]'::jsonb), 'propuestas_ia_iguales', nullif(v_ia_ig, '[]'::jsonb),
    'sigue', case when v_sigue then true end));
end $$;
revoke execute on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) to authenticated;
comment on function public.fn_bandeja_grupo(text, text, jsonb, jsonb) is 'c17: una decisión para todos los CARGOS pendientes de una contraparte (o el lote de uno de cuatro motivos de c6, «M:…»): cada uno pasa por fn_bandeja_hacer con sus guardas; el que algo frena se queda y se dice por qué. Los depósitos no se deciden por grupo (MX008). Guarda lo dicho en la memoria y deja su tanda (para deshacerla entera). Corta por reloj (3 s de fábrica) y dice «sigue».';

-- EL RECIBO QUE LLEGA DESPUÉS. Edgar (o una regla suya) registró un cargo
-- desde la Bandeja y, días después, la cuadrilla sube el recibo de esa
-- compra: el recibo entra al libro por su puente y el gasto queda DOS veces
-- (c6 lo dice: «llegó su ticket», y su control se pone rojo). Aquí, por cada
-- cargo que la Bandeja registró y que tiene un recibo libre por ese mismo
-- monto en su cuenta, se le pide a c6 que lo mire (fn_banco_casar: él decide
-- si puede ser su recibo, con su ventana de fechas) y queda con la propuesta
-- de c6 a la vista: fn_bandeja_leer lo da en «recibos» y la pantalla lo
-- enseña ARRIBA con sus dos respuestas, de un toque: «Es su recibo:
-- cámbialo» / «Es otra compra».
-- NADA SE CAMBIA SOLO (tercera vuelta). Antes, si c6 proponía un solo
-- recibo, lo registrado se cambiaba por él sin un toque. Pero que sea «su»
-- recibo c6 lo decide por el monto, la cuenta y la fecha (hasta tres días
-- DESPUÉS del cargo), sin mirar el comercio, y el cargo de verdad de un
-- recibo recién subido tarda días en llegar al banco: el «es mío» de un
-- cargo de 50.00 se perdía dos días después por el recibo de OTRA compra de
-- 50.00 (y esa compra entraba luego otra vez): un gasto dos veces y el
-- retiro perdido, sin un toque, con «entra solo» apagado y con los controles
-- en verde. Y NO SE PODÍA DESHACER: para c6, un cargo pendiente con un
-- recibo libre de su monto y su tarjeta ES el de ese recibo (su puerta no
-- deja clasificarlo, con motivo o sin él), así que lo cambiado no tenía
-- vuelta a «como Edgar lo dijo». «Es otra compra» solo existe mientras el
-- cargo sigue registrado como él lo dejó: por eso la pregunta se hace ANTES
-- de tocar nada, y lo que Edgar contestó no lo cambia nadie más que él.
-- Y LO QUE YA NO ESPERA: si el recibo casó después con SU cargo de verdad
-- (llegó al banco y c6 lo casó, o el recibo se anuló), el cargo de antes
-- seguía diciendo «llegó su recibo» hasta el siguiente «Casar» de su cuenta:
-- salía arriba con un «Es su recibo» que ya no podía ser. Ahora esos se le
-- dan a c6 otra vez, que quita la marca.
-- p: {ms (el reloj: 1.5 s de fábrica)}. Devuelve {esperan (cuántos tienen su
-- recibo esperando la respuesta de Edgar)}. La llama fn_bandeja_solo (al
-- abrir la Bandeja y en la tarea de la base); corre aunque lo de «entra
-- solo» esté apagado: no registra nada, solo pide a c6 que mire.
create or replace function public.fn_bandeja_recibos(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r      record;
  m      movimientos_banco;
  v_esp  int := 0;
  v_k    int := 0;
  v_fin  timestamptz;
begin
  perform fn_bandeja_quien();
  v_fin := clock_timestamp() + make_interval(secs => least(greatest(coalesce(fn_bandeja_num(p->>'ms'), 1500), 50), 20000) / 1000.0);
  for r in
    select distinct mb.id, x.libre
      from bandeja_hechos h
      join movimientos_banco mb on mb.id = h.movimiento_id
     -- (barato: una línea libre de un recibo por ese monto en su cuenta, de esos días; si puede ser SU recibo lo decide c6)
     cross join lateral (select exists (select 1 from asiento_lineas l join asientos a on a.id = l.asiento_id
                                         where l.cuenta = mb.cuenta and l.monto = mb.monto and a.origen_tabla = 'recibos'
                                           and a.fecha_contable between mb.fecha - 70 and mb.fecha + 35
                                           and a.camino not in ('reverso', 'reverso_automatico')
                                           and not exists (select 1 from asientos z where z.reversa_a = a.id)
                                           and not exists (select 1 from banco_casado_lineas bl
                                                            where bl.asiento_id = l.asiento_id and bl.orden = l.orden and bl.vigente)) as libre) x
     where h.deshecho_el is null and h.accion in ('gasto', 'personal', 'contratista')
       and mb.estado = 'casado' and mb.casado_clase = 'clasificado' and mb.asiento_id is not distinct from h.asiento_id
       and mb.monto < 0 and mb.fecha >= fn_fecha_miami(now()) - 120
       -- (o el que ya decía «llegó su recibo» y ya no tiene ninguno libre: su recibo casó con otro cargo, o se anuló)
       and (x.libre or mb.propuesta->>'motivo' = 'llego_su_ticket')
     order by mb.id loop
    exit when v_k > 0 and clock_timestamp() > v_fin;
    v_k := v_k + 1;
    select * into m from movimientos_banco where id = r.id;
    -- (c6 ya lo tiene mirado y a la vista: no se le pide otra vez… salvo que el recibo que esperaba ya no esté libre: entonces c6 lo
    -- mira de nuevo y quita la marca, o la deja si el suyo es un recibo de otro total o repartido)
    if m.propuesta->>'motivo' is distinct from 'llego_su_ticket' or not r.libre then
      begin
        perform fn_banco_casar(r.id);
      exception when others then
        continue;   -- c6 no lo pudo mirar ahora: lo dirá su control, y la próxima pasada lo vuelve a intentar
      end;
      select * into m from movimientos_banco where id = r.id;
    end if;
    if m.estado = 'casado' and m.propuesta->>'motivo' = 'llego_su_ticket' then
      v_esp := v_esp + 1;
    end if;
  end loop;
  return jsonb_build_object('esperan', v_esp);
end $$;
revoke execute on function public.fn_bandeja_recibos(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_recibos(jsonb) to authenticated;
comment on function public.fn_bandeja_recibos(jsonb) is 'c17: el recibo que llega después de registrar su cargo en la Bandeja: le pide a c6 que lo mire, para que salga arriba con «Es su recibo» / «Es otra compra». No cambia nada sola (lo que Edgar contestó solo lo cambia él, de un toque): devuelve {esperan}.';

-- LA RUTINA QUE REGISTRA SOLA. Primero, los recibos que llegaron después
-- (fn_bandeja_recibos: se miran siempre, para que salgan arriba con sus dos
-- botones; ninguno se cambia solo). Después entra solo, y solo, lo que
-- cumple TODO esto:
--   · bandeja_config.solo está encendido;
--   · es un CARGO (dinero que sale) de un COMERCIO (no un Zelle, un cheque,
--     el cajero, la nómina, un traspaso ni un prestamista);
--   · ese comercio tiene una regla ACTIVA con «que entre solo» (la puso
--     Edgar), de algo personal o de un gasto que NO LLEVA OBRA (gasolina,
--     software, teléfono…). Un costo de obra nunca entra solo: a qué obra
--     fue no lo sabe una regla (la cuadrilla en una sola obra ese día es una
--     pista para PROPONERLA, no para darla por hecha), y de esas compras
--     suele llegar el recibo, que es quien dice la obra;
--   · el banco lo describe como cuando Edgar puso la regla: si la
--     descripción de ahora sugiere otra cosa (el permiso de una ciudad cuya
--     regla es de la luz), no entra: se propone por la descripción;
--   · no pasa del tope (bandeja_config.solo_tope);
--   · c6 no tiene nada mejor que decir de él (su motivo es «sin ticket») y
--     no lo señaló como posible duplicado;
--   · nadie lo deshizo antes;
--   · y la puerta de c6, HOY, no lo frena: se la llama sin motivo (o se la
--     ensaya, si es algo personal), y ella misma rehace lo que sabía si
--     estaba viejo. Su recibo ya subido, uno de otro total, un mes cerrado,
--     algo que puede estar ya en el libro: no entra.
-- Lo comprueba otra vez fn_bandeja_hacer con la fuente «solo». p: {ms (el
-- reloj de toda la llamada: 3 s de fábrica, muy por debajo del corte de la
-- API; la tarea de la base, sin ese corte, pide 20 s), corrio (pantalla |
-- rutina)}. Devuelve {encendido, registrados: [...], esperan (siempre 0: ya
-- nada espera a una obra), no (la puerta no los aceptó), completo (false:
-- cortó por reloj; se la llama otra vez), propuestas_ia, recibos:
-- {esperan}}.
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
  r       jsonb;
  v_rec   jsonb;
  v_reg   jsonb := '[]'::jsonb;
  v_ia    jsonb := '[]'::jsonb;
  v_no    int := 0;
  v_k     int := 0;
  v_comp  boolean := true;
  v_ms    numeric;
  v_fin   timestamptz;
begin
  v_quien := fn_bandeja_quien();
  -- (el reloj: «segundos» es el nombre de antes; «ms» manda)
  v_ms := least(greatest(coalesce(fn_bandeja_num(p->>'ms'), fn_bandeja_num(p->>'segundos') * 1000, 3000), 100), 25000);
  v_fin := clock_timestamp() + make_interval(secs => v_ms / 1000.0);
  begin
    v_rec := fn_bandeja_recibos(jsonb_build_object('ms', round(v_ms / 2)));
  exception when others then
    v_rec := jsonb_build_object('esperan', 0, 'error', left(sqlerrm, 300));
  end;
  select * into cfg from bandeja_config where id = 1;
  if not coalesce(cfg.solo, false) or not exists (select 1 from bandeja_memoria bm where bm.activa and bm.solo) then
    return jsonb_build_object('encendido', coalesce(cfg.solo, false), 'registrados', '[]'::jsonb, 'esperan', 0, 'no', 0, 'completo', true,
                              'recibos', v_rec);
  end if;
  for m in select mb.* from movimientos_banco mb
            where mb.estado = 'pendiente' and mb.monto < 0 and abs(mb.monto) <= cfg.solo_tope
              and coalesce(mb.propuesta->>'motivo', '') in ('sin_ticket', 'dudosa')
              and mb.posible_duplicado_de is null
              and not exists (select 1 from bandeja_hechos h where h.movimiento_id = mb.id and h.deshecho_el is not null)
            order by mb.fecha, mb.id loop
    c := fn_bandeja_contraparte(m.desc_norm, m.memo, m.monto, m.tipo_banco, m.cheque);
    continue when c->>'clase' <> 'comercio' or not (c ? 'clave');
    select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa and bm.solo and bm.accion in ('gasto', 'personal');
    continue when not found;
    -- (lo que va a una obra no entra solo: se propone)
    continue when mem.datos ? 'obra'
               or (mem.accion = 'gasto' and (select k.regla_obra from cuentas k where k.codigo = mem.datos->>'cuenta') = 'obligatoria');
    -- (ni lo que el banco describe distinto de cuando se puso la regla: el permiso de una ciudad cuya regla es de la luz)
    continue when not fn_bandeja_memoria_vale(mem.accion || '|' || coalesce(mem.datos->>'cuenta', case when mem.accion = 'personal' then '3200' else '' end),
                                              mem.sugerida, m.desc_norm);
    if v_k > 0 and clock_timestamp() > v_fin then
      v_comp := false;
      exit;
    end if;
    v_k := v_k + 1;
    r := fn_bandeja_hacer(m.id, mem.accion, mem.datos - 'obra', jsonb_build_object('fuente', 'solo', 'corrio', coalesce(p->>'corrio', 'pantalla')));
    if coalesce((r->>'hecho')::boolean, false) then
      v_reg := v_reg || jsonb_build_object('hecho_id', r->>'hecho_id', 'movimiento_id', m.id, 'fecha', m.fecha, 'monto', m.monto,
                                           'descripcion', m.descripcion, 'texto', r->>'texto');
      v_ia := v_ia || coalesce(r->'propuestas_ia', '[]'::jsonb);
    else
      v_no := v_no + 1;
    end if;
  end loop;
  return jsonb_strip_nulls(jsonb_build_object('encendido', true, 'registrados', v_reg, 'esperan', 0, 'no', v_no, 'completo', v_comp,
                                              'propuestas_ia', nullif(v_ia, '[]'::jsonb), 'recibos', v_rec));
end $$;
revoke execute on function public.fn_bandeja_solo(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_solo(jsonb) to authenticated;
comment on function public.fn_bandeja_solo(jsonb) is 'c17: LA RUTINA QUE REGISTRA SOLA (una regla de Edgar, no la IA): primero mira si llegó el recibo de algún cargo que ya estaba registrado (no cambia ninguno: esperan arriba la respuesta de Edgar); después, los cargos de un comercio con regla «que entre solo» de algo personal o de un gasto que no lleva obra, descritos por el banco como cuando se puso la regla, hasta el tope, que c6 da por «sin ticket», sin sospecha de duplicado, nunca deshechos, y que la puerta de c6 hoy no frena. Nunca un depósito, un Zelle, un cheque, el cajero, la nómina, un traspaso ni un costo de obra. Corta por reloj (3 s de fábrica).';

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
    v_res := fn_bandeja_solo(jsonb_build_object('ms', 20000, 'corrio', 'rutina'));
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
    'recibos', nullif(coalesce((v_res->'recibos'->>'esperan')::int, 0), 0),
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
-- LA MÁSCARA de lo que escribe Edgar (y de lo que escribió el banco) antes
-- de ir a la IA y de guardarse: la de c8 (fn_contador_sin_datos: correos,
-- teléfonos de diez dígitos, números de ocho o más) y, además, lo que una
-- caja de texto LIBRE puede traer y c8 no tapa:
--   · lo que va DETRÁS de la palabra que dice lo que es (cuenta, cta, acct,
--     account, routing, aba, iban, tarjeta, card, ssn, itin, ein, tin,
--     seguro social, licencia, pasaporte): aunque sea corto o lleve guiones
--     («la cuenta 1234-5678-90», «ACCT 123456»). Con cinco cifras o más: «va
--     a la cuenta 5100» es una cuenta del plan, no la del banco;
--   · una tarjeta escrita en grupos (4-4-4-4, o 4-6-5), con espacio, guion
--     o punto (o en renglones: un salto de línea vale como un espacio);
--   · un SSN o un ITIN (3-2-4) con guion, espacio o punto, aunque vaya
--     pegado a su etiqueta («SSN123-45-6789»); un EIN (2-7) con guion o
--     espacio;
--   · un teléfono de siete dígitos con guion o punto (555-0142), o con un
--     espacio o todo seguido si va detrás de «tel», «cel» o «llama»
--     («tel 5550142»). Un espacio suelto no:
--     «la factura 103 2640.80» son un número de factura y su monto, y
--     tapados la IA perdía los dos;
--   · y antes de nada, los guiones que no son el del teclado (pegados de un
--     correo o de un PDF: ‑ – —) se leen como «-».
-- No tapa el número de una tienda (#6341), una fecha (11/05, 2026-11-05),
-- un monto ($1,234.56), el número de un cheque (1043), un código postal
-- (33130-1234) ni los cuatro últimos de una tarjeta. La de c8 no se toca
-- (la ráfaga sigue igual): esta la envuelve, solo para el «Dímelo».
create or replace function public.fn_bandeja_sin_datos(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v text := p;
begin
  if v is null then
    return null;
  end if;
  -- (un hash o un uuid enteros no son un dato de nadie: los deja la máscara de c8, y aquí tampoco se tocan)
  if (v ~* '^([0-9a-f]{32}|[0-9a-f]{40}|[0-9a-f]{64})$' and v ~* '[a-f]')
     or v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return fn_contador_sin_datos(v);
  end if;
  v := translate(v, U&'\2010\2011\2012\2013\2014\2015\2212', '-------');
  v := regexp_replace(v, '(\m(?:cuenta|cta|acct|account|routing|aba|iban|tarjeta|card|ssn|itin|ein|tin|seguro social|social security|licencia|license|pasaporte|passport)\M(?:\s+(?:n[uú]mero|num|no|n[º°]))?[\s#:.]*)([A-Z]{0,2}[0-9][0-9 .-]{3,}[0-9])\M', '\1[número]', 'gi');
  v := regexp_replace(v, '\m[0-9]{4}([\s.-][0-9]{4}){3}\M', '[número]', 'g');
  v := regexp_replace(v, '\m[0-9]{4}[\s.-][0-9]{6}[\s.-][0-9]{5}\M', '[número]', 'g');
  v := regexp_replace(v, '(^|[^0-9])[0-9]{3}[-.\s][0-9]{2}[-.\s][0-9]{4}(?![0-9])', '\1[número]', 'g');
  v := regexp_replace(v, '\m[0-9]{2}[-\s][0-9]{7}\M', '[número]', 'g');
  v := fn_contador_sin_datos(v);
  v := regexp_replace(v, '(\m(?:tel|tel[eé]fono|cel|celular|m[oó]vil|phone|llama|ll[aá]mame|llamar)\M[\s#:.]*(?:al\s+)?)[0-9]{3} ?[0-9]{4}\M(?![.,][0-9])', '\1[teléfono]', 'gi');
  return regexp_replace(v, '\m[0-9]{3}[.-][0-9]{4}\M(?![.,][0-9])', '[teléfono]', 'g');
end $$;
revoke execute on function public.fn_bandeja_sin_datos(text) from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_sin_datos(text) is 'c17: la máscara del «Dímelo»: la de c8 (correos, teléfonos, números largos) y además lo que va detrás de la palabra que dice lo que es (cuenta, tarjeta, ssn…), una tarjeta en grupos, un SSN o ITIN, un EIN y un teléfono de siete dígitos. Solo desde la función de borde.';

create or replace function public.fn_bandeja_sin_datos_jsonb(p jsonb) returns jsonb
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  if p is null then
    return null;
  end if;
  if jsonb_typeof(p) = 'object' then
    -- (el sello, la huella de una opción y los identificadores de la base —el de una obra es su nombre corto con cuatro letras:
    -- «casa-742-1234» no es un teléfono— van enteros por su nombre: son llaves, y tapadas la IA devolvería una que no existe)
    select coalesce(jsonb_object_agg(e.key, case when e.key in ('prompt_version', 'prefijo_hash', 'reglas_version', 'huella')
                                                      or (e.key ~ '(^|_)id$' and jsonb_typeof(e.value) in ('string', 'number', 'null'))
                                                 then e.value
                                                 else fn_bandeja_sin_datos_jsonb(e.value) end), '{}'::jsonb)
      into v
      from jsonb_each(p) e;
    return v;
  elsif jsonb_typeof(p) = 'array' then
    select coalesce(jsonb_agg(fn_bandeja_sin_datos_jsonb(x.v) order by x.n), '[]'::jsonb) into v
      from jsonb_array_elements(p) with ordinality as x(v, n);
    return v;
  elsif jsonb_typeof(p) = 'string' then
    return to_jsonb(fn_bandeja_sin_datos(p #>> '{}'));
  end if;
  return p;
end $$;
revoke execute on function public.fn_bandeja_sin_datos_jsonb(jsonb) from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_sin_datos_jsonb(jsonb) is 'c17: fn_bandeja_sin_datos en todo un árbol JSON (cada texto, tapado; el sello de la trazabilidad, la huella de una opción y los identificadores de la base, enteros). Solo desde la función de borde.';

-- EL CONTEXTO que se le da a la IA para UN movimiento y UNA frase de Edgar.
-- {config: {modelo, effort}, tope, fijo: {…}, ya_enseno, movimiento: {…},
-- facturas_por_cobrar, facturas_no_enviadas, facturas_fuera_del_libro,
-- parecidos_ya_resueltos, frase}. «fijo» es lo que NO cambia de un
-- movimiento a otro (va en el prefijo de las instrucciones y se cachea): las
-- categorías con su cuenta, las cuentas, las obras, las cuentas propias y
-- las tarjetas, los préstamos, la cuadrilla y los proveedores. «ya_enseno»
-- (lo que Edgar ya dijo de cada contraparte) NO va en lo fijo: lleva el
-- nombre que escribió el banco (un texto de fuera: es un DATO, va en el
-- mensaje) y cambia cada vez que se recuerda algo (en el prefijo, rompía el
-- caché justo en el uso normal). LAS FACTURAS POR COBRAR son las 40 que le
-- SIRVEN a este movimiento, no las 40 más recientes (la factura vieja de una
-- obra terminada, que es la que nadie sabe casar, quedaba fuera): primero la
-- que Edgar nombra en su frase (su número, su obra o su cliente), las de
-- saldo igual al depósito (o que lo superan en una comisión creíble si lo
-- deposita un procesador), las marcadas cobradas en Proyectos esos días y
-- las de la obra o el cliente que esa contraparte tiene recordado; después,
-- las más cercanas en fecha. «facturas_no_enviadas» dice cuántas quedaron
-- fuera. TODO sale tapado por la máscara (fn_bandeja_sin_datos: la de c8 y
-- más), también la frase. Con el tope del mes gastado, {bloqueado, motivo}:
-- ni un token.
create or replace function public.fn_bandeja_dimelo_contexto(p_movimiento uuid, p_dueno uuid, p_frase text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg8     contador_config;
  cfg      bandeja_config;
  m        movimientos_banco;
  mem      bandeja_memoria;
  c        jsonb;
  c_ia     jsonb;
  pr       jsonb;
  v_c6     text;
  v_frase  text := nullif(btrim(regexp_replace(coalesce(p_frase, ''), '\s+', ' ', 'g')), '');
  v_fl     text;
  v_tope   jsonb;
  v_fijo   jsonb;
  v_mov    jsonb;
  v_fact   jsonb;
  v_env    jsonb;
  v_cli    text;
  c_max    constant int := 40;
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
  -- (el NOMBRE de la contraparte que se le da a la IA sale de la descripción YA TAPADA: el de un Zelle es a veces un correo, que
  -- c6 deja normalizado —«JPEREZ OBRAS EJEMPLO COM»— y la máscara de texto ya no reconoce)
  c_ia := fn_bandeja_contraparte(fn_contador_sin_datos_norm(m.desc_norm, m.descripcion, m.memo), m.memo, m.monto, m.tipo_banco, m.cheque);
  -- (lo que la app ya sabe de ese dinero: lo deposita un prestamista, o lo manda el propio Edgar)
  pr := case when m.monto > 0 then fn_bandeja_prestamista(m.desc_norm) end;
  v_c6 := coalesce(m.propuesta->>'motivo', 'sin_propuesta');
  select * into mem from bandeja_memoria bm where bm.clave = c->>'clave' and bm.activa;
  v_fact := fn_bandeja_facturas();
  v_fl := lower(v_frase);
  v_cli := (select nullif(lower(btrim(p.cliente)), '') from proyectos p where p.id = mem.datos->>'proyecto_id');
  -- LAS FACTURAS QUE LE SIRVEN A ESTE MOVIMIENTO (un depósito), por orden de lo que pueden explicarlo
  select coalesce(jsonb_agg(z.f - 'monto' order by z.orden, z.dias, z.n) filter (where z.pos <= c_max), '[]'::jsonb) into v_env
    from (select y.*, row_number() over (order by y.orden, y.dias, y.n) as pos
            from (select t.f, t.n,
                         abs((t.f->>'fecha')::date - m.fecha) as dias,
                         case when length(coalesce(t.f->>'num', '')) >= 3 and position(lower(t.f->>'num') in v_fl) > 0 then 0
                              when length(coalesce(t.f->>'obra', '')) >= 4 and position(lower(t.f->>'obra') in v_fl) > 0 then 0
                              when length(coalesce(t.f->>'cliente', '')) >= 4 and position(lower(t.f->>'cliente') in v_fl) > 0 then 0
                              when (t.f->>'saldo')::numeric = m.monto or coalesce((t.f->>'retencion')::numeric, 0) = m.monto then 1
                              when c->>'clase' = 'procesador' and (t.f->>'saldo')::numeric > m.monto
                                   and (t.f->>'saldo')::numeric - m.monto <= round(0.035 * (t.f->>'saldo')::numeric + 0.30, 2) then 1
                              when mem.accion = 'cobro' and (t.f->>'proyecto_id' = mem.datos->>'proyecto_id'
                                                             or (v_cli is not null and lower(btrim(t.f->>'cliente')) = v_cli)) then 2
                              when coalesce((t.f->>'marcada')::boolean, false)
                                   and (t.f->>'cobrada_el' is null or (t.f->>'cobrada_el')::date between m.fecha - 12 and m.fecha + 3) then 3
                              else 5 end as orden
                    from jsonb_array_elements(v_fact) with ordinality as t(f, n)
                   where m.monto > 0) y) z;
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
                                from (select pv.id, pv.nombre from proveedores pv where coalesce(pv.activo, true) order by pv.creado_el desc limit 60) x) end);
  v_mov := jsonb_strip_nulls(jsonb_build_object(
    'fecha', m.fecha, 'monto', m.monto, 'es', case when m.monto < 0 then 'dinero que salió' else 'dinero que entró' end,
    'descripcion', m.descripcion, 'memo', m.memo,
    'cuenta', m.cuenta, 'cuenta_nombre', (select k.nombre from cuentas k where k.codigo = m.cuenta), 'tipo_banco', m.tipo_banco,
    'contraparte', jsonb_build_object('clase', c->>'clase', 'nombre', c_ia->>'nombre'),
    'obra_del_dia', fn_bandeja_obra_del_dia(coalesce(m.fecha_transaccion, m.fecha)) - 'por',
    'prestamista', pr - 'cuenta' - 'por',
    'lo_manda_edgar', case when m.monto > 0 and v_c6 = 'aporte_edgar' then true end,
    -- (de un prestamista, lo que c6 dice del depósito —«estas facturas abiertas lo explican»— no se le pasa a la IA: empujaría a cobrarlo)
    'lo_que_dice_el_banco', case when pr is not null
                                 then format('Lo deposita %s, un prestamista: es dinero de un préstamo (una deuda de la empresa), no el pago de '
                                             'un cliente.', pr->>'prestamista')
                                 else left(fn_bandeja_llano(m.propuesta->>'texto'), 500) end,
    'opciones_del_banco', (select nullif(jsonb_agg(jsonb_build_object('opcion', (n - 1)::int, 'texto', fn_bandeja_opcion_texto(o, m.monto, m.id),
                                                                      'huella', fn_bandeja_opcion_huella(o)) order by n), '[]'::jsonb)
                             from jsonb_array_elements(case when jsonb_typeof(m.propuesta->'opciones') = 'array' then m.propuesta->'opciones'
                                                            else '[]'::jsonb end) with ordinality as t(o, n)
                            where o->>'llamar' = any (fn_bandeja_puertas())
                              -- (un depósito de un prestamista, o del propio Edgar: las opciones de c6 que lo cobran como el pago
                              -- de un cliente no se le ofrecen a la IA. Si lo es de verdad, lo dirá Edgar, y la base frena)
                              and not ((pr is not null or v_c6 = 'aporte_edgar') and o->>'llamar' = 'fn_banco_cobrar'))));
  return fn_bandeja_sin_datos_jsonb(jsonb_build_object(
    'bloqueado', false,
    'config', jsonb_build_object('modelo', cfg8.modelo, 'effort', cfg.dimelo_effort),
    'tope', v_tope,
    'fijo', v_fijo,
    'ya_enseno', (select coalesce(jsonb_agg(x.t order by x.t), '[]'::jsonb)
                    -- (sin el nombre que sale de un correo: lo demás de lo recordado —qué es, de qué obra— sí va)
                    from (select case when bm.privado then replace(bm.texto, bm.nombre, '[correo]') else bm.texto end as t
                            from bandeja_memoria bm where bm.activa order by bm.ultima_vez desc nulls last limit 60) x),
    'movimiento', v_mov,
    'facturas_por_cobrar', v_env,
    'facturas_no_enviadas', case when m.monto > 0 then greatest(jsonb_array_length(v_fact) - jsonb_array_length(v_env), 0) else 0 end,
    'facturas_fuera_del_libro', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                          'num', fc.num, 'obra', p.nombre, 'cliente', p.cliente, 'fecha', fc.fecha, 'monto', fc.monto,
                                          'marcada_cobrada', coalesce(fc.pagada, false))) order by fc.fecha desc), '[]'::jsonb)
                                   from (select * from facturas_cobro z
                                          where coalesce(z.estado, 'emitida') <> 'anulada' and coalesce(z.saldo_libro, 0) = 0
                                            and coalesce(z.cobrado_libro, 0) = 0 and z.fecha > m.fecha - 200 and m.monto > 0
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
comment on function public.fn_bandeja_dimelo_contexto(uuid, uuid, text) is 'c17: lo que la función de borde le da a la IA para «Dímelo con tus palabras»: lo fijo (categorías, cuentas, obras, cuentas propias, préstamos, cuadrilla, proveedores), lo ya enseñado, el movimiento, las 40 facturas por cobrar que le sirven a ese movimiento (y cuántas quedaron fuera), las de fuera del libro, lo parecido ya resuelto y la frase; todo tapado por la máscara. Con el tope gastado, {bloqueado}. Solo desde la función de borde (fn_contador_exigir).';

-- GUARDAR lo que contestó la IA: se anota su gasto (acción
-- «contador_dimelo», donde lo anota c8: cuenta contra el mismo tope), la
-- propuesta anterior de ese movimiento caduca, y la respuesta se VALIDA
-- (fn_bandeja_validar) antes de guardarse como propuesta «pendiente». Lo
-- que no vale, o un «falta», queda «sin_propuesta» con su porqué. Nada se
-- registra en el libro aquí. p_respuesta: {accion, cuenta, proyecto_id,
-- facturas: [{id, monto}], comision, prestamo_id, prestamista, tipo,
-- cuenta_destino, usuario_id, proveedor_id, opcion, recordar, explicacion,
-- falta}. p_usage: {input, output, cache_creacion, cache_lectura}.
-- (Dos «Dímelo» a la vez del mismo movimiento —dos pestañas— van uno detrás
-- de otro: el candado del movimiento. Si validar la respuesta lanza, el
-- gasto ya anotado no se pierde: queda «sin propuesta». Y «recordar» se lee
-- sin convertirlo: algo que no sea true, es que no.)
create or replace function public.fn_bandeja_dimelo_guardar(p_movimiento uuid, p_dueno uuid, p_frase text, p_grupo boolean, p_entrada jsonb,
                                                            p_salida jsonb, p_respuesta jsonb, p_modelo text, p_effort text,
                                                            p_prompt_version text, p_usage jsonb, p_error text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r        jsonb := case when jsonb_typeof(p_respuesta) = 'object' then p_respuesta else null end;
  v_frase  text := fn_bandeja_sin_datos(nullif(btrim(regexp_replace(coalesce(p_frase, ''), '\s+', ' ', 'g')), ''));
  v_cent   int;
  v_k      char;
  v_acc    text;
  v_dat    jsonb;
  v        jsonb;
  v_falta  text;
  v_est    text := 'sin_propuesta';
  v_id     uuid := gen_random_uuid();
  v_s      jsonb;
  v_rec    boolean := false;
  v_de_ia  boolean := false;
  v_exp    text;
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
  perform pg_advisory_xact_lock(820261121, hashtext('bandeja:' || p_movimiento::text));
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
    -- (el porqué técnico queda en «uso»; a Edgar, en llano)
    -- (primero el plazo: su mensaje también dice que la llamada «se cortó», y a Edgar se le decía «dímelo más corto»)
    v_falta := case when coalesce(p_error, '') ~* '(tiempo|plazo|no contestó|tard[oó])' then 'La IA tardó demasiado en contestar. Prueba otra vez, o elige en «Más opciones».'
                    when coalesce(p_error, '') ~* 'cort' then 'La IA se quedó a medias pensándolo. Dímelo más corto, o elige tú en «Más opciones».'
                    else 'La IA no pudo contestar esta vez. Prueba otra vez, o elige en «Más opciones».' end;
  else
    v_acc := r->>'accion';
    -- (el texto libre de la IA llega a la tarjeta marcado como suyo, tapado, corto y SIN ENLACES: una orden metida en la nota de
    -- un Zelle —«entra a esta dirección y escribe tu código»— que la IA repita no sale con la voz de la app ni con un enlace)
    v_exp := nullif(left(btrim(regexp_replace(regexp_replace(fn_bandeja_sin_datos(coalesce(r->>'explicacion', '')),
                                                             '(https?://|www\.)\S+', '[enlace]', 'gi'), '\s+', ' ', 'g')), 300), '');
    if v_acc is null or not (v_acc = any (c_lista)) then
      v_falta := coalesce(nullif(left(btrim(regexp_replace(regexp_replace(fn_bandeja_sin_datos(coalesce(r->>'falta', '')),
                                                                          '(https?://|www\.)\S+', '[enlace]', 'gi'), '\s+', ' ', 'g')), 200), ''),
                          'No encontré a qué corresponde con lo que la app sabe. Dime algo más: la obra, el cliente o de qué fue.');
      -- (de_la_ia: ese «falta» lo escribió la IA, no la base: la tarjeta lo dice)
      v_de_ia := nullif(btrim(coalesce(r->>'falta', '')), '') is not null;
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
        -- (la opción, con la huella de la que se le ENSEÑÓ a la IA: si c6 la cambió mientras pensaba, no vale)
        when 'banco' then jsonb_build_object('opcion', r->>'opcion',
                            'huella', coalesce((select o->>'huella'
                                                  from jsonb_array_elements(case when jsonb_typeof(p_entrada->'movimiento'->'opciones_del_banco') = 'array'
                                                                                 then p_entrada->'movimiento'->'opciones_del_banco' else '[]'::jsonb end) o
                                                 where o->>'opcion' = r->>'opcion' limit 1), 'no estaba entre las que se le dieron'))
        else '{}'::jsonb end);
      begin
        -- (la validación lee como el dueño: en su nombre, solo dentro de esta transacción)
        v_s := fn_contador_suplantar();
        v := fn_bandeja_validar(p_movimiento, v_acc, v_dat);
        perform fn_contador_soltar(v_s);
      exception when others then
        v := jsonb_build_object('ok', false, 'falta', 'No pude comprobar lo que entendió la IA. Prueba otra vez, o elige en «Más opciones».');
      end;
      if coalesce((v->>'ok')::boolean, false) or coalesce((v->>'pide_obra')::boolean, false) then
        v_est := 'pendiente';
        v_dat := v->'datos';
        v_falta := case when not (v->>'ok')::boolean then v->>'falta' end;
        -- (lo que la IA cree que vale «para siempre» solo deja MARCADA la casilla: recordar lo decide Edgar al aprobar)
        v_rec := coalesce(r->>'recordar', '') = 'true';
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
          fn_bandeja_sin_datos_jsonb(p_entrada), p_salida,
          case when v_est = 'pendiente' then v_acc end, case when v_est = 'pendiente' then v_dat end,
          case when v_est = 'pendiente' then v->>'texto' end, v_exp, v_falta, v_rec, v_est, coalesce(v_cent, 0),
          -- (falta_de_la_ia se guarda aquí: la tarjeta lo sigue diciendo —«La IA dice»— cuando la Bandeja se lee otra vez)
          coalesce(p_usage, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('error', left(p_error, 300),
                                                                                 'falta_de_la_ia', case when v_de_ia then true end)), p_dueno);
  perform set_config('mx_bandeja.escribe', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'dimelo_id', v_id, 'movimiento_id', p_movimiento, 'estado', v_est, 'accion', case when v_est = 'pendiente' then v_acc end,
    'datos', case when v_est = 'pendiente' then v_dat end, 'texto', case when v_est = 'pendiente' then v->>'texto' end,
    'porque', v_exp, 'falta', v_falta, 'falta_de_la_ia', case when v_de_ia then true end,
    'pide_obra', case when v_est = 'pendiente' then v->'pide_obra' end,
    -- (lo que el banco pide para esa opción y no es el motivo: el capital y el interés de una cuota; se mandan al aprobar)
    'pide', case when v_est = 'pendiente' and v_acc = 'banco'
                 then (select nullif(jsonb_agg(e), '[]'::jsonb)
                         from jsonb_array_elements_text(coalesce(v->'datos'->'pide', '[]'::jsonb)) e
                        where e not in ('p_motivo', 'p_notas', 'p_partidas.motivo')) end,
    'pide_motivo', case when v_est = 'pendiente' and v_acc in ('aporte', 'otro_ingreso') then false end,
    'recordar', v_rec, 'centavos', coalesce(v_cent, 0), 'tope', fn_contador_tope()));
end $$;
revoke execute on function public.fn_bandeja_dimelo_guardar(uuid, uuid, text, boolean, jsonb, jsonb, jsonb, text, text, text, jsonb, text)
  from public, anon, authenticated, service_role;
comment on function public.fn_bandeja_dimelo_guardar(uuid, uuid, text, boolean, jsonb, jsonb, jsonb, text, text, text, jsonb, text) is 'c17: guarda lo que la IA contestó a un «Dímelo»: anota su gasto (acción contador_dimelo), caduca la propuesta anterior de ese movimiento y valida la respuesta contra la lista cerrada y la base; lo que vale queda «pendiente» (lo aprueba el dueño con fn_bandeja_aprobar), lo demás «sin_propuesta» con su porqué. No registra nada en el libro. Solo desde la función de borde.';

-- «ASÍ ES» de una propuesta del «Dímelo»: la registra fn_bandeja_hacer con
-- la acción YA VALIDADA que se guardó (nunca con algo que venga de fuera; si
-- era una opción de c6, la que la IA vio: su huella), y SIN MOTIVO: la frase
-- que Edgar le escribió a la IA no levanta ningún freno de la puerta (ver
-- «EL FRENO», arriba). Solo es su línea escrita donde la respuesta misma la
-- pide (dinero suyo a la empresa, otro ingreso), y después del ensayo. Si la
-- puerta frena, vuelve lo que dijo y su huella: Edgar escribe el porqué
-- después de leerlo y vuelve a tocar (p_opciones: {motivo, visto}).
-- p_opciones: {proyecto_id (la obra que faltaba), motivo y visto, campos (lo
-- que el banco pide para esa opción: el capital y el interés de una cuota),
-- recordar (solo si Edgar marcó la casilla: lo que la IA proponga recordar
-- no se recuerda solo), solo}. Devuelve lo de fn_bandeja_hacer; con hecho:
-- false la propuesta sigue pendiente (salvo que lo que el banco proponía
-- haya cambiado: caduca).
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
  v_mot   text;
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
  v_mot := coalesce(nullif(btrim(coalesce(op->>'motivo', '')), ''),
                    case when q.accion in ('aporte', 'otro_ingreso')
                              or (q.accion = 'personal' and (select mb.monto from movimientos_banco mb where mb.id = q.movimiento_id) > 0)
                         then 'Edgar dijo: «' || q.frase || '»' end);
  r := fn_bandeja_hacer(q.movimiento_id, q.accion, d, jsonb_strip_nulls(jsonb_build_object(
         'fuente', 'dimelo', 'dimelo_id', q.id, 'motivo', v_mot, 'visto', op->>'visto',
         'recordar', coalesce((op->>'recordar')::boolean, false), 'solo', op->'solo')));
  -- (el banco frenó y deja seguir con un porqué: la caja sale con lo que Edgar YA le dijo a la IA, para que no lo escriba dos
  -- veces. No levanta nada sola: él lee el freno con su frase debajo y, si aun así es eso, vuelve a tocar, con la huella)
  if not coalesce((r->>'hecho')::boolean, false) and coalesce((r->>'pide_motivo')::boolean, false) and r ? 'freno'
     and not (r ? 'sugerido') and nullif(btrim(q.frase), '') is not null then
    r := r || jsonb_build_object('sugerido', left(q.frase, 300));
  end if;
  if coalesce((r->>'hecho')::boolean, false) or coalesce((r->>'cambio')::boolean, false) then
    perform set_config('mx_bandeja.escribe', 'bandeja_dimelo', true);
    update bandeja_dimelo
       set estado = case when (r->>'hecho')::boolean then 'aprobada' else 'caducada' end, resuelto_por = v_quien, resuelto_el = now(),
           hecho_id = (r->>'hecho_id')::uuid,
           resuelto_motivo = case when (r->>'hecho')::boolean then null else 'Lo que el banco proponía cambió antes de aprobarla' end
     where id = q.id;
    perform set_config('mx_bandeja.escribe', '', true);
  end if;
  return r || jsonb_build_object('dimelo_id', q.id);
end $$;
revoke execute on function public.fn_bandeja_aprobar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_aprobar(uuid, jsonb) to authenticated;
comment on function public.fn_bandeja_aprobar(uuid, jsonb) is 'c17: el «Así es» de una propuesta del «Dímelo» (solo el dueño, por la API): la registra fn_bandeja_hacer con la acción ya validada que se guardó, sin motivo (la frase no levanta frenos; solo es la línea de lo que la pide). Si la puerta frena, devuelve lo que dijo y su huella. La IA nunca llega aquí.';

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
-- 14. LO QUE LEE LA PANTALLA: fn_bandeja_leer(p).
--     p: {} (todo), o {ids: [movimientos]} (solo esas tarjetas: lo que quedó
--     en «faltan», o las de una contraparte después de contestar una; la
--     pantalla conserva lo demás), ms (el reloj de las recomendaciones: 2.5 s
--     de fábrica, 4 s como mucho), max (cuántas recomendaciones como mucho),
--     entre (solo estos pendientes existen para la llamada: lo usan las
--     pruebas, para que valgan con lo que la base tenga pendiente).
--     {version, config, categorias, cuentas_propias, prestamos, cuadrilla,
--      proveedores (estos cinco, solo en la llamada entera),
--      tarjetas: {<movimiento_id>: {clave, nombre, clase, rec, dimelo,
--      deshecho, pensando (su recomendación no dio tiempo: viene en la
--      llamada siguiente)}},
--      grupos: [{clave, nombre, clase, n, total, movimientos (por fecha),
--      rec, mixto, pendiente (sus tarjetas no se han mirado todavía),
--      memoria, solo_ok, uno_a_uno}],
--      parte (se pidieron unas: ids), faltan: [los movimientos cuya
--      recomendación no dio tiempo, por unidades enteras y en su orden: se
--      piden otra vez con {ids}], parcial (quedó alguno),
--      recibos: [lo ya registrado cuyo recibo llegó después y espera a
--      Edgar: {movimiento_id, fecha, monto, descripcion, registrado, otro,
--      opciones: [{opcion, huella, es (recibo | otra), texto}]}],
--      solos: [lo que entró solo en 14 días],
--      recientes: [los «Así es» de 14 días, para deshacer; con su tanda],
--      tandas: [las decisiones por grupo de 14 días, para deshacerlas
--      enteras] (los dos, con la clave de su comercio: al deshacer se sabe
--      si hay una regla «que entre solo» que apagar), memoria: [...],
--      tarifas: [las de un procesador que Edgar confirmó o enseñó],
--      ia_abiertas: [propuestas de la IA (c8) que siguen pendientes en
--      movimientos que esta capa ya registró: la pantalla las cierra],
--      ia_caducar: [las aprobadas cuyo asiento deshizo la Bandeja: igual],
--      control: [lo del control de esta capa que Edgar tiene que saber, en
--      llano]}.
--     LAS RECOMENDACIONES VAN POR UNIDADES Y POR RELOJ: un grupo de cargos
--     de una contraparte (o un lote de c6) se recomienda entero o no se
--     recomienda (lo que dice el grupo sale de lo que dicen todas sus
--     tarjetas); lo demás, de uno en uno. Primero los grupos, del más grande
--     al más chico (lo que la pantalla enseña arriba); después el resto, por
--     fecha. El reloj se mira entre unidad y unidad, y siempre sale al menos
--     una: con la Bandeja llena la llamada contesta mucho antes del corte de
--     la API (antes lo recomendaba todo de una vez, con un reloj de 8 s: el
--     mismo corte), y la pantalla va pidiendo lo que falta.
--     LOS GRUPOS son solo de CARGOS (un comercio, un Zelle a alguien): los
--     depósitos de un mismo pagador se dan aparte (uno_a_uno: cada depósito
--     paga sus facturas; no se deciden de una vez). Y la recomendación de un
--     grupo es la de SUS TARJETAS cuando coinciden (todas las que tienen
--     una, y al menos seis de cada diez): si unas dicen una cosa y otras
--     otra (mixto), el grupo no propone nada. Antes salía del nombre, y un
--     toque mandaba las comisiones del procesador a «Oficina y software».
--     Solo lee; a quien no es el dueño no le devuelve nada.
-- ---------------------------------------------------------------------
-- LO QUE RECOMIENDA UN GRUPO cuando sus tarjetas coinciden: la acción y los
-- datos que salen de la clave de sus tarjetas («gasto|5100», «personal|»,
-- «cuadrilla|<persona>»…) y su texto llano. p_falta_obra: a TODOS los del
-- grupo les falta la obra (ese día la cuadrilla no estuvo en una sola): el
-- texto lo dice, en vez de volver a ofrecer «la del día de cada uno».
create or replace function public.fn_bandeja_grupo_rec(p_k text, p_fuente text, p_falta_obra boolean default false) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_acc  text := split_part(coalesce(p_k, ''), '|', 1);
  v_dato text := split_part(coalesce(p_k, ''), '|', 2);
  v_obra text := case when coalesce(p_falta_obra, false)
                      then '. A estos les falta la obra: ese día la cuadrilla no estuvo en una sola. Elige la obra para todos, o '
                           'contéstalos uno por uno'
                      else '. Cada uno va a la obra donde estuvo la cuadrilla ese día (el que no tenga una sola, se queda para que '
                           'digas la obra), o a la que tú digas para todos' end;
begin
  if v_acc not in ('gasto', 'personal', 'cuadrilla', 'contratista', 'traspaso') then
    return null;
  end if;
  return jsonb_build_object(
    'accion', v_acc, 'fuente', coalesce(p_fuente, 'app'),
    'datos', case v_acc
               when 'gasto' then jsonb_build_object('cuenta', v_dato)
               when 'traspaso' then jsonb_build_object('cuenta', v_dato)
               when 'cuadrilla' then jsonb_build_object('usuario_id', v_dato)
               when 'contratista' then jsonb_strip_nulls(jsonb_build_object('proveedor_id', nullif(v_dato, '')))
               else '{}'::jsonb end,
    'texto', case v_acc
               when 'personal' then 'Son tuyos, no de la empresa: salen como retiro tuyo, no como gasto del negocio.'
               when 'contratista' then 'Son pagos a un subcontratista' || v_obra || '.'
               when 'cuadrilla' then format('Son pagos a %s, de la cuadrilla: se reparten entre las obras según sus horas.',
                                            coalesce((select pf.nombre from perfiles pf where pf.id::text = v_dato), 'alguien de la cuadrilla'))
               when 'traspaso' then format('Son dinero entre tus cuentas (con %s): no son un gasto.',
                                           coalesce((select y->>'nombre' from jsonb_array_elements(fn_bandeja_cuentas_propias()) y
                                                      where y->>'codigo' = v_dato), 'otra cuenta tuya'))
               else format('Son «%s»%s.', fn_bandeja_cuenta_llana(v_dato),
                           case when (select k2.regla_obra from cuentas k2 where k2.codigo = v_dato) = 'obligatoria' then v_obra else '' end) end,
    'falta_obra', case when coalesce(p_falta_obra, false) then true end);
end $$;
revoke execute on function public.fn_bandeja_grupo_rec(text, text, boolean) from public, anon, service_role;
grant  execute on function public.fn_bandeja_grupo_rec(text, text, boolean) to authenticated;
comment on function public.fn_bandeja_grupo_rec(text, text, boolean) is 'c17: lo que recomienda un grupo de cargos cuyas tarjetas coinciden: {accion, datos, texto llano, fuente} a partir de la clave de sus tarjetas; dice cuándo a todos les falta la obra.';

create or replace function public.fn_bandeja_leer(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg       bandeja_config;
  u         record;
  x         jsonb;
  c         jsonb;
  rec       jsonb;
  dim       jsonb;
  ctx       jsonb;
  v_k       text;
  v_id      uuid;
  v_base    jsonb;
  v_tarj    jsonb;
  v_tk      text[] := '{}';     -- (las tarjetas se juntan en arreglos y se arman al final: pegar jsonb a jsonb en cada vuelta
  v_tv      jsonb[] := '{}';    --  copia todo lo anterior, y con mil pendientes eso solo era un segundo)
  v_lista   jsonb[] := '{}';
  v_uids    uuid[];
  v_uentre  uuid[];
  v_grupos  jsonb := '[]'::jsonb;
  v_dep     jsonb := '[]'::jsonb;
  v_lotes   jsonb := '[]'::jsonb;
  v_ctl     jsonb := '[]'::jsonb;
  v_sin     jsonb := '{}'::jsonb;
  v_faltan  uuid[] := '{}';
  v_res     jsonb;
  v_ids     jsonb := case when jsonb_typeof(p->'ids') = 'array' then p->'ids' end;
  v_entre   jsonb := case when jsonb_typeof(p->'entre') = 'array' then p->'entre' end;
  v_parte   boolean;
  v_max     int;
  v_n       int := 0;
  v_fin     timestamptz;
  v_corta   boolean := false;
  c_libre   constant text[] := array['sin_ticket', 'clasificar', 'dudosa', 'sin_propuesta'];
  c_lote    constant text[] := array['interes_tarjeta', 'cargo_banco', 'interes', 'cuota_prestamo'];
begin
  perform fn_bandeja_exigir_dueno();
  if current_user = 'service_role' then
    return null;
  end if;
  v_parte := v_ids is not null;
  v_max := case when coalesce(p->>'max', '') ~ '^[0-9]{1,5}$' then (p->>'max')::int end;
  v_fin := clock_timestamp() + make_interval(secs => least(greatest(coalesce(fn_bandeja_num(p->>'ms'), 2500), 20), 4000) / 1000.0);
  select * into cfg from bandeja_config where id = 1;
  if v_ids is not null then
    select coalesce(array_agg(distinct e::uuid), '{}') into v_uids
      from jsonb_array_elements_text(v_ids) e where e ~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$';
  end if;
  if v_entre is not null then
    select coalesce(array_agg(distinct e::uuid), '{}') into v_uentre
      from jsonb_array_elements_text(v_entre) e where e ~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$';
  end if;
  -- 1. LO BARATO de cada pendiente: de quién es (la contraparte) y qué pensaba c6. Con ello se sabe qué GRUPO forma con otros.
  --    (Cuando la pantalla pide unas tarjetas —ids—, solo las de esas: las pide por unidades enteras, como vinieron en «faltan» o
  --    todas las de una misma contraparte; así lo que cuesta una llamada de seguir va con lo pedido y no con la Bandeja entera)
  select coalesce(jsonb_agg(z.x order by z.fecha, z.id), '[]'::jsonb) into v_base
    from (select mb.id, mb.fecha,
                 jsonb_build_object('id', mb.id, 'f', mb.fecha, 'monto', mb.monto, 'motivo', coalesce(mb.propuesta->>'motivo', 'sin_propuesta'),
                                    'c', fn_bandeja_contraparte(mb.desc_norm, mb.memo, mb.monto, mb.tipo_banco, mb.cheque)) as x
            from movimientos_banco mb
           where mb.estado = 'pendiente' and (v_uids is null or mb.id = any (v_uids)) and (v_uentre is null or mb.id = any (v_uentre))) z;
  -- (lo que las recomendaciones comparten: las facturas por cobrar, y qué pendientes pueden ser de un prestamista)
  ctx := jsonb_build_object('facturas', fn_bandeja_facturas());
  begin
    ctx := ctx || jsonb_build_object('prest', fn_bandeja_prestamista_quiza(coalesce(v_uids, v_uentre)));
  exception when others then
    null;   -- sin eso, cada tarjeta lo mira por su cuenta (más lento, igual de bien)
  end;
  -- 2. LAS RECOMENDACIONES, por UNIDADES: un grupo de cargos de una misma contraparte (o un lote de c6) se recomienda ENTERO o
  --    no se recomienda (lo que dice el grupo sale de lo que dicen todas sus tarjetas); lo demás, de uno en uno. Primero los
  --    grupos, del más grande al más chico (es lo que la pantalla enseña arriba), y después el resto por fecha; o, si la
  --    pantalla pide unos (ids), las unidades de esos, en su orden. El reloj se mira entre unidad y unidad.
  for u in
    with b as (select t.x, t.n,
                      case when t.x->>'motivo' = any (c_lote) then 'L:' || (t.x->>'motivo')
                           when t.x->'c'->>'clave' is not null and t.x->'c'->>'clase' in ('comercio', 'zelle_a')
                                and (t.x->>'monto')::numeric < 0 and t.x->>'motivo' = any (c_libre) then 'G:' || (t.x->'c'->>'clave')
                           else 'M:' || (t.x->>'id') end as uk
                 from jsonb_array_elements(v_base) with ordinality as t(x, n)),
         i as (select e.id, min(e.pos) as pos from jsonb_array_elements_text(coalesce(v_ids, '[]'::jsonb)) with ordinality as e(id, pos) group by e.id),
         un as (select b.uk, count(*) as n, sum(abs((b.x->>'monto')::numeric)) as total, min(b.n) as primero,
                       jsonb_agg(b.x order by b.n) as xs, min(i.pos) as pedido
                  from b left join i on i.id = b.x->>'id'
                 group by b.uk)
    select un.uk, un.xs
      from un
     where not v_parte or un.pedido is not null
     order by case when v_parte then un.pedido end,
              (un.n >= 2) desc, case when un.n >= 2 then un.n end desc, case when un.n >= 2 then un.total end desc, un.primero
  loop
    if v_n > 0 and (clock_timestamp() > v_fin or (v_max is not null and v_n >= v_max)) then
      v_corta := true;
    end if;
    for x in select value from jsonb_array_elements(u.xs) loop
      c := x->'c';
      v_id := (x->>'id')::uuid;
      if v_corta then
        v_faltan := v_faltan || v_id;
        rec := null;
        continue when v_parte;   -- (lo pedido que no dio tiempo: la pantalla conserva lo que tenía y lo vuelve a pedir)
      else
        rec := fn_bandeja_recomendar(v_id, ctx || jsonb_build_object('c', c));
        v_n := v_n + 1;
      end if;
      select jsonb_strip_nulls(jsonb_build_object('dimelo_id', q.id, 'estado', q.estado, 'frase', q.frase, 'accion', q.accion, 'datos', q.datos,
                                                  'texto', q.texto, 'porque', q.porque, 'falta', q.falta, 'recordar', q.recordar,
                                                  -- (lo que le falta lo escribió la IA, no la base: la tarjeta lo dice)
                                                  'falta_de_la_ia', case when q.uso->>'falta_de_la_ia' = 'true' then true end,
                                                  'pide_obra', case when q.estado = 'pendiente' and q.falta is not null then true end))
        into dim
        from bandeja_dimelo q
       where q.movimiento_id = v_id and q.estado in ('pendiente', 'sin_propuesta') and q.creado_el > now() - interval '7 days'
         and not exists (select 1 from bandeja_dimelo z where z.movimiento_id = q.movimiento_id and z.creado_el > q.creado_el)
       order by q.creado_el desc limit 1;
      if not found then
        dim := null;
      end if;
      -- lo que la tarjeta recomienda, en una clave: con ella se ve si las de un grupo dicen lo mismo
      v_k := case rec->>'accion'
               when 'gasto' then 'gasto|' || coalesce(rec->'datos'->>'cuenta', '')
               when 'personal' then 'personal|'
               when 'cuadrilla' then 'cuadrilla|' || coalesce(rec->'datos'->>'usuario_id', '')
               when 'contratista' then 'contratista|' || coalesce(rec->'datos'->>'proveedor_id', '')
               when 'traspaso' then 'traspaso|' || coalesce(rec->'datos'->>'cuenta', '')
             end;
      if rec ? 'sin_alta' then
        v_sin := v_sin || jsonb_build_object(rec->>'sin_alta', coalesce((v_sin->>(rec->>'sin_alta'))::int, 0) + 1);
      end if;
      v_tk := v_tk || v_id::text;
      v_tv := v_tv || jsonb_strip_nulls(jsonb_build_object(
                  'clave', c->>'clave', 'nombre', c->>'nombre', 'clase', c->>'clase', 'rec', rec - 'sin_alta', 'dimelo', dim,
                  -- (pensando: su recomendación no dio tiempo en esta llamada; viene en la siguiente)
                  'pensando', case when v_corta then true end,
                  'deshecho', case when exists (select 1 from bandeja_hechos h where h.movimiento_id = v_id and h.deshecho_el is not null)
                                   then true end));
      v_lista := v_lista || jsonb_build_object('id', v_id, 'f', x->>'f', 'monto', x->'monto', 'clave', c->>'clave', 'nombre', c->>'nombre',
                                               'clase', c->>'clase', 'motivo', x->>'motivo', 'u', u.uk, 'ev', not v_corta,
                                               'acc', rec->>'accion', 'k', v_k, 'fte', rec->>'fuente', 'pide', rec->'pide',
                                               'pm', rec->'pide_motivo', 'po', rec->'pide_obra',
                                               'av', case when rec ? 'aviso' then true end);
    end loop;
  end loop;
  select coalesce(jsonb_object_agg(t.k, t.v), '{}'::jsonb) into v_tarj from unnest(v_tk, v_tv) as t(k, v);
  -- 3. LOS GRUPOS DE CARGOS: dos o más pendientes de la misma contraparte, de los que c6 no dice otra cosa. Su recomendación
  --    es la de SUS TARJETAS cuando coinciden (todas las que dicen algo, y al menos seis de cada diez); «pendiente» si todavía
  --    no dio tiempo a mirarlas.
  select coalesce(jsonb_agg(z.g order by z.n desc, z.total), '[]'::jsonb) into v_grupos
    from (select a.n, a.total,
                 jsonb_strip_nulls(jsonb_build_object(
                   'clave', a.clave, 'nombre', a.nombre, 'clase', a.clase, 'n', a.n, 'total', a.total, 'movimientos', a.movs,
                   'solo_ok', case when a.clase = 'comercio' then true end,
                   'pendiente', case when not a.ev then true end,
                   'mixto', case when a.ev and a.nk > 1 then true end,
                   'memoria', (select jsonb_build_object('accion', bm.accion, 'datos', bm.datos, 'texto', bm.texto, 'solo', bm.solo)
                                 from bandeja_memoria bm where bm.clave = a.clave and bm.activa),
                   'rec', case when a.ev and a.nk = 1 and a.nr * 10 >= a.n * 6
                               then fn_bandeja_grupo_rec(a.k, coalesce(a.fte, 'app'), a.npo = a.n) end)) as g
            from (select y->>'clave' as clave, min(y->>'nombre') as nombre, min(y->>'clase') as clase, count(*) as n,
                         sum((y->>'monto')::numeric) as total, jsonb_agg(y->>'id' order by y->>'f', y->>'id') as movs,
                         count(distinct y->>'k') as nk, count(y->>'k') as nr, min(y->>'k') as k,
                         mode() within group (order by y->>'fte') as fte,
                         bool_and((y->>'ev')::boolean) as ev, count(*) filter (where y->>'po' = 'true') as npo
                    from unnest(v_lista) as y
                   -- (lo que el banco ya reconoce va en su lote; lo que se contesta en otra parte no entra en un grupo)
                   where y->>'u' like 'G:%' and (not (y->>'ev')::boolean or (y->>'acc' is distinct from 'banco' and y->>'av' is null))
                   group by y->>'clave'
                  having count(*) >= 2) a) z;
  -- LOS DEPÓSITOS DE UN MISMO PAGADOR (un procesador de tarjetas, un cliente por Zelle o por transferencia): juntos a la vista,
  -- pero cada uno con su respuesta
  if not v_parte then
    select coalesce(jsonb_agg(z.g order by z.n desc, z.total desc), '[]'::jsonb) into v_dep
      from (select count(*) as n, sum((y->>'monto')::numeric) as total,
                   jsonb_build_object('clave', y->>'clave', 'nombre', min(y->>'nombre'), 'clase', min(y->>'clase'), 'n', count(*),
                                      'total', sum((y->>'monto')::numeric), 'movimientos', jsonb_agg(y->>'id' order by y->>'f', y->>'id'),
                                      'uno_a_uno', true) as g
              from unnest(v_lista) as y
             where y->>'clave' is not null and y->>'clase' in ('zelle_de', 'deposito', 'procesador') and (y->>'monto')::numeric > 0
             group by y->>'clave'
            having count(*) >= 2) z;
  end if;
  -- LOS LOTES de c6: lo que c6 ya reconoce igual en varios (intereses, cargos del banco, cuotas): aceptar todos de una vez.
  select coalesce(jsonb_agg(z.g order by z.n desc), '[]'::jsonb) into v_lotes
    from (select count(*) as n,
                 jsonb_build_object('clave', 'M:' || (y->>'motivo'), 'clase', 'lote', 'n', count(*), 'total', sum((y->>'monto')::numeric),
                                    'movimientos', jsonb_agg(y->>'id' order by y->>'f', y->>'id'),
                                    'nombre', case y->>'motivo' when 'interes_tarjeta' then 'Intereses de la tarjeta'
                                                                when 'cargo_banco' then 'Cargos del banco'
                                                                when 'interes' then 'Intereses que paga el banco'
                                                                else 'Cuotas de préstamos' end,
                                    'rec', jsonb_build_object('accion', 'banco', 'fuente', 'banco',
                                                              'texto', 'El banco ya los reconoce: se registra cada uno como dice su tarjeta.')) as g
            from unnest(v_lista) as y
           where y->>'u' like 'L:%' and (y->>'ev')::boolean and y->>'acc' = 'banco' and y->>'pide' is null and y->>'pm' is null
           group by y->>'motivo'
          having count(*) >= 2) z;
  -- LO DEL CONTROL que Edgar tiene que saber, en llano (lo demás lo ve quien pega, en v_bandeja_control)
  select coalesce(jsonb_agg(jsonb_build_object('orden', k.orden, 'nivel', k.nivel, 'texto', k.texto) order by k.orden), '[]'::jsonb) into v_ctl
    from (select t.orden, t.nivel,
                 case t.orden
                   when 20 then 'Algo entró solo que no debía entrar solo. Míralo abajo, en «Registrado solo», y deshazlo.'
                   when 50 then 'Hay una regla «que entre solo» que no debería estar. Apágala abajo, en «Lo que recuerdo».'
                   when 60 then format('%s cosa(s) que registraste aquí se cambiaron después por otro lado: vuelve a mirarlas en Banco → Movimientos.', t.filas)
                   when 70 then 'Registraste dinero de un préstamo que todavía no está dado de alta en la app. Hay que darlo de alta una vez, con su '
                                'contrato: sin eso sus cuotas no se pueden repartir entre lo que baja la deuda y los intereses.'
                   when 80 then 'La tarea que registra sola falló la última vez. Lo que tenía que entrar solo entra igual al abrir la Bandeja.'
                   else 'El control de la Bandeja no cuadra: no registres nada más desde aquí hasta que se revise.' end as texto
            from fn_bandeja_control() t
           where not t.ok and t.orden in (10, 20, 30, 40, 50, 60, 70, 80)) k;
  select v_ctl || coalesce(jsonb_agg(jsonb_build_object('orden', 75, 'nivel', 'aviso', 'texto', format(
           '%s cargo(s) parecen cuotas de un préstamo de %s que todavía no está dado de alta en la app. Hay que darlo de alta una vez, con su '
           'contrato: desde entonces sus cuotas se reparten solas entre lo que baja la deuda y los intereses.', e.value, e.key)) order by e.key),
           '[]'::jsonb)
    into v_ctl
    from jsonb_each_text(v_sin) e;
  v_res := jsonb_build_object(
    'version', fn_bandeja_version(),
    'config', jsonb_build_object('solo', cfg.solo, 'solo_tope', cfg.solo_tope, 'dimelo', cfg.dimelo,
                                 'c10', to_regprocedure('public.fn_jornal_pago(jsonb)') is not null, 'solo_ultimo', cfg.solo_ultimo),
    'tarjetas', v_tarj,
    'grupos', v_lotes || v_grupos || v_dep,
    -- (parte: la pantalla pidió unas tarjetas —ids—; lo demás lo conserva. faltan: las que no dio tiempo a recomendar, en su
    -- orden: se piden otra vez con {ids: faltan}. parcial: quedó alguna)
    'parte', v_parte,
    'faltan', to_jsonb(v_faltan),
    'parcial', cardinality(v_faltan) > 0,
    -- LO YA REGISTRADO CUYO RECIBO LLEGÓ DESPUÉS y no se cambió solo: el gasto está dos veces hasta que Edgar diga
    'recibos', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                         'movimiento_id', mb.id, 'fecha', mb.fecha, 'monto', mb.monto, 'descripcion', mb.descripcion,
                         'registrado', (select h.texto from bandeja_hechos h
                                         where h.movimiento_id = mb.id and h.deshecho_el is null order by h.el desc limit 1),
                         'otro', case when exists (select 1 from jsonb_array_elements(case when jsonb_typeof(mb.propuesta->'tickets') = 'array'
                                                                                           then mb.propuesta->'tickets' else '[]'::jsonb end) t
                                                    where t ? 'otro_total')
                                      then 'Hay un recibo de ese comercio con otro total: ¿se leyó sin el impuesto? Corrige su total en la app y '
                                           'aquí saldrá para cambiarlo.' end,
                         'opciones', (select coalesce(jsonb_agg(jsonb_build_object(
                                               'opcion', (t.n - 1)::int, 'huella', fn_bandeja_opcion_huella(t.o),
                                               'es', case when t.o->>'llamar' = 'fn_banco_casar_con' then 'recibo' else 'otra' end,
                                               'texto', fn_bandeja_opcion_texto(t.o, mb.monto, mb.id)) order by t.n), '[]'::jsonb)
                                        from jsonb_array_elements(case when jsonb_typeof(mb.propuesta->'opciones') = 'array'
                                                                       then mb.propuesta->'opciones' else '[]'::jsonb end) with ordinality as t(o, n)
                                       where t.o->>'llamar' in ('fn_banco_casar_con', 'fn_banco_duplicado'))))
                         order by mb.fecha, mb.id), '[]'::jsonb)
                  from movimientos_banco mb
                 where mb.estado = 'casado' and mb.propuesta->>'motivo' = 'llego_su_ticket'),
    'solos', (select coalesce(jsonb_agg(jsonb_build_object('hecho_id', h.id, 'movimiento_id', h.movimiento_id, 'fecha', mb.fecha,
                                                           'monto', h.monto, 'descripcion', mb.descripcion, 'texto', h.texto, 'el', h.el,
                                                           'asiento', a.numero, 'corrio', h.corrio, 'clave', h.memoria_clave,
                                                           'nombre', substring(h.memoria_clave from '^[A-Z]+[<>]?:(.*)$')) order by h.el desc), '[]'::jsonb)
                from bandeja_hechos h
                join movimientos_banco mb on mb.id = h.movimiento_id
                left join asientos a on a.id = h.asiento_id
               where h.solo and h.deshecho_el is null and h.el > now() - interval '14 days'),
    -- (con su clave: al deshacer se sabe si lo de esa contraparte «entra solo», para apagarlo o preguntarlo)
    'recientes', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                              'hecho_id', z.id, 'movimiento_id', z.movimiento_id, 'fecha', z.fecha, 'monto', z.monto,
                                              'descripcion', z.descripcion, 'texto', z.texto, 'el', z.el, 'fuente', z.fuente, 'tanda', z.tanda,
                                              'clave', z.memoria_clave))
                                            order by z.el desc), '[]'::jsonb)
                    from (select h.id, h.movimiento_id, mb.fecha, h.monto, mb.descripcion, h.texto, h.el, h.fuente, h.tanda, h.memoria_clave
                            from bandeja_hechos h
                            join movimientos_banco mb on mb.id = h.movimiento_id
                           where not h.solo and h.deshecho_el is null and h.el > now() - interval '14 days'
                             and mb.estado <> 'pendiente' and mb.asiento_id is not distinct from h.asiento_id
                           order by h.el desc limit 300) z),
    -- LAS DECISIONES POR GRUPO (su tanda), para deshacerlas enteras con un solo porqué
    'tandas', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('tanda', t.tanda, 'n', t.n, 'monto', t.monto, 'el', t.el,
                                                            'nombre', t.nombre, 'texto', t.que, 'clave', t.clave)) order by t.el desc), '[]'::jsonb)
                 from (select h.tanda, count(*) as n, sum(h.monto) as monto, max(h.el) as el,
                              case when min(h.accion) = 'banco'
                                     then case when bool_and(h.datos->>'llamar' = 'fn_prestamo_cuota') then 'Cuotas de préstamos'
                                               else 'Lo que el banco ya reconocía' end
                                   when count(distinct h.memoria_clave) = 1 then min(substring(h.memoria_clave from '^[A-Z]+[<>]?:(.*)$'))
                                   else 'Varios' end as nombre,
                              case when count(distinct h.memoria_clave) = 1 and min(h.accion) <> 'banco' then min(h.memoria_clave) end as clave,
                              case min(h.accion)
                                when 'personal' then 'tuyos (personales)'
                                when 'gasto' then case when count(distinct h.datos->>'cuenta') = 1 then '«' || fn_bandeja_cuenta_llana(min(h.datos->>'cuenta')) || '»'
                                                       else 'gastos' end
                                when 'cuadrilla' then 'pagos a la cuadrilla'
                                when 'contratista' then 'pagos a un subcontratista'
                                when 'traspaso' then 'dinero entre tus cuentas'
                                else 'como decía cada tarjeta' end as que
                         from bandeja_hechos h
                         join movimientos_banco mb on mb.id = h.movimiento_id
                        where h.tanda is not null and h.deshecho_el is null and h.el > now() - interval '14 days'
                          and mb.estado <> 'pendiente' and mb.asiento_id is not distinct from h.asiento_id
                        group by h.tanda
                       having count(*) >= 2) t),
    -- (obra: lo recordado va a una obra —nunca entra solo: la pantalla no ofrece la casilla—)
    'memoria', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                            'clave', bm.clave, 'nombre', bm.nombre, 'clase', bm.clase, 'accion', bm.accion,
                                            'texto', bm.texto, 'solo', bm.solo, 'veces', bm.veces,
                                            'obra', case when bm.datos ? 'obra' or bm.accion = 'contratista'
                                                              or (bm.accion = 'gasto' and (select k.regla_obra from cuentas k
                                                                                            where k.codigo = bm.datos->>'cuenta') = 'obligatoria')
                                                         then true end)) order by bm.nombre), '[]'::jsonb)
                  from bandeja_memoria bm where bm.activa),
    -- LAS TARIFAS de los procesadores que Edgar confirmó con un cobro, o que la app apuntó de uno (se pueden olvidar)
    'tarifas', (select coalesce(jsonb_agg(y - 'conf' order by y->>'proc', (y->>'pct')::numeric), '[]'::jsonb)
                  from jsonb_array_elements(cfg.tarifas) y
                 where coalesce((y->>'veces')::int, 0) > 0 or y->>'origen' = 'aprendida'),
    -- lo de la IA (c8) que quedó abierto en movimientos que esta capa ya registró: la pantalla lo cierra por la función de borde
    'ia_abiertas', (select coalesce(jsonb_agg(q.id order by q.creado_el), '[]'::jsonb)
                      from contador_propuestas q
                     where q.estado = 'pendiente'
                       and exists (select 1 from bandeja_hechos h join movimientos_banco mb on mb.id = h.movimiento_id
                                    where h.movimiento_id = q.movimiento_id and h.deshecho_el is null and mb.estado <> 'pendiente')),
    -- y lo que la IA tenía APROBADO con un asiento que la Bandeja deshizo: ya no tiene asiento vivo; la pantalla lo cierra igual
    'ia_caducar', (select coalesce(jsonb_agg(q.id order by q.creado_el), '[]'::jsonb)
                     from contador_propuestas q
                    where q.estado in ('aprobada', 'editada') and q.asiento_id is not null
                      and exists (select 1 from bandeja_hechos h
                                   where h.movimiento_id = q.movimiento_id and h.asiento_id = q.asiento_id and h.deshecho_el is not null)
                      and exists (select 1 from asientos r where r.reversa_a = q.asiento_id and r.camino in ('reverso', 'reverso_automatico'))),
    'control', v_ctl);
  if not v_parte then
    -- (lo fijo, que la pantalla conserva entre una llamada y otra)
    v_res := v_res || jsonb_build_object(
      'categorias', fn_bandeja_categorias(),
      'cuentas_propias', fn_bandeja_cuentas_propias(),
      'prestamos', (select coalesce(jsonb_agg(jsonb_build_object('id', pr.id, 'prestamista', pr.prestamista) order by pr.creado_el), '[]'::jsonb)
                      from prestamos pr),
      'cuadrilla', case when to_regprocedure('public.fn_jornal_pago(jsonb)') is null then '[]'::jsonb
                        else (select coalesce(jsonb_agg(jsonb_build_object('usuario_id', pf.id, 'nombre', pf.nombre) order by pf.nombre), '[]'::jsonb)
                                from perfiles pf where pf.rol <> 'dueno' and coalesce(pf.activo, true)) end,
      -- (a quién se le paga un subcontrato: con él, el pago sale con su nombre en el 1099)
      'proveedores', (select coalesce(jsonb_agg(jsonb_build_object('proveedor_id', pv.id, 'nombre', pv.nombre) order by lower(pv.nombre)), '[]'::jsonb)
                        from proveedores pv where pv.activo));
  end if;
  return v_res;
end $$;
revoke execute on function public.fn_bandeja_leer(jsonb) from public, anon, service_role;
grant  execute on function public.fn_bandeja_leer(jsonb) to authenticated;
comment on function public.fn_bandeja_leer(jsonb) is 'c17: lo que la Bandeja nueva lee: la tarjeta de cada movimiento pendiente (contraparte, recomendación y propuesta del «Dímelo»), los grupos de cargos con la recomendación de sus tarjetas (si coinciden) y los depósitos de un mismo pagador (uno a uno), lo registrado cuyo recibo llegó después y espera su respuesta, lo que entró solo y lo contestado (14 días, con sus tandas), lo recordado, las tarifas confirmadas y lo del control que el dueño tiene que saber. Las recomendaciones van por reloj (ms: 2.5 s de fábrica) y por unidades (un grupo, entero): lo que no dio tiempo se devuelve en «faltan» y se pide otra vez con {ids}. Solo lee.';


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
      -- 20: lo que entró solo es SOLO lo permitido: un cargo de un comercio, de algo personal o de un gasto que NO lleva obra
      --     (el tope de entonces no se sabe: se mira el máximo que la tabla deja poner)
      select 20, 'bandeja: nada entró solo fuera de lo permitido', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → deshazlo en la Bandeja (Registrado solo → Deshacer) y avisa' end
        from (select count(*) as n, left(string_agg(format('%s %s «%s»', v.fecha, v.monto, coalesce(v.descripcion, '')), '; '), 1200) as d
                from vivo v
               where v.solo
                 and (v.monto >= 0 or v.accion not in ('gasto', 'personal') or coalesce(v.memoria_clave, '') not like 'C:%'
                      or abs(v.monto) > 5000 or v.datos ? 'proyecto_id'
                      or (v.accion = 'gasto'
                          and (select k.regla_obra from cuentas k where k.codigo = v.datos->>'cuenta') = 'obligatoria'))) t
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
                                           'fn_bandeja_precondiciones', 'fn_bandeja_guarda', 'fn_bandeja_sin_datos', 'fn_bandeja_sin_datos_jsonb')
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
      -- 50: una regla «que entre solo» es de un comercio, y de algo personal o de un gasto que no lleva obra (lo impide la
      --     tabla, salvo la regla de la cuenta, que puede cambiar después; aquí se ve)
      select 50, 'bandeja: las reglas «que entre solo» son de comercios y no llevan obra', 'cuadre', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → apágala en la Bandeja (Lo que recuerdo)' end
        from (select count(*) as n, left(string_agg(bm.clave, '; '), 600) as d
                from bandeja_memoria bm
               where bm.solo and not (bm.clase = 'comercio' and bm.accion in ('gasto', 'personal') and not (bm.datos ? 'obra')
                                      and (bm.accion = 'personal'
                                           or (select k.regla_obra from cuentas k where k.codigo = bm.datos->>'cuenta') is distinct from 'obligatoria'))) t
      union all
      -- 60 (aviso): lo registrado que alguien des-casó por otro lado (sigue marcado como hecho)
      select 60, 'bandeja: lo registrado sigue como se dejó', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → se des-casó fuera de la Bandeja: vuelve a contestarlo allí' end
        from (select count(*) as n, left(string_agg(format('%s %s «%s»', v.fecha, v.monto, coalesce(v.descripcion, '')), '; '), 1200) as d
                from vivo v
               where v.mov_estado is null or v.mov_estado = 'pendiente' or v.mov_asiento is distinct from v.asiento_id) t
      union all
      -- 65 (aviso): lo registrado cuyo recibo llegó después y espera a Edgar (el gasto está dos veces hasta que diga; c6 lo
      --     tiene en rojo en su control: aquí se dice dónde se contesta)
      select 65, 'bandeja: ningún recibo esperando por lo ya registrado', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → abre la Bandeja: salen arriba con «Es su recibo» / «Es otra compra»' end
        from (select count(*) as n, left(string_agg(format('%s %s «%s»', mb.fecha, mb.monto, coalesce(mb.descripcion, '')), '; '), 1200) as d
                from movimientos_banco mb
               where mb.estado = 'casado' and mb.propuesta->>'motivo' = 'llego_su_ticket') t
      union all
      -- 70 (aviso): dinero de un préstamo registrado sin que el préstamo esté dado de alta
      select 70, 'bandeja: los préstamos recibidos están dados de alta', 'aviso', t.n = 0, t.n, 0,
             case when t.n > 0 then t.d || ' → da de alta el préstamo con su contrato (fn_prestamo_guardar, en el SQL Editor): sin eso sus cuotas no se reparten entre capital e intereses' end
        from (select count(*) as n, left(string_agg(format('%s %s de %s', v.fecha, v.monto, coalesce(v.datos->>'prestamista', '?')), '; '), 800) as d
                from vivo v
               where v.accion = 'prestamo' and not (v.datos ? 'prestamo_id')
                 and not exists (select 1 from prestamos p
                                  where position(upper(btrim(p.prestamista)) in upper(coalesce(v.datos->>'prestamista', '¿'))) > 0
                                     or position(upper(btrim(coalesce(v.datos->>'prestamista', '¿'))) in upper(p.prestamista)) > 0)) t
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
comment on function public.fn_bandeja_control() is 'c17: el control de la Bandeja nueva: la configuración, que nada entró solo fuera de lo permitido (nunca algo de obra), que cada propuesta aprobada tiene su registro, los permisos y las reglas «que entre solo» (cuadres), y lo registrado que se des-casó por fuera, los recibos que llegaron después y esperan, los préstamos sin dar de alta, la tarea y lo de la IA que quedó abierto en lo ya registrado (avisos).';

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
