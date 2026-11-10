-- =====================================================================
-- c10-pruebas.sql — el jornal repartido por horas y el costo por obra se
-- prueban a sí mismos (c10-costo-obra.sql). 9-nov-2026; 10-nov-2026: las
-- pruebas 48 a 57, una por cada hallazgo de las dos revisiones (v2 de la
-- capa), y el cierre de la suite pasa a ser 58, 59 y 60.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c10-costo-obra.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 60 filas, todas
-- con ok = true (las que salen «omitida» dicen por qué y no son un fallo).
-- Si el editor se cansa antes del final, la corrida sigue en el servidor y
-- se lee después en pruebas.c10_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c9 y c10-costo-obra.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c10-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las personas de prueba, ni sus horas, ni los movimientos
-- del banco, ni los asientos, ni los repartos); la 58 lo comprueba. Ningún
-- aviso sale al teléfono: lo que una hora nueva encola (fn_avisar_horas) se
-- deshace con ella, como en c3-pruebas y c8-pruebas.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · TRES PERSONAS DE PRUEBA («Zzana C10 PRUEBA», «Zzbeto…», «Zzcaro…»:
--     nombres que nadie de la cuadrilla lleva), con su usuario en auth.users,
--     su perfil (rol campo) y su tarifa (25, 24 y ninguna). Ninguna prueba
--     usa a una persona real ni sus horas. Si la base no deja crear usuarios
--     de prueba (un trigger de auth.users que pida más datos), las pruebas
--     que los necesitan salen «omitida» y dicen qué dijo la base.
--   · DOCE OBRAS DE PRUEBA («C10 PRUEBA Obra A»…«L», ids c10-prueba-a…l),
--     con sus estados (en ejecución, terminada, cancelada, en pausa,
--     aprobada, estimando).
--   · SUS HORAS, con ids negativos (−1010000001…): no gastan la secuencia.
--   · SUS MOVIMIENTOS DEL BANCO, como los trae Plaid (fn_banco_importar_filas
--     en nombre del dueño, y «Casar» SOLO para ese movimiento:
--     fn_banco_casar), con la descripción «Zelle payment to C10 PRUEBA
--     ZZANA…»: ningún patrón real casa con ella. Las personas REALES cuyo
--     patrón casara con un movimiento de prueba se aparcan (de baja) dentro
--     de la prueba.
--   · El día del pago es hace tres días (o el día 1 del mes, como
--     c8-pruebas: un mes abierto), y las horas van en las dos semanas
--     anteriores a la de ese día.
-- Lo real que cambia un resultado se respeta: las pruebas miran SUS filas
-- (su movimiento, su reparto, sus obras), no «la primera fila» de una
-- vista; los controles ajenos (c2, c3, c4, c6, c8, c9) se comparan con cómo
-- estaban justo antes (lo que ya estaba en rojo se dice y no se cuenta). La
-- 27 (un pago de un mes ya cerrado) cierra dentro de su subtransacción la
-- apertura y el mes abierto más viejo que ya terminó, como c2-pruebas (toma
-- «lock table periodos in exclusive mode»); si el libro real no deja cerrar
-- (su apertura sin cuadrar…), sale «omitida» con lo que dijo c2.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 5 tablas, 6 vistas, las 38 funciones por su
--    nombre exacto, la configuración, cada objeto con su comentario «c10: …»);
--  2 las precondiciones en rojo (desde la app; sin una función de c6; una
--    función con nombre de c10 que no es de c10; una vista ajena colgada);
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas en las
--    tablas, las vistas y las auxiliares; el dueño entra y ve;
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa ni de la
--    otra sesión, RLS y policies justas, vistas security_invoker que no
--    fijan columnas de c2 ni cuelgan de vistas de otras capas, nada que
--    nombre objetos de la otra sesión; «permisos» (c2), «protecciones del
--    banco» (c6) y «protecciones de c4» en verde con c10 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API);
--  6 fn_jornal_config y sus frenos;
--  7 fn_jornal_persona (alta, patrón, cuenta, baja, el dueño no) y
--    v_jornal_personas;
--  8 EL NÚCLEO: la suma es el monto, al centavo, con 1, 2, 7 y 12 grupos,
--    montos que no dividen y horas con decimales;
--  9 el núcleo: los mayores restos y sus desempates, a mano; determinista;
-- 10 el núcleo: con CO, con horas sin obra, sin horas, montos mal, y por
--    persona y período;
-- 11 la regla del período: cada día de la semana;
-- 12 el cambio de hora y el fin de año (y la zona horaria de la sesión);
-- 13 las fechas a mano y sus frenos;
-- 14 la propuesta reconoce por el patrón y solo a los dados de alta (la
--    nota del banco, la baja, dos personas que casan);
-- 15 no es un abono, ni un movimiento resuelto, ni uno que no existe;
-- 16 lo que trae la propuesta (líneas, detalle, las dos semanas, la tarifa
--    que sale, la huella: estable, y cambia con las horas);
-- 17 los avisos: sin horas, la tarifa lejos (umbral configurable), sin tarifa;
-- 18 los avisos: obra terminada o no aprobada, obra sin aprobar, falta la
--    cuenta de lo sin obra, una cuenta que ya no sirve;
-- 19 los avisos: horas ya cubiertas, se pisa con otro reparto, «es otro pago
--    de las mismas horas», fechas posteriores al pago;
-- 20 los avisos: posible duplicado sin decidir y devengo estándar en el mes;
-- 21 la propuesta pendiente de la IA (c8) se devuelve y nada de c8 se rompe
--    (lo que un jornal deja abierto en c8, entero, en la 51);
-- 22 APLICAR: el asiento (N líneas con su obra, su CO y la persona, contra
--    el banco; el movimiento casado), el reparto y su detalle guardados;
-- 23 aplicar aprueba las horas por el camino de c3 (con lo que Edgar vio);
-- 24 la huella cambiada → MX011 y NADA cambia;
-- 25 dos veces → la segunda falla limpia; y sus frenos de entrada;
-- 26 más de 5 obras (7) y 12 grupos en un asiento;
-- 27 un pago de un mes ya cerrado → entra el primer día del mes abierto;
-- 28 la obra terminada y la no aprobada reciben su parte;
-- 29 las horas sin obra: sin cuenta no se aplica; con ella, a su cuenta;
-- 30 los frenos del banco valen (un débito que c6 toma por nómina: MX008 y
--    nada cambia; con el motivo de Edgar, entra);
-- 31 DESHACER: el reverso, el movimiento vuelve, el reparto marcado, la
--    aprobación se queda; dos veces no;
-- 32 volver a aplicar con otras fechas;
-- 33 des-casado por fuera (en la Bandeja): el control lo ve, la propuesta
--    lo dice, y fn_jornal_deshacer lo cierra;
-- 34 v_jornal_pendientes, v_jornal_repartos (lo que la pantalla pinta);
-- 35 el control 10 (el reparto es su asiento) en rojo y de vuelta;
-- 36 el control 25 (deshecho con su asiento vivo) en rojo y de vuelta;
-- 37 el control 30 (las horas cambiaron) en rojo y de vuelta;
-- 38 el control 40 (una hora en dos repartos sin aceptarlo);
-- 39 el control 50 (la misma hora en el devengo estándar de un mes y en un
--    jornal que entró al libro ese mes);
-- 40 el control 60 (dos personas casan con un pago; una cuenta que no sirve);
-- 41 el control 90 (las protecciones de la capa);
-- 42 EL MARGEN: una obra con material, jornales, un subcontrato de verdad
--    en 5200, equipo, otro costo, un CO y su factura: cada columna contra el
--    libro, al centavo, y cada «bajar» suma su cifra;
-- 43 la mano de obra real contra la estándar (sin burden, con burden, una
--    persona sin tarifa, las horas del dueño, las de antes del libro);
-- 44 el estimado (sin estimado enlazado: el escenario B; con él: el suyo y
--    sus beneficios; el convertido antes que el más nuevo);
-- 45 la obra que ya andaba antes del libro sale parcial, y lo dice;
-- 46 el detalle de una obra: por CO, por fase, por cost code (o que no
--    hay), la cobertura y los repartos; los pagos sin repartir;
-- 47 v_margen_control (verde; y en rojo cuando un reparto no es su asiento);
-- Lo que las dos revisiones encontraron (v2), una prueba por hallazgo:
-- 48 un estimado parcial no se compara con un real completo (costo_estimado
--    vacío, estimado_completo y estimado_falta);
-- 49 las horas que llegan tarde a una semana ya repartida (el control 35, la
--    obra y la propuesta del pago siguiente);
-- 50 el pago de una persona dada de alta resuelto fuera del jornal (el
--    control 70 y las obras con horas suyas);
-- 51 lo de la IA (c8) que un jornal deja abierto: la pendiente y la aprobada
--    cuyo asiento se reversó (propuestas_ia, fn_jornal_ia y el control 80);
-- 52 la huella cubre exactamente lo que el «Así es» aprueba (una hora
--    cubierta que cambia entre medias: MX011);
-- 53 el CO y la fase, limpios como los deja c6 (un salto de línea, un
--    tabulador); los CO parecidos se avisan; y el MX001 dice qué línea y qué
--    campo;
-- 54 el devengo de un mes y el jornal pagado al siguiente no chocan;
-- 55 el doble de verdad, en rojo mientras el mes está abierto; cerrado, se
--    dice y no se queda en rojo;
-- 56 el reconocimiento por patrón se avisa (un Zelle a cualquiera no entra;
--    la compra en un comercio; el patrón sin el nombre de pila) y la cuenta
--    de lo sin obra no es cualquier gasto;
-- 57 lo menor: el corte de mes y de año, la nota de aplicar, el núcleo con
--    solo las horas aprobadas, y los textos sin nombres de función;
-- Y el cierre:
-- 58 nada queda al deshacer;
-- 59 con jornales aplicados, deshechos y vueltos a aplicar, NINGÚN control
--    de c2, c3, c4, c6, c8 ni c9 pasa a rojo;
-- 60 el cierre de la suite: c2, c3, c6 y c4 como estaban, c8 sin cuadres
--    rojos, nada de c10 en la API de anon o service_role ni SECURITY
--    DEFINER; y fn_jornal_pegado responde (pegar dos veces no hace daño: lo
--    corre el banco).
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el día del pago, las semanas de las horas.
create temp table if not exists _c10 (k text primary key, v text);
truncate _c10;
insert into _c10
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c10 values
  ('p1', '00000000-0000-4000-a000-0000000c1001'),   -- Zzana C10 PRUEBA  (tarifa 25)
  ('p2', '00000000-0000-4000-a000-0000000c1002'),   -- Zzbeto C10 PRUEBA (tarifa 24)
  ('p3', '00000000-0000-4000-a000-0000000c1003'),   -- Zzcaro C10 PRUEBA (sin tarifa)
  ('banco', '1010');
insert into _c10 values ('hoy', fn_fecha_miami(now())::text);
-- el día del pago: hace tres días o el día 1 del mes (un mes abierto, como c8-pruebas)
insert into _c10 values ('d', greatest(fn_fecha_miami(now()) - 3, date_trunc('month', fn_fecha_miami(now()))::date)::text);
-- el lunes de la semana del pago; las horas van en las dos semanas anteriores
insert into _c10
select 'lunes', (x.d - (extract(isodow from x.d)::int - 1))::text from (select (select v from _c10 where k = 'd')::date as d) x;
insert into _c10 values ('libro_desde', fn_margen_libro_desde()::text);
insert into _c10
select 'mes_d', p.periodo from periodos p where p.tipo = 'mes' and (select v from _c10 where k = 'd')::date between p.desde and p.hasta;
insert into _c10 values ('hay_c8', (to_regclass('public.contador_propuestas') is not null)::text);
insert into _c10 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
grant select on _c10 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8 y c9), y
-- ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c10(k text) returns text language sql as $$ select v from _c10 where k = $1 $$;
-- las fechas de las pruebas: el día del pago, el lunes de su semana, y las
-- dos semanas de trabajo anteriores (w1: la anterior; w2: la de antes)
create or replace function pg_temp.c10_d() returns date language sql as $$ select pg_temp.c10('d')::date $$;
create or replace function pg_temp.c10_w1(p_dia int default 0) returns date language sql as $$ select pg_temp.c10('lunes')::date - 7 + p_dia $$;
create or replace function pg_temp.c10_w2(p_dia int default 0) returns date language sql as $$ select pg_temp.c10('lunes')::date - 14 + p_dia $$;

-- Las funciones que crea c10-costo-obra.sql, por su nombre exacto (las 38).
-- No se buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c10_es_suya(p_nombre text) returns boolean language sql immutable as $$
  select p_nombre = any (array[
    'fn_jornal_exigir_dueno', 'fn_jornal_ve', 'fn_jornal_precondiciones', 'fn_jornal_guarda', 'fn_jornal_usd',
    'fn_jornal_h', 'fn_jornal_dia', 'fn_jornal_rango', 'fn_jornal_mes', 'fn_jornal_texto', 'fn_jornal_limpio',
    'fn_jornal_patron_mal', 'fn_jornal_destinatario', 'fn_jornal_patron_sugerido', 'fn_jornal_cuenta_mal',
    'fn_jornal_periodo', 'fn_jornal_regla', 'fn_jornal_repartir_ids', 'fn_jornal_repartir', 'fn_jornal_tardias',
    'fn_jornal_fuera', 'fn_jornal_ia', 'fn_jornal_opciones', 'fn_jornal_calcular', 'fn_jornal_propuesta', 'fn_jornal_aplicar',
    'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona', 'fn_jornal_pegado', 'fn_margen_libro_desde',
    'fn_margen_lineas', 'fn_margen_horas', 'fn_margen_estimado', 'fn_margen_obras', 'fn_margen_bajar',
    'fn_margen_obra', 'fn_margen_control'])
$$;
create or replace function pg_temp.c10_tablas() returns text[] language sql immutable as $$
  select array['jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas']
$$;
create or replace function pg_temp.c10_vistas() returns text[] language sql immutable as $$
  select array['v_jornal_pendientes', 'v_jornal_repartos', 'v_jornal_personas', 'v_jornal_control', 'v_margen_obra', 'v_margen_control']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o una persona de
-- prueba por la API (authenticated, en aal2), anon o service_role.
create or replace function pg_temp.c10_ser(quien text) returns void language plpgsql as $$
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
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c10(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c10(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): las tres personas
-- de prueba con su usuario, su perfil y su tarifa, y las doce obras.
create or replace function pg_temp.c10_sembrar() returns void language plpgsql as $$
declare
  r      record;
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
begin
  perform pg_temp.c10_ser('editor');
  for r in select * from (values ('p1', 'Zzana C10 PRUEBA'), ('p2', 'Zzbeto C10 PRUEBA'), ('p3', 'Zzcaro C10 PRUEBA')) as t(k, nombre) loop
    if v_meta then
      execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                     pg_temp.c10(r.k), 'c10-' || r.k || '@c10-pruebas.invalid',
                     json_build_object('nombre', r.nombre, 'name', r.nombre, 'full_name', r.nombre)::text);
    else
      execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                     pg_temp.c10(r.k), 'c10-' || r.k || '@c10-pruebas.invalid');
    end if;
    insert into perfiles (id, nombre, rol, activo) values (pg_temp.c10(r.k)::uuid, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c10('p1')::uuid, 25), (pg_temp.c10('p2')::uuid, 24)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  delete from costos_equipo where usuario_id = pg_temp.c10('p3')::uuid;
  insert into proyectos (id, tipo, nombre, estado) values
    ('c10-prueba-a', 'comercial',   'C10 PRUEBA Obra A', 'ejecucion'),
    ('c10-prueba-b', 'residencial', 'C10 PRUEBA Obra B', 'ejecucion'),
    ('c10-prueba-c', 'servicio',    'C10 PRUEBA Obra C', 'completado'),
    ('c10-prueba-d', 'servicio',    'C10 PRUEBA Obra D', 'no_aprobado'),
    ('c10-prueba-e', 'comercial',   'C10 PRUEBA Obra E', 'pausa'),
    ('c10-prueba-f', 'comercial',   'C10 PRUEBA Obra F', 'aprobado'),
    ('c10-prueba-g', 'residencial', 'C10 PRUEBA Obra G', 'estimando'),
    ('c10-prueba-h', 'servicio',    'C10 PRUEBA Obra H', 'ejecucion'),
    ('c10-prueba-i', 'servicio',    'C10 PRUEBA Obra I', 'ejecucion'),
    ('c10-prueba-j', 'servicio',    'C10 PRUEBA Obra J', 'ejecucion'),
    ('c10-prueba-k', 'servicio',    'C10 PRUEBA Obra K', 'ejecucion'),
    ('c10-prueba-l', 'servicio',    'C10 PRUEBA Obra L', 'ejecucion');
end $$;

-- ¿Se puede sembrar en esta base? Se prueba UNA vez, antes de todo, y se
-- deshace. Si no (auth.users no deja), las pruebas que siembran salen
-- «omitida» con lo que dijo la base.
do $$
declare
  v text := 'ok';
begin
  begin
    perform pg_temp.c10_sembrar();
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c10 values ('siembra', v);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar; devuelve true si la puso)
create or replace function pg_temp.c10_omitir(p_n int, p_prueba text, p_esperado text) returns boolean language plpgsql as $$
begin
  if pg_temp.c10('siembra') = 'ok' then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    'omitida: esta base no deja crear las personas de prueba (' || left(pg_temp.c10('siembra'), 300) || ')', null);
  return true;
end $$;

-- Un reporte de horas de una persona de prueba (como el SQL Editor), con su
-- id negativo. p_n: 1, 2, 3… dentro de la prueba.
create or replace function pg_temp.c10_hora(p_n int, p_quien text, p_fecha date, p_obra text, p_horas numeric,
                                            p_co text default null, p_fase text default null)
returns bigint language sql as $$
  insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, co, notas) overriding system value
  values (-(1010000000 + p_n), p_fecha, pg_temp.c10(p_quien)::uuid, p_obra, p_fase, p_horas, p_co, 'c10-pruebas')
  returning id
$$;

-- Un movimiento del banco como lo trae Plaid (en nombre del dueño) y
-- «Casar» solo para él: sin ticket ni asiento que lo explique, queda
-- pendiente en la Bandeja. p_monto en positivo = lo que salió (un Zelle);
-- en negativo, un abono. La descripción lleva «C10 PRUEBA». Devuelve el
-- movimiento. Las personas REALES cuyo patrón casaría con él se aparcan (de
-- baja, con la marca de la guarda): se deshace con la prueba.
create or replace function pg_temp.c10_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text, p_memo text default null)
returns uuid language plpgsql as $$
declare
  v_mov uuid;
  v_txt text;
begin
  if p_desc !~ 'C10 PRUEBA' then
    raise exception 'c10-pruebas: la descripción de un movimiento de prueba lleva «C10 PRUEBA» (%)', p_desc;
  end if;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c10('dueno'), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c10('dueno'), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', pg_temp.c10('banco'), 'nombre', 'Plaid · c10-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text, 'descripcion', p_desc, 'memo', p_memo,
               'tipo', case when p_monto < 0 then 'CREDIT' else 'DEBIT' end, 'pendiente', false)))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform pg_temp.c10_ser('editor');
  select fn_jornal_texto(m.desc_norm, m.memo) into v_txt from movimientos_banco m where m.id = v_mov;
  perform set_config('mx_jornal.escribe', 'jornal_personas', true);
  update jornal_personas jp set activa = false
   where jp.activa and jp.usuario_id not in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid)
     and v_txt ~* jp.patron;
  perform set_config('mx_jornal.escribe', '', true);
  return v_mov;
end $$;

-- Como el dueño por la API: dar de alta a una persona de prueba con su
-- patrón, pedir la propuesta, y «Así es» (la propuesta y, con su huella,
-- aplicar). Al volver, otra vez el SQL Editor.
create or replace function pg_temp.c10_alta(p_quien text, p_patron text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10(p_quien),
         'patron', coalesce(p_patron, case p_quien when 'p1' then '\mPRUEBA ZZANA\M' when 'p2' then '\mPRUEBA ZZBETO\M'
                                                   else '\mPRUEBA ZZCARO\M' end)));
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c10_propuesta(p_mov uuid, p_desde date default null, p_hasta date default null,
                                                 p_op jsonb default '{}'::jsonb)
returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_propuesta(p_mov, p_desde, p_hasta, p_op);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c10_aplicar(p_mov uuid, p_desde date, p_hasta date, p_op jsonb default '{}'::jsonb)
returns jsonb language plpgsql as $$
declare
  v jsonb;
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  v := fn_jornal_propuesta(p_mov, p_desde, p_hasta, p_op);
  r := fn_jornal_aplicar(p_mov, p_desde, p_hasta, v->>'visto', p_op);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
-- Edgar corrige un reporte de horas en la app (como el dueño por la API: la
-- guarda de correcciones de la app no deja al SQL Editor). p_cambio: lo que
-- va en el SET («horas = 7», «proyecto_id = 'c10-prueba-b'»).
create or replace function pg_temp.c10_corregir(p_n int, p_cambio text) returns void language plpgsql as $$
begin
  perform pg_temp.c10_ser('dueno');
  execute format('update public.horas set %s where id = %s', p_cambio, -(1010000000 + p_n));
  perform pg_temp.c10_ser('editor');
end $$;
create or replace function pg_temp.c10_deshacer(p_reparto uuid, p_motivo text) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_deshacer(p_reparto, p_motivo);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;

-- Los códigos de los avisos de una propuesta, en su orden («-» si ninguno).
-- Sin los del CALENDARIO (otro_mes, otro_anio: las horas de un mes y el
-- asiento en otro): dependen del día en que se corre la suite —las horas de
-- prueba van en las dos semanas anteriores a hoy—, y los prueba la 57 con
-- sus propias fechas. c10_avisos_todos los trae todos.
create or replace function pg_temp.c10_avisos(j jsonb) returns text language sql as $$
  select coalesce(string_agg(a.v->>'codigo', ',' order by a.o), '-') from jsonb_array_elements(j->'avisos') with ordinality as a(v, o)
   where a.v->>'codigo' not in ('otro_mes', 'otro_anio')
$$;
create or replace function pg_temp.c10_avisos_todos(j jsonb) returns text language sql as $$
  select coalesce(string_agg(a.v->>'codigo', ',' order by a.o), '-') from jsonb_array_elements(j->'avisos') with ordinality as a(v, o)
$$;
-- ¿trae ese aviso? su texto (nulo si no)
create or replace function pg_temp.c10_aviso(j jsonb, p_codigo text) returns text language sql as $$
  select a->>'texto' from jsonb_array_elements(j->'avisos') a where a->>'codigo' = p_codigo limit 1
$$;
-- Las líneas de una propuesta en una línea: obra[/CO] horas→monto, …
create or replace function pg_temp.c10_lineas(j jsonb) returns text language sql as $$
  select coalesce(string_agg(format('%s%s %s→%s', replace(l->>'proyecto_id', 'c10-prueba-', ''),
                                    coalesce('/' || (l->>'co'), ''), trim_scale((l->>'horas')::numeric), l->>'monto'),
                             ', ' order by (l->>'n')::int), '-')
         || case when jsonb_typeof(j->'sin_obra') = 'object'
                 then format(' + sin obra %s→%s', trim_scale((j->'sin_obra'->>'horas')::numeric), j->'sin_obra'->>'monto') else '' end
    from jsonb_array_elements(j->'lineas') l
$$;
-- Las líneas de un asiento en una línea: orden cuenta monto [obra[/CO]] [persona], …
create or replace function pg_temp.c10_asiento(p_asiento uuid) returns text language sql as $$
  select string_agg(format('%s %s %s%s%s', l.orden, l.cuenta, l.monto,
                           coalesce(' ' || replace(l.proyecto_id, 'c10-prueba-', '') || coalesce('/' || l.co, ''), ''),
                           case when l.tercero_tipo is null then ''
                                else ' ' || l.tercero_tipo || ':' || coalesce((select k from _c10 where v = l.tercero_id), l.tercero_id) end),
                    ' | ' order by l.orden)
    from asiento_lineas l where l.asiento_id = p_asiento
$$;

