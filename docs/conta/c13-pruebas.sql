-- =====================================================================
-- c13-pruebas.sql — la cédula de corte se prueba a sí misma
-- (c13-cedula.sql). 12-nov-2026; ampliada el 13-nov-2026 (Fase 11b: la
-- cédula con el auxiliar de la nómina, las pruebas 42 a 47; y la 48, de los
-- arreglos de su verificación: una cuenta por pagar al revés no «cuadra»).
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c13-cedula.sql (y,
-- si el c9-cierre.sql que tienes trae la fila 178, después de volver a
-- pegarlo), pegar este archivo entero → Run. Sale la tabla _pruebas: 48
-- filas, todas con ok = true (las que salen «omitida» dicen por qué y no
-- son un fallo; una fila 99 solo sale si algo de este archivo falló). Si el
-- editor se cansa antes del final, la corrida sigue en el servidor y se lee
-- después en pruebas.c13_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c12 y c13-cedula.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c13-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las cuentas de prueba, ni sus obras, ni sus asientos, ni
-- sus facturas, ni los renglones, ni las explicaciones, ni la revisión del
-- cierre que c9 guarda, ni el reloj, ni lo que se finge de la nómina); la 40
-- lo comprueba, y la 41 otra vez al final de todo (las 42 a 48 corren antes
-- que ellas, aunque su número sea mayor: así las cubren).
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · NUEVE CUENTAS DE PRUEBA, que solo existen dentro de cada prueba: un
--     banco (1093), una tarjeta (2100-9393, con su alta ····9393), las dos
--     de un préstamo (2593 corriente y 2594 largo plazo), una de activos
--     (1583), una de pólizas (1493), una que la base no sabe (1693), una de
--     nómina (2293) y una de patrimonio (3193); y dos más en su prueba (una
--     inactiva, 1694, y una tarjeta sin dar de alta, 2100-9394). En ellas se
--     prueba cada auxiliar AL CENTAVO, sin que lo real se mezcle. Si alguno
--     de esos códigos ya existe en esta base y no es de estas pruebas, las
--     pruebas que lo usan salen «omitida» diciéndolo.
--   · Donde la cuenta es la de verdad y no puede ser otra (las cuentas por
--     cobrar 1110, la retención 1120, las cuentas por pagar 2010, las del
--     WIP, la 1590, Stripe, el use tax, lo devengado), se mira LO QUE LA
--     PRUEBA MUEVE: la fila de la cédula antes y después (libro, auxiliar y
--     diferencia, cada uno por lo que cambió) y SUS renglones (su factura,
--     su proveedor, su obra, su activo). Lo que la base ya traía —cuadre o
--     no— no se cuenta.
--   · TRES OBRAS DE PRUEBA («C13 PRUEBA Obra A», «W» y «X», ids
--     c13-prueba-a, -w y -x), sus facturas por el puente de c3 (ids negativos,
--     −1300001…: no gastan la secuencia), su proveedor («ZZ C13 PRUEBA
--     SUPPLY») y sus asientos a mano por el camino del dueño (fn_postear),
--     fechados en EL MES DE LAS PRUEBAS: el mes abierto más viejo que ya
--     terminó. SI NO HAY NINGUNO (todo lo terminado está cerrado: pasa desde
--     que se cierra un mes hasta que termina el siguiente, o sea, casi
--     siempre que Edgar va al día), NO SE OMITEN: el mes de las pruebas es
--     EL QUE CORRE (abierto, con el siguiente abierto) y cada prueba corre
--     con EL RELOJ FINGIDO —el de c2-pruebas, c11, c12 y c14—: dentro de su
--     subtransacción «hoy» es el día 12 del mes siguiente, y al deshacerse
--     vuelve el de verdad. (Antes, con la apertura y octubre cerrados, 23 de
--     las 36 salían «omitida» hasta el 1-dic: la suite casi no comprobaba
--     nada justo cuando hace falta.) Solo se omiten si no hay ni un mes
--     abierto donde postear. Al final el archivo comprueba que el reloj
--     quedó como estaba (y si no, lo restaura y sale un fallo, la fila 99).
--   · La regla del tipo de obra (mapeo_tipo_proyecto) se confirma dentro de
--     la prueba si estaba en borrador (en producción ya lo está). Si el mes
--     de las pruebas ya tiene su ajuste de WIP real, la del WIP lo deshace
--     dentro de su subtransacción (y vuelve con ella); si ya tiene su
--     depreciación, la del activo la reversa y la vuelve a postear, también
--     dentro; si su mes ya tiene una balanza de QuickBooks, la de QuickBooks
--     carga otra encima dentro de la prueba (c4 lo avisa con un WARNING: es
--     de la prueba y se deshace). Si un mes POSTERIOR ya está amortizado, la
--     de la póliza no puede amortizar el suyo y sale «omitida» diciéndolo.
--   · El patrimonio se prueba sostenido con su mayor (c13_sembrar lo pone
--     así dentro de cada prueba, diga lo que diga la configuración de esta
--     base); la 22 prueba el otro modo.
--   · LA NÓMINA (c15), QUE PUEDE ESTAR O NO EN ESTA BASE (13-nov). Las
--     pruebas de siempre (1 a 41) corren «SIN LA NÓMINA»: al sembrar, la
--     función de c13 que dice qué capas hay pasa a decir que c15 no está (y
--     se deshace con la prueba). Así dan lo mismo con c15 pegada que sin
--     ella, y la cuenta de nómina de prueba (2293) sigue siendo «una cuenta
--     con saldo y sin auxiliar». Las 42 a 45 corren «CON UNA NÓMINA
--     FINGIDA»: la función de c13 que lee la nómina (fn_cedula_nomina) pasa
--     a leer una tabla temporal de esta sesión (qué dejó por pagar cada
--     nómina de prueba cada día), y el «journal» de esa nómina es un asiento
--     de verdad con su origen, por la puerta interna de c2. Dan lo mismo en
--     las tres bases. La 46 prueba la lectura de verdad (sin fingir la
--     función de c13): con c15, la de c15; sin c15, con dos funciones de
--     reemplazo que solo existen dentro de la prueba. La 47 compara, con lo
--     que esta base tenga, la cédula con lo que la nómina dice («omitida»
--     sin c15). NINGUNA TOCA NADA DE c15: ni una tabla, ni una función suya.
--   · Ninguna prueba hace DDL sobre una tabla de otra capa. «La capa no
--     está» se finge reemplazando, dentro de la prueba, la función de c13
--     que dice qué capas hay (como el reloj fingido de c2-pruebas); la
--     cadena mínima de verdad (c1, c2 y c3 solos), la capa que llega
--     después y volver a pegar c13 con lo guardado dentro las prueba en el
--     banco pruebas/conta/c13-sin-capas.sh; y dos sesiones a la vez,
--     pruebas/conta/c13-concurrencia.sh.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10, c11, c12) se comparan
-- con cómo estaban justo antes: lo que ya estaba en rojo se dice y no se
-- cuenta.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 3 tablas, 5 vistas, las 25 funciones por su
--    nombre exacto, la configuración, cada objeto con su comentario «c13: …»);
--  2 las precondiciones en rojo (desde la app; sin una función de c2; una
--    función con nombre de c13 que no es de c13; una vista ajena colgada);
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas en las
--    tablas, las vistas y las funciones de lectura, y tampoco se entera de
--    qué partes de la contabilidad hay instaladas; el dueño entra y ve
--    (no postea: corre también con todos los meses cerrados);
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa, RLS y
--    policies justas, vistas security_invoker que no fijan columnas de c2 ni
--    cuelgan de vistas ajenas; «permisos» (c2) y las protecciones de c6 y c4
--    en verde con c13 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API; y
--    lo que es rastro, ni con la marca);
--  6 fn_cedula_config y sus frenos;
--  7 la cédula trae todas las cuentas de balance, en su lado natural, y su
--    saldo es el del libro; la de grupo y la inactiva sin movimiento no salen
--    (con todo cerrado, lo mismo con lo que la base tenga);
-- CADA AUXILIAR, cuadrando y descuadrando al centavo:
--  8 cuentas por cobrar (1110): una factura cobrada a medias; a una fecha
--    anterior al cobro; un asiento a mano sin factura; y lo que va sin
--    factura, aparte y obra por obra;
--  9 la retención (1120), por obra y factura;
-- 10 cuentas por pagar (2010), por proveedor: pagada a medias; un asiento
--    sin proveedor; y la fila dice que debajo están las partidas del propio
--    libro (el statement del supply se compara a mano);
-- 11 un banco: su conciliación confirmada; lo que pasa después; una fecha
--    anterior a la conciliación (no la comprueba: «del libro»); un asiento
--    que entra después con fecha anterior;
-- 12 una tarjeta: el statement en su lado (lo que se debe, en positivo); y
--    una subcuenta de tarjetas sin dar de alta;
-- 13 un préstamo con su parte corriente y su largo plazo (calculadas a
--    mano): sin registrar, el libro sin repartir (y ese reparto, en los
--    totales, una vez y aparte), repartido, antes y después de una cuota;
-- 14 el WIP por obra: el ajuste vivo el último día del mes, su reverso el
--    día 1, un asiento a mano en una obra, y dos obras que se compensan;
-- 15 un activo con su depreciación (15xx y 1590); uno sin su asiento;
-- 16 una póliza de c6: lo que le falta, amortizado el mes, a una fecha
--    anterior (con y sin el papel de su compra), y un pago que no es póliza;
-- 17 el auxiliar a mano: sin renglones, cuadrando, descuadrando, desde y
--    hasta, corregir, anular y sus frenos;
-- 18 lo devengado (2050): un devengo vivo, su reverso el día 1, y lo que no
--    es un devengo (suelto, y con su renglón a mano);
-- 19 Stripe (1020 y 1140): lo que falta depositar, a una fecha anterior
--    («del libro»: no la comprueba), y un asiento a mano;
-- 20 el use tax (2300) por mes: sale del propio libro («del libro»);
-- 21 la nómina, SIN c15 en la base: sin auxiliar («llega con la nómina»),
--    con saldo, y con su renglón a mano (con c15, las 42 a 47);
-- 22 el patrimonio: su mayor («del libro»); «manual» en la configuración; y
--    con renglones a mano se compara con ellos;
-- LAS EXPLICACIONES:
-- 23 explicar: quién, cuándo, para esa fecha; sus frenos;
-- 24 la explicación se queda vieja (cambia el libro; cambia el auxiliar), se
--    vuelve a explicar, se retira;
-- LO DEMÁS:
-- 25 una capa que no está: «sin auxiliar: esa parte no está», y lo demás
--    sigue;
-- 26 la cédula al lado de QuickBooks (c4): una balanza cargada, la
--    diferencia, anotada en c4, y «amarra»;
-- 27 el control: el 10; el 20, el 30, el 40 y el 50 en rojo y de vuelta;
--    antes del mes desde el que se avisa y en un mes sin terminar, en verde;
-- 28 el 90 (las protecciones) en rojo y de vuelta;
-- 29 la fila del cierre (fn_cedula_cierre): la 178, un aviso, con el nombre
--    fijo;
-- 30 el cierre (c9) mira la cédula: su fila 178, y no detiene («omitida»
--    mientras c9-cierre.sql no traiga el bloque de c13);
-- 31 el texto de la cédula y de su control no nombra funciones;
-- 32 los totales (la pantalla no suma; sus 26 llaves) y los renglones suman
--    lo que dice la cédula, cuenta por cuenta; la vista es la función; y el
--    dueño por la API ve exactamente lo que el SQL Editor (ninguna capa
--    ilegible);
-- CUADRAR DE VERDAD (lo que la revisión de la Fase 12a encontró):
-- 33 la conciliación de otro día no comprueba este: no cuadra aunque la
--    resta dé cero;
-- 34 lo suelto que se compensa entre dos obras no cuadra; y una explicación
--    no cubre lo suelto que aparece después;
-- 35 una póliza y lo que se corrigió después: la cédula de aquel día sigue
--    diciendo lo que la cuenta tenía de más;
-- 36 el balance cierra a la vista (activo = pasivo + patrimonio + resultado
--    sin cerrar), y lo que sale del libro no se cuenta como cuadrado;
-- 37 la caja no es un banco que el banco trae;
-- LA CÉDULA CON EL AUXILIAR DE LA NÓMINA (13-nov, Fase 11b; corren antes
-- que el cierre de la suite):
-- 42 una cuenta de la nómina contra lo que cada nómina dejó por pagar, al
--    centavo: sin ninguna nómina; con su journal; ENTRE EL CARGO DE GUSTO Y
--    EL DÍA DE PAGO (la cuenta al revés: lo adelantado a Gusto, y cuadra);
--    pagada a medias; algo que entra por otro lado (la diferencia, y dónde
--    mirarlo); con su renglón a mano; y una corrección que deja algo a favor;
-- 43 los sueldos acumulados: el devengo de las horas MÁS lo de la nómina, y
--    nada dos veces (ni un journal de nómina marcado como los devengos);
-- 44 sin el código del teléfono: «con_codigo» (ni «no cuadra» ni «sin
--    auxiliar»), sin un renglón ni una cifra de ninguna nómina; el control y
--    la fila 178 no avisan de eso y lo dicen; no se explica; con el código,
--    cuadra; y sin ninguna nómina en el libro, lo mismo con él que sin él;
-- 45 la nómina en el control y en la fila 178 del cierre: lo que cuadra no
--    cuenta; lo que entró por otro lado cuenta en el 20 (no en el 30);
-- 46 la lectura de verdad (fn_cedula_nomina): no está, está, sin el código,
--    el equipo, lo que devuelve es lo que dice la nómina, y si cambió de
--    forma («no se pudo leer», y lo demás sigue);
-- 47 con lo que esta base tenga de nómina: en cada cuenta y cada día, lo de
--    la nómina en la cédula es lo que la nómina dice; el dueño con su código
--    ve lo que el SQL Editor, y sin él, «con_codigo»;
-- Y el cierre de la suite:
-- 38 con renglones, explicaciones y la configuración escritos, NINGÚN
--    control de c2, c3, c4, c6, c8, c9, c10, c11 ni c12 pasa a rojo;
-- 39 la cédula solo mira: con todo lo anterior, ni un asiento más;
-- 48 (13-nov, los arreglos de la verificación) una cuenta por pagar al
--    revés (saldo deudor) no «cuadra» aunque su auxiliar sume lo mismo: lo
--    dice, el aviso 20 la cuenta, se puede explicar, y al activo no le toca;
-- 40 nada queda al deshacer;
-- 41 el cierre de la suite: c2, c3, c6 y c4 como estaban, c8, c10, c11 y c12
--    sin cuadres rojos nuevos, nada de c13 para anon o service_role ni
--    SECURITY DEFINER; fn_cedula_pegado responde; y nada queda.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el mes de las pruebas, hoy, qué capas hay.
create temp table if not exists _c13 (k text primary key, v text);
truncate _c13;
insert into _c13
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c13
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
-- EL MES DE LAS PRUEBAS: el mes abierto más viejo que ya terminó.
insert into _c13
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
-- SI NO HAY NINGUNO (todo lo terminado está cerrado: pasa desde que se cierra
-- un mes hasta que termina el siguiente, es decir, casi siempre que Edgar va
-- al día), las pruebas NO se omiten: su mes es EL MES QUE CORRE (abierto, con
-- el siguiente también abierto) y corren con EL RELOJ FINGIDO: «hoy» pasa a
-- ser el día 12 del mes siguiente (c13_reloj, abajo), solo dentro de la
-- subtransacción de cada prueba. Lo que la base ya tenga en ese mes no
-- estorba: cada prueba mira sus cuentas de prueba, o lo que ella mueve.
insert into _c13
select 'reloj', (p.hasta + 12)::text from periodos p
 where not exists (select 1 from _c13 where k = 'mes')
   and p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta
   and exists (select 1 from periodos s where s.tipo = 'mes' and s.estado = 'abierto' and s.desde = p.hasta + 1)
 order by p.desde limit 1;
insert into _c13
select 'mes', p.periodo from periodos p
 where exists (select 1 from _c13 where k = 'reloj')
   and p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta
 order by p.desde limit 1;
-- hoy: el de verdad, o el del reloj fingido
insert into _c13 select 'hoy', coalesce((select v from _c13 where k = 'reloj'), fn_fecha_miami(now())::text);
-- (el reloj DE VERDAD, tal cual está al empezar: si una prueba lo dejara fingido —no pasa: cada una lo deshace con su
-- subtransacción—, el final de este archivo lo restaura y lo dice como un fallo)
insert into _c13 select 'reloj_def', pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure);
-- el mes siguiente al de las pruebas (donde cae un reverso del día 1)
insert into _c13
select 'mes_sig', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto'
   and p.desde = (select q.hasta + 1 from periodos q where q.periodo = (select v from _c13 where k = 'mes'));
-- un mes abierto que todavía no termina (el más lejano: ni siquiera empezó)
insert into _c13
select 'mes_futuro', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > (select v::date from _c13 where k = 'hoy') order by p.desde desc limit 1;
-- el mes en curso (el que contiene hoy: todavía no termina)
insert into _c13
select 'en_curso', p.periodo from periodos p
 where p.tipo = 'mes' and (select v::date from _c13 where k = 'hoy') between p.desde and p.hasta order by p.desde limit 1;
insert into _c13 select 'c4', coalesce(fn_cedula_capas()->>'c4', 'false');
insert into _c13 select 'c6', coalesce(fn_cedula_capas()->>'c6', 'false');
insert into _c13 select 'c9', coalesce(fn_cedula_capas()->>'c9', 'false');
insert into _c13 select 'c12', coalesce(fn_cedula_capas()->>'c12', 'false');
insert into _c13 select 'p1', coalesce(fn_cedula_capas()->>'p1', 'false');
-- la nómina (c15): si está de verdad en esta base (por su función del auxiliar); y lo que la función de c13 que dice
-- qué capas hay contesta al empezar, y su definición (las pruebas la fingen dentro de su subtransacción)
insert into _c13 values ('c15', (to_regprocedure('public.fn_nomina_auxiliar(date)') is not null)::text);
insert into _c13 select 'capas', fn_cedula_capas()::text;
insert into _c13 select 'capas_def', pg_get_functiondef('public.fn_cedula_capas()'::regprocedure);
insert into _c13 values ('hay_c8', (to_regclass('public.v_contador_control') is not null)::text);
insert into _c13 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
insert into _c13 values ('hay_c10', (to_regclass('public.v_jornal_control') is not null and to_regclass('public.v_margen_control') is not null)::text);
insert into _c13 values ('hay_c11', (to_regclass('public.v_emision_control') is not null)::text);
insert into _c13 values ('hay_c12', (to_regprocedure('public.fn_wip_control(text)') is not null)::text);
insert into _c13
select 'c9_cedula', coalesce((select p.prosrc like '%fn_cedula_cierre%' from pg_proc p
                               where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')), false)::text;
-- ¿algo de esta base ya usa un código o un nombre de estas pruebas? (lo que choca, en una línea; vacío = nada)
insert into _c13
select 'choque', coalesce(string_agg(x.que, ', ' order by x.que), '')
  from (select 'la cuenta ' || c.codigo as que from cuentas c
         where c.codigo in ('1093', '2100-9393', '2100-9394', '2593', '2594', '1583', '1493', '1693', '1694', '2293', '3193')
        union all
        select 'la tarjeta ····9393' from tarjetas t where t.ultimos4 = '9393'
        union all
        select 'la obra ' || p.id from proyectos p where p.id like 'c13-prueba-%'
        union all
        select 'la factura ' || f.id from facturas f where f.id between -1300999 and -1300000
        union all
        select 'el proveedor ' || pr.nombre from proveedores pr where lower(btrim(pr.nombre)) = 'zz c13 prueba supply') x;
grant select on _c13 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9, c10 y
-- c12), y ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c13(k text) returns text language sql as $$ select v from _c13 where k = $1 $$;
-- un día del mes de las pruebas (el día 1 + n) y su último día
create or replace function pg_temp.c13_d(p_n int default 0) returns date language sql as $$
  select p.desde + p_n from periodos p where p.periodo = pg_temp.c13('mes')
$$;
create or replace function pg_temp.c13_h() returns date language sql as $$
  select p.hasta from periodos p where p.periodo = pg_temp.c13('mes')
$$;

-- Las funciones que crea c13-cedula.sql, por su nombre exacto (las 25). No
-- se buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c13_es_suya(p_nombre text) returns boolean language sql immutable as $$
  select p_nombre = any (array[
    'fn_cedula_precondiciones', 'fn_cedula_exigir_dueno', 'fn_cedula_ve', 'fn_cedula_guarda', 'fn_cedula_usd', 'fn_cedula_dia',
    'fn_cedula_mes', 'fn_cedula_monto', 'fn_cedula_capas', 'fn_cedula_nomina', 'fn_cedula_toca', 'fn_cedula_cuentas', 'fn_cedula_partidas', 'fn_cedula',
    'fn_cedula_resumen', 'fn_cedula_qb', 'fn_cedula_qb_periodos', 'fn_cedula_config', 'fn_cedula_renglon', 'fn_cedula_renglon_anular',
    'fn_cedula_explicar', 'fn_cedula_explicacion_retirar', 'fn_cedula_control', 'fn_cedula_cierre', 'fn_cedula_pegado'])
$$;
create or replace function pg_temp.c13_tablas() returns text[] language sql immutable as $$
  select array['cedula_config', 'cedula_manual', 'cedula_explicaciones']
$$;
create or replace function pg_temp.c13_vistas() returns text[] language sql immutable as $$
  select array['v_cedula', 'v_cedula_control', 'v_cedula_manual', 'v_cedula_explicaciones', 'v_cedula_qb']
$$;

-- EL RELOJ FINGIDO (el de c2-pruebas, c11, c12 y c14), solo si esta base lo
-- pide (ver «el mes de las pruebas»): «hoy» pasa a ser esa fecha (o el hoy de
-- verdad, si es posterior). Se llama DENTRO de la subtransacción de una
-- prueba (lo llama c13_sembrar): su MXT00 lo deshace. Como el SQL Editor.
create or replace function pg_temp.c13_reloj() returns void language plpgsql as $$
begin
  if pg_temp.c13('reloj') is null then
    return;
  end if;
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, pg_temp.c13('reloj'));
end $$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, en aal2), el dueño SIN el código del
-- teléfono (dueno_aal1), anon o service_role.
create or replace function pg_temp.c13_ser(quien text) returns void language plpgsql as $$
declare
  v_id text := pg_temp.c13(case when quien = 'dueno_aal1' then 'dueno' else quien end);
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
    perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated',
                                                               'aal', case when quien = 'dueno_aal1' then 'aal1' else 'aal2' end)::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(v_id, ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Lo que contesta una orden: 'ok' o su código de error (y, con c13_dice, su
-- mensaje). Como quien se diga; al volver, otra vez el SQL Editor.
create or replace function pg_temp.c13_estado(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c13_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate;
  end;
  perform pg_temp.c13_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c13_dice(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c13_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  perform pg_temp.c13_ser('editor');
  return v;
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): el reloj de las
-- pruebas (si esta base lo pide), «sin la nómina» (c15 fingida fuera: las pruebas dan lo mismo con ella pegada que sin ella;
-- las que la quieren, la ponen), la regla del tipo de obra confirmada, los puentes de c3 en «immediate» (la factura entra al
-- libro en el momento, como en c3-pruebas), las nueve cuentas de prueba, la
-- tarjeta, las obras, el proveedor, y el patrimonio sostenido con su mayor.
create or replace function pg_temp.c13_sembrar() returns void language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c13_ser('editor');
  perform pg_temp.c13_reloj();
  perform pg_temp.c13_sin_nomina();
  perform fn_mapeo_confirmar('tipo_proyecto');
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v is not null then
    execute 'set constraints ' || v || ' immediate';
  end if;
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code) values
    ('1093',      'C13 PRUEBA banco',                  'c13 test bank',       'activo',  'debe',  true, 'prohibida', 'prohibida'),
    ('2100-9393', 'C13 PRUEBA tarjeta',                'c13 test card',       'pasivo',  'haber', true, 'prohibida', 'prohibida'),
    ('2593',      'C13 PRUEBA préstamo corriente',     'c13 test loan cur',   'pasivo',  'haber', true, 'prohibida', 'prohibida'),
    ('2594',      'C13 PRUEBA préstamo largo plazo',   'c13 test loan lt',    'pasivo',  'haber', true, 'prohibida', 'prohibida'),
    ('1583',      'C13 PRUEBA equipo',                 'c13 test equipment',  'activo',  'debe',  true, 'prohibida', 'prohibida'),
    ('1493',      'C13 PRUEBA pólizas',                'c13 test prepaid',    'activo',  'debe',  true, 'prohibida', 'prohibida'),
    ('1693',      'C13 PRUEBA depósitos',              'c13 test deposits',   'activo',  'debe',  true, 'prohibida', 'prohibida'),
    ('2293',      'C13 PRUEBA nómina',                 'c13 test payroll',    'pasivo',  'haber', true, 'prohibida', 'prohibida'),
    ('3193',      'C13 PRUEBA capital',                'c13 test equity',     'capital', 'haber', true, 'prohibida', 'prohibida');
  perform fn_tarjeta_alta('9393', '2100-9393', 'C13 PRUEBA tarjeta');
  insert into proyectos (id, tipo, nombre, estado) values
    ('c13-prueba-a', 'comercial',   'C13 PRUEBA Obra A', 'ejecucion'),
    ('c13-prueba-w', 'comercial',   'C13 PRUEBA Obra W', 'ejecucion'),
    ('c13-prueba-x', 'residencial', 'C13 PRUEBA Obra X', 'ejecucion');
  insert into finanzas_proyecto (proyecto_id, contrato) values ('c13-prueba-w', 10000), ('c13-prueba-x', 20000);
  perform fn_proveedor_alta('ZZ C13 PRUEBA SUPPLY', 'Net 30', array['zz c13 prueba supply inc']);
  -- (el patrimonio, sostenido con su mayor —como nace—, diga lo que diga la
  -- configuración de esta base: la cuenta de patrimonio de prueba es la
  -- contrapartida de casi todo. La prueba que lo quiere «a mano» lo cambia.)
  perform pg_temp.c13_config('{"patrimonio": "mayor"}');
end $$;

-- (la fila «omitida» de una prueba que no se puede correr en esta base; true
-- si la puso). p_pide: lo que la prueba necesita además del dueño: 'mes' (el
-- mes de las pruebas y el siguiente, abiertos), 'cuentas' (que nada de la
-- base choque con lo que se siembra), 'en_curso' (que el libro tenga el mes
-- de hoy) y las capas ('c4', 'c6', 'c9', 'c12', 'p1'; y 'c15', la nómina de verdad).
create or replace function pg_temp.c13_omitir(p_n int, p_prueba text, p_esperado text, p_pide text[] default array['mes', 'cuentas'])
returns boolean language plpgsql as $$
declare
  v text;
  x text;
begin
  if pg_temp.c13('dueno') is null then
    v := 'no hay un dueño activo en perfiles';
  elsif 'mes' = any (p_pide) and pg_temp.c13('mes') is null then
    v := 'no hay un mes abierto donde postear lo de la prueba (ni uno que ya haya terminado, ni el que corre con el siguiente abierto)';
  elsif 'mes' = any (p_pide) and pg_temp.c13('mes_sig') is null then
    v := 'el mes siguiente al de las pruebas no está abierto';
  elsif 'cuentas' = any (p_pide) and pg_temp.c13('choque') <> '' then
    v := 'esta base ya usa algo que estas pruebas siembran (' || pg_temp.c13('choque') || '): no se pisa';
  elsif 'en_curso' = any (p_pide) and pg_temp.c13('en_curso') is null then
    v := 'el libro no tiene el mes en curso (el de hoy): no hay un mes sin terminar con que probar';
  else
    foreach x in array p_pide loop
      if x in ('c4', 'c6', 'c9', 'c12', 'p1', 'c15') and pg_temp.c13(x) <> 'true' then
        v := format('esa parte de la contabilidad (%s) no está en esta base', x);
        exit;
      end if;
    end loop;
  end if;
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado, 'omitida: ' || v, null);
  return true;
end $$;

-- Un asiento a mano, como el dueño (fn_postear). p_lineas: [{cuenta, monto,
-- proyecto_id?, tercero_tipo?, …}] con el monto como texto. Devuelve su id.
create or replace function pg_temp.c13_asiento(p_fecha date, p_que text, p_lineas jsonb, p_reversible boolean default false)
returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c13_ser('dueno');
  r := fn_postear(jsonb_strip_nulls(jsonb_build_object('fecha', p_fecha::text, 'descripcion', 'C13 PRUEBA: ' || p_que || ' (se deshace)',
         'lineas', p_lineas, 'reversible', case when p_reversible then true end)));
  perform pg_temp.c13_ser('editor');
  return (r->>'id')::uuid;
end $$;
-- (dos líneas: debe una cuenta, haber otra)
create or replace function pg_temp.c13_dh(p_fecha date, p_que text, p_debe text, p_haber text, p_monto numeric,
                                          p_obra_debe text default null, p_obra_haber text default null)
returns uuid language sql as $$
  select pg_temp.c13_asiento(p_fecha, p_que, jsonb_build_array(
           jsonb_strip_nulls(jsonb_build_object('cuenta', p_debe, 'monto', p_monto::text, 'proyecto_id', p_obra_debe)),
           jsonb_strip_nulls(jsonb_build_object('cuenta', p_haber, 'monto', (-p_monto)::text, 'proyecto_id', p_obra_haber))))
$$;

-- Una factura de una obra de prueba, por el puente de c3 (como el SQL
-- Editor): entra al libro al insertarla (Dr 1110 lo que se paga ahora + Dr
-- 1120 lo retenido / Cr su ingreso). Devuelve su id (−1300000 − n).
create or replace function pg_temp.c13_factura(p_n int, p_obra text, p_monto numeric, p_dia int, p_retencion numeric default 0)
returns bigint language plpgsql as $$
declare
  v_id bigint := -(1300000 + p_n);
begin
  perform pg_temp.c13_ser('editor');
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
  values (v_id, p_obra, 'C13-' || p_n, pg_temp.c13_d(p_dia), p_monto, p_retencion);
  if not exists (select 1 from facturas f where f.id = v_id and f.contabilizado_en is not null) then
    raise exception 'c13-pruebas: el puente de facturas no contabilizó la factura de prueba % (¿la regla del tipo de obra?)', v_id;
  end if;
  return v_id;
end $$;

-- La fila de la cédula de una cuenta a una fecha, en una línea (como el SQL
-- Editor): fuente | libro | aux | dif | estado (y si pide algo).
create or replace function pg_temp.c13_fila(p_cuenta text, p_fecha date) returns text language sql as $$
  select coalesce((select format('%s | libro %s | aux %s | dif %s | %s%s', c.fuente, c.saldo_libro, coalesce(c.saldo_auxiliar::text, '-'),
                                 coalesce(c.diferencia::text, '-'), c.estado, case when c.pendiente then ' (pendiente)' else '' end)
                     from fn_cedula(p_fecha) c where c.cuenta = p_cuenta), 'no sale')
$$;
-- LA FOTO de una cuenta a una fecha (para mirar después solo lo que la
-- prueba movió): {l: libro, a: auxiliar, d: diferencia, e: estado, r:
-- renglones, x: descuadres, s: sueltas}.
create or replace function pg_temp.c13_foto(p_cuenta text, p_fecha date) returns jsonb language sql as $$
  select coalesce((select jsonb_build_object('l', c.saldo_libro, 'a', coalesce(c.saldo_auxiliar, 0), 'd', coalesce(c.diferencia, c.saldo_libro),
                                             'e', c.estado, 'r', c.renglones, 'x', c.descuadres, 's', coalesce(c.sueltas, 0),
                                             'so', coalesce(to_jsonb(c)->>'sosten', '-'))
                     from fn_cedula(p_fecha) c where c.cuenta = p_cuenta),
                  jsonb_build_object('l', 0, 'a', 0, 'd', 0, 'e', 'no sale', 'r', 0, 'x', 0, 's', 0, 'so', '-'))
$$;
-- LO QUE CAMBIÓ desde la foto: libro, auxiliar y diferencia, cada uno por lo
-- que se movió; y el estado si antes no pedía nada (cuadraba, o salía del
-- propio libro). Si la base ya la traía sin cuadrar, eso no es de la prueba:
-- se dice el estado que tendría con lo que la prueba movió (sin diferencia
-- nueva: «cuadra», o «del_libro» si lo que la sostiene es el propio libro).
create or replace function pg_temp.c13_cambio(p_foto jsonb, p_cuenta text, p_fecha date) returns text language sql as $$
  select format('libro %s | aux %s | dif %s | %s',
                to_char((n->>'l')::numeric - (p_foto->>'l')::numeric, 'FMS999999990.00'),
                to_char((n->>'a')::numeric - (p_foto->>'a')::numeric, 'FMS999999990.00'),
                to_char((n->>'d')::numeric - (p_foto->>'d')::numeric, 'FMS999999990.00'),
                case when p_foto->>'e' in ('cuadra', 'del_libro', 'no sale') then n->>'e'
                     when (n->>'d')::numeric - (p_foto->>'d')::numeric = 0 and (n->>'x')::int = (p_foto->>'x')::int
                       then case when n->>'so' in ('libro', 'llevado') then 'del_libro' else 'cuadra' end
                     else 'no_cuadra' end)
    from (select pg_temp.c13_foto(p_cuenta, p_fecha) as n) z
$$;
-- (solo la diferencia y el estado de lo que cambió: donde el libro y el
-- auxiliar se mueven también por lo que la base ya traía —el ajuste del WIP
-- con las obras de verdad, la depreciación de los activos de verdad—)
create or replace function pg_temp.c13_dif(p_foto jsonb, p_cuenta text, p_fecha date) returns text language sql as $$
  select regexp_replace(pg_temp.c13_cambio(p_foto, p_cuenta, p_fecha), '^libro .* \| aux .* \| (dif .*)$', '\1')
$$;
-- Una columna de la fila de una cuenta a una fecha, por su nombre (así este
-- archivo corre también contra una capa que todavía no la tenga: sale «-»).
create or replace function pg_temp.c13_col(p_cuenta text, p_fecha date, p_col text) returns text language sql as $$
  select coalesce((select to_jsonb(c)->>p_col from fn_cedula(p_fecha) c where c.cuenta = p_cuenta), '-')
$$;
-- Un renglón del auxiliar de una cuenta a una fecha, buscado por su concepto
-- (LIKE): clase: concepto = monto (y libro, ok donde los hay).
create or replace function pg_temp.c13_renglon(p_cuenta text, p_fecha date, p_como text) returns text language sql as $$
  select coalesce((select string_agg(format('%s: %s = %s%s%s', i.clase, i.concepto, coalesce(i.monto::text, '-'),
                                            coalesce(' (libro ' || i.libro || ')', ''),
                                            case i.ok when true then ' ok' when false then ' NO' else '' end), ' ; ' order by i.n)
                     from fn_cedula_partidas(p_fecha, p_cuenta) i where i.concepto like p_como), 'no sale')
