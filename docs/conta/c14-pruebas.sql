-- =====================================================================
-- c14-pruebas.sql — W-9, COI y el 1099 se prueban a sí mismos
-- (c14-subs.sql). 12-nov-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c14-subs.sql (y,
-- si el c9-cierre.sql que tienes trae la fila 179, después de volver a
-- pegarlo), pegar este archivo entero → Run. Sale la tabla _pruebas: 48
-- filas, todas con ok = true (las que salen «omitida» dicen por qué y no
-- son un fallo; una fila 99 solo sale si algo de este archivo falló). Si el
-- editor se cansa antes del final, la corrida sigue en el servidor y se lee
-- después en pruebas.c14_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c12 y c14-subs.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c14-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las fichas, ni un TIN, ni un archivo, ni las obras, los
-- proveedores y la persona de prueba, ni sus asientos, ni la revisión del
-- cierre que c9 guarda, ni el reloj); la 47 lo comprueba, y la 48 otra vez
-- al final de todo.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · TRES PROVEEDORES DE PRUEBA («ZZ Sub Uno C14 PRUEBA», «ZZ Sub Dos…»,
--     «ZZ Supply…») y UNA PERSONA («Zzeli C14 PRUEBA», con su usuario en
--     auth.users y su perfil de campo): nombres que nadie lleva. Si la base
--     no deja crear el usuario de prueba, las pruebas que lo necesitan salen
--     «omitida» con lo que dijo la base.
--   · DOS OBRAS («C14 PRUEBA Obra A» y «B», ids c14-prueba-a y b).
--   · SUS FICHAS, con nombres «ZZ … C14 PRUEBA» y TIN DE MENTIRA con forma
--     válida que no existen (000-00-000N, 00-000000N). Ninguna prueba toca
--     una ficha real, y cada una mira SUS filas del 1099 (por su ficha), no
--     «la primera fila».
--   · SUS ASIENTOS: a mano por el camino del dueño (fn_postear), por el
--     puente de trabajos externos de c3 (ids negativos, −1400001…: no gastan
--     la secuencia) y por el banco de c6 (un movimiento «como lo trae Plaid»,
--     con «C14 PRUEBA» en su descripción, y el pago a su proveedor), con
--     montos raros (no casan con nada real) y fechados en EL MES DE LAS
--     PRUEBAS: el mes abierto más viejo que ya empezó.
--   · Las pruebas de dos años (un pago en diciembre y otro en enero; el
--     reverso de un pago de un año ya cerrado; el pago que el banco fecha en
--     diciembre y el libro en enero) fingen el reloj DENTRO de su
--     subtransacción (el de c2-pruebas: «hoy» pasa a ser febrero del año
--     siguiente) y usan el primer diciembre y el enero siguiente que estén
--     abiertos; si no los hay, salen «omitida». Al final el archivo
--     comprueba que el reloj quedó como estaba (y si no, lo restaura y sale
--     un fallo, la fila 99).
--   · LA CONFIGURACIÓN Y LOS UMBRALES de la base real pueden ser otros (un
--     umbral confirmado en otro monto, otra regla de a quién no se le
--     reporta, otros días del COI, «al exento de WC le basta»): cada prueba
--     los pone como de fábrica DENTRO de su subtransacción (al sembrar) y
--     los deja como estaban al deshacerse. Las cuentas configuradas no se
--     tocan.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10, c11, c12) se comparan
-- con cómo estaban justo antes: lo que ya estaba en rojo se dice y no se
-- cuenta.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 10 tablas, 6 vistas, las 39 funciones por su
--    nombre exacto, la configuración, cada objeto con su comentario «c14: …»);
--  2 las precondiciones en rojo;
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas; el dueño
--    entra y ve;
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa, RLS y
--    policies justas, vistas security_invoker, nada colgado de contratistas,
--    y «permisos» (c2) en verde con c14 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API; lo
--    que es rastro, ni con la marca; y el TIN con mala forma, MX005);
--  6 la configuración y el umbral de cada año, con sus frenos;
--  7 la ficha: alta, cambio, historial, sus terceros y sus frenos (un
--    tercero en una sola ficha; un contratista de la app no es un tercero);
-- EL TIN:
--  8 se guarda, se cambia y se quita; la vista enseña los 4 últimos; el
--    dueño que lee la tabla a mano ve cero filas;
--  9 el equipo, anon y service_role no lo ven: ni por la tabla, ni por una
--    vista, ni por una función, ni con la marca puesta a mano;
-- 10 guardar y exportar piden el código del teléfono (aal2), como s1; y
--    desde el SQL Editor ni se guarda un TIN (y lo dice SIN un error, para
--    que lo tecleado no vaya al registro del servidor) ni se saca la hoja;
-- 11 no aparece en ningún mensaje de error ni en ninguna otra tabla;
-- 12 su forma, y un TIN en una sola ficha;
-- LOS ARCHIVOS:
-- 13 el bucket «subs»: solo el dueño con su código sube y lee; nadie borra
--    ni pisa («omitida» sin Storage);
-- 14 registrar un W-9 y un COI (ruta, sha256, bytes, que esté en Storage),
--    dos veces = una, retirar;
-- EL CRITERIO DEL PAGO REPORTABLE, al centavo:
-- 15 un pago directo a 5200 desde el banco (clasificado por c6), con su
--    parte de material en el mismo pago (que se pregunta: sin clasificar
--    hasta que se marca, o hasta que su cuenta se dice «no es servicio»);
-- 16 una cuenta por pagar de servicio (un trabajo externo de c3) pagada por
--    el banco (c6): lo devengado no cuenta —pero su fila sale, sin pagos—;
--    lo pagado sí, en su fecha;
-- 17 una cuenta por pagar con MATERIAL Y SERVICIO pagada en dos veces,
--    diciembre y enero: dos años, al centavo;
-- 18 pagado con TARJETA: directo, una cuenta por pagar, y el papel que dice
--    tarjeta aunque salga del banco;
-- 19 un REVERSO: en el mismo mes resta ahí; el de un pago de un año cerrado
--    resta en el año nuevo, y el control lo avisa;
-- 20 un JORNAL de c10 repartido (tercero «empleado»), con su parte sin obra;
-- 21 una corporación, la excepción, «no se reporta» y «por decidir» (con
--    pagos ya hechos, corrigiendo: «corrige»);
-- 22 el umbral justo en el borde, y el umbral confirmado de un año;
-- 23 la misma persona como empleado y como proveedor: una ficha, un 1099;
-- 24 un tercero sin ficha y un pago sin tercero: se dice, y atribuirlo lo
--    arregla sin tocar el libro; y la ficha que se propone por el nombre;
-- 25 las marcas (tarjeta, no es servicio, sí es servicio), sus frenos, y el
--    reverso que sigue la marca de su original;
-- 26 lo pagado a una partida sin papel (de más; la apertura): sin
--    clasificar, hasta que se decide;
-- 27 el año en que empieza el libro es PARCIAL, y lo de antes (sus papeles);
-- 28 bajar al asiento: cada parte con su asiento y su línea, y su suma es la
--    fila;
-- EL COI:
-- 29 vigente, «vence en N días», vencido y sin COI; el COI de cuando se
--    trabajó; el exento de WC (y, si la configuración dice que le basta,
--    quien no es exento sigue sin estar cubierto: sí o no, nunca nulo);
-- LA HOJA:
-- 30 el CSV (columnas, el TIN entero, las comillas), los pendientes con su
--    porqué, «bajo_umbral», y su rastro sin TIN;
-- 31 lo exportado y lo que el libro dice después;
-- LOS CONTROLES:
-- 32 el 45, el 50, el 55 y el 88 en rojo y de vuelta; y las cuentas de la
--    configuración (las que no pagan a nadie, las por pagar que se siguen);
-- 33 el 20, el 90 y el 95 en rojo y de vuelta;
-- 34 las dos filas del cierre (160 y 179), también con «al exento le
--    basta» puesto;
-- 35 el cierre (c9) mira los subs («omitida» mientras c9-cierre.sql no
--    traiga el bloque de c14);
-- 36 los textos, en llano: ninguno nombra una función;
-- LO QUE LA REVISIÓN DE LA FASE 12a ENCONTRÓ (dinero y seguridad):
-- 37 lo que pasa de una cuenta por pagar a otra HEREDA lo que era: la
--    retención de un sub (2010 → 2020) y el anticipo que se cruza con su
--    papel siguen siendo servicio;
-- 38 nada se queda fuera callado: la retención pagada desde la Bandeja sin
--    nombre, el pago a mano de la partida de un sub sin su tercero, el
--    anticipo a quien todavía no tiene ficha; y la hoja lo dice
--    (pendientes, avisos, «completa»);
-- 39 el estatus con fecha: con pagos ya hechos la base pide «desde»; cada
--    pago cuenta con el estatus de su día; retirar el tramo; «corrige»; de
--    «por decidir» a «sí» no pide nada; y cambiar un TIN por otro pide
--    confirmarlo;
-- 40 el abogado: un pago por una cuenta de gasto sin etiqueta a alguien con
--    ficha se pregunta (sin clasificar), y la marca lo mete;
-- 41 por otro camino (de su bolsillo), directo y saldando una cuenta por
--    pagar: sale, se avisa, y la marca «pagado» lo cuenta;
-- 42 las fechas, en llano (1-oct-2026), en todo lo que escribe la capa;
-- 43 el TIN, a los lados: ningún mensaje repite lo tecleado en otro campo;
--    un campo que es entero un TIN no se guarda; desde el SQL Editor, sin
--    error; la columna no deja estadísticas; y el mensaje del código dice
--    dónde se activa;
-- 44 la fila 160 del cierre cuenta a quien tiene nombre; el servicio sin
--    nombre se dice aparte;
-- 45 la fecha del pago: la del libro o la del banco, y el aviso 82;
-- Y el cierre de la suite:
-- 46 con fichas, TIN, archivos, marcas y una hoja exportada, NINGÚN control
--    de c2, c3, c4, c6, c8, c9, c10, c11 ni c12 pasa a rojo;
-- 47 nada queda al deshacer;
-- 48 el cierre de la suite: las demás capas como estaban, nada de c14 para
--    anon o service_role ni SECURITY DEFINER; fn_subs_pegado responde; y
--    nada queda.
-- Última sentencia: select * from _pruebas order by n;
--
-- NO FRENA A LA APP (como c11-pruebas.sql; la revisión final del 12-nov): lo
-- primero que hace es poner lock_timeout a MEDIO SEGUNDO para toda la
-- corrida, como el pegado de la capa. La prueba 33 quita un candado del
-- bucket «subs» en storage.objects —la tabla de TODOS los archivos de la
-- app— dentro de un bloque que se deshace, y para eso necesita la tabla
-- entera: sin tope, con una lectura larga de Storage abierta en otra sesión,
-- la suite se quedaba esperando y todas las lecturas de archivos de la app
-- detrás de ella (medido en el banco, con una lectura de 75 s abierta: la
-- suite 85 s en vez de 20, y una lectura de la app parada 64 s). Con el
-- tope, la prueba que no consigue su candado en medio segundo no espera
-- más: sale «omitida» y lo dice (no es un fallo: se vuelve a pegar en un
-- momento más tranquilo), y nada queda a medias (su bloque se deshace).
-- =====================================================================
-- (Dura lo que dura la corrida, una transacción.)
set local lock_timeout = '500ms';

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el mes de las pruebas, hoy.
create temp table if not exists _c14 (k text primary key, v text);
truncate _c14;
insert into _c14
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c14
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c14 values ('p1', gen_random_uuid()::text);   -- la persona de prueba (su usuario y su perfil se siembran y se deshacen)
insert into _c14 values ('hoy', fn_fecha_miami(now())::text);
-- el mes de las pruebas: el mes abierto más viejo que ya empezó
insert into _c14
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1;
insert into _c14 select 'anio', left(v, 4) from _c14 where k = 'mes';
-- el primer diciembre abierto cuyo enero siguiente también lo está (las pruebas de dos años)
insert into _c14
select 'dic', d.periodo from periodos d
  join periodos e on e.tipo = 'mes' and e.estado = 'abierto' and e.desde = d.hasta + 1
 where d.tipo = 'mes' and d.estado = 'abierto' and extract(month from d.desde) = 12
 order by d.desde limit 1;
insert into _c14 values ('libro_desde', fn_subs_libro_desde()::text);
insert into _c14 values ('hay_storage', (to_regclass('storage.objects') is not null and to_regclass('storage.buckets') is not null)::text);
-- (el banco de c6: lo que las pruebas usan de él para traer un movimiento, casarlo, clasificarlo y pagar a un proveedor)
insert into _c14 values ('hay_c6', (to_regclass('public.movimientos_banco') is not null
                                    and to_regproc('public.fn_banco_importar_filas') is not null and to_regproc('public.fn_banco_casar') is not null
                                    and to_regproc('public.fn_banco_pagar_proveedor') is not null
                                    and to_regproc('public.fn_banco_clasificar') is not null)::text);
insert into _c14 values ('hay_c8', (to_regclass('public.v_contador_control') is not null)::text);
insert into _c14 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
insert into _c14 values ('hay_c10', (to_regclass('public.jornal_repartos') is not null and to_regclass('public.v_jornal_control') is not null
                                     and to_regclass('public.v_margen_control') is not null)::text);
insert into _c14 values ('hay_c11', (to_regclass('public.v_emision_control') is not null)::text);
insert into _c14 values ('hay_c12', (to_regprocedure('public.fn_wip_control(text)') is not null)::text);
insert into _c14
select 'c9_subs', coalesce((select p.prosrc like '%fn_subs_cierre%' from pg_proc p
                             where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')), false)::text;
-- una tarjeta de la empresa (una subcuenta 2100-XXXX que reciba asientos), si la hay
insert into _c14
select 'tarjeta', c.codigo from cuentas c
 where left(c.codigo, 5) = '2100-' and c.tipo = 'pasivo' and c.imputable and coalesce((to_jsonb(c)->>'activa')::boolean, true)
 order by c.codigo limit 1;
grant select on _c14 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9, c10 y
-- c12), y ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c14(k text) returns text language sql as $$ select v from _c14 where k = $1 $$;
-- un día del mes de las pruebas (su día 1 + n, sin pasar de hoy) y el año de las pruebas
create or replace function pg_temp.c14_d(p_n int default 0) returns date language sql as $$
  select least(p.desde + p_n, greatest(pg_temp.c14('hoy')::date, p.desde)) from periodos p where p.periodo = pg_temp.c14('mes')
$$;
create or replace function pg_temp.c14_anio() returns int language sql as $$ select pg_temp.c14('anio')::int $$;

-- Las funciones que crea c14-subs.sql, por su nombre exacto (las 39). No se
-- buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c14_fn() returns text[] language sql immutable as $$
  select array['fn_subs_precondiciones', 'fn_subs_por_api', 'fn_subs_exigir_dueno', 'fn_subs_ve', 'fn_subs_exigir_codigo',
               'fn_subs_guarda', 'fn_subs_tin_forma', 'fn_subs_usd', 'fn_subs_lista', 'fn_subs_hoy', 'fn_subs_dia', 'fn_subs_libro_desde',
               'fn_subs_anios', 'fn_subs_umbral', 'fn_subs_mascara', 'fn_subs_tercero_nombre', 'fn_subs_cuenta_clase', 'fn_subs_storage',
               'fn_subs_mes', 'fn_subs_fichas', 'fn_subs_ficha', 'fn_subs_tramo_retirar', 'fn_subs_tercero', 'fn_subs_tin_guardar',
               'fn_subs_archivo', 'fn_subs_archivo_retirar', 'fn_subs_marcar', 'fn_subs_calculo', 'fn_subs_pagos', 'fn_subs_antes',
               'fn_subs_estado_al', 'fn_subs_1099', 'fn_subs_1099_export', 'fn_subs_config', 'fn_subs_umbral_confirmar', 'fn_subs_coi',
               'fn_subs_control', 'fn_subs_cierre', 'fn_subs_pegado']
$$;
create or replace function pg_temp.c14_tablas() returns text[] language sql immutable as $$
  select array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_tin', 'subs_archivos', 'subs_marcas',
               'subs_historial', 'subs_exportaciones', 'subs_tramos']
$$;
create or replace function pg_temp.c14_vistas() returns text[] language sql immutable as $$
  select array['v_subs_fichas', 'v_subs_archivos', 'v_subs_1099', 'v_subs_pagos', 'v_subs_coi', 'v_subs_control']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, con su código: aal2), el dueño sin su
-- código (dueno_aal1), anon o service_role.
create or replace function pg_temp.c14_ser(quien text) returns void language plpgsql as $$
declare
  v_id  text := pg_temp.c14(case when quien = 'dueno_aal1' then 'dueno' else quien end);
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

-- Lo que contesta una orden: 'ok' o su código de error (c14_estado); con su
-- mensaje (c14_dice); o lo que devuelve como texto (c14_da: su primera
-- columna, o el código si falla). Como quien se diga; al volver, el SQL
-- Editor.
create or replace function pg_temp.c14_estado(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c14_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := case when sqlstate = 'PGRST' then 'PGRST ' || coalesce(sqlerrm::json->>'code', '?') else sqlstate end;
  end;
  perform pg_temp.c14_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c14_dice(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c14_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  perform pg_temp.c14_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c14_da(p_sql text, p_quien text default 'dueno', p_marca boolean default false) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c14_ser(p_quien);
  begin
    if p_marca then   -- (la marca del TIN, puesta a mano ANTES de la orden: en la misma no la vería)
      perform set_config('mx_subs.tin', '1', true);
    end if;
    execute p_sql into v;
  exception when others then
    v := case when sqlstate = 'PGRST' then 'PGRST ' || coalesce(sqlerrm::json->>'code', '?') else sqlstate end;
  end;
  perform set_config('mx_subs.tin', '', true);
  perform pg_temp.c14_ser('editor');
  return v;
end $$;

-- LA CONFIGURACIÓN Y LOS UMBRALES, COMO DE FÁBRICA MIENTRAS DURA LA PRUEBA
-- (se deshace con ella). En la base real Edgar puede haber cambiado la
-- configuración (otro umbral, a quién no se le reporta, los días del COI, si
-- al exento de WC le basta su documento) o confirmado el umbral de un año en
-- otro monto, y lo que cada prueba espera está escrito con los valores de
-- fábrica. Las cuentas (las por pagar y las que no pagan a nadie) no se
-- tocan: son del plan de cada base. No crea umbrales: solo pone en 2000 los
-- ya confirmados en otro monto (el aviso «el umbral del año, confirmado»
-- sigue como estaba). Como el dueño por la API; si falla, la prueba lo dice.
create or replace function pg_temp.c14_fabrica() returns void language plpgsql as $$
declare
  v_y int;
begin
  if pg_temp.c14('dueno') is null then
    return;
  end if;
  perform pg_temp.c14_ser('dueno');
  perform public.fn_subs_config('{"umbral_1099": "2000", "entidades_no_reporta": ["s_corp", "c_corp"], "coi_aviso_dias": 30, '
                                '"coi_ventana_dias": 90, "coi_exento_basta": false}'::jsonb
                                -- (con qué fecha cuenta un pago y las cuentas que nunca son servicio, como nacen)
                                || case when exists (select 1 from information_schema.columns
                                                      where table_schema = 'public' and table_name = 'subs_config' and column_name = 'fecha_pago')
                                        then '{"fecha_pago": "contable", "cuentas_no_servicio": []}'::jsonb else '{}'::jsonb end);
  for v_y in select u.anio from public.subs_umbrales u
              where u.umbral <> 2000
                and u.anio between extract(year from public.fn_subs_libro_desde())::int and extract(year from public.fn_subs_hoy())::int + 1
              order by 1 loop
    perform public.fn_subs_umbral_confirmar(v_y, '2000', 'C14 PRUEBA: el de fábrica mientras dura la prueba');
  end loop;
  perform pg_temp.c14_ser('editor');
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): la configuración
-- y los umbrales como de fábrica, los puentes de c3 en «immediate» (un
-- trabajo externo entra al libro en el momento, como en c3-pruebas), las dos
-- obras, los tres proveedores y la persona de prueba.
create or replace function pg_temp.c14_sembrar(p_persona boolean default false) returns void language plpgsql as $$
declare
  v text;
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
begin
  perform pg_temp.c14_fabrica();
  perform pg_temp.c14_ser('editor');
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v is not null then
    execute 'set constraints ' || v || ' immediate';
  end if;
  insert into proyectos (id, tipo, nombre, estado) values
    ('c14-prueba-a', 'comercial', 'C14 PRUEBA Obra A', 'ejecucion'),
    ('c14-prueba-b', 'servicio',  'C14 PRUEBA Obra B', 'ejecucion');
  perform fn_proveedor_alta('ZZ Sub Uno C14 PRUEBA', null);
  perform fn_proveedor_alta('ZZ Sub Dos C14 PRUEBA', null);
  perform fn_proveedor_alta('ZZ Supply C14 PRUEBA', null);
  if p_persona then
    if v_meta then
      execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                     pg_temp.c14('p1'), 'c14-p1@c14-pruebas.invalid',
                     json_build_object('nombre', 'Zzeli C14 PRUEBA', 'name', 'Zzeli C14 PRUEBA', 'full_name', 'Zzeli C14 PRUEBA')::text);
    else
      execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                     pg_temp.c14('p1'), 'c14-p1@c14-pruebas.invalid');
    end if;
    insert into perfiles (id, nombre, rol, activo) values (pg_temp.c14('p1')::uuid, 'Zzeli C14 PRUEBA', 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end if;
end $$;
create or replace function pg_temp.c14_prov(p text) returns uuid language sql as $$
  select id from proveedores
   where nombre = case p when 'uno' then 'ZZ Sub Uno C14 PRUEBA' when 'dos' then 'ZZ Sub Dos C14 PRUEBA' else 'ZZ Supply C14 PRUEBA' end
$$;

-- ¿Se puede sembrar en esta base (también la persona)? Se prueba UNA vez,
-- antes de todo, y se deshace.
do $$
declare
  v text := 'ok'; w text := 'ok';
begin
  begin
    perform pg_temp.c14_sembrar(false);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v := sqlstate || ': ' || sqlerrm;
  end;
  begin
    perform pg_temp.c14_sembrar(true);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then w := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c14 values ('siembra', v), ('siembra_persona', w);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar; true si la puso)
create or replace function pg_temp.c14_omitir(p_n int, p_prueba text, p_esperado text, p_persona boolean default false,
                                              p_banco boolean default false)
returns boolean language plpgsql as $$
declare
  v text := case when pg_temp.c14('dueno') is null then 'no hay un dueño activo en perfiles'
                 when pg_temp.c14('mes') is null then 'no hay un mes abierto que ya haya empezado: no hay dónde postear un pago de prueba'
                 when pg_temp.c14('siembra') <> 'ok' then 'esta base no deja sembrar las obras y los proveedores de prueba (' || left(pg_temp.c14('siembra'), 300) || ')'
                 when p_persona and pg_temp.c14('siembra_persona') <> 'ok'
                   then 'esta base no deja crear la persona de prueba (' || left(pg_temp.c14('siembra_persona'), 300) || ')'
                 when p_banco and pg_temp.c14('hay_c6') <> 'true'
                   then 'el banco (c6) no está en esta base: no hay cómo traer un movimiento del banco ni pagar con él' end;
begin
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado, 'omitida: ' || v, null);
  return true;
end $$;

-- Como el dueño por la API (con su código): una ficha (devuelve su id), su
-- TIN, enlazar un tercero, una marca.
create or replace function pg_temp.c14_ficha(p jsonb) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_subs_ficha(p);
  perform pg_temp.c14_ser('editor');
  return (r->>'ficha_id')::uuid;
end $$;
-- (una ficha COMPLETA de un proveedor de prueba: nombre legal, tipo, dirección, «sí se reporta»; sin TIN ni W-9)
create or replace function pg_temp.c14_ficha_de(p_prov text, p_extra jsonb default '{}'::jsonb) returns uuid language sql as $$
  select pg_temp.c14_ficha(jsonb_build_object(
           'nombre_legal', 'ZZ ' || initcap(p_prov) || ' Legal C14 PRUEBA', 'tipo_entidad', 'llc_un_socio', 'reporta', 'si',
           'direccion', '1 Calle Falsa', 'ciudad', 'Ocala', 'estado', 'FL', 'zip', '34470',
           'tercero', jsonb_build_object('tipo', 'proveedor', 'id', pg_temp.c14_prov(p_prov))) || p_extra)
$$;
create or replace function pg_temp.c14_tin(p_ficha uuid, p_tin text, p_tipo text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_subs_tin_guardar(p_ficha, jsonb_strip_nulls(jsonb_build_object('tin', p_tin, 'tipo', p_tipo)));
  perform pg_temp.c14_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c14_marcar(p_asiento uuid, p_orden int, p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_subs_marcar(p_asiento, p_orden, p);
  perform pg_temp.c14_ser('editor');
  return r;
end $$;

-- UN ASIENTO A MANO, como el dueño (fn_postear). p_dia: el día del mes de
-- las pruebas (su día 1 + n), o una fecha. Devuelve su id.
create or replace function pg_temp.c14_postear(p_fecha date, p_desc text, p_lineas jsonb, p_extra jsonb default '{}'::jsonb)
returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_postear(jsonb_build_object('fecha', p_fecha::text, 'descripcion', 'C14 PRUEBA: ' || p_desc || ' (se deshace)',
                                     'lineas', p_lineas) || p_extra);
  perform pg_temp.c14_ser('editor');
  return (r->>'id')::uuid;
end $$;
-- (una línea: cuenta, monto, y lo que lleve: obra, tercero, partida)
create or replace function pg_temp.c14_l(p_cuenta text, p_monto numeric, p_obra text default null, p_tt text default null,
                                         p_ti uuid default null, p_pt text default null, p_pi text default null)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('cuenta', p_cuenta, 'monto', p_monto::text, 'proyecto_id', p_obra,
                                              'tercero_tipo', p_tt, 'tercero_id', p_ti::text, 'partida_tabla', p_pt, 'partida_id', p_pi))
$$;
-- UN PAGO DIRECTO a mano: Dr 5200 (obra A, con su tercero si se da) / Cr la cuenta de pago (el banco, 1010, si no se dice).
create or replace function pg_temp.c14_directo(p_fecha date, p_monto numeric, p_tt text default null, p_ti uuid default null,
                                               p_paga text default '1010', p_desc text default 'pago directo')
returns uuid language sql as $$
  select pg_temp.c14_postear(p_fecha, p_desc, jsonb_build_array(pg_temp.c14_l('5200', p_monto, 'c14-prueba-a', p_tt, p_ti),
                                                               pg_temp.c14_l(p_paga, -p_monto)))
$$;

-- UN TRABAJO EXTERNO por el puente de c3 (como el SQL Editor): entra al
-- libro al insertarlo (Dr 5200 / Cr 2010 con su partida y su proveedor).
-- Devuelve su id (−1400000 − n).
create or replace function pg_temp.c14_externo(p_n int, p_costo numeric, p_fecha date, p_prov uuid) returns bigint language plpgsql as $$
declare
  v_id bigint := -(1400000 + p_n);
begin
  perform pg_temp.c14_ser('editor');
  insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, costo, proveedor_id) overriding system value
  values (v_id, 'c14-prueba-a', 'C14 PRUEBA trabajo ' || p_n, p_fecha, 'ajuste', p_costo, p_prov);
  if p_fecha >= pg_temp.c14('libro_desde')::date
     and not exists (select 1 from trabajos_externos t where t.id = v_id and t.contabilizado_en is not null) then
    raise exception 'c14-pruebas: el puente de trabajos externos no contabilizó el trabajo de prueba %', v_id;
  end if;
  return v_id;
end $$;

-- UN MOVIMIENTO DEL BANCO como lo trae Plaid (en nombre del dueño) y «Casar»
-- solo para él: sin ticket ni asiento que lo explique, queda en la Bandeja.
-- p_monto en positivo = lo que salió. Devuelve el movimiento.
create or replace function pg_temp.c14_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text, p_cuenta text default '1010')
returns uuid language plpgsql as $$
declare
  v_mov uuid;
begin
  if p_desc !~ 'C14 PRUEBA' then
    raise exception 'c14-pruebas: la descripción de un movimiento de prueba lleva «C14 PRUEBA» (%)', p_desc;
  end if;
  perform pg_temp.c14_ser('dueno');
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', p_cuenta, 'nombre', 'Plaid · c14-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object('id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text,
                                                  'descripcion', p_desc, 'tipo', 'DEBIT', 'pendiente', false))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform pg_temp.c14_ser('editor');
  if not exists (select 1 from movimientos_banco m where m.id = v_mov and m.estado = 'pendiente') then
    raise exception 'c14-pruebas: el movimiento de prueba % casó solo con algo del libro (¿un monto real igual?)', p_id;
  end if;
  return v_mov;
end $$;
-- EL PAGO A UN PROVEEDOR por el banco (c6: a lo que se le debe, lo más viejo primero). Devuelve el asiento.
create or replace function pg_temp.c14_pagar(p_mov uuid, p_prov uuid) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_banco_pagar_proveedor(p_mov, p_prov, jsonb_build_object('motivo', 'C14 PRUEBA: pago de prueba', 'partidas', null));
  perform pg_temp.c14_ser('editor');
  return (r->>'asiento_id')::uuid;
end $$;
-- CLASIFICAR un movimiento del banco (c6), con su motivo. Devuelve el asiento.
create or replace function pg_temp.c14_clasificar(p_mov uuid, p_lineas jsonb) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c14_ser('dueno');
  r := fn_banco_clasificar(p_mov, p_lineas, 'C14 PRUEBA: clasificado de prueba');
  perform pg_temp.c14_ser('editor');
  return (select m.asiento_id from movimientos_banco m where m.id = p_mov);
end $$;

-- LA FILA DEL 1099 de una ficha (o de una clave) en un año, en una línea
-- (como el dueño por la API).
create or replace function pg_temp.c14_fila(p_ficha uuid, p_anio int default null, p_clave text default null) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c14_ser('dueno');
  select format('servicio %s, tarjeta %s, sin clasificar %s, no servicio %s | %s: reportable %s, excluido %s%s | pasa %s | falta {%s} | listo %s',
                r.pagado_servicio::numeric(14,2), r.pagado_tarjeta::numeric(14,2), r.sin_clasificar::numeric(14,2),
                r.no_servicio::numeric(14,2), r.reporta_efectivo, r.reportable::numeric(14,2), r.excluido::numeric(14,2),
                coalesce(' (' || (select string_agg(e->>'motivo', ', ') from jsonb_array_elements(r.excluido_por) e) || ')', ''),
                case when r.pasa_umbral then 'sí' else 'no' end, array_to_string(r.falta, ','), case when r.listo then 'sí' else 'no' end)
    into v
    from fn_subs_1099(coalesce(p_anio, pg_temp.c14_anio())) r
   where ((p_clave is null and r.ficha_id = p_ficha) or r.clave = p_clave)
     and exists (select 1 from jsonb_array_elements(r.pagos) x where x->>'medio' in ('efectivo', 'tarjeta'));
  -- (quien sale SIN nada pagado: solo con servicio devengado contra una cuenta por pagar, o saldado por otro camino)
  if v is null then
    select format('sin pagos (devengado %s, por otro camino %s)', (to_jsonb(r)->>'devengado')::numeric(14,2),
                  (to_jsonb(r)->>'otro_camino')::numeric(14,2)) into v
      from fn_subs_1099(coalesce(p_anio, pg_temp.c14_anio())) r
     where (p_clave is null and r.ficha_id = p_ficha) or r.clave = p_clave;
  end if;
  perform pg_temp.c14_ser('editor');
  return coalesce(v, 'no sale');
end $$;
-- LAS PARTES de los pagos de una ficha en un año: via medio clase monto | … (en su orden)
create or replace function pg_temp.c14_partes(p_ficha uuid, p_anio int default null) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c14_ser('dueno');
  select string_agg(format('%s %s %s %s', p.via, p.medio, p.clase, p.monto), ' | ' order by p.fecha, p.numero, p.orden, p.medio, p.clase)
    into v
    from fn_subs_pagos(coalesce(p_anio, pg_temp.c14_anio())) p
   where p.ficha_id = p_ficha;
  perform pg_temp.c14_ser('editor');
  return coalesce(v, '-');