-- Una fila del control del jornal o del margen: 'verde' o 'rojo: detalle'
create or replace function pg_temp.c10_jc(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo: ' || c.detalle end from v_jornal_control c where c.orden = p_orden
$$;
create or replace function pg_temp.c10_mc(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo: ' || c.detalle end from v_margen_control c where c.orden = p_orden
$$;
-- (solo el color)
create or replace function pg_temp.c10_color(p text) returns text language sql immutable as $$ select split_part(p, ':', 1) $$;

-- LA LLAVE «bajar» de c4, sumada contra v_libro (como pg_temp.c4_bajar de
-- c4-pruebas): cada pedazo vale signo × la suma de «campo» en las filas que
-- cumplen sus filtros (col = valor, col en una lista, col nula, col_no).
create or replace function pg_temp.c10_bajar(p_specs jsonb) returns numeric language plpgsql as $$
declare
  e       jsonb;
  f       record;
  v_where text;
  v_col   text;
  v_s     numeric;
  v_tot   numeric := 0;
begin
  if p_specs is null or jsonb_typeof(p_specs) <> 'array' then
    raise exception 'bajar no es una lista: %', p_specs;
  end if;
  for e in select value from jsonb_array_elements(p_specs) loop
    if e->>'vista' <> 'v_libro' then
      raise exception 'bajar a una vista que c10 no usa: %', e->>'vista';
    end if;
    v_where := 'true';
    for f in select key, value from jsonb_each(coalesce(e->'filtros', '{}'::jsonb)) loop
      if f.key like '%\_no' then
        v_col := left(f.key, length(f.key) - 3);
        if jsonb_typeof(f.value) = 'array' then
          v_where := v_where || format(' and x.%I::text <> all (%L::text[])', v_col,
                                       coalesce((select array_agg(t) from jsonb_array_elements_text(f.value) t), '{}'::text[]));
        else
          v_where := v_where || format(' and x.%I::text <> %L', v_col, f.value #>> '{}');
        end if;
      elsif jsonb_typeof(f.value) = 'null' then
        v_where := v_where || format(' and x.%I is null', f.key);
      elsif jsonb_typeof(f.value) = 'array' then
        v_where := v_where || format(' and x.%I::text = any (%L::text[])', f.key,
                                     coalesce((select array_agg(t) from jsonb_array_elements_text(f.value) t), '{}'::text[]));
      else
        v_where := v_where || format(' and x.%I::text = %L', f.key, f.value #>> '{}');
      end if;
    end loop;
    if e ? 'desde' then v_where := v_where || format(' and x.fecha >= %L::date', e->>'desde'); end if;
    if e ? 'hasta' then v_where := v_where || format(' and x.fecha <= %L::date', e->>'hasta'); end if;
    execute format('select coalesce(sum(x.%I), 0) from public.v_libro x where %s', e->>'campo', v_where) into v_s;
    v_tot := v_tot + coalesce((e->>'signo')::int, 1) * v_s;
  end loop;
  return v_tot;
end $$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los
-- estados (c4), los cuadres de la IA (c8, si está) y lo que detiene el
-- cierre del mes del pago (c9, si está). Como el SQL Editor.
create or replace function pg_temp.c10_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c10_ser('editor');
  select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') into x from fn_banco_control('hoy') k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') into x from fn_estados_control('hoy') k where not k.ok;
  v := v || x;
  if pg_temp.c10('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c10('hay_c9') = 'true' and pg_temp.c10('mes_d') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k where k.nivel = 'detiene' and k.ok is distinct from true $q$
       into x using pg_temp.c10('mes_d');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c10_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- LOS CONTROLES DE c10 que YA estaban en rojo antes de las pruebas (con datos
-- reales puede haberlos: una hora real que cambió después de su reparto…).
-- Las pruebas cuentan lo NUEVO; y la que pone un cuadre en rojo y lo
-- devuelve a verde sale «omitida» si ese cuadre ya estaba en rojo.
insert into _c10 select 'jc_rojos', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_jornal_control k where not k.ok;
insert into _c10 select 'mc_rojos', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_margen_control k where not k.ok;
-- «control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo»
create or replace function pg_temp.c10_propios() returns text language sql as $$
  select format('control del jornal: %s en rojo; del margen: %s en rojo',
                (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_jornal_control k
                  where not k.ok and k.orden::text <> all (string_to_array(pg_temp.c10('jc_rojos'), ','))),
                (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_margen_control k
                  where not k.ok and k.orden::text <> all (string_to_array(pg_temp.c10('mc_rojos'), ','))))
$$;
-- (la fila «omitida» de una prueba cuyo cuadre ya estaba en rojo con datos reales; true si la puso)
create or replace function pg_temp.c10_omitir_rojo(p_n int, p_prueba text, p_esperado text, p_cual text, p_ordenes int[]) returns boolean
language plpgsql as $$
declare
  v text;
begin
  select string_agg(o::text, ', ' order by o) into v
    from unnest(p_ordenes) o
   where o::text = any (string_to_array(pg_temp.c10(case p_cual when 'jornal' then 'jc_rojos' else 'mc_rojos' end), ','));
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    format('omitida: el control %s del %s ya estaba en rojo antes de las pruebas, con los datos de esta base (míralo en v_%s_control): '
           'aquí no se puede ver que pase a rojo y vuelva', v, p_cual, p_cual), null);
  return true;
end $$;

-- Lo que hay en lo que c10 toca (la 58 lo compara)
create or replace function pg_temp.c10_conteos() returns text language sql as $$
  select format('config %s · personas %s · repartos %s · líneas %s · detalle %s · asientos %s · líneas del libro %s · movimientos %s (%s '
                'pendientes) · archivos %s · horas %s (%s aprobadas) · aprobaciones %s · perfiles %s · usuarios %s · tarifas %s · obras %s · '
                'escenarios %s · estimados %s · cerrados %s · funciones %s',
                (select md5(to_jsonb(c)::text) from jornal_config c where c.id = 1), (select count(*) from jornal_personas),
                (select count(*) from jornal_repartos), (select count(*) from jornal_reparto_lineas), (select count(*) from jornal_reparto_horas),
                (select count(*) from asientos), (select count(*) from asiento_lineas), (select count(*) from movimientos_banco),
                (select count(*) from movimientos_banco where estado = 'pendiente'), (select count(*) from archivos_banco),
                (select count(*) from horas), (select count(*) from horas where aprobado_el is not null),
                (select count(*) from horas_aprobaciones), (select count(*) from perfiles), (select count(*) from auth.users),
                (select count(*) from costos_equipo), (select count(*) from proyectos), (select count(*) from escenarios),
                (select count(*) from estimados), (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c10 values ('conteos', pg_temp.c10_conteos());

-- (lo de c3, c4 y c6 que ya estaba en rojo ANTES de las pruebas: la 60 lo dice y no lo cuenta)
insert into _c10
select 'rojos_c3', coalesce(string_agg(control, ', ' order by control), '') from fn_puentes_verificar() where not ok;
insert into _c10
select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _c10
select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;
-- (las funciones AJENAS a c10 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 60
-- las dicen y no las cuentan como fallo de c10. Una función de c10 nunca
-- entra aquí.)
create or replace function pg_temp.c10_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c10
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c10_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c10: %';
-- «permisos» de c2 sin contar lo ajeno de antes: 'verde' o 'rojo: …'
create or replace function pg_temp.c10_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c10_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c10('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c10_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, las 38 funciones por su
--    nombre exacto, la configuración (una fila, con una cuenta que sirve) y
--    cada objeto con su comentario «c10: …».
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 5 tablas | 6 vistas | 38 funciones (38 nombres) | sin comentario c10: ninguno | '
                'configuración: 1 fila, id 1, cuenta del jornal que sirve';
begin
  begin
    perform pg_temp.c10_ser('editor');
    v_pre := coalesce(fn_jornal_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c10_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c10_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(proname);
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c10_tablas()) or c.relname = any (pg_temp.c10_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c10: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c10: %') x;
    select format('%s fila, id %s, cuenta del jornal %s', count(*), min(c.id),
                  case when bool_and(fn_jornal_cuenta_mal(c.cuenta_defecto, 'obra') is null) then 'que sirve' else 'que NO sirve' end)
      into v_cfg from jornal_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c10: %s | configuración: %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 5 tablas, 6 vistas, las 38 funciones por su nombre exacto, la configuración (una fila con una cuenta que sirve) y cada objeto con su comentario «c10: …»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c6 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c10
--    que no lleva su comentario (no es de c10: no se pisa); una vista ajena
--    colgada de una vista de c10 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin fn_banco_descasar: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    -- (desde la app no se instala nada: la función no está en la API)
    perform pg_temp.c10_ser('dueno');
    begin
      v_a := coalesce(fn_jornal_precondiciones(), 'nada');
    exception when others then v_a := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    begin
      drop function public.fn_banco_descasar(uuid, text);
      v_b := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_margen_obra(text) is 'otra cosa';
      v_c := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c10_prueba_ajena as select o.proyecto_id from public.v_margen_obra o;
      v_d := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin fn_banco_descasar: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%fn_banco_descasar(uuid,text)%' then 'la nombra' else v_b end,
                    case when v_c like '%sin ser de c10%' and v_c like '%fn_margen_obra(text)%' and v_c like '%No lo piso%'
                         then 'la nombra y no la pisa' else v_c end,
                    case when v_d like '%c10_prueba_ajena%' and v_d like '%depende(n) de las vistas de c10%' then 'la nombra' else v_d end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se llaman (42501); sin una función de c6 la nombran; una función con nombre de c10 sin su comentario no se pisa; una vista ajena colgada de las de c10 se dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. La API: las de la pantalla, solo authenticated; las internas, nadie;
--    anon y service_role no ejecutan ni leen nada; el equipo (una persona
--    de prueba, con un reparto SUYO ya en el libro) recibe 42501 de las
--    siete funciones de la pantalla y cero filas de las cinco tablas, las
--    seis vistas y las auxiliares de lectura; el dueño entra y ve.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb;
  v_api text; v_sin text; v_anon text; v_srv text; v_x text; v_n int := 0; v_filas bigint := 0; v_k bigint; v_calc text; v_due text;
  v_esp text := 'pantalla mal: ninguna | internas con API: ninguna | anon 42501 y 42501 | service_role 42501 y 42501 | '
                'equipo: 7 de 7 funciones 42501, 0 filas en 5 tablas, 6 vistas y 8 auxiliares, y el cálculo le dice que el movimiento no '
                'existe | dueño: 1 reparto suyo, 12 obras de prueba, el detalle de la obra y 11 + 6 controles';
begin
  if pg_temp.c10_omitir(3, 'la API por rol', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 6.5);
    v_mov := pg_temp.c10_cargo('c10-t3', pg_temp.c10_d(), 362.50, 'Zelle payment to C10 PRUEBA ZZANA 9003');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_jornal_propuesta', 'fn_jornal_aplicar', 'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona',
                         'fn_jornal_repartir', 'fn_margen_obra')
       and not (has_function_privilege('authenticated', p.oid, 'execute')
                and not has_function_privilege('anon', p.oid, 'execute')
                and not has_function_privilege('service_role', p.oid, 'execute'));
    -- las internas: nadie de la API
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_jornal_precondiciones', 'fn_jornal_pegado', 'fn_jornal_guarda')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    -- anon: ni ejecuta ni lee
    perform pg_temp.c10_ser('anon');
    begin perform fn_jornal_propuesta(v_mov); v_anon := 'entró'; exception when others then v_anon := sqlstate; end;
    begin perform count(*) from v_margen_obra; v_anon := v_anon || ' y leyó'; exception when others then v_anon := v_anon || ' y ' || sqlstate; end;
    perform pg_temp.c10_ser('service_role');
    begin perform fn_jornal_config('{}'::jsonb); v_srv := 'entró'; exception when others then v_srv := sqlstate; end;
    begin perform count(*) from jornal_repartos; v_srv := v_srv || ' y leyó'; exception when others then v_srv := v_srv || ' y ' || sqlstate; end;
    -- el equipo: la misma persona a la que se le pagó
    perform pg_temp.c10_ser('p1');
    begin perform fn_jornal_propuesta(v_mov); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 'x'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_deshacer((v_r->>'reparto_id')::uuid, 'no es mío'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_config('{"aviso_tarifa_pct": 1}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO')); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_margen_obra('c10-prueba-a'); exception when insufficient_privilege then v_n := v_n + 1; end;
    select count(*) into v_k from jornal_config;          v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_personas;        v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_repartos;        v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_reparto_lineas;  v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_reparto_horas;   v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_pendientes;    v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_repartos;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_personas;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_control;       v_filas := v_filas + v_k;
    select count(*) into v_k from v_margen_obra;          v_filas := v_filas + v_k;
    select count(*) into v_k from v_margen_control;       v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_lineas(null); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_horas(null);  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_obras(null);  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_estimado(null); v_filas := v_filas + v_k;
    -- (ni lo que se queda fuera de los repartos: las horas tardías, los pagos resueltos por fuera, lo de la IA)
    select count(*) into v_k from fn_jornal_tardias(null); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_jornal_fuera();       v_filas := v_filas + v_k;
    select count(*) into v_k from fn_jornal_ia(v_mov);     v_filas := v_filas + v_k;
    -- (sus horas sí las lee, como siempre; el reparto de un pago por ellas, no)
    select count(*) into v_k from fn_jornal_repartir_ids(array(select h.id from horas h where h.usuario_id = pg_temp.c10('p1')::uuid), 100);
    v_filas := v_filas + v_k;
    v_calc := fn_jornal_calcular(v_mov, null, null)->>'por_que';
    v_x := coalesce(fn_margen_bajar('c10-prueba-a', 'costo')::text, 'nada');
    -- el dueño: entra y ve
    perform pg_temp.c10_ser('dueno');
    select format('%s reparto suyo, %s obras de prueba, %s y %s + %s controles',
                  (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov),
                  (select count(*) from v_margen_obra o where o.proyecto_id like 'c10-prueba-%'),
                  case when fn_margen_obra('c10-prueba-a')->'obra'->>'proyecto_id' = 'c10-prueba-a' then 'el detalle de la obra' else 'sin detalle' end,
                  (select count(*) from v_jornal_control), (select count(*) from v_margen_control))
      into v_due;
    perform pg_temp.c10_ser('editor');
    v_obt := format('pantalla mal: %s | internas con API: %s | anon %s | service_role %s | equipo: %s de 7 funciones 42501, %s filas en 5 '
                    'tablas, 6 vistas y 8 auxiliares, y el cálculo le dice que %s | dueño: %s',
                    v_api, v_sin, v_anon, v_srv, v_n, v_filas,
                    case when v_calc = 'No existe ese movimiento del banco.' and v_x = 'nada' then 'el movimiento no existe' else v_calc || ' / ' || v_x end,
                    v_due);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las de la pantalla solo authenticated y las internas sin API; anon y service_role 42501 (ni ejecutan ni leen); el equipo, con un pago suyo repartido, 42501 en las siete funciones y cero filas en tablas, vistas y auxiliares; el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. El catálogo: nada SECURITY DEFINER; ningún objeto de c10 con un prefijo
--    de otra capa ni de la otra sesión; RLS con su policy de lectura en cada
--    tabla y ni una policy de más; vistas security_invoker que no fijan las
--    columnas que c2-pruebas reescribe ni cuelgan de vistas de otras capas;
--    nada que nombre objetos de la otra sesión; y «permisos» (c2),
--    «protecciones del banco» (c6) y «protecciones de c4» en verde.
do $$
declare
  v_obt text; v_def text; v_pref text; v_rls text; v_pol text; v_vis text; v_fij int; v_dep text; v_otra text;
  v_c2 text; v_c6 text; v_c4 text;
  v_esp text := 'definer: ninguna | prefijos ajenos: ninguno | sin rls o policy: ninguna | policies que no son las suyas: ninguna | '
                'sin security_invoker: ninguna | columnas de c2 fijadas: 0 | vistas de otras capas debajo: ninguna | nombra lo de la otra '
                'sesión: nada | c2 permisos verde | c6 protecciones verde | c4 protecciones verde';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and pg_temp.c10_es_suya(p.proname);
    select coalesce(string_agg(x.que, ', '), 'ninguno') into v_pref
      from (select p.proname::text as que from pg_proc p
             where p.pronamespace = 'public'::regnamespace and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c10: %'
               and (p.proname ~ '^fn_(banco|puente|estados|stripe|plaid|contador|cierre|costos|reporte|horas)_' or p.proname ~ '^fn_reparto_fase')
            union all
            select c.relname::text from pg_class c
             where c.relnamespace = 'public'::regnamespace and coalesce(obj_description(c.oid, 'pg_class'), '') like 'c10: %'
               and c.relname !~ '^(jornal_|v_jornal_|v_margen_)') x;
    select coalesce(string_agg(t.tablename, ', '), 'ninguna') into v_rls
      from pg_tables t
     where t.schemaname = 'public' and t.tablename = any (pg_temp.c10_tablas())
       and (not t.rowsecurity
            or not exists (select 1 from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t.tablename
                              and pl.cmd = 'SELECT' and pl.qual ~ 'es_dueno'));
    -- las policies justas: leer (todas), editar (config, personas, repartos) y añadir (personas, repartos, líneas, detalle)
    select coalesce(string_agg(pl.tablename || '.' || pl.policyname, ', ' order by 1), 'ninguna') into v_pol
      from pg_policies pl
     where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c10_tablas())
       and (not ((pl.policyname = pl.tablename || '_dueno' and pl.cmd = 'SELECT')
                 or (pl.policyname = pl.tablename || '_dueno_edita' and pl.cmd = 'UPDATE'
                     and pl.tablename in ('jornal_config', 'jornal_personas', 'jornal_repartos'))
                 or (pl.policyname = pl.tablename || '_dueno_anade' and pl.cmd = 'INSERT'
                     and pl.tablename in ('jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas')))
            or pl.roles <> '{authenticated}'::name[]);
    select coalesce(string_agg(c.relname, ', '), 'ninguna') into v_vis
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (pg_temp.c10_vistas())
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    -- las columnas que c2-pruebas reescribe (ALTER COLUMN TYPE): ninguna vista de c10 las fija
    select count(*) into v_fij
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
     where d.refclassid = 'pg_class'::regclass and v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c10_vistas())
       and ((d.refobjid = 'public.cuentas'::regclass and a.attname in ('activa', 'saldo_normal'))
            or (d.refobjid = 'public.periodos'::regclass and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cadena_al_cerrar')));
    -- ninguna vista de c10 lee una vista de otra capa (se rehacen al volver a pegar su archivo)
    select coalesce(string_agg(distinct v.relname || ' → ' || b.relname, ', '), 'ninguna') into v_dep
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_class b on d.refclassid = 'pg_class'::regclass and b.oid = d.refobjid
     where v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c10_vistas())
       and b.relkind in ('v', 'm') and b.oid <> v.oid and not (b.relname = any (pg_temp.c10_vistas()));
    -- nada de c10 nombra lo de la otra sesión
    select coalesce(string_agg(x.que, ', '), 'nada') into v_otra
      from (select p.proname::text as que, p.prosrc as src from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
            union all
            select c.relname::text, pg_get_viewdef(c.oid) from pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (pg_temp.c10_vistas())) x
     where x.src ~* '\m(v_estimado_vs_real_obra|horas_tareas|costos_revision|fn_costos_marcar|fn_cierre_obra|fn_reporte_semanal|horas_estimadas_fase|v_horas_por_fase)\M';
    v_c2 := pg_temp.c10_permisos();
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c6
      from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) where vista = 'cuadre: protecciones del banco';
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c4
      from fn_estados_control('hoy', array['v_saldos_dinero']) where vista = 'cuadre: protecciones de c4';
    v_obt := format('definer: %s | prefijos ajenos: %s | sin rls o policy: %s | policies que no son las suyas: %s | sin security_invoker: %s | '
                    'columnas de c2 fijadas: %s | vistas de otras capas debajo: %s | nombra lo de la otra sesión: %s | c2 permisos %s | '
                    'c6 protecciones %s | c4 protecciones %s',
                    v_def, v_pref, v_rls, v_pol, v_vis, v_fij, v_dep, v_otra, v_c2, v_c6, v_c4);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa ni de la otra sesión, RLS y las policies justas, vistas security_invoker que no fijan columnas de c2 ni leen vistas de otras capas, nada nombra lo de la otra sesión; c2 «permisos», c6 y c4 «protecciones» en verde con c10 pegado',
    v_esp,
    v_obt || case when pg_temp.c10('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c10: ' || pg_temp.c10('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 5. La guarda: las tablas de c10 solo las escriben sus funciones. A mano,
--    MX003: el dueño por la API (la policy le deja; la marca no), el SQL
--    Editor sin la marca, y —con la marca— lo que es rastro no se edita ni
--    se borra. Borrar por la API, ni eso (42501). Una persona sin repartos
--    sí se va (con su perfil).
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text;
  v_esp text := 'el dueño por la API: alta a mano MX003, config a mano MX003, borrar 42501 | el editor sin la marca: MX003, truncar MX003, '
                'borrar la configuración MX003, borrar el detalle MX003 | con la marca: editar un reparto MX003, su detalle MX003, '
                'borrarlo MX003, borrar a quien tiene repartos MX003, a quien no tiene: se va';
begin
  if pg_temp.c10_omitir(5, 'la guarda de las tablas de c10', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t5', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9005');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    perform pg_temp.c10_ser('dueno');
    begin insert into jornal_personas (usuario_id, patron) values (pg_temp.c10('p3')::uuid, 'ZZCARO'); a := 'entró';
    exception when others then a := sqlstate; end;
    begin update jornal_config set aviso_tarifa_pct = 1 where id = 1; b := 'entró'; exception when others then b := sqlstate; end;
    begin delete from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid; c := 'entró'; exception when others then c := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    begin
      insert into jornal_repartos (movimiento_id, usuario_id, desde, hasta, regla_periodo, monto, horas, tarifa_sale, cuenta, asiento_id, huella)
      select r.movimiento_id, r.usuario_id, r.desde, r.hasta, r.regla_periodo, r.monto, r.horas, r.tarifa_sale, r.cuenta, r.asiento_id, 'x'
        from jornal_repartos r where r.id = v_rep;
      d := 'entró';
    exception when others then d := sqlstate; end;
    begin truncate jornal_reparto_horas; e := 'entró'; exception when others then e := sqlstate; end;
    begin delete from jornal_config; e := e || ', borrar la configuración entró'; exception when others then e := e || ', borrar la configuración ' || sqlstate; end;
    begin delete from jornal_reparto_horas where reparto_id = v_rep; e := e || ', borrar el detalle entró'; exception when others then e := e || ', borrar el detalle ' || sqlstate; end;
    -- con la marca puesta a mano (el dueño de la base puede): lo que es rastro, ni así
    perform set_config('mx_jornal.escribe', 'jornal_repartos', true);
    begin update jornal_repartos set monto = monto + 1 where id = v_rep; f := 'entró'; exception when others then f := sqlstate; end;
    begin delete from jornal_repartos where id = v_rep; h := 'entró'; exception when others then h := sqlstate; end;
    perform set_config('mx_jornal.escribe', 'jornal_reparto_lineas', true);
    begin update jornal_reparto_lineas set monto = monto + 1 where reparto_id = v_rep; g := 'entró'; exception when others then g := sqlstate; end;
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    begin delete from jornal_personas where usuario_id = pg_temp.c10('p1')::uuid; i := 'entró'; exception when others then i := sqlstate; end;
    begin
      delete from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid;
      j := case when exists (select 1 from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid) then 'sigue' else 'se va' end;
    exception when others then j := sqlstate; end;
    perform set_config('mx_jornal.escribe', '', true);
    v_obt := format('el dueño por la API: alta a mano %s, config a mano %s, borrar %s | el editor sin la marca: %s, truncar %s | con la marca: '
                    'editar un reparto %s, su detalle %s, borrarlo %s, borrar a quien tiene repartos %s, a quien no tiene: %s',
                    a, b, c, d, e, f, g, h, i, j);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda: a mano no se escribe (MX003: el dueño por la API y el SQL Editor sin la marca), nadie borra por la API (42501), y con la marca un reparto y su detalle ni se editan ni se borran; una persona sin repartos sí se va',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. fn_jornal_config: cambia lo que se le dice y nada más, y sus frenos
--    (una clave desconocida, una cuenta que no sirve para cada uso, un %
--    fuera de sitio).
do $$
declare
  v_obt text; v_sin text; v_j jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text; l text;
  v_esp text;
begin
  begin
    perform pg_temp.c10_ser('editor');
    -- una cuenta que sirve para lo sin obra (de gasto, sin obra obligatoria): la 7900 si está
    select c.codigo into v_sin from cuentas c
     where fn_jornal_cuenta_mal(c.codigo, 'sin_obra') is null order by (c.codigo = '7900') desc, c.codigo limit 1;
    v_esp := format('clave desconocida 22023 | no es un objeto 22023 | cuenta del jornal: 5000 MX004, 1010 MX004, no existe MX004 | lo sin '
                    'obra: 5200 MX004 (exige obra), 6000 MX004, %s entra | burden: 101 MX005, 12.555 MX005, 12.5 entra, null lo quita | '
                    'umbral: -1 MX005, 40 entra | lo demás no se mueve: sí', v_sin);
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_config('{"cuenta": "5200"}'); a := 'entró'; exception when others then a := sqlstate; end;
    begin perform fn_jornal_config('[1]'); b := 'entró'; exception when others then b := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "5000"}'); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "1010"}'); d := 'entró'; exception when others then d := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "c10-no-existe"}'); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "5200"}'); f := 'entró';
    exception when others then f := sqlstate || case when sqlerrm like '%exige obra%' then ' (exige obra)' else '' end; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6000"}'); g := 'entró'; exception when others then g := sqlstate; end;
    begin
      v_j := fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
      h := case when v_j->>'cuenta_sin_obra' = v_sin then v_sin || ' entra' else 'no quedó' end;
    exception when others then h := sqlstate; end;
    begin perform fn_jornal_config('{"burden_estandar_pct": 101}'); i := 'entró'; exception when others then i := sqlstate; end;
    begin perform fn_jornal_config('{"burden_estandar_pct": 12.555}'); k := 'entró'; exception when others then k := sqlstate; end;
    v_j := fn_jornal_config('{"burden_estandar_pct": 12.5}');
    l := case when (v_j->>'burden_estandar_pct')::numeric = 12.5 then '12.5 entra' else 'no quedó' end;
    v_j := fn_jornal_config('{"burden_estandar_pct": null}');
    l := l || case when v_j->'burden_estandar_pct' = 'null'::jsonb then ', null lo quita' else ', null no lo quitó' end;
    v_obt := format('clave desconocida %s | no es un objeto %s | cuenta del jornal: 5000 %s, 1010 %s, no existe %s | lo sin obra: 5200 %s, '
                    '6000 %s, %s | burden: 101 %s, 12.555 %s, %s', a, b, c, d, e, f, g, h, i, k, l);
    begin perform fn_jornal_config('{"aviso_tarifa_pct": -1}'); a := 'entró'; exception when others then a := sqlstate; end;
    v_j := fn_jornal_config('{"aviso_tarifa_pct": 40}');
    v_obt := v_obt || format(' | umbral: -1 %s, %s | lo demás no se mueve: %s', a,
                             case when (v_j->>'aviso_tarifa_pct')::numeric = 40 then '40 entra' else 'no quedó' end,
                             -- (el último cambio tocó solo el umbral: la cuenta de lo sin obra sigue, y quedó quién y cuándo)
                             case when v_j->>'cuenta_sin_obra' = v_sin and v_j->>'actualizado_por' = pg_temp.c10('dueno')
                                       and v_j->>'cuenta_defecto' = (select c2.cuenta_defecto from jornal_config c2 where c2.id = 1)
                                  then 'sí' else 'no: ' || v_j::text end);
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'fn_jornal_config y sus frenos: una clave desconocida 22023; la cuenta del jornal no puede ser de nómina, ni un banco, ni inventada (MX004); la de lo sin obra no puede exigir obra ni ser sueldo; el burden de 0 a 100 con dos decimales (MX005) y null lo quita; el umbral de 0 a 500; cambia solo lo que se le dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. fn_jornal_persona: el alta (con su patrón, o el que sale de un
--    movimiento), sus frenos (el dueño no; un perfil que no existe; un
--    patrón que casaría con cualquier pago, corto, o que no es una
--    expresión; una cuenta de nómina; el patrón de otra persona), el cambio
--    y la baja; y v_jornal_personas lo enseña.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text; l text; m text;
  v_esp text := 'alta desde el movimiento: «\mPRUEBA ZZANA\M», 1 pago pendiente | el dueño MX008 | un perfil que no existe 22023 | patrón: '
                '«ZELLE» 22023, «zz» 22023, «(» 22023, vacío 22023 | cuenta 5000 MX004 | el patrón de otra persona MX008 | la vista: Zzana '
                'registrada y activa con 1 pago, Zzbeto sin dar de alta: no sale (sin horas) | con horas, Zzbeto sale sin registrar | la baja: '
                'de baja y 0 pagos | de vuelta con otro patrón: activa y 1 pago | clave desconocida 22023';
begin
  if pg_temp.c10_omitir(7, 'fn_jornal_persona y v_jornal_personas', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_mov := pg_temp.c10_cargo('c10-t7', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9007');
    perform pg_temp.c10_ser('dueno');
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'movimiento_id', v_mov));
    a := format('«%s», %s pago pendiente', v_j->>'patron', v_j->>'pagos_pendientes');
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('dueno'), 'patron', 'EDGAR PRUEBA')); b := 'entró';
    exception when others then b := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', '00000000-0000-4000-a000-0000000c10ff', 'patron', 'NADIE PRUEBA')); c := 'entró';
    exception when others then c := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZELLE')); d := 'entró';
    exception when others then d := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'zz')); e := 'entró';
    exception when others then e := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO (')); f := 'entró';
    exception when others then f := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'))); g := 'entró';
    exception when others then g := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO', 'cuenta', '5000')); h := 'entró';
    exception when others then h := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', '\mprueba zzana\M')); i := 'entró';
    exception when others then i := sqlstate; end;
    select format('Zzana %s con %s pago, Zzbeto %s',
                  (select case when v.registrada and v.activa then 'registrada y activa' else 'mal' end || '' from v_jornal_personas v where v.usuario_id = pg_temp.c10('p1')::uuid),
                  (select v.pagos_pendientes from v_jornal_personas v where v.usuario_id = pg_temp.c10('p1')::uuid),
                  case when exists (select 1 from v_jornal_personas v where v.usuario_id = pg_temp.c10('p2')::uuid) then 'sale'
                       else 'sin dar de alta: no sale (sin horas)' end)
      into k;
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_hora(1, 'p2', pg_temp.c10_w1(2), 'c10-prueba-a', 4);
    perform pg_temp.c10_ser('dueno');
    select case when not v.registrada and not v.activa and v.patron is null and v.horas_90_dias = 4 then 'Zzbeto sale sin registrar'
                else 'mal: ' || to_jsonb(v)::text end
      into l from v_jornal_personas v where v.usuario_id = pg_temp.c10('p2')::uuid;
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', false));
    m := format('%s y %s pagos', case when not (v_j->>'activa')::boolean then 'de baja' else 'sigue activa' end,
                (select count(*) from v_jornal_pendientes p where p.movimiento_id = v_mov));
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', true, 'patron', 'ZZANA 9007'));
    m := m || format(' | de vuelta con otro patrón: %s y %s pago', case when (v_j->>'activa')::boolean and not (v_j->>'nueva')::boolean then 'activa' else 'mal' end,
                     (select count(*) from v_jornal_pendientes p where p.movimiento_id = v_mov));
    v_obt := format('alta desde el movimiento: %s | el dueño %s | un perfil que no existe %s | patrón: «ZELLE» %s, «zz» %s, «(» %s, vacío %s | '
                    'cuenta 5000 %s | el patrón de otra persona %s | la vista: %s | con horas, %s | la baja: %s', a, b, c, d, e, f, g, h, i, k, l, m);
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO', 'tarifa', 30)); a := 'entró';
    exception when others then a := sqlstate; end;
    v_obt := v_obt || ' | clave desconocida ' || a;
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'fn_jornal_persona: el alta con el patrón que sale del movimiento; el dueño no (MX008); frenos del patrón (22023), de la cuenta (MX004) y del patrón repetido (MX008); la baja deja de reconocer sus pagos y el alta de vuelta los reconoce; v_jornal_personas enseña a los dados de alta y a quien tiene horas sin dar de alta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL NÚCLEO (fn_jornal_repartir_ids / fn_jornal_repartir)
-- ---------------------------------------------------------------------
-- Los grupos de un reparto en una línea: obra[/CO] monto, … (lo sin obra al final)
create or replace function pg_temp.c10_grupos(p_ids bigint[], p_monto numeric) returns text language sql as $$
  select coalesce(string_agg(format('%s%s %s', coalesce(replace(g.proyecto_id, 'c10-prueba-', ''), 'sin obra'),
                                    coalesce('/' || g.co, ''), g.monto_grupo), ', ' order by g.grupo), 'ninguno')
    from (select distinct r.grupo, r.proyecto_id, r.co, r.monto_grupo from fn_jornal_repartir_ids(p_ids, p_monto) r) g
$$;
-- ¿Cumple el reparto lo que promete? «N grupos ✓» o lo que falla: los grupos
-- suman el monto; los reportes, también; los de cada grupo, el del grupo;
-- nada negativo; y cada grupo queda a menos de un centavo de su parte exacta.
create or replace function pg_temp.c10_nucleo(p_ids bigint[], p_monto numeric, p_grupos int) returns text language sql as $$
  with r as (select * from fn_jornal_repartir_ids(p_ids, p_monto)),
       g as (select r.grupo, min(r.monto_grupo) as mg, min(r.horas_grupo) as hg, sum(r.monto) as sr, sum(r.horas) as sh,
                    min(r.horas_total) as ht, count(distinct r.monto_grupo) as k
               from r group by r.grupo)
  select case when (select count(*) from g) <> p_grupos then format('%s grupos (se esperaban %s)', (select count(*) from g), p_grupos)
              when (select sum(g.mg) from g) <> p_monto then format('los grupos suman %s y no %s', (select sum(g.mg) from g), p_monto)
              when (select sum(r.monto) from r) <> p_monto then format('los reportes suman %s y no %s', (select sum(r.monto) from r), p_monto)
              when exists (select 1 from g where g.sr <> g.mg or g.sh <> g.hg or g.k <> 1) then 'un grupo no es la suma de sus reportes'
              when exists (select 1 from r where r.monto < 0 or r.monto_grupo < 0) then 'una parte negativa'
              when exists (select 1 from g where abs(g.mg - p_monto * g.hg / g.ht) >= 0.01) then 'un grupo se aleja un centavo o más de su parte'
              when (select count(*) from r) <> cardinality(p_ids) then 'faltan reportes'
              else format('%s grupo%s ✓', p_grupos, case when p_grupos = 1 then '' else 's' end) end
$$;

-- 8. El núcleo: la suma ES el monto, al centavo, con 1, 2, 7 y 12 grupos,
--    con montos que no dividen y horas con decimales.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; v_ids bigint[]; i int;
  v_esp text := '371.33 en una obra: 1 grupo ✓ | 100.00 entre dos: 2 grupos ✓ | 940.00 entre siete: 7 grupos ✓ | 1234.57 entre doce: 12 '
                'grupos ✓ | 0.01 entre tres: 3 grupos ✓ | 999999.99 entre siete: 7 grupos ✓';
begin
  if pg_temp.c10_omitir(8, 'el núcleo: la suma es el monto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- una obra, tres reportes con decimales
    v_ids := array[pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8),
                   pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 7.5),
                   pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 0.25)];
    a := pg_temp.c10_nucleo(v_ids, 371.33, 1);
    -- dos obras
    v_ids := array[pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-a', 8),
                   pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), 'c10-prueba-b', 4.75)];
    b := pg_temp.c10_nucleo(v_ids, 100.00, 2);
    -- siete obras (una semana de las de verdad: más de las 5 líneas de una propuesta de la IA)
    v_ids := '{}';
    for i in 1..7 loop
      v_ids := v_ids || pg_temp.c10_hora(10 + i, 'p2', pg_temp.c10_w1(i - 1),
                                         'c10-prueba-' || (array['a', 'b', 'e', 'f', 'h', 'i', 'j'])[i],
                                         (array[8, 7.5, 6.25, 5, 3.33, 2, 0.5])[i]);
    end loop;
    c := pg_temp.c10_nucleo(v_ids, 940.00, 7);
    f := pg_temp.c10_nucleo(v_ids, 999999.99, 7);
    e := pg_temp.c10_nucleo(v_ids[1:3], 0.01, 3);
    -- doce obras, con dos reportes en algunas
    v_ids := '{}';
    for i in 1..12 loop
      v_ids := v_ids || pg_temp.c10_hora(30 + i, 'p3', pg_temp.c10_w2((i - 1) % 7), 'c10-prueba-' || chr(96 + i), 0.75 * i);
      if i % 3 = 0 then
        v_ids := v_ids || pg_temp.c10_hora(50 + i, 'p3', pg_temp.c10_w2(i % 7), 'c10-prueba-' || chr(96 + i), 1.1);
      end if;
    end loop;
    d := pg_temp.c10_nucleo(v_ids, 1234.57, 12);
    v_obt := format('371.33 en una obra: %s | 100.00 entre dos: %s | 940.00 entre siete: %s | 1234.57 entre doce: %s | 0.01 entre tres: %s | '
                    '999999.99 entre siete: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'EL NÚCLEO: la suma de los grupos y la de los reportes es el monto, al centavo (1, 2, 7 y 12 grupos; montos que no dividen; horas con decimales; un centavo entre tres; casi un millón), cada grupo es la suma de sus reportes y ninguno se aleja un centavo de su parte',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. El núcleo: los mayores restos y sus desempates, calculados a mano; y
--    es determinista (dos veces, y con los reportes dados en otro orden).
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text; h text; v_ids bigint[]; x bigint; y bigint; z bigint;
  v_esp text := 'a 33.34, b 33.33, h 33.33 | a 3.33, b 6.67 | a 0.01, b 0.00, h 0.00 | a 0.00, b 0.02 | h 0.01, sin obra 0.00 | '
                'a 0.01, a/CO #1 0.00 | dentro del grupo, el centavo va al de la fecha más vieja | dos veces igual, y con los reportes al revés';
begin
  if pg_temp.c10_omitir(9, 'el núcleo: los mayores restos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- tres obras con las mismas horas: el centavo que sobra va a la primera por su id
    x := pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 1);
    y := pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(0), 'c10-prueba-b', 1);
    z := pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 1);
    a := pg_temp.c10_grupos(array[x, y, z], 100.00);
    c := pg_temp.c10_grupos(array[x, y, z], 0.01);
    -- 1 h y 2 h: 333.33… y 666.66… centavos; el resto mayor es el de la b
    y := pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 2);
    b := pg_temp.c10_grupos(array[x, y], 10.00);
    -- restos iguales (2 centavos entre 1 h y 3 h): gana quien tiene más horas
    y := pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 3);
    d := pg_temp.c10_grupos(array[x, y], 0.02);
    -- empate entero entre una obra y lo sin obra: lo sin obra, el último
    y := pg_temp.c10_hora(6, 'p1', pg_temp.c10_w1(3), null, 1);
    e := pg_temp.c10_grupos(array[z, y], 0.01);
    -- empate entre la base y un CO de la misma obra: la base primero
    y := pg_temp.c10_hora(7, 'p1', pg_temp.c10_w1(4), 'c10-prueba-a', 1, 'CO #1');
    f := pg_temp.c10_grupos(array[x, y], 0.01);
    -- dentro de un grupo: dos reportes iguales, el centavo al de la fecha más vieja
    y := pg_temp.c10_hora(8, 'p1', pg_temp.c10_w1(5), 'c10-prueba-a', 1);
    select case when (select r.monto from fn_jornal_repartir_ids(array[y, x], 0.01) r where r.horas_id = x) = 0.01
                     and (select r.monto from fn_jornal_repartir_ids(array[y, x], 0.01) r where r.horas_id = y) = 0.00
                then 'dentro del grupo, el centavo va al de la fecha más vieja' else 'mal' end into g;
    -- determinista
    v_ids := array(select hh.id from horas hh where hh.usuario_id = pg_temp.c10('p1')::uuid order by hh.id);
    select case when (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                     = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                     and (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                       = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id))
                            from fn_jornal_repartir_ids(array(select u from unnest(v_ids) u order by u desc), 777.77) r)
                then 'dos veces igual, y con los reportes al revés' else 'cambia' end into h;
    v_obt := concat_ws(' | ', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'el núcleo, a mano: el centavo que sobra va al resto mayor; a resto igual, a quien tiene más horas; a horas iguales, por obra y CO (la base antes que el CO, lo sin obra al final); dentro del grupo, por fecha; y es determinista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. El núcleo: con CO (el mismo CO con espacios es el mismo; un CO vacío es
--     la base), las horas sin obra (un grupo, al final, sin CO), sin horas
--     (ninguna fila), los montos mal (MX005) y por persona y período.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; v_ids bigint[];
  v_esp text := 'a 40.00, a/CO #1 30.00, b 10.00, sin obra 20.00 (4 grupos ✓) | sin horas: 0 filas | monto 0 MX005, negativo MX005, con '
                'milésimas MX005, nulo MX005 | por persona y período = por sus reportes | fuera del período no entra | fechas al revés 22023';