$$;
-- Como el dueño por la API: un renglón, explicar, la configuración. Al
-- volver, otra vez el SQL Editor.
create or replace function pg_temp.c13_renglon_pon(p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c13_ser('dueno');
  r := fn_cedula_renglon(p);
  perform pg_temp.c13_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c13_explicar(p_cuenta text, p_fecha date, p_texto text) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c13_ser('dueno');
  r := fn_cedula_explicar(p_cuenta, p_fecha, p_texto);
  perform pg_temp.c13_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c13_config(p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c13_ser('dueno');
  r := fn_cedula_config(p);
  perform pg_temp.c13_ser('editor');
  return r;
end $$;
-- Una fila del control de la cédula del mes de las pruebas: 'verde' o 'rojo', y su detalle.
create or replace function pg_temp.c13_ctl(p_orden int, p_per text default null) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from fn_cedula_control(coalesce(p_per, pg_temp.c13('mes'))) c where c.orden = p_orden
$$;
create or replace function pg_temp.c13_ctl_det(p_orden int, p_per text default null) returns text language sql as $$
  select c.detalle from fn_cedula_control(coalesce(p_per, pg_temp.c13('mes'))) c where c.orden = p_orden
$$;
-- (cuántas cuentas —o renglones— tiene en rojo un aviso del control: el
-- número con que empieza su detalle; 0 si está en verde. Con los datos de la
-- base puede no ser cero antes de la prueba: se mira lo que la prueba mueve.)
create or replace function pg_temp.c13_ctl_n(p_orden int, p_per text default null) returns int language sql as $$
  select case when c.ok then 0 else coalesce(substring(c.detalle from '^([0-9]+) ')::int, -1) end
    from fn_cedula_control(coalesce(p_per, pg_temp.c13('mes'))) c where c.orden = p_orden
$$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los estados
-- (c4, hoy y al último día del mes de las pruebas), los cuadres de la IA
-- (c8), los del jornal y el margen (c10), los de las facturas (c11), los del
-- WIP (c12) y lo que detiene el cierre del mes de las pruebas (c9). Lo que no
-- está, no se mira. Como el SQL Editor.
create or replace function pg_temp.c13_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c13_ser('editor');
  select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
  v := v || x;
  if to_regprocedure('public.fn_banco_control(text,text[])') is not null then
    execute $q$ select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') from public.fn_banco_control('hoy') k where not k.ok $q$ into x;
    v := v || x;
  end if;
  if to_regprocedure('public.fn_estados_control(text,text[])') is not null then
    execute $q$ select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') from public.fn_estados_control('hoy') k where not k.ok $q$ into x;
    v := v || x;
    if pg_temp.c13('mes') is not null then
      execute $q$ select coalesce(array_agg('c4 del mes: ' || k.vista order by k.vista), '{}') from public.fn_estados_control($1) k where not k.ok $q$
         into x using pg_temp.c13('mes');
      v := v || x;
    end if;
  end if;
  if pg_temp.c13('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden order by k.orden), '{}') from public.v_contador_control k
                 where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c13('hay_c10') = 'true' then
    execute $q$ select coalesce(array_agg(k.c order by k.c), '{}')
                  from (select 'c10: jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                        union all
                        select 'c10: margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c13('hay_c11') = 'true' then
    execute $q$ select coalesce(array_agg('c11: ' || k.orden order by k.orden), '{}') from public.v_emision_control k
                 where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c13('hay_c12') = 'true' and pg_temp.c13('mes') is not null then
    execute $q$ select coalesce(array_agg('c12: ' || k.orden order by k.orden), '{}') from public.fn_wip_control($1) k
                 where k.nivel = 'cuadre' and not k.ok $q$ into x using pg_temp.c13('mes');
    v := v || x;
  end if;
  if pg_temp.c13('hay_c9') = 'true' and pg_temp.c13('mes') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}') from public.fn_cierre_revisar($1) k
                 where k.nivel = 'detiene' and k.ok is distinct from true $q$ into x using pg_temp.c13('mes');
    v := v || x;
  end if;
  return v;
end $$;
-- (LO MISMO, SIN DEJAR NADA: la revisión del cierre de c9 guarda lo que
-- encuentra en su tabla, con su hora. Se lee dentro de un bloque que se
-- deshace —y con el reloj de las pruebas, si esta base lo pide—: estas
-- pruebas no dejan nada, ni eso.)
create or replace function pg_temp.c13_rojos_limpio() returns text[] language plpgsql as $$
declare
  v text[];
begin
  begin
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_reloj();
    v := pg_temp.c13_rojos();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null;
  end;
  return v;
end $$;
-- lo que está en la segunda lista y no en la primera (los rojos NUEVOS), en una línea
create or replace function pg_temp.c13_nuevos(p_antes text[], p_despues text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_despues) x where x <> all (p_antes)
$$;

-- (las funciones AJENAS a c13 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 41
-- las dicen y no las cuentan como fallo de c13.)
create or replace function pg_temp.c13_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c13
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c13_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c13: %';
-- «permisos» de c2 sin contar lo ajeno de antes: 'verde' o 'rojo: …'
create or replace function pg_temp.c13_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c13_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c13('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c13_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;

-- (la huella de las revisiones del cierre guardadas por c9: «no hay» si c9 no está)
create or replace function pg_temp.c13_revisiones() returns text language plpgsql as $$
declare
  v text := 'no hay';
begin
  if to_regclass('public.cierre_revisiones') is not null then
    execute 'select md5(coalesce(string_agg(md5(r::text), '''' order by md5(r::text)), '''')) from public.cierre_revisiones r' into v;
  end if;
  return v;
end $$;
-- LOS CONTEOS de lo que las pruebas tocan (nada queda).
create or replace function pg_temp.c13_conteos() returns text language sql as $$
  select concat_ws(' ',
    'config', (select md5(coalesce(string_agg(to_jsonb(c)::text, '|'), '')) from cedula_config c),
    'manual', (select count(*) from cedula_manual), 'explicaciones', (select count(*) from cedula_explicaciones),
    'asientos', (select count(*) from asientos), 'lineas', (select count(*) from asiento_lineas),
    'contadores', (select coalesce(sum(ultimo), 0) from contadores),
    'cuentas', (select count(*) from cuentas), 'obras', (select count(*) from proyectos), 'fichas', (select count(*) from finanzas_proyecto),
    'facturas', (select count(*) from facturas), 'cobros', (select count(*) from cobros), 'proveedores', (select count(*) from proveedores),
    'tarjetas', (select count(*) from tarjetas), 'tipos confirmados', (select count(*) from mapeo_tipo_proyecto where confirmado_el is not null),
    'cerrados', (select count(*) from periodos where estado = 'cerrado'),
    'revisiones del cierre', pg_temp.c13_revisiones(),
    'el reloj', left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12),
    'funciones', (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
create or replace function pg_temp.c13_conteos_capas() returns text language plpgsql as $$
declare
  v text := '';
  n bigint;
  t text;
begin
  foreach t in array array['conciliaciones', 'conciliacion_partidas', 'movimientos_banco', 'archivos_banco', 'prestamos', 'prestamo_cuotas',
                           'prepagados', 'prepagados_amortizaciones', 'activos_fijos', 'activos_depreciaciones', 'wip_ajustes',
                           'wip_revisiones', 'stripe_pagos', 'comparacion_qb', 'diferencias', 'apertura_mapeo_qb'] loop
    if to_regclass('public.' || t) is not null then
      execute format('select count(*) from public.%I', t) into n;
      v := v || ' ' || t || ' ' || n;
    end if;
  end loop;
  return v;
end $$;
insert into _c13 values ('conteos', pg_temp.c13_conteos() || pg_temp.c13_conteos_capas());

-- (lo de las otras capas que ya estaba en rojo ANTES de las pruebas: la 41 lo dice y no lo cuenta)
insert into _c13 select 'rojos_antes', array_to_string(pg_temp.c13_rojos_limpio(), chr(31));
create or replace function pg_temp.c13_rojos_antes() returns text[] language sql as $$
  select coalesce(string_to_array(nullif(pg_temp.c13('rojos_antes'), ''), chr(31)), '{}'::text[])
$$;

-- LAS CAPAS FINGIDAS (la 25): la función de c13 que dice qué capas hay pasa
-- a decir lo que se le pida. Solo DENTRO de la subtransacción de una prueba:
-- su MXT00 lo deshace. (El reloj fingido, c13_reloj, está arriba.)
create or replace function pg_temp.c13_fingir_capas(p jsonb) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_cedula_capas() returns jsonb
    language sql stable
    set search_path = public, pg_temp
    as $b$ select %L::jsonb $b$
  $f$, p::text);
end $$;


-- LA NÓMINA (c15) EN LAS PRUEBAS (13-nov, Fase 11b). Tres maneras, todas
-- DENTRO de la subtransacción de una prueba (su MXT00 las deshace), y sin
-- tocar nada de c15:
--   c13_sin_nomina()    la función de c13 que dice qué capas hay contesta lo
--                       de verdad con c15 en falso (lo llama c13_sembrar: las
--                       pruebas de siempre corren así). A quien no es el
--                       dueño, {} como siempre.
--   c13_con_nomina()    c15 en verdadero, y la función de c13 que LEE la
--                       nómina (fn_cedula_nomina) pasa a leer _c13_nomina: lo
--                       que cada nómina de prueba dejó por pagar, por fechas.
--                       Hace lo que la de verdad: sin ninguna nómina de
--                       prueba en el libro no tapa nada; con alguna y sin el
--                       código del teléfono, «codigo»; al equipo, {}.
--   c13_capas_reales()  la función de las capas, otra vez la de verdad (la 46
--                       y la 47 leen la nómina sin fingir).
-- _c13_nomina: lo que la nómina fingida dice de una cuenta entre dos días
-- (hasta vacío = sigue): la corrida (el id del asiento de su journal), su
-- día de pago, lo que su journal dejó por pagar (acreditado) y lo que sus
-- cargos casados ya pagaron (pagado); el saldo es la resta.
create temp table if not exists _c13_nomina (desde date, hasta date, cuenta text, corrida uuid, dia_pago date, descripcion text,
                                             acreditado numeric, pagado numeric, asiento text, cargos text);
truncate _c13_nomina;
grant select on _c13_nomina to public;
create or replace function pg_temp.c13_capas_fingidas(p jsonb) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_cedula_capas() returns jsonb
    language sql stable
    set search_path = public, pg_temp
    as $b$ select case when not public.fn_cedula_ve() then '{}'::jsonb else %L::jsonb end $b$
  $f$, p::text);
end $$;
create or replace function pg_temp.c13_sin_nomina() returns void language plpgsql as $$
begin
  perform pg_temp.c13_capas_fingidas(coalesce(pg_temp.c13('capas'), '{}')::jsonb || '{"c15": false}'::jsonb);
end $$;
create or replace function pg_temp.c13_capas_reales() returns void language plpgsql as $$
begin
  execute pg_temp.c13('capas_def');
end $$;
create or replace function pg_temp.c13_con_nomina() returns void language plpgsql as $$
begin
  perform pg_temp.c13_ser('editor');
  delete from _c13_nomina;
  perform pg_temp.c13_capas_fingidas(coalesce(pg_temp.c13('capas'), '{}')::jsonb || '{"c15": true}'::jsonb);
  execute $f$
    create or replace function public.fn_cedula_nomina(p_fecha date default null) returns jsonb
    language sql stable
    set search_path = public, pg_temp
    as $b$
      select case
        when not public.fn_cedula_ve() then '{}'::jsonb
        when not exists (select 1 from public.asientos a where a.origen_tabla = 'nomina_corridas' and a.descripcion like 'C13 PRUEBA: %')
          then jsonb_build_object('estado', 'ok', 'nominas', false, 'filas', '[]'::jsonb)
        when current_user in ('authenticated', 'anon', 'service_role')
             and coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'aal', '') <> 'aal2'
          then jsonb_build_object('estado', 'codigo', 'nominas', true)
        when p_fecha is null then jsonb_build_object('estado', 'ok', 'nominas', true)
        else jsonb_build_object('estado', 'ok', 'nominas', true, 'filas',
               (select coalesce(jsonb_agg(jsonb_build_object('cuenta', n.cuenta, 'corrida', n.corrida, 'dia_pago', n.dia_pago,
                                 'descripcion', n.descripcion, 'acreditado', n.acreditado, 'pagado', n.pagado, 'saldo', n.acreditado - n.pagado,
                                 'asiento', n.asiento, 'cargos', n.cargos) order by n.cuenta, n.dia_pago, n.corrida), '[]'::jsonb)
                  from _c13_nomina n
                 where p_fecha >= n.desde and (n.hasta is null or p_fecha <= n.hasta) and n.acreditado - n.pagado <> 0))
      end
    $b$
  $f$;
end $$;
-- EL JOURNAL DE UNA NÓMINA DE PRUEBA, como lo deja el puente de la nómina: un
-- asiento con origen «nomina_corridas» (desde el SQL Editor, por la puerta
-- interna de c2, la única que deja decir de qué papel sale un asiento).
-- Devuelve su id (hace de «corrida»). p_reversible: para ver que ni marcado
-- como los devengos cuenta como devengo.
create or replace function pg_temp.c13_journal(p_fecha date, p_que text, p_lineas jsonb, p_reversible boolean default false)
returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c13_ser('editor');
  r := fn_postear_interno(jsonb_strip_nulls(jsonb_build_object('camino', 'puente', 'fecha', p_fecha::text,
         'descripcion', 'C13 PRUEBA: ' || p_que || ' (se deshace)', 'lineas', p_lineas,
         'origen_tabla', 'nomina_corridas', 'origen_id', gen_random_uuid()::text, 'reversible', case when p_reversible then true end)));
  return (r->>'id')::uuid;
end $$;
-- (lo que la nómina fingida dice de una cuenta entre dos días)
create or replace function pg_temp.c13_nomina_dice(p_desde date, p_hasta date, p_cuenta text, p_corrida uuid, p_dia_pago date,
                                                   p_acreditado numeric, p_pagado numeric, p_cargos text default null)
returns void language sql as $$
  insert into _c13_nomina (desde, hasta, cuenta, corrida, dia_pago, descripcion, acreditado, pagado, asiento, cargos)
  values (p_desde, p_hasta, p_cuenta, p_corrida, p_dia_pago, 'C13 PRUEBA Nómina del ' || fn_cedula_dia(p_dia_pago), p_acreditado, p_pagado,
          (select a.numero from asientos a where a.id = p_corrida), p_cargos)
$$;
-- (¿algún texto de la cédula nombra una función, una tabla o una vista? Los mismos patrones que la 31: 'ninguno' o cuáles)
create or replace function pg_temp.c13_llano(p_txt text[]) returns text language sql as $$
  select coalesce(string_agg(left(t, 160), ' || ') filter (where t ~ '(fn_|cedula_|v_cedula|mx_|select |\(\)|security|jsonb|null)'), 'ninguno')
    from unnest(p_txt) t
$$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, las 25 funciones por su
--    nombre exacto, la configuración (una fila) y cada objeto con su
--    comentario «c13: …».
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 3 tablas | 5 vistas | 25 funciones (25 nombres) | sin comentario c13: ninguno | configuración: 1 fila, id 1';
begin
  begin
    perform pg_temp.c13_ser('editor');
    v_pre := coalesce(fn_cedula_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c13_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c13_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(proname);
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c13_tablas()) or c.relname = any (pg_temp.c13_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c13: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(p.proname)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c13: %') x;
    select format('%s fila, id %s', count(*), min(c.id)) into v_cfg from cedula_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c13: %s | configuración: %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 3 tablas, 5 vistas, las 25 funciones por su nombre exacto, la configuración (una fila) y cada objeto con su comentario «c13: …»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c2 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c13
--    que no lleva su comentario (no es de c13: no se pisa); una vista ajena
--    colgada de una vista de c13 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin fn_libro_version: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    v_a := pg_temp.c13_estado('select public.fn_cedula_precondiciones()', 'dueno');
    begin
      drop function public.fn_libro_version();
      v_b := coalesce(fn_cedula_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_cedula_cierre(text) is 'otra cosa';
      v_c := coalesce(fn_cedula_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c13_prueba_ajena as select c.cuenta from public.v_cedula c;
      v_d := coalesce(fn_cedula_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin fn_libro_version: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%falta%fn_libro_version()%' then 'la nombra' else coalesce(v_b, 'nulo') end,
                    case when v_c like '%con nombre de c13 y sin ser de c13%fn_cedula_cierre(text)%No lo piso%' then 'la nombra y no la pisa'
                         else coalesce(v_c, 'nulo') end,
                    case when v_d like '%c13_prueba_ajena%depende%' then 'la nombra' else coalesce(v_d, 'nulo') end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se instala (42501); sin una función de c2 la nombra; una función con nombre de c13 que no lleva su comentario no se pisa; una vista ajena colgada de una vista de c13 se nombra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. La API: las de la pantalla, solo authenticated; las internas, nadie;
--    anon y service_role no ejecutan ni leen nada; el equipo (alguien que no
--    es el dueño, con un renglón y una explicación ya en la base) recibe
--    42501 de las seis que escriben o resumen y cero filas de las tres
--    tablas, las cinco vistas y las siete funciones de lectura, y ni
--    siquiera se entera de qué partes de la contabilidad están instaladas;
--    el dueño entra y ve. (No postea nada: el renglón y la explicación son
--    de hoy, en una cuenta de prueba. Corre también con todos los meses
--    cerrados.)
do $$
declare
  v_obt text; v_api text; v_sin text; v_anon text; v_srv text; v_n int := 0; v_filas bigint := 0; v_k bigint; v_due text; v_x text;
  v_hoy date := pg_temp.c13('hoy')::date; v_per text := coalesce(pg_temp.c13('mes'), pg_temp.c13('en_curso')); v_id uuid; v_cap text;
  v_esp text := 'pantalla mal: ninguna | internas con API: ninguna | anon 42501 y 42501 | service_role 42501 y 42501 | '
                'equipo: 6 de 6 funciones 42501 y 0 filas en 3 tablas, 5 vistas y 7 funciones de lectura, y de qué partes hay instaladas '
                'le sale {} | dueño: su cuenta explicada, 1 renglón suyo, 1 explicación suya, 6 controles y 1 fila del cierre, y sabe qué '
                'partes hay: sí';
begin
  if pg_temp.c13_omitir(3, 'la API por rol', v_esp, array['cuentas']) then return; end if;
  if pg_temp.c13('equipo') is null then
    insert into _pruebas values (3, 'la API por rol', v_esp, 'omitida: no hay nadie del equipo (un perfil activo que no sea el dueño) con quien probar', null);
    return;
  end if;
  begin
    perform pg_temp.c13_sembrar();
    v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
                                                        'desde', v_hoy::text, 'documento', 'C13 PRUEBA contrato'))->>'id')::uuid;
    perform pg_temp.c13_explicar('1693', v_hoy, 'C13 PRUEBA: el depósito todavía no está asentado en el libro');
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(p.proname)
       and p.proname not in ('fn_cedula_precondiciones', 'fn_cedula_guarda', 'fn_cedula_pegado')
       and (not has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname in ('fn_cedula_precondiciones', 'fn_cedula_guarda', 'fn_cedula_pegado')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    v_anon := pg_temp.c13_estado('select count(*) from public.v_cedula', 'anon') || ' y '
           || pg_temp.c13_estado('select public.fn_cedula_resumen(null)', 'anon');
    v_srv  := pg_temp.c13_estado('select count(*) from public.cedula_manual', 'service_role') || ' y '
           || pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', v_hoy, 'C13 PRUEBA: desde la llave de servicio'), 'service_role');
    -- el equipo: las seis que escriben o resumen
    foreach v_x in array array[
      'select public.fn_cedula_config(''{}''::jsonb)',
      format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: del equipo', 'monto', '1.00', 'desde', v_hoy::text)),
      format('select public.fn_cedula_renglon_anular(%L, %L)', v_id, 'C13 PRUEBA: del equipo'),
      format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', v_hoy, 'C13 PRUEBA: una explicación del equipo'),
      format('select public.fn_cedula_explicacion_retirar(%L, %L, %L)', '1693', v_hoy, 'C13 PRUEBA: del equipo'),
      format('select public.fn_cedula_resumen(%L)', v_hoy)] loop
      if pg_temp.c13_estado(v_x, 'equipo') = '42501' then v_n := v_n + 1; end if;
    end loop;
    perform pg_temp.c13_ser('equipo');
    foreach v_x in array array[
      'select count(*) from public.cedula_config', 'select count(*) from public.cedula_manual', 'select count(*) from public.cedula_explicaciones',
      'select count(*) from public.v_cedula', 'select count(*) from public.v_cedula_control', 'select count(*) from public.v_cedula_manual',
      'select count(*) from public.v_cedula_explicaciones', 'select count(*) from public.v_cedula_qb',
      format('select count(*) from public.fn_cedula(%L)', v_hoy), format('select count(*) from public.fn_cedula_partidas(%L, null)', v_hoy),
      'select count(*) from public.fn_cedula_cuentas()', format('select count(*) from public.fn_cedula_control(%L)', v_per),
      format('select count(*) from public.fn_cedula_cierre(%L)', v_per), format('select count(*) from public.fn_cedula_qb(%L)', v_per),
      'select count(*) from public.fn_cedula_qb_periodos()'] loop
      execute v_x into v_k;
      v_filas := v_filas + v_k;
    end loop;
    v_cap := fn_cedula_capas()::text;
    perform pg_temp.c13_ser('dueno');
    select format('su cuenta %s, %s renglón suyo, %s explicación suya, %s controles y %s fila del cierre, y sabe qué partes hay: %s',
                  (select c.estado from fn_cedula(v_hoy) c where c.cuenta = '1693'),
                  (select count(*) from v_cedula_manual m where m.cuenta = '1693' and m.vigente),
                  (select count(*) from v_cedula_explicaciones e where e.cuenta = '1693' and e.viva),
                  (select count(*) from fn_cedula_control(v_per)), (select count(*) from fn_cedula_cierre(v_per)),
                  case when fn_cedula_capas() ?& array['c4', 'c6', 'c9', 'c12', 'p1'] then 'sí' else 'no: ' || fn_cedula_capas()::text end)
      into v_due;
    perform pg_temp.c13_ser('editor');
    v_obt := format('pantalla mal: %s | internas con API: %s | anon %s | service_role %s | equipo: %s de 6 funciones 42501 y %s filas en 3 '
                    'tablas, 5 vistas y 7 funciones de lectura, y de qué partes hay instaladas le sale %s | dueño: %s',
                    v_api, v_sin, v_anon, v_srv, v_n, v_filas, v_cap, v_due);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las funciones de la pantalla solo para authenticated y las internas para nadie; anon y service_role no leen ni ejecutan; el equipo (con un renglón y una explicación ya en la base) recibe 42501 de las seis que escriben o resumen, cero filas de las tablas, las vistas y las funciones de lectura, y no se entera de qué partes de la contabilidad hay instaladas ({}); el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. El catálogo: nada SECURITY DEFINER; ningún nombre con un prefijo de
--    otra capa o de la otra sesión; RLS y sus policies; las vistas
--    security_invoker, que no fijan las columnas de periodos y de cuentas que
--    c2-pruebas reescribe ni cuelgan de vistas ajenas; y «permisos» de c2 y
--    las protecciones de c6 y de c4 en verde con c13 pegado.
do $$
declare
  v_obt text; v_def text; v_pre text; v_rls int; v_pol int; v_inv int; v_col text; v_dep text; v_per text; v_prot text := 'verdes';
  v_esp text := 'definer: ninguna | prefijos de otra capa: ninguno | RLS en 3 de 3 tablas, 8 policies | vistas security_invoker: 5 de 5 | '
                'vistas que fijan columnas que c2 reescribe: ninguna | vistas colgadas de vistas ajenas: ninguna | permisos (c2): verde | '
                'protecciones del banco (c6) y de c4: verdes';
begin
  begin
    perform pg_temp.c13_ser('editor');
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(p.proname) and p.prosecdef;
    select coalesce(string_agg(x.n, ', ' order by x.n), 'ninguno') into v_pre
      from (select p.proname::text as n from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(p.proname)
            union all
            select c.relname::text from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c13_tablas()) or c.relname = any (pg_temp.c13_vistas()))) x
     where x.n ~ '^(fn_banco_|fn_puente_|fn_estados_|fn_stripe_|fn_plaid_|fn_contador_|fn_cierre_|fn_costos_|fn_reporte_|fn_reparto_fase|fn_horas_|fn_jornal_|fn_margen_|fn_cobro_|fn_factura_|fn_anticipo_|fn_doc_|fn_qb_|fn_emision_|fn_wip_|fn_subs_|cxc_|v_cxc_|emision_|v_emision_|wip_|v_wip_|subs_|v_subs_)'
        or x.n !~ '^(fn_cedula$|fn_cedula_|cedula_|v_cedula$|v_cedula_)';
    select count(*) filter (where c.relrowsecurity) into v_rls
      from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c13_tablas());
    select count(*) into v_pol from pg_policies pl where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c13_tablas());
    select count(*) into v_inv
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c13_vistas())
       and coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    -- columnas de periodos y de cuentas que c2-pruebas reescribe, fijadas por una vista de c13
    select coalesce(string_agg(distinct format('%s → %s.%s', cv.relname, rc.relname, a.attname), ', '), 'ninguna') into v_col
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class cv on cv.oid = rw.ev_class
      join pg_class rc on d.refclassid = 'pg_class'::regclass and rc.oid = d.refobjid
      join pg_attribute a on a.attrelid = rc.oid and a.attnum = d.refobjsubid
     where cv.relnamespace = 'public'::regnamespace and cv.relname = any (pg_temp.c13_vistas())
       and ((rc.relname = 'periodos' and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cerrado_rol', 'cerrado_conexion', 'cadena_al_cerrar'))
            or (rc.relname = 'cuentas' and a.attname in ('activa', 'saldo_normal')));
    -- vistas de c13 colgadas de una vista que no es de c13
    select coalesce(string_agg(distinct format('%s → %s', cv.relname, rc.relname), ', '), 'ninguna') into v_dep
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class cv on cv.oid = rw.ev_class
      join pg_class rc on d.refclassid = 'pg_class'::regclass and rc.oid = d.refobjid
     where cv.relnamespace = 'public'::regnamespace and cv.relname = any (pg_temp.c13_vistas())
       and rc.relkind in ('v', 'm') and rc.oid <> cv.oid and not (rc.relname = any (pg_temp.c13_vistas()));
    v_per := pg_temp.c13_permisos();
    if to_regprocedure('public.fn_banco_control(text,text[])') is not null and to_regprocedure('public.fn_estados_control(text,text[])') is not null then
      execute $q$ select case when count(*) filter (where not k.ok) = 0 then 'verdes' else string_agg(k.vista, ', ') filter (where not k.ok) end
                    from (select x.vista, x.ok from public.fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) x
                           where x.vista = 'cuadre: protecciones del banco'
                          union all
                          select y.vista, y.ok from public.fn_estados_control('hoy', array['v_saldos_dinero']) y
                           where y.vista = 'cuadre: protecciones de c4') k $q$ into v_prot;
    end if;
    v_obt := format('definer: %s | prefijos de otra capa: %s | RLS en %s de 3 tablas, %s policies | vistas security_invoker: %s de 5 | '
                    'vistas que fijan columnas que c2 reescribe: %s | vistas colgadas de vistas ajenas: %s | permisos (c2): %s | '
                    'protecciones del banco (c6) y de c4: %s', v_def, v_pre, v_rls, v_pol, v_inv, v_col, v_dep, v_per, v_prot);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: nada SECURITY DEFINER, ningún nombre con prefijo de otra capa ni fuera de fn_cedula/cedula_/v_cedula, RLS y sus 8 policies, las vistas security_invoker que no fijan las columnas que c2-pruebas reescribe ni cuelgan de vistas ajenas, y «permisos» (c2) y las protecciones de c6 y de c4 en verde con c13 pegado',
    v_esp, v_obt || case when pg_temp.c13('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c13: ' || pg_temp.c13('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 5. La guarda de las tablas: a mano (sin la marca) nada entra, ni desde el
--    SQL Editor ni como el dueño por la API; y lo que es rastro (un renglón,
--    una explicación) no se edita ni se borra ni con la marca. (No postea
--    nada: corre también con todos los meses cerrados.)
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text; h text; v_hoy date := pg_temp.c13('hoy')::date;
  v_esp text := 'a mano, sin la marca: insert MX003, update MX003, delete MX003, truncate MX003 | el dueño por la API: MX003 | con la marca, '
                'un renglón no se edita (MX003) ni se borra (MX003), y una explicación tampoco (MX003)';
begin
  if pg_temp.c13_omitir(5, 'la guarda de las tablas', v_esp, array['cuentas']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
                                                       'desde', v_hoy::text));
    perform pg_temp.c13_explicar('1693', v_hoy, 'C13 PRUEBA: el depósito todavía no está asentado en el libro');
    a := pg_temp.c13_estado(format('insert into public.cedula_manual (cuenta, concepto, monto, desde) values (''1693'', ''a mano'', 1, %L)', v_hoy), 'editor');
    b := pg_temp.c13_estado('update public.cedula_config set avisar_desde = null', 'editor');
    c := pg_temp.c13_estado('delete from public.cedula_explicaciones', 'editor');
    d := pg_temp.c13_estado('truncate public.cedula_manual', 'editor');
    e := pg_temp.c13_estado('update public.cedula_config set avisar_desde = null', 'dueno');
    perform set_config('mx_cedula.escribe', 'cedula_manual', true);
    f := pg_temp.c13_estado('update public.cedula_manual set monto = 1 where cuenta = ''1693''', 'editor');
    g := pg_temp.c13_estado('delete from public.cedula_manual where cuenta = ''1693''', 'editor');
    perform set_config('mx_cedula.escribe', 'cedula_explicaciones', true);
    h := pg_temp.c13_estado('update public.cedula_explicaciones set texto = ''otra cosa'' where cuenta = ''1693''', 'editor');
    perform set_config('mx_cedula.escribe', '', true);
    v_obt := format('a mano, sin la marca: insert %s, update %s, delete %s, truncate %s | el dueño por la API: %s | con la marca, un renglón '
                    'no se edita (%s) ni se borra (%s), y una explicación tampoco (%s)', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda de las tablas de c13: a mano (sin la marca de sus funciones) nada entra, ni desde el SQL Editor ni como el dueño por la API (MX003); y lo que es rastro no se edita ni se borra ni con la marca',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. La configuración: sin argumentos la devuelve; cambia desde qué mes
--    avisa (también a «todavía no») y cómo se sostiene el patrimonio; el
--    valor anterior queda en su historial; y sus frenos.
do $$
declare
  v_obt text; v_antes jsonb; v_0 jsonb; v_igual boolean; v_1 jsonb; v_2 jsonb; a text; b text; c text; d text; e text;
  v_esp text := 'sin argumentos: la devuelve sin tocarla | cambia: avisa desde 2027-01 y patrimonio manual; el historial guarda lo de antes: sí | '
                'a «todavía no»: avisa desde nada | frenos: clave desconocida 22023, un mes mal 22023, patrimonio mal 22023, no es un objeto 22023, '
                'el equipo 42501';
begin
  if pg_temp.c13_omitir(6, 'la configuración', v_esp, array[]::text[]) then return; end if;
  begin
    select to_jsonb(c0) into v_antes from cedula_config c0 where c0.id = 1;
    v_0 := pg_temp.c13_config(null);
    v_igual := v_0 = v_antes and pg_temp.c13_config('{}'::jsonb) = v_antes
               and (select to_jsonb(c0) from cedula_config c0 where c0.id = 1) = v_antes;
    v_1 := pg_temp.c13_config('{"avisar_desde": "2027-01", "patrimonio": "manual"}');
    v_2 := pg_temp.c13_config('{"avisar_desde": null}');
    a := pg_temp.c13_estado('select public.fn_cedula_config(''{"color": "rojo"}'')');
    b := pg_temp.c13_estado('select public.fn_cedula_config(''{"avisar_desde": "enero"}'')');
    c := pg_temp.c13_estado('select public.fn_cedula_config(''{"patrimonio": "acta"}'')');
    d := pg_temp.c13_estado('select public.fn_cedula_config(''[1]'')');
    e := case when pg_temp.c13('equipo') is null then '42501' else pg_temp.c13_estado('select public.fn_cedula_config(''{"patrimonio": "manual"}'')', 'equipo') end;
    v_obt := format('sin argumentos: %s | cambia: avisa desde %s y patrimonio %s; el historial guarda lo de antes: %s | a «todavía no»: avisa '
                    'desde %s | frenos: clave desconocida %s, un mes mal %s, patrimonio mal %s, no es un objeto %s, el equipo %s',
                    case when v_igual then 'la devuelve sin tocarla' else 'no: ' || v_0::text end,
                    v_1->>'avisar_desde', v_1->>'patrimonio',
                    case when jsonb_array_length(v_1->'historial') = jsonb_array_length(v_0->'historial') + 1
                              and (v_1->'historial'->-1->>'avisar_desde') is not distinct from (v_0->>'avisar_desde')
                              and (v_1->'historial'->-1->>'patrimonio') = (v_0->>'patrimonio') then 'sí' else 'no: ' || (v_1->'historial')::text end,
                    coalesce(v_2->>'avisar_desde', 'nada'), a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'la configuración de la cédula: sin argumentos la devuelve; cambia desde qué mes avisa el cierre (o «todavía no») y cómo se sostiene el patrimonio, y lo de antes queda en su historial; una clave desconocida, un mes mal escrito, un valor que no existe o algo que no es un objeto, 22023; el equipo, 42501',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. La cédula trae TODAS las cuentas de balance (las activas y las que
--    tienen movimiento), una fila cada una, en su lado natural, y su saldo es
--    el del libro; la de grupo no sale, y una inactiva sin movimiento tampoco.
--    Con un mes donde postear, tres asientos de prueba enseñan el lado
--    natural (un banco, una tarjeta, el patrimonio); con todo cerrado, se
--    mira lo mismo con lo que la base tenga, a hoy.
do $$
declare
  v_obt text; v_con boolean := pg_temp.c13('mes') is not null and pg_temp.c13('mes_sig') is not null;
  v_h date := coalesce(pg_temp.c13_h(), pg_temp.c13('hoy')::date); v_n bigint; v_e bigint; v_s numeric; v_s2 numeric; v_dup bigint; v_grp bigint;
  v_esp text := 'una fila por cuenta de balance, ninguna repetida: sí | la suma de sus saldos (a debe − haber) es la del libro: sí | '
                || case when pg_temp.c13('mes') is not null and pg_temp.c13('mes_sig') is not null
                        then 'el banco de prueba, 100.00 con signo 1; su patrimonio, 100.00 con signo -1; la tarjeta, 30.00 con signo -1'
                        else 'el banco de prueba, 0.00 con signo 1; su patrimonio, 0.00 con signo -1; la tarjeta, 0.00 con signo -1' end
                || ' | cuentas de grupo: 0 | la inactiva sin movimiento: no sale | el control 10: verde';
begin
  if pg_temp.c13_omitir(7, 'todas las cuentas de balance, en su lado', v_esp, array['cuentas']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, activa, regla_obra, regla_cost_code)
    values ('1694', 'C13 PRUEBA inactiva', 'c13 test inactive', 'activo', 'debe', true, false, 'prohibida', 'prohibida');
    if v_con then
      perform pg_temp.c13_dh(pg_temp.c13_d(1), 'un aporte', '1093', '3193', 100);
      perform pg_temp.c13_dh(pg_temp.c13_d(3), 'un cargo de la tarjeta', '6200', '2100-9393', 30);
    end if;
    select count(*), count(*) - count(distinct c.cuenta), coalesce(sum(c.signo * c.saldo_libro), 0) into v_n, v_dup, v_s from fn_cedula(v_h) c;
    select count(*) into v_e from cuentas k
     where k.tipo in ('activo', 'pasivo', 'capital') and k.imputable
       and (k.activa or exists (select 1 from asiento_lineas l join asientos a on a.id = l.asiento_id
                                 where l.cuenta = k.codigo and a.fecha_contable <= v_h));
    select coalesce(sum(l.monto), 0) into v_s2
      from asiento_lineas l join asientos a on a.id = l.asiento_id join cuentas k on k.codigo = l.cuenta
     where k.tipo in ('activo', 'pasivo', 'capital') and a.fecha_contable <= v_h;
    select count(*) into v_grp from fn_cedula(v_h) c join cuentas k on k.codigo = c.cuenta where not k.imputable;
    v_obt := format('una fila por cuenta de balance, ninguna repetida: %s | la suma de sus saldos (a debe − haber) es la del libro: %s | '
                    'el banco de prueba, %s con signo %s; su patrimonio, %s con signo %s; la tarjeta, %s con signo %s | cuentas de grupo: %s | '
                    'la inactiva sin movimiento: %s | el control 10: %s',
                    case when v_n = v_e and v_dup = 0 then 'sí' else format('no: %s filas, %s esperadas, %s repetidas', v_n, v_e, v_dup) end,
                    case when v_s = v_s2 then 'sí' else format('no: %s y %s', v_s, v_s2) end,
                    (select c.saldo_libro from fn_cedula(v_h) c where c.cuenta = '1093'), (select c.signo from fn_cedula(v_h) c where c.cuenta = '1093'),
                    (select c.saldo_libro from fn_cedula(v_h) c where c.cuenta = '3193'), (select c.signo from fn_cedula(v_h) c where c.cuenta = '3193'),
                    (select c.saldo_libro from fn_cedula(v_h) c where c.cuenta = '2100-9393'),
                    (select c.signo from fn_cedula(v_h) c where c.cuenta = '2100-9393'), v_grp,
                    case when exists (select 1 from fn_cedula(v_h) c where c.cuenta = '1694') then 'SALE' else 'no sale' end,
                    (select case when k.ok then 'verde' else 'rojo: ' || k.detalle end
                       from fn_cedula_control(coalesce(pg_temp.c13('mes'), pg_temp.c13('en_curso'))) k where k.orden = 10));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'la cédula trae TODAS las cuentas de balance (activo, pasivo y patrimonio; las activas y las que tienen movimiento), una fila cada una, con su saldo en su lado natural (signo lo pasa a debe − haber) y la suma es la del libro; la de grupo y una inactiva sin movimiento no salen; el control 10 lo vigila',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 8. CUENTAS POR COBRAR (1110), por factura. Una factura de 1,000 cobrada a
--    medias (400): el auxiliar la trae por 600 y la cuenta sube lo mismo. A
--    una fecha anterior al cobro, por los 1,000. Un asiento a mano sin
--    factura (123.45): no está en el auxiliar: es la diferencia, y se dice.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_cxc text; f0 jsonb; f1 jsonb; v_fac bigint; a text; b text; c text; d text; e text; g text;
  v_s0 numeric; v_n0 int;
  v_esp text := 'la factura cobrada a medias: libro +600.00 | aux +600.00 | dif +0.00 | cuadra; su renglón: auxiliar: Factura #C13-1 = 600.00, '
                'en su obra: sí | antes del cobro: auxiliar: Factura #C13-1 = 1000.00 | un asiento a mano sin factura: libro +123.45 | aux +0.00 | '
                'dif +123.45 | no_cuadra; suelto +123.45; lo dice: sí; qué hacer: sí | lo suelto sale por obra: sin obra +123.45, y en la obra A 10.00 '
                '(2 líneas más)';
begin
  if pg_temp.c13_omitir(8, 'cuentas por cobrar por factura', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_cxc := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc'), '1110');
    f0 := pg_temp.c13_foto(v_cxc, v_h);
    v_fac := pg_temp.c13_factura(1, 'c13-prueba-a', 1000, 5);
    perform pg_temp.c13_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c13_d(10)::text, 'monto', '400.00', 'cuenta', '1093', 'medio', 'cheque',
              'referencia', 'C13-PRUEBA-1', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', v_fac, 'monto', '400.00'))));
    perform pg_temp.c13_ser('editor');
    a := pg_temp.c13_cambio(f0, v_cxc, v_h);
    b := pg_temp.c13_renglon(v_cxc, v_h, 'Factura #C13-1');
    c := case when (select i.grupo from fn_cedula_partidas(v_h, v_cxc) i where i.concepto = 'Factura #C13-1') = 'C13 PRUEBA Obra A' then 'sí' else 'no' end;
    d := pg_temp.c13_renglon(v_cxc, pg_temp.c13_d(7), 'Factura #C13-1');
    f1 := pg_temp.c13_foto(v_cxc, v_h);
    -- (lo que esta base ya traía suelto en la cuenta: sin obra, y cuántas líneas en total)
    select coalesce(sum(i.libro) filter (where i.clave = 'suelto'), 0), coalesce(sum(substring(i.nota from '^([0-9]+) línea')::int), 0)
      into v_s0, v_n0 from fn_cedula_partidas(v_h, v_cxc) i where i.clase = 'suelto';
    perform pg_temp.c13_dh(pg_temp.c13_d(12), 'una cuenta por cobrar a mano, sin factura', v_cxc, '3100', 123.45);
    e := format('%s; suelto %s; lo dice: %s; qué hacer: %s', pg_temp.c13_cambio(f1, v_cxc, v_h),
                to_char((pg_temp.c13_foto(v_cxc, v_h)->>'s')::numeric - (f1->>'s')::numeric, 'FMS999999990.00'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxc) like '%están en el libro sin decir de qué factura son%' then 'sí' else 'no' end,
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = v_cxc) like '%no dicen de qué factura son%' then 'sí' else 'no' end);
    -- otro, también sin factura, pero con su obra: lo suelto sale obra por obra
    perform pg_temp.c13_dh(pg_temp.c13_d(13), 'otra cuenta por cobrar a mano, sin factura y con su obra', v_cxc, '3100', 10, 'c13-prueba-a');
    g := format('sin obra %s, y en la obra A %s (%s líneas más)',
                to_char((select coalesce(sum(i.libro), 0) from fn_cedula_partidas(v_h, v_cxc) i where i.clase = 'suelto' and i.clave = 'suelto'
                                                                                               and i.grupo = 'Sin obra') - v_s0, 'FMS999999990.00'),
                coalesce((select i.libro::text from fn_cedula_partidas(v_h, v_cxc) i
                           where i.clase = 'suelto' and i.clave = 'suelto:c13-prueba-a' and i.grupo = 'C13 PRUEBA Obra A'
                             and i.ref_tabla = 'proyectos' and i.ref_id = 'c13-prueba-a' and i.monto is null), 'no sale'),
                (select substring(x.detalle from '\(([0-9]+) línea\(s\)\)')::int from fn_cedula(v_h) x where x.cuenta = v_cxc) - v_n0);
    v_obt := format('la factura cobrada a medias: %s; su renglón: %s, en su obra: %s | antes del cobro: %s | un asiento a mano sin factura: %s | '
                    'lo suelto sale por obra: %s', a, b, c, d, e, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'CUENTAS POR COBRAR (1110), por factura: una factura de 1,000 cobrada a medias sale en el auxiliar por los 600 que faltan y la cuenta sube lo mismo (cuadra); a una fecha anterior al cobro, por los 1,000; un asiento a mano sin factura (123.45) no está en el auxiliar: es la diferencia, al centavo, y la fila lo dice; y lo que va sin factura sale aparte obra por obra (así llega de QuickBooks el saldo de la apertura)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. LA RETENCIÓN POR COBRAR (1120), por obra y factura. Una factura de
--    2,000 con 200 retenidos: 1,800 a cobrar y 200 a retención. Cobrados los
--    1,800, la retención sigue abierta: el auxiliar de la 1120 la trae por
--    200, en su obra; la de cobrar ya no la trae.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_cxc text; v_ret text; f0 jsonb; g0 jsonb; v_fac bigint;
  v_esp text := 'la retención: libro +200.00 | aux +200.00 | dif +0.00 | cuadra; su renglón: auxiliar: Factura #C13-2 = 200.00, en su obra: sí | '
                'la de cobrar, cobrada entera: libro +0.00 | aux +0.00 | dif +0.00 | cuadra; su renglón: no sale';
begin
  if pg_temp.c13_omitir(9, 'la retención por cobrar por obra', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_cxc := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc'), '1110');
    v_ret := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc'), '1120');
    f0 := pg_temp.c13_foto(v_ret, v_h);
    g0 := pg_temp.c13_foto(v_cxc, v_h);
    v_fac := pg_temp.c13_factura(2, 'c13-prueba-a', 2000, 6, 200);
    perform pg_temp.c13_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c13_d(15)::text, 'monto', '1800.00', 'cuenta', '1093', 'medio', 'cheque',
              'referencia', 'C13-PRUEBA-2', 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', v_fac, 'monto', '1800.00'))));
    perform pg_temp.c13_ser('editor');
    v_obt := format('la retención: %s; su renglón: %s, en su obra: %s | la de cobrar, cobrada entera: %s; su renglón: %s',
                    pg_temp.c13_cambio(f0, v_ret, v_h), pg_temp.c13_renglon(v_ret, v_h, 'Factura #C13-2'),
                    case when (select i.grupo from fn_cedula_partidas(v_h, v_ret) i where i.concepto = 'Factura #C13-2') = 'C13 PRUEBA Obra A' then 'sí' else 'no' end,
                    pg_temp.c13_cambio(g0, v_cxc, v_h), pg_temp.c13_renglon(v_cxc, v_h, 'Factura #C13-2'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'LA RETENCIÓN POR COBRAR (1120), por obra y factura: una factura de 2,000 con 200 retenidos, cobrados sus 1,800: la retención sigue abierta y el auxiliar de la 1120 la trae por 200 en su obra (cuadra); la de cobrar, cobrada entera, ya no la trae',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. CUENTAS POR PAGAR (2010), por proveedor. A un supply se le deben 500
--     y se le pagan 200: el auxiliar lo trae por 300, con su nombre. Un
--     asiento sin proveedor ni papel (77.77) no está en el auxiliar: es la
--     diferencia. Y la fila dice lo que hay debajo: las partidas del propio
--     libro (cada línea con su proveedor), no el statement del supply.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_cxp text; v_prov uuid; f0 jsonb; f1 jsonb; a text; b text; c text;
  v_esp text := 'pagada a medias: libro +300.00 | aux +300.00 | dif +0.00 | cuadra; su renglón: auxiliar: ZZ C13 PRUEBA SUPPLY = 300.00; '
                'la sostienen las partidas del propio libro, y dice que el statement del supply se compara a mano: sí | '
                'antes del pago: auxiliar: ZZ C13 PRUEBA SUPPLY = 500.00 | un asiento sin proveedor: libro +77.77 | aux +0.00 | dif +77.77 | '
                'no_cuadra; lo dice: sí';
begin
  if pg_temp.c13_omitir(10, 'cuentas por pagar por proveedor', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_cxp := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp'), '2010');
    select pr.id into v_prov from proveedores pr where pr.nombre = 'ZZ C13 PRUEBA SUPPLY';
    f0 := pg_temp.c13_foto(v_cxp, v_h);
    perform pg_temp.c13_asiento(pg_temp.c13_d(3), 'material a cuenta del supply', jsonb_build_array(
              jsonb_build_object('cuenta', '5100', 'monto', '500.00', 'proyecto_id', 'c13-prueba-a'),
              jsonb_build_object('cuenta', v_cxp, 'monto', '-500.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text)));
    perform pg_temp.c13_asiento(pg_temp.c13_d(18), 'un pago a cuenta al supply', jsonb_build_array(
              jsonb_build_object('cuenta', v_cxp, 'monto', '200.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text),
              jsonb_build_object('cuenta', '1093', 'monto', '-200.00')));
    a := format('%s; su renglón: %s; la sostienen las partidas del propio libro, y dice que el statement del supply se compara a mano: %s',
                pg_temp.c13_cambio(f0, v_cxp, v_h), pg_temp.c13_renglon(v_cxp, v_h, 'ZZ C13 PRUEBA SUPPLY'),
                case when pg_temp.c13_col(v_cxp, v_h, 'sosten') = 'partidas'
                      and (select k.origen from fn_cedula_cuentas() k where k.cuenta = v_cxp)
                          like '%Es lo que se compara A MANO con el statement de cada supply: la cédula no lo hace.'
                      and ((select x.estado from fn_cedula(v_h) x where x.cuenta = v_cxp) <> 'cuadra'
                           or (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxp)
                              like '%Sale de las partidas del propio libro: dice que cada línea tiene su proveedor o su papel y que nada queda suelto, no que case con un papel de fuera.')
                     then 'sí' else 'no' end);
    b := pg_temp.c13_renglon(v_cxp, pg_temp.c13_d(10), 'ZZ C13 PRUEBA SUPPLY');
    f1 := pg_temp.c13_foto(v_cxp, v_h);
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'una cuenta por pagar a mano, sin proveedor', '6200', v_cxp, 77.77);
    c := format('%s; lo dice: %s', pg_temp.c13_cambio(f1, v_cxp, v_h),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxp) like '%están en el libro sin decir a quién se le deben%' then 'sí' else 'no' end);
    v_obt := format('pagada a medias: %s | antes del pago: %s | un asiento sin proveedor: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'CUENTAS POR PAGAR (2010), por proveedor: a un supply se le deben 500 y se le pagan 200: el auxiliar lo trae con su nombre por los 300 que faltan (cuadra: por las partidas del propio libro, y lo dice; el statement del supply se compara a mano), y a una fecha anterior al pago, por los 500; un asiento sin proveedor ni papel (77.77) no está en el auxiliar: es la diferencia, al centavo, y la fila lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. UN BANCO contra su conciliación confirmada. En el banco de prueba: un
--     depósito de 1,000 y un cheque de 200 que el banco todavía no trae; la
--     conciliación al último día del mes (el statement dice 0.00) se confirma
--     con los dos en tránsito. La cédula de ese día cuadra: 800 = 0 + 1,000 −
--     200, partida por partida. Lo que pasa DESPUÉS (50 el mes siguiente) no
--     cambia la de ese día; en la de una fecha posterior es la diferencia, y
--     se dice. A una fecha ANTERIOR, esa conciliación no comprueba el día: se
--     llega quitándole lo que el propio libro movió hasta el corte, así que
--     la resta da cero por construcción; la cédula no dice «cuadra» sino «del
--     libro» (no pide nada, y dice cómo comprobarlo). Y un asiento que entra
--     después con fecha anterior al corte (7) descuadra la de ese día.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_c jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'conciliada al último día: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | cuadra, con 3 renglones y su fecha: sí | '
                'sus renglones: auxiliar: Lo que dice el statement al … = 0.00 ; auxiliar: Depósito en tránsito… = 1000.00 ; auxiliar: Cheque o '
                'cargo en circulación… = -200.00 | lo de después no la cambia: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | cuadra | '
                'a una fecha posterior: conciliacion | libro 850.00 | aux 800.00 | dif 50.00 | no_cuadra (pendiente), después 50.00, lo dice: sí | '
                'a una fecha anterior a su conciliación: conciliacion | libro 1000.00 | aux 1000.00 | dif 0.00 | del_libro, y dice que '
                'no comprueba ese día y cómo comprobarlo: sí | '
                'un asiento que entra después con fecha anterior: conciliacion | libro 807.00 | aux 800.00 | dif 7.00 | no_cuadra (pendiente), lo dice: sí';
begin
  if pg_temp.c13_omitir(11, 'un banco contra su conciliación', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito', '1093', '3193', 1000);
    perform pg_temp.c13_dh(pg_temp.c13_d(19), 'el cheque 9301', '6200', '1093', 200);
    v_c := fn_conciliar('1093', v_h, '0.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    a := format('%s, con %s renglones y su fecha: %s', pg_temp.c13_fila('1093', v_h),
                (select x.renglones from fn_cedula(v_h) x where x.cuenta = '1093'),
                case when (select x.auxiliar_al from fn_cedula(v_h) x where x.cuenta = '1093') = v_h then 'sí' else 'no' end);
    select string_agg(format('%s: %s = %s', i.clase, regexp_replace(regexp_replace(i.concepto, ' al [0-9]+-[a-z]+-[0-9]+$', ' al …'), ': C13 PRUEBA.*$', '…'), i.monto),
                      ' ; ' order by i.n) into b
      from fn_cedula_partidas(v_h, '1093') i;
    perform pg_temp.c13_dh(v_h + 2, 'un depósito del mes siguiente', '1093', '3193', 50);
    c := pg_temp.c13_fila('1093', v_h);
    d := format('%s, después %s, lo dice: %s', pg_temp.c13_fila('1093', v_h + 5),
                (select x.despues from fn_cedula(v_h + 5) x where x.cuenta = '1093'),
                case when (select x.detalle from fn_cedula(v_h + 5) x where x.cuenta = '1093') like '%después el libro movió $50.00 (1 línea(s)): falta conciliar hasta el%'
                          and (select x.auxiliar_al from fn_cedula(v_h + 5) x where x.cuenta = '1093') = v_h then 'sí' else 'no' end);
    e := format('%s, y dice que no comprueba ese día y cómo comprobarlo: %s', pg_temp.c13_fila('1093', pg_temp.c13_d(10)),
                case when pg_temp.c13_col('1093', pg_temp.c13_d(10), 'sosten') = 'llevado'
                      and (select x.detalle from fn_cedula(pg_temp.c13_d(10)) x where x.cuenta = '1093') like '%así que no comprueba el saldo de ESTE día.'
                      and (select x.que_hacer from fn_cedula(pg_temp.c13_d(10)) x where x.cuenta = '1093')
                          like 'No pide nada. Para comprobar el saldo de este día, concilia la cuenta al %'
                     then 'sí' else 'no' end);
    perform pg_temp.c13_dh(pg_temp.c13_d(25), 'un depósito que entra tarde, con fecha de antes del corte', '1093', '3193', 7);
    f := format('%s, lo dice: %s', pg_temp.c13_fila('1093', v_h),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '1093') like '%se confirmó con otro saldo en el libro%' then 'sí' else 'no' end);
    v_obt := format('conciliada al último día: %s | sus renglones: %s | lo de después no la cambia: %s | a una fecha posterior: %s | '
                    'a una fecha anterior a su conciliación: %s | un asiento que entra después con fecha anterior: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'UN BANCO contra su conciliación confirmada (c6): con un depósito y un cheque en tránsito, la cédula del día del corte cuadra partida por partida (800 = 0 del statement + 1,000 − 200); lo que el libro mueve DESPUÉS no cambia la de ese día y en la de una fecha posterior es la diferencia (50), dicha aparte; a una fecha anterior esa conciliación no comprueba el día (se llega con el propio libro: «del libro», sin pedir nada y diciendo cómo comprobarlo); y un asiento que entra después con fecha anterior al corte (7) la descuadra, y lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. UNA TARJETA: el statement en su lado. Un cargo de 300 que el banco
--     trae (se importa y se clasifica): la conciliación se confirma con el
--     statement diciendo que se deben 300. La cédula enseña 300 en positivo
--     (lo que se debe) en el libro y en el auxiliar.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_c jsonb; v_m uuid;
  v_esp text := 'conciliacion | libro 300.00 | aux 300.00 | dif 0.00 | cuadra; su renglón: auxiliar: Lo que dice el statement al … = 300.00; '
                'su auxiliar se llama: El statement de la tarjeta, conciliado | una tarjeta sin dar de alta: manual | libro 45.00 | aux - | dif - | '
                'sin_auxiliar (pendiente), y dice que le falta su alta: sí';
begin
  if pg_temp.c13_omitir(12, 'una tarjeta contra su statement', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '2100-9393', 'nombre', 'C13 PRUEBA tarjeta (se deshace)',
              'saldo', '-300.00', 'saldo_al', v_h::text, 'desde', pg_temp.c13_d(0)::text, 'hasta', v_h::text,
              'filas', jsonb_build_array(jsonb_build_object('id', 'C13T1', 'fecha', pg_temp.c13_d(4)::text, 'monto', '-300.00',
                                                            'descripcion', 'C13 PRUEBA CARGO RARO'))));
    perform fn_banco_casar_todo('2100-9393');
    select m.id into v_m from movimientos_banco m where m.cuenta = '2100-9393' and m.id_externo = 'C13T1';
    perform fn_banco_clasificar(v_m, '[{"cuenta": "6200"}]'::jsonb, 'C13 PRUEBA: un cargo de prueba');
    v_c := fn_conciliar('2100-9393', v_h, '300.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_obt := format('%s; su renglón: %s; su auxiliar se llama: %s', pg_temp.c13_fila('2100-9393', v_h),
                    (select string_agg(format('%s: %s = %s', i.clase, regexp_replace(i.concepto, ' al [0-9]+-[a-z]+-[0-9]+$', ' al …'), i.monto), ' ; ' order by i.n)
                       from fn_cedula_partidas(v_h, '2100-9393') i),
                    (select x.auxiliar from fn_cedula(v_h) x where x.cuenta = '2100-9393'));
    -- una subcuenta de tarjetas que nadie dio de alta como tarjeta: c6 no la concilia; la cédula lo dice
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9394', 'C13 PRUEBA tarjeta sin alta', 'c13 test card 2', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
    perform pg_temp.c13_dh(pg_temp.c13_d(6), 'un cargo de la tarjeta sin alta', '6200', '2100-9394', 45);
    v_obt := v_obt || format(' | una tarjeta sin dar de alta: %s, y dice que le falta su alta: %s', pg_temp.c13_fila('2100-9394', v_h),
                             case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '2100-9394')
                                       like 'Sin auxiliar: es una tarjeta que no está dada de alta (sin su alta no se concilia); mientras, su statement se escribe a mano. Tiene $45.00 %'
                                   and (select x.por_que from fn_cedula(v_h) x where x.cuenta = '2100-9394') = 'manual' then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'UNA TARJETA contra su statement conciliado (c6): con un cargo de 300 importado y clasificado, y el statement diciendo que se deben 300, la cédula enseña 300 en positivo (lo que se debe) en el libro y en el auxiliar: cada cuenta en su lado natural; y una subcuenta de tarjetas que nadie dio de alta como tarjeta (c6 no la concilia) sale sin auxiliar, diciendo que le falta su alta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. UN PRÉSTAMO con su parte corriente y su largo plazo (c6). 24,000 al
--     12 % anual, cuota de 1,000 al mes. A mano: de los próximos doce pagos,
--     9,638.71 son capital (lo que vence en un año) y 14,361.29 quedan a
--     largo plazo. El desembolso entra entero al largo plazo (como lo trae
--     QuickBooks): el total cuadra y el reparto no, y la cédula dice cuánto
--     pasar de una cuenta a la otra. Hecha la reclasificación, cuadran las
--     dos. Con la primera cuota (760 de capital) se deben 23,240: lo que
--     vence en un año pasa a 9,735.10, y el libro vuelve a pedir su reparto
--     (856.39). A una fecha anterior a la cuota, todo sigue cuadrando. En
--     los totales, ese reparto se cuenta UNA vez y aparte (lo que hay que
--     pasar de una cuenta a la otra): no suma a la diferencia pendiente.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_p uuid; a text; b text; c text; d text; e text; f text; r0 jsonb; r1 jsonb; r2 jsonb;
  v_esp text := 'sin registrar: prestamos | libro 0.00 | aux - | dif - | sin_auxiliar, vacio | '
                'el desembolso, todo al largo plazo: prestamos | libro 0.00 | aux 9638.71 | dif -9638.71 | no_cuadra (pendiente) y '
                'prestamos | libro 24000.00 | aux 14361.29 | dif 9638.71 | no_cuadra (pendiente); '
                'sus renglones: auxiliar: ZZ C13 PRUEBA BANK · camioneta de prueba: lo que vence en un año = 9638.71 y '
                'auxiliar: ZZ C13 PRUEBA BANK · camioneta de prueba: a largo plazo = 14361.29; dice cuánto pasar y de dónde: sí; '
                'en los totales: 9638.71 por repartir en 2 cuentas, y a la diferencia pendiente +0.00 | '
                'repartido: en los totales +0.00 por repartir; prestamos | libro 9638.71 | aux 9638.71 | dif 0.00 | cuadra y prestamos | libro 14361.29 | aux 14361.29 | dif 0.00 | cuadra | '
                'después de una cuota: prestamos | libro 8878.71 | aux 9735.10 | dif -856.39 | no_cuadra (pendiente) y '
                'prestamos | libro 14361.29 | aux 13504.90 | dif 856.39 | no_cuadra (pendiente), se deben $23,240.00 | '
                'a una fecha anterior a la cuota: prestamos | libro 9638.71 | aux 9638.71 | dif 0.00 | cuadra';
begin
  if pg_temp.c13_omitir(13, 'un préstamo con su parte corriente', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    a := pg_temp.c13_fila('2593', v_h) || ', ' || coalesce((select x.por_que from fn_cedula(v_h) x where x.cuenta = '2593'), '-');
    perform pg_temp.c13_ser('dueno');
    r0 := fn_cedula_resumen(v_h);
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_dh(pg_temp.c13_d(1), 'el desembolso del préstamo', '1093', '2594', 24000);
    perform fn_prestamo_guardar(jsonb_build_object('prestamista', 'ZZ C13 PRUEBA BANK', 'descripcion', 'camioneta de prueba',
              'principal', '24000.00', 'tasa_anual', '12', 'cuota', '1000.00', 'primer_pago', pg_temp.c13_d(20)::text,
              'cuenta', '2593', 'cuenta_largo', '2594', 'cuenta_interes', '7100', 'cuenta_banco', '1093',
              'saldo_inicial', '24000.00', 'saldo_inicial_al', pg_temp.c13_d(1)::text));
    select p.id into v_p from prestamos p where p.prestamista = 'ZZ C13 PRUEBA BANK';
    b := format('%s y %s; sus renglones: %s y %s; dice cuánto pasar y de dónde: %s',
                pg_temp.c13_fila('2593', v_h), pg_temp.c13_fila('2594', v_h),
                pg_temp.c13_renglon('2593', v_h, 'ZZ C13 PRUEBA BANK%'), pg_temp.c13_renglon('2594', v_h, 'ZZ C13 PRUEBA BANK%'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '2593')
                          like '%Con la 2594 (C13 PRUEBA préstamo largo plazo) el total sí cuadra%pasar $9,638.71 de la 2594 a la 2593.%'
                      and (select x.detalle from fn_cedula(v_h) x where x.cuenta = '2594')
                          like '%Con la 2593 (C13 PRUEBA préstamo corriente) el total sí cuadra%pasar $9,638.71 de la 2594 a la 2593.%'
                      and (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '2593') like 'Haz el asiento de reclasificación%'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = '2593'), 'nulo') end);
    perform pg_temp.c13_ser('dueno');
    r1 := fn_cedula_resumen(v_h);
    perform pg_temp.c13_ser('editor');
    b := b || format('; en los totales: %s por repartir en %s cuentas, y a la diferencia pendiente %s',
                     coalesce(((r1->>'reparto_pendiente')::numeric - (r0->>'reparto_pendiente')::numeric)::text, 'no lo dicen'),
                     coalesce(((r1->>'reparto_cuentas')::int - (r0->>'reparto_cuentas')::int)::text, '-'),
                     to_char((r1->>'diferencia_pendiente')::numeric - (r0->>'diferencia_pendiente')::numeric, 'FMS999999990.00'));
    perform pg_temp.c13_dh(pg_temp.c13_d(1), 'la reclasificación de lo que vence en un año', '2594', '2593', 9638.71);
    perform pg_temp.c13_ser('dueno');
    r2 := fn_cedula_resumen(v_h);
    perform pg_temp.c13_ser('editor');
    c := format('en los totales %s por repartir; ', coalesce(to_char((r2->>'reparto_pendiente')::numeric - (r0->>'reparto_pendiente')::numeric, 'FMS999999990.00'), 'no lo dicen'))
         || pg_temp.c13_fila('2593', v_h) || ' y ' || pg_temp.c13_fila('2594', v_h);
    perform pg_temp.c13_ser('dueno');
    perform fn_prestamo_cuota(v_p, null, pg_temp.c13_d(20), '1000.00', '760.00', '240.00', null);
    perform pg_temp.c13_ser('editor');
    d := format('%s y %s, se deben %s', pg_temp.c13_fila('2593', v_h), pg_temp.c13_fila('2594', v_h),
                (select substring(i.nota from 'Se deben ([^ ]+) en total') from fn_cedula_partidas(v_h, '2593') i where i.clase = 'auxiliar'));
    e := pg_temp.c13_fila('2593', pg_temp.c13_d(15));
    v_obt := format('sin registrar: %s | el desembolso, todo al largo plazo: %s | repartido: %s | después de una cuota: %s | '
                    'a una fecha anterior a la cuota: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'UN PRÉSTAMO con su parte corriente y su largo plazo (c6), al centavo y calculado a mano (24,000 al 12 %, cuota de 1,000): sin registrar, sus cuentas no tienen auxiliar; con el desembolso entero en el largo plazo el total cuadra y el reparto no, y la cédula dice cuánto pasar de una cuenta a la otra (9,638.71), que en los totales se cuenta una vez y aparte (no suma a la diferencia pendiente); repartido, cuadran las dos; después de una cuota (760 de capital) lo que vence en un año es 9,735.10 y vuelve a pedir su reparto (856.39); a una fecha anterior a la cuota sigue cuadrando',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. EL WIP POR OBRA (c12). Una obra de 10,000 con 3,000 de costo de 6,000
--     estimados y 2,000 facturados: ganado 5,000, sub-facturado 3,000. El
--     ajuste se postea el último día del mes: ese día la cédula trae la obra
--     con 3,000 en el auxiliar y 3,000 en el libro. El día 1 del mes
--     siguiente el ajuste se deshace solo: ya no está ni en el auxiliar ni
--     en el libro. Un asiento a mano en esa obra (50) descuadra SU renglón.
--     Y otro, en otra obra, que lo compensa (−50): la cuenta suma lo mismo
--     que su auxiliar y aun así NO cuadra (dos obras no casan).
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); f0 jsonb; g0 jsonb; a text; b text; c text; d text;
  v_esp text := 'el ajuste vivo, el último día del mes: dif +0.00 | cuadra; su obra: auxiliar: C13 PRUEBA Obra W = 3000.00 (libro 3000.00) ok | '
                'el día 1 del mes siguiente, ya deshecho: dif +0.00 | cuadra; su obra: no sale | '
                'un asiento a mano en esa obra: dif +50.00 | no_cuadra; su obra: auxiliar: C13 PRUEBA Obra W = 3000.00 (libro 3050.00) NO; '
                'obras que no casan: +1; lo dice: sí | '
                'y otro en otra obra que lo compensa: dif +0.00 | no_cuadra; la otra: auxiliar: C13 PRUEBA Obra X = 0.00 (libro -50.00) NO; '
                'obras que no casan: +2';
begin
  if pg_temp.c13_omitir(14, 'el WIP por obra', v_esp, array['mes', 'cuentas', 'c12']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    -- (si el mes de las pruebas ya tiene su ajuste de verdad, se deshace aquí dentro y vuelve con la prueba)
    if exists (select 1 from wip_ajustes w where w.periodo = v_per and w.deshecho_el is null) then
      perform fn_wip_deshacer(v_per, 'C13 PRUEBA: se deshace dentro de la prueba (la prueba se deshace entera)');
    end if;
    f0 := pg_temp.c13_foto('1200', v_h);
    g0 := pg_temp.c13_foto('1200', v_h + 1);
    perform pg_temp.c13_dh(pg_temp.c13_d(9), 'el costo de la obra W', '5100', '3100', 3000, 'c13-prueba-w');
    perform pg_temp.c13_factura(3, 'c13-prueba-w', 2000, 11);
    perform pg_temp.c13_ser('dueno');
    perform fn_wip_revisar('c13-prueba-w', v_per, '{"costo_estimado": "6000"}');
    perform fn_wip_postear(v_per, null);
    perform pg_temp.c13_ser('editor');
    a := format('%s; su obra: %s', pg_temp.c13_dif(f0, '1200', v_h), pg_temp.c13_renglon('1200', v_h, 'C13 PRUEBA Obra W'));
    b := format('%s; su obra: %s', pg_temp.c13_dif(g0, '1200', v_h + 1), pg_temp.c13_renglon('1200', v_h + 1, 'C13 PRUEBA Obra W'));
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'un asiento a mano en el WIP de la obra W', '1200', '3100', 50, 'c13-prueba-w');
    c := format('%s; su obra: %s; obras que no casan: %s; lo dice: %s', pg_temp.c13_dif(f0, '1200', v_h),
                pg_temp.c13_renglon('1200', v_h, 'C13 PRUEBA Obra W'),
                to_char((pg_temp.c13_foto('1200', v_h)->>'x')::int - (f0->>'x')::int, 'FMS990'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '1200') like '%obra(s) el libro no tiene lo que dice el ajuste del WIP.%'
                      and (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1200') like 'Vuelve a postear el ajuste del WIP%'
                     then 'sí' else 'no' end);
    perform pg_temp.c13_dh(pg_temp.c13_d(21), 'otro asiento a mano, en la obra X, que lo compensa', '3100', '1200', 50, null, 'c13-prueba-x');
    d := format('%s; la otra: %s; obras que no casan: %s', pg_temp.c13_dif(f0, '1200', v_h),
                pg_temp.c13_renglon('1200', v_h, 'C13 PRUEBA Obra X'),
                to_char((pg_temp.c13_foto('1200', v_h)->>'x')::int - (f0->>'x')::int, 'FMS990'));
    v_obt := format('el ajuste vivo, el último día del mes: %s | el día 1 del mes siguiente, ya deshecho: %s | un asiento a mano en esa obra: %s | '
                    'y otro en otra obra que lo compensa: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'EL WIP POR OBRA (c12): el ajuste vivo el último día del mes está en el auxiliar y en el libro, obra por obra (3,000 = 3,000); el día 1 del mes siguiente, deshecho solo, ya no está en ninguno de los dos; un asiento a mano en esa obra (50) descuadra SU renglón, y lo dice; y otro en otra obra que lo compensa deja la cuenta sumando lo mismo que su auxiliar y aun así sin cuadrar: se compara obra por obra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. UN ACTIVO FIJO Y SU DEPRECIACIÓN (c9). Un compresor de 6,000 comprado
--     el día 3 (su asiento, Dr 15xx), a 60 meses: la cuenta del activo
--     cuadra con su alta, renglón a renglón; a una fecha anterior a la
--     compra, todavía no está. La depreciación del mes (100) entra el último
--     día: la 1590 la trae en SU renglón, y a mitad de mes todavía no. Un
--     activo dado de alta sin su asiento (250) está en el auxiliar y no en el
--     libro: es la diferencia.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); f0 jsonb; v_as uuid; r jsonb; a text; b text; c text; d text;
  v_esp text := 'el activo con su asiento: activos | libro 6000.00 | aux 6000.00 | dif 0.00 | cuadra; su renglón: auxiliar: ZZ C13 PRUEBA '
                'compresor · C13-001 = 6000.00 | antes de comprarlo: activos | libro 0.00 | aux 0.00 | dif 0.00 | cuadra | '
                'su depreciación del mes, en la 1590: auxiliar: ZZ C13 PRUEBA compresor · C13-001 = 100.00, dif +0.00 | cuadra; a mitad de mes: no sale | '
                'uno dado de alta sin su asiento: activos | libro 6000.00 | aux 6250.00 | dif -250.00 | no_cuadra (pendiente); qué hacer: sí';
begin
  if pg_temp.c13_omitir(15, 'un activo con su depreciación', v_esp, array['mes', 'cuentas', 'c9']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    f0 := pg_temp.c13_foto('1590', v_h);
    v_as := pg_temp.c13_dh(pg_temp.c13_d(2), 'la compra del compresor', '1583', '1093', 6000);
    perform pg_temp.c13_ser('dueno');
    perform fn_activo_alta(jsonb_build_object('descripcion', 'ZZ C13 PRUEBA compresor', 'placa_serie', 'C13-001', 'cuenta', '1583',
              'fecha_servicio', pg_temp.c13_d(2)::text, 'costo', '6000.00', 'metodo', 'linea_recta', 'vida_meses', 60,
              'asiento_alta_id', v_as::text));
    perform pg_temp.c13_ser('editor');
    a := format('%s; su renglón: %s', pg_temp.c13_fila('1583', v_h), pg_temp.c13_renglon('1583', v_h, 'ZZ C13 PRUEBA compresor%'));
    b := pg_temp.c13_fila('1583', pg_temp.c13_d(1));
    -- la depreciación del mes (si el mes ya tenía la suya de verdad, se reversa aquí dentro y se vuelve a postear con el compresor)
    perform pg_temp.c13_ser('dueno');
    r := fn_depreciacion_mes(v_per);
    if coalesce((r->>'ya_estaba')::boolean, false) then
      perform fn_reversar((r->'asiento'->>'id')::uuid, 'C13 PRUEBA: se rehace dentro de la prueba (la prueba se deshace entera)');
      r := fn_depreciacion_mes(v_per);
    end if;
    perform pg_temp.c13_ser('editor');
    c := format('%s, %s; a mitad de mes: %s', pg_temp.c13_renglon('1590', v_h, 'ZZ C13 PRUEBA compresor%'), pg_temp.c13_dif(f0, '1590', v_h),
                pg_temp.c13_renglon('1590', pg_temp.c13_d(10), 'ZZ C13 PRUEBA compresor%'));
    perform pg_temp.c13_ser('dueno');
    perform fn_activo_alta(jsonb_build_object('descripcion', 'ZZ C13 PRUEBA andamio', 'cuenta', '1583',
              'fecha_servicio', pg_temp.c13_d(5)::text, 'costo', '250.00', 'metodo', 'linea_recta', 'vida_meses', 60));
    perform pg_temp.c13_ser('editor');
    d := format('%s; qué hacer: %s', pg_temp.c13_fila('1583', v_h),
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1583') like 'Mira los activos en Cierre:%' then 'sí' else 'no' end);
    v_obt := format('el activo con su asiento: %s | antes de comprarlo: %s | su depreciación del mes, en la 1590: %s | '
                    'uno dado de alta sin su asiento: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'UN ACTIVO FIJO Y SU DEPRECIACIÓN (c9): un compresor de 6,000 con su asiento cuadra con su alta, renglón a renglón, y a una fecha anterior a la compra todavía no está; su depreciación del mes (100, a 60 meses) sale en SU renglón de la 1590 el último día y no a mitad de mes; un activo dado de alta sin su asiento (250) está en el auxiliar y no en el libro: es la diferencia, al centavo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. UNA PÓLIZA PAGADA POR ADELANTADO (c6: 1410 y 1420 SÍ las sabe la
--     base). Una póliza de 1,000 por 100 días que empieza 10 días antes de
--     acabar el mes: pagada y sin amortizar, la cuenta y lo que le falta son
--     1,000. Amortizado el mes (10 días, 100): 900 y 900. A una fecha
--     anterior, el auxiliar —que es el de hoy— se lleva a esa fecha quitando
--     SOLO lo que es de una póliza (su amortización, y su compra si la póliza
--     dice con qué papel se compró): pagada y sin amortizar, 1,000; antes de
--     pagarla, sin su papel la cédula no puede saber que todavía no existía
--     (no cuadra por 1,000, y dice qué hacer), y con su papel, cero. Un pago
--     en la cuenta que no es una póliza (300) es la diferencia; con su
--     renglón a mano, cuadra.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_omit text; a text; b text; c text; d text; e text; f text;
  v_pol text; v_as uuid;
  v_esp text := 'pagada y sin amortizar: prepagados | libro 1000.00 | aux 1000.00 | dif 0.00 | cuadra; su renglón: auxiliar: ZZ C13 PRUEBA '
                'póliza GL · del … al … (3 mes(es)) = 1000.00 | amortizado el mes: prepagados | libro 900.00 | aux 900.00 | dif 0.00 | cuadra; '
                'su renglón: auxiliar: ZZ C13 PRUEBA póliza GL · del … al … (3 mes(es)) = 900.00 | '
                'a una fecha anterior: antes de pagarla, sin decir con qué papel se compró prepagados | libro 0.00 | aux 1000.00 | dif -1000.00 | '
                'no_cuadra (pendiente), y dice por qué y qué hacer: sí; con su papel prepagados | libro 0.00 | aux 0.00 | dif 0.00 | cuadra; '
                'pagada y sin amortizar prepagados | libro 1000.00 | aux 1000.00 | dif 0.00 | cuadra, y dice que su auxiliar es el de hoy: sí | '
                'un pago que no es una póliza: prepagados | libro 1200.00 | aux 900.00 | dif 300.00 | no_cuadra (pendiente); qué hacer: sí | '
                'con su renglón a mano: prepagados | libro 1200.00 | aux 1200.00 | dif 0.00 | cuadra, a mano 300.00';
begin
  if pg_temp.c13_omitir(16, 'una póliza pagada por adelantado', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_pol := fn_prepagado_guardar(jsonb_build_object('descripcion', 'ZZ C13 PRUEBA póliza GL', 'tipo', 'seguro', 'cuenta', '1493',
               'cuenta_gasto', '6200', 'monto', '1000.00', 'desde', (v_h - 9)::text, 'hasta', (v_h + 90)::text))->>'id';
    v_as := pg_temp.c13_dh(v_h - 9, 'el pago de la póliza', '1493', '1093', 1000);
    a := format('%s; su renglón: %s', pg_temp.c13_fila('1493', v_h),
                regexp_replace(pg_temp.c13_renglon('1493', v_h, 'ZZ C13 PRUEBA póliza GL%'), 'del [0-9]+-[a-z]+-[0-9]+ al [0-9]+-[a-z]+-[0-9]+', 'del … al …'));
    begin
      perform pg_temp.c13_ser('dueno');
      perform fn_prepagados_amortizar(v_per);
      perform pg_temp.c13_ser('editor');
    exception when sqlstate 'MX008' or sqlstate 'MX002' then
      v_omit := sqlerrm;
      perform pg_temp.c13_ser('editor');
    end;
    if v_omit is not null then
      v_obt := 'omitida: en esta base no se puede amortizar el mes de las pruebas (' || left(v_omit, 200) || ')';
      raise exception using errcode = 'MXT00';
    end if;
    b := format('%s; su renglón: %s', pg_temp.c13_fila('1493', v_h),
                regexp_replace(pg_temp.c13_renglon('1493', v_h, 'ZZ C13 PRUEBA póliza GL%'), 'del [0-9]+-[a-z]+-[0-9]+ al [0-9]+-[a-z]+-[0-9]+', 'del … al …'));
    c := format('antes de pagarla, sin decir con qué papel se compró %s, y dice por qué y qué hacer: %s', pg_temp.c13_fila('1493', pg_temp.c13_d(5)),
                case when (select x.detalle from fn_cedula(pg_temp.c13_d(5)) x where x.cuenta = '1493')
                          like '%Después de ese día el libro movió $1,000.00 en esta cuenta sin ser de una póliza registrada (1 línea(s))%una póliza comprada después que no está enlazada con su papel%'
                      and (select x.que_hacer from fn_cedula(pg_temp.c13_d(5)) x where x.cuenta = '1493') like 'Mira la cédula de HOY:%'
                     then 'sí' else 'no' end);
    -- (la póliza dice con qué se compró: el asiento de su pago)
    perform fn_prepagado_guardar(jsonb_build_object('id', v_pol, 'papel_tabla', 'asientos', 'papel_id', v_as::text));
    c := c || format('; con su papel %s; pagada y sin amortizar %s, y dice que su auxiliar es el de hoy: %s',
                pg_temp.c13_fila('1493', pg_temp.c13_d(5)), pg_temp.c13_fila('1493', v_h - 5),
                case when (select x.detalle from fn_cedula(v_h - 5) x where x.cuenta = '1493')
                          like '% Su auxiliar es el de hoy, llevado a esa fecha con lo que las pólizas movieron después (lo amortizado y lo comprado).%'
                      and (select x.auxiliar_al from fn_cedula(v_h - 5) x where x.cuenta = '1493') = pg_temp.c13('hoy')::date then 'sí' else 'no' end);
    perform pg_temp.c13_dh(v_h - 3, 'un pago que entra a la cuenta y no es una póliza', '1493', '1093', 300);
    d := format('%s; qué hacer: %s', pg_temp.c13_fila('1493', v_h),
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1493') like 'Mira las pólizas:%' then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1493', 'concepto', 'C13 PRUEBA: el permiso anual pagado por adelantado',
              'monto', '300.00', 'desde', (v_h - 3)::text, 'documento', 'C13 PRUEBA recibo del permiso'));
    e := format('%s, a mano %s', pg_temp.c13_fila('1493', v_h), (select x.manual from fn_cedula(v_h) x where x.cuenta = '1493'));
    v_obt := format('pagada y sin amortizar: %s | amortizado el mes: %s | a una fecha anterior: %s | un pago que no es una póliza: %s | '
                    'con su renglón a mano: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'UNA PÓLIZA PAGADA POR ADELANTADO (c6; las cuentas 1410 y 1420 SÍ las sabe la base): una póliza de 1,000 por 100 días, pagada y sin amortizar, cuadra por 1,000; amortizado el mes (10 días: 100), por 900; a una fecha anterior el auxiliar —que es el de hoy— se lleva a esa fecha quitando solo lo que es de una póliza (1,000 pagada y sin amortizar; antes de pagarla, cero si la póliza dice con qué papel se compró, y si no lo dice no cuadra por 1,000 y la cédula dice qué hacer); un pago que entra a la cuenta y no es una póliza (300) es la diferencia, y con su renglón a mano cuadra',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 17. EL AUXILIAR A MANO (lo que la base no sabe: depósitos en garantía,
--     otros activos…). Sin renglones y sin saldo no pide nada; con saldo,
--     pide. Los renglones suman: 400 de 500 deja 100 de diferencia. Cada
--     renglón vale desde su día y hasta su día. Corregir uno deja el
--     anterior como rastro; anular otro, también. Y sus frenos.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_a uuid; v_b uuid; v_a2 jsonb; v_x text;
  s1 text; s2 text; s3 text; s4 text; s5 text; s6 text; s7 text; fr text;
  v_esp text := 'sin renglones ni saldo: manual | libro 0.00 | aux - | dif - | sin_auxiliar, manual | con saldo: manual | libro 500.00 | aux - | dif - | '
                'sin_auxiliar (pendiente) | un renglón de 400: manual | libro 500.00 | aux 400.00 | dif 100.00 | no_cuadra (pendiente) | '
                'otro de 100 que vale hasta el día 21: ese mes a mediados manual | libro 500.00 | aux 500.00 | dif 0.00 | cuadra; al final '
                'manual | libro 500.00 | aux 400.00 | dif 100.00 | no_cuadra (pendiente); antes de que empiecen manual | libro 0.00 | aux - | dif - | sin_auxiliar | '
                'corregido el primero a 500: manual | libro 500.00 | aux 500.00 | dif 0.00 | cuadra; lo no dicho se queda: sí; el anterior queda: '
                '2 vigentes, 1 corregidos, 0 anulados | anulado el segundo: 1 vigentes, 1 corregidos, 1 anulados; con su motivo y quién: sí | '
                'uno en negativo: manual | libro 500.00 | aux 450.00 | dif 50.00 | no_cuadra (pendiente) | '
                'frenos: MX004 MX004 MX004 | MX005 MX005 MX005 MX005 | 22023 22023 22023 22023 22023 22023 | MX008 MX008 22023 MX008 22023';
begin
  if pg_temp.c13_omitir(17, 'el auxiliar a mano', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    s1 := pg_temp.c13_fila('1693', v_h) || ', ' || coalesce((select x.por_que from fn_cedula(v_h) x where x.cuenta = '1693'), '-');
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    s2 := pg_temp.c13_fila('1693', v_h);
    v_a := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
                                                       'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'))->>'id')::uuid;
    s3 := pg_temp.c13_fila('1693', v_h);
    v_b := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la luz', 'monto', '100.00',
                                                       'desde', pg_temp.c13_d(2)::text, 'hasta', pg_temp.c13_d(20)::text))->>'id')::uuid;
    s4 := format('ese mes a mediados %s; al final %s; antes de que empiecen %s', pg_temp.c13_fila('1693', pg_temp.c13_d(15)),
                 pg_temp.c13_fila('1693', v_h), pg_temp.c13_fila('1693', pg_temp.c13_d(1)));
    v_a2 := pg_temp.c13_renglon_pon(jsonb_build_object('id', v_a::text, 'monto', '500.00'));
    s5 := format('%s; lo no dicho se queda: %s; el anterior queda: %s', pg_temp.c13_fila('1693', v_h),
                 case when v_a2->>'concepto' = 'C13 PRUEBA: depósito de la bodega' and v_a2->>'documento' = 'C13 PRUEBA contrato de renta'
                           and v_a2->>'desde' = pg_temp.c13_d(2)::text and v_a2->>'sustituye_a' = v_a::text and v_a2->>'id' <> v_a::text
                      then 'sí' else 'no: ' || v_a2::text end,
                 (select format('%s vigentes, %s corregidos, %s anulados', count(*) filter (where m.vigente),
                                count(*) filter (where m.sustituido_el is not null), count(*) filter (where m.anulado_el is not null))
                    from v_cedula_manual m where m.cuenta = '1693'));
    perform pg_temp.c13_ser('dueno');
    perform fn_cedula_renglon_anular(v_b, 'C13 PRUEBA: ese depósito ya se devolvió');
    perform pg_temp.c13_ser('editor');
    s6 := format('%s; con su motivo y quién: %s',
                 (select format('%s vigentes, %s corregidos, %s anulados', count(*) filter (where m.vigente),
                                count(*) filter (where m.sustituido_el is not null), count(*) filter (where m.anulado_el is not null))
                    from v_cedula_manual m where m.cuenta = '1693'),
                 case when (select m.anulado_motivo = 'C13 PRUEBA: ese depósito ya se devolvió' and m.anulado_por::text = pg_temp.c13('dueno')
                                   and m.cuenta_nombre = 'C13 PRUEBA depósitos'
                              from v_cedula_manual m where m.renglon_id = v_b) then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: lo que se aplicó a la renta', 'monto', '-50.00',
                                                       'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA carta del dueño del local'));
    s7 := pg_temp.c13_fila('1693', v_h);
    -- los frenos
    fr := '';
    foreach v_x in array array[
      jsonb_build_object('cuenta', '6200', 'concepto', 'C13 PRUEBA: en una de resultados', 'monto', '1.00', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '2100', 'concepto', 'C13 PRUEBA: en una de grupo', 'monto', '1.00', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '9999-NO', 'concepto', 'C13 PRUEBA: en una que no existe', 'monto', '1.00', 'desde', v_h::text)::text,
      '|',
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: cero', 'monto', '0', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: no es un monto', 'monto', 'mucho', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: tres decimales', 'monto', '1.234', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: sin monto', 'desde', v_h::text)::text,
      '|',
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: sin desde', 'monto', '1.00')::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: una fecha que no existe', 'monto', '1.00', 'desde', '2026-02-31')::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: acaba antes de empezar', 'monto', '1.00', 'desde', v_h::text, 'hasta', (v_h - 1)::text)::text,
      jsonb_build_object('cuenta', '1693', 'monto', '1.00', 'desde', v_h::text)::text,
      jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: una clave de más', 'monto', '1.00', 'desde', v_h::text, 'color', 'rojo')::text,
      jsonb_build_object('id', (v_a2->>'id'), 'cuenta', '1493')::text,
      '|',
      jsonb_build_object('id', v_a::text, 'monto', '2.00')::text,
      jsonb_build_object('id', v_b::text, 'monto', '2.00')::text] loop
      fr := fr || case when v_x = '|' then '| ' else pg_temp.c13_estado(format('select public.fn_cedula_renglon(%L::jsonb)', v_x)) || ' ' end;
    end loop;
    fr := fr || pg_temp.c13_estado(format('select public.fn_cedula_renglon_anular(%L, %L)', v_a2->>'id', '  ')) || ' '
             || pg_temp.c13_estado(format('select public.fn_cedula_renglon_anular(%L, %L)', v_b, 'C13 PRUEBA: otra vez')) || ' '
             || pg_temp.c13_estado(format('select public.fn_cedula_renglon_anular(%L, %L)', gen_random_uuid(), 'C13 PRUEBA: no existe'));
    v_obt := format('sin renglones ni saldo: %s | con saldo: %s | un renglón de 400: %s | otro de 100 que vale hasta el día 21: %s | '
                    'corregido el primero a 500: %s | anulado el segundo: %s | uno en negativo: %s | frenos: %s',
                    s1, s2, s3, s4, s5, s6, s7, fr);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'EL AUXILIAR A MANO (lo que la base no sabe): sin renglones y sin saldo no pide nada, y con saldo sí; los renglones suman (400 de 500 deja 100 de diferencia, al centavo); cada uno vale desde su día y hasta su día; corregir uno deja el anterior como rastro y lo que no se dice se queda; anular otro, con su motivo y quién; uno en negativo resta; y sus frenos (MX004 la cuenta, MX005 el monto, 22023 lo que falta o sobra, MX008 lo ya corregido o anulado)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. LO DEVENGADO (2050): los devengos del cierre, uno por uno. Un devengo
--     reversible de 500 fechado el último día del mes: ese día está en la
--     cuenta y en su auxiliar; el día 1 se deshace solo y ya no está en
--     ninguno. Lo que entra a la cuenta sin ser un devengo de esos (80) va
--     suelto: es la diferencia; con su renglón a mano, cuadra.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); f0 jsonb; g0 jsonb; a text; b text; c text; d text;
  v_esp text := 'el devengo vivo, el último día: libro +500.00 | aux +500.00 | dif +0.00 | cuadra; su renglón: auxiliar: C13 PRUEBA: el devengo de '
                'la renta de la grúa (se deshace) = 500.00 | el día 1, deshecho solo: libro +0.00 | aux +0.00 | dif +0.00 | cuadra; su renglón: no sale | '
                'algo que no es un devengo: libro +580.00 | aux +500.00 | dif +80.00 | no_cuadra; suelto +80.00; lo dice: sí | '
                'con su renglón a mano: libro +580.00 | aux +580.00 | dif +0.00 | cuadra';
begin
  if pg_temp.c13_omitir(18, 'lo devengado', v_esp) then return; end if;
  if not exists (select 1 from fn_cedula_cuentas() k where k.cuenta = '2050' and k.fuente = 'devengos') then
    insert into _pruebas values (18, 'lo devengado', v_esp, 'omitida: esta base no tiene la cuenta 2050 (costos y gastos devengados por pagar)', null);
    return;
  end if;
  begin
    perform pg_temp.c13_sembrar();
    f0 := pg_temp.c13_foto('2050', v_h);
    g0 := pg_temp.c13_foto('2050', v_h + 1);
    perform pg_temp.c13_asiento(v_h, 'el devengo de la renta de la grúa', jsonb_build_array(
              jsonb_build_object('cuenta', '6200', 'monto', '500.00'), jsonb_build_object('cuenta', '2050', 'monto', '-500.00')), true);
    a := format('%s; su renglón: %s', pg_temp.c13_cambio(f0, '2050', v_h), pg_temp.c13_renglon('2050', v_h, 'C13 PRUEBA: el devengo%'));
    b := format('%s; su renglón: %s', pg_temp.c13_cambio(g0, '2050', v_h + 1), pg_temp.c13_renglon('2050', v_h + 1, 'C13 PRUEBA: el devengo%'));
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'una provisión a mano, que no se deshace sola', '6200', '2050', 80);
    c := format('%s; suelto %s; lo dice: %s', pg_temp.c13_cambio(f0, '2050', v_h),
                to_char((pg_temp.c13_foto('2050', v_h)->>'s')::numeric - (f0->>'s')::numeric, 'FMS999999990.00'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '2050') like '%no son un devengo de los que se deshacen solos.%'
                     then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2050', 'concepto', 'C13 PRUEBA: la provisión de la auditoría de seguros',
              'monto', '80.00', 'desde', pg_temp.c13_d(20)::text, 'documento', 'C13 PRUEBA carta de la aseguradora'));
    d := pg_temp.c13_cambio(f0, '2050', v_h);
    v_obt := format('el devengo vivo, el último día: %s | el día 1, deshecho solo: %s | algo que no es un devengo: %s | con su renglón a mano: %s',
                    a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'LO DEVENGADO (2050), sus devengos uno por uno: un devengo reversible de 500 del último día del mes está ese día en la cuenta y en su auxiliar, y el día 1, deshecho solo, en ninguno; lo que entra sin ser un devengo de esos (80) va suelto y es la diferencia, al centavo; con su renglón a mano, cuadra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 19. STRIPE (p1): lo cobrado en línea que falta depositar. Un cobro de 750
--     en la cuenta de Stripe: el auxiliar lo trae (es «hoy») y cuadra; a una
--     fecha anterior al cobro se llega quitando lo que el propio libro movió
--     después: da cero por construcción, y la cédula dice «del libro» (no lo
--     comprueba, y lo dice), no «cuadra». Un
--     asiento a mano en esa cuenta (40) es la diferencia. Y la cuenta de
--     paso, que debe estar en cero: 25 son 25 de diferencia.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_pu text; v_pa text; f0 jsonb; g0 jsonb; h0 jsonb; a text; b text; c text; d text;
  v_esp text := 'un cobro en línea sin depositar: libro +750.00 | aux +750.00 | dif +0.00 | cuadra; su renglón: auxiliar: Cobro en línea de la '
                'factura #C13-9 = 750.00 | a una fecha anterior al cobro: libro +0.00 | aux +0.00 | dif +0.00 | del_libro, y dice que no '
                'comprueba ese día: sí | '
                'un asiento a mano en la cuenta: libro +790.00 | aux +750.00 | dif +40.00 | no_cuadra; qué hacer: sí | '
                'la cuenta de paso con 25: libro +25.00 | aux +0.00 | dif +25.00 | no_cuadra; lo dice: sí';
begin
  if pg_temp.c13_omitir(19, 'Stripe', v_esp, array['mes', 'cuentas', 'p1']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    select coalesce(c.cuenta_puente, '1020'), coalesce(c.cuenta_paso, '1140') into v_pu, v_pa from stripe_config c where c.id = 1;
    v_pu := coalesce(v_pu, '1020'); v_pa := coalesce(v_pa, '1140');
    f0 := pg_temp.c13_foto(v_pu, v_h);
    g0 := pg_temp.c13_foto(v_pu, pg_temp.c13_d(5));
    h0 := pg_temp.c13_foto(v_pa, v_h);
    insert into stripe_pagos (pi, factura_num, medio, monto, estado, estado_stripe, objetivo, en_libro, cobrado_el)
    values ('pi_c13prueba0001', 'C13-9', 'tarjeta', 750, 'cobrado', 'succeeded', 750, 750, pg_temp.c13_d(8));
    perform pg_temp.c13_dh(pg_temp.c13_d(8), 'el cobro en línea, en la cuenta de Stripe', v_pu, '3193', 750);
    a := format('%s; su renglón: %s', pg_temp.c13_cambio(f0, v_pu, v_h), pg_temp.c13_renglon(v_pu, v_h, 'Cobro en línea de la factura #C13-9'));
    b := format('%s, y dice que no comprueba ese día: %s', pg_temp.c13_cambio(g0, v_pu, pg_temp.c13_d(5)),
                case when pg_temp.c13_col(v_pu, pg_temp.c13_d(5), 'sosten') = 'llevado'
                      and ((select x.estado from fn_cedula(pg_temp.c13_d(5)) x where x.cuenta = v_pu) <> 'del_libro'
                           or ((select x.detalle from fn_cedula(pg_temp.c13_d(5)) x where x.cuenta = v_pu)
                               like '%Su auxiliar es el de HOY: a esa fecha se llega con lo que el libro movió después (% línea(s)), así que no comprueba el saldo de ese día.'
                               and (select x.que_hacer from fn_cedula(pg_temp.c13_d(5)) x where x.cuenta = v_pu) like 'No pide nada. Para comprobarla,%'))
                     then 'sí' else 'no' end);
    perform pg_temp.c13_dh(pg_temp.c13_d(9), 'un asiento a mano en la cuenta de Stripe', v_pu, '3193', 40);
    c := format('%s; qué hacer: %s', pg_temp.c13_cambio(f0, v_pu, v_h),
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = v_pu) like 'Mira Cobros en línea;%' then 'sí' else 'no' end);
    perform pg_temp.c13_dh(pg_temp.c13_d(9), 'algo que se quedó en la cuenta de paso', v_pa, '3193', 25);
    d := format('%s; lo dice: %s', pg_temp.c13_cambio(h0, v_pa, v_h),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_pa) like '%Es una cuenta de paso: debería estar en cero.%' then 'sí' else 'no' end);
    v_obt := format('un cobro en línea sin depositar: %s | a una fecha anterior al cobro: %s | un asiento a mano en la cuenta: %s | '
                    'la cuenta de paso con 25: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'STRIPE (p1), lo cobrado en línea que falta depositar: un cobro de 750 está en la cuenta y en su auxiliar (que es el de hoy), y a una fecha anterior al cobro, en ninguno, pero eso sale de quitarle lo que el propio libro movió después: la cédula dice «del libro» y que no comprueba ese día; un asiento a mano en la cuenta (40) es la diferencia, al centavo; y la cuenta de paso, que debe estar en cero, con 25 tiene 25 de diferencia y lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. EL USE TAX (2300) por mes: lo devengado y lo pagado de cada mes, del
--     propio libro. Un devengo de 12.34 y un pago de 5.00: el mes sube 7.34
--     y la cuenta también. Su auxiliar es el propio libro ordenado por mes:
--     no puede no sumar, así que la cédula no dice «cuadra» sino «del libro»
--     (lo que se compara, a mano, es cada mes con su DR-15 presentado).
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_tax text; f0 jsonb; m0 numeric; m1 numeric; v_con text;
  v_esp text := 'dr15, «El use tax por mes» | libro +7.34 | aux +7.34 | dif +0.00 | del_libro | el renglón de su mes: +7.34, y dice lo devengado y lo '
                'pagado: sí | dice que sale del propio libro y que no lo compara con nada: sí';
begin
  if pg_temp.c13_omitir(20, 'el use tax por mes', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_tax := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
    -- (si esta base ya tiene renglones a mano en la cuenta —los DR-15 presentados—, se compara con ellos y no con el libro:
    -- la prueba mira lo que sale del libro, así que los anula aquí dentro, y vuelven con ella)
    perform pg_temp.c13_ser('dueno');
    perform fn_cedula_renglon_anular(m.id, 'C13 PRUEBA: se mira el auxiliar que sale del libro (se deshace)')
       from cedula_manual m where m.cuenta = v_tax and m.sustituido_el is null and m.anulado_el is null;
    perform pg_temp.c13_ser('editor');
    f0 := pg_temp.c13_foto(v_tax, v_h);
    select coalesce(sum(i.monto), 0) into m0 from fn_cedula_partidas(v_h, v_tax) i where i.clave = v_per;
    perform pg_temp.c13_dh(pg_temp.c13_d(7), 'el use tax devengado de una compra', '6200', v_tax, 12.34);
    perform pg_temp.c13_dh(pg_temp.c13_d(21), 'el pago del DR-15', v_tax, '1093', 5.00);
    select coalesce(sum(i.monto), 0), max(i.concepto) into m1, v_con from fn_cedula_partidas(v_h, v_tax) i where i.clave = v_per;
    v_obt := format('%s, «%s» | %s | el renglón de su mes: %s, y dice lo devengado y lo pagado: %s | dice que sale del propio libro y que no lo '
                    'compara con nada: %s',
                    (select x.fuente from fn_cedula(v_h) x where x.cuenta = v_tax), (select x.auxiliar from fn_cedula(v_h) x where x.cuenta = v_tax),
                    pg_temp.c13_cambio(f0, v_tax, v_h), to_char(m1 - m0, 'FMS999999990.00'),
                    case when v_con like 'Use tax de ' || fn_cedula_mes(v_per) || ': devengado $%, pagado $%' then 'sí' else 'no: ' || coalesce(v_con, 'nulo') end,
                    case when (select count(*) from fn_cedula_partidas(v_h, v_tax) i where i.clave = v_per and i.clase = 'libro') = 1
                          and (select k.origen from fn_cedula_cuentas() k where k.cuenta = v_tax) like '%del propio libro%no lo compara con nada.%'
                          and pg_temp.c13_col(v_tax, v_h, 'sosten') = 'libro'
                          and (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_tax)
                              like '%Sale del propio libro, ordenado%aquí no se compara con ningún papel de fuera.%Si escribes a mano lo que dice cada DR-15 presentado, se compara con eso.'
                          and (select x.pendiente from fn_cedula(v_h) x where x.cuenta = v_tax) is false
                         then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'EL USE TAX (2300) por mes: su auxiliar es lo devengado y lo pagado de cada mes, del propio libro; un devengo de 12.34 y un pago de 5.00 suben el renglón de su mes 7.34 y la cuenta lo mismo. Como sale del propio libro no puede no sumar: la cédula dice «del libro» (no «cuadra») y que no lo compara con nada (lo que se compara, a mano, es cada mes con su DR-15 presentado)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. LA NÓMINA (22xx) SIN c15 EN LA BASE (como corre c13_sembrar): su
--     auxiliar llega con la nómina (f11). Sin saldo no pide nada; con saldo,
--     pide y dice por qué; con su renglón a mano, cuadra. Los sueldos
--     devengados (el puente de c3) sí tienen el suyo: el devengo de las
--     horas. (Con la nómina puesta, las pruebas 42 a 47.)
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); a text; b text; c text; d text;
  v_esp text := 'sin saldo: nomina | libro 0.00 | aux - | dif - | sin_auxiliar, f11, «Sin auxiliar: llega con la nómina (f11). No tiene saldo: no pide nada.» | '
                'con saldo: nomina | libro 900.00 | aux - | dif - | sin_auxiliar (pendiente); qué hacer: sí | '
                'con su renglón a mano: nomina | libro 900.00 | aux 900.00 | dif 0.00 | cuadra | los sueldos devengados: devengos';
begin
  if pg_temp.c13_omitir(21, 'la nómina', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    a := format('%s, %s, «%s»', pg_temp.c13_fila('2293', v_h), (select x.por_que from fn_cedula(v_h) x where x.cuenta = '2293'),
                (select x.detalle from fn_cedula(v_h) x where x.cuenta = '2293'));
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'impuestos de nómina por pagar', '6200', '2293', 900);
    b := format('%s; qué hacer: %s', pg_temp.c13_fila('2293', v_h),
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '2293') like 'Su auxiliar llega con la nómina (f11).%' then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2293', 'concepto', 'C13 PRUEBA: 941 del trimestre por pagar', 'monto', '900.00',
              'desde', pg_temp.c13_d(15)::text, 'documento', 'C13 PRUEBA diario de la nómina'));
    c := pg_temp.c13_fila('2293', v_h);
    d := coalesce((select k.fuente from fn_cedula_cuentas() k
                    where k.cuenta = coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'sueldos_devengados'), '2210')), 'no está');
    v_obt := format('sin saldo: %s | con saldo: %s | con su renglón a mano: %s | los sueldos devengados: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'LA NÓMINA (22xx), SIN c15 EN LA BASE: su auxiliar llega con la nómina (f11): sin saldo no pide nada y lo dice; con saldo, pide (sin auxiliar todavía) y dice qué hacer; con su renglón a mano, cuadra; los sueldos devengados (el puente de c3) sí tienen su auxiliar: el devengo de las horas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 22. EL PATRIMONIO: por omisión sale de su propio mayor (lo que trajo la
--     apertura y los movimientos de cada mes). Eso no puede no sumar, así
--     que la cédula no dice «cuadra» sino «del libro» (no pide nada; lo
--     amarra la comparación con QuickBooks). Con la configuración en
--     «manual», se sostiene con renglones a mano. Y con renglones a mano, en
--     cualquiera de los dos modos, la cuenta SE COMPARA CON ELLOS (el mayor
--     queda abajo, de referencia): si suman el saldo, cuadra; si no, no.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); a text; b text; c text; d text; e text; f text;
  v_esp text := 'con su mayor: mayor | libro 750.00 | aux 750.00 | dif 0.00 | del_libro; su renglón: libro: Movimientos de <mes> = 750.00; dice '
                'que sale del propio libro: sí | con otro mes: 2 renglones, mayor | libro 780.00 | aux 780.00 | dif 0.00 | del_libro | '
                'todo el patrimonio sin renglones a mano sale del libro, y ninguna cuenta de esas «cuadra»: sí | '
                'con la configuración en «manual»: manual | libro 750.00 | aux - | dif - | sin_auxiliar (pendiente), manual | '
                'con su renglón: manual | libro 750.00 | aux 750.00 | dif 0.00 | cuadra | '
                'de vuelta a «mayor» con el renglón puesto, se compara con él: mayor | libro 750.00 | aux 750.00 | dif 0.00 | cuadra; lo dice: sí; '
                'y con otro renglón que no es (−50): mayor | libro 750.00 | aux 700.00 | dif 50.00 | no_cuadra (pendiente)';
begin
  if pg_temp.c13_omitir(22, 'el patrimonio', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    perform pg_temp.c13_dh(pg_temp.c13_d(3), 'un aporte', '1093', '3193', 1000);
    perform pg_temp.c13_dh(pg_temp.c13_d(8), 'un retiro', '3193', '1093', 250);
    a := format('%s; su renglón: %s; dice que sale del propio libro: %s', pg_temp.c13_fila('3193', v_h),
                regexp_replace(pg_temp.c13_renglon('3193', v_h, 'Movimientos de%'), 'Movimientos de [a-z]+ de [0-9]+', 'Movimientos de <mes>'),
                case when pg_temp.c13_col('3193', v_h, 'sosten') = 'libro'
                      and (select x.detalle from fn_cedula(v_h) x where x.cuenta = '3193')
                          like '$750.00 en el libro al %. Sale del propio libro, ordenado (su propio mayor, 1 renglón(es)): aquí no se compara con ningún papel de fuera. Lo amarra la comparación con QuickBooks;%'
                      and (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '3193') is null
                     then 'sí' else 'no' end);
    perform pg_temp.c13_dh(v_h + 3, 'otro aporte, el mes siguiente', '1093', '3193', 30);
    b := format('%s renglones, %s', (select x.renglones from fn_cedula(v_h + 5) x where x.cuenta = '3193'), pg_temp.c13_fila('3193', v_h + 5));
    c := case when not exists (select 1 from fn_cedula(v_h) x where x.tipo = 'capital' and x.manual = 0 and x.estado <> 'del_libro') then 'sí'
              else 'no: ' || (select string_agg(x.cuenta || ' ' || x.estado, ', ') from fn_cedula(v_h) x
                               where x.tipo = 'capital' and x.manual = 0 and x.estado <> 'del_libro') end;
    perform pg_temp.c13_config('{"patrimonio": "manual"}');
    d := pg_temp.c13_fila('3193', v_h) || ', ' || coalesce((select x.por_que from fn_cedula(v_h) x where x.cuenta = '3193'), '-');
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '3193', 'concepto', 'C13 PRUEBA: aportes menos retiros', 'monto', '750.00',
              'desde', pg_temp.c13_d(8)::text, 'documento', 'C13 PRUEBA acta de socios'));
    e := pg_temp.c13_fila('3193', v_h);
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    f := format('%s; lo dice: %s', pg_temp.c13_fila('3193', v_h),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '3193')
                          like '$750.00 en el libro al % = $750.00 en sus renglones escritos a mano (1 renglón(es)). Se compara con lo que está escrito a mano; lo que sale del propio libro queda abajo, de referencia.'
                      and pg_temp.c13_col('3193', v_h, 'sosten') = 'papel'
                      and pg_temp.c13_renglon('3193', v_h, 'Movimientos de%') like 'libro: Movimientos de % = 750.00'
                     then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '3193', 'concepto', 'C13 PRUEBA: un retiro que el acta no trae', 'monto', '-50.00',
              'desde', pg_temp.c13_d(8)::text, 'documento', 'C13 PRUEBA acta de socios'));
    f := f || '; y con otro renglón que no es (−50): ' || pg_temp.c13_fila('3193', v_h);
    v_obt := format('con su mayor: %s | con otro mes: %s | todo el patrimonio sin renglones a mano sale del libro, y ninguna cuenta de esas «cuadra»: %s | '
                    'con la configuración en «manual»: %s | con su renglón: %s | de vuelta a «mayor» con el renglón puesto, se compara con él: %s',
                    a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'EL PATRIMONIO: por omisión sale de su propio mayor (lo que trajo la apertura y los movimientos de cada mes); como eso no puede no sumar, la cédula dice «del libro» y no «cuadra» (no pide nada, y dice que lo amarra la comparación con QuickBooks); con la configuración en «manual» queda sin auxiliar hasta que se le escriben sus renglones; y con renglones a mano, también en «mayor», la cuenta se compara con ellos (el mayor queda abajo, de referencia): si suman el saldo cuadra, y si no, no',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. EXPLICAR UNA DIFERENCIA: por qué esa cuenta no cuadra a esa fecha.
--     Queda el texto, quién, cuándo y los números con que se explicó; la
--     cuenta pasa a «explicada» y deja de pedir; vale para ESA fecha (la del
--     día anterior sigue pidiendo). Explicar otra vez sustituye (la anterior
--     queda). También se explica una cuenta sin auxiliar y con saldo. Y sus
--     frenos.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); r1 jsonb; r2 jsonb; r3 jsonb; a text; b text; c text; d text; e text; fr text;
  v_esp text := 'antes: manual | libro 500.00 | aux 400.00 | dif 100.00 | no_cuadra (pendiente) | al explicarla guarda: no_cuadra, 500.00, 400.00 y 100.00, '
                'quién: sí | queda: manual | libro 500.00 | aux 400.00 | dif 100.00 | explicada; con su texto, quién y cuándo: sí; qué hacer: nada | '
                'vale para esa fecha: la del día anterior manual | libro 500.00 | aux 400.00 | dif 100.00 | no_cuadra (pendiente) | '
                'explicar otra vez sustituye: sí; 1 viva, 1 sustituida | una sin auxiliar y con saldo: guarda sin_auxiliar; queda nomina | libro 900.00 | '
                'aux - | dif - | explicada | desde el SQL Editor: «el SQL Editor» | '
                'frenos: una que cuadra MX008, una sin saldo MX008, texto corto 22023, una fecha que no llega 22023, sin fecha 22023, sin cuenta 22023, '
                'una de resultados MX004, una que no existe MX004';
