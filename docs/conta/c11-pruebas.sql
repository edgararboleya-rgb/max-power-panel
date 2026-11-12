-- =====================================================================
-- c11-pruebas.sql — la emisión de facturas se prueba a sí misma
-- (c11-emision.sql). 12-nov-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c11-emision.sql
-- (el de ahora: el que trae la tabla emision_soltados y dice en cada
-- documento a cuál sustituyó; con uno anterior este archivo para al empezar
-- y lo dice), pegar este archivo entero → Run. Sale la tabla _pruebas: 57
-- filas, todas con ok = true (las que salen «omitida» dicen por qué y no son
-- un fallo).
-- Si el editor se cansa antes del final, la corrida sigue en el servidor y
-- se lee después en pruebas.c11_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- pegada y c11-emision.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c11-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las obras de prueba, ni sus hitos, ni sus facturas, ni sus
-- asientos, ni el contador de la serie, ni los ajustes); la 42 lo
-- comprueba. Lo único que no vuelve atrás es el número interno (id) que
-- Postgres le habría dado a la siguiente fila de facturas (algo más de cien
-- por corrida: medido, 107) y, en las pruebas 30 a 32, a los avisos y cobros
-- de los cobros en línea: la emisión inserta en facturas como la app, y una
-- secuencia no se deshace. No es el número de la factura (ese sí vuelve: lo
-- lleva contadores) y no deja fila.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · UNA PERSONA DE PRUEBA («Zzeva C11 PRUEBA», del equipo: rol campo), con
--     su usuario en auth.users. Si la base no deja crearla, las pruebas que
--     siembran salen «omitida» y dicen qué dijo la base.
--   · CUATRO OBRAS DE PRUEBA («C11 PRUEBA Uno»…«Cuatro», ids c11-prueba-a…d),
--     con su contrato y sus hitos (ids negativos: no gastan la secuencia), y
--     un contratista de prueba si la tabla contratistas existe.
--   · LOS AJUSTES, dentro de cada prueba: el corte adelantado a hoy (para
--     poder emitir), una empresa y un «How to pay» de mentira («ZZ Electric
--     C11 PRUEBA, Inc.»), y las reglas de ingreso por tipo de obra
--     confirmadas si no lo estaban. Todo vuelve a como estaba.
--   · El año de los números es el de hoy, y siguen al último de la serie
--     real: las pruebas miran SUS números (el siguiente al que había).
-- Los controles ajenos (c2, c3, c4, c6, p1, c8, c9, c10) se comparan con
-- cómo estaban justo antes (lo que ya estaba en rojo se dice y no se
-- cuenta), y una prueba que pone en rojo un control de c11 que YA estaba en
-- rojo con los datos reales sale «omitida» y lo dice. «Ya estaba en rojo»
-- se mira DOS veces: antes de todo, y con las obras de prueba sembradas y el
-- corte adelantado a hoy (con datos reales, una factura de hoy hecha fuera
-- de la app enciende el 72 solo por adelantar el corte: no es de las
-- pruebas, y antes hacía fallar en falso la 31 y la 43).
-- El reloj fingido de la 18 (el cambio de año) es el de c2-pruebas: rehace
-- fn_fecha_miami dentro de su subtransacción y el MXT00 la deshace.
--
-- COMO PRODUCCIÓN (lo que el banco no tenía y allá hizo fallar siete de
-- estas pruebas el 12-nov; el banco lo trae ahora con
-- pruebas/conta/06-produccion-facturas.sql, y esta suite pasa con él y sin
-- él):
--   · LOS ÍNDICES ÚNICOS DE facturas POR HITO (de la app, de la otra sesión:
--     ux_facturas_hito, que cuenta también las anuladas, y
--     ux_facturas_hito_viva). Con ellos dos filas de facturas vivas con el
--     mismo hito no caben: la 36 y la 41, que fabricaban ese caso a mano,
--     miran qué índice tiene la base (pg_temp.c11_candado_hito, por su
--     forma, no por su nombre) y van por el único camino que queda (la fila
--     de la factura de la app sin su hito). Y volver a facturar un hito
--     anulado (la 20 y la 43) pasa porque la capa suelta la anulada. La 52,
--     la 53 y la 54 lo prueban a fondo con el índice que la base tenga (el
--     banco con 06-produccion-facturas.sql y producción: el que cuenta las
--     anuladas, que es con el que fallaba; sin él prueban lo mismo —la capa
--     suelta siempre— y lo dicen). La 55 es al revés: su caso (dos anuladas,
--     o una viva y una anulada, con el mismo hito) solo se da SIN ese
--     índice; con él, comprueba que no se puede dar.
--   · EL CANDADO DE BORRADO DE STORAGE (de Supabase: un DELETE directo a
--     storage.objects da 42501 salvo con la marca de la transacción
--     storage.allow_delete_query, que es la que pone la API de Storage). La
--     28 y la 37 ponen esa marca dentro de su subtransacción antes de
--     borrar; en una base sin el candado no hace nada. (La 46 ya no borra
--     nada: no le hacía falta.) Lo que sigue a esos borrados NO se había
--     corrido nunca en producción (las tres morían en el DELETE): si allá la
--     base no deja borrar el archivo de prueba por otra razón, la 37 sale
--     «omitida» y la dice, y la 28 mira lo que le importa (que el archivo
--     sigue ahí, igual).
--
-- NO FRENA A LA APP (la revisión del 12-nov; lo prueba, con dos sesiones de
-- verdad, pruebas/conta/c11-concurrencia.sh, 7 y 8):
--   · LO PRIMERO QUE HACE ES PONER lock_timeout A MEDIO SEGUNDO para toda la
--     corrida, como el pegado de la capa. Si algo que una prueba necesita lo
--     tiene tomado la app (u otra sesión) y no lo suelta en medio segundo,
--     la prueba no espera más: sale «omitida» y dice por qué (no es un
--     fallo: se vuelve a pegar en un momento más tranquilo). Quien espera un
--     candado fuerte deja esperando detrás de sí a todos los que llegan
--     después. Importa sobre todo en la 46, que pone y quita policies de
--     prueba en storage.objects —la tabla de TODOS los archivos de la app—
--     dentro de bloques que se deshacen: sin tope, con una lectura larga de
--     Storage abierta en otra sesión, la suite se quedaba esperando y todas
--     las lecturas de archivos de la app, detrás de ella (medido en el
--     banco: paradas mientras duró la otra sesión, 20 s y más, en vez de
--     milisegundos). Con el tope, la 46 prueba
--     solo su primera mitad y lo dice. (Si lo que no se suelta lo necesita
--     el arranque del archivo —alguien pegando otra capa a la vez—, la
--     corrida entera para con 55P03, no cambia nada, y se vuelve a pegar.)
--   · NO CREA NI QUITA ÍNDICES EN LAS TABLAS DE LA APP. Las pruebas 52, 53 y
--     54 corren con el índice único de facturas por hito que la base tenga
--     (y lo dicen). Antes, si faltaba el que cuenta las anuladas, ponían uno
--     igual dentro de sí mismas: crear un índice para toda escritura en
--     facturas mientras dura la prueba (medido en el banco, con la cadena
--     entera: «marcar cobrada» esperando casi 8 s, que es el tope de la
--     API). Hoy producción lo tiene; el día
--     que la otra sesión lo quite, estas pruebas siguen valiendo sin tocar
--     nada.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 8 tablas, 4 vistas, las 37 funciones por su
--    nombre exacto, los ajustes, cada objeto con su comentario «c11: …»);
--  2 las precondiciones en rojo (desde la app; sin una función de c3; una
--    función con nombre de c11 que no es de c11; una vista ajena colgada);
--  3 la API por rol: anon y service_role nada; el equipo (rol campo) 42501 y
--    cero filas; el dueño entra y ve;
--  4 el catálogo: una sola SECURITY DEFINER (la del número, de trigger y sin
--    EXECUTE), ningún prefijo de otra capa ni de la otra sesión, RLS y
--    policies justas, vistas security_invoker que no cuelgan de vistas de
--    otras capas; «permisos» (c2), «protecciones del banco» (c6) y las de
--    c4 en verde con c11 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API;
--    lo soltado se apunta y ni se cambia ni se borra);
--  6 los ajustes (fn_emision_config) y sus frenos; la tarjeta no se enciende;
--  7 el corte: v_emision_estado dice QuickBooks o la app; antes del corte
--    el borrador sí y emitir no (MX008, en llano);
--  8 el borrador de un hito (uno por hito, su texto, refrescar; el hito
--    cobrado y el ya facturado no);
--  9 el borrador por porcentaje (un contrato que no divide; sin contrato no);
-- 10 el borrador T&M (horas y material; la suma en numeric; sus frenos);
-- 11 la retención: de dónde sale el porcentaje (el estimado, en fracción; la
--    obra; el borrador) y la regla de redondeo (10 % de 1,234.57);
-- 12 EMITIR un hito, como el dueño por la API y con el puente diferido: el
--    número, la fila de facturas, el asiento al centavo, el hito, el sello;
-- 13 lo que pasa al confirmar (los controles diferidos del libro) y la
--    cadena del libro, en verde;
-- 14 el visto: otra pestaña cambió el borrador → MX011 y nada cambia;
-- 15 dos veces el mismo borrador, y el mismo hito por dos caminos → MX008;
-- 16 LA SERIE SIN HUECOS y ningún número dos veces: el que ya lleva una
--    factura de fuera se salta; una emisión que el libro no acepta no gasta
--    número;
-- 17 tres hitos que suman el contrato, con retención: tres números
--    seguidos, tres asientos al centavo, y lo retenido por factura;
-- 18 el año que cambia: la última de un año y la primera del siguiente;
-- 19 congelado: después de emitir nada cambia (ni por la función, ni a
--    mano, ni la fila de facturas);
-- 20 ANULAR por c3: su nota de crédito, el hito vuelve a pendiente, y la
--    buena sale con número nuevo;
-- 21 anulada desde Contabilidad (c3 directo): aquí se termina; con un cobro
--    aplicado no se anula (el freno de c3);
-- 22 por porcentaje y T&M, emitidas: sus asientos;
-- 23 el hito de depósito: se factura, y el documento lo dice;
-- 24 a un contratista: a quién se factura, a_contratista, su retención;
-- 25 LA FACTURA DE LA RETENCIÓN: lista lo retenido de cada factura, con
--    número de SU serie y sin asiento; no se reclama dos veces; cobrada, ya
--    no sale; la serie de las facturas no se entera;
-- 26 el contenido congelado (lo que recibe el cliente) y la vista previa;
-- 27 el idioma: un texto que parece español frena hasta que se confirma;
-- 28 EL PDF: se registra si está en Storage, mide lo declarado y se pintó de
--    ese contenido; versiones; no se pisa;
-- 29 EL ENVÍO: el correo con su id de Resend, el reenvío, en mano; sin PDF no;
-- 30 EL PAGO EN LÍNEA: lo que va a Stripe es lo que dice la factura, solo
--    por cuenta de banco; el enlace de p1 lo cobra exacto; un PDF con otro
--    enlace o con tarjeta no se registra;
-- 31 p1 contabiliza BIEN el pago por cuenta de banco de una factura de la
--    app (Dr 1020 / Cr 1110 de la factura; la retención queda);
-- 32 LA PRUEBA DEL RECARGO: un pago con tarjeta por más de lo que debe la
--    factura: p1 deja lo de más de anticipo de la obra, no de ingreso (por
--    eso la tarjeta queda apagada);
-- 33 el control 10 (la factura es su asiento) en rojo y de vuelta;
-- 34 el control 20 (la serie) en rojo y de vuelta;
-- 35 el control 30 (el sello) en rojo y de vuelta;
-- 36 los controles 40 y 75 (un hito con dos facturas; con el índice único
--    de facturas por hito, por el camino que queda);
-- 37 los controles 50, 60 y 62 (el PDF que ya no está; sin PDF; sin mandar);
-- 38 los controles 70 y 72 (la retención que parece un porcentaje; una
--    factura de después del corte hecha fuera de la app);
-- 39 los controles 80, 85 y 90 (un cobro con tarjeta; los datos de la
--    empresa; las protecciones);
-- 40 lo que la pantalla pinta: v_emision_documentos y v_emision_obras;
-- Lo que encontraron los revisores (12-nov), cada cosa con su prueba:
-- 45 un hito no se factura dos veces aunque su fila de facturas deje de
--    apuntarlo; un hito borrado y vuelto a crear (los controles 40, 42, 44);
-- 46 el bucket «facturas» pide el código del teléfono (aal2), y sus
--    candados (el control 90);
-- 47 anular con un pago por cuenta de banco en camino: no;
-- 48 el corte tiene vuelta atrás (solo cuentan las facturas vivas), y avisa;
-- 49 el visto es de la vista previa entera (otra factura de la obra, otro
--    día); el depósito con retención se dice;
-- 50 el control 64: cobrada entera en el libro y sin marcar en la obra;
-- Lo que encontró la revisión final (12-nov; FALLA con la capa de antes):
-- 51 SOLO SE FACTURA UN HITO PENDIENTE: el que la ficha ya tiene como
--    facturado y aquí no tiene factura (se facturó en QuickBooks a mano) no
--    se ofrece, su borrador no se abre y uno ya abierto no se emite;
-- Lo que falló en producción (12-nov; en una base con el índice único de
-- facturas por hito, FALLAN si la emisión no suelta la anulada, como la de
-- antes):
-- 52 VOLVER A FACTURAR UN HITO CUYA FACTURA SE ANULÓ: el borrador lo avisa
--    sin frenar; al emitir, la anulada suelta el hito y en lo demás no
--    cambia (ni su nota, ni su asiento, ni lo cobrado; su puente no asienta
--    nada); queda apuntado en emision_soltados; otra vuelta hace lo mismo;
--    ningún control se enciende; y el pegado lo dice;
-- 53 una factura de QuickBooks anulada en Contabilidad (c3) y su hito
--    facturado por la app: mientras la ficha lo tenga como facturado no se
--    abre (y dice por qué factura); devuelto a pendiente, la de QuickBooks
--    suelta el hito y queda apuntada como de fuera de la app;
-- 54 dos a la vez por dos caminos, la red: si la fila de facturas de la
--    emisión choca con un índice único de la base, MX011 en llano —y qué
--    índice, en el detalle del error— y no queda nada;
-- 55 dos anuladas apuntando al mismo hito, y una viva con una anulada (solo
--    en una base sin el índice que cuenta las anuladas): con la viva el
--    borrador dice solo que ya se facturó; con las dos anuladas las nombra
--    y la emisión suelta a las dos; con ese índice, se comprueba que el
--    caso no se puede dar;
-- Lo que encontró la revisión de ese arreglo (12-nov; FALLAN con la capa de
-- antes de esa revisión):
-- 56 EL HITO QUE SIGUE COMO FACTURADO CON SU FACTURA ANULADA (anulada desde
--    Contabilidad, por c3: de QuickBooks, o de la app y sin cerrar aquí):
--    el control 75 lo avisa; pedir su borrador dice cuál es la anulada, con
--    su nota de crédito, y qué hacer (antes: «aquí no hay ninguna factura
--    suya»); un borrador ya abierto dice lo mismo y no añade «esta la
--    sustituye»; devuelto el hito a pendiente (o cerrada aquí la de la
--    app), se factura;
-- 57 LO SUSTITUIDO SE VE: el documento de la factura nueva dice a cuál
--    sustituyó (de la app o de QuickBooks) y el de la anulada, cuál la
--    sustituyó; el que no sustituyó a nadie, nada;
-- Y el cierre:
-- 41 el cierre del mes (c9) mira la facturación: las filas 172 y 173;
-- 42 nada queda al deshacer (tampoco la revisión guardada del cierre del
--    mes: las lecturas de «lo que está en rojo» de antes y de después de las
--    pruebas van en bloques que se deshacen);
-- 43 con facturas emitidas, anuladas, vueltas a emitir, por porcentaje,
--    T&M, cobradas y con su factura de la retención, NINGÚN control de c2,
--    c3, c4, c6, p1, c8, c9 ni c10 pasa a rojo;
-- 44 el cierre de la suite: c2, c3, c6 y c4 como estaban, c8 y c10 sin
--    cuadres rojos nuevos, nada de c11 en la API de anon o service_role, y
--    fn_emision_pegado responde con sus doce filas (pegar dos veces no hace
--    daño: lo corre el banco).
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
-- (Lo primero, como el pegado de la capa: esta corrida espera un candado
-- como mucho medio segundo. Si la app —u otra sesión— tiene tomado algo que
-- una prueba necesita, la prueba no se queda esperando (ni deja esperando
-- detrás de ella a quien llegue después): sale «omitida» y lo dice. Dura lo
-- que dura la corrida, una transacción. Ver «No frena a la app».)
set local lock_timeout = '500ms';

-- (Estas pruebas son las del c11-emision.sql de ahora: el que trae la tabla
-- emision_soltados y dice en cada documento a cuál sustituyó. Con uno
-- anterior —o sin c11—, paran aquí, sin tocar nada, y dicen qué pegar.)
do $$
begin
  if to_regclass('public.emision_soltados') is null or to_regprocedure('public.fn_emision_pegado()') is null
     or not exists (select 1 from pg_proc p
                     where p.oid = to_regprocedure('public.fn_emision_documento(uuid)') and p.prosrc like '%sustituida_por%') then
    raise exception using errcode = 'MX000',
      message = 'c11-pruebas NO se corrió, no se tocó nada: esta base no tiene el c11-emision.sql de ahora ('
                || case when to_regclass('public.emision_soltados') is null then 'le falta la tabla emision_soltados'
                        else 'es el de antes de su última revisión' end || ').',
      hint    = 'Pega antes docs/conta/c11-emision.sql entero (encima del anterior: no pisa nada) y después vuelve a pegar este archivo.';
  end if;
end $$;

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién y qué día es.
create temp table if not exists _c11 (k text primary key, v text);
truncate _c11;
insert into _c11
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c11 values ('p1', '00000000-0000-4000-a000-0000000c1101');   -- Zzeva C11 PRUEBA (rol campo)
insert into _c11 values ('hoy', fn_fecha_miami(now())::text);
insert into _c11
select 'mes', p.periodo from periodos p where p.tipo = 'mes' and fn_fecha_miami(now()) between p.desde and p.hasta;
insert into _c11 values ('hay_p1', (to_regclass('public.stripe_enlaces') is not null)::text);
insert into _c11 values ('hay_c4', (to_regprocedure('public.fn_estados_control(text,text[])') is not null)::text);
insert into _c11 values ('hay_c6', (to_regprocedure('public.fn_banco_control(text,text[])') is not null)::text);
insert into _c11 values ('hay_c8', (to_regclass('public.v_contador_control') is not null)::text);
insert into _c11 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
insert into _c11 values ('hay_c10', (to_regclass('public.v_jornal_control') is not null and to_regclass('public.v_margen_control') is not null)::text);
insert into _c11 values ('hay_storage', (to_regclass('storage.objects') is not null)::text);
insert into _c11 values ('hay_gc', (to_regclass('public.contratistas') is not null)::text);
grant select on _c11 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9 y c10), y
-- ningún aviso al teléfono desde la ronda de c9 ni desde p1 si algo los
-- despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
  perform set_config('mxp.stripe_sin_push', '1', false);
end $$;

create or replace function pg_temp.c11(k text) returns text language sql as $$ select v from _c11 where k = $1 $$;

-- Las funciones que crea c11-emision.sql, por su nombre exacto (las 37).
-- No se buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c11_es_suya(p_nombre text) returns boolean language sql immutable as $$
  select p_nombre = any (array[
    'fn_emision_precondiciones', 'fn_emision_exigir_dueno', 'fn_emision_ve', 'fn_emision_guarda', 'fn_emision_numerar',
    'fn_emision_usd', 'fn_emision_dia', 'fn_emision_numero', 'fn_emision_formato', 'fn_emision_tarjeta_lista', 'fn_emision_tarjeta_texto',
    'fn_emision_parece_espanol', 'fn_emision_cuenta', 'fn_emision_saldo', 'fn_emision_retencion', 'fn_emision_retencion_de',
    'fn_emision_destinatario', 'fn_emision_enlaces', 'fn_emision_pagos', 'fn_emision_storage', 'fn_emision_retenido',
    'fn_emision_factura_de_hito', 'fn_emision_revisar',
    'fn_emision_visto', 'fn_emision_contenido', 'fn_emision_documento', 'fn_emision_borrador', 'fn_emision_descartar',
    'fn_emision_obra', 'fn_emision_config', 'fn_emision_emitir', 'fn_emision_anular', 'fn_emision_pago', 'fn_emision_pdf',
    'fn_emision_envio', 'fn_emision_control', 'fn_emision_pegado'])
$$;
create or replace function pg_temp.c11_tablas() returns text[] language sql immutable as $$
  select array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie', 'emision_pdfs',
               'emision_envios', 'emision_soltados']
$$;
create or replace function pg_temp.c11_vistas() returns text[] language sql immutable as $$
  select array['v_emision_estado', 'v_emision_documentos', 'v_emision_obras', 'v_emision_control']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o la persona de
-- prueba por la API (authenticated, en aal2), anon o service_role.
create or replace function pg_temp.c11_ser(quien text) returns void language plpgsql as $$
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
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c11(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c11(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;
-- Como el dueño por la API pero SOLO CON SU CONTRASEÑA: una sesión aal1, sin
-- el código del teléfono (la que s1 corta en la API de datos, y Storage no).
create or replace function pg_temp.c11_ser_aal1() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c11('dueno'), 'role', 'authenticated', 'aal', 'aal1')::text, true);
  perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c11('dueno'), ''), true);
  execute 'set local role authenticated';
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): la persona de
-- prueba, las cuatro obras con su contrato y sus hitos, las reglas de
-- ingreso confirmadas y los ajustes de la factura (el corte ya pasado, una
-- empresa y un «How to pay» de mentira).
--   Uno    servicio     contrato 10,000.00   hitos 3,333.33 + 3,333.33 + 3,333.34
--   Dos    comercial    contrato 18,500.55   un hito de 1,234.57
--   Tres   residencial  contrato  4,000.00   depósito 1,234.57 + final 2,765.43
--   Cuatro servicio     sin contrato ni hitos
create or replace function pg_temp.c11_sembrar() returns void language plpgsql as $$
declare
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
begin
  perform pg_temp.c11_ser('editor');
  if v_meta then
    execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                   pg_temp.c11('p1'), 'c11-p1@c11-pruebas.invalid',
                   json_build_object('nombre', 'Zzeva C11 PRUEBA', 'name', 'Zzeva C11 PRUEBA', 'full_name', 'Zzeva C11 PRUEBA')::text);
  else
    execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                   pg_temp.c11('p1'), 'c11-p1@c11-pruebas.invalid');
  end if;
  insert into perfiles (id, nombre, rol, activo) values (pg_temp.c11('p1')::uuid, 'Zzeva C11 PRUEBA', 'campo', true)
  on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  perform fn_mapeo_confirmar('tipo_proyecto', null);
  insert into proyectos (id, tipo, nombre, estado, cliente, direccion, cliente_email) values
    ('c11-prueba-a', 'servicio',    'C11 PRUEBA Uno',    'ejecucion', 'ZZ Cliente Uno',    '1 ZZ Test Rd, Testville, FL 00000', 'zz.uno@c11-pruebas.invalid'),
    ('c11-prueba-b', 'comercial',   'C11 PRUEBA Dos',    'ejecucion', 'ZZ Cliente Dos',    '2 ZZ Test Rd, Testville, FL 00000', null),
    ('c11-prueba-c', 'residencial', 'C11 PRUEBA Tres',   'ejecucion', 'ZZ Cliente Tres',   null, null),
    ('c11-prueba-d', 'servicio',    'C11 PRUEBA Cuatro', 'ejecucion', 'ZZ Cliente Cuatro', null, null);
  insert into finanzas_proyecto (proyecto_id, contrato) values
    ('c11-prueba-a', 10000.00), ('c11-prueba-b', 18500.55), ('c11-prueba-c', 4000.00);
  insert into hitos (id, proyecto_id, titulo, condicion, monto, estado, orden, es_deposito) overriding system value values
    (-1110000001, 'c11-prueba-a', 'C11 PRUEBA Milestone 1', 'Due upon passing the rough-in inspection', 3333.33, 'pendiente', 1, false),
    (-1110000002, 'c11-prueba-a', 'C11 PRUEBA Milestone 2', null, 3333.33, 'pendiente', 2, false),
    (-1110000003, 'c11-prueba-a', 'C11 PRUEBA Milestone 3', null, 3333.34, 'pendiente', 3, false),
    (-1110000004, 'c11-prueba-c', 'C11 PRUEBA Deposit', 'Due at contract signing', 1234.57, 'pendiente', 0, true),
    (-1110000005, 'c11-prueba-c', 'C11 PRUEBA Final', null, 2765.43, 'pendiente', 1, false),
    (-1110000006, 'c11-prueba-b', 'C11 PRUEBA Rough', null, 1234.57, 'pendiente', 1, false);
  perform fn_emision_config(jsonb_build_object(
    'corte', least((select c.corte from emision_config c where c.id = 1), pg_temp.c11('hoy')::date)::text,
    'empresa', jsonb_build_object('nombre', 'ZZ Electric C11 PRUEBA, Inc.', 'licencia', 'ZZ-0000',
                                  'direccion', '100 ZZ Test Ave, Testville, FL 00000', 'telefono', '(000) 000-0000',
                                  'correo', 'billing@c11-pruebas.invalid', 'web', 'c11-pruebas.invalid'),
    'como_pagar', 'Check payable to ZZ Electric C11 PRUEBA, Inc. Bank transfer (ACH): use the secure link in the email.',
    'terminos_dias', 0, 'terminos_texto', '', 'ach', true));
end $$;

-- ¿Se puede sembrar en esta base? Se prueba UNA vez, antes de todo, y se
-- deshace. Si no, las pruebas que siembran salen «omitida» con lo que dijo
-- la base.
do $$
declare
  v text := 'ok';
  v_rojos text := '';
begin
  begin
    perform pg_temp.c11_sembrar();
    -- (los controles de c11 que quedan en rojo SOLO por sembrar —el corte adelantado a hoy—, con los datos de esta base)
    select coalesce(string_agg(k.orden::text, ',' order by k.orden), '') into v_rojos from v_emision_control k where not k.ok;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c11 values ('siembra', v);
  insert into _c11 values ('ctl_rojos_sembrado', v_rojos);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar; devuelve true si la puso)
create or replace function pg_temp.c11_omitir(p_n int, p_prueba text, p_esperado text) returns boolean language plpgsql as $$
begin
  if pg_temp.c11('siembra') = 'ok' then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    'omitida: esta base no deja sembrar las obras y la persona de prueba (' || left(pg_temp.c11('siembra'), 300) || ')', null);
  return true;
end $$;

-- Un contratista de prueba para la obra Dos (si la tabla existe y deja).
-- Devuelve nulo si lo puso, o por qué no.
create or replace function pg_temp.c11_contratista() returns text language plpgsql as $$
begin
  if pg_temp.c11('hay_gc') <> 'true' then
    return 'esta base no tiene la tabla contratistas';
  end if;
  begin
    execute $q$ insert into public.contratistas (id, nombre, contacto, email)
                values ('c11-prueba-gc', 'ZZ General Contractor C11 PRUEBA', 'Zz Contact', 'zz.gc@c11-pruebas.invalid') $q$;
    update proyectos set contratista_id = 'c11-prueba-gc', contratista_modo = 'contrato' where id = 'c11-prueba-b';
  exception when others then
    return 'la base no dejó crear el contratista de prueba (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
  end;
  return null;
end $$;

-- Como el dueño por la API: abrir (o cambiar) un borrador; emitir uno con
-- lo que se ve (su visto de ahora); un hito entero (borrador y emisión);
-- anular. Al volver, otra vez el SQL Editor.
create or replace function pg_temp.c11_borrador(p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c11_ser('dueno');
  r := fn_emision_borrador(p);
  perform pg_temp.c11_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c11_emitir(p_doc uuid, p_op jsonb default '{}'::jsonb) returns jsonb language plpgsql as $$
declare
  v text;
  r jsonb;
begin
  perform pg_temp.c11_ser('dueno');
  v := fn_emision_documento(p_doc)->>'visto';
  r := fn_emision_emitir(p_doc, v, p_op);
  perform pg_temp.c11_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c11_hito(p_hito bigint, p_extra jsonb default '{}'::jsonb) returns jsonb language plpgsql as $$
declare
  b jsonb;
begin
  b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', p_hito) || p_extra);
  return pg_temp.c11_emitir((b->'documento'->>'id')::uuid);
end $$;
create or replace function pg_temp.c11_anular(p_doc uuid, p_motivo text) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c11_ser('dueno');
  r := fn_emision_anular(p_doc, p_motivo);
  perform pg_temp.c11_ser('editor');
  return r;
end $$;

-- Lo que contesta una sentencia corrida como alguien: 'entró', o su código
-- (c11_cod), o su código y el principio de su mensaje (c11_err).
create or replace function pg_temp.c11_cod(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c11_ser(p_quien);
  begin
    execute p_sql;
    v := 'entró';
  exception when others then
    v := sqlstate;
  end;
  perform pg_temp.c11_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c11_err(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c11_ser(p_quien);
  begin
    execute p_sql;
    v := 'entró';
  exception when others then
    v := sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c11_ser('editor');
  return v;
end $$;

-- (y con el DETALLE del error, que la pantalla no enseña: {codigo, mensaje, detalle}; {codigo: 'entró'} si no falló)
create or replace function pg_temp.c11_err_det(p_sql text, p_quien text default 'dueno') returns jsonb language plpgsql as $$
declare
  v jsonb;
  v_det text;
begin
  perform pg_temp.c11_ser(p_quien);
  begin
    execute p_sql;
    v := jsonb_build_object('codigo', 'entró');
  exception when others then
    get stacked diagnostics v_det = pg_exception_detail;
    v := jsonb_build_object('codigo', sqlstate, 'mensaje', sqlerrm, 'detalle', coalesce(v_det, ''));
  end;
  perform pg_temp.c11_ser('editor');
  return v;
end $$;

-- El siguiente número de la serie de hoy (el que le tocaría a la próxima
-- emisión), y el k-ésimo después del último.
create or replace function pg_temp.c11_num(p_k int default 1) returns text language sql as $$
  select fn_emision_numero((select c.serie_formato from emision_config c where c.id = 1),
                           extract(year from fn_fecha_miami(now()))::int,
                           coalesce((select k.ultimo from contadores k
                                      where k.serie = 'facturas-' || extract(year from fn_fecha_miami(now()))::int), 0)::int + p_k)
$$;
-- El contador de la serie de un año (0 si no existe)
create or replace function pg_temp.c11_contador(p_anio int default null) returns bigint language sql as $$
  select coalesce((select k.ultimo from contadores k
                    where k.serie = 'facturas-' || coalesce(p_anio, extract(year from fn_fecha_miami(now()))::int)), 0)
$$;
-- El siguiente número de la serie de las facturas de la RETENCIÓN (la suya:
-- MXP-R-AAAA-NNNN, contador «retenciones-AAAA»).
create or replace function pg_temp.c11_num_ret(p_k int default 1) returns text language sql as $$
  select fn_emision_numero(replace((select c.serie_formato from emision_config c where c.id = 1), '-AAAA-', '-R-AAAA-'),
                           extract(year from fn_fecha_miami(now()))::int,
                           coalesce((select k.ultimo from contadores k
                                      where k.serie = 'retenciones-' || extract(year from fn_fecha_miami(now()))::int), 0)::int + p_k)
$$;

-- El asiento vivo de una factura en una línea: «cxc 1111.11 | ret 123.46 |
-- ingreso -1234.57» (la cuenta por cobrar, la retención por cobrar y el
-- ingreso, por lo que son; otra cuenta, por su código).
create or replace function pg_temp.c11_asiento(p_factura bigint) returns text language sql as $$
  select coalesce(string_agg(format('%s %s%s',
           case when l.cuenta = fn_emision_cuenta('cxc') then 'cxc'
                when l.cuenta = fn_emision_cuenta('retencion_cxc') then 'ret'
                when c.tipo in ('ingreso', 'otro_ingreso') then 'ingreso' else l.cuenta end,
           l.monto,
           case when l.proyecto_id is distinct from (select f.proyecto_id from facturas f where f.id = p_factura) then ' (otra obra)'
                when l.cuenta in (fn_emision_cuenta('cxc'), fn_emision_cuenta('retencion_cxc'))
                     and (l.partida_tabla is distinct from 'facturas' or l.partida_id is distinct from p_factura::text) then ' (sin su partida)'
                else '' end), ' | ' order by l.orden), 'sin asiento')
    from asiento_lineas l
    join cuentas c on c.codigo = l.cuenta
   where l.asiento_id = (select f.contabilizado_en from facturas f where f.id = p_factura)
$$;

-- Una fila del control de c11: 'verde' o 'rojo: detalle'; y solo el color.
create or replace function pg_temp.c11_ctl(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo: ' || c.detalle end from v_emision_control c where c.orden = p_orden
$$;
create or replace function pg_temp.c11_color(p text) returns text language sql immutable as $$ select split_part(p, ':', 1) $$;

-- EL ÍNDICE ÚNICO DE facturas POR HITO que tenga esta base. No es de c11: es
-- de la app (de la otra sesión). En producción hay dos (leídos el 12-nov):
-- ux_facturas_hito, que cuenta TODAS las filas, también las anuladas, y
-- ux_facturas_hito_viva, solo las vivas; el banco los trae con
-- pruebas/conta/06-produccion-facturas.sql. Devuelve 'todas' (hay uno que
-- cuenta también las anuladas), 'vivas' (solo de los que cuentan las vivas)
-- o 'ninguno'. Se lee del catálogo por su forma (único, de una sola columna,
-- hito_id), no por su nombre.
create or replace function pg_temp.c11_candado_hito() returns text language sql as $$
  select case when count(*) = 0 then 'ninguno'
              when bool_or(coalesce(pg_get_expr(i.indpred, i.indrelid), '') !~* '\mestado\M') then 'todas'
              else 'vivas' end
    from pg_index i
   where i.indrelid = 'public.facturas'::regclass and i.indisunique and i.indisvalid and i.indnkeyatts = 1 and i.indexprs is null
     and i.indkey[0] = (select a.attnum from pg_attribute a where a.attrelid = i.indrelid and a.attname = 'hito_id' and not a.attisdropped)
$$;
-- (ESTE ARCHIVO NO CREA ESE ÍNDICE SI FALTA. Antes, la 52, la 53 y la 54
-- ponían uno igual dentro de sí mismas en una base que no lo trajera: crear
-- un índice para toda escritura en facturas hasta que la prueba se deshace
-- —segundos—, y eso en producción es la app esperando. Ahora corren con lo
-- que la base tenga y lo dicen: cómo se llama el caso de cada una, aquí.)
create or replace function pg_temp.c11_con_que_indice(p_caso text) returns text language sql as $$
  select case pg_temp.c11_candado_hito()
           when 'todas' then p_caso || ', con el índice único de producción (un hito, una sola fila de facturas, también las anuladas)'
           when 'vivas' then p_caso || ' (en esta base, que no deja dos facturas VIVAS del mismo hito y no cuenta las anuladas: sin el '
                             'índice con el que falló en producción, se prueba lo mismo, que la capa suelta siempre)'
           else p_caso || ' (en esta base, sin índice único de facturas por hito —producción sí lo tiene—: se prueba lo mismo, que la '
                'capa suelta siempre; el choque con el índice se prueba donde lo hay)' end
$$;
-- Los índices únicos de facturas por hito de esta base, por su nombre (para
-- reconocer el que nombre un error): '' si no hay.
create or replace function pg_temp.c11_indices_hito() returns text[] language sql as $$
  select coalesce(array_agg(c.relname::text order by c.relname), '{}')
    from pg_index i
    join pg_class c on c.oid = i.indexrelid
   where i.indrelid = 'public.facturas'::regclass and i.indisunique and i.indisvalid and i.indnkeyatts = 1 and i.indexprs is null
     and i.indkey[0] = (select a.attnum from pg_attribute a where a.attrelid = i.indrelid and a.attname = 'hito_id' and not a.attisdropped)
$$;

-- Los controles del WIP (c12) en rojo, cuadres y avisos, si c12 está en
-- esta base ('sin c12' si no): la 52 mira que soltar un hito no los mueva.
create or replace function pg_temp.c11_wip_rojos() returns text language plpgsql as $$
declare
  v text;
begin
  if to_regclass('public.v_wip_control') is null then
    return 'sin c12';
  end if;
  execute $q$ select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'ninguno') from public.v_wip_control k where not k.ok $q$ into v;
  return v;
end $$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los
-- estados (c4), los cuadres de p1, de la IA (c8) y de c10, y lo que detiene
-- el cierre del mes de hoy (c9), las que estén. Como el SQL Editor.
create or replace function pg_temp.c11_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c11_ser('editor');
  select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
  v := v || x;
  if pg_temp.c11('hay_c6') = 'true' then
    execute $q$ select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') from public.fn_banco_control('hoy') k where not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_c4') = 'true' then
    execute $q$ select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') from public.fn_estados_control('hoy') k where not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_p1') = 'true' then
    execute $q$ select coalesce(array_agg('p1: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_stripe_control k where k.nivel = 'cuadre' and k.ok is distinct from true $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_c10') = 'true' then
    execute $q$ select coalesce(array_agg('c10: ' || k.orden || ' ' || k.cuadre order by k.orden), '{}')
                  from (select orden, cuadre, nivel, ok from public.v_jornal_control
                        union all select 100 + orden, cuadre, nivel, ok from public.v_margen_control) k
                 where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_c9') = 'true' and pg_temp.c11('mes') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k where k.nivel = 'detiene' and k.ok is distinct from true $q$
       into x using pg_temp.c11('mes');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c11_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- LOS CONTROLES DE c11 que YA estaban en rojo antes de las pruebas (con
-- datos reales puede haberlos: una factura hecha fuera de la app después del
-- corte…). La prueba que pone uno en rojo y lo devuelve a verde sale
-- «omitida» si ya estaba en rojo.
insert into _c11 select 'ctl_rojos', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_emision_control k where not k.ok;
-- (los que ya estaban en rojo: antes de todo, o solo por sembrar —el corte adelantado a hoy—)
create or replace function pg_temp.c11_ya_rojos() returns text[] language sql as $$
  select string_to_array(coalesce(pg_temp.c11('ctl_rojos'), ''), ',') || string_to_array(coalesce(pg_temp.c11('ctl_rojos_sembrado'), ''), ',')
$$;
create or replace function pg_temp.c11_omitir_rojo(p_n int, p_prueba text, p_esperado text, p_ordenes int[]) returns boolean
language plpgsql as $$
declare
  v text;
begin
  select string_agg(o::text, ', ' order by o) into v
    from unnest(p_ordenes) o where o::text = any (pg_temp.c11_ya_rojos());
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    format('omitida: el control %s de la facturación ya estaba en rojo antes de las pruebas (o lo está con solo adelantar el corte a hoy), '
           'con los datos de esta base (míralo en v_emision_control): aquí no se puede ver que pase a rojo y vuelva', v), null);
  return true;
end $$;
-- (los controles de c11 en rojo que no lo estaban antes: «nada nuevo» si ninguno)
create or replace function pg_temp.c11_propios() returns text language sql as $$
  select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_emision_control k
   where not k.ok and k.orden::text <> all (pg_temp.c11_ya_rojos())
$$;
-- El nombre que el cierre (c9) le da a su fila de los cuadres (172) o de los
-- avisos (173) de la facturación: dice cuáles están en rojo.
create or replace function pg_temp.c11_nombre_fila(p_nivel text) returns text language sql as $$
  select case p_nivel when 'cuadre' then 'facturas: sus cuadres (c11)' else 'facturas: sus avisos (c11)' end
         || case when count(*) filter (where not k.ok) > 0
                 then format(' — %s en rojo: %s', count(*) filter (where not k.ok),
                             string_agg(k.orden::text, ', ' order by k.orden) filter (where not k.ok))
                 else '' end
    from v_emision_control k where k.nivel = p_nivel
$$;

-- Lo que hay en lo que c11 toca (la 42 lo compara)
create or replace function pg_temp.c11_conteos() returns text language plpgsql as $$
declare
  v text;
  x text := '';
begin
  select format('ajustes %s · obras %s · documentos %s · líneas %s · serie %s · pdfs %s · envíos %s · soltados %s · facturas %s (%s) · hitos %s · '
                'notas de crédito %s · contadores %s · asientos %s · líneas del libro %s · papeles de los puentes %s · cobros %s · '
                'obras %s · finanzas %s · estimados %s · perfiles %s · usuarios %s · reglas de ingreso %s · períodos %s (%s cerrados) · '
                'funciones %s · índices de facturas %s · triggers de la serie %s',
                (select md5(to_jsonb(c)::text) from emision_config c where c.id = 1), (select count(*) from emision_obras),
                (select count(*) from emision_documentos), (select count(*) from emision_lineas), (select count(*) from emision_serie),
                (select count(*) from emision_pdfs), (select count(*) from emision_envios), (select count(*) from emision_soltados),
                (select count(*) from facturas),
                (select md5(coalesce(string_agg(f.id || ':' || f.estado || ':' || coalesce(f.hito_id::text, '-'), ',' order by f.id), '')) from facturas f),
                (select md5(coalesce(string_agg(h.id || ':' || coalesce(h.estado, ''), ',' order by h.id), '')) from hitos h),
                (select count(*) from notas_credito),
                (select md5(coalesce(string_agg(k.serie || ':' || k.ultimo, ',' order by k.serie), '')) from contadores k),
                (select count(*) from asientos), (select count(*) from asiento_lineas), (select count(*) from puente_documentos),
                (select count(*) from cobros), (select count(*) from proyectos), (select count(*) from finanzas_proyecto),
                (select count(*) from estimados), (select count(*) from perfiles), (select count(*) from auth.users),
                (select md5(coalesce(string_agg(m.tipo || ':' || coalesce(m.confirmado_el::text, '-'), ',' order by m.tipo), ''))
                   from mapeo_tipo_proyecto m),
                (select count(*) from periodos), (select count(*) from periodos p where to_jsonb(p)->>'estado' = 'cerrado'),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace),
                (select count(*) from pg_index i where i.indrelid = 'public.facturas'::regclass),
                (select count(*) from pg_trigger t where t.tgrelid = 'public.emision_serie'::regclass and not t.tgisinternal))
    into v;
  if pg_temp.c11('hay_storage') = 'true' then
    execute 'select '' · archivos '' || count(*) from storage.objects' into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_p1') = 'true' then
    execute 'select format('' · enlaces %s · pagos %s · avisos de p1 %s · ajustes de p1 %s'', (select count(*) from public.stripe_enlaces), '
            '(select count(*) from public.stripe_pagos), (select count(*) from public.stripe_avisos), '
            '(select md5(to_jsonb(c)::text) from public.stripe_config c where c.id = 1))' into x;
    v := v || x;
  end if;
  if pg_temp.c11('hay_gc') = 'true' then
    execute 'select '' · contratistas '' || count(*) from public.contratistas' into x;
    v := v || x;
  end if;
  -- (la revisión guardada del cierre de cada período: mirar «lo que detiene el cierre» la reescribe. Las pruebas la miran
  -- dentro de bloques que se deshacen: tiene que quedar la que había, con su hora)
  if to_regclass('public.cierre_revisiones') is not null then
    execute 'select format('' · revisiones del cierre %s (%s)'', count(*), '
            'md5(coalesce(string_agg(r.periodo || '':'' || r.revisado_el, '','' order by r.periodo), ''''))) '
            'from public.cierre_revisiones r' into x;
    v := v || x;
  end if;
  return v;
end $$;
insert into _c11 values ('conteos', pg_temp.c11_conteos());

-- (lo de c3, c4 y c6 que ya estaba en rojo ANTES de las pruebas: la 44 lo dice y no lo cuenta. Se lee dentro de un bloque
-- que se deshace: mirar lo que detiene el cierre del mes guarda su revisión —como abrir la pantalla Cierre—, y estas
-- pruebas no dejan nada)
do $$
declare
  v text;
begin
  begin
    v := array_to_string(pg_temp.c11_rojos(), '; ');
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null;
  end;
  insert into _c11 values ('rojos_antes', v);
end $$;
-- (las funciones AJENAS a c11 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 44
-- las dicen y no las cuentan como fallo de c11. Una función de c11 nunca
-- entra aquí.)
create or replace function pg_temp.c11_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c11
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c11_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c11: %';
-- «permisos» de c2 sin contar lo ajeno de antes: 'verde' o 'rojo: …'
create or replace function pg_temp.c11_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c11_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c11('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c11_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;

-- EL RELOJ FINGIDO (el de c2-pruebas): «hoy» pasa a ser esa fecha (o el hoy
-- de verdad, si es posterior). Solo DENTRO de la subtransacción de una
-- prueba: su MXT00 lo deshace.
create or replace function pg_temp.c11_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;

-- LO DE LOS COBROS EN LÍNEA (p1), si está: lo que hace su función de borde,
-- hecho aquí como el SQL Editor (como en p1-pruebas). Con SQL dinámico: sin
-- p1 estas funciones existen y no se llaman.
--   c11_p1_montar: el candado del casado primero (el orden de la app) y los
--     avisos de prueba aceptados, solo dentro de la prueba.
--   c11_enlace: el enlace de pago de una factura (preparar, «Stripe lo
--     crea», guardarlo). Devuelve lo que p1 preparó (centavos, metadata…).
--   c11_foto: la foto de un pago de Stripe por ese enlace (plink_<lo que
--     sigue a pi_>), con el medio (ach | tarjeta) y los centavos que se digan.
--   c11_cobro: las líneas del asiento del cobro que p1 puso por un pago:
--     «stripe 1111.11 | cxc -1111.11 (la factura)».
create or replace function pg_temp.c11_p1_montar() returns void language plpgsql as $$
begin
  perform pg_temp.c11_ser('editor');
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  execute 'update public.stripe_config set acepta_prueba = true, modo = ''prueba'' where id = 1';
end $$;
create or replace function pg_temp.c11_enlace(p_factura bigint, p_plink text, p_con_retencion boolean default false) returns jsonb
language plpgsql as $$
declare
  v jsonb;
begin
  perform pg_temp.c11_ser('editor');
  execute 'select public.fn_stripe_enlace_preparar($1, $2, ''prueba'', $3, false)' into v
    using p_factura, pg_temp.c11('dueno')::uuid, p_con_retencion;
  execute 'select public.fn_stripe_enlace_creado($1, $2)'
    using (v->>'enlace')::uuid,
          jsonb_build_object('id', p_plink, 'url', 'https://buy.stripe.com/test_' || p_plink, 'livemode', false, 'metadata', v->'metadata');
  return v;
end $$;
create or replace function pg_temp.c11_foto(p_pi text, p_estado text, p_centavos bigint, p_medio text) returns jsonb
language plpgsql as $$
declare
  v_meta  jsonb;
  v_plink text;
begin
  execute 'select jsonb_build_object(''mxp'', ''p1'', ''enlace'', e.id::text, ''factura_id'', e.factura_id::text, ''factura'', e.factura_num, '
       || '''retencion'', case when e.con_retencion then ''si'' else ''no'' end), e.plink from public.stripe_enlaces e where e.plink = $1'
     into v_meta, v_plink using 'plink_' || substr(p_pi, 4);
  return jsonb_build_object(
    'pi', p_pi, 'visto_el', clock_timestamp(), 'estado', p_estado, 'monto', p_centavos,
    'recibido', case when p_estado = 'succeeded' then p_centavos else 0 end, 'moneda', 'usd', 'livemode', false,
    'creado', extract(epoch from now())::bigint,
    'metadata', coalesce(v_meta, '{}'::jsonb), 'plink', v_plink,
    'sesion', 'cs_' || substr(p_pi, 4), 'sesion_completa', true, 'medio', p_medio,
    'cargo', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
    'fecha_exito', case when p_estado = 'succeeded' then pg_temp.c11('hoy') end,
    'cargos', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                'id', case when p_medio = 'ach' then 'py_' else 'ch_' end || substr(p_pi, 4),
                'estado', case p_estado when 'succeeded' then 'succeeded' when 'requires_payment_method' then 'failed' else 'pending' end,
                'medio', p_medio, 'bt', 'txn_' || p_pi, 'creado', extract(epoch from now())::bigint, 'monto', p_centavos))),
    'reembolsos', '[]'::jsonb, 'disputas', '[]'::jsonb, 'ultimo_error', null::jsonb);
end $$;
create or replace function pg_temp.c11_cobro(p_pi text) returns text language plpgsql as $$
declare
  v text;
begin
  execute $q$
    select coalesce(string_agg(format('%s %s%s',
             case when l.cuenta = (select c.cuenta_puente from public.stripe_config c where c.id = 1) then 'stripe'
                  when l.cuenta = public.fn_emision_cuenta('cxc') then 'cxc'
                  when l.cuenta = public.fn_emision_cuenta('retencion_cxc') then 'ret'
                  when k.tipo in ('ingreso', 'otro_ingreso') then 'INGRESO' else l.cuenta end,
             l.monto,
             case when l.partida_tabla = 'facturas' then ' (la factura)' when l.partida_tabla = 'cobros' then ' (anticipo de la obra)' else '' end),
             ' | ' order by l.orden), 'sin asiento')
      from public.stripe_pagos s
      join public.cobros c on c.id = s.cobro_id
      join public.asiento_lineas l on l.asiento_id = c.contabilizado_en
      join public.cuentas k on k.codigo = l.cuenta
     where s.pi = $1 $q$ into v using p_pi;
  return v;
end $$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, las ocho tablas (con emision_soltados), las
--    vistas, las 37 funciones por su nombre exacto, los ajustes (una fila,
--    con un formato de número que vale) y cada objeto con su comentario
--    «c11: …».
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 8 tablas | 4 vistas | 37 funciones (37 nombres) | sin comentario c11: ninguno | '
                'ajustes: 1 fila, id 1, con un formato de número que vale';
begin
  begin
    perform pg_temp.c11_ser('editor');
    v_pre := coalesce(fn_emision_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c11_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c11_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and pg_temp.c11_es_suya(proname);
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c11_tablas()) or c.relname = any (pg_temp.c11_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c11: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c11_es_suya(p.proname)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c11: %') x;
    select format('%s fila, id %s, con un formato de número que %s', count(*), min(c.id),
                  case when bool_and(c.serie_formato ~ '^[A-Z0-9]{1,8}-AAAA-NNNN$') then 'vale' else 'NO vale' end)
      into v_cfg from emision_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c11: %s | ajustes: %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 8 tablas, 4 vistas, las 37 funciones por su nombre exacto, los ajustes (una fila) y cada objeto con su comentario «c11: …»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c3 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c11
--    que no lleva su comentario (no es de c11: no se pisa); una vista ajena
--    colgada de una vista de c11 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin fn_factura_anular: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    -- (desde la app no se instala nada: la función no está en la API)
    perform pg_temp.c11_ser('dueno');
    begin
      v_a := coalesce(fn_emision_precondiciones(), 'nada');
    exception when others then v_a := sqlstate;
    end;
    perform pg_temp.c11_ser('editor');
    begin
      drop function public.fn_factura_anular(bigint, text, date);
      v_b := coalesce(fn_emision_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_emision_pago(uuid) is 'otra cosa';
      v_c := coalesce(fn_emision_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c11_prueba_ajena as select o.proyecto_id from public.v_emision_obras o;
      v_d := coalesce(fn_emision_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin fn_factura_anular: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%fn_factura_anular(bigint,text,date)%' then 'la nombra' else v_b end,
                    case when v_c like '%sin ser de c11%' and v_c like '%fn_emision_pago(uuid)%' and v_c like '%No lo piso%'
                         then 'la nombra y no la pisa' else v_c end,
                    case when v_d like '%c11_prueba_ajena%' and v_d like '%depende(n) de las vistas de c11%' then 'la nombra' else v_d end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se llaman (42501); sin una función de c3 la nombran; una función con nombre de c11 sin su comentario no se pisa; una vista ajena colgada de las de c11 se dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. La API: las de la pantalla, solo authenticated; las internas, nadie;
--    anon y service_role no ejecutan ni leen nada; EL EQUIPO (una persona de
--    prueba, rol campo), con una factura emitida y su PDF en el bucket,
--    recibe 42501 de las diez funciones de la pantalla y cero filas de las
--    ocho tablas, las cuatro vistas, las seis auxiliares de lectura y el
--    bucket;
--    el dueño entra y ve.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_fid bigint; v_num text;
  v_api text; v_sin text; v_anon text; v_srv text; v_n int := 0; v_filas bigint := 0; v_k bigint; v_vacio text; v_due text; v_sube text;
  v_esp text := 'pantalla mal: ninguna | internas con API: ninguna | anon 42501 y 42501 | service_role 42501 y 42501 | '
                'equipo: 10 de 10 funciones 42501, 0 filas en 8 tablas, 4 vistas, 6 auxiliares y el bucket, lo demás vacío, y no sube al '
                'bucket | dueño: su factura, 1 documento de prueba, 4 obras de prueba, 16 controles y 1 fila de estado';
begin
  if pg_temp.c11_omitir(3, 'la API por rol', v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint; v_num := v_r->>'numero';
    if pg_temp.c11('hay_storage') = 'true' then
      execute 'insert into storage.objects (bucket_id, name, metadata) values (''facturas'', $1, ''{"size": 1234}''::jsonb)'
        using extract(year from pg_temp.c11('hoy')::date)::int || '/' || v_num || '/c11-prueba-3.pdf';
    end if;
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_emision_config', 'fn_emision_obra', 'fn_emision_borrador', 'fn_emision_documento', 'fn_emision_descartar',
                         'fn_emision_emitir', 'fn_emision_anular', 'fn_emision_pago', 'fn_emision_pdf', 'fn_emision_envio')
       and not (has_function_privilege('authenticated', p.oid, 'execute')
                and not has_function_privilege('anon', p.oid, 'execute')
                and not has_function_privilege('service_role', p.oid, 'execute'));
    -- las internas: nadie de la API
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_emision_precondiciones', 'fn_emision_pegado', 'fn_emision_guarda', 'fn_emision_numerar')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    -- anon: ni ejecuta ni lee
    perform pg_temp.c11_ser('anon');
    begin perform fn_emision_documento(v_doc); v_anon := 'entró'; exception when others then v_anon := sqlstate; end;
    begin perform count(*) from v_emision_estado; v_anon := v_anon || ' y leyó'; exception when others then v_anon := v_anon || ' y ' || sqlstate; end;
    perform pg_temp.c11_ser('service_role');
    begin perform fn_emision_config('{}'::jsonb); v_srv := 'entró'; exception when others then v_srv := sqlstate; end;
    begin perform count(*) from emision_documentos; v_srv := v_srv || ' y leyó'; exception when others then v_srv := v_srv || ' y ' || sqlstate; end;
    -- el equipo (rol campo)
    perform pg_temp.c11_ser('p1');
    begin perform fn_emision_config('{}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_obra(jsonb_build_object('proyecto_id', 'c11-prueba-a', 'retencion_pct', 5)); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002)); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_documento(v_doc); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_descartar(v_doc); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_emitir(v_doc, 'x'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_anular(v_doc, 'no es mía'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_pago(v_doc); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_pdf(v_doc, '{}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_emision_envio(v_doc, '{}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    select count(*) into v_k from emision_config;        v_filas := v_filas + v_k;
    select count(*) into v_k from emision_obras;         v_filas := v_filas + v_k;
    select count(*) into v_k from emision_documentos;    v_filas := v_filas + v_k;
    select count(*) into v_k from emision_lineas;        v_filas := v_filas + v_k;
    select count(*) into v_k from emision_serie;         v_filas := v_filas + v_k;
    select count(*) into v_k from emision_pdfs;          v_filas := v_filas + v_k;
    select count(*) into v_k from emision_envios;        v_filas := v_filas + v_k;
    select count(*) into v_k from emision_soltados;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_emision_estado;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_emision_documentos;  v_filas := v_filas + v_k;
    select count(*) into v_k from v_emision_obras;       v_filas := v_filas + v_k;
    select count(*) into v_k from v_emision_control;     v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_enlaces();  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_pagos();    v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_storage();  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_retenido('c11-prueba-a'); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_factura_de_hito(-1110000001); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_emision_control();  v_filas := v_filas + v_k;
    if pg_temp.c11('hay_storage') = 'true' then
      begin
        execute 'select count(*) from storage.objects where bucket_id = ''facturas''' into v_k;
        v_filas := v_filas + v_k;
      exception when insufficient_privilege then null;   -- (ni permiso para mirar: tampoco ve)
      end;
      begin
        execute 'insert into storage.objects (bucket_id, name, owner) values (''facturas'', ''c11-prueba-3-equipo.pdf'', $1)'
          using pg_temp.c11('p1')::uuid;
        v_sube := 'SUBE al bucket';
      exception when others then v_sube := 'no sube al bucket';
      end;
    else
      v_sube := 'no sube al bucket';
    end if;
    v_vacio := case when fn_emision_revisar(v_doc) = '[]'::jsonb and fn_emision_visto(v_doc) is null
                         and fn_emision_contenido(v_doc, null, null, null) is null
                         and fn_emision_retencion_de('c11-prueba-a') = jsonb_build_object('pct', 0, 'origen', 'ninguna')
                         and fn_emision_destinatario('c11-prueba-a') = '{}'::jsonb
                         and (select s.cxc = 0 and s.retencion = 0 from fn_emision_saldo(v_fid) s)
                    then 'lo demás vacío' else 'algo le contestan las auxiliares' end;
    -- el dueño: entra y ve
    perform pg_temp.c11_ser('dueno');
    select format('%s, %s documento de prueba, %s obras de prueba, %s controles y %s fila de estado',
                  case when fn_emision_documento(v_doc)->'documento'->>'numero' = v_num then 'su factura' else 'sin su factura' end,
                  (select count(*) from v_emision_documentos d where d.proyecto_id like 'c11-prueba-%'),
                  (select count(*) from v_emision_obras o where o.proyecto_id like 'c11-prueba-%'),
                  (select count(*) from v_emision_control), (select count(*) from v_emision_estado))
      into v_due;
    perform pg_temp.c11_ser('editor');
    v_obt := format('pantalla mal: %s | internas con API: %s | anon %s | service_role %s | equipo: %s de 10 funciones 42501, %s filas en 8 '
                    'tablas, 4 vistas, 6 auxiliares y el bucket, %s, y %s | dueño: %s',
                    v_api, v_sin, v_anon, v_srv, v_n, v_filas, v_vacio, v_sube, v_due);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las de la pantalla solo authenticated y las internas sin API; anon y service_role 42501 (ni ejecutan ni leen); EL EQUIPO (rol campo), con una factura emitida y su PDF en el bucket, 42501 en las diez funciones y cero filas en tablas, vistas, auxiliares y bucket; el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. El catálogo: UNA sola SECURITY DEFINER (la del número: devuelve
--    trigger y nadie la ejecuta); ningún objeto de c11 con un prefijo de otra
--    capa ni de la otra sesión; RLS con su policy de lectura en cada tabla y
--    ni una policy de más; vistas security_invoker que no fijan las columnas
--    que c2-pruebas reescribe ni cuelgan de vistas de otras capas; y
--    «permisos» (c2), «protecciones del banco» (c6) y «protecciones de c4» en
--    verde con c11 pegado.
do $$
declare
  v_obt text; v_def text; v_pref text; v_rls text; v_pol text; v_vis text; v_fij int; v_dep text;
  v_c2 text; v_c6 text := 'verde'; v_c4 text := 'verde';
  v_esp text := 'definer: solo fn_emision_numerar (de trigger, sin EXECUTE para nadie) | prefijos ajenos: ninguno | sin rls o policy: ninguna | '
                'policies que no son las suyas: ninguna (21) | sin security_invoker: ninguna | columnas de c2 fijadas: 0 | vistas de otras '
                'capas debajo: ninguna | c2 permisos verde | c6 protecciones verde | c4 protecciones verde';
begin
  begin
    perform pg_temp.c11_ser('editor');
    select coalesce(string_agg(p.proname || case when p.prorettype = 'trigger'::regtype
                                                       and not has_function_privilege('authenticated', p.oid, 'execute')
                                                       and not has_function_privilege('anon', p.oid, 'execute')
                                                       and not has_function_privilege('service_role', p.oid, 'execute')
                                                      and not has_function_privilege('public', p.oid, 'execute')
                                                 then ' (de trigger, sin EXECUTE para nadie)' else ' (MAL: se puede llamar)' end, ', '
                               order by p.proname), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and pg_temp.c11_es_suya(p.proname);
    select coalesce(string_agg(x.que, ', '), 'ninguno') into v_pref
      from (select p.proname::text as que from pg_proc p
             where p.pronamespace = 'public'::regnamespace and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c11: %'
               and (p.proname ~ '^fn_(banco|puente|estados|stripe|plaid|contador|cierre|costos|reporte|horas|jornal|margen|cobro|factura|anticipo|doc|qb)_'
                    or p.proname ~ '^fn_reparto_fase' or p.proname !~ '^fn_emision_')
            union all
            select c.relname::text from pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm')
               and coalesce(obj_description(c.oid, 'pg_class'), '') like 'c11: %'
               and c.relname !~ '^(emision_|v_emision_)') x;
    select coalesce(string_agg(t.tablename, ', '), 'ninguna') into v_rls
      from pg_tables t
     where t.schemaname = 'public' and t.tablename = any (pg_temp.c11_tablas())
       and (not t.rowsecurity
            or not exists (select 1 from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t.tablename
                              and pl.cmd = 'SELECT' and pl.qual ~ 'es_dueno'));
    -- las policies justas: leer (las 8), editar (ajustes, obras, documentos, líneas), añadir (todas menos los ajustes) y
    -- borrar (solo un borrador y sus líneas): 8 + 4 + 7 + 2 = 21
    select coalesce(string_agg(pl.tablename || '.' || pl.policyname, ', ' order by 1)
                      filter (where not ((pl.policyname = pl.tablename || '_dueno' and pl.cmd = 'SELECT')
                                         or (pl.policyname = pl.tablename || '_dueno_edita' and pl.cmd = 'UPDATE'
                                             and pl.tablename in ('emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas'))
                                         or (pl.policyname = pl.tablename || '_dueno_anade' and pl.cmd = 'INSERT'
                                             and pl.tablename <> 'emision_config')
                                         or (pl.policyname = pl.tablename || '_dueno_borra' and pl.cmd = 'DELETE'
                                             and pl.tablename in ('emision_documentos', 'emision_lineas')))
                                    or pl.roles <> '{authenticated}'::name[]), 'ninguna') || format(' (%s)', count(*))
      into v_pol
      from pg_policies pl
     where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c11_tablas());
    select coalesce(string_agg(c.relname, ', '), 'ninguna') into v_vis
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (pg_temp.c11_vistas())
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    -- las columnas que c2-pruebas reescribe (ALTER COLUMN TYPE): ninguna vista de c11 las fija
    select count(*) into v_fij
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
     where d.refclassid = 'pg_class'::regclass and v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c11_vistas())
       and ((d.refobjid = 'public.cuentas'::regclass and a.attname in ('activa', 'saldo_normal'))
            or (d.refobjid = 'public.periodos'::regclass and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cadena_al_cerrar')));
    -- ninguna vista de c11 lee una vista de otra capa (se rehacen al volver a pegar su archivo)
    select coalesce(string_agg(distinct v.relname || ' → ' || b.relname, ', '), 'ninguna') into v_dep
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_class b on d.refclassid = 'pg_class'::regclass and b.oid = d.refobjid
     where v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c11_vistas())
       and b.relkind in ('v', 'm') and b.oid <> v.oid and not (b.relname = any (pg_temp.c11_vistas()));
    v_c2 := pg_temp.c11_permisos();
    if pg_temp.c11('hay_c6') = 'true' then
      execute $q$ select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end
                    from public.fn_banco_control('hoy', array['cuadre: el otro lado de cada casado'])
                   where vista = 'cuadre: protecciones del banco' $q$ into v_c6;
    end if;
    if pg_temp.c11('hay_c4') = 'true' then
      execute $q$ select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end
                    from public.fn_estados_control('hoy', array['v_saldos_dinero'])
                   where vista = 'cuadre: protecciones de c4' $q$ into v_c4;
    end if;
    v_obt := format('definer: solo %s | prefijos ajenos: %s | sin rls o policy: %s | policies que no son las suyas: %s | sin security_invoker: %s | '
                    'columnas de c2 fijadas: %s | vistas de otras capas debajo: %s | c2 permisos %s | c6 protecciones %s | c4 protecciones %s',
                    v_def, v_pref, v_rls, v_pol, v_vis, v_fij, v_dep, v_c2, coalesce(v_c6, 'sin su fila'), coalesce(v_c4, 'sin su fila'));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: una sola SECURITY DEFINER (la del número: de trigger, sin EXECUTE), ningún prefijo de otra capa ni de la otra sesión, RLS y las policies justas, vistas security_invoker que no fijan columnas de c2 ni leen vistas de otras capas; c2 «permisos», c6 y c4 «protecciones» en verde con c11 pegado',
    v_esp,
    v_obt || case when pg_temp.c11('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c11: ' || pg_temp.c11('ajenas_permisos') || ')' else '' end
          || case when pg_temp.c11('hay_c6') <> 'true' then ' (c6 no está en esta base: no se mira)' else '' end
          || case when pg_temp.c11('hay_c4') <> 'true' then ' (c4 no está en esta base: no se mira)' else '' end,
    v_obt = v_esp);
end $$;

-- 5. La guarda: las tablas de c11 solo las escriben sus funciones. A mano,
--    MX003: el dueño por la API (la policy le deja; la marca no), el SQL
--    Editor sin la marca, y —con la marca— lo emitido ni se edita ni se
--    borra: solo se le apunta su anulación, una vez. Lo soltado (qué
--    factura anulada dejó de figurar en qué hito) tampoco se escribe a mano,
--    y una vez apuntado ni se cambia ni se borra.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_bor uuid;
  a text; b text; c text;
  v_esp text := 'el dueño por la API: crear a mano MX003, los ajustes a mano MX003, borrar un borrador a mano MX003, borrar la serie 42501, '
                'cambiar una emitida MX003, apuntar algo soltado a mano MX003 | el editor sin la marca: un número MX003, truncar MX003, '
                'borrar los ajustes MX003, algo soltado MX003 | con la marca: cambiar una emitida MX003, borrarla MX003, sus líneas MX003 '
                'y MX003, su número MX003 y MX003, los ajustes no se borran MX003, la anulación se apunta una vez (entró) y no dos '
                '(MX003), y lo soltado se apunta (entró) y ni se cambia ni se borra (MX003 y MX003)';
begin
  if pg_temp.c11_omitir(5, 'la guarda de las tablas de c11', v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid;
    v_bor := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002))->'documento'->>'id')::uuid;
    a := format('crear a mano %s, los ajustes a mano %s, borrar un borrador a mano %s, borrar la serie %s, cambiar una emitida %s, '
                'apuntar algo soltado a mano %s',
                pg_temp.c11_cod($q$ insert into emision_documentos (forma, proyecto_id) values ('tm', 'c11-prueba-a') $q$),
                pg_temp.c11_cod($q$ update emision_config set ach = false where id = 1 $q$),
                pg_temp.c11_cod(format('delete from emision_documentos where id = %L', v_bor)),
                pg_temp.c11_cod('delete from emision_serie'),
                pg_temp.c11_cod(format('update emision_documentos set notas = ''x'' where id = %L', v_doc)),
                pg_temp.c11_cod(format('insert into emision_soltados (factura_id, num, hito_id, documento_id) values (%s, ''ZZ-X'', -1110000001, %L)',
                                       v_r->>'factura_id', v_doc)));
    b := format('un número %s, truncar %s, borrar los ajustes %s, algo soltado %s',
                pg_temp.c11_cod(format('insert into emision_serie (anio, documento_id) values (2026, %L)', v_bor), 'editor'),
                pg_temp.c11_cod('truncate emision_envios', 'editor'),
                pg_temp.c11_cod('delete from emision_config', 'editor'),
                pg_temp.c11_cod(format('insert into emision_soltados (factura_id, num, hito_id, documento_id) values (%s, ''ZZ-X'', -1110000001, %L)',
                                       v_r->>'factura_id', v_doc), 'editor'));
    -- con la marca puesta a mano (el dueño de la base puede): lo emitido, ni así
    perform set_config('mx_emision.escribe', 'emision_documentos', true);
    c := format('cambiar una emitida %s, borrarla %s',
                pg_temp.c11_cod(format('update emision_documentos set notas = ''x'' where id = %L', v_doc), 'editor'),
                pg_temp.c11_cod(format('delete from emision_documentos where id = %L', v_doc), 'editor'));
    perform set_config('mx_emision.escribe', 'emision_lineas', true);
    c := c || format(', sus líneas %s y %s',
                pg_temp.c11_cod(format('update emision_lineas set descripcion = ''x'' where documento_id = %L', v_doc), 'editor'),
                pg_temp.c11_cod(format('delete from emision_lineas where documento_id = %L', v_doc), 'editor'));
    perform set_config('mx_emision.escribe', 'emision_serie', true);
    c := c || format(', su número %s y %s',
                pg_temp.c11_cod(format('update emision_serie set numero = ''X'' where documento_id = %L', v_doc), 'editor'),
                pg_temp.c11_cod(format('delete from emision_serie where documento_id = %L', v_doc), 'editor'));
    perform set_config('mx_emision.escribe', 'emision_config', true);
    c := c || format(', los ajustes no se borran %s', pg_temp.c11_cod('delete from emision_config', 'editor'));
    perform set_config('mx_emision.escribe', 'emision_documentos', true);
    c := c || format(', la anulación se apunta una vez (%s) y no dos (%s)',
                pg_temp.c11_cod(format('update emision_documentos set anulado_el = now(), anulado_motivo = ''c11-pruebas'' where id = %L', v_doc), 'editor'),
                pg_temp.c11_cod(format('update emision_documentos set anulado_motivo = ''otra vez'' where id = %L', v_doc), 'editor'));
    perform set_config('mx_emision.escribe', 'emision_soltados', true);
    c := c || format(', y lo soltado se apunta (%s) y ni se cambia ni se borra (%s y %s)',
                pg_temp.c11_cod(format('insert into emision_soltados (factura_id, num, hito_id, documento_id) values (%s, ''ZZ-X'', -1110000001, %L)',
                                       v_r->>'factura_id', v_doc), 'editor'),
                pg_temp.c11_cod('update emision_soltados set num = ''ZZ-Y'' where num = ''ZZ-X''', 'editor'),
                pg_temp.c11_cod('delete from emision_soltados where num = ''ZZ-X''', 'editor'));
    perform set_config('mx_emision.escribe', '', true);
    v_obt := format('el dueño por la API: %s | el editor sin la marca: %s | con la marca: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda: a mano no se escribe (MX003: el dueño por la API y el SQL Editor sin la marca), la serie no se borra por la API (42501), y con la marca una factura emitida, sus líneas y su número ni se editan ni se borran; su anulación se apunta una sola vez; lo soltado se apunta y ni se cambia ni se borra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. Los ajustes (fn_emision_config): cambia lo que se le dice y nada más,
--    y sus frenos. LA TARJETA NO SE ENCIENDE: el porcentaje no se deja poner
--    (MX008, y dice por qué, en llano: se enciende cuando el sistema de
--    cobros sepa registrar el recargo; por ahora, solo ACH).
do $$
declare
  v_obt text; v_r jsonb; v_b jsonb; v_c0 jsonb; v_c1 jsonb; v_x text; v_ing text; v_no text;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text;
  v_esp text := 'clave desconocida 22023 | corte: mal escrito 22007, antes del libro MX008 | formato en minúsculas 22023 | términos 121 días '
                'MX005, aviso de PDF -1 MX005 | empresa: clave desconocida 22023, no es un objeto 22023 | ach que no es true o false 22023 | '
                'tarjeta: 3 % MX008 (dice que se enciende cuando el sistema de cobros sepa registrar el recargo, y que por ahora es solo '
                'ACH), 11 % MX005, null entra y queda vacía, lista: false, y los ajustes lo dicen con ese mismo texto | cuenta del recargo: '
                'inventada MX004, una que no es de ingreso ni de gasto MX004, una de ingreso sin obra entra | cambia solo lo que se le dice: '
                'términos 30, vence a 30 días, y lo demás igual | con una factura emitida: el corte no se pone después MX008, el formato no '
                'cambia MX008 | el número se escribe: MXP-2027-0007, ZZ9-2031-0999 y, pasado el 9999, MXP-2027-12345';
begin
  if pg_temp.c11_omitir(6, 'los ajustes y sus frenos', v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    a := pg_temp.c11_cod($q$ select fn_emision_config('{"moneda": "usd"}') $q$);
    b := format('mal escrito %s, antes del libro %s',
                pg_temp.c11_cod($q$ select fn_emision_config('{"corte": "01/01/2027"}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_config('{"corte": "2026-09-30"}') $q$));
    c := pg_temp.c11_cod($q$ select fn_emision_config('{"serie_formato": "mxp-AAAA-NNNN"}') $q$);
    d := format('términos 121 días %s, aviso de PDF -1 %s',
                pg_temp.c11_cod($q$ select fn_emision_config('{"terminos_dias": 121}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_config('{"pdf_dias": -1}') $q$));
    e := format('clave desconocida %s, no es un objeto %s',
                pg_temp.c11_cod($q$ select fn_emision_config('{"empresa": {"nombre": "ZZ", "rfc": "x"}}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_config('{"empresa": "ZZ Electric"}') $q$));
    f := pg_temp.c11_cod($q$ select fn_emision_config('{"ach": "si"}') $q$);
    v_x := pg_temp.c11_err($q$ select fn_emision_config('{"tarjeta_pct": 3}') $q$);
    perform pg_temp.c11_ser('dueno');
    v_r := fn_emision_config('{"tarjeta_pct": null}'::jsonb);
    perform pg_temp.c11_ser('editor');
    g := format('3 %% %s, 11 %% %s, null %s, lista: %s',
                case when v_x like 'MX008: La tarjeta está apagada: se enciende cuando el sistema de cobros sepa registrar el recargo%'
                          and v_x like '%solo por cuenta de banco (ACH)%' and v_x !~ 'fn_|p1'
                     then 'MX008 (dice que se enciende cuando el sistema de cobros sepa registrar el recargo, y que por ahora es solo ACH)'
                     else v_x end,
                pg_temp.c11_cod($q$ select fn_emision_config('{"tarjeta_pct": 11}') $q$),
                case when v_r->>'tarjeta_pct' is null then 'entra y queda vacía' else 'dejó ' || (v_r->>'tarjeta_pct') end,
                v_r->>'tarjeta_lista')
         || case when v_x = 'MX008: ' || (v_r->>'tarjeta_texto') then ', y los ajustes lo dicen con ese mismo texto' else ', y los ajustes NO lo dicen' end;
    select k.codigo into v_ing from cuentas k
     where k.tipo in ('ingreso', 'otro_ingreso') and k.activa and k.imputable and k.regla_obra <> 'obligatoria' order by k.codigo limit 1;
    select k.codigo into v_no from cuentas k
     where k.tipo not in ('ingreso', 'otro_ingreso', 'gasto', 'otro_gasto') and k.activa and k.imputable order by k.codigo limit 1;
    h := format('inventada %s, una que no es de ingreso ni de gasto %s, una de ingreso sin obra %s',
                pg_temp.c11_cod($q$ select fn_emision_config('{"cuenta_recargo": "ZZ99"}') $q$),
                pg_temp.c11_cod(format('select fn_emision_config(%L)', jsonb_build_object('cuenta_recargo', v_no)::text)),
                case when v_ing is null then 'entra'   -- (este plan de cuentas no tiene ninguna: no hay qué probar)
                     else replace(pg_temp.c11_cod(format('select fn_emision_config(%L)', jsonb_build_object('cuenta_recargo', v_ing)::text)),
                                  'entró', 'entra') end);
    -- cambia solo lo que se le dice
    select to_jsonb(k) into v_c0 from emision_config k where k.id = 1;
    perform pg_temp.c11_ser('dueno');
    v_c1 := fn_emision_config('{"terminos_dias": 30}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    i := format('términos %s, %s, y lo demás %s', v_c1->>'terminos_dias',
                case when (v_b->'vista_previa'->>'vence')::date = pg_temp.c11('hoy')::date + 30
                          and v_b->'vista_previa'->'terminos'->>'etiqueta' = 'Net 30'
                     then 'vence a 30 días' else 'no vence a 30 días' end,
                case when (v_c1 - 'terminos_dias' - 'actualizado' - 'actualizado_por' - 'tarjeta_lista' - 'tarjeta_texto')
                          = (v_c0 - 'terminos_dias' - 'actualizado' - 'actualizado_por') then 'igual' else 'CAMBIÓ' end);
    -- con una factura emitida
    perform pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    j := format('el corte no se pone después %s, el formato no cambia %s',
                pg_temp.c11_cod(format('select fn_emision_config(%L)', jsonb_build_object('corte', (pg_temp.c11('hoy')::date + 1)::text)::text)),
                pg_temp.c11_cod($q$ select fn_emision_config('{"serie_formato": "ZZ-AAAA-NNNN"}') $q$));
    v_obt := format('clave desconocida %s | corte: %s | formato en minúsculas %s | %s | empresa: %s | ach que no es true o false %s | tarjeta: %s | '
                    'cuenta del recargo: %s | cambia solo lo que se le dice: %s | con una factura emitida: %s | el número se escribe: %s, %s y, '
                    'pasado el 9999, %s', a, b, c, d, e, f, g, h, i, j,
                    fn_emision_numero('MXP-AAAA-NNNN', 2027, 7), fn_emision_numero('ZZ9-AAAA-NNNN', 2031, 999),
                    fn_emision_numero('MXP-AAAA-NNNN', 2027, 12345));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'los ajustes (fn_emision_config): una clave desconocida 22023; el corte bien escrito y no antes del libro; el formato del número; los días; la empresa; LA TARJETA NO SE ENCIENDE (su porcentaje, MX008 y dice por qué); la cuenta del recargo tiene que servir (MX004); cambia solo lo que se le dice; con una factura emitida ni el corte se pone después ni el formato cambia; y cómo se escribe el número (con ceros hasta cuatro cifras; pasado el 9999, entero)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. EL CORTE. Antes del corte v_emision_estado dice QuickBooks: el borrador
--    se prepara y se mira (para probar) y emitir NO (MX008, en llano; no
--    gasta número ni deja factura). El día del corte dice la app y se emite.
--    Sin los datos de la empresa o sin el «How to pay», tampoco.
do $$
declare
  v_obt text; v_e record; v_b jsonb; v_doc uuid; v_x text; v_n0 bigint; v_r jsonb; v_sig text;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'EL CORTE: antes, v_emision_estado dice QuickBooks, el borrador se prepara y emitir da MX008 en llano (sin gastar número ni '
                'dejar factura); el día del corte dice la app y se emite; sin los datos de la empresa o el «How to pay», tampoco se emite';
  v_esp text := 'antes del corte: por quickbooks, faltan 10 días, no se puede emitir | el borrador sí se prepara, y dice por qué no se emite | '
                'emitir MX008 (todavía no se factura por la app) y no gasta número ni deja factura | el día del corte: por la app, faltan 0 '
                'días, se puede emitir, el siguiente número es el de la serie | sin los datos de la empresa ni el «How to pay»: falta '
                '{empresa,como_pagar}, emitir MX008 | con todo: emite, con su número';
begin
  if pg_temp.c11_omitir(7, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    begin
      perform fn_emision_config(jsonb_build_object('corte', (pg_temp.c11('hoy')::date + 10)::text));
    exception when sqlstate 'MX008' then
      v_obt := 'omitida: esta base ya tiene facturas emitidas por la app y el corte no se puede poner en el futuro para probarlo';
      raise exception using errcode = 'MXT00';
    end;
    perform pg_temp.c11_ser('dueno');
    select * into v_e from v_emision_estado;
    a := format('por %s, faltan %s días, %s', v_e.camino, v_e.dias_para_el_corte,
                case when not v_e.puede_emitir and not v_e.por_la_app and v_e.texto like 'Hasta el %QuickBooks%' then 'no se puede emitir'
                     else 'MAL: ' || v_e.texto end);
    v_n0 := pg_temp.c11_contador();
    v_b := fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    v_doc := (v_b->'documento'->>'id')::uuid;
    b := case when v_b->'documento'->>'estado' = 'borrador' and not (v_b->>'puede_emitir')::boolean
                   and v_b->>'por_que_no' like 'Todavía no se factura por la app: hasta el %QuickBooks%'
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'antes_del_corte' and (x->>'frena')::boolean)
              then 'el borrador sí se prepara, y dice por qué no se emite' else 'MAL: ' || left(v_b::text, 300) end;
    begin
      perform fn_emision_emitir(v_doc, v_b->>'visto');
      v_x := 'emitió';
    exception when others then v_x := sqlstate || ': ' || sqlerrm;
    end;
    c := format('emitir %s y %s',
                case when v_x like 'MX008: Todavía no se factura por la app%' then 'MX008 (todavía no se factura por la app)' else v_x end,
                case when pg_temp.c11_contador() = v_n0 and not exists (select 1 from facturas f where f.hito_id = -1110000001)
                          and (select x.estado from emision_documentos x where x.id = v_doc) = 'borrador'
                     then 'no gasta número ni deja factura' else 'DEJÓ algo' end);
    -- el día del corte
    perform fn_emision_config(jsonb_build_object('corte', pg_temp.c11('hoy')));
    v_sig := pg_temp.c11_num(1);
    select * into v_e from v_emision_estado;
    d := format('por la %s, faltan %s días, %s, el siguiente número %s', v_e.camino, v_e.dias_para_el_corte,
                case when v_e.puede_emitir and v_e.por_la_app and v_e.falta = '{}' then 'se puede emitir' else 'NO se puede emitir' end,
                case when v_e.siguiente_numero = v_sig then 'es el de la serie' else 'es ' || v_e.siguiente_numero || ' y debía ser ' || v_sig end);
    -- sin los datos de la casa
    perform fn_emision_config('{"empresa": {}, "como_pagar": ""}'::jsonb);
    select * into v_e from v_emision_estado;
    begin
      perform fn_emision_emitir(v_doc, fn_emision_documento(v_doc)->>'visto');
      v_x := 'emitió';
    exception when others then v_x := sqlstate;
    end;
    e := format('falta %s, emitir %s', v_e.falta, v_x);
    perform fn_emision_config(jsonb_build_object('empresa', jsonb_build_object('nombre', 'ZZ Electric C11 PRUEBA, Inc.'),
                                                 'como_pagar', 'Check payable to ZZ Electric C11 PRUEBA, Inc.'));
    v_r := fn_emision_emitir(v_doc, fn_emision_documento(v_doc)->>'visto');
    perform pg_temp.c11_ser('editor');
    f := case when v_r->>'numero' = v_sig and v_r->>'estado' = 'emitida' then 'emite, con su número' else 'MAL: ' || v_r::text end;
    v_obt := format('antes del corte: %s | %s | %s | el día del corte: %s | sin los datos de la empresa ni el «How to pay»: %s | con todo: %s',
                    a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 8. EL BORRADOR DE UN HITO: uno por hito (tocar dos veces abre el mismo),
--    con su línea (el título del hito, su condición, su monto), a quién se
--    factura (el de la obra, o el que se escriba), sus notas; refrescar
--    conserva el texto; si el hito cambia, lo dice y se refresca. El hito
--    cobrado, el ya facturado y el que no tiene monto, no. Y tirarlo.
do $$
declare
  v_obt text; v_b jsonb; v_b2 jsonb; v_doc uuid; v_v1 text; v_x text;
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_nom text := 'EL BORRADOR DE UN HITO: uno por hito, con su línea (título, condición y monto del hito), a quién se factura y sus notas; '
                'refrescar conserva el texto; si el hito cambia lo dice (frena) y se refresca; el hito cobrado, el ya facturado y el sin '
                'monto no se facturan; y se tira sin dejar nada';
  v_esp text := 'nuevo: borrador de la obra Uno por 3333.33, sin retención, al cliente de la obra, una línea (el título, la condición, 1 × '
                '3333.33), se puede emitir, con su visto | otra vez: el mismo | con otro texto, notas y otro pagador: cambia, y el visto '
                'también | al refrescar: el texto y el pagador se quedan | cliente null: el de la obra | el hito pasa a 3400.00: avisa '
                '(hito_cambio, frena), y al refrescar 3400.00 | cobrado MX008, ya facturado MX008 (dice ZZ-900), sin monto MX005 | no existe '
                '22023, sin hito 22023, de otra obra 22023, clave desconocida 22023, forma desconocida 22023 | tirarlo: se va con sus líneas, '
                'y el siguiente es nuevo';
begin
  if pg_temp.c11_omitir(8, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    v_doc := (v_b->'documento'->>'id')::uuid; v_v1 := v_b->>'visto';
    a := case when (v_b->>'nuevo')::boolean and v_b->'documento'->>'estado' = 'borrador' and v_b->'documento'->>'forma' = 'hito'
                   and v_b->'documento'->>'proyecto_id' = 'c11-prueba-a' and v_b->'documento'->>'obra' = 'C11 PRUEBA Uno'
                   and (v_b->'documento'->>'monto')::numeric = 3333.33 and (v_b->'documento'->>'retencion')::numeric = 0
                   and (v_b->'documento'->>'a_pagar')::numeric = 3333.33 and v_b->'documento'->>'retencion_origen' = 'ninguna'
                   and v_b->'documento'->'cliente' = jsonb_build_object('nombre', 'ZZ Cliente Uno', 'direccion', '1 ZZ Test Rd, Testville, FL 00000',
                                                                        'correo', 'zz.uno@c11-pruebas.invalid')
                   and not (v_b->'documento'->>'a_contratista')::boolean and v_b->'documento'->>'numero' is null
                   and jsonb_array_length(v_b->'lineas') = 1
                   and v_b->'lineas'->0->>'tipo' = 'hito' and v_b->'lineas'->0->>'descripcion' = 'C11 PRUEBA Milestone 1'
                   and v_b->'lineas'->0->>'detalle' = 'Due upon passing the rough-in inspection'
                   and (v_b->'lineas'->0->>'cantidad')::numeric = 1 and (v_b->'lineas'->0->>'precio')::numeric = 3333.33
                   and (v_b->'lineas'->0->>'importe')::numeric = 3333.33 and v_b->'lineas'->0->'ref'->>'hito_id' = '-1110000001'
                   and (v_b->>'puede_emitir')::boolean and v_b->>'visto' ~ '^[0-9a-f]{32}$'
              then 'borrador de la obra Uno por 3333.33, sin retención, al cliente de la obra, una línea (el título, la condición, 1 × 3333.33), '
                   'se puede emitir, con su visto'
              else 'MAL: ' || left(v_b::text, 600) end;
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    b := case when not (v_b2->>'nuevo')::boolean and v_b2->'documento'->>'id' = v_doc::text
                   and (select count(*) from emision_documentos x where x.hito_id = -1110000001) = 1 then 'el mismo' else 'OTRO' end;
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'descripcion', 'Rough-in complete', 'detalle', null,
                                                    'notas', 'Thank you for your business.',
                                                    'cliente', jsonb_build_object('nombre', 'ZZ Other Payer', 'atencion', 'ZZ Accounts Payable')));
    c := case when v_b2->'lineas'->0->>'descripcion' = 'Rough-in complete' and v_b2->'lineas'->0->>'detalle' is null
                   and v_b2->'documento'->>'notas' = 'Thank you for your business.'
                   and v_b2->'documento'->'cliente' = jsonb_build_object('nombre', 'ZZ Other Payer', 'atencion', 'ZZ Accounts Payable')
              then 'cambia' else 'NO cambia: ' || left(v_b2::text, 300) end
         || case when v_b2->>'visto' <> v_v1 then ', y el visto también' else ', y el visto NO' end;
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    d := case when v_b2->'lineas'->0->>'descripcion' = 'Rough-in complete' and v_b2->'documento'->'cliente'->>'nombre' = 'ZZ Other Payer'
                   and v_b2->'documento'->>'notas' = 'Thank you for your business.'
              then 'el texto y el pagador se quedan' else 'se PERDIERON' end;
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'cliente', null));
    e := case when v_b2->'documento'->'cliente'->>'nombre' = 'ZZ Cliente Uno' then 'el de la obra' else (v_b2->'documento'->'cliente')::text end;
    -- el hito cambia
    update hitos set monto = 3400 where id = -1110000001;
    perform pg_temp.c11_ser('dueno');
    v_b2 := fn_emision_documento(v_doc);
    f := case when not (v_b2->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b2->'avisos') x where x->>'codigo' = 'hito_cambio' and (x->>'frena')::boolean)
                   and (v_b2->'documento'->>'monto')::numeric = 3333.33
              then 'avisa (hito_cambio, frena)' else 'NO avisa' end;
    v_b2 := fn_emision_borrador(jsonb_build_object('documento', v_doc));
    perform pg_temp.c11_ser('editor');
    f := f || format(', y al refrescar %s', case when (v_b2->>'puede_emitir')::boolean then v_b2->'documento'->>'monto' else 'sigue frenado' end);
    -- los que no se facturan
    update hitos set estado = 'cobrado' where id = -1110000002;
    insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
    values ('c11-prueba-a', 'ZZ-900', pg_temp.c11('hoy')::date, 3333.34, -1110000003, 'emitida');
    update hitos set monto = 0 where id = -1110000005;
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000003}') $q$);
    g := format('cobrado %s, ya facturado %s, sin monto %s',
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000002}') $q$),
                case when v_x like 'MX008:%ya se facturó: factura ZZ-900 del %' then 'MX008 (dice ZZ-900)' else v_x end,
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000005}') $q$));
    g := g || format(' | no existe %s, sin hito %s, de otra obra %s, clave desconocida %s, forma desconocida %s',
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": 999999999999}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito"}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001, "proyecto_id": "c11-prueba-b"}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001, "monto": 5}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "factura", "proyecto_id": "c11-prueba-a"}') $q$));
    -- tirarlo
    perform pg_temp.c11_ser('dueno');
    v_b2 := fn_emision_descartar(v_doc);
    h := case when (v_b2->>'descartado')::boolean and not exists (select 1 from emision_documentos x where x.id = v_doc)
                   and not exists (select 1 from emision_lineas x where x.documento_id = v_doc) then 'se va con sus líneas' else 'NO se va' end;
    v_b2 := fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    perform pg_temp.c11_ser('editor');
    h := h || case when (v_b2->>'nuevo')::boolean and v_b2->'documento'->>'id' <> v_doc::text then ', y el siguiente es nuevo' else ', y el siguiente NO es nuevo' end;
    v_obt := format('nuevo: %s | otra vez: %s | con otro texto, notas y otro pagador: %s | al refrescar: %s | cliente null: %s | el hito pasa a '
                    '3400.00: %s | %s | tirarlo: %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. EL BORRADOR POR PORCENTAJE DEL CONTRATO, con un contrato que no divide
--    (18,500.55): el 33.33 % son 6,166.23; el 50 %, 9,250.28 (la mitad
--    exacta, lejos de cero). Guarda el contrato que usó de base: si el
--    contrato cambia, lo dice (frena) y se refresca. Si con esta se pasa del
--    contrato, avisa y deja. Sin contrato no hay porcentaje.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid;
  a text; b text; c text; d text; e text; f text; g text;
  v_nom text := 'EL BORRADOR POR PORCENTAJE del contrato (18,500.55, que no divide): 33.33 % = 6,166.23 y 50 % = 9,250.28, en numeric; '
                'guarda el contrato de base y, si cambia, lo dice (frena) y se refresca; si se pasa del contrato avisa y deja; sin contrato '
                'no hay porcentaje; y sus frenos';
  v_esp text := 'el 33.33 % de 18500.55: 6166.23, una línea con su texto en inglés, y avisa de los hitos de la obra sin frenar | al 50 %: '
                '9250.28 y su texto | un texto propio se queda al refrescar | el contrato pasa a 20000.00: avisa (contrato_cambio, frena), y al '
                'refrescar 10000.00 sobre 20000.00 | el 100 % con 5000.00 ya facturados: avisa que pasa del contrato y deja | sin contrato '
                'MX008 | 0 % MX005, 101 % MX005, cinco decimales MX005, sin porcentaje 22023, con un hito 22023';
begin
  if pg_temp.c11_omitir(9, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'porcentaje', 'proyecto_id', 'c11-prueba-b', 'porcentaje', 33.33));
    v_doc := (v_b->'documento'->>'id')::uuid;
    a := format('%s, %s, y %s', v_b->'documento'->>'monto',
                case when jsonb_array_length(v_b->'lineas') = 1 and v_b->'lineas'->0->>'tipo' = 'porcentaje'
                          and v_b->'lineas'->0->>'descripcion' = 'Progress billing — 33.33% of contract amount ($18,500.55)'
                          and (v_b->'documento'->>'porcentaje')::numeric = 33.33 and (v_b->'documento'->>'base')::numeric = 18500.55
                          and v_b->'documento'->>'hito_id' is null
                     then 'una línea con su texto en inglés' else 'MAL: ' || left((v_b->'lineas')::text, 300) end,
                case when (v_b->>'puede_emitir')::boolean
                          and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'obra_con_hitos' and not (x->>'frena')::boolean)
                     then 'avisa de los hitos de la obra sin frenar' else 'NO avisa de los hitos (o frena)' end);
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'porcentaje', 50));
    b := format('%s y %s', v_b->'documento'->>'monto',
                case when v_b->'lineas'->0->>'descripcion' = 'Progress billing — 50% of contract amount ($18,500.55)' then 'su texto'
                     else v_b->'lineas'->0->>'descripcion' end);
    perform pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'descripcion', 'Progress payment #1'));
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    c := case when v_b->'lineas'->0->>'descripcion' = 'Progress payment #1' and (v_b->'documento'->>'monto')::numeric = 9250.28
              then 'se queda al refrescar' else 'se PIERDE' end;
    update finanzas_proyecto set contrato = 20000 where proyecto_id = 'c11-prueba-b';
    perform pg_temp.c11_ser('dueno');
    v_b := fn_emision_documento(v_doc);
    d := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'contrato_cambio' and (x->>'frena')::boolean)
              then 'avisa (contrato_cambio, frena)' else 'NO avisa' end;
    v_b := fn_emision_borrador(jsonb_build_object('documento', v_doc));
    perform pg_temp.c11_ser('editor');
    d := d || format(', y al refrescar %s sobre %s', v_b->'documento'->>'monto', v_b->'documento'->>'base');
    insert into facturas (proyecto_id, num, fecha, monto, estado) values ('c11-prueba-b', 'ZZ-901', pg_temp.c11('hoy')::date, 5000, 'emitida');
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'porcentaje', 100));
    e := case when (v_b->>'puede_emitir')::boolean and (v_b->'documento'->>'monto')::numeric = 20000
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x
                                where x->>'codigo' = 'pasa_del_contrato' and not (x->>'frena')::boolean
                                  and x->>'texto' like '%($25,000.00) pasa del contrato ($20,000.00)%')
              then 'avisa que pasa del contrato y deja' else 'MAL: ' || left((v_b->'avisos')::text, 300) end;
    f := pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-d", "porcentaje": 30}') $q$);
    g := format('0 %% %s, 101 %% %s, cinco decimales %s, sin porcentaje %s, con un hito %s',
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-a", "porcentaje": 0}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-a", "porcentaje": 101}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-a", "porcentaje": 33.33333}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-a"}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "porcentaje", "proyecto_id": "c11-prueba-a", "porcentaje": 10, "hito_id": -1110000001}') $q$));
    v_obt := format('el 33.33 %% de 18500.55: %s | al 50 %%: %s | un texto propio %s | el contrato pasa a 20000.00: %s | el 100 %% con 5000.00 ya '
                    'facturados: %s | sin contrato %s | %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. EL BORRADOR T&M: líneas de horas y de material (y un descuento), cada
--     una con su cantidad y su precio; el importe de cada línea es
--     round(cantidad × precio, 2) y el monto es la suma, en numeric:
--     7.25 h × 95 + 412.37 + 3.5 h × 47.333 − 32.22 = 1,234.57.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; v_lin jsonb;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'EL BORRADOR T&M: líneas de horas, de material y un descuento, con cantidad y precio; el importe de cada línea es '
                'round(cantidad × precio, 2) y el monto su suma en numeric (1,234.57); con retención en el borrador; otras líneas las '
                'sustituyen todas; y sus frenos';
  v_esp text := 'cuatro líneas (horas, material, horas, otro): 688.75 + 412.37 + 165.67 + -32.22 = 1234.57, sin aviso de hitos | con el 10 % '
                'en el borrador: retiene 123.46 y se pagan 1111.11 | al refrescar, las mismas cuatro | otras líneas las sustituyen todas: 1 '
                'línea, 100.00 | sin líneas 22023, lista vacía 22023, clave desconocida 22023, tipo desconocido 22023, sin descripción 22023 | '
                'cantidad 0 MX005, precio negativo en horas MX005, precio que no es número MX005, cinco decimales MX005, suma negativa MX005';
begin
  if pg_temp.c11_omitir(10, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_lin := jsonb_build_array(
      jsonb_build_object('tipo', 'horas', 'descripcion', 'Electrician labor', 'cantidad', 7.25, 'unidad', 'hr', 'precio', 95),
      jsonb_build_object('tipo', 'material', 'descripcion', 'Materials (wire, boxes, breakers)', 'cantidad', 1, 'precio', 412.37),
      jsonb_build_object('tipo', 'horas', 'descripcion', 'Apprentice labor', 'cantidad', 3.5, 'unidad', 'hr', 'precio', 47.333,
                         'detalle', 'Nov 3 and Nov 4'),
      jsonb_build_object('descripcion', 'Courtesy discount', 'precio', -32.22));
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'tm', 'proyecto_id', 'c11-prueba-d', 'lineas', v_lin));
    v_doc := (v_b->'documento'->>'id')::uuid;
    a := format('cuatro líneas (%s): %s = %s, %s',
                (select string_agg(x->>'tipo', ', ' order by (x->>'n')::int) from jsonb_array_elements(v_b->'lineas') x),
                (select string_agg(x->>'importe', ' + ' order by (x->>'n')::int) from jsonb_array_elements(v_b->'lineas') x),
                v_b->'documento'->>'monto',
                case when exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'obra_con_hitos')
                     then 'CON aviso de hitos' else 'sin aviso de hitos' end);
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'retencion_pct', 10));
    b := format('retiene %s y se pagan %s', v_b->'documento'->>'retencion', v_b->'documento'->>'a_pagar');
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    c := case when jsonb_array_length(v_b->'lineas') = 4 and (v_b->'documento'->>'monto')::numeric = 1234.57
                   and v_b->'lineas'->2->>'detalle' = 'Nov 3 and Nov 4' and v_b->'lineas'->0->>'unidad' = 'hr'
                   and (v_b->'lineas'->2->>'precio')::numeric = 47.333 and (v_b->'documento'->>'retencion')::numeric = 123.46
              then 'las mismas cuatro' else 'CAMBIARON: ' || left((v_b->'lineas')::text, 300) end;
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc,
             'lineas', jsonb_build_array(jsonb_build_object('descripcion', 'Service call', 'precio', 100))));
    d := format('%s línea, %s', jsonb_array_length(v_b->'lineas'), v_b->'documento'->>'monto');
    e := format('sin líneas %s, lista vacía %s, clave desconocida %s, tipo desconocido %s, sin descripción %s',
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d"}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": []}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": 1, "importe": 5}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": 1, "tipo": "viaje"}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": " ", "precio": 1}]}') $q$));
    f := format('cantidad 0 %s, precio negativo en horas %s, precio que no es número %s, cinco decimales %s, suma negativa %s',
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": 1, "cantidad": 0}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": -1, "tipo": "horas"}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": "abc"}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": 1.00001}]}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "tm", "proyecto_id": "c11-prueba-d", "lineas": [{"descripcion": "x", "precio": -5}]}') $q$));
    v_obt := format('%s | con el 10 %% en el borrador: %s | al refrescar, %s | otras líneas las sustituyen todas: %s | %s | %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. LA RETENCIÓN: de dónde sale el porcentaje (el estimado enlazado, que
--     la app guarda como FRACCIÓN: 0.10 es el 10 %; lo que Edgar fije en la
--     obra; lo que lleve el borrador) y LA REGLA DE REDONDEO:
--     round(monto × % × 0.01, 2), la mitad lejos de cero, una vez por
--     factura. El 10 % de 1,234.57 son 123.46 y se pagan 1,111.11.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; v_doc2 uuid; v_r jsonb;
  a text; b text; c text; d text; e text; f text; g text;
  v_nom text := 'LA RETENCIÓN: la regla de redondeo (round(monto × % × 0.01, 2), la mitad lejos de cero: el 10 % de 1,234.57 son 123.46 y se '
                'pagan 1,111.11); el porcentaje sale del estimado enlazado (fracción × 100; el convertido antes que el más nuevo), de lo que '
                'Edgar fije en la obra (0 = sin retención) o del borrador; si la de la obra cambia, el borrador lo dice y se refresca';
  v_esp text := 'la regla: 10 % de 1234.57 = 123.46; de 1234.55 = 123.46; de 1234.54 = 123.45; de 3333.34 = 333.33; de 0.05 = 0.01; 7.5 % de '
                '100 = 7.50; 0 % = 0.00 | sin nada: 0 (ninguna) | el estimado dice 0.10: 10.00 (estimado); con uno convertido más viejo que '
                'dice 0.05: 5.00 (estimado) | la obra dice 7.5: 7.50 (obra); dice 0: 0.00 (obra); null: 10.00 (estimado) | el borrador de '
                '1234.57: retiene 123.46 y se pagan 1111.11 (estimado); con el 5 % suyo: 61.73 (borrador); con null: 123.46 (estimado) | la '
                'obra pasa a 7.5: el borrador avisa (retencion_cambio, frena) y al refrescar retiene 92.59 (obra); el que lleva su porcentaje '
                'no se entera: 166.67 (borrador) | frenos: la obra 100 MX005, tres decimales MX005, no existe 22023, clave desconocida 22023; '
                'el borrador 100 MX005, -1 MX005';
begin
  if pg_temp.c11_omitir(11, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    a := format('10 %% de 1234.57 = %s; de 1234.55 = %s; de 1234.54 = %s; de 3333.34 = %s; de 0.05 = %s; 7.5 %% de 100 = %s; 0 %% = %s',
                fn_emision_retencion(1234.57, 10), fn_emision_retencion(1234.55, 10), fn_emision_retencion(1234.54, 10),
                fn_emision_retencion(3333.34, 10), fn_emision_retencion(0.05, 10), fn_emision_retencion(100, 7.5),
                fn_emision_retencion(1234.57, 0));
    v_r := fn_emision_retencion_de('c11-prueba-b');
    b := format('%s (%s)', v_r->>'pct', v_r->>'origen');
    insert into estimados (id, nombre, proyecto_id, retencion_pct, estado, escenario) overriding system value
    values (-1110000010, 'C11 PRUEBA Estimado', 'c11-prueba-b', 0.10, 'borrador', null);
    v_r := fn_emision_retencion_de('c11-prueba-b');
    c := format('%s (%s)', v_r->>'pct', v_r->>'origen');
    insert into estimados (id, nombre, proyecto_id, retencion_pct, estado, escenario) overriding system value
    values (-1110000011, 'C11 PRUEBA Estimado viejo', 'c11-prueba-b', 0.05, 'convertido', null);
    v_r := fn_emision_retencion_de('c11-prueba-b');
    c := c || format('; con uno convertido más viejo que dice 0.05: %s (%s)', v_r->>'pct', v_r->>'origen');
    delete from estimados where id = -1110000011;
    perform pg_temp.c11_ser('dueno');
    v_r := fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 7.5}'::jsonb)->'retencion';
    d := format('la obra dice 7.5: %s (%s)', v_r->>'pct', v_r->>'origen');
    v_r := fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 0}'::jsonb)->'retencion';
    d := d || format('; dice 0: %s (%s)', v_r->>'pct', v_r->>'origen');
    v_r := fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": null}'::jsonb)->'retencion';
    d := d || format('; null: %s (%s)', v_r->>'pct', v_r->>'origen');
    -- el borrador del hito de 1,234.57
    v_b := fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000006));
    v_doc := (v_b->'documento'->>'id')::uuid;
    e := format('retiene %s y se pagan %s (%s)', v_b->'documento'->>'retencion', v_b->'documento'->>'a_pagar', v_b->'documento'->>'retencion_origen');
    v_b := fn_emision_borrador(jsonb_build_object('documento', v_doc, 'retencion_pct', 5));
    e := e || format('; con el 5 %% suyo: %s (%s)', v_b->'documento'->>'retencion', v_b->'documento'->>'retencion_origen');
    v_b := fn_emision_borrador(jsonb_build_object('documento', v_doc, 'retencion_pct', null));
    e := e || format('; con null: %s (%s)', v_b->'documento'->>'retencion', v_b->'documento'->>'retencion_origen');
    -- otro borrador de la misma obra con su propio porcentaje (9 % de 1,851.85 = 166.67)
    v_doc2 := (fn_emision_borrador(jsonb_build_object('forma', 'tm', 'proyecto_id', 'c11-prueba-b', 'retencion_pct', 9,
                 'lineas', jsonb_build_array(jsonb_build_object('descripcion', 'Additional work', 'precio', 1851.85))))->'documento'->>'id')::uuid;
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 7.5}'::jsonb);
    v_b := fn_emision_documento(v_doc);
    f := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'retencion_cambio' and (x->>'frena')::boolean)
              then 'el borrador avisa (retencion_cambio, frena)' else 'el borrador NO avisa' end;
    v_b := fn_emision_borrador(jsonb_build_object('documento', v_doc));
    f := f || format(' y al refrescar retiene %s (%s)', v_b->'documento'->>'retencion', v_b->'documento'->>'retencion_origen');
    v_b := fn_emision_documento(v_doc2);
    f := f || format('; el que lleva su porcentaje %s: %s (%s)',
                     case when not exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'retencion_cambio')
                          then 'no se entera' else 'SE ENTERA' end,
                     v_b->'documento'->>'retencion', v_b->'documento'->>'retencion_origen');
    perform pg_temp.c11_ser('editor');
    g := format('la obra 100 %s, tres decimales %s, no existe %s, clave desconocida %s; el borrador 100 %s, -1 %s',
                pg_temp.c11_cod($q$ select fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 100}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10.123}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_obra('{"proyecto_id": "c11-prueba-zz", "retencion_pct": 10}') $q$),
                pg_temp.c11_cod($q$ select fn_emision_obra('{"proyecto_id": "c11-prueba-b", "porcentaje": 10}') $q$),
                pg_temp.c11_cod(format('select fn_emision_borrador(%L)', jsonb_build_object('documento', v_doc, 'retencion_pct', 100)::text)),
                pg_temp.c11_cod(format('select fn_emision_borrador(%L)', jsonb_build_object('documento', v_doc, 'retencion_pct', -1)::text)));
    v_obt := format('la regla: %s | sin nada: %s | el estimado dice 0.10: %s | %s | el borrador de 1234.57: %s | la obra pasa a 7.5: %s | frenos: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. EMITIR UN HITO, como el dueño por la API (authenticated, con su
--     sesión) y con el puente de c3 diferido, como en producción: el
--     siguiente número de la serie, la fecha de hoy, la fila de facturas ya
--     emitida con su retención EN DÓLARES, su asiento al centavo (Dr 1110 lo
--     que se paga ahora + Dr 1120 lo retenido / Cr el ingreso de su tipo de
--     obra), el hito a «facturado», el documento sellado.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_fid bigint; v_e1 text; v_n0 bigint; f facturas; d emision_documentos; v_d jsonb; v_v record;
  a text; b text; c text; e text; g text; h text;
  v_nom text := 'EMITIR UN HITO como el dueño por la API, con el puente de c3 diferido: el siguiente número de la serie, la fecha de hoy, la '
                'fila de facturas ya emitida con su retención en dólares, su asiento al centavo (lo que se paga ahora + lo retenido = el '
                'ingreso de su tipo de obra), el hito a facturado y el documento sellado con su huella';
  v_esp text := 'devuelve: el siguiente número, de hoy, vence hoy, 1234.57 − 123.46 = 1111.11, el hito facturado, su asiento de hoy y su '
                'huella | la fila de facturas: emitida, de hoy, 1234.57, retención 123.46, sin pagar, con su hito, de su obra y con su '
                'asiento | el asiento: cxc 1111.11 | ret 123.46 | ingreso -1234.57 (el ingreso de las obras comerciales; nace de la '
                'factura) | el documento: emitido, con su número de la serie (el contador en él) y sellado (su huella es la de su '
                'contenido) | para la pantalla: emitida, debe 1111.11 y 123.46 de retención, sin PDF ni envíos todavía | los cuadres de '
                'la facturación: en verde';
begin
  if pg_temp.c11_omitir(12, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_e1 := pg_temp.c11_num(1); v_n0 := pg_temp.c11_contador();
    v_r := pg_temp.c11_hito(-1110000006);
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint;
    a := case when v_r->>'numero' = v_e1 and v_r->>'estado' = 'emitida' and v_r->>'fecha' = pg_temp.c11('hoy') and v_r->>'vence' = pg_temp.c11('hoy')
                   and v_r->>'hito_estado' = 'facturado' and v_r->>'huella' ~ '^[0-9a-f]{64}$' and v_r->>'asiento' is not null
                   and v_r->>'fecha_contable' = pg_temp.c11('hoy') and (v_r->>'hito_id')::bigint = -1110000006
              then format('el siguiente número, de hoy, vence hoy, %s − %s = %s, el hito facturado, su asiento de hoy y su huella',
                          v_r->>'monto', v_r->>'retencion', v_r->>'a_pagar')
              else 'MAL: ' || v_r::text end;
    select * into f from facturas where id = v_fid;
    b := case when f.estado = 'emitida' and f.fecha = pg_temp.c11('hoy')::date and f.num = v_e1 and not coalesce(f.pagada, false)
                   and f.hito_id = -1110000006 and f.proyecto_id = 'c11-prueba-b' and f.contabilizado_en is not null
                   and not coalesce(f.a_contratista, false)
              then format('emitida, de hoy, %s, retención %s, sin pagar, con su hito, de su obra y con su asiento', f.monto, f.retencion)
              else 'MAL: ' || to_jsonb(f)::text end;
    c := pg_temp.c11_asiento(v_fid)
         || case when (select bool_and(l.cuenta = (select m.cuenta from mapeo_tipo_proyecto m where m.tipo = 'comercial'))
                         from asiento_lineas l where l.asiento_id = f.contabilizado_en and l.monto < 0)
                      and (select x.origen_tabla = 'facturas' and x.origen_id = v_fid::text and x.numero = v_r->>'asiento'
                             from asientos x where x.id = f.contabilizado_en)
                 then ' (el ingreso de las obras comerciales; nace de la factura)' else ' (MAL: otra cuenta u otro origen)' end;
    select * into d from emision_documentos where id = v_doc;
    e := case when d.estado = 'emitida' and d.numero = v_e1 and d.anio = extract(year from pg_temp.c11('hoy')::date)::int
                   and d.secuencia = v_n0 + 1 and pg_temp.c11_contador() = v_n0 + 1 and d.factura_id = v_fid and d.asiento_id = f.contabilizado_en
                   and (select count(*) from emision_serie s where s.documento_id = v_doc and s.numero = v_e1 and s.secuencia = v_n0 + 1) = 1
                   and d.huella = encode(sha256(convert_to(d.contenido::text, 'UTF8')), 'hex') and d.huella = v_r->>'huella'
                   and d.contenido->>'numero' = v_e1 and d.emitido_por = pg_temp.c11('dueno')::uuid
              then 'emitido, con su número de la serie (el contador en él) y sellado (su huella es la de su contenido)'
              else 'MAL: ' || (to_jsonb(d) - 'contenido')::text end;
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento(v_doc);
    select * into v_v from v_emision_documentos x where x.id = v_doc;
    g := case when v_d->'documento'->>'estado' = 'emitida' and v_v.estado = 'emitida' and v_v.asiento = v_r->>'asiento'
                   and v_d->'libro'->>'factura_estado' = 'emitida' and jsonb_array_length(v_d->'pdfs') = 0 and jsonb_array_length(v_d->'envios') = 0
                   and v_d ? 'contenido' and not v_d ? 'visto' and v_v.pdfs = 0 and v_v.envios = 0 and v_v.visto is null
              then format('emitida, debe %s y %s de retención, sin PDF ni envíos todavía', v_v.saldo, v_v.saldo_retencion)
              else 'MAL: ' || left(v_d::text, 300) end;
    select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'en verde') into h from v_emision_control k where k.nivel = 'cuadre' and not k.ok;
    perform pg_temp.c11_ser('editor');
    v_obt := format('devuelve: %s | la fila de facturas: %s | el asiento: %s | el documento: %s | para la pantalla: %s | los cuadres de la '
                    'facturación: %s', a, b, c, e, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. LO QUE PASA AL CONFIRMAR. Con dos facturas emitidas (una con
--     retención), se corren YA los controles diferidos del libro —lo que
--     Postgres comprobaría al confirmar la transacción—: nada falla; cada
--     asiento suma cero y son los dos últimos de la cadena; los contadores
--     subieron lo justo; y ni la cadena ni ningún control de las otras capas
--     pasa a rojo.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; s0 text[]; v_serie text; v_a0 bigint; v_f0 bigint; v_ids uuid[];
  a text; b text; c text; d text;
  v_nom text := 'LO QUE PASA AL CONFIRMAR: con dos facturas emitidas, los controles diferidos del libro (lo que Postgres comprueba al '
                'confirmar) no fallan; cada asiento suma cero y son los dos últimos de la cadena; los contadores subieron lo justo; y ni la '
                'cadena ni ningún control de las otras capas pasa a rojo';
  v_esp text := 'al confirmar: nada falla | cada asiento suma cero y son los dos últimos de la cadena | el contador de asientos subió 2 y el '
                'de facturas 2 | controles de las otras capas en rojo que no lo estaban: ninguno';
begin
  if pg_temp.c11_omitir(13, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    s0 := pg_temp.c11_rojos();
    v_serie := 'asientos-' || extract(year from pg_temp.c11('hoy')::date)::int;
    select coalesce((select k.ultimo from contadores k where k.serie = v_serie), 0) into v_a0;
    v_f0 := pg_temp.c11_contador();
    r1 := pg_temp.c11_hito(-1110000006);
    r2 := pg_temp.c11_hito(-1110000001);
    begin
      set constraints all immediate;
      a := 'nada falla';
    exception when others then a := sqlstate || ': ' || sqlerrm;
    end;
    set constraints all deferred;
    select array_agg(f.contabilizado_en order by f.id) into v_ids
      from facturas f where f.id in ((r1->>'factura_id')::bigint, (r2->>'factura_id')::bigint);
    b := case when (select bool_and((select sum(l.monto) from asiento_lineas l where l.asiento_id = x.id) = 0) from asientos x where x.id = any (v_ids))
              then 'cada asiento suma cero' else 'un asiento NO suma cero' end
         || case when (select array_agg(y.id order by y.cadena_pos) from (select x.id, x.cadena_pos from asientos x order by x.cadena_pos desc limit 2) y) = v_ids
                 then ' y son los dos últimos de la cadena' else ' y NO son los dos últimos de la cadena' end;
    c := format('el contador de asientos subió %s y el de facturas %s',
                (select k.ultimo from contadores k where k.serie = v_serie) - v_a0, pg_temp.c11_contador() - v_f0);
    d := pg_temp.c11_nuevos(s0, pg_temp.c11_rojos());
    v_obt := format('al confirmar: %s | %s | %s | controles de las otras capas en rojo que no lo estaban: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. EL «VISTO». La pantalla manda la huella de lo que enseñó. Si el
--     borrador ya no es ese (otra pestaña cambió las notas; cambiaron los
--     ajustes que salen en la factura; no se manda), MX011 y NADA cambia.
--     Si lo de fuera cambió (el hito vale otra cosa) con el mismo visto,
--     MX011 también, y dice qué. Refrescado, emite.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; v1 text; v2 text; v3 text; v_n0 bigint; v_x text; v_r jsonb;
  a text; b text; c text; d text; e text;
  v_nom text := 'EL «VISTO»: si el borrador ya no es el que la pantalla enseñó (otra pestaña lo cambió, cambiaron los ajustes de la factura, '
                'o no se manda), emitir da MX011 y nada cambia; si cambió el hito con el mismo visto, MX011 y dice qué; refrescado y con el '
                'visto de ahora, emite';
  v_esp text := 'otra pestaña cambió las notas: MX011 y nada cambia (sigue en borrador, sin número, sin factura, el hito pendiente, el '
                'contador igual) | cambiaron los ajustes de la factura: MX011 | sin visto: MX011 | el hito cambió de monto con el mismo '
                'visto: MX011, y dice cuánto vale ahora | refrescado y con lo de ahora: emite por 3500.00';
begin
  if pg_temp.c11_omitir(14, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_n0 := pg_temp.c11_contador();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    v_doc := (v_b->'documento'->>'id')::uuid; v1 := v_b->>'visto';
    perform pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'notas', 'Changed in another tab.'));
    a := pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc, v1))
         || case when (select x.estado = 'borrador' and x.numero is null from emision_documentos x where x.id = v_doc)
                      and not exists (select 1 from facturas f where f.hito_id = -1110000001)
                      and (select h.estado from hitos h where h.id = -1110000001) = 'pendiente' and pg_temp.c11_contador() = v_n0
                 then ' y nada cambia (sigue en borrador, sin número, sin factura, el hito pendiente, el contador igual)'
                 else ' y ALGO cambió' end;
    v2 := fn_emision_documento(v_doc)->>'visto';
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_config('{"terminos_dias": 15}'::jsonb);
    perform pg_temp.c11_ser('editor');
    b := pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc, v2));
    c := pg_temp.c11_cod(format('select fn_emision_emitir(%L, null)', v_doc));
    v3 := fn_emision_documento(v_doc)->>'visto';
    update hitos set monto = 3500 where id = -1110000001;
    v_x := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc, v3));
    d := case when v_x like 'MX011: El hito «C11 PRUEBA Milestone 1» ahora vale $3,500.00 y este borrador dice $3,333.33:%'
              then 'MX011, y dice cuánto vale ahora' else v_x end;
    perform pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    v_r := pg_temp.c11_emitir(v_doc);
    e := format('emite por %s', v_r->>'monto');
    v_obt := format('otra pestaña cambió las notas: %s | cambiaron los ajustes de la factura: %s | sin visto: %s | el hito cambió de monto con '
                    'el mismo visto: %s | refrescado y con lo de ahora: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. DOS VECES. El mismo borrador no se emite dos veces (MX008: dice su
--     número; una sola factura, un solo número). El mismo hito por dos
--     caminos (lo facturó QuickBooks entre el borrador y la emisión): MX008
--     y nada. Otro borrador de un hito ya emitido, no. El hito cobrado entre
--     el borrador y la emisión, tampoco. (Dos emisiones A LA VEZ, de verdad,
--     en dos sesiones: pruebas/conta/c11-concurrencia.sh.)
do $$
declare
  v_obt text; v_r jsonb; v_doc1 uuid; v_doc2 uuid; v_doc3 uuid; v_n0 bigint; v_x text;
  a text; b text; c text; d text; e text;
  v_nom text := 'DOS VECES: el mismo borrador no se emite dos veces (MX008, dice su número; una factura, un número); el mismo hito por dos '
                'caminos (facturado fuera entre el borrador y la emisión) da MX008 y nada; ni otro borrador de un hito ya emitido, ni un '
                'hito cobrado entre el borrador y la emisión; y los estados equivocados';
  v_esp text := 'la segunda emisión del mismo borrador: MX008 (dice su número), una sola factura y un solo número | el hito facturado por '
                'otro camino entre el borrador y la emisión: MX008 (dice ZZ-902) y nada: sigue en borrador y el contador igual | otro '
                'borrador del hito ya emitido: MX008 | el hito cobrado entre el borrador y la emisión: MX008 | cambiar una emitida MX008, '
                'tirarla MX008, anular un borrador MX008, emitir uno que no existe 22023, una opción desconocida 22023';
begin
  if pg_temp.c11_omitir(15, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_n0 := pg_temp.c11_contador();
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc1 := (v_r->>'documento')::uuid;
    v_x := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc1, 'x'));
    a := case when v_x like 'MX008: Ese borrador ya se emitió: es la factura ' || (v_r->>'numero') || ' del %' then 'MX008 (dice su número)' else v_x end
         || case when (select count(*) from facturas f where f.hito_id = -1110000001) = 1 and pg_temp.c11_contador() = v_n0 + 1
                 then ', una sola factura y un solo número' else ', y DOS' end;
    -- el mismo hito por dos caminos
    v_doc2 := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002))->'documento'->>'id')::uuid;
    insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
    values ('c11-prueba-a', 'ZZ-902', pg_temp.c11('hoy')::date, 3333.33, -1110000002, 'emitida');
    v_x := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc2, fn_emision_documento(v_doc2)->>'visto'));
    b := case when v_x like 'MX008: El hito «C11 PRUEBA Milestone 2» ya se facturó: factura ZZ-902 del %' then 'MX008 (dice ZZ-902)' else v_x end
         || case when (select x.estado from emision_documentos x where x.id = v_doc2) = 'borrador' and pg_temp.c11_contador() = v_n0 + 1
                 then ' y nada: sigue en borrador y el contador igual' else ' y ALGO cambió' end;
    c := pg_temp.c11_cod($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001}') $q$);
    -- cobrado entre el borrador y la emisión
    v_doc3 := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003))->'documento'->>'id')::uuid;
    update hitos set estado = 'cobrado' where id = -1110000003;
    d := pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc3, fn_emision_documento(v_doc3)->>'visto'));
    e := format('cambiar una emitida %s, tirarla %s, anular un borrador %s, emitir uno que no existe %s, una opción desconocida %s',
                pg_temp.c11_cod(format('select fn_emision_borrador(%L)', jsonb_build_object('documento', v_doc1, 'notas', 'x')::text)),
                pg_temp.c11_cod(format('select fn_emision_descartar(%L)', v_doc1)),
                pg_temp.c11_cod(format('select fn_emision_anular(%L, %L)', v_doc2, 'c11-pruebas')),
                pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', gen_random_uuid(), 'x')),
                pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L, %L)', v_doc2, 'x', '{"forzar": true}')));
    v_obt := format('la segunda emisión del mismo borrador: %s | el hito facturado por otro camino entre el borrador y la emisión: %s | otro '
                    'borrador del hito ya emitido: %s | el hito cobrado entre el borrador y la emisión: %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. LA SERIE SIN HUECOS, Y NINGÚN NÚMERO DOS VECES. (a) Un número que ya
--     lleva OTRA fila de facturas, hecha fuera de la app —en la misma obra o
--     en otra—, la serie lo SALTA: la emisión sale con el siguiente y lo dice
--     (saltados); el control 20 lo sabe (ese número lo lleva aquella: no es
--     un hueco) y el 72 nombra la de fuera. Antes, en la misma obra la
--     emisión se quedaba trancada para siempre, y en otra obra salían dos
--     facturas con el mismo número. (b) Una emisión que falla DESPUÉS de
--     tomar su número no lo gasta: el contador vuelve atrás con todo lo
--     demás (el libro no acepta la factura: un día sin período abierto; se
--     finge el reloj de c2-pruebas dentro de un bloque que se deshace).
do $$
declare
  v_obt text; v_n0 bigint; e1 text; e2 text; e3 text; e4 text; e5 text; e6 text; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; v_doc3 uuid; v_x text; v_y text;
  v_sig text; v_z text;
  v_dia date; v_ny bigint; v_anio int := extract(year from pg_temp.c11('hoy')::date)::int;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'LA SERIE SIN HUECOS, Y NINGÚN NÚMERO DOS VECES: el número que toca ya lo lleva una factura hecha fuera de la app (en la misma '
                'obra, o en otra): la serie lo salta, la emisión sale con el siguiente y lo dice (saltados), y no hay dos facturas con el '
                'mismo número (y la pantalla ya anuncia el que de verdad toca); una emisión que el libro no acepta da MX008, no gasta '
                'número y no deja nada; el control 20 queda en verde y dice los saltados, y el 72 nombra las de fuera (y la que alguien '
                'haga después con el número de una de la app)';
  v_esp text := 'la primera: el siguiente número | el que toca ya lo lleva una factura de fuera en la MISMA obra: la pantalla ya anuncia el '
                'que sigue, la serie lo salta, emite con el siguiente y lo dice (saltados y aviso) | y si lo lleva una factura de OTRA obra: también lo salta, y ningún número está '
                'dos veces | la siguiente, seguida | un día sin período abierto en el libro: MX008 (el libro no aceptó la factura, y dice '
                'por qué), sin número, sin factura y sin contador de ese año | la serie: 4 números y 2 saltados, el contador en el último, '
                'su control en verde (dice los 2 saltados) y el 72 nombra las dos de fuera (llevan un número de la serie) | y si después '
                'alguien hace fuera una factura con el número de una de la app: el 72 dice que lleva el MISMO número';
begin
  if pg_temp.c11_omitir(16, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_n0 := pg_temp.c11_contador();
    e1 := pg_temp.c11_num(1); e2 := pg_temp.c11_num(2); e3 := pg_temp.c11_num(3); e4 := pg_temp.c11_num(4); e5 := pg_temp.c11_num(5);
    e6 := pg_temp.c11_num(6);
    r1 := pg_temp.c11_hito(-1110000001);
    a := case when r1->>'numero' = e1 then 'el siguiente número' else r1->>'numero' end;
    -- (a) el número que toca ya está en la MISMA obra, en una factura que no salió de aquí
    insert into facturas (proyecto_id, num, fecha, monto, estado) values ('c11-prueba-a', e2, pg_temp.c11('hoy')::date, 10, 'emitida');
    select e.siguiente_numero into v_sig from v_emision_estado e;
    r2 := pg_temp.c11_hito(-1110000002);
    b := case when v_sig = e3 then 'la pantalla ya anuncia el que sigue' else 'la pantalla anuncia ' || coalesce(v_sig, '(nada)') end
         || case when r2->>'numero' = e3 and r2->'saltados' = jsonb_build_array(e2) and r2->>'aviso' like 'La serie saltó ' || e2 || ':%'
                 then ', la serie lo salta, emite con el siguiente y lo dice (saltados y aviso)'
                 else format(', emitió con %s, saltados %s, aviso %s', r2->>'numero', coalesce((r2->'saltados')::text, '(nada)'), coalesce(r2->>'aviso', '(nada)')) end;
    -- … y en OTRA obra
    insert into facturas (proyecto_id, num, fecha, monto, estado) values ('c11-prueba-d', e4, pg_temp.c11('hoy')::date, 20, 'emitida');
    r3 := pg_temp.c11_hito(-1110000006);
    c := case when r3->>'numero' = e5 and r3->'saltados' = jsonb_build_array(e4) then 'también lo salta'
              else format('emitió con %s, saltados %s', r3->>'numero', coalesce((r3->'saltados')::text, '(nada)')) end
         || case when not exists (select 1 from facturas f where f.num in (e1, e2, e3, e4, e5) group by f.num having count(*) > 1)
                 then ', y ningún número está dos veces' else ', y HAY un número dos veces' end;
    r4 := pg_temp.c11_hito(-1110000005);
    d := case when r4->>'numero' = e6 and not r4 ? 'saltados' then 'seguida' else 'con ' || (r4->>'numero') end;
    -- (b) el libro no acepta la factura: un día sin período abierto
    begin
      select max(p.hasta) + 20 into v_dia from periodos p where p.tipo = 'mes';
      v_ny := pg_temp.c11_contador(extract(year from v_dia)::int);
      v_doc3 := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003))->'documento'->>'id')::uuid;
      perform pg_temp.c11_fingir_hoy(v_dia);
      v_x := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc3, fn_emision_documento(v_doc3)->>'visto'));
      e := case when v_x like 'MX008: No se emitió nada (ni se gastó el número %): el libro no aceptó la factura.%período%'
                then 'MX008 (el libro no aceptó la factura, y dice por qué)' else v_x end
           || case when (select x.estado = 'borrador' and x.numero is null from emision_documentos x where x.id = v_doc3)
                        and not exists (select 1 from facturas f where f.hito_id = -1110000003)
                        and pg_temp.c11_contador(extract(year from v_dia)::int) = v_ny
                        and not exists (select 1 from emision_serie s where s.documento_id = v_doc3)
                   then ', sin número, sin factura y sin contador de ese año' else ', y ALGO quedó' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_x := pg_temp.c11_ctl(20); v_y := pg_temp.c11_ctl(72);
    f := format('%s números y %s saltados, el contador %s, su control %s y el 72 %s',
                (select count(*) from emision_serie s where s.anio = v_anio and s.secuencia > v_n0),
                (select count(*) from generate_series(v_n0 + 1, v_n0 + 6) k
                  where not exists (select 1 from emision_serie s where s.anio = v_anio and s.secuencia = k)),
                case when pg_temp.c11_contador() = v_n0 + 6 then 'en el último' else 'en ' || pg_temp.c11_contador() end,
                case when v_x = 'verde'
                          and (select k.detalle from v_emision_control k where k.orden = 20) like '%(y 2 que la serie saltó porque ya lo(s) llevaba una factura hecha fuera de la app)%'
                     then 'en verde (dice los 2 saltados)' else v_x end,
                case when v_y like 'rojo: %#' || e2 || ' (del %; lleva un número con la forma de la serie: la serie lo salta)%'
                          and v_y like '%#' || e4 || ' (del %; lleva un número con la forma de la serie: la serie lo salta)%'
                     then 'nombra las dos de fuera (llevan un número de la serie)' else v_y end);
    -- y si DESPUÉS alguien hace fuera una factura con el número de una de la app (la ficha deja escribir cualquier número)
    begin
      insert into facturas (proyecto_id, num, fecha, monto, estado) values ('c11-prueba-d', e6, pg_temp.c11('hoy')::date, 30, 'emitida');
      v_y := pg_temp.c11_ctl(72);
      v_z := case when v_y like '%#' || e6 || ' (del %; lleva el MISMO número que una factura de la app)%' then 'el 72 dice que lleva el MISMO número' else 'el 72: ' || v_y end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('la primera: %s | el que toca ya lo lleva una factura de fuera en la MISMA obra: %s | y si lo lleva una factura de OTRA '
                    'obra: %s | la siguiente, %s | un día sin período abierto en el libro: %s | la serie: %s | y si después alguien hace fuera '
                    'una factura con el número de una de la app: %s', a, b, c, d, e, f, v_z);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. TRES HITOS QUE SUMAN EL CONTRATO, con retención del 10 %: 3,333.33 +
--     3,333.33 + 3,333.34 = 10,000.00. Tres números seguidos; cada factura
--     retiene su 10 % redondeado UNA vez (333.33, 333.33, 333.33: en total
--     999.99, un centavo menos que el 10 % del contrato, y eso es lo que
--     está en el libro); tres asientos al centavo.
do $$
declare
  v_obt text; e1 text; e2 text; e3 text; r1 jsonb; r2 jsonb; r3 jsonb; v_o record; v_c jsonb;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'TRES HITOS QUE SUMAN EL CONTRATO (3,333.33 + 3,333.33 + 3,333.34 = 10,000.00) con retención del 10 %: tres números '
                'seguidos; cada factura retiene su 10 % redondeado una vez (999.99 en total: lo que vale es lo de cada factura); tres '
                'asientos al centavo; y la obra y el documento lo dicen';
  v_esp text := 'tres números seguidos | 3333.33 − 333.33 = 3000.00; 3333.33 − 333.33 = 3000.00; 3333.34 − 333.33 = 3000.01 | suman el '
                'contrato (10000.00), retienen 999.99 y se pagan 9000.01 | los asientos: cxc 3000.00 | ret 333.33 | ingreso -3333.33; cxc '
                '3000.00 | ret 333.33 | ingreso -3333.33; cxc 3000.01 | ret 333.33 | ingreso -3333.34 | la obra: contrato 10000.00, '
                'facturado 10000.00 en 3 facturas, por facturar 0.00, retención 10.00 % (obra), retenido 999.99, 0 hitos por facturar | la '
                'tercera dice: la 3, antes 6666.66, con esta 10000.00 (el 100.0 %), retenido a la fecha 999.99';
begin
  if pg_temp.c11_omitir(17, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    e1 := pg_temp.c11_num(1); e2 := pg_temp.c11_num(2); e3 := pg_temp.c11_num(3);
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002); r3 := pg_temp.c11_hito(-1110000003);
    a := case when r1->>'numero' = e1 and r2->>'numero' = e2 and r3->>'numero' = e3 then 'tres números seguidos'
              else concat_ws(', ', r1->>'numero', r2->>'numero', r3->>'numero') end;
    b := format('%s − %s = %s; %s − %s = %s; %s − %s = %s', r1->>'monto', r1->>'retencion', r1->>'a_pagar',
                r2->>'monto', r2->>'retencion', r2->>'a_pagar', r3->>'monto', r3->>'retencion', r3->>'a_pagar');
    select format('suman %s (%s), retienen %s y se pagan %s',
                  case when sum(x.monto) = (select round(fp.contrato, 2) from finanzas_proyecto fp where fp.proyecto_id = 'c11-prueba-a')
                       then 'el contrato' else 'OTRA cosa' end, sum(x.monto), sum(x.retencion), sum(x.a_pagar))
      into c from emision_documentos x where x.proyecto_id = 'c11-prueba-a' and x.estado = 'emitida';
    d := concat_ws('; ', pg_temp.c11_asiento((r1->>'factura_id')::bigint), pg_temp.c11_asiento((r2->>'factura_id')::bigint),
                   pg_temp.c11_asiento((r3->>'factura_id')::bigint));
    select * into v_o from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    e := format('contrato %s, facturado %s en %s facturas, por facturar %s, retención %s %% (%s), retenido %s, %s hitos por facturar',
                v_o.contrato, v_o.facturado, v_o.facturas, v_o.por_facturar, v_o.retencion_pct, v_o.retencion_origen, v_o.retenido,
                v_o.hitos_pendientes);
    select x.contenido into v_c from emision_documentos x where x.id = (r3->>'documento')::uuid;
    f := format('la %s, antes %s, con esta %s (el %s %%), retenido a la fecha %s', v_c->>'ordinal', v_c->'contrato'->>'facturado_antes',
                v_c->'contrato'->>'facturado_con_esta', v_c->'contrato'->>'pct', v_c->'totales'->>'retenido_a_la_fecha');
    v_obt := format('%s | %s | %s | los asientos: %s | la obra: %s | la tercera dice: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. EL AÑO QUE CAMBIA: la última de un año y la primera del siguiente
--     (con el calendario de hoy: el 31-dic-2027 y el 1-ene-2028). Cada año
--     lleva su serie y su contador: la del año nuevo empieza por su primer
--     número. El reloj es el fingido de c2-pruebas (se deshace con la
--     prueba) y los meses que falten se abren dentro de ella.
do $$
declare
  v_obt text; v_y int; v_m text; e1 text; e2 text; e3 text; r1 jsonb; r2 jsonb; r3 jsonb; v_n1 bigint; v_n2 bigint; v_otros text;
  a text; b text; c text; d text; e text;
  v_nom text := 'EL AÑO QUE CAMBIA: la última factura de un año (31 de diciembre) y la primera del siguiente (1 de enero): cada año lleva '
                'su serie y su contador, el número dice su año y la del año nuevo empieza por el primero que le toca';
  v_esp text := 'el 31 de diciembre: el siguiente número de ese año, con esa fecha y su asiento ese día | el 1 de enero: el primero que toca '
                'del año nuevo, con su año en el número y esa fecha | otra más ese día: el siguiente | los contadores: uno más en el año '
                'viejo, dos en el nuevo, y los demás sin tocar | el control de la serie, en verde';
begin
  if pg_temp.c11_omitir(18, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_y := greatest(2027, extract(year from pg_temp.c11('hoy')::date)::int);
    -- los meses que falten hasta enero del año nuevo, en orden
    for v_m in select to_char(g, 'YYYY-MM')
                 from generate_series((select max(p.desde) from periodos p where p.tipo = 'mes') + interval '1 month',
                                      make_date(v_y + 1, 1, 1)::timestamp, interval '1 month') g loop
      perform fn_abrir_periodo(v_m);
    end loop;
    v_n1 := pg_temp.c11_contador(v_y); v_n2 := pg_temp.c11_contador(v_y + 1);
    select md5(coalesce(string_agg(k.serie || ':' || k.ultimo, ',' order by k.serie), '')) into v_otros
      from contadores k where k.serie ~ '^facturas-' and k.serie not in ('facturas-' || v_y, 'facturas-' || (v_y + 1));
    perform pg_temp.c11_fingir_hoy(make_date(v_y, 12, 31));
    e1 := pg_temp.c11_num(1);
    r1 := pg_temp.c11_hito(-1110000001);
    a := case when r1->>'numero' = e1 and e1 like '%-' || v_y || '-%' and (r1->>'fecha')::date = make_date(v_y, 12, 31)
                   and (r1->>'fecha_contable')::date = make_date(v_y, 12, 31)
              then 'el siguiente número de ese año, con esa fecha y su asiento ese día' else 'MAL: ' || r1::text end;
    perform pg_temp.c11_ser('editor');
    perform pg_temp.c11_fingir_hoy(make_date(v_y + 1, 1, 1));
    e2 := pg_temp.c11_num(1); e3 := pg_temp.c11_num(2);
    r2 := pg_temp.c11_hito(-1110000002);
    b := case when r2->>'numero' = e2 and e2 like '%-' || (v_y + 1) || '-%' and (r2->>'fecha')::date = make_date(v_y + 1, 1, 1)
                   and (select s.secuencia from emision_serie s where s.numero = e2) = v_n2 + 1
              then 'el primero que toca del año nuevo, con su año en el número y esa fecha' else 'MAL: ' || r2::text end;
    r3 := pg_temp.c11_hito(-1110000003);
    c := case when r3->>'numero' = e3 then 'el siguiente' else r3->>'numero' end;
    d := format('%s en el año viejo, %s en el nuevo, y los demás %s',
                case pg_temp.c11_contador(v_y) - v_n1 when 1 then 'uno más' else (pg_temp.c11_contador(v_y) - v_n1)::text end,
                case pg_temp.c11_contador(v_y + 1) - v_n2 when 2 then 'dos' else (pg_temp.c11_contador(v_y + 1) - v_n2)::text end,
                case when (select md5(coalesce(string_agg(k.serie || ':' || k.ultimo, ',' order by k.serie), '')) from contadores k
                            where k.serie ~ '^facturas-' and k.serie not in ('facturas-' || v_y, 'facturas-' || (v_y + 1))) = v_otros
                     then 'sin tocar' else 'TOCADOS' end);
    e := 'en ' || pg_temp.c11_color(pg_temp.c11_ctl(20));
    v_obt := format('el 31 de diciembre: %s | el 1 de enero: %s | otra más ese día: %s | los contadores: %s | el control de la serie, %s',
                    a, b, c, d, e)
             || format(' (números: %s, %s, %s)', r1->>'numero', r2->>'numero', r3->>'numero');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, v_nom, v_esp, v_obt, regexp_replace(v_obt, ' \(números: [^)]*\)$', '') = v_esp);
end $$;

-- 19. CONGELADO. Después de emitir no cambia nada: ni por sus funciones
--     (MX008), ni a mano el dueño (MX003), ni el monto, la fecha, el número,
--     la retención o la obra de su fila de facturas (la guarda de c3, MX003);
--     la casilla de «pagada» sí la sigue llevando la app. Y si después
--     cambian el hito, el contrato o los datos de la empresa, el documento
--     dice lo que decía: mismo contenido, misma huella.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_fid bigint; v_c0 jsonb; v_h0 text; v_b jsonb;
  a text; b text; c text; d text; e text;
  v_nom text := 'CONGELADO: una factura emitida no cambia ni por sus funciones (MX008), ni a mano (MX003), ni el monto, la fecha, el '
                'número, la retención o la obra de su fila de facturas (la guarda de c3); la casilla de pagada sí; y si después cambian el '
                'hito, el contrato o los datos de la empresa, el documento conserva su contenido y su huella';
  v_esp text := 'por sus funciones: cambiarla MX008, tirarla MX008 | a mano, el dueño: el documento MX003, sus líneas MX003 y MX003 | su fila '
                'de facturas (la guarda de c3): el monto MX003, la fecha MX003, el número MX003, la retención MX003, la obra MX003, '
                'anularla a mano MX003, borrarla MX003; la casilla de pagada sí se deja | el hito, el contrato y la empresa cambian '
                'después: el mismo contenido, la misma huella, y el control del sello en verde | un borrador nuevo sí lleva el nombre nuevo';
begin
  if pg_temp.c11_omitir(19, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_r := pg_temp.c11_hito(-1110000001, jsonb_build_object('notas', 'Thank you for your business.'));
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint;
    select x.contenido, x.huella into v_c0, v_h0 from emision_documentos x where x.id = v_doc;
    a := format('cambiarla %s, tirarla %s',
                pg_temp.c11_cod(format('select fn_emision_borrador(%L)', jsonb_build_object('documento', v_doc, 'notas', 'x')::text)),
                pg_temp.c11_cod(format('select fn_emision_descartar(%L)', v_doc)));
    b := format('el documento %s, sus líneas %s y %s',
                pg_temp.c11_cod(format('update emision_documentos set monto = 1, a_pagar = 1, retencion = 0 where id = %L', v_doc)),
                pg_temp.c11_cod(format('update emision_lineas set precio = 1, importe = 1 where documento_id = %L', v_doc)),
                pg_temp.c11_cod(format('delete from emision_lineas where documento_id = %L', v_doc)));
    c := format('el monto %s, la fecha %s, el número %s, la retención %s, la obra %s, anularla a mano %s, borrarla %s; la casilla de pagada %s',
                pg_temp.c11_cod(format('update facturas set monto = monto + 1 where id = %s', v_fid)),
                pg_temp.c11_cod(format('update facturas set fecha = fecha - 1 where id = %s', v_fid)),
                pg_temp.c11_cod(format('update facturas set num = ''ZZ-X'' where id = %s', v_fid)),
                pg_temp.c11_cod(format('update facturas set retencion = 0 where id = %s', v_fid)),
                pg_temp.c11_cod(format('update facturas set proyecto_id = ''c11-prueba-b'' where id = %s', v_fid)),
                pg_temp.c11_cod(format('update facturas set estado = ''anulada'' where id = %s', v_fid)),
                pg_temp.c11_cod(format('delete from facturas where id = %s', v_fid)),
                replace(pg_temp.c11_cod(format('update facturas set pagada = true where id = %s', v_fid)), 'entró', 'sí se deja'));
    -- lo de fuera cambia después
    update hitos set monto = 9999, titulo = 'C11 PRUEBA Changed later' where id = -1110000001;
    update finanzas_proyecto set contrato = 55555 where proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_config('{"empresa": {"nombre": "ZZ Electric RENAMED, LLC"}, "como_pagar": "Check payable to ZZ Electric RENAMED, LLC."}'::jsonb);
    perform pg_temp.c11_ser('editor');
    d := case when (select x.contenido = v_c0 from emision_documentos x where x.id = v_doc) then 'el mismo contenido' else 'OTRO contenido' end
         || case when (select x.huella = v_h0 and x.huella = encode(sha256(convert_to(x.contenido::text, 'UTF8')), 'hex')
                         from emision_documentos x where x.id = v_doc) then ', la misma huella' else ', OTRA huella' end
         || ', y el control del sello en ' || pg_temp.c11_color(pg_temp.c11_ctl(30));
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    e := case when v_b->'vista_previa'->'empresa'->>'nombre' = 'ZZ Electric RENAMED, LLC' and v_c0->'empresa'->>'nombre' = 'ZZ Electric C11 PRUEBA, Inc.'
              then 'sí lleva el nombre nuevo' else 'NO lleva el nombre nuevo' end;
    v_obt := format('por sus funciones: %s | a mano, el dueño: %s | su fila de facturas (la guarda de c3): %s | el hito, el contrato y la '
                    'empresa cambian después: %s | un borrador nuevo %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. ANULAR ES NOTA DE CRÉDITO, por c3 (fn_factura_anular): la factura
--     queda anulada en el libro con su nota (NC-AAAA-NNNN) y el espejo de su
--     asiento; el documento queda marcado (con su motivo y su nota) y
--     CONSERVA su número; el hito vuelve a «pendiente»; y la buena es un
--     borrador nuevo que sale con el número SIGUIENTE.
do $$
declare
  v_obt text; e1 text; e2 text; v_r jsonb; v_doc uuid; v_fid bigint; v_ra jsonb; v_v record; v_b jsonb; v_r2 jsonb; v_s record; v_ing numeric;
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_nom text := 'ANULAR ES NOTA DE CRÉDITO (por c3): la factura queda anulada en el libro con su nota y el espejo de su asiento; el '
                'documento queda marcado y conserva su número; el hito vuelve a pendiente; la buena es un borrador nuevo con el número '
                'siguiente (el de la anulada no se reutiliza)';
  v_esp text := 'sin motivo 22023 | anulada: con su nota de crédito y su asiento, y el hito vuelve a pendiente | en el libro: la factura '
                'anulada, debe 0.00 y 0.00, y el ingreso de la obra queda en 0.00 | el documento: anulada, con su motivo y su nota, y '
                'conserva su número | otra vez: MX008 | en línea: La factura está anulada: no se cobra. | la buena: un borrador nuevo del '
                'mismo hito, emitida con el número siguiente | la serie conserva los dos números y los cuadres siguen en verde';
begin
  if pg_temp.c11_omitir(20, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    e1 := pg_temp.c11_num(1); e2 := pg_temp.c11_num(2);
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint;
    a := pg_temp.c11_cod(format('select fn_emision_anular(%L, %L)', v_doc, '  '));
    v_ra := pg_temp.c11_anular(v_doc, 'c11-pruebas: monto equivocado');
    b := case when (v_ra->>'anulada')::boolean and v_ra->>'nota_credito' ~ '^NC-[0-9]{4}-[0-9]{4}$'
                   and v_ra->>'nota_credito' = (select n.numero from notas_credito n where n.anula_a = v_fid)
                   and v_ra->>'asiento' is not null and v_ra->>'asiento' <> v_r->>'asiento' and v_ra->>'numero' = e1
              then 'con su nota de crédito y su asiento' else 'MAL: ' || v_ra::text end
         || case when v_ra->>'hito_estado' = 'pendiente' and (select x.estado from hitos x where x.id = -1110000001) = 'pendiente'
                 then ', y el hito vuelve a pendiente' else ', y el hito NO vuelve' end;
    select * into v_s from fn_emision_saldo(v_fid);
    select coalesce(sum(l.monto), 0) into v_ing
      from asiento_lineas l join cuentas k on k.codigo = l.cuenta
     where l.proyecto_id = 'c11-prueba-a' and k.tipo in ('ingreso', 'otro_ingreso');
    c := format('la factura %s, debe %s y %s, y el ingreso de la obra queda en %s',
                (select f.estado from facturas f where f.id = v_fid), v_s.cxc, v_s.retencion, v_ing);
    select * into v_v from v_emision_documentos x where x.id = v_doc;
    d := case when v_v.estado = 'anulada' and v_v.anulado_motivo = 'c11-pruebas: monto equivocado' and v_v.nota_credito = v_ra->>'nota_credito'
                   and v_v.anulado_el is not null
              then 'anulada, con su motivo y su nota' else 'MAL: ' || to_jsonb(v_v)::text end
         || case when v_v.numero = e1 then ', y conserva su número' else ', y PERDIÓ su número' end;
    e := pg_temp.c11_cod(format('select fn_emision_anular(%L, %L)', v_doc, 'otra vez'));
    perform pg_temp.c11_ser('dueno');
    f := fn_emision_pago(v_doc)->>'por_que_no';
    perform pg_temp.c11_ser('editor');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    v_r2 := pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    g := case when (v_b->>'nuevo')::boolean and v_b->'documento'->>'id' <> v_doc::text then 'un borrador nuevo del mismo hito' else 'NO es nuevo' end
         || case when v_r2->>'numero' = e2 then ', emitida con el número siguiente' else ', emitida con ' || (v_r2->>'numero') end;
    h := case when (select count(*) from emision_serie s where s.numero in (e1, e2)) = 2 then 'la serie conserva los dos números'
              else 'la serie NO conserva los dos' end
         || ' y los cuadres '
         || coalesce((select 'en ROJO: ' || string_agg(k.orden::text, ',' order by k.orden) from v_emision_control k where k.nivel = 'cuadre' and not k.ok),
                     'siguen en verde');
    v_obt := format('sin motivo %s | anulada: %s | en el libro: %s | el documento: %s | otra vez: %s | en línea: %s | la buena: %s | %s',
                    a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. ANULADA DESDE CONTABILIDAD (c3 directo, sin pasar por aquí): la lista
--     la enseña anulada, el control 75 avisa de que aquí sigue abierta y su
--     hito sigue «facturado»; Anular aquí la termina (con la misma nota) y
--     suelta el hito. Y CON UN COBRO APLICADO no se anula: el freno es de c3,
--     pero aquí se dice en llano y con qué hacer (sin nombres de funciones;
--     la nota de crédito por una parte todavía no existe), y nada cambia.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_doc1 uuid; v_fid1 bigint; v_doc2 uuid; v_fid2 bigint; v_ra jsonb; v_x text; v_nc text;
  a text; b text; c text;
  v_nom text := 'ANULADA DESDE CONTABILIDAD (c3 directo): la lista la enseña anulada, el control avisa de que aquí sigue abierta y su hito '
                'sigue facturado; Anular aquí la termina con la misma nota y suelta el hito. CON UN COBRO APLICADO no se anula (el freno '
                'de c3, dicho en llano y con qué hacer) y nada cambia';
  v_esp text := 'anulada desde Contabilidad: aquí sale anulada, sin cerrar; el control 75 avisa (anulada en el libro y aquí sigue como '
                'emitida) y el hito sigue facturado | Anular aquí la termina: ya estaba en el libro, con la misma nota de crédito, el hito a '
                'pendiente y el aviso se va | con un cobro de 1000.00 aplicado: MX008 (en llano: tiene cobros aplicados por $1,000.00 y '
                'primero se anula ese cobro) y nada cambia: sigue emitida, debe 2333.33, el hito facturado';
begin
  if pg_temp.c11_omitir(21, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(21, v_nom, v_esp, array[75]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    r1 := pg_temp.c11_hito(-1110000001);
    v_doc1 := (r1->>'documento')::uuid; v_fid1 := (r1->>'factura_id')::bigint;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_fid1, 'c11-pruebas: desde Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    select n.numero into v_nc from notas_credito n where n.anula_a = v_fid1;
    v_x := pg_temp.c11_ctl(75);
    a := case when (select x.estado from v_emision_documentos x where x.id = v_doc1) = 'anulada'
                   and (select x.anulado_el is null from emision_documentos x where x.id = v_doc1)
              then 'aquí sale anulada, sin cerrar' else 'aquí NO sale anulada' end
         || case when v_x like 'rojo: la factura ' || (r1->>'numero') || ' está anulada en el libro y aquí sigue como emitida%'
                 then '; el control 75 avisa (anulada en el libro y aquí sigue como emitida)' else '; el control 75: ' || v_x end
         || format(' y el hito sigue %s', (select h.estado from hitos h where h.id = -1110000001));
    v_ra := pg_temp.c11_anular(v_doc1, 'c11-pruebas: se anuló en Contabilidad');
    b := case when (v_ra->>'ya_estaba_en_el_libro')::boolean then 'ya estaba en el libro' else 'NO dice que ya estaba' end
         || case when v_ra->>'nota_credito' = v_nc and (select count(*) from notas_credito n where n.anula_a = v_fid1) = 1
                 then ', con la misma nota de crédito' else ', con OTRA nota' end
         || format(', el hito a %s y el aviso %s', v_ra->>'hito_estado',
                   case when pg_temp.c11_ctl(75) = 'verde' then 'se va' else 'SIGUE' end);
    -- con un cobro aplicado
    r2 := pg_temp.c11_hito(-1110000002);
    v_doc2 := (r2->>'documento')::uuid; v_fid2 := (r2->>'factura_id')::bigint;
    perform pg_temp.c11_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c11('hoy'), 'monto', '1000.00', 'medio', 'cheque', 'referencia', 'C11-PRUEBA-21',
                                                  'duplicado_confirmado', 'c11-pruebas: un cobro de prueba',
                                                  'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', v_fid2, 'monto', '1000.00'))));
    perform pg_temp.c11_ser('editor');
    v_x := pg_temp.c11_err(format('select fn_emision_anular(%L, %L)', v_doc2, 'c11-pruebas: con cobros'));
    c := case when v_x like 'MX008: La factura ' || (r2->>'numero') || ' tiene cobros aplicados por $1,000.00: así no se anula entera%'
                   and v_x like '%Primero hay que anular ese cobro en el libro%' and v_x !~ 'fn_'
              then 'MX008 (en llano: tiene cobros aplicados por $1,000.00 y primero se anula ese cobro)' else v_x end
         || format(' y nada cambia: sigue %s, debe %s, el hito %s',
                   (select x.estado from v_emision_documentos x where x.id = v_doc2), (select s.cxc from fn_emision_saldo(v_fid2) s),
                   (select h.estado from hitos h where h.id = -1110000002));
    v_obt := format('anulada desde Contabilidad: %s | Anular aquí la termina: %s | con un cobro de 1000.00 aplicado: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 22. POR PORCENTAJE Y T&M, EMITIDAS: sus asientos al centavo. La de
--     porcentaje (el 25 % de 18,500.55 = 4,625.14, con el 10 % de la obra:
--     462.51) no mueve ningún hito. La T&M congela sus cuatro líneas con su
--     cantidad, su unidad y su precio.
do $$
declare
  v_obt text; v_b jsonb; r1 jsonb; r2 jsonb; v_c jsonb;
  a text; b text; c text;
  v_nom text := 'POR PORCENTAJE Y T&M, EMITIDAS: la de porcentaje (25 % de 18,500.55 = 4,625.14; 10 % retenido = 462.51) con su asiento al '
                'centavo y sin mover ningún hito; la T&M (1,234.57) con su asiento y sus cuatro líneas congeladas con cantidad, unidad y '
                'precio';
  v_esp text := 'por porcentaje (el 25 % de 18500.55, con el 10 % de la obra): 4625.14 − 462.51 = 4162.63; asiento cxc 4162.63 | ret 462.51 | '
                'ingreso -4625.14; sin hito, y el hito de la obra sigue pendiente; dice el 25.0 % del contrato | T&M: 1234.57; asiento cxc '
                '1234.57 | ingreso -1234.57; sus cuatro líneas congeladas (7.25 hr × 95.00 = 688.75; 1 — × 412.37 = 412.37; 3.5 hr × '
                '47.333 = 165.67; 1 — × -32.22 = -32.22) | los cuadres de la facturación: en verde';
begin
  if pg_temp.c11_omitir(22, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'porcentaje', 'proyecto_id', 'c11-prueba-b', 'porcentaje', 25));
    r1 := pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    select x.contenido into v_c from emision_documentos x where x.id = (r1->>'documento')::uuid;
    a := format('%s − %s = %s; asiento %s; %s; dice el %s %% del contrato', r1->>'monto', r1->>'retencion', r1->>'a_pagar',
                pg_temp.c11_asiento((r1->>'factura_id')::bigint),
                case when (select f.hito_id is null from facturas f where f.id = (r1->>'factura_id')::bigint) and not r1 ? 'hito_estado'
                          and (select h.estado from hitos h where h.id = -1110000006) = 'pendiente'
                     then 'sin hito, y el hito de la obra sigue pendiente' else 'MOVIÓ un hito' end,
                v_c->'contrato'->>'pct');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'tm', 'proyecto_id', 'c11-prueba-d', 'lineas', jsonb_build_array(
      jsonb_build_object('tipo', 'horas', 'descripcion', 'Electrician labor', 'cantidad', 7.25, 'unidad', 'hr', 'precio', 95),
      jsonb_build_object('tipo', 'material', 'descripcion', 'Materials (wire, boxes, breakers)', 'cantidad', 1, 'precio', 412.37),
      jsonb_build_object('tipo', 'horas', 'descripcion', 'Apprentice labor', 'cantidad', 3.5, 'unidad', 'hr', 'precio', 47.333),
      jsonb_build_object('descripcion', 'Courtesy discount', 'precio', -32.22))));
    r2 := pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    select x.contenido into v_c from emision_documentos x where x.id = (r2->>'documento')::uuid;
    b := format('%s; asiento %s; sus cuatro líneas congeladas (%s)', r2->>'monto', pg_temp.c11_asiento((r2->>'factura_id')::bigint),
                (select string_agg(format('%s %s × %s = %s', l->>'cantidad', coalesce(l->>'unidad', '—'), l->>'precio', l->>'importe'), '; '
                                   order by (l->>'n')::int)
                   from jsonb_array_elements(v_c->'lineas') l));
    select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'en verde') into c from v_emision_control k where k.nivel = 'cuadre' and not k.ok;
    v_obt := format('por porcentaje (el 25 %% de 18500.55, con el 10 %% de la obra): %s | T&M: %s | los cuadres de la facturación: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. EL HITO DE DEPÓSITO se factura como los demás (su asiento, su hito a
--     facturado) y el documento DICE que es el depósito (es_deposito), en el
--     borrador, en lo congelado y en las listas: es lo que la capa del WIP
--     (c12) lee para tratarlo como anticipo y no como avance.
do $$
declare
  v_obt text; v_b jsonb; v_r jsonb; v_doc uuid; v_h jsonb;
  a text; b text; c text; d text;
  v_nom text := 'EL HITO DE DEPÓSITO se factura como los demás (su asiento, su hito a facturado) y el documento dice que es el depósito '
                '(es_deposito) en el borrador, en lo congelado y en las listas; el otro hito de la obra, no';
  v_esp text := 'el borrador dice que es el depósito | emitida: 1234.57, asiento cxc 1234.57 | ingreso -1234.57, el hito facturado | el '
                'documento congelado y la lista lo marcan como depósito | en la obra: el depósito con su factura (ya no se puede facturar) '
                'y el otro hito, que no es depósito, por facturar';
begin
  if pg_temp.c11_omitir(23, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000004));
    v_doc := (v_b->'documento'->>'id')::uuid;
    a := case when (v_b->'documento'->>'es_deposito')::boolean and (v_b->'vista_previa'->'hito'->>'es_deposito')::boolean
              then 'el borrador dice que es el depósito' else 'el borrador NO lo dice' end;
    v_r := pg_temp.c11_emitir(v_doc);
    b := format('emitida: %s, asiento %s, el hito %s', v_r->>'monto', pg_temp.c11_asiento((v_r->>'factura_id')::bigint), v_r->>'hito_estado');
    c := case when (select (x.contenido->'hito'->>'es_deposito')::boolean and x.es_deposito from emision_documentos x where x.id = v_doc)
                   and (select x.es_deposito from v_emision_documentos x where x.id = v_doc)
              then 'el documento congelado y la lista lo marcan como depósito' else 'NO lo marcan' end;
    select o.hitos into v_h from v_emision_obras o where o.proyecto_id = 'c11-prueba-c';
    d := case when jsonb_array_length(v_h) = 2
                   and (v_h->0->>'id')::bigint = -1110000004 and (v_h->0->>'es_deposito')::boolean and v_h->0->>'factura' = v_r->>'numero'
                   and not (v_h->0->>'puede')::boolean and v_h->0->>'estado' = 'facturado'
                   and (v_h->1->>'id')::bigint = -1110000005 and not (v_h->1->>'es_deposito')::boolean and (v_h->1->>'puede')::boolean
                   and v_h->1->>'factura' is null
              then 'el depósito con su factura (ya no se puede facturar) y el otro hito, que no es depósito, por facturar'
              else 'MAL: ' || v_h::text end;
    v_obt := format('%s | %s | %s | en la obra: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. A UN CONTRATISTA. Una obra por contrato con un contratista se le
--     factura a él (a la atención de su contacto, a su correo), y la fila de
--     facturas lo dice (a_contratista). Sin retención avisa (no frena). Si
--     el contacto de la obra cambia, avisa; si la obra cambia de
--     destinatario (pasa a referido), el borrador lo dice (frena, MX011) y
--     al refrescar se le factura al cliente.
do $$
declare
  v_obt text; v_no text; v_dest jsonb; v_b jsonb; v_doc uuid; v_r jsonb; v_x text;
  a text; b text; c text; d text; e text;
  v_nom text := 'A UN CONTRATISTA: la obra por contrato con un contratista se le factura a él (a su contacto y su correo) y la fila de '
                'facturas lo dice; sin retención avisa y no frena; si cambia el contacto, avisa; si la obra cambia de destinatario el '
                'borrador lo dice (frena, MX011) y al refrescar va a quien toca';
  v_esp text := 'la obra por contrato con un contratista: se le factura a él, a la atención de su contacto y a su correo | el borrador: al '
                'contratista; sin retención avisa y no frena; con el 10 % de la obra retiene 123.46 y ya no avisa | el contacto de la obra '
                'cambia: avisa que no es lo que tiene la obra (no frena), y con cliente null toma el nuevo | la obra pasa a referido: lo '
                'dice (destinatario_cambio, frena), emitir MX011, y al refrescar va al cliente de la obra; de vuelta a contrato, al '
                'contratista | emitida: la fila de facturas va al contratista, el documento a su nombre, y su asiento cxc 1111.11 | ret '
                '123.46 | ingreso -1234.57';
begin
  if pg_temp.c11_omitir(24, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_no := pg_temp.c11_contratista();
    if v_no is not null then
      v_obt := 'omitida: ' || v_no;
      raise exception using errcode = 'MXT00';
    end if;
    v_dest := fn_emision_destinatario('c11-prueba-b');
    a := case when (v_dest->>'a_contratista')::boolean
                   and v_dest->'cliente' = jsonb_build_object('nombre', 'ZZ General Contractor C11 PRUEBA', 'atencion', 'Zz Contact',
                                                              'correo', 'zz.gc@c11-pruebas.invalid')
              then 'se le factura a él, a la atención de su contacto y a su correo' else 'MAL: ' || v_dest::text end;
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000006));
    v_doc := (v_b->'documento'->>'id')::uuid;
    b := case when (v_b->'documento'->>'a_contratista')::boolean and v_b->'documento'->'cliente'->>'nombre' = 'ZZ General Contractor C11 PRUEBA'
              then 'al contratista' else 'NO al contratista' end
         || case when (v_b->>'puede_emitir')::boolean
                      and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'contratista_sin_retencion' and not (x->>'frena')::boolean)
                 then '; sin retención avisa y no frena' else '; sin retención NO avisa' end;
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    v_b := fn_emision_borrador(jsonb_build_object('documento', v_doc));
    perform pg_temp.c11_ser('editor');
    b := b || format('; con el 10 %% de la obra retiene %s y %s', v_b->'documento'->>'retencion',
                     case when not exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'contratista_sin_retencion')
                          then 'ya no avisa' else 'SIGUE avisando' end);
    -- el contacto de la obra cambia
    update proyectos set contratista_contacto = 'ZZ Project Manager' where id = 'c11-prueba-b';
    v_b := fn_emision_documento(v_doc);
    c := case when (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'cliente_distinto' and not (x->>'frena')::boolean)
              then 'avisa que no es lo que tiene la obra (no frena)' else 'NO avisa' end;
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'cliente', null));
    c := c || case when v_b->'documento'->'cliente'->>'atencion' = 'ZZ Project Manager'
                        and not exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'cliente_distinto')
                   then ', y con cliente null toma el nuevo' else ', y con cliente null NO lo toma' end;
    -- la obra cambia de destinatario
    update proyectos set contratista_modo = 'referido' where id = 'c11-prueba-b';
    v_b := fn_emision_documento(v_doc);
    d := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'destinatario_cambio' and (x->>'frena')::boolean)
              then 'lo dice (destinatario_cambio, frena)' else 'NO lo dice' end
         || ', emitir ' || pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc, v_b->>'visto'));
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    d := d || case when not (v_b->'documento'->>'a_contratista')::boolean and v_b->'documento'->'cliente'->>'nombre' = 'ZZ Cliente Dos'
                   then ', y al refrescar va al cliente de la obra' else ', y al refrescar NO va al cliente' end;
    update proyectos set contratista_modo = 'contrato' where id = 'c11-prueba-b';
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    d := d || case when (v_b->'documento'->>'a_contratista')::boolean and v_b->'documento'->'cliente'->>'nombre' = 'ZZ General Contractor C11 PRUEBA'
                        and (v_b->>'puede_emitir')::boolean
                   then '; de vuelta a contrato, al contratista' else '; de vuelta a contrato, NO al contratista' end;
    v_r := pg_temp.c11_emitir(v_doc);
    e := case when (select f.a_contratista from facturas f where f.id = (v_r->>'factura_id')::bigint) then 'la fila de facturas va al contratista'
              else 'la fila de facturas NO va al contratista' end
         || case when (select (x.contenido->>'a_contratista')::boolean and x.contenido->'cliente'->>'nombre' = 'ZZ General Contractor C11 PRUEBA'
                              and x.contenido->'cliente'->>'atencion' = 'ZZ Project Manager' and x.contenido->'obra'->>'nombre' = 'C11 PRUEBA Dos'
                         from emision_documentos x where x.id = v_doc)
                 then ', el documento a su nombre' else ', el documento NO a su nombre' end
         || ', y su asiento ' || pg_temp.c11_asiento((v_r->>'factura_id')::bigint);
    v_obt := format('la obra por contrato con un contratista: %s | el borrador: %s | el contacto de la obra cambia: %s | la obra pasa a '
                    'referido: %s | emitida: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 25. LA FACTURA DE LA RETENCIÓN (la que cobra lo retenido al final de la
--     obra). Lista lo que cada factura de la obra tiene abierto en la
--     retención por cobrar del LIBRO, con su número; lleva número de SU
--     serie (MXP-R-AAAA-NNNN: no gasta uno de la serie de las facturas, que
--     así no tiene números sin fila de facturas) y NO lleva fila de facturas
--     ni asiento (el ingreso ya entró con cada factura: el libro no cambia);
--     su contenido cita las facturas que reclama (lo que el cliente pone al
--     pagar). Si entra un cobro de retención entre
--     el borrador y la emisión, lo dice (MX011). No se reclama dos veces.
--     Anulada, lo retenido se puede volver a reclamar.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_b jsonb; v_doc uuid; v_rr jsonb; v_x text; v_as bigint; v_fa bigint; e4 text; v_ra jsonb; v_p jsonb;
  v_n0 bigint; e5 text; r4 jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text; k text;
  v_nom text := 'LA FACTURA DE LA RETENCIÓN: lista lo que cada factura de la obra tiene abierto en la retención por cobrar del libro, con '
                'su número; lleva número de SU serie (no gasta uno de la de las facturas) y no lleva fila de facturas ni asiento; un cobro de '
                'retención entre el borrador y la emisión se dice (MX011); no se reclama dos veces; mientras vive, las facturas que reclama '
                'no se anulan desde aquí (y si se anulan desde Contabilidad, el control avisa); anulada, se puede volver a reclamar';
  v_esp text := 'tres facturas retienen 333.33, 333.33 y 333.33 | el borrador de la retención: 3 líneas (una por factura, con su número) que '
                'suman 999.99, sin retención propia, y uno por obra | entra el cobro de la retención de la primera: el borrador lo dice '
                '(retencion_cambio, frena), emitir MX011, y al refrescar 2 líneas, 666.66 | emitida: con su propio número, de la serie de '
                'las facturas de la retención, sin fila de facturas ni asiento (el libro no cambia), el contador de las facturas no se '
                'mueve y su contenido cita las facturas que reclama | no se reclama dos veces: MX008 (dice su número) | sin enlace '
                'de pago propio | anular una factura que ella reclama: MX008 (dice cuál la reclama) | si esa factura se anula desde '
                'Contabilidad: el control 75 avisa (la de la retención reclama lo de una anulada) | anulada, sin asiento que deshacer: el '
                'aviso se va, y lo retenido que queda se puede volver a reclamar (1 líneas, 333.33) | los cuadres de la facturación: en verde '
                '| la siguiente factura: seguida en su serie, y cada número de la serie de las facturas es una fila de facturas';
begin
  if pg_temp.c11_omitir(25, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002); r3 := pg_temp.c11_hito(-1110000003);
    a := format('tres facturas retienen %s, %s y %s', r1->>'retencion', r2->>'retencion', r3->>'retencion');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'retencion', 'proyecto_id', 'c11-prueba-a'));
    v_doc := (v_b->'documento'->>'id')::uuid;
    b := format('%s líneas (%s) que suman %s, %s, y %s', jsonb_array_length(v_b->'lineas'),
                case when (select bool_and(l->>'tipo' = 'retencion' and (l->>'importe')::numeric = 333.33
                                           and l->>'descripcion' like 'Retainage withheld on invoice ' || (l->'ref'->>'numero') || ' (%')
                             from jsonb_array_elements(v_b->'lineas') l)
                          and (select array_agg(l->'ref'->>'numero' order by (l->>'n')::int) from jsonb_array_elements(v_b->'lineas') l)
                              = array[r1->>'numero', r2->>'numero', r3->>'numero']
                          and (select array_agg((l->'ref'->>'factura_id')::bigint order by (l->>'n')::int) from jsonb_array_elements(v_b->'lineas') l)
                              = array[(r1->>'factura_id')::bigint, (r2->>'factura_id')::bigint, (r3->>'factura_id')::bigint]
                     then 'una por factura, con su número' else 'MAL: ' || left((v_b->'lineas')::text, 300) end,
                v_b->'documento'->>'monto',
                case when (v_b->'documento'->>'retencion')::numeric = 0 and (v_b->'documento'->>'a_pagar')::numeric = 999.99
                          and (v_b->'documento'->>'retencion_pct')::numeric = 0 then 'sin retención propia' else 'CON retención propia' end,
                case when not (pg_temp.c11_borrador(jsonb_build_object('forma', 'retencion', 'proyecto_id', 'c11-prueba-a'))->>'nuevo')::boolean
                          and (select count(*) from emision_documentos x where x.proyecto_id = 'c11-prueba-a' and x.forma = 'retencion') = 1
                     then 'uno por obra' else 'DOS por obra' end);
    -- entra el cobro de la retención de la primera
    perform pg_temp.c11_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c11('hoy'), 'monto', '333.33', 'medio', 'cheque', 'referencia', 'C11-PRUEBA-25',
              'duplicado_confirmado', 'c11-pruebas: un cobro de prueba',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', (r1->>'factura_id')::bigint, 'monto', '333.33', 'es_retencion', true))));
    v_b := fn_emision_documento(v_doc);
    perform pg_temp.c11_ser('editor');
    c := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'retencion_cambio' and (x->>'frena')::boolean)
              then 'el borrador lo dice (retencion_cambio, frena)' else 'el borrador NO lo dice' end
         || ', emitir ' || pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc, v_b->>'visto'));
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc));
    c := c || format(', y al refrescar %s líneas, %s', jsonb_array_length(v_b->'lineas'), v_b->'documento'->>'monto');
    -- emitida
    select count(*) into v_as from asientos; select count(*) into v_fa from facturas;
    e4 := pg_temp.c11_num_ret(1); v_n0 := pg_temp.c11_contador();
    v_rr := pg_temp.c11_emitir(v_doc);
    d := case when v_rr->>'numero' = e4 and e4 ~ '^[A-Z0-9]+-R-[0-9]{4}-[0-9]{4,}$' then 'con su propio número, de la serie de las facturas de la retención'
              else 'con ' || (v_rr->>'numero') end
         || case when not v_rr ? 'factura_id' and not v_rr ? 'asiento' and (select count(*) from asientos) = v_as
                      and (select count(*) from facturas) = v_fa
                      and (select x.factura_id is null and x.asiento_id is null and x.contenido->>'forma' = 'retencion'
                                  and x.contenido->'totales'->>'a_pagar' = '666.66' and not x.contenido ? 'ordinal'
                             from emision_documentos x where x.id = v_doc)
                 then ', sin fila de facturas ni asiento (el libro no cambia)' else ', y CAMBIÓ el libro' end
         || case when pg_temp.c11_contador() = v_n0 then ', el contador de las facturas no se mueve' else ', y MOVIÓ el contador de las facturas' end
         || case when (select x.contenido->'referencias' from emision_documentos x where x.id = v_doc) = jsonb_build_array(r2->>'numero', r3->>'numero')
                 then ' y su contenido cita las facturas que reclama' else ' y su contenido NO cita las facturas que reclama' end;
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "retencion", "proyecto_id": "c11-prueba-a"}') $q$);
    e := case when v_x like 'MX008: La obra «C11 PRUEBA Uno» no tiene retención por cobrar que reclamar: lo retenido ya está reclamado en ' || e4 || '.'
              then 'MX008 (dice su número)' else v_x end;
    perform pg_temp.c11_ser('dueno');
    v_p := fn_emision_pago(v_doc);
    perform pg_temp.c11_ser('editor');
    f := case when not (v_p->>'en_linea')::boolean and v_p->>'por_que_no' like 'La factura de la retención no lleva enlace propio%'
              then 'sin enlace de pago propio' else 'MAL: ' || v_p::text end;
    -- una factura que ella reclama no se anula desde aquí; y si se anula desde Contabilidad, el control lo avisa
    v_x := pg_temp.c11_err(format('select fn_emision_anular(%L, %L)', (r2->>'documento')::uuid, 'c11-pruebas: con su retención reclamada'));
    i := case when v_x like 'MX008: Lo retenido de la factura ' || (r2->>'numero') || ' está reclamado en la factura de la retención ' || e4 || ':%'
              then 'MX008 (dice cuál la reclama)' else v_x end;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular((r3->>'factura_id')::bigint, 'c11-pruebas: desde Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    v_x := pg_temp.c11_ctl(75);
    j := case when v_x like 'rojo: %la factura de la retención ' || e4 || ' reclama lo retenido de la factura ' || (r3->>'numero') || ', que está anulada%'
              then 'el control 75 avisa (la de la retención reclama lo de una anulada)' else 'el control 75: ' || v_x end;
    v_ra := pg_temp.c11_anular(v_doc, 'c11-pruebas: una de sus facturas se anuló');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'retencion', 'proyecto_id', 'c11-prueba-a'));
    g := case when (v_ra->>'anulada')::boolean and v_ra ? 'sin_asiento' and not v_ra ? 'nota_credito' and not v_ra ? 'asiento'
                   and (select x.estado from v_emision_documentos x where x.id = v_doc) = 'anulada'
              then 'anulada, sin asiento que deshacer' else 'MAL: ' || v_ra::text end
         || case when position('la factura de la retención ' || e4 in pg_temp.c11_ctl(75)) = 0 then ': el aviso se va' else ': el aviso SIGUE' end
         || format(', y lo retenido que queda se puede volver a reclamar (%s líneas, %s)', jsonb_array_length(v_b->'lineas'), v_b->'documento'->>'monto');
    select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'en verde') into h from v_emision_control k where k.nivel = 'cuadre' and not k.ok;
    -- la serie de las facturas no se enteró: la siguiente factura va seguida, y cada número de esa serie es una fila de facturas
    e5 := pg_temp.c11_num(1);
    r4 := pg_temp.c11_hito(-1110000006);
    k := case when r4->>'numero' = e5 then 'seguida en su serie' else 'con ' || (r4->>'numero') || ' y debía ser ' || e5 end
         || case when not exists (select 1 from emision_serie s where s.serie = 'facturas' and not exists (select 1 from facturas f where f.num = s.numero))
                      and not exists (select 1 from emision_serie s join emision_documentos x on x.id = s.documento_id
                                       where (s.serie = 'retenciones') <> (x.forma = 'retencion'))
                 then ', y cada número de la serie de las facturas es una fila de facturas' else ', y HAY un número de la serie de las facturas sin fila de facturas' end;
    v_obt := format('%s | el borrador de la retención: %s | entra el cobro de la retención de la primera: %s | emitida: %s | no se reclama dos '
                    'veces: %s | %s | anular una factura que ella reclama: %s | si esa factura se anula desde Contabilidad: %s | %s | los '
                    'cuadres de la facturación: %s | la siguiente factura: %s', a, b, c, d, e, f, i, j, g, h, k);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. EL CONTENIDO CONGELADO: lo que recibe el cliente, entero, en un jsonb
--     del que se pinta el PDF. La vista previa del borrador es ESO mismo sin
--     número: al emitir se congela lo que Edgar vio. Los montos van como
--     texto de dos decimales (nadie los vuelve a sumar ni a redondear). La
--     huella es el sha256 de ese texto.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; vp jsonb; v_r jsonb; v_c jsonb; v_h text; r2 jsonb; c2 jsonb;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'EL CONTENIDO CONGELADO (de él se pinta el PDF): la vista previa del borrador trae la empresa, a quién, la obra, el hito, '
                'las líneas, los totales con la retención, el contrato y lo facturado, cómo pagar y las notas; al emitir se congela ESO con '
                'su número; los montos van como texto de dos decimales; la huella es su sha256';
  v_esp text := 'la vista previa: sin número, de hoy, Due on receipt, con la empresa, el cliente, la obra, el hito, la línea (1 × 3333.33), '
                'los totales (3333.33 − 333.33 al 10 % = 3000.00; retenido a la fecha 333.33), el contrato (10000.00; con esta 3333.33, el '
                '33.3 %), cómo pagar, el pago en línea (solo por cuenta de banco: no ofrece tarjeta) y las notas | al emitir se congela '
                'ESO, con su número | la huella es el sha256 del '
                'contenido | los montos van como texto de dos decimales | sus claves: a_contratista, cliente, como_pagar, contrato, '
                'empresa, fecha, forma, hito, lineas, notas, numero, obra, ordinal, pago_en_linea, terminos, totales, v, vence | la segunda, '
                'a 30 días: Net 30, vence en 30 días, con sus términos escritos, es la 2, antes 3333.33, retenido a la fecha 666.66';
begin
  if pg_temp.c11_omitir(26, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001, 'notas', 'Thank you for your business.'));
    v_doc := (v_b->'documento'->>'id')::uuid; vp := v_b->'vista_previa';
    a := concat_ws(', ',
           case when not vp ? 'numero' then 'sin número' else 'CON número' end,
           case when vp->>'fecha' = pg_temp.c11('hoy') and vp->>'vence' = pg_temp.c11('hoy') then 'de hoy' else 'de OTRO día' end,
           case when vp->'terminos' = '{"dias": 0, "etiqueta": "Due on receipt"}'::jsonb then 'Due on receipt' else (vp->'terminos')::text end,
           case when vp->'empresa' = (select k.empresa from emision_config k where k.id = 1) and vp->'empresa'->>'nombre' = 'ZZ Electric C11 PRUEBA, Inc.'
                then 'con la empresa' else 'SIN la empresa' end,
           case when vp->'cliente' = v_b->'documento'->'cliente' and vp->'cliente'->>'nombre' = 'ZZ Cliente Uno' and not (vp->>'a_contratista')::boolean
                then 'el cliente' else 'SIN el cliente' end,
           case when vp->'obra' = '{"id": "c11-prueba-a", "nombre": "C11 PRUEBA Uno", "direccion": "1 ZZ Test Rd, Testville, FL 00000"}'::jsonb
                then 'la obra' else 'SIN la obra' end,
           case when vp->'hito' = '{"id": -1110000001, "titulo": "C11 PRUEBA Milestone 1", "es_deposito": false}'::jsonb and vp->>'ordinal' = '1'
                     and vp->>'forma' = 'hito' and vp->>'v' = '1'
                then 'el hito' else 'SIN el hito' end,
           case when vp->'lineas' = '[{"n": 1, "tipo": "hito", "descripcion": "C11 PRUEBA Milestone 1", "detalle": "Due upon passing the rough-in inspection", "cantidad": "1", "precio": "3333.33", "importe": "3333.33", "ref": {"hito_id": -1110000001}}]'::jsonb
                then 'la línea (1 × 3333.33)' else 'OTRA línea: ' || (vp->'lineas')::text end,
           case when vp->'totales' = '{"subtotal": "3333.33", "retencion_pct": "10", "retencion": "333.33", "a_pagar": "3000.00", "retenido_a_la_fecha": "333.33"}'::jsonb
                then 'los totales (3333.33 − 333.33 al 10 % = 3000.00; retenido a la fecha 333.33)' else 'OTROS totales: ' || (vp->'totales')::text end,
           case when vp->'contrato' = '{"monto": "10000.00", "facturado_antes": "0.00", "esta": "3333.33", "facturado_con_esta": "3333.33", "pct": "33.3"}'::jsonb
                then 'el contrato (10000.00; con esta 3333.33, el 33.3 %)' else 'OTRO contrato: ' || (vp->'contrato')::text end,
           case when vp->>'como_pagar' like 'Check payable to ZZ Electric C11 PRUEBA, Inc.%' then 'cómo pagar' else 'SIN cómo pagar' end,
           case when vp->'pago_en_linea' = jsonb_build_object('ach', pg_temp.c11('hay_p1') = 'true', 'tarjeta', false)
                                           || case when pg_temp.c11('hay_p1') = 'true'
                                                   then jsonb_build_object('texto', 'Online payment is by bank account (ACH) only.')
                                                   else '{}'::jsonb end
                then 'el pago en línea (solo por cuenta de banco: no ofrece tarjeta)'
                else 'OTRO pago en línea: ' || (vp->'pago_en_linea')::text end)
         || case when vp->>'notas' = 'Thank you for your business.' then ' y las notas' else ' y SIN las notas' end;
    v_r := pg_temp.c11_emitir(v_doc);
    select x.contenido, x.huella into v_c, v_h from emision_documentos x where x.id = v_doc;
    b := case when (v_c - 'numero') = vp and v_c->>'numero' = v_r->>'numero' then 'al emitir se congela ESO, con su número'
              else 'al emitir se congela OTRA cosa' end;
    c := case when v_h = encode(sha256(convert_to(v_c::text, 'UTF8')), 'hex') and v_h = v_r->>'huella' then 'la huella es el sha256 del contenido'
              else 'la huella NO es el sha256 del contenido' end;
    d := case when (select bool_and(x.v ~ '^-?[0-9]+\.[0-9]{2}$')
                      from (select t.value as v from jsonb_each_text(v_c->'totales') t where t.key <> 'retencion_pct'
                            union all select t.value from jsonb_each_text(v_c->'contrato') t where t.key <> 'pct'
                            union all select l->>'precio' from jsonb_array_elements(v_c->'lineas') l
                            union all select l->>'importe' from jsonb_array_elements(v_c->'lineas') l) x)
              then 'los montos van como texto de dos decimales' else 'algún monto NO va como texto de dos decimales' end;
    select 'sus claves: ' || string_agg(k, ', ' order by k) into e from jsonb_object_keys(v_c) k;
    -- la segunda, a 30 días
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_config('{"terminos_dias": 30, "terminos_texto": "Payment due within 30 days of the invoice date."}'::jsonb);
    perform pg_temp.c11_ser('editor');
    r2 := pg_temp.c11_hito(-1110000002);
    select x.contenido into c2 from emision_documentos x where x.id = (r2->>'documento')::uuid;
    f := format('%s, vence en %s días, %s, es la %s, antes %s, retenido a la fecha %s', c2->'terminos'->>'etiqueta',
                (c2->>'vence')::date - (c2->>'fecha')::date,
                case when c2->'terminos'->>'texto' = 'Payment due within 30 days of the invoice date.' and (r2->>'vence')::date = pg_temp.c11('hoy')::date + 30
                     then 'con sus términos escritos' else 'SIN sus términos' end,
                c2->>'ordinal', c2->'contrato'->>'facturado_antes', c2->'totales'->>'retenido_a_la_fecha');
    v_obt := format('la vista previa: %s | %s | %s | %s | %s | la segunda, a 30 días: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. EL IDIOMA. Todo lo que ve el cliente va en inglés. La base no sabe
--     inglés: mira si un texto PARECE español y entonces no emite hasta que
--     Edgar lo escriba en inglés o confirme que está bien así. Una ayuda, no
--     una garantía.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; v_r jsonb;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'EL IDIOMA: lo que ve el cliente va en inglés; si una línea, las notas o el «How to pay» parecen español, el borrador lo '
                'dice y no se emite (MX008) hasta que se escriba en inglés o Edgar confirme que está bien así (idioma_revisado)';
  v_esp text := 'parece español: «Trabajo de rough-in terminado» sí, «¿Listo?» sí, «Pago por el trabajo de la casa» sí; «Rough-in complete» '
                'no, «Final inspection passed» no, «Panel upgrade per contract» no | un hito con el título en español: el borrador lo dice '
                '(frena: una línea) y emitir da MX008 | con las notas en español: las notas, una línea | escrito en inglés: deja emitir | o '
                'confirmando que está bien así: emite | el «How to pay» en español: también lo dice';
begin
  if pg_temp.c11_omitir(27, v_nom, v_esp) then return; end if;
  begin
    a := format('«Trabajo de rough-in terminado» %s, «¿Listo?» %s, «Pago por el trabajo de la casa» %s; «Rough-in complete» %s, «Final '
                'inspection passed» %s, «Panel upgrade per contract» %s',
                case when fn_emision_parece_espanol('Trabajo de rough-in terminado') then 'sí' else 'no' end,
                case when fn_emision_parece_espanol('¿Listo?') then 'sí' else 'no' end,
                case when fn_emision_parece_espanol('Pago por el trabajo de la casa') then 'sí' else 'no' end,
                case when fn_emision_parece_espanol('Rough-in complete') then 'sí' else 'no' end,
                case when fn_emision_parece_espanol('Final inspection passed') then 'sí' else 'no' end,
                case when fn_emision_parece_espanol('Panel upgrade per contract') then 'sí' else 'no' end);
    perform pg_temp.c11_sembrar();
    insert into hitos (id, proyecto_id, titulo, monto, estado, orden) overriding system value
    values (-1110000007, 'c11-prueba-d', 'Instalación del tablero', 500, 'pendiente', 1);
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000007));
    v_doc := (v_b->'documento'->>'id')::uuid;
    b := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x
                                where x->>'codigo' = 'en_espanol' and (x->>'frena')::boolean and x->>'texto' like '%(una línea)%')
              then 'el borrador lo dice (frena: una línea)' else 'el borrador NO lo dice' end
         || ' y emitir da ' || pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc, v_b->>'visto'));
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'notas', 'Gracias por su pago, hasta la próxima'));
    c := coalesce((select substring(x->>'texto' from '\((.*?)\)') from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'en_espanol'), 'NO lo dice');
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'descripcion', 'Panel installation', 'notas', 'Thank you.'));
    d := case when (v_b->>'puede_emitir')::boolean and not exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'en_espanol')
              then 'deja emitir' else 'NO deja emitir' end;
    perform pg_temp.c11_borrador(jsonb_build_object('documento', v_doc, 'descripcion', 'Instalación del tablero'));
    v_r := pg_temp.c11_emitir(v_doc, '{"idioma_revisado": true}'::jsonb);
    e := case when v_r->>'estado' = 'emitida' then 'emite' else 'NO emite' end;
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_config('{"como_pagar": "Cheque a nombre de ZZ Electric, hasta el viernes"}'::jsonb);
    v_b := fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    perform pg_temp.c11_ser('editor');
    f := case when not (v_b->>'puede_emitir')::boolean
                   and exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'en_espanol' and x->>'texto' like '%(el «How to pay»)%')
              then 'también lo dice' else 'NO lo dice' end;
    v_obt := format('parece español: %s | un hito con el título en español: %s | con las notas en español: %s | escrito en inglés: %s | o '
                    'confirmando que está bien así: %s | el «How to pay» en español: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. EL PDF, del lado de la base. La función de borde lo pinta con el
--     contenido congelado, lo sube al bucket privado «facturas» y lo
--     registra: la base comprueba que el archivo ESTÁ en el bucket, que mide
--     lo que se declara y que se pintó de ESE contenido (su huella). Un PDF
--     nuevo es otra versión, con otra ruta: no se pisa. Y en el bucket ni el
--     dueño lo borra ni lo cambia.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_num text; v_h text; v_carp text; v_r1 text; v_r2 text; v_p jsonb; v_p2 jsonb; v_d jsonb; v_bor uuid; v_k bigint;
  v_sha text := repeat('a', 64);
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text; k text;
  v_nom text := 'EL PDF: se registra (ruta, sha256, bytes) solo si el archivo está en el bucket privado «facturas», mide lo que se declara y '
                'se pintó del contenido congelado (su huella; si no, MX011); cada PDF nuevo es otra versión con otra ruta (no se pisa); y '
                'en el bucket ni el dueño lo borra ni lo cambia';
  v_esp text := 'sin subirlo: 22023 | el dueño lo sube al bucket | con otro tamaño que el del bucket: 22023 | pintado de otro contenido: '
                'MX011 | la ruta: en otra carpeta 22023, con .. 22023, sin .pdf 22023, en una subcarpeta 22023 | un sha256 mal escrito '
                '22023, 0 bytes MX005, una clave desconocida 22023 | registrado: la versión 1, con su ruta, su sha256 y su tamaño | otra vez '
                'el mismo: ya estaba (una sola fila) | la misma ruta con otro archivo: MX008 | otro PDF con otra ruta: la versión 2, y la '
                'pantalla ve los dos (el último es el que vale) | de un borrador MX008, de una anulada MX008 | en el bucket el dueño ni lo '
                'borra ni lo cambia: sigue ahí, igual';
begin
  if pg_temp.c11_omitir(28, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_storage') <> 'true' then
    insert into _pruebas values (28, v_nom, v_esp, 'omitida: esta base no tiene Storage (storage.objects): que el PDF esté en el bucket no se puede probar aquí', null);
    return;
  end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid; v_num := v_r->>'numero'; v_h := v_r->>'huella';
    v_carp := extract(year from pg_temp.c11('hoy')::date)::int || '/' || v_num || '/';
    v_r1 := v_carp || v_num || '-v1.pdf'; v_r2 := v_carp || v_num || '-v2.pdf';
    a := pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text));
    -- el dueño lo sube (la policy del bucket le deja)
    perform pg_temp.c11_ser('dueno');
    begin
      insert into storage.objects (bucket_id, name, owner, metadata) values ('facturas', v_r1, pg_temp.c11('dueno')::uuid, '{"size": 1234}'::jsonb);
      insert into storage.objects (bucket_id, name, owner, metadata) values ('facturas', v_r2, pg_temp.c11('dueno')::uuid, '{"size": 2345}'::jsonb);
      b := 'el dueño lo sube al bucket';
    exception when others then b := 'el dueño NO lo sube al bucket (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
    end;
    perform pg_temp.c11_ser('editor');
    -- (si no pudo, los pone el SQL Editor para que lo demás se pueda mirar; la prueba ya lo dijo)
    insert into storage.objects (bucket_id, name, owner, metadata)
    select 'facturas', x.r, pg_temp.c11('dueno')::uuid, jsonb_build_object('size', x.t)
      from (values (v_r1, 1234), (v_r2, 2345)) x(r, t)
     where not exists (select 1 from storage.objects o where o.bucket_id = 'facturas' and o.name = x.r);
    c := pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 999, 'huella', v_h)::text));
    d := pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', repeat('b', 64))::text));
    e := format('en otra carpeta %s, con .. %s, sin .pdf %s, en una subcarpeta %s',
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', '2026/ZZ-OTRA/x.pdf', 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || '../x.pdf', 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'x.txt', 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'sub/x.pdf', 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)));
    f := format('un sha256 mal escrito %s, 0 bytes %s, una clave desconocida %s',
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', 'ABC', 'bytes', 1234, 'huella', v_h)::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 0, 'huella', v_h)::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', v_h, 'paginas', 2)::text)));
    perform pg_temp.c11_ser('dueno');
    v_p := fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', v_h));
    g := case when not (v_p->>'ya_estaba')::boolean and (v_p->'pdf'->>'n')::int = 1 and v_p->'pdf'->>'ruta' = v_r1 and v_p->'pdf'->>'sha256' = v_sha
                   and (v_p->'pdf'->>'bytes')::bigint = 1234 and v_p->>'numero' = v_num
              then 'la versión 1, con su ruta, su sha256 y su tamaño' else 'MAL: ' || v_p::text end;
    v_p2 := fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', v_h));
    h := case when (v_p2->>'ya_estaba')::boolean and v_p2->'pdf'->>'id' = v_p->'pdf'->>'id' and (select count(*) from emision_pdfs x where x.documento_id = v_doc) = 1
              then 'ya estaba (una sola fila)' else 'MAL: ' || v_p2::text end;
    perform pg_temp.c11_ser('editor');
    i := pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_r1, 'sha256', repeat('c', 64), 'bytes', 1234, 'huella', v_h)::text));
    perform pg_temp.c11_ser('dueno');
    v_p2 := fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_r2, 'sha256', repeat('d', 64), 'bytes', 2345, 'huella', v_h));
    v_d := fn_emision_documento(v_doc);
    j := case when (v_p2->'pdf'->>'n')::int = 2 then 'la versión 2' else 'la versión ' || (v_p2->'pdf'->>'n') end
         || case when jsonb_array_length(v_d->'pdfs') = 2 and v_d->'pdfs'->1->>'ruta' = v_r2
                      and (select x.pdfs = 2 and x.pdf_ruta = v_r2 from v_emision_documentos x where x.id = v_doc)
                 then ', y la pantalla ve los dos (el último es el que vale)' else ', y la pantalla NO los ve' end;
    -- en el bucket: ni borrar ni cambiar. (El borrado va como lo manda la API de Storage: en Supabase un DELETE directo
    -- a storage.objects da 42501 «Direct deletion from storage tables is not allowed», toque filas o no —el trigger
    -- protect_objects_delete, por sentencia—, salvo con esta marca de la transacción, que es la que pone la API. Con ella, quien
    -- decide es el candado del bucket. En una base sin ese trigger no hace nada. Se deshace con la prueba. Cada intento va
    -- en su bloque: si la base lo rechaza con un error en vez de no tocar ninguna fila, tampoco lo borró ni lo cambió; lo
    -- que se mira después es el archivo.)
    begin
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects where bucket_id = 'facturas' and name = v_r1;
    exception when others then null;
    end;
    begin
      update storage.objects set metadata = '{"size": 1}'::jsonb where bucket_id = 'facturas' and name = v_r1;
    exception when others then null;
    end;
    perform pg_temp.c11_ser('editor');
    select (o.metadata->>'size')::bigint into v_k from storage.objects o where o.bucket_id = 'facturas' and o.name = v_r1;
    k := case when v_k = 1234 then 'sigue ahí, igual' when v_k is null then 'lo BORRÓ' else 'lo CAMBIÓ' end;
    -- de un borrador y de una anulada
    v_bor := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002))->'documento'->>'id')::uuid;
    perform pg_temp.c11_anular(v_doc, 'c11-pruebas: para probar el PDF de una anulada');
    v_obt := format('sin subirlo: %s | %s | con otro tamaño que el del bucket: %s | pintado de otro contenido: %s | la ruta: %s | %s | '
                    'registrado: %s | otra vez el mismo: %s | la misma ruta con otro archivo: %s | otro PDF con otra ruta: %s | de un borrador '
                    '%s, de una anulada %s | en el bucket el dueño ni lo borra ni lo cambia: %s',
                    a, b, c, d, e, f, g, h, i, j,
                    pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_bor, jsonb_build_object('ruta', v_r1, 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)),
                    pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'v3.pdf', 'sha256', v_sha, 'bytes', 1234, 'huella', v_h)::text)),
                    k);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. EL ENVÍO. Cada envío queda apuntado: a quién, cuándo, con qué PDF y,
--     si fue por correo, el id que dio Resend (la prueba de que salió: el
--     mismo id dos veces no entra dos veces). Otro correo es un reenvío. «En
--     mano» también se apunta. Un correo sin su PDF registrado, no.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_doc uuid; v_doc2 uuid; v_num text; v_ruta text; v_pdf uuid; v_e jsonb; v_e2 jsonb; v_bor uuid; v_v record;
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_nom text := 'EL ENVÍO: cada envío queda apuntado (a quién, cuándo, con qué PDF y el id de Resend); el mismo id de Resend no entra dos '
                'veces; otro correo es un reenvío; «en mano» también se apunta; un correo sin su PDF registrado no; y sus frenos';
  v_esp text := 'un correo sin su PDF registrado: MX008 | el correo: el envío 1, a su destinatario, con el PDF que se mandó y su id de '
                'Resend | el mismo id de Resend otra vez: ya estaba (una sola fila) | otro correo: el envío 2, un reenvío | ese id en otra '
                'factura: MX008 | en mano, sin PDF: entra | frenos: un correo sin id de Resend 22023, a algo que no es un correo 22023, un '
                'medio desconocido 22023, el PDF de otra factura 22023, una clave desconocida 22023, un borrador MX008, una anulada MX008 | '
                'la pantalla lo ve: 2 envíos, el último a zz.dos@c11-pruebas.invalid';
begin
  if pg_temp.c11_omitir(29, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002);
    v_doc := (r1->>'documento')::uuid; v_doc2 := (r2->>'documento')::uuid; v_num := r1->>'numero';
    a := pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc,
                                jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid', 'resend_id', 're_c11_prueba_0')::text));
    v_ruta := extract(year from pg_temp.c11('hoy')::date)::int || '/' || v_num || '/' || v_num || '.pdf';
    if pg_temp.c11('hay_storage') = 'true' then
      execute 'insert into storage.objects (bucket_id, name, metadata) values (''facturas'', $1, ''{"size": 4321}''::jsonb)' using v_ruta;
    end if;
    perform pg_temp.c11_ser('dueno');
    v_pdf := (fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_ruta, 'sha256', repeat('e', 64), 'bytes', 4321, 'huella', r1->>'huella'))->'pdf'->>'id')::uuid;
    v_e := fn_emision_envio(v_doc, jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid', 'cc', 'zz.cc@c11-pruebas.invalid',
                                                      'asunto', 'Invoice ' || v_num || ' from ZZ Electric C11 PRUEBA, Inc.',
                                                      'resend_id', 're_c11_prueba_1'));
    b := case when not (v_e->>'ya_estaba')::boolean and not (v_e->>'reenvio')::boolean and (v_e->'envio'->>'n')::int = 1
                   and v_e->'envio'->>'medio' = 'correo' and v_e->'envio'->>'para' = 'zz.uno@c11-pruebas.invalid'
                   and (select x.pdf_id = v_pdf and x.resend_id = 're_c11_prueba_1' and x.cc = 'zz.cc@c11-pruebas.invalid'
                               and x.enviado_por = pg_temp.c11('dueno')::uuid
                          from emision_envios x where x.id = (v_e->'envio'->>'id')::uuid)
              then 'el envío 1, a su destinatario, con el PDF que se mandó y su id de Resend' else 'MAL: ' || v_e::text end;
    v_e2 := fn_emision_envio(v_doc, jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid', 'resend_id', 're_c11_prueba_1'));
    c := case when (v_e2->>'ya_estaba')::boolean and v_e2->'envio'->>'id' = v_e->'envio'->>'id'
                   and (select count(*) from emision_envios x where x.documento_id = v_doc) = 1
              then 'ya estaba (una sola fila)' else 'MAL: ' || v_e2::text end;
    v_e2 := fn_emision_envio(v_doc, jsonb_build_object('para', 'zz.dos@c11-pruebas.invalid', 'resend_id', 're_c11_prueba_2'));
    d := format('el envío %s, %s', v_e2->'envio'->>'n', case when (v_e2->>'reenvio')::boolean then 'un reenvío' else 'NO un reenvío' end);
    perform pg_temp.c11_ser('editor');
    e := pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc2,
                                jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid', 'resend_id', 're_c11_prueba_1')::text));
    f := replace(pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc2,
                                        jsonb_build_object('medio', 'en_mano', 'para', 'ZZ Site Superintendent', 'nota', 'Delivered on site')::text)),
                 'entró', 'entra');
    v_bor := (pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003))->'documento'->>'id')::uuid;
    g := format('un correo sin id de Resend %s, a algo que no es un correo %s, un medio desconocido %s, el PDF de otra factura %s, una clave '
                'desconocida %s, un borrador %s',
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc, jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid')::text)),
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc, jsonb_build_object('para', 'ZZ Cliente Uno', 'resend_id', 're_c11_prueba_3')::text)),
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc, jsonb_build_object('medio', 'fax', 'para', 'zz.uno@c11-pruebas.invalid')::text)),
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc2, jsonb_build_object('medio', 'en_mano', 'para', 'ZZ', 'pdf_id', v_pdf)::text)),
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc, jsonb_build_object('para', 'zz.uno@c11-pruebas.invalid', 'resend_id', 're_c11_prueba_4', 'bcc', 'x')::text)),
                pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_bor, jsonb_build_object('medio', 'en_mano', 'para', 'ZZ')::text)));
    select * into v_v from v_emision_documentos x where x.id = v_doc;
    h := format('%s envíos, el último a %s', v_v.envios, v_v.enviado_a);
    perform pg_temp.c11_anular(v_doc2, 'c11-pruebas: para probar el envío de una anulada');
    g := g || ', una anulada ' || pg_temp.c11_cod(format('select fn_emision_envio(%L, %L)', v_doc2, jsonb_build_object('medio', 'en_mano', 'para', 'ZZ')::text));
    v_obt := format('un correo sin su PDF registrado: %s | el correo: %s | el mismo id de Resend otra vez: %s | otro correo: %s | ese id en otra '
                    'factura: %s | en mano, sin PDF: %s | frenos: %s | la pantalla lo ve: %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 30. EL PAGO EN LÍNEA: LO QUE VA A STRIPE ES LO QUE DICE LA FACTURA.
--     fn_emision_pago dice el monto (lo que el libro debe en la cuenta por
--     cobrar: recién emitida, el «Amount due» del documento), en centavos, y
--     SOLO por cuenta de banco. El enlace que arman los cobros en línea (p1,
--     sin tocarlo) cobra exactamente eso, sin la retención. Un PDF con un
--     enlace que no es ese, con tarjeta, con otra dirección, que cobra la
--     retención o que quedó desfasado, no se registra.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_fid bigint; v_p jsonb; v_e jsonb; v_carp text; v_h text; v_x jsonb; r2 jsonb; v_e2 jsonb;
  v_sha text := repeat('f', 64); v_url text := 'https://buy.stripe.com/test_plink_C11T30';
  a text; b text; c text; d text; e text; f text; g text;
  v_nom text := 'EL PAGO EN LÍNEA: lo que va a Stripe es lo que dice la factura (lo que el libro debe, en centavos, solo por cuenta de banco, '
                'sin la retención); el enlace de los cobros en línea (p1, sin tocarlo) cobra eso mismo; y un PDF con un enlace que no es '
                'el suyo, con tarjeta, con otra dirección, que cobra la retención o desfasado no se registra (MX008)';
  v_esp text := 'lo que va a Stripe: 111111 centavos de usd (1111.11: lo que dice la factura y lo que el libro debe), solo us_bank_account, '
                'de un solo uso, sin la retención (123.46 quedan retenidos); la tarjeta no se ofrece | el enlace de los cobros en línea '
                'cobra ESO: 111111 centavos, sin retención, con el número de la factura en sus metadatos; queda vivo y vale | el PDF con '
                'ese enlace y solo cuenta de banco: se registra, con lo que lleva impreso | con tarjeta MX008, con un enlace que no es el '
                'suyo MX008, con otra dirección MX008 | un enlace que cobra también la retención: no vale, y no se imprime (MX008) | tras '
                'un cobro parcial por cheque el enlace queda desfasado: no vale, y no se imprime (MX008) | con el pago en línea apagado en '
                'los ajustes: no se ofrece';
begin
  if pg_temp.c11_omitir(30, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_p1') <> 'true' then
    insert into _pruebas values (30, v_nom, v_esp, 'omitida: los cobros en línea (p1) no están en esta base', null);
    return;
  end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_p1_montar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_r := pg_temp.c11_hito(-1110000006);
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint; v_h := v_r->>'huella';
    v_carp := extract(year from pg_temp.c11('hoy')::date)::int || '/' || (v_r->>'numero') || '/';
    perform pg_temp.c11_ser('dueno');
    v_p := fn_emision_pago(v_doc);
    perform pg_temp.c11_ser('editor');
    a := case when (v_p->>'en_linea')::boolean and not v_p ? 'enlace' and (v_p->'stripe'->>'monto')::numeric = (v_p->>'a_pagar')::numeric
                   and (v_p->>'saldo')::numeric = (v_p->>'a_pagar')::numeric and v_p->'stripe'->>'descripcion' like 'Invoice ' || (v_r->>'numero') || ' — %'
              then format('%s centavos de %s (%s: lo que dice la factura y lo que el libro debe), solo %s, %s, %s (%s quedan retenidos); la tarjeta %s',
                          v_p->'stripe'->>'centavos', v_p->'stripe'->>'moneda', v_p->>'a_pagar',
                          (select string_agg(m, ', ') from jsonb_array_elements_text(v_p->'stripe'->'metodos') m),
                          case when (v_p->'stripe'->>'un_solo_uso')::boolean then 'de un solo uso' else 'de VARIOS usos' end,
                          case when not (v_p->'stripe'->>'con_retencion')::boolean then 'sin la retención' else 'CON la retención' end,
                          v_p->>'saldo_retencion',
                          case when not (v_p->'tarjeta'->>'ofrecida')::boolean then 'no se ofrece' else 'SE OFRECE' end)
              else 'MAL: ' || v_p::text end;
    -- el enlace de p1 (lo que hace «Cobros en línea»)
    v_e := pg_temp.c11_enlace(v_fid, 'plink_C11T30');
    perform pg_temp.c11_ser('dueno');
    v_p := fn_emision_pago(v_doc);
    perform pg_temp.c11_ser('editor');
    b := format('%s centavos, %s, %s; %s', v_e->>'centavos',
                case when not (v_e->>'con_retencion')::boolean and v_e->'metadata'->>'retencion' = 'no' then 'sin retención' else 'CON retención' end,
                case when v_e->'metadata'->>'factura' = v_r->>'numero' and v_e->'metadata'->>'factura_id' = v_fid::text and v_e->'metadata'->>'mxp' = 'p1'
                     then 'con el número de la factura en sus metadatos' else 'con OTROS metadatos' end,
                case when v_p->'enlace'->>'estado' = 'activo' and (v_p->'enlace'->>'vale')::boolean and v_p->'enlace'->>'url' = v_url
                          and (v_p->'enlace'->>'monto')::numeric = 1111.11 and v_p->'enlace'->>'id' = v_e->>'enlace'
                     then 'queda vivo y vale' else 'NO vale: ' || coalesce((v_p->'enlace')::text, 'sin enlace') end);
    -- el PDF con ese enlace
    if pg_temp.c11('hay_storage') = 'true' then
      execute 'insert into storage.objects (bucket_id, name, metadata) select ''facturas'', $1 || x, ''{"size": 5000}''::jsonb '
              'from unnest(array[''a.pdf'', ''b.pdf'', ''c.pdf'', ''d.pdf'', ''e.pdf'']) x' using v_carp;
    end if;
    perform pg_temp.c11_ser('dueno');
    v_x := fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_carp || 'a.pdf', 'sha256', v_sha, 'bytes', 5000, 'huella', v_h,
             'pago', jsonb_build_object('enlace_id', v_e->>'enlace', 'url', v_url, 'metodos', jsonb_build_array('us_bank_account'))));
    perform pg_temp.c11_ser('editor');
    c := case when (select x.pago = jsonb_build_object('enlace_id', (v_e->>'enlace')::uuid, 'url', v_url, 'metodos', jsonb_build_array('us_bank_account'),
                                                       'monto', 1111.11)
                      from emision_pdfs x where x.id = (v_x->'pdf'->>'id')::uuid)
              then 'se registra, con lo que lleva impreso' else 'MAL: ' || (select x.pago::text from emision_pdfs x where x.id = (v_x->'pdf'->>'id')::uuid) end;
    d := format('con tarjeta %s, con un enlace que no es el suyo %s, con otra dirección %s',
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'b.pdf', 'sha256', v_sha, 'bytes', 5000, 'huella', v_h,
                  'pago', jsonb_build_object('enlace_id', v_e->>'enlace', 'url', v_url, 'metodos', jsonb_build_array('us_bank_account', 'card')))::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'b.pdf', 'sha256', v_sha, 'bytes', 5000, 'huella', v_h,
                  'pago', jsonb_build_object('enlace_id', gen_random_uuid(), 'url', v_url, 'metodos', jsonb_build_array('us_bank_account')))::text)),
                pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'b.pdf', 'sha256', v_sha, 'bytes', 5000, 'huella', v_h,
                  'pago', jsonb_build_object('enlace_id', v_e->>'enlace', 'url', 'https://example.invalid/pay', 'metodos', jsonb_build_array('us_bank_account')))::text)));
    -- otra factura, con un enlace que cobra también la retención
    r2 := pg_temp.c11_hito(-1110000001);
    v_e2 := pg_temp.c11_enlace((r2->>'factura_id')::bigint, 'plink_C11T30R', true);
    if pg_temp.c11('hay_storage') = 'true' then
      execute 'insert into storage.objects (bucket_id, name, metadata) values (''facturas'', $1, ''{"size": 5000}''::jsonb)'
        using extract(year from pg_temp.c11('hoy')::date)::int || '/' || (r2->>'numero') || '/r.pdf';
    end if;
    perform pg_temp.c11_ser('dueno');
    v_p := fn_emision_pago((r2->>'documento')::uuid);
    perform pg_temp.c11_ser('editor');
    e := case when not (v_p->'enlace'->>'vale')::boolean and (v_p->'enlace'->>'con_retencion')::boolean and (v_e2->>'centavos')::bigint = 333333
              then 'no vale' else 'VALE: ' || (v_p->'enlace')::text end
         || format(', y no se imprime (%s)',
                   pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', (r2->>'documento')::uuid,
                     jsonb_build_object('ruta', extract(year from pg_temp.c11('hoy')::date)::int || '/' || (r2->>'numero') || '/r.pdf', 'sha256', v_sha,
                                        'bytes', 5000, 'huella', r2->>'huella',
                                        'pago', jsonb_build_object('enlace_id', v_e2->>'enlace', 'url', 'https://buy.stripe.com/test_plink_C11T30R',
                                                                   'metodos', jsonb_build_array('us_bank_account')))::text)));
    -- un cobro parcial por cheque deja el enlace desfasado
    perform pg_temp.c11_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c11('hoy'), 'monto', '100.00', 'medio', 'cheque', 'referencia', 'C11-PRUEBA-30',
                                                  'duplicado_confirmado', 'c11-pruebas: un cobro de prueba',
                                                  'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', v_fid, 'monto', '100.00'))));
    v_p := fn_emision_pago(v_doc);
    perform pg_temp.c11_ser('editor');
    f := case when not (v_p->'enlace'->>'vale')::boolean and (v_p->>'saldo')::numeric = 1011.11 and (v_p->'stripe'->>'centavos')::bigint = 101111
              then 'no vale' else 'VALE: ' || v_p::text end
         || format(', y no se imprime (%s)',
                   pg_temp.c11_cod(format('select fn_emision_pdf(%L, %L)', v_doc, jsonb_build_object('ruta', v_carp || 'c.pdf', 'sha256', v_sha, 'bytes', 5000, 'huella', v_h,
                     'pago', jsonb_build_object('enlace_id', v_e->>'enlace', 'url', v_url, 'metodos', jsonb_build_array('us_bank_account')))::text)));
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_config('{"ach": false}'::jsonb);
    v_p := fn_emision_pago(v_doc);
    perform pg_temp.c11_ser('editor');
    g := case when not (v_p->>'en_linea')::boolean and v_p->>'por_que_no' = 'El pago en línea está apagado en los ajustes de facturación.' and not v_p ? 'stripe'
              then 'no se ofrece' else 'SE OFRECE: ' || v_p::text end;
    v_obt := format('lo que va a Stripe: %s | el enlace de los cobros en línea cobra ESO: %s | el PDF con ese enlace y solo cuenta de banco: %s | '
                    '%s | un enlace que cobra también la retención: %s | tras un cobro parcial por cheque el enlace queda desfasado: %s | con el '
                    'pago en línea apagado en los ajustes: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 31. p1 CONTABILIZA BIEN el pago por cuenta de banco de una factura de la
--     app, sin cambiar p1: mientras el pago está en camino la factura sigue
--     debiendo (y no se ofrece otro enlace); al liquidarse, el cobro entra
--     Dr la cuenta de Stripe / Cr la cuenta por cobrar DE ESA FACTURA, por
--     lo que la factura decía; la retención sigue retenida; y ningún control
--     pasa a rojo.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_fid bigint; v_p jsonb; s0 text[]; v_v record;
  a text; b text; c text; d text;
  v_nom text := 'p1 CONTABILIZA BIEN el pago por cuenta de banco de una factura de la app (sin cambiar p1): en camino, la factura sigue '
                'debiendo y no se ofrece otro enlace; liquidado, el cobro entra contra la cuenta por cobrar de esa factura por lo que la '
                'factura decía, la retención sigue retenida, el enlace queda usado y ningún control pasa a rojo';
  v_esp text := 'en camino: la factura sigue debiendo 1111.11, no se ofrece otro enlace (hay 1 pago de 1111.11 en camino) | liquidado: el '
                'cobro es stripe 1111.11 | cxc -1111.11 (la factura); la factura debe 0.00 y sigue retenido 123.46; ya no se cobra en línea '
                '(La factura ya no debe nada en el libro.); el enlace queda usado | la lista: saldo 0.00, retención 123.46 | los controles '
                'de la facturación en verde, y de las otras capas en rojo que no lo estaban: ninguno';
begin
  if pg_temp.c11_omitir(31, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_p1') <> 'true' then
    insert into _pruebas values (31, v_nom, v_esp, 'omitida: los cobros en línea (p1) no están en esta base', null);
    return;
  end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_p1_montar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    s0 := pg_temp.c11_rojos();
    v_r := pg_temp.c11_hito(-1110000006);
    v_doc := (v_r->>'documento')::uuid; v_fid := (v_r->>'factura_id')::bigint;
    perform pg_temp.c11_enlace(v_fid, 'plink_C11T31');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T31', 'processing', 111111, 'ach'), 'evt_C11T31a';
    v_p := fn_emision_pago(v_doc);
    a := format('la factura sigue debiendo %s, %s (hay %s pago de %s en camino)', v_p->>'saldo',
                case when not (v_p->>'en_linea')::boolean and v_p->>'por_que_no' like 'Ya hay un pago por cuenta de banco en camino%' then 'no se ofrece otro enlace'
                     else 'SE OFRECE otro enlace' end,
                v_p->'en_camino'->>'pagos', v_p->'en_camino'->>'monto');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T31', 'succeeded', 111111, 'ach'), 'evt_C11T31b';
    v_p := fn_emision_pago(v_doc);
    b := format('el cobro es %s; la factura debe %s y sigue retenido %s; ya no se cobra en línea (%s); el enlace queda %s',
                pg_temp.c11_cobro('pi_C11T31'), v_p->>'saldo', v_p->>'saldo_retencion', v_p->>'por_que_no',
                (select e.estado from fn_emision_enlaces() e where e.factura_id = v_fid));
    select * into v_v from v_emision_documentos x where x.id = v_doc;
    c := format('saldo %s, retención %s', v_v.saldo, v_v.saldo_retencion);
    d := format('los controles de la facturación %s, y de las otras capas en rojo que no lo estaban: %s',
                coalesce((select 'en ROJO: ' || string_agg(k.orden::text, ',' order by k.orden) from v_emision_control k
                           where not k.ok and k.orden::text <> all (pg_temp.c11_ya_rojos())), 'en verde'),
                pg_temp.c11_nuevos(s0, pg_temp.c11_rojos()));
    v_obt := format('en camino: %s | liquidado: %s | la lista: %s | %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. LA PRUEBA DEL RECARGO: por qué la tarjeta queda apagada. Si el
--     cliente paga con tarjeta MÁS de lo que la factura debe (el recargo),
--     p1 —sellado— reparte así: lo que la factura debe, a la factura; y lo de
--     más, o lo deja de ANTICIPO DE LA OBRA (un saldo a favor del cliente,
--     con el aviso «¿pagó dos veces?»), o —si la factura tiene retención—
--     lo aplica a su RETENCIÓN, que todavía no se debe. En ningún caso es un
--     ingreso. Arreglarlo a mano cada vez sería rodear p1: por eso
--     fn_emision_config no deja poner el porcentaje, y el control 80 avisa
--     de todo cobro con tarjeta de una factura de la app.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_x text; v_av text; v_ing0 numeric; v_ing1 numeric;
  a text; b text; c text;
  v_nom text := 'LA PRUEBA DEL RECARGO (por qué la tarjeta queda apagada): un pago con tarjeta por más de lo que la factura debe, p1 lo '
                'reparte a la factura y deja lo de más de anticipo de la obra (un saldo a favor del cliente) o, si hay retención, lo '
                'aplica a la retención que todavía no se debe; en ningún caso es un ingreso; el control avisa del cobro con tarjeta';
  v_esp text := 'una factura de 3333.33 pagada con tarjeta por 3433.33 (el 3 % de más): stripe 3433.33 | cxc -3333.33 (la factura) | cxc '
                '-100.00 (anticipo de la obra); los cobros en línea avisan de que quedó de anticipo, y a los ingresos no entró nada | con '
                'retención (se debían 3000.00 y se cobran 3090.00): stripe 3090.00 | cxc -3000.00 (la factura) | ret -90.00 (la factura); lo '
                'de más cobró retención que todavía no se debía, y lo avisa | por eso la tarjeta está apagada (lista: false; poner su '
                'porcentaje: MX008) y el control 80 avisa de los dos cobros con tarjeta';
begin
  if pg_temp.c11_omitir(32, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_p1') <> 'true' then
    insert into _pruebas values (32, v_nom, v_esp, 'omitida: los cobros en línea (p1) no están en esta base', null);
    return;
  end if;
  if pg_temp.c11_omitir_rojo(32, v_nom, v_esp, array[80]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_p1_montar();
    -- (a) sin retención
    r1 := pg_temp.c11_hito(-1110000001);
    select coalesce(sum(l.monto), 0) into v_ing0 from asiento_lineas l join cuentas k on k.codigo = l.cuenta where k.tipo in ('ingreso', 'otro_ingreso');
    perform pg_temp.c11_enlace((r1->>'factura_id')::bigint, 'plink_C11T32A');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T32A', 'succeeded', 343333, 'tarjeta'), 'evt_C11T32A';
    select coalesce(sum(l.monto), 0) into v_ing1 from asiento_lineas l join cuentas k on k.codigo = l.cuenta where k.tipo in ('ingreso', 'otro_ingreso');
    execute 'select a.nivel || '': '' || a.texto from public.stripe_avisos a where a.clave = ''sobra:pi_C11T32A''' into v_av;
    a := pg_temp.c11_cobro('pi_C11T32A')
         || case when v_av like 'warn: %$100.00 quedó de anticipo de la obra%' then '; los cobros en línea avisan de que quedó de anticipo'
                 else '; los cobros en línea NO avisan: ' || coalesce(v_av, '(nada)') end
         || case when v_ing1 = v_ing0 then ', y a los ingresos no entró nada' else ', y a los ingresos ENTRÓ ' || (v_ing1 - v_ing0) end;
    -- (b) con retención
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    r2 := pg_temp.c11_hito(-1110000002);
    perform pg_temp.c11_enlace((r2->>'factura_id')::bigint, 'plink_C11T32B');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T32B', 'succeeded', 309000, 'tarjeta'), 'evt_C11T32B';
    execute 'select a.nivel || '': '' || a.texto from public.stripe_avisos a where a.clave = ''sobra:pi_C11T32B''' into v_av;
    b := pg_temp.c11_cobro('pi_C11T32B')
         || case when (select s.retencion from fn_emision_saldo((r2->>'factura_id')::bigint) s) = 243.33 and v_av like 'warn: %$90.00 se aplicó a su retención%'
                 then '; lo de más cobró retención que todavía no se debía, y lo avisa' else '; MAL: ' || coalesce(v_av, '(sin aviso)') end;
    v_x := pg_temp.c11_ctl(80);
    c := format('por eso la tarjeta está apagada (lista: %s; poner su porcentaje: %s) y el control 80 %s', fn_emision_tarjeta_lista()::text,
                pg_temp.c11_cod($q$ select fn_emision_config('{"tarjeta_pct": 3}') $q$),
                case when v_x like 'rojo: la factura ' || (r1->>'numero') || ' se cobró con tarjeta ($3,433.33):%; la factura ' || (r2->>'numero')
                                   || ' se cobró con tarjeta ($3,090.00):%'
                     then 'avisa de los dos cobros con tarjeta' else v_x end);
    v_obt := format('una factura de 3333.33 pagada con tarjeta por 3433.33 (el 3 %% de más): %s | con retención (se debían 3000.00 y se cobran '
                    '3090.00): %s | %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LOS CONTROLES, cada uno en rojo y de vuelta. Lo que se rompe se rompe
-- por debajo de la guarda (el dueño de la base la apaga dentro de la
-- prueba) o con papeles hechos fuera de la app, y se deshace.
-- ---------------------------------------------------------------------
-- 33. El 10: cada factura emitida por la app ES su asiento, al centavo.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_x text;
  a text; b text; c text; d text; e text;
  v_nom text := 'el control 10 (cada factura emitida por la app es su asiento, al centavo: lo que se paga ahora, lo retenido y el ingreso): '
                'en rojo si el documento deja de decir lo que su asiento (cambiado por debajo de la guarda), con lo que tiene y lo que '
                'debía tener, sin nombrar funciones; de vuelta a verde';
  v_esp text := 'verde | lo que se paga y lo retenido cambiados por debajo de la guarda: rojo (dice lo que tiene su asiento y lo que debía '
                'tener, y qué hacer) | de vuelta: verde | el monto cambiado: rojo (dice el ingreso) | de vuelta: verde';
begin
  if pg_temp.c11_omitir(33, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(33, v_nom, v_esp, array[10]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid;
    a := pg_temp.c11_ctl(10);
    alter table public.emision_documentos disable trigger trg_emision_documentos_guarda;
    update emision_documentos set retencion = retencion + 1, a_pagar = a_pagar - 1 where id = v_doc;
    v_x := pg_temp.c11_ctl(10);
    b := case when v_x = 'rojo: la factura ' || (v_r->>'numero') || ' ($3,333.33): por cobrar en su asiento 3000.00 y debía ser 2999.00, retención '
                         'en su asiento 333.33 y debía ser 334.33 → no toques el libro ni la factura: avisa.' and v_x !~ 'fn_|v_emision'
              then 'rojo (dice lo que tiene su asiento y lo que debía tener, y qué hacer)' else v_x end;
    update emision_documentos set retencion = retencion - 1, a_pagar = a_pagar + 1 where id = v_doc;
    c := pg_temp.c11_ctl(10);
    update emision_documentos set monto = monto + 1, a_pagar = a_pagar + 1 where id = v_doc;
    v_x := pg_temp.c11_ctl(10);
    d := case when v_x like 'rojo: la factura % por cobrar en su asiento 3000.00 y debía ser 3001.00, ingreso en su asiento 3333.33 y debía ser 3334.33 →%'
              then 'rojo (dice el ingreso)' else v_x end;
    update emision_documentos set monto = monto - 1, a_pagar = a_pagar - 1 where id = v_doc;
    e := pg_temp.c11_ctl(10);
    v_obt := format('%s | lo que se paga y lo retenido cambiados por debajo de la guarda: %s | de vuelta: %s | el monto cambiado: %s | de vuelta: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. El 20: la serie de cada año, sin huecos ni repetidos, y su contador
--     en el último número.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_x text; v_anio int := extract(year from pg_temp.c11('hoy')::date)::int;
  a text; b text; c text; d text; e text;
  v_nom text := 'el control 20 (la serie de cada año, sin huecos ni repetidos, y su contador en el último número): en rojo si un número se '
                'quita por debajo de la guarda (dice el hueco y la factura que se quedó sin número) o si el contador se adelanta; de '
                'vuelta a verde';
  v_esp text := 'verde | un número quitado por debajo de la guarda: rojo (dice el hueco y la factura que se quedó sin número) | de vuelta: '
                'verde | el contador adelantado: rojo (dice dónde va el contador) | de vuelta: verde';
begin
  if pg_temp.c11_omitir(34, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(34, v_nom, v_esp, array[20]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002); r3 := pg_temp.c11_hito(-1110000003);
    a := pg_temp.c11_ctl(20);
    begin
      alter table public.emision_serie disable trigger trg_emision_serie_guarda;
      delete from emision_serie where documento_id = (r2->>'documento')::uuid;
      v_x := pg_temp.c11_ctl(20);
      b := case when v_x like 'rojo: %la factura ' || (r2->>'numero') || ' no está en la serie%'
                     and v_x like '%en la serie de ' || v_anio || ' falta el número ' || (r2->>'numero') || ' y ninguna factura lo lleva%'
                     and v_x like '%→ un número no se da sin su factura: avisa (no se arregla a mano).'
                then 'rojo (dice el hueco y la factura que se quedó sin número)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    c := pg_temp.c11_ctl(20);
    begin
      update contadores set ultimo = ultimo + 1 where serie = 'facturas-' || v_anio;
      v_x := pg_temp.c11_ctl(20);
      d := case when v_x like 'rojo: la serie de las facturas de ' || v_anio || ' tiene % número(s), el último el %, y su contador va en ' || pg_temp.c11_contador() || ' →%'
                     and v_x not like '%no está en la serie%'
                then 'rojo (dice dónde va el contador)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    e := pg_temp.c11_ctl(20);
    v_obt := format('%s | un número quitado por debajo de la guarda: %s | de vuelta: %s | el contador adelantado: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. El 30: cada documento emitido sigue sellado (su contenido, sus
--     líneas, sus totales) y su fila de facturas dice lo mismo.
do $$
declare
  v_obt text; v_r jsonb; v_doc uuid; v_x text;
  a text; b text; c text; d text; e text; f text; g text;
  v_nom text := 'el control 30 (cada documento emitido sigue sellado y su fila de facturas dice lo mismo): en rojo si el contenido o una '
                'línea se tocan por debajo de la guarda, o si aquí está anulada y en el libro sigue viva; de vuelta a verde';
  v_esp text := 'verde | el contenido tocado por debajo de la guarda: rojo (ya no es el que se selló; sus totales no son los del contenido) | '
                'de vuelta: verde | una línea tocada: rojo (sus líneas no suman su monto) | de vuelta: verde | marcada anulada aquí con la '
                'factura viva en el libro: rojo (lo dice) | de vuelta: verde';
begin
  if pg_temp.c11_omitir(35, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(35, v_nom, v_esp, array[30]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    v_doc := (v_r->>'documento')::uuid;
    a := pg_temp.c11_ctl(30);
    begin
      alter table public.emision_documentos disable trigger trg_emision_documentos_guarda;
      update emision_documentos set contenido = jsonb_set(contenido, '{totales,a_pagar}', '"1.00"') where id = v_doc;
      v_x := pg_temp.c11_ctl(30);
      b := case when v_x like 'rojo: la factura ' || (v_r->>'numero') || ': su contenido ya no es el que se selló, su número o sus totales no son los del '
                              'contenido →%' and v_x !~ 'fn_|v_emision'
                then 'rojo (ya no es el que se selló; sus totales no son los del contenido)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    c := pg_temp.c11_ctl(30);
    begin
      alter table public.emision_lineas disable trigger trg_emision_lineas_guarda;
      update emision_lineas set precio = precio + 1, importe = importe + 1 where documento_id = v_doc;
      v_x := pg_temp.c11_ctl(30);
      d := case when v_x like 'rojo: la factura ' || (v_r->>'numero') || ': sus líneas no suman su monto (o no son las del contenido) →%'
                then 'rojo (sus líneas no suman su monto)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    e := pg_temp.c11_ctl(30);
    begin
      perform set_config('mx_emision.escribe', 'emision_documentos', true);
      update emision_documentos set anulado_el = now(), anulado_motivo = 'c11-pruebas: a mano' where id = v_doc;
      perform set_config('mx_emision.escribe', '', true);
      v_x := pg_temp.c11_ctl(30);
      f := case when v_x like 'rojo: la factura ' || (v_r->>'numero') || ': aquí está anulada y en el libro sigue viva →%' then 'rojo (lo dice)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform set_config('mx_emision.escribe', '', true);
    g := pg_temp.c11_ctl(30);
    v_obt := format('%s | el contenido tocado por debajo de la guarda: %s | de vuelta: %s | una línea tocada: %s | de vuelta: %s | marcada anulada '
                    'aquí con la factura viva en el libro: %s | de vuelta: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. El 40 (un cuadre: ningún hito con dos facturas vivas si alguna salió
--     de la app) y el 75 (un aviso: hitos con dos facturas vivas de antes).
--     EN UNA BASE CON EL ÍNDICE ÚNICO DE facturas POR HITO (producción: es de
--     la app; el banco, con 06-produccion-facturas.sql) dos filas de facturas
--     vivas con el mismo hito no caben, y el caso se fabrica por el único
--     camino que queda: la fila de la factura de la app deja de apuntar a su
--     hito y entra otra de ese hito (para el 40 es lo mismo: el hito de una
--     factura de la app es el de su documento). Y dos de FUERA con el mismo
--     hito no se pueden dar: se dice, y el 75 no tiene de qué avisar.
do $$
declare
  v_obt text; v_r jsonb; v_x text; v_hu text := pg_temp.c11_candado_hito();
  a text; b text; c text; d text; e text;
  v_nom text := 'los controles 40 (un hito con dos facturas vivas y alguna de la app: en rojo, detiene, con el hito y las dos facturas) y 75 '
                '(un hito con dos facturas vivas de antes de la app: un aviso); cada uno se enciende solo con lo suyo; de vuelta a verde';
  v_esp text := 'verde y verde | un hito con la factura de la app y otra de fuera: el 40 en rojo (dice el hito y las dos facturas) y el 75 '
                'verde | de vuelta: verde y verde | un hito con dos facturas de fuera: el 75 avisa (de antes) y el 40 verde | de vuelta: '
                'verde y verde';
begin
  if v_hu <> 'ninguno' then
    v_nom := v_nom || ' (en esta base, con su índice único de facturas por hito: la segunda factura del hito entra con la fila de la de '
                      'la app sin su hito, y dos de fuera con el mismo hito no caben)';
    v_esp := replace(v_esp, 'un hito con dos facturas de fuera: el 75 avisa (de antes) y el 40 verde',
                     'un hito con dos facturas de fuera: no caben (23505: el índice único de facturas por hito), el 75 verde y el 40 verde');
  end if;
  if pg_temp.c11_omitir(36, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(36, v_nom, v_esp, array[40, 75]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    a := pg_temp.c11_color(pg_temp.c11_ctl(40)) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(75));
    begin
      if v_hu <> 'ninguno' then
        update facturas set hito_id = null where id = (v_r->>'factura_id')::bigint;
      end if;
      insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
      values ('c11-prueba-a', 'ZZ-905', pg_temp.c11('hoy')::date, 3333.33, -1110000001, 'emitida');
      v_x := pg_temp.c11_ctl(40);
      b := case when v_x like 'rojo: el hito «C11 PRUEBA Milestone 1» de C11 PRUEBA Uno tiene 2 facturas vivas (' || (v_r->>'numero') || ', ZZ-905) →%'
                then 'el 40 en rojo (dice el hito y las dos facturas)' else 'el 40: ' || v_x end
           || ' y el 75 ' || pg_temp.c11_color(pg_temp.c11_ctl(75));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    c := pg_temp.c11_color(pg_temp.c11_ctl(40)) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(75));
    begin
      begin
        insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado) values
          ('c11-prueba-a', 'ZZ-906', pg_temp.c11('hoy')::date, 3333.33, -1110000002, 'emitida'),
          ('c11-prueba-a', 'ZZ-907', pg_temp.c11('hoy')::date, 3333.33, -1110000002, 'emitida');
        v_x := pg_temp.c11_ctl(75);
        d := case when v_x like 'rojo: el hito «C11 PRUEBA Milestone 2» de C11 PRUEBA Uno tiene 2 facturas vivas de antes (ZZ-906, ZZ-907) →%'
                  then 'el 75 avisa (de antes)' else 'el 75: ' || v_x end
             || ' y el 40 ' || pg_temp.c11_color(pg_temp.c11_ctl(40));
      exception when unique_violation then
        -- (la base no deja dos filas de facturas con el mismo hito: su índice único, de la app)
        d := format('no caben (23505: el índice único de facturas por hito), el 75 %s y el 40 %s',
                    pg_temp.c11_color(pg_temp.c11_ctl(75)), pg_temp.c11_color(pg_temp.c11_ctl(40)));
      end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    e := pg_temp.c11_color(pg_temp.c11_ctl(40)) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(75));
    v_obt := format('%s | un hito con la factura de la app y otra de fuera: %s | de vuelta: %s | un hito con dos facturas de fuera: %s | de '
                    'vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. El 50 (cada PDF registrado sigue en el bucket y mide lo mismo), el 60
--     (ninguna emitida hace más de N días sin PDF) y el 62 (ni sin mandar).
--     Los días pasan con el reloj fingido, dentro de un bloque que se deshace.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_doc uuid; v_doc2 uuid; v_ruta text; v_ruta2 text; v_x text; v_y text; v_por text;
  a text; b text; c text; d text; e text; f text; g text;
  v_nom text := 'los controles 50 (un PDF registrado que ya no está en el bucket, o mide otra cosa), 60 (una factura emitida hace más de N '
                'días sin PDF: la de la retención, como lo que es, sin decir que está en el libro) y 62 (sin mandar ni entregar): avisan '
                'con su número y qué hacer; con el PDF y el envío, dejan de nombrarla';
  v_esp text := 'verde, verde y verde | registrado y quitado del bucket: el 50 avisa (ya no está) | con otro tamaño en el bucket: avisa '
                '(mide otra cosa) | de vuelta: verde | tres días después, una sin PDF y las dos sin mandar: el 60 nombra a la que no tiene '
                'PDF (y no a la otra) y a la de la retención como lo que es, y el 62 a las dos | con su PDF: el 60 ya no la nombra y el 62 '
                'sí | entregadas en mano: el 62 ya no las nombra';
begin
  if pg_temp.c11_omitir(37, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_storage') <> 'true' then
    insert into _pruebas values (37, v_nom, v_esp, 'omitida: esta base no tiene Storage (storage.objects): el PDF en el bucket no se puede probar aquí', null);
    return;
  end if;
  if pg_temp.c11_omitir_rojo(37, v_nom, v_esp, array[50, 60, 62]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform fn_emision_config('{"pdf_dias": 2}'::jsonb);
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002);
    v_doc := (r1->>'documento')::uuid; v_doc2 := (r2->>'documento')::uuid;
    -- (y la factura de la retención de la obra: no lleva asiento)
    r3 := pg_temp.c11_emitir((pg_temp.c11_borrador(jsonb_build_object('forma', 'retencion', 'proyecto_id', 'c11-prueba-a'))->'documento'->>'id')::uuid);
    v_ruta := extract(year from pg_temp.c11('hoy')::date)::int || '/' || (r1->>'numero') || '/' || (r1->>'numero') || '.pdf';
    v_ruta2 := extract(year from pg_temp.c11('hoy')::date)::int || '/' || (r2->>'numero') || '/' || (r2->>'numero') || '.pdf';
    a := concat_ws(', ', pg_temp.c11_color(pg_temp.c11_ctl(50)), pg_temp.c11_color(pg_temp.c11_ctl(60))) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(62));
    insert into storage.objects (bucket_id, name, metadata) values ('facturas', v_ruta, '{"size": 4321}'::jsonb), ('facturas', v_ruta2, '{"size": 1111}'::jsonb);
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_pdf(v_doc, jsonb_build_object('ruta', v_ruta, 'sha256', repeat('a', 64), 'bytes', 4321, 'huella', r1->>'huella'));
    perform pg_temp.c11_ser('editor');
    begin
      -- (en Supabase un DELETE directo a storage.objects da 42501 salvo con esta marca de la transacción; se deshace con el
      -- bloque. Es el SQL Editor quitando el archivo, para imitar «ya no está»: si esta base no lo deja por otra razón, no
      -- hay cómo imitarlo aquí y la prueba sale omitida con lo que dijo la base)
      begin
        perform set_config('storage.allow_delete_query', 'true', true);
        delete from storage.objects where bucket_id = 'facturas' and name = v_ruta;
      exception when others then
        v_por := 'esta base no dejó quitar del bucket el archivo de prueba (' || sqlstate || ': ' || left(sqlerrm, 200)
                 || '): que el control 50 avise de un PDF que ya no está no se puede probar aquí';
      end;
      if v_por is not null then
        raise exception using errcode = 'MXT02';
      end if;
      v_x := pg_temp.c11_ctl(50);
      b := case when v_x like 'rojo: el PDF 1 de la factura ' || (r1->>'numero') || ' (' || v_ruta || ') ya no está → vuelve a pintar el PDF%'
                then 'el 50 avisa (ya no está)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      update storage.objects set metadata = '{"size": 9}'::jsonb where bucket_id = 'facturas' and name = v_ruta;
      v_x := pg_temp.c11_ctl(50);
      c := case when v_x like 'rojo: el PDF 1 de la factura ' || (r1->>'numero') || ' (' || v_ruta || ') mide 9 y se registró con 4321 →%'
                then 'avisa (mide otra cosa)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    d := pg_temp.c11_color(pg_temp.c11_ctl(50));
    -- tres días después (con datos reales, otras facturas de hoy pueden salir también: aquí se miran las dos de la prueba)
    begin
      perform pg_temp.c11_fingir_hoy(pg_temp.c11('hoy')::date + 3);
      v_x := pg_temp.c11_ctl(60); v_y := pg_temp.c11_ctl(62);
      e := case when v_x like 'rojo: %→ están emitidas (las facturas, ya en el libro; la de la retención no lleva asiento), pero sin su PDF%'
                     and position((r2->>'numero') || ' (del ' in v_x) > 0 and position((r1->>'numero') || ' (del ' in v_x) = 0
                     and v_x like '%' || (r3->>'numero') || ' (del %; es la de la retención)%'
                then 'el 60 nombra a la que no tiene PDF (y no a la otra) y a la de la retención como lo que es' else 'el 60: ' || v_x end
           || case when v_y like 'rojo: %→ el cliente todavía no las tiene%'
                        and position((r1->>'numero') || ' (del ' in v_y) > 0 and position((r2->>'numero') || ' (del ' in v_y) > 0
                   then ', y el 62 a las dos' else ', y el 62: ' || v_y end;
      perform pg_temp.c11_ser('dueno');
      perform fn_emision_pdf(v_doc2, jsonb_build_object('ruta', v_ruta2, 'sha256', repeat('b', 64), 'bytes', 1111, 'huella', r2->>'huella'));
      f := format('el 60 %s y el 62 %s', case when position((r2->>'numero') || ' (del ' in pg_temp.c11_ctl(60)) = 0 then 'ya no la nombra' else 'SIGUE nombrándola' end,
                  case when position((r2->>'numero') || ' (del ' in pg_temp.c11_ctl(62)) > 0 then 'sí' else 'NO' end);
      perform fn_emision_envio(v_doc, jsonb_build_object('medio', 'en_mano', 'para', 'ZZ Site Superintendent'));
      perform fn_emision_envio(v_doc2, jsonb_build_object('medio', 'en_mano', 'para', 'ZZ Site Superintendent'));
      v_y := pg_temp.c11_ctl(62);
      g := case when position((r1->>'numero') || ' (del ' in v_y) = 0 and position((r2->>'numero') || ' (del ' in v_y) = 0 then 'el 62 ya no las nombra'
                else 'el 62 SIGUE: ' || v_y end;
      perform pg_temp.c11_ser('editor');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform pg_temp.c11_ser('editor');
    v_obt := format('%s | registrado y quitado del bucket: %s | con otro tamaño en el bucket: %s | de vuelta: %s | tres días después, una sin '
                    'PDF y las dos sin mandar: %s | con su PDF: %s | entregadas en mano: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' or sqlstate 'MXT02' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if v_por is not null then
    insert into _pruebas values (37, v_nom, v_esp, 'omitida: ' || v_por, null);
  else
    insert into _pruebas values (37, v_nom, v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 38. El 70 (una factura que no salió de la app con una «retención» que
--     parece un porcentaje: el conflicto con la función de QuickBooks) y el
--     72 (una factura fechada desde el corte que no salió de la app).
do $$
declare
  v_obt text; v_x text; v_corte date;
  a text; b text; c text; d text; e text;
  v_nom text := 'los controles 70 (una factura de fuera de la app con una «retención» que parece un porcentaje y no cuadra con el de su '
                'obra: el conflicto con la función de QuickBooks) y 72 (una factura fechada desde el corte hecha fuera de la app): avisan '
                'con su número; cada uno con lo suyo';
  v_esp text := 'verde y verde | una factura de fuera, de antes del corte, con «retención 10» sobre 5000.00: el 70 avisa (parece un '
                'porcentaje) y el 72 verde | si la obra retiene de verdad el 0.2 % (10.00 de 5000.00): ya no avisa | una factura de fuera '
                'fechada desde el corte: el 72 avisa (con su número y su fecha) y el 70 verde | de vuelta: verde y verde';
begin
  if pg_temp.c11_omitir(38, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(38, v_nom, v_esp, array[70, 72]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    if pg_temp.c11_color(pg_temp.c11_ctl(72)) = 'rojo' then
      v_obt := 'omitida: con el corte adelantado a hoy para las pruebas, esta base ya tiene facturas de hoy hechas fuera de la app (el control '
               '72 las ve): aquí no se puede ver que pase a rojo y vuelva';
      raise exception using errcode = 'MXT00';
    end if;
    select k.corte into v_corte from emision_config k where k.id = 1;
    a := pg_temp.c11_color(pg_temp.c11_ctl(70)) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(72));
    begin
      insert into facturas (proyecto_id, num, fecha, monto, retencion, estado) values ('c11-prueba-b', 'ZZ-903', v_corte - 1, 5000, 10, 'emitida');
      v_x := pg_temp.c11_ctl(70);
      b := case when v_x like 'rojo: la factura #ZZ-903 de C11 PRUEBA Dos (monto $5,000.00) dice retención 10 → la retención de una factura va en DÓLARES%'
                then 'el 70 avisa (parece un porcentaje)' else 'el 70: ' || v_x end
           || ' y el 72 ' || pg_temp.c11_color(pg_temp.c11_ctl(72));
      perform pg_temp.c11_ser('dueno');
      perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 0.2}'::jsonb);
      perform pg_temp.c11_ser('editor');
      c := case when pg_temp.c11_ctl(70) = 'verde' then 'ya no avisa' else 'SIGUE avisando' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform pg_temp.c11_ser('editor');
    begin
      insert into facturas (proyecto_id, num, fecha, monto, estado) values ('c11-prueba-b', 'ZZ-904', pg_temp.c11('hoy')::date, 250.25, 'emitida');
      v_x := pg_temp.c11_ctl(72);
      d := case when v_x like 'rojo: #ZZ-904 (del ' || fn_emision_dia(pg_temp.c11('hoy')::date) || ', $250.25) → desde el %se factura por la app%'
                then 'el 72 avisa (con su número y su fecha)' else 'el 72: ' || v_x end
           || ' y el 70 ' || pg_temp.c11_color(pg_temp.c11_ctl(70));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    e := pg_temp.c11_color(pg_temp.c11_ctl(70)) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(72));
    v_obt := format('%s | una factura de fuera, de antes del corte, con «retención 10» sobre 5000.00: %s | si la obra retiene de verdad el 0.2 %% '
                    '(10.00 de 5000.00): %s | una factura de fuera fechada desde el corte: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 39. El 80 (el porcentaje de la tarjeta puesto con la tarjeta apagada; el
--     cobro con tarjeta lo prueba la 32), el 85 (los datos de la empresa y el
--     «How to pay», pasado el corte) y el 90 (las protecciones de la capa,
--     por el nombre exacto de cada objeto).
do $$
declare
  v_obt text; v_x text; v_si text := '';
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_nom text := 'los controles 80 (el porcentaje de la tarjeta puesto con la tarjeta apagada), 85 (faltan los datos de la empresa o el «How '
                'to pay» pasado el corte) y 90 (las protecciones: en rojo si anon ejecuta una función, una tabla pierde su RLS, una función '
                'pasa a SECURITY DEFINER, una vista pierde security_invoker, se apaga una guarda, service_role lee una tabla, '
                'authenticated puede borrar la serie o la función del número deja de ser la que es); deshecho, verde';
  v_esp text := 'verde, verde y verde | el porcentaje de la tarjeta puesto por debajo con la tarjeta apagada: el 80 avisa (y dice que se '
                'quite) | de vuelta: verde | sin los datos de la empresa ni el «How to pay», pasado el corte: el 85 avisa (dice los dos, y '
                'dónde ponerlos) | con el «How to pay»: sigue, por los datos de la empresa | con todo: verde | el 90, en rojo si: anon '
                'ejecuta una función (sí), una tabla pierde su RLS (sí), una función pasa a SECURITY DEFINER (sí), una vista pierde '
                'security_invoker (sí), se apaga una guarda (sí), service_role lee una tabla (sí), authenticated puede borrar la serie '
                '(sí), la función del número deja de ser SECURITY DEFINER (sí) | deshecho todo: verde';
begin
  if pg_temp.c11_omitir(39, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(39, v_nom, v_esp, array[80, 85, 90]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    a := concat_ws(', ', pg_temp.c11_color(pg_temp.c11_ctl(80)), pg_temp.c11_color(pg_temp.c11_ctl(85))) || ' y ' || pg_temp.c11_color(pg_temp.c11_ctl(90));
    begin
      perform set_config('mx_emision.escribe', 'emision_config', true);
      update emision_config set tarjeta_pct = 3 where id = 1;
      perform set_config('mx_emision.escribe', '', true);
      v_x := pg_temp.c11_ctl(80);
      b := case when v_x like 'rojo: el porcentaje de la tarjeta está puesto (3 %) y la tarjeta sigue apagada → quítalo de los ajustes de facturación%'
                then 'el 80 avisa (y dice que se quite)' else v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform set_config('mx_emision.escribe', '', true);
    c := pg_temp.c11_color(pg_temp.c11_ctl(80));
    -- el 85
    perform fn_emision_config('{"empresa": {}, "como_pagar": ""}'::jsonb);
    v_x := pg_temp.c11_ctl(85);
    d := case when v_x like 'rojo: Faltan los datos de la empresa y el texto «How to pay» en los ajustes de facturación → sin eso no se puede emitir '
                            'ninguna factura: ponlos en Facturación → Ajustes%'
              then 'el 85 avisa (dice los dos, y dónde ponerlos)' else v_x end;
    perform fn_emision_config('{"como_pagar": "Check payable to ZZ Electric C11 PRUEBA, Inc."}'::jsonb);
    v_x := pg_temp.c11_ctl(85);
    e := case when v_x like 'rojo: Faltan los datos de la empresa en los ajustes de facturación →%' then 'sigue, por los datos de la empresa' else v_x end;
    perform fn_emision_config('{"empresa": {"nombre": "ZZ Electric C11 PRUEBA, Inc."}}'::jsonb);
    f := pg_temp.c11_color(pg_temp.c11_ctl(85));
    -- el 90, cada cosa en su bloque (se deshace)
    begin
      grant execute on function public.fn_emision_emitir(uuid, text, jsonb) to anon;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %fn_emision_emitir la puede ejecutar anon%' then 'anon ejecuta una función (sí)' else 'anon ejecuta una función (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.emision_documentos disable row level security;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %emision_documentos sin RLS%' then ', una tabla pierde su RLS (sí)' else ', una tabla pierde su RLS (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter function public.fn_emision_pago(uuid) security definer;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %fn_emision_pago es SECURITY DEFINER%' then ', una función pasa a SECURITY DEFINER (sí)'
                           else ', una función pasa a SECURITY DEFINER (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter view public.v_emision_estado reset (security_invoker);
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %v_emision_estado sin security_invoker%' then ', una vista pierde security_invoker (sí)'
                           else ', una vista pierde security_invoker (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.emision_serie disable trigger trg_emision_serie_guarda;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %la guarda trg_emision_serie_guarda de emision_serie está apagada%' then ', se apaga una guarda (sí)'
                           else ', se apaga una guarda (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      grant select on public.emision_documentos to service_role;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %service_role puede SELECT en emision_documentos%' then ', service_role lee una tabla (sí)'
                           else ', service_role lee una tabla (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      grant delete on public.emision_serie to authenticated;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %authenticated puede DELETE en emision_serie%' then ', authenticated puede borrar la serie (sí)'
                           else ', authenticated puede borrar la serie (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter function public.fn_emision_numerar() security invoker;
      v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %la función del número ya no es la de un trigger con los permisos del dueño de la base%'
                           then ', la función del número deja de ser SECURITY DEFINER (sí)' else ', la función del número deja de ser SECURITY DEFINER (NO)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    g := v_si;
    h := pg_temp.c11_ctl(90);
    v_obt := format('%s | el porcentaje de la tarjeta puesto por debajo con la tarjeta apagada: %s | de vuelta: %s | sin los datos de la empresa ni '
                    'el «How to pay», pasado el corte: %s | con el «How to pay»: %s | con todo: %s | el 90, en rojo si: %s | deshecho todo: %s',
                    a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 40. LO QUE LA PANTALLA PINTA: las columnas de las cuatro vistas son las
--     del contrato; v_emision_documentos (los borradores y las facturas, con
--     lo que deben HOY en el libro), v_emision_obras (cada obra para
--     facturarla, con sus hitos: cuál tiene factura, cuál borrador, cuál se
--     puede) y v_emision_estado (los contadores de la portada).
do $$
declare
  v_obt text; v_e0 record; v_e1 record; v_r jsonb; v_b jsonb; v_cols text; v_em record; v_bo record; v_o record; v_o4 record; v_h jsonb;
  a text; b text; c text; d text; e text;
  v_nom text := 'LO QUE LA PANTALLA PINTA: las columnas de las cuatro vistas son las del contrato; v_emision_documentos trae cada borrador '
                'y cada factura con lo que debe hoy; v_emision_obras cada obra con su contrato, lo facturado y sus hitos (con su factura, '
                'con su borrador, o por facturar); v_emision_estado cuenta borradores, emitidas, sin PDF y sin mandar';
  v_esp text := 'las columnas de las cuatro vistas son las del contrato | los documentos de la obra: una emitida (su número, su asiento, '
                'debe 3333.33) y un borrador (con su visto, sin número) | la obra Uno: contrato 10000.00, facturado 3333.33 en 1 factura, '
                'por facturar 6666.67, 2 hitos por facturar (6666.67), 1 borrador, con su regla de ingreso; sus hitos: el primero con su '
                'factura (ya no se puede), el segundo con su borrador (se puede), el tercero se puede | la obra Cuatro: sin contrato, sin '
                'hitos, nada facturado | el estado cuenta uno más de cada: borradores, emitidas, sin PDF y sin mandar; dice hasta qué día se '
                'puede poner el corte y, en llano, por qué la tarjeta está apagada';
begin
  if pg_temp.c11_omitir(40, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    select * into v_e0 from v_emision_estado;
    v_r := pg_temp.c11_hito(-1110000001);
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    perform pg_temp.c11_ser('dueno');
    select coalesce(string_agg(x.v || ': ' || x.cols, ' / ' order by x.v), 'las columnas de las cuatro vistas son las del contrato') into v_cols
      from (select k.table_name::text as v, string_agg(k.column_name::text, ', ' order by k.ordinal_position) as cols
              from information_schema.columns k
             where k.table_schema = 'public' and k.table_name = any (pg_temp.c11_vistas())
             group by k.table_name) x
     where x.cols is distinct from case x.v
       when 'v_emision_estado' then 'hoy, corte, por_la_app, camino, texto, dias_para_el_corte, serie_formato, siguiente_numero, terminos_dias, falta, '
                                    'puede_emitir, pago_en_linea, tarjeta, borradores, emitidas, anuladas, sin_pdf, sin_mandar, corte_hasta, '
                                    'tarjeta_texto'
       when 'v_emision_documentos' then 'id, estado, forma, proyecto_id, obra, cliente, a_contratista, hito_id, hito, es_deposito, numero, fecha, vence, '
                                        'monto, retencion_pct, retencion, a_pagar, factura_id, asiento, saldo, saldo_retencion, nota_credito, '
                                        'anulado_el, anulado_motivo, pdfs, pdf_ruta, pdf_el, envios, enviado_el, enviado_a, visto, creado_el, '
                                        'actualizado_el, emitido_el'
       when 'v_emision_obras' then 'proyecto_id, obra, tipo, estado, cliente, a_contratista, contrato, facturado, facturas, por_facturar, '
                                   'retencion_pct, retencion_origen, retenido, hitos_pendientes, hitos_pendientes_monto, hitos, borradores, '
                                   'ingreso_listo'
       when 'v_emision_control' then 'orden, cuadre, nivel, ok, detalle' end;
    a := v_cols;
    select * into v_em from v_emision_documentos x where x.id = (v_r->>'documento')::uuid;
    select * into v_bo from v_emision_documentos x where x.id = (v_b->'documento'->>'id')::uuid;
    b := case when (select count(*) from v_emision_documentos x where x.proyecto_id = 'c11-prueba-a') = 2
                   and v_em.estado = 'emitida' and v_em.numero = v_r->>'numero' and v_em.asiento = v_r->>'asiento' and v_em.forma = 'hito'
                   and v_em.obra = 'C11 PRUEBA Uno' and v_em.cliente = 'ZZ Cliente Uno' and v_em.hito = 'C11 PRUEBA Milestone 1'
                   and v_em.factura_id = (v_r->>'factura_id')::bigint and v_em.saldo_retencion = 0 and v_em.visto is null
                   and v_em.pdfs = 0 and v_em.envios = 0 and v_em.emitido_el is not null and v_em.fecha = pg_temp.c11('hoy')::date
              then format('una emitida (su número, su asiento, debe %s)', v_em.saldo) else 'MAL la emitida: ' || to_jsonb(v_em)::text end
         || case when v_bo.estado = 'borrador' and v_bo.numero is null and v_bo.visto = v_b->>'visto' and v_bo.monto = 3333.33
                      and v_bo.factura_id is null and v_bo.saldo is null and v_bo.asiento is null and v_bo.fecha is null
                 then ' y un borrador (con su visto, sin número)' else ' y MAL el borrador: ' || to_jsonb(v_bo)::text end;
    select * into v_o from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    v_h := v_o.hitos;
    c := format('contrato %s, facturado %s en %s factura, por facturar %s, %s hitos por facturar (%s), %s borrador, %s; sus hitos: %s',
                v_o.contrato, v_o.facturado, v_o.facturas, v_o.por_facturar, v_o.hitos_pendientes, v_o.hitos_pendientes_monto, v_o.borradores,
                case when v_o.ingreso_listo and v_o.cliente = 'ZZ Cliente Uno' and not v_o.a_contratista and v_o.tipo = 'servicio'
                          and v_o.retencion_pct = 0 and v_o.retencion_origen = 'ninguna'
                     then 'con su regla de ingreso' else 'SIN su regla de ingreso' end,
                case when jsonb_array_length(v_h) = 3
                          and (v_h->0->>'id')::bigint = -1110000001 and v_h->0->>'factura' = v_r->>'numero' and not (v_h->0->>'puede')::boolean
                          and v_h->0->>'estado' = 'facturado' and v_h->0->>'borrador' is null and (v_h->0->>'monto')::numeric = 3333.33
                          and v_h->0->>'titulo' = 'C11 PRUEBA Milestone 1'
                          and (v_h->1->>'id')::bigint = -1110000002 and v_h->1->>'borrador' = v_b->'documento'->>'id' and (v_h->1->>'puede')::boolean
                          and v_h->1->>'factura' is null
                          and (v_h->2->>'id')::bigint = -1110000003 and (v_h->2->>'puede')::boolean and v_h->2->>'borrador' is null
                          and v_h->2->>'factura' is null and (v_h->2->>'monto')::numeric = 3333.34
                     then 'el primero con su factura (ya no se puede), el segundo con su borrador (se puede), el tercero se puede'
                     else 'MAL: ' || v_h::text end);
    select * into v_o4 from v_emision_obras o where o.proyecto_id = 'c11-prueba-d';
    d := case when v_o4.contrato is null and v_o4.por_facturar is null and v_o4.hitos = '[]'::jsonb and v_o4.hitos_pendientes = 0
                   and v_o4.facturado = 0 and v_o4.facturas = 0 and v_o4.borradores = 0 and v_o4.ingreso_listo
              then 'sin contrato, sin hitos, nada facturado' else 'MAL: ' || to_jsonb(v_o4)::text end;
    select * into v_e1 from v_emision_estado;
    perform pg_temp.c11_ser('editor');
    e := case when v_e1.borradores = v_e0.borradores + 1 and v_e1.emitidas = v_e0.emitidas + 1 and v_e1.sin_pdf = v_e0.sin_pdf + 1
                   and v_e1.sin_mandar = v_e0.sin_mandar + 1 and v_e1.anuladas = v_e0.anuladas
              then 'el estado cuenta uno más de cada: borradores, emitidas, sin PDF y sin mandar'
              else format('el estado NO cuenta bien: %s → %s', to_jsonb(v_e0)::text, to_jsonb(v_e1)::text) end
         || case when to_jsonb(v_e1)->>'tarjeta_texto' like 'La tarjeta está apagada: se enciende cuando el sistema de cobros sepa registrar el recargo%'
                      and (to_jsonb(v_e1)->>'corte_hasta')::date <= pg_temp.c11('hoy')::date
                 then '; dice hasta qué día se puede poner el corte y, en llano, por qué la tarjeta está apagada'
                 else '; SIN corte_hasta o SIN el texto de la tarjeta' end;
    v_obt := format('%s | los documentos de la obra: %s | la obra Uno: %s | la obra Cuatro: %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LO QUE ENCONTRARON LOS REVISORES (12-nov-2026), cada cosa con su prueba:
-- contra la capa de antes fallan; con esta, pasan.
-- ---------------------------------------------------------------------
-- 45. UN HITO NO SE FACTURA DOS VECES aunque su fila de facturas deje de
--     apuntarlo. El hito de una factura de la app es el de su DOCUMENTO: con
--     facturas.hito_id vaciado a mano (o cambiado), otro borrador de ese hito
--     no se abre, uno que ya estuviera abierto no se emite, la lista de
--     hitos de la obra lo sigue dando por facturado, el control 42 lo avisa
--     y, si otra factura de ese hito entra por fuera, el 40 se pone en rojo.
--     UN HITO BORRADO Y VUELTO A CREAR es otro hito (no hay con qué saber
--     que es el mismo): el control 42 nombra la factura del hito borrado
--     mientras a la obra le queden hitos por facturar, el borrador del nuevo
--     lo avisa (y avisa de que lo facturado pasaría del contrato), y si se
--     factura, el 44 dice que lo facturado por hitos pasa de sus hitos.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_fid bigint; v_doc1 uuid; v_doc2 uuid; v_x text; v_y text; v_b jsonb; v_h jsonb; v_ra jsonb;
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'UN HITO NO SE FACTURA DOS VECES aunque su fila de facturas deje de apuntarlo (el hito de una factura de la app es el de su '
                'documento): otro borrador no se abre, uno ya abierto no se emite, la lista de hitos lo da por facturado, el control 42 lo '
                'avisa y el 40 ve la segunda factura; UN HITO BORRADO Y VUELTO A CREAR es otro hito: el 42 nombra la factura del hito '
                'borrado, el borrador del nuevo lo avisa y avisa de que pasa del contrato, y si se factura, el 44 lo dice';
  v_esp text := 'con la fila de facturas sin su hito: otro borrador de ese hito MX008 (dice su factura), la lista de la obra lo da por '
                'facturado (no se puede), el 42 avisa (su fila de facturas ya no lo dice) y el 40 verde | un borrador de ese hito que ya '
                'estuviera abierto tampoco se emite: MX008 (ya se facturó) | si otra factura de ese hito entra por fuera: el 40 en rojo '
                '(la de la app y la de fuera) | anulada la de la app: el hito vuelve a pendiente y el borrador abierto ya se emite | un '
                'hito facturado, borrado y vuelto a crear: el 42 nombra la factura del hito borrado y los hitos por facturar; el borrador '
                'del nuevo avisa sin frenar (hito_borrado_facturado, pasa_del_contrato) | y si se factura: el 44 lo dice (5530.86 por '
                'hitos; sus hitos suman 4000.00)';
begin
  if pg_temp.c11_omitir(45, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(45, v_nom, v_esp, array[40, 42, 44]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- (1) la fila de facturas deja de apuntar a su hito
    r1 := pg_temp.c11_hito(-1110000001);
    v_doc1 := (r1->>'documento')::uuid; v_fid := (r1->>'factura_id')::bigint;
    update facturas set hito_id = null where id = v_fid;
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001}') $q$);
    perform pg_temp.c11_ser('dueno');
    select o.hitos->0 into v_h from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('editor');
    v_y := pg_temp.c11_ctl(42);
    a := format('otro borrador de ese hito %s, la lista de la obra %s, el 42 %s y el 40 %s',
                case when v_x like 'MX008: El hito «C11 PRUEBA Milestone 1» ya se facturó: factura ' || (r1->>'numero') || ' del %' then 'MX008 (dice su factura)' else v_x end,
                case when v_h->>'factura' = r1->>'numero' and not (v_h->>'puede')::boolean then 'lo da por facturado (no se puede)'
                     else 'lo da por SIN FACTURAR: ' || v_h::text end,
                case when v_y like 'rojo: la factura ' || (r1->>'numero') || ' ($3,333.33) de C11 PRUEBA Uno salió del hito «C11 PRUEBA Milestone 1» y su '
                                   'fila de facturas ya no lo dice →%' then 'avisa (su fila de facturas ya no lo dice)' else coalesce(v_y, '(no está)') end,
                coalesce(pg_temp.c11_color(pg_temp.c11_ctl(40)), '(no está)'));
    -- (2) un borrador de ese hito que ya estuviera abierto (puesto aquí a mano, con la marca de la guarda, si la capa no dejó abrirlo)
    select x.id into v_doc2 from emision_documentos x where x.hito_id = -1110000001 and x.estado = 'borrador';
    if v_doc2 is null then
      perform set_config('mx_emision.escribe', 'emision_documentos', true);
      insert into emision_documentos (forma, proyecto_id, hito_id, cliente, monto, a_pagar)
      values ('hito', 'c11-prueba-a', -1110000001, '{"nombre": "ZZ Cliente Uno"}'::jsonb, 3333.33, 3333.33) returning id into v_doc2;
      perform set_config('mx_emision.escribe', 'emision_lineas', true);
      insert into emision_lineas (documento_id, n, tipo, descripcion, cantidad, precio, importe)
      values (v_doc2, 1, 'hito', 'C11 PRUEBA Milestone 1', 1, 3333.33, 3333.33);
      perform set_config('mx_emision.escribe', '', true);
    end if;
    v_x := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc2, fn_emision_documento(v_doc2)->>'visto'));
    b := case when v_x like 'MX008: El hito «C11 PRUEBA Milestone 1» ya se facturó: factura ' || (r1->>'numero') || ' del %' then 'MX008 (ya se facturó)' else v_x end;
    -- (3) otra factura de ese hito entra por fuera: el 40 la ve (el hito de la de la app es el de su documento)
    begin
      insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
      values ('c11-prueba-a', 'ZZ-910', pg_temp.c11('hoy')::date, 3333.33, -1110000001, 'emitida');
      v_x := pg_temp.c11_ctl(40);
      c := case when v_x like 'rojo: el hito «C11 PRUEBA Milestone 1» de C11 PRUEBA Uno tiene 2 facturas vivas (' || (r1->>'numero') || ', ZZ-910) →%'
                then 'el 40 en rojo (la de la app y la de fuera)' else 'el 40: ' || v_x end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- (4) anulada la de la app, el hito queda libre
    v_ra := pg_temp.c11_anular(v_doc1, 'c11-pruebas: se rehace');
    r2 := pg_temp.c11_emitir(v_doc2);
    d := format('el hito vuelve a %s y el borrador abierto %s', v_ra->>'hito_estado',
                case when r2->>'estado' = 'emitida' and r2->>'hito_estado' = 'facturado' then 'ya se emite' else 'NO se emite: ' || r2::text end);
    -- (5) un hito facturado, borrado y vuelto a crear (la obra Tres: depósito 1,234.57 + final 2,765.43 = contrato 4,000.00)
    r3 := pg_temp.c11_hito(-1110000005);
    delete from hitos where id = -1110000005;
    insert into hitos (id, proyecto_id, titulo, monto, estado, orden, es_deposito) overriding system value
    values (-1110000007, 'c11-prueba-c', 'C11 PRUEBA Final', 2765.43, 'pendiente', 1, false);
    v_y := pg_temp.c11_ctl(42);
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000007));
    e := case when v_y like '%la factura ' || (r3->>'numero') || ' ($2,765.43) de C11 PRUEBA Tres salió de un hito que después se borró, y la obra tiene '
                            'hitos por facturar («C11 PRUEBA Deposit», «C11 PRUEBA Final»)%'
              then 'el 42 nombra la factura del hito borrado y los hitos por facturar' else 'el 42: ' || coalesce(v_y, '(no está)') end
         || case when (v_b->>'puede_emitir')::boolean
                      and (select array_agg(x->>'codigo' order by x->>'codigo') from jsonb_array_elements(v_b->'avisos') x
                            where x->>'codigo' in ('hito_borrado_facturado', 'pasa_del_contrato') and not (x->>'frena')::boolean)
                          = array['hito_borrado_facturado', 'pasa_del_contrato']
                      and exists (select 1 from jsonb_array_elements(v_b->'avisos') x
                                   where x->>'codigo' = 'hito_borrado_facturado' and x->>'texto' like '%la factura ' || (r3->>'numero') || ' ($2,765.43) salió de un hito que después se borró%')
                 then '; el borrador del nuevo avisa sin frenar (hito_borrado_facturado, pasa_del_contrato)'
                 else '; el borrador del nuevo: ' || left((v_b->'avisos')::text, 400) end;
    -- (6) y si se factura
    perform pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    v_x := pg_temp.c11_ctl(44);
    f := case when v_x like 'rojo: en C11 PRUEBA Tres lo facturado por hitos suma $5,530.86 (%) y sus hitos suman $4,000.00 →%'
              then 'el 44 lo dice (5530.86 por hitos; sus hitos suman 4000.00)' else 'el 44: ' || coalesce(v_x, '(no está)') end;
    v_obt := format('con la fila de facturas sin su hito: %s | un borrador de ese hito que ya estuviera abierto tampoco se emite: %s | si otra '
                    'factura de ese hito entra por fuera: %s | anulada la de la app: %s | un hito facturado, borrado y vuelto a crear: %s | y '
                    'si se factura: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 46. EL BUCKET «facturas» PIDE EL CÓDIGO DEL TELÉFONO. Storage no pasa por
--     la guarda de s1: con solo la contraseña de Edgar (una sesión aal1) se
--     leían y se subían los PDF. Ahora no: ni ve ni sube; con el código
--     (aal2), sí. Y aunque OTRA policy de Storage —de otra parte de la app—
--     dejara leer y subir todo, en este bucket siguen sin entrar la sesión
--     sin código, el equipo y la llave pública (los candados «restrictive»).
--     El control 90 mira que los candados sigan puestos.
do $$
declare
  v_obt text; r1 jsonb; v_ruta text; v_puede boolean := true; v_por text; v_k bigint; v_k2 bigint; v_x text; v_si text := '';
  a text; b text; c text := null; d text := null;
  v_nom text := 'EL BUCKET «facturas» PIDE EL CÓDIGO DEL TELÉFONO: el dueño con solo su contraseña (aal1) no ve los PDF ni sube; con el '
                'código (aal2), sí; aunque otra policy de Storage deje leer y subir todo, en este bucket no entran la sesión sin código, '
                'el equipo ni la llave pública; y el control 90 se pone en rojo si un candado se quita, deja de pedir el código o deja de '
                'cerrar';
  v_esp text := 'el dueño solo con su contraseña (aal1): ve 0 PDF y no sube | con el código del teléfono (aal2): ve 1 y sube | con otra '
                'policy de Storage que deja leer y subir todo: aal1 sigue viendo 0 en facturas (y 1 en otro bucket) y no sube; el equipo '
                've 0; la llave pública ve 0 | el control 90, en rojo si: se quita un candado (sí), uno deja de pedir el código (sí), uno '
                'deja de cerrar (sí); deshecho, verde';
begin
  if pg_temp.c11_omitir(46, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_storage') <> 'true' then
    insert into _pruebas values (46, v_nom, v_esp, 'omitida: esta base no tiene Storage (storage.objects): el bucket no se puede probar aquí', null);
    return;
  end if;
  if pg_temp.c11_omitir_rojo(46, v_nom, v_esp, array[90]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    r1 := pg_temp.c11_hito(-1110000001);
    v_ruta := extract(year from pg_temp.c11('hoy')::date)::int || '/' || (r1->>'numero') || '/';
    execute 'insert into storage.objects (bucket_id, name, metadata) values (''facturas'', $1, ''{"size": 1234}''::jsonb)' using v_ruta || 'c11-prueba-46.pdf';
    -- el dueño con solo su contraseña (aal1)
    perform pg_temp.c11_ser_aal1();
    execute 'select count(*) from storage.objects where bucket_id = ''facturas'' and name like $1' into v_k using v_ruta || '%';
    begin
      execute 'insert into storage.objects (bucket_id, name, owner) values (''facturas'', $1, $2)' using v_ruta || 'c11-prueba-46-aal1.pdf', pg_temp.c11('dueno')::uuid;
      v_x := 'SUBE';
    exception when insufficient_privilege then v_x := 'no sube';
    end;
    a := format('ve %s PDF y %s', v_k, v_x);
    -- con el código (aal2)
    perform pg_temp.c11_ser('dueno');
    execute 'select count(*) from storage.objects where bucket_id = ''facturas'' and name like $1' into v_k using v_ruta || '%';
    begin
      execute 'insert into storage.objects (bucket_id, name, owner) values (''facturas'', $1, $2)' using v_ruta || 'c11-prueba-46-aal2.pdf', pg_temp.c11('dueno')::uuid;
      v_x := 'sube';
    exception when insufficient_privilege then v_x := 'NO sube';
    end;
    b := format('ve %s y %s', v_k, v_x);
    perform pg_temp.c11_ser('editor');
    -- LA SEGUNDA MITAD pone y quita policies de prueba en storage.objects, dentro de bloques que se deshacen. Cada una
    -- toma, un instante, el candado más fuerte de la tabla de TODOS los archivos de la app: va con el tope de espera de
    -- esta corrida (medio segundo). Si la app tiene la tabla tomada y no la suelta (una lectura larga, un respaldo), no se
    -- espera más —detrás de quien espera ese candado se quedan esperando todas las lecturas de archivos que lleguen—: se
    -- prueba solo la primera mitad, y se dice. Lo mismo si esta base no deja poner policies en Storage desde aquí, o si
    -- tiene otros candados de Storage con los que la comparación no dice nada.
    -- ¿deja esta base poner y quitar policies de Storage desde aquí? (en el banco, sí)
    begin
      execute 'create policy "c11 prueba: sonda" on storage.objects for select to authenticated using (false)';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when lock_not_available then
        v_puede := false;
        v_por := 'la app (u otra sesión) estaba usando los archivos de Storage y no soltó la tabla en medio segundo: no se esperó más, '
                 'para no dejar esperando a la app; vuelve a pegar el archivo en otro momento para probar la segunda mitad';
      when others then
        v_puede := false;
        v_por := 'la base no deja poner policies de prueba en Storage (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
    end;
    if v_puede then
      begin
        -- otra policy de Storage, de otra parte de la app, que deja leer y subir TODO
        begin
          execute 'create policy "c11 prueba: todo" on storage.objects for all to authenticated, anon using (true) with check (true)';
          execute 'insert into storage.buckets (id, name) values (''c11-prueba-otro'', ''c11-prueba-otro'') on conflict (id) do nothing';
          execute 'insert into storage.objects (bucket_id, name) values (''c11-prueba-otro'', ''c11-prueba-46.txt'')';
          perform pg_temp.c11_ser_aal1();
          execute 'select count(*) from storage.objects where bucket_id = ''facturas'' and name like $1' into v_k using v_ruta || '%';
          execute 'select count(*) from storage.objects where bucket_id = ''c11-prueba-otro''' into v_k2;
          if v_k2 <> 1 then
            -- (con una policy que deja leer TODO, la sesión sin código tampoco ve el archivo del otro bucket: aquí cierra
            -- algo que no es de c11, y que en «facturas» vea 0 no diría nada)
            raise exception using errcode = 'MXT02';
          end if;
          begin
            execute 'insert into storage.objects (bucket_id, name, owner) values (''facturas'', $1, $2)' using v_ruta || 'c11-prueba-46-aal1.pdf', pg_temp.c11('dueno')::uuid;
            v_x := 'SUBE';
          exception when insufficient_privilege then v_x := 'no sube';
          end;
          c := format('aal1 sigue viendo %s en facturas (y %s en otro bucket) y %s', v_k, v_k2, v_x);
          perform pg_temp.c11_ser('p1');
          execute 'select count(*) from storage.objects where bucket_id = ''facturas''' into v_k;
          c := c || format('; el equipo ve %s', v_k);
          perform pg_temp.c11_ser('anon');
          execute 'select count(*) from storage.objects where bucket_id = ''facturas''' into v_k;
          c := c || format('; la llave pública ve %s', v_k);
          perform pg_temp.c11_ser('editor');
          raise exception using errcode = 'MXT01';
        exception when sqlstate 'MXT01' then null;
        end;
        perform pg_temp.c11_ser('editor');
        -- el control 90
        begin
          execute 'drop policy "facturas: solo el dueno con su codigo lee" on storage.objects';
          v_si := case when pg_temp.c11_ctl(90) like 'rojo: %el bucket de las facturas: falta el candado «facturas: solo el dueno con su codigo lee»%'
                       then 'se quita un candado (sí)' else 'se quita un candado (NO)' end;
          raise exception using errcode = 'MXT01';
        exception when sqlstate 'MXT01' then null;
        end;
        begin
          execute 'drop policy "facturas: el dueno lee" on storage.objects';
          execute 'create policy "facturas: el dueno lee" on storage.objects for select to authenticated using (bucket_id = ''facturas'' and public.es_dueno())';
          v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %el bucket de las facturas: el candado «facturas: el dueno lee» no pide el código del teléfono%'
                               then ', uno deja de pedir el código (sí)' else ', uno deja de pedir el código (NO)' end;
          raise exception using errcode = 'MXT01';
        exception when sqlstate 'MXT01' then null;
        end;
        begin
          execute 'drop policy "facturas: no se borra" on storage.objects';
          execute 'create policy "facturas: no se borra" on storage.objects for delete to anon, authenticated using (bucket_id is distinct from ''facturas'')';
          v_si := v_si || case when pg_temp.c11_ctl(90) like 'rojo: %el bucket de las facturas: el candado «facturas: no se borra» ya no es de los que cierran%'
                               then ', uno deja de cerrar (sí)' else ', uno deja de cerrar (NO)' end;
          raise exception using errcode = 'MXT01';
        exception when sqlstate 'MXT01' then null;
        end;
        d := v_si || '; deshecho, ' || pg_temp.c11_ctl(90);
      exception
        when lock_not_available then
          v_puede := false;
          v_por := 'la app (u otra sesión) empezó a usar los archivos de Storage a media prueba y no soltó la tabla en medio segundo: no se '
                   'esperó más, para no dejar esperando a la app; vuelve a pegar el archivo en otro momento para probar la segunda mitad';
        when sqlstate 'MXT02' then
          v_puede := false;
          v_por := 'con una policy de prueba que deja leer todo, la sesión sin el código tampoco ve el archivo de OTRO bucket: esta base '
                   'tiene otros candados de Storage que no son de aquí, y con ellos la comparación no dice nada';
        when others then
          -- (lo que se monta para comparar —otra policy, otro bucket, un archivo— no entró en esta base: no es de la capa)
          v_puede := false;
          v_por := 'esta base no dejó montar la comparación de la segunda mitad (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
      end;
      perform pg_temp.c11_ser('editor');
    end if;
    v_obt := format('el dueño solo con su contraseña (aal1): %s | con el código del teléfono (aal2): %s', a, b)
             || case when v_puede then format(' | con otra policy de Storage que deja leer y subir todo: %s | el control 90, en rojo si: %s', c, d)
                     else '' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if not v_puede then
    -- (aquí la segunda mitad no se pudo probar: se prueba lo que se puede, y se dice por qué)
    v_esp := split_part(v_esp, ' | con otra policy de Storage', 1);
    insert into _pruebas values (46, v_nom || ' (aquí, solo lo primero: ' || coalesce(v_por, '') || ')', v_esp, v_obt, v_obt = v_esp);
  else
    insert into _pruebas values (46, v_nom, v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 47. ANULAR CON UN PAGO POR CUENTA DE BANCO EN CAMINO: no. Si se anulara,
--     ese dinero llegaría a una factura anulada, los cobros en línea lo
--     dejarían de anticipo de la obra, y la factura buena seguiría debiendo
--     entera aunque el cliente ya pagó. MX008, en llano, y nada cambia; si el
--     pago falla, se anula. Y si alguien la anula desde Contabilidad (c3
--     directo) con el pago en camino, el control 80 lo dice.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_doc uuid; v_fid bigint; v_x text; v_ra jsonb; v_vivo boolean;
  a text; b text; c text;
  v_nom text := 'ANULAR CON UN PAGO POR CUENTA DE BANCO EN CAMINO: no se anula (MX008, en llano: ese dinero llegaría a una factura anulada y '
                'quedaría de anticipo) y nada cambia; cuando el pago falla, se anula con su nota de crédito; y si se anula desde '
                'Contabilidad con el pago en camino, el control 80 lo avisa';
  v_esp text := 'con el pago en camino: MX008 (dice el pago en camino y que se espere) y nada cambia: sigue emitida, debe 1234.57, el hito '
                'facturado | el pago falla: se anula, con su nota de crédito, y el hito vuelve a pendiente | anulada desde Contabilidad con '
                'un pago en camino: el control 80 avisa (anulada, con un pago en camino de $3,333.33)';
begin
  if pg_temp.c11_omitir(47, v_nom, v_esp) then return; end if;
  if pg_temp.c11('hay_p1') <> 'true' then
    insert into _pruebas values (47, v_nom, v_esp, 'omitida: los cobros en línea (p1) no están en esta base', null);
    return;
  end if;
  if pg_temp.c11_omitir_rojo(47, v_nom, v_esp, array[80]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_p1_montar();
    r1 := pg_temp.c11_hito(-1110000006);
    v_doc := (r1->>'documento')::uuid; v_fid := (r1->>'factura_id')::bigint;
    perform pg_temp.c11_enlace(v_fid, 'plink_C11T47');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T47', 'processing', 123457, 'ach'), 'evt_C11T47a';
    v_x := pg_temp.c11_err(format('select fn_emision_anular(%L, %L)', v_doc, 'c11-pruebas: con un pago en camino'));
    a := case when v_x like 'MX008: La factura ' || (r1->>'numero') || ' tiene un pago por cuenta de banco en camino ($1,234.57): no se anula ahora.%'
                   and v_x like '%Espera a que el pago entre o falle%' and v_x !~ 'fn_|stripe_'
              then 'MX008 (dice el pago en camino y que se espere)' else v_x end
         || format(' y nada cambia: sigue %s, debe %s, el hito %s',
                   (select x.estado from v_emision_documentos x where x.id = v_doc), (select s.cxc from fn_emision_saldo(v_fid) s),
                   (select h.estado from hitos h where h.id = -1110000006));
    -- el pago falla: ya se puede anular
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T47', 'requires_payment_method', 123457, 'ach'), 'evt_C11T47b';
    select exists (select 1 from fn_emision_enlaces() e where e.factura_id = v_fid and e.estado in ('creando', 'activo')) into v_vivo;
    v_ra := pg_temp.c11_anular(v_doc, 'c11-pruebas: el pago falló');
    b := case when (v_ra->>'anulada')::boolean and v_ra->>'nota_credito' ~ '^NC-[0-9]{4}-[0-9]{4}$' and (v_ra ? 'enlace') = v_vivo
              then 'se anula, con su nota de crédito' else 'MAL: ' || v_ra::text end
         || format(', y el hito vuelve a %s', v_ra->>'hito_estado');
    -- anulada desde Contabilidad (c3 directo) con un pago en camino: el 80 lo dice
    r2 := pg_temp.c11_hito(-1110000001);
    perform pg_temp.c11_enlace((r2->>'factura_id')::bigint, 'plink_C11T47B');
    execute 'select public.fn_stripe_pago_sincronizar($1, $2)' using pg_temp.c11_foto('pi_C11T47B', 'processing', 333333, 'ach'), 'evt_C11T47c';
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular((r2->>'factura_id')::bigint, 'c11-pruebas: desde Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    v_x := pg_temp.c11_ctl(80);
    c := case when v_x like 'rojo: %la factura ' || (r2->>'numero') || ' está anulada y tiene un pago por cuenta de banco en camino ($3,333.33)%'
              then 'el control 80 avisa (anulada, con un pago en camino de $3,333.33)' else 'el control 80: ' || v_x end;
    v_obt := format('con el pago en camino: %s | el pago falla: %s | anulada desde Contabilidad con un pago en camino: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 48. EL CORTE TIENE VUELTA ATRÁS. Solo las facturas emitidas y SIN ANULAR
--     impiden poner el corte después de su fecha: una emisión de prueba,
--     anulada, no lo clava. Mover el corte de forma que cambie HOY por dónde
--     se factura lo dice (aviso); y corte_hasta (v_emision_estado) es el
--     último día en que se puede poner.
do $$
declare
  v_obt text; r1 jsonb; v_x text; v_r jsonb; v_e record; v_hasta0 date;
  a text; b text; c text; d text;
  v_nom text := 'EL CORTE TIENE VUELTA ATRÁS: con una factura viva no se pone después de su fecha (MX008, y dice que se anule si fue de '
                'prueba); anulada, sí; mover el corte de forma que cambie hoy por dónde se factura lo avisa (vuelve a QuickBooks; desde hoy '
                'ya no manda a QuickBooks); y corte_hasta dice hasta qué día se puede poner';
  v_esp text := 'con una factura viva: el corte no se pone después (MX008, dice que se anule si fue de prueba) y corte_hasta es su día | '
                'anulada: el corte sí se pone después, avisa de que el 🧾 vuelve a QuickBooks, se factura por quickbooks y corte_hasta '
                'queda vacío | de vuelta a hoy: avisa de que desde hoy ya no manda a QuickBooks | moverlo sin cambiar por dónde se factura '
                'hoy: sin aviso';
begin
  if pg_temp.c11_omitir(48, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    execute 'select e.corte_hasta from v_emision_estado e' into v_hasta0;
    perform pg_temp.c11_ser('editor');
    if v_hasta0 is not null then
      v_obt := 'omitida: esta base ya tiene facturas vivas emitidas por la app (desde el ' || fn_emision_dia(v_hasta0)
               || '): el corte no se puede mover para probarlo';
      raise exception using errcode = 'MXT00';
    end if;
    r1 := pg_temp.c11_hito(-1110000001);
    v_x := pg_temp.c11_err(format('select fn_emision_config(%L)', jsonb_build_object('corte', (pg_temp.c11('hoy')::date + 5)::text)::text));
    perform pg_temp.c11_ser('dueno');
    select * into v_e from v_emision_estado;
    perform pg_temp.c11_ser('editor');
    a := case when v_x like 'MX008: Hay facturas emitidas por la app (y sin anular) desde el ' || fn_emision_dia(pg_temp.c11('hoy')::date)
                            || ': el corte no se pone después de esa fecha. Si fueron de prueba, anúlalas primero.'
              then 'el corte no se pone después (MX008, dice que se anule si fue de prueba)' else v_x end
         || case when v_e.corte_hasta = pg_temp.c11('hoy')::date then ' y corte_hasta es su día' else ' y corte_hasta es ' || coalesce(v_e.corte_hasta::text, 'nulo') end;
    perform pg_temp.c11_anular((r1->>'documento')::uuid, 'c11-pruebas: era de prueba');
    perform pg_temp.c11_ser('dueno');
    begin
      v_r := fn_emision_config(jsonb_build_object('corte', (pg_temp.c11('hoy')::date + 5)::text));
      select * into v_e from v_emision_estado;
      b := format('el corte sí se pone después, %s, se factura por %s y corte_hasta %s',
                  case when v_r->>'aviso' like 'El corte queda en el ' || fn_emision_dia(pg_temp.c11('hoy')::date + 5) || ': hasta entonces el 🧾 vuelve a mandar a QuickBooks%'
                       then 'avisa de que el 🧾 vuelve a QuickBooks' else 'aviso: ' || coalesce(v_r->>'aviso', '(nada)') end,
                  v_e.camino, case when v_e.corte_hasta is null then 'queda vacío' else 'es ' || v_e.corte_hasta end);
    exception when others then b := sqlstate || ': ' || sqlerrm;
    end;
    v_r := fn_emision_config(jsonb_build_object('corte', pg_temp.c11('hoy')));
    c := case when v_r->>'aviso' like 'Desde hoy el 🧾 de cada hito abre la factura aquí y ya NO manda a QuickBooks%'
              then 'avisa de que desde hoy ya no manda a QuickBooks' else 'aviso: ' || coalesce(v_r->>'aviso', '(nada)') end;
    v_r := fn_emision_config(jsonb_build_object('corte', (pg_temp.c11('hoy')::date - 1)::text));
    d := case when not v_r ? 'aviso' and not fn_emision_config('{"terminos_dias": 0}'::jsonb) ? 'aviso' then 'sin aviso' else 'CON aviso: ' || (v_r->>'aviso') end;
    perform pg_temp.c11_ser('editor');
    v_obt := format('con una factura viva: %s | anulada: %s | de vuelta a hoy: %s | moverlo sin cambiar por dónde se factura hoy: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 49. EL «VISTO» ES DE LA VISTA PREVIA ENTERA, y el depósito con retención
--     se dice. Si entre que Edgar mira un borrador y lo emite entra OTRA
--     factura de la misma obra, lo que se congelaría ya no es lo que vio (su
--     ordinal, lo facturado antes): MX011, se refresca y se emite. Lo mismo
--     si lo miró un día y lo emite otro (la fecha). Y un hito de DEPÓSITO que
--     lleva retención lo avisa (sin frenar): del depósito no suele retenerse.
do $$
declare
  v_obt text; v_b2 jsonb; v_doc2 uuid; v2 text; v_b3 jsonb; v_doc3 uuid; v3 text; v_x text; v_y text; r2 jsonb; v_c jsonb; v_b jsonb; v_av jsonb;
  a text; b text; c text;
  v_nom text := 'EL «VISTO» ES DE LA VISTA PREVIA ENTERA: si entra otra factura de la obra entre que se mira un borrador y se emite (cambian '
                'su ordinal y lo facturado antes), o se mira un día y se emite otro, emitir da MX011; refrescado, emite, y lo congelado es '
                'lo que se vio; y EL DEPÓSITO CON RETENCIÓN lo avisa sin frenar (cuánto se retiene y cuánto paga)';
  v_esp text := 'otra factura de la obra entre que se miró y se emite: el visto cambia y emitir con el de antes da MX011; con el de ahora, '
                'emite como la 2 (antes 3333.33) | mirado hoy y emitido mañana: el visto cambia y da MX011 | el depósito con retención: '
                'avisa sin frenar (se le retienen $123.46 y paga ahora $1,111.11); con la retención de ese borrador en 0, ya no';
begin
  if pg_temp.c11_omitir(49, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- otra factura de la misma obra, entre medias
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    v_doc2 := (v_b2->'documento'->>'id')::uuid; v2 := v_b2->>'visto';
    perform pg_temp.c11_hito(-1110000001);
    v_y := fn_emision_documento(v_doc2)->>'visto';
    v_x := pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc2, v2));
    r2 := pg_temp.c11_emitir(v_doc2);
    select x.contenido into v_c from emision_documentos x where x.id = v_doc2;
    a := format('el visto %s y emitir con el de antes da %s; con el de ahora, emite como la %s (antes %s)',
                case when v_y is distinct from v2 then 'cambia' else 'NO cambia' end,
                v_x, v_c->>'ordinal', v_c->'contrato'->>'facturado_antes');
    -- mirado hoy, emitido mañana
    v_b3 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003));
    v_doc3 := (v_b3->'documento'->>'id')::uuid; v3 := v_b3->>'visto';
    begin
      perform pg_temp.c11_fingir_hoy(pg_temp.c11('hoy')::date + 1);
      v_y := fn_emision_documento(v_doc3)->>'visto';
      b := format('el visto %s y da %s', case when v_y is distinct from v3 then 'cambia' else 'NO cambia' end,
                  pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_doc3, v3)));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- el depósito con retención
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-c", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000004));
    select x into v_av from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'deposito_con_retencion';
    c := case when v_av is not null and not (v_av->>'frena')::boolean and (v_b->>'puede_emitir')::boolean
                   and v_av->>'texto' like 'Es el depósito y lleva retención (10 %: se le retienen $123.46 y paga ahora $1,111.11).%'
              then 'avisa sin frenar (se le retienen $123.46 y paga ahora $1,111.11)' else 'NO avisa: ' || left((v_b->'avisos')::text, 300) end;
    v_b := pg_temp.c11_borrador(jsonb_build_object('documento', v_b->'documento'->>'id', 'retencion_pct', 0));
    c := c || case when not exists (select 1 from jsonb_array_elements(v_b->'avisos') x where x->>'codigo' = 'deposito_con_retencion')
                   then '; con la retención de ese borrador en 0, ya no' else '; con la retención en 0 SIGUE avisando' end;
    v_obt := format('otra factura de la obra entre que se miró y se emite: %s | mirado hoy y emitido mañana: %s | el depósito con retención: %s',
                    a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (49, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 50. LAS COBRADAS EN EL LIBRO, MARCADAS EN LA OBRA (el control 64). Desde el
--     corte nadie marca sola la casilla «cobrada» de la ficha (antes la
--     marcaba QuickBooks): una factura de la app que el libro ya tiene
--     cobrada ENTERA y sigue sin marcar, la ficha y el portal del cliente la
--     enseñan como pendiente. Esta capa no toca la casilla (es de Edgar): lo
--     dice. Con la retención todavía por cobrar, no la nombra.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_x text;
  a text; b text; c text;
  v_nom text := 'el control 64 (una factura de la app cobrada ENTERA en el libro y sin marcar como cobrada en la ficha de su obra): avisa con '
                'su número y qué hacer; con su retención todavía por cobrar no la nombra; marcada en la obra, verde';
  v_esp text := 'verde | cobrada entera en el libro y sin marcar en la obra: el 64 la nombra y dice qué hacer (y no nombra a la que todavía '
                'tiene su retención por cobrar) | marcada como cobrada en la obra: verde';
begin
  if pg_temp.c11_omitir(50, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(50, v_nom, v_esp, array[64]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    r1 := pg_temp.c11_hito(-1110000001);
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-b", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    r2 := pg_temp.c11_hito(-1110000006);
    a := pg_temp.c11_ctl(64);
    perform pg_temp.c11_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c11('hoy'), 'monto', '4444.44', 'medio', 'cheque', 'referencia', 'C11-PRUEBA-50',
              'duplicado_confirmado', 'c11-pruebas: un cobro de prueba',
              'aplicaciones', jsonb_build_array(
                jsonb_build_object('factura_id', (r1->>'factura_id')::bigint, 'monto', '3333.33'),
                jsonb_build_object('factura_id', (r2->>'factura_id')::bigint, 'monto', '1111.11'))));
    perform pg_temp.c11_ser('editor');
    v_x := pg_temp.c11_ctl(64);
    b := case when v_x like 'rojo: ' || (r1->>'numero') || ' ($3,333.33, de C11 PRUEBA Uno) → el libro ya las tiene cobradas enteras%'
                   and v_x like '%Márcalas como cobradas en la obra%' and position(r2->>'numero' in v_x) = 0
              then 'el 64 la nombra y dice qué hacer (y no nombra a la que todavía tiene su retención por cobrar)' else 'el 64: ' || coalesce(v_x, '(no está)') end;
    -- (como la marca Edgar en la ficha de la obra)
    update facturas set pagada = true where id = (r1->>'factura_id')::bigint;
    c := pg_temp.c11_ctl(64);
    v_obt := format('%s | cobrada entera en el libro y sin marcar en la obra: %s | marcada como cobrada en la obra: %s', coalesce(a, '(no está)'), b, coalesce(c, '(no está)'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (50, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 51. SOLO SE FACTURA UN HITO PENDIENTE (la revisión final del 12-nov). Un
--     hito que la ficha ya tiene como «facturado» y que aquí no tiene
--     ninguna factura viva —se facturó en QuickBooks a mano y su factura
--     está en la app SIN su hito (en producción las hay)— no se factura
--     otra vez: la lista de hitos de la obra no lo ofrece (ni lo cuenta por
--     facturar), su borrador no se abre (MX008, con qué hacer), y uno que
--     ya estuviera abierto lo dice y no se emite. Puesto otra vez en
--     pendiente, se factura. Con la capa de antes salía con su botón de
--     facturar, sin un solo aviso, y se emitía: el ingreso del hito, dos
--     veces (la app publicada solo deja facturar un hito pendiente).
do $$
declare
  v_obt text; v_o record; v_x text; v_y text; v_b jsonb; v_doc uuid; v_d jsonb; r jsonb;
  a text; b text; c text; d text;
  v_nom text := 'SOLO SE FACTURA UN HITO PENDIENTE: el que la ficha ya tiene como facturado y aquí no tiene factura (se facturó fuera de la '
                'app, su factura está sin su hito) no se ofrece en la lista de la obra ni cuenta por facturar, su borrador no se abre '
                '(MX008, con qué hacer) y uno que ya estaba abierto lo dice y no se emite; puesto otra vez en pendiente, se factura';
  v_esp text := 'el hito que la ficha tiene como facturado, con su factura de fuera sin su hito: la lista de la obra no lo ofrece y cuenta '
                '1 hito por facturar (3333.34) | su borrador no se abre: MX008 (ya está marcado como facturado; ponlo antes en '
                'pendiente) | un borrador que ya estaba abierto cuando la ficha lo marcó: lo frena (hito_marcado_facturado), no se '
                'ofrece y emitirlo da MX008 | puesto otra vez en pendiente: se emite con su asiento y queda facturado con su factura';
begin
  if pg_temp.c11_omitir(51, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- el hito 1 de la obra Uno se facturó en QuickBooks a mano: la ficha lo tiene como facturado y su factura está en la app SIN su hito
    update hitos set estado = 'facturado' where id = -1110000001;
    insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
    values ('c11-prueba-a', 'ZZ-951', pg_temp.c11('hoy')::date, 3333.33, null, 'emitida');
    -- un borrador del hito 2, abierto mientras estaba pendiente; después la ficha lo marca facturado
    v_b := pg_temp.c11_borrador('{"forma": "hito", "hito_id": -1110000002}');
    v_doc := (v_b->'documento'->>'id')::uuid;
    update hitos set estado = 'facturado' where id = -1110000002;
    -- (a) la lista de hitos de la obra
    perform pg_temp.c11_ser('dueno');
    select o.hitos, o.hitos_pendientes, o.hitos_pendientes_monto into v_o from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('editor');
    a := case when v_o.hitos->0->>'estado' = 'facturado' and v_o.hitos->0->>'factura' is null and not (v_o.hitos->0->>'puede')::boolean
                   and not (v_o.hitos->1->>'puede')::boolean and (v_o.hitos->2->>'puede')::boolean
              then 'no lo ofrece' else 'LO OFRECE: ' || (v_o.hitos->0)::text end
         || format(' y cuenta %s hito por facturar (%s)', v_o.hitos_pendientes, v_o.hitos_pendientes_monto);
    -- (b) su borrador no se abre
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001}') $q$);
    b := case when v_x like 'MX008: El hito «C11 PRUEBA Milestone 1» ya está marcado como facturado en la ficha de la obra y aquí no hay '
                            'ninguna factura suya%no se factura otra vez. Si de verdad falta facturarlo, ponlo antes en pendiente (la '
                            'ficha no tiene botón para eso: avisa y se hace).'
              then 'MX008 (ya está marcado como facturado; ponlo antes en pendiente)' else v_x end;
    -- (c) el borrador que ya estaba abierto
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento(v_doc);
    perform pg_temp.c11_ser('editor');
    v_y := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc, v_d->>'visto'));
    c := case when exists (select 1 from jsonb_array_elements(v_d->'avisos') x
                            where x->>'codigo' = 'hito_marcado_facturado' and (x->>'frena')::boolean
                              and x->>'texto' like 'El hito «C11 PRUEBA Milestone 2» ya está marcado como facturado en la ficha de la obra%')
              then 'lo frena (hito_marcado_facturado)'
              else 'NO lo frena: ' || coalesce((select string_agg(x->>'codigo', ', ') from jsonb_array_elements(v_d->'avisos') x), '(sin avisos)') end
         || case when not (v_d->>'puede_emitir')::boolean then ', no se ofrece' else ', SE OFRECE emitir' end
         || case when v_y like 'MX008: El hito «C11 PRUEBA Milestone 2» ya está marcado como facturado en la ficha de la obra%' then ' y emitirlo da MX008'
                 else ' y emitirlo: ' || v_y end;
    -- (d) puesto otra vez en pendiente, se factura
    update hitos set estado = 'pendiente' where id = -1110000002;
    r := pg_temp.c11_emitir(v_doc);
    perform pg_temp.c11_ser('dueno');
    select o.hitos into v_o.hitos from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('editor');
    d := case when r->>'estado' = 'emitida' and r->>'asiento' is not null and r->>'hito_estado' = 'facturado'
                   and v_o.hitos->1->>'factura' = r->>'numero' and not (v_o.hitos->1->>'puede')::boolean
              then 'se emite con su asiento y queda facturado con su factura' else 'NO: ' || r::text end;
    v_obt := format('el hito que la ficha tiene como facturado, con su factura de fuera sin su hito: la lista de la obra %s | su borrador no se '
                    'abre: %s | un borrador que ya estaba abierto cuando la ficha lo marcó: %s | puesto otra vez en pendiente: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (51, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LO QUE FALLÓ EN PRODUCCIÓN (12-nov-2026). La base de la app admite UNA
-- sola fila de facturas por hito, también contando las anuladas (el índice
-- único ux_facturas_hito; es de la app, de la otra sesión): con la capa de
-- antes, después de anular la factura de un hito no entraba la buena (23505
-- en la 20 y en la 43 de entonces). Cada cosa con su prueba: con una emisión
-- que no suelte la anulada (la de antes), en una base con ese índice, la
-- 20, la 43, la 52 y la 53 fallan, y sin la red, la 54 (se comprobó
-- quitándole a la capa de ahora el soltado y la red); con la de ahora,
-- pasan. Corren con el índice que la base tenga, sin poner ni quitar
-- ninguno (un índice nuevo para toda escritura en facturas mientras se
-- crea y hasta que la prueba se deshace: eso no se le hace a la app): en
-- el banco con pruebas/conta/06-produccion-facturas.sql y en producción,
-- con el que falló; sin él prueban lo mismo —la capa suelta siempre— y
-- cada una dice con qué corrió.
-- ---------------------------------------------------------------------
-- 52. VOLVER A FACTURAR UN HITO CUYA FACTURA SE ANULÓ. La anulada conserva
--     su hito hasta que entra la que la sustituye; el borrador de la buena
--     lo dice con un aviso que NO frena; al emitirla, la anulada SUELTA el
--     hito (facturas.hito_id a nulo) y en lo demás no cambia: sigue anulada,
--     con su nota de crédito, su asiento y lo cobrado como estaban, y su
--     puente no asienta nada; queda apuntado en emision_soltados (qué
--     factura, de qué hito, por qué documento, quién); quien lea facturas
--     por su hito ve una sola fila, la viva; y otra vuelta (anular y
--     facturar otra vez) hace lo mismo. Ningún control se enciende: tampoco
--     el aviso de «una factura de hito que ya no apunta a su hito». Y
--     SOLTAR POR SÍ SOLO (el mismo cambio en la anulada, sin emitir nada,
--     dentro de un bloque que se deshace) no mueve ningún control: ni de la
--     facturación, ni de c2, c3, c4, c6, p1, c8, c9 y c10, ni del WIP (c12).
do $$
declare
  v_obt text; s0 text[]; r1 jsonb; r2 jsonb; r3 jsonb; ra jsonb; ra2 jsonb; v_b jsonb; v_b3 jsonb;
  v_f1 bigint; v_f2 bigint; v_f3 bigint; v_d2 uuid; e1 text; e2 text; e3 text; v_nc text; v_nc2 text; v_x text; v_42 text; v_peg text;
  j0 jsonb; j1 jsonb; pd0 jsonb; v_as0 bigint; v_asf0 bigint; v_sol0 bigint; v_k bigint; v_k2 bigint; x record; v_av jsonb;
  c0 text[]; p0 text; w0 text; v_solo text;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text;
  v_hu text := pg_temp.c11_candado_hito();
  v_nom text := pg_temp.c11_con_que_indice('VOLVER A FACTURAR UN HITO CUYA FACTURA SE ANULÓ')
                || ': el borrador de la buena lo avisa sin frenar; al emitirla, la anulada suelta el hito y en lo demás '
                'no cambia (sigue anulada, con su nota de crédito y su asiento; su puente no asienta nada); queda apuntado qué factura '
                'soltó qué hito y por qué documento; y ningún control se enciende';
  v_esp text := 'la base: una sola fila de facturas por hito, contando las anuladas | anulada la primera: sigue apuntando a su hito y el '
                'hito vuelve a pendiente | soltar el hito de la anulada, por sí solo (sin emitir): la facturación igual, las otras capas '
                'igual, el WIP (c12, si está) igual, y el libro igual | el borrador de la buena: avisa sin frenar (hito_factura_anulada: '
                'nombra la anulada y su nota de crédito) y se puede emitir | al emitirla: sale con el número siguiente, con su asiento, el hito facturado, y dice lo que '
                'soltó; otra vez el mismo borrador MX008 | la anulada: soltó el hito y en lo demás no cambió (sigue anulada, con su nota de '
                'crédito, su asiento y lo cobrado como estaban; su puente no asentó nada: el libro solo ganó el asiento de la nueva) | la '
                'nueva lleva el hito: cxc 3333.33 | ingreso -3333.33 | lo soltado: apuntado (la factura, su número, su nota, el hito, la '
                'obra, que salió de la app, el documento que la soltó y quién); el equipo ve 0 y el dueño 1 | quien lea facturas por su '
                'hito (la función de QuickBooks): una sola fila, la viva | anulada y facturada otra vez: número siguiente, suelta la '
                'segunda (el aviso nombra solo a esa) y quedan 2 apuntes | los controles: de la facturación, nada nuevo (el de «factura de '
                'hito que ya no apunta a su hito» no nombra a ninguna); de las otras capas, ninguno | el pegado lo dice: una sola fila por '
                'hito contando las anuladas, y 2 soltadas más';
begin
  -- (lo que se espera de «la base» y de lo que dice el pegado, según el índice único de facturas por hito que tenga)
  if v_hu = 'vivas' then
    v_esp := replace(v_esp, 'la base: una sola fila de facturas por hito, contando las anuladas |',
                            'la base: no deja dos facturas vivas del mismo hito y no cuenta las anuladas |');
    v_esp := replace(v_esp, 'el pegado lo dice: una sola fila por hito contando las anuladas, y 2 soltadas más',
                            'el pegado lo dice: no deja dos vivas del mismo hito y no cuenta las anuladas, y 2 soltadas más');
  elsif v_hu = 'ninguno' then
    v_esp := replace(v_esp, 'la base: una sola fila de facturas por hito, contando las anuladas |',
                            'la base: sin índice único de facturas por hito |');
    v_esp := replace(v_esp, 'el pegado lo dice: una sola fila por hito contando las anuladas, y 2 soltadas más',
                            'el pegado lo dice: sin índice único de facturas por hito, y 2 soltadas más');
  end if;
  if pg_temp.c11_omitir(52, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    a := case v_hu when 'todas' then 'una sola fila de facturas por hito, contando las anuladas'
                   when 'vivas' then 'no deja dos facturas vivas del mismo hito y no cuenta las anuladas'
                   else 'sin índice único de facturas por hito' end;
    s0 := pg_temp.c11_rojos();
    select count(*) into v_sol0 from emision_soltados;
    e1 := pg_temp.c11_num(1); e2 := pg_temp.c11_num(2); e3 := pg_temp.c11_num(3);
    -- (1) emitida y anulada: la anulada conserva su hito
    r1 := pg_temp.c11_hito(-1110000001);
    v_f1 := (r1->>'factura_id')::bigint;
    ra := pg_temp.c11_anular((r1->>'documento')::uuid, 'c11-pruebas: monto equivocado');
    v_nc := ra->>'nota_credito';
    b := case when (select f.estado = 'anulada' and f.hito_id = -1110000001 from facturas f where f.id = v_f1) then 'sigue apuntando a su hito'
              else 'YA NO apunta a su hito' end
         || format(' y el hito vuelve a %s', (select hh.estado from hitos hh where hh.id = -1110000001));
    -- (1b) SOLTAR POR SÍ SOLO: el mismo cambio que hará la emisión en la anulada (su hito a nulo), sin emitir nada, y su puente
    --      corrido ya. Ningún control se mueve, y el libro no gana nada. Se deshace.
    begin
      c0 := pg_temp.c11_rojos();
      select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'ninguno') into p0 from v_emision_control k where not k.ok;
      w0 := pg_temp.c11_wip_rojos();
      select count(*) into v_as0 from asientos;
      update facturas set hito_id = null where id = v_f1;
      set constraints public.trg_puente_facturas_despues immediate;
      set constraints public.trg_puente_facturas_despues deferred;
      v_solo := format('la facturación %s, las otras capas %s, el WIP (c12, si está) %s, y el libro %s',
                       case when (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'ninguno') from v_emision_control k where not k.ok) = p0
                            then 'igual' else 'CAMBIÓ' end,
                       case when pg_temp.c11_nuevos(c0, pg_temp.c11_rojos()) = 'ninguno' and pg_temp.c11_nuevos(pg_temp.c11_rojos(), c0) = 'ninguno'
                            then 'igual' else 'CAMBIARON: ' || pg_temp.c11_nuevos(c0, pg_temp.c11_rojos()) end,
                       case when pg_temp.c11_wip_rojos() = w0 then 'igual' else format('CAMBIÓ (%s → %s)', w0, pg_temp.c11_wip_rojos()) end,
                       case when (select count(*) from asientos) = v_as0 then 'igual' else 'GANÓ asientos' end);
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- (2) el borrador de la buena: lo dice, y no frena
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    v_d2 := (v_b->'documento'->>'id')::uuid;
    select y.value into v_av from jsonb_array_elements(v_b->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    c := case when v_av is null then 'NO avisa: ' || left((v_b->'avisos')::text, 300)
              when (v_av->>'frena')::boolean then 'avisa y FRENA'
              when v_av->>'texto' like 'El hito «C11 PRUEBA Milestone 1» ya tuvo una factura que se anuló: ' || e1 || ' del % (nota de crédito '
                                       || v_nc || '). Esta la sustituye: al emitirla, la anulada deja de figurar como la factura de este hito (en '
                                       || 'lo demás no cambia: sigue anulada) y queda apuntado.'
                then 'avisa sin frenar (hito_factura_anulada: nombra la anulada y su nota de crédito)'
              else 'avisa con otro texto: ' || (v_av->>'texto') end
         || case when (v_b->>'puede_emitir')::boolean and (v_b->>'nuevo')::boolean then ' y se puede emitir' else ' y NO se puede emitir' end;
    -- (3) lo de la anulada y lo del libro, justo antes
    select to_jsonb(ff) - 'hito_id' into j0 from facturas ff where ff.id = v_f1;
    select to_jsonb(pd) into pd0 from puente_documentos pd where pd.tabla = 'facturas' and pd.documento_id = v_f1::text;
    select count(*) into v_as0 from asientos;
    select count(*) into v_asf0 from asientos z where z.origen_tabla = 'facturas' and z.origen_id = v_f1::text;
    -- (4) se emite
    r2 := pg_temp.c11_emitir(v_d2);
    v_f2 := (r2->>'factura_id')::bigint;
    d := case when r2->>'estado' = 'emitida' and r2->>'numero' = e2 and r2->>'asiento' is not null and r2->>'hito_estado' = 'facturado'
              then 'sale con el número siguiente, con su asiento, el hito facturado' else 'MAL: ' || r2::text end
         || case when r2->'soltadas' = jsonb_build_array(jsonb_build_object('factura_id', v_f1, 'numero', e1, 'nota_credito', v_nc, 'de_la_app', true))
                 then ', y dice lo que soltó' else ', y de lo soltado dice ' || coalesce((r2->'soltadas')::text, 'nada') end
         || '; otra vez el mismo borrador ' || pg_temp.c11_cod(format('select fn_emision_emitir(%L, %L)', v_d2, v_b->>'visto'));
    -- (5) la anulada: soltó el hito y nada más
    select to_jsonb(ff) - 'hito_id' into j1 from facturas ff where ff.id = v_f1;
    e := case when (select ff.hito_id is null and ff.estado = 'anulada' from facturas ff where ff.id = v_f1) then 'soltó el hito'
              else 'NO soltó el hito' end
         || case when j1 = j0 and (select count(*) from notas_credito n where n.anula_a = v_f1 and n.numero = v_nc) = 1
                      and (select count(*) from asientos z where z.origen_tabla = 'facturas' and z.origen_id = v_f1::text) = v_asf0
                      and (select sx.cxc = 0 and sx.retencion = 0 from fn_emision_saldo(v_f1) sx)
                 then ' y en lo demás no cambió (sigue anulada, con su nota de crédito, su asiento y lo cobrado como estaban;'
                 else format(' y CAMBIÓ algo más (antes %s; ahora %s);', j0, j1) end
         || case when (select to_jsonb(pd) from puente_documentos pd where pd.tabla = 'facturas' and pd.documento_id = v_f1::text) = pd0
                      and (select count(*) from asientos) = v_as0 + 1
                 then ' su puente no asentó nada: el libro solo ganó el asiento de la nueva)'
                 else format(' su puente SE MOVIÓ, o el libro ganó %s asientos)', (select count(*) from asientos) - v_as0) end;
    f := case when (select ff.hito_id = -1110000001 and ff.estado = 'emitida' from facturas ff where ff.id = v_f2) then pg_temp.c11_asiento(v_f2)
              else 'la nueva NO lleva el hito' end;
    -- (6) lo soltado, apuntado; el equipo no lo ve
    select count(*) into v_k from emision_soltados so where so.documento_id = v_d2;
    select * into x from emision_soltados so where so.documento_id = v_d2 limit 1;
    g := case when v_k = 1 and x.factura_id = v_f1 and x.num = e1 and x.nota_credito = v_nc and x.hito_id = -1110000001
                   and x.proyecto_id = 'c11-prueba-a' and x.de_la_app and x.soltado_por = pg_temp.c11('dueno')::uuid and x.soltado_el is not null
              then 'apuntado (la factura, su número, su nota, el hito, la obra, que salió de la app, el documento que la soltó y quién)'
              else format('MAL (%s filas): %s', v_k, to_jsonb(x)) end;
    perform pg_temp.c11_ser('p1');
    select count(*) into v_k from emision_soltados;
    perform pg_temp.c11_ser('dueno');
    select count(*) into v_k2 from emision_soltados so where so.documento_id = v_d2;
    perform pg_temp.c11_ser('editor');
    g := g || format('; el equipo ve %s y el dueño %s', v_k, v_k2);
    -- (7) quien lea facturas por su hito, sin mirar el estado
    select format('%s, %s', case count(*) when 1 then 'una sola fila' else count(*) || ' filas' end,
                  case when bool_and(ff.estado = 'emitida') then 'la viva' else 'y alguna NO está viva' end)
      into h from facturas ff where ff.hito_id = -1110000001;
    -- (8) otra vuelta: se anula la buena y se factura otra vez
    ra2 := pg_temp.c11_anular(v_d2, 'c11-pruebas: otra vez');
    v_nc2 := ra2->>'nota_credito';
    v_b3 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    select y.value into v_av from jsonb_array_elements(v_b3->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    r3 := pg_temp.c11_emitir((v_b3->'documento'->>'id')::uuid);
    v_f3 := (r3->>'factura_id')::bigint;
    select count(*) into v_k from emision_soltados;
    i := case when r3->>'numero' = e3 and r3->>'estado' = 'emitida' then 'número siguiente' else 'MAL: ' || r3::text end
         || case when r3->'soltadas' = jsonb_build_array(jsonb_build_object('factura_id', v_f2, 'numero', e2, 'nota_credito', v_nc2, 'de_la_app', true))
                      and (select count(*) from facturas ff where ff.id in (v_f1, v_f2) and ff.hito_id is null and ff.estado = 'anulada') = 2
                      and (select ff.hito_id from facturas ff where ff.id = v_f3) = -1110000001
                 then ', suelta la segunda' else ', NO suelta la segunda: ' || coalesce((r3->'soltadas')::text, 'nada') end
         || case when v_av->>'texto' like '%ya tuvo una factura que se anuló: ' || e2 || ' del %' and position(e1 in v_av->>'texto') = 0
                 then ' (el aviso nombra solo a esa)' else ' (el aviso: ' || coalesce(v_av->>'texto', 'no hay') || ')' end
         || format(' y quedan %s apuntes', v_k - v_sol0);
    -- (9) los controles
    v_42 := pg_temp.c11_ctl(42);
    j := format('de la facturación, %s (el de «factura de hito que ya no apunta a su hito» %s); de las otras capas, %s',
                pg_temp.c11_propios(),
                case when position(e1 in v_42) = 0 and position(e2 in v_42) = 0 and position(e3 in v_42) = 0 then 'no nombra a ninguna'
                     else 'NOMBRA a alguna: ' || left(v_42, 300) end,
                pg_temp.c11_nuevos(s0, pg_temp.c11_rojos()));
    -- (10) el pegado lo dice
    select p.detalle into v_peg from fn_emision_pegado() p where p.que = 'volver a facturar un hito';
    v_x := case when v_peg like 'esta base admite UNA sola fila de facturas por hito, contando las anuladas (%' then 'una sola fila por hito contando las anuladas'
                when v_peg like 'esta base no deja dos facturas vivas del mismo hito (%' then 'no deja dos vivas del mismo hito y no cuenta las anuladas'
                when v_peg like 'esta base no tiene un índice único de facturas por hito (%' then 'sin índice único de facturas por hito'
                else 'otra cosa: ' || coalesce(left(v_peg, 200), '(sin esa fila)') end
           || case when v_peg like '%· soltadas hasta hoy: ' || (v_sol0 + 2) then ', y 2 soltadas más' else ', y NO cuenta las dos soltadas' end;
    v_obt := format('la base: %s | anulada la primera: %s | soltar el hito de la anulada, por sí solo (sin emitir): %s | el borrador de la '
                    'buena: %s | al emitirla: %s | la anulada: %s | la nueva lleva el hito: %s | lo soltado: %s | quien lea facturas por su '
                    'hito (la función de QuickBooks): %s | anulada y facturada otra vez: %s | los controles: %s | el pegado lo dice: %s',
                    a, b, v_solo, c, d, e, f, g, h, i, j, v_x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (52, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 53. UNA FACTURA DE QUICKBOOKS ANULADA EN CONTABILIDAD, Y SU HITO FACTURADO
--     POR LA APP. La fila de facturas como la deja la función de QuickBooks
--     (su número, su hito, su id de QuickBooks; el hito a «facturado») entra
--     al libro por su puente; se anula desde Contabilidad (por c3, sin pasar
--     por la facturación): queda anulada con su nota de crédito, apuntando a
--     su hito, y la ficha sigue con el hito «facturado». Aquí: la lista de
--     la obra no lo ofrece y su borrador no se abre hasta que vuelva a
--     pendiente (solo se factura un hito pendiente), y lo dice nombrando la
--     anulada (la 56 lo mira a fondo). La ficha no tiene botón para eso: es
--     el segundo paso de la consulta con que se anula una de QuickBooks, y
--     aquí lo hace la prueba. Entonces el borrador lo
--     avisa sin frenar, y al emitir la de QuickBooks suelta el hito —sigue
--     anulada, con su nota, su asiento y su id de QuickBooks— y queda
--     apuntado como «de fuera de la app». Y UNA QUE NUNCA ENTRÓ AL LIBRO
--     (esperaba en la bandeja de los puentes: es a un contratista y no dice
--     su retención) y se anuló sin nota de crédito: también suelta su hito,
--     queda apuntada sin nota y su puente sigue donde estaba. Ningún control
--     se enciende.
do $$
declare
  v_obt text; s0 text[]; v_fq bigint; v_nc text; v_h jsonb; v_x text; v_b jsonb; v_av jsonb; r jsonb; x record; v_k bigint;
  j0 jsonb; j1 jsonb; v_asf0 bigint; v_as0 bigint; e1 text; v_fq2 bigint; v_ra jsonb; r2 jsonb; pd0 jsonb; v_b2 jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text;
  v_nom text := pg_temp.c11_con_que_indice('UNA FACTURA DE QUICKBOOKS ANULADA EN CONTABILIDAD (por c3) Y SU HITO FACTURADO POR LA APP')
                || ': la anulada conserva su hito; devuelto el hito a pendiente, el borrador lo avisa sin frenar y, al emitir, la '
                'de QuickBooks suelta el hito (sigue anulada, con su nota de crédito, su asiento y su id de QuickBooks) y queda apuntada '
                'como de fuera de la app; ningún control se enciende';
  v_esp text := 'como la deja QuickBooks, entra al libro por su puente: cxc 3333.33 | ingreso -3333.33 | anulada en Contabilidad: con su '
                'nota de crédito; sigue apuntando a su hito y la ficha lo tiene como facturado | aquí: la lista de la obra no lo ofrece y '
                'su borrador no se abre (MX008: dice que su factura de QuickBooks está anulada, con su nota, y que el hito tiene que '
                'volver antes a pendiente) | puesto en pendiente: el borrador avisa sin frenar (nombra la '
                'de QuickBooks y su nota de crédito) y se puede emitir | emitida por la app: con su número de la serie, su asiento y el '
                'hito facturado, y dice lo que soltó | la de QuickBooks: soltó el hito y en lo demás no cambió (sigue anulada, con su nota '
                'de crédito, su asiento y su id de QuickBooks; el libro solo ganó el asiento de la nueva) | lo soltado: apuntado como de '
                'fuera de la app, con su número y su nota | quien lea facturas por su hito: una sola fila, la viva | una de fuera que '
                'nunca entró al libro, anulada sin nota de crédito: el borrador la nombra (sin nota), al emitir suelta su hito, queda '
                'apuntada sin nota y su puente sigue donde estaba | los controles: de la facturación, nada nuevo; de las otras capas, '
                'ninguno';
begin
  if pg_temp.c11_omitir(53, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    s0 := pg_temp.c11_rojos();
    e1 := pg_temp.c11_num(1);
    -- (1) como la deja la función de QuickBooks: la fila de facturas con su hito y su id de QuickBooks, y el hito a facturado
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5301', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5301')
    returning id into v_fq;
    update hitos set estado = 'facturado' where id = -1110000002;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    a := pg_temp.c11_asiento(v_fq);
    -- (2) se anula desde Contabilidad (c3 directo)
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_fq, 'c11-pruebas: se anula en Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    select n.numero into v_nc from notas_credito n where n.anula_a = v_fq;
    b := case when v_nc ~ '^NC-[0-9]{4}-[0-9]{4}$' and (select ff.estado from facturas ff where ff.id = v_fq) = 'anulada' then 'con su nota de crédito'
              else 'SIN su nota de crédito' end
         || case when (select ff.hito_id from facturas ff where ff.id = v_fq) = -1110000002 then '; sigue apuntando a su hito' else '; YA NO apunta a su hito' end
         || format(' y la ficha lo tiene como %s', (select hh.estado from hitos hh where hh.id = -1110000002));
    -- (3) aquí, mientras la ficha lo tenga como facturado: ni se ofrece ni se abre
    perform pg_temp.c11_ser('dueno');
    select o.hitos->1 into v_h from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('editor');
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000002}') $q$);
    c := case when (v_h->>'id')::bigint = -1110000002 and not (v_h->>'puede')::boolean and v_h->>'factura' is null then 'la lista de la obra no lo ofrece'
              else 'la lista de la obra: ' || v_h::text end
         || case when v_x like 'MX008: El hito «C11 PRUEBA Milestone 2» sigue marcado como facturado en la ficha de la obra y su factura '
                                 'ZZ-QB-5301 del % (nota de crédito ' || v_nc || ') está anulada: hoy no tiene ninguna factura viva.%el hito '
                                 'tiene que volver antes a pendiente (la ficha no tiene botón para eso: avisa y se hace).'
                 then ' y su borrador no se abre (MX008: dice que su factura de QuickBooks está anulada, con su nota, y que el hito tiene '
                      'que volver antes a pendiente)' else ' y su borrador: ' || v_x end;
    -- (4) el hito vuelve a pendiente (la ficha no tiene botón para eso: es el segundo paso de la consulta con que se anula
    --     una de QuickBooks): el borrador lo avisa, y no frena
    update hitos set estado = 'pendiente' where id = -1110000002;
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    select y.value into v_av from jsonb_array_elements(v_b->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    d := case when v_av is null then 'el borrador NO avisa: ' || left((v_b->'avisos')::text, 300)
              when (v_av->>'frena')::boolean then 'el borrador avisa y FRENA'
              when v_av->>'texto' like 'El hito «C11 PRUEBA Milestone 2» ya tuvo una factura que se anuló: ZZ-QB-5301 del % (nota de crédito '
                                       || v_nc || '). Esta la sustituye:%'
                then 'el borrador avisa sin frenar (nombra la de QuickBooks y su nota de crédito)'
              else 'el borrador avisa con otro texto: ' || (v_av->>'texto') end
         || case when (v_b->>'puede_emitir')::boolean then ' y se puede emitir' else ' y NO se puede emitir' end;
    -- (5) se emite
    select to_jsonb(ff) - 'hito_id' into j0 from facturas ff where ff.id = v_fq;
    select count(*) into v_asf0 from asientos z where z.origen_tabla = 'facturas' and z.origen_id = v_fq::text;
    select count(*) into v_as0 from asientos;
    r := pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    e := case when r->>'estado' = 'emitida' and r->>'numero' = e1 and r->>'asiento' is not null and r->>'hito_estado' = 'facturado'
                   and (select ff.hito_id from facturas ff where ff.id = (r->>'factura_id')::bigint) = -1110000002
              then 'con su número de la serie, su asiento y el hito facturado' else 'MAL: ' || r::text end
         || case when r->'soltadas' = jsonb_build_array(jsonb_build_object('factura_id', v_fq, 'numero', 'ZZ-QB-5301', 'nota_credito', v_nc, 'de_la_app', false))
                 then ', y dice lo que soltó' else ', y de lo soltado dice ' || coalesce((r->'soltadas')::text, 'nada') end;
    -- (6) la de QuickBooks: soltó el hito y nada más
    select to_jsonb(ff) - 'hito_id' into j1 from facturas ff where ff.id = v_fq;
    f := case when (select ff.hito_id is null and ff.estado = 'anulada' and ff.qb_id = 'ZZ-QBID-5301' from facturas ff where ff.id = v_fq)
              then 'soltó el hito' else 'NO soltó el hito' end
         || case when j1 = j0 and (select count(*) from notas_credito n where n.anula_a = v_fq and n.numero = v_nc) = 1
                      and (select count(*) from asientos z where z.origen_tabla = 'facturas' and z.origen_id = v_fq::text) = v_asf0
                      and (select count(*) from asientos) = v_as0 + 1
                 then ' y en lo demás no cambió (sigue anulada, con su nota de crédito, su asiento y su id de QuickBooks; el libro solo ganó '
                      'el asiento de la nueva)'
                 else format(' y CAMBIÓ algo más (antes %s; ahora %s; asientos de más: %s)', j0, j1, (select count(*) from asientos) - v_as0 - 1) end;
    -- (7) lo soltado
    select count(*) into v_k from emision_soltados so where so.documento_id = (r->>'documento')::uuid;
    select * into x from emision_soltados so where so.documento_id = (r->>'documento')::uuid limit 1;
    g := case when v_k = 1 and x.factura_id = v_fq and x.num = 'ZZ-QB-5301' and x.nota_credito = v_nc and x.hito_id = -1110000002
                   and not x.de_la_app and x.proyecto_id = 'c11-prueba-a' and x.soltado_por = pg_temp.c11('dueno')::uuid
              then 'apuntado como de fuera de la app, con su número y su nota' else format('MAL (%s filas): %s', v_k, to_jsonb(x)) end;
    select format('%s, %s', case count(*) when 1 then 'una sola fila' else count(*) || ' filas' end,
                  case when bool_and(ff.estado = 'emitida') then 'la viva' else 'y alguna NO está viva' end)
      into h from facturas ff where ff.hito_id = -1110000002;
    -- (8) una de fuera que NUNCA entró al libro: a un contratista y sin decir su retención, espera en la bandeja de los puentes;
    --     anulada desde Contabilidad queda sin nota de crédito (no hay asiento que compensar)
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id, a_contratista)
    values ('c11-prueba-a', 'ZZ-QB-5302', pg_temp.c11('hoy')::date, 3333.34, false, -1110000003, 'ZZ-QBID-5302', true)
    returning id into v_fq2;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    perform pg_temp.c11_ser('dueno');
    v_ra := fn_factura_anular(v_fq2, 'c11-pruebas: nunca entró al libro', null);
    perform pg_temp.c11_ser('editor');
    select to_jsonb(pd) into pd0 from puente_documentos pd where pd.tabla = 'facturas' and pd.documento_id = v_fq2::text;
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003));
    select y.value into v_av from jsonb_array_elements(v_b2->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    r2 := pg_temp.c11_emitir((v_b2->'documento'->>'id')::uuid);
    select * into x from emision_soltados so where so.documento_id = (r2->>'documento')::uuid limit 1;
    k := case when (select ff.contabilizado_en is null and ff.estado = 'anulada' from facturas ff where ff.id = v_fq2)
                   and v_ra->>'nota_credito' is null and not exists (select 1 from notas_credito n where n.anula_a = v_fq2)
              then '' else 'NO es el caso (entró al libro o tiene nota): ' end
         || case when not (v_av->>'frena')::boolean and v_av->>'texto' like '%ya tuvo una factura que se anuló: ZZ-QB-5302 del %. Esta la sustituye:%'
                      and position('nota de crédito' in v_av->>'texto') = 0
                 then 'el borrador la nombra (sin nota)' else 'el borrador: ' || coalesce(v_av->>'texto', 'no avisa') end
         || case when r2->>'estado' = 'emitida' and (select ff.hito_id is null and ff.estado = 'anulada' from facturas ff where ff.id = v_fq2)
                      and r2->'soltadas' = jsonb_build_array(jsonb_build_object('factura_id', v_fq2, 'numero', 'ZZ-QB-5302', 'de_la_app', false))
                 then ', al emitir suelta su hito' else ', al emitir NO suelta su hito: ' || coalesce(r2::text, '') end
         || case when x.factura_id = v_fq2 and x.nota_credito is null and not x.de_la_app then ', queda apuntada sin nota'
                 else ', el apunte: ' || coalesce(to_jsonb(x)::text, 'no hay') end
         || case when (select to_jsonb(pd) from puente_documentos pd where pd.tabla = 'facturas' and pd.documento_id = v_fq2::text) = pd0
                      and not exists (select 1 from asientos z where z.origen_tabla = 'facturas' and z.origen_id = v_fq2::text)
                 then ' y su puente sigue donde estaba' else ' y su puente SE MOVIÓ' end;
    i := format('de la facturación, %s; de las otras capas, %s', pg_temp.c11_propios(), pg_temp.c11_nuevos(s0, pg_temp.c11_rojos()));
    v_obt := format('como la deja QuickBooks, entra al libro por su puente: %s | anulada en Contabilidad: %s | aquí: %s | puesto en pendiente: '
                    '%s | emitida por la app: %s | la de QuickBooks: %s | lo soltado: %s | quien lea facturas por su hito: %s | una de '
                    'fuera que nunca entró al libro, anulada sin nota de crédito: %s | los controles: %s', a, b, c, d, e, f, g, h, k, i);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (53, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 54. DOS A LA VEZ POR DOS CAMINOS: LA RED. Durante el paralelo la función
--     de QuickBooks puede facturar un hito en el mismo instante en que la
--     app lo emite. Lo normal es que la emisión ESPERE a la otra (la fila de
--     fuera sujeta su hito por la llave de facturas) y pare antes de
--     insertar: «ya no es lo que viste» (MX011) o «ya se facturó» (MX008);
--     eso lo prueba, con dos sesiones de verdad, c11-concurrencia.sh (4c).
--     Aquí se prueba LA RED que queda debajo: si aun así la fila de
--     facturas de la emisión choca con un índice único de la base (el del
--     hito o el del número), no sale el error del índice: se dice en llano
--     (MX011: entró por otro lado una factura de este mismo hito, o con ese
--     número) y no queda nada —ni el número—. QUÉ índice chocó va en el
--     DETALLE del error (la pantalla no lo enseña; queda en la respuesta de
--     la API y en el registro de la base): si un día la base tuviera otro
--     índice único que la emisión no cumple, ese MX011 saldría siempre, y
--     así se sabe cuál es. Se imita con un disparo de
--     prueba que mete la otra factura justo cuando la emisión toma su número
--     (después de mirar que el hito estaba libre). Y si la otra había
--     entrado ANTES de emitir, el borrador ya lo frena. (Dos emisiones del
--     mismo borrador desde dos pestañas, con una anulada que soltar: también
--     en c11-concurrencia.sh, 4b.) En una base SIN ningún índice único de
--     facturas por hito no hay choque que parar: ahí se comprueba que la
--     emisión para igual, por el sello (lo que se congela ya no es lo que
--     se vio: entró otra factura de la obra), y que tampoco queda nada.
do $$
declare
  v_obt text; v_b jsonb; v_doc uuid; v_n0 bigint; e1 text; v_x text; v_d jsonb; v_av jsonb; v_e jsonb;
  v_hu text := pg_temp.c11_candado_hito();
  a text; b text; c text;
  v_nom text := 'DOS A LA VEZ POR DOS CAMINOS (la app y QuickBooks), con el índice único de facturas por hito de la base, LA RED: si la '
                'fila de facturas de la emisión choca con un índice único porque entró por otro lado una factura de ese mismo hito, la '
                'emisión para en llano (MX011), sin el error del índice en el texto y con el índice en el detalle del error, sin gastar '
                'número y sin dejar nada; y si la otra ya había entrado, el borrador lo frena';
  v_esp text := 'mientras se emite entra por otro lado una factura del mismo hito: MX011 en llano (dice que entró otra del mismo hito y '
                'qué hacer; ni el índice ni «duplicate»), y el detalle del error dice qué índice la paró | no queda nada: el número sin '
                'gastar, el borrador en borrador, ninguna factura '
                'de ese hito y el hito pendiente | y si la otra ya había entrado antes: el borrador lo frena (hito_facturado: nombra la '
                'ZZ-QB-5401) y no se ofrece emitir';
begin
  if v_hu = 'ninguno' then
    -- (esta base no tiene ningún índice único de facturas por hito: no hay choque que parar. Lo que para a la emisión es su
    -- sello —lo que se congela ya no es lo que se vio: entró otra factura de la obra—, y eso es lo que se mira)
    v_nom := 'DOS A LA VEZ POR DOS CAMINOS (la app y QuickBooks) en una base SIN índice único de facturas por hito (producción lo tiene; '
             'ahí se prueba la red del índice): si a media emisión entra por otro lado una factura de ese mismo hito, la emisión para '
             'igual en llano (MX011: algo de la obra cambió mientras se emitía), sin gastar número y sin dejar nada; y si la otra ya '
             'había entrado, el borrador lo frena';
    v_esp := replace(v_esp, 'MX011 en llano (dice que entró otra del mismo hito y qué hacer; ni el índice ni «duplicate»), y el detalle '
                            'del error dice qué índice la paró |',
                            'MX011 en llano (la para el sello: algo de la obra cambió mientras se emitía) |');
  end if;
  if pg_temp.c11_omitir(54, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000003));
    v_doc := (v_b->'documento'->>'id')::uuid;
    v_n0 := pg_temp.c11_contador(); e1 := pg_temp.c11_num(1);
    -- (1) la otra factura entra a media emisión (un disparo de prueba en la serie: se deshace con este bloque)
    begin
      create function pg_temp.c11_otro_lado() returns trigger language plpgsql as $f$
      begin
        insert into public.facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
        values ('c11-prueba-a', 'ZZ-QB-5401', public.fn_fecha_miami(now()), 3333.34, false, -1110000003, 'ZZ-QBID-5401');
        return null;
      end $f$;
      create trigger zz_c11_prueba_otro_lado after insert on public.emision_serie
        for each row execute function pg_temp.c11_otro_lado();
      v_e := pg_temp.c11_err_det(format('select fn_emision_emitir(%L, %L)', v_doc, v_b->>'visto'));
      v_x := (v_e->>'codigo') || coalesce(': ' || (v_e->>'mensaje'), '');
      if v_hu = 'ninguno' then
        a := case when v_x like 'MX011: Algo de la obra cambió mientras se emitía (otra factura, un cobro, el contrato): no se emitió nada.%'
                  then 'MX011 en llano (la para el sello: algo de la obra cambió mientras se emitía)' else v_x end;
      else
        a := case when v_x like 'MX011: No se emitió nada (ni se gastó el número ' || e1 || '): mientras se emitía entró por otro lado una '
                                'factura de este mismo hito, o con ese número (¿se facturó a la vez en QuickBooks?). Vuelve a mirar el '
                                'borrador: si el hito ya quedó facturado, tíralo.'
                       and v_x !~* 'ux_|zz_c11|duplicate|unique|constraint'
                  then 'MX011 en llano (dice que entró otra del mismo hito y qué hacer; ni el índice ni «duplicate»)' else v_x end
             -- (el detalle, que la pantalla no enseña, nombra el índice de la base que la paró: uno de los únicos por hito)
             || case when exists (select 1 from unnest(pg_temp.c11_indices_hito()) i(n)
                                   where position('el índice único «' || i.n || '»' in v_e->>'detalle') > 0)
                     then ', y el detalle del error dice qué índice la paró'
                     else ', y el detalle del error NO dice qué índice: ' || coalesce(nullif(v_e->>'detalle', ''), '(vacío)') end;
      end if;
      b := format('el número %s, el borrador en %s, %s y el hito %s',
                  case when pg_temp.c11_contador() = v_n0 and not exists (select 1 from emision_serie se where se.documento_id = v_doc)
                       then 'sin gastar' else 'GASTADO' end,
                  (select dd.estado from emision_documentos dd where dd.id = v_doc),
                  case when not exists (select 1 from facturas ff where ff.hito_id = -1110000003) then 'ninguna factura de ese hito'
                       else 'QUEDÓ una factura de ese hito' end,
                  (select hh.estado from hitos hh where hh.id = -1110000003));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- (2) la otra ya había entrado antes de emitir: el borrador lo frena
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5401', pg_temp.c11('hoy')::date, 3333.34, false, -1110000003, 'ZZ-QBID-5401');
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento(v_doc);
    perform pg_temp.c11_ser('editor');
    select y.value into v_av from jsonb_array_elements(v_d->'avisos') y where y.value->>'codigo' = 'hito_facturado';
    c := case when (v_av->>'frena')::boolean and v_av->>'texto' like 'El hito «C11 PRUEBA Milestone 3» ya se facturó: factura ZZ-QB-5401 del %'
              then 'el borrador lo frena (hito_facturado: nombra la ZZ-QB-5401)' else 'el borrador: ' || left((v_d->'avisos')::text, 300) end
         || case when not (v_d->>'puede_emitir')::boolean then ' y no se ofrece emitir' else ' y SE OFRECE emitir' end;
    v_obt := format('mientras se emite entra por otro lado una factura del mismo hito: %s | no queda nada: %s | y si la otra ya había entrado '
                    'antes: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (54, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 55. DOS ANULADAS APUNTANDO AL MISMO HITO, Y UNA VIVA CON UNA ANULADA. Solo
--     puede darse en una base SIN el índice único de facturas por hito que
--     cuenta las anuladas (el banco
--     sin 06-produccion-facturas.sql; o producción, si un día la otra sesión
--     lo quita y deja el de las vivas): una factura de fuera de un hito se
--     anula, entra otra de fuera del mismo hito y también se anula. Al
--     facturarlo la app, el borrador nombra a las dos y la emisión suelta a
--     las dos (dos apuntes). Y EN MEDIO, con la segunda todavía VIVA y la
--     primera anulada apuntando las dos al hito, un borrador que ya estaba
--     abierto dice UNA sola cosa: que el hito ya se facturó (antes añadía
--     además «esta la sustituye», por la anulada: las dos cosas a la vez).
--     Con ese índice puesto el caso no se puede dar,
--     y eso es lo que se comprueba: con una anulada apuntando al hito, otra
--     fila de facturas de ese hito no entra.
do $$
declare
  v_obt text; v_f1 bigint; v_f2 bigint; v_n1 text; v_n2 text; v_b jsonb; v_av jsonb; r jsonb; v_k bigint; v_d jsonb;
  v_todas boolean := pg_temp.c11_candado_hito() = 'todas';
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'DOS ANULADAS APUNTANDO AL MISMO HITO, Y UNA VIVA CON UNA ANULADA (solo en una base sin el índice único de facturas por '
                'hito que cuenta las anuladas): con la viva, el borrador dice solo que ya se facturó; con las dos anuladas las nombra sin '
                'frenar, y al emitir las dos sueltan el hito y quedan dos apuntes';
  v_esp text := 'con la primera de fuera anulada apuntando al hito, un borrador abierto y otra de fuera, viva, del mismo hito: el borrador '
                'dice solo que ya se facturó (nombra la viva y frena; no añade «esta la sustituye») | anulada también la segunda: las dos '
                'apuntan al hito | el borrador: las nombra a las dos, sin '
                'frenar, y se puede emitir | al emitir: suelta las dos y dice cuáles; quedan 2 apuntes | una sola fila de facturas con '
                'ese hito, la viva | los controles de la facturación: nada nuevo';
begin
  if v_todas then
    -- (esta base tiene el índice que cuenta también las anuladas: el caso no se puede dar, y eso es lo que se mira)
    v_nom := v_nom || ' (en esta base, con el índice único de facturas por hito que cuenta también las anuladas, el caso no se puede '
                      'dar: se comprueba que, con una anulada apuntando al hito, otra fila de ese hito no entra)';
    v_esp := 'con una de fuera anulada apuntando al hito, otra fila de facturas de ese hito: no entra (23505), y sigue habiendo una sola '
             'fila con ese hito';
  end if;
  if pg_temp.c11_omitir(55, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- (como las dejaría la función de QuickBooks: una, anulada desde Contabilidad; después otra del mismo hito, anulada también)
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5501', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5501') returning id into v_f1;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_f1, 'c11-pruebas: la primera', null);
    perform pg_temp.c11_ser('editor');
    if v_todas then
      begin
        insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
        values ('c11-prueba-a', 'ZZ-QB-5502', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5502');
        a := 'ENTRÓ';
      exception when unique_violation then
        a := 'no entra (23505)';
      end;
      v_obt := format('con una de fuera anulada apuntando al hito, otra fila de facturas de ese hito: %s, y sigue habiendo %s con ese hito', a,
                      (select case count(*) when 1 then 'una sola fila' else count(*) || ' filas' end from facturas ff where ff.hito_id = -1110000002));
      raise exception using errcode = 'MXT00';
    end if;
    -- (el borrador de la buena se abre ahora, con la primera anulada apuntando al hito; y entonces entra otra de fuera, VIVA)
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5502', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5502') returning id into v_f2;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento((v_b->'documento'->>'id')::uuid);
    perform pg_temp.c11_ser('editor');
    f := case when exists (select 1 from jsonb_array_elements(v_d->'avisos') y
                            where y->>'codigo' = 'hito_facturado' and (y->>'frena')::boolean
                              and y->>'texto' like 'El hito «C11 PRUEBA Milestone 2» ya se facturó: factura ZZ-QB-5502 del %')
                   and not (v_d->>'puede_emitir')::boolean
              then 'el borrador dice solo que ya se facturó (nombra la viva y frena;'
              else 'el borrador NO dice que ya se facturó (' || left((v_d->'avisos')::text, 200) || ';' end
         || case when not exists (select 1 from jsonb_array_elements(v_d->'avisos') y where y->>'codigo' = 'hito_factura_anulada')
                 then ' no añade «esta la sustituye»)' else ' y AÑADE «esta la sustituye»)' end;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_f2, 'c11-pruebas: la segunda', null);
    perform pg_temp.c11_ser('editor');
    select n.numero into v_n1 from notas_credito n where n.anula_a = v_f1;
    select n.numero into v_n2 from notas_credito n where n.anula_a = v_f2;
    a := case when (select count(*) from facturas ff where ff.hito_id = -1110000002 and ff.estado = 'anulada') = 2 then 'las dos apuntan al hito'
              else 'NO apuntan las dos al hito' end;
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    select y.value into v_av from jsonb_array_elements(v_b->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    b := case when v_av->>'texto' like 'El hito «C11 PRUEBA Milestone 2» ya tuvo facturas que se anularon: ZZ-QB-5501 del % (nota de crédito ' || v_n1
                                       || '), ZZ-QB-5502 del % (nota de crédito ' || v_n2 || '). Esta las sustituye: al emitirla, las anuladas '
                                       || 'dejan de figurar como la factura de este hito (en lo demás no cambian: siguen anuladas) y queda apuntado.'
              then 'las nombra a las dos' else 'dice: ' || coalesce(v_av->>'texto', '(no avisa)') end
         || case when not (v_av->>'frena')::boolean then ', sin frenar' else ', y FRENA' end
         || case when (v_b->>'puede_emitir')::boolean then ', y se puede emitir' else ', y NO se puede emitir' end;
    r := pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    select count(*) into v_k from emision_soltados so where so.documento_id = (r->>'documento')::uuid and not so.de_la_app
       and so.hito_id = -1110000002 and so.factura_id in (v_f1, v_f2);
    c := case when r->>'estado' = 'emitida'
                   and r->'soltadas' = jsonb_build_array(
                         jsonb_build_object('factura_id', v_f1, 'numero', 'ZZ-QB-5501', 'nota_credito', v_n1, 'de_la_app', false),
                         jsonb_build_object('factura_id', v_f2, 'numero', 'ZZ-QB-5502', 'nota_credito', v_n2, 'de_la_app', false))
                   and (select count(*) from facturas ff where ff.id in (v_f1, v_f2) and ff.hito_id is null and ff.estado = 'anulada') = 2
              then 'suelta las dos y dice cuáles' else 'NO: ' || r::text end
         || format('; quedan %s apuntes', v_k);
    select format('%s, %s', case count(*) when 1 then 'una sola fila de facturas con ese hito' else count(*) || ' filas de facturas con ese hito' end,
                  case when bool_and(ff.estado = 'emitida' and ff.id = (r->>'factura_id')::bigint) then 'la viva' else 'y NO es la viva' end)
      into d from facturas ff where ff.hito_id = -1110000002;
    e := pg_temp.c11_propios();
    v_obt := format('con la primera de fuera anulada apuntando al hito, un borrador abierto y otra de fuera, viva, del mismo hito: %s | '
                    'anulada también la segunda: %s | el borrador: %s | al emitir: %s | %s | los controles de la '
                    'facturación: %s', f, a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (55, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LO QUE ENCONTRÓ LA REVISIÓN DE ESE ARREGLO (12-nov-2026). Cada cosa con su
-- prueba: con la capa de antes de esa revisión fallan la 56 y la 57; la 54,
-- por el detalle del error; y, en una base sin el índice que cuenta las
-- anuladas, la 55, por los dos avisos a la vez. (Lo que era de ESTE archivo
-- —que no frene a la app— lo prueba c11-concurrencia.sh, 7 y 8; y que no
-- deje nada, la 42 y la 44.)
-- ---------------------------------------------------------------------
-- 56. EL HITO QUE SIGUE COMO «FACTURADO» CON SU FACTURA ANULADA. Anular desde
--     Contabilidad (por c3, que no sabe de hitos: así se anula hoy una de
--     QuickBooks, con una consulta) deja la ficha con el hito «facturado» y
--     sin ninguna factura viva, y la ficha no tiene botón para devolverlo a
--     pendiente. Solo se factura un hito pendiente, así que ese hito no se
--     ofrece y su borrador no se abre: eso no cambia. Lo que cambia es que
--     SE DICE: el control 75 lo avisa (el hito, la obra, la factura anulada
--     y su nota de crédito, y qué hacer); pedir su borrador ya no contesta
--     «aquí no hay ninguna factura suya (¿se facturó en QuickBooks…?)»:
--     nombra la anulada y dice qué hacer; y un borrador que ya estaba
--     abierto lo frena con ese mismo texto, sin añadir «esta la sustituye».
--     Devuelto el hito a pendiente (el segundo paso de la consulta con que
--     se anula), el aviso se apaga y se factura; y si en realidad ya se
--     había vuelto a facturar por fuera, enlazada esa factura a su hito el
--     aviso se apaga también. Y SI LA ANULADA ES DE LA
--     APP y aquí sigue sin cerrar: lo dice así y manda a cerrarla aquí
--     (Anular: termina lo de aquí y el hito vuelve a pendiente); el control
--     75 la nombra una vez, como anulada sin cerrar, sin repetir el hito.
do $$
declare
  v_obt text; v_fq bigint; v_nc text; v_x text; v_y text; v_75 text; v_b jsonb; v_doc uuid; v_d jsonb; v_h jsonb; r jsonb;
  r1 jsonb; v_doc1 uuid; v_f1 bigint; v_nc1 text; v_ra jsonb; v_b2 jsonb; v_av jsonb; v_txt text;
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_nom text := 'EL HITO QUE SIGUE COMO FACTURADO CON SU FACTURA ANULADA (anulada desde Contabilidad, por c3, que no sabe de hitos: una de '
                'QuickBooks, o una de la app sin cerrar aquí): el control 75 lo avisa; pedir su borrador dice cuál es la anulada, con su '
                'nota de crédito, y qué hacer; un borrador ya abierto lo frena con ese mismo texto y no añade «esta la sustituye»; '
                'devuelto el hito a pendiente (o cerrada aquí la de la app), el aviso se apaga y se factura';
  v_esp text := 'una de QuickBooks anulada desde Contabilidad, con un borrador de su hito ya abierto: el control 75 lo avisa (el hito, su '
                'factura anulada con su nota de crédito, y qué hacer) y la lista de la obra no lo ofrece | pedir su borrador: MX008, '
                'nombra la anulada con su nota de crédito y dice qué hacer (el hito tiene que volver antes a pendiente; la ficha no tiene '
                'botón) | el borrador que ya estaba abierto: lo frena con ese mismo texto, sin «esta la sustituye», no se ofrece y '
                'emitirlo da MX008 | si ya se había vuelto a facturar por fuera y esa factura se enlaza a su hito (la anulada lo suelta '
                'antes): el control 75 verde | devuelto el hito a pendiente: el control 75 verde, el borrador avisa sin frenar y se emite '
                '(suelta la de QuickBooks) | una de la app anulada desde Contabilidad y sin cerrar aquí: el control 75 la nombra como anulada sin '
                'cerrar (una vez: no repite el hito) | pedir el borrador de su hito: MX008, nombra la factura con su nota de crédito y '
                'manda a cerrarla aquí | cerrada aquí: ya estaba en el libro, el hito a pendiente, el control 75 verde, y el borrador se '
                'abre y avisa sin frenar';
begin
  if pg_temp.c11_omitir(56, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(56, v_nom, v_esp, array[75]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- (A) UNA DE QUICKBOOKS. El borrador del hito 2 se abre mientras está pendiente; después entra su factura de fuera (como
    --     la deja la función de QuickBooks: su fila con el hito, y el hito a facturado) y se anula desde Contabilidad (c3)
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000002));
    v_doc := (v_b->'documento'->>'id')::uuid;
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5601', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5601')
    returning id into v_fq;
    update hitos set estado = 'facturado' where id = -1110000002;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_fq, 'c11-pruebas: se anula en Contabilidad', null);
    select o.hitos->1 into v_h from v_emision_obras o where o.proyecto_id = 'c11-prueba-a';
    perform pg_temp.c11_ser('editor');
    select n.numero into v_nc from notas_credito n where n.anula_a = v_fq;
    v_75 := pg_temp.c11_ctl(75);
    a := case when v_75 like 'rojo: el hito «C11 PRUEBA Milestone 2» de C11 PRUEBA Uno sigue como facturado en la ficha y su factura ZZ-QB-5601 '
                             '(nota de crédito ' || v_nc || ') está anulada: no tiene ninguna factura viva →%'
                   and v_75 like '%El hito que sigue como facturado con su factura anulada: si no se volvió a facturar por otro lado, está '
                                 'SIN FACTURAR, y para hacer la buena tiene que volver antes a pendiente; si sí se volvió a facturar (en '
                                 'QuickBooks), esa factura tiene que quedar enlazada a su hito. La ficha no tiene botón para ninguna de las '
                                 'dos cosas: avisa y se hace.'
              then 'el control 75 lo avisa (el hito, su factura anulada con su nota de crédito, y qué hacer)' else 'el control 75: ' || v_75 end
         || case when (v_h->>'id')::bigint = -1110000002 and v_h->>'estado' = 'facturado' and not (v_h->>'puede')::boolean and v_h->>'factura' is null
                 then ' y la lista de la obra no lo ofrece' else ' y la lista de la obra: ' || v_h::text end;
    -- pedir su borrador (el 🧾, o «Facturar» en la lista)
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000002}') $q$);
    v_txt := 'El hito «C11 PRUEBA Milestone 2» sigue marcado como facturado en la ficha de la obra y su factura ZZ-QB-5601 del '
             || fn_emision_dia(pg_temp.c11('hoy')::date) || ' (nota de crédito ' || v_nc || ') está anulada: hoy no tiene ninguna factura viva. '
             || 'Si no se volvió a facturar por otro lado (en QuickBooks), está sin facturar: para hacer aquí la buena, el hito tiene que '
             || 'volver antes a pendiente (la ficha no tiene botón para eso: avisa y se hace).';
    b := case when v_x = 'MX008: ' || v_txt
              then 'MX008, nombra la anulada con su nota de crédito y dice qué hacer (el hito tiene que volver antes a pendiente; la ficha '
                   'no tiene botón)' else v_x end;
    -- el borrador que ya estaba abierto
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento(v_doc);
    perform pg_temp.c11_ser('editor');
    v_y := pg_temp.c11_err(format('select fn_emision_emitir(%L, %L)', v_doc, v_d->>'visto'));
    select y.value into v_av from jsonb_array_elements(v_d->'avisos') y where y.value->>'codigo' = 'hito_marcado_facturado';
    c := case when (v_av->>'frena')::boolean and v_av->>'texto' = v_txt then 'lo frena con ese mismo texto'
              else 'el aviso: ' || coalesce(v_av::text, 'no hay (' || left((v_d->'avisos')::text, 200) || ')') end
         || case when not exists (select 1 from jsonb_array_elements(v_d->'avisos') y where y->>'codigo' = 'hito_factura_anulada')
                 then ', sin «esta la sustituye»' else ', y AÑADE «esta la sustituye»' end
         || case when not (v_d->>'puede_emitir')::boolean then ', no se ofrece' else ', SE OFRECE emitir' end
         || case when v_y = 'MX008: ' || v_txt then ' y emitirlo da MX008' else ' y emitirlo: ' || v_y end;
    -- (y si SÍ se había vuelto a facturar por fuera: lo que toca es enlazar esa factura a su hito —la anulada lo suelta
    -- antes: con el índice de producción no caben las dos—, y el aviso también se apaga. Se deshace)
    begin
      update facturas set hito_id = null where id = v_fq;
      insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
      values ('c11-prueba-a', 'ZZ-QB-5602', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5602');
      h := 'el control 75 ' || pg_temp.c11_color(pg_temp.c11_ctl(75));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- devuelto a pendiente (la ficha no tiene botón: es el segundo paso de la consulta con que se anula una de QuickBooks)
    update hitos set estado = 'pendiente' where id = -1110000002;
    v_75 := pg_temp.c11_ctl(75);
    perform pg_temp.c11_ser('dueno');
    v_d := fn_emision_documento(v_doc);
    perform pg_temp.c11_ser('editor');
    select y.value into v_av from jsonb_array_elements(v_d->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    r := pg_temp.c11_emitir(v_doc);
    d := format('el control 75 %s', pg_temp.c11_color(v_75))
         || case when not (v_av->>'frena')::boolean and v_av->>'texto' like 'El hito «C11 PRUEBA Milestone 2» ya tuvo una factura que se anuló: ZZ-QB-5601 del %'
                      and (v_d->>'puede_emitir')::boolean
                 then ', el borrador avisa sin frenar' else ', el borrador: ' || left((v_d->'avisos')::text, 200) end
         || case when r->>'estado' = 'emitida'
                      and r->'soltadas' = jsonb_build_array(jsonb_build_object('factura_id', v_fq, 'numero', 'ZZ-QB-5601', 'nota_credito', v_nc, 'de_la_app', false))
                 then ' y se emite (suelta la de QuickBooks)' else ' y al emitir: ' || r::text end;
    -- (B) UNA DE LA APP, anulada desde Contabilidad (c3 directo) y sin cerrar aquí: el hito 1 sigue facturado
    r1 := pg_temp.c11_hito(-1110000001);
    v_doc1 := (r1->>'documento')::uuid; v_f1 := (r1->>'factura_id')::bigint;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_f1, 'c11-pruebas: desde Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    select n.numero into v_nc1 from notas_credito n where n.anula_a = v_f1;
    v_75 := pg_temp.c11_ctl(75);
    e := case when v_75 like 'rojo: la factura ' || (r1->>'numero') || ' está anulada en el libro y aquí sigue como emitida →%'
              then 'el control 75 la nombra como anulada sin cerrar' else 'el control 75: ' || v_75 end
         || case when position('C11 PRUEBA Milestone 1' in v_75) = 0 then ' (una vez: no repite el hito)' else ' (y REPITE el hito)' end;
    v_x := pg_temp.c11_err($q$ select fn_emision_borrador('{"forma": "hito", "hito_id": -1110000001}') $q$);
    f := case when v_x = 'MX008: El hito «C11 PRUEBA Milestone 1» sigue marcado como facturado en la ficha de la obra porque su factura '
                         || (r1->>'numero') || ' (nota de crédito ' || v_nc1 || ') está anulada en el libro y aquí sigue sin cerrar. Hay que '
                         || 'cerrar esa anulación aquí (Facturación → la factura → Anular; si ya sale anulada y no ofrece el botón, avisa y '
                         || 'se hace): el hito vuelve a pendiente y entonces se hace la buena.'
              then 'MX008, nombra la factura con su nota de crédito y manda a cerrarla aquí' else v_x end;
    v_ra := pg_temp.c11_anular(v_doc1, 'c11-pruebas: se anuló en Contabilidad');
    v_b2 := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000001));
    select y.value into v_av from jsonb_array_elements(v_b2->'avisos') y where y.value->>'codigo' = 'hito_factura_anulada';
    g := case when (v_ra->>'ya_estaba_en_el_libro')::boolean then 'ya estaba en el libro' else 'NO dice que ya estaba' end
         || format(', el hito a %s, el control 75 %s', v_ra->>'hito_estado', pg_temp.c11_color(pg_temp.c11_ctl(75)))
         || case when (v_b2->>'nuevo')::boolean and (v_b2->>'puede_emitir')::boolean and not (v_av->>'frena')::boolean
                      and v_av->>'texto' like '%ya tuvo una factura que se anuló: ' || (r1->>'numero') || ' del % (nota de crédito ' || v_nc1 || ')%'
                 then ', y el borrador se abre y avisa sin frenar' else ', y el borrador: ' || left(v_b2::text, 300) end;
    v_obt := format('una de QuickBooks anulada desde Contabilidad, con un borrador de su hito ya abierto: %s | pedir su borrador: %s | el '
                    'borrador que ya estaba abierto: %s | si ya se había vuelto a facturar por fuera y esa factura se enlaza a su hito (la '
                    'anulada lo suelta antes): %s | devuelto el hito a pendiente: %s | una de la app anulada desde Contabilidad y sin '
                    'cerrar aquí: %s | pedir el borrador de su hito: %s | cerrada aquí: %s', a, b, c, h, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (56, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 57. LO SUSTITUIDO SE VE. Lo soltado quedaba apuntado (emision_soltados) y
--     no se veía en ningún sitio: el documento de la factura nueva no decía
--     a cuál sustituyó, y de una de QuickBooks, que fue de ese hito solo
--     quedaba en esa tabla. Ahora el documento entero de una factura emitida
--     (lo que lee la pantalla) trae «sustituye» —las anuladas a las que
--     sustituyó en su hito: su número, su nota de crédito, si era de la app
--     o de fuera, y cuándo— y, si es una anulada de la app que soltó su
--     hito, «sustituida_por» —el número y la fecha de la buena—. La que no
--     sustituyó a ninguna, nada. Un borrador no trae esas claves (lo suyo es
--     el aviso), y el equipo no lee nada de esto.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; ra jsonb; d1 jsonb; d2 jsonb; d3 jsonb; d4 jsonb; v_b jsonb; v_fq bigint; v_ncq text;
  a text; b text; c text; d text; e text;
  v_nom text := 'LO SUSTITUIDO SE VE: el documento de la factura que sustituye a una anulada dice a cuál (su número, su nota de crédito, '
                'si era de la app o de fuera, y cuándo), y el de la anulada de la app, cuál la sustituyó; la que no sustituyó a ninguna, '
                'nada; un borrador no trae esas claves y el equipo no lo lee';
  v_esp text := 'la buena de una de la app: su documento dice a cuál sustituyó (la anulada, su número, su nota de crédito, que era de la '
                'app y cuándo), y a ella no la sustituyó nadie | la anulada: su documento dice cuál la sustituyó (el documento, el número '
                'y la fecha de la buena, y cuándo), y ella no sustituyó a ninguna | la que sustituye a una de QuickBooks: lo dice, como '
                'de fuera de la app | la que no sustituyó a ninguna: nada | un borrador no trae esas claves, y el equipo no lo lee '
                '(42501)';
begin
  if pg_temp.c11_omitir(57, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    -- (1) de la app: emitida, anulada, y la buena
    r1 := pg_temp.c11_hito(-1110000001);
    ra := pg_temp.c11_anular((r1->>'documento')::uuid, 'c11-pruebas: monto equivocado');
    r2 := pg_temp.c11_hito(-1110000001);
    -- (2) de QuickBooks: su fila con el hito 2, anulada desde Contabilidad, y el hito facturado por la app (aquí la ficha
    --     no llegó a marcarlo: lo del hito que sigue como facturado lo miran la 53 y la 56)
    insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id)
    values ('c11-prueba-a', 'ZZ-QB-5701', pg_temp.c11('hoy')::date, 3333.33, false, -1110000002, 'ZZ-QBID-5701')
    returning id into v_fq;
    set constraints public.trg_puente_facturas_despues immediate;
    set constraints public.trg_puente_facturas_despues deferred;
    perform pg_temp.c11_ser('dueno');
    perform fn_factura_anular(v_fq, 'c11-pruebas: se anula en Contabilidad', null);
    perform pg_temp.c11_ser('editor');
    select n.numero into v_ncq from notas_credito n where n.anula_a = v_fq;
    r3 := pg_temp.c11_hito(-1110000002);
    -- (3) una que no sustituye a ninguna, y un borrador
    r4 := pg_temp.c11_hito(-1110000003);
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'hito', 'hito_id', -1110000006));
    perform pg_temp.c11_ser('dueno');
    d1 := fn_emision_documento((r1->>'documento')::uuid); d2 := fn_emision_documento((r2->>'documento')::uuid);
    d3 := fn_emision_documento((r3->>'documento')::uuid); d4 := fn_emision_documento((r4->>'documento')::uuid);
    perform pg_temp.c11_ser('editor');
    a := case when jsonb_typeof(d2->'sustituye') = 'array' and jsonb_array_length(d2->'sustituye') = 1
                   and (d2->'sustituye'->0) - 'soltado_el' = jsonb_build_object('factura_id', (r1->>'factura_id')::bigint, 'numero', r1->>'numero',
                                                                               'nota_credito', ra->>'nota_credito', 'de_la_app', true)
                   and (d2->'sustituye'->0->>'soltado_el')::timestamptz is not null
              then 'su documento dice a cuál sustituyó (la anulada, su número, su nota de crédito, que era de la app y cuándo)'
              else 'su documento dice: ' || coalesce((d2->'sustituye')::text, '(no trae la clave)') end
         || case when d2 ? 'sustituida_por' and jsonb_typeof(d2->'sustituida_por') = 'null' then ', y a ella no la sustituyó nadie'
                 else ', y de quién la sustituyó dice: ' || coalesce((d2->'sustituida_por')::text, '(no trae la clave)') end;
    b := case when (d1->'sustituida_por') - 'soltado_el' = jsonb_build_object('documento', r2->>'documento', 'numero', r2->>'numero', 'fecha', pg_temp.c11('hoy'))
                   and (d1->'sustituida_por'->>'soltado_el')::timestamptz is not null and d1->'documento'->>'estado' = 'anulada'
              then 'su documento dice cuál la sustituyó (el documento, el número y la fecha de la buena, y cuándo)'
              else 'su documento dice: ' || coalesce((d1->'sustituida_por')::text, '(no trae la clave)') end
         || case when d1->'sustituye' = '[]'::jsonb then ', y ella no sustituyó a ninguna' else ', y de lo que sustituyó dice: ' || coalesce((d1->'sustituye')::text, '(no trae la clave)') end;
    c := case when jsonb_array_length(d3->'sustituye') = 1
                   and (d3->'sustituye'->0) - 'soltado_el' = jsonb_build_object('factura_id', v_fq, 'numero', 'ZZ-QB-5701', 'nota_credito', v_ncq, 'de_la_app', false)
              then 'lo dice, como de fuera de la app' else 'dice: ' || coalesce((d3->'sustituye')::text, '(no trae la clave)') end;
    d := case when d4->'sustituye' = '[]'::jsonb and d4 ? 'sustituida_por' and jsonb_typeof(d4->'sustituida_por') = 'null' then 'nada'
              else format('dice %s y %s', coalesce((d4->'sustituye')::text, '(sin clave)'), coalesce((d4->'sustituida_por')::text, '(sin clave)')) end;
    e := case when not (v_b ? 'sustituye') and not (v_b ? 'sustituida_por') then 'un borrador no trae esas claves' else 'un borrador TRAE esas claves' end
         || format(', y el equipo no lo lee (%s)', pg_temp.c11_cod(format('select fn_emision_documento(%L)', r2->>'documento'), 'p1'));
    v_obt := format('la buena de una de la app: %s | la anulada: %s | la que sustituye a una de QuickBooks: %s | la que no sustituyó a '
                    'ninguna: %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (57, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL CIERRE
-- ---------------------------------------------------------------------
-- 41. EL CIERRE DEL MES (c9) MIRA LA FACTURACIÓN, con su bloque de c11: las
--     filas 172 y 173 de fn_cierre_revisar. La 172 (detiene) dice lo mismo
--     que los cuadres de v_emision_control; la 173, sus avisos. Un hito
--     facturado dos veces pone la 172 en rojo con el detalle del control;
--     deshecho, vuelve a como estaba. EL NOMBRE de cada fila dice cuáles de
--     sus controles están en rojo («… — 1 en rojo: 40»): la ronda avisa al
--     teléfono de un rojo NUEVO por el nombre de la fila, y con un nombre
--     fijo un rojo nuevo quedaba tapado por otro que ya estuviera. Si el c9
--     de esta base es el de antes (sin el bloque), se omite y dice qué pegar.
--     (En una base con el índice único de facturas por hito —producción—, el
--     hito facturado dos veces se fabrica como en la 36: la fila de la
--     factura de la app sin su hito, y otra de ese hito.)
do $$
declare
  v_obt text; v_r jsonb; v_per text := pg_temp.c11('mes'); v_rc int; v_ra int; v_ok172 boolean; v_ok173 boolean; v_corte date;
  v_hu text := pg_temp.c11_candado_hito();
  f record; g record;
  a text; b text; c text; d text; e text;
  v_nom text := 'EL CIERRE DEL MES (c9) MIRA LA FACTURACIÓN: la fila 172 de su revisión (detiene) dice lo que los cuadres de la facturación '
                'y la 173 (un aviso) lo que sus avisos; un hito facturado dos veces pone la 172 en rojo con el hito, y un aviso la 173; '
                'el nombre de cada fila dice cuáles de sus controles están en rojo; deshecho, vuelven a como estaban';
  v_esp text := 'antes: la 172 detiene y dice lo que los cuadres de la facturación; la 173 es un aviso y dice lo que sus avisos; y sus '
                'nombres dicen cuáles están en rojo | un hito facturado dos veces: la 172 en rojo, detiene, con el hito, y su nombre dice '
                'que el 40 está en rojo | deshecho: la 172 como antes | el porcentaje de la tarjeta puesto por debajo: la 173 en rojo, un '
                'aviso, con lo que es, su nombre dice que el 80 está en rojo, y la 172 como antes | deshecho: la 173 como antes';
begin
  if pg_temp.c11('hay_c9') <> 'true' then
    insert into _pruebas values (41, v_nom, v_esp, 'omitida: c9 (el cierre) no está en esta base', null);
    return;
  end if;
  if not exists (select 1 from pg_proc p where p.oid = to_regprocedure('public.fn_cierre_revisar(text)') and p.prosrc like '%v_emision_control%') then
    insert into _pruebas values (41, v_nom, v_esp,
      'omitida: el cierre de esta base todavía no trae las filas de la facturación (172 y 173): vuelve a pegar docs/conta/c9-cierre.sql (el '
      'que las trae) y corre esto otra vez', null);
    return;
  end if;
  if v_per is null then
    insert into _pruebas values (41, v_nom, v_esp, 'omitida: el libro no tiene un período para el mes de hoy: no hay mes que revisar', null);
    return;
  end if;
  if pg_temp.c11_omitir(41, v_nom, v_esp) then return; end if;
  if pg_temp.c11_omitir_rojo(41, v_nom, v_esp, array[40, 80]) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    v_r := pg_temp.c11_hito(-1110000001);
    select k.corte into v_corte from emision_config k where k.id = 1;
    select count(*) filter (where x.nivel = 'cuadre' and x.ok is not true), count(*) filter (where x.nivel = 'aviso' and x.ok is not true)
      into v_rc, v_ra from v_emision_control x;
    perform pg_temp.c11_ser('dueno');
    select x.nivel, x.ok, x.detalle, x.control into f from fn_cierre_revisar(v_per) x where x.orden = 172;
    select x.nivel, x.ok, x.detalle, x.control into g from fn_cierre_revisar(v_per) x where x.orden = 173;
    perform pg_temp.c11_ser('editor');
    v_ok172 := f.ok; v_ok173 := g.ok;
    a := format('la 172 %s y %s; la 173 %s y %s',
                coalesce(f.nivel, 'NO está'),
                case when f.ok = (v_rc = 0) then 'dice lo que los cuadres de la facturación' else format('dice %s con %s cuadre(s) en rojo', f.ok, v_rc) end,
                case when g.nivel = 'aviso' then 'es un aviso' else 'es ' || coalesce(g.nivel, 'nada: NO está') end,
                case when g.ok = (v_ra = 0) then 'dice lo que sus avisos' else format('dice %s con %s aviso(s) en rojo', g.ok, v_ra) end)
         || case when f.control = pg_temp.c11_nombre_fila('cuadre') and g.control = pg_temp.c11_nombre_fila('aviso')
                 then '; y sus nombres dicen cuáles están en rojo' else format('; y sus nombres son «%s» y «%s»', f.control, g.control) end;
    begin
      if v_hu <> 'ninguno' then
        update facturas set hito_id = null where id = (v_r->>'factura_id')::bigint;
      end if;
      insert into facturas (proyecto_id, num, fecha, monto, hito_id, estado)
      values ('c11-prueba-a', 'ZZ-908', v_corte - 1, 3333.33, -1110000001, 'emitida');
      perform pg_temp.c11_ser('dueno');
      select x.nivel, x.ok, x.detalle, x.control into f from fn_cierre_revisar(v_per) x where x.orden = 172;
      perform pg_temp.c11_ser('editor');
      b := format('la 172 %s, %s, %s', case when f.ok then 'en VERDE' else 'en rojo' end, f.nivel,
                  case when f.detalle like '%el hito «C11 PRUEBA Milestone 1» de C11 PRUEBA Uno tiene 2 facturas vivas%' then 'con el hito'
                       else 'sin decir cuál: ' || left(coalesce(f.detalle, ''), 200) end)
           || case when f.control = pg_temp.c11_nombre_fila('cuadre') and f.control ~ ' en rojo: ([0-9]+, )*40(, [0-9]+)*$'
                   then ', y su nombre dice que el 40 está en rojo' else format(', y su nombre es «%s»', f.control) end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform pg_temp.c11_ser('dueno');
    select x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 172;
    perform pg_temp.c11_ser('editor');
    c := case when f.ok is not distinct from v_ok172 then 'la 172 como antes' else 'la 172 NO volvió' end;
    begin
      perform set_config('mx_emision.escribe', 'emision_config', true);
      update emision_config set tarjeta_pct = 3 where id = 1;
      perform set_config('mx_emision.escribe', '', true);
      perform pg_temp.c11_ser('dueno');
      select x.nivel, x.ok, x.detalle, x.control into g from fn_cierre_revisar(v_per) x where x.orden = 173;
      select x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 172;
      perform pg_temp.c11_ser('editor');
      d := format('la 173 %s, %s, %s, %s, y la 172 %s', case when g.ok then 'en VERDE' else 'en rojo' end,
                  case when g.nivel = 'aviso' then 'un aviso' else g.nivel end,
                  case when g.detalle like '%el porcentaje de la tarjeta está puesto (3 %)%' then 'con lo que es' else 'sin decir qué: ' || left(coalesce(g.detalle, ''), 200) end,
                  case when g.control = pg_temp.c11_nombre_fila('aviso') and g.control ~ ' en rojo: ([0-9]+, )*80(, [0-9]+)*$'
                       then 'su nombre dice que el 80 está en rojo' else format('su nombre es «%s»', g.control) end,
                  case when f.ok is not distinct from v_ok172 then 'como antes' else 'CAMBIÓ' end);
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform set_config('mx_emision.escribe', '', true);
    perform pg_temp.c11_ser('dueno');
    select x.ok into g from fn_cierre_revisar(v_per) x where x.orden = 173;
    perform pg_temp.c11_ser('editor');
    e := case when g.ok is not distinct from v_ok173 then 'la 173 como antes' else 'la 173 NO volvió' end;
    v_obt := format('antes: %s | un hito facturado dos veces: %s | deshecho: %s | el porcentaje de la tarjeta puesto por debajo: %s | deshecho: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 42. Nada queda: lo que c11 toca (y lo que sus pruebas sembraron) está
--     como antes de la primera prueba. También la revisión guardada del
--     cierre del mes (cierre_revisiones, de c9): mirar «lo que detiene el
--     cierre» la reescribe, y antes la primera lectura de estas pruebas se
--     hacía fuera de todo bloque y la dejaba cambiada (como abrir la
--     pantalla Cierre).
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c11_ser('editor');
    v_obt := case when pg_temp.c11_conteos() = pg_temp.c11('conteos') then 'igual que antes' else 'antes: ' || pg_temp.c11('conteos') || ' · ahora: ' || pg_temp.c11_conteos() end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'nada queda de las pruebas: los ajustes, las obras y sus retenciones, los documentos, las líneas, la serie y su contador, los PDF, los envíos y lo soltado, las facturas (con su estado y su hito) y los hitos, las notas de crédito, los asientos, los cobros, los estimados, los perfiles y usuarios, las reglas de ingreso, los períodos, los archivos del bucket, los índices de facturas, lo de los cobros en línea, las funciones y la revisión guardada del cierre del mes, como antes',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 43. Con facturas emitidas, anuladas, vueltas a emitir, por porcentaje,
--     T&M, cobradas por cheque y con su factura de la retención, NINGÚN
--     control de las otras capas pasa a rojo: la cadena y «permisos» de c2,
--     los puentes (c3), el banco (c6), los estados (c4), los cuadres de p1,
--     de la IA (c8) y de la mano de obra (c10), y lo que detiene el cierre
--     del mes (c9). Se compara con cómo estaban con las obras de prueba ya
--     sembradas (lo que ya estaba en rojo se dice, y no cuenta): los de las
--     otras capas Y los de la facturación (con datos reales, el 72 puede
--     estar en rojo solo por adelantar el corte a hoy). Y el 64: la factura
--     cobrada entera se nombra hasta que se marca como cobrada en su obra.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_b jsonb; s0 text[]; s1 text[]; s2 text[]; s3 text[]; s4 text[]; v_antes text := '';
  p0 text[]; v_64 text; v_64b text;
  v_nom text := 'con facturas emitidas, anuladas, vueltas a emitir, por porcentaje, T&M, cobradas por cheque y con su factura de la '
                'retención, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3), el banco (c6), '
                'los estados (c4), los cuadres de p1, de la IA (c8) y de la mano de obra (c10), y lo que detiene el cierre del mes (c9); ni '
                'ninguno de la facturación';
  v_esp text := 'al emitir tres: ninguno | al anular una y volver a emitirla: ninguno | con una por porcentaje, una T&M y un cobro por cheque '
                '(con su retención): ninguno | con la factura de la retención: ninguno | la cobrada entera: el 64 la nombra hasta que se '
                'marca como cobrada en su obra | y de la facturación: nada nuevo';
begin
  if pg_temp.c11_omitir(43, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c11_sembrar();
    perform pg_temp.c11_ser('dueno');
    perform fn_emision_obra('{"proyecto_id": "c11-prueba-a", "retencion_pct": 10}'::jsonb);
    perform pg_temp.c11_ser('editor');
    s0 := pg_temp.c11_rojos();
    -- (y los de la facturación que ya están en rojo CON LAS OBRAS SEMBRADAS y el corte adelantado a hoy: con datos reales, una
    -- factura de hoy hecha fuera de la app enciende el 72; no es de esta prueba)
    select coalesce(array_agg(k.orden::text), '{}') into p0 from v_emision_control k where not k.ok;
    r1 := pg_temp.c11_hito(-1110000001); r2 := pg_temp.c11_hito(-1110000002); r3 := pg_temp.c11_hito(-1110000003);
    s1 := pg_temp.c11_rojos();
    perform pg_temp.c11_anular((r2->>'documento')::uuid, 'c11-pruebas: monto equivocado');
    perform pg_temp.c11_hito(-1110000002);
    s2 := pg_temp.c11_rojos();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'porcentaje', 'proyecto_id', 'c11-prueba-b', 'porcentaje', 25));
    perform pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'tm', 'proyecto_id', 'c11-prueba-d', 'lineas', jsonb_build_array(
             jsonb_build_object('tipo', 'horas', 'descripcion', 'Electrician labor', 'cantidad', 7.25, 'unidad', 'hr', 'precio', 95),
             jsonb_build_object('tipo', 'material', 'descripcion', 'Materials', 'cantidad', 1, 'precio', 545.82))));
    perform pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    perform pg_temp.c11_ser('dueno');
    perform fn_cobro_registrar(jsonb_build_object('fecha', pg_temp.c11('hoy'), 'monto', '3333.33', 'medio', 'cheque', 'referencia', 'C11-PRUEBA-43',
              'duplicado_confirmado', 'c11-pruebas: un cobro de prueba',
              'aplicaciones', jsonb_build_array(
                jsonb_build_object('factura_id', (r1->>'factura_id')::bigint, 'monto', '3000.00'),
                jsonb_build_object('factura_id', (r1->>'factura_id')::bigint, 'monto', '333.33', 'es_retencion', true))));
    perform pg_temp.c11_ser('editor');
    -- (la primera quedó cobrada ENTERA en el libro: el 64 la nombra hasta que se marca como cobrada en la ficha de su obra)
    v_64 := pg_temp.c11_ctl(64);
    update facturas set pagada = true where id = (r1->>'factura_id')::bigint;
    v_64b := pg_temp.c11_ctl(64);
    s3 := pg_temp.c11_rojos();
    v_b := pg_temp.c11_borrador(jsonb_build_object('forma', 'retencion', 'proyecto_id', 'c11-prueba-a'));
    perform pg_temp.c11_emitir((v_b->'documento'->>'id')::uuid);
    s4 := pg_temp.c11_rojos();
    v_obt := format('al emitir tres: %s | al anular una y volver a emitirla: %s | con una por porcentaje, una T&M y un cobro por cheque (con su '
                    'retención): %s | con la factura de la retención: %s | la cobrada entera: %s | y de la facturación: %s',
                    pg_temp.c11_nuevos(s0, s1), pg_temp.c11_nuevos(s0, s2), pg_temp.c11_nuevos(s0, s3), pg_temp.c11_nuevos(s0, s4),
                    case when v_64 like 'rojo: %' and position((r1->>'numero') || ' ($3,333.33, de C11 PRUEBA Uno)' in v_64) > 0
                              and position((r1->>'numero') || ' ($3,333.33' in coalesce(v_64b, 'x')) = 0 and v_64b is not null
                         then 'el 64 la nombra hasta que se marca como cobrada en su obra'
                         else format('el 64 antes de marcarla: %s; después: %s', coalesce(v_64, '(no está)'), coalesce(v_64b, '(no está)')) end,
                    (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_emision_control k
                      where not k.ok and k.orden::text <> all (p0 || pg_temp.c11_ya_rojos())));
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, v_nom, v_esp,
    v_obt || case when v_antes <> '' then ' (ya en rojo antes, con las obras de prueba sembradas: ' || v_antes || ')' else '' end, v_obt = v_esp);
end $$;

-- 44. El cierre de la suite: los controles de c2 (la cadena y «permisos»),
--     c3, c6, c4, p1, c8, c10 y lo que detiene el cierre (c9) como estaban
--     antes de la primera prueba (lo que ya estaba en rojo se dice y no
--     cuenta); los de la facturación, igual; nada de c11 para anon o
--     service_role ni más SECURITY DEFINER que la del número; y
--     fn_emision_pegado responde con sus doce filas y los ajustes siguen
--     siendo UNA fila (pegar dos veces no los pisa: lo corre el banco, con
--     dos pegados seguidos antes de esta suite).
do $$
declare
  v_obt text; v_otras text; v_c11 text; v_perm text; v_api text; v_n int; v_cfg int; v_fin text;
  v_esp text := 'controles de las otras capas en rojo que no lo estaban: ninguno | de la facturación: nada nuevo | c2 permisos verde | c11 para '
                'anon o service_role, o definer de más: ninguna | el pegado: 12 filas, y los ajustes 1 fila (id 1) | y después de todo, lo '
                'que c11 toca: igual que antes';
begin
  begin
    perform pg_temp.c11_ser('editor');
    -- (dentro de un bloque que se deshace: mirar lo que detiene el cierre del mes guarda su revisión, y aquí no queda nada)
    begin
      v_otras := pg_temp.c11_nuevos(coalesce(string_to_array(nullif(pg_temp.c11('rojos_antes'), ''), '; '), '{}'::text[]), pg_temp.c11_rojos());
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_c11 := pg_temp.c11_propios();
    v_perm := pg_temp.c11_permisos();
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c11_es_suya(p.proname)
       and ((p.prosecdef and p.proname <> 'fn_emision_numerar')
            or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_emision_pegado();
    select count(*) into v_cfg from emision_config;
    v_fin := case when pg_temp.c11_conteos() = pg_temp.c11('conteos') then 'igual que antes'
                  else 'CAMBIÓ: antes ' || pg_temp.c11('conteos') || ' · ahora ' || pg_temp.c11_conteos() end;
    v_obt := format('controles de las otras capas en rojo que no lo estaban: %s | de la facturación: %s | c2 permisos %s | c11 para anon o '
                    'service_role, o definer de más: %s | el pegado: %s filas, y los ajustes %s fila (id %s) | y después de todo, lo que c11 '
                    'toca: %s',
                    v_otras, v_c11, v_perm, v_api, v_n, v_cfg, (select id from emision_config limit 1), v_fin);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'el cierre de la suite: los controles de c2, c3, c6, c4, p1, c8, c10 y del cierre (c9) como estaban antes de las pruebas, y los de la facturación también; nada de c11 para anon o service_role ni más SECURITY DEFINER que la del número; fn_emision_pegado responde y los ajustes son una fila (pegar dos veces no los pisa: lo corre el banco); y al terminar no queda nada (tampoco la revisión guardada del cierre)',
    v_esp,
    v_obt || case when pg_temp.c11('rojos_antes') <> '' then ' (ya en rojo antes de las pruebas: ' || pg_temp.c11('rojos_antes') || ')' else '' end
          || case when pg_temp.c11('ctl_rojos') <> '' then ' (de la facturación, ya en rojo antes: ' || pg_temp.c11('ctl_rojos') || ')' else '' end
          || case when pg_temp.c11('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c11: ' || pg_temp.c11('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;
reset mxp.stripe_sin_push;

-- UNA PRUEBA QUE NO PUDO TOMAR UN CANDADO EN MEDIO SEGUNDO NO ES UN FALLO:
-- la app (u otra sesión) tenía tomado algo que necesitaba, y esta corrida no
-- espera más (el tope de arriba, para no dejar esperando a la app). Sale
-- «omitida», con lo que dijo la base, y se vuelve a pegar el archivo en un
-- momento más tranquilo.
update _pruebas
   set ok = null,
       obtenido = 'omitida: mientras corría, la app (u otra sesión) tenía tomado algo que esta prueba necesita y no lo soltó en medio '
                  || 'segundo (55P03); no se esperó más, para no dejar esperando a la app. No es un fallo: vuelve a pegar el archivo en un '
                  || 'momento en que nadie esté usando la app. Lo que dio: ' || left(obtenido, 300)
 where ok is false and obtenido like '%55P03%';

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8, c9 y c10): si el SQL Editor deja de esperar, la corrida sigue en
-- el servidor hasta el final y se lee después con
--   select * from pruebas.c11_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c11_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c11_resultado from public, anon, authenticated, service_role;
truncate pruebas.c11_resultado;
insert into pruebas.c11_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
