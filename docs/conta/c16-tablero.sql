-- =====================================================================
-- c16-tablero.sql — LOS NÚMEROS DEL TABLERO: la portada «Resumen» de
-- Contabilidad, con gráficas, datos y enlaces, como el «Business at a
-- glance» de QuickBooks · c16 (Fase 16).
-- 13-nov-2026. Se pega en el SQL Editor DESPUÉS de c1, c2, c3 y c4 (y de
-- c6, c7, s1, p1, c8, c9, c10, c11, c12, c13 y c14 si se usan: la cadena de
-- siempre). Idempotente: se puede volver a pegar entero las veces que haga
-- falta. Después se pega c16-pruebas.sql.
--
-- QUÉ ES. Edgar pidió que la portada de Contabilidad «se viera como la de
-- QuickBooks: con gráficas, datos, números y enlaces de interés». Esta capa
-- es la mitad de eso que vive en la base: UNA FUNCIÓN POR TARJETA, que
-- devuelve en jsonb todo lo que la tarjeta enseña YA CALCULADO (totales,
-- porcentajes, diferencias, las series de cada gráfica mes a mes con el
-- mes en texto, los tramos de antigüedad, lo que queda por revisar), y
-- fn_tablero(p), que las junta en un solo jsonb con una clave por tarjeta.
-- La pantalla (js/conta.js) dibuja lo que llega: no suma, no resta y no
-- saca porcentajes (el dinero no se toca en JavaScript).
--
-- SOLO LEE. No crea ninguna tabla, no guarda nada, no escribe en el libro
-- ni en ninguna tabla de otra capa, no pone triggers ni índices. Son 34
-- funciones (ninguna SECURITY DEFINER) y nada más. Lo que la pantalla
-- recuerde de cada persona (qué tarjetas ve, si tapa los montos) lo guarda
-- el navegador: aquí no hay configuración que guardar.
--
-- LA VERDAD DE LOS NÚMEROS (lo que no se negocia):
--   · EL LIBRO EMPIEZA CON LA APERTURA (30-sep-2026): lo de antes vive en
--     QuickBooks. Una gráfica «de 12 meses» trae los meses que el libro
--     tiene y lo dice (libro.texto, meses_pedidos y meses_con_libro): nunca
--     inventa un mes ni pinta ceros donde no hay libro. Una comparación
--     con un período que cae antes del libro sale nula, con su porqué.
--   · CADA NÚMERO DICE DE DÓNDE SALE (fuente, en llano), CON QUÉ FECHA DE
--     CORTE (corte, o desde y hasta) y A DÓNDE LLEVA (ir: la página de
--     Contabilidad y su apartado, con las mismas palabras que usa conta.js:
--     ir(x.pagina, x)).
--   · «HOY» es el día de Miami (fn_fecha_miami de c2), como en todas las
--     capas. «Los últimos 30 días» son hoy y los 29 anteriores.
--   · UNA CAPA QUE NO ESTÁ deja SU tarjeta diciéndolo ({ok: false, falta:
--     «c6», motivo: …}) y las demás siguen. Una tarjeta que falla por lo
--     que sea, igual ({ok: false, motivo, codigo}): fn_tablero no se cae.
--   · LO QUE NO TIENE EQUIVALENTE SE DICE Y NO SE INVENTA. De la portada
--     de QuickBooks no hay aquí: «Mileage» (la app no lleva millas) ni el
--     «Lending» de Intuit (lo nuestro son los préstamos de c6). El «Sales
--     tax» es el use tax del DR-15 (c9): las ventas gravables todavía no
--     las separa nadie, y la tarjeta lo dice. El umbral («Threshold») de
--     la gráfica de caja no existe: no se pinta.
--
-- LAS TARJETAS (la clave de cada una en fn_tablero, su función y de dónde
-- sale cada cosa):
--   acciones          fn_tablero_acciones()
--       La fila de acciones rápidas, con lo que cambia de cada una: crear
--       una factura (c11: por dónde se factura hoy y cuántos borradores),
--       la Bandeja (c6: cuántos movimientos esperan y desde cuándo),
--       Conciliar (c6: la conciliación confirmada más vieja), pedir un
--       pago en línea (p1: enlaces activos), Cerrar el mes (c9: qué
--       período toca y qué lo detiene) y los estados financieros (c4).
--   cobros            fn_tablero_cobros(p_dias)
--       EL EMBUDO DE COBRO: por cobrar (las partidas abiertas de 1110:
--       cuántas facturas, cuántas vencidas) → cobrado en los últimos N
--       días (los cobros vigentes de c3, sin los devueltos) → depositado
--       (de eso, lo que ya está en el banco: el cobro casado con su
--       movimiento de c6, o el cobro de Stripe que su depósito ya liquidó).
--   bancos            fn_tablero_bancos()
--       Cada banco y tarjeta (v_banco_saldos de c6, la misma lista de la
--       página Bancos): saldo según el banco y su fecha, saldo en el
--       libro, cuántos movimientos por revisar y desde cuándo, cuándo se
--       actualizó y por dónde (Plaid de c7, o un archivo), su última
--       conciliación y su alarma. Con los totales ya sumados.
--   resultados        fn_tablero_resultados(p_desde, p_hasta, p_periodo)
--       EL RESULTADO de un período (este mes, el mes pasado, el año o un
--       rango): ingresos, costo, gastos, las tres utilidades, el margen,
--       las dos barras (lo que entra y lo que se gasta), la comparación
--       con el período anterior (los mismos días del mes anterior si el
--       mes va a medias) y lo que queda POR REVISAR en la Bandeja con
--       fecha de ese período. Del libro, con el mapeo de c4: lo mismo que
--       v_resultados, al centavo.
--   gastos            fn_tablero_gastos(p_dias, p_top)
--       LO GASTADO en los últimos N días por categoría (cada cuenta de
--       costo, gastos y otros gastos, con la etiqueta de c4), contra los N
--       días anteriores; con las «p_top» mayores y «las demás» ya
--       sumadas para la gráfica.
--   caja              fn_tablero_caja(p_meses, p_proyeccion, p_calendario)
--       EL SALDO DE CAJA mes a mes (el efectivo del balance de c4: bancos,
--       reserva, Stripe en tránsito y caja chica), con lo que entró y
--       salió de verdad cada mes, y —solo con lo que de verdad se sabe—
--       UNA PROYECCIÓN, marcada como tal: el saldo de hoy más lo que hay
--       por cobrar según su vencimiento, menos lo que hay por pagar según
--       el suyo y las cuotas de los préstamos (c6). Dice sus supuestos y lo
--       que NO incluye (la nómina, las tarjetas, lo que todavía no se ha
--       facturado ni comprado). Sin nada con fecha, no hay proyección.
--   facturas          fn_tablero_facturas(p_dias)
--       LAS FACTURAS: no pagadas (vencidas y por vencer) y lo cobrado en
--       los últimos N días (depositado y sin depositar).
--   ventas            fn_tablero_ventas(p_anio)
--       LOS INGRESOS (la sección «ingresos» de c4: 40xx) de cada mes del
--       año y su total.
--   por_cobrar        fn_tablero_antiguedad('cobrar')
--   por_pagar         fn_tablero_antiguedad('pagar')
--       LA ANTIGÜEDAD por VENCIMIENTO, como QuickBooks: corriente (no ha
--       vencido), 1–30, 31–60, 61–90 y más de 90 días de vencida. Por
--       cobrar: las partidas de 1110 (las mismas de v_cxc_antiguedad de
--       c4), con el vencimiento de la factura emitida por la app (c11) o,
--       si no lo trae, su fecha más los términos de Facturas → Ajustes (de
--       fábrica, «due on receipt»: vence el día de su fecha). La retención
--       (1120) y los anticipos van aparte: no vencen. Por pagar: las
--       partidas de v_cxp_antiguedad de c4, con el vencimiento que c4 les
--       da (los términos del proveedor, o el de la balanza de apertura).
--   conexiones        fn_tablero_conexiones()
--       Las conexiones con el mundo: cada banco por Plaid (c7), Stripe
--       (p1) y la IA contable (c8): conectada, con problemas o apagada.
--   cobros_en_linea   fn_tablero_cobros_en_linea()
--       STRIPE (p1): lo cobrado que falta depositar, los depósitos en
--       camino al banco, los pagos por cuenta de banco que todavía no
--       liquidan y el último depósito que llegó.
--   use_tax           fn_tablero_use_tax()
--       EL USE TAX (el DR-15, de v_dr15_mes de c9): lo del mes en curso y
--       lo del mes pasado, lo que se debe hoy en la 2300.
--   prestamos         fn_tablero_prestamos()
--       LOS PRÉSTAMOS (v_prestamos de c6): lo que se debe de cada uno, su
--       cuota y la próxima (su fecha por el calendario del préstamo, y su
--       reparto en capital e interés por la fórmula de c6).
--   obras             fn_tablero_obras(p_top)
--       LO QUE EL LIBRO SABE DE LAS OBRAS: el WIP del mes que toca (c12:
--       sub y sobre-facturado, lo ganado contra lo facturado) y el costo
--       por obra (c10: ingreso, costo y margen de las obras con más
--       ingreso).
--   «Qué atender» NO está aquí: sigue como hoy, en la pantalla, con los
--   controles de cada capa.
--
-- fn_tablero(p jsonb) — lo que llama la pantalla (una llamada). p (todo
-- opcional):
--   {"tarjetas": ["cobros", "bancos", …],   solo esas (por omisión, todas)
--    "cobros": {"dias": 30}, "facturas": {"dias": 30},
--    "resultados": {"periodo": "mes" | "mes_pasado" | "anio" | "anio_pasado"}
--                  | {"desde": "AAAA-MM-DD", "hasta": "AAAA-MM-DD"},
--    "gastos": {"dias": 30, "top": 5},
--    "caja": {"meses": 12, "proyeccion": 3},
--    "ventas": {"anio": 2026},
--    "obras": {"top": 5},
--    "tope_ms": 4000}
-- Devuelve {ok, hoy, libro: {apertura, desde, texto, …}, capas: {c4: true,
-- c6: true, …}, tarjetas: [las pedidas, en orden], <una clave por
-- tarjeta>, sigue: [las que no alcanzaron], ms}. EL TOPE POR RELOJ (como
-- fn_estados_control de c4): desde la API, pasados «tope_ms» (4 s; 0 = sin
-- tope; desde el SQL Editor no hay), las tarjetas que faltan salen con
-- {ok: false, sigue: true} y su nombre va en «sigue»: la pantalla las
-- vuelve a pedir ({"tarjetas": sigue}). Así una llamada nunca se acerca a
-- los 8 s de la API. Cada tarjeta se puede pedir también por su función.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c4, c6, c9 y c10 sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Todas son SECURITY
--     INVOKER, sin EXECUTE para public, anon ni service_role, con EXECUTE
--     para authenticated y es_dueno() por dentro (fn_tablero_exigir_dueno):
--     leen con la policy de cada tabla (solo el dueño). El equipo recibe
--     42501; anon y service_role no ejecutan nada. Así «permisos» de c2
--     sigue en verde.
--   · fn_tablero_pegado y fn_tablero_precondiciones: sin API (solo el SQL
--     Editor).
--   · No hay vistas: nada de aquí cuelga de una vista de otra capa (que se
--     rehace al volver a pegar su archivo). Lo de las otras capas se lee
--     al vuelo, dentro de cada función, y si su vista o su tabla no está
--     la tarjeta lo dice.
--   · Nada lleva un prefijo que otra capa sella ni de la otra sesión que
--     escribe esta base: aquí todo es fn_tablero_*. es_dueno() no se toca.
--
-- LOS ERRORES CON NOMBRE (ninguno nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_tablero_precondiciones dice qué)
--   22023  entrada mal formada: una clave desconocida, un período o un
--          lado que no existe, un número de días fuera de rango
--   22007  una fecha mal escrita
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres, «lock timeout») la app estaba leyendo mientras se
--          pegaba: no se aplicó nada, se vuelve a pegar
--   Dentro de fn_tablero ninguna tarjeta levanta un error: la que falla lo
--   trae en su clave ({ok: false, motivo, codigo}).
--
-- Lo que este archivo NO toca: c1..c14, s1, p1, es_dueno(), docs/sql, el
-- libro, las tablas de la app, ninguna tabla ni vista de otra capa (las
-- LEE: asientos, asiento_lineas, cuentas, periodos, puente_cuentas,
-- facturas, cobros, cobros_devoluciones, aplicaciones_cobro, proyectos y
-- v_estados_mapeo, v_cxp_antiguedad de c4; y, si están, movimientos_banco,
-- archivos_banco, conciliaciones, v_banco_saldos, v_prestamos y
-- prestamo_cuotas de c6; plaid_conexiones de c7; stripe_config,
-- stripe_pagos, stripe_payouts, stripe_enlaces y v_stripe_pagos de p1;
-- contador_config de c8; v_dr15_mes y v_cierre_estado de c9; v_margen_obra
-- de c10; emision_config, emision_documentos y v_emision_estado de c11;
-- fn_wip_resumen de c12).
--
-- Cómo se instala (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla de 6 filas: la capa, las capas que ve, el libro, una pasada
--      del tablero (cuántas tarjetas contestan y en cuánto), qué falta y el
--      paso siguiente. Si algo de lo que da por hecho falta, para con
--      MX000 y no queda nada.
--   2. SQL Editor → pegar docs/conta/c16-pruebas.sql → sus filas, todas en
--      true (las «omitida» dicen por qué; no es un fallo).
--   3. Publicar la app con la portada nueva (js/conta.js): Contabilidad →
--      Resumen.
--
-- Lo que llama la pantalla (RPC, como el dueño; todas solo leen, y se
-- pueden pedir por GET o por POST):
--   fn_tablero(p jsonb)                                   todas las tarjetas
--   fn_tablero_acciones()
--   fn_tablero_cobros(p_dias int default 30)
--   fn_tablero_bancos()
--   fn_tablero_resultados(p_desde date, p_hasta date, p_periodo text)
--   fn_tablero_gastos(p_dias int default 30, p_top int default 5)
--   fn_tablero_caja(p_meses int default 12, p_proyeccion int default 3, p_calendario jsonb default null)
--   fn_tablero_facturas(p_dias int default 30)
--   fn_tablero_ventas(p_anio int default null)
--   fn_tablero_antiguedad(p_lado text)                     'cobrar' | 'pagar'
--   fn_tablero_conexiones()
--   fn_tablero_cobros_en_linea()
--   fn_tablero_use_tax()
--   fn_tablero_prestamos()
--   fn_tablero_obras(p_top int default 5)
-- Montos en dólares, numeric(14,2); porcentajes con un decimal (nulos
-- cuando no hay contra qué comparar). El jsonb exacto de cada tarjeta está
-- en el comentario de su función (\df+ o obj_description) y en
-- docs/conta/fases/f16.
--
-- ▶ PARA DECIDIR (no frena nada; se dice):
--   · Los términos de las facturas de QuickBooks (las de antes de facturar
--     por la app): hoy se toman los de Facturas → Ajustes («due on
--     receipt»). Si QuickBooks las da a 15 o 30 días, se cambia ahí y la
--     antigüedad se mueve sola.
--   · La proyección de caja pone lo VENCIDO en el mes en curso (como si se
--     cobrara y se pagara ya): es un supuesto, y la tarjeta lo dice.
-- =====================================================================
-- (Lo primero, como en c4, c6, c10 y c12: el pegado espera un candado como
-- mucho medio segundo. Con la app leyendo, para con 55P03 («lock
-- timeout»), no se aplica nada y se vuelve a pegar. Dura lo que dura el
-- pegado.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Lo que este archivo da por hecho (MX000 sin tocar nada) y las guardas
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c16, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_tablero_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_fn    constant text[] := array['fn_tablero_precondiciones', 'fn_tablero_version', 'fn_tablero_exigir_dueno', 'fn_tablero_hoy',
                                   'fn_tablero_dia', 'fn_tablero_mes', 'fn_tablero_mes_largo', 'fn_tablero_rango', 'fn_tablero_usd', 'fn_tablero_pct',
                                   'fn_tablero_no', 'fn_tablero_capas', 'fn_tablero_libro', 'fn_tablero_saldo', 'fn_tablero_mapa',
                                   'fn_tablero_pyg',
                                   'fn_tablero_cxc', 'fn_tablero_cxp', 'fn_tablero_cobrado', 'fn_tablero_por_revisar',
                                   'fn_tablero_acciones', 'fn_tablero_cobros', 'fn_tablero_bancos',
                                   'fn_tablero_resultados', 'fn_tablero_gastos', 'fn_tablero_caja', 'fn_tablero_facturas',
                                   'fn_tablero_ventas', 'fn_tablero_antiguedad', 'fn_tablero_conexiones', 'fn_tablero_cobros_en_linea',
                                   'fn_tablero_use_tax', 'fn_tablero_prestamos', 'fn_tablero_obras', 'fn_tablero', 'fn_tablero_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()',
                             'fn_estados_version()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'facturas', 'cobros',
                             'cobros_devoluciones', 'aplicaciones_cobro', 'puente_cuentas', 'v_estados_mapeo', 'estados_lineas',
                             'v_cxp_antiguedad'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c16 se pega después de c1, c2, c3 y c4 (y de c6, c7, s1, p1, c8, c9, c10, c11, c12, c13 y c14 si se usan), con las '
                  'tablas de la app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- Las versiones de c2 y c4 que van con esta capa (las del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  execute 'select public.fn_estados_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c4-estados.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c4-estados.sql.', v_v);
  end if;
  -- Las columnas que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('asientos', 'id'), ('asientos', 'fecha_contable'), ('asientos', 'anio'), ('asientos', 'tipo'),
                 ('asientos', 'afecta_periodo'), ('asientos', 'camino'), ('asientos', 'reversa_a'), ('asientos', 'cadena_pos'),
                 ('asiento_lineas', 'asiento_id'), ('asiento_lineas', 'orden'), ('asiento_lineas', 'cuenta'),
                 ('asiento_lineas', 'monto'), ('asiento_lineas', 'proyecto_id'), ('asiento_lineas', 'partida_tabla'),
                 ('asiento_lineas', 'partida_id'),
                 ('cuentas', 'codigo'), ('cuentas', 'nombre'),
                 ('periodos', 'periodo'), ('periodos', 'tipo'), ('periodos', 'anio'), ('periodos', 'desde'), ('periodos', 'hasta'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'),
                 ('facturas', 'id'), ('facturas', 'num'), ('facturas', 'fecha'), ('facturas', 'proyecto_id'),
                 ('cobros', 'id'), ('cobros', 'fecha'), ('cobros', 'monto'), ('cobros', 'cuenta'), ('cobros', 'estado'),
                 ('cobros', 'movimiento_id'), ('cobros_devoluciones', 'cobro_id'), ('cobros_devoluciones', 'fecha'),
                 ('cobros_devoluciones', 'monto'), ('aplicaciones_cobro', 'cobro_id'), ('aplicaciones_cobro', 'factura_id'),
                 ('proyectos', 'id'), ('proyectos', 'nombre'), ('proyectos', 'cliente'),
                 ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('v_estados_mapeo', 'cuenta'), ('v_estados_mapeo', 'estado'), ('v_estados_mapeo', 'seccion'),
                 ('v_estados_mapeo', 'etiqueta_es'), ('v_estados_mapeo', 'efectivo'), ('v_estados_mapeo', 'caja'),
                 ('v_estados_mapeo', 'orden'),
                 ('estados_lineas', 'estado'), ('estados_lineas', 'seccion'), ('estados_lineas', 'linea'),
                 ('estados_lineas', 'etiqueta_es'),
                 ('v_cxp_antiguedad', 'periodo'), ('v_cxp_antiguedad', 'nivel'), ('v_cxp_antiguedad', 'tipo'),
                 ('v_cxp_antiguedad', 'proveedor'), ('v_cxp_antiguedad', 'referencia'), ('v_cxp_antiguedad', 'fecha'),
                 ('v_cxp_antiguedad', 'vence'), ('v_cxp_antiguedad', 'tramo'), ('v_cxp_antiguedad', 'por_pagar'),
                 ('v_cxp_antiguedad', 'retencion')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 y c4 pegados?', v_x);
  end if;
  -- Las dos cuentas por cobrar de los puentes (c3): sin ellas no hay partidas que contar.
  if (select count(*) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')) < 2 then
    return 'faltan las cuentas por cobrar de los puentes (cxc y retencion_cxc en puente_cuentas, de c3): vuelve a pegar c3-puentes.sql.';
  end if;
  -- Una función con nombre de c16 que no sea de c16 (otra sesión escribe esta
  -- misma base): «create or replace» la pisaría sin avisar.
  select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_x
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
     and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c16: %';
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c16 y sin ser de c16: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: el tablero lo ve el dueño.';
  end if;
  return null;
end $$;
revoke execute on function public.fn_tablero_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_tablero_precondiciones() is 'c16: lo que falta para pegar c16-tablero.sql (nulo = nada): c1, c2 (marca 2026100201), c3 y c4 (marca 2026100201), las tablas y columnas del libro y de la app que lee, las cuentas por cobrar de los puentes, el SQL Editor, un dueño activo y nada ajeno con nombre de c16.';

do $$
declare
  v text;
begin
  v := public.fn_tablero_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c16-tablero NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4 (c6, c7, s1, p1, c8, c9, c10, c11, c12, c13, c14) y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- La MARCA de esta versión (AAAAMMDDNN), como las de c2, c3, c4 y c6.
create or replace function public.fn_tablero_version() returns bigint
language sql immutable
set search_path = public, pg_temp
as $$ select 2026111301::bigint $$;
revoke execute on function public.fn_tablero_version() from public, anon, service_role;
grant  execute on function public.fn_tablero_version() to authenticated;
comment on function public.fn_tablero_version() is 'c16: la marca de esta versión del tablero (AAAAMMDDNN). La pantalla la puede mirar para saber si la base ya trae la portada nueva.';

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron
-- (current_user no es un rol de la API) pasa. Solo es_dueno(), como c4, c6,
-- c9, c10 y c12: fn_desde_editor no es ejecutable por authenticated.
create or replace function public.fn_tablero_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon', 'service_role') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'El tablero de Contabilidad (los saldos, lo que se cobra, lo que se debe y el resultado) lo ve solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_tablero_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_tablero_exigir_dueno() to authenticated;
comment on function public.fn_tablero_exigir_dueno() is 'c16: la guarda de todo lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';


-- ---------------------------------------------------------------------
-- 1. Lo común: hoy, los nombres de las fechas, el dinero en texto, los
--    porcentajes, «esta tarjeta no», las capas que hay y el libro.
-- ---------------------------------------------------------------------
-- «Hoy», en Miami (el reloj de c2: las pruebas lo fingen ahí).
create or replace function public.fn_tablero_hoy() returns date
language sql stable
set search_path = public, pg_temp
as $$ select public.fn_fecha_miami(now()) $$;
revoke execute on function public.fn_tablero_hoy() from public, anon, service_role;
grant  execute on function public.fn_tablero_hoy() to authenticated;
comment on function public.fn_tablero_hoy() is 'c16: hoy, en Miami (fn_fecha_miami de c2).';

-- Un día en llano: 30-sep-2026.
create or replace function public.fn_tablero_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_dia(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_dia(date) to authenticated;
comment on function public.fn_tablero_dia(date) is 'c16: un día en llano (30-sep-2026).';

-- Un mes en corto, para el eje de una gráfica: oct 2026.
create or replace function public.fn_tablero_mes(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || ' ' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_mes(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_mes(date) to authenticated;
comment on function public.fn_tablero_mes(date) is 'c16: un mes en corto, para el eje de una gráfica (oct 2026).';

-- Un mes entero, para un título: octubre de 2026.
create or replace function public.fn_tablero_mes_largo(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
                'diciembre'])[extract(month from p)::int] || ' de ' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_mes_largo(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_mes_largo(date) to authenticated;
comment on function public.fn_tablero_mes_largo(date) is 'c16: un mes entero, para un título (octubre de 2026).';

-- Un rango de días en llano: «1 a 12 de octubre de 2026» si cae en un mes;
-- si no, «1-oct-2026 a 15-nov-2026».
create or replace function public.fn_tablero_rango(p_desde date, p_hasta date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_desde = p_hasta then public.fn_tablero_dia(p_desde)
              when date_trunc('month', p_desde) = date_trunc('month', p_hasta)
                then extract(day from p_desde)::int || ' a ' || extract(day from p_hasta)::int || ' de ' || public.fn_tablero_mes_largo(p_desde)
              else public.fn_tablero_dia(p_desde) || ' a ' || public.fn_tablero_dia(p_hasta) end
$$;
revoke execute on function public.fn_tablero_rango(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_rango(date, date) to authenticated;
comment on function public.fn_tablero_rango(date, date) is 'c16: un rango de días en llano (1 a 12 de octubre de 2026; 1-oct-2026 a 15-nov-2026).';

-- Dinero en texto, para los mensajes: $1,234.56 (−$1,234.56).
create or replace function public.fn_tablero_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select case when p < 0 then '−' else '' end || '$' || btrim(to_char(abs(round(p, 2)), 'FM999,999,999,990.00')) $$;
revoke execute on function public.fn_tablero_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_tablero_usd(numeric) to authenticated;
comment on function public.fn_tablero_usd(numeric) is 'c16: dinero en texto para los mensajes ($1,234.56).';

-- Un porcentaje con un decimal: cuánto es p_parte de p_base (nulo si la
-- base es cero o falta). Con p_abs, sobre el valor absoluto de la base: la
-- variación contra un período anterior, con el signo de la diferencia (la
-- convención de v_resultados de c4).
create or replace function public.fn_tablero_pct(p_parte numeric, p_base numeric, p_abs boolean default false) returns numeric
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_parte is null or p_base is null or p_base = 0 then null
              else round(100 * p_parte / case when p_abs then abs(p_base) else p_base end, 1) end
$$;
revoke execute on function public.fn_tablero_pct(numeric, numeric, boolean) from public, anon, service_role;
grant  execute on function public.fn_tablero_pct(numeric, numeric, boolean) to authenticated;
comment on function public.fn_tablero_pct(numeric, numeric, boolean) is 'c16: un porcentaje con un decimal (nulo si no hay base); con p_abs, la variación contra un período anterior con el signo de la diferencia, como v_resultados de c4.';

-- «Esta tarjeta no»: por qué, y qué capa falta si es eso.
create or replace function public.fn_tablero_no(p_tarjeta text, p_motivo text, p_falta text default null, p_codigo text default null)
returns jsonb
language sql immutable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object('ok', false, 'tarjeta', p_tarjeta, 'motivo', p_motivo, 'falta', p_falta, 'codigo', p_codigo))
$$;
revoke execute on function public.fn_tablero_no(text, text, text, text) from public, anon, service_role;
grant  execute on function public.fn_tablero_no(text, text, text, text) to authenticated;
comment on function public.fn_tablero_no(text, text, text, text) is 'c16: lo que contesta una tarjeta que no se puede pintar: {ok: false, tarjeta, motivo, falta (la capa que no está), codigo (el del error)}.';

-- Las capas que esta base tiene, por lo que el tablero lee de cada una.
create or replace function public.fn_tablero_capas() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'c4',  to_regclass('public.v_estados_mapeo') is not null and to_regclass('public.v_cxp_antiguedad') is not null,
    'c6',  to_regclass('public.v_banco_saldos') is not null and to_regclass('public.movimientos_banco') is not null
           and to_regclass('public.conciliaciones') is not null and to_regclass('public.archivos_banco') is not null,
    'c6_prestamos', to_regclass('public.v_prestamos') is not null and to_regclass('public.prestamos') is not null
           and to_regclass('public.prestamo_cuotas') is not null,
    'c7',  to_regclass('public.plaid_conexiones') is not null,
    'p1',  to_regclass('public.stripe_config') is not null and to_regclass('public.stripe_pagos') is not null
           and to_regclass('public.stripe_payouts') is not null and to_regclass('public.v_stripe_pagos') is not null
           and to_regclass('public.stripe_enlaces') is not null,
    'c8',  to_regclass('public.contador_config') is not null,
    'c9',  to_regclass('public.v_dr15_mes') is not null and to_regclass('public.v_cierre_estado') is not null,
    'c10', to_regclass('public.v_margen_obra') is not null,
    'c11', to_regclass('public.emision_config') is not null and to_regclass('public.emision_documentos') is not null
           and to_regclass('public.v_emision_estado') is not null,
    'c12', to_regprocedure('public.fn_wip_resumen(text)') is not null,
    'c13', to_regprocedure('public.fn_cedula_resumen(date)') is not null)
$$;
revoke execute on function public.fn_tablero_capas() from public, anon, service_role;
grant  execute on function public.fn_tablero_capas() to authenticated;
comment on function public.fn_tablero_capas() is 'c16: las capas que esta base tiene, por lo que el tablero lee de cada una ({c4, c6, c6_prestamos, c7, p1, c8, c9, c10, c11, c12, c13}: verdadero o falso).';

-- EL LIBRO: desde cuándo hay libro. La apertura (30-sep-2026) y el primer
-- día (el siguiente); sin período de apertura, el primer período que haya.
-- Es la misma regla de v_resultados (c4), de c10 y de c12.
create or replace function public.fn_tablero_libro() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_ap    date;
  v_desde date;
  v_en    boolean;
begin
  perform fn_tablero_exigir_dueno();
  select pa.hasta into v_ap from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1;
  v_desde := coalesce(v_ap + 1, (select min(pm.desde) from periodos pm));
  v_en := exists (select 1 from asientos a
                   where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'));
  return jsonb_build_object(
    'apertura', v_ap, 'desde', v_desde, 'primer_mes', to_char(v_desde, 'YYYY-MM'), 'apertura_en_el_libro', v_en,
    'texto', case when v_desde is null then 'El libro no tiene períodos todavía.'
                  when v_ap is null then format('El libro de la app empieza el %s: lo de antes vive en QuickBooks.', fn_tablero_dia(v_desde))
                  when v_en then format('El libro de la app empieza con la apertura al %s: lo de antes vive en QuickBooks.', fn_tablero_dia(v_ap))
                  else format('El libro de la app empieza el %s, pero la apertura al %s todavía no está en el libro: los saldos de '
                              'antes (el banco, lo que se debía y lo que debían) no están contados.',
                              fn_tablero_dia(v_desde), fn_tablero_dia(v_ap)) end);
end $$;
revoke execute on function public.fn_tablero_libro() from public, anon, service_role;
grant  execute on function public.fn_tablero_libro() to authenticated;
comment on function public.fn_tablero_libro() is 'c16: desde cuándo hay libro: {apertura (el día de la apertura), desde (el primer día del libro: el siguiente), primer_mes (AAAA-MM), apertura_en_el_libro (si su asiento ya está), texto (en llano: «el libro empieza con la apertura al 30-sep-2026: lo de antes vive en QuickBooks»)}. La regla de v_resultados (c4). Solo el dueño.';

-- El saldo de una lista de cuentas hasta un día (debe − haber, como el
-- libro): el cuadre barato de cada tarjeta contra el mayor.
create or replace function public.fn_tablero_saldo(p_cuentas text[], p_hasta date default null) returns numeric
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto), 0)::numeric(14,2)
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
   where l.cuenta = any (p_cuentas) and (p_hasta is null or a.fecha_contable <= p_hasta)
$$;
revoke execute on function public.fn_tablero_saldo(text[], date) from public, anon, service_role;
grant  execute on function public.fn_tablero_saldo(text[], date) to authenticated;
comment on function public.fn_tablero_saldo(text[], date) is 'c16: el saldo en el libro (debe − haber) de una lista de cuentas hasta un día (sin día, todo): contra él cuadra cada tarjeta. Lee con la policy del libro: a quien no es el dueño le da 0.';


-- EL MAPEO de cada cuenta a su estado financiero (c4): dónde sale (estado,
-- sección, renglón), su etiqueta, si es efectivo y si es la caja chica. Es
-- v_estados_mapeo de c4, leída por el camino corto: si cada cuenta del plan
-- tiene su fila guardada en estados_mapeo (lo normal: el control de c4 dice
-- en rojo la que no), la tabla lo dice todo y se lee directa; si a alguna le
-- falta, manda la vista (que le propone su sitio). El resultado es el mismo;
-- la tabla cuesta la vigésima parte.
create or replace function public.fn_tablero_mapa()
returns table (cuenta text, nombre text, estado text, seccion text, linea text, etiqueta text, orden int, efectivo boolean, caja boolean)
language plpgsql stable
rows 120
set search_path = public, pg_temp
as $$
begin
  if to_regclass('public.estados_mapeo') is not null
     and not exists (select 1 from cuentas c where not exists (select 1 from estados_mapeo m where m.cuenta = c.codigo)) then
    return query
    select m.cuenta, c.nombre, m.estado, m.seccion, m.linea, coalesce(m.etiqueta_es, c.nombre), m.orden, m.efectivo, m.caja
      from estados_mapeo m
      join cuentas c on c.codigo = m.cuenta;
  else
    return query
    select v.cuenta, v.cuenta_nombre, v.estado, v.seccion, v.linea, v.etiqueta_es, v.orden, v.efectivo, v.caja
      from v_estados_mapeo v;
  end if;
end $$;
revoke execute on function public.fn_tablero_mapa() from public, anon, service_role;
grant  execute on function public.fn_tablero_mapa() to authenticated;
comment on function public.fn_tablero_mapa() is 'c16: el mapeo de cada cuenta a su estado financiero, el de v_estados_mapeo de c4 (cuenta, nombre, estado, seccion, linea, etiqueta, orden, efectivo, caja), leído de la tabla estados_mapeo cuando cada cuenta tiene su fila y de la vista cuando a alguna le falta. Lee con la policy de c4: a quien no es el dueño no le da nada.';


-- ---------------------------------------------------------------------
-- 2. Las piezas que comparten varias tarjetas: el resultado de un rango, las
--    partidas por cobrar y por pagar con su vencimiento, lo cobrado y lo que
--    espera en la Bandeja.
-- ---------------------------------------------------------------------
-- EL RESULTADO DE UN RANGO de fechas, del libro: las cinco secciones del
-- estado de resultados de c4 (el mapeo de cada cuenta lo dice
-- fn_tablero_mapa) y las tres utilidades. Cifras con el signo del estado
-- (ingresos y costos en positivo; un resultado negativo es pérdida).
-- Cuenta lo mismo que v_resultados: cada línea en el ejercicio de su fecha;
-- un ajuste del CPA que corrige OTRO año no es de estos días (va al año
-- que corrige) y se dice aparte (ajustes_otro_ejercicio).
create or replace function public.fn_tablero_pyg(p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  select jsonb_build_object(
           'ingresos', s.i, 'costo', s.c, 'gastos', s.g, 'otros_ingresos', s.oi, 'otros_gastos', s.og,
           'utilidad_bruta', (s.i - s.c)::numeric(14,2), 'utilidad_operacion', (s.i - s.c - s.g)::numeric(14,2),
           'resultado', (s.i - s.c - s.g + s.oi - s.og)::numeric(14,2),
           'entra', (s.i + s.oi)::numeric(14,2), 'sale', (s.c + s.g + s.og)::numeric(14,2),
           'asientos', s.n, 'ajustes_otro_ejercicio', s.aj)
    into v
    from (select coalesce(-sum(l.monto) filter (where x.suyo and m.seccion = 'ingresos'), 0)::numeric(14,2)       as i,
                 coalesce(sum(l.monto)  filter (where x.suyo and m.seccion = 'costo'), 0)::numeric(14,2)          as c,
                 coalesce(sum(l.monto)  filter (where x.suyo and m.seccion = 'gastos'), 0)::numeric(14,2)         as g,
                 coalesce(-sum(l.monto) filter (where x.suyo and m.seccion = 'otros_ingresos'), 0)::numeric(14,2) as oi,
                 coalesce(sum(l.monto)  filter (where x.suyo and m.seccion = 'otros_gastos'), 0)::numeric(14,2)   as og,
                 count(distinct l.asiento_id) filter (where x.suyo)                                               as n,
                 coalesce(-sum(l.monto) filter (where not x.suyo), 0)::numeric(14,2)                              as aj
            from asiento_lineas l
            join asientos a on a.id = l.asiento_id
            join fn_tablero_mapa() m on m.cuenta = l.cuenta
           cross join lateral (select a.afecta_periodo is null
                                      or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio as suyo) x
           where m.estado = 'resultados' and a.fecha_contable >= p_desde and a.fecha_contable <= p_hasta) s;
  return v;
end $$;
revoke execute on function public.fn_tablero_pyg(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_pyg(date, date) to authenticated;
comment on function public.fn_tablero_pyg(date, date) is 'c16: el resultado de un rango de fechas, del libro con el mapeo de c4: {ingresos, costo, gastos, otros_ingresos, otros_gastos, utilidad_bruta, utilidad_operacion, resultado, entra (ingresos + otros ingresos), sale (costo + gastos + otros gastos), asientos, ajustes_otro_ejercicio (lo de un ajuste del CPA que corrige otro año: no se cuenta en estos días)}. Lo mismo que v_resultados de c4, al centavo. Lee con la policy del libro.';

-- LAS PARTIDAS POR COBRAR de hoy, una por una, con su VENCIMIENTO. Las
-- mismas partidas de v_cxc_antiguedad (c4): las líneas de 1110 y 1120
-- agrupadas por su partida (la factura, el cobro que dejó un anticipo) o,
-- sin partida, por su obra; lo que va sin factura se fecha por lo más viejo
-- que sigue sin cobrar (FIFO). Lo que aquí se añade es CUÁNDO VENCE:
--   · la factura emitida por la app (c11) trae su vencimiento (se congeló
--     al emitirla);
--   · la que no (las de QuickBooks, o sin c11), su fecha más los términos
--     de Facturas → Ajustes (emision_config.terminos_dias; de fábrica 0:
--     «due on receipt», vence el día de su fecha);
--   · lo que va sin factura, el día de su fecha.
-- Una partida vence el día que dice y está VENCIDA desde el día siguiente.
-- tramo: corriente | d1_30 | d31_60 | d61_90 | d90_mas (por días de
-- vencida), o retencion (solo queda la retención, que no vence por
-- términos: se cobra al terminar la obra), anticipo (el dinero que un
-- cliente adelantó) o a_favor (un saldo a favor del cliente sin factura).
create or replace function public.fn_tablero_cxc(p_hoy date default null)
returns table (tipo text, partida_tabla text, partida_id text, factura_id bigint, factura_num text, proyecto_id text, obra text,
               cliente text, fecha date, vence date, vence_de text, por_cobrar numeric, retencion numeric, dias_vencida int, tramo text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := coalesce(p_hoy, fn_tablero_hoy());
  v_cxc  text;
  v_ret  text;
  v_dias int := 0;
  v_c11  boolean := to_regclass('public.emision_config') is not null and to_regclass('public.emision_documentos') is not null;
begin
  perform fn_tablero_exigir_dueno();
  select pc.cuenta into v_cxc from puente_cuentas pc where pc.rol = 'cxc';
  select pc.cuenta into v_ret from puente_cuentas pc where pc.rol = 'retencion_cxc';
  if v_c11 then
    execute 'select coalesce((select c.terminos_dias from public.emision_config c where c.id = 1), 0)' into v_dias;
  end if;
  return query execute format($q$
    with l as materialized (
      select a.fecha_contable as fecha, li.monto, li.proyecto_id, li.partida_tabla, li.partida_id, li.cuenta = $3 as es_ret,
             a.cadena_pos, li.orden
        from public.asiento_lineas li
        join public.asientos a on a.id = li.asiento_id
       where li.cuenta in ($2, $3) and a.fecha_contable <= $1
    ), fs as materialized (
      -- (FIFO de lo que va sin factura, por obra: la fecha de lo más viejo que sigue sin cobrar)
      select y.obra, min(y.fecha) as fecha
        from (select l.proyecto_id as obra, l.fecha,
                     sum(l.monto) over (partition by l.proyecto_id order by l.fecha, l.cadena_pos, l.orden
                                        rows between unbounded preceding and current row) as acum
                from l where l.partida_tabla is null and not l.es_ret and l.monto > 0) y
        left join (select l.proyecto_id as obra, -sum(l.monto) as abonado
                     from l where l.partida_tabla is null and not l.es_ret and l.monto < 0 group by l.proyecto_id) ab
               on ab.obra is not distinct from y.obra
       where y.acum > coalesce(ab.abonado, 0)
       group by y.obra
    ), g as materialized (
      select l.partida_tabla, l.partida_id, case when l.partida_tabla is null then l.proyecto_id end as obra_sin_partida,
             min(l.proyecto_id) as proyecto_id,
             coalesce(sum(l.monto) filter (where not l.es_ret), 0) as por_cobrar,
             coalesce(sum(l.monto) filter (where l.es_ret), 0) as retencion,
             min(l.fecha) as primera
        from l
       group by l.partida_tabla, l.partida_id, case when l.partida_tabla is null then l.proyecto_id end
      having coalesce(sum(l.monto) filter (where not l.es_ret), 0) <> 0 or coalesce(sum(l.monto) filter (where l.es_ret), 0) <> 0
    ), x as (
      select case when g.partida_tabla = 'facturas' then 'factura' when g.partida_tabla = 'cobros' then 'anticipo'
                  when g.partida_tabla is null then 'sin_partida' else 'otra' end as tipo,
             g.partida_tabla, g.partida_id, f.id as factura_id, f.num as factura_num,
             g.proyecto_id, g.por_cobrar, g.retencion,
             coalesce(case when g.partida_tabla = 'facturas' then f.fecha
                           when g.partida_tabla = 'cobros' then co.fecha
                           when g.partida_tabla is null and g.por_cobrar > 0 then fs.fecha end, g.primera) as fecha
        from g
        left join public.facturas f on g.partida_tabla = 'facturas'
              and f.id = case when g.partida_tabla = 'facturas' and g.partida_id ~ '^-?[0-9]{1,18}$' then g.partida_id::bigint end
        left join public.cobros co on g.partida_tabla = 'cobros'
              and co.id = case when g.partida_tabla = 'cobros' and g.partida_id ~ '^[0-9a-f-]{36}$' then g.partida_id::uuid end
        left join fs on g.partida_tabla is null and fs.obra is not distinct from g.obra_sin_partida
    ), v as (
      select x.*,
             case when x.partida_tabla = 'cobros' or x.por_cobrar <= 0 then null::date
                  when x.tipo = 'factura' then coalesce(%1$s, x.fecha + $4)
                  else x.fecha end as vence,
             case when x.partida_tabla = 'cobros' or x.por_cobrar <= 0 then null::text
                  when x.tipo = 'factura' and %1$s is not null then 'factura'
                  when x.tipo = 'factura' then 'terminos'
                  else 'fecha' end as vence_de
        from x %2$s
    )
    select v.tipo, v.partida_tabla, v.partida_id, v.factura_id, v.factura_num, v.proyecto_id, pr.nombre, pr.cliente,
           v.fecha, v.vence, v.vence_de, v.por_cobrar::numeric(14,2), v.retencion::numeric(14,2),
           ($1 - v.vence)::int as dias_vencida,
           case when v.tipo = 'anticipo' then 'anticipo'
                when v.por_cobrar < 0 then 'a_favor'
                when v.por_cobrar = 0 then 'retencion'
                when $1 - v.vence <= 0 then 'corriente'
                when $1 - v.vence <= 30 then 'd1_30'
                when $1 - v.vence <= 60 then 'd31_60'
                when $1 - v.vence <= 90 then 'd61_90'
                else 'd90_mas' end as tramo
      from v
      left join public.proyectos pr on pr.id = v.proyecto_id
  $q$, case when v_c11 then 'd.vence' else 'null::date' end,
       case when v_c11 then 'left join public.emision_documentos d on d.factura_id = x.factura_id and d.vence is not null' else '' end)
  using v_hoy, v_cxc, v_ret, v_dias;
end $$;
revoke execute on function public.fn_tablero_cxc(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_cxc(date) to authenticated;
comment on function public.fn_tablero_cxc(date) is 'c16: las partidas por cobrar de hoy (o de ese día), una por una, las mismas de v_cxc_antiguedad de c4, con su vencimiento: tipo (factura | anticipo | sin_partida | otra), la factura y su obra, fecha, vence y de dónde sale (vence_de: factura = el de la factura emitida por la app; terminos = su fecha más los términos de Facturas → Ajustes; fecha = el día de su fecha), por_cobrar (1110), retencion (1120), dias_vencida y tramo (corriente | d1_30 | d31_60 | d61_90 | d90_mas | retencion | anticipo | a_favor). Solo lee. Solo el dueño.';

-- LAS PARTIDAS POR PAGAR de hoy, una por una: las de v_cxp_antiguedad de c4
-- (cada papel con su proveedor; lo de la apertura, factura por factura; lo
-- pagado sin partida salda lo más viejo del mismo proveedor), con el
-- vencimiento que c4 les da (los términos del proveedor, o el de la balanza
-- de apertura). Sin vencimiento conocido, vence el día de su fecha
-- (vence_de = fecha). tramo, como en lo por cobrar; sin_fecha = lo de la
-- apertura que no trae ni su fecha.
create or replace function public.fn_tablero_cxp()
returns table (tipo text, partida_tabla text, partida_id text, proveedor text, referencia text, fecha date, vence date,
               vence_de text, por_pagar numeric, retencion numeric, dias_vencida int, tramo text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
begin
  perform fn_tablero_exigir_dueno();
  return query
  select x.tipo, x.partida_tabla, x.partida_id, x.proveedor, x.referencia, x.fecha,
         case when x.por_pagar > 0 and x.tramo <> 'apertura' then coalesce(x.vence, x.fecha) end as vence,
         case when x.por_pagar <= 0 or x.tramo = 'apertura' then null
              when x.vence is not null then 'terminos' else 'fecha' end as vence_de,
         x.por_pagar, x.retencion,
         case when x.por_pagar > 0 and x.tramo <> 'apertura' then (v_hoy - coalesce(x.vence, x.fecha))::int end as dias_vencida,
         case when x.por_pagar < 0 then 'a_favor'
              when x.por_pagar = 0 then 'retencion'
              when x.tramo = 'apertura' or coalesce(x.vence, x.fecha) is null then 'sin_fecha'
              when v_hoy - coalesce(x.vence, x.fecha) <= 0 then 'corriente'
              when v_hoy - coalesce(x.vence, x.fecha) <= 30 then 'd1_30'
              when v_hoy - coalesce(x.vence, x.fecha) <= 60 then 'd31_60'
              when v_hoy - coalesce(x.vence, x.fecha) <= 90 then 'd61_90'
              else 'd90_mas' end as tramo
    from v_cxp_antiguedad x
   where x.periodo = 'hoy' and x.nivel = 'partida';
end $$;
revoke execute on function public.fn_tablero_cxp() from public, anon, service_role;
grant  execute on function public.fn_tablero_cxp() to authenticated;
comment on function public.fn_tablero_cxp() is 'c16: las partidas por pagar de hoy, una por una, de v_cxp_antiguedad de c4, con su vencimiento: tipo, el papel, proveedor, referencia, fecha, vence y de dónde sale (vence_de: terminos = los del proveedor o el de la balanza de apertura; fecha = sin vencimiento conocido, el día de su fecha), por_pagar (2010), retencion (2020), dias_vencida y tramo (corriente | d1_30 | d31_60 | d61_90 | d90_mas | sin_fecha | retencion | a_favor). Solo lee. Solo el dueño.';

-- LO COBRADO en los últimos N días y lo que de eso ya está en el banco. Un
-- cobro es un papel de c3 (cobros): cuenta el vigente, con su fecha en la
-- ventana, que no se devolvió (un cheque devuelto no se cobró: va aparte).
-- DEPOSITADO es:
--   · el cobro a una cuenta de banco que ya casó con su movimiento del
--     banco (c6: cobros.movimiento_id); el que no, sigue «sin casar» (el
--     cheque en la mano, o el depósito que el banco todavía no trae);
--   · el cobro de Stripe (a la cuenta puente de p1), por lo que su
--     depósito ya liquidó (lo que falta sigue «en Stripe»);
--   · lo que entró a la caja chica no está en el banco («en caja»).
-- Sin el banco (c6) no se sabe qué está depositado: sale nulo, con su nota.
create or replace function public.fn_tablero_cobrado(p_dias int default 30) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_dias   int := coalesce(p_dias, 30);
  v_desde  date;
  v_c6     boolean := to_regclass('public.movimientos_banco') is not null;
  v_p1     boolean := to_regclass('public.stripe_config') is not null and to_regclass('public.stripe_pagos') is not null
                      and to_regclass('public.v_stripe_pagos') is not null;
  v_puente text;
  v_falta  jsonb := '{}'::jsonb;   -- por cobro de Stripe: lo que falta depositar
  v_sabe   boolean;
  r        record;
begin
  perform fn_tablero_exigir_dueno();
  if v_dias < 1 or v_dias > 366 then
    raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_dias);
  end if;
  v_desde := v_hoy - (v_dias - 1);
  if v_p1 then
    execute 'select c.cuenta_puente from public.stripe_config c where c.id = 1' into v_puente;
    execute 'select coalesce(jsonb_object_agg(s.cobro_id::text, v.falta_depositar), ''{}''::jsonb)
               from public.v_stripe_pagos v join public.stripe_pagos s on s.id = v.id
              where s.cobro_id is not null' into v_falta;
  end if;
  select count(*) as n, coalesce(sum(k.monto), 0)::numeric(14,2) as monto,
         count(*) filter (where k.depositado = k.monto) as n_dep,
         coalesce(sum(k.depositado), 0)::numeric(14,2) as dep,
         count(*) filter (where k.clase = 'banco') as n_banco,
         count(*) filter (where k.clase = 'banco' and k.depositado = 0) as n_sin,
         coalesce(sum(k.monto) filter (where k.clase = 'banco' and k.depositado = 0), 0)::numeric(14,2) as sin,
         count(*) filter (where k.clase = 'stripe' and k.depositado < k.monto) as n_stripe,
         coalesce(sum(k.monto - k.depositado) filter (where k.clase = 'stripe'), 0)::numeric(14,2) as en_stripe,
         count(*) filter (where k.clase = 'caja') as n_caja,
         coalesce(sum(k.monto) filter (where k.clase = 'caja'), 0)::numeric(14,2) as en_caja,
         (select count(distinct ap.factura_id) from aplicaciones_cobro ap
           where ap.factura_id is not null and ap.cobro_id = any (coalesce(array_agg(k.id), '{}'::uuid[]))) as facturas
    into r
    from (select c.id, c.monto,
                 case when c.cuenta = v_puente then 'stripe' when coalesce(m.caja, false) then 'caja' else 'banco' end as clase,
                 (case when c.cuenta = v_puente
                         then least(c.monto, greatest(c.monto - coalesce((v_falta ->> c.id::text)::numeric, c.monto), 0))
                       when coalesce(m.caja, false) then 0
                       when c.movimiento_id is not null then c.monto
                       else 0 end)::numeric(14,2) as depositado
            from cobros c
            left join fn_tablero_mapa() m on m.cuenta = c.cuenta
           where c.estado = 'vigente' and c.fecha between v_desde and v_hoy
             and not exists (select 1 from cobros_devoluciones d where d.cobro_id = c.id)) k;
  -- (sin el banco no se sabe si un cobro a una cuenta de banco ya está depositado)
  v_sabe := v_c6 or r.n_banco = 0;
  return jsonb_build_object(
    'dias', v_dias, 'desde', v_desde, 'hasta', v_hoy,
    'monto', r.monto, 'n', r.n, 'facturas', r.facturas,
    'depositado', case when v_sabe then jsonb_build_object('monto', r.dep, 'n', r.n_dep) end,
    'sin_depositar', case when v_sabe
                          then jsonb_build_object('monto', (r.monto - r.dep)::numeric(14,2), 'n', r.n - r.n_dep,
                                                  'sin_casar', jsonb_build_object('monto', r.sin, 'n', r.n_sin),
                                                  'en_stripe', jsonb_build_object('monto', r.en_stripe, 'n', r.n_stripe),
                                                  'en_caja', jsonb_build_object('monto', r.en_caja, 'n', r.n_caja)) end,
    'devuelto', (select jsonb_build_object('monto', coalesce(sum(d.monto), 0)::numeric(14,2), 'n', count(*))
                   from cobros_devoluciones d where d.fecha between v_desde and v_hoy),
    'nota', case when not v_sabe then 'Sin el banco (c6) en esta base no se sabe qué cobros ya están depositados.' end,
    'fuente', 'los cobros vigentes de esos días (c3), sin los devueltos; depositado = casado con su movimiento del banco (c6) o ya '
              'liquidado por Stripe (p1)');
end $$;
revoke execute on function public.fn_tablero_cobrado(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobrado(int) to authenticated;
comment on function public.fn_tablero_cobrado(int) is 'c16: lo cobrado en los últimos N días (hoy y los N − 1 anteriores) y lo que de eso ya está en el banco: {dias, desde, hasta, monto, n (cobros), facturas (cuántas facturas tocaron), depositado: {monto, n (cobros depositados enteros)}, sin_depositar: {monto, n, sin_casar: {monto, n}, en_stripe: {monto, n}, en_caja: {monto, n}}, devuelto: {monto, n} (cheques devueltos en esos días; no cuentan como cobrados), nota, fuente}. depositado y sin_depositar salen nulos si no hay banco (c6) y hay cobros a una cuenta de banco. Solo lee. Solo el dueño.';

-- LO QUE ESPERA EN LA BANDEJA (c6) con fecha en un rango: los movimientos
-- del banco y de las tarjetas que todavía no están casados ni clasificados.
-- Un CARGO que espera puede ser un gasto que todavía no está en el libro (o
-- un ticket que ya entró y falta casar); un DEPÓSITO que espera es un cobro
-- (nunca un ingreso: el ingreso lo pone la factura). Nulo sin c6.
create or replace function public.fn_tablero_por_revisar(p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.movimientos_banco') is null then
    return null;
  end if;
  execute $q$
    select jsonb_build_object(
             'n', count(*),
             'cargos', jsonb_build_object('n', count(*) filter (where m.monto < 0),
                                          'monto', coalesce(-sum(m.monto) filter (where m.monto < 0), 0)::numeric(14,2)),
             'depositos', jsonb_build_object('n', count(*) filter (where m.monto > 0),
                                             'monto', coalesce(sum(m.monto) filter (where m.monto > 0), 0)::numeric(14,2)),
             'mas_viejo', min(m.fecha),
             'nota', 'movimientos del banco y de las tarjetas con fecha de este período que esperan en la Bandeja: un cargo puede ser '
                     'un gasto que todavía no está en el libro (o un ticket que ya entró y falta casar); un depósito es un cobro, no '
                     'un ingreso',
             'ir', jsonb_build_object('pagina', 'bandeja'))
      from public.movimientos_banco m
     where m.estado = 'pendiente' and ($1::date is null or m.fecha >= $1) and ($2::date is null or m.fecha <= $2)
  $q$ into v using p_desde, p_hasta;
  return v;
end $$;
revoke execute on function public.fn_tablero_por_revisar(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_por_revisar(date, date) to authenticated;
comment on function public.fn_tablero_por_revisar(date, date) is 'c16: lo que espera en la Bandeja (c6) con fecha en un rango (sin fechas, todo): {n, cargos: {n, monto}, depositos: {n, monto}, mas_viejo, nota, ir}. Un cargo que espera puede ser un gasto que falta en el libro; un depósito es un cobro, no un ingreso. Nulo sin c6. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 3. LAS TARJETAS, una función por tarjeta. Cada una contesta un jsonb con
--    «ok», su nombre, su corte y todo lo que enseña ya calculado. Si la
--    capa de la que sale no está, lo dice (fn_tablero_no) y no es un error.
-- ---------------------------------------------------------------------

-- 3.1 · ACCIONES RÁPIDAS: lo que cambia de cada una (la etiqueta y el
-- icono son de la pantalla).
create or replace function public.fn_tablero_acciones() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  v_l     jsonb := '[]'::jsonb;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  -- crear una factura (c11): por dónde se factura hoy
  if (v_capas ->> 'c11')::boolean then
    select e.camino, e.texto, e.borradores, e.puede_emitir, e.sin_mandar, e.sin_pdf into r from v_emision_estado e;
    v_l := v_l || jsonb_build_object(
      'clave', 'factura', 'texto', 'Crear una factura', 'disponible', true,
      'n', coalesce(r.borradores, 0),
      'detalle', case when r.camino is null then 'Facturas no tiene sus ajustes todavía.'
                      when r.camino = 'app' and coalesce(r.borradores, 0) > 0
                        then format('%s borrador%s por emitir', r.borradores, case when r.borradores = 1 then '' else 'es' end)
                      when r.camino = 'app' then 'se emite desde la app'
                      else r.texto end,
      'camino', r.camino,
      'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'obras'));
  else
    v_l := v_l || jsonb_build_object('clave', 'factura', 'texto', 'Crear una factura', 'disponible', false, 'falta', 'c11',
                                     'detalle', 'Facturas (c11) no está en esta base.');
  end if;
  -- la Bandeja y Conciliar (c6)
  if (v_capas ->> 'c6')::boolean then
    select count(*) as n, min(m.fecha) as viejo into r from movimientos_banco m where m.estado = 'pendiente';
    v_l := v_l || jsonb_build_object(
      'clave', 'bandeja', 'texto', 'Bandeja', 'disponible', true, 'n', r.n,
      'detalle', case when r.n = 0 then 'nada espera'
                      else format('%s movimiento%s por revisar, el más viejo del %s', r.n, case when r.n = 1 then '' else 's' end,
                                  fn_tablero_dia(r.viejo)) end,
      'mas_viejo', r.viejo, 'dias', v_hoy - r.viejo, 'alarma', coalesce(v_hoy - r.viejo > 30, false),
      'ir', jsonb_build_object('pagina', 'bandeja'));
    select count(*) as cuentas, count(*) filter (where s.ultima_confirmada is null) as nunca, min(s.ultima_confirmada) as vieja,
           max(s.dias_sin_conciliar) as dias
      into r
      from v_banco_saldos s
     where s.activa and (s.ultimo_archivo_id is not null or s.ultima_conciliacion_id is not null);
    v_l := v_l || jsonb_build_object(
      'clave', 'conciliar', 'texto', 'Conciliar', 'disponible', true, 'n', r.cuentas,
      'detalle', case when r.cuentas = 0 then 'ninguna cuenta con archivo del banco todavía'
                      when r.nunca > 0 then format('%s cuenta%s sin ninguna conciliación confirmada', r.nunca, case when r.nunca = 1 then '' else 's' end)
                      else format('la más atrasada, confirmada al %s', fn_tablero_dia(r.vieja)) end,
      'dias', r.dias, 'alarma', coalesce(r.dias > 45, false),
      'ir', jsonb_build_object('pagina', 'conciliar'));
  else
    v_l := v_l || jsonb_build_object('clave', 'bandeja', 'texto', 'Bandeja', 'disponible', false, 'falta', 'c6',
                                     'detalle', 'El banco (c6) no está en esta base.')
               || jsonb_build_object('clave', 'conciliar', 'texto', 'Conciliar', 'disponible', false, 'falta', 'c6',
                                     'detalle', 'El banco (c6) no está en esta base.');
  end if;
  -- pedir un pago en línea (p1)
  if (v_capas ->> 'p1')::boolean then
    select (select count(*) from stripe_enlaces e where e.estado = 'activo') as n into r;
    v_l := v_l || jsonb_build_object(
      'clave', 'pago', 'texto', 'Pedir un pago en línea', 'disponible', true, 'n', r.n,
      'detalle', case when r.n = 0 then 'ningún enlace de pago activo'
                      else format('%s enlace%s de pago activo%s', r.n, case when r.n = 1 then '' else 's' end, case when r.n = 1 then '' else 's' end) end,
      'ir', jsonb_build_object('pagina', 'cobros'));
  else
    v_l := v_l || jsonb_build_object('clave', 'pago', 'texto', 'Pedir un pago en línea', 'disponible', false, 'falta', 'p1',
                                     'detalle', 'Los cobros en línea (p1) no están en esta base.');
  end if;
  -- cerrar el mes (c9): el período que toca
  if (v_capas ->> 'c9')::boolean then
    select e.periodo, e.nombre, e.terminado, e.detienen, e.avisos, e.revisado_el, e.hasta into r
      from v_cierre_estado e where e.siguiente order by e.desde limit 1;
    v_l := v_l || jsonb_build_object(
      'clave', 'cierre', 'texto', 'Cerrar el mes', 'disponible', true, 'n', coalesce(r.detienen, 0),
      'detalle', case when r.periodo is null then 'no hay ningún período por cerrar'
                      when not r.terminado then format('toca %s, que termina el %s', r.nombre, fn_tablero_dia(r.hasta))
                      when r.revisado_el is null then format('toca %s: todavía sin revisar', r.nombre)
                      when coalesce(r.detienen, 0) = 0 then format('toca %s: nada por resolver, se puede cerrar', r.nombre)
                      else format('toca %s: %s cosa%s por resolver antes de cerrar', r.nombre, r.detienen,
                                  case when r.detienen = 1 then '' else 's' end) end,
      'periodo', r.periodo, 'terminado', r.terminado,
      'ir', jsonb_strip_nulls(jsonb_build_object('pagina', 'cierre', 'sub', 'cierre', 'periodo', r.periodo)));
  else
    v_l := v_l || jsonb_build_object('clave', 'cierre', 'texto', 'Cerrar el mes', 'disponible', false, 'falta', 'c9',
                                     'detalle', 'El cierre del mes (c9) no está en esta base.');
  end if;
  -- los estados financieros (c4)
  v_l := v_l || jsonb_build_object('clave', 'estados', 'texto', 'Estados financieros', 'disponible', true,
                                   'detalle', 'resultados, balance, balanza y flujo de caja',
                                   'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados'));
  return jsonb_build_object('ok', true, 'tarjeta', 'acciones', 'corte', v_hoy, 'lista', v_l,
                            'fuente', 'Facturas (c11), la Bandeja y las conciliaciones (c6), los enlaces de pago (p1) y el cierre (c9)');
end $$;
revoke execute on function public.fn_tablero_acciones() from public, anon, service_role;
grant  execute on function public.fn_tablero_acciones() to authenticated;
comment on function public.fn_tablero_acciones() is 'c16: la fila de acciones rápidas del tablero: {ok, tarjeta, corte, lista: [{clave (factura | bandeja | conciliar | pago | cierre | estados), texto, disponible, n (borradores, movimientos por revisar, cuentas, enlaces activos, cosas que detienen el cierre), detalle (en llano), alarma?, ir: {pagina, sub?, periodo?}, falta? (la capa que no está)}], fuente}. Solo lee. Solo el dueño.';

-- 3.2 · EL EMBUDO DE COBRO: por cobrar → cobrado en los últimos N días →
-- depositado.
create or replace function public.fn_tablero_cobros(p_dias int default 30) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_c     jsonb;
  v_libro numeric;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  v_c := fn_tablero_cobrado(p_dias);
  select coalesce(sum(x.por_cobrar) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as monto,
         count(*) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')) as n,
         count(*) filter (where x.tipo = 'factura' and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')) as facturas,
         coalesce(sum(x.por_cobrar) filter (where x.tipo <> 'factura' and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as sin_factura,
         count(*) filter (where x.tipo <> 'factura' and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_sin_factura,
         coalesce(sum(x.por_cobrar) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
         count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
         coalesce(sum(x.por_cobrar) filter (where x.tramo = 'corriente'), 0)::numeric(14,2) as por_vencer,
         count(*) filter (where x.tramo = 'corriente') as n_por_vencer,
         coalesce(sum(x.retencion), 0)::numeric(14,2) as retencion, count(*) filter (where x.retencion <> 0) as n_retencion,
         coalesce(sum(x.por_cobrar) filter (where x.tramo in ('anticipo', 'a_favor')), 0)::numeric(14,2) as a_favor,
         count(*) filter (where x.tramo in ('anticipo', 'a_favor')) as n_a_favor,
         max(x.dias_vencida) as dias_mas_vieja
    into r
    from fn_tablero_cxc(v_hoy) x;
  v_libro := fn_tablero_saldo((select array_agg(pc.cuenta) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')), v_hoy);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'cobros', 'corte', v_hoy, 'dias', v_c -> 'dias', 'desde', v_c -> 'desde', 'hasta', v_c -> 'hasta',
    'por_cobrar', jsonb_build_object(
        'monto', r.monto, 'n', r.n, 'facturas', r.facturas,
        'sin_factura', jsonb_build_object('monto', r.sin_factura, 'n', r.n_sin_factura),
        'vencidas', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'dias_mas_vieja', case when r.n_vencido > 0 then r.dias_mas_vieja end),
        'por_vencer', jsonb_build_object('monto', r.por_vencer, 'n', r.n_por_vencer),
        'retencion', jsonb_build_object('monto', r.retencion, 'n', r.n_retencion),
        'a_favor', jsonb_build_object('monto', r.a_favor, 'n', r.n_a_favor),
        'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
    'cobrado', jsonb_build_object('monto', v_c -> 'monto', 'n', v_c -> 'n', 'facturas', v_c -> 'facturas',
                                  'ir', jsonb_build_object('pagina', 'movimientos')),
    'depositado', v_c -> 'depositado',
    'sin_depositar', v_c -> 'sin_depositar',
    'devuelto', v_c -> 'devuelto',
    -- los tres pasos del embudo, listos para dibujar
    'pasos', jsonb_build_array(
        jsonb_build_object('clave', 'por_cobrar', 'etiqueta', 'Por cobrar', 'monto', r.monto, 'n', r.n,
                           'detalle', case when r.n = 0 then 'nada por cobrar'
                                           when r.n_vencido = 0 then 'ninguna vencida'
                                           when r.n_vencido = 1 then '1 vencida'
                                           else r.n_vencido || ' vencidas' end,
                           'alarma', r.n_vencido > 0),
        jsonb_build_object('clave', 'cobrado', 'etiqueta', 'Cobrado', 'monto', v_c -> 'monto', 'n', v_c -> 'n',
                           'detalle', case when (v_c ->> 'n')::int = 1 then '1 cobro' else (v_c ->> 'n') || ' cobros' end
                                      || ' en ' || (v_c ->> 'dias') || ' días'),
        jsonb_build_object('clave', 'depositado', 'etiqueta', 'Depositado', 'monto', v_c -> 'depositado' -> 'monto',
                           'n', v_c -> 'depositado' -> 'n',
                           'detalle', case when v_c -> 'depositado' = 'null'::jsonb or v_c -> 'depositado' is null then 'sin el banco no se sabe'
                                           when (v_c -> 'sin_depositar' ->> 'monto')::numeric = 0 then 'todo lo cobrado está en el banco'
                                           else fn_tablero_usd((v_c -> 'sin_depositar' ->> 'monto')::numeric) || ' sin depositar' end)),
    'cuadre', jsonb_build_object('ok', r.monto + r.a_favor + r.retencion = v_libro, 'libro', v_libro,
                                 'suma', (r.monto + r.a_favor + r.retencion)::numeric(14,2),
                                 'texto', 'por cobrar + retención + anticipos y saldos a favor = el saldo de las cuentas por cobrar en el libro'),
    'nota', v_c -> 'nota',
    'fuente', 'por cobrar: las partidas abiertas de las cuentas por cobrar en el libro (vencidas según su vencimiento); cobrado y '
              'depositado: ' || (v_c ->> 'fuente'),
    'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas'));
end $$;
revoke execute on function public.fn_tablero_cobros(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros(int) to authenticated;
comment on function public.fn_tablero_cobros(int) is 'c16: el embudo de cobro: {ok, tarjeta, corte, dias, desde, hasta, por_cobrar: {monto, n, facturas, sin_factura: {monto, n}, vencidas: {monto, n, dias_mas_vieja}, por_vencer: {monto, n}, retencion: {monto, n}, a_favor: {monto, n}, ir}, cobrado: {monto, n, facturas, ir}, depositado: {monto, n}, sin_depositar: {monto, n, sin_casar, en_stripe, en_caja}, devuelto: {monto, n}, pasos: [{clave, etiqueta, monto, n, detalle, alarma?}] (los tres del embudo), cuadre: {ok, libro, suma, texto}, nota, fuente, ir}. Por cobrar no cuenta la retención (se cobra al terminar la obra) ni los anticipos: van aparte. Solo lee. Solo el dueño.';

-- 3.3 · BANCOS Y TARJETAS: cada cuenta con lo que dice el banco, lo que dice
-- el libro, lo que espera en la Bandeja y cuándo se actualizó.
create or replace function public.fn_tablero_bancos() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_capas  jsonb := fn_tablero_capas();
  v_ocultas text[] := '{}';
  v_plaid  jsonb := '{}'::jsonb;   -- por cuenta del plan: su conexión de Plaid
  v_l      jsonb;
  r        record;
begin
  perform fn_tablero_exigir_dueno();
  if not (v_capas ->> 'c6')::boolean then
    return fn_tablero_no('bancos', 'El banco (c6) no está en esta base: los saldos de los bancos y las tarjetas se llevan ahí.', 'c6');
  end if;
  -- (las dos cuentas de Stripe no son un banco con estado de cuenta: la página Bancos las esconde, y aquí igual)
  if (v_capas ->> 'p1')::boolean then
    select array_remove(array[c.cuenta_puente, c.cuenta_paso], null) into v_ocultas from stripe_config c where c.id = 1;
  end if;
  if (v_capas ->> 'c7')::boolean then
    select coalesce(jsonb_object_agg(z.cuenta, z.j), '{}'::jsonb) into v_plaid
      from (select distinct on (x.value ->> 'cuenta') x.value ->> 'cuenta' as cuenta,
                   jsonb_build_object('institucion', c.institucion, 'estado', c.estado, 'error', c.ultimo_error,
                                      'ultimo_sync', c.ultimo_sync) as j
              from plaid_conexiones c, jsonb_array_elements(c.cuentas) x
             where c.estado <> 'desconectada' and x.value ->> 'cuenta' is not null and x.value ->> 'cuenta' <> 'ignorar'
             order by x.value ->> 'cuenta', (c.estado = 'activa') desc, c.ultimo_sync desc nulls last) z;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'cuenta', s.cuenta, 'nombre', s.cuenta_nombre, 'tipo', s.tipo, 'activa', s.activa,
           'saldo_banco', s.saldo_banco_como_banco, 'saldo_banco_al', s.saldo_banco_al,
           'saldo_libro', s.saldo_libros_como_banco,
           'diferencia', (s.saldo_banco_como_banco - s.saldo_libros_como_banco)::numeric(14,2),
           'por_revisar', s.pendientes, 'por_revisar_monto', s.pendientes_monto, 'mas_viejo', s.pendiente_mas_viejo,
           'dias_mas_viejo', v_hoy - s.pendiente_mas_viejo, 'en_transito', s.en_transito,
           'actualizado_el', u.el,
           'horas', case when u.el is not null then floor(extract(epoch from now() - u.el) / 3600)::int end,
           'via', case when v_plaid ? s.cuenta then 'plaid' when u.archivo is not null then 'archivo' end,
           'conexion', v_plaid -> s.cuenta,
           'ultima_conciliacion', s.ultima_confirmada, 'dias_sin_conciliar', s.dias_sin_conciliar,
           'alarma', s.alarma, 'alarma_texto', nullif(s.alarma_texto, ''),
           'ir', jsonb_build_object('pagina', 'bandeja', 'cuenta', s.cuenta),
           'ir_conciliar', jsonb_build_object('pagina', 'conciliar', 'cuenta', s.cuenta))
           order by s.tipo, s.cuenta), '[]'::jsonb) as lista,
         count(*) filter (where s.tipo = 'banco') as n_bancos,
         coalesce(sum(s.saldo_libros_como_banco) filter (where s.tipo = 'banco'), 0)::numeric(14,2) as bancos_libro,
         count(*) filter (where s.tipo = 'banco' and s.saldo_banco is not null) as n_bancos_con,
         coalesce(sum(s.saldo_banco_como_banco) filter (where s.tipo = 'banco'), 0)::numeric(14,2) as bancos_banco,
         count(*) filter (where s.tipo = 'tarjeta') as n_tarjetas,
         coalesce(sum(s.saldo_libros_como_banco) filter (where s.tipo = 'tarjeta'), 0)::numeric(14,2) as tarjetas_libro,
         count(*) filter (where s.tipo = 'tarjeta' and s.saldo_banco is not null) as n_tarjetas_con,
         coalesce(sum(s.saldo_banco_como_banco) filter (where s.tipo = 'tarjeta'), 0)::numeric(14,2) as tarjetas_banco,
         coalesce(sum(s.pendientes), 0) as pendientes, min(s.pendiente_mas_viejo) as viejo,
         count(*) filter (where s.alarma) as alarmas, max(u.el) as actualizado
    into r
    from v_banco_saldos s
    left join lateral (select greatest(max(a.importado_el), (v_plaid -> s.cuenta ->> 'ultimo_sync')::timestamptz) as el,
                              max(a.importado_el) as archivo
                         from archivos_banco a where a.cuenta = s.cuenta and a.retirado_el is null) u on true
   where not (s.cuenta = any (v_ocultas));
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'bancos', 'corte', v_hoy, 'cuentas', r.lista,
    'totales', jsonb_build_object(
        'bancos', jsonb_build_object('n', r.n_bancos, 'libro', r.bancos_libro, 'con_banco', r.n_bancos_con,
                                     'banco', case when r.n_bancos_con > 0 then r.bancos_banco end),
        'tarjetas', jsonb_build_object('n', r.n_tarjetas, 'libro', r.tarjetas_libro, 'con_banco', r.n_tarjetas_con,
                                       'banco', case when r.n_tarjetas_con > 0 then r.tarjetas_banco end),
        'por_revisar', jsonb_build_object('n', r.pendientes, 'mas_viejo', r.viejo, 'dias', v_hoy - r.viejo,
                                          'alarma', coalesce(v_hoy - r.viejo > 30, false)),
        'alarmas', r.alarmas, 'actualizado_el', r.actualizado),
    'fuente', 'v_banco_saldos (c6): el saldo según el banco es el del último archivo o lote de Plaid con saldo; el del libro, la suma de '
              'la cuenta; en las tarjetas, lo que se debe va en positivo',
    'ir', jsonb_build_object('pagina', 'bancos'));
end $$;
revoke execute on function public.fn_tablero_bancos() from public, anon, service_role;
grant  execute on function public.fn_tablero_bancos() to authenticated;
comment on function public.fn_tablero_bancos() is 'c16: bancos y tarjetas (v_banco_saldos de c6, sin las dos cuentas de Stripe): {ok, tarjeta, corte, cuentas: [{cuenta, nombre, tipo (banco | tarjeta), activa, saldo_banco y saldo_banco_al (lo que dice el banco y de qué día; en una tarjeta, lo que se debe en positivo), saldo_libro, diferencia (banco − libro), por_revisar, por_revisar_monto, mas_viejo, dias_mas_viejo, en_transito, actualizado_el, horas (desde que se actualizó), via (plaid | archivo), conexion: {institucion, estado, error, ultimo_sync}, ultima_conciliacion, dias_sin_conciliar, alarma, alarma_texto, ir, ir_conciliar}], totales: {bancos: {n, libro, con_banco, banco}, tarjetas: {…}, por_revisar: {n, mas_viejo, dias, alarma}, alarmas, actualizado_el}, fuente, ir}. Sin c6: {ok: false, falta: «c6»}. Solo lee. Solo el dueño.';

-- 3.4 · EL RESULTADO de un período, contra el anterior.
--   p_periodo: 'mes' (el de hoy; por omisión), 'mes_pasado', 'anio' (el de
--   hoy) o 'anio_pasado'; o p_desde y p_hasta (los dos). El período va
--   contado HASTA HOY si todavía no termina (lo que tenga fecha de después
--   se dice aparte y no se cuenta).
--   EL ANTERIOR: de un período de meses enteros, los meses de antes (de
--   noviembre, octubre; del año, el año pasado); si el período va a medias,
--   los MISMOS DÍAS del anterior (del 1 al 12 de noviembre contra el 1 al 12
--   de octubre). De un rango cualquiera, los mismos días justo antes. Si el
--   anterior empieza antes del libro, no hay comparación (y se dice).
create or replace function public.fn_tablero_resultados(p_desde date default null, p_hasta date default null, p_periodo text default null)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy     date := fn_tablero_hoy();
  v_libro   date := (fn_tablero_libro() ->> 'desde')::date;
  v_per     text := lower(btrim(coalesce(p_periodo, '')));
  v_desde   date;
  v_hasta   date;
  v_al      date;      -- hasta dónde se cuenta: el fin del período o hoy
  v_etq     text;
  v_meses   int;
  v_alineado boolean;
  v_en_curso boolean;
  a_desde   date;
  a_hasta   date;
  a_etq     text;
  v_comp    boolean;
  v_r       jsonb;
  v_a       jsonb;
  v_d       jsonb;     -- lo de después de hoy, si el período va a medias
  v_etqs    jsonb;
  v_filas   jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if v_per <> '' and (p_desde is not null or p_hasta is not null) then
    raise exception using errcode = '22023', message = 'Se pide un período por su nombre (p_periodo) o por sus fechas (p_desde y p_hasta), no las dos cosas.';
  end if;
  if v_per = '' and p_desde is null and p_hasta is null then
    v_per := 'mes';
  end if;
  if v_per = 'mes' then
    v_desde := date_trunc('month', v_hoy)::date; v_hasta := (v_desde + interval '1 month')::date - 1;
  elsif v_per = 'mes_pasado' then
    v_desde := (date_trunc('month', v_hoy) - interval '1 month')::date; v_hasta := date_trunc('month', v_hoy)::date - 1;
  elsif v_per = 'anio' then
    v_desde := date_trunc('year', v_hoy)::date; v_hasta := (v_desde + interval '1 year')::date - 1;
  elsif v_per = 'anio_pasado' then
    v_desde := (date_trunc('year', v_hoy) - interval '1 year')::date; v_hasta := date_trunc('year', v_hoy)::date - 1;
  elsif v_per = '' then
    if p_desde is null or p_hasta is null then
      raise exception using errcode = '22023', message = 'Un rango lleva sus dos fechas: p_desde y p_hasta.';
    end if;
    if p_desde > p_hasta then
      raise exception using errcode = '22023', message = format('El rango va al revés: del %s al %s.', p_desde, p_hasta);
    end if;
    v_per := 'rango'; v_desde := p_desde; v_hasta := p_hasta;
  else
    raise exception using errcode = '22023',
      message = format('No conozco el período «%s». Los que hay: mes, mes_pasado, anio, anio_pasado (o p_desde y p_hasta).', left(p_periodo, 40));
  end if;
  if v_libro is null then
    return fn_tablero_no('resultados', 'El libro no tiene períodos todavía.');
  end if;
  if v_hasta < v_libro then
    return fn_tablero_no('resultados', format('Ese período (%s) es de antes del libro, que empieza el %s: vive en QuickBooks.',
                                              fn_tablero_rango(v_desde, v_hasta), fn_tablero_dia(v_libro)))
           || jsonb_build_object('antes_del_libro', true, 'periodo', v_per, 'desde', v_desde, 'hasta', v_hasta);
  end if;
  v_alineado := v_desde = date_trunc('month', v_desde)::date and v_hasta = (date_trunc('month', v_hasta) + interval '1 month')::date - 1;
  v_meses := (extract(year from v_hasta)::int - extract(year from v_desde)::int) * 12
             + extract(month from v_hasta)::int - extract(month from v_desde)::int + 1;
  v_en_curso := v_hoy >= v_desde and v_hoy < v_hasta;
  v_al := least(v_hasta, greatest(v_hoy, v_desde));
  v_etq := case when v_alineado and v_meses = 1 then fn_tablero_mes_largo(v_desde)
                when v_alineado and v_meses = 12 and extract(month from v_desde) = 1 then extract(year from v_desde)::int::text
                else fn_tablero_rango(v_desde, v_hasta) end;
  -- el período anterior
  if v_alineado then
    a_desde := (v_desde - make_interval(months => v_meses))::date;
    a_hasta := v_desde - 1;
    if v_en_curso then
      a_hasta := least(a_hasta, (v_hoy - make_interval(months => v_meses))::date);
    end if;
    a_etq := case when a_hasta = v_desde - 1 and v_meses = 1 then fn_tablero_mes_largo(a_desde)
                  when a_hasta = v_desde - 1 and v_meses = 12 and extract(month from a_desde) = 1 then extract(year from a_desde)::int::text
                  else fn_tablero_rango(a_desde, a_hasta) end;
  else
    a_desde := v_desde - (v_hasta - v_desde + 1);
    a_hasta := case when v_en_curso then a_desde + (v_hoy - v_desde) else v_desde - 1 end;
    a_etq := fn_tablero_rango(a_desde, a_hasta);
  end if;
  v_comp := a_desde >= v_libro;
  v_r := fn_tablero_pyg(v_desde, v_al);
  v_a := case when v_comp then fn_tablero_pyg(a_desde, a_hasta) end;
  v_d := case when v_en_curso then fn_tablero_pyg(v_al + 1, v_hasta) end;
  -- las etiquetas de los renglones, las de c4 (estados_lineas)
  select coalesce(jsonb_object_agg(el.linea, el.etiqueta_es), '{}'::jsonb) into v_etqs
    from estados_lineas el
   where el.estado = 'resultados' and (el.seccion = el.linea or el.seccion = 'totales');
  select jsonb_agg(jsonb_build_object(
           'clave', k.clave, 'etiqueta', coalesce(v_etqs ->> k.linea, k.omision), 'es_total', k.es_total,
           'monto', (v_r ->> k.clave)::numeric,
           'anterior', (v_a ->> k.clave)::numeric,
           'variacion', ((v_r ->> k.clave)::numeric - (v_a ->> k.clave)::numeric)::numeric(14,2),
           'variacion_pct', fn_tablero_pct((v_r ->> k.clave)::numeric - (v_a ->> k.clave)::numeric, (v_a ->> k.clave)::numeric, true))
           order by k.o) into v_filas
    from (values (1, 'ingresos', 'ingresos', 'Ingresos', false), (2, 'costo', 'costo', 'Costo de obra', false),
                 (3, 'utilidad_bruta', 'utilidad_bruta', 'Utilidad bruta', true), (4, 'gastos', 'gastos', 'Gastos de operación', false),
                 (5, 'utilidad_operacion', 'utilidad_operacion', 'Utilidad de operación', true),
                 (6, 'otros_ingresos', 'otros_ingresos', 'Otros ingresos', false), (7, 'otros_gastos', 'otros_gastos', 'Otros gastos', false),
                 (8, 'resultado', 'utilidad_neta', 'Utilidad neta', true)) k(o, clave, linea, omision, es_total);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'resultados', 'periodo', v_per, 'etiqueta', v_etq, 'desde', v_desde, 'hasta', v_hasta, 'corte', v_al,
    'en_curso', v_en_curso,
    'parcial', v_desde < v_libro, 'desde_libro', case when v_desde < v_libro then v_libro end,
    'resultado', v_r -> 'resultado', 'es_perdida', (v_r ->> 'resultado')::numeric < 0,
    'margen_pct', case when (v_r ->> 'entra')::numeric > 0 then fn_tablero_pct((v_r ->> 'resultado')::numeric, (v_r ->> 'entra')::numeric) end,
    'ingresos', v_r -> 'ingresos', 'costo', v_r -> 'costo', 'gastos', v_r -> 'gastos',
    'otros_ingresos', v_r -> 'otros_ingresos', 'otros_gastos', v_r -> 'otros_gastos',
    'utilidad_bruta', v_r -> 'utilidad_bruta', 'utilidad_operacion', v_r -> 'utilidad_operacion',
    'asientos', v_r -> 'asientos',
    -- las dos barras: lo que entra y lo que se gasta (entra − sale = el resultado)
    'barras', jsonb_build_array(
        jsonb_build_object('clave', 'entra', 'etiqueta', 'Ingresos', 'monto', v_r -> 'entra', 'anterior', v_a -> 'entra'),
        jsonb_build_object('clave', 'sale', 'etiqueta', 'Costo y gastos', 'monto', v_r -> 'sale', 'anterior', v_a -> 'sale')),
    'renglones', v_filas,
    'anterior', case when v_comp
                     then jsonb_build_object('desde', a_desde, 'hasta', a_hasta, 'etiqueta', a_etq, 'resultado', v_a -> 'resultado',
                                             'ingresos', v_a -> 'ingresos', 'entra', v_a -> 'entra', 'sale', v_a -> 'sale') end,
    'variacion', case when v_comp
                      then jsonb_build_object(
                             'resultado', ((v_r ->> 'resultado')::numeric - (v_a ->> 'resultado')::numeric)::numeric(14,2),
                             'pct', fn_tablero_pct((v_r ->> 'resultado')::numeric - (v_a ->> 'resultado')::numeric, (v_a ->> 'resultado')::numeric, true),
                             'sube', (v_r ->> 'resultado')::numeric > (v_a ->> 'resultado')::numeric,
                             'contra', a_etq) end,
    'sin_comparar', case when not v_comp
                         then format('El período anterior (%s) empieza antes del libro (%s): vive en QuickBooks.', a_etq, fn_tablero_dia(v_libro)) end,
    'despues_de_hoy', case when v_en_curso and (v_d ->> 'asientos')::int > 0
                           then jsonb_build_object('asientos', v_d -> 'asientos', 'resultado', v_d -> 'resultado',
                                                   'texto', format('%s asiento(s) de este período tienen fecha de después de hoy: no van contados.', v_d ->> 'asientos')) end,
    'ajustes_otro_ejercicio', v_r -> 'ajustes_otro_ejercicio',
    'por_revisar', fn_tablero_por_revisar(greatest(v_desde, v_libro), v_al),
    'nota', case when v_desde < v_libro
                 then format('El libro empieza el %s: lo de antes de ese día vive en QuickBooks y no está aquí.', fn_tablero_dia(v_libro)) end,
    'fuente', 'el libro, con el mapeo de los estados financieros (c4): lo mismo que el estado de resultados',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados',
                             'periodo', case when v_alineado and v_meses = 1 then to_char(v_desde, 'YYYY-MM')
                                             when v_alineado and v_meses = 12 and extract(month from v_desde) = 1 then to_char(v_desde, 'YYYY')
                                             else to_char(v_al, 'YYYY-MM') end));
end $$;
revoke execute on function public.fn_tablero_resultados(date, date, text) from public, anon, service_role;
grant  execute on function public.fn_tablero_resultados(date, date, text) to authenticated;
comment on function public.fn_tablero_resultados(date, date, text) is 'c16: el resultado de un período (p_periodo: mes | mes_pasado | anio | anio_pasado; o p_desde y p_hasta), contado hasta hoy si no ha terminado: {ok, tarjeta, periodo, etiqueta, desde, hasta, corte, en_curso, parcial y desde_libro (si empieza antes del libro), resultado, es_perdida, margen_pct (resultado ÷ lo que entra), ingresos, costo, gastos, otros_ingresos, otros_gastos, utilidad_bruta, utilidad_operacion, asientos, barras: [{clave: entra | sale, etiqueta, monto, anterior}], renglones: [{clave, etiqueta (la de c4), es_total, monto, anterior, variacion, variacion_pct}] (el estado entero, para la tabla), anterior: {desde, hasta, etiqueta, resultado, ingresos, entra, sale}, variacion: {resultado, pct, sube, contra}, sin_comparar (por qué no hay anterior), despues_de_hoy, ajustes_otro_ejercicio, por_revisar: {n, cargos, depositos, …} (la Bandeja de c6 con fecha del período; nulo sin c6), nota, fuente, ir}. Un período de antes del libro: {ok: false, antes_del_libro: true}. 22023 si el período no existe. Solo lee. Solo el dueño.';

-- 3.5 · LO GASTADO en los últimos N días, por categoría, contra los N
-- anteriores. Una categoría es una cuenta de costo, de gastos o de otros
-- gastos (las tres secciones de gasto del estado de resultados de c4), con
-- la etiqueta de c4. Hoy y los N − 1 días anteriores, contra los N días
-- justo antes; si esos caen antes del libro, no hay comparación.
create or replace function public.fn_tablero_gastos(p_dias int default 30, p_top int default 5) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_libro date := (fn_tablero_libro() ->> 'desde')::date;
  v_dias  int := coalesce(p_dias, 30);
  v_top   int := coalesce(p_top, 5);
  v_desde date;
  a_desde date;
  a_hasta date;
  v_comp  boolean;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if v_dias < 1 or v_dias > 366 then
    raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_dias);
  end if;
  if v_top < 1 or v_top > 20 then
    raise exception using errcode = '22023', message = format('Las categorías de la gráfica van de 1 a 20 (llegó %s).', v_top);
  end if;
  if v_libro is null then
    return fn_tablero_no('gastos', 'El libro no tiene períodos todavía.');
  end if;
  v_desde := v_hoy - (v_dias - 1);
  a_desde := v_desde - v_dias;
  a_hasta := v_desde - 1;
  v_comp := a_desde >= v_libro;
  with ln as materialized (
    select l.cuenta, m.etiqueta as etiqueta_es, m.seccion, m.orden, a.fecha_contable >= v_desde as actual, l.monto
      from asiento_lineas l
      join asientos a on a.id = l.asiento_id
      join fn_tablero_mapa() m on m.cuenta = l.cuenta
     where m.estado = 'resultados' and m.seccion in ('costo', 'gastos', 'otros_gastos')
       and a.fecha_contable >= a_desde and a.fecha_contable <= v_hoy
       and (a.afecta_periodo is null
            or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio)
  ), c as (
    select ln.cuenta, min(ln.etiqueta_es) as nombre, min(ln.seccion) as seccion, min(ln.orden) as orden,
           coalesce(sum(ln.monto) filter (where ln.actual), 0)::numeric(14,2) as monto,
           coalesce(sum(ln.monto) filter (where not ln.actual), 0)::numeric(14,2) as anterior
      from ln group by ln.cuenta
  ), t as (
    select coalesce(sum(c.monto), 0)::numeric(14,2) as total, coalesce(sum(c.anterior), 0)::numeric(14,2) as anterior,
           coalesce(sum(c.monto) filter (where c.monto > 0), 0)::numeric(14,2) as positivo,
           coalesce(sum(c.monto) filter (where c.monto < 0), 0)::numeric(14,2) as negativo,
           count(*) filter (where c.monto <> 0) as n
      from c
  ), o as (
    select c.*, row_number() over (order by c.monto desc, c.cuenta) as pos from c where c.monto > 0
  )
  select t.total, t.anterior, t.positivo, t.negativo, t.n,
         (select coalesce(jsonb_agg(jsonb_build_object(
                   'cuenta', c.cuenta, 'nombre', c.nombre, 'seccion', c.seccion, 'monto', c.monto,
                   'pct', fn_tablero_pct(c.monto, nullif(t.total, 0)),
                   'anterior', case when v_comp then c.anterior end,
                   'variacion', case when v_comp then (c.monto - c.anterior)::numeric(14,2) end)
                   order by c.monto desc, c.cuenta), '[]'::jsonb)
            from c where c.monto <> 0 or (v_comp and c.anterior <> 0)) as categorias,
         (select coalesce(jsonb_agg(z.j order by z.o), '[]'::jsonb)
            from (select o.pos as o, jsonb_build_object('clave', o.cuenta, 'nombre', o.nombre, 'monto', o.monto,
                                                        'pct', fn_tablero_pct(o.monto, nullif(t.positivo, 0))) as j
                    from o where o.pos <= v_top
                  union all
                  select v_top + 1, jsonb_build_object('clave', 'otras', 'nombre', 'Las demás', 'monto', sum(o.monto)::numeric(14,2),
                                                       'pct', fn_tablero_pct(sum(o.monto), nullif(t.positivo, 0)),
                                                       'categorias', count(*))
                    from o where o.pos > v_top having count(*) > 0) z) as grafica
    into r
    from t;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'gastos', 'dias', v_dias, 'desde', v_desde, 'hasta', v_hoy, 'corte', v_hoy,
    'total', r.total, 'categorias', r.categorias, 'n_categorias', r.n,
    -- la gráfica: las «top» mayores y las demás juntas; sus porcentajes son de lo gastado en positivo
    'grafica', r.grafica, 'total_grafica', r.positivo,
    'abonos', case when r.negativo <> 0 then r.negativo end,
    'anterior', case when v_comp then jsonb_build_object('desde', a_desde, 'hasta', a_hasta, 'total', r.anterior,
                                                         'etiqueta', fn_tablero_rango(a_desde, a_hasta)) end,
    'variacion', case when v_comp then (r.total - r.anterior)::numeric(14,2) end,
    'variacion_pct', case when v_comp then fn_tablero_pct(r.total - r.anterior, r.anterior, true) end,
    'sin_comparar', case when not v_comp
                         then format('Los %s días anteriores (%s) empiezan antes del libro (%s): viven en QuickBooks.', v_dias,
                                     fn_tablero_rango(a_desde, a_hasta), fn_tablero_dia(v_libro)) end,
    'parcial', v_desde < v_libro,
    'nota', case when v_desde < v_libro
                 then format('El libro empieza el %s: de estos %s días solo cuentan los que tienen libro.', fn_tablero_dia(v_libro), v_dias)
                 when r.negativo <> 0
                 then format('Hay categorías con saldo a favor en estos días (%s): bajan el total y no salen en la gráfica.', fn_tablero_usd(r.negativo)) end,
    'fuente', 'el libro: las cuentas de costo, gastos y otros gastos del estado de resultados (c4), por la fecha de cada asiento',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados', 'periodo', to_char(v_hoy, 'YYYY-MM')));
end $$;
revoke execute on function public.fn_tablero_gastos(int, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_gastos(int, int) to authenticated;
comment on function public.fn_tablero_gastos(int, int) is 'c16: lo gastado en los últimos N días (hoy y los N − 1 anteriores) por categoría, contra los N días de antes: {ok, tarjeta, dias, desde, hasta, corte, total, categorias: [{cuenta, nombre (la etiqueta de c4), seccion (costo | gastos | otros_gastos), monto, pct (del total), anterior, variacion}] (de mayor a menor), n_categorias, grafica: [{clave (la cuenta, u «otras»), nombre, monto, pct}] (las p_top mayores y las demás juntas; pct de total_grafica), total_grafica (lo gastado en positivo), abonos (lo que hay a favor, si lo hay), anterior: {desde, hasta, total, etiqueta}, variacion, variacion_pct, sin_comparar (por qué no hay anterior), parcial, nota, fuente, ir}. Un ajuste del CPA que corrige otro año no cuenta. 22023 con días o top fuera de rango. Solo lee. Solo el dueño.';

-- 3.6 · LAS VENTAS: los ingresos (la sección «ingresos» de c4: 40xx) de cada
-- mes de un año, y su total. Solo los meses que el libro tiene: los de
-- antes viven en QuickBooks, y se dice. El mes en curso, hasta hoy.
create or replace function public.fn_tablero_ventas(p_anio int default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_libro date := (fn_tablero_libro() ->> 'desde')::date;
  v_anio  int := coalesce(p_anio, extract(year from fn_tablero_hoy())::int);
  v_m0    date;
  v_m1    date;
  v_fuera int;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if v_anio < 2000 or v_anio > 2100 then
    raise exception using errcode = '22023', message = format('El año no parece un año (llegó %s).', v_anio);
  end if;
  if v_libro is null then
    return fn_tablero_no('ventas', 'El libro no tiene períodos todavía.');
  end if;
  if make_date(v_anio, 12, 31) < v_libro then
    return fn_tablero_no('ventas', format('%s es de antes del libro, que empieza el %s: sus ventas viven en QuickBooks.', v_anio, fn_tablero_dia(v_libro)))
           || jsonb_build_object('antes_del_libro', true, 'anio', v_anio);
  end if;
  v_m0 := greatest(make_date(v_anio, 1, 1), date_trunc('month', v_libro)::date);
  v_m1 := least(make_date(v_anio, 12, 1), date_trunc('month', v_hoy)::date);
  v_fuera := extract(month from v_m0)::int - 1;   -- los meses del año de antes del libro
  with ms as (
    select g::date as mes from generate_series(v_m0, v_m1, interval '1 month') g
  ), ln as materialized (
    select date_trunc('month', a.fecha_contable)::date as mes, l.monto, l.asiento_id
      from asiento_lineas l
      join asientos a on a.id = l.asiento_id
      join fn_tablero_mapa() m on m.cuenta = l.cuenta
     where m.estado = 'resultados' and m.seccion = 'ingresos'
       and a.fecha_contable >= v_m0 and a.fecha_contable <= least(v_hoy, make_date(v_anio, 12, 31))
       and (a.afecta_periodo is null
            or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio)
  ), x as (
    select ms.mes, coalesce(-sum(ln.monto), 0)::numeric(14,2) as monto, count(distinct ln.asiento_id) as asientos
      from ms left join ln on ln.mes = ms.mes group by ms.mes
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'mes', to_char(x.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(x.mes),
           'corto', (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from x.mes)::int],
           'monto', x.monto, 'asientos', x.asientos, 'en_curso', x.mes = date_trunc('month', v_hoy)::date) order by x.mes), '[]'::jsonb) as meses,
         coalesce(sum(x.monto), 0)::numeric(14,2) as total, count(*) as n,
         (select jsonb_build_object('mes', to_char(y.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(y.mes), 'monto', y.monto)
            from x y where y.monto > 0 order by y.monto desc, y.mes limit 1) as mejor
    into r
    from x;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'ventas', 'anio', v_anio, 'desde', v_m0, 'corte', least(v_hoy, make_date(v_anio, 12, 31)),
    'total', r.total, 'meses', r.meses,
    'meses_del_anio', 12, 'meses_con_libro', r.n, 'mejor_mes', r.mejor,
    'antes_del_libro', case when v_fuera > 0
                            then jsonb_build_object('meses', v_fuera,
                                   'texto', format('%s de %s no %s en el libro, que empieza el %s: %s en QuickBooks.',
                                                   case when v_fuera = 1 then 'Enero'
                                                        else 'De enero a ' || (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
                                                                                     'agosto', 'septiembre', 'octubre', 'noviembre'])[v_fuera] end,
                                                   v_anio, case when v_fuera = 1 then 'está' else 'están' end, fn_tablero_dia(v_libro),
                                                   case when v_fuera = 1 then 'vive' else 'viven' end)) end,
    'fuente', 'el libro: las cuentas de ingreso del estado de resultados (c4), por la fecha de cada asiento; el mes en curso, hasta hoy',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados', 'periodo', v_anio::text));
end $$;
revoke execute on function public.fn_tablero_ventas(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_ventas(int) to authenticated;
comment on function public.fn_tablero_ventas(int) is 'c16: las ventas (los ingresos de la sección «ingresos» de c4) de cada mes de un año (por omisión, el de hoy): {ok, tarjeta, anio, desde, corte, total, meses: [{mes (AAAA-MM), etiqueta (oct 2026), corto (oct), monto, asientos, en_curso}] (solo los meses que el libro tiene, hasta el de hoy), meses_del_anio, meses_con_libro, mejor_mes, antes_del_libro: {meses, texto} (los meses del año que viven en QuickBooks), fuente, ir}. Un año de antes del libro: {ok: false, antes_del_libro: true}. Solo lee. Solo el dueño.';

-- 3.7 · LA ANTIGÜEDAD de lo que se cobra y de lo que se paga, por
-- VENCIMIENTO: corriente (no ha vencido), 1–30, 31–60, 61–90 y más de 90
-- días de vencido. p_lado: 'cobrar' | 'pagar'. La retención y lo que hay a
-- favor van aparte (no vencen). «calendario» es lo mismo por el mes en que
-- vence (lo ya vencido, en el mes de hoy): lo usa la proyección de caja.
create or replace function public.fn_tablero_antiguedad(p_lado text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_lado   text := lower(btrim(coalesce(p_lado, '')));
  v_ctas   text[];
  v_libro  numeric;
  v_dias   int := 0;
  r        record;
begin
  perform fn_tablero_exigir_dueno();
  if v_lado not in ('cobrar', 'pagar') then
    raise exception using errcode = '22023', message = format('El lado es «cobrar» o «pagar» (llegó «%s»).', left(coalesce(p_lado, ''), 40));
  end if;
  if v_lado = 'cobrar' then
    select array_agg(pc.cuenta) into v_ctas from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc');
    v_libro := fn_tablero_saldo(v_ctas, v_hoy);
    if to_regclass('public.emision_config') is not null then
      execute 'select coalesce((select c.terminos_dias from public.emision_config c where c.id = 1), 0)' into v_dias;
    end if;
    with x as materialized (
      select c.tipo, c.factura_num as papel, c.obra as de, c.cliente as detalle, c.fecha, c.vence, c.vence_de, c.por_cobrar as monto,
             c.retencion, c.dias_vencida, c.tramo, c.factura_id::text as id
        from fn_tablero_cxc(v_hoy) c
    )
    select (select jsonb_agg(jsonb_build_object('clave', k.clave, 'etiqueta', k.etiqueta,
                     'monto', coalesce((select sum(x.monto) from x where x.tramo = k.clave), 0)::numeric(14,2),
                     'n', (select count(*) from x where x.tramo = k.clave),
                     'vencido', k.clave <> 'corriente') order by k.o)
              from (values (1, 'corriente', 'Corriente'), (2, 'd1_30', '1 – 30'), (3, 'd31_60', '31 – 60'), (4, 'd61_90', '61 – 90'),
                           (5, 'd90_mas', 'Más de 90')) k(o, clave, etiqueta)) as tramos,
           coalesce(sum(x.monto) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as total,
           count(*) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')) as n,
           coalesce(sum(x.monto) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
           count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
           0::numeric(14,2) as sin_fecha, 0::bigint as n_sin_fecha,
           coalesce(sum(x.retencion), 0)::numeric(14,2) as retencion, count(*) filter (where x.retencion <> 0) as n_retencion,
           coalesce(sum(x.monto) filter (where x.tramo in ('anticipo', 'a_favor')), 0)::numeric(14,2) as a_favor,
           count(*) filter (where x.tramo in ('anticipo', 'a_favor')) as n_a_favor,
           count(*) filter (where x.vence_de = 'fecha' or x.vence_de = 'terminos') as n_sin_vence,
           (select coalesce(jsonb_agg(jsonb_build_object('papel', y.papel, 'de', y.de, 'detalle', y.detalle, 'fecha', y.fecha,
                                                         'vence', y.vence, 'dias_vencida', y.dias_vencida, 'monto', y.monto, 'tramo', y.tramo,
                                                         'id', y.id)
                                      order by y.dias_vencida desc, y.monto desc), '[]'::jsonb)
              from (select * from x where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
                     order by x.dias_vencida desc, x.monto desc limit 5) y) as viejas,
           (select coalesce(jsonb_agg(jsonb_build_object('mes', to_char(z.mes, 'YYYY-MM'), 'monto', z.monto, 'n', z.n, 'vencido', z.vencido)
                                      order by z.mes), '[]'::jsonb)
              from (select date_trunc('month', greatest(x.vence, v_hoy))::date as mes, sum(x.monto)::numeric(14,2) as monto, count(*) as n,
                           coalesce(sum(x.monto) filter (where x.tramo <> 'corriente'), 0)::numeric(14,2) as vencido
                      from x where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas') group by 1) z) as calendario
      into r
      from x;
  else
    v_ctas := array(select m.cuenta from fn_tablero_mapa() m
                     where m.estado = 'balance' and m.linea in ('cuentas_por_pagar', 'retencion_por_pagar')
                    union
                    select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp');
    v_libro := -fn_tablero_saldo(v_ctas, v_hoy);
    with x as materialized (
      select c.tipo, c.referencia as papel, c.proveedor as de, null::text as detalle, c.fecha, c.vence, c.vence_de, c.por_pagar as monto,
             c.retencion, c.dias_vencida, c.tramo, c.partida_id as id
        from fn_tablero_cxp() c
    )
    select (select jsonb_agg(jsonb_build_object('clave', k.clave, 'etiqueta', k.etiqueta,
                     'monto', coalesce((select sum(x.monto) from x where x.tramo = k.clave), 0)::numeric(14,2),
                     'n', (select count(*) from x where x.tramo = k.clave),
                     'vencido', k.clave <> 'corriente') order by k.o)
              from (values (1, 'corriente', 'Corriente'), (2, 'd1_30', '1 – 30'), (3, 'd31_60', '31 – 60'), (4, 'd61_90', '61 – 90'),
                           (5, 'd90_mas', 'Más de 90')) k(o, clave, etiqueta)) as tramos,
           coalesce(sum(x.monto) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas', 'sin_fecha')), 0)::numeric(14,2) as total,
           count(*) filter (where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas', 'sin_fecha')) as n,
           coalesce(sum(x.monto) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
           count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
           coalesce(sum(x.monto) filter (where x.tramo = 'sin_fecha'), 0)::numeric(14,2) as sin_fecha,
           count(*) filter (where x.tramo = 'sin_fecha') as n_sin_fecha,
           coalesce(sum(x.retencion), 0)::numeric(14,2) as retencion, count(*) filter (where x.retencion <> 0) as n_retencion,
           coalesce(sum(x.monto) filter (where x.tramo = 'a_favor'), 0)::numeric(14,2) as a_favor,
           count(*) filter (where x.tramo = 'a_favor') as n_a_favor,
           count(*) filter (where x.vence_de = 'fecha') as n_sin_vence,
           (select coalesce(jsonb_agg(jsonb_build_object('papel', y.papel, 'de', y.de, 'detalle', y.detalle, 'fecha', y.fecha,
                                                         'vence', y.vence, 'dias_vencida', y.dias_vencida, 'monto', y.monto, 'tramo', y.tramo,
                                                         'id', y.id)
                                      order by y.dias_vencida desc, y.monto desc), '[]'::jsonb)
              from (select * from x where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
                     order by x.dias_vencida desc, x.monto desc limit 5) y) as viejas,
           (select coalesce(jsonb_agg(jsonb_build_object('mes', to_char(z.mes, 'YYYY-MM'), 'monto', z.monto, 'n', z.n, 'vencido', z.vencido)
                                      order by z.mes), '[]'::jsonb)
              from (select date_trunc('month', greatest(coalesce(x.vence, v_hoy), v_hoy))::date as mes, sum(x.monto)::numeric(14,2) as monto,
                           count(*) as n,
                           coalesce(sum(x.monto) filter (where x.tramo not in ('corriente')), 0)::numeric(14,2) as vencido
                      from x where x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas', 'sin_fecha') group by 1) z) as calendario
      into r
      from x;
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', case when v_lado = 'cobrar' then 'por_cobrar' else 'por_pagar' end, 'lado', v_lado, 'corte', v_hoy,
    'total', r.total, 'n', r.n,
    'tramos', r.tramos,
    'vencido', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'pct', fn_tablero_pct(r.vencido, nullif(r.total, 0))),
    'sin_fecha', case when v_lado = 'pagar' then jsonb_build_object('monto', r.sin_fecha, 'n', r.n_sin_fecha) end,
    'retencion', jsonb_build_object('monto', r.retencion, 'n', r.n_retencion),
    'a_favor', jsonb_build_object('monto', r.a_favor, 'n', r.n_a_favor),
    'mas_viejas', r.viejas,
    'calendario', r.calendario,
    'cuadre', jsonb_build_object('ok', r.total + r.retencion + r.a_favor = v_libro, 'libro', v_libro,
                                 'suma', (r.total + r.retencion + r.a_favor)::numeric(14,2),
                                 'texto', case when v_lado = 'cobrar'
                                               then 'los tramos + la retención + los anticipos y saldos a favor = el saldo de las cuentas por cobrar en el libro'
                                               else 'los tramos + lo que va sin fecha + la retención + lo que hay a favor = el saldo de las cuentas por pagar en el libro' end),
    'regla', case when v_lado = 'cobrar'
                  then format('Vence el día que dice la factura emitida por la app; la que no lo trae, %s. Lo que va sin factura, el día de su fecha. '
                              'La retención y los anticipos no vencen: van aparte.',
                              case when v_dias = 0 then 'el día de su fecha («due on receipt», los términos de Facturas → Ajustes)'
                                   else format('a los %s días de su fecha (los términos de Facturas → Ajustes)', v_dias) end)
                  else 'Vence según los términos del proveedor (Net 30, Net 10 EOM…) o lo que dijo la balanza de apertura; sin términos, el '
                       || 'día de su fecha' || case when r.n_sin_vence > 0 then format(' (%s así)', r.n_sin_vence) else '' end
                       || '. La retención a los subcontratistas no vence por términos: va aparte.' end,
    'fuente', case when v_lado = 'cobrar'
                   then 'las partidas abiertas de las cuentas por cobrar en el libro (las de la antigüedad de c4), por su vencimiento'
                   else 'las partidas abiertas de las cuentas por pagar (la antigüedad de c4), por su vencimiento' end,
    'ir', case when to_regprocedure('public.fn_cedula_resumen(date)') is not null
               then jsonb_build_object('pagina', 'cedula', 'sub', 'cedula', 'cuenta', v_ctas[1])
               else jsonb_build_object('pagina', 'estados', 'sub', 'balance', 'cuenta', v_ctas[1]) end);
end $$;
revoke execute on function public.fn_tablero_antiguedad(text) from public, anon, service_role;
grant  execute on function public.fn_tablero_antiguedad(text) to authenticated;
comment on function public.fn_tablero_antiguedad(text) is 'c16: la antigüedad por VENCIMIENTO de lo que se cobra («cobrar») o de lo que se paga («pagar»): {ok, tarjeta (por_cobrar | por_pagar), lado, corte, total, n, tramos: [{clave (corriente | d1_30 | d31_60 | d61_90 | d90_mas), etiqueta, monto, n, vencido}], vencido: {monto, n, pct}, sin_fecha: {monto, n} (solo en pagar: lo de la apertura sin fecha; cuenta en el total), retencion: {monto, n}, a_favor: {monto, n} (en negativo: anticipos y saldos a favor), mas_viejas: [{papel, de, detalle, fecha, vence, dias_vencida, monto, tramo, id}] (las cinco más vencidas), calendario: [{mes, monto, n, vencido}] (por el mes en que vence; lo ya vencido, en el de hoy), cuadre: {ok, libro, suma, texto}, regla (cómo se sabe el vencimiento, en llano), fuente, ir}. 22023 con otro lado. Solo lee. Solo el dueño.';

-- 3.8 · LAS FACTURAS: no pagadas (vencidas y por vencer) y lo cobrado en los
-- últimos N días (depositado y sin depositar).
create or replace function public.fn_tablero_facturas(p_dias int default 30) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
  v_c   jsonb;
  r     record;
begin
  perform fn_tablero_exigir_dueno();
  v_c := fn_tablero_cobrado(p_dias);
  select coalesce(sum(x.por_cobrar), 0)::numeric(14,2) as monto, count(*) as n,
         coalesce(sum(x.por_cobrar) filter (where x.tramo <> 'corriente'), 0)::numeric(14,2) as vencido,
         count(*) filter (where x.tramo <> 'corriente') as n_vencido,
         coalesce(sum(x.por_cobrar) filter (where x.tramo = 'corriente'), 0)::numeric(14,2) as por_vencer,
         count(*) filter (where x.tramo = 'corriente') as n_por_vencer,
         min(x.fecha) as mas_vieja, max(x.dias_vencida) as dias
    into r
    from fn_tablero_cxc(v_hoy) x
   where x.tipo = 'factura' and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas');
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'facturas', 'corte', v_hoy,
    'no_pagadas', jsonb_build_object(
        'monto', r.monto, 'n', r.n,
        'vencidas', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'pct', fn_tablero_pct(r.vencido, nullif(r.monto, 0))),
        'por_vencer', jsonb_build_object('monto', r.por_vencer, 'n', r.n_por_vencer, 'pct', fn_tablero_pct(r.por_vencer, nullif(r.monto, 0))),
        'mas_vieja', r.mas_vieja, 'dias_mas_vencida', case when r.n_vencido > 0 then r.dias end,
        'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
    'pagadas', jsonb_build_object(
        'dias', v_c -> 'dias', 'desde', v_c -> 'desde', 'hasta', v_c -> 'hasta',
        'monto', v_c -> 'monto', 'n', v_c -> 'n', 'facturas', v_c -> 'facturas',
        'depositado', case when v_c -> 'depositado' <> 'null'::jsonb
                           then (v_c -> 'depositado') || jsonb_build_object('pct', fn_tablero_pct((v_c -> 'depositado' ->> 'monto')::numeric,
                                                                                                  nullif((v_c ->> 'monto')::numeric, 0))) end,
        'sin_depositar', case when v_c -> 'sin_depositar' <> 'null'::jsonb
                              then (v_c -> 'sin_depositar') || jsonb_build_object('pct', fn_tablero_pct((v_c -> 'sin_depositar' ->> 'monto')::numeric,
                                                                                                        nullif((v_c ->> 'monto')::numeric, 0))) end,
        'devuelto', v_c -> 'devuelto', 'nota', v_c -> 'nota'),
    'fuente', 'no pagadas: las facturas con saldo en las cuentas por cobrar del libro (sin la retención); pagadas: ' || (v_c ->> 'fuente'),
    'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas'));
end $$;
revoke execute on function public.fn_tablero_facturas(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_facturas(int) to authenticated;
comment on function public.fn_tablero_facturas(int) is 'c16: las facturas: {ok, tarjeta, corte, no_pagadas: {monto, n, vencidas: {monto, n, pct}, por_vencer: {monto, n, pct}, mas_vieja, dias_mas_vencida, ir} (las facturas con saldo por cobrar, sin su retención), pagadas: {dias, desde, hasta, monto, n, facturas, depositado: {monto, n, pct}, sin_depositar: {monto, n, pct, sin_casar, en_stripe, en_caja}, devuelto, nota} (lo cobrado en los últimos N días, como en el embudo), fuente, ir}. Solo lee. Solo el dueño.';

-- 3.9 · LOS PRÉSTAMOS (c6): lo que se debe de cada uno, su cuota y la
-- PRÓXIMA. La fecha de la próxima cuota sale del calendario del préstamo
-- (el primer pago y cada período después: cada mes en su día, cada semana…):
-- la primera fecha posterior a la última cuota registrada, con medio
-- período de margen (una cuota pagada unos días antes o después cuenta por
-- la suya). Si esa fecha ya pasó, la cuota está ATRASADA O SIN REGISTRAR (el
-- cargo puede estar esperando en la Bandeja). Su reparto es el de la fórmula
-- de c6: el interés del período sobre lo que se debe y el resto a capital.
-- «calendario»: las cuotas de los próximos 12 meses por mes (las atrasadas,
-- en el mes de hoy): lo usa la proyección de caja.
create or replace function public.fn_tablero_prestamos() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_l      jsonb := '[]'::jsonb;
  v_cal    jsonb := '{}'::jsonb;   -- mes → {monto, n}
  v_total  numeric := 0;
  v_n      int := 0;
  v_prox   date;
  v_30     numeric := 0;
  v_ctas   text[] := '{}';
  v_libro  numeric;
  p        record;
  v_paso   int;       -- meses entre cuotas (0 si va por días)
  v_dias   int;       -- días entre cuotas (si no va por meses)
  v_margen int;
  v_ref    date;
  v_k      int;
  v_f      date;
  v_base   date;
  v_saldo  numeric;
  v_int    numeric;
  v_cap    numeric;
  v_pago   numeric;
  v_i      int;
  v_mes    text;
  v_p1     jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.v_prestamos') is null or to_regclass('public.prestamos') is null then
    return fn_tablero_no('prestamos', 'El banco (c6) no está en esta base: los préstamos se llevan ahí.', 'c6');
  end if;
  for p in select x.* from v_prestamos x order by (x.estado = 'vigente') desc, x.saldo desc, x.prestamista loop
    v_p1 := null;
    if p.estado = 'vigente' then
      v_n := v_n + 1;
      v_total := v_total + p.saldo;
      v_ctas := v_ctas || array_remove(array[p.cuenta, p.cuenta_largo], null);
    end if;
    if p.estado = 'vigente' and p.saldo > 0 then
      v_paso := case p.cuotas_al_anio when 12 then 1 when 6 then 2 when 4 then 3 when 2 then 6 when 1 then 12 else 0 end;
      v_dias := case p.cuotas_al_anio when 52 then 7 when 26 then 14 when 24 then 15 else 0 end;
      v_margen := greatest(1, 365 / p.cuotas_al_anio / 2);
      v_ref := greatest(p.saldo_inicial_al, coalesce(p.ultima_fecha + v_margen, p.saldo_inicial_al));
      -- la primera fecha del calendario posterior a la referencia
      v_k := 0;
      loop
        if v_paso > 0 then
          v_base := (date_trunc('month', p.primer_pago) + make_interval(months => v_k * v_paso))::date;
          v_f := v_base + least(case when v_paso = 1 then p.dia_pago else extract(day from p.primer_pago)::int end,
                                extract(day from (v_base + interval '1 month' - interval '1 day'))::int) - 1;
        else
          v_f := p.primer_pago + v_k * v_dias;
        end if;
        exit when v_f > v_ref or v_k > 20000;
        v_k := v_k + 1;
      end loop;
      -- las cuotas de los próximos 12 meses, con la fórmula de c6
      v_saldo := p.saldo;
      v_i := 0;
      while v_saldo > 0 and v_f <= (v_hoy + interval '12 months')::date and v_i < 600 loop
        v_int := round(v_saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2);
        v_cap := least(v_saldo, greatest(p.cuota - v_int, 0));
        v_pago := v_cap + v_int;
        if v_i = 0 then
          v_p1 := jsonb_build_object('fecha', v_f, 'monto', v_pago, 'capital', v_cap, 'interes', v_int,
                                     'atrasada', v_f < v_hoy, 'dias', v_f - v_hoy);
          v_prox := least(coalesce(v_prox, v_f), v_f);
        end if;
        if v_f <= v_hoy + 30 then
          v_30 := v_30 + v_pago;
        end if;
        v_mes := to_char(greatest(v_f, v_hoy), 'YYYY-MM');
        v_cal := jsonb_set(v_cal, array[v_mes],
                           jsonb_build_object('monto', coalesce((v_cal -> v_mes ->> 'monto')::numeric, 0) + v_pago,
                                              'n', coalesce((v_cal -> v_mes ->> 'n')::int, 0) + 1));
        v_saldo := v_saldo - v_cap;
        exit when v_cap = 0;    -- (la cuota no cubre ni el interés: no baja nunca; se enseña una y basta)
        v_i := v_i + 1;
        v_k := v_k + 1;
        if v_paso > 0 then
          v_base := (date_trunc('month', p.primer_pago) + make_interval(months => v_k * v_paso))::date;
          v_f := v_base + least(case when v_paso = 1 then p.dia_pago else extract(day from p.primer_pago)::int end,
                                extract(day from (v_base + interval '1 month' - interval '1 day'))::int) - 1;
        else
          v_f := p.primer_pago + v_k * v_dias;
        end if;
      end loop;
    end if;
    v_l := v_l || jsonb_build_object(
      'prestamo_id', p.prestamo_id, 'prestamista', p.prestamista, 'descripcion', p.descripcion, 'estado', p.estado,
      'saldo', p.saldo, 'principal', p.principal, 'pagado_pct', fn_tablero_pct(p.principal - p.saldo, nullif(p.principal, 0)),
      'cuota', p.cuota, 'tasa_anual', p.tasa_anual, 'cuotas_al_anio', p.cuotas_al_anio,
      'cuotas_registradas', p.cuotas, 'ultima_cuota', p.ultima_fecha,
      'porcion_corriente', p.porcion_corriente, 'porcion_largo_plazo', p.porcion_largo_plazo,
      'proxima', v_p1);
  end loop;
  v_libro := -fn_tablero_saldo(array(select distinct u from unnest(v_ctas) u), v_hoy);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'prestamos', 'corte', v_hoy,
    'lista', v_l,
    'totales', jsonb_build_object('saldo', v_total::numeric(14,2), 'n', v_n, 'proxima_fecha', v_prox, 'en_30_dias', v_30::numeric(14,2)),
    'calendario', (select coalesce(jsonb_agg(jsonb_build_object('mes', e.key, 'monto', ((e.value ->> 'monto')::numeric)::numeric(14,2),
                                                                'n', (e.value ->> 'n')::int) order by e.key), '[]'::jsonb)
                     from jsonb_each(v_cal) e),
    'cuadre', jsonb_build_object('ok', v_total = v_libro, 'libro', v_libro, 'suma', v_total::numeric(14,2),
                                 'texto', 'lo que se debe según los préstamos registrados = el saldo de sus cuentas en el libro (si no, la cédula de corte lo explica)'),
    'fuente', 'v_prestamos (c6): lo que se debe es el saldo inicial menos el capital de las cuotas registradas; la próxima cuota sale de su '
              'calendario y de la fórmula del préstamo',
    'ir', case when to_regprocedure('public.fn_cedula_resumen(date)') is not null and cardinality(v_ctas) > 0
               then jsonb_build_object('pagina', 'cedula', 'sub', 'cedula', 'cuenta', v_ctas[1])
               else jsonb_build_object('pagina', 'estados', 'sub', 'balance') end);
end $$;
revoke execute on function public.fn_tablero_prestamos() from public, anon, service_role;
grant  execute on function public.fn_tablero_prestamos() to authenticated;
comment on function public.fn_tablero_prestamos() is 'c16: los préstamos (v_prestamos de c6): {ok, tarjeta, corte, lista: [{prestamo_id, prestamista, descripcion, estado, saldo (lo que se debe), principal, pagado_pct, cuota, tasa_anual, cuotas_al_anio, cuotas_registradas, ultima_cuota, porcion_corriente, porcion_largo_plazo, proxima: {fecha, monto, capital, interes, atrasada, dias}}], totales: {saldo, n, proxima_fecha, en_30_dias}, calendario: [{mes, monto, n}] (las cuotas de los próximos 12 meses; las atrasadas, en el mes de hoy), cuadre: {ok, libro, suma, texto}, fuente, ir}. La fecha de la próxima cuota es la primera del calendario del préstamo posterior a la última registrada (con medio período de margen); su reparto, el de la fórmula de c6. Sin c6: {ok: false, falta: «c6»}. Solo lee. Solo el dueño.';

-- 3.10 · EL SALDO DE CAJA mes a mes, lo que entró y salió, y UNA PROYECCIÓN
-- con lo que de verdad se sabe.
--   LA CAJA es el efectivo del balance de c4 (las cuentas que su mapeo
--   marca «efectivo»: bancos, reserva, Stripe en tránsito, caja chica). El
--   saldo de un mes es el de sus cuentas en negro al terminar el mes (lo que
--   un banco tenga en rojo va aparte, en «sobregiro», como en c4); el del
--   mes en curso, a hoy. Lo que entró y salió es el neto de cada asiento en
--   esas cuentas, sin los pares error-reverso del mismo mes
--   (v_flujo_real_por_mes de c4, al centavo en los meses terminados).
--   Trae los meses que el libro tiene, hasta p_meses: nunca uno inventado.
--   LA PROYECCIÓN (p_proyeccion meses, contando el de hoy; 0 = sin ella):
--   el saldo de hoy + lo que hay POR COBRAR según su vencimiento − lo que
--   hay POR PAGAR según el suyo − las CUOTAS de los préstamos. Lo ya vencido
--   va en el mes de hoy (el supuesto: se cobra y se paga ya). No incluye
--   nada que todavía no exista en el libro. Si no hay nada por cobrar, por
--   pagar ni cuotas, NO HAY PROYECCIÓN.
--   p_calendario (opcional, lo pasa fn_tablero para no calcular dos veces):
--   {"cobrar": […], "pagar": […], "prestamos": […]}, los «calendario» de las
--   tarjetas por_cobrar, por_pagar y prestamos.
create or replace function public.fn_tablero_caja(p_meses int default 12, p_proyeccion int default 3, p_calendario jsonb default null)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_lib    jsonb := fn_tablero_libro();
  v_libro  date := (v_lib ->> 'desde')::date;
  v_meses  int := coalesce(p_meses, 12);
  v_proy   int := coalesce(p_proyeccion, 3);
  v_ult    date;
  v_m0     date;
  v_serie  jsonb;
  v_ctas   jsonb;
  v_saldo  numeric;
  v_sobre  numeric;
  v_neto   numeric;
  v_cal    jsonb := coalesce(p_calendario, '{}'::jsonb);
  v_x      jsonb;
  v_pm     jsonb := '[]'::jsonb;
  v_hay    boolean := false;
  v_acum   numeric;
  v_falta  text[] := '{}';
  v_despues jsonb;
  r        record;
begin
  perform fn_tablero_exigir_dueno();
  if v_meses < 1 or v_meses > 36 then
    raise exception using errcode = '22023', message = format('Los meses de la serie van de 1 a 36 (llegó %s).', v_meses);
  end if;
  if v_proy < 0 or v_proy > 12 then
    raise exception using errcode = '22023', message = format('Los meses de la proyección van de 0 a 12 (llegó %s).', v_proy);
  end if;
  if jsonb_typeof(v_cal) <> 'object' then
    raise exception using errcode = '22023', message = 'p_calendario es un objeto ({"cobrar": […], "pagar": […], "prestamos": […]}).';
  end if;
  if v_libro is null then
    return fn_tablero_no('caja', 'El libro no tiene períodos todavía.');
  end if;
  v_ult := date_trunc('month', v_hoy)::date;
  v_m0 := greatest(date_trunc('month', v_libro)::date, (v_ult - make_interval(months => v_meses - 1))::date);
  if v_m0 > v_ult then
    return fn_tablero_no('caja', format('El libro empieza el %s: todavía no hay ningún mes que enseñar.', fn_tablero_dia(v_libro)));
  end if;
  with ef as materialized (
    select m.cuenta, m.nombre, coalesce(m.caja, false) as caja from fn_tablero_mapa() m where m.efectivo
  ), li as materialized (
    select l.cuenta, l.monto, a.id, date_trunc('month', a.fecha_contable)::date as mes, a.camino, a.reversa_a
      from asiento_lineas l
      join asientos a on a.id = l.asiento_id
     where l.cuenta in (select ef.cuenta from ef) and a.fecha_contable <= v_hoy
  ), ms as (
    select g::date as mes from generate_series(v_m0, v_ult, interval '1 month') g
  ), sal as (
    select ms.mes, ef.cuenta,
           coalesce(sum(li.monto) filter (where li.mes <= ms.mes), 0) as s1,
           coalesce(sum(li.monto) filter (where li.mes < ms.mes), 0) as s0
      from ms cross join ef left join li on li.cuenta = ef.cuenta
     group by ms.mes, ef.cuenta
  ), tot as (
    select sal.mes, sum(greatest(sal.s0, 0)) as inicial, sum(greatest(sal.s1, 0)) as final, -sum(least(sal.s1, 0)) as sobregiro
      from sal group by sal.mes
  ), mov as (
    select li.id, li.mes, sum(li.monto) as neto, min(li.camino) as camino, (array_agg(li.reversa_a))[1] as reversa_a
      from li where li.mes >= v_m0 group by li.id, li.mes having sum(li.monto) <> 0
  ), par as (
    select mov.mes, mov.neto,
           (mov.camino = 'reverso' and exists (select 1 from asientos o
                                                where o.id = mov.reversa_a and date_trunc('month', o.fecha_contable)::date = mov.mes))
           or exists (select 1 from asientos rv
                       where rv.reversa_a = mov.id and rv.camino = 'reverso' and date_trunc('month', rv.fecha_contable)::date = mov.mes) as par
      from mov
  ), es as (
    select par.mes, coalesce(sum(par.neto) filter (where par.neto > 0 and not par.par), 0) as entradas,
           coalesce(-sum(par.neto) filter (where par.neto < 0 and not par.par), 0) as salidas, count(*) as n
      from par group by par.mes
  )
  select jsonb_agg(jsonb_build_object(
           'mes', to_char(tot.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(tot.mes),
           'corto', (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from tot.mes)::int],
           'inicial', tot.inicial::numeric(14,2), 'entradas', coalesce(es.entradas, 0)::numeric(14,2),
           'salidas', coalesce(es.salidas, 0)::numeric(14,2),
           'neto', (coalesce(es.entradas, 0) - coalesce(es.salidas, 0))::numeric(14,2),
           'final', tot.final::numeric(14,2), 'sobregiro', tot.sobregiro::numeric(14,2),
           'movimientos', coalesce(es.n, 0), 'en_curso', tot.mes = v_ult,
           'al', least((tot.mes + interval '1 month')::date - 1, v_hoy)) order by tot.mes),
         (select coalesce(jsonb_agg(jsonb_build_object('cuenta', q.cuenta, 'nombre', q.nombre, 'saldo', q.saldo::numeric(14,2), 'caja', q.caja)
                                    order by q.cuenta), '[]'::jsonb)
            from (select ef.cuenta, ef.nombre, ef.caja, coalesce(sum(li.monto), 0) as saldo
                    from ef left join li on li.cuenta = ef.cuenta group by ef.cuenta, ef.nombre, ef.caja) q
           where q.saldo <> 0)
    into v_serie, v_ctas
    from tot left join es on es.mes = tot.mes;
  v_saldo := (v_serie -> -1 ->> 'final')::numeric;
  v_sobre := (v_serie -> -1 ->> 'sobregiro')::numeric;
  v_neto := v_saldo - v_sobre;
  -- LA PROYECCIÓN
  if v_proy > 0 then
    if not v_cal ? 'cobrar' then
      begin
        v_cal := v_cal || jsonb_build_object('cobrar', fn_tablero_antiguedad('cobrar') -> 'calendario');
      exception when others then v_falta := v_falta || 'lo que hay por cobrar'::text;
      end;
    end if;
    if not v_cal ? 'pagar' then
      begin
        v_cal := v_cal || jsonb_build_object('pagar', fn_tablero_antiguedad('pagar') -> 'calendario');
      exception when others then v_falta := v_falta || 'lo que hay por pagar'::text;
      end;
    end if;
    if not v_cal ? 'prestamos' then
      begin
        v_x := fn_tablero_prestamos();
        if (v_x ->> 'ok')::boolean then
          v_cal := v_cal || jsonb_build_object('prestamos', v_x -> 'calendario');
        else
          v_falta := v_falta || 'las cuotas de los préstamos (sin c6)'::text;
        end if;
      exception when others then v_falta := v_falta || 'las cuotas de los préstamos'::text;
      end;
    end if;
    v_acum := v_neto;
    for r in
      select g::date as mes,
             coalesce((select sum((e ->> 'monto')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'cobrar', '[]'::jsonb)) e
                        where e ->> 'mes' = to_char(g, 'YYYY-MM')), 0) as cobrar,
             coalesce((select sum((e ->> 'monto')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'pagar', '[]'::jsonb)) e
                        where e ->> 'mes' = to_char(g, 'YYYY-MM')), 0) as pagar,
             coalesce((select sum((e ->> 'monto')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'prestamos', '[]'::jsonb)) e
                        where e ->> 'mes' = to_char(g, 'YYYY-MM')), 0) as cuotas,
             coalesce((select sum((e ->> 'vencido')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'cobrar', '[]'::jsonb)) e
                        where e ->> 'mes' = to_char(g, 'YYYY-MM')), 0) as cobrar_vencido,
             coalesce((select sum((e ->> 'vencido')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'pagar', '[]'::jsonb)) e
                        where e ->> 'mes' = to_char(g, 'YYYY-MM')), 0) as pagar_vencido
        from generate_series(v_ult, (v_ult + make_interval(months => v_proy - 1))::date, interval '1 month') g
    loop
      v_acum := v_acum + r.cobrar - r.pagar - r.cuotas;
      v_hay := v_hay or r.cobrar <> 0 or r.pagar <> 0 or r.cuotas <> 0;
      v_pm := v_pm || jsonb_build_object(
        'mes', to_char(r.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(r.mes),
        'corto', (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from r.mes)::int],
        'por_cobrar', r.cobrar::numeric(14,2), 'por_pagar', r.pagar::numeric(14,2), 'prestamos', r.cuotas::numeric(14,2),
        'por_cobrar_vencido', r.cobrar_vencido::numeric(14,2), 'por_pagar_vencido', r.pagar_vencido::numeric(14,2),
        'neto', (r.cobrar - r.pagar - r.cuotas)::numeric(14,2), 'saldo', v_acum::numeric(14,2),
        'al', (r.mes + interval '1 month')::date - 1, 'en_curso', r.mes = v_ult);
    end loop;
    -- lo que vence después del último mes proyectado (se dice; no entra)
    select jsonb_build_object(
             'por_cobrar', coalesce((select sum((e ->> 'monto')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'cobrar', '[]'::jsonb)) e
                                      where e ->> 'mes' > to_char((v_ult + make_interval(months => v_proy - 1))::date, 'YYYY-MM')), 0)::numeric(14,2),
             'por_pagar', coalesce((select sum((e ->> 'monto')::numeric) from jsonb_array_elements(coalesce(v_cal -> 'pagar', '[]'::jsonb)) e
                                     where e ->> 'mes' > to_char((v_ult + make_interval(months => v_proy - 1))::date, 'YYYY-MM')), 0)::numeric(14,2))
      into v_despues;
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'caja', 'corte', v_hoy,
    'hoy', jsonb_build_object('saldo', v_saldo, 'sobregiro', v_sobre, 'neto', v_neto, 'cuentas', v_ctas),
    'meses', v_serie,
    'meses_pedidos', v_meses, 'meses_con_libro', jsonb_array_length(v_serie),
    'apertura', jsonb_build_object('fecha', v_m0 - 1, 'saldo', v_serie -> 0 -> 'inicial',
                                   'es_la_apertura', v_m0 = date_trunc('month', v_libro)::date),
    'libro', v_lib,
    'proyeccion', case
        when v_proy = 0 then jsonb_build_object('hay', false, 'motivo', 'No se pidió.')
        when not v_hay then jsonb_build_object('hay', false,
               'motivo', 'No hay nada por cobrar, por pagar ni cuotas de préstamos con fecha en estos meses: sin eso no hay nada cierto que proyectar.'
                         || case when cardinality(v_falta) > 0 then ' (No se pudo leer: ' || array_to_string(v_falta, ', ') || '.)' else '' end)
        else jsonb_build_object(
               'hay', true, 'es_proyeccion', true, 'desde', v_hoy, 'saldo_inicial', v_neto, 'meses', v_pm,
               'despues', v_despues,
               'supuestos', jsonb_build_array(
                   'Sale del saldo de caja de hoy.',
                   'Lo que hay por cobrar entra el mes en que vence; lo ya vencido, este mes (como si se cobrara ya).',
                   'Lo que hay por pagar sale el mes en que vence; lo ya vencido, este mes.',
                   'Las cuotas de los préstamos salen en su fecha, con la cuota de hoy.'),
               'no_incluye', jsonb_build_array(
                   'la nómina y los gastos que todavía no están en el libro',
                   'lo que se debe en las tarjetas de crédito',
                   'las facturas que todavía no se han emitido',
                   'la retención por cobrar y por pagar (no tiene fecha: se salda al terminar la obra)',
                   'los impuestos')
                   || case when cardinality(v_falta) > 0 then to_jsonb(v_falta) else '[]'::jsonb end,
               'texto', 'Proyección, no un hecho: el saldo de hoy más lo que ya se sabe que entra y sale. Nada que todavía no esté en el libro.') end,
    'nota', case when jsonb_array_length(v_serie) < v_meses then v_lib ->> 'texto' end,
    'fuente', 'el libro: las cuentas de efectivo del balance (c4), por la fecha de cada asiento; lo mismo que el flujo de caja real por mes',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'flujo'));
end $$;
revoke execute on function public.fn_tablero_caja(int, int, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_caja(int, int, jsonb) to authenticated;
comment on function public.fn_tablero_caja(int, int, jsonb) is 'c16: el saldo de caja mes a mes y una proyección: {ok, tarjeta, corte, hoy: {saldo (el efectivo en negro), sobregiro (lo que un banco tenga en rojo), neto, cuentas: [{cuenta, nombre, saldo, caja}]}, meses: [{mes (AAAA-MM), etiqueta, corto, inicial, entradas, salidas, neto, final, sobregiro, movimientos, en_curso, al}] (solo los meses que el libro tiene, hasta p_meses; el de hoy, a hoy), meses_pedidos, meses_con_libro, apertura: {fecha, saldo, es_la_apertura} (el saldo con que empieza la serie), libro, proyeccion: {hay, es_proyeccion, desde, saldo_inicial, meses: [{mes, etiqueta, corto, por_cobrar, por_pagar, prestamos, por_cobrar_vencido, por_pagar_vencido (lo que de eso ya estaba vencido hoy), neto, saldo, al, en_curso}], despues: {por_cobrar, por_pagar} (lo que vence más tarde), supuestos: […], no_incluye: […], texto} o {hay: false, motivo}, nota, fuente, ir}. La caja es el efectivo del balance de c4; cada mes terminado cuadra con v_flujo_real_por_mes. p_calendario lo pasa fn_tablero (los «calendario» de por_cobrar, por_pagar y prestamos). 22023 con meses fuera de rango. Solo lee. Solo el dueño.';

-- 3.11 · LAS CONEXIONES con el mundo: cada banco por Plaid (c7), Stripe (p1)
-- y la IA contable (c8). estado: conectada | problema | sin_usar | apagada.
create or replace function public.fn_tablero_conexiones() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  v_l     jsonb := '[]'::jsonb;
  v_des   int := 0;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if (v_capas ->> 'c7')::boolean then
    for r in
      select c.id, coalesce(c.institucion, 'Un banco') as institucion, c.estado, c.ultimo_sync, c.ultimo_error, c.cursor is not null as sincronizada,
             (select count(*) from jsonb_array_elements(c.cuentas) x where x.value ->> 'cuenta' is null) as sin_fijar,
             (select count(*) from jsonb_array_elements(c.cuentas) x where x.value ->> 'cuenta' is not null and x.value ->> 'cuenta' <> 'ignorar') as fijadas
        from plaid_conexiones c
       where c.estado <> 'desconectada'
       order by c.creado_el
    loop
      v_l := v_l || jsonb_build_object(
        'clave', 'plaid:' || r.id, 'tipo', 'banco', 'nombre', r.institucion, 'servicio', 'Plaid',
        'estado', case when r.estado = 'error' or r.sin_fijar > 0 then 'problema'
                       when r.ultimo_sync is null then 'sin_usar' else 'conectada' end,
        'detalle', case when r.estado = 'error' then 'pide volver a conectar' || coalesce(': ' || nullif(btrim(r.ultimo_error), ''), '')
                        when r.sin_fijar > 0 then format('%s cuenta%s del banco sin fijar a una cuenta del plan: hasta fijarla%s no se sincroniza nada',
                                                         r.sin_fijar, case when r.sin_fijar = 1 then '' else 's' end, case when r.sin_fijar = 1 then '' else 's' end)
                        when r.ultimo_sync is null then 'conectada, todavía sin sincronizar'
                        else format('%s cuenta%s al día', r.fijadas, case when r.fijadas = 1 then '' else 's' end) end,
        'actualizado_el', r.ultimo_sync,
        'horas', case when r.ultimo_sync is not null then floor(extract(epoch from now() - r.ultimo_sync) / 3600)::int end,
        'ir', jsonb_build_object('pagina', 'conexiones'));
    end loop;
    select count(*) into v_des from plaid_conexiones c where c.estado = 'desconectada';
  end if;
  if (v_capas ->> 'p1')::boolean then
    select c.modo, c.rutina_activa, c.ultimo_evento_el, c.ultimo_barrido_el, c.ultimo_barrido_completo_el, c.ultimo_error, c.ultimo_error_el,
           (select count(*) from stripe_pagos) as pagos
      into r
      from stripe_config c where c.id = 1;
    if found then
      v_l := v_l || jsonb_build_object(
        'clave', 'stripe', 'tipo', 'cobros', 'nombre', 'Stripe', 'servicio', 'Cobros en línea',
        'estado', case when not r.rutina_activa then 'apagada'
                       when r.ultimo_error is not null
                            and (r.ultimo_barrido_completo_el is null or r.ultimo_error_el >= r.ultimo_barrido_completo_el) then 'problema'
                       when r.pagos = 0 and r.ultimo_evento_el is null and r.ultimo_barrido_el is null then 'sin_usar'
                       else 'conectada' end,
        'detalle', case when not r.rutina_activa then 'la rutina que habla con Stripe está apagada'
                        when r.ultimo_error is not null
                             and (r.ultimo_barrido_completo_el is null or r.ultimo_error_el >= r.ultimo_barrido_completo_el)
                          then 'el último intento falló: ' || left(r.ultimo_error, 200)
                        when r.pagos = 0 and r.ultimo_evento_el is null and r.ultimo_barrido_el is null then 'instalado, todavía sin ningún cobro'
                        else case when r.modo = 'prueba' then 'en modo de prueba' else 'al día' end end,
        'modo', nullif(r.modo, ''),
        'actualizado_el', greatest(r.ultimo_evento_el, r.ultimo_barrido_el),
        'horas', case when greatest(r.ultimo_evento_el, r.ultimo_barrido_el) is not null
                      then floor(extract(epoch from now() - greatest(r.ultimo_evento_el, r.ultimo_barrido_el)) / 3600)::int end,
        'ir', jsonb_build_object('pagina', 'cobros'));
    end if;
  end if;
  if (v_capas ->> 'c8')::boolean then
    select c.activa, c.rutina_activa, c.ultima_rafaga_el, c.ultimo_error, c.ultimo_error_el, c.rutina_ultima_el, c.rutina_ultimo_error into r
      from contador_config c where c.id = 1;
    if found then
      v_l := v_l || jsonb_build_object(
        'clave', 'ia', 'tipo', 'ia', 'nombre', 'IA contable', 'servicio', 'Propuestas en la Bandeja',
        'estado', case when not r.activa then 'apagada'
                       when r.ultimo_error is not null and (r.ultima_rafaga_el is null or r.ultimo_error_el >= r.ultima_rafaga_el) then 'problema'
                       when r.ultima_rafaga_el is null and r.rutina_ultima_el is null then 'sin_usar'
                       else 'conectada' end,
        'detalle', case when not r.activa then 'apagada: la Bandeja sigue como siempre, sin propuestas'
                        when r.ultimo_error is not null and (r.ultima_rafaga_el is null or r.ultimo_error_el >= r.ultima_rafaga_el)
                          then 'la última ráfaga falló: ' || left(r.ultimo_error, 200)
                        when r.ultima_rafaga_el is null and r.rutina_ultima_el is null then 'encendida, todavía sin ninguna ráfaga'
                        else 'al día' end,
        'actualizado_el', greatest(r.ultima_rafaga_el, r.rutina_ultima_el),
        'horas', case when greatest(r.ultima_rafaga_el, r.rutina_ultima_el) is not null
                      then floor(extract(epoch from now() - greatest(r.ultima_rafaga_el, r.rutina_ultima_el)) / 3600)::int end,
        'ir', jsonb_build_object('pagina', 'bandeja'));
    end if;
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'conexiones', 'corte', v_hoy,
    'lista', v_l,
    'totales', jsonb_build_object(
        'total', jsonb_array_length(v_l),
        'conectadas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'conectada'),
        'con_problemas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'problema'),
        'sin_usar', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'sin_usar'),
        'apagadas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'apagada'),
        'bancos_desconectados', v_des),
    'faltan', (select coalesce(jsonb_agg(k.capa), '[]'::jsonb)
                 from (values ('c7'), ('p1'), ('c8')) k(capa) where not (v_capas ->> k.capa)::boolean),
    'fuente', 'las conexiones de Plaid (c7), la configuración de Stripe (p1) y la de la IA contable (c8)',
    'ir', jsonb_build_object('pagina', 'conexiones'));
end $$;
revoke execute on function public.fn_tablero_conexiones() from public, anon, service_role;
grant  execute on function public.fn_tablero_conexiones() to authenticated;
comment on function public.fn_tablero_conexiones() is 'c16: las conexiones con el mundo: {ok, tarjeta, corte, lista: [{clave (plaid:<id> | stripe | ia), tipo (banco | cobros | ia), nombre, servicio, estado (conectada | problema | sin_usar | apagada), detalle (en llano), modo?, actualizado_el, horas, ir}], totales: {total, conectadas, con_problemas, sin_usar, apagadas, bancos_desconectados}, faltan: [las capas que no están], fuente, ir}. Solo lee. Solo el dueño.';

-- 3.12 · LOS COBROS EN LÍNEA (Stripe, p1): lo cobrado que falta depositar,
-- los depósitos en camino al banco, los pagos por cuenta de banco que
-- todavía no liquidan y los depósitos que ya llegaron.
create or replace function public.fn_tablero_cobros_en_linea() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  c       record;
  r       record;
  v_saldo numeric;
begin
  perform fn_tablero_exigir_dueno();
  if not (v_capas ->> 'p1')::boolean then
    return fn_tablero_no('cobros_en_linea', 'Los cobros en línea (p1, Stripe) no están en esta base.', 'p1');
  end if;
  select k.cuenta_puente, k.modo, k.ultimo_evento_el into c from stripe_config k where k.id = 1;
  if not found then
    return fn_tablero_no('cobros_en_linea', 'Los cobros en línea están pegados pero sin configurar (stripe_config no tiene su fila).', 'p1');
  end if;
  select (select coalesce(sum(v.falta_depositar), 0)::numeric(14,2) from v_stripe_pagos v) as por_dep,
         (select count(*) from v_stripe_pagos v where v.falta_depositar <> 0) as n_por_dep,
         (select coalesce(sum(s.monto), 0)::numeric(14,2) from stripe_pagos s where s.estado in ('iniciado', 'en_camino')) as pagos_camino,
         (select count(*) from stripe_pagos s where s.estado in ('iniciado', 'en_camino')) as n_pagos_camino,
         (select coalesce(sum(q.monto), 0)::numeric(14,2) from stripe_payouts q where q.estado = 'en_camino') as dep_camino,
         (select count(*) from stripe_payouts q where q.estado = 'en_camino') as n_dep_camino,
         (select min(q.llegada) from stripe_payouts q where q.estado = 'en_camino') as llegada,
         (select coalesce(sum(q.monto), 0)::numeric(14,2) from stripe_payouts q where q.estado = 'asentado' and q.llegada > v_hoy - 30 and q.llegada <= v_hoy) as dep_30,
         (select count(*) from stripe_payouts q where q.estado = 'asentado' and q.llegada > v_hoy - 30 and q.llegada <= v_hoy) as n_dep_30,
         (select coalesce(sum(q.monto), 0)::numeric(14,2) from stripe_payouts q where q.estado = 'asentado' and q.llegada = v_hoy) as dep_hoy,
         (select count(*) from stripe_payouts q where q.estado = 'asentado' and q.llegada = v_hoy) as n_dep_hoy,
         (select count(*) from stripe_payouts q where q.estado in ('esperando_composicion', 'esperando_cobros', 'revisar', 'fallido')) as dep_revisar,
         (select count(*) from stripe_pagos s where s.estado in ('revisar', 'en_disputa')) as pagos_revisar,
         (select count(*) from stripe_enlaces e where e.estado = 'activo') as enlaces
    into r;
  v_saldo := fn_tablero_saldo(array[c.cuenta_puente]);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'cobros_en_linea', 'corte', v_hoy, 'modo', nullif(c.modo, ''),
    'por_depositar', jsonb_build_object('monto', r.por_dep, 'n', r.n_por_dep),
    'en_camino_al_banco', jsonb_build_object('monto', r.dep_camino, 'n', r.n_dep_camino, 'llegada', r.llegada),
    'pagos_en_camino', jsonb_build_object('monto', r.pagos_camino, 'n', r.n_pagos_camino),
    'depositado_hoy', jsonb_build_object('monto', r.dep_hoy, 'n', r.n_dep_hoy),
    'depositado_30', jsonb_build_object('monto', r.dep_30, 'n', r.n_dep_30),
    'ultimo_deposito', (select jsonb_build_object('fecha', q.llegada, 'monto', q.monto)
                          from stripe_payouts q where q.estado = 'asentado' order by q.llegada desc, q.creado_el desc limit 1),
    'por_revisar', jsonb_build_object('pagos', r.pagos_revisar, 'depositos', r.dep_revisar),
    'enlaces_activos', r.enlaces, 'ultimo_evento_el', c.ultimo_evento_el,
    'cuadre', jsonb_build_object('ok', v_saldo = r.por_dep, 'libro', v_saldo, 'suma', r.por_dep,
                                 'texto', 'lo cobrado en Stripe que falta depositar = el saldo de la cuenta de Stripe en el libro'),
    'fuente', 'los pagos y los depósitos de Stripe (p1): por depositar es lo cobrado que ningún depósito ha liquidado todavía',
    'ir', jsonb_build_object('pagina', 'cobros'));
end $$;
revoke execute on function public.fn_tablero_cobros_en_linea() from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros_en_linea() to authenticated;
comment on function public.fn_tablero_cobros_en_linea() is 'c16: los cobros en línea (Stripe, p1): {ok, tarjeta, corte, modo, por_depositar: {monto, n} (cobrado en Stripe, falta que lo deposite), en_camino_al_banco: {monto, n, llegada} (depósitos que Stripe ya mandó y no han llegado), pagos_en_camino: {monto, n} (pagos por cuenta de banco que todavía no liquidan: sin asiento), depositado_hoy: {monto, n}, depositado_30: {monto, n} (los depósitos que llegaron en 30 días), ultimo_deposito: {fecha, monto}, por_revisar: {pagos, depositos}, enlaces_activos, ultimo_evento_el, cuadre: {ok, libro, suma, texto}, fuente, ir}. Sin p1: {ok: false, falta: «p1»}. Solo lee. Solo el dueño.';

-- 3.13 · EL USE TAX (el DR-15 de c9): el mes en curso y el mes pasado, y lo
-- que se debe hoy. Las ventas gravables y el sales tax cobrado todavía no
-- los separa nadie: la nota de c9 lo dice.
create or replace function public.fn_tablero_use_tax() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  v_cta   text := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
  v_m     jsonb;
  v_nota  text;
begin
  perform fn_tablero_exigir_dueno();
  if not (v_capas ->> 'c9')::boolean then
    return fn_tablero_no('use_tax', 'El cierre del mes (c9) no está en esta base: el DR-15 se arma ahí.', 'c9');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'periodo', d.periodo, 'nombre', fn_tablero_mes_largo(d.desde), 'desde', d.desde, 'hasta', d.hasta,
           'en_curso', v_hoy between d.desde and d.hasta,
           'compras', d.compras_use_tax_n, 'base', d.compras_use_tax_base,
           'cargado', d.use_tax_cargado_2300, 'pagado', d.use_tax_pagado_2300, 'saldo_al_cierre', d.use_tax_saldo_2300,
           'ir', jsonb_build_object('pagina', 'cierre', 'sub', 'dr15', 'periodo', d.periodo)) order by d.desde desc), '[]'::jsonb),
         min(d.nota)
    into v_m, v_nota
    from v_dr15_mes d
   where d.periodo in (to_char(v_hoy, 'YYYY-MM'), to_char(v_hoy - interval '1 month', 'YYYY-MM'));
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'use_tax', 'corte', v_hoy, 'cuenta', v_cta,
    'por_pagar', (-fn_tablero_saldo(array[v_cta], v_hoy))::numeric(14,2),
    'meses', v_m,
    'ventas_gravables', null, 'sales_tax_cobrado', null,
    'nota', coalesce(v_nota, 'El libro no tiene abierto ni el mes de hoy ni el anterior.'),
    'fuente', 'el DR-15 de cada mes (v_dr15_mes de c9) y el saldo de la cuenta de use tax en el libro',
    'ir', jsonb_build_object('pagina', 'cierre', 'sub', 'dr15'));
end $$;
revoke execute on function public.fn_tablero_use_tax() from public, anon, service_role;
grant  execute on function public.fn_tablero_use_tax() to authenticated;
comment on function public.fn_tablero_use_tax() is 'c16: el use tax (el DR-15 de c9): {ok, tarjeta, corte, cuenta, por_pagar (lo que se debe hoy en la cuenta de use tax), meses: [{periodo, nombre, desde, hasta, en_curso, compras, base, cargado, pagado, saldo_al_cierre, ir}] (el mes de hoy y el anterior, de v_dr15_mes), ventas_gravables y sales_tax_cobrado (nulos: todavía no se separan), nota (la de c9), fuente, ir}. Sin c9: {ok: false, falta: «c9»}. Solo lee. Solo el dueño.';

-- 3.14 · LO QUE EL LIBRO SABE DE LAS OBRAS: el WIP del mes que toca (c12) y
-- el costo por obra (c10), las de más ingreso.
create or replace function public.fn_tablero_obras(p_top int default 5) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  v_top   int := coalesce(p_top, 5);
  v_wip   jsonb;
  v_w     jsonb;
  v_costo jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if v_top < 1 or v_top > 50 then
    raise exception using errcode = '22023', message = format('Las obras de la lista van de 1 a 50 (llegó %s).', v_top);
  end if;
  if not (v_capas ->> 'c12')::boolean and not (v_capas ->> 'c10')::boolean then
    return fn_tablero_no('obras', 'Ni el WIP (c12) ni el costo por obra (c10) están en esta base.', 'c10');
  end if;
  if (v_capas ->> 'c12')::boolean then
    begin
      execute 'select public.fn_wip_resumen(null)' into v_w;
      v_wip := jsonb_build_object(
        'ok', true, 'periodo', v_w -> 'periodo', 'nombre', v_w -> 'nombre', 'cerrado', v_w -> 'cerrado',
        'obras', v_w -> 'obras',
        'sub_facturado', v_w -> 'totales' -> 'sub_facturado', 'sobre_facturado', v_w -> 'totales' -> 'sobre_facturado',
        'ingreso_ganado', v_w -> 'totales' -> 'ingreso_ganado', 'facturado', v_w -> 'totales' -> 'facturado_fecha',
        'precio_contrato', v_w -> 'totales' -> 'precio_contrato', 'costo_fecha', v_w -> 'totales' -> 'costo_fecha',
        'costo_estimado', v_w -> 'totales' -> 'costo_estimado', 'pct_avance', v_w -> 'totales' -> 'pct_avance',
        'perdida_provision', v_w -> 'totales' -> 'perdida_provision',
        'ajuste', v_w -> 'ajuste', 'nota', v_w -> 'nota',
        'ir', jsonb_build_object('pagina', 'wip', 'sub', 'mes', 'periodo', v_w -> 'periodo'));
    exception when others then
      v_wip := fn_tablero_no('obras', 'El WIP no contestó: ' || sqlerrm, null, sqlstate);
    end;
  else
    v_wip := fn_tablero_no('obras', 'El WIP (c12) no está en esta base.', 'c12');
  end if;
  if (v_capas ->> 'c10')::boolean then
    begin
      with x as materialized (
        select z.proyecto_id, z.obra, z.cliente, z.estado, z.parcial, z.contrato, z.ingreso_libro, z.costo_real, z.margen_real,
               z.margen_real_pct
          from v_margen_obra z
         where coalesce(z.ingreso_libro, 0) <> 0 or coalesce(z.costo_real, 0) <> 0
      )
      select jsonb_build_object(
               'ok', true,
               'lista', coalesce((select jsonb_agg(jsonb_build_object(
                                    'proyecto_id', y.proyecto_id, 'obra', y.obra, 'cliente', y.cliente, 'estado', y.estado, 'parcial', y.parcial,
                                    'contrato', y.contrato, 'ingreso', y.ingreso_libro, 'costo', y.costo_real, 'margen', y.margen_real,
                                    'margen_pct', y.margen_real_pct,
                                    'ir', jsonb_build_object('pagina', 'obras', 'sub', 'obras', 'sel', y.proyecto_id))
                                    order by y.ingreso_libro desc nulls last, y.obra)
                                    from (select * from x order by x.ingreso_libro desc nulls last, x.obra limit v_top) y), '[]'::jsonb),
               'totales', (select jsonb_build_object(
                   'obras', count(*),
                   'ingreso', coalesce(sum(x.ingreso_libro), 0)::numeric(14,2),
                   'costo', coalesce(sum(x.costo_real), 0)::numeric(14,2),
                   'margen', (coalesce(sum(x.ingreso_libro), 0) - coalesce(sum(x.costo_real), 0))::numeric(14,2),
                   'margen_pct', fn_tablero_pct(coalesce(sum(x.ingreso_libro), 0) - coalesce(sum(x.costo_real), 0), nullif(sum(x.ingreso_libro), 0)),
                   'parciales', count(*) filter (where x.parcial)) from x),
               'nota', 'Lo del libro, desde que empieza: una obra «parcial» ya andaba antes y lo de antes vive en QuickBooks.',
               'ir', jsonb_build_object('pagina', 'obras', 'sub', 'obras'))
        into v_costo;
    exception when others then
      v_costo := fn_tablero_no('obras', 'El costo por obra no contestó: ' || sqlerrm, null, sqlstate);
    end;
  else
    v_costo := fn_tablero_no('obras', 'El costo por obra (c10) no está en esta base.', 'c10');
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'obras', 'corte', v_hoy, 'wip', v_wip - 'tarjeta', 'costo', v_costo - 'tarjeta',
    'fuente', 'el WIP del mes que toca (c12) y el costo por obra del libro (c10)',
    'ir', jsonb_build_object('pagina', 'obras', 'sub', 'obras'));
end $$;
revoke execute on function public.fn_tablero_obras(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_obras(int) to authenticated;
comment on function public.fn_tablero_obras(int) is 'c16: lo que el libro sabe de las obras: {ok, tarjeta, corte, wip: {ok, periodo, nombre, cerrado, obras: {total, listas, pendientes, …}, sub_facturado, sobre_facturado, ingreso_ganado, facturado, precio_contrato, costo_fecha, costo_estimado, pct_avance, perdida_provision, ajuste, nota, ir} (el WIP del mes que toca, de fn_wip_resumen de c12), costo: {ok, lista: [{proyecto_id, obra, cliente, estado, parcial, contrato, ingreso, costo, margen, margen_pct, ir}] (las p_top de más ingreso, de v_margen_obra de c10), totales: {obras, ingreso, costo, margen, margen_pct, parciales}, nota, ir}, fuente, ir}. La mitad que no está (o que falla) trae su {ok: false, motivo}; sin ninguna de las dos: {ok: false, falta}. Solo lee. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 4. fn_tablero(p): todas las tarjetas en una llamada, cada una en su clave.
--    La que falla o cuya capa no está trae {ok: false, motivo} y las demás
--    siguen. Con su tope por reloj (como fn_estados_control de c4): lo que
--    no alcanza sale «sigue» y la pantalla lo vuelve a pedir.
-- ---------------------------------------------------------------------
create or replace function public.fn_tablero(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_t0      timestamptz := clock_timestamp();
  v_t1      timestamptz;
  v_p       jsonb := coalesce(p, '{}'::jsonb);
  -- el orden de la portada (y el de «tarjetas»)
  c_todas   constant text[] := array['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar',
                                     'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras'];
  -- el orden en que se calculan: lo de arriba de la portada primero, y antes de la caja las tres de las que sale su proyección
  c_orden   constant text[] := array['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'por_cobrar', 'por_pagar', 'prestamos', 'caja',
                                     'facturas', 'ventas', 'conexiones', 'cobros_en_linea', 'use_tax', 'obras'];
  v_pedidas text[];
  v_tope    int;
  v_r       jsonb := '{}'::jsonb;
  v_sigue   text[] := '{}';
  v_cal     jsonb := '{}'::jsonb;
  v_x       jsonb;
  v_o       jsonb;
  v_t       text;
  v_mal     text;
begin
  perform fn_tablero_exigir_dueno();
  if jsonb_typeof(v_p) <> 'object' then
    raise exception using errcode = '22023', message = 'p es un objeto: {"tarjetas": […], "resultados": {"periodo": "mes"}, …} (o vacío).';
  end if;
  select string_agg(k, ', ' order by k) into v_mal
    from jsonb_object_keys(v_p) k
   where k not in ('tarjetas', 'tope_ms', 'cobros', 'facturas', 'resultados', 'gastos', 'caja', 'ventas', 'obras');
  if v_mal is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida: %s. Las que hay: tarjetas, tope_ms, cobros, facturas, resultados, gastos, caja, ventas, obras.', left(v_mal, 120));
  end if;
  select string_agg(k, ', ' order by k) into v_mal
    from jsonb_object_keys(v_p) k
   where k in ('cobros', 'facturas', 'resultados', 'gastos', 'caja', 'ventas', 'obras') and jsonb_typeof(v_p -> k) <> 'object';
  if v_mal is not null then
    raise exception using errcode = '22023', message = format('Lo de cada tarjeta va en un objeto ({"dias": 30}): %s.', left(v_mal, 120));
  end if;
  if v_p ? 'tarjetas' and v_p -> 'tarjetas' <> 'null'::jsonb then
    if jsonb_typeof(v_p -> 'tarjetas') <> 'array' then
      raise exception using errcode = '22023', message = '«tarjetas» es una lista: ["cobros", "bancos", …].';
    end if;
    select string_agg(left(e #>> '{}', 40), ', ') into v_mal
      from jsonb_array_elements(v_p -> 'tarjetas') e
     where jsonb_typeof(e) <> 'string' or not (e #>> '{}' = any (c_todas));
    if v_mal is not null then
      raise exception using errcode = '22023',
        message = format('No conozco la tarjeta «%s». Las que hay: %s.', v_mal, array_to_string(c_todas, ', '));
    end if;
    select coalesce(array_agg(t.x order by t.o), '{}') into v_pedidas
      from unnest(c_todas) with ordinality t(x, o)
     where v_p -> 'tarjetas' ? t.x;
  else
    v_pedidas := c_todas;
  end if;
  if v_p ? 'tope_ms' and v_p -> 'tope_ms' <> 'null'::jsonb then
    if jsonb_typeof(v_p -> 'tope_ms') <> 'number' or (v_p ->> 'tope_ms')::numeric < 0 or (v_p ->> 'tope_ms')::numeric > 60000
       or (v_p ->> 'tope_ms')::numeric <> trunc((v_p ->> 'tope_ms')::numeric) then
      raise exception using errcode = '22023', message = '«tope_ms» es un número entero de milisegundos, de 0 (sin tope) a 60000.';
    end if;
    v_tope := (v_p ->> 'tope_ms')::int;
  else
    -- desde la API, 4 s (la API corta a los 8); desde el SQL Editor, sin tope
    v_tope := case when current_user in ('authenticated', 'anon', 'service_role') then 4000 else 0 end;
  end if;
  foreach v_t in array c_orden loop
    continue when not (v_t = any (v_pedidas));
    if v_tope > 0 and extract(epoch from clock_timestamp() - v_t0) * 1000 > v_tope then
      v_sigue := v_sigue || v_t;
      v_r := v_r || jsonb_build_object(v_t, jsonb_build_object('ok', false, 'tarjeta', v_t, 'sigue', true,
                                                               'motivo', 'No dio tiempo en esta llamada: se pide otra vez.'));
      continue;
    end if;
    v_t1 := clock_timestamp();
    v_o := coalesce(v_p -> v_t, '{}'::jsonb);
    begin
      v_x := case v_t
        when 'acciones'        then fn_tablero_acciones()
        when 'cobros'          then fn_tablero_cobros(coalesce((v_o ->> 'dias')::int, 30))
        when 'bancos'          then fn_tablero_bancos()
        when 'resultados'      then fn_tablero_resultados((v_o ->> 'desde')::date, (v_o ->> 'hasta')::date, v_o ->> 'periodo')
        when 'gastos'          then fn_tablero_gastos(coalesce((v_o ->> 'dias')::int, 30), coalesce((v_o ->> 'top')::int, 5))
        when 'por_cobrar'      then fn_tablero_antiguedad('cobrar')
        when 'por_pagar'       then fn_tablero_antiguedad('pagar')
        when 'prestamos'       then fn_tablero_prestamos()
        when 'caja'            then fn_tablero_caja(coalesce((v_o ->> 'meses')::int, 12), coalesce((v_o ->> 'proyeccion')::int, 3), v_cal)
        when 'facturas'        then fn_tablero_facturas(coalesce((v_o ->> 'dias')::int, 30))
        when 'ventas'          then fn_tablero_ventas((v_o ->> 'anio')::int)
        when 'conexiones'      then fn_tablero_conexiones()
        when 'cobros_en_linea' then fn_tablero_cobros_en_linea()
        when 'use_tax'         then fn_tablero_use_tax()
        when 'obras'           then fn_tablero_obras(coalesce((v_o ->> 'top')::int, 5))
      end;
    exception when others then
      v_x := fn_tablero_no(v_t, sqlerrm, null, sqlstate);
    end;
    -- (lo que la proyección de caja necesita de las tres que van antes: si ya están, no se calculan otra vez)
    if (v_x ->> 'ok')::boolean and v_t in ('por_cobrar', 'por_pagar', 'prestamos') then
      v_cal := v_cal || jsonb_build_object(case v_t when 'por_cobrar' then 'cobrar' when 'por_pagar' then 'pagar' else 'prestamos' end,
                                           v_x -> 'calendario');
    end if;
    v_r := v_r || jsonb_build_object(v_t, v_x || jsonb_build_object('ms', round(extract(epoch from clock_timestamp() - v_t1) * 1000)::int));
  end loop;
  return jsonb_build_object(
           'ok', true, 'hoy', fn_tablero_hoy(), 'generado_el', now(), 'version', fn_tablero_version(),
           'libro', fn_tablero_libro(), 'capas', fn_tablero_capas(),
           'tarjetas', to_jsonb(v_pedidas), 'sigue', to_jsonb(v_sigue),
           'ms', round(extract(epoch from clock_timestamp() - v_t0) * 1000)::int)
         || v_r;
end $$;
revoke execute on function public.fn_tablero(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero(jsonb) to authenticated;
comment on function public.fn_tablero(jsonb) is 'c16: el tablero entero en una llamada. p (todo opcional): {"tarjetas": [las que se quieren; por omisión, todas], "cobros": {"dias"}, "facturas": {"dias"}, "resultados": {"periodo"} | {"desde", "hasta"}, "gastos": {"dias", "top"}, "caja": {"meses", "proyeccion"}, "ventas": {"anio"}, "obras": {"top"}, "tope_ms"}. Devuelve {ok, hoy, generado_el, version, libro, capas, tarjetas (las pedidas, en el orden de la portada), sigue (las que no alcanzaron), ms, y una clave por tarjeta: acciones, cobros, bancos, resultados, gastos, caja, facturas, ventas, por_cobrar, por_pagar, conexiones, cobros_en_linea, use_tax, prestamos, obras}. Cada tarjeta trae lo de su función y «ms»; la que falla o cuya capa no está, {ok: false, motivo, falta?, codigo?}; la que no alcanzó el tope por reloj (4 s desde la API; tope_ms lo cambia, 0 = sin tope), {ok: false, sigue: true}: se vuelve a pedir con {"tarjetas": sigue}. 22023 con una clave o una tarjeta desconocida. Solo lee. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 5. Lo que debe verse al pegar: fn_tablero_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_tablero_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c_fn    constant text[] := array['fn_tablero_precondiciones', 'fn_tablero_version', 'fn_tablero_exigir_dueno', 'fn_tablero_hoy',
                                   'fn_tablero_dia', 'fn_tablero_mes', 'fn_tablero_mes_largo', 'fn_tablero_rango', 'fn_tablero_usd',
                                   'fn_tablero_pct', 'fn_tablero_no', 'fn_tablero_capas', 'fn_tablero_libro', 'fn_tablero_saldo',
                                   'fn_tablero_mapa', 'fn_tablero_pyg', 'fn_tablero_cxc', 'fn_tablero_cxp', 'fn_tablero_cobrado', 'fn_tablero_por_revisar',
                                   'fn_tablero_acciones', 'fn_tablero_cobros', 'fn_tablero_bancos', 'fn_tablero_resultados',
                                   'fn_tablero_gastos', 'fn_tablero_caja', 'fn_tablero_facturas', 'fn_tablero_ventas',
                                   'fn_tablero_antiguedad', 'fn_tablero_conexiones', 'fn_tablero_cobros_en_linea', 'fn_tablero_use_tax',
                                   'fn_tablero_prestamos', 'fn_tablero_obras', 'fn_tablero', 'fn_tablero_pegado'];
  v_capas jsonb := fn_tablero_capas();
  v_lib   jsonb;
  v_t     jsonb;
  v_n     int;
  v_com   int;
  v_def   int;
  v_txt   text;
  v_falta text[] := '{}';
  v_no    text;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select count(*), count(*) filter (where coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c16: %'),
         count(*) filter (where p.prosecdef)
    into v_n, v_com, v_def
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn);
  return query select 'la capa'::text,
                      format('c16 · marca %s · %s funciones (%s con su comentario «c16: …»)%s · ninguna tabla, ninguna vista: solo lee',
                             fn_tablero_version(), v_n, v_com,
                             case when v_def = 0 then ' · ninguna SECURITY DEFINER' else format(' · ¡%s SECURITY DEFINER!', v_def) end);
  return query select 'las capas que ve'::text,
                      (select string_agg(k.capa || case when (v_capas ->> k.clave)::boolean then ' sí' else ' NO' end, ' · ' order by k.o)
                         from (values (1, 'c4', 'c4 (estados)'), (2, 'c6', 'c6 (banco)'), (3, 'c6_prestamos', 'c6 (préstamos)'),
                                      (4, 'c7', 'c7 (Plaid)'), (5, 'p1', 'p1 (Stripe)'), (6, 'c8', 'c8 (IA)'), (7, 'c9', 'c9 (cierre)'),
                                      (8, 'c10', 'c10 (costo por obra)'), (9, 'c11', 'c11 (facturas)'), (10, 'c12', 'c12 (WIP)'),
                                      (11, 'c13', 'c13 (cédula)')) k(o, clave, capa));
  v_lib := fn_tablero_libro();
  select format('%s · %s asiento(s)%s', v_lib ->> 'texto', count(*),
                coalesce(format(', del %s al %s', fn_tablero_dia(min(a.fecha_contable)), fn_tablero_dia(max(a.fecha_contable))), ''))
    into v_txt from asientos a;
  return query select 'el libro'::text, v_txt;
  begin
    v_t := fn_tablero('{}'::jsonb);
    select format('%s tarjetas: %s contestan, %s dicen que su capa no está, %s fallan · %s ms',
                  count(*), count(*) filter (where (v_t -> t.x ->> 'ok')::boolean),
                  count(*) filter (where not (v_t -> t.x ->> 'ok')::boolean and v_t -> t.x ? 'falta'),
                  count(*) filter (where not (v_t -> t.x ->> 'ok')::boolean and not v_t -> t.x ? 'falta'), v_t ->> 'ms'),
           string_agg(t.x || ': ' || left(v_t -> t.x ->> 'motivo', 160), ' · ' order by t.o)
             filter (where not (v_t -> t.x ->> 'ok')::boolean)
      into v_txt, v_no
      from jsonb_array_elements_text(v_t -> 'tarjetas') with ordinality t(x, o);
    select coalesce(array_agg(t.x || ' (' || left(v_t -> t.x -> 'cuadre' ->> 'texto', 90) || ': libro '
                              || (v_t -> t.x -> 'cuadre' ->> 'libro') || ', tarjeta ' || (v_t -> t.x -> 'cuadre' ->> 'suma') || ')'), '{}')
      into v_falta
      from jsonb_array_elements_text(v_t -> 'tarjetas') t(x)
     where v_t -> t.x -> 'cuadre' ->> 'ok' = 'false' and t.x <> 'prestamos';
  exception when others then
    v_txt := format('fn_tablero falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'una pasada del tablero'::text, v_txt;
  return query select 'qué falta'::text,
                      case when v_no is null and cardinality(v_falta) = 0 then 'nada: todas las tarjetas contestan y cuadran con el libro'
                           else concat_ws(' · ', v_no, case when cardinality(v_falta) > 0
                                                            then 'NO CUADRA con el libro: ' || array_to_string(v_falta, '; ') end) end;
  return query select 'siguiente paso'::text,
                      'pegar docs/conta/c16-pruebas.sql (sus filas, todas en true u «omitida»); después, la portada nueva de Contabilidad sale '
                      || 'al publicar la app'::text;
end $$;
revoke execute on function public.fn_tablero_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_tablero_pegado() is 'c16: lo que enseña el final del pegado (seis filas): la capa (su marca, sus funciones, ninguna SECURITY DEFINER), las capas que ve, el libro (desde cuándo y cuántos asientos), una pasada del tablero (cuántas tarjetas contestan y en cuánto), qué falta y el paso siguiente. Solo el SQL Editor.';

-- Lo que Edgar ve al final del pegado.
select * from public.fn_tablero_pegado();