begin
  if pg_temp.c13_omitir(23, 'explicar una diferencia', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'));
    a := pg_temp.c13_fila('1693', v_h);
    r1 := pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz; el recibo está pedido');
    b := format('%s, %s, %s y %s, quién: %s', r1->>'estado', r1->>'saldo_libro', r1->>'saldo_auxiliar', r1->>'diferencia',
                case when r1->>'explicado_por' = pg_temp.c13('dueno') and r1->>'sustituye_a' is null and (r1->>'fecha')::date = v_h then 'sí' else 'no' end);
    c := format('%s; con su texto, quién y cuándo: %s; qué hacer: %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion = 'C13 PRUEBA: los 100 que faltan son el depósito de la luz; el recibo está pedido'
                                  and x.explicada_por::text = pg_temp.c13('dueno')
                                  and x.explicada_por_nombre is not distinct from (select p.nombre from perfiles p where p.id::text = pg_temp.c13('dueno'))
                                  and x.explicacion_id::text = r1->>'id' and not x.explicacion_vieja and x.explicada_el is not null
                                  and x.detalle like '% Explicada por % el ' || fn_cedula_dia(pg_temp.c13('hoy')::date)
                                                     || ': «C13 PRUEBA: los 100 que faltan son el depósito de la luz; el recibo está pedido»'
                             then 'sí' else 'no: ' || coalesce(x.detalle, 'nulo') end
                   from fn_cedula(v_h) x where x.cuenta = '1693'),
                coalesce((select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1693'), 'nada'));
    d := 'la del día anterior ' || pg_temp.c13_fila('1693', v_h - 1);
    r2 := pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 son el depósito de la luz, recibo 4471');
    e := format('%s; %s viva, %s sustituida', case when r2->>'sustituye_a' = r1->>'id' then 'sí' else 'no' end,
                (select count(*) from v_cedula_explicaciones x where x.cuenta = '1693' and x.viva),
                (select count(*) from v_cedula_explicaciones x where x.cuenta = '1693' and x.sustituida_el is not null));
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'impuestos de nómina por pagar', '6200', '2293', 900);
    r3 := pg_temp.c13_explicar('2293', v_h, 'C13 PRUEBA: es el 941 del trimestre, se paga en enero');
    e := e || format(' | una sin auxiliar y con saldo: guarda %s; queda %s', r3->>'estado', pg_temp.c13_fila('2293', v_h));
    -- desde el SQL Editor (sin sesión): la explica «el SQL Editor»
    perform fn_cedula_explicar('1693', v_h - 2, 'C13 PRUEBA: explicada desde el SQL Editor, sin sesión');
    e := e || ' | desde el SQL Editor: «' || coalesce((select substring(x.detalle from 'Explicada por (.+) el [0-9]+-[a-z]+-[0-9]+: «')
                                                       from fn_cedula(v_h - 2) x where x.cuenta = '1693'), 'nulo') || '»';
    fr := format('una que cuadra %s, una sin saldo %s, texto corto %s, una fecha que no llega %s, sin fecha %s, sin cuenta %s, una de resultados %s, '
                 'una que no existe %s',
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '3193', v_h, 'C13 PRUEBA: una que cuadra no se explica')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '1493', v_h, 'C13 PRUEBA: una sin saldo no se explica')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', v_h, 'porque sí')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', pg_temp.c13('hoy')::date + 1, 'C13 PRUEBA: una fecha que no ha llegado')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, null, %L)', '1693', 'C13 PRUEBA: sin fecha no se explica')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '  ', v_h, 'C13 PRUEBA: sin cuenta no se explica')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '6200', v_h, 'C13 PRUEBA: una de resultados no está')),
                 pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '9999-NO', v_h, 'C13 PRUEBA: una que no existe')));
    v_obt := format('antes: %s | al explicarla guarda: %s | queda: %s | vale para esa fecha: %s | explicar otra vez sustituye: %s | frenos: %s',
                    a, b, c, d, e, fr);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'EXPLICAR UNA DIFERENCIA (fn_cedula_explicar): guarda el texto, quién, cuándo y los números con que se explicó; la cuenta pasa a «explicada» y deja de pedir; vale para ESA fecha (la del día anterior sigue pidiendo); explicar otra vez sustituye a la anterior, que queda; también se explica una cuenta sin auxiliar y con saldo; desde el SQL Editor la firma «el SQL Editor»; y sus frenos (MX008 si cuadra o no tiene saldo, 22023 el texto corto o la fecha, MX004 la cuenta)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. LA EXPLICACIÓN SE QUEDA VIEJA: vale mientras el saldo del libro y el
