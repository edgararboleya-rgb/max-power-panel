-- =====================================================================
-- c12-pruebas.sql — el WIP por costo a costo se prueba a sí mismo
-- (c12-wip.sql). 12-nov-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c12-wip.sql (y de
-- volver a pegar c9-cierre.sql, que trae las filas 174 a 177), pegar este
-- archivo entero → Run. Sale la tabla _pruebas: 48 filas, todas con ok =
-- true (las que salen «omitida» dicen por qué y no son un fallo). Si el
-- editor se cansa antes del final, la corrida sigue en el servidor y se lee
-- después en pruebas.c12_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c10 y c12-wip.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c12-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las obras de prueba, ni sus asientos, ni sus facturas, ni
-- las revisiones, ni los ajustes); la 43 lo comprueba.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · CATORCE OBRAS DE PRUEBA («C12 PRUEBA Obra A»…«P», ids c12-prueba-a…p),
--     con su tipo, su estado y su contrato (y una más, Z, en la 33). Ninguna
--     prueba toca una obra real: mira SUS filas del WIP, SUS líneas del
--     asiento y SUS saldos (el ajuste de un mes lleva también las obras
--     reales que estén listas: las pruebas las dejan pasar y no las cuentan).
--   · Si el mes de las pruebas YA TIENE SU AJUSTE REAL posteado, cada prueba
--     lo deshace dentro de su subtransacción (y vuelve con ella): parte de un
--     mes sin ajuste vivo. Y lo que wip_config diga en esta base no cambia
--     lo que se prueba: las pruebas del ajuste y de los controles ponen ahí
--     dentro el mes de las pruebas como exigido.
--   · SUS COSTOS, a mano por el camino del dueño (fn_postear: Dr la cuenta
--     de costo con su obra / Cr 3100), y SUS FACTURAS por el puente de c3
--     (con ids negativos, −1200001…: no gastan la secuencia), fechados en
--     EL MES DE LAS PRUEBAS: el mes abierto más viejo que ya terminó (en el
--     banco y hoy en producción, octubre de 2026). Si no hay ninguno (todo
--     lo terminado está cerrado), las pruebas que postean salen «omitida».
--   · La regla del tipo de obra (mapeo_tipo_proyecto) se confirma dentro de
--     la prueba si estaba en borrador (en producción ya lo está).
--   · La 29 (un mes cerrado) cierra dentro de su subtransacción la apertura
--     y el mes de las pruebas, como c3-pruebas (toma «lock table periodos in
--     exclusive mode»); si el libro real no deja cerrar, sale «omitida» con
--     lo que dijo c2.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10) se comparan con cómo
-- estaban justo antes: lo que ya estaba en rojo se dice y no se cuenta.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 6 tablas, 5 vistas, las 29 funciones por su
--    nombre exacto, la configuración, cada objeto con su comentario «c12: …»);
--  2 las precondiciones en rojo (desde la app; sin una función de c2; una
--    función con nombre de c12 que no es de c12; una vista ajena colgada);
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas en las
--    tablas, las vistas y las auxiliares; el dueño entra y ve;
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa, RLS y
--    policies justas, vistas security_invoker que no fijan columnas de c2 ni
--    cuelgan de vistas ajenas; «permisos» (c2) y las protecciones de c6 y c4
--    en verde con c12 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API; y
--    lo que es rastro, ni con la marca);
--  6 fn_wip_config y sus frenos;
--  7 QUÉ OBRAS LLEVAN WIP: la regla, la marca (contrato, tm, auto) y sus
--    frenos; v_wip_obras;
-- EL CÁLCULO, cada columna a mano:
--  8 una obra SUB-facturada;
--  9 una obra SOBRE-facturada;
-- 10 el depósito sin costo: todo a sobre-facturado (2400);
-- 11 la PÉRDIDA: sin costo, a la mitad y con todo el costo, el resultado
--    acumulado es la pérdida completa, una vez; y con centavos;
-- 12 una obra que PASA DE 100 %: queda pendiente y fuera del ajuste, el
--    cuadre 60 la detiene y ninguna nota lo salta;
-- 13 el redondeo: una sola vez, medio centavo hacia arriba; con 100 % el
--    ganado es el precio;
-- 14 una obra que ya andaba ANTES DEL LIBRO: la propuesta, confirmarla, otros
--    números con su nota, la anterior queda;
-- 15 otra que ya andaba, SIN CONFIRMAR: no entra en el ajuste, y se dice;
-- 16 una de servicio (T&M) no entra; marcada «contrato», sí;
-- 17 una obra TERMINADA: 100 %, lo que falta por facturar queda
--    sub-facturado; sigue entrando mientras no se facture entera;
-- 18 la propuesta del costo estimado: el estimado de la obra (c10) y lo del
--    mes anterior; un toque; otro número pide su nota; la propuesta que
--    cambió;
-- 19 los frenos de la revisión;
-- 20 el precio del contrato se copia al revisar (la ficha cambia sin
--    historia) y se avisa si cambió;
-- 21 v_wip_schedule (lo que la pantalla pinta) y los totales del resumen;
-- EL AJUSTE:
-- 22 el asiento, línea por línea, y su foto;
-- 23 dos veces = uno (idempotente);
-- 24 su reverso del día 1: el espejo, el saldo por obra al cierre y al día
--    siguiente, y «Costo por obra» (c10) no se mueve;
-- 25 la revisión cambiada después de postear: el control lo dice y volver a
--    postear lo rehace (reverso, anulación del reverso del día 1 y el nuevo);
-- 26 deshacer;
-- 27 el asiento reversado por fuera (a mano): el control lo ve, y postear o
--    deshacer lo arreglan;
-- 28 cuándo no se postea (el mes sin terminar, uno que no existe, la
--    apertura, sin obras listas, nada que ajustar); el freno de «falta abrir
--    el mes siguiente» no se puede provocar sin borrar un período: no se
--    prueba;
-- 29 EL MES CERRADO no se toca, y su WIP es la foto de su ajuste;
-- 30 el mes siguiente: lo facturado y el costo no cuentan los ajustes;
-- LOS CONTROLES:
-- 31 el 10 (un asiento a mano en las cuentas del WIP) en rojo y de vuelta;
-- 32 el 30 (lo facturado = las facturas del libro) no salta con notas de
--    crédito dentro y fuera del mes (es un cable trampa: con los puentes de
--    c3 sanos no se puede poner en rojo sin romper sus guardas);
-- 33 el 40 (cada obra revisada): exigible, en rojo y de vuelta;
-- 34 el 50 (el ajuste posteado): exigible, en rojo y de vuelta;
-- 35 el 60 (más costo que el estimado, con nota o sin ella) en rojo y de
--    vuelta, y el nombre de la fila 174 dice cuál;
-- 36 los avisos (pérdida, facturado por encima del contrato, ingreso que no
--    es factura, terminadas fuera del WIP, activas sin contrato, horas sin
--    costo en el libro, los hitos) y la fila 177 del cierre;
-- 37 el 90 (las protecciones) en rojo y de vuelta;
-- 38 las cuatro filas del cierre (fn_wip_cierre);
-- 39 el cierre (c9) mira el WIP: sus filas 174 a 177, y MX010 al cerrar
--    («omitida» mientras c9-cierre.sql no traiga el bloque de c12);
-- 40 el texto de los controles y de los avisos no nombra funciones;
-- Y el cierre de la suite:
-- 41 con ajustes posteados, rehechos y deshechos, NINGÚN control de c2, c3,
--    c4, c6, c8, c9 ni c10 pasa a rojo;
-- 42 «Costo por obra» (c10) con un ajuste vivo: ingreso_libro, costo_real y
--    sus cuadres;
-- 43 nada queda al deshacer;
-- 44 el cierre de la suite: c2, c3, c6 y c4 como estaban, c8 y c10 sin
--    cuadres rojos nuevos, nada de c12 para anon o service_role ni SECURITY
--    DEFINER; y fn_wip_pegado responde.
-- Y lo que encontraron los revisores (cada una FALLA con la capa de antes):
-- 45 NINGUNA OBRA CON SALDO SALE SOLA: la cancelada, la marcada T&M y la
--    terminada sin facturar entera entran en el mes siguiente; salen solo
--    excluidas con su nota; la terminada sigue entrando;
-- 46 el contrato de la ficha cambia después de revisar: pendiente (precio),
--    detiene, y se decide («es de después», o se revisa otra vez);
-- 47 lo de antes sin confirmar detiene; excluida ese mes con su nota, la
--    fila 176 lo dice.
-- Y lo que encontró la revisión final (FALLA con la capa de antes):
-- 48 una obra de precio fijo con su depósito facturado que la app todavía
--    tiene como «enviado»: no entra en el WIP (su ingreso es lo facturado) y
--    el aviso 160 la nombra; pasada a aprobada, entra; otra en estimación,
--    marcada «tm» con su nota, ya no se nombra; la que solo tiene costo, no.
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el mes de las pruebas, hoy.
create temp table if not exists _c12 (k text primary key, v text);
truncate _c12;
insert into _c12
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c12
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c12 values ('hoy', fn_fecha_miami(now())::text);
-- el mes de las pruebas: el mes abierto más viejo que ya terminó
insert into _c12
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
-- el mes siguiente al de las pruebas (donde cae el reverso del día 1)
insert into _c12
select 'mes_sig', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto'
   and p.desde = (select q.hasta + 1 from periodos q where q.periodo = (select v from _c12 where k = 'mes'));
-- un mes abierto que todavía no termina (el más lejano: ni siquiera empezó)
insert into _c12
select 'mes_futuro', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > fn_fecha_miami(now()) order by p.desde desc limit 1;
insert into _c12 values ('libro_desde', fn_wip_libro_desde()::text);
insert into _c12 values ('hay_c8', (to_regclass('public.v_contador_control') is not null)::text);
insert into _c12 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
insert into _c12 values ('hay_c10', (to_regprocedure('public.fn_margen_obras(text)') is not null
                                     and to_regclass('public.v_margen_control') is not null)::text);
insert into _c12
select 'c9_wip', coalesce((select p.prosrc like '%fn_wip_cierre%' from pg_proc p
                            where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')), false)::text;
grant select on _c12 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9 y c10), y
-- ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c12(k text) returns text language sql as $$ select v from _c12 where k = $1 $$;
-- un día del mes de las pruebas (el día 1 + n) y su último día
create or replace function pg_temp.c12_d(p_n int default 0) returns date language sql as $$
  select p.desde + p_n from periodos p where p.periodo = pg_temp.c12('mes')
$$;
create or replace function pg_temp.c12_h() returns date language sql as $$
  select p.hasta from periodos p where p.periodo = pg_temp.c12('mes')
$$;

-- Las funciones que crea c12-wip.sql, por su nombre exacto (las 29). No se
-- buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c12_es_suya(p_nombre text) returns boolean language sql immutable as $$
  select p_nombre = any (array[
    'fn_wip_precondiciones', 'fn_wip_exigir_dueno', 'fn_wip_ve', 'fn_wip_guarda', 'fn_wip_usd', 'fn_wip_mes', 'fn_wip_dia',
    'fn_wip_monto', 'fn_wip_libro_desde', 'fn_wip_toca', 'fn_wip_meses', 'fn_wip_asientos', 'fn_wip_obras', 'fn_wip_libro',
    'fn_wip_calcular', 'fn_wip_schedule', 'fn_wip_plan', 'fn_wip_ajuste_estado', 'fn_wip_resumen', 'fn_wip_antes_propuesta',
    'fn_wip_antes', 'fn_wip_obra', 'fn_wip_config', 'fn_wip_revisar', 'fn_wip_postear', 'fn_wip_deshacer', 'fn_wip_control',
    'fn_wip_cierre', 'fn_wip_pegado'])
$$;
create or replace function pg_temp.c12_tablas() returns text[] language sql immutable as $$
  select array['wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras']
$$;
create or replace function pg_temp.c12_vistas() returns text[] language sql immutable as $$
  select array['v_wip_obras', 'v_wip_schedule', 'v_wip_control', 'v_wip_ajustes', 'v_wip_revisiones']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, en aal2), anon o service_role.