begin
  if pg_temp.c10_omitir(10, 'el núcleo: CO, sin obra, sin horas, montos mal', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_ids := array[pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 4),
                   pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1'),
                   pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 1, '  CO #1 '),
                   pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-b', 1, ''),
                   pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), null, 2, 'CO #9')];
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 9);   -- (otra semana)
    a := format('%s (%s)', pg_temp.c10_grupos(v_ids, 100.00), pg_temp.c10_nucleo(v_ids, 100.00, 4));
    perform pg_temp.c10_ser('dueno');
    select format('sin horas: %s filas', count(*)) into b from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100);
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, 0); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, -5); c := c || ', negativo entró'; exception when others then c := c || ', negativo ' || sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, 10.005); c := c || ', con milésimas entró'; exception when others then c := c || ', con milésimas ' || sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, null); c := c || ', nulo entró'; exception when others then c := c || ', nulo ' || sqlstate; end;
    select case when (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id))
                        from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r)
                     = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 100.00) r)
                then 'por persona y período = por sus reportes' else 'no coinciden' end,
           case when (select count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r
                       where r.proyecto_id = 'c10-prueba-h') = 0 then 'fuera del período no entra' else 'entró lo de otra semana' end
      into d, e;
    begin perform count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(6), pg_temp.c10_w1(0), 100); f := 'entró'; exception when others then f := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('%s | %s | monto 0 %s | %s | %s | fechas al revés %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'el núcleo: la base y cada CO son grupos aparte (el CO con espacios es el mismo; vacío, la base), lo sin obra es un grupo al final y sin CO, sin horas no hay filas, un monto mal da MX005, y por persona y período da lo mismo que por sus reportes',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LA REGLA DEL PERÍODO
-- ---------------------------------------------------------------------
-- 11. Cada día de la semana: de lunes a miércoles, la semana anterior (de
--     lunes a domingo); de jueves a domingo, la semana en curso.
do $$
declare
  v_obt text;
  v_esp text := 'lun 2-nov → 26-oct a 1-nov (anterior) | mar 3-nov → 26-oct a 1-nov (anterior) | mié 4-nov → 26-oct a 1-nov (anterior) | '
                'jue 5-nov → 2-nov a 8-nov (en curso) | vie 6-nov → 2-nov a 8-nov (en curso) | sáb 7-nov → 2-nov a 8-nov (en curso) | '
                'dom 8-nov → 2-nov a 8-nov (en curso)';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s → %s a %s (%s)', (array['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'])[extract(isodow from g.d)::int],
                             fn_jornal_dia(g.d::date), fn_jornal_dia(p.desde), fn_jornal_dia(p.hasta),
                             case p.regla when 'semana_anterior' then 'anterior' when 'semana_en_curso' then 'en curso' else p.regla end),
                      ' | ' order by g.d)
      into v_obt
      from generate_series(date '2026-11-02', date '2026-11-08', interval '1 day') g(d)
      cross join lateral fn_jornal_periodo(g.d::date) p;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'la regla del período, cada día de la semana: pago de lunes a miércoles → la semana anterior (lunes a domingo); de jueves a domingo → la semana en curso',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. El cambio de hora (1-nov-2026 y 14-mar-2027), el fin de año, el 29 de
--     febrero; 400 días seguidos siempre de lunes a domingo; y lo mismo con
--     la sesión en otra zona horaria (la regla es de fechas, no de horas).
do $$
declare
  v_obt text; a text; b text; c text; d text;
  v_esp text := 'dom 1-nov-2026 → 26-oct a 1-nov-2026 (en curso) | lun 2-nov-2026 → 26-oct a 1-nov-2026 (anterior) | dom 14-mar-2027 → '
                '8-mar a 14-mar-2027 (en curso) | lun 15-mar-2027 → 8-mar a 14-mar-2027 (anterior) | jue 31-dic-2026 → 28-dic a 3-ene-2027 '
                '(en curso) | lun 4-ene-2027 → 28-dic a 3-ene-2027 (anterior) | mar 29-feb-2028 → 21-feb a 27-feb-2028 (anterior) | 400 días '
                'seguidos: siempre de lunes a domingo, la semana del pago o la de antes | igual en Kiritimati, en Los Ángeles y en UTC';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s → %s a %s (%s)', (array['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'])[extract(isodow from g.d)::int],
                             fn_jornal_dia(g.d, true), fn_jornal_dia(p.desde), fn_jornal_dia(p.hasta, true),
                             case p.regla when 'semana_anterior' then 'anterior' else 'en curso' end), ' | ' order by g.o)
      into a
      from unnest(array[date '2026-11-01', date '2026-11-02', date '2027-03-14', date '2027-03-15', date '2026-12-31', date '2027-01-04',
                        date '2028-02-29']) with ordinality as g(d, o)
      cross join lateral fn_jornal_periodo(g.d) p;
    select case when count(*) = 400
                     and bool_and(extract(isodow from p.desde) = 1 and p.hasta = p.desde + 6
                                  and ((p.regla = 'semana_en_curso' and g.d::date between p.desde and p.hasta and extract(isodow from g.d) >= 4)
                                       or (p.regla = 'semana_anterior' and g.d::date between p.desde + 7 and p.desde + 9)))
                then '400 días seguidos: siempre de lunes a domingo, la semana del pago o la de antes' else 'algún día mal' end
      into b
      from generate_series(date '2026-09-30', date '2026-09-30' + 399, interval '1 day') g(d)
      cross join lateral fn_jornal_periodo(g.d::date) p;
    select md5(string_agg(p::text, '|' order by g.d)) into c
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    set local timezone = 'Pacific/Kiritimati';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := case when c = d then 'Kiritimati' else 'CAMBIA en Kiritimati' end;
    set local timezone = 'America/Los_Angeles';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := v_obt || case when c = d then ', en Los Ángeles' else ', CAMBIA en Los Ángeles' end;
    set local timezone = 'UTC';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := format('%s | %s | igual en %s%s', a, b, v_obt, case when c = d then ' y en UTC' else ' y CAMBIA en UTC' end);
    raise exception using errcode = 'MXT00';   -- (la zona de la sesión vuelve a ser la que era)
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'la regla del período no se mueve con el cambio de hora (1-nov-2026, 14-mar-2027), ni en fin de año, ni el 29 de febrero, ni con la sesión en otra zona horaria; siempre una semana de lunes a domingo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. Las fechas a mano: la propuesta va por las horas de las fechas que se
--     pidan y dice qué regla es (la semana anterior, la del pago, o a mano);
--     y sus frenos (una sola fecha, al revés, más de 62 días).
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; a text; b text; c text; d text; e text; f text; g text; h text; i text; v_def record;
  v_esp text := 'dos semanas atrás: a_mano, 4 h | la semana anterior a la del pago: semana_anterior, 10 h | un solo día: a_mano, 8 h | las dos '
                'semanas: a_mano, 14 h | una sola fecha 22023 | al revés 22023 | 63 días 22023 | 62 días: entra | sin fechas: la de la regla';
begin
  if pg_temp.c10_omitir(13, 'las fechas a mano', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 4);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(3), 'c10-prueba-b', 2);
    v_mov := pg_temp.c10_cargo('c10-t13', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9013');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    a := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(0));
    c := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    d := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), null); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6), pg_temp.c10_w1(0)); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6) - 62, pg_temp.c10_w1(6)); g := 'entró'; exception when others then g := sqlstate; end;
    begin
      v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6) - 61, pg_temp.c10_w1(6));
      h := case when v_j->'periodo'->>'regla' = 'a_mano' and (v_j->>'horas')::numeric = 14 then 'entra' else 'mal: ' || (v_j->'periodo')::text end;
    exception when others then h := sqlstate; end;
    -- sin fechas: la semana que dice la regla para el día del pago (la 11 y la 12 prueban la regla)
    select * into v_def from fn_jornal_periodo(pg_temp.c10_d());
    v_j := pg_temp.c10_propuesta(v_mov);
    i := case when (v_j->'periodo'->>'desde')::date = v_def.desde and (v_j->'periodo'->>'hasta')::date = v_def.hasta
                   and v_j->'periodo'->>'regla' = v_def.regla and v_j->'periodo'->'por_defecto'->>'regla' = v_def.regla
                   and v_def.regla = case when extract(isodow from pg_temp.c10_d()) <= 3 then 'semana_anterior' else 'semana_en_curso' end
              then 'la de la regla' else 'otra: ' || (v_j->'periodo')::text end;
    v_obt := format('dos semanas atrás: %s | la semana anterior a la del pago: %s | un solo día: %s | las dos semanas: %s | una sola fecha %s | '
                    'al revés %s | 63 días %s | 62 días: %s | sin fechas: %s', a, b, c, d, e, f, g, h, i);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'las fechas a mano: la propuesta va por las horas de las fechas pedidas y nombra la regla (semana_anterior, semana_en_curso o a_mano); una sola fecha, las fechas al revés o más de 62 días, 22023; sin fechas, la semana de la regla',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LA PROPUESTA (fn_jornal_propuesta: solo lee)
-- ---------------------------------------------------------------------
-- 14. Reconoce por el patrón y SOLO a los dados de alta: el pago de quien no
--     lo está no se reconoce (y trae el patrón que saldría y a quién se
--     parece); el nombre puede venir en la nota del banco; si casa con dos
--     personas, con ninguna; y a quien se da de baja se le deja de reconocer.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'el de Zzana: reconocido (p1) | el de Zzbeto, sin dar de alta: no, sugiere «\mPRUEBA ZZBETO\M» y lo ofrece (p2) | con el nombre '
                'en la nota del banco: reconocido (p1) | si casa con dos: no, y nombra a las dos | afinado: p1 y p2 | de baja: no';
begin
  if pg_temp.c10_omitir(14, 'la propuesta reconoce por el patrón', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    m1 := pg_temp.c10_cargo('c10-t14-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9141');
    m2 := pg_temp.c10_cargo('c10-t14-2', pg_temp.c10_d(), 310.00, 'Zelle payment to C10 PRUEBA ZZBETO 9142');
    m3 := pg_temp.c10_cargo('c10-t14-3', pg_temp.c10_d(), 320.00, 'Zelle payment 9143 C10 PRUEBA', 'C10 PRUEBA ZZANA semana');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1);
    a := case when (v_j->>'reconocido')::boolean then format('reconocido (%s)', (select k from _c10 where v = v_j->'persona'->>'usuario_id')) else 'no' end;
    v_j := pg_temp.c10_propuesta(m2);
    b := case when (v_j->>'reconocido')::boolean then 'reconocido'
              else format('no, sugiere «%s» y lo ofrece (%s)', v_j->>'patron_sugerido',
                          (select string_agg((select k from _c10 where v = q->>'usuario_id'), ',') from jsonb_array_elements(v_j->'candidatos') q)) end;
    v_j := pg_temp.c10_propuesta(m3);
    c := case when (v_j->>'reconocido')::boolean then format('reconocido (%s)', (select k from _c10 where v = v_j->'persona'->>'usuario_id')) else 'no: ' || (v_j->>'por_que') end;
    -- un patrón demasiado ancho en la segunda persona: el pago de Zzana casa con las dos
    perform pg_temp.c10_alta('p2', '\mPRUEBA ZZ');
    v_j := pg_temp.c10_propuesta(m1);
    d := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like '%casa con 2 personas%' and v_j->>'por_que' like '%Zzana C10 PRUEBA y Zzbeto C10 PRUEBA%'
              then 'no, y nombra a las dos' else coalesce(v_j->>'por_que', 'reconocido') end;
    perform pg_temp.c10_alta('p2');
    e := format('%s y %s', (select k from _c10 where v = pg_temp.c10_propuesta(m1)->'persona'->>'usuario_id'),
                (select k from _c10 where v = pg_temp.c10_propuesta(m2)->'persona'->>'usuario_id'));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', false));
    perform pg_temp.c10_ser('editor');
    f := case when (pg_temp.c10_propuesta(m1)->>'reconocido')::boolean then 'sigue reconocido' else 'no' end;
    v_obt := format('el de Zzana: %s | el de Zzbeto, sin dar de alta: %s | con el nombre en la nota del banco: %s | si casa con dos: %s | afinado: %s | '
                    'de baja: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'la propuesta reconoce el pago por el patrón y solo a los dados de alta: sin alta no (con el patrón que saldría y el perfil al que se parece); el nombre vale también en la nota del banco; si casa con dos personas, con ninguna; de baja, tampoco',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. No es un abono, ni un movimiento ya resuelto (ignorado, clasificado a
--     mano en la Bandeja, o ya repartido), ni uno que no existe.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; m4 uuid; v_j jsonb; v_r jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'un abono: no (es un abono) | ignorado: no (resuelto en el banco) | clasificado a mano: no (resuelto en el banco) | ya repartido: '
                'no, y trae su reparto | no existe: no | sin movimiento 22023 | entre los pendientes: ninguno de los cuatro';
begin
  if pg_temp.c10_omitir(15, 'la propuesta: ni abono ni movimiento resuelto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t15-1', pg_temp.c10_d(), -500.00, 'Zelle payment from C10 PRUEBA ZZANA 9151');
    m2 := pg_temp.c10_cargo('c10-t15-2', pg_temp.c10_d(), 111.11, 'Zelle payment to C10 PRUEBA ZZANA 9152');
    m3 := pg_temp.c10_cargo('c10-t15-3', pg_temp.c10_d(), 122.22, 'Zelle payment to C10 PRUEBA ZZANA 9153');
    m4 := pg_temp.c10_cargo('c10-t15-4', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9154');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_ignorar(m2, 'c10-pruebas: no era de la empresa (se deshace)');
    perform fn_banco_clasificar(m3, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}]'::jsonb, 'c10-pruebas: un subcontrato de verdad');
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(m4, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_j := pg_temp.c10_propuesta(m1);
    a := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Es un abono%' then 'no (es un abono)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m2);
    b := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este movimiento ya está resuelto en el banco%' then 'no (resuelto en el banco)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m3);
    c := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este movimiento ya está resuelto en el banco%' then 'no (resuelto en el banco)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m4);
    d := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este pago ya está repartido%'
                   and v_j->'reparto'->>'reparto_id' = v_r->>'reparto_id' then 'no, y trae su reparto' else v_j::text end;
    v_j := pg_temp.c10_propuesta('00000000-0000-4000-a000-0000000c10fe');
    e := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' = 'No existe ese movimiento del banco.' then 'no' else v_j::text end;
    begin perform pg_temp.c10_propuesta(null); f := 'entró'; exception when others then f := sqlstate; end;
    perform pg_temp.c10_ser('dueno');
    v_obt := format('un abono: %s | ignorado: %s | clasificado a mano: %s | ya repartido: %s | no existe: %s | sin movimiento %s | entre los '
                    'pendientes: %s', a, b, c, d, e, f,
                    (select case when count(*) = 0 then 'ninguno de los cuatro' else count(*)::text end
                       from v_jornal_pendientes p where p.movimiento_id in (m1, m2, m3, m4)));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'la propuesta no reconoce un abono, ni un movimiento ya resuelto en el banco (ignorado o clasificado a mano), ni uno ya repartido (trae su reparto), ni uno que no existe; y ninguno sale entre los pendientes',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. Lo que trae la propuesta: las líneas por obra y CO que suman el pago,
--     las horas, el detalle por reporte, las dos semanas para elegir, la
--     tarifa que sale junto a la suya, y la huella: estable mientras nada
--     cambie, y otra en cuanto cambian las horas, hay un reporte nuevo o
--     cambian las fechas.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'a 8→200.00, a/CO #1 6.5→162.50, b 1.5→37.50, e 4→100.00 | 20 h, 4 reportes, 3 obras | sale a 25.00 la hora (la suya 25, desvío '
                '0) | el detalle: 5 reportes, 4 entran y suman 500.00 | las dos semanas: la anterior 20 h, la del pago 3 h | se puede aplicar, '
                'sin avisos | la huella: 32 letras, estable; otra con otras horas, con un reporte nuevo y con otras fechas';
begin
  if pg_temp.c10_omitir(16, 'lo que trae la propuesta', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6.5, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 1.5, null, 'trim');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-e', 4);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10('lunes')::date, 'c10-prueba-h', 3);   -- (la semana del pago)
    v_mov := pg_temp.c10_cargo('c10-t16', pg_temp.c10_d(), 500.00, 'Zelle payment to C10 PRUEBA ZZANA 9016');
    perform pg_temp.c10_alta('p1');
    -- (las dos semanas se piden juntas para ver los cinco reportes: los de la del pago no entran)
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_lineas(v_j);
    b := format('%s h, %s reportes, %s obras', trim_scale((v_j->>'horas')::numeric), v_j->>'reportes', v_j->>'obras');
    c := format('sale a %s la hora (la suya %s, desvío %s)', v_j->>'tarifa_sale', v_j->>'tarifa_equipo', trim_scale((v_j->>'tarifa_desvio_pct')::numeric));
    v_k := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10('lunes')::date + 6, '{}'::jsonb);
    select format('%s reportes, %s entran y suman %s', jsonb_array_length(v_k->'detalle'),
                  (select count(*) from jsonb_array_elements(v_j->'detalle') x where (x->>'entra')::boolean),
                  (select sum((x->>'monto')::numeric) from jsonb_array_elements(v_j->'detalle') x where (x->>'entra')::boolean))
      into d;
    select format('la anterior %s h, la del pago %s h',
                  (select trim_scale((o->>'horas')::numeric) from jsonb_array_elements(v_j->'periodo'->'opciones') o where o->>'regla' = 'semana_anterior'),
                  (select trim_scale((o->>'horas')::numeric) from jsonb_array_elements(v_j->'periodo'->'opciones') o where o->>'regla' = 'semana_en_curso'))
      into e;
    f := case when (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' is null and pg_temp.c10_avisos(v_j) = '-' then 'se puede aplicar, sin avisos'
              else format('puede %s, avisos %s', v_j->>'puede_aplicar', pg_temp.c10_avisos(v_j)) end;
    g := case when v_j->>'visto' ~ '^[0-9a-f]{32}$' then '32 letras' else 'rara' end
         || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' = v_j->>'visto' then ', estable' else ', NO estable' end;
    begin
      perform pg_temp.c10_corregir(1, 'horas = 7');
      g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' <> v_j->>'visto' then '; otra con otras horas' else '; la MISMA con otras horas' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w1(5), 'c10-prueba-a', 1);
      g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' <> v_j->>'visto' then ', con un reporte nuevo' else ', la MISMA con un reporte nuevo' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(5))->>'visto' <> v_j->>'visto' then ' y con otras fechas' else ' y la MISMA con otras fechas' end;
    v_obt := format('%s | %s | %s | el detalle: %s | las dos semanas: %s | %s | la huella: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'lo que trae la propuesta: las líneas por obra y CO (suman el pago), las horas, los reportes y las obras, la tarifa que sale junto a la de Costos del equipo, el detalle por reporte, las dos semanas para elegir con sus horas, y la huella (estable; cambia con las horas, con un reporte nuevo y con las fechas)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. Los avisos (a): sin horas en esas fechas (no deja aplicar); la tarifa
--     que sale lejos de la suya (un aviso, nunca un freno; el umbral se
--     cambia); y la persona sin tarifa.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; m4 uuid; v_j jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'sin horas: no deja y lo dice [sin_horas] | 40.00 la hora contra 25: avisa (60 % más) y deja [tarifa_lejos] | con el umbral en '
                '80: no avisa [-] | 15.00 la hora: avisa (40 % menos) [tarifa_lejos] | 26.00 la hora: no avisa [-] | sin tarifa: avisa y deja '
                '[sin_tarifa]';
begin
  if pg_temp.c10_omitir(17, 'los avisos: sin horas, la tarifa, sin tarifa', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 10);
    perform pg_temp.c10_hora(2, 'p3', pg_temp.c10_w2(1), 'c10-prueba-a', 5);
    m1 := pg_temp.c10_cargo('c10-t17-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9171');
    m2 := pg_temp.c10_cargo('c10-t17-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9172');
    m3 := pg_temp.c10_cargo('c10-t17-3', pg_temp.c10_d(), 260.00, 'Zelle payment to C10 PRUEBA ZZANA 9173');
    m4 := pg_temp.c10_cargo('c10-t17-4', pg_temp.c10_d(), 100.00, 'Zelle payment to C10 PRUEBA ZZCARO 9174');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p3');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 25}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%no tiene horas reportadas%' then 'no deja y lo dice' else 'mal: ' || coalesce(v_j->>'por_que', 'deja') end,
                pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    b := format('%s la hora contra %s: %s y %s [%s]', v_j->>'tarifa_sale', v_j->>'tarifa_equipo',
                case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%(60 % más)%' and pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%Es solo un aviso%' then 'avisa (60 % más)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 80}');
    perform pg_temp.c10_ser('editor');
    c := format('%s [%s]', case when pg_temp.c10_aviso(pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6)), 'tarifa_lejos') is null then 'no avisa' else 'avisa' end,
                pg_temp.c10_avisos(pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6))));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 25}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('%s la hora: %s [%s]', v_j->>'tarifa_sale',
                case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%(40 % menos)%' then 'avisa (40 % menos)' else 'no lo dice bien' end, pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m3, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    e := format('%s la hora: %s [%s]', v_j->>'tarifa_sale', case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') is null then 'no avisa' else 'avisa' end,
                pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m4, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    f := format('%s y %s [%s]', case when pg_temp.c10_aviso(v_j, 'sin_tarifa') like '%no tiene tarifa en Costos del equipo%' and v_j->'tarifa_equipo' = 'null'::jsonb then 'avisa' else 'no avisa' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    v_obt := format('sin horas: %s | %s | con el umbral en 80: %s | %s | %s | sin tarifa: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'los avisos: sin horas en esas fechas no deja aplicar; la tarifa que sale lejos de la de Costos del equipo avisa en llano (cuánto más o menos) y deja; el umbral se cambia; dentro del umbral no avisa; sin tarifa, avisa y deja',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. Los avisos (b): horas en una obra terminada o cancelada (avisa y
--     deja: su parte va a esa obra), en una sin aprobar; horas sin obra sin
--     la cuenta fijada (no deja) y con ella (deja); y una cuenta que ya no
--     sirve (no deja).
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_sin text; a text; b text; c text; d text; e text; f text;
  v_esp text;
begin
  if pg_temp.c10_omitir(18, 'los avisos: la obra y las cuentas', 'obra terminada, obra sin aprobar, falta la cuenta de lo sin obra, una cuenta que no sirve') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('terminada y no aprobada: avisa (C terminada, D no aprobada) y deja | sin aprobar: avisa (G) y deja | sin obra y sin su '
                    'cuenta: no deja [falta_cuenta_sin_obra], 3 h y 75.00 | con su cuenta (%s): deja [-] | la cuenta de la persona ya no '
                    'sirve: no deja [cuenta_mal] | la de lo sin obra ya no sirve: no deja [cuenta_mal]', v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-c', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-d', 2);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-g', 2);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 5);
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(1), null, 3);
    m1 := pg_temp.c10_cargo('c10-t18-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9181');
    m2 := pg_temp.c10_cargo('c10-t18-2', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9182');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"cuenta_sin_obra": null}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'obra_terminada') like '%C10 PRUEBA Obra C (terminada)%'
                                     and pg_temp.c10_aviso(v_j, 'obra_terminada') like '%C10 PRUEBA Obra D (no aprobada)%'
                                     and pg_temp.c10_aviso(v_j, 'obra_terminada') like '%Su parte va a esa obra igual%' then 'avisa (C terminada, D no aprobada)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end);
    b := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'obra_sin_aprobar') like '%C10 PRUEBA Obra G (estimando)%' then 'avisa (G)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean and pg_temp.c10_avisos(v_j) = 'obra_terminada,obra_sin_aprobar' then 'deja' else 'NO deja o sobran avisos: ' || pg_temp.c10_avisos(v_j) end);
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    c := format('%s [%s], %s h y %s', case when not (v_j->>'puede_aplicar')::boolean and (v_j->'sin_obra'->>'falta_cuenta')::boolean
                                               and v_j->>'por_que' like '%no tienen obra%' then 'no deja' else 'DEJA' end,
                pg_temp.c10_avisos(v_j), trim_scale((v_j->'sin_obra'->>'horas')::numeric), v_j->'sin_obra'->>'monto');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('%s [%s]', case when (v_j->>'puede_aplicar')::boolean and v_j->'sin_obra'->>'cuenta' = v_sin then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    -- una cuenta que dejó de servir después (escrita aquí por debajo de fn_jornal_persona / fn_jornal_config, con la marca)
    begin
      perform set_config('mx_jornal.escribe', 'jornal_personas', true);
      update jornal_personas set cuenta = '5000' where usuario_id = pg_temp.c10('p1')::uuid;
      perform set_config('mx_jornal.escribe', '', true);
      v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      e := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like 'La cuenta del jornal de Zzana C10 PRUEBA no sirve%' then 'no deja' else 'DEJA' end,
                  (select string_agg(a2->>'codigo', ',') from jsonb_array_elements(v_j->'avisos') a2 where a2->>'codigo' = 'cuenta_mal'));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      perform set_config('mx_jornal.escribe', 'jornal_config', true);
      update jornal_config set cuenta_sin_obra = '5200' where id = 1;
      perform set_config('mx_jornal.escribe', '', true);
      v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
      f := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like 'La cuenta de lo sin obra ya no sirve%' then 'no deja' else 'DEJA' end,
                  pg_temp.c10_avisos(v_j));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('terminada y no aprobada: %s | sin aprobar: %s | sin obra y sin su cuenta: %s | con su cuenta (%s): %s | la cuenta de la persona '
                    'ya no sirve: %s | la de lo sin obra ya no sirve: %s', a, b, c, v_sin, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'los avisos: horas en una obra terminada o no aprobada —como la llama la app; no «cancelada»— (avisa y deja: su parte va a esa obra) o sin aprobar; horas sin obra sin la cuenta fijada (no deja, y dice cuántas horas y cuánto) y con ella (deja); una cuenta que ya no sirve (no deja)',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 19. Los avisos (c): las horas que ya cubre otro pago no entran otra vez
--     (todas cubiertas: no deja; con horas nuevas: solo por las nuevas);
--     «es otro pago de las mismas horas» las mete porque Edgar lo pide; y
--     las fechas posteriores al pago.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text;
  v_esp text := 'todo cubierto: no deja (ya entraron en otro reparto) [sin_horas,se_pisa] | con 3 h nuevas, solo por ellas: h 3→75.00 '
                '[horas_cubiertas,se_pisa], cubiertas 12 h en 2 reportes | «es otro pago de las mismas horas»: a 8→40.00, b 4→20.00, h '
                '3→15.00 [horas_cubiertas,se_pisa,tarifa_lejos] | fechas posteriores al pago: avisa [sin_horas,horas_tardias,periodo_futuro]';
begin
  if pg_temp.c10_omitir(19, 'los avisos: horas ya cubiertas y fechas posteriores', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t19-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9191');
    m2 := pg_temp.c10_cargo('c10-t19-2', pg_temp.c10_d(), 75.00, 'Zelle payment to C10 PRUEBA ZZANA 9192');
    m3 := pg_temp.c10_cargo('c10-t19-3', pg_temp.c10_d(), 90.00, 'Zelle payment to C10 PRUEBA ZZANA 9193');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%ya entraron en otro reparto%' then 'no deja (ya entraron en otro reparto)' else 'DEJA' end,
                pg_temp.c10_avisos(v_j));
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(4), 'c10-prueba-h', 3);
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s [%s], cubiertas %s h en %s reportes', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j),
                trim_scale((v_j->'cubiertas'->>'horas')::numeric), v_j->'cubiertas'->>'reportes');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    c := format('%s [%s]', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m3, pg_temp.c10_d() + 1, pg_temp.c10_d() + 7);
    d := format('%s [%s]', case when pg_temp.c10_aviso(v_j, 'periodo_futuro') like '%empiezan después del día del pago%' then 'avisa' else 'no avisa' end,
                pg_temp.c10_avisos(v_j));
    v_obt := format('todo cubierto: %s | con 3 h nuevas, solo por ellas: %s | «es otro pago de las mismas horas»: %s | fechas posteriores al '
                    'pago: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'los avisos: las horas que ya cubre otro pago no entran otra vez (si todas lo están, no deja; con horas nuevas reparte solo por ellas y dice cuáles cubre el otro); con «incluir_cubiertas» entran porque Edgar lo pide; y avisa de unas fechas posteriores al pago',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. Los avisos (d): un posible duplicado sin decidir (el banco trajo el
--     mismo pago con otro número: no deja hasta que Edgar diga), y un mes
--     con devengo estándar de horas (c3: avisa de que saldría dos veces).
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text; v_mes text; v_dia date; v_dev jsonb; v_no text;
  v_esp text := 'el parecido: posible duplicado, no deja [posible_duplicado] | el primero: deja | dicho «no es el mismo»: deja [-] | con el '
                'devengo estándar de ese mes: avisa, con el mes y su asiento [devengo_estandar]';