--     del auxiliar sean los de cuando se escribió. Si cambia el libro (10
--     más) o el auxiliar (un renglón más), la cuenta vuelve a pedir y dice
--     con qué números valía; se vuelve a explicar. Retirarla, con su motivo,
--     deja la cuenta como esté. Y una cuenta que acaba cuadrando ya no
--     enseña explicación ninguna.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); r1 jsonb; r2 jsonb; rr jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'explicada: manual | libro 500.00 | aux 400.00 | dif 100.00 | explicada | cambia el libro: manual | libro 510.00 | aux 400.00 | dif 110.00 | '
                'no_cuadra (pendiente), vieja: sí, dice con qué valía: sí, y sigue a la vista: sí | se vuelve a explicar: manual | libro 510.00 | aux 400.00 | '
                'dif 110.00 | explicada, vieja: no, sustituye a la anterior: sí | cambia el auxiliar: manual | libro 510.00 | aux 460.00 | dif 50.00 | '
                'no_cuadra (pendiente), vieja: sí | una sin auxiliar, explicada, y cambia su saldo: nomina | libro 1000.00 | aux - | dif - | '
                'sin_auxiliar (pendiente), vieja: sí | retirada con su motivo: manual | libro 510.00 | aux 460.00 | dif 50.00 | no_cuadra (pendiente), '
                'sin explicación, quién y por qué: sí; otra vez MX008; sin motivo 22023 | la que acaba cuadrando: manual | libro 510.00 | aux 510.00 | '
                'dif 0.00 | cuadra, sin explicación a la vista | quedan: 0 vivas, 1 sustituidas, 2 retiradas';
