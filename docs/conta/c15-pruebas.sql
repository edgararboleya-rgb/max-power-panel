-- =====================================================================
-- c15-pruebas.sql — LA NÓMINA se prueba a sí misma (c15-nomina.sql).
-- 13-nov-2026.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c15-nomina.sql (y,
-- si el c9-cierre.sql que tienes nombra las filas 180 a 183 en su cabecera,
-- después de volver a pegarlo), pegar este archivo entero → Run. Sale la
-- tabla _pruebas: 40 filas, todas con ok = true (las que salen «omitida»
-- dicen por qué y no son un fallo; una fila 99 solo sale si algo de este
-- archivo falló). Si el editor se cansa antes del final, la corrida sigue en
-- el servidor y se lee después en pruebas.c15_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c14 y c15-nomina.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c15-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni una corrida, ni una persona, ni un archivo, ni sus
-- asientos, ni las obras, las personas y las horas de prueba, ni un
-- movimiento del banco, ni la revisión del cierre que c9 guarda, ni el
-- reloj); la 39 lo comprueba, y la 40 otra vez al final de todo.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · TRES PERSONAS DE PRUEBA («ZZ Ayudante Uno», «ZZ Ayudante Dos» y «ZZ
--     Oficial Tres»: nombres que nadie lleva), cada una con su usuario en
--     auth.users (correo @c15-pruebas.invalid) y su perfil de campo; las dos
--     primeras con su tarifa estándar (25 y 30 la hora). Si la base no deja
--     crear el usuario de prueba, las pruebas que siembran salen «omitida»
--     con lo que dijo la base.
--   · DOS OBRAS («C15 PRUEBA Obra A» y «B», ids c15-prueba-a y b).
--   · SUS HORAS, con ids negativos (−1510000001…: no gastan la secuencia),
--     en el período del día 1 al 14 del MES DE LAS PRUEBAS: el mes de hoy
--     (si no está abierto, las pruebas que postean salen «omitida»).
--   · SU «PAYROLL JOURNAL»: un CSV sintético (el de
--     pruebas/conta/nomina/zz-payroll-journal.csv, con las fechas del mes de
--     las pruebas): tres personas, montos inventados que cuadran al centavo,
--     ningún dato de nadie. Día de pago, el 20; sus cargos de Gusto, el 16.
--   · SUS CARGOS DE GUSTO: movimientos del banco «como los trae Plaid», con
--     «C15 PRUEBA» en su descripción, por el camino de c6 (se importan, c6
--     los deja en la Bandeja esperando su journal y la nómina los casa).
--   · EL RELOJ: cada prueba pone «hoy» en el último día del mes de las
--     pruebas DENTRO de su subtransacción (el reloj fingido de c2-pruebas),
--     para que el día de pago, los cargos y las horas ya hayan pasado sea el
--     día del mes que sea. Al final el archivo comprueba que el reloj quedó
--     como estaba (y si no, lo restaura y sale un fallo, la fila 99).
--   · LA CONFIGURACIÓN Y EL MAPEO de la base real pueden ser otros (otra
--     cuenta de lo sin obra, otro día en que empieza la semana, una columna
--     de fábrica cambiada): cada prueba los pone como de fábrica DENTRO de
--     su subtransacción (al sembrar) y los deja como estaban al deshacerse.
-- Los controles ajenos (c2, c3, c4, c6, c8, c9, c10, c11, c12, c13, c14) se
-- comparan con cómo estaban justo antes: lo que ya estaba en rojo se dice y
-- no se cuenta. Y un control de la nómina que los datos reales ya tuvieran
-- en rojo no rompe una prueba: se mira que nombre (o deje de nombrar) lo de
-- la prueba.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 15 tablas, 7 vistas, las 60 funciones por su
--    nombre exacto, la configuración, el mapeo de fábrica, cada objeto con
--    su comentario «c15: …»);
--  2 las precondiciones en rojo;
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas; el
--    dueño sin su código lee lo general y no escribe; con su código, entra;
--  4 el catálogo: SECURITY DEFINER solo el trigger del puente (sin EXECUTE
--    para nadie), RLS y policies justas, lo de cada persona con el código,
--    vistas security_invoker, y «permisos» (c2) en verde con c15 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API; lo
--    que es rastro, ni con la marca; y una corrida puesta «posteada» a mano
--    no entra al libro: el puente la para);
--  6 la configuración, con sus frenos, y la cuenta de lo sin obra;
--  7 el mapeo de columnas, con sus frenos;
-- EL ARCHIVO:
--  8 importar el journal: el ensayo (sin guardar nada) y la importación, al
--    centavo; del archivo solo queda su nombre, su sha256 y su tamaño;
--  9 no entra dos veces: el mismo archivo, la misma nómina por otro archivo
--    o bajada de otra forma; con otras cifras, o reemplaza a la que estaba
--    sin postear o es otra nómina del mismo día; una posteada no se
--    reemplaza;
-- 10 lo delicado (Seguro Social, cuenta y ruta del banco, dirección, correo)
--    no se guarda nunca, ni sale en un mensaje;
-- 11 una columna con cifras que el mapeo no conoce frena la corrida;
-- 12 cuadra al centavo o no se postea; y el archivo que no se puede leer;
-- 13 las personas: cada una nace sin enlazar y frena hasta que se enlaza y
--    se confirma, una vez;
-- 14 el reparto al centavo por las horas aprobadas (obra y CO, lo sin obra,
--    las horas de Gusto distintas de las aprobadas, el oficial en obra);
-- 15 alguien con sueldo y ninguna hora aprobada frena hasta que se decide;
-- EL ASIENTO:
-- 16 postear: una corrida = su journal (de puente, origen nomina_corridas,
--    en su día de pago, cada cuenta al centavo) y el reparto de su burden
--    real (origen nomina_burden); lo visto es lo que entra (MX011);
-- 17 con la nómina en el libro las otras capas siguen como estaban: c3
--    «mano de obra» en verde;
-- 18 el costo por obra (c10) y el WIP (c12) leen el burden real por obra;
-- 19 el devengo estándar de c3 del mes, con y sin la corrida: nada dos
--    veces; y la cola se dice;
-- 20 anular y volver a subir;
-- 21 la nómina tardía (el mes de su día de pago ya cerrado);
-- EL BANCO, EL AMARRE Y LAS HORAS PARA GUSTO:
-- 22 el neto y los impuestos, cada cargo de Gusto casado con lo que la
--    nómina dejó por pagar, por la puerta del banco;
-- 23 un cargo para dos corridas (la regular y un bono del mismo día);
-- 24 un cargo que no casa al centavo no se casa solo; deshacer;
-- 25 la cuota mensual de Gusto no es nómina: a su gasto;
-- 26 el auxiliar de las cuentas por pagar de la nómina a una fecha (c13);
-- 27 el amarre con el 941, el 940 y el RT-6;
-- 28 las horas para Gusto: la tabla por persona y semana laboral, el CSV, el
--    lote guardado y su aviso si algo cambia después; y el período que
--    corta una semana;
-- LAS FORMAS DEL ARCHIVO Y LO QUE AVISA LA PROPUESTA:
-- 29 el archivo, como venga (con preámbulo, por secciones, el resumen y el
--    detalle juntos, dos nóminas el mismo día, el neto con su reembolso, las
--    fechas con el nombre del mes, sin día de pago, con marca de orden de
--    bytes);
-- 30 lo que la propuesta dice y no frena (una obra terminada o sin aprobar,
--    las horas sin aprobar del oficial, impuestos sin su renglón, una nómina
--    fuera de ciclo) y los reembolsos, a nombre de cada empleado;
-- LOS CONTROLES:
-- 31 los cuadres (10, 15, 20, 25 y 90), en rojo y de vuelta;
-- 32 los avisos del dinero (30, 35, 40, 60, 62, 75 y 85), en rojo y de
--    vuelta por su camino de verdad;
-- 33 las horas, nada dos veces y nada fuera (lo que pagó una nómina, la
--    cola, el «pagado hasta»), y sus avisos (45, 50, 55 y 80);
-- 34 las cuatro filas del cierre (180 a 183);
-- 35 el cierre (c9) mira la nómina, y un cargo de Gusto del mes sin casar no
--    deja cerrar («omitida» mientras c9-cierre.sql no traiga el bloque de
--    c15);
-- 36 los textos, en llano: ninguno nombra una función ni una tabla, y las
--    fechas van como 20-nov-2026;
-- 37 con la nómina dentro, nadie más ve nada: el equipo, la llave pública,
--    la de servicio, y el dueño sin el código del teléfono (lo de cada
--    persona);
-- Y el cierre de la suite:
-- 38 con una nómina posteada, sus cargos casados, la cuota, un bono anulado,
--    una declaración y un lote, NINGÚN control de c2, c3, c4, c6, c8, c9,
--    c10, c11, c12, c13 ni c14 pasa a rojo;
-- 39 nada queda al deshacer;
-- 40 el cierre de la suite: las demás capas como estaban, nada de c15 para
--    anon o service_role, con permisos de dueño solo el trigger del puente;
--    fn_nomina_pegado responde; y nada queda.
-- Última sentencia: select * from _pruebas order by n;
--
-- NO FRENA A LA APP (como c11-pruebas.sql y c14-pruebas.sql): lo primero que
-- hace es poner lock_timeout a MEDIO SEGUNDO para toda la corrida, como el
-- pegado de la capa. Las pruebas 31 y 34 apagan una guarda o dan un permiso
-- de más DENTRO de un bloque que se deshace (para ver que el control lo ve):
-- eso pide un candado sobre una tabla de la nómina; si alguien está en la
-- pantalla de Nómina en ese momento y no lo suelta en medio segundo, la
-- prueba no espera más: sale «omitida» y lo dice (no es un fallo: se vuelve
-- a pegar en un momento más tranquilo), y nada queda a medias.
-- =====================================================================
-- (Dura lo que dura la corrida, una transacción.)
set local lock_timeout = '500ms';

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el mes de las pruebas, hoy.
create temp table if not exists _c15 (k text primary key, v text);
truncate _c15;
insert into _c15
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c15
select 'equipo', id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
-- las tres personas de prueba (su usuario y su perfil se siembran y se deshacen)
insert into _c15 values ('p1', gen_random_uuid()::text), ('p2', gen_random_uuid()::text), ('p3', gen_random_uuid()::text);
insert into _c15 values ('hoy', fn_fecha_miami(now())::text);
-- el mes de las pruebas: el mes de hoy, si está abierto
insert into _c15
select 'mes', p.periodo from periodos p
 where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta;
insert into _c15 select 'mes_desde', p.desde::text from periodos p where p.periodo = (select v from _c15 where k = 'mes');
insert into _c15 select 'mes_hasta', p.hasta::text from periodos p where p.periodo = (select v from _c15 where k = 'mes');
-- el mes siguiente, si existe y está abierto (la nómina tardía)
insert into _c15
select 'mes2', q.periodo from periodos p join periodos q on q.tipo = 'mes' and q.estado = 'abierto' and q.desde = p.hasta + 1
 where p.periodo = (select v from _c15 where k = 'mes');
insert into _c15 values ('banco', '1010');
insert into _c15 values ('hay_c6', (to_regclass('public.movimientos_banco') is not null
                                    and to_regproc('public.fn_banco_importar_filas') is not null and to_regproc('public.fn_banco_casar') is not null
                                    and exists (select 1 from cuentas c where c.codigo = '1010'))::text);
insert into _c15 values ('hay_c8', (to_regclass('public.v_contador_control') is not null)::text);
insert into _c15 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
insert into _c15 values ('hay_c11', (to_regclass('public.v_emision_control') is not null)::text);
insert into _c15 values ('hay_c12', (to_regprocedure('public.fn_wip_control(text)') is not null and to_regprocedure('public.fn_wip_libro(date,text)') is not null)::text);
insert into _c15 values ('hay_c13', (to_regclass('public.v_cedula_control') is not null)::text);
insert into _c15 values ('hay_c14', (to_regclass('public.v_subs_control') is not null)::text);
insert into _c15
select 'c9_nomina', coalesce((select p.prosrc like '%fn_nomina_cierre%' from pg_proc p
                               where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')), false)::text;
grant select on _c15 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8, c9, c10, c12
-- y c14), y ningún aviso al teléfono desde la ronda de c9 si algo la
-- despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c15(k text) returns text language sql as $$ select v from _c15 where k = $1 $$;
-- un día del mes de las pruebas: su día 1 + n
create or replace function pg_temp.c15_d(p_n int default 0) returns date language sql as $$ select pg_temp.c15('mes_desde')::date + p_n $$;
-- (las fechas de la nómina de prueba: su período, del día 1 al 14; su día de pago, el 20; sus cargos de Gusto, el 16)
create or replace function pg_temp.c15_pago() returns date language sql as $$ select pg_temp.c15_d(19) $$;
create or replace function pg_temp.c15_us(p date) returns text language sql immutable as $$ select to_char(p, 'MM/DD/YYYY') $$;

-- Los objetos que crea c15-nomina.sql, por su nombre exacto. No se buscan
-- por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c15_fn() returns text[] language sql immutable as $$
  select array['fn_nomina_precondiciones', 'fn_nomina_por_api', 'fn_nomina_exigir_dueno', 'fn_nomina_ve', 'fn_nomina_aal2',
               'fn_nomina_exigir_codigo', 'fn_nomina_ve_personas', 'fn_nomina_guarda', 'fn_nomina_al_libro', 'fn_nomina_usd', 'fn_nomina_h',
               'fn_nomina_dia', 'fn_nomina_hoy', 'fn_nomina_lista', 'fn_nomina_norm', 'fn_nomina_clave', 'fn_nomina_monto', 'fn_nomina_fecha',
               'fn_nomina_delicado', 'fn_nomina_etiqueta', 'fn_nomina_cuenta_mal', 'fn_nomina_cuenta_sin_obra', 'fn_nomina_cuentas',
               'fn_nomina_fecha_asiento', 'fn_nomina_apunta', 'fn_nomina_config', 'fn_nomina_columna', 'fn_nomina_journal', 'fn_nomina_leer',
               'fn_nomina_propone', 'fn_nomina_ya', 'fn_nomina_ensayo',
               'fn_nomina_importar', 'fn_nomina_corrida', 'fn_nomina_descartar', 'fn_nomina_persona', 'fn_nomina_decidir', 'fn_nomina_plan',
               'fn_nomina_propuesta', 'fn_nomina_postear', 'fn_nomina_anular', 'fn_nomina_pendiente', 'fn_nomina_cargos',
               'fn_nomina_cargo_propuesta', 'fn_nomina_cargo_casar', 'fn_nomina_cargo_cuota', 'fn_nomina_cargo_deshacer',
               'fn_nomina_declaracion', 'fn_nomina_amarre', 'fn_nomina_por_horas', 'fn_nomina_horas_gusto', 'fn_nomina_lote',
               'fn_nomina_lote_csv', 'fn_nomina_horas_pagadas', 'fn_nomina_cola', 'fn_nomina_pagado_hasta', 'fn_nomina_auxiliar',
               'fn_nomina_control',
               'fn_nomina_cierre', 'fn_nomina_pegado']
$$;
create or replace function pg_temp.c15_tablas() returns text[] language sql immutable as $$
  select array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_archivos', 'nomina_corridas', 'nomina_corrida_personas',
               'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas', 'nomina_pagos', 'nomina_pago_partes', 'nomina_declaraciones',
               'nomina_lotes', 'nomina_lote_horas', 'nomina_historial']
$$;
create or replace function pg_temp.c15_vistas() returns text[] language sql immutable as $$
  select array['v_nomina_corridas', 'v_nomina_personas', 'v_nomina_cargos', 'v_nomina_amarre', 'v_nomina_lotes', 'v_nomina_control',
               'v_nomina_papel']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o alguien del
-- equipo por la API (authenticated, con su código: aal2), el dueño sin su
-- código (dueno_aal1), anon o service_role.
create or replace function pg_temp.c15_ser(quien text) returns void language plpgsql as $$
declare
  v_id text := pg_temp.c15(case when quien = 'dueno_aal1' then 'dueno' else quien end);
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

-- Lo que contesta una orden: 'ok' o su código de error (c15_estado; p_marca:
-- con la marca de la guarda puesta a mano); con su mensaje (c15_dice); o lo
-- que devuelve como texto (c15_da: su primera columna, o el código si
-- falla). Como quien se diga; al volver, el SQL Editor.
create or replace function pg_temp.c15_estado(p_sql text, p_quien text default 'dueno', p_marca text default null) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c15_ser(p_quien);
  begin
    if p_marca is not null then   -- (la marca de la guarda, puesta a mano antes de la orden)
      perform set_config('mx_nomina.escribe', p_marca, true);
    end if;
    execute p_sql;
    v := 'ok';
  exception when others then
    v := case when sqlstate = 'PGRST' then 'PGRST ' || coalesce(sqlerrm::json->>'code', '?') else sqlstate end;
  end;
  perform set_config('mx_nomina.escribe', '', true);
  perform pg_temp.c15_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c15_dice(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c15_ser(p_quien);
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  perform set_config('mx_nomina.escribe', '', true);
  perform pg_temp.c15_ser('editor');
  return v;
end $$;
create or replace function pg_temp.c15_da(p_sql text, p_quien text default 'dueno') returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.c15_ser(p_quien);
  begin
    execute p_sql into v;
  exception when others then
    v := case when sqlstate = 'PGRST' then 'PGRST ' || coalesce(sqlerrm::json->>'code', '?') else sqlstate end;
  end;
  perform pg_temp.c15_ser('editor');
  return v;
end $$;

-- EL RELOJ FINGIDO (el de c2-pruebas, c11, c12 y c14): «hoy» pasa a ser esa
-- fecha (o el hoy de verdad, si es posterior). Solo DENTRO de la
-- subtransacción de una prueba: su MXT00 lo deshace. Las pruebas ponen «hoy»
-- en el último día del mes de las pruebas: así el día de pago (el 20), los
-- cargos de Gusto (el 16) y las horas (del 1 al 14) ya pasaron, sea el día
-- del mes que sea de verdad.
create or replace function pg_temp.c15_fingir_hoy(p_hoy date) returns void language plpgsql as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;

-- UN CSV → SUS CELDAS, como las manda la pantalla (todas como texto; con
-- comillas, comas dentro de comillas y saltos de línea), y el archivo
-- entero: {nombre, sha256, bytes, filas}.
create or replace function pg_temp.c15_celdas(p text) returns jsonb language plpgsql as $$
declare
  v_filas jsonb := '[]'::jsonb; v_fila jsonb := '[]'::jsonb; v_c text := ''; i int := 1; n int; ch text; q boolean := false;
begin
  p := replace(replace(p, E'\r\n', E'\n'), E'\r', E'\n');
  n := length(p);
  while i <= n loop
    ch := substr(p, i, 1);
    if q then
      if ch = '"' then
        if substr(p, i + 1, 1) = '"' then v_c := v_c || '"'; i := i + 1; else q := false; end if;
      else v_c := v_c || ch; end if;
    elsif ch = '"' then q := true;
    elsif ch = ',' then v_fila := v_fila || to_jsonb(v_c); v_c := '';
    elsif ch = E'\n' then v_fila := v_fila || to_jsonb(v_c); v_filas := v_filas || jsonb_build_array(v_fila); v_fila := '[]'::jsonb; v_c := '';
    else v_c := v_c || ch; end if;
    i := i + 1;
  end loop;
  if v_c <> '' or jsonb_array_length(v_fila) > 0 then
    v_fila := v_fila || to_jsonb(v_c); v_filas := v_filas || jsonb_build_array(v_fila);
  end if;
  return v_filas;
end $$;
create or replace function pg_temp.c15_arch(p_csv text, p_nombre text default 'zz-c15-prueba.csv') returns jsonb language sql as $$
  select jsonb_build_object('nombre', p_nombre, 'sha256', encode(sha256(convert_to(p_csv, 'UTF8')), 'hex'), 'bytes', octet_length(p_csv),
                            'filas', pg_temp.c15_celdas(p_csv))
$$;

-- EL JOURNAL DE PRUEBA (sintético: nombres «ZZ…», montos inventados que
-- cuadran al centavo). Tres personas, una nómina regular del período del día
-- 1 al 14 del mes de las pruebas, con día de pago el 20:
--   ZZ Ayudante Uno   bruto 1,958.00 (regular 1,760.00 + extra 198.00), retenido 291.79, neto 1,666.21; patrón 214.41
--   ZZ Ayudante Dos   bruto 1,450.00, retenido 206.93, deducción 50.00, neto 1,193.07; patrón 158.78
--   ZZ Oficial Tres   bruto 2,400.00, retenido 448.60, neto 1,951.40, reembolso 64.25 (cheque 2,015.65); patrón 262.80
--   Totales           bruto 5,808.00 · retenido 947.32 · deducciones 50.00 · neto 4,810.68 · reembolsos 64.25 · patrón 635.99
--                     (941: 503.00 + 2 × 360.10 + 2 × 84.22 = 1,391.64 · FUTA 34.85 · reempleo 156.82)
-- p_suf: un sufijo para cada una de sus cinco líneas (cabecera, tres personas y totales): así se le añaden columnas.
create or replace function pg_temp.c15_journal(p_suf text[] default null) returns text language sql as $$
  select string_agg(x.l || coalesce(p_suf[x.n], ''), E'\n' order by x.n) || E'\n'
    from (values
      (1, 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Regular hours,'
          'Regular earnings,Overtime hours,Overtime earnings,Gross earnings,Employee federal income tax,Employee social security tax,'
          'Employee medicare tax,Employee medicare additional tax,Employee taxes,Employee deductions,Net pay,Reimbursements,Check amount,'
          'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes,Employer cost'),
      (2, format('ZZ Ayudante,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1760.00,6.00,198.00,1958.00,142.00,121.40,28.39,0.00,291.79,'
                 '0.00,1666.21,0.00,1666.21,121.40,28.39,11.75,52.87,214.41,2172.41',
                 pg_temp.c15_us(pg_temp.c15_d(0)), pg_temp.c15_us(pg_temp.c15_d(13)), pg_temp.c15_us(pg_temp.c15_pago()))),
      (3, format('ZZ Ayudante,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,72.50,1450.00,0.00,0.00,1450.00,96.00,89.90,21.03,0.00,206.93,'
                 '50.00,1193.07,0.00,1193.07,89.90,21.03,8.70,39.15,158.78,1608.78',
                 pg_temp.c15_us(pg_temp.c15_d(0)), pg_temp.c15_us(pg_temp.c15_d(13)), pg_temp.c15_us(pg_temp.c15_pago()))),
      (4, format('ZZ Oficial,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2400.00,0.00,0.00,2400.00,265.00,148.80,34.80,0.00,448.60,'
                 '0.00,1951.40,64.25,2015.65,148.80,34.80,14.40,64.80,262.80,2662.80',
                 pg_temp.c15_us(pg_temp.c15_d(0)), pg_temp.c15_us(pg_temp.c15_d(13)), pg_temp.c15_us(pg_temp.c15_pago()))),
      (5, 'Totals,,,,,,,232.50,5610.00,6.00,198.00,5808.00,503.00,360.10,84.22,0.00,947.32,50.00,4810.68,64.25,4874.93,360.10,84.22,'
          '34.85,156.82,635.99,6443.99')) as x(n, l)
$$;
-- UN BONO fuera de ciclo, el mismo día de pago, de una sola persona (ZZ Ayudante Uno): bruto 500.00, retenido 88.25, neto
-- 411.75; patrón 54.75 (941: 50.00 + 2 × 31.00 + 2 × 7.25 = 126.50 · FUTA 3.00 · reempleo 13.50).
create or replace function pg_temp.c15_bono() returns text language sql as $$
  select 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Bonus,Gross earnings,'
         || 'Employee federal income tax,Employee social security tax,Employee medicare tax,Employee taxes,Net pay,Check amount,'
         || 'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes' || E'\n'
         || format('ZZ Ayudante,Uno,%1$s,%2$s,%3$s,Bonus,Direct Deposit,500.00,500.00,50.00,31.00,7.25,88.25,411.75,411.75,31.00,7.25,3.00,13.50,54.75',
                   pg_temp.c15_us(pg_temp.c15_d(0)), pg_temp.c15_us(pg_temp.c15_d(13)), pg_temp.c15_us(pg_temp.c15_pago())) || E'\n'
$$;

-- LA CONFIGURACIÓN Y EL MAPEO, COMO DE FÁBRICA MIENTRAS DURA LA PRUEBA (se
-- deshace con ella). En la base real Edgar puede haber cambiado la
-- configuración o lo que dice el mapeo de una columna de fábrica, y lo que
-- cada prueba espera está escrito con los valores de fábrica (y con la
-- cuenta de lo sin obra en 6000). Como el SQL Editor, con la marca de la
-- guarda.
create or replace function pg_temp.c15_fabrica() returns void language plpgsql as $$
begin
  perform pg_temp.c15_ser('editor');
  perform set_config('mx_nomina.escribe', 'nomina_config', true);
  update nomina_config
     set cuenta_sin_obra = '6000', cuenta_oficina = '6000', cuenta_oficial = '6005', cuenta_bolsa = '5015', cuenta_burden_obra = '5010',
         cuenta_burden_admin = '6010', cuenta_cuota = '6500', semana_empieza = 1, horas_extra_desde = 40, horas_periodo_oficial = 80,
         cargo_dias_antes = 10, cargo_dias_despues = 5, saldo_dias = 10, amarre_tolerancia = 1.00,
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
      ('overtime earnings', 'overtime_earnings', 'bruto', null, null), ('bonus', 'bonus', 'bruto', null, null),
      ('gross earnings', 'gross_earnings', 'bruto_total', null, null),
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
      ('employer taxes', 'employer_taxes', 'imp_patron_total', null, null), ('employer cost', 'employer_cost', 'costo_total', null, null),
      ('ssn', 'ssn', 'delicado', null, null), ('bank account account number', 'bank_account_account_number', 'delicado', null, null),
      ('bank account routing number', 'bank_account_routing_number', 'delicado', null, null), ('home address', 'home_address', 'delicado', null, null),
      ('employee email', 'employee_email', 'delicado', null, null)) as v(alias, concepto, clase, cuenta, declara)
   where k.alias = v.alias
     and (k.concepto, k.clase, k.cuenta, k.declara) is distinct from (v.concepto, v.clase, v.cuenta, v.declara);
  -- (una columna que las pruebas dan por desconocida no puede estar ya en el mapeo de esta base)
  delete from nomina_columnas where alias in ('zz employer 401k match', 'zz dato raro', 'zz otra') and not de_fabrica;
  perform set_config('mx_nomina.escribe', '', true);
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): el reloj en el
-- último día del mes de las pruebas, la configuración y el mapeo como de
-- fábrica, dos obras, tres personas de prueba (su usuario, su perfil de
-- campo; las dos primeras con su tarifa) y, si se piden, sus horas del
-- período (con ids negativos: no gastan la secuencia):
--   ZZ Ayudante Uno   día 2: 8 h obra A · día 3: 8 h obra A · día 4: 10 h obra B, CO #1 · día 5: 4 h SIN OBRA (aprobadas)
--                     día 9: 7 h obra B, SIN APROBAR
--   ZZ Ayudante Dos   día 2: 8 h obra B (aprobadas)
--   ZZ Oficial Tres   día 6: 10 h obra A · día 7: 10 h obra A (aprobadas)
create or replace function pg_temp.c15_sembrar(p_horas boolean default true) returns void language plpgsql as $$
declare
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
  r record;
  v_d uuid := pg_temp.c15('dueno')::uuid;
begin
  perform pg_temp.c15_ser('editor');
  perform pg_temp.c15_fingir_hoy(pg_temp.c15('mes_hasta')::date);
  perform pg_temp.c15_fabrica();
  insert into proyectos (id, tipo, nombre, estado) values
    ('c15-prueba-a', 'comercial', 'C15 PRUEBA Obra A', 'ejecucion'),
    ('c15-prueba-b', 'servicio',  'C15 PRUEBA Obra B', 'ejecucion');
  for r in select * from (values ('p1', 'ZZ Ayudante Uno'), ('p2', 'ZZ Ayudante Dos'), ('p3', 'ZZ Oficial Tres')) as x(k, nombre) loop
    if v_meta then
      execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                     pg_temp.c15(r.k), 'c15-' || r.k || '@c15-pruebas.invalid',
                     json_build_object('nombre', r.nombre, 'name', r.nombre, 'full_name', r.nombre)::text);
    else
      execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                     pg_temp.c15(r.k), 'c15-' || r.k || '@c15-pruebas.invalid');
    end if;
    insert into perfiles (id, nombre, rol, activo) values (pg_temp.c15(r.k)::uuid, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c15('p1')::uuid, 25), (pg_temp.c15('p2')::uuid, 30)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  if p_horas then
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) overriding system value values
      (-1510000001, pg_temp.c15_d(1), pg_temp.c15('p1')::uuid, 'c15-prueba-a', 8,  null,    'c15-pruebas', v_d, now()),
      (-1510000002, pg_temp.c15_d(2), pg_temp.c15('p1')::uuid, 'c15-prueba-a', 8,  null,    'c15-pruebas', v_d, now()),
      (-1510000003, pg_temp.c15_d(3), pg_temp.c15('p1')::uuid, 'c15-prueba-b', 10, 'CO #1', 'c15-pruebas', v_d, now()),
      (-1510000004, pg_temp.c15_d(4), pg_temp.c15('p1')::uuid, null,           4,  null,    'c15-pruebas', v_d, now()),
      (-1510000005, pg_temp.c15_d(8), pg_temp.c15('p1')::uuid, 'c15-prueba-b', 7,  null,    'c15-pruebas', null, null),
      (-1510000006, pg_temp.c15_d(1), pg_temp.c15('p2')::uuid, 'c15-prueba-b', 8,  null,    'c15-pruebas', v_d, now()),
      (-1510000007, pg_temp.c15_d(5), pg_temp.c15('p3')::uuid, 'c15-prueba-a', 10, null,    'c15-pruebas', v_d, now()),
      (-1510000008, pg_temp.c15_d(6), pg_temp.c15('p3')::uuid, 'c15-prueba-a', 10, null,    'c15-pruebas', v_d, now());
  end if;
end $$;
-- (un reporte de horas más de una persona de prueba, como el SQL Editor; p_ap: aprobado o no)
create or replace function pg_temp.c15_hora(p_n int, p_quien text, p_fecha date, p_obra text, p_horas numeric, p_ap boolean default true,
                                            p_co text default null) returns bigint language sql as $$
  insert into horas (id, fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) overriding system value
  values (-(1510000000 + p_n), p_fecha, pg_temp.c15(p_quien)::uuid, p_obra, p_horas, p_co, 'c15-pruebas',
          case when p_ap then pg_temp.c15('dueno')::uuid end, case when p_ap then now() end)
  returning id
$$;