begin
  if pg_temp.c10_omitir(20, 'los avisos: posible duplicado y devengo estándar', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (el devengo, en el mes del pago, que está abierto: el día 1, con otra persona para no mezclar)
    v_dia := date_trunc('month', pg_temp.c10_d())::date;
    v_mes := to_char(v_dia, 'YYYY-MM');
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', v_dia, 'c10-prueba-b', 6);
    m1 := pg_temp.c10_cargo('c10-t20-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9201');
    m2 := pg_temp.c10_cargo('c10-t20-1b', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9201');
    m3 := pg_temp.c10_cargo('c10-t20-3', pg_temp.c10_d(), 144.00, 'Zelle payment to C10 PRUEBA ZZBETO 9203');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%falta decir si es el mismo%' then 'posible duplicado, no deja'
                                else 'mal: ' || coalesce(v_j->>'por_que', 'deja') end, pg_temp.c10_avisos(v_j));
    b := case when (pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end;
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_duplicado(m2, false, 'c10-pruebas: son dos pagos distintos (se deshace)');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := format('%s [%s]', case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja: ' || (v_j->>'por_que') end, pg_temp.c10_avisos(v_j));
    -- el devengo estándar del mes de esas horas (aprobadas antes, como pide c3)
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p2')::uuid, v_dia, v_dia, '{"ids": [-1010000002]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := fn_horas_devengar(v_mes);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is null then
      v_j := pg_temp.c10_propuesta(m3, v_dia, v_dia);
      d := format('%s [%s]', case when pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%' || v_mes || ' (asiento ' || (v_dev->>'asiento') || ')%'
                                       and pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%saldría dos veces%' then 'avisa, con el mes y su asiento' else 'no lo dice bien' end,
                  pg_temp.c10_avisos(v_j));
      v_obt := format('el parecido: %s | el primero: %s | dicho «no es el mismo»: %s | con el devengo estándar de ese mes: %s', a, b, c, d);
    else
      v_obt := format('omitida: c3 no dejó devengar %s (%s); lo demás: el parecido: %s | el primero: %s | dicho «no es el mismo»: %s', v_mes, left(v_no, 300), a, b, c);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'los avisos: un posible duplicado sin decidir no deja aplicar hasta que Edgar diga si es el mismo; y un mes con devengo estándar de horas (c3) avisa de que la mano de obra saldría dos veces, con el mes y su asiento',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 21. La IA (c8) sigue proponiendo para estos pagos: si el movimiento tiene
--     una propuesta suya pendiente, la propuesta, la vista y aplicar la
--     devuelven (la pantalla la rechaza por la función de borde); c8 no la
--     cierra sola, y ninguno de sus cuadres se pone en rojo.
do $$
declare
  v_obt text; v_mov uuid; v_p uuid; v_j jsonb; v_r jsonb; v_antes text[]; v_ahora text[]; a text; b text; c text; d text;
  v_esp text := 'la propuesta la trae | la vista de pendientes también | aplicar la devuelve | c8 la deja pendiente (la rechaza la pantalla) | '
                'cuadres de c8 que pasan a rojo: ninguno';
begin
  if pg_temp.c10('hay_c8') <> 'true' then
    insert into _pruebas values (21, 'la propuesta pendiente de la IA (c8) de un pago se devuelve y nada de c8 se rompe', v_esp,
                                 'omitida: c8 no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(21, 'la propuesta pendiente de la IA (c8)', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t21', pg_temp.c10_d(), 210.00, 'Zelle payment to C10 PRUEBA ZZANA 9021');
    perform pg_temp.c10_alta('p1');
    -- (una propuesta pendiente de c8 para ese movimiento, como la deja su rutina)
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {"pide_obra": true}}'::jsonb)
                returning id $q$ into v_p using v_mov;
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_antes;
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := case when (v_j->>'propuesta_ia')::uuid = v_p then 'la trae' else 'no la trae' end;
    perform pg_temp.c10_ser('dueno');
    -- (la vista va por la semana de la regla; la propuesta de la IA sale igual)
    b := case when (select p.propuesta_ia from v_jornal_pendientes p where p.movimiento_id = v_mov) = v_p then 'también' else 'no' end;
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := case when (v_r->>'propuesta_ia')::uuid = v_p then 'la devuelve' else 'no la devuelve' end;
    execute $q$ select p.estado from public.contador_propuestas p where p.id = $1 $q$ into d using v_p;
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_ahora;
    v_obt := format('la propuesta %s | la vista de pendientes %s | aplicar %s | c8 la deja %s (la rechaza la pantalla) | cuadres de c8 que '
                    'pasan a rojo: %s', a, b, c, d, pg_temp.c10_nuevos(v_antes, v_ahora));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'la IA (c8) sigue proponiendo para estos pagos: su propuesta pendiente sale en la propuesta, en la vista de pendientes y en lo que devuelve aplicar (para que la pantalla la rechace); c8 no la cierra sola y ninguno de sus cuadres pasa a rojo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- APLICAR («Así es»: fn_jornal_aplicar)
-- ---------------------------------------------------------------------
-- 22. El asiento: por el camino del banco (c6), la línea del banco y una
--     por obra y CO a la cuenta del jornal, cada una con su obra, su CO y la
--     persona (tercero empleado); el movimiento queda casado con él; y el
--     reparto, sus partes y su detalle por reporte quedan guardados.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_as asientos; v_rep jornal_repartos; v_m movimientos_banco; v_j jsonb;
  a text; b text; c text; d text; e text; f text;
  v_esp text := 'el asiento: puente / movimientos_banco, el día del pago, a nombre del dueño, «Clasificado por Edgar: Zelle…» | 1 1010 '
                '-500.00 | 2 5200 200.00 a empleado:p1 | 3 5200 162.50 a/CO #1 empleado:p1 | 4 5200 37.50 b empleado:p1 | 5 5200 100.00 e '
                'empleado:p1 | cada línea dice de quién y de qué semana | el movimiento: casado (clasificado) con ese asiento | el reparto: '
                'aplicado, 500.00, 20 h, 25.00 la hora (la suya 25), semana_anterior, 5200, con la huella de la propuesta, por el dueño | 4 '
                'partes (líneas 2 a 5 del asiento) y 4 reportes que suman 500.00 | lo que devuelve: el reparto, el asiento y 4 líneas | '
                'control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(22, 'aplicar: el asiento, el reparto y su detalle', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6.5, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 1.5, null, 'trim');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-e', 4);
    v_mov := pg_temp.c10_cargo('c10-t22', pg_temp.c10_d(), 500.00, 'Zelle payment to C10 PRUEBA ZZANA 9022');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select * into v_rep from jornal_repartos where id = (v_r->>'reparto_id')::uuid;
    select * into v_as from asientos where id = v_rep.asiento_id;
    select * into v_m from movimientos_banco where id = v_mov;
    a := format('%s / %s, %s, %s, %s', v_as.camino, v_as.origen_tabla,
                case when v_as.fecha_contable = pg_temp.c10_d() then 'el día del pago' else v_as.fecha_contable::text end,
                case when v_as.usuario_id::text = pg_temp.c10('dueno') then 'a nombre del dueño' else 'a nombre de otro' end,
                case when v_as.descripcion like 'Clasificado por Edgar: Zelle payment to C10 PRUEBA ZZANA%' then '«Clasificado por Edgar: Zelle…»' else v_as.descripcion end);
    b := pg_temp.c10_asiento(v_as.id);
    c := case when (select bool_and(l.memo like 'Jornal de Zzana C10 PRUEBA · ' || fn_jornal_dia(pg_temp.c10_w1(0)) || ' a ' || fn_jornal_dia(pg_temp.c10_w1(6), true) || ' · % h de 20 h')
                      from asiento_lineas l where l.asiento_id = v_as.id and l.orden > 1)
              then 'cada línea dice de quién y de qué semana' else 'las notas de las líneas no lo dicen' end;
    d := format('%s (%s) %s', v_m.estado, v_m.casado_clase, case when v_m.asiento_id = v_as.id then 'con ese asiento' else 'con OTRO asiento' end);
    e := format('%s, %s, %s h, %s la hora (la suya %s), %s, %s, %s, %s', v_rep.estado, v_rep.monto, trim_scale(v_rep.horas), v_rep.tarifa_sale,
                trim_scale(v_rep.tarifa_equipo), v_rep.regla_periodo, v_rep.cuenta,
                case when v_rep.huella = v_j->>'visto' then 'con la huella de la propuesta' else 'con OTRA huella' end,
                case when v_rep.creado_por::text = pg_temp.c10('dueno') then 'por el dueño' else 'por otro' end);
    f := format('%s partes (líneas %s a %s del asiento) y %s reportes que suman %s',
                (select count(*) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select min(l.orden) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select max(l.orden) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select count(*) from jornal_reparto_horas h where h.reparto_id = v_rep.id),
                (select sum(h.monto) from jornal_reparto_horas h where h.reparto_id = v_rep.id));
    v_obt := format('el asiento: %s | %s | %s | el movimiento: %s | el reparto: %s | %s | lo que devuelve: %s | %s', a, b, c, d, e, f,
                    case when v_r->>'estado' = 'aplicado' and v_r->'asiento'->>'numero' = v_as.numero and jsonb_array_length(v_r->'lineas') = 4
                              and v_r->>'nota' like 'Repartido: $500.00 de Zzana C10 PRUEBA%entre 3 obra(s); asiento ' || v_as.numero || '%Quedaron aprobados 4 reporte(s)%'
                         then 'el reparto, el asiento y 4 líneas' else v_r::text end,
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'APLICAR: el asiento entra por el camino del banco (c6), con la línea del banco y una por obra y CO a 5200, cada una con su obra, su CO y la persona como tercero; el movimiento queda casado con él; el reparto, sus partes (con la línea de su asiento) y su detalle por reporte quedan guardados; los controles, en verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. «Así es» aprueba las horas que Edgar vio, por el camino de c3
--     (fn_horas_aprobar, con sus ids): quedan aprobadas por el dueño y en
--     horas_aprobaciones con lo que vio. Las que ya estaban aprobadas no se
--     tocan; y otro pago de las mismas horas no tiene nada que aprobar.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_r2 jsonb; a text; b text; c text; d text;
  v_esp text := 'antes: 1 de 3 aprobadas | aplicar aprobó las 2 que faltaban: por el dueño, por fn_horas_aprobar, con lo que vio | después: 3 de '
                '3 | el reparto dice cuáles aprobó: 2 | otro pago de las mismas horas: nada que aprobar, y entra';
begin
  if pg_temp.c10_omitir(23, 'aplicar aprueba las horas por c3', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    m1 := pg_temp.c10_cargo('c10-t23-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9231');
    m2 := pg_temp.c10_cargo('c10-t23-2', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9232');
    perform pg_temp.c10_alta('p1');
    -- (el lunes ya lo había aprobado Edgar en Horas)
    perform pg_temp.c10_ser('dueno');
    perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(0), '{"ids": [-1010000001]}'::jsonb);
    perform pg_temp.c10_ser('editor');
    select format('%s de %s aprobadas', count(*) filter (where h.aprobado_el is not null), count(*)) into a
      from horas h where h.usuario_id = pg_temp.c10('p1')::uuid;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s: %s, %s, %s',
                  case when v_r->'horas_aprobadas'->>'reportes' = '2' and v_r->'horas_aprobadas'->'ids' = '[-1010000003, -1010000002]'::jsonb
                       then 'aplicar aprobó las 2 que faltaban' else 'aplicar dice ' || (v_r->'horas_aprobadas')::text end,
                  case when bool_and(h.aprobado_por::text = pg_temp.c10('dueno')) then 'por el dueño' else 'por otro' end,
                  case when (select count(*) from horas_aprobaciones ap
                              where ap.horas_id in (-1010000002, -1010000003) and ap.accion = 'aprobada'
                                and ap.hecho_por::text = pg_temp.c10('dueno')) = 2 then 'por fn_horas_aprobar' else 'sin su rastro' end,
                  case when (select bool_and(ap.detalle->'visto'->'ids' = '[-1010000003, -1010000002]'::jsonb) from horas_aprobaciones ap
                              where ap.horas_id in (-1010000002, -1010000003) and ap.accion = 'aprobada') then 'con lo que vio' else 'sin lo que vio' end)
      into b
      from horas h where h.id in (-1010000002, -1010000003);
    select format('%s de %s', count(*) filter (where h.aprobado_el is not null), count(*)) into c
      from horas h where h.usuario_id = pg_temp.c10('p1')::uuid;
    v_r2 := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    d := case when v_r2->'horas_aprobadas'->>'reportes' = '0' and v_r2->>'estado' = 'aplicado' and (v_r2->>'horas')::numeric = 16
              then 'nada que aprobar, y entra' else v_r2::text end;
    v_obt := format('antes: %s | %s | después: %s | el reparto dice cuáles aprobó: %s | otro pago de las mismas horas: %s', a, b, c,
                    (select jsonb_array_length(r.horas_aprobadas) from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid), d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'aplicar aprueba por el camino de c3 (fn_horas_aprobar, con los ids que Edgar vio) las horas de esas fechas que estaban sin aprobar: quedan por el dueño y en horas_aprobaciones; el reparto guarda cuáles aprobó; otro pago de las mismas horas no aprueba nada',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. LA HUELLA: si entre que Edgar miró y que tocó «Así es» cambian las
--     horas (un reporte nuevo, otras horas, otra obra, uno borrado) o una
--     cuenta, o la huella no es la de la propuesta: MX011, y NADA cambia (ni
--     una hora aprobada, ni un asiento, ni un reparto; el pago sigue en la
--     Bandeja). Con la propuesta de ahora, entra.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_antes text; v_visto text; v_sin text;
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'un reporte nuevo MX011 | otras horas MX011 | otra obra MX011 | un reporte borrado MX011 | otra cuenta MX011 | una huella '
                'inventada MX011 | y nada cambió: sí | lo dice en llano y pide volver a mirar: sí | con la propuesta de ahora: entra';
begin
  if pg_temp.c10_omitir(24, 'la huella cambiada: MX011 y nada cambia', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), null, 1);
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_mov := pg_temp.c10_cargo('c10-t24', pg_temp.c10_d(), 325.00, 'Zelle payment to C10 PRUEBA ZZANA 9024');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    -- lo que Edgar ve
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_visto := v_j->>'visto';
    select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                  (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                  (select count(*) from horas_aprobaciones), (select m.estado from movimientos_banco m where m.id = v_mov)) into v_antes;
    -- …y lo que pasa antes de que toque
    begin
      perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-h', 2);
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      a := 'entró';
    exception when others then a := sqlstate; g := sqlerrm;
    end;
    begin
      perform pg_temp.c10_corregir(1, 'horas = 7');
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      b := 'entró';
    exception when others then b := sqlstate;
    end;
    begin
      perform pg_temp.c10_corregir(2, $s$proyecto_id = 'c10-prueba-h'$s$);
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      c := 'entró';
    exception when others then c := sqlstate;
    end;
    begin
      delete from horas where id = -1010000002;
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      d := 'entró';
    exception when others then d := sqlstate;
    end;
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', (select c2.codigo from cuentas c2
                                 where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null and c2.codigo <> v_sin order by c2.codigo limit 1)));
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      e := 'entró';
    exception when others then e := sqlstate;
    end;
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 'c10c10c10c10c10c10c10c10c10c10c1');
      f := 'entró';
    exception when others then f := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('un reporte nuevo %s | otras horas %s | otra obra %s | un reporte borrado %s | otra cuenta %s | una huella inventada %s | y '
                    'nada cambió: %s | lo dice en llano y pide volver a mirar: %s', a, b, c, d, e, f,
                    case when (select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                                             (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                                             (select count(*) from horas_aprobaciones), (select m.estado from movimientos_banco m where m.id = v_mov))) = v_antes
                         then 'sí' else 'NO' end,
                    case when g like 'Las horas de Zzana C10 PRUEBA % ya no son las que viste%no se aprobó ni se posteó nada. Vuelve a mirar%' then 'sí' else 'no: ' || coalesce(g, '-') end);
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_obt := v_obt || ' | con la propuesta de ahora: ' || case when v_r->>'estado' = 'aplicado' then 'entra' else 'no' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'LA HUELLA: si las horas ya no son las que Edgar vio (un reporte nuevo, otras horas, otra obra, uno borrado), o cambió una cuenta, o la huella no es la de la propuesta, aplicar da MX011 —un código nuevo— y NADA cambia; con la propuesta de ahora, entra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. Dos veces: la segunda falla limpia (MX008: ya está repartido) y no
--     queda nada a medias. Y los frenos de entrada (22023) y de fondo (MX008).
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'la segunda MX008 (ya está repartido) y sigue habiendo 1 reparto y 1 asiento suyo | sin huella 22023 | sin fechas 22023 | al '
                'revés 22023 | 63 días 22023 | una opción desconocida 22023 | el pago de alguien sin dar de alta MX008 | sin horas MX008';