begin
  if pg_temp.c13_omitir(24, 'la explicación se queda vieja', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'));
    r1 := pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz');
    a := pg_temp.c13_fila('1693', v_h);
    perform pg_temp.c13_dh(pg_temp.c13_d(22), 'diez más que entran a la cuenta', '1693', '3193', 10);
    b := format('%s, vieja: %s, dice con qué valía: %s, y sigue a la vista: %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion_vieja then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = '1693'),
                (select case when x.detalle like '% La explicación del ' || fn_cedula_dia(pg_temp.c13('hoy')::date)
                                                 || ' valía con $500.00 en el libro y $400.00 en el auxiliar; eso cambió después: vuelve a explicarla.'
                             then 'sí' else 'no: ' || x.detalle end from fn_cedula(v_h) x where x.cuenta = '1693'),
                (select case when x.explicacion = 'C13 PRUEBA: los 100 que faltan son el depósito de la luz' and x.explicacion_id::text = r1->>'id'
                             then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = '1693'));
    r2 := pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: ahora son 110: la luz y un ajuste de 10');
    c := format('%s, vieja: %s, sustituye a la anterior: %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion_vieja then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = '1693'),
                case when r2->>'sustituye_a' = r1->>'id' and r2->>'saldo_libro' = '510.00' and r2->>'diferencia' = '110.00' then 'sí' else 'no' end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la luz', 'monto', '60.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA recibo 4471'));
    d := format('%s, vieja: %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion_vieja then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = '1693'));
    -- una sin auxiliar: explicada con 900, y entran 100 más
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'impuestos de nómina por pagar', '6200', '2293', 900);
    perform pg_temp.c13_explicar('2293', v_h, 'C13 PRUEBA: es el 941 del trimestre, se paga en enero');
    perform pg_temp.c13_dh(pg_temp.c13_d(16), 'cien más de impuestos de nómina', '6200', '2293', 100);
    e := format('%s, vieja: %s', pg_temp.c13_fila('2293', v_h),
                (select case when x.explicacion_vieja then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = '2293'));
    -- retirar la de la 1693 (viva, aunque vieja)
    perform pg_temp.c13_ser('dueno');
    rr := fn_cedula_explicacion_retirar('1693', v_h, 'C13 PRUEBA: ya no es eso');
    perform pg_temp.c13_ser('editor');
    f := format('%s, %s, quién y por qué: %s; otra vez %s; sin motivo %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion is null and x.explicacion_id is null and not x.explicacion_vieja then 'sin explicación' else 'CON explicación' end
                   from fn_cedula(v_h) x where x.cuenta = '1693'),
                case when rr->>'id' = r2->>'id' and rr->>'retirada_por' = pg_temp.c13('dueno') and rr->>'retirada_motivo' = 'C13 PRUEBA: ya no es eso'
                          and rr->>'retirada_el' is not null then 'sí' else 'no' end,
                pg_temp.c13_estado(format('select public.fn_cedula_explicacion_retirar(%L, %L, %L)', '1693', v_h, 'C13 PRUEBA: otra vez')),
                pg_temp.c13_estado(format('select public.fn_cedula_explicacion_retirar(%L, %L, %L)', '2293', v_h, ' ')));
    -- la que acaba cuadrando: se explica (50) y después se le escribe el renglón que faltaba
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: faltan 50 por documentar');
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito del agua', 'monto', '50.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA recibo del agua'));
    g := format('%s, %s', pg_temp.c13_fila('1693', v_h),
                (select case when x.explicacion is null and not x.explicacion_vieja and x.detalle not like '%xplica%' then 'sin explicación a la vista'
                             else 'CON explicación: ' || x.detalle end from fn_cedula(v_h) x where x.cuenta = '1693'));
    perform pg_temp.c13_ser('dueno');
    perform fn_cedula_explicacion_retirar('1693', v_h, 'C13 PRUEBA: ya cuadra, no hace falta');
    perform pg_temp.c13_ser('editor');
    v_obt := format('explicada: %s | cambia el libro: %s | se vuelve a explicar: %s | cambia el auxiliar: %s | una sin auxiliar, explicada, y cambia su '
                    'saldo: %s | retirada con su motivo: %s | la que acaba cuadrando: %s | quedan: %s', a, b, c, d, e, f, g,
                    (select format('%s vivas, %s sustituidas, %s retiradas', count(*) filter (where x.viva),
                                   count(*) filter (where x.sustituida_el is not null and x.retirada_el is null),
                                   count(*) filter (where x.retirada_el is not null))
                       from v_cedula_explicaciones x where x.cuenta = '1693'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'LA EXPLICACIÓN SE QUEDA VIEJA: vale mientras el saldo del libro y el del auxiliar sean los de cuando se escribió; si cambia el libro o cambia el auxiliar la cuenta vuelve a pedir, dice con qué números valía y la explicación sigue a la vista; se vuelve a explicar (sustituye); también en una cuenta sin auxiliar; retirarla, con su motivo, deja la cuenta como esté (MX008 si no hay ninguna viva, 22023 sin motivo); y la que acaba cuadrando ya no enseña explicación',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. UNA CAPA QUE NO ESTÁ. La cédula lee las capas opcionales (c4, c6, c9,
--     c12, p1) solo si están. Fingiendo que no está ninguna (la función de
--     c13 que lo dice pasa a decir que no; se deshace con la prueba): sus
--     cuentas salen «sin auxiliar: esa parte no está en esta base», con qué
--     hacer; lo que sale del libro sigue teniendo su auxiliar; la cédula
--     trae las mismas cuentas; QuickBooks sale vacío; y a una cuenta de esas
--     se le puede escribir su renglón a mano. (La cadena mínima de verdad,
--     c1 + c2 + c3 solos, la prueba pruebas/conta/c13-sin-capas.sh.)
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_n0 bigint; v_n1 bigint; v_cxc text;
  a text; b text; c text; d text; e text; f text;
  v_esp text := 'el banco: conciliacion | libro 500.00 | aux - | dif - | sin_auxiliar (pendiente), capa, «Sin auxiliar: la parte del banco (c6) no está '
                'en esta base. Tiene $500.00 en el libro al …», y dice qué hacer: sí | el activo: activos | libro 200.00 | aux - | dif - | '
                'sin_auxiliar (pendiente), capa | cada cuenta de una capa que falta, sin renglones a mano: sin auxiliar y dice cuál falta: sí | '
                'lo demás sigue: el patrimonio mayor | libro 700.00 | aux 700.00 | dif 0.00 | del_libro; las de cobrar siguen con sus facturas: sí; '
                'las mismas cuentas: sí; el control 10: verde | QuickBooks: 0 períodos y sin balanza: sí | el pegado lo dice: sí | '
                'con su renglón a mano: conciliacion | libro 500.00 | aux 500.00 | dif 0.00 | cuadra';
begin
  if pg_temp.c13_omitir(25, 'una capa que no está', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    v_cxc := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc'), '1110');
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito', '1093', '3193', 700);
    perform pg_temp.c13_dh(pg_temp.c13_d(3), 'una herramienta', '1583', '1093', 200);
    select count(*) into v_n0 from fn_cedula(v_h);
    perform pg_temp.c13_fingir_capas('{"c4": false, "c6": false, "c9": false, "c12": false, "p1": false}');
    select count(*) into v_n1 from fn_cedula(v_h);
    a := format('%s, %s, «%s», y dice qué hacer: %s', pg_temp.c13_fila('1093', v_h),
                (select x.por_que from fn_cedula(v_h) x where x.cuenta = '1093'),
                (select regexp_replace(x.detalle, ' al [0-9]+-[a-z]+-[0-9]+\.$', ' al …') from fn_cedula(v_h) x where x.cuenta = '1093'),
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1093') like 'Esa parte de la contabilidad no está instalada aquí:%'
                     then 'sí' else 'no' end);
    b := pg_temp.c13_fila('1583', v_h) || ', ' || coalesce((select x.por_que from fn_cedula(v_h) x where x.cuenta = '1583'), '-');
    select case when count(*) filter (where not (x.estado = 'sin_auxiliar' and x.por_que = 'capa'
                                                 and x.detalle like 'Sin auxiliar: la parte de% no está en esta base.%')) = 0
                     and count(*) > 0 then 'sí'
                else 'no: ' || coalesce(string_agg(x.cuenta, ', ') filter (where not (x.estado = 'sin_auxiliar' and x.por_que = 'capa')), 'ninguna') end
      into c
      from fn_cedula(v_h) x
     where x.fuente in ('conciliacion', 'prestamos', 'prepagados', 'activos', 'depreciacion', 'wip', 'stripe', 'stripe_paso') and x.renglones = 0;
    d := format('el patrimonio %s; las de cobrar siguen con sus facturas: %s; las mismas cuentas: %s; el control 10: %s',
                pg_temp.c13_fila('3193', v_h),
                (select case when x.fuente = 'partidas' and x.estado <> 'sin_auxiliar' then 'sí' else 'no' end from fn_cedula(v_h) x where x.cuenta = v_cxc),
                case when v_n0 = v_n1 then 'sí' else format('no: %s y %s', v_n0, v_n1) end, pg_temp.c13_ctl(10));
    e := format('%s períodos y sin balanza: %s', (select count(*) from fn_cedula_qb_periodos()),
                (select case when count(*) = v_n1 and not bool_or(q.qb_cargada) and count(q.saldo_qb) = 0 then 'sí' else 'no' end from fn_cedula_qb(v_per) q));
    f := case when (select g.detalle from fn_cedula_pegado() g where g.que = 'capas que lee')
                   like '%(c6): NO está (sus cuentas salen sin auxiliar)%el WIP (c12): NO está%' then 'sí' else 'no' end;
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1093', 'concepto', 'C13 PRUEBA: lo que dice el statement del banco', 'monto', '500.00',
              'desde', pg_temp.c13_d(3)::text, 'documento', 'C13 PRUEBA statement'));
    v_obt := format('el banco: %s | el activo: %s | cada cuenta de una capa que falta, sin renglones a mano: sin auxiliar y dice cuál falta: %s | '
                    'lo demás sigue: %s | QuickBooks: %s | el pegado lo dice: %s | con su renglón a mano: %s', a, b, c, d, e, f, pg_temp.c13_fila('1093', v_h));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'UNA CAPA QUE NO ESTÁ (fingido: la función de c13 que dice qué capas hay pasa a decir que ninguna): las cuentas de esa capa salen «sin auxiliar: esa parte no está en esta base» con qué hacer, lo que sale del propio libro sigue con su auxiliar, la cédula trae las mismas cuentas y su control 10 sigue verde, QuickBooks sale vacío, el pegado lo dice, y a una cuenta de esas se le escribe su renglón a mano',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. LA CÉDULA AL LADO DE QUICKBOOKS (c4), para el cuadre de la 12b. Con
--     una balanza de QuickBooks cargada para el mes (dos cuentas de prueba:
--     QuickBooks dice 960 donde el libro tiene 1,000): cada cuenta trae lo
--     que dice QuickBooks, la diferencia con el libro (40) y lo que queda sin
--     explicar, en su lado natural. Anotada la diferencia en c4, QuickBooks
--     queda bien; y «amarra» solo cuando ADEMÁS el libro no pide nada (cuadra
--     con su auxiliar, está explicado, o —como el patrimonio— sale del
--     propio libro: a esas cuentas las amarra justo esta comparación). La
--     vista es la función, por período. Un
--     período sin balanza sale sin QuickBooks. Nada se carga desde aquí.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_sin text; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'la balanza: cargada, su documento y su fecha: sí | el patrimonio: del_libro | libro 1000.00 | qb 960.00 | dif 40.00 | explicada 0.00 | '
                'sin explicar 40.00 | qb bien no | el libro de c4 es el de la cédula sí | amarra no | el banco: sin_auxiliar | libro 1000.00 | qb 960.00 | '
                'dif 40.00 | explicada 0.00 | sin explicar 40.00 | qb bien no | el libro de c4 es el de la cédula sí | amarra no | '
                'anotada en c4: el patrimonio del_libro | libro 1000.00 | qb 960.00 | dif 40.00 | explicada 40.00 | sin explicar 0.00 | qb bien sí | '
                'el libro de c4 es el de la cédula sí | amarra sí; el banco, con QuickBooks bien y sin auxiliar: qb bien sí, amarra no | '
                'el banco con su renglón a mano: amarra sí | la vista, por período, es la función: sí | un mes sin balanza: sin QuickBooks | '
                'un período que no existe: 22023';
begin
  if pg_temp.c13_omitir(26, 'la cédula al lado de QuickBooks', v_esp, array['mes', 'cuentas', 'c4']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    select p.periodo into v_sin from periodos p
     where p.tipo = 'mes' and p.periodo <> v_per and p.periodo not in (select q.periodo from fn_cedula_qb_periodos() q)
     order by p.desde desc limit 1;
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un aporte', '1093', '3193', 1000);
    perform fn_apertura_mapeo_qb('ZZ C13 QB banco', '1093', 'C13 PRUEBA');
    perform fn_apertura_mapeo_qb('ZZ C13 QB capital', '3193', 'C13 PRUEBA');
    perform fn_comparacion_qb_cargar(v_per, 'docs/c13-pruebas/qb-mes.csv',
              '[{"cuenta_qb": "ZZ C13 QB banco", "saldo": "960.00"}, {"cuenta_qb": "ZZ C13 QB capital", "saldo": "-960.00"}]'::jsonb);
    create temp table _c13_qb on commit drop as select 1 as paso, q.* from fn_cedula_qb(v_per) q;
    a := (select case when bool_and(q.qb_cargada) and min(q.documento) = 'docs/c13-pruebas/qb-mes.csv' and max(q.documento) = min(q.documento)
                           and min(q.al) = v_h and max(q.al) = v_h and min(q.periodo) = v_per then 'sí' else 'no' end from _c13_qb q);
    b := (select format('%s | libro %s | qb %s | dif %s | explicada %s | sin explicar %s | qb bien %s | el libro de c4 es el de la cédula %s | amarra %s',
                        q.estado, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.explicada_qb, q.sin_explicar_qb,
                        case when q.qb_ok then 'sí' else 'no' end, case when q.libro_igual then 'sí' else 'no' end, case when q.amarra then 'sí' else 'no' end)
            from _c13_qb q where q.cuenta = '3193');
    c := (select format('%s | libro %s | qb %s | dif %s | explicada %s | sin explicar %s | qb bien %s | el libro de c4 es el de la cédula %s | amarra %s',
                        q.estado, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.explicada_qb, q.sin_explicar_qb,
                        case when q.qb_ok then 'sí' else 'no' end, case when q.libro_igual then 'sí' else 'no' end, case when q.amarra then 'sí' else 'no' end)
            from _c13_qb q where q.cuenta = '1093');
    perform fn_diferencia_anotar(v_per, '3193', '-40.00', 'criterio', 'C13 PRUEBA: QuickBooks registra ese aporte el mes siguiente');
    perform fn_diferencia_anotar(v_per, '1093', '40.00', 'puente', 'C13 PRUEBA: un depósito que QuickBooks tiene en otro mes');
    d := (select format('el patrimonio %s | libro %s | qb %s | dif %s | explicada %s | sin explicar %s | qb bien %s | el libro de c4 es el de la cédula %s | amarra %s',
                        q.estado, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.explicada_qb, q.sin_explicar_qb,
                        case when q.qb_ok then 'sí' else 'no' end, case when q.libro_igual then 'sí' else 'no' end, case when q.amarra then 'sí' else 'no' end)
            from fn_cedula_qb(v_per) q where q.cuenta = '3193')
         || (select format('; el banco, con QuickBooks bien y sin auxiliar: qb bien %s, amarra %s',
                           case when q.qb_ok then 'sí' else 'no' end, case when q.amarra then 'sí' else 'no' end)
               from fn_cedula_qb(v_per) q where q.cuenta = '1093');
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1093', 'concepto', 'C13 PRUEBA: lo que dice el statement del banco', 'monto', '1000.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA statement'));
    e := (select case when q.amarra then 'sí' else 'no' end from fn_cedula_qb(v_per) q where q.cuenta = '1093');
    f := (select case when (select count(*) from v_cedula_qb v where v.periodo = v_per) = (select count(*) from fn_cedula_qb(v_per))
                           and not exists (select v.cuenta, v.saldo_libro, v.saldo_qb, v.diferencia_qb, v.sin_explicar_qb, v.amarra, v.al, v.documento
                                             from v_cedula_qb v where v.periodo = v_per
                                           except
                                           select q.cuenta, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.sin_explicar_qb, q.amarra, q.al, q.documento
                                             from fn_cedula_qb(v_per) q)
                           and exists (select 1 from fn_cedula_qb_periodos() p where p.periodo = v_per)
                      then 'sí' else 'no' end);
    g := case when v_sin is null then 'no hay ningún mes sin balanza con que probar'
              else (select case when count(*) > 0 and not bool_or(q.qb_cargada) and count(q.saldo_qb) = 0 and count(q.amarra) = 0 and min(q.al) = max(q.al)
                                then 'sin QuickBooks' else 'CON QuickBooks' end from fn_cedula_qb(v_sin) q) end;
    v_obt := format('la balanza: cargada, su documento y su fecha: %s | el patrimonio: %s | el banco: %s | anotada en c4: %s | '
                    'el banco con su renglón a mano: amarra %s | la vista, por período, es la función: %s | un mes sin balanza: %s | '
                    'un período que no existe: %s', a, b, c, d, e, f, g,
                    pg_temp.c13_estado('select count(*) from public.fn_cedula_qb(''1999-01'')'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'LA CÉDULA AL LADO DE QUICKBOOKS (c4), para el cuadre de la 12b: con una balanza de QuickBooks cargada en c4 para el mes, cada cuenta trae lo que dice QuickBooks, la diferencia con el libro (40) y lo que queda sin explicar, en su lado natural; anotada la diferencia en c4, QuickBooks queda bien, y «amarra» solo cuando además el libro no pide nada (cuadra con su auxiliar, está explicado, o sale del propio libro como el patrimonio: a ese lo amarra justo esta comparación); la vista por período es la función; un mes sin balanza sale sin QuickBooks; un período que no existe, 22023. Nada se carga desde c13',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. EL CONTROL DE LA CÉDULA (fn_cedula_control). El 10 (trae todas las
--     cuentas y su saldo es el del libro) en verde. Y cada aviso, por lo que
--     la prueba mueve (con los datos de la base puede haber otras cuentas en
--     rojo: se cuenta una más y una menos): el 20 con una cuenta que no
--     cuadra, y de vuelta al explicarla; el 30 con una cuenta con saldo y sin
--     auxiliar, y de vuelta con su renglón; el 50 con un renglón sin
--     documento, y de vuelta al ponérselo; el 40 con una explicación que se
--     quedó vieja (que ya no cuenta en el 20), y de vuelta al explicarla otra
--     vez. Antes del mes desde el que se avisa, o sin mes dicho, o en un mes
--     que todavía no termina, los avisos no se ponen en rojo: dicen cuánto
--     saldría.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_sig text := pg_temp.c13('mes_sig'); v_cur text := pg_temp.c13('en_curso');
  k20 int; k30 int; k40 int; k50 int; v_id uuid; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'el 10: verde | el 20: +1 y rojo; antes del mes desde el que se avisa: verde, y dice cuántas saldrían: sí; sin mes dicho: verde y lo dice: sí; '
                'en un mes sin terminar: los 4 avisos verdes y lo dice: sí; explicada: +0 | el 30: +1 y rojo; con su renglón: +0 | '
                'el 50: +1 y rojo; con su documento: +0 | el 40: +1 y rojo, y el 20 +0; vuelta a explicar: +0 | '
                'un período que no existe: la de hoy, sin avisar: sí | el 10 al final: verde';
begin
  if pg_temp.c13_omitir(27, 'el control de la cédula', v_esp, array['mes', 'cuentas', 'en_curso']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    k20 := pg_temp.c13_ctl_n(20); k30 := pg_temp.c13_ctl_n(30); k40 := pg_temp.c13_ctl_n(40); k50 := pg_temp.c13_ctl_n(50);
    a := pg_temp.c13_ctl(10);
    -- el 20: una cuenta que no cuadra
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'));
    b := format('%s y %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'),
                case when pg_temp.c13_ctl(20) = 'rojo' and pg_temp.c13_ctl_det(20) like '% cuenta(s) no cuadran con su auxiliar al % y nadie lo ha explicado: %'
                     then 'rojo' else pg_temp.c13_ctl(20) || ': ' || pg_temp.c13_ctl_det(20) end);
    -- antes del mes desde el que se avisa; sin mes dicho; y en un mes que no ha terminado
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_sig));
    b := b || format('; antes del mes desde el que se avisa: %s, y dice cuántas saldrían: %s', pg_temp.c13_ctl(20),
                     case when pg_temp.c13_ctl_det(20) = format('El cierre avisa de la cédula desde %s; %s es anterior. Hoy saldrían %s cuenta(s) sin cuadrar ni explicar.',
                                                                  fn_cedula_mes(v_sig), fn_cedula_mes(v_per), k20 + 1)
                               and pg_temp.c13_ctl(30) = 'verde' and pg_temp.c13_ctl(40) = 'verde' and pg_temp.c13_ctl(50) = 'verde'
                          then 'sí' else 'no: ' || pg_temp.c13_ctl_det(20) end);
    perform pg_temp.c13_config('{"avisar_desde": null}');
    b := b || format('; sin mes dicho: %s y lo dice: %s', pg_temp.c13_ctl(20),
                     case when pg_temp.c13_ctl_det(20) like 'El cierre todavía no avisa de la cédula en ningún mes (no se ha dicho desde cuál). Hoy saldrían %'
                          then 'sí' else 'no: ' || pg_temp.c13_ctl_det(20) end);
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    b := b || format('; en un mes sin terminar: los %s avisos verdes y lo dice: %s',
                     (select count(*) from fn_cedula_control(v_cur) k where k.nivel = 'aviso' and k.ok),
                     case when pg_temp.c13_ctl_det(20, v_cur) like '% termina el %: la cédula se mira al cerrar.%' then 'sí'
                          else 'no: ' || pg_temp.c13_ctl_det(20, v_cur) end);
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz');
    b := b || '; explicada: ' || to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990');
    -- el 30: una cuenta con saldo y sin auxiliar
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'impuestos de nómina por pagar', '6200', '2293', 900);
    c := format('%s y %s', to_char(pg_temp.c13_ctl_n(30) - k30, 'FMS990'),
                case when pg_temp.c13_ctl(30) = 'rojo' and pg_temp.c13_ctl_det(30) like '% cuenta(s) tienen saldo al % y nada debajo que lo sostenga: %'
                     then 'rojo' else pg_temp.c13_ctl(30) || ': ' || pg_temp.c13_ctl_det(30) end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2293', 'concepto', 'C13 PRUEBA: 941 del trimestre por pagar', 'monto', '900.00',
              'desde', pg_temp.c13_d(15)::text, 'documento', 'C13 PRUEBA diario de la nómina'));
    c := c || '; con su renglón: ' || to_char(pg_temp.c13_ctl_n(30) - k30, 'FMS990');
    -- el 50: un renglón a mano sin documento
    v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1493', 'concepto', 'C13 PRUEBA: un permiso pagado por adelantado', 'monto', '5.00',
                                                        'desde', pg_temp.c13_d(15)::text))->>'id')::uuid;
    d := format('%s y %s', to_char(pg_temp.c13_ctl_n(50) - k50, 'FMS990'),
                case when pg_temp.c13_ctl(50) = 'rojo' and pg_temp.c13_ctl_det(50) like '% renglón(es) escritos a mano no dicen su documento: %'
                     then 'rojo' else pg_temp.c13_ctl(50) || ': ' || pg_temp.c13_ctl_det(50) end);
    v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('id', v_id::text, 'documento', 'C13 PRUEBA recibo del permiso'))->>'id')::uuid;
    d := d || '; con su documento: ' || to_char(pg_temp.c13_ctl_n(50) - k50, 'FMS990');
    perform pg_temp.c13_ser('dueno');
    perform fn_cedula_renglon_anular(v_id, 'C13 PRUEBA: ya no hace falta');
    perform pg_temp.c13_ser('editor');
    -- el 40: la explicación de la 1693 se queda vieja (y ya no cuenta en el 20)
    perform pg_temp.c13_dh(pg_temp.c13_d(22), 'diez más que entran a la cuenta', '1693', '3193', 10);
    e := format('%s y %s, y el 20 %s', to_char(pg_temp.c13_ctl_n(40) - k40, 'FMS990'),
                case when pg_temp.c13_ctl(40) = 'rojo' and pg_temp.c13_ctl_det(40) like '% cuenta(s) se explicaron al % y después cambió su saldo o su auxiliar: %'
                     then 'rojo' else pg_temp.c13_ctl(40) || ': ' || pg_temp.c13_ctl_det(40) end,
                to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'));
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: ahora son 110: la luz y un ajuste de 10');
    e := e || '; vuelta a explicar: ' || to_char(pg_temp.c13_ctl_n(40) - k40, 'FMS990');
    f := case when (select count(*) from fn_cedula_control('1999-01')) = 6
                   and pg_temp.c13_ctl_det(20, '1999-01') like 'El período 1999-01 no existe: esta es la cédula de hoy.%'
                   and (select bool_and(k.ok) from fn_cedula_control('1999-01') k where k.nivel = 'aviso') then 'sí' else 'no' end;
    g := pg_temp.c13_ctl(10);
    v_obt := format('el 10: %s | el 20: %s | el 30: %s | el 50: %s | el 40: %s | un período que no existe: la de hoy, sin avisar: %s | el 10 al final: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'EL CONTROL DE LA CÉDULA: el 10 (trae todas las cuentas y su saldo es el del libro) en verde; y cada aviso por lo que la prueba mueve (una más, una menos): el 20 con una cuenta que no cuadra y de vuelta al explicarla; el 30 con una cuenta con saldo y sin auxiliar y de vuelta con su renglón; el 50 con un renglón sin documento y de vuelta al ponérselo; el 40 con una explicación que se quedó vieja (que ya no cuenta en el 20) y de vuelta al explicarla otra vez; antes del mes desde el que se avisa, sin mes dicho o en un mes sin terminar no se ponen en rojo y dicen cuánto saldría',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. EL 90: LAS PROTECCIONES DE LA CAPA, en rojo y de vuelta. Cada daño se
--     hace dentro de la prueba, se mira que el control lo nombra y se deshace.
do $$
declare
  v_obt text; v_0 text; v_r text := ''; v_x record; v_ok text;
  v_esp text := 'verde al empezar | en rojo y lo nombra: anon ejecuta sí, permisos de más sí, sin candado de filas sí, sin su policy sí, '
                'la guarda apagada sí, la vista sin los permisos de quien mira sí, la app puede borrar sí, una interna con API sí | verde al deshacerlo';
begin
  if pg_temp.c13_omitir(28, 'las protecciones de la capa', v_esp, array[]::text[]) then return; end if;
  begin
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_reloj();
    v_0 := pg_temp.c13_ctl(90, pg_temp.c13('en_curso'));
    for v_x in
      select * from (values
        (1, 'anon ejecuta',        'grant execute on function public.fn_cedula_resumen(date) to anon',            '%fn_cedula_resumen la puede ejecutar anon%'),
        (2, 'permisos de más',     'alter function public.fn_cedula_toca() security definer',                     '%fn_cedula_toca corre con permisos de más%'),
        (3, 'sin candado de filas', 'alter table public.cedula_manual disable row level security',                '%cedula_manual sin su candado de filas%'),
        (4, 'sin su policy',       'drop policy cedula_explicaciones_dueno on public.cedula_explicaciones',       '%cedula_explicaciones sin su candado de solo-dueño%'),
        (5, 'la guarda apagada',   'alter table public.cedula_config disable trigger trg_cedula_config_guarda',   '%la guarda de cedula_config está apagada%'),
        (6, 'la vista sin los permisos de quien mira', 'alter view public.v_cedula set (security_invoker = false)', '%v_cedula no lee con los permisos de quien mira%'),
        (7, 'la app puede borrar', 'grant delete on public.cedula_manual to authenticated',                       '%la app puede DELETE en cedula_manual%'),
        (8, 'una interna con API', 'grant execute on function public.fn_cedula_pegado() to authenticated',        '%fn_cedula_pegado la puede ejecutar la app%')
      ) as t(n, que, orden_sql, dice) order by 1
    loop
      begin
        execute v_x.orden_sql;
        v_ok := case when pg_temp.c13_ctl(90, pg_temp.c13('en_curso')) = 'rojo' and pg_temp.c13_ctl_det(90, pg_temp.c13('en_curso')) like v_x.dice
                          and pg_temp.c13_ctl_det(90, pg_temp.c13('en_curso')) like 'Las protecciones de la cédula no están como se pegaron: %'
                     then 'sí' else 'no (' || coalesce(pg_temp.c13_ctl_det(90, pg_temp.c13('en_curso')), 'nulo') || ')' end;
        raise exception using errcode = 'MXT01';
      exception when sqlstate 'MXT01' then null;
      end;
      v_r := v_r || case when v_r = '' then '' else ', ' end || v_x.que || ' ' || v_ok;
    end loop;
    v_obt := format('%s al empezar | en rojo y lo nombra: %s | %s al deshacerlo', v_0, v_r, pg_temp.c13_ctl(90, pg_temp.c13('en_curso')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'EL 90, LAS PROTECCIONES DE LA CAPA, en rojo y de vuelta: una función ejecutable por anon, una con permisos de más, una tabla sin su candado de filas o sin su policy del dueño, una guarda apagada, una vista que no lee con los permisos de quien mira, la app pudiendo borrar, una función interna con API: cada daño lo nombra el control, y al deshacerlo vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. LA FILA DEL CIERRE (fn_cedula_cierre): UNA fila, la 178, un AVISO con
--     ir_a = cedula y el nombre FIJO (la ronda del cierre avisa al teléfono
--     de cada rojo nuevo por el nombre de la fila: una lista de cuentas en el
--     nombre sería un aviso cada mañana). En verde lleva el detalle del
--     control; en rojo, qué hacer y que no detiene; y cabe en lo que c9
--     guarda por fila.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_sig text := pg_temp.c13('mes_sig');
  c_nombre constant text := 'cédula: cada saldo del balance con su auxiliar cuadrado o explicado (c13)';
  r0 record; r1 record; r2 record; r3 record; a text; b text; c text; d text;
  v_esp text := 'una fila, la 178, un aviso, ir a cedula, con su nombre fijo: sí | antes del mes desde el que se avisa: verde, sin qué hacer, y su '
                'detalle es el del control: sí | con una cuenta sin cuadrar: rojo, dice qué hacer y que no detiene: sí; el mismo nombre: sí; '
                'cabe en 1500: sí | explicada: como antes';
begin
  if pg_temp.c13_omitir(29, 'la fila del cierre', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_sig));
    select count(*) as n, min(k.orden) as orden, min(k.nivel) as nivel, bool_and(k.ok) as ok, min(k.ir_a) as ir_a, min(k.control) as control,
           min(k.detalle) as detalle, min(k.que_hacer) as que_hacer into r0 from fn_cedula_cierre(v_per) k;
    a := case when r0.n = 1 and r0.orden = 178 and r0.nivel = 'aviso' and r0.ir_a = 'cedula' and r0.control = c_nombre then 'sí'
              else format('no: %s fila(s), orden %s, %s, %s, «%s»', r0.n, r0.orden, r0.nivel, r0.ir_a, r0.control) end;
    b := format('%s, %s, y su detalle es el del control: %s', case when r0.ok then 'verde' else 'rojo' end,
                case when r0.que_hacer is null then 'sin qué hacer' else 'CON qué hacer' end,
                case when r0.detalle = pg_temp.c13_ctl_det(20) then 'sí' else 'no' end);
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    select bool_and(k.ok) as ok into r1 from fn_cedula_cierre(v_per) k;       -- (cómo está con los datos de esta base, antes de lo de la prueba)
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'));
    select count(*) as n, min(k.orden) as orden, min(k.nivel) as nivel, bool_and(k.ok) as ok, min(k.ir_a) as ir_a, min(k.control) as control,
           min(k.detalle) as detalle, min(k.que_hacer) as que_hacer into r2 from fn_cedula_cierre(v_per) k;
    c := format('%s, dice qué hacer y que no detiene: %s; el mismo nombre: %s; cabe en 1500: %s', case when r2.ok then 'verde' else 'rojo' end,
                case when r2.que_hacer like 'No detiene el cierre. En Contabilidad → Cédula:%' and r2.detalle like '% cuenta(s) no cuadran con su auxiliar al %'
                     then 'sí' else 'no: ' || coalesce(r2.que_hacer, 'nulo') || ' / ' || coalesce(r2.detalle, 'nulo') end,
                case when r2.control = c_nombre and r2.n = 1 and r2.orden = 178 and r2.nivel = 'aviso' and r2.ir_a = 'cedula' then 'sí' else 'no' end,
                case when length(r2.detalle) <= 1500 then 'sí' else 'no: ' || length(r2.detalle) end);
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz');
    select bool_and(k.ok) as ok into r3 from fn_cedula_cierre(v_per) k;
    d := case when r3.ok is not distinct from r1.ok then 'como antes' else format('NO: antes %s y ahora %s', r1.ok, r3.ok) end;
    v_obt := format('una fila, la 178, un aviso, ir a cedula, con su nombre fijo: %s | antes del mes desde el que se avisa: %s | '
                    'con una cuenta sin cuadrar: %s | explicada: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'LA FILA DEL CIERRE (fn_cedula_cierre): una sola fila, la 178, un aviso con ir_a = cedula y el nombre fijo; antes del mes desde el que se avisa va en verde con el detalle del control; con una cuenta sin cuadrar va en rojo, dice qué hacer y que no detiene, con el mismo nombre, y cabe en lo que el cierre guarda por fila; explicada, vuelve a como estaba',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 30. EL CIERRE (c9) MIRA LA CÉDULA: fn_cierre_revisar trae su fila 178 (la
--     que le da fn_cedula_cierre), un aviso que NO detiene. «Omitida»
--     mientras el c9-cierre.sql de esta base no traiga el bloque de c13 (se
--     vuelve a pegar c9-cierre.sql).
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_sig text := pg_temp.c13('mes_sig');
  c_nombre constant text := 'cédula: cada saldo del balance con su auxiliar cuadrado o explicado (c13)';
  v_d0 bigint; v_d1 bigint; v_ok0 boolean; a text; b text; c text; d text; r record;
  v_esp text := 'una fila 178, un aviso, ir a cedula, con el nombre fijo: sí | con una cuenta sin cuadrar: en rojo, con el detalle y el qué hacer de la '
                'cédula: sí; lo que detiene el cierre: +0 | explicada: como antes | antes del mes desde el que se avisa: verde';
begin
  if pg_temp.c13_omitir(30, 'el cierre mira la cédula', v_esp, array['mes', 'cuentas', 'c9']) then return; end if;
  if pg_temp.c13('c9_cedula') <> 'true' then
    insert into _pruebas values (30, 'el cierre mira la cédula', v_esp,
      'omitida: el c9-cierre.sql de esta base todavía no trae el bloque de la cédula (su fila 178): se vuelve a pegar c9-cierre.sql y se corre esto otra vez', null);
    return;
  end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    select count(*) filter (where k.orden = 178) as n, min(k.nivel) filter (where k.orden = 178) as nivel,
           min(k.ir_a) filter (where k.orden = 178) as ir_a, min(k.control) filter (where k.orden = 178) as control,
           bool_and(k.ok) filter (where k.orden = 178) as ok,
           count(*) filter (where k.nivel = 'detiene' and k.ok is distinct from true) as detiene
      into r from fn_cierre_revisar(v_per) k;
    v_d0 := r.detiene; v_ok0 := r.ok;
    a := case when r.n = 1 and r.nivel = 'aviso' and r.ir_a = 'cedula' and r.control = c_nombre then 'sí'
              else format('no: %s fila(s), %s, %s, «%s»', r.n, r.nivel, r.ir_a, r.control) end;
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text, 'documento', 'C13 PRUEBA contrato de renta'));
    select count(*) filter (where k.nivel = 'detiene' and k.ok is distinct from true) into v_d1 from fn_cierre_revisar(v_per) k;
    b := format('%s; lo que detiene el cierre: %s',
                (select case when not k.ok and k.detalle = left(z.detalle, 1500) and k.que_hacer = z.que_hacer and k.control = c_nombre and k.nivel = 'aviso'
                             then 'en rojo, con el detalle y el qué hacer de la cédula: sí' else 'no: ' || coalesce(k.detalle, 'nulo') end
                   from fn_cierre_revisar(v_per) k cross join fn_cedula_cierre(v_per) z where k.orden = 178),
                to_char(v_d1 - v_d0, 'FMS990'));
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz');
    c := (select case when k.ok is not distinct from v_ok0 then 'como antes' else 'NO' end from fn_cierre_revisar(v_per) k where k.orden = 178);
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_sig));
    d := (select case when k.ok then 'verde' else 'rojo' end from fn_cierre_revisar(v_per) k where k.orden = 178);
    v_obt := format('una fila 178, un aviso, ir a cedula, con el nombre fijo: %s | con una cuenta sin cuadrar: %s | explicada: %s | '
                    'antes del mes desde el que se avisa: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'EL CIERRE (c9) MIRA LA CÉDULA: la revisión del cierre del mes trae UNA fila 178, la de la cédula, un aviso con su nombre fijo; con una cuenta sin cuadrar va en rojo con el detalle y el qué hacer que da la cédula, y lo que detiene el cierre no cambia (no detiene); explicada, vuelve a como estaba; antes del mes desde el que se avisa, verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 31. LOS TEXTOS, EN LLANO: ni el detalle ni el qué hacer de una fila de la
--     cédula, ni de dónde sale cada auxiliar, ni lo que la cédula pone en sus
--     renglones, ni el control o la fila del cierre (en verde y en rojo), ni
--     los errores de cada día nombran una función, una tabla o una vista.
--     (El cuadre de las protecciones, en rojo, sí dice cuál es el objeto que
--     quedó mal: es para quien lo arregla. Y lo que escribió otra capa o
--     Edgar —la descripción de un asiento, un concepto— no es texto de c13.)
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_txt text[] := '{}'; v_mal text; v_n int; v_c jsonb; v_id uuid;
  v_esp text := 'ninguno';
begin
  if pg_temp.c13_omitir(31, 'los textos no nombran funciones', v_esp, array['mes', 'cuentas', 'en_curso']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per, 'patrimonio', 'mayor'));
    -- una escena con un poco de todo
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito', '1093', '3193', 1000);
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito en garantía', '1693', '3193', 500);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', pg_temp.c13_d(2)::text));
    perform pg_temp.c13_explicar('1693', v_h, 'C13 PRUEBA: los 100 que faltan son el depósito de la luz');
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'impuestos de nómina por pagar', '6200', '2293', 900);
    perform pg_temp.c13_explicar('2293', v_h, 'C13 PRUEBA: es el 941 del trimestre, se paga en enero');
    perform pg_temp.c13_dh(pg_temp.c13_d(16), 'cien más de impuestos de nómina', '6200', '2293', 100);
    perform pg_temp.c13_dh(pg_temp.c13_d(12), 'una cuenta por cobrar a mano, sin factura',
                           coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc'), '1110'), '3100', 123.45);
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'una cuenta por pagar a mano, sin proveedor', '6200',
                           coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp'), '2010'), 77.77);
    if pg_temp.c13('c6') = 'true' then
      v_c := fn_conciliar('1093', pg_temp.c13_d(10), '0.00');     -- (el statement en cero: el depósito va en tránsito)
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      perform pg_temp.c13_dh(pg_temp.c13_d(12), 'un depósito después de la conciliación', '1093', '3193', 50);
      perform pg_temp.c13_dh(pg_temp.c13_d(1), 'el desembolso del préstamo', '1093', '2594', 24000);
      perform fn_prestamo_guardar(jsonb_build_object('prestamista', 'ZZ C13 PRUEBA BANK', 'descripcion', 'camioneta de prueba',
                'principal', '24000.00', 'tasa_anual', '12', 'cuota', '1000.00', 'primer_pago', pg_temp.c13_d(20)::text,
                'cuenta', '2593', 'cuenta_largo', '2594', 'cuenta_interes', '7100', 'cuenta_banco', '1093',
                'saldo_inicial', '24000.00', 'saldo_inicial_al', pg_temp.c13_d(1)::text));
      perform pg_temp.c13_dh(v_h - 3, 'un pago que entra a la cuenta de pólizas', '1493', '1093', 300);
    end if;
    if pg_temp.c13('c9') = 'true' then
      perform pg_temp.c13_ser('dueno');
      perform fn_activo_alta(jsonb_build_object('descripcion', 'ZZ C13 PRUEBA andamio', 'cuenta', '1583',
                'fecha_servicio', pg_temp.c13_d(5)::text, 'costo', '250.00', 'metodo', 'linea_recta', 'vida_meses', 60));
      perform pg_temp.c13_ser('editor');
    end if;
    if pg_temp.c13('c12') = 'true' then
      perform pg_temp.c13_dh(pg_temp.c13_d(20), 'un asiento a mano en el WIP', '1200', '3100', 50, 'c13-prueba-w');
    end if;
    if pg_temp.c13('p1') = 'true' then
      perform pg_temp.c13_dh(pg_temp.c13_d(9), 'algo en la cuenta de paso de Stripe',
                             coalesce((select c.cuenta_paso from stripe_config c where c.id = 1), '1140'), '3193', 25);
    end if;
    -- la cédula de dos días, de dónde sale cada auxiliar, y lo que la cédula pone en los renglones
    -- (lo que alguien escribió en una explicación —va entre «» al final del detalle— no es texto de c13)
    select v_txt || array_agg(format('fila %s: %s · %s · %s · %s', x.cuenta, x.auxiliar, x.origen, regexp_replace(x.detalle, ': «.*»$', ': «…»'),
                                     coalesce(x.que_hacer, '')))
      into v_txt from (select * from fn_cedula(v_h) union all select * from fn_cedula(v_h + 5)) x;
    select v_txt || array_agg(format('cuenta %s: %s · %s · %s', k.cuenta, k.auxiliar, k.origen, coalesce(k.vacio, ''))) into v_txt from fn_cedula_cuentas() k;
    select v_txt || array_agg(format('renglón %s: %s · %s', i.cuenta,
                                     case when i.clase = 'suelto' or i.clave in ('statement', 'hasta_el_corte', 'despues', 'despues_del_dia', 'apertura', 'ajuste_cpa')
                                               or i.fuente in ('mayor', 'dr15') then i.concepto else '' end,
                                     case when i.fuente = 'manual' or i.ref_tabla = 'conciliacion_partidas' then '' else coalesce(i.nota, '') end))
      into v_txt from (select * from fn_cedula_partidas(v_h, null) union all select * from fn_cedula_partidas(v_h + 5, null)
                       union all select * from fn_cedula_partidas(v_h, '1030')) i;
    -- el control y la fila del cierre: en rojo (se avisa desde este mes), antes de avisar, sin mes dicho, y en un mes sin terminar
    select v_txt || array_agg(k.orden || ': ' || k.control || ' · ' || k.detalle) into v_txt from fn_cedula_control(v_per) k;
    select v_txt || array_agg('cierre: ' || k.control || ' · ' || k.detalle || ' · ' || coalesce(k.que_hacer, '')) into v_txt from fn_cedula_cierre(v_per) k;
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_cedula_control(pg_temp.c13('en_curso')) k;
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_cedula_control('1999-01') k;
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', pg_temp.c13('mes_sig')));
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_cedula_control(v_per) k;
    select v_txt || array_agg('cierre: ' || k.detalle) into v_txt from fn_cedula_cierre(v_per) k;
    perform pg_temp.c13_config('{"avisar_desde": null}');
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_cedula_control(v_per) k;
    select v_txt || array_agg('pegado: ' || g.detalle) into v_txt from fn_cedula_pegado() g where g.que in ('cedula_config', 'la cédula', 'control', 'qué falta');
    -- sin las capas opcionales
    begin
      perform pg_temp.c13_fingir_capas('{"c4": false, "c6": false, "c9": false, "c12": false, "p1": false}');
      select v_txt || array_agg(format('sin capas %s: %s · %s', x.cuenta, regexp_replace(x.detalle, ': «.*»$', ': «…»'), coalesce(x.que_hacer, '')))
        into v_txt from fn_cedula(v_h) x;
      select v_txt || array_agg(format('sin capas, cuenta %s: %s', k.cuenta, coalesce(k.vacio, ''))) into v_txt from fn_cedula_cuentas() k;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- los errores de cada día
    v_id := (select m.id from cedula_manual m where m.cuenta = '1693' limit 1);
    v_txt := v_txt || array[
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '6200', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '2100', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '9999-NO', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '0', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', 'mucho', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.234', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', '31/10/2026'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', '2026-02-31'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', v_h::text, 'hasta', (v_h - 1)::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'monto', '1.00', 'desde', v_h::text))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: x', 'monto', '1.00', 'desde', v_h::text, 'color', 'rojo'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('id', v_id::text, 'cuenta', '1493'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('id', gen_random_uuid()::text, 'monto', '2.00'))),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon(%L::jsonb)', jsonb_build_object('id', 'no-es-un-id', 'monto', '2.00'))),
      pg_temp.c13_dice('select public.fn_cedula_renglon(''[1]''::jsonb)'),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon_anular(%L, %L)', v_id, ' ')),
      pg_temp.c13_dice(format('select public.fn_cedula_renglon_anular(%L, %L)', gen_random_uuid(), 'C13 PRUEBA: no existe')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '3193', v_h, 'C13 PRUEBA: una que cuadra no se explica')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '1493', pg_temp.c13_d(0), 'C13 PRUEBA: una sin saldo no se explica')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', v_h, 'porque sí')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '1693', pg_temp.c13('hoy')::date + 1, 'C13 PRUEBA: una fecha que no ha llegado')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, null, %L)', '1693', 'C13 PRUEBA: sin fecha no se explica')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', ' ', v_h, 'C13 PRUEBA: sin cuenta no se explica')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '6200', v_h, 'C13 PRUEBA: una de resultados no está')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '2100', v_h, 'C13 PRUEBA: una de grupo no está')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicacion_retirar(%L, %L, %L)', '3193', v_h, 'C13 PRUEBA: no hay ninguna')),
      pg_temp.c13_dice(format('select public.fn_cedula_explicacion_retirar(%L, %L, %L)', '1693', v_h, ' ')),
      pg_temp.c13_dice('select public.fn_cedula_config(''{"color": "rojo"}'')'),
      pg_temp.c13_dice('select public.fn_cedula_config(''{"avisar_desde": "enero"}'')'),
      pg_temp.c13_dice('select public.fn_cedula_config(''{"patrimonio": "acta"}'')'),
      pg_temp.c13_dice('select public.fn_cedula_config(''[1]'')'),
      pg_temp.c13_dice('select count(*) from public.fn_cedula_qb(''1999-01'')'),
      case when pg_temp.c13('equipo') is null then '42501 (no hay nadie del equipo con quien probar)'
           else pg_temp.c13_dice(format('select public.fn_cedula_resumen(%L)', v_h), 'equipo') end];
    select count(*), string_agg(left(t, 200), ' || ') filter (where t ~ '(fn_|cedula_|v_cedula|mx_|select |\(\)|security|jsonb|null)' or t ~ '^ok$')
      into v_n, v_mal from unnest(v_txt) t;
    v_obt := coalesce(v_mal, case when v_n >= 200 then 'ninguno' else 'solo se miraron ' || v_n || ' textos' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'LOS TEXTOS, EN LLANO: el detalle y el qué hacer de cada fila de la cédula (con un poco de todo: cuadrando, sin cuadrar, explicada, vieja, sin auxiliar, sin las capas), de dónde sale cada auxiliar, lo que la cédula pone en sus renglones, el control y la fila del cierre (en verde, en rojo, antes de avisar y en un mes sin terminar), el pegado y los errores de cada día no nombran ninguna función, tabla ni vista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. LA PANTALLA NO SUMA: los totales (fn_cedula_resumen) son los de la
--     cédula, contados aquí otra vez; lo que suma el auxiliar de cada cuenta
--     es la suma de sus renglones (y lo suelto, lo de después y lo que no
--     casa, lo de los suyos), cuenta por cuenta, a hoy y al día que toca, con
--     todo lo de esta base y lo de la prueba; pedir los renglones de una
--     cuenta da los mismos que pedirlos todos; cada vista es su función; y
--     el dueño, por la API, ve exactamente lo que ve el SQL Editor.
--     (No postea nada: los renglones y la explicación de la prueba son de
--     hoy. Corre también con todos los meses cerrados.)
do $$
declare
  v_obt text; v_f date := pg_temp.c13('hoy')::date; r jsonb; a text; b text; c text; d text; e text; f text;
  v_m0 text; v_m1 text; v_p0 text; v_p1 text; v_q0 text := '-'; v_q1 text := '-'; v_err bigint;
  v_perq text := coalesce(fn_cedula_toca(), pg_temp.c13('en_curso'), pg_temp.c13('mes'));
  v_esp text := 'los totales son los de la cédula, sus 26 llaves: sí | el auxiliar de cada cuenta es la suma de sus renglones: sí, en todas | '
                'los renglones de una cuenta son los mismos que al pedirlos todos: sí | sin fecha es el último día del período que toca: sí | '
                'las vistas son sus funciones: sí | el dueño por la API ve lo mismo que el SQL Editor, y ninguna capa le sale ilegible: sí';
begin
  if pg_temp.c13_omitir(32, 'los totales y los renglones', v_esp, array['cuentas']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
              'desde', v_f::text, 'documento', 'C13 PRUEBA contrato de renta'));
    perform pg_temp.c13_explicar('1693', v_f, 'C13 PRUEBA: el depósito todavía no está asentado en el libro');
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1493', 'concepto', 'C13 PRUEBA: un permiso pagado por adelantado', 'monto', '5.00',
              'desde', v_f::text));
    perform pg_temp.c13_ser('dueno');
    r := fn_cedula_resumen(v_f);
    perform pg_temp.c13_ser('editor');
    select case when (r->>'cuentas')::int = count(*) and (r->>'con_saldo')::int = count(*) filter (where x.saldo_libro <> 0)
                     and (r->>'cuadran')::int = count(*) filter (where x.estado = 'cuadra')
                     -- (de las que cuadran: contra algo que no es el libro, o por las partidas del propio libro; y aparte, sin
                     -- contar entre las que cuadran, las que salen del propio libro o se llevan a la fecha con él)
                     and (r->>'cuadran_papel')::int = count(*) filter (where x.estado = 'cuadra' and to_jsonb(x)->>'sosten' = 'papel')
                     and (r->>'cuadran_partidas')::int = count(*) filter (where x.estado = 'cuadra' and to_jsonb(x)->>'sosten' = 'partidas')
                     and (r->>'cuadran_papel')::int + (r->>'cuadran_partidas')::int = (r->>'cuadran')::int
                     and (r->>'del_libro')::int = count(*) filter (where x.estado = 'del_libro')
                     and count(*) filter (where x.estado = 'del_libro' and to_jsonb(x)->>'sosten' not in ('libro', 'llevado')) = 0
                     and count(*) filter (where to_jsonb(x)->>'sosten' = 'libro' and x.estado <> 'del_libro') = 0
                     and count(*) filter (where x.estado = 'del_libro' and x.pendiente) = 0
                     and (r->>'explicadas')::int = count(*) filter (where x.estado = 'explicada') and (r->>'explicadas')::int >= 1
                     and (r->>'no_cuadran')::int = count(*) filter (where x.estado = 'no_cuadra') and (r->>'no_cuadran')::int >= 1
                     and (r->>'sin_auxiliar')::int = count(*) filter (where x.estado = 'sin_auxiliar' and x.saldo_libro <> 0)
                     -- (lo que solo falta mirar con el código del teléfono: aquí, con el código, ninguna)
                     and (r->>'con_codigo')::int = count(*) filter (where x.estado = 'con_codigo')
                     and (r->>'pendientes')::int = count(*) filter (where x.pendiente) and (r->>'pendientes')::int >= 1
                     and (r->>'explicaciones_viejas')::int = count(*) filter (where x.explicacion_vieja)
                     and (r->>'listo')::boolean = (count(*) filter (where x.pendiente) = 0)
                     and (r->>'activo')::numeric = coalesce(sum(x.signo * x.saldo_libro) filter (where x.tipo = 'activo'), 0)
                     and (r->>'pasivo')::numeric = coalesce(-sum(x.signo * x.saldo_libro) filter (where x.tipo = 'pasivo'), 0)
                     and (r->>'capital')::numeric = coalesce(-sum(x.signo * x.saldo_libro) filter (where x.tipo = 'capital'), 0)
                     -- (el balance cierra a la vista: activo = pasivo + patrimonio + el resultado que todavía no está en el
                     -- patrimonio, que es lo que suman las cuentas de resultados del libro hasta ese día)
                     and (r->>'resultado')::numeric = (select coalesce(-sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                         join cuentas k on k.codigo = l.cuenta
                                                        where a.fecha_contable <= v_f and k.tipo not in ('activo', 'pasivo', 'capital'))
                     and (r->>'patrimonio_total')::numeric = (r->>'capital')::numeric + (r->>'resultado')::numeric
                     and (r->>'activo')::numeric = (r->>'pasivo')::numeric + (r->>'capital')::numeric + (r->>'resultado')::numeric
                     and (r->>'balance_cuadra')::boolean
                     -- (la diferencia pendiente no cuenta el reparto de un préstamo entre corriente y largo plazo: va aparte, una vez)
                     and (r->>'diferencia_pendiente')::numeric
                         = coalesce(sum(abs(x.diferencia)) filter (where x.pendiente and x.estado = 'no_cuadra' and not (to_jsonb(x)->>'solo_reparto')::boolean), 0)
                     and (r->>'reparto_pendiente')::numeric
                         = coalesce(sum(abs(x.diferencia)) filter (where x.pendiente and x.estado = 'no_cuadra' and (to_jsonb(x)->>'solo_reparto')::boolean), 0) / 2
                     and (r->>'reparto_cuentas')::int = count(*) filter (where x.pendiente and x.estado = 'no_cuadra' and (to_jsonb(x)->>'solo_reparto')::boolean)
                     and (r->>'sin_respaldo')::numeric = coalesce(sum(abs(x.saldo_libro)) filter (where x.pendiente and x.estado = 'sin_auxiliar'), 0)
                     and (r->>'fecha')::date = v_f and (r->>'hoy')::date = v_f
                     and r->>'periodo' is not distinct from (select q.periodo from periodos q where q.tipo in ('mes', 'apertura') and q.hasta = v_f
                                                              order by q.desde limit 1)
                     and (select count(*) from jsonb_object_keys(r)) = 26
                then 'sí' else 'no: ' || r::text end
      into a from fn_cedula(v_f) x;
    -- cuenta por cuenta, a hoy y al día que toca (sin fecha)
    select case when count(*) = 0 then 'sí, en todas' else 'no: ' || string_agg(z.cuenta || ' (' || z.cual || ')', ', ') end into b
      from (select x.cuenta, w.cual
              from (values ('hoy', v_f), ('el día que toca', (select min(t.fecha) from fn_cedula(null) t))) w(cual, f)
              cross join lateral fn_cedula(w.f) x
              left join lateral (select coalesce(sum(i.monto) filter (where i.clase = 'auxiliar'), 0)
                                        -- (lo que sale del propio libro es el auxiliar mientras nadie haya escrito con qué compararlo)
                                        + case when to_jsonb(x)->>'sosten' = 'libro' then coalesce(sum(i.monto) filter (where i.clase = 'libro'), 0) else 0 end as aux,
                                        count(*) filter (where i.clase = 'auxiliar')
                                        + case when to_jsonb(x)->>'sosten' = 'libro' then count(*) filter (where i.clase = 'libro') else 0 end as n,
                                        sum(i.libro) filter (where i.clase = 'suelto') as sueltas,
                                        sum(i.libro) filter (where i.clase = 'despues') as despues,
                                        count(*) filter (where i.clase = 'auxiliar' and i.ok is false) as x,
                                        coalesce(sum(i.monto) filter (where i.clase = 'auxiliar' and i.fuente = 'manual'), 0) as manual
                                   from fn_cedula_partidas(w.f, x.cuenta) i) s on true
             where coalesce(x.saldo_auxiliar, 0) <> case when x.saldo_auxiliar is null then 0 else coalesce(s.aux, 0) end
                or x.renglones <> coalesce(s.n, 0) or x.sueltas is distinct from s.sueltas or x.despues is distinct from s.despues
                or x.descuadres <> coalesce(s.x, 0) or x.manual <> coalesce(s.manual, 0)
                or (x.saldo_auxiliar is not null and x.diferencia <> x.saldo_libro - x.saldo_auxiliar)
                or (x.saldo_auxiliar is null and (x.diferencia is not null or x.estado not in ('sin_auxiliar', 'explicada', 'con_codigo')))) z;
    select case when not exists (select i.n, i.clase, i.clave, i.concepto, i.monto, i.libro from fn_cedula_partidas(v_f, '1693') i
                                 except
                                 select i.n, i.clase, i.clave, i.concepto, i.monto, i.libro from fn_cedula_partidas(v_f, null) i where i.cuenta = '1693')
                     and (select count(*) from fn_cedula_partidas(v_f, '1693')) = (select count(*) from fn_cedula_partidas(v_f, null) i where i.cuenta = '1693')
                     and (select count(*) from fn_cedula_partidas(v_f, '1693')) = 1
                     and (select count(*) from fn_cedula_partidas(v_f, '9999-NO')) = 0
                then 'sí' else 'no' end into c;
    d := case when (select min(x.fecha) from fn_cedula(null) x)
                   = coalesce((select q.hasta from periodos q where q.periodo = fn_cedula_toca()), v_f)
                   and (select min(x.fecha) from fn_cedula(null) x) = (select max(x.fecha) from fn_cedula(null) x) then 'sí' else 'no' end;
    e := case when not exists (select v.cuenta, v.saldo_libro, v.saldo_auxiliar, v.diferencia, v.estado, v.pendiente, v.detalle, v.fecha,
                                      to_jsonb(v)->>'sosten', to_jsonb(v)->>'par', to_jsonb(v)->>'solo_reparto' from v_cedula v
                               except
                               select x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.detalle, x.fecha,
                                      to_jsonb(x)->>'sosten', to_jsonb(x)->>'par', to_jsonb(x)->>'solo_reparto' from fn_cedula(null) x)
                   and (select count(*) from v_cedula v where to_jsonb(v)->>'sosten' is not null) > 0
                   and (select count(*) from v_cedula) = (select count(*) from fn_cedula(null))
                   and not exists (select v.orden, v.control, v.nivel, v.ok, v.detalle from v_cedula_control v
                                   except select k.orden, k.control, k.nivel, k.ok, k.detalle from fn_cedula_control(null) k)
                   and (select count(*) from v_cedula_control) = 6
                   and (select count(*) from v_cedula_manual m where m.cuenta = '1693' and m.vigente and m.cuenta_nombre = 'C13 PRUEBA depósitos'
                                                                 and m.creado_por::text = pg_temp.c13('dueno')) = 1
                   and (select count(*) from v_cedula_explicaciones x where x.cuenta = '1693' and x.viva and x.estado = 'no_cuadra'
                                                                        and x.saldo_libro = 0 and x.saldo_auxiliar = 400 and x.diferencia = -400
                                                                        and x.explicado_por::text = pg_temp.c13('dueno')) = 1
              then 'sí' else 'no' end;
    -- EL DUEÑO, POR LA API, VE LO MISMO QUE EL SQL EDITOR: la cédula lee las tablas de las otras capas con los permisos de
    -- quien llama, y si una no se dejara leer esa cuenta saldría «sin auxiliar: no se pudo leer» sin romper nada. Aquí se
    -- comprueba que no pasa: las mismas filas, los mismos renglones (a hoy y al día que toca) y ninguno de «error».
    select md5(coalesce(string_agg(z::text, '|' order by z.fecha, z.cuenta), '')) into v_m0
      from (select x.fecha, x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.por_que, x.renglones, x.detalle
              from (select * from fn_cedula(v_f) union all select * from fn_cedula(null)) x) z;
    select md5(coalesce(string_agg(z::text, '|' order by z.cuenta, z.n), '')) into v_p0
      from (select i.cuenta, i.n, i.clase, i.clave, i.concepto, i.monto, i.libro, i.ok from fn_cedula_partidas(v_f, null) i) z;
    if v_perq is not null then
      select md5(coalesce(string_agg(z::text, '|' order by z.cuenta), '')) into v_q0
        from (select q.cuenta, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.sin_explicar_qb, q.qb_ok, q.amarra from fn_cedula_qb(v_perq) q) z;
    end if;
    perform pg_temp.c13_ser('dueno');
    select md5(coalesce(string_agg(z::text, '|' order by z.fecha, z.cuenta), '')) into v_m1
      from (select x.fecha, x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.por_que, x.renglones, x.detalle
              from (select * from fn_cedula(v_f) union all select * from fn_cedula(null)) x) z;
    select md5(coalesce(string_agg(z::text, '|' order by z.cuenta, z.n), '')) into v_p1
      from (select i.cuenta, i.n, i.clase, i.clave, i.concepto, i.monto, i.libro, i.ok from fn_cedula_partidas(v_f, null) i) z;
    if v_perq is not null then
      select md5(coalesce(string_agg(z::text, '|' order by z.cuenta), '')) into v_q1
        from (select q.cuenta, q.saldo_libro, q.saldo_qb, q.diferencia_qb, q.sin_explicar_qb, q.qb_ok, q.amarra from fn_cedula_qb(v_perq) q) z;
    end if;
    select (select count(*) from fn_cedula(v_f) x where x.por_que = 'error')
         + (select count(*) from fn_cedula_partidas(v_f, null) i where i.clase = 'error')
         + (select count(*) from fn_cedula_cuentas() k where k.vacio like 'no se pudo leer%') into v_err;
    perform pg_temp.c13_ser('editor');
    f := case when v_m0 = v_m1 and v_p0 = v_p1 and v_q0 = v_q1 and v_err = 0 then 'sí'
              else format('no: la cédula %s, los renglones %s, QuickBooks %s, y %s de «error»', case when v_m0 = v_m1 then 'igual' else 'DISTINTA' end,
                          case when v_p0 = v_p1 then 'iguales' else 'DISTINTOS' end, case when v_q0 = v_q1 then 'igual' else 'DISTINTO' end, v_err) end;
    v_obt := format('los totales son los de la cédula, sus 26 llaves: %s | el auxiliar de cada cuenta es la suma de sus renglones: %s | '
                    'los renglones de una cuenta son los mismos que al pedirlos todos: %s | sin fecha es el último día del período que toca: %s | '
                    'las vistas son sus funciones: %s | el dueño por la API ve lo mismo que el SQL Editor, y ninguna capa le sale ilegible: %s',
                    a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'LA PANTALLA NO SUMA: los totales (fn_cedula_resumen, sus 26 llaves) son los de la cédula contados otra vez, con lo que cuadra contra un papel, lo que cuadra por las partidas del libro y lo que sale del propio libro contados aparte, el resultado sin cerrar con que el balance cierra (activo = pasivo + patrimonio + resultado) y el reparto de los préstamos fuera de la diferencia pendiente; el auxiliar de cada cuenta es la suma de sus renglones (y lo suelto, lo de después y lo que no casa, lo de los suyos), cuenta por cuenta, a hoy y al día que toca, con lo de esta base y lo de la prueba; los renglones de una cuenta son los mismos pedidos sola o con todas; sin fecha, la cédula es la del último día del período que toca; cada vista es su función; y el dueño por la API ve exactamente lo que el SQL Editor (ninguna capa le sale ilegible por permisos)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. LA CONCILIACIÓN DE OTRO DÍA NO COMPRUEBA ESTE. El banco de prueba se
--     concilia y se confirma a mitad de mes (el día 15: 800 = 0 del statement
--     + 1,000 − 200) y el libro no vuelve a mover la cuenta. La cédula de ese
--     día cuadra. La del último día del mes NO: su conciliación es de otro
--     día, y que el libro no haya movido la cuenta no dice lo que hizo el
--     banco (una comisión, un cargo que nadie asentó). Lo dice, dice qué
--     hacer, y el aviso del control —y con él la fila del cierre— cuenta una
--     cuenta más. Con movimientos después que suman cero (entran 300, salen
--     300), lo mismo. Conciliada al último día, cuadra y el aviso vuelve.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_c jsonb; k20 int; a text; b text; c text; d text;
  v_esp text := 'conciliada el día 15, ese día: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | cuadra | '
                'el último día del mes, sin que el libro la haya movido: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | no_cuadra (pendiente); '
                'dice de qué día es su conciliación y por qué no cuadra: sí; qué hacer: sí; el aviso del control: +1 y rojo | '
                'con 300 que entran y 300 que salen después: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | no_cuadra (pendiente), '
                'después 0.00, y lo dice: sí | conciliada al último día: conciliacion | libro 800.00 | aux 800.00 | dif 0.00 | cuadra; el aviso: +0';
begin
  if pg_temp.c13_omitir(33, 'la conciliación de otro día', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito', '1093', '3193', 1000);
    perform pg_temp.c13_dh(pg_temp.c13_d(9), 'el cheque 9301', '6200', '1093', 200);
    k20 := pg_temp.c13_ctl_n(20);
    v_c := fn_conciliar('1093', pg_temp.c13_d(14), '0.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    a := pg_temp.c13_fila('1093', pg_temp.c13_d(14));
    b := format('%s; dice de qué día es su conciliación y por qué no cuadra: %s; qué hacer: %s; el aviso del control: %s y %s',
                pg_temp.c13_fila('1093', v_h),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '1093')
                          = format('$800.00 en el libro al %s. La última conciliación confirmada es la del %s: falta la de este día. Desde entonces el '
                                   'libro no ha movido la cuenta, pero eso no dice lo que hizo el banco. Por eso no cuadra aunque la resta dé cero.',
                                   fn_cedula_dia(v_h), fn_cedula_dia(pg_temp.c13_d(14)))
                      and (select x.auxiliar_al from fn_cedula(v_h) x where x.cuenta = '1093') = pg_temp.c13_d(14)
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = '1093'), 'nulo') end,
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1093')
                          like 'Concilia la cuenta hasta el ' || fn_cedula_dia(v_h) || ' en Conciliar y confirma%' then 'sí' else 'no' end,
                to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'), pg_temp.c13_ctl(20));
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'entran 300 que nadie ha conciliado', '1093', '3193', 300);
    perform pg_temp.c13_dh(pg_temp.c13_d(21), 'y salen 300', '3193', '1093', 300);
    c := format('%s, después %s, y lo dice: %s', pg_temp.c13_fila('1093', v_h),
                coalesce((select x.despues::text from fn_cedula(v_h) x where x.cuenta = '1093'), '-'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '1093')
                          like '%falta la de este día. Después de ella el libro movió $0.00 (2 línea(s)%), sin conciliar. Por eso no cuadra aunque la resta dé cero.'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = '1093'), 'nulo') end);
    v_c := fn_conciliar('1093', v_h, '0.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    d := format('%s; el aviso: %s', pg_temp.c13_fila('1093', v_h), to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'));
    v_obt := format('conciliada el día 15, ese día: %s | el último día del mes, sin que el libro la haya movido: %s | '
                    'con 300 que entran y 300 que salen después: %s | conciliada al último día: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'LA CONCILIACIÓN DE OTRO DÍA NO COMPRUEBA ESTE: un banco conciliado y confirmado a mitad de mes cuadra ese día; el último día del mes, aunque el libro no haya movido la cuenta y la resta dé cero, NO cuadra (su conciliación es de otro día: que el libro no se moviera no dice lo que hizo el banco), lo dice, dice qué hacer y el aviso del control cuenta una cuenta más; con movimientos posteriores que suman cero, lo mismo; conciliada al último día, cuadra y el aviso vuelve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. LO SUELTO QUE SE COMPENSA NO CUADRA. En las cuentas por cobrar, un
--     traspaso a mano entre dos obras sin factura (700 en una, −700 en la
--     otra): la cuenta no cambia, su auxiliar tampoco y la resta sigue igual,
--     pero cada obra tiene un saldo que no es de ninguna factura. La cédula
--     no dice «cuadra»: pide, y lo dice (como ya hacía con el WIP). Y una
--     explicación vale para lo suelto que había al escribirla: si después
--     aparece otro par que se compensa, se queda vieja aunque el saldo sea
--     el mismo. (Con los datos de esta base la cuenta puede no cuadrar ya
--     por otra cosa: entonces se mira que los dos renglones estén y que pida.)
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_cxc text; f0 jsonb; a text; b text; c text;
  v_esp text := 'un traspaso sin factura entre dos obras: libro +0.00 | aux +0.00 | dif +0.00; no cuadra y pide: sí; sus dos renglones sueltos: '
                'C13 PRUEBA Obra W 700.00 y C13 PRUEBA Obra X -700.00; lo dice: sí; el aviso del control la nombra: sí | '
                'explicada: explicada | con otro par que se compensa después: no_cuadra (pendiente), la explicación quedó vieja y dice por qué: sí';
begin
  if pg_temp.c13_omitir(34, 'lo suelto que se compensa', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    v_cxc := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc'), '1110');
    f0 := pg_temp.c13_foto(v_cxc, v_h);
    perform pg_temp.c13_dh(pg_temp.c13_d(12), 'un traspaso a mano entre dos obras, sin factura', v_cxc, v_cxc, 700, 'c13-prueba-w', 'c13-prueba-x');
    a := format('%s; no cuadra y pide: %s; sus dos renglones sueltos: %s y %s; lo dice: %s; el aviso del control la nombra: %s',
                regexp_replace(pg_temp.c13_cambio(f0, v_cxc, v_h), ' \| [a-z_]+$', ''),
                case when (select x.estado = 'no_cuadra' and x.pendiente from fn_cedula(v_h) x where x.cuenta = v_cxc) then 'sí'
                     else 'no: ' || pg_temp.c13_fila(v_cxc, v_h) end,
                coalesce((select i.grupo || ' ' || i.libro from fn_cedula_partidas(v_h, v_cxc) i where i.clase = 'suelto' and i.clave = 'suelto:c13-prueba-w'), 'no sale'),
                coalesce((select i.grupo || ' ' || i.libro from fn_cedula_partidas(v_h, v_cxc) i where i.clase = 'suelto' and i.clave = 'suelto:c13-prueba-x'), 'no sale'),
                case when f0->>'e' not in ('cuadra', 'no sale')
                       or (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxc)
                          like '%pero NO cuadra: la cuenta tiene 2 renglón(es) sin decir de qué factura son que se compensan entre sí (2 línea(s)). Cada uno está abajo, con su obra.'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxc), 'nulo') end,
                -- (CON LOS DATOS DE ESTA BASE la cuenta puede traer ya SU explicación de ese día —Edgar explica el saldo que venía
                -- de QuickBooks sin sus facturas—: el traspaso de prueba la deja vieja, y entonces quien la nombra no es el
                -- aviso 20 («nadie lo ha explicado») sino el 40 («la explicación se quedó vieja»). Vale cualquiera de los dos:
                -- lo que se mira es que un aviso del control la nombre. Antes solo se miraba el 20 y la prueba fallaba en falso
                -- en una base en uso.)
                case when (pg_temp.c13_ctl(20) = 'rojo' and pg_temp.c13_ctl_det(20) like '%' || v_cxc || '%')
                       or (pg_temp.c13_ctl(40) = 'rojo' and pg_temp.c13_ctl_det(40) like '%' || v_cxc || '%') then 'sí'
                     else 'no: ' || coalesce(pg_temp.c13_ctl_det(20), 'nulo') || ' / ' || coalesce(pg_temp.c13_ctl_det(40), 'nulo') end);
    perform pg_temp.c13_explicar(v_cxc, v_h, 'C13 PRUEBA: es el mismo cliente en dos obras; se cruza al facturar la segunda');
    b := (select x.estado from fn_cedula(v_h) x where x.cuenta = v_cxc);
    perform pg_temp.c13_dh(pg_temp.c13_d(13), 'otro traspaso a mano entre las dos obras, sin factura', v_cxc, v_cxc, 55, 'c13-prueba-x', 'c13-prueba-w');
    c := format('%s, la explicación quedó vieja y dice por qué: %s',
                (select x.estado || case when x.pendiente then ' (pendiente)' else '' end from fn_cedula(v_h) x where x.cuenta = v_cxc),
                case when (select x.explicacion_vieja from fn_cedula(v_h) x where x.cuenta = v_cxc)
                      and (select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxc)
                          like '%se escribió con otros renglones sueltos en la cuenta (sin decir de qué son); eso cambió después, aunque el saldo sea el mismo: vuelve a explicarla.'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = v_cxc), 'nulo') end);
    v_obt := format('un traspaso sin factura entre dos obras: %s | explicada: %s | con otro par que se compensa después: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'LO SUELTO QUE SE COMPENSA NO CUADRA: en las cuentas por cobrar, un traspaso a mano sin factura entre dos obras (700 y −700) no cambia la cuenta, ni su auxiliar, ni la resta, pero deja en cada obra un saldo que no es de ninguna factura: la cédula no dice «cuadra», pide, lo dice con sus dos renglones y el aviso del control la nombra; explicada, deja de pedir; y si después aparece otro par que se compensa, la explicación se queda vieja aunque el saldo sea el mismo, y dice por qué',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. UNA PÓLIZA, Y LO QUE SE CORRIGIÓ DESPUÉS. La cuenta de pólizas con una
--     póliza de 1,000 (con su papel) y un cargo de 100 que no es póliza: no
--     cuadra por 100. El mes siguiente se corrige. La cédula de HOY cuadra;
--     la de aquel día tiene que seguir diciendo que la cuenta tenía 100 de
--     más (antes, al «llevar el auxiliar a la fecha» con todo lo que el libro
--     movió después, la corrección entraba como un renglón del auxiliar y
--     aquel día pasaba a «cuadra» solo). La corrección sale aparte, a la
--     vista, y la fila dice qué hacer; explicada, deja de pedir.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_pol text; v_as uuid; a text; b text; c text; d text;
  v_esp text := 'con 100 de más que no son póliza: prepagados | libro 1100.00 | aux 1000.00 | dif 100.00 | no_cuadra (pendiente) | '
                'corregido el mes siguiente, la de aquel día: prepagados | libro 1100.00 | aux 1000.00 | dif 100.00 | no_cuadra (pendiente); la corrección '
                'sale aparte: despues: Lo que el libro movió en la cuenta después del … sin ser de una póliza registrada (ni su compra ni su '
                'amortización) = - (libro -100.00); lo dice: sí; qué hacer: sí | la de hoy: prepagados | libro 1000.00 | aux 1000.00 | dif 0.00 | cuadra | '
                'explicada: prepagados | libro 1100.00 | aux 1000.00 | dif 100.00 | explicada';
begin
  if pg_temp.c13_omitir(35, 'una póliza y lo que se corrigió después', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    v_as := pg_temp.c13_dh(v_h - 9, 'el pago de la póliza', '1493', '1093', 1000);
    v_pol := fn_prepagado_guardar(jsonb_build_object('descripcion', 'ZZ C13 PRUEBA póliza GL', 'tipo', 'seguro', 'cuenta', '1493',
               'cuenta_gasto', '6200', 'monto', '1000.00', 'desde', (v_h + 1)::text, 'hasta', (v_h + 365)::text,
               'papel_tabla', 'asientos', 'papel_id', v_as::text))->>'id';
    perform pg_temp.c13_dh(v_h - 3, 'un cargo que entra a la cuenta y no es una póliza', '1493', '1093', 100);
    a := pg_temp.c13_fila('1493', v_h);
    perform pg_temp.c13_dh(v_h + 2, 'la corrección: aquel cargo era un gasto', '6200', '1493', 100);
    b := format('%s; la corrección sale aparte: %s; lo dice: %s; qué hacer: %s', pg_temp.c13_fila('1493', v_h),
                regexp_replace(pg_temp.c13_renglon('1493', v_h, 'Lo que el libro movió en la cuenta después del%'),
                               'después del [0-9]+-[a-z]+-[0-9]+', 'después del …'),
                case when (select x.detalle from fn_cedula(v_h) x where x.cuenta = '1493')
                          like '%$100.00 de diferencia. Después de ese día el libro movió -$100.00 en esta cuenta sin ser de una póliza registrada (1 línea(s)): eso no se le quita al auxiliar, porque a esa fecha la cuenta lo tenía de más o de menos%'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from fn_cedula(v_h) x where x.cuenta = '1493'), 'nulo') end,
                case when (select x.que_hacer from fn_cedula(v_h) x where x.cuenta = '1493') like 'Mira la cédula de HOY: si hoy cuadra,%' then 'sí' else 'no' end);
    c := pg_temp.c13_fila('1493', pg_temp.c13('hoy')::date);
    perform pg_temp.c13_explicar('1493', v_h, 'C13 PRUEBA: un cargo de 100 que no era póliza; se pasó al gasto el mes siguiente');
    d := pg_temp.c13_fila('1493', v_h);
    v_obt := format('con 100 de más que no son póliza: %s | corregido el mes siguiente, la de aquel día: %s | la de hoy: %s | explicada: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'UNA PÓLIZA, Y LO QUE SE CORRIGIÓ DESPUÉS: con un cargo de 100 en la cuenta de pólizas que no es póliza, no cuadra por 100; corregido el mes siguiente, la cédula de hoy cuadra y la de AQUEL día sigue diciendo que la cuenta tenía 100 de más (a una fecha anterior el auxiliar de hoy se lleva quitando solo lo que es de una póliza; lo demás que el libro movió después —la corrección— sale aparte y no se le quita), lo dice, dice qué hacer, y explicada deja de pedir',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. EL BALANCE CIERRA A LA VISTA, Y LO QUE SALE DEL LIBRO NO SE CUENTA COMO
--     CUADRADO. Los totales traen el RESULTADO que todavía no está en el
--     patrimonio (ingresos menos costos y gastos hasta ese día): con él,
--     activo = pasivo + patrimonio + resultado, siempre. Un aporte de 1,000
--     y un gasto de 300 pagado del banco: el activo sube 700, el patrimonio
--     1,000 y el resultado baja 300. Y la cuenta de patrimonio nueva, que
--     sale de su propio mayor, se cuenta aparte («del libro»), no entre las
--     que cuadran.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); r0 jsonb; r1 jsonb;
  v_esp text := 'antes: activo = pasivo + patrimonio + resultado: sí | con un aporte de 1,000 y un gasto de 300: activo +700.00, pasivo +0.00, '
                'patrimonio +1000.00, resultado -300.00, patrimonio con el resultado +700.00; cierra: sí | la cuenta de patrimonio nueva: '
                'cuadran +0, del libro +1';
