-- =====================================================================
-- C4 · Las pruebas de los estados, el tablero y la apertura — Max Power
-- Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1, c2-libro.sql,
-- c3-puentes.sql y c4-estados.sql. Lo que enseña al final es la tabla de
-- resultados: una fila por prueba, con lo esperado, lo obtenido y ok. Todo
-- en true = los estados cuadran, cada cifra baja a su asiento y a su papel,
-- la apertura amarra con QuickBooks, y el equipo no ve nada.
--
-- NO DEJA RASTRO. Cada prueba es un bloque «do» con una subtransacción
-- adentro: arma lo que necesita (una tarjeta, un proveedor, una balanza de
-- QuickBooks de prueba con sus trampas, facturas, cobros, recibos y
-- trabajos externos de prueba con ids negativos y nombres «c4-pruebas»),
-- postea, mira las vistas y al final lanza MXT00 para DESHACER todo: los
-- papeles, sus asientos, los números, la apertura, los cierres, las
-- anotaciones y el historial. El resultado viaja en variables y se apunta
-- en _pruebas, que es temporal. Los papeles entran con su id escrito
-- («overriding system value»): las secuencias de la app no avanzan. La
-- última prueba compara la foto del final con la del principio.
--
-- EL RELOJ FINGIDO Y LOS CANDADOS: los de c2-pruebas.sql y c3-pruebas.sql
-- (ver su cabecera), en el orden de la app: los de los recibos, periodos y
-- la cadena. Toda subtransacción que sube recibos toma antes los 512
-- cajones de los candados de los recibos (pg_temp.c4_candados_recibos, que
-- explica por qué: sin eso, con la app subiendo tickets, Postgres cortaba a
-- uno de los dos y el puente dejaba ese recibo en la bandeja; pedirlos
-- tarde es MXT10, la 90). Las pruebas que cierran meses o el año
-- (7, 8, 13, 14, 15, 16, 25, 37, 52 y 75) toman antes, como primeras
-- sentencias de su subtransacción, esos cajones y «lock table
-- public.periodos in exclusive mode», y rehacen fn_fecha_miami dentro de
-- ella (el MXT00 la deshace; la
-- 45 la rehace para fingir «hoy» a mitad del mes, y la 68 y la 69 en
-- enero del año siguiente, sin cerrar nada). Las que
-- cambian un instante algo de c4 que la app podría estar leyendo (la 38 y
-- la 55 vacían o quitan vistas para ver que fn_estados_control lo dice;
-- la 56 y la 57 apagan una guarda, la RLS o ponen una policy; la 58 prueba
-- TRUNCATE; la 64 pone una vista y una función encima de las de c4; la
-- 77, la 79, la 80 y la 82 ponen una vista de ayuda, apagan un trigger de
-- historial, rehacen una guarda o dan un permiso por columna; la 89 apaga
-- un instante los triggers del libro, como la 22 de c2; la 101 pone una
-- función ajena que lee las tablas de c4; la 103 rehace la marca de c2 y
-- la policy de cobros a la forma vieja; la 109 da MAINTAIN sobre una
-- tabla de c4) van con lock_timeout de 2 s: si la app las está usando,
-- salen «omitida» en vez de hacerla esperar.
--
-- TODA CIFRA BAJA (la 25): copia, en tablas temporales que mueren con su
-- subtransacción, las vistas a las que se baja (v_libro, v_flujo_lineas,
-- v_gasto_lineas, v_efectivo_movimientos, v_qb_balanzas, diferencias; cada
-- una la primera vez que un «bajar» la pide), cada línea con si llega a su
-- papel, y suma cada «bajar» de cada cifra sobre esas copias (cada pieza
-- una vez): miles de cifras en unos segundos. Un período y un grupo de
-- vistas por vuelta, cada una con su escenario: con el libro lleno,
-- ninguna vuelta pasa de unos 3 s.
--
-- CON DATOS DE VERDAD: cada prueba mide lo que cambia SU escenario (la
-- cifra antes y después, en su subtransacción), con cuentas, proveedores
-- y documentos propios de prueba; lo que el mes ya tenía (la renta, los
-- honorarios, los tickets de Home Depot, una balanza de QuickBooks ya
-- cargada) no la pone en rojo.
--
-- CUÁNDO: recién pegado c4-estados.sql y ANTES de postear la apertura de
-- verdad. Con la apertura ya en el libro (o la apertura cerrada), las
-- pruebas que postean una apertura de prueba (29 a 36, 50, 51, 53, 56, 61,
-- 62, 69, 73, 76, 81, 84, 86, 91, 93, 94, 98, 102, 105 y 107; la 47 y la
-- 75 miran la apertura solo si pueden) salen «omitida»: una segunda
-- apertura encima de la de verdad duplicaría los saldos, y fn_apertura no
-- la pone. Las demás corren igual.
-- Tarda unos 40 s en el banco; con el libro lleno (10.000 asientos, un año
-- largo) cerca de dos minutos (algo más en 17.6), y ninguna
-- subtransacción tiene tomado el libro más de unos 3 s (la 25 y la 37 van
-- por período, y la 25 además por grupo de vistas: antes, de 6 a 9 s, y
-- se cortaban subidas de la app): aun así, mejor correrla sin nadie usando
-- la app (pruebas/conta/c4-volumen.sh la corre así, con cuatro teléfonos
-- subiendo tickets, con 2026 abierto y cerrado, y lo mide: ninguna subida
-- cortada ni sin su asiento, la que más esperó unos 3 s). Corre con el
-- compilador JIT apagado (set jit = off al empezar, reset al final): sus
-- consultas sobre las vistas grandes tardan más en compilarse que en
-- correr.
--
-- LOS DATOS se buscan, no se inventan: el dueño, uno del equipo (si no
-- hay, esas pruebas salen «omitidas»), dos obras con tipo, el mes abierto
-- más antiguo desde el corte, y las cuentas del plan.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;
-- Sin el compilador JIT mientras corren las pruebas (se devuelve al final):
-- sus consultas sobre las vistas grandes tardan más en compilarse que en
-- correr (con 10.000 asientos, segundos por consulta), y cada segundo es
-- un segundo con el libro tomado.
set jit = off;

-- ---------------------------------------------------------------------
-- Antes de nada: lo que estas pruebas dan por hecho.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.estados_mapeo') is null or to_regprocedure('public.fn_apertura(date,text,text)') is null
     or to_regprocedure('public.fn_estados_control(text,text[])') is null
     or to_regclass('public.puente_documentos') is null or to_regprocedure('public.fn_postear_interno(jsonb)') is null then
    raise exception using
      errcode = 'MX000',
      message = 'c4-pruebas NO se corrió: pega antes c1-plan-de-cuentas.sql, c2-libro.sql, c3-puentes.sql y c4-estados.sql.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Los ayudantes (en pg_temp: mueren con la sesión y nadie más los ve; se
-- llaman con su esquema delante, y siempre como el editor).
--   · c4_foto(): cómo están el libro, los papeles, las tablas de c4 y su
--     historial, las reglas, los contadores, las secuencias de la app, las
--     huellas de c2 y la definición de cada vista y función de c4.
--   · c4_montar(): la tarjeta, las reglas confirmadas, el proveedor y el
--     ayudante de prueba (como c3_montar).
--   · c4_balanza_qb(documento): la balanza de QuickBooks de prueba al
--     30-sep, CON SUS TRAMPAS (Opening Balance Equity, Retained Earnings,
--     Undeposited Funds, subcuentas con espacios de sobra, saldos
--     negativos en su columna o entre paréntesis, un grupo en cero,
--     Customer:Job con espacios alrededor de «:», cuentas por cobrar por
--     factura con su retención, un crédito del cliente sin factura, cuentas
--     por pagar por proveedor), y su mapeo.
--   · c4_escenario(): todo junto, como un mes del paralelo: la apertura de
--     prueba (si se puede), y en el mes abierto facturas, cobros (uno
--     parcial, un anticipo aplicado, un cheque devuelto), una nota de
--     crédito, recibos (con tarjeta y a cuenta), un trabajo externo, y
--     asientos a mano de cada clase (traspaso entre bancos, un cobro con
--     comisión, una distribución, depreciación, un devengo reversible, un
--     asiento reversado, la línea de crédito, un pago a proveedor y a la
--     tarjeta), y en el mes siguiente la renta.
--   · c4_qb_del_libro(periodo, documento, extra, con_posteriores): una
--     balanza de QuickBooks del período igual al libro (con lo de enero a
--     septiembre dentro de las cuentas de resultados, como la da
--     QuickBooks en su año), más lo que diga «extra».
--   · c4_bajar_preparar(): copia UNA vez, en tablas temporales con sus
--     índices, las seis vistas a las que se baja (v_libro,
--     v_flujo_lineas, v_gasto_lineas, v_efectivo_movimientos,
--     v_qb_balanzas, diferencias), cada línea con si llega o no a un
--     asiento con su papel. Son las mismas filas que leería la app en ese
--     momento; así cada «bajar» se cuenta sobre una tabla chica, y no se
--     vuelve a armar el libro por cada cifra (con miles de cifras, de
--     minutos a segundos).
--   · c4_bajar(specs): evalúa una lista «bajar» (la cabecera de
--     c4-estados.sql) sobre esas copias: cuánto suma, y cuántas de sus
--     líneas no llegan a un asiento con su papel (cada pieza se suma una
--     vez: las que se repiten salen de c4_bl_memo).
--   · c4_revisar_bajar(vista, periodo): cada cifra de cada fila de esa
--     vista en ese período, contra lo que suma su «bajar».
--   · el reloj fingido y los cierres, como en c2 y c3.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c4_foto() returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_seq     text;
  v_huellas text;
  v_defs    text;
begin
  select left(md5(string_agg(h.tipo || ' ' || h.objeto || ' ' || h.md5, ',' order by h.tipo, h.objeto)), 12)
    into v_huellas
    from public.fn_libro_huellas_calcular() h;
  select left(md5(string_agg(x.d, '|' order by x.d)), 12) into v_defs
    from (select c.relname || ':' || pg_get_viewdef(c.oid) || ':' || coalesce(array_to_string(c.reloptions, ','), '') as d
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname like 'v\_%'
          union all
          select p.oid::regprocedure::text || ':' || md5(pg_get_functiondef(p.oid))
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and (p.proname like 'fn\_estados\_%' or p.proname like 'fn\_apertura%' or p.proname like 'fn\_comparacion%'
                  or p.proname like 'fn\_diferencia%' or p.proname = 'fn_fecha_miami')) x;
  select string_agg(format('%s=%s', t, coalesce((select s.last_value from pg_sequences s
                                                   where s.schemaname || '.' || s.sequencename = pg_get_serial_sequence('public.' || t, 'id')),
                                                  0)), ' ' order by t)
    into v_seq
    from unnest(array['recibos', 'facturas', 'horas', 'trabajos_externos', 'materiales', 'externos_equipo']) t;
  return format('asientos=%s lineas=%s contadores=%s cerrados=%s puente=%s cobros=%s aplic=%s notas=%s devol=%s recibos=%s '
                'facturas=%s externos=%s prov=%s alias=%s tarjetas=%s reglas=%s/%s/%s cuentas=%s historial_c1=%s '
                'c4=%s/%s/%s/%s/%s/%s/%s/%s config=%s sec=[%s] huellas=%s defs=%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) || ':' || coalesce(sum(intentos), 0) from puente_documentos),
                (select count(*) from cobros), (select count(*) from aplicaciones_cobro), (select count(*) from notas_credito),
                (select count(*) from cobros_devoluciones),
                (select count(*) from recibos), (select count(*) from facturas), (select count(*) from trabajos_externos),
                (select count(*) from proveedores), (select count(*) from proveedores_alias), (select count(*) from tarjetas),
                (select count(*) from mapeo_categoria_recibo), (select count(*) from mapeo_metodo_pago),
                (select count(*) from mapeo_tipo_proyecto),
                (select count(*) from cuentas), (select count(*) from cuentas_historial),
                (select count(*) from estados_historial), (select count(*) from estados_lineas),
                (select count(*) from estados_mapeo), (select count(*) from apertura_mapeo_qb),
                (select count(*) from apertura_balanza_qb), (select count(*) from comparacion_qb),
                (select count(*) from diferencias), (select count(*) from diferencias where retirada_el is not null),
                (select string_agg(clave || ':' || valor, ',' order by clave) from estados_config),
                coalesce(v_seq, '-'), v_huellas, v_defs);
end $$;
revoke execute on function pg_temp.c4_foto() from public, anon, authenticated, service_role;

-- Suplantar a alguien (dentro de la subtransacción de la prueba):
-- 'dueno', 'equipo', 'anon', o nulo para volver a ser el editor. Se llama
-- siendo el editor: la prueba vuelve antes con «execute 'reset role'»
-- (suplantado, ya no puede ejecutar los ayudantes).
create or replace function pg_temp.c4_como(p_quien text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute 'reset role';
  if p_quien is null then
    perform set_config('request.jwt.claims', '', true);
    return;
  end if;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', case p_quien when 'dueno' then current_setting('mx4.dueno')
                                                           when 'equipo' then current_setting('mx4.equipo') end,
                                       'role', case when p_quien = 'anon' then 'anon' else 'authenticated' end)::text, true);
  execute format('set local role %I', case when p_quien = 'anon' then 'anon' else 'authenticated' end);
end $$;
revoke execute on function pg_temp.c4_como(text) from public, anon, authenticated, service_role;

create or replace function pg_temp.c4_montar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_prov uuid;
  v_pext uuid;
  v_t    text;
  v_ing  text;
begin
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
  values ('2100-9998', 'c4-pruebas: tarjeta de prueba', 'c4 test card', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
  on conflict (codigo) do nothing;
  perform fn_estados_mapeo_derivar();
  perform fn_tarjeta_alta('9998', '2100-9998', 'c4-pruebas: tarjeta');
  perform fn_mapeo_categoria('material', '5100');
  perform fn_mapeo_metodo_pago('credito', 'tarjeta');
  perform fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor');
  perform fn_mapeo_metodo_pago('zelle', 'banco', fn_puente_cuenta_de('banco'));
  for v_t in select distinct fn_puente_normalizar(p.tipo) from proyectos p
              where p.id in (current_setting('mx4.obra'), current_setting('mx4.obra2')) loop
    v_ing := coalesce((select m.cuenta from mapeo_tipo_proyecto m where m.tipo = v_t),
                      case v_t when 'comercial' then '4020' when 'servicio' then '4030' else '4010' end);
    perform fn_mapeo_tipo_proyecto(v_t, v_ing);
  end loop;
  v_prov := fn_proveedor_alta('C4 PRUEBAS SUPPLY', 'Net 30', array['c4 pruebas supply inc']);
  insert into externos_equipo (id, nombre, costo_hora, activo) overriding system value
  values (-4900001, 'c4-pruebas ayudante', 20, true);
  v_pext := fn_proveedor_alta('C4 PRUEBAS AYUDANTE', null, '{}', -4900001);
  return jsonb_build_object('proveedor', v_prov, 'proveedor_ayudante', v_pext, 'externo', -4900001);
end $$;
revoke execute on function pg_temp.c4_montar() from public, anon, authenticated, service_role;

-- LOS CANDADOS EN EL ORDEN DE LA APP. Una subida de la app toma primero el
-- candado de la foto y el del ticket de su recibo (c3: 512 cajones, la
-- clave 820260925 y hashtext & 511), después las filas de periodos («for
-- share») y al final el candado de la cadena (c2). Una prueba que ya había
-- posteado (la cadena) o cerrado (periodos) y DESPUÉS subía un recibo los
-- pedía al revés: si un teléfono tenía el cajón de ese recibo y esperaba la
-- cadena, cada uno esperaba al otro, y Postgres cortaba a uno (40P01,
-- «deadlock detected»). El puente, que no tumba la subida, dejaba ESE recibo
-- en la bandeja con el error: el de la prueba (con el libro lleno, la 24
-- salió en rojo: su material sin asiento) o el del teléfono (un recibo de
-- verdad sin asiento hasta «reintentar»: dos de 369 subidas mientras corría
-- c4-pruebas). Por eso toda subtransacción que sube recibos toma ANTES los
-- 512 cajones, en orden (c4_inmediato lo hace; las que cierran, antes del
-- candado de periodos): el teléfono espera su cajón como antes esperaba la
-- cadena, y nadie se cruza. Se sueltan con el MXT00. Pedirlos tarde, con la
-- cadena o periodos ya tomados, es MXT10: una prueba nueva que lo haga sale
-- en rojo en el banco, sin necesitar un teléfono que la cruce.
create or replace function pg_temp.c4_candados_recibos() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_k int;
begin
  if (select count(*) from pg_locks l
       where l.pid = pg_backend_pid() and l.granted and l.locktype = 'advisory'
         and l.classid::bigint = 820260925 and l.objsubid = 2) >= 512 then
    return;   -- ya los tiene (el escenario, dentro de una prueba que cierra)
  end if;
  if exists (select 1 from pg_locks l
              where l.pid = pg_backend_pid() and l.granted
                and ((l.locktype = 'advisory' and l.classid::bigint = 0 and l.objid::bigint = 820260923 and l.objsubid = 1)
                     or (l.locktype = 'relation' and l.relation = 'public.periodos'::regclass
                         and l.mode <> 'AccessShareLock'))) then
    raise exception using errcode = 'MXT10',
      message = 'c4-pruebas: los candados de los recibos (pg_temp.c4_candados_recibos()) se toman antes que el de periodos y '
                'el de la cadena, como en la app.';
  end if;
  for v_k in 0 .. 511 loop
    perform pg_advisory_xact_lock(820260925, v_k);
  end loop;
end $$;
revoke execute on function pg_temp.c4_candados_recibos() from public, anon, authenticated, service_role;

-- Los puentes diferidos, en immediate (como en c3-pruebas), con los
-- candados de los recibos tomados antes (arriba).
create or replace function pg_temp.c4_inmediato() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_lista text;
begin
  perform pg_temp.c4_candados_recibos();
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v_lista
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v_lista is not null then
    execute 'set constraints ' || v_lista || ' immediate';
  end if;
end $$;
revoke execute on function pg_temp.c4_inmediato() from public, anon, authenticated, service_role;

-- El reloj fingido y los cierres (los de c2 y c3). Cerrar hasta un mes, o
-- un año entero (todos sus meses y el año).
create or replace function pg_temp.c4_fingir_hoy(p_hoy date) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;
revoke execute on function pg_temp.c4_fingir_hoy(date) from public, anon, authenticated, service_role;

create or replace function pg_temp.c4_cerrar_hasta(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p periodos;
  v_q text;
begin
  if not exists (select 1 from pg_locks l
                  where l.locktype = 'relation' and l.relation = 'public.periodos'::regclass
                    and l.pid = pg_backend_pid() and l.granted
                    and l.mode in ('ExclusiveLock', 'AccessExclusiveLock')) then
    raise exception using errcode = 'MXT09',
      message = 'c4-pruebas: una prueba que cierra períodos toma antes lock table public.periodos in exclusive mode.';
  end if;
  select * into v_p from periodos where periodo = p_periodo;
  perform pg_temp.c4_fingir_hoy(greatest(v_p.hasta + 1, fn_fecha_miami(now())));
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto'
                and p.desde <= case when v_p.tipo = 'anio' then v_p.hasta else v_p.desde end
              order by p.desde loop
    update periodos set estado = 'cerrado' where periodo = v_q;
  end loop;
  if v_p.tipo = 'anio' then
    update periodos set estado = 'cerrado' where periodo = p_periodo and estado = 'abierto';
  end if;
end $$;
revoke execute on function pg_temp.c4_cerrar_hasta(text) from public, anon, authenticated, service_role;

-- El control de QuickBooks de una balanza de apertura de prueba (las filas
-- «Net Income», «TOTAL ASSETS» y «Total Liabilities», que fn_apertura_plan
-- exige desde las rondas 3 y 4 de c4): lo que da su mapeo de hoy, para las
-- pruebas cuyo mapeo es el bueno. (La prueba del mapeo equivocado pone el
-- suyo, el de QuickBooks.) Se escriben como las escribe la carga: tres
-- filas más, apartadas.
create or replace function pg_temp.c4_control_qb(p_documento text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_res numeric;
  v_act numeric;
  v_pas numeric;
  v_l   int;
begin
  delete from apertura_balanza_qb b where b.documento = p_documento and b.control is not null;
  select coalesce(sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where c.tipo not in ('activo', 'pasivo', 'capital')), 0),
         coalesce(sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where c.tipo = 'activo'), 0),
         coalesce(sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where c.tipo = 'pasivo'), 0),
         coalesce(max(b.linea), 0)
    into v_res, v_act, v_pas, v_l
    from apertura_balanza_qb b
    left join apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave
    left join cuentas c on c.codigo = m.cuenta
   where b.documento = p_documento;
  insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe, haber, control)
  values (p_documento, v_l + 1, 'Net Income', greatest(v_res, 0), greatest(-v_res, 0), 'utilidad'),
         (p_documento, v_l + 2, 'TOTAL ASSETS', greatest(v_act, 0), greatest(-v_act, 0), 'activo'),
         (p_documento, v_l + 3, 'Total Liabilities', greatest(v_pas, 0), greatest(-v_pas, 0), 'pasivo');
end $$;
revoke execute on function pg_temp.c4_control_qb(text) from public, anon, authenticated, service_role;

-- La balanza de QuickBooks de prueba (con sus trampas) y su mapeo.
-- Cuadra: debe 109,050.00 = haber 109,050.00. Resultado de enero a
-- septiembre: ingresos 90,050 − materiales 40,000 − renta 12,000 = 38,050.
create or replace function pg_temp.c4_balanza_qb(p_documento text, p_mapear boolean default true, p_extra jsonb default '[]')
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_a  text := current_setting('mx4.obra');
  v_b  text := current_setting('mx4.obra2');
  v_r  jsonb;
begin
  -- Las facturas de QuickBooks que siguen abiertas al 30-sep (en la app).
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
  values (-4400001, v_a, 'C4-QB-1', '2026-08-15', 3000.00, 500.00),
         (-4400006, v_b, 'C4-QB-6', '2026-09-20', 4000.00, 0)
  on conflict (id) do nothing;
  v_r := fn_apertura_balanza_cargar(p_documento, jsonb_build_array(
    jsonb_build_object('cuenta_qb', 'Chase  Chk 4392 ', 'debe', '25,000.00'),
    jsonb_build_object('cuenta_qb', 'Undeposited Funds', 'debe', '1,200.00'),
    jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'debe', '3,000.00', 'factura_id', -4400001, 'retencion', '500.00',
                       'cliente_trabajo', 'C4 Pruebas, Cliente : Obra A'),
    jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'debe', '4000', 'factura_id', -4400006),
    jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'haber', '300.00', 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A'),
    jsonb_build_object('cuenta_qb', 'Vehicles', 'debe', 30000),
    jsonb_build_object('cuenta_qb', 'Accumulated Depreciation', 'debe', '(6,000.00)'),
    jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '2,500.00', 'proveedor_qb', 'C4  Pruebas Supply Inc'),
    jsonb_build_object('cuenta_qb', 'Credit Cards:Amex 2009', 'haber', '1,100.00'),
    jsonb_build_object('cuenta_qb', 'Credit Cards : Amex 1007', 'debe', '-150.00'),
    jsonb_build_object('cuenta_qb', 'Credit Cards', 'debe', '0.00'),
    jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '5,000.00'),
    jsonb_build_object('cuenta_qb', 'Retained Earnings', 'haber', '9,100.00'),
    jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '90,000.00'),
    jsonb_build_object('cuenta_qb', 'Job Materials', 'debe', '40,000.00'),
    jsonb_build_object('cuenta_qb', 'Rent Expense', 'debe', '12,000.00'),
    jsonb_build_object('cuenta_qb', 'Interest Income', 'haber', '50.00'),
    jsonb_build_object('cuenta_qb', 'Common Stock', 'haber', '1,000.00')) || coalesce(p_extra, '[]'::jsonb));
  if p_mapear then
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_mapeo_qb('undeposited funds', '1010', 'c4-pruebas: depósitos en tránsito');
    perform fn_apertura_mapeo_qb('Accounts Receivable', fn_puente_cuenta_de('cxc'));
    perform fn_apertura_mapeo_qb('Vehicles', '1510');
    perform fn_apertura_mapeo_qb('Accumulated Depreciation', '1590');
    perform fn_apertura_mapeo_qb('Accounts Payable', fn_puente_cuenta_de('cxp'));
    perform fn_apertura_mapeo_qb('Credit Cards:Amex 2009', '2100-2009');
    -- (La Amex Gold: en QuickBooks figura como 1007, y es la 2100-2013 del
    -- plan, c1. No se crea otra cuenta.)
    perform fn_apertura_mapeo_qb('Credit Cards:Amex 1007', '2100-2013');
    perform fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
    perform fn_apertura_mapeo_qb('Retained Earnings', '3900');
    perform fn_apertura_mapeo_qb('Construction Income', '4010');
    perform fn_apertura_mapeo_qb('Job Materials', '5100');
    perform fn_apertura_mapeo_qb('Rent Expense', '6100');
    perform fn_apertura_mapeo_qb('Interest Income', '4910');
    perform fn_apertura_mapeo_qb('Common Stock', '3000');
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Cliente:Obra A', v_a);
    -- Y su control de QuickBooks (Net Income y TOTAL ASSETS), el de este
    -- mapeo (que es el bueno): utilidad 38,050 y activo 56,900 (más lo
    -- que traiga p_extra).
    perform pg_temp.c4_control_qb(p_documento);
  end if;
  return v_r;
end $$;
revoke execute on function pg_temp.c4_balanza_qb(text, boolean, jsonb) from public, anon, authenticated, service_role;

-- Una balanza de QuickBooks de un período IGUAL al libro (cada cuenta con
-- un nombre «QB <cuenta>» y su mapeo; las de resultados con lo que trajo
-- la balanza de apertura dentro, como las da QuickBooks en su año, y 3900
-- sin ello), más lo que diga p_extra ({"<cuenta>": monto, …}: lo que
-- QuickBooks tiene de más). Lo que ya está anotado como explicado en ese
-- período (con datos de verdad: una comisión que QuickBooks ya tenía)
-- sigue explicado: esa diferencia va en la balanza. p_con_posteriores: la
-- final (ya con los ajustes del CPA posteriores). p_al: la balanza a ese
-- día (una quincena: el libro hasta ahí), cargada con su fecha (salvo
-- p_con_fecha = false: la misma cifra cargada como del fin del período).
-- Devuelve lo que devuelve la carga.
create or replace function pg_temp.c4_qb_del_libro(p_periodo text, p_documento text, p_extra jsonb default '{}',
                                                   p_con_posteriores boolean default false, p_al date default null,
                                                   p_con_fecha boolean default true)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ap text := (select p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1);
  v_ja boolean;
  v_f  jsonb;
begin
  -- (el arrastre de la apertura: solo en su año, después de ella)
  select pp.anio = pa.anio and pp.hasta > pa.hasta and pp.periodo <> pa.periodo into v_ja
    from periodos pp, periodos pa where pp.periodo = p_periodo and pa.periodo = v_ap;
  with b as (select v.cuenta, v.saldo_final from v_balanza v where v.periodo = p_periodo and v.nivel = 'cuenta' and p_al is null
             union all
             select v.cuenta, sum(v.monto) from v_libro v join periodos pp on pp.periodo = p_periodo
              where p_al is not null and v.fecha <= p_al and (v.estado = 'balance' or v.ejercicio = pp.anio)
              group by v.cuenta),
       j as (select q.cuenta, sum(q.saldo) as saldo from v_qb_balanzas q
              where q.fuente = 'apertura_balanza_qb' and q.cuenta_tipo not in ('activo', 'pasivo', 'capital')
              group by q.cuenta),
       d as (select x.cuenta, sum(x.monto) as monto from diferencias x
              where x.periodo = p_periodo and x.retirada_el is null group by x.cuenta),
       c as (select b.cuenta from b
             union select q.cuenta from v_qb_balanzas q where q.fuente = 'apertura_balanza_qb' and q.cuenta is not null
             union select k from jsonb_object_keys(coalesce(p_extra, '{}')) k
             union select d.cuenta from d)
  select jsonb_agg(jsonb_build_object('cuenta_qb', 'QB ' || c.cuenta, 'saldo',
           (coalesce(b.saldo_final, 0)
            + case when v_ja then coalesce(j.saldo, 0) else 0 end
            - case when v_ja and c.cuenta = '3900' then (select coalesce(sum(j2.saldo), 0) from j j2) else 0 end
            + coalesce((p_extra->>c.cuenta)::numeric, 0)
            - coalesce(d.monto, 0))::text) order by c.cuenta)
    into v_f
    from c
    left join b on b.cuenta = c.cuenta
    left join j on j.cuenta = c.cuenta
    left join d on d.cuenta = c.cuenta
   where c.cuenta is not null;
  perform fn_apertura_mapeo_qb(e->>'cuenta_qb', substr(e->>'cuenta_qb', 4)) from jsonb_array_elements(v_f) e;
  return fn_comparacion_qb_cargar(p_periodo, p_documento, v_f, p_con_posteriores, case when p_con_fecha then p_al end);
end $$;
revoke execute on function pg_temp.c4_qb_del_libro(text, text, jsonb, boolean, date, boolean)
  from public, anon, authenticated, service_role;

-- ¿Se puede postear una apertura de prueba? La apertura abierta y sin
-- asiento de apertura vivo (antes de que Edgar cargue la real).
create or replace function pg_temp.c4_apertura_libre() returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select exists (select 1 from periodos p where p.tipo = 'apertura' and p.estado = 'abierto')
     and not exists (select 1 from asientos a
                      where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
$$;
revoke execute on function pg_temp.c4_apertura_libre() from public, anon, authenticated, service_role;

-- Todo junto. Devuelve los ids y lo que las pruebas comparan.
create or replace function pg_temp.c4_escenario() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_m      jsonb;
  v_a      text := current_setting('mx4.obra');
  v_b      text := current_setting('mx4.obra2');
  d        date := current_setting('mx4.desde')::date;
  v_dueno  uuid := nullif(current_setting('mx4.dueno', true), '')::uuid;
  v_ap     jsonb;
  v_c1     jsonb;
  v_c2     jsonb;
  v_c3     jsonb;
  v_c4     jsonb;
  v_rev    jsonb;
  v_banco  text := fn_puente_cuenta_de('banco');
  v_cxp    text := fn_puente_cuenta_de('cxp');
  v_con_ap boolean := pg_temp.c4_apertura_libre();
begin
  v_m := pg_temp.c4_montar();
  perform pg_temp.c4_inmediato();
  -- La apertura de prueba, desde su balanza de QuickBooks.
  if v_con_ap then
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-v1.csv');
    v_ap := fn_apertura((select p.desde from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
                        'docs/c4-pruebas/qb-apertura-v1.csv');
  end if;
  -- Las facturas del mes (ids negativos): una con retención, una que se
  -- cobra con un anticipo, una que se anula, una cuyo cheque rebota.
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value values
    (-4400002, v_a, 'C4-2', d + 2, 10000.00, 1000.00),
    (-4400003, v_b, 'C4-3', d + 14, 2000.00, 0),
    (-4400004, v_b, 'C4-4', d + 8, 500.00, 0),
    (-4400005, v_a, 'C4-5', d + 10, 3000.00, 0);
  -- Los cobros.
  if v_con_ap then
    v_c1 := fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (d + 4)::text, 'monto', '1000.00', 'medio', 'cheque',
              'referencia', 'c4-1', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -4400001, 'monto', '1000.00'))));
  end if;
  v_c2 := fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (d + 9)::text, 'monto', '4000.00', 'medio', 'cheque',
            'referencia', 'c4-2', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -4400002, 'monto', '4000.00'))));
  v_c3 := fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (d + 11)::text, 'monto', '1500.00', 'medio', 'ach', 'proyecto_id', v_b,
            'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_b, 'monto', '1500.00'))));
  perform fn_anticipo_aplicar((v_c3->>'cobro')::uuid, -4400003, '1500.00', d + 19);
  perform fn_factura_anular(-4400004, 'c4-pruebas: se facturó de más', d + 20);
  v_c4 := fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (d + 12)::text, 'monto', '3000.00', 'medio', 'cheque',
            'referencia', 'c4-4', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -4400005, 'monto', '3000.00'))));
  perform fn_cobro_devolver((v_c4->>'cobro')::uuid, d + 15, 'c4-pruebas: cheque sin fondos');
  -- Recibos (subidos el día de su fecha) y un trabajo externo.
  insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo,
                       metodo_pago, ultimos4) overriding system value values
    (-4410001, v_a, 'recibos/c4-pruebas/1.jpg', 350.00, 'C4 Pruebas Ferreteria', 'leido', v_dueno,
     ((d + 3) + time '12:00') at time zone 'America/New_York', d + 3, 'material', 'C4-HD-1', 'credito', '9998'),
    (-4410002, v_a, 'recibos/c4-pruebas/2.jpg', 800.00, 'C4 Pruebas Supply Inc', 'leido', v_dueno,
     ((d + 5) + time '12:00') at time zone 'America/New_York', d + 5, 'material', 'C4-SP-2', 'cuenta_proveedor', null);
  insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id, creado) overriding system value
  values (-4420001, v_a, 'c4-pruebas ayudante', d + 7, 'horas', 60, 1200.00, -4900001, ((d + 7) + time '12:00') at time zone 'America/New_York');
  -- Asientos a mano, de cada clase.
  perform fn_postear(jsonb_build_object('fecha', (d + 6)::text, 'descripcion', 'c4-pruebas: traspaso a la reserva de impuestos',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1030', 'monto', '2000.00'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-2000.00'))));
  perform fn_postear(jsonb_build_object('fecha', (d + 13)::text, 'descripcion', 'c4-pruebas: otro ingreso cobrado con comisión',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_banco, 'monto', '950.00'),
                                jsonb_build_object('cuenta', '6130', 'monto', '50.00'),
                                jsonb_build_object('cuenta', '4900', 'monto', '-1000.00'))));
  perform fn_postear(jsonb_build_object('fecha', (d + 16)::text, 'descripcion', 'c4-pruebas: distribución al accionista',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200', 'monto', '300.00'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-300.00'))));
  v_rev := fn_postear(jsonb_build_object('fecha', (d + 17)::text, 'descripcion', 'c4-pruebas: gasto equivocado (se reversa)',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '99.00'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-99.00'))));
  perform fn_reversar((v_rev->>'id')::uuid, 'c4-pruebas: no era de la empresa');
  perform fn_postear(jsonb_build_object('fecha', (d + 18)::text, 'descripcion', 'c4-pruebas: disposición de la línea de crédito',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_banco, 'monto', '5000.00'),
                                jsonb_build_object('cuenta', '2510', 'monto', '-5000.00'))));
  perform fn_postear(jsonb_build_object('fecha', (d + 21)::text, 'descripcion', 'c4-pruebas: abono al supply',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cxp, 'monto', '500.00', 'tercero_tipo', 'proveedor',
                                                   'tercero_id', v_m->>'proveedor', 'partida_tabla', 'recibos',
                                                   'partida_id', '-4410002'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-500.00'))));
  perform fn_postear(jsonb_build_object('fecha', (d + 25)::text, 'descripcion', 'c4-pruebas: pago de la tarjeta',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9998', 'monto', '350.00'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-350.00'))));
  perform fn_postear(jsonb_build_object('fecha', ((date_trunc('month', d::timestamp) + interval '1 month')::date - 1)::text,
    'descripcion', 'c4-pruebas: depreciación del mes',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6950', 'monto', '250.00'),
                                jsonb_build_object('cuenta', '1590', 'monto', '-250.00'))));
  perform fn_postear(jsonb_build_object('fecha', ((date_trunc('month', d::timestamp) + interval '1 month')::date - 1)::text,
    'descripcion', 'c4-pruebas: devengo de honorarios (reversible)', 'reversible', true,
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6600', 'monto', '400.00'),
                                jsonb_build_object('cuenta', '2050', 'monto', '-400.00'))));
  -- El mes siguiente: la renta, del banco.
  perform fn_postear(jsonb_build_object('fecha', ((date_trunc('month', d::timestamp) + interval '1 month')::date + 1)::text,
    'descripcion', 'c4-pruebas: renta',
    'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '1200.00'),
                                jsonb_build_object('cuenta', v_banco, 'monto', '-1200.00'))));
  return v_m || jsonb_strip_nulls(jsonb_build_object('apertura', v_ap, 'con_apertura', v_con_ap, 'cobro_anticipo', v_c3->>'cobro',
                                                     'cobro_rebotado', v_c4->>'cobro', 'cobro_parcial', v_c2->>'cobro',
                                                     'cobro_apertura', v_c1->>'cobro'));
end $$;
revoke execute on function pg_temp.c4_escenario() from public, anon, authenticated, service_role;

-- Evaluar una lista «bajar»: cuánto suma, cuántas líneas trae, y cuántas
-- de ellas no llegan a un asiento con su papel (o, en QuickBooks, a su
-- documento; en las diferencias, a su explicación).
create or replace function pg_temp.c4_bajar_preparar() returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  drop table if exists pg_temp.c4_bl_v_libro, pg_temp.c4_bl_v_flujo_lineas, pg_temp.c4_bl_v_gasto_lineas,
                       pg_temp.c4_bl_v_qb_balanzas, pg_temp.c4_bl_diferencias, pg_temp.c4_bl_papel,
                       pg_temp.c4_bl_v_efectivo_movimientos, pg_temp.c4_bl_memo;
  -- (Lo que ya se sumó, por pieza de «bajar»: muchas cifras repiten la
  -- misma pieza —el total y sus tramos, el saldo y la cifra—, y cada una
  -- es una consulta.)
  create temp table c4_bl_memo (k text primary key, s numeric, n bigint, p bigint);
  create temp table c4_bl_papel as
    select p.asiento_id, (p.papel_existe is true and p.papel is not null) as con_papel
      from public.v_asiento_papel p;
  create unique index on pg_temp.c4_bl_papel (asiento_id);
  analyze pg_temp.c4_bl_papel;
end $$;
revoke execute on function pg_temp.c4_bajar_preparar() from public, anon, authenticated, service_role;

-- La copia de UNA vista a la que se baja, la primera vez que un «bajar» la
-- pide (c4_bajar): cada vuelta de la 25 copia solo las que usan sus
-- vistas, y la estadística solo de las columnas por las que se busca (la
-- de todas, con el libro lleno, tardaba más que la copia).
create or replace function pg_temp.c4_bajar_copiar(p_vista text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  case p_vista
    when 'v_libro' then
      create temp table c4_bl_v_libro as
        select x.*, not coalesce(p.con_papel, false) as c4_sin_papel
          from public.v_libro x left join pg_temp.c4_bl_papel p on p.asiento_id = x.asiento_id;
      create index on pg_temp.c4_bl_v_libro (cuenta, fecha);
      create index on pg_temp.c4_bl_v_libro (fecha);
      -- (la antigüedad baja por partida, y el dinero y la balanza por obra:
      -- sin estos, con el libro lleno cada cifra recorría la cuenta entera)
      create index on pg_temp.c4_bl_v_libro (partida_id);
      create index on pg_temp.c4_bl_v_libro (proyecto_id, cuenta);
      analyze pg_temp.c4_bl_v_libro (cuenta, fecha, proyecto_id, tipo, partida_id);
    when 'v_flujo_lineas' then
      create temp table c4_bl_v_flujo_lineas as
        select x.*, not coalesce(p.con_papel, false) as c4_sin_papel
          from public.v_flujo_lineas x left join pg_temp.c4_bl_papel p on p.asiento_id = x.asiento_id;
      create index on pg_temp.c4_bl_v_flujo_lineas (fecha);
      analyze pg_temp.c4_bl_v_flujo_lineas (fecha, linea_directo, linea_indirecto);
    when 'v_gasto_lineas' then
      create temp table c4_bl_v_gasto_lineas as
        select x.*, not coalesce(p.con_papel, false) as c4_sin_papel
          from public.v_gasto_lineas x left join pg_temp.c4_bl_papel p on p.asiento_id = x.asiento_id;
      create index on pg_temp.c4_bl_v_gasto_lineas (fecha);
      analyze pg_temp.c4_bl_v_gasto_lineas (fecha);
    when 'v_efectivo_movimientos' then
      create temp table c4_bl_v_efectivo_movimientos as
        select x.*, not coalesce(p.con_papel, false) as c4_sin_papel
          from public.v_efectivo_movimientos x left join pg_temp.c4_bl_papel p on p.asiento_id = x.asiento_id;
      create index on pg_temp.c4_bl_v_efectivo_movimientos (fecha);
      analyze pg_temp.c4_bl_v_efectivo_movimientos (fecha);
    when 'v_qb_balanzas' then
      create temp table c4_bl_v_qb_balanzas as
        select x.*, x.documento is null as c4_sin_papel from public.v_qb_balanzas x;
      analyze pg_temp.c4_bl_v_qb_balanzas;
    when 'diferencias' then
      create temp table c4_bl_diferencias as
        select x.*, coalesce(btrim(x.explicacion), '') = '' as c4_sin_papel from public.diferencias x;
      analyze pg_temp.c4_bl_diferencias;
  end case;
end $$;
revoke execute on function pg_temp.c4_bajar_copiar(text) from public, anon, authenticated, service_role;

create or replace function pg_temp.c4_bajar(p_specs jsonb, out total numeric, out filas bigint, out sin_papel bigint)
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e       jsonb;
  f       record;
  v_where text;
  v_col   text;
  v_s     numeric;
  v_n     bigint;
  v_p     bigint;
begin
  total := 0; filas := 0; sin_papel := 0;
  if p_specs is null or jsonb_typeof(p_specs) <> 'array' then
    raise exception using errcode = 'MXT01', message = format('bajar no es una lista: %s', p_specs);
  end if;
  for e in select value from jsonb_array_elements(p_specs) loop
    if e->>'vista' not in ('v_libro', 'v_flujo_lineas', 'v_gasto_lineas', 'v_efectivo_movimientos', 'v_qb_balanzas',
                           'diferencias') then
      raise exception using errcode = 'MXT01', message = format('bajar a una vista que no se sabe bajar: %s', e->>'vista');
    end if;
    v_where := 'true';
    for f in select key, value from jsonb_each(coalesce(e->'filtros', '{}'::jsonb)) loop
      if f.key like '%\_hasta' then
        v_col := left(f.key, length(f.key) - 6);
        v_where := v_where || format(' and x.%I::text <= %L', v_col, f.value #>> '{}');
      elsif f.key like '%\_no' then
        v_col := left(f.key, length(f.key) - 3);
        if jsonb_typeof(f.value) = 'array' then
          v_where := v_where || format(' and x.%I::text <> all (%L::text[])', v_col,
                                       (select array_agg(t) from jsonb_array_elements_text(f.value) t));
        else
          v_where := v_where || format(' and x.%I::text <> %L', v_col, f.value #>> '{}');
        end if;
      elsif jsonb_typeof(f.value) = 'null' then
        v_where := v_where || format(' and x.%I is null', f.key);
      elsif jsonb_typeof(f.value) = 'array' then
        v_where := v_where || format(' and x.%I::text = any (%L::text[])', f.key,
                                     (select array_agg(t) from jsonb_array_elements_text(f.value) t));
      else
        v_where := v_where || format(' and x.%I::text = %L', f.key, f.value #>> '{}');
      end if;
    end loop;
    if e ? 'desde' then v_where := v_where || format(' and x.fecha >= %L::date', e->>'desde'); end if;
    if e ? 'hasta' then v_where := v_where || format(' and x.fecha <= %L::date', e->>'hasta'); end if;
    -- (la copia de la vista, de c4_bajar_copiar: mismas filas y columnas,
    -- más c4_sin_papel; cada pieza se suma una vez)
    select m.s, m.n, m.p into v_s, v_n, v_p from pg_temp.c4_bl_memo m where m.k = (e - 'signo')::text;
    if not found then
      if to_regclass('pg_temp.c4_bl_' || (e->>'vista')) is null then
        perform pg_temp.c4_bajar_copiar(e->>'vista');
      end if;
      execute format('select coalesce(sum(x.%I), 0), count(*), count(*) filter (where x.c4_sin_papel) from pg_temp.%I x where %s',
                     e->>'campo', 'c4_bl_' || (e->>'vista'), v_where)
        into v_s, v_n, v_p;
      insert into pg_temp.c4_bl_memo values ((e - 'signo')::text, v_s, v_n, v_p);
    end if;
    total := total + coalesce((e->>'signo')::int, 1) * v_s;
    filas := filas + v_n;
    sin_papel := sin_papel + v_p;
  end loop;
end $$;
revoke execute on function pg_temp.c4_bajar(jsonb) from public, anon, authenticated, service_role;

-- Cada cifra de cada fila de una vista (en un período) contra su «bajar».
-- Devuelve 'filas=N cifras=M' si todo cuadra y todo llega a su papel, o
-- las primeras que no.
create or replace function pg_temp.c4_revisar_bajar(p_vista text, p_periodo text) returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r       jsonb;
  k       text;
  v_b     record;
  v_n     int := 0;
  v_c     int := 0;
  v_malas text[] := '{}';
  v_cols  text[];
begin
  -- Las columnas de cifra de la vista (numeric(14,2)): cada una con valor
  -- tiene que traer su llave en «bajar». (factura_monto, de la cobranza,
  -- es el monto del papel, no una cifra del libro.)
  select coalesce(array_agg(a.attname::text), '{}') into v_cols
    from pg_attribute a
   where a.attrelid = to_regclass('public.' || p_vista) and a.attnum > 0 and not a.attisdropped
     and a.atttypid = 'numeric'::regtype and a.atttypmod = ((14 << 16) | 2) + 4
     and a.attname not in ('factura_monto');
  for r in execute format('select to_jsonb(v) from public.%I v where v.periodo = %L', p_vista, p_periodo) loop
    v_n := v_n + 1;
    if r->'bajar' is null or jsonb_typeof(r->'bajar') <> 'object' then
      v_malas := v_malas || format('%s fila sin bajar', p_vista);
      continue;
    end if;
    for k in select c from unnest(v_cols) c
              where r->c is not null and jsonb_typeof(r->c) <> 'null' and not (r->'bajar' ? c) loop
      v_malas := v_malas || format('%s %s %s: cifra %s sin su llave en bajar', p_vista,
                                   coalesce(r->>'cuenta', r->>'linea', r->>'partida_id', r->>'proveedor_clave', r->>'nivel', '?'),
                                   k, r->>k);
    end loop;
    for k in select jsonb_object_keys(r->'bajar') loop
      if r->k is null or jsonb_typeof(r->k) = 'null' then
        continue;  -- (una cifra que no aplica en esa fila)
      end if;
      v_c := v_c + 1;
      if jsonb_typeof(r->'bajar'->k) is distinct from 'array' then
        v_malas := v_malas || format('%s %s %s: su bajar no es una lista (%s)', p_vista,
                                     coalesce(r->>'cuenta', r->>'linea', r->>'partida_id', r->>'proveedor_clave', r->>'nivel', '?'),
                                     k, r->'bajar'->k);
        continue;
      end if;
      select * into v_b from pg_temp.c4_bajar(r->'bajar'->k);
      if v_b.total <> (r->>k)::numeric or v_b.sin_papel > 0 then
        v_malas := v_malas || format('%s %s %s: cifra %s, baja a %s (%s líneas, %s sin papel)', p_vista,
                                     coalesce(r->>'cuenta', r->>'linea', r->>'partida_id', r->>'proveedor_clave', r->>'nivel', '?'),
                                     k, r->>k, v_b.total, v_b.filas, v_b.sin_papel);
      end if;
    end loop;
  end loop;
  if cardinality(v_malas) > 0 then
    return array_to_string(v_malas[1:3], ' | ');
  end if;
  return format('filas=%s cifras=%s', v_n, v_c);
end $$;
revoke execute on function pg_temp.c4_revisar_bajar(text, text) from public, anon, authenticated, service_role;

-- Una línea de texto con las filas de una consulta (para comparar).
create or replace function pg_temp.c4_filas(p_sql text) returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  execute format('select coalesce(string_agg(t::text, '' | ''), ''(nada)'') from (%s) t', p_sql) into v;
  return v;
end $$;
revoke execute on function pg_temp.c4_filas(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Lo que usan todas las pruebas, en ajustes de la
-- sesión (mx4.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno  uuid;
  v_equipo uuid;
  v_obra   text;
  v_obra2  text;
  v_mes    text;
  v_desde  date;
  v_sig    text;
  v_ap     text;
begin
  select id into v_dueno from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select p.id into v_obra from proyectos p where nullif(btrim(p.tipo), '') is not null order by p.id limit 1;
  select p.id into v_obra2 from proyectos p where nullif(btrim(p.tipo), '') is not null and p.id <> v_obra order by p.id limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde >= fn_puente_corte() order by desde limit 1;
  select periodo into v_sig from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  select periodo into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  perform set_config('mx4.dueno',    coalesce(v_dueno::text, ''), false);
  perform set_config('mx4.equipo',   coalesce(v_equipo::text, ''), false);
  perform set_config('mx4.obra',     coalesce(v_obra, ''), false);
  perform set_config('mx4.obra2',    coalesce(v_obra2, ''), false);
  perform set_config('mx4.mes',      coalesce(v_mes, ''), false);
  perform set_config('mx4.desde',    coalesce(v_desde::text, ''), false);
  perform set_config('mx4.sig',      coalesce(v_sig, ''), false);
  perform set_config('mx4.anio',     coalesce(extract(year from v_desde)::text, ''), false);
  perform set_config('mx4.apertura', coalesce(v_ap, ''), false);
  perform set_config('mx4.foto',     pg_temp.c4_foto(), false);
end $$;

-- El escenario con TODOS los tipos de asiento: el de arriba (apertura,
-- normales de los puentes y a mano, un reverso, un devengo reversible con
-- su reverso automático) y, con el mes cerrado, un ajuste del CPA a ese mes
-- posteado en el mes siguiente. La prueba que lo llama toma antes el
-- candado de periodos (primera sentencia de su subtransacción).
create or replace function pg_temp.c4_escenario_completo() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_e jsonb;
  v_a jsonb;
begin
  v_e := pg_temp.c4_escenario();
  perform pg_temp.c4_cerrar_hasta(current_setting('mx4.mes'));
  v_a := fn_postear(jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', current_setting('mx4.mes'),
           'fecha', ((current_setting('mx4.desde')::date + interval '1 month')::date + 3)::text,
           'motivo', 'c4-pruebas: el CPA ajusta los honorarios del mes', 'descripcion', 'c4-pruebas: ajuste del CPA',
           'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6600', 'monto', '75.00'),
                                       jsonb_build_object('cuenta', '2050', 'monto', '-75.00'))));
  return v_e || jsonb_build_object('ajuste', v_a->>'id');
end $$;
revoke execute on function pg_temp.c4_escenario_completo() from public, anon, authenticated, service_role;


-- =====================================================================
-- A · Lo que se crea y quién lo ve
-- =====================================================================

-- 1. Las 28 vistas, todas security_invoker y con SELECT solo para
--    authenticated (anon y service_role, nada); las 8 tablas con RLS y su
--    única policy de lectura del dueño («(select es_dueno())», o la de
--    antes, «es_dueno()»: dicen lo mismo); ninguna función de c4 SECURITY
--    DEFINER; y de la API solo fn_estados_control es ejecutable (y solo por
--    authenticated). Y ninguna vista de c4 nombra las columnas que las
--    pruebas 24 y 66 de c2 reescriben con ALTER TABLE … TYPE (cuentas.activa
--    y saldo_normal; periodos.estado y cerrado_*): si las nombrara, les
--    fijaría el tipo y esas dos pruebas de c2 saldrían en rojo (0A000).
do $$
declare
  v_vistas text[] := array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                           'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra', 'v_balance_general',
                           'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos', 'v_flujo_real_por_mes',
                           'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria',
                           'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion',
                           'v_comparacion_obra', 'v_comparacion_resumen'];
  v_tablas text[] := array['estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                           'apertura_balanza_qb', 'comparacion_qb', 'diferencias'];
  v_obt text;
  v_esp text := 'vistas=28 invoker=28 select_auth=28 otros_privilegios=0 tablas_rls=8 policies=8 definer=0 api=fn_estados_control(text,text[]) columnas_fijadas=0';
begin
  select format('vistas=%s invoker=%s select_auth=%s otros_privilegios=%s tablas_rls=%s policies=%s definer=%s api=%s columnas_fijadas=%s',
    (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (v_vistas)),
    (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (v_vistas)
        and 'security_invoker=true' = any (coalesce(c.reloptions, '{}'))),
    (select count(*) from unnest(v_vistas) v where has_table_privilege('authenticated', 'public.' || v, 'select')),
    (select count(*) from unnest(v_vistas) v, unnest(array['anon', 'service_role']) r
      where has_table_privilege(r, 'public.' || v, 'select'))
      + (select count(*) from unnest(v_vistas) v
          where has_table_privilege('authenticated', 'public.' || v, 'insert,update,delete,truncate,references,trigger')),
    (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas) and c.relrowsecurity),
    (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = any (v_tablas)
        and p.policyname = p.tablename || '_dueno' and p.cmd = 'SELECT'
        and regexp_replace(p.qual, '[[:space:]]', '', 'g') in ('es_dueno()', '(SELECTes_dueno()ASes_dueno)')),
    (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef
        and (p.proname like 'fn\_estados\_%' or p.proname like 'fn\_apertura%' or p.proname like 'fn\_comparacion%'
             or p.proname like 'fn\_diferencia%')),
    (select coalesce(string_agg(p.oid::regprocedure::text, ', ' order by p.proname), '(ninguna)')
       from pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and (p.proname like 'fn\_estados\_%' or p.proname like 'fn\_apertura%' or p.proname like 'fn\_comparacion%'
             or p.proname like 'fn\_diferencia%')
        and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
             or has_function_privilege('service_role', p.oid, 'execute'))),
    (select count(*)
       from pg_depend d
       join pg_rewrite r on d.classid = 'pg_rewrite'::regclass and r.oid = d.objid
       join pg_class v on v.oid = r.ev_class
       join pg_attribute a on d.refclassid = 'pg_class'::regclass and a.attrelid = d.refobjid and a.attnum = d.refobjsubid
      where v.relnamespace = 'public'::regnamespace and v.relname = any (v_vistas)
        and ((a.attrelid = 'public.cuentas'::regclass and a.attname in ('activa', 'saldo_normal'))
          or (a.attrelid = 'public.periodos'::regclass
              and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cerrado_rol', 'cerrado_conexion', 'cadena_al_cerrar')))))
    into v_obt;
  insert into _pruebas values (1, 'vistas security_invoker solo para authenticated; tablas con RLS; ninguna DEFINER; de la API solo el control',
                               v_esp, v_obt, v_obt = v_esp);
exception when others then
  insert into _pruebas values (1, 'vistas security_invoker solo para authenticated; tablas con RLS; ninguna DEFINER; de la API solo el control',
                               v_esp, sqlstate || ' ' || left(sqlerrm, 90), false);
end $$;

-- 2. El equipo (con su login) lee 0 filas de TODAS las vistas, con el libro
--    lleno (la apertura de prueba y un mes), y no ejecuta nada nuevo: el
--    control le dice 42501, y las funciones del SQL Editor ni se le dejan
--    llamar (42501). anon no abre ninguna vista (42501).
do $$
declare
  v_vistas text[] := array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                           'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra', 'v_balance_general',
                           'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos', 'v_flujo_real_por_mes',
                           'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria',
                           'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion',
                           'v_comparacion_obra', 'v_comparacion_resumen'];
  v_fns text[] := array['select public.fn_estados_control(%L)', 'select public.fn_estados_mapeo_derivar()',
                        'select public.fn_estados_sembrar()', 'select public.fn_estados_mapeo(''1010'', ''{}'')',
                        'select public.fn_estados_linea(''resultados'', ''costo'', ''x'', ''x'', ''x'')',
                        'select public.fn_estados_config(''plegar_3200'', ''si'')',
                        'select public.fn_apertura_mapeo_qb(''x'', ''1010'')', 'select public.fn_apertura_mapeo_trabajo(''x'', ''x'')',
                        'select public.fn_apertura_balanza_cargar(''x'', ''[]'')', 'select public.fn_apertura_plan(''x'')',
                        'select * from public.fn_apertura_revisar(''x'')', 'select public.fn_apertura(''2026-09-30'', ''x'')',
                        'select public.fn_comparacion_qb_cargar(%L, ''x'', ''[]'')',
                        'select public.fn_diferencia_anotar(%L, ''1010'', ''1'', ''puente'', ''x'')',
                        'select public.fn_diferencia_retirar(gen_random_uuid(), ''x'')'];
  v_v      text;
  v_f      text;
  v_n      bigint;
  v_dueno  bigint := 0;
  v_filas  bigint := 0;
  v_errv   text := '';
  v_fn     text := '';
  v_anon   text := '';
  v_obt    text;
  v_esp    text := 'dueño_ve>0 equipo_filas=0 equipo_errores= funciones=todas_42501 anon=todas_42501';
begin
  if nullif(current_setting('mx4.equipo', true), '') is null or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (2, 'el equipo lee 0 filas de todas las vistas y no ejecuta nada nuevo; anon no abre ninguna', v_esp,
                                 'omitida: falta alguien del equipo o el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    perform pg_temp.c4_como('dueno');
    select count(*) into v_dueno from public.v_libro;
    execute 'reset role';
    perform pg_temp.c4_como('equipo');
    foreach v_v in array v_vistas loop
      begin
        execute format('select count(*) from public.%I', v_v) into v_n;
        v_filas := v_filas + v_n;
      exception when others then
        v_errv := v_errv || v_v || ':' || sqlstate || ' ';
      end;
    end loop;
    foreach v_f in array v_fns loop
      begin
        execute format(v_f, current_setting('mx4.mes'));
        v_fn := v_fn || 'entró ';
      exception when others then
        if sqlstate <> '42501' then v_fn := v_fn || left(v_f, 40) || ':' || sqlstate || ' '; end if;
      end;
    end loop;
    execute 'reset role';
    perform pg_temp.c4_como('anon');
    foreach v_v in array v_vistas loop
      begin
        execute format('select count(*) from public.%I', v_v) into v_n;
        v_anon := v_anon || v_v || ':' || v_n || ' ';
      exception when others then
        if sqlstate <> '42501' then v_anon := v_anon || v_v || ':' || sqlstate || ' '; end if;
      end;
    end loop;
    foreach v_f in array v_fns loop
      begin
        execute format(v_f, current_setting('mx4.mes'));
        v_anon := v_anon || 'entró ';
      exception when others then
        if sqlstate <> '42501' then v_anon := v_anon || left(v_f, 40) || ':' || sqlstate || ' '; end if;
      end;
    end loop;
    execute 'reset role';
    perform pg_temp.c4_como(null);
    v_obt := format('dueño_ve%s equipo_filas=%s equipo_errores=%s funciones=%s anon=%s',
                    case when v_dueno > 0 then '>0' else '=0' end, v_filas, btrim(v_errv),
                    coalesce(nullif(btrim(v_fn), ''), 'todas_42501'), coalesce(nullif(btrim(v_anon), ''), 'todas_42501'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (2, 'el equipo lee 0 filas de todas las vistas y no ejecuta nada nuevo; anon no abre ninguna', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 3. Con c4 puesto y el libro lleno, los controles de c2 siguen en verde:
--    triggers (c4 no toca las huellas) y permisos (ninguna vista sin
--    security_invoker, ninguna función SECURITY DEFINER de la API que lea
--    el libro). Y los de c3: partidas y documentos. (Cada verificador una
--    vez, cada uno en su vuelta con el escenario: el libro no queda tomado
--    más que lo que tarda uno.)
do $$
declare
  v_obt text;
  v_esp text := 'triggers=t permisos=t cuadre=t reversos=t partidas=t documentos=t';
  v_c2  text;
  v_c3  text;
  v_k   text;
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (3, 'con c4 y el libro lleno, los controles de c2 y c3 siguen en verde', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  foreach v_k in array array['c2', 'c3'] loop
    begin
      perform pg_temp.c4_escenario();
      if v_k = 'c2' then
        select format('triggers=%s permisos=%s cuadre=%s reversos=%s',
                      max(v.ok::text) filter (where v.control = 'triggers'), max(v.ok::text) filter (where v.control = 'permisos'),
                      max(v.ok::text) filter (where v.control = 'cuadre'), max(v.ok::text) filter (where v.control = 'reversos'))
          into v_c2
          from fn_verificar_cadena() v;
      else
        select format('partidas=%s documentos=%s',
                      max(v.ok::text) filter (where v.control = 'partidas'), max(v.ok::text) filter (where v.control = 'documentos'))
          into v_c3
          from fn_puentes_verificar() v;
      end if;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_obt := coalesce(v_obt, '') || v_k || ': ' || sqlstate || ' ' || left(sqlerrm, 90) || ' ';
    end;
  end loop;
  v_obt := coalesce(v_obt, replace(replace(v_c2 || ' ' || v_c3, 'true', 't'), 'false', 'f'));
  insert into _pruebas values (3, 'con c4 y el libro lleno, los controles de c2 y c3 siguen en verde', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- B · El mapeo de cada cuenta
-- =====================================================================

-- 4. Cada cuenta del plan tiene su fila, derivada de su tipo y su código
--    (efectivo, contra-cuentas, tarjetas, impuestos, intereses, utilidades
--    retenidas). Una cuenta NUEVA del plan (una tarjeta) sin fila: los
--    estados la pintan igual (con lo propuesto), pero fn_estados_control
--    la dice en rojo con su nombre; fn_estados_mapeo_derivar() le da su
--    fila y el control vuelve a verde.
do $$
declare
  v_obt  text;
  v_esp  text := 'filas=todas 1010=activo_circulante/efectivo/1/f/t/efectivo 1590=activo_fijo/depreciacion_acumulada/1/t/f/no_monetario '
                 '3200=capital/distribuciones/-1/t/f/fin_distribuciones 5011=costo/costo/1/t/f/resultado '
                 '2100-2009=pasivo_circulante/tarjetas/-1/f/f/op_tarjetas 9000=gastos/gastos/1/f/f/resultado '
                 '3900=capital/utilidades_retenidas/-1/f/f/ajustes nueva=sin_fila:t balanza:500.00 control:f:2100-9997 '
                 'derivar=t control_despues:t';
  v_a    text;
  v_b    text;
  v_c    text;
  v_f    text;
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (4, 'cada cuenta con su fila; una cuenta nueva sin fila se dice en rojo', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    v_f := case when (select count(*) from cuentas) = (select count(*) from estados_mapeo) then 'todas' else 'faltan' end;
    select string_agg(format('%s=%s/%s/%s/%s/%s/%s', m.cuenta, m.seccion, m.linea, m.signo, case when m.contra then 't' else 'f' end,
                             case when m.efectivo then 't' else 'f' end, m.flujo_indirecto), ' ' order by k.o)
      into v_a
      from (values ('1010', 1), ('1590', 2), ('3200', 3), ('5011', 4), ('2100-2009', 5), ('9000', 6), ('3900', 7)) as k(c, o)
      join v_estados_mapeo m on m.cuenta = k.c;
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9997', 'c4-pruebas: tarjeta nueva', 'c4 new card', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
    perform fn_postear(jsonb_build_object('fecha', current_setting('mx4.desde'), 'descripcion', 'c4-pruebas: cargo a la tarjeta nueva',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6300', 'monto', '500.00'),
                                  jsonb_build_object('cuenta', '2100-9997', 'monto', '-500.00'))));
    select format('nueva=sin_fila:%s balanza:%s control:%s:%s',
                  (select case when m.sin_fila then 't' else 'f' end from v_estados_mapeo m where m.cuenta = '2100-9997'),
                  (select -b.saldo_final from v_balanza b where b.periodo = current_setting('mx4.mes') and b.cuenta = '2100-9997'),
                  (select case when c.ok then 't' else 'f' end from fn_estados_control(current_setting('mx4.mes'), array['v_estados_mapeo']) c
                    where c.vista = 'cuadre: mapeo completo'),
                  (select substring(c.detalle from '2100-9997') from fn_estados_control(current_setting('mx4.mes'), array['v_estados_mapeo']) c
                    where c.vista = 'cuadre: mapeo completo'))
      into v_b;
    select format('derivar=%s control_despues:%s', (fn_estados_mapeo_derivar())->'anadidas' @? '$[*] ? (@.cuenta == "2100-9997")',
                  (select case when c.ok then 't' else 'f' end from fn_estados_control(current_setting('mx4.mes'), array['v_estados_mapeo']) c
                    where c.vista = 'cuadre: mapeo completo'))
      into v_c;
    v_obt := format('filas=%s %s %s %s', v_f, v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (4, 'cada cuenta con su fila; una cuenta nueva sin fila se dice en rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 5. El mapeo se ajusta con rastro, y la guarda no deja uno incoherente:
--    6130 a «otros gastos» (queda en el historial, antes y después, y el
--    estado de resultados lo enseña ahí); un renglón nuevo que agrupa dos
--    cuentas (Renta y servicios) sale como renglón con su suma; 1010 al
--    pasivo, 6100 como dinero, un signo cambiado a mano en el SQL Editor y
--    un renglón del flujo repetido: MX006, en español.
do $$
declare
  v_mes  text := current_setting('mx4.mes', true);
  v_obt  text;
  v_esp  text := 'historial=gastos→otros_gastos estado=otros_gastos renglon=ocupacion:1300.00 1010_pasivo=MX006 6100_efectivo=MX006 '
                 'signo_a_mano=MX006 flujo_repetido=MX006';
  v_h    text;
  v_r    text;
  v_x    text[] := '{}';
  v_antes numeric;
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (5, 'el mapeo se ajusta con rastro; la guarda no deja uno incoherente', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform fn_estados_mapeo('6130', '{"seccion": "otros_gastos"}');
    select (h.antes->>'seccion') || '→' || (h.despues->>'seccion') into v_h
      from estados_historial h where h.tabla = 'estados_mapeo' and h.clave = '6130' and h.operacion = 'UPDATE'
     order by h.cambiado_el desc limit 1;
    -- (Lo que ya había en 6100 y 6110 en el mes, para medir solo lo de la
    -- prueba: el renglón nuevo agrupa las dos.)
    select coalesce(sum(r.mes), 0) into v_antes from v_resultados r
     where r.periodo = v_mes and r.nivel = 'cuenta' and r.cuenta in ('6100', '6110');
    perform fn_estados_linea('resultados', 'gastos', 'ocupacion', 'Renta y servicios', 'Occupancy', 305);
    perform fn_estados_mapeo('6100', '{"linea": "ocupacion"}');
    perform fn_estados_mapeo('6110', '{"linea": "ocupacion"}');
    perform fn_postear(jsonb_build_object('fecha', current_setting('mx4.desde'), 'descripcion', 'c4-pruebas: renta y luz',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '6110', 'monto', '300.00'),
                                  jsonb_build_object('cuenta', '6130', 'monto', '10.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-1310.00'))));
    select format('estado=%s renglon=%s',
                  (select r.seccion from v_resultados r where r.periodo = v_mes and r.nivel = 'cuenta' and r.cuenta = '6130'),
                  (select r.linea || ':' || (r.mes - v_antes) from v_resultados r
                    where r.periodo = v_mes and r.nivel = 'linea' and r.linea = 'ocupacion'))
      into v_r;
    begin perform fn_estados_mapeo('1010', '{"seccion": "pasivo_circulante", "linea": "otros_pasivos"}'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin perform fn_estados_mapeo('6100', '{"efectivo": true}'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin update estados_mapeo set signo = -1 where cuenta = '1010'; v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin perform fn_estados_linea('flujo_directo', 'inversion', 'proveedores', 'x', 'x'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    v_obt := format('historial=%s %s 1010_pasivo=%s 6100_efectivo=%s signo_a_mano=%s flujo_repetido=%s', v_h, v_r, v_x[1], v_x[2],
                    v_x[3], v_x[4]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (5, 'el mapeo se ajusta con rastro; la guarda no deja uno incoherente', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 6. VOLVER A PEGAR c4 encima de sí mismo: lo que el pegado siembra
--    (fn_estados_sembrar: renglones, configuración, mapeo) no duplica nada,
--    no pisa lo que Edgar ajustó (una etiqueta, un mapeo, la configuración)
--    y no ensucia el historial. (Que las vistas y funciones se vuelven a
--    crear igual lo prueba el banco pegando el archivo dos veces.)
do $$
declare
  v_obt  text;
  v_esp  text := 'sembrar={"mapeo": [], "renglones": 0, "configuracion": 0} historial=+0 etiqueta=Ingresos de obra mapeo=Material de obra '
                 'config=si renglones=igual';
  v_h    bigint;
  v_l    bigint;
  v_s    jsonb;
begin
  begin
    perform fn_estados_linea('resultados', 'ingresos', 'ingresos', 'Ingresos de obra', 'Contract revenue');
    perform fn_estados_mapeo('5100', '{"etiqueta_es": "Material de obra"}');
    perform fn_estados_config('plegar_3200', 'si');
    select count(*) into v_h from estados_historial;
    select count(*) into v_l from estados_lineas;
    v_s := fn_estados_sembrar();
    select format('sembrar=%s historial=+%s etiqueta=%s mapeo=%s config=%s renglones=%s', v_s,
                  (select count(*) from estados_historial) - v_h,
                  (select l.etiqueta_es from estados_lineas l where l.estado = 'resultados' and l.seccion = 'ingresos' and l.linea = 'ingresos'),
                  (select m.etiqueta_es from estados_mapeo m where m.cuenta = '5100'),
                  (select c.valor from estados_config c where c.clave = 'plegar_3200'),
                  case when (select count(*) from estados_lineas) = v_l then 'igual' else 'cambió' end)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (6, 'volver a pegar no duplica, no pisa lo ajustado y no ensucia el historial', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- C · La balanza y el balance
-- =====================================================================

-- 7. LA BALANZA EN CERO con asientos de todos los tipos (la apertura, los
--    normales de los puentes y a mano, un reverso, un devengo reversible y
--    su reverso automático, un ajuste del CPA): en la apertura, el mes, el
--    siguiente y el año, el total da saldo inicial y final en cero y debe =
--    haber; y cada cifra es la del libro (saldo final por cuenta contra las
--    líneas, SQL contra SQL).
do $$
declare
  v_obt text;
  v_esp text := 'tipos=ajuste_cpa,apertura,normal caminos=mano,puente,reverso,reverso_automatico cuadra=t,t,t,t distintas=0';
  v_ps  text[];
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (7, 'la balanza en cero con asientos de todos los tipos', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_escenario_completo();
    v_ps := array[current_setting('mx4.apertura'), current_setting('mx4.mes'), current_setting('mx4.sig'), current_setting('mx4.anio')];
    select format('tipos=%s caminos=%s cuadra=%s distintas=%s',
                  (select string_agg(distinct a.tipo, ',' order by a.tipo) from asientos a),
                  (select string_agg(distinct a.camino, ',' order by a.camino) from asientos a),
                  (select string_agg(coalesce((select case when b.cuadra and b.debe = b.haber and b.saldo_inicial = 0 and b.saldo_final = 0
                                                           then 't' else 'f' end
                                                 from v_balanza b where b.periodo = x.p and b.nivel = 'total'), 'sin total'), ','
                                     order by x.n)
                     from unnest(v_ps) with ordinality as x(p, n)),
                  (select count(*)
                     from unnest(v_ps) x(p)
                     join periodos p on p.periodo = x.p
                     join v_balanza b on b.periodo = x.p and b.nivel = 'cuenta'
                    where b.saldo_final <> (select coalesce(sum(l.monto), 0)
                                              from asiento_lineas l join asientos a on a.id = l.asiento_id
                                              left join periodos pa on pa.periodo = a.afecta_periodo
                                             where l.cuenta = b.cuenta and a.fecha_contable <= p.hasta
                                               and (b.estado = 'balance' or coalesce(pa.anio, a.anio) = p.anio))))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (7, 'la balanza en cero con asientos de todos los tipos', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 8. ACTIVO = PASIVO + CAPITAL + RESULTADO, con asientos de todos los
--    tipos, en cada corte (la apertura, el mes, el siguiente, el año): la
--    fila «cuadra» en 0.00; el total del activo es el del libro más sus
--    reclasificaciones (SQL contra SQL); y el resultado del ejercicio del
--    balance es la utilidad neta acumulada del estado de resultados.
do $$
declare
  v_obt text;
  v_esp text := 'cuadra=0.00,0.00,0.00,0.00 activo_libro=t,t,t,t resultado=t,t,t';
  v_ps  text[];
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (8, 'activo = pasivo + capital + resultado en cada corte', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_escenario_completo();
    v_ps := array[current_setting('mx4.apertura'), current_setting('mx4.mes'), current_setting('mx4.sig'), current_setting('mx4.anio')];
    select format('cuadra=%s activo_libro=%s resultado=%s',
      (select string_agg(coalesce((select b.cifra::text from v_balance_general b
                                    where b.periodo = x.p and b.nivel = 'total' and b.linea = 'cuadra' and b.cuadra), 'no'), ','
                         order by x.n)
         from unnest(v_ps) with ordinality as x(p, n)),
      -- (el activo del libro más sus reclasificaciones de presentación: los
      -- saldos contrarios que van al otro lado —anticipos, sobregiros,
      -- saldos a favor—, que la prueba 25 baja a sus líneas)
      (select string_agg(case when (select b.cifra from v_balance_general b
                                     where b.periodo = x.p and b.nivel = 'total' and b.linea = 'total_activo')
                                   = (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                        join cuentas c on c.codigo = l.cuenta
                                       where c.tipo = 'activo' and a.fecha_contable <= (select p.hasta from periodos p where p.periodo = x.p))
                                     + coalesce((select sum(b.cifra) from v_balance_general b
                                                  where b.periodo = x.p and b.nivel = 'componente'
                                                    and b.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')), 0)
                              then 't' else 'f' end, ',' order by x.n)
         from unnest(v_ps) with ordinality as x(p, n)),
      (select string_agg(case when coalesce((select b.cifra from v_balance_general b
                                              where b.periodo = x.p and b.nivel = 'componente' and b.componente = 'resultado'), 0)
                                   = coalesce((select r.acumulado from v_resultados r
                                                where r.periodo = x.p and r.nivel = 'total' and r.linea = 'utilidad_neta'), 0)
                              then 't' else 'f' end, ',' order by x.n)
         from unnest(v_ps[2:4]) with ordinality as x(p, n)))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (8, 'activo = pasivo + capital + resultado en cada corte', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 9. UN DESCUADRE NO ENTRA: ni por fn_postear, ni por la puerta interna, ni
--    con un insert directo en el SQL Editor (MX001); el libro no cambia y
--    la balanza sigue en cero.
do $$
declare
  v_obt text;
  v_esp text := 'fn_postear=MX001 interna=MX001 directo=MX001 asientos=+0 cuadra=t';
  v_n   bigint;
  v_x   text[] := '{}';
  v_id  uuid := gen_random_uuid();
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (9, 'un descuadre no entra y la balanza sigue en cero', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select count(*) into v_n from asientos;
    begin
      perform fn_postear(jsonb_build_object('fecha', current_setting('mx4.desde'), 'descripcion', 'c4-pruebas: descuadrado',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '100.00'),
                                    jsonb_build_object('cuenta', '1010', 'monto', '-99.99'))));
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin
      perform fn_postear_interno(jsonb_build_object('camino', 'mano', 'fecha', current_setting('mx4.desde'),
        'descripcion', 'c4-pruebas: descuadrado', 'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '100.00'),
                                                                               jsonb_build_object('cuenta', '1010', 'monto', '-100.01'))));
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin
      insert into asiento_lineas (asiento_id, orden, cuenta, monto) values (v_id, 1, '6500', 100.00), (v_id, 2, '1010', -90.00);
      insert into asientos (id, fecha_contable, camino, descripcion) values (v_id, current_setting('mx4.desde')::date, 'mano', 'c4-pruebas');
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    select format('fn_postear=%s interna=%s directo=%s asientos=+%s cuadra=%s', v_x[1], v_x[2], v_x[3],
                  (select count(*) from asientos) - v_n,
                  (select case when b.cuadra then 't' else 'f' end from v_balanza b
                    where b.periodo = current_setting('mx4.mes') and b.nivel = 'total'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (9, 'un descuadre no entra y la balanza sigue en cero', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 10. EL MAYOR: el saldo corrido de cada cuenta, en la última línea del
--     mes, es el saldo final de su balanza; cada línea trae su asiento; y
--     el saldo en su lado de las cuentas por pagar sale en positivo.
do $$
declare
  v_obt text;
  v_esp text := 'cuentas_distintas=0 sin_asiento=0 cxp_en_su_lado=positivo';
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (10, 'el mayor: saldo corrido = balanza; cada línea con su asiento', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select format('cuentas_distintas=%s sin_asiento=%s cxp_en_su_lado=%s',
      (select count(*) from v_balanza b
        where b.periodo = current_setting('mx4.mes') and b.nivel = 'cuenta' and b.estado = 'balance'
          and b.saldo_final is distinct from (select m.saldo from v_mayor m
                                               where m.cuenta = b.cuenta and m.fecha <= b.hasta
                                               order by m.fecha desc, m.cadena_pos desc, m.orden desc limit 1)),
      (select count(*) from v_mayor m where m.periodo = current_setting('mx4.mes')
          and not exists (select 1 from asientos a where a.id = m.asiento_id)),
      (select case when m.saldo_en_su_lado > 0 then 'positivo' else 'no' end from v_mayor m
        where m.cuenta = fn_puente_cuenta_de('cxp') and m.periodo = current_setting('mx4.mes')
        order by m.fecha desc, m.cadena_pos desc, m.orden desc limit 1))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (10, 'el mayor: saldo corrido = balanza; cada línea con su asiento', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 11. LA BALANZA POR OBRA Y COST CODE suma, cuenta por cuenta, lo mismo
--     que la balanza (saldo inicial, debe, haber, saldo final), y su total
--     también está en cero.
do $$
declare
  v_obt text;
  v_esp text := 'cuentas_distintas=0 cuadra=t con_obra=t';
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (11, 'la balanza por obra suma lo mismo que la balanza', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select format('cuentas_distintas=%s cuadra=%s con_obra=%s',
      (select count(*) from v_balanza b
        where b.periodo = current_setting('mx4.mes') and b.nivel = 'cuenta'
          and row(b.saldo_inicial::numeric, b.debe::numeric, b.haber::numeric, b.saldo_final::numeric)
              is distinct from (select row(sum(o.saldo_inicial)::numeric, sum(o.debe)::numeric, sum(o.haber)::numeric,
                                           sum(o.saldo_final)::numeric)
                                  from v_balanza_obra o
                                 where o.periodo = b.periodo and o.nivel = 'cuenta' and o.cuenta = b.cuenta)),
      (select case when o.cuadra then 't' else 'f' end from v_balanza_obra o where o.periodo = current_setting('mx4.mes') and o.nivel = 'total'),
      (select case when count(*) > 0 then 't' else 'f' end from v_balanza_obra o
        where o.periodo = current_setting('mx4.mes') and o.proyecto_id = current_setting('mx4.obra') and o.cost_code is null
          and o.cuenta = '5100'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (11, 'la balanza por obra suma lo mismo que la balanza', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- D · El estado de resultados
-- =====================================================================

-- 12. MES CONTRA MES Y LO DEL AÑO: en el mes y el siguiente, cada cuenta
--     del estado de resultados es la del libro (SQL contra SQL: el mes, el
--     mes anterior y el acumulado, con el signo del estado), la variación
--     es mes − mes anterior, y la utilidad neta es −(la suma de las líneas
--     de resultados). El devengo reversible sale en su mes y su reverso
--     automático en el siguiente (mes contra mes: −800 en honorarios). El
--     mes anterior va con su propio ejercicio (el de enero es diciembre
--     del año anterior): antes la prueba lo medía con el del mes y, con
--     enero como el mes abierto más antiguo, salía en rojo con datos
--     normales.
do $$
declare
  v_obt text;
  v_esp text := 'cuentas_distintas=0 variacion_mal=0 utilidad=t,t devengo=400.00→-400.00';
  v_ps  text[];
  v_d1  numeric;
  v_d2  numeric;
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (12, 'mes contra mes y lo del año, cuenta por cuenta, contra el libro', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    -- (Lo que ya había en 6600 en el mes y el siguiente: el devengo se mide
    -- por lo que cambió.)
    select coalesce(sum(r.mes) filter (where r.periodo = current_setting('mx4.mes')), 0),
           coalesce(sum(r.mes) filter (where r.periodo = current_setting('mx4.sig')), 0)
      into v_d1, v_d2
      from v_resultados r where r.periodo in (current_setting('mx4.mes'), current_setting('mx4.sig'))
       and r.nivel = 'cuenta' and r.cuenta = '6600';
    perform pg_temp.c4_escenario();
    v_ps := array[current_setting('mx4.mes'), current_setting('mx4.sig')];
    select format('cuentas_distintas=%s variacion_mal=%s utilidad=%s devengo=%s',
      (select count(*)
         from unnest(v_ps) x(p)
         join periodos p on p.periodo = x.p
         join v_resultados r on r.periodo = x.p and r.nivel = 'cuenta'
         cross join lateral (
           -- (El mes anterior, con SU ejercicio: el de enero es diciembre
           -- del año anterior, con lo de ese año.)
           select coalesce(sum(l.monto) filter (where a.fecha_contable between p.desde and p.hasta
                                                  and coalesce(pa.anio, a.anio) = p.anio), 0) as m,
                  coalesce(sum(l.monto) filter (where a.fecha_contable between (p.desde - interval '1 month')::date and p.desde - 1
                                                  and coalesce(pa.anio, a.anio)
                                                      = extract(year from p.desde - interval '1 month')::int), 0) as ma,
                  coalesce(sum(l.monto) filter (where a.fecha_contable between make_date(p.anio, 1, 1) and p.hasta
                                                  and coalesce(pa.anio, a.anio) = p.anio), 0) as ac
             from asiento_lineas l join asientos a on a.id = l.asiento_id
             left join periodos pa on pa.periodo = a.afecta_periodo
            where l.cuenta = r.cuenta) s
        where r.mes <> (select m.signo from estados_mapeo m where m.cuenta = r.cuenta) * s.m
           or r.mes_anterior <> (select m.signo from estados_mapeo m where m.cuenta = r.cuenta) * s.ma
           or r.acumulado <> (select m.signo from estados_mapeo m where m.cuenta = r.cuenta) * s.ac),
      (select count(*) from v_resultados r where r.periodo = any (v_ps) and r.variacion <> r.mes - r.mes_anterior),
      (select string_agg(case when r.acumulado = -(select coalesce(sum(l.monto), 0)
                                                    from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                    join cuentas c on c.codigo = l.cuenta
                                                    join periodos p on p.periodo = r.periodo
                                                   where c.tipo not in ('activo', 'pasivo', 'capital') and a.anio = p.anio
                                                     and a.fecha_contable <= p.hasta and a.afecta_periodo is null)
                              then 't' else 'f' end, ',' order by r.periodo)
         from v_resultados r where r.periodo = any (v_ps) and r.nivel = 'total' and r.linea = 'utilidad_neta'),
      (select (r1.mes - v_d1) || '→' || (r2.mes - v_d2) from v_resultados r1, v_resultados r2
        where r1.periodo = v_ps[1] and r1.nivel = 'cuenta' and r1.cuenta = '6600'
          and r2.periodo = v_ps[2] and r2.nivel = 'cuenta' and r2.cuenta = '6600'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (12, 'mes contra mes y lo del año, cuenta por cuenta, contra el libro', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 13. UN AJUSTE DEL CPA POSTERIOR (con el mes cerrado, fechado en el
--     siguiente): el estado de resultados del mes lo enseña en
--     «posteriores» (y en el acumulado ajustado) sin cambiar su acumulado a
--     esa fecha; el del mes siguiente lo lleva en su mes si es del mismo
--     ejercicio (−400 del devengo que se reversa + 75); si el siguiente es
--     enero, el ajuste es del año anterior y no entra en su mes (solo el
--     −400); el balance del mes no lo ve y el del siguiente sí. (Antes la
--     prueba esperaba siempre −325: con diciembre como mes abierto más
--     antiguo daba un falso rojo.)
do $$
declare
  v_obt text;
  v_esp text;
  v_mes text := current_setting('mx4.mes', true);
  v_sig text := current_setting('mx4.sig', true);
  v_p0  numeric;
  v_s0  numeric;
  v_b1  numeric;
  v_b2  numeric;
begin
  v_esp := format('posteriores=75.00 ajustado=acumulado+posteriores siguiente=%s balance_mes=+400.00 balance_sig=+75.00',
                  case when (select pm.anio from periodos pm where pm.periodo = v_mes)
                            = (select ps.anio from periodos ps where ps.periodo = v_sig)
                       then '-325.00' else '-400.00' end);
  if nullif(v_sig, '') is null then
    insert into _pruebas values (13, 'un ajuste del CPA posterior: en posteriores del mes, en el mes siguiente', v_esp,
                                 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    -- (Lo que ya había: se mide lo que cambia el escenario.)
    select coalesce(sum(r.posteriores) filter (where r.periodo = v_mes), 0),
           coalesce(sum(r.mes) filter (where r.periodo = v_sig), 0)
      into v_p0, v_s0
      from v_resultados r where r.periodo in (v_mes, v_sig) and r.nivel = 'cuenta' and r.cuenta = '6600';
    select coalesce(sum(b.cifra) filter (where b.periodo = v_mes), 0), coalesce(sum(b.cifra) filter (where b.periodo = v_sig), 0)
      into v_b1, v_b2
      from v_balance_general b where b.periodo in (v_mes, v_sig) and b.nivel = 'cuenta' and b.cuenta = '2050';
    perform pg_temp.c4_escenario_completo();
    select format('posteriores=%s ajustado=%s siguiente=%s balance_mes=%s balance_sig=%s',
      (select r.posteriores - v_p0 from v_resultados r where r.periodo = v_mes and r.nivel = 'cuenta' and r.cuenta = '6600'),
      (select case when r.acumulado_ajustado = r.acumulado + r.posteriores then 'acumulado+posteriores'
                   else r.acumulado_ajustado::text end
         from v_resultados r where r.periodo = v_mes and r.nivel = 'cuenta' and r.cuenta = '6600'),
      (select r.mes - v_s0 from v_resultados r where r.periodo = v_sig and r.nivel = 'cuenta' and r.cuenta = '6600'),
      (select to_char(b.cifra - v_b1, 'FMSG999999990.00') from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'cuenta' and b.cuenta = '2050'),
      (select to_char(b.cifra - v_b2, 'FMSG999999990.00') from v_balance_general b
        where b.periodo = v_sig and b.nivel = 'cuenta' and b.cuenta = '2050'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (13, 'un ajuste del CPA posterior: en posteriores del mes, en el mes siguiente', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- E · El cierre del año
-- =====================================================================

-- 14. EL ARRASTRE A 3900 AL CERRAR EL AÑO. Con los meses del año cerrados
--     pero el año todavía abierto, el balance de enero siguiente enseña el
--     resultado del año anterior en «por cerrar»; cerrado el año, dentro de
--     utilidades retenidas (3900 + arrastre), sin postear nada. Un ajuste
--     del CPA a diciembre, posteado en enero, va con el año anterior (al
--     arrastre), no al resultado de enero. En los dos momentos cuadra. (El
--     resultado de enero y su utilidad, lo que cambia la prueba: enero
--     puede tener ya sus asientos.)
do $$
declare
  v_anio   int := nullif(current_setting('mx4.anio', true), '')::int;
  v_ene    text;
  v_dic    text;
  v_res    numeric;
  v_r0     numeric;
  v_u0     numeric;
  v_antes  text;
  v_obt    text;
  v_esp    text := 'antes: por_cerrar=R resultado=-60.00 cuadra=0.00 · despues: arrastre=R+ajuste por_cerrar=no retenidas=3900+arrastre '
                   'resultado=-60.00 enero_utilidad=-60.00 cuadra=0.00 asientos_de_cierre=0';
  v_n      bigint;
begin
  select p.periodo into v_ene from periodos p where p.tipo = 'mes' and p.desde = make_date(v_anio + 1, 1, 1);
  select p.periodo into v_dic from periodos p where p.tipo = 'mes' and p.desde = make_date(v_anio, 12, 1);
  if v_ene is null or v_dic is null or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (14, 'el arrastre a 3900 al cerrar el año (por cerrar → utilidades retenidas)', v_esp,
                                 'omitida: faltan diciembre o enero en el calendario', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_escenario();
    perform pg_temp.c4_cerrar_hasta(v_dic);
    -- El resultado del año (todo lo de resultados de ese ejercicio).
    select -coalesce(sum(l.monto), 0) into v_res
      from asiento_lineas l join asientos a on a.id = l.asiento_id join cuentas c on c.codigo = l.cuenta
     where c.tipo not in ('activo', 'pasivo', 'capital') and a.anio = v_anio;
    -- Lo que enero ya tenía (antes de la prueba).
    select coalesce((select b.cifra from v_balance_general b
                      where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'resultado'), 0),
           coalesce((select r.acumulado from v_resultados r
                      where r.periodo = v_ene and r.nivel = 'total' and r.linea = 'utilidad_neta'), 0)
      into v_r0, v_u0;
    perform fn_postear(jsonb_build_object('fecha', make_date(v_anio + 1, 1, 5)::text, 'descripcion', 'c4-pruebas: gasto de enero',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '60.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-60.00'))));
    select count(*) into v_n from asientos;
    select format('antes: por_cerrar=%s resultado=%s cuadra=%s',
      (select case when b.cifra = v_res then 'R' else b.cifra::text end from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'por_cerrar'),
      (select (b.cifra - v_r0)::numeric(14,2) from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'resultado'),
      (select b.cifra from v_balance_general b where b.periodo = v_ene and b.nivel = 'total' and b.linea = 'cuadra'))
      into v_antes;
    -- El ajuste del CPA a diciembre, en enero; y el cierre del año.
    perform fn_postear(jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_dic, 'fecha', make_date(v_anio + 1, 1, 6)::text,
      'motivo', 'c4-pruebas: el CPA devenga honorarios de diciembre', 'descripcion', 'c4-pruebas: ajuste del CPA al año',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6600', 'monto', '40.00'),
                                  jsonb_build_object('cuenta', '2050', 'monto', '-40.00'))));
    update periodos set estado = 'cerrado' where periodo = v_anio::text;
    select format('%s · despues: arrastre=%s por_cerrar=%s retenidas=%s resultado=%s enero_utilidad=%s cuadra=%s asientos_de_cierre=%s',
      v_antes,
      (select case when b.cifra = v_res - 40 then 'R+ajuste' else b.cifra::text || ' (R=' || v_res || ')' end from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'arrastre'),
      coalesce((select b.cifra::text from v_balance_general b
                 where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'por_cerrar'), 'no'),
      (select case when l.cifra = coalesce((select b.cifra from v_balance_general b
                                             where b.periodo = v_ene and b.nivel = 'cuenta' and b.cuenta = '3900'), 0)
                                  + (select b.cifra from v_balance_general b
                                      where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'arrastre')
                   then '3900+arrastre' else l.cifra::text end
         from v_balance_general l where l.periodo = v_ene and l.nivel = 'linea' and l.linea = 'utilidades_retenidas'),
      (select (b.cifra - v_r0)::numeric(14,2) from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'resultado'),
      (select (r.acumulado - v_u0)::numeric(14,2) from v_resultados r
        where r.periodo = v_ene and r.nivel = 'total' and r.linea = 'utilidad_neta'),
      (select b.cifra from v_balance_general b where b.periodo = v_ene and b.nivel = 'total' and b.linea = 'cuadra'),
      (select count(*) - v_n - 1 from asientos))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (14, 'el arrastre a 3900 al cerrar el año (por cerrar → utilidades retenidas)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 15. PLEGAR 3200 (si el CPA lo pide): con el año cerrado, sus
--     distribuciones salen dentro de utilidades retenidas y la línea de
--     distribuciones enseña solo las de los años abiertos; el total del
--     capital no cambia y el balance cuadra. Solo presentación: no se
--     postea nada.
do $$
declare
  v_anio int := nullif(current_setting('mx4.anio', true), '')::int;
  v_ene  text;
  v_dic  text;
  v_cap  numeric;
  v_n    bigint;
  v_obt  text;
  v_esp  text := 'distribuciones=libro plegado_en_retenidas=libro:con_escenario capital=igual cuadra=0.00 asientos=+0';
begin
  select p.periodo into v_ene from periodos p where p.tipo = 'mes' and p.desde = make_date(v_anio + 1, 1, 1);
  select p.periodo into v_dic from periodos p where p.tipo = 'mes' and p.desde = make_date(v_anio, 12, 1);
  if v_ene is null or v_dic is null or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (15, 'plegar 3200 a utilidades retenidas: solo presentación', v_esp,
                                 'omitida: faltan diciembre o enero en el calendario', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_escenario();
    perform pg_temp.c4_cerrar_hasta(v_anio::text);
    select b.cifra into v_cap from v_balance_general b where b.periodo = v_ene and b.nivel = 'total' and b.linea = 'total_capital';
    select count(*) into v_n from asientos;
    perform fn_estados_config('plegar_3200', 'si');
    -- (Contra el libro, SQL contra SQL, para que valga con distribuciones
    -- de verdad: en la línea quedan las de los años abiertos; en
    -- utilidades retenidas, las de los cerrados, con la del escenario.)
    select format('distribuciones=%s plegado_en_retenidas=%s capital=%s cuadra=%s asientos=+%s',
      (select case when coalesce(l.cifra, 0) = -(select coalesce(sum(al.monto), 0)
                                                   from asiento_lineas al join asientos a on a.id = al.asiento_id
                                                   left join periodos pa on pa.periodo = a.afecta_periodo
                                                  where al.cuenta = '3200' and coalesce(pa.anio, a.anio) > v_anio
                                                    and a.fecha_contable <= (select p.hasta from periodos p where p.periodo = v_ene))
                   then 'libro' else coalesce(l.cifra::text, 'sin línea') end
         from (select (select l2.cifra from v_balance_general l2
                        where l2.periodo = v_ene and l2.nivel = 'linea' and l2.linea = 'distribuciones') as cifra) l),
      (select case when b.cifra = (select coalesce(sum(al.monto), 0)
                                     from asiento_lineas al join asientos a on a.id = al.asiento_id
                                     left join periodos pa on pa.periodo = a.afecta_periodo
                                    where al.cuenta = '3200' and coalesce(pa.anio, a.anio) <= v_anio
                                      and a.fecha_contable <= (select p.hasta from periodos p where p.periodo = v_ene))
                         * -1
                    and b.cifra <= -300
                   then 'libro:con_escenario' else b.cifra::text end
         from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'componente' and b.componente = 'plegado_3200' and b.linea = 'utilidades_retenidas'),
      (select case when b.cifra = v_cap then 'igual' else b.cifra::text end from v_balance_general b
        where b.periodo = v_ene and b.nivel = 'total' and b.linea = 'total_capital'),
      (select b.cifra from v_balance_general b where b.periodo = v_ene and b.nivel = 'total' and b.linea = 'cuadra'),
      (select count(*) - v_n from asientos))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (15, 'plegar 3200 a utilidades retenidas: solo presentación', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- F · El flujo de caja
-- =====================================================================

-- 16. DIRECTO = INDIRECTO = CAMBIO DEL EFECTIVO, en la apertura, el mes, el
--     siguiente y el año (con asientos de todos los tipos): las filas de
--     control (el cambio contra el efectivo y cada sección contra la del
--     otro método: operación, inversión, financiamiento y ajustes) en cero
--     y cuadra; el cambio de cada método es el del libro en las cuentas de
--     efectivo. Y cada cosa en su renglón (lo que el escenario cambió en el
--     mes): el cobro con comisión entra por su contrapartida (otros
--     ingresos +1000); la línea de crédito es financiamiento (+5000); la
--     distribución, del accionista (−300); la depreciación no mueve dinero
--     (en el indirecto se suma de vuelta, +250); un traspaso entre bancos
--     no es flujo; y la apertura no es un flujo: lo que trajo es el
--     efectivo al inicio del período de la apertura (con su leyenda), y el
--     cambio de cada período es el del efectivo del balance (las cuentas
--     en negro) sin la apertura. (El flujo de cada período se lee una vez,
--     a una tabla de la prueba: con el libro lleno la prueba tenía tomado el
--     libro 4 s.)
do $$
declare
  v_obt text;
  v_esp text := 'cuadra=t,t,t,t cambio_libro=t,t,t,t otros_operacion=+1000.00 prestamos=+5000.00 dueno=-300.00 '
                'no_monetario=+250.00 apertura=inicio traspaso=fuera';
  v_ps  text[];
  v_mes text := current_setting('mx4.mes', true);
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (16, 'flujo directo = indirecto = cambio del efectivo, sección por sección, cada cosa en su renglón', v_esp,
                                 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    -- (Lo que ya había en esos renglones del mes: se mide lo que cambia.
    -- Antes del candado: leer no detiene a nadie.)
    create temp table _c4_16 on commit drop as
      select f.metodo, f.linea, f.importe from v_flujo_caja f
       where f.periodo = v_mes and f.nivel = 'linea' and f.linea in ('otros_operacion', 'prestamos', 'dueno', 'no_monetario');
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_escenario_completo();
    v_ps := array[current_setting('mx4.apertura'), v_mes, current_setting('mx4.sig'), current_setting('mx4.anio')];
    -- (Cada período se lee UNA vez: con el libro lleno, cada lectura del
    -- flujo tarda, y la prueba tiene tomado el libro mientras tanto.)
    create temp table _c4_16f on commit drop as select * from v_flujo_caja f where f.periodo = any (v_ps);
    select format('cuadra=%s cambio_libro=%s otros_operacion=%s prestamos=%s dueno=%s no_monetario=%s apertura=%s traspaso=%s',
      (select string_agg(coalesce((select case when bool_and(f.cuadra) and bool_and(f.importe = 0) and count(*) = 10 then 't'
                                               else 'f' || count(*) end
                                     from _c4_16f f where f.periodo = x.p and f.nivel = 'control'), 'f'), ',' order by x.n)
         from unnest(v_ps) with ordinality as x(p, n)),
      -- (El cambio del efectivo del BALANCE, cuenta por cuenta desde el
      -- libro: lo que tenía en negro al terminar menos lo que tenía en negro
      -- al empezar, con lo que trajo la apertura contado al empezar.)
      (select string_agg(case when (select count(*) from _c4_16f f
                                     where f.periodo = x.p and f.nivel = 'total' and f.linea = 'cambio'
                                       and f.importe = (select coalesce(sum(greatest(z.s1, 0) - greatest(z.s0, 0)), 0)
                                                          from (select l.cuenta,
                                                                       coalesce(sum(l.monto) filter (where a.fecha_contable < p.desde
                                                                                                        or a.tipo = 'apertura'), 0) as s0,
                                                                       sum(l.monto) as s1
                                                                  from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                                  join estados_mapeo m on m.cuenta = l.cuenta and m.efectivo
                                                                  join periodos p on p.periodo = x.p
                                                                 where a.fecha_contable <= p.hasta
                                                                 group by l.cuenta) z)) = 2
                              then 't' else 'f' end, ',' order by x.n)
         from unnest(v_ps) with ordinality as x(p, n)),
      (select to_char(f.importe - coalesce((select a.importe from _c4_16 a where a.metodo = f.metodo and a.linea = f.linea), 0),
                      'FMSG999999990.00')
         from _c4_16f f where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'linea' and f.linea = 'otros_operacion'),
      (select to_char(f.importe - coalesce((select a.importe from _c4_16 a where a.metodo = f.metodo and a.linea = f.linea), 0),
                      'FMSG999999990.00')
         from _c4_16f f where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'linea' and f.linea = 'prestamos'),
      (select to_char(f.importe - coalesce((select a.importe from _c4_16 a where a.metodo = f.metodo and a.linea = f.linea), 0),
                      'FMSG999999990.00')
         from _c4_16f f where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'linea' and f.linea = 'dueno'),
      (select to_char(f.importe - coalesce((select a.importe from _c4_16 a where a.metodo = f.metodo and a.linea = f.linea), 0),
                      'FMSG999999990.00')
         from _c4_16f f where f.periodo = v_mes and f.metodo = 'indirecto' and f.nivel = 'linea' and f.linea = 'no_monetario'),
      -- (La apertura: su efectivo es el del inicio, en los dos métodos, con
      -- la leyenda de la apertura; y ningún renglón del período lo cuenta
      -- como entrada.)
      (select case when count(*) = 2
                        and bool_and(f.etiqueta_es like '%apertura del%')
                        and bool_and(f.importe = (select coalesce(sum(greatest(z.s0, 0)), 0)
                                                    from (select l.cuenta, sum(l.monto) as s0
                                                            from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                            join estados_mapeo m on m.cuenta = l.cuenta and m.efectivo
                                                            join periodos p on p.periodo = v_ps[1]
                                                           where a.fecha_contable < p.desde
                                                              or (a.tipo = 'apertura' and a.fecha_contable <= p.hasta)
                                                           group by l.cuenta) z))
                        and bool_and(f.importe > 0)
                        and not exists (select 1 from _c4_16f o
                                         where o.periodo = v_ps[1] and o.nivel = 'linea' and o.importe <> 0
                                           and o.linea <> 'sobregiro'
                                           and not exists (select 1 from v_flujo_lineas fl
                                                            join periodos p on p.periodo = v_ps[1]
                                                           where fl.fecha between p.desde and p.hasta and fl.tipo <> 'apertura'))
                   then 'inicio'
                   else 'f' || count(*) || coalesce(':' || string_agg(f.importe::text || ' ' || f.etiqueta_es, ';'), '') end
         from _c4_16f f
        where f.periodo = v_ps[1] and f.nivel = 'total' and f.linea = 'efectivo_inicial'),
      (select case when exists (select 1 from v_flujo_lineas fl
                                 where fl.descripcion = 'c4-pruebas: traspaso a la reserva de impuestos'
                                   and fl.fecha between current_setting('mx4.desde')::date
                                                    and (current_setting('mx4.desde')::date + interval '1 month')::date - 1)
                   then 'dentro' else 'fuera' end))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (16, 'flujo directo = indirecto = cambio del efectivo, sección por sección, cada cosa en su renglón', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 17. EL DINERO DE CADA MES (la gráfica del Panel): entradas − salidas =
--     neto = final − inicial = operación + inversión + financiamiento +
--     ajustes; el final de un mes es el inicial del siguiente; y el final
--     es el saldo de los bancos en el libro.
do $$
declare
  v_obt text;
  v_esp text := 'identidades=t,t encadena=t final_libro=t';
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (17, 'el dinero de cada mes: entradas − salidas = neto = final − inicial', v_esp,
                                 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select format('identidades=%s encadena=%s final_libro=%s',
      (select string_agg(case when f.entradas - f.salidas = f.neto and f.neto = f.efectivo_final - f.efectivo_inicial
                                   and f.neto = f.operacion + f.inversion + f.financiamiento + f.ajustes then 't' else 'f' end, ','
                         order by f.periodo)
         from v_flujo_real_por_mes f where f.periodo in (current_setting('mx4.mes'), current_setting('mx4.sig'))),
      (select case when a.efectivo_final = b.efectivo_inicial then 't' else 'f' end
         from v_flujo_real_por_mes a, v_flujo_real_por_mes b
        where a.periodo = current_setting('mx4.mes') and b.periodo = current_setting('mx4.sig')),
      (select case when f.efectivo_final = (select sum(s.saldo) from v_saldos_dinero s
                                             where s.periodo = f.periodo and s.tipo = 'banco') then 't' else 'f' end
         from v_flujo_real_por_mes f where f.periodo = current_setting('mx4.mes')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (17, 'el dinero de cada mes: entradas − salidas = neto = final − inicial', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- G · El tablero
-- =====================================================================

-- 18. BANCOS, TARJETAS Y LÍNEA DE CRÉDITO: el saldo de cada cuenta es el
--     del libro (en su lado); la tarjeta de prueba queda en cero (cargo de
--     350 y su pago); el saldo inicial del mes siguiente es el final del
--     mes; y cargos − abonos = el movimiento del mes.
do $$
declare
  v_obt text;
  v_esp text := 'saldo_libro=t tarjeta=0.00 encadena=t movimiento=t';
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (18, 'bancos, tarjetas y línea de crédito: saldo = libro', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select format('saldo_libro=%s tarjeta=%s encadena=%s movimiento=%s',
      (select case when bool_and(s.saldo = (case when m.saldo_normal = 'haber' then -1 else 1 end)
                                         * (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                             where l.cuenta = s.cuenta and a.fecha_contable <= s.corte)) then 't' else 'f' end
         from v_saldos_dinero s join cuentas m on m.codigo = s.cuenta where s.periodo = current_setting('mx4.mes')),
      (select s.saldo from v_saldos_dinero s where s.periodo = current_setting('mx4.mes') and s.cuenta = '2100-9998'),
      (select case when bool_and(b.saldo_inicial = a.saldo) then 't' else 'f' end
         from v_saldos_dinero a join v_saldos_dinero b on b.cuenta = a.cuenta
        where a.periodo = current_setting('mx4.mes') and b.periodo = current_setting('mx4.sig')),
      (select case when bool_and((s.cargos - s.abonos) * (case when m.saldo_normal = 'haber' then -1 else 1 end) = s.saldo - s.saldo_inicial)
                   then 't' else 'f' end
         from v_saldos_dinero s join cuentas m on m.codigo = s.cuenta where s.periodo = current_setting('mx4.mes')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (18, 'bancos, tarjetas y línea de crédito: saldo = libro', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 19. LA ANTIGÜEDAD DE LO QUE SE COBRA, partida por partida: un cobro
--     PARCIAL deja la factura abierta por la diferencia (con su retención
--     aparte, sin envejecer); el ANTICIPO aplicado cierra su factura y
--     desaparece; la NOTA DE CRÉDITO cierra la anulada; el CHEQUE DEVUELTO
--     la vuelve a abrir entera; las facturas de la apertura van con su
--     fecha de QuickBooks, y el crédito del cliente, sin partida. Cada una
--     en su tramo por los días desde su fecha, y el total = el mayor de
--     1110 + 1120. El anticipo es el del escenario (su cobro, por su id):
--     un anticipo de verdad en la misma obra no lo confunde.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_c    date;
  v_ap   boolean;
  v_e    jsonb;
begin
  if v_d is null then
    insert into _pruebas values (19, 'antigüedad de cobrar: parcial, anticipo, nota de crédito, cheque devuelto', '-', 'omitida: falta el mes abierto', null);
    return;
  end if;
  v_c := (date_trunc('month', v_d::timestamp) + interval '1 month')::date - 1;
  begin
    v_e := pg_temp.c4_escenario();
    v_ap := (v_e->>'con_apertura')::boolean;
    v_esp := concat_ws(' | ',
      format('C4-2:factura:5000.00:1000.00:%s', case when v_c - (v_d + 2) <= 30 then '0-30' else '31-60' end),
      format('C4-3:factura:500.00:0.00:%s', case when v_c - (v_d + 14) <= 30 then '0-30' else '31-60' end),
      format('C4-5:factura:3000.00:0.00:%s:cargos=6000.00:abonos=3000.00', case when v_c - (v_d + 10) <= 30 then '0-30' else '31-60' end),
      case when v_ap then format('C4-QB-1:factura:1500.00:500.00:%s', case when v_c - date '2026-08-15' <= 30 then '0-30'
                                                                              when v_c - date '2026-08-15' <= 60 then '31-60'
                                                                              when v_c - date '2026-08-15' <= 90 then '61-90' else '90+' end) end,
      case when v_ap then format('C4-QB-6:factura:4000.00:0.00:%s', case when v_c - date '2026-09-20' <= 30 then '0-30'
                                                                           when v_c - date '2026-09-20' <= 60 then '31-60'
                                                                           when v_c - date '2026-09-20' <= 90 then '61-90' else '90+' end) end,
      case when v_ap then 'sin_partida:sin_partida:-300.00:0.00:a_favor' end,
      'anticipo=cerrado anulada=cerrada total=mayor');
    select concat_ws(' | ',
      (select string_agg(format('%s:%s:%s:%s:%s', coalesce(x.factura_num, x.tipo), x.tipo, x.por_cobrar, x.retencion, x.tramo)
                         || case when x.factura_num = 'C4-5' then format(':cargos=%s:abonos=%s', x.cargos, x.abonos) else '' end,
                         ' | ' order by coalesce(x.factura_num, 'zz'))
         from v_cxc_antiguedad x
        where x.periodo = v_mes and x.nivel = 'partida'
          and ((x.partida_tabla = 'facturas' and x.partida_id::bigint between -4400099 and -4400001)
               or (v_ap and x.tipo = 'sin_partida' and x.proyecto_id = current_setting('mx4.obra'))
               or (x.tipo = 'anticipo' and x.partida_id = v_e->>'cobro_anticipo'))),
      format('anticipo=%s anulada=%s total=%s',
             case when exists (select 1 from v_cxc_antiguedad x where x.periodo = v_mes and x.tipo = 'anticipo'
                                  and x.partida_id = v_e->>'cobro_anticipo')
                  then 'abierto' else 'cerrado' end,
             case when exists (select 1 from v_cxc_antiguedad x where x.periodo = v_mes and x.factura_num = 'C4-4')
                  then 'abierta' else 'cerrada' end,
             (select case when x.cuadra and x.total = x.mayor then 'mayor' else x.total || '≠' || x.mayor end
                from v_cxc_antiguedad x where x.periodo = v_mes and x.nivel = 'total')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (19, 'antigüedad de cobrar: parcial, anticipo, nota de crédito, cheque devuelto', coalesce(v_esp, '-'),
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 20. LA ANTIGÜEDAD DE LO QUE SE PAGA: el recibo a cuenta con su abono
--     parcial (800 − 500), a nombre de su proveedor, con su vencimiento por
--     sus términos (Net 30); el trabajo externo a nombre del ayudante (sin
--     términos: sin vencimiento); lo que trajo la apertura por proveedor
--     (sin la fecha de su factura: tramo 'apertura', sin vencimiento
--     inventado); y el total = el mayor de 2010.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_ap   boolean;
begin
  if v_d is null then
    insert into _pruebas values (20, 'antigüedad de pagar: abono parcial, vencimiento por términos, por proveedor', '-', 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    v_ap := (pg_temp.c4_escenario()->>'con_apertura')::boolean;
    v_esp := concat_ws(' | ',
      format('papel:recibos:300.00:C4 PRUEBAS SUPPLY:vence=%s:0-30', v_d + 5 + 30),
      'papel:trabajos_externos:1200.00:C4 PRUEBAS AYUDANTE:vence=-:0-30',
      -- (lo de la apertura, sin la fecha de su factura en la balanza: sin
      -- vencimiento inventado, en el tramo 'apertura')
      case when v_ap then 'proveedor:-:2500.00:C4 PRUEBAS SUPPLY:vence=-:apertura' end,
      'total=mayor');
    select concat_ws(' | ',
      (select string_agg(format('%s:%s:%s:%s:vence=%s:%s', x.tipo, coalesce(x.partida_tabla, '-'), x.por_pagar, x.proveedor,
                                coalesce(x.vence::text, '-'), x.tramo), ' | ' order by x.tipo, x.partida_tabla)
         from v_cxp_antiguedad x
        where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor like 'C4 PRUEBAS%'),
      (select case when x.cuadra and x.total = x.mayor then 'total=mayor' else 'total=' || x.total || '≠' || x.mayor end
         from v_cxp_antiguedad x where x.periodo = v_mes and x.nivel = 'total'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (20, 'antigüedad de pagar: abono parcial, vencimiento por términos, por proveedor', coalesce(v_esp, '-'),
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 21. EN QUÉ SE GASTA Y A QUIÉN = EL MAYOR: la suma por categoría (cuenta)
--     y la suma por proveedor son las dos el gasto del libro del período
--     (SQL contra SQL); el proveedor sale del asiento (la deuda a cuenta, el
--     trabajo externo) o del nombre del recibo: sin alta, por su nombre; con
--     alta (un alias nuevo), el proveedor.
do $$
declare
  v_obt text;
  v_esp text := 'categoria=libro proveedor=libro supply=800.00:asiento ayudante=1200.00:asiento ferreteria=350.00:recibo_sin_alta '
                'con_alta=350.00:recibo';
  v_mes text := current_setting('mx4.mes', true);
  v_lib numeric;
  v_a   text;
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (21, 'gasto por categoría y por proveedor = el mayor', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select coalesce(sum(l.monto), 0) into v_lib
      from asiento_lineas l join asientos a on a.id = l.asiento_id join estados_mapeo m on m.cuenta = l.cuenta
      join periodos p on p.periodo = v_mes
     where m.estado = 'resultados' and m.seccion in ('costo', 'gastos', 'otros_gastos')
       and a.fecha_contable between p.desde and p.hasta and a.afecta_periodo is null;
    select format('categoria=%s proveedor=%s supply=%s ayudante=%s ferreteria=%s',
      (select case when sum(g.mes) filter (where g.nivel = 'cuenta') = v_lib and max(g.mes) filter (where g.nivel = 'total') = v_lib
                   then 'libro' else sum(g.mes) filter (where g.nivel = 'cuenta')::text || '≠' || v_lib end
         from v_gasto_por_categoria g where g.periodo = v_mes),
      (select case when sum(g.mes) filter (where g.nivel = 'proveedor') = v_lib and max(g.mes) filter (where g.nivel = 'total') = v_lib
                   then 'libro' else sum(g.mes) filter (where g.nivel = 'proveedor')::text || '≠' || v_lib end
         from v_gasto_por_proveedor g where g.periodo = v_mes),
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor = 'C4 PRUEBAS SUPPLY'),
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor = 'C4 PRUEBAS AYUDANTE'),
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g
        where g.periodo = v_mes and g.proveedor_clave = 'txt:c4pruebasferreteria'))
      into v_a;
    perform fn_proveedor_alta('C4 PRUEBAS FERRETERIA', null, array['c4 pruebas ferreteria']);
    select v_a || ' ' || format('con_alta=%s',
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor = 'C4 PRUEBAS FERRETERIA'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (21, 'gasto por categoría y por proveedor = el mayor', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 22. EL COSTO POR OBRA (el auxiliar) = EL MAYOR: cada fila de control
--     cuadra (la suma de todas las obras de cada cuenta es su mayor del
--     año), y lo que el escenario metió en cada obra es lo que enseña (lo
--     que cambió en la vista: ingresos, costo, margen = ingresos − costo y
--     otros, de la obra A y de la B).
do $$
declare
  v_obt  text;
  v_esp  text := 'control=t A=13000.00/2350.00/10650.00/0.00 B=2000.00/0.00/2000.00/0.00';
  v_mes  text := current_setting('mx4.mes', true);
  v_a    text := current_setting('mx4.obra', true);
  v_b    text := current_setting('mx4.obra2', true);
begin
  if nullif(current_setting('mx4.desde', true), '') is null or nullif(v_b, '') is null then
    insert into _pruebas values (22, 'costo por obra: el auxiliar = el mayor', v_esp, 'omitida: faltan el mes abierto o dos obras', null);
    return;
  end if;
  begin
    create temp table _c4_antes on commit drop as
      select o.proyecto_id, o.seccion, o.del_periodo from v_costo_por_obra o where o.periodo = v_mes and o.nivel = 'obra';
    perform pg_temp.c4_escenario();
    select format('control=%s A=%s B=%s',
      (select case when bool_and(o.cuadra) then 't' else 'f' end from v_costo_por_obra o where o.periodo = v_mes and o.nivel = 'control'),
      (select string_agg((o.del_periodo - coalesce(x.del_periodo, 0))::numeric(14,2)::text, '/' order by o.orden)
         from v_costo_por_obra o left join _c4_antes x on x.proyecto_id is not distinct from o.proyecto_id and x.seccion = o.seccion
        where o.periodo = v_mes and o.nivel = 'obra' and o.proyecto_id = v_a),
      (select string_agg((o.del_periodo - coalesce(x.del_periodo, 0))::numeric(14,2)::text, '/' order by o.orden)
         from v_costo_por_obra o left join _c4_antes x on x.proyecto_id is not distinct from o.proyecto_id and x.seccion = o.seccion
        where o.periodo = v_mes and o.nivel = 'obra' and o.proyecto_id = v_b))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (22, 'costo por obra: el auxiliar = el mayor', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 23. EL DINERO POR OBRA: lo que el escenario cambió en cada obra —
--     facturado, cobrado (el dinero que entró contra sus cuentas por
--     cobrar, menos el cheque devuelto; el anticipo cuenta al cobrarse, no
--     al aplicarse), por cobrar, retención, costo y margen.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_a    text := current_setting('mx4.obra', true);
  v_b    text := current_setting('mx4.obra2', true);
  v_ap   boolean;
begin
  if nullif(current_setting('mx4.desde', true), '') is null or nullif(v_b, '') is null then
    insert into _pruebas values (23, 'dinero por obra: facturado, cobrado, por cobrar, costo y margen', '-',
                                 'omitida: faltan el mes abierto o dos obras', null);
    return;
  end if;
  begin
    create temp table _c4_antes_d on commit drop as select * from v_obras_dinero o where o.periodo = v_mes;
    v_ap := (pg_temp.c4_escenario()->>'con_apertura')::boolean;
    v_esp := case when v_ap
                  then 'A=13000.00/5000.00/9200.00/1500.00/2350.00/10650.00 B=2000.00/1500.00/4500.00/0.00/0.00/2000.00'
                  else 'A=13000.00/4000.00/8000.00/1000.00/2350.00/10650.00 B=2000.00/1500.00/500.00/0.00/0.00/2000.00' end;
    select format('A=%s B=%s',
      (select concat_ws('/', o.facturado - coalesce(x.facturado, 0), o.cobrado - coalesce(x.cobrado, 0),
                        o.por_cobrar - coalesce(x.por_cobrar, 0), o.retencion - coalesce(x.retencion, 0),
                        o.costo - coalesce(x.costo, 0), o.margen - coalesce(x.margen, 0))
         from v_obras_dinero o left join _c4_antes_d x on x.proyecto_id = o.proyecto_id
        where o.periodo = v_mes and o.proyecto_id = v_a),
      (select concat_ws('/', o.facturado - coalesce(x.facturado, 0), o.cobrado - coalesce(x.cobrado, 0),
                        o.por_cobrar - coalesce(x.por_cobrar, 0), o.retencion - coalesce(x.retencion, 0),
                        o.costo - coalesce(x.costo, 0), o.margen - coalesce(x.margen, 0))
         from v_obras_dinero o left join _c4_antes_d x on x.proyecto_id = o.proyecto_id
        where o.periodo = v_mes and o.proyecto_id = v_b))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (23, 'dinero por obra: facturado, cobrado, por cobrar, costo y margen', coalesce(v_esp, '-'),
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 24. LOS INGRESOS (4xxx), EL MATERIAL (5100) Y LOS SUBCONTRATOS (5200)
--     DE LA PRIMERA QUINCENA DEL MES, en el libro y en los papeles de la
--     app, SQL contra SQL: las facturas contra sus líneas de ingreso, los
--     recibos contra su costo, los trabajos externos contra 5200; en total
--     y obra por obra. (La nota de crédito, del día 21, no es de la
--     quincena.)
do $$
declare
  v_obt text;
  v_esp text := 'ingresos=15500.00/15500.00 material=1150.00/1150.00 subcontratos=1200.00/1200.00 por_obra=iguales';
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
begin
  if v_d is null then
    insert into _pruebas values (24, '4xxx, 5100 y 5200 de la quincena: el libro = los papeles', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    create temp table _c4_lib on commit drop as
      select a.origen_tabla, l.proyecto_id, c.tipo, l.cuenta, l.monto
        from asiento_lineas l join asientos a on a.id = l.asiento_id join cuentas c on c.codigo = l.cuenta
       where a.fecha_contable between v_d and v_d + 14
         and a.origen_tabla in ('facturas', 'recibos', 'trabajos_externos') and a.origen_id::bigint between -4499999 and -4400000;
    create temp table _c4_pap on commit drop as
      select 'facturas'::text as t, f.proyecto_id, f.monto from facturas f
       where f.id between -4400099 and -4400002 and f.fecha between v_d and v_d + 14
      union all
      select 'recibos', r.proyecto_id, r.total from recibos r where r.id between -4410099 and -4410001 and r.fecha between v_d and v_d + 14
      union all
      select 'trabajos_externos', x.proyecto_id, x.costo from trabajos_externos x
       where x.id between -4420099 and -4420001 and x.fecha between v_d and v_d + 14;
    select format('ingresos=%s/%s material=%s/%s subcontratos=%s/%s por_obra=%s',
      (select -sum(monto) from _c4_lib where origen_tabla = 'facturas' and tipo = 'ingreso'),
      (select sum(monto) from _c4_pap where t = 'facturas'),
      (select sum(monto) from _c4_lib where origen_tabla = 'recibos' and cuenta = '5100'),
      (select sum(monto) from _c4_pap where t = 'recibos'),
      (select sum(monto) from _c4_lib where origen_tabla = 'trabajos_externos' and cuenta = '5200'),
      (select sum(monto) from _c4_pap where t = 'trabajos_externos'),
      case when exists (
             (select t, proyecto_id, sum(monto) from _c4_pap group by 1, 2
              except
              select origen_tabla, proyecto_id, sum(case when origen_tabla = 'facturas' then -monto else monto end)
                from _c4_lib
               where (origen_tabla = 'facturas' and tipo = 'ingreso') or (origen_tabla = 'recibos' and cuenta = '5100')
                  or (origen_tabla = 'trabajos_externos' and cuenta = '5200')
               group by 1, 2)) then 'distintas' else 'iguales' end)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (24, '4xxx, 5100 y 5200 de la quincena: el libro = los papeles', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- H · Cada cifra baja a su asiento y a su papel
-- =====================================================================

-- 25. TODA CIFRA DE TODA VISTA: en el mes, el siguiente, la apertura y el
--     año (con asientos de todos los tipos y una balanza de QuickBooks del
--     mes cargada para comparar), cada cifra de cada fila de cada vista
--     con cifras (también el resumen contra QuickBooks) tiene su llave en
--     «bajar» —cada columna numeric(14,2) con valor—, suma exactamente lo
--     que dice su «bajar», y cada línea a
--     la que baja llega a un asiento con su papel (el recibo con su foto,
--     la factura, el cobro, la balanza de apertura; el asiento a mano es su
--     propio papel); las de QuickBooks, a su documento. (Un período y un
--     grupo de vistas por vuelta —las que más tardan con el libro lleno,
--     cada una sola—, cada vuelta en su subtransacción con su escenario y
--     solo las copias que usan sus vistas, con índices por partida y por
--     obra: con 10.000 asientos ninguna vuelta tiene tomado el libro más de
--     unos 2,5 s. Antes, un período entero por vuelta: de 6 a 9 s, y se
--     cortaban subidas de la app; y hasta esta ronda, seis grupos por
--     período: hasta 5 s con 2026 cerrado.)
do $$
declare
  -- (Las que más tardan con el libro lleno, cada una en su vuelta.)
  v_grupos text[] := array['v_balanza,v_balance_general,v_resultados',
                           'v_balanza_obra',
                           'v_flujo_caja,v_saldos_dinero',
                           'v_flujo_real_por_mes',
                           'v_cxc_antiguedad',
                           'v_cxp_antiguedad',
                           'v_gasto_por_categoria,v_gasto_por_proveedor',
                           'v_costo_por_obra',
                           'v_obras_dinero',
                           'v_comparacion,v_comparacion_obra,v_comparacion_resumen'];
  v_ps     text[];
  v_g      text;
  v_v      text;
  v_p      text;
  v_r      text;
  v_malas  text := '';
  v_filas  jsonb := '{}';
  v_cifras bigint := 0;
  v_obt    text;
  v_esp    text := 'todas bajan (vistas con filas: 16)';
  v_con    int := 0;
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (25, 'toda cifra de toda vista baja a su asiento y a su papel', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  v_ps := array[current_setting('mx4.mes'), current_setting('mx4.sig'), current_setting('mx4.apertura'), current_setting('mx4.anio')];
  foreach v_p in array v_ps loop
    foreach v_g in array v_grupos loop
      begin
        perform pg_temp.c4_candados_recibos();
        lock table public.periodos in exclusive mode;
        perform pg_temp.c4_escenario_completo();
        -- Para la comparación: una balanza de QuickBooks del mes (la del
        -- libro, cuenta por cuenta, por su código, con la retención por obra)
        -- para que tenga filas.
        if v_g like 'v_comparacion%' then
          perform fn_apertura_mapeo_qb('QB ' || b.cuenta, b.cuenta)
             from v_balanza b where b.periodo = current_setting('mx4.mes') and b.nivel = 'cuenta';
          perform fn_comparacion_qb_cargar(current_setting('mx4.mes'), 'docs/c4-pruebas/qb-mes.csv',
                    (select jsonb_agg(jsonb_build_object('cuenta_qb', 'QB ' || b.cuenta, 'saldo', b.saldo_final::text,
                                                         'proyecto_id', b.proyecto_id) order by b.cuenta, b.proyecto_id)
                       from v_balanza_obra b where b.periodo = current_setting('mx4.mes') and b.nivel = 'cuenta'));
        end if;
        perform pg_temp.c4_bajar_preparar();   -- (las copias mueren con la subtransacción)
        foreach v_v in array string_to_array(v_g, ',') loop
          v_r := pg_temp.c4_revisar_bajar(v_v, v_p);
          if v_r not like 'filas=%' then
            v_malas := v_malas || v_r || ' ';
          else
            v_cifras := v_cifras + substring(v_r from 'cifras=([0-9]+)')::bigint;
            v_filas := jsonb_set(v_filas, array[v_v],
                                 to_jsonb(coalesce((v_filas->>v_v)::bigint, 0) + substring(v_r from 'filas=([0-9]+)')::bigint));
          end if;
        end loop;
        raise exception using errcode = 'MXT00';
      exception
        when sqlstate 'MXT00' then null;
        when others then v_malas := v_malas || v_p || ': ' || sqlstate || ' ' || left(sqlerrm, 200) || ' ';
      end;
    end loop;
  end loop;
  select count(*) into v_con from jsonb_each_text(v_filas) f where f.value::bigint > 0;
  v_obt := case when v_malas = '' then format('todas bajan (vistas con filas: %s)', v_con) else left(v_malas, 400) end;
  insert into _pruebas values (25, 'toda cifra de toda vista baja a su asiento y a su papel (' || v_cifras || ' cifras)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 26. DEL ASIENTO A SU PAPEL, en cada clase: el recibo (con la ruta de su
--     foto), la factura, el trabajo externo, el cobro, el anticipo
--     aplicado, la nota de crédito, la devolución, la balanza de apertura
--     y el asiento a mano (su propio papel); un reverso lleva el papel de
--     su original. Todos con papel_existe.
do $$
declare
  v_obt text;
  v_esp text := 'aplicaciones_cobro=t cobros=t cobros_devoluciones=t facturas=t mano=t notas_credito=t recibos=t:recibos/c4-pruebas/1.jpg '
                'reverso=t trabajos_externos=t';
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (26, 'del asiento a su papel, en cada clase', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select string_agg(x.k || '=' || x.v, ' ' order by x.k) into v_obt
      from (select y.k,
                   case when bool_and(y.papel_existe and y.papel is not null) then 't' else 'f' end
                   || case when y.k = 'recibos' then ':' || min(y.papel_ruta) else '' end as v
              from (select case when p.origen_tabla is null and p.reversa_a is not null then 'reverso'
                                when p.origen_tabla is null then 'mano' else p.origen_tabla end as k, p.*
                      from v_asiento_papel p
                     where p.periodo = current_setting('mx4.mes')
                       and (p.origen_tabla is null or p.origen_tabla <> 'recibos' or p.origen_id = '-4410001')) y
             group by y.k) x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (26, 'del asiento a su papel, en cada clase', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- I · La apertura desde la balanza de QuickBooks
-- =====================================================================

-- 27. UNA CUENTA DE QUICKBOOKS SIN MAPEO para la apertura en la primera,
--     con su nombre y cómo mapearla (MX004), sin postear nada; mapeadas
--     todas menos una, para en esa. (Con nombres que solo usa esta prueba:
--     corre igual con la apertura de verdad ya en el libro y los nombres de
--     Edgar ya mapeados.)
do $$
declare
  v_obt text;
  v_esp text := 'primera=MX004:«C4P Banco  Uno» luego=MX004:«C4P Renta» asientos=+0';
  v_a   text;
  v_b   text;
  v_n   bigint;
begin
  if nullif(current_setting('mx4.apertura', true), '') is null then
    insert into _pruebas values (27, 'una cuenta de QuickBooks sin mapeo: para en la primera y la nombra', v_esp, 'omitida: no hay apertura', null);
    return;
  end if;
  begin
    select count(*) into v_n from asientos;
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-sin-mapeo.csv',
      '[{"cuenta_qb": "C4P Banco  Uno ", "debe": "700.00"}, {"cuenta_qb": "C4P Capital", "haber": "1,000.00"},
        {"cuenta_qb": "C4P Renta", "debe": "300.00"}]'::jsonb);
    begin
      perform fn_apertura((select p.desde from periodos p where p.periodo = current_setting('mx4.apertura')), 'docs/c4-pruebas/qb-sin-mapeo.csv');
      v_a := 'entró';
    exception when others then v_a := sqlstate || ':' || coalesce(substring(sqlerrm from '«[^»]*»'), sqlerrm);
    end;
    perform fn_apertura_mapeo_qb('c4p banco uno', '1010');
    perform fn_apertura_mapeo_qb('C4P Capital', '3900');
    begin
      perform fn_apertura((select p.desde from periodos p where p.periodo = current_setting('mx4.apertura')), 'docs/c4-pruebas/qb-sin-mapeo.csv');
      v_b := 'entró';
    exception when others then v_b := sqlstate || ':' || coalesce(substring(sqlerrm from '«[^»]*»'), sqlerrm);
    end;
    v_obt := format('primera=%s luego=%s asientos=+%s', v_a, v_b, (select count(*) from asientos) - v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (27, 'una cuenta de QuickBooks sin mapeo: para en la primera y la nombra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 28. LAS OTRAS TRAMPAS, cada una con su error y su nombre: un
--     Customer:Job sin mapear (MX008), una cuenta por cobrar positiva sin
--     factura (MX008), la retención de una factura sin obra (MX006), una
--     balanza que trae «Net Income» además de las cuentas de resultados (no
--     cuadra: MX001, y lo dice), una cuenta de resultados con factura
--     (MX006).
do $$
declare
  v_obt text;
  v_esp text := 'trabajo=MX008:«Otro Cliente:Otra Obra» sin_factura=MX008 retencion_sin_obra=MX006 net_income=MX001:Net Income '
                'resultados_con_factura=MX006';
  v_f   date;
  v_x   text[] := '{}';
  r     record;
begin
  if nullif(current_setting('mx4.apertura', true), '') is null then
    insert into _pruebas values (28, 'las otras trampas de QuickBooks, cada una con su error', v_esp, 'omitida: no hay apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    select p.desde into v_f from periodos p where p.periodo = current_setting('mx4.apertura');
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_mapeo_qb('Retained Earnings', '3900');
    perform fn_apertura_mapeo_qb('Accounts Receivable', fn_puente_cuenta_de('cxc'));
    perform fn_apertura_mapeo_qb('Net Income', '3900');
    perform fn_apertura_mapeo_qb('Rent Expense', '6100');
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400008, null, 'C4-QB-8', '2026-09-10', 1000.00, 100.00), (-4400001, current_setting('mx4.obra'), 'C4-QB-1', '2026-08-15', 3000.00, 500.00);
    for r in select * from (values
      (1, 'docs/c4-pruebas/t-trabajo.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "700"}, {"cuenta_qb": "Retained Earnings", "haber": "1000"},
                                            {"cuenta_qb": "Accounts Receivable", "debe": "300", "factura_id": -4400001, "retencion": "0",
                                             "cliente_trabajo": "Otro Cliente:Otra Obra"}]'::jsonb),
      (2, 'docs/c4-pruebas/t-sin-factura.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "700"}, {"cuenta_qb": "Retained Earnings", "haber": "1000"},
                                                {"cuenta_qb": "Accounts Receivable", "debe": "300"}]'::jsonb),
      (3, 'docs/c4-pruebas/t-retencion.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "700"}, {"cuenta_qb": "Retained Earnings", "haber": "1000"},
                                              {"cuenta_qb": "Accounts Receivable", "debe": "300", "factura_id": -4400008, "retencion": "100"}]'::jsonb),
      (4, 'docs/c4-pruebas/t-net-income.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "1500"}, {"cuenta_qb": "Retained Earnings", "haber": "1000"},
                                               {"cuenta_qb": "Rent Expense", "debe": "500"}, {"cuenta_qb": "Net Income", "haber": "500"}]'::jsonb),
      (5, 'docs/c4-pruebas/t-resultados.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "700"}, {"cuenta_qb": "Retained Earnings", "haber": "1000"},
                                               {"cuenta_qb": "Rent Expense", "debe": "300", "factura_id": -4400001}]'::jsonb)
    ) as t(n, doc, filas) order by n loop
      perform fn_apertura_balanza_cargar(r.doc, r.filas);
      begin
        perform fn_apertura(v_f, r.doc);
        v_x := v_x || 'entró'::text;
      exception when others then
        v_x := v_x || (sqlstate || case r.n when 1 then ':' || coalesce(substring(sqlerrm from '«[^»]*»'), '')
                                         when 4 then case when sqlerrm like '%Net Income%' then ':Net Income' else '' end
                                         else '' end)::text;
      end;
    end loop;
    v_obt := format('trabajo=%s sin_factura=%s retencion_sin_obra=%s net_income=%s resultados_con_factura=%s',
                    v_x[1], v_x[2], v_x[3], v_x[4], v_x[5]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (28, 'las otras trampas de QuickBooks, cada una con su error', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 29. LA APERTURA CON TODAS LAS TRAMPAS AMARRA CUENTA POR CUENTA con
--     QuickBooks: v_comparacion de la apertura sin nada sin explicar; las
--     únicas diferencias son las de criterio que anotó fn_apertura (la
--     retención partida a 1120); los dos bancos de QuickBooks (Chase con
--     espacios de sobra y Undeposited Funds) en 1010; la tarjeta con saldo
--     negativo en su columna; la depreciación entre paréntesis; el grupo en
--     cero, saltado; y el resultado de enero a septiembre en 3900 con su
--     nota.
do $$
declare
  v_obt text;
  v_esp text := 'comparacion=ok diferencias=1110:-500.00:{criterio},1120:500.00:{criterio} 1010=26200.00 2100-2013=-150.00 '
                '1590=-6000.00 3900=-52150.00 resultado=utilidad 38050.00 cero=1';
  v_e   jsonb;
  v_id  uuid;
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (29, 'la apertura con sus trampas amarra cuenta por cuenta con QuickBooks', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    v_e := pg_temp.c4_escenario();
    v_id := (v_e->'apertura'->>'id')::uuid;
    select format('comparacion=%s diferencias=%s 1010=%s 2100-2013=%s 1590=%s 3900=%s resultado=%s cero=%s',
      (select case when bool_and(c.ok) then 'ok' else 'mal' end from v_comparacion c where c.periodo = current_setting('mx4.apertura')),
      (select string_agg(c.cuenta || ':' || c.diferencia || ':' || c.clases::text, ',' order by c.cuenta)
         from v_comparacion c where c.periodo = current_setting('mx4.apertura') and c.diferencia <> 0),
      (select sum(l.monto) from asiento_lineas l where l.asiento_id = v_id and l.cuenta = '1010'),
      (select sum(l.monto) from asiento_lineas l where l.asiento_id = v_id and l.cuenta = '2100-2013'),
      (select sum(l.monto) from asiento_lineas l where l.asiento_id = v_id and l.cuenta = '1590'),
      (select sum(l.monto) from asiento_lineas l where l.asiento_id = v_id and l.cuenta = '3900'),
      (select substring(l.memo from 'utilidad [0-9.]+') from asiento_lineas l
        where l.asiento_id = v_id and l.cuenta = '3900' and l.memo like 'Resultado de enero%'),
      v_e->'apertura'->>'ignoradas_en_cero')
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (29, 'la apertura con sus trampas amarra cuenta por cuenta con QuickBooks', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 30. LA RETENCIÓN A 1120 POR OBRA Y LAS CUENTAS POR COBRAR A 1110 POR
--     FACTURA, con la obra de su factura; el crédito del cliente sin
--     factura, con su obra. El cobro de octubre de una factura de la
--     apertura se aplica a su partida (queda 1,500 + la retención), y el
--     control de partidas de c3 sigue en verde.
do $$
declare
  v_obt text;
  v_esp text;
  v_e   jsonb;
  v_id  uuid;
begin
  v_esp := format('lineas=%s:facturas/-4400001:%s:2500.00 | %s:facturas/-4400006:%s:4000.00 | %s:-:%s:-300.00 | %s:facturas/-4400001:%s:500.00 '
                  'despues_del_cobro=1500.00/500.00 partidas=t',
                  fn_puente_cuenta_de('cxc'), current_setting('mx4.obra', true), fn_puente_cuenta_de('cxc'),
                  current_setting('mx4.obra2', true), fn_puente_cuenta_de('cxc'), current_setting('mx4.obra', true),
                  fn_puente_cuenta_de('retencion_cxc'), current_setting('mx4.obra', true));
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (30, 'retención a 1120 por obra y 1110 por factura; el cobro se aplica a su partida', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    v_e := pg_temp.c4_escenario();
    v_id := (v_e->'apertura'->>'id')::uuid;
    select format('lineas=%s despues_del_cobro=%s/%s partidas=%s',
      (select string_agg(l.cuenta || ':' || coalesce(l.partida_tabla || '/' || l.partida_id, '-') || ':' || coalesce(l.proyecto_id, '-')
                         || ':' || l.monto, ' | ' order by l.cuenta, l.partida_id nulls last)
         from asiento_lineas l where l.asiento_id = v_id and l.cuenta in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc'))),
      (select sum(l.monto) from asiento_lineas l
        where l.cuenta = fn_puente_cuenta_de('cxc') and l.partida_tabla = 'facturas' and l.partida_id = '-4400001'),
      (select sum(l.monto) from asiento_lineas l
        where l.cuenta = fn_puente_cuenta_de('retencion_cxc') and l.partida_tabla = 'facturas' and l.partida_id = '-4400001'),
      (select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v where v.control = 'partidas'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (30, 'retención a 1120 por obra y 1110 por factura; el cobro se aplica a su partida', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 31. LA APERTURA DOS VECES NO DUPLICA, Y OTRA BALANZA NO PISA: con la
--     misma balanza, sin_cambios (ni un asiento más); con otra (QuickBooks
--     corrigió el vehículo), MX007 diciendo qué cambia, sin tocar nada; con
--     el motivo, la sustituye (reverso de la vieja y la nueva con
--     sustituye_a, el mismo día), las anotaciones de criterio se rehacen y
--     la comparación sigue en cero.
do $$
declare
  v_obt text;
  v_esp text := 'misma=sin_cambios:+0 otra=MX007:1510 asientos=+0 vivo=v1 motivo=sustituida vivo=v2 reverso=t anotaciones=2 retiradas/2 vivas '
                'comparacion=ok';
  v_f   date;
  v_n   bigint;
  v_a   text;
  v_b   text;
  v_c   text;
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (31, 'la apertura dos veces no duplica; otra balanza no pisa (con motivo, la sustituye)', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select p.desde into v_f from periodos p where p.periodo = current_setting('mx4.apertura');
    select count(*) into v_n from asientos;
    v_a := (fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v1.csv'))->>'accion' || ':+' || ((select count(*) from asientos) - v_n);
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-apertura-v2.csv',
      (select jsonb_agg(case when b.cuenta_qb = 'Vehicles' then jsonb_build_object('cuenta_qb', b.cuenta_qb, 'debe', '31000.00')
                             when b.cuenta_qb = 'Retained Earnings' then jsonb_build_object('cuenta_qb', b.cuenta_qb, 'haber', '10100.00')
                             else jsonb_strip_nulls(jsonb_build_object('cuenta_qb', b.cuenta_qb, 'debe', b.debe::text, 'haber', b.haber::text,
                                    'factura_id', b.factura_id, 'retencion', b.retencion::text, 'cliente_trabajo', b.cliente_trabajo,
                                    'proveedor_qb', b.proveedor_qb)) end order by b.linea)
         from apertura_balanza_qb b where b.documento = 'docs/c4-pruebas/qb-apertura-v1.csv' and b.control is null));
    perform pg_temp.c4_control_qb('docs/c4-pruebas/qb-apertura-v2.csv');
    begin
      perform fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v2.csv');
      v_b := 'entró';
    exception when others then v_b := sqlstate || ':' || coalesce(substring(sqlerrm from '1510'), '-');
    end;
    v_b := v_b || ' asientos=+' || ((select count(*) from asientos) - v_n) || ' vivo='
           || (select case a.documento_ruta when 'docs/c4-pruebas/qb-apertura-v1.csv' then 'v1' else 'v2' end
                 from asientos a where a.origen_tabla = 'apertura_balanza_qb' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from asientos r where r.reversa_a = a.id) order by a.cadena_pos desc limit 1);
    v_c := (fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v2.csv', 'c4-pruebas: QuickBooks corrigió el vehículo'))->>'accion';
    select format('misma=%s otra=%s motivo=%s vivo=%s reverso=%s anotaciones=%s retiradas/%s vivas comparacion=%s', v_a, v_b, v_c,
      (select case a.documento_ruta when 'docs/c4-pruebas/qb-apertura-v1.csv' then 'v1' else 'v2' end
         from asientos a where a.origen_tabla = 'apertura_balanza_qb' and a.camino not in ('reverso', 'reverso_automatico')
          and not exists (select 1 from asientos r where r.reversa_a = a.id) order by a.cadena_pos desc limit 1),
      (select case when exists (select 1 from asientos r join asientos o on o.id = r.reversa_a
                                 where o.documento_ruta = 'docs/c4-pruebas/qb-apertura-v1.csv' and r.camino = 'reverso'
                                   and r.fecha_contable = v_f)
                        and exists (select 1 from asientos s where s.sustituye_a is not null
                                       and s.documento_ruta = 'docs/c4-pruebas/qb-apertura-v2.csv') then 't' else 'f' end),
      (select count(*) from diferencias d where d.origen = 'fn_apertura' and d.retirada_el is not null),
      (select count(*) from diferencias d where d.origen = 'fn_apertura' and d.retirada_el is null),
      (select case when bool_and(c.ok) then 'ok' else 'mal' end from v_comparacion c where c.periodo = current_setting('mx4.apertura')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (31, 'la apertura dos veces no duplica; otra balanza no pisa (con motivo, la sustituye)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 32. LA BALANZA QUE ENTRÓ AL LIBRO NO SE EDITA NI SE BORRA (es el papel
--     de su asiento): update, delete, truncate y volver a cargarla dan
--     MX003; una que no ha entrado se recarga libre.
do $$
declare
  v_obt text;
  v_esp text := 'update=MX003 delete=MX003 truncate=MX003 recargar_usada=MX003 recargar_libre=ok';
  v_x   text[] := '{}';
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (32, 'la balanza que entró al libro no se edita ni se borra', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    begin update apertura_balanza_qb set debe = 1 where documento = 'docs/c4-pruebas/qb-apertura-v1.csv' and linea = 1;
          v_x := v_x || 'entró'::text; exception when others then v_x := v_x || sqlstate::text; end;
    begin delete from apertura_balanza_qb where documento = 'docs/c4-pruebas/qb-apertura-v1.csv';
          v_x := v_x || 'entró'::text; exception when others then v_x := v_x || sqlstate::text; end;
    begin truncate apertura_balanza_qb;
          v_x := v_x || 'entró'::text; exception when others then v_x := v_x || sqlstate::text; end;
    begin perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-apertura-v1.csv', '[{"cuenta_qb": "x", "debe": "1"}]');
          v_x := v_x || 'entró'::text; exception when others then v_x := v_x || sqlstate::text; end;
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-libre.csv', '[{"cuenta_qb": "x", "debe": "1"}]');
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-libre.csv', '[{"cuenta_qb": "y", "debe": "2"}, {"cuenta_qb": "z", "haber": "2"}]');
    v_obt := format('update=%s delete=%s truncate=%s recargar_usada=%s recargar_libre=%s', v_x[1], v_x[2], v_x[3], v_x[4],
                    case when (select count(*) from apertura_balanza_qb where documento = 'docs/c4-pruebas/qb-libre.csv') = 2
                         then 'ok' else 'mal' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (32, 'la balanza que entró al libro no se edita ni se borra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 33. LA APERTURA Y LOS PUENTES: una factura que la app fechó el 1-oct y
--     su puente ya contabilizó, pero que QuickBooks tenía al 30-sep y la
--     balanza trae: al postear la apertura, su puente la reversa (queda la
--     de la apertura, en_apertura), no está dos veces, y la antigüedad la
--     enseña una vez.
do $$
declare
  v_obt text;
  v_esp text := 'antes=1/0 despues=2/1 puente=no_aplica/en_apertura partidas=t antiguedad=2000.00';
  v_a   text;
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (33, 'la apertura reversa el puente de un papel que ya trae', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400009, current_setting('mx4.obra'), 'C4-QB-9', current_setting('mx4.desde')::date, 2000.00, 0);
    select count(*) || '/' || count(*) filter (where a.camino = 'reverso') into v_a
      from asientos a where a.origen_tabla = 'facturas' and a.origen_id = '-4400009';
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-v9.csv', true,
      '[{"cuenta_qb": "Accounts Receivable", "debe": "2000", "factura_id": -4400009},
        {"cuenta_qb": "Retained Earnings", "haber": "2000"}]');
    perform fn_apertura((select p.desde from periodos p where p.periodo = current_setting('mx4.apertura')), 'docs/c4-pruebas/qb-apertura-v9.csv');
    select format('antes=%s despues=%s puente=%s partidas=%s antiguedad=%s', v_a,
      (select count(*) || '/' || count(*) filter (where a.camino = 'reverso') from asientos a
        where a.origen_tabla = 'facturas' and a.origen_id = '-4400009'),
      (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'facturas' and d.documento_id = '-4400009'),
      (select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v where v.control = 'partidas'),
      (select string_agg(x.total::text, ',') from v_cxc_antiguedad x
        where x.periodo = current_setting('mx4.mes') and x.partida_tabla = 'facturas' and x.partida_id = '-4400009'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (33, 'la apertura reversa el puente de un papel que ya trae', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 34. LA APERTURA VA FECHADA EL DÍA DE LA APERTURA (MX002), y no se postea
--     encima de una apertura a mano (MX007: la duplicaría). Reversada la de
--     mano, entra: un asiento de apertura a mano (camino 'mano', con su
--     papel: la balanza), no de puente. Y como c2 deja reversar la apertura
--     con fn_reversar mientras está abierta, reversada así, la misma
--     balanza la vuelve a poner (la sustituye).
do $$
declare
  v_obt text;
  v_esp text := 'otra_fecha=MX002 con_una_a_mano=MX007 sin_la_de_mano=posteada:mano:apertura_balanza_qb reversada=sustituida';
  v_f   date;
  v_x   text[] := '{}';
  v_r   jsonb;
begin
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (34, 'la apertura va fechada el día de la apertura y no se duplica con una a mano', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    select p.desde into v_f from periodos p where p.periodo = current_setting('mx4.apertura');
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-v1.csv');
    begin perform fn_apertura(v_f + 1, 'docs/c4-pruebas/qb-apertura-v1.csv'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', v_f::text, 'descripcion', 'c4-pruebas: apertura a mano',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1000.00'))));
    begin perform fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v1.csv'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    perform fn_reversar((select a.id from asientos a
                          where a.tipo = 'apertura' and a.origen_tabla is null and a.camino = 'mano'
                          order by a.cadena_pos desc limit 1), 'c4-pruebas: la apertura a mano sobraba');
    v_r := fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v1.csv');
    v_x := v_x || (select (v_r->>'accion') || ':' || a.camino || ':' || a.origen_tabla
                     from asientos a where a.id = (v_r->>'id')::uuid);
    perform fn_reversar((v_r->>'id')::uuid, 'c4-pruebas: se rehace la apertura');
    v_x := v_x || (fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-v1.csv')->>'accion');
    v_obt := format('otra_fecha=%s con_una_a_mano=%s sin_la_de_mano=%s reversada=%s', v_x[1], v_x[2], v_x[3], v_x[4]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (34, 'la apertura va fechada el día de la apertura y no se duplica con una a mano', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- J · La comparación de cada mes contra QuickBooks
-- =====================================================================

-- 35. EL MES CONTRA QUICKBOOKS: con la balanza de QuickBooks del mes
--     cargada (sus cuentas de resultados con enero a septiembre dentro,
--     como las trae QuickBooks, que el libro compara sumándoles el arrastre
--     de la apertura), solo dos cuentas no cuadran: una comisión del banco
--     que QuickBooks ya tiene y el libro todavía no (1010 +100 y 6130 −100).
--     La utilidad del libro contra la de QuickBooks, acumulada y del mes,
--     difiere en esos 100. Anotadas (clase puente), todo en ok; retirada
--     una, vuelve a rojo. Una cuenta de QuickBooks sin mapear sale sola, en
--     rojo. Lo cargado y lo anotado no se edita ni se borra (MX003).
do $$
declare
  v_obt  text;
  v_esp  text := 'antes=1010:100.00,6130:-100.00 utilidad_dif=100.00 mes_dif=100.00 anotadas=ok resumen=t retirada=6130 '
                 'sin_mapeo=QB Misterio:f inmutables=MX003,MX003,MX003,MX003';
  v_mes  text := current_setting('mx4.mes', true);
  v_a    text;
  v_b    text;
  v_d1   uuid;
  v_d2   uuid;
  v_x    text[] := '{}';
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (35, 'el mes contra QuickBooks: diferencias explicadas, utilidad, sin mapeo, nada se edita', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    -- La balanza de QuickBooks del mes: cada cuenta del plan con un nombre
    -- «QB …», con el saldo del libro; las de resultados, con enero a
    -- septiembre dentro (lo que la balanza de apertura traía en ellas); y
    -- la comisión del banco que el libro no tiene.
    perform fn_apertura_mapeo_qb('QB ' || x.cuenta, x.cuenta)
       from (select b.cuenta from v_balanza b where b.periodo = v_mes and b.nivel = 'cuenta'
             union
             select q.cuenta from v_qb_balanzas q where q.fuente = 'apertura_balanza_qb' and q.cuenta is not null
             union
             select '6130') x;
    perform fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-mes-v1.csv',
      (select jsonb_agg(jsonb_build_object('cuenta_qb', 'QB ' || x.cuenta, 'saldo', x.saldo::text) order by x.cuenta)
         from (select coalesce(b.cuenta, j.cuenta) as cuenta,
                      coalesce(b.saldo_final, 0) + coalesce(j.saldo, 0)
                      - case when coalesce(b.cuenta, j.cuenta) = '3900'
                             then (select sum(q.saldo) from v_qb_balanzas q
                                    where q.fuente = 'apertura_balanza_qb' and q.cuenta_tipo not in ('activo', 'pasivo', 'capital'))
                             else 0 end
                      + case coalesce(b.cuenta, j.cuenta) when '1010' then -100 when '6130' then 100 else 0 end as saldo
                 from (select * from v_balanza where periodo = v_mes and nivel = 'cuenta') b
                 full join (select q.cuenta, sum(q.saldo) as saldo from v_qb_balanzas q
                             where q.fuente = 'apertura_balanza_qb' and q.cuenta_tipo not in ('activo', 'pasivo', 'capital')
                             group by q.cuenta) j on j.cuenta = b.cuenta) x));
    select string_agg(c.cuenta || ':' || c.sin_explicar, ',' order by c.cuenta) into v_a
      from v_comparacion c where c.periodo = v_mes and not c.ok;
    select format('utilidad_dif=%s mes_dif=%s', r.utilidad_diferencia, r.utilidad_mes_libro - r.utilidad_mes_qb) into v_b
      from v_comparacion_resumen r where r.periodo = v_mes;
    v_d1 := fn_diferencia_anotar(v_mes, '1010', '100.00', 'puente', 'c4-pruebas: comisión del banco que QuickBooks ya tiene');
    v_d2 := fn_diferencia_anotar(v_mes, '6130', '-100.00', 'puente', 'c4-pruebas: la misma comisión, en el gasto');
    select format('antes=%s %s anotadas=%s resumen=%s', v_a, v_b,
                  case when bool_and(c.ok) then 'ok' else 'mal' end,
                  (select case when r.ok then 't' else 'f' end from v_comparacion_resumen r where r.periodo = v_mes))
      into v_a
      from v_comparacion c where c.periodo = v_mes;
    perform fn_diferencia_retirar(v_d2, 'c4-pruebas: ya entró la comisión');
    select v_a || ' retirada=' || coalesce(string_agg(c.cuenta, ','), '-') into v_a
      from v_comparacion c where c.periodo = v_mes and not c.ok;
    -- Otra versión de la balanza del mes, con un nombre sin mapear: vale la
    -- más reciente.
    perform fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-mes-v2.csv',
      (select jsonb_agg(jsonb_build_object('cuenta_qb', q.cuenta_qb, 'saldo', q.saldo::text) order by q.linea)
         from comparacion_qb q where q.documento = 'docs/c4-pruebas/qb-mes-v1.csv')
      || '[{"cuenta_qb": "QB Misterio", "saldo": "50.00"}, {"cuenta_qb": "QB 1010", "saldo": "-50.00"}]'::jsonb);
    select v_a || ' sin_mapeo=' || coalesce(string_agg(c.cuenta_qb || ':' || case when c.ok then 't' else 'f' end, ','), '-') into v_a
      from v_comparacion c where c.periodo = v_mes and c.nivel = 'sin_mapeo';
    begin update comparacion_qb set saldo = 0 where documento = 'docs/c4-pruebas/qb-mes-v1.csv'; v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin delete from comparacion_qb where documento = 'docs/c4-pruebas/qb-mes-v1.csv'; v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin update diferencias set monto = 1 where id = v_d1; v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    begin delete from diferencias where id = v_d1; v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text; end;
    v_obt := v_a || ' inmutables=' || array_to_string(v_x, ',');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (35, 'el mes contra QuickBooks: diferencias explicadas, utilidad, sin mapeo, nada se edita', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 36. LA COMPARACIÓN POR OBRA (Customer:Job): en la apertura, la cuenta por
--     cobrar de la obra A es en el libro la de QuickBooks menos su
--     retención; la diferencia viene explicada por obra (la anotó
--     fn_apertura), y la obra B cuadra sola. La retención, en 1120, no la
--     trae QuickBooks por obra (la tiene dentro de cobrar): no abre filas
--     por obra, y su explicación va por cuenta. fn_estados_control lo dice
--     en verde; retirada la explicación de la retención, la comparación por
--     obra sigue en verde y la de por cuenta se pone en rojo.
do $$
declare
  v_obt text;
  v_esp text;
begin
  v_esp := format('%s:%s:2200.00/2700.00:ok | %s:%s:4000.00/4000.00:ok control=ttt retirada=obra:ttt,cuenta:tft',
                  fn_puente_cuenta_de('cxc'), current_setting('mx4.obra', true), fn_puente_cuenta_de('cxc'),
                  current_setting('mx4.obra2', true));
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (36, 'la comparación por obra: la retención explicada obra por obra', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select string_agg(format('%s:%s:%s/%s:%s', c.cuenta, c.proyecto_id, c.libro, c.qb, case when c.ok then 'ok' else 'mal' end), ' | '
                      order by c.cuenta, c.proyecto_id)
      into v_obt
      from v_comparacion_obra c
     where c.periodo = current_setting('mx4.apertura')
       and c.proyecto_id in (current_setting('mx4.obra'), current_setting('mx4.obra2'));
    select v_obt || ' control=' || string_agg(case when c.ok then 't' else 'f' end, '' order by c.orden) into v_obt
      from fn_estados_control(current_setting('mx4.apertura'), array['v_comparacion_obra']) c
     where c.vista <> 'cuadre: protecciones de c4';
    perform fn_diferencia_retirar(d.id, 'c4-pruebas: se quita la explicación de la retención de la obra')
       from diferencias d
      where d.periodo = current_setting('mx4.apertura') and d.cuenta = fn_puente_cuenta_de('retencion_cxc')
        and d.proyecto_id = current_setting('mx4.obra') and d.retirada_el is null;
    select v_obt || ' retirada=obra:' || string_agg(case when c.ok then 't' else 'f' end, '' order by c.orden) into v_obt
      from fn_estados_control(current_setting('mx4.apertura'), array['v_comparacion_obra']) c
     where c.vista <> 'cuadre: protecciones de c4';
    select v_obt || ',cuenta:' || string_agg(case when c.ok then 't' else 'f' end, '' order by c.orden) into v_obt
      from fn_estados_control(current_setting('mx4.apertura'), array['v_comparacion']) c
     where c.vista <> 'cuadre: protecciones de c4';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (36, 'la comparación por obra: la retención explicada obra por obra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- K · fn_estados_control: la falla ruidosa
-- =====================================================================

-- 37. CON EL LIBRO LLENO, TODO EN VERDE: en el mes (todas las vistas), el
--     siguiente, la apertura y el año (las vistas con cuadre), cada vista
--     devuelve las filas que el libro dice (filas = esperadas, y más de 0
--     donde hay asientos) y todos los cuadres dan true, también el de las
--     protecciones de c4. (Si el período ya tiene su balanza de QuickBooks
--     cargada, sus dos cuadres contra QuickBooks no cuentan aquí: el
--     escenario le mete asientos que QuickBooks no tiene, y ahí el rojo es
--     el correcto.) Un período por vuelta, cada una en su subtransacción
--     con su escenario: con el libro lleno ninguna pasa de unos 2 s (antes,
--     las cuatro en una: casi 6 s con el libro tomado).
do $$
declare
  v_obt text;
  v_esp text := 'mal=0 vistas_con_filas=t cuadres=t';
  v_ps  text[];
  v_est text[] := array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja', 'v_cxc_antiguedad', 'v_cxp_antiguedad',
                        'v_costo_por_obra', 'v_obras_dinero'];
  v_n   int;
  v_acc jsonb := '[]';
  v_err text := '';
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (37, 'fn_estados_control: con el libro lleno, todo en verde', v_esp, 'omitida: falta el mes siguiente', null);
    return;
  end if;
  v_ps := array[current_setting('mx4.mes'), current_setting('mx4.sig'), current_setting('mx4.apertura'), current_setting('mx4.anio')];
  for v_n in 1 .. 4 loop
    begin
      perform pg_temp.c4_candados_recibos();
      lock table public.periodos in exclusive mode;
      perform pg_temp.c4_escenario_completo();
      select v_acc || coalesce(jsonb_agg(to_jsonb(c) || jsonb_build_object(
               'p', v_ps[v_n], 'n', v_n, 'con_qb', exists (select 1 from comparacion_qb q where q.periodo = v_ps[v_n]))), '[]')
        into v_acc
        from fn_estados_control(v_ps[v_n], case when v_n = 1 then null else v_est end) c;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_err := v_err || v_ps[v_n] || ': ' || sqlstate || ' ' || left(sqlerrm, 90) || ' ';
    end;
  end loop;
  with c as (select e->>'p' as p, (e->>'n')::int as n, e->>'vista' as vista, (e->>'filas')::bigint as filas, (e->>'ok')::boolean as ok,
                    e->>'detalle' as detalle, (e->>'con_qb')::boolean as con_qb
               from jsonb_array_elements(v_acc) e)
  select format('mal=%s vistas_con_filas=%s cuadres=%s',
    (select count(*) || coalesce(' ' || string_agg(c.p || ':' || c.vista || ':' || coalesce(c.detalle, ''), '; '), '')
       from c where not c.ok and not (c.con_qb and c.vista like 'cuadre: QuickBooks%')),
    (select case when count(*) filter (where c.filas > 0) >= 20 then 't' else 'f' end
       from c where c.n = 1 and c.filas is not null),
    (select case when count(*) = 15 and bool_and(c.ok or (c.con_qb and c.vista like 'cuadre: QuickBooks%')) then 't'
                 else 'f' || count(*) end
       from c where c.n = 1 and c.vista like 'cuadre:%'))
    into v_obt;
  if v_err <> '' then
    v_obt := v_err;
  end if;
  insert into _pruebas values (37, 'fn_estados_control: con el libro lleno, todo en verde', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 38. UNA VISTA ROTA O VACÍA NO PINTA CEROS: se cambia un instante (y se
--     deshace) v_saldos_dinero por una que no devuelve nada, y se quita
--     v_cxc_antiguedad: fn_estados_control (UNA vez, para tener tomadas
--     esas dos vistas lo menos posible) dice cuál, con ok = false (0 filas
--     donde el libro espera N;
--     el error de la que no está), y también el cuadre de las protecciones
--     (a una le falta la vista, la otra no es la de c4); lo demás sigue en
--     verde (salvo, si el mes ya tiene su balanza de QuickBooks, sus
--     cuadres contra QuickBooks, que el escenario mueve). El equipo no lo
--     puede llamar (42501).
do $$
declare
  v_obt text;
  v_esp text := 'vacia=v_saldos_dinero:0/N:f rota=v_cxc_antiguedad:42P01:f otras=t protecciones=f equipo=42501';
  v_a   text;
  v_b   text;
  v_c   text;
  v_d   text;
  v_e   text;
  v_qb  boolean;
begin
  if nullif(current_setting('mx4.desde', true), '') is null or nullif(current_setting('mx4.equipo', true), '') is null then
    insert into _pruebas values (38, 'una vista vacía o rota: fn_estados_control la dice y no se pinta', v_esp,
                                 'omitida: falta el mes abierto o alguien del equipo', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c4_escenario();
    v_qb := exists (select 1 from comparacion_qb q where q.periodo = current_setting('mx4.mes'));
    alter view public.v_saldos_dinero rename to v_saldos_dinero_c4p;
    create view public.v_saldos_dinero with (security_invoker = true) as select * from public.v_saldos_dinero_c4p where false;
    drop view public.v_cxc_antiguedad;
    create temp table _c4_38 on commit drop as select c.* from fn_estados_control(current_setting('mx4.mes')) c;
    select c.vista || ':' || c.filas || '/' || case when c.esperadas > 0 then 'N' else c.esperadas::text end || ':'
           || case when c.ok then 't' else 'f' end
      into v_a
      from _c4_38 c where c.vista = 'v_saldos_dinero';
    select c.vista || ':' || coalesce(substring(c.detalle from '42P01'), c.detalle) || ':' || case when c.ok then 't' else 'f' end
      into v_b
      from _c4_38 c where c.vista = 'v_cxc_antiguedad';
    select case when bool_and(c.ok) then 't' else 'f:' || string_agg(c.vista, ',') filter (where not c.ok) end into v_c
      from _c4_38 c
     where c.vista not in ('v_saldos_dinero', 'v_cxc_antiguedad', 'cuadre: protecciones de c4')
       and c.vista not like 'cuadre: antigüedad de cobrar%'
       and not (v_qb and c.vista like 'cuadre: QuickBooks%');
    select case when c.ok then 't' else 'f' end into v_d from _c4_38 c where c.vista = 'cuadre: protecciones de c4';
    perform pg_temp.c4_como('equipo');
    begin
      perform * from public.fn_estados_control(current_setting('mx4.mes'), array['v_saldos_dinero']);
      v_e := 'entró';
    exception when others then v_e := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('vacia=%s rota=%s otras=%s protecciones=%s equipo=%s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (38, 'una vista vacía o rota: fn_estados_control la dice y no se pinta', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- =====================================================================
-- L · Los hallazgos de la ronda del 25-sep (una prueba por cada uno: cada
--     una habría salido en rojo antes de su arreglo)
-- =====================================================================

-- 39. EL BALANCE NO NETEA SALDOS CONTRARIOS: un anticipo de un cliente
--     (dinero sin factura) va al pasivo, «anticipos y saldos a favor de
--     clientes», y no resta de cuentas por cobrar; un saldo a favor con un
--     proveedor va al activo; y una cuenta de efectivo en rojo va al pasivo
--     como sobregiro (el efectivo es la suma de las cuentas en positivo).
--     Lo que cambia la prueba en cada renglón, y el balance cuadra. Antes
--     salía todo neteado en su cuenta.
do $$
declare
  v_obt  text;
  v_esp  text := 'anticipos=+1500.00 a_favor=+250.00 sobregiro=+700.00 efectivo=positivos cuadra=0.00';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_b    text := current_setting('mx4.obra2', true);
  v_prov uuid;
  v_a1   numeric;
  v_a2   numeric;
  v_a3   numeric;
begin
  if v_d is null or nullif(v_b, '') is null then
    insert into _pruebas values (39, 'el balance no netea: anticipos al pasivo, saldos a favor al activo, sobregiro al pasivo', v_esp,
                                 'omitida: faltan el mes abierto o dos obras', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    select coalesce(sum(b.cifra) filter (where b.linea = 'anticipos_clientes'), 0),
           coalesce(sum(b.cifra) filter (where b.linea = 'saldos_a_favor'), 0),
           coalesce(sum(b.cifra) filter (where b.linea = 'sobregiro_bancario'), 0)
      into v_a1, v_a2, v_a3
      from v_balance_general b where b.periodo = v_mes and b.nivel = 'linea';
    -- Un anticipo de la obra B (sin factura): 1110 en negativo, en su partida.
    perform fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (v_d + 3)::text, 'monto', '1500.00', 'medio', 'ach',
              'proyecto_id', v_b, 'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_b, 'monto', '1500.00'))));
    -- Un proveedor al que se le pagó por adelantado.
    v_prov := fn_proveedor_alta('C4 PRUEBAS ANTICIPADO', 'Net 30');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: pago por adelantado al proveedor',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '250.00',
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-250.00'))));
    -- Una cuenta de efectivo de prueba que queda en rojo.
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('1098', 'c4-pruebas: banco en rojo', 'c4 test overdrawn bank', 'activo', 'debe', true, 'prohibida', 'prohibida');
    perform fn_estados_mapeo_derivar();
    perform fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: cheque sin fondos en la cuenta',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '700.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-700.00'))));
    select format('anticipos=%s a_favor=%s sobregiro=%s efectivo=%s cuadra=%s',
      (select to_char(coalesce(sum(b.cifra), 0) - v_a1, 'FMSG999999990.00') from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'anticipos_clientes'),
      (select to_char(coalesce(sum(b.cifra), 0) - v_a2, 'FMSG999999990.00') from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'saldos_a_favor'),
      (select to_char(coalesce(sum(b.cifra), 0) - v_a3, 'FMSG999999990.00') from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'sobregiro_bancario'),
      (select case when b.cifra = (select coalesce(sum(greatest(x.s, 0)), 0)
                                     from (select l.cuenta, sum(l.monto) as s
                                             from asiento_lineas l join asientos a on a.id = l.asiento_id
                                             join estados_mapeo m on m.cuenta = l.cuenta and m.efectivo
                                            where a.fecha_contable <= (select p.hasta from periodos p where p.periodo = v_mes)
                                            group by l.cuenta) x)
                   then 'positivos' else b.cifra::text end
         from v_balance_general b where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'efectivo'),
      (select b.cifra from v_balance_general b where b.periodo = v_mes and b.nivel = 'total' and b.linea = 'cuadra'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (39, 'el balance no netea: anticipos al pasivo, saldos a favor al activo, sobregiro al pasivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 40. LO QUE SE MUEVE SIN DINERO NO ES FLUJO (ASC 230): un generador
--     comprado con tarjeta y la tarjeta pagada después, un camión
--     financiado con préstamo, y una reclasificación del CPA de renta a
--     distribución (3200/6100). En el flujo del mes (lo que cambia la
--     prueba): inversión −3000 en los dos métodos (el pago de la tarjeta se
--     clasifica por lo que compró), operación 0 en los dos, financiamiento
--     0; y el bloque sin dinero lo revela (inversión −43000, financiamiento
--     +39500, su contrapartida +3000) sin sumarlo. Y cada sección cuadra
--     entre métodos. Antes, el indirecto sumaba el camión y la
--     reclasificación, y el directo dejaba el pago de la tarjeta en
--     operación.
do $$
declare
  v_obt  text;
  v_esp  text := 'inversion=-3000.00/-3000.00 operacion=0.00/0.00 financiamiento=0.00/0.00 '
                 'sin_dinero=-43000.00:39500.00:3000.00 tarjetas=0.00 cuadra=t';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
begin
  if v_d is null then
    insert into _pruebas values (40, 'lo que se mueve sin dinero no es flujo; cada sección igual en los dos métodos', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    -- (El banco con fondos antes de medir: si el pago de la tarjeta lo
    -- dejara en rojo, ese rojo es sobregiro, financiamiento, y aquí se
    -- mide otra cosa.)
    perform fn_postear(jsonb_build_object('fecha', (v_d + 1)::text, 'descripcion', 'c4-pruebas: el banco con fondos',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '100000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-100000.00'))));
    create temp table _c4_40 on commit drop as
      select f.metodo, f.nivel, f.linea, f.importe from v_flujo_caja f where f.periodo = v_mes and f.nivel in ('linea', 'seccion');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: generador con la tarjeta',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1520', 'monto', '3000.00'),
                                  jsonb_build_object('cuenta', '2100-9998', 'monto', '-3000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 20)::text, 'descripcion', 'c4-pruebas: pago de la tarjeta',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9998', 'monto', '3000.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-3000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 9)::text, 'descripcion', 'c4-pruebas: camión financiado',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1510', 'monto', '40000.00'),
                                  jsonb_build_object('cuenta', '2530', 'monto', '-40000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 6)::text, 'descripcion', 'c4-pruebas: parte de la renta era personal',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200', 'monto', '500.00'),
                                  jsonb_build_object('cuenta', '6100', 'monto', '-500.00'))));
    select format('inversion=%s operacion=%s financiamiento=%s sin_dinero=%s tarjetas=%s cuadra=%s',
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, '/' order by f.metodo)
         from v_flujo_caja f left join _c4_40 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.nivel = 'seccion' and f.linea = 'inversion'),
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, '/' order by f.metodo)
         from v_flujo_caja f left join _c4_40 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.nivel = 'seccion' and f.linea = 'operacion'),
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, '/' order by f.metodo)
         from v_flujo_caja f left join _c4_40 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.nivel = 'seccion' and f.linea = 'financiamiento'),
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, ':'
                         order by case f.linea when 'sd_inversion' then 1 when 'sd_financiamiento' then 2 else 3 end)
         from v_flujo_caja f left join _c4_40 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'linea'
          and f.linea in ('sd_inversion', 'sd_financiamiento', 'sd_contrapartida')),
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2)
         from v_flujo_caja f left join _c4_40 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'linea' and f.linea = 'tarjetas'),
      (select case when bool_and(f.cuadra) and count(*) = 10 then 't' else 'f' end
         from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (40, 'lo que se mueve sin dinero no es flujo; cada sección igual en los dos métodos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 41. LA VENTA DE UN ACTIVO: lo cobrado sale en inversión en los dos
--     métodos (+1500: el costo que sale, la depreciación que se da de baja
--     y la ganancia, juntos), operación no cambia, y el indirecto resta la
--     ganancia de la utilidad (−1000, «(ganancia) o pérdida en venta»).
--     Antes: operación −3500 en el directo y −2500 en el indirecto.
do $$
declare
  v_obt  text;
  v_esp  text := 'directo=inversion:1500.00,operacion:0.00 indirecto=inversion:1500.00,operacion:0.00,ganancia:-1000.00 cuadra=t';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
begin
  if v_d is null then
    insert into _pruebas values (41, 'la venta de un activo: lo cobrado en inversión, la ganancia fuera de operación', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    create temp table _c4_41 on commit drop as
      select f.metodo, f.nivel, f.linea, f.importe from v_flujo_caja f where f.periodo = v_mes and f.nivel in ('linea', 'seccion');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 12)::text, 'descripcion', 'c4-pruebas: venta de un compresor usado',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '1500.00'),
                                  jsonb_build_object('cuenta', '1590', 'monto', '3500.00'),
                                  jsonb_build_object('cuenta', '1520', 'monto', '-4000.00'),
                                  jsonb_build_object('cuenta', '4920', 'monto', '-1000.00'))));
    select format('directo=inversion:%s,operacion:%s indirecto=inversion:%s,operacion:%s,ganancia:%s cuadra=%s',
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2) from v_flujo_caja f
         left join _c4_41 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'seccion' and f.linea = 'inversion'),
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2) from v_flujo_caja f
         left join _c4_41 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'directo' and f.nivel = 'seccion' and f.linea = 'operacion'),
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2) from v_flujo_caja f
         left join _c4_41 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'indirecto' and f.nivel = 'seccion' and f.linea = 'inversion'),
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2) from v_flujo_caja f
         left join _c4_41 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'indirecto' and f.nivel = 'seccion' and f.linea = 'operacion'),
      (select (f.importe - coalesce(a.importe, 0))::numeric(14,2) from v_flujo_caja f
         left join _c4_41 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
        where f.periodo = v_mes and f.metodo = 'indirecto' and f.nivel = 'linea' and f.linea = 'ganancia_venta_activos'),
      (select case when bool_and(f.cuadra) then 't' else 'f' end from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (41, 'la venta de un activo: lo cobrado en inversión, la ganancia fuera de operación', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 42. MES CONTRA MES CON SU SIGNO: un ingreso que baja de 1000 a 800 da
--     variación −200 y −20.0 %; un gasto que sube de 100 a 150, +50.0 %
--     (cuentas de prueba, solas en su renglón). Y el primer mes del libro
--     no tiene «mes anterior» (nulo: lo de antes está en QuickBooks, no es
--     0.00). Antes el ingreso salía +20.0 %.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_sig  text := current_setting('mx4.sig', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_ld   date;
  v_pri  text;
begin
  if nullif(v_sig, '') is null then
    insert into _pruebas values (42, 'mes contra mes: la variación con el signo del estado; antes del libro, sin dato', '-',
                                 'omitida: falta el mes siguiente', null);
    return;
  end if;
  -- Si el mes de la prueba es el primero del libro (el de después de la
  -- apertura), su «mes anterior» es de antes del libro: sin dato.
  select coalesce((select pa.hasta + 1 from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                  (select min(pm.desde) from periodos pm where pm.tipo = 'mes')) into v_ld;
  select p.periodo into v_pri from periodos p where p.periodo = v_mes and p.desde = v_ld;
  v_esp := 'ingreso=800.00/1000.00/-200.00/-20.0 gasto=150.00/100.00/50.00/50.0'
           || case when v_pri is not null then ' antes_del_libro=nulo' else '' end;
  begin
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('4097', 'c4-pruebas: servicio', 'c4 test service', 'ingreso', 'haber', true, 'prohibida', 'prohibida'),
           ('6097', 'c4-pruebas: gasto', 'c4 test expense', 'gasto', 'debe', true, 'prohibida', 'prohibida');
    perform fn_estados_mapeo_derivar();
    perform fn_postear(jsonb_build_object('fecha', (v_d + 2)::text, 'descripcion', 'c4-pruebas: servicio y gasto del mes',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '900.00'),
                                  jsonb_build_object('cuenta', '6097', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '4097', 'monto', '-1000.00'))));
    perform fn_postear(jsonb_build_object('fecha', ((v_d + interval '1 month')::date + 2)::text,
      'descripcion', 'c4-pruebas: servicio y gasto del mes siguiente',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '650.00'),
                                  jsonb_build_object('cuenta', '6097', 'monto', '150.00'),
                                  jsonb_build_object('cuenta', '4097', 'monto', '-800.00'))));
    select format('ingreso=%s gasto=%s', 
      (select concat_ws('/', r.mes, r.mes_anterior, r.variacion, r.variacion_pct) from v_resultados r
        where r.periodo = v_sig and r.nivel = 'cuenta' and r.cuenta = '4097'),
      (select concat_ws('/', r.mes, r.mes_anterior, r.variacion, r.variacion_pct) from v_resultados r
        where r.periodo = v_sig and r.nivel = 'cuenta' and r.cuenta = '6097'))
      || case when v_pri is not null
              then ' antes_del_libro=' || (select case when bool_and(r.mes_anterior is null and r.variacion is null
                                                                  and r.variacion_pct is null) then 'nulo' else 'con_dato' end
                                             from v_resultados r where r.periodo = v_pri)
              else '' end
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (42, 'mes contra mes: la variación con el signo del estado; antes del libro, sin dato', coalesce(v_esp, '-'),
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 43. A QUIÉN SE GASTA, CON DOS PROVEEDORES EN UN ASIENTO: un devengo de
--     dos subcontratistas va a cada uno (el de su deuda del mismo monto),
--     y uno que no se puede repartir (dos deudas del mismo monto) sale
--     junto como «varios», sin adivinar; la suma por proveedor sigue siendo
--     el gasto del estado de resultados. Antes, todo al de uuid mayor.
do $$
declare
  v_obt  text;
  v_esp  text := 'electro=700.00:asiento zanja=900.00:asiento varios=+1000.00 total=libro';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a    text := current_setting('mx4.obra', true);
  v_b    text := current_setting('mx4.obra2', true);
  v_e    uuid;
  v_z    uuid;
  v_v0   numeric;
  v_lib  numeric;
begin
  if v_d is null or nullif(v_b, '') is null then
    insert into _pruebas values (43, 'dos proveedores en un asiento: cada uno lo suyo, o «varios»', v_esp,
                                 'omitida: faltan el mes abierto o dos obras', null);
    return;
  end if;
  begin
    select coalesce(sum(g.mes), 0) into v_v0 from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor_clave = 'varios';
    v_e := fn_proveedor_alta('C4 PRUEBAS ELECTRO SUB', 'Net 30');
    v_z := fn_proveedor_alta('C4 PRUEBAS ZANJA PRO', 'Net 15');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 26)::text, 'descripcion', 'c4-pruebas: devengo de dos subcontratistas',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '5200', 'monto', '700.00', 'proyecto_id', v_a),
        jsonb_build_object('cuenta', '5200', 'monto', '900.00', 'proyecto_id', v_b),
        jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-700.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_e::text),
        jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-900.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_z::text))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 26)::text, 'descripcion', 'c4-pruebas: dos subcontratistas, mismo monto',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', v_a),
        jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', v_a),
        jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-500.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_e::text),
        jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-500.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_z::text))));
    -- (El gasto del mes según el estado de resultados: costo, gastos y
    -- otros gastos.)
    select coalesce(sum(r.mes), 0) into v_lib
      from v_resultados r where r.periodo = v_mes and r.nivel = 'seccion' and r.seccion in ('costo', 'gastos', 'otros_gastos');
    select format('electro=%s zanja=%s varios=%s total=%s',
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor_id = v_e),
      (select g.mes || ':' || g.fuente from v_gasto_por_proveedor g where g.periodo = v_mes and g.proveedor_id = v_z),
      (select to_char(g.mes - v_v0, 'FMSG999999990.00') from v_gasto_por_proveedor g
        where g.periodo = v_mes and g.proveedor_clave = 'varios'),
      (select case when sum(g.mes) filter (where g.nivel = 'proveedor') = v_lib then 'libro' else 'distinto' end
         from v_gasto_por_proveedor g where g.periodo = v_mes))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (43, 'dos proveedores en un asiento: cada uno lo suyo, o «varios»', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 44. LO QUE DE VERDAD ENTRÓ Y SALIÓ DEL BANCO (la gráfica del Panel): una
--     nómina de 5000 con 800 retenidos son 4200 que salen (no 5000, ni 800
--     que entran), y un gasto y su reverso del mismo mes no entran ni salen
--     (se anulan). entradas − salidas sigue siendo el neto. Antes: entradas
--     +800, salidas +5000, y el par, 99 y 99.
do $$
declare
  v_obt  text;
  v_esp  text := 'entradas=+0.00 salidas=+4200.00 par=t,t identidad=t';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_e0   numeric;
  v_s0   numeric;
  v_rev  jsonb;
begin
  if v_d is null then
    insert into _pruebas values (44, 'el dinero de verdad: la nómina neta, el par error-reverso fuera', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    select coalesce(f.entradas, 0), coalesce(f.salidas, 0) into v_e0, v_s0 from v_flujo_real_por_mes f where f.periodo = v_mes;
    perform fn_postear(jsonb_build_object('fecha', (v_d + 15)::text, 'descripcion', 'c4-pruebas: nómina de la quincena',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5000', 'monto', '5000.00', 'proyecto_id', current_setting('mx4.obra')),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-4200.00'),
                                  jsonb_build_object('cuenta', '2220', 'monto', '-800.00'))));
    v_rev := fn_postear(jsonb_build_object('fecha', (v_d + 10)::text, 'descripcion', 'c4-pruebas: gasto equivocado (se reversa en el mes)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6300', 'monto', '99.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-99.00'))));
    perform fn_reversar((v_rev->>'id')::uuid, 'c4-pruebas: no era de la empresa');
    select format('entradas=%s salidas=%s par=%s identidad=%s',
      to_char(coalesce(f.entradas, 0) - coalesce(v_e0, 0), 'FMSG999999990.00'),
      to_char(coalesce(f.salidas, 0) - coalesce(v_s0, 0), 'FMSG999999990.00'),
      (select string_agg(case when m.par_en_el_mes then 't' else 'f' end, ',')
         from v_efectivo_movimientos m
        where m.asiento_id = (v_rev->>'id')::uuid or m.reversa_a = (v_rev->>'id')::uuid),
      case when f.entradas - f.salidas = f.neto then 't' else 'f' end)
      into v_obt
      from v_flujo_real_por_mes f where f.periodo = v_mes;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (44, 'el dinero de verdad: la nómina neta, el par error-reverso fuera', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 45. EL CORTE 'HOY' (el del Panel) TIENE SU CONTROL: con «hoy» a mitad
--     del mes (el reloj fingido) y un asiento de después de hoy en ese mes
--     (una cuenta de prueba), fn_estados_control('hoy') cuenta lo de hoy y
--     no lo del mes: las siete vistas por corte con filas = esperadas y más
--     de 0 (el balance, con menos filas que el del mes), sus ocho cuadres
--     en verde (activo = pasivo + capital, antigüedad de cobrar y de pagar
--     = mayor, mapeo completo, dinero por obra, protecciones, la apertura
--     en el libro y la caja chica que no queda en rojo); y una vista
--     por período pedida con 'hoy' sale sola en rojo.
--     Antes: 22023, «No existe el período hoy».
do $$
declare
  v_obt  text;
  v_esp  text := 'vistas=7:t balance=a_hoy cuadres=8:t por_periodo=v_resultados:0:f';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_hoy  date;
begin
  if v_d is null then
    insert into _pruebas values (45, 'el corte ''hoy'' del Panel tiene su control', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    perform pg_temp.c4_fingir_hoy(v_d + 14);
    v_hoy := fn_fecha_miami(now());
    if v_hoy <> v_d + 14 then
      v_obt := 'omitida: el reloj de verdad ya pasó el día 15 del mes de la prueba';
      raise exception using errcode = 'MXT00';
    end if;
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('1597', 'c4-pruebas: equipo de prueba', 'c4 test equipment', 'activo', 'debe', true, 'prohibida', 'prohibida');
    perform fn_estados_mapeo_derivar();
    perform fn_postear(jsonb_build_object('fecha', (v_d + 20)::text, 'descripcion', 'c4-pruebas: equipo, después de hoy',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1597', 'monto', '500.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-500.00'))));
    create temp table _c4_45 on commit drop as select c.* from fn_estados_control('hoy') c;
    select format('vistas=%s balance=%s cuadres=%s por_periodo=%s',
      (select count(*) || ':' || case when bool_and(c.ok and c.filas = c.esperadas and c.filas > 0) then 't' else 'f' end
         from _c4_45 c where c.orden > 0 and c.vista not like 'cuadre:%'),
      (select case when c.esperadas = (select count(*) from v_balance_general b where b.periodo = 'hoy')
                        and c.esperadas < (select count(*) from v_balance_general b where b.periodo = v_mes)
                   then 'a_hoy' else c.filas || '/' || c.esperadas end
         from _c4_45 c where c.vista = 'v_balance_general'),
      (select count(*) || ':' || case when bool_and(c.ok) then 't' else 'f:' || string_agg(c.vista, ',') filter (where not c.ok) end
         from _c4_45 c where c.vista like 'cuadre:%'),
      (select string_agg(c.vista || ':' || c.orden || ':' || case when c.ok then 't' else 'f' end, ',')
         from fn_estados_control('hoy', array['v_balance_general', 'v_resultados']) c where c.orden = 0))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (45, 'el corte ''hoy'' del Panel tiene su control', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 46. EL MARGEN DE CADA OBRA ES INGRESOS − COSTO: por obra, cuatro
--     renglones (ingresos, costo, margen y otros). Una venta de 1,000 y un
--     material de 400 de la obra dan margen 600; la chatarra vendida (4900
--     de la obra, 300) va a «otros», no al margen; y el margen de
--     v_costo_por_obra es el de v_obras_dinero. Antes, el margen sumaba el
--     4900 (900) y no coincidía con el del dinero por obra.
do $$
declare
  v_obt text;
  v_esp text := 'ingresos=+1000.00 costo=+400.00 margen=+600.00 otros=+300.00 obras_dinero=igual';
  v_mes text := current_setting('mx4.mes', true);
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a   text := current_setting('mx4.obra', true);
begin
  if v_d is null or nullif(v_a, '') is null then
    insert into _pruebas values (46, 'el margen de cada obra es ingresos − costo, y el del dinero por obra', v_esp,
                                 'omitida: faltan el mes abierto o una obra', null);
    return;
  end if;
  begin
    create temp table _c4_46 on commit drop as
      select c.seccion, c.del_periodo from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'obra' and c.proyecto_id = v_a;
    perform fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: venta de contado de la obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '4010', 'monto', '-1000.00', 'proyecto_id', v_a))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: material de la obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '400.00', 'proyecto_id', v_a),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-400.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: chatarra de la obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '300.00'),
                                  jsonb_build_object('cuenta', '4900', 'monto', '-300.00', 'proyecto_id', v_a))));
    select format('ingresos=%s costo=%s margen=%s otros=%s obras_dinero=%s',
      max(to_char(c.del_periodo - coalesce(a.del_periodo, 0), 'FMSG999999990.00')) filter (where c.seccion = 'ingresos'),
      max(to_char(c.del_periodo - coalesce(a.del_periodo, 0), 'FMSG999999990.00')) filter (where c.seccion = 'costo'),
      max(to_char(c.del_periodo - coalesce(a.del_periodo, 0), 'FMSG999999990.00')) filter (where c.seccion = 'margen'),
      max(to_char(c.del_periodo - coalesce(a.del_periodo, 0), 'FMSG999999990.00')) filter (where c.seccion = 'otros'),
      (select case when x.desde_inicio = o.margen then 'igual' else x.desde_inicio || '<>' || o.margen end
         from v_costo_por_obra x join v_obras_dinero o on o.periodo = x.periodo and o.proyecto_id = x.proyecto_id
        where x.periodo = v_mes and x.nivel = 'obra' and x.seccion = 'margen' and x.proyecto_id = v_a))
      into v_obt
      from v_costo_por_obra c
      left join _c4_46 a on a.seccion = c.seccion
     where c.periodo = v_mes and c.nivel = 'obra' and c.proyecto_id = v_a;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (46, 'el margen de cada obra es ingresos − costo, y el del dinero por obra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 47. EL DINERO DE CADA OBRA CUADRA: una factura de 2,500 cobrada con 2,450
--     y 50 de descuento da facturado +2,450 (neto del descuento), cobrado
--     +2,450 (el dinero que entró), otros 0 y por cobrar 0; y su columna
--     cuadra (por cobrar de la apertura + facturado − cobrado + otros = por
--     cobrar + retención) en verde en las dos obras. Una obra con papeles de
--     antes del libro sale parcial, con el día en que empieza el libro; y
--     con la apertura de prueba, cada obra con lo que traía por cobrar al
--     30-sep. Antes: cobrado +2,500 (el descuento como dinero), y ni parcial
--     ni la apertura.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a    text := current_setting('mx4.obra', true);
  v_b    text := current_setting('mx4.obra2', true);
  v_lib  date;
  v_ap   boolean := pg_temp.c4_apertura_libre();
begin
  select coalesce((select pa.hasta + 1 from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                  (select min(pm.desde) from periodos pm where pm.tipo = 'mes')) into v_lib;
  v_esp := format('facturado=+2450.00 cobrado=+2450.00 otros=+0.00 por_cobrar=+0.00 cuadra=t,t parcial=t:%s apertura=%s', v_lib,
                  case when v_ap then '2700.00/4000.00' else '-' end);
  if v_d is null or nullif(v_b, '') is null then
    insert into _pruebas values (47, 'el dinero por obra cuadra: el descuento no es dinero; parcial y la apertura', v_esp,
                                 'omitida: faltan el mes abierto o dos obras', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_inmediato();
    if v_ap then
      perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-47.csv');
      perform fn_apertura((select p.desde from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
                          'docs/c4-pruebas/qb-apertura-47.csv');
    end if;
    create temp table _c4_47 on commit drop as
      select o.proyecto_id, o.facturado, o.cobrado, o.otros, o.por_cobrar from v_obras_dinero o where o.periodo = v_mes;
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400047, v_a, 'C4-47', v_d + 1, 2500.00, 0);
    perform fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (v_d + 5)::text, 'monto', '2450.00', 'medio', 'cheque',
              'referencia', 'c4-47', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -4400047, 'monto', '2450.00',
                                                                                          'descuento', '50.00'))));
    -- La obra B: un recibo de antes del libro (en QuickBooks) y un material
    -- en el mes.
    insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo,
                         metodo_pago, ultimos4) overriding system value
    values (-4410047, v_b, 'recibos/c4-pruebas/47.jpg', 100.00, 'C4 Pruebas Supply Inc', 'leido',
            nullif(current_setting('mx4.dueno', true), '')::uuid, ((v_lib - 5) + time '12:00') at time zone 'America/New_York',
            v_lib - 5, 'material', 'C4-47', 'credito', '9998');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 6)::text, 'descripcion', 'c4-pruebas: material de la obra B',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '100.00', 'proyecto_id', v_b),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-100.00'))));
    select format('facturado=%s cobrado=%s otros=%s por_cobrar=%s cuadra=%s parcial=%s apertura=%s',
      to_char(o.facturado - coalesce(x.facturado, 0), 'FMSG999999990.00'),
      to_char(o.cobrado - coalesce(x.cobrado, 0), 'FMSG999999990.00'),
      to_char(o.otros - coalesce(x.otros, 0), 'FMSG999999990.00'),
      to_char(o.por_cobrar - coalesce(x.por_cobrar, 0), 'FMSG999999990.00'),
      (select string_agg(case when z.cuadra then 't' else 'f' end, ',' order by z.proyecto_id = v_b)
         from v_obras_dinero z where z.periodo = v_mes and z.proyecto_id in (v_a, v_b)),
      (select case when z.parcial then 't' else 'f' end || ':' || z.libro_desde
         from v_obras_dinero z where z.periodo = v_mes and z.proyecto_id = v_b),
      case when v_ap then (select string_agg(z.por_cobrar_apertura::text, '/' order by z.proyecto_id = v_b)
                             from v_obras_dinero z where z.periodo = v_mes and z.proyecto_id in (v_a, v_b))
           else '-' end)
      into v_obt
      from v_obras_dinero o
      left join _c4_47 x on x.proyecto_id = o.proyecto_id
     where o.periodo = v_mes and o.proyecto_id = v_a;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (47, 'el dinero por obra cuadra: el descuento no es dinero; parcial y la apertura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 48. LO QUE LA EMPRESA LE PRESTA AL ACCIONISTA ES INVERSIÓN (ASC
--     230-10-45-12a), en los dos métodos: 1130 va a «préstamos otorgados»,
--     y financiamiento no se mueve. Y una fila de 1130 que todavía dijera lo
--     de la versión anterior (financiamiento) pasa a inversión al volver a
--     sembrar, con su rastro. Antes: financiamiento, «accionista».
do $$
declare
  v_obt  text;
  v_esp  text := 'mapeo=prestamos_otorgados/prestamos_otorgados:inversion inversion=-2000.00/-2000.00 '
                 'financiamiento=0.00/0.00 resembrado=prestamos_otorgados:+1';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_h    bigint;
  v_r    text;
begin
  if v_d is null then
    insert into _pruebas values (48, 'el préstamo al accionista (1130) es inversión en los dos métodos', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    -- (El banco con fondos antes de medir, como en la 40: un banco en rojo
    -- sería sobregiro, financiamiento.)
    perform fn_postear(jsonb_build_object('fecha', (v_d + 1)::text, 'descripcion', 'c4-pruebas: el banco con fondos',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '100000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-100000.00'))));
    create temp table _c4_48 on commit drop as
      select f.metodo, f.linea, f.importe from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'seccion';
    perform fn_postear(jsonb_build_object('fecha', (v_d + 7)::text, 'descripcion', 'c4-pruebas: préstamo al accionista',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1130', 'monto', '2000.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-2000.00'))));
    -- La fila de 1130 como la dejaba la versión anterior, y otra vez la
    -- siembra.
    perform fn_estados_mapeo('1130', '{"flujo_directo": "dueno", "flujo_indirecto": "fin_accionista"}');
    select count(*) into v_h from estados_historial;
    perform fn_estados_sembrar();
    select m.flujo_directo || ':+' || ((select count(*) from estados_historial) - v_h) into v_r
      from estados_mapeo m where m.cuenta = '1130';
    select format('mapeo=%s inversion=%s financiamiento=%s resembrado=%s',
      (select m.flujo_directo || '/' || m.flujo_indirecto || ':' || m.flujo_directo_seccion
         from v_estados_mapeo m where m.cuenta = '1130'),
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, '/' order by f.metodo)
         from v_flujo_caja f left join _c4_48 a on a.metodo = f.metodo and a.linea = f.linea
        where f.periodo = v_mes and f.nivel = 'seccion' and f.linea = 'inversion'),
      (select string_agg((f.importe - coalesce(a.importe, 0))::numeric(14,2)::text, '/' order by f.metodo)
         from v_flujo_caja f left join _c4_48 a on a.metodo = f.metodo and a.linea = f.linea
        where f.periodo = v_mes and f.nivel = 'seccion' and f.linea = 'financiamiento'),
      v_r)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (48, 'el préstamo al accionista (1130) es inversión en los dos métodos', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 49. CUÁNDO VENCE LO QUE SE DEBE, SEGÚN LOS TÉRMINOS DEL PROVEEDOR (una
--     deuda del día 3 del mes): «Net 10th Prox» → el 10 del mes siguiente;
--     «Net 10 EOM» → fin de mes + 10 días; «Net 15th» → el 15 del mes
--     siguiente; «1% 10 Net 30» → 30 días; «EOM» → fin de mes; «Due on
--     receipt» → el mismo día; y unos términos que no se entienden, sin
--     vencimiento (no se inventa). Antes, «Net 10th Prox» y «Net 10 EOM»
--     daban la fecha + 10 días.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_f    date;
  v_sig1 date;
  v_l    jsonb := '[]'::jsonb;
  v_ids  uuid[] := '{}';
  v_p    uuid;
  r      record;
begin
  if v_d is null then
    insert into _pruebas values (49, 'el vencimiento según los términos del proveedor', '-', 'omitida: falta el mes abierto', null);
    return;
  end if;
  v_f := v_d + 2;
  v_sig1 := (date_trunc('month', v_f::timestamp) + interval '1 month')::date;
  v_esp := format('prox=%s eom10=%s net15th=%s net30=%s eom=%s recibo=%s raro=-',
                  v_sig1 + 9, v_sig1 - 1 + 10, v_sig1 + 14, v_f + 30, v_sig1 - 1, v_f);
  begin
    for r in select * from (values (1, 'C4 PRUEBAS PROX', 'Net 10th Prox'), (2, 'C4 PRUEBAS EOM10', 'Net 10 EOM'),
                                   (3, 'C4 PRUEBAS NET15TH', 'Net 15th'), (4, 'C4 PRUEBAS NET30', '1% 10 Net 30'),
                                   (5, 'C4 PRUEBAS EOM', 'EOM'), (6, 'C4 PRUEBAS RECIBO', 'Due on receipt'),
                                   (7, 'C4 PRUEBAS RARO', 'Consignación')) as t(n, nombre, terminos) order by t.n loop
      v_p := fn_proveedor_alta(r.nombre, r.terminos);
      v_ids := v_ids || v_p;
      v_l := v_l || jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-100.00',
                                                         'tercero_tipo', 'proveedor', 'tercero_id', v_p::text));
    end loop;
    perform fn_postear(jsonb_build_object('fecha', v_f::text, 'descripcion', 'c4-pruebas: facturas de siete proveedores',
      'lineas', v_l || jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '700.00'))));
    select format('prox=%s eom10=%s net15th=%s net30=%s eom=%s recibo=%s raro=%s',
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[1]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[2]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[3]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[4]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[5]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[6]),
      max(coalesce(x.vence::text, '-')) filter (where x.proveedor_id = v_ids[7]))
      into v_obt
      from v_cxp_antiguedad x
     where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = any (v_ids);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (49, 'el vencimiento según los términos del proveedor', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 50. LO QUE SE DEBÍA A CADA PROVEEDOR EN LA APERTURA ENVEJECE DESDE SU
--     FACTURA: la balanza trae, por proveedor, cada factura con su fecha
--     (del A/P Aging Detail, en ISO o como la exporta QuickBooks, MM/DD/
--     YYYY) y su vencimiento. Un pago de octubre salda primero la más vieja
--     (FIFO): queda la segunda, con su fecha, su vencimiento, su referencia
--     y su tramo. Lo de un proveedor sin fecha en la balanza no se envejece
--     desde el 30-sep: tramo 'apertura', en «sin fecha». Antes, todo desde
--     el 30-sep, y sin manera de darle su fecha.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_ap   date;
  v_ct   date;
  v_m    jsonb;
  v_sf   uuid;
begin
  select p.desde into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select p.hasta into v_ct from periodos p where p.periodo = v_mes;
  v_esp := format('supply=1300.00:%s:balanza:%s:B-2:%s sin_fecha=700.00:-:-:apertura:700.00', v_ap - 15, v_ap + 15,
                  case when v_ct - (v_ap - 15) <= 30 then '0-30' when v_ct - (v_ap - 15) <= 60 then '31-60'
                       when v_ct - (v_ap - 15) <= 90 then '61-90' else '90+' end);
  if not pg_temp.c4_apertura_libre() or v_d is null then
    insert into _pruebas values (50, 'la CxP de la apertura envejece desde su factura (FIFO), o sin fecha', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    v_m := pg_temp.c4_montar();
    v_sf := fn_proveedor_alta('C4 PRUEBAS SIN FECHA', 'Net 30', array['c4 pruebas sin fecha']);
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-apertura-50.csv', jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Chase Chk 4392', 'debe', '10000.00'),
      jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '1000.00', 'proveedor_qb', 'C4 Pruebas Supply Inc',
                         'fecha_documento', (v_ap - 60)::text, 'referencia', 'B-1'),
      jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '1500.00', 'proveedor_qb', 'C4 Pruebas Supply Inc',
                         'fecha', to_char(v_ap - 15, 'MM/DD/YYYY'), 'vence', to_char(v_ap + 15, 'MM/DD/YYYY'),
                         'referencia', 'B-2'),
      jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '700.00', 'proveedor_qb', 'C4 Pruebas Sin Fecha'),
      jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '6800.00')));
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_mapeo_qb('Accounts Payable', fn_puente_cuenta_de('cxp'));
    perform fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
    perform pg_temp.c4_control_qb('docs/c4-pruebas/qb-apertura-50.csv');
    perform fn_apertura(v_ap, 'docs/c4-pruebas/qb-apertura-50.csv');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: pago a cuenta al supply',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '1200.00',
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_m->>'proveedor'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-1200.00'))));
    select format('supply=%s sin_fecha=%s',
      (select concat_ws(':', x.por_pagar, coalesce(x.fecha::text, '-'), coalesce(x.fecha_origen, '-'), coalesce(x.vence::text, '-'),
                        coalesce(x.referencia, '-'), x.tramo)
         from v_cxp_antiguedad x where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = (v_m->>'proveedor')::uuid),
      (select concat_ws(':', x.por_pagar, coalesce(x.fecha::text, '-'), coalesce(x.fecha_origen, '-'), x.tramo, x.sin_fecha)
         from v_cxp_antiguedad x where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = v_sf))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (50, 'la CxP de la apertura envejece desde su factura (FIFO), o sin fecha', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 51. EL AÑO DE LA APERTURA, ENTERO Y CON SU NOMBRE: en el balance de un
--     mes de 2026, «Resultado del ejercicio» lleva lo de enero a septiembre
--     según la balanza de QuickBooks con que se posteó la apertura (sale de
--     utilidades retenidas: el capital no cambia y cuadra), cada pieza con
--     su etiqueta (lo del libro dice «desde el 1-oct»); y el acumulado de
--     resultados dice desde cuándo. Antes, el resultado de 2026 era solo
--     desde octubre, con la etiqueta del año completo.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_ap   periodos;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  v_esp := format('resultado_apertura=resultado_ejercicio:38050.00,utilidades_retenidas:-38050.00 '
                  'etiqueta=Resultado del 01-01-%s al %s según QuickBooks (la balanza de la apertura) '
                  'libro=Resultado del ejercicio %s desde el %s (el libro) acumulado_desde=%s cuadra=0.00',
                  v_ap.anio, to_char(v_ap.hasta, 'DD-MM-YYYY'), v_ap.anio, to_char(v_ap.hasta + 1, 'DD-MM-YYYY'), v_ap.hasta + 1);
  if not pg_temp.c4_apertura_libre() or v_d is null or extract(year from v_d)::int <> v_ap.anio then
    insert into _pruebas values (51, 'el resultado del año de la apertura, entero y con su etiqueta', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o el mes es de otro año)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-51.csv');
    perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-51.csv');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 2)::text, 'descripcion', 'c4-pruebas: un gasto del mes',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '10.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-10.00'))));
    select format('resultado_apertura=%s etiqueta=%s libro=%s acumulado_desde=%s cuadra=%s',
      (select string_agg(b.linea || ':' || b.cifra, ',' order by b.linea) from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'resultado_apertura'),
      (select b.etiqueta_es from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'resultado_apertura' and b.linea = 'resultado_ejercicio'),
      (select b.etiqueta_es from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'resultado'),
      (select string_agg(distinct r.acumulado_desde::text, ',') from v_resultados r where r.periodo = v_mes),
      (select b.cifra from v_balance_general b where b.periodo = v_mes and b.nivel = 'total' and b.linea = 'cuadra'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (51, 'el resultado del año de la apertura, entero y con su etiqueta', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 52. LA BALANZA FINAL DEL CPA (con sus ajustes posteriores): cargada con
--     p_con_posteriores, la comparación del mes le suma al libro el ajuste
--     del CPA posteado después que corrige ese mes, y todo cuadra; la
--     misma cifra cargada como preliminar (la más reciente vale) deja en
--     rojo justo esas dos cuentas. Antes, contra la final siempre salían
--     diferencias que el libro ya tenía. Con datos de verdad: los ajustes
--     del CPA posteriores que el libro ya tenía (un ajuste a diciembre
--     fechado en febrero) también están en la balanza final de QuickBooks,
--     y la prueba mide lo que añade su escenario (antes, con uno así, salía
--     en rojo).
do $$
declare
  v_obt  text;
  v_esp  text := 'final=t posteriores=2050:-75.00,6600:75.00 preliminar=2050,6600';
  v_mes  text := current_setting('mx4.mes', true);
  v_a    text;
  v_pre  jsonb;
  v_ext  jsonb;
begin
  if nullif(current_setting('mx4.sig', true), '') is null then
    insert into _pruebas values (52, 'la balanza final del CPA: la comparación con los ajustes posteriores', v_esp,
                                 'omitida: falta el mes siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    -- (Los ajustes del CPA posteriores que ya había: los que la final le
    -- suma al libro del mes, por cuenta. QuickBooks ya los tiene.)
    select coalesce(jsonb_object_agg(z.cuenta, z.monto), '{}'::jsonb) into v_pre
      from (select v.cuenta, sum(v.monto) as monto
              from v_libro v join periodos p on p.periodo = v_mes
             where v.tipo = 'ajuste_cpa' and v.fecha > p.hasta and v.efectivo_hasta <= p.hasta
               and (v.estado = 'balance' or v.ejercicio = p.anio)
             group by v.cuenta
            having sum(v.monto) <> 0) z;
    perform pg_temp.c4_escenario_completo();
    select coalesce(jsonb_object_agg(k, coalesce((v_pre->>k)::numeric, 0)
                                        + case k when '6600' then 75 when '2050' then -75 else 0 end), '{}'::jsonb)
      into v_ext
      from (select jsonb_object_keys(v_pre) as k union select '6600' union select '2050') x;
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-final-1.csv', v_ext, true);
    select format('final=%s posteriores=%s',
      case when bool_and(c.ok) then 't' else 'f:' || string_agg(c.cuenta, ',') filter (where not c.ok) end,
      string_agg(c.cuenta || ':' || (c.posteriores - coalesce((v_pre->>c.cuenta)::numeric, 0))::numeric(14,2), ','
                 order by c.cuenta) filter (where c.posteriores - coalesce((v_pre->>c.cuenta)::numeric, 0) <> 0))
      into v_a
      from v_comparacion c where c.periodo = v_mes;
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-final-2.csv', v_ext, false);
    -- (Con la preliminar, en rojo quedan esas dos y las de los ajustes que
    -- ya había: se cuentan las del escenario.)
    select v_a || ' preliminar=' || coalesce(string_agg(c.cuenta, ',' order by c.cuenta), '-') into v_obt
      from v_comparacion c
     where c.periodo = v_mes and not c.ok and (c.cuenta in ('2050', '6600') or not v_pre ? c.cuenta);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (52, 'la balanza final del CPA: la comparación con los ajustes posteriores', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 53. LA COMPARACIÓN POR OBRA LLEVA SU ARRASTRE: la apertura trae el
--     resultado de enero a septiembre por Customer:Job (ingresos de las dos
--     obras, material de una); la balanza de QuickBooks del mes lo sigue
--     teniendo en cada obra. Cada fila por obra le suma al libro lo de su
--     obra en la apertura, y cuadra. Antes, cada cuenta de resultados por
--     obra salía en rojo por lo de enero a septiembre.
do $$
declare
  v_obt  text;
  v_esp  text := '4010:A:-60000.00:ok | 4010:B:-30000.00:ok | 5100:A:5000.00:ok';
  v_mes  text := current_setting('mx4.mes', true);
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a    text := current_setting('mx4.obra', true);
  v_b    text := current_setting('mx4.obra2', true);
  v_ap   periodos;
  v_ct   date;
begin
  if not pg_temp.c4_apertura_libre() or v_d is null or nullif(v_b, '') is null then
    insert into _pruebas values (53, 'la comparación por obra lleva el arrastre de su obra', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o faltan el mes o dos obras)', null);
    return;
  end if;
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select p.hasta into v_ct from periodos p where p.periodo = v_mes;
  if extract(year from v_d)::int <> v_ap.anio then
    insert into _pruebas values (53, 'la comparación por obra lleva el arrastre de su obra', v_esp,
                                 'omitida: el mes es de otro año que la apertura', null);
    return;
  end if;
  begin
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-apertura-53.csv', jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Chase Chk 4392', 'debe', '95000.00'),
      jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '60000.00', 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A'),
      jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '30000.00', 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra B'),
      jsonb_build_object('cuenta_qb', 'Job Materials', 'debe', '5000.00', 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A'),
      jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '10000.00')));
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_mapeo_qb('Construction Income', '4010');
    perform fn_apertura_mapeo_qb('Job Materials', '5100');
    perform fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Cliente:Obra A', v_a);
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Cliente:Obra B', v_b);
    perform pg_temp.c4_control_qb('docs/c4-pruebas/qb-apertura-53.csv');
    perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-53.csv');
    perform fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: venta de contado de la obra A',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '4010', 'monto', '-1000.00', 'proyecto_id', v_a))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: material de la obra A',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '200.00', 'proyecto_id', v_a),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-200.00'))));
    -- La balanza del mes, por Customer:Job, como la da QuickBooks: lo del
    -- libro en el año más lo de enero a septiembre.
    perform fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-obras-53.csv',
      (select jsonb_agg(jsonb_build_object('cuenta_qb', x.qb, 'cliente_trabajo', x.cli,
                                           'saldo', (coalesce((select sum(l.monto) from asiento_lineas l join asientos s on s.id = l.asiento_id
                                                                where l.cuenta = x.cuenta and l.proyecto_id = x.obra
                                                                  and s.fecha_contable between make_date(v_ap.anio, 1, 1) and v_ct
                                                                  and s.tipo <> 'apertura'), 0) + x.antes)::text))
         from (values ('Construction Income', 'C4 Pruebas, Cliente:Obra A', '4010', v_a, -60000.00),
                      ('Construction Income', 'C4 Pruebas, Cliente:Obra B', '4010', v_b, -30000.00),
                      ('Job Materials', 'C4 Pruebas, Cliente:Obra A', '5100', v_a, 5000.00)) as x(qb, cli, cuenta, obra, antes)));
    select string_agg(format('%s:%s:%s:%s', c.cuenta, case c.proyecto_id when v_a then 'A' else 'B' end, c.arrastre_apertura,
                             case when c.ok then 'ok' else 'mal' end), ' | ' order by c.cuenta, c.proyecto_id = v_b)
      into v_obt
      from v_comparacion_obra c
     where c.periodo = v_mes and c.proyecto_id in (v_a, v_b) and c.cuenta in ('4010', '5100');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (53, 'la comparación por obra lleva el arrastre de su obra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 54. LA APERTURA DICE LO QUE DE VERDAD PASA con una cuenta por cobrar: un
--     saldo a favor con factura (negativo) pide quitar la factura y decir su
--     obra (no «la retención es mayor que su saldo», sin retención); una
--     positiva sin factura pide su número (factura_num).
do $$
declare
  v_obt text;
  v_esp text := 'a_favor=MX006:saldo a favor del cliente sin_factura=MX008:factura_num';
  v_x   text[] := '{}';
begin
  begin
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400001, current_setting('mx4.obra'), 'C4-QB-1', '2026-08-15', 3000.00, 500.00)
    on conflict (id) do nothing;
    perform fn_apertura_mapeo_qb('Accounts Receivable', fn_puente_cuenta_de('cxc'));
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Cliente:Obra A', current_setting('mx4.obra'));
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-54a.csv',
      '[{"cuenta_qb": "Accounts Receivable", "haber": "300.00", "factura_id": -4400001},
        {"cuenta_qb": "Chase Chk 4392", "debe": "300.00"}]');
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-54b.csv',
      '[{"cuenta_qb": "Accounts Receivable", "debe": "300.00", "cliente_trabajo": "C4 Pruebas, Cliente:Obra A"},
        {"cuenta_qb": "Chase Chk 4392", "haber": "300.00"}]');
    begin perform fn_apertura_plan('docs/c4-pruebas/qb-54a.csv'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || (sqlstate || ':' || coalesce(substring(sqlerrm from 'saldo a favor del cliente'), sqlerrm));
    end;
    begin perform fn_apertura_plan('docs/c4-pruebas/qb-54b.csv'); v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || (sqlstate || ':' || coalesce(substring(sqlerrm from 'factura_num'), sqlerrm));
    end;
    v_obt := format('a_favor=%s sin_factura=%s', v_x[1], v_x[2]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (54, 'la apertura: un saldo a favor con factura y una por cobrar sin factura, con su mensaje', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 55. LO ESPERADO SALE DE LAS TABLAS, NO DE LA VISTA: se cambian un
--     instante (y se deshacen) v_qb_balanzas, v_comparacion y
--     v_gasto_lineas por unas que no devuelven nada; con la balanza de
--     QuickBooks del mes cargada y gasto en el mes, fn_estados_control dice
--     las tres en rojo (0 filas donde el libro espera N). Antes las tres
--     salían en verde: su «esperadas» se contaba con la misma vista.
do $$
declare
  v_obt text;
  v_esp text := 'v_comparacion:0/N:f v_gasto_lineas:0/N:f v_qb_balanzas:0/N:f';
  v_mes text := current_setting('mx4.mes', true);
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (55, 'una vista vacía que el control contaba consigo misma: ahora sale en rojo', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c4_escenario();
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-mes-55.csv');
    alter view public.v_qb_balanzas rename to v_qb_balanzas_c4p;
    create view public.v_qb_balanzas with (security_invoker = true) as select * from public.v_qb_balanzas_c4p where false;
    alter view public.v_comparacion rename to v_comparacion_c4p;
    create view public.v_comparacion with (security_invoker = true) as select * from public.v_comparacion_c4p where false;
    alter view public.v_gasto_lineas rename to v_gasto_lineas_c4p;
    create view public.v_gasto_lineas with (security_invoker = true) as select * from public.v_gasto_lineas_c4p where false;
    select string_agg(c.vista || ':' || c.filas || '/' || case when c.esperadas > 0 then 'N' else c.esperadas::text end || ':'
                      || case when c.ok then 't' else 'f' end, ' ' order by c.vista)
      into v_obt
      from fn_estados_control(v_mes, array['v_qb_balanzas', 'v_comparacion', 'v_gasto_lineas']) c
     where c.vista in ('v_qb_balanzas', 'v_comparacion', 'v_gasto_lineas');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (55, 'una vista vacía que el control contaba consigo misma: ahora sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 56. LO QUE ENTRÓ AL LIBRO NO CRECE: una fila nueva en la balanza de la
--     apertura ya posteada, o en una balanza del mes ya cargada, da MX003
--     (la guarda mira también INSERT); otra versión del mes, con otro
--     documento, sí entra. Y si alguien cambia la balanza saltándose la
--     guarda (su trigger apagado), fn_apertura no dice «sin_cambios»: su
--     huella ya no es la del asiento (MX007), y el control lo dice. Antes:
--     la fila entraba callada y fn_apertura decía «sin_cambios».
do $$
declare
  v_obt text;
  v_esp text := 'fila_apertura=MX003 fila_mes=MX003 otra_version=ok huella=MX007 control=f';
  v_mes text := current_setting('mx4.mes', true);
  v_f   date;
  v_x   text[] := '{}';
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (56, 'la balanza que entró no crece; la huella delata un cambio por fuera', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c4_montar();
    select p.desde into v_f from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-56.csv');
    perform fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-56.csv');
    begin
      insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe) values ('docs/c4-pruebas/qb-apertura-56.csv', 99, 'Chase Chk 4392', 1);
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-mes-56.csv');
    begin
      insert into comparacion_qb (periodo, documento, linea, cuenta_qb, saldo, cargado_rol)
      values (v_mes, 'docs/c4-pruebas/qb-mes-56.csv', 999, 'QB 1010', 1, fn_rol_llamante());
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    begin
      perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-mes-56b.csv');
      v_x := v_x || 'ok'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    -- Por fuera de la guarda: su trigger apagado un instante.
    alter table public.apertura_balanza_qb disable trigger trg_apertura_balanza_guarda;
    -- (una nota: el plan no cambia, solo el papel)
    update apertura_balanza_qb set notas = 'c4-pruebas: tocada por fuera'
     where documento = 'docs/c4-pruebas/qb-apertura-56.csv' and linea = 1;
    alter table public.apertura_balanza_qb enable trigger trg_apertura_balanza_guarda;
    begin
      perform fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-56.csv');
      v_x := v_x || 'sin_cambios'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    select v_x || case when c.ok then 't' else 'f' end into v_x
      from fn_estados_control(v_mes, array['v_cortes']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := format('fila_apertura=%s fila_mes=%s otra_version=%s huella=%s control=%s', v_x[1], v_x[2], v_x[3], v_x[4], v_x[5]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (56, 'la balanza que entró no crece; la huella delata un cambio por fuera', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 57. LAS PROTECCIONES DE c4 SE VIGILAN: el cuadre «protecciones de c4»
--     está en verde, y se pone en rojo diciendo cuál si un trigger de
--     historial se apaga, si una tabla se queda sin RLS o si alguien le
--     pone a una tabla una policy abierta (cada cambio, un instante y
--     deshecho). Antes, con las tres cosas a la vez todo seguía en verde y
--     el equipo leía la balanza de QuickBooks.
do $$
declare
  v_obt text;
  v_esp text := 'antes=t trigger=f:trg_estados_mapeo_historial rls=f:diferencias policy=f:comparacion_qb';
  v_x   text[] := '{}';
  v_t   text;
  v_mes text := current_setting('mx4.mes', true);
  r     record;
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (57, 'las protecciones de c4 se vigilan: trigger, RLS y policy', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    select case when c.ok then 't' else 'f' end into v_t from fn_estados_control(v_mes, array['v_cortes']) c
     where c.vista = 'cuadre: protecciones de c4';
    v_x := v_x || v_t;
    for r in select * from (values
               (1, 'alter table public.estados_mapeo disable trigger trg_estados_mapeo_historial', 'trg_estados_mapeo_historial'),
               (2, 'alter table public.diferencias disable row level security', 'diferencias'),
               (3, 'create policy c4p_abierta on public.comparacion_qb for select to authenticated using (true)', 'comparacion_qb'))
               as t(n, ddl, que) order by t.n loop
      begin
        execute r.ddl;
        select v_x || ((case when c.ok then 't' else 'f' end) || ':' || coalesce(substring(c.detalle from r.que), '(no lo dice)'))
          into v_x
          from fn_estados_control(v_mes, array['v_cortes']) c where c.vista = 'cuadre: protecciones de c4';
        raise exception using errcode = 'MXT01';
      exception when sqlstate 'MXT01' then null;
      end;
    end loop;
    v_obt := format('antes=%s trigger=%s rls=%s policy=%s', v_x[1], v_x[2], v_x[3], v_x[4]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (57, 'las protecciones de c4 se vigilan: trigger, RLS y policy', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 58. LAS REGLAS Y LOS MAPEOS NO SE VACÍAN DE GOLPE: TRUNCATE de
--     estados_mapeo, estados_lineas (en cascada), estados_config y
--     apertura_mapeo_qb da MX003 (cada cambio va por su función, con
--     rastro). Antes se vaciaban sin una fila en el historial.
do $$
declare
  v_obt text;
  v_esp text := 'estados_mapeo=MX003 estados_lineas=MX003 estados_config=MX003 apertura_mapeo_qb=MX003';
  v_x   text[] := '{}';
  t     text;
begin
  begin
    set local lock_timeout = '2s';
    foreach t in array array['estados_mapeo', 'estados_lineas', 'estados_config', 'apertura_mapeo_qb'] loop
      begin
        execute format('truncate public.%I cascade', t);
        v_x := v_x || 'entró'::text;
      exception when lock_not_available then raise;
                when others then v_x := v_x || sqlstate::text;
      end;
    end loop;
    v_obt := format('estados_mapeo=%s estados_lineas=%s estados_config=%s apertura_mapeo_qb=%s', v_x[1], v_x[2], v_x[3], v_x[4]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (58, 'las reglas y los mapeos no se vacían con TRUNCATE', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 59. LO QUE fn_estados_control NO CONOCE LO DICE EN ROJO: un nombre mal
--     escrito, la lista vacía, un nulo y una vista de paso (v_balanza_base)
--     salen cada uno en una fila con ok = false (orden 0); lo que sí conoce
--     sigue en verde. Antes: 0 filas y nada en rojo, y la pantalla pintaba.
do $$
declare
  v_obt text;
  v_esp text := 'dedo=v_balanse_general:0:f vacia=(ninguna):0:f nula=(nula):0:f de_paso=v_balanza_base:0:f conocida=t';
  v_mes text := current_setting('mx4.mes', true);
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (59, 'fn_estados_control dice en rojo lo que no conoce', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    select format('dedo=%s vacia=%s nula=%s de_paso=%s conocida=%s',
      (select string_agg(c.vista || ':' || c.orden || ':' || case when c.ok then 't' else 'f' end, ',')
         from fn_estados_control(v_mes, array['v_balanse_general']) c where c.orden = 0),
      (select string_agg(c.vista || ':' || c.orden || ':' || case when c.ok then 't' else 'f' end, ',')
         from fn_estados_control(v_mes, '{}'::text[]) c where c.orden = 0),
      (select string_agg(c.vista || ':' || c.orden || ':' || case when c.ok then 't' else 'f' end, ',')
         from fn_estados_control(v_mes, array[null::text]) c where c.orden = 0),
      (select string_agg(c.vista || ':' || c.orden || ':' || case when c.ok then 't' else 'f' end, ',')
         from fn_estados_control(v_mes, array['v_balanza_base', 'v_cortes']) c where c.orden = 0),
      (select case when bool_and(c.ok) then 't' else 'f' end
         from fn_estados_control(v_mes, array['v_balanza_base', 'v_cortes']) c where c.vista = 'v_cortes'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (59, 'fn_estados_control dice en rojo lo que no conoce', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 60. LA CARGA DE LA BALANZA Y LA APERTURA NO SE CRUZAN: las dos toman el
--     mismo candado (pg_advisory_xact_lock 820260930), así una carga espera
--     a que la apertura termine (y entonces su guarda la para) en vez de
--     reemplazar la balanza mientras se postea. Aquí se ve el candado
--     tomado tras la carga, y el mismo en fn_apertura (la carrera entre dos
--     sesiones, en pruebas/conta/c4-concurrencia.sh). Antes, ninguna lo
--     tomaba.
do $$
declare
  v_obt text;
  v_esp text := 'carga=candado apertura=candado';
begin
  begin
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-60.csv', '[{"cuenta_qb": "Chase Chk 4392", "debe": "1.00"}]');
    select format('carga=%s apertura=%s',
      case when exists (select 1 from pg_locks l
                         where l.locktype = 'advisory' and l.pid = pg_backend_pid() and l.granted
                           and ((l.classid::bigint << 32) | l.objid::bigint) = 820260930)
           then 'candado' else 'sin candado' end,
      case when pg_get_functiondef('public.fn_apertura(date,text,text)'::regprocedure) ~ 'pg_advisory_xact_lock\(820260930\)'
           then 'candado' else 'sin candado' end)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (60, 'la carga de la balanza y la apertura toman el mismo candado', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 61. UNA APERTURA SUSTITUIDA A MANO NO SE HACE PASAR POR LA DE LA
--     BALANZA: desde la app, el dueño reversa la de fn_apertura y postea
--     otra a mano con sustituye_a (que hereda el origen y dice el mismo
--     documento). fn_apertura ya no dice «sin_cambios»: MX007, hay una a
--     mano; su papel dice que es a mano (no la balanza); la balanza sigue
--     en la comparación, marcada como de una apertura que ya no está viva
--     (vivo = false), y fn_estados_control lo dice en rojo («apertura en
--     el libro»: la viva es una a mano). Antes: «sin_cambios», el papel
--     era la balanza, y el control del pegado en verde.
do $$
declare
  v_obt text;
  v_esp text := 'fn_apertura=MX007:a mano papel=a_mano balanza_de_la_apertura=reversada control=f:a_mano';
  v_f   date;
  v_ap  text;
  v_id  uuid;
  v_s   jsonb;
  v_x   text;
begin
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.dueno', true), '') is null then
    insert into _pruebas values (61, 'una apertura sustituida a mano no se hace pasar por la de la balanza', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o no hay dueño)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    select p.desde, p.periodo into v_f, v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-61.csv');
    v_id := (fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-61.csv')->>'id')::uuid;
    perform pg_temp.c4_como('dueno');
    perform public.fn_reversar(v_id, 'c4-pruebas: la rehago a mano');
    v_s := public.fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', v_f::text, 'descripcion', 'c4-pruebas: apertura a mano',
             'origen_tabla', 'apertura_balanza_qb', 'origen_id', v_ap, 'sustituye_a', v_id,
             'documento_ruta', 'docs/c4-pruebas/qb-apertura-61.csv',
             'lineas', '[{"cuenta": "1010", "monto": "1.00"}, {"cuenta": "3900", "monto": "-1.00"}]'::jsonb));
    execute 'reset role';
    perform pg_temp.c4_como(null);
    begin
      v_x := fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-61.csv')->>'accion';
    exception when others then v_x := sqlstate || ':' || coalesce(substring(sqlerrm from 'a mano'), sqlerrm);
    end;
    select format('fn_apertura=%s papel=%s balanza_de_la_apertura=%s control=%s', v_x,
      (select case when p.papel like 'Asiento de apertura a mano%' then 'a_mano' else p.papel end
         from v_asiento_papel p where p.asiento_id = (v_s->>'id')::uuid),
      (select case when count(*) > 0 and bool_and(not q.vivo) then 'reversada' else count(*) || ':vivas=' || count(*) filter (where q.vivo) end
         from v_qb_balanzas q where q.fuente = 'apertura_balanza_qb'),
      (select case when c.ok then 't' else 'f' end || ':' || case when c.detalle like '%es una hecha a mano%' then 'a_mano' else c.detalle end
         from fn_estados_control(v_ap, array['v_balanza']) c where c.vista = 'cuadre: apertura en el libro'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  execute 'reset role';
  insert into _pruebas values (61, 'una apertura sustituida a mano no se hace pasar por la de la balanza', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 62. UN MAPEO CORREGIDO CON LA MISMA BALANZA SE APLICA: posteada la
--     apertura, el vehículo se mapea bien (a 1520, no a 1510). fn_apertura
--     con la misma balanza ya no dice «sin_cambios»: sin motivo, MX007
--     diciendo qué renglones cambian (sin tocar nada); con el motivo, la
--     sustituye y el libro queda con el mapeo de hoy. Antes, «sin_cambios»
--     también con motivo.
do $$
declare
  v_obt text;
  v_esp text := 'sin_motivo=MX007:1510,1520 con_motivo=sustituida 1510=0.00 1520=30000.00 comparacion=ok';
  v_f   date;
  v_x   text;
  v_r   jsonb;
begin
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (62, 'un mapeo corregido con la misma balanza se aplica (con motivo)', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    select p.desde into v_f from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-62.csv');
    perform fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-62.csv');
    perform fn_apertura_mapeo_qb('Vehicles', '1520', 'c4-pruebas: el vehículo era herramienta y equipo');
    begin
      v_x := fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-62.csv')->>'accion';
    exception when others then
      v_x := sqlstate || ':' || concat_ws(',', substring(sqlerrm from '1510'), substring(sqlerrm from '1520'));
    end;
    v_r := fn_apertura(v_f, 'docs/c4-pruebas/qb-apertura-62.csv', 'c4-pruebas: corrijo el mapeo del vehículo');
    select format('sin_motivo=%s con_motivo=%s 1510=%s 1520=%s comparacion=%s', v_x, v_r->>'accion',
      (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.asiento_id = (v_r->>'id')::uuid and l.cuenta = '1510'),
      (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.asiento_id = (v_r->>'id')::uuid and l.cuenta = '1520'),
      (select case when bool_and(c.ok) then 'ok' else 'mal' end from v_comparacion c
        where c.periodo = (select p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1)))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (62, 'un mapeo corregido con la misma balanza se aplica (con motivo)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 63. ANOTAR POR OBRA UNA DIFERENCIA DE UN MES SIN CUSTOMER:JOB NO LO DEJA
--     EN ROJO: la balanza del mes no trae obras; QuickBooks tiene 100 más de
--     una factura de la obra A, y se anota por cuenta (1010) y por obra
--     (4010, con aviso). La comparación por cuenta cuadra, y la de por obra
--     no abre filas de cuentas que QuickBooks no trae por obra: los dos
--     cuadres del control en verde. Antes, la fila por obra quedaba en rojo
--     para siempre (ni retirando la anotación).
do $$
declare
  v_obt text;
  v_esp text := 'comparacion=ok obra_filas=0 control=t,t';
  v_mes text := current_setting('mx4.mes', true);
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a   text := current_setting('mx4.obra', true);
begin
  if v_d is null or nullif(v_a, '') is null then
    insert into _pruebas values (63, 'una anotación por obra en un mes sin Customer:Job no lo deja en rojo', v_esp,
                                 'omitida: faltan el mes abierto o una obra', null);
    return;
  end if;
  begin
    perform fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: venta de contado de la obra A',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '5000.00'),
                                  jsonb_build_object('cuenta', '4010', 'monto', '-5000.00', 'proyecto_id', v_a))));
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-mes-63.csv', '{"1010": 100, "4010": -100}');
    perform fn_diferencia_anotar(v_mes, '1010', '-100.00', 'puente', 'c4-pruebas: factura de la obra A que la app aún no tiene');
    perform fn_diferencia_anotar(v_mes, '4010', '100.00', 'puente', 'c4-pruebas: factura de la obra A que la app aún no tiene', v_a);
    select format('comparacion=%s obra_filas=%s control=%s',
      (select case when bool_and(c.ok) then 'ok' else 'mal:' || string_agg(c.cuenta, ',') filter (where not c.ok) end
         from v_comparacion c where c.periodo = v_mes),
      (select count(*) from v_comparacion_obra c where c.periodo = v_mes),
      (select string_agg(case when c.ok then 't' else 'f' end, ',' order by c.orden)
         from fn_estados_control(v_mes, array['v_comparacion', 'v_comparacion_obra']) c where c.vista like 'cuadre: QuickBooks%'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (63, 'una anotación por obra en un mes sin Customer:Job no lo deja en rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 64. VOLVER A PEGAR c4 NO BORRA LO AJENO SIN AVISAR: una vista y una
--     función de otro sobre las de c4 salen en fn_estados_vistas_ajenas
--     (el pegado para con MX000 y la lista, en vez de llevárselas con
--     «drop … cascade»); sin ellas, nada.
do $$
declare
  v_obt text;
  v_esp text := 'antes=nada con_ajenas=la función fn_c4p_ajena(), la vista v_c4p_ajena';
  v_a   text;
begin
  begin
    set local lock_timeout = '2s';
    v_a := coalesce(public.fn_estados_vistas_ajenas(), 'nada');
    create view public.v_c4p_ajena with (security_invoker = true) as select b.periodo, b.cuenta from public.v_balanza b;
    create function public.fn_c4p_ajena() returns setof public.v_balanza language sql stable
      set search_path = public, pg_temp as $f$ select * from public.v_balanza $f$;
    v_obt := format('antes=%s con_ajenas=%s', v_a, coalesce(public.fn_estados_vistas_ajenas(), 'nada'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (64, 'volver a pegar c4 no borra vistas ni funciones ajenas sin avisar', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 65. LA FACTURA POR SU NÚMERO (factura_num, como la trae el A/R Aging de
--     QuickBooks): con su Customer:Job, la carga la encuentra (su id queda
--     en la fila); un número que está en dos obras, sin decir cuál, da
--     MX008 con las dos; uno que no está, MX008; factura_id y factura_num
--     de facturas distintas, 22023. Y un factura_id que en realidad es el
--     número de la factura lo dice. Antes: «no está en la app» (sí estaba)
--     y el consejo llevaba a otro error.
do $$
declare
  v_obt text;
  v_esp text := 'con_obra=-4400001 dos=MX008:2 facturas no_esta=MX008 distintas=22023 id_por_numero=MX008:factura_num';
  v_a   text := current_setting('mx4.obra', true);
  v_b   text := current_setting('mx4.obra2', true);
  v_x   text[] := '{}';
begin
  if nullif(v_b, '') is null then
    insert into _pruebas values (65, 'la factura por su número de QuickBooks (factura_num)', v_esp, 'omitida: faltan dos obras', null);
    return;
  end if;
  begin
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value values
      (-4400001, v_a, 'C4-QB-1', '2026-08-15', 3000.00, 500.00),
      (-4400065, v_b, 'C4-QB-1', '2026-08-20', 1000.00, 0),
      (-4400066, v_a, '4400999', '2026-08-25', 800.00, 0)
    on conflict (id) do nothing;
    perform fn_apertura_mapeo_qb('Accounts Receivable', fn_puente_cuenta_de('cxc'));
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Cliente:Obra A', v_a);
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-65a.csv',
      '[{"cuenta_qb": "Accounts Receivable", "debe": "3000.00", "factura_num": "#C4-QB-1",
         "cliente_trabajo": "C4 Pruebas, Cliente:Obra A"}]');
    v_x := v_x || (select b.factura_id::text from apertura_balanza_qb b where b.documento = 'docs/c4-pruebas/qb-65a.csv');
    begin
      perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-65b.csv', '[{"cuenta_qb": "Accounts Receivable", "debe": "1.00", "factura_num": "C4-QB-1"}]');
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || (sqlstate || ':' || coalesce(substring(sqlerrm from '2 facturas'), sqlerrm));
    end;
    begin
      perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-65c.csv', '[{"cuenta_qb": "Accounts Receivable", "debe": "1.00", "factura_num": "C4-QB-404"}]');
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    begin
      perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-65d.csv',
        '[{"cuenta_qb": "Accounts Receivable", "debe": "1.00", "factura_num": "C4-QB-1", "factura_id": -4400066,
           "cliente_trabajo": "C4 Pruebas, Cliente:Obra A"}]');
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || sqlstate::text;
    end;
    -- factura_id con el número de la factura (4400999), no su id.
    perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
    perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-65e.csv',
      '[{"cuenta_qb": "Accounts Receivable", "debe": "800.00", "factura_id": 4400999},
        {"cuenta_qb": "Chase Chk 4392", "haber": "800.00"}]');
    begin
      perform fn_apertura_plan('docs/c4-pruebas/qb-65e.csv');
      v_x := v_x || 'entró'::text;
    exception when others then v_x := v_x || (sqlstate || ':' || coalesce(substring(sqlerrm from 'factura_num'), sqlerrm));
    end;
    v_obt := format('con_obra=%s dos=%s no_esta=%s distintas=%s id_por_numero=%s', v_x[1], v_x[2], v_x[3], v_x[4], v_x[5]);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (65, 'la factura por su número de QuickBooks (factura_num)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 66. LA FILA TOTAL DEL EXPORT NO SE SUMA: en la balanza de la apertura y
--     en la del mes, la fila «TOTAL» se aparta (no es una cuenta): el
--     resumen dice lo de verdad y si el total del reporte coincide. Antes,
--     el total salía al doble.
do $$
declare
  v_obt text;
  v_esp text := 'apertura=filas:2,debe:100.00,haber:100.00,total:ignorada/coincide mal=f comparacion=2';
  v_mes text := current_setting('mx4.mes', true);
  v_r   jsonb;
  v_m   jsonb;
  v_q   jsonb;
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (66, 'la fila TOTAL del export de QuickBooks no se suma', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    v_r := fn_apertura_balanza_cargar('docs/c4-pruebas/qb-66a.csv',
      '[{"cuenta_qb": "Chase Chk 4392", "debe": "100.00"}, {"cuenta_qb": "Opening Balance Equity", "haber": "100.00"},
        {"cuenta_qb": "TOTAL", "debe": "100.00", "haber": "100.00"}]');
    v_m := fn_apertura_balanza_cargar('docs/c4-pruebas/qb-66b.csv',
      '[{"cuenta_qb": "Chase Chk 4392", "debe": "100.00"}, {"cuenta_qb": "Opening Balance Equity", "haber": "100.00"},
        {"cuenta_qb": "Total", "debe": "90.00", "haber": "90.00"}]');
    v_q := fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-mes-66.csv',
      '[{"cuenta_qb": "QB 1010", "saldo": "100.00"}, {"cuenta_qb": "QB 3900", "saldo": "-100.00"},
        {"cuenta_qb": "TOTAL", "debe": "100.00", "haber": "100.00"}]');
    v_obt := format('apertura=filas:%s,debe:%s,haber:%s,total:%s/%s mal=%s comparacion=%s',
                    v_r->>'filas', v_r->>'debe', v_r->>'haber',
                    case when (v_r->'fila_total'->>'ignorada')::boolean then 'ignorada' else 'cargada' end,
                    case when (v_r->'fila_total'->>'coincide')::boolean then 'coincide' else 'no_coincide' end,
                    case when (v_m->'fila_total'->>'coincide')::boolean then 't' else 'f' end,
                    (select count(*) from comparacion_qb q where q.documento = 'docs/c4-pruebas/qb-mes-66.csv'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (66, 'la fila TOTAL del export de QuickBooks no se suma', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 67. LA GRÁFICA DEL PANEL LEE EL LIBRO UNA VEZ, NO UNA POR MES: leída
--     como el dueño (con la RLS), v_flujo_real_por_mes no recorre las
--     líneas del libro (asiento_lineas) enteras una vez por cada mes (solo
--     las busca por llave, con índice). Antes, cada mes volvía a leer el
--     libro entero hasta su fecha (y la gráfica crecía con cada mes). El
--     tiempo de todas las vistas del Panel con el libro lleno lo mide
--     pruebas/conta/c4-volumen.sh, que falla si pasan de su tope.
do $$
declare
  v_obt   text;
  v_esp   text := 'flujo_real=una_pasada meses=2';
  v_plan  jsonb;
  v_malos text;
  v_n     bigint;
begin
  if nullif(current_setting('mx4.sig', true), '') is null or nullif(current_setting('mx4.dueno', true), '') is null then
    insert into _pruebas values (67, 'la gráfica del Panel lee el libro una vez, no una por mes', v_esp,
                                 'omitida: faltan el mes siguiente o el dueño', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select count(*) into v_n from v_flujo_real_por_mes f
     where f.periodo in (current_setting('mx4.mes'), current_setting('mx4.sig'));
    perform pg_temp.c4_como('dueno');
    execute 'explain (analyze, format json) select * from public.v_flujo_real_por_mes' into v_plan;
    execute 'reset role';
    select string_agg(distinct (n->>'Relation Name') || '×' || (n->>'Actual Loops'), ',') into v_malos
      from jsonb_path_query(v_plan, 'strict $.**') n
     where jsonb_typeof(n) = 'object' and n->>'Relation Name' = 'asiento_lineas'
       and n->>'Node Type' = 'Seq Scan' and (n->>'Actual Loops')::numeric > 1;
    v_obt := 'flujo_real=' || coalesce('recorre el libro más de una vez: ' || v_malos, 'una_pasada') || ' meses=' || v_n;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  execute 'reset role';
  insert into _pruebas values (67, 'la gráfica del Panel lee el libro una vez, no una por mes', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- F · Ronda 3 de c4: una prueba por hallazgo (cada una habría salido en
-- rojo antes de su arreglo)
-- =====================================================================

-- 68. EL MAYOR EMPIEZA CADA AÑO EN CERO EN LAS CUENTAS DE RESULTADOS (como
--     la balanza y el estado de resultados): con material en el mes y en
--     enero del año siguiente, el saldo corrido de 5100 en su última línea
--     de enero es el de la balanza de enero (lo del año); el del banco
--     (balance) sigue siendo toda su historia, también igual a la balanza.
--     Antes el mayor arrastraba el año anterior: 1,300 contra 300 (y es lo
--     que f08 le manda al CPA).
do $$
declare
  v_obt  text;
  v_esp  text := 'resultados=balanza:t del_anio=+300.37 banco=balanza:t';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_obra text := nullif(current_setting('mx4.obra', true), '');
  v_ene  periodos;
  v_b0   numeric;
  v_bco  text := fn_puente_cuenta_de('banco');
begin
  select * into v_ene from periodos p
   where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_d)::int + 1, 1, 1);
  if v_d is null or v_obra is null or v_ene.periodo is null then
    insert into _pruebas values (68, 'el mayor empieza cada año en cero en las cuentas de resultados', v_esp,
                                 'omitida: falta el mes abierto o el enero del año siguiente (abierto)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_fingir_hoy(v_ene.desde + 14);
    select coalesce(sum(b.saldo_final), 0) into v_b0
      from v_balanza b where b.periodo = v_ene.periodo and b.nivel = 'cuenta' and b.cuenta = '5100';
    perform fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: material del mes',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '1000.37', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-1000.37'))));
    perform fn_postear(jsonb_build_object('fecha', (v_ene.desde + 9)::text, 'descripcion', 'c4-pruebas: material de enero',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '300.37', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-300.37'))));
    select format('resultados=balanza:%s del_anio=%s banco=balanza:%s',
      coalesce((select case when m.saldo = b.saldo_final then 't' else 'f:' || m.saldo || '<>' || b.saldo_final end
                  from (select m.saldo from v_mayor m where m.periodo = v_ene.periodo and m.cuenta = '5100'
                         order by m.fecha desc, m.cadena_pos desc, m.orden desc limit 1) m,
                       v_balanza b
                 where b.periodo = v_ene.periodo and b.nivel = 'cuenta' and b.cuenta = '5100'), 'sin_fila'),
      (select to_char(b.saldo_final - v_b0, 'FMSG999999990.00')
         from v_balanza b where b.periodo = v_ene.periodo and b.nivel = 'cuenta' and b.cuenta = '5100'),
      coalesce((select case when m.saldo = b.saldo_final then 't' else 'f:' || m.saldo || '<>' || b.saldo_final end
                  from (select m.saldo from v_mayor m where m.periodo = v_ene.periodo and m.cuenta = v_bco
                         order by m.fecha desc, m.cadena_pos desc, m.orden desc limit 1) m,
                       v_balanza b
                 where b.periodo = v_ene.periodo and b.nivel = 'cuenta' and b.cuenta = v_bco), 'sin_fila'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (68, 'el mayor empieza cada año en cero en las cuentas de resultados', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 69. EN EL AÑO SIGUIENTE, MIENTRAS EL DE LA APERTURA NO SE CIERRA, su
--     resultado ENTERO (enero a septiembre según QuickBooks, más octubre a
--     diciembre del libro) sale en «resultado de ejercicios anteriores por
--     cerrar», y las utilidades retenidas son las del 31-dic: al 31-ene,
--     retenidas = las del 31-dic, y por cerrar = el resultado del
--     ejercicio al 31-dic. Antes, al 31-ene las retenidas saltaban con lo
--     de enero a septiembre y «por cerrar» era solo lo del libro. (Postea
--     una apertura de prueba: si la de verdad ya está, «omitida».)
do $$
declare
  v_obt  text;
  v_esp  text := 'retenidas=las_del_31dic por_cerrar=el_resultado_del_31dic resultado_ene=+5000.00 cuadra=t';
  v_obra text := nullif(current_setting('mx4.obra', true), '');
  v_ap   periodos;
  v_dic  periodos;
  v_ene  periodos;
  v_r0   numeric;
  v_bco  text := fn_puente_cuenta_de('banco');
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select * into v_dic from periodos p where p.tipo = 'mes' and p.hasta = make_date(v_ap.anio, 12, 31);
  select * into v_ene from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(v_ap.anio + 1, 1, 1);
  if not pg_temp.c4_apertura_libre() or v_obra is null or v_dic.periodo is null or v_ene.periodo is null then
    insert into _pruebas values (69, 'el año siguiente con el de la apertura sin cerrar: retenidas y por cerrar', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta diciembre o el enero siguiente',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-69.csv');
    perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-69.csv');
    perform pg_temp.c4_fingir_hoy(v_ene.desde + 14);
    -- Octubre: una venta y la renta (el libro gana 8,000).
    perform fn_postear(jsonb_build_object('fecha', (v_ap.hasta + 10)::text, 'descripcion', 'c4-pruebas: venta de octubre',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_bco, 'monto', '10000.00'),
                                  jsonb_build_object('cuenta', '4010', 'monto', '-10000.00', 'proyecto_id', v_obra))));
    perform fn_postear(jsonb_build_object('fecha', (v_ap.hasta + 20)::text, 'descripcion', 'c4-pruebas: renta de octubre',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '2000.00'),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-2000.00'))));
    select coalesce(sum(g.cifra), 0) into v_r0
      from v_balance_general g where g.periodo = v_ene.periodo and g.nivel = 'linea' and g.linea = 'resultado_ejercicio';
    -- Enero del año siguiente (el año de la apertura sigue abierto).
    perform fn_postear(jsonb_build_object('fecha', (v_ene.desde + 9)::text, 'descripcion', 'c4-pruebas: venta de enero',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_bco, 'monto', '5000.00'),
                                  jsonb_build_object('cuenta', '4010', 'monto', '-5000.00', 'proyecto_id', v_obra))));
    select format('retenidas=%s por_cerrar=%s resultado_ene=%s cuadra=%s',
      (select case when e.cifra = d.cifra then 'las_del_31dic' else e.cifra || '<>' || d.cifra end
         from v_balance_general e, v_balance_general d
        where e.periodo = v_ene.periodo and e.nivel = 'linea' and e.linea = 'utilidades_retenidas'
          and d.periodo = v_dic.periodo and d.nivel = 'linea' and d.linea = 'utilidades_retenidas'),
      (select case when e.cifra = d.cifra then 'el_resultado_del_31dic' else coalesce(e.cifra::text, '-') || '<>' || d.cifra end
         from v_balance_general d
         left join v_balance_general e on e.periodo = v_ene.periodo and e.nivel = 'linea' and e.linea = 'ejercicios_por_cerrar'
        where d.periodo = v_dic.periodo and d.nivel = 'linea' and d.linea = 'resultado_ejercicio'),
      (select to_char(coalesce(sum(g.cifra), 0) - v_r0, 'FMSG999999990.00')
         from v_balance_general g where g.periodo = v_ene.periodo and g.nivel = 'linea' and g.linea = 'resultado_ejercicio'),
      (select bool_and(g.cuadra) from v_balance_general g where g.periodo = v_ene.periodo and g.nivel = 'total' and g.linea = 'cuadra'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (69, 'el año siguiente con el de la apertura sin cerrar: retenidas y por cerrar', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 70. UN BANCO EN ROJO: el efectivo del flujo es el del balance. Con una
--     cuenta de efectivo de prueba que termina el mes 700 en rojo (20,000
--     pasaron a la reserva de impuestos y la renta la dejó abajo): el
--     efectivo al final del flujo (los dos métodos) y el del Panel son el
--     renglón «efectivo» del balance; los 700 son sobregiro en el balance
--     y, en el flujo, financiamiento que entra (renglón «Sobregiro
--     bancario»); y el cuadre «efectivo del flujo = efectivo del balance»
--     en verde. Antes el flujo decía 19,300, el balance 20,000, y ningún
--     cuadre lo veía.
do $$
declare
  v_obt  text;
  v_esp  text := 'final=balance:t,t panel=balance:t sobregiro_flujo=+700.00/+700.00 sobregiro_balance=+700.00 cuadre=t';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_sb0  numeric;
begin
  if v_d is null then
    insert into _pruebas values (70, 'un banco en rojo: el efectivo del flujo es el del balance', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('1010-9998', 'c4-pruebas: banco de prueba', 'c4 test bank', 'activo', 'debe', true, 'prohibida', 'prohibida')
    on conflict (codigo) do nothing;
    perform fn_estados_mapeo_derivar();
    create temp table _c4_70 on commit drop as
      select f.metodo, f.importe from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'linea' and f.linea = 'sobregiro';
    select coalesce(sum(g.cifra), 0) into v_sb0
      from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'sobregiro_bancario';
    perform fn_postear(jsonb_build_object('fecha', v_d::text, 'descripcion', 'c4-pruebas: aportación al banco de prueba',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010-9998', 'monto', '25000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-25000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: a la reserva de impuestos',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1030', 'monto', '20000.00'),
                                  jsonb_build_object('cuenta', '1010-9998', 'monto', '-20000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 19)::text, 'descripcion', 'c4-pruebas: renta desde el banco de prueba',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '5700.00'),
                                  jsonb_build_object('cuenta', '1010-9998', 'monto', '-5700.00'))));
    select format('final=balance:%s panel=balance:%s sobregiro_flujo=%s sobregiro_balance=%s cuadre=%s',
      (select string_agg(case when f.importe = g.cifra then 't' else 'f:' || f.importe || '<>' || g.cifra end, ',' order by f.metodo)
         from v_flujo_caja f, v_balance_general g
        where f.periodo = v_mes and f.nivel = 'total' and f.linea = 'efectivo_final'
          and g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'efectivo'),
      (select case when r.efectivo_final = g.cifra then 't' else 'f:' || r.efectivo_final || '<>' || g.cifra end
         from v_flujo_real_por_mes r, v_balance_general g
        where r.periodo = v_mes and g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'efectivo'),
      (select string_agg(to_char(f.importe - coalesce((select a.importe from _c4_70 a where a.metodo = f.metodo), 0),
                                 'FMSG999999990.00'), '/' order by f.metodo)
         from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'linea' and f.linea = 'sobregiro'),
      (select to_char(coalesce(sum(g.cifra), 0) - v_sb0, 'FMSG999999990.00')
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'sobregiro_bancario'),
      (select c.ok from fn_estados_control(v_mes, array['v_balance_general', 'v_flujo_caja', 'v_flujo_real_por_mes']) c
        where c.vista = 'cuadre: efectivo del flujo = efectivo del balance'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (70, 'un banco en rojo: el efectivo del flujo es el del balance', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 71. EL COSTO POR OBRA SE CONCILIA CONTRA EL MAYOR, con lo que no está
--     repartido a la vista: material a una obra (1,000), burden APLICADO a
--     la obra (5010 contra 5011, 600) y el burden REAL del mes sin obra
--     (5015, 900). El control por cuenta trae 5011 y 5015 (sin repartir
--     −600 y +900, contra su mayor); el de la sección costo: repartido
--     +1,600 + sin repartir +300 = mayor +1,900; la obra, +1,600 de costo;
--     y el cuadre en verde. Antes el control sumaba las mismas líneas
--     contra sí mismas (no podía salir en rojo) y dejaba fuera 5011, 5015
--     y 5019.
do $$
declare
  v_obt  text;
  v_esp  text := 'c5011=-600.00:-600.00:t c5015=+900.00:+900.00:t costo=+1600.00+300.00=+1900.00:t obra=+1600.00 cuadre=t';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_obra text := nullif(current_setting('mx4.obra', true), '');
  v_bco  text := fn_puente_cuenta_de('banco');
begin
  if v_d is null or v_obra is null then
    insert into _pruebas values (71, 'el costo por obra se concilia contra el mayor, con lo sin repartir a la vista', v_esp,
                                 'omitida: falta el mes abierto o una obra', null);
    return;
  end if;
  begin
    create temp table _c4_71 on commit drop as
      select c.nivel, c.cuenta, c.seccion, c.proyecto_id, c.etiqueta_en, c.del_periodo, c.del_anio, c.sin_repartir, c.mayor
        from v_costo_por_obra c
       where c.periodo = v_mes and (c.nivel = 'control' or (c.nivel = 'obra' and c.proyecto_id = v_obra));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 9)::text, 'descripcion', 'c4-pruebas: material a la obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '1000.00', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-1000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 20)::text, 'descripcion', 'c4-pruebas: burden aplicado',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5010', 'monto', '600.00', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', '5011', 'monto', '-600.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 20)::text, 'descripcion', 'c4-pruebas: burden real (impuestos patronales)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '900.00'),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-900.00'))));
    select format('c5011=%s c5015=%s costo=%s obra=%s cuadre=%s',
      (select to_char(c.sin_repartir - coalesce(a.sin_repartir, 0), 'FMSG999999990.00') || ':'
              || to_char(c.mayor - coalesce(a.mayor, 0), 'FMSG999999990.00') || ':' || case when c.cuadra then 't' else 'f' end
         from v_costo_por_obra c left join _c4_71 a on a.nivel = 'control' and a.cuenta = c.cuenta
        where c.periodo = v_mes and c.nivel = 'control' and c.cuenta = '5011'),
      (select to_char(c.sin_repartir - coalesce(a.sin_repartir, 0), 'FMSG999999990.00') || ':'
              || to_char(c.mayor - coalesce(a.mayor, 0), 'FMSG999999990.00') || ':' || case when c.cuadra then 't' else 'f' end
         from v_costo_por_obra c left join _c4_71 a on a.nivel = 'control' and a.cuenta = c.cuenta
        where c.periodo = v_mes and c.nivel = 'control' and c.cuenta = '5015'),
      (select to_char(c.del_anio - coalesce(a.del_anio, 0), 'FMSG999999990.00')
              || to_char(c.sin_repartir - coalesce(a.sin_repartir, 0), 'FMSG999999990.00') || '='
              || to_char(c.mayor - coalesce(a.mayor, 0), 'FMSG999999990.00') || ':' || case when c.cuadra then 't' else 'f' end
         from v_costo_por_obra c left join _c4_71 a on a.nivel = 'control' and a.cuenta is null and a.seccion = c.seccion
        where c.periodo = v_mes and c.nivel = 'control' and c.cuenta is null and c.seccion = 'costo'),
      (select to_char(c.del_periodo - coalesce(a.del_periodo, 0), 'FMSG999999990.00')
         from v_costo_por_obra c left join _c4_71 a on a.nivel = 'obra' and a.proyecto_id = c.proyecto_id and a.etiqueta_en = c.etiqueta_en
        where c.periodo = v_mes and c.nivel = 'obra' and c.proyecto_id = v_obra and c.etiqueta_en = 'Cost'),
      (select c.ok from fn_estados_control(v_mes, array['v_costo_por_obra']) c where c.vista = 'cuadre: auxiliar por obra = mayor'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (71, 'el costo por obra se concilia contra el mayor, con lo sin repartir a la vista', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 72. UN ACTIVO CON PRÉSTAMO Y ENGANCHE EN UN SOLO ASIENTO no infla el
--     flujo: la camioneta de 40,000 (5,000 de enganche del banco y 35,000
--     que el banco del préstamo pagó directo) da lo mismo en un asiento que
--     en dos: inversión −5,000 (los dos métodos), financiamiento 0, y la
--     parte del préstamo revelada sin dinero (−35,000 / +35,000). Antes, en
--     un asiento: inversión −40,000 y financiamiento +35,000, con los
--     cuadres en verde.
do $$
declare
  v_obt  text;
  v_esp  text := 'un_asiento=inv:-5000.00/-5000.00,fin:0.00/0.00,sd:-35000.00/+35000.00 igual_a_dos=t cuadra=t';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_bco  text := fn_puente_cuenta_de('banco');
  v_dos  text;
  v_uno  text;
begin
  if v_d is null then
    insert into _pruebas values (72, 'un activo con préstamo y enganche en un asiento no infla el flujo', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    -- (El banco con fondos antes de medir: un banco en rojo es sobregiro.)
    perform fn_postear(jsonb_build_object('fecha', (v_d + 1)::text, 'descripcion', 'c4-pruebas: el banco con fondos',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_bco, 'monto', '100000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-100000.00'))));
    create temp table _c4_72 on commit drop as
      select f.metodo, f.nivel, f.linea, f.importe from v_flujo_caja f
       where f.periodo = v_mes and (f.nivel = 'seccion' or f.linea in ('sd_inversion', 'sd_financiamiento'));
    create or replace function pg_temp.c4_72_medir(p_mes text) returns text
    language sql as $f$
      select format('inv:%s,fin:%s,sd:%s',
        (select string_agg(to_char(f.importe - coalesce(a.importe, 0), 'FMSG999999990.00'), '/' order by f.metodo)
           from v_flujo_caja f left join pg_temp._c4_72 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
          where f.periodo = p_mes and f.nivel = 'seccion' and f.linea = 'inversion'),
        (select string_agg(to_char(f.importe - coalesce(a.importe, 0), 'FM999999990.00'), '/' order by f.metodo)
           from v_flujo_caja f left join pg_temp._c4_72 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
          where f.periodo = p_mes and f.nivel = 'seccion' and f.linea = 'financiamiento'),
        (select string_agg(to_char(f.importe - coalesce(a.importe, 0), 'FMSG999999990.00'), '/'
                           order by case f.linea when 'sd_inversion' then 1 else 2 end)
           from v_flujo_caja f left join pg_temp._c4_72 a on a.metodo = f.metodo and a.nivel = f.nivel and a.linea = f.linea
          where f.periodo = p_mes and f.metodo = 'directo' and f.nivel = 'linea' and f.linea in ('sd_inversion', 'sd_financiamiento')))
    $f$;
    -- En dos asientos (se deshace).
    begin
      perform fn_postear(jsonb_build_object('fecha', (v_d + 11)::text, 'descripcion', 'c4-pruebas: camioneta, el préstamo',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1510', 'monto', '35000.00'),
                                    jsonb_build_object('cuenta', '2530', 'monto', '-35000.00'))));
      perform fn_postear(jsonb_build_object('fecha', (v_d + 11)::text, 'descripcion', 'c4-pruebas: camioneta, el enganche',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1510', 'monto', '5000.00'),
                                    jsonb_build_object('cuenta', v_bco, 'monto', '-5000.00'))));
      v_dos := pg_temp.c4_72_medir(v_mes);
      raise exception using errcode = 'MXT00';
    exception when sqlstate 'MXT00' then null;
    end;
    -- En uno (como se registra).
    perform fn_postear(jsonb_build_object('fecha', (v_d + 11)::text, 'descripcion', 'c4-pruebas: camioneta, enganche y préstamo',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1510', 'monto', '40000.00'),
                                  jsonb_build_object('cuenta', '2530', 'monto', '-35000.00'),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-5000.00'))));
    v_uno := pg_temp.c4_72_medir(v_mes);
    select format('un_asiento=%s igual_a_dos=%s cuadra=%s', v_uno, v_uno = v_dos,
      (select case when bool_and(f.cuadra) and count(*) = 10 then 't' else 'f' end
         from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (72, 'un activo con préstamo y enganche en un asiento no infla el flujo', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 73. LA RETENCIÓN POR PAGAR DE LA APERTURA (2020) VA CON SU PROVEEDOR: la
--     balanza de QuickBooks trae 1,000 de Retainage Payable del
--     subcontratista, en su obra; la apertura la pone a su nombre, y al
--     pagársela en el mes el balance no inventa un saldo a favor, la
--     retención por pagar baja 1,000, y la antigüedad no la parte en dos.
--     Antes entraba sin proveedor: 1,000 «a favor» y 1,000 de pasivo, y la
--     antigüedad −1,000 del proveedor y +1,000 sin proveedor.
do $$
declare
  v_obt  text;
  v_esp  text := 'apertura_2020=proveedor pago: saldos_a_favor=+0.00 retencion_por_pagar=-1000.00 antiguedad=+0.00';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_obra text := nullif(current_setting('mx4.obra', true), '');
  v_ap   periodos;
  v_m    jsonb;
  v_num  text;
  v_af0  numeric;
  v_rp0  numeric;
  v_an0  numeric;
  v_doc  text := 'docs/c4-pruebas/qb-apertura-73.csv';
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or v_d is null or v_obra is null then
    insert into _pruebas values (73, 'la retención por pagar de la apertura va con su proveedor', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta el mes abierto', null);
    return;
  end if;
  begin
    v_m := pg_temp.c4_montar();
    select coalesce(sum(abs(c.retencion)), 0) into v_an0
      from v_cxp_antiguedad c where c.periodo = v_mes and c.nivel <> 'total';
    perform pg_temp.c4_balanza_qb(v_doc, true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Retainage Payable', 'haber', '1,000.00', 'proveedor_qb', 'C4 Pruebas Supply Inc',
                         'proyecto_id', v_obra),
      jsonb_build_object('cuenta_qb', 'Undeposited Funds', 'debe', '1,000.00')));
    perform fn_apertura_mapeo_qb('Retainage Payable', '2020');
    perform pg_temp.c4_control_qb(v_doc);
    v_num := fn_apertura(v_ap.desde, v_doc)->>'asiento';
    select coalesce(sum(g.cifra) filter (where g.linea = 'saldos_a_favor'), 0),
           coalesce(sum(g.cifra) filter (where g.linea = 'retencion_por_pagar'), 0)
      into v_af0, v_rp0
      from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea';
    -- El mes: se le paga su retención (a su nombre, en su obra).
    perform fn_postear(jsonb_build_object('fecha', (v_d + 14)::text, 'descripcion', 'c4-pruebas: pago de la retención al subcontratista',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2020', 'monto', '1000.00', 'proyecto_id', v_obra,
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_m->>'proveedor'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-1000.00'))));
    select format('apertura_2020=%s pago: saldos_a_favor=%s retencion_por_pagar=%s antiguedad=%s',
      (select string_agg(case when l.tercero_tipo = 'proveedor' and l.tercero_id = v_m->>'proveedor' then 'proveedor'
                              else coalesce(l.tercero_tipo, 'sin_proveedor') end, ',')
         from asiento_lineas l join asientos a on a.id = l.asiento_id where a.numero = v_num and l.cuenta = '2020'),
      (select to_char(coalesce(sum(g.cifra), 0) - v_af0, 'FMSG999999990.00')
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'saldos_a_favor'),
      (select to_char(coalesce(sum(g.cifra), 0) - v_rp0, 'FMSG999999990.00')
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'retencion_por_pagar'),
      (select to_char(coalesce(sum(abs(c.retencion)), 0) - v_an0, 'FMSG999999990.00')
         from v_cxp_antiguedad c where c.periodo = v_mes and c.nivel <> 'total'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (73, 'la retención por pagar de la apertura va con su proveedor', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 74. NINGÚN SALDO CONTRARIO SE COMPENSA EN EL BALANCE: el préstamo del
--     accionista (2900) que queda DEUDOR (le devolvieron de más: él le debe
--     a la empresa 3,000) sale en el activo, «Cuenta por cobrar al
--     accionista», y no como pasivo negativo; un 941 pagado de más (2220
--     deudor, 600) sale en «Nómina e impuestos pagados de más» y no resta a
--     lo que se debe de nómina. Cada renglón es lo que dice el libro cuenta
--     por cuenta (los deudores de un lado, los acreedores del otro), y el
--     balance cuadra. Antes: pasivo −3,000 y sueldos por pagar 3,400.
do $$
declare
  v_obt  text;
  v_esp  text := '2900=+3000.00 2220=+600.00 accionista_por_cobrar=libro prestamo_accionista=libro impuestos_a_favor=libro '
                 'nomina_por_pagar=libro cuadra=t';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_p    periodos;
  v_bco  text := fn_puente_cuenta_de('banco');
  v_s    numeric;
begin
  select * into v_p from periodos p where p.periodo = v_mes;
  if v_d is null then
    insert into _pruebas values (74, 'ningún saldo contrario se compensa en el balance (2900 deudor, 941 pagado de más)', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform fn_postear(jsonb_build_object('fecha', (v_d + 1)::text, 'descripcion', 'c4-pruebas: el banco con fondos',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_bco, 'monto', '100000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-100000.00'))));
    -- 2900 queda en +3,000 (deudor) y 2220 en +600, sea lo que sea que
    -- tuvieran.
    select coalesce(sum(l.monto), 0) into v_s
      from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '2900' and a.fecha_contable <= v_p.hasta;
    perform fn_postear(jsonb_build_object('fecha', (v_d + 24)::text, 'descripcion', 'c4-pruebas: se le devuelve de más al accionista',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2900', 'monto', (3000.00 - v_s)::numeric(14,2)::text),
                                  jsonb_build_object('cuenta', v_bco, 'monto', (v_s - 3000.00)::numeric(14,2)::text))));
    select coalesce(sum(l.monto), 0) into v_s
      from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '2220' and a.fecha_contable <= v_p.hasta;
    perform fn_postear(jsonb_build_object('fecha', (v_d + 24)::text, 'descripcion', 'c4-pruebas: el 941 pagado de más',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2220', 'monto', (600.00 - v_s)::numeric(14,2)::text),
                                  jsonb_build_object('cuenta', v_bco, 'monto', (v_s - 600.00)::numeric(14,2)::text))));
    -- Lo que dice el libro, cuenta por cuenta, al corte (sin las
    -- contra-cuentas, que van así de por sí).
    create temp table _c4_74 on commit drop as
      select m.linea, m.contra, l.cuenta, sum(l.monto) as s
        from asiento_lineas l join asientos a on a.id = l.asiento_id
        join estados_mapeo m on m.cuenta = l.cuenta
       where a.fecha_contable <= v_p.hasta and m.estado = 'balance'
       group by m.linea, m.contra, l.cuenta;
    select format('2900=%s 2220=%s accionista_por_cobrar=%s prestamo_accionista=%s impuestos_a_favor=%s nomina_por_pagar=%s cuadra=%s',
      (select to_char(x.s, 'FMSG999999990.00') from _c4_74 x where x.cuenta = '2900'),
      (select to_char(x.s, 'FMSG999999990.00') from _c4_74 x where x.cuenta = '2220'),
      -- el activo: 1130 (y lo que vaya a ese renglón) en su lado, más lo
      -- deudor de los renglones del préstamo del accionista
      (select case when g.cifra = (select coalesce(sum(greatest(x.s, 0)), 0) from _c4_74 x
                                    where x.linea in ('accionista_por_cobrar', 'prestamo_accionista') and not x.contra)
                   then 'libro' else g.cifra::text end
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'accionista_por_cobrar'),
      (select case when coalesce(max(g.cifra), 0) = (select coalesce(sum(greatest(-x.s, 0)), 0) from _c4_74 x
                                                       where x.linea in ('accionista_por_cobrar', 'prestamo_accionista')
                                                         and not x.contra)
                   then 'libro' else coalesce(max(g.cifra), 0)::text end
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'prestamo_accionista'),
      (select case when g.cifra = (select coalesce(sum(greatest(x.s, 0)), 0) from _c4_74 x
                                    where x.linea in ('nomina_por_pagar', 'impuestos_por_pagar', 'impuestos_a_favor') and not x.contra)
                   then 'libro' else g.cifra::text end
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'impuestos_a_favor'),
      (select case when coalesce(max(g.cifra), 0) = (select coalesce(sum(greatest(-x.s, 0)), 0) from _c4_74 x
                                                       where x.linea = 'nomina_por_pagar' and not x.contra)
                   then 'libro' else coalesce(max(g.cifra), 0)::text end
         from v_balance_general g where g.periodo = v_mes and g.nivel = 'linea' and g.linea = 'nomina_por_pagar'),
      (select bool_and(g.cuadra) from v_balance_general g where g.periodo = v_mes and g.nivel = 'total' and g.linea = 'cuadra'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (74, 'ningún saldo contrario se compensa en el balance (2900 deudor, 941 pagado de más)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 75. UN AJUSTE DEL CPA AL AÑO (afecta_periodo = '2026', el año) cuenta
--     como del 31-dic: con el año de la apertura cerrado y un ajuste a ese
--     año posteado en el siguiente, sale en los «posteriores» de diciembre
--     y del año, no en los de la apertura, octubre ni noviembre; y el
--     balance ajustado de octubre no lo trae. Antes los períodos se
--     comparaban como texto: '2026' ≤ '2026-10' salía en todos.
do $$
declare
  v_obt  text;
  v_esp  text := 'posteriores=apertura:+0.00,oct:+0.00,nov:+0.00,dic:+750.00,anio:+750.00 balance_2050=oct:+0.00,dic:+750.00';
  v_ap   periodos;
  v_anio periodos;
  v_sig  periodos;
  v_ps   text[];
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select * into v_anio from periodos p where p.tipo = 'anio' and p.anio = v_ap.anio;
  select * into v_sig from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.anio = v_ap.anio + 1 order by p.desde limit 1;
  v_ps := array[v_ap.periodo,
                (select p.periodo from periodos p where p.tipo = 'mes' and p.desde = make_date(v_ap.anio, 10, 1)),
                (select p.periodo from periodos p where p.tipo = 'mes' and p.desde = make_date(v_ap.anio, 11, 1)),
                (select p.periodo from periodos p where p.tipo = 'mes' and p.desde = make_date(v_ap.anio, 12, 1)),
                v_anio.periodo];
  if v_sig.periodo is null or array_position(v_ps, null) is not null
     or (v_anio.estado <> 'cerrado' and not pg_temp.c4_apertura_libre()
         and not exists (select 1 from asientos a where a.tipo = 'apertura')) then
    insert into _pruebas values (75, 'un ajuste del CPA al año cuenta como del 31-dic, no como de octubre', v_esp,
                                 'omitida: faltan los meses del año de la apertura o un mes abierto del siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    create temp table _c4_75 on commit drop as
      select r.periodo, r.posteriores from v_resultados r where r.periodo = any (v_ps) and r.nivel = 'cuenta' and r.cuenta = '6600';
    create temp table _c4_75b on commit drop as
      select g.periodo, g.cifra_ajustada from v_balance_general g where g.periodo = any (v_ps) and g.nivel = 'cuenta' and g.cuenta = '2050';
    if v_anio.estado <> 'cerrado' then
      if pg_temp.c4_apertura_libre() then
        perform pg_temp.c4_montar();
        perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-75.csv');
        perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-75.csv');
      end if;
      perform pg_temp.c4_cerrar_hasta(v_anio.periodo);
    end if;
    perform pg_temp.c4_fingir_hoy(v_sig.desde + 14);
    perform fn_postear(jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_anio.periodo, 'fecha', (v_sig.desde + 9)::text,
      'motivo', 'c4-pruebas: el CPA devenga honorarios del año', 'descripcion', 'c4-pruebas: ajuste del CPA al año',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6600', 'monto', '750.00'),
                                  jsonb_build_object('cuenta', '2050', 'monto', '-750.00'))));
    select format('posteriores=%s balance_2050=%s',
      (select string_agg(x.k || ':' || to_char(coalesce((select r.posteriores from v_resultados r
                                                           where r.periodo = x.p and r.nivel = 'cuenta' and r.cuenta = '6600'), 0)
                                                - coalesce((select a.posteriores from _c4_75 a where a.periodo = x.p), 0),
                                                'FMSG999999990.00'), ',' order by x.n)
         from unnest(v_ps, array['apertura', 'oct', 'nov', 'dic', 'anio']) with ordinality as x(p, k, n)),
      (select string_agg(x.k || ':' || to_char(coalesce((select g.cifra_ajustada from v_balance_general g
                                                           where g.periodo = x.p and g.nivel = 'cuenta' and g.cuenta = '2050'), 0)
                                                - coalesce((select a.cifra_ajustada from _c4_75b a where a.periodo = x.p), 0),
                                                'FMSG999999990.00'), ',' order by x.n)
         from unnest(array[v_ps[2], v_ps[4]], array['oct', 'dic']) with ordinality as x(p, k, n)))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (75, 'un ajuste del CPA al año cuenta como del 31-dic, no como de octubre', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 76. EL FLUJO DEL AÑO DE LA APERTURA EMPIEZA CON LO QUE ELLA TRAJO: en el
--     año, el efectivo al inicio es el de la apertura (su leyenda lo
--     dice), su asiento no da piezas (ningún renglón del año cuenta ese
--     dinero como entrada), y el efectivo al final es el del balance al
--     31-dic. Antes el año empezaba en 0.00 y contaba los 25,000 de
--     QuickBooks como un «ajuste» que entró en el año.
do $$
declare
  v_obt  text;
  v_esp  text := 'inicio=apertura:t,t piezas_de_la_apertura=0 final=balance:t,t';
  v_ap   periodos;
  v_anio periodos;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select * into v_anio from periodos p where p.tipo = 'anio' and p.anio = v_ap.anio;
  if not pg_temp.c4_apertura_libre() or v_anio.periodo is null then
    insert into _pruebas values (76, 'el flujo del año de la apertura empieza con lo que ella trajo', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-76.csv');
    perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-76.csv');
    select format('inicio=apertura:%s piezas_de_la_apertura=%s final=balance:%s',
      (select string_agg(case when f.importe = g.cifra and f.etiqueta_es like '%apertura del%' then 't'
                              else 'f:' || f.importe || ' ' || f.etiqueta_es end, ',' order by f.metodo)
         from v_flujo_caja f, v_balance_general g
        where f.periodo = v_anio.periodo and f.nivel = 'total' and f.linea = 'efectivo_inicial'
          and g.periodo = v_ap.periodo and g.nivel = 'linea' and g.linea = 'efectivo'),
      (select count(*) from v_flujo_caja f
        where f.periodo = v_anio.periodo and f.nivel = 'linea' and f.importe <> 0
          and not exists (select 1 from v_flujo_lineas fl
                           where fl.fecha between v_anio.desde and v_anio.hasta and fl.tipo <> 'apertura'
                             and (fl.linea_directo = f.linea or fl.linea_indirecto = f.linea))
          and f.linea <> 'sobregiro'),
      (select string_agg(case when f.importe = g.cifra then 't' else 'f:' || f.importe || '<>' || g.cifra end, ',' order by f.metodo)
         from v_flujo_caja f, v_balance_general g
        where f.periodo = v_anio.periodo and f.nivel = 'total' and f.linea = 'efectivo_final'
          and g.periodo = v_anio.periodo and g.nivel = 'linea' and g.linea = 'efectivo'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (76, 'el flujo del año de la apertura empieza con lo que ella trajo', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 77. LO AJENO QUE ABRE LAS TABLAS DE c4 A LA API SE VE: una vista «de
--     ayuda para el CPA» sobre la balanza de QuickBooks sin
--     security_invoker (lee con los permisos de su dueño, se salta la RLS)
--     y una función SECURITY DEFINER que la lee y que anon puede ejecutar
--     ponen «protecciones de c4» en rojo, con su nombre; la misma vista con
--     security_invoker, y sin la función, ya no. Antes, las dos le daban a
--     anon la balanza y las diferencias, y todo en verde. (lock_timeout de
--     2 s: si la app está leyendo, «omitida».)
do $$
declare
  v_obt  text;
  v_esp  text := 'con_ayudantes=f:vista,funcion arreglado=sin_ellas';
  v_mes  text := current_setting('mx4.mes', true);
  v_x    text;
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (77, 'una vista o función ajena que abre las tablas de c4 a la API sale en rojo', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    create view public.c4_pruebas_qb_ayuda as
      select q.periodo, q.cuenta_qb, q.saldo from public.comparacion_qb q
      union all
      select d.periodo, d.explicacion, d.monto from public.diferencias d;
    grant select on public.c4_pruebas_qb_ayuda to anon, authenticated;
    create function public.c4_pruebas_qb_saldo(p_cuenta_qb text) returns numeric
    language sql stable security definer set search_path = public, pg_temp
    as $f$ select sum(saldo) from comparacion_qb where cuenta_qb = p_cuenta_qb $f$;
    grant execute on function public.c4_pruebas_qb_saldo(text) to anon;
    select (case when c.ok then 't' else 'f' end) || ':'
           || concat_ws(',', case when c.detalle like '%la vista public.c4_pruebas_qb_ayuda lee las tablas de c4 sin security_invoker%'
                                  then 'vista' end,
                             case when c.detalle like '%la función c4_pruebas_qb_saldo(text) es SECURITY DEFINER%anon%'
                                  then 'funcion' end)
      into v_x
      from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := 'con_ayudantes=' || v_x;
    alter view public.c4_pruebas_qb_ayuda set (security_invoker = true);
    drop function public.c4_pruebas_qb_saldo(text);
    select case when coalesce(c.detalle, '') not like '%c4_pruebas_qb%' then 'sin_ellas' else c.detalle end into v_x
      from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := v_obt || ' arreglado=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida: la app estaba usando las tablas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (77, 'una vista o función ajena que abre las tablas de c4 a la API sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 78. QUIÉN Y CUÁNDO DE UNA BALANZA DE QUICKBOOKS LOS PONE LA BASE: un
--     insert directo desde el SQL Editor «firmado» por alguien del equipo
--     y fechado en 2099 queda con el rol que de verdad lo escribió y la
--     hora de verdad, deja su rastro en estados_historial, y la carga
--     oficial de después es la vigente. Antes quedaba a nombre del equipo,
--     vigente para siempre (la carga oficial ya no contaba) y sin rastro.
do $$
declare
  v_obt  text;
  v_esp  text := 'directo=su_rol:sin_usuario:hoy vigente=la_oficial rastro=2+3';
  v_mes  text := current_setting('mx4.mes', true);
  -- (la firma falsa: alguien del equipo, o cualquiera)
  v_eq   uuid := coalesce(nullif(current_setting('mx4.equipo', true), '')::uuid, '00000000-0000-4000-a000-0000000000c4'::uuid);
  v_h0   bigint;
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (78, 'quién y cuándo de una balanza de QuickBooks los pone la base', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    select count(*) into v_h0 from estados_historial h where h.tabla = 'comparacion_qb';
    perform fn_apertura_mapeo_qb('C4 Pruebas Chase', fn_puente_cuenta_de('banco'));
    perform fn_apertura_mapeo_qb('C4 Pruebas Capital', '3100');
    insert into comparacion_qb (periodo, documento, linea, cuenta_qb, saldo, cargado_por, cargado_rol, cargado_el)
    values (v_mes, 'docs/c4-pruebas/qb-directo.csv', 1, 'C4 Pruebas Chase', 100.00, v_eq, 'authenticated', '2099-01-01'),
           (v_mes, 'docs/c4-pruebas/qb-directo.csv', 2, 'C4 Pruebas Capital', -100.00, v_eq, 'authenticated', '2099-01-01');
    perform fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-oficial.csv',
      '[{"cuenta_qb": "C4 Pruebas Chase", "debe": "223.45"}, {"cuenta_qb": "C4 Pruebas Capital", "haber": "100.00"},
        {"cuenta_qb": "C4 Pruebas Capital", "haber": "123.45"}]');
    select format('directo=%s vigente=%s rastro=%s',
      (select string_agg(distinct case when q.cargado_rol = fn_rol_llamante() then 'su_rol' else q.cargado_rol end || ':'
                                  || coalesce(q.cargado_por::text, 'sin_usuario') || ':'
                                  || case when q.cargado_el <= clock_timestamp() and q.cargado_el > clock_timestamp() - interval '1 hour'
                                          then 'hoy' else q.cargado_el::text end, ',')
         from comparacion_qb q where q.documento = 'docs/c4-pruebas/qb-directo.csv'),
      (select case when count(distinct b.documento) = 1 and min(b.documento) = 'docs/c4-pruebas/qb-oficial.csv' then 'la_oficial'
                   else string_agg(distinct b.documento, ',') end
         from v_qb_balanzas b where b.periodo = v_mes and b.fuente = 'comparacion_qb' and b.vigente),
      (select count(*) filter (where h.clave like v_mes || '|docs/c4-pruebas/qb-directo.csv|%') || '+'
              || count(*) filter (where h.clave like v_mes || '|docs/c4-pruebas/qb-oficial.csv|%')
         from estados_historial h where h.tabla = 'comparacion_qb'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (78, 'quién y cuándo de una balanza de QuickBooks los pone la base', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 79. LOS CAMBIOS SIN RASTRO SE VEN: el historial no acepta filas escritas
--     a mano (solo las de su trigger), y un cambio al mapeo o una
--     diferencia anotada con su trigger de historial apagado un instante
--     ponen «protecciones de c4» en rojo, con la fila que no es como la
--     dejó su historial. Como c2 cruza cuentas con cuentas_historial. Antes
--     el historial aceptaba el «rastro» escrito a mano y el control seguía
--     en verde. (lock_timeout de 2 s.)
do $$
declare
  v_obt  text;
  v_esp  text := 'a_mano=MX003 mapeo_sin_rastro=f:6100 diferencia_sin_rastro=f:1010';
  v_mes  text := current_setting('mx4.mes', true);
  v_x    text;
begin
  if nullif(v_mes, '') is null or not exists (select 1 from estados_mapeo m where m.cuenta = '6100') then
    insert into _pruebas values (79, 'los cambios sin rastro al mapeo y a las diferencias salen en rojo', v_esp,
                                 'omitida: falta el mes abierto o el mapeo de 6100', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    begin
      insert into estados_historial (tabla, clave, operacion, cambiado_el, usuario_id, rol, antes, despues)
      values ('estados_mapeo', '6100', 'UPDATE', now(), null, 'authenticated', '{}', '{}');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'a_mano=' || v_x;
    alter table estados_mapeo disable trigger trg_estados_mapeo_historial;
    update estados_mapeo set seccion = 'otros_gastos', linea = 'otros_gastos' where cuenta = '6100';
    alter table estados_mapeo enable trigger trg_estados_mapeo_historial;
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%estados_mapeo 6100 no es como la dejó su último cambio%' then '6100' else c.detalle end
      into v_x
      from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := v_obt || ' mapeo_sin_rastro=' || v_x;
    alter table diferencias disable trigger trg_diferencias_historial;
    insert into diferencias (periodo, cuenta, monto, clase, explicacion)
    values (v_mes, '1010', -123.45, 'puente', 'c4-pruebas: depósito en tránsito sin rastro');
    alter table diferencias enable trigger trg_diferencias_historial;
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle ~ ('diferencias ' || v_mes || '\|1010\|[0-9a-f-]+ no tiene su renglón en estados_historial') then '1010'
                   else c.detalle end
      into v_x
      from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := v_obt || ' diferencia_sin_rastro=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida: la app estaba usando las tablas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (79, 'los cambios sin rastro al mapeo y a las diferencias salen en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 80. «PROTECCIONES DE c4» MIRA LO QUE HACEN, NO SOLO EL NOMBRE (las
--     huellas de c4): una guarda vaciada con create or replace (mismo
--     nombre, mismo oid), un trigger de historial rehecho solo para INSERT,
--     un trigger ajeno que se traga las altas del historial y una regla
--     «do instead nothing» salen, cada uno, en rojo con su nombre. Antes,
--     los cuatro en verde. (lock_timeout de 2 s.)
do $$
declare
  v_obt  text;
  v_esp  text := 'guarda=f:fn_estados_inmutable() trigger=f:estados_mapeo.trg_estados_mapeo_historial '
                 'ajeno=f:estados_historial.c4_pruebas_tragar regla=f:estados_historial.c4_pruebas_nada';
  v_mes  text := current_setting('mx4.mes', true);
  v_r    text;
  v_x    text;
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (80, 'protecciones de c4 mira lo que hacen sus guardas, triggers y reglas', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    -- (1) la guarda de lo inmutable, vaciada
    create or replace function public.fn_estados_inmutable() returns trigger
    language plpgsql set search_path = public, pg_temp as $f$ begin return coalesce(new, old); end $f$;
    revoke execute on function public.fn_estados_inmutable() from public, anon, authenticated, service_role;
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%funcion fn_estados_inmutable() cambió desde que se pegó c4%' then 'fn_estados_inmutable()'
                   else c.detalle end
      into v_x from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_r := 'guarda=' || v_x;
    -- (2) el trigger de historial, rehecho solo para INSERT (mismo nombre y función)
    drop trigger trg_estados_mapeo_historial on public.estados_mapeo;
    create trigger trg_estados_mapeo_historial after insert on public.estados_mapeo
      for each row execute function public.fn_estados_historial('cuenta');
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%trigger estados_mapeo.trg_estados_mapeo_historial cambió desde que se pegó c4%'
                   then 'estados_mapeo.trg_estados_mapeo_historial' else c.detalle end
      into v_x from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_r := v_r || ' trigger=' || v_x;
    -- (3) un trigger ajeno que se traga las altas del historial
    create function pg_temp.c4_pruebas_tragar() returns trigger language plpgsql as $f$ begin return null; end $f$;
    create trigger c4_pruebas_tragar before insert on public.estados_historial
      for each row execute function pg_temp.c4_pruebas_tragar();
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%trigger estados_historial.c4_pruebas_tragar es nuevo: no es de c4%'
                   then 'estados_historial.c4_pruebas_tragar' else c.detalle end
      into v_x from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_r := v_r || ' ajeno=' || v_x;
    drop trigger c4_pruebas_tragar on public.estados_historial;
    -- (4) una regla que tira cada alta del historial
    create rule c4_pruebas_nada as on insert to public.estados_historial do instead nothing;
    select (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%regla estados_historial.c4_pruebas_nada es nuevo: no es de c4%'
                   then 'estados_historial.c4_pruebas_nada' else c.detalle end
      into v_x from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    v_obt := v_r || ' regla=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida: la app estaba usando las tablas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (80, 'protecciones de c4 mira lo que hacen sus guardas, triggers y reglas', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 81. LA APERTURA REVERSADA DESDE LA APP NO DEJA TODO EN VERDE: el dueño
--     la reversa «para rehacerla luego»; su balanza de QuickBooks sigue en
--     la comparación de la apertura (marcada como de una apertura que ya no
--     está viva) y sale en rojo contra el libro, y fn_estados_control dice
--     «apertura en el libro» en rojo, con el asiento reversado, en la
--     apertura, en el mes y en 'hoy'. Antes su balanza desaparecía y todo
--     salía en verde con el banco en 0.
do $$
declare
  v_obt  text;
  v_esp  text := 'qb=reversada comparacion=rojo control=f:reversada,f:reversada,f:reversada';
  v_ap   periodos;
  v_mes  text := current_setting('mx4.mes', true);
  v_id   uuid;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or nullif(current_setting('mx4.dueno', true), '') is null or nullif(v_mes, '') is null then
    insert into _pruebas values (81, 'la apertura reversada desde la app no deja todo en verde', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta el dueño', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-81.csv');
    v_id := (fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-81.csv')->>'id')::uuid;
    perform pg_temp.c4_como('dueno');
    perform public.fn_reversar(v_id, 'c4-pruebas: la rehago luego');
    execute 'reset role';
    perform pg_temp.c4_como(null);
    select format('qb=%s comparacion=%s control=%s',
      (select case when count(*) > 0 and bool_and(not q.vivo) then 'reversada' else count(*) || ':' || coalesce(bool_and(q.vivo)::text, '-') end
         from v_qb_balanzas q where q.periodo = v_ap.periodo and q.fuente = 'apertura_balanza_qb'),
      (select case when count(*) filter (where not c.ok) > 0 then 'rojo' else 'verde:' || count(*) end
         from v_comparacion c where c.periodo = v_ap.periodo),
      (select string_agg((case when c.ok then 't' else 'f' end) || ':'
                         || case when c.detalle like '%está REVERSADA%' then 'reversada' else coalesce(c.detalle, '-') end, ','
                         order by x.n)
         from unnest(array[v_ap.periodo, v_mes, 'hoy']) with ordinality as x(p, n)
         cross join lateral fn_estados_control(x.p, array['v_saldos_dinero']) c
        where c.vista = 'cuadre: apertura en el libro'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  execute 'reset role';
  insert into _pruebas values (81, 'la apertura reversada desde la app no deja todo en verde', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 82. LOS PERMISOS POR COLUMNA TAMBIÉN SE VEN: un grant de insert por
--     columnas a service_role sobre comparacion_qb (la pantalla «Column
--     privileges» de Supabase) pone «protecciones de c4» en rojo con la
--     tabla, el rol y la columna. Antes has_table_privilege no lo veía y
--     service_role plantaba la balanza vigente con todo en verde.
--     (lock_timeout de 2 s.)
do $$
declare
  v_obt  text;
  v_esp  text := 'grant=f:service_role:INSERT:saldo';
  v_mes  text := current_setting('mx4.mes', true);
begin
  if nullif(v_mes, '') is null then
    insert into _pruebas values (82, 'un permiso por columna sobre las tablas de c4 sale en rojo', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    grant insert (periodo, documento, linea, cuenta_qb, saldo) on public.comparacion_qb to service_role;
    select 'grant=' || (case when c.ok then 't' else 'f' end) || ':'
           || case when c.detalle like '%tabla comparacion_qb: service_role puede INSERT la columna saldo%' then 'service_role:INSERT:saldo'
                   else c.detalle end
      into v_obt
      from fn_estados_control(v_mes, array['v_balanza']) c where c.vista = 'cuadre: protecciones de c4';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida: la app estaba usando las tablas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (82, 'un permiso por columna sobre las tablas de c4 sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 83. UN DEPÓSITO DE VERDAD PARECIDO NO TUMBA EL ESCENARIO: con dos
--     depósitos normales del mes que se parecen a los cobros de la prueba
--     (un ACH de 1,500.00 sin referencia el mismo día, un cheque de
--     3,000.00 sin referencia), el escenario se monta igual: sus cobros
--     llevan «duplicado_confirmado» (son datos de prueba y la subtransacción
--     los deshace). El detector de depósito doble de c3 sigue en su sitio
--     para los de verdad (la 95 de c3-pruebas). Antes, con uno así en el
--     mes, 34 pruebas salían en rojo en producción. (Los dos «de verdad» de
--     esta prueba también son datos de prueba: entran diciéndolo, para que
--     un depósito real igual a ellos —el del hallazgo, ya en el libro— no
--     la tumbe a ella.)
do $$
declare
  v_obt  text;
  v_esp  text := 'reales=2 escenario=montado';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a    text := nullif(current_setting('mx4.obra', true), '');
  v_b    text := nullif(current_setting('mx4.obra2', true), '');
  v_e    jsonb;
begin
  if v_d is null or v_a is null or v_b is null then
    insert into _pruebas values (83, 'un depósito de verdad parecido no tumba el escenario de las pruebas', v_esp,
                                 'omitida: falta el mes abierto o dos obras', null);
    return;
  end if;
  begin
    -- (Los candados de los recibos antes de postear: el escenario sube
    -- recibos. Ver c4_candados_recibos.)
    perform pg_temp.c4_candados_recibos();
    -- Los de verdad, como los registraría Edgar (anticipos de obra).
    perform fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: simula uno de verdad', 'fecha', (v_d + 11)::text,
              'monto', '1500.00', 'medio', 'ach', 'proyecto_id', v_b,
              'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_b, 'monto', '1500.00'))));
    perform fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: simula uno de verdad', 'fecha', (v_d + 12)::text,
              'monto', '3000.00', 'medio', 'cheque', 'proyecto_id', v_a,
              'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_a, 'monto', '3000.00'))));
    v_obt := 'reales=2';
    begin
      v_e := pg_temp.c4_escenario();
      v_obt := v_obt || ' escenario=' || case when v_e ? 'cobro_rebotado' and v_e ? 'cobro_anticipo' then 'montado' else v_e::text end;
    exception when others then
      v_obt := v_obt || ' escenario=' || sqlstate || ' ' || left(sqlerrm, 80);
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (83, 'un depósito de verdad parecido no tumba el escenario de las pruebas', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 84. UN MAPEO EQUIVOCADO DE QUICKBOOKS NO PASA LA APERTURA: con el
--     material de enero a septiembre (Job Materials) mapeado a una cuenta
--     de balance (1300, material en bodega) en vez de a 5100, fn_apertura
--     para (MX001) y dice por qué: con ese mapeo la utilidad y el activo
--     no son los de QuickBooks (Net Income, TOTAL ASSETS), con la fila que
--     lo explica; y sin las filas de control no posteala (MX001: faltan, y
--     dice las tres: Net Income, TOTAL ASSETS y Total Liabilities).
--     Antes se posteaba con todo en verde: 40,000 de «inventario» y la
--     utilidad inflada.
do $$
declare
  v_obt  text;
  v_esp  text := 'mapeo_equivocado=MX001:net_income+total_assets+job_materials sin_control=MX001:faltan';
  v_ap   periodos;
  v_x    text;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or not exists (select 1 from cuentas c where c.codigo = '1300' and c.tipo = 'activo') then
    insert into _pruebas values (84, 'un mapeo equivocado de QuickBooks no pasa la apertura', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o no hay 1300', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-84.csv');
    perform fn_apertura_mapeo_qb('Job Materials', '1300');
    begin
      perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-84.csv');
      v_x := 'posteada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%no amarra con su control de QuickBooks%(Net Income)%(TOTAL ASSETS)%'
                                          and sqlerrm like '%«Job Materials» (40000.00) va a 1300, de activo%'
                                     then 'net_income+total_assets+job_materials' else left(sqlerrm, 200) end;
    end;
    v_obt := 'mapeo_equivocado=' || v_x;
    perform fn_apertura_mapeo_qb('Job Materials', '5100');
    delete from apertura_balanza_qb b where b.documento = 'docs/c4-pruebas/qb-apertura-84.csv' and b.control is not null;
    begin
      perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-84.csv');
      v_x := 'posteada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%no trae su control de QuickBooks (falta «Net Income», «TOTAL ASSETS» y «Total Liabilities»)%'
                                     then 'faltan' else left(sqlerrm, 200) end;
    end;
    v_obt := v_obt || ' sin_control=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (84, 'un mapeo equivocado de QuickBooks no pasa la apertura', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 85. EL CUSTOMER:JOB MAPEADO A OTRA OBRA NO MANDA A DAR DE ALTA UNA
--     FACTURA QUE YA ESTÁ: la factura abierta de QuickBooks está en la app
--     en su obra, y su Customer:Job quedó mapeado a otra; la carga para
--     (MX006) y dice que SÍ está, en qué obra, y que se corrige el mapeo,
--     no la app. Antes decía «no está en la app, dala de alta», y hacerle
--     caso duplicaba la factura con la cuenta por cobrar en la obra
--     equivocada, todo en verde.
do $$
declare
  v_obt  text;
  v_esp  text := 'carga=MX006:si_esta:en_su_obra:corrige_el_mapeo';
  v_a    text := nullif(current_setting('mx4.obra', true), '');
  v_b    text := nullif(current_setting('mx4.obra2', true), '');
begin
  if v_a is null or v_b is null or not exists (select 1 from periodos p where p.tipo = 'apertura') then
    insert into _pruebas values (85, 'el Customer:Job mapeado a otra obra no manda a dar de alta una factura que ya está', v_esp,
                                 'omitida: faltan dos obras o la apertura', null);
    return;
  end if;
  begin
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400008, v_a, 'C4-QB-8', '2026-08-20', 6000.00, 0);
    perform fn_apertura_mapeo_trabajo('C4 Pruebas, Familia:Casa', v_b);
    begin
      perform fn_apertura_balanza_cargar('docs/c4-pruebas/qb-apertura-85.csv', jsonb_build_array(
        jsonb_build_object('cuenta_qb', 'Chase Chk 4392', 'debe', '44,000.00'),
        jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'factura_num', 'C4-QB-8', 'cliente_trabajo', 'C4 Pruebas, Familia:Casa',
                           'debe', '6,000.00'),
        jsonb_build_object('cuenta_qb', 'Retained Earnings', 'haber', '50,000.00')));
      v_obt := 'carga=entró';
    exception when others then
      v_obt := 'carga=' || sqlstate || ':' ||
               case when sqlerrm like '%la factura #C4-QB-8 SÍ está en la app%' and sqlerrm like '%en ' || v_a || ' (id -4400008%'
                         and sqlerrm like '%fn_apertura_mapeo_trabajo%' and sqlerrm not like '%Dala de alta%'
                    then 'si_esta:en_su_obra:corrige_el_mapeo' else left(sqlerrm, 200) end;
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (85, 'el Customer:Job mapeado a otra obra no manda a dar de alta una factura que ya está', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 86. LA RETENCIÓN POR COBRAR DE LA APERTURA VA POR FACTURA: QuickBooks
--     la trae en su propia cuenta (Retainage Receivable) por Customer:Job;
--     sin decir de qué factura, fn_apertura para (MX006: va por factura, y
--     dice qué facturas de la obra tienen retención); con su factura entra
--     a 1120 contra la partida de esa factura, y en el mes la retención se
--     cobra. Antes entraba por obra, sin partida, todo en verde, y en
--     octubre el cobro de la retención «no cabía».
do $$
declare
  v_obt  text;
  v_esp  text := 'sin_factura=MX006:va_por_factura con_factura=facturas/-4400007:1250.00 cobro_de_la_retencion=entró';
  v_ap   periodos;
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a    text := nullif(current_setting('mx4.obra', true), '');
  v_num  text;
  v_x    text;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or v_d is null or v_a is null then
    insert into _pruebas values (86, 'la retención por cobrar de la apertura va por factura (y se cobra)', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-4400007, v_a, 'C4-QB-7', '2026-09-10', 12500.00, 1250.00);
    perform fn_apertura_mapeo_qb('Retainage Receivable', fn_puente_cuenta_de('retencion_cxc'));
    -- Sin su factura.
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-86a.csv', true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Retainage Receivable', 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A', 'debe', '1,250.00'),
      jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '1,250.00')));
    perform pg_temp.c4_control_qb('docs/c4-pruebas/qb-apertura-86a.csv');
    begin
      perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-86a.csv');
      v_x := 'posteada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%La retención por cobrar va por factura%' and sqlerrm like '%C4-QB-7%'
                                     then 'va_por_factura' else left(sqlerrm, 200) end;
    end;
    v_obt := 'sin_factura=' || v_x;
    -- Con su factura (la cuenta por cobrar sin la retención, y la retención aparte).
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-86b.csv', true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'factura_id', -4400007, 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A',
                         'debe', '11,250.00'),
      jsonb_build_object('cuenta_qb', 'Retainage Receivable', 'factura_id', -4400007, 'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A',
                         'debe', '1,250.00'),
      jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '12,500.00')));
    perform pg_temp.c4_control_qb('docs/c4-pruebas/qb-apertura-86b.csv');
    v_num := fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-86b.csv')->>'asiento';
    select v_obt || ' con_factura=' || coalesce(string_agg(l.partida_tabla || '/' || l.partida_id || ':' || l.monto, ','), '-')
      into v_obt
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where a.numero = v_num and l.cuenta = fn_puente_cuenta_de('retencion_cxc') and l.partida_id = '-4400007';
    begin
      perform fn_cobro_registrar(jsonb_build_object('duplicado_confirmado', 'c4-pruebas: dato de prueba', 'fecha', (v_d + 19)::text,
                'monto', '1250.00', 'medio', 'cheque', 'referencia', 'c4-ret-7',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -4400007, 'monto', '1250.00', 'es_retencion', true))));
      v_x := 'entró';
    exception when others then v_x := sqlstate || ':' || left(sqlerrm, 120);
    end;
    v_obt := v_obt || ' cobro_de_la_retencion=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (86, 'la retención por cobrar de la apertura va por factura (y se cobra)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 87. LA BALANZA DE QUINCENA SE COMPARA A SU FECHA: la balanza de
--     QuickBooks al día 15 del mes, igual al libro a ese día, cargada con
--     su fecha (p_al), cuadra entera aunque después del 15 se pagó la
--     tarjeta; la comparación dice al = el 15. Cargada sin fecha, ese pago
--     sale como diferencia en el banco y en la tarjeta. Antes la
--     comparación cortaba siempre el libro al último día del período. Y
--     cada versión cargada sigue comparable: con la otra ya cargada, la de
--     la quincena, pedida por su documento (c4.comparar_documento), se
--     compara otra vez a su fecha y cuadra; fn_estados_control sigue
--     mirando la última (la sin fecha, en rojo). Antes, al cargar la del
--     31-dic, la del 15 dejaba de verse.
do $$
declare
  v_obt  text;
  v_esp  text := 'al_15=t:0 sin_fecha=2 version_15=t:0 control=la_ultima';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes  text := current_setting('mx4.mes', true);
  v_bco  text := fn_puente_cuenta_de('banco');
begin
  if v_d is null then
    insert into _pruebas values (87, 'la balanza de quincena se compara a su fecha', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform fn_postear(jsonb_build_object('fecha', (v_d + 1)::text, 'descripcion', 'c4-pruebas: la tarjeta de prueba',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '4812.55'),
                                  jsonb_build_object('cuenta', '2100-9998', 'monto', '-4812.55'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 19)::text, 'descripcion', 'c4-pruebas: pago de la tarjeta, después del 15',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9998', 'monto', '4812.55'),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-4812.55'))));
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-quincena.csv', '{}', false, v_d + 14);
    select format('al_15=%s:%s', bool_and(c.al = v_d + 14), count(*) filter (where not c.ok)) into v_obt
      from v_comparacion c where c.periodo = v_mes;
    perform pg_temp.c4_qb_del_libro(v_mes, 'docs/c4-pruebas/qb-quincena-sin-fecha.csv', '{}', false, v_d + 14, false);
    select v_obt || ' sin_fecha=' || count(*) filter (where not c.ok and c.cuenta in (v_bco, '2100-9998')) into v_obt
      from v_comparacion c where c.periodo = v_mes;
    -- La de la quincena otra vez, pedida por su documento.
    perform set_config('c4.comparar_documento', 'docs/c4-pruebas/qb-quincena.csv', true);
    select v_obt || format(' version_15=%s:%s', bool_and(c.al = v_d + 14 and c.documento = 'docs/c4-pruebas/qb-quincena.csv'),
                           count(*) filter (where not c.ok))
      into v_obt
      from v_comparacion c where c.periodo = v_mes;
    select v_obt || ' control=' || coalesce(max(case when c.ok then 'la_pedida' else 'la_ultima' end), '-') into v_obt
      from fn_estados_control(v_mes, array['v_comparacion']) c where c.vista = 'cuadre: QuickBooks sin diferencias sin explicar';
    perform set_config('c4.comparar_documento', '', true);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (87, 'la balanza de quincena se compara a su fecha', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 88. EL JIT APAGADO PARA LA APP, DONDE PostgREST LO LEE: el rol de la app
--     (authenticated) lleva jit = off para todas las bases (pg_roles.
--     rolconfig: es lo que PostgREST lee y aplica en cada consulta, como su
--     tope de 8 s; un «alter role … in database …» no lo ve), y es de los
--     ajustes que PostgREST aplica (contexto «user»); fn_estados_control
--     también lo lleva. Con el JIT del servidor, la gráfica del Panel
--     pasaba de 2 s con 10.000 asientos, casi todo compilando. Antes el
--     pegado lo ponía «in database»: esta prueba y «c4 · jit» salían en
--     verde y PostgREST seguía compilando. (Si el pegado no pudo cambiar el
--     rol, lo dijo con un WARNING y en la fila «c4 · jit» del final: esta
--     prueba sale en rojo hasta que se haga.)
do $$
declare
  v_obt  text;
  v_esp  text := 'postgrest=jit_off control=jit_off';
begin
  -- (Lo que PostgREST aplica al rol que suplanta: sus ajustes de
  -- pg_roles.rolconfig cuyo parámetro puede cambiar un usuario.)
  select format('postgrest=%s control=%s',
    case when exists (select 1
                        from pg_roles r
                        cross join lateral unnest(coalesce(r.rolconfig, '{}')) c
                        join pg_settings ps on ps.name = split_part(c, '=', 1) and ps.context = 'user'
                       where r.rolname = 'authenticated' and split_part(c, '=', 1) = 'jit'
                         and lower(substr(c, strpos(c, '=') + 1)) = 'off')
         then 'jit_off' else 'jit_encendido' end,
    (select case when 'jit=off' = any (coalesce(p.proconfig, '{}')) then 'jit_off' else 'jit_encendido' end
       from pg_proc p where p.oid = 'public.fn_estados_control(text,text[])'::regprocedure))
    into v_obt;
  insert into _pruebas values (88, 'el JIT apagado para la app (donde PostgREST lo lee) y para fn_estados_control', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 89. LO SIN REPARTIR QUE NO SE EXPLICA SALE EN ROJO: el auxiliar por obra
--     concilia con el mayor, y lo sin repartir se explica solo en las
--     cuentas que no exigen obra (el burden real, 5015, sin obra: en
--     verde). Si una línea de una cuenta que EXIGE obra (5100) queda sin
--     ella —sus guardas no lo dejan: aquí se le quita por debajo, con los
--     triggers del libro apagados un instante, como el ataque de la 22 de
--     c2—, su fila de control y la de la sección costo salen en rojo, y
--     fn_estados_control lo dice con la cuenta. Antes el control sumaba
--     las mismas líneas contra sí mismas y no podía salir en rojo. (Si la
--     app está usando el libro, espera 2 s y sale «omitida».)
do $$
declare
  v_obt   text;
  v_esp   text := 'normal=t,t atacada=5100:f:+300.37 costo=f cuadre=f:5100 bolsa_5015=t';
  v_d     date := nullif(current_setting('mx4.desde', true), '')::date;
  v_mes   text := current_setting('mx4.mes', true);
  v_obra  text := nullif(current_setting('mx4.obra', true), '');
  v_bco   text := fn_puente_cuenta_de('banco');
  v_id    uuid;
  v_s0    numeric;
  v_norm  text;
  v_omite text;
begin
  if v_d is null or v_obra is null then
    insert into _pruebas values (89, 'lo sin repartir que no se explica sale en rojo', v_esp, 'omitida: falta el mes abierto o una obra', null);
    return;
  end if;
  begin
    execute 'set local lock_timeout = ''2s''';
    begin
      -- (antes que el candado de la cadena: c2, prueba 24)
      lock table public.asientos, public.asiento_lineas in access exclusive mode;
    exception when lock_not_available then
      v_omite := 'el libro estaba en uso (se prueba en el banco)';
      raise exception using errcode = 'MXT00';
    end;
    execute 'set local lock_timeout = 0';
    select coalesce(sum(c.sin_repartir), 0) into v_s0
      from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'control' and c.cuenta = '5100';
    v_id := (fn_postear(jsonb_build_object('fecha', (v_d + 9)::text, 'descripcion', 'c4-pruebas: material que pierde su obra por debajo',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '300.37', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-300.37'))))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', (v_d + 9)::text, 'descripcion', 'c4-pruebas: burden real del mes, sin obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', v_bco, 'monto', '-100.00'))));
    select string_agg(case when c.cuadra then 't' else 'f' end, ',' order by c.cuenta) into v_norm
      from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'control' and c.cuenta in ('5100', '5015');
    -- El ataque: la línea de 5100 pierde su obra por debajo de sus guardas.
    set constraints all immediate;
    begin
      execute 'alter table public.asiento_lineas disable trigger user';
    exception when insufficient_privilege then
      v_omite := format('el editor no puede apagar los triggers del libro (%s)', sqlstate);
      raise exception using errcode = 'MXT00';
    end;
    update asiento_lineas set proyecto_id = null where asiento_id = v_id and cuenta = '5100';
    execute 'alter table public.asiento_lineas enable trigger user';
    select format('normal=%s atacada=%s costo=%s cuadre=%s bolsa_5015=%s', v_norm,
      (select '5100:' || case when c.cuadra then 't' else 'f' end || ':' || to_char(c.sin_repartir - v_s0, 'FMSG999999990.00')
         from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'control' and c.cuenta = '5100'),
      (select case when c.cuadra then 't' else 'f' end
         from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'control' and c.cuenta is null and c.seccion = 'costo'),
      (select case when c.ok then 't' else 'f' || case when c.detalle like '%5100%sin explicar%' then ':5100' else ':' || coalesce(c.detalle, '-') end end
         from fn_estados_control(v_mes, array['v_costo_por_obra']) c where c.vista = 'cuadre: auxiliar por obra = mayor'),
      (select case when c.cuadra then 't' else 'f' end
         from v_costo_por_obra c where c.periodo = v_mes and c.nivel = 'control' and c.cuenta = '5015'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  if v_omite is not null then
    insert into _pruebas values (89, 'lo sin repartir que no se explica sale en rojo', v_esp, 'omitida: ' || v_omite, null);
  else
    insert into _pruebas values (89, 'lo sin repartir que no se explica sale en rojo', v_esp, coalesce(v_obt, '-'),
                                 coalesce(v_obt = v_esp, false));
  end if;
end $$;

-- 90. LAS PRUEBAS PIDEN LOS CANDADOS EN EL ORDEN DE LA APP (los cajones de
--     los recibos, después periodos y la cadena: ver c4_candados_recibos).
--     Con el escenario puesto, esta transacción tiene los 512 cajones; y
--     pedirlos con la cadena ya tomada (un asiento a mano) o con periodos
--     es MXT10. Antes el escenario pedía solo los de sus dos recibos, y ya
--     con la cadena tomada: con c4-volumen.sh subiendo tickets a la vez,
--     Postgres cortaba a uno de los dos (40P01) y el puente dejaba ese
--     recibo en la bandeja (la 24 salió en rojo en 17.6; y dos subidas de
--     los teléfonos se quedaron sin asiento).
do $$
declare
  v_esp text := 'cajones=512 cadena=MXT10 periodos=MXT10';
  v_c   text;
  v_cad text;
  v_per text;
  v_obt text;
begin
  if nullif(current_setting('mx4.desde', true), '') is null then
    insert into _pruebas values (90, 'las pruebas piden los candados en el orden de la app', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_escenario();
    select count(*)::text into v_c
      from pg_locks l
     where l.pid = pg_backend_pid() and l.granted and l.locktype = 'advisory'
       and l.classid::bigint = 820260925 and l.objsubid = 2;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_c := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  -- Tarde: con la cadena ya tomada.
  begin
    perform fn_postear(jsonb_build_object('fecha', current_setting('mx4.desde'), 'descripcion', 'c4-pruebas: toma la cadena',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-1.00'))));
    perform pg_temp.c4_candados_recibos();
    v_cad := 'los tomó';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_cad := sqlstate;
  end;
  -- Tarde: con periodos ya tomado.
  begin
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_candados_recibos();
    v_per := 'los tomó';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_per := sqlstate;
  end;
  v_obt := format('cajones=%s cadena=%s periodos=%s', coalesce(v_c, '-'), coalesce(v_cad, '-'), coalesce(v_per, '-'));
  insert into _pruebas values (90, 'las pruebas piden los candados en el orden de la app', v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- RONDA 4 DE c4: una prueba por hallazgo (91 a 109). Cada una falla con
-- la versión anterior de c4-estados.sql (o de c2 y c3, donde se dice).
-- =====================================================================

-- 91. EL RESULTADO DE LA APERTURA ES EL QUE SE POSTEÓ: posteada la
--     apertura, re-mapear en QuickBooks una cuenta de resultados a una de
--     balance («Job Materials», 40,000, a 1300) lo AVISA (WARNING y la llave
--     aviso: la usa la apertura ya posteada, y cambia de clase) y no mueve
--     el balance: el resultado de enero a septiembre sigue siendo el que
--     3900 trae (38,050, que baja a su línea de la apertura), no el de la
--     balanza con el mapeo de hoy (78,050); y en la comparación del mes a
--     3900 se le resta lo posteado (arrastre 38,050, que baja a esa misma
--     línea). Antes el balance pasaba 78,050 de utilidades retenidas al
--     resultado del ejercicio (las dos líneas mal, el total bien), sin
--     aviso, y 3900 salía en rojo en la comparación.
do $$
declare
  v_obt text;
  v_esp text := 'aviso=t:clase balance=resultado_ejercicio:38050.00,utilidades_retenidas:-38050.00 baja=38050.00:1 '
                'arrastre_3900=38050.00:38050.00';
  v_ap  periodos;
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_av  jsonb;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or v_d is null or extract(year from v_d)::int <> v_ap.anio then
    insert into _pruebas values (91, 'el resultado de la apertura es el que se posteó, aunque se re-mapee (y se avisa)', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o el mes es de otro año)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-91.csv');
    perform fn_apertura(v_ap.desde, 'docs/c4-pruebas/qb-apertura-91.csv');
    v_av := fn_apertura_mapeo_qb('Job Materials', '1300');
    -- (una balanza del mes cualquiera: con ella el mes tiene comparación)
    perform fn_comparacion_qb_cargar(v_mes, 'docs/c4-pruebas/qb-91.csv', '[{"cuenta_qb": "QB c4-91", "saldo": "0.00"}]');
    perform pg_temp.c4_bajar_preparar();
    select format('aviso=%s balance=%s baja=%s arrastre_3900=%s',
      case when v_av->>'aviso' like '%está en la apertura ya posteada%CAMBIA DE CLASE%' then 't:clase'
           else coalesce(v_av->>'aviso', 'no') end,
      (select string_agg(b.linea || ':' || b.cifra, ',' order by b.linea) from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'resultado_apertura'),
      (select x.total || ':' || x.filas
         from v_balance_general b, pg_temp.c4_bajar(b.bajar->'cifra') x
        where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'resultado_apertura'
          and b.linea = 'resultado_ejercicio'),
      (select c.arrastre_apertura || ':' || (select x.total from pg_temp.c4_bajar(c.bajar->'arrastre_apertura') x)
         from v_comparacion c where c.periodo = v_mes and c.cuenta = '3900'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (91, 'el resultado de la apertura es el que se posteó, aunque se re-mapee (y se avisa)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 92. LO PAGADO SIN PARTIDA SALDA LOS PAPELES DE SU PROVEEDOR: dos recibos
--     a cuenta de un proveedor (800 del día 3 y 600 del 7) y un cheque por
--     el statement SIN partida (1,000, el 11): la antigüedad de pagar dice
--     UNA fila, la del proveedor, con 400 del recibo del 7 (lo más viejo que
--     sigue sin pagar, fecha del papel), sin los recibos sueltos ni un «a
--     favor» que el balance no tiene; cada cifra baja a sus líneas (lo suyo
--     sin papel y los dos recibos) y el total es el mayor. Con otro cheque
--     de 900, la fila es −500, a favor: lo mismo que el balance pasa al
--     activo por ese proveedor. Antes: los dos recibos abiertos (1,400) y un
--     «a favor» de −1,000 que el balance no tenía.
do $$
declare
  v_obt   text;
  v_esp   text;
  v_mes   text := nullif(current_setting('mx4.mes', true), '');
  v_d     date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a     text := nullif(current_setting('mx4.obra', true), '');
  v_dueno uuid := nullif(current_setting('mx4.dueno', true), '')::uuid;
  v_prov  uuid;
  v_uno   text;
  v_baj   text;
  v_af0   numeric;
  v_dos   text;
  v_af1   numeric;
  v_tot   text;
begin
  if v_d is null or v_a is null then
    insert into _pruebas values (92, 'lo pagado sin partida salda los papeles de su proveedor (y el a favor es el del balance)', '-',
                                 'omitida: falta el mes abierto o una obra', null);
    return;
  end if;
  v_esp := format('uno=proveedor:400.00:%s:papel:0-30 bajar=ok dos=proveedor:-500.00:a_favor balance=500.00 total=mayor', v_d + 6);
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_inmediato();
    v_prov := fn_proveedor_alta('C4 PRUEBAS PAGOS', 'Net 30', array['c4 pruebas pagos']);
    insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo,
                         metodo_pago, ultimos4) overriding system value values
      (-4410921, v_a, 'recibos/c4-pruebas/921.jpg', 800.00, 'C4 Pruebas Pagos', 'leido', v_dueno,
       ((v_d + 2) + time '12:00') at time zone 'America/New_York', v_d + 2, 'material', 'C4-PG-1', 'cuenta_proveedor', null),
      (-4410922, v_a, 'recibos/c4-pruebas/922.jpg', 600.00, 'C4 Pruebas Pagos', 'leido', v_dueno,
       ((v_d + 6) + time '12:00') at time zone 'America/New_York', v_d + 6, 'material', 'C4-PG-2', 'cuenta_proveedor', null);
    perform fn_postear(jsonb_build_object('fecha', (v_d + 10)::text, 'descripcion', 'c4-pruebas: cheque por el statement',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '1000.00',
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_prov),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-1000.00'))));
    select string_agg(format('%s:%s:%s:%s:%s', x.tipo, x.por_pagar, coalesce(x.fecha::text, '-'), coalesce(x.fecha_origen, '-'),
                             x.tramo), ' | ' order by x.tipo, x.partida_id)
      into v_uno
      from v_cxp_antiguedad x
     where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = v_prov;
    perform pg_temp.c4_bajar_preparar();
    v_baj := pg_temp.c4_revisar_bajar('v_cxp_antiguedad', v_mes);
    select coalesce(sum(b.cifra), 0) into v_af0 from v_balance_general b
     where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'reclasif_a_favor' and b.linea = 'saldos_a_favor';
    perform fn_postear(jsonb_build_object('fecha', (v_d + 12)::text, 'descripcion', 'c4-pruebas: otro cheque, de más',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '900.00',
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_prov),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-900.00'))));
    select string_agg(format('%s:%s:%s', x.tipo, x.por_pagar, x.tramo), ' | ' order by x.tipo, x.partida_id)
      into v_dos
      from v_cxp_antiguedad x
     where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = v_prov;
    select coalesce(sum(b.cifra), 0) into v_af1 from v_balance_general b
     where b.periodo = v_mes and b.nivel = 'componente' and b.componente = 'reclasif_a_favor' and b.linea = 'saldos_a_favor';
    select case when x.cuadra and x.total = x.mayor then 'total=mayor' else 'total=' || x.total || '≠' || x.mayor end
      into v_tot
      from v_cxp_antiguedad x where x.periodo = v_mes and x.nivel = 'total';
    v_obt := format('uno=%s bajar=%s dos=%s balance=%s %s', coalesce(v_uno, '(nada)'),
                    case when v_baj like 'filas=%' then 'ok' else v_baj end, coalesce(v_dos, '(nada)'), v_af1 - v_af0, v_tot);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (92, 'lo pagado sin partida salda los papeles de su proveedor (y el a favor es el del balance)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 93. EL CONTROL DEL PASIVO: una deuda mapeada a capital (la Amex 2009,
--     1,100, a 3100) no mueve la utilidad ni el activo, y antes pasaba en
--     verde con el pasivo 1,100 corto; ahora la apertura para (MX001) con
--     «Total Liabilities» y la fila que lo explica. Sin la fila «Total
--     Liabilities», no postea (MX001: la nombra). Con el mapeo bueno y las
--     filas opcionales (el capital, con la utilidad del año, y el pasivo más
--     capital) amarra, y dice sus cifras. Los nombres de las filas de
--     control se reconocen.
do $$
declare
  v_obt  text;
  v_esp  text := 'nombres=pasivo,capital,pasivo_capital deuda_a_capital=MX001:total_liabilities+amex_2009 '
                 'sin_pasivo=MX001:falta_total_liabilities con_capital=amarra:3750.00:53150.00:56900.00';
  v_doc  text := 'docs/c4-pruebas/qb-apertura-93.csv';
  v_x    text;
  v_y    text;
  v_z    text;
  v_plan jsonb;
begin
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (93, 'el control del pasivo: una deuda mapeada a capital no pasa la apertura', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb(v_doc);
    v_x := concat_ws(',', fn_apertura_control_qb('Total Liabilities'), fn_apertura_control_qb('Total Stockholders'' Equity'),
                     fn_apertura_control_qb('TOTAL LIABILITIES AND EQUITY'));
    perform fn_apertura_mapeo_qb('Credit Cards:Amex 2009', '3100');
    begin
      perform fn_apertura_plan(v_doc);
      v_y := 'amarra';
    exception when others then
      v_y := sqlstate || ':' || case when sqlerrm like '%(Total Liabilities)%'
                                          and sqlerrm like '%«Credit Cards:Amex 2009» (-1100.00) va a 3100, de capital%'
                                     then 'total_liabilities+amex_2009' else left(sqlerrm, 300) end;
    end;
    perform fn_apertura_mapeo_qb('Credit Cards:Amex 2009', '2100-2009');
    delete from apertura_balanza_qb b where b.documento = v_doc and b.control = 'pasivo';
    begin
      perform fn_apertura_plan(v_doc);
      v_z := 'amarra';
    exception when others then
      v_z := sqlstate || ':' || case when sqlerrm like '%(falta «Total Liabilities»)%' then 'falta_total_liabilities'
                                     else left(sqlerrm, 300) end;
    end;
    insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe, haber, control, cargado_rol)
    values (v_doc, 901, 'Total Liabilities', 0, 3750.00, 'pasivo', 'x'),
           (v_doc, 902, 'Total Stockholders'' Equity', 0, 53150.00, 'capital', 'x'),
           (v_doc, 903, 'TOTAL LIABILITIES AND EQUITY', 0, 56900.00, 'pasivo_capital', 'x');
    v_plan := fn_apertura_plan(v_doc);
    v_obt := format('nombres=%s deuda_a_capital=%s sin_pasivo=%s con_capital=amarra:%s:%s:%s', v_x, v_y, v_z,
                    v_plan->'control_qb'->>'pasivo', v_plan->'control_qb'->>'capital', v_plan->'control_qb'->>'pasivo_capital');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (93, 'el control del pasivo: una deuda mapeada a capital no pasa la apertura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 94. UNA FACTURA NO SE DEBE POR MÁS DE SU MONTO: la balanza de la
--     apertura trae de la factura C4-QB-6 (4,000 en la app) 4,000 y 600 más
--     en otra fila (otro cargo con su número): la apertura para (MX006) y
--     dice la factura, su monto, lo que trae la balanza y las filas. Antes
--     entraba, y en octubre c3 decía que la factura «está dos veces».
do $$
declare
  v_obt text;
  v_esp text := 'MX006:factura_C4-QB-6:4000.00:4600.00:filas';
  v_doc text := 'docs/c4-pruebas/qb-apertura-94.csv';
begin
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (94, 'una factura no entra a la apertura con más por cobrar que su monto', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb(v_doc, true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Accounts Receivable', 'debe', '600.00', 'factura_id', -4400006),
      jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '600.00')));
    begin
      perform fn_apertura_plan(v_doc);
      v_obt := 'amarra';
    exception when others then
      v_obt := sqlstate || ':' || case when sqlerrm like '%factura #C4-QB-6%es por 4000.00%trae 4600.00 por cobrar de ella (filas %'
                                       then 'factura_C4-QB-6:4000.00:4600.00:filas' else left(sqlerrm, 300) end;
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (94, 'una factura no entra a la apertura con más por cobrar que su monto', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 95. EL PROVEEDOR DEL ASIENTO, SOLO SI SU DEUDA EXPLICA EL ASIENTO: un
--     journal de nómina a mano (sueldos 3,000 y el seguro 300; 2,500 del
--     banco, 500 retenidos y 300 que se le deben a la aseguradora, en 2010 a
--     su nombre): en qué se gasta y a quién, los sueldos van sin proveedor y
--     el seguro a la aseguradora (por su línea del mismo monto). Antes la
--     aseguradora se llevaba también los 3,000 de sueldos.
do $$
declare
  v_obt  text;
  v_esp  text := 'sueldos=ninguno seguro=C4 PRUEBAS SEGUROS:asiento';
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_prov uuid;
  v_as   uuid;
begin
  if v_d is null then
    insert into _pruebas values (95, 'el proveedor del asiento solo si su deuda explica el asiento (el journal de nómina)', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    v_prov := fn_proveedor_alta('C4 PRUEBAS SEGUROS', 'Net 30', array['c4 pruebas seguros']);
    v_as := (fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: journal de nómina con el seguro',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6000', 'monto', '3000.00'),
                                  jsonb_build_object('cuenta', '6200', 'monto', '300.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-2500.00'),
                                  jsonb_build_object('cuenta', '2220', 'monto', '-500.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('cxp'), 'monto', '-300.00',
                                                     'tercero_tipo', 'proveedor', 'tercero_id', v_prov))))->>'id')::uuid;
    select format('sueldos=%s seguro=%s',
      (select coalesce(g.proveedor, 'ninguno') from v_gasto_lineas g where g.asiento_id = v_as and g.cuenta = '6000'),
      (select coalesce(g.proveedor, 'ninguno') || ':' || coalesce(g.proveedor_fuente, '-')
         from v_gasto_lineas g where g.asiento_id = v_as and g.cuenta = '6200'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (95, 'el proveedor del asiento solo si su deuda explica el asiento (el journal de nómina)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 96. SIN DINERO, LAS DOS PATAS DE UNA MISMA SECCIÓN NO SE ANULAN: el
--     préstamo del accionista convertido en capital (Dr 2900 / Cr 3100,
--     10,000: las dos de financiamiento) se revela: −10,000 en
--     financiamiento sin dinero y +10,000 en su contrapartida, en los dos
--     métodos; la porción corriente de un préstamo (Dr 2530 / Cr 2520,
--     5,000: el mismo préstamo) sigue sin revelarse (0.00); y el flujo
--     cuadra. Antes la conversión salía en 0.00 y no se veía.
do $$
declare
  v_obt  text;
  v_esp  text := 'conversion=sd_contrapartida:10000.00,sd_financiamiento:-10000.00|sd_contrapartida:10000.00,sd_financiamiento:-10000.00 '
                 'porcion=sd_financiamiento:0.00|sd_financiamiento:0.00 cuadra=t';
  v_mes  text := nullif(current_setting('mx4.mes', true), '');
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_conv uuid;
  v_porc uuid;
begin
  if v_d is null then
    insert into _pruebas values (96, 'sin dinero, las dos patas de una misma sección no se anulan', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    v_conv := (fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: el préstamo del accionista, a capital',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2900', 'monto', '10000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-10000.00'))))->>'id')::uuid;
    v_porc := (fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: la porción corriente del préstamo',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2530', 'monto', '5000.00'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-5000.00'))))->>'id')::uuid;
    select format('conversion=%s|%s porcion=%s|%s cuadra=%s',
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_directo as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_conv
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_indirecto as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_conv
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_directo as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_porc
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_indirecto as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_porc
                                                                     group by 1) y),
      (select case when bool_and(f.cuadra) then 't' else 'f' end from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (96, 'sin dinero, las dos patas de una misma sección no se anulan', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 97. LO QUE SE COBRA SIN FACTURA SE FECHA POR LO MÁS VIEJO QUE SIGUE SIN
--     COBRAR (FIFO): en una obra, un cargo a mano a cuentas por cobrar sin
--     factura el día 1 del mes (1,000), su cobro el 5 y otro cargo el 10 del
--     mes siguiente (500): al cierre del mes siguiente, la partida sin
--     factura dice 500 del día 10 (0-30), no del día 1 (31-60). Antes la
--     fechaba por su línea más vieja.
do $$
declare
  v_obt text;
  v_esp text;
  v_sig text := nullif(current_setting('mx4.sig', true), '');
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_b   text := nullif(current_setting('mx4.obra2', true), '');
  v_sd  date;
begin
  select p.desde into v_sd from periodos p where p.periodo = v_sig;
  if v_sd is null or v_b is null
     or exists (select 1 from asiento_lineas l where l.cuenta = fn_puente_cuenta_de('cxc') and l.proyecto_id = v_b
                   and l.partida_tabla is null) then
    insert into _pruebas values (97, 'lo que se cobra sin factura se fecha por lo más viejo sin cobrar (FIFO)', '-',
                                 'omitida: falta el mes siguiente u otra obra, o esa obra ya tiene saldos sin factura', null);
    return;
  end if;
  v_esp := format('fecha=%s tramo=0-30 por_cobrar=500.00', v_sd + 9);
  begin
    perform pg_temp.c4_fingir_hoy(v_sd + 10);
    perform fn_postear(jsonb_build_object('fecha', v_d::text, 'descripcion', 'c4-pruebas: un cargo sin factura',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxc'), 'monto', '1000.00', 'proyecto_id', v_b),
                                  jsonb_build_object('cuenta', '4900', 'monto', '-1000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (v_d + 4)::text, 'descripcion', 'c4-pruebas: su cobro, sin factura',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('cxc'), 'monto', '-1000.00', 'proyecto_id', v_b))));
    perform fn_postear(jsonb_build_object('fecha', (v_sd + 9)::text, 'descripcion', 'c4-pruebas: otro cargo sin factura',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('cxc'), 'monto', '500.00', 'proyecto_id', v_b),
                                  jsonb_build_object('cuenta', '4900', 'monto', '-500.00'))));
    select format('fecha=%s tramo=%s por_cobrar=%s', x.fecha, x.tramo, x.por_cobrar) into v_obt
      from v_cxc_antiguedad x
     where x.periodo = v_sig and x.nivel = 'partida' and x.tipo = 'sin_partida' and x.proyecto_id = v_b;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (97, 'lo que se cobra sin factura se fecha por lo más viejo sin cobrar (FIFO)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 98. LA RETENCIÓN NO VENCE POR TÉRMINOS: la retención por pagar que trae
--     la apertura de un subcontratista (700, en 2020, sin la fecha de su
--     factura en la balanza) sale en la antigüedad de pagar en el tramo
--     'retencion', sin fecha inventada (no el 30-sep), sin vencimiento y
--     sin días vencida, aunque el proveedor tenga términos (Net 30). Antes:
--     fechada el 30-sep, vencida a los 30 días.
do $$
declare
  v_obt  text;
  v_esp  text := 'retencion=700.00:retencion:fecha=-:vence=-:dias_vencida=-';
  v_ap   periodos;
  v_mes  text := nullif(current_setting('mx4.mes', true), '');
  v_prov uuid;
  v_doc  text := 'docs/c4-pruebas/qb-apertura-98.csv';
  v_ret  text;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select m.cuenta into v_ret from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'retencion_por_pagar' order by m.cuenta limit 1;
  if not pg_temp.c4_apertura_libre() or v_mes is null or v_ret is null then
    insert into _pruebas values (98, 'la retención por pagar de la apertura no vence por términos ni se fecha el 30-sep', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta el mes', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    v_prov := fn_proveedor_alta('C4 PRUEBAS SUB', 'Net 30', array['c4 pruebas sub']);
    perform fn_apertura_mapeo_qb('Retainage Payable', v_ret);
    perform pg_temp.c4_balanza_qb(v_doc, true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Retainage Payable', 'haber', '700.00', 'proveedor_qb', 'C4 Pruebas Sub',
                         'cliente_trabajo', 'C4 Pruebas, Cliente:Obra A'),
      jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'debe', '700.00')));
    perform fn_apertura(v_ap.desde, v_doc);
    select format('retencion=%s:%s:fecha=%s:vence=%s:dias_vencida=%s', x.retencion, x.tramo, coalesce(x.fecha::text, '-'),
                  coalesce(x.vence::text, '-'), coalesce(x.dias_vencida::text, '-'))
      into v_obt
      from v_cxp_antiguedad x
     where x.periodo = v_mes and x.nivel = 'partida' and x.proveedor_id = v_prov;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (98, 'la retención por pagar de la apertura no vence por términos ni se fecha el 30-sep', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 99. EL ADELANTO DE EFECTIVO DE LA TARJETA ES FINANCIAMIENTO: los 500 que
--     la tarjeta de prueba adelanta al banco entran en préstamos
--     (financiamiento), no en «pagos de tarjetas» (operación), en los dos
--     métodos; y su pago del día 21 sale de préstamos también (la cola de la
--     tarjeta). El flujo cuadra. Antes: operación, las dos veces.
do $$
declare
  v_obt text;
  v_esp text := 'adelanto=prestamos:500.00,tarjetas:0.00|fin_prestamos:500.00,op_tarjetas:0.00 '
                'pago=prestamos:-500.00,tarjetas:0.00|fin_prestamos:-500.00,op_tarjetas:0.00 cuadra=t';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_a1  uuid;
  v_a2  uuid;
begin
  if v_d is null then
    insert into _pruebas values (99, 'el adelanto de efectivo de la tarjeta es financiamiento (y su pago)', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    v_a1 := (fn_postear(jsonb_build_object('fecha', (v_d + 5)::text, 'descripcion', 'c4-pruebas: adelanto de efectivo de la tarjeta',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '500.00'),
                                  jsonb_build_object('cuenta', '2100-9998', 'monto', '-500.00'))))->>'id')::uuid;
    v_a2 := (fn_postear(jsonb_build_object('fecha', (v_d + 20)::text, 'descripcion', 'c4-pruebas: pago de la tarjeta',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9998', 'monto', '500.00'),
                                  jsonb_build_object('cuenta', fn_puente_cuenta_de('banco'), 'monto', '-500.00'))))->>'id')::uuid;
    select format('adelanto=%s|%s pago=%s|%s cuadra=%s',
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_directo as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_a1
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_indirecto as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_a1
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_directo as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_a2
                                                                     group by 1) y),
      (select string_agg(y.l || ':' || y.s, ',' order by y.l) from (select fl.linea_indirecto as l, sum(fl.importe) as s
                                                                      from v_flujo_lineas fl where fl.asiento_id = v_a2
                                                                     group by 1) y),
      (select case when bool_and(f.cuadra) then 't' else 'f' end from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (99, 'el adelanto de efectivo de la tarjeta es financiamiento (y su pago)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 100. LA CAJA CHICA EN ROJO NO ES UN SOBREGIRO: la 1050 (marcada caja)
--      con 200 menos de lo que tiene (un gasto pagado de la caja que no
--      tenía): el balance la pasa al pasivo en su renglón «Caja chica en
--      rojo…» (el sobregiro bancario no cambia), el flujo le da su renglón
--      de financiamiento en los dos métodos y el Panel su columna, los
--      saldos de dinero la dicen caja, los cuadres del flujo siguen en
--      verde, y el control la dice en rojo. Antes: «Sobregiro bancario».
do $$
declare
  v_obt  text;
  v_esp  text := 'marca=t balance=200.00 sobregiro=0.00 flujo=200.00,200.00 panel=200.00 saldos=caja cuadres=t control=f';
  v_mes  text := nullif(current_setting('mx4.mes', true), '');
  v_d    date := nullif(current_setting('mx4.desde', true), '')::date;
  v_h    date;
  v_s    numeric;
  v_so0  numeric;
begin
  select p.hasta into v_h from periodos p where p.periodo = v_mes;
  if v_d is null or not exists (select 1 from cuentas c where c.codigo = '1050' and c.imputable) then
    insert into _pruebas values (100, 'la caja chica en rojo no es un sobregiro: su renglón, su flujo y su rojo', v_esp,
                                 'omitida: falta el mes abierto o la 1050', null);
    return;
  end if;
  begin
    select coalesce(sum(l.monto), 0) into v_s from v_libro l where l.cuenta = '1050' and l.fecha <= v_h;
    select coalesce(sum(b.cifra), 0) into v_so0 from v_balance_general b
     where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'sobregiro_bancario';
    perform fn_postear(jsonb_build_object('fecha', (v_d + 3)::text, 'descripcion', 'c4-pruebas: gasto pagado de la caja chica',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', (greatest(v_s, 0) + 200)::text),
                                  jsonb_build_object('cuenta', '1050', 'monto', (-(greatest(v_s, 0) + 200))::text))));
    select format('marca=%s balance=%s sobregiro=%s flujo=%s panel=%s saldos=%s cuadres=%s control=%s',
      (select case when m.caja then 't' else 'f' end from v_estados_mapeo m where m.cuenta = '1050'),
      (select coalesce(sum(b.cifra), 0) from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'caja_en_rojo'),
      (select (coalesce(sum(b.cifra), 0) - v_so0)::numeric(14,2) from v_balance_general b
        where b.periodo = v_mes and b.nivel = 'linea' and b.linea = 'sobregiro_bancario'),
      (select string_agg(f.importe::text, ',' order by f.metodo) from v_flujo_caja f
        where f.periodo = v_mes and f.nivel = 'linea' and f.linea = 'caja_en_rojo'),
      (select r.caja_en_rojo from v_flujo_real_por_mes r where r.periodo = v_mes),
      (select s.tipo from v_saldos_dinero s where s.periodo = v_mes and s.cuenta = '1050'),
      (select case when bool_and(f.cuadra) then 't' else 'f' end from v_flujo_caja f where f.periodo = v_mes and f.nivel = 'control'),
      (select case when c.ok then 't' else 'f' end from fn_estados_control(v_mes, array['v_balance_general']) c
        where c.vista = 'cuadre: la caja chica no queda en rojo'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (100, 'la caja chica en rojo no es un sobregiro: su renglón, su flujo y su rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 101. LO AJENO QUE LEE LAS TABLAS DE c4, TAMBIÉN ESCONDIDO: una función
--      SECURITY DEFINER que la API puede ejecutar y que lee las diferencias
--      con un join de coma («from periodos p, diferencias d»), o con un
--      comentario en medio («from/**/diferencias»), o llamando a una función
--      de ayuda SECURITY INVOKER que lee estados_mapeo: cada una sale en rojo
--      en «protecciones de c4», con su nombre. Una que solo habla de las
--      diferencias en un comentario o en un texto, no. Antes las tres
--      pasaban en verde. (Van con lock_timeout de 2 s, como las otras que
--      tocan lo de c4.)
do $$
declare
  v_obt text := '';
  v_esp text := 'coma=f comentario=f anidada=f inocente=t';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_k   text;
  v_x   text;
begin
  if v_mes is null then
    insert into _pruebas values (101, 'lo ajeno que lee las tablas de c4, también escondido (coma, comentario, anidada)', v_esp,
                                 'omitida: falta el mes abierto', null);
    return;
  end if;
  foreach v_k in array array['coma', 'comentario', 'anidada', 'inocente'] loop
    begin
      perform set_config('lock_timeout', '2s', true);
      if v_k = 'coma' then
        execute $f$create function public.fn_c4p_ajena() returns bigint language sql security definer set search_path = public
                   as 'select count(*) from periodos p, diferencias d where d.periodo = p.periodo'$f$;
      elsif v_k = 'comentario' then
        execute $f$create function public.fn_c4p_ajena() returns bigint language sql security definer set search_path = public
                   as 'select count(*) from/**/diferencias'$f$;
      elsif v_k = 'anidada' then
        execute $f$create function public.fn_c4p_ayuda() returns bigint language sql set search_path = public
                   as 'select count(*) from estados_mapeo'$f$;
        execute $f$create function public.fn_c4p_ajena() returns bigint language sql security definer set search_path = public
                   as 'select fn_c4p_ayuda()'$f$;
      else
        execute $f$create function public.fn_c4p_ajena() returns bigint language plpgsql security definer set search_path = public
                   as $b$
                   begin
                     -- (una nota: select * from diferencias)
                     return length('las diferencias, anotadas');
                   end $b$ $f$;
      end if;
      select case when c.ok then 't' when c.detalle like '%fn_c4p_ajena()%' then 'f' else 'f:' || left(c.detalle, 120) end
        into v_x
        from fn_estados_control(v_mes, array['v_estados_mapeo']) c where c.vista = 'cuadre: protecciones de c4';
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when lock_not_available then v_x := 'omitida';
      when others then v_x := sqlstate || ' ' || left(sqlerrm, 60);
    end;
    v_obt := concat_ws(' ', nullif(v_obt, ''), v_k || '=' || coalesce(v_x, '-'));
  end loop;
  insert into _pruebas values (101, 'lo ajeno que lee las tablas de c4, también escondido (coma, comentario, anidada)', v_esp, v_obt,
                               case when v_obt like '%omitida%' then null else v_obt = v_esp end);
end $$;

-- 102. EL MX007 DE LA APERTURA DICE QUE SE DESHACE LA CORRIDA ENTERA, Y QUÉ
--      PEGAR JUNTO: posteada la apertura, se corrige un mapeo (Undeposited
--      Funds de 1010 a 1030) y fn_apertura sin motivo para (MX007): dice que
--      el error deshace la corrida entera, y trae la línea del mapeo que
--      cambió y el fn_apertura con su motivo, para pegarlos juntos. Con el
--      motivo y NADA que cambiar (el mapeo otra vez en 1010), para (MX007) y
--      dice por qué, en vez de un «sin_cambios» callado. Con otra balanza
--      (el proveedor de prueba con 100 más), cada cambio dice su proveedor
--      por su nombre, no solo su uuid. Y repetir el mismo fn_apertura con el
--      mismo motivo que ya sustituyó no hace nada (sin_cambios).
do $$
declare
  v_obt  text;
  v_esp  text := 'mapeo=MX007:corrida+bloque motivo_sin_cambios=MX007:nada_que_rehacer otra_balanza=MX007:proveedor_por_nombre '
                 'mismo_motivo=sustituida/sin_cambios';
  v_ap   periodos;
  v_d1   text := 'docs/c4-pruebas/qb-apertura-102.csv';
  v_d2   text := 'docs/c4-pruebas/qb-apertura-102b.csv';
  v_x    text;
  v_r1   jsonb;
  v_r2   jsonb;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (102, 'el MX007 de la apertura: la corrida entera, el bloque, el motivo sin cambios, el proveedor', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb(v_d1);
    perform fn_apertura(v_ap.desde, v_d1);
    perform fn_apertura_mapeo_qb('Undeposited Funds', '1030');
    begin
      perform fn_apertura(v_ap.desde, v_d1);
      v_x := 'posteada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%deshace la corrida ENTERA%'
                                          and sqlerrm like '%select fn_apertura_mapeo_qb(''Undeposited Funds'', ''1030''); select fn_apertura(%'
                                     then 'corrida+bloque' else left(sqlerrm, 300) end;
    end;
    v_obt := 'mapeo=' || v_x;
    perform fn_apertura_mapeo_qb('Undeposited Funds', '1010');
    begin
      perform fn_apertura(v_ap.desde, v_d1, 'c4-pruebas: el mapeo ya estaba bien');
      v_x := 'sin error';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%con el motivo no hay nada que rehacer%deshizo la corrida entera%'
                                     then 'nada_que_rehacer' else left(sqlerrm, 300) end;
    end;
    v_obt := v_obt || ' motivo_sin_cambios=' || v_x;
    perform pg_temp.c4_balanza_qb(v_d2, true, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '100.00', 'proveedor_qb', 'C4 Pruebas Supply Inc'),
      jsonb_build_object('cuenta_qb', 'Retained Earnings', 'debe', '100.00')));
    begin
      perform fn_apertura(v_ap.desde, v_d2);
      v_x := 'posteada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%2010%C4 PRUEBAS SUPPLY: -2500.00 → -2600.00%'
                                     then 'proveedor_por_nombre' else left(sqlerrm, 300) end;
    end;
    v_obt := v_obt || ' otra_balanza=' || v_x;
    v_r1 := fn_apertura(v_ap.desde, v_d2, 'c4-pruebas: QuickBooks corrigió al proveedor');
    v_r2 := fn_apertura(v_ap.desde, v_d2, 'c4-pruebas: QuickBooks corrigió al proveedor');
    v_obt := v_obt || ' mismo_motivo=' || (v_r1->>'accion') || '/' || (v_r2->>'accion');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (102, 'el MX007 de la apertura: la corrida entera, el bloque, el motivo sin cambios, el proveedor', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 103. c2 Y c3 AL DÍA: con la marca de un c2 anterior (fn_libro_version más
--      vieja) o una policy de c3 de la forma vieja (es_dueno() por fila, en
--      cobros), «protecciones de c4» sale en rojo y dice qué volver a pegar.
--      Antes el pegado decía que c2 y c3 «funcionan igual sin volver a
--      pegarlos», y nada lo miraba. (Con lock_timeout de 2 s.)
do $$
declare
  v_obt text := '';
  v_esp text := 'hoy=t c2_viejo=f:c2-libro.sql c3_policy=f:c3-puentes.sql';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_k   text;
  v_x   text;
begin
  if v_mes is null or to_regclass('public.cobros') is null then
    insert into _pruebas values (103, 'c2 y c3 al día: una versión vieja o una policy vieja salen en rojo', v_esp,
                                 'omitida: falta el mes abierto o c3', null);
    return;
  end if;
  foreach v_k in array array['hoy', 'c2_viejo', 'c3_policy'] loop
    begin
      perform set_config('lock_timeout', '2s', true);
      if v_k = 'c2_viejo' then
        execute $f$create or replace function public.fn_libro_version() returns bigint language sql immutable
                   set search_path = public, pg_temp as 'select 2026010101::bigint'$f$;
      elsif v_k = 'c3_policy' then
        execute 'alter policy cobros_dueno on public.cobros using (es_dueno())';
      end if;
      select case when c.ok then 't'
                  when v_k = 'c2_viejo' and c.detalle like '%fn_libro_version() es de una versión anterior%vuelve a pegar c2-libro.sql%'
                    then 'f:c2-libro.sql'
                  when v_k = 'c3_policy' and c.detalle like '%cobros lee con su policy de la forma vieja%vuelve a pegar c3-puentes.sql%'
                    then 'f:c3-puentes.sql'
                  else 'f:' || left(c.detalle, 150) end
        into v_x
        from fn_estados_control(v_mes, array['v_estados_mapeo']) c where c.vista = 'cuadre: protecciones de c4';
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when lock_not_available then v_x := 'omitida';
      when others then v_x := sqlstate || ' ' || left(sqlerrm, 60);
    end;
    v_obt := concat_ws(' ', nullif(v_obt, ''), v_k || '=' || coalesce(v_x, '-'));
  end loop;
  insert into _pruebas values (103, 'c2 y c3 al día: una versión vieja o una policy vieja salen en rojo', v_esp, v_obt,
                               case when v_obt like '%omitida%' then null else v_obt = v_esp end);
end $$;

-- 104. EL COMPLEMENTO POR OBRA Y LA CARGA EQUIVOCADA: con la balanza del mes
--      cargada (A), el «Profit and Loss by Customer» cargado como 'por_obra'
--      (P) no la desplaza ni avisa: v_comparacion sigue con A y
--      v_comparacion_obra usa P; otra balanza del mes (B) sí desplaza a A, y
--      lo avisa; retirada con su motivo, vuelve a valer A (B queda como
--      rastro, retirada), y el control cuenta las filas de las dos vigentes
--      (A y P). Antes P pasaba a ser «la vigente» (todas las cuentas de
--      balance en rojo) y una carga equivocada no se podía deshacer.
do $$
declare
  v_obt text;
  v_esp text := 'por_obra=sin_aviso comparacion=A obra=por_obra otra=aviso:A retirada=A:t control=t';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_a   text := nullif(current_setting('mx4.obra', true), '');
  v_p   jsonb;
  v_b   jsonb;
  v_da  text := 'docs/c4-pruebas/qb-104-a.csv';
  v_dp  text := 'docs/c4-pruebas/qb-104-p.csv';
  v_db  text := 'docs/c4-pruebas/qb-104-b.csv';
  v_c1  text;
  v_o   text;
  v_c2  text;
  v_ret text;
  v_ctl text;
begin
  if v_mes is null or v_a is null then
    insert into _pruebas values (104, 'el complemento por obra no desplaza a la balanza del mes; una carga equivocada se retira', v_esp,
                                 'omitida: falta el mes abierto o una obra', null);
    return;
  end if;
  begin
    perform fn_apertura_mapeo_qb('QB c4-104 banco', fn_puente_cuenta_de('banco'));
    perform fn_apertura_mapeo_qb('QB c4-104 otros', '4900');
    perform fn_apertura_mapeo_trabajo('C4 Pruebas 104:Obra', v_a);
    perform fn_comparacion_qb_cargar(v_mes, v_da, '[{"cuenta_qb": "QB c4-104 banco", "saldo": "100.00"}]');
    v_p := fn_comparacion_qb_cargar(v_mes, v_dp, '[{"cuenta_qb": "QB c4-104 otros", "cliente_trabajo": "C4 Pruebas 104:Obra", "saldo": "-50.00"}]',
                                    false, null, 'por_obra');
    select min(c.documento) into v_c1 from v_comparacion c where c.periodo = v_mes;
    select string_agg(distinct c.bajar->'qb'->0->'filtros'->>'tipo', ',') into v_o
      from v_comparacion_obra c where c.periodo = v_mes and c.cuenta = '4900' and c.proyecto_id = v_a;
    v_b := fn_comparacion_qb_cargar(v_mes, v_db, '[{"cuenta_qb": "QB c4-104 banco", "saldo": "120.00"}]');
    perform fn_comparacion_qb_retirar(v_mes, v_db, 'c4-pruebas: era la de otro mes');
    select min(c.documento) into v_c2 from v_comparacion c where c.periodo = v_mes;
    select case when bool_and(b.retirada) and not bool_or(b.vigente) then 't' else 'f' end into v_ret
      from v_qb_balanzas b where b.periodo = v_mes and b.documento = v_db;
    select case when c.ok then 't' else 'f:' || coalesce(c.detalle, '') end into v_ctl
      from fn_estados_control(v_mes, array['v_qb_balanzas']) c where c.vista = 'v_qb_balanzas';
    v_obt := format('por_obra=%s comparacion=%s obra=%s otra=%s retirada=%s:%s control=%s',
                    case when v_p ? 'aviso' or v_p ? 'desplaza' then 'aviso' else 'sin_aviso' end,
                    case v_c1 when v_da then 'A' when v_dp then 'P' else coalesce(v_c1, '-') end,
                    coalesce(v_o, '-'),
                    case when v_b->>'desplaza' = v_da and v_b->>'aviso' like '%desplaza%' || v_da || '%' then 'aviso:A'
                         else coalesce(v_b->>'aviso', 'sin_aviso') end,
                    case v_c2 when v_da then 'A' when v_db then 'B' else coalesce(v_c2, '-') end, v_ret, v_ctl);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (104, 'el complemento por obra no desplaza a la balanza del mes; una carga equivocada se retira', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 105. LA APERTURA CERRADA Y CORREGIDA CON UN AJUSTE DEL CPA AMARRA EN SU
--      COMPARACIÓN: con la apertura cerrada, lo que faltaba (100 que
--      QuickBooks corrigió en septiembre: un depósito) se corrige con un
--      ajuste a la apertura; cargada la balanza corregida de QuickBooks al
--      30-sep (la preliminar, sin p_con_posteriores), v_comparacion de la
--      apertura cuenta ese ajuste como posterior y queda sin nada sin
--      explicar. Antes la apertura no amarraba nunca: el ajuste no era del
--      30-sep. (Cierra la apertura: toma antes los candados.)
do $$
declare
  v_obt text;
  v_esp text := 'posteriores=1010:100.00,3900:-100.00 sin_explicar=0';
  v_ap  periodos;
  v_d   date := nullif(current_setting('mx4.desde', true), '')::date;
  v_doc text := 'docs/c4-pruebas/qb-apertura-105.csv';
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if not pg_temp.c4_apertura_libre() or v_d is null then
    insert into _pruebas values (105, 'la apertura cerrada y corregida con un ajuste del CPA amarra en su comparación', v_esp,
                                 'omitida: la apertura ya tiene su asiento (o está cerrada), o falta el mes', null);
    return;
  end if;
  begin
    perform pg_temp.c4_candados_recibos();
    lock table public.periodos in exclusive mode;
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb(v_doc);
    perform fn_apertura(v_ap.desde, v_doc);
    perform pg_temp.c4_cerrar_hasta(v_ap.periodo);
    perform pg_temp.c4_fingir_hoy(v_d + 5);
    perform fn_postear(jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_ap.periodo, 'fecha', (v_d + 2)::text,
      'motivo', 'c4-pruebas: el depósito que QuickBooks corrigió en septiembre', 'descripcion', 'c4-pruebas: ajuste a la apertura',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-100.00'))));
    perform pg_temp.c4_qb_del_libro(v_ap.periodo, 'docs/c4-pruebas/qb-105-corregida.csv', '{"1010": 100, "3900": -100}');
    select format('posteriores=%s sin_explicar=%s',
      (select string_agg(c.cuenta || ':' || c.posteriores, ',' order by c.cuenta) from v_comparacion c
        where c.periodo = v_ap.periodo and c.posteriores <> 0),
      (select count(*) from v_comparacion c where c.periodo = v_ap.periodo and not c.ok))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (105, 'la apertura cerrada y corregida con un ajuste del CPA amarra en su comparación', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 106. LA AMEX 1007 ES LA 2100-2013: mapear «Credit Cards:Amex 1007» a una
--      2100-1007 que no existe para (MX004) y dice cuál es: la 2100-2013,
--      cuyas notas dicen que QuickBooks la nombra 1007, con el select para
--      mapearla; no manda a crear otra tarjeta en c1. Antes decía «añádela
--      antes en c1» (y las pruebas la creaban).
do $$
declare
  v_obt text;
  v_esp text := 'MX004:2100-2013+select';
begin
  begin
    perform fn_apertura_mapeo_qb('Credit Cards:Amex 1007', '2100-1007');
    v_obt := 'mapeada';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then
      v_obt := sqlstate || ':' || case when sqlerrm like '%¿Es la 2100-2013?%'
                                            and sqlerrm like '%select fn_apertura_mapeo_qb(''Credit Cards:Amex 1007'', ''2100-2013'');%'
                                            and sqlerrm not like '%añádela antes en c1%'
                                       then '2100-2013+select' else left(sqlerrm, 200) end;
  end;
  insert into _pruebas values (106, 'la Amex 1007 de QuickBooks es la 2100-2013: el mapeo lo dice', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 107. EN LAS FILAS DE CONTROL, «saldo» ES LA CIFRA COMO LA PRESENTA
--      QUICKBOOKS: cargadas con saldo, todas en positivo (Net Income 38,050,
--      TOTAL ASSETS 56,900, Total Liabilities 3,750, Total Stockholders'
--      Equity 53,150 y TOTAL LIABILITIES AND EQUITY 56,900), la apertura
--      amarra; y un Net Income dado en el debe (el signo al revés) para
--      (MX001) diciendo que es el signo de esa fila, no el mapeo. Antes el
--      Net Income dado como saldo entraba como pérdida, y MX001 culpaba al
--      mapeo.
do $$
declare
  v_obt  text;
  v_esp  text := 'saldo=amarra:38050.00:56900.00:3750.00:53150.00:56900.00 al_reves=MX001:signo_net_income';
  v_plan jsonb;
  v_x    text;
begin
  if not pg_temp.c4_apertura_libre() then
    insert into _pruebas values (107, 'en las filas de control, saldo es la cifra como la presenta QuickBooks (y el signo al revés)',
                                 v_esp, 'omitida: la apertura ya tiene su asiento (o está cerrada)', null);
    return;
  end if;
  begin
    perform pg_temp.c4_montar();
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-107-mapeo.csv');
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-107.csv', false, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Net Income', 'saldo', '38,050.00'),
      jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'saldo', '56,900.00'),
      jsonb_build_object('cuenta_qb', 'Total Liabilities', 'saldo', '3,750.00'),
      jsonb_build_object('cuenta_qb', 'Total Stockholders'' Equity', 'saldo', '53,150.00'),
      jsonb_build_object('cuenta_qb', 'TOTAL LIABILITIES AND EQUITY', 'saldo', '56,900.00')));
    begin
      v_plan := fn_apertura_plan('docs/c4-pruebas/qb-apertura-107.csv');
      v_obt := 'saldo=amarra:' || concat_ws(':', v_plan->'control_qb'->>'utilidad', v_plan->'control_qb'->>'activo',
                                            v_plan->'control_qb'->>'pasivo', v_plan->'control_qb'->>'capital',
                                            v_plan->'control_qb'->>'pasivo_capital');
    exception when others then
      v_obt := 'saldo=' || sqlstate || ':' || left(sqlerrm, 200);
    end;
    perform pg_temp.c4_balanza_qb('docs/c4-pruebas/qb-apertura-107b.csv', false, jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'Net Income', 'debe', '38,050.00'),
      jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'debe', '56,900.00'),
      jsonb_build_object('cuenta_qb', 'Total Liabilities', 'haber', '3,750.00')));
    begin
      perform fn_apertura_plan('docs/c4-pruebas/qb-apertura-107b.csv');
      v_x := 'amarra';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%justo lo contrario que el mapeo en «Net Income»%el signo de esa fila de control%'
                                     then 'signo_net_income' else left(sqlerrm, 300) end;
    end;
    v_obt := v_obt || ' al_reves=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (107, 'en las filas de control, saldo es la cifra como la presenta QuickBooks (y el signo al revés)',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 108. ANOTAR DOS VECES LA MISMA DIFERENCIA NO LA DUPLICA: la segunda
--      devuelve el mismo id y en la tabla queda una; otra con otro monto sí
--      entra. Antes la segunda entraba, y la cuenta quedaba en rojo por lo
--      explicado de más.
do $$
declare
  v_obt text;
  v_esp text := 'mismo_id=t filas=1 otra=nueva';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
  v_i1  uuid;
  v_i2  uuid;
  v_i3  uuid;
begin
  if v_mes is null then
    insert into _pruebas values (108, 'anotar dos veces la misma diferencia no la duplica', v_esp, 'omitida: falta el mes abierto', null);
    return;
  end if;
  begin
    v_i1 := fn_diferencia_anotar(v_mes, '6100', '25.00', 'puente', 'c4-pruebas: la renta que QuickBooks tiene en otro mes');
    v_i2 := fn_diferencia_anotar(v_mes, '6100', '25.00', 'puente', 'c4-pruebas: la renta que QuickBooks tiene en otro mes');
    v_i3 := fn_diferencia_anotar(v_mes, '6100', '30.00', 'puente', 'c4-pruebas: la renta que QuickBooks tiene en otro mes');
    v_obt := format('mismo_id=%s filas=%s otra=%s', case when v_i1 = v_i2 then 't' else 'f' end,
                    (select count(*) from diferencias d
                      where d.periodo = v_mes and d.cuenta = '6100' and d.monto = 25.00
                        and d.explicacion = 'c4-pruebas: la renta que QuickBooks tiene en otro mes'),
                    case when v_i3 is distinct from v_i1 then 'nueva' else 'misma' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (108, 'anotar dos veces la misma diferencia no la duplica', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 109. MAINTAIN TAMBIÉN SE VE (Postgres 17): con «grant maintain» sobre una
--      tabla de c4 a authenticated (el «grant all» de Supabase lo incluye en
--      17: VACUUM FULL, REINDEX, CLUSTER desde la API), «protecciones de c4»
--      sale en rojo y lo dice. Antes miraba una lista fija de privilegios,
--      sin MAINTAIN. En Postgres 16 no existe: omitida. (Con lock_timeout
--      de 2 s.)
do $$
declare
  v_obt text;
  v_esp text := 'maintain=f:estados_mapeo:MAINTAIN';
  v_mes text := nullif(current_setting('mx4.mes', true), '');
begin
  if current_setting('server_version_num')::int < 170000 or v_mes is null then
    insert into _pruebas values (109, 'el privilegio MAINTAIN (Postgres 17) sobre una tabla de c4 sale en rojo', v_esp,
                                 'omitida: MAINTAIN es de Postgres 17 (o falta el mes abierto)', null);
    return;
  end if;
  begin
    perform set_config('lock_timeout', '2s', true);
    execute 'grant maintain on public.estados_mapeo to authenticated';
    select 'maintain=' || case when c.ok then 't'
                               when c.detalle like '%tabla estados_mapeo: authenticated puede MAINTAIN%' then 'f:estados_mapeo:MAINTAIN'
                               else 'f:' || left(c.detalle, 150) end
      into v_obt
      from fn_estados_control(v_mes, array['v_estados_mapeo']) c where c.vista = 'cuadre: protecciones de c4';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (109, 'el privilegio MAINTAIN (Postgres 17) sobre una tabla de c4 sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 110. NO DEJA RASTRO: todo lo de arriba se deshizo. El libro, los papeles,
--      las tablas de c4 y su historial, las reglas, los contadores, las
--      secuencias de la app, las huellas y la definición de cada vista y
--      función de c4 están como al empezar. Va la última.
do $$
declare
  v_antes text := current_setting('mx4.foto', true);
  v_ahora text;
begin
  v_ahora := pg_temp.c4_foto();
  insert into _pruebas values (110, 'no deja rastro: todo como al empezar', v_antes, v_ahora, v_ahora = v_antes);
end $$;

reset jit;

select * from _pruebas order by n;
