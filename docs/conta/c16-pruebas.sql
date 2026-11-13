-- =====================================================================
-- c16-pruebas.sql — el tablero de la portada se prueba a sí mismo
-- (c16-tablero.sql). 13-nov-2026 (la marca 2026111303: con los arreglos de
-- las dos revisiones, cada uno con su prueba, de la 36 a la 43, y los de la
-- revisión final, de la 46 a la 50).
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c16-tablero.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 50 filas, todas
-- con ok = true (las que salen «omitida» dicen por qué y no son un fallo;
-- una fila 99 solo sale si algo de este archivo falló). Si el editor se
-- cansa antes del final, la corrida sigue en el servidor y se lee después
-- en pruebas.c16_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c14 y c16-tablero.sql):
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
-- Las capas que no estén en la base (c6, c7, p1, c8, c9, c10, c11, c12)
-- hacen que su tarjeta diga que no está: lo que necesita una de ellas sale
-- «omitida» con su porqué, y lo demás se prueba igual.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10, c11, c12, c14) se
-- comparan con cómo estaban SIN c16 (dentro de un bloque que lo quita y se
-- deshace): lo que ya estaba en rojo se dice y no se cuenta.
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
--  5 el tablero entero: las 15 tarjetas, en su orden, todas contestan (o
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
-- 50 la proyección, lo que no incluye: la deuda de la nómina con todo lo
--    que el libro tiene (también lo fechado después de hoy);
-- Y el cierre de la suite:
-- 44 las demás capas como estaban sin c16 (lo que ya estaba en rojo se dice
--    y no cuenta);
-- 45 nada queda, y el reloj es el de verdad.
-- Última sentencia: select * from _pruebas order by n;
--
-- NO FRENA A LA APP: lo primero que hace es poner lock_timeout a MEDIO
-- SEGUNDO para toda la corrida, como el pegado. Las pruebas 2, 30, 31 y 40
-- renombran o quitan el permiso de una vista ajena DENTRO de un bloque que
-- se deshace: si la app la tiene tomada y no la suelta en medio segundo,
-- esa prueba sale «omitida» (no es un fallo: se vuelve a pegar en un
-- momento más tranquilo).
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
-- (un monto como texto con sus dos decimales, para comparar al centavo; nulo = «—»)
create or replace function pg_temp.c16_m(p numeric) returns text language sql immutable as $$ select coalesce(round(p, 2)::numeric(14,2)::text, '—') $$;
create or replace function pg_temp.c16_mj(p jsonb) returns text language sql immutable as $$
  select case when p is null or jsonb_typeof(p) = 'null' then '—' else round((p #>> '{}')::numeric, 2)::numeric(14,2)::text end
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, con su código: aal2), anon o
-- service_role.
create or replace function pg_temp.c16_ser(quien text) returns void language plpgsql as $$
declare
  v_id text := pg_temp.c16(quien);
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
    perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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

-- LOS CONTROLES DE LAS OTRAS CAPAS que están en rojo: la cadena (c2), los
-- puentes (c3), los estados (c4), el banco (c6), los cuadres de la IA (c8),
-- los del jornal y el margen (c10), los de las facturas (c11), los del WIP
-- (c12), los de los subs (c14) y lo que detiene el cierre del mes (c9);
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
                           'contador_config', 'cierre_revisiones', 'emision_config', 'emision_documentos', 'wip_ajustes', 'wip_revisiones'] loop
    if to_regclass('public.' || t) is not null then
      execute format('select count(*) from public.%I', t) into n;
      v := v || t || '=' || n || ' ';
    end if;
  end loop;
  return v || '· reloj ' || left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12)
         || ' · funciones ' || (select count(*) from pg_proc where pronamespace = 'public'::regnamespace)
         || ' · obras de prueba ' || (select count(*) from proyectos where id like 'c16-prueba-%')
         || ' · asientos de prueba ' || (select count(*) from asientos where descripcion like 'C16 PRUEBA%');
end $$;
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
                  'tablas o vistas de c16: 0 | el pegado: 6 filas | marca: 2026111303', v_tot);
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
    'select count(*) from public.fn_tablero_cxp()', 'select public.fn_tablero_stripe()', 'select public.fn_tablero_saldos()'];
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

-- 5. EL TABLERO ENTERO, como el dueño: las 15 tarjetas en su orden, cada una
--    contesta (o dice qué capa no está, si es eso: ninguna falla), el libro
--    en llano («lo de antes vive en QuickBooks»), las capas, y nada en
--    «sigue» sin tope.
do $$
declare
  v_obt text; v_esp text; t jsonb; v_k text; v_ok int := 0; v_falta text[] := '{}'; v_mal text[] := '{}'; v_espf text[] := '{}';
  c_orden constant text[] := array['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar',
                                   'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras'];