begin
  if pg_temp.c10_omitir(25, 'aplicar dos veces, y sus frenos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t25-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9251');
    m2 := pg_temp.c10_cargo('c10-t25-2', pg_temp.c10_d(), 210.00, 'Zelle payment to C10 PRUEBA ZZBETO 9252');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), ''); b := 'entró'; exception when others then b := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, null, null, v_j->>'visto'); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(6), pg_temp.c10_w1(0), v_j->>'visto'); d := 'entró'; exception when others then d := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(6) - 62, pg_temp.c10_w1(6), v_j->>'visto'); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto', '{"incluir_cubierta": true}'); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform fn_jornal_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto'); g := 'entró'; exception when others then g := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6), v_j->>'visto'); h := 'entró'; exception when others then h := sqlstate; end;
    -- la buena, y otra vez con la misma huella (dos toques, o dos pantallas)
    v_r := fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
    begin
      perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
      a := 'entró';
    exception when others then a := sqlstate || case when sqlerrm like 'Este pago ya está repartido%' then ' (ya está repartido)' else ' (' || sqlerrm || ')' end;
    end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('la segunda %s y sigue habiendo %s reparto y %s asiento suyo | sin huella %s | sin fechas %s | al revés %s | 63 días %s | una '
                    'opción desconocida %s | el pago de alguien sin dar de alta %s | sin horas %s', a,
                    (select count(*) from jornal_repartos r where r.movimiento_id = m1),
                    (select count(*) from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = m1::text), b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'aplicar dos veces: la segunda falla limpia (MX008: ya está repartido) y queda un solo reparto y un solo asiento; sin huella, sin fechas, al revés, de más de 62 días o con una opción desconocida, 22023; el pago de alguien sin dar de alta o sin horas, MX008',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. Una semana toca más de 5 obras (las 5 líneas son el tope de las
--     propuestas de la IA, c8; este camino no pasa por ahí): 7 obras en un
--     asiento, y 12.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_r2 jsonb; i int; a text; b text;
  v_esp text := '7 obras: 8 líneas, las 7 a 5200 suman 940.00 en 7 obras distintas, todas con la persona | 12 obras: 13 líneas, las 12 suman '
                '1000.00 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(26, 'más de 5 obras en un asiento', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    for i in 1..7 loop
      perform pg_temp.c10_hora(i, 'p1', pg_temp.c10_w1(i - 1), 'c10-prueba-' || (array['a', 'b', 'e', 'f', 'h', 'i', 'j'])[i],
                               (array[8, 7.5, 6.25, 5, 3.25, 2, 0.5])[i]);
    end loop;
    for i in 1..12 loop
      perform pg_temp.c10_hora(20 + i, 'p2', pg_temp.c10_w1((i - 1) % 7), 'c10-prueba-' || chr(96 + i), 1);
    end loop;
    m1 := pg_temp.c10_cargo('c10-t26-1', pg_temp.c10_d(), 940.00, 'Zelle payment to C10 PRUEBA ZZANA 9261');
    m2 := pg_temp.c10_cargo('c10-t26-2', pg_temp.c10_d(), 1000.00, 'Zelle payment to C10 PRUEBA ZZBETO 9262');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_r2 := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s líneas, las %s a 5200 suman %s en %s obras distintas, %s', count(*), count(*) filter (where l.cuenta = '5200'),
                  sum(l.monto) filter (where l.cuenta = '5200'), count(distinct l.proyecto_id),
                  case when bool_and(l.tercero_id = pg_temp.c10('p1')) filter (where l.cuenta = '5200') then 'todas con la persona' else 'alguna sin la persona' end)
      into a from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid;
    select format('%s líneas, las %s suman %s', count(*), count(*) filter (where l.cuenta = '5200'), sum(l.monto) filter (where l.cuenta = '5200'))
      into b from asiento_lineas l where l.asiento_id = (v_r2->'asiento'->>'id')::uuid;
    v_obt := format('7 obras: %s | 12 obras: %s | %s', a, b, pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'una semana con más de 5 obras entra en UN asiento (c6 no limita las líneas; las 5 son de las propuestas de c8, por las que este camino no pasa): 7 obras, y 12',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. Un pago de un mes YA CERRADO: lo que dicen c6 y c2 con todo lo que el
--     banco trae tarde: el asiento entra el primer día del mes abierto, con
--     su nota; la propuesta lo avisa antes, y el reparto va igual por las
--     horas de sus fechas. (Cierra la apertura y el mes abierto más viejo que
--     ya terminó dentro de la prueba, como c2-pruebas; si el libro real no
--     deja cerrar, sale «omitida» con lo que dijo c2.)
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_mes periodos; v_ap periodos; v_abre date; v_no text; a text; b text; c text;
  v_esp text := 'la propuesta lo avisa (mes_cerrado, con la fecha en que entrará) y deja | el asiento entra el primer día del mes abierto, con '
                'su nota de tardío | el reparto, por las horas de sus fechas: a 8→200.00 | control del jornal: nada nuevo en rojo; del margen: '
                'nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(27, 'un pago de un mes ya cerrado', v_esp) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    lock table periodos in exclusive mode;
    select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
    if v_mes.periodo is null then
      -- no queda un mes terminado por cerrar: vale el último que ya esté cerrado
      select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'cerrado' order by p.desde desc limit 1;
      if v_mes.periodo is null then
        v_no := 'no hay un mes terminado (ni abierto ni cerrado) donde poner el pago';
      end if;
    else
      begin
        select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
        if v_ap.estado = 'abierto' then
          if not exists (select 1 from asientos x where x.periodo = v_ap.periodo and x.tipo = 'apertura' and x.reversa_a is null
                            and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
            perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
              'descripcion', 'C10 PRUEBA: apertura de prueba (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
          end if;
          perform fn_cerrar_periodo(v_ap.periodo);
        end if;
        perform fn_cerrar_periodo(v_mes.periodo);
      exception when others then
        v_no := format('c2 no dejó cerrar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null then
      select min(p.desde) into v_abre from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > v_mes.hasta;
      perform pg_temp.c10_sembrar();
      -- (la semana del lunes anterior al último día del mes cerrado; el pago, ese último día)
      perform pg_temp.c10_hora(1, 'p1', v_mes.hasta - 9, 'c10-prueba-a', 8);
      v_mov := pg_temp.c10_cargo('c10-t27', v_mes.hasta, 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9027');
      perform pg_temp.c10_alta('p1');
      v_j := pg_temp.c10_propuesta(v_mov, v_mes.hasta - 13, v_mes.hasta - 7);
      a := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'mes_cerrado') like '%ese mes ya está cerrado: el asiento entrará con fecha ' || fn_jornal_dia(v_abre, true) || '%'
                                       and (v_j->'movimiento'->>'mes_cerrado')::boolean then 'la propuesta lo avisa (mes_cerrado, con la fecha en que entrará)'
                                  else 'la propuesta no lo avisa bien: ' || pg_temp.c10_avisos(v_j) end,
                  case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja: ' || (v_j->>'por_que') end);
      v_r := pg_temp.c10_aplicar(v_mov, v_mes.hasta - 13, v_mes.hasta - 7);
      b := case when (v_r->'asiento'->>'fecha_contable')::date = v_abre and v_r->>'tardio' like 'Documento tardío del ' || v_mes.hasta || '%'
                     and (select x.procedencia ? 'tardio' from asientos x where x.id = (v_r->'asiento'->>'id')::uuid)
                then 'el asiento entra el primer día del mes abierto, con su nota de tardío'
                else format('el asiento entra el %s (se esperaba el %s), tardío: %s', v_r->'asiento'->>'fecha_contable', v_abre, coalesce(v_r->>'tardio', 'no lo dice')) end;
      c := pg_temp.c10_lineas(v_r);
      v_obt := format('%s | %s | el reparto, por las horas de sus fechas: %s | %s', a, b, c, pg_temp.c10_propios());
    else
      v_obt := 'omitida: ' || v_no;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'un pago de un mes YA CERRADO entra como c6 y c2 meten todo lo que llega tarde: el primer día del mes abierto, con su nota; la propuesta lo avisa antes (con la fecha) y el reparto va por las horas de sus fechas',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 28. La obra terminada y la cancelada reciben su parte: ni c2 ni c6 piden
--     que la obra esté activa (eso es de las propuestas de la IA); el
--     trabajo se hizo ahí, y el costo queda en esa obra.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb;
  v_esp text := 'c 4→100.00, d 4→100.00 [obra_terminada] | 1 1010 -200.00 | 2 5200 100.00 c empleado:p1 | 3 5200 100.00 d empleado:p1 | el '
                'costo queda en la terminada: 100.00, y en la no aprobada: 100.00';
begin
  if pg_temp.c10_omitir(28, 'la obra terminada y la cancelada reciben su parte', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-c', 4);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-d', 4);
    v_mov := pg_temp.c10_cargo('c10-t28', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9028');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    v_obt := format('%s [%s] | %s | el costo queda en la terminada: %s, y en la no aprobada: %s', pg_temp.c10_lineas(v_r), pg_temp.c10_avisos(v_r),
                    pg_temp.c10_asiento((v_r->'asiento'->>'id')::uuid),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-c' and o.estado = 'completado'),
                    (select o.costo_real from v_margen_obra o where o.proyecto_id = 'c10-prueba-d' and o.estado = 'no_aprobado'));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'la obra terminada y la no aprobada reciben su parte (ni c2 ni c6 piden que la obra esté activa: el trabajo se hizo ahí): entra con su aviso y el costo queda en esa obra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. Las horas sin obra: sin la cuenta fijada no se aplica (MX008, y nada
--     cambia); con ella, su parte va a esa cuenta, sin obra y con la
--     persona, y el reparto lo guarda.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_sin text; a text; v_antes int;
  v_esp text;
begin
  if pg_temp.c10_omitir(29, 'las horas sin obra', 'sin la cuenta no se aplica; con ella, a su cuenta') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('sin la cuenta: MX008 (dice que la fije) y nada cambia | con ella: 1 1010 -200.00 | 2 5200 150.00 a empleado:p1 | 3 %s '
                    '50.00 empleado:p1 | el reparto la guarda (%s; la parte sin obra es la línea 3) | control del jornal: nada nuevo en '
                    'rojo; del margen: nada nuevo en rojo', v_sin, v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 6);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), null, 2);
    v_mov := pg_temp.c10_cargo('c10-t29', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9029');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"cuenta_sin_obra": null}');
    perform pg_temp.c10_ser('editor');
    select count(*) into v_antes from asientos;
    begin
      perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      a := 'entró';
    exception when others then
      a := sqlstate || case when sqlerrm like '%no tienen obra%Di una vez a qué cuenta va la mano de obra sin obra%' then ' (dice que la fije)' else ' (' || sqlerrm || ')' end;
    end;
    a := a || case when (select count(*) from asientos) = v_antes and (select m.estado from movimientos_banco m where m.id = v_mov) = 'pendiente'
                        and not exists (select 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null)
                   then ' y nada cambia' else ' y ALGO cambió' end;
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_obt := format('sin la cuenta: %s | con ella: %s | el reparto la guarda (%s; la parte sin obra es la línea %s) | %s', a,
                    pg_temp.c10_asiento((v_r->'asiento'->>'id')::uuid),
                    (select r.cuenta_sin_obra from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid),
                    (select l.orden from jornal_reparto_lineas l where l.reparto_id = (v_r->>'reparto_id')::uuid and l.proyecto_id is null),
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'las horas sin obra no pueden ir a 5200 (exige obra): sin la cuenta fijada no se aplica (MX008, nada cambia); con ella, su parte va a esa cuenta, sin obra y con la persona, y el reparto la guarda',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 30. Los frenos del banco VALEN: fn_jornal_aplicar llama a c6 sin motivo, y
--     lo que c6 no deja pasar sin el motivo escrito de Edgar tampoco pasa
--     aquí. Un débito que c6 toma por nómina (su descripción dice PAYROLL):
--     MX008 con el mensaje de c6, y nada cambia; con el motivo de Edgar
--     (p_opciones.motivo), entra, y el asiento lo lleva.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; a text; b text; v_antes int;
  v_esp text := 'c6 lo toma por nómina; la propuesta lo reconoce y deja | sin motivo: MX008, con el mensaje de c6 («dilo en el motivo»), y nada '
                'cambia | con el motivo de Edgar: entra, el asiento lo lleva y el reparto lo guarda';
begin
  if pg_temp.c10_omitir(30, 'los frenos del banco valen', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t30', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA PAYROLL 9030');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s; %s', case when (select m.estado_motivo from movimientos_banco m where m.id = v_mov) = 'nomina' then 'c6 lo toma por nómina'
                               else 'c6 dice ' || coalesce((select m.estado_motivo from movimientos_banco m where m.id = v_mov), '-') end,
                case when (v_j->>'reconocido')::boolean and (v_j->>'puede_aplicar')::boolean then 'la propuesta lo reconoce y deja' else 'la propuesta no' end);
    select count(*) into v_antes from asientos;
    begin
      perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      b := 'entró';
    exception when others then
      b := sqlstate || case when sqlerrm like 'Es un débito de nómina%dilo en el motivo%' then ', con el mensaje de c6 («dilo en el motivo»)' else ' (' || sqlerrm || ')' end;
    end;
    b := b || case when (select count(*) from asientos) = v_antes and (select m.estado from movimientos_banco m where m.id = v_mov) = 'pendiente'
                        and not exists (select 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null)
                        and not exists (select 1 from jornal_repartos r where r.movimiento_id = v_mov)
                   then ', y nada cambia' else ', y ALGO cambió' end;
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"motivo": "c10-pruebas: es su jornal de la semana, no la nómina"}');
    v_obt := format('%s | sin motivo: %s | con el motivo de Edgar: %s', a, b,
                    case when v_r->>'estado' = 'aplicado'
                              and (select x.descripcion from asientos x where x.id = (v_r->'asiento'->>'id')::uuid) like 'c10-pruebas: es su jornal de la semana, no la nómina: Zelle%'
                              and (select r.opciones->>'motivo' from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'c10-pruebas: es su jornal de la semana, no la nómina'
                         then 'entra, el asiento lo lleva y el reparto lo guarda' else v_r::text end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'los frenos del banco valen: lo que c6 no deja clasificar sin el motivo escrito de Edgar (aquí, un débito que toma por nómina) tampoco pasa por el jornal: MX008 con el mensaje de c6 y nada cambia; con el motivo en p_opciones.motivo, entra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- DESHACER (fn_jornal_deshacer) Y LO QUE LA PANTALLA PINTA
-- ---------------------------------------------------------------------
-- 31. Deshacer va por el camino del banco (fn_banco_descasar): el asiento
--     NO se borra, se reversa; el movimiento vuelve a la Bandeja; el reparto
--     queda marcado con quién, por qué y su reverso; la aprobación de las
--     horas SE QUEDA; y el pago vuelve a salir entre los pendientes. Dos
--     veces no; sin motivo, tampoco.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_d jsonb; v_rep jornal_repartos; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'el asiento sigue en el libro y su reverso lo anula (5200 de las dos obras, en 0.00), con el motivo | el movimiento vuelve a la '
                'Bandeja (pendiente, sin asiento) | el reparto queda marcado: deshecho, por el dueño, con su motivo y su reverso | las 2 horas '
                'siguen aprobadas | el pago vuelve a salir entre los pendientes, con sus 12 h | otra vez MX008 | sin motivo 22023 | un reparto '
                'que no existe 22023 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(31, 'deshacer un reparto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (las horas, en la semana que la regla da para el día del pago: así el pago vuelve a salir con ellas)
    perform pg_temp.c10_hora(1, 'p1', (select p.desde from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', (select p.desde + 1 from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-b', 4);
    v_mov := pg_temp.c10_cargo('c10-t31', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9031');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, (select p.desde from fn_jornal_periodo(pg_temp.c10_d()) p), (select p.hasta from fn_jornal_periodo(pg_temp.c10_d()) p));
    v_d := pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: era de otra semana');
    select * into v_rep from jornal_repartos where id = (v_r->>'reparto_id')::uuid;
    a := format('%s (5200 de las dos obras, en %s), %s',
                case when exists (select 1 from asientos x where x.id = v_rep.asiento_id)
                          and (select x.camino = 'reverso' and x.reversa_a = v_rep.asiento_id from asientos x where x.id = v_rep.reverso_id)
                     then 'el asiento sigue en el libro y su reverso lo anula' else 'el asiento o su reverso no están como deben' end,
                (select sum(l.monto) from asiento_lineas l where l.cuenta = '5200' and l.proyecto_id in ('c10-prueba-a', 'c10-prueba-b')),
                case when (select x.motivo from asientos x where x.id = v_rep.reverso_id) like '%c10-pruebas: era de otra semana%' then 'con el motivo' else 'sin el motivo' end);
    select format('%s, %s', m.estado, case when m.asiento_id is null then 'sin asiento' else 'CON asiento' end) into b from movimientos_banco m where m.id = v_mov;
    c := format('%s, %s, %s', v_rep.estado, case when v_rep.deshecho_por::text = pg_temp.c10('dueno') and v_rep.deshecho_el is not null then 'por el dueño' else 'por otro' end,
                case when v_rep.deshecho_motivo = 'c10-pruebas: era de otra semana' and v_rep.reverso_id = (v_d->'reverso'->>'id')::uuid
                          and v_d->>'estado' = 'deshecho' and not (v_d->>'por_fuera')::boolean and v_d->>'movimiento_estado' = 'pendiente'
                     then 'con su motivo y su reverso' else 'mal: ' || v_d::text end);
    select format('las %s horas siguen aprobadas', count(*)) into d from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null;
    perform pg_temp.c10_ser('dueno');
    select format('con sus %s h', trim_scale(p.horas)) into e from v_jornal_pendientes p where p.movimiento_id = v_mov;
    perform pg_temp.c10_ser('editor');
    begin perform pg_temp.c10_deshacer(v_rep.id, 'otra vez, por si acaso'); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform pg_temp.c10_deshacer(v_rep.id, ' x '); g := 'entró'; exception when others then g := sqlstate; end;
    begin perform pg_temp.c10_deshacer('00000000-0000-4000-a000-0000000c10fd', 'no existe'); h := 'entró'; exception when others then h := sqlstate; end;
    v_obt := format('%s | el movimiento vuelve a la Bandeja (%s) | el reparto queda marcado: %s | %s | el pago vuelve a salir entre los '
                    'pendientes, %s | otra vez %s | sin motivo %s | un reparto que no existe %s | %s', a, b, c, d, coalesce(e, 'NO sale'), f, g, h,
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'DESHACER va por el camino del banco: el asiento se reversa (no se borra), el movimiento vuelve a la Bandeja, el reparto queda marcado (quién, por qué, su reverso) y no se borra, la aprobación de las horas se queda, y el pago vuelve a salir entre los pendientes; dos veces MX008, sin motivo 22023',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. Volver a aplicar con otras fechas: deshecho el primero, el mismo pago
--     se reparte por otra semana; quedan los dos repartos (uno deshecho, uno
--     aplicado) y el costo, en la obra buena.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_r2 jsonb;
  v_esp text := 'primero a 8→260.00 (semana_anterior); deshecho; después b 5→260.00 (a_mano) | del mismo pago: 2 repartos (1 aplicado, 1 '
                'deshecho) y 3 asientos (el primero, su reverso y el nuevo) | el costo: en la a 0.00, en la b 260.00 | las horas de las dos '
                'semanas, aprobadas: 2 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(32, 'volver a aplicar con otras fechas', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 5);
    v_mov := pg_temp.c10_cargo('c10-t32', pg_temp.c10_d(), 260.00, 'Zelle payment to C10 PRUEBA ZZANA 9032');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: no era esa semana, era la de antes');
    v_r2 := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    perform pg_temp.c10_ser('dueno');
    v_obt := format('primero %s (%s); deshecho; después %s (%s) | del mismo pago: %s repartos (%s aplicado, %s deshecho) y %s asientos (el primero, '
                    'su reverso y el nuevo) | el costo: en la a %s, en la b %s | las horas de las dos semanas, aprobadas: %s | %s',
                    pg_temp.c10_lineas(v_r), v_r->>'regla_periodo', pg_temp.c10_lineas(v_r2), v_r2->>'regla_periodo',
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov),
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov and r.estado = 'aplicado' and r.asiento_vivo),
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov and r.estado = 'deshecho' and not r.asiento_vivo and r.reverso is not null),
                    (select count(*) from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = v_mov::text),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-a'),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-b'),
                    (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                    pg_temp.c10_propios());
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'volver a aplicar con otras fechas: deshecho el primer reparto, el mismo pago se reparte por otra semana (un asiento nuevo); quedan los dos repartos como rastro y el costo, solo en la obra buena',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. Des-casado POR FUERA (Edgar lo suelta en la Bandeja, sin pasar por el
--     jornal): c6 reversa el asiento y el reparto queda «aplicado» sin
--     asiento vivo. El control lo ve (20, en rojo, con qué hacer), la
--     propuesta lo dice y no deja repartir encima, y fn_jornal_deshacer lo
--     cierra sin tocar el libro otra vez.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; v_d jsonb; a text; b text; c text; d text; e text; v_n int;
  v_esp text := 'des-casado en la Bandeja: el control 20 en rojo, y dice qué hacer; el margen, nada nuevo en rojo | la propuesta: no deja '
                '[reparto_suelto] y trae el reparto | aplicar MX008 | deshacer lo cierra (por fuera) sin otro asiento | el control vuelve a '
                'verde y el pago se puede repartir';
begin
  if pg_temp.c10_omitir(33, 'des-casado por fuera', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(33, 'des-casado por fuera', v_esp, 'jornal', array[20]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t33', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9033');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(v_mov, 'c10-pruebas: lo suelto en la Bandeja (se deshace)');
    perform pg_temp.c10_ser('editor');
    a := format('%s; el margen, %s',
                case when pg_temp.c10_jc(20) like 'rojo: %se reversó por fuera%→ toca «Deshacer» en ese reparto (en Repartos), con su motivo%'
                          and pg_temp.c10_jc(20) !~ 'fn_|v_jornal|v_margen' then 'el control 20 en rojo, y dice qué hacer'
                     else 'el control 20: ' || pg_temp.c10_jc(20) end,
                split_part(split_part(pg_temp.c10_propios(), 'del margen: ', 2), ' en rojo', 1) || ' en rojo');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s [%s] y %s', case when (v_j->>'puede_aplicar')::boolean then 'DEJA' else 'no deja' end,
                (select string_agg(x->>'codigo', ',') from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'reparto_suelto'),
                case when (select x->>'reparto_id' from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'reparto_suelto') = v_r->>'reparto_id'
                     then 'trae el reparto' else 'no trae el reparto' end);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
      c := 'entró';
    exception when others then c := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    select count(*) into v_n from asientos;
    v_d := pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: se había des-casado en la Bandeja');
    d := format('%s %s', case when (v_d->>'por_fuera')::boolean and v_d->>'estado' = 'deshecho' and v_d->'reverso'->>'numero' is not null then 'lo cierra (por fuera)' else 'no: ' || v_d::text end,
                case when (select count(*) from asientos) = v_n then 'sin otro asiento' else 'con OTRO asiento' end);
    e := format('%s y %s', case when pg_temp.c10_jc(20) = 'verde' then 'el control vuelve a verde' else pg_temp.c10_jc(20) end,
                case when (pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'puede_aplicar')::boolean then 'el pago se puede repartir' else 'el pago sigue sin poder repartirse' end);
    v_obt := format('des-casado en la Bandeja: %s | la propuesta: %s | aplicar %s | deshacer %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'des-casado por fuera (en la Bandeja, sin pasar por el jornal): el control 20 lo pone en rojo con qué hacer, la propuesta lo dice (reparto_suelto) y no deja repartir encima, y fn_jornal_deshacer lo cierra sin tocar el libro otra vez; después, verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. Lo que la pantalla pinta: v_jornal_pendientes (la tarjeta de «mano de
--     obra» de la Bandeja: la misma cuenta que la propuesta sin fechas) y
--     v_jornal_repartos (el historial), con sus columnas: las del contrato.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_j jsonb; a text; b text; c text; v_def record;
  v_esp text := 'pendientes: 300.00 de Zzana C10 PRUEBA, 12 h en 2 reportes y 2 obras, a 25.00 la hora, se puede aplicar, con la huella y las '
                'líneas de la propuesta | repartos: aplicado, 150.00 por 6 h en 1 obra (C10 PRUEBA Obra H, línea 2), su asiento vivo, 1 hora '
                'aprobada, por el dueño | las columnas: las del contrato';
begin
  if pg_temp.c10_omitir(34, 'v_jornal_pendientes y v_jornal_repartos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select * into v_def from fn_jornal_periodo(pg_temp.c10_d());
    perform pg_temp.c10_hora(1, 'p1', v_def.desde, 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', v_def.desde + 1, 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', v_def.desde - 14, 'c10-prueba-h', 6);
    m2 := pg_temp.c10_cargo('c10-t34-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9342');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(m2, v_def.desde - 14, v_def.desde - 8);
    m1 := pg_temp.c10_cargo('c10-t34-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9341');
    v_j := pg_temp.c10_propuesta(m1);
    perform pg_temp.c10_ser('dueno');
    select format('%s de %s, %s h en %s reportes y %s obras, a %s la hora, %s, %s', p.monto, p.persona, trim_scale(p.horas), p.reportes, p.obras,
                  p.tarifa_sale,
                  -- (sin avisos, salvo los del calendario —otro_mes, otro_anio—, que dependen del día en que se corre; y la
                  -- etiqueta corta y la cuenta de avisos de la vista son las de la lista)
                  case when p.puede_aplicar and p.por_que is null
                            and (select count(*) from jsonb_array_elements(p.avisos) a2 where a2->>'codigo' not in ('otro_mes', 'otro_anio')) = 0
                            and p.n_avisos = jsonb_array_length(p.avisos)
                            and p.aviso is not distinct from (select string_agg(a2->>'corto', ' · ') from jsonb_array_elements(p.avisos) a2)
                       then 'se puede aplicar' else 'NO se puede: ' || coalesce(p.por_que, p.aviso) end,
                  case when p.visto = v_j->>'visto' and p.lineas = v_j->'lineas' and p.desde = v_def.desde and p.hasta = v_def.hasta and p.regla = v_def.regla
                            and p.fecha = pg_temp.c10_d() and p.cuenta = pg_temp.c10('banco') and p.usuario_id::text = pg_temp.c10('p1') and p.tarifa = 25
                            and p.periodo_texto = fn_jornal_rango(v_def.desde, v_def.hasta) and p.horas_sin_obra is null and p.propuesta_ia is null
                       then 'con la huella y las líneas de la propuesta' else 'con otra cosa que la propuesta' end)
      into a from v_jornal_pendientes p where p.movimiento_id = m1;
    select format('%s, %s por %s h en %s obra (%s, línea %s), %s, %s hora aprobada, %s', r.estado, r.monto, trim_scale(r.horas), r.obras,
                  r.lineas->0->>'obra', r.lineas->0->>'orden',
                  case when r.asiento_vivo and r.asiento = v_r->'asiento'->>'numero' and r.asiento_fecha = pg_temp.c10_d() and r.reverso is null then 'su asiento vivo' else 'su asiento NO' end,
                  r.horas_aprobadas,
                  case when r.creado_por::text = pg_temp.c10('dueno') and r.creado_por_nombre = (select pf.nombre from perfiles pf where pf.id = r.creado_por)
                            and r.persona = 'Zzana C10 PRUEBA' and r.fecha_pago = pg_temp.c10_d() and r.cuenta_banco = pg_temp.c10('banco')
                            and r.regla_periodo = 'a_mano' and r.cuenta = '5200' and r.tarifa_sale = 25.00 and r.deshecho_el is null
                       then 'por el dueño' else 'con algo mal: ' || to_jsonb(r)::text end)
      into b from v_jornal_repartos r where r.movimiento_id = m2;
    perform pg_temp.c10_ser('editor');
    select case when (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                       where a2.attrelid = 'public.v_jornal_pendientes'::regclass and a2.attnum > 0)
                     = 'movimiento_id,cuenta,fecha,monto,descripcion,usuario_id,persona,tarifa,desde,hasta,regla,periodo_texto,horas,reportes,obras,'
                       'horas_sin_obra,tarifa_sale,puede_aplicar,por_que,aviso,n_avisos,avisos,lineas,visto,propuesta_ia'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_repartos'::regclass and a2.attnum > 0)
                     = 'reparto_id,estado,movimiento_id,fecha_pago,cuenta_banco,descripcion,usuario_id,persona,desde,hasta,regla_periodo,periodo_texto,'
                       'monto,horas,tarifa_sale,tarifa_equipo,cuenta,cuenta_sin_obra,obras,lineas,asiento_id,asiento,asiento_fecha,asiento_vivo,avisos,'
                       'opciones,horas_aprobadas,creado_el,creado_por,creado_por_nombre,deshecho_el,deshecho_por,deshecho_por_nombre,deshecho_motivo,'
                       'reverso_id,reverso'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_personas'::regclass and a2.attnum > 0)
                     = 'usuario_id,nombre,rol,perfil_activo,registrada,activa,patron,cuenta_propia,cuenta,tarifa,nota,creado_el,actualizado_el,'
                       'pagos_pendientes,pagos_pendientes_monto,repartos,repartido,ultimo_reparto,horas_90_dias,horas_sin_pago'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_control'::regclass and a2.attnum > 0) = 'orden,cuadre,nivel,ok,detalle'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_margen_control'::regclass and a2.attnum > 0) = 'orden,cuadre,nivel,ok,detalle'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_margen_obra'::regclass and a2.attnum > 0)
                     = 'proyecto_id,obra,cliente,tipo,estado,completado_el,libro_desde,parcial,parcial_por,contrato,ingreso_libro,material_real,'
                       'mano_obra_real,mano_obra_jornales,mano_obra_nomina,subcontratos_real,equipo_real,otros_costos_real,costo_real,horas_reales,'
                       'horas_co,horas_base,horas_antes_libro,horas_con_pago_real,horas_estandar,horas_dueno,horas_sin_aprobar,mano_obra_estandar,'
                       'mano_obra_estandar_falta,mano_obra_dueno,burden_estandar_pct,costo_con_estandar,horas_estimadas,tarifa_estimada,escenario,'
                       'estimado_id,mano_obra_estimada,material_presupuesto,costo_estimado,estimado_completo,estimado_falta,margen_real,'
                       'margen_real_pct,margen_estimado,margen_estimado_pct,diferencia,pagos_sin_repartir,asientos,avisos'
                then 'las del contrato' else 'han cambiado' end
      into c;
    v_obt := format('pendientes: %s | repartos: %s | las columnas: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'lo que la pantalla pinta: v_jornal_pendientes (el pago con su semana, sus horas, sus obras, la tarifa que sale, si se puede aplicar, la huella y las líneas: lo mismo que la propuesta sin fechas) y v_jornal_repartos (el historial); y las columnas de las seis vistas son las del contrato',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- v_jornal_control: cada cuadre en rojo, y de vuelta a verde
-- (el 20, en la 33). Lo que solo se rompe por debajo de las guardas se
-- rompe aquí apagando la guarda de la tabla de c10 dentro de la prueba (se
-- deshace con ella).
-- ---------------------------------------------------------------------
-- 35. El 10: cada reparto aplicado ES las líneas de su asiento, y su
--     detalle por reporte suma cada parte.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid; a text; b text; c text; d text; e text;
  v_esp text := 'verde | una parte cambiada por debajo: rojo (no es su línea; no suman el pago; el detalle no suma) | de vuelta: verde | el '
                'detalle de un reporte cambiado: rojo (el detalle no suma) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(35, 'el control 10 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(35, 'el control 10 del jornal', v_esp, 'jornal', array[10]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    v_mov := pg_temp.c10_cargo('c10-t35', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9035');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    a := pg_temp.c10_jc(10);
    alter table public.jornal_reparto_lineas disable trigger trg_jornal_reparto_lineas_guarda;
    alter table public.jornal_reparto_horas disable trigger trg_jornal_reparto_horas_guarda;
    update jornal_reparto_lineas set monto = monto + 1 where reparto_id = v_rep and n = 1;
    b := pg_temp.c10_jc(10);
    -- (y lo dice sin nombrar una función ni una vista: ese detalle lo lee Edgar en la Bandeja)
    b := case when b like 'rojo: %la parte 1 (201.00) no es la línea 2 de su asiento%sus partes no suman el pago%su detalle por reporte de horas no suma sus partes%'
                   and b like '%→ no toques el libro: mira ese reparto y su asiento (en Repartos), y avisa.' and b !~ 'fn_|v_jornal|v_margen'
              then 'rojo (no es su línea; no suman el pago; el detalle no suma)' else b end;
    update jornal_reparto_lineas set monto = monto - 1 where reparto_id = v_rep and n = 1;
    c := pg_temp.c10_jc(10);
    update jornal_reparto_horas set monto = monto - 0.01 where reparto_id = v_rep and horas_id = -1010000002;
    d := pg_temp.c10_jc(10);
    d := case when d like 'rojo: %su detalle por reporte de horas no suma sus partes%' and d not like '%no es la línea%' then 'rojo (el detalle no suma)' else d end;
    update jornal_reparto_horas set monto = monto + 0.01 where reparto_id = v_rep and horas_id = -1010000002;
    e := pg_temp.c10_jc(10);
    v_obt := format('%s | una parte cambiada por debajo: %s | de vuelta: %s | el detalle de un reporte cambiado: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'el control 10 del jornal (cada reparto aplicado es las líneas de su asiento, al centavo, y su detalle por reporte suma cada parte): en rojo si una parte o el detalle se cambian por debajo de la guarda, y de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. El 25: ningún reparto marcado deshecho con su asiento todavía vivo.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid; a text; b text; c text;
  v_esp text := 'verde | marcado deshecho por debajo, con su asiento vivo: rojo, y dice qué hacer | de vuelta: verde';
begin
  if pg_temp.c10_omitir(36, 'el control 25 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(36, 'el control 25 del jornal', v_esp, 'jornal', array[25]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t36', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9036');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    a := pg_temp.c10_jc(25);
    alter table public.jornal_repartos disable trigger trg_jornal_repartos_guarda;
    update jornal_repartos set estado = 'deshecho', deshecho_el = now(), deshecho_motivo = 'c10-pruebas: por debajo' where id = v_rep;
    b := pg_temp.c10_jc(25);
    b := case when b like 'rojo: %asiento ' || (v_r->'asiento'->>'numero') || '%su asiento sigue en el libro: des-casa su pago en la Bandeja%' then 'rojo, y dice qué hacer' else b end;
    update jornal_repartos set estado = 'aplicado', deshecho_el = null, deshecho_motivo = null where id = v_rep;
    c := pg_temp.c10_jc(25);
    v_obt := format('%s | marcado deshecho por debajo, con su asiento vivo: %s | de vuelta: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'el control 25 del jornal (ningún reparto deshecho con su asiento todavía vivo): en rojo si un reparto se marca deshecho por debajo de la guarda, con qué hacer; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. El 30: las horas de un reparto aplicado siguen como se repartieron.
--     Edgar corrige unas horas en la app (c3 les quita la aprobación), les
--     cambia la obra, o se borra un reporte: en rojo, y dice cuál y qué
--     pasó; deshecho el reparto (se vuelve a repartir con las de hoy), verde.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'verde | otras horas: rojo (el reporte del lunes cambió de horas, de 8 a 7) | las de antes, pero ya sin aprobar: rojo (ya no '
                'está aprobado) | aprobadas otra vez: verde | otra obra: rojo (cambió de obra) | un reporte borrado: rojo (se borró), y dice '
                'qué hacer | deshecho el reparto: verde';
begin
  if pg_temp.c10_omitir(37, 'el control 30 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(37, 'el control 30 del jornal', v_esp, 'jornal', array[30]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-h', 2);
    v_mov := pg_temp.c10_cargo('c10-t37', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9037');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(30);
    perform pg_temp.c10_corregir(1, 'horas = 7');
    b := pg_temp.c10_jc(30);
    b := case when b like 'rojo: %el reporte -1010000001 del ' || pg_temp.c10_w1(0) || ' cambió de horas (de 8 a 7)%' then 'rojo (el reporte del lunes cambió de horas, de 8 a 7)' else b end;
    perform pg_temp.c10_corregir(1, 'horas = 8');
    c := pg_temp.c10_jc(30);
    c := case when c like 'rojo: %el reporte -1010000001 %ya no está aprobado%' then 'rojo (ya no está aprobado)' else c end;
    perform pg_temp.c10_ser('dueno');
    perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"ids": [-1010000001]}'::jsonb);
    perform pg_temp.c10_ser('editor');
    d := pg_temp.c10_jc(30);
    perform pg_temp.c10_corregir(2, $s$proyecto_id = 'c10-prueba-i'$s$);
    e := pg_temp.c10_jc(30);
    e := case when e like 'rojo: %el reporte -1010000002 %cambió de obra%' then 'rojo (cambió de obra)' else e end;
    delete from horas where id = -1010000003;
    f := pg_temp.c10_jc(30);
    f := case when f like 'rojo: %el reporte -1010000003 %se borró%→ el pago se repartió con otras horas: deshaz ese reparto%' then 'rojo (se borró), y dice qué hacer' else f end;
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: las horas cambiaron, se vuelve a repartir');
    g := pg_temp.c10_jc(30);
    v_obt := format('%s | otras horas: %s | las de antes, pero ya sin aprobar: %s | aprobadas otra vez: %s | otra obra: %s | un reporte borrado: '
                    '%s | deshecho el reparto: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'el control 30 del jornal (las horas de cada reparto aplicado siguen como se repartieron y aprobadas): en rojo si unas horas cambian, pierden su aprobación, cambian de obra o se borran, con cuál y qué hacer; de vuelta a verde al aprobarlas o al deshacer el reparto',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. El 40: ninguna hora en dos repartos vivos sin que Edgar lo aceptara.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; a text; b text; c text; d text;
  v_esp text := 'un pago: verde | otro pago de las mismas horas, pedido por Edgar: verde, y lo dice | lo mismo sin haberlo pedido: rojo (en 2 '
                'repartos), y dice qué hacer | de vuelta: verde';
begin
  if pg_temp.c10_omitir(38, 'el control 40 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(38, 'el control 40 del jornal', v_esp, 'jornal', array[40]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t38-1', pg_temp.c10_d(), 120.00, 'Zelle payment to C10 PRUEBA ZZANA 9381');
    m2 := pg_temp.c10_cargo('c10-t38-2', pg_temp.c10_d(), 80.00, 'Zelle payment to C10 PRUEBA ZZANA 9382');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(40);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    b := pg_temp.c10_jc(40);
    b := case when b = 'verde' and (select k.detalle from v_jornal_control k where k.orden = 40) like '% reporte(s) de horas están en dos repartos porque Edgar lo pidió%'
              then 'verde, y lo dice' else b end;
    alter table public.jornal_repartos disable trigger trg_jornal_repartos_guarda;
    update jornal_repartos set opciones = '{}'::jsonb where id = (v_r->>'reparto_id')::uuid;
    c := pg_temp.c10_jc(40);
    c := case when c like 'rojo: %el reporte -1010000001 %(en 2 repartos)%→ una semana pagada dos veces sin decirlo: deshaz el reparto que sobre%' then 'rojo (en 2 repartos), y dice qué hacer' else c end;
    update jornal_repartos set opciones = '{"incluir_cubiertas": true}'::jsonb where id = (v_r->>'reparto_id')::uuid;
    d := pg_temp.c10_color(pg_temp.c10_jc(40));
    v_obt := format('un pago: %s | otro pago de las mismas horas, pedido por Edgar: %s | lo mismo sin haberlo pedido: %s | de vuelta: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'el control 40 del jornal (ninguna hora en dos repartos vivos sin que Edgar lo aceptara): verde con «es otro pago de las mismas horas» (y lo dice); en rojo si el segundo reparto no lo lleva escrito; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 39. El 50: una hora que está a la vez en el devengo estándar de un mes
--     (c3, fn_horas_devengar) y en un jornal que entró al libro en ese mismo
--     mes cuenta dos veces: en rojo, con el mes, el devengo, las horas y el
--     jornal; deshecho el jornal, deja de contar (verde, salvo que ese mes
--     tenga jornales reales que también choquen: entonces lo que se mira es
--     que el de la prueba ya no esté). Y en la obra el devengo no cuenta
--     como real (se anula solo con su reverso del día 1). (Lo que NO es
--     doble —el pago que entra al mes siguiente— lo prueba la 54.)
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_mes text; v_dia date; v_dev jsonb; v_no text; a text; b text; c text; d text; v_n1 int; v_h1 numeric; v_n2 int; v_h2 numeric;
  v_esp text := 'con el jornal: verde | con el devengo estándar del mismo mes: rojo (nombra el mes, su devengo, las horas y el jornal), y dice '
                'qué hacer | en la obra, el devengo no cuenta como real: jornales 200.00, nómina 0.00 | deshecho el jornal: el de la prueba '
                'ya no cuenta';
begin
  if pg_temp.c10_omitir(39, 'el control 50 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(39, 'el control 50 del jornal', v_esp, 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (en el mes del pago, que está abierto: las horas, el día 1)
    v_dia := date_trunc('month', pg_temp.c10_d())::date;
    v_mes := to_char(v_dia, 'YYYY-MM');
    perform pg_temp.c10_hora(1, 'p1', v_dia, 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t39', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9039');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, v_dia, v_dia);
    a := pg_temp.c10_jc(50);
    begin
      v_dev := fn_horas_devengar(v_mes);
    exception when others then v_no := sqlstate || ': ' || sqlerrm;
    end;
    if v_no is null then
      b := pg_temp.c10_jc(50);
      -- (cuántas horas y cuántos jornales dice que chocan con el devengo de ese mes)
      v_h1 := substring(b from v_mes || ': el devengo [^ ]+ cuenta ([0-9.]+) h')::numeric;
      v_n1 := substring(b from v_mes || ': el devengo [^ ]+ cuenta [0-9.]+ h \([0-9]+ reporte\(s\)\) que ya tienen su pago real en ese mes, en ([0-9]+) jornal')::int;
      b := case when b like 'rojo: %' || v_mes || ': el devengo ' || (v_dev->>'asiento') || ' cuenta % h (% reporte(s)) que ya tienen su pago real en ese mes, en % jornal(es)%'
                                   || '→ esa mano de obra sale dos veces en ese mes%hay que retirarlo de ese mes antes de cerrarlo%'
                then 'rojo (nombra el mes, su devengo, las horas y el jornal), y dice qué hacer' else b end;
      perform pg_temp.c10_ser('dueno');
      select format('jornales %s, nómina %s', o.mano_obra_jornales, o.mano_obra_nomina) into c from v_margen_obra o where o.proyecto_id = 'c10-prueba-a';
      perform pg_temp.c10_ser('editor');
      perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: ese mes va con su devengo estándar');
      d := pg_temp.c10_jc(50);
      v_h2 := coalesce(substring(d from v_mes || ': el devengo [^ ]+ cuenta ([0-9.]+) h')::numeric, 0);
      v_n2 := coalesce(substring(d from v_mes || ': el devengo [^ ]+ cuenta [0-9.]+ h \([0-9]+ reporte\(s\)\) que ya tienen su pago real en ese mes, en ([0-9]+) jornal')::int, 0);
      d := case when d = 'verde' or (v_n2 = v_n1 - 1 and v_h2 = v_h1 - 8) then 'el de la prueba ya no cuenta' else d end;
      v_obt := format('con el jornal: %s | con el devengo estándar del mismo mes: %s | en la obra, el devengo no cuenta como real: %s | deshecho '
                      'el jornal: %s', a, b, c, d);
    else
      v_obt := format('omitida: c3 no dejó devengar %s (%s); con el jornal: %s', v_mes, left(v_no, 300), a);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'el control 50 del jornal (ninguna hora a la vez en el devengo estándar de un mes y en un jornal que entró al libro ese mes: la mano de obra saldría dos veces): en rojo con el mes, el devengo, las horas y el jornal; en la obra el devengo no cuenta como real; deshecho el jornal, deja de contar',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 40. El 60 (un aviso): cada persona dada de alta se reconoce sin dudas y va
--     a una cuenta que sirve.
do $$
declare
  v_obt text; v_mov uuid; a text; b text; c text; d text; e text;
  v_esp text := 'verde | un pago que casa con dos personas: rojo, de nivel aviso, y dice qué hacer | afinado el patrón: verde | una cuenta que '
                'dejó de servir: rojo (la nombra) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(40, 'el control 60 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(40, 'el control 60 del jornal', v_esp, 'jornal', array[60]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_mov := pg_temp.c10_cargo('c10-t40', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9040');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    a := pg_temp.c10_jc(60);
    perform pg_temp.c10_alta('p2', '\mPRUEBA ZZ');
    b := pg_temp.c10_jc(60);
    b := case when b like 'rojo: %«Zelle payment to C10 PRUEBA ZZANA 9040») casa con 2 personas%→ corrígelo en las personas del jornal%'
                   and b !~ 'fn_|v_jornal|v_margen'
                   and (select k.nivel from v_jornal_control k where k.orden = 60) = 'aviso' then 'rojo, de nivel aviso, y dice qué hacer' else b end;
    perform pg_temp.c10_alta('p2');
    c := pg_temp.c10_jc(60);
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    update jornal_personas set cuenta = '5000' where usuario_id = pg_temp.c10('p1')::uuid;
    d := pg_temp.c10_jc(60);
    d := case when d like 'rojo: %Zzana C10 PRUEBA: la cuenta 5000 (%) es mano de obra de nómina%' then 'rojo (la nombra)' else d end;
    update jornal_personas set cuenta = null where usuario_id = pg_temp.c10('p1')::uuid;
    perform set_config('mx_jornal.escribe', '', true);
    e := pg_temp.c10_jc(60);
    v_obt := format('%s | un pago que casa con dos personas: %s | afinado el patrón: %s | una cuenta que dejó de servir: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'el control 60 del jornal (un aviso: cada persona dada de alta se reconoce sin dudas y va a una cuenta que sirve): en rojo si un pago pendiente casa con dos personas, o si una cuenta dejó de servir; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. El 90: las protecciones de la capa (por el nombre exacto de cada
--     objeto de c10). Cada cosa se rompe y se deshace en su bloque.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'verde | anon puede ejecutar una función: rojo | una tabla sin RLS: rojo | una función SECURITY DEFINER: rojo | una vista sin '
                'security_invoker: rojo | la guarda de una tabla apagada: rojo | service_role puede leer una tabla: rojo | y todo deshecho: verde';
begin
  if pg_temp.c10_omitir_rojo(41, 'el control 90 del jornal', v_esp, 'jornal', array[90]) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    a := pg_temp.c10_jc(90);
    begin
      grant execute on function public.fn_jornal_aplicar(uuid, date, date, text, jsonb) to anon;
      b := pg_temp.c10_jc(90);
      b := case when b like 'rojo: %fn_jornal_aplicar la puede ejecutar anon%→ vuelve a pegar c10-costo-obra.sql%' then 'rojo' else b end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.jornal_repartos disable row level security;
      c := pg_temp.c10_jc(90);
      c := case when c like 'rojo: %jornal_repartos sin RLS%' then 'rojo' else c end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter function public.fn_margen_obra(text) security definer;
      d := pg_temp.c10_jc(90);
      d := case when d like 'rojo: %fn_margen_obra es SECURITY DEFINER%' then 'rojo' else d end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter view public.v_margen_obra set (security_invoker = false);
      e := pg_temp.c10_jc(90);
      e := case when e like 'rojo: %v_margen_obra sin security_invoker%' then 'rojo' else e end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.jornal_personas disable trigger trg_jornal_personas_guarda;
      f := pg_temp.c10_jc(90);
      f := case when f like 'rojo: %la guarda trg_jornal_personas_guarda de jornal_personas está apagada%' then 'rojo' else f end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      grant select on public.jornal_reparto_horas to service_role;
      g := pg_temp.c10_jc(90);
      g := case when g like 'rojo: %service_role puede SELECT en jornal_reparto_horas%' then 'rojo' else g end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('%s | anon puede ejecutar una función: %s | una tabla sin RLS: %s | una función SECURITY DEFINER: %s | una vista sin '
                    'security_invoker: %s | la guarda de una tabla apagada: %s | service_role puede leer una tabla: %s | y todo deshecho: %s',
                    a, b, c, d, e, f, g, pg_temp.c10_jc(90));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, 'el control 90 del jornal (las protecciones de la capa, por el nombre exacto de cada objeto): en rojo si anon ejecuta una función, una tabla pierde su RLS, una función pasa a SECURITY DEFINER, una vista pierde security_invoker, se apaga una guarda o service_role lee una tabla; deshecho, verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL MARGEN (v_margen_obra, fn_margen_obra, v_margen_control)
-- ---------------------------------------------------------------------
-- Un asiento a mano del dueño (fn_postear), para poner en el libro lo que
-- una obra de prueba necesita: su factura, su material, un subcontrato…
create or replace function pg_temp.c10_postear(p_desc text, p_lineas jsonb) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_postear(jsonb_build_object('fecha', pg_temp.c10_d()::text, 'descripcion', 'C10 PRUEBA: ' || p_desc || ' (se deshace)', 'lineas', p_lineas));
  perform pg_temp.c10_ser('editor');
  return (select a.id from asientos a where a.numero = r->>'numero');
end $$;

-- 42. Una obra con de todo: su factura (4020), material (5100, parte con un
--     CO), jornales, un subcontrato DE VERDAD en la misma 5200, equipo
--     (5300) y otro costo (5400). Cada columna de v_margen_obra contra el
--     libro, al centavo; y cada «bajar» de fn_margen_obra suma su cifra.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; o record; v_as uuid; a text; b text; c text; d text;
  v_esp text := 'ingreso 5000.00 | material 750.25 | mano de obra 250.00 (jornales 250.00, nómina 0.00) | subcontratos 500.00 | equipo 75.25 | '
                'otros 60.00 | costo 1635.50 | margen 3364.50 (67.3 %) | 3 asientos | cada columna es la del libro: sí | los 8 «bajar» de los '
                'conceptos suman su cifra: sí | por cuenta, la 5200 sale partida en dos (jornales 250.00 y lo demás 500.00) y los 5 «bajar» '
                'suman: sí';
begin
  if pg_temp.c10_omitir(42, 'el margen de una obra con de todo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'trim');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    perform pg_temp.c10_postear('la factura de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '1600', 'monto', '5000.00'),
      jsonb_build_object('cuenta', '4020', 'monto', '-5000.00', 'proyecto_id', 'c10-prueba-a')));
    perform pg_temp.c10_postear('los costos de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-a', 'co', 'CO #1', 'fase', 'rough'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5300', 'monto', '75.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5400', 'monto', '60.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-1385.50')));
    v_mov := pg_temp.c10_cargo('c10-t42', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9042');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_as := (v_r->'asiento'->>'id')::uuid;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    v_j := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    a := format('ingreso %s | material %s | mano de obra %s (jornales %s, nómina %s) | subcontratos %s | equipo %s | otros %s | costo %s | '
                'margen %s (%s %%) | %s asientos', o.ingreso_libro, o.material_real, o.mano_obra_real, o.mano_obra_jornales, o.mano_obra_nomina,
                o.subcontratos_real, o.equipo_real, o.otros_costos_real, o.costo_real, o.margen_real, o.margen_real_pct, o.asientos);
    -- contra el libro, línea por línea (las tablas, no la vista)
    select case when o.ingreso_libro = (select -sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta like '40%')
                     and o.material_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5100')
                     and o.mano_obra_jornales = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.asiento_id = v_as and l.orden > 1)
                     and o.subcontratos_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5200' and l.asiento_id <> v_as)
                     and o.equipo_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5300')
                     and o.otros_costos_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5400')
                     and o.costo_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta like '5%')
                     and v_j->'obra' = to_jsonb(o)
                then 'sí' else 'NO' end into b;
    select format('%s', case when count(*) = 8 and bool_and(pg_temp.c10_bajar(x->'bajar') = (x->>'real')::numeric) then 'sí' else 'NO (' || count(*) || ')' end)
      into c from jsonb_array_elements(v_j->'conceptos') x where x ? 'bajar';
    select format('la 5200 sale partida en dos (jornales %s y lo demás %s) y los %s «bajar» suman: %s',
                  (select x->>'real' from jsonb_array_elements(v_j->'por_cuenta') x where x->>'cuenta' = '5200' and (x->>'jornal')::boolean),
                  (select x->>'real' from jsonb_array_elements(v_j->'por_cuenta') x where x->>'cuenta' = '5200' and not (x->>'jornal')::boolean),
                  count(*), case when bool_and(pg_temp.c10_bajar(x->'bajar') = (x->>'real')::numeric) then 'sí' else 'NO' end)
      into d from jsonb_array_elements(v_j->'por_cuenta') x;
    v_obt := format('%s | cada columna es la del libro: %s | los 8 «bajar» de los conceptos suman su cifra: %s | por cuenta, %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'EL MARGEN de una obra con su factura, material, jornales, un subcontrato de verdad en la misma 5200, equipo y otro costo: cada columna de v_margen_obra es la del libro, al centavo; los jornales no se confunden con el subcontrato; y cada «bajar» de fn_margen_obra (por concepto y por cuenta) suma su cifra en v_libro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. La mano de obra DICE si es real o estándar. Real: lo pagado y
--     repartido. Estándar: las horas sin pago real × la tarifa de Costos del
--     equipo × (1 + burden estándar), al centavo por reporte; sin burden
--     fijado, o sin la tarifa de alguien, sale vacía con su porqué. Las del
--     dueño van aparte y no suman; las de antes del libro no van a estándar.
do $$
declare
  v_obt text; v_mov uuid; o record; a text; b text; c text; d text; e text; v_td numeric;
  v_esp text := 'sin burden fijado: 24.75 h; 8 con pago real (200.00), 5.75 a estándar sin cifra (falta el burden), 6 del dueño y 5 de antes '
                'del libro | burden 0: estándar 141.50, costo con estándar 341.50 | burden 12.5: estándar 159.19 (al centavo por reporte), '
                'costo con estándar 359.19 | las del dueño van aparte y no suman: sí | alguien sin tarifa: 9.75 h a estándar sin cifra, y dice '
                'quién | sin aprobar: 20.75 h';
begin
  if pg_temp.c10_omitir(43, 'la mano de obra real contra la estándar', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 3.5);
    perform pg_temp.c10_hora(3, 'p2', pg_temp.c10_w2(0), 'c10-prueba-h', 2.25);
    perform pg_temp.c10_hora(4, 'dueno', pg_temp.c10_w2(0), 'c10-prueba-h', 6);
    perform pg_temp.c10_hora(5, 'p2', pg_temp.c10('libro_desde')::date - 3, 'c10-prueba-h', 5);
    select ce.costo_hora into v_td from costos_equipo ce where ce.usuario_id = pg_temp.c10('dueno')::uuid;
    v_mov := pg_temp.c10_cargo('c10-t43', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9043');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": null}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    a := format('%s h; %s con pago real (%s), %s a estándar %s, %s del dueño y %s de antes del libro', trim_scale(o.horas_reales),
                trim_scale(o.horas_con_pago_real), o.mano_obra_real, trim_scale(o.horas_estandar),
                case when o.mano_obra_estandar is null and o.costo_con_estandar is null and o.mano_obra_estandar_falta like 'Falta fijar el burden estándar%'
                          and o.burden_estandar_pct is null then 'sin cifra (falta el burden)' else 'con cifra: ' || o.mano_obra_estandar end,
                trim_scale(o.horas_dueno), trim_scale(o.horas_antes_libro));
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    b := format('estándar %s, costo con estándar %s', o.mano_obra_estandar, o.costo_con_estandar);
    perform fn_jornal_config('{"burden_estandar_pct": 12.5}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    c := format('estándar %s (al centavo por reporte), costo con estándar %s', o.mano_obra_estandar, o.costo_con_estandar);
    -- (las 6 h del dueño: aparte, con su tarifa si la tiene, y fuera del costo)
    d := case when o.costo_con_estandar = o.costo_real + o.mano_obra_estandar and o.horas_dueno = 6
                   and o.mano_obra_dueno is not distinct from round(6 * v_td * 1.125, 2)
                   and exists (select 1 from unnest(o.avisos) x where x like '6 h de % (dueño) no están en el costo: no cobra por hora.')
              then 'sí' else 'NO' end;
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_hora(6, 'p3', pg_temp.c10_w2(1), 'c10-prueba-h', 4);
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    e := format('%s h a estándar %s', trim_scale(o.horas_estandar),
                case when o.mano_obra_estandar is null and o.mano_obra_estandar_falta = 'Falta la tarifa de Zzcaro C10 PRUEBA en Costos del equipo: la mano de obra estándar no se calcula.'
                     then 'sin cifra, y dice quién' else 'con cifra o sin decir quién: ' || coalesce(o.mano_obra_estandar_falta, o.mano_obra_estandar::text) end);
    v_obt := format('sin burden fijado: %s | burden 0: %s | burden 12.5: %s | las del dueño van aparte y no suman: %s | alguien sin tarifa: %s | '
                    'sin aprobar: %s h', a, b, c, d, e, trim_scale(o.horas_sin_aprobar));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'la mano de obra dice si es REAL (pagada y repartida) o ESTÁNDAR (horas sin pago real × la tarifa de Costos del equipo × (1 + burden estándar), al centavo por reporte): sin el burden fijado o sin la tarifa de alguien sale vacía y dice por qué; las horas del dueño van aparte y no suman; las de antes del libro no van a estándar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 44. El estimado, de las mismas fuentes que la app: sin estimado enlazado,
--     el escenario B; con él, el suyo y sus beneficios; el «convertido»
--     antes que el más nuevo. (Los escenarios A y B se fijan dentro de la
--     prueba con tarifas redondas; se deshace.)
do $$
declare
  v_obt text; o record; a text; b text; c text; d text; e text;
  v_esp text := 'sin estimado enlazado: B, 36.25 la hora × 100 h = 3625.00, material 2000.00, costo 5625.00, contrato 9000.00, margen 3375.00 '
                '(37.5 %), diferencia 5625.00 | con su estimado: A, 42.38, mano de obra 4238.00 | con sus beneficios: 35.86, mano de obra '
                '3586.00 | el convertido antes que el más nuevo: B, 36.25 | una obra sin datos: sin cifras, y lo dice';
begin
  if pg_temp.c10_omitir(44, 'el estimado de una obra', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into escenarios (id, nombre, foreman, journeyman, helper, pct_foreman, pct_journeyman, pct_helper, benefits) values
      ('B', 'C10 PRUEBA B', 40, 30, 20, 0.2, 0.5, 0.3, 0.25), ('A', 'C10 PRUEBA A', 50, 35, 22, 0.1, 0.6, 0.3, 0.30)
    on conflict (id) do update set foreman = excluded.foreman, journeyman = excluded.journeyman, helper = excluded.helper,
      pct_foreman = excluded.pct_foreman, pct_journeyman = excluded.pct_journeyman, pct_helper = excluded.pct_helper, benefits = excluded.benefits;
    update proyectos set horas_estimadas = 100 where id = 'c10-prueba-i';
    update proyectos set horas_estimadas = null where id = 'c10-prueba-j';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-i', 9000, 2000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    delete from finanzas_proyecto where proyecto_id = 'c10-prueba-j';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    a := format('%s, %s la hora × %s h = %s, material %s, costo %s, contrato %s, margen %s (%s %%), diferencia %s%s', o.escenario, o.tarifa_estimada,
                trim_scale(o.horas_estimadas), o.mano_obra_estimada, o.material_presupuesto, o.costo_estimado, o.contrato, o.margen_estimado,
                o.margen_estimado_pct, o.diferencia, case when o.estimado_id is null then '' else ' (CON estimado)' end);
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000001, 'C10 PRUEBA estimado de la obra I', 'c10-prueba-i', 'A', 'borrador', null, now());
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    b := format('%s, %s, mano de obra %s%s', o.escenario, o.tarifa_estimada, o.mano_obra_estimada, case when o.estimado_id = -1010000001 then '' else ' (OTRO estimado)' end);
    update estimados set benefits_pct = 0.10 where id = -1010000001;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    c := format('%s, mano de obra %s', o.tarifa_estimada, o.mano_obra_estimada);
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000002, 'C10 PRUEBA estimado convertido de la obra I', 'c10-prueba-i', 'B', 'convertido', null, now() - interval '30 days');
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    d := format('%s, %s%s', o.escenario, o.tarifa_estimada, case when o.estimado_id = -1010000002 then '' else ' (el OTRO estimado)' end);
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    perform pg_temp.c10_ser('editor');
    e := case when o.horas_estimadas is null and o.mano_obra_estimada is null and o.material_presupuesto is null and o.costo_estimado is null
                   and o.contrato is null and o.margen_estimado is null and o.diferencia is null
                   and o.avisos @> array['Sin contrato en la ficha de la obra.', 'Sin horas estimadas.', 'Sin presupuesto de material.']
              then 'sin cifras, y lo dice' else 'con cifras: ' || to_jsonb(o)::text end;
    v_obt := format('sin estimado enlazado: %s | con su estimado: %s | con sus beneficios: %s | el convertido antes que el más nuevo: %s | una '
                    'obra sin datos: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'el estimado sale de las mismas fuentes que la app (horas_estimadas, el presupuesto de material y el contrato de la ficha, y la tarifa del escenario): sin estimado enlazado, el escenario B; con él, el suyo, con sus beneficios si los tiene; el «convertido» antes que el más nuevo; sin datos, sin cifras y lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 45. El libro empieza el día después de la apertura: una obra que ya
--     andaba antes sale «parcial», y se dice en llano qué tenía.
do $$
declare
  v_obt text; o record; a text; b text; c text;
  v_esp text := 'con horas de antes del libro: parcial (horas), y lo dice | con horas de antes de la app en su ficha: parcial (horas de antes '
                'de la app), 12 h de base | una obra nueva: no es parcial';
begin
  if pg_temp.c10_omitir(45, 'la obra que ya andaba antes del libro', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p2', pg_temp.c10('libro_desde')::date - 10, 'c10-prueba-k', 5);
    update proyectos set horas_reales_base = 12 where id = 'c10-prueba-l';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-k';
    a := format('%s (%s), %s', case when o.parcial then 'parcial' else 'NO parcial' end, o.parcial_por,
                case when exists (select 1 from unnest(o.avisos) x
                                   where x = format('El libro empieza el %s y esta obra ya tenía de antes: horas. Lo de antes está en QuickBooks: aquí el real es parcial.',
                                                    fn_jornal_dia(pg_temp.c10('libro_desde')::date, true)))
                          and o.libro_desde = pg_temp.c10('libro_desde')::date and o.horas_antes_libro = 5 and o.horas_estandar = 0
                     then 'y lo dice' else 'y NO lo dice bien' end);
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-l';
    b := format('%s (%s), %s h de base', case when o.parcial then 'parcial' else 'NO parcial' end, o.parcial_por, trim_scale(o.horas_base));
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    c := case when not o.parcial and o.parcial_por is null then 'no es parcial' else 'parcial: ' || o.parcial_por end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('con horas de antes del libro: %s | con horas de antes de la app en su ficha: %s | una obra nueva: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'el libro empieza el día después de la apertura: una obra que ya andaba entonces (horas de antes, o de antes de la app en su ficha) sale parcial y dice en llano qué tenía; una obra nueva, no',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 46. El detalle de una obra (fn_margen_obra): por CO (la base aparte de
--     cada CO), por fase, por cost code (hoy ninguna línea lo trae: se dice;
--     con una que lo lleve, sale con su «bajar»), la cobertura de la mano de
--     obra por persona, los repartos que la tocan, y los pagos reconocidos
--     que siguen sin repartir.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'por CO: Base (sin CO) 8 h, mano de obra 200.00, material 450.25, costo 650.25; CO #1 2 h, mano de obra 50.00, material 300.00, '
                'costo 350.00 | por fase: rough 8 h, 200.00 pagados y 300.00 más en el libro; trim 2 h, 50.00 pagados | sin código: lo dice | '
                'con una línea con código: C10-PRUEBA 100.00, y su «bajar» suma | la cobertura: Zzana C10 PRUEBA 10 h, las 10 con pago real, '
                '250.00 | los repartos: 1, aplicado, 250.00 de 300.00 por 10 h | un pago suyo sin repartir: 1, y lo avisa';
begin
  if pg_temp.c10_omitir(46, 'el detalle de una obra', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'trim');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    perform pg_temp.c10_postear('el material de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-a', 'co', 'CO #1', 'fase', 'rough'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-750.25')));
    m1 := pg_temp.c10_cargo('c10-t46-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9461');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    v_j := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s h, mano de obra %s, material %s, costo %s', x->>'etiqueta', trim_scale((x->>'horas')::numeric),
                             x->>'mano_obra_real', x->>'material_real', x->>'costo_real'), '; ' order by o)
      into a from jsonb_array_elements(v_j->'por_co') with ordinality as t(x, o);
    select string_agg(format('%s %s h, %s pagados%s', x->>'etiqueta', trim_scale((x->>'horas')::numeric), x->>'mano_obra_real',
                             case when (x->>'otros_costos_libro')::numeric <> 0 then format(' y %s más en el libro', x->>'otros_costos_libro') else '' end),
                      '; ' order by o)
      into b from jsonb_array_elements(v_j->'por_fase') with ordinality as t(x, o);
    c := case when not (v_j->'por_cost_code'->>'hay')::boolean and v_j->'por_cost_code'->>'nota' like 'Todavía no hay nada capturado con código en esta obra%'
                   and jsonb_array_length(v_j->'por_cost_code'->'filas') = 0 then 'lo dice' else (v_j->'por_cost_code')::text end;
    select format('%s %s h, las %s con pago real, %s', x->>'persona', trim_scale((x->>'horas')::numeric), trim_scale((x->>'horas_con_pago_real')::numeric), x->>'pagado')
      into e from jsonb_array_elements(v_j->'cobertura') x;
    select format('%s, %s, %s de %s por %s h', jsonb_array_length(v_j->'repartos'), x->>'estado', x->>'monto_obra', x->>'monto', trim_scale((x->>'horas_obra')::numeric))
      into f from jsonb_array_elements(v_j->'repartos') x;
    -- una línea con código (un código de prueba en la tabla de la app; se deshace)
    insert into codigos_partida (codigo, nombre, nombre_en, categoria) values ('C10-PRUEBA', 'C10 PRUEBA código', 'C10 TEST code', 'preliminares');
    perform pg_temp.c10_postear('material con código de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '100.00', 'proyecto_id', 'c10-prueba-a', 'cost_code', 'C10-PRUEBA'),
      jsonb_build_object('cuenta', '3100', 'monto', '-100.00')));
    -- y otro pago suyo en la Bandeja, con una hora nueva de esta obra en la semana que le toca
    perform pg_temp.c10_hora(4, 'p1', (select p.desde + 3 from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-a', 1);
    m2 := pg_temp.c10_cargo('c10-t46-2', pg_temp.c10_d(), 25.00, 'Zelle payment to C10 PRUEBA ZZANA 9462');
    perform pg_temp.c10_ser('dueno');
    v_k := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    d := case when (v_k->'por_cost_code'->>'hay')::boolean
              then format('%s %s, y su «bajar» %s', v_k->'por_cost_code'->'filas'->0->>'cost_code', v_k->'por_cost_code'->'filas'->0->>'real',
                          case when pg_temp.c10_bajar(v_k->'por_cost_code'->'filas'->0->'bajar') = 100.00
                                    and v_k->'por_cost_code'->>'nota' = '$100.00 de costo llevan código; el resto ($1,000.25) no.' then 'suma' else 'NO suma' end)
              else 'no sale' end;
    g := format('%s, %s', v_k->'obra'->>'pagos_sin_repartir',
                case when exists (select 1 from jsonb_array_elements_text(v_k->'avisos') x where x like '1 pago(s) de mano de obra de esas semanas siguen sin repartir en la Bandeja%')
                     then 'y lo avisa' else 'y NO lo avisa' end);
    v_obt := format('por CO: %s | por fase: %s | sin código: %s | con una línea con código: %s | la cobertura: %s | los repartos: %s | un pago '
                    'suyo sin repartir: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (46, 'el detalle de una obra (fn_margen_obra): por CO (la base aparte de cada CO), por fase (horas y dólares), por cost code (hoy ninguna línea lo trae y se dice; con una que lo lleve sale con su «bajar»), la cobertura de la mano de obra por persona, los repartos que la tocan y los pagos reconocidos sin repartir',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 47. v_margen_control: con una obra con de todo, en verde (también contra
--     «Estados», c4); y el 40 en rojo cuando un reparto deja de ser su asiento.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; a text; b text; c text;
  v_esp text := 'con una obra con de todo: nada nuevo en rojo, y el costo de cada obra es el de Estados (c4) | un reparto que ya no es su '
                'asiento: el 40 en rojo, con la diferencia (1.00) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(47, 'v_margen_control', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(47, 'v_margen_control', v_esp, 'margen', array[40, 60]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_postear('la factura y los costos de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '1600', 'monto', '2000.00'),
      jsonb_build_object('cuenta', '4020', 'monto', '-2000.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-950.25')));
    v_mov := pg_temp.c10_cargo('c10-t47', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9047');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s, y %s', split_part(split_part(pg_temp.c10_propios(), 'del margen: ', 2), ' en rojo', 1) || ' en rojo',
                case when (select k.ok and k.detalle like 'Obra por obra, el costo real de aquí es el de «Estados»%' from v_margen_control k where k.orden = 60)
                     then 'el costo de cada obra es el de Estados (c4)'
                     else 'contra Estados: ' || (select k.detalle from v_margen_control k where k.orden = 60) end);
    alter table public.jornal_reparto_lineas disable trigger trg_jornal_reparto_lineas_guarda;
    update jornal_reparto_lineas set monto = monto + 1 where reparto_id = (v_r->>'reparto_id')::uuid and n = 1;
    b := pg_temp.c10_mc(40);
    b := case when b like 'rojo: El libro tiene % de jornales por obra y los repartos aplicados dicen %: diferencia -$1.00.%' then 'el 40 en rojo, con la diferencia (1.00)' else b end;
    update jornal_reparto_lineas set monto = monto - 1 where reparto_id = (v_r->>'reparto_id')::uuid and n = 1;
    c := pg_temp.c10_mc(40);
    v_obt := format('con una obra con de todo: %s | un reparto que ya no es su asiento: %s | de vuelta: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, 'v_margen_control: con una obra con factura, material, un subcontrato y jornales, nada nuevo en rojo, y el costo de cada obra es el de «Estados» (v_costo_por_obra, c4); el 40 se pone en rojo si un reparto deja de ser su asiento, y vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LO QUE LAS DOS REVISIONES ENCONTRARON (v2): una prueba por hallazgo
-- ---------------------------------------------------------------------
-- 48. UN ESTIMADO PARCIAL NO SE COMPARA CON UN REAL COMPLETO. El costo
--     estimado es mano de obra (horas × tarifa) más material. Si la mitad
--     que falta ya tiene real en la obra, o hay horas estimadas y no hay con
--     qué valorarlas, no hay total: costo_estimado, el margen estimado y la
--     diferencia salen vacíos, estimado_completo es falso y estimado_falta
--     dice qué falta. Lo que falta y todavía no tiene real no estorba.
--     (Antes la mitad que faltaba sumaba 0, y la obra salía «se pasa» o
--     «dentro» contra un real que sí la traía.)
do $$
declare
  v_obt text; o record; v_j jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'sin presupuesto de material y con material en el libro: sin total, y lo dice (la mano de obra estimada sigue: 3625.00) | sin '
                'horas estimadas y con horas a estándar: sin total, y lo dice | con horas estimadas y sin tarifas en su escenario: sin total, '
                'y lo dice | sin presupuesto de material y sin material en el libro: se compara (1450.00, diferencia 1450.00) | sin nada '
                'estimado: sin estimado, y lo dice | el detalle: el total sin estimado ni diferencia y con su nota; el material — contra '
                '300.00; la mano de obra 3625.00, diferencia 3625.00 | puesto el presupuesto que faltaba: 5625.00, diferencia 5325.00, margen '
                'estimado 3375.00';
begin
  if pg_temp.c10_omitir(48, 'un estimado parcial no se compara con un real completo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into escenarios (id, nombre, foreman, journeyman, helper, pct_foreman, pct_journeyman, pct_helper, benefits) values
      ('B', 'C10 PRUEBA B', 40, 30, 20, 0.2, 0.5, 0.3, 0.25)
    on conflict (id) do update set foreman = excluded.foreman, journeyman = excluded.journeyman, helper = excluded.helper,
      pct_foreman = excluded.pct_foreman, pct_journeyman = excluded.pct_journeyman, pct_helper = excluded.pct_helper, benefits = excluded.benefits;
    insert into escenarios (id, nombre) values ('C10Z', 'C10 PRUEBA sin tarifas');
    -- I: horas estimadas, SIN presupuesto de material, y material en el libro
    update proyectos set horas_estimadas = 100 where id = 'c10-prueba-i';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-i', 9000, null)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    perform pg_temp.c10_postear('el material de la obra I', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-i'),
      jsonb_build_object('cuenta', '3100', 'monto', '-300.00')));
    -- J: presupuesto de material, SIN horas estimadas, y horas a estándar
    update proyectos set horas_estimadas = null where id = 'c10-prueba-j';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-j', 5000, 2000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-j', 2);
    -- K: horas estimadas y material, pero su estimado va con un escenario sin tarifas
    update proyectos set horas_estimadas = 50 where id = 'c10-prueba-k';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-k', 4000, 1000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000048, 'C10 PRUEBA estimado de la obra K', 'c10-prueba-k', 'C10Z', 'borrador', null, now());
    -- L: horas estimadas, sin material presupuestado NI en el libro; H: nada
    -- estimado (y con horas a estándar: sigue siendo «no hay estimado», no «incompleto»)
    update proyectos set horas_estimadas = 40 where id = 'c10-prueba-l';
    delete from finanzas_proyecto where proyecto_id in ('c10-prueba-l', 'c10-prueba-h');
    update proyectos set horas_estimadas = null where id = 'c10-prueba-h';
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-h', 3);
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    a := case when o.costo_estimado is null and not o.estimado_completo and o.margen_estimado is null and o.margen_estimado_pct is null
                   and o.diferencia is null
                   and o.estimado_falta = 'Estimado incompleto: no tiene presupuesto de material y ya lleva $300.00 de material en el libro. '
                                          'No da un total que comparar con el costo real: se compara concepto por concepto lo que sí está estimado.'
                   and o.avisos @> array[o.estimado_falta, 'Sin presupuesto de material.']
              then format('sin total, y lo dice (la mano de obra estimada sigue: %s)', o.mano_obra_estimada)
              else 'mal: ' || to_jsonb(o)::text end;
    v_j := fn_margen_obra('c10-prueba-i');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    b := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.material_presupuesto = 2000
                   and o.estimado_falta like 'Estimado incompleto: no tiene horas estimadas y ya lleva mano de obra (2 h a estándar). No da un total%'
                   and o.avisos @> array[o.estimado_falta]
              then 'sin total, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') || ' / ' || coalesce(o.costo_estimado::text, 'nulo') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-k';
    c := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.tarifa_estimada is null
                   and o.estimado_falta like 'Estimado incompleto: hay 50 h estimadas y falta el escenario C10Z del estimador (o sus tarifas) para valorarlas. No da un total%'
              then 'sin total, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') || ' / ' || coalesce(o.costo_estimado::text, 'nulo') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-l';
    d := case when o.estimado_completo and o.estimado_falta is null and o.material_presupuesto is null
              then format('se compara (%s, diferencia %s)', o.costo_estimado, o.diferencia)
              else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    e := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.horas_estandar = 3
                   and o.estimado_falta = 'No hay estimado: faltan las horas estimadas y el presupuesto de material.'
                   and o.avisos @> array['Sin horas estimadas.', 'Sin presupuesto de material.'] and not (o.avisos @> array[o.estimado_falta])
              then 'sin estimado, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    select format('el total %s; el material %s contra %s; la mano de obra %s, diferencia %s',
                  (select case when x->'estimado' = 'null'::jsonb and x->'diferencia' = 'null'::jsonb and not (x->>'estimado_completo')::boolean
                                    and x->>'nota' like 'Estimado incompleto: no tiene presupuesto de material%' and (x->>'real')::numeric = 300.00
                               then 'sin estimado ni diferencia y con su nota' else x::text end
                     from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'total'),
                  (select coalesce(x->>'estimado', '—') from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'material'),
                  (select x->>'real' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'material'),
                  (select x->>'estimado' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'mano_obra'),
                  (select x->>'diferencia' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'mano_obra'))
      into f;
    perform pg_temp.c10_ser('editor');
    update finanzas_proyecto set presupuesto_materiales = 2000 where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    g := case when o.estimado_completo and o.estimado_falta is null
              then format('%s, diferencia %s, margen estimado %s', o.costo_estimado, o.diferencia, o.margen_estimado)
              else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('sin presupuesto de material y con material en el libro: %s | sin horas estimadas y con horas a estándar: %s | con horas '
                    'estimadas y sin tarifas en su escenario: %s | sin presupuesto de material y sin material en el libro: %s | sin nada '
                    'estimado: %s | el detalle: %s | puesto el presupuesto que faltaba: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, 'UN ESTIMADO PARCIAL NO SE COMPARA CON UN REAL COMPLETO: si falta el presupuesto de material y la obra ya lleva material, o faltan las horas estimadas y ya lleva mano de obra, o hay horas estimadas y su escenario no tiene tarifas, costo_estimado, el margen estimado y la diferencia salen vacíos, estimado_completo es falso y estimado_falta dice qué falta; lo que falta y aún no tiene real no estorba; sin nada, «no hay estimado»; el detalle compara concepto por concepto',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 49. LAS HORAS QUE LLEGAN TARDE a una semana ya repartida. Repartido el
--     pago de la semana, la persona reporta después unas horas de esa misma
--     semana: no recibieron nada (el pago sigue entre las demás obras) y en
--     su obra salen a estándar. Antes todo quedaba en verde. Ahora lo dicen
--     el control (el 35, un aviso), la obra, y la propuesta del pago
--     siguiente (con las fechas que las cogerían). Se arregla repartiéndolas
--     con el pago que las cubra, o deshaciendo y repitiendo aquel reparto.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_j jsonb; o record; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'repartida la semana: el 35 verde | llega un reporte de esa semana: el 35 en rojo, de nivel aviso, lo nombra y dice qué '
                'hacer, sin nombrar funciones; los demás, como estaban | la obra: 6 h a estándar, y lo avisa | el pago siguiente (otra '
                'semana): avisa [sin_horas,horas_tardias], 6 h en 1 reporte, con sus fechas | con sus fechas a mano: h 6→150.00 '
                '[se_pisa] | deshecho y vuelto a repartir el primero: a 8→133.33, b 4→66.67, h 6→100.00, y el 35 verde | o repartidas con '
                'el pago siguiente: el 35 verde, y la obra ya sin horas a estándar';
begin
  if pg_temp.c10_omitir(49, 'las horas que llegan tarde a una semana ya repartida', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(49, 'las horas que llegan tarde a una semana ya repartida', v_esp, 'jornal', array[35]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t49-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9491');
    m2 := pg_temp.c10_cargo('c10-t49-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9492');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(35);
    -- (el sábado de esa semana, reportado después del «Así es»)
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(5), 'c10-prueba-h', 6);
    b := pg_temp.c10_jc(35);
    b := format('%s; %s',
                case when b like 'rojo: Zzana C10 PRUEBA: 6 h en 1 reporte(s) (' || fn_jornal_dia(pg_temp.c10_w1(5)) || ' en C10 PRUEBA Obra H) dentro del reparto del pago del '
                                 || pg_temp.c10_d() || ' → se reportaron o se movieron después de repartir esa semana%Toca «Deshacer» en ese reparto%'
                                 || 'repártelas con él eligiendo sus fechas a mano.'
                          and (select k.nivel from v_jornal_control k where k.orden = 35) = 'aviso' and b !~ 'fn_|v_jornal|v_margen'
                     then 'el 35 en rojo, de nivel aviso, lo nombra y dice qué hacer, sin nombrar funciones' else b end,
                case when (select coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_jornal_control k
                            where not k.ok and k.orden <> 35 and k.orden::text <> all (string_to_array(pg_temp.c10('jc_rojos'), ','))) = ''
                          and split_part(pg_temp.c10_propios(), 'del margen: ', 2) = 'nada nuevo en rojo'
                     then 'los demás, como estaban' else pg_temp.c10_propios() end);
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    perform pg_temp.c10_ser('editor');
    c := format('%s h a estándar, %s', trim_scale(o.horas_estandar),
                case when exists (select 1 from unnest(o.avisos) x
                                   where x like '6 h de esta obra son de una semana ya repartida y no entraron en su reparto (Zzana C10 PRUEBA, pago del '
                                                || fn_jornal_dia(pg_temp.c10_d()) || '): se reportaron o se movieron después. Aquí salen a estándar%')
                     then 'y lo avisa' else 'y NO lo avisa: ' || array_to_string(o.avisos, ' · ') end);
    -- el pago siguiente, por otra semana: no las recoge, y lo dice
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('avisa [%s], %s h en %s reporte, %s', pg_temp.c10_avisos(v_j),
                (select trim_scale((x->>'horas')::numeric) from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias'),
                (select x->>'reportes' from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias'),
                case when (select (x->>'desde')::date = pg_temp.c10_w1(5) and (x->>'hasta')::date = pg_temp.c10_w1(5)
                                  and x->>'texto' like 'Zzana C10 PRUEBA tiene 6 h de una semana ya repartida que no están en ningún reparto%'
                             from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias')
                     then 'con sus fechas' else 'sin sus fechas' end);
    -- con las fechas que las cogen (a mano), entran
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(5), pg_temp.c10_w1(5));
    e := format('%s [%s]', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j));
    -- arreglo 1: deshacer aquel reparto y repetirlo con las horas de hoy
    begin
      perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: llegó un reporte de esa semana');
      f := format('%s, y el 35 %s', pg_temp.c10_lineas(pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6))), pg_temp.c10_jc(35));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- arreglo 2: repartirlas con el pago que las cubre
    perform pg_temp.c10_aplicar(m2, pg_temp.c10_w1(5), pg_temp.c10_w1(5));
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    perform pg_temp.c10_ser('editor');
    g := format('el 35 %s, y la obra %s', pg_temp.c10_jc(35),
                case when o.horas_estandar = 0 and o.mano_obra_jornales = 150.00
                          and not exists (select 1 from unnest(o.avisos) x where x like '%semana ya repartida%')
                     then 'ya sin horas a estándar' else 'con ' || trim_scale(o.horas_estandar) || ' h a estándar' end);
    v_obt := format('repartida la semana: el 35 %s | llega un reporte de esa semana: %s | la obra: %s | el pago siguiente (otra semana): %s | '
                    'con sus fechas a mano: %s | deshecho y vuelto a repartir el primero: %s | o repartidas con el pago siguiente: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (49, 'LAS HORAS QUE LLEGAN TARDE a una semana ya repartida (se reportaron después del «Así es») ya no pasan calladas: el control del jornal lo dice (el 35, un aviso, con la persona, las horas, la obra y el pago), la obra avisa de que esas horas salen a estándar con el pago repartido entre las demás, y la propuesta del pago siguiente las ofrece con sus fechas; se arregla repartiéndolas con ese pago o deshaciendo y repitiendo el primero',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 50. EL PAGO DE UNA PERSONA DADA DE ALTA RESUELTO POR OTRO CAMINO
--     (clasificado a mano en la Bandeja: 5200 entero a una obra). Su costo
--     queda entero ahí, sin su nombre, y sus horas de esas semanas salen
--     además a estándar: la semana cuenta dos veces en el costo con
--     estándar. Antes, todo en verde. Ahora lo dicen el control (el 70, un
--     aviso) y cada obra con horas suyas sin pago; des-casado y repartido
--     por horas, se va.
do $$
declare
  v_obt text; m1 uuid; o record; p record; a text; b text; c text; d text; e text;
  v_esp text := 'en la Bandeja: el 70 verde | clasificado a mano (5200 entero a la obra A): el 70 en rojo, de nivel aviso, nombra el pago, '
                'cómo se resolvió y las 12 h sin pago, y dice qué hacer, sin nombrar funciones | la obra A: subcontratos 300.00, mano de '
                'obra real 0.00, 8 h a estándar (200.00), y lo avisa; la B: 4 h a estándar, y lo avisa | des-casado en la Bandeja: el 70 '
                'verde | repartido por sus horas: A 200.00 y B 100.00 de mano de obra real, sin horas a estándar y sin el aviso';
begin
  if pg_temp.c10_omitir(50, 'el pago de una persona dada de alta resuelto fuera del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(50, 'el pago de una persona dada de alta resuelto fuera del jornal', v_esp, 'jornal', array[70]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t50', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9050');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    perform pg_temp.c10_ser('editor');
    a := pg_temp.c10_jc(70);
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_clasificar(m1, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-a"}]'::jsonb, 'c10-pruebas: clasificado a mano, sin repartir');
    perform pg_temp.c10_ser('editor');
    b := pg_temp.c10_jc(70);
    b := case when b like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA por $300.00 (%clasificado%, asiento %): 12 h suyas sin pago del '
                          || (pg_temp.c10('lunes')::date - 7) || ' al ' || (pg_temp.c10('lunes')::date + 6)
                          || ' → si era su pago por horas, su costo quedó entero donde se clasificó%Des-cásalo en la Bandeja, con su motivo, y repártelo por sus horas.%'
                   and (select k.nivel from v_jornal_control k where k.orden = 70) = 'aviso' and b !~ 'fn_|v_jornal|v_margen'
              then 'el 70 en rojo, de nivel aviso, nombra el pago, cómo se resolvió y las 12 h sin pago, y dice qué hacer, sin nombrar funciones'
              else b end;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    perform pg_temp.c10_ser('editor');
    c := format('la obra A: subcontratos %s, mano de obra real %s, %s h a estándar (%s), %s; la B: %s h a estándar, %s', o.subcontratos_real,
                o.mano_obra_real, trim_scale(o.horas_estandar), o.mano_obra_estandar,
                case when exists (select 1 from unnest(o.avisos) x
                                   where x like '1 pago(s) de mano de obra se resolvieron en la Bandeja sin repartir por horas ($300.00 a Zzana C10 PRUEBA el '
                                                || fn_jornal_dia(pg_temp.c10_d()) || '): si era el pago de esas semanas%Des-cásalo en la Bandeja y repártelo por sus horas.')
                     then 'y lo avisa' else 'y NO lo avisa' end,
                trim_scale(p.horas_estandar),
                case when exists (select 1 from unnest(p.avisos) x where x like '1 pago(s) de mano de obra se resolvieron en la Bandeja sin repartir por horas%')
                     then 'y lo avisa' else 'y NO lo avisa' end);
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(m1, 'c10-pruebas: era su pago por horas');
    perform pg_temp.c10_ser('editor');
    d := pg_temp.c10_jc(70);
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    perform pg_temp.c10_ser('editor');
    e := format('A %s y B %s de mano de obra real, %s', o.mano_obra_real, p.mano_obra_real,
                case when o.horas_estandar = 0 and p.horas_estandar = 0 and o.subcontratos_real = 0
                          and not exists (select 1 from unnest(o.avisos || p.avisos) x where x like '%sin repartir por horas%')
                          and pg_temp.c10_jc(70) = 'verde'
                     then 'sin horas a estándar y sin el aviso' else 'con algo todavía: ' || array_to_string(o.avisos, ' · ') end);
    v_obt := format('en la Bandeja: el 70 %s | clasificado a mano (5200 entero a la obra A): %s | %s | des-casado en la Bandeja: el 70 %s | '
                    'repartido por sus horas: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (50, 'EL PAGO DE UNA PERSONA DADA DE ALTA RESUELTO FUERA DEL JORNAL (clasificado a mano en la Bandeja) ya no pasa callado: el control del jornal lo dice (el 70, un aviso: el pago, cómo se resolvió, las horas suyas sin pago y qué hacer) y cada obra con horas suyas de esas semanas avisa de que salen además a estándar; des-casado y repartido por sus horas, el aviso se va y la mano de obra queda como real en sus obras',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 51. LO DE LA IA (c8) QUE UN JORNAL DEJA ABIERTO. c10 no puede cerrar
--     propuestas de c8 (son de su función de borde); las devuelve, con qué
--     hacer con cada una, para que la pantalla las cierre, y las enseña en
--     su control (el 80, un aviso) mientras sigan abiertas:
--       · la PENDIENTE del movimiento (ya no se puede aprobar: «rechazar»);
--       · la APROBADA cuyo asiento se reversó —Edgar la aceptó y después
--         des-casó el pago para repartirlo por horas— («caducar»): deja en
--         rojo el cuadre 60 de c8, y antes c10 ni la veía.
--     (El «Así es» no se frena por una pendiente: cabecera, «decisiones».)
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_p uuid; v_p2 uuid; v_j jsonb; v_r jsonb; v_c0 text[]; v_c1 text[]; v_c2 text[]; v_c3 text[];
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'pendiente: la propuesta trae 1 abierta (pendiente → rechazar) | aplicar la devuelve, y el 80 lo dice (un aviso, con lo que '
                'proponía y qué hacer, sin nombrar funciones) | para reintentar: 1 | rechazada (lo que hace la pantalla): el 80 verde | '
                'aprobada y des-casada: c8 60 en rojo; la propuesta trae 1 abierta (sin_asiento → caducar) y ninguna pendiente | repartido: '
                'aplicar la devuelve y el 80 lo dice; c8 sigue con el 60 (c10 no lo cierra) | caducada (lo que hace la pantalla): el 80 '
                'verde y c8 sin cuadres nuevos';
begin
  if pg_temp.c10('hay_c8') <> 'true' then
    insert into _pruebas values (51, 'lo de la IA (c8) que un jornal deja abierto se devuelve y se enseña en el control', v_esp,
                                 'omitida: c8 no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(51, 'lo de la IA (c8) que un jornal deja abierto', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(51, 'lo de la IA (c8) que un jornal deja abierto', v_esp, 'jornal', array[80]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-b', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t51-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9511');
    m2 := pg_temp.c10_cargo('c10-t51-2', pg_temp.c10_d(), 100.00, 'Zelle payment to C10 PRUEBA ZZANA 9512');
    perform pg_temp.c10_alta('p1');
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c0;
    -- (a) la propuesta PENDIENTE de la IA para ese Zelle, como la deja su rutina
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into v_p using m1;
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := case when (v_j->>'propuesta_ia')::uuid = v_p and jsonb_array_length(v_j->'propuestas_ia') = 1
              then format('la propuesta trae 1 abierta (%s → %s)', v_j->'propuestas_ia'->0->>'clase', v_j->'propuestas_ia'->0->>'que_hacer')
              else 'la propuesta trae ' || (v_j->'propuestas_ia')::text end;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := pg_temp.c10_jc(80);
    b := format('%s, y %s',
                case when (v_r->>'propuesta_ia')::uuid = v_p and (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p then 'aplicar la devuelve' else 'aplicar NO la devuelve' end,
                case when b like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA ($200.00): su propuesta de la IA sigue pendiente (proponía 5200 → C10 PRUEBA Obra B)'
                                 || ' → ya no se pueden aprobar%a la pendiente se le dice «No es eso»%'
                          and (select k.nivel from v_jornal_control k where k.orden = 80) = 'aviso' and b !~ 'fn_|v_jornal|v_margen|v_contador'
                     then 'el 80 lo dice (un aviso, con lo que proponía y qué hacer, sin nombrar funciones)' else 'el 80: ' || b end);
    perform pg_temp.c10_ser('dueno');
    select count(*)::text into c from fn_jornal_ia(null) i where i.movimiento_id in (m1, m2);
    perform pg_temp.c10_ser('editor');
    -- (lo que hace la pantalla por la función de borde «contador»: «No es eso»)
    execute 'select public.fn_contador_rechazar($1, $2, $3)' using v_p, pg_temp.c10('dueno')::uuid, 'c10-pruebas: se repartió por sus horas';
    d := 'el 80 ' || pg_temp.c10_jc(80);
    -- (b) la APROBADA cuyo asiento se reversa: Edgar acepta la propuesta de la IA y después des-casa el pago para repartirlo
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into v_p2 using m2;
    execute 'select public.fn_contador_aprobar($1, $2, null, false)' using v_p2, pg_temp.c10('dueno')::uuid;
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(m2, 'c10-pruebas: es mano de obra, va por sus horas');
    perform pg_temp.c10_ser('editor');
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c1;
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    e := format('c8 %s en rojo; %s', pg_temp.c10_nuevos(v_c0, v_c1),
                case when v_j->'propuesta_ia' = 'null'::jsonb and jsonb_array_length(v_j->'propuestas_ia') = 1
                          and (v_j->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p2 and v_j->'propuestas_ia'->0->>'estado' = 'aprobada'
                     then format('la propuesta trae 1 abierta (%s → %s) y ninguna pendiente', v_j->'propuestas_ia'->0->>'clase', v_j->'propuestas_ia'->0->>'que_hacer')
                     else 'la propuesta trae ' || (v_j->'propuestas_ia')::text end);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c2;
    f := pg_temp.c10_jc(80);
    f := format('%s; c8 sigue con el %s (c10 no lo cierra)',
                case when (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p2 and v_r->'propuesta_ia' = 'null'::jsonb
                          and f like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA ($100.00): su propuesta de la IA está aprobada y su asiento % ya no vive (proponía 5200 → C10 PRUEBA Obra B)'
                                     || ' → %la aprobada cuyo asiento se reversó se cierra con su motivo%'
                     then 'aplicar la devuelve y el 80 lo dice' else 'el 80: ' || f end,
                pg_temp.c10_nuevos(v_c0, v_c2));
    -- (lo que hace la pantalla: «caducar», con su motivo)
    execute 'select public.fn_contador_caducar($1, $2, $3)' using v_p2, pg_temp.c10('dueno')::uuid, 'c10-pruebas: se repartió por sus horas';
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c3;
    g := format('el 80 %s y c8 %s', pg_temp.c10_jc(80), case when pg_temp.c10_nuevos(v_c0, v_c3) = 'ninguno' then 'sin cuadres nuevos' else 'con ' || pg_temp.c10_nuevos(v_c0, v_c3) end);
    v_obt := format('pendiente: %s | %s | para reintentar: %s | rechazada (lo que hace la pantalla): %s | aprobada y des-casada: %s | repartido: '
                    '%s | caducada (lo que hace la pantalla): %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (51, 'LO DE LA IA (c8) QUE UN JORNAL DEJA ABIERTO: la propuesta pendiente del movimiento y la aprobada cuyo asiento se reversó (des-casado para repartirlo) salen en propuestas_ia —con qué hacer: rechazar o caducar— en la propuesta y en lo que devuelve aplicar, fn_jornal_ia las da para reintentar, y el control del jornal las enseña (el 80, un aviso) hasta que la pantalla las cierra por la función de borde; c10 no escribe en c8',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 52. LA HUELLA CUBRE EXACTAMENTE LO QUE EL «ASÍ ES» APRUEBA. Aplicar manda
--     a c3 TODOS los reportes sin aprobar de esas fechas, también los que no
--     entran porque ya los cubre otro pago. Antes la huella llevaba solo los
--     que entran: una hora cubierta que cambiaba entre que Edgar miraba y
--     tocaba (c3 le quita la aprobación) se aprobaba con horas que él no vio.
--     Ahora la huella lleva cada reporte que se aprueba: MX011, y nada cambia.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; v_r jsonb; a text; b text; c text; d text; e text; v_antes text;
  v_esp text := 'lo que Edgar ve: entran 12 h, 12 h cubiertas, y va a aprobar 2 reportes [horas_cubiertas,se_pisa] | cambia una hora '
                'cubierta (c3 le quita la aprobación) y toca «Así es» con lo que vio: MX011, y nada cambió | lo que ve ahora: va a aprobar '
                '3 —la cubierta que cambió, avisada [horas_cubiertas,cubiertas_sin_aprobar,se_pisa]—, con otra huella | con la de ahora: '
                'entra, aprueba las 3 y queda escrito lo que vio | el reparto que la cubría: el control 30 lo dice';
begin
  if pg_temp.c10_omitir(52, 'la huella cubre lo que el «Así es» aprueba', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 8);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(1), 'c10-prueba-i', 4);
    m1 := pg_temp.c10_cargo('c10-t52-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9521');
    m2 := pg_temp.c10_cargo('c10-t52-2', pg_temp.c10_d(), 360.00, 'Zelle payment to C10 PRUEBA ZZANA 9522');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    -- Edgar mira el segundo pago con las dos semanas (la primera ya la cubre el otro reparto)
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    a := format('entran %s h, %s h cubiertas, y va a aprobar %s reportes [%s]', trim_scale((v_j->>'horas')::numeric),
                trim_scale((v_j->'cubiertas'->>'horas')::numeric),
                case when v_j->'aprueba'->'ids' = '[-1010000004, -1010000003]'::jsonb then v_j->'aprueba'->>'reportes' else (v_j->'aprueba')::text end,
                pg_temp.c10_avisos(v_j));
    select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                  (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                  (select count(*) from horas_aprobaciones where accion = 'aprobada'), (select m.estado from movimientos_banco m where m.id = m2)) into v_antes;
    -- …y entre medias cambia una hora CUBIERTA (del otro reparto): c3 le tumba la aprobación
    perform pg_temp.c10_corregir(1, 'horas = 7');
    v_antes := v_antes || '|' || (select (h.aprobado_el is null)::text from horas h where h.id = -1010000001);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6), v_j->>'visto');
      b := 'entró';
    exception when others then b := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    b := b || case when (select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                                       (select count(*) + 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                                       (select count(*) from horas_aprobaciones where accion = 'aprobada'),
                                       (select m.estado from movimientos_banco m where m.id = m2))
                                || '|' || (select (h.aprobado_el is null)::text from horas h where h.id = -1010000001)) = v_antes
                   then ', y nada cambió' else ', y ALGO cambió' end;
    v_k := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    c := format('va a aprobar %s —%s [%s]—, %s',
                case when v_k->'aprueba'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb then v_k->'aprueba'->>'reportes' else (v_k->'aprueba')::text end,
                case when (select x->'horas_ids' = '[-1010000001]'::jsonb and x->>'texto' like '1 reporte(s) de esas fechas que no entran en este reparto están sin aprobar%Al aceptar quedan aprobados como están hoy.%'
                             from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'cubiertas_sin_aprobar')
                     then 'la cubierta que cambió, avisada' else 'sin avisar de la cubierta' end,
                pg_temp.c10_avisos(v_k),
                case when v_k->>'visto' <> v_j->>'visto' then 'con otra huella' else 'con la MISMA huella' end);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    d := format('%s, aprueba las %s y %s', case when v_r->>'estado' = 'aplicado' and (v_r->>'horas')::numeric = 12 then 'entra' else 'no entra' end,
                case when v_r->'horas_aprobadas'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb then v_r->'horas_aprobadas'->>'reportes' else (v_r->'horas_aprobadas')::text end,
                case when (select ap.horas = 7 and ap.detalle->'visto'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb
                             from horas_aprobaciones ap where ap.horas_id = -1010000001 and ap.accion = 'aprobada' order by ap.hecho_el desc limit 1)
                     then 'queda escrito lo que vio' else 'NO queda escrito lo que vio' end);
    e := pg_temp.c10_jc(30);
    e := case when e like 'rojo: %el reporte -1010000001 del ' || pg_temp.c10_w2(0) || ' cambió de horas (de 8 a 7)%' then 'el control 30 lo dice' else e end;
    v_obt := format('lo que Edgar ve: %s | cambia una hora cubierta (c3 le quita la aprobación) y toca «Así es» con lo que vio: %s | lo que ve '
                    'ahora: %s | con la de ahora: %s | el reparto que la cubría: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (52, 'LA HUELLA CUBRE EXACTAMENTE LO QUE EL «ASÍ ES» APRUEBA: lleva cada reporte de esas fechas que se va a aprobar, entre o no en el reparto («aprueba»); si una hora que ya cubre otro pago cambia entre que Edgar mira y toca (c3 le quita la aprobación), aplicar da MX011 y nada cambia —antes la aprobaba con horas que él no vio—; al volver a mirar la ve avisada (cubiertas_sin_aprobar) y entonces sí',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 53. EL CO Y LA FASE, LIMPIOS COMO LOS DEJA c6. Un CO con un salto de línea
--     detrás (un pegado, el conector) o que es solo un tabulador: c6 limpia
--     tabuladores y saltos al postear, y c10 quitaba solo espacios: el mismo
--     CO salía en dos grupos, el asiento «no era el reparto» y el pago no se
--     podía repartir (MX001 «la línea 3… Avisa»). Ahora van limpios igual en
--     el núcleo, la propuesta, la huella, el margen y el control; lo que solo
--     cambia por las mayúsculas se avisa (co_parecidos) y no se adivina; y si
--     el asiento de c6 no fuera el reparto, el error dice qué línea, qué
--     campo y qué hacer.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'tres grupos: base 2→50.00, CO #1 6→150.00, co #1 2→50.00 [co_parecidos], y se puede aplicar | el aviso nombra los dos CO '
                'parecidos | aplicado: 4 líneas, el CO sin saltos ni tabuladores; el detalle guarda «CO #1» y la fase «rough»; control del '
                'jornal: nada nuevo en rojo; del margen: nada nuevo en rojo | el margen por CO: Base (sin CO) 2 h, CO #1 6 h, co #1 2 h | si el '
                'asiento del banco no fuera el reparto: MX001, dice la línea, el campo y qué hacer, y nada cambia';
begin
  if pg_temp.c10_omitir(53, 'el CO y la fase, limpios como los deja c6', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 4, E'CO #1\n', E'rough\n');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 1, E'\t');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-a', 1);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), 'c10-prueba-a', 2, E' co #1\r\n');
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 2, 'CO #9');
    m1 := pg_temp.c10_cargo('c10-t53-1', pg_temp.c10_d(), 250.00, 'Zelle payment to C10 PRUEBA ZZANA 9531');
    m2 := pg_temp.c10_cargo('c10-t53-2', pg_temp.c10_d(), 50.00, 'Zelle payment to C10 PRUEBA ZZANA 9532');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    -- (los grupos, la base primero y los CO por su letra: el orden de dos CO que solo cambian en las mayúsculas depende
    -- de la intercalación de la base, y aquí no importa)
    select format('%s grupos: %s [%s], y %s', case jsonb_array_length(v_j->'lineas') when 3 then 'tres' else jsonb_array_length(v_j->'lineas')::text end,
                  string_agg(format('%s %s→%s', coalesce(l->>'co', 'base'), trim_scale((l->>'horas')::numeric), l->>'monto'), ', '
                             order by (l->>'co' is null) desc, (l->>'co') collate "C"),
                  pg_temp.c10_avisos(v_j), case when (v_j->>'puede_aplicar')::boolean then 'se puede aplicar' else 'NO se puede: ' || (v_j->>'por_que') end)
      into a from jsonb_array_elements(v_j->'lineas') l;
    b := case when pg_temp.c10_aviso(v_j, 'co_parecidos') ~ '^Hay CO escritos de dos formas en la misma obra \(C10 PRUEBA Obra A: («CO #1» y «co #1»|«co #1» y «CO #1»)\): salen como líneas distintas\.'
              then 'el aviso nombra los dos CO parecidos' else coalesce(pg_temp.c10_aviso(v_j, 'co_parecidos'), 'sin aviso') end;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s líneas, el CO %s; el detalle guarda «%s» y la fase «%s»; %s', count(*),
                  case when bool_and(l.co is not distinct from fn_jornal_limpio(l.co)) and count(*) filter (where l.co = 'CO #1') = 1
                            and count(*) filter (where l.co = 'co #1') = 1 and count(*) filter (where l.co is null) = 2
                       then 'sin saltos ni tabuladores' else 'CON algo raro' end,
                  (select rh.co from jornal_reparto_horas rh where rh.reparto_id = (v_r->>'reparto_id')::uuid and rh.horas_id = -1010000001),
                  (select rh.fase from jornal_reparto_horas rh where rh.reparto_id = (v_r->>'reparto_id')::uuid and rh.horas_id = -1010000001),
                  pg_temp.c10_propios())
      into c from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid;
    perform pg_temp.c10_ser('dueno');
    v_k := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s h', x->>'etiqueta', trim_scale((x->>'horas')::numeric)), ', ' order by (x->>'co' is null) desc, (x->>'co') collate "C")
      into d from jsonb_array_elements(v_k->'por_co') x;
    -- LA RED: si c6 dejara otra cosa en la línea (aquí, un trigger de prueba le cambia el CO al entrar), el error lo dice
    begin
      create function public.c10_prueba_altera() returns trigger language plpgsql as $f$
      begin
        if new.co = 'CO #9' then new.co := 'CO #9 (cambiado)'; end if;
        return new;
      end $f$;
      create trigger zzz_c10_prueba_altera before insert on public.asiento_lineas for each row execute function public.c10_prueba_altera();
      begin
        perform pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
        e := 'entró';
      exception when others then
        e := sqlstate || case when sqlerrm like 'El asiento % que dejó el banco no es el reparto que se le pidió: la línea 2 (C10 PRUEBA Obra B): el CO quedó ''CO #9 (cambiado)'' y se pidió ''CO #9''. '
                                                || 'No se guardó nada%el pago sigue en la Bandeja%corrígelos en Horas y vuelve a mirar el reparto; si no, avisa con este mensaje.'
                              then ', dice la línea, el campo y qué hacer' else ' (' || sqlerrm || ')' end;
      end;
      perform pg_temp.c10_ser('editor');
      f := case when (select m.estado from movimientos_banco m where m.id = m2) = 'pendiente'
                     and (select h.aprobado_el is null from horas h where h.id = -1010000006)
                     and not exists (select 1 from jornal_repartos r where r.movimiento_id = m2)
                     and not exists (select 1 from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = m2::text)
                then 'y nada cambia' else 'y ALGO cambió' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('%s | %s | aplicado: %s | el margen por CO: %s | si el asiento del banco no fuera el reparto: %s, %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (53, 'EL CO Y LA FASE VAN LIMPIOS COMO LOS DEJA c6 (sin espacios, tabuladores ni saltos de línea en las puntas): un CO con un salto de línea detrás es el mismo CO —un grupo, una línea— y uno que es solo un tabulador es la base; el pago se reparte (antes paraba con MX001 «Avisa»); dos CO que solo cambian en las mayúsculas se avisan (co_parecidos) y no se juntan; y si el asiento del banco no fuera el reparto, el MX001 dice qué línea, qué campo y qué hacer, y nada cambia',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 54. EL DEVENGO DE UN MES Y EL JORNAL DEL SIGUIENTE NO CHOCAN (el uso de
--     manual de fn_horas_devengar, c3): un mes devengado por lo trabajado y
--     todavía no pagado (Dr 5000 / Cr 2210 a fin de mes, con su reverso del
--     día 1) y su Zelle pagado al mes siguiente. El libro: el devengo en su
--     mes; al siguiente, su reverso y el pago real: nada dos veces. Antes el
--     control 50 lo ponía en rojo (miraba el mes de las HORAS contra el del
--     devengo, y daba por vivo un devengo ya deshecho) y no tenía vuelta, y
--     la propuesta avisaba «saldría dos veces». (El doble de verdad —el pago
--     que entra en el mismo mes— lo prueba la 39; y lo que pasa con él al
--     cerrar el mes, la 55.)
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_m0 date; v_fin date; v_mes text; v_mes1 text; v_dev jsonb; v_no text; a text; b text; c text;
  v_c0 text; v_c1 text;
  v_esp text;
begin
  if pg_temp.c10_omitir(54, 'el devengo de un mes y el jornal del siguiente no chocan', 'ni la propuesta avisa ni el control 50 se pone en rojo') then return; end if;
  if pg_temp.c10_omitir_rojo(54, 'el devengo de un mes y el jornal del siguiente no chocan', 'ni la propuesta avisa ni el control 50 se pone en rojo', 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (el último día del mes anterior al del pago: trabajado ese mes, pagado en el siguiente)
    v_m0 := date_trunc('month', pg_temp.c10_d())::date;
    v_fin := v_m0 - 1;
    v_mes := to_char(v_fin, 'YYYY-MM');
    v_mes1 := to_char(v_m0, 'YYYY-MM');
    v_esp := format('la propuesta del pago no avisa del devengo | aplicado: el asiento cae en %s, y el control 50 no cuenta ese jornal | el libro de la obra: '
                    '%s 5000 200.00 · %s 5000 -200.00 · %s 5200 200.00: nada dos veces', v_mes1, v_mes, v_mes1, v_mes1);
    perform pg_temp.c10_hora(1, 'p1', v_fin, 'c10-prueba-a', 8);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, v_fin, v_fin, '{"ids": [-1010000001]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := fn_horas_devengar(v_mes);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is null then
      -- (el devengo de c3 se lleva TODAS las horas aprobadas del mes: en una
      --  base con jornales de verdad pagados dentro de ese mes, ESE devengo de
      --  prueba ya es un doble de verdad para ellos y el 50 sale en rojo por
      --  ellos, no por el de aquí. Por eso se mira que el jornal del mes
      --  siguiente NO MUEVA el control: verde, o igual que antes de aplicarlo
      --  —el detalle lleva las horas, los reportes y los jornales contados—.)
      v_c0 := pg_temp.c10_jc(50);
      v_mov := pg_temp.c10_cargo('c10-t54', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9054');
      perform pg_temp.c10_alta('p1');
      v_j := pg_temp.c10_propuesta(v_mov, v_fin, v_fin);
      a := case when pg_temp.c10_aviso(v_j, 'devengo_estandar') is null and (v_j->>'puede_aplicar')::boolean and (v_j->>'horas')::numeric = 8
                then 'la propuesta del pago no avisa del devengo' else 'la propuesta avisa: ' || coalesce(pg_temp.c10_aviso(v_j, 'devengo_estandar'), v_j->>'por_que') end;
      v_r := pg_temp.c10_aplicar(v_mov, v_fin, v_fin);
      v_c1 := pg_temp.c10_jc(50);
      b := format('el asiento cae en %s, y el control 50 %s', v_r->'asiento'->>'periodo',
                  case when v_c1 = 'verde' or v_c1 = v_c0 then 'no cuenta ese jornal' else v_c1 end);
      select string_agg(format('%s %s %s', q.periodo, q.cuenta, q.s), ' · ' order by q.periodo, q.cuenta) into c
        from (select x.periodo, l.cuenta, sum(l.monto) as s
                from asiento_lineas l join asientos x on x.id = l.asiento_id
               where l.proyecto_id = 'c10-prueba-a' and l.cuenta in ('5000', '5200')
               group by x.periodo, l.cuenta) q;
      v_obt := format('%s | aplicado: %s | el libro de la obra: %s: nada dos veces', a, b, c);
    else
      v_obt := format('omitida: c3 no dejó devengar %s (%s)', v_mes, left(v_no, 300));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (54, 'EL DEVENGO DE UN MES Y EL JORNAL DEL SIGUIENTE NO CHOCAN: un mes devengado por lo trabajado y todavía no pagado (fn_horas_devengar, c3) y su Zelle pagado al mes siguiente: la propuesta no avisa de doble y el control 50 no cuenta ese jornal: sigue en verde (el mes lleva el devengo; el siguiente, su reverso y el pago real). Antes salía en rojo, sin vuelta',
    coalesce(v_esp, '-'), v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 55. EL DOBLE DE VERDAD, Y LO QUE PASA AL CERRAR EL MES. Un pago que entra
--     al libro en un mes y el devengo de ese mismo mes con esas horas: el 50
--     en rojo mientras el mes está abierto (se puede arreglar: retirar el
--     devengo antes de cerrar). Si el mes se cierra así, ya no tiene arreglo
--     en ese mes —el siguiente lo compensa con el reverso del devengo—: el
--     control lo deja dicho y NO se queda en rojo para siempre (con el cierre
--     de c9 mirándolo sería un «detiene» sin salida). Cierra, dentro de la
--     prueba, la apertura y el mes abierto más viejo que ya terminó, como la
--     27; si el libro real no deja, sale «omitida» con lo que dijo c2.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_mes periodos; v_ap periodos; v_dev jsonb; v_no text; a text; b text;
  v_esp text := 'pagado y devengado en el mismo mes, abierto: el 50 en rojo (la misma hora en el devengo y en el jornal de ese mes) | '
                'cerrado ese mes: el 50 verde, y lo deja dicho (ya cerrado, sin arreglo: el mes siguiente lo compensa)';
begin
  if pg_temp.c10_omitir(55, 'el doble de verdad, y al cerrar el mes', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(55, 'el doble de verdad, y al cerrar el mes', v_esp, 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    lock table periodos in exclusive mode;
    select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
    if v_mes.periodo is null then
      v_no := 'no hay un mes terminado y todavía abierto donde pagar, devengar y cerrar';
    else
      perform pg_temp.c10_sembrar();
      -- (trabajado y PAGADO dentro de ese mes: el pago, su último día)
      perform pg_temp.c10_hora(1, 'p1', v_mes.hasta - 2, 'c10-prueba-a', 8);
      v_mov := pg_temp.c10_cargo('c10-t55', v_mes.hasta, 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9055');
      perform pg_temp.c10_alta('p1');
      v_r := pg_temp.c10_aplicar(v_mov, v_mes.hasta - 2, v_mes.hasta - 2);
      begin
        v_dev := fn_horas_devengar(v_mes.periodo);
      exception when others then v_no := format('c3 no dejó devengar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null then
      a := pg_temp.c10_jc(50);
      a := case when a like 'rojo: %' || v_mes.periodo || ': el devengo ' || (v_dev->>'asiento') || ' cuenta % h (% reporte(s)) que ya tienen su pago real en ese mes, en % jornal(es)%'
                                || '→ esa mano de obra sale dos veces en ese mes%'
                then 'el 50 en rojo (la misma hora en el devengo y en el jornal de ese mes)' else 'el 50: ' || a end;
      begin
        select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
        if v_ap.estado = 'abierto' then
          if not exists (select 1 from asientos x where x.periodo = v_ap.periodo and x.tipo = 'apertura' and x.reversa_a is null
                            and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
            perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
              'descripcion', 'C10 PRUEBA: apertura de prueba (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
          end if;
          perform fn_cerrar_periodo(v_ap.periodo);
        end if;
        perform fn_cerrar_periodo(v_mes.periodo);
      exception when others then
        v_no := format('c2 no dejó cerrar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null then
      b := case when (select k.ok and k.detalle like 'Ninguna hora está a la vez en el devengo estándar de un mes abierto y en un jornal que entró al libro ese mes.%'
                                     || '(Ya cerrado, sin arreglo: ' || v_mes.periodo || ': el devengo ' || (v_dev->>'asiento') || ' cuenta %'
                                     || 'ese mes quedó con esa mano de obra dos veces y el siguiente con ella de menos, por el reverso del devengo.)'
                        from v_jornal_control k where k.orden = 50)
                then 'el 50 verde, y lo deja dicho (ya cerrado, sin arreglo: el mes siguiente lo compensa)' else 'el 50: ' || pg_temp.c10_jc(50) || ' / ' || (select k.detalle from v_jornal_control k where k.orden = 50) end;
      v_obt := format('pagado y devengado en el mismo mes, abierto: %s | cerrado ese mes: %s', a, b);
    else
      v_obt := 'omitida: ' || v_no;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (55, 'EL DOBLE DE VERDAD (el pago y el devengo estándar de las mismas horas en el mismo mes) pone el control 50 en rojo mientras ese mes está abierto y se puede arreglar; si el mes se cierra así, el control lo deja dicho y no se queda en rojo para siempre (el mes siguiente lo compensa con el reverso del devengo)',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 56. EL RECONOCIMIENTO POR PATRÓN, Y LA CUENTA DE LO SIN OBRA. Un patrón no
--     sabe qué clase de movimiento mira ni de quién es: la compra en un
--     comercio cuyo nombre lleva el de alguien casa igual que su Zelle, y el
--     patrón de una persona puesto en el perfil de otra reconocía sus pagos a
--     nombre de la otra, sin decir nada. No se frena (un banco puede
--     describir un pago de otra forma, y la app el nombre de pila): se DICE,
--     al dar de alta y en la propuesta. Y un patrón que casaría con un Zelle
--     a cualquiera no entra. La cuenta de lo sin obra, además, ya no es
--     «cualquier gasto».
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; v_sin text; a text; b text; c text; d text; e text; x1 text; x2 text; x3 text; x4 text;
  v_esp text;
begin
  if pg_temp.c10_omitir(56, 'el reconocimiento por patrón, y la cuenta de lo sin obra', 'los avisos del patrón y las cuentas que no sirven') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('«un Zelle a quien sea» no vale, y lo dice; con su nombre, sí | al dar de alta: avisa de que casa con pagos descritos de 2 '
                    'formas (el Zelle y la compra en el comercio), y lo pone en la nota | la compra en el comercio: reconocida, con su aviso '
                    '[no_parece_pago]; el Zelle, sin él | un patrón sin el nombre de pila del perfil: avisa y entra | lo sin obra: 6010 MX004 '
                    '(la alimenta otra parte del libro), 6950 MX004, 7920 MX004, %s entra', v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t56-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9561');
    m2 := pg_temp.c10_cargo('c10-t56-2', pg_temp.c10_d(), 88.40, 'POS PURCHASE C10 PRUEBA ZZANA SUPPLY 0042');
    perform pg_temp.c10_ser('dueno');
    a := format('%s; %s',
                case when fn_jornal_patron_mal('ZELLE PAYMENT TO [A-Z]') like '%casaría con cualquier pago (también con «ZELLE PAYMENT TO otra persona»)%'
                          and fn_jornal_patron_mal('ZELLE.*') is not null and fn_jornal_patron_mal('\mTO\M \w+') is not null
                     then '«un Zelle a quien sea» no vale, y lo dice' else coalesce(fn_jornal_patron_mal('ZELLE PAYMENT TO [A-Z]'), 'VALE') end,
                case when fn_jornal_patron_mal('\mPRUEBA ZZANA\M') is null then 'con su nombre, sí' else 'con su nombre NO' end);
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'patron', '\mPRUEBA ZZANA\M'));
    b := case when jsonb_array_length(v_j->'avisos') = 1
                   and v_j->'avisos'->>0 like 'El patrón casa con pagos que el banco describe de 2 formas distintas («POS PURCHASE PRUEBA ZZANA», «PRUEBA ZZANA»): mira que todos sean suyos%'
                   -- (en un LIKE la barra invertida es el escape: va doble)
                   and v_j->>'nota_alta' like 'Zzana C10 PRUEBA: 2 pago(s) pendientes reconocidos con «\\mPRUEBA ZZANA\\M». Ojo: El patrón casa con pagos%'
              then 'avisa de que casa con pagos descritos de 2 formas (el Zelle y la compra en el comercio), y lo pone en la nota'
              else coalesce((v_j->'avisos')::text, 'sin avisos') end;
    v_k := fn_jornal_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := format('%s; el Zelle, %s',
                case when (v_k->>'reconocido')::boolean
                          and (select x->>'texto' from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'no_parece_pago')
                              like 'El banco no lo describe como un pago a una persona (un Zelle, una transferencia, un cheque): «POS PURCHASE C10 PRUEBA ZZANA SUPPLY 0042».%clasifícalo en la Bandeja como siempre.'
                     then 'reconocida, con su aviso [no_parece_pago]' else 'sin su aviso: ' || pg_temp.c10_avisos(v_k) end,
                case when pg_temp.c10_aviso(fn_jornal_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6)), 'no_parece_pago') is null then 'sin él' else 'CON él' end);
    -- (el patrón de «otra» persona en el perfil de Zzcaro: su nombre de pila no sale en él)
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p3'), 'patron', '\mPRUEBA ZZOTRA\M'));
    d := case when v_j->'avisos'->>0 = 'El patrón «\mPRUEBA ZZOTRA\M» no lleva el nombre de Zzcaro C10 PRUEBA («ZZCARO»): mira que sea el de sus pagos y no el de otra persona.'
                   and (v_j->>'activa')::boolean and v_j->>'nota_alta' like '% Ojo: El patrón «\\mPRUEBA ZZOTRA\\M» no lleva el nombre de Zzcaro C10 PRUEBA%'
              then 'avisa y entra' else coalesce((v_j->'avisos')::text, 'sin avisos') end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6010"}'); x1 := 'entra';
    exception when others then x1 := sqlstate || case when sqlerrm like '%la alimenta otra parte del libro%' then ' (la alimenta otra parte del libro)' else '' end; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6950"}'); x2 := 'entra'; exception when others then x2 := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "7920"}'); x3 := 'entra'; exception when others then x3 := sqlstate; end;
    begin
      x4 := case when fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin))->>'cuenta_sin_obra' = v_sin then v_sin || ' entra' else 'no quedó' end;
    exception when others then x4 := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    -- (si el plan de cuentas de esta base no trae la 6010, el porqué es otro —«no existe»— y sigue sin entrar)
    if not exists (select 1 from cuentas k where k.codigo = '6010') and x1 = 'MX004' then x1 := 'MX004 (la alimenta otra parte del libro)'; end if;
    e := format('6010 %s, 6950 %s, 7920 %s, %s', x1, x2, x3, x4);
    v_obt := format('%s | al dar de alta: %s | la compra en el comercio: %s | un patrón sin el nombre de pila del perfil: %s | lo sin obra: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (56, 'EL RECONOCIMIENTO POR PATRÓN SE AVISA, NO SE ADIVINA: un patrón que casaría con un Zelle a cualquiera no entra; al dar de alta se dice si el patrón casa con pagos que el banco describe de varias formas (un comercio con un nombre parecido) o si no lleva el nombre de pila del perfil; y la propuesta avisa si el movimiento no parece un pago a una persona. La cuenta de lo sin obra no admite las que alimenta otra parte del libro ni las de etiqueta fiscal propia',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 57. LO MENOR, DICHO: el corte de mes y de año (las horas de un mes y el
--     asiento en otro: el libro va por la fecha del pago, como QuickBooks, y
--     se avisa con cuántas horas, cuánto y cuándo entra); la nota de aplicar
--     no cuenta las obras a las que no les llegó ni un centavo; el núcleo
--     reparte también solo por las horas APROBADAS (lo que pedirá f11); la
--     nota del estándar dice que va con la tarifa de hoy; el control dice
--     dónde salen los jornales en «Estados»; y ningún detalle de los dos
--     controles nombra una función ni una vista.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; v_k jsonb; v_m0 date; v_fin date; v_ano date; v_cod text; a text; b text; c text; d text; e text;
  v_esp text := 'las horas del mes anterior: avisa (8 h, 200.00, con el día en que entra el asiento) | las de otro año: avisa (4 h, 250.00, '
                'y el ejercicio en que queda) | un pago de 2 centavos entre tres obras: la nota cuenta 2 obras y dice que a 1 grupo no le '
                'llegó nada | el núcleo: 4 reportes con todas las horas y 3 con solo las aprobadas, y los dos suman 100.00 | la nota del '
                'estándar dice que va con la tarifa de hoy; el control dice dónde salen los jornales en Estados; y ningún detalle nombra '
                'una función ni una vista';
begin
  if pg_temp.c10_omitir(57, 'el corte de mes y de año, la nota de aplicar, el núcleo con las aprobadas y los textos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_m0 := date_trunc('month', pg_temp.c10_d())::date;
    v_fin := v_m0 - 1;                                           -- el último día del mes anterior al del pago
    v_ano := date_trunc('year', pg_temp.c10_d())::date - 1;      -- el 31 de diciembre del año anterior
    perform pg_temp.c10_hora(1, 'p1', v_fin, 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', v_m0, 'c10-prueba-b', 2);
    perform pg_temp.c10_hora(3, 'p1', v_ano, 'c10-prueba-h', 4);
    m1 := pg_temp.c10_cargo('c10-t57-1', pg_temp.c10_d(), 250.00, 'Zelle payment to C10 PRUEBA ZZANA 9571');
    perform pg_temp.c10_alta('p1');
    -- (a) el mes: 8 h del mes anterior y 2 h del mes del pago
    v_j := pg_temp.c10_propuesta(m1, v_fin, v_m0);
    v_cod := case when extract(year from v_fin) <> extract(year from pg_temp.c10_d()) then 'otro_anio' else 'otro_mes' end;
    select case when (x->>'horas')::numeric = 8 and (x->>'monto')::numeric = 200.00 and (x->>'fecha_asiento')::date = pg_temp.c10_d()
                     and x->>'texto' like '8 h de este pago ($200.00) se trabajaron en % y el asiento entra el ' || fn_jornal_dia(pg_temp.c10_d(), true) || ': su costo queda en %(el libro va por la fecha del pago, como QuickBooks)%Es solo un aviso.'
                     and (v_j->>'puede_aplicar')::boolean and (v_j->'movimiento'->>'fecha_asiento')::date = pg_temp.c10_d()
                then 'avisa (8 h, 200.00, con el día en que entra el asiento)' else x::text end
      into a from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = v_cod;
    -- (b) el año: una hora del 31 de diciembre del año anterior. La propuesta no deja más de 62 días hacia atrás; el
    --     cálculo es el mismo y aquí se le pide directo, como el dueño, con ese solo día.
    perform pg_temp.c10_ser('dueno');
    v_k := fn_jornal_calcular(m1, v_ano, v_ano, '{}'::jsonb);
    perform pg_temp.c10_ser('editor');
    select case when (x->>'horas')::numeric = 4 and (x->>'monto')::numeric = 250.00
                     and x->>'texto' like '4 h de este pago ($250.00) se trabajaron en ' || to_char(v_ano, 'YYYY') || ' y el asiento entra el ' || fn_jornal_dia(pg_temp.c10_d(), true)
                                          || ': su costo queda en el ejercicio ' || to_char(pg_temp.c10_d(), 'YYYY') || ' %Si el CPA quiere ese costo en el año en que se trabajó%'
                then 'avisa (4 h, 250.00, y el ejercicio en que queda)' else x::text end
      into b from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'otro_anio';
    -- (c) un pago de 2 centavos entre tres obras: a una no le llega nada
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w1(0), 'c10-prueba-a', 1);
    perform pg_temp.c10_hora(5, 'p2', pg_temp.c10_w1(0), 'c10-prueba-b', 1);
    perform pg_temp.c10_hora(6, 'p2', pg_temp.c10_w1(0), 'c10-prueba-h', 1);
    m2 := pg_temp.c10_cargo('c10-t57-2', pg_temp.c10_d(), 0.02, 'Zelle payment to C10 PRUEBA ZZBETO 9572');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := case when v_r->>'nota' like 'Repartido: $0.02 de Zzbeto C10 PRUEBA (%, 3 h) entre 2 obra(s); asiento %. A 1 grupo(s) de horas no les llegó ni un centavo (el pago es muy chico): no llevan línea. Quedaron aprobados 3 reporte(s) de horas.'
                   and (select count(*) from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid) = 3
              then 'la nota cuenta 2 obras y dice que a 1 grupo no le llegó nada' else v_r->>'nota' end;
    -- (d) el núcleo, con todas las horas y con solo las aprobadas (las tres de arriba ya lo están; la cuarta, no)
    perform pg_temp.c10_hora(7, 'p2', pg_temp.c10_w1(1), 'c10-prueba-i', 2);
    perform pg_temp.c10_ser('dueno');
    select format('%s reportes con todas las horas y %s con solo las aprobadas, y los dos suman %s',
                  (select count(*) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00)),
                  (select count(*) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true)),
                  case when (select sum(r.monto) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r) = 100.00
                            and (select sum(r.monto) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true) r) = 100.00
                            and not exists (select 1 from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true) r
                                             where r.proyecto_id = 'c10-prueba-i')
                       then '100.00' else 'otra cosa' end)
      into d;
    -- (e) los textos
    v_k := fn_margen_obra('c10-prueba-i');
    select format('%s; %s; y %s',
                  case when (select x->>'nota' from jsonb_array_elements(v_k->'conceptos') x where x->>'concepto' = 'mano_obra_estandar')
                            like '%con la tarifa y el burden de hoy (si cambian, este número cambia). No está en el libro.'
                         or (select x->>'nota' from jsonb_array_elements(v_k->'conceptos') x where x->>'concepto' = 'mano_obra_estandar') like 'Falta %'
                       then 'la nota del estándar dice que va con la tarifa de hoy' else 'la nota del estándar NO lo dice' end,
                  case when to_regclass('public.v_costo_por_obra') is null
                         or (select not k.ok or k.detalle like '%en «Estados» salen dentro de «Subcontratos» y aquí como mano de obra real; el total de cada obra es el mismo.' from v_margen_control k where k.orden = 60)
                       then 'el control dice dónde salen los jornales en Estados' else 'el control NO dice dónde salen los jornales' end,
                  case when not exists (select 1 from (select k.detalle from v_jornal_control k union all select k.detalle from v_margen_control k) z
                                         where z.detalle ~ '\m(fn_[a-z_]+|v_(jornal|margen|costo|contador)_[a-z_]+)\M')
                       then 'ningún detalle nombra una función ni una vista'
                       else 'algún detalle nombra una función o una vista: ' || (select string_agg(left(z.detalle, 120), ' · ')
                                                                                     from (select k.detalle from v_jornal_control k union all select k.detalle from v_margen_control k) z
                                                                                    where z.detalle ~ '\m(fn_[a-z_]+|v_(jornal|margen|costo|contador)_[a-z_]+)\M') end)
      into e;
    perform pg_temp.c10_ser('editor');
    v_obt := format('las horas del mes anterior: %s | las de otro año: %s | un pago de 2 centavos entre tres obras: %s | el núcleo: %s | %s',
                    coalesce(a, 'sin aviso [' || pg_temp.c10_avisos_todos(v_j) || ']'), coalesce(b, 'sin aviso'), c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (57, 'LO MENOR, DICHO: las horas de otro mes —o de otro año— que el asiento (que entra el día del pago) se avisan con cuántas horas, cuánto y cuándo entra (otro_mes, otro_anio); la nota de aplicar no cuenta las obras a las que no les llegó ni un centavo; el núcleo reparte también por solo las horas aprobadas (lo que pedirá f11); la nota del estándar dice que va con la tarifa de hoy; el control dice dónde salen los jornales en «Estados»; y ningún detalle de los controles nombra una función ni una vista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL CIERRE DE LA SUITE
-- ---------------------------------------------------------------------
-- 58. Nada queda: lo que c10 toca (y lo que sus pruebas sembraron) está
--     como antes de la primera prueba.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c10_ser('editor');
    v_obt := case when pg_temp.c10_conteos() = pg_temp.c10('conteos') then 'igual que antes' else 'antes: ' || pg_temp.c10('conteos') || ' · ahora: ' || pg_temp.c10_conteos() end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (58, 'nada queda de las pruebas: la configuración, las personas, los repartos, los asientos, los movimientos y archivos del banco, las horas y sus aprobaciones, los perfiles y usuarios, las tarifas, las obras, los escenarios, los estimados, los períodos cerrados y las funciones, como antes',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 59. Con jornales aplicados, deshechos y vueltos a aplicar, NINGÚN control
--     de las otras capas pasa a rojo: la cadena y «permisos» de c2, los
--     puentes (c3), el banco (c6), los estados (c4), los cuadres de la IA
--     (c8, si está) y lo que detiene el cierre del mes (c9, si está). Se
--     compara con cómo estaban con el pago ya en la Bandeja (lo que ya
--     estaba en rojo se dice, y no cuenta).
do $$
declare
  v_obt text; v_mov uuid; m2 uuid; v_r jsonb; s0 text[]; s1 text[]; s2 text[]; s3 text[]; s4 text[]; v_antes text := '';
  v_esp text := 'al aplicar: ninguno | al deshacer: ninguno | al volver a aplicar con otras fechas: ninguno | con otro pago de las mismas '
                'horas: ninguno';
begin
  if pg_temp.c10_omitir(59, 'ningún control de las otras capas pasa a rojo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-c', 2);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 5);
    v_mov := pg_temp.c10_cargo('c10-t59-1', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9591');
    m2 := pg_temp.c10_cargo('c10-t59-2', pg_temp.c10_d(), 125.00, 'Zelle payment to C10 PRUEBA ZZANA 9592');
    perform pg_temp.c10_alta('p1');
    s0 := pg_temp.c10_rojos();
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    s1 := pg_temp.c10_rojos();
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: no era esa semana');
    s2 := pg_temp.c10_rojos();
    perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    s3 := pg_temp.c10_rojos();
    perform pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6), '{"incluir_cubiertas": true}');
    s4 := pg_temp.c10_rojos();
    v_obt := format('al aplicar: %s | al deshacer: %s | al volver a aplicar con otras fechas: %s | con otro pago de las mismas horas: %s',
                    pg_temp.c10_nuevos(s0, s1), pg_temp.c10_nuevos(s0, s2), pg_temp.c10_nuevos(s0, s3), pg_temp.c10_nuevos(s0, s4));
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (59, 'con jornales aplicados, deshechos, vueltos a aplicar y un segundo pago de las mismas horas, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3), el banco (c6), los estados (c4), los cuadres de la IA (c8) y lo que detiene el cierre del mes (c9)',
    v_esp, v_obt || case when v_antes <> '' then ' (ya en rojo antes, con el pago en la Bandeja: ' || v_antes || ')' else '' end, v_obt = v_esp);
end $$;

-- 60. El cierre de la suite: c2 (la cadena y «permisos»), c3, c6 y c4 como
--     estaban con c10 pegado (lo que ya estaba en rojo antes se dice y no
--     cuenta), c8 sin cuadres rojos, nada de c10 para anon o service_role ni
--     SECURITY DEFINER; y fn_jornal_pegado responde con sus nueve filas y la
--     configuración sigue siendo UNA (pegar dos veces no la pisa: lo corre
--     el banco, con dos pegados seguidos antes de esta suite).
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_c8 text; v_api text; v_n int; v_cfg int;
  v_esp text := 'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres rojos: ninguno | c10 para anon o service_role, o definer: ninguna | el '
                'pegado: 9 filas, y la configuración 1 fila (id 1)';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena()
     where not ok and not (control = 'permisos' and pg_temp.c10_permisos() = 'verde');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar()
     where not ok and not (control = any (string_to_array(pg_temp.c10('rojos_c3'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c10('rojos_c6'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c10('rojos_c4'), ', ')));
    if pg_temp.c10('hay_c8') = 'true' then
      execute $q$ select coalesce(string_agg(orden::text, ' ' order by orden), 'ninguno') from public.v_contador_control where nivel = 'cuadre' and not ok $q$ into v_c8;
    else
      v_c8 := 'ninguno';
    end if;
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_jornal_pegado();
    select count(*) into v_cfg from jornal_config;
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | c8 cuadres rojos: %s | c10 para anon o service_role, o definer: %s | el pegado: %s filas, y la '
                    'configuración %s fila (id %s)', v_c2, v_c3, v_c6, v_c4, v_c8, v_api, v_n, v_cfg, (select id from jornal_config limit 1));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (60, 'el cierre de la suite: c2, c3, c6 y c4 en verde con c10 puesto (salvo lo que ya estaba en rojo antes), c8 sin cuadres rojos, nada de c10 para anon o service_role ni SECURITY DEFINER; fn_jornal_pegado responde y la configuración es una fila (pegar dos veces no la pisa: lo corre el banco)',
    v_esp,
    v_obt || case when pg_temp.c10('rojos_c3') <> '' then ' (ya en rojo antes, en c3: ' || pg_temp.c10('rojos_c3') || ')' else '' end
          || case when pg_temp.c10('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.c10('rojos_c4') || ')' else '' end
          || case when pg_temp.c10('rojos_c6') <> '' then ' (ya en rojo antes, en c6: ' || pg_temp.c10('rojos_c6') || ')' else '' end
          || case when pg_temp.c10('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c10: ' || pg_temp.c10('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;


-- 61. EL CIERRE MIRA LA MANO DE OBRA REPARTIDA (c9, con su bloque de c10:
--     las filas 170 y 171 de fn_cierre_revisar). Sin ese bloque un mes se
--     podía cerrar con un reparto suelto. La 170 (detiene) dice lo mismo que
--     los cuadres de v_jornal_control y v_margen_control; la 171, sus
--     avisos. Un reparto des-casado por fuera pone la 170 en rojo con el
--     detalle del control 20; deshecho, vuelve a como estaba. Si el c9 de
--     esta base es el de antes (sin el bloque), se omite y dice qué pegar.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_per text; a text; b text; c text; v_rojos int; v_ok0 boolean;
  f record;
  v_nom text := 'el cierre (c9) mira la mano de obra repartida: la fila 170 de su revisión (detiene) dice lo que los cuadres de c10 y '
                'la 171 sus avisos; un reparto des-casado por fuera la pone en rojo, y deshecho vuelve a como estaba';
  v_esp text := 'antes: la 170 detiene y dice lo que los cuadres de c10; la 171 es un aviso | des-casado por fuera: la 170 en rojo, '
                'detiene, con el reparto suelto | deshecho: la 170 como antes';
begin
  if to_regprocedure('public.fn_cierre_revisar(text)') is null then
    insert into _pruebas values (61, v_nom, v_esp, 'omitida: c9 (el cierre) no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(61, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(61, v_nom, v_esp, 'jornal', array[20]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select p.periodo into v_per from periodos p where p.tipo = 'mes' and pg_temp.c10_d() between p.desde and p.hasta;
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t61', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9061');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select (select count(*) from v_jornal_control x where x.nivel = 'cuadre' and x.ok is not true)
         + (select count(*) from v_margen_control y where y.nivel = 'cuadre' and y.ok is not true)
      into v_rojos;
    perform pg_temp.c10_ser('dueno');
    select x.nivel, x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    if not found then
      v_obt := 'omitida: el cierre de esta base todavía no trae las filas de la mano de obra (170 y 171): vuelve a pegar '
               'docs/conta/c9-cierre.sql y corre esto otra vez';
      raise exception using errcode = 'MXT00';
    end if;
    v_ok0 := f.ok;
    a := format('la 170 %s y %s; la 171 %s', f.nivel,
                case when f.ok = (v_rojos = 0) then 'dice lo que los cuadres de c10'
                     else format('dice %s con %s cuadre(s) de c10 en rojo', f.ok, v_rojos) end,
                coalesce((select case when x.nivel = 'aviso' then 'es un aviso' else 'es ' || x.nivel end
                            from fn_cierre_revisar(v_per) x where x.orden = 171), 'no está'));
    perform fn_banco_descasar(v_mov, 'c10-pruebas: lo suelto en la Bandeja (se deshace)');
    select x.nivel, x.ok, x.detalle into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    b := format('la 170 %s, %s, %s', case when f.ok then 'en VERDE' else 'en rojo' end, f.nivel,
                case when f.detalle like '%se reversó por fuera%' then 'con el reparto suelto'
                     else 'sin decir cuál: ' || left(coalesce(f.detalle, ''), 200) end);
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: se había des-casado en la Bandeja');
    perform pg_temp.c10_ser('dueno');
    select x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    perform pg_temp.c10_ser('editor');
    c := case when f.ok is not distinct from v_ok0 then 'la 170 como antes' else 'la 170 NO volvió: ' || coalesce(f.ok::text, 'nulo') end;
    v_obt := format('antes: %s | des-casado por fuera: %s | deshecho: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (61, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8 y c9): si el SQL Editor deja de esperar, la corrida sigue en el
-- servidor hasta el final y se lee después con
--   select * from pruebas.c10_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c10_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c10_resultado from public, anon, authenticated, service_role;
truncate pruebas.c10_resultado;
insert into pruebas.c10_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