begin
  if pg_temp.c13_omitir(36, 'el balance cierra a la vista', v_esp) then return; end if;
  begin
    -- (los totales de antes se toman SIN las cuentas de prueba —la de patrimonio es la «nueva»— y, como en todas las
    -- pruebas, con el patrimonio sostenido por su mayor, diga lo que diga la configuración de esta base, y «sin la nómina»,
    -- como las deja sembrar: si no, las cuentas de la nómina cambiarían de estado entre el antes y el después)
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_reloj();
    perform pg_temp.c13_sin_nomina();
    perform pg_temp.c13_config('{"patrimonio": "mayor"}');
    perform pg_temp.c13_ser('dueno');
    r0 := fn_cedula_resumen(v_h);
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_dh(pg_temp.c13_d(3), 'un aporte', '1093', '3193', 1000);
    perform pg_temp.c13_dh(pg_temp.c13_d(8), 'un gasto pagado del banco', '6200', '1093', 300);
    perform pg_temp.c13_ser('dueno');
    r1 := fn_cedula_resumen(v_h);
    perform pg_temp.c13_ser('editor');
    v_obt := format('antes: activo = pasivo + patrimonio + resultado: %s | con un aporte de 1,000 y un gasto de 300: activo %s, pasivo %s, '
                    'patrimonio %s, resultado %s, patrimonio con el resultado %s; cierra: %s | la cuenta de patrimonio nueva: cuadran %s, del libro %s',
                    case when (r0->>'activo')::numeric = (r0->>'pasivo')::numeric + (r0->>'capital')::numeric + (r0->>'resultado')::numeric
                          and (r0->>'balance_cuadra')::boolean then 'sí'
                         else 'no: ' || coalesce(r0->>'activo', '-') || ' ≠ ' || coalesce(r0->>'pasivo', '-') || ' + ' || coalesce(r0->>'capital', '-')
                              || ' + ' || coalesce(r0->>'resultado', '(los totales no traen el resultado)') end,
                    to_char((r1->>'activo')::numeric - (r0->>'activo')::numeric, 'FMS999999990.00'),
                    to_char((r1->>'pasivo')::numeric - (r0->>'pasivo')::numeric, 'FMS999999990.00'),
                    to_char((r1->>'capital')::numeric - (r0->>'capital')::numeric, 'FMS999999990.00'),
                    coalesce(to_char((r1->>'resultado')::numeric - (r0->>'resultado')::numeric, 'FMS999999990.00'), 'no lo traen'),
                    coalesce(to_char((r1->>'patrimonio_total')::numeric - (r0->>'patrimonio_total')::numeric, 'FMS999999990.00'), 'no lo traen'),
                    case when (r1->>'activo')::numeric = (r1->>'pasivo')::numeric + (r1->>'capital')::numeric + (r1->>'resultado')::numeric
                          and (r1->>'balance_cuadra')::boolean then 'sí' else 'no' end,
                    to_char((r1->>'cuadran')::int - (r0->>'cuadran')::int, 'FMS990'),
                    coalesce(to_char((r1->>'del_libro')::int - (r0->>'del_libro')::int, 'FMS990'), 'no lo traen'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'EL BALANCE CIERRA A LA VISTA: los totales de la cédula traen el resultado que todavía no está en el patrimonio (ingresos menos costos y gastos hasta ese día) y con él activo = pasivo + patrimonio + resultado, antes y después de un aporte de 1,000 y un gasto de 300 (activo +700, patrimonio +1,000, resultado −300); y la cuenta de patrimonio nueva, que sale de su propio mayor, se cuenta aparte («del libro») y no entre las que cuadran',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. LA CAJA NO ES UN BANCO QUE EL BANCO TRAE. La caja chica es la cuenta de
--     la forma de pago «efectivo» de los recibos (c3). Si alguien apunta esa
--     forma a una cuenta que el banco trae (aquí, el banco de prueba, con su
--     conciliación confirmada), esa cuenta SIGUE siendo un banco en la
--     cédula —con su conciliación— y lo avisa; y la caja sigue siendo la
--     caja chica de siempre (1050). (Antes el banco pasaba a ser «el arqueo
--     de caja, a mano» y la 1050 un banco por conciliar.)
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_c jsonb; a text; b text; c text; d text;
  v_esp text := 'el banco de prueba, conciliado: conciliacion, «El estado de cuenta, conciliado», cuadra | con «efectivo» apuntando a esa cuenta: '
                'conciliacion, «El estado de cuenta, conciliado», cuadra, y lo avisa: sí | la caja chica (1050): manual, «El arqueo de caja» | '
                'y Conciliar, mientras siga así, no la deja conciliar: MX004';
begin
  if pg_temp.c13_omitir(37, 'la caja y el banco', v_esp, array['mes', 'cuentas', 'c6']) then return; end if;
  if not exists (select 1 from cuentas k where k.codigo = '1050' and k.imputable and k.tipo = 'activo') then
    insert into _pruebas values (37, 'la caja y el banco', v_esp, 'omitida: esta base no tiene la caja chica del plan (1050)', null);
    return;
  end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_dh(pg_temp.c13_d(2), 'un depósito', '1093', '3193', 1000);
    v_c := fn_conciliar('1093', v_h, '0.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    a := (select format('%s, «%s», %s', x.fuente, x.auxiliar, x.estado) from fn_cedula(v_h) x where x.cuenta = '1093');
    perform pg_temp.c13_ser('dueno');
    perform fn_mapeo_metodo_pago('c13 prueba efectivo', 'efectivo', '1093');
    perform pg_temp.c13_ser('editor');
    b := format('%s, y lo avisa: %s', (select format('%s, «%s», %s', x.fuente, x.auxiliar, x.estado) from fn_cedula(v_h) x where x.cuenta = '1093'),
                case when (select x.origen from fn_cedula(v_h) x where x.cuenta = '1093')
                          like '%OJO: la forma de pago «efectivo» de los recibos apunta a esta cuenta, y el banco la trae: aquí sigue siendo un banco, pero Conciliar la toma por la caja chica%'
                     then 'sí' else 'no' end);
    c := coalesce((select format('%s, «%s»', k.fuente, k.auxiliar) from fn_cedula_cuentas() k where k.cuenta = '1050'), 'no sale');
    d := pg_temp.c13_estado(format('select public.fn_conciliar(%L, %L, %L)', '1093', v_h + 5, '0.00'), 'editor');
    v_obt := format('el banco de prueba, conciliado: %s | con «efectivo» apuntando a esa cuenta: %s | la caja chica (1050): %s | '
                    'y Conciliar, mientras siga así, no la deja conciliar: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'LA CAJA NO ES UN BANCO QUE EL BANCO TRAE: si la forma de pago «efectivo» de los recibos (c3) se apunta a una cuenta que el banco trae (con su conciliación confirmada), en la cédula esa cuenta sigue siendo un banco, con su conciliación, y la fila lo avisa (Conciliar la toma por la caja chica y no la deja conciliar mientras siga así: MX004); la caja sigue siendo la caja chica de siempre (1050), a mano',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LA CÉDULA CON EL AUXILIAR DE LA NÓMINA (13-nov-2026, Fase 11b): las
-- pruebas 42 a 47. Corren aquí, antes que el cierre de la suite (38 a 41),
-- para que «nada queda» las cubra. De la 42 a la 45, con una nómina
-- FINGIDA (c13_con_nomina): dan lo mismo sin c15, con c15 y con nóminas de
-- verdad en la base. La 46 y la 47, con la lectura de verdad.
-- =====================================================================

-- 42. UNA CUENTA DE LA NÓMINA CONTRA LO QUE CADA NÓMINA DEJÓ POR PAGAR, al
--     centavo (la cuenta de prueba 2293). La nómina de prueba: su journal el
--     día 20 deja 1,000 por pagar; Gusto cobra 600 el día 16 (ANTES del día
--     de pago) y 250 el día 23. Sin ninguna nómina en el libro la cuenta
--     cuadra en cero. Entre el cargo y el día de pago la cuenta está al
--     revés (−600) y CUADRA: es lo adelantado a Gusto, y lo dice. El día de
--     pago quedan 400; al final, 150. Algo que entra por otro lado (77.77)
--     es la diferencia: lo dice, con lo que la nómina sí explica y dónde
--     mirarlo; con su renglón a mano, cuadra. Y una corrección que devuelve
--     (82.35 a favor) entra con su signo.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); k1 uuid; k2 uuid; n1 text; v_c text := 'un cargo del día 16 por $600.00';
  a text; b0 text; b text; c text; d text; e text; f text; g text; h text; v_txt text[] := '{}';
  v_esp text := 'sin ninguna nómina en el libro: nomina | libro 0.00 | aux 0.00 | dif 0.00 | cuadra, con un papel, «Sin saldo al …, y nada abierto en lo '
                'que cada nómina dejó por pagar.» | antes del primer cargo: nomina | libro 0.00 | aux 0.00 | dif 0.00 | cuadra | '
                'entre el cargo de Gusto y el día de pago: nomina | libro -600.00 | aux -600.00 | dif 0.00 | cuadra, con un papel; su renglón: '
                'auxiliar: C13 PRUEBA Nómina del … = -600.00; dice que es lo adelantado a Gusto: sí | '
                'el día de pago: nomina | libro 400.00 | aux 400.00 | dif 0.00 | cuadra; dice qué dejó su journal y qué pagaron sus cargos: sí | '
                'pagado otro cargo, el último día: nomina | libro 150.00 | aux 150.00 | dif 0.00 | cuadra | '
                'algo que entra por otro lado: nomina | libro 72.23 | aux 150.00 | dif -77.77 | no_cuadra (pendiente); suelto -77.77; lo dice, con '
                'lo que la nómina sí explica y dónde mirarlo: sí | con su renglón a mano: nomina | libro 72.23 | aux 72.23 | dif 0.00 | cuadra | '
                'una corrección que deja algo a favor: nomina | libro -10.12 | aux -10.12 | dif 0.00 | cuadra; lo dice: sí | '
                'textos que nombran funciones: ninguno';
begin
  if pg_temp.c13_omitir(42, 'la nómina con su auxiliar', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_con_nomina();
    a := format('%s, %s, «%s»', pg_temp.c13_fila('2293', v_h),
                case pg_temp.c13_col('2293', v_h, 'sosten') when 'papel' then 'con un papel' else pg_temp.c13_col('2293', v_h, 'sosten') end,
                regexp_replace(pg_temp.c13_col('2293', v_h, 'detalle'), ' al [0-9]+-[a-z]+-[0-9]+', ' al …'));
    -- la nómina de prueba: su journal (el día 20) y sus dos cargos (el 16 y el 23), y lo que la nómina dice cada día
    k1 := pg_temp.c13_journal(pg_temp.c13_d(19), 'el journal de una nómina', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '1000.00'), jsonb_build_object('cuenta', '2293', 'monto', '-1000.00')));
    select x.numero into n1 from asientos x where x.id = k1;
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'el cargo de Gusto, antes del día de pago', '2293', '1093', 600);
    perform pg_temp.c13_dh(pg_temp.c13_d(22), 'otro cargo de Gusto', '2293', '1093', 250);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(15), pg_temp.c13_d(18), '2293', k1, pg_temp.c13_d(19), 0, 600, v_c);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), pg_temp.c13_d(21), '2293', k1, pg_temp.c13_d(19), 1000, 600, v_c);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(22), null, '2293', k1, pg_temp.c13_d(19), 1000, 850, v_c || '; otro del día 23 por $250.00');
    b0 := pg_temp.c13_fila('2293', pg_temp.c13_d(14));
    b := format('%s, %s; su renglón: %s; dice que es lo adelantado a Gusto: %s', pg_temp.c13_fila('2293', pg_temp.c13_d(16)),
                case pg_temp.c13_col('2293', pg_temp.c13_d(16), 'sosten') when 'papel' then 'con un papel' else pg_temp.c13_col('2293', pg_temp.c13_d(16), 'sosten') end,
                regexp_replace(pg_temp.c13_renglon('2293', pg_temp.c13_d(16), 'C13 PRUEBA Nómina%'), ' del [0-9]+-[a-z]+-[0-9]+', ' del …'),
                case when pg_temp.c13_col('2293', pg_temp.c13_d(16), 'detalle')
                          like '%ya se pagaron $600.00 (' || v_c || ') y su journal todavía no está en el libro ese día (Gusto cobra antes del día de pago): '
                               'hasta que entre, es lo adelantado a Gusto.%'
                     then 'sí' else 'no: ' || pg_temp.c13_col('2293', pg_temp.c13_d(16), 'detalle') end);
    c := format('%s; dice qué dejó su journal y qué pagaron sus cargos: %s', pg_temp.c13_fila('2293', pg_temp.c13_d(19)),
                case when pg_temp.c13_col('2293', pg_temp.c13_d(19), 'detalle')
                          like '%quedan $400.00 por pagar: su journal (' || n1 || ') dejó $1,000.00 y sus cargos casados ya pagaron $600.00 (' || v_c || ').%'
                     then 'sí' else 'no: ' || pg_temp.c13_col('2293', pg_temp.c13_d(19), 'detalle') end);
    d := pg_temp.c13_fila('2293', v_h);
    select v_txt || array_agg(format('%s · %s · %s · %s', x.auxiliar, x.origen, x.detalle, coalesce(x.que_hacer, ''))) into v_txt
      from (select * from fn_cedula(pg_temp.c13_d(16)) union all select * from fn_cedula(pg_temp.c13_d(19)) union all select * from fn_cedula(v_h)) x
     where x.cuenta = '2293';
    -- algo que entra a la cuenta por otro lado: un pago a mano que no pasó por la nómina
    perform pg_temp.c13_dh(pg_temp.c13_d(24), 'un pago a mano que no pasó por la nómina', '2293', '1093', 77.77);
    e := format('%s; suelto %s; lo dice, con lo que la nómina sí explica y dónde mirarlo: %s', pg_temp.c13_fila('2293', v_h),
                pg_temp.c13_col('2293', v_h, 'sueltas'),
                case when pg_temp.c13_col('2293', v_h, 'detalle')
                          like '%-$77.77 están en el libro sin ser lo que una nómina dejó por pagar ni un cargo casado con ella: entraron por otro lado.%'
                               'Lo que la nómina sí explica: de la nómina del % quedan $150.00 por pagar%'
                          and pg_temp.c13_col('2293', v_h, 'que_hacer') like 'Lo que entró por otro lado lo dice, asiento por asiento, el control de la nómina%Nómina → Cargos de Gusto%'
                          and (select count(*) from fn_cedula_partidas(v_h, '2293') i where i.clase = 'suelto' and i.libro = -77.77 and i.monto is null) = 1
                     then 'sí' else 'no: ' || pg_temp.c13_col('2293', v_h, 'detalle') || ' / ' || pg_temp.c13_col('2293', v_h, 'que_hacer') end);
    select v_txt || array_agg(format('%s · %s', x.detalle, coalesce(x.que_hacer, ''))) into v_txt from fn_cedula(v_h) x where x.cuenta = '2293';
    select v_txt || array_agg(format('%s · %s', case when i.clase = 'suelto' then i.concepto else '' end, coalesce(i.nota, ''))) into v_txt
      from (select * from fn_cedula_partidas(pg_temp.c13_d(16), '2293') union all select * from fn_cedula_partidas(v_h, '2293')) i;
    select v_txt || array_agg(format('%s · %s · %s', k.auxiliar, k.origen, coalesce(k.vacio, ''))) into v_txt from fn_cedula_cuentas() k where k.nomina is not null;
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2293', 'concepto', 'C13 PRUEBA: una deducción que se pagó a mano', 'monto', '-77.77',
              'desde', pg_temp.c13_d(24)::text, 'documento', 'C13 PRUEBA recibo'));
    f := pg_temp.c13_fila('2293', v_h);
    -- una corrección que devuelve: su journal (el día 26) deja 82.35 A FAVOR
    k2 := pg_temp.c13_journal(pg_temp.c13_d(25), 'el journal de una corrección que devuelve', jsonb_build_array(
            jsonb_build_object('cuenta', '2293', 'monto', '82.35'), jsonb_build_object('cuenta', '6200', 'monto', '-82.35')));
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(25), null, '2293', k2, pg_temp.c13_d(25), -82.35, 0);
    g := format('%s; lo dice: %s', pg_temp.c13_fila('2293', v_h),
                case when pg_temp.c13_col('2293', v_h, 'detalle') like '% tiene $82.35 a favor: su journal (%) dejó -$82.35 y sus cargos casados movieron $0.00. '
                                                                       'Lo descuenta Gusto de un cargo o lo devuelve.%'
                     then 'sí' else 'no: ' || pg_temp.c13_col('2293', v_h, 'detalle') end);
    select v_txt || array_agg(x.detalle) into v_txt from fn_cedula(v_h) x where x.cuenta = '2293';
    h := pg_temp.c13_llano(v_txt);
    v_obt := format('sin ninguna nómina en el libro: %s | antes del primer cargo: %s | entre el cargo de Gusto y el día de pago: %s | el día de pago: %s | '
                    'pagado otro cargo, el último día: %s | algo que entra por otro lado: %s | con su renglón a mano: %s | '
                    'una corrección que deja algo a favor: %s | textos que nombran funciones: %s', a, b0, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'UNA CUENTA DE LA NÓMINA CONTRA LO QUE CADA NÓMINA DEJÓ POR PAGAR (una nómina fingida: su journal de 1,000 el día 20 y sus cargos de 600 el día 16 y de 250 el día 23): sin ninguna nómina en el libro cuadra en cero; ENTRE EL CARGO DE GUSTO Y EL DÍA DE PAGO la cuenta está al revés (−600) y cuadra con un papel, diciendo que es lo adelantado a Gusto; el día de pago quedan 400 (dice qué dejó su journal y qué pagaron sus cargos) y al final 150; algo que entra por otro lado (77.77) es la diferencia, al centavo, y la fila lo dice con lo que la nómina sí explica y dónde mirarlo; con su renglón a mano cuadra; y una corrección que devuelve (82.35 a favor) entra con su signo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. LOS SUELDOS ACUMULADOS (la cuenta del puente de c3: 2210): EL DEVENGO
--     DE LAS HORAS MÁS LO DE LA NÓMINA, Y NADA DOS VECES. Por lo que la
--     prueba mueve (la cuenta es la de verdad): Gusto cobra 200 del neto el
--     día 16, antes del día de pago (−200, y cuadra); el último día hay un
--     devengo vivo de 300 y la nómina debe 300 de su journal de 500 (+600:
--     sus dos renglones, cada uno una vez); el día 1 el devengo se deshace
--     solo y queda lo de la nómina (+300). Un journal de nómina MARCADO como
--     los devengos (reversible) cuenta como nómina y NO como devengo (+40,
--     no +80). Lo que no es ni lo uno ni lo otro (80) va suelto; con su
--     renglón a mano, cuadra.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_sd text; k1 uuid; k2 uuid; f0 jsonb; g0 jsonb; h0 jsonb; a text; b text; c text; d text; e text; f text;
  v_c text := 'un cargo del día 16 por $200.00';
  v_esp text := 'entre el cargo de Gusto y el día de pago: libro -200.00 | aux -200.00 | dif +0.00 | cuadra | '
                'el último día, el devengo vivo y lo de la nómina: libro +600.00 | aux +600.00 | dif +0.00 | cuadra; sus renglones: el devengo 300.00 y '
                'la nómina 300.00; por sus partidas, y dice las dos cosas: sí | el día 1, deshecho el devengo: libro +300.00 | aux +300.00 | dif +0.00 | cuadra | '
                'un journal de nómina marcado como los devengos: libro +640.00 | aux +640.00 | dif +0.00 | cuadra; cuenta como nómina y no como devengo: sí | '
                'lo que no es ni lo uno ni lo otro: libro +720.00 | aux +640.00 | dif +80.00 | no_cuadra; suelto +80.00; lo dice: sí | '
                'con su renglón a mano: libro +720.00 | aux +720.00 | dif +0.00 | cuadra';
begin
  if pg_temp.c13_omitir(43, 'los sueldos acumulados: el devengo más la nómina', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_con_nomina();
    v_sd := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'sueldos_devengados'), '2210');
    h0 := pg_temp.c13_foto(v_sd, pg_temp.c13_d(16)); f0 := pg_temp.c13_foto(v_sd, v_h); g0 := pg_temp.c13_foto(v_sd, v_h + 1);
    -- la nómina de prueba: su journal (el día 20) deja 500 de neto por pagar; Gusto cobra 200 el día 16
    k1 := pg_temp.c13_journal(pg_temp.c13_d(19), 'el journal de una nómina', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '500.00'), jsonb_build_object('cuenta', v_sd, 'monto', '-500.00')));
    perform pg_temp.c13_dh(pg_temp.c13_d(15), 'el cargo de Gusto del neto, antes del día de pago', v_sd, '1093', 200);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(15), pg_temp.c13_d(18), v_sd, k1, pg_temp.c13_d(19), 0, 200, v_c);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), null, v_sd, k1, pg_temp.c13_d(19), 500, 200, v_c);
    a := pg_temp.c13_cambio(h0, v_sd, pg_temp.c13_d(16));
    -- el devengo de las horas del último día (se deshace solo el día 1)
    perform pg_temp.c13_asiento(v_h, 'el devengo de las horas aprobadas', jsonb_build_array(
              jsonb_build_object('cuenta', '6200', 'monto', '300.00'), jsonb_build_object('cuenta', v_sd, 'monto', '-300.00')), true);
    b := format('%s; sus renglones: el devengo %s y la nómina %s; por sus partidas, y dice las dos cosas: %s', pg_temp.c13_cambio(f0, v_sd, v_h),
                coalesce((select string_agg(i.monto::text, '+') from fn_cedula_partidas(v_h, v_sd) i
                           where i.clase = 'auxiliar' and i.fuente = 'devengos' and i.concepto like 'C13 PRUEBA: el devengo de las horas%'), 'no sale'),
                coalesce((select string_agg(i.monto::text, '+') from fn_cedula_partidas(v_h, v_sd) i
                           where i.clase = 'auxiliar' and i.fuente = 'nomina' and i.ref_id = k1::text), 'no sale'),
                case when pg_temp.c13_col(v_sd, v_h, 'sosten') = 'partidas'
                          and pg_temp.c13_col(v_sd, v_h, 'detalle') ilike '%de la nómina del % quedan $300.00 por pagar: su journal (%) dejó $500.00 y sus cargos casados ya pagaron $200.00%'
                          and (pg_temp.c13_col(v_sd, v_h, 'estado') <> 'cuadra'
                               or pg_temp.c13_col(v_sd, v_h, 'detalle') like '%Lo del devengo sale del propio libro (su asiento, que se deshace solo el día 1); lo de la '
                                                                             'nómina, de su journal y de sus cargos casados.%')
                     then 'sí' else 'no: ' || pg_temp.c13_col(v_sd, v_h, 'sosten') || ' / ' || pg_temp.c13_col(v_sd, v_h, 'detalle') end);
    c := pg_temp.c13_cambio(g0, v_sd, v_h + 1);
    -- un journal de nómina MARCADO como los devengos (40, el último día): la nómina lo trae; como devengo no cuenta
    k2 := pg_temp.c13_journal(v_h, 'un journal de nómina marcado como los devengos', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '40.00'), jsonb_build_object('cuenta', v_sd, 'monto', '-40.00')), true);
    perform pg_temp.c13_nomina_dice(v_h, v_h, v_sd, k2, v_h, 40, 0);
    d := format('%s; cuenta como nómina y no como devengo: %s', pg_temp.c13_cambio(f0, v_sd, v_h),
                case when (select count(*) from fn_cedula_partidas(v_h, v_sd) i where i.fuente = 'devengos' and i.ref_id = k2::text) = 0
                          and (select count(*) from fn_cedula_partidas(v_h, v_sd) i where i.fuente = 'nomina' and i.ref_id = k2::text and i.monto = 40) = 1
                     then 'sí' else 'no' end);
    -- lo que no es ni un devengo ni de una nómina
    perform pg_temp.c13_dh(pg_temp.c13_d(20), 'una provisión a mano en los sueldos acumulados', '6200', v_sd, 80);
    e := format('%s; suelto %s; lo dice: %s', pg_temp.c13_cambio(f0, v_sd, v_h),
                to_char((pg_temp.c13_foto(v_sd, v_h)->>'s')::numeric - (f0->>'s')::numeric, 'FMS999999990.00'),
                case when pg_temp.c13_col(v_sd, v_h, 'detalle') like '% no son un devengo de los que se deshacen solos, ni lo que una nómina dejó por pagar, ni un '
                                                                    'cargo casado con ella: entraron por otro lado.%'
                          and (select count(*) from fn_cedula_partidas(v_h, v_sd) i where i.clase = 'suelto' and i.fuente = 'devengos') = 1
                     then 'sí' else 'no: ' || pg_temp.c13_col(v_sd, v_h, 'detalle') end);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', v_sd, 'concepto', 'C13 PRUEBA: unas vacaciones devengadas a mano', 'monto', '80.00',
              'desde', pg_temp.c13_d(20)::text, 'documento', 'C13 PRUEBA cálculo de vacaciones'));
    f := pg_temp.c13_cambio(f0, v_sd, v_h);
    v_obt := format('entre el cargo de Gusto y el día de pago: %s | el último día, el devengo vivo y lo de la nómina: %s | el día 1, deshecho el devengo: %s | '
                    'un journal de nómina marcado como los devengos: %s | lo que no es ni lo uno ni lo otro: %s | con su renglón a mano: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'LOS SUELDOS ACUMULADOS (la cuenta del puente de c3), EL DEVENGO DE LAS HORAS MÁS LO DE LA NÓMINA, Y NADA DOS VECES (por lo que la prueba mueve): entre el cargo de Gusto y el día de pago la cuenta baja 200 y cuadra; el último día el devengo vivo (300) y lo que la nómina dejó por pagar (300 de 500) suman 600, cada uno en su renglón y una sola vez, y la fila dice de dónde sale cada cosa; el día 1 el devengo se deshace solo y queda lo de la nómina; un journal de nómina marcado como los devengos cuenta como nómina y no como devengo (+40, no +80); lo que no es ni lo uno ni lo otro (80) va suelto y es la diferencia; con su renglón a mano, cuadra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 44. SIN EL CÓDIGO DEL TELÉFONO. La nómina no enseña lo de nadie sin él, y
--     la cédula no abre esa puerta ni da un rojo falso: con una nómina en el
--     libro, sus cuentas salen «con_codigo» (ni «no cuadra» ni «sin
--     auxiliar»), sin compararse, sin un renglón ni una cifra de ninguna
--     nómina; y piden entrar con el código TENGAN SALDO O NO (en cero en el
--     libro, una puede tener algo abierto en su nómina: darla por buena sin
--     verlo sería un verde falso). Los totales las cuentan aparte y entre
--     las pendientes; el control (el 20 y el 30) y la fila del cierre no se
--     ponen en rojo por eso, y el 20 las nombra todas; no se explica
--     (MX008). Con el código, la misma cuenta cuadra. Y sin ninguna nómina
--     en el libro no hay nada que tapar: sale lo mismo con el código que
--     sin él.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); v_sd text; k1 uuid; k20 int; k30 int; v_ok0 boolean; r jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text; v_txt text[] := '{}';
  v_esp text := 'sin ninguna nómina en el libro, sin el código: nomina | libro 0.00 | aux 0.00 | dif 0.00 | cuadra | '
                'con su nómina, sin el código: nomina | libro 1000.00 | aux - | dif - | con_codigo (pendiente), codigo; no la compara y dice cómo verla: sí; '
                'los sueldos acumulados: con_codigo | ni un renglón de la nómina (0), y al pedir la cuenta, un dato que lo dice: sí | '
                'los totales las cuentan aparte y entre las pendientes, y no está lista: sí | el 20: +0 y el 30: +0, y el 20 las nombra todas: sí | '
                'la fila del cierre: como antes, y lo dice: sí | '
                'explicarla: MX008 | una sin saldo: nomina | libro 0.00 | aux - | dif - | con_codigo (pendiente), y también dice cómo verla: sí | '
                'con el código: nomina | libro 1000.00 | aux 1000.00 | dif 0.00 | cuadra | textos que nombran funciones: ninguno';