begin
  -- (lo que debe decir que su capa no está, por las capas de esta base)
  if not pg_temp.c16_capa('c6') then v_espf := v_espf || 'bancos'::text; end if;
  if not pg_temp.c16_capa('p1') then v_espf := v_espf || 'cobros_en_linea'::text; end if;
  if not pg_temp.c16_capa('c9') then v_espf := v_espf || 'use_tax'::text; end if;
  if not pg_temp.c16_capa('c6_prestamos') then v_espf := v_espf || 'prestamos'::text; end if;
  if not pg_temp.c16_capa('c10') and not pg_temp.c16_capa('c12') then v_espf := v_espf || 'obras'::text; end if;
  v_esp := format('ok: true | las tarjetas, en su orden: sí | contestan: %s | dicen qué capa no está: %s | fallan: ninguna | el libro: en llano | '
                  'capas: las de esta base | sigue: nada', 15 - cardinality(v_espf),
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
  insert into _pruebas values (5, 'EL TABLERO ENTERO, como el dueño: las 15 tarjetas en su orden; cada una contesta, o dice que su capa no está (ninguna falla); el libro en llano («lo de antes vive en QuickBooks»); las capas de esta base; sin tope, nada en «sigue»',
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
--    mes que toca cerrar y lo que lo detiene, de c9).
do $$
declare
  v_obt text; v_esp text; a jsonb := pg_temp.c16_tc('acciones'); r record;
  v_ocultas text[] := '{}'; v_fin date := date_trunc('month', pg_temp.c16_hoy())::date - 1;
  e_fac text; e_ban text; e_con text; e_pag text; e_cie text;
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
    v_esp := format('factura: %s | bandeja: %s | conciliar: %s | pago: %s | cierre: %s | estados: true', e_fac, e_ban, e_con, e_pag, e_cie);
    select format('factura: %s | bandeja: %s | conciliar: %s | pago: %s | cierre: %s | estados: %s',
             max(case when x ->> 'clave' = 'factura' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', x ->> 'camino') else 'false' end end),
             max(case when x ->> 'clave' = 'bandeja' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', coalesce(x ->> 'mas_viejo', '—')) else 'false' end end),
             max(case when x ->> 'clave' = 'conciliar' then case when (x ->> 'disponible')::boolean then format('true %s', x ->> 'n') else 'false' end end),
             max(case when x ->> 'clave' = 'pago' then case when (x ->> 'disponible')::boolean then format('true %s', x ->> 'n') else 'false' end end),
             max(case when x ->> 'clave' = 'cierre' then case when (x ->> 'disponible')::boolean then format('true %s %s', x ->> 'n', coalesce(x ->> 'periodo', '—')) else 'false' end end),
             max(case when x ->> 'clave' = 'estados' then x ->> 'disponible' end))
      into v_obt
      from jsonb_array_elements(a -> 'lista') x;
    if (a ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(a ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'ACCIONES RÁPIDAS: crear una factura (los borradores y por dónde se factura, c11), la Bandeja (lo que espera y desde cuándo, contado como su página: v_banco_bandeja, c6), conciliar (las cuentas con banco sin conciliar hasta el fin del mes pasado, c6), pedir un pago en línea (los enlaces activos, p1), cerrar el mes (el que toca y lo que lo detiene, c9) y los estados',
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
    a_h := least(v_d - 1, (v_hoy - interval '1 month')::date);
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
do $$
declare
  v_obt text; v_esp text; c jsonb := pg_temp.c16_tc('caja'); v_hoy date := pg_temp.c16_hoy(); v_fin date; v_cob numeric; v_pag numeric;
  v_cuo numeric := 0; v_imp numeric; v_lib numeric; p jsonb; v_ap boolean; v_dev bigint[]; v_ut text; v_s0 numeric; v_p numeric; v_h numeric;
  v_mod text[]; v_nom numeric; v_dv numeric; v_vj numeric; v_m0 date := date_trunc('month', pg_temp.c16_hoy())::date;
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
      if v_cob = 0 and v_pag = 0 and v_cuo = 0 and v_imp = 0 and v_lib = 0 and (p is null or p = 'null'::jsonb) then
        v_esp := 'sin nada con fecha: sin proyección (lo dice)';
        v_obt := case when c ->> 'sin_proyeccion' is not null and (p is null or p = 'null'::jsonb) then 'sin nada con fecha: sin proyección (lo dice)' else 'otra cosa: ' || coalesce(p::text, '') end;
      else
        v_esp := format('este mes: cobrar %s, pagar %s, cuotas %s, use tax %s, posfechado %s, saldo %s | cada mes, el anterior más su neto: sí | '
                        'marcada como proyección, con la línea a la vista: sí | no incluye, con su monto: la nómina %s, un cheque devuelto %s, más de 60 días %s',
                        pg_temp.c16_m(v_cob), pg_temp.c16_m(v_pag), pg_temp.c16_m(v_cuo), pg_temp.c16_m(v_imp), pg_temp.c16_m(v_lib),
                        pg_temp.c16_m((c -> 'hoy' ->> 'neto')::numeric + v_cob - v_pag - v_cuo - v_imp + v_lib),
                        case when v_nom <> 0 then pg_temp.c16_m(v_nom) else 'nada' end, case when v_dv <> 0 then pg_temp.c16_m(v_dv) else 'nada' end,
                        case when v_vj <> 0 then pg_temp.c16_m(v_vj) else 'nada' end);
        v_obt := format('este mes: cobrar %s, pagar %s, cuotas %s, use tax %s, posfechado %s, saldo %s | cada mes, el anterior más su neto: %s | '
                        'marcada como proyección, con la línea a la vista: %s | no incluye, con su monto: la nómina %s, un cheque devuelto %s, más de 60 días %s',
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'cobrar'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'pagar'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'cuotas'),
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'impuestos'), pg_temp.c16_mj(p -> 'meses' -> 0 -> 'libro'),
                        pg_temp.c16_mj(p -> 'meses' -> 0 -> 'saldo'),
                        case when not exists (select 1 from jsonb_array_elements(p -> 'meses') with ordinality t(x, o)
                                               where o > 1 and (x ->> 'saldo')::numeric <> (p -> 'meses' -> (o::int - 2) ->> 'saldo')::numeric + (x ->> 'neto')::numeric)
                             then 'sí' else 'no' end,
                        case when jsonb_array_length(p -> 'supuestos') > 0 and jsonb_array_length(p -> 'no_incluye') > 0
                                  and p ->> 'aviso' like '%la caja real será menor%'
                                  and (select count(*) from jsonb_array_elements(c -> 'serie') x where x ->> 'tipo' = 'proyeccion') = jsonb_array_length(p -> 'meses')
                             then 'sí' else 'no' end,
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x
                                   where x ->> 'clave' = 'deuda' and x ->> 'linea' = 'nomina_por_pagar'), 'nada'),
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x where x ->> 'clave' = 'cheque_devuelto'), 'nada'),
                        coalesce((select pg_temp.c16_mj(x -> 'monto') from jsonb_array_elements(p -> 'no_incluye') x where x ->> 'clave' = 'vencido_viejo'), 'nada'));
      end if;
    end if;
    if (c ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c ->> 'motivo', pg_temp.c16('t_error')); end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'LA PROYECCIÓN DE CAJA, con lo que se sabe y dicho de frente: en el mes de hoy, lo por cobrar que vence en él o ya venció hasta hace 60 días (sin lo de un cheque devuelto) − lo por pagar igual − las cuotas de los préstamos − el use tax por la regla del DR-15 ± lo posfechado del libro; cada mes, el saldo anterior más su neto; la línea a la vista («la caja real será menor») y lo que no incluye con su monto; sin la apertura en el libro, sin proyección (lo dice)',
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
                  'acciones, pedir un pago: no disponible (p1) | el tablero: 15 contestan, %s dicen que falta su capa, 0 fallan', v_antes + v_mas);
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
  v_esp := 'no se pudieron leer, con 42501: caja, cobros, facturas, por_cobrar | las demás contestan: 11 | la tarjeta sola: 42501';
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
  insert into _pruebas values (31, 'UNA TARJETA QUE FALLA: sin permiso para leer la antigüedad de lo por cobrar de c4, las cuatro tarjetas que la usan dicen que no se pudieron leer (con su código, 42501) y las otras once contestan; la tarjeta sola, por la API, da el error',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. EL TOPE POR RELOJ: con un tope de 1 ms, lo que no alcanzó sale en
--     «sigue» ({ok: false, sigue: true}, sin error) y, pedido otra vez, llega
--     igual que sin tope; entre las dos llamadas, las 15 tarjetas.
do $$
declare
  v_obt text; v_esp text; t0 jsonb := pg_temp.c16('t')::jsonb; t1 jsonb; t2 jsonb; v_dif text;
begin
  if pg_temp.c16_omitir(32, 'el tope por reloj', 'lo que no alcanzó sale en «sigue» y llega al pedirlo otra vez') then return; end if;
  v_esp := 'la primera: ok, lo que no alcanzó en «sigue» (sin error) | la segunda: lo de «sigue», igual que sin tope | entre las dos: las 15';
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
                                                              union select jsonb_array_elements_text(t2 -> 'tarjetas')) u) = 15
                         then 'las 15' else 'faltan' end);
    if jsonb_array_length(t1 -> 'sigue') = 0 then
      v_obt := replace(v_obt, 'no hizo falta (todo alcanzó en 1 ms)', 'lo de «sigue», igual que sin tope');
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'EL TOPE POR RELOJ: con un tope de 1 ms, lo que no alcanzó sale en «sigue» ({ok: false, sigue: true}, sin error) y, pedido otra vez, llega igual que sin tope; entre las dos llamadas, las 15 tarjetas',
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
      (17, 'ninguna tarjeta', 'select public.fn_tablero(''{"tarjetas": []}'')', 'ok')) x(o, que, s, codigo)
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
                             public.fn_tablero_capas())');
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
    with s as (
      select k, x #>> '{}' as s
        from unnest(array['texto', 'detalle', 'nota', 'regla', 'fuente', 'motivo', 'etiqueta', 'titulo', 'aviso', 'cuantas', 'que_es',
                          'sin_comparar', 'alarma_texto', 'por_que_no', 'sin_proyeccion']) k,
             lateral jsonb_path_query(t, ('strict $.**.' || k)::jsonpath) x
       where jsonb_typeof(x) = 'string'
      union all
      select 'supuestos', x #>> '{}' from jsonb_path_query(t, 'strict $.**.supuestos[*]') x where jsonb_typeof(x) = 'string'
    )
    select string_agg(distinct k || ': «' || left(s.s, 120) || '»', ' · '), count(*) into v_mal, v_n
      from s
     where s.s ~* '(\mfn_[a-z]|\mv_[a-z]+_|\mnull\M|\mnan\M|undefined|[{}]|\msqlstate\M|\mjsonb?\M|\mselect\M|\mpg_|permission denied|does not exist)'
        or regexp_replace(s.s, '«[^»]*»', '', 'g') ~ '\m[a-z]+_[a-z_]+\M'
        -- (un código o un secreto en mayúsculas, una fecha AAAA-MM-DD, un plural a medias, un texto cortado, jerga)
        or s.s ~ '\m[A-Z][A-Z0-9]+(_[A-Z0-9]+)+\M'
        or s.s ~ '\m[0-9]{4}-[0-9]{2}-[0-9]{2}\M'
        or s.s ~ '\((s|es)\)'
        or s.s like '%…%'
        or s.s ~* '\mráfaga|\mpartidas?\M';
       -- (un nombre de la base en minúsculas, como_pagar, fuera de unas comillas «»: lo que va entre «» es una etiqueta que Edgar ve
       --  tal cual en otra página)
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