end $$;
-- Una fila del control de los subs del año de las pruebas: 'verde' o 'rojo', y su detalle (como el SQL Editor).
create or replace function pg_temp.c14_ctl(p_orden int, p_anio int default null) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from fn_subs_control(coalesce(p_anio, pg_temp.c14_anio())) c where c.orden = p_orden
$$;
create or replace function pg_temp.c14_ctl_det(p_orden int, p_anio int default null) returns text language sql as $$
  select c.detalle from fn_subs_control(coalesce(p_anio, pg_temp.c14_anio())) c where c.orden = p_orden
$$;
-- ¿El detalle de un control NOMBRA algo (un patrón de LIKE)? Con los datos reales la lista de un control puede no caber
-- entera en su detalle: entonces acaba en «… y N más» (fn_subs_lista) y lo de la prueba —que se llama «ZZ…» y va al final, o
-- es lo último del mes— puede haber quedado fuera. En ese caso no se puede leer ahí y se da por nombrado: que está en rojo y
-- que el dato está donde debe ya lo mira cada prueba por su lado (su fila del 1099, sus pagos, su COI).
create or replace function pg_temp.c14_nombra(p_detalle text, p_patron text) returns boolean language sql immutable as $$
  select coalesce(p_detalle like p_patron or p_detalle ~ '; … y [0-9]+ más', false)
$$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los estados
-- (c4), los cuadres de la IA (c8), los del jornal y del margen (c10), los de
-- las facturas (c11), los del WIP (c12) y lo que detiene el cierre del mes de
-- las pruebas (c9); cada una, si está. Como el SQL Editor.
create or replace function pg_temp.c14_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c14_ser('editor');
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
  end if;
  if pg_temp.c14('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c14('hay_c10') = 'true' then
    execute $q$ select coalesce(array_agg('c10: ' || k.c order by k.c), '{}')
                  from (select 'jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                        union all
                        select 'margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c14('hay_c11') = 'true' then
    execute $q$ select coalesce(array_agg('c11: ' || k.orden order by k.orden), '{}')
                  from public.v_emision_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c14('hay_c12') = 'true' and pg_temp.c14('mes') is not null then
    execute $q$ select coalesce(array_agg('c12: ' || k.orden order by k.orden), '{}')
                  from public.fn_wip_control($1) k where k.nivel = 'cuadre' and not k.ok $q$ into x using pg_temp.c14('mes');
    v := v || x;
  end if;
  if pg_temp.c14('hay_c9') = 'true' and pg_temp.c14('mes') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k
                 where k.nivel = 'detiene' and k.ok is distinct from true $q$
       into x using pg_temp.c14('mes');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c14_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- Lo que hay en lo que c14 toca y en lo que sus pruebas siembran (la 47 lo compara, y la 48 otra vez)
create or replace function pg_temp.c14_mov_banco() returns bigint language plpgsql as $$
declare
  n bigint := 0;
begin
  if to_regclass('public.movimientos_banco') is not null then
    execute 'select count(*) from public.movimientos_banco' into n;
  end if;
  return n;
end $$;
-- (la revisión guardada del cierre —c9—, si está: su huella. Estas pruebas no la reescriben.)
create or replace function pg_temp.c14_revisiones() returns text language plpgsql as $$
declare
  v text := 'no hay';
begin
  if to_regclass('public.cierre_revisiones') is not null then
    execute 'select md5(coalesce(string_agg(md5(r::text), '''' order by md5(r::text)), '''')) from public.cierre_revisiones r' into v;
  end if;
  return v;
end $$;
create or replace function pg_temp.c14_tramos() returns bigint language plpgsql as $$
declare
  n bigint := 0;
begin
  if to_regclass('public.subs_tramos') is not null then
    execute 'select count(*) from public.subs_tramos' into n;
  end if;
  return n;
end $$;
create or replace function pg_temp.c14_conteos() returns text language sql as $$
  select format('config %s · umbrales %s · fichas %s · tramos %s · revisiones del cierre %s · terceros %s · tin %s · archivos %s · marcas %s · historial %s · exportaciones %s · '
                'asientos %s · líneas del libro %s · contadores %s · proveedores %s · perfiles %s · externos %s (%s contabilizados) · '
                'movimientos del banco %s · obras %s · cerrados %s · objetos en el bucket %s · el reloj %s · funciones %s',
                (select md5(to_jsonb(c)::text) from subs_config c where c.id = 1), (select count(*) from subs_umbrales),
                (select count(*) from subs_fichas), pg_temp.c14_tramos(), pg_temp.c14_revisiones(),
                (select count(*) from subs_terceros), (select count(*) from subs_tin),
                (select count(*) from subs_archivos), (select count(*) from subs_marcas), (select count(*) from subs_historial),
                (select count(*) from subs_exportaciones), (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from proveedores), (select count(*) from perfiles),
                (select count(*) from trabajos_externos), (select count(*) from trabajos_externos where contabilizado_en is not null),
                pg_temp.c14_mov_banco(), (select count(*) from proyectos),
                (select count(*) from periodos where estado = 'cerrado'), (select count(*) from fn_subs_storage()),
                left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c14 values ('conteos', pg_temp.c14_conteos());
-- (el reloj DE VERDAD, tal cual está al empezar: si una prueba lo dejara fingido —no pasa: cada una lo deshace con su
-- subtransacción—, el final de este archivo lo restaura y lo dice como un fallo)
insert into _c14 select 'reloj_def', pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure);
-- (LO MISMO, SIN DEJAR NADA: la revisión del cierre de c9 guarda lo que encuentra en su tabla, con su hora. Se lee dentro
-- de un bloque que se deshace: estas pruebas no dejan nada, ni eso.)
create or replace function pg_temp.c14_rojos_limpio() returns text[] language plpgsql as $$
declare
  v text[];
begin
  begin
    v := pg_temp.c14_rojos();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null;
  end;
  return v;
end $$;
-- (lo de las otras capas que ya estaba en rojo ANTES de las pruebas: la última lo dice y no lo cuenta)
insert into _c14 select 'rojos_antes', array_to_string(pg_temp.c14_rojos_limpio(), '; ');
-- (los cuadres del propio control de los subs que ya estaban en rojo con los datos de esta base)
insert into _c14
select 'rojos_subs', coalesce(string_agg(k.orden::text, ',' order by k.orden), '')
  from fn_subs_control(pg_temp.c14_anio()) k where k.nivel = 'cuadre' and not k.ok;
create or replace function pg_temp.c14_propios() returns text language sql as $$
  select coalesce(nullif((select string_agg(k.orden::text, ',' order by k.orden)
                            from fn_subs_control(pg_temp.c14_anio()) k
                           where k.nivel = 'cuadre' and not k.ok
                             and not (k.orden::text = any (string_to_array(pg_temp.c14('rojos_subs'), ',')))), ''), 'nada nuevo en rojo')
$$;
-- (las funciones AJENAS a c14 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 48
-- las dicen y no las cuentan como fallo de c14.)
create or replace function pg_temp.c14_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c14
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c14_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c14: %';
create or replace function pg_temp.c14_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c14_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c14('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c14_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;

-- EL RELOJ FINGIDO (el de c2-pruebas, c11-pruebas y c12-pruebas): «hoy» pasa
-- a ser esa fecha (o el hoy de verdad, si es posterior). Solo DENTRO de la
-- subtransacción de una prueba: su MXT00 lo deshace.
create or replace function pg_temp.c14_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;

-- UN OBJETO EN EL BUCKET «subs», como quien se diga (lo que hace la app al
-- subir): 'ok' o el código del error. Y un sha256 de mentira con buena forma.
create or replace function pg_temp.c14_subir(p_ruta text, p_bytes bigint, p_quien text default 'dueno') returns text language sql as $$
  select pg_temp.c14_estado(format('insert into storage.objects (bucket_id, name, owner, metadata) values (''subs'', %L, %L, %L::jsonb)',
                                   p_ruta, pg_temp.c14(case when p_quien = 'dueno_aal1' then 'dueno' else p_quien end),
                                   json_build_object('size', p_bytes)::text), p_quien)
$$;
create or replace function pg_temp.c14_sha(p text) returns text language sql immutable as $$
  select encode(sha256(convert_to(p, 'UTF8')), 'hex')
$$;
-- (registrar un archivo de una ficha, como el dueño: lo sube antes si la base tiene Storage)
create or replace function pg_temp.c14_archivo(p_ficha uuid, p_clase text, p_nombre text, p_extra jsonb default '{}'::jsonb)
returns jsonb language plpgsql as $$
declare
  v_ruta text := p_ficha::text || '/' || p_clase || '/' || p_nombre;
  r jsonb;
begin
  if pg_temp.c14('hay_storage') = 'true' then
    if pg_temp.c14_subir(v_ruta, 1234) <> 'ok' then
      raise exception 'c14-pruebas: no se pudo subir % al bucket subs', v_ruta;
    end if;
  end if;
  perform pg_temp.c14_ser('dueno');
  r := fn_subs_archivo(p_ficha, jsonb_build_object('clase', p_clase, 'ruta', v_ruta, 'sha256', pg_temp.c14_sha(v_ruta), 'bytes', 1234) || p_extra);
  perform pg_temp.c14_ser('editor');
  return r;
end $$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, las 39 funciones por su
--    nombre exacto, la configuración (una fila) y cada objeto con su
--    comentario «c14: …».
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 10 tablas | 6 vistas | 39 funciones (39 nombres) | sin comentario c14: ninguno | configuración: 1 fila, id 1';
begin
  begin
    perform pg_temp.c14_ser('editor');
    v_pre := coalesce(fn_subs_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c14_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c14_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and proname = any (pg_temp.c14_fn());
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c14_tablas()) or c.relname = any (pg_temp.c14_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c14: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c14_fn())
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c14: %') x;
    select format('%s fila, id %s', count(*), min(c.id)) into v_cfg from subs_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c14: %s | configuración: %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 10 tablas, 6 vistas, las 39 funciones por su nombre exacto, la configuración (una fila) y cada objeto con su comentario «c14: …»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c2 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c14
--    que no lleva su comentario (no es de c14: no se pisa); una vista ajena
--    colgada de una vista de c14 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin la marca del libro: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    v_a := pg_temp.c14_estado('select public.fn_subs_precondiciones()', 'dueno');
    begin
      drop function public.fn_libro_version();
      v_b := coalesce(fn_subs_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_subs_usd(numeric) is 'otra cosa';
      v_c := coalesce(fn_subs_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.zz_c14_colgada as select f.ficha_id from public.v_subs_fichas f;
      v_d := coalesce(fn_subs_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin la marca del libro: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%falta fn_libro_version()%' then 'la nombra' else 'no: ' || v_b end,
                    case when v_c like '%con nombre de c14 y sin ser de c14: la función fn_subs_usd(numeric)%No lo piso%' then 'la nombra y no la pisa'
                         else 'no: ' || v_c end,
                    case when v_d like '%la vista zz_c14_colgada depende(n) de las vistas de c14%' then 'la nombra' else 'no: ' || v_d end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se instala (42501); sin una función de c2 la nombra; una función con nombre de c14 que no es de c14 no se pisa; una vista ajena colgada de las de c14 se dice antes de borrarla',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. LA API. anon y service_role: ningún privilegio en las tablas ni en las
--    vistas, y ninguna función. El equipo: cero filas en todo, y 42501 en lo
--    que escribe o exporta. El dueño entra y ve.
do $$
declare
  v_obt text; v_f uuid; v_a text; v_b text; v_c text; v_d text; v_e text; v_n int; v_m int; t text; r text;
  v_esp text := 'anon: 16 de 16 relaciones con 42501, 0 funciones | service_role: 16 de 16 relaciones con 42501, 0 funciones | el equipo: '
                'cero filas en las 10 tablas y las 6 vistas; el 1099, el control y el COI, vacíos; dar de alta 42501, guardar un TIN '
                '42501, exportar 42501, configurar 42501, marcar 42501 | el dueño: ve su ficha (1), su TIN con máscara, y el control '
                'responde con 18 filas';
begin
  if pg_temp.c14_omitir(3, 'la API', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_f, '000-00-0001');
    foreach r in array array['anon', 'service_role'] loop
      v_n := 0;
      foreach t in array pg_temp.c14_tablas() || pg_temp.c14_vistas() loop
        if pg_temp.c14_estado('select count(*) from public.' || t, r) = '42501' then v_n := v_n + 1; end if;
      end loop;
      select count(*) into v_m from pg_proc p
       where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c14_fn()) and has_function_privilege(r, p.oid, 'execute');
      if r = 'anon' then v_a := format('%s de 16 relaciones con 42501, %s funciones', v_n, v_m);
      else v_b := format('%s de 16 relaciones con 42501, %s funciones', v_n, v_m); end if;
    end loop;
    v_n := 0;
    foreach t in array pg_temp.c14_tablas() || pg_temp.c14_vistas() loop
      -- (subs_config tiene su fila, y el equipo tampoco la ve)
      if pg_temp.c14_da('select count(*)::text from public.' || t, 'equipo') = '0' then v_n := v_n + 1; end if;
    end loop;
    v_c := format('%s en las 10 tablas y las 6 vistas; el 1099, el control y el COI, %s; dar de alta %s, guardar un TIN %s, exportar %s, '
                  'configurar %s, marcar %s',
                  case when v_n = 16 then 'cero filas' else v_n || ' de 16 con cero filas' end,
                  case when pg_temp.c14_da(format('select count(*)::text from public.fn_subs_1099(%s)', pg_temp.c14_anio()), 'equipo') = '0'
                            and pg_temp.c14_da('select count(*)::text from public.fn_subs_control(null)', 'equipo') = '0'
                            and pg_temp.c14_da('select count(*)::text from public.fn_subs_coi(null, null, null)', 'equipo') = '0'
                            and pg_temp.c14_da('select count(*)::text from public.fn_subs_fichas(null)', 'equipo') = '0'
                            and pg_temp.c14_da('select count(*)::text from public.fn_subs_calculo()', 'equipo') = '0'
                       then 'vacíos' else 'NO vacíos' end,
                  pg_temp.c14_estado('select public.fn_subs_ficha(''{"nombre_legal": "ZZ Intruso C14 PRUEBA"}''::jsonb)', 'equipo'),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0002"}''::jsonb)', v_f), 'equipo'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'equipo'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"umbral_1099": "1"}''::jsonb)', 'equipo'),
                  pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"trato": "servicio", "nota": "x"}''::jsonb)', gen_random_uuid()), 'equipo'));
    v_d := format('ve su ficha (%s), su TIN %s, y el control responde con %s filas',
                  pg_temp.c14_da(format('select count(*)::text from public.v_subs_fichas where ficha_id = %L', v_f)),
                  case when pg_temp.c14_da(format('select tin_mascara from public.v_subs_fichas where ficha_id = %L', v_f)) = '***-**-0001'
                       then 'con máscara' else 'SIN máscara' end,
                  pg_temp.c14_da('select count(*)::text from public.v_subs_control'));
    v_obt := format('anon: %s | service_role: %s | el equipo: %s | el dueño: %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'LA API: anon y service_role no tienen ningún privilegio en las 10 tablas ni en las 6 vistas ni ejecutan ninguna función; el equipo ve cero filas en todo (también con una ficha y un TIN puestos) y recibe 42501 al dar de alta, guardar un TIN, exportar, configurar o marcar; el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. EL CATÁLOGO: ninguna función SECURITY DEFINER; ningún nombre con un
--    prefijo de otra capa ni de la otra sesión (en LIKE el «_» es comodín);
--    RLS y las policies justas (el TIN: dos, una restrictiva, las dos con el
--    dueño, su código y la marca); vistas security_invoker; nada colgado de
--    contratistas (los clientes); y «permisos» de c2 en verde con c14 pegado.
do $$
declare
  v_obt text; v_def text; v_pre text; v_rls text; v_pol text; v_tin text; v_vis text; v_con text;
  v_esp text := 'definer: ninguna | prefijos de otra capa: ninguno | RLS en las 10 | policies: subs_archivos 3, subs_config 2, '
                'subs_exportaciones 2, subs_fichas 3, subs_historial 2, subs_marcas 3, subs_terceros 3, subs_tin 2, subs_tramos 3, subs_umbrales 3 | '
                'el TIN: 2 policies (1 restrictiva), las dos con el dueño, su código y la marca | vistas security_invoker: 6 de 6 | '
                'llaves hacia contratistas: ninguna | permisos (c2): verde';
begin
  begin
    perform pg_temp.c14_ser('editor');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c14_fn()) and p.prosecdef;
    select coalesce(string_agg(x.n || ' ~ ' || y.pref, ', '), 'ninguno') into v_pre
      from unnest(pg_temp.c14_fn() || pg_temp.c14_tablas() || pg_temp.c14_vistas()) x(n)
      join unnest(array['fn_banco_', 'fn_puente_', 'fn_estados_', 'fn_stripe_', 'fn_plaid_', 'fn_contador_', 'fn_cierre_', 'fn_costos_',
                        'fn_reporte_', 'fn_reparto_fase', 'fn_horas_', 'fn_jornal_', 'fn_margen_', 'fn_cobro_', 'fn_factura_',
                        'fn_anticipo_', 'fn_doc_', 'fn_qb_', 'fn_emision_', 'fn_wip_', 'fn_cedula_', 'cxc_', 'v_cxc_', 'cedula_',
                        'v_cedula_']) y(pref)
        on x.n like y.pref || '%';
    select case when count(*) filter (where c.relrowsecurity) = 10 then 'RLS en las 10' else 'RLS en ' || count(*) filter (where c.relrowsecurity) end
      into v_rls from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c14_tablas());
    select string_agg(z.t || ' ' || z.n, ', ' order by z.t) into v_pol
      from (select pl.tablename as t, count(*) as n from pg_policies pl
             where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c14_tablas()) group by pl.tablename) z;
    select format('%s policies (%s restrictiva), %s', count(*), count(*) filter (where not pl.polpermissive),
                  case when bool_and(pg_get_expr(pl.polqual, pl.polrelid) like '%es_dueno%' and pg_get_expr(pl.polqual, pl.polrelid) like '%aal2%'
                                     and pg_get_expr(pl.polqual, pl.polrelid) like '%mx_subs.tin%'
                                     and pg_get_expr(pl.polwithcheck, pl.polrelid) like '%es_dueno%'
                                     and pg_get_expr(pl.polwithcheck, pl.polrelid) like '%aal2%'
                                     and pg_get_expr(pl.polwithcheck, pl.polrelid) like '%mx_subs.tin%')
                       then 'las dos con el dueño, su código y la marca' else 'ALGUNA SIN el dueño, su código o la marca' end)
      into v_tin from pg_policy pl where pl.polrelid = 'public.subs_tin'::regclass;
    select format('%s de 6', count(*) filter (where c.reloptions @> array['security_invoker=true'])) into v_vis
      from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c14_vistas()) and c.relkind = 'v';
    select coalesce(string_agg(k.conname, ', '), 'ninguna') into v_con
      from pg_constraint k
     where k.contype = 'f' and k.confrelid = to_regclass('public.contratistas')
       and k.conrelid in (select c.oid from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c14_tablas()));
    v_obt := format('definer: %s | prefijos de otra capa: %s | %s | policies: %s | el TIN: %s | vistas security_invoker: %s | llaves hacia '
                    'contratistas: %s | permisos (c2): %s', v_def, v_pre, v_rls, v_pol, v_tin, v_vis, v_con, pg_temp.c14_permisos());
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'EL CATÁLOGO: ninguna función de c14 es SECURITY DEFINER; ningún nombre lleva un prefijo de otra capa ni de la otra sesión; RLS en las 10 tablas con las policies justas (el TIN: dos, una restrictiva, las dos con el dueño, su código del teléfono y la marca); las 6 vistas son security_invoker; nada cuelga de contratistas (los clientes); y «permisos» de c2 sigue en verde',
    v_esp, v_obt || case when pg_temp.c14('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c14: ' || pg_temp.c14('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 5. LA GUARDA. A mano no se escribe: ni el dueño por la API, ni el SQL
--    Editor sin la marca (MX003). Nada se trunca. Lo que es rastro no se
--    edita ni se borra ni con la marca. Y un TIN con mala forma no entra ni
--    con la marca (MX005), con un mensaje que no lo repite.
do $$
declare
  v_obt text; v_f uuid; v_a text; v_b text; v_c text; v_d text; v_e text; v_arch uuid; v_m text;
  v_esp text := 'el dueño por la API, a mano: alta MX003, cambio MX003, borrado MX003, la configuración MX003 | el SQL Editor sin la '
                'marca: MX003; truncar: MX003 | con la marca: borrar una ficha MX003, editar el historial MX003, cambiar un archivo '
                'MX003, retirarlo una vez ok y otra vez MX003 | un TIN con mala forma, con la marca: MX005, y el mensaje no lo repite';
begin
  if pg_temp.c14_omitir(5, 'la guarda de las tablas', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_arch := (pg_temp.c14_archivo(v_f, 'w9', 'w9.pdf')->'archivo'->>'id')::uuid;
    v_a := format('alta %s, cambio %s, borrado %s, la configuración %s',
                  pg_temp.c14_estado('insert into public.subs_fichas (nombre_legal) values (''ZZ A Mano C14 PRUEBA'')'),
                  pg_temp.c14_estado(format('update public.subs_fichas set reporta = ''no'' where id = %L', v_f)),
                  pg_temp.c14_estado(format('delete from public.subs_terceros where ficha_id = %L', v_f)),
                  pg_temp.c14_estado('update public.subs_config set umbral_1099 = 1 where id = 1'));
    v_b := format('%s; truncar: %s',
                  pg_temp.c14_estado(format('update public.subs_fichas set reporta = ''no'' where id = %L', v_f), 'editor'),
                  pg_temp.c14_estado('truncate public.subs_historial', 'editor'));
    perform set_config('mx_subs.escribe', 'subs_fichas', true);
    v_c := 'borrar una ficha ' || pg_temp.c14_estado(format('delete from public.subs_fichas where id = %L', v_f), 'editor');
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    v_c := v_c || ', editar el historial ' || pg_temp.c14_estado(format('update public.subs_historial set que = ''cambio'' where ficha_id = %L', v_f), 'editor');
    perform set_config('mx_subs.escribe', 'subs_archivos', true);
    v_c := v_c || ', cambiar un archivo ' || pg_temp.c14_estado(format('update public.subs_archivos set bytes = 1 where id = %L', v_arch), 'editor');
    perform set_config('mx_subs.escribe', '', true);
    v_c := v_c || ', retirarlo una vez ' || pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: mal subido'')', v_arch));
    perform set_config('mx_subs.escribe', 'subs_archivos', true);
    v_c := v_c || ' y otra vez ' || pg_temp.c14_estado(format('update public.subs_archivos set retirado_el = now(), retirado_motivo = ''otra'' where id = %L', v_arch), 'editor');
    perform set_config('mx_subs.escribe', 'subs_tin', true);
    v_m := pg_temp.c14_dice(format('insert into public.subs_tin (ficha_id, tin) values (%L, ''98765432X'')', v_f), 'editor');
    perform set_config('mx_subs.escribe', '', true);
    v_d := format('%s, y el mensaje %s', left(v_m, 5), case when v_m like '%98765432%' then 'LO REPITE' else 'no lo repite' end);
    v_obt := format('el dueño por la API, a mano: %s | el SQL Editor sin la marca: %s | con la marca: %s | un TIN con mala forma, con la '
                    'marca: %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'LA GUARDA: las tablas de c14 no se escriben a mano (MX003: ni el dueño por la API, ni el SQL Editor sin la marca), no se truncan, y lo que es rastro (una ficha, el historial, un archivo) no se borra ni se edita ni con la marca: un archivo solo queda retirado, una vez; y un TIN con mala forma no entra ni con la marca (MX005), con un mensaje que no lo repite',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. LA CONFIGURACIÓN Y EL UMBRAL. Lo que no viene no cambia; cada cambio
--    queda en el historial; sus frenos. El umbral de un año, confirmado con
--    su nota, manda sobre el de fábrica; otro lo sustituye y el anterior
--    queda.
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text; v_j jsonb; v_y int := pg_temp.c14_anio(); v_h0 bigint;
  v_esp text := 'cambia el umbral y los días (lo demás, igual): sí; en el historial: 1 cambio, con lo de antes y lo de después | frenos: '
                'clave desconocida 22023, umbral negativo MX005, con tres decimales MX005, una cuenta que no existe MX004, una entidad '
                'que no existe 22023, 999 días MX005, exento que no es sí o no 22023 | el umbral del año: sin nota 22023, un año de '
                'antes del libro 22023, un monto que no lo es MX005; confirmado en 600.00, el año usa 600.00 y un año sin confirmar '
                '2500.00; otro (650.00) lo sustituye y el anterior queda en su historial: sí';
begin
  if pg_temp.c14('dueno') is null then
    insert into _pruebas values (6, 'la configuración y el umbral', v_esp, 'omitida: no hay un dueño activo en perfiles', null); return;
  end if;
  begin
    perform pg_temp.c14_ser('editor');
    select count(*) into v_h0 from subs_historial where que = 'config';
    -- (parte de la configuración de fábrica, esté como esté en esta base; las cuentas no se tocan: son del plan de cada base)
    perform pg_temp.c14_fabrica();
    select count(*) into v_h0 from subs_historial where que = 'config';
    perform pg_temp.c14_ser('dueno');
    v_j := fn_subs_config('{"umbral_1099": "2500.00", "coi_aviso_dias": 45}'::jsonb);
    perform pg_temp.c14_ser('editor');
    v_a := format('%s; en el historial: %s cambio, %s',
                  case when v_j->>'umbral_1099' = '2500.00' and v_j->>'coi_aviso_dias' = '45' and v_j->>'coi_ventana_dias' = '90'
                            and v_j->'entidades_no_reporta' = '["c_corp", "s_corp"]'::jsonb and (v_j->>'coi_exento_basta')::boolean is false
                       then 'sí' else 'no: ' || v_j::text end,
                  (select count(*) - v_h0 from subs_historial where que = 'config'),
                  (select case when h.antes = '{"umbral_1099": 2000.00, "coi_aviso_dias": 30}'::jsonb
                                    and h.despues = '{"umbral_1099": 2500.00, "coi_aviso_dias": 45}'::jsonb
                               then 'con lo de antes y lo de después' else 'no: ' || h.antes::text || ' → ' || h.despues::text end
                     from subs_historial h where h.que = 'config' order by h.hecho_el desc limit 1));
    v_b := format('clave desconocida %s, umbral negativo %s, con tres decimales %s, una cuenta que no existe %s, una entidad que no existe '
                  '%s, 999 días %s, exento que no es sí o no %s',
                  pg_temp.c14_estado('select public.fn_subs_config(''{"umbral": "5"}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"umbral_1099": "-1"}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"umbral_1099": "600.005"}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"cuentas_por_pagar": ["2010", "ZZ99"]}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"entidades_no_reporta": ["marciano"]}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"coi_aviso_dias": 999}''::jsonb)'),
                  pg_temp.c14_estado('select public.fn_subs_config(''{"coi_exento_basta": "quizá"}''::jsonb)'));
    v_c := format('sin nota %s, un año de antes del libro %s, un monto que no lo es %s',
                  pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''600'', '' '')', v_y)),
                  pg_temp.c14_estado('select public.fn_subs_umbral_confirmar(2019, ''600'', ''C14 PRUEBA'')'),
                  pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''seiscientos'', ''C14 PRUEBA'')', v_y)));
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''600'', ''C14 PRUEBA: lo dijo el CPA'')', v_y));
    v_d := format('confirmado en 600.00, el año usa %s y un año sin confirmar %s', fn_subs_umbral(v_y),
                  fn_subs_umbral((select g from generate_series(2030, 2100) g where not exists (select 1 from subs_umbrales u where u.anio = g) limit 1)));
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''650.00'', ''C14 PRUEBA: corregido'')', v_y));
    v_d := v_d || format('; otro (%s) lo sustituye y el anterior queda en su historial: %s', fn_subs_umbral(v_y),
                         (select case when u.historial->-1->>'umbral' = '600.00' and u.historial->-1->>'nota' = 'C14 PRUEBA: lo dijo el CPA'
                                      then 'sí' else 'no: ' || u.historial::text end from subs_umbrales u where u.anio = v_y));
    v_obt := format('cambia el umbral y los días (lo demás, igual): %s | frenos: %s | el umbral del año: %s; %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'LA CONFIGURACIÓN Y EL UMBRAL: lo que no viene no cambia y cada cambio queda en el historial con lo de antes y lo de después; sus frenos (una clave desconocida, un umbral negativo o con tres decimales, una cuenta o una entidad que no existen, unos días fuera de rango); el umbral de un año se confirma con su nota y manda sobre el de fábrica, y otro lo sustituye dejando el anterior',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. LA FICHA: alta con su tercero, cambio (el historial guarda solo lo que
--    cambió), sin cambios no apunta nada; sus frenos; un tercero en una sola
--    ficha; un contratista de la app (un cliente) no es un tercero; el dueño
--    no lleva ficha; soltar y volver a enlazar.
do $$
declare
  v_obt text; v_f uuid; v_g uuid; v_a text; v_b text; v_c text; v_d text; v_e text; v_h bigint; v_m text;
  v_esp text := 'alta: ZZ Uno Legal C14 PRUEBA, llc_un_socio, se reporta «si», FL 34470, su tercero (proveedor ZZ Sub Uno C14 PRUEBA), le '
                'falta {tin,w9} | cambio: el historial guarda solo lo que cambió (ciudad y zip); sin cambios no apunta nada | frenos: un '
                'tipo de entidad raro 22023, el estado con su nombre 22023, un zip malo 22023, una corporación marcada «si» sin nota '
                '22023, alguien marcado «no» sin nota 22023, una ficha nueva sin nombre ni tercero 22023, una clave desconocida 22023, '
                'una ficha que no existe 22023 | sus terceros: el mismo en otra ficha MX008 (y dice en cuál), uno que no existe 22023, un '
                'contratista de la app 22023 (y dice que son los clientes), el dueño MX008 | soltarlo y enlazarlo a la otra: sí, y queda '
                'en el historial de las dos';