-- ¿Se puede sembrar en esta base? Se prueba UNA vez, antes de todo, y se
-- deshace. Si no (un trigger de auth.users que pida más datos), las pruebas
-- que siembran salen «omitida» con lo que dijo la base.
do $$
declare
  v text := 'ok';
begin
  if pg_temp.c15('mes') is not null and pg_temp.c15('dueno') is not null then
    begin
      perform pg_temp.c15_sembrar();
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v := sqlstate || ': ' || sqlerrm;
    end;
  end if;
  insert into _c15 values ('siembra', v);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar; true si la puso)
create or replace function pg_temp.c15_omitir(p_n int, p_prueba text, p_esperado text, p_banco boolean default false)
returns boolean language plpgsql as $$
declare
  v text := case when pg_temp.c15('dueno') is null then 'no hay un dueño activo en perfiles'
                 when pg_temp.c15('mes') is null then 'el mes de hoy no está abierto (o no existe): no hay dónde postear una nómina de prueba'
                 when pg_temp.c15('siembra') <> 'ok'
                   then 'esta base no deja sembrar las obras, las personas y las horas de prueba (' || left(pg_temp.c15('siembra'), 300) || ')'
                 when p_banco and pg_temp.c15('hay_c6') <> 'true'
                   then 'el banco (c6) o su cuenta 1010 no están en esta base: no hay cómo traer un cargo de Gusto' end;
begin
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado, 'omitida: ' || v, null);
  return true;
end $$;

-- COMO EL DUEÑO POR LA API (con su código): importar un archivo (devuelve la
-- primera corrida nueva), enlazar y confirmar a las tres personas de prueba
-- (dos de campo y un oficial), pedir la propuesta y postear lo visto.
create or replace function pg_temp.c15_importar(p_csv text, p_nombre text default 'zz-c15-prueba.csv', p_op jsonb default '{}'::jsonb)
returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c15_ser('dueno');
  r := fn_nomina_importar(pg_temp.c15_arch(p_csv, p_nombre), p_op);
  perform pg_temp.c15_ser('editor');
  return (select (q->>'corrida')::uuid from jsonb_array_elements(r->'corridas') q where q->>'resultado' = 'nueva' order by (q->>'n')::int limit 1);
end $$;
create or replace function pg_temp.c15_persona(p_nombre text) returns uuid language sql as $$
  select id from nomina_personas where clave = fn_nomina_clave(p_nombre)
$$;
create or replace function pg_temp.c15_enlazar() returns void language plpgsql as $$
begin
  perform pg_temp.c15_ser('dueno');
  perform fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'usuario_id', pg_temp.c15('p1'), 'clase', 'campo', 'confirmar', true));
  perform fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Dos'), 'usuario_id', pg_temp.c15('p2'), 'clase', 'campo', 'confirmar', true));
  if pg_temp.c15_persona('ZZ Oficial Tres') is not null then
    perform fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Oficial Tres'), 'usuario_id', pg_temp.c15('p3'), 'clase', 'oficial', 'confirmar', true));
  end if;
  perform pg_temp.c15_ser('editor');
end $$;
create or replace function pg_temp.c15_postear(p_corrida uuid) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c15_ser('dueno');
  r := fn_nomina_postear(p_corrida, fn_nomina_propuesta(p_corrida)->>'visto');
  perform pg_temp.c15_ser('editor');
  return r;
end $$;
-- (todo junto: sembrar, importar el journal de prueba y enlazar a su gente; devuelve la corrida, lista para postear)
create or replace function pg_temp.c15_lista(p_horas boolean default true) returns uuid language plpgsql as $$
declare
  v uuid;
begin
  perform pg_temp.c15_sembrar(p_horas);
  v := pg_temp.c15_importar(pg_temp.c15_journal());
  perform pg_temp.c15_enlazar();
  return v;
end $$;
-- La propuesta de una corrida, como el dueño.
create or replace function pg_temp.c15_propuesta(p_corrida uuid) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c15_ser('dueno');
  r := fn_nomina_propuesta(p_corrida);
  perform pg_temp.c15_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c15_codigos(p jsonb) returns text language sql as $$
  select coalesce(string_agg(distinct q->>'codigo', ',' order by q->>'codigo'), 'ninguno') from jsonb_array_elements(p) q
$$;

-- UN ASIENTO EN UNA LÍNEA: cada línea «cuenta[ obra[ CO]] monto», en su orden.
create or replace function pg_temp.c15_asiento(p_id uuid) returns text language sql as $$
  select coalesce(string_agg(concat_ws(' ', l.cuenta, replace(l.proyecto_id, 'c15-prueba-', ''), l.co, l.monto::text), ' · ' order by l.orden), '-')
    from asiento_lineas l where l.asiento_id = p_id
$$;

-- UN CARGO DE GUSTO EN EL BANCO, como lo trae Plaid (en nombre del dueño) y
-- «Casar» solo para él: c6 lo deja en la Bandeja esperando su journal.
-- p_monto en positivo = lo que salió. La descripción lleva «C15 PRUEBA».
create or replace function pg_temp.c15_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text) returns uuid language plpgsql as $$
declare
  v_mov uuid;
begin
  if p_desc !~ 'C15 PRUEBA' then
    raise exception 'c15-pruebas: la descripción de un movimiento de prueba lleva «C15 PRUEBA» (%)', p_desc;
  end if;
  perform pg_temp.c15_ser('dueno');
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', pg_temp.c15('banco'), 'nombre', 'Plaid · c15-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_build_object('id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text,
                                                  'descripcion', p_desc, 'tipo', 'DEBIT', 'pendiente', false))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform pg_temp.c15_ser('editor');
  if not exists (select 1 from movimientos_banco m where m.id = v_mov and m.estado = 'pendiente') then
    raise exception 'c15-pruebas: el movimiento de prueba % casó solo con algo del libro (¿un monto real igual?)', p_id;
  end if;
  return v_mov;
end $$;
-- (casar un cargo con la primera opción de su propuesta, como el dueño; devuelve lo que contesta, o el código del error)
create or replace function pg_temp.c15_casar(p_mov uuid, p_partes jsonb default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c15_ser('dueno');
  r := fn_nomina_cargo_casar(p_mov, coalesce(p_partes, fn_nomina_cargo_propuesta(p_mov)->'opciones'->0->'partes'));
  perform pg_temp.c15_ser('editor');
  return r;
end $$;

-- Una fila del control de la nómina: 'verde' o 'rojo', y su detalle (como el SQL Editor).
create or replace function pg_temp.c15_ctl(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo' end from fn_nomina_control() c where c.orden = p_orden
$$;
create or replace function pg_temp.c15_ctl_det(p_orden int) returns text language sql as $$
  select c.detalle from fn_nomina_control() c where c.orden = p_orden
$$;
-- ¿El detalle de un control NOMBRA algo (un patrón de LIKE)? Con los datos reales la lista de un control puede no caber
-- entera («… y N más»): entonces lo de la prueba puede haber quedado fuera y se da por nombrado.
create or replace function pg_temp.c15_nombra(p_detalle text, p_patron text) returns boolean language sql immutable as $$
  select coalesce(p_detalle like p_patron or p_detalle ~ '; … y [0-9]+ más', false)
$$;
-- (un control que la prueba puso en rojo y arregló: vuelve a verde, o —si los datos reales de esta base ya lo tenían en
-- rojo— deja de nombrar lo de la prueba)
create or replace function pg_temp.c15_vuelve(p_orden int, p_patron text) returns text language sql as $$
  select case when c.ok then 'verde' when c.detalle not like p_patron then 'verde' else 'rojo' end from fn_nomina_control() c where c.orden = p_orden
$$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los estados
-- (c4), los cuadres de la IA (c8), los del jornal y del margen (c10), los de
-- las facturas (c11), los del WIP (c12), los de la cédula (c13), los de los
-- subs (c14) y lo que detiene el cierre del mes de las pruebas (c9, sin las
-- filas de la propia nómina); cada una, si está. Como el SQL Editor.
create or replace function pg_temp.c15_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c15_ser('editor');
  select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
  v := v || x;
  if to_regprocedure('public.fn_banco_control(text,text[])') is not null then
    execute $q$ select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') from public.fn_banco_control($1) k where not k.ok $q$
       into x using pg_temp.c15('mes');
    v := v || x;
  end if;
  if to_regprocedure('public.fn_estados_control(text,text[])') is not null then
    execute $q$ select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') from public.fn_estados_control($1) k where not k.ok $q$
       into x using pg_temp.c15('mes');
    v := v || x;
  end if;
  if pg_temp.c15('hay_c8') = 'true' then
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
  if pg_temp.c15('hay_c11') = 'true' then
    execute $q$ select coalesce(array_agg('c11: ' || k.orden order by k.orden), '{}')
                  from public.v_emision_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c15('hay_c12') = 'true' and pg_temp.c15('mes') is not null then
    execute $q$ select coalesce(array_agg('c12: ' || k.orden order by k.orden), '{}')
                  from public.fn_wip_control($1) k where k.nivel = 'cuadre' and not k.ok $q$ into x using pg_temp.c15('mes');
    v := v || x;
  end if;
  if pg_temp.c15('hay_c13') = 'true' then
    execute $q$ select coalesce(array_agg('c13: ' || k.orden order by k.orden), '{}')
                  from public.v_cedula_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c15('hay_c14') = 'true' then
    execute $q$ select coalesce(array_agg('c14: ' || k.orden order by k.orden), '{}')
                  from public.v_subs_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c15('hay_c9') = 'true' and pg_temp.c15('mes') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k
                 where k.nivel = 'detiene' and k.ok is distinct from true and k.orden not between 180 and 183 $q$
       into x using pg_temp.c15('mes');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c15_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;
-- (LO MISMO, SIN DEJAR NADA: la revisión del cierre de c9 guarda lo que encuentra en su tabla. Se lee dentro de un
-- bloque que se deshace: estas pruebas no dejan nada, ni eso.)
create or replace function pg_temp.c15_rojos_limpio() returns text[] language plpgsql as $$
declare
  v text[];
begin
  begin
    v := pg_temp.c15_rojos();
    raise exception using errcode = 'MXT00';
  exception when sqlstate 'MXT00' then null;
  end;
  return v;
end $$;

-- Lo que hay en lo que c15 toca y en lo que sus pruebas siembran (la penúltima lo compara, y la última otra vez)
create or replace function pg_temp.c15_cuenta(p_tabla text) returns text language plpgsql as $$
declare
  n text := 'no hay';
begin
  if to_regclass(p_tabla) is not null then
    execute format('select count(*)::text from %s', p_tabla) into n;
  end if;
  return n;
end $$;
create or replace function pg_temp.c15_revisiones() returns text language plpgsql as $$
declare
  v text := 'no hay';
begin
  if to_regclass('public.cierre_revisiones') is not null then
    execute 'select md5(coalesce(string_agg(md5(r::text), '''' order by md5(r::text)), '''')) from public.cierre_revisiones r' into v;
  end if;
  return v;
end $$;
create or replace function pg_temp.c15_conteos() returns text language sql as $$
  select format('config %s · mapeo %s · personas %s · archivos %s · corridas %s · sus personas %s · líneas %s · reparto %s · lote %s · pagos %s · '
                'partes %s · declaraciones %s · lotes de horas %s (%s) · historial %s · asientos %s · líneas del libro %s · contadores %s · '
                'perfiles %s · usuarios %s · tarifas %s · horas %s · aprobaciones %s · obras %s · movimientos del banco %s · cerrados %s · '
                'revisiones del cierre %s · el reloj %s · funciones %s',
                (select md5(to_jsonb(c)::text) from nomina_config c where c.id = 1),
                (select md5(coalesce(string_agg(md5(to_jsonb(k)::text), '' order by k.alias), '')) from nomina_columnas k),
                (select count(*) from nomina_personas), (select count(*) from nomina_archivos), (select count(*) from nomina_corridas),
                (select count(*) from nomina_corrida_personas), (select count(*) from nomina_lineas), (select count(*) from nomina_reparto),
                (select count(*) from nomina_reparto_horas), (select count(*) from nomina_pagos), (select count(*) from nomina_pago_partes),
                (select count(*) from nomina_declaraciones), (select count(*) from nomina_lotes), (select count(*) from nomina_lote_horas),
                (select count(*) from nomina_historial), (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from perfiles), pg_temp.c15_cuenta('auth.users'),
                (select count(*) from costos_equipo), (select count(*) from horas), pg_temp.c15_cuenta('public.horas_aprobaciones'),
                (select count(*) from proyectos), pg_temp.c15_cuenta('public.movimientos_banco'),
                (select count(*) from periodos where estado = 'cerrado'), pg_temp.c15_revisiones(),
                left(md5(pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)), 12),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c15 values ('conteos', pg_temp.c15_conteos());
-- (el reloj DE VERDAD, tal cual está al empezar: si una prueba lo dejara fingido —no pasa: cada una lo deshace con su
-- subtransacción—, el final de este archivo lo restaura y lo dice como un fallo)
insert into _c15 select 'reloj_def', pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure);
-- (lo de las otras capas que ya estaba en rojo ANTES de las pruebas: la última lo dice y no lo cuenta)
insert into _c15 select 'rojos_antes', array_to_string(pg_temp.c15_rojos_limpio(), '; ');
-- (los cuadres del propio control de la nómina que ya estaban en rojo con los datos de esta base)
insert into _c15
select 'rojos_nomina', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from fn_nomina_control() k where k.nivel = 'cuadre' and not k.ok;
create or replace function pg_temp.c15_propios() returns text language sql as $$
  select coalesce(nullif((select string_agg(k.orden::text, ',' order by k.orden)
                            from fn_nomina_control() k
                           where k.nivel = 'cuadre' and not k.ok
                             and not (k.orden::text = any (string_to_array(pg_temp.c15('rojos_nomina'), ',')))), ''), 'nada nuevo en rojo')
$$;
-- (las funciones AJENAS a c15 que «permisos» de c2 ya marcaba ANTES de las pruebas: se dicen y no cuentan como fallo de c15)
create or replace function pg_temp.c15_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c15
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c15_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c15: %';
create or replace function pg_temp.c15_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c15_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c15('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c15_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;
-- CERRAR HASTA UN MES dentro de una prueba (como c12 y c14): la apertura, si sigue abierta, con un asiento de prueba, y
-- cada mes hasta ese, en orden. Como el SQL Editor.
create or replace function pg_temp.c15_cerrar_hasta(p_periodo text) returns void language plpgsql as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  perform pg_temp.c15_ser('editor');
  select * into v_p from periodos where periodo = p_periodo;
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear(jsonb_build_object(
      'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
      'descripcion', 'C15 PRUEBA: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
  end loop;
end $$;

-- =====================================================================
-- 1. EL PEGADO: las precondiciones en verde, las 15 tablas, las 7 vistas y
--    las 60 funciones por su nombre exacto, cada objeto con su comentario
--    «c15: …», la configuración (una fila) y el mapeo de fábrica.
-- =====================================================================
do $$
declare
  v_obt text;
  v_esp text := 'precondiciones: nada | tablas 15 de 15 | vistas 7 de 7 | funciones 60 de 60 | sin su comentario «c15: »: ninguno | la '
                'configuración: 1 fila (id 1) | el mapeo de fábrica: 130 columnas | el puente: puesto';
begin
  begin
    perform pg_temp.c15_ser('editor');
    select format('precondiciones: %s | tablas %s de 15 | vistas %s de 7 | funciones %s de 60 | sin su comentario «c15: »: %s | la '
                  'configuración: %s fila (id %s) | el mapeo de fábrica: %s columnas | el puente: %s',
                  coalesce(fn_nomina_precondiciones(), 'nada'),
                  (select count(*) from unnest(pg_temp.c15_tablas()) t where to_regclass('public.' || t) is not null),
                  (select count(*) from unnest(pg_temp.c15_vistas()) t where to_regclass('public.' || t) is not null),
                  (select count(distinct p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn())),
                  coalesce((select string_agg(x.o, ', ' order by x.o)
                              from (select c.relname::text as o from pg_class c
                                     where c.relnamespace = 'public'::regnamespace
                                       and c.relname = any (pg_temp.c15_tablas() || pg_temp.c15_vistas())
                                       and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c15: %'
                                    union all
                                    select p.proname::text from pg_proc p
                                     where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn())
                                       and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c15: %') x), 'ninguno'),
                  (select count(*) from nomina_config), (select min(id) from nomina_config),
                  (select count(*) from nomina_columnas where de_fabrica),
                  case when exists (select 1 from pg_trigger tg where tg.tgrelid = 'public.nomina_corridas'::regclass
                                       and tg.tgname = 'trg_nomina_corridas_libro' and tg.tgenabled = 'O') then 'puesto' else 'NO' end)
      into v_obt;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: las precondiciones no piden nada, están las 15 tablas, las 7 vistas y las 60 funciones (por su nombre exacto), cada objeto con su comentario «c15: …», la configuración es una fila, el mapeo de fábrica trae sus 130 nombres de columna y el puente al libro está puesto',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. LAS PRECONDICIONES EN ROJO: algo ajeno con nombre de c15, algo colgado
--    de una de sus vistas, una tabla con su nombre que no es la suya; y por
--    la API no se pregunta.
do $$
declare
  v_obt text; a text; b text; c text; d text;
  v_esp text := 'algo ajeno con nombre de c15: lo dice | algo colgado de una vista: lo dice | una tabla que no es la de c15: lo dice | por la '
                'API: 42501 | deshecho: nada';
begin
  begin
    perform pg_temp.c15_ser('editor');
    begin
      comment on function public.fn_nomina_usd(numeric) is 'otra cosa';
      a := case when fn_nomina_precondiciones() like '%con nombre de c15 y sin ser de c15%fn_nomina_usd%' then 'lo dice' else coalesce(fn_nomina_precondiciones(), 'nada') end;
      raise exception using errcode = 'MXT00';
    exception when sqlstate 'MXT00' then null;
    end;
    begin
      create view public.zz_c15_ajena as select corrida_id from public.v_nomina_corridas;
      b := case when fn_nomina_precondiciones() like '%zz_c15_ajena%depende(n) de las vistas de c15%' then 'lo dice' else coalesce(fn_nomina_precondiciones(), 'nada') end;
      raise exception using errcode = 'MXT00';
    exception when sqlstate 'MXT00' then null;
    end;
    begin
      alter table public.nomina_reparto rename column destino to destino_de_otro;
      c := case when fn_nomina_precondiciones() like '%la tabla nomina_reparto ya existe%no es la de c15%' then 'lo dice' else coalesce(fn_nomina_precondiciones(), 'nada') end;
      raise exception using errcode = 'MXT00';
    exception when sqlstate 'MXT00' then null;
    end;
    d := pg_temp.c15_estado('select public.fn_nomina_precondiciones()');
    v_obt := format('algo ajeno con nombre de c15: %s | algo colgado de una vista: %s | una tabla que no es la de c15: %s | por la API: %s | '
                    'deshecho: %s', a, b, c, d, coalesce(fn_nomina_precondiciones(), 'nada'));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo (sin tocar nada): una función con nombre de c15 que no es de c15, una vista ajena colgada de una de las suyas, una tabla con su nombre que no es la suya; por la API no se pregunta; y deshecho, no piden nada',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. LA API: anon y service_role no tienen nada; el equipo, 42501 y cero
--    filas; el dueño sin su código lee lo general y no escribe ni ve una
--    propuesta; con su código, entra.
do $$
declare
  v_obt text;
  v_esp text := 'anon y service_role: 0 tablas, 0 vistas, 0 funciones | el equipo: importar 42501, configurar 42501, la propuesta de un cargo '
                '42501, el control 0 filas, las corridas 0 filas, el mapeo 0 filas | el dueño sin su código: lee la configuración ok, cambiarla '
                'PGRST MFA, importar PGRST MFA, una propuesta PGRST MFA, una persona PGRST MFA | el dueño con su código: configura ok, el '
                'control 18 filas';
begin
  begin
    perform pg_temp.c15_ser('editor');
    v_obt := format('anon y service_role: %s tablas, %s vistas, %s funciones',
      (select count(*) from unnest(pg_temp.c15_tablas()) t cross join (values ('anon'), ('service_role')) g(r)
        where has_table_privilege(g.r, 'public.' || t, 'select, insert, update, delete, truncate, references, trigger')),
      (select count(*) from unnest(pg_temp.c15_vistas()) t cross join (values ('anon'), ('service_role')) g(r)
        where has_table_privilege(g.r, 'public.' || t, 'select, insert, update, delete')),
      (select count(*) from pg_proc p cross join (values ('anon'), ('service_role')) g(r)
        where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn()) and has_function_privilege(g.r, p.oid, 'execute')));
    v_obt := v_obt || format(' | el equipo: importar %s, configurar %s, la propuesta de un cargo %s, el control %s filas, las corridas %s filas, el mapeo %s filas',
      pg_temp.c15_estado('select public.fn_nomina_importar(''{}''::jsonb)', 'equipo'),
      pg_temp.c15_estado('select public.fn_nomina_config()', 'equipo'),
      pg_temp.c15_estado(format('select public.fn_nomina_cargo_propuesta(%L)', gen_random_uuid()), 'equipo'),
      pg_temp.c15_da('select count(*) from public.v_nomina_control', 'equipo'),
      pg_temp.c15_da('select count(*) from public.nomina_corridas', 'equipo'),
      pg_temp.c15_da('select count(*) from public.nomina_columnas', 'equipo'));
    v_obt := v_obt || format(' | el dueño sin su código: lee la configuración %s, cambiarla %s, importar %s, una propuesta %s, una persona %s',
      pg_temp.c15_estado('select public.fn_nomina_config()', 'dueno_aal1'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"saldo_dias": 11}''::jsonb)', 'dueno_aal1'),
      pg_temp.c15_estado('select public.fn_nomina_importar(''{}''::jsonb)', 'dueno_aal1'),
      pg_temp.c15_estado(format('select public.fn_nomina_propuesta(%L)', gen_random_uuid()), 'dueno_aal1'),
      pg_temp.c15_estado('select public.fn_nomina_persona(''{}''::jsonb)', 'dueno_aal1'));
    v_obt := v_obt || format(' | el dueño con su código: configura %s, el control %s filas',
      pg_temp.c15_estado('select public.fn_nomina_config(''{}''::jsonb)'),
      pg_temp.c15_da('select count(*) from public.v_nomina_control'));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: anon y service_role no tienen ningún privilegio (ni tabla, ni vista, ni función); el equipo recibe 42501 y cero filas; el dueño SIN el código del teléfono lee lo general pero no escribe, no importa y no ve una propuesta (403 «MFA»); con su código, entra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. EL CATÁLOGO: la única función SECURITY DEFINER es el trigger del
--    puente (sin EXECUTE para la API); RLS en todas las tablas, con policies
--    que piden al dueño, y lo de cada persona con el código; las vistas,
--    security_invoker; y «permisos» de c2 en verde con c15 pegado.
do $$
declare
  v_obt text;
  v_esp text := 'SECURITY DEFINER: fn_nomina_al_libro (de trigger: sí; la API la ejecuta: no) | sin API: fn_nomina_al_libro, fn_nomina_guarda, '
                'fn_nomina_pegado, fn_nomina_precondiciones | RLS en 15 de 15 | policies que no piden al dueño: 0 | lo de cada persona pide el '
                'código: 4 de 4 | vistas security_invoker: 7 de 7 | permisos (c2): verde';
begin
  begin
    perform pg_temp.c15_ser('editor');
    select format('SECURITY DEFINER: %s (de trigger: %s; la API la ejecuta: %s) | sin API: %s | RLS en %s de 15 | policies que no piden al '
                  'dueño: %s | lo de cada persona pide el código: %s de 4 | vistas security_invoker: %s de 7 | permisos (c2): %s',
             (select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') from pg_proc p
               where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn()) and p.prosecdef),
             (select case when bool_and(p.prorettype = 'trigger'::regtype) then 'sí' else 'no' end from pg_proc p
               where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn()) and p.prosecdef),
             (select case when bool_or(has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
                                       or has_function_privilege('service_role', p.oid, 'execute')) then 'sí' else 'no' end from pg_proc p
               where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn()) and p.prosecdef),
             (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p
               where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn())
                 and not has_function_privilege('authenticated', p.oid, 'execute')),
             (select count(*) from unnest(pg_temp.c15_tablas()) t join pg_class c on c.oid = to_regclass('public.' || t) where c.relrowsecurity),
             (select count(*) from pg_policy pl
               where pl.polrelid in (select to_regclass('public.' || t) from unnest(pg_temp.c15_tablas()) t)
                 and coalesce(pg_get_expr(pl.polqual, pl.polrelid), pg_get_expr(pl.polwithcheck, pl.polrelid), '') not like '%es_dueno()%'),
             (select count(*) from unnest(array['nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas']) t
               where exists (select 1 from pg_policy pl where pl.polrelid = to_regclass('public.' || t) and pl.polcmd = 'r'
                                and pg_get_expr(pl.polqual, pl.polrelid) like '%aal2%')
                 and not exists (select 1 from pg_policy pl where pl.polrelid = to_regclass('public.' || t) and pl.polcmd = 'r'
                                    and pg_get_expr(pl.polqual, pl.polrelid) not like '%aal2%')),
             (select count(*) from unnest(pg_temp.c15_vistas()) t join pg_class c on c.oid = to_regclass('public.' || t)
               where coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false)),
             pg_temp.c15_permisos())
      into v_obt;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: la única función SECURITY DEFINER de la capa es el trigger del puente al libro, y la API no la puede ejecutar; RLS en las 15 tablas con policies que piden al dueño; lo de cada persona se lee solo con el código; las 7 vistas leen con los permisos de quien mira; y «permisos» de c2 sigue en verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 5. LA GUARDA: a mano no se escribe nada (MX003), aunque sea el dueño por
--    la API o el SQL Editor; lo que es rastro, ni con la marca; una corrida
--    no salta de estado; y una corrida puesta «posteada» a mano, con la
--    marca y un asiento inventado, no entra al libro: el puente la para.
do $$
declare
  v_obt text; v_c uuid; v_n bigint;
  v_nom text := 'la guarda de las tablas y el puente';
  v_esp text := 'el dueño por la API, a mano: la configuración MX003, una corrida MX003, borrar una columna del mapeo MX003 | el SQL Editor, a '
                'mano: MX003 | con la marca puesta a mano: editar una línea (el dueño no tiene ni el permiso: 42501; el SQL Editor, MX003), '
                'editar lo que la corrida trajo MX003, saltar a anulada MX003, borrar una corrida MX003, truncar el historial MX003 | '
                'postearla a mano con un asiento inventado: MX001, y en el libro entraron 0 asientos';
