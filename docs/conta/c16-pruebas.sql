-- =====================================================================
-- c16-pruebas.sql — el tablero de la portada se prueba a sí mismo
-- (c16-tablero.sql). 14-nov-2026, Fase 11c (la marca 2026111403: EL TABLERO
-- APRENDE LA NÓMINA de Gusto —c15—: su tarjeta, su acción rápida, lo que
-- pide atender y la proyección de la caja; de la 51 a la 61, y la 1, la 3,
-- la 5, la 7, la 15, la 30 a la 35, la 44, la 45 y la 50, puestas al día; y
-- los arreglos de su verificación, de la 62 a la 65: «LO QUE CAMBIÓ EL
-- 14-NOV», abajo). (El 13-nov, la marca 2026111303: los
-- arreglos de las dos revisiones, cada uno con su prueba, de la 36 a la 43,
-- y los de la revisión final, de la 46 a la 50.)
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c16-tablero.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 65 filas, todas
-- con ok = true (las que salen «omitida» dicen por qué y no son un fallo;
-- una fila 99 solo sale si algo de este archivo falló). Si el editor se
-- cansa antes del final, la corrida sigue en el servidor y se lee después
-- en pruebas.c16_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c15 y c16-tablero.sql; sin c15 corre igual: lo de la nómina sale
-- «omitida», menos la 58):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c16-pruebas.sql
--
-- QUÉ PRUEBA. Que CADA NÚMERO de cada tarjeta es el que dice el libro: cada
-- uno se compara, al centavo, con una consulta independiente (escrita aquí,
-- sin usar nada de c16) al libro o a la vista de la capa que ya lo sabe (las
-- partidas abiertas de las cuentas por cobrar y por pagar, v_resultados,
-- v_banco_saldos, v_flujo_real_por_mes, v_prestamos, v_dr15_mes,
-- v_stripe_estado, fn_wip_resumen, v_margen_obra…). Los bordes (una factura
-- que vence hoy, una cobrada a medias, un mes sin movimientos, el primer mes
-- del libro, un cambio de año), una capa que falta, una tarjeta que falla
-- sola, el tope por reloj, lo mal pedido, la API (el equipo, anon y
-- service_role sin ver nada), que solo lee, que sus textos no nombran
-- funciones, que las demás capas siguen como estaban y que nada queda.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN: lo que comparan
-- es lo que hay en la base ese día, sea lo que sea. Lo que siembran los
-- bordes es suyo y se deshace (MXT00): DOS OBRAS («C16 PRUEBA Obra A» y «B»,
-- ids c16-prueba-a y b), sus facturas por el puente de c3 (ids negativos,
-- −1600001…: no gastan la secuencia), un cobro, dos gastos a mano
-- («C16 PRUEBA…», montos raros) y, donde hace falta, el reloj fingido DENTRO
-- de su subtransacción (el de c2-pruebas: «hoy» pasa a ser otro día). Al
-- final el archivo comprueba que el reloj quedó como estaba (si no, lo
-- restaura y sale un fallo, la fila 99) y que nada quedó.
-- LO DE LA NÓMINA (de la 52 a la 60, y de la 62 a la 65) siembra, también dentro de su bloque
-- que se deshace: tres personas inventadas («ZZ C16 Prueba Uno», «Dos» y
-- «Tres»: su usuario y su perfil), la configuración y el mapeo de columnas
-- de la nómina como de fábrica mientras dura la prueba (como c15-pruebas),
-- sus journals de prueba por el camino de c15 (importar, enlazar, postear)
-- y, por el banco (c6), unos cargos de Gusto («… C16 PRUEBA», con
-- identificadores «ZZ0000000n»). Nada de eso es de nadie y nada queda.
-- Las capas que no estén en la base (c6, c7, p1, c8, c9, c10, c11, c12,
-- c15) hacen que su tarjeta diga que no está: lo que necesita una de ellas
-- sale «omitida» con su porqué, y lo demás se prueba igual.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10, c11, c12, c14, c15) se
-- comparan con cómo estaban SIN c16 (dentro de un bloque que lo quita y se
-- deshace): lo que ya estaba en rojo se dice y no se cuenta.
--
-- LO QUE CAMBIÓ EL 14-NOV (Fase 11c), y por qué:
--  · NUEVAS, de la 51 a la 61: la tarjeta de la nómina contra el libro
--    crudo y las tablas y vistas de c15, con el código del teléfono y sin él
--    (el dueño con aal2 y con aal1, como c15-pruebas), una nómina de una
--    sola persona y los dos criterios de la decisión de seguridad, una
--    importada sin postear, los cargos de Gusto, la proyección, sin c15, el
--    equipo, sus textos, y qué pasa si lo de la nómina no se deja leer.
--  · PUESTAS AL DÍA: la 1 (la marca), la 3 (las funciones nuevas, en la
--    API), la 5 (16 tarjetas; la de la nómina dice que c15 falta si no
--    está), la 7 (la acción «Nómina»), la 15 (con c15 la proyección resta
--    lo que se debe de la nómina y ya no lo lista en «no incluye»; sin c15,
--    como antes), la 30, la 31 y la 32 (16 tarjetas), la 33 (los meses de
--    la nómina fuera de rango), la 34 (las funciones nuevas tampoco
--    escriben), la 35 (lo que mira, ahora en una función que usan también
--    las nuevas), la 44 (los cuadres de c15 entre los ajenos), la 45 (las
--    tablas de la nómina y los usuarios de prueba, en la huella) y la 50
--    (con c15 esa deuda va EN la proyección; sin c15, como antes).
--  · LOS ARREGLOS DE LA VERIFICACIÓN (marca 2026111403), cada uno con su
--    prueba, que falla con el c16 de antes y pasa con el de hoy:
--      – CUÁNDO SALE LO QUE SE DEBE (la 62, y la 57 con su cuenta rehecha):
--        lo que Gusto ya cobró se le quita a la nómina que PAGÓ, no a lo
--        más viejo de la cuenta. La cuenta independiente de aquí
--        (c16_nom_pagos) ya no repite el método de c16: usa lo que la
--        nómina (c15) sabe —lo que le QUEDA a cada corrida, por las partes
--        de sus cargos casados—, que c16 no lee (lee solo el libro). Con
--        el método de antes, la 57 daba por bueno el mismo error.
--      – LO QUE NO ES DE LA NÓMINA DE GUSTO (la 63): las vacaciones
--        devengadas (2215) no cuentan en lo que se debe de la nómina ni se
--        restan de la caja; van aparte, y la proyección las sigue listando
--        en lo que no incluye.
--      – LO LIGERO (la 64): la portada ya no arma la propuesta de cada
--        cargo de Gusto ni corre los avisos de la nómina; «control» trae
--        los cuadres en rojo y los que sin el código no se pueden
--        comprobar (ya no «avisos»: la 51 a la 56, al día).
--      – GASTOS, LO TAPADO, UNA VEZ (la 65).
--      – LA 10, EL ÚLTIMO DÍA DE UN MES más corto que el anterior (el 30 de
--        noviembre): el mes ya va entero y se compara con el mes pasado
--        ENTERO (del 1 al 31 de octubre), como hace la tarjeta; la prueba
--        esperaba «del 1 al 30» y daba un rojo falso ese día. Ya estaba en
--        la v305; la capa no cambia.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado: precondiciones, las funciones por su firma exacta, cada una
--    con su comentario «c16: …», ninguna tabla ni vista, y su tabla final;
--  2 las precondiciones en rojo (una vista de c4 que falta; una función
--    ajena con nombre de c16) y la guarda MX000;
--  3 la API: anon y service_role no ejecutan nada; el equipo, 42501 en cada
--    tarjeta; el dueño entra; el pegado y las precondiciones, sin API;
--  4 el catálogo: nada SECURITY DEFINER, todas con search_path, ninguna
--    volátil (no pueden escribir), solo nombres fn_tablero_*, y «permisos»
--    de c2 en verde con c16 puesto;
--  5 el tablero entero: las 16 tarjetas, en su orden, todas contestan (o
--    dicen qué capa falta), el libro en llano y las capas;
--  6 rápido: una pasada como el dueño por la API, con el tope de fábrica;
-- CADA TARJETA CONTRA EL LIBRO, al centavo:
--  7 acciones rápidas;   8 el embudo de cobro;   9 bancos y tarjetas;
-- 10 resultados de este mes; 11 del mes pasado (y contra v_resultados);
-- 12 del año (y contra v_resultados); 13 gastos de 30 días (sin el WIP);
-- 14 caja: los meses y hoy; 15 caja: la proyección (con la línea que dice
--    que no es la caja que va a haber); 16 facturas;
-- 17 ventas (sin el WIP); 18 por cobrar; 19 por pagar; 20 conexiones (un
--    banco que no trae nada en dos días, con problemas);
-- 21 cobros en línea; 22 use tax; 23 préstamos (la próxima cuota de cada
--    uno y la de un préstamo semanal de prueba); 24 obras;
-- LOS BORDES:
-- 25 una factura que vence HOY (corriente) y mañana (vencida);
-- 26 una factura cobrada A MEDIAS;
-- 27 un MES SIN MOVIMIENTOS (con el reloj en el mes que sigue al que viene);
-- 28 el PRIMER MES del libro;
-- 29 un CAMBIO DE AÑO (con el reloj en enero);
-- LO QUE NO DEBE TUMBAR NADA:
-- 30 una capa que falta: su tarjeta lo dice, las demás siguen;
-- 31 una tarjeta que falla (sin permiso de leer la antigüedad de c4): las
--    cuatro que la usan lo dicen, con 42501, y las demás siguen;
-- 32 el tope por reloj: lo que no alcanzó sale en «sigue» y se pide otra
--    vez;
-- 33 lo mal pedido: 22023 y 22007;
-- 34 solo lee: ni una fila escrita al pedir el tablero y cada tarjeta;
-- 35 los textos en llano: ninguno nombra una función ni una vista, ni dice
--    un código en mayúsculas, una fecha AAAA-MM-DD, «cargo(s)», un texto
--    cortado, «ráfaga» ni «partidas»;
-- LO QUE ENCONTRARON LOS REVISORES (cada arreglo, con su prueba):
-- 36 el saldo del banco de otro día: dice de qué día es y la diferencia es
--    la del mismo día;
-- 37 el cheque posfechado: no va en el saldo de hoy (bancos y caja dicen lo
--    mismo) y la proyección lo resta en su mes;
-- 38 «llegó su ticket»: el gasto dos veces; el tablero lo cuenta como la
--    Bandeja y los gastos dicen que van de más;
-- 39 el reembolso de un cobro de Stripe ya depositado: sigue depositado; lo
--    devuelto es el reembolso;
-- 40 Stripe sin la ventana de 120 días de v_stripe_pagos;
-- 41 la caja sin la apertura en el libro: lo dice, sin alarma falsa ni
--    proyección;
-- 42 el reverso del WIP del día 1 va aparte en el mes que no tiene su
--    ajuste; las ventas, sin el WIP;
-- 43 los enlaces: la Bandeja entera (sin el filtro de antes) y el DR-15;
-- LO QUE ENCONTRÓ LA REVISIÓN FINAL (corren antes del cierre; van con su
-- número después del 45):
-- 46 la caja: el mes en curso es hasta hoy (lo de después de hoy, aparte);
-- 47 bancos: lo que dice el banco se suma solo si es del mismo día;
-- 48 lo devuelto de un cobro de antes: no se resta de lo cobrado (aparte);
-- 49 Stripe: lo que queda de un pago de antes reembolsado hoy no es cobrado
--    de estos días;
-- 50 la proyección y la deuda de la nómina con todo lo que el libro tiene
--    (también lo fechado después de hoy): sin c15, en «no incluye»; con
--    c15, restada en la proyección, y sin restar dos veces;
-- LA NÓMINA DE GUSTO EN LA PORTADA (14-nov, Fase 11c; corren antes del
-- cierre):
-- 51 la tarjeta de la nómina, como está la base, con el código: cada cifra
--    contra el libro crudo y las tablas de c15;
-- 52 una nómina de tres personas, posteada: la última, con sus totales;
-- 53 la misma, SIN EL CÓDIGO (aal1): solo lo de la empresa; de la nómina,
--    «con el código del teléfono», nunca un cero;
-- 54 los cargos de Gusto: esperan con su enlace; casados, la proyección no
--    los resta otra vez; una devolución;
-- 55 una nómina de UNA SOLA PERSONA y los dos criterios de la decisión de
--    seguridad («libro», el de fábrica, y «codigo»), con y sin el código;
-- 56 una nómina importada sin postear (con el código, cuántas; sin él, «no
--    se sabe»);
-- 57 la proyección de la caja con la nómina, paso a paso;
-- 58 sin c15: todo como antes;
-- 59 el equipo y los de fuera, con una nómina en la base: 42501;
-- 60 la nómina, en llano y sin el nombre de nadie;
-- 61 si lo de la nómina no se deja leer: su tarjeta lo dice, lo demás sigue;
-- LOS ARREGLOS DE LA VERIFICACIÓN DE LA FASE 11c (corren antes del cierre):
-- 62 lo que Gusto ya cobró se le quita a la nómina que pagó: el cheque de
--    papel de la nómina pasada, sin cobrar, sale HOY, y lo que le queda a la
--    que viene, su día de pago;
-- 63 lo que no es de la nómina de Gusto (las vacaciones devengadas) no va en
--    lo que se debe de la nómina ni se resta de la caja: va aparte;
-- 64 la portada no arma la propuesta de ningún cargo de Gusto ni corre los
--    avisos de la nómina (lo ligero de c15);
-- 65 en Gastos, lo que se tapa sin el código se dice una vez;
-- Y el cierre de la suite:
-- 44 las demás capas como estaban sin c16 (lo que ya estaba en rojo se dice
--    y no cuenta);
-- 45 nada queda, y el reloj es el de verdad.
-- Última sentencia: select * from _pruebas order by n;
--
-- NO FRENA A LA APP: lo primero que hace es poner lock_timeout a MEDIO
-- SEGUNDO para toda la corrida, como el pegado. Las pruebas 2, 30, 31, 40,
-- 58 y 61 renombran o quitan el permiso de una vista o una tabla ajena, y la
-- 64 y la 65 rehacen un instante una función (de c15 y de esta capa)
-- DENTRO de un bloque que se deshace (la 58 y la 61, de la nómina de c15:
-- su vista de las nóminas y su tabla de archivos): si la app la
-- tiene tomada y no la suelta en medio segundo, esa prueba sale «omitida»
-- (no es un fallo: se vuelve a pegar en un momento más tranquilo). Las de
-- la nómina (52 a 60) escriben por las puertas de c15 y de c6 dentro de su
-- bloque, como las de esas capas: lo que toman lo sueltan al deshacerse.
-- =====================================================================
-- (Dura lo que dura la corrida, una transacción.)
set local lock_timeout = '500ms';

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, hoy, el libro, el mes de las pruebas, las capas.
create temp table if not exists _c16 (k text primary key, v text);
truncate _c16;
insert into _c16 select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c16 select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c16 values ('hoy', fn_fecha_miami(now())::text);
insert into _c16 values ('libro_desde', coalesce((select pa.hasta + 1 from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                                                 (select min(pm.desde) from periodos pm))::text);
-- el mes de las pruebas: el mes abierto de hoy (donde se siembran los bordes)
insert into _c16
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta;
insert into _c16 values ('capas', fn_tablero_capas()::text);
-- (los términos de Facturas → Ajustes, de c11; sin c11, 0. Por EXECUTE: en una base sin c11 la tabla no existe)
do $$
declare
  v int := 0;
begin
  if to_regclass('public.emision_config') is not null then
    execute 'select coalesce((select c.terminos_dias from public.emision_config c where c.id = 1), 0)' into v;
  end if;
  insert into _c16 values ('terminos', v::text);
end $$;
insert into _c16 select 'reloj_def', pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure);
-- (14-nov, Fase 11c) LA NÓMINA DE GUSTO (c15) en las pruebas: la cuenta del banco, si el banco (c6) puede traer un cargo de Gusto,
-- los perfiles de las tres personas de prueba (se siembran y se deshacen) y un día de pago DESPUÉS de hoy dentro de un mes
-- abierto (mañana; si hoy es el último día de su mes, mañana solo si el mes que sigue está abierto: si no, nulo).
insert into _c16 select 'banco', pc.cuenta from puente_cuentas pc where pc.rol = 'banco';
-- (si la nómina de c15 está en esta base, mirado AQUÍ —sus tablas, sus vistas y su puerta de importar—, sin preguntárselo a c16:
--  lo que c16 dice de sus capas se compara con esto, la 51 y la 58)
insert into _c16 values ('hay_c15', (to_regclass('public.nomina_corridas') is not null and to_regclass('public.nomina_archivos') is not null
                                     and to_regclass('public.v_nomina_corridas') is not null and to_regclass('public.v_nomina_control') is not null
                                     and to_regprocedure('public.fn_nomina_importar(jsonb,jsonb)') is not null)::text);
insert into _c16 values ('hay_banco', (to_regclass('public.movimientos_banco') is not null and to_regproc('public.fn_banco_importar_filas') is not null
                                       and to_regproc('public.fn_banco_casar') is not null
                                       and exists (select 1 from puente_cuentas pc where pc.rol = 'banco'))::text);
insert into _c16 values ('n1', gen_random_uuid()::text), ('n2', gen_random_uuid()::text), ('n3', gen_random_uuid()::text);
insert into _c16
select 'pago_despues', (fn_fecha_miami(now()) + 1)::text
  from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) + 1 between p.desde and p.hasta
   and exists (select 1 from _c16 m where m.k = 'mes');
grant select on _c16 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9, c10, c12
-- y c14), y ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c16(k text) returns text language sql as $$ select v from _c16 where k = $1 $$;
create or replace function pg_temp.c16_capa(k text) returns boolean language sql as $$ select coalesce((pg_temp.c16('capas')::jsonb ->> k)::boolean, false) $$;
create or replace function pg_temp.c16_hoy() returns date language sql as $$ select fn_fecha_miami(now()) $$;
create or replace function pg_temp.c16_hay_c15() returns boolean language sql as $$ select coalesce(pg_temp.c16('hay_c15') = 'true', false) $$;
-- (un monto como texto con sus dos decimales, para comparar al centavo; nulo = «—»)
create or replace function pg_temp.c16_m(p numeric) returns text language sql immutable as $$ select coalesce(round(p, 2)::numeric(14,2)::text, '—') $$;
create or replace function pg_temp.c16_mj(p jsonb) returns text language sql immutable as $$
  select case when p is null or jsonb_typeof(p) = 'null' then '—' else round((p #>> '{}')::numeric, 2)::numeric(14,2)::text end
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, con su código: aal2), el dueño SIN su
-- código (dueno_aal1: entró solo con la contraseña; 14-nov, como
-- c15-pruebas), anon o service_role.
create or replace function pg_temp.c16_ser(quien text) returns void language plpgsql as $$
declare
  v_id text := pg_temp.c16(case when quien = 'dueno_aal1' then 'dueno' else quien end);
begin
  execute 'reset role';
  if quien = 'editor' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien in ('service_role', 'anon') then
    perform set_config('request.jwt.claims', json_build_object('role', quien)::text, true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute format('set local role %I', quien);
  else
    perform set_config('request.jwt.claims',
                       json_build_object('sub', v_id, 'role', 'authenticated',
                                         'aal', case when quien = 'dueno_aal1' then 'aal1' else 'aal2' end)::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(v_id, ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Lo que contesta una orden: 'ok' o su código de error. Como quien se diga;
-- al volver, el SQL Editor.
create or replace function pg_temp.c16_estado(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c16_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate;
  end;
  perform pg_temp.c16_ser('editor');
  return v;
end $$;
-- Lo que devuelve una orden (un jsonb), como el dueño (o quien se diga). Si
-- falla, falla con su código y su mensaje: la prueba lo dice.
create or replace function pg_temp.c16_j(p_sql text, p_quien text default 'dueno') returns jsonb language plpgsql as $$
declare
  v jsonb; e text; c text;
begin
  perform pg_temp.c16_ser(p_quien);
  begin
    execute p_sql into v;
  exception when others then
    e := sqlerrm; c := sqlstate;
  end;
  perform pg_temp.c16_ser('editor');
  if c is not null then
    raise exception using errcode = c, message = e;
  end if;
  return v;
end $$;
-- EL TABLERO, como el dueño por la API (sin tope por reloj, salvo que se pida).
create or replace function pg_temp.c16_t(p jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select pg_temp.c16_j(format('select public.fn_tablero(%L::jsonb)',
                              (case when p ? 'tope_ms' then p else p || '{"tope_ms": 0}'::jsonb end)::text))
$$;

-- EL RELOJ FINGIDO (el de c2-pruebas, c12-pruebas y c14-pruebas): «hoy» pasa
-- a ser esa fecha (o el hoy de verdad, si es posterior). Solo DENTRO de la
-- subtransacción de una prueba: su MXT00 lo deshace.
create or replace function pg_temp.c16_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): los puentes de c3
-- en «immediate» (una factura entra al libro en el momento, como en
-- c3-pruebas), las reglas del tipo de obra confirmadas (si no lo están) y las
-- dos obras de prueba.
create or replace function pg_temp.c16_sembrar() returns void language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c16_ser('editor');
  perform fn_mapeo_confirmar('tipo_proyecto');
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v is not null then
    execute 'set constraints ' || v || ' immediate';
  end if;
  insert into proyectos (id, tipo, nombre, estado, cliente) values
    ('c16-prueba-a', 'comercial', 'C16 PRUEBA Obra A', 'ejecucion', 'ZZ Cliente C16 PRUEBA'),
    ('c16-prueba-b', 'servicio',  'C16 PRUEBA Obra B', 'ejecucion', 'ZZ Cliente C16 PRUEBA');
end $$;
-- Una factura de una obra de prueba, por el puente de c3 (entra al libro al
-- insertarla: Dr 1110 / Cr su ingreso). Devuelve su id (−1600000 − n).
create or replace function pg_temp.c16_factura(p_n int, p_obra text, p_monto numeric, p_fecha date, p_ret numeric default 0)
returns bigint language plpgsql as $$
declare
  v_id bigint := -(1600000 + p_n);
begin
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
  values (v_id, p_obra, 'C16-PRUEBA-' || p_n, p_fecha, p_monto, p_ret);
  if not exists (select 1 from facturas f where f.id = v_id and f.contabilizado_en is not null) then
    raise exception 'c16-pruebas: el puente de facturas no contabilizó la factura de prueba % (¿la regla del tipo de obra?)', v_id;
  end if;
  return v_id;
end $$;
-- Un cobro aplicado a una factura (c3, como el SQL Editor), a la cuenta del banco.
create or replace function pg_temp.c16_cobro(p_fecha date, p_monto numeric, p_factura bigint) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c16_ser('editor');
  r := fn_cobro_registrar(jsonb_build_object('fecha', p_fecha::text, 'monto', p_monto::text,
         'cuenta', (select pc.cuenta from puente_cuentas pc where pc.rol = 'banco'), 'medio', 'cheque',
         'referencia', 'C16 PRUEBA ' || p_factura, 'duplicado_confirmado', 'C16 PRUEBA: se deshace',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', p_factura, 'monto', p_monto::text))));
  return coalesce((r ->> 'cobro')::uuid, (r ->> 'id')::uuid);
end $$;
-- Un asiento a mano, como el dueño (fn_postear). Devuelve su id.
create or replace function pg_temp.c16_postear(p_fecha date, p_desc text, p_lineas jsonb) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c16_ser('dueno');
  r := fn_postear(jsonb_build_object('fecha', p_fecha::text, 'descripcion', 'C16 PRUEBA: ' || p_desc || ' (se deshace)', 'lineas', p_lineas));
  perform pg_temp.c16_ser('editor');
  return (r ->> 'id')::uuid;
end $$;

-- ---------------------------------------------------------------------
-- (14-nov, Fase 11c) LA NÓMINA DE GUSTO (c15) DE PRUEBA. Todo lo que
-- siembra es inventado y se deshace con su prueba (MXT00): tres personas
-- («ZZ C16 Prueba Uno» y «Dos», de oficina, y «ZZ C16 Prueba Tres», el
-- oficial: su usuario y su perfil), la configuración y el mapeo de
-- columnas de la nómina como de fábrica mientras dura la prueba (como
-- c15-pruebas: en la base real Edgar puede haberlos cambiado) y los
-- journals de abajo, con montos raros que cuadran al centavo. Las
-- funciones son plpgsql a propósito: en una base sin c15 se crean igual,
-- y nadie las llama.
-- ---------------------------------------------------------------------
-- LOS JOURNALS DE PRUEBA (sintéticos, como los exporta Gusto: «Payroll
-- journal»), con su período y su día de pago:
--   «tres» · tres personas · bruto 5,600.75 · retenido 899.46 · deducciones 37.50 · neto 4,663.79 · reembolsos 61.30 (cheque
--            4,725.09) · patrón 613.28 (941: 471.00 + 2 × 347.25 + 2 × 81.21 = 1,327.92 · FUTA 33.60 · reempleo 151.22)
--            → costo de la empresa 6,214.03 · impuestos 1,512.74 · deja por pagar 6,275.33 (el costo más lo reembolsado)
--        ZZ C16 Prueba Uno   bruto 1,873.60 · retenido 274.33 · neto 1,599.27 · patrón 205.16
--        ZZ C16 Prueba Dos   bruto 1,415.25 · retenido 201.27 · deducción 37.50 · neto 1,176.48 · patrón 154.97
--        ZZ C16 Prueba Tres  bruto 2,311.90 · retenido 423.86 · neto 1,888.04 · reembolso 61.30 · patrón 253.15
--   «dos»  · dos personas (Uno y Dos) · bruto 3,234.40 · retenido 467.42 · deducciones 37.50 · neto 2,729.48 · patrón 354.14
--            (941: 220.00 + 2 × 200.53 + 2 × 46.89 = 714.84 · FUTA 19.40 · reempleo 87.32) → costo 3,588.54 · impuestos 821.56 ·
--            deja por pagar 3,588.54
--   «una»  · UNA SOLA PERSONA (Tres, el oficial) · bruto 2,468.35 · retenido 456.83 · neto 2,011.52 · patrón 270.29 (941: 268.00 +
--            2 × 153.04 + 2 × 35.79 = 645.66 · FUTA 14.81 · reempleo 66.65) → costo 2,738.64 · impuestos 727.12 · deja por pagar
--            2,738.64
create or replace function pg_temp.c16_nom_csv(p_cual text, p_desde date, p_hasta date, p_pago date) returns text language plpgsql as $$
declare
  c_cab constant text := 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Regular hours,'
                         'Regular earnings,Overtime hours,Overtime earnings,Gross earnings,Employee federal income tax,Employee social security tax,'
                         'Employee medicare tax,Employee medicare additional tax,Employee taxes,Employee deductions,Net pay,Reimbursements,Check amount,'
                         'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes,Employer cost';
  v_f text[];
begin
  v_f := case p_cual
    when 'tres' then array[
      'ZZ C16 Prueba,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1873.60,0.00,0.00,1873.60,131.00,116.16,27.17,0.00,274.33,0.00,1599.27,0.00,1599.27,116.16,27.17,11.24,50.59,205.16,2078.76',
      'ZZ C16 Prueba,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,76.50,1415.25,0.00,0.00,1415.25,93.00,87.75,20.52,0.00,201.27,37.50,1176.48,0.00,1176.48,87.75,20.52,8.49,38.21,154.97,1570.22',
      'ZZ C16 Prueba,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2311.90,0.00,0.00,2311.90,247.00,143.34,33.52,0.00,423.86,0.00,1888.04,61.30,1949.34,143.34,33.52,13.87,62.42,253.15,2565.05',
      'Totals,,,,,,,236.50,5600.75,0.00,0.00,5600.75,471.00,347.25,81.21,0.00,899.46,37.50,4663.79,61.30,4725.09,347.25,81.21,33.60,151.22,613.28,6214.03']
    when 'dos' then array[
      'ZZ C16 Prueba,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1902.40,0.00,0.00,1902.40,134.00,117.95,27.58,0.00,279.53,0.00,1622.87,0.00,1622.87,117.95,27.58,11.41,51.36,208.30,2110.70',
      'ZZ C16 Prueba,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,72.00,1332.00,0.00,0.00,1332.00,86.00,82.58,19.31,0.00,187.89,37.50,1106.61,0.00,1106.61,82.58,19.31,7.99,35.96,145.84,1477.84',
      'Totals,,,,,,,152.00,3234.40,0.00,0.00,3234.40,220.00,200.53,46.89,0.00,467.42,37.50,2729.48,0.00,2729.48,200.53,46.89,19.40,87.32,354.14,3588.54']
    when 'una' then array[
      'ZZ C16 Prueba,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2468.35,0.00,0.00,2468.35,268.00,153.04,35.79,0.00,456.83,0.00,2011.52,0.00,2011.52,153.04,35.79,14.81,66.65,270.29,2738.64',
      'Totals,,,,,,,80.00,2468.35,0.00,0.00,2468.35,268.00,153.04,35.79,0.00,456.83,0.00,2011.52,0.00,2011.52,153.04,35.79,14.81,66.65,270.29,2738.64']
    end;
  if v_f is null then
    raise exception 'c16-pruebas: no hay un journal de prueba «%»', p_cual;
  end if;
  return c_cab || E'\n'
         || (select string_agg(format(f, to_char(p_desde, 'MM/DD/YYYY'), to_char(p_hasta, 'MM/DD/YYYY'), to_char(p_pago, 'MM/DD/YYYY')), E'\n' order by o)
               from unnest(v_f) with ordinality u(f, o)) || E'\n';
end $$;

-- SEMBRAR LO DE LA NÓMINA (como el SQL Editor; se deshace con la prueba): la
-- configuración y el mapeo de columnas como de fábrica (con la marca de la
-- guarda de c15) y las tres personas de prueba (su usuario y su perfil).
create or replace function pg_temp.c16_nom_sembrar() returns void language plpgsql as $$
declare
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
  r record;
begin
  perform pg_temp.c16_ser('editor');
  perform set_config('mx_nomina.escribe', 'nomina_config', true);
  update nomina_config
     set cuenta_sin_obra = '6000', cuenta_oficina = '6000', cuenta_oficial = '6005', cuenta_bolsa = '5015', cuenta_burden_obra = '5010',
         cuenta_burden_admin = '6010', cuenta_cuota = '6500', cargo_dias_antes = 10, cargo_dias_despues = 5, saldo_dias = 10,
         cargo_patrones = '{"neto": "\\mNET\\M", "impuestos": "\\mTAX\\M", "reembolsos": "\\mREM\\M", "manutencion": "\\mCSD\\M", "cuota": "\\mFEE\\M"}'::jsonb
   where id = 1;
  perform set_config('mx_nomina.escribe', 'nomina_columnas', true);
  update nomina_columnas k
     set concepto = v.concepto, clase = v.clase, cuenta = v.cuenta, declara = v.declara
    from (values
      ('employee first name', 'employee_first_name', 'nombre', null, null), ('employee last name', 'employee_last_name', 'apellido', null, null),
      ('pay period start', 'pay_period_start', 'periodo_desde', null, null), ('pay period end', 'pay_period_end', 'periodo_hasta', null, null),
      ('check date', 'check_date', 'dia_pago', null, null), ('payroll type', 'payroll_type', 'tipo', null, null),
      ('payment method', 'payment_method', 'metodo_pago', null, null), ('regular hours', 'regular_hours', 'horas', null, null),
      ('overtime hours', 'overtime_hours', 'horas', null, null), ('regular earnings', 'regular_earnings', 'bruto', null, null),
      ('overtime earnings', 'overtime_earnings', 'bruto', null, null), ('gross earnings', 'gross_earnings', 'bruto_total', null, null),
      ('employee federal income tax', 'employee_federal_income_tax', 'imp_empleado', '2220', 'fit'),
      ('employee social security tax', 'employee_social_security_tax', 'imp_empleado', '2220', 'ss_ee'),
      ('employee medicare tax', 'employee_medicare_tax', 'imp_empleado', '2220', 'med_ee'),
      ('employee medicare additional tax', 'employee_medicare_additional_tax', 'imp_empleado', '2220', 'med_adic'),
      ('employee taxes', 'employee_taxes', 'imp_empleado_total', '2220', null), ('employee deductions', 'employee_deductions', 'deduccion', '2240', null),
      ('net pay', 'net_pay', 'neto', '2210', null), ('reimbursements', 'reimbursements', 'reembolso_total', '2250', null),
      ('check amount', 'check_amount', 'cheque_total', null, null),
      ('employer social security tax', 'employer_social_security_tax', 'imp_patron', '2220', 'ss_er'),
      ('employer medicare tax', 'employer_medicare_tax', 'imp_patron', '2220', 'med_er'),
      ('employer futa tax', 'employer_futa_tax', 'imp_patron', '2225', 'futa'), ('employer suta tax', 'employer_suta_tax', 'imp_patron', '2230', 'suta'),
      ('employer taxes', 'employer_taxes', 'imp_patron_total', null, null), ('employer cost', 'employer_cost', 'costo_total', null, null))
      as v(alias, concepto, clase, cuenta, declara)
   where k.alias = v.alias
     and (k.concepto, k.clase, k.cuenta, k.declara) is distinct from (v.concepto, v.clase, v.cuenta, v.declara);
  perform set_config('mx_nomina.escribe', '', true);
  for r in select * from (values ('n1', 'ZZ C16 Prueba Uno'), ('n2', 'ZZ C16 Prueba Dos'), ('n3', 'ZZ C16 Prueba Tres')) as x(k, nombre) loop
    if v_meta then
      execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                     pg_temp.c16(r.k), 'c16-' || r.k || '@c16-pruebas.invalid',
                     json_build_object('nombre', r.nombre, 'name', r.nombre, 'full_name', r.nombre)::text);
    else
      execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                     pg_temp.c16(r.k), 'c16-' || r.k || '@c16-pruebas.invalid');
    end if;
    insert into perfiles (id, nombre, rol, activo) values (pg_temp.c16(r.k)::uuid, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
end $$;

-- UNA NÓMINA DE PRUEBA, por el camino de c15 y como el dueño con su código:
-- el journal importado, su gente enlazada y confirmada (Uno y Dos, de
-- oficina; Tres, el oficial) y, si se pide, la propuesta vista y posteada.
-- Devuelve la corrida. Si la nómina no la toma por nueva (en la base hay
-- otra con ese mismo día de pago y ese período), lo dice con MXT01: la
-- prueba sale «omitida».
create or replace function pg_temp.c16_nom(p_cual text, p_desde date, p_hasta date, p_pago date, p_postear boolean default true)
returns uuid language plpgsql as $$
declare
  v_csv text := pg_temp.c16_nom_csv(p_cual, p_desde, p_hasta, p_pago);
  r jsonb; c uuid; x record;
begin
  perform pg_temp.c16_ser('dueno');
  r := fn_nomina_importar(jsonb_build_object(
         'nombre', format('zz-c16-prueba-%s-%s.csv', p_cual, to_char(p_pago, 'YYYYMMDD')),
         'sha256', encode(sha256(convert_to(v_csv, 'UTF8')), 'hex'), 'bytes', octet_length(v_csv),
         'filas', (select jsonb_agg(to_jsonb(string_to_array(l, ',')) order by o)
                     from unnest(string_to_array(rtrim(v_csv, E'\n'), E'\n')) with ordinality u(l, o))), '{}'::jsonb);
  c := (select (q ->> 'corrida')::uuid from jsonb_array_elements(r -> 'corridas') q where q ->> 'resultado' = 'nueva' order by (q ->> 'n')::int limit 1);
  if c is null then
    perform pg_temp.c16_ser('editor');
    raise exception using errcode = 'MXT01',
      message = format('la nómina no tomó por nueva la de prueba (%s): en esta base ya hay una con ese día de pago y ese período',
                       coalesce(r -> 'corridas' -> 0 ->> 'resultado', left(r::text, 200)));
  end if;
  for x in select pe.id, case pe.nombre when 'ZZ C16 Prueba Uno' then 'n1' when 'ZZ C16 Prueba Dos' then 'n2' else 'n3' end as k,
                  case when pe.nombre = 'ZZ C16 Prueba Tres' then 'oficial' else 'oficina' end as clase
             from nomina_personas pe
            where pe.nombre in ('ZZ C16 Prueba Uno', 'ZZ C16 Prueba Dos', 'ZZ C16 Prueba Tres') and pe.confirmado_el is null loop
    perform fn_nomina_persona(jsonb_build_object('id', x.id, 'usuario_id', pg_temp.c16(x.k), 'clase', x.clase, 'confirmar', true));
  end loop;
  if p_postear then
    perform fn_nomina_postear(c, fn_nomina_propuesta(c) ->> 'visto');
  end if;
  perform set_config('mx_nomina.escribe', '', true);
  perform pg_temp.c16_ser('editor');
  return c;
end $$;

-- UN MOVIMIENTO DE GUSTO EN EL BANCO, como lo trae Plaid (en nombre del
-- dueño) y «Casar» solo para él: c6 lo deja en la Bandeja esperando su
-- nómina. p_monto en positivo = lo que salió (un cargo); en negativo, un
-- depósito (una devolución de Gusto). La descripción lleva «C16 PRUEBA».
create or replace function pg_temp.c16_nom_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text) returns uuid language plpgsql as $$
declare
  v_mov uuid;
begin
  perform pg_temp.c16_ser('dueno');
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', pg_temp.c16('banco'), 'nombre', 'Plaid · c16-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object('id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text,
                                                  'descripcion', p_desc || ' C16 PRUEBA', 'tipo', case when p_monto >= 0 then 'DEBIT' else 'CREDIT' end,
                                                  'pendiente', false))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform pg_temp.c16_ser('editor');
  if not exists (select 1 from movimientos_banco m where m.id = v_mov and m.estado = 'pendiente') then
    raise exception using errcode = 'MXT01',
      message = format('el movimiento de prueba %s casó solo con algo del libro (¿un monto real igual?)', p_id);
  end if;
  return v_mov;
end $$;
-- (casar un cargo con lo que paga de una nómina, como el dueño con su código: fn_nomina_cargo_casar de c15)
create or replace function pg_temp.c16_nom_casar(p_mov uuid, p_partes jsonb) returns void language plpgsql as $$
begin
  perform pg_temp.c16_ser('dueno');
  perform fn_nomina_cargo_casar(p_mov, p_partes, null);
  perform set_config('mx_nomina.escribe', '', true);
  perform pg_temp.c16_ser('editor');
end $$;

-- ¿Se puede sembrar en esta base? Se prueba UNA vez, antes de todo, y se deshace.
do $$
declare
  v text := 'ok';
begin
  begin
    perform pg_temp.c16_sembrar();
    perform pg_temp.c16_factura(99, 'c16-prueba-a', 1234.57, fn_fecha_miami(now()));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c16 values ('siembra', v);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar o que necesita una capa; true si la puso)
create or replace function pg_temp.c16_omitir(p_n int, p_prueba text, p_esperado text, p_siembra boolean default false,
                                              p_capas text[] default '{}') returns boolean language plpgsql as $$
declare
  v_falta text := (select string_agg(c, ', ') from unnest(p_capas) c where not pg_temp.c16_capa(c));
  v text := case when pg_temp.c16('dueno') is null then 'no hay un dueño activo en perfiles'
                 when v_falta is not null then format('esa parte de la contabilidad (%s) no está en esta base', v_falta)
                 when p_siembra and pg_temp.c16('mes') is null then 'el mes de hoy no está abierto: no hay dónde sembrar lo de la prueba'
                 when p_siembra and pg_temp.c16('siembra') <> 'ok'
                   then 'esta base no deja sembrar las obras y la factura de prueba (' || left(pg_temp.c16('siembra'), 300) || ')' end;
begin
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado, 'omitida: ' || v, null);
  return true;
end $$;

-- (14-nov, Fase 11c) ¿Se puede sembrar una NÓMINA de prueba en esta base? Se prueba UNA vez (las personas, la nómina de una sola
-- persona, importada, enlazada y posteada con día de pago hoy) y se deshace. Si no (un trigger de auth.users que pida más datos,
-- una nómina de verdad con ese mismo día de pago y ese período), las pruebas que la siembran salen «omitida» con lo que dijo la
-- base. Sin c15, ni se intenta.
do $$
declare
  v text := 'ok';
begin
  if pg_temp.c16_hay_c15() and pg_temp.c16('mes') is not null and pg_temp.c16('dueno') is not null then
    begin
      perform pg_temp.c16_nom_sembrar();
      perform pg_temp.c16_nom('una', fn_fecha_miami(now()) - 12, fn_fecha_miami(now()) - 4, fn_fecha_miami(now()));
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v := sqlstate || ': ' || sqlerrm;
    end;
    perform pg_temp.c16_ser('editor');
  end if;
  insert into _c16 values ('siembra_nomina', v);
end $$;
-- (la fila «omitida» de una prueba de la nómina: sin c15, sin dónde o sin cómo sembrarla, o sin el banco; true si la puso)
create or replace function pg_temp.c16_nom_omitir(p_n int, p_prueba text, p_esperado text, p_siembra boolean default true,
                                                  p_banco boolean default false) returns boolean language plpgsql as $$
declare
  v text := case when not pg_temp.c16_hay_c15()
                   then 'la nómina con Gusto (c15) no está pegada en esta base (lo que la portada dice entonces lo mira la 58)'
                 when pg_temp.c16('dueno') is null then 'no hay un dueño activo en perfiles'
                 when p_siembra and pg_temp.c16('mes') is null then 'el mes de hoy no está abierto: no hay dónde postear una nómina de prueba'
                 when p_siembra and pg_temp.c16('siembra_nomina') <> 'ok'
                   then 'esta base no deja sembrar una nómina de prueba (' || left(pg_temp.c16('siembra_nomina'), 300) || ')'
                 when p_banco and pg_temp.c16('hay_banco') <> 'true'
                   then 'el banco (c6) o su cuenta no están en esta base: no hay cómo traer un cargo de Gusto' end;
begin
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado, 'omitida: ' || v, null);
  return true;
end $$;

-- ---------------------------------------------------------------------
-- LAS CONSULTAS INDEPENDIENTES: lo que dice el libro (o la vista de la capa
-- que ya lo sabe), escrito aquí sin usar nada de c16. Cada prueba compara
-- la tarjeta con esto.
-- ---------------------------------------------------------------------
-- El saldo de unas cuentas en el libro (debe − haber) hasta un día.
create or replace function pg_temp.c16_libro(p_cuentas text[], p_hasta date) returns numeric language sql as $$
  select coalesce(sum(l.monto), 0)::numeric(14,2)
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.cuenta = any (p_cuentas) and a.fecha_contable <= p_hasta
$$;
-- El ejercicio de un asiento (el de su fecha; el de un ajuste del CPA, el del período que corrige).
create or replace function pg_temp.c16_ejercicio(p_asiento uuid) returns int language sql as $$
  select case when a.afecta_periodo is null then extract(year from a.fecha_contable)::int
              else coalesce((select p.anio from periodos p where p.periodo = a.afecta_periodo), extract(year from a.fecha_contable)::int) end
    from asientos a where a.id = p_asiento
$$;
-- LOS ASIENTOS DEL WIP (c12, fn_wip_asientos: el ajuste de cada mes, su
-- reverso del día 1, el de corrección, la anulación), escritos aquí: todos,
-- y los que van APARTE (caen en un mes sin cerrar que todavía no tiene su
-- propio ajuste vivo con fecha hasta hoy: el reverso del día 1 que espera al
-- ajuste de su mes). Sin c12, ninguno.
create or replace function pg_temp.c16_wip(p_solo_aparte boolean) returns table (asiento_id uuid, fecha date) language plpgsql as $$
begin
  if to_regprocedure('public.fn_wip_asientos()') is null or to_regclass('public.wip_ajustes') is null then
    return;
  end if;
  return query execute $q$
    select a.id, a.fecha_contable
      from public.fn_wip_asientos() w join public.asientos a on a.id = w.asiento_id
     where not $1
        or (exists (select 1 from public.periodos p where p.tipo = 'mes' and p.estado = 'abierto' and a.fecha_contable between p.desde and p.hasta)
            and not exists (select 1 from public.wip_ajustes j
                             where j.periodo = to_char(a.fecha_contable, 'YYYY-MM') and j.deshecho_el is null
                               and j.fecha <= fn_fecha_miami(now())))$q$ using p_solo_aparte;
end $$;
-- EL RESULTADO de un rango, del libro y el mapeo de c4 (cada línea de su
-- ejercicio): las secciones y la utilidad neta. Sin lo del WIP que va aparte
-- (p_con_wip: con él, lo de v_resultados tal cual).
create or replace function pg_temp.c16_res(p_desde date, p_hasta date, p_con_wip boolean default false) returns jsonb language sql as $$
  with l as (
    select m.seccion, li.monto, li.asiento_id
      from asiento_lineas li
      join asientos a on a.id = li.asiento_id
      join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados'
     where a.fecha_contable between p_desde and p_hasta
       and pg_temp.c16_ejercicio(a.id) = extract(year from a.fecha_contable)::int
       and (p_con_wip or a.id not in (select w.asiento_id from pg_temp.c16_wip(true) w))
  ), s as (
    select coalesce(-sum(monto) filter (where seccion = 'ingresos'), 0) as i, coalesce(sum(monto) filter (where seccion = 'costo'), 0) as c,
           coalesce(sum(monto) filter (where seccion = 'gastos'), 0) as g, coalesce(-sum(monto) filter (where seccion = 'otros_ingresos'), 0) as oi,
           coalesce(sum(monto) filter (where seccion = 'otros_gastos'), 0) as og, count(distinct asiento_id) as n
      from l
  )
  select jsonb_build_object('ingresos', round(i, 2), 'costo', round(c, 2), 'gastos', round(g, 2), 'otros_ingresos', round(oi, 2),
                            'otros_gastos', round(og, 2), 'resultado', round(i - c - g + oi - og, 2), 'entra', round(i + oi, 2),
                            'sale', round(c + g + og, 2), 'asientos', n)
    from s
$$;
-- LAS PARTIDAS POR COBRAR de hoy, del libro: las líneas de las cuentas por
-- cobrar (1110 y la retención) agrupadas por su partida (o, sin partida, por
-- su obra), con su fecha (la de la factura; la de lo demás, la de c4) y su
-- vencimiento (el de la factura emitida por la app; si no, su fecha más los
-- términos de Facturas → Ajustes).
create or replace function pg_temp.c16_cxc() returns table (pt text, pid text, obra text, por numeric, ret numeric, fecha date, vence date)
language plpgsql as $$
declare
  v_cxc  text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc');
  v_ret  text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc');
  v_hoy  date := fn_fecha_miami(now());
  v_dias int := pg_temp.c16('terminos')::int;
  v_app  jsonb := '{}'::jsonb;
begin
  if to_regclass('public.emision_documentos') is not null then
    execute $q$select coalesce(jsonb_object_agg(d.factura_id::text, d.vence), '{}'::jsonb) from public.emision_documentos d
                where d.estado = 'emitida' and d.factura_id is not null and d.vence is not null$q$ into v_app;
  end if;
  return query
  with g as (
    select l.partida_tabla as pt, l.partida_id as pid, case when l.partida_tabla is null then l.proyecto_id end as obra,
           coalesce(sum(l.monto) filter (where l.cuenta = v_cxc), 0) as por, coalesce(sum(l.monto) filter (where l.cuenta = v_ret), 0) as ret
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta in (v_cxc, v_ret) and a.fecha_contable <= v_hoy
     group by 1, 2, 3
    having coalesce(sum(l.monto) filter (where l.cuenta = v_cxc), 0) <> 0 or coalesce(sum(l.monto) filter (where l.cuenta = v_ret), 0) <> 0
  )
  select g.pt, g.pid, g.obra, g.por, g.ret, x.f,
         case when g.por > 0 then coalesce(case when g.pt = 'facturas' then (v_app ->> g.pid)::date end, x.f + v_dias) end
    from g
    cross join lateral (
      select case when g.pt = 'facturas' then (select f.fecha from facturas f where f.id::text = g.pid)
                  else (select c.fecha from v_cxc_antiguedad c
                         where c.periodo = 'hoy' and c.nivel = 'partida' and c.partida_tabla is not distinct from g.pt
                           and c.partida_id is not distinct from g.pid
                           and (g.pt is not null or c.proyecto_id is not distinct from g.obra) limit 1) end as f) x;
end $$;
-- (el tramo por días de vencida, como QuickBooks)
create or replace function pg_temp.c16_tramo(p_vence date) returns text language sql as $$
  select case when p_vence is null then 'sin_vencimiento'
              when fn_fecha_miami(now()) - p_vence <= 0 then 'corriente'
              when fn_fecha_miami(now()) - p_vence <= 30 then 'd1_30'
              when fn_fecha_miami(now()) - p_vence <= 60 then 'd31_60'
              when fn_fecha_miami(now()) - p_vence <= 90 then 'd61_90'
              else 'd90_mas' end
$$;
-- EL DÍA EN QUE SE COBRÓ un cobro: el suyo; el de un cobro que p1 volvió a
-- registrar tras un reembolso en parte o una disputa (una versión nueva de su
-- pago, con la fecha del cambio), el del primer cobro de su pago.
create or replace function pg_temp.c16_origen(p_cobro uuid) returns date language plpgsql as $$
declare
  v date;
begin
  if to_regclass('public.stripe_pago_libro') is not null then
    execute $q$select min(c2.fecha) from public.stripe_pago_libro pl
                 join public.stripe_pago_libro pl2 on pl2.pago_id = pl.pago_id and pl2.accion = 'cobro'
                 join public.cobros c2 on c2.id = pl2.cobro_id
                where pl.cobro_id = $1 and pl.accion = 'cobro'$q$ into v using p_cobro;
  end if;
  return coalesce(v, (select c.fecha from cobros c where c.id = p_cobro));
end $$;
-- LOS COBROS de un rango (por el día en que se cobró), del libro de cobros
-- (c3): cada uno con lo devuelto de él hasta hoy y si ya está en el banco
-- (casado con su movimiento; el de Stripe, con su depósito ya casado).
create or replace function pg_temp.c16_cobros(p_desde date, p_hasta date)
returns table (id uuid, neto numeric, en_banco boolean, clase text, facturas bigint[], a_facturas numeric)
language plpgsql as $$
declare
  v_puente text;
  v_st jsonb := '{}'::jsonb;
  v_caja text[] := array(select m.cuenta from v_estados_mapeo m where coalesce(m.caja, false));
  v_c6 boolean := to_regclass('public.banco_casado_lineas') is not null;
  v_cas uuid[] := '{}';
begin
  if to_regclass('public.stripe_config') is not null and to_regclass('public.v_stripe_pagos') is not null then
    execute 'select cuenta_puente from public.stripe_config where id = 1' into v_puente;
    execute $q$select coalesce(jsonb_object_agg(s.cobro_id::text, v.estado_pantalla), '{}'::jsonb)
                 from public.v_stripe_pagos v join public.stripe_pagos s on s.id = v.id where s.cobro_id is not null$q$ into v_st;
  end if;
  if v_c6 then
    execute $q$select coalesce(array_agg(c.id), '{}'::uuid[]) from public.cobros c
                where c.estado = 'vigente' and (c.movimiento_id is not null
                      or exists (select 1 from public.banco_casado_lineas bl join public.banco_casados bc on bc.id = bl.casado_id
                                  where bl.vigente and bc.deshecho_el is null and bl.asiento_id = c.contabilizado_en and bl.cuenta = c.cuenta))$q$
      into v_cas;
  end if;
  return query
  select c.id, (c.monto - coalesce((select d.monto from cobros_devoluciones d where d.cobro_id = c.id and d.fecha <= fn_fecha_miami(now())), 0))::numeric(14,2),
         case when c.cuenta = v_puente then (v_st ->> c.id::text) = 'depositado'
              when c.cuenta = any (v_caja) then false
              else c.id = any (v_cas) end,
         case when c.cuenta = v_puente then 'stripe' when c.cuenta = any (v_caja) then 'caja' else 'banco' end,
         array(select distinct ap.factura_id from aplicaciones_cobro ap where ap.cobro_id = c.id and ap.factura_id is not null order by 1),
         coalesce((select sum(ap.monto) from aplicaciones_cobro ap where ap.cobro_id = c.id and ap.factura_id is not null), 0)::numeric(14,2)
    from cobros c
   where c.estado = 'vigente' and pg_temp.c16_origen(c.id) between p_desde and p_hasta;
end $$;

-- ---------------------------------------------------------------------
-- (14-nov, Fase 11c) LO QUE DICEN EL LIBRO Y LA NÓMINA (c15) DE LA NÓMINA,
-- escrito aquí sin usar nada de c16 y como el SQL Editor (que lee enteras
-- las tablas de c15). Cada prueba de la tarjeta de la nómina compara con
-- esto. Son plpgsql con «execute» a propósito: en una base sin c15 se crean
-- igual, y nadie las llama.
-- ---------------------------------------------------------------------
-- LO QUE COSTÓ LA NÓMINA CADA MES: los asientos de las corridas que la
-- nómina tiene POSTEADAS (nomina_corridas, de c15), con fecha hasta hoy, por
-- el mes en que el libro los lleva (el de un ajuste del CPA, el mes que
-- corrige). Lo que cargan a las cuentas del estado de resultados de c4
-- (v_estados_mapeo) es el costo; de eso, lo del patrón es lo que va a la
-- bolsa del burden y al burden de oficina y de obra (las cuentas de la
-- configuración de la nómina). Un trozo por mes: «AAAA-MM costo (sueldos +
-- patrón), cuántas».
create or replace function pg_temp.c16_nom_meses(p_meses int default 6) returns text language plpgsql as $$
declare
  v_hoy date := fn_fecha_miami(now());
  v_m0  date := greatest(date_trunc('month', pg_temp.c16('libro_desde')::date)::date,
                         (date_trunc('month', fn_fecha_miami(now())) - make_interval(months => p_meses - 1))::date);
  v text;
begin
  execute $q$
    with j as (
      select a.id, coalesce((select date_trunc('month', pe.hasta)::date from public.periodos pe
                              where a.tipo = 'ajuste_cpa' and pe.periodo = a.afecta_periodo),
                            date_trunc('month', a.fecha_contable)::date) as mes
        from public.nomina_corridas k join public.asientos a on a.id = k.asiento_id
       where k.estado = 'posteada' and a.fecha_contable <= $1
    ), s as (
      select j.mes, count(distinct j.id) as n,
             coalesce(sum(l.monto) filter (where l.cuenta in (select m.cuenta from public.v_estados_mapeo m where m.estado = 'resultados')), 0) as costo,
             coalesce(sum(l.monto) filter (where l.cuenta in (select u from public.nomina_config c,
                                                                     unnest(array[c.cuenta_bolsa, c.cuenta_burden_admin, c.cuenta_burden_obra]) u
                                                               where c.id = 1)), 0) as patron
        from j join public.asiento_lineas l on l.asiento_id = j.id
       group by j.mes
    )
    select string_agg(format('%s %s (%s + %s), %s', to_char(g.mes, 'YYYY-MM'), pg_temp.c16_m(coalesce(s.costo, 0)),
                             pg_temp.c16_m(coalesce(s.costo - s.patron, 0)), pg_temp.c16_m(coalesce(s.patron, 0)), coalesce(s.n, 0)),
                      '; ' order by g.mes)
      from generate_series($2::timestamp, date_trunc('month', $1::timestamp), interval '1 month') g(mes)
      left join s on s.mes = g.mes::date$q$ into v using v_hoy, v_m0;
  return coalesce(v, 'ninguno');
end $$;

-- LO QUE SE DEBE DE LA NÓMINA: las cuentas por pagar que usa la nómina (las
-- del mapeo de columnas de c15 y las que los journals de sus corridas han
-- usado; y la de reembolsos), dentro del renglón «nómina y retenciones por
-- pagar» del balance de c4 (v_estados_mapeo), con TODO lo que el libro
-- tiene en ellas (también lo fechado después de hoy), en positivo lo que se
-- debe. La cuenta de los reembolsos a empleados (la que dice el mapeo de
-- columnas de la nómina; sin él, la del puente de c3) cuenta solo si debe: al
-- revés va aparte. LO DEMÁS DEL RENGLÓN (las vacaciones devengadas: ninguna
-- nómina las paga) no es de la nómina: va en «otras». {monto, libro (el del
-- Balance: el renglón entero), aparte, otras (su suma) y otras_cuentas,
-- cuentas («2210 4725.09, …»: las que suman «monto»), reem (las cuentas de
-- reembolsos), nom (las de la nómina)}. Sin c15, todas las del renglón.
create or replace function pg_temp.c16_nom_debe() returns jsonb language plpgsql as $$
declare
  v_reem text[] := '{}'; v_nom text[]; r record; v_m numeric := 0; v_l numeric := 0; v_a numeric := 0; v_o numeric := 0; v_c text := '';
  v_oc text[] := '{}'; v_s numeric;
begin
  if to_regclass('public.nomina_columnas') is not null then
    execute $q$select coalesce(array_agg(distinct k.cuenta), '{}'::text[]) from public.nomina_columnas k
                where k.clase in ('reembolso', 'reembolso_total') and k.cuenta is not null$q$ into v_reem;
    execute $q$select array(select k.cuenta from public.nomina_columnas k where k.cuenta is not null
                            union
                            select l.cuenta from public.nomina_corridas c join public.asiento_lineas l on l.asiento_id = c.asiento_id)$q$ into v_nom;
  end if;
  if cardinality(v_reem) = 0 then
    v_reem := array(select pc.cuenta from puente_cuentas pc where pc.rol = 'reembolso_empleado');
  end if;
  for r in select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'nomina_por_pagar' order by m.cuenta loop
    select coalesce(-sum(l.monto), 0) into v_s from asiento_lineas l where l.cuenta = r.cuenta;
    v_l := v_l + v_s;
    if v_nom is not null and r.cuenta <> all (v_nom) and r.cuenta <> all (v_reem) then
      -- (del renglón, pero no de la nómina de Gusto)
      v_o := v_o + v_s;
      if v_s <> 0 then v_oc := v_oc || r.cuenta; end if;
    elsif r.cuenta = any (v_reem) and v_s < 0 then
      v_a := v_a - v_s;
    else
      v_m := v_m + v_s;
      if v_s <> 0 then
        v_c := v_c || r.cuenta || ' ' || pg_temp.c16_m(v_s) || ', ';
      end if;
    end if;
  end loop;
  return jsonb_build_object('monto', round(v_m, 2), 'libro', round(v_l, 2), 'aparte', round(v_a, 2), 'otras', round(v_o, 2),
                            'otras_cuentas', to_jsonb(v_oc), 'cuentas', coalesce(nullif(rtrim(v_c, ', '), ''), 'ninguna'),
                            'reem', to_jsonb(v_reem), 'nom', to_jsonb(v_nom));
end $$;

-- CUÁNDO SALE DE LA CAJA LO QUE SE DEBE DE LA NÓMINA, hecho aquí paso a paso
-- y a mano (con bucles: no como lo hace c16) y CON LO QUE LA NÓMINA (c15)
-- SABE DE CADA UNA, que c16 no lee (c16 mira solo el libro: qué nómina pagó
-- cada cargo lo saca de la descripción de su asiento). CUENTA POR CUENTA,
-- de las de la nómina: lo que le QUEDA por pagar a cada corrida posteada con
-- journal de fecha de después de hoy —lo que dejó en la cuenta (sus
-- «pasivos») menos lo que sus cargos casados, vivos, ya le pagaron (sus
-- partes: nomina_pago_partes)— se debe su día; lo demás que la cuenta
-- tiene, hoy. Si la cuenta tiene MENOS de lo que así les queda (algo se
-- pagó sin pasar por la nómina), la diferencia se le quita a la más próxima
-- primero. La de reembolsos, si debe, hoy. Lo que una cuenta tiene a favor
-- baja lo de hoy primero y después lo más próximo. Si en total no se debe
-- nada, nada. (Hasta los arreglos de la verificación del 14-nov esta cuenta
-- repetía el método de c16 —lo cobrado, contra lo más viejo de la cuenta— y
-- daba por bueno su mismo error.)
create or replace function pg_temp.c16_nom_pagos() returns table (fecha date, monto numeric, asiento text) language plpgsql as $$
declare
  v_hoy date := fn_fecha_miami(now()); d jsonb := pg_temp.c16_nom_debe(); v_reem text[]; v_nom text[];
  v_cor uuid[] := '{}'; v_num text[] := '{}'; v_fec date[] := '{}'; v_mon numeric[] := '{}'; v_que numeric[];
  v_hoy_m numeric := 0; v_favor numeric := 0; v_b numeric; v_s numeric; v_x numeric; v_q numeric; i int; r record; c record;
begin
  if (d ->> 'monto')::numeric <= 0 then
    return;
  end if;
  v_reem := array(select jsonb_array_elements_text(d -> 'reem'));
  v_nom := case when jsonb_typeof(d -> 'nom') = 'array' then array(select jsonb_array_elements_text(d -> 'nom')) end;
  -- las corridas posteadas con journal de fecha de después de hoy, en su orden
  if to_regclass('public.nomina_corridas') is not null then
    for r in execute $q$select k.id, a.numero, a.fecha_contable as f from public.nomina_corridas k join public.asientos a on a.id = k.asiento_id
                         where k.estado = 'posteada' and a.fecha_contable > $1 order by a.fecha_contable, a.numero$q$ using v_hoy loop
      v_cor := v_cor || r.id; v_num := v_num || r.numero; v_fec := v_fec || r.f; v_mon := v_mon || 0::numeric;
    end loop;
  end if;
  for c in select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'nomina_por_pagar' order by m.cuenta loop
    if v_nom is not null and c.cuenta <> all (v_nom) and c.cuenta <> all (v_reem) then
      continue;   -- (del renglón, pero no de la nómina: no cuenta)
    end if;
    select coalesce(-sum(l.monto), 0) into v_b from asiento_lineas l where l.cuenta = c.cuenta;
    if c.cuenta = any (v_reem) then
      v_hoy_m := v_hoy_m + greatest(v_b, 0);
      continue;
    end if;
    -- lo que a cada corrida de después LE QUEDA en esta cuenta, según la nómina: lo que dejó menos lo que sus cargos casados y
    -- vivos le pagaron
    v_que := '{}'; v_s := 0;
    for i in 1 .. coalesce(array_length(v_cor, 1), 0) loop
      execute $q$select greatest(coalesce((k.pasivos ->> $2)::numeric, 0)
                                 - coalesce((select sum(pp.monto)
                                               from public.nomina_pago_partes pp
                                               join public.nomina_pagos g on g.id = pp.pago_id
                                               join public.movimientos_banco m on m.id = g.movimiento_id
                                              where pp.corrida_id = k.id and pp.cuenta = $2 and g.estado = 'aplicado'
                                                and m.asiento_id = g.asiento_id and m.estado in ('casado', 'en_transito')), 0), 0)
                   from public.nomina_corridas k where k.id = $1$q$ into v_q using v_cor[i], c.cuenta;
      v_que := v_que || coalesce(v_q, 0); v_s := v_s + coalesce(v_q, 0);
    end loop;
    v_favor := v_favor + greatest(-v_b, 0);
    v_hoy_m := v_hoy_m + greatest(v_b - v_s, 0);
    v_x := greatest(v_s - v_b, 0);                      -- lo que falta por explicar, en esta cuenta: se le quita a la más próxima
    for i in 1 .. coalesce(array_length(v_cor, 1), 0) loop
      v_mon[i] := v_mon[i] + greatest(v_que[i] - v_x, 0);
      v_x := greatest(v_x - v_que[i], 0);
    end loop;
  end loop;
  -- lo que hay a favor: de lo de hoy primero, y después de lo más próximo
  v_x := least(v_favor, v_hoy_m); v_hoy_m := v_hoy_m - v_x; v_favor := v_favor - v_x;
  if v_hoy_m > 0 then
    fecha := v_hoy; monto := round(v_hoy_m, 2); asiento := null;
    return next;
  end if;
  for i in 1 .. coalesce(array_length(v_num, 1), 0) loop
    v_x := least(v_favor, v_mon[i]); v_mon[i] := v_mon[i] - v_x; v_favor := v_favor - v_x;
    if v_mon[i] > 0 then
      fecha := v_fec[i]; monto := round(v_mon[i], 2); asiento := v_num[i];
      return next;
    end if;
  end loop;
end $$;
create or replace function pg_temp.c16_nom_pagos_txt() returns text language sql as $$
  select coalesce(string_agg(case when p.asiento is null then 'hoy ' || pg_temp.c16_m(p.monto)
                                  else format('%s %s (%s)', p.fecha, pg_temp.c16_m(p.monto), p.asiento) end,
                             ', ' order by p.fecha, p.asiento nulls first), 'nada')
    from pg_temp.c16_nom_pagos() p
$$;

-- UNA NÓMINA, con lo que la nómina (c15) tiene de ella en sus tablas: su
-- estado, su día de pago y su período, cuántas personas (las filas de sus
-- personas) y los totales de la empresa SUMADOS DE LO DE CADA PERSONA; y, si
-- está posteada, lo que le queda por pagar y lo que tiene a favor (lo que su
-- journal dejó en cada cuenta menos lo que sus cargos casados ya pagaron).
create or replace function pg_temp.c16_nom_una(p_corrida uuid) returns text language plpgsql as $$
declare
  v text;
begin
  if p_corrida is null or to_regclass('public.nomina_corridas') is null then
    return 'ninguna';
  end if;
  execute $q$
    select format('%s · %s · %s · %s personas · costo %s · bruto %s · patrón %s · impuestos %s · neto %s · deducciones %s · reembolsos %s · '
                  'por pagar %s · a favor %s · asiento %s',
                  k.estado, k.dia_pago, coalesce(k.periodo_desde::text || ' a ' || k.periodo_hasta::text, 'sin período'), s.n,
                  pg_temp.c16_m(s.bruto + s.imp_p + s.ben_p), pg_temp.c16_m(s.bruto), pg_temp.c16_m(s.imp_p + s.ben_p),
                  pg_temp.c16_m(s.imp_e + s.imp_p), pg_temp.c16_m(s.neto), pg_temp.c16_m(s.ded), pg_temp.c16_m(s.reem),
                  pg_temp.c16_m(case when k.estado = 'posteada' then coalesce(pd.por_pagar, 0) end),
                  pg_temp.c16_m(case when k.estado = 'posteada' then coalesce(pd.a_favor, 0) end), coalesce(k.asiento_numero, '—'))
      from public.nomina_corridas k
      cross join lateral (select count(*) as n, coalesce(sum(cp.bruto), 0) as bruto, coalesce(sum(cp.imp_empleado), 0) as imp_e,
                                 coalesce(sum(cp.imp_patron), 0) as imp_p, coalesce(sum(cp.ben_patron), 0) as ben_p,
                                 coalesce(sum(cp.neto), 0) as neto, coalesce(sum(cp.deducciones), 0) as ded, coalesce(sum(cp.reembolsos), 0) as reem
                            from public.nomina_corrida_personas cp where cp.corrida_id = k.id) s
      left join lateral (select sum(greatest(e.value::numeric - coalesce(pg.s, 0), 0)) as por_pagar,
                                sum(greatest(coalesce(pg.s, 0) - e.value::numeric, 0)) as a_favor
                           from jsonb_each_text(k.pasivos) e
                           left join lateral (select sum(pp.monto) as s
                                                from public.nomina_pago_partes pp
                                                join public.nomina_pagos g on g.id = pp.pago_id
                                                join public.movimientos_banco m on m.id = g.movimiento_id
                                               where pp.corrida_id = k.id and pp.cuenta = e.key and g.estado = 'aplicado'
                                                 and m.asiento_id = g.asiento_id and m.estado in ('casado', 'en_transito')) pg on true) pd on true
     where k.id = $1$q$ into v using p_corrida;
  return coalesce(v, 'ninguna');
end $$;
-- (cuál es la última —posteada, con día de pago hasta hoy— y cuál la próxima —la primera que la nómina ya tiene, posteada o
--  importada, con día de pago después de hoy—, por las tablas de c15)
create or replace function pg_temp.c16_nom_cual(p_que text) returns uuid language plpgsql as $$
declare
  v uuid; v_hoy date := fn_fecha_miami(now());
begin
  if to_regclass('public.nomina_corridas') is null then
    return null;
  end if;
  if p_que = 'ultima' then
    execute $q$select k.id from public.nomina_corridas k where k.estado = 'posteada' and k.dia_pago <= $1
                order by k.dia_pago desc, k.asiento_numero desc limit 1$q$ into v using v_hoy;
  else
    execute $q$select k.id from public.nomina_corridas k where k.estado in ('importada', 'posteada') and k.dia_pago > $1
                order by k.dia_pago, k.importada_el, k.id limit 1$q$ into v using v_hoy;
  end if;
  return v;
end $$;
-- LOS MOVIMIENTOS DE GUSTO QUE ESPERAN EN EL BANCO, de la vista de la página
-- (v_nomina_cargos de c15): los cargos pendientes, las devoluciones (un
-- depósito: monto en negativo) y los que se des-casaron en la Bandeja.
create or replace function pg_temp.c16_nom_cargos() returns text language plpgsql as $$
declare
  v text;
begin
  execute $q$
    select format('%s por %s desde %s · devoluciones %s por %s · des-casados %s',
                  count(*) filter (where g.estado = 'pendiente' and g.monto > 0),
                  pg_temp.c16_m(coalesce(sum(g.monto) filter (where g.estado = 'pendiente' and g.monto > 0), 0)),
                  coalesce((min(g.fecha) filter (where g.estado = 'pendiente' and g.monto > 0))::text, '—'),
                  count(*) filter (where g.estado = 'pendiente' and g.monto < 0),
                  pg_temp.c16_m(coalesce(-sum(g.monto) filter (where g.estado = 'pendiente' and g.monto < 0), 0)),
                  count(*) filter (where g.estado = 'descasado'))
      from public.v_nomina_cargos g$q$ into v;
  return v;
end $$;
-- (cuántas cosas de la nómina esperan a Edgar: las importadas sin postear, los cargos y las devoluciones de Gusto por casar y los
--  des-casados; lo que cuenta su acción rápida con el código)
create or replace function pg_temp.c16_nom_esperan() returns int language plpgsql as $$
declare
  v int;
begin
  execute $q$select (select count(*) from public.nomina_corridas k where k.estado = 'importada')
                    + (select count(*) from public.v_nomina_cargos g where g.estado in ('pendiente', 'descasado') and g.monto <> 0)$q$ into v;
  return v;
end $$;

-- (lo que la tarjeta dice de cuándo sale lo que se debe, en una línea: como c16_nom_pagos_txt)
create or replace function pg_temp.c16_nom_sale_de(n jsonb) returns text language sql as $$
  select coalesce((select string_agg(case when (x ->> 'de_hoy')::boolean then 'hoy ' || pg_temp.c16_mj(x -> 'monto')
                                          else format('%s %s (%s)', x ->> 'fecha', pg_temp.c16_mj(x -> 'monto'), x ->> 'asiento') end, ', ' order by o)
                     from jsonb_array_elements(n -> 'debe' -> 'pagos') with ordinality t(x, o)), 'nada')
$$;
-- (las cuentas de lo que se debe suman su total; lo que sale —si se debe algo—, también; lo de hoy más lo de después es el total;
--  y el total menos lo que dice el Balance es lo de reembolsos que va aparte, menos lo del renglón que no es de la nómina)
create or replace function pg_temp.c16_nom_suma(n jsonb) returns text language sql as $$
  select case when (select coalesce(sum((x ->> 'monto')::numeric), 0) from jsonb_array_elements(n -> 'debe' -> 'cuentas') x) = (n -> 'debe' ->> 'monto')::numeric
                   and ((n -> 'debe' ->> 'monto')::numeric <= 0
                        or (select coalesce(sum((x ->> 'monto')::numeric), 0) from jsonb_array_elements(n -> 'debe' -> 'pagos') x)
                           = (n -> 'debe' ->> 'monto')::numeric)
                   and (n -> 'debe' ->> 'a_hoy')::numeric + (n -> 'debe' ->> 'despues')::numeric = (n -> 'debe' ->> 'monto')::numeric
                   and (n -> 'debe' ->> 'monto')::numeric - (n -> 'debe' ->> 'libro')::numeric
                       = coalesce((nullif(n -> 'debe' -> 'aparte', 'null'::jsonb) ->> 'monto')::numeric, 0)
                         - coalesce((nullif(n -> 'debe' -> 'otras', 'null'::jsonb) ->> 'monto')::numeric, 0)
              then 'sí' else 'no' end
$$;
-- LO QUE SALE POR LA NÓMINA CADA MES DE LA PROYECCIÓN (p_meses meses, contando el de hoy), de la cuenta de arriba; y lo mismo, de
-- la tarjeta de la caja.
create or replace function pg_temp.c16_nom_por_mes(p_meses int) returns text language sql as $$
  select string_agg(to_char(g.mes, 'YYYY-MM') || ' '
                    || pg_temp.c16_m(coalesce((select sum(p.monto) from pg_temp.c16_nom_pagos() p where date_trunc('month', p.fecha) = g.mes), 0)),
                    ', ' order by g.mes)
    from generate_series(date_trunc('month', fn_fecha_miami(now())::timestamp),
                         date_trunc('month', fn_fecha_miami(now())::timestamp) + make_interval(months => p_meses - 1), interval '1 month') g(mes)
$$;
create or replace function pg_temp.c16_nom_por_mes_de(c jsonb) returns text language sql as $$
  select coalesce(string_agg((m ->> 'mes') || ' ' || pg_temp.c16_mj(m -> 'nomina'), ', ' order by o), 'sin proyección')
    from jsonb_array_elements(c -> 'proyeccion' -> 'meses') with ordinality t(m, o)
$$;

-- LA TARJETA DE LA NÓMINA, DICHA EN UNA LÍNEA (lo que contestó c16) y lo
-- mismo ESPERADO, de las consultas de arriba (con el código del teléfono).
create or replace function pg_temp.c16_nom_una_de(u jsonb) returns text language sql as $$
  select case when u is null or jsonb_typeof(u) = 'null' then 'ninguna'
              when not coalesce((u ->> 'con_codigo')::boolean, false)
                then format('sin sus totales: %s · asiento %s', u ->> 'dia_pago', coalesce(u ->> 'asiento', '—'))
              else format('%s · %s · %s · %s personas · costo %s · bruto %s · patrón %s · impuestos %s · neto %s · deducciones %s · reembolsos %s · '
                          'por pagar %s · a favor %s · asiento %s',
                          u ->> 'estado', u ->> 'dia_pago', coalesce((u ->> 'periodo_desde') || ' a ' || (u ->> 'periodo_hasta'), 'sin período'),
                          u ->> 'personas', pg_temp.c16_mj(u -> 'costo'), pg_temp.c16_mj(u -> 'bruto'), pg_temp.c16_mj(u -> 'patron'),
                          pg_temp.c16_mj(u -> 'impuestos'), pg_temp.c16_mj(u -> 'neto'), pg_temp.c16_mj(u -> 'deducciones'),
                          pg_temp.c16_mj(u -> 'reembolsos'), pg_temp.c16_mj(u -> 'por_pagar'), pg_temp.c16_mj(u -> 'a_favor'),
                          coalesce(u ->> 'asiento', '—')) end
$$;
create or replace function pg_temp.c16_nom_dice(n jsonb) returns text language sql as $$
  select case when (n ->> 'ok')::boolean is not true then 'la tarjeta no contestó: ' || coalesce(n ->> 'motivo', '?')
    else format('con el código: %s | meses: %s | se debe %s (en el Balance %s; aparte %s): %s | sale: %s | la bolsa %s (del mes pasado: %s) | '
                'los cargos: %s | por postear: %s | la última: %s | la próxima: %s | cuadres en rojo %s, sin comprobar %s',
      case when (n ->> 'con_codigo')::boolean then 'sí' else 'no' end,
      coalesce((select string_agg(format('%s %s (%s + %s), %s', x ->> 'mes', pg_temp.c16_mj(x -> 'costo'), pg_temp.c16_mj(x -> 'sueldos'),
                                         pg_temp.c16_mj(x -> 'patron'), x ->> 'nominas'), '; ' order by o)
                  from jsonb_array_elements(n -> 'meses') with ordinality t(x, o)), 'ninguno'),
      pg_temp.c16_mj(n -> 'debe' -> 'monto'), pg_temp.c16_mj(n -> 'debe' -> 'libro'),
      case when n -> 'debe' -> 'aparte' is null or jsonb_typeof(n -> 'debe' -> 'aparte') = 'null' then '0.00'
           else pg_temp.c16_mj(n -> 'debe' -> 'aparte' -> 'monto') end,
      coalesce((select string_agg((x ->> 'cuenta') || ' ' || pg_temp.c16_mj(x -> 'monto'), ', ' order by x ->> 'cuenta')
                  from jsonb_array_elements(n -> 'debe' -> 'cuentas') x), 'ninguna'),
      pg_temp.c16_nom_sale_de(n),
      pg_temp.c16_mj(n -> 'bolsa' -> 'monto'),
      case when n -> 'bolsa' -> 'mes' is null or jsonb_typeof(n -> 'bolsa' -> 'mes') = 'null' then 'nada'
           else format('%s, %s', pg_temp.c16_mj(n -> 'bolsa' -> 'mes' -> 'monto'),
                       case n -> 'bolsa' -> 'mes' ->> 'puede' when 'true' then 'ya se puede repartir' when 'false' then 'todavía no se puede repartir'
                            else 'sin decir si se puede repartir' end) end,
      format('%s por %s desde %s · devoluciones %s por %s · des-casados %s', n -> 'cargos' ->> 'n', pg_temp.c16_mj(n -> 'cargos' -> 'monto'),
             coalesce(n -> 'cargos' ->> 'mas_viejo', '—'), n -> 'cargos' -> 'devoluciones' ->> 'n',
             pg_temp.c16_mj(n -> 'cargos' -> 'devoluciones' -> 'monto'), coalesce(n -> 'cargos' ->> 'descasados', 'no se sabe')),
      case when n -> 'por_postear' is null or jsonb_typeof(n -> 'por_postear') = 'null' then 'no se sabe'
           else format('%s (%s a %s)', n -> 'por_postear' ->> 'n', coalesce(n -> 'por_postear' ->> 'primero', '—'),
                       coalesce(n -> 'por_postear' ->> 'ultimo', '—')) end,
      pg_temp.c16_nom_una_de(n -> 'ultima'), pg_temp.c16_nom_una_de(n -> 'proxima'),
      n -> 'control' ->> 'cuadres_rojos', n -> 'control' ->> 'sin_comprobar') end
$$;
create or replace function pg_temp.c16_nom_espera() returns text language plpgsql as $$
declare
  d jsonb := pg_temp.c16_nom_debe(); v_bol numeric; v_pp text; v_ctl jsonb; b jsonb; v_bm text := 'nada';
begin
  -- (lo de la bolsa del último mes terminado lo dice la nómina, c15, con el código: lo que queda de ese mes —como mucho lo que hoy
  --  hay— y si ya se puede repartir; sin un mes terminado en el libro contesta con un error: entonces, nada)
  begin
    b := pg_temp.c16_j('select public.fn_nomina_bolsa(null)');
    if b ->> 'mes' = to_char(date_trunc('month', fn_fecha_miami(now())) - interval '1 month', 'YYYY-MM') and (b ->> 'saldo')::numeric <> 0 then
      v_bm := format('%s, %s', pg_temp.c16_mj(b -> 'saldo'),
                     case when (b ->> 'puede')::boolean then 'ya se puede repartir' else 'todavía no se puede repartir' end);
    end if;
  exception when others then
    perform pg_temp.c16_ser('editor');
  end;
  execute $q$select coalesce(sum(l.monto), 0) from public.asiento_lineas l
              where l.cuenta = (select c.cuenta_bolsa from public.nomina_config c where c.id = 1)$q$ into v_bol;
  execute $q$select format('%s (%s a %s)', count(*), coalesce(min(k.dia_pago)::text, '—'), coalesce(max(k.dia_pago)::text, '—'))
               from public.nomina_corridas k where k.estado = 'importada'$q$ into v_pp;
  -- (los cuadres de la nómina, como los ve el dueño con su código en su página: su control entero)
  v_ctl := pg_temp.c16_j($q$select jsonb_build_object('c', count(*) filter (where k.nivel = 'cuadre' and k.ok is not true))
                               from public.v_nomina_control k$q$);
  return format('con el código: sí | meses: %s | se debe %s (en el Balance %s; aparte %s): %s | sale: %s | la bolsa %s (del mes pasado: %s) | '
                'los cargos: %s | por postear: %s | la última: %s | la próxima: %s | cuadres en rojo %s, sin comprobar 0',
                pg_temp.c16_nom_meses(6), pg_temp.c16_mj(d -> 'monto'), pg_temp.c16_mj(d -> 'libro'), pg_temp.c16_mj(d -> 'aparte'), d ->> 'cuentas',
                pg_temp.c16_nom_pagos_txt(), pg_temp.c16_m(v_bol), v_bm, pg_temp.c16_nom_cargos(), v_pp,
                pg_temp.c16_nom_una(pg_temp.c16_nom_cual('ultima')), pg_temp.c16_nom_una(pg_temp.c16_nom_cual('proxima')),
                v_ctl ->> 'c');
end $$;
-- (la tarjeta de la nómina, como el dueño con su código —o sin él: 'dueno_aal1'—)
create or replace function pg_temp.c16_nom_tarjeta(p_quien text default 'dueno') returns jsonb language sql as $$
  select pg_temp.c16_j('select public.fn_tablero_nomina()', p_quien)
$$;

-- LOS CONTROLES DE LAS OTRAS CAPAS que están en rojo: la cadena (c2), los
-- puentes (c3), los estados (c4), el banco (c6), los cuadres de la IA (c8),
-- los del jornal y el margen (c10), los de las facturas (c11), los del WIP
-- (c12), los de los subs (c14), los de la nómina (c15; 14-nov) y lo que
-- detiene el cierre del mes (c9);
-- cada una, si está. Como el SQL Editor, dentro de un bloque que se deshace
-- (la revisión del cierre de c9 guarda lo que encuentra: estas pruebas no
-- dejan nada, ni eso).
create or replace function pg_temp.c16_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
  v_mes text := pg_temp.c16('mes');
begin
  perform pg_temp.c16_ser('editor');
  begin
    select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
    v := v || x;
    select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
    v := v || x;
    if to_regprocedure('public.fn_estados_control(text,text[])') is not null then
      execute $q$ select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') from public.fn_estados_control('hoy') k where not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regprocedure('public.fn_banco_control(text,text[])') is not null then
      execute $q$ select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') from public.fn_banco_control('hoy') k where not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regclass('public.v_contador_control') is not null then
      execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                    from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regclass('public.v_jornal_control') is not null and to_regclass('public.v_margen_control') is not null then
      execute $q$ select coalesce(array_agg('c10: ' || k.c order by k.c), '{}')
                    from (select 'jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                          union all
                          select 'margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k $q$ into x;
      v := v || x;
    end if;
    if to_regclass('public.v_emision_control') is not null then
      execute $q$ select coalesce(array_agg('c11: ' || k.orden order by k.orden), '{}')
                    from public.v_emision_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regprocedure('public.fn_wip_control(text)') is not null and v_mes is not null then
      execute $q$ select coalesce(array_agg('c12: ' || k.orden order by k.orden), '{}')
                    from public.fn_wip_control($1) k where k.nivel = 'cuadre' and not k.ok $q$ into x using v_mes;
      v := v || x;
    end if;
    if to_regclass('public.v_subs_control') is not null then
      execute $q$ select coalesce(array_agg('c14: ' || k.orden order by k.orden), '{}')
                    from public.v_subs_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regclass('public.v_nomina_control') is not null then
      execute $q$ select coalesce(array_agg('c15: ' || k.orden order by k.orden), '{}')
                    from public.v_nomina_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
      v := v || x;
    end if;
    if to_regprocedure('public.fn_cierre_revisar(text)') is not null and v_mes is not null then
      execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                    from public.fn_cierre_revisar($1) k where k.nivel = 'detiene' and k.ok is distinct from true $q$ into x using v_mes;
      v := v || x;
    end if;
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null;
  end;
  return v;
end $$;
create or replace function pg_temp.c16_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- LA HUELLA de lo que el tablero lee y de lo que siembran estas pruebas:
-- cuántas filas tiene cada una de esas tablas (las que estén), el reloj y
-- cuántas funciones hay. Con ella se ve que el tablero solo lee (la 34) y que
-- nada queda (la 37). (Si la app escribe mientras corre la suite —un recibo
-- que sube alguien—, puede cambiar: se vuelve a pegar en un momento
-- tranquilo.)
create or replace function pg_temp.c16_huella() returns text language plpgsql as $$
declare
  t text; n bigint; v text := '';
begin
  foreach t in array array['asientos', 'asiento_lineas', 'contadores', 'periodos', 'cuentas', 'estados_mapeo', 'proyectos', 'finanzas_proyecto',
                           'facturas', 'cobros', 'cobros_devoluciones', 'aplicaciones_cobro', 'puente_documentos', 'mapeo_tipo_proyecto',
                           'movimientos_banco', 'banco_casados', 'banco_casado_lineas', 'archivos_banco', 'conciliaciones', 'prestamos',
                           'prestamo_cuotas', 'plaid_conexiones', 'stripe_config', 'stripe_pagos', 'stripe_payouts', 'stripe_enlaces',
                           'contador_config', 'cierre_revisiones', 'emision_config', 'emision_documentos', 'wip_ajustes', 'wip_revisiones',
                           -- (14-nov, Fase 11c) lo que la tarjeta de la nómina lee y lo que sus pruebas siembran
                           'perfiles', 'nomina_config', 'nomina_columnas', 'nomina_archivos', 'nomina_personas', 'nomina_corridas',
                           'nomina_corrida_personas', 'nomina_lineas', 'nomina_pagos', 'nomina_pago_partes', 'nomina_historial'] loop
    if to_regclass('public.' || t) is not null then
      execute format('select count(*) from public.%I', t) into n;
      v := v || t || '=' || n || ' ';
    end if;
  end loop;
  return v || '· reloj ' || left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12)
         || ' · funciones ' || (select count(*) from pg_proc where pronamespace = 'public'::regnamespace)
         || ' · obras de prueba ' || (select count(*) from proyectos where id like 'c16-prueba-%')
         || ' · asientos de prueba ' || (select count(*) from asientos where descripcion like 'C16 PRUEBA%')
         || ' · personas de prueba ' || (select count(*) from perfiles where nombre like 'ZZ C16 Prueba%');
end $$;

-- (14-nov, Fase 11c) ¿QUEDÓ ALGO DE LA NÓMINA DE PRUEBA? Sus personas, sus archivos, sus usuarios o sus cargos de Gusto en el
-- banco (por EXECUTE: en una base sin c15 o sin c6, esas tablas no existen).
create or replace function pg_temp.c16_quedo_de_la_nomina() returns boolean language plpgsql as $$
declare
  v boolean := false; x boolean;
begin
  if to_regclass('public.nomina_personas') is not null then
    execute $q$select exists (select 1 from public.nomina_personas p where p.nombre like 'ZZ C16 Prueba%')
                   or exists (select 1 from public.nomina_archivos a where a.nombre like 'zz-c16-prueba-%')$q$ into x;
    v := v or x;
  end if;
  if to_regclass('public.movimientos_banco') is not null then
    execute $q$select exists (select 1 from public.movimientos_banco m where m.id_externo like 'zz-c16-prueba-%')$q$ into x;
    v := v or x;
  end if;
  if to_regclass('auth.users') is not null then
    execute $q$select exists (select 1 from auth.users u where u.email like '%@c16-pruebas.invalid')$q$ into x;
    v := v or x;
  end if;
  return v;
end $$;

-- EN LLANO (lo que mira la 35, en una función: la usan también las de la
-- nómina). De un jsonb del tablero, los textos para Edgar (texto, detalle,
-- nota, regla, fuente, motivo, etiqueta, titulo, aviso, cuantas, que_es,
-- sin_comparar, alarma_texto, por_que_no, sin_proyeccion, supuestos) que
-- dicen el nombre de una función, una vista o una columna, «null», llaves
-- de JSON, un mensaje de error de la base, un código o un secreto en
-- mayúsculas, una fecha AAAA-MM-DD, un plural a medias, un texto cortado,
-- «ráfaga» o «partidas». Nulo si ninguno. (Un nombre de la base en
-- minúsculas fuera de unas comillas «»: lo que va entre «» es una etiqueta
-- que Edgar ve tal cual en otra página.)
create or replace function pg_temp.c16_llano(t jsonb) returns text language sql as $$
  with s as (
    select k, x #>> '{}' as s
      from unnest(array['texto', 'detalle', 'nota', 'regla', 'fuente', 'motivo', 'etiqueta', 'titulo', 'aviso', 'cuantas', 'que_es',
                        'sin_comparar', 'alarma_texto', 'por_que_no', 'sin_proyeccion']) k,
           lateral jsonb_path_query(t, ('strict $.**.' || k)::jsonpath) x
     where jsonb_typeof(x) = 'string'
    union all
    select 'supuestos', x #>> '{}' from jsonb_path_query(t, 'strict $.**.supuestos[*]') x where jsonb_typeof(x) = 'string'
  )
  select string_agg(distinct k || ': «' || left(s.s, 120) || '»', ' · ')
    from s
   where s.s ~* '(\mfn_[a-z]|\mv_[a-z]+_|\mnull\M|\mnan\M|undefined|[{}]|\msqlstate\M|\mjsonb?\M|\mselect\M|\mpg_|permission denied|does not exist)'
      or regexp_replace(s.s, '«[^»]*»', '', 'g') ~ '\m[a-z]+_[a-z_]+\M'
      -- (un código o un secreto en mayúsculas, una fecha AAAA-MM-DD, un plural a medias, un texto cortado, jerga)
      or s.s ~ '\m[A-Z][A-Z0-9]+(_[A-Z0-9]+)+\M'
      or s.s ~ '\m[0-9]{4}-[0-9]{2}-[0-9]{2}\M'
      or s.s ~ '\((s|es)\)'
      or s.s like '%…%'
      or s.s ~* '\mráfaga|\mpartidas?\M'
$$;
insert into _c16 values ('huella', pg_temp.c16_huella());

-- (lo de las otras capas que ya estaba en rojo SIN c16: se quita c16 dentro de un bloque que se deshace y se miran los
--  controles; la 36 compara con esto lo de ahora, con c16 puesto y después de todas las pruebas)
do $$
declare
  v text[];
  r record;
  e text;
begin
  begin
    for r in select p.oid::regprocedure as f from pg_proc p
              where p.pronamespace = 'public'::regnamespace
                and replace(p.oid::regprocedure::text, 'public.', '') = any (fn_tablero_funciones()) loop
      execute format('drop function %s', r.f);
    end loop;
    v := pg_temp.c16_rojos();
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then e := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c16 values ('rojos_sin_c16', coalesce(array_to_string(v, '; '), '¿? ' || e));
end $$;
-- (las funciones AJENAS a c16 que «permisos» de c2 ya marcaba: la 4 las dice y no las cuenta)
create or replace function pg_temp.c16_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_c16 text;
begin
  select k.ok, left(k.detalle::text, 400) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  -- (rojo: ¿por algo de c16?)
  select string_agg(x.t, ' · ') into v_c16
    from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle -> 'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok and x.t ~ 'fn_tablero';
  if v_c16 is null then return 'verde para c16 (en rojo por otra cosa: ' || left(v_det, 200) || ')'; end if;
  return 'rojo: ' || left(v_c16, 300);
end $$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: nada falta, las funciones por su firma exacta (no por el
--    prefijo: otra sesión escribe esta base), cada una con su comentario
--    «c16: …», ninguna otra con nombre de c16, ninguna tabla ni vista, la
--    tabla final del pegado (6 filas) y la marca.
do $$
declare
  v_obt text; v_esp text; v_pre text; v_fn int; v_com int; v_falta text; v_otras int; v_tab int; v_peg int;
  v_tot int := cardinality(fn_tablero_funciones());
begin
  v_esp := format('precondiciones: nada falta | funciones: %1$s de %1$s (%1$s con su comentario «c16: …») | otras con nombre de c16: 0 | '
                  'tablas o vistas de c16: 0 | el pegado: 6 filas | marca: 2026111403', v_tot);
  begin
    v_pre := fn_tablero_precondiciones();
    select count(*) filter (where to_regprocedure('public.' || f) is not null),
           count(*) filter (where coalesce(obj_description(to_regprocedure('public.' || f), 'pg_proc'), '') like 'c16: %'),
           string_agg(f, ', ') filter (where to_regprocedure('public.' || f) is null)
      into v_fn, v_com, v_falta
      from unnest(fn_tablero_funciones()) f;
    select count(*) into v_otras from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_tablero%'
       and not (replace(p.oid::regprocedure::text, 'public.', '') = any (fn_tablero_funciones()));
    select count(*) into v_tab from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p')
       and (c.relname like 'tablero\_%' or c.relname like 'v\_tablero%' or coalesce(obj_description(c.oid, 'pg_class'), '') like 'c16: %');
    select count(*) into v_peg from fn_tablero_pegado();
    v_obt := format('precondiciones: %s | funciones: %s de %s (%s con su comentario «c16: …»)%s | otras con nombre de c16: %s | '
                    'tablas o vistas de c16: %s | el pegado: %s filas | marca: %s',
                    coalesce(v_pre, 'nada falta'), v_fn, v_tot, v_com, coalesce(' faltan: ' || v_falta, ''), v_otras, v_tab, v_peg,
                    fn_tablero_version());
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'EL PEGADO: nada falta; las funciones de c16 por su firma exacta, cada una con su comentario «c16: …»; ninguna otra con nombre de c16; ninguna tabla ni vista (solo lee); la tabla final del pegado y la marca',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: sin una vista de c4 que lee (renombrada
--    dentro del bloque) lo dicen por su nombre, y la guarda del pegado para
--    con MX000; una función ajena con nombre de c16 (sin su comentario)
--    también: el pegado no la pisaría.
do $$
declare
  v_obt text; a text; b text; c text;
  v_esp text := 'sin v_cxp_antiguedad: la nombra | la guarda: MX000 | una función ajena con nombre de c16: la nombra';
begin
  begin
    execute 'alter view public.v_cxp_antiguedad rename to v_cxp_antiguedad_c16_prueba';
    a := case when fn_tablero_precondiciones() like '%falta%v_cxp_antiguedad%' then 'la nombra' else 'no: ' || coalesce(fn_tablero_precondiciones(), 'nada') end;
    begin
      -- (la guarda del pegado, tal cual)
      if fn_tablero_precondiciones() is not null then
        raise exception using errcode = 'MX000', message = 'c16-tablero NO se aplicó, no se tocó nada: ' || fn_tablero_precondiciones();
      end if;
      b := 'no paró';
    exception when sqlstate 'MX000' then b := 'MX000';
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if v_obt is null then
    begin
      execute 'create function public.fn_tablero_zz_c16_prueba() returns int language sql as $f$ select 1 $f$';
      c := case when fn_tablero_precondiciones() like '%con nombre de c16 y sin ser de c16: fn_tablero_zz_c16_prueba()%' then 'la nombra'
                else 'no: ' || coalesce(fn_tablero_precondiciones(), 'nada') end;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
    end;
  end if;
  v_obt := coalesce(v_obt, format('sin v_cxp_antiguedad: %s | la guarda: %s | una función ajena con nombre de c16: %s', a, b, c));
  insert into _pruebas values (2, 'LAS PRECONDICIONES EN ROJO: sin una vista de c4 que el tablero lee, lo dicen por su nombre y la guarda del pegado para con MX000; una función ajena con nombre de c16 también se dice (el pegado no la pisa)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. LA API: anon y service_role no pueden ejecutar ninguna función de c16
--    (ni la llamada les entra: 42501); alguien del equipo recibe 42501 en el
--    tablero y en cada tarjeta; el dueño entra en todas; el pegado y las
--    precondiciones no los ejecuta nadie por la API.
do $$
declare
  v_obt text; v_anon int; v_srv int; v_auth int; v_sin text; v_eq text; v_du text; v_k text;
  c_llamadas constant text[] := array['select public.fn_tablero()', 'select public.fn_tablero_acciones()', 'select public.fn_tablero_cobros()',
    'select public.fn_tablero_bancos()', 'select public.fn_tablero_resultados()', 'select public.fn_tablero_gastos()',
    'select public.fn_tablero_caja()', 'select public.fn_tablero_facturas()', 'select public.fn_tablero_ventas()',
    'select public.fn_tablero_antiguedad(''cobrar'')', 'select public.fn_tablero_antiguedad(''pagar'')', 'select public.fn_tablero_conexiones()',
    'select public.fn_tablero_cobros_en_linea()', 'select public.fn_tablero_use_tax()', 'select public.fn_tablero_prestamos()',
    'select public.fn_tablero_obras()', 'select public.fn_tablero_libro()', 'select count(*) from public.fn_tablero_cxc()',
    'select count(*) from public.fn_tablero_cxp()', 'select public.fn_tablero_stripe()', 'select public.fn_tablero_saldos()',
    -- (14-nov, Fase 11c) la tarjeta de la nómina y sus piezas
    'select public.fn_tablero_nomina()', 'select public.fn_tablero_nomina_estado()', 'select public.fn_tablero_nomina_debe()',
    'select count(*) from public.fn_tablero_nomina_pagos()', 'select public.fn_tablero_nomina_tapada()'];
  v_esp text;
begin
  v_esp := format('anon y service_role, funciones que pueden ejecutar: 0 y 0 | anon y service_role llaman al tablero: 42501 y 42501 | '
                  'authenticated, sin las dos del SQL Editor: %s de %s | el equipo, en las %s llamadas: %s | el dueño, en las %s: ok',
                  cardinality(fn_tablero_funciones()) - 2, cardinality(fn_tablero_funciones()) - 2, cardinality(c_llamadas),
                  case when pg_temp.c16('equipo') is null then 'sin nadie del equipo en perfiles' else '42501' end, cardinality(c_llamadas));
  begin
    select count(*) filter (where has_function_privilege('anon', to_regprocedure('public.' || f), 'execute')),
           count(*) filter (where has_function_privilege('service_role', to_regprocedure('public.' || f), 'execute')),
           count(*) filter (where has_function_privilege('authenticated', to_regprocedure('public.' || f), 'execute')
                              and f not in ('fn_tablero_precondiciones()', 'fn_tablero_pegado()')),
           string_agg(f, ', ') filter (where (has_function_privilege('authenticated', to_regprocedure('public.' || f), 'execute'))
                                             = (f in ('fn_tablero_precondiciones()', 'fn_tablero_pegado()')))
      into v_anon, v_srv, v_auth, v_sin
      from unnest(fn_tablero_funciones()) f;
    if pg_temp.c16('equipo') is null then
      v_eq := 'sin nadie del equipo en perfiles';
    else
      select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'equipo'), ','), ''), '?') into v_eq from unnest(c_llamadas) x;
    end if;
    select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'dueno'), ','), ''), '?') into v_du from unnest(c_llamadas) x;
    v_obt := format('anon y service_role, funciones que pueden ejecutar: %s y %s | anon y service_role llaman al tablero: %s y %s | '
                    'authenticated, sin las dos del SQL Editor: %s de %s%s | el equipo, en las %s llamadas: %s | el dueño, en las %s: %s',
                    v_anon, v_srv, pg_temp.c16_estado('select public.fn_tablero()', 'anon'),
                    pg_temp.c16_estado('select public.fn_tablero()', 'service_role'), v_auth, cardinality(fn_tablero_funciones()) - 2,
                    coalesce(' (mal: ' || v_sin || ')', ''), cardinality(c_llamadas), v_eq, cardinality(c_llamadas), v_du);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'LA API: anon y service_role no ejecutan ninguna función de c16 (42501); alguien del equipo recibe 42501 en el tablero y en cada tarjeta; el dueño entra en todas; el pegado y las precondiciones no los ejecuta nadie por la API',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. EL CATÁLOGO: ninguna SECURITY DEFINER, todas con su search_path,
--    ninguna volátil (una función STABLE no puede escribir: el tablero solo
--    lee), todas fn_tablero_* (ningún prefijo de otra capa), y «permisos» de
--    c2 en verde con c16 puesto.
do $$
declare
  v_obt text; v_def text; v_sp text; v_vol text; v_nom text;
  v_esp text := 'definer: ninguna | sin search_path: ninguna | volátiles: ninguna | con otro nombre: ninguna | permisos (c2): verde';
begin
  begin
    select coalesce(string_agg(p.proname, ', ') filter (where p.prosecdef), 'ninguna'),
           coalesce(string_agg(p.proname, ', ') filter (where not exists (select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
                                                                           where c like 'search_path=%')), 'ninguna'),
           coalesce(string_agg(p.proname, ', ') filter (where p.provolatile = 'v' and p.proname <> 'fn_tablero_pegado'), 'ninguna'),
           coalesce(string_agg(p.proname, ', ') filter (where p.proname not like 'fn\_tablero%'), 'ninguna')
      into v_def, v_sp, v_vol, v_nom
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and replace(p.oid::regprocedure::text, 'public.', '') = any (fn_tablero_funciones());
    v_obt := format('definer: %s | sin search_path: %s | volátiles: %s | con otro nombre: %s | permisos (c2): %s',
                    v_def, v_sp, v_vol, v_nom, pg_temp.c16_permisos());
    if v_obt like '%permisos (c2): verde para c16%' then
      v_obt := regexp_replace(v_obt, 'permisos \(c2\): verde para c16 .*$', 'permisos (c2): verde') || ' (c2 ya en rojo por otra cosa)';
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'EL CATÁLOGO: ninguna función de c16 es SECURITY DEFINER, todas llevan su search_path, ninguna es volátil (no pueden escribir: el tablero solo lee; el pegado sí, y no tiene API), todas se llaman fn_tablero_* y «permisos» de c2 sigue en verde con c16 puesto',
    v_esp, v_obt, v_obt = v_esp or v_obt = v_esp || ' (c2 ya en rojo por otra cosa)');
end $$;

-- 5. EL TABLERO ENTERO, como el dueño: las 16 tarjetas en su orden, cada una
--    contesta (o dice qué capa no está, si es eso: ninguna falla), el libro
--    en llano («lo de antes vive en QuickBooks»), las capas, y nada en
--    «sigue» sin tope.
do $$
declare
  v_obt text; v_esp text; t jsonb; v_k text; v_ok int := 0; v_falta text[] := '{}'; v_mal text[] := '{}'; v_espf text[] := '{}';
  c_orden constant text[] := array['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar',
                                   'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras', 'nomina'];
begin
  -- (lo que debe decir que su capa no está, por las capas de esta base)
  if not pg_temp.c16_capa('c6') then v_espf := v_espf || 'bancos'::text; end if;
  if not pg_temp.c16_capa('p1') then v_espf := v_espf || 'cobros_en_linea'::text; end if;
  if not pg_temp.c16_capa('c9') then v_espf := v_espf || 'use_tax'::text; end if;
  if not pg_temp.c16_capa('c6_prestamos') then v_espf := v_espf || 'prestamos'::text; end if;
  if not pg_temp.c16_capa('c10') and not pg_temp.c16_capa('c12') then v_espf := v_espf || 'obras'::text; end if;
  -- (14-nov, Fase 11c) la de la nómina, sin c15
  if not pg_temp.c16_hay_c15() then v_espf := v_espf || 'nomina'::text; end if;
  v_esp := format('ok: true | las tarjetas, en su orden: sí | contestan: %s | dicen qué capa no está: %s | fallan: ninguna | el libro: en llano | '
                  'capas: las de esta base | sigue: nada', 16 - cardinality(v_espf),
                  coalesce(nullif(array_to_string(v_espf, ', '), ''), 'ninguna'));
  begin
    t := pg_temp.c16_t();
    foreach v_k in array c_orden loop
      if (t -> v_k ->> 'ok')::boolean then
        v_ok := v_ok + 1;
      elsif t -> v_k ? 'falta' then
        v_falta := v_falta || v_k;
      else
        v_mal := v_mal || (v_k || ' (' || coalesce(t -> v_k ->> 'motivo', '?') || ')');
      end if;
    end loop;
    v_obt := format('ok: %s | las tarjetas, en su orden: %s | contestan: %s | dicen qué capa no está: %s | fallan: %s | el libro: %s | '
                    'capas: %s | sigue: %s',
                    t ->> 'ok', case when t -> 'tarjetas' = to_jsonb(c_orden) then 'sí' else 'no: ' || (t ->> 'tarjetas') end, v_ok,
                    coalesce(nullif(array_to_string(v_falta, ', '), ''), 'ninguna'),
                    coalesce(nullif(array_to_string(v_mal, '; '), ''), 'ninguna'),
                    case when t -> 'libro' ->> 'texto' like '%QuickBooks%' or t -> 'libro' ->> 'texto' = 'El libro no tiene períodos todavía.'
                         then 'en llano' else coalesce(t -> 'libro' ->> 'texto', 'no lo dice') end,
                    case when t -> 'capas' = pg_temp.c16('capas')::jsonb then 'las de esta base' else 'otras: ' || (t ->> 'capas') end,
                    case when jsonb_array_length(t -> 'sigue') = 0 then 'nada' else t ->> 'sigue' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'EL TABLERO ENTERO, como el dueño: las 16 tarjetas en su orden; cada una contesta, o dice que su capa no está (ninguna falla); el libro en llano («lo de antes vive en QuickBooks»); las capas de esta base; sin tope, nada en «sigue»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. RÁPIDO: una pasada entera como el dueño por la API, con el tope de
--    fábrica (4 s), contesta en menos de 2 s y nada se queda en «sigue». (La
--    meta es menos de 1 s: en el banco, 0.27 s con el libro de la semilla y
--    0.55 a 0.65 s con un libro de 3,600 asientos, pruebas/conta/
--    c16-volumen.sh; aquí se deja holgura para un servidor ocupado.)
do $$
declare
  v_obt text; t jsonb; v_t0 timestamptz; v_ms int;
  v_esp text := 'menos de 2 s: sí | sigue: nada | el tablero dice lo que tardó: sí';
begin
  begin
    v_t0 := clock_timestamp();
    t := pg_temp.c16_j('select public.fn_tablero()');
    v_ms := round(extract(epoch from clock_timestamp() - v_t0) * 1000)::int;
    v_obt := format('menos de 2 s: %s | sigue: %s | el tablero dice lo que tardó: %s',
                    case when v_ms < 2000 then 'sí' else 'no' end,
                    case when jsonb_array_length(t -> 'sigue') = 0 then 'nada' else t ->> 'sigue' end,
                    case when (t ->> 'ms')::int <= v_ms + 5 then 'sí' else 'no' end);
    insert into _c16 values ('ms', v_ms::text) on conflict (k) do update set v = excluded.v;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'RÁPIDO: una pasada entera del tablero como el dueño por la API (con el tope de fábrica) en menos de 2 s, sin nada en «sigue» (la meta es 1 s: en el banco, 0.27 s con la semilla y 0.55 a 0.65 s con 3,600 asientos)',
    v_esp, v_obt || coalesce(' (tardó ' || pg_temp.c16('ms') || ' ms)', ''), v_obt = v_esp);
end $$;

-- EL TABLERO DE HOY, una vez para las pruebas 7 a 24 (como el dueño, sin
-- tope): cada una compara su tarjeta con lo que dice el libro.
do $$
begin
  begin
    insert into _c16 values ('t', pg_temp.c16_t()::text);
  exception when others then
    insert into _c16 values ('t_error', sqlstate || ': ' || sqlerrm);
  end;
end $$;
create or replace function pg_temp.c16_tc(k text) returns jsonb language sql as $$ select pg_temp.c16('t')::jsonb -> k $$;

-- 7. LAS ACCIONES RÁPIDAS: cada una con su número de donde sale (los
--    borradores y por dónde se factura, de c11; lo que espera en la Bandeja y
--    las cuentas por conciliar, de c6; los enlaces de pago activos, de p1; el
--    mes que toca cerrar y lo que lo detiene, de c9; y —14-nov— lo de la
--    nómina que espera a Edgar, de c15: las importadas sin postear, los
--    cargos y las devoluciones de Gusto por casar y los des-casados).
do $$
declare
  v_obt text; v_esp text; a jsonb := pg_temp.c16_tc('acciones'); r record;
  v_ocultas text[] := '{}'; v_fin date := date_trunc('month', pg_temp.c16_hoy())::date - 1;
  e_fac text; e_ban text; e_con text; e_pag text; e_cie text; e_nom text;
begin
  begin
    if pg_temp.c16_capa('p1') then
      execute 'select array_remove(array[c.cuenta_puente, c.cuenta_paso], null) from public.stripe_config c where c.id = 1' into v_ocultas;
    end if;
    -- (lo de las capas que pueden faltar, por EXECUTE: sin ellas, sus vistas no existen)
    e_fac := 'false';
    if pg_temp.c16_capa('c11') then
      execute $q$select format('true %s %s', coalesce(e.borradores, 0), e.camino) from public.v_emision_estado e$q$ into e_fac;
    end if;
    if pg_temp.c16_capa('c6') then
      -- (la Bandeja, contada como su página: todas las filas de v_banco_bandeja)
      execute $q$select format('true %s %s', count(*), coalesce(min(b.fecha)::text, '—')) from public.v_banco_bandeja b$q$
        into e_ban;
      execute $q$select format('true %s', count(*)) from public.v_banco_saldos s
                  where s.activa and s.ultimo_importado_el is not null and not (s.cuenta = any ($1))
                    and coalesce(s.ultima_confirmada, date '1900-01-01') < $2$q$ into e_con using v_ocultas, v_fin;
    else
      e_ban := 'false'; e_con := 'false';
    end if;
    e_pag := 'false';
    if pg_temp.c16_capa('p1') then
      execute $q$select format('true %s', count(*)) from public.stripe_enlaces e where e.estado = 'activo'$q$ into e_pag;
    end if;
    if pg_temp.c16_capa('c9') then
      execute $q$select format('true %s %s', coalesce(e.detienen, 0), coalesce(e.periodo, '—'))
                   from (select 1) u left join lateral (select * from public.v_cierre_estado x where x.siguiente order by x.desde limit 1) e on true$q$
        into e_cie;
    else
      e_cie := 'false';
    end if;
    -- (14-nov, Fase 11c: la nómina, con el código; sin c15, no disponible)
    e_nom := 'false';
    if pg_temp.c16_hay_c15() then
      e_nom := format('true %s', pg_temp.c16_nom_esperan());
    end if;
    v_esp := format('factura: %s | bandeja: %s | conciliar: %s | pago: %s | nómina: %s | cierre: %s | estados: true',
                    e_fac, e_ban, e_con, e_pag, e_nom, e_cie);
    select format('factura: %s | bandeja: %s | conciliar: %s | pago: %s | nómina: %s | cierre: %s | estados: %s',
             max(case when x ->> 'clave' = 'factura' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', x ->> 'camino') else 'false' end end),
             max(case when x ->> 'clave' = 'bandeja' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', coalesce(x ->> 'mas_viejo', '—')) else 'false' end end),
             max(case when x ->> 'clave' = 'conciliar' then case when (x ->> 'disponible')::boolean then format('true %s', x ->> 'n') else 'false' end end),
             max(case when x ->> 'clave' = 'pago' then case when (x ->> 'disponible')::boolean then format('true %s', x ->> 'n') else 'false' end end),
             max(case when x ->> 'clave' = 'nomina' then case when (x ->> 'disponible')::boolean then format('true %s', x ->> 'n') else 'false' end end),
             max(case when x ->> 'clave' = 'cierre' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', coalesce(x ->> 'periodo', '—')) else 'false' end end),
             max(case when x ->> 'clave' = 'estados' then x ->> 'disponible' end))
      into v_obt
      from jsonb_array_elements(a -> 'lista') x;
    if (a ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(a ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'ACCIONES RÁPIDAS: crear una factura (los borradores y por dónde se factura, c11), la Bandeja (lo que espera y desde cuándo, contado como su página: v_banco_bandeja, c6), conciliar (las cuentas con banco sin conciliar hasta el fin del mes pasado, c6), pedir un pago en línea (los enlaces activos, p1), la nómina (lo suyo que espera: las importadas sin postear y los cargos y devoluciones de Gusto por casar, c15), cerrar el mes (el que toca y lo que lo detiene, c9) y los estados',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 8. EL EMBUDO DE COBRO contra el libro, al centavo: lo por cobrar (las
--    partidas de 1110 con saldo, cuántas facturas, cuántas vencidas por su
--    vencimiento), la retención y lo que hay a favor aparte, y todo junto =
--    el saldo de las cuentas por cobrar; lo cobrado en los últimos 30 días
--    (los cobros vigentes menos lo devuelto) y de eso lo que está en el banco
--    (casado con su movimiento; el de Stripe, con su depósito casado); los
--    tres pasos con esas mismas cifras.
do $$
declare
  v_obt text; v_esp text; c jsonb := pg_temp.c16_tc('cobros'); r record; k record; v_libro numeric;
  v_hoy date := pg_temp.c16_hoy();
begin
  begin
    select pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por > 0), 0)) as monto, count(*) filter (where x.por > 0) as n,
           count(*) filter (where x.por > 0 and x.pt = 'facturas') as fact,
           pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por > 0 and pg_temp.c16_tramo(x.vence) in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)) as venc,
           count(*) filter (where x.por > 0 and pg_temp.c16_tramo(x.vence) in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_venc,
           pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por < 0), 0)) as favor, count(*) filter (where x.por < 0) as n_favor,
           pg_temp.c16_m(coalesce(sum(x.ret), 0)) as ret, count(*) filter (where x.ret <> 0) as n_ret
      into r from pg_temp.c16_cxc() x;
    select pg_temp.c16_m(coalesce(sum(y.neto) filter (where y.neto > 0), 0)) as monto, count(*) filter (where y.neto > 0) as n,
           (select count(distinct f) from pg_temp.c16_cobros(v_hoy - 29, v_hoy) z, unnest(z.facturas) f where z.neto > 0) as fact,
           pg_temp.c16_m(coalesce(sum(y.neto) filter (where y.neto > 0 and y.en_banco), 0)) as dep,
           count(*) filter (where y.neto > 0 and y.en_banco) as n_dep,
           pg_temp.c16_m(coalesce(sum(y.neto) filter (where y.neto > 0 and not y.en_banco), 0)) as sin
      into k from pg_temp.c16_cobros(v_hoy - 29, v_hoy) y;
    v_libro := pg_temp.c16_libro((select array_agg(pc.cuenta) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')), v_hoy);
    v_esp := format('por cobrar %s en %s partidas (%s facturas), vencido %s en %s, a favor %s en %s, retención %s en %s | cobrado en 30 días %s en %s '
                    'cobros (%s facturas) | depositado %s en %s, sin depositar %s | los pasos: los mismos | cuadre con el libro: %s sí',
                    r.monto, r.n, r.fact, r.venc, r.n_venc, r.favor, r.n_favor, r.ret, r.n_ret, k.monto, k.n, k.fact,
                    case when pg_temp.c16_capa('c6') then k.dep else '—' end, case when pg_temp.c16_capa('c6') then k.n_dep::text else '—' end,
                    case when pg_temp.c16_capa('c6') then k.sin else '—' end, pg_temp.c16_m(v_libro));
    v_obt := format('por cobrar %s en %s partidas (%s facturas), vencido %s en %s, a favor %s en %s, retención %s en %s | cobrado en 30 días %s en %s '
                    'cobros (%s facturas) | depositado %s en %s, sin depositar %s | los pasos: %s | cuadre con el libro: %s %s',
                    pg_temp.c16_mj(c -> 'por_cobrar' -> 'monto'), c -> 'por_cobrar' ->> 'n', c -> 'por_cobrar' ->> 'facturas',
                    pg_temp.c16_mj(c -> 'por_cobrar' -> 'vencidas' -> 'monto'), c -> 'por_cobrar' -> 'vencidas' ->> 'n',
                    pg_temp.c16_mj(c -> 'por_cobrar' -> 'a_favor' -> 'monto'), c -> 'por_cobrar' -> 'a_favor' ->> 'n',
                    pg_temp.c16_mj(c -> 'por_cobrar' -> 'retencion' -> 'monto'), c -> 'por_cobrar' -> 'retencion' ->> 'n',
                    pg_temp.c16_mj(c -> 'cobrado' -> 'monto'), c -> 'cobrado' ->> 'n', c -> 'cobrado' ->> 'facturas',
                    pg_temp.c16_mj(c -> 'depositado' -> 'monto'), coalesce(c -> 'depositado' ->> 'n', '—'),
                    pg_temp.c16_mj(c -> 'sin_depositar' -> 'monto'),
                    case when c -> 'pasos' -> 0 -> 'monto' = c -> 'por_cobrar' -> 'monto' and c -> 'pasos' -> 1 -> 'monto' = c -> 'cobrado' -> 'monto'
                              and coalesce(c -> 'pasos' -> 2 -> 'monto', 'null') = coalesce(c -> 'depositado' -> 'monto', 'null')
                         then 'los mismos' else 'otros: ' || (c ->> 'pasos') end,
                    pg_temp.c16_mj(c -> 'cuadre' -> 'libro'), case when (c -> 'cuadre' ->> 'ok')::boolean then 'sí' else 'NO' end);
    if (c ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'EL EMBUDO DE COBRO contra el libro, al centavo: lo por cobrar (las partidas de 1110 con saldo, sus facturas y lo vencido por su vencimiento), lo que hay a favor y la retención aparte, y todo junto = el saldo de las cuentas por cobrar; lo cobrado en 30 días (los cobros vigentes menos lo devuelto) y lo que de eso está en el banco; los tres pasos con esas mismas cifras',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. BANCOS Y TARJETAS: cada cuenta de la página Bancos (sin las de
--    Stripe) con su saldo en el libro HASTA HOY (la suma de la cuenta con lo
--    fechado hasta hoy, y en una tarjeta lo que se debe en positivo), lo que
--    dice el banco (el último archivo o lote con saldo) y DE QUÉ DÍA, la
--    diferencia EL MISMO DÍA (el banco contra el libro a la fecha del saldo
--    del banco, como la página Bancos) y lo que espera en la Bandeja (sus
--    filas de v_banco_bandeja); y los totales.
do $$
declare
  v_obt text; v_esp text; b jsonb := pg_temp.c16_tc('bancos'); v_ocultas text[] := '{}'; v_hoy date := pg_temp.c16_hoy();
begin
  if pg_temp.c16_omitir(9, 'bancos y tarjetas', 'cada cuenta y los totales, del libro y del banco', false, array['c6']) then return; end if;
  begin
    if pg_temp.c16_capa('p1') then
      execute 'select array_remove(array[c.cuenta_puente, c.cuenta_paso], null) from public.stripe_config c where c.id = 1' into v_ocultas;
    end if;
    execute $q$
      with s as (
        select s.cuenta, s.tipo, s.saldo_banco_como_banco, s.saldo_banco_al, s.activa,
               (case when s.tipo = 'tarjeta' then -1 else 1 end
                * (select coalesce(sum(l.monto), 0) from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                    where l.cuenta = s.cuenta and a.fecha_contable <= $2))::numeric(14,2) as libro,
               (select coalesce(sum(l.monto), 0) from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                 where l.cuenta = s.cuenta and a.fecha_contable > $2) as despues,
               case when s.saldo_banco_al is not null
                    then (case when s.tipo = 'tarjeta' then -1 else 1 end
                          * (select coalesce(sum(l.monto), 0) from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                              where l.cuenta = s.cuenta and a.fecha_contable <= s.saldo_banco_al))::numeric(14,2) end as libro_al,
               (select count(*) from public.v_banco_bandeja m where m.cuenta = s.cuenta) as pend
          from public.v_banco_saldos s
         where not (s.cuenta = any ($1))
      ), v as (
        select * from s where s.activa or s.libro <> 0 or s.despues <> 0 or s.pend > 0 or coalesce(s.saldo_banco_como_banco, 0) <> 0
      )
      select string_agg(format('%s: libro %s, banco %s %s, diferencia el mismo día %s, por revisar %s', v.cuenta, pg_temp.c16_m(v.libro),
                               pg_temp.c16_m(v.saldo_banco_como_banco),
                               case when v.saldo_banco_al is null then '(sin saldo del banco)' when v.saldo_banco_al >= $2 then 'hoy'
                                    else 'al ' || v.saldo_banco_al end,
                               pg_temp.c16_m(v.saldo_banco_como_banco - v.libro_al), v.pend),
                        '; ' order by case v.tipo when 'banco' then 0 else 1 end, v.cuenta)
             || format(' | bancos en el libro %s, tarjetas %s, por revisar %s',
                       pg_temp.c16_m(coalesce(sum(v.libro) filter (where v.tipo = 'banco'), 0)),
                       pg_temp.c16_m(coalesce(sum(v.libro) filter (where v.tipo = 'tarjeta'), 0)), coalesce(sum(v.pend), 0))
        from v$q$ into v_esp using v_ocultas, v_hoy;
    select string_agg(format('%s: libro %s, banco %s %s, diferencia el mismo día %s, por revisar %s', x ->> 'cuenta', pg_temp.c16_mj(x -> 'saldo_libro'),
                             pg_temp.c16_mj(x -> 'saldo_banco'),
                             case when x ->> 'saldo_banco_al' is null then '(sin saldo del banco)'
                                  when x ->> 'saldo_banco_texto' = 'hoy' then 'hoy'
                                  when x ->> 'saldo_banco_texto' like 'al %' then 'al ' || (x ->> 'saldo_banco_al')
                                  else 'sin decir de qué día' end,
                             pg_temp.c16_mj(x -> 'diferencia'), x ->> 'por_revisar'), '; ' order by o)
           || format(' | bancos en el libro %s, tarjetas %s, por revisar %s', pg_temp.c16_mj(b -> 'totales' -> 'bancos' -> 'libro'),
                     pg_temp.c16_mj(b -> 'totales' -> 'tarjetas' -> 'libro'), b -> 'totales' -> 'por_revisar' ->> 'n')
      into v_obt
      from jsonb_array_elements(b -> 'cuentas') with ordinality t(x, o);
    if (b ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(b ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'BANCOS Y TARJETAS: cada cuenta de la página Bancos (sin las de Stripe) con su saldo en el libro HASTA HOY (en una tarjeta, lo que se debe en positivo), lo que dice el banco y de qué día, la diferencia el mismo día (el banco contra el libro a la fecha del saldo del banco, como la página Bancos) y lo que espera en la Bandeja (sus filas); y los totales',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. LOS RESULTADOS DE ESTE MES (contados hasta hoy) contra el libro: las
--     cinco secciones, la utilidad, el margen, las dos barras (entra − sale =
--     el resultado) y la comparación con los MISMOS días del mes pasado (o,
--     si el mes pasado es de antes del libro, que no la hay y por qué).
do $$
declare
  v_obt text; v_esp text; r jsonb; e jsonb; a jsonb; v_hoy date := pg_temp.c16_hoy(); v_d date := date_trunc('month', pg_temp.c16_hoy())::date;
  a_d date; a_h date; v_comp boolean; v_rev text;
begin
  begin
    r := pg_temp.c16_tc('resultados');
    e := pg_temp.c16_res(v_d, v_hoy);
    a_d := (v_d - interval '1 month')::date;
    -- (los MISMOS días del mes pasado mientras el mes va a medias; EL ÚLTIMO DÍA del mes ya va entero y se compara con el mes
    --  pasado ENTERO —el 30 de noviembre, con octubre del 1 al 31—: así lo hace la tarjeta. Antes aquí se esperaba «del 1 al
    --  30» también ese día, y la prueba daba un rojo falso el último día de un mes más corto que el anterior.)
    a_h := case when v_hoy = (v_d + interval '1 month')::date - 1 then v_d - 1
                else least(v_d - 1, (v_hoy - interval '1 month')::date) end;
    v_comp := a_d >= pg_temp.c16('libro_desde')::date;
    a := case when v_comp then pg_temp.c16_res(a_d, a_h) end;
    v_esp := format('del %s al %s: ingresos %s, costo %s, gastos %s, otros %s/%s, resultado %s, margen %s, barras %s − %s | anterior %s',
                    v_d, v_hoy, e ->> 'ingresos', e ->> 'costo', e ->> 'gastos', e ->> 'otros_ingresos', e ->> 'otros_gastos', e ->> 'resultado',
                    coalesce(case when (e ->> 'ingresos')::numeric > 0 then round(100 * (e ->> 'resultado')::numeric / (e ->> 'ingresos')::numeric, 1)::text end, '—'),
                    e ->> 'entra', e ->> 'sale',
                    case when v_comp then format('del %s al %s: resultado %s, variación %s', a_d, a_h, a ->> 'resultado',
                                                 pg_temp.c16_m((e ->> 'resultado')::numeric - (a ->> 'resultado')::numeric))
                         else 'ninguno: empieza antes del libro (lo dice)' end);
    v_obt := format('del %s al %s: ingresos %s, costo %s, gastos %s, otros %s/%s, resultado %s, margen %s, barras %s − %s | anterior %s',
                    r ->> 'desde', r ->> 'corte', pg_temp.c16_mj(r -> 'ingresos'), pg_temp.c16_mj(r -> 'costo'), pg_temp.c16_mj(r -> 'gastos'),
                    pg_temp.c16_mj(r -> 'otros_ingresos'), pg_temp.c16_mj(r -> 'otros_gastos'), pg_temp.c16_mj(r -> 'resultado'),
                    coalesce(r ->> 'margen_pct', '—'), pg_temp.c16_mj(r -> 'barras' -> 0 -> 'monto'), pg_temp.c16_mj(r -> 'barras' -> 1 -> 'monto'),
                    case when r -> 'anterior' is not null and r -> 'anterior' <> 'null'::jsonb
                         then format('del %s al %s: resultado %s, variación %s', r -> 'anterior' ->> 'desde', r -> 'anterior' ->> 'hasta',
                                     pg_temp.c16_mj(r -> 'anterior' -> 'resultado'), pg_temp.c16_mj(r -> 'variacion' -> 'monto'))
                         when r ->> 'sin_comparar' like '%antes del libro%' then 'ninguno: empieza antes del libro (lo dice)'
                         else 'ninguno, sin decir por qué' end);
    -- LO QUE ESPERA EN LA BANDEJA con fecha del mes (hasta hoy), contado como su página (v_banco_bandeja): todas sus filas, y de lo
    -- pendiente los cargos y los depósitos (lo que «llegó su ticket» y lo que el banco quitó, aparte)
    if pg_temp.c16_capa('c6') then
      execute $q$select format(' | por revisar: %s (cargos %s por %s, depósitos %s por %s, dobles %s)', count(*),
                               count(*) filter (where m.monto < 0 and m.motivo not in ('llego_su_ticket', 'quitada')),
                               pg_temp.c16_m(coalesce(-sum(m.monto) filter (where m.monto < 0 and m.motivo not in ('llego_su_ticket', 'quitada')), 0)),
                               count(*) filter (where m.monto > 0 and m.motivo not in ('llego_su_ticket', 'quitada')),
                               pg_temp.c16_m(coalesce(sum(m.monto) filter (where m.monto > 0 and m.motivo not in ('llego_su_ticket', 'quitada')), 0)),
                               count(*) filter (where m.motivo = 'llego_su_ticket'))
                   from public.v_banco_bandeja m where m.fecha between $1 and $2$q$
        into v_rev using greatest(v_d, pg_temp.c16('libro_desde')::date), v_hoy;
      v_esp := v_esp || v_rev;
    else
      v_esp := v_esp || ' | por revisar: — (sin el banco)';
    end if;
    v_obt := v_obt || case when r -> 'por_revisar' is null or r -> 'por_revisar' = 'null'::jsonb then ' | por revisar: — (sin el banco)'
                           else format(' | por revisar: %s (cargos %s por %s, depósitos %s por %s, dobles %s)', r -> 'por_revisar' ->> 'n',
                                       r -> 'por_revisar' -> 'cargos' ->> 'n', pg_temp.c16_mj(r -> 'por_revisar' -> 'cargos' -> 'monto'),
                                       r -> 'por_revisar' -> 'depositos' ->> 'n', pg_temp.c16_mj(r -> 'por_revisar' -> 'depositos' -> 'monto'),
                                       coalesce(r -> 'por_revisar' -> 'dobles' ->> 'n', '¿?')) end;
    -- LO DEL WIP QUE VA APARTE (el reverso del día 1 que espera el ajuste de este mes): ni en las cifras, y dicho con su monto;
    -- y las cifras más eso = lo de Estados (el libro tal cual)
    select format(' | el WIP aparte: %s', case when count(*) = 0 then 'nada'
                                               else format('ingresos %s, costo %s, con él el resultado %s', pg_temp.c16_m(-sum(li.monto) filter (where m.seccion = 'ingresos')),
                                                           pg_temp.c16_m(coalesce(sum(li.monto) filter (where m.seccion = 'costo'), 0)),
                                                           (pg_temp.c16_res(v_d, v_hoy, true) ->> 'resultado')) end)
      into v_rev
      from asiento_lineas li join pg_temp.c16_wip(true) w on w.asiento_id = li.asiento_id
      join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados'
     where w.fecha between v_d and v_hoy;
    v_esp := v_esp || v_rev;
    v_obt := v_obt || format(' | el WIP aparte: %s', case when r -> 'wip_aparte' is null or r -> 'wip_aparte' = 'null'::jsonb then 'nada'
                                                          when coalesce(r -> 'wip_aparte' ->> 'texto', '') = '' then 'sin decirlo en llano'
                                                          else format('ingresos %s, costo %s, con él el resultado %s',
                                                                      pg_temp.c16_mj(r -> 'wip_aparte' -> 'ingresos'), pg_temp.c16_mj(r -> 'wip_aparte' -> 'costo'),
                                                                      pg_temp.c16_m((r ->> 'resultado')::numeric + (r -> 'wip_aparte' ->> 'resultado')::numeric)) end);
    if (r ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(r ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'LOS RESULTADOS DE ESTE MES, contados hasta hoy, contra el libro: las secciones, la utilidad, el margen (resultado ÷ ingresos), las dos barras (entra − sale), la comparación con los MISMOS días del mes pasado (si es de antes del libro, no la hay y lo dice), lo que espera en la Bandeja con fecha del mes (como su página: cargos, depósitos y lo que llegó su ticket) y el reverso del WIP que espera el ajuste de este mes, aparte (con él, lo de Estados)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. LOS RESULTADOS DEL MES PASADO contra el libro y contra el estado de
--     resultados de c4 (v_resultados: las secciones y la utilidad neta de ese
--     mes, al centavo). Si el mes pasado es de antes del libro, la tarjeta lo
--     dice ({ok: false, antes_del_libro}).
do $$
declare
  v_obt text; v_esp text; r jsonb; e jsonb; v_per text := to_char(date_trunc('month', pg_temp.c16_hoy()) - interval '1 month', 'YYYY-MM');
  v_d date := (date_trunc('month', pg_temp.c16_hoy()) - interval '1 month')::date; vr record;
begin
  begin
    r := pg_temp.c16_j('select public.fn_tablero_resultados(null, null, ''mes_pasado'')');
    if v_d + interval '1 month' - interval '1 day' < pg_temp.c16('libro_desde')::date then
      v_esp := 'antes del libro: lo dice';
      v_obt := case when (r ->> 'ok')::boolean is false and (r ->> 'antes_del_libro')::boolean then 'antes del libro: lo dice' else 'no: ' || r::text end;
    else
      e := pg_temp.c16_res(v_d, (v_d + interval '1 month')::date - 1);
      -- (una sección que c4 no trae, por no tener cuentas o líneas, es cero)
      select pg_temp.c16_m(coalesce(max(x.mes) filter (where x.nivel = 'seccion' and x.seccion = 'ingresos'), 0)) as i,
             pg_temp.c16_m(coalesce(max(x.mes) filter (where x.nivel = 'seccion' and x.seccion = 'costo'), 0)) as c,
             pg_temp.c16_m(coalesce(max(x.mes) filter (where x.nivel = 'seccion' and x.seccion = 'gastos'), 0)) as g,
             pg_temp.c16_m(coalesce(max(x.mes) filter (where x.nivel = 'total' and x.linea = 'utilidad_neta'), 0)) as u
        into vr from v_resultados x where x.periodo = v_per;
      v_esp := format('ingresos %s, costo %s, gastos %s, resultado %s | contra v_resultados: %s, %s, %s, %s',
                      e ->> 'ingresos', e ->> 'costo', e ->> 'gastos', e ->> 'resultado',
                      coalesce(vr.i, '0.00'), coalesce(vr.c, '0.00'), coalesce(vr.g, '0.00'), coalesce(vr.u, '0.00'));
      -- (contra v_resultados: lo de la tarjeta MÁS lo del WIP que dejó aparte —el reverso que espera el ajuste de su mes—; sin nada aparte, lo mismo)
      v_obt := format('ingresos %s, costo %s, gastos %s, resultado %s | contra v_resultados: %s, %s, %s, %s',
                      pg_temp.c16_mj(r -> 'ingresos'), pg_temp.c16_mj(r -> 'costo'), pg_temp.c16_mj(r -> 'gastos'), pg_temp.c16_mj(r -> 'resultado'),
                      pg_temp.c16_m((r ->> 'ingresos')::numeric + coalesce((r -> 'wip_aparte' ->> 'ingresos')::numeric, 0)),
                      pg_temp.c16_m((r ->> 'costo')::numeric + coalesce((r -> 'wip_aparte' ->> 'costo')::numeric, 0)),
                      pg_temp.c16_m((r ->> 'gastos')::numeric + coalesce((r -> 'wip_aparte' ->> 'gastos')::numeric, 0)),
                      pg_temp.c16_m((r ->> 'resultado')::numeric + coalesce((r -> 'wip_aparte' ->> 'resultado')::numeric, 0)));
      if (r ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(r ->> 'motivo', '?'); end if;
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'LOS RESULTADOS DEL MES PASADO contra el libro y contra el estado de resultados de c4 (v_resultados), al centavo (con lo del WIP que la tarjeta deja aparte, si deja algo); si el mes pasado es de antes del libro, lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. LOS RESULTADOS DEL AÑO (lo que va, hasta hoy) contra el libro, y lo
--     que va del año contra el acumulado de v_resultados de c4 en el mes de
--     hoy; si el año empieza antes del libro, la tarjeta dice desde cuándo
--     cuenta (parcial) y que el año pasado vive en QuickBooks.
do $$
declare
  v_obt text; v_esp text; r jsonb; e jsonb; v_hoy date := pg_temp.c16_hoy(); v_d date := date_trunc('year', pg_temp.c16_hoy())::date;
  v_acum text; v_post int;
begin
  begin
    r := pg_temp.c16_j('select public.fn_tablero_resultados(null, null, ''anio'')');
    e := pg_temp.c16_res(v_d, v_hoy);
    -- (lo que va del año según c4: el acumulado del mes de hoy, si no hay asientos de después de hoy en el mes)
    select count(*) into v_post from asientos a where a.fecha_contable > v_hoy and a.fecha_contable <= (date_trunc('month', v_hoy) + interval '1 month')::date - 1;
    select pg_temp.c16_m(coalesce(max(x.acumulado) filter (where x.nivel = 'total' and x.linea = 'utilidad_neta'), 0)) into v_acum
      from v_resultados x where x.periodo = to_char(v_hoy, 'YYYY-MM');
    v_esp := format('resultado %s, ingresos %s | contra v_resultados (acumulado del mes de hoy): %s | parcial: %s, sin comparar: %s | el título: %s',
                    e ->> 'resultado', e ->> 'ingresos', case when v_post > 0 then 'hay asientos de después de hoy: no se compara' else coalesce(v_acum, '0.00') end,
                    v_d < pg_temp.c16('libro_desde')::date, (v_d - interval '1 year')::date < pg_temp.c16('libro_desde')::date,
                    case when v_d < pg_temp.c16('libro_desde')::date then 'dice desde cuándo hay libro' else 'el año' end);
    -- (contra v_resultados: la tarjeta MÁS lo del WIP que dejó aparte; y el título dice desde cuándo cuenta si el año empieza antes del libro)
    v_obt := format('resultado %s, ingresos %s | contra v_resultados (acumulado del mes de hoy): %s | parcial: %s, sin comparar: %s | el título: %s',
                    pg_temp.c16_mj(r -> 'resultado'), pg_temp.c16_mj(r -> 'ingresos'),
                    case when v_post > 0 then 'hay asientos de después de hoy: no se compara'
                         else pg_temp.c16_m((r ->> 'resultado')::numeric + coalesce((r -> 'wip_aparte' ->> 'resultado')::numeric, 0)) end,
                    (r ->> 'parcial')::boolean, (r ->> 'sin_comparar') is not null,
                    case when r ->> 'titulo' like '%en el libro (del ' || (to_char(pg_temp.c16('libro_desde')::date, 'FMDD') || '-')
                                                  || '%' then 'dice desde cuándo hay libro'
                         when r ->> 'titulo' like '%' || extract(year from v_hoy)::int || '%' and not coalesce((r ->> 'parcial')::boolean, false) then 'el año'
                         else 'otro: ' || coalesce(r ->> 'titulo', 'ninguno') end);
    if (r ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(r ->> 'motivo', '?'); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'LOS RESULTADOS DEL AÑO (lo que va, hasta hoy) contra el libro y contra el acumulado del estado de resultados de c4 (con lo del WIP que deja aparte); si el año empieza antes del libro, la tarjeta lo dice (parcial, y en el título: «en el libro, del 1-oct-2026 a hoy») y no compara con el año pasado (vive en QuickBooks)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. LOS GASTOS DE 30 DÍAS contra el libro: el total, cada categoría (cada
--     cuenta de costo, gastos y otros gastos), las 5 mayores de la gráfica y
--     «las demás» (que suman lo gastado en positivo), y los 30 días de antes
--     (o que no los hay porque empiezan antes del libro).
do $$
declare
  v_obt text; v_esp text; g jsonb := pg_temp.c16_tc('gastos'); v_hoy date := pg_temp.c16_hoy(); v_comp boolean;
begin
  begin
    v_comp := v_hoy - 59 >= pg_temp.c16('libro_desde')::date;
    with l as (
      select li.cuenta, a.fecha_contable >= v_hoy - 29 as actual, li.monto
        from asiento_lineas li join asientos a on a.id = li.asiento_id
        join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion in ('costo', 'gastos', 'otros_gastos')
       where a.fecha_contable between v_hoy - 59 and v_hoy and pg_temp.c16_ejercicio(a.id) = extract(year from a.fecha_contable)::int
         -- (el ajuste del WIP no es un gasto: ni el ajuste ni su reverso)
         and a.id not in (select w.asiento_id from pg_temp.c16_wip(false) w)
    ), c as (
      select l.cuenta, coalesce(sum(l.monto) filter (where l.actual), 0) as monto, coalesce(sum(l.monto) filter (where not l.actual), 0) as ant
        from l group by l.cuenta
    )
    select format('total %s | categorías: %s | la gráfica suma %s | anterior %s',
                  pg_temp.c16_m(coalesce(sum(c.monto), 0)),
                  coalesce(string_agg(c.cuenta || ' ' || pg_temp.c16_m(c.monto), ', ' order by c.monto desc, c.cuenta) filter (where c.monto <> 0), 'ninguna'),
                  pg_temp.c16_m(coalesce(sum(c.monto) filter (where c.monto > 0), 0)),
                  case when v_comp then pg_temp.c16_m(coalesce(sum(c.ant), 0)) else 'ninguno: empieza antes del libro' end)
      into v_esp from c;
    v_obt := format('total %s | categorías: %s | la gráfica suma %s | anterior %s',
                    pg_temp.c16_mj(g -> 'total'),
                    coalesce((select string_agg((x ->> 'cuenta') || ' ' || pg_temp.c16_mj(x -> 'monto'), ', ' order by o)
                                from jsonb_array_elements(g -> 'categorias') with ordinality t(x, o) where (x ->> 'monto')::numeric <> 0), 'ninguna'),
                    case when (select coalesce(sum((x ->> 'monto')::numeric), 0) from jsonb_array_elements(g -> 'grafica') x) = (g ->> 'total_grafica')::numeric
                         then pg_temp.c16_mj(g -> 'total_grafica') else 'otra cosa: ' || (g ->> 'grafica') end,
                    case when g -> 'anterior' is not null and g -> 'anterior' <> 'null'::jsonb then pg_temp.c16_mj(g -> 'anterior' -> 'total')
                         when g ->> 'sin_comparar' like '%antes del libro%' then 'ninguno: empieza antes del libro' else 'ninguno, sin decir por qué' end);
    if (g ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(g ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'LOS GASTOS DE 30 DÍAS contra el libro, al centavo: el total, cada categoría (cada cuenta de costo, gastos y otros gastos, sin el ajuste del WIP: no es un gasto), la gráfica (las mayores y «las demás» suman lo gastado en positivo) y los 30 días de antes (o que no los hay: empiezan antes del libro)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. LA CAJA, LOS MESES Y HOY: cada mes del libro con lo de Estados → Flujo
--     de caja (v_flujo_real_por_mes de c4: inicial, entradas, salidas, final,
--     al centavo); el mes en curso, HASTA HOY (la revisión final: lo que entró
--     y salió del 1 a hoy, con la regla de c4, y al terminar = la caja de hoy;
--     lo de después de hoy va aparte, la 46); el saldo de hoy del libro (las
--     cuentas de efectivo, en negro) y la línea: empieza con la apertura y
--     pasa por hoy.
do $$
declare
  v_obt text; v_esp text; c jsonb := pg_temp.c16_tc('caja'); v_hoy date := pg_temp.c16_hoy(); v_m0 date; v_saldo numeric;
begin
  begin
    v_m0 := greatest(date_trunc('month', pg_temp.c16('libro_desde')::date)::date, (date_trunc('month', v_hoy) - interval '11 months')::date);
    select coalesce(sum(greatest(s, 0)), 0) into v_saldo
      from (select m.cuenta, (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where l.cuenta = m.cuenta and a.fecha_contable <= v_hoy) as s
              from v_estados_mapeo m where m.efectivo) x;
    -- (cada mes del libro hasta hoy; el que c4 no trae —sin efectivo ni movimientos de efectivo— es cero. El mes en curso, HASTA
    --  HOY: lo que entró y salió de v_efectivo_movimientos de c4 con fecha hasta hoy —sin un error y su reverso, los dos de este
    --  mes y hasta hoy— y al terminar, la caja de hoy)
    select coalesce(string_agg(format('%s: %s → %s (+%s −%s)', to_char(g.mes, 'YYYY-MM'), pg_temp.c16_m(coalesce(f.efectivo_inicial, 0)),
                                      pg_temp.c16_m(case when g.mes::date = date_trunc('month', v_hoy)::date then v_saldo else coalesce(f.efectivo_final, 0) end),
                                      pg_temp.c16_m(case when g.mes::date = date_trunc('month', v_hoy)::date then h.ent else coalesce(f.entradas, 0) end),
                                      pg_temp.c16_m(case when g.mes::date = date_trunc('month', v_hoy)::date then h.sal else coalesce(f.salidas, 0) end)),
                               '; ' order by g.mes), 'ninguno')
      into v_esp
      from generate_series(v_m0::timestamp, date_trunc('month', v_hoy)::timestamp, interval '1 month') g(mes)
      left join v_flujo_real_por_mes f on f.desde = g.mes::date
      cross join (select coalesce(sum(m.neto) filter (where m.neto > 0 and not m.par), 0) as ent, coalesce(-sum(m.neto) filter (where m.neto < 0 and not m.par), 0) as sal
                    from (select m.neto, m.par_en_el_mes and (m.camino = 'reverso'
                                                              or exists (select 1 from asientos r where r.reversa_a = m.asiento_id and r.camino = 'reverso'
                                                                            and r.fecha_contable <= v_hoy)) as par
                            from v_efectivo_movimientos m
                           where m.fecha between date_trunc('month', v_hoy)::date and v_hoy) m) h;
    v_esp := v_esp || format(' | hoy %s | la línea empieza en %s y pasa por hoy | hoy, en llano: sí | alarma de sobregiro: %s', pg_temp.c16_m(v_saldo),
                             case when exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null
                                                  and not exists (select 1 from asientos r where r.reversa_a = a.id))
                                       and v_m0 = date_trunc('month', pg_temp.c16('libro_desde')::date)::date
                                  then 'la apertura' else 'el primer mes' end,
                             -- (de verdad: alguna cuenta de efectivo en rojo, y la apertura en el libro; sin ella, el saldo no es el del banco)
                             case when exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null
                                                 and not exists (select 1 from asientos r where r.reversa_a = a.id))
                                       and exists (select 1 from v_estados_mapeo m where m.efectivo
                                                     and (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                           where l.cuenta = m.cuenta and a.fecha_contable <= v_hoy) < 0)
                                  then 'true' else 'false' end);
    select coalesce(string_agg(format('%s: %s → %s (+%s −%s)', x ->> 'mes', pg_temp.c16_mj(x -> 'inicial'), pg_temp.c16_mj(x -> 'final'),
                                      pg_temp.c16_mj(x -> 'entradas'), pg_temp.c16_mj(x -> 'salidas')), '; ' order by o)
                                 , 'ninguno')
      into v_obt
      from jsonb_array_elements(c -> 'meses') with ordinality t(x, o);
    v_obt := v_obt || format(' | hoy %s | la línea empieza en %s y pasa por hoy | hoy, en llano: %s | alarma de sobregiro: %s', pg_temp.c16_mj(c -> 'hoy' -> 'saldo'),
                             case when c -> 'serie' -> 0 ->> 'tipo' = 'apertura' then 'la apertura' else 'el primer mes' end,
                             case when coalesce(c -> 'hoy' ->> 'texto', '') <> '' then 'sí' else 'no lo dice' end,
                             coalesce(c -> 'hoy' ->> 'alarma', 'no lo dice'))
             || case when exists (select 1 from jsonb_array_elements(c -> 'serie') x where x ->> 'tipo' = 'hoy' and x -> 'saldo' = c -> 'hoy' -> 'saldo')
                     then '' else ' (pero la línea no pasa por el saldo de hoy)' end;
    if (c ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'LA CAJA, LOS MESES Y HOY: cada mes del libro con lo de Estados → Flujo de caja de c4 (inicial, final, entradas y salidas, al centavo; el mes en curso, hasta hoy), el saldo de hoy del libro (las cuentas de efectivo), dicho en llano (de qué cuentas sale), la alarma de sobregiro solo si es de verdad (una cuenta en rojo con la apertura en el libro) y la línea, que empieza con la apertura (su asiento vivo) y pasa por hoy',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. LA PROYECCIÓN DE CAJA, con lo que se sabe, y dicho de frente que no
--     es la caja que va a haber: en el mes de hoy, lo por cobrar que vence en
--     él o ya venció (hasta hace 60 días; lo vencido de más y lo de una
--     factura con un cheque devuelto no se cuenta) − lo por pagar igual − las
--     cuotas de los préstamos del mes − el use tax por la regla del DR-15 (lo
--     que ya se debía, el 20 de este mes) ± lo que el libro ya tiene con
--     fecha de después de hoy (un cheque posfechado, salvo lo que ya va por
--     otro lado); cada mes, el saldo anterior más su neto; la línea visible
--     que dice lo que no cuenta («la caja real será menor»), y lo que no
--     incluye con su monto (lo que se debe de la nómina, lo de un cheque
--     devuelto, lo vencido de más de 60 días). Sin la apertura en el libro,
--     no hay de dónde partir: sin proyección, y lo dice. O, sin nada con
--     fecha, que no hay proyección.
--     (14-nov, Fase 11c) CON LA NÓMINA DE c15 EN LA BASE, lo que el libro
--     dice que se debe de ella se RESTA en la proyección (lo que ya se
--     debía, hoy; lo de una nómina ya posteada con día de pago después de
--     hoy, ese día: la cuenta de c16_nom_pagos) y ya no va en «no incluye».
--     Sin c15, como antes.
do $$
declare
  v_obt text; v_esp text; c jsonb := pg_temp.c16_tc('caja'); v_hoy date := pg_temp.c16_hoy(); v_fin date; v_cob numeric; v_pag numeric;
  v_cuo numeric := 0; v_imp numeric; v_lib numeric; p jsonb; v_ap boolean; v_dev bigint[]; v_ut text; v_s0 numeric; v_p numeric; v_h numeric;
  v_mod text[]; v_nom numeric; v_dv numeric; v_vj numeric; v_m0 date := date_trunc('month', pg_temp.c16_hoy())::date;
  v_c15 boolean := pg_temp.c16_hay_c15(); v_nomm numeric := 0;
begin
  begin
    v_fin := (v_m0 + interval '1 month')::date - 1;
    v_ap := exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null
                      and not exists (select 1 from asientos r where r.reversa_a = a.id));
    p := c -> 'proyeccion';
    if not v_ap then
      v_esp := 'sin la apertura en el libro: sin proyección (lo dice)';
      v_obt := case when (p is null or p = 'null'::jsonb) and c ->> 'sin_proyeccion' like '%apertura%' then 'sin la apertura en el libro: sin proyección (lo dice)'
                    else 'otra cosa: ' || coalesce(p::text, c ->> 'sin_proyeccion', '') end;
    else
      -- (las facturas con un cheque devuelto de verdad: una devolución de un cobro aplicado a ellas que no es la técnica de Stripe)
      if to_regclass('public.stripe_pago_libro') is not null then
        execute $q$select coalesce(array_agg(distinct ap.factura_id), '{}') from public.aplicaciones_cobro ap
                     join public.cobros_devoluciones d on d.cobro_id = ap.cobro_id
                    where ap.factura_id is not null and not exists (select 1 from public.stripe_pago_libro x where x.devolucion_id = d.id)$q$ into v_dev;
      else
        select coalesce(array_agg(distinct ap.factura_id), '{}') into v_dev from aplicaciones_cobro ap
          join cobros_devoluciones d on d.cobro_id = ap.cobro_id where ap.factura_id is not null;
      end if;
      select coalesce(sum(y.por) filter (where not y.dev and v_hoy - y.vence <= 60 and y.vence <= v_fin), 0),
             coalesce(sum(y.por) filter (where y.dev), 0),
             coalesce(sum(y.por) filter (where not y.dev and v_hoy - y.vence > 60), 0)
        into v_cob, v_dv, v_vj
        from (select x.por, x.vence,
                     coalesce(case when x.pt = 'facturas' and x.pid ~ '^-?[0-9]{1,18}$' then x.pid::bigint end = any (v_dev), false) as dev
                from pg_temp.c16_cxc() x where x.por > 0 and x.vence is not null) y;
      select coalesce(sum(x.por_pagar), 0) into v_pag from v_cxp_antiguedad x
       where x.periodo = 'hoy' and x.nivel = 'partida' and x.por_pagar > 0 and x.vence is not null and x.vence <= v_fin;
      if pg_temp.c16_capa('c6_prestamos') then
        -- (las cuotas del mes, del calendario del préstamo; lo comprueba aparte la 23)
        select coalesce(sum((q ->> 'monto')::numeric) filter (where greatest((q ->> 'fecha')::date, v_hoy) <= v_fin), 0) into v_cuo
          from jsonb_array_elements(pg_temp.c16_j('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.fn_tablero_cuotas(' || quote_literal(v_fin) || '::date) x')) q;
      end if;
      -- (el use tax: lo que ya se debía al empezar el mes y sigue sin pagar sale el 20 de este mes —la regla del DR-15—)
      v_ut := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
      v_s0 := -pg_temp.c16_libro(array[v_ut], v_m0 - 1);
      v_h := -pg_temp.c16_libro(array[v_ut], v_hoy);
      select coalesce(sum(l.monto) filter (where l.monto > 0), 0) into v_p
        from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = v_ut and a.fecha_contable between v_m0 and v_hoy;
      v_imp := greatest(least(v_s0 - v_p, v_h), 0);
      -- (lo posfechado del libro en la caja, del día de mañana al fin del mes, salvo lo que va contra lo que la proyección ya lleva)
      v_mod := array(select pc.cuenta from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc', 'cxp')
                     union select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea in ('retencion_por_pagar', 'prestamos_corto', 'prestamos_largo')
                     union select v_ut);
      if to_regclass('public.prestamos') is not null then
        execute $q$select $1 || array(select distinct u from public.prestamos x, unnest(array[x.cuenta, x.cuenta_largo]) u where u is not null)$q$
          into v_mod using v_mod;
      end if;
      select coalesce(sum(l.monto), 0) into v_lib
        from asiento_lineas l join asientos a on a.id = l.asiento_id
       where l.cuenta in (select m.cuenta from v_estados_mapeo m where m.efectivo) and a.fecha_contable > v_hoy and a.fecha_contable <= v_fin
         and not exists (select 1 from asiento_lineas l2 where l2.asiento_id = a.id and l2.cuenta = any (v_mod));
      -- (lo que se debe de la nómina, que no va: con su monto, con todo lo que el libro tiene en sus cuentas —también lo fechado
      --  después de hoy: la 50—)
      v_nom := -pg_temp.c16_libro(array(select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'nomina_por_pagar'), date 'infinity');
      -- (14-nov, Fase 11c: con c15, lo de la nómina que sale este mes —lo que ya se debía, hoy; lo de una nómina ya posteada con día
      --  de pago en lo que queda del mes, ese día—)
      if v_c15 then
        select coalesce(sum(q.monto), 0) into v_nomm from pg_temp.c16_nom_pagos() q where q.fecha <= v_fin;
      end if;
      if v_cob = 0 and v_pag = 0 and v_cuo = 0 and v_imp = 0 and v_lib = 0 and v_nomm = 0 and (p is null or p = 'null'::jsonb) then
        v_esp := 'sin nada con fecha: sin proyección (lo dice)';
        v_obt := case when c ->> 'sin_proyeccion' is not null and (p is null or p = 'null'::jsonb) then 'sin nada con fecha: sin proyección (lo dice)' else 'otra cosa: ' || coalesce(p::text, '') end;
      else
        v_esp := format('este mes: cobrar %s, pagar %s, cuotas %s, use tax %s, la nómina %s, posfechado %s, saldo %s | cada mes, el anterior más su neto: sí | '
                        'marcada como proyección, con la línea a la vista: sí | no incluye, con su monto: la nómina %s, un cheque devuelto %s, más de 60 días %s',
                        pg_temp.c16_m(v_cob), pg_temp.c16_m(v_pag), pg_temp.c16_m(v_cuo), pg_temp.c16_m(v_imp),
                        case when v_c15 then pg_temp.c16_m(v_nomm) else '—' end, pg_temp.c16_m(v_lib),
                        pg_temp.c16_m((c -> 'hoy' ->> 'neto')::numeric + v_cob - v_pag - v_cuo - v_imp - v_nomm + v_lib),
                        case when v_c15 then 'va en la proyección' when v_nom <> 0 then pg_temp.c16_m(v_nom) else 'nada' end,
                        case when v_dv <> 0 then pg_temp.c16_m(v_dv) else 'nada' end,
                        case when v_vj <> 0 then pg_temp.c16_m(v_vj) else 'nada' end);
        v_obt := format('este mes: cobrar %s, pagar %s, cuotas %s, use tax %s, la nómina %s, posfechado %s, saldo %s | cada mes, el anterior más su neto: %s | '
                        'marcada como proyección, con la línea a la vista: %s | no incluye, con su monto: la nómina %s, un cheque devuelto %s, más de 60 días %s',
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'cobrar'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'pagar'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'cuotas'),
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'impuestos'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'nomina'),
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'libro'),
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'saldo'),
                        case when not exists (select 1 from jsonb_array_elements(p -> 'meses') with ordinality t(x, o)
                                               where o > 1 and (x ->> 'saldo')::numeric <> (p -> 'meses' -> (o::int - 2) ->> 'saldo')::numeric + (x ->> 'neto')::numeric)
                             then 'sí' else 'no' end,
                        case when jsonb_array_length(p -> 'supuestos') > 0 and jsonb_array_length(p -> 'no_incluye') > 0
                                  and p ->> 'aviso' like '%la caja real será menor%'
                                  and (select count(*) from jsonb_array_elements(c -> 'serie') x where x ->> 'tipo' = 'proyeccion') = jsonb_array_length(p -> 'meses')
                             then 'sí' else 'no' end,
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x
                                   where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar'),
                                 case when v_c15 then 'va en la proyección' else 'nada' end),
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x where x ->> 'clave' = 'cheque_devuelto'), 'nada'),
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x where x ->> 'clave' = 'vencido_viejo'), 'nada'));
      end if;
    end if;
    if (c ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'LA PROYECCIÓN DE CAJA, con lo que se sabe y dicho de frente: en el mes de hoy, lo por cobrar que vence en él o ya venció hasta hace 60 días (sin lo de un cheque devuelto) − lo por pagar igual − las cuotas de los préstamos − el use tax por la regla del DR-15 − (con la nómina de c15 en la base) lo que se debe de la nómina ± lo posfechado del libro; cada mes, el saldo anterior más su neto; la línea a la vista («la caja real será menor») y lo que no incluye con su monto; sin la apertura en el libro, sin proyección (lo dice)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. LAS FACTURAS: las no pagadas (las partidas de factura con saldo en
--     1110, vencidas y por vencer por su vencimiento) y las pagadas en 30 días
--     (lo mismo que el embudo: depositado y sin depositar).
do $$
declare
  v_obt text; v_esp text; f jsonb := pg_temp.c16_tc('facturas'); c jsonb := pg_temp.c16_tc('cobros'); r record;
begin
  begin
    select pg_temp.c16_m(coalesce(sum(x.por), 0)) as monto, count(*) as n,
           pg_temp.c16_m(coalesce(sum(x.por) filter (where pg_temp.c16_tramo(x.vence) in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)) as venc,
           count(*) filter (where pg_temp.c16_tramo(x.vence) in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_venc
      into r from pg_temp.c16_cxc() x where x.pt = 'facturas' and x.por > 0;
    v_esp := format('no pagadas %s en %s, vencidas %s en %s, por vencer %s | pagadas = el embudo: %s, depositado %s',
                    r.monto, r.n, r.venc, r.n_venc, pg_temp.c16_m(r.monto::numeric - r.venc::numeric),
                    pg_temp.c16_mj(c -> 'cobrado' -> 'monto'), pg_temp.c16_mj(c -> 'depositado' -> 'monto'));
    v_obt := format('no pagadas %s en %s, vencidas %s en %s, por vencer %s | pagadas = el embudo: %s, depositado %s',
                    pg_temp.c16_mj(f -> 'no_pagadas' -> 'monto'), f -> 'no_pagadas' ->> 'n', pg_temp.c16_mj(f -> 'no_pagadas' -> 'vencidas' -> 'monto'),
                    f -> 'no_pagadas' -> 'vencidas' ->> 'n', pg_temp.c16_mj(f -> 'no_pagadas' -> 'por_vencer' -> 'monto'),
                    pg_temp.c16_mj(f -> 'pagadas' -> 'monto'), pg_temp.c16_mj(f -> 'pagadas' -> 'depositado' -> 'monto'));
    if (f ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(f ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'LAS FACTURAS: las no pagadas (cada factura con saldo en 1110, sin su retención), vencidas y por vencer según su vencimiento, contra el libro; y las pagadas en 30 días, las mismas cifras del embudo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. LAS VENTAS DEL AÑO contra el libro: cada mes del año que tiene libro
--     (las cuentas de ingreso, el mes en curso hasta hoy), el total, el mejor
--     mes y cuántos meses del año son de antes del libro (y que lo dice); y
--     el total contra el estado de resultados del año de c4.
do $$
declare
  v_obt text; v_esp text; v jsonb := pg_temp.c16_tc('ventas'); v_hoy date := pg_temp.c16_hoy();
  v_lib date := pg_temp.c16('libro_desde')::date; v_m0 date; v_post int; v_vr text; v_fuera int;
begin
  begin
    v_m0 := greatest(date_trunc('year', v_hoy)::date, date_trunc('month', v_lib)::date);
    v_fuera := extract(month from v_m0)::int - 1;
    with ms as (
      select g::date as mes from generate_series(v_m0::timestamp, date_trunc('month', v_hoy)::timestamp, interval '1 month') g
    ), l as (
      select date_trunc('month', a.fecha_contable)::date as mes, -li.monto as monto
        from asiento_lineas li join asientos a on a.id = li.asiento_id
        join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion = 'ingresos'
       where a.fecha_contable between v_m0 and v_hoy and pg_temp.c16_ejercicio(a.id) = extract(year from a.fecha_contable)::int
         -- (lo vendido: sin el ajuste del WIP ni su reverso)
         and a.id not in (select w.asiento_id from pg_temp.c16_wip(false) w)
    ), x as (
      select ms.mes, coalesce(sum(l.monto), 0) as monto from ms left join l on l.mes = ms.mes group by ms.mes
    )
    select format('meses: %s | total %s | mejor mes %s | antes del libro: %s',
                  string_agg(to_char(x.mes, 'YYYY-MM') || ' ' || pg_temp.c16_m(x.monto), ', ' order by x.mes),
                  pg_temp.c16_m(sum(x.monto)),
                  coalesce((select to_char(y.mes, 'YYYY-MM') from x y where y.monto > 0 order by y.monto desc, y.mes limit 1), 'ninguno'),
                  case when v_fuera > 0 then v_fuera || ' meses (lo dice)' else 'ninguno' end)
      into v_esp from x;
    select count(*) into v_post from asientos a where a.fecha_contable > v_hoy and extract(year from a.fecha_contable) = extract(year from v_hoy);
    -- (el estado de resultados del año de c4, menos lo del WIP en sus cuentas de ingreso: lo vendido)
    select pg_temp.c16_m(coalesce(max(r.mes) filter (where r.nivel = 'seccion' and r.seccion = 'ingresos'), 0)
                         - coalesce((select -sum(li.monto) from asiento_lineas li join pg_temp.c16_wip(false) w on w.asiento_id = li.asiento_id
                                      join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion = 'ingresos'
                                     where extract(year from w.fecha) = extract(year from v_hoy)), 0))
      into v_vr
      from v_resultados r where r.periodo = to_char(v_hoy, 'YYYY') and r.periodo_tipo = 'anio';
    v_esp := v_esp || ' | contra el estado de resultados del año (sin el WIP): ' || case when v_post > 0 then 'hay asientos de después de hoy: no se compara'
                                                                          else coalesce(v_vr, '0.00') end
             || ' | el título: ' || case when v_fuera > 0 then 'dice desde cuándo hay libro' else 'el año' end;
    v_obt := format('meses: %s | total %s | mejor mes %s | antes del libro: %s',
                    (select string_agg((x ->> 'mes') || ' ' || pg_temp.c16_mj(x -> 'monto'), ', ' order by o)
                       from jsonb_array_elements(v -> 'meses') with ordinality t(x, o)),
                    pg_temp.c16_mj(v -> 'total'), coalesce(v -> 'mejor_mes' ->> 'mes', 'ninguno'),
                    case when v -> 'antes_del_libro' is not null and v -> 'antes_del_libro' <> 'null'::jsonb
                              and v -> 'antes_del_libro' ->> 'texto' like '%QuickBooks%'
                         then (v -> 'antes_del_libro' ->> 'meses') || ' meses (lo dice)'
                         when v -> 'antes_del_libro' is null or v -> 'antes_del_libro' = 'null'::jsonb then 'ninguno'
                         else 'no lo dice en llano' end)
             || ' | contra el estado de resultados del año (sin el WIP): ' || case when v_post > 0 then 'hay asientos de después de hoy: no se compara'
                                                                     else pg_temp.c16_mj(v -> 'total') end
             || ' | el título: ' || case when v ->> 'titulo' like 'Ventas de ' || extract(year from v_hoy)::int || ' en el libro (del %' then 'dice desde cuándo hay libro'
                                         when v ->> 'titulo' like 'Ventas de ' || extract(year from v_hoy)::int || '%' and v_fuera = 0 then 'el año'
                                         else 'otro: ' || coalesce(v ->> 'titulo', 'ninguno') end;
    if (v ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(v ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'LAS VENTAS DEL AÑO contra el libro, SIN el ajuste del WIP (no es lo vendido): cada mes con libro (el mes en curso, hasta hoy), el total, el mejor mes y los meses del año de antes del libro (lo dice: viven en QuickBooks); el total, contra el estado de resultados del año de c4 sin el WIP; y el título dice desde cuándo hay libro («Ventas de 2026 en el libro (del 1-oct-2026 a hoy)»), nunca solo «Ventas de 2026»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. LO POR COBRAR POR ANTIGÜEDAD, como QuickBooks, contra el libro: cada
--     tramo por días de vencida (corriente, 1–30, 31–60, 61–90, más de 90),
--     lo que va sin vencimiento, la retención y lo que hay a favor aparte, la
--     más vencida y el cuadre con el saldo de las cuentas por cobrar.
do $$
declare
  v_obt text; v_esp text; a jsonb := pg_temp.c16_tc('por_cobrar'); r record; v_top text;
begin
  begin
    select string_agg(format('%s %s (%s)', k.clave, pg_temp.c16_m(coalesce(s.monto, 0)), coalesce(s.n, 0)), ', ' order by k.o) as tramos
      into r
      from (values (1, 'corriente'), (2, 'd1_30'), (3, 'd31_60'), (4, 'd61_90'), (5, 'd90_mas')) k(o, clave)
      left join (select pg_temp.c16_tramo(x.vence) as tramo, sum(x.por) as monto, count(*) as n
                   from pg_temp.c16_cxc() x where x.por > 0 group by 1) s on s.tramo = k.clave;
    select coalesce(x.pt || ':' || x.pid, 'obra ' || x.obra) || ', ' || (pg_temp.c16_hoy() - x.vence) || ' días' into v_top
      from pg_temp.c16_cxc() x where x.por > 0 and x.vence < pg_temp.c16_hoy()
     order by x.vence, x.por desc limit 1;
    select format('%s | sin vencimiento %s | total %s en %s | retención %s | a favor %s | la más vencida: %s | cuadre con el libro: %s sí',
                  r.tramos, pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por > 0 and x.vence is null), 0)),
                  pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por > 0), 0)), count(*) filter (where x.por > 0),
                  pg_temp.c16_m(coalesce(sum(x.ret), 0)), pg_temp.c16_m(coalesce(sum(x.por) filter (where x.por < 0), 0)),
                  coalesce(v_top, 'ninguna'),
                  pg_temp.c16_m(pg_temp.c16_libro((select array_agg(pc.cuenta) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')),
                                                  pg_temp.c16_hoy())))
      into v_esp from pg_temp.c16_cxc() x;
    v_obt := format('%s | sin vencimiento %s | total %s en %s | retención %s | a favor %s | la más vencida: %s | cuadre con el libro: %s %s',
                    (select string_agg(format('%s %s (%s)', t ->> 'clave', pg_temp.c16_mj(t -> 'monto'), t ->> 'n'), ', ' order by o)
                       from jsonb_array_elements(a -> 'tramos') with ordinality u(t, o)),
                    pg_temp.c16_mj(a -> 'sin_vencimiento' -> 'monto'), pg_temp.c16_mj(a -> 'total'), a ->> 'n',
                    pg_temp.c16_mj(a -> 'retencion' -> 'monto'), pg_temp.c16_mj(a -> 'a_favor' -> 'monto'),
                    coalesce((select coalesce((m ->> 'partida_tabla') || ':' || (m ->> 'partida_id'), 'obra ?') || ', ' || (m ->> 'dias_vencida') || ' días'
                                from jsonb_array_elements(a -> 'mas_vencidas') with ordinality u(m, o) where o = 1), 'ninguna'),
                    pg_temp.c16_mj(a -> 'cuadre' -> 'libro'), case when (a -> 'cuadre' ->> 'ok')::boolean then 'sí' else 'NO' end);
    if (a ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(a ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'LO POR COBRAR POR ANTIGÜEDAD contra el libro: cada tramo por días de vencida (corriente, 1–30, 31–60, 61–90, más de 90) con cuántas, lo que va sin vencimiento, la retención y lo que hay a favor aparte, la más vencida y el cuadre con el saldo de las cuentas por cobrar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 19. LO POR PAGAR POR ANTIGÜEDAD: cada partida por pagar de c4 (la de la
--     página Estados) en su tramo por días de vencida según el vencimiento que
--     c4 le da; lo que no tiene vencimiento, la retención y lo que hay a
--     favor aparte; y todo junto = el saldo de las cuentas por pagar (2010 y
--     la retención) en el libro.
do $$
declare
  v_obt text; v_esp text; a jsonb := pg_temp.c16_tc('por_pagar'); r record; v_ctas text[]; v_hoy date := pg_temp.c16_hoy();
begin
  begin
    select array_agg(distinct u.c) into v_ctas
      from (select pc.cuenta as c from puente_cuentas pc where pc.rol = 'cxp'
            union all select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'retencion_por_pagar') u;
    with p as (
      select x.por_pagar, x.retencion, x.vence,
             case when x.por_pagar <= 0 or x.vence is null then null
                  when v_hoy - x.vence <= 0 then 'corriente' when v_hoy - x.vence <= 30 then 'd1_30'
                  when v_hoy - x.vence <= 60 then 'd31_60' when v_hoy - x.vence <= 90 then 'd61_90' else 'd90_mas' end as tramo
        from v_cxp_antiguedad x where x.periodo = 'hoy' and x.nivel = 'partida'
    )
    select (select string_agg(format('%s %s (%s)', k.clave, pg_temp.c16_m(coalesce((select sum(p.por_pagar) from p where p.tramo = k.clave), 0)),
                                     (select count(*) from p where p.tramo = k.clave)), ', ' order by k.o)
              from (values (1, 'corriente'), (2, 'd1_30'), (3, 'd31_60'), (4, 'd61_90'), (5, 'd90_mas')) k(o, clave)) as tramos,
           pg_temp.c16_m(coalesce(sum(p.por_pagar) filter (where p.por_pagar > 0 and p.vence is null), 0)) as sin,
           pg_temp.c16_m(coalesce(sum(p.por_pagar) filter (where p.por_pagar > 0), 0)) as total, count(*) filter (where p.por_pagar > 0) as n,
           pg_temp.c16_m(coalesce(sum(p.retencion), 0)) as ret, pg_temp.c16_m(coalesce(sum(p.por_pagar) filter (where p.por_pagar < 0), 0)) as favor
      into r from p;
    v_esp := format('%s | sin vencimiento %s | total %s en %s | retención %s | a favor %s | cuadre con el libro (%s): %s sí',
                    r.tramos, r.sin, r.total, r.n, r.ret, r.favor, array_to_string(v_ctas, ', '), pg_temp.c16_m(-pg_temp.c16_libro(v_ctas, v_hoy)));
    v_obt := format('%s | sin vencimiento %s | total %s en %s | retención %s | a favor %s | cuadre con el libro (%s): %s %s',
                    (select string_agg(format('%s %s (%s)', t ->> 'clave', pg_temp.c16_mj(t -> 'monto'), t ->> 'n'), ', ' order by o)
                       from jsonb_array_elements(a -> 'tramos') with ordinality u(t, o)),
                    pg_temp.c16_mj(a -> 'sin_vencimiento' -> 'monto'), pg_temp.c16_mj(a -> 'total'), a ->> 'n',
                    pg_temp.c16_mj(a -> 'retencion' -> 'monto'), pg_temp.c16_mj(a -> 'a_favor' -> 'monto'),
                    (select string_agg(c, ', ' order by c) from jsonb_array_elements_text(a -> 'cuadre' -> 'cuentas') c),
                    pg_temp.c16_mj(a -> 'cuadre' -> 'libro'), case when (a -> 'cuadre' ->> 'ok')::boolean then 'sí' else 'NO' end);
    if (a ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(a ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'LO POR PAGAR POR ANTIGÜEDAD: cada partida por pagar de c4 en su tramo según el vencimiento que c4 le da (los términos del proveedor o la balanza de apertura), lo que no se sabe cuándo vence, la retención y lo que hay a favor aparte; y todo junto = el saldo de las cuentas por pagar en el libro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. LAS CONEXIONES: cada banco de Plaid con su estado (al día; con
--     problemas si pide volver a entrar o tiene una cuenta sin fijar; los
--     dados de baja aparte), Stripe y la IA contable con el estado que dicen
--     sus propias vistas (v_stripe_estado de p1 y v_contador_estado de c8:
--     algo en rojo = con problemas) y los totales. Y lo que está en rojo, en
--     llano: ningún detalle nombra un control de p1 o de c8 entre comillas
--     (antes: «Por revisar: «la revisión automática corre».»).
do $$
declare
  v_obt text; v_esp text; c jsonb := pg_temp.c16_tc('conexiones'); v_pl text := 'sin Plaid'; v_st text := 'sin p1'; v_ia text := 'sin c8';
  v_n jsonb := '[]'::jsonb; v_nom text[] := '{}'; v_q text;
begin
  begin
    if to_regclass('public.plaid_conexiones') is not null then
      -- (con problemas: pide volver a entrar, tiene una cuenta sin fijar o lleva más de 48 horas sin traer nada —la rutina es diaria—)
      execute $q$select format('%s conectados, %s con problemas, %s dados de baja',
                               count(*) filter (where c.estado <> 'desconectada' and c.estado <> 'error'
                                                  and not exists (select 1 from jsonb_array_elements(c.cuentas) x where x ->> 'cuenta' is null)
                                                  and not coalesce(now() - c.ultimo_sync > interval '48 hours', false)),
                               count(*) filter (where c.estado = 'error'
                                                  or (c.estado <> 'desconectada'
                                                      and (exists (select 1 from jsonb_array_elements(c.cuentas) x where x ->> 'cuenta' is null)
                                                           or coalesce(now() - c.ultimo_sync > interval '48 hours', false)))),
                               count(*) filter (where c.estado = 'desconectada'))
                   from public.plaid_conexiones c$q$ into v_pl;
    end if;
    if pg_temp.c16_capa('p1') then
      execute $q$select case when e.cuadres_rojos > 0 or e.alarmas > 0 or e.modo is null
                                  or (e.ultimo_error is not null and e.ultimo_error_el >= coalesce(e.ultimo_evento_el, '-infinity'::timestamptz))
                             then 'con_problemas' else 'conectada' end
                   from public.v_stripe_estado e$q$ into v_st;
    end if;
    if to_regclass('public.v_contador_estado') is not null then
      execute $q$select case when not coalesce(e.activa, false) then 'apagada'
                             when coalesce(e.bloqueado, false) or e.cuadres_rojos > 0 or e.alarmas > 0
                                  or (e.ultimo_error is not null and e.ultimo_error_el >= coalesce(e.ultima_rafaga_el, '-infinity'::timestamptz))
                               then 'con_problemas' else 'conectada' end
                   from public.v_contador_estado e$q$ into v_ia;
      v_ia := coalesce(v_ia, 'sin configurar');
    end if;
    v_esp := format('Plaid: %s | Stripe: %s | IA: %s', v_pl, v_st, v_ia);
    v_obt := format('Plaid: %s | Stripe: %s | IA: %s',
                    case when exists (select 1 from jsonb_array_elements(c -> 'sin_instalar') x where x ->> 'tipo' = 'banco') then 'sin Plaid'
                         else format('%s conectados, %s con problemas, %s dados de baja',
                                     (select count(*) from jsonb_array_elements(c -> 'lista') x where x ->> 'tipo' = 'banco' and x ->> 'estado' = 'conectada'),
                                     (select count(*) from jsonb_array_elements(c -> 'lista') x where x ->> 'tipo' = 'banco' and x ->> 'estado' = 'con_problemas'),
                                     c ->> 'desconectadas') end,
                    coalesce((select x ->> 'estado' from jsonb_array_elements(c -> 'lista') x where x ->> 'tipo' = 'cobros'),
                             case when exists (select 1 from jsonb_array_elements(c -> 'sin_instalar') x where x ->> 'tipo' = 'cobros') then 'sin p1' end, '?'),
                    coalesce((select x ->> 'estado' from jsonb_array_elements(c -> 'lista') x where x ->> 'tipo' = 'ia'),
                             case when exists (select 1 from jsonb_array_elements(c -> 'sin_instalar') x where x ->> 'tipo' = 'ia') then 'sin c8' end,
                             'sin configurar'));
    -- los totales, de la lista
    if (c ->> 'conectadas')::int <> (select count(*) from jsonb_array_elements(c -> 'lista') x where x ->> 'estado' = 'conectada')
       or (c ->> 'con_problemas')::int <> (select count(*) from jsonb_array_elements(c -> 'lista') x where x ->> 'estado' = 'con_problemas')
       or (c ->> 'total')::int <> jsonb_array_length(c -> 'lista') then
      v_obt := v_obt || ' (los totales no son los de la lista)';
    end if;
    -- lo que tiene problemas, primero; y cada uno dice qué pide
    if exists (select 1 from jsonb_array_elements(c -> 'lista') x where coalesce(x ->> 'detalle', '') = '') then
      v_obt := v_obt || ' (alguna sin detalle)';
    end if;
    -- Y LO QUE ESTÁ EN ROJO, EN LLANO: ningún detalle nombra un control de p1 o de c8 entre comillas («la revisión automática
    -- corre», «la llave y la función»): dice qué pasa. Los controles en rojo se leen de las vistas de p1 y c8, no de c16.
    if pg_temp.c16_capa('p1') then
      execute $q$select coalesce(array_agg(regexp_replace(k.control, '^stripe: ', '')), '{}') from public.v_stripe_control k
                  where k.ok is not true$q$ into v_nom;
    end if;
    if to_regclass('public.v_contador_control') is not null then
      execute $q$select $1 || coalesce(array_agg(regexp_replace(k.control, '^ia: ', '')), '{}') from public.v_contador_control k
                  where k.ok is not true$q$ into v_nom using v_nom;
    end if;
    select '«' || n || '»' into v_q
      from jsonb_array_elements(c -> 'lista') x cross join unnest(v_nom) n
     where position('«' || n || '»' in coalesce(x ->> 'detalle', '')) > 0
     limit 1;
    v_esp := v_esp || format(' | %s en rojo en p1 y c8: ninguno nombrado entre comillas en el detalle', cardinality(v_nom));
    v_obt := v_obt || format(' | %s en rojo en p1 y c8: %s', cardinality(v_nom),
                             coalesce('el detalle nombra ' || v_q, 'ninguno nombrado entre comillas en el detalle'));
    if (c ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c ->> 'motivo', pg_temp.c16('t_error')); end if;
    -- UN BANCO QUE LLEVA TRES DÍAS SIN TRAER NADA (su último sync, tres días atrás, dentro de un bloque que se deshace): con problemas,
    -- y su detalle lo dice («no trae nada desde hace 3 días»), no «al día»
    if to_regclass('public.plaid_conexiones') is not null
       and exists (select 1 from plaid_conexiones x where x.estado = 'activa' and x.ultimo_sync is not null) then
      v_esp := v_esp || ' | un banco que lleva 3 días sin traer nada: con_problemas, lo dice';
      begin
        update plaid_conexiones set ultimo_sync = now() - interval '3 days 2 hours'
         where id = (select x.id from plaid_conexiones x where x.estado = 'activa' and x.ultimo_sync is not null order by x.creado_el, x.id limit 1)
        returning institucion into v_pl;
        v_n := pg_temp.c16_j('select public.fn_tablero_conexiones()') -> 'lista';
        v_obt := v_obt || ' | un banco que lleva 3 días sin traer nada: '
                 || coalesce((select (x ->> 'estado') || case when x ->> 'detalle' like '%hace 3 días%' then ', lo dice' else ', dice: ' || (x ->> 'detalle') end
                                from jsonb_array_elements(v_n) x where x ->> 'nombre' = coalesce(v_pl, 'Un banco') || ' (Plaid)'), 'no sale');
        raise exception using errcode = 'MXT00';
      exception
        when sqlstate 'MXT00' then null;
        when others then v_obt := v_obt || ' | error ' || sqlstate || ': ' || sqlerrm;
      end;
      perform pg_temp.c16_ser('editor');
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'LAS CONEXIONES: cada banco de Plaid con su estado (con problemas si pide volver a entrar, tiene una cuenta sin fijar o lleva más de 48 horas sin traer nada —y uno de prueba con tres días lo dice—; los dados de baja aparte), Stripe y la IA contable con el estado que dicen sus propias vistas de p1 y c8 (algo en rojo = con problemas; la IA desactivada = apagada), cada una con su detalle —lo que está en rojo, en llano: sin nombrar un control de p1 o c8 entre comillas—, y los totales de la lista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. LOS COBROS EN LÍNEA contra lo que dice Stripe en p1 (v_stripe_estado:
--     el modo, lo cobrado por depositar, lo que está en camino, los enlaces
--     activos, los pagos por revisar, los cuadres y las alarmas en rojo) y el
--     último depósito que llegó (v_stripe_payouts).
do $$
declare
  v_obt text; v_esp text; s jsonb := pg_temp.c16_tc('cobros_en_linea');
begin
  if pg_temp.c16_omitir(21, 'los cobros en línea', 'lo de v_stripe_estado y el último depósito', false, array['p1']) then return; end if;
  begin
    -- (lo que falta depositar, como v_stripe_estado; y sus dos partes, de v_stripe_pagos: lo cobrado que espera su depósito, y lo que
    --  Stripe descontará del siguiente por un reembolso de algo ya depositado)
    execute $q$select format('modo %s | falta depositar %s en %s: cobrado que espera %s, por descontar %s | en camino %s en %s | enlaces %s | por revisar %s | rojos %s y %s alarmas | último depósito %s',
                             coalesce(e.modo, '—'), pg_temp.c16_m(e.por_depositar), e.n_por_depositar,
                             pg_temp.c16_m((select coalesce(sum(v.falta_depositar) filter (where v.falta_depositar > 0), 0) from public.v_stripe_pagos v)),
                             pg_temp.c16_m((select coalesce(-sum(v.falta_depositar) filter (where v.falta_depositar < 0), 0) from public.v_stripe_pagos v)),
                             pg_temp.c16_m(e.en_camino_monto), e.en_camino_n,
                             e.enlaces_activos, e.pagos_revisar, e.cuadres_rojos, e.alarmas,
                             coalesce((select pg_temp.c16_m(q.monto) || ' del ' || q.llegada from public.v_stripe_payouts q
                                        where q.estado = 'asentado' and q.llegada <= pg_temp.c16_hoy()
                                        order by q.llegada desc, q.creado_el desc limit 1), 'ninguno'))
                 from public.v_stripe_estado e$q$ into v_esp;
    v_obt := format('modo %s | falta depositar %s en %s: cobrado que espera %s, por descontar %s | en camino %s en %s | enlaces %s | por revisar %s | rojos %s y %s alarmas | último depósito %s',
                    coalesce(s ->> 'modo', '—'), pg_temp.c16_mj(s -> 'falta_depositar' -> 'monto'), s -> 'falta_depositar' ->> 'n',
                    pg_temp.c16_mj(s -> 'por_depositar' -> 'monto'), pg_temp.c16_mj(coalesce(nullif(s -> 'por_descontar', 'null'::jsonb) -> 'monto', '0'::jsonb)),
                    pg_temp.c16_mj(s -> 'en_camino' -> 'monto'), s -> 'en_camino' ->> 'n', s ->> 'enlaces_activos', s ->> 'pagos_revisar',
                    s ->> 'cuadres_rojos', s ->> 'alarmas',
                    case when s -> 'ultimo_deposito' is null or s -> 'ultimo_deposito' = 'null'::jsonb then 'ninguno'
                         else pg_temp.c16_mj(s -> 'ultimo_deposito' -> 'monto') || ' del ' || (s -> 'ultimo_deposito' ->> 'llegada') end);
    if (s ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(s ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'LOS COBROS EN LÍNEA contra lo que dice Stripe en p1 (v_stripe_estado): el modo, lo que falta depositar y sus dos partes (lo cobrado que espera su depósito y lo que Stripe descontará por un reembolso de algo ya depositado), lo que está en camino, los enlaces activos, los pagos por revisar, los cuadres y alarmas en rojo; y el último depósito que llegó',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 22. EL USE TAX: lo de este mes y del mes pasado, del DR-15 de c9
--     (v_dr15_mes: la base, lo cargado y lo pagado en la 2300), lo que se
--     debía al cierre del mes pasado contra el libro, y lo que se debe hoy (el
--     libro hasta hoy).
do $$
declare
  v_obt text; v_esp text; u jsonb := pg_temp.c16_tc('use_tax'); v_hoy date := pg_temp.c16_hoy(); v_cta text; r record; k record;
  v_fin date := date_trunc('month', pg_temp.c16_hoy())::date - 1; v_falta numeric;
begin
  if pg_temp.c16_omitir(22, 'el use tax', 'lo del DR-15 y el libro', false, array['c9']) then return; end if;
  begin
    v_cta := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
    execute 'select d.compras_use_tax_base as b, d.use_tax_cargado_2300 as c, d.use_tax_pagado_2300 as p from public.v_dr15_mes d where d.periodo = $1'
      into r using to_char(v_hoy, 'YYYY-MM');
    execute 'select d.compras_use_tax_base as b, d.use_tax_cargado_2300 as c, d.use_tax_pagado_2300 as p, d.use_tax_saldo_2300 as s from public.v_dr15_mes d where d.periodo = $1'
      into k using to_char(v_fin, 'YYYY-MM');
    -- (el DR-15 que toca, el del mes pasado: lo que se debía al cerrarlo, menos lo pagado en este mes; se paga a más tardar el 20)
    v_falta := greatest(-pg_temp.c16_libro(array[v_cta], v_fin)
                        - (select coalesce(sum(l.monto) filter (where l.monto > 0), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                            where l.cuenta = v_cta and a.fecha_contable between v_fin + 1 and v_hoy), 0);
    v_esp := format('hoy se debe %s | este mes: base %s, cargado %s, pagado %s | mes pasado: %s | el DR-15 que toca: %s | lleva a: Cierre del mes → DR-15',
                    pg_temp.c16_m(-pg_temp.c16_libro(array[v_cta], v_hoy)), pg_temp.c16_m(r.b), pg_temp.c16_m(r.c), pg_temp.c16_m(r.p),
                    case when v_fin < pg_temp.c16('libro_desde')::date then 'de antes del libro (lo dice)'
                         else format('base %s, cargado %s, pagado %s, al cierre %s (el libro: %s)', pg_temp.c16_m(k.b), pg_temp.c16_m(k.c), pg_temp.c16_m(k.p),
                                     pg_temp.c16_m(k.s), pg_temp.c16_m(-pg_temp.c16_libro(array[v_cta], v_fin))) end,
                    case when v_fin < pg_temp.c16('libro_desde')::date then 'ninguno'
                         else format('falta pagar %s, vence el %s', pg_temp.c16_m(v_falta), v_fin + 20) end);
    v_obt := format('hoy se debe %s | este mes: base %s, cargado %s, pagado %s | mes pasado: %s',
                    pg_temp.c16_mj(u -> 'saldo_hoy'), pg_temp.c16_mj(u -> 'mes' -> 'base'), pg_temp.c16_mj(u -> 'mes' -> 'cargado'),
                    pg_temp.c16_mj(u -> 'mes' -> 'pagado'),
                    case when u -> 'mes_pasado' is null or u -> 'mes_pasado' = 'null'::jsonb
                         then case when u ->> 'sin_mes_pasado' like '%QuickBooks%' then 'de antes del libro (lo dice)' else 'ninguno, sin decir por qué' end
                         else format('base %s, cargado %s, pagado %s, al cierre %s (el libro: %s)', pg_temp.c16_mj(u -> 'mes_pasado' -> 'base'),
                                     pg_temp.c16_mj(u -> 'mes_pasado' -> 'cargado'), pg_temp.c16_mj(u -> 'mes_pasado' -> 'pagado'),
                                     pg_temp.c16_mj(u -> 'mes_pasado' -> 'saldo_al_cierre'), pg_temp.c16_mj(u -> 'mes_pasado' -> 'saldo_al_cierre')) end)
             || format(' | el DR-15 que toca: %s | lleva a: %s',
                       case when u -> 'dr15' is null or u -> 'dr15' = 'null'::jsonb then 'ninguno'
                            else format('falta pagar %s, vence el %s', pg_temp.c16_mj(u -> 'dr15' -> 'falta'), u -> 'dr15' ->> 'vence') end,
                       case when u -> 'ir' ->> 'pagina' = 'cierre' and u -> 'ir' ->> 'sub' = 'dr15' then 'Cierre del mes → DR-15'
                            else 'otra página: ' || coalesce(u ->> 'ir', '—') end);
    if (u ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(u ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'EL USE TAX: lo de este mes y del mes pasado del DR-15 de c9 (la base, lo cargado y lo pagado en la 2300), lo que se debía al cierre del mes pasado contra el libro, lo que se debe hoy (el libro hasta hoy), el DR-15 que toca (el del mes pasado: lo que falta pagar y que vence el 20) y su enlace a la pestaña DR-15 del cierre',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. LOS PRÉSTAMOS contra c6: lo que se debe de cada uno (el saldo inicial
--     menos el capital de sus cuotas registradas, de prestamo_cuotas), la
--     próxima cuota (la fecha siguiente de su calendario y su reparto por la
--     fórmula de c6, fn_prestamo_particion), el total contra sus cuentas en el
--     libro; y un préstamo SEMANAL de prueba, sin cuotas, con su primera cuota
--     en su primer pago.
do $$
declare
  v_obt text; v_esp text; p jsonb := pg_temp.c16_tc('prestamos'); r record; v_l text := ''; v_o text := ''; v_ctas text[];
  v_f date; v_part jsonb; v_id uuid; w jsonb; v_sem text; v_sem_esp text;
begin
  if pg_temp.c16_omitir(23, 'los préstamos', 'el saldo, la próxima cuota y el libro', false, array['c6_prestamos']) then return; end if;
  begin
    for r in execute $q$select x.id, x.prestamista, x.saldo_inicial, x.cuota, x.primer_pago, x.dia_pago, x.cuotas_al_anio, x.saldo_inicial_al,
                               (x.saldo_inicial - coalesce((select sum(q.capital) from public.prestamo_cuotas q where q.prestamo_id = x.id and q.anulada_el is null), 0))::numeric(14,2) as saldo,
                               (select max(q.fecha) from public.prestamo_cuotas q where q.prestamo_id = x.id and q.anulada_el is null) as ultima
                          from public.prestamos x where x.estado = 'vigente' order by x.prestamista, x.id$q$ loop
      -- (la fecha siguiente: mensual, el día de pago del mes después de la última cuota; sin cuotas, la primera del calendario después del saldo inicial)
      if r.cuotas_al_anio = 12 then
        v_f := case when r.ultima is not null then (date_trunc('month', r.ultima) + interval '1 month')::date
                    else (select min(g)::date from generate_series(date_trunc('month', r.primer_pago), date_trunc('month', r.primer_pago) + interval '600 months', interval '1 month') g
                           where (g::date + least(coalesce(r.dia_pago, extract(day from r.primer_pago)::int),
                                                   extract(day from (g + interval '1 month' - interval '1 day'))::int) - 1) > coalesce(r.saldo_inicial_al, r.primer_pago - 1)) end;
        v_f := v_f + least(coalesce(r.dia_pago, extract(day from r.primer_pago)::int), extract(day from (v_f + interval '1 month' - interval '1 day'))::int) - 1;
      else
        v_f := null;   -- (las otras frecuencias las mira el préstamo semanal de abajo)
      end if;
      execute 'select public.fn_prestamo_particion($1, $2, $3)' into v_part using r.id, v_f, r.cuota;
      v_l := v_l || format('%s: debe %s; próxima %s de %s (capital %s, interés %s); ', r.prestamista, pg_temp.c16_m(r.saldo), coalesce(v_f::text, '?'),
                           pg_temp.c16_m(least(r.cuota, r.saldo + (v_part ->> 'interes')::numeric)), v_part ->> 'capital', v_part ->> 'interes');
    end loop;
    execute $q$select array(select distinct u from public.prestamos x, unnest(array[x.cuenta, x.cuenta_largo]) u where u is not null order by 1)$q$ into v_ctas;
    -- (sin préstamos, sin cuentas: el libro no tiene nada que decir)
    v_esp := v_l || format('total %s = el libro %s', pg_temp.c16_m(coalesce((select sum(x.saldo) from v_prestamos x where x.estado = 'vigente'), 0)),
                           case when cardinality(v_ctas) = 0 then '—' else pg_temp.c16_m(-pg_temp.c16_libro(v_ctas, pg_temp.c16_hoy())) end);
    select string_agg(format('%s: debe %s; próxima %s de %s (capital %s, interés %s); ', x ->> 'prestamista', pg_temp.c16_mj(x -> 'saldo'),
                             coalesce(x -> 'proxima' ->> 'fecha', '?'), pg_temp.c16_mj(x -> 'proxima' -> 'monto'),
                             x -> 'proxima' ->> 'capital', x -> 'proxima' ->> 'interes'), '' order by x ->> 'prestamista', x ->> 'prestamo_id')
      into v_o from jsonb_array_elements(p -> 'lista') x where x ->> 'estado' = 'vigente';
    v_obt := coalesce(v_o, '') || format('total %s = el libro %s', pg_temp.c16_mj(p -> 'totales' -> 'saldo'), pg_temp.c16_mj(p -> 'libro' -> 'saldo'));
    if (p ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(p ->> 'motivo', pg_temp.c16('t_error')); end if;
    -- EL PRÉSTAMO SEMANAL de prueba (se deshace): 5,000 al 6.5 %, 120 a la semana, el primer pago dentro de 3 días
    begin
      perform pg_temp.c16_ser('editor');
      w := fn_prestamo_guardar(jsonb_build_object('prestamista', 'ZZ C16 PRUEBA SEMANAL', 'descripcion', 'C16 PRUEBA (se deshace)',
             'principal', '5000.00', 'tasa_anual', '6.5', 'cuota', '120.00', 'primer_pago', (pg_temp.c16_hoy() + 3)::text,
             'plazo_meses', 12, 'saldo_inicial', '5000.00', 'saldo_inicial_al', pg_temp.c16_hoy()::text, 'frecuencia', 'semanal',
             'descriptor', 'ZZ C16 PRUEBA SEMANAL'));
      v_id := coalesce((w ->> 'id')::uuid, (w ->> 'prestamo_id')::uuid, (select x.id from prestamos x where x.prestamista = 'ZZ C16 PRUEBA SEMANAL'));
      v_part := fn_prestamo_particion(v_id, pg_temp.c16_hoy() + 3, 120.00);
      v_sem_esp := format('semanal: próxima %s de 120.00 (capital %s, interés %s), la siguiente %s', pg_temp.c16_hoy() + 3, v_part ->> 'capital', v_part ->> 'interes',
                          pg_temp.c16_hoy() + 10);
      select format('semanal: próxima %s de %s (capital %s, interés %s), la siguiente %s', x -> 'proxima' ->> 'fecha', pg_temp.c16_mj(x -> 'proxima' -> 'monto'),
                    x -> 'proxima' ->> 'capital', x -> 'proxima' ->> 'interes',
                    (select (q ->> 'fecha') from jsonb_array_elements(pg_temp.c16_j(format('select coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) from public.fn_tablero_cuotas(%L::date) c',
                                                                                          pg_temp.c16_hoy() + 30))) q
                      where (q ->> 'prestamo_id')::uuid = v_id and (q ->> 'n')::int = 2))
        into v_sem
        from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_prestamos()') -> 'lista') x
       where (x ->> 'prestamo_id')::uuid = v_id;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_sem := 'error ' || sqlstate || ': ' || sqlerrm;
    end;
    perform pg_temp.c16_ser('editor');
    v_esp := v_esp || ' | ' || coalesce(v_sem_esp, 'el semanal de prueba');
    v_obt := v_obt || ' | ' || coalesce(v_sem, 'el semanal no salió en la tarjeta');
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'LOS PRÉSTAMOS contra c6: lo que se debe de cada uno (el saldo inicial menos el capital de sus cuotas registradas), la próxima cuota (la fecha siguiente de su calendario y su reparto por la fórmula de c6), el total contra sus cuentas en el libro; y un préstamo SEMANAL de prueba con su primera cuota en su primer pago y la siguiente a los 7 días',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. LAS OBRAS: el WIP del mes que toca, igual que el resumen de c12
--     (fn_wip_resumen: sobre y sub-facturado, la provisión de pérdida, el
--     ajuste), y el costo por obra igual que c10 (v_margen_obra: las obras con
--     más ingreso y los totales de todas las que tienen ingreso o costo).
do $$
declare
  v_obt text; v_esp text; o jsonb := pg_temp.c16_tc('obras'); j jsonb; v_w text; v_c text;
begin
  if pg_temp.c16_omitir(24, 'las obras', 'el WIP de c12 y el costo por obra de c10', false, array['c10', 'c12']) then return; end if;
  begin
    j := pg_temp.c16_j('select public.fn_wip_resumen(null)');
    v_w := format('WIP %s: sobre %s, sub %s, pérdida %s, ajuste al día %s', j ->> 'periodo', pg_temp.c16_mj(j -> 'totales' -> 'sobre_facturado'),
                  pg_temp.c16_mj(j -> 'totales' -> 'sub_facturado'), pg_temp.c16_mj(j -> 'totales' -> 'perdida_provision'),
                  coalesce(j -> 'ajuste' ->> 'al_dia', '—'));
    select format('costo: %s obras, ingreso %s, costo %s, margen %s; las de más ingreso: %s', count(*), pg_temp.c16_m(sum(m.ingreso_libro)),
                  pg_temp.c16_m(sum(m.costo_real)), pg_temp.c16_m(sum(m.margen_real)),
                  (select string_agg(y.obra || ' ' || pg_temp.c16_m(y.ingreso_libro), ', ' order by y.ingreso_libro desc, y.obra)
                     from (select * from v_margen_obra z where coalesce(z.ingreso_libro, 0) <> 0 or coalesce(z.costo_real, 0) <> 0
                            order by z.ingreso_libro desc, z.obra limit 5) y))
      into v_c from v_margen_obra m where coalesce(m.ingreso_libro, 0) <> 0 or coalesce(m.costo_real, 0) <> 0;
    v_esp := v_w || ' | ' || v_c;
    v_obt := format('WIP %s: sobre %s, sub %s, pérdida %s, ajuste al día %s', o -> 'wip' ->> 'periodo', pg_temp.c16_mj(o -> 'wip' -> 'sobre_facturado'),
                    pg_temp.c16_mj(o -> 'wip' -> 'sub_facturado'), pg_temp.c16_mj(o -> 'wip' -> 'perdida_provision'),
                    coalesce(o -> 'wip' -> 'ajuste' ->> 'al_dia', '—'))
             || ' | ' ||
             format('costo: %s obras, ingreso %s, costo %s, margen %s; las de más ingreso: %s', o -> 'costo' -> 'totales' ->> 'n',
                    pg_temp.c16_mj(o -> 'costo' -> 'totales' -> 'ingreso'), pg_temp.c16_mj(o -> 'costo' -> 'totales' -> 'costo'),
                    pg_temp.c16_mj(o -> 'costo' -> 'totales' -> 'margen'),
                    (select string_agg((x ->> 'obra') || ' ' || pg_temp.c16_mj(x -> 'ingreso'), ', ' order by u)
                       from jsonb_array_elements(o -> 'costo' -> 'obras') with ordinality t(x, u)));
    if (o -> 'wip' ->> 'neto')::numeric is distinct from ((j -> 'totales' ->> 'sub_facturado')::numeric - (j -> 'totales' ->> 'sobre_facturado')::numeric) then
      v_obt := v_obt || ' (el neto no es sub − sobre)';
    end if;
    if (o ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(o ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'LAS OBRAS: el WIP del mes que toca igual que el resumen de c12 (sobre y sub-facturado, la provisión de pérdida, el ajuste; el neto = sub − sobre) y el costo por obra igual que c10 (las de más ingreso y los totales de las que tienen ingreso o costo)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LOS BORDES (25 a 29): cada uno siembra lo suyo o finge el reloj dentro
-- de un bloque que se deshace (MXT00).
-- =====================================================================

-- 25. LA FACTURA QUE VENCE HOY: con los términos en 0 («due on receipt»),
--     una factura de hoy vence hoy: corriente, con 0 días (todavía no está
--     vencida) y entre lo por vencer de la tarjeta de facturas; mañana (el
--     reloj fingido), en el tramo 1–30 con 1 día.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_f bigint; a jsonb; b jsonb; x jsonb; y jsonb;
begin
  if pg_temp.c16_omitir(25, 'la factura que vence hoy', 'hoy corriente con 0 días; mañana 1–30 con 1 día', true) then return; end if;
  v_esp := format('hoy: vence el %s, corriente, 0 días; por vencer +1234.57 | mañana: d1_30, 1 día', v_hoy);
  begin
    if pg_temp.c16_capa('c11') then
      perform pg_temp.c16_j('select public.fn_emision_config(''{"terminos_dias": 0}''::jsonb)');
    end if;
    a := pg_temp.c16_j('select public.fn_tablero_facturas()');
    perform pg_temp.c16_sembrar();
    v_f := pg_temp.c16_factura(1, 'c16-prueba-a', 1234.57, v_hoy);
    b := pg_temp.c16_j('select public.fn_tablero_facturas()');
    x := pg_temp.c16_j(format('select to_jsonb(x) from public.fn_tablero_cxc() x where x.factura_id = %s', v_f));
    perform pg_temp.c16_fingir_hoy(v_hoy + 1);
    y := pg_temp.c16_j(format('select to_jsonb(x) from public.fn_tablero_cxc() x where x.factura_id = %s', v_f));
    v_obt := format('hoy: vence el %s, %s, %s días; por vencer +%s | mañana: %s, %s día', x ->> 'vence', x ->> 'tramo', x ->> 'dias_vencida',
                    pg_temp.c16_m((b -> 'no_pagadas' -> 'por_vencer' ->> 'monto')::numeric - (a -> 'no_pagadas' -> 'por_vencer' ->> 'monto')::numeric),
                    y ->> 'tramo', y ->> 'dias_vencida');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (25, 'BORDE, LA FACTURA QUE VENCE HOY: con los términos en 0, una factura de hoy vence hoy y está corriente (0 días: vencida es desde mañana) y entre lo por vencer; mañana (el reloj fingido), en 1–30 con 1 día',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. LA FACTURA COBRADA A MEDIAS: una factura de 1,000.00 con un cobro de
--     400.00 hoy queda por cobrar en 600.00 (una partida más en el embudo,
--     +600.00); lo cobrado sube 400.00 (un cobro y una factura más) y, como
--     ese cheque todavía no sale en el banco, va en «sin depositar» (sin
--     casar); el embudo sigue cuadrando con el libro.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_f bigint; a jsonb; b jsonb; x jsonb; v_c6 boolean := pg_temp.c16_capa('c6');
begin
  if pg_temp.c16_omitir(26, 'la factura cobrada a medias', 'queda en 600.00; cobrado +400.00 sin depositar', true) then return; end if;
  v_esp := format('la factura queda en 600.00, corriente | por cobrar +600.00 (+1 partida) | cobrado +400.00 (+1 cobro, +1 factura) | '
                  'sin depositar +%s | el cuadre con el libro: sí', case when v_c6 then '400.00 (sin casar)' else '— (sin el banco)' end);
  begin
    a := pg_temp.c16_j('select public.fn_tablero_cobros()');
    perform pg_temp.c16_sembrar();
    v_f := pg_temp.c16_factura(2, 'c16-prueba-a', 1000.00, v_hoy);
    perform pg_temp.c16_cobro(v_hoy, 400.00, v_f);
    b := pg_temp.c16_j('select public.fn_tablero_cobros()');
    x := pg_temp.c16_j(format('select to_jsonb(x) from public.fn_tablero_cxc() x where x.factura_id = %s', v_f));
    v_obt := format('la factura queda en %s, %s | por cobrar +%s (+%s partida) | cobrado +%s (+%s cobro, +%s factura) | sin depositar +%s | el cuadre con el libro: %s',
                    pg_temp.c16_mj(x -> 'por_cobrar'), x ->> 'tramo',
                    pg_temp.c16_m((b -> 'por_cobrar' ->> 'monto')::numeric - (a -> 'por_cobrar' ->> 'monto')::numeric),
                    (b -> 'por_cobrar' ->> 'n')::int - (a -> 'por_cobrar' ->> 'n')::int,
                    pg_temp.c16_m((b -> 'cobrado' ->> 'monto')::numeric - (a -> 'cobrado' ->> 'monto')::numeric),
                    (b -> 'cobrado' ->> 'n')::int - (a -> 'cobrado' ->> 'n')::int,
                    (b -> 'cobrado' ->> 'facturas')::int - (a -> 'cobrado' ->> 'facturas')::int,
                    case when v_c6 then pg_temp.c16_m((b -> 'sin_depositar' -> 'sin_casar' ->> 'monto')::numeric
                                                      - (a -> 'sin_depositar' -> 'sin_casar' ->> 'monto')::numeric) || ' (sin casar)'
                         else '— (sin el banco)' end,
                    case when (b -> 'cuadre' ->> 'ok')::boolean then 'sí' else 'NO' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (26, 'BORDE, LA FACTURA COBRADA A MEDIAS: 1,000.00 con un cobro de 400.00 queda por cobrar en 600.00; lo cobrado sube 400.00 (un cobro y una factura más) y va en «sin depositar» mientras el banco no lo trae; el embudo sigue cuadrando con el libro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. EL MES SIN MOVIMIENTOS: con el reloj en el mes que sigue al que viene,
--     el mes que viene (sin ningún asiento) sale en la caja sin movimientos
--     (lo mismo al empezar que al terminar: el efectivo del libro al fin de
--     este mes), sus resultados en cero (sin margen: no hay ingresos) y sus
--     ventas en 0.00; no se salta ni se inventa.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_m date := (date_trunc('month', pg_temp.c16_hoy()) + interval '1 month')::date;
  v_fin date; v_fake date; v_ini numeric; c jsonb; r jsonb; v jsonb; x jsonb; v_mes text;
begin
  v_fin := (v_m + interval '1 month')::date - 1;
  v_fake := v_fin + 10;
  v_mes := to_char(v_m, 'YYYY-MM');
  if pg_temp.c16_omitir(27, 'el mes sin movimientos', 'el mes que viene, sin asientos: en cero y sin saltarlo') then return; end if;
  if exists (select 1 from asientos a where a.fecha_contable between v_m and v_fake) then
    insert into _pruebas values (27, 'BORDE, EL MES SIN MOVIMIENTOS', 'el mes que viene, sin asientos',
      'omitida: el mes que viene ya tiene asientos (fechados después de hoy): no hay un mes sin movimientos que mirar', null);
    return;
  end if;
  -- (el efectivo al empezar ese mes: las cuentas de efectivo del libro, en negro, hasta el fin de este mes)
  select coalesce(sum(greatest(z.s, 0)), 0) into v_ini
    from (select (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                   where l.cuenta = m.cuenta and a.fecha_contable < v_m) as s
            from v_estados_mapeo m where m.efectivo) z;
  v_esp := format('caja de %s: sin movimientos, %s → %s (+0.00 −0.00) | resultados: 0 asientos, ingresos 0.00, costo y gastos 0.00, resultado 0.00, '
                  'margen — | ventas de %s: 0.00', v_mes, pg_temp.c16_m(v_ini), pg_temp.c16_m(v_ini), v_mes);
  begin
    perform pg_temp.c16_fingir_hoy(v_fake);
    c := pg_temp.c16_j('select public.fn_tablero_caja(12, 0)');
    r := pg_temp.c16_j(format('select public.fn_tablero_resultados(%L::date, %L::date)', v_m, v_fin));
    v := pg_temp.c16_j(format('select public.fn_tablero_ventas(%s)', extract(year from v_m)::int));
    select e into x from jsonb_array_elements(c -> 'meses') e where e ->> 'mes' = v_mes;
    v_obt := format('caja de %s: %s, %s → %s (+%s −%s) | resultados: %s asientos, ingresos %s, costo y gastos %s, resultado %s, margen %s | ventas de %s: %s',
                    v_mes, case when x is null then 'no está' when (x ->> 'sin_movimientos')::boolean then 'sin movimientos' else 'con movimientos' end,
                    pg_temp.c16_mj(x -> 'inicial'), pg_temp.c16_mj(x -> 'final'), pg_temp.c16_mj(x -> 'entradas'), pg_temp.c16_mj(x -> 'salidas'),
                    r ->> 'asientos', pg_temp.c16_mj(r -> 'ingresos'), pg_temp.c16_mj(r -> 'barras' -> 1 -> 'monto'), pg_temp.c16_mj(r -> 'resultado'),
                    coalesce(r ->> 'margen_pct', '—'), v_mes,
                    coalesce((select pg_temp.c16_mj(e -> 'monto') from jsonb_array_elements(v -> 'meses') e where e ->> 'mes' = v_mes), 'no está'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (27, 'BORDE, EL MES SIN MOVIMIENTOS: con el reloj más adelante, el mes que viene (sin asientos) sale en la caja sin movimientos y con el mismo efectivo al empezar que al terminar (el del libro al fin de este mes), sus resultados en cero sin margen y sus ventas en 0.00: no se salta ni se inventa',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. EL PRIMER MES DEL LIBRO: sus resultados no se comparan con el mes de
--     antes (es de QuickBooks: lo dice); un período todo de antes del libro
--     no se cuenta (lo dice); uno que cruza el inicio cuenta desde que hay
--     libro (parcial) y da lo que dice el libro; las ventas del año dicen
--     cuántos meses son de antes; la caja empieza en la apertura.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_lib date := pg_temp.c16('libro_desde')::date; v_fin date; v_ap date;
  r1 jsonb; r2 jsonb; r3 jsonb; v jsonb; c jsonb; v_antes int;
begin
  if pg_temp.c16_omitir(28, 'el primer mes del libro', 'sin comparar con lo de QuickBooks') then return; end if;
  if v_lib is null or v_lib > v_hoy then
    insert into _pruebas values (28, 'BORDE, EL PRIMER MES DEL LIBRO', 'un libro que ya empezó', 'omitida: el libro todavía no empieza', null);
    return;
  end if;
  v_fin := least((date_trunc('month', v_lib) + interval '1 month')::date - 1, v_hoy);
  select pa.hasta into v_ap from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1;
  -- (la línea empieza en la apertura solo si su asiento ya está en el libro)
  if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null
                    and not exists (select 1 from asientos r where r.reversa_a = a.id)) then
    v_ap := null;
  end if;
  v_antes := extract(month from v_lib)::int - 1;
  v_esp := format('el primer mes (%s a %s): sin comparación, lo dice | todo de antes del libro: no se cuenta, lo dice | cruzando el inicio: parcial, '
                  'cuenta desde el %s, resultado %s | ventas de %s: %s | caja: %s',
                  v_lib, v_fin, v_lib, (pg_temp.c16_res(v_lib - 10, v_fin) ->> 'resultado'), extract(year from v_lib),
                  case when v_antes > 0 then v_antes || ' meses de antes del libro (QuickBooks), la primera ' || to_char(v_lib, 'YYYY-MM')
                       else 'la primera ' || to_char(v_lib, 'YYYY-MM') end,
                  case when v_ap is not null then 'la línea empieza en la apertura del ' || v_ap else 'la línea empieza en el primer mes' end
                  || ', el primer mes ' || to_char(v_lib, 'YYYY-MM'));
  begin
    r1 := pg_temp.c16_j(format('select public.fn_tablero_resultados(%L::date, %L::date)', v_lib, v_fin));
    r2 := pg_temp.c16_j(format('select public.fn_tablero_resultados(%L::date, %L::date)', v_lib - 31, v_lib - 1));
    r3 := pg_temp.c16_j(format('select public.fn_tablero_resultados(%L::date, %L::date)', v_lib - 10, v_fin));
    v := pg_temp.c16_j(format('select public.fn_tablero_ventas(%s)', extract(year from v_lib)::int));
    c := pg_temp.c16_j('select public.fn_tablero_caja(36, 0)');
    v_obt := format('el primer mes (%s a %s): %s | todo de antes del libro: %s | cruzando el inicio: %s, cuenta desde el %s, resultado %s | ventas de %s: %s | caja: %s',
                    r1 ->> 'desde', r1 ->> 'hasta',
                    case when (r1 -> 'anterior' is null or r1 -> 'anterior' = 'null'::jsonb) and r1 ->> 'sin_comparar' like '%antes del libro%QuickBooks%'
                         then 'sin comparación, lo dice' else 'compara con: ' || coalesce(r1 ->> 'anterior', '?') end,
                    case when (r2 ->> 'ok')::boolean is false and (r2 ->> 'antes_del_libro')::boolean and r2 ->> 'motivo' like '%QuickBooks%'
                         then 'no se cuenta, lo dice' else 'otra cosa: ' || left(r2::text, 200) end,
                    case when (r3 ->> 'parcial')::boolean and r3 ->> 'nota' like '%QuickBooks%' then 'parcial' else 'no dice que es parcial' end,
                    r3 ->> 'desde_libro', pg_temp.c16_mj(r3 -> 'resultado'), v ->> 'anio',
                    case when coalesce((v -> 'antes_del_libro' ->> 'meses')::int, 0) > 0 and v -> 'antes_del_libro' ->> 'texto' like '%QuickBooks%'
                         then (v -> 'antes_del_libro' ->> 'meses') || ' meses de antes del libro (QuickBooks), la primera ' || (v -> 'meses' -> 0 ->> 'mes')
                         else 'la primera ' || (v -> 'meses' -> 0 ->> 'mes') end,
                    case when c -> 'serie' -> 0 ->> 'tipo' = 'apertura' then 'la línea empieza en la apertura del ' || (c -> 'serie' -> 0 ->> 'fecha')
                         else 'la línea empieza en el primer mes' end || ', el primer mes ' || (c -> 'meses' -> 0 ->> 'mes'));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'BORDE, EL PRIMER MES DEL LIBRO: no se compara con el mes de antes (vive en QuickBooks: lo dice); un período todo de antes del libro no se cuenta (lo dice); uno que cruza el inicio cuenta desde que hay libro (parcial) y da lo que dice el libro; las ventas del año dicen cuántos meses son de antes; la caja empieza en la apertura',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. EL CAMBIO DE AÑO: con el reloj en el 10 de enero del año que viene,
--     y un gasto el 28 de diciembre y otro el 5 de enero: el año es el nuevo
--     (solo el de enero), el año pasado tiene el de diciembre (y empieza con
--     el libro), las ventas son del año nuevo (un mes), los gastos de 30 días
--     cruzan el año (los dos) y la caja pasa de diciembre a enero.
do $$
declare
  v_obt text; v_esp text; v_y int := extract(year from pg_temp.c16_hoy())::int; v_fake date; d1 date; d2 date;
  v_lib date := pg_temp.c16('libro_desde')::date; ea jsonb; ep jsonb; ra jsonb; rp jsonb; v jsonb; g jsonb; c jsonb; v_g numeric; v_g65 numeric;
begin
  v_fake := make_date(v_y + 1, 1, 10); d1 := make_date(v_y, 12, 28); d2 := make_date(v_y + 1, 1, 5);
  if pg_temp.c16_omitir(29, 'el cambio de año', 'el año nuevo, el pasado y los 30 días que cruzan') then return; end if;
  if not exists (select 1 from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and d1 between p.desde and p.hasta)
     or not exists (select 1 from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and d2 between p.desde and p.hasta) then
    insert into _pruebas values (29, 'BORDE, EL CAMBIO DE AÑO', 'diciembre y enero abiertos',
      format('omitida: diciembre de %s y enero de %s tienen que estar abiertos para sembrar los dos gastos de prueba', v_y, v_y + 1), null);
    return;
  end if;
  begin
    perform pg_temp.c16_fingir_hoy(v_fake);
    perform pg_temp.c16_postear(d1, 'un gasto del 28 de diciembre', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '55.55'),
                                                                                       jsonb_build_object('cuenta', '3100', 'monto', '-55.55')));
    perform pg_temp.c16_postear(d2, 'un gasto del 5 de enero', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '77.77'),
                                                                                  jsonb_build_object('cuenta', '3100', 'monto', '-77.77')));
    ea := pg_temp.c16_res(make_date(v_y + 1, 1, 1), v_fake);
    ep := pg_temp.c16_res(greatest(make_date(v_y, 1, 1), v_lib), make_date(v_y, 12, 31));
    select coalesce(sum(li.monto), 0), coalesce(sum(li.monto) filter (where li.cuenta = '6500'), 0) into v_g, v_g65
      from asiento_lineas li join asientos a on a.id = li.asiento_id
      join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion in ('costo', 'gastos', 'otros_gastos')
     where a.fecha_contable between v_fake - 29 and v_fake and pg_temp.c16_ejercicio(a.id) = extract(year from a.fecha_contable)::int;
    v_esp := format('el año: %s, del %s, gastos %s, resultado %s | el año pasado: %s, del %s, gastos %s, resultado %s%s | ventas: %s, %s mes | '
                    'gastos de 30 días (%s a %s): %s, la 6500 en %s | caja: … dic %s, ene %s',
                    v_y + 1, make_date(v_y + 1, 1, 1), ea ->> 'gastos', ea ->> 'resultado',
                    v_y, make_date(v_y, 1, 1), ep ->> 'gastos', ep ->> 'resultado',
                    case when make_date(v_y, 1, 1) < v_lib then ' (parcial: el libro empieza el ' || v_lib || ')' else '' end,
                    v_y + 1, 1, v_fake - 29, v_fake, pg_temp.c16_m(v_g), pg_temp.c16_m(v_g65), v_y, v_y + 1);
    ra := pg_temp.c16_j('select public.fn_tablero_resultados(null, null, ''anio'')');
    rp := pg_temp.c16_j('select public.fn_tablero_resultados(null, null, ''anio_pasado'')');
    v := pg_temp.c16_j('select public.fn_tablero_ventas()');
    g := pg_temp.c16_j('select public.fn_tablero_gastos()');
    c := pg_temp.c16_j('select public.fn_tablero_caja(12, 0)');
    v_obt := format('el año: %s, del %s, gastos %s, resultado %s | el año pasado: %s, del %s, gastos %s, resultado %s%s | ventas: %s, %s mes | '
                    'gastos de 30 días (%s a %s): %s, la 6500 en %s | caja: … %s, %s',
                    ra ->> 'etiqueta', ra ->> 'desde', pg_temp.c16_mj(ra -> 'gastos'), pg_temp.c16_mj(ra -> 'resultado'),
                    rp ->> 'etiqueta', rp ->> 'desde', pg_temp.c16_mj(rp -> 'gastos'), pg_temp.c16_mj(rp -> 'resultado'),
                    case when (rp ->> 'parcial')::boolean then ' (parcial: el libro empieza el ' || (rp ->> 'desde_libro') || ')' else '' end,
                    v ->> 'anio', jsonb_array_length(v -> 'meses'), g ->> 'desde', g ->> 'hasta', pg_temp.c16_mj(g -> 'total'),
                    coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(g -> 'categorias') x where x ->> 'cuenta' = '6500'), '0.00'),
                    (select x ->> 'etiqueta' from jsonb_array_elements(c -> 'meses') x where x ->> 'mes' = v_y || '-12'),
                    (select x ->> 'etiqueta' from jsonb_array_elements(c -> 'meses') x where x ->> 'mes' = (v_y + 1) || '-01'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (29, 'BORDE, EL CAMBIO DE AÑO: con el reloj en el 10 de enero y un gasto el 28 de diciembre y otro el 5 de enero, el año es el nuevo (solo lo de enero), el año pasado tiene lo de diciembre (desde que empieza el libro), las ventas son del año nuevo (un mes), los gastos de 30 días cruzan el año y la caja pasa de diciembre a enero',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LO QUE FALTA, LO QUE FALLA Y LO MAL PEDIDO (30 a 33)
-- =====================================================================

-- 30. UNA CAPA QUE FALTA: sin los préstamos (c6), sin el DR-15 (c9) y sin
--     Stripe (p1) —se esconden dentro de un bloque que se deshace—, sus
--     tarjetas dicen que su capa no está (falta), las conexiones dicen que
--     Stripe no está instalado, «pedir un pago en línea» no está disponible y
--     el tablero sigue: cada tarjeta contesta o dice qué falta, ninguna falla.
do $$
declare
  v_obt text; v_esp text; t0 jsonb := pg_temp.c16('t')::jsonb; t jsonb; v_antes int; v_mas int := 0;
begin
  if pg_temp.c16_omitir(30, 'una capa que falta', 'la tarjeta lo dice y las demás siguen', false, array['c6_prestamos', 'c9', 'p1']) then return; end if;
  select count(*) into v_antes from jsonb_array_elements_text(t0 -> 'tarjetas') k
   where (t0 -> k ->> 'ok')::boolean is false and t0 -> k ->> 'falta' is not null;
  v_mas := (select count(*) from unnest(array['prestamos', 'use_tax', 'cobros_en_linea']) k where (t0 -> k ->> 'ok')::boolean);
  v_esp := format('préstamos: falta c6 | use tax: falta c9 | cobros en línea: falta p1 | conexiones: contesta, Stripe sin instalar (p1) | '
                  'acciones, pedir un pago: no disponible (p1) | el tablero: 16 contestan, %s dicen que falta su capa, 0 fallan', v_antes + v_mas);
  begin
    execute 'alter view public.v_prestamos rename to v_prestamos_c16_fuera';
    execute 'alter view public.v_dr15_mes rename to v_dr15_mes_c16_fuera';
    execute 'alter table public.stripe_config rename to stripe_config_c16_fuera';
    t := pg_temp.c16_t();
    v_obt := format('préstamos: %s | use tax: %s | cobros en línea: %s | conexiones: %s | acciones, pedir un pago: %s | el tablero: %s contestan, %s dicen que falta su capa, %s fallan',
                    case when (t -> 'prestamos' ->> 'ok')::boolean then 'contesta' else 'falta ' || coalesce(t -> 'prestamos' ->> 'falta', '¿?') end,
                    case when (t -> 'use_tax' ->> 'ok')::boolean then 'contesta' else 'falta ' || coalesce(t -> 'use_tax' ->> 'falta', '¿?') end,
                    case when (t -> 'cobros_en_linea' ->> 'ok')::boolean then 'contesta' else 'falta ' || coalesce(t -> 'cobros_en_linea' ->> 'falta', '¿?') end,
                    case when (t -> 'conexiones' ->> 'ok')::boolean then 'contesta' else 'no contesta' end
                    || coalesce((select ', Stripe sin instalar (' || (x ->> 'falta') || ')' from jsonb_array_elements(t -> 'conexiones' -> 'sin_instalar') x
                                  where x ->> 'tipo' = 'cobros'), ', Stripe sigue en la lista'),
                    coalesce((select case when (x ->> 'disponible')::boolean then 'disponible' else 'no disponible (' || coalesce(x ->> 'falta', '?') || ')' end
                                from jsonb_array_elements(t -> 'acciones' -> 'lista') x where x ->> 'clave' = 'pago'), 'no está'),
                    (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k
                      where (t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null),
                    (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k
                      where (t -> k ->> 'ok')::boolean is false and t -> k ->> 'falta' is not null),
                    (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k
                      where (t -> k ->> 'ok')::boolean is false and t -> k ->> 'falta' is null));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (30, 'UNA CAPA QUE FALTA: sin los préstamos (c6), sin el DR-15 (c9) y sin Stripe (p1), sus tarjetas dicen qué capa falta, las conexiones dicen que Stripe no está instalado, «pedir un pago en línea» no está disponible y el tablero sigue: cada tarjeta contesta o dice qué falta, ninguna falla',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 31. UNA TARJETA QUE FALLA: si la antigüedad de lo por cobrar de c4 no se
--     deja leer (se le quita el permiso dentro de un bloque que se deshace),
--     las cuatro tarjetas que la usan (el embudo, la caja, las facturas y lo
--     por cobrar) dicen que no se pudieron leer, con el código (42501), y las
--     demás contestan; la tarjeta sola, por la API, da el error.
do $$
declare
  v_obt text; v_esp text; t jsonb; e text;
begin
  if pg_temp.c16_omitir(31, 'una tarjeta que falla', 'la que falla lo dice y las demás contestan') then return; end if;
  v_esp := 'no se pudieron leer, con 42501: caja, cobros, facturas, por_cobrar | las demás contestan: 12 | la tarjeta sola: 42501';
  begin
    execute 'revoke select on public.v_cxc_antiguedad from authenticated';
    t := pg_temp.c16_t();
    e := pg_temp.c16_estado('select public.fn_tablero_antiguedad(''cobrar'')');
    v_obt := format('no se pudieron leer, con 42501: %s | las demás contestan: %s | la tarjeta sola: %s',
                    (select string_agg(k, ', ' order by k) from jsonb_array_elements_text(t -> 'tarjetas') k
                      where (t -> k ->> 'ok')::boolean is false and t -> k ->> 'motivo' like 'Esta tarjeta no se pudo leer%' and t -> k ->> 'codigo' = '42501'),
                    (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k
                      where (t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null),
                    e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (31, 'UNA TARJETA QUE FALLA: sin permiso para leer la antigüedad de lo por cobrar de c4, las cuatro tarjetas que la usan dicen que no se pudieron leer (con su código, 42501) y las otras doce contestan; la tarjeta sola, por la API, da el error',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. EL TOPE POR RELOJ: con un tope de 1 ms, lo que no alcanzó sale en
--     «sigue» ({ok: false, sigue: true}, sin error) y, pedido otra vez, llega
--     igual que sin tope; entre las dos llamadas, las 16 tarjetas.
do $$
declare
  v_obt text; v_esp text; t0 jsonb := pg_temp.c16('t')::jsonb; t1 jsonb; t2 jsonb; v_dif text;
begin
  if pg_temp.c16_omitir(32, 'el tope por reloj', 'lo que no alcanzó sale en «sigue» y llega al pedirlo otra vez') then return; end if;
  v_esp := 'la primera: ok, lo que no alcanzó en «sigue» (sin error) | la segunda: lo de «sigue», igual que sin tope | entre las dos: las 16';
  begin
    t1 := pg_temp.c16_t('{"tope_ms": 1}');
    t2 := pg_temp.c16_t(jsonb_build_object('tarjetas', t1 -> 'sigue', 'tope_ms', 0));
    select string_agg(k, ', ' order by k) into v_dif
      from jsonb_array_elements_text(t1 -> 'sigue') k
     where case when k = 'bancos' then (t2 -> k -> 'totales') is distinct from (t0 -> k -> 'totales')
                else (t2 -> k) - 'ms' is distinct from (t0 -> k) - 'ms' end;
    v_obt := format('la primera: %s, lo que no alcanzó en «sigue» (%s) | la segunda: %s | entre las dos: %s',
                    case when (t1 ->> 'ok')::boolean then 'ok' else 'no' end,
                    case when not exists (select 1 from jsonb_array_elements_text(t1 -> 'sigue') k
                                           where not coalesce((t1 -> k ->> 'sigue')::boolean, false) or t1 -> k ->> 'codigo' is not null)
                         then 'sin error' else 'con error' end,
                    case when jsonb_array_length(t1 -> 'sigue') = 0 then 'no hizo falta (todo alcanzó en 1 ms)'
                         when v_dif is null and jsonb_array_length(t2 -> 'sigue') = 0 then 'lo de «sigue», igual que sin tope'
                         else 'distinto en: ' || coalesce(v_dif, 'sigue otra vez') end,
                    case when (select count(distinct k) from (select jsonb_array_elements_text(t1 -> 'tarjetas') k
                                                              except select jsonb_array_elements_text(t1 -> 'sigue')
                                                              union select jsonb_array_elements_text(t2 -> 'tarjetas')) u) = 16
                         then 'las 16' else 'faltan' end);
    if jsonb_array_length(t1 -> 'sigue') = 0 then
      v_obt := replace(v_obt, 'no hizo falta (todo alcanzó en 1 ms)', 'lo de «sigue», igual que sin tope');
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'EL TOPE POR RELOJ: con un tope de 1 ms, lo que no alcanzó sale en «sigue» ({ok: false, sigue: true}, sin error) y, pedido otra vez, llega igual que sin tope; entre las dos llamadas, las 16 tarjetas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. LO MAL PEDIDO: una tarjeta, una clave o un período que no existen,
--     un número fuera de su rango o en letra, una fecha mal escrita, un
--     rango al revés o un período con fechas: 22023 (la fecha, 22007), sin
--     pintar nada a medias; sin tarjetas pedidas, contesta vacío.
do $$
declare
  v_obt text := ''; v_esp text := ''; r record;
begin
  if pg_temp.c16_omitir(33, 'lo mal pedido', '22023 / 22007') then return; end if;
  for r in select * from (values
      (1, 'una tarjeta que no existe', 'select public.fn_tablero(''{"tarjetas": ["otra"]}'')', '22023'),
      (2, 'una clave que no existe', 'select public.fn_tablero(''{"otra": 1}'')', '22023'),
      (3, '0 días', 'select public.fn_tablero(''{"cobros": {"dias": 0}}'')', '22023'),
      (4, 'los días en letra', 'select public.fn_tablero(''{"cobros": {"dias": "treinta"}}'')', '22023'),
      (5, 'una fecha mal escrita', 'select public.fn_tablero(''{"resultados": {"desde": "2026-13-01", "hasta": "2026-12-31"}}'')', '22007'),
      (6, 'un período que no existe', 'select public.fn_tablero(''{"resultados": {"periodo": "semana"}}'')', '22023'),
      (7, 'una caja de 0 meses', 'select public.fn_tablero(''{"caja": {"meses": 0}}'')', '22023'),
      (8, 'un tope de 9 s', 'select public.fn_tablero(''{"tope_ms": 9000}'')', '22023'),
      (9, 'lo pedido no es un objeto', 'select public.fn_tablero(''[1]'')', '22023'),
      (10, 'el lado «otro»', 'select public.fn_tablero_antiguedad(''otro'')', '22023'),
      (11, 'un rango al revés', 'select public.fn_tablero_resultados(''2026-11-02'', ''2026-11-01'')', '22023'),
      (12, 'un período con fechas', 'select public.fn_tablero_resultados(''2026-11-01'', ''2026-11-30'', ''mes'')', '22023'),
      (13, 'gastos de 0 días', 'select public.fn_tablero_gastos(0)', '22023'),
      (14, 'las ventas del año 1800', 'select public.fn_tablero_ventas(1800)', '22023'),
      (15, '0 obras', 'select public.fn_tablero_obras(0)', '22023'),
      (16, 'el embudo de 400 días', 'select public.fn_tablero_cobros(400)', '22023'),
      (17, 'ninguna tarjeta', 'select public.fn_tablero(''{"tarjetas": []}'')', 'ok'),
      -- (14-nov, Fase 11c) la nómina: sus meses van de 1 a 24, esté o no c15; y no tiene más claves
      (18, 'una nómina de 0 meses', 'select public.fn_tablero(''{"nomina": {"meses": 0}}'')', '22023'),
      (19, 'una nómina de 25 meses', 'select public.fn_tablero_nomina(25)', '22023'),
      (20, 'la nómina con una clave de más', 'select public.fn_tablero(''{"nomina": {"dias": 30}}'')', '22023')) x(o, que, s, codigo)
    order by o loop
    v_esp := v_esp || r.que || ': ' || r.codigo || ' · ';
    v_obt := v_obt || r.que || ': ' || pg_temp.c16_estado(r.s) || ' · ';
  end loop;
  insert into _pruebas values (33, 'LO MAL PEDIDO: una tarjeta, una clave o un período que no existen, un número fuera de su rango o en letra, un tope de más, un rango al revés o un período con fechas dan 22023 (una fecha mal escrita, 22007) y no pintan nada a medias; sin tarjetas pedidas, contesta vacío',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- SOLO LEE, EN LLANO Y SIN DEJAR NADA (34 a 37)
-- =====================================================================

-- 34. SOLO LEE: el tablero entero y cada tarjeta por su cuenta, como el
--     dueño, no escriben ni una fila en ninguna tabla (los contadores de esta
--     transacción, pg_stat_xact_user_tables, no se mueven) y la huella de lo
--     que leen queda igual.
do $$
declare
  v_obt text; v_esp text; j0 jsonb; v1 bigint; v_t text; h0 text; h1 text;
begin
  if pg_temp.c16_omitir(34, 'solo lee', 'ninguna fila escrita') then return; end if;
  v_esp := 'filas escritas por el tablero y sus tarjetas: 0 | la huella: igual';
  begin
    h0 := pg_temp.c16_huella();
    select coalesce(jsonb_object_agg(s.relname, s.n_tup_ins + s.n_tup_upd + s.n_tup_del), '{}'::jsonb) into j0
      from pg_stat_xact_user_tables s where s.schemaname = 'public';
    perform pg_temp.c16_t();
    perform pg_temp.c16_j('select jsonb_build_array(public.fn_tablero_acciones(), public.fn_tablero_cobros(), public.fn_tablero_bancos(),
                             public.fn_tablero_resultados(), public.fn_tablero_resultados(null, null, ''anio''), public.fn_tablero_gastos(),
                             public.fn_tablero_caja(), public.fn_tablero_facturas(), public.fn_tablero_ventas(), public.fn_tablero_antiguedad(''cobrar''),
                             public.fn_tablero_antiguedad(''pagar''), public.fn_tablero_conexiones(), public.fn_tablero_cobros_en_linea(),
                             public.fn_tablero_use_tax(), public.fn_tablero_prestamos(), public.fn_tablero_obras(), public.fn_tablero_libro(),
                             public.fn_tablero_capas(), public.fn_tablero_nomina(), public.fn_tablero_nomina_estado(), public.fn_tablero_nomina_debe(),
                             to_jsonb(public.fn_tablero_nomina_tapada()), (select to_jsonb(count(*)) from public.fn_tablero_nomina_pagos()))');
    select coalesce(sum(s.n_tup_ins + s.n_tup_upd + s.n_tup_del - coalesce((j0 ->> s.relname)::bigint, 0)), 0),
           string_agg(s.relname, ', ' order by s.relname) filter (where s.n_tup_ins + s.n_tup_upd + s.n_tup_del <> coalesce((j0 ->> s.relname)::bigint, 0))
      into v1, v_t
      from pg_stat_xact_user_tables s where s.schemaname = 'public';
    h1 := pg_temp.c16_huella();
    v_obt := format('filas escritas por el tablero y sus tarjetas: %s%s | la huella: %s', v1, coalesce(' (en ' || v_t || ')', ''),
                    case when h1 = h0 then 'igual' else 'cambió: ' || left(h1, 300) end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'SOLO LEE: el tablero entero y cada tarjeta por su cuenta, como el dueño, no escriben ni una fila (los contadores de la transacción no se mueven) y la huella de lo que leen queda igual',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. EN LLANO: ningún texto para Edgar (texto, detalle, nota, regla,
--     fuente, motivo, etiqueta, titulo, aviso, cuantas, que_es,
--     sin_comparar, alarma_texto, por_que_no, sin_proyeccion, supuestos)
--     dice el nombre de una función, una vista o una columna (fn_…, v_…,
--     como_pagar), «null», «NaN», «undefined», llaves de JSON ni un mensaje
--     de error de la base. Y lo que Edgar no entiende en la portada: un
--     código o el nombre de un secreto en mayúsculas (ITEM_LOGIN_REQUIRED,
--     ANTHROPIC_API_KEY), una fecha AAAA-MM-DD, un plural a medias
--     («cargo(s)»), un texto cortado («…»), «ráfaga» o «partidas». Lo que dijo
--     cada capa tal cual va en «tecnico», «alarma_tecnico» o «error» (para
--     soporte): eso no se mira.
do $$
declare
  v_obt text; v_esp text; t jsonb := pg_temp.c16('t')::jsonb; v_mal text; v_n int;
begin
  v_esp := 'ningún texto con nombres de la base, códigos, fechas AAAA-MM-DD, plurales a medias, textos cortados ni jerga';
  begin
    -- (lo que mira está en pg_temp.c16_llano, arriba: lo usan también las pruebas de la nómina)
    v_mal := pg_temp.c16_llano(t);
    v_obt := coalesce('dicen cosas que Edgar no entiende: ' || v_mal, 'ningún texto con nombres de la base, códigos, fechas AAAA-MM-DD, plurales a medias, textos cortados ni jerga');
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'EN LLANO: ningún texto para Edgar (texto, detalle, nota, regla, fuente, motivo, etiqueta, título, aviso, sin_comparar, alarma_texto, por_que_no, supuestos…) dice el nombre de una función o una vista, «null», llaves de JSON, un código de error, un código o un secreto en mayúsculas (ITEM_LOGIN_REQUIRED, ANTHROPIC_API_KEY), una fecha AAAA-MM-DD, un plural a medias («cargo(s)»), un texto cortado («…»), «ráfaga» ni «partidas»; lo de cada capa tal cual va en «tecnico»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LO QUE ENCONTRARON LOS REVISORES (36 a 43): cada arreglo con su prueba,
-- cada una en su bloque que se deshace (MXT00).
-- =====================================================================

-- 36. EL SALDO DEL BANCO DE OTRO DÍA: una cuenta del banco trae un saldo de
--     AYER (un lote a mano, como un estado de cuenta) y hoy se mueve en el
--     libro: la tarjeta dice de qué día es lo del banco («al …», no «hoy») y
--     la diferencia compara el banco con el libro DE ESE DÍA (cero), no con
--     el de hoy (que ya se movió). El libro de la cuenta es el de hoy.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_cta text; v_ocultas text[] := '{}'; v_ayer numeric; x jsonb;
begin
  if pg_temp.c16_omitir(36, 'el saldo del banco de otro día', 'dice de qué día es y compara el mismo día', true, array['c6']) then return; end if;
  if pg_temp.c16_capa('p1') then
    execute 'select array_remove(array[c.cuenta_puente, c.cuenta_paso], null) from public.stripe_config c where c.id = 1' into v_ocultas;
  end if;
  -- (una cuenta de banco de la página Bancos cuyo último saldo del banco sea de antes de ayer, o que no tenga: el de ayer será el último)
  execute $q$select s.cuenta from public.v_banco_saldos s
              where s.tipo = 'banco' and s.activa and not (s.cuenta = any ($1)) and (s.saldo_banco_al is null or s.saldo_banco_al < $2 - 1)
              order by (s.cuenta = (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'banco')), s.cuenta limit 1$q$
    into v_cta using v_ocultas, v_hoy;
  if v_cta is null then
    insert into _pruebas values (36, 'EL SALDO DEL BANCO DE OTRO DÍA', 'una cuenta del banco sin el saldo de hoy',
      'omitida: todas las cuentas del banco ya traen un saldo de ayer o de hoy: no hay dónde poner uno de otro día sin pisarlo', null);
    return;
  end if;
  v_ayer := pg_temp.c16_libro(array[v_cta], v_hoy - 1);
  v_esp := format('%s: según el banco %s al %s, el libro hoy %s, la diferencia el mismo día 0.00', v_cta, pg_temp.c16_m(v_ayer), v_hoy - 1,
                  pg_temp.c16_m(pg_temp.c16_libro(array[v_cta], v_hoy) + 25.25));
  begin
    -- el saldo del banco de ayer (lo que el libro decía ayer), y hoy entra dinero a esa cuenta (si la base no deja sembrarlo, omitida)
    begin
      perform pg_temp.c16_j(format('select public.fn_banco_importar_filas(%L::jsonb)', jsonb_build_object(
                'origen', 'mano', 'cuenta', v_cta, 'nombre', 'C16 PRUEBA: el saldo de ayer (se deshace)', 'saldo', v_ayer::text,
                'saldo_al', (v_hoy - 1)::text, 'filas', '[]'::jsonb)::text));
      perform pg_temp.c16_postear(v_hoy, 'dinero que entra hoy a la cuenta', jsonb_build_array(jsonb_build_object('cuenta', v_cta, 'monto', '25.25'),
                                                                                               jsonb_build_object('cuenta', '3100', 'monto', '-25.25')));
    exception when others then
      v_obt := 'omitida: esta base no deja sembrar el saldo de ayer y el dinero de hoy (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    select e into x from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_bancos()') -> 'cuentas') e where e ->> 'cuenta' = v_cta;
    v_obt := format('%s: según el banco %s %s, el libro hoy %s, la diferencia el mismo día %s', v_cta, pg_temp.c16_mj(x -> 'saldo_banco'),
                    case when x ->> 'saldo_banco_texto' = 'al ' || to_char(v_hoy - 1, 'FMDD') || '-' || (array['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'])[extract(month from v_hoy - 1)::int] || '-' || extract(year from v_hoy - 1)::int
                         then 'al ' || (v_hoy - 1) else 'sin decir de qué día (' || coalesce(x ->> 'saldo_banco_texto', 'nada') || ')' end,
                    pg_temp.c16_mj(x -> 'saldo_libro'), pg_temp.c16_mj(x -> 'diferencia'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (36, 'EL SALDO DEL BANCO DE OTRO DÍA: con un saldo del banco de ayer y dinero que entra hoy a esa cuenta, la tarjeta dice de qué día es lo del banco («al …»), el libro es el de hoy y la diferencia compara el banco con el libro de ESE día (cero), no con el de hoy',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 37. EL CHEQUE POSFECHADO: un pago a mano fechado dentro de cinco días
--     (la renta, con un cheque posfechado del banco): el saldo de hoy en el
--     libro no lo cuenta, ni en la tarjeta de bancos ni en la caja (las dos
--     dicen lo mismo de esa cuenta), la de bancos lo dice aparte, y la
--     proyección lo resta en su mes.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_cta text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'banco');
  b0 jsonb; b1 jsonb; c0 jsonb; c1 jsonb; v_mes text := to_char(pg_temp.c16_hoy() + 5, 'YYYY-MM'); v_proy boolean;
begin
  if pg_temp.c16_omitir(37, 'el cheque posfechado', 'no va en el saldo de hoy; la proyección lo resta en su mes', true, array['c6']) then return; end if;
  if not exists (select 1 from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and v_hoy + 5 between p.desde and p.hasta) then
    insert into _pruebas values (37, 'EL CHEQUE POSFECHADO', 'el mes de dentro de cinco días, abierto',
      'omitida: el mes de dentro de cinco días no está abierto: no hay dónde fechar el cheque de prueba', null);
    return;
  end if;
  v_proy := exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null and not exists (select 1 from asientos r where r.reversa_a = a.id));
  v_esp := format('bancos, %s: el libro de hoy igual, lo posfechado -500.00 | la caja de hoy: igual | la proyección de %s: %s',
                  v_cta, v_mes, case when v_proy then '500.00 menos' else 'sin proyección (sin la apertura en el libro)' end);
  begin
    b0 := pg_temp.c16_j('select public.fn_tablero_bancos()');
    c0 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    begin
      perform pg_temp.c16_postear(v_hoy + 5, 'la renta con un cheque posfechado', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '500.00'),
                                                                                                      jsonb_build_object('cuenta', v_cta, 'monto', '-500.00')));
    exception when others then
      v_obt := 'omitida: esta base no deja fechar el cheque de prueba dentro de cinco días (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    b1 := pg_temp.c16_j('select public.fn_tablero_bancos()');
    c1 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    v_obt := format('bancos, %s: el libro de hoy %s, lo posfechado %s | la caja de hoy: %s | la proyección de %s: %s', v_cta,
                    case when (select x -> 'saldo_libro' from jsonb_array_elements(b1 -> 'cuentas') x where x ->> 'cuenta' = v_cta)
                              = (select x -> 'saldo_libro' from jsonb_array_elements(b0 -> 'cuentas') x where x ->> 'cuenta' = v_cta) then 'igual'
                         else 'cambió' end,
                    coalesce((select pg_temp.c16_m((x -> 'posfechado' ->> 'monto')::numeric - coalesce((y -> 'posfechado' ->> 'monto')::numeric, 0))
                                from jsonb_array_elements(b1 -> 'cuentas') x, jsonb_array_elements(b0 -> 'cuentas') y
                               where x ->> 'cuenta' = v_cta and y ->> 'cuenta' = v_cta), 'no lo dice'),
                    case when c1 -> 'hoy' -> 'saldo' = c0 -> 'hoy' -> 'saldo' then 'igual' else 'cambió' end,
                    v_mes,
                    case when c1 -> 'proyeccion' is null or c1 -> 'proyeccion' = 'null'::jsonb then 'sin proyección (sin la apertura en el libro)'
                         else coalesce((select pg_temp.c16_m((y ->> 'saldo')::numeric - (x ->> 'saldo')::numeric) || ' menos'
                                          from jsonb_array_elements(c1 -> 'proyeccion' -> 'meses') x, jsonb_array_elements(c0 -> 'proyeccion' -> 'meses') y
                                         where x ->> 'mes' = v_mes and y ->> 'mes' = v_mes), 'no está') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (37, 'EL CHEQUE POSFECHADO: un pago fechado dentro de cinco días no va en el saldo de hoy, ni en la tarjeta de bancos ni en la caja (dicen lo mismo de esa cuenta); la de bancos lo dice aparte y la proyección lo resta en su mes',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 38. «LLEGÓ SU TICKET»: un cargo de una tarjeta que espera en la Bandeja
--     se clasifica a material, y después llega su ticket (el recibo del
--     mismo monto, la misma tarjeta y el mismo día): el gasto queda DOS
--     VECES en el libro y la Bandeja lo enseña. El tablero lo cuenta como
--     la Bandeja (bancos, por cuenta; las acciones, en total) y la tarjeta
--     de gastos dice que lo gastado va DE MÁS, no de menos.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_cta text; v_u4 text; v_mov uuid; v_mot text; v_bj int; v_bjc int; t1 jsonb;
begin
  if pg_temp.c16_omitir(38, '«llegó su ticket»', 'el gasto dos veces: la Bandeja, los bancos, las acciones y los gastos lo dicen', true, array['c6']) then return; end if;
  select t.cuenta, t.ultimos4 into v_cta, v_u4
    from tarjetas t join v_banco_saldos s on s.cuenta = t.cuenta
   where t.activa and s.activa order by t.cuenta limit 1;
  if v_cta is null then
    insert into _pruebas values (38, '«LLEGÓ SU TICKET»', 'una tarjeta activa', 'omitida: no hay ninguna tarjeta activa en la página Bancos: no hay dónde poner el cargo de prueba', null);
    return;
  end if;
  v_esp := 'la Bandeja: el cargo con su ticket, dos veces en el libro | bancos (la tarjeta) y acciones: como la Bandeja | gastos: 1 doble de 77.31, lo dice';
  begin
   begin
    perform pg_temp.c16_sembrar();
    perform fn_mapeo_confirmar('categoria');
    perform fn_mapeo_confirmar('metodo_pago');
    -- el cargo de la tarjeta (un lote a mano, como lo trae el banco), y Edgar lo clasifica a material
    perform pg_temp.c16_j(format('select public.fn_banco_importar_filas(%L::jsonb)', jsonb_build_object(
              'origen', 'mano', 'cuenta', v_cta, 'nombre', 'C16 PRUEBA: un cargo (se deshace)',
              'filas', jsonb_build_array(jsonb_build_object('id', 'c16-prueba-cargo-38', 'fecha', (v_hoy - 2)::text, 'monto', '-77.31',
                                                            'descripcion', 'C16 PRUEBA FERRETERIA')))::text));
    select m.id into v_mov from movimientos_banco m where m.descripcion = 'C16 PRUEBA FERRETERIA' and m.cuenta = v_cta;
    perform pg_temp.c16_j(format('select public.fn_banco_clasificar(%L::uuid, %L::jsonb, %L)', v_mov,
                                 jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', 'c16-prueba-a'))::text, 'C16 PRUEBA: material'));
    -- y después llega su ticket (el recibo, por el puente de c3)
    perform pg_temp.c16_ser('editor');
    insert into recibos (proyecto_id, ruta, total, subtotal, tax, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4, num_recibo)
    values ('c16-prueba-a', 'recibos/c16/prueba-38.jpg', 77.31, 72.25, 5.06, 'C16 PRUEBA Ferretera', 'leido', pg_temp.c16('dueno')::uuid, now(),
            v_hoy - 2, 'material', 'credito', v_u4, 'C16-PRUEBA-T38');
    perform pg_temp.c16_j(format('select public.fn_banco_casar_todo(%L, null)', v_cta));
   exception when others then
    perform pg_temp.c16_ser('editor');
    v_obt := 'omitida: esta base no deja sembrar el cargo, su clasificación y su ticket (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
    raise exception using errcode = 'MXT00';
   end;
    select m.propuesta ->> 'motivo' into v_mot from movimientos_banco m where m.id = v_mov;
    if v_mot is distinct from 'llego_su_ticket' then
      v_obt := 'omitida: en esta base el ticket de prueba no quedó como «llegó su ticket» (' || coalesce(v_mot, 'sin motivo')
               || '): el puente de recibos no lo contabilizó o el banco no lo cruzó; no hay nada doble que mirar';
    else
      select count(*), count(*) filter (where b.cuenta = v_cta) into v_bj, v_bjc from v_banco_bandeja b;
      t1 := pg_temp.c16_t('{"tarjetas": ["acciones", "bancos", "gastos"]}');
      v_obt := format('la Bandeja: el cargo con su ticket, %s | bancos (la tarjeta) y acciones: %s | gastos: %s',
                      case when exists (select 1 from v_banco_bandeja b where b.movimiento_id = v_mov and b.motivo = 'llego_su_ticket') then 'dos veces en el libro' else 'no sale' end,
                      case when (select (x ->> 'por_revisar')::int from jsonb_array_elements(t1 -> 'bancos' -> 'cuentas') x where x ->> 'cuenta' = v_cta) = v_bjc
                                and (select (x ->> 'n')::int from jsonb_array_elements(t1 -> 'acciones' -> 'lista') x where x ->> 'clave' = 'bandeja') = v_bj
                                and (t1 -> 'bancos' -> 'totales' -> 'por_revisar' ->> 'dobles')::int >= 1
                           then 'como la Bandeja'
                           else format('otra cosa (la tarjeta %s de %s, las acciones %s de %s)',
                                       (select x ->> 'por_revisar' from jsonb_array_elements(t1 -> 'bancos' -> 'cuentas') x where x ->> 'cuenta' = v_cta), v_bjc,
                                       (select x ->> 'n' from jsonb_array_elements(t1 -> 'acciones' -> 'lista') x where x ->> 'clave' = 'bandeja'), v_bj) end,
                      case when t1 -> 'gastos' -> 'dobles' is null or t1 -> 'gastos' -> 'dobles' = 'null'::jsonb then 'no lo cuenta'
                           else format('%s doble de %s, %s', t1 -> 'gastos' -> 'dobles' ->> 'n', pg_temp.c16_mj(t1 -> 'gastos' -> 'dobles' -> 'monto'),
                                       case when t1 -> 'gastos' ->> 'nota' like '%DOS VECES%' then 'lo dice' else 'no lo dice' end) end);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  if v_obt like 'omitida:%' then
    insert into _pruebas values (38, '«LLEGÓ SU TICKET»', v_esp, v_obt, null);
  else
    insert into _pruebas values (38, '«LLEGÓ SU TICKET»: un cargo de tarjeta clasificado cuyo ticket llega después queda dos veces en el libro y en la Bandeja; el tablero lo cuenta como la Bandeja (bancos y acciones) y la tarjeta de gastos dice que lo gastado va de más',
      v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 39. STRIPE, EL REEMBOLSO DE ALGO YA DEPOSITADO: un pago de Stripe ya
--     depositado en el banco se reembolsa en parte (el 20 %, con la foto que
--     Stripe mandaría). p1 devuelve su cobro ENTERO y registra uno nuevo por
--     lo que queda: el embudo sigue contando ese dinero como DEPOSITADO (ya
--     llegó al banco; el reembolso lo descuenta Stripe del siguiente), no
--     «en Stripe»; lo devuelto es el reembolso, no el cobro entero; y los
--     cobros en línea dicen lo que Stripe descontará.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); s0 record; v_viejo numeric := 0; v_nuevo numeric; v_re numeric;
  e0 jsonb; e1 jsonb; l0 jsonb; l1 jsonb;
begin
  if pg_temp.c16_omitir(39, 'el reembolso de algo ya depositado', 'sigue depositado; lo devuelto es el reembolso', false, array['p1', 'c6']) then return; end if;
  select s.id, s.pi, s.monto, s.en_libro, s.cobro_id, s.foto into s0
    from stripe_pagos s join v_stripe_pagos v on v.id = s.id
   where v.estado_pantalla = 'depositado' and s.foto is not null and s.cobro_id is not null and s.en_libro > 0
   order by s.creado_el desc limit 1;
  if s0.id is null then
    insert into _pruebas values (39, 'STRIPE, EL REEMBOLSO DE ALGO YA DEPOSITADO', 'un pago de Stripe ya depositado',
      'omitida: no hay ningún pago de Stripe ya depositado en el banco: no hay qué reembolsar', null);
    return;
  end if;
  v_re := round(s0.monto * 0.20, 2);
  begin
    e0 := pg_temp.c16_j('select public.fn_tablero_cobros()');
    l0 := pg_temp.c16_j('select public.fn_tablero_cobros_en_linea()');
    -- (el cobro de antes, si cae en los 30 días del embudo: sale de él al devolverse entero)
    select (c.monto - coalesce((select sum(d.monto) from cobros_devoluciones d where d.cobro_id = c.id and d.fecha <= v_hoy), 0)) into v_viejo
      from cobros c where c.id = s0.cobro_id and c.fecha between v_hoy - 29 and v_hoy;
    v_viejo := coalesce(v_viejo, 0);
    perform pg_temp.c16_ser('editor');
    begin
      perform fn_stripe_pago_sincronizar(s0.foto || jsonb_build_object('visto_el', clock_timestamp(), 'reembolsos', jsonb_build_array(
                jsonb_build_object('id', 're_C16PRUEBA', 'monto', round(v_re * 100)::bigint, 'estado', 'succeeded',
                                   'creado', extract(epoch from now())::bigint, 'bt', 'txn_re_C16PRUEBA', 'bt_fallo', null, 'motivo_fallo', null))),
                'evt_C16PRUEBA_REEMBOLSO');
    exception when others then
      v_obt := 'omitida: p1 no aceptó el reembolso de prueba (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    select c.monto into v_nuevo from stripe_pagos s join cobros c on c.id = s.cobro_id where s.id = s0.id;
    e1 := pg_temp.c16_j('select public.fn_tablero_cobros()');
    l1 := pg_temp.c16_j('select public.fn_tablero_cobros_en_linea()');
    v_esp := format('el cobro nuevo de %s: depositado %s, en Stripe sin depositar %s | devuelto %s (de Stripe %s) | cobros en línea: Stripe descontará %s',
                    pg_temp.c16_m(s0.monto - v_re), pg_temp.c16_m((e0 -> 'depositado' ->> 'monto')::numeric - v_viejo + (s0.monto - v_re)),
                    pg_temp.c16_mj(e0 -> 'sin_depositar' -> 'en_stripe' -> 'monto'),
                    pg_temp.c16_m((e0 -> 'cobrado' -> 'devuelto' ->> 'monto')::numeric + v_re), pg_temp.c16_m(v_re),
                    pg_temp.c16_m(coalesce((l0 -> 'por_descontar' ->> 'monto')::numeric, 0) + v_re));
    v_obt := format('el cobro nuevo de %s: depositado %s, en Stripe sin depositar %s | devuelto %s (de Stripe %s) | cobros en línea: Stripe descontará %s',
                    pg_temp.c16_m(v_nuevo), pg_temp.c16_mj(e1 -> 'depositado' -> 'monto'), pg_temp.c16_mj(e1 -> 'sin_depositar' -> 'en_stripe' -> 'monto'),
                    pg_temp.c16_mj(e1 -> 'cobrado' -> 'devuelto' -> 'monto'), coalesce(pg_temp.c16_mj(e1 -> 'cobrado' -> 'devuelto' -> 'stripe' -> 'monto'), '—'),
                    pg_temp.c16_mj(coalesce(nullif(l1 -> 'por_descontar', 'null'::jsonb) -> 'monto', '0'::jsonb)));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (39, 'STRIPE, EL REEMBOLSO DE ALGO YA DEPOSITADO: tras un reembolso del 20 % de un pago ya depositado, el cobro nuevo sigue DEPOSITADO (no «en Stripe»), lo devuelto es el reembolso (no el cobro entero) y los cobros en línea dicen lo que Stripe descontará del próximo depósito',
    coalesce(v_esp, 'el cobro nuevo, depositado; lo devuelto, el reembolso'), v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 40. STRIPE, SIN LA VENTANA DE 120 DÍAS: si un cobro de Stripe es viejo, su
--     pago sale de v_stripe_pagos (p1 solo enseña 120 días) pero sigue
--     depositado. El embudo ya no lee esa vista: escondida (dentro de un
--     bloque que se deshace), el embudo de un año dice lo mismo.
do $$
declare
  v_obt text; v_esp text; e0 jsonb; e1 jsonb;
begin
  if pg_temp.c16_omitir(40, 'Stripe sin la ventana de 120 días', 'el embudo no depende de v_stripe_pagos', false, array['p1', 'c6']) then return; end if;
  v_esp := 'sin v_stripe_pagos, el embudo de un año: depositado igual, sin depositar igual (en Stripe, en camino y sin casar)';
  begin
    e0 := pg_temp.c16_j('select public.fn_tablero_cobros(366)');
    execute 'alter view public.v_stripe_pagos rename to v_stripe_pagos_c16_fuera';
    e1 := pg_temp.c16_j('select public.fn_tablero_cobros(366)');
    v_obt := format('sin v_stripe_pagos, el embudo de un año: depositado %s, sin depositar %s',
                    case when e1 -> 'depositado' = e0 -> 'depositado' then 'igual' else format('otro (%s contra %s)', e1 -> 'depositado' ->> 'monto', e0 -> 'depositado' ->> 'monto') end,
                    case when (e1 -> 'sin_depositar') - 'ir' = (e0 -> 'sin_depositar') - 'ir' then 'igual (en Stripe, en camino y sin casar)'
                         else format('otro (en Stripe %s contra %s)', e1 -> 'sin_depositar' -> 'en_stripe' ->> 'monto', e0 -> 'sin_depositar' -> 'en_stripe' ->> 'monto') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (40, 'STRIPE, SIN LA VENTANA DE 120 DÍAS: lo de Stripe del embudo se lee de las tablas de p1, no de v_stripe_pagos (que solo enseña 120 días): sin esa vista, el embudo de un año dice lo mismo, y un cobro viejo ya depositado sigue depositado',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. LA CAJA SIN LA APERTURA EN EL LIBRO (así está producción hasta que se
--     pegue la apertura): si la apertura está, se reversa dentro del bloque;
--     y con una cuenta de la caja en rojo, la caja dice que sin la apertura
--     no es lo que hay en el banco, NO da la alarma de sobregiro (sería
--     falsa), no hace proyección (no hay de dónde partir), su línea no
--     empieza en una apertura que no está, y lo de antes del libro lo dice
--     con las palabras del libro.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_ap uuid; v_cta text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'banco');
  v_s numeric; c jsonb; l jsonb;
begin
  if pg_temp.c16_omitir(41, 'la caja sin la apertura en el libro', 'lo dice, sin alarma de sobregiro ni proyección', true) then return; end if;
  v_esp := 'el libro: sin la apertura | la caja: lo dice, sobregiro sin alarma, sin proyección (por la apertura), la línea sin apertura, lo de antes del libro con las palabras del libro';
  begin
    select a.id into v_ap from asientos a
     where a.tipo = 'apertura' and a.reversa_a is null and not exists (select 1 from asientos r where r.reversa_a = a.id)
     order by a.cadena_pos desc limit 1;
    begin
      if v_ap is not null then
        perform pg_temp.c16_ser('editor');
        perform fn_reversar(v_ap, 'C16 PRUEBA: la caja sin la apertura (se deshace)');
      end if;
      -- (una cuenta de la caja en rojo: si ninguna lo está, una renta que la deja así)
      if not exists (select 1 from v_estados_mapeo m where m.efectivo and pg_temp.c16_libro(array[m.cuenta], v_hoy) < 0) then
        v_s := pg_temp.c16_libro(array[v_cta], v_hoy);
        perform pg_temp.c16_postear(v_hoy, 'una renta que deja el banco en rojo', jsonb_build_array(
                  jsonb_build_object('cuenta', '6100', 'monto', (greatest(v_s, 0) + 1850.00)::text),
                  jsonb_build_object('cuenta', v_cta, 'monto', (-(greatest(v_s, 0) + 1850.00))::text)));
      end if;
    exception when others then
      perform pg_temp.c16_ser('editor');
      v_obt := 'omitida: esta base no deja reversar la apertura o sembrar la renta de prueba (' || sqlstate || ': ' || left(sqlerrm, 200)
               || '); con la apertura en un período cerrado, el caso sin apertura ya no se puede mirar';
      raise exception using errcode = 'MXT00';
    end;
    l := pg_temp.c16_j('select public.fn_tablero_libro()');
    c := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    v_obt := format('el libro: %s | la caja: %s, sobregiro %s, %s, %s, %s',
                    case when (l ->> 'apertura_en_el_libro')::boolean then 'dice que la apertura está' else 'sin la apertura' end,
                    case when (c ->> 'sin_apertura')::boolean and c -> 'hoy' ->> 'texto' ilike '%no es lo que hay en el banco%' then 'lo dice' else 'no lo dice' end,
                    case when (c -> 'hoy' ->> 'sobregiro')::numeric > 0 and (c -> 'hoy' ->> 'alarma')::boolean is false then 'sin alarma'
                         when (c -> 'hoy' ->> 'sobregiro')::numeric > 0 then 'con alarma (' || coalesce(c -> 'hoy' ->> 'alarma', 'sin decir') || ')'
                         else 'ninguno' end,
                    case when (c -> 'proyeccion' is null or c -> 'proyeccion' = 'null'::jsonb) and c ->> 'sin_proyeccion' ilike '%apertura%' then 'sin proyección (por la apertura)'
                         else 'con proyección' end,
                    case when c -> 'serie' -> 0 ->> 'tipo' = 'apertura' then 'la línea empieza en la apertura' else 'la línea sin apertura' end,
                    case when c -> 'antes_del_libro' is null or c -> 'antes_del_libro' = 'null'::jsonb then 'lo de antes del libro con las palabras del libro'
                         when c -> 'antes_del_libro' ->> 'texto' like '%empieza con la apertura%' then 'lo de antes del libro dice que empieza con la apertura'
                         else 'lo de antes del libro con las palabras del libro' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (41, 'LA CAJA SIN LA APERTURA EN EL LIBRO: sin el asiento de la apertura (reversado dentro del bloque) y con una cuenta en rojo, la caja dice que no es lo que hay en el banco, no da la alarma de sobregiro (sería falsa), no proyecta (no hay de dónde partir), su línea no empieza en una apertura que no está y lo de antes del libro lo dice como el libro',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 42. EL WIP DEL MES QUE NO TIENE SU AJUSTE: el reverso automático del
--     ajuste del WIP del mes pasado cae el día 1 de este mes; mientras este
--     mes no tenga su propio ajuste, NO cuenta en sus resultados (va aparte,
--     con su texto; con él, lo de Estados), y las ventas son lo vendido, sin
--     el WIP de ningún mes (el mejor mes, por lo vendido). Sin WIP en la
--     base, nada se aparta.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_m0 date := date_trunc('month', pg_temp.c16_hoy())::date; r jsonb; v jsonb;
  v_wi numeric; v_vm numeric; v_mej text;
begin
  if pg_temp.c16_omitir(42, 'el WIP del mes que no tiene su ajuste', 'el reverso va aparte; las ventas, sin el WIP') then return; end if;
  begin
    r := pg_temp.c16_tc('resultados');
    v := pg_temp.c16_tc('ventas');
    select -sum(li.monto) filter (where m.seccion = 'ingresos') into v_wi
      from asiento_lineas li join pg_temp.c16_wip(true) w on w.asiento_id = li.asiento_id
      join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados'
     where w.fecha between v_m0 and v_hoy;
    -- (lo vendido este mes, sin ningún asiento del WIP, y el mejor mes del año así)
    with l as (
      select date_trunc('month', a.fecha_contable)::date as mes, -li.monto as monto
        from asiento_lineas li join asientos a on a.id = li.asiento_id
        join v_estados_mapeo m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion = 'ingresos'
       where a.fecha_contable between greatest(date_trunc('year', v_hoy)::date, date_trunc('month', pg_temp.c16('libro_desde')::date)::date) and v_hoy
         and pg_temp.c16_ejercicio(a.id) = extract(year from a.fecha_contable)::int
         and a.id not in (select w.asiento_id from pg_temp.c16_wip(false) w)
    ), x as (select l.mes, sum(l.monto) as monto from l group by l.mes)
    select (select x.monto from x where x.mes = v_m0), (select to_char(x.mes, 'YYYY-MM') from x where x.monto > 0 order by x.monto desc, x.mes limit 1)
      into v_vm, v_mej;
    v_esp := format('este mes, el WIP aparte: %s | las ventas de este mes, sin el WIP: %s | el mejor mes, por lo vendido: %s',
                    case when coalesce(v_wi, 0) = 0 then 'nada' else pg_temp.c16_m(v_wi) || ' de ingreso, con su texto' end,
                    pg_temp.c16_m(coalesce(v_vm, 0)), coalesce(v_mej, 'ninguno'));
    v_obt := format('este mes, el WIP aparte: %s | las ventas de este mes, sin el WIP: %s | el mejor mes, por lo vendido: %s',
                    case when r -> 'wip_aparte' is null or r -> 'wip_aparte' = 'null'::jsonb then 'nada'
                         else pg_temp.c16_mj(r -> 'wip_aparte' -> 'ingresos') || ' de ingreso, '
                              || case when r -> 'wip_aparte' ->> 'texto' like '%WIP%' then 'con su texto' else 'sin texto' end end,
                    coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(v -> 'meses') x where x ->> 'mes' = to_char(v_m0, 'YYYY-MM')), '0.00'),
                    coalesce(v -> 'mejor_mes' ->> 'mes', 'ninguno'));
    if (r ->> 'periodo') is distinct from 'mes' then v_obt := v_obt || ' (la tarjeta de resultados no es la de este mes)'; end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'EL WIP DEL MES QUE NO TIENE SU AJUSTE: el reverso automático del día 1 no cuenta en los resultados de este mes mientras no tenga su propio ajuste (va aparte, con su texto) y las ventas son lo vendido, sin el WIP de ningún mes (el mejor mes, por lo vendido); sin WIP, nada se aparta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. LOS ENLACES: cada enlace a la Bandeja dice su cuenta, o que es la
--     Bandeja entera (la cuenta en nulo: así no se queda el filtro de una
--     cuenta de antes), y el del use tax lleva a la pestaña DR-15 del cierre.
do $$
declare
  v_obt text; v_esp text; t jsonb := pg_temp.c16('t')::jsonb; v_n int; v_mal text;
begin
  v_esp := 'los enlaces a la Bandeja: todos dicen su cuenta o la Bandeja entera | el del use tax: Cierre del mes → DR-15';
  begin
    select count(*), string_agg(distinct x::text, ' · ') filter (where not (x ? 'cuenta')) into v_n, v_mal
      from jsonb_path_query(t, 'strict $.**') x
     where jsonb_typeof(x) = 'object' and x ->> 'pagina' = 'bandeja';
    v_obt := format('los enlaces a la Bandeja: %s | el del use tax: %s',
                    case when v_n = 0 then 'ninguno' when v_mal is null then 'todos dicen su cuenta o la Bandeja entera' else 'sin cuenta: ' || left(v_mal, 300) end,
                    case when t -> 'use_tax' ->> 'ok' is distinct from 'true' then 'Cierre del mes → DR-15'   -- (sin c9 no hay tarjeta)
                         when t -> 'use_tax' -> 'ir' ->> 'pagina' = 'cierre' and t -> 'use_tax' -> 'ir' ->> 'sub' = 'dr15' then 'Cierre del mes → DR-15'
                         else 'otro: ' || coalesce(t -> 'use_tax' ->> 'ir', '—') end);
    if v_n = 0 and pg_temp.c16_capa('c6') then v_obt := v_obt || ' (con el banco en la base, ningún enlace a la Bandeja)'; end if;
    if not pg_temp.c16_capa('c6') then v_obt := replace(v_obt, 'ninguno', 'todos dicen su cuenta o la Bandeja entera'); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'LOS ENLACES: cada enlace a la Bandeja dice su cuenta o que es la Bandeja entera (la cuenta en nulo, para que no se quede el filtro de una cuenta de antes) y el del use tax lleva a la pestaña DR-15 del cierre',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 46. LA CAJA, EL MES EN CURSO HASTA HOY (la revisión final, 13-nov): lo que
--     tiene fecha de DESPUÉS de hoy en este mes (un cheque posfechado) no va
--     en lo que entró y salió del mes «hasta hoy» ni en su «al terminar», que
--     es la caja de hoy; la tarjeta lo dice aparte (despues_de_hoy). Antes,
--     el mes en curso era el entero de c4: con el cheque posfechado de la
--     semilla, «nov 2026 (hasta hoy)» terminaba en 640.00 menos que la caja
--     de hoy. Un mes ya terminado sigue siendo el de Estados (la 14).
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_fin date := (date_trunc('month', pg_temp.c16_hoy()) + interval '1 month')::date - 1;
  v_f date; v_cta text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'banco'); c0 jsonb; c1 jsonb; m0 jsonb; m1 jsonb;
begin
  if pg_temp.c16_omitir(46, 'la caja, el mes en curso hasta hoy', 'lo de después de hoy no va en el mes «hasta hoy»; lo dice aparte', true) then return; end if;
  v_f := least(v_hoy + 5, v_fin);
  if v_f <= v_hoy then
    insert into _pruebas values (46, 'LA CAJA, EL MES EN CURSO HASTA HOY', 'un día de este mes después de hoy',
      'omitida: hoy es el último día del mes: no hay un día de este mes después de hoy donde fechar el cheque de prueba', null);
    return;
  end if;
  v_esp := 'el mes en curso, hasta hoy: entradas igual, salidas igual, al terminar igual = la caja de hoy, entradas − salidas = su neto | '
           || 'lo de después de hoy: 1 asiento más, sale 500.00 más, lo dice';
  begin
    c0 := pg_temp.c16_j('select public.fn_tablero_caja(12, 0)');
    begin
      perform pg_temp.c16_postear(v_f, 'un cheque posfechado de este mes', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '500.00'),
                                                                                          jsonb_build_object('cuenta', v_cta, 'monto', '-500.00')));
    exception when others then
      v_obt := 'omitida: esta base no deja fechar el cheque de prueba después de hoy en este mes (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    c1 := pg_temp.c16_j('select public.fn_tablero_caja(12, 0)');
    select x into m0 from jsonb_array_elements(c0 -> 'meses') x where (x ->> 'en_curso')::boolean;
    select x into m1 from jsonb_array_elements(c1 -> 'meses') x where (x ->> 'en_curso')::boolean;
    v_obt := format('el mes en curso, hasta hoy: entradas %s, salidas %s, al terminar %s, entradas − salidas %s | lo de después de hoy: %s',
      case when m1 -> 'entradas' = m0 -> 'entradas' then 'igual' else format('otra (%s → %s)', m0 ->> 'entradas', m1 ->> 'entradas') end,
      case when m1 -> 'salidas' = m0 -> 'salidas' then 'igual' else format('otra (%s → %s)', m0 ->> 'salidas', m1 ->> 'salidas') end,
      case when m1 -> 'final' = m0 -> 'final' and (m1 ->> 'final')::numeric = (c1 -> 'hoy' ->> 'saldo')::numeric then 'igual = la caja de hoy'
           when m1 -> 'final' = m0 -> 'final' then format('igual, pero no es la caja de hoy (%s; hoy %s)', m1 ->> 'final', c1 -> 'hoy' ->> 'saldo')
           else format('otro (%s → %s; la caja de hoy %s)', m0 ->> 'final', m1 ->> 'final', c1 -> 'hoy' ->> 'saldo') end,
      case when (m1 ->> 'entradas')::numeric - (m1 ->> 'salidas')::numeric = (m1 ->> 'neto')::numeric then '= su neto' else 'no da su neto' end,
      case when m1 -> 'despues_de_hoy' is null or m1 -> 'despues_de_hoy' = 'null'::jsonb then 'no lo dice'
           else format('%s asiento%s más, sale %s más, %s',
                       coalesce((m1 -> 'despues_de_hoy' ->> 'asientos')::int, 0) - coalesce((nullif(m0 -> 'despues_de_hoy', 'null'::jsonb) ->> 'asientos')::int, 0),
                       case when coalesce((m1 -> 'despues_de_hoy' ->> 'asientos')::int, 0) - coalesce((nullif(m0 -> 'despues_de_hoy', 'null'::jsonb) ->> 'asientos')::int, 0) = 1
                            then '' else 's' end,
                       pg_temp.c16_m(coalesce((m1 -> 'despues_de_hoy' ->> 'salidas')::numeric, 0) - coalesce((nullif(m0 -> 'despues_de_hoy', 'null'::jsonb) ->> 'salidas')::numeric, 0)),
                       case when m1 -> 'despues_de_hoy' ->> 'texto' like '%después de hoy%' then 'lo dice' else 'sin texto' end) end);
    if (c1 ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c1 ->> 'motivo', '?'); end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (46, 'LA CAJA, EL MES EN CURSO HASTA HOY: un cheque fechado más adelante en este mes no cambia lo que entró y salió del mes «hasta hoy» ni su «al terminar», que es la caja de hoy (c4 lo pone en el mes entero); la tarjeta lo dice aparte',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 47. LO QUE DICE EL BANCO, SUMADO, SOLO EL MISMO DÍA (la revisión final):
--     dos cuentas del mismo tipo con el saldo del banco de días distintos (una
--     de hoy y otra del 31-oct, como la Amex por archivo de la semilla) no se
--     suman en «según el banco» —sería una cifra que el banco nunca dijo—: el
--     total va nulo y dice por qué; del mismo día, sí, con su día. Con la
--     tarjeta de bancos armada con dos cuentas de prueba (fn_tablero_bancos_de
--     arma la tarjeta con lo que le dan): vale en cualquier base.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); t jsonb; u jsonb;
  f jsonb := jsonb_build_object('tipo', 'banco', 'activa', true, 'saldo_libro', 100, 'saldo_libro_despues', 0, 'por_revisar', 0, 'por_revisar_monto', 0);
begin
  v_esp := format('de días distintos: sin total del banco, lo dice; 2 de 2 con saldo | del mismo día: 300.00, del %s', v_hoy - 3);
  begin
    t := pg_temp.c16_j(format('select public.fn_tablero_bancos_de(%L::jsonb)', jsonb_build_array(
           f || jsonb_build_object('cuenta', 'C16-PRUEBA-A', 'nombre', 'C16 PRUEBA A', 'saldo_banco', 100, 'saldo_banco_al', v_hoy, 'saldo_libro_al', 100),
           f || jsonb_build_object('cuenta', 'C16-PRUEBA-B', 'nombre', 'C16 PRUEBA B', 'saldo_banco', 200, 'saldo_banco_al', v_hoy - 3, 'saldo_libro_al', 200))::text));
    u := pg_temp.c16_j(format('select public.fn_tablero_bancos_de(%L::jsonb)', jsonb_build_array(
           f || jsonb_build_object('cuenta', 'C16-PRUEBA-A', 'nombre', 'C16 PRUEBA A', 'saldo_banco', 100, 'saldo_banco_al', v_hoy - 3, 'saldo_libro_al', 100),
           f || jsonb_build_object('cuenta', 'C16-PRUEBA-B', 'nombre', 'C16 PRUEBA B', 'saldo_banco', 200, 'saldo_banco_al', v_hoy - 3, 'saldo_libro_al', 200))::text));
    v_obt := format('de días distintos: %s; %s de %s con saldo | del mismo día: %s',
      case when t -> 'totales' -> 'bancos' -> 'banco' is null or t -> 'totales' -> 'bancos' -> 'banco' = 'null'::jsonb
           then case when coalesce(t -> 'totales' -> 'bancos' ->> 'banco_texto', '') like '%días distintos%' then 'sin total del banco, lo dice'
                     else 'sin total del banco, sin decir por qué' end
           else 'suma ' || pg_temp.c16_mj(t -> 'totales' -> 'bancos' -> 'banco') end,
      t -> 'totales' -> 'bancos' ->> 'con_banco', t -> 'totales' -> 'bancos' ->> 'n',
      coalesce(pg_temp.c16_mj(u -> 'totales' -> 'bancos' -> 'banco'), '—') || ', del ' || coalesce(u -> 'totales' -> 'bancos' ->> 'banco_al', 'día sin decir'));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (47, 'LO QUE DICE EL BANCO, SUMADO, SOLO EL MISMO DÍA: dos cuentas con el saldo del banco de días distintos no se suman en el total de la tarjeta de bancos (sería una cifra que el banco nunca dijo): va nulo y dice por qué; del mismo día, sí, con su día',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 48. LO DEVUELTO DE UN COBRO DE ANTES (la revisión final): un cheque de
--     hace 40 días (fuera de los 30 del embudo) que rebota hace 5 (dentro): lo
--     cobrado en los 30 días no cambia (ese cobro no está en ellos) y lo
--     devuelto «ya restado» tampoco (no se restó de nada); el rebote se dice
--     aparte, como lo devuelto de un cobro de antes. Antes, se sumaba a lo
--     devuelto «ya restado».
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_f date := pg_temp.c16_hoy() - 40; v_fac bigint; v_cob uuid; e0 jsonb; e1 jsonb;
begin
  if pg_temp.c16_omitir(48, 'lo devuelto de un cobro de antes', 'no se resta de lo cobrado; se dice aparte', true) then return; end if;
  if v_f < pg_temp.c16('libro_desde')::date
     or not exists (select 1 from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and v_f between p.desde and p.hasta) then
    insert into _pruebas values (48, 'LO DEVUELTO DE UN COBRO DE ANTES', 'un mes abierto hace 40 días, en el libro',
      'omitida: hace 40 días es de antes del libro o su mes está cerrado: no hay dónde fechar el cheque de prueba', null);
    return;
  end if;
  v_esp := 'lo cobrado en 30 días: igual | lo devuelto, ya restado: igual | lo devuelto de cobros de antes: 1234.56 más (1 más), lo dice aparte';
  begin
    e0 := pg_temp.c16_j('select public.fn_tablero_cobros(30)');
    begin
      perform pg_temp.c16_sembrar();
      v_fac := pg_temp.c16_factura(48, 'c16-prueba-a', 1234.56, v_f);
      v_cob := pg_temp.c16_cobro(v_f, 1234.56, v_fac);
      perform pg_temp.c16_ser('editor');
      perform fn_cobro_devolver(v_cob, v_hoy - 5, 'C16 PRUEBA: el cheque rebotó (se deshace)', null);
    exception when others then
      perform pg_temp.c16_ser('editor');
      v_obt := 'omitida: esta base no deja sembrar la factura, su cobro de hace 40 días y su devolución (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    e1 := pg_temp.c16_j('select public.fn_tablero_cobros(30)');
    v_obt := format('lo cobrado en 30 días: %s | lo devuelto, ya restado: %s | lo devuelto de cobros de antes: %s',
      case when e1 -> 'cobrado' -> 'monto' = e0 -> 'cobrado' -> 'monto' and e1 -> 'cobrado' -> 'n' = e0 -> 'cobrado' -> 'n' then 'igual'
           else format('otro (%s → %s)', e0 -> 'cobrado' ->> 'monto', e1 -> 'cobrado' ->> 'monto') end,
      case when e1 -> 'cobrado' -> 'devuelto' -> 'monto' = e0 -> 'cobrado' -> 'devuelto' -> 'monto' then 'igual'
           else format('otro (%s → %s)', e0 -> 'cobrado' -> 'devuelto' ->> 'monto', e1 -> 'cobrado' -> 'devuelto' ->> 'monto') end,
      case when e1 -> 'cobrado' -> 'devuelto_antes' is null or e1 -> 'cobrado' -> 'devuelto_antes' = 'null'::jsonb then 'no lo dice'
           else format('%s más (%s más), %s',
                       pg_temp.c16_m((e1 -> 'cobrado' -> 'devuelto_antes' ->> 'monto')::numeric
                                     - coalesce((nullif(e0 -> 'cobrado' -> 'devuelto_antes', 'null'::jsonb) ->> 'monto')::numeric, 0)),
                       (e1 -> 'cobrado' -> 'devuelto_antes' ->> 'n')::int - coalesce((nullif(e0 -> 'cobrado' -> 'devuelto_antes', 'null'::jsonb) ->> 'n')::int, 0),
                       case when e1 -> 'cobrado' -> 'devuelto_antes' ->> 'etiqueta' like '%de antes%' then 'lo dice aparte' else 'sin texto' end) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (48, 'LO DEVUELTO DE UN COBRO DE ANTES: un cheque de hace 40 días que rebota hace 5 no cambia lo cobrado en los 30 días ni lo devuelto «ya restado» (no se restó de nada); se dice aparte, como lo devuelto de un cobro de antes',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 49. STRIPE, EL REEMBOLSO DE UN PAGO DE ANTES (la revisión final): un pago
--     de Stripe ya depositado se reembolsa en parte HOY; p1 devuelve su cobro
--     y registra uno nuevo, con la fecha de hoy, por lo que queda. En un
--     embudo de pocos días que ya no alcanza el día del pago, ese cobro nuevo
--     NO es dinero cobrado en esos días (se cobró aquel día): lo cobrado no
--     cambia, y el reembolso va aparte, como lo devuelto de un cobro de antes.
--     Antes, lo que quedaba del pago salía «cobrado» en esos días.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); s0 record; v_re numeric; v_dias int; e0 jsonb; e1 jsonb;
begin
  if pg_temp.c16_omitir(49, 'Stripe, el reembolso de un pago de antes', 'lo que queda no es cobrado de estos días', false, array['p1', 'c6']) then return; end if;
  select s.id, s.monto, s.foto, c.fecha into s0
    from stripe_pagos s join v_stripe_pagos v on v.id = s.id join cobros c on c.id = s.cobro_id
   where v.estado_pantalla = 'depositado' and s.foto is not null and s.en_libro > 0 and c.fecha < v_hoy
   order by c.fecha desc, s.creado_el desc limit 1;
  if s0.id is null then
    insert into _pruebas values (49, 'STRIPE, EL REEMBOLSO DE UN PAGO DE ANTES', 'un pago de Stripe ya depositado, de antes de hoy',
      'omitida: no hay ningún pago de Stripe ya depositado de antes de hoy: no hay qué reembolsar', null);
    return;
  end if;
  v_dias := v_hoy - s0.fecha;    -- (el embudo de esos días va del día siguiente al pago a hoy: ya no lo alcanza)
  v_re := round(s0.monto * 0.20, 2);
  v_esp := format('el embudo de %s días: lo cobrado igual | lo devuelto, ya restado: igual | lo devuelto de cobros de antes: %s más, lo dice aparte',
                  v_dias, pg_temp.c16_m(v_re));
  begin
    e0 := pg_temp.c16_j(format('select public.fn_tablero_cobros(%s)', v_dias));
    perform pg_temp.c16_ser('editor');
    begin
      perform fn_stripe_pago_sincronizar(s0.foto || jsonb_build_object('visto_el', clock_timestamp(), 'reembolsos', jsonb_build_array(
                jsonb_build_object('id', 're_C16PRUEBA49', 'monto', round(v_re * 100)::bigint, 'estado', 'succeeded',
                                   'creado', extract(epoch from now())::bigint, 'bt', 'txn_re_C16PRUEBA49', 'bt_fallo', null, 'motivo_fallo', null))),
                'evt_C16PRUEBA_REEMBOLSO_49');
    exception when others then
      v_obt := 'omitida: p1 no aceptó el reembolso de prueba (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    e1 := pg_temp.c16_j(format('select public.fn_tablero_cobros(%s)', v_dias));
    v_obt := format('el embudo de %s días: lo cobrado %s | lo devuelto, ya restado: %s | lo devuelto de cobros de antes: %s', v_dias,
      case when e1 -> 'cobrado' -> 'monto' = e0 -> 'cobrado' -> 'monto' and e1 -> 'cobrado' -> 'n' = e0 -> 'cobrado' -> 'n' then 'igual'
           else format('otro (%s → %s)', e0 -> 'cobrado' ->> 'monto', e1 -> 'cobrado' ->> 'monto') end,
      case when e1 -> 'cobrado' -> 'devuelto' -> 'monto' = e0 -> 'cobrado' -> 'devuelto' -> 'monto' then 'igual'
           else format('otro (%s → %s)', e0 -> 'cobrado' -> 'devuelto' ->> 'monto', e1 -> 'cobrado' -> 'devuelto' ->> 'monto') end,
      case when e1 -> 'cobrado' -> 'devuelto_antes' is null or e1 -> 'cobrado' -> 'devuelto_antes' = 'null'::jsonb then 'no lo dice'
           else format('%s más, %s',
                       pg_temp.c16_m((e1 -> 'cobrado' -> 'devuelto_antes' ->> 'monto')::numeric
                                     - coalesce((nullif(e0 -> 'cobrado' -> 'devuelto_antes', 'null'::jsonb) ->> 'monto')::numeric, 0)),
                       case when e1 -> 'cobrado' -> 'devuelto_antes' ->> 'etiqueta' like '%de antes%' then 'lo dice aparte' else 'sin texto' end) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (49, 'STRIPE, EL REEMBOLSO DE UN PAGO DE ANTES: p1 devuelve el cobro y registra uno nuevo con la fecha de hoy por lo que queda; en un embudo que ya no alcanza el día del pago, eso no es cobrado en esos días (lo cobrado no cambia) y el reembolso va aparte, como lo devuelto de un cobro de antes',
    coalesce(v_esp, 'lo que queda del pago no es cobrado de estos días'), v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 50. LA PROYECCIÓN Y LA DEUDA DE LA NÓMINA CON TODO LO QUE EL LIBRO TIENE (la
--     revisión final, con la nómina de c15 en producción). (14-nov, Fase 11c:
--     CON c15 EN LA BASE esa deuda ya no va en «no incluye»: va EN la
--     proyección, y esta prueba mira lo mismo ahí —(a) una deuda de la nómina
--     fechada después de hoy, a mano y sin journal, se resta ya, este mes;
--     (b) si su cargo ya salió del banco, lo que se debe vuelve a lo de
--     antes, el banco baja y el saldo proyectado no cambia: no se resta dos
--     veces—. Lo de una nómina de verdad con día de pago después de hoy, la
--     57. SIN c15, como estaba:)
--     El journal de una nómina lleva la fecha de su día de pago, y Gusto cobra
--     del banco unos días antes. (a) Una nómina ya posteada con día de pago
--     después de hoy: lo que deja por pagar se dice (la deuda sube y el texto
--     lo cuenta), aunque hoy todavía no se deba. (b) Si su cargo ya salió del
--     banco antes de ese día, la deuda vuelve a ser la de antes: no baja en
--     negativo (contada solo hasta hoy, salía «se debe −500.00»). Con un
--     asiento a mano en la primera cuenta de «nómina y retenciones por pagar»
--     del balance de c4 (la 2210), que se deshace.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_f date := pg_temp.c16_hoy() + 3;
  v_banco text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'banco');
  v_nom text := (select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'nomina_por_pagar' order by m.cuenta limit 1);
  c0 jsonb; c1 jsonb; c2 jsonb; d0 jsonb; d1 jsonb; d2 jsonb; v_c15 boolean := pg_temp.c16_hay_c15();
begin
  if pg_temp.c16_omitir(50, 'la proyección, lo que no incluye: la deuda de la nómina', 'con todo lo que el libro tiene, también lo fechado después de hoy', true) then return; end if;
  if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.reversa_a is null and not exists (select 1 from asientos r where r.reversa_a = a.id)) then
    insert into _pruebas values (50, 'LA PROYECCIÓN, LO QUE NO INCLUYE: LA DEUDA DE LA NÓMINA', 'la apertura en el libro (sin ella no hay proyección)',
      'omitida: la apertura todavía no está en el libro: no hay proyección de caja, ni lista de lo que no incluye (lo comprueban la 15 y la 41)', null);
    return;
  end if;
  if v_nom is null or v_banco is null then
    insert into _pruebas values (50, 'LA PROYECCIÓN, LO QUE NO INCLUYE: LA DEUDA DE LA NÓMINA', 'una cuenta de nómina por pagar en el balance de c4 y la del banco',
      'omitida: el mapeo de c4 no tiene ninguna cuenta en «nómina y retenciones por pagar», o los puentes no dicen cuál es el banco', null);
    return;
  end if;
  v_esp := case when v_c15
                then 'con la nómina de c15: una deuda de la nómina fechada después de hoy (a mano, sin journal) se resta ya, este mes (500.00 más), y '
                     || 'no va en «no incluye» | su cargo ya salió del banco: lo que sale por la nómina vuelve a lo de antes, el banco baja 500.00 y el '
                     || 'saldo proyectado no cambia (no se resta dos veces)'
                else 'una nómina posteada con día de pago después de hoy: la deuda sube 500.00, lo de hasta hoy igual, lo dice | '
                     || 'su cargo ya salió del banco: la deuda vuelve a la de antes, lo de hasta hoy baja 500.00' end;
  begin
    c0 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    if c0 -> 'proyeccion' is null or c0 -> 'proyeccion' = 'null'::jsonb then
      v_obt := 'omitida: hoy no hay nada con fecha que proyectar en esta base: sin proyección no hay lista de lo que no incluye';
      raise exception using errcode = 'MXT00';
    end if;
    begin
      perform pg_temp.c16_postear(v_f, 'una nómina con día de pago después de hoy', jsonb_build_array(
                jsonb_build_object('cuenta', '6100', 'monto', '500.00'), jsonb_build_object('cuenta', v_nom, 'monto', '-500.00')));
    exception when others then
      v_obt := 'omitida: esta base no deja fechar el asiento de prueba tres días después de hoy (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      raise exception using errcode = 'MXT00';
    end;
    c1 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    perform pg_temp.c16_postear(v_hoy, 'el cargo de esa nómina, que sale del banco antes de su día de pago', jsonb_build_array(
              jsonb_build_object('cuenta', v_nom, 'monto', '500.00'), jsonb_build_object('cuenta', v_banco, 'monto', '-500.00')));
    c2 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    select x into d0 from jsonb_array_elements(c0 -> 'proyeccion' -> 'no_incluye') x where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar';
    select x into d1 from jsonb_array_elements(c1 -> 'proyeccion' -> 'no_incluye') x where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar';
    select x into d2 from jsonb_array_elements(c2 -> 'proyeccion' -> 'no_incluye') x where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar';
    if v_c15 then
      -- (14-nov, Fase 11c) con c15, EN la proyección: lo que sale por la nómina este mes y el saldo del mes
      v_obt := format('con la nómina de c15: una deuda de la nómina fechada después de hoy (a mano, sin journal) %s, y %s | su cargo ya salió del '
                      'banco: lo que sale por la nómina %s, el banco baja %s y el saldo proyectado %s',
        case when (c1 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina')::numeric - (c0 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina')::numeric = 500
             then 'se resta ya, este mes (500.00 más)'
             else format('no se resta este mes (%s → %s)', c0 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina', c1 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina') end,
        case when d0 is null and d1 is null and d2 is null then 'no va en «no incluye»' else 'sigue en «no incluye»' end,
        case when c2 -> 'proyeccion' -> 'meses' -> 0 -> 'nomina' = c0 -> 'proyeccion' -> 'meses' -> 0 -> 'nomina' then 'vuelve a lo de antes'
             else format('no es lo de antes (%s → %s)', c0 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina', c2 -> 'proyeccion' -> 'meses' -> 0 ->> 'nomina') end,
        pg_temp.c16_m((c0 -> 'hoy' ->> 'neto')::numeric - (c2 -> 'hoy' ->> 'neto')::numeric),
        case when c2 -> 'proyeccion' -> 'meses' -> 0 -> 'saldo' = c1 -> 'proyeccion' -> 'meses' -> 0 -> 'saldo'
                  and (c0 -> 'proyeccion' -> 'meses' -> 0 ->> 'saldo')::numeric - (c1 -> 'proyeccion' -> 'meses' -> 0 ->> 'saldo')::numeric = 500
             then 'no cambia (no se resta dos veces)'
             else format('cambia (%s → %s → %s)', c0 -> 'proyeccion' -> 'meses' -> 0 ->> 'saldo', c1 -> 'proyeccion' -> 'meses' -> 0 ->> 'saldo',
                         c2 -> 'proyeccion' -> 'meses' -> 0 ->> 'saldo') end);
    else
    v_obt := format('una nómina posteada con día de pago después de hoy: la deuda %s, lo de hasta hoy %s, %s | su cargo ya salió del banco: la deuda %s, lo de hasta hoy %s',
      case when coalesce((d1 ->> 'monto')::numeric, 0) - coalesce((d0 ->> 'monto')::numeric, 0) = 500 then 'sube 500.00'
           else format('no sube 500.00 (%s → %s)', coalesce(d0 ->> 'monto', '0.00'), coalesce(d1 ->> 'monto', '0.00')) end,
      case when d1 is null then 'sin decir'
           when coalesce((d1 ->> 'a_hoy')::numeric, 0) = coalesce((d0 ->> 'a_hoy')::numeric, (d0 ->> 'monto')::numeric, 0) then 'igual'
           else format('otro (%s → %s)', coalesce(d0 ->> 'a_hoy', d0 ->> 'monto', '0.00'), coalesce(d1 ->> 'a_hoy', '?')) end,
      case when d1 ->> 'texto' like '%después de hoy%' and (d1 ->> 'despues')::numeric - coalesce((d0 ->> 'despues')::numeric, 0) = 500 then 'lo dice' else 'no lo dice' end,
      case when coalesce((d2 ->> 'monto')::numeric, 0) = coalesce((d0 ->> 'monto')::numeric, 0) then 'vuelve a la de antes'
           else format('no es la de antes (%s → %s)', coalesce(d0 ->> 'monto', '0.00'), coalesce(d2 ->> 'monto', '0.00')) end,
      case when d2 is null then case when coalesce((d0 ->> 'monto')::numeric, 0) = 0 then 'baja 500.00' else 'sin decir' end
           when coalesce((d2 ->> 'a_hoy')::numeric, 0) - coalesce((d0 ->> 'a_hoy')::numeric, (d0 ->> 'monto')::numeric, 0) = -500 then 'baja 500.00'
           else format('otro (%s → %s)', coalesce(d0 ->> 'a_hoy', d0 ->> 'monto', '0.00'), coalesce(d2 ->> 'a_hoy', '?')) end);
    end if;
    if (c2 ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c2 ->> 'motivo', '?'); end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (50, 'LA PROYECCIÓN Y LA DEUDA DE LA NÓMINA con todo lo que el libro tiene en sus cuentas, también lo fechado después de hoy. Sin c15, en «no incluye»: una nómina ya posteada con día de pago después de hoy se dice (la deuda sube); y si su cargo ya salió del banco antes de ese día, la deuda no baja en negativo (vuelve a la de antes). Con la nómina de c15 en la base, EN la proyección: se resta ya, y con su cargo ya salido del banco no se resta dos veces',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- =====================================================================
-- LA NÓMINA DE GUSTO EN LA PORTADA (14-nov, Fase 11c; de la 51 a la 61).
-- La tarjeta «nomina», su acción rápida, lo que pide atender y la
-- proyección de la caja, contra el libro crudo y las tablas y vistas de la
-- nómina (c15): con el código del teléfono y sin él (el dueño con aal2 y
-- con aal1), una nómina de una sola persona, una importada sin postear,
-- los cargos de Gusto, el equipo, y sin c15. Cada una en su bloque que se
-- deshace (MXT00). Sin la nómina de c15 en la base salen «omitida» (menos
-- la 58, que mira justo eso).
-- =====================================================================

-- 51. LA TARJETA DE LA NÓMINA, COMO ESTÁ LA BASE (sin sembrar nada), con el
--     código del teléfono: lo que costó la nómina cada mes y lo que se debe
--     de ella (del libro crudo), cuándo sale de la caja, la bolsa del
--     burden, los cargos de Gusto que esperan (la vista de su página), las
--     que esperan por postear, la última y la próxima (de las tablas de la
--     nómina: sus personas contadas y sus totales sumados de lo de cada
--     una), sus cuadres; lo que cuenta su acción rápida, y los meses que se
--     piden.
do $$
declare
  v_obt text; v_esp text; n jsonb := pg_temp.c16_tc('nomina'); a jsonb; t2 jsonb; v_meses int; v_hoy date := pg_temp.c16_hoy();
begin
  if pg_temp.c16_nom_omitir(51, 'la tarjeta de la nómina, como está la base', 'cada cifra, la del libro o la de la nómina', false) then return; end if;
  begin
    -- (de los 2 meses que se piden, los que el libro tiene)
    select count(*) into v_meses
      from generate_series(greatest(date_trunc('month', pg_temp.c16('libro_desde')::date), date_trunc('month', v_hoy) - interval '1 month'),
                           date_trunc('month', v_hoy), interval '1 month') g;
    v_esp := pg_temp.c16_nom_espera()
             || format(' || su acción rápida: %s esperan, lleva a la página de la nómina | pedida con 2 meses: %s | la tarjeta lleva a Nómina | '
                       'el tablero dice que la nómina (c15) está: sí', pg_temp.c16_nom_esperan(), v_meses);
    select x into a from jsonb_array_elements(pg_temp.c16_tc('acciones') -> 'lista') x where x ->> 'clave' = 'nomina';
    t2 := pg_temp.c16_t('{"tarjetas": ["nomina"], "nomina": {"meses": 2}}');
    v_obt := pg_temp.c16_nom_dice(n)
             || format(' || su acción rápida: %s esperan, lleva a %s | pedida con 2 meses: %s | la tarjeta lleva a %s | '
                       'el tablero dice que la nómina (c15) está: %s',
                       coalesce(a ->> 'n', 'no dice cuántas'),
                       case when a -> 'ir' ->> 'pagina' = 'nomina' and a -> 'ir' ->> 'sub' in ('nominas', 'cargos') then 'la página de la nómina'
                            else coalesce(a ->> 'ir', 'ningún sitio') end,
                       jsonb_array_length(t2 -> 'nomina' -> 'meses'),
                       case when n -> 'ir' ->> 'pagina' = 'nomina' then 'Nómina' else coalesce(n ->> 'ir', '?') end,
                       case when pg_temp.c16_capa('c15') then 'sí' else 'no' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (51, 'LA TARJETA DE LA NÓMINA, COMO ESTÁ LA BASE, con el código del teléfono, contra el libro crudo y las tablas de la nómina (c15), al centavo: lo que costó cada mes (sueldos y lo del patrón, de sus asientos), lo que se debe de ella (2210 a 2250; la de reembolsos al revés, aparte) y cuándo sale, la bolsa del burden, los cargos de Gusto que esperan, las que esperan por postear, la última y la próxima (sus personas contadas y sus totales sumados de lo de cada una), sus cuadres; lo que cuenta su acción rápida y los meses pedidos',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 52. UNA NÓMINA DE TRES PERSONAS, POSTEADA, CON EL CÓDIGO: entra por el
--     camino de c15 (el journal de prueba «tres», con día de pago hoy) y la
--     tarjeta la trae como la última, con los totales de la EMPRESA al
--     centavo (los inventados, y los mismos que suman sus tres personas en
--     las tablas de la nómina); el mes de hoy sube lo que costó, y lo que el
--     Balance dice que se debe, lo que dejó por pagar menos lo reembolsado.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; n0 jsonb; n jsonb; u jsonb; m0 jsonb; m1 jsonb;
begin
  if pg_temp.c16_nom_omitir(52, 'una nómina de tres personas, posteada, con el código', 'la última, con sus totales al centavo') then return; end if;
  begin
    n0 := pg_temp.c16_nom_tarjeta();
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    -- (y la prima de WC del mes pasado, a mano, a la bolsa del burden: queda sin repartir; si ese mes ya está cerrado no entra, y
    --  la bolsa se compara como esté)
    begin
      perform pg_temp.c16_postear(date_trunc('month', v_hoy)::date - 1, 'la prima de WC del mes pasado, a la bolsa del burden',
                jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '123.45'), jsonb_build_object('cuenta', '1410', 'monto', '-123.45')));
    exception when others then
      perform pg_temp.c16_ser('editor');
    end;
    n := pg_temp.c16_nom_tarjeta();
    u := n -> 'ultima'; m0 := n0 -> 'meses' -> -1; m1 := n -> 'meses' -> -1;
    v_esp := pg_temp.c16_nom_espera()
             || ' || la de prueba es la última: 3 personas, costo 6214.03 (bruto 5600.75 + patrón 613.28), impuestos 1512.74, neto 4663.79, '
             || 'deducciones 37.50, reembolsos 61.30, le quedan por pagar 6275.33 | el mes de hoy sube 6214.03 (sueldos 5600.75 + patrón 613.28), '
             || 'con una nómina más | lo que el Balance dice que se debe sube 6214.03 (lo que dejó por pagar, 6275.33, menos lo reembolsado, 61.30) | '
             || 'las cuentas suman lo que se debe, y lo que sale también: sí | en llano: sí';
    v_obt := pg_temp.c16_nom_dice(n)
             || format(' || la de prueba %s: %s personas, costo %s (bruto %s + patrón %s), impuestos %s, neto %s, deducciones %s, reembolsos %s, '
                       'le quedan por pagar %s | el mes de hoy sube %s (sueldos %s + patrón %s), con %s | lo que el Balance dice que se debe sube %s '
                       '(lo que dejó por pagar, 6275.33, menos lo reembolsado, 61.30) | las cuentas suman lo que se debe, y lo que sale también: %s | '
                       'en llano: %s',
                       case when u ->> 'corrida' = c::text then 'es la última' else 'NO es la última' end, u ->> 'personas',
                       pg_temp.c16_mj(u -> 'costo'), pg_temp.c16_mj(u -> 'bruto'), pg_temp.c16_mj(u -> 'patron'), pg_temp.c16_mj(u -> 'impuestos'),
                       pg_temp.c16_mj(u -> 'neto'), pg_temp.c16_mj(u -> 'deducciones'), pg_temp.c16_mj(u -> 'reembolsos'), pg_temp.c16_mj(u -> 'por_pagar'),
                       pg_temp.c16_m((m1 ->> 'costo')::numeric - (m0 ->> 'costo')::numeric),
                       pg_temp.c16_m((m1 ->> 'sueldos')::numeric - (m0 ->> 'sueldos')::numeric),
                       pg_temp.c16_m((m1 ->> 'patron')::numeric - (m0 ->> 'patron')::numeric),
                       case when (m1 ->> 'nominas')::int - (m0 ->> 'nominas')::int = 1 then 'una nómina más'
                            else format('%s nóminas más', (m1 ->> 'nominas')::int - (m0 ->> 'nominas')::int) end,
                       pg_temp.c16_m((n -> 'debe' ->> 'libro')::numeric - (n0 -> 'debe' ->> 'libro')::numeric),
                       pg_temp.c16_nom_suma(n), coalesce(pg_temp.c16_llano(n), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (52, 'UNA NÓMINA DE TRES PERSONAS, POSTEADA, CON EL CÓDIGO DEL TELÉFONO (el journal de prueba, por el camino de c15, con día de pago hoy): la tarjeta entera contra el libro y las tablas de la nómina, al centavo; es la última, con los totales de la EMPRESA (cuántas personas, costo = bruto + lo del patrón, impuestos, neto, deducciones, reembolsos, lo que le queda por pagar); el mes de hoy sube lo que costó; lo que el Balance dice que se debe sube lo que dejó por pagar menos lo reembolsado; las cuentas y los pagos suman lo que se debe; sus textos, en llano',
    coalesce(v_esp, 'la última, con sus totales al centavo'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 53. LA MISMA NÓMINA, SIN EL CÓDIGO DEL TELÉFONO (el dueño con aal1): la
--     decisión de seguridad. De la última, solo lo que el libro dice (su día
--     y su asiento) y «con el código del teléfono»; NADA de una nómina en la
--     tarjeta (cuántas personas, su bruto, su neto, sus impuestos, lo que le
--     queda, su período); las que esperan por postear y los des-casados, «no
--     se sabe» (nulo), NUNCA un cero; los cuadres que la nómina tapa sin el
--     código no son un rojo ni un verde (sin_comprobar); lo de la empresa
--     (del libro y del banco), igual que con el código; lo que pide atender,
--     entrar con el código; y el tablero entero contesta sin el código (sin
--     el error «MFA» de c15).
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; n1 jsonb; n2 jsonb; t1 jsonb; a jsonb; v_num text; v_sin int; v_de text; v_ult text;
begin
  if pg_temp.c16_nom_omitir(53, 'la misma nómina, sin el código del teléfono', 'solo lo de la empresa; lo de la nómina, «con el código»') then return; end if;
  begin
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    select k.asiento_numero into v_num from nomina_corridas k where k.id = c;
    n2 := pg_temp.c16_nom_tarjeta();
    n1 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    t1 := pg_temp.c16_j($q$select public.fn_tablero('{"tope_ms": 0}'::jsonb)$q$, 'dueno_aal1');
    -- (los cuadres que la nómina tapa sin el código, contados en su vista —su control entero— como lo ve esa sesión)
    v_sin := (pg_temp.c16_j($q$select to_jsonb(count(*)) from public.v_nomina_control k
                                where k.nivel = 'cuadre' and k.ok is not true
                                  and k.detalle like '%hace falta el código del teléfono%'$q$, 'dueno_aal1') #>> '{}')::int;
    select x into a from jsonb_array_elements(t1 -> 'acciones' -> 'lista') x where x ->> 'clave' = 'nomina';
    v_esp := format('con el código: no, y lo dice | la última: su día (%s) y su asiento (%s), y que lo demás va con el código del teléfono | '
                    'de una nómina (cuántas personas, su bruto, su neto, sus impuestos, lo que le queda, su período), en la tarjeta: nada | '
                    'por postear: no se sabe (ni un cero) | des-casados: no se sabe | cuadres en rojo: no más que con el código | '
                    'sin comprobar: %s (los cuadres que la nómina tapa sin el código; más de cero) | lo de la empresa (los meses, lo que se debe y cuándo '
                    'sale, la bolsa, los cargos que esperan en el banco): igual que con el código | qué atender: entrar con el código | '
                    'su acción rápida: sin el código, y dice que las por postear se ven con él | el tablero entero sin el código: 16 tarjetas '
                    'contestan o dicen qué capa falta | en llano: sí', v_hoy, v_num, v_sin);
    select string_agg(k, ', ' order by k) into v_de
      from unnest(array['personas', 'bruto', 'neto', 'impuestos', 'deducciones', 'reembolsos', 'por_pagar', 'a_favor', 'periodo', 'periodo_desde',
                        'periodo_hasta', 'tipo', 'tipo_texto', 'corrida']) k
     where jsonb_path_exists(n1, ('strict $.**.' || k)::jsonpath);
    select string_agg(k, ', ' order by k) into v_ult
      from (select jsonb_object_keys(coalesce(nullif(n1 -> 'ultima', 'null'::jsonb), '{}'::jsonb)) as k
            union select jsonb_object_keys(coalesce(nullif(n1 -> 'proxima', 'null'::jsonb), '{}'::jsonb))) q
     where k not in ('dia_pago', 'etiqueta', 'asiento', 'con_codigo', 'texto', 'ir', 'estado');
    v_obt := format('con el código: %s | la última: su día (%s) y su asiento (%s)%s | de una nómina (cuántas personas, su bruto, su neto, sus '
                    'impuestos, lo que le queda, su período), en la tarjeta: %s | por postear: %s | des-casados: %s | cuadres en rojo: %s | '
                    'sin comprobar: %s (los cuadres que la nómina tapa sin el código; %s) | lo de la empresa (los meses, lo que se debe y cuándo sale, la '
                    'bolsa, los cargos que esperan en el banco): %s | qué atender: %s | su acción rápida: %s | el tablero entero sin el código: %s '
                    'tarjetas contestan o dicen qué capa falta | en llano: %s',
                    case when (n1 ->> 'con_codigo')::boolean is false and n1 -> 'codigo' ->> 'texto' like '%código del teléfono%' then 'no, y lo dice'
                         else coalesce(n1 ->> 'con_codigo', '?') || ', sin decirlo' end,
                    n1 -> 'ultima' ->> 'dia_pago', n1 -> 'ultima' ->> 'asiento',
                    case when (n1 -> 'ultima' ->> 'con_codigo')::boolean is false and n1 -> 'ultima' ->> 'texto' like '%con el código del teléfono%'
                         then ', y que lo demás va con el código del teléfono' else ', sin decir lo del código' end,
                    coalesce(nullif(concat_ws(', ', v_de, v_ult), ''), 'nada'),
                    case when n1 ? 'por_postear' and jsonb_typeof(n1 -> 'por_postear') = 'null' then 'no se sabe (ni un cero)'
                         else coalesce(n1 ->> 'por_postear', 'sin la clave') end,
                    case when n1 -> 'cargos' ? 'descasados' and jsonb_typeof(n1 -> 'cargos' -> 'descasados') = 'null' then 'no se sabe'
                         else coalesce(n1 -> 'cargos' ->> 'descasados', 'sin la clave') end,
                    case when (n1 -> 'control' ->> 'cuadres_rojos')::int <= (n2 -> 'control' ->> 'cuadres_rojos')::int then 'no más que con el código'
                         else format('%s (con el código, %s)', n1 -> 'control' ->> 'cuadres_rojos', n2 -> 'control' ->> 'cuadres_rojos') end,
                    n1 -> 'control' ->> 'sin_comprobar',
                    case when (n1 -> 'control' ->> 'sin_comprobar')::int > 0 then 'más de cero' else 'cero' end,
                    case when n1 -> 'meses' = n2 -> 'meses' and n1 -> 'debe' = n2 -> 'debe' and n1 -> 'bolsa' -> 'monto' = n2 -> 'bolsa' -> 'monto'
                              and (n1 -> 'cargos') - 'descasados' = (n2 -> 'cargos') - 'descasados' then 'igual que con el código'
                         else 'distinto que con el código' end,
                    case when exists (select 1 from jsonb_array_elements(n1 -> 'atender') x where x ->> 'clave' = 'codigo')
                              and not exists (select 1 from jsonb_array_elements(n1 -> 'atender') x where x ->> 'clave' = 'por_postear')
                         then 'entrar con el código' else 'otra cosa: ' || (n1 ->> 'atender') end,
                    case when (a ->> 'con_codigo')::boolean is false and a ->> 'detalle' like '%por postear se ven con el código del teléfono%'
                         then 'sin el código, y dice que las por postear se ven con él' else coalesce(a ->> 'detalle', 'no está') end,
                    (select count(*) from jsonb_array_elements_text(t1 -> 'tarjetas') k where (t1 -> k ->> 'ok')::boolean or t1 -> k ->> 'falta' is not null),
                    coalesce(pg_temp.c16_llano(n1), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (53, 'LA MISMA NÓMINA, SIN EL CÓDIGO DEL TELÉFONO (el dueño que entró solo con su contraseña: aal1): de la última, solo lo que el libro dice (su día y su asiento) y «con el código del teléfono»; nada de una nómina en la tarjeta (cuántas personas, su bruto, su neto, sus impuestos, lo que le queda, su período); las que esperan por postear y los des-casados, «no se sabe» (nulo), NUNCA un cero; lo que la nómina tapa sin el código no cuenta como rojo ni como verde; lo de la EMPRESA (del libro y del banco), igual que con el código; pide entrar con el código; y el tablero entero contesta sin él',
    coalesce(v_esp, 'solo lo de la empresa; lo de la nómina, «con el código»'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 54. LOS CARGOS DE GUSTO: el cargo del neto de la nómina de prueba llega al
--     banco (Plaid) y espera en la Bandeja: sale en la tarjeta (uno más, por
--     su monto), en lo que pide atender y en la acción rápida, con su
--     enlace a Nómina → Cargos de Gusto; mientras espera, lo que se debe no
--     baja. CASADO con su nómina (c15), deja de esperar, lo que se debe y lo
--     que le queda a la nómina bajan en eso, y la proyección NO LO RESTA
--     OTRA VEZ: el banco bajó y lo que se debe también; el saldo proyectado
--     no cambia. Y una devolución de Gusto (un depósito) que espera.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; n0 jsonb; n1 jsonb; n2 jsonb; n3 jsonb; a0 jsonb; a1 jsonb; c0 jsonb; c1 jsonb; c2 jsonb;
  v_mov uuid; v_dev uuid; v_proy boolean; x1 jsonb;
begin
  if pg_temp.c16_nom_omitir(54, 'los cargos de Gusto', 'esperan con su enlace; casados, no se restan otra vez', true, true) then return; end if;
  begin
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    n0 := pg_temp.c16_nom_tarjeta();
    c0 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    select x into a0 from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()') -> 'lista') x where x ->> 'clave' = 'nomina';
    v_proy := c0 -> 'proyeccion' is not null and c0 -> 'proyeccion' <> 'null'::jsonb;
    -- (a) el cargo del neto (4,725.09) llega al banco y espera
    v_mov := pg_temp.c16_nom_cargo('zz-c16-prueba-net', v_hoy, 4725.09, 'GUSTO DES:NET ID:ZZ00000001');
    n1 := pg_temp.c16_nom_tarjeta();
    c1 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    select x into a1 from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()') -> 'lista') x where x ->> 'clave' = 'nomina';
    select x into x1 from jsonb_array_elements(n1 -> 'atender') x where x ->> 'clave' = 'cargos';
    -- (b) casado con el neto de su nómina, desde Nómina → Cargos de Gusto
    perform pg_temp.c16_nom_casar(v_mov, jsonb_build_array(jsonb_build_object('corrida', c, 'cuenta', '2210', 'monto', '4725.09')));
    n2 := pg_temp.c16_nom_tarjeta();
    c2 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    -- (c) una devolución de Gusto (un depósito de 12.34) que espera
    v_dev := pg_temp.c16_nom_cargo('zz-c16-prueba-dev', v_hoy, -12.34, 'GUSTO DES:REV ID:ZZ00000002');
    n3 := pg_temp.c16_nom_tarjeta();
    v_esp := 'el cargo espera: uno más, 4725.09 más, lo que se debe igual | pide atenderlo, en Nómina → Cargos de Gusto | su acción rápida: uno más, '
             || 'lleva a Nómina | casado: deja de esperar, lo que se debe baja 4725.09, a la nómina le quedan 1550.24 | '
             || case when v_proy then 'la proyección: mientras espera, igual; casado, el banco baja 4725.09, lo que sale por la nómina baja 4725.09 y '
                                      'el saldo proyectado no cambia (no se resta otra vez)'
                     else 'la proyección: no la hay en esta base (sin la apertura en el libro, o sin nada con fecha)' end
             || ' | la devolución espera: una más, por 12.34, y pide atenderla | las tres veces, como dice la vista de los cargos de la nómina: sí';
    v_obt := format('el cargo espera: %s, %s más, lo que se debe %s | pide atenderlo, en %s | su acción rápida: %s, lleva a %s | casado: %s, lo que se '
                    'debe baja %s, a la nómina le quedan %s | %s | la devolución espera: %s, por %s, y %s | las tres veces, como dice la vista de '
                    'los cargos de la nómina: %s',
                    case when (n1 -> 'cargos' ->> 'n')::int - (n0 -> 'cargos' ->> 'n')::int = 1 then 'uno más'
                         else format('%s más', (n1 -> 'cargos' ->> 'n')::int - (n0 -> 'cargos' ->> 'n')::int) end,
                    pg_temp.c16_m((n1 -> 'cargos' ->> 'monto')::numeric - (n0 -> 'cargos' ->> 'monto')::numeric),
                    case when n1 -> 'debe' -> 'monto' = n0 -> 'debe' -> 'monto' then 'igual' else 'otro' end,
                    case when x1 -> 'ir' ->> 'pagina' = 'nomina' and x1 -> 'ir' ->> 'sub' = 'cargos' and x1 ->> 'texto' like '%Gusto%'
                         then 'Nómina → Cargos de Gusto' else coalesce(x1 ->> 'ir', 'ningún sitio (no lo pide)') end,
                    case when (a1 ->> 'n')::int - (a0 ->> 'n')::int = 1 then 'uno más' else format('%s más', (a1 ->> 'n')::int - (a0 ->> 'n')::int) end,
                    case when a1 -> 'ir' ->> 'pagina' = 'nomina' then 'Nómina' else coalesce(a1 ->> 'ir', '?') end,
                    case when n2 -> 'cargos' -> 'n' = n0 -> 'cargos' -> 'n' and n2 -> 'cargos' -> 'monto' = n0 -> 'cargos' -> 'monto' then 'deja de esperar'
                         else 'sigue esperando' end,
                    pg_temp.c16_m((n0 -> 'debe' ->> 'monto')::numeric - (n2 -> 'debe' ->> 'monto')::numeric),
                    pg_temp.c16_mj(n2 -> 'ultima' -> 'por_pagar'),
                    case when not v_proy then 'la proyección: no la hay en esta base (sin la apertura en el libro, o sin nada con fecha)'
                         else format('la proyección: mientras espera, %s; casado, el banco baja %s, lo que sale por la nómina baja %s y el saldo '
                                     'proyectado %s',
                                     case when c1 -> 'proyeccion' -> 'meses' = c0 -> 'proyeccion' -> 'meses' then 'igual' else 'otra' end,
                                     pg_temp.c16_m((c0 -> 'hoy' ->> 'neto')::numeric - (c2 -> 'hoy' ->> 'neto')::numeric),
                                     pg_temp.c16_m((select sum((m ->> 'nomina')::numeric) from jsonb_array_elements(c0 -> 'proyeccion' -> 'meses') m)
                                                   - (select sum((m ->> 'nomina')::numeric) from jsonb_array_elements(c2 -> 'proyeccion' -> 'meses') m)),
                                     case when c2 -> 'proyeccion' -> 'meses' -> -1 -> 'saldo' = c0 -> 'proyeccion' -> 'meses' -> -1 -> 'saldo'
                                          then 'no cambia (no se resta otra vez)' else 'cambia' end) end,
                    case when (n3 -> 'cargos' -> 'devoluciones' ->> 'n')::int - (n2 -> 'cargos' -> 'devoluciones' ->> 'n')::int = 1 then 'una más'
                         else 'no sale' end,
                    pg_temp.c16_m((n3 -> 'cargos' -> 'devoluciones' ->> 'monto')::numeric - (n2 -> 'cargos' -> 'devoluciones' ->> 'monto')::numeric),
                    case when exists (select 1 from jsonb_array_elements(n3 -> 'atender') x where x ->> 'clave' = 'devoluciones'
                                         and x -> 'ir' ->> 'sub' = 'cargos') then 'pide atenderla' else 'no lo pide' end,
                    'sí');
    -- (lo de la tarjeta al final, contra la vista de los cargos de la nómina tal como queda)
    if pg_temp.c16_nom_dice(n3) <> pg_temp.c16_nom_espera() then
      v_obt := regexp_replace(v_obt, 'sí$', 'no: ' || pg_temp.c16_nom_dice(n3) || ' ≠ ' || pg_temp.c16_nom_espera());
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (54, 'LOS CARGOS DE GUSTO: el cargo del neto de la nómina de prueba llega al banco y espera en la Bandeja: sale en la tarjeta (uno más, por su monto), en lo que pide atender y en la acción rápida, con su enlace a Nómina → Cargos de Gusto, y mientras espera lo que se debe no baja; CASADO con su nómina, deja de esperar, lo que se debe y lo que le queda a la nómina bajan en eso, y LA PROYECCIÓN NO LO RESTA OTRA VEZ (el banco bajó y lo que se debe también: el saldo proyectado no cambia); y una devolución de Gusto (un depósito) que espera',
    coalesce(v_esp, 'esperan con su enlace; casados, no se restan otra vez'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 55. UNA NÓMINA DE UNA SOLA PERSONA, Y LOS DOS CRITERIOS (la decisión de
--     seguridad, entera). Con el código: una persona y sus totales. SIN EL
--     CÓDIGO, con el criterio de fábrica («libro»): lo que costó la nómina
--     ese mes sale (es lo que el libro dice: lo mismo que Estados →
--     Resultados; con una sola persona, eso es lo que costó ella) y de la
--     nómina, nada; Gastos trae la cuenta del oficial, como siempre. Con el
--     criterio «codigo» (cambiando la palabra de fn_tablero_nomina_criterio
--     dentro del bloque) y sin el código: la tarjeta no escribe ninguna
--     cifra de dinero de la nómina (ni una de las inventadas aparece), Gastos
--     deja fuera las cuentas de la nómina y lo dice, y la proyección no
--     escribe aparte lo que sale por la nómina; con el código, los dos
--     criterios dan lo mismo. Al deshacerse, el criterio vuelve a «libro».
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; n0 jsonb; l2 jsonb; l1 jsonb; k2 jsonb; k1 jsonb; g0 jsonb; gl jsonb; gk jsonb; gk2 jsonb;
  ck jsonb; ck2 jsonb; ak jsonb; u jsonb; v_cifras text; v_fuera numeric; v_crit text; v_proy boolean;
  c_cifras constant text[] := array['2738.64', '2468.35', '2011.52', '727.12', '456.83', '270.29', '645.66'];
begin
  if pg_temp.c16_nom_omitir(55, 'una nómina de una sola persona, y los dos criterios', 'con el criterio «libro» sale lo del libro; con «codigo», ninguna cifra') then return; end if;
  begin
    n0 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    g0 := pg_temp.c16_j('select public.fn_tablero_gastos()', 'dueno_aal1');
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('una', v_hoy - 12, v_hoy - 4, v_hoy);
    -- el criterio de fábrica: «libro»
    l2 := pg_temp.c16_nom_tarjeta();
    l1 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    gl := pg_temp.c16_j('select public.fn_tablero_gastos()', 'dueno_aal1');
    u := l2 -> 'ultima';
    -- el criterio «codigo»: la misma función, con la otra palabra (se deshace con el bloque)
    execute $f$create or replace function public.fn_tablero_nomina_criterio() returns text
              language sql stable set search_path = public, pg_temp as $b$ select 'codigo'::text $b$ $f$;
    k2 := pg_temp.c16_nom_tarjeta();
    k1 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    gk := pg_temp.c16_j('select public.fn_tablero_gastos()', 'dueno_aal1');
    gk2 := pg_temp.c16_j('select public.fn_tablero_gastos()');
    ck := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)', 'dueno_aal1');
    ck2 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    ak := pg_temp.c16_j('select public.fn_tablero_acciones()', 'dueno_aal1');
    v_proy := ck2 -> 'proyeccion' is not null and ck2 -> 'proyeccion' <> 'null'::jsonb;
    -- (las cifras inventadas de esta nómina que aparecen en lo que la portada escribe de la nómina sin el código, con «codigo»)
    select string_agg(x, ', ' order by x) into v_cifras from unnest(c_cifras) x
     where position(x in k1::text) > 0 or position(x in ak::text) > 0
        or position(x in (select coalesce(jsonb_agg(q), '[]'::jsonb)::text from jsonb_array_elements(gk -> 'categorias') q
                           where q ->> 'cuenta' = any (array(select jsonb_array_elements_text(gk -> 'tapado' -> 'cuentas'))))) > 0;
    -- (lo que Gastos deja fuera con «codigo» y sin el código: las cuentas de la nómina, como las trae con el código)
    select coalesce(sum((q ->> 'monto')::numeric), 0) into v_fuera from jsonb_array_elements(gk2 -> 'categorias') q
     where q ->> 'cuenta' = any (array(select jsonb_array_elements_text(gk -> 'tapado' -> 'cuentas')));
    v_esp := 'con el código: 1 persona, costo 2738.64 (bruto 2468.35 + patrón 270.29), impuestos 727.12, neto 2011.52, le quedan por pagar 2738.64 | '
             || 'SIN EL CÓDIGO, criterio «libro» (el de fábrica): el mes de hoy sube 2738.64 (lo que dice el libro: lo que costó esa persona), de la '
             || 'última solo su día y su asiento, y Gastos trae la cuenta del oficial 2468.35 más, como Estados | '
             || 'SIN EL CÓDIGO, criterio «codigo»: lo dice (a_la_vista: no); los meses sin cifras pero con cuántas nóminas; lo que se debe, la bolsa y el '
             || 'monto de los cargos, «con el código del teléfono»; cifras de esta nómina en la tarjeta, en su acción o en las cuentas de la nómina de '
             || 'Gastos: ninguna; Gastos deja fuera las cuentas de la nómina (su total baja en lo de ellas) y lo dice; '
             || case when v_proy then 'la proyección no escribe aparte lo de la nómina y su saldo es el mismo que con el código'
                     else 'la proyección: no la hay en esta base' end
             || ' | con el código, los dos criterios dan lo mismo: sí | en llano, los dos sin el código: sí | al deshacerse, el criterio vuelve a: libro';
    v_obt := format('con el código: %s, costo %s (bruto %s + patrón %s), impuestos %s, neto %s, le quedan por pagar %s | '
                    'SIN EL CÓDIGO, criterio «%s» (el de fábrica): el mes de hoy sube %s (lo que dice el libro: lo que costó esa persona), de la '
                    'última %s, y Gastos trae la cuenta del oficial %s más, como Estados | '
                    'SIN EL CÓDIGO, criterio «%s»: %s; los meses %s; lo que se debe, la bolsa y el monto de los cargos, %s; cifras de esta nómina en '
                    'la tarjeta, en su acción o en las cuentas de la nómina de Gastos: %s; Gastos %s; %s | con el código, los dos criterios dan lo '
                    'mismo: %s | en llano, los dos sin el código: %s',
                    case when u ->> 'corrida' is distinct from c::text then 'otra nómina' when (u ->> 'personas')::int = 1 then '1 persona'
                         else (u ->> 'personas') || ' personas' end,
                    pg_temp.c16_mj(u -> 'costo'), pg_temp.c16_mj(u -> 'bruto'), pg_temp.c16_mj(u -> 'patron'), pg_temp.c16_mj(u -> 'impuestos'),
                    pg_temp.c16_mj(u -> 'neto'), pg_temp.c16_mj(u -> 'por_pagar'),
                    l1 ->> 'criterio',
                    pg_temp.c16_m((l1 -> 'meses' -> -1 ->> 'costo')::numeric - (n0 -> 'meses' -> -1 ->> 'costo')::numeric),
                    case when (l1 -> 'ultima' ->> 'con_codigo')::boolean is false and not (l1 -> 'ultima' ? 'costo') and not (l1 -> 'ultima' ? 'personas')
                              and l1 -> 'ultima' ->> 'dia_pago' = v_hoy::text then 'solo su día y su asiento' else 'algo más: ' || (l1 ->> 'ultima') end,
                    pg_temp.c16_m(coalesce((select (q ->> 'monto')::numeric from jsonb_array_elements(gl -> 'categorias') q where q ->> 'cuenta' = '6005'), 0)
                                  - coalesce((select (q ->> 'monto')::numeric from jsonb_array_elements(g0 -> 'categorias') q where q ->> 'cuenta' = '6005'), 0)),
                    k1 ->> 'criterio',
                    case when (k1 ->> 'a_la_vista')::boolean is false and k1 -> 'codigo' ->> 'texto' like '%con el código del teléfono%'
                         then 'lo dice (a_la_vista: no)' else 'no lo dice' end,
                    case when not exists (select 1 from jsonb_array_elements(k1 -> 'meses') m
                                           where jsonb_typeof(m -> 'costo') <> 'null' or jsonb_typeof(m -> 'sueldos') <> 'null'
                                              or jsonb_typeof(m -> 'patron') <> 'null' or jsonb_typeof(m -> 'nominas') <> 'number')
                              and (k1 -> 'meses' -> -1 ->> 'nominas')::int = (l1 -> 'meses' -> -1 ->> 'nominas')::int
                         then 'sin cifras pero con cuántas nóminas' else 'con cifras: ' || (k1 ->> 'meses') end,
                    case when (k1 -> 'debe' ->> 'a_la_vista')::boolean is false and not (k1 -> 'debe' ? 'monto') and not (k1 -> 'debe' ? 'cuentas')
                              and not (k1 -> 'debe' ? 'pagos') and k1 -> 'debe' ->> 'texto' like '%con el código del teléfono%'
                              and jsonb_typeof(k1 -> 'bolsa' -> 'monto') = 'null' and k1 -> 'bolsa' ->> 'texto' like '%con el código del teléfono%'
                              and not (k1 -> 'cargos' ? 'monto') and not (k1 -> 'cargos' -> 'devoluciones' ? 'monto')
                              and k1 -> 'cargos' -> 'n' = l1 -> 'cargos' -> 'n'
                         then '«con el código del teléfono»' else 'a la vista' end,
                    coalesce(v_cifras, 'ninguna'),
                    case when gk -> 'tapado' ->> 'texto' like '%código del teléfono%'
                              and not exists (select 1 from jsonb_array_elements(gk -> 'categorias') q
                                               where q ->> 'cuenta' = any (array(select jsonb_array_elements_text(gk -> 'tapado' -> 'cuentas'))))
                              and (gk2 ->> 'total')::numeric - (gk ->> 'total')::numeric = v_fuera and v_fuera >= 2738.64
                              and (gk2 -> 'tapado' is null or gk2 -> 'tapado' = 'null'::jsonb)
                         then 'deja fuera las cuentas de la nómina (su total baja en lo de ellas) y lo dice'
                         else format('no: fuera %s, total %s contra %s, tapado %s', v_fuera, gk ->> 'total', gk2 ->> 'total', gk ->> 'tapado') end,
                    case when not v_proy then 'la proyección: no la hay en esta base'
                         when (ck -> 'proyeccion' ->> 'nomina_a_la_vista')::boolean is false
                              and not exists (select 1 from jsonb_array_elements(ck -> 'proyeccion' -> 'meses') m where jsonb_typeof(m -> 'nomina') <> 'null')
                              and (select jsonb_agg(m -> 'saldo') from jsonb_array_elements(ck -> 'proyeccion' -> 'meses') m)
                                  = (select jsonb_agg(m -> 'saldo') from jsonb_array_elements(ck2 -> 'proyeccion' -> 'meses') m)
                              and (ck2 -> 'proyeccion' ->> 'nomina_a_la_vista')::boolean
                              and not exists (select 1 from jsonb_array_elements(ck -> 'proyeccion' -> 'no_incluye') q
                                               where q ->> 'clave' like 'nomina%' and jsonb_typeof(q -> 'monto') = 'number')
                           then 'la proyección no escribe aparte lo de la nómina y su saldo es el mismo que con el código'
                         else 'la proyección la escribe: ' || left(ck -> 'proyeccion' ->> 'meses', 300) end,
                    case when k2 - 'criterio' = l2 - 'criterio' and k2 ->> 'criterio' = 'codigo' and l2 ->> 'criterio' = 'libro' then 'sí' else 'no' end,
                    coalesce(pg_temp.c16_llano(jsonb_build_array(l1, k1, gk, ck)), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  -- (deshecho el bloque, el criterio es otra vez el de fábrica: lo dicen la función y la tarjeta)
  if v_obt not like 'omitida:%' and v_obt not like 'error %' then
    begin
      v_crit := fn_tablero_nomina_criterio();
      v_obt := v_obt || ' | al deshacerse, el criterio vuelve a: '
               || case when v_crit = pg_temp.c16_nom_tarjeta() ->> 'criterio' then v_crit else v_crit || ' (y la tarjeta dice otro)' end;
    exception when others then v_obt := v_obt || ' | al deshacerse: error ' || sqlstate || ': ' || sqlerrm;
    end;
    perform pg_temp.c16_ser('editor');
  end if;
  insert into _pruebas values (55, 'UNA NÓMINA DE UNA SOLA PERSONA, Y LOS DOS CRITERIOS (la decisión de seguridad): con el código, una persona y sus totales; SIN EL CÓDIGO y con el criterio de fábrica («libro»), lo que costó la nómina ese mes sale (lo que el libro dice, lo mismo que Estados: con una sola persona, lo que costó ella), de la nómina nada, y Gastos trae la cuenta del oficial como siempre; con el criterio «codigo» (la palabra de fn_tablero_nomina_criterio, cambiada dentro del bloque) y sin el código, la portada no escribe ninguna cifra de dinero de la nómina (la tarjeta, su acción, Gastos sin sus cuentas —y lo dice—, la proyección sin su renglón); con el código los dos criterios dan lo mismo; al deshacerse, vuelve a «libro»',
    coalesce(v_esp, 'con el criterio «libro» sale lo del libro; con «codigo», ninguna cifra'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 56. UNA NÓMINA IMPORTADA SIN POSTEAR (dos: una con día de pago hoy y otra
--     con día de pago mañana): no está en el libro (ni en los meses ni en lo
--     que se debe); con el código, la tarjeta dice cuántas esperan y desde
--     cuándo, lo pide atender (con alarma: el día de pago de una ya llegó) y
--     la acción rápida las cuenta; la de mañana es «la próxima» (importada:
--     sin lo que le queda por pagar) si la nómina no tiene otra antes. SIN
--     EL CÓDIGO: «no se sabe» (nulo), nunca «cero esperan», y lo dice.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); ca uuid; cb uuid; n0 jsonb; n jsonb; n1 jsonb; a jsonb; a1 jsonb; x jsonb; v_lib boolean;
begin
  if pg_temp.c16_nom_omitir(56, 'una nómina importada sin postear', 'con el código, cuántas esperan; sin él, «no se sabe»') then return; end if;
  begin
    n0 := pg_temp.c16_nom_tarjeta();
    perform pg_temp.c16_nom_sembrar();
    ca := pg_temp.c16_nom('una', v_hoy - 12, v_hoy - 4, v_hoy, false);
    cb := pg_temp.c16_nom('dos', v_hoy - 3, v_hoy - 1, v_hoy + 1, false);
    n := pg_temp.c16_nom_tarjeta();
    n1 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    select q into a from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()') -> 'lista') q where q ->> 'clave' = 'nomina';
    select q into a1 from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()', 'dueno_aal1') -> 'lista') q where q ->> 'clave' = 'nomina';
    select q into x from jsonb_array_elements(n -> 'atender') q where q ->> 'clave' = 'por_postear';
    v_lib := exists (select 1 from nomina_corridas k where k.estado = 'posteada');
    v_esp := pg_temp.c16_nom_espera()
             || ' || con el código: dos más por postear; no están en el libro (los meses y lo que se debe, igual); lo pide atender, con alarma (el día '
             || 'de pago de una ya llegó), en Nómina → Nóminas; su acción rápida, dos más y con alarma | la próxima: '
             || case when pg_temp.c16_nom_cual('proxima') = cb then 'la de mañana, importada (2 personas, costo 3588.54, sin lo que le queda por pagar)'
                     else 'otra que la nómina ya tenía antes (la de arriba)' end
             || ' | SIN EL CÓDIGO: por postear, no se sabe (ni un cero); no lo pide atender (pide entrar con el código); su acción rápida dice que se '
             || 'ven con el código'
             || case when v_lib then '' else '; y sin ninguna en el libro, dice que si alguna espera se ve con el código' end
             || ' | en llano: sí';
    v_obt := pg_temp.c16_nom_dice(n)
             || format(' || con el código: %s por postear; no están en el libro (los meses y lo que se debe, %s); %s; su acción rápida, %s | la próxima: %s'
                       ' | SIN EL CÓDIGO: por postear, %s; %s; su acción rápida %s%s | en llano: %s',
                       case when (n -> 'por_postear' ->> 'n')::int - (n0 -> 'por_postear' ->> 'n')::int = 2 then 'dos más'
                            else format('%s más', (n -> 'por_postear' ->> 'n')::int - (n0 -> 'por_postear' ->> 'n')::int) end,
                       case when n -> 'meses' = n0 -> 'meses' and n -> 'debe' = n0 -> 'debe' then 'igual' else 'cambian' end,
                       case when (x ->> 'alarma')::boolean and x -> 'ir' ->> 'sub' = 'nominas' and x -> 'ir' ->> 'pagina' = 'nomina'
                            then 'lo pide atender, con alarma (el día de pago de una ya llegó), en Nómina → Nóminas'
                            else 'no lo pide así: ' || coalesce(x::text, 'nada') end,
                       case when (a ->> 'n')::int = pg_temp.c16_nom_esperan() and (a ->> 'alarma')::boolean
                                 and (a ->> 'n')::int - (select (q ->> 'n')::int from jsonb_array_elements(pg_temp.c16_tc('acciones') -> 'lista') q
                                                          where q ->> 'clave' = 'nomina') = 2
                            then 'dos más y con alarma' else coalesce(a::text, 'no está') end,
                       case when n -> 'proxima' ->> 'corrida' = cb::text and n -> 'proxima' ->> 'estado' = 'importada'
                                 and jsonb_typeof(n -> 'proxima' -> 'por_pagar') = 'null' and n -> 'proxima' ->> 'dia_pago' = (v_hoy + 1)::text
                              then format('la de mañana, importada (%s personas, costo %s, sin lo que le queda por pagar)',
                                          n -> 'proxima' ->> 'personas', pg_temp.c16_mj(n -> 'proxima' -> 'costo'))
                            when n -> 'proxima' ->> 'corrida' is distinct from cb::text then 'otra que la nómina ya tenía antes (la de arriba)'
                            else 'la de mañana, pero ' || (n ->> 'proxima') end,
                       case when n1 ? 'por_postear' and jsonb_typeof(n1 -> 'por_postear') = 'null' then 'no se sabe (ni un cero)'
                            else coalesce(n1 ->> 'por_postear', 'sin la clave') end,
                       case when not exists (select 1 from jsonb_array_elements(n1 -> 'atender') q where q ->> 'clave' = 'por_postear')
                                 and exists (select 1 from jsonb_array_elements(n1 -> 'atender') q where q ->> 'clave' = 'codigo')
                            then 'no lo pide atender (pide entrar con el código)' else 'lo pide atender: ' || (n1 ->> 'atender') end,
                       case when a1 ->> 'detalle' like '%por postear se ven con el código del teléfono%' then 'dice que se ven con el código'
                            else 'dice: ' || coalesce(a1 ->> 'detalle', 'nada') end,
                       case when v_lib then ''
                            when (n1 ->> 'sin_nominas')::boolean and n1 ->> 'texto' like '%se ve con el código del teléfono%'
                              then '; y sin ninguna en el libro, dice que si alguna espera se ve con el código'
                            else '; y sin ninguna en el libro, dice: ' || coalesce(n1 ->> 'texto', 'nada') end,
                       coalesce(pg_temp.c16_llano(jsonb_build_array(n, n1, a, a1)), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (56, 'UNA NÓMINA IMPORTADA SIN POSTEAR (dos de prueba: una con día de pago hoy, otra mañana): no están en el libro (los meses y lo que se debe no cambian); con el código la tarjeta dice cuántas esperan y de qué días, lo pide atender con alarma (el día de pago de una ya llegó) y la acción rápida las cuenta; la de mañana es «la próxima» (importada: sus totales, sin lo que le queda por pagar) si la nómina no tenía otra antes; SIN EL CÓDIGO, «no se sabe» (nulo), nunca «cero esperan», y la tarjeta y la acción lo dicen',
    coalesce(v_esp, 'con el código, cuántas esperan; sin él, «no se sabe»'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 57. LA PROYECCIÓN DE LA CAJA CON LA NÓMINA (y lo que la tarjeta dice de
--     cuándo sale lo que se debe), paso a paso contra la cuenta hecha aquí:
--     (1) una nómina ya posteada con día de pago DESPUÉS de hoy: lo que dejó
--     por pagar sale ESE día (en su mes), y lo que ya se debía, hoy; (2)
--     Gusto cobra su neto por adelantado y el cargo se casa: no se resta
--     otra vez (lo que sale baja en eso, y el saldo al final de la
--     proyección no cambia); (3) otra con día de pago hoy: se debe hoy; (4)
--     se paga de más (queda a favor): no sale nada, y lo dice. En los
--     cuatro, lo que sale suma lo que se debe; la deuda de la nómina ya no
--     va en «no incluye»; y con la proyección de un solo mes, lo de un día
--     de pago de después va en «no incluye».
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_d date := pg_temp.c16('pago_despues')::date; v_banco text := pg_temp.c16('banco');
  v_hay_b boolean := pg_temp.c16('hay_banco') = 'true'; ca uuid; cb uuid; v_mov uuid; v_nom text; v_p numeric;
  e1 text; e2 text; e3 text; e4 text; o1 text; o2 text; o3 text; o4 text; v_suma text := 'sí'; n jsonb; cj jsonb; c1 jsonb; v_proy boolean;
  pe1 text; pe2 text; pe3 text; pe4 text; po1 text; po2 text; po3 text; po4 text; v_fin1 date; v_s2 jsonb; v_s3 jsonb; v_deuda text := 'ya no va en «no incluye»';
  v_m0 date := date_trunc('month', pg_temp.c16_hoy())::date;
begin
  if pg_temp.c16_nom_omitir(57, 'la proyección de la caja con la nómina', 'lo de una nómina posteada sale su día de pago; lo ya cobrado no se resta otra vez') then return; end if;
  if v_d is null then
    insert into _pruebas values (57, 'LA PROYECCIÓN DE LA CAJA CON LA NÓMINA', 'un día de pago después de hoy dentro de un mes abierto',
      'omitida: hoy es el último día de su mes y el mes que sigue no está abierto: no hay dónde postear una nómina con día de pago después de hoy', null);
    return;
  end if;
  begin
    cj := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    v_proy := not (cj ->> 'sin_apertura')::boolean;
    v_fin1 := (v_m0 + interval '1 month')::date - 1;
    perform pg_temp.c16_nom_sembrar();
    -- (1) una nómina ya posteada con día de pago después de hoy
    cb := pg_temp.c16_nom('dos', v_hoy - 3, v_hoy - 1, v_d);
    e1 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o1 := pg_temp.c16_nom_sale_de(n);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (1)'; end if;
    if v_proy then
      cj := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)'); c1 := pg_temp.c16_j('select public.fn_tablero_caja(12, 1)');
      if c1 -> 'proyeccion' is null or c1 -> 'proyeccion' = 'null'::jsonb then
        -- (hoy es fin de mes y este mes no tiene nada más con fecha: con un solo mes no hay proyección, ni su lista)
        pe1 := pg_temp.c16_nom_por_mes(3) || '; con un solo mes, no hay proyección';
        po1 := pg_temp.c16_nom_por_mes_de(cj) || '; con un solo mes, no hay proyección';
      else
        pe1 := pg_temp.c16_nom_por_mes(3) || '; con un solo mes, después de él: '
               || coalesce((select pg_temp.c16_m(sum(p.monto)) from pg_temp.c16_nom_pagos() p where p.fecha > v_fin1 having sum(p.monto) > 0), 'nada');
        po1 := pg_temp.c16_nom_por_mes_de(cj) || '; con un solo mes, después de él: '
               || coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(c1 -> 'proyeccion' -> 'no_incluye') q
                             where q ->> 'clave' = 'nomina_despues'), 'nada');
      end if;
      v_s2 := cj -> 'proyeccion' -> 'meses' -> -1 -> 'saldo';
      if exists (select 1 from jsonb_array_elements(cj -> 'proyeccion' -> 'no_incluye') q where q ->> 'clave' = 'deuda' and q ->> 'linea' = 'nomina_por_pagar') then
        v_deuda := 'sigue en «no incluye»';
      end if;
    end if;
    -- (2) Gusto cobra su neto (2,729.48) antes del día de pago, y el cargo se casa con ella
    if v_hay_b then
      v_mov := pg_temp.c16_nom_cargo('zz-c16-prueba-adelantado', v_hoy, 2729.48, 'GUSTO DES:NET ID:ZZ00000003');
      perform pg_temp.c16_nom_casar(v_mov, jsonb_build_array(jsonb_build_object('corrida', cb, 'cuenta', '2210', 'monto', '2729.48')));
      e2 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o2 := pg_temp.c16_nom_sale_de(n);
      if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (2)'; end if;
      if v_proy then
        cj := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
        v_s3 := cj -> 'proyeccion' -> 'meses' -> -1 -> 'saldo';
        pe2 := pg_temp.c16_nom_por_mes(3) || ', y el saldo al final de la proyección no cambia';
        po2 := pg_temp.c16_nom_por_mes_de(cj) || case when v_s3 = v_s2 then ', y el saldo al final de la proyección no cambia'
                                                     else format(', y el saldo al final de la proyección cambia (%s → %s)', v_s2, v_s3) end;
      end if;
    else
      e2 := 'no se prueba (el banco no está en esta base)'; o2 := e2; pe2 := e2; po2 := e2;
    end if;
    -- (3) otra nómina, con día de pago hoy: lo suyo se debe hoy
    ca := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    e3 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o3 := pg_temp.c16_nom_sale_de(n);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (3)'; end if;
    if v_proy then
      cj := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
      pe3 := pg_temp.c16_nom_por_mes(3); po3 := pg_temp.c16_nom_por_mes_de(cj);
    end if;
    -- (4) se paga de más: lo que se debe, más 100.00, sale del banco hoy (a mano): queda a favor
    v_p := (pg_temp.c16_nom_debe() ->> 'monto')::numeric;
    select m.cuenta into v_nom from v_estados_mapeo m
     where m.estado = 'balance' and m.linea = 'nomina_por_pagar'
       and m.cuenta <> all (array(select jsonb_array_elements_text(pg_temp.c16_nom_debe() -> 'reem'))) order by m.cuenta limit 1;
    perform pg_temp.c16_postear(v_hoy, 'la nómina pagada de más', jsonb_build_array(
              jsonb_build_object('cuenta', v_nom, 'monto', (v_p + 100)::text), jsonb_build_object('cuenta', v_banco, 'monto', (-(v_p + 100))::text)));
    e4 := 'nada (a favor 100.00, y lo dice)';
    n := pg_temp.c16_nom_tarjeta();
    o4 := pg_temp.c16_nom_sale_de(n) || format(' (a favor %s, y %s)', pg_temp.c16_m(-(n -> 'debe' ->> 'monto')::numeric),
                                               case when n -> 'debe' ->> 'texto' like '%a favor%' then 'lo dice' else 'no lo dice' end);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (4)'; end if;
    if v_proy then
      cj := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
      pe4 := pg_temp.c16_nom_por_mes(3) || '; a favor 100.00 en «no incluye»';
      po4 := case when cj -> 'proyeccion' is null or cj -> 'proyeccion' = 'null'::jsonb then 'sin proyección: ' || coalesce(cj ->> 'sin_proyeccion', '?')
                  else pg_temp.c16_nom_por_mes_de(cj) || '; a favor '
                       || coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(cj -> 'proyeccion' -> 'no_incluye') q
                                     where q ->> 'clave' = 'nomina_a_favor'), 'nada') || ' en «no incluye»' end;
      -- (sin nada más con fecha en la base, sin la nómina no queda nada que proyectar: entonces no hay proyección, y lo dice)
      if (cj -> 'proyeccion' is null or cj -> 'proyeccion' = 'null'::jsonb) and cj ->> 'sin_proyeccion' like '%ni de la nómina%' then
        po4 := pe4;
      end if;
    end if;
    v_esp := format('(1) una nómina posteada con día de pago después de hoy (%s): sale %s | (2) Gusto ya cobró su neto y está casado: sale %s | '
                    '(3) otra con día de pago hoy: sale %s | (4) pagada de más: sale %s | lo que sale suma lo que se debe, y sus cuentas también: sí',
                    v_d, e1, e2, e3, e4)
             || case when v_proy
                     then format(' || en la proyección, lo que sale por la nómina cada mes: (1) %s | (2) %s | (3) %s | (4) %s | la deuda de la nómina '
                                 'ya no va en «no incluye»', pe1, pe2, pe3, pe4)
                     else ' || en la proyección: no la hay (la apertura todavía no está en el libro)' end;
    v_obt := format('(1) una nómina posteada con día de pago después de hoy (%s): sale %s | (2) Gusto ya cobró su neto y está casado: sale %s | '
                    '(3) otra con día de pago hoy: sale %s | (4) pagada de más: sale %s | lo que sale suma lo que se debe, y sus cuentas también: %s',
                    v_d, o1, o2, o3, o4, v_suma)
             || case when v_proy
                     then format(' || en la proyección, lo que sale por la nómina cada mes: (1) %s | (2) %s | (3) %s | (4) %s | la deuda de la nómina '
                                 '%s', po1, po2, po3, po4, v_deuda)
                     else ' || en la proyección: no la hay (la apertura todavía no está en el libro)' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (57, 'LA PROYECCIÓN DE LA CAJA CON LA NÓMINA, y lo que la tarjeta dice de cuándo sale lo que se debe, paso a paso contra la cuenta hecha aquí: una nómina ya posteada con día de pago DESPUÉS de hoy sale ese día (en su mes) y lo que ya se debía, hoy; Gusto cobra su neto por adelantado y se casa: NO SE RESTA OTRA VEZ (el saldo al final de la proyección no cambia); otra con día de pago hoy se debe hoy; pagada de más, no sale nada (a favor, y lo dice); lo que sale suma siempre lo que se debe; la deuda de la nómina ya no va en «no incluye», y con un solo mes de proyección lo de un día de pago de después sí',
    coalesce(v_esp, 'lo de una nómina posteada sale su día de pago; lo ya cobrado no se resta otra vez'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 58. SIN LA NÓMINA DE c15 (en una base que no la tiene; o, si la tiene,
--     escondiendo su vista de las nóminas dentro de un bloque que se
--     deshace): todo como antes. La tarjeta dice que la nómina no está
--     pegada (sin error), su acción rápida no está disponible, las demás
--     tarjetas contestan lo mismo, y la proyección no resta la nómina: lo
--     que el libro dice que se debe de ella va en «no incluye», con su
--     monto, y la línea a la vista dice que no cuenta la nómina.
do $$
declare
  v_obt text; v_esp text; t jsonb; t0 jsonb := pg_temp.c16('t')::jsonb; a jsonb; p jsonb; v_c15 boolean := pg_temp.c16_hay_c15(); v_nom numeric; v_otras int;
begin
  if pg_temp.c16_omitir(58, 'sin la nómina de c15', 'todo como antes') then return; end if;
  begin
    if v_c15 then
      execute 'alter view public.v_nomina_corridas rename to v_nomina_corridas_c16_fuera';
    end if;
    t := pg_temp.c16_t();
    select x into a from jsonb_array_elements(t -> 'acciones' -> 'lista') x where x ->> 'clave' = 'nomina';
    p := nullif(t -> 'caja' -> 'proyeccion', 'null'::jsonb);
    v_nom := -pg_temp.c16_libro(array(select m.cuenta from v_estados_mapeo m where m.estado = 'balance' and m.linea = 'nomina_por_pagar'), date 'infinity');
    -- (las otras tarjetas —todas menos la nómina, las acciones y la caja—, iguales que con ella; los bancos, por sus totales)
    select count(*) into v_otras from jsonb_array_elements_text(t0 -> 'tarjetas') k
     where k not in ('nomina', 'acciones', 'caja')
       and case when k = 'bancos' then (t -> k -> 'totales') is not distinct from (t0 -> k -> 'totales')
                else (t -> k) - 'ms' is not distinct from (t0 -> k) - 'ms' end;
    v_esp := 'las capas: la nómina (c15) no está | su tarjeta: dice que la nómina no está pegada, sin error | su acción rápida: no disponible (c15) | '
             || 'las otras 13 tarjetas: como con ella | la caja: '
             || case when p is null then 'sin proyección en esta base (como antes)'
                     else format('la proyección no resta la nómina (ningún mes la trae), lo que se debe de ella va en «no incluye» (%s) y la línea a la '
                                 'vista dice que no cuenta la nómina', case when v_nom <> 0 then pg_temp.c16_m(v_nom) else 'nada' end) end
             || ' | en llano: sí';
    v_obt := format('las capas: %s | su tarjeta: %s | su acción rápida: %s | las otras 13 tarjetas: %s | la caja: %s | en llano: %s',
                    case when (t -> 'capas' ->> 'c15')::boolean is false then 'la nómina (c15) no está' else 'dicen que c15 está' end,
                    case when (t -> 'nomina' ->> 'ok')::boolean is false and t -> 'nomina' ->> 'falta' = 'c15' and t -> 'nomina' ->> 'codigo' is null
                              and t -> 'nomina' ->> 'motivo' like '%no está pegada%' then 'dice que la nómina no está pegada, sin error'
                         else coalesce(left(t ->> 'nomina', 300), 'no está') end,
                    case when (a ->> 'disponible')::boolean is false and a ->> 'falta' = 'c15' then 'no disponible (c15)' else coalesce(a::text, 'no está') end,
                    case when v_otras = 13 then 'como con ella' else format('%s iguales', v_otras) end,
                    case when p is null then case when v_c15 and t0 -> 'caja' -> 'proyeccion' is not null and t0 -> 'caja' -> 'proyeccion' <> 'null'::jsonb
                                                       and t -> 'caja' ->> 'sin_proyeccion' not like '%ni de impuestos en esos meses%'
                                                  then 'sin proyección: ' || coalesce(t -> 'caja' ->> 'sin_proyeccion', '?')
                                                  else 'sin proyección en esta base (como antes)' end
                         else format('la proyección %s, lo que se debe de ella va en «no incluye» (%s) y la línea a la vista %s',
                                     case when not exists (select 1 from jsonb_array_elements(p -> 'meses') m where jsonb_typeof(m -> 'nomina') <> 'null')
                                               and jsonb_typeof(p -> 'nomina_a_la_vista') = 'null'
                                               and not exists (select 1 from jsonb_array_elements(p -> 'no_incluye') q where q ->> 'clave' like 'nomina%')
                                          then 'no resta la nómina (ningún mes la trae)' else 'trae la nómina' end,
                                     coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(p -> 'no_incluye') q
                                                where q ->> 'clave' = 'deuda' and q ->> 'linea' = 'nomina_por_pagar'), 'nada'),
                                     case when p ->> 'aviso' like '%No cuenta la nómina, la renta%' then 'dice que no cuenta la nómina' else 'dice otra cosa' end) end,
                    coalesce(pg_temp.c16_llano(jsonb_build_array(t -> 'nomina', a, t -> 'caja')), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (58, 'SIN LA NÓMINA DE c15 (en una base que no la tiene; si la tiene, con su vista de las nóminas escondida dentro de un bloque que se deshace): todo como antes. La tarjeta dice que la nómina no está pegada (sin error), su acción rápida no está disponible, las otras tarjetas contestan lo mismo, y la proyección de la caja no resta la nómina: lo que el libro dice que se debe de ella va en «no incluye» con su monto, y la línea a la vista dice que no cuenta la nómina',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 59. EL EQUIPO Y LOS DE FUERA, CON UNA NÓMINA EN LA BASE: alguien del equipo
--     con su propia sesión y su código (aquí, una de las personas de la
--     nómina de prueba) recibe 42501 en la tarjeta de la nómina, en cada una
--     de sus piezas y en el tablero pidiendo solo la nómina; anon y
--     service_role, igual (ni les entra la llamada). El dueño, sí.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; v_eq text; v_an text; v_sr text; v_du text;
  c_llamadas constant text[] := array['select public.fn_tablero_nomina()', 'select public.fn_tablero_nomina_estado()',
    'select public.fn_tablero_nomina_debe()', 'select count(*) from public.fn_tablero_nomina_pagos()', 'select public.fn_tablero_nomina_tapada()',
    'select public.fn_tablero(''{"tarjetas": ["nomina"]}'')', 'select public.fn_tablero(''{"tarjetas": ["acciones", "caja", "gastos"]}'')'];
begin
  if pg_temp.c16_nom_omitir(59, 'el equipo y los de fuera, con una nómina en la base', '42501') then return; end if;
  v_esp := format('una persona de la nómina, con su sesión y su código, en las %1$s llamadas: 42501 | anon: 42501 | service_role: 42501 | '
                  'el dueño sin el código: ok | el dueño con el código: ok', cardinality(c_llamadas));
  begin
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'n1'), ','), ''), '?') into v_eq from unnest(c_llamadas) x;
    select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'anon'), ','), ''), '?') into v_an from unnest(c_llamadas) x;
    select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'service_role'), ','), ''), '?') into v_sr from unnest(c_llamadas) x;
    select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'dueno_aal1'), ','), ''), '?') into v_du from unnest(c_llamadas) x;
    v_obt := format('una persona de la nómina, con su sesión y su código, en las %s llamadas: %s | anon: %s | service_role: %s | '
                    'el dueño sin el código: %s | el dueño con el código: %s', cardinality(c_llamadas), v_eq, v_an, v_sr, v_du,
                    (select coalesce(nullif(string_agg(distinct pg_temp.c16_estado(x, 'dueno'), ','), ''), '?') from unnest(c_llamadas) x));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (59, 'EL EQUIPO Y LOS DE FUERA, CON UNA NÓMINA EN LA BASE: una persona de esa misma nómina, con su propia sesión y su código del teléfono, recibe 42501 en la tarjeta de la nómina, en cada una de sus piezas y en el tablero (pidiendo la nómina, o las acciones, la caja y los gastos); anon y service_role, igual; el dueño entra, con el código y sin él',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 60. LA NÓMINA, EN LLANO Y SIN NADIE: con una nómina posteada, otra
--     importada y un cargo de Gusto esperando, ningún texto de la portada
--     (con el código y sin él) dice un nombre de la base, un código, una
--     fecha AAAA-MM-DD ni jerga (lo mismo que mira la 35), y la portada no
--     nombra a ninguna persona de la nómina, ni con el código.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); c uuid; t2 jsonb; t1 jsonb; v_mal text;
  v_hay_b boolean := pg_temp.c16('hay_banco') = 'true';
begin
  if pg_temp.c16_nom_omitir(60, 'la nómina, en llano y sin nadie', 'ningún texto con jerga ni con el nombre de nadie') then return; end if;
  v_esp := 'con el código: en llano, y sin el nombre de nadie | sin el código: en llano, y sin el nombre de nadie | lo que pide atender, cada cosa con '
           || 'su enlace a una página: sí';
  begin
    perform pg_temp.c16_nom_sembrar();
    c := pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    perform pg_temp.c16_nom('una', v_hoy - 3, v_hoy - 1, v_hoy, false);
    if v_hay_b then
      perform pg_temp.c16_nom_cargo('zz-c16-prueba-llano', v_hoy, 151.22, 'GUSTO DES:TAX ID:ZZ00000004');
    end if;
    t2 := pg_temp.c16_t();
    t1 := pg_temp.c16_j($q$select public.fn_tablero('{"tope_ms": 0}'::jsonb)$q$, 'dueno_aal1');
    select string_agg(format('%s (%s)', x ->> 'clave', coalesce(x ->> 'ir', 'sin enlace')), ', ') into v_mal
      from (select jsonb_array_elements(t2 -> 'nomina' -> 'atender') as x union all select jsonb_array_elements(t1 -> 'nomina' -> 'atender')) q
     where coalesce(x -> 'ir' ->> 'pagina', '') not in ('nomina', 'conexiones') or coalesce(x ->> 'texto', '') = ''
        or (x -> 'ir' ->> 'pagina' = 'nomina' and coalesce(x -> 'ir' ->> 'sub', '') not in ('nominas', 'cargos', 'ajustes'));
    v_obt := format('con el código: %s, y %s | sin el código: %s, y %s | lo que pide atender, cada cosa con su enlace a una página: %s',
                    coalesce('NO: ' || pg_temp.c16_llano(t2), 'en llano'),
                    case when t2::text like '%ZZ C16 Prueba%' then 'NOMBRA a una persona de la nómina' else 'sin el nombre de nadie' end,
                    coalesce('NO: ' || pg_temp.c16_llano(t1), 'en llano'),
                    case when t1::text like '%ZZ C16 Prueba%' then 'NOMBRA a una persona de la nómina' else 'sin el nombre de nadie' end,
                    case when jsonb_array_length(t2 -> 'nomina' -> 'atender') > 0 and jsonb_array_length(t1 -> 'nomina' -> 'atender') > 0 and v_mal is null
                         then 'sí' else 'no: ' || coalesce(v_mal, 'no pide nada') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (60, 'LA NÓMINA, EN LLANO Y SIN NADIE: con una nómina posteada, otra importada sin postear y un cargo de Gusto esperando, ningún texto de la portada (con el código y sin él) dice un nombre de la base, un código, una fecha AAAA-MM-DD ni jerga (lo que mira la 35); la portada no nombra a ninguna persona de la nómina, ni con el código; y lo que pide atender lleva cada cosa a su página',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 61. SI LO DE LA NÓMINA NO SE DEJA LEER (a la API se le quita el permiso de
--     leer los archivos de la nómina, dentro de un bloque que se deshace):
--     la tarjeta de la nómina dice que no se pudo leer, con su código
--     (42501); su acción rápida dice que no se pudo leer (sin número), las
--     demás acciones siguen como siempre y las otras tarjetas contestan.
do $$
declare
  v_obt text; v_esp text; t jsonb; t0 jsonb := pg_temp.c16('t')::jsonb; a jsonb;
begin
  if pg_temp.c16_nom_omitir(61, 'si lo de la nómina no se deja leer', 'su tarjeta lo dice y las demás siguen', false) then return; end if;
  v_esp := 'la tarjeta de la nómina: no se pudo leer, con 42501 | su acción rápida: dice que no se pudo leer, sin número | las demás acciones: '
           || 'las 6, como siempre | las otras 15 tarjetas: contestan o dicen qué capa falta';
  begin
    execute 'revoke select on public.nomina_archivos from authenticated';
    t := pg_temp.c16_t();
    select x into a from jsonb_array_elements(t -> 'acciones' -> 'lista') x where x ->> 'clave' = 'nomina';
    v_obt := format('la tarjeta de la nómina: %s | su acción rápida: %s | las demás acciones: %s | las otras 15 tarjetas: %s',
                    case when (t -> 'nomina' ->> 'ok')::boolean is false and t -> 'nomina' ->> 'motivo' like 'Esta tarjeta no se pudo leer%'
                              and t -> 'nomina' ->> 'codigo' = '42501' then 'no se pudo leer, con 42501' else left(t ->> 'nomina', 300) end,
                    case when (a ->> 'disponible')::boolean and a ->> 'detalle' like '%no se pudo leer%' and jsonb_typeof(a -> 'n') = 'null'
                         then 'dice que no se pudo leer, sin número' else coalesce(a::text, 'no está') end,
                    case when (select count(*) from jsonb_array_elements(t -> 'acciones' -> 'lista') x
                                where x ->> 'clave' <> 'nomina'
                                  and x in (select y from jsonb_array_elements(t0 -> 'acciones' -> 'lista') y)) = 6
                              and jsonb_array_length(t -> 'acciones' -> 'lista') = 7 then 'las 6, como siempre'
                         else 'otras: ' || left(t -> 'acciones' ->> 'lista', 300) end,
                    case when (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k
                                where k <> 'nomina' and ((t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null)) = 15
                         then 'contestan o dicen qué capa falta'
                         else 'fallan: ' || coalesce((select string_agg(k, ', ') from jsonb_array_elements_text(t -> 'tarjetas') k
                                                      where k <> 'nomina' and not ((t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null)), '?') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (61, 'SI LO DE LA NÓMINA NO SE DEJA LEER (a la API se le quita el permiso de leer los archivos de la nómina, dentro de un bloque que se deshace): la tarjeta de la nómina dice que no se pudo leer, con su código (42501); su acción rápida dice que no se pudo leer, sin número; las demás acciones siguen como siempre y las otras tarjetas contestan',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LOS ARREGLOS DE LA VERIFICACIÓN DE LA FASE 11c (14-nov, marca 2026111403;
-- de la 62 a la 65). Cada una falla con el c16 de antes y pasa con el de
-- hoy. En su bloque que se deshace (MXT00).
-- =====================================================================
-- 62. LO QUE GUSTO YA COBRÓ SE LE QUITA A LA NÓMINA QUE PAGÓ (no a lo más
--     viejo de la cuenta). Por el camino de verdad (c15: importar, postear,
--     casar): la nómina A, con día de pago HOY, cuyo neto se pagó con un
--     cheque de papel que nadie ha cobrado (sus impuestos sí: casados); y la
--     nómina B, con día de pago MAÑANA, ya posteada. (1) Gusto cobra hoy el
--     neto de B y se casa: lo que A dejó sin cobrar (2,011.52, en la misma
--     cuenta que el neto de B) sale HOY, y a B le queda lo demás (859.06) su
--     día de pago. Antes, el neto cobrado de B «pagaba» el cheque viejo de A
--     y la portada decía que hoy no salía nada de eso y que mañana salía
--     todo: en la tarjeta, y en el mes de la proyección de la caja. (2) Se
--     cobra por fin el cheque de A (un cargo que NO es de Gusto, casado «por
--     fuera de Gusto» con su nota): hoy baja en eso; lo de B, igual. (3) El
--     neto de B se des-casa en la Bandeja (su asiento se reversa): lo de B
--     vuelve a deberse entero su día. En cada paso, lo que c16 dice (del
--     libro) es lo que la nómina sabe de cada una (c16_nom_pagos: sus
--     partes); y sin el código del teléfono dice lo mismo.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_d date := pg_temp.c16('pago_despues')::date;
  ca uuid; cb uuid; v_nb text; m_tax uuid; m_net uuid; m_chk uuid; n0 jsonb; n jsonb; n1 jsonb; v_h0 numeric;
  e1 text; e2 text; e3 text; o1 text; o2 text; o3 text; x1 text; x2 text; x3 text; v_sin text; v_suma text := 'sí';
begin
  if pg_temp.c16_nom_omitir(62, 'lo que Gusto ya cobró se le quita a la nómina que pagó', 'lo viejo sale hoy; lo de la que viene, su día de pago', true, true) then return; end if;
  if v_d is null then
    insert into _pruebas values (62, 'LO QUE GUSTO YA COBRÓ SE LE QUITA A LA NÓMINA QUE PAGÓ', 'un día de pago después de hoy dentro de un mes abierto',
      'omitida: hoy es el último día de su mes y el mes que sigue no está abierto: no hay dónde postear una nómina con día de pago después de hoy', null);
    return;
  end if;
  begin
    n0 := pg_temp.c16_nom_tarjeta();
    v_h0 := coalesce((n0 -> 'debe' ->> 'a_hoy')::numeric, 0);
    perform pg_temp.c16_nom_sembrar();
    -- la nómina A (día de pago hoy): sus impuestos, cobrados por Gusto y casados; su neto (un cheque de papel), sin cobrar
    ca := pg_temp.c16_nom('una', v_hoy - 12, v_hoy - 4, v_hoy);
    m_tax := pg_temp.c16_nom_cargo('zz-c16-prueba-62-tax', v_hoy, 727.12, 'GUSTO DES:TAX ID:ZZ00000004');
    perform pg_temp.c16_nom_casar(m_tax, jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2220', 'monto', '645.66'),
                                                           jsonb_build_object('corrida', ca, 'cuenta', '2225', 'monto', '14.81'),
                                                           jsonb_build_object('corrida', ca, 'cuenta', '2230', 'monto', '66.65')));
    -- la nómina B (día de pago mañana), ya posteada; (1) Gusto cobra hoy su neto, y se casa con ella
    cb := pg_temp.c16_nom('dos', v_hoy - 3, v_hoy - 1, v_d);
    select k.asiento_numero into v_nb from nomina_corridas k where k.id = cb;
    m_net := pg_temp.c16_nom_cargo('zz-c16-prueba-62-net', v_hoy, 2729.48, 'GUSTO DES:NET ID:ZZ00000005');
    perform pg_temp.c16_nom_casar(m_net, jsonb_build_array(jsonb_build_object('corrida', cb, 'cuenta', '2210', 'monto', '2729.48')));
    e1 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o1 := pg_temp.c16_nom_sale_de(n);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (1)'; end if;
    x1 := format('hoy %s más que antes de la prueba; a la de mañana le quedan %s',
                 pg_temp.c16_m((n -> 'debe' ->> 'a_hoy')::numeric - v_h0),
                 coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(n -> 'debe' -> 'pagos') q where q ->> 'asiento' = v_nb), 'nada'));
    n1 := pg_temp.c16_nom_tarjeta('dueno_aal1');
    v_sin := case when n1 -> 'debe' -> 'pagos' = n -> 'debe' -> 'pagos' and n1 -> 'debe' -> 'a_hoy' = n -> 'debe' -> 'a_hoy' then 'lo mismo' else 'otra cosa' end;
    -- (2) el cheque de papel de A se cobra: un cargo que no es de Gusto, casado «por fuera de Gusto» con su nota
    m_chk := pg_temp.c16_nom_cargo('zz-c16-prueba-62-chk', v_hoy, 2011.52, 'CHECK 1041 ZZ');
    perform pg_temp.c16_ser('dueno');
    perform fn_nomina_cargo_casar(m_chk, jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2210', 'monto', '2011.52')),
                                  'C16 PRUEBA: el cheque de papel de la nómina');
    perform set_config('mx_nomina.escribe', '', true);
    perform pg_temp.c16_ser('editor');
    e2 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o2 := pg_temp.c16_nom_sale_de(n);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (2)'; end if;
    x2 := format('hoy %s más que antes de la prueba; a la de mañana le quedan %s',
                 pg_temp.c16_m((n -> 'debe' ->> 'a_hoy')::numeric - v_h0),
                 coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(n -> 'debe' -> 'pagos') q where q ->> 'asiento' = v_nb), 'nada'));
    -- (3) el neto de B se des-casa en la Bandeja del banco (su asiento se reversa)
    perform pg_temp.c16_ser('dueno');
    perform fn_banco_descasar(m_net, 'C16 PRUEBA: se des-casa en la Bandeja');
    perform pg_temp.c16_ser('editor');
    e3 := pg_temp.c16_nom_pagos_txt(); n := pg_temp.c16_nom_tarjeta(); o3 := pg_temp.c16_nom_sale_de(n);
    if pg_temp.c16_nom_suma(n) <> 'sí' then v_suma := 'no (3)'; end if;
    x3 := format('hoy %s más que antes de la prueba; a la de mañana le quedan %s',
                 pg_temp.c16_m((n -> 'debe' ->> 'a_hoy')::numeric - v_h0),
                 coalesce((select pg_temp.c16_mj(q -> 'monto') from jsonb_array_elements(n -> 'debe' -> 'pagos') q where q ->> 'asiento' = v_nb), 'nada'));
    v_esp := format('(1) el cheque de papel de la nómina de hoy sin cobrar, y el neto de la de mañana (%s) ya cobrado por Gusto y casado: sale %s '
                    '[hoy 2011.52 más que antes de la prueba; a la de mañana le quedan 859.06] | sin el código del teléfono: lo mismo | '
                    '(2) cobrado el cheque (casado «por fuera de Gusto»): sale %s [hoy 0.00 más que antes de la prueba; a la de mañana le quedan '
                    '859.06] | (3) des-casado en la Bandeja el neto de la de mañana: sale %s [hoy 0.00 más que antes de la prueba; a la de mañana '
                    'le quedan 3588.54] | lo que sale suma lo que se debe: sí', v_d, e1, e2, e3);
    v_obt := format('(1) el cheque de papel de la nómina de hoy sin cobrar, y el neto de la de mañana (%s) ya cobrado por Gusto y casado: sale %s '
                    '[%s] | sin el código del teléfono: %s | (2) cobrado el cheque (casado «por fuera de Gusto»): sale %s [%s] | (3) des-casado '
                    'en la Bandeja el neto de la de mañana: sale %s [%s] | lo que sale suma lo que se debe: %s', v_d, o1, x1, v_sin, o2, x2, o3, x3, v_suma);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (62, 'LO QUE GUSTO YA COBRÓ SE LE QUITA A LA NÓMINA QUE PAGÓ, no a lo más viejo de la cuenta (por el camino de la nómina: importar, postear y casar): con el cheque de papel de la nómina de hoy sin cobrar y el neto de la de mañana ya cobrado por Gusto y casado, lo viejo sale HOY y a la de mañana le queda lo demás su día de pago (antes: hoy nada, y mañana todo); cobrado el cheque («por fuera de Gusto»), hoy baja en eso; des-casado el neto en la Bandeja, vuelve a deberse su día; en cada paso lo que dice la portada —del libro, con y sin el código del teléfono— es lo que la nómina sabe de cada una',
    coalesce(v_esp, 'lo viejo sale hoy; lo de la que viene, su día de pago'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 63. LO QUE NO ES DE LA NÓMINA DE GUSTO NO VA EN LO QUE SE DEBE DE ELLA. El
--     renglón «nómina por pagar» del Balance trae cuentas que ninguna nómina
--     paga: las vacaciones devengadas (2215), un devengo que el CPA postea a
--     mano. Con 400.00 devengados ahí (a mano, dentro del bloque): lo que se
--     debe de la nómina NO cambia, ni cuándo sale, ni lo que la proyección
--     resta cada mes; van APARTE en la tarjeta («otras», con su texto), lo
--     que dice el Balance sube 400.00, y la proyección los sigue listando en
--     lo que no incluye (sin fecha de pago). Antes: «se deben de la nómina»,
--     «Gusto lo cobra», y 400.00 menos de caja este mes.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_cta text; n0 jsonb; n jsonb; c0 jsonb; c jsonb; d jsonb; v_proy boolean;
begin
  if pg_temp.c16_nom_omitir(63, 'lo que no es de la nómina de Gusto no va en lo que se debe de ella', 'las vacaciones devengadas, aparte', false) then return; end if;
  if pg_temp.c16('mes') is null then
    insert into _pruebas values (63, 'LO QUE NO ES DE LA NÓMINA DE GUSTO NO VA EN LO QUE SE DEBE DE ELLA', 'el mes de hoy, abierto',
      'omitida: el mes de hoy no está abierto: no hay dónde postear el devengo de prueba', null);
    return;
  end if;
  -- (una cuenta del renglón que la nómina no usa: ni en su mapeo de columnas, ni en un journal suyo, ni la de reembolsos)
  select m.cuenta into v_cta
    from v_estados_mapeo m
   where m.estado = 'balance' and m.linea = 'nomina_por_pagar'
     and m.cuenta <> all (array(select jsonb_array_elements_text(pg_temp.c16_nom_debe() -> 'nom')))
     and m.cuenta <> all (array(select jsonb_array_elements_text(pg_temp.c16_nom_debe() -> 'reem')))
   order by m.cuenta limit 1;
  if v_cta is null then
    insert into _pruebas values (63, 'LO QUE NO ES DE LA NÓMINA DE GUSTO NO VA EN LO QUE SE DEBE DE ELLA', 'una cuenta de «nómina por pagar» que la nómina no use',
      'omitida: en esta base todas las cuentas del renglón «nómina por pagar» las usa la nómina (su mapeo de columnas): no hay ninguna aparte', null);
    return;
  end if;
  begin
    n0 := pg_temp.c16_nom_tarjeta();
    c0 := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    v_proy := c0 -> 'proyeccion' is not null and c0 -> 'proyeccion' <> 'null'::jsonb;
    perform pg_temp.c16_postear(v_hoy, 'unas vacaciones devengadas', jsonb_build_array(
              jsonb_build_object('cuenta', '6100', 'monto', '400.00'), jsonb_build_object('cuenta', v_cta, 'monto', '-400.00')));
    n := pg_temp.c16_nom_tarjeta();
    c := pg_temp.c16_j('select public.fn_tablero_caja(12, 3)');
    select x into d from jsonb_array_elements(c -> 'proyeccion' -> 'no_incluye') x where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar';
    v_esp := 'con 400.00 devengados a mano en una cuenta de «nómina por pagar» que la nómina no usa: lo que se debe de la nómina, igual; cuándo '
             || 'sale, igual; va aparte, 400.00 más, con su cuenta y dicho en llano; lo que dice el Balance, 400.00 más; sus cifras cuadran: sí | '
             || case when v_proy then 'la proyección de la caja: lo que sale por la nómina cada mes, igual; en lo que no incluye, 400.00 más, con su '
                                      'cuenta y sin las de la nómina'
                     else 'la proyección de la caja: no la hay en esta base (sin la apertura en el libro, o sin nada con fecha)' end;
    v_obt := format('con 400.00 devengados a mano en una cuenta de «nómina por pagar» que la nómina no usa: lo que se debe de la nómina, %s; cuándo '
                    'sale, %s; va aparte, %s más, %s; lo que dice el Balance, %s más; sus cifras cuadran: %s | %s',
                    case when n -> 'debe' -> 'monto' = n0 -> 'debe' -> 'monto' and n -> 'debe' -> 'cuentas' = n0 -> 'debe' -> 'cuentas' then 'igual'
                         else format('otro (%s → %s)', n0 -> 'debe' ->> 'monto', n -> 'debe' ->> 'monto') end,
                    case when n -> 'debe' -> 'pagos' = n0 -> 'debe' -> 'pagos' and n -> 'debe' -> 'a_hoy' = n0 -> 'debe' -> 'a_hoy' then 'igual' else 'otro' end,
                    pg_temp.c16_m(coalesce((nullif(n -> 'debe' -> 'otras', 'null'::jsonb) ->> 'monto')::numeric, 0)
                                  - coalesce((nullif(n0 -> 'debe' -> 'otras', 'null'::jsonb) ->> 'monto')::numeric, 0)),
                    case when exists (select 1 from jsonb_array_elements(n -> 'debe' -> 'otras' -> 'cuentas') q where q ->> 'cuenta' = v_cta)
                              and n -> 'debe' -> 'otras' ->> 'texto' like '%' || v_cta || '%'
                              and n -> 'debe' -> 'otras' ->> 'texto' like '%no va en lo que se debe de la nómina%'
                              and pg_temp.c16_llano(n -> 'debe' -> 'otras') is null
                         then 'con su cuenta y dicho en llano' else 'sin decirlo bien: ' || coalesce(n -> 'debe' ->> 'otras', 'nada') end,
                    pg_temp.c16_m((n -> 'debe' ->> 'libro')::numeric - (n0 -> 'debe' ->> 'libro')::numeric),
                    pg_temp.c16_nom_suma(n),
                    case when not v_proy then 'la proyección de la caja: no la hay en esta base (sin la apertura en el libro, o sin nada con fecha)'
                         else format('la proyección de la caja: lo que sale por la nómina cada mes, %s; en lo que no incluye, %s más, %s',
                                     case when pg_temp.c16_nom_por_mes_de(c) = pg_temp.c16_nom_por_mes_de(c0) then 'igual'
                                          else format('otro (%s → %s)', pg_temp.c16_nom_por_mes_de(c0), pg_temp.c16_nom_por_mes_de(c)) end,
                                     pg_temp.c16_m(coalesce((d ->> 'monto')::numeric, 0)
                                                   - coalesce((select (x ->> 'monto')::numeric from jsonb_array_elements(c0 -> 'proyeccion' -> 'no_incluye') x
                                                                where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar'), 0)),
                                     case when d -> 'cuentas' ? v_cta
                                               and not exists (select 1 from jsonb_array_elements_text(d -> 'cuentas') q
                                                                where q = any (array(select jsonb_array_elements_text(pg_temp.c16_nom_debe() -> 'nom'))))
                                          then 'con su cuenta y sin las de la nómina' else 'con otras cuentas: ' || coalesce(d ->> 'cuentas', 'ninguna') end) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (63, 'LO QUE NO ES DE LA NÓMINA DE GUSTO NO VA EN LO QUE SE DEBE DE ELLA: el renglón «nómina por pagar» del Balance trae cuentas que ninguna nómina paga (las vacaciones devengadas, un devengo del CPA a mano). Con 400.00 devengados ahí, lo que se debe de la nómina no cambia, ni cuándo sale, ni lo que la proyección resta cada mes; van aparte en la tarjeta, dichos en llano, el Balance sube en eso, y la proyección los sigue listando en lo que no incluye (antes: «se deben de la nómina, Gusto lo cobra», y 400.00 menos de caja este mes)',
    coalesce(v_esp, 'las vacaciones devengadas, aparte'), v_obt, coalesce(v_obt = v_esp, false));
end $$;

-- 64. LO LIGERO: LA PORTADA NO ARMA LA PROPUESTA DE NINGÚN CARGO DE GUSTO NI
--     CORRE LOS AVISOS DE LA NÓMINA. Con un cargo de Gusto esperando en la
--     Bandeja, y la propuesta de los cargos de la nómina (c15) rota a
--     propósito dentro del bloque (una función que solo da un error): la
--     tarjeta, su acción rápida y el tablero entero contestan igual que
--     antes de romperla (ya no la llaman: leen de c15 los que esperan, sin
--     su propuesta, y el control solo con sus cuadres), y «control» trae los
--     cuadres en rojo y los que no se pueden comprobar, sin los avisos. Con
--     un c15 anterior a estos arreglos (sin sus dos lecturas ligeras) sale
--     «omitida»: c16 lee entonces lo de antes, que sí la arma.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); v_mov uuid; n0 jsonb; n jsonb; a0 jsonb; a jsonb; t jsonb;
begin
  if pg_temp.c16_nom_omitir(64, 'la portada no arma la propuesta de ningún cargo de Gusto', 'lee lo ligero de la nómina', true, true) then return; end if;
  if to_regprocedure('public.fn_nomina_cargos_esperan()') is null or to_regprocedure('public.fn_nomina_control_filas(boolean)') is null then
    insert into _pruebas values (64, 'LO LIGERO: LA PORTADA NO ARMA LA PROPUESTA DE NINGÚN CARGO DE GUSTO', 'la nómina (c15) con sus dos lecturas ligeras',
      'omitida: la nómina (c15) de esta base es anterior a los arreglos del 14-nov (no trae sus dos lecturas ligeras): la portada lee entonces su lista entera de cargos y su control entero, como antes. Vuelve a pegar c15-nomina.sql', null);
    return;
  end if;
  begin
    perform pg_temp.c16_nom_sembrar();
    perform pg_temp.c16_nom('tres', v_hoy - 12, v_hoy - 4, v_hoy);
    v_mov := pg_temp.c16_nom_cargo('zz-c16-prueba-64-net', v_hoy, 4725.09, 'GUSTO DES:NET ID:ZZ00000006');
    n0 := pg_temp.c16_nom_tarjeta();
    select x into a0 from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()') -> 'lista') x where x ->> 'clave' = 'nomina';
    -- la propuesta de un cargo, rota a propósito (se deshace con la prueba)
    perform pg_temp.c16_ser('editor');
    execute $f$create or replace function public.fn_nomina_cargo_propuesta(p_movimiento uuid) returns jsonb
            language plpgsql stable set search_path = public, pg_temp
            as $b$ begin raise exception using errcode = 'MXT64', message = 'c16-pruebas: aquí no se arma la propuesta de un cargo'; end $b$
            $f$;
    n := pg_temp.c16_nom_tarjeta();
    select x into a from jsonb_array_elements(pg_temp.c16_j('select public.fn_tablero_acciones()') -> 'lista') x where x ->> 'clave' = 'nomina';
    t := pg_temp.c16_t();
    v_esp := 'con un cargo de Gusto esperando y la propuesta de los cargos rota: la lista entera de la nómina falla (MXT64) | la tarjeta contesta, '
             || 'con sus cargos (uno o más) y sus cuadres, igual que antes de romperla | su acción rápida, igual | el tablero entero: 16 tarjetas '
             || 'contestan o dicen qué capa falta, y la de la nómina contesta | «control» trae los cuadres en rojo y los que no se pueden '
             || 'comprobar, sin los avisos';
    v_obt := format('con un cargo de Gusto esperando y la propuesta de los cargos rota: la lista entera de la nómina %s | la tarjeta %s | su acción '
                    'rápida, %s | el tablero entero: %s tarjetas contestan o dicen qué capa falta, y la de la nómina %s | «control» trae %s',
                    case pg_temp.c16_estado('select count(*) from public.fn_nomina_cargos()')
                      when 'MXT64' then 'falla (MXT64)' when 'ok' then 'contesta (no la arma: la prueba no prueba nada)'
                      else 'falla con otro error' end,
                    case when (n ->> 'ok')::boolean and (n -> 'cargos' ->> 'n')::int >= 1 and n -> 'cargos' = n0 -> 'cargos' and n -> 'control' = n0 -> 'control'
                         then 'contesta, con sus cargos (uno o más) y sus cuadres, igual que antes de romperla'
                         else 'no contesta igual: ' || left(coalesce(n ->> 'motivo', n -> 'cargos' #>> '{}', '?') || ' ' || coalesce(n ->> 'error', ''), 200) end,
                    case when a is not distinct from a0 and (a ->> 'n')::int >= 1 then 'igual' else 'otra: ' || left(coalesce(a ->> 'detalle', '?'), 200) end,
                    (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k where (t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null),
                    case when (t -> 'nomina' ->> 'ok')::boolean then 'contesta' else 'no contesta: ' || left(coalesce(t -> 'nomina' ->> 'error', '?'), 200) end,
                    case when n -> 'control' ? 'cuadres_rojos' and n -> 'control' ? 'sin_comprobar' and not n -> 'control' ? 'avisos'
                         then 'los cuadres en rojo y los que no se pueden comprobar, sin los avisos'
                         else coalesce((select string_agg(k, ', ' order by k) from jsonb_object_keys(n -> 'control') k), 'nada') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (64, 'LO LIGERO: LA PORTADA NO ARMA LA PROPUESTA DE NINGÚN CARGO DE GUSTO NI CORRE LOS AVISOS DE LA NÓMINA: con un cargo de Gusto esperando en la Bandeja y la propuesta de los cargos de la nómina rota a propósito (dentro del bloque), la tarjeta de la nómina, su acción rápida y el tablero entero contestan igual que antes de romperla (leen de la nómina los que esperan, sin su propuesta, y el control solo con sus cuadres); y «control» trae los cuadres en rojo y los que no se pueden comprobar, sin los avisos',
    coalesce(v_esp, 'lee lo ligero de la nómina'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 65. EN GASTOS, LO QUE SE TAPA SIN EL CÓDIGO SE DICE UNA VEZ. Con el
--     criterio «codigo» (la otra palabra de fn_tablero_nomina_criterio,
--     dentro del bloque), una nómina de Gusto en el libro y sin el código
--     del teléfono, la tarjeta de gastos deja fuera las cuentas de la nómina
--     y lo dice en «tapado» (con su botón); su «nota» ya no repite la misma
--     frase (antes salía dos veces en la pantalla). Con el criterio de
--     fábrica, ni «tapado» ni esa frase.
do $$
declare
  v_obt text; v_esp text; v_hoy date := pg_temp.c16_hoy(); g0 jsonb; g jsonb; v_veces int;
begin
  if pg_temp.c16_nom_omitir(65, 'en gastos, lo que se tapa sin el código se dice una vez', 'en «tapado», y no otra vez en la nota') then return; end if;
  begin
    perform pg_temp.c16_nom_sembrar();
    perform pg_temp.c16_nom('una', v_hoy - 12, v_hoy - 4, v_hoy);
    g0 := pg_temp.c16_j('select public.fn_tablero_gastos()', 'dueno_aal1');
    execute $f$create or replace function public.fn_tablero_nomina_criterio() returns text
              language sql stable set search_path = public, pg_temp as $b$ select 'codigo'::text $b$ $f$;
    g := pg_temp.c16_j('select public.fn_tablero_gastos()', 'dueno_aal1');
    -- (cuántas veces dice la tarjeta que sin el código no va lo de la nómina: en «tapado» y en su nota)
    v_veces := (select count(*) from regexp_matches(coalesce(g -> 'tapado' ->> 'texto', '') || ' ¦ ' || coalesce(g ->> 'nota', ''),
                                                     'Sin el código del teléfono', 'g'));
    v_esp := 'criterio de fábrica, sin el código: ni «tapado» ni esa frase en la nota | criterio «codigo», sin el código: «tapado» lo dice, con sus '
             || 'cuentas y su botón a Conexiones; la frase sale 1 vez (en «tapado»: la nota no la repite); en llano: sí';
    v_obt := format('criterio de fábrica, sin el código: %s | criterio «codigo», sin el código: %s; la frase sale %s %s (%s); en llano: %s',
                    case when (g0 -> 'tapado' is null or jsonb_typeof(g0 -> 'tapado') = 'null') and coalesce(g0 ->> 'nota', '') not like '%Sin el código del teléfono%'
                         then 'ni «tapado» ni esa frase en la nota' else 'trae «tapado» o la frase' end,
                    case when g -> 'tapado' ->> 'texto' like 'Sin el código del teléfono%' and jsonb_array_length(g -> 'tapado' -> 'cuentas') > 0
                              and g -> 'tapado' -> 'ir' ->> 'pagina' = 'conexiones'
                         then '«tapado» lo dice, con sus cuentas y su botón a Conexiones' else '«tapado» no lo dice bien: ' || coalesce(g ->> 'tapado', 'nada') end,
                    v_veces, case when v_veces = 1 then 'vez' else 'veces' end,
                    case when coalesce(g ->> 'nota', '') like '%Sin el código del teléfono%' then 'la nota la repite' else 'en «tapado»: la nota no la repite' end,
                    coalesce(pg_temp.c16_llano(g), 'sí'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: ' || sqlerrm;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (65, 'EN GASTOS, LO QUE SE TAPA SIN EL CÓDIGO SE DICE UNA VEZ: con el criterio «codigo», una nómina de Gusto en el libro y sin el código del teléfono, la tarjeta de gastos deja fuera las cuentas de la nómina y lo dice en «tapado» (con su botón a Conexiones); su nota ya no repite la misma frase. Con el criterio de fábrica, ni «tapado» ni esa frase',
    coalesce(v_esp, 'en «tapado», y no otra vez en la nota'), v_obt, case when v_obt like 'omitida:%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 44. LAS DEMÁS CAPAS, COMO SIN c16: los controles de c2, c3, c4, c6, c8,
--     c10, c11, c12, c14, c15 y lo que detiene el cierre de c9 están como estaban
--     sin c16 (lo que ya estaba en rojo sin c16 se dice y no cuenta), después
--     de todas las pruebas.
do $$
declare
  v_obt text; v_esp text; v_antes text := pg_temp.c16('rojos_sin_c16'); v_ahora text[];
begin
  v_esp := 'nuevo en rojo con c16 puesto: ninguno';
  begin
    v_ahora := pg_temp.c16_rojos();
    v_obt := 'nuevo en rojo con c16 puesto: ' || case when v_antes like '¿?%' then 'no se pudo mirar sin c16 (' || v_antes || ')'
                                                     else pg_temp.c16_nuevos(string_to_array(v_antes, '; '), v_ahora) end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'LAS DEMÁS CAPAS, COMO SIN c16: los controles de c2, c3, c4, c6, c8, c10, c11, c12, c14 y c15 y lo que detiene el cierre de c9 están como estaban sin c16, después de todas las pruebas (lo que ya estaba en rojo sin c16 se dice y no cuenta)',
    v_esp, v_obt || case when coalesce(v_antes, '') not in ('', '¿?') and v_antes not like '¿?%'
                         then ' (ya en rojo sin c16, con los datos de esta base: ' || left(v_antes, 600) || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 45. NADA QUEDA: al terminar, la huella es la del principio (las mismas
--     filas en cada tabla que el tablero lee o que las pruebas siembran, el
--     reloj de verdad, las mismas funciones), sin obras, facturas ni
--     asientos de prueba.
do $$
declare
  v_obt text; v_esp text;
begin
  v_esp := 'la huella: la del principio | el reloj: el de verdad | de prueba: nada';
  begin
    v_obt := format('la huella: %s | el reloj: %s | de prueba: %s',
                    case when pg_temp.c16_huella() = pg_temp.c16('huella') then 'la del principio' else 'otra: ' || left(pg_temp.c16_huella(), 400) end,
                    case when pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) = pg_temp.c16('reloj_def') then 'el de verdad' else 'fingido' end,
                    case when exists (select 1 from proyectos where id like 'c16-prueba-%')
                              or exists (select 1 from facturas where num like 'C16-PRUEBA-%')
                              or exists (select 1 from asientos where descripcion like 'C16 PRUEBA%')
                              -- (14-nov, Fase 11c) ni las personas de la nómina de prueba ni sus cargos de Gusto
                              or exists (select 1 from perfiles where nombre like 'ZZ C16 Prueba%')
                              or pg_temp.c16_quedo_de_la_nomina() then 'quedó algo' else 'nada' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'NADA QUEDA: al terminar, la huella es la del principio (las mismas filas en cada tabla que el tablero lee o que las pruebas siembran —también las de la nómina—, las mismas funciones), el reloj es el de verdad y no queda ninguna obra, factura, asiento, persona, nómina ni cargo de prueba',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- EL RELOJ, COMO ESTABA. Cada prueba que lo finge lo deshace con su
-- subtransacción; esto es la red: si alguno quedara puesto, se restaura aquí
-- mismo el de verdad (el que había al empezar) y sale como un fallo, con su
-- fila.
do $$
begin
  if pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) is distinct from pg_temp.c16('reloj_def') then
    reset role;
    execute pg_temp.c16('reloj_def');
    insert into _pruebas values (99, 'EL RELOJ DE LAS PRUEBAS: ninguna prueba deja puesto el reloj fingido', 'el reloj de verdad, al terminar',
      'una prueba dejó puesto el reloj fingido: se restauró el de verdad aquí mismo. Es un fallo de este archivo: avisa.', false);
  end if;
end $$;

-- Lo que se puso para la sesión, como estaba
reset role;
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- UNA PRUEBA QUE NO PUDO TOMAR UN CANDADO EN MEDIO SEGUNDO NO ES UN FALLO:
-- la app (u otra sesión) tenía tomado algo que necesitaba, y esta corrida no
-- espera más (el tope de arriba, para no dejar esperando a la app). Sale
-- «omitida», con lo que dijo la base, y se vuelve a pegar el archivo en un
-- momento más tranquilo. (Como c11, c12 y c14.)
update _pruebas
   set ok = null,
       obtenido = 'omitida: mientras corría, la app (u otra sesión) tenía tomado algo que esta prueba necesita y no lo soltó en medio '
                  || 'segundo (55P03); no se esperó más, para no dejar esperando a la app. No es un fallo: vuelve a pegar el archivo en un '
                  || 'momento en que nadie esté usando la app. Lo que dio: ' || left(obtenido, 300)
 where ok is false and obtenido like '%55P03%';

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como las demás
-- capas): si el SQL Editor deja de esperar, la corrida sigue en el
-- servidor hasta el final y se lee después con
--   select * from pruebas.c16_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro ni del tablero (c16 no tiene
-- tablas) y se borra, cuando ya no haga falta, con «drop schema pruebas
-- cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c16_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c16_resultado from public, anon, authenticated, service_role;
truncate pruebas.c16_resultado;
insert into pruebas.c16_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