create or replace function pg_temp.c12_ser(quien text) returns void language plpgsql as $$
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
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c12(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c12(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- Lo que contesta una orden: 'ok' o su código de error (y, con c12_dice, su
-- mensaje). Como quien se diga; al volver, otra vez el SQL Editor.
create or replace function pg_temp.c12_estado(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c12_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate;
  end;
  perform pg_temp.c12_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c12_dice(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c12_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  perform pg_temp.c12_ser('editor');
  return v;
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): la regla del tipo
-- de obra confirmada, los puentes de c3 en «immediate» (la factura entra al
-- libro en el momento, como en c3-pruebas), y las obras de prueba con su
-- contrato. Si el mes de las pruebas ya tiene su ajuste de WIP real posteado,
-- se deshace AQUÍ DENTRO (y vuelve con la prueba, que se deshace entera):
-- cada prueba parte de un mes sin ajuste vivo.
create or replace function pg_temp.c12_sembrar() returns void language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c12_ser('editor');
  if exists (select 1 from wip_ajustes a where a.periodo = pg_temp.c12('mes') and a.deshecho_el is null) then
    perform fn_wip_deshacer(pg_temp.c12('mes'), 'C12 PRUEBA: se deshace dentro de la prueba (la prueba se deshace entera)');
  end if;
  perform fn_mapeo_confirmar('tipo_proyecto');
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v is not null then
    execute 'set constraints ' || v || ' immediate';
  end if;
  insert into proyectos (id, tipo, nombre, estado) values
    ('c12-prueba-a', 'comercial',   'C12 PRUEBA Obra A', 'ejecucion'),    -- sub-facturada
    ('c12-prueba-b', 'residencial', 'C12 PRUEBA Obra B', 'ejecucion'),    -- sobre-facturada
    ('c12-prueba-c', 'comercial',   'C12 PRUEBA Obra C', 'ejecucion'),    -- con pérdida
    ('c12-prueba-d', 'residencial', 'C12 PRUEBA Obra D', 'ejecucion'),    -- el depósito sin costo
    ('c12-prueba-e', 'comercial',   'C12 PRUEBA Obra E', 'pausa'),        -- pasa de 100 %
    ('c12-prueba-f', 'comercial',   'C12 PRUEBA Obra F', 'ejecucion'),    -- ya andaba, confirmada
    ('c12-prueba-g', 'residencial', 'C12 PRUEBA Obra G', 'ejecucion'),    -- ya andaba, sin confirmar
    ('c12-prueba-h', 'servicio',    'C12 PRUEBA Obra H', 'ejecucion'),    -- de servicio (T&M)
    ('c12-prueba-i', 'servicio',    'C12 PRUEBA Obra I', 'ejecucion'),    -- de servicio con contrato
    ('c12-prueba-j', 'comercial',   'C12 PRUEBA Obra J', 'ejecucion'),    -- la que termina
    ('c12-prueba-k', 'residencial', 'C12 PRUEBA Obra K', 'ejecucion'),    -- sin contrato
    ('c12-prueba-l', 'comercial',   'C12 PRUEBA Obra L', 'aprobado'),     -- sin movimiento
    ('c12-prueba-m', 'comercial',   'C12 PRUEBA Obra M', 'ejecucion'),    -- el redondeo
    ('c12-prueba-p', 'comercial',   'C12 PRUEBA Obra P', 'ejecucion');    -- la pérdida con centavos
  insert into finanzas_proyecto (proyecto_id, contrato) values
    ('c12-prueba-a', 10000), ('c12-prueba-b', 20000), ('c12-prueba-c', 10000), ('c12-prueba-d', 30000), ('c12-prueba-e', 10000),
    ('c12-prueba-f', 40000), ('c12-prueba-g', 15000), ('c12-prueba-i', 5000), ('c12-prueba-j', 8000), ('c12-prueba-l', 12000),
    ('c12-prueba-m', 9999.99), ('c12-prueba-p', 10000);
end $$;

-- (la fila «omitida» de una prueba que necesita el mes de las pruebas; true si la puso)
create or replace function pg_temp.c12_omitir(p_n int, p_prueba text, p_esperado text) returns boolean language plpgsql as $$
begin
  if pg_temp.c12('mes') is not null and pg_temp.c12('mes_sig') is not null and pg_temp.c12('dueno') is not null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    'omitida: ' || case when pg_temp.c12('dueno') is null then 'no hay un dueño activo en perfiles'
                        when pg_temp.c12('mes') is null then 'no hay un mes abierto que ya haya terminado (todo lo terminado está cerrado): '
                                                             'no hay dónde postear un ajuste de prueba'
                        else 'el mes siguiente al de las pruebas no está abierto' end, null);
  return true;
end $$;

-- Un costo de una obra de prueba en el libro (a mano, como el dueño): Dr la
-- cuenta de costo con su obra / Cr 3100. p_dia: el día del mes de las
-- pruebas (0 = el día 1); p_per: otro mes.
create or replace function pg_temp.c12_costo(p_obra text, p_monto numeric, p_dia int default 9, p_cuenta text default '5100',
                                             p_per text default null)
returns uuid language plpgsql as $$
declare
  r jsonb;
  v_f date;
begin
  select q.desde + p_dia into v_f from periodos q where q.periodo = coalesce(p_per, pg_temp.c12('mes'));
  perform pg_temp.c12_ser('dueno');
  r := fn_postear(jsonb_build_object('fecha', v_f::text, 'descripcion', 'C12 PRUEBA: costo de ' || p_obra || ' (se deshace)',
         'lineas', jsonb_build_array(jsonb_build_object('cuenta', p_cuenta, 'monto', p_monto::text, 'proyecto_id', p_obra),
                                     jsonb_build_object('cuenta', '3100', 'monto', (-p_monto)::text))));
  perform pg_temp.c12_ser('editor');
  return (r->>'id')::uuid;
end $$;

-- Una factura de una obra de prueba, por el puente de c3 (como el SQL
-- Editor): entra al libro al insertarla (Dr 1110 / Cr su ingreso). Devuelve
-- su id (−1200000 − n). p_dia: el día del mes de las pruebas; si es negativo,
-- esos días ANTES del libro (no entra al libro: es de QuickBooks).
create or replace function pg_temp.c12_factura(p_n int, p_obra text, p_monto numeric, p_dia int default 11, p_hito bigint default null)
returns bigint language plpgsql as $$
declare
  v_id bigint := -(1200000 + p_n);
  v_f  date := case when p_dia < 0 then pg_temp.c12('libro_desde')::date + p_dia else pg_temp.c12_d(p_dia) end;
begin
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion, hito_id) overriding system value
  values (v_id, p_obra, 'C12-' || p_n, v_f, p_monto, 0, p_hito);
  if p_dia >= 0 and not exists (select 1 from facturas f where f.id = v_id and f.contabilizado_en is not null) then
    raise exception 'c12-pruebas: el puente de facturas no contabilizó la factura de prueba % (¿la regla del tipo de obra?)', v_id;
  end if;
  return v_id;
end $$;

-- Como el dueño por la API: revisar, confirmar lo de antes, postear,
-- deshacer. Al volver, otra vez el SQL Editor.
create or replace function pg_temp.c12_rev(p_obra text, p jsonb, p_per text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c12_ser('dueno');
  r := fn_wip_revisar(p_obra, coalesce(p_per, pg_temp.c12('mes')), p);
  perform pg_temp.c12_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c12_antes(p_obra text, p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c12_ser('dueno');
  r := fn_wip_antes(p_obra, p);
  perform pg_temp.c12_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c12_postear(p_per text default null, p_motivo text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c12_ser('dueno');
  r := fn_wip_postear(coalesce(p_per, pg_temp.c12('mes')), p_motivo);
  perform pg_temp.c12_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c12_deshacer(p_motivo text, p_per text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c12_ser('dueno');
  r := fn_wip_deshacer(coalesce(p_per, pg_temp.c12('mes')), p_motivo);
  perform pg_temp.c12_ser('editor');
  return r;
end $$;

-- La fila del WIP de una obra en un mes, en una línea (como el SQL Editor).
create or replace function pg_temp.c12_fila(p_obra text, p_per text default null) returns text language sql as $$
  select coalesce((select case when s.costo_fecha is null and s.precio_contrato is null
                               then format('%s {%s}: sin cifras', s.estado, array_to_string(s.falta, ','))
                               when s.costo_fecha is null
                               then format('%s {%s}: precio %s, sin cifras', s.estado, array_to_string(s.falta, ','), s.precio_contrato)
                               else format('%s: precio %s, est %s, util est %s, costo %s, %s %%, ganado %s, fact %s, sub %s, sobre %s, '
                                           'para terminar %s, util %s, perdida %s, prov %s',
                                           s.estado, s.precio_contrato, s.costo_estimado, s.utilidad_estimada, s.costo_fecha, s.pct_avance,
                                           s.ingreso_ganado, s.facturado_fecha, s.sub_facturado, s.sobre_facturado, s.costo_para_terminar,
                                           s.utilidad_fecha, s.perdida_total, s.perdida_provision) end
                     from fn_wip_schedule(coalesce(p_per, pg_temp.c12('mes'))) s where s.proyecto_id = p_obra), 'no sale')
$$;
-- Las líneas de un asiento que son de las obras de prueba: cuenta monto obra | …
create or replace function pg_temp.c12_lineas(p_asiento uuid) returns text language sql as $$
  select coalesce(string_agg(format('%s %s %s', l.cuenta, l.monto, replace(l.proyecto_id, 'c12-prueba-', '')), ' | ' order by l.orden), '-')
    from asiento_lineas l where l.asiento_id = p_asiento and l.proyecto_id like 'c12-prueba-%'
$$;
-- El saldo de una cuenta en una obra de prueba hasta un día (debe − haber).
create or replace function pg_temp.c12_saldo(p_cuenta text, p_obra text, p_hasta date) returns numeric language sql as $$
  select coalesce(sum(l.monto), 0)::numeric(14,2)
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.cuenta = p_cuenta and l.proyecto_id = p_obra and a.fecha_contable <= p_hasta
$$;
-- Una fila del control del WIP del mes de las pruebas: 'verde' o 'rojo', y su detalle.
create or replace function pg_temp.c12_ctl(p_orden int, p_per text default null) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from fn_wip_control(coalesce(p_per, pg_temp.c12('mes'))) c where c.orden = p_orden
$$;
create or replace function pg_temp.c12_ctl_det(p_orden int, p_per text default null) returns text language sql as $$
  select c.detalle from fn_wip_control(coalesce(p_per, pg_temp.c12('mes'))) c where c.orden = p_orden
$$;
-- Los cuadres del WIP del mes de las pruebas (sin el 40 y el 50, que tienen
-- sus pruebas) contra cómo estaban ANTES de las pruebas: lo que ya estaba en
-- rojo con los datos de esta base no se cuenta.
create or replace function pg_temp.c12_propios(p_per text default null) returns text language sql as $$
  select coalesce('NUEVO en rojo: ' || string_agg(c.orden::text, ', ' order by c.orden), 'nada nuevo en rojo')
    from fn_wip_control(coalesce(p_per, pg_temp.c12('mes'))) c
   where c.nivel = 'cuadre' and not c.ok and c.orden not in (40, 50)
     and c.orden::text <> all (string_to_array(coalesce(pg_temp.c12('rojos_wip'), ''), ','))
$$;
-- El ajuste vivo del mes de las pruebas.
create or replace function pg_temp.c12_vivo(p_per text default null) returns public.wip_ajustes language sql as $$
  select a.* from wip_ajustes a where a.periodo = coalesce(p_per, pg_temp.c12('mes')) and a.deshecho_el is null
$$;
-- Las líneas de un asiento que son de las obras de prueba, con la cuenta de
-- ingreso de cada obra dicha como «ingreso» (la regla del tipo de obra es de
-- cada base): cuenta monto obra | …
create or replace function pg_temp.c12_lin(p_asiento uuid) returns text language sql as $$
  select coalesce(string_agg(format('%s %s %s',
                    case when l.cuenta = (select o.cuenta_ingreso from fn_wip_obras(l.proyecto_id) o) then 'ingreso' else l.cuenta end,
                    l.monto, replace(l.proyecto_id, 'c12-prueba-', '')), ' | ' order by l.orden), '-')
    from asiento_lineas l where l.asiento_id = p_asiento and l.proyecto_id like 'c12-prueba-%'
$$;
-- LA ESCENA DE LOS TRES (las pruebas del ajuste y de los controles): A
-- sub-facturada 3,000; B sobre-facturada 4,000; C con pérdida (sub-facturada
-- 5,000 y 1,000 de provisión). Y el WIP exigido en el mes de las pruebas (lo
-- que diga wip_config en esta base no cambia lo que se prueba).
create or replace function pg_temp.c12_escena() returns void language plpgsql as $$
begin
  perform pg_temp.c12_sembrar();
  perform fn_wip_config(jsonb_build_object('exigir_desde', pg_temp.c12('mes')));
  perform pg_temp.c12_costo('c12-prueba-a', 3000);
  perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
  perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
  perform pg_temp.c12_costo('c12-prueba-b', 4000);
  perform pg_temp.c12_factura(2, 'c12-prueba-b', 9000);
  perform pg_temp.c12_rev('c12-prueba-b', '{"costo_estimado": "16000"}');
  perform pg_temp.c12_costo('c12-prueba-c', 6000);
  perform pg_temp.c12_rev('c12-prueba-c', '{"costo_estimado": "12000"}');
end $$;

-- CERRAR HASTA EL MES DE LAS PRUEBAS (como pg_temp.c3_cerrar_hasta de
-- c3-pruebas): la apertura —con un asiento de apertura de prueba si no tiene
-- el suyo— y cada mes abierto hasta el de las pruebas, en orden. La prueba
-- toma antes «lock table public.periodos in exclusive mode».
create or replace function pg_temp.c12_cerrar_hasta(p_periodo text) returns void language plpgsql as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  perform pg_temp.c12_ser('editor');
  select * into v_p from periodos where periodo = p_periodo;
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear(jsonb_build_object(
      'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
      'descripcion', 'C12 PRUEBA: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
  end loop;
end $$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los estados
-- (c4), los cuadres de la IA (c8, si está), los cuadres del jornal y del
-- margen (c10, si está) y lo que detiene el cierre del mes de las pruebas
-- (c9, si está; sin las filas del propio WIP, 174 a 177). Como el SQL Editor.
create or replace function pg_temp.c12_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c12_ser('editor');
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
    -- (y al último día del mes de las pruebas, que es donde vive el ajuste)
    execute $q$ select coalesce(array_agg('c4 del mes: ' || k.vista order by k.vista), '{}') from public.fn_estados_control($1) k where not k.ok $q$
       into x using pg_temp.c12('mes');
    v := v || x;
  end if;
  if pg_temp.c12('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c12('hay_c10') = 'true' then
    execute $q$ select coalesce(array_agg('c10: ' || k.c order by k.c), '{}')
                  from (select 'jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                        union all
                        select 'margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c12('hay_c9') = 'true' and pg_temp.c12('mes') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k
                 where k.nivel = 'detiene' and k.ok is distinct from true and k.orden not between 174 and 177 $q$
       into x using pg_temp.c12('mes');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c12_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- Lo que hay en lo que c12 toca (la 43 lo compara)
create or replace function pg_temp.c12_conteos() returns text language sql as $$
  select format('config %s · marcas %s · antes %s · revisiones %s · ajustes %s · fotos %s · asientos %s · líneas del libro %s · contadores %s · '
                'facturas %s (%s contabilizadas) · notas de crédito %s · externos %s · hitos %s · obras %s · fichas %s · reglas confirmadas %s · '
                'cerrados %s · escenarios %s · funciones %s',
                (select md5(to_jsonb(c)::text) from wip_config c where c.id = 1), (select count(*) from wip_obras),
                (select count(*) from wip_antes), (select count(*) from wip_revisiones), (select count(*) from wip_ajustes),
                (select count(*) from wip_ajuste_obras), (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from facturas),
                (select count(*) from facturas where contabilizado_en is not null), (select count(*) from notas_credito),
                (select count(*) from trabajos_externos), (select count(*) from hitos), (select count(*) from proyectos),
                (select md5(coalesce(string_agg(to_jsonb(f)::text, '|' order by f.proyecto_id), '')) from finanzas_proyecto f),
                (select count(*) from mapeo_tipo_proyecto where confirmado_el is not null),
                (select count(*) from periodos where estado = 'cerrado'), (select count(*) from escenarios),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c12 values ('conteos', pg_temp.c12_conteos());

-- (lo de c3, c4, c6 y c10 que ya estaba en rojo ANTES de las pruebas: la 44 lo dice y no lo cuenta)
insert into _c12
select 'rojos_c3', coalesce(string_agg(control, ', ' order by control), '') from fn_puentes_verificar() where not ok;
insert into _c12
select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _c12
select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;
do $$
declare
  v text := '';
begin
  if pg_temp.c12('hay_c10') = 'true' then
    execute $q$ select coalesce(string_agg(k.c, ', ' order by k.c), '')
                  from (select 'jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                        union all
                        select 'margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k $q$ into v;
  end if;
  insert into _c12 values ('rojos_c10', v);
  v := '';
  if pg_temp.c12('hay_c8') = 'true' then
    execute $q$ select coalesce(string_agg(k.orden::text, ', ' order by k.orden), '')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v;
  end if;
  insert into _c12 values ('rojos_c8', v);
end $$;
-- (los cuadres del propio WIP que ya estaban en rojo con los datos de esta base)
insert into _c12
select 'rojos_wip', coalesce(string_agg(k.orden::text, ',' order by k.orden), '')
  from fn_wip_control(pg_temp.c12('mes')) k where k.nivel = 'cuadre' and not k.ok;
-- (las funciones AJENAS a c12 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 44
-- las dicen y no las cuentan como fallo de c12.)
create or replace function pg_temp.c12_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c12
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c12_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c12: %';
-- «permisos» de c2 sin contar lo ajeno de antes: 'verde' o 'rojo: …'
create or replace function pg_temp.c12_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c12_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c12('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c12_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;

-- EL RELOJ FINGIDO (el de c2-pruebas y c11-pruebas): «hoy» pasa a ser esa
-- fecha (o el hoy de verdad, si es posterior). Solo DENTRO de la
-- subtransacción de una prueba: su MXT00 lo deshace.
create or replace function pg_temp.c12_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, las 29 funciones por su
--    nombre exacto, la configuración (una fila) y cada objeto con su
--    comentario «c12: …».
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 6 tablas | 5 vistas | 29 funciones (29 nombres) | sin comentario c12: ninguno | configuración: 1 fila, id 1';
begin
  begin
    perform pg_temp.c12_ser('editor');
    v_pre := coalesce(fn_wip_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c12_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c12_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(proname);
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c12_tablas()) or c.relname = any (pg_temp.c12_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c12: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(p.proname)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c12: %') x;
    select format('%s fila, id %s', count(*), min(c.id)) into v_cfg from wip_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c12: %s | configuración: %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 6 tablas, 5 vistas, las 29 funciones por su nombre exacto, la configuración (una fila) y cada objeto con su comentario «c12: …»',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c2 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c12
--    que no lleva su comentario (no es de c12: no se pisa); una vista ajena
--    colgada de una vista de c12 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin fn_reversar: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    v_a := pg_temp.c12_estado('select public.fn_wip_precondiciones()', 'dueno');
    begin
      drop function public.fn_reversar(uuid, text);
      v_b := coalesce(fn_wip_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_wip_cierre(text) is 'otra cosa';
      v_c := coalesce(fn_wip_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c12_prueba_ajena as select o.proyecto_id from public.v_wip_obras o;
      v_d := coalesce(fn_wip_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin fn_reversar: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%fn_reversar(uuid,text)%' then 'la nombra' else v_b end,
                    case when v_c like '%sin ser de c12%' and v_c like '%fn_wip_cierre(text)%' and v_c like '%No lo piso%'
                         then 'la nombra y no la pisa' else v_c end,
                    case when v_d like '%c12_prueba_ajena%' and v_d like '%depende(n) de las vistas de c12%' then 'la nombra' else v_d end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se llaman (42501); sin una función de c2 la nombran; una función con nombre de c12 sin su comentario no se pisa; una vista ajena colgada de las de c12 se dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. La API: las de la pantalla, solo authenticated; las internas, nadie;
--    anon y service_role no ejecutan ni leen nada; el equipo (alguien que no
--    es el dueño, con un ajuste ya posteado en la base) recibe 42501 de las
--    ocho funciones de la pantalla y cero filas de las seis tablas, las cinco
--    vistas y las diez auxiliares de lectura; el dueño entra y ve.
do $$
declare
  v_obt text; v_api text; v_sin text; v_anon text; v_srv text; v_n int := 0; v_filas bigint := 0; v_k bigint; v_due text; v_x text;
  v_per text := pg_temp.c12('mes');
  v_esp text := 'pantalla mal: ninguna | internas con API: ninguna | anon 42501 y 42501 | service_role 42501 y 42501 | '
                'equipo: 8 de 8 funciones 42501 y 0 filas en 6 tablas, 5 vistas y 10 auxiliares | '
                'dueño: su obra lista, 1 ajuste vivo, 17 controles y 4 filas del cierre';
begin
  if pg_temp.c12_omitir(3, 'la API por rol', v_esp) then return; end if;
  if pg_temp.c12('equipo') is null then
    insert into _pruebas values (3, 'la API por rol', v_esp, 'omitida: no hay nadie del equipo (un perfil activo que no sea el dueño) con quien probar', null);
    return;
  end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    perform pg_temp.c12_postear();
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(p.proname)
       and p.proname not in ('fn_wip_precondiciones', 'fn_wip_guarda', 'fn_wip_pegado')
       and (not has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname in ('fn_wip_precondiciones', 'fn_wip_guarda', 'fn_wip_pegado')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    v_anon := pg_temp.c12_estado('select count(*) from public.v_wip_schedule', 'anon') || ' y '
           || pg_temp.c12_estado(format('select public.fn_wip_resumen(%L)', v_per), 'anon');
    v_srv  := pg_temp.c12_estado('select count(*) from public.wip_ajustes', 'service_role') || ' y '
           || pg_temp.c12_estado(format('select public.fn_wip_postear(%L)', v_per), 'service_role');
    -- el equipo: las ocho de la pantalla
    foreach v_x in array array[
      format('select public.fn_wip_revisar(%L, %L, %L::jsonb)', 'c12-prueba-a', v_per, '{"confirmar": true}'),
      format('select public.fn_wip_antes(%L, %L::jsonb)', 'c12-prueba-a', '{"costo": "0", "facturado": "0"}'),
      format('select public.fn_wip_antes_propuesta(%L)', 'c12-prueba-a'),
      format('select public.fn_wip_obra(%L, %L::jsonb)', 'c12-prueba-a', '{"modo": "tm", "nota": "x"}'),
      'select public.fn_wip_config(''{}''::jsonb)',
      format('select public.fn_wip_postear(%L)', v_per),
      format('select public.fn_wip_deshacer(%L, %L)', v_per, 'x'),
      format('select public.fn_wip_resumen(%L)', v_per)] loop
      if pg_temp.c12_estado(v_x, 'equipo') = '42501' then v_n := v_n + 1; end if;
    end loop;
    perform pg_temp.c12_ser('equipo');
    foreach v_x in array array[
      'select count(*) from public.wip_config', 'select count(*) from public.wip_obras', 'select count(*) from public.wip_antes',
      'select count(*) from public.wip_revisiones', 'select count(*) from public.wip_ajustes', 'select count(*) from public.wip_ajuste_obras',
      'select count(*) from public.v_wip_obras', 'select count(*) from public.v_wip_schedule', 'select count(*) from public.v_wip_control',
      'select count(*) from public.v_wip_ajustes', 'select count(*) from public.v_wip_revisiones',
      'select count(*) from public.fn_wip_obras(null)', format('select count(*) from public.fn_wip_calcular(%L)', v_per),
      format('select count(*) from public.fn_wip_schedule(%L)', v_per), format('select count(*) from public.fn_wip_control(%L)', v_per),
      format('select count(*) from public.fn_wip_cierre(%L)', v_per), format('select count(*) from public.fn_wip_libro(%L)', pg_temp.c12_h()),
      'select count(*) from public.fn_wip_meses()', 'select count(*) from public.fn_wip_asientos()',
      format('select count(*) from (select public.fn_wip_plan(%L) as x) z where z.x is not null', v_per),
      format('select count(*) from (select public.fn_wip_ajuste_estado(%L) as x) z where z.x is not null', v_per)] loop
      execute v_x into v_k;
      v_filas := v_filas + v_k;
    end loop;
    perform pg_temp.c12_ser('dueno');
    select format('su obra %s, %s ajuste vivo, %s controles y %s filas del cierre',
                  (select s.estado from v_wip_schedule s where s.periodo = v_per and s.proyecto_id = 'c12-prueba-a'),
                  (select count(*) from v_wip_ajustes a where a.periodo = v_per and a.vivo),
                  (select count(*) from fn_wip_control(v_per)), (select count(*) from fn_wip_cierre(v_per)))
      into v_due;
    perform pg_temp.c12_ser('editor');
    v_obt := format('pantalla mal: %s | internas con API: %s | anon %s | service_role %s | equipo: %s de 8 funciones 42501 y %s filas en 6 '
                    'tablas, 5 vistas y 10 auxiliares | dueño: %s', v_api, v_sin, v_anon, v_srv, v_n, v_filas, v_due);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las funciones de la pantalla solo para authenticated y las internas para nadie; anon y service_role no leen ni ejecutan; el equipo (con un ajuste ya en la base) recibe 42501 de las ocho de la pantalla y cero filas de las tablas, las vistas y las auxiliares; el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. El catálogo: nada SECURITY DEFINER; ningún nombre con un prefijo de
--    otra capa o de la otra sesión; RLS y sus policies; las vistas
--    security_invoker, que no fijan las columnas de periodos y de cuentas que
--    c2-pruebas reescribe ni cuelgan de vistas ajenas; y «permisos» de c2 y
--    las protecciones de c6 y de c4 en verde con c12 pegado.
do $$
declare
  v_obt text; v_def text; v_pre text; v_rls int; v_pol int; v_inv int; v_col text; v_dep text; v_per text; v_prot text;
  v_esp text := 'definer: ninguna | prefijos de otra capa: ninguno | RLS en 6 de 6 tablas, 16 policies | vistas security_invoker: 5 de 5 | '
                'vistas que fijan columnas que c2 reescribe: ninguna | vistas colgadas de vistas ajenas: ninguna | permisos (c2): verde | '
                'protecciones del banco (c6) y de c4: verdes';
begin
  begin
    perform pg_temp.c12_ser('editor');
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(p.proname) and p.prosecdef;
    select coalesce(string_agg(x.n, ', ' order by x.n), 'ninguno') into v_pre
      from (select p.proname::text as n from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(p.proname)
            union all
            select c.relname::text from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c12_tablas()) or c.relname = any (pg_temp.c12_vistas()))) x
     where x.n ~ '^(fn_banco_|fn_puente_|fn_estados_|fn_stripe_|fn_plaid_|fn_contador_|fn_cierre_|fn_costos_|fn_reporte_|fn_reparto_fase|fn_horas_|fn_jornal_|fn_margen_|fn_cobro_|fn_factura_|fn_anticipo_|fn_doc_|fn_qb_|fn_emision_|cxc_|v_cxc_|emision_|v_emision_)'
        or x.n !~ '^(fn_wip_|wip_|v_wip_)';
    select count(*) filter (where c.relrowsecurity) into v_rls
      from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c12_tablas());
    select count(*) into v_pol from pg_policies pl where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c12_tablas());
    select count(*) into v_inv
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relname = any (pg_temp.c12_vistas())
       and coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    -- columnas de periodos y de cuentas que c2-pruebas reescribe, fijadas por una vista de c12
    select coalesce(string_agg(distinct format('%s → %s.%s', cv.relname, rc.relname, a.attname), ', '), 'ninguna') into v_col
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class cv on cv.oid = rw.ev_class
      join pg_class rc on d.refclassid = 'pg_class'::regclass and rc.oid = d.refobjid
      join pg_attribute a on a.attrelid = rc.oid and a.attnum = d.refobjsubid
     where cv.relnamespace = 'public'::regnamespace and cv.relname = any (pg_temp.c12_vistas())
       and ((rc.relname = 'periodos' and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cerrado_rol', 'cerrado_conexion', 'cadena_al_cerrar'))
            or (rc.relname = 'cuentas' and a.attname in ('activa', 'saldo_normal')));
    -- vistas de c12 colgadas de una vista que no es de c12
    select coalesce(string_agg(distinct format('%s → %s', cv.relname, rc.relname), ', '), 'ninguna') into v_dep
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class cv on cv.oid = rw.ev_class
      join pg_class rc on d.refclassid = 'pg_class'::regclass and rc.oid = d.refobjid
     where cv.relnamespace = 'public'::regnamespace and cv.relname = any (pg_temp.c12_vistas())
       and rc.relkind in ('v', 'm') and rc.oid <> cv.oid and not (rc.relname = any (pg_temp.c12_vistas()));
    v_per := pg_temp.c12_permisos();
    select case when count(*) filter (where not k.ok) = 0 then 'verdes' else string_agg(k.vista, ', ') filter (where not k.ok) end into v_prot
      from (select x.vista, x.ok from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) x
             where x.vista = 'cuadre: protecciones del banco'
            union all
            select y.vista, y.ok from fn_estados_control('hoy', array['v_saldos_dinero']) y where y.vista = 'cuadre: protecciones de c4') k;
    v_obt := format('definer: %s | prefijos de otra capa: %s | RLS en %s de 6 tablas, %s policies | vistas security_invoker: %s de 5 | '
                    'vistas que fijan columnas que c2 reescribe: %s | vistas colgadas de vistas ajenas: %s | permisos (c2): %s | '
                    'protecciones del banco (c6) y de c4: %s', v_def, v_pre, v_rls, v_pol, v_inv, v_col, v_dep, v_per, v_prot);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: nada SECURITY DEFINER, ningún nombre con prefijo de otra capa ni fuera de fn_wip_/wip_/v_wip_, RLS y sus 16 policies, las vistas security_invoker que no fijan las columnas que c2-pruebas reescribe ni cuelgan de vistas ajenas, y «permisos» (c2) y las protecciones de c6 y de c4 en verde con c12 pegado',
    v_esp, v_obt || case when pg_temp.c12('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c12: ' || pg_temp.c12('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 5. La guarda de las tablas: a mano (sin la marca) nada entra, ni desde el
--    SQL Editor ni como el dueño por la API; y lo que es rastro (una
--    revisión, la foto de un ajuste) no se edita ni se borra ni con la marca.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'a mano, sin la marca: insert MX003, update MX003, delete MX003, truncate MX003 | el dueño por la API: MX003 | con la marca, '
                'una revisión no se edita (MX003) ni se borra (MX003), y la foto de un ajuste tampoco (MX003)';
begin
  if pg_temp.c12_omitir(5, 'la guarda de las tablas', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    perform pg_temp.c12_postear();
    a := pg_temp.c12_estado('insert into public.wip_obras (proyecto_id, modo, nota) values (''c12-prueba-a'', ''tm'', ''a mano'')', 'editor');
    b := pg_temp.c12_estado('update public.wip_config set exigir_desde = null', 'editor');
    c := pg_temp.c12_estado('delete from public.wip_revisiones', 'editor');
    d := pg_temp.c12_estado('truncate public.wip_ajuste_obras', 'editor');
    e := pg_temp.c12_estado('update public.wip_config set exigir_desde = null', 'dueno');
    perform set_config('mx_wip.escribe', 'wip_revisiones', true);
    f := pg_temp.c12_estado('update public.wip_revisiones set costo_estimado = 1 where proyecto_id = ''c12-prueba-a''', 'editor');
    g := pg_temp.c12_estado('delete from public.wip_revisiones where proyecto_id = ''c12-prueba-a''', 'editor');
    perform set_config('mx_wip.escribe', 'wip_ajuste_obras', true);
    h := pg_temp.c12_estado('update public.wip_ajuste_obras set sub_facturado = 1 where proyecto_id = ''c12-prueba-a''', 'editor');
    perform set_config('mx_wip.escribe', '', true);
    v_obt := format('a mano, sin la marca: insert %s, update %s, delete %s, truncate %s | el dueño por la API: %s | con la marca, una revisión '
                    'no se edita (%s) ni se borra (%s), y la foto de un ajuste tampoco (%s)', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda de las tablas de c12: a mano (sin la marca de sus funciones) nada entra, ni desde el SQL Editor ni como el dueño por la API (MX003); y lo que es rastro no se edita ni se borra ni con la marca',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. La configuración: se lee, se cambia a un mes del libro y a vacío (no se
--    exige), y sus frenos.
do $$
declare
  v_obt text; v_mes text := coalesce(pg_temp.c12('mes'), pg_temp.c12('mes_futuro')); r jsonb; a text; b text; c text;
  v_esp text;
begin
  v_esp := format('lee: sí | a %s: sí, y lo dice | a vacío: no se exige | mal escrito: 22023 | un mes que no existe: 22023 | otra clave: '
                  '22023 | no es un objeto: 22023', v_mes);
  begin
    perform pg_temp.c12_ser('dueno');
    r := fn_wip_config('{}'::jsonb);
    a := case when r ? 'exigir_desde' and r ? 'nota' then 'sí' else r::text end;
    r := fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    b := case when r->>'exigir_desde' = v_mes and r->>'nota' like '%' || fn_wip_mes(v_mes) || '%' then 'sí, y lo dice' else r::text end;
    r := fn_wip_config('{"exigir_desde": null}'::jsonb);
    c := case when r->'exigir_desde' = 'null'::jsonb and r->>'nota' like '%todavía no exige%' then 'no se exige' else r::text end;
    perform pg_temp.c12_ser('editor');
    v_obt := format('lee: %s | a %s: %s | a vacío: %s | mal escrito: %s | un mes que no existe: %s | otra clave: %s | no es un objeto: %s',
                    a, v_mes, b, c,
                    pg_temp.c12_estado('select public.fn_wip_config(''{"exigir_desde": "noviembre"}''::jsonb)'),
                    pg_temp.c12_estado('select public.fn_wip_config(''{"exigir_desde": "2019-01"}''::jsonb)'),
                    pg_temp.c12_estado('select public.fn_wip_config(''{"exigir": "2026-11"}''::jsonb)'),
                    pg_temp.c12_estado('select public.fn_wip_config(''["2026-11"]''::jsonb)'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'la configuración (desde qué mes exige el cierre el WIP): se lee, se cambia a un mes del libro y a vacío, y sus frenos (22023)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. QUÉ OBRAS LLEVAN WIP. La regla: la residencial o comercial con contrato
--    en su ficha, sí; la de servicio (aunque tenga contrato) y la que no
--    tiene contrato, no. La marca de Edgar manda: «contrato», «tm», y «auto»
--    vuelve a la regla; cada cambio queda en su historia. Y sus frenos.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text;
  v_esp text := 'la regla: A sí (de precio fijo), H no (de servicio), I no (de servicio, aunque tenga contrato), K no (sin contrato) | '
                'marcada «contrato», I sí | marcada «tm», A no | de vuelta a la regla, A sí, con 2 cambios en su historia | modo raro '
                '22023, sin nota 22023, una obra que no existe MX008, otra clave 22023';
begin
  begin
    perform pg_temp.c12_sembrar();
    select format('A %s, H %s, I %s, K %s',
             (select case when o.lleva_wip and o.motivo like 'De precio fijo%' then 'sí (de precio fijo)' else 'NO: ' || o.motivo end from v_wip_obras o where o.proyecto_id = 'c12-prueba-a'),
             (select case when not o.lleva_wip and o.motivo like 'Es de servicio%' then 'no (de servicio)' else 'SÍ: ' || o.motivo end from v_wip_obras o where o.proyecto_id = 'c12-prueba-h'),
             (select case when not o.lleva_wip and o.motivo like 'Es de servicio%' and o.contrato = 5000 then 'no (de servicio, aunque tenga contrato)' else 'SÍ: ' || o.motivo end from v_wip_obras o where o.proyecto_id = 'c12-prueba-i'),
             (select case when not o.lleva_wip and o.motivo like 'No tiene contrato%' then 'no (sin contrato)' else 'SÍ: ' || o.motivo end from v_wip_obras o where o.proyecto_id = 'c12-prueba-k'))
      into a;
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-i', '{"modo": "contrato", "nota": "servicio con precio cerrado"}');
    select case when o.lleva_wip and o.marca = 'contrato' then 'sí' else 'no' end into b from v_wip_obras o where o.proyecto_id = 'c12-prueba-i';
    perform fn_wip_obra('c12-prueba-a', '{"modo": "tm", "nota": "se cobra por horas"}');
    select case when not o.lleva_wip and o.marca = 'tm' and o.marca_nota = 'se cobra por horas' then 'no' else 'sí' end into c
      from v_wip_obras o where o.proyecto_id = 'c12-prueba-a';
    perform fn_wip_obra('c12-prueba-a', '{"modo": "contrato", "nota": "no, es de precio fijo"}');
    perform fn_wip_obra('c12-prueba-a', '{"modo": "auto"}');
    select format('%s, con %s cambios en su historia', case when o.lleva_wip and o.marca is null then 'sí' else 'no' end,
                  (select jsonb_array_length(w.historial) from wip_obras w where w.proyecto_id = 'c12-prueba-a'))
      into d from v_wip_obras o where o.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('editor');
    e := format('modo raro %s, sin nota %s, una obra que no existe %s, otra clave %s',
                pg_temp.c12_estado('select public.fn_wip_obra(''c12-prueba-b'', ''{"modo": "fijo", "nota": "x"}''::jsonb)'),
                pg_temp.c12_estado('select public.fn_wip_obra(''c12-prueba-b'', ''{"modo": "tm"}''::jsonb)'),
                pg_temp.c12_estado('select public.fn_wip_obra(''c12-prueba-zz'', ''{"modo": "tm", "nota": "x"}''::jsonb)'),
                pg_temp.c12_estado('select public.fn_wip_obra(''c12-prueba-b'', ''{"modo": "tm", "nota": "x", "desde": "hoy"}''::jsonb)'));
    v_obt := format('la regla: %s | marcada «contrato», I %s | marcada «tm», A %s | de vuelta a la regla, A %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'QUÉ OBRAS LLEVAN WIP: la regla (residencial o comercial con contrato: sí; de servicio, aunque tenga contrato, y sin contrato: no) y la marca de Edgar, que manda («contrato», «tm», «auto» vuelve a la regla), con su nota y su historia; y sus frenos',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL CÁLCULO, cada columna a mano
-- ---------------------------------------------------------------------
-- Las líneas que el WIP de hoy postearía por una obra de prueba: «cuenta
-- monto / …» (la cuenta de ingreso sale como «ingreso»: la regla del tipo de
-- obra es de cada base).
create or replace function pg_temp.c12_plan_lineas(p_obra text, p_per text default null) returns text language sql as $$
  select coalesce(string_agg(format('%s %s', case when (l.v->>'cuenta') in (select m.cuenta from mapeo_tipo_proyecto m) then 'ingreso'
                                                  else l.v->>'cuenta' end, l.v->>'monto'), ' / ' order by l.o), '-')
    from jsonb_array_elements(fn_wip_plan(coalesce(p_per, pg_temp.c12('mes')))->'lineas') with ordinality l(v, o)
   where l.v->>'proyecto_id' = p_obra
$$;
-- ¿Nombra esa fila del control, en rojo, a la obra de prueba de esa letra?
create or replace function pg_temp.c12_nombra(p_orden int, p_letra text, p_per text default null) returns text language sql as $$
  select case when not c.ok and c.detalle like '%C12 PRUEBA Obra ' || upper(p_letra) || '%' then 'sí' else 'no' end
    from fn_wip_control(coalesce(p_per, pg_temp.c12('mes'))) c where c.orden = p_orden
$$;
-- La cuenta de ingreso que el puente de facturas usa para un tipo de obra.
create or replace function pg_temp.c12_ingreso(p_tipo text) returns text language sql as $$
  select m.cuenta from mapeo_tipo_proyecto m where m.tipo = p_tipo
$$;

-- 8. Una obra SUB-facturada. Precio 10,000; costo estimado 6,000; lleva
--    3,000 de costo (50 %): ganó 5,000; le facturaron 2,000 → sub-facturada
--    3,000 (Dr 1200 / Cr su ingreso). Le faltan 3,000 de costo, y lleva
--    2,000 de utilidad de los 4,000 estimados.
do $$
declare
  v_obt text; a text; b text; c text; d text;
  v_esp text := 'antes de revisar: pendiente {revision}: sin cifras | revisada: lista: precio 10000.00, est 6000.00, util est 4000.00, '
                'costo 3000.00, 50.00 %, ganado 5000.00, fact 2000.00, sub 3000.00, sobre 0.00, para terminar 3000.00, util 2000.00, '
                'perdida 0.00, prov 0.00 | su cuenta de ingreso es la del puente de facturas para una obra comercial: sí | lo que se '
                'postearía: 1200 3000.00 / ingreso -3000.00';
begin
  if pg_temp.c12_omitir(8, 'una obra sub-facturada', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    a := pg_temp.c12_fila('c12-prueba-a');
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    b := pg_temp.c12_fila('c12-prueba-a');
    select case when s.cuenta_ingreso = pg_temp.c12_ingreso('comercial') then 'sí' else 'no: ' || coalesce(s.cuenta_ingreso, 'nula') end into c
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    d := pg_temp.c12_plan_lineas('c12-prueba-a');
    v_obt := format('antes de revisar: %s | revisada: %s | su cuenta de ingreso es la del puente de facturas para una obra comercial: %s | '
                    'lo que se postearía: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'una obra SUB-facturada, cada columna a mano: precio 10,000, costo estimado 6,000, costo a la fecha 3,000 (50 %), ganado 5,000, facturado 2,000 → sub-facturado 3,000 (Dr 1200 / Cr su ingreso), costo para terminar 3,000, utilidad a la fecha 2,000 de 4,000 estimados',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. Una obra SOBRE-facturada. Precio 20,000; costo estimado 16,000; lleva
--    4,000 (25 %): ganó 5,000; le facturaron 9,000 → sobre-facturada 4,000
--    (Dr su ingreso / Cr 2400).
do $$
declare
  v_obt text; a text; b text; c text;
  v_esp text := 'lista: precio 20000.00, est 16000.00, util est 4000.00, costo 4000.00, 25.00 %, ganado 5000.00, fact 9000.00, sub 0.00, '
                'sobre 4000.00, para terminar 12000.00, util 1000.00, perdida 0.00, prov 0.00 | su cuenta de ingreso es la de una obra '
                'residencial: sí | lo que se postearía: ingreso 4000.00 / 2400 -4000.00';
begin
  if pg_temp.c12_omitir(9, 'una obra sobre-facturada', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-b', 4000);
    perform pg_temp.c12_factura(2, 'c12-prueba-b', 9000);
    perform pg_temp.c12_rev('c12-prueba-b', '{"costo_estimado": "16000"}');
    a := pg_temp.c12_fila('c12-prueba-b');
    select case when s.cuenta_ingreso = pg_temp.c12_ingreso('residencial') then 'sí' else 'no: ' || coalesce(s.cuenta_ingreso, 'nula') end into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-b';
    c := pg_temp.c12_plan_lineas('c12-prueba-b');
    v_obt := format('%s | su cuenta de ingreso es la de una obra residencial: %s | lo que se postearía: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'una obra SOBRE-facturada, cada columna a mano: precio 20,000, costo estimado 16,000, costo a la fecha 4,000 (25 %), ganado 5,000, facturado 9,000 → sobre-facturado 4,000 (Dr su ingreso / Cr 2400)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. EL DEPÓSITO NO ES AVANCE. Una obra con su depósito facturado (un hito
--     es_deposito) y sin costo: 0 % de avance, nada ganado, y lo facturado
--     entero sale sobre-facturado (2400). Con el primer costo (2,100 de
--     21,000: 10 %) gana 3,000 y el sobre-facturado baja a 3,000.
do $$
declare
  v_obt text; a text; b text; c text;
  v_esp text := 'con el depósito y sin costo: lista: precio 30000.00, est 21000.00, util est 9000.00, costo 0.00, 0.00 %, ganado 0.00, '
                'fact 6000.00, sub 0.00, sobre 6000.00, para terminar 21000.00, util 0.00, perdida 0.00, prov 0.00 | lo que se postearía: '
                'ingreso 6000.00 / 2400 -6000.00 | con el primer costo (2100 de 21000): 10.00 %, ganado 3000.00, sobre 3000.00';
begin
  if pg_temp.c12_omitir(10, 'el depósito sin costo', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    insert into hitos (id, proyecto_id, titulo, monto, estado, es_deposito) overriding system value
    values (-1200010, 'c12-prueba-d', 'C12 PRUEBA: depósito', 6000, 'facturado', true);
    perform pg_temp.c12_factura(3, 'c12-prueba-d', 6000, 4, -1200010);
    perform pg_temp.c12_rev('c12-prueba-d', '{"costo_estimado": "21000"}');
    a := pg_temp.c12_fila('c12-prueba-d');
    b := pg_temp.c12_plan_lineas('c12-prueba-d');
    perform pg_temp.c12_costo('c12-prueba-d', 2100, 20);
    select format('%s %%, ganado %s, sobre %s', s.pct_avance, s.ingreso_ganado, s.sobre_facturado) into c
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-d';
    v_obt := format('con el depósito y sin costo: %s | lo que se postearía: %s | con el primer costo (2100 de 21000): %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'EL DEPÓSITO NO ES AVANCE: una obra con su depósito facturado (hito es_deposito) y sin costo tiene 0 % de avance y nada ganado, y lo facturado entero sale sobre-facturado (Dr su ingreso / Cr 2400); con el primer costo empieza a ganar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. LA PÉRDIDA, completa y una sola vez. Precio 10,000 y costo estimado
--     12,000: pierde 2,000. La provisión (Dr 5950 / Cr 2410) es lo que falta
--     por reconocer: sin costo, la pérdida entera; a la mitad (6,000 de
--     costo: ganó 5,000, ya perdió 1,000), 1,000; con todo el costo, nada.
--     En los tres momentos el resultado acumulado de la obra (ganado − costo
--     − provisión) es −2,000. Y con centavos (precio 10,000, estimado
--     11,000, costo 3,333.33): ganado 3,030.30, provisión 696.97, −1,000.00.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text;
  v_esp text := 'sin costo: 0.00 %, ganado 0.00, util 0.00, pérdida 2000.00, provisión 2000.00, resultado acumulado -2000.00 | a la '
                'mitad: 50.00 %, ganado 5000.00, util -1000.00, pérdida 2000.00, provisión 1000.00, resultado acumulado -2000.00 | lo que '
                'se postearía: 1200 5000.00 / ingreso -5000.00 / 5950 1000.00 / 2410 -1000.00 | con todo el costo: 100.00 %, ganado '
                '10000.00, util -2000.00, pérdida 2000.00, provisión 0.00, resultado acumulado -2000.00 | con centavos: 30.30 %, ganado '
                '3030.30, util -303.03, pérdida 1000.00, provisión 696.97, resultado acumulado -1000.00';
begin
  if pg_temp.c12_omitir(11, 'la pérdida', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_rev('c12-prueba-c', '{"costo_estimado": "12000"}');
    select format('%s %%, ganado %s, util %s, pérdida %s, provisión %s, resultado acumulado %s', s.pct_avance, s.ingreso_ganado,
                  s.utilidad_fecha, s.perdida_total, s.perdida_provision, s.ingreso_ganado - s.costo_fecha - s.perdida_provision) into a
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-c';
    perform pg_temp.c12_costo('c12-prueba-c', 6000);
    select format('%s %%, ganado %s, util %s, pérdida %s, provisión %s, resultado acumulado %s', s.pct_avance, s.ingreso_ganado,
                  s.utilidad_fecha, s.perdida_total, s.perdida_provision, s.ingreso_ganado - s.costo_fecha - s.perdida_provision) into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-c';
    c := pg_temp.c12_plan_lineas('c12-prueba-c');
    perform pg_temp.c12_costo('c12-prueba-c', 6000, 15, '5200');
    select format('%s %%, ganado %s, util %s, pérdida %s, provisión %s, resultado acumulado %s', s.pct_avance, s.ingreso_ganado,
                  s.utilidad_fecha, s.perdida_total, s.perdida_provision, s.ingreso_ganado - s.costo_fecha - s.perdida_provision) into d
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-c';
    perform pg_temp.c12_costo('c12-prueba-p', 3333.33);
    perform pg_temp.c12_rev('c12-prueba-p', '{"costo_estimado": "11000.00"}');
    select format('%s %%, ganado %s, util %s, pérdida %s, provisión %s, resultado acumulado %s', s.pct_avance, s.ingreso_ganado,
                  s.utilidad_fecha, s.perdida_total, s.perdida_provision, s.ingreso_ganado - s.costo_fecha - s.perdida_provision) into e
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-p';
    v_obt := format('sin costo: %s | a la mitad: %s | lo que se postearía: %s | con todo el costo: %s | con centavos: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'LA PÉRDIDA, completa y una sola vez: con el costo estimado (12,000) por encima del precio (10,000) la provisión (Dr 5950 / Cr 2410) es lo que falta por reconocer —sin costo, los 2,000 enteros; a la mitad, 1,000; con todo el costo, nada— y el resultado acumulado de la obra es −2,000 en los tres momentos; y con centavos cuadra al centavo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. Una obra que PASA DE 100 %. Precio 10,000 y estimado 5,000; con 3,000
--     de costo va al 60 %. Llega más costo (6,500 en total): 130 % real. Más
--     costo que el estimado sin estar terminada es un estimado viejo: la obra
--     queda «pendiente» (le falta: estimado), FUERA del ajuste —con el avance
--     topado en 100 % ganaría el precio entero sin haber terminado—, y el
--     cuadre 60 la pone en rojo. Ninguna nota lo salta: revisar con un
--     estimado menor que el costo no entra (MX005), con nota o sin ella.
--     Subiendo el estimado vuelve a entrar; y si se deja justo en lo que
--     lleva (100 %), entra y lo avisa el 125.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text;
  v_esp text := 'al revisar (3000 de 5000): 60.00 %, ganado 6000.00 | con 6500 de costo: pendiente {estimado}, real 130.00 %, fuera del '
                'ajuste, y lo dice: sí | el control 60 la nombra: sí | revisar otra vez con 5000, sin nota: MX005; con su nota: MX005 | '
                'subiendo el estimado a 13000: lista, 50.00 %, y el 60 ya no la nombra | con el estimado justo en lo que lleva (6500): '
                'lista, 100.00 %, y el aviso 125 la nombra: sí';
begin
  if pg_temp.c12_omitir(12, 'una obra que pasa de 100 %', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-e', 3000);
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "5000"}');
    select format('%s %%, ganado %s', s.pct_avance, s.ingreso_ganado) into a
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-e';
    perform pg_temp.c12_costo('c12-prueba-e', 3500, 14);
    select format('%s {%s}, real %s %%, %s, y lo dice: %s', s.estado, array_to_string(s.falta, ','), s.pct_real,
                  case when s.en_ajuste then 'DENTRO del ajuste' else 'fuera del ajuste' end,
                  case when s.pasa_de_100 and s.falta_texto like 'Lleva $6,500.00 de costo y su costo estimado revisado es $5,000.00 (130 %): ese estimado quedó viejo.%'
                            and exists (select 1 from unnest(s.avisos) t where t like '%no entra en el ajuste hasta que subas el costo estimado%')
                       then 'sí' else 'no: ' || coalesce(s.falta_texto, 'sin texto') end)
      into b from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-e';
    c := pg_temp.c12_nombra(60, 'e');
    d := 'sin nota: ' || pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-e'', ' || quote_literal(pg_temp.c12('mes')) || ', ''{"costo_estimado": "5000"}''::jsonb)')
         || '; con su nota: ' || pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-e'', ' || quote_literal(pg_temp.c12('mes'))
                                                  || ', ''{"costo_estimado": "5000", "nota": "C12 PRUEBA: el excedente lo cubre un cambio que falta firmar"}''::jsonb)');
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "13000", "nota": "C12 PRUEBA: estimado puesto al día"}');
    select format('%s, %s %%, y el 60 %s', s.estado, s.pct_avance,
                  case pg_temp.c12_nombra(60, 'e') when 'no' then 'ya no la nombra' else 'la sigue nombrando' end)
      into e from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-e';
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "6500", "nota": "C12 PRUEBA: justo lo que lleva"}');
    select format('%s, %s %%, y el aviso 125 la nombra: %s', s.estado, s.pct_avance, pg_temp.c12_nombra(125, 'e'))
      into f from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-e';
    v_obt := format('al revisar (3000 de 5000): %s | con 6500 de costo: %s | el control 60 la nombra: %s | revisar otra vez con 5000, %s | '
                    'subiendo el estimado a 13000: %s | con el estimado justo en lo que lleva (6500): %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'una obra que PASA DE 100 %: con más costo (6,500) que su estimado revisado (5,000) queda pendiente (su estimado quedó viejo) y FUERA del ajuste, y el control 60 la pone en rojo; ninguna nota lo salta (un estimado menor que el costo no entra: MX005); subiendo el estimado vuelve a entrar, y justo al 100 % lo avisa el 125',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. EL REDONDEO: el ganado se calcula de una vez (precio × costo ÷ costo
--     estimado) y se redondea una vez, medio centavo hacia arriba. A mano:
--     9,999.99 × 3,333.33 ÷ 7,777.77 = 4,285.7100… → 4,285.71 (42.86 %); y
--     1,001.00 × 100 ÷ 800 = 125.125 → 125.13. Con el costo igual al
--     estimado, el ganado es el precio, al centavo.
do $$
declare
  v_obt text; a text; b text; c text;
  v_esp text := 'lista: precio 9999.99, est 7777.77, util est 2222.22, costo 3333.33, 42.86 %, ganado 4285.71, fact 1234.56, sub 3051.15, '
                'sobre 0.00, para terminar 4444.44, util 952.38, perdida 0.00, prov 0.00 | medio centavo (1001.00 × 100 ÷ 800 = 125.125): '
                '12.50 %, ganado 125.13 | con el costo igual al estimado: 100.00 %, ganado 9999.99';
begin
  if pg_temp.c12_omitir(13, 'el redondeo', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-m', 3333.33);
    perform pg_temp.c12_factura(4, 'c12-prueba-m', 1234.56);
    perform pg_temp.c12_rev('c12-prueba-m', '{"costo_estimado": "7777.77"}');
    a := pg_temp.c12_fila('c12-prueba-m');
    update finanzas_proyecto set contrato = 1001.00 where proyecto_id = 'c12-prueba-l';
    perform pg_temp.c12_costo('c12-prueba-l', 100);
    perform pg_temp.c12_rev('c12-prueba-l', '{"costo_estimado": "800.00"}');
    select format('%s %%, ganado %s', s.pct_avance, s.ingreso_ganado) into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-l';
    perform pg_temp.c12_rev('c12-prueba-m', '{"costo_estimado": "3333.33"}');
    select format('%s %%, ganado %s', s.pct_avance, s.ingreso_ganado) into c
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-m';
    v_obt := format('%s | medio centavo (1001.00 × 100 ÷ 800 = 125.125): %s | con el costo igual al estimado: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'EL REDONDEO: el ingreso ganado es precio × costo ÷ costo estimado, calculado de una vez y redondeado una sola vez (medio centavo hacia arriba); a mano con centavos en todo, y con el costo igual al estimado el ganado es el precio, al centavo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. Una obra que YA ANDABA ANTES DEL LIBRO. Tiene de antes una factura de
--     8,000 y un trabajo externo de 5,000: la base lo PROPONE. Mientras
--     Edgar no lo confirma, la obra no tiene cifras. Confirmada la propuesta
--     (sin nota: son los números de la app), entra con todo desde el inicio:
--     costo 7,000 del libro + 5,000 de antes = 12,000 de 24,000 (50 %); ganó
--     20,000; facturado 10,000 + 8,000 = 18,000 → sub-facturada 2,000. Otros
--     números (los de QuickBooks) piden su nota; con ella, 13,000 de costo:
--     54.17 %, ganado 21,666.67, sub 3,666.67; y la confirmación anterior
--     queda.
do $$
declare
  v_obt text; r jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'la propuesta: costo 5000.00 (1 trabajo externo por 5000.00) y facturado 8000.00 (1 factura) | sin confirmar: pendiente '
                '{antes}: precio 40000.00, sin cifras | confirmada: lista: precio 40000.00, est 24000.00, util est 16000.00, costo '
                '12000.00, 50.00 %, ganado 20000.00, fact 18000.00, sub 2000.00, sobre 0.00, para terminar 12000.00, util 8000.00, perdida '
                '0.00, prov 0.00 (costo 7000.00 del libro + 5000.00 de antes; facturado 10000.00 + 8000.00), y lo dice sin hablar de un '
                'ajuste que no hay: sí | otros números sin nota: 22023 | con su nota: 54.17 %, ganado 21666.67, sub 3666.67 | la anterior '
                'queda: 2 confirmaciones, 1 vigente, y repetir la misma no añade otra';
begin
  if pg_temp.c12_omitir(14, 'una obra que ya andaba antes del libro, confirmada', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_factura(5, 'c12-prueba-f', 8000, -20);
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, costo) overriding system value
    values (-1200014, 'c12-prueba-f', 'C12 PRUEBA: sub de antes del libro', pg_temp.c12('libro_desde')::date - 18, 'ajuste', 5000.00);
    perform pg_temp.c12_costo('c12-prueba-f', 7000);
    perform pg_temp.c12_factura(6, 'c12-prueba-f', 10000);
    perform pg_temp.c12_rev('c12-prueba-f', '{"costo_estimado": "24000"}');
    perform pg_temp.c12_ser('dueno');
    r := fn_wip_antes_propuesta('c12-prueba-f');
    perform pg_temp.c12_ser('editor');
    a := format('costo %s (%s trabajo externo por %s) y facturado %s (%s factura)', r->'costo'->>'total', r->'costo'->'trabajos_externos'->>'n',
                r->'costo'->'trabajos_externos'->>'monto', r->'facturado'->>'total', r->'facturado'->'facturas'->>'n');
    b := pg_temp.c12_fila('c12-prueba-f');
    r := pg_temp.c12_antes('c12-prueba-f', '{"costo": "5000", "facturado": "8000"}');
    select format('%s (costo %s del libro + %s de antes; facturado %s + %s), y lo dice sin hablar de un ajuste que no hay: %s',
                  pg_temp.c12_fila('c12-prueba-f'), s.costo_libro, s.costo_antes, s.facturado_libro, s.facturado_antes,
                  case when r->>'nota' = 'Confirmado lo de antes del libro de «C12 PRUEBA Obra F»: costo $5,000.00 y facturado $8,000.00.'
                            -- (si otro mes abierto de esta base tiene su ajuste real posteado, lo avisa: con su nombre)
                            or (r->>'nota' like 'Confirmado lo de antes del libro de «C12 PRUEBA Obra F»: costo $5,000.00 y facturado $8,000.00. '
                                                'El ajuste de _% ya estaba posteado: mira si sigue al día%'
                                and exists (select 1 from wip_ajustes x join periodos q on q.periodo = x.periodo
                                             where x.deshecho_el is null and q.estado = 'abierto'))
                       then 'sí' else 'no: ' || coalesce(r->>'nota', 'sin nota') end) into c
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-f';
    d := pg_temp.c12_estado('select public.fn_wip_antes(''c12-prueba-f'', ''{"costo": "6000", "facturado": "8000"}''::jsonb)');
    perform pg_temp.c12_antes('c12-prueba-f', '{"costo": "6000", "facturado": "8000", "nota": "C12 PRUEBA: costo por obra de QuickBooks al 30-sep"}');
    select format('%s %%, ganado %s, sub %s', s.pct_avance, s.ingreso_ganado, s.sub_facturado) into e
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-f';
    r := pg_temp.c12_antes('c12-prueba-f', '{"costo": "6000", "facturado": "8000", "nota": "C12 PRUEBA: costo por obra de QuickBooks al 30-sep"}');
    select format('%s confirmaciones, %s vigente, y repetir la misma %s', count(*), count(*) filter (where x.sustituida_el is null),
                  case when (r->>'ya_estaba')::boolean then 'no añade otra' else 'AÑADE otra' end) into f
      from wip_antes x where x.proyecto_id = 'c12-prueba-f';
    v_obt := format('la propuesta: %s | sin confirmar: %s | confirmada: %s | otros números sin nota: %s | con su nota: %s | la anterior '
                    'queda: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'una obra que YA ANDABA ANTES DEL LIBRO: la base propone lo de antes desde los papeles de la app (una factura y un trabajo externo); sin confirmar no tiene cifras; confirmada, el costo y lo facturado cuentan desde el inicio (libro + lo de antes), a mano; otros números piden su nota, y la confirmación anterior queda',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. Otra que ya andaba, SIN CONFIRMAR: no entra en el ajuste, y se dice (en
--     su fila, en la respuesta de postear y en el aviso 110). Confirmado lo
--     de antes (0 de costo y 3,000 facturados, lo que proponen los papeles),
--     entra: 2,000 de 9,000 (22.22 %), ganó 3,333.33, facturado 3,000 → sub
--     333.33; y el ajuste ya posteado deja de estar al día: «entra…».
do $$
declare
  v_obt text; r jsonb; a text; b text; c text; d text; e text;
  v_esp text := 'pendiente {antes}: precio 15000.00, sin cifras, y dice por qué: sí | al postear queda fuera (le falta: antes) y sin líneas '
                'suyas: - | el aviso 110 la nombra: sí | confirmado lo de antes: lista: precio 15000.00, est 9000.00, util est 6000.00, '
                'costo 2000.00, 22.22 %, ganado 3333.33, fact 3000.00, sub 333.33, sobre 0.00, para terminar 7000.00, util 1333.33, perdida '
                '0.00, prov 0.00; y avisa de que el ajuste del mes ya estaba posteado: sí | y el ajuste ya posteado deja de estar al día: '
                'entra C12 PRUEBA Obra G (sub-facturado $333.33)';
begin
  if pg_temp.c12_omitir(15, 'una obra que ya andaba, sin confirmar', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_factura(7, 'c12-prueba-g', 3000, -10);
    perform pg_temp.c12_costo('c12-prueba-g', 2000);
    perform pg_temp.c12_rev('c12-prueba-g', '{"costo_estimado": "9000"}');
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    select format('%s, y dice por qué: %s', pg_temp.c12_fila('c12-prueba-g'),
                  case when s.falta_texto like '%Ya andaba antes del libro%' and s.falta_texto like '%no entra en el ajuste%' then 'sí' else 'no' end)
      into a from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-g';
    r := pg_temp.c12_postear();
    select format('queda fuera (le falta: %s) y sin líneas suyas: %s',
                  coalesce((select string_agg(e.v, ',') from jsonb_array_elements(r->'fuera') x, jsonb_array_elements_text(x->'falta') e(v)
                             where x->>'proyecto_id' = 'c12-prueba-g'), 'NO está fuera'),
                  (select coalesce(string_agg(l.cuenta, ','), '-') from asiento_lineas l
                    where l.asiento_id = (r->'asiento'->>'id')::uuid and l.proyecto_id = 'c12-prueba-g'))
      into b;
    c := pg_temp.c12_nombra(110, 'g');
    r := pg_temp.c12_antes('c12-prueba-g', '{"costo": "0", "facturado": "3000"}');
    d := pg_temp.c12_fila('c12-prueba-g') || '; y avisa de que el ajuste del mes ya estaba posteado: '
         || case when r->>'nota' like 'Confirmado lo de antes del libro de «C12 PRUEBA Obra G»: costo $0.00 y facturado $3,000.00. El ajuste de %'
                                      || fn_wip_mes(pg_temp.c12('mes')) || '% ya estaba posteado: mira si sigue al día y, si no, vuelve a postearlo.'
                 then 'sí' else 'no: ' || coalesce(r->>'nota', 'sin nota') end;
    e := coalesce(fn_wip_ajuste_estado(pg_temp.c12('mes'))->>'cambios', 'sigue al día');
    v_obt := format('%s | al postear %s | el aviso 110 la nombra: %s | confirmado lo de antes: %s | y el ajuste ya posteado deja de estar al '
                    'día: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'una obra que ya andaba antes del libro y NO tiene lo de antes confirmado: no tiene cifras, no entra en el ajuste (y se dice: en su fila, en la respuesta de postear y en el aviso 110); confirmado, entra con sus cifras a mano, y el ajuste ya posteado deja de estar al día',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. Una obra de SERVICIO (T&M) no lleva WIP: con costo y factura, no sale,
--     y no se puede revisar (MX008). Una de servicio con contrato tampoco
--     (la regla); marcada «contrato», entra: pendiente de revisar; revisada,
--     400 de 2,000 (20 %): ganó 1,000 de 5,000.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text;
  v_esp text := 'de servicio, con costo y factura: no sale | revisarla: MX008 | de servicio con contrato: no sale | marcada «contrato»: '
                'pendiente {revision}: sin cifras | revisada: lista: precio 5000.00, est 2000.00, util est 3000.00, costo 400.00, 20.00 %, '
                'ganado 1000.00, fact 0.00, sub 1000.00, sobre 0.00, para terminar 1600.00, util 600.00, perdida 0.00, prov 0.00';
begin
  if pg_temp.c12_omitir(16, 'una obra de servicio (T&M) no entra', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-h', 500);
    perform pg_temp.c12_factura(8, 'c12-prueba-h', 700);
    perform pg_temp.c12_costo('c12-prueba-i', 400);
    a := pg_temp.c12_fila('c12-prueba-h');
    b := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-h'', ' || quote_literal(pg_temp.c12('mes')) || ', ''{"costo_estimado": "900"}''::jsonb)');
    c := pg_temp.c12_fila('c12-prueba-i');
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-i', '{"modo": "contrato", "nota": "C12 PRUEBA: servicio con precio cerrado"}');
    perform pg_temp.c12_ser('editor');
    d := pg_temp.c12_fila('c12-prueba-i');
    perform pg_temp.c12_rev('c12-prueba-i', '{"costo_estimado": "2000"}');
    e := pg_temp.c12_fila('c12-prueba-i');
    v_obt := format('de servicio, con costo y factura: %s | revisarla: %s | de servicio con contrato: %s | marcada «contrato»: %s | revisada: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'una obra de SERVICIO (T&M) no lleva WIP: con costo y factura no sale en el schedule y no se puede revisar (MX008); una de servicio con contrato tampoco, hasta que Edgar la marca «contrato»: entonces entra, pendiente de revisar, y revisada se calcula como las demás',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. Una obra TERMINADA. En el mes va en obra: 5,000 de 6,000 (83.33 %),
--     ganó 6,666.67 de 8,000, facturado 6,000 → sub 666.67. Después termina
--     (la app la tiene completada) y llega un último costo de 500: el mes
--     siguiente la propone como terminada; revisada así es 100 %: el costo
--     final es el que lleva (5,500), ganó el precio (8,000) y lo que falta
--     por facturar (2,000) queda sub-facturado. El mes de después SIGUE
--     ENTRANDO mientras no se facture entera (antes dejaba de entrar y ese
--     sub-facturado se perdía sin aviso); facturados los 2,000, ya no sale.
--     No se termina una obra que la app tiene en obra (MX008), y una
--     terminada no lleva costo estimado (22023).
do $$
declare
  v_obt text; v_sig text := pg_temp.c12('mes_sig'); v_des text; a text; b text; c text; d text; e text; f text;
  v_esp text := 'en el mes, en obra: 83.33 %, ganado 6666.67, sub 666.67 | terminada después, el mes siguiente la propone como terminada: '
                'pendiente {revision}: sin cifras, propone terminada: sí | revisada como terminada: lista: precio 8000.00, est 5500.00, util '
                'est 2500.00, costo 5500.00, 100.00 %, ganado 8000.00, fact 6000.00, sub 2000.00, sobre 0.00, para terminar 0.00, util '
                '2500.00, perdida 0.00, prov 0.00 | el mes de después, con 2,000 por facturar: sigue entrando, pendiente {revision}: sin '
                'cifras, y propone terminada: sí | facturada entera: no sale | terminar una que sigue en obra: MX008 | terminada con '
                'costo estimado: 22023';
begin
  if pg_temp.c12_omitir(17, 'una obra terminada', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-j', 5000);
    perform pg_temp.c12_factura(9, 'c12-prueba-j', 6000);
    perform pg_temp.c12_rev('c12-prueba-j', '{"costo_estimado": "6000"}');
    select format('%s %%, ganado %s, sub %s', s.pct_avance, s.ingreso_ganado, s.sub_facturado) into a
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-j';
    update proyectos set estado = 'completado' where id = 'c12-prueba-j';
    perform pg_temp.c12_costo('c12-prueba-j', 500, 2, '5100', v_sig);
    select format('%s, propone terminada: %s', pg_temp.c12_fila('c12-prueba-j', v_sig), case when s.propuesta_terminada then 'sí' else 'no' end) into b
      from fn_wip_schedule(v_sig) s where s.proyecto_id = 'c12-prueba-j';
    perform pg_temp.c12_rev('c12-prueba-j', '{"terminada": true}', v_sig);
    c := pg_temp.c12_fila('c12-prueba-j', v_sig);
    select q.periodo into v_des from periodos q
     where q.tipo = 'mes' and q.desde = (select x.hasta + 1 from periodos x where x.periodo = v_sig);
    select coalesce((select format('sigue entrando, %s, y propone terminada: %s', pg_temp.c12_fila('c12-prueba-j', v_des),
                                   case when s.propuesta_terminada then 'sí' else 'no' end)
                       from fn_wip_calcular(v_des, 'c12-prueba-j', true) s), 'NO SALE') into d;
    -- (se factura lo que faltaba, en el mes siguiente: lo facturado ya es su precio)
    perform pg_temp.c12_factura(10, 'c12-prueba-j', 2000, (select (q.desde - pg_temp.c12_d(0)) + 5 from periodos q where q.periodo = v_sig));
    select d || ' | facturada entera: ' || coalesce((select 'SALE: ' || s.estado from fn_wip_calcular(v_des, 'c12-prueba-j', false) s), 'no sale') into d;
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    e := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-a'', ' || quote_literal(pg_temp.c12('mes')) || ', ''{"terminada": true}''::jsonb)');
    f := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-j'', ' || quote_literal(v_sig) || ', ''{"terminada": true, "costo_estimado": "5500"}''::jsonb)');
    v_obt := format('en el mes, en obra: %s | terminada después, el mes siguiente la propone como terminada: %s | revisada como terminada: '
                    '%s | el mes de después, con 2,000 por facturar: %s | terminar una que sigue en obra: %s | terminada con costo estimado: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'una obra TERMINADA: el mes siguiente a estar en el WIP la propone como terminada; revisada así es 100 % (su costo final es el que lleva, gana el precio y lo que falta por facturar queda sub-facturado); SIGUE ENTRANDO cada mes mientras no se facture entera, y facturada entera ya no entra; no se termina una que la app tiene en obra (MX008), y terminada no lleva costo estimado (22023)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. LA PROPUESTA del costo estimado. La primera vez, el estimado de la
--     obra (c10: 100 h × 36.25 + 2,000 de material = 5,625.00); «confirmar»
--     es un toque. El mes siguiente propone lo del mes anterior; confirmar
--     con otra cifra que la propuesta para (MX008: ya no es la que viste);
--     otro número pide su nota (22023) y queda «a mano» con lo que se
--     proponía. Sin propuesta no hay nada que confirmar (MX008).
do $$
declare
  v_obt text; v_sig text := pg_temp.c12('mes_sig'); r jsonb; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'la primera vez propone el estimado de la obra: 5625.00 (estimado) | un toque: origen estimado, costo estimado 5625.00, '
                '53.33 %, ganado 5333.33 | el mes siguiente propone lo del mes anterior: 5625.00 (mes_anterior) | confirmar otra cifra que '
                'la propuesta: MX008 | un toque: origen mes_anterior | otro número sin nota: 22023 | con su nota: origen a_mano, y guarda '
                'lo que se proponía (5625.00, mes_anterior) | sin propuesta, confirmar: MX008';
begin
  if pg_temp.c12_omitir(18, 'la propuesta del costo estimado', v_esp) then return; end if;
  if pg_temp.c12('hay_c10') <> 'true' then
    insert into _pruebas values (18, 'la propuesta del costo estimado', v_esp, 'omitida: el costo por obra (c10) no está en esta base: no hay propuesta de fábrica que probar', null);
    return;
  end if;
  begin
    perform pg_temp.c12_sembrar();
    insert into escenarios (id, nombre, foreman, journeyman, helper, pct_foreman, pct_journeyman, pct_helper, benefits) values
      ('B', 'C12 PRUEBA B', 40, 30, 20, 0.2, 0.5, 0.3, 0.25)
    on conflict (id) do update set foreman = excluded.foreman, journeyman = excluded.journeyman, helper = excluded.helper,
      pct_foreman = excluded.pct_foreman, pct_journeyman = excluded.pct_journeyman, pct_helper = excluded.pct_helper, benefits = excluded.benefits;
    update proyectos set horas_estimadas = 100 where id = 'c12-prueba-a';
    update finanzas_proyecto set presupuesto_materiales = 2000 where proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_costo('c12-prueba-b', 4000);
    perform pg_temp.c12_ser('dueno');
    select format('%s (%s)', s.propuesta_costo_estimado, s.propuesta_origen) into a
      from v_wip_schedule s where s.periodo = pg_temp.c12('mes') and s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('editor');
    r := pg_temp.c12_rev('c12-prueba-a', '{"confirmar": true}');
    select format('origen %s, costo estimado %s, %s %%, ganado %s', r->>'origen', s.costo_estimado, s.pct_avance, s.ingreso_ganado) into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('dueno');
    select format('%s (%s)', s.propuesta_costo_estimado, s.propuesta_origen) into c
      from v_wip_schedule s where s.periodo = v_sig and s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('editor');
    d := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-a'', ' || quote_literal(v_sig) || ', ''{"confirmar": true, "costo_estimado": "5000"}''::jsonb)');
    r := pg_temp.c12_rev('c12-prueba-a', '{"confirmar": true, "costo_estimado": "5625.00"}', v_sig);
    e := 'origen ' || (r->>'origen');
    f := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-a'', ' || quote_literal(v_sig) || ', ''{"costo_estimado": "7000"}''::jsonb)');
    r := pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "7000", "nota": "C12 PRUEBA: subió el cobre"}', v_sig);
    select format('origen %s, y guarda lo que se proponía (%s, %s)', x.origen, x.propuesta, x.propuesta_origen) into g
      from wip_revisiones x where x.id = (r->>'revision_id')::uuid;
    h := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(pg_temp.c12('mes')) || ', ''{"confirmar": true}''::jsonb)');
    v_obt := format('la primera vez propone el estimado de la obra: %s | un toque: %s | el mes siguiente propone lo del mes anterior: %s | '
                    'confirmar otra cifra que la propuesta: %s | un toque: %s | otro número sin nota: %s | con su nota: %s | sin propuesta, '
                    'confirmar: %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'LA PROPUESTA del costo estimado: la primera vez, el estimado de la obra (c10); después, lo del mes anterior; «confirmar» es un toque y dice de dónde salió; confirmar una cifra que ya no es la propuesta para (MX008); otro número pide su nota (22023) y guarda lo que se proponía; sin propuesta no hay nada que confirmar (MX008)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 19. Los frenos de la revisión: el mes (no existe, la apertura, uno que no
--     empezó), la obra, la forma de lo que llega, el monto, el contrato.
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); r jsonb; a text; b text; c text; d text; e text; f text;
  q text;
  v_esp text := 'un mes que no existe MX002, la apertura MX002, un mes que no empezó MX002 | una obra que no existe MX008 | otra clave '
                '22023, no es un objeto 22023, nada que revisar 22023 | tres decimales MX005, cero MX005, negativo MX005, letras MX005 | '
                'sin contrato en la ficha MX008, y diciendo el precio con su nota entra | otro precio que el de la ficha, sin nota 22023; '
                'con nota: precio 11000.00, y el de la ficha (10000.00) guardado';
begin
  if pg_temp.c12_omitir(19, 'los frenos de la revisión', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_costo('c12-prueba-k', 800);
    q := 'select public.fn_wip_revisar(%L, %L, %L::jsonb)';
    a := format('un mes que no existe %s, la apertura %s, un mes que no empezó %s',
                pg_temp.c12_estado(format(q, 'c12-prueba-a', '2019-01', '{"costo_estimado": "6000"}')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', (select p.periodo from periodos p where p.tipo = 'apertura' limit 1), '{"costo_estimado": "6000"}')),
                coalesce(pg_temp.c12_estado(format(q, 'c12-prueba-a', pg_temp.c12('mes_futuro'), '{"costo_estimado": "6000"}')), 'sin mes futuro'));
    b := 'una obra que no existe ' || pg_temp.c12_estado(format(q, 'c12-prueba-zz', v_mes, '{"costo_estimado": "6000"}'));
    c := format('otra clave %s, no es un objeto %s, nada que revisar %s',
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "6000", "avance": 50}')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '"6000"')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{}')));
    d := format('tres decimales %s, cero %s, negativo %s, letras %s',
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "6000.123"}')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "0"}')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "-6000"}')),
                pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "mucho"}')));
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-k', '{"modo": "contrato", "nota": "C12 PRUEBA: precio fijo, falta el contrato en la ficha"}');
    perform pg_temp.c12_ser('editor');
    e := format('sin contrato en la ficha %s, y diciendo el precio con su nota %s',
                pg_temp.c12_estado(format(q, 'c12-prueba-k', v_mes, '{"costo_estimado": "5000"}')),
                case pg_temp.c12_estado(format(q, 'c12-prueba-k', v_mes, '{"costo_estimado": "5000", "precio_contrato": "7000", "nota": "C12 PRUEBA: contrato firmado, falta en la ficha"}'))
                  when 'ok' then 'entra' else 'NO entra' end);
    f := 'otro precio que el de la ficha, sin nota '
         || pg_temp.c12_estado(format(q, 'c12-prueba-a', v_mes, '{"costo_estimado": "6000", "precio_contrato": "11000"}'));
    r := pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000", "precio_contrato": "11000", "nota": "C12 PRUEBA: CO 1 firmado, falta en la ficha"}');
    select f || format('; con nota: precio %s, y el de la ficha (%s) guardado', x.precio_contrato, x.precio_ficha) into f
      from wip_revisiones x where x.id = (r->>'revision_id')::uuid;
    v_obt := format('%s | %s | %s | %s | %s | %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'los frenos de la revisión: un mes que no existe, la apertura o un mes que no empezó (MX002); una obra que no existe (MX008); una clave desconocida, algo que no es un objeto o nada que revisar (22023); un monto con tres decimales, cero, negativo o con letras (MX005); una obra sin contrato (MX008, salvo que se diga el precio con su nota); y otro precio que el de la ficha sin nota (22023)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. EL PRECIO SE COPIA AL REVISAR: la ficha (finanzas_proyecto.contrato)
--     cambia sin historia, y el WIP del mes sigue con el precio de su
--     revisión hasta que se revise otra vez; mientras, lo avisa (en la fila y
--     en el aviso 130). La revisión anterior queda.
do $$
declare
  v_obt text; a text; b text; c text;
  v_esp text := 'revisada con el contrato de la ficha: precio 10000.00, ganado 5000.00 | la ficha cambia a 12000: el WIP sigue con '
                '10000.00 y ganado 5000.00, lo avisa en su fila: sí, y el aviso 130 la nombra: sí | revisada otra vez: precio 12000.00, '
                'ganado 6000.00, el 130 la nombra: no, y la revisión anterior queda (2 revisiones, 1 vigente)';
begin
  if pg_temp.c12_omitir(20, 'el precio del contrato se copia al revisar', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    select format('precio %s, ganado %s', s.precio_contrato, s.ingreso_ganado) into a
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    update finanzas_proyecto set contrato = 12000 where proyecto_id = 'c12-prueba-a';
    select format('el WIP sigue con %s y ganado %s, lo avisa en su fila: %s, y el aviso 130 la nombra: %s', s.precio_contrato, s.ingreso_ganado,
                  case when exists (select 1 from unnest(s.avisos) t where t like 'El contrato de la ficha ($12,000.00) no es el que se usó al revisar ($10,000.00)%') then 'sí' else 'no' end,
                  pg_temp.c12_nombra(130, 'a')) into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    select format('precio %s, ganado %s, el 130 la nombra: %s, y la revisión anterior queda (%s revisiones, %s vigente)', s.precio_contrato,
                  s.ingreso_ganado, pg_temp.c12_nombra(130, 'a'),
                  (select count(*) from wip_revisiones x where x.proyecto_id = 'c12-prueba-a' and x.periodo = pg_temp.c12('mes')),
                  (select count(*) from wip_revisiones x where x.proyecto_id = 'c12-prueba-a' and x.periodo = pg_temp.c12('mes') and x.sustituida_el is null))
      into c from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    v_obt := format('revisada con el contrato de la ficha: %s | la ficha cambia a 12000: %s | revisada otra vez: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'EL PRECIO DEL CONTRATO SE COPIA AL REVISAR: la ficha cambia sin historia y el WIP del mes sigue con el precio de su revisión; lo avisa (en la fila y en el aviso 130) hasta que se revisa otra vez, y la revisión anterior queda',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. v_wip_schedule (lo que la pantalla pinta, filtrada por periodo) y los
--     totales de fn_wip_resumen (la pantalla no suma). Con A sub-facturada
--     3,000, B sobre-facturada 4,000, C con pérdida (sub 5,000, provisión
--     1,000), G pendiente y las demás sin movimiento.
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); r jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'las obras de prueba en el mes: 3 listas, 1 pendiente y 7 sin movimiento | la vista y la función dan lo mismo: sí | un mes '
                'que no ha empezado no sale: sí | los totales del resumen son la suma de las obras listas: sí | de las de prueba: contrato '
                '40000.00, ganado 15000.00, facturado 11000.00, sub-facturado 8000.00, sobre-facturado 4000.00, pérdida por reconocer '
                '1000.00 | se puede postear: sí, con 8 líneas de las obras de prueba, cada una con el nombre de su cuenta y de su obra';
begin
  if pg_temp.c12_omitir(21, 'v_wip_schedule y los totales del resumen', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    perform pg_temp.c12_costo('c12-prueba-b', 4000);
    perform pg_temp.c12_factura(2, 'c12-prueba-b', 9000);
    perform pg_temp.c12_rev('c12-prueba-b', '{"costo_estimado": "16000"}');
    perform pg_temp.c12_costo('c12-prueba-c', 6000);
    perform pg_temp.c12_rev('c12-prueba-c', '{"costo_estimado": "12000"}');
    perform pg_temp.c12_factura(7, 'c12-prueba-g', 3000, -10);
    perform pg_temp.c12_ser('dueno');
    select format('%s listas, %s pendiente y %s sin movimiento', count(*) filter (where s.estado = 'lista'),
                  count(*) filter (where s.estado = 'pendiente'), count(*) filter (where s.estado = 'sin_movimiento')) into a
      from v_wip_schedule s where s.periodo = v_mes and s.proyecto_id like 'c12-prueba-%';
    select case when (select count(*) from v_wip_schedule s where s.periodo = v_mes) = (select count(*) from fn_wip_schedule(v_mes))
                     and not exists ((select to_jsonb(s) from v_wip_schedule s where s.periodo = v_mes)
                                     except (select to_jsonb(s) from fn_wip_schedule(v_mes) s))
                then 'sí' else 'no' end into b;
    select case when count(*) = 0 then 'sí' else 'no: ' || count(*) end into c
      from v_wip_schedule s where s.periodo = pg_temp.c12('mes_futuro');
    r := fn_wip_resumen(v_mes);
    select case when (r->'totales'->>'sub_facturado')::numeric = coalesce(sum(s.sub_facturado), 0)
                     and (r->'totales'->>'sobre_facturado')::numeric = coalesce(sum(s.sobre_facturado), 0)
                     and (r->'totales'->>'ingreso_ganado')::numeric = coalesce(sum(s.ingreso_ganado), 0)
                     and (r->'totales'->>'precio_contrato')::numeric = coalesce(sum(s.precio_contrato), 0)
                     and (r->'totales'->>'costo_fecha')::numeric = coalesce(sum(s.costo_fecha), 0)
                     and (r->'totales'->>'facturado_fecha')::numeric = coalesce(sum(s.facturado_fecha), 0)
                     and (r->'totales'->>'perdida_provision')::numeric = coalesce(sum(s.perdida_provision), 0)
                     and (r->'totales'->>'costo_para_terminar')::numeric = coalesce(sum(s.costo_para_terminar), 0)
                     and (r->'totales'->>'obras')::int = count(*)
                then 'sí' else 'no: ' || (r->'totales')::text end into d
      from v_wip_schedule s where s.periodo = v_mes and s.en_ajuste;
    select format('contrato %s, ganado %s, facturado %s, sub-facturado %s, sobre-facturado %s, pérdida por reconocer %s',
                  sum(s.precio_contrato), sum(s.ingreso_ganado), sum(s.facturado_fecha), sum(s.sub_facturado), sum(s.sobre_facturado),
                  sum(s.perdida_provision)) into e
      from v_wip_schedule s where s.periodo = v_mes and s.en_ajuste and s.proyecto_id like 'c12-prueba-%';
    select format('%s, con %s líneas de las obras de prueba, cada una con el nombre de su cuenta y de su obra',
                  case when (r->>'puede_postear')::boolean then 'sí' else 'no (' || coalesce(r->>'por_que_no', '') || ')' end,
                  count(*) filter (where l->>'cuenta_nombre' is not null and l->>'obra' like 'C12 PRUEBA Obra %')) into f
      from jsonb_array_elements(r->'lineas') l where l->>'proyecto_id' like 'c12-prueba-%';
    perform pg_temp.c12_ser('editor');
    v_obt := format('las obras de prueba en el mes: %s | la vista y la función dan lo mismo: %s | un mes que no ha empezado no sale: %s | '
                    'los totales del resumen son la suma de las obras listas: %s | de las de prueba: %s | se puede postear: %s',
                    a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'v_wip_schedule (lo que la pantalla pinta, filtrada por periodo) da lo mismo que la función, no enseña un mes que no ha empezado, y los totales de fn_wip_resumen son la suma de las obras listas (la pantalla no suma dinero); las líneas que se postearían llevan el nombre de su cuenta y de su obra',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL AJUSTE
-- ---------------------------------------------------------------------

-- 22. EL ASIENTO, línea por línea, y su foto. Con A sub-facturada 3,000, B
--     sobre-facturada 4,000 y C con pérdida (sub-facturada 5,000 y 1,000 de
--     provisión): UN asiento, fechado el último día del mes, por el camino
--     del dueño (fn_postear de c2) y reversible; cada obra con su par de
--     líneas (1200 / su ingreso; su ingreso / 2400; 5950 / 2410), su obra y
--     su memo. Y queda guardado: el ajuste (wip_ajustes) y la foto de cada
--     obra (wip_ajuste_obras), también las que no entraron.
do $$
declare
  v_obt text; r jsonb; v_a asientos; v_w wip_ajustes; v_mes text := pg_temp.c12('mes');
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'posteado: sí, y lo dice: sí | el asiento: fechado el último día del mes, por el camino del dueño, reversible, normal, '
                'cuadrado y a nombre del dueño: sí | sus líneas de las obras de prueba: 1200 3000.00 a | ingreso -3000.00 a | ingreso '
                '4000.00 b | 2400 -4000.00 b | 1200 5000.00 c | ingreso -5000.00 c | 5950 1000.00 c | 2410 -1000.00 c | cada línea con su '
                'obra y su memo, sin cost code: sí | el memo de la primera dice el cálculo: sí | la foto de las obras de prueba: a lista sub '
                '3000.00 sobre 0.00 prov 0.00; b lista sub 0.00 sobre 4000.00 prov 0.00; c lista sub 5000.00 sobre 0.00 prov 1000.00; y 8 '
                'sin movimiento | el ajuste guardado es su asiento, con su reverso del día 1 y los totales de su foto: sí';
begin
  if pg_temp.c12_omitir(22, 'el asiento del ajuste, línea por línea, y su foto', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    select * into v_a from asientos x where x.id = (r->'asiento'->>'id')::uuid;
    select * into v_w from wip_ajustes x where x.id = (r->>'ajuste_id')::uuid;
    a := format('%s, y lo dice: %s', case when (r->>'posteado')::boolean and not (r->>'ya_estaba')::boolean then 'sí' else 'no' end,
                case when r->>'nota' like 'Posteado el ajuste de WIP de ' || fn_wip_mes(v_mes) || ': asiento ' || v_a.numero || ', con %'
                     then 'sí' else 'no: ' || coalesce(r->>'nota', 'sin nota') end);
    b := case when v_a.fecha_contable = pg_temp.c12_h() and v_a.camino = 'mano' and v_a.reversible and v_a.tipo = 'normal'
                   and v_a.periodo = v_mes and v_a.usuario_id::text = pg_temp.c12('dueno')
                   and (select sum(l.monto) from asiento_lineas l where l.asiento_id = v_a.id) = 0
                   and v_a.descripcion like 'Ajuste de WIP de ' || fn_wip_mes(v_mes) || ' por costo a costo (c12: %'
              then 'sí' else format('no: %s, %s, reversible %s, %s, %s', v_a.fecha_contable, v_a.camino, v_a.reversible, v_a.tipo, v_a.descripcion) end;
    c := pg_temp.c12_lin(v_a.id);
    d := case when not exists (select 1 from asiento_lineas l
                                where l.asiento_id = v_a.id
                                  and (l.proyecto_id is null or l.cost_code is not null
                                       or coalesce(l.memo, '') not like 'WIP de ' || fn_wip_mes(v_mes) || ': %'))
              then 'sí' else 'no' end;
    select case when l.memo = format('WIP de %s: sub-facturado · ganado $5,000.00 (50 %%) − facturado $2,000.00', fn_wip_mes(v_mes))
                then 'sí' else 'no: ' || coalesce(l.memo, 'sin memo') end into e
      from asiento_lineas l where l.asiento_id = v_a.id and l.proyecto_id = 'c12-prueba-a' and l.cuenta = '1200';
    select format('%s; y %s sin movimiento',
                  string_agg(format('%s %s sub %s sobre %s prov %s', replace(w.proyecto_id, 'c12-prueba-', ''), w.estado, w.sub_facturado,
                                    w.sobre_facturado, w.perdida_provision), '; ' order by w.proyecto_id) filter (where w.en_ajuste),
                  count(*) filter (where w.estado = 'sin_movimiento')) into f
      from wip_ajuste_obras w where w.ajuste_id = v_w.id and w.proyecto_id like 'c12-prueba-%';
    select case when v_w.asiento_id = v_a.id and v_w.numero = v_a.numero and v_w.fecha = pg_temp.c12_h() and v_w.periodo = v_mes
                     and v_w.reverso_auto_id is not null and v_w.reverso_auto_id = (r->'reverso'->>'id')::uuid
                     and v_w.obras = count(*) filter (where w.en_ajuste)
                     and v_w.sub_facturado = coalesce(sum(w.sub_facturado) filter (where w.en_ajuste), 0)
                     and v_w.sobre_facturado = coalesce(sum(w.sobre_facturado) filter (where w.en_ajuste), 0)
                     and v_w.perdida = coalesce(sum(w.perdida_provision) filter (where w.en_ajuste), 0)
                     and v_w.lineas = (select count(*) from asiento_lineas l where l.asiento_id = v_a.id)
                     and v_w.creado_por::text = pg_temp.c12('dueno') and v_w.deshecho_el is null
                     and (r->>'sub_facturado')::numeric = v_w.sub_facturado and (r->>'sobre_facturado')::numeric = v_w.sobre_facturado
                     and (r->>'perdida')::numeric = v_w.perdida and (r->>'obras')::int = v_w.obras and (r->>'lineas')::int = v_w.lineas
                then 'sí' else 'no' end into g
      from wip_ajuste_obras w where w.ajuste_id = v_w.id;
    v_obt := format('posteado: %s | el asiento: fechado el último día del mes, por el camino del dueño, reversible, normal, cuadrado y a '
                    'nombre del dueño: %s | sus líneas de las obras de prueba: %s | cada línea con su obra y su memo, sin cost code: %s | el '
                    'memo de la primera dice el cálculo: %s | la foto de las obras de prueba: %s | el ajuste guardado es su asiento, con su '
                    'reverso del día 1 y los totales de su foto: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'EL ASIENTO DEL AJUSTE, línea por línea: uno solo, fechado el último día del mes, por el camino del dueño (fn_postear de c2) y reversible; la sub-facturada Dr 1200 / Cr su ingreso, la sobre-facturada Dr su ingreso / Cr 2400, la pérdida Dr 5950 / Cr 2410, cada línea con su obra y su memo; y queda guardado el ajuste y la foto de cada obra (también las que no entraron)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. DOS VECES = UNO. Postear otra vez un mes que ya tiene su ajuste al día
--     devuelve el que estaba: ni otro asiento ni otro ajuste.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; r3 jsonb; v_n bigint; v_w bigint; a text; b text; c text; d text;
  v_esp text := 'la segunda vez: ya estaba: sí, el mismo asiento y el mismo reverso: sí, y dice que no se duplica: sí | asientos nuevos en '
                'el libro: 0 | ajustes nuevos: 0; vivos en el mes: 1 | una tercera, con otro motivo: igual';
begin
  if pg_temp.c12_omitir(23, 'postear dos veces = un ajuste', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r1 := pg_temp.c12_postear();
    select count(*) into v_n from asientos;
    select count(*) into v_w from wip_ajustes;
    r2 := pg_temp.c12_postear();
    a := format('ya estaba: %s, el mismo asiento y el mismo reverso: %s, y dice que no se duplica: %s',
                case when (r2->>'ya_estaba')::boolean and (r2->>'posteado')::boolean then 'sí' else 'no' end,
                case when r2->'asiento'->>'id' = r1->'asiento'->>'id' and r2->'reverso'->>'id' = r1->'reverso'->>'id'
                          and r2->>'ajuste_id' = r1->>'ajuste_id' and (r2->>'sub_facturado')::numeric = (r1->>'sub_facturado')::numeric then 'sí' else 'no' end,
                case when r2->>'nota' like '%ya estaba posteado y sigue al día (asiento ' || (r1->'asiento'->>'numero') || '): no se duplica.'
                     then 'sí' else 'no: ' || coalesce(r2->>'nota', 'sin nota') end);
    r3 := pg_temp.c12_postear(null, 'C12 PRUEBA: otra vez');
    b := ((select count(*) from asientos) - v_n)::text;
    c := format('%s; vivos en el mes: %s', (select count(*) from wip_ajustes) - v_w,
                (select count(*) from wip_ajustes x where x.periodo = pg_temp.c12('mes') and x.deshecho_el is null));
    d := case when (r3->>'ya_estaba')::boolean and r3->'asiento'->>'id' = r1->'asiento'->>'id' then 'igual' else 'NO es igual' end;
    v_obt := format('la segunda vez: %s | asientos nuevos en el libro: %s | ajustes nuevos: %s | una tercera, con otro motivo: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'DOS VECES = UNO (idempotente): postear otra vez un mes que ya tiene su ajuste al día devuelve el que estaba (ya_estaba, el mismo asiento y su reverso) y no entra ni otro asiento ni otro ajuste',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. SU REVERSO DEL DÍA 1. El ajuste nace con su reverso automático (c2):
--     fechado el día 1 del mes siguiente, su espejo línea por línea. Al
--     cierre del mes el saldo por obra de 1200, 2400 y 2410 es el del ajuste,
--     y el ingreso de la obra en el libro es lo GANADO; al día siguiente todo
--     vuelve a cero y el ingreso, a lo facturado. «Costo por obra» (c10), que
--     no mira fechas, no se mueve.
do $$
declare
  v_obt text; r jsonb; v_r asientos; v_aj uuid; v_h date := pg_temp.c12_h(); v_c10a text; v_c10b text;
  a text; b text; c text; d text; e text; f text;
  v_q text := 'select string_agg(format(''%s %s/%s'', right(o.proyecto_id, 1), o.ingreso_libro, o.costo_real), '', '' order by o.proyecto_id) '
              'from public.v_margen_obra o where o.proyecto_id in (''c12-prueba-a'', ''c12-prueba-b'', ''c12-prueba-c'')';
  v_esp text := 'el reverso: automático, del asiento del ajuste, fechado el día 1 del mes siguiente y en ese mes: sí | es su espejo, cuenta '
                'por cuenta y obra por obra: sí | al cierre del mes, el saldo por obra: sub-facturado de A 3000.00, sobre-facturado de B '
                '-4000.00, sub-facturado de C 5000.00, provisión de C -1000.00, gasto por la pérdida de C 1000.00 | al día siguiente: 0.00, '
                '0.00, 0.00, 0.00, 0.00 | el ingreso del libro al cierre es lo ganado: A 5000.00 y B 5000.00; al día siguiente vuelve a lo '
                'facturado: A 2000.00 y B 9000.00 | '
                || case when pg_temp.c12('hay_c10') = 'true'
                        then '«Costo por obra» (c10, sin fechas) no se mueve: a 2000.00/3000.00, b 9000.00/4000.00, c 0.00/6000.00'
                        else '«Costo por obra» (c10) no está en esta base' end;
begin
  if pg_temp.c12_omitir(24, 'el reverso del día 1', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    if pg_temp.c12('hay_c10') = 'true' then execute v_q into v_c10a; end if;
    r := pg_temp.c12_postear();
    v_aj := (r->'asiento'->>'id')::uuid;
    select * into v_r from asientos x where x.id = (r->'reverso'->>'id')::uuid;
    a := case when v_r.camino = 'reverso_automatico' and v_r.reversa_a = v_aj and v_r.fecha_contable = v_h + 1
                   and v_r.periodo = pg_temp.c12('mes_sig') and (r->'reverso'->>'fecha')::date = v_h + 1
                   and (select count(*) from asientos x where x.reversa_a = v_aj) = 1
              then 'sí' else format('no: %s, %s, en %s', v_r.camino, v_r.fecha_contable, v_r.periodo) end;
    select case when count(*) = 0 and (select count(*) from asiento_lineas l where l.asiento_id = v_aj)
                                      = (select count(*) from asiento_lineas l where l.asiento_id = v_r.id)
                then 'sí' else 'no' end into b
      from (select l.cuenta, l.proyecto_id from asiento_lineas l where l.asiento_id in (v_aj, v_r.id)
             group by l.cuenta, l.proyecto_id having sum(l.monto) <> 0) z;
    c := format('sub-facturado de A %s, sobre-facturado de B %s, sub-facturado de C %s, provisión de C %s, gasto por la pérdida de C %s',
                pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h), pg_temp.c12_saldo('2400', 'c12-prueba-b', v_h),
                pg_temp.c12_saldo('1200', 'c12-prueba-c', v_h), pg_temp.c12_saldo('2410', 'c12-prueba-c', v_h),
                pg_temp.c12_saldo('5950', 'c12-prueba-c', v_h));
    d := format('%s, %s, %s, %s, %s',
                pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h + 1), pg_temp.c12_saldo('2400', 'c12-prueba-b', v_h + 1),
                pg_temp.c12_saldo('1200', 'c12-prueba-c', v_h + 1), pg_temp.c12_saldo('2410', 'c12-prueba-c', v_h + 1),
                pg_temp.c12_saldo('5950', 'c12-prueba-c', v_h + 1));
    e := format('A %s y B %s; al día siguiente vuelve a lo facturado: A %s y B %s',
                -pg_temp.c12_saldo(pg_temp.c12_ingreso('comercial'), 'c12-prueba-a', v_h),
                -pg_temp.c12_saldo(pg_temp.c12_ingreso('residencial'), 'c12-prueba-b', v_h),
                -pg_temp.c12_saldo(pg_temp.c12_ingreso('comercial'), 'c12-prueba-a', v_h + 1),
                -pg_temp.c12_saldo(pg_temp.c12_ingreso('residencial'), 'c12-prueba-b', v_h + 1));
    if pg_temp.c12('hay_c10') = 'true' then
      execute v_q into v_c10b;
      f := case when v_c10b = v_c10a then '«Costo por obra» (c10, sin fechas) no se mueve: ' || v_c10b
                else format('«Costo por obra» (c10) SE MUEVE: de %s a %s', v_c10a, v_c10b) end;
    else
      f := '«Costo por obra» (c10) no está en esta base';
    end if;
    v_obt := format('el reverso: automático, del asiento del ajuste, fechado el día 1 del mes siguiente y en ese mes: %s | es su espejo, '
                    'cuenta por cuenta y obra por obra: %s | al cierre del mes, el saldo por obra: %s | al día siguiente: %s | el ingreso '
                    'del libro al cierre es lo ganado: %s | %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'SU REVERSO DEL DÍA 1: el ajuste nace con su reverso automático (c2), fechado el día 1 del mes siguiente y espejo suyo; al cierre del mes el saldo por obra de sub-facturado, sobre-facturado y provisión es el del ajuste y el ingreso de la obra es lo ganado; al día siguiente todo vuelve a cero y el ingreso, a lo facturado; «Costo por obra» (c10), que no mira fechas, no se mueve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. LA REVISIÓN CAMBIA DESPUÉS DE POSTEAR. No se rehace sola: el control
--     del ajuste (50) se pone en rojo y dice qué cambió; volver a postear lo
--     rehace: el asiento anterior se reversa en su mismo día (c2 anula
--     también su reverso del día 1) y entra el nuevo, con su propio reverso.
--     A sube su estimado a 7,500: 40 %, ganó 4,000, sub-facturada 2,000.
do $$
declare
  v_obt text; r1 jsonb; r2 jsonb; v_h date := pg_temp.c12_h(); v_viejo uuid; v_auto uuid; v_w1 wip_ajustes; v_w2 wip_ajustes;
  a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'posteado y al día: el control del ajuste verde | A sube su estimado a 7500: 40.00 %, ganado 4000.00, sub 2000.00; el '
                'control rojo y dice qué cambió: sí; el resumen lo dice y deja postear: sí | volver a postear lo rehace: sí | el asiento '
                'anterior queda reversado en su mismo día: sí, y su reverso del día 1, anulado ese día 1: sí | el nuevo: 1200 2000.00 a | '
                'ingreso -2000.00 a | ingreso 4000.00 b | 2400 -4000.00 b | 1200 5000.00 c | ingreso -5000.00 c | 5950 1000.00 c | 2410 '
                '-1000.00 c | el saldo de sub-facturado de A al cierre: 2000.00, y al día siguiente: 0.00 | ajustes vivos en el mes: 1; el '
                'anterior guarda por qué se deshizo y con qué reverso: sí; el nuevo dice a cuál sustituye y su motivo: sí | el control del '
                'ajuste verde, y los demás cuadres: nada nuevo en rojo';
begin
  if pg_temp.c12_omitir(25, 'la revisión cambiada después de postear', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r1 := pg_temp.c12_postear();
    v_viejo := (r1->'asiento'->>'id')::uuid;
    v_auto  := (r1->'reverso'->>'id')::uuid;
    a := 'el control del ajuste ' || pg_temp.c12_ctl(50);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "7500", "nota": "C12 PRUEBA: subió el cobre"}');
    perform pg_temp.c12_ser('dueno');
    select format('%s %%, ganado %s, sub %s; el control %s y dice qué cambió: %s; el resumen lo dice y deja postear: %s',
                  s.pct_avance, s.ingreso_ganado, s.sub_facturado, pg_temp.c12_ctl(50),
                  case when pg_temp.c12_ctl_det(50) like 'El ajuste posteado de % (asiento ' || (r1->'asiento'->>'numero') || ') ya no es el que '
                            'da el WIP de hoy: C12 PRUEBA Obra A pasa de sub-facturado $3,000.00 a sub-facturado $2,000.00. Vuelve a postearlo%'
                       then 'sí' else 'no: ' || pg_temp.c12_ctl_det(50) end,
                  case when (z.j->>'puede_postear')::boolean and not (z.j->'ajuste'->>'al_dia')::boolean
                            and z.j->>'nota' like 'El ajuste posteado de % ya no es el de hoy: C12 PRUEBA Obra A pasa de sub-facturado $3,000.00 '
                                                  'a sub-facturado $2,000.00. Vuelve a postearlo%' then 'sí' else 'no: ' || (z.j->>'nota') end)
      into b
      from fn_wip_schedule(pg_temp.c12('mes')) s, (select fn_wip_resumen(pg_temp.c12('mes')) as j) z
     where s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('editor');
    r2 := pg_temp.c12_postear(null, 'C12 PRUEBA: subió el estimado de A');
    c := case when (r2->>'posteado')::boolean and not (r2->>'ya_estaba')::boolean and r2->'rehecho'->>'ajuste_id' = r1->>'ajuste_id'
                   and not (r2->'rehecho'->>'por_fuera')::boolean and r2->>'nota' like 'Rehecho el ajuste de WIP de %'
                   and r2->'asiento'->>'id' <> r1->'asiento'->>'id'
              then 'sí' else 'no: ' || coalesce(r2->>'nota', 'sin nota') end;
    d := format('%s, y su reverso del día 1, anulado ese día 1: %s',
                case when exists (select 1 from asientos x where x.reversa_a = v_viejo and x.camino = 'reverso' and x.fecha_contable = v_h
                                     and x.numero = r2->'rehecho'->'reverso'->>'numero') then 'sí' else 'no' end,
                case when exists (select 1 from asientos x where x.reversa_a = v_auto and x.camino = 'reverso' and x.fecha_contable = v_h + 1
                                     and x.numero = r2->'rehecho'->>'anula_reverso_automatico') then 'sí' else 'no' end);
    e := pg_temp.c12_lin((r2->'asiento'->>'id')::uuid);
    f := format('%s, y al día siguiente: %s', pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h), pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h + 1));
    select * into v_w1 from wip_ajustes x where x.id = (r1->>'ajuste_id')::uuid;
    select * into v_w2 from wip_ajustes x where x.id = (r2->>'ajuste_id')::uuid;
    g := format('%s; el anterior guarda por qué se deshizo y con qué reverso: %s; el nuevo dice a cuál sustituye y su motivo: %s',
                (select count(*) from wip_ajustes x where x.periodo = pg_temp.c12('mes') and x.deshecho_el is null),
                case when v_w1.deshecho_el is not null and not v_w1.por_fuera and v_w1.deshecho_por::text = pg_temp.c12('dueno')
                          and v_w1.reverso_id = (select x.id from asientos x where x.reversa_a = v_viejo and x.camino = 'reverso')
                          and v_w1.deshecho_motivo like 'El WIP de % cambió después de postear su ajuste (' || v_w1.numero || '): C12 PRUEBA Obra A '
                               'pasa de sub-facturado $3,000.00 a sub-facturado $2,000.00. C12 PRUEBA: subió el estimado de A'
                     then 'sí' else 'no: ' || coalesce(v_w1.deshecho_motivo, 'sin motivo') end,
                case when v_w2.sustituye_a = v_w1.id and v_w2.motivo = 'C12 PRUEBA: subió el estimado de A' and v_w2.deshecho_el is null
                          and v_w2.sub_facturado = v_w1.sub_facturado - 1000 then 'sí' else 'no' end);
    h := format('el control del ajuste %s, y los demás cuadres: %s', pg_temp.c12_ctl(50), pg_temp.c12_propios());
    v_obt := format('posteado y al día: %s | A sube su estimado a 7500: %s | volver a postear lo rehace: %s | el asiento anterior queda '
                    'reversado en su mismo día: %s | el nuevo: %s | el saldo de sub-facturado de A al cierre: %s | ajustes vivos en el mes: '
                    '%s | %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'LA REVISIÓN CAMBIA DESPUÉS DE POSTEAR: el ajuste no se rehace solo; el control lo pone en rojo y dice qué obra cambió y de cuánto a cuánto; volver a postear lo rehace: el asiento anterior se reversa en su mismo día (c2 anula también su reverso del día 1) y entra el nuevo con su propio reverso; el anterior queda como rastro con su porqué',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. DESHACER el ajuste de un mes abierto, con su motivo: se reversa en su
--     fecha y su reverso del día 1 queda anulado; el libro vuelve a lo
--     facturado; el ajuste queda como rastro; y se puede volver a postear.
do $$
declare
  v_obt text; r jsonb; d jsonb; r2 jsonb; v_h date := pg_temp.c12_h(); v_w wip_ajustes; v_j jsonb;
  a text; b text; c text; e text; f text; g text; h text;
  v_esp text := 'sin motivo: 22023 | con su motivo: se reversa en su fecha y su reverso del día 1 queda anulado: sí | el saldo de '
                'sub-facturado de A al cierre y al día siguiente: 0.00 y 0.00; el ingreso de A vuelve a lo facturado: 2000.00 | el ajuste '
                'queda como rastro, deshecho con su motivo y su reverso: sí; vivos en el mes: 0 | deshacer otra vez: MX008 | el control '
                'vuelve a pedirlo (falta postear): sí, y el resumen deja postear y no deshacer: sí | y se vuelve a postear: sí, 1 vivo';
begin
  if pg_temp.c12_omitir(26, 'deshacer el ajuste', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    a := pg_temp.c12_estado('select public.fn_wip_deshacer(' || quote_literal(pg_temp.c12('mes')) || ', ''  '')');
    d := pg_temp.c12_deshacer('C12 PRUEBA: se posteó antes de tiempo');
    b := case when not (d->>'por_fuera')::boolean
                   and d->>'nota' like 'Deshecho el ajuste de WIP de %: el asiento ' || (r->'asiento'->>'numero') || ' se reversó con '
                                       || (d->'reverso'->>'numero') || ', y su reverso del día 1 quedó anulado.%'
                   and exists (select 1 from asientos x where x.id = (d->'reverso'->>'id')::uuid and x.camino = 'reverso'
                                  and x.reversa_a = (r->'asiento'->>'id')::uuid and x.fecha_contable = v_h)
                   and exists (select 1 from asientos x where x.reversa_a = (r->'reverso'->>'id')::uuid and x.camino = 'reverso'
                                  and x.fecha_contable = v_h + 1 and x.numero = d->>'anula_reverso_automatico')
              then 'sí' else 'no: ' || coalesce(d->>'nota', 'sin nota') end;
    c := format('%s y %s; el ingreso de A vuelve a lo facturado: %s', pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h),
                pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h + 1), -pg_temp.c12_saldo(pg_temp.c12_ingreso('comercial'), 'c12-prueba-a', v_h));
    select * into v_w from wip_ajustes x where x.id = (r->>'ajuste_id')::uuid;
    e := format('%s; vivos en el mes: %s',
                case when v_w.deshecho_el is not null and v_w.deshecho_motivo = 'C12 PRUEBA: se posteó antes de tiempo' and not v_w.por_fuera
                          and v_w.reverso_id = (d->'reverso'->>'id')::uuid and v_w.deshecho_por::text = pg_temp.c12('dueno') then 'sí' else 'no' end,
                (select count(*) from wip_ajustes x where x.periodo = pg_temp.c12('mes') and x.deshecho_el is null));
    f := pg_temp.c12_estado('select public.fn_wip_deshacer(' || quote_literal(pg_temp.c12('mes')) || ', ''C12 PRUEBA: otra vez'')');
    perform pg_temp.c12_ser('dueno');
    v_j := fn_wip_resumen(pg_temp.c12('mes'));
    perform pg_temp.c12_ser('editor');
    g := format('%s, y el resumen deja postear y no deshacer: %s',
                case when pg_temp.c12_ctl(50) = 'rojo' and pg_temp.c12_ctl_det(50) like 'Falta postear el ajuste de WIP de %' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(50) end,
                case when (v_j->>'puede_postear')::boolean and not (v_j->>'puede_deshacer')::boolean and not (v_j->'ajuste'->>'vivo')::boolean
                     then 'sí' else 'no' end);
    r2 := pg_temp.c12_postear();
    h := format('%s, %s vivo', case when (r2->>'posteado')::boolean and r2->'rehecho' = 'null'::jsonb and r2->>'nota' like 'Posteado el ajuste%'
                                    then 'sí' else 'no: ' || coalesce(r2->>'nota', 'sin nota') end,
                (select count(*) from wip_ajustes x where x.periodo = pg_temp.c12('mes') and x.deshecho_el is null));
    v_obt := format('sin motivo: %s | con su motivo: se reversa en su fecha y su reverso del día 1 queda anulado: %s | el saldo de '
                    'sub-facturado de A al cierre y al día siguiente: %s | el ajuste queda como rastro, deshecho con su motivo y su '
                    'reverso: %s | deshacer otra vez: %s | el control vuelve a pedirlo (falta postear): %s | y se vuelve a postear: %s',
                    a, b, c, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'DESHACER el ajuste de un mes abierto pide su motivo (22023 sin él): se reversa en su fecha y su reverso del día 1 queda anulado, el libro vuelve a lo facturado y el ajuste queda como rastro con su motivo; sin ajuste vivo no hay qué deshacer (MX008); el control vuelve a pedirlo y se puede postear otra vez',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. EL ASIENTO REVERSADO POR FUERA (a mano, con fn_reversar de c2, sin
--     pasar por aquí): el mes se quedó sin su ajuste y la capa lo ve (el
--     cuadre 20 y el 50 en rojo, el resumen lo dice). Postear otra vez lo
--     anota como deshecho por fuera y pone el nuevo; deshacer, solo lo anota.
do $$
declare
  v_obt text; r jsonb; r2 jsonb; d jsonb; v jsonb; v2 jsonb; v_h date := pg_temp.c12_h(); v_w wip_ajustes; v_w2 wip_ajustes; v_j jsonb;
  v_n bigint; a text; b text; c text; e text; f text; g text;
  v_esp text := 'reversado a mano: el cuadre 20 rojo y el del ajuste rojo, y dicen que se reversó por fuera: sí | el resumen lo dice y deja '
                'postear: sí | postear otra vez: lo rehace, diciendo que el anterior se reversó por fuera: sí | el anterior queda anotado '
                '(por fuera, con el reverso que lo quitó y su motivo): sí; el nuevo lo sustituye: sí | el control del ajuste verde, y los '
                'demás cuadres: nada nuevo en rojo | otra vez a mano, y deshacer: solo lo anota (por fuera), sin otro asiento: sí | vivos '
                'en el mes: 0, y el saldo de sub-facturado de A al cierre: 0.00';
begin
  if pg_temp.c12_omitir(27, 'el asiento del ajuste reversado por fuera', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    perform pg_temp.c12_ser('dueno');
    v := fn_reversar((r->'asiento'->>'id')::uuid, 'C12 PRUEBA: reversado a mano en el libro');
    v_j := fn_wip_resumen(pg_temp.c12('mes'));
    perform pg_temp.c12_ser('editor');
    a := format('el cuadre 20 %s y el del ajuste %s, y dicen que se reversó por fuera: %s', pg_temp.c12_ctl(20), pg_temp.c12_ctl(50),
                case when pg_temp.c12_ctl_det(20) like '%se reversó en el libro por fuera de aquí: el de ' || fn_wip_mes(pg_temp.c12('mes'))
                                                       || ' (asiento ' || (r->'asiento'->>'numero') || ')%'
                          and pg_temp.c12_ctl_det(50) like 'El asiento del ajuste de % (' || (r->'asiento'->>'numero') || ') se reversó en el libro '
                                                           'por fuera de aquí: el mes quedó sin su ajuste. Vuelve a postearlo.'
                     then 'sí' else 'no: ' || pg_temp.c12_ctl_det(20) || ' // ' || pg_temp.c12_ctl_det(50) end);
    b := case when (v_j->>'puede_postear')::boolean and (v_j->'ajuste'->>'por_fuera')::boolean
                   and v_j->>'nota' like 'El asiento del ajuste de % se reversó en el libro por fuera de aquí: vuelve a postearlo (o deshazlo).'
              then 'sí' else 'no: ' || coalesce(v_j->>'nota', 'sin nota') end;
    r2 := pg_temp.c12_postear();
    c := case when (r2->>'posteado')::boolean and (r2->'rehecho'->>'por_fuera')::boolean and r2->'rehecho'->>'ajuste_id' = r->>'ajuste_id'
                   and r2->>'nota' like 'Rehecho el ajuste de WIP de %' then 'sí' else 'no: ' || coalesce(r2->>'nota', 'sin nota') end;
    select * into v_w from wip_ajustes x where x.id = (r->>'ajuste_id')::uuid;
    select * into v_w2 from wip_ajustes x where x.id = (r2->>'ajuste_id')::uuid;
    e := format('%s; el nuevo lo sustituye: %s',
                case when v_w.deshecho_el is not null and v_w.por_fuera and v_w.reverso_id = (v->>'id')::uuid
                          and v_w.deshecho_motivo = 'Su asiento se reversó en el libro por fuera del WIP: C12 PRUEBA: reversado a mano en el libro'
                     then 'sí' else 'no: ' || coalesce(v_w.deshecho_motivo, 'sin motivo') end,
                case when v_w2.sustituye_a = v_w.id and v_w2.deshecho_el is null then 'sí' else 'no' end);
    f := format('el control del ajuste %s, y los demás cuadres: %s', pg_temp.c12_ctl(50), pg_temp.c12_propios());
    perform pg_temp.c12_ser('dueno');
    v2 := fn_reversar((r2->'asiento'->>'id')::uuid, 'C12 PRUEBA: reversado a mano otra vez');
    perform pg_temp.c12_ser('editor');
    select count(*) into v_n from asientos;
    d := pg_temp.c12_deshacer('C12 PRUEBA: ya estaba reversado en el libro');
    g := case when (d->>'por_fuera')::boolean and d->'reverso'->>'id' = v2->>'id' and (select count(*) from asientos) = v_n
                   and d->>'nota' like 'El asiento ' || (r2->'asiento'->>'numero') || ' ya se había reversado en el libro (' || (v2->>'numero')
                                       || '): el ajuste de % queda anotado como deshecho.'
                   and (select x.por_fuera and x.reverso_id = (v2->>'id')::uuid from wip_ajustes x where x.id = (r2->>'ajuste_id')::uuid)
              then 'sí' else 'no: ' || coalesce(d->>'nota', 'sin nota') end;
    v_obt := format('reversado a mano: %s | el resumen lo dice y deja postear: %s | postear otra vez: lo rehace, diciendo que el anterior se '
                    'reversó por fuera: %s | el anterior queda anotado (por fuera, con el reverso que lo quitó y su motivo): %s | %s | otra '
                    'vez a mano, y deshacer: solo lo anota (por fuera), sin otro asiento: %s | vivos en el mes: %s, y el saldo de '
                    'sub-facturado de A al cierre: %s', a, b, c, e, f, g,
                    (select count(*) from wip_ajustes x where x.periodo = pg_temp.c12('mes') and x.deshecho_el is null),
                    pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'EL ASIENTO DEL AJUSTE REVERSADO POR FUERA (a mano en el libro, sin pasar por el WIP): la capa lo ve (el cuadre 20 y el del ajuste en rojo, y el resumen lo dice); postear otra vez lo anota como deshecho por fuera y pone el nuevo; deshacer, solo lo anota, sin otro asiento',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. CUÁNDO NO SE POSTEA: un mes que todavía no termina (siguen entrando
--     costos y facturas), uno que no existe, la apertura; sin obras listas;
--     y con lo ganado igual a lo facturado (nada que ajustar: no entra un
--     asiento vacío). (Las dos últimas, si en el mes de las pruebas no hay
--     obras REALES listas: con ellas, postear las postearía.)
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); v_curso text; v_reales int := 0; v_n bigint; v_w bigint;
  a text; b text; c text; d text;
  v_esp text;
begin
  select p.periodo into v_curso from periodos p
   where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta >= fn_fecha_miami(now()) order by p.desde limit 1;
  if v_mes is not null then
    v_reales := coalesce((fn_wip_plan(v_mes)->'totales'->>'obras')::int, 0);
  end if;
  v_esp := case when v_curso is null then 'no hay un mes abierto sin terminar'
                else 'un mes que todavía no termina: MX002, y dice desde cuándo se puede: sí' end
           || ' | un mes que no existe: MX002; la apertura: MX002; sin mes: MX002 | '
           || case when v_reales > 0 then format('(en el mes de las pruebas hay %s obra(s) real(es) lista(s): postear sin obras listas no se '
                                                 'prueba) | con lo ganado igual a lo facturado, la obra no pone líneas: sí', v_reales)
                   else 'sin obras listas: no postea y lo dice, sin asientos ni ajustes nuevos: sí | con lo ganado igual a lo facturado: la '
                        'obra no pone líneas, no postea y lo dice, y el control del ajuste queda en verde: sí' end;
  if pg_temp.c12_omitir(28, 'cuándo no se postea', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    a := case when v_curso is null then 'no hay un mes abierto sin terminar'
              else format('un mes que todavía no termina: %s, y dice desde cuándo se puede: %s',
                          pg_temp.c12_estado('select public.fn_wip_postear(' || quote_literal(v_curso) || ')'),
                          case when pg_temp.c12_dice('select public.fn_wip_postear(' || quote_literal(v_curso) || ')')
                                    like 'MX002 % todavía no termina (su último día es el %; hoy es % en Miami): el ajuste del WIP se postea '
                                         'con el mes terminado, desde el %' then 'sí' else 'no' end) end;
    b := format('un mes que no existe: %s; la apertura: %s; sin mes: %s',
                pg_temp.c12_estado('select public.fn_wip_postear(''2019-01'')'),
                pg_temp.c12_estado('select public.fn_wip_postear(' || quote_literal((select p.periodo from periodos p where p.tipo = 'apertura' limit 1)) || ')'),
                pg_temp.c12_estado('select public.fn_wip_postear(null)'));
    if v_reales > 0 then
      c := format('(en el mes de las pruebas hay %s obra(s) real(es) lista(s): postear sin obras listas no se prueba)', v_reales);
      perform pg_temp.c12_costo('c12-prueba-a', 3000);
      perform pg_temp.c12_factura(1, 'c12-prueba-a', 5000);
      perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
      d := 'con lo ganado igual a lo facturado, la obra no pone líneas: '
           || case when pg_temp.c12_plan_lineas('c12-prueba-a') = '-' and pg_temp.c12_fila('c12-prueba-a') like 'lista: %sub 0.00, sobre 0.00,%'
                   then 'sí' else 'no: ' || pg_temp.c12_plan_lineas('c12-prueba-a') end;
    else
      select count(*) into v_n from asientos;
      select count(*) into v_w from wip_ajustes;
      r := pg_temp.c12_postear();
      c := 'sin obras listas: no postea y lo dice, sin asientos ni ajustes nuevos: '
           || case when not (r->>'posteado')::boolean and r->>'nota' like 'En % ninguna obra está lista para el ajuste%'
                        and (select count(*) from asientos) = v_n and (select count(*) from wip_ajustes) = v_w
                   then 'sí' else 'no: ' || coalesce(r->>'nota', 'sin nota') end;
      perform pg_temp.c12_costo('c12-prueba-a', 3000);
      perform pg_temp.c12_factura(1, 'c12-prueba-a', 5000);
      perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
      select count(*) into v_n from asientos;
      r := pg_temp.c12_postear();
      d := 'con lo ganado igual a lo facturado: la obra no pone líneas, no postea y lo dice, y el control del ajuste queda en verde: '
           || case when pg_temp.c12_plan_lineas('c12-prueba-a') = '-' and pg_temp.c12_fila('c12-prueba-a') like 'lista: %sub 0.00, sobre 0.00,%'
                        and not (r->>'posteado')::boolean
                        and r->>'nota' like 'En % no hay nada que ajustar: en las 1 obra(s) listas lo ganado es lo facturado, al centavo.'
                        and (select count(*) from asientos) = v_n and (select count(*) from wip_ajustes) = v_w
                        and pg_temp.c12_ctl(50) = 'verde' and pg_temp.c12_ctl_det(50) like 'En % no hay nada que ajustar: en las 1 obra(s) listas%'
                   then 'sí' else 'no: ' || coalesce(r->>'nota', 'sin nota') || ' // ' || pg_temp.c12_ctl_det(50) end;
    end if;
    v_obt := format('%s | %s | %s | %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'CUÁNDO NO SE POSTEA: un mes que todavía no termina (MX002: siguen entrando costos y facturas), uno que no existe o la apertura (MX002); sin obras listas no entra nada y se dice; y con lo ganado igual a lo facturado no entra un asiento vacío (y el control queda en verde)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. EL MES CERRADO NO SE TOCA. Con el ajuste posteado se cierra el mes (la
--     prueba cierra dentro de su subtransacción la apertura y el mes de las
--     pruebas): ya no se postea, ni se deshace, ni se revisa (MX002); su WIP
--     es la FOTO de su ajuste, y no cambia aunque después cambie la ficha o
--     llegue más costo; su reverso del día 1 sigue en el mes siguiente.
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); v_sig text := pg_temp.c12('mes_sig'); v_h date := pg_temp.c12_h();
  v_no text; v_j jsonb; v_antes text; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'cerrado: postear MX002, deshacer MX002, revisar MX002 | su WIP es la foto de su ajuste (fuente «posteado»): 11 obras de '
                'prueba, 3 en el ajuste | después cambia la ficha de A y llega más costo: su fila del mes cerrado no cambia: sí | el control: '
                'el de la revisión «no aplica» y el del ajuste dice que está cerrado con su ajuste: sí | el resumen: cerrado, fuente '
                'posteado, sin postear ni deshacer, con las 8 líneas posteadas de las obras de prueba: sí | su reverso del día 1 sigue en el '
                'mes siguiente: el saldo de sub-facturado de A al día 1 es 0.00, y el ajuste sigue siendo el del mes: sí | en el mes '
                'siguiente A espera su revisión, con lo del mes anterior propuesto: sí';
begin
  if pg_temp.c12_omitir(29, 'el mes cerrado no se toca', v_esp) then return; end if;
  begin
    perform pg_temp.c12_ser('editor');
    lock table public.periodos in exclusive mode;
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    v_antes := pg_temp.c12_fila('c12-prueba-a');
    begin
      perform pg_temp.c12_cerrar_hasta(v_mes);
    exception when others then
      v_no := format('el libro no dejó cerrar %s dentro de la prueba (%s: %s)', v_mes, sqlstate, left(sqlerrm, 300));
    end;
    if v_no is null then
      a := format('postear %s, deshacer %s, revisar %s',
                  pg_temp.c12_estado('select public.fn_wip_postear(' || quote_literal(v_mes) || ')'),
                  pg_temp.c12_estado('select public.fn_wip_deshacer(' || quote_literal(v_mes) || ', ''C12 PRUEBA: en un mes cerrado'')'),
                  pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-a'', ' || quote_literal(v_mes) || ', ''{"costo_estimado": "7500", "nota": "C12 PRUEBA"}''::jsonb)'));
      select format('%s obras de prueba, %s en el ajuste', count(*), count(*) filter (where s.en_ajuste)) into b
        from fn_wip_schedule(v_mes) s where s.proyecto_id like 'c12-prueba-%' and s.fuente = 'posteado';
      update finanzas_proyecto set contrato = 12000 where proyecto_id = 'c12-prueba-a';
      perform pg_temp.c12_costo('c12-prueba-a', 1500, 2, '5100', v_sig);
      c := case when pg_temp.c12_fila('c12-prueba-a') = v_antes and v_antes like 'lista: precio 10000.00, est 6000.00, % sub 3000.00, %'
                then 'sí' else 'no: ' || pg_temp.c12_fila('c12-prueba-a') end;
      d := case when pg_temp.c12_ctl(40) = 'verde' and pg_temp.c12_ctl_det(40) like 'No aplica: % ya está cerrado; su WIP es el que se posteó.'
                     and pg_temp.c12_ctl(50) = 'verde'
                     and pg_temp.c12_ctl_det(50) like '% está cerrado con su ajuste de WIP (asiento ' || (r->'asiento'->>'numero') || '): sub-facturado %'
                then 'sí' else 'no: ' || pg_temp.c12_ctl_det(40) || ' // ' || pg_temp.c12_ctl_det(50) end;
      perform pg_temp.c12_ser('dueno');
      v_j := fn_wip_resumen(v_mes);
      perform pg_temp.c12_ser('editor');
      e := case when (v_j->>'cerrado')::boolean and v_j->>'fuente' = 'posteado' and not (v_j->>'puede_postear')::boolean
                     and not (v_j->>'puede_deshacer')::boolean and v_j->>'por_que_no' like '% ya está cerrado: su WIP es el que se posteó.'
                     and (select count(*) from jsonb_array_elements(v_j->'lineas') l
                           where l->>'proyecto_id' like 'c12-prueba-%' and l->>'cuenta_nombre' is not null and l->>'obra' like 'C12 PRUEBA Obra %') = 8
                     and v_j->'ajuste'->>'numero' = r->'asiento'->>'numero'
                then 'sí' else 'no: ' || left(v_j::text, 400) end;
      f := format('el saldo de sub-facturado de A al día 1 es %s, y el ajuste sigue siendo el del mes: %s',
                  pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h + 1),
                  case when (select count(*) from wip_ajustes x where x.periodo = v_mes and x.deshecho_el is null and x.id = (r->>'ajuste_id')::uuid) = 1
                            and pg_temp.c12_saldo('1200', 'c12-prueba-a', v_h) = 3000 then 'sí' else 'no' end);
      select case when s.estado = 'pendiente' and s.falta = array['revision'] and s.propuesta_costo_estimado = 6000 and s.propuesta_origen = 'mes_anterior'
                  then 'sí' else format('no: %s %s, propone %s (%s)', s.estado, s.falta, s.propuesta_costo_estimado, s.propuesta_origen) end into g
        from fn_wip_schedule(v_sig) s where s.proyecto_id = 'c12-prueba-a';
      v_obt := format('cerrado: %s | su WIP es la foto de su ajuste (fuente «posteado»): %s | después cambia la ficha de A y llega más costo: '
                      'su fila del mes cerrado no cambia: %s | el control: el de la revisión «no aplica» y el del ajuste dice que está '
                      'cerrado con su ajuste: %s | el resumen: cerrado, fuente posteado, sin postear ni deshacer, con las 8 líneas posteadas '
                      'de las obras de prueba: %s | su reverso del día 1 sigue en el mes siguiente: %s | en el mes siguiente A espera su '
                      'revisión, con lo del mes anterior propuesto: %s', a, b, c, d, e, f, coalesce(g, 'no sale'));
    else
      v_obt := 'omitida: ' || v_no;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'EL MES CERRADO NO SE TOCA: con el mes cerrado no se postea, ni se deshace, ni se revisa (MX002); su WIP es la foto de su ajuste tal como se posteó, y no cambia aunque después cambie la ficha o llegue más costo; su reverso del día 1 sigue en el mes siguiente, donde la obra espera su revisión',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 30. EL MES SIGUIENTE: el WIP es ACUMULADO, y lo que lee de la obra en el
--     libro (costo y facturado) NO cuenta sus propios ajustes ni sus
--     reversos. Con el ajuste de octubre en el libro (que dejó 3,000 más de
--     ingreso y, en C, 1,000 de gasto por la pérdida al cierre), A sigue con
--     3,000 de costo y 2,000 facturados; con 1,500 más de costo en el mes
--     siguiente va al 75 %: ganó 7,500 y su ajuste sería 5,500 (el
--     acumulado, no la diferencia con el mes anterior).
do $$
declare
  v_obt text; r jsonb; v_sig text := pg_temp.c12('mes_sig'); v_h date := pg_temp.c12_h(); a text; b text; c text; d text;
  v_esp text := 'al cierre del mes, con el ajuste ya en el libro, lo que el WIP lee de la obra no lo cuenta: A: costo 3000.00, facturado '
                '2000.00, otro ingreso 0.00; C: costo 6000.00 | el mes siguiente, con 1500 más de costo: lista: precio 10000.00, est '
                '6000.00, util est 4000.00, costo 4500.00, 75.00 %, ganado 7500.00, fact 2000.00, sub 5500.00, sobre 0.00, para terminar '
                '1500.00, util 3000.00, perdida 0.00, prov 0.00 | su ajuste sería el acumulado (no la diferencia con el mes anterior): 1200 '
                '5500.00 / ingreso -5500.00 | y el ajuste del mes anterior sigue al día: sí';
begin
  if pg_temp.c12_omitir(30, 'el mes siguiente no cuenta los ajustes', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    select format('A: costo %s, facturado %s, otro ingreso %s; C: costo %s', x.costo, x.facturado, x.ingreso_otro, y.costo) into a
      from fn_wip_libro(v_h, 'c12-prueba-a') x, fn_wip_libro(v_h, 'c12-prueba-c') y;
    perform pg_temp.c12_costo('c12-prueba-a', 1500, 2, '5100', v_sig);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}', v_sig);
    b := pg_temp.c12_fila('c12-prueba-a', v_sig);
    c := pg_temp.c12_plan_lineas('c12-prueba-a', v_sig);
    d := case when (fn_wip_ajuste_estado(pg_temp.c12('mes'))->>'al_dia')::boolean then 'sí'
              else 'no: ' || coalesce(fn_wip_ajuste_estado(pg_temp.c12('mes'))->>'cambios', 'sin cambios') end;
    v_obt := format('al cierre del mes, con el ajuste ya en el libro, lo que el WIP lee de la obra no lo cuenta: %s | el mes siguiente, con '
                    '1500 más de costo: %s | su ajuste sería el acumulado (no la diferencia con el mes anterior): %s | y el ajuste del mes '
                    'anterior sigue al día: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'EL MES SIGUIENTE: el WIP es acumulado desde el inicio de la obra, y el costo y lo facturado que lee del libro NO cuentan sus propios ajustes ni sus reversos (ni el gasto de la provisión por pérdida); el ajuste del mes siguiente es el acumulado a su cierre, no la diferencia con el anterior',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- LOS CONTROLES
-- ---------------------------------------------------------------------
-- La fila de un período en fn_wip_cierre (como el SQL Editor).
create or replace function pg_temp.c12_cie(p_orden int, p_per text default null)
returns table (ok boolean, nivel text, detalle text, que_hacer text, ir_a text) language sql as $$
  select c.ok, c.nivel, c.detalle, c.que_hacer, c.ir_a from fn_wip_cierre(coalesce(p_per, pg_temp.c12('mes'))) c where c.orden = p_orden
$$;
-- El mes en curso: abierto y sin terminar (nulo si no lo hay).
create or replace function pg_temp.c12_curso() returns text language sql as $$
  select p.periodo from periodos p
   where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta >= fn_fecha_miami(now()) and p.desde <= fn_fecha_miami(now())
   order by p.desde limit 1
$$;

-- 31. EL CUADRE 10: en las cuentas del WIP (1200, 2400, 2410, 5950) solo está
--     el ajuste. Un asiento A MANO en sub-facturado lo pone en rojo (y al 20:
--     el saldo por obra ya no es el del ajuste), la fila 174 del cierre
--     detiene; reversado, vuelve a verde.
do $$
declare
  v_obt text; r jsonb; f record; a text; b text; c text; d text;
  v_esp text := 'un asiento a mano de 500 en sub-facturado (obra A): el cuadre 10 rojo y lo dice: sí; el 20 rojo (el saldo por obra no es '
                'el del ajuste): sí; la fila 174 del cierre detiene, con el detalle y qué hacer: sí | reversado: nada nuevo en rojo';
begin
  if pg_temp.c12_omitir(31, 'el cuadre 10: un asiento a mano en las cuentas del WIP', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_ser('dueno');
    r := fn_postear(jsonb_build_object('fecha', pg_temp.c12_d(12)::text,
           'descripcion', 'C12 PRUEBA: un asiento a mano en sub-facturado (se deshace)',
           'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1200', 'monto', '500.00', 'proyecto_id', 'c12-prueba-a'),
                                       jsonb_build_object('cuenta', '3100', 'monto', '-500.00'))));
    perform pg_temp.c12_ser('editor');
    a := case when pg_temp.c12_ctl(10) = 'rojo'
                   and pg_temp.c12_ctl_det(10) like 'Hay saldo en las cuentas del WIP que no viene de un ajuste: %$500.00 en la 1200 de C12 PRUEBA Obra A%'
              then 'sí' else 'no: ' || pg_temp.c12_ctl_det(10) end;
    b := case when pg_temp.c12_ctl(20) = 'rojo'
                   and pg_temp.c12_ctl_det(20) like '%El saldo por obra no es el del ajuste de %1200 de C12 PRUEBA Obra A: saldo $500.00 al % y el ajuste dice $0.00%'
              then 'sí' else 'no: ' || pg_temp.c12_ctl_det(20) end;
    select * into f from pg_temp.c12_cie(174);
    c := case when not f.ok and f.nivel = 'detiene' and f.detalle like '%$500.00 en la 1200 de C12 PRUEBA Obra A%'
                   and f.que_hacer like '%Un asiento a mano en las cuentas del WIP se reversa%' and f.ir_a = 'wip'
              then 'sí' else 'no: ' || coalesce(f.detalle, 'sin fila') end;
    perform pg_temp.c12_ser('dueno');
    perform fn_reversar((r->>'id')::uuid, 'C12 PRUEBA: no iba a mano');
    perform pg_temp.c12_ser('editor');
    d := pg_temp.c12_propios();
    v_obt := format('un asiento a mano de 500 en sub-facturado (obra A): el cuadre 10 rojo y lo dice: %s; el 20 rojo (el saldo por obra no '
                    'es el del ajuste): %s; la fila 174 del cierre detiene, con el detalle y qué hacer: %s | reversado: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'EL CUADRE 10 EN ROJO Y DE VUELTA: en las cuentas del WIP solo está el ajuste del mes; un asiento a mano en sub-facturado lo pone en rojo (y al 20: el saldo por obra ya no es el del ajuste) y la fila 174 del cierre detiene con su detalle y qué hacer; reversado, vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. EL CUADRE 30: lo facturado a la fecha = las facturas del libro. Es un
--     cable trampa (con los puentes de c3 sanos no se puede poner en rojo sin
--     romper sus guardas: una factura contabilizada ya no cambia); aquí se
--     prueba que NO salta con lo que sí pasa: dos facturas, una anulada con
--     su nota de crédito dentro del mes (lo facturado baja) y otra anulada el
--     mes siguiente (al cierre del mes todavía cuenta; después, no).
do $$
declare
  v_obt text; v_sig text := pg_temp.c12('mes_sig'); v_h date := pg_temp.c12_h(); v_f date; a text; b text; c text; d text;
  v_esp text := 'dos facturas (2000 y 1500): facturado 3500.00, sub 1500.00 | la segunda anulada con su nota de crédito dentro del mes: '
                'facturado 2000.00, sub 3000.00 | otra de 800 anulada el mes siguiente: al cierre del mes cuenta (facturado 2800.00) y al '
                'del siguiente ya no (2000.00) | el cuadre en los dos meses: nada nuevo en rojo y nada nuevo en rojo';
begin
  if pg_temp.c12_omitir(32, 'el cuadre 30: lo facturado = las facturas del libro', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    perform pg_temp.c12_factura(10, 'c12-prueba-a', 1500, 13);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    select format('facturado %s, sub %s', s.facturado_fecha, s.sub_facturado) into a
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_ser('dueno');
    perform fn_factura_anular(-1200010, 'C12 PRUEBA: se anula dentro del mes', pg_temp.c12_d(15));
    perform pg_temp.c12_ser('editor');
    select format('facturado %s, sub %s', s.facturado_fecha, s.sub_facturado) into b
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    perform pg_temp.c12_factura(11, 'c12-prueba-a', 800, 14);
    select least(q.desde + 3, fn_fecha_miami(now())) into v_f from periodos q where q.periodo = v_sig;
    perform pg_temp.c12_ser('dueno');
    perform fn_factura_anular(-1200011, 'C12 PRUEBA: se anula el mes siguiente', v_f);
    perform pg_temp.c12_ser('editor');
    select format('al cierre del mes cuenta (facturado %s) y al del siguiente ya no (%s)', s.facturado_fecha,
                  (select x.facturado from fn_wip_libro((select q.hasta from periodos q where q.periodo = v_sig), 'c12-prueba-a') x)) into c
      from fn_wip_schedule(pg_temp.c12('mes')) s where s.proyecto_id = 'c12-prueba-a';
    d := format('%s y %s', pg_temp.c12_propios(), pg_temp.c12_propios(v_sig));
    v_obt := format('dos facturas (2000 y 1500): %s | la segunda anulada con su nota de crédito dentro del mes: %s | otra de 800 anulada el '
                    'mes siguiente: %s | el cuadre en los dos meses: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'EL CUADRE 30 (lo facturado a la fecha = las facturas del libro) no salta con lo que sí pasa: una factura anulada con su nota de crédito baja lo facturado desde la fecha de la nota (dentro del mes, ya; el mes siguiente, al cierre del mes todavía cuenta), y el cuadre sigue en verde en los dos meses',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. EL CUADRE 40 (cada obra con movimiento, revisada en el mes) ES
--     EXIGIBLE: en rojo solo si el mes ya terminó y el WIP se exige desde ese
--     mes (wip_config.exigir_desde); si no, en verde diciendo cuánto falta.
--     Revisada la obra, deja de nombrarla. Y una obra cuyo tipo no tiene su
--     cuenta de ingreso confirmada tampoco entra (solo se puede probar donde
--     la regla del tipo de obra sigue en borrador).
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); v_sig text := pg_temp.c12('mes_sig'); v_curso text := pg_temp.c12_curso();
  v_sinregla boolean; f record; a text; b text; c text; d text; e text; g text;
  v_esp text;
begin
  select exists (select 1 from mapeo_tipo_proyecto m where m.tipo = 'comercial' and m.confirmado_el is null) into v_sinregla;
  v_esp := 'exigido y sin revisar: el cuadre rojo y nombra la obra: sí; la fila 175 del cierre detiene y dice qué hacer: sí | exigido solo '
           'desde el mes siguiente: verde, y dice cuánto falta: sí | sin decir desde cuándo: verde, y lo dice: sí | '
           || case when v_curso is null then '(no hay un mes en curso abierto)'
                   else 'el mes en curso, exigido pero sin terminar: verde, y dice que se hace al cerrarlo: sí' end
           || ' | revisada: el cuadre ya no la nombra | '
           || case when v_sinregla then 'con la regla del tipo de obra en borrador: pendiente {revision,cuenta_ingreso}; revisada: pendiente '
                                        '{cuenta_ingreso}, fuera del ajuste, y el cuadre lo dice: sí; confirmada la regla: lista'
                   else '(la regla del tipo de obra ya está confirmada en esta base: la obra sin cuenta de ingreso no se prueba)' end;
  if pg_temp.c12_omitir(33, 'el cuadre 40: cada obra revisada, exigible', v_esp) then return; end if;
  begin
    -- (antes de sembrar: la regla del tipo de obra como esté en esta base)
    if v_sinregla then
      perform pg_temp.c12_ser('editor');
      insert into proyectos (id, tipo, nombre, estado) values ('c12-prueba-z', 'comercial', 'C12 PRUEBA Obra Z', 'ejecucion');
      insert into finanzas_proyecto (proyecto_id, contrato) values ('c12-prueba-z', 7000);
      perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
      perform pg_temp.c12_costo('c12-prueba-z', 100);
      select format('%s {%s}', s.estado, array_to_string(s.falta, ',')) into g from fn_wip_schedule(v_mes) s where s.proyecto_id = 'c12-prueba-z';
      perform pg_temp.c12_rev('c12-prueba-z', '{"costo_estimado": "500"}');
      select g || format('; revisada: %s {%s}, %s, y el cuadre lo dice: %s', s.estado, array_to_string(s.falta, ','),
                         case when s.en_ajuste then 'DENTRO del ajuste' else 'fuera del ajuste' end,
                         case when pg_temp.c12_ctl_det(40) like '%C12 PRUEBA Obra Z (su tipo no tiene cuenta de ingreso confirmada)%'
                                   and s.falta_texto like 'Su tipo de obra (comercial) no tiene cuenta de ingreso confirmada%' then 'sí'
                              else 'no: ' || pg_temp.c12_ctl_det(40) end) into g
        from fn_wip_schedule(v_mes) s where s.proyecto_id = 'c12-prueba-z';
    end if;
    perform pg_temp.c12_sembrar();
    if v_sinregla then
      select 'con la regla del tipo de obra en borrador: ' || g || '; confirmada la regla: ' || s.estado into g
        from fn_wip_schedule(v_mes) s where s.proyecto_id = 'c12-prueba-z';
    else
      g := '(la regla del tipo de obra ya está confirmada en esta base: la obra sin cuenta de ingreso no se prueba)';
    end if;
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    select * into f from pg_temp.c12_cie(175);
    a := format('el cuadre %s y nombra la obra: %s; la fila 175 del cierre detiene y dice qué hacer: %s', pg_temp.c12_ctl(40),
                case when pg_temp.c12_nombra(40, 'a') = 'sí' and pg_temp.c12_ctl_det(40) like 'Faltan por revisar % de las % obra(s) de precio fijo con movimiento en %' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(40) end,
                case when not f.ok and f.nivel = 'detiene' and f.detalle = pg_temp.c12_ctl_det(40) and f.que_hacer like '%decide cada obra de la lista%'
                     then 'sí' else 'no' end);
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_sig));
    b := format('%s, y dice cuánto falta: %s', pg_temp.c12_ctl(40),
                case when pg_temp.c12_ctl_det(40) like 'En % el WIP todavía no se exige para cerrar (se exige desde ' || fn_wip_mes(v_sig)
                                                       || '). Hoy faltan por revisar % de %: %C12 PRUEBA Obra A%'
                          and (select x.ok from pg_temp.c12_cie(175) x) then 'sí' else 'no: ' || pg_temp.c12_ctl_det(40) end);
    perform fn_wip_config('{"exigir_desde": null}'::jsonb);
    c := format('%s, y lo dice: %s', pg_temp.c12_ctl(40),
                case when pg_temp.c12_ctl_det(40) like 'En % el WIP todavía no se exige para cerrar (no se ha dicho desde qué mes). Hoy faltan por revisar %'
                     then 'sí' else 'no: ' || pg_temp.c12_ctl_det(40) end);
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    d := case when v_curso is null then '(no hay un mes en curso abierto)'
              else format('el mes en curso, exigido pero sin terminar: %s, y dice que se hace al cerrarlo: %s', pg_temp.c12_ctl(40, v_curso),
                          case when pg_temp.c12_ctl_det(40, v_curso) like '% termina el %: se hace al cerrar el mes. Hoy faltan por revisar % de %: %C12 PRUEBA Obra A%'
                               then 'sí' else 'no: ' || pg_temp.c12_ctl_det(40, v_curso) end) end;
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    e := case pg_temp.c12_nombra(40, 'a') when 'no' then 'el cuadre ya no la nombra' else 'el cuadre la SIGUE nombrando' end;
    v_obt := format('exigido y sin revisar: %s | exigido solo desde el mes siguiente: %s | sin decir desde cuándo: %s | %s | revisada: %s | %s',
                    a, b, c, d, e, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'EL CUADRE 40 EN ROJO Y DE VUELTA, Y ES EXIGIBLE: cada obra de precio fijo con movimiento necesita su costo estimado revisado en el mes; detiene el cierre (fila 175) solo si el mes ya terminó y el WIP se exige desde ese mes (wip_config.exigir_desde); si no, está en verde diciendo cuánto falta; revisada la obra, deja de nombrarla; y la obra cuyo tipo no tiene cuenta de ingreso confirmada no entra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. EL CUADRE 50 (el ajuste del mes posteado y al día) ES EXIGIBLE: con
--     obras listas y sin postear, en rojo solo si el mes ya terminó y el WIP
--     se exige desde ese mes; si no, en verde diciendo lo que daría.
--     Posteado, verde (la fila 176 del cierre deja de detener).
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); v_sig text := pg_temp.c12('mes_sig'); v_curso text := pg_temp.c12_curso();
  f record; a text; b text; c text; d text; e text;
  v_esp text;
begin
  v_esp := 'exigido, con obras listas y sin postear: el cuadre rojo y dice lo que falta postear: sí; la fila 176 del cierre detiene y dice '
           'qué hacer: sí | exigido solo desde el mes siguiente: verde, y dice lo que daría: sí | sin decir desde cuándo: verde | '
           || case when v_curso is null then '(no hay un mes en curso abierto)'
                   else 'el mes en curso, exigido pero sin terminar: verde, y dice que se hace al cerrarlo: sí' end
           || ' | posteado: verde, dice el asiento y cuándo se deshace: sí; y quién quedó fuera: sí; la fila 176 ya no detiene: sí';
  if pg_temp.c12_omitir(34, 'el cuadre 50: el ajuste posteado, exigible', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    -- (una obra que ya andaba, revisada y sin lo de antes confirmado: no entra, y el texto del ajuste lo tiene que decir)
    perform pg_temp.c12_factura(7, 'c12-prueba-g', 3000, -10);
    perform pg_temp.c12_costo('c12-prueba-g', 2000);
    perform pg_temp.c12_rev('c12-prueba-g', '{"costo_estimado": "9000"}');
    select * into f from pg_temp.c12_cie(176);
    a := format('el cuadre %s y dice lo que falta postear: %s; la fila 176 del cierre detiene y dice qué hacer: %s', pg_temp.c12_ctl(50),
                case when pg_temp.c12_ctl_det(50) like 'Falta postear el ajuste de WIP de ' || fn_wip_mes(v_mes) || ': sub-facturado % en % obra(s), '
                                                       'sobre-facturado % en %, y pérdida por reconocer %.' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(50) end,
                case when not f.ok and f.nivel = 'detiene' and f.detalle = pg_temp.c12_ctl_det(50) and f.que_hacer like '%toca «Postear el ajuste»%'
                     then 'sí' else 'no' end);
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_sig));
    b := format('%s, y dice lo que daría: %s', pg_temp.c12_ctl(50),
                case when pg_temp.c12_ctl_det(50) like 'En % el WIP todavía no se exige para cerrar (se exige desde ' || fn_wip_mes(v_sig)
                                                       || '). Hoy daría el ajuste de WIP de %: sub-facturado % en % obra(s), sobre-facturado %'
                          and (select x.ok from pg_temp.c12_cie(176) x) then 'sí' else 'no: ' || pg_temp.c12_ctl_det(50) end);
    perform fn_wip_config('{"exigir_desde": null}'::jsonb);
    c := pg_temp.c12_ctl(50);
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    if v_curso is null then
      d := '(no hay un mes en curso abierto)';
    else
      perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}', v_curso);
      d := format('el mes en curso, exigido pero sin terminar: %s, y dice que se hace al cerrarlo: %s', pg_temp.c12_ctl(50, v_curso),
                  case when pg_temp.c12_ctl_det(50, v_curso) like '% termina el %: se hace al cerrar el mes. Hoy daría el ajuste de WIP de %'
                       then 'sí' else 'no: ' || pg_temp.c12_ctl_det(50, v_curso) end);
    end if;
    r := pg_temp.c12_postear();
    select * into f from pg_temp.c12_cie(176);
    e := format('%s, dice el asiento y cuándo se deshace: %s; y quién quedó fuera: %s; la fila 176 ya no detiene: %s', pg_temp.c12_ctl(50),
                case when pg_temp.c12_ctl_det(50) like 'El ajuste de ' || fn_wip_mes(v_mes) || ' está posteado y al día (asiento ' || (r->'asiento'->>'numero')
                                                       || ', del ' || fn_wip_dia(pg_temp.c12_h()) || '; se deshace solo el ' || fn_wip_dia(pg_temp.c12_h() + 1)
                                                       || '): sub-facturado %, sobre-facturado % y pérdida %, en % obra(s).%' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(50) end,
                case when pg_temp.c12_ctl_det(50) like '%OJO: % obra(s) NO entran en el ajuste porque les falta algo (%C12 PRUEBA Obra G%)%'
                     then 'sí' else 'no: ' || pg_temp.c12_ctl_det(50) end,
                case when f.ok and f.que_hacer is null and f.detalle = pg_temp.c12_ctl_det(50) then 'sí' else 'no' end);
    v_obt := format('exigido, con obras listas y sin postear: %s | exigido solo desde el mes siguiente: %s | sin decir desde cuándo: %s | %s '
                    '| posteado: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'EL CUADRE 50 EN ROJO Y DE VUELTA, Y ES EXIGIBLE: con obras listas, el ajuste del mes tiene que estar posteado y al día; detiene el cierre (fila 176) solo si el mes ya terminó y el WIP se exige desde ese mes; si no, está en verde diciendo lo que daría; posteado, vuelve a verde y dice su asiento y cuándo se deshace',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. EL CUADRE 60 Y LA FILA 174: una obra con más costo que su estimado
--     revisado detiene el cierre, TENGA O NO una nota su revisión (una nota
--     por otra cosa no lo salta); el nombre de la fila 174 dice cuál de sus
--     cuadres está en rojo; subiendo el estimado, vuelve a verde.
do $$
declare
  v_obt text; f record; a text; b text; c text;
  v_esp text := 'revisada con una nota por otra cosa (5000) y después con 6500 de costo: el cuadre 60 la nombra con sus cifras: sí; la fila '
                '174 del cierre detiene, la nombra y su nombre dice cuál está en rojo: sí | subido el estimado a 13000: el cuadre ya no la '
                'nombra, la fila 174 tampoco, y los cuadres: nada nuevo en rojo';
begin
  if pg_temp.c12_omitir(35, 'el cuadre 60 y la fila 174 del cierre', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', pg_temp.c12('mes')));
    perform pg_temp.c12_costo('c12-prueba-e', 3000);
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "5000", "nota": "C12 PRUEBA: una nota por otra cosa (la orden de cambio 1)"}');
    perform pg_temp.c12_costo('c12-prueba-e', 3500, 14);
    select c.ok, c.nivel, c.detalle, c.que_hacer, c.control into f from fn_wip_cierre(pg_temp.c12('mes')) c where c.orden = 174;
    a := case when pg_temp.c12_ctl(60) = 'rojo'
                   and pg_temp.c12_ctl_det(60) like '%C12 PRUEBA Obra E (lleva $6,500.00 y su estimado es $5,000.00: 130 %)%Ese estimado quedó viejo%'
              then 'sí' else 'no: ' || pg_temp.c12_ctl_det(60) end;
    b := case when not f.ok and f.nivel = 'detiene' and f.detalle like '%C12 PRUEBA Obra E (lleva $6,500.00 y su estimado es $5,000.00: 130 %)%'
                   and f.que_hacer is not null and f.control ~ '^wip: los cuadres del WIP \(c12\) — [0-9]+ en rojo: ([0-9]+, )*60(, [0-9]+)*$'
              then 'sí' else 'no: ' || coalesce(f.control || ': ' || f.detalle, 'sin fila') end;
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "13000", "nota": "C12 PRUEBA: estimado puesto al día"}');
    select * into f from pg_temp.c12_cie(174);
    c := format('el cuadre %s, la fila 174 %s, y los cuadres: %s',
                case pg_temp.c12_nombra(60, 'e') when 'no' then 'ya no la nombra' else 'la SIGUE nombrando' end,
                case when f.detalle not like '%C12 PRUEBA Obra E%' then 'tampoco' else 'SÍ' end, pg_temp.c12_propios());
    v_obt := format('revisada con una nota por otra cosa (5000) y después con 6500 de costo: el cuadre 60 la nombra con sus cifras: %s; la '
                    'fila 174 del cierre detiene, la nombra y su nombre dice cuál está en rojo: %s | subido el estimado a 13000: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'EL CUADRE 60 EN ROJO Y DE VUELTA: una obra con más costo que su estimado revisado pone el cuadre en rojo con sus cifras y la fila 174 del cierre detiene (y su nombre dice cuál de sus cuadres es), tenga o no una nota la revisión; subido el estimado, vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. LOS AVISOS (no detienen): una obra con pérdida (120), facturado por
--     encima del contrato (140), ingreso que no es factura (150), una
--     terminada con costo en el mes y fuera del WIP (160), una activa sin
--     contrato que no es de servicio (165), horas sin costo en el libro (170,
--     con c10) y hitos que no suman el contrato (180). La fila 177 del
--     cierre los junta. (El 110, el 125 y el 130, en las pruebas 15, 12 y 20.)
do $$
declare
  v_obt text; f record; r jsonb; v_mes text := pg_temp.c12('mes'); v_horas boolean;
  a text; b text; c text; d text; e text; g text; h text; i text;
  v_esp text;
begin
  v_horas := pg_temp.c12('hay_c10') = 'true' and pg_temp.c12('equipo') is not null;
  v_esp := 'pérdida (120): nombra la obra, con la pérdida y lo provisionado: sí | facturado por encima del contrato (140): sí, y lo dice '
           'en su fila: sí | ingreso que no es factura (150): sí, y no cuenta como facturado: sí | terminada con costo en el mes y fuera '
           'del WIP (160): sí; revisada como terminada, entra y ya no la nombra: sí | activa sin contrato (165): sí; marcada «tm», ya no: '
           'sí | '
           || case when v_horas then 'horas sin costo en el libro (170): sí'
                   else '(sin el costo por obra (c10) o sin nadie del equipo en esta base: el aviso 170 no se prueba)' end
           || ' | los hitos no suman el contrato (180): sí | la fila 177 del cierre los junta a todos y su nombre dice cuáles, es un aviso y no detiene: sí; y los cuadres: '
              'nada nuevo en rojo';
  if pg_temp.c12_omitir(36, 'los avisos del WIP', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    -- 120: C con pérdida
    perform pg_temp.c12_costo('c12-prueba-c', 6000);
    perform pg_temp.c12_rev('c12-prueba-c', '{"costo_estimado": "12000"}');
    a := case when pg_temp.c12_ctl(120) = 'rojo' and pg_temp.c12_ctl_det(120) like '%C12 PRUEBA Obra C (pérdida $2,000.00; provisionado $1,000.00)%'
              then 'sí' else 'no: ' || pg_temp.c12_ctl_det(120) end;
    -- 140: B con 21,000 facturados y 20,000 de contrato
    perform pg_temp.c12_costo('c12-prueba-b', 4000);
    perform pg_temp.c12_factura(2, 'c12-prueba-b', 21000);
    perform pg_temp.c12_rev('c12-prueba-b', '{"costo_estimado": "16000"}');
    select format('%s, y lo dice en su fila: %s',
                  case when pg_temp.c12_ctl_det(140) like '%C12 PRUEBA Obra B (facturado $21,000.00, contrato $20,000.00)%' then 'sí' else 'no' end,
                  case when exists (select 1 from unnest(s.avisos) t where t like 'Lo facturado ($21,000.00) pasa del contrato ($20,000.00)%') then 'sí' else 'no' end)
      into b from fn_wip_schedule(v_mes) s where s.proyecto_id = 'c12-prueba-b';
    -- 150: A con 300 de ingreso a mano (no es una factura)
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    perform pg_temp.c12_ser('dueno');
    perform fn_postear(jsonb_build_object('fecha', pg_temp.c12_d(12)::text, 'descripcion', 'C12 PRUEBA: un ingreso a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', pg_temp.c12_ingreso('comercial'), 'monto', '-300.00', 'proyecto_id', 'c12-prueba-a'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '300.00'))));
    perform pg_temp.c12_ser('editor');
    select format('%s, y no cuenta como facturado: %s',
                  case when pg_temp.c12_ctl_det(150) like '%C12 PRUEBA Obra A ($300.00)%' then 'sí' else 'no' end,
                  case when s.facturado_fecha = 2000 and s.ingreso_otro = 300 and s.sub_facturado = 3000 then 'sí' else 'no' end)
      into c from fn_wip_schedule(v_mes) s where s.proyecto_id = 'c12-prueba-a';
    -- 160: J, terminada, con costo en el mes y sin haber estado nunca en el WIP
    update proyectos set estado = 'completado' where id = 'c12-prueba-j';
    perform pg_temp.c12_costo('c12-prueba-j', 500);
    d := case when pg_temp.c12_fila('c12-prueba-j') = 'no sale' and pg_temp.c12_nombra(160, 'j') = 'sí' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(160) end;
    perform pg_temp.c12_rev('c12-prueba-j', '{"terminada": true}');
    d := d || '; revisada como terminada, entra y ya no la nombra: '
           || case when pg_temp.c12_fila('c12-prueba-j') like 'lista: precio 8000.00, est 500.00, % 100.00 \%, ganado 8000.00, %'
                        and pg_temp.c12_nombra(160, 'j') = 'no' then 'sí' else 'no: ' || pg_temp.c12_fila('c12-prueba-j') end;
    -- 165: K, activa, residencial, sin contrato, con costo
    perform pg_temp.c12_costo('c12-prueba-k', 800);
    e := case when pg_temp.c12_nombra(165, 'k') = 'sí' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(165) end;
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-k', '{"modo": "tm", "nota": "C12 PRUEBA: se cobra por horas"}');
    perform pg_temp.c12_ser('editor');
    e := e || '; marcada «tm», ya no: ' || case when pg_temp.c12_nombra(165, 'k') = 'no' then 'sí' else 'no' end;
    -- 170: horas de alguien del equipo en A, sin pago repartido (con c10)
    if v_horas then
      insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas) overriding system value
      values (-1200036, pg_temp.c12_d(5), pg_temp.c12('equipo')::uuid, 'c12-prueba-a', 8, 'c12-pruebas');
      g := 'horas sin costo en el libro (170): '
           || case when pg_temp.c12_ctl(170) = 'rojo' and pg_temp.c12_ctl_det(170) like '%C12 PRUEBA Obra A (8 h%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(170) end;
    else
      g := '(sin el costo por obra (c10) o sin nadie del equipo en esta base: el aviso 170 no se prueba)';
    end if;
    -- 180: D con un hito de 6,000 y 30,000 de contrato
    insert into hitos (id, proyecto_id, titulo, monto, estado, es_deposito) overriding system value
    values (-1200036, 'c12-prueba-d', 'C12 PRUEBA: depósito', 6000, 'pendiente', true);
    h := case when pg_temp.c12_ctl_det(180) like '%C12 PRUEBA Obra D (hitos $6,000.00, contrato $30,000.00)%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(180) end;
    -- la fila 177 del cierre
    -- (con datos reales los avisos son muchos y largos: la fila no puede dejarse ninguno, y su nombre dice cuáles son,
    -- que es lo que mira la ronda de c9 para avisar de un rojo nuevo)
    select c.ok, c.nivel, c.detalle, c.que_hacer, c.control into f from fn_wip_cierre(v_mes) c where c.orden = 177;
    i := format('%s; y los cuadres: %s',
                case when not f.ok and f.nivel = 'aviso' and f.que_hacer like 'No detienen el cierre.%'
                          and f.control = 'wip: sus avisos (c12)' || (select format(' — %s en rojo: %s', count(*), string_agg(k.orden::text, ', ' order by k.orden))
                                                                       from fn_wip_control(v_mes) k where k.nivel = 'aviso' and not k.ok)
                          and f.control ~ '\m120\M' and f.control ~ '\m140\M' and f.control ~ '\m150\M' and f.control ~ '\m180\M'
                          and not exists (select 1 from fn_wip_control(v_mes) k
                                           where k.nivel = 'aviso' and not k.ok and position(left(k.detalle, 100) in f.detalle) = 0)
                          and length(f.detalle) <= 1500
                          and not exists (select 1 from fn_wip_control(v_mes) k where k.orden between 110 and 180 and k.nivel <> 'aviso')
                     then 'sí' else 'no: ' || coalesce(f.control, '') || ' · ' || left(coalesce(f.detalle, 'sin fila'), 300) end,
                pg_temp.c12_propios());
    v_obt := format('pérdida (120): nombra la obra, con la pérdida y lo provisionado: %s | facturado por encima del contrato (140): %s | '
                    'ingreso que no es factura (150): %s | terminada con costo en el mes y fuera del WIP (160): %s | activa sin contrato '
                    '(165): %s | %s | los hitos no suman el contrato (180): %s | la fila 177 del cierre los junta a todos y su nombre '
                    'dice cuáles, es un aviso y no detiene: %s', a, b, c, d, e, g, h, i);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'LOS AVISOS (no detienen): una obra con pérdida, facturado por encima del contrato, ingreso de una obra que no es factura (y no cuenta como facturado), una terminada con costo en el mes y fuera del WIP (revisada como terminada, entra), una activa sin contrato que no es de servicio (marcada «tm», ya no), horas sin costo en el libro y hitos que no suman el contrato; la fila 177 del cierre los junta como aviso',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. EL CUADRE 90 (las protecciones de la capa) en rojo y de vuelta: una
--     función del WIP ejecutable por la llave pública, una SECURITY DEFINER,
--     una guarda apagada, una vista sin security_invoker, una tabla legible
--     por la llave pública, una que el dueño puede borrar por la API, una sin
--     RLS. Cada cosa se pone y se quita aquí dentro.
do $$
declare
  v_obt text; f record; a text; b text; c text; d text; e text; g text; h text; i text;
  v_esp text := 'ejecutable por la llave pública: rojo, lo dice, y la fila 174 del cierre detiene: sí | una SECURITY DEFINER: sí | una '
                'guarda apagada: sí | una vista sin security_invoker: sí | una tabla legible por la llave pública: sí | una que se puede '
                'borrar por la API: sí | una sin RLS: sí | todo como estaba: verde, nada nuevo en rojo';
begin
  begin
    perform pg_temp.c12_ser('editor');
    grant execute on function public.fn_wip_postear(text, text) to anon;
    select * into f from pg_temp.c12_cie(174);
    a := case when pg_temp.c12_ctl(90) = 'rojo' and pg_temp.c12_ctl_det(90) like 'Las protecciones del WIP no están como se pegaron: %fn_wip_postear la puede ejecutar anon%'
                   and not f.ok and f.detalle like '%fn_wip_postear la puede ejecutar anon%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    revoke execute on function public.fn_wip_postear(text, text) from anon;
    alter function public.fn_wip_usd(numeric) security definer;
    b := case when pg_temp.c12_ctl_det(90) like '%fn_wip_usd es SECURITY DEFINER%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    alter function public.fn_wip_usd(numeric) security invoker;
    alter table public.wip_ajustes disable trigger trg_wip_ajustes_guarda;
    c := case when pg_temp.c12_ctl_det(90) like '%la guarda trg_wip_ajustes_guarda de wip_ajustes está apagada%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    alter table public.wip_ajustes enable trigger trg_wip_ajustes_guarda;
    alter view public.v_wip_obras set (security_invoker = false);
    d := case when pg_temp.c12_ctl_det(90) like '%v_wip_obras sin security_invoker%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    alter view public.v_wip_obras set (security_invoker = true);
    grant select on public.wip_revisiones to anon;
    e := case when pg_temp.c12_ctl_det(90) like '%anon puede SELECT en wip_revisiones%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    revoke select on public.wip_revisiones from anon;
    grant delete on public.wip_obras to authenticated;
    g := case when pg_temp.c12_ctl_det(90) like '%authenticated puede DELETE en wip_obras%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    revoke delete on public.wip_obras from authenticated;
    alter table public.wip_antes disable row level security;
    h := case when pg_temp.c12_ctl_det(90) like '%wip_antes sin RLS%' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(90) end;
    alter table public.wip_antes enable row level security;
    i := format('%s, %s', pg_temp.c12_ctl(90), pg_temp.c12_propios());
    v_obt := format('ejecutable por la llave pública: rojo, lo dice, y la fila 174 del cierre detiene: %s | una SECURITY DEFINER: %s | una '
                    'guarda apagada: %s | una vista sin security_invoker: %s | una tabla legible por la llave pública: %s | una que se '
                    'puede borrar por la API: %s | una sin RLS: %s | todo como estaba: %s', a, b, c, d, e, g, h, i);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'EL CUADRE 90 EN ROJO Y DE VUELTA (las protecciones de la capa): una función del WIP ejecutable por la llave pública, una SECURITY DEFINER, una guarda apagada, una vista sin security_invoker, una tabla legible por la llave pública, una que se puede borrar por la API o una sin RLS lo ponen en rojo diciendo cuál, y la fila 174 del cierre detiene; quitado, vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. LAS CUATRO FILAS DEL CIERRE (fn_wip_cierre): 174 los cuadres (sin el 40
--     ni el 50), 175 el cuadre 40, 176 el cuadre 50 y 177 los avisos; las
--     tres primeras detienen; cada una en rojo dice qué hacer, y todas llevan
--     a la página del WIP. En la apertura, en un año o en un período que no
--     existe: «no aplica», en verde. Al equipo, nada.
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); v_ap text; v_anio text; a text; b text; c text; d text; e text;
  v_esp text;
begin
  select p.periodo into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  select p.periodo into v_anio from periodos p where p.tipo not in ('mes', 'apertura') order by p.desde limit 1;
  v_esp := 'cuatro filas (174 a 177): tres que detienen y un aviso, todas a la página del WIP: sí | dicen lo que el control (174 los '
           'cuadres sin el 40 ni el 50; 175 el 40; 176 el 50; 177 los avisos): sí | la que está en rojo dice qué hacer y la que está en '
           'verde no: sí | '
           || case when v_ap is null then '(sin apertura en esta base)' else 'en la apertura: no aplica, en verde' end || '; '
           || case when v_anio is null then '(sin un año en esta base)' else 'en un año: no aplica, en verde' end
           || '; un período que no existe: no aplica, en verde | al equipo por la API: 0 filas; a la llave pública: 42501';
  if pg_temp.c12_omitir(38, 'las cuatro filas del cierre', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    select case when count(*) = 4 and string_agg(k.orden::text, ',' order by k.orden) = '174,175,176,177'
                     and string_agg(k.nivel, ',' order by k.orden) = 'detiene,detiene,detiene,aviso'
                     and bool_and(k.ir_a = 'wip')
                     and bool_and(case k.orden
                                    when 174 then k.control ~ '^wip: los cuadres del WIP \(c12\)( — [0-9]+ en rojo: [0-9]+(, [0-9]+)*)?$'
                                    when 175 then k.control = 'wip: cada obra con su costo estimado revisado'
                                    when 176 then k.control = 'wip: el ajuste del mes posteado y al día'
                                    else k.control ~ '^wip: sus avisos \(c12\)( — [0-9]+ en rojo: [0-9]+(, [0-9]+)*)?$' end)
                     -- (el nombre de la 174 y de la 177 dice cuántos y cuáles de sus controles están en rojo: ni uno más ni uno
                     -- menos; la ronda de c9 avisa de un rojo nuevo por el nombre de la fila)
                     and (select k2.control from fn_wip_cierre(v_mes) k2 where k2.orden = 177)
                         = 'wip: sus avisos (c12)'
                           || coalesce((select format(' — %s en rojo: %s', count(*), string_agg(q.orden::text, ', ' order by q.orden))
                                          from fn_wip_control(v_mes) q where q.nivel = 'aviso' and not q.ok having count(*) > 0), '')
                     and (select k2.control from fn_wip_cierre(v_mes) k2 where k2.orden = 174)
                         = 'wip: los cuadres del WIP (c12)'
                           || coalesce((select format(' — %s en rojo: %s', count(*), string_agg(q.orden::text, ', ' order by q.orden))
                                          from fn_wip_control(v_mes) q
                                         where q.nivel = 'cuadre' and q.orden not in (40, 50) and not q.ok having count(*) > 0), '')
                     and (select k2.control from fn_wip_cierre(v_mes) k2 where k2.orden = 177) ~ '\m120\M'
                then 'sí' else 'no' end into a
      from fn_wip_cierre(v_mes) k;
    select case when (select k.ok from fn_wip_cierre(v_mes) k where k.orden = 174)
                       = not exists (select 1 from fn_wip_control(v_mes) q where q.nivel = 'cuadre' and q.orden not in (40, 50) and not q.ok)
                     and (select (k.ok, k.detalle) from fn_wip_cierre(v_mes) k where k.orden = 175)
                       = (select (q.ok, q.detalle) from fn_wip_control(v_mes) q where q.orden = 40)
                     and (select (k.ok, k.detalle) from fn_wip_cierre(v_mes) k where k.orden = 176)
                       = (select (q.ok, q.detalle) from fn_wip_control(v_mes) q where q.orden = 50)
                     and (select k.ok from fn_wip_cierre(v_mes) k where k.orden = 177)
                       = not exists (select 1 from fn_wip_control(v_mes) q where q.nivel = 'aviso' and not q.ok)
                     and (select count(*) from fn_wip_control(v_mes)) = 17
                     and not (select k.ok from fn_wip_cierre(v_mes) k where k.orden = 176)
                then 'sí' else 'no' end into b;
    select case when bool_and((k.que_hacer is null) = k.ok) then 'sí' else 'no' end into c from fn_wip_cierre(v_mes) k;
    d := case when v_ap is null then '(sin apertura en esta base)'
              else 'en la apertura: ' || (select case when bool_and(k.ok) filter (where k.orden in (175, 176, 177))
                                                        and bool_and(k.detalle = 'No aplica: el WIP va por mes (esto es la apertura).') filter (where k.orden in (175, 176))
                                                        and count(*) = 4
                                                   then 'no aplica, en verde' else 'NO: ' || string_agg(k.detalle, ' / ') end from fn_wip_cierre(v_ap) k) end
         || '; '
         || case when v_anio is null then '(sin un año en esta base)'
                 else 'en un año: ' || (select case when bool_and(k.ok) filter (where k.orden in (175, 176, 177))
                                                      and bool_and(k.detalle = 'No aplica: el WIP va por mes (esto es un año).') filter (where k.orden in (175, 176))
                                                      and count(*) = 4
                                                 then 'no aplica, en verde' else 'NO: ' || string_agg(k.detalle, ' / ') end from fn_wip_cierre(v_anio) k) end
         || '; un período que no existe: '
         || (select case when bool_and(k.ok) filter (where k.orden in (175, 176, 177))
                           and bool_and(k.detalle = 'No aplica: ese período no existe.') filter (where k.orden in (175, 176)) and count(*) = 4
                      then 'no aplica, en verde' else 'NO: ' || string_agg(k.detalle, ' / ') end from fn_wip_cierre('2019-01') k);
    perform pg_temp.c12_ser('equipo');
    select count(*)::text || ' filas' into e from fn_wip_cierre(v_mes);
    perform pg_temp.c12_ser('editor');
    e := format('al equipo por la API: %s; a la llave pública: %s', e,
                pg_temp.c12_estado('select count(*) from public.fn_wip_cierre(' || quote_literal(v_mes) || ')', 'anon'));
    v_obt := format('cuatro filas (174 a 177): tres que detienen y un aviso, todas a la página del WIP: %s | dicen lo que el control (174 '
                    'los cuadres sin el 40 ni el 50; 175 el 40; 176 el 50; 177 los avisos): %s | la que está en rojo dice qué hacer y la '
                    'que está en verde no: %s | %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'LAS CUATRO FILAS DEL CIERRE (fn_wip_cierre, lo que c9 pide): 174 los cuadres del WIP, 175 cada obra revisada, 176 el ajuste posteado y al día (las tres detienen) y 177 los avisos; dicen lo que el control, la que está en rojo dice qué hacer y todas llevan a la página del WIP; en la apertura, en un año o en un período que no existe, «no aplica» en verde; al equipo, nada',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 39. EL CIERRE (c9) MIRA EL WIP: con el bloque de c12 en fn_cierre_revisar,
--     la revisión de un mes trae las filas 174 a 177 tal como las arma el WIP,
--     y cerrar para con MX010 mientras el ajuste exigido no esté posteado.
--     Sin ese bloque (c9 sin volver a pegar), «omitida».
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); v1 text; v2 text; n1 int; n1r int; n2 int; n2r int; v_176a boolean; v_176b boolean;
  a text; b text; c text;
  v_nom text := 'el cierre (c9) mira el WIP: sus filas 174 a 177, y MX010 al cerrar';
  v_esp text := 'la revisión del cierre trae las cuatro filas del WIP, tal como las arma el WIP: sí | sin el ajuste posteado la fila 176 '
                'detiene: sí, y cerrar para (MX010) contándola: sí | con el ajuste posteado ya no detiene: sí, y al cerrar hay una cosa '
                'menos que lo detiene: sí';
begin
  if pg_temp.c12('hay_c9') <> 'true' then
    insert into _pruebas values (39, v_nom, v_esp, 'omitida: c9 (el cierre) no está en esta base', null);
    return;
  end if;
  if pg_temp.c12('c9_wip') <> 'true' then
    insert into _pruebas values (39, v_nom, v_esp, 'omitida: el cierre de esta base todavía no trae las filas del WIP (174 a 177): vuelve a '
      'pegar docs/conta/c9-cierre.sql con el bloque de c12 y corre esto otra vez', null);
    return;
  end if;
  if pg_temp.c12_omitir(39, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    perform pg_temp.c12_ser('dueno');
    select case when count(*) = 4 and count(*) filter (where x.control = w.control and x.nivel = w.nivel and x.ok = w.ok and x.detalle = w.detalle
                                                              and x.que_hacer is not distinct from w.que_hacer
                                                              and x.ir_a is not distinct from w.ir_a) = 4
                then 'sí' else 'no' end into a
      from fn_cierre_revisar(v_mes) x join fn_wip_cierre(v_mes) w on w.orden = x.orden;
    select count(*) filter (where x.nivel = 'detiene' and x.ok is distinct from true), bool_or(x.ok) filter (where x.orden = 176)
      into n1r, v_176a from fn_cierre_revisar(v_mes) x;
    perform pg_temp.c12_ser('editor');
    v1 := pg_temp.c12_dice('select public.fn_cierre_cerrar(' || quote_literal(v_mes) || ', public.fn_cierre_confirmacion(' || quote_literal(v_mes) || '))');
    n1 := substring(v1 from ': ([0-9]+) cosa\(s\) lo detienen')::int;
    b := format('%s, y cerrar para (MX010) contándola: %s', case when v_176a is false then 'sí' else 'no' end,
                case when v1 like 'MX010 No se cierra %' and n1 = n1r then 'sí' else 'no: ' || left(v1, 300) end);
    perform pg_temp.c12_postear();
    perform pg_temp.c12_ser('dueno');
    select count(*) filter (where x.nivel = 'detiene' and x.ok is distinct from true), bool_or(x.ok) filter (where x.orden = 176)
      into n2r, v_176b from fn_cierre_revisar(v_mes) x;
    perform pg_temp.c12_ser('editor');
    v2 := pg_temp.c12_dice('select public.fn_cierre_cerrar(' || quote_literal(v_mes) || ', public.fn_cierre_confirmacion(' || quote_literal(v_mes) || '))');
    n2 := coalesce(substring(v2 from ': ([0-9]+) cosa\(s\) lo detienen')::int, 0);
    c := format('%s, y al cerrar hay una cosa menos que lo detiene: %s', case when v_176b then 'sí' else 'no' end,
                case when n2r = n1r - 1 and n2 = n2r and (v2 like 'MX010 %' or (n2r = 0 and v2 = 'ok')) then 'sí'
                     else format('no: antes %s, ahora %s (%s)', n1r, n2r, left(v2, 200)) end);
    v_obt := format('la revisión del cierre trae las cuatro filas del WIP, tal como las arma el WIP: %s | sin el ajuste posteado la fila 176 '
                    'detiene: %s | con el ajuste posteado ya no detiene: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'EL CIERRE (c9) MIRA EL WIP: con su bloque de c12, la revisión de un mes trae las filas 174 a 177 tal como las arma el WIP; mientras el ajuste exigido no está posteado, la 176 detiene y cerrar para con MX010; posteado, deja de detener',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 40. LOS TEXTOS, EN LLANO: ni el detalle de un control o de un aviso, ni lo
--     que dicen las filas del cierre, el resumen, una fila del WIP, postear o
--     deshacer, ni los errores de cada día nombran una función, una tabla o
--     una vista. (El cuadre de las protecciones, en rojo, sí dice cuál es el
--     objeto que quedó mal: es para quien lo arregla.)
do $$
declare
  v_obt text; r jsonb; d jsonb; v_mes text := pg_temp.c12('mes'); v_txt text[] := '{}'; v_mal text; v_n int;
  v_esp text := 'ninguno';
begin
  if pg_temp.c12_omitir(40, 'los textos no nombran funciones', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    perform pg_temp.c12_costo('c12-prueba-e', 3000);
    perform pg_temp.c12_rev('c12-prueba-e', '{"costo_estimado": "5000", "nota": "C12 PRUEBA: con nota"}');
    perform pg_temp.c12_costo('c12-prueba-e', 3500, 14);
    perform pg_temp.c12_factura(7, 'c12-prueba-g', 3000, -10);
    perform pg_temp.c12_costo('c12-prueba-m', 100);
    perform pg_temp.c12_rev('c12-prueba-m', '{"excluir": true, "nota": "C12 PRUEBA: este mes no se mide"}');
    perform pg_temp.c12_costo('c12-prueba-k', 800);
    -- sin postear
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_wip_control(v_mes) k;
    select v_txt || array_agg(k.orden || ': ' || k.detalle || ' ' || coalesce(k.que_hacer, '')) into v_txt from fn_wip_cierre(v_mes) k;
    select v_txt || array_agg('fila: ' || coalesce(s.falta_texto, '') || ' ' || array_to_string(s.avisos, ' ') || ' ' || coalesce(s.propuesta_nota, ''))
      into v_txt from fn_wip_schedule(v_mes) s;
    select v_txt || array_agg('obra: ' || o.motivo) into v_txt from fn_wip_obras(null) o;
    perform pg_temp.c12_ser('dueno');
    r := fn_wip_resumen(v_mes);
    v_txt := v_txt || ('resumen: ' || coalesce(r->>'nota', '') || ' ' || coalesce(r->>'por_que_no', ''));
    select v_txt || array_agg('línea: ' || (l->>'memo')) into v_txt from jsonb_array_elements(r->'lineas') l;
    v_txt := v_txt || ('config: ' || (fn_wip_config()->>'nota'));
    select v_txt || array_agg('antes: ' || t) into v_txt from jsonb_array_elements_text(fn_wip_antes_propuesta('c12-prueba-g')->'notas') t;
    perform pg_temp.c12_ser('editor');
    -- posteado, desfasado, rehecho y deshecho
    r := pg_temp.c12_postear();
    v_txt := v_txt || ('postear: ' || (r->>'nota'));
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_wip_control(v_mes) k;
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "7500", "nota": "C12 PRUEBA: subió"}');
    select v_txt || array_agg(k.orden || ': ' || k.detalle) into v_txt from fn_wip_control(v_mes) k;
    perform pg_temp.c12_ser('dueno');
    v_txt := v_txt || ('resumen: ' || coalesce(fn_wip_resumen(v_mes)->>'nota', ''));
    perform pg_temp.c12_ser('editor');
    r := pg_temp.c12_postear();
    v_txt := v_txt || ('rehacer: ' || (r->>'nota') || ' ' || (r->'rehecho'->>'motivo'));
    v_txt := v_txt || ('otra vez: ' || (pg_temp.c12_postear()->>'nota'));
    d := pg_temp.c12_deshacer('C12 PRUEBA: fuera');
    v_txt := v_txt || ('deshacer: ' || (d->>'nota'));
    -- los errores de cada día
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"costo_estimado": "17000"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-h'', ' || quote_literal(v_mes) || ', ''{"costo_estimado": "900"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"costo_estimado": "17000.123", "nota": "x"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"confirmar": true, "costo_estimado": "1"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_deshacer(' || quote_literal(v_mes) || ', ''C12 PRUEBA: no hay'')');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_antes(''c12-prueba-g'', ''{"costo": "1", "facturado": "1"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_obra(''c12-prueba-k'', ''{"modo": "contrato"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_postear(' || quote_literal(coalesce(pg_temp.c12_curso(), '2019-01')) || ')');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_postear(' || quote_literal(v_mes) || ')', 'equipo');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"excluir": true}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"precio_de_despues": true}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-e'', ' || quote_literal(v_mes) || ', ''{"costo_estimado": "5000", "nota": "x"}''::jsonb)');
    v_txt := v_txt || pg_temp.c12_dice('select public.fn_wip_revisar(''c12-prueba-h'', ' || quote_literal(v_mes) || ', ''{"excluir": true, "nota": "x"}''::jsonb)');
    select count(*), string_agg(left(t, 160), ' || ') filter (where t ~ '(fn_|wip_|v_wip|v_margen|mx_|select |\(\)|security|jsonb|null)')
      into v_n, v_mal from unnest(v_txt) t;
    v_obt := coalesce(v_mal, case when v_n >= 60 then 'ninguno' else 'solo se miraron ' || v_n || ' textos' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'LOS TEXTOS, EN LLANO: el detalle de cada control y de cada aviso (en verde y en rojo), las filas del cierre, el resumen, las filas del WIP, lo que dicen postear, rehacer y deshacer, y los errores de cada día no nombran ninguna función, tabla ni vista',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- LO QUE ENCONTRARON LOS REVISORES (45 a 47): ninguna obra con saldo sale
-- sola, el contrato que cambia después de revisar, y lo de antes sin
-- confirmar. Usan el reloj fingido de c2-pruebas (solo dentro de su
-- subtransacción: el MXT00 lo deshace).
-- ---------------------------------------------------------------------

-- 45. NINGUNA OBRA CON SALDO SALE SOLA. Con el ajuste del mes posteado (A
--     sub-facturada 3,000; B sobre-facturada 4,000; C sub-facturada 5,000 y
--     1,000 de provisión), al mes siguiente B se cancela en la app
--     («no_aprobado»), C se marca T&M y A termina con 8,000 por facturar. Las
--     tres ENTRAN en el mes siguiente (antes B y C desaparecían, su saldo se
--     deshacía el día 1 y no volvía, sin que nada se pusiera en rojo), el
--     cuadre 40 las nombra y la fila 175 detiene. B y C salen solo excluidas
--     con su nota; A se revisa como terminada y, mientras no se facture
--     entera, SIGUE ENTRANDO el mes de después (antes dejaba de entrar y su
--     1200 se perdía).
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); v_sig text := pg_temp.c12('mes_sig'); v_des text; v_hoy2 date; v_fin date;
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'posteado el mes: A sub 3000.00, B sobre 4000.00, C sub 5000.00 y provisión 1000.00 | el mes siguiente, con B cancelada, C '
                'marcada T&M y A terminada: B pendiente {revision} y dice que traía su saldo: sí; C pendiente {revision} y dice que ya no '
                'lleva WIP: sí; A pendiente {revision}, propone terminada: sí | el cuadre 40 nombra a las tres y la fila 175 detiene: sí | '
                'excluir sin nota: 22023; con su nota: B excluida, C excluida, y el cuadre 40 ya no las nombra: sí | A terminada: lista, '
                'ganado 10000.00, sub 8000.00 | el ajuste del mes siguiente: 1200 8000.00 a | ingreso -8000.00 a; dice las dos excluidas: '
                'sí; la fila 176 las nombra con su nota: sí; saldo de A en 1200 al cierre: 8000.00 | el mes de después: A sigue entrando '
                '(terminada, sin facturar entera): sí; B: no sale; C: no sale';
begin
  if pg_temp.c12_omitir(45, 'ninguna obra con saldo sale sola', v_esp) then return; end if;
  select q.periodo, q.desde + 1 into v_des, v_hoy2 from periodos q
   where q.tipo = 'mes' and q.estado = 'abierto' and q.desde = (select x.hasta + 1 from periodos x where x.periodo = v_sig);
  select x.hasta into v_fin from periodos x where x.periodo = v_sig;
  if v_des is null then
    insert into _pruebas values (45, 'ninguna obra con saldo sale sola', v_esp,
      'omitida: el mes de después del siguiente al de las pruebas no está abierto en el libro: no hay dónde ver que la obra sigue entrando', null);
    return;
  end if;
  begin
    perform pg_temp.c12_escena();
    r := pg_temp.c12_postear();
    a := format('A sub %s, B sobre %s, C sub %s y provisión %s', pg_temp.c12_saldo('1200', 'c12-prueba-a', pg_temp.c12_h()),
                -pg_temp.c12_saldo('2400', 'c12-prueba-b', pg_temp.c12_h()), pg_temp.c12_saldo('1200', 'c12-prueba-c', pg_temp.c12_h()),
                -pg_temp.c12_saldo('2410', 'c12-prueba-c', pg_temp.c12_h()));
    -- el mes siguiente: B se cancela, C pasa a T&M y A termina; el reloj, al día 2 del mes de después (el siguiente ya terminó)
    update proyectos set estado = 'no_aprobado' where id = 'c12-prueba-b';
    update proyectos set estado = 'completado' where id = 'c12-prueba-a';
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-c', '{"modo": "tm", "nota": "C12 PRUEBA: pasa a cobrarse por horas"}');
    perform pg_temp.c12_ser('editor');
    perform pg_temp.c12_fingir_hoy(v_hoy2);
    b := format('B %s; C %s; A %s',
           coalesce((select format('%s {%s} y dice que traía su saldo: %s', s.estado, array_to_string(s.falta, ','),
                                   case when s.falta_texto like 'Traía $4,000.00 sobre-facturados en el ajuste de ' || fn_wip_mes(v_mes)
                                                                || ' y la app la tiene ahora como «no_aprobado».%exclúyela con su nota%'
                                        then 'sí' else 'no: ' || coalesce(s.falta_texto, '-') end)
                       from fn_wip_calcular(v_sig, 'c12-prueba-b', true) s), 'NO SALE'),
           coalesce((select format('%s {%s} y dice que ya no lleva WIP: %s', s.estado, array_to_string(s.falta, ','),
                                   case when s.falta_texto like 'Traía $5,000.00 sub-facturados y $1,000.00 de pérdida provisionada en el ajuste de '
                                                                || fn_wip_mes(v_mes) || ' y hoy ya no lleva WIP%exclúyela este mes con su nota%'
                                        then 'sí' else 'no: ' || coalesce(s.falta_texto, '-') end)
                       from fn_wip_calcular(v_sig, 'c12-prueba-c', true) s), 'NO SALE'),
           coalesce((select format('%s {%s}, propone terminada: %s', s.estado, array_to_string(s.falta, ','),
                                   case when s.propuesta_terminada then 'sí' else 'no' end)
                       from fn_wip_calcular(v_sig, 'c12-prueba-a', true) s), 'NO SALE'));
    c := case when pg_temp.c12_nombra(40, 'a', v_sig) = 'sí' and pg_temp.c12_nombra(40, 'b', v_sig) = 'sí' and pg_temp.c12_nombra(40, 'c', v_sig) = 'sí'
                   and (select not x.ok and x.nivel = 'detiene' from pg_temp.c12_cie(175, v_sig) x) then 'sí'
              else 'no: ' || coalesce(pg_temp.c12_ctl_det(40, v_sig), 'sin fila') end;
    d := 'excluir sin nota: ' || pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_sig) || ', ''{"excluir": true}''::jsonb)');
    perform pg_temp.c12_rev('c12-prueba-b', '{"excluir": true, "nota": "C12 PRUEBA: el cliente canceló el contrato"}', v_sig);
    perform pg_temp.c12_rev('c12-prueba-c', '{"excluir": true, "nota": "C12 PRUEBA: desde ahora se cobra por horas"}', v_sig);
    d := d || format('; con su nota: B %s, C %s, y el cuadre 40 ya no las nombra: %s',
                     (select s.estado from fn_wip_calcular(v_sig, 'c12-prueba-b', false) s),
                     (select s.estado from fn_wip_calcular(v_sig, 'c12-prueba-c', false) s),
                     case when pg_temp.c12_nombra(40, 'b', v_sig) = 'no' and pg_temp.c12_nombra(40, 'c', v_sig) = 'no' then 'sí' else 'no' end);
    perform pg_temp.c12_rev('c12-prueba-a', '{"terminada": true}', v_sig);
    select format('%s, ganado %s, sub %s', s.estado, s.ingreso_ganado, s.sub_facturado) into e
      from fn_wip_calcular(v_sig, 'c12-prueba-a', false) s;
    r := pg_temp.c12_postear(v_sig);
    f := format('%s; dice las dos excluidas: %s; la fila 176 las nombra con su nota: %s; saldo de A en 1200 al cierre: %s',
                pg_temp.c12_lin((r->'asiento'->>'id')::uuid),
                case when (select count(*) from jsonb_array_elements(r->'excluidas') x
                            where x->>'proyecto_id' in ('c12-prueba-b', 'c12-prueba-c') and coalesce(x->>'nota', '') like 'C12 PRUEBA:%') = 2
                          and r->>'nota' like '%quedaron fuera a propósito, con su nota.' then 'sí' else 'no: ' || coalesce(r->>'nota', '-') end,
                case when (select x.detalle from pg_temp.c12_cie(176, v_sig) x)
                          like '%Fuera del ajuste a propósito, % obra(s): %C12 PRUEBA Obra B («C12 PRUEBA: el cliente canceló el contrato»)%'
                                || 'C12 PRUEBA Obra C («C12 PRUEBA: desde ahora se cobra por horas»)%'
                     then 'sí' else 'no: ' || coalesce((select x.detalle from pg_temp.c12_cie(176, v_sig) x), 'sin fila') end,
                pg_temp.c12_saldo('1200', 'c12-prueba-a', v_fin));
    g := format('A sigue entrando (terminada, sin facturar entera): %s; B: %s; C: %s',
                coalesce((select case when s.estado = 'pendiente' and s.propuesta_terminada
                                           and s.falta_texto like 'Ya estaba terminada (se revisó así en ' || fn_wip_mes(v_sig)
                                                                  || ') y sigue sin facturarse entera: lleva facturado $2,000.00 de $10,000.00.%'
                                      then 'sí' else 'no: ' || s.estado || ' · ' || coalesce(s.falta_texto, '-') end
                            from fn_wip_calcular(v_des, 'c12-prueba-a', true) s), 'NO SALE'),
                coalesce((select 'SALE: ' || s.estado from fn_wip_calcular(v_des, 'c12-prueba-b', false) s), 'no sale'),
                coalesce((select 'SALE: ' || s.estado from fn_wip_calcular(v_des, 'c12-prueba-c', false) s), 'no sale'));
    v_obt := format('posteado el mes: %s | el mes siguiente, con B cancelada, C marcada T&M y A terminada: %s | el cuadre 40 nombra a las '
                    'tres y la fila 175 detiene: %s | %s | A terminada: %s | el ajuste del mes siguiente: %s | el mes de después: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'NINGUNA OBRA CON SALDO SALE SOLA: la que traía sub, sobre o provisión en el último ajuste entra en el mes siguiente aunque la app la tenga cancelada, marcada T&M o terminada; el cuadre 40 la nombra y detiene; sale solo excluida con su nota (y la fila 176 lo dice); y la terminada que no se ha facturado entera sigue entrando cada mes',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 46. EL CONTRATO DE LA FICHA CAMBIA DESPUÉS DE REVISAR Y POSTEAR (10,000 →
--     12,000). Antes solo avisaba (130) y el mes cerraba con 5,000 ganados
--     donde a mano son 6,000. Ahora la obra vuelve a «pendiente» (le falta:
--     precio), el cuadre 40 la nombra y el ajuste deja de estar al día. Se
--     decide: «el cambio es de después» (un toque: se queda como estaba, queda
--     escrito, y el ajuste vuelve a estar al día sin repostear), o se revisa
--     otra vez con el precio nuevo (ganado 6,000; el ajuste se rehace).
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); a text; b text; c text; d text; e text; f text;
  v_esp text := 'revisada y posteada con 10000: lista, ganado 5000.00, sub 3000.00 | la ficha pasa a 12000: pendiente {precio}, con las '
                'cifras de su revisión (ganado 5000.00), y dice qué hacer: sí; el cuadre 40 la nombra con su porqué: sí; el ajuste ya no '
                'está al día: sí | «el cambio es de después» en una obra sin revisión: MX008 | dicho en un toque: lista, precio 10000.00, '
                'sub 3000.00; queda escrito: sí; el cuadre 40 ya no la nombra y el 130 sí: sí; el ajuste vuelve a estar al día sin '
                'repostear: sí; otra vez, sin cambio nuevo: MX008 | revisada otra vez con el precio nuevo: lista, precio 12000.00, ganado '
                '6000.00, sub 4000.00; y el ajuste pide rehacerse: sí';
begin
  if pg_temp.c12_omitir(46, 'el contrato de la ficha cambia después de revisar', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_factura(1, 'c12-prueba-a', 2000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    r := pg_temp.c12_postear();
    select format('%s, ganado %s, sub %s', s.estado, s.ingreso_ganado, s.sub_facturado) into a
      from fn_wip_calcular(v_mes, 'c12-prueba-a', false) s;
    update finanzas_proyecto set contrato = 12000 where proyecto_id = 'c12-prueba-a';
    select format('%s {%s}, con las cifras de su revisión (ganado %s), y dice qué hacer: %s; el cuadre 40 la nombra con su porqué: %s; el '
                  'ajuste ya no está al día: %s', s.estado, array_to_string(s.falta, ','), s.ingreso_ganado,
                  case when s.falta_texto like 'El contrato de su ficha cambió después de revisarla (se revisó con $10,000.00 y la ficha dice ahora '
                                               '$12,000.00)%si es de después, dilo (un toque)%' then 'sí' else 'no: ' || coalesce(s.falta_texto, '-') end,
                  case when pg_temp.c12_ctl(40) = 'rojo'
                            and pg_temp.c12_ctl_det(40) like '%C12 PRUEBA Obra A (el contrato de su ficha cambió después de revisarla)%' then 'sí'
                       else 'no: ' || pg_temp.c12_ctl_det(40) end,
                  case when not (fn_wip_ajuste_estado(v_mes)->>'al_dia')::boolean
                            and fn_wip_ajuste_estado(v_mes)->>'cambios' like '%sale C12 PRUEBA Obra A (estaba sub-facturado $3,000.00)%' then 'sí'
                       else 'no: ' || coalesce(fn_wip_ajuste_estado(v_mes)->>'cambios', 'sigue al día') end)
      into b from fn_wip_calcular(v_mes, 'c12-prueba-a', false) s;
    c := pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-b'', ' || quote_literal(v_mes) || ', ''{"precio_de_despues": true}''::jsonb)');
    r := pg_temp.c12_rev('c12-prueba-a', '{"precio_de_despues": true}');
    select format('%s, precio %s, sub %s; queda escrito: %s; el cuadre 40 ya no la nombra y el 130 sí: %s; el ajuste vuelve a estar al día '
                  'sin repostear: %s', s.estado, s.precio_contrato, s.sub_facturado,
                  case when s.revision_nota like 'El contrato de la ficha pasó de $10,000.00 a $12,000.00 después de ' || fn_wip_mes(v_mes)
                                                 || ': este mes se queda con $10,000.00.' then 'sí' else 'no: ' || coalesce(s.revision_nota, '-') end,
                  case when pg_temp.c12_nombra(40, 'a') = 'no' and pg_temp.c12_nombra(130, 'a') = 'sí' then 'sí' else 'no' end,
                  case when (fn_wip_ajuste_estado(v_mes)->>'al_dia')::boolean then 'sí' else 'no' end)
      into d from fn_wip_calcular(v_mes, 'c12-prueba-a', false) s;
    d := d || '; otra vez, sin cambio nuevo: '
           || pg_temp.c12_estado('select public.fn_wip_revisar(''c12-prueba-a'', ' || quote_literal(v_mes) || ', ''{"precio_de_despues": true}''::jsonb)');
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    select format('%s, precio %s, ganado %s, sub %s; y el ajuste pide rehacerse: %s', s.estado, s.precio_contrato, s.ingreso_ganado,
                  s.sub_facturado,
                  case when fn_wip_ajuste_estado(v_mes)->>'cambios' like '%C12 PRUEBA Obra A pasa de sub-facturado $3,000.00 a sub-facturado $4,000.00%'
                       then 'sí' else 'no: ' || coalesce(fn_wip_ajuste_estado(v_mes)->>'cambios', 'sigue al día') end)
      into e from fn_wip_calcular(v_mes, 'c12-prueba-a', false) s;
    v_obt := format('revisada y posteada con 10000: %s | la ficha pasa a 12000: %s | «el cambio es de después» en una obra sin revisión: %s '
                    '| dicho en un toque: %s | revisada otra vez con el precio nuevo: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (46, 'EL CONTRATO DE LA FICHA CAMBIA DESPUÉS DE REVISAR: la obra vuelve a pendiente (le falta: precio), el cuadre 40 la nombra y el ajuste posteado deja de estar al día; se decide con un toque («el cambio es de después»: se queda como estaba y queda escrito) o revisándola otra vez con el precio nuevo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 47. LO DE ANTES SIN CONFIRMAR DETIENE (en producción, la mayoría de las
--     obras activas empezaron antes del libro). Una obra que ya andaba,
--     revisada y sin lo de antes confirmado: antes el cuadre 40 no la contaba
--     y el mes cerraba en verde con ella fuera. Ahora el cuadre 40 la nombra
--     con su porqué (la fila 175 detiene); se arregla confirmando lo de
--     antes, o dejándola fuera ESE mes con su nota: entonces el control del
--     ajuste y la fila 176 dicen que quedó fuera y por qué, el aviso 110 la
--     sigue nombrando, y el mes siguiente se vuelve a preguntar.
do $$
declare
  v_obt text; r jsonb; v_mes text := pg_temp.c12('mes'); v_sig text := pg_temp.c12('mes_sig'); a text; b text; c text; d text;
  v_esp text := 'revisada y sin lo de antes confirmado: el cuadre 40 la nombra con su porqué: sí; la fila 175 detiene: sí | excluida este '
                'mes con su nota: excluida {}: precio 15000.00, sin cifras; el cuadre 40 ya no la nombra: sí; el aviso 110 la sigue '
                'nombrando: sí | al postear: dice que quedó fuera a propósito: sí; el control del ajuste y la fila 176 la nombran con su '
                'nota: sí; sin líneas suyas: - | el mes siguiente se vuelve a preguntar: pendiente {revision,antes}';
begin
  if pg_temp.c12_omitir(47, 'lo de antes sin confirmar detiene', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    perform pg_temp.c12_factura(7, 'c12-prueba-g', 3000, -10);
    perform pg_temp.c12_costo('c12-prueba-g', 2000);
    perform pg_temp.c12_rev('c12-prueba-g', '{"costo_estimado": "9000"}');
    perform pg_temp.c12_costo('c12-prueba-a', 3000);
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "6000"}');
    a := format('el cuadre 40 la nombra con su porqué: %s; la fila 175 detiene: %s',
                case when pg_temp.c12_ctl(40) = 'rojo' and pg_temp.c12_ctl_det(40) like '%C12 PRUEBA Obra G (falta confirmar lo de antes del libro)%'
                     then 'sí' else 'no: ' || pg_temp.c12_ctl_det(40) end,
                case when (select not x.ok and x.nivel = 'detiene' and x.detalle like '%C12 PRUEBA Obra G%' from pg_temp.c12_cie(175) x) then 'sí' else 'no' end);
    perform pg_temp.c12_rev('c12-prueba-g', '{"excluir": true, "nota": "C12 PRUEBA: el costo de antes lo pasa el contador el mes que viene"}');
    b := format('%s; el cuadre 40 ya no la nombra: %s; el aviso 110 la sigue nombrando: %s', pg_temp.c12_fila('c12-prueba-g'),
                case pg_temp.c12_nombra(40, 'g') when 'no' then 'sí' else 'no' end,
                case when pg_temp.c12_ctl_det(110) like '%C12 PRUEBA Obra G (fuera este mes, con su nota)%' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(110) end);
    r := pg_temp.c12_postear();
    c := format('dice que quedó fuera a propósito: %s; el control del ajuste y la fila 176 la nombran con su nota: %s; sin líneas suyas: %s',
                case when exists (select 1 from jsonb_array_elements(r->'excluidas') x where x->>'proyecto_id' = 'c12-prueba-g'
                                     and x->>'nota' = 'C12 PRUEBA: el costo de antes lo pasa el contador el mes que viene')
                          and r->>'nota' like '%quedaron fuera a propósito, con su nota.' then 'sí' else 'no: ' || coalesce(r->>'nota', '-') end,
                case when pg_temp.c12_ctl_det(50) like '%Fuera del ajuste a propósito, % obra(s): %C12 PRUEBA Obra G («C12 PRUEBA: el costo de antes '
                                                       'lo pasa el contador el mes que viene»)%'
                          and (select x.detalle from pg_temp.c12_cie(176) x) = pg_temp.c12_ctl_det(50) then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(50) end,
                (select coalesce(string_agg(l.cuenta, ','), '-') from asiento_lineas l
                  where l.asiento_id = (r->'asiento'->>'id')::uuid and l.proyecto_id = 'c12-prueba-g'));
    d := coalesce((select format('%s {%s}', s.estado, array_to_string(s.falta, ',')) from fn_wip_calcular(v_sig, 'c12-prueba-g', false) s), 'NO SALE');
    v_obt := format('revisada y sin lo de antes confirmado: %s | excluida este mes con su nota: %s | al postear: %s | el mes siguiente se '
                    'vuelve a preguntar: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, 'LO DE ANTES SIN CONFIRMAR DETIENE: una obra que ya andaba, revisada y sin lo de antes confirmado, pone en rojo el cuadre 40 (fila 175); se confirma, o se deja fuera ese mes con su nota: entonces el control del ajuste y la fila 176 dicen que quedó fuera y por qué, el aviso 110 la sigue nombrando y al mes siguiente se vuelve a preguntar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 48. UNA OBRA CON FACTURAS QUE LA APP TODAVÍA NO TIENE EN OBRA (la revisión
--     final del 12-nov). Una obra de precio fijo cuyo depósito se facturó al
--     firmar, ANTES de pasarla a «aprobado» en la app (sigue como
--     «enviado»): no entra en el WIP —no está activa—, así que su depósito
--     cuenta entero como ingreso y nada lo difiere. Antes ningún control lo
--     decía (el 160 solo miraba las terminadas; el 165, las activas sin
--     contrato). Ahora el aviso 160 la nombra, con lo facturado y con qué
--     hacer; pasada a aprobada entra en el WIP (pendiente de revisar, con su
--     depósito sobre-facturado al revisarla) y el aviso ya no la nombra.
--     Otra, todavía «en estimación» y con una factura: la nombra; marcada
--     como que no lleva WIP («tm», con su nota), ya no. Y una que solo tiene
--     costo (sin facturas) no se nombra: no hay ingreso de más.
do $$
declare
  v_obt text; v_mes text := pg_temp.c12('mes'); a text; b text; c text; d text; e text;
  v_esp text := 'con su depósito facturado y la app en «enviado»: no sale en el WIP y el aviso 160 la nombra (con la propuesta enviada; '
                'facturado $6,000.00) y dice qué hacer: sí | es un aviso, no detiene: la fila 177 lo lleva en su nombre: sí; la 175 y los '
                'cuadres, como estaban: sí | la que solo tiene costo y no está aprobada: no la nombra: sí | pasada a aprobada: entra '
                '(pendiente {revision}: sin cifras) y el aviso ya no la nombra: sí; revisada: lista: precio 30000.00, est 20000.00, util '
                'est 10000.00, costo 0.00, 0.00 %, ganado 0.00, fact 6000.00, sub 0.00, sobre 6000.00, para terminar 20000.00, util 0.00, '
                'perdida 0.00, prov 0.00 | otra, en estimación y con una factura: la nombra (en estimación; facturado $1,000.00): sí; '
                'marcada «tm» con su nota, ya no: sí';
  v_175 text; v_prop text;
begin
  if pg_temp.c12_omitir(48, 'una obra con facturas que la app todavía no tiene en obra', v_esp) then return; end if;
  begin
    perform pg_temp.c12_sembrar();
    perform fn_wip_config(jsonb_build_object('exigir_desde', v_mes));
    select format('%s|%s', x.ok, x.detalle) into v_175 from pg_temp.c12_cie(175) x;
    v_prop := pg_temp.c12_propios();
    -- D: su depósito facturado (6,000 de 30,000) y la app todavía la tiene como «enviado»; M: en estimación, con una factura
    -- de 1,000; L: no aprobada, solo con costo
    update proyectos set estado = 'enviado' where id = 'c12-prueba-d';
    update proyectos set estado = 'estimando' where id = 'c12-prueba-m';
    update proyectos set estado = 'no_aprobado' where id = 'c12-prueba-l';
    perform pg_temp.c12_factura(48, 'c12-prueba-d', 6000);
    perform pg_temp.c12_factura(49, 'c12-prueba-m', 1000);
    perform pg_temp.c12_costo('c12-prueba-l', 400);
    a := case when pg_temp.c12_fila('c12-prueba-d') = 'no sale' and pg_temp.c12_ctl(160) = 'rojo'
                   and pg_temp.c12_ctl_det(160) like '%obra(s) de precio fijo ya tienen facturas en el libro y la app todavía no las tiene en obra: '
                                                     '%C12 PRUEBA Obra D (la app la tiene con la propuesta enviada; facturado $6,000.00)%'
                   and pg_temp.c12_ctl_det(160) like '%pásala a aprobada o en ejecución en su ficha%márcala como que no lleva WIP, con su nota%'
              then 'sí' else 'no: ' || pg_temp.c12_fila('c12-prueba-d') || ' · ' || pg_temp.c12_ctl_det(160) end;
    b := format('la fila 177 lo lleva en su nombre: %s; la 175 y los cuadres, como estaban: %s',
                case when (select not x.ok and x.nivel = 'aviso' from pg_temp.c12_cie(177) x)
                          and (select c.control ~ '\m160\M' from fn_wip_cierre(v_mes) c where c.orden = 177) then 'sí' else 'no' end,
                case when (select format('%s|%s', x.ok, x.detalle) from pg_temp.c12_cie(175) x) = v_175 and pg_temp.c12_propios() = v_prop then 'sí'
                     else 'no: ' || pg_temp.c12_propios() end);
    c := case pg_temp.c12_nombra(160, 'l') when 'no' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(160) end;
    -- pasada a aprobada, entra en el WIP; revisada, su depósito sale sobre-facturado
    update proyectos set estado = 'aprobado' where id = 'c12-prueba-d';
    d := format('entra (%s) y el aviso ya no la nombra: %s', pg_temp.c12_fila('c12-prueba-d'),
                case pg_temp.c12_nombra(160, 'd') when 'no' then 'sí' else 'no' end);
    perform pg_temp.c12_rev('c12-prueba-d', '{"costo_estimado": "20000"}');
    d := d || '; revisada: ' || pg_temp.c12_fila('c12-prueba-d');
    -- M, en estimación y con una factura: la nombra; marcada como que no lleva WIP (con su nota), ya no
    e := format('la nombra (en estimación; facturado $1,000.00): %s; marcada «tm» con su nota, ya no: ',
                case when pg_temp.c12_ctl_det(160) like '%C12 PRUEBA Obra M (la app la tiene en estimación; facturado $1,000.00)%' then 'sí'
                     else 'no: ' || pg_temp.c12_ctl_det(160) end);
    perform pg_temp.c12_ser('dueno');
    perform fn_wip_obra('c12-prueba-m', '{"modo": "tm", "nota": "C12 PRUEBA: no va a ser obra; lo facturado se devuelve"}');
    perform pg_temp.c12_ser('editor');
    e := e || case pg_temp.c12_nombra(160, 'm') when 'no' then 'sí' else 'no: ' || pg_temp.c12_ctl_det(160) end;
    v_obt := format('con su depósito facturado y la app en «enviado»: no sale en el WIP y el aviso 160 la nombra (con la propuesta enviada; '
                    'facturado $6,000.00) y dice qué hacer: %s | es un aviso, no detiene: %s | la que solo tiene costo y no está aprobada: '
                    'no la nombra: %s | pasada a aprobada: %s | otra, en estimación y con una factura: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, 'UNA OBRA CON FACTURAS QUE LA APP TODAVÍA NO TIENE EN OBRA (su depósito facturado y la app en «enviado»): no entra en el WIP —su ingreso es lo facturado— y el aviso 160 la nombra con lo facturado y qué hacer, sin detener; la que solo tiene costo no se nombra; pasada a aprobada entra en el WIP (su depósito, sobre-facturado) y el aviso ya no la nombra; otra en estimación con una factura se nombra y, marcada como que no lleva WIP con su nota, ya no',
    v_esp, v_obt, v_obt = v_esp);
end $$;


-- ---------------------------------------------------------------------
-- EL CIERRE DE LA SUITE
-- ---------------------------------------------------------------------

-- 41. Con el ajuste posteado, desfasado, rehecho, deshecho y vuelto a
--     postear, NINGÚN control de las otras capas pasa a rojo: la cadena y
--     «permisos» de c2, los puentes (c3), el banco (c6), los estados (c4:
--     hoy y al último día del mes de las pruebas, que es donde vive el
--     ajuste), los cuadres de la IA (c8, si está), los del jornal y del
--     margen (c10, si está) y lo que detiene el cierre del mes (c9, si está;
--     sin las filas del propio WIP). Se compara con cómo estaban con las
--     obras de prueba ya sembradas (lo que ya estaba en rojo se dice, y no
--     cuenta).
do $$
declare
  v_obt text; s0 text[]; s1 text[]; s2 text[]; s3 text[]; s4 text[]; s5 text[]; v_antes text := '';
  v_esp text := 'al postear: ninguno | con la revisión cambiada: ninguno | al rehacer: ninguno | al deshacer: ninguno | al volver a postear: '
                'ninguno';
begin
  if pg_temp.c12_omitir(41, 'ningún control de las otras capas pasa a rojo', v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    s0 := pg_temp.c12_rojos();
    perform pg_temp.c12_postear();
    s1 := pg_temp.c12_rojos();
    perform pg_temp.c12_rev('c12-prueba-a', '{"costo_estimado": "7500", "nota": "C12 PRUEBA: subió el cobre"}');
    s2 := pg_temp.c12_rojos();
    perform pg_temp.c12_postear(null, 'C12 PRUEBA: subió el estimado de A');
    s3 := pg_temp.c12_rojos();
    perform pg_temp.c12_deshacer('C12 PRUEBA: fuera');
    s4 := pg_temp.c12_rojos();
    perform pg_temp.c12_postear();
    s5 := pg_temp.c12_rojos();
    v_obt := format('al postear: %s | con la revisión cambiada: %s | al rehacer: %s | al deshacer: %s | al volver a postear: %s',
                    pg_temp.c12_nuevos(s0, s1), pg_temp.c12_nuevos(s0, s2), pg_temp.c12_nuevos(s0, s3), pg_temp.c12_nuevos(s0, s4),
                    pg_temp.c12_nuevos(s0, s5));
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, 'con el ajuste de WIP posteado, desfasado, rehecho, deshecho y vuelto a postear, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3), el banco (c6), los estados (c4, hoy y al cierre del mes), los cuadres de la IA (c8), los del jornal y el margen (c10) y lo que detiene el cierre del mes (c9)',
    v_esp, v_obt || case when v_antes <> '' then ' (ya en rojo antes, con las obras de prueba sembradas: ' || left(v_antes, 600) || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 42. «COSTO POR OBRA» (c10) CON UN AJUSTE VIVO. v_margen_obra no mira
--     fechas: el ajuste (el último día del mes) y su reverso (el día 1) se
--     anulan entre sí, así que ingreso_libro sigue siendo lo FACTURADO y
--     costo_real no cuenta el gasto de la provisión; y sus cuadres (el costo
--     y el ingreso por obra = el mayor; el costo = el de «Estados») siguen
--     como estaban.
do $$
declare
  v_obt text; m0 text; m1 text; m2 text; q0 text; q1 text;
  v_m text := 'select string_agg(format(''%s %s/%s'', right(o.proyecto_id, 1), o.ingreso_libro, o.costo_real), '', '' order by o.proyecto_id) '
              'from public.v_margen_obra o where o.proyecto_id in (''c12-prueba-a'', ''c12-prueba-b'', ''c12-prueba-c'')';
  v_q text := 'select string_agg(format(''%s %s'', k.orden, case when k.ok then ''verde'' else ''rojo'' end), '', '' order by k.orden) '
              'from public.v_margen_control k where k.nivel = ''cuadre''';
  v_nom text := '«Costo por obra» (c10) con un ajuste de WIP vivo';
  v_esp text := 'antes del ajuste (ingreso del libro / costo real): a 2000.00/3000.00, b 9000.00/4000.00, c 0.00/6000.00 | con el ajuste '
                'vivo y su reverso del día 1: igual | los cuadres del margen: como estaban | deshecho el ajuste: igual';
begin
  if pg_temp.c12('hay_c10') <> 'true' then
    insert into _pruebas values (42, v_nom, v_esp, 'omitida: el costo por obra (c10) no está en esta base', null);
    return;
  end if;
  if pg_temp.c12_omitir(42, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c12_escena();
    execute v_m into m0;
    execute v_q into q0;
    perform pg_temp.c12_postear();
    execute v_m into m1;
    execute v_q into q1;
    perform pg_temp.c12_deshacer('C12 PRUEBA: fuera');
    execute v_m into m2;
    v_obt := format('antes del ajuste (ingreso del libro / costo real): %s | con el ajuste vivo y su reverso del día 1: %s | los cuadres del '
                    'margen: %s | deshecho el ajuste: %s', m0, case when m1 = m0 then 'igual' else 'CAMBIA: ' || m1 end,
                    case when q1 = q0 then 'como estaban' else format('CAMBIAN: de %s a %s', q0, q1) end,
                    case when m2 = m0 then 'igual' else 'CAMBIA: ' || m2 end);
    v_nom := q1;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, '«COSTO POR OBRA» (c10) CON UN AJUSTE DE WIP VIVO: v_margen_obra no mira fechas, así que el ajuste y su reverso del día 1 se anulan: ingreso_libro sigue siendo lo facturado, costo_real no cuenta el gasto de la provisión por pérdida, y los cuadres del margen (el costo y el ingreso por obra = el mayor, el costo = el de «Estados») siguen como estaban',
    v_esp, v_obt || case when v_nom ~ '^[0-9]' then ' (los cuadres del margen con el ajuste vivo: ' || v_nom || ')' else '' end, v_obt = v_esp);
end $$;

-- 43. Nada queda: lo que c12 toca (y lo que sus pruebas sembraron) está como
--     antes de la primera prueba.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c12_ser('editor');
    v_obt := case when pg_temp.c12_conteos() <> pg_temp.c12('conteos') then 'antes: ' || pg_temp.c12('conteos') || ' · ahora: ' || pg_temp.c12_conteos()
                  when exists (select 1 from proyectos p where p.id like 'c12-prueba-%') then 'queda una obra de prueba'
                  when exists (select 1 from facturas f where f.id between -1200999 and -1200000) then 'queda una factura de prueba'
                  when exists (select 1 from asientos a where a.descripcion like 'C12 PRUEBA%') then 'queda un asiento de prueba'
                  else 'igual que antes' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'nada queda de las pruebas: la configuración, las marcas, lo de antes, las revisiones, los ajustes y sus fotos, los asientos y sus líneas, los contadores, las facturas, las notas de crédito, los trabajos externos, los hitos, las obras y sus fichas, la regla del tipo de obra, los períodos cerrados, los escenarios y las funciones, como antes',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 44. El cierre de la suite: c2 (la cadena y «permisos»), c3, c6 y c4 como
--     estaban con c12 pegado (lo que ya estaba en rojo antes se dice y no
--     cuenta), c8 y c10 sin cuadres rojos nuevos, los cuadres del propio WIP
--     como estaban, nada de c12 para anon o service_role ni SECURITY DEFINER;
--     y fn_wip_pegado responde con sus ocho filas y la configuración sigue
--     siendo UNA (pegar dos veces no la pisa: lo corre el banco, con dos
--     pegados seguidos antes de esta suite).
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_c8 text := 'ninguno'; v_c10 text := 'ninguno'; v_api text; v_n int; v_cfg int;
  v_esp text := 'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres rojos nuevos: ninguno | c10 cuadres rojos nuevos: ninguno | los '
                'cuadres del WIP: nada nuevo en rojo | c12 para anon o service_role, o definer: ninguna | el pegado: 8 filas, y la '
                'configuración 1 fila (id 1)';
begin
  begin
    perform pg_temp.c12_ser('editor');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena()
     where not ok and not (control = 'permisos' and pg_temp.c12_permisos() = 'verde');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar()
     where not ok and not (control = any (string_to_array(pg_temp.c12('rojos_c3'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c12('rojos_c6'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c12('rojos_c4'), ', ')));
    if pg_temp.c12('hay_c8') = 'true' then
      execute $q$ select coalesce(string_agg(k.orden::text, ' ' order by k.orden), 'ninguno') from public.v_contador_control k
                   where k.nivel = 'cuadre' and not k.ok and not (k.orden::text = any (string_to_array($1, ', '))) $q$
         into v_c8 using pg_temp.c12('rojos_c8');
    end if;
    if pg_temp.c12('hay_c10') = 'true' then
      execute $q$ select coalesce(string_agg(k.c, ', ' order by k.c), 'ninguno')
                    from (select 'jornal ' || j.orden as c from public.v_jornal_control j where j.nivel = 'cuadre' and not j.ok
                          union all
                          select 'margen ' || m.orden from public.v_margen_control m where m.nivel = 'cuadre' and not m.ok) k
                   where not (k.c = any (string_to_array($1, ', '))) $q$
         into v_c10 using pg_temp.c12('rojos_c10');
    end if;
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c12_es_suya(p.proname)
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_wip_pegado();
    select count(*) into v_cfg from wip_config;
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | c8 cuadres rojos nuevos: %s | c10 cuadres rojos nuevos: %s | los cuadres del WIP: %s | '
                    'c12 para anon o service_role, o definer: %s | el pegado: %s filas, y la configuración %s fila (id %s)',
                    v_c2, v_c3, v_c6, v_c4, v_c8, v_c10, pg_temp.c12_propios(), v_api, v_n, v_cfg, (select id from wip_config limit 1));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'el cierre de la suite: c2, c3, c6 y c4 en verde con c12 puesto (salvo lo que ya estaba en rojo antes), c8 y c10 sin cuadres rojos nuevos, los cuadres del propio WIP como estaban, nada de c12 para anon o service_role ni SECURITY DEFINER; fn_wip_pegado responde y la configuración es una fila (pegar dos veces no la pisa: lo corre el banco)',
    v_esp,
    v_obt || case when pg_temp.c12('rojos_c3') <> '' then ' (ya en rojo antes, en c3: ' || pg_temp.c12('rojos_c3') || ')' else '' end
          || case when pg_temp.c12('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.c12('rojos_c4') || ')' else '' end
          || case when pg_temp.c12('rojos_c6') <> '' then ' (ya en rojo antes, en c6: ' || pg_temp.c12('rojos_c6') || ')' else '' end
          || case when pg_temp.c12('rojos_c8') <> '' then ' (ya en rojo antes, en c8: ' || pg_temp.c12('rojos_c8') || ')' else '' end
          || case when pg_temp.c12('rojos_c10') <> '' then ' (ya en rojo antes, en c10: ' || pg_temp.c12('rojos_c10') || ')' else '' end
          || case when pg_temp.c12('rojos_wip') <> '' then ' (cuadres del WIP ya en rojo antes, con los datos de esta base: ' || pg_temp.c12('rojos_wip') || ')' else '' end
          || case when pg_temp.c12('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c12: ' || pg_temp.c12('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8, c9 y c10): si el SQL Editor deja de esperar, la corrida sigue en
-- el servidor hasta el final y se lee después con
--   select * from pruebas.c12_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c12_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c12_resultado from public, anon, authenticated, service_role;
truncate pruebas.c12_resultado;
insert into pruebas.c12_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