begin
  if pg_temp.c15_omitir(5, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    select count(*) into v_n from asientos;
    v_obt := format('el dueño por la API, a mano: la configuración %s, una corrida %s, borrar una columna del mapeo %s | el SQL Editor, a mano: %s',
      pg_temp.c15_estado('update public.nomina_config set saldo_dias = 99'),
      pg_temp.c15_estado(format('update public.nomina_corridas set periodo_desde = periodo_desde where id = %L', v_c)),
      pg_temp.c15_estado('delete from public.nomina_columnas where alias = ''net pay'''),
      pg_temp.c15_estado('update public.nomina_config set saldo_dias = 99', 'editor'));
    v_obt := v_obt || format(' | con la marca puesta a mano: editar una línea (el dueño no tiene ni el permiso: %s; el SQL Editor, %s), editar lo que la corrida trajo %s, saltar a anulada %s, borrar una corrida %s, truncar el historial %s',
      pg_temp.c15_estado(format('update public.nomina_lineas set monto = 1 where corrida_id = %L', v_c), 'dueno', 'nomina_lineas'),
      pg_temp.c15_estado(format('update public.nomina_lineas set monto = 1 where corrida_id = %L', v_c), 'editor', 'nomina_lineas'),
      pg_temp.c15_estado(format('update public.nomina_corridas set bruto = 1 where id = %L', v_c), 'dueno', 'nomina_corridas'),
      pg_temp.c15_estado(format('update public.nomina_corridas set estado = ''anulada'', anulada_el = now(), anulada_motivo = ''C15 PRUEBA'' where id = %L', v_c), 'dueno', 'nomina_corridas'),
      pg_temp.c15_estado(format('delete from public.nomina_corridas where id = %L', v_c), 'editor', 'nomina_corridas'),
      pg_temp.c15_estado('truncate public.nomina_historial', 'editor', 'nomina_historial'));
    v_obt := v_obt || format(' | postearla a mano con un asiento inventado: %s, y en el libro entraron %s asientos',
      pg_temp.c15_estado(format($q$update public.nomina_corridas
                                     set estado = 'posteada', huella = 'x', pasivos = '{"2210": 1.00}'::jsonb, posteada_el = now(),
                                         plan = '{"asiento": {"lineas": [{"cuenta": "6000", "monto": "1.00"}, {"cuenta": "2210", "monto": "-1.00"}]}}'::jsonb
                                   where id = %L$q$, v_c), 'dueno', 'nomina_corridas'),
      (select count(*) from asientos) - v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda: las tablas de la nómina no se escriben a mano (MX003), ni el dueño por la API ni el SQL Editor; lo que es rastro, ni con la marca; una corrida no salta de estado ni se borra; y una corrida que alguien pone «posteada» a mano con un asiento inventado no entra al libro: el puente comprueba que el asiento ES el journal guardado',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. LA CONFIGURACIÓN: se lee, se cambia (queda en el historial) y frena lo
--    que no sirve; y la cuenta de lo sin obra: la de la nómina o, si no dice
--    nada, la del jornal de c10 cuando sirve.
do $$
declare
  v_obt text; r jsonb; v_h bigint; v_j text;
  v_nom text := 'la configuración de la nómina';
  v_esp text := 'se lee: con sus cuentas (mano de obra 5000 y 5001, sin obra 6000, bolsa 5015) | cambiada: la semana empieza el 3, la cuota a '
                '6010, y 1 apunte en el historial | la bolsa en un gasto: MX004 | el sueldo de oficina en un pasivo: MX004 | la cuota en una '
                'cuenta de sueldos: MX004 | la semana en el día 8: MX005 | una tolerancia que no es un número: MX005 | una clave que no '
                'existe: 22023 | un patrón que no es una expresión: 22023 | sin la cuenta de lo sin obra de la nómina: la del jornal si '
                'sirve, y si no, ninguna: sí';
begin
  if pg_temp.c15_omitir(6, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar(false);
    select count(*) into v_h from nomina_historial where que = 'config';
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_config();
    v_obt := format('se lee: con sus cuentas (mano de obra %s y %s, sin obra %s, bolsa %s)', r->'cuentas'->>'mano_obra',
                    r->'cuentas'->>'mano_obra_oficial', r->'cuentas'->>'sin_obra', r->'cuentas'->>'bolsa');
    r := fn_nomina_config('{"semana_empieza": 3, "cuenta_cuota": "6010"}');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | cambiada: la semana empieza el %s, la cuota a %s, y %s apunte en el historial', r->>'semana_empieza',
                             r->>'cuenta_cuota', (select count(*) from nomina_historial where que = 'config') - v_h);
    v_obt := v_obt || format(' | la bolsa en un gasto: %s | el sueldo de oficina en un pasivo: %s | la cuota en una cuenta de sueldos: %s | la '
                             'semana en el día 8: %s | una tolerancia que no es un número: %s | una clave que no existe: %s | un patrón que '
                             'no es una expresión: %s',
      pg_temp.c15_estado('select public.fn_nomina_config(''{"cuenta_bolsa": "6000"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"cuenta_oficina": "2210"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"cuenta_cuota": "6000"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"semana_empieza": 8}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"amarre_tolerancia": "abc"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"no_existe": 1}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_config(''{"cargo_patrones": {"neto": "("}}''::jsonb)'));
    perform pg_temp.c15_estado('select public.fn_nomina_config(''{"cuenta_sin_obra": null}''::jsonb)');
    select j.cuenta_sin_obra into v_j from jornal_config j where j.id = 1 and fn_nomina_cuenta_mal(j.cuenta_sin_obra, 'sin_obra') is null;
    v_obt := v_obt || ' | sin la cuenta de lo sin obra de la nómina: la del jornal si sirve, y si no, ninguna: '
             || case when fn_nomina_cuenta_sin_obra() is not distinct from v_j then 'sí' else 'no (' || coalesce(fn_nomina_cuenta_sin_obra(), 'nulo') || ')' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'la configuración: se lee con las cuentas que usa la nómina, se cambia (y queda en el historial), y frena una cuenta que no sirve para su uso (MX004), un número fuera de medida (MX005), una clave desconocida y un patrón roto (22023); la cuenta de lo sin obra es la de la nómina o, si no dice nada, la del jornal de c10 cuando sirve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. EL MAPEO DE COLUMNAS: decir qué es una columna nueva, cambiar una de
--    fábrica, quitar la que no lo es; y sus frenos.
do $$
declare
  v_obt text; r jsonb; q jsonb;
  v_nom text := 'el mapeo de columnas';
  v_esp text := 'una columna nueva: zz otra → ben_patron, 2240, concepto zz_otra, de fábrica no | una de fábrica cambiada: employer suta tax → '
                '2225, sigue de fábrica sí | quitar la nueva: sí | quitar una de fábrica: MX003 | una clase que no existe: 22023 | una cuenta '
                'en una columna de horas: MX004 | una cuenta que no es un pasivo: MX004 | declara en una parte del bruto: 22023 | un dato por '
                'nombre de columna: 22023 | sin el código del teléfono: PGRST MFA';
begin
  if pg_temp.c15_omitir(7, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar(false);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_columna('{"columna": "ZZ Otra", "clase": "ben_patron", "cuenta": "2240"}');
    q := fn_nomina_columna('{"columna": "Employer SUTA tax", "cuenta": "2225"}');
    perform pg_temp.c15_ser('editor');
    v_obt := format('una columna nueva: %s → %s, %s, concepto %s, de fábrica %s | una de fábrica cambiada: %s → %s, sigue de fábrica %s',
                    r->>'alias', r->>'clase', r->>'cuenta', r->>'concepto', case when (r->>'de_fabrica')::boolean then 'sí' else 'no' end,
                    q->>'alias', q->>'cuenta', case when (q->>'de_fabrica')::boolean then 'sí' else 'no' end);
    v_obt := v_obt || format(' | quitar la nueva: %s | quitar una de fábrica: %s | una clase que no existe: %s | una cuenta en una columna de '
                             'horas: %s | una cuenta que no es un pasivo: %s | declara en una parte del bruto: %s | un dato por nombre de '
                             'columna: %s | sin el código del teléfono: %s',
      case when (pg_temp.c15_da('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "quitar": true}''::jsonb)->>''quitada''')) = 'true' then 'sí' else 'no' end,
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "Net pay", "quitar": true}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "clase": "propina"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "clase": "horas", "cuenta": "2240"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "clase": "ben_patron", "cuenta": "6000"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "clase": "bruto", "declara": "fit"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "000-00-1234", "clase": "ignorar"}''::jsonb)'),
      pg_temp.c15_estado('select public.fn_nomina_columna(''{"columna": "ZZ Otra", "clase": "ignorar"}''::jsonb)', 'dueno_aal1'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'el mapeo de columnas: se dice qué es una columna nueva (su clase y su cuenta), se cambia una de fábrica (que sigue siéndolo), se quita la que no es de fábrica y la de fábrica no; y frena una clase que no existe, una cuenta donde no va o que no es un pasivo, un «declara» fuera de un impuesto y un dato puesto por nombre de columna',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- EL ARCHIVO
-- =====================================================================
-- 8. IMPORTAR EL JOURNAL: el ensayo dice lo que entendería sin guardar nada
--    (y propone a cada persona su perfil por el nombre); la importación deja
--    la corrida con su día de pago, su período y sus totales al centavo, sus
--    personas y sus líneas por concepto, y lo que amarra con las
--    declaraciones. Del archivo solo queda su nombre, su sha256 y su tamaño.
do $$
declare
  v_obt text; r jsonb; c nomina_corridas; v_id uuid; a nomina_archivos; v_n bigint;
  v_nom text := 'importar el journal';
  v_esp text := format('el ensayo: 1 nómina, cuadra sí, se puede postear sí, entraría 1, guardó 0 corridas, y a cada persona le propone su '
                'perfil por el nombre: 3 de 3 | importada: «Entró: 1 nómina(s).» | la corrida: regular, importada, día de pago %s, período del '
                '%s al %s, se queda con las horas sí, 3 personas, bruto 5808.00, retenido 947.32, deducciones 50.00, neto 4810.68, reembolsos '
                '64.25, patrón 635.99 + 0.00, horas 238.5, cuadra sí | lo que amarra: fit 503.00, ss 360.10 + 360.10, medicare 84.22 + 84.22, '
                'futa 34.85, reempleo 156.82 | 34 líneas por persona y concepto; el neto de ZZ Ayudante Dos 1193.07 a 2210 | la fila de totales '
                'del archivo, guardada: sí | del archivo: su nombre, su sha256 de 64 y 5 filas',
                pg_temp.c15_pago(), pg_temp.c15_d(0), pg_temp.c15_d(13));
begin
  if pg_temp.c15_omitir(8, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    select count(*) into v_n from nomina_corridas;
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(pg_temp.c15_journal()));
    perform pg_temp.c15_ser('editor');
    v_obt := format('el ensayo: %s nómina, cuadra %s, se puede postear %s, entraría %s, guardó %s corridas, y a cada persona le propone su perfil por el nombre: %s de 3',
      jsonb_array_length(r->'corridas'), case when (r->'corridas'->0->>'cuadra')::boolean then 'sí' else 'no' end,
      case when (r->'corridas'->0->>'se_puede_postear')::boolean then 'sí' else 'no' end, r->>'entraria',
      (select count(*) from nomina_corridas) - v_n,
      (select count(*) from jsonb_array_elements(r->'corridas'->0->'personas') q
        where q->'propuesta'->>'usuario_id' = pg_temp.c15(case q->>'nombre' when 'ZZ Ayudante Uno' then 'p1' when 'ZZ Ayudante Dos' then 'p2' else 'p3' end)));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()));
    perform pg_temp.c15_ser('editor');
    v_id := (r->'corridas'->0->>'corrida')::uuid;
    select * into c from nomina_corridas where id = v_id;
    select * into a from nomina_archivos where id = c.archivo_id;
    v_obt := v_obt || format(' | importada: «%s» | la corrida: %s, %s, día de pago %s, período del %s al %s, se queda con las horas %s, %s personas, '
      'bruto %s, retenido %s, deducciones %s, neto %s, reembolsos %s, patrón %s + %s, horas %s, cuadra %s',
      r->>'mensaje', c.tipo, c.estado, c.dia_pago, c.periodo_desde, c.periodo_hasta, case when c.toma_horas then 'sí' else 'no' end, c.personas,
      c.bruto, c.imp_empleado, c.deducciones, c.neto, c.reembolsos, c.imp_patron, c.ben_patron, trim_scale(c.horas),
      case when c.cuadra then 'sí' else 'no' end);
    v_obt := v_obt || format(' | lo que amarra: fit %s, ss %s + %s, medicare %s + %s, futa %s, reempleo %s', c.declara->>'fit', c.declara->>'ss_ee',
      c.declara->>'ss_er', c.declara->>'med_ee', c.declara->>'med_er', c.declara->>'futa', c.declara->>'suta');
    v_obt := v_obt || format(' | %s líneas por persona y concepto; el neto de ZZ Ayudante Dos %s a %s | la fila de totales del archivo, guardada: %s | del archivo: su nombre, su sha256 de %s y %s filas',
      (select count(*) from nomina_lineas l where l.corrida_id = v_id),
      (select l.monto from nomina_lineas l where l.corrida_id = v_id and l.persona_id = pg_temp.c15_persona('ZZ Ayudante Dos') and l.clase = 'neto'),
      (select l.cuenta from nomina_lineas l where l.corrida_id = v_id and l.persona_id = pg_temp.c15_persona('ZZ Ayudante Dos') and l.clase = 'neto'),
      case when (c.totales_archivo->>'net_pay')::numeric = 4810.68 then 'sí' else 'no' end, length(a.sha256), a.filas);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'importar el journal (las celdas del CSV, como texto): el ensayo dice lo que entendería sin guardar nada y propone a cada persona su perfil; la importación deja la corrida con su día de pago, su período y sus totales al centavo, lo que amarra con las declaraciones, sus líneas por persona y concepto, y del archivo solo su nombre, su sha256 y su tamaño',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. NO ENTRA DOS VECES: el mismo archivo otra vez (su sha256); la misma
--    nómina por OTRO archivo (con preámbulo, otra columna y los importes con
--    $ y comas); la misma bajada de otra forma (sin la columna del período, o
--    con la llave de Gusto: otra llave, la misma nómina); con otras cifras no
--    entra sola: o reemplaza a la que estaba sin postear, o es otra nómina
--    del mismo día; y una ya posteada no se reemplaza.
do $$
declare
  v_obt text; r jsonb; v_csv2 text; v_csv3 text; v_csv4 text; v_csv5 text; v_n bigint; v_a bigint; v_c uuid; v_c3 uuid;
  v_nom text := 'la misma nómina no entra dos veces';
  v_esp text := 'el mismo archivo otra vez: ya_estaba, «Ese archivo ya estaba importado: no entró nada nuevo.» | la misma nómina por otro '
                'archivo (otro sha256, con preámbulo, una columna más y un importe con $ y comas): ya_estaba | el ensayo lo avisa antes: '
                'ya estaba, con las mismas cifras | bajada sin la columna del período (otra llave): ya_estaba | bajada con la llave de '
                'Gusto (otra llave): ya_estaba | con otras cifras: otra_distinta, no entró, y dice que se puede reemplazar: true | las dos '
                'cosas a la vez: 22023 | en lugar de la que estaba: reemplazada (la de antes, descartada) | diciendo que es otra nómina del '
                'mismo día: nueva; y otra vez: ya_estaba | ya posteada, con otras cifras y pidiendo reemplazarla: otra_distinta, y sigue '
                'posteada | corridas vivas de esta nómina: 2, subidas que dejaron algo: 4';
begin
  if pg_temp.c15_omitir(9, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    select count(*) into v_n from nomina_corridas;
    select count(*) into v_a from nomina_archivos;
    v_c := pg_temp.c15_importar(pg_temp.c15_journal());
    v_csv2 := 'ZZ Empresa C15 PRUEBA' || E'\n' || 'Payroll journal' || E'\n\n'
              || replace(pg_temp.c15_journal(array[',Job title', ',ZZ Puesto', ',ZZ Puesto', ',ZZ Puesto', ',']), ',1958.00,', ',"$1,958.00",');
    -- (otras cifras: la deducción de ZZ Ayudante Dos, 40 en vez de 50; cuadra igual)
    v_csv3 := replace(replace(pg_temp.c15_journal(), '50.00,1193.07,0.00,1193.07', '40.00,1203.07,0.00,1203.07'),
                      '947.32,50.00,4810.68,64.25,4874.93', '947.32,40.00,4820.68,64.25,4884.93');
    -- (la misma, sin las columnas del período: su llave ya no lleva el período)
    v_csv4 := replace(replace(replace(pg_temp.c15_journal(), 'Pay period start,Pay period end,', 'ZZ Otra,ZZ Otra dos,'),
                              pg_temp.c15_us(pg_temp.c15_d(0)) || ',' || pg_temp.c15_us(pg_temp.c15_d(13)) || ',', ',,'), 'Totals,,,,', 'Totals,,,,');
    -- (la misma, con la llave de Gusto en una columna más)
    v_csv5 := pg_temp.c15_journal(array[',Payroll uuid', ',zz-c15-nomina-1', ',zz-c15-nomina-1', ',zz-c15-nomina-1', ',']);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()));
    v_obt := format('el mismo archivo otra vez: %s, «%s»', r->'corridas'->0->>'resultado', r->>'mensaje');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv2, 'zz-c15-prueba-otro.csv'));
    v_obt := v_obt || format(' | la misma nómina por otro archivo (otro sha256, con preámbulo, una columna más y un importe con $ y comas): %s',
                             r->'corridas'->0->>'resultado');
    r := fn_nomina_ensayo(pg_temp.c15_arch(v_csv2, 'zz-c15-prueba-otro.csv'));
    v_obt := v_obt || format(' | el ensayo lo avisa antes: %s', case when (r->'corridas'->0->'ya_estaba'->>'mismas_cifras')::boolean
                                                                       then 'ya estaba, con las mismas cifras' else coalesce(r->'corridas'->0->>'ya_estaba', 'no') end);
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv4, 'zz-c15-prueba-sin-periodo.csv'));
    v_obt := v_obt || format(' | bajada sin la columna del período (otra llave): %s', r->'corridas'->0->>'resultado');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv5, 'zz-c15-prueba-con-llave.csv'));
    v_obt := v_obt || format(' | bajada con la llave de Gusto (otra llave): %s', r->'corridas'->0->>'resultado');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv3, 'zz-c15-prueba-cifras.csv'));
    v_obt := v_obt || format(' | con otras cifras: %s, %s, y dice que se puede reemplazar: %s', r->'corridas'->0->>'resultado',
                             case when (r->>'nuevas')::int = 0 then 'no entró' else 'ENTRÓ' end, r->'corridas'->0->>'se_puede_reemplazar');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | las dos cosas a la vez: %s',
      pg_temp.c15_estado(format('select public.fn_nomina_importar(%L::jsonb, ''{"reemplazar": true, "otra_nomina": true}''::jsonb)',
                                pg_temp.c15_arch(v_csv3, 'zz-c15-prueba-cifras.csv'))));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv3, 'zz-c15-prueba-cifras.csv'), '{"reemplazar": true}');
    v_c3 := (r->'corridas'->0->>'corrida')::uuid;
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | en lugar de la que estaba: %s (la de antes, %s)', r->'corridas'->0->>'resultado',
                             (select estado from nomina_corridas where id = v_c));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()), '{"otra_nomina": true}');
    v_obt := v_obt || format(' | diciendo que es otra nómina del mismo día: %s', r->'corridas'->0->>'resultado');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()), '{"otra_nomina": true}');
    v_obt := v_obt || format('; y otra vez: %s', r->'corridas'->0->>'resultado');
    perform pg_temp.c15_ser('editor');
    -- (la de las otras cifras, posteada; y la primera otra vez, pidiendo reemplazarla: una posteada no se reemplaza)
    perform pg_temp.c15_enlazar();
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_descartar((select id from nomina_corridas where llave like '%#%' and estado = 'importada' order by importada_el desc limit 1),
                                'C15 PRUEBA: sobra');
    perform pg_temp.c15_ser('editor');
    perform pg_temp.c15_postear(v_c3);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()), '{"reemplazar": true}');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | ya posteada, con otras cifras y pidiendo reemplazarla: %s, y sigue %s', r->'corridas'->0->>'resultado',
                             (select estado from nomina_corridas where id = v_c3));
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()), '{"otra_nomina": true}');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | corridas vivas de esta nómina: %s, subidas que dejaron algo: %s',
                             (select count(*) from nomina_corridas k where k.dia_pago = pg_temp.c15_pago() and k.estado in ('importada', 'posteada')
                                 and exists (select 1 from nomina_corrida_personas cp where cp.corrida_id = k.id and cp.nombre like 'ZZ %')),
                             (select count(*) from nomina_archivos) - v_a);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'la misma nómina no entra dos veces: ni por el mismo archivo (su sha256), ni por otro archivo distinto con la misma nómina, ni bajada de otra forma (sin su período, o con su llave de Gusto: se reconoce por su día de pago y su tipo, y por sus cifras); con otras cifras contesta «otra distinta» y no entra sola: o reemplaza a la que estaba sin postear (que queda descartada), o se dice que es otra nómina del mismo día; y una ya posteada no se reemplaza',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. LO DELICADO NO SE GUARDA NUNCA: un archivo con columna de Seguro
--     Social, cuenta y ruta del banco, dirección y correo, y una columna que
--     nadie conoce con valores con forma de Seguro Social. De ninguna queda
--     un valor en ninguna tabla; ni en un mensaje de error.
do $$
declare
  v_obt text; r jsonb; v_csv text; v_txt text; v_e1 text; v_e2 text; v_id uuid;
  v_nom text := 'lo delicado no se guarda';
  v_esp text := 'entró: nueva | las columnas que no se leyeron (solo sus nombres): Bank account account number, Bank account routing number, '
                'Employee email, Home address, SSN, ZZ Dato raro | alguno de sus valores en alguna tabla de la nómina: no | un Seguro '
                'Social en la columna del nombre: 22023, y el mensaje no lo repite: sí | un dato puesto por rótulo de columna: se apunta como '
                '«columna 33» | una celda que no es un importe: MX005, y el mensaje no la repite: sí';
begin
  if pg_temp.c15_omitir(10, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    v_csv := pg_temp.c15_journal(array[
      ',SSN,Bank account account number,Bank account routing number,Home address,Employee email,ZZ Dato raro',
      ',000-00-1234,000111222333,000000000,1 Calle Falsa C15,zz1@c15-pruebas.invalid,000-00-9991',
      ',000-00-1235,000111222334,000000000,2 Calle Falsa C15,zz2@c15-pruebas.invalid,000-00-9992',
      ',000-00-1236,000111222335,000000000,3 Calle Falsa C15,zz3@c15-pruebas.invalid,000-00-9993',
      ',,,,,,']);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv));
    perform pg_temp.c15_ser('editor');
    v_id := (r->'corridas'->0->>'corrida')::uuid;
    v_obt := format('entró: %s | las columnas que no se leyeron (solo sus nombres): %s', r->'corridas'->0->>'resultado',
                    (select string_agg(x, ', ' order by x) from jsonb_array_elements_text(r->'delicado') x));
    -- (todo lo que guardan las tablas de la nómina, y lo que contestó la importación, como texto)
    select r::text || coalesce(string_agg(z.t, ''), '') into v_txt
      from (select to_jsonb(x)::text as t from nomina_archivos x union all select to_jsonb(x)::text from nomina_corridas x
            union all select to_jsonb(x)::text from nomina_corrida_personas x union all select to_jsonb(x)::text from nomina_lineas x
            union all select to_jsonb(x)::text from nomina_personas x union all select to_jsonb(x)::text from nomina_historial x
            union all select to_jsonb(x)::text from nomina_columnas x) z;
    v_obt := v_obt || ' | alguno de sus valores en alguna tabla de la nómina: '
             || case when v_txt ~ '000-00-123|000111222|Calle Falsa C15|c15-pruebas\.invalid|000-00-999' then 'SÍ' else 'no' end;
    v_e1 := pg_temp.c15_dice(format('select public.fn_nomina_importar(%L::jsonb)',
              pg_temp.c15_arch(replace(pg_temp.c15_journal(), 'ZZ Ayudante,Uno', '000-00-7777,Uno'), 'zz-c15-prueba-2.csv')));
    v_obt := v_obt || format(' | un Seguro Social en la columna del nombre: %s, y el mensaje no lo repite: %s', left(v_e1, 5),
                             case when v_e1 !~ '7777' then 'sí' else 'NO' end);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(replace(v_csv, 'ZZ Dato raro', '000-00-5555'), 'zz-c15-prueba-3.csv'));
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | un dato puesto por rótulo de columna: se apunta como «%s»',
                             (select x from jsonb_array_elements_text(r->'delicado') x where x like 'columna%'));
    v_e2 := pg_temp.c15_dice(format('select public.fn_nomina_importar(%L::jsonb)',
              pg_temp.c15_arch(replace(pg_temp.c15_journal(), ',1760.00,', ',abc-secreto,'), 'zz-c15-prueba-4.csv')));
    v_obt := v_obt || format(' | una celda que no es un importe: %s, y el mensaje no la repite: %s', left(v_e2, 5),
                             case when v_e2 !~ 'secreto' then 'sí' else 'NO' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'lo delicado no se guarda nunca: de un archivo con columnas de Seguro Social, cuenta y ruta del banco, dirección y correo —y una columna desconocida con valores con forma de Seguro Social— no queda ningún valor en ninguna tabla (solo los nombres de esas columnas); un Seguro Social en la columna del nombre para el archivo, y ningún mensaje de error repite el valor de una celda',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 11. UNA COLUMNA CON CIFRAS QUE EL MAPEO NO CONOCE deja la corrida sin
--     postear hasta que se dice qué es (y se vuelve a subir el archivo).
do $$
declare
  v_obt text; r jsonb; v_csv text; v_c uuid; v_c2 uuid; p jsonb;
  v_nom text := 'una columna desconocida frena la corrida';
  v_esp text := 'el ensayo: se puede postear no, por «ZZ Employer 401k match» (3 celdas con cifras) | entra, y la frena: '
                'columna_sin_clasificar | postearla: MX008 | sus cifras no se guardaron: sí | dicho qué es (un beneficio del patrón, a 2240) '
                'y vuelta a subir tal cual: otra_distinta, y se puede reemplazar: true | subida en lugar de la que estaba: reemplazada, la de '
                'antes queda descartada, sin frenos, beneficios del patrón 30.00, y lo que queda por pagar en 2240 es 80.00';
begin
  if pg_temp.c15_omitir(11, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    v_csv := pg_temp.c15_journal(array[',ZZ Employer 401k match', ',10.00', ',0.00', ',20.00', ',30.00']);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(v_csv));
    perform pg_temp.c15_ser('editor');
    v_obt := format('el ensayo: se puede postear %s, por «%s» (%s celdas con cifras)',
                    case when (r->'corridas'->0->>'se_puede_postear')::boolean then 'sí' else 'no' end,
                    r->'corridas'->0->'sin_clasificar'->0->>'columna', r->'corridas'->0->'sin_clasificar'->0->>'celdas');
    v_c := pg_temp.c15_importar(v_csv);
    perform pg_temp.c15_enlazar();
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | entra, y la frena: %s | postearla: %s | sus cifras no se guardaron: %s', pg_temp.c15_codigos(p->'frenos'),
      pg_temp.c15_estado(format('select public.fn_nomina_postear(%L, ''x'')', v_c)),
      case when not exists (select 1 from nomina_lineas l where l.corrida_id = v_c and l.concepto like 'zz%')
                and (select ben_patron from nomina_corridas where id = v_c) = 0 then 'sí' else 'no' end);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_columna('{"columna": "ZZ Employer 401k match", "clase": "ben_patron", "cuenta": "2240"}');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv));
    v_obt := v_obt || format(' | dicho qué es (un beneficio del patrón, a 2240) y vuelta a subir tal cual: %s, y se puede reemplazar: %s',
                             r->'corridas'->0->>'resultado', r->'corridas'->0->>'se_puede_reemplazar');
    r := fn_nomina_importar(pg_temp.c15_arch(v_csv), '{"reemplazar": true}');
    perform pg_temp.c15_ser('editor');
    v_c2 := (r->'corridas'->0->>'corrida')::uuid;
    p := pg_temp.c15_propuesta(v_c2);
    v_obt := v_obt || format(' | subida en lugar de la que estaba: %s, la de antes queda %s, %s, beneficios del patrón %s, y lo que queda por pagar en 2240 es %s',
      r->'corridas'->0->>'resultado', (select estado from nomina_corridas where id = v_c),
      case when jsonb_array_length(p->'frenos') = 0 then 'sin frenos' else pg_temp.c15_codigos(p->'frenos') end,
      p->'totales'->>'ben_patron', p->'pasivos'->>'2240');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'una columna con cifras que el mapeo no conoce: la corrida entra pero NO se puede postear (lo dice el ensayo, la frena la propuesta y postear contesta MX008), y sus cifras no se guardan; dicho qué es la columna, el archivo vuelto a subir no entra solo (es la misma nómina con otras cifras); subido en lugar de la que estaba, la reemplaza (la de antes queda descartada) y entra sin frenos, con esa columna en su cuenta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. CUADRA AL CENTAVO O NO SE POSTEA: una persona cuyo neto no es su bruto
--     menos lo retenido y las deducciones (por un centavo), la fila de
--     totales que no suma sus filas; y el archivo que no se puede leer.
do $$
declare
  v_obt text; r jsonb; v_csv text; v_c uuid; p jsonb; v_d text;
  v_nom text := 'cuadra al centavo o no se postea';
  v_esp text := 'una persona descuadrada por un centavo: cuadra no | dice quién, con las dos cifras ($1,666.21 y $1,666.22): sí | dice que la '
                'fila de total no suma: sí | entra, y la frena: no_cuadra | postearla: MX008 | un importe con tres decimales: MX005 | un '
                'archivo sin cabecera: MX009 | sin la columna del día de pago: MX009; diciéndolo, 1 nómina';
begin
  if pg_temp.c15_omitir(12, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    v_csv := replace(pg_temp.c15_journal(), '0.00,1666.21,0.00,1666.21', '0.00,1666.22,0.00,1666.21');
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(v_csv));
    perform pg_temp.c15_ser('editor');
    select string_agg(x, ' · ') into v_d from jsonb_array_elements_text(r->'corridas'->0->'descuadres') x;
    v_obt := format('una persona descuadrada por un centavo: cuadra %s | dice quién, con las dos cifras ($1,666.21 y $1,666.22): %s | dice que la fila de total no suma: %s',
                    case when (r->'corridas'->0->>'cuadra')::boolean then 'sí' else 'no' end,
                    case when v_d like '%ZZ Ayudante Uno%$1,666.21%$1,666.22%' then 'sí' else 'no: ' || left(v_d, 300) end,
                    case when v_d like '%la fila de total%no es la suma%' then 'sí' else 'no' end);
    v_c := pg_temp.c15_importar(v_csv);
    perform pg_temp.c15_enlazar();
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | entra, y la frena: %s | postearla: %s', pg_temp.c15_codigos(p->'frenos'),
                             pg_temp.c15_estado(format('select public.fn_nomina_postear(%L, ''x'')', v_c)));
    v_obt := v_obt || format(' | un importe con tres decimales: %s | un archivo sin cabecera: %s | sin la columna del día de pago: %s; diciéndolo, %s nómina',
      pg_temp.c15_estado(format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(replace(pg_temp.c15_journal(), ',198.00,1958.00', ',198.005,1958.00'), 'zz-c15-b.csv'))),
      pg_temp.c15_estado(format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(E'ZZ una hoja,que no es,un journal\n1,2,3\n', 'zz-c15-c.csv'))),
      pg_temp.c15_estado(format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(replace(pg_temp.c15_journal(), ',Check date,', ',ZZ Otra,'), 'zz-c15-d.csv'))),
      pg_temp.c15_da(format('select jsonb_array_length(public.fn_nomina_ensayo(%L::jsonb, %L::jsonb)->''corridas'')',
                            pg_temp.c15_arch(replace(pg_temp.c15_journal(), ',Check date,', ',ZZ Otra,'), 'zz-c15-d.csv'),
                            jsonb_build_object('dia_pago', pg_temp.c15_pago()))));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'cuadra al centavo o no se postea: una persona cuyo neto no es su bruto menos lo retenido y las deducciones —por un centavo— deja la corrida sin cuadrar, y dice quién y las dos cifras, y que la fila de totales del archivo no suma; entra, pero frenada; un importe con tres decimales, un archivo sin cabecera o sin día de pago no entran (y dicen qué falta)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LAS PERSONAS Y EL REPARTO
-- =====================================================================
-- 13. LAS PERSONAS: cada empleado del journal nace sin enlazar (con su
--     perfil propuesto por el nombre) y frena la corrida hasta que Edgar lo
--     enlaza y lo confirma, una vez.
do $$
declare
  v_obt text; v_c uuid; p jsonb; r jsonb; v_libre boolean; v_cl text; v_h bigint;
  v_nom text := 'las personas';
  v_esp text := 'recién importadas: 3 sin enlazar, y a las 3 se les propone su perfil por el nombre, de clase campo | frenan la corrida: '
                'sin_enlazar | enlazada sin confirmar: sin_confirmar, y sigue frenando: sí | confirmada: lista | el mismo perfil para otra '
                'persona: MX008 | un perfil que no existe: 22023 | la clase por el rol del perfil: campo → campo; dueño → oficial | '
                'cambiarle la clase la deja sin confirmar: sí | y todo queda en el historial: sí';