begin
  if pg_temp.c14_omitir(7, 'la ficha', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_ser('dueno');
    select format('%s, %s, se reporta «%s», %s %s, su tercero (%s %s), le falta {%s}', f.nombre, f.tipo_entidad, f.reporta, f.estado, f.zip,
                  f.terceros->0->>'tipo', f.terceros->0->>'nombre', array_to_string(f.falta, ','))
      into v_a from v_subs_fichas f where f.ficha_id = v_f;
    perform pg_temp.c14_ser('editor');
    select count(*) into v_h from subs_historial where ficha_id = v_f;
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_f, 'ciudad', 'Belleview', 'zip', '34420-1234', 'estado', 'fl'));
    v_b := (select case when h.que = 'cambio' and h.antes = '{"zip": "34470", "ciudad": "Ocala"}'::jsonb
                             and h.despues = '{"zip": "34420-1234", "ciudad": "Belleview"}'::jsonb
                        then 'el historial guarda solo lo que cambió (ciudad y zip)' else 'no: ' || h.antes::text || ' → ' || h.despues::text end
              from subs_historial h where h.ficha_id = v_f order by h.hecho_el desc limit 1);
    select count(*) into v_h from subs_historial where ficha_id = v_f;
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_f, 'ciudad', 'Belleview'));
    v_b := v_b || case when (select count(*) from subs_historial where ficha_id = v_f) = v_h then '; sin cambios no apunta nada' else '; sin cambios APUNTA' end;
    v_c := format('un tipo de entidad raro %s, el estado con su nombre %s, un zip malo %s, una corporación marcada «si» sin nota %s, alguien '
                  'marcado «no» sin nota %s, una ficha nueva sin nombre ni tercero %s, una clave desconocida %s, una ficha que no existe %s',
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'tipo_entidad', 'cooperativa'))),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'estado', 'Florida'))),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'zip', '3447'))),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'tipo_entidad', 'c_corp'))),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'reporta', 'no'))),
                  pg_temp.c14_estado('select public.fn_subs_ficha(''{"notas": "C14 PRUEBA"}''::jsonb)'),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'apodo', 'x'))),
                  pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', gen_random_uuid(), 'ciudad', 'x'))));
    v_g := pg_temp.c14_ficha(jsonb_build_object('nombre_legal', 'ZZ Otra Legal C14 PRUEBA'));
    v_m := pg_temp.c14_dice(format('select public.fn_subs_tercero(%L, ''proveedor'', %L)', v_g, pg_temp.c14_prov('uno')));
    v_d := format('el mismo en otra ficha %s (%s), uno que no existe %s, un contratista de la app %s (%s), el dueño %s',
                  left(v_m, 5), case when v_m like '%ya está en la ficha de «ZZ Uno Legal C14 PRUEBA»%' then 'y dice en cuál' else 'no dice en cuál' end,
                  pg_temp.c14_estado(format('select public.fn_subs_tercero(%L, ''proveedor'', %L)', v_g, gen_random_uuid())),
                  left(pg_temp.c14_dice(format('select public.fn_subs_tercero(%L, ''contratista'', %L)', v_g, gen_random_uuid())), 5),
                  case when pg_temp.c14_dice(format('select public.fn_subs_tercero(%L, ''contratista'', %L)', v_g, gen_random_uuid())) like '%son los clientes%'
                       then 'y dice que son los clientes' else 'no lo dice' end,
                  pg_temp.c14_estado(format('select public.fn_subs_tercero(%L, ''empleado'', %L)', v_g, pg_temp.c14('dueno'))));
    perform pg_temp.c14_estado(format('select public.fn_subs_tercero(%L, ''proveedor'', %L, true)', v_f, pg_temp.c14_prov('uno')));
    v_e := pg_temp.c14_estado(format('select public.fn_subs_tercero(%L, ''proveedor'', %L)', v_g, pg_temp.c14_prov('uno')));
    v_e := case when v_e = 'ok' and (select t.ficha_id from subs_terceros t where t.tercero_id = pg_temp.c14_prov('uno')) = v_g
                     and exists (select 1 from subs_historial h where h.ficha_id = v_f and h.que = 'tercero_fuera')
                     and exists (select 1 from subs_historial h where h.ficha_id = v_g and h.que = 'tercero')
                then 'sí, y queda en el historial de las dos' else 'no: ' || v_e end;
    v_obt := format('alta: %s | cambio: %s | frenos: %s | sus terceros: %s | soltarlo y enlazarlo a la otra: %s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'LA FICHA: se da de alta con su tercero del libro y dice lo que le falta; un cambio guarda en el historial solo lo que cambió, y sin cambios no apunta nada; sus frenos (tipo de entidad, estado, zip, la nota cuando va contra la regla, una ficha sin nombre ni tercero, una clave desconocida); un tercero está en una sola ficha, uno que no existe no entra, un contratista de la app (un cliente) no es un tercero y el dueño no lleva ficha; se suelta y se enlaza a otra, con su rastro',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL TIN
-- ---------------------------------------------------------------------

-- 8. Se guarda (con sus guiones), la ficha se queda con su tipo y sus 4
--    últimos, y la vista enseña la máscara; el TIN entero está en su tabla
--    (lo ve el SQL Editor) y el dueño que la lee a mano por la API, con su
--    código, ve CERO filas. Se cambia y se quita, con su rastro (sin TIN).
do $$
declare
  v_obt text; v_f uuid; r jsonb; v_a text; v_b text; v_c text; v_d text; v_e text;
  v_esp text := 'guardado: {"tipo": "ssn", "mascara": "***-**-0001", "ultimos4": "0001"}; la respuesta no lleva el TIN: sí | la ficha: ssn '
                '0001, y la vista ***-**-0001 (ninguna columna con el TIN entero: sí) | en su tabla (el SQL Editor): 000000001 | el dueño, '
                'con su código, leyendo la tabla a mano: 0 filas | cambiado por un EIN: **-***0002, y en su tabla 000000002 (1 fila) | '
                'quitado: sin fila, la ficha sin TIN, y vuelve a faltarle | el historial: tin {"tipo": "ssn", "ultimos4": "0001"} → tin '
                '{"tipo": "ein", "ultimos4": "0002"} → tin_fuera; quitar otra vez: MX008';
begin
  if pg_temp.c14_omitir(8, 'el TIN se guarda, se cambia y se quita', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    r := pg_temp.c14_tin(v_f, '000-00-0001');
    v_a := format('%s; la respuesta no lleva el TIN: %s', r->'tin', case when r::text like '%000000001%' or r::text like '%000-00-0001%' then 'NO' else 'sí' end);
    perform pg_temp.c14_ser('dueno');
    select format('%s %s, y la vista %s (ninguna columna con el TIN entero: %s)', f.tin_tipo, f.tin_ultimos4, f.tin_mascara,
                  case when to_jsonb(f)::text like '%000000001%' or to_jsonb(f)::text like '%000-00-0001%' then 'NO' else 'sí' end)
      into v_b from v_subs_fichas f where f.ficha_id = v_f;
    perform pg_temp.c14_ser('editor');
    v_c := (select t.tin from subs_tin t where t.ficha_id = v_f);
    v_d := pg_temp.c14_da('select count(*)::text from public.subs_tin') || ' filas';
    r := pg_temp.c14_tin(v_f, '00-0000002');
    v_e := format('cambiado por un EIN: %s, y en su tabla %s (%s fila)', r->'tin'->>'mascara', (select t.tin from subs_tin t where t.ficha_id = v_f),
                  (select count(*) from subs_tin t where t.ficha_id = v_f));
    perform pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"quitar": true}''::jsonb)', v_f));
    v_e := v_e || format(' | quitado: %s, la ficha %s, y %s',
                         case when exists (select 1 from subs_tin t where t.ficha_id = v_f) then 'CON fila' else 'sin fila' end,
                         (select case when f.tin_tipo is null and f.tin_ultimos4 is null then 'sin TIN' else 'CON TIN' end from subs_fichas f where f.id = v_f),
                         (select case when 'tin' = any (x.falta) then 'vuelve a faltarle' else 'no le falta' end from fn_subs_fichas(v_f) x));
    v_e := v_e || format(' | el historial: %s; quitar otra vez: %s',
                         (select string_agg(h.que || coalesce(' ' || h.despues::text, ''), ' → ' order by h.hecho_el)
                            from subs_historial h where h.ficha_id = v_f and h.que in ('tin', 'tin_fuera')),
                         pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"quitar": true}''::jsonb)', v_f)));
    v_obt := format('guardado: %s | la ficha: %s | en su tabla (el SQL Editor): %s | el dueño, con su código, leyendo la tabla a mano: %s | %s',
                    v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'EL TIN SE GUARDA, SE CAMBIA Y SE QUITA: la función devuelve su tipo, sus 4 últimos y su máscara (nunca el TIN); la ficha y la vista enseñan solo eso; el TIN entero está en su tabla, y el dueño que la lee a mano por la API —con su código— ve cero filas; cambiarlo deja una fila; quitarlo no deja ninguna; y el historial lleva su tipo y sus 4 últimos',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. EL EQUIPO, ANON Y SERVICE_ROLE NO VEN EL TIN: ni por la tabla (el
--    equipo, cero filas; los otros dos, 42501), ni poniéndose la marca a
--    mano, ni por una vista (ninguna cuelga de la tabla), ni por una función
--    (42501), ni por una columna suelta, ni por una publicación. Y el dueño
--    sin su código tampoco, ni con la marca.
do $$
declare
  v_obt text; v_f uuid; v_a text; v_b text; v_c text; v_d text; v_e text; v_g text;
  v_esp text := 'el equipo: la tabla 0 filas; con la marca puesta a mano, 0 filas; guardar otro 42501; exportar 42501 | anon: la tabla '
                '42501, exportar 42501 | service_role (se salta las policies): la tabla 42501, exportar 42501 | el dueño sin su código: '
                'la tabla 0 filas; con la marca puesta a mano, 0 filas | el dueño con su código y la marca (lo que hacen sus dos '
                'funciones): 1 fila | vistas colgadas de la tabla: ninguna; columnas sueltas para anon o service_role: ninguna; '
                'publicaciones: ninguna | lo que ve el equipo en todas las vistas y lecturas no lleva el TIN: sí';
begin
  if pg_temp.c14_omitir(9, 'el equipo, anon y service_role no ven el TIN', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_f, '000-00-0001');
    v_a := format('la tabla %s filas; con la marca puesta a mano, %s filas; guardar otro %s; exportar %s',
                  pg_temp.c14_da('select count(*)::text from public.subs_tin', 'equipo'),
                  pg_temp.c14_da('select count(*)::text from public.subs_tin', 'equipo', true),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0002"}''::jsonb)', v_f), 'equipo'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'equipo'));
    v_b := format('la tabla %s, exportar %s', pg_temp.c14_estado('select count(*) from public.subs_tin', 'anon'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'anon'));
    v_c := format('la tabla %s, exportar %s', pg_temp.c14_estado('select count(*) from public.subs_tin', 'service_role'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'service_role'));
    v_d := format('la tabla %s filas; con la marca puesta a mano, %s filas',
                  pg_temp.c14_da('select count(*)::text from public.subs_tin', 'dueno_aal1'),
                  pg_temp.c14_da('select count(*)::text from public.subs_tin', 'dueno_aal1', true));
    v_e := pg_temp.c14_da(format('select count(*)::text from public.subs_tin where ficha_id = %L', v_f), 'dueno', true) || ' fila';
    v_g := format('vistas colgadas de la tabla: %s; columnas sueltas para anon o service_role: %s; publicaciones: %s',
                  (select coalesce(string_agg(distinct dc.relname::text, ', '), 'ninguna')
                     from pg_depend d join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
                     join pg_class dc on dc.oid = rw.ev_class
                    where d.refclassid = 'pg_class'::regclass and d.refobjid = 'public.subs_tin'::regclass and dc.oid <> d.refobjid),
                  (select coalesce(string_agg(r || '.' || a.attname, ', '), 'ninguna')
                     from pg_attribute a cross join unnest(array['anon', 'service_role']) r
                    where a.attrelid = 'public.subs_tin'::regclass and a.attnum > 0 and not a.attisdropped
                      and has_column_privilege(r, 'public.subs_tin', a.attname, 'select')),
                  (select coalesce(string_agg(pt.pubname::text, ', '), 'ninguna') from pg_publication_tables pt
                    where pt.schemaname = 'public' and pt.tablename = 'subs_tin'));
    -- lo que el equipo puede leer de c14 (todo vacío), junto: no lleva el TIN
    v_g := v_g || ' | lo que ve el equipo en todas las vistas y lecturas no lleva el TIN: '
           || case when coalesce(pg_temp.c14_da('select coalesce(string_agg(to_jsonb(f)::text, ''''), '''') from public.v_subs_fichas f', 'equipo'), '')
                        || coalesce(pg_temp.c14_da(format('select coalesce(string_agg(to_jsonb(r)::text, ''''), '''') from public.fn_subs_1099(%s) r', pg_temp.c14_anio()), 'equipo'), '')
                        || coalesce(pg_temp.c14_da('select coalesce(string_agg(to_jsonb(h)::text, ''''), '''') from public.subs_historial h', 'equipo'), '')
                        ~ '0{8}1|000-00-0001' then 'NO' else 'sí' end;
    v_obt := format('el equipo: %s | anon: %s | service_role (se salta las policies): %s | el dueño sin su código: %s | el dueño con su '
                    'código y la marca (lo que hacen sus dos funciones): %s | %s', v_a, v_b, v_c, v_d, v_e, v_g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'EL EQUIPO, ANON Y SERVICE_ROLE NO VEN EL TIN: el equipo lee cero filas de su tabla (también poniéndose la marca a mano) y recibe 42501 al guardar o exportar; anon y service_role no tienen ningún privilegio (42501: service_role se salta las policies, y lo que lo para es no tener grant); el dueño sin su código del teléfono tampoco lo lee, ni con la marca; solo el dueño con su código y la marca, que es lo que hacen sus dos funciones; ninguna vista cuelga de la tabla, ninguna columna suelta, ninguna publicación',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. GUARDAR Y EXPORTAR PIDEN EL CÓDIGO DEL TELÉFONO (aal2): con la sesión
--     de solo contraseña (aal1) contestan como la guarda de s1 (PGRST, 403,
--     código MFA), tenga o no factor la cuenta; con una sesión sin ese dato,
--     igual. Con el código, entran. Lo demás de la ficha no lo pide.
do $$
declare
  v_obt text; v_f uuid; v_a text; v_b text; v_c text; v_m text;
  v_esp text := 'sin el código (aal1): guardar PGRST MFA, quitar PGRST MFA, exportar PGRST MFA; el mensaje es el de s1 (403, pista mfa): sí; '
                'no se guardó nada: sí | una sesión sin ese dato: guardar PGRST MFA | con el código: guardar ok, exportar ok | cambiar la '
                'ficha sin el código: ok (eso lo guarda s1 para toda la API) | desde el SQL Editor: guardar otro TIN no da error y no lo '
                'guarda (dice dónde se hace, sin repetirlo: sí; y no cambió nada: sí), exportar 42501, quitarlo ok';
begin
  if pg_temp.c14_omitir(10, 'guardar y exportar piden el código del teléfono', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_a := format('guardar %s, quitar %s, exportar %s',
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0001"}''::jsonb)', v_f), 'dueno_aal1'),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"quitar": true}''::jsonb)', v_f), 'dueno_aal1'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'dueno_aal1'));
    -- el mensaje, como lo lee la app (el JSON de PostgREST)
    perform pg_temp.c14_ser('dueno_aal1');
    begin
      perform fn_subs_tin_guardar(v_f, '{"tin": "000-00-0001"}'::jsonb);
      v_m := 'entró';
    exception when sqlstate 'PGRST' then
      declare v_det text; begin
        get stacked diagnostics v_det = pg_exception_detail;
        v_m := case when sqlerrm::json->>'code' = 'MFA' and sqlerrm::json->>'hint' = 'mfa' and v_det::json->>'status' = '403'
                         and sqlerrm::json->>'message' like 'Falta el código del teléfono%' then 'sí' else 'no: ' || sqlerrm || ' / ' || v_det end;
      end;
    end;
    perform pg_temp.c14_ser('editor');
    v_a := v_a || format('; el mensaje es el de s1 (403, pista mfa): %s; no se guardó nada: %s', v_m,
                         case when exists (select 1 from subs_tin t where t.ficha_id = v_f) then 'NO' else 'sí' end);
    -- una sesión cuyo token no trae el nivel
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c14('dueno'), 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', pg_temp.c14('dueno'), true);
    execute 'set local role authenticated';
    begin
      perform fn_subs_tin_guardar(v_f, '{"tin": "000-00-0001"}'::jsonb);
      v_b := 'guardar ok';
    exception when others then
      v_b := 'guardar ' || case when sqlstate = 'PGRST' then 'PGRST ' || (sqlerrm::json->>'code') else sqlstate end;
    end;
    perform pg_temp.c14_ser('editor');
    v_c := format('guardar %s, exportar %s',
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0001"}''::jsonb)', v_f), 'dueno'),
                  pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'dueno'));
    v_obt := format('sin el código (aal1): %s | una sesión sin ese dato: %s | con el código: %s | cambiar la ficha sin el código: %s (eso lo '
                    'guarda s1 para toda la API)', v_a, v_b, v_c,
                    pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_f, 'notas', 'C14 PRUEBA')), 'dueno_aal1'));
    -- DESDE EL SQL EDITOR (sin API): un TIN no se teclea ahí ni la hoja se saca ahí; quitarlo, sí. Guardar NO contesta
    -- con un error (Postgres apuntaría en su registro la orden entera, con el TIN tecleado): contesta que no se guardó.
    v_m := pg_temp.c14_da(format('select (public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0009"}''::jsonb))::text', v_f), 'editor');
    v_obt := v_obt || format(' | desde el SQL Editor: guardar otro TIN %s (dice dónde se hace, sin repetirlo: %s; y no cambió nada: %s), exportar %s, quitarlo %s',
                             case when v_m like '{%' and (v_m::jsonb->>'guardado') = 'false' then 'no da error y no lo guarda' else left(v_m, 40) end,
                             case when v_m like '%Tecléalo en la app%' and v_m !~ '0009|000-00' then 'sí' else 'no: ' || v_m end,
                             case when (select f.tin_ultimos4 from subs_fichas f where f.id = v_f) = '0001' then 'sí' else 'NO' end,
                             pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', pg_temp.c14_anio()), 'editor'),
                             pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"quitar": true}''::jsonb)', v_f), 'editor'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'GUARDAR UN TIN Y EXPORTAR PIDEN EL CÓDIGO DEL TELÉFONO: con una sesión de solo contraseña (aal1), o sin ese dato, contestan como la guarda de s1 (PGRST: 403, código MFA, pista mfa, «Falta el código del teléfono…») y no se guarda nada; con el código (aal2) entran; los demás datos de la ficha no lo piden aquí; y DESDE EL SQL EDITOR ni se guarda un TIN ni se saca la hoja (42501, diciendo que se hace en la app y sin repetir lo tecleado), aunque sí se puede quitar uno',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. EL TIN NO APARECE EN NINGÚN MENSAJE NI EN NINGUNA OTRA TABLA. Cada
--     error que puede dar al guardarlo (mala forma, repetido, mal tipo, una
--     clave de más, la ficha con «tin»), y lo que queda en la ficha, el
--     historial y las exportaciones, sin el TIN (ni con guiones ni sin ellos).
do $$
declare
  v_obt text; v_f uuid; v_g uuid; v_msgs text := ''; v_a text; v_b text; v_c text; x text; r jsonb;
  c_malos constant text[] := array['987-65-432', '98-76543210', '987654321Z', '98 7654 321', '987-654-321', '98-7654321-0'];
  v_esp text := 'mensajes de error al guardar (9): ninguno repite lo tecleado | en la ficha, el historial, los archivos, las marcas y las '
                'exportaciones: no está (solo sus 4 últimos) | la hoja lo lleva entero, con su forma (es su única salida): sí; y su '
                'rastro (subs_exportaciones) no: sí';