begin
  if pg_temp.c13_omitir(44, 'sin el código del teléfono', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_con_nomina();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    v_sd := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'sueldos_devengados'), '2210');
    -- sin ninguna nómina de prueba en el libro: sin el código sale lo mismo
    perform pg_temp.c13_ser('dueno_aal1');
    a := pg_temp.c13_fila('2293', v_h);
    perform pg_temp.c13_ser('editor');
    -- una nómina en el libro que no toca estas cuentas (desde aquí, sin el código, la nómina se tapa): cómo está el control
    perform pg_temp.c13_journal(pg_temp.c13_d(1), 'el journal de otra nómina, que no toca estas cuentas', jsonb_build_array(
              jsonb_build_object('cuenta', '6200', 'monto', '1.00'), jsonb_build_object('cuenta', '3193', 'monto', '-1.00')));
    perform pg_temp.c13_ser('dueno_aal1');
    k20 := pg_temp.c13_ctl_n(20); k30 := pg_temp.c13_ctl_n(30);
    select k.ok into v_ok0 from fn_cedula_cierre(v_per) k;
    perform pg_temp.c13_ser('editor');
    -- la nómina de prueba: su journal (el día 20) deja 1,000 en la 2293 y 500 en los sueldos acumulados
    k1 := pg_temp.c13_journal(pg_temp.c13_d(19), 'el journal de una nómina', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '1500.00'), jsonb_build_object('cuenta', '2293', 'monto', '-1000.00'),
            jsonb_build_object('cuenta', v_sd, 'monto', '-500.00')));
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), null, '2293', k1, pg_temp.c13_d(19), 1000, 0);
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), null, v_sd, k1, pg_temp.c13_d(19), 500, 0);
    perform pg_temp.c13_ser('dueno_aal1');
    b := format('%s, %s; no la compara y dice cómo verla: %s; los sueldos acumulados: %s', pg_temp.c13_fila('2293', v_h), pg_temp.c13_col('2293', v_h, 'por_que'),
                (select case when x.saldo_auxiliar is null and x.diferencia is null and x.sosten is null and x.auxiliar_al is null
                                  and x.detalle like '$1,000.00 en el libro al %solo se ve con el código del teléfono: esta sesión entró sin él%No es que no cuadre: falta mirarla con el código.'
                                  and x.que_hacer like 'Entra con el código del teléfono y vuelve a mirar%' and x.explicacion is null
                             then 'sí' else 'no: ' || x.detalle || ' / ' || coalesce(x.que_hacer, 'nulo') end
                   from fn_cedula(v_h) x where x.cuenta = '2293'),
                pg_temp.c13_col(v_sd, v_h, 'estado'));
    c := format('ni un renglón de la nómina (%s), y al pedir la cuenta, un dato que lo dice: %s',
                (select count(*) from fn_cedula_partidas(v_h, null) p where p.fuente = 'nomina'),
                case when (select count(*) from fn_cedula_partidas(v_h, '2293') p
                            where p.clase = 'dato' and p.clave = 'codigo' and p.monto is null and p.libro is null
                              and p.concepto = 'Lo que cada nómina dejó por pagar en esta cuenta se ve con el código del teléfono') = 1
                          and (select count(*) from fn_cedula_partidas(v_h, '2293') p where p.clase <> 'dato') = 0
                          and not (fn_cedula_nomina(v_h) ? 'filas')
                     then 'sí' else 'no' end);
    r := fn_cedula_resumen(v_h);
    d := case when (r->>'con_codigo')::int >= 2 and (r->>'con_codigo')::int = (select count(*) from fn_cedula(v_h) x where x.estado = 'con_codigo')
                   and (r->>'con_codigo')::int = (select count(*) from fn_cedula_cuentas() k where k.nomina = 'codigo')
                   and (select count(*) from fn_cedula(v_h) x where x.estado = 'con_codigo' and not x.pendiente) = 0
                   and (r->>'pendientes')::int = (select count(*) from fn_cedula(v_h) x where x.pendiente)
                   and (r->>'pendientes')::int >= (r->>'con_codigo')::int and not (r->>'listo')::boolean
                   and (r->>'no_cuadran')::int = (select count(*) from fn_cedula(v_h) x where x.estado = 'no_cuadra')
                   and (r->>'sin_auxiliar')::int = (select count(*) from fn_cedula(v_h) x where x.estado = 'sin_auxiliar' and x.saldo_libro <> 0)
              then 'sí' else 'no: ' || r::text end;
    -- (el 20 las nombra TODAS, con saldo o sin él: las que esta sesión no pudo comparar)
    e := format('el 20: %s y el 30: %s, y el 20 las nombra todas: %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'), to_char(pg_temp.c13_ctl_n(30) - k30, 'FMS990'),
                case when pg_temp.c13_ctl_det(20) like '%' || (select format(' Con el código del teléfono se ven %s cuenta(s) de la nómina que aquí no se comprobaron (%s): entra con él.',
                                                                              count(*), left(string_agg(x.cuenta, ', ' order by x.cuenta), 200))
                                                                 from fn_cedula(v_h) x where x.estado = 'con_codigo')
                          and (select count(*) from fn_cedula(v_h) x where x.estado = 'con_codigo' and x.saldo_libro = 0) >= 1
                          and pg_temp.c13_ctl_det(20) like '%2293%'
                          and pg_temp.c13_ctl_det(20) not like '%2293 C13 PRUEBA%' and pg_temp.c13_ctl_det(30) not like '%2293%'
                     then 'sí' else 'no: ' || pg_temp.c13_ctl_det(20) || ' / ' || pg_temp.c13_ctl_det(30) end);
    f := (select format('%s, y lo dice: %s', case when k.ok is not distinct from v_ok0 then 'como antes' else 'CAMBIÓ' end,
                        case when k.detalle like '% Con el código del teléfono se ven % cuenta(s) de la nómina que aquí no se comprobaron (%2293%): entra con él.'
                                  and length(k.detalle) <= 1500 and k.orden = 178
                             then 'sí' else 'no: ' || k.detalle end)
            from fn_cedula_cierre(v_per) k);
    -- (una SIN SALDO en el libro —antes de su journal—: también pide entrar con el código, y lo dice igual)
    h := format('%s, y también dice cómo verla: %s', pg_temp.c13_fila('2293', pg_temp.c13_d(10)),
                (select case when x.saldo_auxiliar is null and x.diferencia is null and x.por_que = 'codigo'
                                  and x.detalle like 'Sin saldo en el libro al %solo se ve con el código del teléfono: esta sesión entró sin él%No es que no cuadre: falta mirarla con el código.'
                                  and x.que_hacer like 'Entra con el código del teléfono y vuelve a mirar%'
                             then 'sí' else 'no: ' || x.detalle || ' / ' || coalesce(x.que_hacer, 'nulo') end
                   from fn_cedula(pg_temp.c13_d(10)) x where x.cuenta = '2293'));
    select v_txt || array_agg(format('%s · %s · %s · %s', x.auxiliar, x.origen, x.detalle, coalesce(x.que_hacer, ''))) into v_txt
      from fn_cedula(v_h) x where x.estado = 'con_codigo';
    select v_txt || array_agg(format('%s · %s', p.concepto, coalesce(p.nota, ''))) into v_txt from fn_cedula_partidas(v_h, '2293') p where p.clase = 'dato';
    select v_txt || array_agg(k.detalle) into v_txt from fn_cedula_control(v_per) k where k.orden in (20, 30);
    select v_txt || array_agg(k.detalle || ' · ' || coalesce(k.que_hacer, '')) into v_txt from fn_cedula_cierre(v_per) k;
    select v_txt || array_agg(format('%s · %s · %s', k.auxiliar, k.origen, coalesce(k.vacio, ''))) into v_txt from fn_cedula_cuentas() k where k.nomina is not null;
    perform pg_temp.c13_ser('editor');
    g := pg_temp.c13_estado(format('select public.fn_cedula_explicar(%L, %L, %L)', '2293', v_h, 'C13 PRUEBA: no se puede explicar lo que no se ve'), 'dueno_aal1');
    v_txt := v_txt || pg_temp.c13_dice(format('select public.fn_cedula_explicar(%L, %L, %L)', '2293', v_h, 'C13 PRUEBA: no se puede explicar lo que no se ve'), 'dueno_aal1');
    perform pg_temp.c13_ser('dueno');
    i := pg_temp.c13_fila('2293', v_h);
    perform pg_temp.c13_ser('editor');
    j := pg_temp.c13_llano(v_txt);
    v_obt := format('sin ninguna nómina en el libro, sin el código: %s | con su nómina, sin el código: %s | %s | los totales las cuentan aparte y entre las pendientes, y no está lista: %s | '
                    '%s | la fila del cierre: %s | explicarla: %s | una sin saldo: %s | con el código: %s | textos que nombran funciones: %s',
                    a, b, c, d, e, f, g, h, i, j);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'SIN EL CÓDIGO DEL TELÉFONO (una nómina fingida; el dueño por la API con la sesión en aal1): con una nómina en el libro, la cuenta de la nómina y los sueldos acumulados salen «con_codigo» (ni «no cuadra» ni «sin auxiliar»), sin auxiliar que sumar ni diferencia, diciendo cómo verla; no sale ni un renglón de ninguna nómina, y al pedir la cuenta un dato lo dice; los totales las cuentan aparte y entre las pendientes (no está «lista»); el control (el 20 y el 30) y la fila del cierre no se ponen en rojo por eso, y el 20 las nombra todas; no se explica (MX008); una sin saldo en el libro también pide entrar con el código (puede tener algo abierto en su nómina); con el código, la misma cuenta cuadra; y sin ninguna nómina en el libro sale lo mismo con el código que sin él',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 45. LA NÓMINA EN EL CONTROL Y EN LA FILA 178 DEL CIERRE (por lo que la
--     prueba mueve): una cuenta de la nómina que cuadra con lo que su nómina
--     dejó por pagar no cuenta en ningún aviso; lo que entró por otro lado
--     la deja sin cuadrar: cuenta en el 20 (no en el 30: SÍ tiene auxiliar),
--     la fila del cierre va en rojo nombrándola (y el cierre de c9, si está,
--     trae esa misma fila); explicada, vuelve.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); k1 uuid; k20 int; k30 int; v_ok0 boolean; v_c9 text := 'sí';
  a text; b text; c text; d text;
  v_esp text := 'la nómina que cuadra: el 20 +0 y el 30 +0 | lo que entró por otro lado: el 20 +1 y rojo, el 30 +0, y la nombra: sí | '
                'la fila del cierre: rojo, la nombra, dice qué hacer y cabe en 1500: sí; y la del cierre (c9) es esa misma: sí | '
                'explicada: el 20 +0 y la fila como antes';
begin
  if pg_temp.c13_omitir(45, 'la nómina en el control y en la fila del cierre', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_con_nomina();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    k20 := pg_temp.c13_ctl_n(20); k30 := pg_temp.c13_ctl_n(30);
    select k.ok into v_ok0 from fn_cedula_cierre(v_per) k;
    k1 := pg_temp.c13_journal(pg_temp.c13_d(19), 'el journal de una nómina', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '1000.00'), jsonb_build_object('cuenta', '2293', 'monto', '-1000.00')));
    perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), null, '2293', k1, pg_temp.c13_d(19), 1000, 0);
    a := format('el 20 %s y el 30 %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'), to_char(pg_temp.c13_ctl_n(30) - k30, 'FMS990'));
    -- (contra una cuenta de resultados: así lo único que cambia en la cédula es la cuenta de la nómina)
    perform pg_temp.c13_dh(pg_temp.c13_d(24), 'un ajuste a mano que no pasó por la nómina', '2293', '6200', 77.77);
    b := format('el 20 %s y %s, el 30 %s, y la nombra: %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'), pg_temp.c13_ctl(20),
                to_char(pg_temp.c13_ctl_n(30) - k30, 'FMS990'),
                case when pg_temp.c13_ctl_det(20) like '%2293 C13 PRUEBA nómina (-$77.77 de diferencia)%' and pg_temp.c13_ctl_det(30) not like '%2293%'
                     then 'sí' else 'no: ' || pg_temp.c13_ctl_det(20) end);
    if pg_temp.c13('hay_c9') = 'true' and pg_temp.c13('c9_cedula') = 'true' then
      execute $q$ select case when not k.ok and k.detalle = left(z.detalle, 1500) and k.que_hacer = z.que_hacer then 'sí' else 'no: ' || coalesce(k.detalle, 'nulo') end
                    from public.fn_cierre_revisar($1) k cross join public.fn_cedula_cierre($1) z where k.orden = 178 $q$ into v_c9 using v_per;
    end if;
    c := (select format('%s, la nombra, dice qué hacer y cabe en 1500: %s; y la del cierre (c9) es esa misma: %s', case when k.ok then 'verde' else 'rojo' end,
                        case when k.detalle like '%2293 C13 PRUEBA nómina (-$77.77 de diferencia)%' and k.que_hacer like 'No detiene el cierre.%'
                                  and length(k.detalle) <= 1500 and k.orden = 178 and k.nivel = 'aviso'
                             then 'sí' else 'no: ' || k.detalle end, coalesce(v_c9, 'no: sin fila 178'))
            from fn_cedula_cierre(v_per) k);
    perform pg_temp.c13_explicar('2293', v_h, 'C13 PRUEBA: los 77.77 son una deducción que se pagó con un cheque de papel');
    d := format('el 20 %s y la fila %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'),
                (select case when k.ok is not distinct from v_ok0 then 'como antes' else 'NO' end from fn_cedula_cierre(v_per) k));
    v_obt := format('la nómina que cuadra: %s | lo que entró por otro lado: %s | la fila del cierre: %s | explicada: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'LA NÓMINA EN EL CONTROL Y EN LA FILA 178 DEL CIERRE (una nómina fingida; por lo que la prueba mueve): una cuenta de la nómina que cuadra con lo que su nómina dejó por pagar no cuenta en ningún aviso; lo que entró por otro lado (77.77) la deja sin cuadrar y cuenta en el 20 —no en el 30: sí tiene auxiliar—, que la nombra con su diferencia; la fila del cierre va en rojo nombrándola, dice qué hacer y cabe en lo que el cierre guarda (y la revisión del cierre de c9, si está, trae esa misma fila); explicada, vuelve a como estaba',
    v_esp, v_obt || case when not (pg_temp.c13('hay_c9') = 'true' and pg_temp.c13('c9_cedula') = 'true')
                         then ' (el cierre de c9 no está en esta base, o todavía no trae la fila 178: esa parte no se miró)' else '' end,
    v_obt = v_esp);
end $$;