begin
  if pg_temp.c15_omitir(13, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    select count(*) into v_h from nomina_historial where que = 'persona';
    v_c := pg_temp.c15_importar(pg_temp.c15_journal());
    v_obt := format('recién importadas: %s sin enlazar, y a las %s se les propone su perfil por el nombre, de clase %s',
      (select count(*) from v_nomina_personas v where v.nombre like 'ZZ %' and v.estado = 'sin_enlazar'),
      (select count(*) from v_nomina_personas v
        where v.propuesta_usuario_id::text = pg_temp.c15(case v.nombre when 'ZZ Ayudante Uno' then 'p1' when 'ZZ Ayudante Dos' then 'p2' else 'p3' end)),
      (select min(v.propuesta_clase) from v_nomina_personas v where v.nombre like 'ZZ %'));
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | frenan la corrida: %s', pg_temp.c15_codigos(p->'frenos'));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'usuario_id', pg_temp.c15('p1')));
    perform pg_temp.c15_ser('editor');
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | enlazada sin confirmar: %s, y sigue frenando: %s',
      (select v.estado from v_nomina_personas v where v.nombre = 'ZZ Ayudante Uno'),
      case when pg_temp.c15_codigos(p->'frenos') like '%sin_confirmar%' then 'sí' else 'no' end);
    v_cl := r->>'clase';
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'confirmar', true));
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | confirmada: %s | el mismo perfil para otra persona: %s | un perfil que no existe: %s',
      (select v.estado from v_nomina_personas v where v.nombre = 'ZZ Ayudante Uno'),
      pg_temp.c15_estado(format('select public.fn_nomina_persona(%L::jsonb)',
                                jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Dos'), 'usuario_id', pg_temp.c15('p1')))),
      pg_temp.c15_estado(format('select public.fn_nomina_persona(%L::jsonb)',
                                jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Dos'), 'usuario_id', gen_random_uuid()))));
    -- (el dueño → oficial: solo si el dueño de esta base todavía no está enlazado con su persona de verdad)
    v_libre := not exists (select 1 from nomina_personas o where o.usuario_id = pg_temp.c15('dueno')::uuid);
    if v_libre then
      perform pg_temp.c15_ser('dueno');
      r := fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Oficial Tres'), 'usuario_id', pg_temp.c15('dueno')));
      perform fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Oficial Tres'), 'usuario_id', pg_temp.c15('p3'), 'clase', 'oficial'));
      perform pg_temp.c15_ser('editor');
    end if;
    v_obt := v_obt || format(' | la clase por el rol del perfil: campo → %s; dueño → %s', v_cl, case when v_libre then r->>'clase' else 'oficial' end);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_persona(jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'clase', 'oficina'));
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | cambiarle la clase la deja sin confirmar: %s | y todo queda en el historial: %s',
      case when not (r->>'confirmada')::boolean then 'sí' else 'no' end,
      case when (select count(*) from nomina_historial where que = 'persona') - v_h >= 3 then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'las personas: cada empleado del journal nace sin enlazar, con su perfil de la app propuesto por el nombre, y frena su corrida hasta que Edgar lo enlaza y lo confirma (una vez); un perfil no sirve para dos personas; la clase sale del rol del perfil (campo → campo; dueño → oficial) y cambiarla pide confirmar otra vez; todo queda en el historial',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 14. EL REPARTO AL CENTAVO: dos obras (una con CO), una hora sin obra, horas
--     sin aprobar que no entran, las horas de Gusto distintas de las
--     aprobadas (aviso con las dos cifras) y el oficial con parte en obra.
--     La regla: el bruto de cada persona entre sus grupos (obra y CO; lo sin
--     obra aparte) por sus horas, truncado al centavo, y los centavos que
--     faltan a los de mayor resto (en el empate, al de más horas). ZZ
--     Ayudante Uno: 1,958.00 entre 16 h (A), 10 h (B, CO #1) y 4 h (sin
--     obra) = 1,044.266…, 652.666… y 261.066…: truncados suman 1,957.98 y los
--     dos centavos van a los dos grupos de más horas → 1,044.27, 652.67 y
--     261.06.
do $$
declare
  v_obt text; v_c uuid; p jsonb; v_av text;
  v_nom text := 'el reparto al centavo';
  v_esp text := 'se puede postear: sí | avisa: horas_distintas,oficial_en_obra,reembolsos,sin_aprobar,sin_obra | ZZ Ayudante Uno: bruto obra 5000 a 16 '
                '1044.27 · bruto obra 5000 b CO #1 10 652.67 · bruto sin_obra 6000 4 261.06 · patron obra 5015 a 16 114.35 · patron obra 5015 b '
                'CO #1 10 71.47 · patron sin_obra 6010 4 28.59 (suman 1958.00 y 214.41) | ZZ Ayudante Dos: bruto obra 5000 b 8 1450.00 · patron '
                'obra 5015 b 8 158.78 (suman 1450.00 y 158.78) | ZZ Oficial Tres: bruto obra 5001 a 20 600.00 · bruto oficial 6005 1800.00 · '
                'patron obra 5015 a 20 65.70 · patron oficial 6010 197.10 (suman 2400.00 y 262.80) | las horas de Gusto contra las aprobadas, '
                'con las dos cifras (86 y 30; 72.5 y 8): sí | las 7 h sin aprobar no entran: sí | el asiento que propone: 5000 a 1044.27 · 5000 '
                'b 1450.00 · 5000 b CO #1 652.67 · 5001 a 600.00 · 6000 261.06 · 6005 1800.00 · 6010 225.69 · 5015 410.30 · 2250 64.25 · 2210 '
                '-4874.93 · 2220 -1391.64 · 2225 -34.85 · 2230 -156.82 · 2240 -50.00 | y el reparto del burden: 5010 a 180.05 · 5010 b 158.78 · '
                '5010 b CO #1 71.47 · 5015 -410.30';
begin
  if pg_temp.c15_omitir(14, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    p := pg_temp.c15_propuesta(v_c);
    select string_agg(q->>'texto', ' · ') into v_av from jsonb_array_elements(p->'avisos') q;
    v_obt := format('se puede postear: %s | avisa: %s', case when (p->>'puede_postear')::boolean then 'sí' else 'no: ' || pg_temp.c15_codigos(p->'frenos') end,
                    pg_temp.c15_codigos(p->'avisos'));
    select v_obt || ' | ' || string_agg(format('%s: %s (suman %s y %s)', x->>'nombre',
             (select string_agg(concat_ws(' ', q->>'clase', q->>'destino', q->>'cuenta', replace(q->>'proyecto_id', 'c15-prueba-', ''), q->>'co',
                                          q->>'horas', q->>'monto'), ' · ' order by o)
                from jsonb_array_elements(x->'partes') with ordinality e(q, o)),
             (select sum((q->>'monto')::numeric) from jsonb_array_elements(x->'partes') q where q->>'clase' = 'bruto'),
             (select sum((q->>'monto')::numeric) from jsonb_array_elements(x->'partes') q where q->>'clase' = 'patron')), ' | ' order by (x->>'n')::int)
      into v_obt from jsonb_array_elements(p->'personas') x;
    v_obt := v_obt || format(' | las horas de Gusto contra las aprobadas, con las dos cifras (86 y 30; 72.5 y 8): %s | las 7 h sin aprobar no entran: %s',
      case when v_av like '%ZZ Ayudante Uno: Gusto le pagó 86 h%30 h aprobadas%' and v_av like '%ZZ Ayudante Dos: Gusto le pagó 72.5 h%8 h aprobadas%' then 'sí' else 'no' end,
      case when v_av like '%ZZ Ayudante Uno tiene 1 reporte(s) de horas sin aprobar en el período (7 h)%' then 'sí' else 'no' end);
    v_obt := v_obt || format(' | el asiento que propone: %s | y el reparto del burden: %s',
      (select string_agg(concat_ws(' ', q->>'cuenta', replace(q->>'proyecto_id', 'c15-prueba-', ''), q->>'co', q->>'monto'), ' · ' order by o)
         from jsonb_array_elements(p->'asiento'->'lineas') with ordinality e(q, o)),
      (select string_agg(concat_ws(' ', q->>'cuenta', replace(q->>'proyecto_id', 'c15-prueba-', ''), q->>'co', q->>'monto'), ' · ' order by o)
         from jsonb_array_elements(p->'burden'->'lineas') with ordinality e(q, o)));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'el reparto al centavo: el bruto de cada persona de campo entre sus obras (y su CO) por sus horas APROBADAS del período, con lo sin obra a su cuenta y lo patronal por las mismas horas; las horas sin aprobar no entran; las de Gusto contra las aprobadas, un aviso con las dos cifras; el oficial, su parte de obra a 5001 y lo demás a 6005; y cada persona suma su bruto y su parte patronal, sin un centavo de más ni de menos',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. ALGUIEN CON SUELDO Y NINGUNA HORA APROBADA frena la corrida hasta que
--     Edgar elige: aprobar sus horas, o mandarlo «sin obra» con su nota.
do $$
declare
  v_obt text; v_c uuid; p jsonb; v_t text; v_j text;
  v_nom text := 'alguien sin horas aprobadas';
  v_esp text := 'con sueldo y ninguna hora aprobada: sin_horas, y lo dice con su nombre y su sueldo: sí | postearla: MX008 | decidir sin su '
                'nota: 22023 | «sin obra» con su nota: sin frenos, avisa sin_obra_decidido, y va: bruto sin_obra 6000 1450.00 · patron sin_obra '
                '6010 158.78 | quitada la decisión: sin_horas | con sus horas aprobadas: sin frenos, y va: bruto obra 5000 a 6 1450.00 · patron '
                'obra 5015 a 6 158.78 | sin cuenta para lo sin obra, frena solo si tampoco la da el jornal: sí';
begin
  if pg_temp.c15_omitir(15, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    perform pg_temp.c15_ser('editor');
    delete from horas where id = -1510000006;
    p := pg_temp.c15_propuesta(v_c);
    select string_agg(q->>'texto', ' · ') into v_t from jsonb_array_elements(p->'frenos') q;
    v_obt := format('con sueldo y ninguna hora aprobada: %s, y lo dice con su nombre y su sueldo: %s | postearla: %s | decidir sin su nota: %s',
      pg_temp.c15_codigos(p->'frenos'), case when v_t like '%ZZ Ayudante Dos tiene sueldo en esta nómina ($1,450.00) y ninguna hora aprobada%' then 'sí' else 'no' end,
      pg_temp.c15_estado(format('select public.fn_nomina_postear(%L, ''x'')', v_c)),
      pg_temp.c15_estado(format('select public.fn_nomina_decidir(%L, %L, ''{"decision": "sin_obra"}''::jsonb)', v_c, pg_temp.c15_persona('ZZ Ayudante Dos'))));
    perform pg_temp.c15_estado(format('select public.fn_nomina_decidir(%L, %L, ''{"decision": "sin_obra", "nota": "C15 PRUEBA: estuvo en el taller"}''::jsonb)',
                                      v_c, pg_temp.c15_persona('ZZ Ayudante Dos')));
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | «sin obra» con su nota: %s, avisa %s, y va: %s',
      case when jsonb_array_length(p->'frenos') = 0 then 'sin frenos' else pg_temp.c15_codigos(p->'frenos') end,
      (select string_agg(q->>'codigo', ',') from jsonb_array_elements(p->'avisos') q where q->>'codigo' = 'sin_obra_decidido'),
      (select string_agg(concat_ws(' ', q->>'clase', q->>'destino', q->>'cuenta', q->>'monto'), ' · ' order by o)
         from jsonb_array_elements(p->'personas'->1->'partes') with ordinality e(q, o)));
    perform pg_temp.c15_estado(format('select public.fn_nomina_decidir(%L, %L, ''{"quitar": true}''::jsonb)', v_c, pg_temp.c15_persona('ZZ Ayudante Dos')));
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | quitada la decisión: %s', pg_temp.c15_codigos(p->'frenos'));
    perform pg_temp.c15_hora(9, 'p2', pg_temp.c15_d(10), 'c15-prueba-a', 6);
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | con sus horas aprobadas: %s, y va: %s',
      case when jsonb_array_length(p->'frenos') = 0 then 'sin frenos' else pg_temp.c15_codigos(p->'frenos') end,
      (select string_agg(concat_ws(' ', q->>'clase', q->>'destino', q->>'cuenta', replace(q->>'proyecto_id', 'c15-prueba-', ''), q->>'horas', q->>'monto'), ' · ' order by o)
         from jsonb_array_elements(p->'personas'->1->'partes') with ordinality e(q, o)));
    -- (sin la cuenta de lo sin obra en la nómina: frena —por las 4 h sin obra de ZZ Ayudante Uno— solo si tampoco la da el jornal de c10)
    perform set_config('mx_nomina.escribe', 'nomina_config', true);
    update nomina_config set cuenta_sin_obra = null where id = 1;
    perform set_config('mx_nomina.escribe', '', true);
    p := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || ' | sin cuenta para lo sin obra, frena solo si tampoco la da el jornal: '
             || case when (fn_nomina_cuenta_sin_obra() is null) = (pg_temp.c15_codigos(p->'frenos') = 'falta_cuenta_sin_obra') then 'sí'
                     else 'no (' || pg_temp.c15_codigos(p->'frenos') || ')' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'alguien de campo con sueldo y NINGUNA hora aprobada en el período frena la corrida (con su nombre y su sueldo) hasta que Edgar elige: mandarlo «sin obra» con su nota (su sueldo va entero a la cuenta de lo sin obra, con su aviso) o aprobar sus horas (y se reparte por ellas); y sin cuenta para lo sin obra, las horas sin obra frenan',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- EL ASIENTO
-- =====================================================================
-- 16. POSTEAR: una corrida = su journal, en la fecha del día de pago, con
--     origen «nomina_corridas» y cada cuenta al centavo; y el reparto de su
--     burden real a las obras (origen «nomina_burden»). Lo que Edgar vio es
--     lo que entra; dos toques, un asiento.
do $$
declare
  v_obt text; v_c uuid; r jsonb; a asientos; b asientos; c nomina_corridas; v_n bigint; v_visto text; x text; y text;
  v_nom text := 'el asiento de la corrida';
  v_esp text := format('con una huella que no es la que vio: MX011 | si cambia una hora entre que mira y toca: MX011 | posteada: su journal es de '
                'puente, origen nomina_corridas (la corrida), fecha %s, y cuadra a 0.00 | sus líneas: 5000 a 1044.27 · 5000 b 1450.00 · 5000 b '
                'CO #1 652.67 · 5001 a 600.00 · 6000 261.06 · 6005 1800.00 · 6010 225.69 · 5015 410.30 · 2250 64.25 · 2210 -4874.93 · 2220 '
                '-1391.64 · 2225 -34.85 · 2230 -156.82 · 2240 -50.00 | el reparto de su burden: origen nomina_burden, misma fecha: 5010 a 180.05 · '
                '5010 b 158.78 · 5010 b CO #1 71.47 · 5015 -410.30 | lo que quedó por pagar: 2210 4874.93, 2220 1391.64, 2225 34.85, 2230 156.82, '
                '2240 50.00 | su reparto: 12 partes (bruto 5808.00, patronal 635.99) | su lote: 7 reportes de horas, 58 h, con 4008.00 de sueldo '
                'y 438.89 de lo patronal repartidos por ellas | otra vez: ya estaba, y entraron 2 asientos en total', pg_temp.c15_pago());
begin
  if pg_temp.c15_omitir(16, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    select count(*) into v_n from asientos;
    v_visto := pg_temp.c15_propuesta(v_c)->>'visto';
    x := pg_temp.c15_estado(format('select public.fn_nomina_postear(%L, ''no-es-lo-que-vi'')', v_c));
    -- (entre que miró y que tocó, alguien aprueba las 7 h que estaban sin aprobar: lo que entraría ya no es lo que vio)
    perform pg_temp.c15_ser('editor');
    update horas set aprobado_por = pg_temp.c15('dueno')::uuid, aprobado_el = now() where id = -1510000005;
    y := pg_temp.c15_estado(format('select public.fn_nomina_postear(%L, %L)', v_c, v_visto));
    update horas set aprobado_por = null, aprobado_el = null where id = -1510000005;
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_postear(v_c, v_visto);
    perform pg_temp.c15_ser('editor');
    select * into c from nomina_corridas where id = v_c;
    select * into a from asientos where id = c.asiento_id;
    select * into b from asientos where id = c.burden_asiento_id;
    v_obt := format('con una huella que no es la que vio: %s | si cambia una hora entre que mira y toca: %s | posteada: su journal es de %s, origen %s '
                    '(%s), fecha %s, y cuadra a %s | sus líneas: %s', x, y, a.camino, a.origen_tabla,
                    case when a.origen_id = v_c::text then 'la corrida' else 'otra cosa' end, a.fecha_contable,
                    (select sum(l.monto) from asiento_lineas l where l.asiento_id = a.id), pg_temp.c15_asiento(a.id));
    v_obt := v_obt || format(' | el reparto de su burden: origen %s, %s: %s', b.origen_tabla,
                             case when b.fecha_contable = a.fecha_contable and b.origen_id = v_c::text then 'misma fecha' else 'otra fecha' end,
                             pg_temp.c15_asiento(b.id));
    v_obt := v_obt || format(' | lo que quedó por pagar: %s | su reparto: %s partes (bruto %s, patronal %s) | su lote: %s reportes de horas, %s h, con %s de '
                             'sueldo y %s de lo patronal repartidos por ellas',
      (select string_agg(e.key || ' ' || e.value, ', ' order by e.key) from jsonb_each_text(c.pasivos) e),
      (select count(*) from nomina_reparto x2 where x2.corrida_id = v_c),
      (select sum(x2.monto) from nomina_reparto x2 where x2.corrida_id = v_c and x2.clase = 'bruto'),
      (select sum(x2.monto) from nomina_reparto x2 where x2.corrida_id = v_c and x2.clase = 'patron'),
      (select count(*) from nomina_reparto_horas h where h.corrida_id = v_c and h.titular and h.vivo),
      (select trim_scale(sum(h.horas)) from nomina_reparto_horas h where h.corrida_id = v_c),
      (select sum(h.bruto) from nomina_reparto_horas h where h.corrida_id = v_c),
      (select sum(h.patron) from nomina_reparto_horas h where h.corrida_id = v_c));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_postear(v_c, v_visto);
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | otra vez: %s, y entraron %s asientos en total', case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRO' end,
                             (select count(*) from asientos) - v_n);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'el asiento: una corrida = su journal, de puente, con origen «nomina_corridas», en la fecha del día de pago y con cada cuenta al centavo (5000 y 5001 por obra, 6000, 6005, 6010, la bolsa 5015, los reembolsos, y lo que queda por pagar en 2210, 2220, 2225, 2230 y 2240), más el reparto de su burden real a las obras (5010 contra 5015); lo que Edgar vio es lo que entra (MX011 si cambió algo), y dos toques dejan un asiento',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. CON LA NÓMINA EN EL LIBRO, LAS OTRAS CAPAS SIGUEN COMO ESTABAN: c3
--     «mano de obra» en verde (5000 y 5001 vienen de un journal de nómina; el
--     5010, de su reparto), y c3 ve el journal del mes.
do $$
declare
  v_obt text; v_c uuid; r jsonb; s0 text[]; s1 text[]; v_plan jsonb; c nomina_corridas; v_mo boolean;
  v_nom text := 'las otras capas con la nómina en el libro';
  v_esp text := 'con la nómina en el libro, en rojo nuevo: ninguno | c3 «mano de obra»: verde | el devengo estándar de c3 ve el journal del '
                'mes: nomina_en_el_mes, y nombra sus 2 asientos | el papel de sus asientos: 2 (el journal y el reparto de su burden)';
begin
  if pg_temp.c15_omitir(17, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    s0 := pg_temp.c15_rojos();
    r := pg_temp.c15_postear(v_c);
    s1 := pg_temp.c15_rojos();
    select * into c from nomina_corridas where id = v_c;
    v_plan := fn_puente_devengo_plan(pg_temp.c15('mes'));
    select k.ok into v_mo from fn_puentes_verificar() k where k.control = 'mano_de_obra';
    v_obt := format('con la nómina en el libro, en rojo nuevo: %s | c3 «mano de obra»: %s | el devengo estándar de c3 ve el journal del mes: %s, y '
                    'nombra sus %s asientos | el papel de sus asientos: %s (el journal y el reparto de su burden)',
      pg_temp.c15_nuevos(s0, s1), case when v_mo or 'c3: mano_de_obra' = any (s0) then 'verde' else 'rojo' end, v_plan->>'codigo',
      (select count(*) from jsonb_array_elements_text(v_plan->'nomina') n(v)
        where n.v in (c.asiento_numero, (select a.numero from asientos a where a.id = c.burden_asiento_id))),
      (select count(*) from v_nomina_papel p where p.origen_id = v_c::text and p.origen_tabla in ('nomina_corridas', 'nomina_burden')
          and p.papel like '%Gusto del ' || fn_nomina_dia(c.dia_pago) || '%'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'con la nómina en el libro ningún control de las otras capas pasa a rojo (la cadena y «permisos» de c2, los puentes de c3, el banco de c6, los estados de c4, y los demás): c3 «mano de obra» en verde, porque el 5000 y el 5001 vienen de un journal de nómina y el 5010 de su reparto; c3 ve el journal del mes; y sus asientos tienen su papel',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. EL COSTO POR OBRA (c10) Y EL WIP (c12) LEEN EL BURDEN REAL POR OBRA: la
--     mano de obra de cada obra es su 5000, su 5001 y su 5010, al centavo; y
--     la capa dice qué horas pagó cada corrida.
do $$
declare
  v_obt text; v_c uuid; r jsonb; v_m text := 'no está'; v_w text := 'no está'; v_hp text;
  v_nom text := 'el costo por obra y el WIP con el burden real';
  v_esp text := 'en el libro, por obra: a sueldo 1644.27 y burden real 180.05; b sueldo 2102.67 y burden real 230.25 | el costo por obra '
                '(c10), la mano de obra por nómina: a 1824.32, b 2332.92 | el WIP (c12), el costo de cada obra a fin de mes: a 1824.32, b '
                '2332.92 | las horas que pagó esta nómina: 7 reportes, 4008.00 de sueldo';
begin
  if pg_temp.c15_omitir(18, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    select string_agg(format('%s sueldo %s y burden real %s', replace(q.proyecto_id, 'c15-prueba-', ''), q.sueldo, q.burden), '; ' order by q.proyecto_id)
      into v_obt
      from (select l.proyecto_id, sum(l.monto) filter (where l.cuenta in ('5000', '5001')) as sueldo, sum(l.monto) filter (where l.cuenta = '5010') as burden
              from asiento_lineas l where l.proyecto_id in ('c15-prueba-a', 'c15-prueba-b') group by l.proyecto_id) q;
    if to_regclass('public.v_margen_obra') is not null then
      execute $q$ select string_agg(replace(m.proyecto_id, 'c15-prueba-', '') || ' ' || m.mano_obra_nomina, ', ' order by m.proyecto_id)
                    from public.v_margen_obra m where m.proyecto_id in ('c15-prueba-a', 'c15-prueba-b') $q$ into v_m;
    end if;
    if pg_temp.c15('hay_c12') = 'true' then
      execute $q$ select string_agg(replace(w.proyecto_id, 'c15-prueba-', '') || ' ' || w.costo, ', ' order by w.proyecto_id)
                    from public.fn_wip_libro($1, null) w where w.proyecto_id in ('c15-prueba-a', 'c15-prueba-b') $q$
         into v_w using pg_temp.c15('mes_hasta')::date;
    end if;
    perform pg_temp.c15_ser('dueno');
    select format('%s reportes, %s de sueldo', count(*), sum(h.bruto)) into v_hp from fn_nomina_horas_pagadas() h where h.corrida_id = v_c;
    perform pg_temp.c15_ser('editor');
    v_obt := format('en el libro, por obra: %s | el costo por obra (c10), la mano de obra por nómina: %s | el WIP (c12), el costo de cada obra a fin de mes: %s | '
                    'las horas que pagó esta nómina: %s', v_obt, v_m, v_w, v_hp);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'el costo por obra (c10) y el WIP (c12) leen del libro el sueldo y el BURDEN REAL de cada obra, al centavo: lo que el patrón pagó por las horas de esa obra, repartido de la bolsa 5015 al 5010 de cada una; y la capa dice qué reportes de horas pagó cada corrida, con lo que le tocó a cada uno',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 19. EL DEVENGO ESTÁNDAR DE c3 DEL MES, CON Y SIN LA CORRIDA. c3 está
--     sellado y no puede saber qué horas pagó cada journal: un mes con
--     journal de nómina no se devenga. Aquí se ve lo que pasa: sin la nómina,
--     el devengo lleva las horas a estándar; al postear la nómina se deshace
--     solo (nada dos veces); y lo trabajado después del período de pago y sin
--     pagar al terminar el mes (LA COLA) no se devenga: se dice.
do $$
declare
  v_obt text; v_c uuid; r jsonb; v_dev uuid; v_cola text; v_plan jsonb; c nomina_corridas; v_m text := pg_temp.c15('mes'); v_x text;
  v_nom text := 'el devengo estándar de c3 con y sin la nómina';
  v_esp text := 'sin la nómina, el devengo estándar del mes lleva sus horas a su tarifa: a 400.00 · b 390.00 · b CO #1 250.00 | al postear la '
                'nómina se deshace solo: lo dice sí, y devengo vivo del mes: no | la mano de obra directa del mes en sus obras, una sola vez: a '
                '1044.27 · b 1450.00 · b CO #1 652.67 | devengar el mes con la nómina dentro: MX008 | la cola (lo trabajado después del período y '
                'sin pagar al terminar el mes): ZZ Ayudante Uno, 6 h, 150.00 a su tarifa; se dice, no se devenga | anulada la nómina, c3 ya no ve '
                'su journal: sí';
begin
  if pg_temp.c15_omitir(19, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    -- (la cola: 6 h de ZZ Ayudante Uno en la obra B el día 22, aprobadas, después del período de pago)
    perform pg_temp.c15_hora(9, 'p1', pg_temp.c15_d(21), 'c15-prueba-b', 6);
    perform pg_temp.c15_ser('dueno');
    perform fn_horas_devengar(v_m);
    perform pg_temp.c15_ser('editor');
    select a.id into v_dev from asientos a
     where a.origen_tabla = 'horas_devengo' and a.origen_id = v_m and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso');
    v_obt := 'sin la nómina, el devengo estándar del mes lleva sus horas a su tarifa: '
             || coalesce((select string_agg(concat_ws(' ', replace(l.proyecto_id, 'c15-prueba-', ''), l.co, l.monto::text), ' · ' order by l.proyecto_id, l.co nulls first)
                            from asiento_lineas l where l.asiento_id = v_dev and l.proyecto_id in ('c15-prueba-a', 'c15-prueba-b')), 'no devengó');
    r := pg_temp.c15_postear(v_c);
    select * into c from nomina_corridas where id = v_c;
    v_obt := v_obt || format(' | al postear la nómina se deshace solo: lo dice %s, y devengo vivo del mes: %s',
      case when r->>'devengo' like '%se deshizo aquí mismo%' then 'sí' else 'no' end,
      case when exists (select 1 from asientos a
                         where a.origen_tabla = 'horas_devengo' and a.origen_id = v_m and a.camino not in ('reverso', 'reverso_automatico')
                           and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')) then 'SÍ' else 'no' end);
    v_obt := v_obt || ' | la mano de obra directa del mes en sus obras, una sola vez: '
             || (select string_agg(concat_ws(' ', replace(q.proyecto_id, 'c15-prueba-', ''), q.co, q.s::text), ' · ' order by q.proyecto_id, q.co nulls first)
                   from (select l.proyecto_id, l.co, sum(l.monto) as s
                           from asiento_lineas l join asientos a on a.id = l.asiento_id
                          where l.cuenta = '5000' and l.proyecto_id in ('c15-prueba-a', 'c15-prueba-b') and a.periodo = v_m
                          group by l.proyecto_id, l.co having sum(l.monto) <> 0) q);
    v_obt := v_obt || format(' | devengar el mes con la nómina dentro: %s', pg_temp.c15_estado(format('select public.fn_horas_devengar(%L)', v_m)));
    perform pg_temp.c15_ser('dueno');
    select string_agg(format('%s, %s h, %s a su tarifa', q.persona, trim_scale(q.horas), q.estandar), '; ') into v_cola
      from fn_nomina_cola(v_m) q where q.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'), pg_temp.c15('p3'));
    perform fn_nomina_anular(v_c, 'C15 PRUEBA: se anula para ver el devengo');
    perform pg_temp.c15_ser('editor');
    v_plan := fn_puente_devengo_plan(v_m);
    v_obt := v_obt || format(' | la cola (lo trabajado después del período y sin pagar al terminar el mes): %s; se dice, no se devenga | anulada la nómina, c3 ya '
                             'no ve su journal: %s', coalesce(v_cola, 'nada'),
      case when not exists (select 1 from jsonb_array_elements_text(coalesce(v_plan->'nomina', '[]'::jsonb)) n(v) where n.v = c.asiento_numero) then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'el devengo estándar de c3 del mes, con y sin la nómina: sin ella, lleva las horas aprobadas a su tarifa; al postear la nómina del mes, el devengo vivo se deshace solo (nada queda dos veces: la mano de obra directa del mes en cada obra es la del journal) y c3 ya no devenga ese mes (MX008); lo trabajado después del período de pago y sin pagar al terminar el mes —la cola— NO se devenga: la capa dice cuánto es; y anulada la nómina, c3 deja de ver su journal',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. ANULAR Y VOLVER A SUBIR: una corrida posteada no se borra; se anula
--     (sus dos asientos se reversan, su lote suelta sus horas) y su archivo
--     se puede volver a importar y postear.
do $$
declare
  v_obt text; v_c uuid; v_c2 uuid; r jsonb; c nomina_corridas; p jsonb; x text; y text;
  v_nom text := 'anular y volver a subir';
  v_esp text := 'descartar una posteada: MX008 | anular sin decir por qué: 22023 | anulada: sí, con sus 2 reversos, y su lote suelta sus 7 horas '
                '| en el libro, sus obras quedan en 0.00 y lo que dejó por pagar en 0.00 | anular otra vez: ya estaba | vuelta a subir: nueva, sin '
                'frenos (su gente ya estaba enlazada) | anular la que solo está importada: MX008 | posteada otra vez: con otro asiento, y su lote '
                'vuelve a tener 7 horas | quedan: 1 anulada y 1 posteada';
begin
  if pg_temp.c15_omitir(20, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    x := pg_temp.c15_estado(format('select public.fn_nomina_descartar(%L, ''C15 PRUEBA'')', v_c));
    y := pg_temp.c15_estado(format('select public.fn_nomina_anular(%L, '' '')', v_c));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_anular(v_c, 'C15 PRUEBA: se subió el archivo que no era');
    perform pg_temp.c15_ser('editor');
    select * into c from nomina_corridas where id = v_c;
    v_obt := format('descartar una posteada: %s | anular sin decir por qué: %s | anulada: %s, con sus %s reversos, y su lote suelta sus %s horas', x, y,
      case when c.estado = 'anulada' then 'sí' else 'no' end,
      (select count(*) from asientos a where a.camino = 'reverso' and a.reversa_a in (c.asiento_id, c.burden_asiento_id) and a.id in (c.reverso_id, c.burden_reverso_id)),
      (select count(*) from nomina_reparto_horas h where h.corrida_id = v_c and not h.vivo));
    v_obt := v_obt || format(' | en el libro, sus obras quedan en %s y lo que dejó por pagar en %s',
      (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.proyecto_id in ('c15-prueba-a', 'c15-prueba-b')),
      (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.asiento_id in (c.asiento_id, c.reverso_id) and l.cuenta like '22%'));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_anular(v_c, 'C15 PRUEBA: otra vez');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | anular otra vez: %s', case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRA' end);
    v_c2 := pg_temp.c15_importar(pg_temp.c15_journal());
    p := pg_temp.c15_propuesta(v_c2);
    v_obt := v_obt || format(' | vuelta a subir: %s, %s (su gente ya estaba enlazada) | anular la que solo está importada: %s',
      case when v_c2 is not null and v_c2 <> v_c then 'nueva' else 'no entró' end,
      case when jsonb_array_length(p->'frenos') = 0 then 'sin frenos' else pg_temp.c15_codigos(p->'frenos') end,
      pg_temp.c15_estado(format('select public.fn_nomina_anular(%L, ''C15 PRUEBA'')', v_c2)));
    r := pg_temp.c15_postear(v_c2);
    v_obt := v_obt || format(' | posteada otra vez: %s, y su lote vuelve a tener %s horas | quedan: %s anulada y %s posteada',
      case when (r->'asiento'->>'id')::uuid <> c.asiento_id then 'con otro asiento' else 'con el mismo' end,
      (select count(*) from nomina_reparto_horas h where h.corrida_id = v_c2 and h.titular and h.vivo),
      (select count(*) from nomina_corridas k where k.id in (v_c, v_c2) and k.estado = 'anulada'),
      (select count(*) from nomina_corridas k where k.id in (v_c, v_c2) and k.estado = 'posteada'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'anular y volver a subir: una corrida posteada no se descarta ni se borra; se anula con su motivo (sus dos asientos se reversan, sus obras y lo que dejó por pagar quedan en cero, su lote suelta sus horas), dos veces es una; su archivo se vuelve a importar como una corrida nueva y se postea otra vez, con las mismas horas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. LA NÓMINA TARDÍA: si el mes de su día de pago ya está cerrado, el
--     asiento entra el primer día del mes abierto (la regla del documento
--     tardío de c3), con su aviso; el amarre con las declaraciones la sigue
--     contando por su día de pago.
do $$
declare
  v_obt text; v_c uuid; r jsonb; p jsonb; c nomina_corridas; v_no text; v_l0 numeric; v_l1 numeric;
  v_m2 date := (select q.desde from periodos q where q.periodo = pg_temp.c15('mes2'));
  v_nom text := 'la nómina tardía';
  v_esp text := format('con el mes de su día de pago cerrado: avisa mes_cerrado y propone el %s | posteada: su asiento es del %s (el primer día del '
                'mes abierto) y su día de pago sigue siendo el %s | el amarre la cuenta en el trimestre de su día de pago: 5808.00 de salarios más',
                v_m2, v_m2, pg_temp.c15_pago());
begin
  if pg_temp.c15_omitir(21, v_nom, v_esp) then return; end if;
  if v_m2 is null then
    insert into _pruebas values (21, v_nom, v_esp, 'omitida: el mes siguiente al de las pruebas no existe o no está abierto', null); return;
  end if;
  begin
    v_c := pg_temp.c15_lista();
    begin
      -- (un mes se cierra a partir del día siguiente a su último día: «hoy» pasa a ser el día 1 del mes siguiente)
      perform pg_temp.c15_fingir_hoy(v_m2);
      perform pg_temp.c15_cerrar_hasta(pg_temp.c15('mes'));
    exception when others then
      v_no := format('el libro no dejó cerrar el mes %s dentro de la prueba (%s: %s)', pg_temp.c15('mes'), sqlstate, left(sqlerrm, 300));
    end;
    if v_no is null then
      select coalesce(sum(a.libro), 0) into v_l0 from fn_nomina_amarre(extract(year from pg_temp.c15_pago())::int) a
       where a.forma = '941' and a.campo = 'salarios' and a.trimestre = extract(quarter from pg_temp.c15_pago())::int;
      p := pg_temp.c15_propuesta(v_c);
      r := pg_temp.c15_postear(v_c);
      select * into c from nomina_corridas where id = v_c;
      select coalesce(sum(a.libro), 0) into v_l1 from fn_nomina_amarre(extract(year from pg_temp.c15_pago())::int) a
       where a.forma = '941' and a.campo = 'salarios' and a.trimestre = extract(quarter from pg_temp.c15_pago())::int;
      v_obt := format('con el mes de su día de pago cerrado: avisa %s y propone el %s | posteada: su asiento es del %s (el primer día del mes abierto) y su '
                      'día de pago sigue siendo el %s | el amarre la cuenta en el trimestre de su día de pago: %s de salarios más',
        (select string_agg(q->>'codigo', ',') from jsonb_array_elements(p->'avisos') q where q->>'codigo' = 'mes_cerrado'),
        p->'fecha_asiento'->>'fecha', (select a.fecha_contable from asientos a where a.id = c.asiento_id), c.dia_pago, v_l1 - v_l0);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if v_no is not null then
    insert into _pruebas values (21, v_nom, v_esp, 'omitida: ' || v_no, null);
  else
    insert into _pruebas values (21, 'la nómina tardía: si el mes de su día de pago ya está cerrado, la propuesta lo avisa y el asiento entra el primer día del mes abierto (la regla del documento tardío de c3); su día de pago no cambia, y el amarre con el 941 la cuenta por ese día',
      v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- =====================================================================
-- EL CARGO DE GUSTO EN EL BANCO
-- =====================================================================
-- 22. EL NETO Y LOS IMPUESTOS, POR SEPARADO: Gusto cobra antes del día de
--     pago, en varios cargos. c6 deja cada uno en la Bandeja esperando su
--     journal; aquí se casa cada uno con lo que la nómina dejó por pagar,
--     al centavo, por la puerta del banco (el movimiento queda casado: la
--     conciliación se confirma como siempre).
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; m2 uuid; m3 uuid; s0 text[]; s1 text[]; a1 uuid; a2 uuid; a3 uuid;
  v_nom text := 'el cargo de Gusto: el neto y los impuestos por separado';
  v_esp text := format('en la Bandeja del banco: 3 pendientes, esperando su journal | la nómina propone: 4874.93 → neto (1 opción) · 1583.31 → '
                'impuestos (1 opción) · 50.00 → deducciones (1 opción) | el del neto, casado: 1010 -4874.93 · 2210 4874.93, con fecha %s | el de '
                'los impuestos: 1010 -1583.31 · 2220 1391.64 · 2225 34.85 · 2230 156.82 | el de las deducciones: 1010 -50.00 · 2240 50.00 | los '
                'tres movimientos: casado, casado, casado (el banco se concilia como siempre) | a la nómina le queda por pagar 0.00 de 6508.24 | '
                'casar uno otra vez: ya estaba | al casarlos, en rojo nuevo en las otras capas: ninguno', pg_temp.c15_d(15));
begin
  if pg_temp.c15_omitir(22, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    m1 := pg_temp.c15_cargo('c15-t22-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 6semk7 C15 PRUEBA');
    m2 := pg_temp.c15_cargo('c15-t22-tax', pg_temp.c15_d(15), 1583.31, 'GUSTO TAX 6semk7 C15 PRUEBA');
    m3 := pg_temp.c15_cargo('c15-t22-csd', pg_temp.c15_d(15), 50.00, 'GUSTO CSD 6semk7 C15 PRUEBA');
    -- (lo que ya está en rojo con los tres cargos en el banco y sin casar: un movimiento nuevo del mes pide, por ejemplo, su conciliación)
    s0 := pg_temp.c15_rojos();
    v_obt := format('en la Bandeja del banco: %s pendientes, esperando su journal',
                    (select count(*) from movimientos_banco m where m.id in (m1, m2, m3) and m.estado = 'pendiente' and m.estado_motivo = 'nomina'));
    perform pg_temp.c15_ser('dueno');
    select v_obt || ' | la nómina propone: ' || string_agg(format('%s → %s (%s opción)', g.monto, g.clase_probable, g.opciones), ' · ' order by g.monto desc)
      into v_obt from v_nomina_cargos g where g.movimiento_id in (m1, m2, m3) and g.estado = 'pendiente';
    perform pg_temp.c15_ser('editor');
    perform pg_temp.c15_casar(m1); perform pg_temp.c15_casar(m2); perform pg_temp.c15_casar(m3);
    select g.asiento_id into a1 from nomina_pagos g where g.movimiento_id = m1 and g.estado = 'aplicado';
    select g.asiento_id into a2 from nomina_pagos g where g.movimiento_id = m2 and g.estado = 'aplicado';
    select g.asiento_id into a3 from nomina_pagos g where g.movimiento_id = m3 and g.estado = 'aplicado';
    v_obt := v_obt || format(' | el del neto, casado: %s, con fecha %s | el de los impuestos: %s | el de las deducciones: %s',
                             pg_temp.c15_asiento(a1), (select a.fecha_contable from asientos a where a.id = a1), pg_temp.c15_asiento(a2), pg_temp.c15_asiento(a3));
    v_obt := v_obt || format(' | los tres movimientos: %s (el banco se concilia como siempre)',
                             (select string_agg(m.estado, ', ') from movimientos_banco m where m.id in (m1, m2, m3)));
    perform pg_temp.c15_ser('dueno');
    select v_obt || format(' | a la nómina le queda por pagar %s de %s', k.por_pagar, k.por_pagar + k.pagado) into v_obt from v_nomina_corridas k where k.corrida_id = v_c;
    perform pg_temp.c15_ser('editor');
    r := pg_temp.c15_casar(m2, '[]'::jsonb || jsonb_build_object('corrida', v_c, 'cuenta', '2220', 'monto', '1.00'));
    s1 := pg_temp.c15_rojos();
    v_obt := v_obt || format(' | casar uno otra vez: %s | al casarlos, en rojo nuevo en las otras capas: %s', case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRO' end,
                             pg_temp.c15_nuevos(s0, s1));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'el cargo de Gusto en el banco, el neto y los impuestos por separado: c6 deja cada cargo en la Bandeja esperando su journal; la nómina propone para cada uno lo que paga, al centavo, y al casarlo el banco pone su asiento en la fecha del cargo (Dr 2210 / 2220, 2225 y 2230 / 2240, Cr el banco) y deja el movimiento casado; a la nómina no le queda nada por pagar, y ninguna otra capa pasa a rojo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. UN CARGO PARA DOS CORRIDAS: la regular y un bono fuera de ciclo del
--     mismo día. Gusto cobra los impuestos de las dos en un cargo (y el neto
--     en otro). El bono usa las horas del período de clave, sin quedárselas.
do $$
declare
  v_obt text; v_c uuid; v_b uuid; r jsonb; m1 uuid; m2 uuid; p jsonb; cb nomina_corridas;
  v_nom text := 'un cargo de Gusto para dos corridas';
  v_esp text := 'el bono: fuera_de_ciclo, no se queda con las horas; su sueldo (500.00) por las mismas 30 h: 5000 a 266.67 · 5000 b CO #1 166.67 '
                '· 6000 66.66; ninguna hora queda en dos nóminas: sí | un cargo por los impuestos de las dos (1726.31): 1 opción, de 2 nóminas | '
                'casado: 1010 -1726.31 · 2220 1518.14 · 2225 37.85 · 2230 170.32 | un cargo por el neto de las dos (5286.68): 1 opción, de 2 '
                'nóminas; casado: 1010 -5286.68 · 2210 5286.68 | les queda por pagar: 50.00 (las deducciones de la regular) y 0.00';
begin
  if pg_temp.c15_omitir(23, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    v_b := pg_temp.c15_importar(pg_temp.c15_bono(), 'zz-c15-prueba-bono.csv');
    r := pg_temp.c15_postear(v_b);
    select * into cb from nomina_corridas where id = v_b;
    v_obt := format('el bono: %s, %s; su sueldo (%s) por las mismas %s h: %s; ninguna hora queda en dos nóminas: %s', cb.tipo,
      case when cb.toma_horas then 'SE QUEDA con las horas' else 'no se queda con las horas' end, cb.bruto,
      (select trim_scale(sum(h.horas)) from nomina_reparto_horas h where h.corrida_id = v_b),
      (select string_agg(concat_ws(' ', l.cuenta, replace(l.proyecto_id, 'c15-prueba-', ''), l.co, l.monto::text), ' · ' order by l.orden)
         from asiento_lineas l where l.asiento_id = cb.asiento_id and l.cuenta in ('5000', '6000')),
      case when not exists (select 1 from nomina_reparto_horas h where h.titular and h.vivo and h.corrida_id in (v_c, v_b)
                             group by h.horas_id having count(*) > 1)
                and not exists (select 1 from nomina_reparto_horas h where h.corrida_id = v_b and h.titular) then 'sí' else 'no' end);
    m1 := pg_temp.c15_cargo('c15-t23-tax', pg_temp.c15_d(15), 1726.31, 'GUSTO TAX 6semk7 C15 PRUEBA');
    perform pg_temp.c15_ser('dueno');
    p := fn_nomina_cargo_propuesta(m1);
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | un cargo por los impuestos de las dos (1726.31): %s opción, de %s nóminas', jsonb_array_length(p->'opciones'),
                             jsonb_array_length(p->'opciones'->0->'corridas'));
    r := pg_temp.c15_casar(m1);
    v_obt := v_obt || format(' | casado: %s', pg_temp.c15_asiento((select g.asiento_id from nomina_pagos g where g.movimiento_id = m1 and g.estado = 'aplicado')));
    m2 := pg_temp.c15_cargo('c15-t23-net', pg_temp.c15_d(15), 5286.68, 'GUSTO NET 6semk7 C15 PRUEBA');
    perform pg_temp.c15_ser('dueno');
    p := fn_nomina_cargo_propuesta(m2);
    perform pg_temp.c15_ser('editor');
    r := pg_temp.c15_casar(m2);
    v_obt := v_obt || format(' | un cargo por el neto de las dos (5286.68): %s opción, de %s nóminas; casado: %s', jsonb_array_length(p->'opciones'),
                             jsonb_array_length(p->'opciones'->0->'corridas'),
                             pg_temp.c15_asiento((select g.asiento_id from nomina_pagos g where g.movimiento_id = m2 and g.estado = 'aplicado')));
    perform pg_temp.c15_ser('dueno');
    v_obt := v_obt || format(' | les queda por pagar: %s (las deducciones de la regular) y %s',
                             (select sum(q.pendiente) from fn_nomina_pendiente(v_c) q), (select sum(q.pendiente) from fn_nomina_pendiente(v_b) q));
    perform pg_temp.c15_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'un cargo de Gusto para dos corridas: una nómina regular y un bono fuera de ciclo del mismo día de pago (el bono reparte su sueldo por las mismas horas del período sin quedárselas: ninguna hora queda en dos nóminas); Gusto cobra los impuestos de las dos en un cargo y el neto en otro, y cada cargo se casa con lo que las dos dejaron por pagar, al centavo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. UN CARGO QUE NO CASA AL CENTAVO no se casa solo: se dice con las dos
--     cifras. Las partes de un cargo suman el cargo y ninguna paga de más.
--     Y deshacer devuelve el cargo a la Bandeja.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; p jsonb; v_e text; v_pago uuid; x text;
  v_nom text := 'un cargo de Gusto que no casa';
  v_esp text := 'un cargo de 1583.30 (un centavo menos que los impuestos): 0 opciones, y lo dice con las dos cifras ($1,583.30 y los $1,391.64 '
                'de 2220): sí | con partes que suman otra cosa: MX001, y dice las dos cifras: sí | pagándole de más a una cuenta: MX008 | a una '
                'cuenta que la nómina no debe: MX008 | a una corrida que no existe: MX008 | diciendo Edgar qué paga (el reempleo, con un centavo '
                'menos): casa, y quedan por pagar 0.01 en 2230 | anular la nómina con un cargo casado: MX008 | deshacerlo sin decir por qué: '
                '22023 | deshecho: el cargo vuelve a la Bandeja (pendiente, nomina), el pago queda deshecho con su reverso, y a 2230 le vuelven '
                'a faltar 156.82 | deshacerlo otra vez: ya estaba';
begin
  if pg_temp.c15_omitir(24, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    m1 := pg_temp.c15_cargo('c15-t24-tax', pg_temp.c15_d(15), 1583.30, 'GUSTO TAX 6semk7 C15 PRUEBA');
    perform pg_temp.c15_ser('dueno');
    p := fn_nomina_cargo_propuesta(m1);
    perform pg_temp.c15_ser('editor');
    v_obt := format('un cargo de 1583.30 (un centavo menos que los impuestos): %s opciones, y lo dice con las dos cifras ($1,583.30 y los $1,391.64 de 2220): %s',
                    jsonb_array_length(p->'opciones'), case when p->>'texto' like '%$1,583.30%no casa al centavo%$1,391.64 en 2220%' then 'sí' else 'no' end);
    v_e := pg_temp.c15_dice(format('select public.fn_nomina_cargo_casar(%L, %L::jsonb)', m1, jsonb_build_array(
             jsonb_build_object('corrida', v_c, 'cuenta', '2220', 'monto', '1391.64'), jsonb_build_object('corrida', v_c, 'cuenta', '2225', 'monto', '34.85'),
             jsonb_build_object('corrida', v_c, 'cuenta', '2230', 'monto', '156.82'))));
    v_obt := v_obt || format(' | con partes que suman otra cosa: %s, y dice las dos cifras: %s', left(v_e, 5),
                             case when v_e like '%$1,583.31%$1,583.30%' then 'sí' else 'no' end);
    v_obt := v_obt || format(' | pagándole de más a una cuenta: %s | a una cuenta que la nómina no debe: %s | a una corrida que no existe: %s',
      pg_temp.c15_estado(format('select public.fn_nomina_cargo_casar(%L, %L::jsonb)', m1, jsonb_build_array(jsonb_build_object('corrida', v_c, 'cuenta', '2220', 'monto', '1583.30')))),
      pg_temp.c15_estado(format('select public.fn_nomina_cargo_casar(%L, %L::jsonb)', m1, jsonb_build_array(jsonb_build_object('corrida', v_c, 'cuenta', '6500', 'monto', '1583.30')))),
      pg_temp.c15_estado(format('select public.fn_nomina_cargo_casar(%L, %L::jsonb)', m1, jsonb_build_array(jsonb_build_object('corrida', gen_random_uuid(), 'cuenta', '2220', 'monto', '1583.30')))));
    r := pg_temp.c15_casar(m1, jsonb_build_array(
           jsonb_build_object('corrida', v_c, 'cuenta', '2220', 'monto', '1391.64'), jsonb_build_object('corrida', v_c, 'cuenta', '2225', 'monto', '34.85'),
           jsonb_build_object('corrida', v_c, 'cuenta', '2230', 'monto', '156.81')));
    v_pago := (r->>'pago')::uuid;
    v_obt := v_obt || format(' | diciendo Edgar qué paga (el reempleo, con un centavo menos): %s, y quedan por pagar %s en %s',
      case when r->>'asiento' is not null then 'casa' else 'no casa' end,
      (select q->>'pendiente' from jsonb_array_elements(r->'queda_por_pagar') q where q->>'cuenta' = '2230'),
      (select q->>'cuenta' from jsonb_array_elements(r->'queda_por_pagar') q where q->>'cuenta' = '2230'));
    v_obt := v_obt || format(' | anular la nómina con un cargo casado: %s | deshacerlo sin decir por qué: %s',
      pg_temp.c15_estado(format('select public.fn_nomina_anular(%L, ''C15 PRUEBA'')', v_c)),
      pg_temp.c15_estado(format('select public.fn_nomina_cargo_deshacer(%L, '''')', v_pago)));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_deshacer(v_pago, 'C15 PRUEBA: no era de esta nómina');
    x := (select q.pendiente::text from fn_nomina_pendiente(v_c) q where q.cuenta = '2230');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | deshecho: el cargo vuelve a la Bandeja (%s), el pago queda %s con su reverso, y a 2230 le vuelven a faltar %s',
      (select m.estado || ', ' || coalesce(m.estado_motivo, '-') from movimientos_banco m where m.id = m1),
      (select g.estado || case when g.reverso_id is null then ' SIN' else '' end from nomina_pagos g where g.id = v_pago), x);
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_deshacer(v_pago, 'C15 PRUEBA: otra vez');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | deshacerlo otra vez: %s', case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRO' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'un cargo de Gusto que no casa al centavo no se casa solo: la propuesta no da opciones y lo dice con las dos cifras; las partes de un cargo tienen que sumar el cargo (MX001, con las dos cifras) y ninguna paga más de lo que la nómina dejó por pagar en esa cuenta (MX008); si Edgar dice qué paga, casa y dice lo que queda; una nómina con cargos casados no se anula; y deshacer devuelve el cargo a la Bandeja',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. LA CUOTA MENSUAL DE GUSTO NO ES NÓMINA: c6 la atrapa por «GUSTO» y la
--     deja en la Bandeja; desde aquí sale a su gasto (6500), con su motivo.
do $$
declare
  v_obt text; r jsonb; m1 uuid; p jsonb; v_as uuid;
  v_nom text := 'la cuota de Gusto no es nómina';
  v_esp text := 'en la Bandeja: pendiente, nomina | la nómina dice: cuota, «Parece la cuota mensual de Gusto ($67.00): no es nómina; va a su '
                'gasto (6500).» | resuelta: 1010 -67.00 · 6500 67.00; el movimiento: casado; en la lista de cargos: cuota | otra vez: ya estaba | '
                'no pagó nada de ninguna nómina: sí';
begin
  if pg_temp.c15_omitir(25, v_nom, v_esp, true) then return; end if;
  begin
    perform pg_temp.c15_sembrar(false);
    m1 := pg_temp.c15_cargo('c15-t25-fee', pg_temp.c15_d(2), 67.00, 'GUSTO FEE 6semk7 C15 PRUEBA');
    perform pg_temp.c15_ser('dueno');
    p := fn_nomina_cargo_propuesta(m1);
    perform pg_temp.c15_ser('editor');
    v_obt := format('en la Bandeja: %s | la nómina dice: %s, «%s»', (select m.estado || ', ' || coalesce(m.estado_motivo, '-') from movimientos_banco m where m.id = m1),
                    p->>'clase_probable', p->>'texto');
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_cuota(m1, 'C15 PRUEBA');
    perform pg_temp.c15_ser('editor');
    select g.asiento_id into v_as from nomina_pagos g where g.id = (r->>'pago')::uuid;
    v_obt := v_obt || format(' | resuelta: %s; el movimiento: %s; en la lista de cargos: %s', pg_temp.c15_asiento(v_as),
                             (select m.estado from movimientos_banco m where m.id = m1),
                             pg_temp.c15_da(format('select estado from public.v_nomina_cargos where movimiento_id = %L', m1)));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_cuota(m1);
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | otra vez: %s | no pagó nada de ninguna nómina: %s', case when (r->>'ya_estaba')::boolean then 'ya estaba' else 'OTRA' end,
                             case when not exists (select 1 from nomina_pago_partes pp join nomina_pagos g on g.id = pp.pago_id where g.movimiento_id = m1) then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'la cuota mensual de Gusto no es nómina: el banco la deja en la Bandeja con los cargos de Gusto; la nómina la reconoce por su descripción y la manda a su gasto (6500) por la puerta del banco, con su motivo; el movimiento queda casado y no paga nada de ninguna corrida',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. EL AUXILIAR DE LAS CUENTAS POR PAGAR DE LA NÓMINA A UNA FECHA (para la
--     cédula de corte, c13): lo que cada corrida dejó por pagar menos lo que
--     sus cargos pagaron, ese día. Entre el cargo de Gusto y el día de pago
--     el saldo es al revés (Gusto ya cobró lo que el libro todavía no debe).
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; m2 uuid; c nomina_corridas; v_ok boolean;
  v_nom text := 'el auxiliar de las cuentas por pagar de la nómina a una fecha';
  v_esp text := 'la víspera del primer cargo: nada | entre los cargos y el día de pago (Gusto ya cobró): 2210 -4874.93 · 2220 -1391.64 · 2225 '
                '-34.85 · 2230 -156.82 | el día de pago: 2240 50.00 | y cada día es lo que dice el libro en los asientos de esta nómina: sí';
begin
  if pg_temp.c15_omitir(26, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    select * into c from nomina_corridas where id = v_c;
    m1 := pg_temp.c15_cargo('c15-t26-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 6semk7 C15 PRUEBA');
    m2 := pg_temp.c15_cargo('c15-t26-tax', pg_temp.c15_d(15), 1583.31, 'GUSTO TAX 6semk7 C15 PRUEBA');
    perform pg_temp.c15_casar(m1); perform pg_temp.c15_casar(m2);
    perform pg_temp.c15_ser('dueno');
    v_obt := format('la víspera del primer cargo: %s | entre los cargos y el día de pago (Gusto ya cobró): %s | el día de pago: %s',
      coalesce((select string_agg(a.cuenta || ' ' || a.saldo, ' · ' order by a.cuenta) from fn_nomina_auxiliar(pg_temp.c15_d(14)) a where a.corrida_id = v_c), 'nada'),
      coalesce((select string_agg(a.cuenta || ' ' || a.saldo, ' · ' order by a.cuenta) from fn_nomina_auxiliar(pg_temp.c15_d(16)) a where a.corrida_id = v_c), 'nada'),
      coalesce((select string_agg(a.cuenta || ' ' || a.saldo, ' · ' order by a.cuenta) from fn_nomina_auxiliar(pg_temp.c15_pago()) a where a.corrida_id = v_c), 'nada'));
    -- (contra el libro: el saldo acreedor de cada cuenta en los asientos de esta nómina —su journal y sus cargos—, a cada fecha)
    select bool_and(coalesce(x.aux, 0) = coalesce(x.libro, 0)) into v_ok
      from (select d.f, k.cuenta,
                   (select sum(a.saldo) from fn_nomina_auxiliar(d.f) a where a.corrida_id = v_c and a.cuenta = k.cuenta) as aux,
                   (select -sum(l.monto) from asiento_lineas l join asientos s on s.id = l.asiento_id
                     where l.cuenta = k.cuenta and s.fecha_contable <= d.f
                       and s.id in (select c.asiento_id union all select g.asiento_id from nomina_pagos g where g.movimiento_id in (m1, m2))) as libro
              from (values (pg_temp.c15_d(14)), (pg_temp.c15_d(16)), (pg_temp.c15_pago())) d(f)
              cross join (values ('2210'), ('2220'), ('2225'), ('2230'), ('2240')) k(cuenta)) x;
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | y cada día es lo que dice el libro en los asientos de esta nómina: %s', case when v_ok then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'el auxiliar de 2210, 2220, 2225, 2230 y 2240 a una fecha (para la cédula de corte): por corrida, lo que su journal dejó por pagar menos lo que sus cargos de Gusto pagaron hasta ese día; entre el cargo y el día de pago sale al revés (Gusto ya cobró), y a cada fecha es, al centavo, lo que dice el libro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- EL AMARRE Y LAS HORAS PARA GUSTO
-- =====================================================================
-- 27. EL AMARRE CON EL 941, EL 940 Y EL RT-6: Edgar teclea los totales de
--     cada declaración y la base los compara con lo posteado por día de
--     pago. Lo que no amarra, un aviso con las dos cifras.
do $$
declare
  v_obt text; v_c uuid; r jsonb; v_y int := extract(year from pg_temp.c15_pago())::int; v_q int := extract(quarter from pg_temp.c15_pago())::int;
  l0 jsonb; l1 jsonb; v_d text; v_ras bigint;
  v_nom text := 'el amarre con el 941, el 940 y el RT-6';
  v_esp text := 'lo que esta nómina suma a lo posteado de su trimestre y de su año: 941 salarios 5808.00, retención 503.00, Social Security y '
                'Medicare 888.64 · RT-6 contribución 156.82 · 940 FUTA 34.85 | el 941 tecleado como dice el libro: amarran 3 de 3 | el 940 con '
                '4.85 de menos en el FUTA: no amarra, y lo dice con las dos cifras: sí | el RT-6 con 0.50 de más: amarra (dentro de la tolerancia) '
                '| el control: rojo, y nombra el 940: sí | tecleado bien el 940: verde, y la anterior queda como rastro: 1 | un renglón que no es '
                'de esa forma: 22023 | el 940 con trimestre: 22023 | un monto que no es un número: MX005 | sin el código del teléfono: PGRST MFA '
                '| quitar una: sí';
begin
  if pg_temp.c15_omitir(27, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    perform pg_temp.c15_ser('dueno');
    select coalesce(jsonb_object_agg(a.forma || '.' || a.campo, a.libro), '{}'::jsonb) into l0 from fn_nomina_amarre(v_y) a
     where coalesce(a.trimestre, v_q) = v_q;
    perform pg_temp.c15_ser('editor');
    r := pg_temp.c15_postear(v_c);
    perform pg_temp.c15_ser('dueno');
    select jsonb_object_agg(a.forma || '.' || a.campo, a.libro) into l1 from fn_nomina_amarre(v_y) a where coalesce(a.trimestre, v_q) = v_q;
    v_obt := format('lo que esta nómina suma a lo posteado de su trimestre y de su año: 941 salarios %s, retención %s, Social Security y Medicare %s · RT-6 '
                    'contribución %s · 940 FUTA %s',
      ((l1->>'941.salarios')::numeric - coalesce((l0->>'941.salarios')::numeric, 0))::numeric(14,2),
      ((l1->>'941.retencion')::numeric - coalesce((l0->>'941.retencion')::numeric, 0))::numeric(14,2),
      ((l1->>'941.ss_medicare')::numeric - coalesce((l0->>'941.ss_medicare')::numeric, 0))::numeric(14,2),
      ((l1->>'rt6.contribucion')::numeric - coalesce((l0->>'rt6.contribucion')::numeric, 0))::numeric(14,2),
      ((l1->>'940.futa')::numeric - coalesce((l0->>'940.futa')::numeric, 0))::numeric(14,2));
    r := fn_nomina_declaracion(jsonb_build_object('forma', '941', 'anio', v_y, 'trimestre', v_q, 'salarios', l1->>'941.salarios',
                                                  'retencion', l1->>'941.retencion', 'ss_medicare', l1->>'941.ss_medicare'));
    v_obt := v_obt || format(' | el 941 tecleado como dice el libro: amarran %s de 3', (select count(*) from jsonb_array_elements(r->'amarre') q where (q->>'ok')::boolean));
    r := fn_nomina_declaracion(jsonb_build_object('forma', '940', 'anio', v_y, 'salarios', l1->>'940.salarios',
                                                  'futa', ((l1->>'940.futa')::numeric - 4.85)::text));
    select q->>'detalle' into v_d from jsonb_array_elements(r->'amarre') q where q->>'campo' = 'futa';
    v_obt := v_obt || format(' | el 940 con 4.85 de menos en el FUTA: %s, y lo dice con las dos cifras: %s',
      case when v_d like '%NO amarra%' then 'no amarra' else 'amarra' end,
      case when v_d like '%' || fn_nomina_usd((l1->>'940.futa')::numeric - 4.85) || '%' || fn_nomina_usd((l1->>'940.futa')::numeric) || '%diferencia -$4.85%' then 'sí' else 'no' end);
    r := fn_nomina_declaracion(jsonb_build_object('forma', 'rt6', 'anio', v_y, 'trimestre', v_q, 'salarios', l1->>'rt6.salarios',
                                                  'contribucion', ((l1->>'rt6.contribucion')::numeric + 0.50)::text));
    v_obt := v_obt || format(' | el RT-6 con 0.50 de más: %s (dentro de la tolerancia)',
      case when (select bool_and((q->>'ok')::boolean) from jsonb_array_elements(r->'amarre') q) then 'amarra' else 'no amarra' end);
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | el control: %s, y nombra el 940: %s', pg_temp.c15_ctl(65),
                             case when pg_temp.c15_nombra(pg_temp.c15_ctl_det(65), '%El 940 de ' || v_y || ', FUTA: NO amarra%') then 'sí' else 'no' end);
    select count(*) into v_ras from nomina_declaraciones d where not d.vigente;
    perform pg_temp.c15_estado(format('select public.fn_nomina_declaracion(%L::jsonb)',
              jsonb_build_object('forma', '940', 'anio', v_y, 'salarios', l1->>'940.salarios', 'futa', l1->>'940.futa')));
    v_obt := v_obt || format(' | tecleado bien el 940: %s, y la anterior queda como rastro: %s', pg_temp.c15_vuelve(65, '%El 940 de ' || v_y || ', FUTA: NO amarra%'),
                             (select count(*) from nomina_declaraciones d where not d.vigente) - v_ras);
    v_obt := v_obt || format(' | un renglón que no es de esa forma: %s | el 940 con trimestre: %s | un monto que no es un número: %s | sin el código del teléfono: %s | quitar una: %s',
      pg_temp.c15_estado(format('select public.fn_nomina_declaracion(''{"forma": "941", "anio": %s, "trimestre": %s, "futa": "1.00"}''::jsonb)', v_y, v_q)),
      pg_temp.c15_estado(format('select public.fn_nomina_declaracion(''{"forma": "940", "anio": %s, "trimestre": 1, "futa": "1.00"}''::jsonb)', v_y)),
      pg_temp.c15_estado(format('select public.fn_nomina_declaracion(''{"forma": "rt6", "anio": %s, "trimestre": %s, "salarios": "abc"}''::jsonb)', v_y, v_q)),
      pg_temp.c15_estado(format('select public.fn_nomina_declaracion(''{"forma": "940", "anio": %s, "futa": "1.00"}''::jsonb)', v_y), 'dueno_aal1'),
      case when pg_temp.c15_da(format('select public.fn_nomina_declaracion(''{"forma": "rt6", "anio": %s, "trimestre": %s, "quitar": true}''::jsonb)->>''quitada''', v_y, v_q)) = 'true'
           then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'el amarre con las declaraciones: lo posteado por DÍA DE PAGO en el trimestre (941: salarios, retención federal, Social Security y Medicare; RT-6: contribución) y en el año (940: FUTA); Edgar teclea los totales de cada declaración: lo que coincide amarra (con su tolerancia), lo que no es un aviso con las dos cifras y pone el control en rojo; corregir es teclearla otra vez, y la anterior queda como rastro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. LAS HORAS PARA GUSTO: las aprobadas de un período por persona y semana
--     laboral (total, regulares hasta 40 y extra), en tabla y en CSV; el
--     lote queda guardado y, si después cambia una hora suya o se aprueba
--     otra del período, el control lo avisa. Quien cobra sueldo fijo no va.
do $$
declare
  v_obt text; v_c uuid; r jsonb; v_l date; v_lote uuid; v_csv text; x text; y text;
  v_nom text := 'las horas para Gusto';
  v_esp text := 'ZZ Ayudante Uno: 45 h = 40 regulares + 5 extra · 8 h = 8 regulares + 0 extra | ZZ Ayudante Dos: 8 h = 8 regulares + 0 extra, y '
                '5 h sin aprobar que no van | el oficial (sueldo fijo) sale en la tabla con sus 10 h, marcado, y no va al lote: sí | el CSV: '
                '"ZZ Ayudante Uno",48,5,53 y "ZZ Ayudante Dos",8,0,8, con su período (mes/día/año); sin el oficial: sí | avisa las horas sin '
                'aprobar y las de sueldo fijo: sí | el lote guardó sus 7 reportes, y sus 3 semanas como quedaron | un período que empieza a '
                'media semana (miércoles): 27 h = 22 regulares + 5 extra (con 18 h de antes del período) · 8 h = 8 regulares + 0 extra | con la '
                'semana empezando el miércoles: 18 h y 35 h, sin extra | después cambia '
                'una hora del lote y se aprueba otra: 1 cambiada y 1 nueva (5 h); el control: rojo, y lo nombra: sí | armado otra vez: verde, y '
                'el lote anterior queda como rastro: sí | un período sin horas aprobadas: MX008';
begin
  if pg_temp.c15_omitir(28, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista(false);
    -- (el primer lunes del mes de las pruebas; las horas, de lunes a viernes de esa semana y el lunes siguiente)
    v_l := pg_temp.c15_d(0) + ((8 - extract(isodow from pg_temp.c15_d(0))::int) % 7);
    perform pg_temp.c15_ser('editor');
    perform pg_temp.c15_hora(11, 'p1', v_l,     'c15-prueba-a', 9); perform pg_temp.c15_hora(12, 'p1', v_l + 1, 'c15-prueba-a', 9);
    perform pg_temp.c15_hora(13, 'p1', v_l + 2, 'c15-prueba-a', 9); perform pg_temp.c15_hora(14, 'p1', v_l + 3, 'c15-prueba-b', 9);
    perform pg_temp.c15_hora(15, 'p1', v_l + 4, 'c15-prueba-b', 9); perform pg_temp.c15_hora(16, 'p1', v_l + 7, 'c15-prueba-b', 8);
    perform pg_temp.c15_hora(17, 'p2', v_l,     'c15-prueba-a', 8); perform pg_temp.c15_hora(18, 'p2', v_l + 1, 'c15-prueba-a', 5, false);
    perform pg_temp.c15_hora(19, 'p3', v_l,     'c15-prueba-a', 10);
    perform pg_temp.c15_ser('dueno');
    select format('ZZ Ayudante Uno: %s | ZZ Ayudante Dos: %s, y %s h sin aprobar que no van | el oficial (sueldo fijo) sale en la tabla con sus %s h, marcado, y no va al lote: %s',
             (select string_agg(format('%s h = %s regulares + %s extra', trim_scale(g.horas), trim_scale(g.regulares), trim_scale(g.extra)), ' · ' order by g.semana_desde)
                from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p1')),
             (select string_agg(format('%s h = %s regulares + %s extra', trim_scale(g.horas), trim_scale(g.regulares), trim_scale(g.extra)), ' · ' order by g.semana_desde)
                from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p2')),
             (select trim_scale(sum(g.sin_aprobar)) from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p2')),
             (select trim_scale(sum(g.horas)) from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p3')),
             case when (select bool_and(not g.por_horas) from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p3')) then 'sí' else 'no' end)
      into v_obt;
    r := fn_nomina_lote(v_l, v_l + 13, 'C15 PRUEBA');
    v_lote := (r->>'lote')::uuid;
    v_csv := r->>'csv';
    v_obt := v_obt || format(' | el CSV: "ZZ Ayudante Uno",48,5,53 y "ZZ Ayudante Dos",8,0,8, con su período (mes/día/año); sin el oficial: %s | avisa las horas sin aprobar y las de sueldo fijo: %s | el lote guardó sus %s reportes, y sus %s semanas como quedaron',
      case when v_csv like E'Employee name,Regular hours,Overtime hours,Total hours,Pay period start,Pay period end\n%'
                and v_csv like '%"ZZ Ayudante Uno",48,5,53,' || pg_temp.c15_us(v_l) || ',' || pg_temp.c15_us(v_l + 13) || E'\n%'
                and v_csv like '%"ZZ Ayudante Dos",8,0,8,' || pg_temp.c15_us(v_l) || ',' || pg_temp.c15_us(v_l + 13) || E'\n%'
                and v_csv not like '%ZZ Oficial Tres%' and v_csv = fn_nomina_lote_csv(v_lote) then 'sí' else 'no' end,
      case when pg_temp.c15_codigos(r->'avisos') like '%sin_aprobar%' and pg_temp.c15_codigos(r->'avisos') like '%sueldo_fijo%' then 'sí' else 'no' end,
      (select count(*) from nomina_lote_horas lh where lh.lote_id = v_lote and lh.horas_id between -1510000099 and -1510000001),
      (select jsonb_array_length(l.semanas) from nomina_lotes l where l.id = v_lote));
    -- (un período que empieza el miércoles con la semana empezando el lunes: las 18 h del lunes y el martes ya gastaron su parte de las 40)
    select v_obt || ' | un período que empieza a media semana (miércoles): '
           || string_agg(format('%s h = %s regulares + %s extra%s', trim_scale(g.horas), trim_scale(g.regulares), trim_scale(g.extra),
                                case when g.horas_antes > 0 then format(' (con %s h de antes del período)', trim_scale(g.horas_antes)) else '' end),
                         ' · ' order by g.semana_desde)
      into v_obt from fn_nomina_horas_gusto(v_l + 2, v_l + 15) g where g.usuario_id::text = pg_temp.c15('p1');
    perform fn_nomina_config('{"semana_empieza": 3}');
    select v_obt || ' | con la semana empezando el miércoles: ' || string_agg(trim_scale(g.horas) || ' h', ' y ' order by g.semana_desde)
           || case when sum(g.extra) = 0 then ', sin extra' else ', CON extra' end
      into v_obt from fn_nomina_horas_gusto(v_l, v_l + 13) g where g.usuario_id::text = pg_temp.c15('p1');
    perform fn_nomina_config('{"semana_empieza": 1}');
    -- (después: Edgar corrige una hora del lote —pierde su aprobación— y aprueba las 5 h que faltaban)
    perform pg_temp.c15_ser('editor');
    if pg_temp.c15_estado('update public.horas set horas = 7 where id = -1510000011') <> 'ok' then   -- (como el dueño, desde la app)
      raise exception 'c15-pruebas: la base no dejó al dueño corregir una hora de prueba';
    end if;
    update horas set aprobado_por = pg_temp.c15('dueno')::uuid, aprobado_el = now() where id = -1510000018;
    select format('%s cambiada y %s nueva (%s h)', v.cambiadas, v.nuevas, trim_scale(v.nuevas_horas)) into x from v_nomina_lotes v where v.lote_id = v_lote and v.cambio;
    v_obt := v_obt || format(' | después cambia una hora del lote y se aprueba otra: %s; el control: %s, y lo nombra: %s', coalesce(x, 'sin cambio'), pg_temp.c15_ctl(70),
                             case when pg_temp.c15_nombra(pg_temp.c15_ctl_det(70), '%el del ' || fn_nomina_dia(v_l) || ' al ' || fn_nomina_dia(v_l + 13) || '%') then 'sí' else 'no' end);
    perform pg_temp.c15_estado(format('select public.fn_nomina_lote(%L, %L, ''C15 PRUEBA: otra vez'')', v_l, v_l + 13));
    v_obt := v_obt || format(' | armado otra vez: %s, y el lote anterior queda como rastro: %s | un período sin horas aprobadas: %s',
      pg_temp.c15_vuelve(70, '%el del ' || fn_nomina_dia(v_l) || ' al ' || fn_nomina_dia(v_l + 13) || '%'),
      case when (select not l.vigente from nomina_lotes l where l.id = v_lote) then 'sí' else 'no' end,
      pg_temp.c15_estado('select public.fn_nomina_lote(''2099-01-04'', ''2099-01-10'')'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'las horas para Gusto: las aprobadas de un período por persona y semana laboral (total, regulares hasta 40 y extra, semana por semana; el día en que empieza la semana, de la configuración), en tabla y en CSV; las sin aprobar no van, y quien cobra sueldo fijo tampoco; el lote queda guardado, y si después cambia una hora suya o se aprueba otra del período el control lo avisa hasta que se arma otra vez',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- LAS FORMAS DEL ARCHIVO Y LO QUE AVISA LA PROPUESTA
-- =====================================================================
-- 29. EL ARCHIVO, COMO VENGA. Gusto baja el «Payroll journal» de más de una
--     forma y todavía no hay uno real para confirmarla: el lector no supone
--     una. Con preámbulo y la fecha del cheque arriba; por secciones (el
--     resumen por empleado y, en otra parte, el detalle de lo patronal) y
--     con el nombre como «Apellido, Nombre»; con el resumen y el detalle de
--     la MISMA nómina (cada concepto, una vez); con las dos partes diciendo
--     cifras distintas (no cuadra); con dos nóminas el mismo día y filas que
--     no dicen de cuál son (MX009: no se adivina); con el neto que ya trae
--     el reembolso; con las fechas con el nombre del mes, el período en una
--     celda y una fila en cero; y sin el día de pago (MX009, hasta que se
--     dice).
do $$
declare
  v_obt text; r jsonb; c jsonb; v text; d0 text := pg_temp.c15_us(pg_temp.c15_d(0)); d13 text := pg_temp.c15_us(pg_temp.c15_d(13));
  dp text := pg_temp.c15_us(pg_temp.c15_pago()); mp text := to_char(pg_temp.c15_pago(), 'Mon FMDD, YYYY');
  m0 text := to_char(pg_temp.c15_d(0), 'Mon FMDD, YYYY'); m13 text := to_char(pg_temp.c15_d(13), 'Mon FMDD, YYYY');
  v_nom text := 'el archivo, como venga';
  v_esp text := format('por secciones, con preámbulo: 1 nómina, día de pago %1$s y período desde %2$s (de arriba), 2 personas, bruto 3408.00, neto '
                '2859.28, lo patronal 373.19 (del detalle de la otra sección), cuadra: sí; «Uno, ZZ Ayudante» es ZZ Ayudante Uno: sí; lo retenido '
                'sin su renglón de las declaraciones: 498.72 | el resumen y el detalle de la misma nómina: 1 nómina, 1 persona, bruto 1000.00 '
                '(una vez), cuadra: sí | las dos partes con cifras distintas: cuadra: no, y lo dice: sí | dos nóminas el mismo día y un resumen '
                'que no dice de cuál: MX009 | el neto que ya trae el reembolso: cuadra: sí, lo avisa: sí, reembolsos 50.00 de los que 25.00 van '
                'en el neto | fechas con el nombre del mes, el período en una celda y una fila en cero: día de pago %1$s, del %2$s al %3$s, 1 '
                'persona, y lo avisa: sí | sin el día de pago: MX009; diciéndolo: %1$s | con la marca de orden de bytes y espacios raros: lee '
                'igual: sí', pg_temp.c15_pago(), pg_temp.c15_d(0), pg_temp.c15_d(13));
begin
  if pg_temp.c15_omitir(29, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar(false);
    perform pg_temp.c15_ser('dueno');
    -- A. por secciones, con preámbulo
    v := 'C15 PRUEBA ZZ Electric Inc' || E'\n' || '123 ZZ Street' || E'\n' || 'Payroll Journal Summary by Employee' || E'\n'
         || 'Check date: ' || dp || E'\n' || 'Pay period: ' || d0 || ' - ' || d13 || E'\n\n'
         || 'Employee,Regular hours,Overtime hours,Gross earnings,Employee taxes,Employee deductions,Net pay,Employer taxes,Employer cost' || E'\n'
         || '"Uno, ZZ Ayudante",80.00,6.00,"$1,958.00",$291.79,$0.00,"$1,666.21",$214.41,"$2,172.41"' || E'\n'
         || '"Dos, ZZ Ayudante",72.50,0.00,"$1,450.00",$206.93,$50.00,"$1,193.07",$158.78,"$1,608.78"' || E'\n'
         || 'Total,152.50,6.00,"$3,408.00",$498.72,$50.00,"$2,859.28",$373.19,"$3,781.19"' || E'\n\n'
         || 'Employer tax breakdown' || E'\n'
         || 'Employee,Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax' || E'\n'
         || '"Uno, ZZ Ayudante",121.40,28.39,11.75,52.87' || E'\n' || '"Dos, ZZ Ayudante",89.90,21.03,8.70,39.15' || E'\n'
         || 'Total,211.30,49.42,20.45,92.02' || E'\n';
    r := fn_nomina_ensayo(pg_temp.c15_arch(v, 'zz-c15-prueba-secciones.csv'));
    c := r->'corridas'->0;
    v_obt := format('por secciones, con preámbulo: %s nómina, día de pago %s y período desde %s (de arriba), %s personas, bruto %s, neto %s, lo '
                    'patronal %s (del detalle de la otra sección), cuadra: %s; «Uno, ZZ Ayudante» es ZZ Ayudante Uno: %s; lo retenido sin su renglón '
                    'de las declaraciones: %s',
      jsonb_array_length(r->'corridas'), c->>'dia_pago', c->>'periodo_desde', jsonb_array_length(c->'personas'), c->'totales'->>'bruto',
      c->'totales'->>'neto', c->'totales'->>'imp_patron', case when (c->>'cuadra')::boolean then 'sí' else 'no' end,
      case when exists (select 1 from jsonb_array_elements(c->'personas') p where p->>'clave' = fn_nomina_clave('ZZ Ayudante Uno')) then 'sí' else 'no' end,
      c->'declara'->>'sin_renglon');
    -- B. el resumen (sin fechas) y el detalle (con ellas) de la misma nómina
    v := 'Payroll Journal Summary by Employee' || E'\n\n' || 'Employee,Gross earnings,Employee taxes,Net pay' || E'\n'
         || '"ZZ Ayudante Uno",1000.00,100.00,900.00' || E'\n' || 'Total,1000.00,100.00,900.00' || E'\n\n' || 'Employee Earnings' || E'\n'
         || 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Regular earnings,Gross earnings,'
         || 'Employee federal income tax,Employee taxes,Net pay' || E'\n'
         || format('ZZ Ayudante,Uno,%s,%s,%s,Regular,1000.00,1000.00,100.00,100.00,900.00', d0, d13, dp) || E'\n';
    r := fn_nomina_ensayo(pg_temp.c15_arch(v, 'zz-c15-prueba-dos-partes.csv'));
    c := r->'corridas'->0;
    v_obt := v_obt || format(' | el resumen y el detalle de la misma nómina: %s nómina, %s persona, bruto %s (una vez), cuadra: %s',
      jsonb_array_length(r->'corridas'), jsonb_array_length(c->'personas'), c->'totales'->>'bruto', case when (c->>'cuadra')::boolean then 'sí' else 'no' end);
    -- C. lo mismo, y el resumen dice otra cifra
    r := fn_nomina_ensayo(pg_temp.c15_arch(replace(v, '"ZZ Ayudante Uno",1000.00,100.00,900.00', '"ZZ Ayudante Uno",1100.00,100.00,1000.00'),
                                           'zz-c15-prueba-dos-partes.csv'));
    c := r->'corridas'->0;
    v_obt := v_obt || format(' | las dos partes con cifras distintas: cuadra: %s, y lo dice: %s', case when (c->>'cuadra')::boolean then 'sí' else 'no' end,
      case when (c->'descuadres')::text like '%sale en dos partes del archivo con cifras distintas%' then 'sí' else 'no' end);
    -- D. dos nóminas el mismo día (la regular y un bono) y un resumen sin tipo
    v := 'Employee,Gross earnings,Net pay' || E'\n' || '"ZZ Ayudante Uno",1500.00,1500.00' || E'\n\n'
         || 'Employee first name,Employee last name,Check date,Payroll type,Gross earnings,Net pay' || E'\n'
         || format('ZZ Ayudante,Uno,%1$s,Regular,1000.00,1000.00', dp) || E'\n' || format('ZZ Ayudante,Uno,%1$s,Bonus,500.00,500.00', dp) || E'\n';
    v_obt := v_obt || ' | dos nóminas el mismo día y un resumen que no dice de cuál: '
             || pg_temp.c15_estado(format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(v, 'zz-c15-prueba-dos-nominas.csv')));
    -- E. el neto que ya trae el reembolso (el de la primera persona)
    perform pg_temp.c15_ser('dueno');
    v := 'Employee first name,Employee last name,Check date,Gross earnings,Employee taxes,Net pay,Reimbursements,Check amount' || E'\n'
         || format('ZZ Ayudante,Uno,%1$s,1000.00,100.00,925.00,25.00,925.00', dp) || E'\n'
         || format('ZZ Ayudante,Dos,%1$s,1000.00,100.00,900.00,25.00,925.00', dp) || E'\n';
    r := fn_nomina_ensayo(pg_temp.c15_arch(v, 'zz-c15-prueba-neto.csv'));
    c := r->'corridas'->0;
    v_obt := v_obt || format(' | el neto que ya trae el reembolso: cuadra: %s, lo avisa: %s, reembolsos %s de los que %s van en el neto',
      case when (c->>'cuadra')::boolean then 'sí' else 'no' end,
      case when pg_temp.c15_codigos(c->'avisos') like '%neto_con_reembolso%' then 'sí' else 'no' end,
      c->'totales'->>'reembolsos', c->'totales'->>'reembolsos_en_neto');
    -- F. fechas con el nombre del mes, el período en una celda, una fila en cero
    v := 'Employee,Pay period,Pay date,Gross pay,Net pay' || E'\n'
         || format('"ZZ Ayudante Uno","%s - %s","%s",1000.00,1000.00', m0, m13, mp) || E'\n'
         || format('"ZZ Ayudante Dos","%s - %s","%s",0.00,0.00', m0, m13, mp) || E'\n';
    r := fn_nomina_ensayo(pg_temp.c15_arch(v, 'zz-c15-prueba-mes.csv'));
    c := r->'corridas'->0;
    v_obt := v_obt || format(' | fechas con el nombre del mes, el período en una celda y una fila en cero: día de pago %s, del %s al %s, %s persona, y lo '
                             'avisa: %s', c->>'dia_pago', c->>'periodo_desde', c->>'periodo_hasta', jsonb_array_length(c->'personas'),
      case when pg_temp.c15_codigos(c->'avisos') like '%filas_en_cero%' then 'sí' else 'no' end);
    -- G. sin el día de pago en ninguna parte; y diciéndolo
    v := 'Employee,Gross earnings,Net pay' || E'\n' || '"ZZ Ayudante Uno",1000.00,1000.00' || E'\n';
    v_obt := v_obt || ' | sin el día de pago: '
             || pg_temp.c15_estado(format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(v, 'zz-c15-prueba-sin-dia.csv')));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(v, 'zz-c15-prueba-sin-dia.csv'), jsonb_build_object('dia_pago', pg_temp.c15_pago()));
    v_obt := v_obt || '; diciéndolo: ' || (r->'corridas'->0->>'dia_pago');
    -- H. con la marca de orden de bytes al principio, espacios que no parten y espacios de más
    r := fn_nomina_ensayo(pg_temp.c15_arch(pg_temp.c15_journal(), 'zz-c15-prueba.csv'));
    c := fn_nomina_ensayo(pg_temp.c15_arch(U&'\FEFF' || replace(replace(pg_temp.c15_journal(), 'Employee first name,', U&'Employee\00A0first name ,'),
                                                                  ',1958.00,', U&', 1958.00\00A0,'), 'zz-c15-prueba-bom.csv'));
    v_obt := v_obt || ' | con la marca de orden de bytes y espacios raros: lee igual: '
             || case when r->'corridas'->0->'totales' = c->'corridas'->0->'totales' and (c->'corridas'->0->>'cuadra')::boolean
                          and r->'corridas'->0->>'firma' = c->'corridas'->0->>'firma' then 'sí' else 'no' end;
    perform pg_temp.c15_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'el archivo, como venga (todavía no hay un «Payroll journal» real para confirmar su forma, y el lector no supone una): con preámbulo y las fechas arriba; por secciones, con el nombre como «Apellido, Nombre»; el resumen y el detalle de la misma nómina en un archivo (cada concepto una vez; si las dos partes no dicen lo mismo, no cuadra); dos nóminas el mismo día con filas que no dicen de cuál son (MX009: no se adivina); el neto que ya trae el reembolso; las fechas con el nombre del mes, el período en una celda, las filas en cero; sin día de pago (MX009 hasta que se dice); y la marca de orden de bytes y los espacios raros',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 30. LO QUE DICE LA PROPUESTA Y NO FRENA: horas en una obra terminada o
--     sin aprobar todavía; las horas sin aprobar de un oficial; una nómina
--     fuera de ciclo (reparte por las horas de su período SIN quedárselas,
--     hasta que se dice que es la que las paga); impuestos sin su renglón de
--     las declaraciones; y los reembolsos: a nombre de cada empleado, contra
--     lo que se le debía (y si esa cuenta no tiene con qué, se dice).
do $$
declare
  v_obt text; v_c uuid; v_a uuid; v_b uuid; r jsonb; v text; x text; y text; dp text := pg_temp.c15_us(pg_temp.c15_pago());
  d0 text := pg_temp.c15_us(pg_temp.c15_d(0)); d13 text := pg_temp.c15_us(pg_temp.c15_d(13));
  v_nom text := 'lo que avisa la propuesta';
  v_esp text := 'un archivo con lo retenido en un solo total: avisa sin_renglon y nombra «Employee taxes»: sí | horas en una obra terminada '
                'y en otra sin aprobar: obra_sin_aprobar,obra_terminada, y las nombra: sí | las 5 h sin aprobar del oficial: lo avisa: sí | '
                'los reembolsos, sin nada que se le deba al empleado: lo avisa con su OJO: sí | registrado el gasto que pagó de su bolsillo '
                '(64.25 por pagar a su nombre): sin OJO: sí | posteada: su línea de reembolso va a nombre de ZZ Oficial Tres (empleado): sí, y '
                'lo que se le debe queda en 0.00 | el bono, fuera de ciclo: reparte por las horas SIN quedárselas: sí, y horas suyas vivas: 0 | '
                'dicho que es la que las paga: se queda con ellas: sí';
begin
  if pg_temp.c15_omitir(30, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    -- (un archivo que solo trae el total de lo retenido, sin su detalle)
    v := 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Gross earnings,Employee taxes,Net pay' || E'\n'
         || format('ZZ Ayudante,Uno,%s,%s,%s,Regular,1000.00,100.00,900.00', d0, d13, dp) || E'\n';
    v_a := pg_temp.c15_importar(v, 'zz-c15-prueba-total.csv');
    r := pg_temp.c15_propuesta(v_a);
    v_obt := format('un archivo con lo retenido en un solo total: avisa %s y nombra «Employee taxes»: %s',
      (select coalesce(string_agg(q->>'codigo', ','), 'nada') from jsonb_array_elements(r->'avisos') q where q->>'codigo' = 'sin_renglon'),
      case when (r->'avisos')::text like '%«Employee taxes»%' then 'sí' else 'no' end);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_descartar(v_a, 'C15 PRUEBA: era para ver su aviso');
    perform pg_temp.c15_ser('editor');
    -- (la nómina de prueba; la obra A ya terminó, la B todavía está en estimación, y el oficial tiene 5 h sin aprobar)
    v_c := pg_temp.c15_importar(pg_temp.c15_journal());
    perform pg_temp.c15_enlazar();
    update proyectos set estado = 'completado' where id = 'c15-prueba-a';
    update proyectos set estado = 'estimando' where id = 'c15-prueba-b';
    perform pg_temp.c15_hora(21, 'p3', pg_temp.c15_d(7), 'c15-prueba-a', 5, false);
    r := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | horas en una obra terminada y en otra sin aprobar: %s, y las nombra: %s | las 5 h sin aprobar del oficial: lo avisa: %s | '
                             'los reembolsos, sin nada que se le deba al empleado: lo avisa con su OJO: %s',
      (select coalesce(string_agg(distinct q->>'codigo', ',' order by q->>'codigo'), 'nada') from jsonb_array_elements(r->'avisos') q
        where q->>'codigo' in ('obra_terminada', 'obra_sin_aprobar')),
      case when (r->'avisos')::text like '%C15 PRUEBA Obra A (terminada)%' and (r->'avisos')::text like '%C15 PRUEBA Obra B (en estimación)%' then 'sí' else 'no' end,
      case when exists (select 1 from jsonb_array_elements(r->'avisos') q
                         where q->>'codigo' = 'sin_aprobar' and q->>'persona' = pg_temp.c15_persona('ZZ Oficial Tres')::text
                           and q->>'texto' like '%(5 h)%no cuentan para la parte de obra de su sueldo%') then 'sí' else 'no' end,
      case when exists (select 1 from jsonb_array_elements(r->'avisos') q where q->>'codigo' = 'reembolsos' and q->>'texto' like '%OJO: 2250 tiene%') then 'sí' else 'no' end);
    -- (el gasto que el oficial pagó de su bolsillo, registrado: 64.25 por pagar a su nombre)
    perform pg_temp.c15_ser('dueno');
    perform fn_postear(jsonb_build_object('tipo', 'normal', 'fecha', pg_temp.c15_d(9)::text,
      'descripcion', 'C15 PRUEBA: un gasto que ZZ Oficial Tres pagó de su bolsillo',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '64.25'),
                                  jsonb_build_object('cuenta', '2250', 'monto', '-64.25', 'tercero_tipo', 'empleado', 'tercero_id', pg_temp.c15('p3')))));
    perform pg_temp.c15_ser('editor');
    r := pg_temp.c15_propuesta(v_c);
    v_obt := v_obt || format(' | registrado el gasto que pagó de su bolsillo (64.25 por pagar a su nombre): sin OJO: %s',
      case when exists (select 1 from jsonb_array_elements(r->'avisos') q where q->>'codigo' = 'reembolsos' and q->>'texto' not like '%OJO%') then 'sí' else 'no' end);
    r := pg_temp.c15_postear(v_c);
    v_obt := v_obt || format(' | posteada: su línea de reembolso va a nombre de ZZ Oficial Tres (empleado): %s, y lo que se le debe queda en %s',
      case when exists (select 1 from asiento_lineas l where l.asiento_id = (r->'asiento'->>'id')::uuid and l.cuenta = '2250' and l.monto = 64.25
                           and l.tercero_tipo = 'empleado' and l.tercero_id = pg_temp.c15('p3')) then 'sí' else 'no' end,
      (select coalesce(sum(l.monto), 0) from asiento_lineas l where l.cuenta = '2250' and l.tercero_tipo = 'empleado' and l.tercero_id = pg_temp.c15('p3')));
    -- (un bono fuera de ciclo del mismo día: reparte por las horas del período sin quedárselas; y dicho que es la que las paga)
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_anular(v_c, 'C15 PRUEBA: para que el bono reparta por sus horas');
    perform pg_temp.c15_ser('editor');
    v_b := pg_temp.c15_importar(pg_temp.c15_bono(), 'zz-c15-prueba-bono.csv');
    r := pg_temp.c15_propuesta(v_b);
    x := case when exists (select 1 from jsonb_array_elements(r->'avisos') q where q->>'codigo' = 'fuera_de_ciclo' and q->>'texto' like '%SIN quedárselas%') then 'sí' else 'no' end;
    r := pg_temp.c15_postear(v_b);
    y := (select count(*)::text from nomina_reparto_horas h where h.corrida_id = v_b and h.titular and h.vivo);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_anular(v_b, 'C15 PRUEBA: era la que paga esas horas');
    perform pg_temp.c15_ser('editor');
    v_b := pg_temp.c15_importar(pg_temp.c15_bono(), 'zz-c15-prueba-bono.csv');
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_corrida(v_b, '{"toma_horas": true}');
    perform pg_temp.c15_ser('editor');
    r := pg_temp.c15_propuesta(v_b);
    v_obt := v_obt || format(' | el bono, fuera de ciclo: reparte por las horas SIN quedárselas: %s, y horas suyas vivas: %s | dicho que es la que las '
                             'paga: se queda con ellas: %s', x, y,
      case when exists (select 1 from jsonb_array_elements(r->'avisos') q where q->>'codigo' = 'fuera_de_ciclo' and q->>'texto' like '%se queda con las horas aprobadas de su período%') then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'lo que la propuesta dice y no frena: impuestos que llegan en un total sin su renglón de las declaraciones; horas en una obra que ya terminó o que todavía no está aprobada (su parte va a esa obra igual, y se dice); las horas sin aprobar de un oficial; los reembolsos, que bajan lo que se le debe a cada empleado A SU NOMBRE (y si esa cuenta no tiene con qué, se dice antes de postear); y una nómina fuera de ciclo, que reparte por las horas de su período sin quedárselas hasta que se dice que es la que las paga',
    v_esp, v_obt, v_obt = v_esp);
end $$;
-- =====================================================================
-- LOS CONTROLES
-- =====================================================================
-- (un control en rojo que dice lo de la prueba: 'rojo, y lo dice'; en rojo sin decirlo; o verde)
create or replace function pg_temp.c15_rojo(p_orden int, p_patron text) returns text language sql as $$
  select case when c.ok then 'verde' when pg_temp.c15_nombra(c.detalle, p_patron) then 'rojo, y lo dice' else 'rojo, sin decirlo' end
    from fn_nomina_control() c where c.orden = p_orden
$$;

-- 31. LOS CUADRES, EN ROJO Y DE VUELTA. Por las funciones de la capa no se
--     llega a ninguno de estos estados (la guarda y el puente no dejan): se
--     fuerzan a mano, como el SQL Editor y dentro de un bloque que se
--     deshace, para ver que el control los ve. El 25 sí tiene camino: un
--     cargo des-casado en la Bandeja del banco sin pasar por la nómina.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; v_p uuid; k nomina_corridas; x text; v_dos uuid;
  v_nom text := 'los cuadres de la nómina, en rojo y de vuelta';
  v_esp text := 'el asiento de la nómina reversado en el libro sin anularla: el 10 rojo, y lo dice; sin eso: verde | el neto de una persona '
                'cambiado a mano en su corrida: el 15 rojo, y lo dice; sin eso: verde | una parte del reparto cambiada a mano: el 20 rojo, y lo '
                'dice; sin eso: verde | el cargo del neto des-casado en la Bandeja del banco, sin pasar por la nómina: el 25 rojo, y lo dice; '
                'deshecho también aquí (apunta que fue por fuera: sí): verde | una tabla que la llave pública puede leer: el 90 rojo, y lo dice; '
                'la guarda de una tabla apagada: rojo, y lo dice; de vuelta: verde';
begin
  if pg_temp.c15_omitir(31, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    m1 := pg_temp.c15_cargo('c15-t31-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t31 C15 PRUEBA');
    perform pg_temp.c15_casar(m1);
    select * into k from nomina_corridas where id = v_c;
    select g.id into v_p from nomina_pagos g where g.movimiento_id = m1 and g.estado = 'aplicado';
    v_dos := pg_temp.c15_persona('ZZ Ayudante Dos');
    -- el 10: el asiento de la nómina, reversado por dentro sin anular la corrida
    begin
      perform fn_reversar_interno(k.asiento_id, 'C15 PRUEBA: reversado por fuera de la nómina');
      x := pg_temp.c15_rojo(10, '%la nómina del ' || fn_nomina_dia(k.dia_pago) || ' (' || k.asiento_numero || '): %su asiento se reversó en el libro sin anular la corrida%');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('el asiento de la nómina reversado en el libro sin anularla: el 10 %s; sin eso: %s', x,
                    pg_temp.c15_vuelve(10, '%(' || k.asiento_numero || '): %'));
    -- el 15: el neto de una persona, cambiado a mano (con su guarda apagada)
    begin
      alter table nomina_corrida_personas disable trigger trg_nomina_corrida_personas_guarda;
      update nomina_corrida_personas set neto = neto + 1 where corrida_id = v_c and persona_id = v_dos;
      x := pg_temp.c15_rojo(15, '%la nómina del ' || fn_nomina_dia(k.dia_pago) || ': las líneas de ZZ Ayudante Dos no suman sus totales%');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := v_obt || format(' | el neto de una persona cambiado a mano en su corrida: el 15 %s; sin eso: %s', x,
                             pg_temp.c15_vuelve(15, '%las líneas de ZZ Ayudante Dos no suman%'));
    -- el 20: una parte del reparto, cambiada a mano
    begin
      alter table nomina_reparto disable trigger trg_nomina_reparto_guarda;
      update nomina_reparto set monto = monto + 1
       where ctid = (select q.ctid from nomina_reparto q where q.corrida_id = v_c and q.persona_id = v_dos and q.clase = 'bruto' limit 1);
      x := pg_temp.c15_rojo(20, '%el reparto de ZZ Ayudante Dos suma $1,451.00 de sueldo y $158.78 de lo patronal, y su journal dice $1,450.00 y $158.78%');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := v_obt || format(' | una parte del reparto cambiada a mano: el 20 %s; sin eso: %s', x, pg_temp.c15_vuelve(20, '%el reparto de ZZ Ayudante Dos suma%'));
    -- el 25: el cargo, des-casado en la Bandeja del banco (por c6, sin pasar por la nómina); y deshecho también aquí
    perform pg_temp.c15_ser('dueno');
    perform fn_banco_descasar(m1, 'C15 PRUEBA: des-casado en la Bandeja');
    perform pg_temp.c15_ser('editor');
    x := pg_temp.c15_rojo(25, '%el cargo del ' || fn_nomina_dia(pg_temp.c15_d(15)) || ' por $4,874.93: ya no está casado con su asiento en el banco (se des-casó en la Bandeja): deshazlo aquí también%');
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_deshacer(v_p, 'C15 PRUEBA: se des-casó en la Bandeja');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | el cargo del neto des-casado en la Bandeja del banco, sin pasar por la nómina: el 25 %s; deshecho también aquí (apunta '
                             'que fue por fuera: %s): %s', x, case when (r->>'por_fuera')::boolean then 'sí' else 'no' end,
                             pg_temp.c15_vuelve(25, '%por $4,874.93: ya no está casado%'));
    -- el 90: una tabla que la llave pública puede leer; y una guarda apagada
    grant select on nomina_corridas to anon;
    x := pg_temp.c15_rojo(90, '%nomina_corridas la puede leer o escribir quien no debe%');
    revoke select on nomina_corridas from anon;
    alter table nomina_pagos disable trigger trg_nomina_pagos_guarda;
    v_obt := v_obt || format(' | una tabla que la llave pública puede leer: el 90 %s; la guarda de una tabla apagada: %s', x,
                             pg_temp.c15_rojo(90, '%nomina_pagos sin su guarda%'));
    alter table nomina_pagos enable trigger trg_nomina_pagos_guarda;
    v_obt := v_obt || '; de vuelta: ' || pg_temp.c15_ctl(90);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'los cuadres de la nómina, en rojo y de vuelta: el asiento de una corrida reversado sin anularla (10), lo de una persona que deja de sumar sus líneas (15), un reparto que deja de sumar su journal (20), un cargo de Gusto des-casado en la Bandeja del banco sin pasar por la nómina (25: se deshace también aquí, y queda apuntado que fue por fuera) y las protecciones (90: una tabla legible para la llave pública, una guarda apagada)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. LOS AVISOS DEL DINERO, EN ROJO Y DE VUELTA, por su camino de verdad:
--     una nómina importada sin postear (30), su gente sin enlazar (40), un
--     cargo de Gusto esperando en el banco (35), lo que la nómina dejó por
--     pagar y no baja (60), lo que entra a sus cuentas por pagar por otro
--     lado (62), la bolsa del burden real con algo sin repartir (75) y la
--     configuración a medias (85). (El 65 y el 70, en las pruebas 27 y 28.)
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; m2 uuid; m3 uuid; k nomina_corridas; x text; y text; v_a uuid; v_b uuid; v_bolsa numeric;
  v_dp text := fn_nomina_dia(pg_temp.c15_pago());
  v_nom text := 'los avisos del dinero, en rojo y de vuelta';
  v_esp text := 'importada y sin enlazar: el 30 rojo, y lo dice, y el 40 rojo, y lo dice | enlazada su gente: el 40 verde | posteada: el 30 verde | '
                'sin decir la cuenta de lo sin obra: el 85 rojo, y lo dice; dicha: verde | con el plazo en 5 días y nada pagado: el 60 rojo, y lo '
                'dice | sus tres cargos de Gusto en el banco: el 35 rojo, y lo dice | casados los tres: el 35 verde y el 60 verde | un asiento a '
                'mano en la cuenta de los impuestos por pagar: el 62 rojo, y lo dice; reversado: verde | la prima de WC del mes a la bolsa del '
                'burden real: el 75 rojo, y dice 25.00 más que antes: sí; reversada: como antes: sí';
begin
  if pg_temp.c15_omitir(32, v_nom, v_esp, true) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    v_c := pg_temp.c15_importar(pg_temp.c15_journal());
    v_obt := format('importada y sin enlazar: el 30 %s, y el 40 %s', pg_temp.c15_rojo(30, '%la del ' || v_dp || ' (regular, bruto $5,808.00)%'),
                    pg_temp.c15_rojo(40, '%ZZ Ayudante Dos (sin enlazar)%ZZ Ayudante Uno (sin enlazar)%ZZ Oficial Tres (sin enlazar)%'));
    perform pg_temp.c15_enlazar();
    v_obt := v_obt || ' | enlazada su gente: el 40 ' || pg_temp.c15_vuelve(40, '%ZZ Ayudante Dos (sin enlazar)%');
    r := pg_temp.c15_postear(v_c);
    select * into k from nomina_corridas where id = v_c;
    v_obt := v_obt || ' | posteada: el 30 ' || pg_temp.c15_vuelve(30, '%la del ' || v_dp || ' (regular, bruto $5,808.00)%');
    -- el 85: la cuenta de lo sin obra, sin decir (con gente de campo en la nómina)
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_config('{"cuenta_sin_obra": null}');
    perform pg_temp.c15_ser('editor');
    x := pg_temp.c15_rojo(85, '%Falta decir a qué cuenta van las horas sin obra de la gente de campo%');
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_config('{"cuenta_sin_obra": "6000", "saldo_dias": 5}');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | sin decir la cuenta de lo sin obra: el 85 %s; dicha: %s', x, pg_temp.c15_vuelve(85, '%Falta decir a qué cuenta van las horas sin obra%'));
    -- el 60: lo que dejó por pagar, con el plazo en 5 días (hoy es el último día del mes; el día de pago, el 20)
    v_obt := v_obt || ' | con el plazo en 5 días y nada pagado: el 60 ' || pg_temp.c15_rojo(60, '%$4,874.93 en 2210 de la nómina del ' || v_dp || '%');
    -- el 35: sus tres cargos de Gusto, en el banco
    m1 := pg_temp.c15_cargo('c15-t32-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t32 C15 PRUEBA');
    m2 := pg_temp.c15_cargo('c15-t32-tax', pg_temp.c15_d(15), 1583.31, 'GUSTO TAX 7c15t32 C15 PRUEBA');
    m3 := pg_temp.c15_cargo('c15-t32-csd', pg_temp.c15_d(15), 50.00, 'GUSTO CSD 7c15t32 C15 PRUEBA');
    v_obt := v_obt || ' | sus tres cargos de Gusto en el banco: el 35 '
             || pg_temp.c15_rojo(35, '%$4,874.93 del ' || fn_nomina_dia(pg_temp.c15_d(15)) || ' («GUSTO NET 7c15t32 C15 PRUEBA»)%');
    perform pg_temp.c15_casar(m1); perform pg_temp.c15_casar(m2); perform pg_temp.c15_casar(m3);
    v_obt := v_obt || format(' | casados los tres: el 35 %s y el 60 %s', pg_temp.c15_vuelve(35, '%7c15t32%'),
                             pg_temp.c15_vuelve(60, '%de la nómina del ' || v_dp || '%'));
    -- el 62: un asiento a mano en la cuenta de los impuestos por pagar (2220), después del día de pago
    perform pg_temp.c15_ser('dueno');
    r := fn_postear(jsonb_build_object('tipo', 'normal', 'fecha', pg_temp.c15_d(20)::text, 'descripcion', 'C15 PRUEBA: a mano en los impuestos por pagar',
           'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6500', 'monto', '10.00'), jsonb_build_object('cuenta', '2220', 'monto', '-10.00'))));
    v_a := (r->>'id')::uuid;
    perform pg_temp.c15_ser('editor');
    x := pg_temp.c15_rojo(62, '%2220: $10.00 en 1 asiento(s) que no son de la nómina (' || (select a.numero from asientos a where a.id = v_a) || ')%');
    perform pg_temp.c15_ser('dueno');
    perform fn_reversar(v_a, 'C15 PRUEBA: no iba');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | un asiento a mano en la cuenta de los impuestos por pagar: el 62 %s; reversado: %s', x,
                             pg_temp.c15_vuelve(62, '%2220: $10.00 en 1 asiento(s)%'));
    -- el 75: la prima de WC del mes, de lo pagado por adelantado a la bolsa del burden real (lo que c1 dice que entra ahí)
    select coalesce(sum(l.monto), 0) into v_bolsa from asiento_lineas l where l.cuenta = '5015';
    perform pg_temp.c15_ser('dueno');
    r := fn_postear(jsonb_build_object('tipo', 'normal', 'fecha', pg_temp.c15_d(20)::text, 'descripcion', 'C15 PRUEBA: la prima de WC del mes',
           'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '25.00'), jsonb_build_object('cuenta', '1410', 'monto', '-25.00'))));
    v_b := (r->>'id')::uuid;
    perform pg_temp.c15_ser('editor');
    x := format('el 75 %s, y dice 25.00 más que antes: %s', pg_temp.c15_ctl(75),
                case when pg_temp.c15_ctl_det(75) like '%tiene ' || fn_nomina_usd(v_bolsa + 25) || ' sin repartir a las obras%' then 'sí' else 'no' end);
    perform pg_temp.c15_ser('dueno');
    perform fn_reversar(v_b, 'C15 PRUEBA: no iba');
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | la prima de WC del mes a la bolsa del burden real: %s; reversada: como antes: %s', x,
      case when (v_bolsa = 0 and pg_temp.c15_ctl(75) = 'verde')
             or (v_bolsa <> 0 and pg_temp.c15_ctl_det(75) like '%tiene ' || fn_nomina_usd(v_bolsa) || ' sin repartir%') then 'sí' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'los avisos del dinero, en rojo y de vuelta por su camino de verdad: una nómina importada sin postear (30) y su gente sin enlazar (40); la cuenta de lo sin obra sin decir (85); lo que la nómina dejó por pagar y sigue sin su cargo pasado el plazo (60); los cargos de Gusto esperando en el banco (35), hasta que se casan; un asiento a mano en una cuenta por pagar de la nómina (62), hasta que se reversa; y algo que entra a la bolsa del burden real por otro lado y queda sin repartir (75: la prima de WC, ▶ CPA)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. LAS HORAS: NADA DOS VECES, NADA FUERA. Cada hora aprobada de quien
--     cobra por horas está en UN sitio: o la pagó una nómina viva (su lote),
--     o está en la cola (trabajada y todavía sin pagar). Y los avisos que lo
--     vigilan, en rojo y de vuelta: Gusto pagó otras horas que las aprobadas
--     (45), una hora del período aprobada después de postear (50), una hora
--     del lote que cambia después (55) y la cola del mes al terminar (80).
do $$
declare
  v_obt text; v_c uuid; r jsonb; k nomina_corridas; x text; y text; v_m text := pg_temp.c15('mes'); v_dp text := fn_nomina_dia(pg_temp.c15_pago());
  v_nom text := 'las horas: nada dos veces, nada fuera';
  v_esp text := format('las horas aprobadas del mes de ZZ Ayudante Uno y Dos: 44 h = 38 h que pagó la nómina + 6 h en la cola (150.00 a su tarifa); en '
                'los dos sitios a la vez: 0 | pagado hasta: %s los dos | Gusto pagó otras horas que las aprobadas: el 45 rojo, y lo dice | una '
                'hora del período aprobada después de postear: el 50 rojo, y lo dice, y entra en la cola: 13 h; quitada su aprobación: verde | una '
                'hora del lote cambiada después: el 55 rojo, y lo dice; como estaba: verde | terminado el mes: el 80 rojo, y habla de %s; sin la '
                'hora de la cola: ZZ Ayudante Uno ya no está en ella: sí | anulada la nómina: el 45 verde, y todas sus horas vuelven a la cola: '
                '44 h', pg_temp.c15_d(13), v_m);
begin
  if pg_temp.c15_omitir(33, v_nom, v_esp) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    -- (la cola: 6 h de ZZ Ayudante Uno en la obra B el día 22, aprobadas, después del período de pago)
    perform pg_temp.c15_hora(9, 'p1', pg_temp.c15_d(21), 'c15-prueba-b', 6);
    r := pg_temp.c15_postear(v_c);
    select * into k from nomina_corridas where id = v_c;
    perform pg_temp.c15_ser('dueno');
    select format('las horas aprobadas del mes de ZZ Ayudante Uno y Dos: %s h = %s h que pagó la nómina + %s h en la cola (%s a su tarifa); en los dos '
                  'sitios a la vez: %s',
             (select trim_scale(sum(h.horas)) from horas h where h.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'))
                 and h.aprobado_el is not null and h.fecha between pg_temp.c15('mes_desde')::date and pg_temp.c15('mes_hasta')::date),
             (select trim_scale(sum(p.horas)) from fn_nomina_horas_pagadas() p where p.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'))),
             (select trim_scale(sum(q.horas)) from fn_nomina_cola(v_m) q where q.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'))),
             (select sum(q.estandar) from fn_nomina_cola(v_m) q where q.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'))),
             (select count(*) from horas h join fn_nomina_horas_pagadas() p on p.horas_id = h.id
               where h.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2')) and h.fecha > k.periodo_hasta))
      into v_obt;
    select v_obt || ' | pagado hasta: ' || string_agg(distinct h.pagado_hasta::text, ', ') || case when count(*) = 2 then ' los dos' else ' (' || count(*) || ')' end
      into v_obt from fn_nomina_pagado_hasta() h where h.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'));
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || ' | Gusto pagó otras horas que las aprobadas: el 45 '
             || pg_temp.c15_rojo(45, '%ZZ Ayudante Uno en la nómina del ' || v_dp || ': Gusto le pagó 86 h y en la app tiene 30 h aprobadas del período%');
    -- el 50: las 7 h del día 9 (dentro del período), aprobadas después de postear
    update horas set aprobado_por = pg_temp.c15('dueno')::uuid, aprobado_el = now() where id = -1510000005;
    x := pg_temp.c15_rojo(50, '%ZZ Ayudante Uno: 7 h del ' || fn_nomina_dia(pg_temp.c15_d(8)) || ' al ' || fn_nomina_dia(pg_temp.c15_d(8))
                              || ' (período de la nómina del ' || v_dp || ')%');
    perform pg_temp.c15_ser('dueno');
    select trim_scale(sum(q.horas))::text into y from fn_nomina_cola(v_m) q where q.usuario_id::text = pg_temp.c15('p1');
    perform pg_temp.c15_ser('editor');
    update horas set aprobado_por = null, aprobado_el = null where id = -1510000005;
    v_obt := v_obt || format(' | una hora del período aprobada después de postear: el 50 %s, y entra en la cola: %s h; quitada su aprobación: %s', x, y,
                             pg_temp.c15_vuelve(50, '%ZZ Ayudante Uno: 7 h del%'));
    -- el 55: una hora del lote, cambiada después (de 8 h a 9)
    if pg_temp.c15_estado('update public.horas set horas = 9 where id = -1510000001') <> 'ok' then   -- (como el dueño, desde la app)
      raise exception 'c15-pruebas: la base no dejó al dueño corregir una hora de prueba';
    end if;
    x := pg_temp.c15_rojo(55, '%el reporte -1510000001 de la nómina del ' || v_dp || ': %');
    perform pg_temp.c15_estado('update public.horas set horas = 8 where id = -1510000001');
    update horas set aprobado_por = pg_temp.c15('dueno')::uuid, aprobado_el = now() where id = -1510000001;
    v_obt := v_obt || format(' | una hora del lote cambiada después: el 55 %s; como estaba: %s', x, pg_temp.c15_vuelve(55, '%el reporte -1510000001 de%'));
    -- el 80: terminado el mes (hoy pasa a ser el día 1 del siguiente), su cola
    perform pg_temp.c15_fingir_hoy(pg_temp.c15('mes_hasta')::date + 1);
    x := case when pg_temp.c15_ctl(80) = 'rojo' and pg_temp.c15_ctl_det(80) like 'En ' || v_m || ' quedaron %' then 'rojo, y habla de ' || v_m
              else pg_temp.c15_ctl(80) || ': ' || left(pg_temp.c15_ctl_det(80), 120) end;
    update horas set aprobado_por = null, aprobado_el = null where id = -1510000009;
    perform pg_temp.c15_ser('dueno');
    y := case when exists (select 1 from fn_nomina_cola(v_m) q where q.usuario_id::text = pg_temp.c15('p1')) then 'no' else 'sí' end;
    perform pg_temp.c15_ser('editor');
    update horas set aprobado_por = pg_temp.c15('dueno')::uuid, aprobado_el = now() where id = -1510000009;
    perform pg_temp.c15_fingir_hoy(pg_temp.c15('mes_hasta')::date);
    v_obt := v_obt || format(' | terminado el mes: el 80 %s; sin la hora de la cola: ZZ Ayudante Uno ya no está en ella: %s', x, y);
    -- anulada la nómina: el 45 deja de nombrarla, y sus horas vuelven a no estar pagadas
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_anular(v_c, 'C15 PRUEBA: para ver sus horas volver');
    select trim_scale(sum(q.horas))::text into y from fn_nomina_cola(v_m) q where q.usuario_id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'));
    perform pg_temp.c15_ser('editor');
    v_obt := v_obt || format(' | anulada la nómina: el 45 %s, y todas sus horas vuelven a la cola: %s h',
                             pg_temp.c15_vuelve(45, '%ZZ Ayudante Uno en la nómina del ' || v_dp || '%'), y);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'las horas, nada dos veces y nada fuera: cada hora aprobada de quien cobra por horas está en un solo sitio —la pagó una nómina viva (su lote) o está en la cola (trabajada y sin pagar todavía)—, y cada persona tiene su «pagado hasta»; y los avisos que lo vigilan, en rojo y de vuelta: Gusto pagó otras horas que las aprobadas (45), una hora del período aprobada después de postear (50), una hora del lote que cambia después (55) y la cola del mes al terminar (80); anulada la nómina, sus horas vuelven a no estar pagadas',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. LAS CUATRO FILAS DEL CIERRE (180 a 183), con lo que las pone en rojo y
--     lo que las devuelve; en la apertura no aplican las dos del mes.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; x text; v_m text := pg_temp.c15('mes'); v_dp text := fn_nomina_dia(pg_temp.c15_pago()); v_ap text;
  v_nom text := 'las cuatro filas del cierre';
  v_esp text := 'las cuatro filas (180, 181 y 182 detienen; 183 avisa), todas a la página de la nómina: sí | importada sin postear: la 181 en '
                'rojo, la nombra y dice qué hacer: sí | posteada: la 181 verde | un cargo de Gusto del mes en el banco: la 180 en rojo, lo '
                'nombra y dice qué hacer: sí | casado: la 180 verde | un cuadre en rojo: la 182 lo dice en su nombre («— 1 en rojo: 90») y en su '
                'detalle: sí; de vuelta: verde | la 183 lleva el aviso 45 con el principio de su detalle: sí | en la apertura, la 180 y la 181: '
                'no aplican';
begin
  if pg_temp.c15_omitir(34, v_nom, v_esp, true) then return; end if;
  begin
    perform pg_temp.c15_sembrar();
    v_c := pg_temp.c15_importar(pg_temp.c15_journal());
    select case when count(*) = 4 and bool_and(k.ir_a = 'nomina') and bool_and(k.nivel = case when k.orden = 183 then 'aviso' else 'detiene' end)
                     and array_agg(k.orden order by k.orden) = array[180, 181, 182, 183] then 'sí' else 'no' end
      into x from fn_nomina_cierre(v_m) k;
    v_obt := 'las cuatro filas (180, 181 y 182 detienen; 183 avisa), todas a la página de la nómina: ' || x;
    select case when not k.ok and pg_temp.c15_nombra(k.detalle, '%la del ' || v_dp || ' (bruto $5,808.00)%') and k.que_hacer like '%postéala%' then 'sí' else 'no' end
      into x from fn_nomina_cierre(v_m) k where k.orden = 181;
    v_obt := v_obt || ' | importada sin postear: la 181 en rojo, la nombra y dice qué hacer: ' || x;
    perform pg_temp.c15_enlazar();
    r := pg_temp.c15_postear(v_c);
    select case when k.ok or k.detalle not like '%la del ' || v_dp || ' (bruto $5,808.00)%' then 'verde' else 'rojo' end into x from fn_nomina_cierre(v_m) k where k.orden = 181;
    v_obt := v_obt || ' | posteada: la 181 ' || x;
    m1 := pg_temp.c15_cargo('c15-t34-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t34 C15 PRUEBA');
    select case when not k.ok and pg_temp.c15_nombra(k.detalle, '%$4,874.93 del ' || fn_nomina_dia(pg_temp.c15_d(15)) || '%') and k.que_hacer like '%Cargos de Gusto%' then 'sí' else 'no' end
      into x from fn_nomina_cierre(v_m) k where k.orden = 180;
    v_obt := v_obt || ' | un cargo de Gusto del mes en el banco: la 180 en rojo, lo nombra y dice qué hacer: ' || x;
    perform pg_temp.c15_casar(m1);
    select case when k.ok or k.detalle not like '%$4,874.93 del ' || fn_nomina_dia(pg_temp.c15_d(15)) || '%' then 'verde' else 'rojo' end into x from fn_nomina_cierre(v_m) k where k.orden = 180;
    v_obt := v_obt || ' | casado: la 180 ' || x;
    grant select on nomina_corridas to anon;
    select case when not k.ok and k.control ~ ' — [0-9]+ en rojo: .*90' and k.detalle like '%90: %nomina_corridas la puede leer o escribir quien no debe%' then 'sí' else 'no' end
      into x from fn_nomina_cierre(v_m) k where k.orden = 182;
    revoke select on nomina_corridas from anon;
    v_obt := v_obt || ' | un cuadre en rojo: la 182 lo dice en su nombre («— 1 en rojo: 90») y en su detalle: ' || x || '; de vuelta: '
             || (select case when k.control !~ '90' then 'verde' else 'rojo' end from fn_nomina_cierre(v_m) k where k.orden = 182);
    select case when not k.ok and k.control = 'nómina: sus avisos (c15)' and k.detalle ~ '^[0-9]+ en rojo \(.*45.*\)\. ' and k.detalle like '%45: %Gusto le pagó%' then 'sí' else 'no' end
      into x from fn_nomina_cierre(v_m) k where k.orden = 183;
    v_obt := v_obt || ' | la 183 lleva el aviso 45 con el principio de su detalle: ' || x;
    select p.periodo into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
    v_obt := v_obt || ' | en la apertura, la 180 y la 181: '
             || coalesce((select case when bool_and(k.ok and k.detalle = 'No aplica: la nómina va por mes.') then 'no aplican' else 'APLICAN' end
                            from fn_nomina_cierre(v_ap) k where k.orden in (180, 181)), 'no aplican');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'las cuatro filas que la nómina le da al cierre del mes: 180 cada cargo de Gusto del mes casado con su nómina (detiene), 181 cada nómina con día de pago en el mes posteada (detiene), 182 sus cuadres en una fila que dice en su nombre cuáles están en rojo (detiene) y 183 sus avisos en una fila (avisa); cada una con su detalle en llano, qué hacer y la página a la que lleva; en la apertura, las dos del mes no aplican',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. EL CIERRE (c9) MIRA LA NÓMINA: con el bloque de c15 en
--     fn_cierre_revisar, la revisión del mes trae las cuatro filas de esta
--     capa tal cual, y un cargo de Gusto del mes sin casar NO deja cerrar
--     (MX010, y lo nombra). «omitida» mientras c9-cierre.sql no traiga ese
--     bloque.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; x text; y text; v_m text := pg_temp.c15('mes');
  v_nom text := 'el cierre (c9) mira la nómina';
  v_esp text := 'la revisión del mes trae la 180, la 181, la 182 y la 183 con lo que dice esta capa: sí | con un cargo de Gusto del mes sin '
                'casar, cerrar el mes: MX010, y la 180 es de las que lo detienen: sí | casado: la 180 ya no lo detiene: sí';
begin
  if pg_temp.c15('hay_c9') <> 'true' then
    insert into _pruebas values (35, v_nom, v_esp, 'omitida: el cierre (c9) no está en esta base', null); return;
  end if;
  if pg_temp.c15('c9_nomina') <> 'true' then
    insert into _pruebas values (35, v_nom, v_esp,
      'omitida: el c9-cierre.sql de esta base todavía no pide las filas de la nómina a esta capa (no trae la 180 a la 183): cuando llegue el c9-cierre.sql que las nombra en su cabecera, pégalo y después estas pruebas', null);
    return;
  end if;
  if pg_temp.c15_omitir(35, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    m1 := pg_temp.c15_cargo('c15-t35-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t35 C15 PRUEBA');
    select case when count(*) = 4 and bool_and(k.control = s.control and k.ok is not distinct from s.ok and k.detalle = left(s.detalle, 1500)
                                               and k.ir_a = 'nomina' and k.nivel = s.nivel) then 'sí' else 'no' end
      into x
      from fn_cierre_revisar(v_m) k join fn_nomina_cierre(v_m) s on s.orden = k.orden
     where k.orden between 180 and 183;
    v_obt := 'la revisión del mes trae la 180, la 181, la 182 y la 183 con lo que dice esta capa: ' || x;
    x := pg_temp.c15_dice(format('select public.fn_cierre_cerrar(%L, public.fn_cierre_confirmacion(%L))', v_m, v_m));
    select case when k.nivel = 'detiene' and k.ok is distinct from true then 'sí' else 'no' end into y from fn_cierre_revisar(v_m) k where k.orden = 180;
    v_obt := v_obt || format(' | con un cargo de Gusto del mes sin casar, cerrar el mes: %s, y la 180 es de las que lo detienen: %s', left(x, 5),
                             case when y = 'sí' and (x like '%180) nómina: cada cargo de Gusto del mes casado con su nómina%' or length(x) > 2400) then 'sí' else 'no' end);
    perform pg_temp.c15_casar(m1);
    select case when k.ok or k.detalle not like '%$4,874.93 del ' || fn_nomina_dia(pg_temp.c15_d(15)) || '%' then 'sí' else 'no' end into y
      from fn_cierre_revisar(v_m) k where k.orden = 180;
    v_obt := v_obt || ' | casado: la 180 ya no lo detiene: ' || y;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'EL CIERRE (c9) MIRA LA NÓMINA: la revisión del mes trae las cuatro filas de esta capa (180 a 183) tal cual las dice; con un cargo de Gusto del mes sin casar el mes NO se cierra (MX010, y la 180 es de las que lo detienen); casado, deja de detenerlo',
    v_esp, v_obt, v_obt = v_esp);
end $$;
-- =====================================================================
-- LOS TEXTOS, QUIÉN VE QUÉ Y EL CIERRE DE LA SUITE
-- =====================================================================
-- 36. LOS TEXTOS, EN LLANO: ni el detalle de un control (en verde o en
--     rojo), ni las filas del cierre, ni lo que frena o avisa una propuesta,
--     ni lo que contesta importar, ni lo que se propone para un cargo, ni el
--     amarre, ni el papel de un asiento, ni los mensajes de error de la
--     pantalla nombran una función ni una tabla; y las fechas van en llano
--     (20-nov-2026), nunca 2026-11-20.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; m2 uuid; v_txt text; v_fch text; v_n int; v_m text := pg_temp.c15('mes'); v_y int; v_q int;
  v_nom text := 'los textos, en llano';
  v_esp text := 'textos mirados: más de 60; con el nombre de una función o de una tabla: ninguno; con una fecha sin poner en llano: ninguno';
begin
  if pg_temp.c15_omitir(36, v_nom, v_esp, true) then return; end if;
  begin
    create temp table _c15_textos (t text) on commit drop;
    grant all on _c15_textos to public;
    perform pg_temp.c15_sembrar();
    v_y := extract(year from pg_temp.c15_pago())::int; v_q := extract(quarter from pg_temp.c15_pago())::int;
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_ensayo(pg_temp.c15_arch(replace(pg_temp.c15_journal(), ',1193.07,0.00,1193.07,', ',1190.07,0.00,1190.07,'), 'zz-c15-prueba-mal.csv'));
    insert into _c15_textos select jsonb_array_elements_text(r->'corridas'->0->'descuadres');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()));
    v_c := (r->'corridas'->0->>'corrida')::uuid;
    insert into _c15_textos values (r->>'mensaje'), (r->'corridas'->0->>'texto');
    r := fn_nomina_importar(pg_temp.c15_arch(pg_temp.c15_journal()));
    insert into _c15_textos values (r->>'mensaje'), (r->'corridas'->0->>'texto');
    r := fn_nomina_propuesta(v_c);
    insert into _c15_textos select q->>'texto' from jsonb_array_elements(r->'frenos' || r->'avisos') q;
    insert into _c15_textos select k.detalle from fn_nomina_control() k union all select k.control from fn_nomina_control() k;
    perform pg_temp.c15_ser('editor');
    perform pg_temp.c15_enlazar();
    m1 := pg_temp.c15_cargo('c15-t36-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t36 C15 PRUEBA');
    m2 := pg_temp.c15_cargo('c15-t36-tax', pg_temp.c15_d(15), 1500.00, 'GUSTO TAX 7c15t36 C15 PRUEBA');
    perform pg_temp.c15_ser('dueno');
    insert into _c15_textos select g.texto from fn_nomina_cargos() g where g.movimiento_id in (m1, m2);
    r := fn_nomina_propuesta(v_c);
    insert into _c15_textos select q->>'texto' from jsonb_array_elements(r->'frenos' || r->'avisos') q;
    insert into _c15_textos select q->>'memo' from jsonb_array_elements(r->'asiento'->'lineas' || r->'burden'->'lineas') q;
    r := fn_nomina_postear(v_c, r->>'visto');
    insert into _c15_textos select q->>'texto' from jsonb_array_elements(r->'avisos') q;
    r := fn_nomina_cargo_propuesta(m1);
    insert into _c15_textos select r->>'texto' union all select q->>'texto' from jsonb_array_elements(r->'opciones') q;
    r := fn_nomina_cargo_propuesta(m2);
    insert into _c15_textos select r->>'texto' union all select q->>'texto' from jsonb_array_elements(r->'opciones') q;
    perform fn_nomina_cargo_casar(m1, fn_nomina_cargo_propuesta(m1)->'opciones'->0->'partes');
    insert into _c15_textos select g.texto from fn_nomina_cargos() g where g.movimiento_id in (m1, m2);
    r := fn_nomina_declaracion(jsonb_build_object('forma', '941', 'anio', v_y, 'trimestre', v_q, 'salarios', '5000.00', 'retencion', '503.00', 'ss_medicare', '888.64'));
    insert into _c15_textos select a.detalle from fn_nomina_amarre(null) a;
    r := fn_nomina_lote(pg_temp.c15_d(0), pg_temp.c15_d(13), 'C15 PRUEBA');
    insert into _c15_textos select q->>'texto' from jsonb_array_elements(r->'avisos') q;
    insert into _c15_textos select k.detalle from fn_nomina_control() k;
    insert into _c15_textos select k.detalle from fn_nomina_cierre(v_m) k union all select k.control from fn_nomina_cierre(v_m) k
                            union all select k.que_hacer from fn_nomina_cierre(v_m) k where k.que_hacer is not null;
    insert into _c15_textos select p.papel from v_nomina_papel p where p.origen_id = v_c::text;
    insert into _c15_textos select x.descripcion from fn_nomina_auxiliar(null) x where x.corrida_id = v_c;
    perform pg_temp.c15_ser('editor');
    insert into _c15_textos select pg_temp.c15_dice(format('select public.fn_nomina_anular(%L, ''C15 PRUEBA: con su cargo casado'')', v_c));
    perform pg_temp.c15_ser('dueno');
    r := fn_nomina_cargo_deshacer((select g.id from nomina_pagos g where g.movimiento_id = m1 and g.estado = 'aplicado'), 'C15 PRUEBA: para anularla');
    insert into _c15_textos values (r->>'nota');
    r := fn_nomina_anular(v_c, 'C15 PRUEBA: para ver sus textos');
    insert into _c15_textos values (r->>'nota');
    perform pg_temp.c15_ser('editor');
    -- (los mensajes de error de la pantalla; los de la guarda —escribir a mano en el SQL Editor— nombran su tabla y no cuentan)
    insert into _c15_textos
    select pg_temp.c15_dice(x.q) from (values
      (format('select public.fn_nomina_postear(%L, ''no-es-lo-que-vi'')', v_c)),
      (format('select public.fn_nomina_anular(%L, '''')', v_c)),
      (format('select public.fn_nomina_descartar(%L, ''C15 PRUEBA'')', v_c)),
      (format('select public.fn_nomina_propuesta(%L)', gen_random_uuid())),
      ('select public.fn_nomina_importar(''{"nombre": "zz.csv", "sha256": "x", "bytes": 1, "filas": []}''::jsonb)'),
      (format('select public.fn_nomina_importar(%L::jsonb)', pg_temp.c15_arch('ZZ Nada,ZZ Otra' || E'\n' || 'a,b' || E'\n', 'zz-c15-prueba-nada.csv'))),
      (format('select public.fn_nomina_cargo_casar(%L, %L::jsonb)', m2, jsonb_build_array(jsonb_build_object('corrida', v_c, 'cuenta', '2220', 'monto', '1.00')))),
      (format('select public.fn_nomina_cargo_cuota(%L, '''')', m2)),
      (format('select public.fn_nomina_cargo_deshacer(%L, ''C15 PRUEBA'')', gen_random_uuid())),
      ('select public.fn_nomina_lote(''2099-01-04'', ''2099-01-10'')'),
      ('select public.fn_nomina_lote(''2099-01-10'', ''2099-01-04'')'),
      ('select public.fn_nomina_declaracion(''{"forma": "941", "anio": 2026}''::jsonb)'),
      ('select public.fn_nomina_declaracion(''{"forma": "1040", "anio": 2026}''::jsonb)'),
      ('select public.fn_nomina_persona(''{"nombre": "x"}''::jsonb)'),
      (format('select public.fn_nomina_persona(%L::jsonb)', jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'clase', 'jefe'))),
      (format('select public.fn_nomina_decidir(%L, %L, ''{"decision": "sin_obra"}''::jsonb)', v_c, pg_temp.c15_persona('ZZ Ayudante Dos'))),
      ('select public.fn_nomina_config(''{"cuenta_bolsa": "9999"}''::jsonb)'),
      ('select public.fn_nomina_config(''{"semana_empieza": 9}''::jsonb)'),
      ('select public.fn_nomina_columna(''{"columna": "ZZ Dato raro", "clase": "no-existe"}''::jsonb)'),
      ('select public.fn_nomina_columna(''{"columna": "ZZ Dato raro", "clase": "imp_patron", "cuenta": "1010"}''::jsonb)'),
      (format('select public.fn_nomina_corrida(%L, ''{"periodo_desde": "2026-02-30"}''::jsonb)', v_c)),
      ('select public.fn_nomina_importar(''{}''::jsonb, ''{"reemplazar": true, "otra_nomina": true}''::jsonb)')) as x(q);
    insert into _c15_textos select pg_temp.c15_dice('select public.fn_nomina_importar(''{}''::jsonb)', 'equipo');
    select count(*), string_agg(left(z.t, 200), ' ¶ ') filter (where z.t ~ '\mfn_[a-z0-9_]+|\mnomina_[a-z_]+|\mv_nomina_[a-z0-9_]+|\masiento_lineas\M|\mmovimientos_banco\M|\mjornal_[a-z]+'),
           string_agg(left(z.t, 200), ' ¶ ') filter (where z.t ~ '\m20[0-9]{2}-[01][0-9]-[0-3][0-9]\M')
      into v_n, v_txt, v_fch from _c15_textos z where z.t is not null and z.t <> 'ok';
    v_obt := format('textos mirados: %s; con el nombre de una función o de una tabla: %s; con una fecha sin poner en llano: %s',
                    case when v_n > 60 then 'más de 60' else v_n::text end, coalesce(left(v_txt, 700), 'ninguno'), coalesce(left(v_fch, 700), 'ninguno'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'LOS TEXTOS, EN LLANO: el detalle de cada control (con varios en rojo), las filas del cierre, lo que frena y lo que avisa una propuesta, las líneas del asiento, lo que contesta importar, lo que se propone para un cargo, el amarre, el papel de un asiento y los mensajes de error de la pantalla no nombran ninguna función ni ninguna tabla, y dicen las fechas en llano (20-nov-2026)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. CON LA NÓMINA DENTRO, NADIE MÁS VE NADA: el equipo (por la API, con
--     su sesión) lee cero filas de cada tabla, de cada vista y de cada
--     función, y no puede hacer nada; la llave pública y la de servicio no
--     tienen permiso de nada; y el dueño SIN el código del teléfono no ve lo
--     de cada persona (ni por la tabla, ni por una función), y el control se
--     lo dice.
do $$
declare
  v_obt text; v_c uuid; r jsonb; m1 uuid; t text; v_eq int := 0; v_eq_n int := 0; v_an int := 0; v_an_n int := 0; v_d1 text; x text; v_m text := pg_temp.c15('mes');
  v_nom text := 'con la nómina dentro, nadie más ve nada';
  v_esp text := 'el equipo: filas que ve en las 15 tablas y las 7 vistas: 0 (22 de 22 miradas) | en lo que se lee por una función: 0 filas | lo '
                'que intenta hacer: 42501 las 12 veces | la llave pública y la de servicio: sin permiso en 44 de 44 (tablas y vistas) y en 8 de '
                '8 funciones | el dueño sin el código del teléfono: las corridas las ve (1 o más), y lo de cada persona: 0 filas en sus 4 '
                'tablas, 0 por las funciones de las horas, y sus personas en la corrida: PGRST MFA | el control se lo dice en el 15 y el 20: sí '
                '| con su código: 3 personas, 14 o más líneas';
begin
  if pg_temp.c15_omitir(37, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    r := pg_temp.c15_postear(v_c);
    m1 := pg_temp.c15_cargo('c15-t37-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t37 C15 PRUEBA');
    perform pg_temp.c15_casar(m1);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_declaracion(jsonb_build_object('forma', '940', 'anio', extract(year from pg_temp.c15_pago())::int, 'futa', '34.85'));
    perform fn_nomina_lote(pg_temp.c15_d(0), pg_temp.c15_d(13), 'C15 PRUEBA');
    perform pg_temp.c15_ser('editor');
    -- el equipo
    foreach t in array pg_temp.c15_tablas() || pg_temp.c15_vistas() loop
      x := pg_temp.c15_da(format('select count(*) from public.%I', t), 'equipo');
      v_eq_n := v_eq_n + 1;
      v_eq := v_eq + case when x ~ '^[0-9]+$' then x::int else 1000000 end;
    end loop;
    v_obt := format('el equipo: filas que ve en las 15 tablas y las 7 vistas: %s (%s de 22 miradas)', v_eq, v_eq_n);
    select v_obt || ' | en lo que se lee por una función: ' || sum(case when z.n ~ '^[0-9]+$' then z.n::int else 1000000 end) || ' filas' into v_obt
      from (select pg_temp.c15_da(q, 'equipo') as n from unnest(array[
              'select count(*) from public.fn_nomina_control()', 'select count(*) from public.fn_nomina_cargos()',
              'select count(*) from public.fn_nomina_auxiliar(null)', 'select count(*) from public.fn_nomina_amarre(null)',
              'select count(*) from public.fn_nomina_pendiente(null)', 'select count(*) from public.fn_nomina_horas_pagadas()',
              'select count(*) from public.fn_nomina_pagado_hasta()', format('select count(*) from public.fn_nomina_cola(%L)', v_m),
              format('select count(*) from public.fn_nomina_cierre(%L)', v_m),
              format('select count(*) from public.fn_nomina_horas_gusto(%L, %L)', pg_temp.c15_d(0), pg_temp.c15_d(13)),
              format('select count(*) from public.fn_nomina_journal(%L)', v_c),
              format('select coalesce(length(public.fn_nomina_lote_csv(%L)), 0)', (select l.id from nomina_lotes l where l.vigente order by l.creado_el desc limit 1))]) q) z;
    select v_obt || ' | lo que intenta hacer: ' || case when count(*) filter (where z.e = '42501') = count(*) then '42501 las ' || count(*) || ' veces'
                                                       else string_agg(z.e, ', ') end into v_obt
      from (select pg_temp.c15_estado(q, 'equipo') as e from unnest(array[
              format('select public.fn_nomina_propuesta(%L)', v_c), format('select public.fn_nomina_postear(%L, ''x'')', v_c),
              format('select public.fn_nomina_anular(%L, ''C15 PRUEBA'')', v_c), format('select public.fn_nomina_descartar(%L, ''C15 PRUEBA'')', v_c),
              format('select public.fn_nomina_ensayo(%L::jsonb)', pg_temp.c15_arch(pg_temp.c15_journal())),
              format('select public.fn_nomina_lote(%L, %L)', pg_temp.c15_d(0), pg_temp.c15_d(13)),
              'select public.fn_nomina_declaracion(''{"forma": "940", "anio": 2026, "futa": "1"}''::jsonb)',
              format('select public.fn_nomina_persona(%L::jsonb)', jsonb_build_object('id', pg_temp.c15_persona('ZZ Ayudante Uno'), 'clase', 'oficina')),
              'select public.fn_nomina_columna(''{"columna": "ZZ Dato raro", "clase": "ignorar"}''::jsonb)',
              format('select public.fn_nomina_cargo_casar(%L, ''[]''::jsonb)', m1), format('select public.fn_nomina_cargo_cuota(%L, ''C15 PRUEBA'')', m1),
              format('select public.fn_nomina_cargo_deshacer(%L, ''C15 PRUEBA'')', (select g.id from nomina_pagos g where g.movimiento_id = m1))]) q) z;
    -- la llave pública y la de servicio
    foreach t in array pg_temp.c15_tablas() || pg_temp.c15_vistas() loop
      v_an_n := v_an_n + 2;
      v_an := v_an + case when pg_temp.c15_da(format('select count(*) from public.%I', t), 'anon') = '42501' then 1 else 0 end
                   + case when pg_temp.c15_da(format('select count(*) from public.%I', t), 'service_role') = '42501' then 1 else 0 end;
    end loop;
    select v_obt || format(' | la llave pública y la de servicio: sin permiso en %s de %s (tablas y vistas) y en %s de %s funciones', v_an, v_an_n,
                           count(*) filter (where z.e = '42501'), count(*)) into v_obt
      from (select pg_temp.c15_estado(q.q, g.r) as e
              from unnest(array['select count(*) from public.fn_nomina_control()', 'select count(*) from public.fn_nomina_horas_pagadas()',
                                format('select public.fn_nomina_propuesta(%L)', v_c), 'select public.fn_nomina_config()']) q(q)
             cross join (values ('anon'), ('service_role')) g(r)) z;
    -- el dueño sin el código del teléfono
    v_d1 := format('las corridas las ve (%s), y lo de cada persona: %s filas en sus 4 tablas, %s por las funciones de las horas, y sus personas en la corrida: %s',
      case when pg_temp.c15_da('select count(*) from public.nomina_corridas', 'dueno_aal1')::int >= 1 then '1 o más' else '0' end,
      (select sum(pg_temp.c15_da(format('select count(*) from public.%I', q), 'dueno_aal1')::int)
         from unnest(array['nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas']) q),
      (select sum(pg_temp.c15_da(q, 'dueno_aal1')::int)
         from unnest(array['select count(*) from public.fn_nomina_horas_pagadas()', 'select count(*) from public.fn_nomina_pagado_hasta()',
                           format('select count(*) from public.fn_nomina_cola(%L)', v_m), format('select count(*) from public.fn_nomina_journal(%L)', v_c)]) q),
      pg_temp.c15_estado(format('select public.fn_nomina_propuesta(%L)', v_c), 'dueno_aal1'));
    perform pg_temp.c15_ser('dueno_aal1');
    select case when count(*) = 2 and bool_and(not k.ok and k.detalle like '%hace falta el código del teléfono%') then 'sí' else 'no' end into x
      from fn_nomina_control() k where k.orden in (15, 20);
    perform pg_temp.c15_ser('dueno');
    v_obt := v_obt || format(' | el dueño sin el código del teléfono: %s | el control se lo dice en el 15 y el 20: %s | con su código: %s personas, %s líneas',
      v_d1, x, (select count(*) from nomina_corrida_personas cp where cp.corrida_id = v_c),
      (select case when count(*) >= 14 then '14 o más' else count(*)::text end from nomina_lineas l where l.corrida_id = v_c));
    perform pg_temp.c15_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c15_ser('editor');
  insert into _pruebas values (37, 'con una nómina posteada, un cargo casado, una declaración y un lote de horas dentro, NADIE MÁS VE NADA: el equipo lee cero filas de cada tabla, de cada vista y de cada función, y todo lo que intenta hacer contesta 42501; la llave pública y la de servicio no tienen permiso de nada; y el dueño sin el código del teléfono ve las corridas pero no lo de cada persona (ni por sus tablas, ni por las funciones de las horas, ni en una propuesta), y el control se lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. Con una nómina posteada (su journal y el reparto de su burden), sus
--     tres cargos de Gusto casados, la cuota mensual en su gasto, un bono
--     posteado y anulado, una declaración tecleada y un lote de horas,
--     NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos»
--     de c2, los puentes (c3), el banco (c6), los estados (c4), los cuadres
--     de la IA (c8), los del jornal y el margen (c10), los de las facturas
--     (c11), los del WIP (c12), los de la cédula (c13), los de los subs
--     (c14) y lo que detiene el cierre del mes (c9). Se compara con cómo
--     estaban con los cargos de prueba ya en la Bandeja del banco y sin
--     casar (lo que ya estaba en rojo se dice y no cuenta).
do $$
declare
  v_obt text; s0 text[]; s1 text[]; v_c uuid; v_b uuid; r jsonb; m1 uuid; m2 uuid; m3 uuid; m4 uuid; v_antes text := ''; v_mo boolean;
  v_nom text := 'ningún control de las otras capas pasa a rojo';
  v_esp text := 'con todo lo de c15 puesto: ninguno | permisos (c2): verde | c3 «mano de obra»: verde | los cuadres de la nómina: nada nuevo en rojo';
begin
  if pg_temp.c15_omitir(38, v_nom, v_esp, true) then return; end if;
  begin
    v_c := pg_temp.c15_lista();
    m1 := pg_temp.c15_cargo('c15-t38-net', pg_temp.c15_d(15), 4874.93, 'GUSTO NET 7c15t38 C15 PRUEBA');
    m2 := pg_temp.c15_cargo('c15-t38-tax', pg_temp.c15_d(15), 1583.31, 'GUSTO TAX 7c15t38 C15 PRUEBA');
    m3 := pg_temp.c15_cargo('c15-t38-csd', pg_temp.c15_d(15), 50.00, 'GUSTO CSD 7c15t38 C15 PRUEBA');
    m4 := pg_temp.c15_cargo('c15-t38-fee', pg_temp.c15_d(16), 49.00, 'GUSTO FEE 7c15t38 C15 PRUEBA');
    s0 := pg_temp.c15_rojos();
    r := pg_temp.c15_postear(v_c);
    perform pg_temp.c15_casar(m1); perform pg_temp.c15_casar(m2); perform pg_temp.c15_casar(m3);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_cargo_cuota(m4, 'C15 PRUEBA: la cuota del mes');
    perform pg_temp.c15_ser('editor');
    v_b := pg_temp.c15_importar(pg_temp.c15_bono(), 'zz-c15-prueba-bono.csv');
    r := pg_temp.c15_postear(v_b);
    perform pg_temp.c15_ser('dueno');
    perform fn_nomina_anular(v_b, 'C15 PRUEBA: el bono no iba');
    perform fn_nomina_declaracion(jsonb_build_object('forma', '940', 'anio', extract(year from pg_temp.c15_pago())::int, 'futa', '34.85'));
    perform fn_nomina_lote(pg_temp.c15_d(0), pg_temp.c15_d(13), 'C15 PRUEBA');
    perform pg_temp.c15_ser('editor');
    s1 := pg_temp.c15_rojos();
    select k.ok into v_mo from fn_puentes_verificar() k where k.control = 'mano_de_obra';
    v_obt := format('con todo lo de c15 puesto: %s | permisos (c2): %s | c3 «mano de obra»: %s | los cuadres de la nómina: %s',
                    pg_temp.c15_nuevos(s0, s1), pg_temp.c15_permisos(), case when v_mo or 'c3: mano_de_obra' = any (s0) then 'verde' else 'rojo' end,
                    pg_temp.c15_propios());
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'con una nómina posteada (su journal y el reparto de su burden real), sus tres cargos de Gusto casados por el banco, la cuota mensual en su gasto, un bono posteado y anulado, una declaración tecleada y un lote de horas, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3: «mano de obra» en verde), el banco (c6), los estados (c4), los cuadres de la IA (c8), los del jornal y el margen (c10), los de las facturas (c11), los del WIP (c12), los de la cédula (c13), los de los subs (c14) y lo que detiene el cierre del mes (c9)',
    v_esp, v_obt || case when v_antes <> '' then ' (ya en rojo antes, con los cargos de prueba en la Bandeja del banco: ' || left(v_antes, 600) || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 39. Nada queda: lo que c15 toca (y lo que sus pruebas sembraron) está como
--     antes de la primera prueba.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c15_ser('editor');
    v_obt := case when pg_temp.c15_conteos() <> pg_temp.c15('conteos') then 'antes: ' || pg_temp.c15('conteos') || ' · ahora: ' || pg_temp.c15_conteos()
                  when exists (select 1 from proyectos p where p.id like 'c15-prueba-%') then 'queda una obra de prueba'
                  when exists (select 1 from perfiles p where p.id::text in (pg_temp.c15('p1'), pg_temp.c15('p2'), pg_temp.c15('p3'))) then 'queda una persona de prueba'
                  when exists (select 1 from nomina_personas p where p.nombre like 'ZZ %') then 'queda una persona de la nómina de prueba'
                  when exists (select 1 from nomina_archivos a where a.nombre like 'zz-c15-prueba%') then 'queda un archivo de prueba'
                  when exists (select 1 from horas h where h.id between -1510000999 and -1510000000) then 'queda un reporte de horas de prueba'
                  when exists (select 1 from asientos a where a.descripcion like 'C15 PRUEBA%' or a.origen_tabla in ('nomina_corridas', 'nomina_burden')
                                                             and not exists (select 1 from nomina_corridas k where k.id::text = a.origen_id))
                    then 'queda un asiento de prueba'
                  when to_regclass('public.movimientos_banco') is not null
                       and (select count(*) from movimientos_banco m where m.descripcion like '%C15 PRUEBA%') > 0 then 'queda un movimiento de prueba'
                  when coalesce(current_setting('mx_nomina.escribe', true), '') <> '' then 'queda una marca de escritura puesta'
                  else 'igual que antes' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'nada queda de las pruebas: la configuración, el mapeo, las personas, los archivos, las corridas con sus personas, sus líneas, su reparto y su lote, los cargos casados y sus partes, las declaraciones, los lotes de horas, el historial, los asientos y sus líneas, los contadores, los perfiles, los usuarios, las tarifas, las horas y sus aprobaciones, las obras, los movimientos del banco, los períodos cerrados, la revisión del cierre que c9 guarda, el reloj y las funciones: todo como antes de la primera prueba',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 40. El cierre de la suite: las demás capas (c2, c3, c4, c6, c8, c9, c10,
--     c11, c12, c13 y c14) como estaban antes de las pruebas (lo que ya
--     estaba en rojo se dice y no cuenta), los cuadres del propio control
--     como estaban, nada de c15 para anon o service_role, y SECURITY DEFINER
--     solo el trigger del puente; fn_nomina_pegado responde con sus nueve
--     filas y la configuración sigue siendo UNA (pegar dos veces no la pisa:
--     lo corre el banco, con dos pegados seguidos antes de esta suite). Y,
--     mirado todo eso, la base sigue como al empezar (tampoco la revisión del
--     cierre que c9 guarda, ni el reloj).
do $$
declare
  v_obt text; v_api text; v_def text; v_n int; v_cfg int; v_rojos text;
  v_esp text := 'las otras capas, en rojo nuevo: ninguno | permisos (c2): verde | los cuadres de la nómina: nada nuevo en rojo | c15 para anon o '
                'service_role: ninguna | con permisos de dueño: fn_nomina_al_libro (el trigger del puente) | el pegado: 9 filas, y la '
                'configuración 1 fila (id 1) | y nada queda: sí';
begin
  begin
    perform pg_temp.c15_ser('editor');
    v_rojos := pg_temp.c15_nuevos(coalesce(string_to_array(nullif(pg_temp.c15('rojos_antes'), ''), '; '), '{}'::text[]),
                                  array(select x from unnest(pg_temp.c15_rojos_limpio()) x where x <> 'c2: permisos'));
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn())
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select coalesce(string_agg(p.proname || case when p.prorettype = 'trigger'::regtype then ' (el trigger del puente)' else ' (NO es un trigger)' end,
                               ', ' order by p.proname), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (pg_temp.c15_fn()) and p.prosecdef;
    select count(*) into v_n from fn_nomina_pegado();
    select count(*) into v_cfg from nomina_config;
    v_obt := format('las otras capas, en rojo nuevo: %s | permisos (c2): %s | los cuadres de la nómina: %s | c15 para anon o service_role: %s | con '
                    'permisos de dueño: %s | el pegado: %s filas, y la configuración %s fila (id %s)',
                    v_rojos, pg_temp.c15_permisos(), pg_temp.c15_propios(), v_api, v_def, v_n, v_cfg, (select id from nomina_config limit 1));
    v_obt := v_obt || ' | y nada queda: '
             || case when pg_temp.c15_conteos() = pg_temp.c15('conteos') then 'sí'
                     else 'QUEDÓ: ' || pg_temp.c15_conteos() || ' (antes: ' || pg_temp.c15('conteos') || ')' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'el cierre de la suite: c2, c3, c4, c6, c8, c9, c10, c11, c12, c13 y c14 como estaban con c15 puesto (lo que ya estaba en rojo antes se dice y no cuenta), «permisos» de c2 en verde, los cuadres del propio control de la nómina como estaban, nada de c15 para anon o service_role, con permisos de dueño solo el trigger del puente al libro; fn_nomina_pegado responde con sus nueve filas, la configuración sigue siendo una (pegar dos veces no la pisa) y nada queda (ni la revisión del cierre que c9 guarda, ni el reloj)',
    v_esp,
    v_obt || case when pg_temp.c15('rojos_antes') <> '' then ' (ya en rojo antes de las pruebas: ' || left(pg_temp.c15('rojos_antes'), 600) || ')' else '' end
          || case when pg_temp.c15('rojos_nomina') <> '' then ' (cuadres de la nómina ya en rojo antes, con los datos de esta base: ' || pg_temp.c15('rojos_nomina') || ')' else '' end
          || case when pg_temp.c15('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c15: ' || pg_temp.c15('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- EL RELOJ, COMO ESTABA. Cada prueba que lo finge lo deshace con su subtransacción; esto es la red: si alguno quedara
-- puesto, se restaura aquí mismo el de verdad (el que había al empezar) y sale como un fallo, con su fila.
do $$
begin
  if pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) is distinct from pg_temp.c15('reloj_def') then
    reset role;
    execute pg_temp.c15('reloj_def');
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
-- momento más tranquilo. (Como c11-pruebas.sql y c14-pruebas.sql.)
update _pruebas
   set ok = null,
       obtenido = 'omitida: mientras corría, la app (u otra sesión) tenía tomado algo que esta prueba necesita y no lo soltó en medio '
                  || 'segundo (55P03); no se esperó más, para no dejar esperando a la app. No es un fallo: vuelve a pegar el archivo en un '
                  || 'momento en que nadie esté usando la app. Lo que dio: ' || left(obtenido, 300)
 where ok is false and obtenido like '%55P03%';

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8, c9, c10, c11, c12 y c14): si el SQL Editor deja de esperar, la
-- corrida sigue en el servidor hasta el final y se lee después con
--   select * from pruebas.c15_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade». (No lleva nada de nadie: las
-- personas de las pruebas son inventadas, «ZZ…», y sus montos también.)
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c15_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c15_resultado from public, anon, authenticated, service_role;
truncate pruebas.c15_resultado;
insert into pruebas.c15_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