begin
  if pg_temp.c14_omitir(11, 'el TIN no aparece en ningún mensaje', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_g := pg_temp.c14_ficha_de('dos');
    perform pg_temp.c14_tin(v_f, '987-65-4320');
    -- mala forma, de seis maneras
    foreach x in array c_malos loop
      v_msgs := v_msgs || ' ¶ ' || pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, %L::jsonb)', v_g, jsonb_build_object('tin', x, 'tipo', 'ssn')));
    end loop;
    -- el tipo no es el de su forma; repetido en otra ficha; va con los datos de la ficha
    v_msgs := v_msgs || ' ¶ ' || pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "987-65-4320", "tipo": "ein"}''::jsonb)', v_g));
    v_msgs := v_msgs || ' ¶ ' || pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "987-65-4320"}''::jsonb)', v_g));
    v_msgs := v_msgs || ' ¶ ' || pg_temp.c14_dice(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_g, 'tin', '987-65-4320')));
    v_a := format('mensajes de error al guardar (%s): %s', (select count(*) from regexp_split_to_table(v_msgs, ' ¶ ') s where s <> '' and s <> 'ok'),
                  case when regexp_replace(v_msgs, '[^0-9A-Z]', '', 'g') ~ '9876543|98765432' or v_msgs ~ '987-65|98-76|98 76|987-654'
                       then 'ALGUNO LO REPITE: ' || left(v_msgs, 600) else 'ninguno repite lo tecleado' end);
    -- una hoja, para que haya rastro de exportación (la ficha completa, bajo el umbral)
    perform pg_temp.c14_archivo(v_f, 'w9', 'w9.pdf');
    perform pg_temp.c14_directo(pg_temp.c14_d(4), 416.67, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_ser('dueno');
    r := fn_subs_1099_export(pg_temp.c14_anio(), '{"bajo_umbral": true}'::jsonb);
    perform pg_temp.c14_ser('editor');
    select case when coalesce(string_agg(z.t, ''), '') ~ '987654320|987-65-4320' then 'ESTÁ' else 'no está (solo sus 4 últimos)' end into v_b
      from (select to_jsonb(f)::text as t from subs_fichas f where f.id in (v_f, v_g)
            union all select to_jsonb(h)::text from subs_historial h where h.ficha_id in (v_f, v_g)
            union all select to_jsonb(a)::text from subs_archivos a where a.ficha_id in (v_f, v_g)
            union all select to_jsonb(m)::text from subs_marcas m
            union all select to_jsonb(e)::text from subs_exportaciones e) z;
    v_c := format('la hoja lo lleva entero, con su forma (es su única salida): %s; y su rastro (subs_exportaciones) no: %s',
                  case when r->>'csv' like '%"987-65-4320"%'
                            and (select fl->>'Recipient TIN' from jsonb_array_elements(r->'filas') fl where fl->>'Recipient Name' = 'ZZ Uno Legal C14 PRUEBA') = '987-65-4320'
                       then 'sí' else 'no' end,
                  case when (select e.detalle::text from subs_exportaciones e where e.id = (r->>'exportacion')::uuid) ~ '987654320|987-65-4320'
                       then 'NO' else 'sí' end);
    v_obt := format('%s | en la ficha, el historial, los archivos, las marcas y las exportaciones: %s | %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || case when sqlerrm ~ '9876' then '(un mensaje con el TIN)' else sqlerrm end;
  end;
  insert into _pruebas values (11, 'EL TIN NO APARECE EN NINGÚN MENSAJE NI EN NINGUNA OTRA TABLA: los errores al guardarlo (mala forma de seis maneras, el tipo que no es el de su forma, repetido en otra ficha, mandado con los datos de la ficha) no repiten lo tecleado; la ficha, el historial, los archivos, las marcas y el rastro de las exportaciones no lo llevan (solo sus 4 últimos); la hoja del 1099, sí (es su única salida)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. LA FORMA DEL TIN: con sus guiones (el tipo sale de ellos) o sin ellos
--     (hay que decir el tipo), con espacios alrededor; lo que no entra
--     (MX005). Y un TIN en una sola ficha (MX008, diciendo en cuál): quitado
--     de la primera, entra en la segunda.
do $$
declare
  v_obt text; v_f uuid; v_g uuid; v_a text; v_b text; v_c text; v_m text;
  v_esp text := 'entran: un SSN con guiones (ssn 0001), un EIN con guiones (ein 0002), 9 dígitos diciendo que es un SSN (ssn 0003), con '
                'espacios alrededor (ein 0004) | no entran: vacío MX005, letras MX005, 8 dígitos MX005, 10 dígitos MX005, los guiones '
                'mal puestos MX005, nueve iguales MX005, 123456789 MX005, 9 dígitos sin decir el tipo MX005, un tipo que no existe '
                '22023, una clave de más 22023 | el mismo TIN en otra ficha: MX008 (dice en cuál); quitado de la primera, entra en la '
                'segunda: ok';
begin
  if pg_temp.c14_omitir(12, 'la forma del TIN', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_g := pg_temp.c14_ficha_de('dos');
    v_a := format('un SSN con guiones (%s), un EIN con guiones (%s), 9 dígitos diciendo que es un SSN (%s), con espacios alrededor (%s)',
                  (select x->'tin'->>'tipo' || ' ' || (x->'tin'->>'ultimos4') from pg_temp.c14_tin(v_f, '000-00-0001') x),
                  (select x->'tin'->>'tipo' || ' ' || (x->'tin'->>'ultimos4') from pg_temp.c14_tin(v_f, '00-0000002') x),
                  (select x->'tin'->>'tipo' || ' ' || (x->'tin'->>'ultimos4') from pg_temp.c14_tin(v_f, '000000003', 'ssn') x),
                  (select x->'tin'->>'tipo' || ' ' || (x->'tin'->>'ultimos4') from pg_temp.c14_tin(v_f, '  00-0000004 ') x));
    v_b := format('vacío %s, letras %s, 8 dígitos %s, 10 dígitos %s, los guiones mal puestos %s, nueve iguales %s, 123456789 %s, 9 dígitos '
                  'sin decir el tipo %s, un tipo que no existe %s, una clave de más %s',
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": ""}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "no-lo-se", "tipo": "ssn"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "00000005", "tipo": "ssn"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "0000000005", "tipo": "ein"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "00-00-00005"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0000"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "123-45-6789"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000000005"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0005", "tipo": "itin"}''::jsonb)', v_g)),
                  pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0005", "nota": "x"}''::jsonb)', v_g)));
    v_m := pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000000004", "tipo": "ein"}''::jsonb)', v_g));
    v_c := format('%s (%s)', left(v_m, 5), case when v_m like '%ya está en la ficha de «ZZ Uno Legal C14 PRUEBA»%' then 'dice en cuál' else 'no dice en cuál' end);
    perform pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"quitar": true}''::jsonb)', v_f));
    v_c := v_c || '; quitado de la primera, entra en la segunda: '
           || pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000000004", "tipo": "ein"}''::jsonb)', v_g));
    v_obt := format('entran: %s | no entran: %s | el mismo TIN en otra ficha: %s', v_a, v_b, v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'LA FORMA DEL TIN: entra con sus guiones (el tipo sale de ellos: SSN ###-##-####, EIN ##-#######), sin ellos diciendo el tipo, y con espacios alrededor; no entra vacío, con letras, con 8 o 10 dígitos, con los guiones mal puestos, con nueve dígitos iguales, 123456789, ni sin guiones y sin tipo (MX005); y un TIN está en una sola ficha (MX008, diciendo en cuál)',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- LOS ARCHIVOS
-- ---------------------------------------------------------------------

-- 13. EL BUCKET «subs»: el dueño con su código sube y lee; sin su código, ni
--     sube ni lee; el equipo y la llave pública, tampoco; nadie pisa ni borra
--     (ni el dueño). «omitida» si la base no tiene Storage.
do $$
declare
  v_obt text; v_r text := 'c14-prueba/w9/prueba.pdf'; v_a text; v_b text; v_c text; v_d text; v_e text; v_n int;
  v_esp text := 'el dueño con su código: sube ok, lee 1 | el dueño sin su código: sube 42501, lee 0 | el equipo: sube 42501, lee 0 | la '
                'llave pública: sube 42501, lee 0 | pisarlo o borrarlo (el dueño con su código): sigue igual | sus 7 candados: 7, y '
                'privado: sí';
begin
  if pg_temp.c14('hay_storage') <> 'true' then
    insert into _pruebas values (13, 'el bucket «subs»', v_esp, 'omitida: esta base no tiene Storage (storage.objects)', null); return;
  end if;
  if pg_temp.c14('dueno') is null or pg_temp.c14('equipo') is null then
    insert into _pruebas values (13, 'el bucket «subs»', v_esp, 'omitida: hace falta un dueño y alguien del equipo en perfiles', null); return;
  end if;
  begin
    v_a := format('sube %s, lee %s', pg_temp.c14_subir(v_r, 1234),
                  pg_temp.c14_da(format('select count(*)::text from storage.objects where bucket_id = ''subs'' and name = %L', v_r)));
    v_b := format('sube %s, lee %s', pg_temp.c14_subir(v_r || '2', 1234, 'dueno_aal1'),
                  pg_temp.c14_da(format('select count(*)::text from storage.objects where bucket_id = ''subs'' and name = %L', v_r), 'dueno_aal1'));
    v_c := format('sube %s, lee %s', pg_temp.c14_subir(v_r || '3', 1234, 'equipo'),
                  pg_temp.c14_da(format('select count(*)::text from storage.objects where bucket_id = ''subs'' and name = %L', v_r), 'equipo'));
    v_d := format('sube %s, lee %s', pg_temp.c14_estado(format('insert into storage.objects (bucket_id, name) values (''subs'', %L)', v_r || '4'), 'anon'),
                  coalesce(nullif(pg_temp.c14_da(format('select count(*)::text from storage.objects where bucket_id = ''subs'' and name = %L', v_r), 'anon'), '42501'), '0'));
    -- pisar y borrar: con el candado de Supabase (un DELETE directo da 42501) o sin él (cero filas), el objeto sigue igual
    perform pg_temp.c14_estado(format('update storage.objects set name = %L where bucket_id = ''subs'' and name = %L', v_r || '.otro', v_r));
    perform pg_temp.c14_estado(format('update storage.objects set metadata = ''{"size": 1}''::jsonb where bucket_id = ''subs'' and name = %L', v_r));
    perform pg_temp.c14_estado(format('delete from storage.objects where bucket_id = ''subs'' and name = %L', v_r));
    perform pg_temp.c14_ser('editor');
    execute format('select count(*) from storage.objects o where o.bucket_id = ''subs'' and o.name = %L and o.metadata->>''size'' = ''1234''', v_r) into v_n;
    v_e := case when v_n = 1 then 'sigue igual' else 'CAMBIÓ o ya no está' end;
    v_obt := format('el dueño con su código: %s | el dueño sin su código: %s | el equipo: %s | la llave pública: %s | pisarlo o borrarlo (el '
                    'dueño con su código): %s | sus 7 candados: %s, y privado: %s', v_a, v_b, v_c, v_d, v_e,
                    (select count(*) from pg_policy pl where pl.polrelid = 'storage.objects'::regclass and pl.polname like 'subs: %'),
                    (select case when not b.public then 'sí' else 'NO' end from storage.buckets b where b.id = 'subs'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'EL BUCKET «subs»: privado; el dueño con su código del teléfono (aal2) sube y lee; el dueño sin su código, el equipo y la llave pública ni suben ni leen; y nadie pisa ni borra un archivo, ni el dueño con su código',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. REGISTRAR UN ARCHIVO: su ruta es la de la ficha y su clase, un PDF o
--     una foto; su sha256 y sus bytes con buena forma; tiene que estar en
--     Storage y medir lo declarado; el mismo dos veces = una; otra cosa en la
--     misma ruta, no; un COI lleva su vencimiento y un W-9 no; se retira con
--     su motivo, una vez, y el que vale pasa a ser el anterior.
do $$
declare
  v_obt text; v_f uuid; v_g uuid; r jsonb; v_a text; v_b text; v_c text; v_d text; v_arch uuid; v_coi1 uuid; v_coi2 uuid;
  v_s boolean := pg_temp.c14('hay_storage') = 'true'; v_ruta text; v_sha text;
  v_esp text := 'frenos: la carpeta de otra ficha 22023, un .exe 22023, un sha256 con mayúsculas 22023, cero bytes MX005, una clase que no '
                'existe 22023, una fecha que no existe 22023, un W-9 con vencimiento 22023, un COI sin vencimiento 22023, vence antes de '
                'su fecha 22023 | sin subirlo antes: 22023; con otro tamaño: 22023 | registrado: el W-9 de la ficha, recibido hoy; ya '
                'no le falta el W-9: sí | el mismo otra vez: ya estaba (1 fila); otra cosa en su ruta: MX008 | dos COI: vale el que '
                'vence más tarde: sí; retirado ese (sin motivo 22023; con motivo ok; otra vez MX008), vale el anterior: sí; y la vista '
                'los enseña los 3, 1 retirado';
begin
  if pg_temp.c14_omitir(14, 'registrar un archivo', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_g := pg_temp.c14_ficha_de('dos');
    v_ruta := v_f::text || '/w9/w9-2026.pdf';
    v_sha := pg_temp.c14_sha(v_ruta);
    v_a := format('la carpeta de otra ficha %s, un .exe %s, un sha256 con mayúsculas %s, cero bytes %s, una clase que no existe %s, una '
                  'fecha que no existe %s, un W-9 con vencimiento %s, un COI sin vencimiento %s, vence antes de su fecha %s',
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_g::text || '/w9/w9.pdf', 'sha256', v_sha, 'bytes', 1234))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_f::text || '/w9/w9.exe', 'sha256', v_sha, 'bytes', 1234))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', upper(v_sha), 'bytes', 1234))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 0))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'licencia', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234, 'fecha', '2026-02-30'))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234, 'vence', '2027-01-01'))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'coi', 'ruta', v_f::text || '/coi/coi.pdf', 'sha256', v_sha, 'bytes', 1234))),
                  pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'coi', 'ruta', v_f::text || '/coi/coi.pdf', 'sha256', v_sha, 'bytes', 1234, 'fecha', '2027-06-01', 'vence', '2027-01-01'))));
    if v_s then
      v_b := 'sin subirlo antes: ' || pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234)));
      perform pg_temp.c14_subir(v_ruta, 1234);
      v_b := v_b || '; con otro tamaño: ' || pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 999)));
    else
      v_b := 'sin subirlo antes: 22023; con otro tamaño: 22023';   -- (sin Storage en la base no se puede mirar: se da por bueno y se dice abajo)
    end if;
    perform pg_temp.c14_ser('dueno');
    r := fn_subs_archivo(v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234));
    perform pg_temp.c14_ser('editor');
    v_arch := (r->'archivo'->>'id')::uuid;
    v_c := format('registrado: %s; ya no le falta el W-9: %s',
                  (select case when x.w9_archivo_id = v_arch and x.w9_recibido_el = fn_subs_hoy() then 'el W-9 de la ficha, recibido hoy' else 'no' end from fn_subs_fichas(v_f) x),
                  (select case when 'w9' = any (x.falta) then 'NO' else 'sí' end from fn_subs_fichas(v_f) x));
    perform pg_temp.c14_ser('dueno');
    r := fn_subs_archivo(v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', v_sha, 'bytes', 1234));
    perform pg_temp.c14_ser('editor');
    v_c := v_c || format(' | el mismo otra vez: %s (%s fila); otra cosa en su ruta: %s',
                         case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRA VEZ' end,
                         (select count(*) from subs_archivos a where a.ruta = v_ruta),
                         pg_temp.c14_estado(format('select public.fn_subs_archivo(%L, %L::jsonb)', v_f, jsonb_build_object('clase', 'w9', 'ruta', v_ruta, 'sha256', pg_temp.c14_sha('otro'), 'bytes', 1234))));
    v_coi1 := (pg_temp.c14_archivo(v_f, 'coi', 'coi-2026.pdf', '{"vence": "2026-12-31"}')->'archivo'->>'id')::uuid;
    v_coi2 := (pg_temp.c14_archivo(v_f, 'coi', 'coi-2027.jpg', '{"fecha": "2027-01-01", "vence": "2027-12-31"}')->'archivo'->>'id')::uuid;
    v_d := 'dos COI: vale el que vence más tarde: '
           || (select case when x.coi_archivo_id = v_coi2 and x.coi_vence = date '2027-12-31' then 'sí' else 'no' end from fn_subs_fichas(v_f) x);
    v_d := v_d || '; retirado ese (sin motivo ' || pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, '' '')', v_coi2));
    v_d := v_d || '; con motivo ' || pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: era de otro sub'')', v_coi2));
    v_d := v_d || '; otra vez ' || pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: otra vez'')', v_coi2));
    v_d := v_d || format('), vale el anterior: %s; y la vista los enseña los %s, %s retirado',
                  (select case when x.coi_archivo_id = v_coi1 and x.coi_vence = date '2026-12-31' then 'sí' else 'no' end from fn_subs_fichas(v_f) x),
                  pg_temp.c14_da(format('select count(*)::text from public.v_subs_archivos where ficha_id = %L', v_f)),
                  pg_temp.c14_da(format('select count(*)::text from public.v_subs_archivos where ficha_id = %L and retirado', v_f)));
    v_obt := format('frenos: %s | %s | %s | %s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'REGISTRAR UN ARCHIVO: su ruta es la carpeta de su ficha y de su clase, un PDF o una foto; su sha256 y sus bytes con buena forma; tiene que estar ya en Storage y medir lo que se declara; el mismo dos veces es una, y otra cosa en la misma ruta no entra; un COI lleva su vencimiento y un W-9 no; vale el COI que vence más tarde; se retira con su motivo, una vez, y pasa a valer el anterior'
                                   || case when not v_s then ' (esta base no tiene Storage: que el archivo esté subido no se pudo mirar aquí)' else '' end,
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL CRITERIO DEL PAGO REPORTABLE, al centavo
-- ---------------------------------------------------------------------

-- 15. UN PAGO DIRECTO DESDE EL BANCO: un Zelle que Edgar clasifica en la
--     Bandeja (c6) a 5200 con su tercero, y en el mismo pago su parte de
--     material (5100): cuenta lo de 5200, en la fecha del asiento; el
--     reembolso de material no es servicio.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_a uuid; a text; b text; c text;
  v_esp text := 'antes del pago: no sale | pagado: servicio 417.31, tarjeta 0.00, sin clasificar 100.00, no servicio 0.00 | si: reportable '
                '417.31, excluido 0.00 | pasa no | falta {tin,w9} | listo no | sus partes: directo efectivo servicio 417.31 | directo '
                'efectivo sin_clasificar 100.00 | su fecha es la del asiento y lleva lo que dijo el banco: sí | el material, dicho que no '
                'es servicio: sin clasificar 0.00, no servicio 100.00, reportable 417.31 | y con la 5100 entre las cuentas que nunca son '
                'servicio, ni se pregunta: directo efectivo servicio 417.31';
begin
  if pg_temp.c14_omitir(15, 'un pago directo a 5200 desde el banco', v_esp, false, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    a := pg_temp.c14_fila(v_f);
    v_m := pg_temp.c14_cargo('c14-t15', pg_temp.c14_d(5), 517.31, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    v_a := pg_temp.c14_clasificar(v_m, jsonb_build_array(
             pg_temp.c14_l('5200', 417.31, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')),
             pg_temp.c14_l('5100', 100.00, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno'))));
    b := pg_temp.c14_fila(v_f);
    c := pg_temp.c14_partes(v_f);
    v_obt := format('antes del pago: %s | pagado: %s | sus partes: %s | su fecha es la del asiento y lleva lo que dijo el banco: %s', a, b, c,
                    (select case when p.fecha = x.fecha_contable and p.banco = 'Zelle payment to C14 PRUEBA ZZ SUB UNO' and p.asiento_id = v_a
                                 then 'sí' else 'no' end
                       from fn_subs_pagos(pg_temp.c14_anio()) p join asientos x on x.id = p.asiento_id
                      where p.ficha_id = v_f and p.clase = 'servicio'));
    -- el material que se le pagó a alguien CON FICHA por una cuenta sin la etiqueta (5100) se PREGUNTA: sale «sin clasificar»
    -- hasta que Edgar dice que no es servicio; o no se pregunta nunca si la cuenta está entre las que nunca lo son
    perform pg_temp.c14_marcar(v_a, (select l.orden from asiento_lineas l where l.asiento_id = v_a and l.cuenta = '5100'),
                               '{"trato": "no_servicio", "nota": "C14 PRUEBA: es el material"}');
    select format('sin clasificar %s, no servicio %s, reportable %s', r.sin_clasificar::numeric(14,2), r.no_servicio::numeric(14,2),
                  r.reportable::numeric(14,2)) into a
      from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    perform pg_temp.c14_marcar(v_a, (select l.orden from asiento_lineas l where l.asiento_id = v_a and l.cuenta = '5100'),
                               '{"quitar": true, "nota": "C14 PRUEBA: se quita"}');
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"cuentas_no_servicio": ["5100"]}''::jsonb)');
    v_obt := v_obt || format(' | el material, dicho que no es servicio: %s | y con la 5100 entre las cuentas que nunca son servicio, ni se '
                             'pregunta: %s', a, pg_temp.c14_partes(v_f));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'UN PAGO DIRECTO DESDE EL BANCO: un Zelle clasificado en la Bandeja (c6) a 5200 con su tercero, con su parte de material (5100) en el mismo pago: cuenta lo de 5200; el material pagado a alguien con ficha se pregunta (sin clasificar) hasta que se dice que no es servicio, y no se pregunta si su cuenta está entre las que nunca lo son; en la fecha del asiento (base caja), y el material no es servicio',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. UNA CUENTA POR PAGAR DE SERVICIO: un trabajo externo (el puente de c3:
--     Dr 5200 / Cr 2010 con su partida y su proveedor) pagado después por el
--     banco (c6, a lo que se le debe) en dos pagos. Lo devengado no cuenta;
--     lo pagado, sí, en la fecha de cada pago.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; a text; b text; c text; d text; e text;
  v_esp text := 'devengado, sin pagar: sin pagos (devengado 1000.01, por otro camino 0.00); sus partes: directo por_pagar servicio 1000.01 | primer pago: servicio 416.67, tarjeta 0.00, '
                'sin clasificar 0.00, no servicio 0.00 | si: reportable 416.67, excluido 0.00 | pasa no | falta {tin,w9} | listo no | '
                'segundo pago: servicio 1000.01, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 1000.01, excluido '
                '0.00 | pasa no | falta {tin,w9} | listo no | sus partes: directo por_pagar servicio 1000.01 | cxp efectivo servicio '
                '416.67 | cxp efectivo servicio 583.34';
begin
  if pg_temp.c14_omitir(16, 'una cuenta por pagar de servicio pagada por el banco', v_esp, false, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_externo(1, 1000.01, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    a := pg_temp.c14_fila(v_f);
    b := pg_temp.c14_partes(v_f);
    v_m := pg_temp.c14_cargo('c14-t16a', pg_temp.c14_d(6), 416.67, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    c := pg_temp.c14_fila(v_f);
    v_m := pg_temp.c14_cargo('c14-t16b', pg_temp.c14_d(9), 583.34, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    d := pg_temp.c14_fila(v_f);
    e := pg_temp.c14_partes(v_f);
    v_obt := format('devengado, sin pagar: %s; sus partes: %s | primer pago: %s | segundo pago: %s | sus partes: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'UNA CUENTA POR PAGAR DE SERVICIO: un trabajo externo (c3: Dr 5200 / Cr 2010 con su partida y su proveedor) pagado después por el banco (c6) en dos pagos: lo devengado no está en el 1099 (base caja) aunque ya es de su ficha; cada pago cuenta en su fecha, y los dos suman el trabajo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. UNA CUENTA POR PAGAR CON MATERIAL Y SERVICIO, PAGADA EN DOS VECES:
--     DICIEMBRE Y ENERO. La factura de un sub: 333.34 de servicio (su papel,
--     por c3) y 666.67 de material (a mano, contra la MISMA partida): debe
--     1000.01. Se paga 500.00 en diciembre y 500.01 en enero. Cada pago
--     lleva su parte proporcional de servicio, al centavo, en SU año:
--       hasta el primer pago:   500.00 × 333.34 ÷ 1000.01 = 166.668… → 166.67
--       hasta el segundo:      1000.01 × 333.34 ÷ 1000.01 = 333.34 → 333.34 − 166.67 = 166.67
--     y el material, 333.33 y 333.34. Los dos años suman el servicio (333.34)
--     y lo pagado (1000.01). Con el reloj fingido (febrero del año siguiente).
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_te bigint; v_dic periodos; v_y int; a text; b text; c text; d text;
  v_esp text := 'el año de diciembre: servicio 166.67, tarjeta 0.00, sin clasificar 0.00, no servicio 333.33 | si: reportable 166.67, '
                'excluido 0.00 | pasa no | falta {tin,w9} | listo no; sus partes: directo por_pagar servicio 333.34 | cxp efectivo '
                'no_servicio 333.33 | cxp efectivo servicio 166.67 | el año de enero: servicio 166.67, tarjeta 0.00, sin clasificar '
                '0.00, no servicio 333.34 | si: reportable 166.67, excluido 0.00 | pasa no | falta {tin,w9} | listo no; sus partes: cxp '
                'efectivo no_servicio 333.34 | cxp efectivo servicio 166.67 | los dos años: servicio 333.34 de 333.34, pagado 1000.01 de '
                '1000.01 | el control del reparto de los dos años: verde, verde';
begin
  if pg_temp.c14_omitir(17, 'una cuenta por pagar con material y servicio pagada en diciembre y en enero', v_esp, false, true) then return; end if;
  if pg_temp.c14('dic') is null then
    insert into _pruebas values (17, 'una cuenta por pagar con material y servicio pagada en diciembre y en enero', v_esp,
      'omitida: no hay un diciembre abierto con su enero siguiente abierto', null);
    return;
  end if;
  begin
    select * into v_dic from periodos where periodo = pg_temp.c14('dic');
    v_y := extract(year from v_dic.desde)::int;
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_fingir_hoy(v_dic.hasta + 41);
    v_f := pg_temp.c14_ficha_de('uno');
    v_te := pg_temp.c14_externo(2, 333.34, v_dic.desde + 4, pg_temp.c14_prov('uno'));
    perform pg_temp.c14_postear(v_dic.desde + 4, 'el material de la factura del sub', jsonb_build_array(
              pg_temp.c14_l('5100', 666.67, 'c14-prueba-a'),
              pg_temp.c14_l('2010', -666.67, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', v_te::text)));
    v_m := pg_temp.c14_cargo('c14-t17a', v_dic.desde + 14, 500.00, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    v_m := pg_temp.c14_cargo('c14-t17b', v_dic.hasta + 15, 500.01, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    a := pg_temp.c14_fila(v_f, v_y) || '; sus partes: ' || pg_temp.c14_partes(v_f, v_y);
    b := pg_temp.c14_fila(v_f, v_y + 1) || '; sus partes: ' || pg_temp.c14_partes(v_f, v_y + 1);
    select format('servicio %s de 333.34, pagado %s de 1000.01', sum(p.monto) filter (where p.clase = 'servicio'), sum(p.monto))
      into c from fn_subs_pagos(null) p where p.ficha_id = v_f and p.via = 'cxp';
    d := format('%s, %s', (select case when bool_and(k.ok) then 'verde' else 'rojo' end from fn_subs_control(v_y) k where k.orden in (10, 12)),
                (select case when bool_and(k.ok) then 'verde' else 'rojo' end from fn_subs_control(v_y + 1) k where k.orden in (10, 12)));
    v_obt := format('el año de diciembre: %s | el año de enero: %s | los dos años: %s | el control del reparto de los dos años: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'UNA CUENTA POR PAGAR CON MATERIAL Y SERVICIO, PAGADA EN DICIEMBRE Y EN ENERO (dos años): la factura de un sub con 333.34 de servicio y 666.67 de material contra la misma partida, pagada 500.00 y 500.01: cada pago lleva su parte proporcional de servicio en su año, repartida por acumulado (166.67 y 166.67; el material, 333.33 y 333.34), y los dos años suman el servicio y lo pagado, al centavo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. PAGADO CON TARJETA no se reporta (lo reporta el procesador), y se
--     enseña aparte con su porqué: (a) directo contra una tarjeta de la
--     empresa (2100-XXXX); (b) una cuenta por pagar de servicio pagada con la
--     tarjeta; (c) un recibo cuyo PAPEL dice tarjeta aunque su cuenta sea el
--     banco (la de débito: el puente de c3 deja la regla de la tarjeta en su
--     procedencia).
do $$
declare
  v_obt text; v_f uuid; v_te bigint; v_t text := pg_temp.c14('tarjeta'); a text; b text; c text; v_n text;
  v_esp text := 'directo y a cuenta, con tarjeta: servicio 0.00, tarjeta 550.55, sin clasificar 0.00, no servicio 0.00 | si: reportable '
                '0.00, excluido 550.55 (tarjeta) | pasa no | falta {tin,w9} | listo no | sus partes: directo por_pagar servicio 300.30 | '
                'directo tarjeta servicio 250.25 | cxp tarjeta servicio 300.30 | el recibo pagado con la de débito (sale del banco): '
                'directo tarjeta servicio 150.15';
begin
  if pg_temp.c14_omitir(18, 'pagado con tarjeta', v_esp) then return; end if;
  if v_t is null then
    insert into _pruebas values (18, 'pagado con tarjeta', v_esp, 'omitida: el plan no tiene ninguna tarjeta (subcuenta 2100-XXXX) que reciba asientos', null);
    return;
  end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    -- (en el orden de sus fechas: si el mes acaba de empezar, los días de la prueba se juntan en hoy y manda el orden del libro)
    v_te := pg_temp.c14_externo(3, 300.30, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 250.25, 'proveedor', pg_temp.c14_prov('uno'), v_t, 'pagado con la tarjeta');
    perform pg_temp.c14_postear(pg_temp.c14_d(6), 'su trabajo, pagado con la tarjeta', jsonb_build_array(
              pg_temp.c14_l('2010', 300.30, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', v_te::text),
              pg_temp.c14_l(v_t, -300.30)));
    a := pg_temp.c14_fila(v_f);
    b := pg_temp.c14_partes(v_f);
    -- (c) el recibo de c3 pagado con la tarjeta de débito, que sale de la cuenta del banco
    begin
      perform pg_temp.c14_ser('editor');
      perform fn_tarjeta_alta('9421', '1010', 'C14 PRUEBA débito');
      perform fn_mapeo_confirmar('metodo_pago', 'debito');
      perform fn_mapeo_confirmar('categoria', 'labor_externo');
      insert into recibos (id, proyecto_id, total, proveedor, estado, autor_id, fecha, categoria, metodo_pago, ultimos4, notas) overriding system value
      values (-1400101, 'c14-prueba-a', 150.15, 'ZZ Sub Uno C14 PRUEBA', 'leido', pg_temp.c14('dueno')::uuid, pg_temp.c14_d(4), 'labor_externo',
              'debito', '9421', 'c14-pruebas');
      select string_agg(format('%s %s %s %s', p.via, p.medio, p.clase, p.monto), ' | ') into c
        from fn_subs_pagos(pg_temp.c14_anio()) p where p.origen_tabla = 'recibos' and p.origen_id = '-1400101';
      if c is null then
        select 'el puente de recibos no lo contabilizó aquí (' || coalesce(d.codigo, d.estado, 'sin fila') || ')' into v_n
          from (select 1) z left join puente_documentos d on d.tabla = 'recibos' and d.documento_id = '-1400101';
      end if;
    exception when others then
      v_n := 'esta base no dejó sembrar el recibo (' || sqlstate || ': ' || left(sqlerrm, 200) || ')';
    end;
    v_obt := format('directo y a cuenta, con tarjeta: %s | sus partes: %s | el recibo pagado con la de débito (sale del banco): %s', a, b,
                    coalesce(c, 'directo tarjeta servicio 150.15'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'PAGADO CON TARJETA no se reporta (lo reporta el procesador) y sale aparte con su porqué: directo contra una tarjeta de la empresa, una cuenta por pagar de servicio pagada con la tarjeta, y un recibo cuyo papel dice tarjeta aunque su cuenta sea el banco (la de débito)'
                                   || coalesce(' — OJO: lo del recibo con la de débito no se pudo probar aquí: ' || v_n, ''),
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 19. UN REVERSO RESTA EN EL AÑO DEL REVERSO. (a) En el mismo mes (abierto),
--     c2 lo fecha el mismo día: el pago y su reverso se ven los dos, y suman
--     cero. (b) El reverso de un pago de un año YA CERRADO cae en el año nuevo
--     (c2 lo postea como ajuste de un ejercicio anterior): el año viejo
--     conserva el pago, el nuevo lo resta, y el control lo avisa. Con el reloj
--     fingido y los meses cerrados dentro de la prueba; si el libro real no
--     deja cerrar, esa parte se dice y no cuenta.
do $$
declare
  v_obt text; v_f uuid; v_a uuid; v_dic periodos; v_y int; a text; b text; v_no text; v_q text;
  v_esp_a text := 'en el mismo mes: servicio 0.00, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 0.00, excluido 0.00 '
                  '| pasa no | falta {tin,w9} | listo no; sus partes: directo efectivo servicio 321.12 | directo efectivo servicio -321.12';
  v_esp_b text := 'el de un año cerrado: el año del pago conserva servicio 432.10; el año nuevo, servicio -432.10 (su parte: directo '
                  'efectivo servicio -432.10, un reverso de un pago del año anterior); el control lo avisa: sí';
begin
  if pg_temp.c14_omitir(19, 'un reverso resta en el año del reverso', v_esp_a || ' | ' || v_esp_b) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_a := pg_temp.c14_directo(pg_temp.c14_d(3), 321.12, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_estado(format('select public.fn_reversar(%L, ''C14 PRUEBA: se pagó dos veces'')', v_a));
    a := 'en el mismo mes: ' || pg_temp.c14_fila(v_f) || '; sus partes: ' || pg_temp.c14_partes(v_f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if pg_temp.c14('dic') is null then
    v_no := 'no hay un diciembre abierto con su enero siguiente abierto';
  else
    begin
      select * into v_dic from periodos where periodo = pg_temp.c14('dic');
      v_y := extract(year from v_dic.desde)::int;
      perform pg_temp.c14_ser('editor');
      lock table public.periodos in exclusive mode;
      perform pg_temp.c14_sembrar();
      perform pg_temp.c14_fingir_hoy(v_dic.hasta + 41);
      v_f := pg_temp.c14_ficha_de('uno');
      v_a := pg_temp.c14_directo(v_dic.desde + 9, 432.10, 'proveedor', pg_temp.c14_prov('uno'));
      -- se cierra todo hasta diciembre (la apertura con su asiento, si no lo tiene), como c2-pruebas y c12-pruebas
      begin
        if exists (select 1 from periodos p where p.tipo = 'apertura' and p.estado = 'abierto')
           and not exists (select 1 from asientos x join periodos p on p.periodo = x.periodo
                            where p.tipo = 'apertura' and x.tipo = 'apertura' and x.reversa_a is null
                              and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
          perform fn_postear(jsonb_build_object(
            'tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' and p.estado = 'abierto' order by p.desde limit 1),
            'descripcion', 'C14 PRUEBA: apertura de prueba (se deshace)',
            'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                        jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
        end if;
        for v_q in select p.periodo from periodos p
                    where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_dic.desde order by p.desde loop
          update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
        end loop;
      exception when others then
        v_no := format('el libro no dejó cerrar hasta %s dentro de la prueba (%s: %s)', v_dic.periodo, sqlstate, left(sqlerrm, 300));
      end;
      if v_no is null then
        b := pg_temp.c14_estado(format('select public.fn_reversar(%L, ''C14 PRUEBA: el pago de diciembre no era'')', v_a));
        if b <> 'ok' then
          v_no := 'c2 no dejó reversar el pago del año cerrado (' || b || ')';
        else
          b := format('el de un año cerrado: el año del pago conserva servicio %s; el año nuevo, servicio %s (su parte: %s, %s); el control lo '
                      'avisa: %s',
                      (select r.pagado_servicio::numeric(14,2) from fn_subs_1099(v_y) r where r.ficha_id = v_f),
                      (select r.pagado_servicio::numeric(14,2) from fn_subs_1099(v_y + 1) r where r.ficha_id = v_f),
                      pg_temp.c14_partes(v_f, v_y + 1),
                      (select case when bool_and(p.reverso and p.anio_original = v_y and p.fecha = v_dic.hasta + 1)
                                   then 'un reverso de un pago del año anterior' else 'NO es un reverso del año anterior' end
                         from fn_subs_pagos(v_y + 1) p where p.ficha_id = v_f),
                      (select case when not k.ok and k.detalle like '%1 reverso(s) por -$432.10 que restan pagos de un año anterior%el pago era de ' || v_y || '%'
                                   then 'sí' else 'no: ' || k.detalle end
                         from fn_subs_control(v_y + 1) k where k.orden = 80));
        end if;
      end if;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then b := 'error ' || sqlstate || ': ' || sqlerrm;
    end;
  end if;
  v_obt := a || ' | ' || coalesce(case when v_no is not null then 'omitida: ' || v_no else b end, '?');
  insert into _pruebas values (19, 'UN REVERSO RESTA EN EL AÑO DEL REVERSO: en el mismo mes (abierto) el pago y su reverso se ven los dos y suman cero; el reverso de un pago de un año ya cerrado cae en el año nuevo (su fecha): el año viejo conserva el pago, el nuevo lo resta, y el control lo avisa (el 1099 de aquel año quizá ya se presentó)',
    v_esp_a || ' | ' || v_esp_b, v_obt,
    case when a <> v_esp_a then false when v_no is not null then null else v_obt = v_esp_a || ' | ' || v_esp_b end);
end $$;

-- 20. UN JORNAL DE c10, REPARTIDO: el Zelle a un ayudante dado de alta se
--     reparte por sus horas (c10, por el camino del banco de c6): dos líneas
--     de 5200 con su obra y UNA a la cuenta de lo sin obra, las tres con la
--     persona como tercero «empleado». Las tres son su pago: el 1099 suma el
--     Zelle entero. Deshecho el reparto (su reverso), suma cero.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_j jsonb; r jsonb; v_p uuid := pg_temp.c14('p1')::uuid; v_txt text; v_sin text; v_cta text; a text; b text; c text;
  v_d1 date := pg_temp.c14_d(5); v_d2 date := pg_temp.c14_d(7);
  v_nom text := 'un jornal de c10 repartido (tercero empleado), con su parte sin obra';
  v_esp text := 'sin ficha: sin_ficha, reportable 517.37, le falta {ficha} | con su ficha: servicio 517.37, tarjeta 0.00, sin clasificar '
                '0.00, no servicio 0.00 | si: reportable 517.37, excluido 0.00 | pasa no | falta {tin,w9} | listo no | sus partes: 3, las '
                '3 por jornal y en efectivo, 2 a subcontratos y 1 a la cuenta de lo sin obra, y suman 517.37 | deshecho el reparto: '
                'servicio 0.00';
begin
  if pg_temp.c14('hay_c10') <> 'true' or to_regprocedure('public.fn_jornal_aplicar(uuid,date,date,text,jsonb)') is null then
    insert into _pruebas values (20, v_nom, v_esp, 'omitida: el jornal (c10) no está en esta base', null); return;
  end if;
  if pg_temp.c14_omitir(20, v_nom, v_esp, true, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar(true);
    perform pg_temp.c14_ser('editor');
    insert into costos_equipo (usuario_id, costo_hora) values (v_p, 25) on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, co, notas) overriding system value values
      (-1410000001, v_d1, v_p, 'c14-prueba-a', null, 8, null, 'c14-pruebas'),
      (-1410000002, v_d2, v_p, 'c14-prueba-b', null, 8, null, 'c14-pruebas'),
      (-1410000003, v_d2, v_p, null, null, 4, null, 'c14-pruebas');
    perform pg_temp.c14_ser('dueno');
    -- la cuenta de lo sin obra: la que tenga esta base; si no tiene, una de gasto sin obra
    select c.cuenta_sin_obra, c.cuenta_defecto into v_sin, v_cta from jornal_config c where c.id = 1;
    if v_sin is null then
      v_sin := (fn_jornal_config('{"cuenta_sin_obra": "6400"}'::jsonb))->>'cuenta_sin_obra';
    end if;
    perform fn_jornal_persona(jsonb_build_object('usuario_id', v_p, 'patron', '\mPRUEBA ZZELI\M'));
    perform pg_temp.c14_ser('editor');
    v_m := pg_temp.c14_cargo('c14-t20', pg_temp.c14_d(12), 517.37, 'Zelle payment to C14 PRUEBA ZZELI');
    -- (las personas REALES cuyo patrón casara con este movimiento se aparcan dentro de la prueba, como hace c10-pruebas)
    select fn_jornal_texto(m.desc_norm, m.memo) into v_txt from movimientos_banco m where m.id = v_m;
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    update jornal_personas jp set activa = false where jp.activa and jp.usuario_id <> v_p and v_txt ~* jp.patron;
    perform set_config('mx_jornal.escribe', '', true);
    perform pg_temp.c14_ser('dueno');
    v_j := fn_jornal_propuesta(v_m, v_d1, v_d2, '{}'::jsonb);
    r := fn_jornal_aplicar(v_m, v_d1, v_d2, v_j->>'visto', jsonb_build_object('motivo', 'C14 PRUEBA: jornal de prueba'));
    perform pg_temp.c14_ser('editor');
    select format('%s, reportable %s, le falta {%s}', x.reporta_efectivo, x.reportable::numeric(14,2), array_to_string(x.falta, ',')) into a
      from fn_subs_1099(pg_temp.c14_anio()) x where x.clave = 'empleado:' || v_p::text;
    v_f := pg_temp.c14_ficha(jsonb_build_object('nombre_legal', 'ZZ Eli Legal C14 PRUEBA', 'tipo_entidad', 'individual', 'reporta', 'si',
                                                'direccion', '2 Calle Falsa', 'ciudad', 'Ocala', 'estado', 'FL', 'zip', '34471',
                                                'tercero', jsonb_build_object('tipo', 'empleado', 'id', v_p)));
    b := pg_temp.c14_fila(v_f);
    select format('%s, las %s por jornal y en efectivo, %s a subcontratos y %s a la cuenta de lo sin obra, y suman %s', count(*),
                  count(*) filter (where p.via = 'jornal' and p.medio = 'efectivo' and p.clase = 'servicio'),
                  count(*) filter (where p.cuenta = v_cta), count(*) filter (where p.cuenta = v_sin and p.cuenta <> v_cta), sum(p.monto))
      into c from fn_subs_pagos(pg_temp.c14_anio()) p where p.ficha_id = v_f;
    v_obt := format('sin ficha: %s | con su ficha: %s | sus partes: %s', coalesce(a, 'no sale'), b, c);
    perform pg_temp.c14_ser('dueno');
    perform fn_jornal_deshacer((select jr.id from jornal_repartos jr where jr.movimiento_id = v_m and jr.estado = 'aplicado'), 'C14 PRUEBA: era de otra semana');
    perform pg_temp.c14_ser('editor');
    v_obt := v_obt || ' | deshecho el reparto: servicio ' || (select x.pagado_servicio::numeric(14,2) from fn_subs_1099(pg_temp.c14_anio()) x where x.ficha_id = v_f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'UN JORNAL DE c10, REPARTIDO: el Zelle a un ayudante dado de alta, repartido por sus horas por el camino del banco: dos líneas de 5200 con su obra y una a la cuenta de lo sin obra, las tres con la persona como tercero «empleado»; las tres son su pago y el 1099 suma el Zelle entero (sin ficha, se dice; con su ficha, a su nombre); deshecho el reparto, suma cero',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. A QUIÉN SE LE REPORTA: una corporación (por decidir: vale la regla, no
--     se le reporta); la excepción (una corporación marcada «sí» con su
--     nota); alguien marcado «no» con su porqué; y alguien «por decidir» que
--     no es corporación (sale con lo pagado, le falta decidir, y no está
--     listo). Con el umbral del año en 2000.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_s uuid; a text; b text; c text; d text; e text; v_y int := pg_temp.c14_anio();
  v_esp text := 'una corporación (por decidir): servicio 2200.20, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | no: reportable 0.00, '
                'excluido 2200.20 (corporacion) | pasa no | falta {} | listo no | la excepción (corporación marcada «sí» con su nota): '
                'servicio 2300.30, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 2300.30, excluido 0.00 | pasa sí '
                '| falta {tin,w9} | listo no | marcado «no» con su porqué: servicio 2100.10, tarjeta 0.00, sin clasificar 0.00, no '
                'servicio 0.00 | no: reportable 0.00, excluido 2100.10 (no_se_reporta) | pasa no | falta {} | listo no | por decidir '
                '(no es corporación): servicio 2100.10, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | por_decidir: reportable '
                '2100.10, excluido 0.00 | pasa sí | falta {tin,w9,decidir} | listo no | quitando las corporaciones de la regla, la '
                'primera pasa a: por_decidir, reportable 2200.20';
begin
  if pg_temp.c14_omitir(21, 'a quién se le reporta', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''2000'', ''C14 PRUEBA: el umbral de la prueba'')', v_y));
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"entidades_no_reporta": ["s_corp", "c_corp"]}''::jsonb)');
    v_u := pg_temp.c14_ficha_de('uno', '{"tipo_entidad": "individual"}');
    v_d := pg_temp.c14_ficha_de('dos', '{"tipo_entidad": "c_corp", "reporta": "por_decidir"}');
    v_s := pg_temp.c14_ficha_de('supply', '{"tipo_entidad": "c_corp", "reporta": "si", "reporta_nota": "C14 PRUEBA: servicios legales, lo dijo el CPA"}');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 2100.10, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 2200.20, 'proveedor', pg_temp.c14_prov('dos'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 2300.30, 'proveedor', pg_temp.c14_prov('supply'));
    a := pg_temp.c14_fila(v_d);
    b := pg_temp.c14_fila(v_s);
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_u, 'reporta', 'no', 'reporta_nota', 'C14 PRUEBA: es empleado por Gusto', 'corrige', true));
    c := pg_temp.c14_fila(v_u);
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_u, 'reporta', 'por_decidir', 'reporta_nota', null, 'corrige', true));
    d := pg_temp.c14_fila(v_u);
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"entidades_no_reporta": []}''::jsonb)');
    select format('%s, reportable %s', r.reporta_efectivo, r.reportable::numeric(14,2)) into e from fn_subs_1099(v_y) r where r.ficha_id = v_d;
    v_obt := format('una corporación (por decidir): %s | la excepción (corporación marcada «sí» con su nota): %s | marcado «no» con su '
                    'porqué: %s | por decidir (no es corporación): %s | quitando las corporaciones de la regla, la primera pasa a: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'A QUIÉN SE LE REPORTA: a una corporación no (la regla: sale excluida por «corporacion»); a la excepción sí (una corporación marcada «sí» con su nota); a quien su ficha dice «no» con su porqué, no («no_se_reporta»); quien está «por decidir» y no es corporación sale con lo pagado, le falta decidir y no está listo; y la regla de las corporaciones es de la configuración',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 22. EL UMBRAL JUSTO EN EL BORDE. Con el umbral del año en 2000.00: 1999.99
--     no pasa; un centavo más (2000.00), pasa: se reporta a quien se le pagó
--     el umbral O MÁS. Con la ficha completa (TIN y W-9) queda lista para la
--     hoja. Subiendo el umbral del año a 2000.01, deja de pasar.
do $$
declare
  v_obt text; v_f uuid; a text; b text; c text; v_y int := pg_temp.c14_anio();
  v_esp text := 'con 1999.99: servicio 1999.99, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 1999.99, excluido 0.00 '
                '| pasa no | falta {} | listo no | con un centavo más: servicio 2000.00, tarjeta 0.00, sin clasificar 0.00, no servicio '
                '0.00 | si: reportable 2000.00, excluido 0.00 | pasa sí | falta {} | listo sí | con el umbral del año en 2000.01: pasa '
                'no, listo no';
begin
  if pg_temp.c14_omitir(22, 'el umbral justo en el borde', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''2000'', ''C14 PRUEBA: el umbral de la prueba'')', v_y));
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_f, '000-00-0001');
    perform pg_temp.c14_archivo(v_f, 'w9', 'w9.pdf');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 1999.99, 'proveedor', pg_temp.c14_prov('uno'));
    a := pg_temp.c14_fila(v_f);
    perform pg_temp.c14_directo(pg_temp.c14_d(4), 0.01, 'proveedor', pg_temp.c14_prov('uno'));
    b := pg_temp.c14_fila(v_f);
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''2000.01'', ''C14 PRUEBA: un centavo más'')', v_y));
    select format('pasa %s, listo %s', case when r.pasa_umbral then 'sí' else 'no' end, case when r.listo then 'sí' else 'no' end) into c
      from fn_subs_1099(v_y) r where r.ficha_id = v_f;
    v_obt := format('con 1999.99: %s | con un centavo más: %s | con el umbral del año en 2000.01: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'EL UMBRAL JUSTO EN EL BORDE: con el umbral del año en 2000.00, 1999.99 no pasa y 2000.00 pasa (se reporta a quien se le pagó el umbral o más); con la ficha completa queda lista para la hoja; y con el umbral del año en 2000.01 deja de pasar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. LA MISMA PERSONA COMO EMPLEADO Y COMO PROVEEDOR: una ficha con sus dos
--     terceros; lo pagado a su perfil (como en un jornal) y lo pagado a su
--     proveedor (un trabajo externo) salen en UNA fila: un 1099.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_p uuid := pg_temp.c14('p1')::uuid; a text; b text;
  v_esp text := 'una fila para los dos terceros: 1; servicio 700.30, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable '
                '700.30, excluido 0.00 | pasa no | falta {tin,w9} | listo no | sus partes: directo por_pagar servicio 400.20 | directo '
                'efectivo servicio 300.10 | cxp efectivo servicio 400.20';
begin
  if pg_temp.c14_omitir(23, 'la misma persona como empleado y como proveedor', v_esp, true, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar(true);
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_estado(format('select public.fn_subs_tercero(%L, ''empleado'', %L)', v_f, v_p));
    perform pg_temp.c14_externo(5, 400.20, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 300.10, 'empleado', v_p);
    v_m := pg_temp.c14_cargo('c14-t23', pg_temp.c14_d(6), 400.20, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    a := pg_temp.c14_fila(v_f);
    b := pg_temp.c14_partes(v_f);
    v_obt := format('una fila para los dos terceros: %s; %s | sus partes: %s',
                    (select count(*) from fn_subs_1099(pg_temp.c14_anio()) r
                      where r.ficha_id = v_f or r.clave in ('empleado:' || v_p::text, 'proveedor:' || pg_temp.c14_prov('uno')::text)), a, b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'LA MISMA PERSONA COMO EMPLEADO Y COMO PROVEEDOR: una ficha con sus dos terceros del libro; lo pagado a su perfil y lo pagado a su proveedor salen en una sola fila (un 1099 por persona, no por tercero)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. UN TERCERO SIN FICHA Y UN PAGO SIN TERCERO. El primero sale con su
--     nombre y «le falta su ficha», y el control lo nombra; dársela lo
--     arregla. El segundo (lo normal cuando el pago se clasifica en la
--     Bandeja: la línea no trae tercero) no es de nadie: el control lo dice
--     con su asiento, y ATRIBUIRLO a una ficha (una marca, sin tocar el
--     libro) lo mete en su 1099.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_a uuid; v_b uuid; v_c uuid; v_sug text; v_num text; a text; b text; c text; d text; e text; v_y int := pg_temp.c14_anio();
  v_esp text := 'un tercero sin ficha: sin_ficha, reportable 611.11, le falta {ficha}; el control lo nombra: sí | con su ficha: sale a su '
                'nombre (si, 611.11) y el control ya no lo nombra: sí | un pago sin tercero: no es de nadie, y el control lo dice con su '
                'asiento: sí | atribuido a una ficha: servicio 722.22, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: '
                'reportable 722.22, excluido 0.00 | pasa no | falta {tin,w9} | listo no; el control ya no lo nombra: sí; y el libro no '
                'se tocó: sí | un Zelle sin tercero que nombra a alguien con ficha: la propone (ZZ Uno Legal C14 PRUEBA); el que no '
                'nombra a nadie, no: sí';
begin
  if pg_temp.c14_omitir(24, 'un tercero sin ficha y un pago sin tercero', v_esp, false, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    v_a := pg_temp.c14_directo(pg_temp.c14_d(3), 611.11, 'proveedor', pg_temp.c14_prov('dos'));
    v_b := pg_temp.c14_directo(pg_temp.c14_d(4), 722.22);
    select x.numero into v_num from asientos x where x.id = v_b;
    select format('%s, reportable %s, le falta {%s}', r.reporta_efectivo, r.reportable::numeric(14,2), array_to_string(r.falta, ',')) into a
      from fn_subs_1099(v_y) r where r.clave = 'proveedor:' || pg_temp.c14_prov('dos')::text;
    a := coalesce(a, 'no sale') || '; el control lo nombra: '
         || case when pg_temp.c14_ctl(30) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(30), '%ZZ Sub Dos C14 PRUEBA (servicio pagado $611.11)%') then 'sí' else 'no: ' || pg_temp.c14_ctl_det(30) end;
    v_d := pg_temp.c14_ficha_de('dos');
    select format('sale a su nombre (%s, %s)', r.reporta_efectivo, r.reportable::numeric(14,2)) into b from fn_subs_1099(v_y) r where r.ficha_id = v_d;
    b := coalesce(b, 'no sale') || ' y el control ya no lo nombra: ' || case when pg_temp.c14_ctl_det(30) like '%ZZ Sub Dos C14 PRUEBA%' then 'NO' else 'sí' end;
    c := case when exists (select 1 from fn_subs_pagos(v_y) p where p.asiento_id = v_b and p.ficha_id is null and p.tercero_id is null and p.estado = 'cuenta' and p.monto = 722.22)
                   and exists (select 1 from fn_subs_1099(v_y) r where r.clave = 'sin_tercero' and r.reporta_efectivo = 'sin_tercero' and r.falta = array['tercero']
                                 and r.pagos @> jsonb_build_array(jsonb_build_object('asiento_id', v_b)))
                   and pg_temp.c14_ctl(40) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(40), '%' || v_num || ' del % por $722.22%')
              then 'sí' else 'no: ' || pg_temp.c14_ctl_det(40) end;
    d := pg_temp.c14_conteos();
    perform pg_temp.c14_marcar(v_b, 1, jsonb_build_object('ficha', v_u, 'nota', 'C14 PRUEBA: el Zelle del día 4 era para ZZ Uno'));
    e := pg_temp.c14_fila(v_u) || '; el control ya no lo nombra: ' || case when pg_temp.c14_ctl_det(40) like '%' || v_num || '%' then 'NO' else 'sí' end
         || '; y el libro no se tocó: '
         || case when split_part(split_part(pg_temp.c14_conteos(), 'asientos ', 2), ' · contadores', 1) = split_part(split_part(d, 'asientos ', 2), ' · contadores', 1)
                 then 'sí' else 'NO' end;
    -- un Zelle clasificado en la Bandeja sin tercero, cuya descripción nombra al proveedor de una ficha: se propone esa ficha
    v_c := pg_temp.c14_clasificar(pg_temp.c14_cargo('c14-t24', pg_temp.c14_d(5), 233.33, 'Zelle payment to ZZ SUB UNO C14 PRUEBA'),
                                  jsonb_build_array(pg_temp.c14_l('5200', 233.33, 'c14-prueba-a')));
    v_b := pg_temp.c14_directo(pg_temp.c14_d(5), 244.44);
    select format('la propone (%s); el que no nombra a nadie, no: %s',
                  (select p.sugerencia_ficha from fn_subs_pagos(v_y) p where p.asiento_id = v_c and p.sugerencia_ficha_id = v_u),
                  (select case when p.sugerencia_ficha_id is null and p.ficha_id is null then 'sí' else 'NO' end from fn_subs_pagos(v_y) p where p.asiento_id = v_b))
      into v_sug;
    v_obt := format('un tercero sin ficha: %s | con su ficha: %s | un pago sin tercero: no es de nadie, y el control lo dice con su asiento: '
                    '%s | atribuido a una ficha: %s | un Zelle sin tercero que nombra a alguien con ficha: %s', a, b, c, e, v_sug);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'UN TERCERO SIN FICHA Y UN PAGO SIN TERCERO: el tercero del libro sin ficha sale con su nombre y «le falta su ficha» y el control lo nombra hasta que la tiene; el pago cuya línea no trae tercero no es de nadie, el control lo dice con su asiento, y atribuirlo a una ficha (una marca, sin tocar el libro) lo mete en su 1099',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. LAS MARCAS: «tarjeta» (se pagó con la de débito aunque saliera del
--     banco), «no_servicio» (no cuenta), «servicio» (el material del sub que
--     el CPA dice que cuenta, en 5100); sustituir y quitar (la anterior queda
--     retirada); sus frenos; y el reverso de una línea marcada sigue su marca.
do $$
declare
  v_obt text; v_f uuid; v_a uuid; v_b uuid; v_c uuid; v_d uuid; v_r uuid; a text; b text; c text; d text; e text; g text; h text;
  v_esp text := 'marcado «tarjeta»: servicio 100.10, tarjeta 811.11 | sustituida por «no_servicio»: servicio 100.10, tarjeta 0.00, no '
                'servicio 811.11 (1 viva, 1 retirada por «sustituida») | quitada: servicio 911.21 | el material del sub (5100) marcado '
                '«servicio»: servicio 1133.43 | frenos: la línea del banco MX008, una línea que ya dice de quién es MX008, sin nota 22023, '
                'un trato que no existe 22023, ni ficha ni trato 22023, una línea que no existe 22023, una ficha que no existe 22023, '
                'quitar donde no hay MX008, una clave de más 22023 | el reverso de un pago atribuido sigue su marca: antes 1466.76, '
                'después 1133.43 (su parte: directo efectivo servicio -333.33); marcar el reverso: MX008';
begin
  if pg_temp.c14_omitir(25, 'las marcas', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    v_a := pg_temp.c14_directo(pg_temp.c14_d(3), 811.11, 'proveedor', pg_temp.c14_prov('uno'));
    v_b := pg_temp.c14_directo(pg_temp.c14_d(4), 100.10, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_marcar(v_a, 1, '{"trato": "tarjeta", "nota": "C14 PRUEBA: se pagó con la de débito"}');
    select format('servicio %s, tarjeta %s', r.pagado_servicio::numeric(14,2), r.pagado_tarjeta::numeric(14,2)) into a from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    perform pg_temp.c14_marcar(v_a, 1, '{"trato": "no_servicio", "nota": "C14 PRUEBA: era la devolución de un depósito"}');
    select format('servicio %s, tarjeta %s, no servicio %s', r.pagado_servicio::numeric(14,2), r.pagado_tarjeta::numeric(14,2), r.no_servicio::numeric(14,2)) into b
      from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    b := b || format(' (%s viva, %s retirada por «%s»)', (select count(*) from subs_marcas m where m.asiento_id = v_a and m.retirada_el is null),
                     (select count(*) from subs_marcas m where m.asiento_id = v_a and m.retirada_el is not null),
                     (select max(m.retirada_motivo) from subs_marcas m where m.asiento_id = v_a and m.retirada_el is not null));
    perform pg_temp.c14_marcar(v_a, 1, '{"quitar": true, "nota": "C14 PRUEBA: sí era su pago"}');
    select format('servicio %s', r.pagado_servicio::numeric(14,2)) into c from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    v_c := pg_temp.c14_postear(pg_temp.c14_d(5), 'el material que puso el sub', jsonb_build_array(
             pg_temp.c14_l('5100', 222.22, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')), pg_temp.c14_l('1010', -222.22)));
    perform pg_temp.c14_marcar(v_c, 1, '{"trato": "servicio", "nota": "C14 PRUEBA: el CPA dice que el material de su servicio cuenta"}');
    select format('servicio %s', r.pagado_servicio::numeric(14,2)) into d from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    e := format('la línea del banco %s, una línea que ya dice de quién es %s, sin nota %s, un trato que no existe %s, ni ficha ni trato %s, '
                'una línea que no existe %s, una ficha que no existe %s, quitar donde no hay %s, una clave de más %s',
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 2, ''{"trato": "tarjeta", "nota": "x"}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, %L::jsonb)', v_b, jsonb_build_object('ficha', v_f, 'nota', 'x'))),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"trato": "tarjeta"}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"trato": "regalo", "nota": "x"}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"nota": "x"}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 9, ''{"trato": "tarjeta", "nota": "x"}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, %L::jsonb)', v_c, jsonb_build_object('ficha', gen_random_uuid(), 'nota', 'x'))),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"quitar": true}''::jsonb)', v_b)),
                pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"trato": "tarjeta", "nota": "x", "monto": 5}''::jsonb)', v_b)));
    -- un pago sin tercero, atribuido; y su reverso
    v_d := pg_temp.c14_directo(pg_temp.c14_d(6), 333.33);
    perform pg_temp.c14_marcar(v_d, 1, jsonb_build_object('ficha', v_f, 'nota', 'C14 PRUEBA: era de ZZ Uno'));
    select r.pagado_servicio::numeric(14,2)::text into g from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    perform pg_temp.c14_estado(format('select public.fn_reversar(%L, ''C14 PRUEBA: ese pago no salió'')', v_d));
    select x.id into v_r from asientos x where x.reversa_a = v_d;
    select format('antes %s, después %s (su parte: %s); marcar el reverso: %s', g, r.pagado_servicio::numeric(14,2),
                  (select format('%s %s %s %s', p.via, p.medio, p.clase, p.monto) from fn_subs_pagos(pg_temp.c14_anio()) p where p.asiento_id = v_r and p.ficha_id = v_f),
                  pg_temp.c14_estado(format('select public.fn_subs_marcar(%L, 1, ''{"trato": "no_servicio", "nota": "x"}''::jsonb)', v_r)))
      into h from fn_subs_1099(pg_temp.c14_anio()) r where r.ficha_id = v_f;
    v_obt := format('marcado «tarjeta»: %s | sustituida por «no_servicio»: %s | quitada: %s | el material del sub (5100) marcado «servicio»: '
                    '%s | frenos: %s | el reverso de un pago atribuido sigue su marca: %s', a, b, c, d, e, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'LAS MARCAS: «tarjeta» pasa un pago a lo que reporta el procesador; otra marca la sustituye y la anterior queda retirada; «no_servicio» lo saca; quitarla lo devuelve; «servicio» mete una línea que no lleva la etiqueta (el material del sub); sus frenos (la línea del banco, una línea que ya dice de quién es, sin nota, un trato que no existe, sin nada que marcar, lo que no existe); y el reverso de un pago atribuido sigue su marca (resta de la misma ficha) y no se marca aparte',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. LO PAGADO A UNA PARTIDA SIN PAPEL: (a) de más —se le debían 201.01 y
--     se le pagaron 301.01: c6 deja 100.00 a su favor, en 2010 sin partida—:
--     esos 100.00 no se sabe de qué son y salen «sin clasificar» hasta que
--     Edgar lo dice; (b) lo que traía QuickBooks en la apertura (una deuda
--     sin gasto en el libro), pagado después: igual. Marcado «servicio»,
--     cuenta; marcado «no_servicio», no.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_a uuid; v_o int; a text; b text; c text; d text; v_ap text; v_no text; v_y int := pg_temp.c14_anio();
  v_esp text := 'pagado de más: servicio 201.01, tarjeta 0.00, sin clasificar 100.00, no servicio 0.00 | si: reportable 201.01, excluido 0.00 '
                '| pasa no | falta {tin,w9} | listo no; el control lo dice: sí | marcado «servicio»: servicio 301.01, sin clasificar '
                '0.00; marcado «no_servicio»: servicio 201.01, sin clasificar 0.00, no servicio 100.00 | lo de la apertura, pagado: '
                'sin clasificar 500.50; marcado «servicio»: servicio 500.50, sin clasificar 0.00';
begin
  if pg_temp.c14_omitir(26, 'lo pagado a una partida sin papel', v_esp, false, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_externo(6, 201.01, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    v_m := pg_temp.c14_cargo('c14-t26', pg_temp.c14_d(6), 301.01, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    v_a := pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    a := pg_temp.c14_fila(v_f) || '; el control lo dice: '
         || case when pg_temp.c14_ctl(60) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(60), '%ZZ Uno Legal C14 PRUEBA ($100.00)%') then 'sí' else 'no: ' || pg_temp.c14_ctl_det(60) end;
    select l.orden into v_o from asiento_lineas l where l.asiento_id = v_a and l.cuenta = '2010' and l.partida_tabla is null;
    perform pg_temp.c14_marcar(v_a, v_o, '{"trato": "servicio", "nota": "C14 PRUEBA: era un adelanto de su trabajo"}');
    select format('servicio %s, sin clasificar %s', r.pagado_servicio::numeric(14,2), r.sin_clasificar::numeric(14,2)) into b from fn_subs_1099(v_y) r where r.ficha_id = v_f;
    perform pg_temp.c14_marcar(v_a, v_o, '{"trato": "no_servicio", "nota": "C14 PRUEBA: era un préstamo"}');
    select format('servicio %s, sin clasificar %s, no servicio %s', r.pagado_servicio::numeric(14,2), r.sin_clasificar::numeric(14,2), r.no_servicio::numeric(14,2)) into c
      from fn_subs_1099(v_y) r where r.ficha_id = v_f;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then a := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  -- (b) la apertura: una deuda con el segundo proveedor que traía QuickBooks, y su pago
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('dos');
    begin
      perform pg_temp.c14_ser('editor');
      perform fn_postear(jsonb_build_object(
        'tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' and p.estado = 'abierto' order by p.desde limit 1),
        'descripcion', 'C14 PRUEBA: una deuda que traía QuickBooks (se deshace)',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '3900', 'monto', '500.50'),
                                    pg_temp.c14_l('2010', -500.50, null, 'proveedor', pg_temp.c14_prov('dos')))));
    exception when others then
      v_no := sqlstate || ': ' || left(sqlerrm, 200);
    end;
    if v_no is null then
      v_m := pg_temp.c14_cargo('c14-t26b', pg_temp.c14_d(7), 500.50, 'Zelle payment to C14 PRUEBA ZZ SUB DOS');
      v_a := pg_temp.c14_pagar(v_m, pg_temp.c14_prov('dos'));
      select format('sin clasificar %s', r.sin_clasificar::numeric(14,2)) into v_ap from fn_subs_1099(v_y) r where r.ficha_id = v_f;
      perform pg_temp.c14_marcar(v_a, 2, '{"trato": "servicio", "nota": "C14 PRUEBA: era su trabajo de septiembre"}');
      select coalesce(v_ap, 'no sale') || format('; marcado «servicio»: servicio %s, sin clasificar %s', r.pagado_servicio::numeric(14,2), r.sin_clasificar::numeric(14,2))
        into v_ap from fn_subs_1099(v_y) r where r.ficha_id = v_f;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_ap := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  v_obt := format('pagado de más: %s | marcado «servicio»: %s; marcado «no_servicio»: %s | lo de la apertura, pagado: %s', a, b, c,
                  coalesce(v_ap, 'sin clasificar 500.50; marcado «servicio»: servicio 500.50, sin clasificar 0.00'));
  insert into _pruebas values (26, 'LO PAGADO A UNA PARTIDA SIN PAPEL no se adivina: lo pagado de más (queda a su favor) y lo que traía QuickBooks en la apertura salen «sin clasificar», y el control lo dice, hasta que Edgar marca el pago: «servicio» cuenta, «no_servicio» no'
                                   || coalesce(' — OJO: lo de la apertura no se pudo probar aquí (la apertura de esta base no admite un asiento de prueba: ' || v_no || ')', ''),
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. EL AÑO EN QUE EMPIEZA EL LIBRO ES PARCIAL: cada fila de ese año lo
--     dice (el 1099 de ese año sale de QuickBooks), y la hoja también. Y LO
--     DE ANTES: los trabajos externos fechados antes del libro (papeles, no
--     pagos) salen por quién, para cruzar: en su fila y en la lista.
do $$
declare
  v_obt text; v_f uuid; v_ld date := pg_temp.c14('libro_desde')::date; v_yl int; v_y int := pg_temp.c14_anio(); a text; b text; c text;
  v_esp text := 'la fila del año de las pruebas dice si es parcial como toca: sí | lo de antes del libro: 1 papel por 900.90 a nombre de su '
                'ficha, y en su fila del año del libro; no está en el libro ni en sus pagos: sí | otro papel de antes, de un proveedor '
                'sin ficha: sale con su nombre (ZZ Sub Dos C14 PRUEBA, 1 papel, 77.70)';
begin
  if pg_temp.c14_omitir(27, 'el año en que empieza el libro es parcial, y lo de antes', v_esp) then return; end if;
  begin
    v_yl := extract(year from v_ld)::int;
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 123.45, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_externo(7, 900.90, v_ld - 10, pg_temp.c14_prov('uno'));
    perform pg_temp.c14_externo(8, 77.70, v_ld - 20, pg_temp.c14_prov('dos'));
    select case when r.parcial = (v_y = v_yl and v_ld > make_date(v_yl, 1, 1))
                     and (not r.parcial or r.parcial_texto like 'PARCIAL: el libro de la app empieza el ' || fn_subs_dia(v_ld) || '.%sale de allí.')
                then 'sí' else 'no: ' || r.parcial::text || ' ' || coalesce(r.parcial_texto, '') end
      into a from fn_subs_1099(v_y) r where r.ficha_id = v_f;
    select format('%s papel por %s a nombre de su ficha', x.papeles, x.costo) into b from fn_subs_antes(v_yl) x where x.ficha_id = v_f;
    b := coalesce(b, 'no sale') || case when v_y <> v_yl or (select r.antes_del_libro from fn_subs_1099(v_yl) r where r.ficha_id = v_f) = 900.90
                                        then ', y en su fila del año del libro' else ', y NO en su fila' end
         || '; no está en el libro ni en sus pagos: '
         || case when not exists (select 1 from trabajos_externos t where t.id in (-1400007, -1400008) and t.contabilizado_en is not null)
                      and (select coalesce(sum(p.monto), 0) from fn_subs_pagos(null) p where p.ficha_id = v_f) = 123.45 then 'sí' else 'NO' end;
    select format('sale con su nombre (%s, %s papel, %s)', x.nombre, x.papeles, x.costo) into c
      from fn_subs_antes(v_yl) x where x.proveedor_id = pg_temp.c14_prov('dos') and x.ficha_id is null;
    v_obt := format('la fila del año de las pruebas dice si es parcial como toca: %s | lo de antes del libro: %s | otro papel de antes, de '
                    'un proveedor sin ficha: %s', coalesce(a, 'no sale'), b, coalesce(c, 'no sale'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'EL AÑO EN QUE EMPIEZA EL LIBRO ES PARCIAL (su 1099 sale de QuickBooks): cada fila de ese año lo dice, con desde cuándo hay libro; y lo de antes del libro —los trabajos externos fechados antes, que son papeles y no pagos— sale por quién (en su fila y en la lista para cruzar), sin entrar en el libro ni en sus pagos',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. BAJAR AL ASIENTO: cada parte de la fila lleva su asiento y su línea
--     (existen en el libro, y la línea es la del gasto o la de la cuenta por
--     pagar), y la suma de las partes ES la fila: lo que cuenta, lo de
--     tarjeta y lo que no es servicio.
do $$
declare
  v_obt text; v_f uuid; v_m uuid; v_te bigint; v_t text := pg_temp.c14('tarjeta'); v_y int := pg_temp.c14_anio(); r record;
  v_esp text := 'partes: 4 (las mismas que da la lista de pagos: sí); cada una con su asiento y su línea en el libro: sí; suman la fila: '
                'cuenta 388.89 = servicio 388.89, tarjeta 55.55 = con tarjeta 55.55, no servicio 111.11 = 111.11';
begin
  if pg_temp.c14_omitir(28, 'bajar al asiento', v_esp, false, true) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 166.67, 'proveedor', pg_temp.c14_prov('uno'));
    v_te := pg_temp.c14_externo(9, 222.22, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    perform pg_temp.c14_postear(pg_temp.c14_d(2), 'material en su factura', jsonb_build_array(
              pg_temp.c14_l('5100', 111.11, 'c14-prueba-a'),
              pg_temp.c14_l('2010', -111.11, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', v_te::text)));
    v_m := pg_temp.c14_cargo('c14-t28', pg_temp.c14_d(6), 333.33, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
    perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    if v_t is not null then
      perform pg_temp.c14_directo(pg_temp.c14_d(7), 55.55, 'proveedor', pg_temp.c14_prov('uno'), v_t, 'con la tarjeta');
    else   -- (sin tarjeta en el plan: se marca como tarjeta un pago del banco)
      perform pg_temp.c14_marcar(pg_temp.c14_directo(pg_temp.c14_d(7), 55.55, 'proveedor', pg_temp.c14_prov('uno')), 1,
                                 '{"trato": "tarjeta", "nota": "C14 PRUEBA"}');
    end if;
    select x.* into r from fn_subs_1099(v_y) x where x.ficha_id = v_f;
    v_obt := format('partes: %s (las mismas que da la lista de pagos: %s); cada una con su asiento y su línea en el libro: %s; suman la fila: '
                    'cuenta %s = servicio %s, tarjeta %s = con tarjeta %s, no servicio %s = %s',
                    r.n_pagos,
                    case when r.n_pagos = jsonb_array_length(r.pagos)
                              and r.n_pagos = (select count(*) from fn_subs_pagos(v_y) p where p.ficha_id = v_f and p.medio in ('efectivo', 'tarjeta'))
                         then 'sí' else 'no' end,
                    case when (select bool_and(exists (select 1 from asiento_lineas l join asientos a on a.id = l.asiento_id
                                                        where l.asiento_id = (e->>'asiento_id')::uuid and l.orden = (e->>'orden')::int
                                                          and a.numero = e->>'numero' and l.cuenta = e->>'cuenta' and l.cuenta in ('5200', '2010')))
                                 from jsonb_array_elements(r.pagos) e) then 'sí' else 'no' end,
                    (select sum((e->>'monto')::numeric) from jsonb_array_elements(r.pagos) e where e->>'estado' = 'cuenta'), r.pagado_servicio,
                    (select sum((e->>'monto')::numeric) from jsonb_array_elements(r.pagos) e where e->>'estado' = 'tarjeta'), r.pagado_tarjeta,
                    (select sum((e->>'monto')::numeric) from jsonb_array_elements(r.pagos) e where e->>'estado' = 'no_servicio'), r.no_servicio);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'BAJAR AL ASIENTO: cada parte de una fila del 1099 lleva su asiento y su línea, que existen en el libro (la línea del gasto, o la de la cuenta por pagar que se pagó); son las mismas que da la lista de pagos; y su suma es la fila: lo que cuenta, lo de tarjeta y lo que no es servicio',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL COI
-- ---------------------------------------------------------------------

-- 29. EL COI de quien tuvo servicio (pagado o devengado) entre dos días, a
--     un día: sin COI; «vence en N días» (la cuenta del chip de los
--     documentos de la empresa: días = vence − ese día; avisa con 30);
--     vigente; vencido. Y SI CUBRÍA EL DÍA DEL TRABAJO: un COI vencido hoy
--     cubría el pago de entonces; uno que empezó a valer después, no. El
--     exento de WC con su documento se enseña, y solo cuenta como cubierto
--     si la configuración lo dice. Un tercero sin ficha sale «sin ficha».
do $$
declare
  v_obt text; v_f uuid; v_arch uuid; v_d0 date := pg_temp.c14_d(0); v_d date := pg_temp.c14_d(3); a text; b text; c text; d text; e text; g text; h text; i text;
  v_k text := 'select format(''%s, %s, cubría %s, cubierto %s%s'', k.coi_estado, k.coi_chip, case when k.cubria then ''sí'' else ''no'' end, '
              'case when k.cubierto then ''sí'' else ''no'' end, coalesce('' ('' || k.que_falta || '')'', '''')) '
              'from public.fn_subs_coi($1, $2, $3) k where k.ficha_id = $4';
  v_esp text := 'sin COI: sin_coi, sin COI, cubría no, cubierto no (sin COI) | con un COI que vence a los 10 días: por_vencer, vence en 10 '
                'días, cubría sí, cubierto sí | visto 31 días antes de que venza: vigente, cubría sí | visto después de vencido: vencido, '
                'cubría sí, cubierto sí (cubría el día del pago) | un COI que empezó a valer después del pago: cubría no, cubierto no (su '
                'COI no cubría todos los días con trabajo o pago (mira desde cuándo vale)) | uno que venció antes del pago: vencido, cubría '
                'no (dice cuándo venció y cuándo fue el pago: sí) | exento de WC con su documento, sin COI: exento, cubierto no; si la '
                'configuración dice que basta: cubierto sí (y quien no es exento sigue sin estarlo, sí o no y nunca nulo: sí) | un '
                'tercero sin ficha con trabajo devengado: sin ficha (y sin COI), devengado 88.88, pagado 0.00';
begin
  if pg_temp.c14_omitir(29, 'el COI', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"coi_aviso_dias": 30, "coi_exento_basta": false}''::jsonb)');
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_directo(v_d, 444.44, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_externo(10, 88.88, v_d, pg_temp.c14_prov('dos'));
    execute v_k into a using v_d0, v_d, v_d, v_f;
    v_arch := (pg_temp.c14_archivo(v_f, 'coi', 'coi-a.pdf', jsonb_build_object('vence', (v_d + 10)::text))->'archivo'->>'id')::uuid;
    execute v_k into b using v_d0, v_d, v_d, v_f;
    select format('%s, cubría %s', k.coi_estado, case when k.cubria then 'sí' else 'no' end) into c from fn_subs_coi(v_d0, v_d, v_d - 21) k where k.ficha_id = v_f;
    select format('%s, cubría %s, cubierto %s', k.coi_estado, case when k.cubria then 'sí' else 'no' end, case when k.cubierto then 'sí' else 'no' end) into d
      from fn_subs_coi(v_d0, v_d, v_d + 40) k where k.ficha_id = v_f;
    perform pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: otro'')', v_arch));
    v_arch := (pg_temp.c14_archivo(v_f, 'coi', 'coi-b.pdf', jsonb_build_object('fecha', (v_d + 1)::text, 'vence', (v_d + 300)::text))->'archivo'->>'id')::uuid;
    select format('cubría %s, cubierto %s (%s)', case when k.cubria then 'sí' else 'no' end, case when k.cubierto then 'sí' else 'no' end, k.que_falta) into e
      from fn_subs_coi(v_d0, v_d, v_d) k where k.ficha_id = v_f;
    perform pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: otro'')', v_arch));
    v_arch := (pg_temp.c14_archivo(v_f, 'coi', 'coi-c.pdf', jsonb_build_object('vence', (v_d - 1)::text))->'archivo'->>'id')::uuid;
    select format('%s, cubría %s (dice cuándo venció y cuándo fue el pago: %s)', k.coi_estado, case when k.cubria then 'sí' else 'no' end,
                  case when k.que_falta = format('su COI venció el %s y su último trabajo o pago fue el %s', fn_subs_dia(v_d - 1), fn_subs_dia(v_d))
                       then 'sí' else 'no: ' || k.que_falta end)
      into g from fn_subs_coi(v_d0, v_d, v_d) k where k.ficha_id = v_f;
    perform pg_temp.c14_estado(format('select public.fn_subs_archivo_retirar(%L, ''C14 PRUEBA: otro'')', v_arch));
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_f, 'wc_exento', true));
    perform pg_temp.c14_archivo(v_f, 'wc_exento', 'exento.pdf', jsonb_build_object('vence', (v_d + 300)::text));
    select format('%s, cubierto %s', k.wc_estado, case when k.cubierto then 'sí' else 'no' end) into h from fn_subs_coi(v_d0, v_d, v_d) k where k.ficha_id = v_f;
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"coi_exento_basta": true}''::jsonb)');
    select h || '; si la configuración dice que basta: cubierto ' || case when k.cubierto then 'sí' else 'no' end into h from fn_subs_coi(v_d0, v_d, v_d) k where k.ficha_id = v_f;
    -- (con «al exento le basta» puesto, a quien NO es exento —aquí, el tercero sin ficha— no se le da por cubierto: y «cubierto» es
    --  sí o no en todas las filas, nunca nulo, que un nulo lo callaría en el control y en el cierre)
    select h || ' (y quien no es exento sigue sin estarlo, sí o no y nunca nulo: '
             || case when bool_and(k.cubierto is not null)
                          and coalesce(bool_and(k.cubierto is false) filter (where k.clave = 'proveedor:' || pg_temp.c14_prov('dos')::text), false)
                     then 'sí' else 'NO' end || ')'
      into h from fn_subs_coi(v_d0, v_d, v_d) k;
    select format('%s, devengado %s, pagado %s', k.que_falta, k.devengado::numeric(14,2), k.pagado::numeric(14,2)) into i
      from fn_subs_coi(v_d0, v_d, v_d) k where k.clave = 'proveedor:' || pg_temp.c14_prov('dos')::text;
    v_obt := format('sin COI: %s | con un COI que vence a los 10 días: %s | visto 31 días antes de que venza: %s | visto después de vencido: '
                    '%s (cubría el día del pago) | un COI que empezó a valer después del pago: %s | uno que venció antes del pago: %s | '
                    'exento de WC con su documento, sin COI: %s | un tercero sin ficha con trabajo devengado: %s', a, b, c, d, e, g, h, coalesce(i, 'no sale'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'EL COI de quien tuvo servicio: sin COI; «vence en N días» (días = vence − el día, como el chip de los documentos de la empresa; avisa con 30); vigente; vencido; y si cubría el día del trabajo o del pago (un COI vencido hoy cubría el pago de entonces; uno que empezó a valer después, o que venció antes, no, y dice cuándo); el exento de WC con su documento se enseña y solo basta si la configuración lo dice; y un tercero sin ficha con trabajo devengado sale «sin ficha»',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- LA HOJA DEL 1099
-- ---------------------------------------------------------------------

-- 30. EL CSV: su cabecera (las 15 columnas, en inglés), una línea por ficha
--     lista (se reporta, pasa del umbral y está completa) con el TIN ENTERO y
--     su forma, cada celda entre comillas (las del nombre, dobladas) y CRLF;
--     lo que pasa del umbral y no está completo sale en «pendientes» con su
--     porqué; con «bajo_umbral» entra también quien no llega; y su rastro
--     queda apuntado sin el TIN. (Con el umbral del año en 600.)
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_s uuid; r jsonb; r2 jsonb; v_y int := pg_temp.c14_anio(); a text; b text; c text; d text; e text; v_l text;
  v_esp text;
begin
  v_esp := format('la cabecera: sí | la línea de la ficha lista: "1099-NEC","%s","SSN","000-00-0001","ZZ Uno ""El Rayo"", LLC C14 PRUEBA","ZZ Rayo '
                  'Electric","1 Calle Falsa, Suite 2","","Ocala","FL","34470","US","700.70","0.00","########"; acaba en CRLF: sí | las de '
                  'prueba en la hoja: 1 (la de bajo el umbral y la incompleta, fuera) | pendientes: ZZ Supply Legal C14 PRUEBA (900.90: le '
                  'falta su TIN, su W-9 (el archivo)) | con «bajo_umbral»: 2 de prueba, y entra ZZ Dos Legal C14 PRUEBA con "EIN","00-0000002" y '
                  '"100.10" | su rastro: 1 fila de prueba con sus 4 últimos (0001) y su monto (700.70), sin el TIN: sí | un año sin libro: 22023; '
                  'una opción que no existe: 22023', v_y);
  if pg_temp.c14_omitir(30, 'la hoja del 1099', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''600'', ''C14 PRUEBA: el umbral de la prueba'')', v_y));
    v_u := pg_temp.c14_ficha_de('uno', '{"nombre_legal": "ZZ Uno \"El Rayo\", LLC C14 PRUEBA", "nombre_comercial": "ZZ Rayo Electric", "direccion": "1 Calle Falsa, Suite 2"}');
    v_d := pg_temp.c14_ficha_de('dos');
    v_s := pg_temp.c14_ficha_de('supply');
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_tin(v_d, '00-0000002');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    perform pg_temp.c14_archivo(v_d, 'w9', 'w9.pdf');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 700.70, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 100.10, 'proveedor', pg_temp.c14_prov('dos'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 900.90, 'proveedor', pg_temp.c14_prov('supply'));
    perform pg_temp.c14_ser('dueno');
    r := fn_subs_1099_export(v_y);
    r2 := fn_subs_1099_export(v_y, '{"bajo_umbral": true}'::jsonb);
    perform pg_temp.c14_ser('editor');
    a := case when split_part(r->>'csv', E'\r\n', 1) = '"Form","Tax Year","Recipient TIN Type","Recipient TIN","Recipient Name","Recipient Name Line 2",'
                   '"Address Line 1","Address Line 2","City","State","ZIP","Country","Box 1 Nonemployee Compensation","Box 4 Federal Income Tax Withheld",'
                   '"Account Number"' and jsonb_array_length(r->'columnas') = 15 and r->>'nombre_archivo' = format('1099-NEC-%s.csv', v_y)
              then 'sí' else 'no: ' || split_part(r->>'csv', E'\r\n', 1) end;
    select x.l into v_l from regexp_split_to_table(r->>'csv', E'\r\n') x(l) where x.l like '%ZZ Uno %';
    b := regexp_replace(coalesce(v_l, 'no sale'), '"[0-9a-f]{8}"$', '"########"') || '; acaba en CRLF: ' || case when right(r->>'csv', 2) = E'\r\n' then 'sí' else 'no' end;
    c := format('%s (la de bajo el umbral y la incompleta, fuera)',
                (select count(*) from jsonb_array_elements(r->'filas') f where f->>'Recipient Name' like '%C14 PRUEBA%'));
    select string_agg(format('%s (%s: %s)', p->>'nombre', p->>'monto', p->>'por_que'), '; ' order by p->>'nombre') into d
      from jsonb_array_elements(r->'pendientes') p where p->>'nombre' like '%C14 PRUEBA%';
    select format('%s de prueba, y entra %s con "%s","%s" y "%s"', (select count(*) from jsonb_array_elements(r2->'filas') f where f->>'Recipient Name' like '%C14 PRUEBA%'),
                  f->>'Recipient Name', f->>'Recipient TIN Type', f->>'Recipient TIN', f->>'Box 1 Nonemployee Compensation') into e
      from jsonb_array_elements(r2->'filas') f where f->>'Recipient Name' like 'ZZ Dos %';
    v_obt := format('la cabecera: %s | la línea de la ficha lista: %s | las de prueba en la hoja: %s | pendientes: %s | con «bajo_umbral»: %s | '
                    'su rastro: %s | un año sin libro: %s; una opción que no existe: %s', a, b, c, coalesce(d, 'ninguno'), coalesce(e, 'no entra'),
                    (select format('%s fila de prueba con sus 4 últimos (%s) y su monto (%s), sin el TIN: %s', count(*), max(f->>'tin_ultimos4'), max(f->>'monto'),
                                   case when x.detalle::text ~ '000000001|000-00-0001' or x.huella is null or x.generado_por is null then 'NO' else 'sí' end)
                       from subs_exportaciones x, jsonb_array_elements(x.detalle->'filas') f
                      where x.id = (r->>'exportacion')::uuid and f->>'nombre' like '%C14 PRUEBA%' group by x.id, x.detalle, x.huella, x.generado_por),
                    pg_temp.c14_estado('select public.fn_subs_1099_export(2019)'),
                    pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s, ''{"todo": true}''::jsonb)', v_y)));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'LA HOJA DEL 1099: un CSV con su cabecera (15 columnas genéricas de la 1099-NEC, en inglés), una línea por ficha lista con el TIN entero y su forma, cada celda entre comillas (las del nombre, dobladas; la coma de la dirección, dentro) y CRLF; quien pasa del umbral y no está completo sale en «pendientes» con su porqué; con «bajo_umbral» entra también quien no llega; y queda apuntada, sin el TIN',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 31. LO EXPORTADO Y LO QUE EL LIBRO DICE DESPUÉS: recién exportada, la hoja
--     del año está al día; si después entra otro pago a alguien de la hoja,
--     el control lo dice (con lo exportado y lo de hoy); exportada otra vez,
--     vuelve a estar al día.
do $$
declare
  v_obt text; v_u uuid; v_y int := pg_temp.c14_anio(); a text; b text; c text;
  v_esp text := 'recién exportada: el control no nombra el año | con otro pago después: lo nombra, con lo exportado y lo de hoy: sí | '
                'exportada otra vez: ya no lo nombra';
begin
  if pg_temp.c14_omitir(31, 'lo exportado y lo que el libro dice después', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''600'', ''C14 PRUEBA: el umbral de la prueba'')', v_y));
    v_u := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 700.70, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', v_y));
    a := case when pg_temp.c14_ctl_det(85) like '%' || v_y || ' (exportado el %' then 'LO NOMBRA' else 'el control no nombra el año' end;
    perform pg_temp.c14_directo(pg_temp.c14_d(5), 50.05, 'proveedor', pg_temp.c14_prov('uno'));
    b := case when pg_temp.c14_ctl(85) = 'rojo' and pg_temp.c14_ctl_det(85) ~ (v_y || ' \(exportado el [0-9]+-[a-z]+-[0-9]+: [0-9]+ fila\(s\) por \$[0-9,.]+; hoy: [0-9]+ por \$[0-9,.]+\)')
              then 'sí' else 'no: ' || pg_temp.c14_ctl_det(85) end;
    perform pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', v_y));
    c := case when pg_temp.c14_ctl_det(85) like '%' || v_y || ' (exportado el %' then 'LO SIGUE NOMBRANDO' else 'ya no lo nombra' end;
    v_obt := format('recién exportada: %s | con otro pago después: lo nombra, con lo exportado y lo de hoy: %s | exportada otra vez: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'LO EXPORTADO Y LO QUE EL LIBRO DICE DESPUÉS: recién exportada, la hoja del año está al día; si después entra otro pago a alguien de la hoja, el control lo dice con lo exportado y lo de hoy (si ya se presentó, se pregunta al CPA); exportada otra vez, vuelve a estar al día',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- LOS CONTROLES
-- ---------------------------------------------------------------------

-- 32. El 45 (servicio pagado por otro camino: ni banco, ni tarjeta, ni
--     cuenta por pagar), el 50 (una ficha que se reporta, incompleta), el 55
--     (por decidir con pagos) y el 88 (el umbral del año sin confirmar): en
--     rojo nombrando lo suyo, y de vuelta.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_a uuid; v_num text; v_y int := pg_temp.c14_anio(); a text; b text; c text; d text; v_88 text; v_ya boolean;
  v_s uuid; v_b uuid; v_n2 text; v_np jsonb; v_pp jsonb; e text;
  v_esp text := 'el 45: lo nombra con su asiento: sí; no está en el 1099 de nadie: sí | el 50: nombra la ficha incompleta y lo que le falta: '
                'sí; completa, ya no: sí | el 55: nombra la ficha por decidir con su pago: sí; decidida, ya no: sí | el 88: sin confirmar '
                'está en rojo (o ya estaba confirmado en esta base); confirmado, en verde: sí | las cuentas de la configuración: lo pagado '
                'desde la caja chica cuenta: sí; puesta entre las cuentas que no pagan a nadie, deja de contar y el 45 lo nombra: sí; con '
                'la 2010 fuera de las cuentas por pagar, lo devengado en ella sale por otro camino y el 45 lo nombra: sí; de vuelta, se '
                'sigue hasta su pago: sí';
begin
  if pg_temp.c14_omitir(32, 'los controles 45, 50, 55 y 88', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_ya := exists (select 1 from subs_umbrales u where u.anio = v_y);
    v_88 := pg_temp.c14_ctl(88);
    v_u := pg_temp.c14_ficha_de('uno');
    -- servicio que pagó alguien de su bolsillo (contra aportaciones, 3100)
    v_a := pg_temp.c14_postear(pg_temp.c14_d(3), 'servicio pagado de su bolsillo', jsonb_build_array(
             pg_temp.c14_l('5200', 444.44, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')), pg_temp.c14_l('3100', -444.44)));
    select x.numero into v_num from asientos x where x.id = v_a;
    a := format('lo nombra con su asiento: %s; no está en el 1099 de nadie: %s',
                case when pg_temp.c14_ctl(45) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(45), '%' || v_num || ' por $444.44%') then 'sí' else 'no: ' || pg_temp.c14_ctl_det(45) end,
                case when pg_temp.c14_fila(v_u) = 'sin pagos (devengado 0.00, por otro camino 444.44)' then 'sí' else 'no: ' || pg_temp.c14_fila(v_u) end);
    b := 'nombra la ficha incompleta y lo que le falta: '
         || case when pg_temp.c14_ctl(50) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(50), '%ZZ Uno Legal C14 PRUEBA (le falta su TIN, su W-9 (el archivo))%') then 'sí'
                 else 'no: ' || pg_temp.c14_ctl_det(50) end;
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    b := b || '; completa, ya no: ' || case when pg_temp.c14_ctl_det(50) like '%ZZ Uno Legal C14 PRUEBA%' then 'NO' else 'sí' end;
    v_d := pg_temp.c14_ficha_de('dos', '{"reporta": "por_decidir"}');
    perform pg_temp.c14_directo(pg_temp.c14_d(4), 55.55, 'proveedor', pg_temp.c14_prov('dos'));
    c := 'nombra la ficha por decidir con su pago: '
         || case when pg_temp.c14_ctl(55) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(55), '%ZZ Dos Legal C14 PRUEBA ($55.55)%') then 'sí' else 'no: ' || pg_temp.c14_ctl_det(55) end;
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_d, 'reporta', 'si'));
    c := c || '; decidida, ya no: ' || case when pg_temp.c14_ctl_det(55) like '%ZZ Dos Legal C14 PRUEBA%' then 'NO' else 'sí' end;
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''2000'', ''C14 PRUEBA: lo dijo el CPA'')', v_y));
    d := case when (v_88 = 'rojo' or v_ya) and pg_temp.c14_ctl(88) = 'verde' and pg_temp.c14_ctl_det(88) like '%está confirmado: $2,000.00 («C14 PRUEBA: lo dijo el CPA»%'
              then 'sí' else 'no: antes ' || v_88 || ', después ' || pg_temp.c14_ctl_det(88) end;
    -- LAS CUENTAS DE LA CONFIGURACIÓN mueven el criterio, y el 45 dice lo que queda fuera. (Todo se deshace con la prueba.)
    v_s := pg_temp.c14_ficha_de('supply');
    select to_jsonb(array_remove(g.cuentas_no_pago, '1050')), to_jsonb(array_remove(g.cuentas_por_pagar, '2010')) into v_np, v_pp
      from subs_config g where g.id = 1;
    -- (a) la caja chica (1050): fuera de «las que no pagan a nadie», lo pagado desde ella cuenta; dentro, no (es «otro camino»)
    perform pg_temp.c14_estado(format('select public.fn_subs_config(%L::jsonb)', jsonb_build_object('cuentas_no_pago', v_np)));
    v_b := pg_temp.c14_directo(pg_temp.c14_d(5), 66.66, 'proveedor', pg_temp.c14_prov('supply'), '1050');
    select x.numero into v_n2 from asientos x where x.id = v_b;
    e := 'lo pagado desde la caja chica cuenta: '
         || case when pg_temp.c14_partes(v_s) = 'directo efectivo servicio 66.66' then 'sí' else 'no: ' || pg_temp.c14_partes(v_s) end;
    perform pg_temp.c14_estado(format('select public.fn_subs_config(%L::jsonb)', jsonb_build_object('cuentas_no_pago', v_np || '["1050"]'::jsonb)));
    e := e || '; puesta entre las cuentas que no pagan a nadie, deja de contar y el 45 lo nombra: '
         || case when pg_temp.c14_partes(v_s) = 'directo otro servicio 66.66'
                      and pg_temp.c14_fila(v_s) = 'sin pagos (devengado 0.00, por otro camino 66.66)'
                      and pg_temp.c14_nombra(pg_temp.c14_ctl_det(45), '%' || v_n2 || ' por $66.66%')
                 then 'sí' else 'no: ' || pg_temp.c14_partes(v_s) || ' · ' || pg_temp.c14_fila(v_s) end;
    perform pg_temp.c14_estado(format('select public.fn_subs_config(%L::jsonb)', jsonb_build_object('cuentas_no_pago', v_np)));
    -- (b) la 2010 fuera de «las cuentas por pagar que se siguen»: lo devengado en ella ya no es una deuda que se sigue hasta su
    --     pago (queda como servicio por otro camino, y sin nadie: quien la nombraba era la cuenta por pagar); de vuelta, sí
    perform pg_temp.c14_externo(12, 77.77, pg_temp.c14_d(5), pg_temp.c14_prov('supply'));
    select x.numero into v_n2 from asientos x where x.origen_tabla = 'trabajos_externos' and x.origen_id = '-1400012';
    perform pg_temp.c14_estado(format('select public.fn_subs_config(%L::jsonb)', jsonb_build_object('cuentas_por_pagar', v_pp)));
    e := e || '; con la 2010 fuera de las cuentas por pagar, lo devengado en ella sale por otro camino y el 45 lo nombra: '
         || case when pg_temp.c14_partes(v_s) = 'directo efectivo servicio 66.66' and v_n2 is not null
                      and pg_temp.c14_nombra(pg_temp.c14_ctl_det(45), '%' || v_n2 || ' por $77.77%')
                 then 'sí' else 'no: ' || pg_temp.c14_partes(v_s) || ' · ' || coalesce(v_n2, 'sin asiento') end;
    perform pg_temp.c14_estado(format('select public.fn_subs_config(%L::jsonb)', jsonb_build_object('cuentas_por_pagar', v_pp || '["2010"]'::jsonb)));
    e := e || '; de vuelta, se sigue hasta su pago: '
         || case when pg_temp.c14_partes(v_s) = 'directo efectivo servicio 66.66 | directo por_pagar servicio 77.77'
                      and pg_temp.c14_ctl_det(45) not like '%' || v_n2 || ' por $77.77%'
                 then 'sí' else 'no: ' || pg_temp.c14_partes(v_s) end;
    v_obt := format('el 45: %s | el 50: %s | el 55: %s | el 88: sin confirmar está en rojo (o ya estaba confirmado en esta base); confirmado, en '
                    'verde: %s | las cuentas de la configuración: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'LOS CONTROLES 45, 50, 55 Y 88: el servicio que no salió del banco, de una tarjeta ni está en una cuenta por pagar se dice con su asiento (y no está en el 1099 de nadie); la ficha que se reporta e incompleta se nombra con lo que le falta, hasta que se completa; la ficha por decidir con pagos, hasta que se decide; el umbral del año, hasta que se confirma con su nota; y LAS CUENTAS DE LA CONFIGURACIÓN mueven el criterio: una cuenta de caja puesta entre las que no pagan a nadie deja de contar como pago, y una cuenta por pagar fuera de la lista deja de seguirse hasta su pago (el 45 nombra lo que queda fuera)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. El 20 (las fichas coherentes: un tercero que ya no existe; y, desde el
--     SQL Editor, un TIN que no casa con su ficha), el 90 (las protecciones:
--     un permiso de más, una guarda apagada, el candado del TIN quitado, una
--     vista sobre el TIN, un candado del bucket quitado) y el 95 (un archivo
--     que ya no está en Storage): cada uno en rojo diciendo qué, y de vuelta.
do $$
declare
  v_obt text; v_f uuid; v_r text; a text; b text; c text; x text; v_90 text := ''; v_s boolean := pg_temp.c14('hay_storage') = 'true';
  v_20 text; v_900 text; v_95 text;
  v_esp text := 'el 20: un tercero que ya no existe: rojo, lo dice; un TIN que no casa con su ficha (desde el SQL Editor): rojo, lo dice; '
                'de vuelta: como estaba | el 90: un permiso para la llave pública: rojo; una guarda apagada: rojo; sin el candado '
                'restrictivo del TIN: rojo; una vista sobre el TIN: rojo; una función con permisos de dueño: rojo; un candado del bucket '
                'quitado: rojo; de vuelta: como estaba | el 95: un archivo que ya no está en Storage: rojo, lo nombra; de vuelta: como '
                'estaba';
begin
  if pg_temp.c14_omitir(33, 'los controles 20, 90 y 95', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_f := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_f, '000-00-0001');
    perform pg_temp.c14_archivo(v_f, 'w9', 'w9.pdf');
    v_r := v_f::text || '/w9/w9.pdf';
    v_20 := pg_temp.c14_ctl(20); v_900 := pg_temp.c14_ctl(90); v_95 := pg_temp.c14_ctl(95);
    -- 20
    begin
      perform set_config('mx_subs.escribe', 'subs_terceros', true);
      insert into subs_terceros (tercero_tipo, tercero_id, ficha_id) values ('proveedor', gen_random_uuid(), v_f);
      perform set_config('mx_subs.escribe', '', true);
      a := 'un tercero que ya no existe: ' || pg_temp.c14_ctl(20) || case when pg_temp.c14_nombra(pg_temp.c14_ctl_det(20), '%la ficha de ZZ Uno Legal C14 PRUEBA tiene enlazado un proveedor que ya no existe%') then ', lo dice' else ', NO lo dice' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      perform set_config('mx_subs.escribe', 'subs_fichas', true);
      update subs_fichas set tin_ultimos4 = '9999' where id = v_f;
      perform set_config('mx_subs.escribe', '', true);
      a := a || '; un TIN que no casa con su ficha (desde el SQL Editor): ' || pg_temp.c14_ctl(20)
           || case when pg_temp.c14_nombra(pg_temp.c14_ctl_det(20), '%hay un TIN guardado para la ficha de ZZ Uno Legal C14 PRUEBA y su ficha no lo dice (o dice otros 4 últimos)%')
                        and pg_temp.c14_ctl_det(20) !~ '000000001|000-00-0001' then ', lo dice' else ', NO lo dice (o enseña el TIN)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    a := a || '; de vuelta: ' || case when pg_temp.c14_ctl(20) = v_20 then 'como estaba' else 'NO: ' || pg_temp.c14_ctl(20) end;
    -- 90: cada rotura, en su subtransacción
    foreach x in array array[
      'un permiso para la llave pública|grant select on public.subs_fichas to anon|anon puede select en subs_fichas',
      'una guarda apagada|alter table public.subs_tin disable trigger trg_subs_tin_guarda|a la tabla subs_tin le falta su guarda',
      'sin el candado restrictivo del TIN|drop policy subs_tin_solo_asi on public.subs_tin|al TIN le falta su candado restrictivo',
      'una vista sobre el TIN|create view public.zz_c14_tin as select t.ficha_id, right(t.tin, 4) as u from public.subs_tin t|zz_c14_tin lee la tabla del TIN',
      'una función con permisos de dueño|alter function public.fn_subs_fichas(uuid) security definer|la función fn_subs_fichas corre con permisos de dueño'] loop
      begin
        execute split_part(x, '|', 2);
        v_90 := v_90 || split_part(x, '|', 1) || ': ' || pg_temp.c14_ctl(90)
                || case when pg_temp.c14_ctl_det(90) like '%' || split_part(x, '|', 3) || '%' then '' else ' (NO dice qué: ' || left(pg_temp.c14_ctl_det(90), 200) || ')' end || '; ';
        raise exception using errcode = 'MXT01';
      exception when sqlstate 'MXT01' then null;
      end;
    end loop;
    if v_s then
      begin
        drop policy "subs: no se borra" on storage.objects;
        v_90 := v_90 || 'un candado del bucket quitado: ' || pg_temp.c14_ctl(90)
                || case when pg_temp.c14_ctl_det(90) like '%el bucket de los subs: falta su candado «subs: no se borra»%' then '' else ' (NO dice qué)' end || '; ';
        raise exception using errcode = 'MXT01';
      exception when sqlstate 'MXT01' then null;
      end;
    else
      v_90 := v_90 || 'un candado del bucket quitado: rojo; ';
    end if;
    b := v_90 || 'de vuelta: ' || case when pg_temp.c14_ctl(90) = v_900 then 'como estaba' else 'NO: ' || pg_temp.c14_ctl(90) end;
    -- 95
    if v_s then
      c := 'un archivo que ya no está en Storage: ';
      begin
        perform set_config('storage.allow_delete_query', 'true', true);
        delete from storage.objects o where o.bucket_id = 'subs' and o.name = v_r;
        c := c || pg_temp.c14_ctl(95) || case when pg_temp.c14_nombra(pg_temp.c14_ctl_det(95), '%' || v_r || ' (ya no está)%') then ', lo nombra' else ', NO lo nombra' end;
        raise exception using errcode = 'MXT01';
      exception when sqlstate 'MXT01' then null;
      end;
      c := c || '; de vuelta: ' || case when pg_temp.c14_ctl(95) = v_95 then 'como estaba' else 'NO: ' || pg_temp.c14_ctl(95) end;
    else
      c := 'un archivo que ya no está en Storage: rojo, lo nombra; de vuelta: como estaba';
    end if;
    v_obt := format('el 20: %s | el 90: %s | el 95: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'LOS CONTROLES 20, 90 Y 95: un tercero enlazado que ya no existe y un TIN que no casa con su ficha (esto, desde el SQL Editor, y sin enseñar el TIN) ponen el 20 en rojo; un permiso para la llave pública, una guarda apagada, el TIN sin su candado restrictivo, una vista sobre el TIN, una función con permisos de dueño o un candado del bucket quitado ponen el 90 en rojo diciendo cuál; y un archivo registrado que ya no está en Storage, el 95; cada uno vuelve a verde'
                                   || case when not v_s then ' (esta base no tiene Storage: lo del bucket y lo del archivo no se pudo mirar aquí)' else '' end,
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. LAS DOS FILAS DEL CIERRE (fn_subs_cierre) del mes de las pruebas: 160
--     (el COI de cada uno con servicio en el mes, vigente el día de su
--     trabajo o de su pago) y 179 (el W-9 y el TIN de cada uno con un PAGO en
--     el mes). Avisos las dos, con qué hacer y a qué página ir. Quien tiene
--     todo no sale; a quien su ficha dice que no se le reporta no se le pide
--     W-9 (pero sí su COI). Un período que no es un mes: nada.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_mes text := pg_temp.c14('mes'); v_dia date := pg_temp.c14_d(3); a text; b text; c text; d text; e text; g text;
  v_esp text := 'dos filas, 160 y 179, avisos, con ir_a = subs: sí | la 160 nombra al que no tiene ficha y no al que tiene su COI: sí | la 179 '
                'nombra al que no tiene ficha (con lo pagado) y no al que tiene su W-9 y su TIN: sí; y no a quien solo tiene trabajo '
                'devengado: sí | con su ficha marcada «no se reporta»: la 179 ya no lo nombra y la 160 sigue (sin COI): sí | con «al '
                'exento de WC le basta su documento» puesto, la 160 sigue nombrando a quien no tiene COI ni es exento: sí | en rojo dicen '
                'qué hacer: sí | para el año entero: 0 filas; para un período que no existe: 0 filas';
begin
  if pg_temp.c14_omitir(34, 'las dos filas del cierre', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    perform pg_temp.c14_archivo(v_u, 'coi', 'coi.pdf', jsonb_build_object('vence', (v_dia + 200)::text));
    perform pg_temp.c14_directo(v_dia, 311.11, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(v_dia, 422.22, 'proveedor', pg_temp.c14_prov('dos'));
    perform pg_temp.c14_externo(11, 99.99, v_dia, pg_temp.c14_prov('supply'));
    select case when count(*) = 2 and bool_and(k.nivel = 'aviso' and k.ir_a = 'subs') and array_agg(k.orden order by k.orden) = array[160, 179]
                     and min(k.control) filter (where k.orden = 160) = 'subs: COI vigente de cada sub pagado en el mes'
                     and min(k.control) filter (where k.orden = 179) = 'subs: W-9 y TIN de cada sub con pago en el mes'
                then 'sí' else 'no' end into a from fn_subs_cierre(v_mes) k;
    select case when not k.ok and pg_temp.c14_nombra(k.detalle, '%ZZ Sub Dos C14 PRUEBA (sin ficha (y sin COI))%') and k.detalle not like '%ZZ Uno Legal C14 PRUEBA%'
                then 'sí' else 'no: ' || k.detalle end into b from fn_subs_cierre(v_mes) k where k.orden = 160;
    select case when not k.ok and pg_temp.c14_nombra(k.detalle, '%ZZ Sub Dos C14 PRUEBA (sin ficha; pagado $422.22)%') and k.detalle not like '%ZZ Uno Legal C14 PRUEBA%' then 'sí'
                else 'no: ' || k.detalle end || '; y no a quien solo tiene trabajo devengado: ' || case when k.detalle like '%ZZ Supply C14 PRUEBA%' then 'NO' else 'sí' end
      into c from fn_subs_cierre(v_mes) k where k.orden = 179;
    select case when bool_and(k.que_hacer like '%Contabilidad → Subs y 1099%') then 'sí' else 'no' end into e from fn_subs_cierre(v_mes) k where not k.ok;
    v_d := pg_temp.c14_ficha_de('dos', '{"reporta": "no", "reporta_nota": "C14 PRUEBA: es empleado por Gusto"}');
    select case when (select k.detalle not like '%ZZ Dos Legal C14 PRUEBA%' and k.detalle not like '%ZZ Sub Dos C14 PRUEBA%' from fn_subs_cierre(v_mes) k where k.orden = 179)
                     and (select pg_temp.c14_nombra(k.detalle, '%ZZ Dos Legal C14 PRUEBA (sin COI)%') from fn_subs_cierre(v_mes) k where k.orden = 160)
                then 'sí' else 'no' end into d;
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"coi_exento_basta": true}''::jsonb)');
    select case when not k.ok and pg_temp.c14_nombra(k.detalle, '%ZZ Dos Legal C14 PRUEBA (sin COI)%') and k.detalle not like '%ZZ Uno Legal C14 PRUEBA%'
                then 'sí' else 'no: ' || k.detalle end into g from fn_subs_cierre(v_mes) k where k.orden = 160;
    v_obt := format('dos filas, 160 y 179, avisos, con ir_a = subs: %s | la 160 nombra al que no tiene ficha y no al que tiene su COI: %s | la '
                    '179 nombra al que no tiene ficha (con lo pagado) y no al que tiene su W-9 y su TIN: %s | con su ficha marcada «no se '
                    'reporta»: la 179 ya no lo nombra y la 160 sigue (sin COI): %s | con «al exento de WC le basta su documento» puesto, la '
                    '160 sigue nombrando a quien no tiene COI ni es exento: %s | en rojo dicen qué hacer: %s | para el año entero: %s filas; '
                    'para un período que no existe: %s filas', a, b, c, d, g, e,
                    (select count(*) from fn_subs_cierre(left(v_mes, 4))), (select count(*) from fn_subs_cierre('1999-01')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'LAS DOS FILAS DEL CIERRE: 160 «subs: COI vigente de cada sub pagado en el mes» nombra a quien tuvo servicio en el mes sin su COI vigente ese día (o sin ficha), y 179 «subs: W-9 y TIN de cada sub con pago en el mes» a quien cobró sin su W-9 o su TIN (no a quien solo tiene trabajo devengado, ni a quien su ficha dice que no se le reporta); las dos son avisos con qué hacer y la página; quien tiene todo no sale; y para un período que no es un mes no hay filas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. EL CIERRE (c9) MIRA LOS SUBS: con el bloque de c14 en
--     fn_cierre_revisar, la revisión del mes trae la 160 y la 179 de esta
--     capa (una de cada, avisos, con el mismo detalle), y no detienen.
--     «omitida» mientras c9-cierre.sql no traiga ese bloque.
do $$
declare
  v_obt text; v_mes text := pg_temp.c14('mes');
  v_esp text := 'la revisión del mes trae una 160 y una 179, avisos, con el detalle de esta capa: sí | ninguna de las dos detiene: sí';
begin
  if pg_temp.c14('hay_c9') <> 'true' then
    insert into _pruebas values (35, 'el cierre (c9) mira los subs', v_esp, 'omitida: el cierre (c9) no está en esta base', null); return;
  end if;
  if pg_temp.c14('c9_subs') <> 'true' then
    insert into _pruebas values (35, 'el cierre (c9) mira los subs', v_esp,
      'omitida: el c9-cierre.sql de esta base todavía no pide las filas de los subs a esta capa (su 160 es la de antes y no trae la 179): vuelve a pegar c9-cierre.sql y después estas pruebas', null);
    return;
  end if;
  if pg_temp.c14_omitir(35, 'el cierre (c9) mira los subs', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 422.22, 'proveedor', pg_temp.c14_prov('dos'));
    select format('la revisión del mes trae una 160 y una 179, avisos, con el detalle de esta capa: %s | ninguna de las dos detiene: %s',
                  case when count(*) = 2 and count(*) filter (where k.orden = 160) = 1 and bool_and(k.nivel = 'aviso' and k.ir_a = 'subs')
                            and bool_and(k.detalle = left(s.detalle, 1500) and k.control = s.control and k.ok = s.ok)
                            and bool_or(pg_temp.c14_nombra(k.detalle, '%ZZ Sub Dos C14 PRUEBA%')) then 'sí' else 'no' end,
                  case when bool_and(k.nivel <> 'detiene') then 'sí' else 'no' end)
      into v_obt
      from fn_cierre_revisar(v_mes) k
      join fn_subs_cierre(v_mes) s on s.orden = k.orden
     where k.orden in (160, 179);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'EL CIERRE (c9) MIRA LOS SUBS: la revisión del mes trae la fila 160 y la 179 de esta capa (una de cada, avisos, con su mismo detalle), y ninguna detiene el cierre',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. LOS TEXTOS, EN LLANO: ni el detalle de un control (en verde o en
--     rojo), ni lo que dicen las filas del cierre, ni lo que le falta a una
--     ficha, ni el porqué de lo excluido nombran una función ni una tabla.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_txt text; v_n int; v_y int := pg_temp.c14_anio();
  v_esp text := 'textos mirados: más de 30; con el nombre de una función o de una tabla: ninguno';
begin
  if pg_temp.c14_omitir(36, 'los textos, en llano', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno', '{"reporta": "por_decidir"}');
    v_d := pg_temp.c14_ficha_de('dos', '{"tipo_entidad": "c_corp", "reporta": "por_decidir"}');
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 311.11, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 322.22, 'proveedor', pg_temp.c14_prov('dos'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 333.33, 'proveedor', pg_temp.c14_prov('supply'));
    perform pg_temp.c14_directo(pg_temp.c14_d(3), 344.44);
    if pg_temp.c14('tarjeta') is not null then
      perform pg_temp.c14_directo(pg_temp.c14_d(3), 355.55, 'proveedor', pg_temp.c14_prov('dos'), pg_temp.c14('tarjeta'));
    end if;
    perform pg_temp.c14_postear(pg_temp.c14_d(3), 'de su bolsillo', jsonb_build_array(
              pg_temp.c14_l('5200', 44.44, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')), pg_temp.c14_l('3100', -44.44)));
    select count(*), string_agg(z.t, ' ¶ ') filter (where z.t ~ '\mfn_[a-z0-9_]+|\msubs_[a-z_]+|\mv_subs_[a-z0-9_]+|\masiento_lineas\M|\mjornal_[a-z]+')
      into v_n, v_txt
      from (select k.detalle as t from fn_subs_control(v_y) k
            union all select k.control from fn_subs_control(v_y) k
            union all select k.detalle from fn_subs_cierre(pg_temp.c14('mes')) k
            union all select k.que_hacer from fn_subs_cierre(pg_temp.c14('mes')) k where k.que_hacer is not null
            union all select f.falta_texto from fn_subs_fichas(null) f where f.falta_texto is not null and f.ficha_id in (v_u, v_d)
            union all select f.reporta_texto from fn_subs_fichas(null) f where f.ficha_id in (v_u, v_d)
            union all select r.falta_texto from fn_subs_1099(v_y) r where r.falta_texto is not null
            union all select r.parcial_texto from fn_subs_1099(v_y) r where r.parcial_texto is not null
            union all select e->>'texto' from fn_subs_1099(v_y) r, jsonb_array_elements(r.excluido_por) e
            union all select k.que_falta from fn_subs_coi(null, null, null) k where k.que_falta is not null) z;
    v_obt := format('textos mirados: %s; con el nombre de una función o de una tabla: %s',
                    case when v_n > 30 then 'más de 30' else v_n::text end, coalesce(left(v_txt, 600), 'ninguno'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'LOS TEXTOS, EN LLANO: el detalle de cada control (con varios en rojo), lo que dicen las filas del cierre, lo que le falta a una ficha, por qué se le reporta o no, el porqué de lo excluido y lo del COI no nombran ninguna función ni ninguna tabla',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL CIERRE DE LA SUITE
-- ---------------------------------------------------------------------

-- =====================================================================
-- LO QUE ENCONTRARON LAS DOS REVISIONES DE LA FASE 12a (37 a 45): cada una
-- falla con la capa de antes y pasa con la arreglada.
-- =====================================================================

-- 37. LO QUE PASA DE UNA CUENTA POR PAGAR A OTRA HEREDA SU COMPOSICIÓN. (1) LA
--     RETENCIÓN: un trabajo externo de 1000.01 (servicio), del que 100.01 se
--     separan a la 2020 a mano (Dr 2010 con su partida / Cr 2020 con su
--     tercero); se pagan 900.00 y después los 100.01: el 1099 dice 1000.01
--     (antes, 900.00 y «no es servicio» 100.01). (2) EL ANTICIPO: se le pagan
--     3000.03 a un sub antes de su papel (queda sin clasificar, y el control
--     lo dice); llega su trabajo y se cruza el anticipo (Dr 2010 con su
--     partida / Cr 2010 sin ella): pasa a servicio pagado (antes pasaba a «no
--     es servicio» y el sub desaparecía del 1099).
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_te bigint; v_te2 bigint; a text; b text; c text; d text;
  v_esp text := 'la retención: servicio 1000.01, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 1000.01, excluido 0.00 | '
                'pasa no | falta {tin,w9} | listo no; sus partes: directo por_pagar servicio 1000.01 | cxp efectivo servicio 900.00 | cxp '
                'efectivo servicio 100.01 | el anticipo, antes de su papel: servicio 0.00, tarjeta 0.00, sin clasificar 3000.03, no servicio '
                '0.00 | si: reportable 0.00, excluido 0.00 | pasa no | falta {tin,w9} | listo no; el control lo nombra: sí | cruzado con su '
                'papel: servicio 3000.03, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 3000.03, excluido 0.00 | pasa '
                'sí | falta {tin,w9} | listo no; el control ya no lo nombra: sí | los cuadres del reparto: nada nuevo en rojo';
begin
  if pg_temp.c14_omitir(37, 'lo que pasa de una cuenta por pagar a otra hereda su composición', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    v_d := pg_temp.c14_ficha_de('dos');
    v_te := pg_temp.c14_externo(31, 1000.01, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    perform pg_temp.c14_postear(pg_temp.c14_d(3), 'la retención del sub uno, a la 2020', jsonb_build_array(
              pg_temp.c14_l('2010', 100.01, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', v_te::text),
              pg_temp.c14_l('2020', -100.01, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno'))));
    perform pg_temp.c14_postear(pg_temp.c14_d(4), 'el pago del trabajo', jsonb_build_array(
              pg_temp.c14_l('2010', 900.00, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', v_te::text),
              pg_temp.c14_l('1010', -900.00)));
    perform pg_temp.c14_postear(pg_temp.c14_d(6), 'se suelta la retención', jsonb_build_array(
              pg_temp.c14_l('2020', 100.01, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')),
              pg_temp.c14_l('1010', -100.01)));
    a := pg_temp.c14_fila(v_u) || '; sus partes: ' || pg_temp.c14_partes(v_u);
    perform pg_temp.c14_postear(pg_temp.c14_d(5), 'el anticipo al sub dos', jsonb_build_array(
              pg_temp.c14_l('2010', 3000.03, null, 'proveedor', pg_temp.c14_prov('dos')), pg_temp.c14_l('1010', -3000.03)));
    b := pg_temp.c14_fila(v_d) || '; el control lo nombra: '
         || case when pg_temp.c14_ctl(60) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(60), '%ZZ Dos Legal C14 PRUEBA ($3,000.03)%') then 'sí'
                 else 'no: ' || pg_temp.c14_ctl_det(60) end;
    v_te2 := pg_temp.c14_externo(32, 3000.03, pg_temp.c14_d(7), pg_temp.c14_prov('dos'));
    perform pg_temp.c14_postear(pg_temp.c14_d(8), 'se cruza el anticipo con su trabajo', jsonb_build_array(
              pg_temp.c14_l('2010', 3000.03, null, 'proveedor', pg_temp.c14_prov('dos'), 'trabajos_externos', v_te2::text),
              pg_temp.c14_l('2010', -3000.03, null, 'proveedor', pg_temp.c14_prov('dos'))));
    c := pg_temp.c14_fila(v_d) || '; el control ya no lo nombra: '
         || case when pg_temp.c14_ctl_det(60) like '%ZZ Dos Legal C14 PRUEBA%' then 'NO' else 'sí' end;
    d := pg_temp.c14_propios();
    v_obt := format('la retención: %s | el anticipo, antes de su papel: %s | cruzado con su papel: %s | los cuadres del reparto: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'LO QUE PASA DE UNA CUENTA POR PAGAR A OTRA HEREDA SU COMPOSICIÓN: la retención separada a mano de la cuenta del sub (2010 → 2020) y pagada después cuenta como servicio (el 1099 da el trabajo entero, no el trabajo menos la retención); y el anticipo que se cruza con su papel pasa de «sin clasificar» a servicio pagado (el sub no desaparece del 1099)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. NADA SE QUEDA FUERA CALLADO. (a) La retención de un sub que se le
--     devuelve SIN decir a quién (lo que deja la Bandeja al clasificar a la
--     2020, que no pide proveedor): sale en la fila «sin tercero», el control
--     lo dice y la hoja lo trae entre sus pendientes y sus avisos (y no está
--     «completa»); atribuida a su ficha, hereda lo que era y cuenta entera.
--     (b) El pago a mano de la partida de un sub sin decir el tercero en la
--     línea: es del tercero de su partida. (c) Un anticipo a alguien SIN
--     ficha: sale con su nombre, y los controles lo dicen.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_a uuid; v_te bigint; v_h jsonb; a text; b text; c text; d text; e text; v_num text;
  v_y int := pg_temp.c14_anio();
  v_esp text := 'la retención devuelta sin decir a quién: la fila sin tercero la trae (sin clasificar 1000.01): sí; el control lo dice con su '
                'asiento: sí; la hoja la trae entre sus pendientes: sí, entre sus avisos: sí, y no está completa: sí | atribuida a su ficha: '
                'servicio 10000.10, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 10000.10, excluido 0.00 | pasa sí | '
                'falta {tin,w9} | listo no | la partida de un sub pagada a mano sin decir de quién: servicio 2400.24, tarjeta 0.00, sin '
                'clasificar 0.00, no servicio 0.00 | si: reportable 2400.24, excluido 0.00 | pasa sí | falta {tin,w9} | listo no | un anticipo '
                'a alguien sin ficha: sin_ficha, sin clasificar 350.35, le falta {ficha}; lo dicen el control de los sin ficha y el de lo sin '
                'clasificar: sí';
begin
  if pg_temp.c14_omitir(38, 'nada se queda fuera callado', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    v_d := pg_temp.c14_ficha_de('dos');
    -- (a) la factura de 10000.10 con 1000.01 retenidos, y la retención devuelta sin decir a quién
    perform pg_temp.c14_postear(pg_temp.c14_d(2), 'la factura del sub uno con su retención', jsonb_build_array(
              pg_temp.c14_l('5200', 10000.10, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')),
              pg_temp.c14_l('1010', -9000.09),
              pg_temp.c14_l('2020', -1000.01, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno'))));
    v_a := pg_temp.c14_postear(pg_temp.c14_d(6), 'cheque de la retención, sin decir de quién', jsonb_build_array(
              pg_temp.c14_l('2020', 1000.01, 'c14-prueba-a'), pg_temp.c14_l('1010', -1000.01)));
    select x.numero into v_num from asientos x where x.id = v_a;
    perform pg_temp.c14_ser('dueno');
    v_h := fn_subs_1099_export(v_y, '{}'::jsonb);
    perform pg_temp.c14_ser('editor');
    a := format('la fila sin tercero la trae (sin clasificar 1000.01): %s; el control lo dice con su asiento: %s; la hoja la trae entre sus '
                'pendientes: %s, entre sus avisos: %s, y no está completa: %s',
                case when exists (select 1 from fn_subs_1099(v_y) r, jsonb_array_elements(r.pagos) p
                                   where r.clave = 'sin_tercero' and p->>'asiento_id' = v_a::text and (p->>'monto')::numeric = 1000.01
                                     and p->>'estado' = 'sin_clasificar') then 'sí' else 'no' end,
                case when pg_temp.c14_ctl(40) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(40), '%' || v_num || ' del % por $1,000.01 a la 2020, sin clasificar%')
                     then 'sí' else 'no: ' || pg_temp.c14_ctl_det(40) end,
                case when exists (select 1 from jsonb_array_elements(v_h->'pendientes') p where p->>'clave' = 'sin_tercero') then 'sí' else 'no' end,
                case when exists (select 1 from jsonb_array_elements(v_h->'avisos') p where (p->>'orden')::int = 40) then 'sí' else 'no' end,
                case when (v_h->>'completa') = 'false' then 'sí' else 'no' end);
    perform pg_temp.c14_marcar(v_a, 1, jsonb_build_object('ficha', v_u, 'nota', 'C14 PRUEBA: es la retención del sub uno'));
    b := pg_temp.c14_fila(v_u);
    -- (b) el trabajo del sub dos, pagado a mano sin tercero en la línea (lleva su partida)
    v_te := pg_temp.c14_externo(33, 2400.24, pg_temp.c14_d(3), pg_temp.c14_prov('dos'));
    perform pg_temp.c14_postear(pg_temp.c14_d(5), 'pago del trabajo del sub dos, sin decir de quién', jsonb_build_array(
              pg_temp.c14_l('2010', 2400.24, null, null, null, 'trabajos_externos', v_te::text), pg_temp.c14_l('1010', -2400.24)));
    c := pg_temp.c14_fila(v_d);
    -- (c) un anticipo a un proveedor que todavía no tiene ficha
    perform pg_temp.c14_postear(pg_temp.c14_d(4), 'anticipo a alguien sin ficha', jsonb_build_array(
              pg_temp.c14_l('2010', 350.35, null, 'proveedor', pg_temp.c14_prov('supply')), pg_temp.c14_l('1010', -350.35)));
    select format('%s, sin clasificar %s, le falta {%s}', r.reporta_efectivo, r.sin_clasificar::numeric(14,2), array_to_string(r.falta, ',')) into d
      from fn_subs_1099(v_y) r where r.clave = 'proveedor:' || pg_temp.c14_prov('supply')::text;
    e := case when pg_temp.c14_ctl(30) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(30), '%ZZ Supply C14 PRUEBA (sin clasificar $350.35)%')
                   and pg_temp.c14_ctl(60) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(60), '%ZZ Supply C14 PRUEBA ($350.35)%')
              then 'sí' else 'no: ' || pg_temp.c14_ctl_det(30) || ' · ' || pg_temp.c14_ctl_det(60) end;
    v_obt := format('la retención devuelta sin decir a quién: %s | atribuida a su ficha: %s | la partida de un sub pagada a mano sin decir de '
                    'quién: %s | un anticipo a alguien sin ficha: %s; lo dicen el control de los sin ficha y el de lo sin clasificar: %s',
                    a, b, c, coalesce(d, 'no sale'), e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'NADA SE QUEDA FUERA CALLADO: la retención devuelta sin decir a quién sale en la fila «sin tercero», el control lo dice, y la hoja la trae entre sus pendientes y sus avisos (no está «completa»); atribuida a su ficha hereda lo que era y cuenta entera; el pago a mano de la partida de un sub sin tercero en la línea es del tercero de su partida; y un anticipo a alguien sin ficha sale con su nombre y los controles lo dicen',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 39. CAMBIAR UNA FICHA NO REESCRIBE LO YA PAGADO. A alguien con pagos, pasar
--     de «se le reporta» a «no» pide decir DESDE CUÁNDO (o que es una
--     corrección); con su «desde», lo pagado antes sigue contando y lo de
--     después no (un tramo); el tramo se puede retirar; con «corrige» vale
--     para todo; decidir «sí» a quien estaba por decidir no lo pide. Y un TIN
--     no se cambia por otro en una ficha con pagos sin decir que es una
--     corrección.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_s uuid; v_t uuid; a text; b text; c text; d text; e text; f text; g text; v_y int := pg_temp.c14_anio();
  v_esp text := 'de «sí» a «no» con pagos, sin decir desde cuándo: MX008 (lo pide, con lo pagado: sí) | desde un día: lo de antes cuenta y lo '
                'de después no: servicio 4000.40, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | no: reportable 3000.30, excluido '
                '1000.10 (no_se_reporta) | pasa sí | falta {tin,w9} | listo no; la fila dice el cambio: sí; queda su tramo: 1 | retirado el '
                'tramo, vale para todo: reportable 0.00, excluido 4000.40 | una corrección: reportable 0.00, excluido 2200.20 (y ningún '
                'tramo: 0) | decidir «sí» a quien estaba por decidir no pide nada: ok, reportable 1500.15, falta {tin,w9} | el TIN: cambiarlo '
                'por otro con pagos MX008 (pide decir que es una corrección: sí); diciéndolo: ok; y el mismo otra vez: ok';
begin
  if pg_temp.c14_omitir(39, 'cambiar una ficha no reescribe lo ya pagado', v_esp) then return; end if;
  if pg_temp.c14_d(1) = pg_temp.c14_d(0) then
    insert into _pruebas values (39, 'cambiar una ficha no reescribe lo ya pagado', v_esp,
      'omitida: el mes de las pruebas empieza hoy: no hay un día anterior en que pagar antes del cambio', null);
    return;
  end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno', '{"tipo_entidad": "individual"}');
    v_d := pg_temp.c14_ficha_de('dos', '{"tipo_entidad": "individual"}');
    v_s := pg_temp.c14_ficha_de('supply', '{"tipo_entidad": "individual", "reporta": "por_decidir"}');
    perform pg_temp.c14_directo(pg_temp.c14_d(0), 3000.30, 'proveedor', pg_temp.c14_prov('uno'));
    a := pg_temp.c14_dice(format('select public.fn_subs_ficha(%L::jsonb)',
                                 jsonb_build_object('id', v_u, 'reporta', 'no', 'reporta_nota', 'C14 PRUEBA: desde hoy va por Gusto')));
    a := left(a, 5) || ' (lo pide, con lo pagado: ' || case when a like 'MX008 Esta ficha ya tiene pagos con lo de antes: $3,000.30 %Di desde qué día vale%' then 'sí' else 'no: ' || a end || ')';
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_u, 'reporta', 'no', 'reporta_nota', 'C14 PRUEBA: desde hoy va por Gusto',
                                                 'desde', pg_temp.c14_d(1)::text));
    perform pg_temp.c14_directo(pg_temp.c14_d(2), 1000.10, 'proveedor', pg_temp.c14_prov('uno'));
    select t.id into v_t from subs_tramos t where t.ficha_id = v_u and t.retirado_el is null;
    b := pg_temp.c14_fila(v_u) || '; la fila dice el cambio: '
         || coalesce((select case when r.cambios like 'hasta el ' || fn_subs_dia(pg_temp.c14_d(0)) || ': se le reportaba%' then 'sí' else 'no: ' || coalesce(r.cambios, 'nada') end
                        from fn_subs_1099(v_y) r where r.ficha_id = v_u), 'no sale')
         || '; queda su tramo: ' || (select count(*) from subs_tramos t where t.ficha_id = v_u and t.retirado_el is null and t.hasta = pg_temp.c14_d(0));
    perform pg_temp.c14_estado(format('select public.fn_subs_tramo_retirar(%L, ''C14 PRUEBA: no era desde ese día'')', v_t));
    select format('reportable %s, excluido %s', r.reportable::numeric(14,2), r.excluido::numeric(14,2)) into c from fn_subs_1099(v_y) r where r.ficha_id = v_u;
    -- una corrección: vale para todo lo pagado
    perform pg_temp.c14_directo(pg_temp.c14_d(0), 2200.20, 'proveedor', pg_temp.c14_prov('dos'));
    perform pg_temp.c14_ficha(jsonb_build_object('id', v_d, 'reporta', 'no', 'reporta_nota', 'C14 PRUEBA: siempre fue empleado', 'corrige', true));
    select format('reportable %s, excluido %s (y ningún tramo: %s)', r.reportable::numeric(14,2), r.excluido::numeric(14,2),
                  (select count(*) from subs_tramos t where t.ficha_id = v_d)) into d from fn_subs_1099(v_y) r where r.ficha_id = v_d;
    -- decidir que sí a quien estaba por decidir
    perform pg_temp.c14_directo(pg_temp.c14_d(0), 1500.15, 'proveedor', pg_temp.c14_prov('supply'));
    e := pg_temp.c14_estado(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_s, 'reporta', 'si')));
    select e || format(', reportable %s, falta {%s}', r.reportable::numeric(14,2), array_to_string(r.falta, ',')) into e from fn_subs_1099(v_y) r where r.ficha_id = v_s;
    -- el TIN
    perform pg_temp.c14_tin(v_s, '000-00-0001');
    f := pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0002"}''::jsonb)', v_s));
    f := left(f, 5) || ' (pide decir que es una corrección: ' || case when f like 'MX008 Esta ficha ya tiene un TIN y pagos a su nombre%' and f !~ '0002|0001' then 'sí' else 'no: ' || f end || ')';
    g := pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0002", "corrige": true}''::jsonb)', v_s))
         || '; y el mismo otra vez: ' || pg_temp.c14_estado(format('select public.fn_subs_tin_guardar(%L, ''{"tin": "000-00-0002"}''::jsonb)', v_s));
    v_obt := format('de «sí» a «no» con pagos, sin decir desde cuándo: %s | desde un día: lo de antes cuenta y lo de después no: %s | retirado '
                    'el tramo, vale para todo: %s | una corrección: %s | decidir «sí» a quien estaba por decidir no pide nada: %s | el TIN: '
                    'cambiarlo por otro con pagos %s; diciéndolo: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'CAMBIAR UNA FICHA NO REESCRIBE LO YA PAGADO: pasar a alguien con pagos de «se le reporta» a «no» pide decir desde cuándo (MX008); con su «desde», lo pagado antes sigue en su 1099 y lo de después no (queda un tramo, y la fila lo dice); el tramo se retira; con «corrige» vale para todo; decidir «sí» a quien estaba por decidir no lo pide; y un TIN no se cambia por otro en una ficha con pagos sin decir que es una corrección',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 40. LO QUE SE LE PAGA A ALGUIEN CON FICHA POR UNA CUENTA SIN LA ETIQUETA (el
--     abogado, a «profesionales»): no se sabe si es servicio, y SE PREGUNTA:
--     sale «sin clasificar», el control lo dice, y la hoja lo trae pendiente.
--     Dicho que es servicio, cuenta. Y SI SU FICHA PASA A «NO» DESDE UN DÍA
--     POSTERIOR AL PAGO (entra a la nómina, se hace corporación), el control
--     lo SIGUE preguntando: ese pago es de cuando SÍ se le reportaba, y si es
--     servicio va en su 1099. (Antes se callaba —«no hay pagos sin
--     clasificar»— porque solo miraba cómo está la ficha al final del año.)
do $$
declare
  v_obt text; v_s uuid; v_a uuid; v_h jsonb; a text; b text; c text; v_cta text; v_y int := pg_temp.c14_anio();
  -- (¿hay un día DESPUÉS del pago que ya haya llegado? Con el mes de las pruebas recién empezado no lo hay: esa parte no se puede probar ese día)
  v_hay boolean := coalesce(pg_temp.c14_d(4) > pg_temp.c14_d(3), false);
  v_esp text := 'el abogado, pagado por una cuenta sin la etiqueta: servicio 0.00, tarjeta 0.00, sin clasificar 4500.45, no servicio 0.00 | si: '
                'reportable 0.00, excluido 0.00 | pasa no | falta {tin,w9} | listo no; sus partes: directo efectivo sin_clasificar 4500.45; el '
                'control lo dice: sí; la hoja lo trae pendiente: sí | su ficha pasa a «no» desde el día siguiente al pago: '
                || case when v_hay then 'el control lo sigue preguntando: sí; retirado ese cambio (el «no» vale para todo), ya no: sí'
                        else '(hoy no se puede probar: el mes de las pruebas acaba de empezar)' end
                || ' | dicho que es servicio: servicio 4500.45, tarjeta 0.00, sin clasificar '
                '0.00, no servicio 0.00 | si: reportable 4500.45, excluido 0.00 | pasa sí | falta {tin,w9} | listo no';
begin
  if pg_temp.c14_omitir(40, 'lo pagado a alguien con ficha por una cuenta sin la etiqueta se pregunta', v_esp) then return; end if;
  -- una cuenta de gasto sin la etiqueta 1099, que no pida obra: «profesionales» (6600) si está; si no, cualquiera
  select k.codigo into v_cta
    from cuentas k
   where k.tipo = 'gasto' and k.imputable and coalesce((to_jsonb(k)->>'activa')::boolean, true) and k.etiqueta_fiscal is distinct from '1099'
     and k.regla_obra <> 'obligatoria'
     and not exists (select 1 from subs_config c where c.id = 1 and k.codigo = any (c.cuentas_por_pagar || c.cuentas_no_pago))
   order by (k.codigo = '6600') desc, k.codigo limit 1;
  if v_cta is null then
    insert into _pruebas values (40, 'lo pagado a alguien con ficha por una cuenta sin la etiqueta se pregunta', v_esp,
      'omitida: el plan de esta base no tiene una cuenta de gasto sin la etiqueta 1099 y sin obra obligatoria', null);
    return;
  end if;
  begin
    perform pg_temp.c14_sembrar();
    v_s := pg_temp.c14_ficha_de('supply', '{"tipo_entidad": "c_corp", "reporta": "si", "reporta_nota": "C14 PRUEBA: abogado, lo dijo el CPA"}');
    v_a := pg_temp.c14_postear(pg_temp.c14_d(3), 'honorarios del abogado', jsonb_build_array(
             pg_temp.c14_l(v_cta, 4500.45, null, 'proveedor', pg_temp.c14_prov('supply')), pg_temp.c14_l('1010', -4500.45)));
    perform pg_temp.c14_ser('dueno');
    v_h := fn_subs_1099_export(v_y, '{}'::jsonb);
    perform pg_temp.c14_ser('editor');
    a := pg_temp.c14_fila(v_s) || '; sus partes: ' || pg_temp.c14_partes(v_s) || '; el control lo dice: '
         || case when pg_temp.c14_ctl(60) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(60), '%ZZ Supply Legal C14 PRUEBA ($4,500.45)%') then 'sí'
                 else 'no: ' || pg_temp.c14_ctl_det(60) end
         || '; la hoja lo trae pendiente: '
         || case when exists (select 1 from jsonb_array_elements(v_h->'pendientes') p
                               where p->>'ficha_id' = v_s::text and (p->>'sin_clasificar')::numeric = 4500.45) then 'sí' else 'no' end;
    -- SU FICHA PASA A «NO» DESDE EL DÍA SIGUIENTE AL PAGO: el pago es de cuando sí se le reportaba (queda su tramo), y el
    -- control lo sigue preguntando, por su monto. Retirado ese cambio, el «no» vale para todo lo pagado y ya no hay nada que
    -- preguntar. Y la ficha vuelve a «sí», como estaba (una corrección: sin tramo), para lo que sigue.
    if v_hay then
      perform pg_temp.c14_ficha(jsonb_build_object('id', v_s, 'reporta', 'no', 'reporta_nota', 'C14 PRUEBA: desde ese día va por nómina',
                                                   'desde', pg_temp.c14_d(4)::text));
      c := 'el control lo sigue preguntando: '
           || case when pg_temp.c14_ctl(60) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(60), '%ZZ Supply Legal C14 PRUEBA ($4,500.45)%') then 'sí'
                   else 'no: ' || coalesce(pg_temp.c14_ctl_det(60), 'nulo') end;
      perform pg_temp.c14_estado(format('select public.fn_subs_tramo_retirar(%L, ''C14 PRUEBA: no era desde ese día'')',
                                        (select t.id from subs_tramos t where t.ficha_id = v_s and t.retirado_el is null)));
      c := c || '; retirado ese cambio (el «no» vale para todo), ya no: '
           || case when pg_temp.c14_ctl_det(60) like '%ZZ Supply Legal C14 PRUEBA%' then 'NO: ' || pg_temp.c14_ctl_det(60) else 'sí' end;
      perform pg_temp.c14_ficha(jsonb_build_object('id', v_s, 'reporta', 'si', 'reporta_nota', 'C14 PRUEBA: abogado, lo dijo el CPA', 'corrige', true));
    else
      c := '(hoy no se puede probar: el mes de las pruebas acaba de empezar)';
    end if;
    perform pg_temp.c14_marcar(v_a, 1, '{"trato": "servicio", "nota": "C14 PRUEBA: honorarios legales, se reportan"}');
    b := pg_temp.c14_fila(v_s);
    v_obt := format('el abogado, pagado por una cuenta sin la etiqueta: %s | su ficha pasa a «no» desde el día siguiente al pago: %s | dicho que '
                    'es servicio: %s', a, c, b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'LO QUE SE LE PAGA A ALGUIEN CON FICHA POR UNA CUENTA DE GASTO SIN LA ETIQUETA 1099 (el abogado, a «profesionales») SE PREGUNTA: sale «sin clasificar» en su fila, el control lo dice y la hoja lo trae pendiente; si su ficha pasa a «no» desde un día posterior al pago, el control lo sigue preguntando (es de cuando sí se le reportaba); dicho que es servicio, cuenta y pasa del umbral',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. LO QUE NO SALIÓ DEL BANCO (lo pagó Edgar de su bolsillo). (a) Directo
--     (Dr 5200 / Cr 2900): el control lo dice, sale en la fila como «por otro
--     camino» y la hoja lo trae pendiente; marcado «pagado» (lo pagó la
--     empresa por otro camino), cuenta ese día. (b) Devengado en la cuenta
--     del sub y saldado contra la 2900: ANTES no se decía en ningún sitio;
--     ahora es una parte «por otro camino» que el control nombra, y marcada
--     «pagado» cuenta.
do $$
declare
  v_obt text; v_u uuid; v_d uuid; v_a uuid; v_b uuid; v_te bigint; a text; b text; c text; d text; v_num text; v_cta text; v_y int := pg_temp.c14_anio();
  v_esp text := 'pagado de su bolsillo: sin pagos (devengado 0.00, por otro camino 2500.25); el control lo nombra: sí | marcado «pagado»: '
                'servicio 2500.25, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 2500.25, excluido 0.00 | pasa sí | '
                'falta {tin,w9} | listo no; sus partes: directo efectivo servicio 2500.25; el control ya no lo nombra: sí | devengado y saldado '
                'por otro camino: directo por_pagar servicio 2600.26 | cxp otro servicio 2600.26; el control lo nombra: sí | marcado «pagado»: '
                'servicio 2600.26, tarjeta 0.00, sin clasificar 0.00, no servicio 0.00 | si: reportable 2600.26, excluido 0.00 | pasa sí | '
                'falta {tin,w9} | listo no';
begin
  if pg_temp.c14_omitir(41, 'lo que no salió del banco', v_esp) then return; end if;
  -- una cuenta de balance que no es banco, tarjeta ni por pagar: el préstamo del accionista (2900) si está; si no, aportaciones
  select k.codigo into v_cta from cuentas k
   where k.codigo in ('2900', '3100') and k.imputable and coalesce((to_jsonb(k)->>'activa')::boolean, true)
     and fn_subs_cuenta_clase(k.codigo) = 'otra'
   order by k.codigo limit 1;
  if v_cta is null then
    insert into _pruebas values (41, 'lo que no salió del banco', v_esp, 'omitida: el plan de esta base no tiene la 2900 ni la 3100', null);
    return;
  end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    v_d := pg_temp.c14_ficha_de('dos');
    v_a := pg_temp.c14_postear(pg_temp.c14_d(3), 'el sub cobró del bolsillo de Edgar', jsonb_build_array(
             pg_temp.c14_l('5200', 2500.25, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno')), pg_temp.c14_l(v_cta, -2500.25)));
    select x.numero into v_num from asientos x where x.id = v_a;
    a := pg_temp.c14_fila(v_u) || '; el control lo nombra: '
         || case when pg_temp.c14_ctl(45) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(45), '%' || v_num || ' por $2,500.25 (ZZ Uno Legal C14 PRUEBA)%') then 'sí'
                 else 'no: ' || pg_temp.c14_ctl_det(45) end;
    perform pg_temp.c14_marcar(v_a, 1, '{"trato": "pagado", "nota": "C14 PRUEBA: lo pagó Edgar y la empresa se lo devolvió"}');
    b := pg_temp.c14_fila(v_u) || '; sus partes: ' || pg_temp.c14_partes(v_u) || '; el control ya no lo nombra: '
         || case when pg_temp.c14_ctl_det(45) like '%' || v_num || ' por%' then 'NO' else 'sí' end;
    v_te := pg_temp.c14_externo(34, 2600.26, pg_temp.c14_d(4), pg_temp.c14_prov('dos'));
    v_b := pg_temp.c14_postear(pg_temp.c14_d(5), 'Edgar le pagó al sub dos de su bolsillo', jsonb_build_array(
             pg_temp.c14_l('2010', 2600.26, null, 'proveedor', pg_temp.c14_prov('dos'), 'trabajos_externos', v_te::text), pg_temp.c14_l(v_cta, -2600.26)));
    select x.numero into v_num from asientos x where x.id = v_b;
    c := pg_temp.c14_partes(v_d) || '; el control lo nombra: '
         || case when pg_temp.c14_ctl(45) = 'rojo' and pg_temp.c14_nombra(pg_temp.c14_ctl_det(45), '%' || v_num || ' por $2,600.26 (ZZ Dos Legal C14 PRUEBA)%') then 'sí'
                 else 'no: ' || pg_temp.c14_ctl_det(45) end;
    perform pg_temp.c14_marcar(v_b, 1, '{"trato": "pagado", "nota": "C14 PRUEBA: lo pagó Edgar y la empresa se lo devolvió"}');
    d := pg_temp.c14_fila(v_d);
    v_obt := format('pagado de su bolsillo: %s | marcado «pagado»: %s | devengado y saldado por otro camino: %s | marcado «pagado»: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, 'LO QUE NO SALIÓ DEL BANCO (lo pagó Edgar de su bolsillo): pagado directo contra la cuenta del accionista sale «por otro camino» y el control lo nombra; marcado «pagado» (lo pagó la empresa por otro camino) cuenta ese día; y lo devengado en la cuenta del sub y saldado contra la del accionista, que antes no se decía en ningún sitio, es una parte «por otro camino» que el control nombra y que marcada «pagado» cuenta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 42. LAS FECHAS, EN LLANO Y SIN PODER CONFUNDIR EL MES CON EL DÍA: lo que la
--     capa escribe con una fecha dentro (el chip del COI, lo que le falta a
--     un COI, el aviso de «parcial», los detalles del control y las filas del
--     cierre) la lleva como 1-oct-2026: ni 01/10/2026 ni 2026-10-01.
do $$
declare
  v_obt text; v_u uuid; v_d0 date := pg_temp.c14_d(0); v_d date := pg_temp.c14_d(1); v_hoy date := pg_temp.c14('hoy')::date; v_todo text; a text; b text;
  v_y int := pg_temp.c14_anio();
  v_esp text := 'fechas con barras o como AAAA-MM-DD en lo que la capa escribe: ninguna | el chip de un COI vencido la dice en llano: sí; el de '
                'uno vigente: sí';
begin
  if pg_temp.c14_omitir(42, 'las fechas, en llano', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    perform pg_temp.c14_directo(v_d, 2700.27, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_archivo(v_u, 'coi', 'coi-viejo.pdf', jsonb_build_object('vence', (v_d - 1)::text));
    select f.coi_chip into a from fn_subs_fichas(v_u) f;
    perform pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', v_y));
    perform pg_temp.c14_directo(v_d, 10.01, 'proveedor', pg_temp.c14_prov('uno'));
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''2000'', ''C14 PRUEBA: el umbral'')', v_y));
    -- todo lo que la capa escribe con esto dentro
    -- (lo de la ficha de la prueba; y de los controles, las filas del cierre y el pegado, todo menos lo que va entre «»:
    -- eso lo escribió alguien —una nota, lo que dijo el banco— y no es de la capa)
    select regexp_replace(concat_ws(E'\n',
             (select string_agg(concat_ws(' ', f.coi_chip, f.reporta_texto, f.falta_texto), E'\n') from fn_subs_fichas(v_u) f),
             (select string_agg(concat_ws(' ', k.coi_chip, k.que_falta), E'\n') from fn_subs_coi(v_d0, v_hoy, v_hoy) k where k.ficha_id = v_u),
             (select string_agg(concat_ws(' ', r.parcial_texto, r.falta_texto, to_jsonb(r)->>'cambios', r.excluido_por::text), E'\n')
                from fn_subs_1099(v_y) r where r.ficha_id = v_u),
             (select string_agg(c.detalle, E'\n') from fn_subs_control(v_y) c),
             (select string_agg(concat_ws(' ', c.detalle, c.que_hacer), E'\n') from fn_subs_cierre(pg_temp.c14('mes')) c),
             (select string_agg(p.detalle, E'\n') from fn_subs_pegado() p)), '«[^»]*»', '', 'g') into v_todo;
    perform pg_temp.c14_archivo(v_u, 'coi', 'coi-nuevo.pdf', jsonb_build_object('vence', (v_hoy + 200)::text));
    select f.coi_chip into b from fn_subs_fichas(v_u) f;
    v_obt := format('fechas con barras o como AAAA-MM-DD en lo que la capa escribe: %s | el chip de un COI vencido la dice en llano: %s; el de '
                    'uno vigente: %s',
                    coalesce((select string_agg(distinct m[1], ', ') from regexp_matches(v_todo, '([0-9]{1,2}/[0-9]{1,2}(/[0-9]{4})?|[0-9]{4}-[0-9]{2}-[0-9]{2})', 'g') m), 'ninguna'),
                    case when a = 'Vencido el ' || fn_subs_dia(v_d - 1) then 'sí' else 'no: ' || coalesce(a, 'nulo') end,
                    case when b = 'vence el ' || fn_subs_dia(v_hoy + 200) then 'sí' else 'no: ' || coalesce(b, 'nulo') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'LAS FECHAS, EN LLANO: lo que la capa escribe con una fecha dentro (el chip del COI, lo que le falta a un COI, el aviso de «parcial», los detalles del control, las filas del cierre y el pegado) la lleva como 1-oct-2026, no como 01/10/2026 (que aquí se lee 10 de enero) ni como 2026-10-01',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. EL TIN, A LOS LADOS: ningún mensaje repite lo que alguien tecleó en OTRO
--     campo (una clave desconocida, el tipo de entidad, «quitar»: ahí puede
--     ir, por error, un TIN); un campo de la ficha que es, entero, un TIN no
--     se guarda; desde el SQL Editor nada de esto contesta con un error (la
--     orden entera, con lo tecleado, iría al registro del servidor); el
--     planificador no guarda valores del TIN en sus estadísticas; y el
--     mensaje del código del teléfono manda a donde está hoy su tarjeta.
do $$
declare
  v_obt text; v_u uuid; a text; b text; c text; d text; e text; f text; g text; h text; v_n int := 0; v_x jsonb; v_r text;
  v_esp text := 'una clave desconocida con forma de TIN: 22023, sin repetirla: sí | el tipo de entidad: 22023, sin repetirlo: sí | «quitar» que '
                'no es sí o no: 22023, sin repetirlo: sí | el nombre legal que es un TIN: 22023 y no se guardó: sí | desde el SQL Editor, el '
                'TIN entre los datos de la ficha: sin error y sin guardar: sí; y en cualquier otro sitio (una clave de más, el código '
                'postal, el tipo de entidad, la dirección): 4 de 4 sin error, sin guardar y sin repetirlo | las estadísticas del '
                'planificador no guardan el TIN: sí | el mensaje del código manda a Conexiones y seguridad: sí';
begin
  if pg_temp.c14_omitir(43, 'el TIN, a los lados', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    v_u := pg_temp.c14_ficha_de('uno');
    a := pg_temp.c14_dice(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_u, '000-00-0007', 'x')));
    b := pg_temp.c14_dice(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_u, 'tipo_entidad', '000-00-0007')));
    c := pg_temp.c14_dice(format('select public.fn_subs_tin_guardar(%L, %L::jsonb)', v_u, '{"quitar": "000-00-0007"}'));
    d := pg_temp.c14_dice(format('select public.fn_subs_ficha(%L::jsonb)', jsonb_build_object('id', v_u, 'nombre_legal', '000-00-0007')));
    e := pg_temp.c14_da(format('select (public.fn_subs_ficha(%L::jsonb))::text', jsonb_build_object('id', v_u, 'tin', '000-00-0007')), 'editor');
    -- (desde el SQL Editor, lo que parece un TIN no llega a un error esté donde esté: la orden que falla va entera al registro)
    foreach v_x in array array[jsonb_build_object('id', v_u, '000-00-0007', 'x'), jsonb_build_object('id', v_u, 'zip', '00-0000007'),
                               jsonb_build_object('id', v_u, 'tipo_entidad', '000000007'), jsonb_build_object('id', v_u, 'direccion', ' 000-00-0007 ')] loop
      v_r := pg_temp.c14_da(format('select (public.fn_subs_ficha(%L::jsonb))::text', v_x), 'editor');
      if v_r like '{%' and (v_r::jsonb->>'guardado') = 'false' and v_r !~ '0007|000-00|00-000' then v_n := v_n + 1; end if;
    end loop;
    f := v_n || ' de 4 sin error, sin guardar y sin repetirlo';
    perform pg_temp.c14_ser('dueno_aal1');
    begin
      perform fn_subs_tin_guardar(v_u, '{"tin": "000-00-0001"}'::jsonb);
      h := 'entró';
    exception when sqlstate 'PGRST' then
      h := case when sqlerrm::json->>'message' like '%Conexiones y seguridad%' and sqlerrm::json->>'message' not like '%Bancos y tarjetas%' then 'sí'
                else 'no: ' || (sqlerrm::json->>'message') end;
    end;
    perform pg_temp.c14_ser('editor');
    v_obt := format('una clave desconocida con forma de TIN: %s, sin repetirla: %s | el tipo de entidad: %s, sin repetirlo: %s | «quitar» que no '
                    'es sí o no: %s, sin repetirlo: %s | el nombre legal que es un TIN: %s y no se guardó: %s | desde el SQL Editor, el TIN '
                    'entre los datos de la ficha: sin error y sin guardar: %s; y en cualquier otro sitio (una clave de más, el código '
                    'postal, el tipo de entidad, la dirección): %s | las estadísticas del planificador no guardan el TIN: %s | el '
                    'mensaje del código manda a Conexiones y seguridad: %s',
                    left(a, 5), case when a !~ '0007|000-00' then 'sí' else 'no: ' || a end,
                    left(b, 5), case when b !~ '0007|000-00' then 'sí' else 'no: ' || b end,
                    left(c, 5), case when c !~ '0007|000-00' then 'sí' else 'no: ' || c end,
                    left(d, 5), case when d !~ '0007|000-00' and (select f.nombre_legal from subs_fichas f where f.id = v_u) = 'ZZ Uno Legal C14 PRUEBA' then 'sí' else 'no: ' || d end,
                    case when e like '{%' and (e::jsonb->>'guardado') = 'false' and e !~ '0007|000-00' then 'sí' else 'no: ' || e end,
                    f,
                    case when (select a.attstattarget from pg_attribute a where a.attrelid = 'public.subs_tin'::regclass and a.attname = 'tin') = 0
                              and not exists (select 1 from pg_stats s where s.schemaname = 'public' and s.tablename = 'subs_tin' and s.attname = 'tin')
                         then 'sí' else 'no' end,
                    h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'EL TIN, A LOS LADOS: ningún mensaje repite lo tecleado en otro campo (una clave desconocida, el tipo de entidad, «quitar»); un campo de la ficha que es entero un TIN no se guarda; desde el SQL Editor el TIN entre los datos de la ficha no contesta con un error (la orden entera iría al registro del servidor) ni se guarda; el planificador no guarda valores del TIN en sus estadísticas; y el mensaje del código del teléfono manda a Conexiones y seguridad',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 44. LA FILA 160 DEL CIERRE NO CUENTA COMO «UN SUB» EL SERVICIO SIN NOMBRE: un
--     trabajo devengado que el libro no dice de quién es se dice aparte, por
--     su monto («además hay servicio por … que el libro no dice de quién
--     es»), y el número de «los N con servicio» es el de quienes tienen
--     nombre.
do $$
declare
  v_obt text; v_det text; v_n bigint; v_per text := pg_temp.c14('mes'); v_p periodos;
  v_esp text := 'el servicio sin nombre se dice aparte, por su monto: sí | y no cuenta como un sub: sí';
begin
  if pg_temp.c14_omitir(44, 'la fila 160 del cierre y el servicio sin nombre', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    select * into v_p from periodos where periodo = v_per;
    perform pg_temp.c14_postear(pg_temp.c14_d(3), 'un trabajo devengado sin decir de quién', jsonb_build_array(
              pg_temp.c14_l('5200', 303.03, 'c14-prueba-a'), pg_temp.c14_l('2010', -303.03)));
    select c.detalle into v_det from fn_subs_cierre(v_per) c where c.orden = 160;
    select count(*) into v_n from fn_subs_coi(v_p.desde, v_p.hasta, least(v_p.hasta, pg_temp.c14('hoy')::date)) k where k.clave <> 'sin_tercero';
    v_obt := format('el servicio sin nombre se dice aparte, por su monto: %s | y no cuenta como un sub: %s',
                    case when v_det ~ 'Además hay servicio por \$[0-9,]+\.[0-9]{2} que el libro no dice de quién es' and v_det not like '%Sin tercero%'
                         then 'sí' else 'no: ' || v_det end,
                    case when (v_n = 0 and v_det like 'Nadie con nombre tuvo servicio%')
                              or (v_n > 0 and (v_det like 'Los ' || v_n || ' con servicio%' or v_det ~ ('^[0-9]+ de los ' || v_n || ' con servicio')))
                         then 'sí' else 'no: ' || v_det end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'LA FILA 160 DEL CIERRE (el COI de cada uno con servicio en el mes) NO CUENTA COMO «UN SUB» EL SERVICIO SIN NOMBRE: el trabajo devengado que el libro no dice de quién es se dice aparte, por su monto, y «los N con servicio» son los que tienen nombre',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 45. CON QUÉ FECHA CUENTA UN PAGO (▶ CPA): un Zelle del 30 de diciembre que
--     se clasifica con diciembre ya cerrado se asienta en enero. De fábrica
--     cuenta con la fecha de su asiento (el año nuevo) y el control avisa de
--     que el banco dice otro año; con la configuración en «banco», cuenta en
--     el año que dijo el banco, y los cuadres del reparto siguen en verde en
--     los dos años. Con el reloj fingido (febrero del año siguiente).
do $$
declare
  v_obt text; v_no text; v_f uuid; v_m uuid; v_a uuid; v_dic periodos; v_q text; v_y int; a text; b text; c text; d text;
  v_esp text := 'de fábrica cuenta con la fecha de su asiento: el año del banco no lo trae y el siguiente sí (servicio 1234.56): sí; el control '
                'avisa de que el banco dice otro año: sí | con la fecha del banco: lo trae el año del banco y el siguiente no: sí; los cuadres '
                'del reparto de los dos años: en verde';
begin
  if pg_temp.c14_omitir(45, 'con qué fecha cuenta un pago', v_esp, false, true) then return; end if;
  if pg_temp.c14('dic') is null then
    insert into _pruebas values (45, 'con qué fecha cuenta un pago', v_esp, 'omitida: no hay un diciembre abierto con su enero siguiente abierto', null);
    return;
  end if;
  begin
    select * into v_dic from periodos where periodo = pg_temp.c14('dic');
    v_y := extract(year from v_dic.desde)::int;
    perform pg_temp.c14_ser('editor');
    lock table public.periodos in exclusive mode;
    perform pg_temp.c14_sembrar();
    perform pg_temp.c14_fingir_hoy(v_dic.hasta + 41);
    v_f := pg_temp.c14_ficha_de('uno');
    v_m := pg_temp.c14_cargo('c14-t45', v_dic.hasta - 1, 1234.56, 'Zelle payment to C14 PRUEBA ZZ SUB UNO dic');
    -- se cierra todo hasta diciembre (la apertura con su asiento, si no lo tiene), como c2-pruebas y la 19
    begin
      if exists (select 1 from periodos p where p.tipo = 'apertura' and p.estado = 'abierto')
         and not exists (select 1 from asientos x join periodos p on p.periodo = x.periodo
                          where p.tipo = 'apertura' and x.tipo = 'apertura' and x.reversa_a is null
                            and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
        perform fn_postear(jsonb_build_object(
          'tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' and p.estado = 'abierto' order by p.desde limit 1),
          'descripcion', 'C14 PRUEBA: apertura de prueba (se deshace)',
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                      jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
      end if;
      for v_q in select p.periodo from periodos p
                  where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_dic.desde order by p.desde loop
        update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
      end loop;
    exception when others then
      v_no := format('el libro no dejó cerrar hasta %s dentro de la prueba (%s: %s)', v_dic.periodo, sqlstate, left(sqlerrm, 300));
    end;
    if v_no is null then
      begin
        v_a := pg_temp.c14_clasificar(v_m, jsonb_build_array(pg_temp.c14_l('5200', 1234.56, 'c14-prueba-a', 'proveedor', pg_temp.c14_prov('uno'))));
      exception when others then
        v_no := format('el banco no dejó clasificar un movimiento de un mes cerrado (%s: %s)', sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null and not exists (select 1 from asientos x where x.id = v_a and x.anio = v_y + 1) then
      v_no := 'el asiento de un movimiento de diciembre con diciembre cerrado no cayó en enero en esta base';
    end if;
    if v_no is null then
      a := case when pg_temp.c14_fila(v_f, v_y) = 'no sale' and pg_temp.c14_fila(v_f, v_y + 1) like 'servicio 1234.56, %' then 'sí'
                else 'no: ' || pg_temp.c14_fila(v_f, v_y) || ' · ' || pg_temp.c14_fila(v_f, v_y + 1) end;
      b := case when pg_temp.c14_ctl(82, v_y + 1) = 'rojo'
                     and pg_temp.c14_nombra(pg_temp.c14_ctl_det(82, v_y + 1), '%por $1,234.56 (el banco dice %')
                     and pg_temp.c14_ctl_det(82, v_y + 1) like '%Hoy cuentan con la fecha del libro%' then 'sí'
                else 'no: ' || coalesce(pg_temp.c14_ctl_det(82, v_y + 1), 'el control no tiene esa fila') end;
      perform pg_temp.c14_estado('select public.fn_subs_config(''{"fecha_pago": "banco"}''::jsonb)');
      c := case when pg_temp.c14_fila(v_f, v_y) like 'servicio 1234.56, %' and pg_temp.c14_fila(v_f, v_y + 1) = 'no sale' then 'sí'
                else 'no: ' || pg_temp.c14_fila(v_f, v_y) || ' · ' || pg_temp.c14_fila(v_f, v_y + 1) end;
      d := case when pg_temp.c14_ctl(10, v_y) = 'verde' and pg_temp.c14_ctl(12, v_y) = 'verde' and pg_temp.c14_ctl(10, v_y + 1) = 'verde'
                     and pg_temp.c14_ctl(12, v_y + 1) = 'verde' then 'en verde'
                else format('%s: %s %s · %s: %s %s', v_y, pg_temp.c14_ctl(10, v_y), pg_temp.c14_ctl(12, v_y), v_y + 1,
                            pg_temp.c14_ctl(10, v_y + 1), pg_temp.c14_ctl(12, v_y + 1)) end;
      v_obt := format('de fábrica cuenta con la fecha de su asiento: el año del banco no lo trae y el siguiente sí (servicio 1234.56): %s; el '
                      'control avisa de que el banco dice otro año: %s | con la fecha del banco: lo trae el año del banco y el siguiente no: '
                      '%s; los cuadres del reparto de los dos años: %s', a, b, c, d);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if v_no is not null then
    insert into _pruebas values (45, 'con qué fecha cuenta un pago', v_esp, 'omitida: ' || v_no, null);
  else
    insert into _pruebas values (45, 'CON QUÉ FECHA CUENTA UN PAGO (▶ CPA): un Zelle del 30 de diciembre clasificado con diciembre ya cerrado se asienta en enero; de fábrica cuenta con la fecha de su asiento (el año nuevo) y el control avisa de que el banco dice otro año; con la configuración en «banco» cuenta en el año que dijo el banco, y los cuadres del reparto siguen en verde en los dos años',
      v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 46. Con fichas, sus terceros, un TIN, sus archivos, marcas, el umbral, la
--     configuración cambiada y una hoja exportada, NINGÚN control de las
--     otras capas pasa a rojo: la cadena y «permisos» de c2, los puentes
--     (c3), el banco (c6), los estados (c4), los cuadres de la IA (c8), los
--     del jornal y el margen (c10), los de las facturas (c11), los del WIP
--     (c12) y lo que detiene el cierre del mes (c9). Se compara con cómo
--     estaban con los pagos de prueba ya en el libro (esta capa no escribe
--     el libro: lo que ya estaba en rojo se dice, y no cuenta).
do $$
declare
  v_obt text; s0 text[]; s1 text[]; v_u uuid; v_a uuid; v_m uuid; v_antes text := ''; v_y int := pg_temp.c14_anio();
  v_esp text := 'con todo lo de c14 puesto: ninguno';
begin
  if pg_temp.c14_omitir(46, 'ningún control de las otras capas pasa a rojo', v_esp) then return; end if;
  begin
    perform pg_temp.c14_sembrar();
    -- los pagos de prueba, en el libro (por c3 y c6, y a mano)
    perform pg_temp.c14_externo(12, 333.34, pg_temp.c14_d(2), pg_temp.c14_prov('uno'));
    if pg_temp.c14('hay_c6') = 'true' then
      v_m := pg_temp.c14_cargo('c14-t37', pg_temp.c14_d(6), 333.34, 'Zelle payment to C14 PRUEBA ZZ SUB UNO');
      perform pg_temp.c14_pagar(v_m, pg_temp.c14_prov('uno'));
    else   -- (sin el banco de c6 en esta base: el mismo pago, a mano)
      perform pg_temp.c14_postear(pg_temp.c14_d(6), 'pago de su trabajo', jsonb_build_array(
                pg_temp.c14_l('2010', 333.34, null, 'proveedor', pg_temp.c14_prov('uno'), 'trabajos_externos', '-1400012'),
                pg_temp.c14_l('1010', -333.34)));
    end if;
    v_a := pg_temp.c14_directo(pg_temp.c14_d(4), 722.22);
    s0 := pg_temp.c14_rojos();
    -- todo lo de c14
    v_u := pg_temp.c14_ficha_de('uno');
    perform pg_temp.c14_tin(v_u, '000-00-0001');
    perform pg_temp.c14_archivo(v_u, 'w9', 'w9.pdf');
    perform pg_temp.c14_archivo(v_u, 'coi', 'coi.pdf', '{"vence": "2030-12-31"}');
    perform pg_temp.c14_marcar(v_a, 1, jsonb_build_object('ficha', v_u, 'trato', 'servicio', 'nota', 'C14 PRUEBA: era de ZZ Uno'));
    perform pg_temp.c14_estado(format('select public.fn_subs_umbral_confirmar(%s, ''600'', ''C14 PRUEBA'')', v_y));
    perform pg_temp.c14_estado('select public.fn_subs_config(''{"coi_aviso_dias": 45}''::jsonb)');
    perform pg_temp.c14_estado(format('select public.fn_subs_1099_export(%s)', v_y));
    s1 := pg_temp.c14_rojos();
    v_obt := 'con todo lo de c14 puesto: ' || pg_temp.c14_nuevos(s0, s1);
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (46, 'con fichas, un TIN, archivos, una marca, el umbral, la configuración cambiada y una hoja exportada, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3), el banco (c6), los estados (c4), los cuadres de la IA (c8), los del jornal y el margen (c10), los de las facturas (c11), los del WIP (c12) y lo que detiene el cierre del mes (c9)',
    v_esp, v_obt || case when v_antes <> '' then ' (ya en rojo antes, con los pagos de prueba en el libro: ' || left(v_antes, 600) || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 47. Nada queda: lo que c14 toca (y lo que sus pruebas sembraron) está como
--     antes de la primera prueba.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c14_ser('editor');
    v_obt := case when pg_temp.c14_conteos() <> pg_temp.c14('conteos') then 'antes: ' || pg_temp.c14('conteos') || ' · ahora: ' || pg_temp.c14_conteos()
                  when exists (select 1 from proyectos p where p.id like 'c14-prueba-%') then 'queda una obra de prueba'
                  when exists (select 1 from proveedores p where p.nombre like 'ZZ % C14 PRUEBA') then 'queda un proveedor de prueba'
                  when exists (select 1 from perfiles p where p.id = pg_temp.c14('p1')::uuid) then 'queda la persona de prueba'
                  when exists (select 1 from subs_fichas f where f.nombre_legal like '%C14 PRUEBA%') then 'queda una ficha de prueba'
                  when exists (select 1 from trabajos_externos t where t.id between -1400999 and -1400000) then 'queda un trabajo externo de prueba'
                  when exists (select 1 from asientos a where a.descripcion like 'C14 PRUEBA%') then 'queda un asiento de prueba'
                  when pg_temp.c14_mov_banco() <> split_part(split_part(pg_temp.c14('conteos'), 'movimientos del banco ', 2), ' ·', 1)::bigint
                    then 'queda un movimiento de prueba'
                  when coalesce(current_setting('mx_subs.tin', true), '') <> '' or coalesce(current_setting('mx_subs.escribe', true), '') <> ''
                    then 'queda una marca de escritura puesta'
                  else 'igual que antes' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, 'nada queda de las pruebas: la configuración, los umbrales, las fichas, sus terceros, los TIN, los archivos, las marcas, el historial, las exportaciones, los asientos y sus líneas, los contadores, los proveedores, los perfiles, los trabajos externos, los movimientos del banco, las obras, los períodos cerrados, el bucket y las funciones, como antes; y ninguna marca de escritura puesta',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 48. El cierre de la suite: las demás capas (c2, c3, c4, c6, c8, c9, c10,
--     c11 y c12) como estaban antes de las pruebas (lo que ya estaba en rojo
--     se dice y no cuenta), los cuadres del propio control como estaban,
--     nada de c14 para anon o service_role ni SECURITY DEFINER; y
--     fn_subs_pegado responde con sus nueve filas y la configuración sigue
--     siendo UNA (pegar dos veces no la pisa: lo corre el banco, con dos
--     pegados seguidos antes de esta suite). Y, mirado todo eso, la base
--     sigue como al empezar (tampoco la revisión del cierre que c9 guarda, ni
--     el reloj).
do $$
declare
  v_obt text; v_api text; v_n int; v_cfg int; v_rojos text;
  v_esp text := 'las otras capas, en rojo nuevo: ninguno | permisos (c2): verde | los cuadres de los subs: nada nuevo en rojo | c14 para anon '
                'o service_role, o definer: ninguna | el pegado: 9 filas, y la configuración 1 fila (id 1) | y nada queda: sí';
begin
  begin
    perform pg_temp.c14_ser('editor');
    v_rojos := pg_temp.c14_nuevos(coalesce(string_to_array(nullif(pg_temp.c14('rojos_antes'), ''), '; '), '{}'::text[]),
                                  array(select x from unnest(pg_temp.c14_rojos_limpio()) x where x <> 'c2: permisos'));
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c14_fn())
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_subs_pegado();
    select count(*) into v_cfg from subs_config;
    v_obt := format('las otras capas, en rojo nuevo: %s | permisos (c2): %s | los cuadres de los subs: %s | c14 para anon o service_role, o '
                    'definer: %s | el pegado: %s filas, y la configuración %s fila (id %s)',
                    v_rojos, pg_temp.c14_permisos(), pg_temp.c14_propios(), v_api, v_n, v_cfg, (select id from subs_config limit 1));
    v_obt := v_obt || ' | y nada queda: '
             || case when pg_temp.c14_conteos() = pg_temp.c14('conteos') then 'sí'
                     else 'QUEDÓ: ' || pg_temp.c14_conteos() || ' (antes: ' || pg_temp.c14('conteos') || ')' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, 'el cierre de la suite: c2, c3, c4, c6, c8, c9, c10, c11 y c12 como estaban con c14 puesto (lo que ya estaba en rojo antes se dice y no cuenta), «permisos» de c2 en verde, los cuadres del propio control de los subs como estaban, nada de c14 para anon o service_role ni SECURITY DEFINER; fn_subs_pegado responde y la configuración es una fila (pegar dos veces no la pisa: lo corre el banco)',
    v_esp,
    v_obt || case when pg_temp.c14('rojos_antes') <> '' then ' (ya en rojo antes de las pruebas: ' || left(pg_temp.c14('rojos_antes'), 600) || ')' else '' end
          || case when pg_temp.c14('rojos_subs') <> '' then ' (cuadres de los subs ya en rojo antes, con los datos de esta base: ' || pg_temp.c14('rojos_subs') || ')' else '' end
          || case when pg_temp.c14('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c14: ' || pg_temp.c14('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- EL RELOJ, COMO ESTABA. Cada prueba que lo finge lo deshace con su subtransacción; esto es la red: si alguno quedara
-- puesto, se restaura aquí mismo el de verdad (el que había al empezar) y sale como un fallo, con su fila.
do $$
begin
  if pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) is distinct from pg_temp.c14('reloj_def') then
    reset role;
    execute pg_temp.c14('reloj_def');
    insert into _pruebas values (99, 'EL RELOJ DE LAS PRUEBAS: ninguna prueba deja puesto el reloj fingido', 'el reloj de verdad, al terminar',
      'una prueba dejó puesto el reloj fingido: se restauró el de verdad aquí mismo. Es un fallo de este archivo: avisa.', false);
  end if;
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- UNA PRUEBA QUE NO PUDO TOMAR UN CANDADO EN MEDIO SEGUNDO NO ES UN FALLO:
-- la app (u otra sesión) tenía tomado algo que necesitaba, y esta corrida no
-- espera más (el tope de arriba, para no dejar esperando a la app). Sale
-- «omitida», con lo que dijo la base, y se vuelve a pegar el archivo en un
-- momento más tranquilo. (Como c11-pruebas.sql.)
update _pruebas
   set ok = null,
       obtenido = 'omitida: mientras corría, la app (u otra sesión) tenía tomado algo que esta prueba necesita y no lo soltó en medio '
                  || 'segundo (55P03); no se esperó más, para no dejar esperando a la app. No es un fallo: vuelve a pegar el archivo en un '
                  || 'momento en que nadie esté usando la app. Lo que dio: ' || left(obtenido, 300)
 where ok is false and obtenido like '%55P03%';

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8, c9, c10, c11 y c12): si el SQL Editor deja de esperar, la corrida
-- sigue en el servidor hasta el final y se lee después con
--   select * from pruebas.c14_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade». (No lleva ningún TIN: los de las
-- pruebas son de mentira, y ninguna fila los repite.)
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c14_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c14_resultado from public, anon, authenticated, service_role;
truncate pruebas.c14_resultado;
insert into pruebas.c14_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