-- 50. LA PROYECCIÓN, LO QUE NO INCLUYE: LA DEUDA DE LA NÓMINA CON TODO LO QUE
--     EL LIBRO TIENE (la revisión final, con la nómina de c15 en producción).
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
  c0 jsonb; c1 jsonb; c2 jsonb; d0 jsonb; d1 jsonb; d2 jsonb;
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
  v_esp := 'una nómina posteada con día de pago después de hoy: la deuda sube 500.00, lo de hasta hoy igual, lo dice | '
           || 'su cargo ya salió del banco: la deuda vuelve a la de antes, lo de hasta hoy baja 500.00';
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
    if (c2 ->> 'ok')::boolean is not true then v_obt := 'la tarjeta no contestó: ' || coalesce(c2 ->> 'motivo', '?'); end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c16_ser('editor');
  insert into _pruebas values (50, 'LA PROYECCIÓN, LO QUE NO INCLUYE: LA DEUDA DE LA NÓMINA con todo lo que el libro tiene en sus cuentas, también lo fechado después de hoy: una nómina ya posteada con día de pago después de hoy se dice (la deuda sube); y si su cargo ya salió del banco antes de ese día, la deuda no baja en negativo (vuelve a la de antes)',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 44. LAS DEMÁS CAPAS, COMO SIN c16: los controles de c2, c3, c4, c6, c8,
--     c10, c11, c12, c14 y lo que detiene el cierre de c9 están como estaban
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
  insert into _pruebas values (44, 'LAS DEMÁS CAPAS, COMO SIN c16: los controles de c2, c3, c4, c6, c8, c10, c11, c12 y c14 y lo que detiene el cierre de c9 están como estaban sin c16, después de todas las pruebas (lo que ya estaba en rojo sin c16 se dice y no cuenta)',
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
                              or exists (select 1 from asientos where descripcion like 'C16 PRUEBA%') then 'quedó algo' else 'nada' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'NADA QUEDA: al terminar, la huella es la del principio (las mismas filas en cada tabla que el tablero lee o que las pruebas siembran, las mismas funciones), el reloj es el de verdad y no queda ninguna obra, factura ni asiento de prueba',
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