-- 46. LA LECTURA DE VERDAD (fn_cedula_nomina, sin fingirla). Si la nómina
--     (c15) está en esta base, se lee la suya; si no, primero se comprueba
--     que la cédula lo dice («no_esta») y después, DENTRO de la prueba, se
--     ponen dos funciones de reemplazo con los nombres que la cédula busca
--     (la del auxiliar a una fecha y la que dice si la sesión pasó el
--     código), que leen _c13_nomina. Sin ninguna nómina en el libro no hay
--     nada que tapar; con una, el SQL Editor y el dueño con su código la
--     leen, sin el código sale «codigo» SIN renglones, y el equipo recibe
--     {}. Lo que devuelve es lo que dice la nómina, renglón por renglón. Y si
--     la nómina cambia de forma (solo con las de reemplazo: la de verdad no
--     se toca), la cuenta dice «no se pudo leer» y lo demás sigue.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_real boolean := pg_temp.c13('c15') = 'true'; v_hay0 boolean; k1 uuid; v_dir jsonb; v_ed jsonb; v_n0 bigint;
  a text; b text; c text; d text; e text; f text; v_info text := '';
  v_esp text;
begin
  v_esp := 'antes: ' || case when v_real then 'la nómina está' else 'la nómina no está (no_esta), y lo dicen las capas' end
        || ' | sin ninguna nómina en el libro: ok, sin nada que tapar, con el código y sin él | con una nómina en el libro: el SQL Editor ok, el dueño con su '
        || 'código ok, sin el código codigo y sin renglones, el equipo {} | lo que devuelve es lo que dice la nómina, renglón por renglón: sí | la cuenta de prueba: '
        || case when v_real then 'no cuadra por 100.00 (la nómina de verdad no conoce ese journal), y sin el código: con_codigo'
                else 'cuadra por 100.00 con lo que dice la nómina, y sin el código: con_codigo' end
        || ' | si la nómina cambia de forma: '
        || case when v_real then 'no se finge sobre la nómina de verdad'
                else 'no se pudo leer, sin auxiliar por error, las demás cuentas siguen y el control 10 verde; sin la función del código, lo mismo' end;
  if pg_temp.c13_omitir(46, 'la lectura de verdad de la nómina', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_capas_reales();
    select exists (select 1 from asientos x where x.origen_tabla = 'nomina_corridas') into v_hay0;
    a := case when v_real
              then case when (fn_cedula_capas()->>'c15')::boolean and fn_cedula_nomina(v_h)->>'estado' = 'ok' then 'la nómina está'
                        else 'no: ' || fn_cedula_capas()::text || ' ' || fn_cedula_nomina(v_h)::text end
              else case when not (fn_cedula_capas()->>'c15')::boolean and fn_cedula_nomina(v_h) = '{"estado": "no_esta", "nominas": false}'::jsonb
                             and fn_cedula_nomina(null) = '{"estado": "no_esta", "nominas": false}'::jsonb
                             and pg_temp.c13_col('2293', v_h, 'por_que') = 'f11'
                        then 'la nómina no está (no_esta), y lo dicen las capas' else 'no: ' || fn_cedula_capas()::text || ' ' || fn_cedula_nomina(v_h)::text end end;
    if not v_real then
      -- (las dos funciones de reemplazo: solo existen dentro de esta prueba)
      create function public.fn_nomina_aal2() returns boolean language sql stable set search_path = public, pg_temp as $f$
        select current_user not in ('authenticated', 'anon', 'service_role')
               or coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'aal', '') = 'aal2' $f$;
      create function public.fn_nomina_auxiliar(p_fecha date default null)
      returns table (cuenta text, clase text, corrida_id uuid, dia_pago date, descripcion text, acreditado numeric(14,2), pagado numeric(14,2),
                     saldo numeric(14,2), asiento text, cargos text)
      language sql stable set search_path = public, pg_temp as $f$
        select n.cuenta, 'impuestos'::text, n.corrida, n.dia_pago, n.descripcion, n.acreditado::numeric(14,2), n.pagado::numeric(14,2),
               (n.acreditado - n.pagado)::numeric(14,2), n.asiento, n.cargos
          from _c13_nomina n
         where p_fecha >= n.desde and (n.hasta is null or p_fecha <= n.hasta) and n.acreditado - n.pagado <> 0 $f$;
      delete from _c13_nomina;
    end if;
    -- sin ninguna nómina en el libro (si esta base ya tiene alguna, eso no se puede mirar aquí: se dice)
    if v_hay0 then
      b := 'ok, sin nada que tapar, con el código y sin él';
      v_info := ' (esta base ya tiene nóminas en el libro: lo de «sin ninguna nómina» no se pudo mirar aquí)';
    else
      b := fn_cedula_nomina(v_h)::text;
      perform pg_temp.c13_ser('dueno_aal1');
      b := case when b::jsonb = '{"estado": "ok", "nominas": false, "filas": []}'::jsonb and fn_cedula_nomina(v_h) = b::jsonb
                     and fn_cedula_nomina(null) = b::jsonb and pg_temp.c13_col('2293', v_h, 'estado') = 'cuadra'
                then 'ok, sin nada que tapar, con el código y sin él' else 'no: ' || b || ' / ' || fn_cedula_nomina(v_h)::text end;
      perform pg_temp.c13_ser('editor');
    end if;
    -- una nómina en el libro: su journal (el día 20) deja 100 en la cuenta de prueba
    k1 := pg_temp.c13_journal(pg_temp.c13_d(19), 'el journal de una nómina', jsonb_build_array(
            jsonb_build_object('cuenta', '6200', 'monto', '100.00'), jsonb_build_object('cuenta', '2293', 'monto', '-100.00')));
    if not v_real then
      perform pg_temp.c13_nomina_dice(pg_temp.c13_d(19), null, '2293', k1, pg_temp.c13_d(19), 100, 0);
    end if;
    v_ed := fn_cedula_nomina(v_h);
    c := format('el SQL Editor %s', case when v_ed->>'estado' = 'ok' and (v_ed->>'nominas')::boolean and jsonb_typeof(v_ed->'filas') = 'array'
                                              and fn_cedula_nomina(null) = '{"estado": "ok", "nominas": true}'::jsonb then 'ok' else 'no: ' || v_ed::text end);
    perform pg_temp.c13_ser('dueno');
    c := c || format(', el dueño con su código %s', case when fn_cedula_nomina(v_h) = v_ed then 'ok' else 'no: ' || fn_cedula_nomina(v_h)::text end);
    perform pg_temp.c13_ser('dueno_aal1');
    c := c || format(', sin el código %s', case when fn_cedula_nomina(v_h) = '{"estado": "codigo", "nominas": true}'::jsonb
                                                     and fn_cedula_nomina(null) = '{"estado": "codigo", "nominas": true}'::jsonb
                                                then 'codigo y sin renglones' else 'no: ' || fn_cedula_nomina(v_h)::text end);
    e := pg_temp.c13_col('2293', v_h, 'estado');
    if pg_temp.c13('equipo') is not null then
      perform pg_temp.c13_ser('equipo');
      c := c || format(', el equipo %s', fn_cedula_nomina(v_h)::text);
    else
      c := c || ', el equipo {}';
      v_info := v_info || ' (no hay nadie del equipo con quien probar: lo del equipo no se miró)';
    end if;
    perform pg_temp.c13_ser('editor');
    -- lo que devuelve es lo que dice la nómina
    execute 'select coalesce(jsonb_agg(jsonb_build_object(''cuenta'', x.cuenta, ''corrida'', x.corrida_id, ''dia_pago'', x.dia_pago, '
         || '''descripcion'', x.descripcion, ''acreditado'', x.acreditado, ''pagado'', x.pagado, ''saldo'', x.saldo, ''asiento'', x.asiento, '
         || '''cargos'', x.cargos) order by x.cuenta, x.dia_pago, x.corrida_id), ''[]''::jsonb) from public.fn_nomina_auxiliar($1) x' into v_dir using v_h;
    d := case when v_ed->'filas' = v_dir
                   and (v_real or (jsonb_array_length(v_dir) = 1 and v_dir->0->>'cuenta' = '2293' and (v_dir->0->>'saldo')::numeric = 100
                                   and v_dir->0->>'corrida' = k1::text))
              then 'sí' else 'no: ' || coalesce(v_ed->'filas', 'null'::jsonb)::text || ' / ' || v_dir::text end;
    e := format('%s, y sin el código: %s',
                case when v_real
                     then case when pg_temp.c13_fila('2293', v_h) = 'nomina | libro 100.00 | aux 0.00 | dif 100.00 | no_cuadra (pendiente)'
                                    and pg_temp.c13_col('2293', v_h, 'detalle') like '%$100.00 están en el libro sin ser lo que una nómina dejó por pagar ni un cargo casado '
                                                                                  'con ella: entraron por otro lado. Ninguna nómina tiene nada por pagar en esta cuenta ese día.%'
                               then 'no cuadra por 100.00 (la nómina de verdad no conoce ese journal)' else 'no: ' || pg_temp.c13_fila('2293', v_h) end
                     else case when pg_temp.c13_fila('2293', v_h) = 'nomina | libro 100.00 | aux 100.00 | dif 0.00 | cuadra'
                               then 'cuadra por 100.00 con lo que dice la nómina' else 'no: ' || pg_temp.c13_fila('2293', v_h) end end, e);
    -- si la nómina cambia de forma (solo con las de reemplazo: la de verdad no se toca)
    if v_real then
      f := 'no se finge sobre la nómina de verdad';
    else
      select count(*) into v_n0 from fn_cedula(v_h);
      drop function public.fn_nomina_auxiliar(date);
      create function public.fn_nomina_auxiliar(p_fecha date default null) returns table (cuenta text, cuanto numeric)
      language sql stable set search_path = public, pg_temp as $f$ select n.cuenta, n.acreditado from _c13_nomina n $f$;
      f := case when fn_cedula_nomina(v_h)->>'estado' = 'error' and nullif(fn_cedula_nomina(v_h)->>'error', '') is not null
                     and pg_temp.c13_fila('2293', v_h) = 'nomina | libro 100.00 | aux - | dif - | sin_auxiliar (pendiente)'
                     and pg_temp.c13_col('2293', v_h, 'por_que') = 'error'
                     and pg_temp.c13_col('2293', v_h, 'detalle') like 'Sin auxiliar: no se pudo leer (%). Tiene $100.00 en el libro al %'
                     and pg_temp.c13_col('2293', v_h, 'que_hacer') like 'Avisa:%'
                     and (select count(*) from fn_cedula(v_h)) = v_n0 and pg_temp.c13_ctl(10) = 'verde'
                then 'no se pudo leer, sin auxiliar por error, las demás cuentas siguen y el control 10 verde'
                else 'no: ' || fn_cedula_nomina(v_h)::text || ' / ' || pg_temp.c13_fila('2293', v_h) || ' / ' || pg_temp.c13_col('2293', v_h, 'detalle') end;
      drop function public.fn_nomina_aal2();
      f := f || '; sin la función del código, ' || case when fn_cedula_nomina(v_h)->>'estado' = 'error' and fn_cedula_nomina(null)->>'estado' = 'error'
                                                             and pg_temp.c13_col('2293', v_h, 'estado') = 'sin_auxiliar' and pg_temp.c13_col('2293', v_h, 'por_que') = 'error'
                                                             and (select count(*) from fn_cedula(v_h)) = v_n0
                                                        then 'lo mismo' else 'no: ' || fn_cedula_nomina(v_h)::text || ' / ' || pg_temp.c13_fila('2293', v_h) end;
    end if;
    v_obt := format('antes: %s | sin ninguna nómina en el libro: %s | con una nómina en el libro: %s | lo que devuelve es lo que dice la nómina, renglón por '
                    'renglón: %s | la cuenta de prueba: %s | si la nómina cambia de forma: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (46, 'LA LECTURA DE VERDAD DE LA NÓMINA (la función de la cédula que la lee, sin fingirla; con la nómina de esta base si está y, si no, con dos funciones de reemplazo que solo existen dentro de la prueba): si no está lo dice (y sus cuentas siguen «llega con la nómina»); sin ninguna nómina en el libro no hay nada que tapar, con el código o sin él; con una, el SQL Editor y el dueño con su código la leen, sin el código sale «codigo» sin un solo renglón, y el equipo recibe {}; lo que devuelve es lo que dice la nómina, renglón por renglón; y si la nómina cambia de forma, la cuenta dice «no se pudo leer», lo demás sigue y el control 10 queda verde',
    v_esp, v_obt || v_info, v_obt = v_esp);
end $$;

-- 47. CON LO QUE ESTA BASE TENGA DE NÓMINA (c15 de verdad; «omitida» si no
--     está). Sin sembrar nada y sin fingir nada: en hoy, en el día que toca y
--     alrededor de cada journal de nómina que haya en el libro (su fecha y
--     los cuatro días anteriores: cuando Gusto cobra), y en cada cuenta que
--     se sostiene con la nómina: lo que la cédula pone «de la nómina» es lo
--     que la nómina dice ese día, al centavo y renglón por renglón; en los
--     sueldos acumulados, el auxiliar es el devengo más lo de la nómina más
--     lo escrito a mano, una vez cada cosa; el dueño con su código ve lo
--     mismo que el SQL Editor; y sin el código, si hay nóminas en el libro,
--     esas cuentas salen «con_codigo» sin un renglón de nómina (si no las
--     hay, lo mismo que con él).
do $$
declare
  v_obt text; v_hoy date := pg_temp.c13('hoy')::date; v_fechas date[]; v_hay boolean; v_ctas int; v_m0 text; v_m1 text; v_m2 text;
  a text; b text; c text; d text; v_info text := '';
  v_esp text := 'lo de la nómina en la cédula es lo que dice la nómina, cuenta por cuenta y día por día: sí | en los sueldos acumulados, el devengo más la '
                'nómina más lo escrito a mano, una vez cada cosa: sí | el dueño con su código ve lo que el SQL Editor: sí | sin el código: sí';
begin
  if pg_temp.c13_omitir(47, 'con lo que esta base tenga de nómina', v_esp, array['c15']) then return; end if;
  begin
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_reloj();
    select exists (select 1 from asientos x where x.origen_tabla = 'nomina_corridas') into v_hay;
    select array_agg(z.f order by z.f) into v_fechas
      from (select y.f from (select distinct x.fecha_contable - g.n as f
                               from asientos x cross join generate_series(0, 4) g(n)
                              where x.origen_tabla = 'nomina_corridas'
                             union select v_hoy
                             union select coalesce((select q.hasta from periodos q where q.periodo = fn_cedula_toca()), v_hoy)) y
             where y.f <= v_hoy order by y.f desc limit 12) z;
    select count(*) into v_ctas from fn_cedula_cuentas() k where k.nomina is not null;
    -- (lo que dice la nómina, por su función; y lo que la cédula pone «de la nómina»: mismas cuentas, mismas nóminas, mismos montos)
    execute $q$
      select case when count(*) = 0 then 'sí' else 'no: ' || left(string_agg(format('%s al %s (%s)', z.cuenta, z.f, z.que), '; '), 400) end
        from (select coalesce(n.f, p.f) as f, coalesce(n.cuenta, p.cuenta) as cuenta,
                     case when n.cuenta is null then 'la cédula trae ' || p.monto || ' que la nómina no dice'
                          when p.cuenta is null then 'la nómina dice ' || n.monto || ' y la cédula no lo trae'
                          else 'la nómina dice ' || n.monto || ' y la cédula ' || p.monto end as que
                from (select u.f, x.cuenta, x.corrida_id::text as corrida, (-k.signo * x.saldo)::numeric(14,2) as monto
                        from unnest($1) u(f) cross join lateral public.fn_nomina_auxiliar(u.f) x
                        join public.fn_cedula_cuentas() k on k.cuenta = x.cuenta and k.nomina is not null) n
                full join (select u.f, i.cuenta, i.ref_id as corrida, i.monto
                             from unnest($1) u(f) cross join lateral public.fn_cedula_partidas(u.f, null) i
                            where i.clase = 'auxiliar' and i.fuente = 'nomina') p
                  on p.f = n.f and p.cuenta = n.cuenta and p.corrida = n.corrida
               where n.cuenta is null or p.cuenta is null or n.monto <> p.monto) z $q$ into a using v_fechas;
    if fn_cedula_nomina(v_hoy)->>'estado' <> 'ok' then
      a := 'no: la cédula no pudo leer la nómina (' || fn_cedula_nomina(v_hoy)::text || ')';
    end if;
    select case when count(*) = 0 then 'sí' else 'no: ' || left(string_agg(format('%s al %s', z.cuenta, z.f), '; '), 300) end into b
      from (select u.f, x.cuenta
              from unnest(v_fechas) u(f) cross join lateral fn_cedula(u.f) x
              join fn_cedula_cuentas() k on k.cuenta = x.cuenta and k.nomina is not null
              left join lateral (select coalesce(sum(i.monto), 0) as s, count(*) as n,
                                        count(*) filter (where i.fuente not in ('devengos', 'nomina', 'manual')) as otros,
                                        count(*) - count(distinct (i.fuente, i.clave)) as repetidos
                                   from fn_cedula_partidas(u.f, x.cuenta) i where i.clase = 'auxiliar') s on true
             where x.estado not in ('cuadra', 'no_cuadra', 'explicada') or x.saldo_auxiliar is distinct from s.s::numeric(14,2) or x.renglones <> s.n
                or s.otros > 0 or s.repetidos > 0) z;
    select md5(coalesce(string_agg(z::text, '|' order by z.fecha, z.cuenta), '')) into v_m0
      from (select x.fecha, x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.por_que, x.renglones, x.detalle
              from unnest(v_fechas) u(f) cross join lateral fn_cedula(u.f) x) z;
    perform pg_temp.c13_ser('dueno');
    select md5(coalesce(string_agg(z::text, '|' order by z.fecha, z.cuenta), '')) into v_m1
      from (select x.fecha, x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.por_que, x.renglones, x.detalle
              from unnest(v_fechas) u(f) cross join lateral fn_cedula(u.f) x) z;
    c := case when v_m0 = v_m1 and (select count(*) from fn_cedula(v_hoy) x where x.por_que in ('error', 'codigo')) = 0 then 'sí' else 'no' end;
    perform pg_temp.c13_ser('dueno_aal1');
    if v_hay then
      d := (select case when count(*) filter (where x.estado <> 'con_codigo' or x.saldo_auxiliar is not null or x.diferencia is not null
                                                    or x.por_que is distinct from 'codigo' or x.pendiente is distinct from true) = 0
                             and count(*) > 0
                             and (select count(*) from unnest(v_fechas) w(f) cross join lateral fn_cedula_partidas(w.f, null) i where i.fuente = 'nomina') = 0
                             and not (fn_cedula_nomina(v_hoy) ? 'filas') and fn_cedula_nomina(v_hoy)->>'estado' = 'codigo'
                        then 'sí' else 'no: ' || left(string_agg(x.cuenta || ' ' || x.estado, ', ') filter (where x.estado <> 'con_codigo'), 300) end
              from unnest(v_fechas) u(f) cross join lateral fn_cedula(u.f) x
              join fn_cedula_cuentas() k on k.cuenta = x.cuenta and k.nomina is not null);
    else
      select md5(coalesce(string_agg(z::text, '|' order by z.fecha, z.cuenta), '')) into v_m2
        from (select x.fecha, x.cuenta, x.saldo_libro, x.saldo_auxiliar, x.diferencia, x.estado, x.pendiente, x.por_que, x.renglones, x.detalle
                from unnest(v_fechas) u(f) cross join lateral fn_cedula(u.f) x) z;
      d := case when v_m2 = v_m0 then 'sí' else 'no: sin nóminas en el libro, la cédula sin el código no es la misma' end;
    end if;
    perform pg_temp.c13_ser('editor');
    v_info := format(' (%s cuenta(s) de la nómina en %s día(s); %s)', v_ctas, cardinality(v_fechas),
                     case when v_hay then 'con nóminas en el libro: sin el código salen «con_codigo»'
                          else 'sin ninguna nómina en el libro todavía: sin el código sale lo mismo que con él' end);
    v_obt := format('lo de la nómina en la cédula es lo que dice la nómina, cuenta por cuenta y día por día: %s | en los sueldos acumulados, el devengo más la '
                    'nómina más lo escrito a mano, una vez cada cosa: %s | el dueño con su código ve lo que el SQL Editor: %s | sin el código: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, 'CON LO QUE ESTA BASE TENGA DE NÓMINA (c15 de verdad, sin sembrar ni fingir nada): en hoy, en el día que toca y alrededor de cada journal de nómina del libro, y en cada cuenta que se sostiene con la nómina, lo que la cédula pone «de la nómina» es lo que la nómina dice ese día, al centavo y nómina por nómina; el auxiliar de esas cuentas es el devengo más la nómina más lo escrito a mano, una vez cada cosa; el dueño con su código ve exactamente lo que el SQL Editor; y sin el código, si hay nóminas en el libro, esas cuentas salen «con_codigo» sin un renglón de nómina (si no las hay, lo mismo que con él)',
    v_esp, v_obt || v_info, v_obt = v_esp);
end $$;

-- 48. UNA CUENTA POR PAGAR AL REVÉS NO «CUADRA» (13-nov, los arreglos de la
--     verificación de la Fase 11b). La nómina paga un reembolso cuyo gasto
--     no está registrado y la cuenta por pagar queda con saldo DEUDOR; su
--     auxiliar dice lo mismo (en negativo) y la cédula la daba por buena.
--     Ahora, una cuenta de pasivo con el saldo al revés que por lo demás
--     cuadraría sale «no_cuadra» diciéndolo, con su qué hacer; el aviso 20
--     la cuenta y la nombra así; se puede explicar; y con lo que se debía
--     ya registrado (la cuenta vuelve a su lado) cuadra. A una cuenta de
--     ACTIVO con el saldo al revés no le toca.
do $$
declare
  v_obt text; v_h date := pg_temp.c13_h(); v_per text := pg_temp.c13('mes'); k20 int; a text; b text; c text; d text; e text;
  v_esp text := 'una cuenta por pagar con 80.00 de saldo deudor y su auxiliar por lo mismo: no_cuadra, pide algo, y dice que está al revés y '
                'qué hacer: sí | el aviso 20: +1, y la nombra así: sí | explicada: explicada, y el 20: +0 | con lo que se debía ya '
                'registrado (vuelve a su lado): cuadra | una cuenta de activo con el saldo al revés y su auxiliar por lo mismo: cuadra '
                '(esto es de las cuentas por pagar)';
begin
  if pg_temp.c13_omitir(48, 'una cuenta por pagar al revés no cuadra', v_esp) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', v_per));
    k20 := pg_temp.c13_ctl_n(20);
    -- (se pagaron 80.00 que no se debían —o cuyo gasto no está registrado—: la cuenta por pagar de prueba queda deudora; su
    -- auxiliar, escrito a mano, dice lo mismo)
    perform pg_temp.c13_dh(pg_temp.c13_d(5), 'un pago de más en una cuenta por pagar', '2293', '1093', 80);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2293', 'concepto', 'C13 PRUEBA: pagado de más a un tercero', 'monto', '-80.00',
              'desde', pg_temp.c13_d(5)::text, 'documento', 'C13 PRUEBA recibo del pago'));
    a := format('%s, %s, y dice que está al revés y qué hacer: %s', pg_temp.c13_col('2293', v_h, 'estado'),
                case when pg_temp.c13_col('2293', v_h, 'pendiente') = 'true' then 'pide algo' else 'no pide nada' end,
                case when pg_temp.c13_col('2293', v_h, 'detalle')
                          like '-$80.00 en el libro al % y lo mismo en %, pero está AL REVÉS: es una cuenta por pagar y su saldo es deudor ($80.00 a favor de la empresa)%'
                      and pg_temp.c13_col('2293', v_h, 'que_hacer') like '%regístralo a nombre de quien es%explícalo con sus palabras%'
                     then 'sí' else 'no' end);
    b := format('%s, y la nombra así: %s', to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'),
                case when pg_temp.c13_ctl_det(20) like '%2293 C13 PRUEBA nómina (está al revés: una cuenta por pagar con $80.00 de saldo deudor)%'
                     then 'sí' else 'no' end);
    perform pg_temp.c13_explicar('2293', v_h, 'C13 PRUEBA: se le pagó de más y lo devuelve el mes que viene');
    c := format('%s, y el 20: %s', pg_temp.c13_col('2293', v_h, 'estado'), to_char(pg_temp.c13_ctl_n(20) - k20, 'FMS990'));
    -- (lo que se debía, registrado después: 100.00. La cuenta vuelve a su lado —20.00 por pagar—, y su auxiliar con ella)
    perform pg_temp.c13_dh(pg_temp.c13_d(9), 'lo que se debía, registrado', '6200', '2293', 100);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '2293', 'concepto', 'C13 PRUEBA: lo que se debía', 'monto', '100.00',
              'desde', pg_temp.c13_d(9)::text, 'documento', 'C13 PRUEBA factura'));
    d := pg_temp.c13_col('2293', v_h, 'estado');
    -- (una cuenta de ACTIVO al revés: los depósitos de prueba, con 30.00 de saldo acreedor y su renglón a mano por lo mismo)
    perform pg_temp.c13_dh(pg_temp.c13_d(6), 'un depósito devuelto de más', '1093', '1693', 30);
    perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: devuelto de más', 'monto', '-30.00',
              'desde', pg_temp.c13_d(6)::text, 'documento', 'C13 PRUEBA recibo'));
    e := pg_temp.c13_col('1693', v_h, 'estado');
    v_obt := format('una cuenta por pagar con 80.00 de saldo deudor y su auxiliar por lo mismo: %s | el aviso 20: %s | explicada: %s | con lo que '
                    'se debía ya registrado (vuelve a su lado): %s | una cuenta de activo con el saldo al revés y su auxiliar por lo mismo: %s '
                    '(esto es de las cuentas por pagar)', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, 'UNA CUENTA POR PAGAR AL REVÉS NO «CUADRA»: una cuenta de pasivo que no sostiene la nómina, con saldo deudor y un auxiliar que suma lo mismo (la nómina pagó un reembolso cuyo gasto no está registrado; a un proveedor se le pagó de más), sale «no_cuadra» diciendo que está al revés y qué hacer; el aviso 20 la cuenta y la nombra así; se puede explicar; con lo que se debía ya registrado cuadra; y a una cuenta de activo con el saldo al revés no le toca',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. CON LA CÉDULA EN USO, NINGÚN CONTROL DE LAS OTRAS CAPAS PASA A ROJO.
--     En cuentas DE VERDAD de esta base (sin tocar el libro): un renglón a
--     mano, la explicación de la primera cuenta que pida algo hoy (si la
--     hay), otro renglón corregido y anulado, y la configuración cambiada.
--     Después se miran la cadena y «permisos» de c2, los puentes (c3), los
--     estados (c4, hoy y el mes), el banco (c6), y los cuadres de c8, c10,
--     c11 y c12, y lo que detiene el cierre del mes (c9): ni uno nuevo.
do $$
declare
  v_obt text; v_hoy date := pg_temp.c13('hoy')::date; v_cta text; v_cta2 text; v_id uuid; v_n int := 0;
  v_esp text := 'rojos nuevos en las otras capas: ninguno | permisos (c2): verde';
begin
  if pg_temp.c13_omitir(38, 'ningún control ajeno pasa a rojo', v_esp, array[]::text[]) then return; end if;
  begin
    perform pg_temp.c13_ser('editor');
    perform pg_temp.c13_reloj();
    select x.cuenta into v_cta from fn_cedula(v_hoy) x where x.pendiente order by x.cuenta limit 1;
    select x.cuenta into v_cta2 from fn_cedula(v_hoy) x order by x.cuenta limit 1;
    if v_cta2 is not null then
      perform pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', v_cta2, 'concepto', 'C13 PRUEBA: un renglón en una cuenta de verdad', 'monto', '1.00',
                'desde', v_hoy::text, 'documento', 'C13 PRUEBA papel'));
      v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', v_cta2, 'concepto', 'C13 PRUEBA: otro, que se corrige y se anula', 'monto', '2.00',
                                                          'desde', v_hoy::text))->>'id')::uuid;
      v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('id', v_id::text, 'monto', '3.00'))->>'id')::uuid;
      perform pg_temp.c13_ser('dueno');
      perform fn_cedula_renglon_anular(v_id, 'C13 PRUEBA: fuera');
      perform pg_temp.c13_ser('editor');
      v_n := v_n + 1;
    end if;
    if v_cta is not null then
      perform pg_temp.c13_explicar(v_cta, v_hoy, 'C13 PRUEBA: una explicación en una cuenta de verdad');
      v_n := v_n + 1;
    end if;
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', to_char(v_hoy, 'YYYY-MM'), 'patrimonio', 'manual'));
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', coalesce(pg_temp.c13('mes'), to_char(v_hoy, 'YYYY-MM')), 'patrimonio', 'mayor'));
    v_obt := format('rojos nuevos en las otras capas: %s | permisos (c2): %s', pg_temp.c13_nuevos(pg_temp.c13_rojos_antes(), pg_temp.c13_rojos_limpio()),
                    pg_temp.c13_permisos());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'CON LA CÉDULA EN USO, NINGÚN CONTROL DE LAS OTRAS CAPAS PASA A ROJO: con un renglón a mano en una cuenta de verdad, otro corregido y anulado, la explicación de una cuenta de verdad que pida algo hoy (si la hay) y la configuración cambiada, la cadena y «permisos» de c2, los puentes (c3), los estados (c4, hoy y el mes), el banco (c6), los cuadres de c8, c10, c11 y c12 y lo que detiene el cierre del mes (c9) siguen como estaban',
    v_esp,
    v_obt || case when pg_temp.c13('rojos_antes') <> '' then ' (ya en rojo antes, con los datos de esta base: ' || array_to_string(pg_temp.c13_rojos_antes(), '; ') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 39. LA CÉDULA SOLO MIRA. Con el libro tal cual, se llama a TODO lo de
--     c13 —leer a varias fechas, los renglones, el control, la fila del
--     cierre, QuickBooks, las vistas, el pegado; y escribir: la
--     configuración, un renglón, corregirlo, anularlo, explicar y retirar—:
--     ni un asiento, ni una línea, ni un número de asiento gastado, y nada en
--     las tablas de las otras capas. (Corre también con todos los meses
--     cerrados: no necesita postear.)
do $$
declare
  v_obt text; v_hoy date := pg_temp.c13('hoy')::date; v_per text := coalesce(pg_temp.c13('mes'), pg_temp.c13('en_curso'), fn_cedula_toca());
  v_h date; v0 text; v1 text; v_id uuid; v_k bigint;
  v_esp text := 'ni un asiento, ni una línea, ni un número gastado, y nada en las tablas de las otras capas';
begin
  if pg_temp.c13_omitir(39, 'la cédula solo mira', v_esp, array['cuentas']) then return; end if;
  begin
    perform pg_temp.c13_sembrar();
    perform pg_temp.c13_ser('editor');
    v_h := coalesce((select q.hasta from periodos q where q.periodo = v_per), v_hoy);
    v0 := format('%s asientos, %s líneas, contadores %s ·', (select count(*) from asientos), (select count(*) from asiento_lineas),
                 (select coalesce(sum(ultimo), 0) from contadores)) || pg_temp.c13_conteos_capas();
    -- leer
    select count(*) into v_k from fn_cedula(v_h);
    select count(*) into v_k from fn_cedula(null);
    select count(*) into v_k from fn_cedula(v_hoy);
    select count(*) into v_k from fn_cedula_partidas(v_h, null);
    select count(*) into v_k from fn_cedula_partidas(v_hoy, '1030');
    select count(*) into v_k from fn_cedula_cuentas();
    if to_regprocedure('public.fn_cedula_nomina(date)') is not null then
      execute 'select count(*) from jsonb_object_keys(public.fn_cedula_nomina($1))' into v_k using v_hoy;
    end if;
    select count(*) into v_k from fn_cedula_control(v_per);
    select count(*) into v_k from fn_cedula_cierre(v_per);
    if v_per is not null then
      select count(*) into v_k from fn_cedula_qb(v_per);
    end if;
    select count(*) into v_k from fn_cedula_qb_periodos();
    select count(*) into v_k from v_cedula;
    select count(*) into v_k from v_cedula_control;
    select count(*) into v_k from v_cedula_manual;
    select count(*) into v_k from v_cedula_explicaciones;
    select count(*) into v_k from v_cedula_qb;
    select count(*) into v_k from fn_cedula_pegado();
    -- escribir
    perform pg_temp.c13_config(jsonb_build_object('avisar_desde', to_char(v_hoy, 'YYYY-MM'), 'patrimonio', 'manual'));
    v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('cuenta', '1693', 'concepto', 'C13 PRUEBA: depósito de la bodega', 'monto', '400.00',
                                                        'desde', v_hoy::text))->>'id')::uuid;
    v_id := (pg_temp.c13_renglon_pon(jsonb_build_object('id', v_id::text, 'monto', '450.00', 'documento', 'C13 PRUEBA contrato'))->>'id')::uuid;
    perform pg_temp.c13_explicar('1693', v_hoy, 'C13 PRUEBA: el depósito todavía no está asentado en el libro');
    perform pg_temp.c13_ser('dueno');
    perform fn_cedula_resumen(v_hoy);
    perform fn_cedula_explicacion_retirar('1693', v_hoy, 'C13 PRUEBA: fuera');
    perform fn_cedula_renglon_anular(v_id, 'C13 PRUEBA: fuera');
    perform pg_temp.c13_ser('editor');
    v1 := format('%s asientos, %s líneas, contadores %s ·', (select count(*) from asientos), (select count(*) from asiento_lineas),
                 (select coalesce(sum(ultimo), 0) from contadores)) || pg_temp.c13_conteos_capas();
    v_obt := case when v0 = v1 then 'ni un asiento, ni una línea, ni un número gastado, y nada en las tablas de las otras capas'
                  else 'CAMBIÓ: ' || v0 || ' → ' || v1 end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'LA CÉDULA SOLO MIRA: llamando a todo lo de c13 (leer a varias fechas, los renglones, el control, la fila del cierre, QuickBooks, las vistas, el pegado; y escribir la configuración, un renglón, corregirlo, anularlo, explicar y retirar) el libro no gana ni un asiento, ni una línea, ni gasta un número, y las tablas de las otras capas (banco, préstamos, pólizas, activos, WIP, Stripe, QuickBooks) quedan como estaban',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 40. NADA QUEDA: después de todo lo anterior, la base está como al empezar
--     (la configuración, los renglones, las explicaciones, el libro y sus
--     números, las cuentas, las obras, las facturas, los cobros, los
--     proveedores, las tarjetas, los períodos, las funciones, y las tablas de
--     las otras capas que las pruebas tocan).
do $$
declare
  v_obt text; v_esp text := 'nada';
begin
  begin
    perform pg_temp.c13_ser('editor');
    v_obt := case when pg_temp.c13_conteos() || pg_temp.c13_conteos_capas() = pg_temp.c13('conteos') then 'nada'
                  else 'QUEDÓ: ' || pg_temp.c13_conteos() || pg_temp.c13_conteos_capas() || ' (antes: ' || pg_temp.c13('conteos') || ')' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'NADA QUEDA al deshacer: la configuración de la cédula, sus renglones y explicaciones, el libro y sus números, las cuentas, las obras, las facturas, los cobros, los proveedores, las tarjetas, los períodos, las funciones y las tablas de las otras capas están como antes de las pruebas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. EL CIERRE DE LA SUITE: con c13 puesto, la cadena y «permisos» de c2,
--     los puentes (c3), los estados (c4), el banco (c6), los cuadres de c8,
--     c10, c11 y c12 y lo que detiene el cierre (c9) están como antes de las
--     pruebas (lo que ya estaba en rojo con los datos de esta base se dice y
--     no se cuenta); nada de c13 es para anon o service_role ni SECURITY
--     DEFINER; fn_cedula_pegado responde; y, mirado todo eso, la base sigue
--     como al empezar (tampoco la revisión del cierre que c9 guarda).
do $$
declare
  v_obt text; v_api text; v_n int; v_cfg int;
  v_esp text := 'rojos nuevos en c2, c3, c4, c6, c8, c9, c10, c11 y c12: ninguno | permisos (c2): verde | c13 para anon o service_role, o definer: '
                'ninguna | el pegado: 8 filas, y la configuración 1 fila (id 1) | y nada queda: sí';
begin
  begin
    perform pg_temp.c13_ser('editor');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c13_es_suya(p.proname)
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_cedula_pegado();
    select count(*) into v_cfg from cedula_config;
    v_obt := format('rojos nuevos en c2, c3, c4, c6, c8, c9, c10, c11 y c12: %s | permisos (c2): %s | c13 para anon o service_role, o definer: %s | '
                    'el pegado: %s filas, y la configuración %s fila (id %s)',
                    pg_temp.c13_nuevos(pg_temp.c13_rojos_antes(), pg_temp.c13_rojos_limpio()), pg_temp.c13_permisos(), v_api, v_n, v_cfg,
                    (select id from cedula_config limit 1));
    v_obt := v_obt || ' | y nada queda: '
             || case when pg_temp.c13_conteos() || pg_temp.c13_conteos_capas() = pg_temp.c13('conteos') then 'sí'
                     else 'QUEDÓ: ' || pg_temp.c13_conteos() || pg_temp.c13_conteos_capas() || ' (antes: ' || pg_temp.c13('conteos') || ')' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, 'el cierre de la suite: con c13 puesto, la cadena y «permisos» de c2, los puentes (c3), los estados (c4), el banco (c6), los cuadres de c8, c10, c11 y c12 y lo que detiene el cierre (c9) siguen como antes de las pruebas (lo que ya estaba en rojo se dice y no se cuenta); nada de c13 para anon o service_role ni SECURITY DEFINER; fn_cedula_pegado responde y la configuración es una fila (pegar dos veces no la pisa: lo corre el banco)',
    v_esp,
    v_obt || case when pg_temp.c13('rojos_antes') <> '' then ' (ya en rojo antes, con los datos de esta base: ' || array_to_string(pg_temp.c13_rojos_antes(), '; ') || ')' else '' end
          || case when pg_temp.c13('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c13: ' || pg_temp.c13('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- EL RELOJ, COMO ESTABA. Cada prueba deshace el suyo con su subtransacción; esto es la red: si alguno quedara puesto, se
-- restaura aquí mismo el de verdad (el que había al empezar) y sale como un fallo, con su fila.
do $$
begin
  if pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) is distinct from pg_temp.c13('reloj_def') then
    reset role;
    execute pg_temp.c13('reloj_def');
    insert into _pruebas values (99, 'EL RELOJ DE LAS PRUEBAS: ninguna prueba deja puesto el reloj fingido', 'el reloj de verdad, al terminar',
      'una prueba dejó puesto el reloj fingido: se restauró el de verdad aquí mismo. Es un fallo de este archivo: avisa.', false);
  end if;
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8, c9, c10, c11 y c12): si el SQL Editor deja de esperar, la corrida
-- sigue en el servidor hasta el final y se lee después con
--   select * from pruebas.c13_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c13_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c13_resultado from public, anon, authenticated, service_role;
truncate pruebas.c13_resultado;
insert into pruebas.c13_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
